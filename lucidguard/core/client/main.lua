--[[
    LucidGuard Anticheat - Client Main
    Created by OnlyLucidVibes
    Core client-side functionality and utilities
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local isInitialized = false

-- ============================================================================
-- TIER GATING (synced from server via license.lua)
-- ============================================================================

local activeTier = 'FREE'
local TIER_LEVELS = { FREE = 1, BASIC = 2, ADVANCED = 3 }

RegisterNetEvent('lg_ac:setTier')
AddEventHandler('lg_ac:setTier', function(tier)
    if TIER_LEVELS[tier] then
        activeTier = tier
    end
end)

-- Global function for module self-gating
function RequiresTier(requiredTier)
    local reqLevel = TIER_LEVELS[requiredTier] or 3
    local curLevel = TIER_LEVELS[activeTier] or 1
    return curLevel >= reqLevel
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsPlayerActive(PlayerId()) then
            isInitialized = true
            break
        end
    end
    
    -- Longer delay to ensure everything is loaded (players can fall through map while textures load)
    Wait(5000)
    
    if Config.Debug then
        print('[XX-AC] Client initialized')
    end
end)

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Check if player is admin (client-side cache)
local isAdmin = false

function IsClientAdmin()
    return isAdmin
end

-- Called from server to update admin status
RegisterNetEvent('xx_ac:setAdminStatus')
AddEventHandler('xx_ac:setAdminStatus', function(status)
    isAdmin = status
end)

-- ============================================================================
-- PLAYER STATE CONTEXT
-- Gathers current player state so the server can distinguish hacks from
-- legitimate game actions (ragdoll, falling, vehicle, interior transition)
-- ============================================================================

local lastInteriorId = 0

function GetPlayerStateContext()
    local ped = PlayerPedId()
    return {
        isInVehicle = IsPedInAnyVehicle(ped, false),
        isFalling = IsPedFalling(ped),
        isRagdoll = IsPedRagdoll(ped),
        isInAir = IsEntityInAir(ped),
        isDead = IsEntityDead(ped),
        isSwimming = IsPedSwimming(ped),
        interiorId = GetInteriorFromEntity(ped),
        speed = GetEntitySpeed(ped)
    }
end

-- ============================================================================
-- REPORT DETECTION TO SERVER
-- ============================================================================

function ReportDetection(detectionType, severity, details)
    -- Don't report if admin
    if isAdmin then return end

    -- Attach player state context so the server can filter false positives
    local context = GetPlayerStateContext()
    local contextStr = string.format(
        ' | Context: vehicle=%s, falling=%s, ragdoll=%s, inAir=%s, interior=%d, speed=%.1f',
        tostring(context.isInVehicle), tostring(context.isFalling),
        tostring(context.isRagdoll), tostring(context.isInAir),
        context.interiorId, context.speed
    )

    TriggerServerEvent('xx_ac:report', detectionType, severity, (details or '') .. contextStr)
end

-- ============================================================================
-- GET PLAYER DATA
-- ============================================================================

function GetPlayerCoords()
    local ped = PlayerPedId()
    return GetEntityCoords(ped)
end

function GetPlayerSpeed()
    local ped = PlayerPedId()
    return GetEntitySpeed(ped)
end

function GetPlayerHealth()
    local ped = PlayerPedId()
    return GetEntityHealth(ped)
end

function GetPlayerArmour()
    local ped = PlayerPedId()
    return GetPedArmour(ped)
end

-- ============================================================================
-- POSITION REPORTING (with interior-change tracking and randomized interval)
-- ============================================================================

CreateThread(function()
    while not isInitialized do Wait(100) end

    while true do
        -- Randomize interval so cheaters can't time bursts between checks
        Wait(math.random(4000, 7000))

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        -- Track interior changes to suppress teleport false positives
        -- MLO transitions teleport the player into an interior bucket
        local currentInterior = GetInteriorFromEntity(ped)
        if currentInterior ~= lastInteriorId then
            lastInteriorId = currentInterior
            -- Notify teleport detection to reset (interior transition = legitimate teleport)
            TriggerEvent('xx_ac:resetTeleportCheck')
        end

        TriggerServerEvent('xx_ac:position', {
            x = coords.x,
            y = coords.y,
            z = coords.z
        })
    end
end)

-- ============================================================================
-- RESOURCE LIST REQUEST HANDLER
-- ============================================================================

RegisterNetEvent('xx_ac:requestResourceList')
AddEventHandler('xx_ac:requestResourceList', function()
    -- Wait for slow PCs where resources may still be starting
    Wait(2000)

    local resources = {}

    for i = 0, GetNumResources() - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName and GetResourceState(resourceName) == 'started' then
            table.insert(resources, resourceName)
        end
    end

    TriggerServerEvent('xx_ac:resourceListResponse', resources)
end)

-- ============================================================================
-- ANTI-TAMPER: Detect resource stop attempts
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == Config.ResourceName then
        -- Someone tried to stop the anticheat
        TriggerServerEvent('xx_ac:report', 'RESOURCE_TAMPER', 'CRITICAL', 
            'Anticheat resource stop attempted')
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ReportDetection', ReportDetection)
exports('IsClientAdmin', IsClientAdmin)
exports('GetPlayerCoords', GetPlayerCoords)
exports('GetPlayerSpeed', GetPlayerSpeed)
exports('GetPlayerStateContext', GetPlayerStateContext)
exports('RequiresTier', RequiresTier)
