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
    if GetResourceState('oxmysql') ~= 'started' then return end

    local tableName = Config.Connection.VPNDetection.DatabaseCache.TableName or 'lucidguard_vpn_cache'
    MySQL.query.await(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            id INT AUTO_INCREMENT PRIMARY KEY,
            ip_address VARCHAR(45) UNIQUE NOT NULL,
            is_vpn TINYINT NOT NULL,
            provider VARCHAR(255),
            country VARCHAR(100),
            cached_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_ip (ip_address),
            INDEX idx_cached (cached_at)
        )
    ]]):format(tableName))
end

function GetVPNCacheFromDB(ip)
    if not Config.Connection.VPNDetection.DatabaseCache.Enabled then return nil end
    if GetResourceState('oxmysql') ~= 'started' then return nil end

    local tableName = Config.Connection.VPNDetection.DatabaseCache.TableName or 'lucidguard_vpn_cache'
    local expiry = Config.Connection.VPNDetection.DatabaseCache.CacheExpiry or 86400
    return MySQL.single.await(
        ('SELECT * FROM `%s` WHERE ip_address = ? AND UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(cached_at) < ?'):format(tableName),
        { ip, expiry }
    )
end

function CacheVPNToDB(ip, isVPN, data)
    if not Config.Connection.VPNDetection.DatabaseCache.Enabled then return end
    if GetResourceState('oxmysql') ~= 'started' then return end

    local tableName = Config.Connection.VPNDetection.DatabaseCache.TableName or 'lucidguard_vpn_cache'
    data = data or {}
    MySQL.insert.await(
        ('INSERT INTO `%s` (ip_address, is_vpn, provider, country) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE is_vpn = VALUES(is_vpn), provider = VALUES(provider), country = VALUES(country), cached_at = CURRENT_TIMESTAMP'):format(tableName),
        { ip, isVPN and 1 or 0, data.isp or 'Unknown', data.country or 'Unknown' }
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

    -- Name guard (invalid / blacklisted / spoofed names)
    if Config.Modules.NameGuard then
        local ng = Config.NameGuard or {}
        local name = playerName or ''
        local lower = string.lower(name)
        local bad, why = false, nil
        if name == '' or #name < (ng.MinLength or 2) then
            bad, why = true, 'too_short'
        elseif #name > (ng.MaxLength or 32) then
            bad, why = true, 'too_long'
        elseif name:find('[\1-\8\11\12\14-\31]') then
            bad, why = true, 'control_chars'
        else
            for _, pat in ipairs(ng.Blacklist or {}) do
                if lower:find(string.lower(pat), 1, true) then
                    bad, why = true, 'blacklisted'
                    break
                end
            end
        end
        if bad then
            deferrals.done(('LucidGuard: invalid player name (%s)'):format(why or 'rejected'))
            return
        end
    end
    
    -- Get all identifiers
    local identifiers = {}
    local numIds = GetNumPlayerIdentifiers(playerId)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(playerId, i)
        if id then
            table.insert(identifiers, id)
            
            -- Parse identifier type
            if string.find(id, 'license2:') then identifiers.license2 = id
            elseif string.find(id, 'license:') then identifiers.license = id
            elseif string.find(id, 'steam:') then identifiers.steam = id
            elseif string.find(id, 'discord:') then identifiers.discord = id
            elseif string.find(id, 'ip:') then identifiers.ip = id
            elseif string.find(id, 'fivem:') then identifiers.fivem = id
            end
        end
    end
    
    Wait(100)
    deferrals.update('LucidGuard: Verifying identifiers...')

    local tokens = {}
    local numTokens = GetNumPlayerTokens(playerId)
    for i = 0, numTokens - 1 do
        local token = GetPlayerToken(playerId, i)
        if token then tokens[#tokens + 1] = token end
    end

    -- Persistent ban store (oxmysql)
    if BanStore and BanStore.IsBanned then
        local banned, row = BanStore.IsBanned(identifiers, tokens)
        if banned then
            Log('ALERT', string.format('Persistent ban hit: %s (%s)', playerName, row and row.reason or 'n/a'))
            deferrals.done('You are banned from this server. Appeal with staff.')
            return
        end
    end
    
    -- ========================================================================
    -- CHECK 1: Hardware Token Ban Check (memory cache)
    -- ========================================================================
    
    if Config.Connection.CheckHardwareTokens then
        deferrals.update('LucidGuard: Checking hardware tokens...')
        
        for _, token in ipairs(tokens) do
            if bannedTokens[token] then
                Log('ALERT', string.format('Banned token detected: %s attempting to connect', playerName))
                SendConnectionAlert(playerId, 'Hardware ban evasion attempt')
                deferrals.done('You are banned from this server. Appeal via txAdmin.')
                return
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
