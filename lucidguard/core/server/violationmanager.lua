--[[
    LucidGuard Anticheat - Violation Manager
    by OnlyLucidVibes
    
    Centralized violation handling with:
    - Configurable thresholds per detection type
    - Cooldown windows to prevent spam
    - Progressive punishment system
    - Appeal-friendly logging
]]

local ViolationManager = {}

-- ============================================================================
-- VIOLATION CONFIGURATION
-- ============================================================================

-- Default thresholds (can be overridden in config)
local DEFAULT_THRESHOLDS = {
    -- Movement Cheats
    SPEED = { violations = 5, window = 60000, action = 'KICK', cooldown = 5000 },
    TELEPORT = { violations = 3, window = 60000, action = 'KICK', cooldown = 10000 },
    NOCLIP = { violations = 4, window = 60000, action = 'KICK', cooldown = 5000 },
    
    -- Combat Cheats  
    GODMODE = { violations = 3, window = 60000, action = 'BAN', cooldown = 10000 },
    AIMBOT = { violations = 5, window = 120000, action = 'BAN', cooldown = 5000 },
    DAMAGE_MOD = { violations = 4, window = 60000, action = 'KICK', cooldown = 5000 },
    
    -- Weapon Cheats
    WEAPON_SPAWN = { violations = 2, window = 60000, action = 'KICK', cooldown = 10000 },
    WEAPON_BLACKLIST = { violations = 1, window = 60000, action = 'KICK', cooldown = 30000 },
    AMMO_MOD = { violations = 3, window = 60000, action = 'KICK', cooldown = 10000 },
    
    -- Resource/Integrity
    FILE_TAMPERING = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 },
    RESOURCE_INJECT = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 },
    NATIVE_HOOK = { violations = 3, window = 60000, action = 'KICK', cooldown = 30000 },
    
    -- Network/State
    STATE_BAG_HACK = { violations = 2, window = 60000, action = 'BAN', cooldown = 30000 },
    LAG_SWITCH = { violations = 5, window = 120000, action = 'KICK', cooldown = 10000 },
    EVENT_SPAM = { violations = 10, window = 10000, action = 'KICK', cooldown = 1000 },
    
    -- Economy
    MONEY_EXPLOIT = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 },
    GHOST_FARMING = { violations = 3, window = 120000, action = 'KICK', cooldown = 30000 },
    
    -- Honeypots (instant)
    MENU_TRAP = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 },
    JUNK_EVENT_TRIGGER = { violations = 1, window = 60000, action = 'FLAG', cooldown = 60000 },
    
    -- Default for unknown types
    DEFAULT = { violations = 5, window = 60000, action = 'KICK', cooldown = 5000 }
}

-- Player violation tracking
local playerViolations = {}
local lastViolationTime = {}

-- ============================================================================
-- GET THRESHOLD CONFIGURATION
-- ============================================================================

function ViolationManager.GetThreshold(detectionType)
    -- Check config override
    if Config.ViolationThresholds and Config.ViolationThresholds[detectionType] then
        return Config.ViolationThresholds[detectionType]
    end
    
    -- Use default
    return DEFAULT_THRESHOLDS[detectionType] or DEFAULT_THRESHOLDS.DEFAULT
end

-- ============================================================================
-- RECORD VIOLATION
-- ============================================================================

function ViolationManager.RecordViolation(playerId, detectionType, details, severity)
    local threshold = ViolationManager.GetThreshold(detectionType)
    details = details or {}
    severity = severity or 'MEDIUM'
    
    -- Initialize player tracking
    if not playerViolations[playerId] then
        playerViolations[playerId] = {}
    end
    
    if not playerViolations[playerId][detectionType] then
        playerViolations[playerId][detectionType] = {
            count = 0,
            timestamps = {},
            details = {}
        }
    end
    
    local pv = playerViolations[playerId][detectionType]
    
    -- Check cooldown
    local lastTime = lastViolationTime[playerId] and lastViolationTime[playerId][detectionType]
    if lastTime and (GetGameTimer() - lastTime) < threshold.cooldown then
        -- Still in cooldown, don't record
        return false, pv.count, threshold.violations, 'COOLDOWN'
    end
    
    -- Record timestamp
    lastViolationTime[playerId] = lastViolationTime[playerId] or {}
    lastViolationTime[playerId][detectionType] = GetGameTimer()
    
    -- Add violation
    local now = os.time()
    table.insert(pv.timestamps, now)
    table.insert(pv.details, {
        time = now,
        details = details,
        severity = severity
    })
    
    -- Clean old violations (outside window)
    local windowSeconds = threshold.window / 1000
    local cutoff = now - windowSeconds
    
    local newTimestamps = {}
    local newDetails = {}
    
    for i, timestamp in ipairs(pv.timestamps) do
        if timestamp > cutoff then
            table.insert(newTimestamps, timestamp)
            table.insert(newDetails, pv.details[i])
        end
    end
    
    pv.timestamps = newTimestamps
    pv.details = newDetails
    pv.count = #pv.timestamps
    
    -- Log the violation
    local playerName = GetPlayerName(playerId) or 'Unknown'
    
    if Log then
        local logLevel = 'WARN'
        if pv.count >= threshold.violations then
            logLevel = 'CRITICAL'
        elseif pv.count >= threshold.violations / 2 then
            logLevel = 'ALERT'
        end
        
        Log(logLevel, detectionType, string.format(
            'Violation %d/%d - %s',
            pv.count,
            threshold.violations,
            details.reason or 'No reason provided'
        ), playerId, {
            ['Severity'] = severity,
            ['Window'] = string.format('%ds', threshold.window / 1000),
            ['Action at Threshold'] = threshold.action,
            ['Details'] = details
        })
    end
    
    -- Check if threshold reached
    local thresholdReached = pv.count >= threshold.violations
    
    return thresholdReached, pv.count, threshold.violations, threshold.action
end

-- ============================================================================
-- PROCESS DETECTION (Main entry point)
-- ============================================================================

function ViolationManager.ProcessDetection(playerId, detectionType, details, severity)
    local playerName = GetPlayerName(playerId)
    if not playerName then return end
    
    details = details or {}
    severity = severity or 'MEDIUM'
    
    -- ========================================================================
    -- STEP 1: Check admin immunity
    -- ========================================================================
    
    if IsPlayerAdmin and IsPlayerAdmin(playerId) then
        if Log then
            Log('DEBUG', detectionType, 'Skipped (Admin immunity)', playerId)
        end
        return
    end
    
    -- ========================================================================
    -- STEP 2: Check whitelist
    -- ========================================================================
    
    if FalsePositive then
        if FalsePositive.IsWhitelisted(playerId) then
            if Log then
                Log('DEBUG', detectionType, 'Skipped (Whitelisted)', playerId)
            end
            return
        end
        
        if FalsePositive.IsDetectionWhitelisted(playerId, detectionType) then
            if Log then
                Log('DEBUG', detectionType, 'Skipped (Detection whitelisted)', playerId)
            end
            return
        end
    end
    
    -- ========================================================================
    -- STEP 3: Validate detection (false positive check)
    -- ========================================================================
    
    if FalsePositive then
        local valid, reasons = FalsePositive.ValidateDetection(playerId, detectionType, details)
        
        if not valid then
            if Log and Config.Debug then
                Log('DEBUG', detectionType, string.format(
                    'Skipped (False positive prevention): %s',
                    table.concat(reasons, ', ')
                ), playerId)
            end
            return
        end
    end
    
    -- ========================================================================
    -- STEP 4: Record violation
    -- ========================================================================
    
    local thresholdReached, count, threshold, action = ViolationManager.RecordViolation(
        playerId, detectionType, details, severity
    )
    
    if action == 'COOLDOWN' then
        -- In cooldown, don't process further
        return
    end
    
    -- ========================================================================
    -- STEP 5: Take action if threshold reached
    -- ========================================================================
    
    if thresholdReached then
        ViolationManager.TakeAction(playerId, detectionType, action, {
            count = count,
            threshold = threshold,
            details = details,
            severity = severity
        })
    end
end

-- ============================================================================
-- TAKE ACTION
-- ============================================================================

function ViolationManager.TakeAction(playerId, detectionType, action, context)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetPlayerIdentifiers(playerId)
    
    context = context or {}
    
    -- Log action
    if Log then
        Log('CRITICAL', detectionType, string.format(
            'Taking action: %s (violations: %d/%d)',
            action,
            context.count or 0,
            context.threshold or 0
        ), playerId, context.details)
    end
    
    -- Send Discord alert
    if Config.Discord and Config.Discord.Enabled then
        ViolationManager.SendActionWebhook(playerId, playerName, detectionType, action, context, identifiers)
    end
    
    -- Execute action
    if action == 'KICK' then
        DropPlayer(playerId, string.format(
            '[LucidGuard] Kicked: %s violations exceeded threshold',
            detectionType
        ))
        
    elseif action == 'BAN' then
        -- Try to use punishment system if available
        if TriggerEvent then
            TriggerEvent('lucidguard:punish', playerId, detectionType, 
                context.details and context.details.reason or 'Threshold exceeded')
        else
            DropPlayer(playerId, string.format(
                '[LucidGuard] Banned: %s',
                detectionType
            ))
        end
        
    elseif action == 'FLAG' then
        -- Just flag for review, don't kick
        if Log then
            Log('ALERT', detectionType, 'Player flagged for review', playerId, context)
        end
        
        -- Shadowban if enabled
        if Config.Modules.Shadowban and TriggerEvent then
            TriggerEvent('lucidguard:shadowban', playerId, detectionType)
        end
        
    elseif action == 'WARN' then
        -- Send warning to player
        TriggerClientEvent('chat:addMessage', playerId, {
            color = { 255, 0, 0 },
            multiline = true,
            args = { '[LucidGuard]', 'Warning: Suspicious activity detected. Continued violations will result in removal.' }
        })
    end
    
    -- Clear violations after action
    ViolationManager.ClearViolations(playerId, detectionType)
end

-- ============================================================================
-- DISCORD WEBHOOK
-- ============================================================================

function ViolationManager.SendActionWebhook(playerId, playerName, detectionType, action, context, identifiers)
    local actionColors = {
        KICK = 16744448,    -- Orange
        BAN = 16711680,     -- Red
        FLAG = 16776960,    -- Yellow
        WARN = 3447003      -- Blue
    }
    
    local actionEmojis = {
        KICK = '🚫',
        BAN = '⛔',
        FLAG = '🚩',
        WARN = '⚠️'
    }
    
    local fields = {
        { name = 'Player', value = playerName, inline = true },
        { name = 'Server ID', value = tostring(playerId), inline = true },
        { name = 'Detection', value = detectionType, inline = true },
        { name = 'Action', value = action, inline = true },
        { name = 'Violations', value = string.format('%d/%d', context.count or 0, context.threshold or 0), inline = true },
        { name = 'Severity', value = context.severity or 'UNKNOWN', inline = true }
    }
    
    if context.details and context.details.reason then
        table.insert(fields, { name = 'Reason', value = context.details.reason, inline = false })
    end
    
    if identifiers and #identifiers > 0 then
        local idStr = table.concat(identifiers, '\n')
        if #idStr > 1000 then idStr = idStr:sub(1, 1000) .. '...' end
        table.insert(fields, { name = 'Identifiers', value = '```' .. idStr .. '```', inline = false })
    end
    
    local embed = {
        title = string.format('%s Action Taken: %s', actionEmojis[action] or '❓', action),
        description = string.format('Detection type: **%s**', detectionType),
        color = actionColors[action] or 8421504,
        fields = fields,
        footer = { text = 'LucidGuard Anticheat • Violation Manager' },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }
    
    PerformHttpRequest(Config.Discord.WebhookURL, function() end, 'POST',
        json.encode({ embeds = { embed } }),
        { ['Content-Type'] = 'application/json' })
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

function ViolationManager.GetViolationCount(playerId, detectionType)
    if not playerViolations[playerId] then return 0 end
    if not playerViolations[playerId][detectionType] then return 0 end
    return playerViolations[playerId][detectionType].count
end

function ViolationManager.GetAllViolations(playerId)
    return playerViolations[playerId] or {}
end

function ViolationManager.ClearViolations(playerId, detectionType)
    if not playerViolations[playerId] then return end
    
    if detectionType then
        playerViolations[playerId][detectionType] = nil
    else
        playerViolations[playerId] = nil
    end
end

function ViolationManager.ResetAllViolations()
    playerViolations = {}
    lastViolationTime = {}
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    
    -- Keep violation history for 30 minutes for logging purposes
    SetTimeout(1800000, function()
        playerViolations[src] = nil
        lastViolationTime[src] = nil
    end)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ProcessDetection', ViolationManager.ProcessDetection)
exports('RecordViolation', ViolationManager.RecordViolation)
exports('GetViolationCount', ViolationManager.GetViolationCount)
exports('GetAllViolations', ViolationManager.GetAllViolations)
exports('ClearViolations', ViolationManager.ClearViolations)
exports('TakeAction', ViolationManager.TakeAction)
exports('GetThreshold', ViolationManager.GetThreshold)

-- Global access for other modules
_G.ViolationManager = ViolationManager

print('[^2LucidGuard^0] Violation Manager loaded')
