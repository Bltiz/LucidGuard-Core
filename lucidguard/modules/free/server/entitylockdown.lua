--[[
    LucidGuard Anticheat - Entity Lockdown
    Created by OnlyLucidVibes
    Server-side entity spawn protection, explosion monitoring, and nuke detection
    
    CRITICAL: Set routing bucket to STRICT mode to prevent client-side spawning!
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local playerEntityCounts = {}  -- Track entities spawned per player
local playerExplosionCounts = {} -- Track explosions per player

-- ============================================================================
-- ROUTING BUCKET LOCKDOWN (OneSync Required)
-- Set to 'strict' to block ALL client-side entity spawning
-- All entities must be spawned via CreateVehicleServerSetter or server scripts
-- ============================================================================

CreateThread(function()
    Wait(1000) -- Wait for server to initialize
    
    if not Config.Modules.EntityLockdown then return end
    
    local lockdownMode = Config.EntityLockdown.RoutingBucketMode or 'relaxed'
    
    -- Set routing bucket entity lockdown mode for default bucket (0)
    -- 'strict' = No client-side entity creation allowed
    -- 'relaxed' = Client-side entity creation allowed (default)
    SetRoutingBucketEntityLockdownMode(0, lockdownMode)
    
    Log('INFO', string.format('Entity Lockdown: Routing bucket 0 set to "%s" mode', lockdownMode))
    
    -- Apply to additional buckets if configured
    if Config.EntityLockdown.AdditionalBuckets then
        for _, bucketId in ipairs(Config.EntityLockdown.AdditionalBuckets) do
            SetRoutingBucketEntityLockdownMode(bucketId, lockdownMode)
            Log('INFO', string.format('Entity Lockdown: Routing bucket %d set to "%s" mode', bucketId, lockdownMode))
        end
    end
end)

-- ============================================================================
-- INITIALIZE PLAYER TRACKING
-- ============================================================================

local function InitPlayerEntityTracking(playerId)
    playerEntityCounts[playerId] = {
        second = { count = 0, timestamp = os.time() },
        minute = { count = 0, timestamp = os.time() }
    }
    playerExplosionCounts[playerId] = {
        count = 0,
        timestamp = os.time()
    }
end

AddEventHandler('playerJoining', function()
    local playerId = source
    InitPlayerEntityTracking(playerId)
end)

AddEventHandler('playerDropped', function()
    local playerId = source
    playerEntityCounts[playerId] = nil
    playerExplosionCounts[playerId] = nil
end)

-- ============================================================================
-- ENTITY CREATING EVENT - Main Protection
-- ============================================================================

if Config.Modules.EntityLockdown then
    AddEventHandler('entityCreating', function(entity)
        local entityType = GetEntityType(entity)
        local entityModel = GetEntityModel(entity)
        local entityOwner = NetworkGetEntityOwner(entity)
        
        if not entityOwner or entityOwner <= 0 then return end
        
        -- Admin immunity
        if IsPlayerAdmin(entityOwner) then return end
        
        -- Initialize tracking if needed
        if not playerEntityCounts[entityOwner] then
            InitPlayerEntityTracking(entityOwner)
        end
        
        local tracking = playerEntityCounts[entityOwner]
        local currentTime = os.time()
        
        -- ====================================================================
        -- CHECK 1: Blacklisted Models
        -- ====================================================================
        
        if Config.EntityLockdown.BlacklistedModels[entityModel] then
            CancelEvent()
            Log('ALERT', string.format('Blocked blacklisted entity from %s: Model %s',
                GetPlayerName(entityOwner), entityModel))
            ProcessDetection(entityOwner, 'BLACKLISTED_ENTITY', 'HIGH',
                string.format('Attempted to spawn blacklisted model: %s', entityModel))
            return
        end
        
        -- ====================================================================
        -- CHECK 2: Per-Second Rate (Nuke Detection)
        -- ====================================================================
        
        if Config.EntityLockdown.NukeProtection.Enabled then
            -- Reset counter if second has passed
            if currentTime - tracking.second.timestamp >= 1 then
                tracking.second = { count = 1, timestamp = currentTime }
            else
                tracking.second.count = tracking.second.count + 1
            end
            
            -- Check for nuke
            if tracking.second.count > Config.EntityLockdown.NukeProtection.MaxEntitiesPerSecond then
                CancelEvent()
                
                local details = string.format('NUKE DETECTED: %d entities in 1 second',
                    tracking.second.count)
                Log('ALERT', string.format('NUKE ATTEMPT by %s: %s',
                    GetPlayerName(entityOwner), details))
                
                ProcessDetection(entityOwner, 'ENTITY_NUKE', 'CRITICAL', details)
                
                -- Reset to prevent spam
                tracking.second = { count = 0, timestamp = currentTime }
                return
            end
        end
        
        -- ====================================================================
        -- CHECK 3: Per-Minute Rate
        -- ====================================================================
        
        if Config.EntityLockdown.NukeProtection.Enabled then
            -- Reset counter if minute has passed
            if currentTime - tracking.minute.timestamp >= 60 then
                tracking.minute = { count = 1, timestamp = currentTime }
            else
                tracking.minute.count = tracking.minute.count + 1
            end
            
            -- Check for excessive spawning
            if tracking.minute.count > Config.EntityLockdown.NukeProtection.MaxEntitiesPerMinute then
                CancelEvent()
                
                local details = string.format('Excessive entity spawning: %d entities in 1 minute',
                    tracking.minute.count)
                Log('ALERT', string.format('Entity spam by %s: %s',
                    GetPlayerName(entityOwner), details))
                
                ProcessDetection(entityOwner, 'ENTITY_SPAM', 'HIGH', details)
                return
            end
        end
        
        -- ====================================================================
        -- CHECK 4: Job-Based Spawning Permissions
        -- ====================================================================
        
        local ESX = GetESX()
        if ESX then
            local xPlayer = ESX.GetPlayerFromId(entityOwner)
            if xPlayer then
                local job = xPlayer.getJob().name
                local allowedTypes = Config.EntityLockdown.AllowedSpawners[job]
                
                -- If player's job has restrictions, check entity type
                if allowedTypes then
                    local entityCategory = GetEntityCategory(entityType)
                    local isAllowed = false
                    
                    for _, allowed in ipairs(allowedTypes) do
                        if allowed == entityCategory then
                            isAllowed = true
                            break
                        end
                    end
                    
                    if not isAllowed and entityCategory ~= 'other' then
                        -- Log but don't always block - could be legitimate resource
                        if Config.Debug then
                            Log('DEBUG', string.format('Unusual spawn by %s (%s job): %s entity',
                                GetPlayerName(entityOwner), job, entityCategory))
                        end
                    end
                end
            end
        end
        
        -- ====================================================================
        -- CHECK 5: Verify Spawning Resource
        -- ====================================================================
        
        local invokingResource = GetInvokingResource()
        if invokingResource then
            -- Check if resource is whitelisted
            local isWhitelisted = false
            for _, pattern in ipairs(Config.EntityLockdown.WhitelistedResources) do
                if string.find(invokingResource, pattern) then
                    isWhitelisted = true
                    break
                end
            end
            
            if not isWhitelisted and Config.Debug then
                Log('DEBUG', string.format('Entity spawned by non-whitelisted resource: %s (player: %s)',
                    invokingResource, GetPlayerName(entityOwner)))
            end
        end
    end)
end

-- ============================================================================
-- EXPLOSION EVENT MONITORING
-- ============================================================================

if Config.Modules.ExplosionMonitoring then
    AddEventHandler('explosionEvent', function(sender, ev)
        if not sender or sender <= 0 then return end
        
        -- Admin immunity
        if IsPlayerAdmin(sender) then return end
        
        local explosionType = ev.explosionType
        local damageScale = ev.damageScale or 1.0
        local position = vector3(ev.posX, ev.posY, ev.posZ)
        local playerName = GetPlayerName(sender)
        
        -- Initialize tracking
        if not playerExplosionCounts[sender] then
            playerExplosionCounts[sender] = { count = 0, timestamp = os.time() }
        end
        
        local tracking = playerExplosionCounts[sender]
        local currentTime = os.time()
        
        -- Reset counter every minute
        if currentTime - tracking.timestamp >= 60 then
            tracking.count = 1
            tracking.timestamp = currentTime
        else
            tracking.count = tracking.count + 1
        end
        
        -- ====================================================================
        -- CHECK 0: Damage Scale Exploit (Added from user's recommendation)
        -- ====================================================================
        
        if damageScale > 1.0 then
            CancelEvent()
            
            local details = string.format('Modified explosion damage scale: %.2f (type: %d)',
                damageScale, explosionType)
            Log('ALERT', string.format('DAMAGE SCALE EXPLOIT by %s: %s', playerName, details))
            
            ProcessDetection(sender, 'EXPLOSION_DAMAGE_HACK', 'CRITICAL', details)
            return
        end
        
        -- ====================================================================
        -- CHECK 1: Script-Heavy Explosions (Type 9, etc.)
        -- These are commonly used by mod menus
        -- ====================================================================
        
        local scriptHeavyTypes = {9, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50}
        for _, badType in ipairs(scriptHeavyTypes) do
            if explosionType == badType then
                CancelEvent()
                
                local details = string.format('Script-heavy explosion type %d at %.2f, %.2f, %.2f',
                    explosionType, position.x, position.y, position.z)
                Log('ALERT', string.format('SCRIPT EXPLOSION by %s: %s', playerName, details))
                
                ProcessDetection(sender, 'SCRIPT_EXPLOSION', 'CRITICAL', details)
                return
            end
        end
        
        -- ====================================================================
        -- CHECK 1B: Instant Ban Explosions (from config)
        -- ====================================================================
        
        for _, bannedType in ipairs(Config.ExplosionMonitoring.InstantBanExplosions) do
            if explosionType == bannedType then
                CancelEvent()
                
                local details = string.format('Instant-ban explosion type: %d at %.2f, %.2f, %.2f',
                    explosionType, position.x, position.y, position.z)
                Log('ALERT', string.format('BANNED EXPLOSION by %s: %s', playerName, details))
                
                ProcessDetection(sender, 'BANNED_EXPLOSION', 'CRITICAL', details)
                return
            end
        end
        
        -- ====================================================================
        -- CHECK 2: Restricted Explosions
        -- ====================================================================
        
        local restriction = Config.ExplosionMonitoring.RestrictedExplosions[explosionType]
        if restriction then
            local ped = GetPlayerPed(sender)
            local isValid = true
            local reason = nil
            
            -- Check vehicle requirement
            if restriction.requireVehicle then
                local vehicle = GetVehiclePedIsIn(ped, false)
                if not vehicle or vehicle == 0 then
                    isValid = false
                    reason = string.format('%s explosion without being in vehicle', restriction.name)
                end
            end
            
            -- Check weapon requirement
            if restriction.requireWeapon and isValid then
                -- Player should have a weapon that causes this explosion
                -- This is a simplified check - could be expanded
                local currentWeapon = GetSelectedPedWeapon(ped)
                if currentWeapon == `WEAPON_UNARMED` then
                    isValid = false
                    reason = string.format('%s explosion without weapon', restriction.name)
                end
            end
            
            if not isValid then
                CancelEvent()
                
                local details = reason or string.format('Suspicious %s explosion', restriction.name)
                Log('ALERT', string.format('Blocked explosion from %s: %s', playerName, details))
                
                ProcessDetection(sender, 'SUSPICIOUS_EXPLOSION', restriction.severity, details)
                return
            end
        end
        
        -- ====================================================================
        -- CHECK 3: Explosion Rate Limit
        -- ====================================================================
        
        if tracking.count > Config.ExplosionMonitoring.MaxExplosionsPerMinute then
            CancelEvent()
            
            local details = string.format('Explosion spam: %d explosions in 1 minute',
                tracking.count)
            Log('ALERT', string.format('Explosion spam by %s: %s', playerName, details))
            
            ProcessDetection(sender, 'EXPLOSION_SPAM', 'HIGH', details)
            return
        end
        
        -- Log explosion for debugging
        if Config.Debug then
            Log('DEBUG', string.format('Explosion by %s: Type %d at %.2f, %.2f, %.2f',
                playerName, explosionType, position.x, position.y, position.z))
        end
    end)
end

-- ============================================================================
-- HELPER: Get Entity Category
-- ============================================================================

function GetEntityCategory(entityType)
    if entityType == 1 then return 'peds'
    elseif entityType == 2 then return 'vehicles'
    elseif entityType == 3 then return 'objects'
    else return 'other'
    end
end

-- ============================================================================
-- WEAPON DAMAGE EVENT (Additional Protection)
-- ============================================================================

AddEventHandler('weaponDamageEvent', function(sender, ev)
    if not sender or sender <= 0 then return end
    
    -- Admin immunity
    if IsPlayerAdmin(sender) then return end
    
    local damageType = ev.damageType
    local weaponType = ev.weaponType
    local damage = ev.weaponDamage
    
    -- Check for impossible damage values
    if damage > 500 then
        CancelEvent()
        
        local details = string.format('Impossible damage: %d with weapon %s',
            damage, weaponType)
        Log('ALERT', string.format('Damage hack by %s: %s', GetPlayerName(sender), details))
        
        ProcessDetection(sender, 'DAMAGE_HACK', 'CRITICAL', details)
        return
    end
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

CreateThread(function()
    while true do
        Wait(60000) -- Cleanup every minute
        
        local currentTime = os.time()
        
        -- Clean up disconnected players
        for playerId, _ in pairs(playerEntityCounts) do
            if not GetPlayerName(playerId) then
                playerEntityCounts[playerId] = nil
            end
        end
        
        for playerId, _ in pairs(playerExplosionCounts) do
            if not GetPlayerName(playerId) then
                playerExplosionCounts[playerId] = nil
            end
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetPlayerEntityCount', function(playerId)
    return playerEntityCounts[playerId]
end)

exports('GetPlayerExplosionCount', function(playerId)
    return playerExplosionCounts[playerId]
end)
