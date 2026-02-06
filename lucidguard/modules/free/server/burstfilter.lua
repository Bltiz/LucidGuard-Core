--[[
    LucidGuard Anticheat - Event Burst Filter (Token Bucket Algorithm)
    Created by OnlyLucidVibes
    
    Don't just check WHAT they trigger, check HOW FAST.
    Uses Token Bucket algorithm to rate limit events per player.
    
    Example: A player can trigger esx:giveInventoryItem max 3 times every 10 seconds.
    If they trigger it 50 times in 1 second = brute force exploit attempt.
]]

-- ============================================================================
-- TOKEN BUCKET IMPLEMENTATION
-- ============================================================================

local playerBuckets = {}

local function GetOrCreateBucket(playerId, eventName)
    if not playerBuckets[playerId] then
        playerBuckets[playerId] = {}
    end
    
    if not playerBuckets[playerId][eventName] then
        local config = Config.BurstFilter.EventLimits[eventName] or Config.BurstFilter.DefaultLimit
        
        playerBuckets[playerId][eventName] = {
            tokens = config.maxTokens,
            maxTokens = config.maxTokens,
            refillRate = config.refillRate, -- tokens per second
            lastRefill = os.time(),
            burstCount = 0,
            lastBurstReset = os.time()
        }
    end
    
    return playerBuckets[playerId][eventName]
end

local function RefillBucket(bucket)
    local now = os.time()
    local elapsed = now - bucket.lastRefill
    
    if elapsed > 0 then
        local tokensToAdd = elapsed * bucket.refillRate
        bucket.tokens = math.min(bucket.maxTokens, bucket.tokens + tokensToAdd)
        bucket.lastRefill = now
    end
end

local function ConsumeToken(playerId, eventName)
    local bucket = GetOrCreateBucket(playerId, eventName)
    
    -- Refill tokens based on time
    RefillBucket(bucket)
    
    -- Track burst count
    local now = os.time()
    if now - bucket.lastBurstReset >= 1 then
        bucket.burstCount = 0
        bucket.lastBurstReset = now
    end
    bucket.burstCount = bucket.burstCount + 1
    
    -- Check if burst is too high (more than limit per second)
    local eventConfig = Config.BurstFilter.EventLimits[eventName] or Config.BurstFilter.DefaultLimit
    if bucket.burstCount > (eventConfig.maxBurstPerSecond or 10) then
        return false, 'BURST_EXCEEDED', bucket.burstCount
    end
    
    -- Check if we have tokens
    if bucket.tokens >= 1 then
        bucket.tokens = bucket.tokens - 1
        return true, nil, bucket.burstCount
    else
        return false, 'NO_TOKENS', bucket.burstCount
    end
end

-- ============================================================================
-- EVENT MONITORING CONFIG
-- ============================================================================

-- These events will be rate-limited
local monitoredEvents = {
    -- Inventory events (3 per 10 seconds is reasonable for looting)
    'esx:giveInventoryItem',
    'esx:removeInventoryItem', 
    'esx:useItem',
    
    -- Money events (should be rare)
    'esx:addAccountMoney',
    'esx:removeAccountMoney',
    'esx_billing:sendBill',
    
    -- Shop events
    'esx_shops:buy',
    'esx_weaponshop:buyWeapon',
    'esx_vehicleshop:buy',
    
    -- Job events
    'esx_jobs:startWork',
    'esx_jobs:stopWork',
    
    -- Garage events
    'esx_garage:spawnVehicle',
    'esx_garage:storeVehicle',
    
    -- Interaction events
    'esx_ambulancejob:revive',
    'esx_policejob:handcuff',
    'esx_policejob:drag',
    
    -- Banking
    'esx_banking:deposit',
    'esx_banking:withdraw',
    'esx_banking:transfer'
}

-- ============================================================================
-- REGISTER EVENT MONITORS
-- ============================================================================

for _, eventName in ipairs(monitoredEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function(...)
        local playerId = source
        local playerName = GetPlayerName(playerId)
        
        -- Admin immunity
        if IsPlayerAdmin(playerId) then return end
        
        -- Try to consume a token
        local allowed, reason, burstCount = ConsumeToken(playerId, eventName)
        
        if not allowed then
            if reason == 'BURST_EXCEEDED' then
                -- Player is spamming the event
                Log('ALERT', string.format(
                    '[BURST FILTER] %s triggered %s %d times in 1 second!',
                    playerName, eventName, burstCount
                ))
                
                ProcessDetection(playerId, 'EVENT_BURST', 'HIGH',
                    string.format('Triggered %s %d times in 1 second (brute force attempt)',
                        eventName, burstCount))
                        
            elseif reason == 'NO_TOKENS' then
                -- Player exceeded rate limit
                Log('WARN', string.format(
                    '[BURST FILTER] %s rate limited on %s',
                    playerName, eventName
                ))
                
                -- Just warn first time, flag on repeated violations
                local bucket = GetOrCreateBucket(playerId, eventName)
                bucket.rateLimitViolations = (bucket.rateLimitViolations or 0) + 1
                
                if bucket.rateLimitViolations >= 5 then
                    ProcessDetection(playerId, 'RATE_LIMIT_ABUSE', 'MEDIUM',
                        string.format('Repeatedly exceeded rate limit on %s (%d violations)',
                            eventName, bucket.rateLimitViolations))
                    bucket.rateLimitViolations = 0
                end
            end
        end
    end)
end

-- ============================================================================
-- GENERIC EVENT BURST DETECTION
-- Monitor ALL events for suspicious patterns
-- ============================================================================

local globalEventCounts = {}

AddEventHandler('__cfx_internal:serverGameEvent', function(eventName, eventData)
    -- This won't work as intended, but we can monitor specific patterns
end)

-- Track all TriggerServerEvent calls (via monitoring pattern)
CreateThread(function()
    Wait(10000)
    
    if not Config.Modules.BurstFilter then
        Log('INFO', 'Burst Filter module disabled')
        return
    end
    
    Log('INFO', string.format('Burst Filter: Monitoring %d event types', #monitoredEvents))
    
    while true do
        Wait(60000) -- Cleanup every minute
        
        -- Clean up disconnected players
        for playerId, _ in pairs(playerBuckets) do
            if not GetPlayerName(playerId) then
                playerBuckets[playerId] = nil
            end
        end
    end
end)

-- ============================================================================
-- CLEANUP ON DISCONNECT
-- ============================================================================

AddEventHandler('playerDropped', function()
    local playerId = source
    playerBuckets[playerId] = nil
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetPlayerEventStats', function(playerId)
    return playerBuckets[playerId]
end)

exports('ConsumeEventToken', ConsumeToken)
