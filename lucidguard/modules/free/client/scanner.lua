--[[
    LucidGuard Anticheat - Resource Scanner
    Created by OnlyLucidVibes
    Scans for blacklisted/suspicious resources
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local hasScannedOnSpawn = false

-- ============================================================================
-- SCAN ON SPAWN
-- ============================================================================

AddEventHandler('playerSpawned', function()
    if not Config.Modules.ResourceScanner then return end
    if not Config.ResourceScanner.ScanOnSpawn then return end
    if hasScannedOnSpawn then return end
    
    hasScannedOnSpawn = true
    
    -- Small delay to let everything load
    Wait(3000)
    
    PerformResourceScan()
end)

-- ============================================================================
-- PERIODIC SCAN
-- ============================================================================

CreateThread(function()
    -- Wait for initialization
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(10000)
    
    if not Config.Modules.ResourceScanner then return end
    
    -- Initial scan
    Wait(5000)
    PerformResourceScan()
    
    -- Periodic scans
    while true do
        Wait(Config.ResourceScanner.PeriodicScanInterval)
        PerformResourceScan()
    end
end)

-- ============================================================================
-- PERFORM RESOURCE SCAN
-- ============================================================================

function PerformResourceScan()
    -- Skip if admin
    if IsClientAdmin() then return end
    
    local resources = {}
    local suspiciousResources = {}
    
    -- Enumerate all resources
    for i = 0, GetNumResources() - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName then
            local state = GetResourceState(resourceName)
            if state == 'started' then
                table.insert(resources, resourceName)
                
                -- Check against blacklist
                local isSuspicious, matchedPattern = CheckResourceBlacklist(resourceName)
                
                if isSuspicious then
                    table.insert(suspiciousResources, {
                        name = resourceName,
                        pattern = matchedPattern
                    })
                end
            end
        end
    end
    
    -- If suspicious resources found, report immediately
    if #suspiciousResources > 0 then
        local details = 'Suspicious resources:\n'
        for _, res in ipairs(suspiciousResources) do
            details = details .. '- ' .. res.name .. ' (matched: ' .. res.pattern .. ')\n'
        end
        
        if Config.Debug then
            print('[XX-AC] Suspicious resources detected locally!')
            print(details)
        end
        
        -- Report to server
        TriggerServerEvent('xx_ac:report', 'CHEAT_MENU', 'CRITICAL', details)
    end
    
    -- Send full resource list to server for verification
    TriggerServerEvent('xx_ac:resourceListResponse', resources)
    
    if Config.Debug then
        print(string.format('[XX-AC] Resource scan complete: %d resources, %d suspicious',
            #resources, #suspiciousResources))
    end
end

-- ============================================================================
-- CHECK RESOURCE AGAINST BLACKLIST
-- ============================================================================

function CheckResourceBlacklist(resourceName)
    local lowerName = string.lower(resourceName)
    
    -- Never flag ourselves (the anticheat resource)
    local currentResource = string.lower(GetCurrentResourceName())
    if lowerName == currentResource then
        return false, nil
    end
    
    -- Check blacklist
    for _, pattern in ipairs(Config.ResourceScanner.BlacklistedResources) do
        local lowerPattern = string.lower(pattern)
        if string.find(lowerName, lowerPattern) then
            -- Check whitelist (override)
            for _, whitePattern in ipairs(Config.ResourceScanner.WhitelistedResources) do
                if string.find(lowerName, string.lower(whitePattern)) then
                    return false, nil
                end
            end
            return true, pattern
        end
    end
    
    return false, nil
end

-- ============================================================================
-- HANDLE SERVER REQUEST FOR RESOURCE LIST
-- ============================================================================

RegisterNetEvent('xx_ac:requestResourceList')
AddEventHandler('xx_ac:requestResourceList', function()
    PerformResourceScan()
end)

-- ============================================================================
-- MONITOR FOR NEW RESOURCES STARTING
-- ============================================================================

AddEventHandler('onClientResourceStart', function(resourceName)
    if not Config.Modules.ResourceScanner then return end
    
    -- Skip if admin
    if IsClientAdmin() then return end
    
    -- Small delay
    Wait(1000)
    
    -- Check if this new resource is suspicious
    local isSuspicious, matchedPattern = CheckResourceBlacklist(resourceName)
    
    if isSuspicious then
        if Config.Debug then
            print(string.format('[XX-AC] Suspicious resource started: %s (matched: %s)',
                resourceName, matchedPattern))
        end
        
        local details = string.format('New suspicious resource started: %s (matched: %s)',
            resourceName, matchedPattern)
        TriggerServerEvent('xx_ac:report', 'RESOURCE_INJECTION', 'CRITICAL', details)
    end
end)

-- ============================================================================
-- DETECT RESOURCE METADATA TAMPERING
-- ============================================================================

CreateThread(function()
    -- Wait for initialization
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(30000) -- Wait for everything to stabilize
    
    if not Config.Modules.ResourceScanner then return end
    
    -- Store original metadata for comparison
    local originalMetadata = {}
    
    for i = 0, GetNumResources() - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName then
            originalMetadata[resourceName] = {
                version = GetResourceMetadata(resourceName, 'version', 0),
                author = GetResourceMetadata(resourceName, 'author', 0)
            }
        end
    end
    
    while true do
        Wait(120000) -- Check every 2 minutes
        
        -- Skip if admin
        if IsClientAdmin() then goto continue end
        
        -- Compare current metadata with original
        for resourceName, original in pairs(originalMetadata) do
            local currentVersion = GetResourceMetadata(resourceName, 'version', 0)
            local currentAuthor = GetResourceMetadata(resourceName, 'author', 0)
            
            -- Check for changes (could indicate injection)
            if currentVersion ~= original.version or currentAuthor ~= original.author then
                local details = string.format('Resource metadata changed: %s (version: %s->%s)',
                    resourceName, original.version or 'nil', currentVersion or 'nil')
                
                if Config.Debug then
                    print('[XX-AC] ' .. details)
                end
                
                -- Update stored metadata
                originalMetadata[resourceName] = {
                    version = currentVersion,
                    author = currentAuthor
                }
                
                -- Only report if it's a significant resource
                if resourceName == Config.ResourceName then
                    TriggerServerEvent('xx_ac:report', 'METADATA_TAMPER', 'HIGH', details)
                end
            end
        end
        
        ::continue::
    end
end)
