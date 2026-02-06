--[[
    LucidGuard Anticheat - Client Integrity
    Created by OnlyLucidVibes
    Honey pot traps, resource verification, and token handling
]]

-- ============================================================================
-- HONEY POT VARIABLES (TRAPS)
-- These variables are bait - cheats scan for "Admin" variables
-- If any of these change to true, it's an instant detection
-- ============================================================================

-- Create honey pot traps
Config.AdminMenu = false
Config.GodModeEnabled = false
Config.MoneyHack = false
Config.InfiniteAmmo = false
Config.NoClipEnabled = false
Config.AdminMode = false
Config.CheatEnabled = false
Config.BypassAnticheat = false

-- Store original values
local honeyPotValues = {
    AdminMenu = false,
    GodModeEnabled = false,
    MoneyHack = false,
    InfiniteAmmo = false,
    NoClipEnabled = false,
    AdminMode = false,
    CheatEnabled = false,
    BypassAnticheat = false
}

-- ============================================================================
-- VARIABLES
-- ============================================================================

local securityToken = nil
local isTokenValid = false
local resourceCountAtStart = 0

-- ============================================================================
-- TOKEN HANDLING
-- ============================================================================

RegisterNetEvent('lg_ac:setToken')
AddEventHandler('lg_ac:setToken', function(token)
    securityToken = token
    isTokenValid = true
    
    if Config.Debug then
        print('[LucidGuard] Security token received')
    end
end)

RegisterNetEvent('lg_ac:tokenVerified')
AddEventHandler('lg_ac:tokenVerified', function(valid)
    isTokenValid = valid
    
    if not valid then
        print('[LucidGuard] Token verification failed!')
    end
end)

-- Get current token for secure events
function GetSecurityToken()
    return securityToken
end

-- Verify token is valid
function IsTokenValid()
    return isTokenValid and securityToken ~= nil
end

-- ============================================================================
-- HONEY POT MONITORING
-- ============================================================================

CreateThread(function()
    -- Wait for initialization
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(5000)
    
    if not Config.Modules.ClientIntegrity then return end
    if not Config.ClientIntegrity.HoneyPots.Enabled then return end
    
    while true do
        Wait(5000) -- Check every 5 seconds
        
        -- Skip if admin
        if IsClientAdmin() then goto continue end
        
        -- Check each honey pot variable
        local triggered = false
        local triggeredVar = nil
        
        if Config.AdminMenu ~= honeyPotValues.AdminMenu then
            triggered = true
            triggeredVar = 'AdminMenu'
        elseif Config.GodModeEnabled ~= honeyPotValues.GodModeEnabled then
            triggered = true
            triggeredVar = 'GodModeEnabled'
        elseif Config.MoneyHack ~= honeyPotValues.MoneyHack then
            triggered = true
            triggeredVar = 'MoneyHack'
        elseif Config.InfiniteAmmo ~= honeyPotValues.InfiniteAmmo then
            triggered = true
            triggeredVar = 'InfiniteAmmo'
        elseif Config.NoClipEnabled ~= honeyPotValues.NoClipEnabled then
            triggered = true
            triggeredVar = 'NoClipEnabled'
        elseif Config.AdminMode ~= honeyPotValues.AdminMode then
            triggered = true
            triggeredVar = 'AdminMode'
        elseif Config.CheatEnabled ~= honeyPotValues.CheatEnabled then
            triggered = true
            triggeredVar = 'CheatEnabled'
        elseif Config.BypassAnticheat ~= honeyPotValues.BypassAnticheat then
            triggered = true
            triggeredVar = 'BypassAnticheat'
        end
        
        if triggered then
            print('[LucidGuard] HONEY POT TRIGGERED: ' .. triggeredVar)
            
            -- Report to server immediately
            TriggerServerEvent('xx_ac:report', 'HONEY_POT_TRIGGERED', 'CRITICAL',
                string.format('Honey pot variable modified: Config.%s', triggeredVar))
            
            -- Reset the variable
            Config[triggeredVar] = honeyPotValues[triggeredVar]
        end
        
        ::continue::
    end
end)

-- ============================================================================
-- RESOURCE COUNT VERIFICATION
-- ============================================================================

CreateThread(function()
    -- Wait for initialization
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(10000) -- Wait for all resources to load
    
    if not Config.Modules.ClientIntegrity then return end
    if not Config.ClientIntegrity.ResourceVerification.Enabled then return end
    
    -- Count resources at startup
    resourceCountAtStart = 0
    for i = 0, GetNumResources() - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName and GetResourceState(resourceName) == 'started' then
            resourceCountAtStart = resourceCountAtStart + 1
        end
    end
    
    -- Report initial count to server
    TriggerServerEvent('lg_ac:resourceCount', resourceCountAtStart)
    
    -- Periodic verification
    while true do
        Wait(Config.ClientIntegrity.ResourceVerification.CheckInterval)
        
        -- Skip if admin
        if IsClientAdmin() then goto continue end
        
        -- Count current resources
        local currentCount = 0
        for i = 0, GetNumResources() - 1 do
            local resourceName = GetResourceByFindIndex(i)
            if resourceName and GetResourceState(resourceName) == 'started' then
                currentCount = currentCount + 1
            end
        end
        
        -- Check for new resources (ghost injection)
        if currentCount > resourceCountAtStart then
            local diff = currentCount - resourceCountAtStart
            print(string.format('[LucidGuard] Resource count increased by %d', diff))
            
            -- Report to server
            TriggerServerEvent('lg_ac:resourceCount', currentCount)
            
            -- Could be a legitimate resource start, so just log
            TriggerServerEvent('xx_ac:report', 'RESOURCE_COUNT_CHANGE', 'MEDIUM',
                string.format('Resource count changed: %d -> %d (+%d)',
                    resourceCountAtStart, currentCount, diff))
            
            -- Update baseline
            resourceCountAtStart = currentCount
        end
        
        ::continue::
    end
end)

-- ============================================================================
-- DETECT INJECTED GLOBAL VARIABLES
-- ============================================================================

local knownGlobals = {}

CreateThread(function()
    -- Wait for initialization
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(15000)
    
    if not Config.Modules.ClientIntegrity then return end
    
    -- Capture initial global state
    for k, v in pairs(_G) do
        knownGlobals[k] = type(v)
    end
    
    while true do
        Wait(30000) -- Check every 30 seconds
        
        -- Skip if admin
        if IsClientAdmin() then goto continue end
        
        -- Check for new suspicious globals
        for k, v in pairs(_G) do
            if not knownGlobals[k] then
                -- New global detected
                local suspicious = false
                local lowerKey = string.lower(k)
                
                -- Check for suspicious names
                local suspiciousPatterns = {
                    'cheat', 'hack', 'inject', 'bypass', 'menu',
                    'executor', 'lua', 'exec', 'admin', 'god'
                }
                
                for _, pattern in ipairs(suspiciousPatterns) do
                    if string.find(lowerKey, pattern) then
                        suspicious = true
                        break
                    end
                end
                
                if suspicious then
                    print('[LucidGuard] Suspicious global detected: ' .. k)
                    
                    TriggerServerEvent('xx_ac:report', 'SUSPICIOUS_GLOBAL', 'HIGH',
                        string.format('New suspicious global variable: %s (type: %s)',
                            k, type(v)))
                end
                
                -- Add to known list
                knownGlobals[k] = type(v)
            end
        end
        
        ::continue::
    end
end)

-- ============================================================================
-- DETECT NATIVE FUNCTION TAMPERING
-- ============================================================================

local nativeFunctions = {}

CreateThread(function()
    -- Wait for initialization
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(5000)
    
    if not Config.Modules.ClientIntegrity then return end
    
    -- Store references to critical natives
    nativeFunctions = {
        GetEntityHealth = GetEntityHealth,
        SetEntityHealth = SetEntityHealth,
        GetPlayerPed = GetPlayerPed,
        SetEntityCoords = SetEntityCoords,
        GetEntityCoords = GetEntityCoords,
        SetPedArmour = SetPedArmour,
        GiveWeaponToPed = GiveWeaponToPed
    }
    
    while true do
        Wait(60000) -- Check every minute
        
        -- Skip if admin
        if IsClientAdmin() then goto continue end
        
        -- Check if natives have been replaced
        for name, originalFunc in pairs(nativeFunctions) do
            local currentFunc = _G[name]
            
            if currentFunc ~= originalFunc then
                print('[LucidGuard] Native function tampered: ' .. name)
                
                TriggerServerEvent('xx_ac:report', 'NATIVE_TAMPER', 'CRITICAL',
                    string.format('Native function tampered: %s', name))
                
                -- Restore original
                _G[name] = originalFunc
            end
        end
        
        ::continue::
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetSecurityToken', GetSecurityToken)
exports('IsTokenValid', IsTokenValid)
