--[[
    LucidGuard Anticheat - Client State Reporter
    by OnlyLucidVibes
    
    Reports player states to server for false positive prevention.
    Tracks: spawning, loading, teleporting, vehicle, cutscene, etc.
]]

local StateReporter = {}
local currentStates = {}
local lastReportedStates = {}

-- ============================================================================
-- STATE DETECTION
-- ============================================================================

local function IsSpawning()
    local playerPed = PlayerPedId()
    return not DoesEntityExist(playerPed) or IsPlayerSwitchInProgress()
end

local function IsInCutscene()
    return IsCutsceneActive() or IsCutscenePlaying()
end

local function IsFalling()
    local playerPed = PlayerPedId()
    return IsPedFalling(playerPed) or IsPedJumping(playerPed)
end

local function IsSwimming()
    local playerPed = PlayerPedId()
    return IsPedSwimming(playerPed) or IsPedSwimmingUnderWater(playerPed)
end

local function IsRagdoll()
    local playerPed = PlayerPedId()
    return IsPedRagdoll(playerPed)
end

local function IsDead()
    local playerPed = PlayerPedId()
    return IsEntityDead(playerPed) or IsPedDeadOrDying(playerPed, true)
end

local function IsInVehicleTransition()
    local playerPed = PlayerPedId()
    return GetIsTaskActive(playerPed, 160) or  -- TASK_ENTER_VEHICLE
           GetIsTaskActive(playerPed, 161) or  -- TASK_OPEN_VEHICLE_DOOR
           GetIsTaskActive(playerPed, 164)     -- TASK_EXIT_VEHICLE
end

local function IsPaused()
    return IsPauseMenuActive()
end

-- ============================================================================
-- STATE MONITORING
-- ============================================================================

local function CheckState(stateName, checkFunc)
    local isActive = checkFunc()
    local wasActive = currentStates[stateName]
    
    if isActive ~= wasActive then
        currentStates[stateName] = isActive
        
        -- Only report if changed from last report
        if lastReportedStates[stateName] ~= isActive then
            TriggerServerEvent('LucidGuard:UpdatePlayerState', stateName, isActive)
            lastReportedStates[stateName] = isActive
        end
    end
end

-- Main state monitoring loop
CreateThread(function()
    -- Wait for player to fully load
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    
    -- Report initial loading complete
    Wait(1000)
    TriggerServerEvent('LucidGuard:UpdatePlayerState', 'LOADING', false)
    
    while true do
        Wait(250) -- Check every 250ms
        
        -- Check all states
        CheckState('SPAWNING', IsSpawning)
        CheckState('CUTSCENE', IsInCutscene)
        CheckState('FALLING', IsFalling)
        CheckState('SWIMMING', IsSwimming)
        CheckState('RAGDOLL', IsRagdoll)
        CheckState('DEAD', IsDead)
        CheckState('VEHICLE_ENTER', IsInVehicleTransition)
        CheckState('PAUSED', IsPaused)
    end
end)

-- ============================================================================
-- TELEPORT TRACKING
-- ============================================================================

local lastPosition = nil
local TELEPORT_DISTANCE = 50.0 -- Distance that counts as teleport

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    
    Wait(5000) -- Wait for initial spawn
    
    local playerPed = PlayerPedId()
    if DoesEntityExist(playerPed) then
        lastPosition = GetEntityCoords(playerPed)
    end
    
    while true do
        Wait(500)
        
        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then
            goto continue
        end
        
        local currentPos = GetEntityCoords(playerPed)
        
        if lastPosition then
            local distance = #(currentPos - lastPosition)
            
            -- If moved more than threshold, report as teleport
            if distance > TELEPORT_DISTANCE then
                TriggerServerEvent('LucidGuard:UpdatePlayerState', 'TELEPORTING', true)
                
                -- Clear teleport state after 1 second
                SetTimeout(1000, function()
                    TriggerServerEvent('LucidGuard:UpdatePlayerState', 'TELEPORTING', false)
                end)
            end
        end
        
        lastPosition = currentPos
        
        ::continue::
    end
end)

-- ============================================================================
-- INTERIOR TRACKING
-- ============================================================================

local lastInterior = 0

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    
    while true do
        Wait(1000)
        
        local playerPed = PlayerPedId()
        if not DoesEntityExist(playerPed) then
            goto continue
        end
        
        local currentInterior = GetInteriorFromEntity(playerPed)
        
        if currentInterior ~= lastInterior then
            -- Interior changed
            TriggerServerEvent('LucidGuard:UpdatePlayerState', 'INTERIOR', true)
            
            SetTimeout(2000, function()
                TriggerServerEvent('LucidGuard:UpdatePlayerState', 'INTERIOR', false)
            end)
            
            lastInterior = currentInterior
        end
        
        ::continue::
    end
end)

-- ============================================================================
-- SPAWN/DEATH EVENTS
-- ============================================================================

AddEventHandler('playerSpawned', function()
    TriggerServerEvent('LucidGuard:UpdatePlayerState', 'SPAWNING', true)
    
    SetTimeout(5000, function()
        TriggerServerEvent('LucidGuard:UpdatePlayerState', 'SPAWNING', false)
    end)
end)

AddEventHandler('esx:onPlayerSpawn', function()
    TriggerServerEvent('LucidGuard:UpdatePlayerState', 'SPAWNING', true)
    
    SetTimeout(5000, function()
        TriggerServerEvent('LucidGuard:UpdatePlayerState', 'SPAWNING', false)
    end)
end)

AddEventHandler('esx:onPlayerDeath', function()
    TriggerServerEvent('LucidGuard:UpdatePlayerState', 'DEAD', true)
end)

-- ============================================================================
-- MISSION/JOB TRACKING
-- ============================================================================

-- Register when player starts a mission/job activity
RegisterNetEvent('LucidGuard:StartMission', function()
    TriggerServerEvent('LucidGuard:UpdatePlayerState', 'MISSION', true)
end)

RegisterNetEvent('LucidGuard:EndMission', function()
    TriggerServerEvent('LucidGuard:UpdatePlayerState', 'MISSION', false)
end)

-- ============================================================================
-- EXPORTS FOR OTHER CLIENT SCRIPTS
-- ============================================================================

exports('ReportState', function(stateName, active)
    TriggerServerEvent('LucidGuard:UpdatePlayerState', stateName, active)
end)

exports('GetCurrentStates', function()
    return currentStates
end)

print('[^2LucidGuard^0] Client State Reporter loaded')
