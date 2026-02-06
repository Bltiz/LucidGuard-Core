--[[
    LucidGuard Anticheat - Player Safety System
    by OnlyLucidVibes
    
    ⚠️ CRITICAL MODULE ⚠️
    
    This module ensures legitimate players NEVER get falsely banned.
    It adds multiple layers of protection against false positives.
    
    Philosophy: It's better to let 10 cheaters through than ban 1 innocent player.
]]

local PlayerSafety = {}

-- ============================================================================
-- SAFE MODE CONFIGURATION
-- ============================================================================

-- When enabled, the system will LOG but NOT BAN for the first X hours
-- This allows you to review detections before enabling auto-bans
local SAFE_MODE = {
    Enabled = true,                     -- START WITH THIS ON!
    Duration = 72,                      -- Hours to run in safe mode (3 days)
    StartTime = nil,                    -- Set on first load
    LogOnly = true,                     -- Only log, don't kick/ban
    NotifyAdmins = true                 -- Send Discord alerts for review
}

-- ============================================================================
-- BANNED ACTION WHITELIST
-- ============================================================================

-- These scenarios should NEVER result in a ban
local NEVER_BAN_SCENARIOS = {
    -- Time-based
    'PLAYER_JUST_JOINED',               -- Within 60 seconds of joining
    'PLAYER_JUST_SPAWNED',              -- Within 30 seconds of spawning
    'PLAYER_JUST_DIED',                 -- Within 30 seconds of death
    'PLAYER_LOADING',                   -- Player is still loading
    
    -- State-based
    'PLAYER_IN_CUTSCENE',               -- In any cutscene
    'PLAYER_IN_INTERIOR_TRANSITION',    -- Changing interiors
    'PLAYER_IN_VEHICLE_TRANSITION',     -- Getting in/out of vehicle
    'PLAYER_RAGDOLL',                   -- In ragdoll physics
    'PLAYER_SWIMMING',                  -- Swimming/underwater
    'PLAYER_FALLING',                   -- Falling from height
    'PLAYER_PARACHUTING',               -- Using parachute
    
    -- Network-based
    'PLAYER_HIGH_PING',                 -- Ping > 250ms
    'PLAYER_PING_SPIKE',                -- Recent ping spike
    'PLAYER_PACKET_LOSS',               -- Experiencing packet loss
    
    -- Server-based
    'SERVER_JUST_STARTED',              -- Within 5 minutes of server start
    'SERVER_RESTARTING',                -- Server is restarting
    'RESOURCE_RESTARTING'               -- Anticheat resource restarting
}

-- ============================================================================
-- DETECTION SAFETY MULTIPLIERS
-- ============================================================================

-- Multiply all thresholds by these values for extra safety
local SAFETY_MULTIPLIERS = {
    SPEED = 1.5,            -- 50% more tolerance for speed
    TELEPORT = 2.0,         -- 100% more tolerance for teleport distance
    GODMODE = 1.5,          -- 50% more tolerance for health checks
    NOCLIP = 2.0,           -- 100% more tolerance for ground checks
    AIMBOT = 2.0,           -- 100% more tolerance (skilled players exist!)
    DAMAGE = 1.5,           -- 50% more tolerance for damage
    WEAPON = 1.0,           -- Normal (weapon blacklist is explicit)
    LAG_SWITCH = 2.0        -- 100% more tolerance (bad internet exists)
}

-- ============================================================================
-- MINIMUM VIOLATION REQUIREMENTS
-- ============================================================================

-- Minimum violations required before ANY action (overrides config)
local MINIMUM_VIOLATIONS = {
    -- These require MANY violations before action
    SPEED = 10,             -- Need 10 speed violations minimum
    TELEPORT = 5,           -- Need 5 teleport violations minimum
    NOCLIP = 8,             -- Need 8 noclip violations minimum
    AIMBOT = 10,            -- Need 10 aimbot flags (good players exist!)
    LAG_SWITCH = 8,         -- Need 8 lag switch flags
    
    -- These can act faster (more definitive cheats)
    GODMODE = 5,            -- Need 5 godmode violations
    WEAPON_BLACKLIST = 3,   -- Need 3 blacklisted weapon detections
    
    -- These are NEVER auto-banned (review required)
    FILE_TAMPERING = 999,   -- Flag only, manual review
    RESOURCE_INJECT = 999,  -- Flag only, manual review
    MENU_TRAP = 999,        -- Flag only, manual review
    STATE_BAG_HACK = 999    -- Flag only, manual review
}

-- ============================================================================
-- TIME WINDOWS (Longer = Safer)
-- ============================================================================

-- Violations must occur within these windows to count
local VIOLATION_WINDOWS = {
    SPEED = 120000,         -- 2 minutes (was 60s)
    TELEPORT = 180000,      -- 3 minutes (was 60s)
    GODMODE = 180000,       -- 3 minutes
    NOCLIP = 120000,        -- 2 minutes
    AIMBOT = 300000,        -- 5 minutes (skilled players have good streaks)
    LAG_SWITCH = 300000,    -- 5 minutes
    DEFAULT = 120000        -- 2 minutes default
}

-- ============================================================================
-- PLAYER PROTECTION TRACKING
-- ============================================================================

local playerProtection = {}
local serverStartTime = os.time()

function PlayerSafety.InitPlayer(playerId)
    playerProtection[playerId] = {
        joinTime = os.time(),
        lastSpawn = os.time(),
        lastDeath = nil,
        isLoading = true,
        scenarios = {},
        violations = {},
        lastViolation = {},
        isFlagged = false,
        reviewQueue = {}
    }
end

-- ============================================================================
-- SCENARIO CHECKING
-- ============================================================================

function PlayerSafety.HasScenario(playerId, scenario)
    if not playerProtection[playerId] then
        PlayerSafety.InitPlayer(playerId)
    end
    return playerProtection[playerId].scenarios[scenario] == true
end

function PlayerSafety.SetScenario(playerId, scenario, active)
    if not playerProtection[playerId] then
        PlayerSafety.InitPlayer(playerId)
    end
    playerProtection[playerId].scenarios[scenario] = active
end

function PlayerSafety.CheckAllScenarios(playerId)
    if not playerProtection[playerId] then
        PlayerSafety.InitPlayer(playerId)
    end
    
    local pp = playerProtection[playerId]
    local now = os.time()
    local reasons = {}
    
    -- Time-based scenarios
    if (now - pp.joinTime) < 60 then
        table.insert(reasons, 'PLAYER_JUST_JOINED')
    end
    
    if pp.lastSpawn and (now - pp.lastSpawn) < 30 then
        table.insert(reasons, 'PLAYER_JUST_SPAWNED')
    end
    
    if pp.lastDeath and (now - pp.lastDeath) < 30 then
        table.insert(reasons, 'PLAYER_JUST_DIED')
    end
    
    if pp.isLoading then
        table.insert(reasons, 'PLAYER_LOADING')
    end
    
    -- Server-based scenarios
    if (now - serverStartTime) < 300 then
        table.insert(reasons, 'SERVER_JUST_STARTED')
    end
    
    -- Network-based scenarios
    local ping = GetPlayerPing(playerId)
    if ping and ping > 250 then
        table.insert(reasons, 'PLAYER_HIGH_PING')
    end
    
    -- Check active scenarios from FalsePositive module
    if FalsePositive then
        if FalsePositive.HasState(playerId, 'SPAWNING') or FalsePositive.InCooldown(playerId, 'SPAWNING') then
            table.insert(reasons, 'PLAYER_JUST_SPAWNED')
        end
        if FalsePositive.HasState(playerId, 'DEAD') or FalsePositive.InCooldown(playerId, 'DEAD') then
            table.insert(reasons, 'PLAYER_JUST_DIED')
        end
        if FalsePositive.HasState(playerId, 'CUTSCENE') or FalsePositive.InCooldown(playerId, 'CUTSCENE') then
            table.insert(reasons, 'PLAYER_IN_CUTSCENE')
        end
        if FalsePositive.HasState(playerId, 'INTERIOR') or FalsePositive.InCooldown(playerId, 'INTERIOR') then
            table.insert(reasons, 'PLAYER_IN_INTERIOR_TRANSITION')
        end
        if FalsePositive.HasState(playerId, 'VEHICLE_ENTER') or FalsePositive.InCooldown(playerId, 'VEHICLE_ENTER') then
            table.insert(reasons, 'PLAYER_IN_VEHICLE_TRANSITION')
        end
        if FalsePositive.HasState(playerId, 'RAGDOLL') or FalsePositive.InCooldown(playerId, 'RAGDOLL') then
            table.insert(reasons, 'PLAYER_RAGDOLL')
        end
        if FalsePositive.HasState(playerId, 'SWIMMING') or FalsePositive.InCooldown(playerId, 'SWIMMING') then
            table.insert(reasons, 'PLAYER_SWIMMING')
        end
        if FalsePositive.HasState(playerId, 'FALLING') or FalsePositive.InCooldown(playerId, 'FALLING') then
            table.insert(reasons, 'PLAYER_FALLING')
        end
    end
    
    return reasons
end

-- ============================================================================
-- MAIN SAFETY CHECK - Call this before ANY punishment
-- ============================================================================

function PlayerSafety.CanPunish(playerId, detectionType, severity)
    local playerName = GetPlayerName(playerId)
    if not playerName then return false, 'Invalid player' end
    
    local blockReasons = {}
    
    -- ========================================================================
    -- CHECK 1: Safe Mode Active
    -- ========================================================================
    
    if SAFE_MODE.Enabled and SAFE_MODE.LogOnly then
        table.insert(blockReasons, 'SAFE_MODE_ACTIVE')
    end
    
    -- ========================================================================
    -- CHECK 2: Protected Scenarios
    -- ========================================================================
    
    local scenarios = PlayerSafety.CheckAllScenarios(playerId)
    for _, scenario in ipairs(scenarios) do
        for _, protected in ipairs(NEVER_BAN_SCENARIOS) do
            if scenario == protected then
                table.insert(blockReasons, scenario)
            end
        end
    end
    
    -- ========================================================================
    -- CHECK 3: Admin Immunity
    -- ========================================================================
    
    if IsPlayerAdmin and IsPlayerAdmin(playerId) then
        table.insert(blockReasons, 'ADMIN_IMMUNITY')
    end
    
    -- ========================================================================
    -- CHECK 4: Minimum Violations Not Met
    -- ========================================================================
    
    local minViolations = MINIMUM_VIOLATIONS[detectionType] or 5
    local currentViolations = PlayerSafety.GetViolationCount(playerId, detectionType)
    
    if currentViolations < minViolations then
        table.insert(blockReasons, string.format('MIN_VIOLATIONS_NOT_MET (%d/%d)', 
            currentViolations, minViolations))
    end
    
    -- ========================================================================
    -- CHECK 5: Review-Only Detections
    -- ========================================================================
    
    local reviewOnly = {
        'FILE_TAMPERING', 'RESOURCE_INJECT', 'MENU_TRAP', 
        'STATE_BAG_HACK', 'EXTERNAL_ESP'
    }
    
    for _, detection in ipairs(reviewOnly) do
        if detectionType == detection then
            table.insert(blockReasons, 'REQUIRES_MANUAL_REVIEW')
            break
        end
    end
    
    -- ========================================================================
    -- CHECK 6: High Ping Protection
    -- ========================================================================
    
    local ping = GetPlayerPing(playerId)
    if ping and ping > 200 then
        -- Movement cheats are unreliable with high ping
        local pingAffected = { 'SPEED', 'TELEPORT', 'NOCLIP', 'LAG_SWITCH' }
        for _, affected in ipairs(pingAffected) do
            if detectionType == affected then
                table.insert(blockReasons, string.format('HIGH_PING_PROTECTION (%dms)', ping))
                break
            end
        end
    end
    
    -- ========================================================================
    -- RESULT
    -- ========================================================================
    
    local canPunish = #blockReasons == 0
    
    -- Log the decision
    if not canPunish then
        if Log then
            Log('INFO', 'SAFETY', string.format(
                'Punishment BLOCKED for %s - Reasons: %s',
                playerName,
                table.concat(blockReasons, ', ')
            ), playerId, {
                ['Detection'] = detectionType,
                ['Severity'] = severity,
                ['BlockReasons'] = blockReasons
            })
        end
        
        -- Add to review queue instead
        PlayerSafety.AddToReviewQueue(playerId, detectionType, severity, blockReasons)
    end
    
    return canPunish, blockReasons
end

-- ============================================================================
-- REVIEW QUEUE (Instead of banning, flag for admin review)
-- ============================================================================

local reviewQueue = {}

function PlayerSafety.AddToReviewQueue(playerId, detectionType, severity, reasons)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetPlayerIdentifiers(playerId)
    
    local entry = {
        playerId = playerId,
        playerName = playerName,
        identifiers = identifiers,
        detectionType = detectionType,
        severity = severity,
        blockReasons = reasons,
        timestamp = os.time(),
        reviewed = false
    }
    
    table.insert(reviewQueue, entry)
    
    -- Discord notification for admins
    if Config.Discord and Config.Discord.Enabled and SAFE_MODE.NotifyAdmins then
        local embed = {
            title = '📋 Detection Flagged for Review',
            description = 'A detection was blocked by safety systems and requires manual review.',
            color = 16776960, -- Yellow
            fields = {
                { name = 'Player', value = playerName, inline = true },
                { name = 'Server ID', value = tostring(playerId), inline = true },
                { name = 'Detection', value = detectionType, inline = true },
                { name = 'Severity', value = severity, inline = true },
                { name = 'Block Reasons', value = table.concat(reasons, '\n'), inline = false },
                { name = '⚠️ Action Required', value = 'Please review this detection manually before taking action.', inline = false }
            },
            footer = { text = 'LucidGuard Safety System • Review Queue' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
        
        PerformHttpRequest(Config.Discord.WebhookURL, function() end, 'POST',
            json.encode({ embeds = { embed } }),
            { ['Content-Type'] = 'application/json' })
    end
    
    return entry
end

-- ============================================================================
-- VIOLATION TRACKING (with safety multipliers)
-- ============================================================================

function PlayerSafety.RecordViolation(playerId, detectionType)
    if not playerProtection[playerId] then
        PlayerSafety.InitPlayer(playerId)
    end
    
    local pp = playerProtection[playerId]
    local now = os.time()
    local window = VIOLATION_WINDOWS[detectionType] or VIOLATION_WINDOWS.DEFAULT
    
    if not pp.violations[detectionType] then
        pp.violations[detectionType] = {}
    end
    
    -- Add violation
    table.insert(pp.violations[detectionType], now)
    pp.lastViolation[detectionType] = now
    
    -- Clean old violations
    local cutoff = now - (window / 1000)
    local newViolations = {}
    for _, timestamp in ipairs(pp.violations[detectionType]) do
        if timestamp > cutoff then
            table.insert(newViolations, timestamp)
        end
    end
    pp.violations[detectionType] = newViolations
    
    return #pp.violations[detectionType]
end

function PlayerSafety.GetViolationCount(playerId, detectionType)
    if not playerProtection[playerId] then return 0 end
    if not playerProtection[playerId].violations[detectionType] then return 0 end
    return #playerProtection[playerId].violations[detectionType]
end

-- ============================================================================
-- SAFETY MULTIPLIER APPLICATION
-- ============================================================================

function PlayerSafety.ApplySafetyMultiplier(detectionType, value)
    local multiplier = SAFETY_MULTIPLIERS[detectionType] or 1.0
    return value * multiplier
end

function PlayerSafety.GetSafeThreshold(detectionType, baseThreshold)
    return PlayerSafety.ApplySafetyMultiplier(detectionType, baseThreshold)
end

-- ============================================================================
-- EVENTS
-- ============================================================================

AddEventHandler('playerJoining', function()
    PlayerSafety.InitPlayer(source)
end)

AddEventHandler('playerDropped', function()
    playerProtection[source] = nil
end)

RegisterNetEvent('LucidGuard:PlayerSpawned', function()
    local src = source
    if playerProtection[src] then
        playerProtection[src].lastSpawn = os.time()
        playerProtection[src].isLoading = false
    end
end)

RegisterNetEvent('LucidGuard:PlayerDied', function()
    local src = source
    if playerProtection[src] then
        playerProtection[src].lastDeath = os.time()
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('CanPunish', PlayerSafety.CanPunish)
exports('AddToReviewQueue', PlayerSafety.AddToReviewQueue)
exports('GetSafeThreshold', PlayerSafety.GetSafeThreshold)
exports('ApplySafetyMultiplier', PlayerSafety.ApplySafetyMultiplier)
exports('RecordSafetyViolation', PlayerSafety.RecordViolation)
exports('GetSafetyViolationCount', PlayerSafety.GetViolationCount)
exports('CheckAllScenarios', PlayerSafety.CheckAllScenarios)

-- Global access
_G.PlayerSafety = PlayerSafety

print('[^2LucidGuard^0] ⚠️  Player Safety System loaded')
print('[^3LucidGuard^0] ⚠️  SAFE MODE is ENABLED - Detections will be LOGGED but NOT BANNED')
print('[^3LucidGuard^0] ⚠️  Review Discord alerts before disabling Safe Mode')
