--[[
    LucidGuard Anticheat - Smart Detection System (AI-Like)
    by OnlyLucidVibes
    
    Intelligent detection that prevents false positives by:
    - Building trust scores over time
    - Requiring multiple independent detection confirmations
    - Considering player context (ping, playtime, state)
    - Using confidence scoring before taking action
    - Learning from player behavior patterns
]]

local SmartDetection = {}

-- ============================================================================
-- PLAYER TRUST & HISTORY TRACKING
-- ============================================================================

local playerProfiles = {}
local TRUST_LEVELS = {
    NEW = 0,          -- Just joined, no history
    UNTRUSTED = 1,    -- Recent flags/suspicious
    NEUTRAL = 2,      -- Default after some playtime
    TRUSTED = 3,      -- Clean history, regular player
    VETERAN = 4       -- Long-term clean player
}

-- Detection weights (how suspicious each detection is)
local DETECTION_WEIGHTS = {
    -- Low confidence detections (often false positives)
    SPEED_HACK = 0.15,
    GHOST_CLIENT = 0.20,       -- Heartbeat issues are common
    TELEPORT = 0.25,
    NOCLIP = 0.25,
    
    -- Medium confidence
    DAMAGE_MOD = 0.40,
    WEAPON_SPAWN = 0.45,
    VEHICLE_MOD = 0.35,
    STATE_BAG = 0.40,
    
    -- High confidence (rarely false positive)
    GOD_MODE = 0.60,
    MONEY_INJECTION = 0.80,
    RESOURCE_INJECTION = 0.90,
    EXECUTOR_DETECTED = 0.95,
    MENU_TRAP = 0.85,
    
    -- Default
    DEFAULT = 0.30
}

-- How much trust each detection loses
local TRUST_PENALTIES = {
    GHOST_CLIENT = 5,      -- Reduced - common false positive
    SPEED_HACK = 8,
    TELEPORT = 10,
    NOCLIP = 12,
    GOD_MODE = 25,
    WEAPON_SPAWN = 15,
    MONEY_INJECTION = 50,
    EXECUTOR_DETECTED = 100,
    DEFAULT = 10
}

-- ============================================================================
-- INITIALIZE PLAYER PROFILE
-- ============================================================================

function SmartDetection.InitPlayer(playerId)
    local identifiers = GetPlayerIdentifiers(playerId) or {}
    local license = nil
    
    for _, id in ipairs(identifiers) do
        if string.match(id, 'license:') then
            license = id
            break
        end
    end
    
    playerProfiles[playerId] = {
        license = license,
        joinTime = os.time(),
        sessionStart = os.time(),
        trustScore = 100,                -- Start neutral (0-200 scale)
        trustLevel = TRUST_LEVELS.NEW,
        
        -- Detection tracking
        detections = {},                 -- {type = {timestamps, count}}
        totalDetections = 0,
        uniqueDetectionTypes = 0,
        
        -- Confidence tracking
        confidenceScore = 0,             -- Running cheat confidence (0-100)
        confidenceHistory = {},          -- Rolling history
        
        -- Behavioral patterns
        avgPing = 50,
        pingSpikes = 0,
        lastPosition = nil,
        positionHistory = {},
        
        -- Session stats
        cleanMinutes = 0,                -- Minutes without detection
        lastDetectionTime = 0,
        isLoading = true,                -- Player still loading
        loadingGracePeriod = 60,         -- 60 seconds grace for loading
        
        -- Flags
        flaggedForReview = false,
        actionTaken = false
    }
    
    -- Loading grace period
    SetTimeout(60000, function()
        if playerProfiles[playerId] then
            playerProfiles[playerId].isLoading = false
            playerProfiles[playerId].trustLevel = TRUST_LEVELS.NEUTRAL
        end
    end)
    
    return playerProfiles[playerId]
end

function SmartDetection.GetProfile(playerId)
    if not playerProfiles[playerId] then
        return SmartDetection.InitPlayer(playerId)
    end
    return playerProfiles[playerId]
end

-- ============================================================================
-- TRUST SCORE MANAGEMENT
-- ============================================================================

function SmartDetection.AddTrust(playerId, amount)
    local profile = SmartDetection.GetProfile(playerId)
    profile.trustScore = math.min(200, profile.trustScore + amount)
    SmartDetection.UpdateTrustLevel(playerId)
end

function SmartDetection.RemoveTrust(playerId, amount)
    local profile = SmartDetection.GetProfile(playerId)
    profile.trustScore = math.max(0, profile.trustScore - amount)
    SmartDetection.UpdateTrustLevel(playerId)
end

function SmartDetection.UpdateTrustLevel(playerId)
    local profile = SmartDetection.GetProfile(playerId)
    
    if profile.trustScore >= 180 then
        profile.trustLevel = TRUST_LEVELS.VETERAN
    elseif profile.trustScore >= 140 then
        profile.trustLevel = TRUST_LEVELS.TRUSTED
    elseif profile.trustScore >= 80 then
        profile.trustLevel = TRUST_LEVELS.NEUTRAL
    elseif profile.trustScore >= 40 then
        profile.trustLevel = TRUST_LEVELS.UNTRUSTED
    else
        profile.trustLevel = TRUST_LEVELS.NEW
    end
end

-- ============================================================================
-- SMART DETECTION VALIDATION
-- ============================================================================

function SmartDetection.ShouldProcess(playerId, detectionType, details)
    local profile = SmartDetection.GetProfile(playerId)
    local reasons = {}
    
    -- ========================================================================
    -- CHECK 1: Loading grace period
    -- ========================================================================
    
    if profile.isLoading then
        table.insert(reasons, 'Player still loading (grace period)')
        return false, reasons, 0
    end
    
    local timeSinceJoin = os.time() - profile.sessionStart
    if timeSinceJoin < profile.loadingGracePeriod then
        table.insert(reasons, string.format('Join grace period (%ds remaining)', 
            profile.loadingGracePeriod - timeSinceJoin))
        return false, reasons, 0
    end
    
    -- ========================================================================
    -- CHECK 2: Ping spike detection (high ping = ignore detection)
    -- ========================================================================
    
    local ping = GetPlayerPing(playerId) or 0
    
    if ping > 500 then
        table.insert(reasons, string.format('Extreme ping (%dms) - network issue likely', ping))
        return false, reasons, 0
    end
    
    if ping > 250 then
        table.insert(reasons, string.format('High ping (%dms) - reduced confidence', ping))
        -- Don't return false, but reduce confidence later
    end
    
    -- ========================================================================
    -- CHECK 3: Trust-based thresholds
    -- ========================================================================
    
    local weight = DETECTION_WEIGHTS[detectionType] or DETECTION_WEIGHTS.DEFAULT
    local requiredConfidence = SmartDetection.GetRequiredConfidence(playerId, detectionType)
    
    -- Trusted players need much higher confidence to flag
    if profile.trustLevel >= TRUST_LEVELS.TRUSTED then
        weight = weight * 0.5  -- Halve the weight for trusted players
        table.insert(reasons, 'Trusted player - reduced detection weight')
    end
    
    -- ========================================================================
    -- CHECK 4: Recent clean time bonus
    -- ========================================================================
    
    if profile.cleanMinutes > 30 then
        weight = weight * 0.7  -- 30% reduction for 30+ clean minutes
        table.insert(reasons, '30+ clean minutes - reduced detection weight')
    end
    
    return true, reasons, weight
end

-- ============================================================================
-- CONFIDENCE SCORING SYSTEM
-- ============================================================================

function SmartDetection.GetRequiredConfidence(playerId, detectionType)
    local profile = SmartDetection.GetProfile(playerId)
    
    -- Base required confidence
    local required = Config.SmartDetection and Config.SmartDetection.BaseConfidenceRequired or 75
    
    -- Trust level adjustments
    if profile.trustLevel == TRUST_LEVELS.VETERAN then
        required = required + 20  -- Veterans need 95% confidence
    elseif profile.trustLevel == TRUST_LEVELS.TRUSTED then
        required = required + 15  -- Trusted need 90% confidence
    elseif profile.trustLevel == TRUST_LEVELS.NEUTRAL then
        required = required + 5   -- Neutral need 80% confidence
    end
    
    -- Cap at 95 (never 100% - always allow human review)
    return math.min(95, required)
end

function SmartDetection.CalculateConfidence(playerId, detectionType, details)
    local profile = SmartDetection.GetProfile(playerId)
    local confidence = 0
    local factors = {}
    
    -- ========================================================================
    -- FACTOR 1: Detection weight
    -- ========================================================================
    
    local weight = DETECTION_WEIGHTS[detectionType] or DETECTION_WEIGHTS.DEFAULT
    confidence = confidence + (weight * 40)  -- Max 40 points from weight
    table.insert(factors, string.format('Detection weight: +%.1f', weight * 40))
    
    -- ========================================================================
    -- FACTOR 2: Multiple detection types (correlation)
    -- ========================================================================
    
    local uniqueTypes = 0
    for dtype, data in pairs(profile.detections) do
        if data.count > 0 then
            uniqueTypes = uniqueTypes + 1
        end
    end
    
    if uniqueTypes >= 3 then
        confidence = confidence + 25  -- Multiple detection types = very suspicious
        table.insert(factors, 'Multiple detection types: +25')
    elseif uniqueTypes >= 2 then
        confidence = confidence + 15
        table.insert(factors, 'Two detection types: +15')
    end
    
    -- ========================================================================
    -- FACTOR 3: Repeat detections (same type)
    -- ========================================================================
    
    if profile.detections[detectionType] then
        local count = profile.detections[detectionType].count
        if count >= 5 then
            confidence = confidence + 20
            table.insert(factors, string.format('Repeated detections (%d): +20', count))
        elseif count >= 3 then
            confidence = confidence + 10
            table.insert(factors, string.format('Repeated detections (%d): +10', count))
        end
    end
    
    -- ========================================================================
    -- FACTOR 4: Time clustering (multiple detections in short time)
    -- ========================================================================
    
    local recentDetections = 0
    local now = os.time()
    
    for dtype, data in pairs(profile.detections) do
        for _, timestamp in ipairs(data.timestamps or {}) do
            if (now - timestamp) < 300 then  -- Last 5 minutes
                recentDetections = recentDetections + 1
            end
        end
    end
    
    if recentDetections >= 5 then
        confidence = confidence + 15
        table.insert(factors, string.format('Recent cluster (%d in 5min): +15', recentDetections))
    end
    
    -- ========================================================================
    -- FACTOR 5: Inverse trust penalty
    -- ========================================================================
    
    local trustPenalty = (200 - profile.trustScore) / 10  -- 0-20 points
    confidence = confidence + trustPenalty
    table.insert(factors, string.format('Trust penalty: +%.1f', trustPenalty))
    
    -- ========================================================================
    -- NEGATIVE FACTORS (reduce confidence)
    -- ========================================================================
    
    -- High ping reduces confidence
    local ping = GetPlayerPing(playerId) or 0
    if ping > 150 then
        local pingPenalty = math.min(20, (ping - 150) / 10)
        confidence = confidence - pingPenalty
        table.insert(factors, string.format('High ping penalty: -%.1f', pingPenalty))
    end
    
    -- Clean time reduces confidence
    if profile.cleanMinutes > 60 then
        confidence = confidence - 10
        table.insert(factors, 'Long clean session: -10')
    elseif profile.cleanMinutes > 30 then
        confidence = confidence - 5
        table.insert(factors, 'Clean session: -5')
    end
    
    -- Clamp to 0-100
    confidence = math.max(0, math.min(100, confidence))
    
    return confidence, factors
end

-- ============================================================================
-- MAIN DETECTION PROCESSOR
-- ============================================================================

function SmartDetection.ProcessDetection(playerId, detectionType, severity, details)
    -- Skip if disabled
    if not Config.SmartDetection or not Config.SmartDetection.Enabled then
        return true, 'SmartDetection disabled'
    end
    
    local profile = SmartDetection.GetProfile(playerId)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    
    -- ========================================================================
    -- STEP 1: Should we even process this?
    -- ========================================================================
    
    local shouldProcess, skipReasons, weight = SmartDetection.ShouldProcess(playerId, detectionType, details)
    
    if not shouldProcess then
        if Config.Debug then
            Log('DEBUG', string.format('[SMART] Skipped %s for %s: %s', 
                detectionType, playerName, table.concat(skipReasons, ', ')))
        end
        return false, skipReasons
    end
    
    -- ========================================================================
    -- STEP 2: Record the detection
    -- ========================================================================
    
    if not profile.detections[detectionType] then
        profile.detections[detectionType] = {
            count = 0,
            timestamps = {},
            lastTime = 0
        }
        profile.uniqueDetectionTypes = profile.uniqueDetectionTypes + 1
    end
    
    profile.detections[detectionType].count = profile.detections[detectionType].count + 1
    table.insert(profile.detections[detectionType].timestamps, os.time())
    profile.detections[detectionType].lastTime = os.time()
    profile.totalDetections = profile.totalDetections + 1
    profile.lastDetectionTime = os.time()
    profile.cleanMinutes = 0  -- Reset clean time
    
    -- ========================================================================
    -- STEP 3: Calculate confidence score
    -- ========================================================================
    
    local confidence, factors = SmartDetection.CalculateConfidence(playerId, detectionType, details)
    local requiredConfidence = SmartDetection.GetRequiredConfidence(playerId, detectionType)
    
    profile.confidenceScore = confidence
    table.insert(profile.confidenceHistory, {
        time = os.time(),
        confidence = confidence,
        detectionType = detectionType
    })
    
    -- Keep only last 50 entries
    while #profile.confidenceHistory > 50 do
        table.remove(profile.confidenceHistory, 1)
    end
    
    -- ========================================================================
    -- STEP 4: Remove trust based on detection
    -- ========================================================================
    
    local trustPenalty = TRUST_PENALTIES[detectionType] or TRUST_PENALTIES.DEFAULT
    SmartDetection.RemoveTrust(playerId, trustPenalty)
    
    -- ========================================================================
    -- STEP 5: Determine action
    -- ========================================================================
    
    local action = 'NONE'
    local actionReason = ''
    
    if confidence >= requiredConfidence then
        -- High confidence - take action
        action = SmartDetection.DetermineAction(playerId, detectionType, confidence)
        actionReason = string.format('Confidence %.1f%% >= Required %.1f%%', confidence, requiredConfidence)
        profile.actionTaken = true
    elseif confidence >= (requiredConfidence - 15) then
        -- Close to threshold - flag for review only
        action = 'FLAG'
        actionReason = string.format('Confidence %.1f%% approaching threshold (need %.1f%%)', confidence, requiredConfidence)
        profile.flaggedForReview = true
    else
        -- Low confidence - log only
        action = 'LOG'
        actionReason = string.format('Confidence %.1f%% below threshold (need %.1f%%)', confidence, requiredConfidence)
    end
    
    -- ========================================================================
    -- STEP 6: Log decision
    -- ========================================================================
    
    if Config.Debug or action ~= 'LOG' then
        Log('INFO', string.format('[SMART] %s | %s | Confidence: %.1f%% | Required: %.1f%% | Action: %s | Trust: %d | Factors: %s',
            playerName, detectionType, confidence, requiredConfidence, action, 
            profile.trustScore, table.concat(factors, ', ')))
    end
    
    -- ========================================================================
    -- STEP 7: Return decision
    -- ========================================================================
    
    return action ~= 'NONE' and action ~= 'LOG', {
        action = action,
        reason = actionReason,
        confidence = confidence,
        required = requiredConfidence,
        factors = factors,
        trustScore = profile.trustScore,
        trustLevel = profile.trustLevel
    }
end

-- ============================================================================
-- DETERMINE ACTION BASED ON CONFIDENCE
-- ============================================================================

function SmartDetection.DetermineAction(playerId, detectionType, confidence)
    local profile = SmartDetection.GetProfile(playerId)
    
    -- Critical detections with very high confidence = BAN
    local criticalTypes = {
        'MONEY_INJECTION', 'RESOURCE_INJECTION', 'EXECUTOR_DETECTED', 
        'MENU_TRAP', 'FILE_TAMPERING'
    }
    
    for _, crit in ipairs(criticalTypes) do
        if detectionType == crit and confidence >= 90 then
            return 'BAN'
        end
    end
    
    -- Very high confidence on any type = KICK
    if confidence >= 95 then
        return 'KICK'
    end
    
    -- High confidence = KICK for untrusted, FLAG for trusted
    if confidence >= 85 then
        if profile.trustLevel <= TRUST_LEVELS.NEUTRAL then
            return 'KICK'
        else
            return 'FLAG'  -- Don't kick trusted players, just flag
        end
    end
    
    -- Moderate confidence = just FLAG for review
    return 'FLAG'
end

-- ============================================================================
-- TRUST BUILDING (Call this periodically)
-- ============================================================================

function SmartDetection.AwardCleanTime(playerId)
    local profile = SmartDetection.GetProfile(playerId)
    
    if not profile then return end
    
    -- Award trust for clean play time
    profile.cleanMinutes = profile.cleanMinutes + 1
    
    if profile.cleanMinutes % 10 == 0 then  -- Every 10 clean minutes
        SmartDetection.AddTrust(playerId, 2)
    end
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    local playerId = source
    -- Keep profile for a bit in case they reconnect
    SetTimeout(300000, function()  -- 5 minutes
        playerProfiles[playerId] = nil
    end)
end)

-- ============================================================================
-- TRUST BUILDER LOOP
-- ============================================================================

CreateThread(function()
    while true do
        Wait(60000)  -- Every minute
        
        for _, playerId in ipairs(GetPlayers()) do
            SmartDetection.AwardCleanTime(playerId)
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('SmartProcessDetection', SmartDetection.ProcessDetection)
exports('GetPlayerTrustScore', function(playerId)
    local profile = SmartDetection.GetProfile(playerId)
    return profile.trustScore, profile.trustLevel
end)
exports('GetPlayerConfidence', function(playerId)
    local profile = SmartDetection.GetProfile(playerId)
    return profile.confidenceScore
end)

-- Global access
_G.SmartDetection = SmartDetection
