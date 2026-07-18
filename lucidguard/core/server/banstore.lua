--[[
    LucidGuard — persistent ban store (oxmysql)
]]

BanStore = BanStore or {}

local function hasOx()
    return GetResourceState('oxmysql') == 'started'
end

function BanStore.Init()
    if not hasOx() then
        print('^3[LucidGuard]^7 BanStore: oxmysql not started — bans are memory-only')
        return
    end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS lucidguard_bans (
            id INT NOT NULL AUTO_INCREMENT,
            license VARCHAR(80) DEFAULT NULL,
            license2 VARCHAR(80) DEFAULT NULL,
            discord VARCHAR(80) DEFAULT NULL,
            steam VARCHAR(80) DEFAULT NULL,
            token VARCHAR(128) DEFAULT NULL,
            reason VARCHAR(255) NOT NULL,
            detection VARCHAR(64) DEFAULT NULL,
            banned_by VARCHAR(64) NOT NULL DEFAULT 'LucidGuard',
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            expires_at DATETIME DEFAULT NULL,
            active TINYINT NOT NULL DEFAULT 1,
            PRIMARY KEY (id),
            KEY idx_license (license),
            KEY idx_token (token),
            KEY idx_active (active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    print('^2[LucidGuard]^7 BanStore ready')
end

function BanStore.IsBanned(identifiers, tokens)
    if not hasOx() then return false, nil end

    identifiers = identifiers or {}
    tokens = tokens or {}

    local row = MySQL.single.await([[
        SELECT * FROM lucidguard_bans
        WHERE active = 1
          AND (expires_at IS NULL OR expires_at > NOW())
          AND (
                (? IS NOT NULL AND license = ?)
             OR (? IS NOT NULL AND license2 = ?)
             OR (? IS NOT NULL AND discord = ?)
             OR (? IS NOT NULL AND steam = ?)
          )
        LIMIT 1
    ]], {
        identifiers.license, identifiers.license,
        identifiers.license2, identifiers.license2,
        identifiers.discord, identifiers.discord,
        identifiers.steam, identifiers.steam
    })

    if row then return true, row end

    for _, token in ipairs(tokens) do
        local trow = MySQL.single.await([[
            SELECT * FROM lucidguard_bans
            WHERE active = 1 AND token = ?
              AND (expires_at IS NULL OR expires_at > NOW())
            LIMIT 1
        ]], { token })
        if trow then return true, trow end
    end

    return false, nil
end

function BanStore.AddBan(playerId, reason, detection)
    local identifiers = GetAllIdentifiers and GetAllIdentifiers(playerId) or {}
    local tokens = GetAllTokens and GetAllTokens(playerId) or {}
    local token = tokens[1]

    if hasOx() then
        MySQL.insert.await([[
            INSERT INTO lucidguard_bans (license, license2, discord, steam, token, reason, detection, banned_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'LucidGuard')
        ]], {
            identifiers.license, identifiers.license2, identifiers.discord, identifiers.steam,
            token, reason or 'Anticheat ban', detection or 'UNKNOWN'
        })
    end

    if BanPlayerTokens then
        BanPlayerTokens(playerId, reason or 'Anticheat ban')
    end

    Log('BAN', ('Ban stored for %s (%s): %s'):format(GetPlayerName(playerId) or '?', playerId, reason or ''))
end

CreateThread(function()
    Wait(1500)
    BanStore.Init()
end)

function BanStore.ListRecent(limit)
    limit = tonumber(limit) or 25
    if not hasOx() then return {} end
    local rows = MySQL.query.await([[
        SELECT id, license, discord, reason, detection, banned_by, created_at, active
        FROM lucidguard_bans
        ORDER BY id DESC
        LIMIT ?
    ]], { limit })
    return rows or {}
end

exports('AddBan', BanStore.AddBan)
exports('IsBanned', BanStore.IsBanned)
exports('ListBans', BanStore.ListRecent)
_G.BanStore = BanStore
