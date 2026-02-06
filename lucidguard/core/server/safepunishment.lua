--[[
    LucidGuard Anticheat - Safe Punishment Handler
    by OnlyLucidVibes
    
    This module replaces direct kicks/bans with a safe review process.
    All punishments go through this handler which ensures innocent players
    are NEVER falsely banned.
]]

local SafePunishment = {}

-- ============================================================================
-- PUNISHMENT QUEUE (Not immediate action)
-- ============================================================================

local pendingPunishments = {}
local confirmedCheaters = {}  -- Only after manual review or EXTREME evidence

-- ============================================================================
-- PUNISHMENT SEVERITY LEVELS
-- ============================================================================

local SEVERITY = {
    LOG_ONLY = 1,       -- Just log, no action
    FLAG = 2,           -- Flag for review
    WARN = 3,           -- Send warning to player
    SOFT_KICK = 4,      -- Kick with reconnect allowed
    HARD_KICK = 5,      -- Kick, add to watchlist
    TEMP_BAN = 6,       -- Temporary ban (manual review)
    PERM_BAN = 7        -- Permanent ban (requires confirmation)
}

-- ============================================================================
-- DETECTION SEVERITY MAPPING (Conservative by default)
-- ============================================================================

local DEFAULT_SEVERITY = {
    -- Movement (LOTS of false positives possible)
    SPEED = SEVERITY.FLAG,
    TELEPORT = SEVERITY.FLAG,
    NOCLIP = SEVERITY.FLAG,
    FLY = SEVERITY.FLAG,
    
    -- Combat (Good players can look like aimbots)
    AIMBOT = SEVERITY.LOG_ONLY,
    DAMAGE_MODIFIER = SEVERITY.FLAG,
    
    -- Health (Many legitimate reasons for invincibility)
    GODMODE = SEVERITY.FLAG,
    HEALTH_HACK = SEVERITY.FLAG,
    
    -- Weapons (More definitive)
    WEAPON_BLACKLIST = SEVERITY.WARN,
    WEAPON_DAMAGE = SEVERITY.FLAG,
    
    -- Network (BAD INTERNET EXISTS!)
    LAG_SWITCH = SEVERITY.LOG_ONLY,
    
    -- Advanced (Require manual review)
    FILE_TAMPERING = SEVERITY.FLAG,
    RESOURCE_INJECT = SEVERITY.FLAG,
    MENU_TRAP = SEVERITY.FLAG,
    STATE_BAG_HACK = SEVERITY.FLAG,
    EXTERNAL_ESP = SEVERITY.FLAG,
    
    -- Definitive cheats (Still warn first)
    VEHICLE_SPAWN = SEVERITY.WARN,
    PED_SPAWN = SEVERITY.WARN,
    MONEY_CHEAT = SEVERITY.FLAG
}

-- ============================================================================
-- ESCALATION THRESHOLDS
-- ============================================================================

-- How many times before we escalate severity?
local ESCALATION = {
    FLAG_TO_WARN = 5,           -- 5 flags before warning
    WARN_TO_SOFT_KICK = 3,      -- 3 warnings before soft kick
    SOFT_KICK_TO_HARD_KICK = 2, -- 2 soft kicks before hard kick
    HARD_KICK_TO_REVIEW = 1     -- Any hard kick goes to manual review
}

-- ============================================================================
-- SAFE PUNISHMENT FUNCTION
-- ============================================================================

function SafePunishment.Process(playerId, detectionType, details, confidence)
    local playerName = GetPlayerName(playerId)
    if not playerName then return end
    
    confidence = confidence or 0.5  -- Default 50% confidence
    
    -- ========================================================================
    -- STEP 1: Check if we can even consider punishment
    -- ========================================================================
    
    if PlayerSafety then
        local canPunish, reasons = PlayerSafety.CanPunish(playerId, detectionType, 'CHECK')
        if not canPunish then
            -- Already logged by PlayerSafety, just return
            return
        end
    end
    
    -- ========================================================================
    -- STEP 2: Determine severity based on detection type
    -- ========================================================================
    
    local severity = DEFAULT_SEVERITY[detectionType] or SEVERITY.FLAG
    
    -- ========================================================================
    -- STEP 3: Check player's history for this detection
    -- ========================================================================
    
    if not pendingPunishments[playerId] then
        pendingPunishments[playerId] = {}
    end
    
    if not pendingPunishments[playerId][detectionType] then
        pendingPunishments[playerId][detectionType] = {
            count = 0,
            flags = 0,
            warnings = 0,
            kicks = 0,
            firstSeen = os.time(),
            lastSeen = os.time()
        }
    end
    
    local history = pendingPunishments[playerId][detectionType]
    history.count = history.count + 1
    history.lastSeen = os.time()
    
    -- ========================================================================
    -- STEP 4: Check confidence threshold
    -- ========================================================================
    
    -- Require higher confidence for harsher punishments
    local requiredConfidence = {
        [SEVERITY.LOG_ONLY] = 0.0,
        [SEVERITY.FLAG] = 0.3,
        [SEVERITY.WARN] = 0.6,
        [SEVERITY.SOFT_KICK] = 0.75,
        [SEVERITY.HARD_KICK] = 0.85,
        [SEVERITY.TEMP_BAN] = 0.95,
        [SEVERITY.PERM_BAN] = 0.99
    }
    
    if confidence < (requiredConfidence[severity] or 0.5) then
        -- Downgrade severity due to low confidence
        severity = SEVERITY.LOG_ONLY
    end
    
    -- ========================================================================
    -- STEP 5: Execute appropriate action
    -- ========================================================================
    
    if severity == SEVERITY.LOG_ONLY then
        SafePunishment.LogOnly(playerId, detectionType, details, confidence)
        
    elseif severity == SEVERITY.FLAG then
        history.flags = history.flags + 1
        SafePunishment.Flag(playerId, detectionType, details, confidence)
        
        -- Check for escalation
        if history.flags >= ESCALATION.FLAG_TO_WARN then
            SafePunishment.Warn(playerId, detectionType, details, confidence)
            history.warnings = history.warnings + 1
            history.flags = 0  -- Reset flags
        end
        
    elseif severity == SEVERITY.WARN then
        history.warnings = history.warnings + 1
        SafePunishment.Warn(playerId, detectionType, details, confidence)
        
        -- Check for escalation
        if history.warnings >= ESCALATION.WARN_TO_SOFT_KICK then
            SafePunishment.SoftKick(playerId, detectionType, details, confidence)
            history.kicks = history.kicks + 1
            history.warnings = 0
        end
        
    elseif severity == SEVERITY.SOFT_KICK then
        history.kicks = history.kicks + 1
        SafePunishment.SoftKick(playerId, detectionType, details, confidence)
        
    elseif severity >= SEVERITY.HARD_KICK then
        -- HARD KICK and above ALWAYS goes to review queue
        SafePunishment.SendToReview(playerId, detectionType, details, confidence, severity)
    end
end

-- ============================================================================
-- PUNISHMENT IMPLEMENTATIONS
-- ============================================================================

function SafePunishment.LogOnly(playerId, detectionType, details, confidence)
    if Log then
        Log('DEBUG', detectionType, string.format(
            'Detection logged (no action) - Confidence: %.1f%%',
            confidence * 100
        ), playerId, details)
    end
end

function SafePunishment.Flag(playerId, detectionType, details, confidence)
    if Log then
        Log('INFO', detectionType, string.format(
            'Player flagged for monitoring - Confidence: %.1f%%',
            confidence * 100
        ), playerId, details)
    end
    
    -- Discord notification (if enabled)
    if Config.Discord and Config.Discord.Enabled then
        local playerName = GetPlayerName(playerId) or 'Unknown'
        local embed = {
            title = '🚩 Player Flagged',
            description = 'A player has been flagged for suspicious activity.',
            color = 16776960,  -- Yellow
            fields = {
                { name = 'Player', value = playerName, inline = true },
                { name = 'Detection', value = detectionType, inline = true },
                { name = 'Confidence', value = string.format('%.1f%%', confidence * 100), inline = true },
                { name = 'Action', value = 'Monitoring (no action taken)', inline = false }
            },
            footer = { text = 'LucidGuard Safe Mode • Flag Only' }
        }
        
        PerformHttpRequest(Config.Discord.WebhookURL, function() end, 'POST',
            json.encode({ embeds = { embed } }),
            { ['Content-Type'] = 'application/json' })
    end
end

function SafePunishment.Warn(playerId, detectionType, details, confidence)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    
    if Log then
        Log('WARN', detectionType, string.format(
            'Warning issued - Confidence: %.1f%%',
            confidence * 100
        ), playerId, details)
    end
    
    -- Send warning to player (NOT a kick)
    TriggerClientEvent('chat:addMessage', playerId, {
        color = { 255, 165, 0 },
        multiline = true,
        args = { 
            '[LucidGuard]', 
            'Suspicious activity detected. Please play fairly. Continued violations may result in removal.'
        }
    })
    
    -- Discord notification
    if Config.Discord and Config.Discord.Enabled then
        local embed = {
            title = '⚠️ Warning Issued',
            description = 'A player has been warned for suspicious activity.',
            color = 16744448,  -- Orange
            fields = {
                { name = 'Player', value = playerName, inline = true },
                { name = 'Detection', value = detectionType, inline = true },
                { name = 'Confidence', value = string.format('%.1f%%', confidence * 100), inline = true }
            },
            footer = { text = 'LucidGuard Safe Mode • Warning Only' }
        }
        
        PerformHttpRequest(Config.Discord.WebhookURL, function() end, 'POST',
            json.encode({ embeds = { embed } }),
            { ['Content-Type'] = 'application/json' })
    end
end

function SafePunishment.SoftKick(playerId, detectionType, details, confidence)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    
    if Log then
        Log('ALERT', detectionType, string.format(
            'Soft kick executed - Confidence: %.1f%%',
            confidence * 100
        ), playerId, details)
    end
    
    -- Discord notification BEFORE kick
    if Config.Discord and Config.Discord.Enabled then
        local embed = {
            title = '🚫 Soft Kick',
            description = 'A player has been kicked (can rejoin).',
            color = 16711680,  -- Red
            fields = {
                { name = 'Player', value = playerName, inline = true },
                { name = 'Detection', value = detectionType, inline = true },
                { name = 'Confidence', value = string.format('%.1f%%', confidence * 100), inline = true },
                { name = 'Note', value = 'Player can rejoin. If this happens repeatedly, consider manual review.', inline = false }
            },
            footer = { text = 'LucidGuard Safe Mode' }
        }
        
        PerformHttpRequest(Config.Discord.WebhookURL, function() end, 'POST',
            json.encode({ embeds = { embed } }),
            { ['Content-Type'] = 'application/json' })
    end
    
    -- Kick with friendly message
    DropPlayer(playerId, 
        '🛡️ LucidGuard: Suspicious activity detected. You have been disconnected.\n' ..
        'If this was a mistake, you can rejoin the server.\n' ..
        'If this keeps happening, please contact server admins.'
    )
end

function SafePunishment.SendToReview(playerId, detectionType, details, confidence, severity)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetPlayerIdentifiers(playerId)
    
    if Log then
        Log('CRITICAL', detectionType, string.format(
            'Sent to manual review queue - Confidence: %.1f%%, Severity: %d',
            confidence * 100, severity
        ), playerId, details)
    end
    
    -- IMPORTANT: Do NOT kick or ban automatically
    -- Just send to Discord for manual review
    
    if Config.Discord and Config.Discord.Enabled then
        local identStr = ''
        for _, id in ipairs(identifiers or {}) do
            if id:find('discord:') or id:find('steam:') or id:find('license:') then
                identStr = identStr .. id .. '\n'
            end
        end
        
        local embed = {
            title = '🔴 MANUAL REVIEW REQUIRED',
            description = 'A severe detection requires manual admin review. **NO AUTO-BAN TAKEN.**',
            color = 10038562,  -- Dark red
            fields = {
                { name = 'Player', value = playerName, inline = true },
                { name = 'Server ID', value = tostring(playerId), inline = true },
                { name = 'Detection', value = detectionType, inline = true },
                { name = 'Confidence', value = string.format('%.1f%%', confidence * 100), inline = true },
                { name = 'Severity Level', value = tostring(severity), inline = true },
                { name = 'Player Still Connected', value = 'YES', inline = true },
                { name = 'Identifiers', value = identStr ~= '' and identStr or 'None available', inline = false },
                { name = '⚠️ IMPORTANT', value = 'This detection did NOT result in automatic action. Please review the evidence and take manual action if needed.', inline = false }
            },
            footer = { text = 'LucidGuard Safe Mode • Manual Review Required' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
        
        PerformHttpRequest(Config.Discord.WebhookURL, function() end, 'POST',
            json.encode({ embeds = { embed } }),
            { ['Content-Type'] = 'application/json' })
    end
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    pendingPunishments[source] = nil
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('SafePunish', SafePunishment.Process)
exports('LogOnly', SafePunishment.LogOnly)
exports('FlagPlayer', SafePunishment.Flag)
exports('WarnPlayer', SafePunishment.Warn)
exports('SoftKick', SafePunishment.SoftKick)
exports('SendToReview', SafePunishment.SendToReview)

-- Global access
_G.SafePunishment = SafePunishment

print('[^2LucidGuard^0] Safe Punishment Handler loaded')
print('[^3LucidGuard^0] All punishments will be reviewed before action')
