--[[
    LucidGuard Anticheat - Client Legitimacy Reporter
    by OnlyLucidVibes
    
    Reports legitimate gameplay scenarios to prevent false positives.
    This helps the server understand when NOT to flag a player.
]]

-- ============================================================================
-- STATE TRACKING
-- ============================================================================

local legitimateActions = {}
local lastReport = 0
local REPORT_INTERVAL = 500  -- Report every 500ms

-- ============================================================================
-- LEGITIMATE GAMEPLAY SCENARIOS
-- ============================================================================

local function GetCurrentLegitimateScenarios()
    local scenarios = {}
    local ped = PlayerPedId()
    
    if not DoesEntityExist(ped) then return scenarios end
    
    -- Vehicle scenarios (legitimate fast movement)
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local speed = GetEntitySpeed(vehicle) * 3.6  -- km/h
        
        table.insert(scenarios, 'IN_VEHICLE')
        
        if IsThisModelAPlane(GetEntityModel(vehicle)) then
            table.insert(scenarios, 'IN_PLANE')
        elseif IsThisModelAHeli(GetEntityModel(vehicle)) then
            table.insert(scenarios, 'IN_HELICOPTER')
        elseif IsThisModelABoat(GetEntityModel(vehicle)) then
            table.insert(scenarios, 'IN_BOAT')
        elseif IsThisModelABike(GetEntityModel(vehicle)) then
            table.insert(scenarios, 'ON_BIKE')
        end
        
        if speed > 200 then
            table.insert(scenarios, 'HIGH_SPEED_VEHICLE')
        end
        
        -- Nitro/boost
        if IsVehicleTyreBurst(vehicle, 0, false) == false then
            if GetVehicleCurrentGear(vehicle) > 1 and speed > 100 then
                table.insert(scenarios, 'VEHICLE_ACCELERATING')
            end
        end
    end
    
    -- Movement scenarios
    if IsPedFalling(ped) then
        table.insert(scenarios, 'FALLING')
    end
    
    if IsPedRagdoll(ped) then
        table.insert(scenarios, 'RAGDOLL')
    end
    
    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then
        table.insert(scenarios, 'SWIMMING')
    end
    
    if IsPedClimbing(ped) then
        table.insert(scenarios, 'CLIMBING')
    end
    
    if IsPedJumping(ped) then
        table.insert(scenarios, 'JUMPING')
    end
    
    if GetPedParachuteState(ped) ~= -1 then
        table.insert(scenarios, 'PARACHUTING')
    end
    
    -- Combat scenarios (legitimate damage)
    if IsPedShooting(ped) then
        table.insert(scenarios, 'SHOOTING')
    end
    
    if IsPedInMeleeCombat(ped) then
        table.insert(scenarios, 'MELEE_COMBAT')
    end
    
    if IsPedInCover(ped, false) then
        table.insert(scenarios, 'IN_COVER')
    end
    
    -- Animation scenarios
    if IsPedUsingScenario(ped) then
        table.insert(scenarios, 'USING_SCENARIO')
    end
    
    if IsEntityPlayingAnim(ped, 'anim@heists@ornate_bank@grab_cash', 'grab', 3) then
        table.insert(scenarios, 'ROBBERY_ANIM')
    end
    
    -- Cutscene/cinematic
    if IsCutsceneActive() or IsCutscenePlaying() then
        table.insert(scenarios, 'CUTSCENE')
    end
    
    if IsScreenFadedOut() or IsScreenFadingOut() then
        table.insert(scenarios, 'SCREEN_FADING')
    end
    
    -- Death/injury
    if IsPedDeadOrDying(ped, true) then
        table.insert(scenarios, 'DEAD_OR_DYING')
    end
    
    if IsPedInjured(ped) then
        table.insert(scenarios, 'INJURED')
    end
    
    -- Position scenarios
    local coords = GetEntityCoords(ped)
    local groundZ = 0.0
    local foundGround, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, true)
    
    if not foundGround or (coords.z - z) > 3.0 then
        table.insert(scenarios, 'NO_GROUND_BELOW')
    end
    
    local interior = GetInteriorFromEntity(ped)
    if interior ~= 0 then
        table.insert(scenarios, 'IN_INTERIOR')
    end
    
    -- Entering/exiting
    if GetIsTaskActive(ped, 160) then  -- TASK_ENTER_VEHICLE
        table.insert(scenarios, 'ENTERING_VEHICLE')
    end
    
    if GetIsTaskActive(ped, 2) then  -- TASK_EXIT_VEHICLE
        table.insert(scenarios, 'EXITING_VEHICLE')
    end
    
    -- Phone/menu
    if IsPauseMenuActive() then
        table.insert(scenarios, 'PAUSE_MENU')
    end
    
    -- Stunned/frozen by game
    if IsPedBeingStunned(ped, 0) then
        table.insert(scenarios, 'BEING_STUNNED')
    end
    
    -- GTA physics can cause weird positions
    if HasEntityCollidedWithAnything(ped) then
        table.insert(scenarios, 'COLLISION')
    end
    
    return scenarios
end

-- ============================================================================
-- POSITION HISTORY (Legitimate teleport tracking)
-- ============================================================================

local positionHistory = {}
local MAX_POSITION_HISTORY = 50

local function RecordPosition()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    
    local coords = GetEntityCoords(ped)
    local now = GetGameTimer()
    
    table.insert(positionHistory, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        time = now,
        inVehicle = IsPedInAnyVehicle(ped, false),
        interior = GetInteriorFromEntity(ped)
    })
    
    -- Keep only recent history
    if #positionHistory > MAX_POSITION_HISTORY then
        table.remove(positionHistory, 1)
    end
end

local function GetLegitimateMovementSpeed()
    if #positionHistory < 2 then return 0 end
    
    local oldest = positionHistory[1]
    local newest = positionHistory[#positionHistory]
    
    local timeDiff = (newest.time - oldest.time) / 1000  -- seconds
    if timeDiff <= 0 then return 0 end
    
    local distance = #(vector3(newest.x, newest.y, newest.z) - vector3(oldest.x, oldest.y, oldest.z))
    
    return distance / timeDiff  -- m/s
end

-- ============================================================================
-- RESOURCE TRACKING (Legitimate teleports from other resources)
-- ============================================================================

local expectedTeleport = false
local teleportCooldown = 0

-- Hook common teleport events
AddEventHandler('esx:playerLoaded', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 10000
end)

AddEventHandler('esx:onPlayerSpawn', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 10000
end)

RegisterNetEvent('esx_ambulancejob:revive', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 5000
end)

RegisterNetEvent('esx_garage:openMenu', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 5000
end)

RegisterNetEvent('skinchanger:loadSkin', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 5000
end)

-- Common housing/property systems
RegisterNetEvent('esx_property:enter', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 5000
end)

RegisterNetEvent('esx_property:exit', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 5000
end)

-- Job systems
RegisterNetEvent('esx:setJob', function()
    expectedTeleport = true
    teleportCooldown = GetGameTimer() + 3000
end)

local function IsTeleportExpected()
    if expectedTeleport and GetGameTimer() < teleportCooldown then
        return true
    end
    expectedTeleport = false
    return false
end

-- ============================================================================
-- REPORT TO SERVER
-- ============================================================================

local function ReportLegitimateState()
    local now = GetGameTimer()
    if now - lastReport < REPORT_INTERVAL then return end
    lastReport = now
    
    local scenarios = GetCurrentLegitimateScenarios()
    local speed = GetLegitimateMovementSpeed()
    local teleportExpected = IsTeleportExpected()
    
    -- Only report if we have meaningful data
    if #scenarios > 0 or teleportExpected or speed > 30 then
        TriggerServerEvent('LucidGuard:LegitimateState', {
            scenarios = scenarios,
            avgSpeed = speed,
            teleportExpected = teleportExpected,
            timestamp = now
        })
    end
end

-- ============================================================================
-- MAIN LOOP
-- ============================================================================

CreateThread(function()
    while true do
        Wait(200)
        RecordPosition()
        ReportLegitimateState()
    end
end)

-- ============================================================================
-- NOTIFY SERVER OF GAME EVENTS
-- ============================================================================

-- Vehicle enter/exit
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkPlayerEnteredVehicle' then
        TriggerServerEvent('LucidGuard:VehicleEnter')
    end
end)

-- Death
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local ped = PlayerPedId()
        
        if victim == ped and IsPedDeadOrDying(ped, true) then
            TriggerServerEvent('LucidGuard:PlayerDied')
        end
    end
end)

-- Spawn
AddEventHandler('playerSpawned', function()
    TriggerServerEvent('LucidGuard:PlayerSpawned')
end)

print('[^2LucidGuard^0] Client Legitimacy Reporter loaded')
