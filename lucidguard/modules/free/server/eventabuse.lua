--[[
    Free tier — server-authoritative network event abuse
    Covers: clearPedTasks, giveWeapon, ptFx spam, projectiles, blacklisted vehicles
]]

local strikes = {}

local function bump(src, key, max, detection, severity, details)
    if not src or src <= 0 then return end
    if IsPlayerAdmin and IsPlayerAdmin(src) then return end
    strikes[src] = strikes[src] or {}
    strikes[src][key] = (strikes[src][key] or 0) + 1
    if strikes[src][key] >= max then
        strikes[src][key] = 0
        if ProcessDetection then
            ProcessDetection(src, detection, severity, details)
        end
    end
end

AddEventHandler('playerDropped', function()
    strikes[source] = nil
end)

-- clearPedTasks — common freeze/kill menus (cancel + strike)
AddEventHandler('clearPedTasksEvent', function(sender, data)
    if not Config.Modules.EventAbuse then return end
    if IsPlayerAdmin and IsPlayerAdmin(sender) then return end
    CancelEvent()
    bump(sender, 'cleartasks', Config.EventAbuse.ClearTasksStrikes or 3,
        'CLEAR_PED_TASKS', 'CRITICAL', 'clearPedTasksEvent blocked')
end)

-- Unauthorized weapon give over network
AddEventHandler('giveWeaponEvent', function(sender, data)
    if not Config.Modules.EventAbuse then return end
    if IsPlayerAdmin and IsPlayerAdmin(sender) then return end
    CancelEvent()
    if ProcessDetection then
        ProcessDetection(sender, 'GIVE_WEAPON_EVENT', 'CRITICAL',
            'Network giveWeaponEvent blocked')
    end
end)

AddEventHandler('removeWeaponEvent', function(sender, data)
    if not Config.Modules.EventAbuse then return end
    if IsPlayerAdmin and IsPlayerAdmin(sender) then return end
    -- Removing others' weapons is almost always malicious
    CancelEvent()
    bump(sender, 'rmweapon', 2, 'REMOVE_WEAPON_EVENT', 'HIGH',
        'Network removeWeaponEvent blocked')
end)

-- Particle FX spam
local ptfx = {}
AddEventHandler('ptFxEvent', function(sender, data)
    if not Config.Modules.EventAbuse then return end
    if IsPlayerAdmin and IsPlayerAdmin(sender) then return end

    local now = GetGameTimer and GetGameTimer() or (os.time() * 1000)
    ptfx[sender] = ptfx[sender] or { n = 0, t = now }
    if now - ptfx[sender].t > 3000 then
        ptfx[sender] = { n = 0, t = now }
    end
    ptfx[sender].n = ptfx[sender].n + 1

    local max = Config.EventAbuse.MaxPtFxPer3s or 25
    if ptfx[sender].n > max then
        CancelEvent()
        bump(sender, 'ptfx', 2, 'PTFX_SPAM', 'HIGH',
            ('Particle spam %s/3s'):format(ptfx[sender].n))
    end
end)

-- Projectile spam (RPG/grenade menus)
local proj = {}
AddEventHandler('startProjectileEvent', function(sender, data)
    if not Config.Modules.EventAbuse then return end
    if IsPlayerAdmin and IsPlayerAdmin(sender) then return end

    local now = os.time()
    proj[sender] = proj[sender] or { n = 0, t = now }
    if now ~= proj[sender].t then
        proj[sender] = { n = 0, t = now }
    end
    proj[sender].n = proj[sender].n + 1

    local max = Config.EventAbuse.MaxProjectilesPerSec or 6
    if proj[sender].n > max then
        CancelEvent()
        bump(sender, 'proj', 2, 'PROJECTILE_SPAM', 'CRITICAL',
            ('Projectile spam %s/s'):format(proj[sender].n))
    end
end)

-- Blacklisted vehicle / object models on create
local vehSet, objSet

local function rebuildSets()
    vehSet = {}
    for _, name in ipairs(Config.EventAbuse.BlacklistedVehicles or {}) do
        vehSet[joaat(name)] = name
    end
    objSet = {}
    for _, name in ipairs(Config.EventAbuse.BlacklistedObjects or {}) do
        objSet[joaat(name)] = name
    end
end

CreateThread(function()
    Wait(500)
    if Config.Modules.EventAbuse then
        rebuildSets()
        print('^2[LucidGuard]^7 Event abuse + entity blacklist active')
    end
end)

AddEventHandler('entityCreating', function(entity)
    if not Config.Modules.EventAbuse then return end
    if not DoesEntityExist(entity) then return end

    local model = GetEntityModel(entity)
    local owner = NetworkGetEntityOwner(entity)

    if vehSet and vehSet[model] then
        CancelEvent()
        if owner and owner > 0 and ProcessDetection then
            ProcessDetection(owner, 'BLACKLISTED_VEHICLE', 'CRITICAL',
                ('Blocked vehicle %s'):format(vehSet[model]))
        end
        return
    end

    if objSet and objSet[model] then
        CancelEvent()
        if owner and owner > 0 and ProcessDetection then
            ProcessDetection(owner, 'BLACKLISTED_OBJECT', 'HIGH',
                ('Blocked object %s'):format(objSet[model]))
        end
    end
end)
