--[[
    Post LucidGuard browser panel link to Discord (+ console) when the server/resource starts.
]]

local function resolvePanelUrl()
    local override = GetConvar('lucidguard_panel_url', '')
    if override ~= '' then
        return override
    end

    local host = GetConvar('lucidguard_panel_host', '')
    if host == '' then
        host = GetConvar('sv_listingHostOverride', '')
    end
    if host == '' then
        -- Best-effort public IP for remote staff (falls back to localhost if lookup fails)
        return nil, true -- signal: need async IP lookup
    end

    -- Strip protocol if staff pasted a full URL into host
    host = host:gsub('^https?://', ''):gsub('/+$', '')
    local port = GetConvarInt('lucidguard_panel_port', 30120)
    return ('http://%s:%s/lucidguard/'):format(host, port), false
end

local function webhookTargets()
    local urls = {}
    local seen = {}
    local candidates = {
        GetConvar('lucidguard_panel_webhook', ''),
        GetConvar('lucidguard_case_webhook', ''),
        GetConvar('discord_webhook', ''),
        (Config.Discord and Config.Discord.WebhookURL) or '',
        (Config.Evidence and Config.Evidence.CaseWebhook) or ''
    }
    for _, url in ipairs(candidates) do
        if type(url) == 'string' and url ~= '' and not seen[url] then
            seen[url] = true
            urls[#urls + 1] = url
        end
    end
    return urls
end

local function postDiscord(panelUrl)
    local urls = webhookTargets()
    if #urls == 0 then
        print('^3[LucidGuard]^7 Startup panel announce: no Discord webhook set (panel URL still printed below)')
        return
    end

    local hostname = GetConvar('sv_projectName', '') ~= '' and GetConvar('sv_projectName', '')
        or GetConvar('sv_hostname', 'FiveM Server')

    local payload = {
        username = (Config.Discord and Config.Discord.BotName) or 'LucidGuard',
        avatar_url = (Config.Discord and Config.Discord.BotAvatar) or nil,
        embeds = {{
            title = 'LucidGuard panel is online',
            description = ('**%s** finished starting.\n\n[Open staff browser panel](%s)\n\nPassword: `lucidguard_web_password` convar\nIn-game: **F7** (admin)'):format(
                hostname,
                panelUrl
            ),
            color = 16027670, -- orange
            fields = {
                { name = 'Panel', value = panelUrl, inline = false },
                { name = 'Local fallback', value = 'http://127.0.0.1:30120/lucidguard/', inline = false }
            },
            footer = { text = 'LucidGuard' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }

    local body = json.encode(payload)
    for _, url in ipairs(urls) do
        PerformHttpRequest(url, function(code)
            if code == 200 or code == 204 then
                print(('^2[LucidGuard]^7 Posted panel link to Discord (%s)'):format(code))
            else
                print(('^3[LucidGuard]^7 Discord panel announce HTTP %s'):format(tostring(code)))
            end
        end, 'POST', body, { ['Content-Type'] = 'application/json' })
    end
end

local function announce(panelUrl)
    local localUrl = 'http://127.0.0.1:30120/lucidguard/'
    print('^2[LucidGuard]^7 ========================================')
    print('^2[LucidGuard]^7 Staff browser panel:')
    print(('^3[LucidGuard]^7   On THIS PC (use this first): %s'):format(localUrl))
    print(('^3[LucidGuard]^7   Public link: %s'):format(panelUrl))
    print('^2[LucidGuard]^7 Password convar: lucidguard_web_password  |  In-game: F7')
    print('^3[LucidGuard]^7 If the public link fails but local works: open Windows Firewall')
    print('^3[LucidGuard]^7 inbound TCP 30120 + router port-forward TCP 30120 to this PC.')
    print('^3[LucidGuard]^7 (Same issue shows as dynamic.json timeout in the console.)')
    print('^2[LucidGuard]^7 ========================================')

    if PanelPush then
        PanelPush({
            type = 'system',
            message = ('Panel online: %s'):format(localUrl)
        })
    end

    postDiscord(panelUrl)
end

CreateThread(function()
    if Config.WebPanel and Config.WebPanel.AnnounceOnStart == false then
        return
    end
    if Config.WebPanel and Config.WebPanel.Enabled == false then
        return
    end

    Wait((Config.WebPanel and Config.WebPanel.AnnounceDelayMs) or 8000)

    local url, needLookup = resolvePanelUrl()
    if url then
        announce(url)
        return
    end

    -- Async public IP for clickable remote link
    PerformHttpRequest('https://api.ipify.org', function(code, body)
        local panelUrl
        if code == 200 and type(body) == 'string' and body:match('^%d+%.%d+%.%d+%.%d+$') then
            local port = GetConvarInt('lucidguard_panel_port', 30120)
            panelUrl = ('http://%s:%s/lucidguard/'):format(body, port)
        else
            panelUrl = 'http://127.0.0.1:30120/lucidguard/'
            print('^3[LucidGuard]^7 Could not resolve public IP — using localhost link. Set lucidguard_panel_url in server.cfg for a fixed link.')
        end
        announce(panelUrl)
    end, 'GET', '', {})
end)
