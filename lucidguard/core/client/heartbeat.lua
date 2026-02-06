--[[
    LucidGuard Anticheat - Heartbeat System
    Created by OnlyLucidVibes
    Client-Server ping to detect resource tampering
    
    GHOST CLIENT DETECTION: Server sends math challenges that prove
    the script is actually executing code, not just existing.
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local heartbeatActive = false
local pendingChallenge = nil
local challengeReceivedAt = 0

-- ============================================================================
-- HEARTBEAT LOOP
-- ============================================================================

CreateThread(function()
    -- Wait for initialization
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(5000)
    
    if not Config.Modules.Heartbeat or not Config.Heartbeat.Enabled then return end
    
    heartbeatActive = true
    
    while heartbeatActive do
        Wait(Config.Heartbeat.Interval)
        
        -- Send heartbeat to server with client timestamp
        TriggerServerEvent('xx_ac:heartbeat', GetGameTimer())
        
        if Config.Debug then
            print('[LucidGuard] Heartbeat sent')
        end
    end
end)

-- ============================================================================
-- MATH CHALLENGE SYSTEM (Ghost Client Detection)
-- Server sends: {operation: 'add', a: 15, b: 22}
-- Client must respond with: 37
-- This proves the script is actually EXECUTING code, not paused
-- ============================================================================

RegisterNetEvent('lg_ac:mathChallenge')
AddEventHandler('lg_ac:mathChallenge', function(challengeId, operation, a, b)
    -- Record when we received the challenge
    challengeReceivedAt = GetGameTimer()
    
    -- Calculate the answer
    local answer = 0
    
    if operation == 'add' then
        answer = a + b
    elseif operation == 'subtract' then
        answer = a - b
    elseif operation == 'multiply' then
        answer = a * b
    elseif operation == 'modulo' then
        answer = a % b
    elseif operation == 'xor' then
        -- Bitwise XOR (harder to predict)
        answer = (a ~ b)
    elseif operation == 'mixed' then
        -- Complex: (a * 2) + (b / 2) rounded
        answer = math.floor((a * 2) + (b / 2))
    end
    
    -- Send response immediately
    TriggerServerEvent('lg_ac:challengeResponse', challengeId, answer, GetGameTimer())
    
    if Config.Debug then
        print(string.format('[LucidGuard] Challenge %s: %s(%d, %d) = %d', 
            challengeId, operation, a, b, answer))
    end
end)

-- ============================================================================
-- HANDLE SERVER HEARTBEAT CHECK
-- ============================================================================

RegisterNetEvent('xx_ac:heartbeatCheck')
AddEventHandler('xx_ac:heartbeatCheck', function()
    -- Server is checking if we're responsive
    TriggerServerEvent('xx_ac:heartbeatResponse', GetGameTimer())
end)

-- ============================================================================
-- ANTI-TAMPER: Prevent heartbeat disable
-- ============================================================================

-- Monitor if heartbeat gets disabled somehow
CreateThread(function()
    Wait(15000) -- Wait for system to initialize
    
    if not Config.Modules.Heartbeat then return end
    
    while true do
        Wait(60000) -- Check every minute
        
        if not heartbeatActive and Config.Heartbeat.Enabled then
            -- Heartbeat was disabled somehow - this shouldn't happen
            TriggerServerEvent('xx_ac:report', 'HEARTBEAT_TAMPER', 'HIGH', 
                'Heartbeat system was disabled')
            
            -- Try to restart it
            heartbeatActive = true
        end
    end
end)

-- ============================================================================
-- SECONDARY HEARTBEAT (Harder to block)
-- Uses a different event name to detect if main heartbeat is blocked
-- ============================================================================

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(30000) -- Start after 30 seconds
    
    if not Config.Modules.Heartbeat then return end
    
    while true do
        Wait(45000) -- Every 45 seconds (offset from main heartbeat)
        
        -- Send secondary pulse with different event name
        TriggerServerEvent('lg_ac:pulse', {
            time = GetGameTimer(),
            frame = GetFrameCount(),
            ping = GetPlayerPing(PlayerId())
        })
    end
end)
