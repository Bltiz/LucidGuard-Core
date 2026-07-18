--[[
    LucidGuard browser admin panel
    URL: http://<server-ip>:<port>/lucidguard/
]]

local function webEnabled()
    return Config.WebPanel and Config.WebPanel.Enabled ~= false
end

local function password()
    local fromConvar = GetConvar('lucidguard_web_password', '')
    if fromConvar ~= '' then return fromConvar end
    return (Config.WebPanel and Config.WebPanel.Password) or 'changeme'
end

local function authorized(req)
    local expected = password()
    local header = req.headers['X-LG-Token'] or req.headers['x-lg-token']
    if header and header == expected then return true end
    local auth = req.headers['Authorization'] or req.headers['authorization']
    if auth and auth == ('Bearer ' .. expected) then return true end
    return false
end

local function send(res, code, body, contentType)
    res.writeHead(code, {
        ['Content-Type'] = contentType or 'application/json; charset=utf-8',
        ['Access-Control-Allow-Origin'] = '*',
        ['Access-Control-Allow-Headers'] = 'Content-Type, X-LG-Token, Authorization',
        ['Cache-Control'] = 'no-store'
    })
    res.send(body or '')
end

local function sendJson(res, code, tbl)
    send(res, code, json.encode(tbl), 'application/json; charset=utf-8')
end

local MIME = {
    html = 'text/html; charset=utf-8',
    css = 'text/css; charset=utf-8',
    js = 'application/javascript; charset=utf-8',
    json = 'application/json; charset=utf-8',
    png = 'image/png',
    svg = 'image/svg+xml'
}

local function readWebFile(rel)
    local path = ('web/%s'):format(rel)
    local raw = LoadResourceFile(GetCurrentResourceName(), path)
    return raw
end

local function buildState()
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
    local cases = {}
    if Evidence and Evidence.List then
        cases = Evidence.List(30) or {}
    end

    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local data = GetPlayerData and GetPlayerData(src) or {}
        local vcount = 0
        if data.violations then
            for _, v in pairs(data.violations) do
                vcount = vcount + (v.count or 0)
            end
        end
        local trust, watched = nil, false
        if GetResourceState('lucidguard-advanced') == 'started' then
            pcall(function()
                trust = exports['lucidguard-advanced']:TrustGet(src)
                watched = exports['lucidguard-advanced']:TrustIsWatched(src)
            end)
        end
        players[#players + 1] = {
            id = src,
            name = GetPlayerName(src),
            ping = GetPlayerPing(src),
            admin = IsPlayerAdmin and IsPlayerAdmin(src) or false,
            risk = 0,
            trust = trust,
            watched = watched,
            violations = vcount
        }
    end

    local risks = {}
    if type(LucidGuardGetRiskScores) == 'function' then
        risks = LucidGuardGetRiskScores() or {}
    end
    for _, p in ipairs(players) do
        p.risk = risks[p.id] or 0
    end
    table.sort(players, function(a, b) return (a.risk or 0) > (b.risk or 0) end)

    local feedCopy = {}
    if type(LucidGuardGetFeed) == 'function' then
        feedCopy = LucidGuardGetFeed() or {}
    end

    local safe = Config.PlayerSafety and Config.PlayerSafety.SafeMode and Config.PlayerSafety.SafeMode.Enabled == true

    local watchlist = {}
    if GetResourceState('lucidguard-advanced') == 'started' then
        pcall(function()
            watchlist = exports['lucidguard-advanced']:GetWatchlist() or {}
        end)
    end
    local watchedOnline = 0
    for _, p in ipairs(players) do
        if p.watched then watchedOnline = watchedOnline + 1 end
    end

    local theme = (Config.WebPanel and Config.WebPanel.Theme) or { Snow = 'orange', Accent = '#f97316' }

    return {
        tier = Config.Tier or 'FREE',
        version = GetVersion and GetVersion() or '2.0.1',
        safeMode = safe,
        players = players,
        feed = feedCopy,
        shadowban = shadow,
        bans = bans,
        cases = cases,
        watchlist = watchlist,
        theme = { snow = theme.Snow or 'orange', accent = theme.Accent or '#f97316' },
        stats = {
            online = #GetPlayers(),
            feedSize = #feedCopy,
            cases = #cases,
            shadowban = #shadow,
            watched = math.max(watchedOnline, #watchlist)
        }
    }
end

SetHttpHandler(function(req, res)
    if not webEnabled() then
        send(res, 503, 'Web panel disabled')
        return
    end

    if req.method == 'OPTIONS' then
        send(res, 204, '')
        return
    end

    local path = req.path or '/'
    -- FiveM may pass path with or without leading resource segment (case varies on some clients)
    path = path:gsub('^/[Ll][Uu][Cc][Ii][Dd][Gg][Uu][Aa][Rr][Dd]', '')
    if path == '' or path == '/' then path = '/index.html' end

    -- API
    if path == '/api/login' and req.method == 'POST' then
        req.setDataHandler(function(body)
            local ok, data = pcall(json.decode, body or '{}')
            data = ok and data or {}
            if tostring(data.password or '') == password() then
                sendJson(res, 200, { ok = true, token = password(), tier = Config.Tier or 'FREE' })
            else
                sendJson(res, 401, { error = 'Invalid password' })
            end
        end)
        return
    end

    if path:sub(1, 5) == '/api/' then
        if not authorized(req) and path ~= '/api/login' then
            sendJson(res, 401, { error = 'Unauthorized' })
            return
        end

        if path == '/api/state' then
            sendJson(res, 200, buildState())
            return
        end

        if path == '/api/safemode' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                Config.PlayerSafety = Config.PlayerSafety or {}
                Config.PlayerSafety.SafeMode = Config.PlayerSafety.SafeMode or {}
                Config.PlayerSafety.SafeMode.Enabled = data.enabled and true or false
                if PanelPush then
                    PanelPush({ type = 'system', message = ('Safe Mode %s via web panel'):format(data.enabled and 'ENABLED' or 'DISABLED') })
                end
                sendJson(res, 200, { ok = true, safeMode = Config.PlayerSafety.SafeMode.Enabled })
            end)
            return
        end

        if (path == '/api/kick' or path == '/api/ban') and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                local reason = tostring(data.reason or 'LucidGuard web panel')
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                if path == '/api/ban' and BanStore and BanStore.AddBan then
                    BanStore.AddBan(target, reason, 'WEB_BAN')
                end
                DropPlayer(target, reason)
                if PanelPush then
                    PanelPush({ type = 'system', message = ('Web panel %s #%s: %s'):format(path == '/api/ban' and 'banned' or 'kicked', target, reason) })
                end
                sendJson(res, 200, { ok = true })
            end)
            return
        end

        if path == '/api/warn' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                local reason = tostring(data.reason or 'Warned by staff')
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                TriggerClientEvent('chat:addMessage', target, {
                    color = { 192, 132, 252 },
                    args = { 'LucidGuard', reason }
                })
                if PanelPush then
                    PanelPush({ type = 'system', message = ('Web warn #%s: %s'):format(target, reason) })
                end
                sendJson(res, 200, { ok = true })
            end)
            return
        end

        if path == '/api/announce' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local message = tostring(data.message or '')
                if message == '' then
                    sendJson(res, 400, { error = 'Empty message' })
                    return
                end
                TriggerClientEvent('chat:addMessage', -1, {
                    color = { 192, 132, 252 },
                    args = { 'STAFF', message }
                })
                if PanelPush then
                    PanelPush({ type = 'system', message = 'Announce: ' .. message })
                end
                sendJson(res, 200, { ok = true })
            end)
            return
        end

        if path == '/api/shadowban' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                local queued = false
                if GetResourceState('lucidguard-advanced') == 'started' then
                    local ok2 = pcall(function()
                        queued = exports['lucidguard-advanced']:QueueShadowban(target, 'WEB_PANEL')
                    end)
                    queued = ok2 and queued
                end
                sendJson(res, queued and 200 or 500, { ok = queued, error = queued and nil or 'Shadowban unavailable' })
            end)
            return
        end

        if path == '/api/watch' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                local watched = false
                if GetResourceState('lucidguard-advanced') == 'started' then
                    pcall(function()
                        watched = exports['lucidguard-advanced']:TrustWatch(target, data.reason or 'web panel')
                    end)
                end
                sendJson(res, 200, { ok = watched })
            end)
            return
        end

        if path == '/api/screenshot' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                if GetResourceState('screenshot-basic') ~= 'started' then
                    sendJson(res, 500, { error = 'screenshot-basic not started' })
                    return
                end
                local webhook = Config.Panel and Config.Panel.ScreenshotWebhook or ''
                if webhook == '' then
                    sendJson(res, 500, { error = 'Set lucidguard_screenshot_webhook' })
                    return
                end
                TriggerClientEvent('lg_ac:panel:takeScreenshot', target, 0, webhook)
                sendJson(res, 200, { ok = true })
            end)
            return
        end

        if path == '/api/freeze' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                TriggerClientEvent('lg_ac:evidence:doFreeze', target, data.freeze and true or false)
                sendJson(res, 200, { ok = true })
            end)
            return
        end

        if path == '/api/clearfeed' and req.method == 'POST' then
            if type(LucidGuardGetFeed) == 'function' then
                local f = LucidGuardGetFeed()
                if type(f) == 'table' then
                    for i = #f, 1, -1 do f[i] = nil end
                end
            end
            sendJson(res, 200, { ok = true })
            return
        end

        if path == '/api/theme' and req.method == 'GET' then
            local theme = (Config.WebPanel and Config.WebPanel.Theme) or { Snow = 'orange', Accent = '#f97316' }
            sendJson(res, 200, { snow = theme.Snow or 'orange', accent = theme.Accent or '#f97316' })
            return
        end

        if path == '/api/theme' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local pin = tostring(data.pin or '')
                local expected = (Config.WebPanel and Config.WebPanel.ThemePin) or GetConvar('lucidguard_theme_pin', 'lucidowner')
                if pin ~= expected then
                    sendJson(res, 403, { error = 'Owner theme PIN required' })
                    return
                end
                local snow = tostring(data.snow or 'orange')
                local allowed = { orange = true, purple = true, teal = true, rose = true, gold = true }
                if not allowed[snow] then snow = 'orange' end
                Config.WebPanel = Config.WebPanel or {}
                Config.WebPanel.Theme = Config.WebPanel.Theme or {}
                Config.WebPanel.Theme.Snow = snow
                if PanelPush then
                    PanelPush({ type = 'system', message = ('Owner set snowfall theme: %s'):format(snow) })
                end
                sendJson(res, 200, { ok = true, snow = snow })
            end)
            return
        end

        if path == '/api/identifiers' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                local ids = {}
                pcall(function() ids = GetAllIdentifiers(target) or {} end)
                sendJson(res, 200, {
                    ok = true,
                    name = GetPlayerName(target),
                    id = target,
                    identifiers = ids
                })
            end)
            return
        end

        if path == '/api/clearrisk' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                if not target then
                    sendJson(res, 400, { error = 'Bad id' })
                    return
                end
                if type(LucidGuardGetRiskScores) == 'function' then
                    local risks = LucidGuardGetRiskScores()
                    if risks then risks[target] = 0 end
                end
                sendJson(res, 200, { ok = true })
            end)
            return
        end

        if path == '/api/recheck' and req.method == 'POST' then
            req.setDataHandler(function(body)
                local ok, data = pcall(json.decode, body or '{}')
                data = ok and data or {}
                local target = tonumber(data.id)
                if not target or not GetPlayerName(target) then
                    sendJson(res, 404, { error = 'Player not found' })
                    return
                end
                TriggerClientEvent('lg_ac:adv:forceRecheck', target)
                sendJson(res, 200, { ok = true })
            end)
            return
        end

        if path == '/api/testcase' and req.method == 'POST' then
            if SendCaseToDiscord then
                SendCaseToDiscord({
                    id = 0,
                    playerId = 0,
                    player = 'TEST_PLAYER',
                    detection = 'TEST_CASE_WEBHOOK',
                    severity = 'HIGH',
                    details = 'Staff tested LucidGuard case Discord integration from the web panel.',
                    status = 'test'
                })
                sendJson(res, 200, { ok = true, message = 'Test embed sent (if webhook is set)' })
            else
                sendJson(res, 500, { error = 'Case Discord helper missing' })
            end
            return
        end

        sendJson(res, 404, { error = 'Unknown API' })
        return
    end

    -- Static files from /web
    local rel = path:gsub('^/', '')
    rel = rel:gsub('%.%.', '')
    local ext = rel:match('%.([%w]+)$') or 'html'
    local data = readWebFile(rel)
    if not data then
        send(res, 404, 'Not found')
        return
    end
    send(res, 200, data, MIME[ext] or 'text/plain; charset=utf-8')
end)

print('^2[LucidGuard]^7 Web panel: http://127.0.0.1:30120/lucidguard/  (set lucidguard_web_password)')
