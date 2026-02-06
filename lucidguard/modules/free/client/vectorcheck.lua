--[[
    LucidGuard Anticheat - Advanced Noclip Detection (Vector Validation)
    Created by OnlyLucidVibes
    
    Uses raycasting to detect players moving THROUGH walls/objects.
    Checks:
    - Distance vs obstacles (raycast between positions)
    - Z-axis changes without vehicle/elevator
    - Interior transitions without doors
    
    IMPORTANT: This module is designed to MINIMIZE false positives.
    It will NOT flag legitimate teleports, respawns, or script actions.
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local positionHistory = {}
local lastRaycastCheck = 0
local wallClipViolations = 0
local zClipViolations = 0
local lastTeleportTime = 0  -- Track legitimate teleports
local wasRecentlyDead = false

-- Known elevator locations (add your server's elevator coords)
local elevatorLocations = {
    -- Example: Maze Bank Tower elevators
    vector3(-75.0, -827.0, 243.0),
    vector3(-75.0, -827.0, 37.0),
    -- Add more elevator locations...
}

-- ============================================================================
-- TELEPORT WHITELIST: Detect legitimate teleports from scripts
-- ============================================================================

-- Listen for common teleport events from scripts
RegisterNetEvent('esx:teleport', function() lastTeleportTime = GetGameTimer() end)
RegisterNetEvent('esx_skin:openMenu', function() lastTeleportTime = GetGameTimer() end)
RegisterNetEvent('skinchanger:loadSkin', function() lastTeleportTime = GetGameTimer() end)
RegisterNetEvent('hospital:respawn', function() lastTeleportTime = GetGameTimer() end)
RegisterNetEvent('esx_ambulancejob:revive', function() lastTeleportTime = GetGameTimer() end)
RegisterNetEvent('esx:onPlayerSpawn', function() lastTeleportTime = GetGameTimer() end)

-- Check if teleport was recent (within 5 seconds)
local function WasRecentlyTeleported()
    return (GetGameTimer() - lastTeleportTime) < 5000
end

-- ============================================================================
-- POSITION TRACKING
-- ============================================================================

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(5000)
    
    if not Config.Modules.VectorValidation then return end
    
    while true do
        Wait(2000) -- Check every 2 seconds (as recommended)
        
        -- Skip if admin
        if IsClientAdmin() then goto continue end
        
        local ped = PlayerPedId()
        
        -- Skip if dead
        if IsEntityDead(ped) then
            positionHistory = {}
            wasRecentlyDead = true
            goto continue
        end
        
        -- Skip for a few seconds after respawning from death
        if wasRecentlyDead then
            wasRecentlyDead = false
            positionHistory = {}
            Wait(3000) -- Wait 3 seconds after respawn
            goto continue
        end
        
        -- Skip if recently teleported by a script
        if WasRecentlyTeleported() then
            positionHistory = {}
            goto continue
        end
        
        -- Skip if in a loading screen or fading
        if IsPlayerSwitchInProgress() or IsScreenFadedOut() or IsScreenFadingOut() then
            positionHistory = {}
            goto continue
        end
        
        local currentPos = GetEntityCoords(ped)
        local currentTime = GetGameTimer()
        local inVehicle = IsPedInAnyVehicle(ped, false)
        local interior = GetInteriorFromEntity(ped)
        
        -- Store position data
        local posData = {
            pos = currentPos,
            time = currentTime,
            inVehicle = inVehicle,
            interior = interior,
            z = currentPos.z
        }
        
        -- Add to history
        table.insert(positionHistory, posData)
        
        -- Keep only last 5 positions
        if #positionHistory > 5 then
            table.remove(positionHistory, 1)
        end
        
        -- Need at least 2 positions to compare
        if #positionHistory < 2 then goto continue end
        
        local prevData = positionHistory[#positionHistory - 1]
        local prevPos = prevData.pos
        
        -- Calculate movement
        local distance = #(currentPos - prevPos)
        local zChange = math.abs(currentPos.z - prevPos.z)
        local timeDelta = (currentTime - prevData.time) / 1000 -- seconds
        
        -- ====================================================================
        -- CHECK 1: Z-Axis Change Validation
        -- Large Z changes without vehicle or elevator = noclip
        -- ====================================================================
        
        if zChange > Config.VectorValidation.MaxZChangeOnFoot then
            -- Check if in vehicle (legitimate)
            if not inVehicle and not prevData.inVehicle then
                -- Check if near elevator
                local nearElevator = IsNearElevator(currentPos) or IsNearElevator(prevPos)
                
                -- Check if using ladder
                local onLadder = GetPedConfigFlag(ped, 388, true) -- Climbing flag
                
                -- Check if in parachute
                local inParachute = IsPedInParachuteFreeFall(ped) or GetPedParachuteState(ped) > 0
                
                -- Check if falling (ragdoll or falling animation)
                local isFalling = IsPedFalling(ped) or IsPedRagdoll(ped)
                
                -- Check if recently teleported by script
                local recentTeleport = WasRecentlyTeleported()
                
                -- Check if swimming/diving (can change Z quickly)
                local isSwimming = IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)
                
                if not nearElevator and not onLadder and not inParachute and not isFalling and not recentTeleport and not isSwimming then
                    zClipViolations = zClipViolations + 1
                    
                    if Config.Debug then
                        print(string.format('[LucidGuard] Z-Clip: %.1fm change in %.1fs', 
                            zChange, timeDelta))
                    end
                    
                    -- Require MORE violations before flagging (safety margin)
                    if zClipViolations >= (Config.VectorValidation.ViolationsBeforeFlag + 2) then
                        ReportDetection('Z_CLIP', 'HIGH',
                            string.format('Z-axis change: %.1fm in %.1fs without vehicle/elevator',
                                zChange, timeDelta))
                        zClipViolations = 0
                    end
                end
            end
        end
        
        -- ====================================================================
        -- CHECK 2: Raycast Wall Clip Detection
        -- Cast ray between positions, if blocked = they went through something
        -- ====================================================================
        
        if distance > Config.VectorValidation.MinDistanceForRaycast then
            -- Perform raycast from previous position to current
            local rayResult = PerformWallRaycast(prevPos, currentPos)
            
            if rayResult.hit then
                -- Something was between the two positions
                local entityHit = rayResult.entityHit
                local isStatic = false
                
                if entityHit and entityHit ~= 0 then
                    -- Check if it's a static world object (building, wall)
                    isStatic = IsEntityStatic(entityHit) or GetEntityType(entityHit) == 0
                else
                    -- No entity but ray hit something = world geometry
                    isStatic = true
                end
                
                if isStatic then
                    -- Player moved through a wall!
                    wallClipViolations = wallClipViolations + 1
                    
                    if Config.Debug then
                        print(string.format('[LucidGuard] Wall clip detected! Distance: %.1fm', distance))
                    end
                    
                    if wallClipViolations >= Config.VectorValidation.WallClipThreshold then
                        local coords = rayResult.hitCoords
                        ReportDetection('WALL_CLIP', 'CRITICAL',
                            string.format('Passed through wall at %.1f, %.1f, %.1f (traveled %.1fm)',
                                coords.x, coords.y, coords.z, distance))
                        wallClipViolations = 0
                    end
                end
            end
        end
        
        -- ====================================================================
        -- CHECK 3: Interior Transition Without Door
        -- If interior changed but they didn't use a door = teleport/noclip
        -- ====================================================================
        
        if interior ~= prevData.interior then
            -- Interior changed
            local usedDoor = DidPlayerUseDoor(prevPos, currentPos)
            
            if not usedDoor and not inVehicle then
                if Config.Debug then
                    print(string.format('[LucidGuard] Interior change without door: %d -> %d',
                        prevData.interior, interior))
                end
                
                -- This could be legitimate (some scripts teleport to interiors)
                -- Just log it for now
                -- ReportDetection('INTERIOR_CLIP', 'MEDIUM', ...)
            end
        end
        
        -- Decay violations over time
        if wallClipViolations > 0 then
            wallClipViolations = wallClipViolations - 0.1
        end
        if zClipViolations > 0 then
            zClipViolations = zClipViolations - 0.1
        end
        
        ::continue::
    end
end)

-- ============================================================================
-- RAYCAST FUNCTION
-- ============================================================================

function PerformWallRaycast(startPos, endPos)
    -- Offset positions slightly to avoid self-collision
    local start = vector3(startPos.x, startPos.y, startPos.z + 0.5)
    local finish = vector3(endPos.x, endPos.y, endPos.z + 0.5)
    
    -- Cast ray - flags: 1 = world, 16 = objects, 256 = vehicles (we want world + objects)
    local rayHandle = StartShapeTestRay(
        start.x, start.y, start.z,
        finish.x, finish.y, finish.z,
        1 + 16, -- World geometry + objects
        PlayerPedId(),
        0
    )
    
    local _, hit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    
    return {
        hit = hit == 1,
        hitCoords = hitCoords,
        surfaceNormal = surfaceNormal,
        entityHit = entityHit
    }
end

-- ============================================================================
-- HELPER: Check if near elevator
-- ============================================================================

function IsNearElevator(pos)
    for _, elevatorPos in ipairs(elevatorLocations) do
        local dist = #(pos - elevatorPos)
        if dist < 10.0 then
            return true
        end
    end
    return false
end

-- ============================================================================
-- HELPER: Check if player used a door
-- ============================================================================

function DidPlayerUseDoor(fromPos, toPos)
    -- Check for door entities between positions
    local midPoint = (fromPos + toPos) / 2
    
    -- Look for nearby door objects
    local doorHash = GetHashKey('prop_door_01')
    local nearbyDoor = GetClosestObjectOfType(
        midPoint.x, midPoint.y, midPoint.z,
        5.0, doorHash, false, false, false
    )
    
    if nearbyDoor and nearbyDoor ~= 0 then
        return true
    end
    
    -- Also check for garage doors, gates, etc.
    -- This is a simplified check - you may want to expand it
    return false
end

-- ============================================================================
-- CONTINUOUS MICRO-RAYCAST (Detect phasing in real-time)
-- NOTE: This is more aggressive, so it only adds small violation increments
-- ============================================================================

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(10000)
    
    if not Config.Modules.VectorValidation then return end
    
    local lastPos = nil
    local lastVehicleState = false
    
    while true do
        Wait(100) -- More frequent checks
        
        -- Skip if admin
        if IsClientAdmin() then 
            lastPos = nil
            goto continue 
        end
        
        local ped = PlayerPedId()
        if IsEntityDead(ped) then 
            lastPos = nil
            goto continue 
        end
        
        -- Skip if recently teleported by script
        if WasRecentlyTeleported() then
            lastPos = nil
            goto continue
        end
        
        local inVehicle = IsPedInAnyVehicle(ped, false)
        
        -- Reset if vehicle state changed (entering/exiting vehicle)
        if inVehicle ~= lastVehicleState then
            lastPos = nil
            lastVehicleState = inVehicle
            goto continue
        end
        
        -- Skip raycast if in vehicle (going through garages, etc.)
        if inVehicle then
            lastPos = nil
            goto continue
        end
        
        local currentPos = GetEntityCoords(ped)
        
        if lastPos then
            local dist = #(currentPos - lastPos)
            
            -- Only check if moved moderately (not too little, not teleport distance)
            -- Reduced upper threshold from 50 to 20 to avoid false positives
            if dist > 3.0 and dist < 20.0 then
                local ray = PerformWallRaycast(lastPos, currentPos)
                
                if ray.hit then
                    -- Only add small increment - requires many hits to flag
                    wallClipViolations = wallClipViolations + 0.3
                    
                    if Config.Debug then
                        print('[LucidGuard] Micro-raycast: Wall penetration detected')
                    end
                end
            end
        end
        
        lastPos = currentPos
        lastVehicleState = inVehicle
        
        ::continue::
    end
end)

-- ============================================================================
-- UNDERGROUND CHECK
-- ============================================================================

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(5000)
    
    if not Config.Modules.VectorValidation then return end
    
    local undergroundCount = 0  -- Require multiple checks to avoid false positives
    
    while true do
        Wait(5000)
        
        -- Skip if admin
        if IsClientAdmin() then goto continue end
        
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        
        -- Skip if in vehicle (submarines, etc.)
        if IsPedInAnyVehicle(ped, false) then goto continue end
        
        -- Skip if swimming/underwater (legitimate)
        if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then goto continue end
        
        -- Skip if in an interior
        local interior = GetInteriorFromEntity(ped)
        if interior ~= 0 then goto continue end
        
        -- Skip if recently teleported
        if WasRecentlyTeleported() then goto continue end
        
        -- Get ground Z at player position
        local foundGround, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
        
        if foundGround then
            -- Check if player is SIGNIFICANTLY below ground level
            -- Using 10m threshold instead of 5m to avoid edge cases
            if pos.z < groundZ - 10.0 then
                undergroundCount = undergroundCount + 1
                
                if Config.Debug then
                    print(string.format('[LucidGuard] Underground check: Z=%.1f, Ground=%.1f, Count=%d',
                        pos.z, groundZ, undergroundCount))
                end
                
                -- Require 3 consecutive underground checks before flagging
                if undergroundCount >= 3 then
                    ReportDetection('UNDERGROUND', 'HIGH',
                        string.format('Player at Z=%.1f, ground at Z=%.1f (%.1fm below surface)',
                            pos.z, groundZ, groundZ - pos.z))
                    undergroundCount = 0
                end
            else
                -- Reset counter if player is above ground
                undergroundCount = 0
            end
        end
        
        ::continue::
    end
end)
