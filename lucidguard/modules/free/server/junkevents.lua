--[[
    LucidGuard Anticheat - Junk Events & Trap System (Server)
    Created by OnlyLucidVibes
    
    Creates 100+ fake events that look like legitimate server events.
    These events serve no purpose - they're TRAPS.
    Any client that triggers them is using an event dumper/spammer.
    
    Categories:
    - Fake economy events (esx:giveMoney, etc.)
    - Fake admin events (admin:godmode, etc.)
    - Fake weapon events (giveWeapon, etc.)
    - Fake vehicle events (spawnVehicle, etc.)
    - Fake inventory events (addItem, etc.)
    - Common cheat menu event patterns
]]

-- ============================================================================
-- TRAP TRIGGERED HANDLER
-- ============================================================================

local function TrapTriggered(source, eventName)
    local playerName = GetPlayerName(source)
    if not playerName then return end
    
    -- Admin immunity
    if IsPlayerAdmin(source) then return end
    
    print(string.format('[LucidGuard] TRAP TRIGGERED: %s (%s) called %s',
        playerName, source, eventName))
    
    -- This is ALWAYS malicious - no legitimate client would call these
    TriggerEvent('lucidguard:sendWebhook', 'EVENT_TRAP', playerName, source, {
        ['Detection'] = 'Trap Event Triggered',
        ['Event Name'] = eventName,
        ['Risk Level'] = 'CRITICAL',
        ['Action'] = 'Using event spammer/dumper'
    }, 'CRITICAL')
    
    -- Immediate ban
    TriggerEvent('lucidguard:punish', source, 'EVENT_TRAP', 
        'Triggered trap event: ' .. eventName)
end

-- ============================================================================
-- FAKE ECONOMY EVENTS
-- ============================================================================

-- IMPORTANT: These are FAKE events that do NOT exist in real ESX/QB
-- Real ESX events like esx:setAccountMoney are NOT included here
local economyTraps = {
    -- These are fake/cheat-style events that no legitimate script uses
    'cheat:giveMoney',
    'hack:addMoney',
    'exploit:setMoney',
    'mod:giveCash',
    'trainer:money',
    'menu:addMoney',
    'injector:cash',
    'free:money',
    'money:cheat',
    'instant:cash',
    'unlimited:money',
    'godmoney:add',
    'freecash:give',
    'moneyhack:execute',
    'cashgiver:run',
}

-- ============================================================================
-- FAKE ADMIN EVENTS
-- ============================================================================

-- These are clearly cheat/exploit event names - no legitimate script uses these
local adminTraps = {
    'cheat:godmode',
    'hack:noclip',
    'exploit:invisible',
    'menu:giveweapon',
    'trainer:spawnvehicle',
    'injector:teleport',
    'godmode:enable',
    'noclip:toggle',
    'invisible:on',
    'fly:enable',
    'superjump:activate',
    'superrun:enable',
    'cheat:revive',
    'hack:heal',
    'exploit:armor',
    'menu:setjob',
    'trainer:setgroup',
}

-- ============================================================================
-- FAKE WEAPON EVENTS
-- ============================================================================

-- Clearly cheat-style event names
local weaponTraps = {
    'cheat:giveAllWeapons',
    'hack:unlimitedAmmo',
    'exploit:weaponDamage',
    'menu:giveWeapon',
    'trainer:allGuns',
    'injector:weapons',
    'weaponhack:enable',
    'infiniteammo:toggle',
    'rapidfire:enable',
    'explosive:ammo',
    'aimbot:enable',
    'triggerbot:on',
    'norecoil:enable',
    'nospread:toggle',
}

-- ============================================================================
-- FAKE VEHICLE EVENTS
-- ============================================================================

-- Clearly cheat-style event names
local vehicleTraps = {
    'cheat:spawnVehicle',
    'hack:spawnCar',
    'exploit:spawnAny',
    'menu:carSpawner',
    'trainer:spawnVeh',
    'injector:vehicle',
    'vehiclehack:spawn',
    'carspawner:any',
    'godcar:spawn',
    'speedhack:vehicle',
    'vehiclefly:enable',
    'carjump:enable',
    'vehiclegod:toggle',
}

-- ============================================================================
-- FAKE INVENTORY EVENTS
-- ============================================================================

-- Clearly cheat-style event names
local inventoryTraps = {
    'cheat:giveItem',
    'hack:giveAllItems',
    'exploit:inventory',
    'menu:itemGiver',
    'trainer:addItem',
    'injector:items',
    'itemhack:give',
    'itemspawner:run',
    'unlimitedItems:enable',
    'inventoryhack:fill',
}

-- ============================================================================
-- FAKE JOB/RANK EVENTS
-- ============================================================================

-- Clearly cheat-style event names
local jobTraps = {
    'cheat:setJob',
    'hack:setRank',
    'exploit:setAdmin',
    'menu:giveRank',
    'trainer:setJob',
    'injector:admin',
    'jobhack:set',
    'rankhack:give',
    'adminexploit:set',
}

-- ============================================================================
-- COMMON CHEAT MENU PATTERNS
-- ============================================================================

-- These are KNOWN cheat menu event prefixes - 100% malicious
local cheatTraps = {
    -- Known cheat menus (specific patterns that won't conflict)
    'eulen_anticheat_bypass',
    'eulen_executor',
    'lynx_executor',
    'lynx_bypass',
    'redengine_exec',
    'redengine_bypass',
    'hammafia_exec',
    'hammafia_bypass',
    'desudo_executor',
    'skid_menu',
    
    -- Generic cheat patterns (very specific to avoid conflicts)
    'cheatengine:execute',
    'hackloader:run',
    'exploitkit:inject',
    'bypassac:enable',
    'modmenu:open',
    'trainer:execute',
    'injector:loadlua',
    'luaexecutor:run',
    'remotecode:execute',
    'dumpevents:all',
    'spoofidentity:set',
}

-- ============================================================================
-- REGISTER ALL TRAPS
-- ============================================================================

local function RegisterTraps(trapList, category)
    for _, eventName in ipairs(trapList) do
        RegisterNetEvent(eventName, function(...)
            local source = source
            TrapTriggered(source, eventName)
        end)
    end
    
    if Config.Debug then
        print(string.format('[LucidGuard] Registered %d %s traps', 
            #trapList, category))
    end
end

CreateThread(function()
    Wait(1000)
    
    RegisterTraps(economyTraps, 'economy')
    RegisterTraps(adminTraps, 'admin')
    RegisterTraps(weaponTraps, 'weapon')
    RegisterTraps(vehicleTraps, 'vehicle')
    RegisterTraps(inventoryTraps, 'inventory')
    RegisterTraps(jobTraps, 'job')
    RegisterTraps(cheatTraps, 'cheat')
    
    local totalTraps = #economyTraps + #adminTraps + #weaponTraps + 
                       #vehicleTraps + #inventoryTraps + #jobTraps + #cheatTraps
    
    print(string.format('[LucidGuard] Registered %d trap events', totalTraps))
end)

-- ============================================================================
-- DYNAMIC TRAP: Unknown Event Handler
-- ============================================================================

-- Track what events are called and flag suspicious patterns
local eventCallCounts = {}
local suspiciousPatterns = {
    'money', 'cash', 'weapon', 'spawn', 'god', 'admin', 'cheat', 'hack',
    'give', 'add', 'set', 'teleport', 'noclip', 'invisible', 'ban'
}

AddEventHandler('__cfx_internal:commandFallback', function(eventName)
    -- This catches events that don't have handlers
    local source = source
    
    if source and source > 0 then
        local playerName = GetPlayerName(source)
        
        -- Check if event name matches suspicious patterns
        local eventLower = string.lower(eventName or '')
        
        for _, pattern in ipairs(suspiciousPatterns) do
            if string.find(eventLower, pattern) then
                print(string.format('[LucidGuard] Suspicious event: %s called %s',
                    playerName or 'Unknown', eventName))
                
                -- Track
                eventCallCounts[source] = eventCallCounts[source] or {}
                eventCallCounts[source][eventName] = (eventCallCounts[source][eventName] or 0) + 1
                
                -- Too many calls = spammer
                if eventCallCounts[source][eventName] >= 5 then
                    TriggerEvent('lucidguard:sendWebhook', 'EVENT_SPAM', 
                        playerName or 'Unknown', source, {
                        ['Detection'] = 'Event Spamming',
                        ['Event'] = eventName,
                        ['Calls'] = eventCallCounts[source][eventName]
                    }, 'HIGH')
                end
                
                break
            end
        end
    end
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    local source = source
    eventCallCounts[source] = nil
end)
