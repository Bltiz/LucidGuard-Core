--[[
    LucidGuard Anticheat - False Positive Prevention System
    by OnlyLucidVibes
    
    Comprehensive false positive prevention with:
    - Player state tracking (respawning, loading, teleporting legitimately)
    - Cooldown windows after state changes
    - Ping-based tolerance adjustments
    - Context-aware detection validation
    - Multi-violation confirmation before action
]]

local FalsePositive = {}

-- ============================================================================
-- PLAYER STATE TRACKING
-- ============================================================================

local playerStates = {}

-- State flags that indicate temporary immunity
local STATE_FLAGS = {
    SPAWNING = 'spawning',           -- Player is spawning/respawning
    LOADING = 'loading',             -- Player is loading into server
    TELEPORTING = 'teleporting',     -- Legitimate teleport in progress
    VEHICLE_ENTER = 'vehicle_enter', -- Entering/exiting vehicle
    CUTSCENE = 'cutscene',           -- In cutscene
    PAUSED = 'paused',               -- Game paused
    DEAD = 'dead',                   -- Player is dead
    FALLING = 'falling',             -- Player is falling
    SWIMMING = 'swimming',           -- Player is swimming
    RAGDOLL = 'ragdoll',             -- Player in ragdoll state
    MISSION = 'mission',             -- In mission/job activity
    INTERIOR = 'interior',            -- Transitioning interiors
    VEHICLE_SEAT_CHANGE = 'vehicle_seat_change' -- Changing seats in vehicle
}

-- Default immunity durations (ms) after state ends
local STATE_COOLDOWNS = {
    SPAWNING = 10000,       -- 10 seconds after spawn
    LOADING = 15000,        -- 15 seconds after loading
    TELEPORTING = 5000,     -- 5 seconds after teleport
    VEHICLE_ENTER = 3000,   -- 3 seconds after vehicle enter/exit
    CUTSCENE = 5000,        -- 5 seconds after cutscene
    PAUSED = 2000,          -- 2 seconds after unpause
    DEAD = 10000,           -- 10 seconds after death/respawn
    FALLING = 2000,         -- 2 seconds after landing
    SWIMMING = 2000,        -- 2 seconds after exiting water
    RAGDOLL = 3000,         -- 3 seconds after ragdoll
    MISSION = 5000,         -- 5 seconds after mission
    INTERIOR = 5000,        -- 5 seconds after interior transition
    VEHICLE_SEAT_CHANGE = 3000 -- 3 seconds after seat change
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

function FalsePositive.InitPlayer(playerId)
    playerStates[playerId] = {
        flags = {},
        cooldowns = {},
        lastPosition = nil,
        lastPositionTime = nil,
        positionStableFor = 0,
        lastHealth = nil,
        joinTime = GetGameTimer(),
        violations = {},
        ping = 0,
        pingHistory = {},
        lastChecked = {}
    }
end

function FalsePositive.SetState(playerId, state, active)
    if not playerStates[playerId] then
        FalsePositive.InitPlayer(playerId)
    end
    
    local ps = playerStates[playerId]
    
    if active then
        ps.flags[state] = GetGameTimer()
    else
        -- State ended - start cooldown
        ps.flags[state] = nil
        ps.cooldowns[state] = GetGameTimer() + (STATE_COOLDOWNS[state] or 5000)
    end
end

function FalsePositive.HasState(playerId, state)
    if not playerStates[playerId] then return false end
    return playerStates[playerId].flags[state] ~= nil
end

function FalsePositive.InCooldown(playerId, state)
    if not playerStates[playerId] then return false end
    
    local cooldownEnd = playerStates[playerId].cooldowns[state]
    if cooldownEnd and GetGameTimer() < cooldownEnd then
        return true
    end
    
    return false
end

-- Check if player has ANY immunity state active
function FalsePositive.HasAnyImmunity(playerId)
    if not playerStates[playerId] then return false end
    
    local ps = playerStates[playerId]
    
    -- Check active flags
    for state, _ in pairs(ps.flags) do
        return true
    end
    
    -- Check cooldowns
    local now = GetGameTimer()
    for state, cooldownEnd in pairs(ps.cooldowns) do
        if now < cooldownEnd then
            return true
        end
    end
    
    return false
end

-- ============================================================================
-- PING-BASED TOLERANCE
-- ============================================================================

function FalsePositive.UpdatePing(playerId)
    if not playerStates[playerId] then
        FalsePositive.InitPlayer(playerId)
    end
    
    local ping = GetPlayerPing(playerId) or 0
    local ps = playerStates[playerId]
    
    ps.ping = ping
    table.insert(ps.pingHistory, ping)
    
    -- Keep last 50 pings for a more stable average
    while #ps.pingHistory > 50 do
        table.remove(ps.pingHistory, 1)
    end
end

function FalsePositive.GetAveragePing(playerId)
    if not playerStates[playerId] then return 50 end
    
    local history = playerStates[playerId].pingHistory
    if #history == 0 then return 50 end
    
    local sum = 0
    for _, ping in ipairs(history) do
        sum = sum + ping
    end
    
    return sum / #history
end

-- Get tolerance multiplier based on ping
-- Higher ping = more tolerance to prevent false positives
function FalsePositive.GetPingTolerance(playerId)
    local avgPing = FalsePositive.GetAveragePing(playerId)
    
    if avgPing < 50 then
        return 1.0      -- Low ping, normal tolerance
    elseif avgPing < 100 then
        return 1.2      -- Moderate ping, 20% extra tolerance
    elseif avgPing < 150 then
        return 1.4      -- Higher ping, 40% extra tolerance
    elseif avgPing < 200 then
        return 1.6      -- High ping, 60% extra tolerance
    elseif avgPing < 300 then
        return 1.8      -- Very high ping, 80% extra tolerance
    else
        return 2.0      -- Extreme ping, double tolerance
    end
end

-- ============================================================================
-- POSITION STABILITY TRACKING
-- Used for dynamic join-time window (extends immunity if player is still
-- falling through the map while textures load)
-- ============================================================================

function FalsePositive.UpdatePosition(playerId, coords)
    if not playerStates[playerId] then return end
    local ps = playerStates[playerId]
    local now = GetGameTimer()

    if ps.lastPosition then
        local dist = #(vector3(coords.x, coords.y, coords.z) - ps.lastPosition)
        if dist < 5.0 then
            -- Position is stable (moved less than 5 units)
            ps.positionStableFor = (ps.positionStableFor or 0) + (now - (ps.lastPositionTime or now))
        else
            -- Position changed significantly, reset stability timer
            ps.positionStableFor = 0
        end
    end

    ps.lastPosition = vector3(coords.x, coords.y, coords.z)
    ps.lastPositionTime = now
end

-- ============================================================================
-- DETECTION VALIDATION
-- ============================================================================

-- Check if a detection should be validated (not a false positive)
function FalsePositive.ValidateDetection(playerId, detectionType, context)
    context = context or {}
    
    if not playerStates[playerId] then
        FalsePositive.InitPlayer(playerId)
    end
    
    local ps = playerStates[playerId]
    local reasons = {}
    local valid = true
    
    -- ========================================================================
    -- CHECK 1: Player recently joined (dynamic window)
    -- Instead of a hard 30s cutoff, we check if position has stabilized.
    -- Minimum 15s immunity, extends up to 120s if position is still unstable
    -- (player falling through map while textures/collision loads on slow HDDs)
    -- ========================================================================

    local timeSinceJoin = GetGameTimer() - ps.joinTime
    local posStable = ps.positionStableFor and ps.positionStableFor >= 5000
    local maxJoinWindow = 120000 -- Hard cap at 120s (slow HDDs need more time)

    if timeSinceJoin < maxJoinWindow then
        if timeSinceJoin < 15000 then
            -- Always give at least 15s immunity regardless of position
            table.insert(reasons, string.format('Recently joined (%ds ago)', timeSinceJoin / 1000))
            valid = false
        elseif not posStable then
            -- Position still unstable after 15s, keep immunity active
            table.insert(reasons, string.format('Recently joined, position not stable (%ds ago)', timeSinceJoin / 1000))
            valid = false
        end
        -- If posStable and > 15s, allow detections (player has loaded in)
    end
    
    -- ========================================================================
    -- CHECK 2: Active immunity states
    -- ========================================================================
    
    for state, timestamp in pairs(ps.flags) do
        table.insert(reasons, string.format('Active state: %s', state))
        valid = false
    end
    
    -- ========================================================================
    -- CHECK 3: Cooldown states
    -- ========================================================================
    
    local now = GetGameTimer()
    for state, cooldownEnd in pairs(ps.cooldowns) do
        if now < cooldownEnd then
            local remaining = (cooldownEnd - now) / 1000
            table.insert(reasons, string.format('Cooldown: %s (%.1fs remaining)', state, remaining))
            valid = false
        end
    end
    
    -- ========================================================================
    -- CHECK 4: Detection-specific validations
    -- ========================================================================
    
    if detectionType == 'SPEED' then
        -- Speed detection specific checks
        if FalsePositive.HasState(playerId, 'FALLING') or
           FalsePositive.InCooldown(playerId, 'FALLING') then
            table.insert(reasons, 'Player falling/landed recently')
            valid = false
        end

        if FalsePositive.HasState(playerId, 'VEHICLE_ENTER') or
           FalsePositive.InCooldown(playerId, 'VEHICLE_ENTER') then
            table.insert(reasons, 'Vehicle transition')
            valid = false
        end

        if FalsePositive.HasState(playerId, 'VEHICLE_SEAT_CHANGE') or
           FalsePositive.InCooldown(playerId, 'VEHICLE_SEAT_CHANGE') then
            table.insert(reasons, 'Vehicle seat change')
            valid = false
        end
    end

    if detectionType == 'TELEPORT' then
        -- Teleport specific checks
        if FalsePositive.HasState(playerId, 'TELEPORTING') or
           FalsePositive.InCooldown(playerId, 'TELEPORTING') then
            table.insert(reasons, 'Legitimate teleport')
            valid = false
        end

        if FalsePositive.HasState(playerId, 'INTERIOR') or
           FalsePositive.InCooldown(playerId, 'INTERIOR') then
            table.insert(reasons, 'Interior transition')
            valid = false
        end

        if FalsePositive.HasState(playerId, 'SPAWNING') or
           FalsePositive.InCooldown(playerId, 'SPAWNING') then
            table.insert(reasons, 'Spawning/respawning')
            valid = false
        end

        if FalsePositive.HasState(playerId, 'VEHICLE_SEAT_CHANGE') or
           FalsePositive.InCooldown(playerId, 'VEHICLE_SEAT_CHANGE') then
            table.insert(reasons, 'Vehicle seat change')
            valid = false
        end
    end
    
    if detectionType == 'GODMODE' then
        -- Godmode specific checks
        if FalsePositive.HasState(playerId, 'DEAD') or
           FalsePositive.InCooldown(playerId, 'DEAD') then
            table.insert(reasons, 'Recently died/respawned')
            valid = false
        end
        
        if FalsePositive.HasState(playerId, 'CUTSCENE') or
           FalsePositive.InCooldown(playerId, 'CUTSCENE') then
            table.insert(reasons, 'In/after cutscene')
            valid = false
        end
    end
    
    if detectionType == 'NOCLIP' then
        -- Noclip specific checks
        if FalsePositive.HasState(playerId, 'SWIMMING') or
           FalsePositive.InCooldown(playerId, 'SWIMMING') then
            table.insert(reasons, 'Swimming')
            valid = false
        end
        
        if FalsePositive.HasState(playerId, 'RAGDOLL') or
           FalsePositive.InCooldown(playerId, 'RAGDOLL') then
            table.insert(reasons, 'Ragdoll state')
            valid = false
        end
    end
    
    -- ========================================================================
    -- CHECK 5: High ping tolerance
    -- ========================================================================
    
    local avgPing = FalsePositive.GetAveragePing(playerId)
    if avgPing > 200 then
        table.insert(reasons, string.format('High ping (%dms avg)', avgPing))
        -- Don't invalidate, but note it
    end
    
    return valid, reasons
end

-- ============================================================================
-- MULTI-VIOLATION CONFIRMATION
-- ============================================================================

-- Require multiple violations within a time window before flagging
function FalsePositive.ConfirmViolation(playerId, detectionType, threshold, windowMs)
    threshold = threshold or 3
    windowMs = windowMs or 30000 -- 30 seconds default
    
    if not playerStates[playerId] then
        FalsePositive.InitPlayer(playerId)
    end
    
    local ps = playerStates[playerId]
    
    if not ps.violations[detectionType] then
        ps.violations[detectionType] = {}
    end
    
    local violations = ps.violations[detectionType]
    local now = GetGameTimer()
    
    -- Add new violation
    table.insert(violations, now)
    
    -- Remove old violations outside window
    local cutoff = now - windowMs
    local newViolations = {}
    for _, timestamp in ipairs(violations) do
        if timestamp > cutoff then
            table.insert(newViolations, timestamp)
        end
    end
    ps.violations[detectionType] = newViolations
    
    -- Check if threshold met
    local count = #ps.violations[detectionType]
    local confirmed = count >= threshold
    
    return confirmed, count, threshold
end

-- ============================================================================
-- RATE LIMITING CHECKS
-- ============================================================================

-- Prevent checking same thing too frequently
function FalsePositive.CanCheck(playerId, checkType, cooldownMs)
    cooldownMs = cooldownMs or 1000
    
    if not playerStates[playerId] then
        FalsePositive.InitPlayer(playerId)
    end
    
    local ps = playerStates[playerId]
    local lastCheck = ps.lastChecked[checkType]
    local now = GetGameTimer()
    
    if lastCheck and (now - lastCheck) < cooldownMs then
        return false
    end
    
    ps.lastChecked[checkType] = now
    return true
end

-- ============================================================================
-- STATE UPDATE EVENTS (Client -> Server)
-- ============================================================================

RegisterNetEvent('LucidGuard:UpdatePlayerState', function(state, active)
    local src = source

    -- Validate state name
    if not STATE_FLAGS[state] then return end

    -- Server-side verification: don't blindly trust client-reported states
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and active then
        -- Verify FALLING: check vertical velocity is actually negative
        if state == 'FALLING' then
            local vel = GetEntityVelocity(ped)
            if vel and vel.z > -2.0 then
                return -- Not actually falling, reject
            end
        end

        -- Cap RAGDOLL immunity at 10 seconds (can't verify server-side)
        if state == 'RAGDOLL' then
            SetTimeout(10000, function()
                if playerStates[src] and playerStates[src].flags['ragdoll'] then
                    FalsePositive.SetState(src, 'RAGDOLL', false)
                end
            end)
        end

        -- Cap TELEPORTING immunity at 8 seconds
        if state == 'TELEPORTING' then
            SetTimeout(8000, function()
                if playerStates[src] and playerStates[src].flags['teleporting'] then
                    FalsePositive.SetState(src, 'TELEPORTING', false)
                end
            end)
        end

        -- Cap INTERIOR immunity at 8 seconds
        if state == 'INTERIOR' then
            SetTimeout(8000, function()
                if playerStates[src] and playerStates[src].flags['interior'] then
                    FalsePositive.SetState(src, 'INTERIOR', false)
                end
            end)
        end

        -- Cap VEHICLE_SEAT_CHANGE immunity at 5 seconds
        if state == 'VEHICLE_SEAT_CHANGE' then
            SetTimeout(5000, function()
                if playerStates[src] and playerStates[src].flags['vehicle_seat_change'] then
                    FalsePositive.SetState(src, 'VEHICLE_SEAT_CHANGE', false)
                end
            end)
        end
    end

    FalsePositive.SetState(src, state, active)

    if Config.Debug then
        print(string.format('[LucidGuard] Player %d state: %s = %s',
            src, state, tostring(active)))
    end
end)

-- ============================================================================
-- WHITELIST SYSTEM
-- ============================================================================

local whitelistedPlayers = {}
local whitelistedDetections = {}

function FalsePositive.WhitelistPlayer(playerId, duration, reason)
    whitelistedPlayers[playerId] = {
        until_ = duration and (GetGameTimer() + duration) or nil,
        reason = reason or 'Manual whitelist'
    }
end

function FalsePositive.IsWhitelisted(playerId)
    local wl = whitelistedPlayers[playerId]
    if not wl then return false end
    
    if wl.until_ and GetGameTimer() > wl.until_ then
        whitelistedPlayers[playerId] = nil
        return false
    end
    
    return true
end

function FalsePositive.WhitelistDetection(playerId, detectionType, duration)
    if not whitelistedDetections[playerId] then
        whitelistedDetections[playerId] = {}
    end
    
    whitelistedDetections[playerId][detectionType] = {
        until_ = GetGameTimer() + (duration or 60000)
    }
end

function FalsePositive.IsDetectionWhitelisted(playerId, detectionType)
    if not whitelistedDetections[playerId] then return false end
    
    local wl = whitelistedDetections[playerId][detectionType]
    if not wl then return false end
    
    if GetGameTimer() > wl.until_ then
        whitelistedDetections[playerId][detectionType] = nil
        return false
    end
    
    return true
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerJoining', function()
    local src = source
    FalsePositive.InitPlayer(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerStates[src] = nil
    whitelistedPlayers[src] = nil
    whitelistedDetections[src] = nil
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('FP_InitPlayer', FalsePositive.InitPlayer)
exports('FP_SetState', FalsePositive.SetState)
exports('FP_HasState', FalsePositive.HasState)
exports('FP_InCooldown', FalsePositive.InCooldown)
exports('FP_HasAnyImmunity', FalsePositive.HasAnyImmunity)
exports('FP_GetPingTolerance', FalsePositive.GetPingTolerance)
exports('FP_ValidateDetection', FalsePositive.ValidateDetection)
exports('FP_ConfirmViolation', FalsePositive.ConfirmViolation)
exports('FP_CanCheck', FalsePositive.CanCheck)
exports('FP_WhitelistPlayer', FalsePositive.WhitelistPlayer)
exports('FP_IsWhitelisted', FalsePositive.IsWhitelisted)
exports('FP_WhitelistDetection', FalsePositive.WhitelistDetection)
exports('FP_IsDetectionWhitelisted', FalsePositive.IsDetectionWhitelisted)
exports('FP_UpdatePing', FalsePositive.UpdatePing)
exports('FP_GetAveragePing', FalsePositive.GetAveragePing)
exports('FP_UpdatePosition', FalsePositive.UpdatePosition)

-- Global access
_G.FalsePositive = FalsePositive

print('[^2LucidGuard^0] False Positive Prevention System loaded')
