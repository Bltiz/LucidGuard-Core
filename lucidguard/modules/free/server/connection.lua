--[[
    LucidGuard Anticheat - Connection Screening
    Created by OnlyLucidVibes
    Pre-join checks: ban detection, hardware tokens, VPN flagging
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local bannedTokens = {} -- Cache of banned hardware tokens
local vpnCache = {}     -- Cache VPN check results
local connectionAttempts = {} -- Track connection spam

-- ============================================================================
-- DATABASE INITIALIZATION FOR VPN CACHE (NEW v1.4.1)
-- ============================================================================

-- Create VPN cache table if it doesn't exist
function InitializeVPNCacheTable()
    if not Config.Connection.VPNDetection.DatabaseCache.Enabled then return end
    
    MySQL.Async.execute(
        'CREATE TABLE IF NOT EXISTS `' .. Config.Connection.VPNDetection.DatabaseCache.TableName .. '` (' ..
        '`id` INT AUTO_INCREMENT PRIMARY KEY, ' ..
        '`ip_address` VARCHAR(45) UNIQUE NOT NULL, ' ..
        '`is_vpn` BOOLEAN NOT NULL, ' ..
        '`provider` VARCHAR(255), ' ..
        '`country` VARCHAR(100), ' ..
        '`cached_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ' ..
        'INDEX idx_ip (ip_address), ' ..
        'INDEX idx_cached (cached_at)' ..
        ')',
        {},
        function(rowsChanged) end
    )
end

-- Get VPN result from database cache
function GetVPNCacheFromDB(ip)
    if not Config.Connection.VPNDetection.DatabaseCache.Enabled then return nil end
    
    local result = nil
    local done = false
    
    MySQL.Async.fetchAll(
        'SELECT * FROM `' .. Config.Connection.VPNDetection.DatabaseCache.TableName .. '` WHERE ip_address = @ip AND UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(cached_at) < @expiry',
        { ['@ip'] = ip, ['@expiry'] = Config.Connection.VPNDetection.DatabaseCache.CacheExpiry },
        function(rows)
            if rows and rows[1] then
                result = rows[1]
            end
            done = true
        end
    )
    
    -- Wait for async query to complete (max 2 seconds)
    local waited = 0
    while not done and waited < 2000 do
        Wait(10)
        waited = waited + 10
    end
    
    return result
end

-- Cache VPN result to database
function CacheVPNToDB(ip, isVPN, data)
    if not Config.Connection.VPNDetection.DatabaseCache.Enabled then return end
    
    MySQL.Async.execute(
        'INSERT INTO `' .. Config.Connection.VPNDetection.DatabaseCache.TableName .. '` (ip_address, is_vpn, provider, country) ' ..
        'VALUES (@ip, @isVPN, @provider, @country) ' ..
        'ON DUPLICATE KEY UPDATE is_vpn = @isVPN, provider = @provider, country = @country, cached_at = CURRENT_TIMESTAMP',
        {
            ['@ip'] = ip,
            ['@isVPN'] = isVPN and 1 or 0,
            ['@provider'] = data.isp or 'Unknown',
            ['@country'] = data.country or 'Unknown'
        },
        function(rowsChanged) end
    )
end

-- ============================================================================
-- PLAYER CONNECTING EVENT
-- ============================================================================

AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local playerId = source
    
    -- Start deferral process
    deferrals.defer()
    Wait(0)
    
    deferrals.update('🛡️ LucidGuard: Checking your connection...')
    
    -- Get all identifiers
    local identifiers = {}
    local numIds = GetNumPlayerIdentifiers(playerId)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(playerId, i)
        if id then
            table.insert(identifiers, id)
            
            -- Parse identifier type
            if string.find(id, 'license:') then identifiers.license = id
            elseif string.find(id, 'steam:') then identifiers.steam = id
            elseif string.find(id, 'discord:') then identifiers.discord = id
            elseif string.find(id, 'ip:') then identifiers.ip = id
            elseif string.find(id, 'fivem:') then identifiers.fivem = id
            end
        end
    end
    
    Wait(100)
    deferrals.update('🛡️ LucidGuard: Verifying identifiers...')
    
    -- ========================================================================
    -- CHECK 1: Hardware Token Ban Check
    -- ========================================================================
    
    if Config.Connection.CheckHardwareTokens then
        deferrals.update('🛡️ LucidGuard: Checking hardware tokens...')
        
        local tokens = {}
        local numTokens = GetNumPlayerTokens(playerId)
        for i = 0, numTokens - 1 do
            local token = GetPlayerToken(playerId, i)
            if token then
                table.insert(tokens, token)
                
                -- Check against banned tokens
                if bannedTokens[token] then
                    Log('ALERT', string.format('Banned token detected: %s attempting to connect', playerName))
                    SendConnectionAlert(playerId, 'Hardware ban evasion attempt')
                    deferrals.done('🚫 You are banned from this server. Appeal via txAdmin.')
                    return
                end
            end
        end
    end
    
    Wait(100)
    
    -- ========================================================================
    -- CHECK 2: Connection Spam Detection
    -- ========================================================================
    
    local ip = identifiers.ip
    if ip then
        local currentTime = os.time()
        
        if not connectionAttempts[ip] then
            connectionAttempts[ip] = { count = 1, firstAttempt = currentTime }
        else
            local data = connectionAttempts[ip]
            local windowSeconds = Config.RateLimit.ConnectionSpamWindow / 1000
            
            -- Reset if window passed
            if currentTime - data.firstAttempt > windowSeconds then
                connectionAttempts[ip] = { count = 1, firstAttempt = currentTime }
            else
                data.count = data.count + 1
                
                -- Check threshold
                if data.count > Config.RateLimit.ConnectionSpamThreshold then
                    Log('ALERT', string.format('Connection spam detected from IP: %s (%d attempts)', ip, data.count))
                    SendConnectionAlert(playerId, 'Connection spam (' .. data.count .. ' attempts)')
                    deferrals.done('🚫 Too many connection attempts. Please wait and try again.')
                    return
                end
            end
        end
    end
    
    Wait(100)
    
    -- ========================================================================
    -- CHECK 3: VPN/Proxy Detection (Flag only, don't block)
    -- ========================================================================
    
    if Config.Modules.VPNDetection and Config.Connection.VPNDetection.Enabled and ip then
        deferrals.update('🛡️ LucidGuard: Checking connection type...')
        
        -- Extract IP address from identifier
        local cleanIP = string.gsub(ip, 'ip:', '')
        
        -- Check in-memory cache first
        if vpnCache[cleanIP] and (os.time() - vpnCache[cleanIP].timestamp < Config.Connection.VPNDetection.CacheDuration) then
            local cached = vpnCache[cleanIP]
            if cached.isVPN then
                Log('WARN', string.format('VPN/Proxy detected (memory cache): %s (%s)', playerName, cleanIP))
                SendVPNAlert(playerId, cached.data)
            end
        else
            -- Check database cache (NEW v1.4.1)
            local dbCached = GetVPNCacheFromDB(cleanIP)
            if dbCached then
                if dbCached.is_vpn then
                    Log('WARN', string.format('VPN/Proxy detected (database cache): %s (%s) [%s]', playerName, cleanIP, dbCached.provider))
                    SendVPNAlert(playerId, { status = 'success', proxy = true, hosting = false, isp = dbCached.provider, country = dbCached.country })
                end
                -- Update memory cache from DB
                vpnCache[cleanIP] = {
                    isVPN = dbCached.is_vpn,
                    data = { isp = dbCached.provider, country = dbCached.country },
                    timestamp = os.time()
                }
            else
                -- Perform API check (not in any cache)
                local apiURL = string.gsub(Config.Connection.VPNDetection.APIURL, '{ip}', cleanIP)
                
                local vpnCheckComplete = false
                local isVPN = false
                local vpnData = {}
                
                PerformHttpRequest(apiURL, function(errorCode, resultData, resultHeaders)
                    if errorCode == 200 and resultData then
                        local data = json.decode(resultData)
                        if data and data.status == 'success' then
                            isVPN = data.proxy or data.hosting
                            vpnData = data
                            
                            -- Cache to database (NEW v1.4.1)
                            if Config.Connection.VPNDetection.DatabaseCache.Enabled then
                                CacheVPNToDB(cleanIP, isVPN, data)
                            end
                            
                            -- Cache to memory
                            if Config.Connection.VPNDetection.CacheResults then
                                vpnCache[cleanIP] = {
                                    isVPN = isVPN,
                                    data = data,
                                    timestamp = os.time()
                                }
                            end
                            
                            if isVPN then
                                Log('WARN', string.format('VPN/Proxy detected (API): %s (%s) [%s]', playerName, cleanIP, data.isp))
                                SendVPNAlert(playerId, data)
                            end
                        end
                    end
                    vpnCheckComplete = true
                end, 'GET')
                
                -- Wait for VPN check (max 5 seconds)
                local waitTime = 0
                while not vpnCheckComplete and waitTime < 5000 do
                    Wait(100)
                    waitTime = waitTime + 100
                end
            end
        end
    end
    
    Wait(100)
    deferrals.update('🛡️ LucidGuard: Finalizing...')
    Wait(500)
    
    -- ========================================================================
    -- ALL CHECKS PASSED
    -- ========================================================================
    
    Log('INFO', string.format('Connection approved: %s', playerName))
    deferrals.done()
end)

-- ============================================================================
-- ADD BANNED TOKEN
-- ============================================================================

function AddBannedToken(token, reason)
    bannedTokens[token] = {
        reason = reason,
        bannedAt = os.time()
    }
    Log('BAN', string.format('Token banned: %s (Reason: %s)', string.sub(token, 1, 20) .. '...', reason))
end

-- ============================================================================
-- REMOVE BANNED TOKEN
-- ============================================================================

function RemoveBannedToken(token)
    if bannedTokens[token] then
        bannedTokens[token] = nil
        Log('INFO', string.format('Token unbanned: %s', string.sub(token, 1, 20) .. '...'))
        return true
    end
    return false
end

-- ============================================================================
-- BAN PLAYER TOKENS (ban all tokens of a player)
-- ============================================================================

function BanPlayerTokens(playerId, reason)
    local tokens = {}
    local numTokens = GetNumPlayerTokens(playerId)
    
    for i = 0, numTokens - 1 do
        local token = GetPlayerToken(playerId, i)
        if token then
            AddBannedToken(token, reason)
            table.insert(tokens, token)
        end
    end
    
    return tokens
end

-- ============================================================================
-- CLEANUP OLD CONNECTION ATTEMPTS
-- ============================================================================

CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        
        local currentTime = os.time()
        local windowSeconds = Config.RateLimit.ConnectionSpamWindow / 1000
        
        for ip, data in pairs(connectionAttempts) do
            if currentTime - data.firstAttempt > windowSeconds then
                connectionAttempts[ip] = nil
            end
        end
    end
end)

-- ============================================================================
-- CLEANUP OLD VPN CACHE
-- ============================================================================

CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes
        
        local currentTime = os.time()
        local cacheDuration = Config.Connection.VPNDetection.CacheDuration
        
        for ip, data in pairs(vpnCache) do
            if currentTime - data.timestamp > cacheDuration then
                vpnCache[ip] = nil
            end
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('AddBannedToken', AddBannedToken)
exports('RemoveBannedToken', RemoveBannedToken)
exports('BanPlayerTokens', BanPlayerTokens)
