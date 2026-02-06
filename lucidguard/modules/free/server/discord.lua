--[[
    LucidGuard Anticheat - Discord Webhook System
    Created by OnlyLucidVibes
    Rich embed notifications with rate limiting
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local webhookQueue = {}
local lastWebhookSend = 0
local webhooksSentThisMinute = 0
local lastMinuteReset = os.time()

-- ============================================================================
-- WEBHOOK QUEUE PROCESSOR
-- ============================================================================

CreateThread(function()
    while true do
        Wait(2000) -- Process queue every 2 seconds
        
        -- Reset counter every minute
        if os.time() - lastMinuteReset >= 60 then
            webhooksSentThisMinute = 0
            lastMinuteReset = os.time()
        end
        
        -- Process queue if under rate limit
        if #webhookQueue > 0 and webhooksSentThisMinute < Config.Discord.RateLimit.MaxPerMinute then
            local webhook = table.remove(webhookQueue, 1)
            SendWebhookDirect(webhook)
            webhooksSentThisMinute = webhooksSentThisMinute + 1
        end
    end
end)

-- ============================================================================
-- DIRECT WEBHOOK SEND
-- ============================================================================

function SendWebhookDirect(payload)
    if not Config.Discord.Enabled then return end
    if Config.Discord.WebhookURL == 'YOUR_DISCORD_WEBHOOK_URL_HERE' then
        Log('WARN', 'Discord webhook URL not configured!')
        return
    end
    
    PerformHttpRequest(Config.Discord.WebhookURL, function(errorCode, resultData, resultHeaders)
        if errorCode ~= 200 and errorCode ~= 204 then
            Log('WARN', string.format('Discord webhook failed: HTTP %s', errorCode))
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- ============================================================================
-- QUEUE WEBHOOK
-- ============================================================================

function QueueWebhook(payload)
    if Config.Discord.RateLimit.QueueEnabled then
        table.insert(webhookQueue, payload)
    else
        SendWebhookDirect(payload)
    end
end

-- ============================================================================
-- BUILD DETECTION EMBED
-- ============================================================================

function SendDiscordDetection(playerId, detectionType, severity, details)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetAllIdentifiers(playerId)
    local tokens = GetAllTokens(playerId)
    local playerData = GetPlayerData(playerId)
    
    -- Get coordinates if available
    local coords = 'N/A'
    if playerData and playerData.lastPosition then
        coords = FormatCoords(playerData.lastPosition)
    end
    
    -- Build identifier string
    local idString = ''
    if identifiers.steam then idString = idString .. '**Steam:** `' .. identifiers.steam .. '`\n' end
    if identifiers.license then idString = idString .. '**License:** `' .. identifiers.license .. '`\n' end
    if identifiers.discord then idString = idString .. '**Discord:** <@' .. string.gsub(identifiers.discord, 'discord:', '') .. '>\n' end
    if identifiers.fivem then idString = idString .. '**FiveM:** `' .. identifiers.fivem .. '`\n' end
    if identifiers.ip then idString = idString .. '**IP:** `' .. identifiers.ip .. '`\n' end
    
    -- Build token string (first 3 only)
    local tokenString = ''
    for i = 1, math.min(3, #tokens) do
        tokenString = tokenString .. '`' .. string.sub(tokens[i], 1, 20) .. '...`\n'
    end
    if tokenString == '' then tokenString = 'N/A' end
    
    -- Get severity color
    local color = Config.Discord.Colors[severity] or Config.Discord.Colors.INFO
    
    -- Severity emoji
    local severityEmoji = '⚪'
    if severity == 'LOW' then severityEmoji = '🟡'
    elseif severity == 'MEDIUM' then severityEmoji = '🟠'
    elseif severity == 'HIGH' then severityEmoji = '🔴'
    elseif severity == 'CRITICAL' then severityEmoji = '🚨'
    end
    
    -- Recommended action
    local recommendedAction = 'Review activity'
    if Config.Severity[severity] then
        if Config.Severity[severity].RecommendedBan then
            recommendedAction = '**Ban recommended:** ' .. Config.Severity[severity].RecommendedBan
        elseif Config.Severity[severity].Action == 'kick' then
            recommendedAction = 'Player has been kicked'
        end
    end
    
    local payload = {
        username = Config.Discord.BotName,
        avatar_url = Config.Discord.BotAvatar,
        embeds = {{
            title = severityEmoji .. ' Anticheat Detection: ' .. detectionType,
            description = 'A potential cheat has been detected on the server.',
            color = color,
            fields = {
                {
                    name = '👤 Player',
                    value = playerName .. ' (ID: ' .. playerId .. ')',
                    inline = true
                },
                {
                    name = '⚠️ Severity',
                    value = severity,
                    inline = true
                },
                {
                    name = '🎯 Detection Type',
                    value = detectionType,
                    inline = true
                },
                {
                    name = '📍 Coordinates',
                    value = '`' .. coords .. '`',
                    inline = true
                },
                {
                    name = '🕐 Server Time',
                    value = os.date('%Y-%m-%d %H:%M:%S'),
                    inline = true
                },
                {
                    name = '📋 Action',
                    value = recommendedAction,
                    inline = true
                },
                {
                    name = '🔑 Identifiers',
                    value = idString ~= '' and idString or 'N/A',
                    inline = false
                },
                {
                    name = '🖥️ Hardware Tokens',
                    value = tokenString,
                    inline = false
                },
                {
                    name = '📝 Details',
                    value = '```' .. (details or 'No additional details') .. '```',
                    inline = false
                }
            },
            footer = {
                text = '🛡️ LucidGuard v1.0 by OnlyLucidVibes | Review and ban via txAdmin if needed'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    
    QueueWebhook(payload)
end

-- ============================================================================
-- VPN DETECTION ALERT
-- ============================================================================

function SendVPNAlert(playerId, ipData)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetAllIdentifiers(playerId)
    
    local idString = ''
    if identifiers.steam then idString = idString .. '**Steam:** `' .. identifiers.steam .. '`\n' end
    if identifiers.license then idString = idString .. '**License:** `' .. identifiers.license .. '`\n' end
    if identifiers.discord then idString = idString .. '**Discord:** <@' .. string.gsub(identifiers.discord, 'discord:', '') .. '>\n' end
    if identifiers.ip then idString = idString .. '**IP:** `' .. identifiers.ip .. '`\n' end
    
    local payload = {
        username = Config.Discord.BotName,
        avatar_url = Config.Discord.BotAvatar,
        embeds = {{
            title = '🔒 VPN/Proxy Detected',
            description = 'A player connected using a VPN or proxy service.',
            color = Config.Discord.Colors.VPN,
            fields = {
                {
                    name = '👤 Player',
                    value = playerName .. ' (ID: ' .. playerId .. ')',
                    inline = true
                },
                {
                    name = '🌐 Connection Type',
                    value = ipData.hosting and 'Datacenter/Hosting' or 'VPN/Proxy',
                    inline = true
                },
                {
                    name = '🕐 Server Time',
                    value = os.date('%Y-%m-%d %H:%M:%S'),
                    inline = true
                },
                {
                    name = '🔑 Identifiers',
                    value = idString ~= '' and idString or 'N/A',
                    inline = false
                }
            },
            footer = {
                text = '🛡️ LucidGuard v1.0 by OnlyLucidVibes | Player allowed - flagged for review only'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    
    QueueWebhook(payload)
end

-- ============================================================================
-- SCREENSHOT UPLOAD
-- ============================================================================

function SendScreenshotToDiscord(playerId, screenshotData)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetAllIdentifiers(playerId)
    
    local idString = ''
    if identifiers.steam then idString = idString .. '`' .. identifiers.steam .. '`\n' end
    if identifiers.license then idString = idString .. '`' .. identifiers.license .. '`' end
    
    local payload = {
        username = Config.Discord.BotName,
        avatar_url = Config.Discord.BotAvatar,
        embeds = {{
            title = '📸 Post-Join Screenshot',
            description = 'Automatic screenshot captured after player joined.',
            color = Config.Discord.Colors.INFO,
            fields = {
                {
                    name = '👤 Player',
                    value = playerName .. ' (ID: ' .. playerId .. ')',
                    inline = true
                },
                {
                    name = '🕐 Captured At',
                    value = os.date('%Y-%m-%d %H:%M:%S'),
                    inline = true
                },
                {
                    name = '🔑 Identifiers',
                    value = idString ~= '' and idString or 'N/A',
                    inline = false
                }
            },
            image = {
                url = screenshotData
            },
            footer = {
                text = '🛡️ LucidGuard v1.0 by OnlyLucidVibes | Review for cheat menu overlays'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    
    QueueWebhook(payload)
end

-- ============================================================================
-- PLAYER CONNECTION ALERT
-- ============================================================================

function SendConnectionAlert(playerId, reason)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetAllIdentifiers(playerId)
    
    local idString = ''
    for idType, idValue in pairs(identifiers) do
        if idValue then
            idString = idString .. '**' .. idType .. ':** `' .. idValue .. '`\n'
        end
    end
    
    local payload = {
        username = Config.Discord.BotName,
        avatar_url = Config.Discord.BotAvatar,
        embeds = {{
            title = '🚫 Connection Blocked',
            description = 'A player was prevented from joining the server.',
            color = Config.Discord.Colors.CRITICAL,
            fields = {
                {
                    name = '👤 Player',
                    value = playerName,
                    inline = true
                },
                {
                    name = '❌ Reason',
                    value = reason,
                    inline = true
                },
                {
                    name = '🕐 Time',
                    value = os.date('%Y-%m-%d %H:%M:%S'),
                    inline = true
                },
                {
                    name = '🔑 Identifiers',
                    value = idString ~= '' and idString or 'N/A',
                    inline = false
                }
            },
            footer = {
                text = '🛡️ LucidGuard v1.0 by OnlyLucidVibes'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    
    QueueWebhook(payload)
end

-- ============================================================================
-- ECONOMY ALERT
-- ============================================================================

function SendEconomyAlert(playerId, transactionType, amount, details)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetAllIdentifiers(playerId)
    
    local idString = ''
    if identifiers.steam then idString = idString .. '**Steam:** `' .. identifiers.steam .. '`\n' end
    if identifiers.license then idString = idString .. '**License:** `' .. identifiers.license .. '`\n' end
    
    local payload = {
        username = Config.Discord.BotName,
        avatar_url = Config.Discord.BotAvatar,
        embeds = {{
            title = '💰 Suspicious Economy Activity',
            description = 'Unusual transaction detected.',
            color = Config.Discord.Colors.HIGH,
            fields = {
                {
                    name = '👤 Player',
                    value = playerName .. ' (ID: ' .. playerId .. ')',
                    inline = true
                },
                {
                    name = '💵 Transaction Type',
                    value = transactionType,
                    inline = true
                },
                {
                    name = '💲 Amount',
                    value = '$' .. tostring(amount),
                    inline = true
                },
                {
                    name = '🕐 Time',
                    value = os.date('%Y-%m-%d %H:%M:%S'),
                    inline = true
                },
                {
                    name = '🔑 Identifiers',
                    value = idString ~= '' and idString or 'N/A',
                    inline = false
                },
                {
                    name = '📝 Details',
                    value = '```' .. (details or 'No additional details') .. '```',
                    inline = false
                }
            },
            footer = {
                text = '🛡️ LucidGuard v1.0 by OnlyLucidVibes | Review via txAdmin'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    
    QueueWebhook(payload)
end

-- ============================================================================
-- RATE LIMIT ALERT
-- ============================================================================

function SendRateLimitAlert(playerId, eventName, callCount)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetAllIdentifiers(playerId)
    
    local idString = ''
    if identifiers.steam then idString = idString .. '`' .. identifiers.steam .. '`\n' end
    if identifiers.license then idString = idString .. '`' .. identifiers.license .. '`' end
    
    local payload = {
        username = Config.Discord.BotName,
        avatar_url = Config.Discord.BotAvatar,
        embeds = {{
            title = '⚡ Rate Limit Exceeded',
            description = 'A player exceeded the event rate limit (potential DDoS or exploit attempt).',
            color = Config.Discord.Colors.HIGH,
            fields = {
                {
                    name = '👤 Player',
                    value = playerName .. ' (ID: ' .. playerId .. ')',
                    inline = true
                },
                {
                    name = '📡 Event',
                    value = '`' .. eventName .. '`',
                    inline = true
                },
                {
                    name = '🔢 Call Count',
                    value = tostring(callCount),
                    inline = true
                },
                {
                    name = '🔑 Identifiers',
                    value = idString ~= '' and idString or 'N/A',
                    inline = false
                }
            },
            footer = {
                text = '🛡️ LucidGuard v1.0 by OnlyLucidVibes | Player kicked - recommend ban if repeated'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
    
    QueueWebhook(payload)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('SendDiscordDetection', SendDiscordDetection)
exports('SendVPNAlert', SendVPNAlert)
exports('SendScreenshotToDiscord', SendScreenshotToDiscord)
exports('SendConnectionAlert', SendConnectionAlert)
exports('SendEconomyAlert', SendEconomyAlert)
exports('SendRateLimitAlert', SendRateLimitAlert)
