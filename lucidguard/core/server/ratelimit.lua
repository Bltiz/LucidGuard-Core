--[[
    LucidGuard Anticheat - Rate Limiting / DDoS Protection
    Created by OnlyLucidVibes
    Token bucket algorithm for event rate limiting
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local playerEventCounts = {} -- Track event calls per player
local protectedEvents = {}   -- Wrapped events

-- ============================================================================
-- INITIALIZE PLAYER RATE LIMITER
-- ============================================================================

local function InitPlayerRateLimit(playerId)
    if not playerEventCounts[playerId] then
        playerEventCounts[playerId] = {}
    end
end

-- ============================================================================
-- CHECK RATE LIMIT
-- ============================================================================

function CheckRateLimit(playerId, eventName)
    if not Config.Modules.RateLimiting then return false end
    
    -- Admin immunity
    if IsPlayerAdmin(playerId) then return false end
    
    InitPlayerRateLimit(playerId)
    
    local currentTime = GetGameTimer()
    local eventData = playerEventCounts[playerId][eventName]
    
    -- Get limit config for this event
    local limitConfig = Config.RateLimit.EventLimits[eventName] or Config.RateLimit.DefaultLimit
    
    if not eventData then
        playerEventCounts[playerId][eventName] = {
            count = 1,
            windowStart = currentTime
        }
        return false -- Not rate limited
    end
    
    -- Check if window has passed
    if currentTime - eventData.windowStart > limitConfig.WindowMs then
        -- Reset window
        playerEventCounts[playerId][eventName] = {
            count = 1,
            windowStart = currentTime
        }
        return false
    end
    
    -- Increment count
    eventData.count = eventData.count + 1
    
    -- Check if over limit
    if eventData.count > limitConfig.MaxCalls then
        return true, eventData.count
    end
    
    return false
end

-- ============================================================================
-- SECURE EVENT WRAPPER
-- ============================================================================

function SecureEvent(eventName, callback)
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function(...)
        local playerId = source
        
        -- Validate source
        if not playerId or playerId <= 0 then
            Log('WARN', string.format('Invalid source for event: %s', eventName))
            return
        end
        
        -- Check rate limit
        local isLimited, callCount = CheckRateLimit(playerId, eventName)
        
        if isLimited then
            local playerName = GetPlayerName(playerId) or 'Unknown'
            Log('ALERT', string.format('Rate limit exceeded: %s (%s) on event %s (%d calls)',
                playerName, playerId, eventName, callCount))
            
            -- Send Discord alert
            if Config.Discord.Enabled then
                SendRateLimitAlert(playerId, eventName, callCount)
            end
            
            -- Kick player
            DropPlayer(playerId, 'Rate limit exceeded. This has been logged.')
            return
        end
        
        -- Execute original callback
        callback(playerId, ...)
    end)
    
    -- Track protected events
    protectedEvents[eventName] = true
end

-- ============================================================================
-- PROTECT ESX EVENTS
-- ============================================================================

CreateThread(function()
    Wait(1000) -- Wait for other resources to load
    
    if not Config.Modules.RateLimiting then return end
    
    Log('INFO', 'Rate limiting system initialized')
    Log('INFO', 'Protected events:')
    
    for eventName, limit in pairs(Config.RateLimit.EventLimits) do
        Log('INFO', string.format('  • %s (%d/%dms)', eventName, limit.MaxCalls, limit.WindowMs))
    end
end)

-- ============================================================================
-- MONITOR ALL INCOMING EVENTS
-- ============================================================================

-- Hook into the raw event system for monitoring
AddEventHandler('__cfx_internal:commandFallback', function(command)
    local playerId = source
    if not playerId or playerId <= 0 then return end
    
    -- This catches any unhandled commands that might be exploits
    Log('DEBUG', string.format('Unknown command from %s: %s', playerId, command))
end)

-- ============================================================================
-- ANTICHEAT EVENTS WITH RATE LIMITING
-- ============================================================================

-- Heartbeat event
SecureEvent('xx_ac:heartbeat', function(playerId)
    local playerData = GetPlayerData(playerId)
    if playerData then
        playerData.lastHeartbeat = os.time()
        playerData.heartbeatMissed = 0
    end
end)

-- Detection report event
SecureEvent('xx_ac:report', function(playerId, detectionType, severity, details)
    -- Admin immunity
    if IsPlayerAdmin(playerId) then return end
    
    -- Process the detection
    ProcessDetection(playerId, detectionType, severity, details)
end)

-- Resource list report
SecureEvent('xx_ac:resourceList', function(playerId, resources)
    -- Admin immunity
    if IsPlayerAdmin(playerId) then return end
    
    local currentResource = string.lower(GetCurrentResourceName())
    
    -- Check for blacklisted resources
    if type(resources) == 'table' then
        for _, resourceName in ipairs(resources) do
            -- Never flag ourselves (the anticheat resource)
            if string.lower(resourceName) == currentResource then
                goto continue
            end
            
            if Config.TableContainsPartial(Config.ResourceScanner.BlacklistedResources, resourceName) then
                -- Check whitelist
                if not Config.TableContainsPartial(Config.ResourceScanner.WhitelistedResources, resourceName) then
                    HandleResourceInjection(playerId, resourceName)
                    return
                end
            end
            
            ::continue::
        end
    end
end)

-- Position update (for tracking + FalsePositive stability)
SecureEvent('xx_ac:position', function(playerId, coords)
    local playerData = GetPlayerData(playerId)
    if playerData and coords then
        playerData.lastPosition = coords
    end

    -- Feed position to FalsePositive for join-stability tracking
    if FalsePositive and FalsePositive.UpdatePosition then
        FalsePositive.UpdatePosition(playerId, coords)
    end

    -- Update ping for FalsePositive tolerance
    if FalsePositive and FalsePositive.UpdatePing then
        FalsePositive.UpdatePing(playerId)
    end
end)

-- ============================================================================
-- BLOCK COMMON EXPLOIT EVENTS
-- ============================================================================

-- Block server-only events being triggered from client
local blockedClientEvents = {
    'esx:setJob',
    'esx:setAccountMoney',
    'esx_addonaccount:setMoney',
    'esx_billing:sendBill',
    'esx_society:depositMoney',
    'esx_society:withdrawMoney'
}

for _, eventName in ipairs(blockedClientEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function(...)
        local playerId = source
        
        -- If triggered from client (source > 0), it's an exploit attempt
        if playerId and playerId > 0 then
            local playerName = GetPlayerName(playerId) or 'Unknown'
            Log('ALERT', string.format('Blocked exploit attempt: %s (%s) triggered %s',
                playerName, playerId, eventName))
            
            -- Process as critical detection
            ProcessDetection(playerId, 'EXPLOIT_ATTEMPT', 'CRITICAL', 
                string.format('Attempted to trigger protected event: %s', eventName))
            
            CancelEvent()
        end
    end)
end

-- ============================================================================
-- CLEANUP ON PLAYER DISCONNECT
-- ============================================================================

AddEventHandler('playerDropped', function()
    local playerId = source
    playerEventCounts[playerId] = nil
end)

-- ============================================================================
-- PERIODIC CLEANUP
-- ============================================================================

CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        
        -- Clean up data for disconnected players
        for playerId, _ in pairs(playerEventCounts) do
            if not GetPlayerName(playerId) then
                playerEventCounts[playerId] = nil
            end
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('SecureEvent', SecureEvent)
exports('CheckRateLimit', CheckRateLimit)
