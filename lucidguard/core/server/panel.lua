--[[
    LucidGuard Admin Panel — server API + live feed
]]

local feed = {} -- ring buffer
local MAX_FEED = 200
local riskScores = {} -- playerId -> score

function LucidGuardGetFeed()
    return feed
end

function LucidGuardGetRiskScores()
    return riskScores
end

_G.LucidGuardGetFeed = LucidGuardGetFeed
_G.LucidGuardGetRiskScores = LucidGuardGetRiskScores

local function pushFeed(entry)
    entry.ts = entry.ts or os.time()
    feed[#feed + 1] = entry
    while #feed > MAX_FEED do
        table.remove(feed, 1)
    end
    TriggerClientEvent('lg_ac:panel:feed', -1, entry)
end

function PanelPush(entry)
    pushFeed(entry)
end

exports('PanelPush', PanelPush)
_G.PanelPush = PanelPush

-- Called from ProcessDetection
function PanelOnDetection(playerId, detectionType, severity, details)
    riskScores[playerId] = (riskScores[playerId] or 0) + ({
        LOW = 1, MEDIUM = 3, HIGH = 6, CRITICAL = 12
    })[severity] or 2

    pushFeed({
        type = 'detection',
        player = GetPlayerName(playerId) or 'unknown',
        id = playerId,
        detection = detectionType,
        severity = severity,
        details = type(details) == 'table' and json.encode(details) or tostring(details or ''),
        risk = riskScores[playerId]
    })
end

exports('PanelOnDetection', PanelOnDetection)

local function assertAdmin(src)
    if not src or src <= 0 then return false end
    if IsPlayerAdmin and IsPlayerAdmin(src) then
        -- Advanced HWID gate if present
        if GetResourceState('lucidguard-advanced') == 'started' then
            local ok, auth = pcall(function()
                return exports['lucidguard-advanced']:AdminAuthorized(src)
            end)
            if ok and auth == false then return false end
        end
        return true
    end
    return false
end

local function buildPlayers()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local data = GetPlayerData and GetPlayerData(src) or {}
        local vcount = 0
        if data.violations then
            for _, v in pairs(data.violations) do
                vcount = vcount + (v.count or 0)
            end
        end
        local trust = nil
        local watched = false
        if GetResourceState('lucidguard-advanced') == 'started' then
            pcall(function()
                trust = exports['lucidguard-advanced']:TrustGet(src)
                watched = exports['lucidguard-advanced']:TrustIsWatched(src)
            end)
        end
        list[#list + 1] = {
            id = src,
            name = GetPlayerName(src),
            ping = GetPlayerPing(src),
            admin = IsPlayerAdmin and IsPlayerAdmin(src) or false,
            risk = riskScores[src] or 0,
            trust = trust,
            watched = watched,
            violations = vcount,
            joinTime = data.joinTime
        }
    end
    table.sort(list, function(a, b) return (a.risk or 0) > (b.risk or 0) end)
    return list
end

local function safeModeState()
    return Config.PlayerSafety
        and Config.PlayerSafety.SafeMode
        and Config.PlayerSafety.SafeMode.Enabled == true
end

exports('IsSafeMode', safeModeState)

local function buildPayload()
    local shadow = {}
    if GetResourceState('lucidguard-advanced') == 'started' then
        pcall(function()
            shadow = exports['lucidguard-advanced']:GetShadowbanQueue() or {}
        end)
    end
    local bans = {}
    if BanStore and BanStore.ListRecent then
        bans = BanStore.ListRecent(20) or {}
    end
    local caseList = {}
    if Evidence and Evidence.List then
        caseList = Evidence.List(30) or {}
    end
    local watchlist = {}
    if GetResourceState('lucidguard-advanced') == 'started' then
        pcall(function()
            watchlist = exports['lucidguard-advanced']:GetWatchlist() or {}
        end)
    end
    local players = buildPlayers()
    local watchedOnline = 0
    for _, p in ipairs(players) do
        if p.watched then watchedOnline = watchedOnline + 1 end
    end
    return {
        feed = feed,
        players = players,
        safeMode = safeModeState(),
        tier = Config.Tier or 'FREE',
        version = GetVersion and GetVersion() or '2.0.1',
        modules = Config.Modules,
        shadowban = shadow,
        bans = bans,
        cases = caseList,
        watchlist = watchlist,
        stats = {
            online = #GetPlayers(),
            feedSize = #feed,
            shadowban = #shadow,
            cases = #caseList,
            watched = math.max(watchedOnline, #watchlist)
        }
    }
end

RegisterNetEvent('lg_ac:panel:requestOpen', function()
    local src = source
    if Config.Panel and Config.Panel.Enabled == false then
        TriggerClientEvent('lg_ac:panel:denied', src)
        return
    end
    if not assertAdmin(src) then
        TriggerClientEvent('lg_ac:panel:denied', src)
        return
    end

    TriggerClientEvent('lg_ac:panel:open', src, buildPayload())
end)

RegisterNetEvent('lg_ac:panel:refresh', function()
    local src = source
    if not assertAdmin(src) then return end
    TriggerClientEvent('lg_ac:panel:data', src, buildPayload())
end)

RegisterNetEvent('lg_ac:panel:setSafeMode', function(enabled)
    local src = source
    if not assertAdmin(src) then return end
    Config.PlayerSafety = Config.PlayerSafety or {}
    Config.PlayerSafety.SafeMode = Config.PlayerSafety.SafeMode or {}
    Config.PlayerSafety.SafeMode.Enabled = enabled and true or false
    Config.PlayerSafety.SafeMode.LogOnly = true
    pushFeed({
        type = 'system',
        message = ('Safe Mode %s by %s'):format(enabled and 'ENABLED' or 'DISABLED', GetPlayerName(src))
    })
    TriggerClientEvent('lg_ac:panel:data', src, buildPayload())
end)

RegisterNetEvent('lg_ac:panel:kick', function(targetId, reason)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    reason = tostring(reason or 'Kicked by LucidGuard panel')
    DropPlayer(targetId, reason)
    pushFeed({ type = 'system', message = ('%s kicked %s: %s'):format(GetPlayerName(src), targetId, reason) })
end)

RegisterNetEvent('lg_ac:panel:ban', function(targetId, reason)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    reason = tostring(reason or 'Banned by LucidGuard panel')
    if BanStore and BanStore.AddBan then
        BanStore.AddBan(targetId, reason, 'PANEL_BAN')
    end
    DropPlayer(targetId, reason)
    pushFeed({ type = 'system', message = ('%s banned %s: %s'):format(GetPlayerName(src), targetId, reason) })
end)

RegisterNetEvent('lg_ac:panel:clearRisk', function(targetId)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if targetId then riskScores[targetId] = 0 end
end)

RegisterNetEvent('lg_ac:panel:clearFeed', function()
    local src = source
    if not assertAdmin(src) then return end
    feed = {}
    TriggerClientEvent('lg_ac:panel:data', src, buildPayload())
end)

RegisterNetEvent('lg_ac:panel:screenshot', function(targetId)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId then return end

    if GetResourceState('screenshot-basic') ~= 'started' then
        TriggerClientEvent('lg_ac:panel:toast', src, 'Install screenshot-basic for screenshots')
        return
    end

    local webhook = Config.Panel and Config.Panel.ScreenshotWebhook or ''
    if webhook == '' then
        TriggerClientEvent('lg_ac:panel:toast', src, 'Set lucidguard_screenshot_webhook convar first')
        return
    end

    TriggerClientEvent('lg_ac:panel:takeScreenshot', targetId, src, webhook)
    pushFeed({ type = 'system', message = ('Screenshot requested on %s by %s'):format(targetId, GetPlayerName(src)) })
end)

RegisterNetEvent('lg_ac:panel:screenshotDone', function(requestor, ok)
    local src = source
    requestor = tonumber(requestor)
    if not requestor then return end
    TriggerClientEvent('lg_ac:panel:toast', requestor,
        ok and ('Screenshot uploaded from #%s'):format(src) or ('Screenshot failed from #%s'):format(src))
end)

RegisterNetEvent('lg_ac:panel:announce', function(message)
    local src = source
    if not assertAdmin(src) then return end
    message = tostring(message or '')
    if message == '' then return end
    TriggerClientEvent('chat:addMessage', -1, {
        color = { 249, 115, 22 },
        args = { 'STAFF', message }
    })
    pushFeed({ type = 'system', message = ('Announce by %s: %s'):format(GetPlayerName(src), message) })
    TriggerClientEvent('lg_ac:panel:toast', src, 'Announce sent')
end)

RegisterNetEvent('lg_ac:panel:warn', function(targetId, reason)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('lg_ac:panel:toast', src, 'Player not found')
        return
    end
    reason = tostring(reason or 'Warned by staff')
    TriggerClientEvent('chat:addMessage', targetId, {
        color = { 249, 115, 22 },
        args = { 'LucidGuard', reason }
    })
    pushFeed({ type = 'system', message = ('%s warned #%s: %s'):format(GetPlayerName(src), targetId, reason) })
    TriggerClientEvent('lg_ac:panel:toast', src, ('Warned #%s'):format(targetId))
end)

RegisterNetEvent('lg_ac:panel:shadowban', function(targetId)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('lg_ac:panel:toast', src, 'Player not found')
        return
    end
    local queued = false
    if GetResourceState('lucidguard-advanced') == 'started' then
        pcall(function()
            queued = exports['lucidguard-advanced']:QueueShadowban(targetId, 'F7_PANEL')
        end)
    end
    TriggerClientEvent('lg_ac:panel:toast', src, queued and ('Shadowban queued #%s'):format(targetId) or 'Shadowban unavailable')
    if queued then
        TriggerClientEvent('lg_ac:panel:data', src, buildPayload())
    end
end)

RegisterNetEvent('lg_ac:panel:watch', function(targetId, reason)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('lg_ac:panel:toast', src, 'Player not found')
        return
    end
    local watched = false
    if GetResourceState('lucidguard-advanced') == 'started' then
        pcall(function()
            watched = exports['lucidguard-advanced']:TrustWatch(targetId, reason or 'F7 panel')
        end)
    end
    pushFeed({ type = 'system', message = ('%s watchlisted #%s'):format(GetPlayerName(src), targetId) })
    TriggerClientEvent('lg_ac:panel:toast', src, watched and ('Watching #%s'):format(targetId) or 'Watchlist unavailable')
    TriggerClientEvent('lg_ac:panel:data', src, buildPayload())
end)

RegisterNetEvent('lg_ac:panel:lookupIds', function(targetId)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('lg_ac:panel:toast', src, 'Player not found')
        return
    end
    local ids = {}
    if GetAllIdentifiers then
        pcall(function() ids = GetAllIdentifiers(targetId) or {} end)
    else
        for _, ident in ipairs(GetPlayerIdentifiers(targetId) or {}) do
            local k, v = ident:match('([^:]+):(.+)')
            if k then ids[k] = v end
        end
    end
    TriggerClientEvent('lg_ac:panel:identifiers', src, {
        id = targetId,
        name = GetPlayerName(targetId),
        identifiers = ids
    })
end)

RegisterNetEvent('lg_ac:panel:forceRecheck', function(targetId)
    local src = source
    if not assertAdmin(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('lg_ac:panel:toast', src, 'Player not found')
        return
    end
    TriggerClientEvent('lg_ac:adv:forceRecheck', targetId)
    TriggerClientEvent('lg_ac:panel:toast', src, ('Force recheck #%s'):format(targetId))
end)

RegisterNetEvent('lg_ac:panel:testCaseWebhook', function()
    local src = source
    if not assertAdmin(src) then return end
    if SendCaseToDiscord then
        SendCaseToDiscord({
            id = 0,
            playerId = src,
            player = GetPlayerName(src),
            detection = 'TEST_CASE',
            severity = 'HIGH',
            details = 'Manual F7 panel webhook test',
            status = 'open',
            screenshots = 0
        })
        TriggerClientEvent('lg_ac:panel:toast', src, 'Test case sent (check Discord)')
    else
        TriggerClientEvent('lg_ac:panel:toast', src, 'Case Discord helper missing — set lucidguard_case_webhook')
    end
end)

AddEventHandler('playerDropped', function()
    riskScores[source] = nil
end)

print('^2[LucidGuard]^7 Admin panel API loaded')
