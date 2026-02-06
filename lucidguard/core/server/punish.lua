--[[
    LucidGuard Anticheat - Punishment System
    Created by OnlyLucidVibes
    Severity-based actions with admin review workflow
]]

-- ============================================================================
-- EXECUTE PUNISHMENT
-- ============================================================================

function ExecutePunishment(playerId, severity, detectionType, details)
    -- SafeMode: log only, never kick/ban
    if Config.PlayerSafety and Config.PlayerSafety.SafeMode
       and Config.PlayerSafety.SafeMode.Enabled
       and Config.PlayerSafety.SafeMode.LogOnly then
        Log('INFO', string.format('[SAFE MODE] Would have executed %s on %s (ID: %s) for %s - blocked by SafeMode',
            Config.Severity[severity] and Config.Severity[severity].Action or 'unknown',
            GetPlayerName(playerId) or 'Unknown', playerId, detectionType))
        return
    end

    -- Validate severity
    if not Config.Severity[severity] then
        Log('WARN', 'Unknown severity level: ' .. tostring(severity))
        return
    end
    
    local severityConfig = Config.Severity[severity]
    local action = severityConfig.Action
    local playerName = GetPlayerName(playerId) or 'Unknown'
    
    -- Log the action
    Log('ALERT', string.format('[%s] Executing %s action on %s (ID: %s) for %s',
        severity, action, playerName, playerId, detectionType))
    
    -- Execute based on action type
    if action == 'log' then
        -- Just logging - handled above and in Discord
        Log('INFO', string.format('LOW severity - Logged for admin review: %s', playerName))
        
    elseif action == 'kick' then
        -- Kick the player
        local kickMessage = severityConfig.KickMessage or 'You have been kicked by the anticheat.'
        
        -- Add detection type to kick message for player awareness
        kickMessage = kickMessage .. '\n\nDetection: ' .. detectionType
        
        -- Schedule kick (small delay to ensure Discord notification sends)
        CreateThread(function()
            Wait(500)
            DropPlayer(playerId, kickMessage)
            Log('ALERT', string.format('Player kicked: %s (ID: %s)', playerName, playerId))
        end)
        
    elseif action == 'ban' then
        -- Note: Since we're using txAdmin for bans, this just kicks with ban recommendation
        local kickMessage = severityConfig.KickMessage or 'You have been banned by the anticheat.'
        kickMessage = kickMessage .. '\n\nDetection: ' .. detectionType
        kickMessage = kickMessage .. '\n\nAppeal via txAdmin panel if you believe this is an error.'
        
        CreateThread(function()
            Wait(500)
            DropPlayer(playerId, kickMessage)
            Log('BAN', string.format('Player kicked (ban recommended): %s (ID: %s)', playerName, playerId))
        end)
    end
end

-- ============================================================================
-- SEVERITY ESCALATION
-- Not auto-escalating per user request - all requires admin review
-- This function can be called to check violation thresholds
-- ============================================================================

function CheckViolationThreshold(playerId, detectionType, currentViolations)
    -- Get threshold from config based on detection type
    local threshold = 3 -- Default
    
    if detectionType == 'SPEED_HACK' then
        threshold = Config.SpeedHack.ViolationsBeforeFlag
    elseif detectionType == 'TELEPORT' then
        threshold = Config.Teleport.ViolationsBeforeFlag
    elseif detectionType == 'GOD_MODE' then
        threshold = Config.GodMode.ViolationsBeforeFlag
    elseif detectionType == 'WEAPON_MOD' then
        threshold = Config.Weapons.ViolationsBeforeFlag
    elseif detectionType == 'NOCLIP' then
        threshold = Config.NoClip.ViolationsBeforeFlag
    end
    
    return currentViolations >= threshold
end

-- ============================================================================
-- DETERMINE SEVERITY
-- ============================================================================

function DetermineSeverity(detectionType, violations, additionalFactors)
    additionalFactors = additionalFactors or {}
    
    -- Critical detections - always CRITICAL
    local criticalDetections = {
        'GOD_MODE', 'MONEY_INJECTION', 'RESOURCE_INJECTION', 
        'EXECUTOR_DETECTED', 'CHEAT_MENU', 'INFINITE_AMMO'
    }
    
    -- High severity detections
    local highDetections = {
        'NOCLIP', 'TELEPORT_HACK', 'WEAPON_SPAWN', 'DAMAGE_MOD',
        'VEHICLE_SPAWN_ABUSE', 'ITEM_DUPLICATION'
    }
    
    -- Check for critical
    for _, crit in ipairs(criticalDetections) do
        if detectionType == crit then
            return 'CRITICAL'
        end
    end
    
    -- Check for high
    for _, high in ipairs(highDetections) do
        if detectionType == high then
            return 'HIGH'
        end
    end
    
    -- Check violation count for escalation
    if violations >= 5 then
        return 'HIGH'
    elseif violations >= 3 then
        return 'MEDIUM'
    end
    
    -- Default to LOW
    return 'LOW'
end

-- ============================================================================
-- HANDLE SPECIFIC DETECTIONS
-- ============================================================================

-- Speed hack detected
function HandleSpeedHack(playerId, speed, maxAllowed)
    local violations = AddViolation(playerId, 'SPEED_HACK')
    local details = string.format('Speed: %.2f m/s | Max allowed: %.2f m/s | Violations: %d', 
        speed, maxAllowed, violations)
    
    if CheckViolationThreshold(playerId, 'SPEED_HACK', violations) then
        ProcessDetection(playerId, 'SPEED_HACK', 'MEDIUM', details)
    else
        -- Just log, don't kick yet
        LogDetection('LOW', playerId, 'SPEED_HACK', details)
        if Config.Discord.Enabled then
            SendDiscordDetection(playerId, 'SPEED_HACK', 'LOW', details)
        end
    end
end

-- Teleport detected
function HandleTeleport(playerId, distance, timeMs)
    local violations = AddViolation(playerId, 'TELEPORT')
    local details = string.format('Distance: %.2f units in %dms | Violations: %d',
        distance, timeMs, violations)
    
    if CheckViolationThreshold(playerId, 'TELEPORT', violations) then
        ProcessDetection(playerId, 'TELEPORT_HACK', 'HIGH', details)
    else
        LogDetection('MEDIUM', playerId, 'TELEPORT', details)
        if Config.Discord.Enabled then
            SendDiscordDetection(playerId, 'TELEPORT', 'MEDIUM', details)
        end
    end
end

-- God mode detected
function HandleGodMode(playerId, details)
    -- God mode is always critical
    ProcessDetection(playerId, 'GOD_MODE', 'CRITICAL', details)
end

-- Weapon modification detected
function HandleWeaponMod(playerId, weaponHash, issue)
    local violations = AddViolation(playerId, 'WEAPON_MOD')
    local details = string.format('Weapon: %s | Issue: %s | Violations: %d',
        weaponHash, issue, violations)
    
    if CheckViolationThreshold(playerId, 'WEAPON_MOD', violations) then
        ProcessDetection(playerId, 'WEAPON_MOD', 'HIGH', details)
    else
        LogDetection('MEDIUM', playerId, 'WEAPON_MOD', details)
        if Config.Discord.Enabled then
            SendDiscordDetection(playerId, 'WEAPON_MOD', 'MEDIUM', details)
        end
    end
end

-- NoClip detected
function HandleNoClip(playerId, details)
    local violations = AddViolation(playerId, 'NOCLIP')
    local fullDetails = string.format('%s | Violations: %d', details, violations)
    
    if CheckViolationThreshold(playerId, 'NOCLIP', violations) then
        ProcessDetection(playerId, 'NOCLIP', 'HIGH', fullDetails)
    else
        LogDetection('MEDIUM', playerId, 'NOCLIP', fullDetails)
        if Config.Discord.Enabled then
            SendDiscordDetection(playerId, 'NOCLIP', 'MEDIUM', fullDetails)
        end
    end
end

-- Resource injection detected
function HandleResourceInjection(playerId, resourceName)
    local details = string.format('Suspicious resource detected: %s', resourceName)
    ProcessDetection(playerId, 'RESOURCE_INJECTION', 'CRITICAL', details)
end

-- Heartbeat missing
function HandleMissingHeartbeat(playerId, missedCount)
    local details = string.format('Missed %d heartbeats (potential tampering)', missedCount)
    
    if missedCount >= Config.Heartbeat.MaxMissedBeats then
        ProcessDetection(playerId, 'HEARTBEAT_MISSING', 'HIGH', details)
    else
        LogDetection('LOW', playerId, 'HEARTBEAT_MISSING', details)
    end
end

-- Economy exploit detected
function HandleEconomyExploit(playerId, exploitType, amount)
    local details = string.format('Type: %s | Amount: $%d', exploitType, amount)
    ProcessDetection(playerId, 'ECONOMY_EXPLOIT', 'CRITICAL', details)
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ExecutePunishment', ExecutePunishment)
exports('DetermineSeverity', DetermineSeverity)
exports('HandleSpeedHack', HandleSpeedHack)
exports('HandleTeleport', HandleTeleport)
exports('HandleGodMode', HandleGodMode)
exports('HandleWeaponMod', HandleWeaponMod)
exports('HandleNoClip', HandleNoClip)
exports('HandleResourceInjection', HandleResourceInjection)
exports('HandleMissingHeartbeat', HandleMissingHeartbeat)
exports('HandleEconomyExploit', HandleEconomyExploit)
