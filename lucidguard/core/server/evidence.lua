--[[
    LucidGuard — staff evidence / case workflow
    Auto-cases on HIGH/CRITICAL, screenshots, spectate, freeze, timeline.
]]

Evidence = Evidence or {}
local cases = {} -- id -> case
local nextId = 1
local MAX_CASES = 80

local function pushPanel(entry)
    if PanelPush then PanelPush(entry) end
end

local function newCase(playerId, detectionType, severity, details)
    local id = nextId
    nextId = nextId + 1
    local case = {
        id = id,
        playerId = playerId,
        player = GetPlayerName(playerId) or 'unknown',
        detection = detectionType,
        severity = severity,
        details = type(details) == 'table' and json.encode(details) or tostring(details or ''),
        ts = os.time(),
        timeline = {},
        screenshots = 0,
        status = 'open'
    }
    case.timeline[#case.timeline + 1] = {
        ts = os.time(),
        event = 'opened',
        note = detectionType
    }
    cases[id] = case

    -- prune
    local count = 0
    for _ in pairs(cases) do count = count + 1 end
    if count > MAX_CASES then
        local oldest, oldestTs = nil, math.huge
        for cid, c in pairs(cases) do
            if c.ts < oldestTs then oldest, oldestTs = cid, c.ts end
        end
        if oldest then cases[oldest] = nil end
    end

    pushPanel({
        type = 'case',
        message = ('Case #%s opened: %s on %s (%s)'):format(id, detectionType, case.player, severity),
        caseId = id,
        id = playerId
    })

    -- Staff Discord (admin channel webhook) — set lucidguard_case_webhook later
    if Config.Evidence and Config.Evidence.CaseDiscordEnabled ~= false then
        SendCaseToDiscord(case)
    end

    return case
end

function SendCaseToDiscord(case)
    local url = (Config.Evidence and Config.Evidence.CaseWebhook) or ''
    if url == '' then
        url = GetConvar('lucidguard_case_webhook', '')
    end
    -- Fallback: main AC webhook if case webhook not set yet
    if url == '' and Config.Discord and Config.Discord.WebhookURL and Config.Discord.WebhookURL ~= '' then
        url = Config.Discord.WebhookURL
    end
    if url == '' then return end

    local color = ({
        CRITICAL = 16724787,
        HIGH = 16750848,
        MEDIUM = 16776960,
        LOW = 65280
    })[case.severity] or 16239900 -- orange default

    local ids = {}
    pcall(function()
        ids = exports['lucidguard']:GetAllIdentifiers(case.playerId) or {}
    end)

    local embed = {
        {
            title = ('LucidGuard Case #%s'):format(case.id),
            description = ('**%s** on **%s** (`#%s`)'):format(case.detection, case.player, case.playerId),
            color = color,
            fields = {
                { name = 'Severity', value = tostring(case.severity or '?'), inline = true },
                { name = 'Status', value = tostring(case.status or 'open'), inline = true },
                { name = 'Details', value = string.sub(tostring(case.details or 'n/a'), 1, 900), inline = false },
                { name = 'License', value = tostring(ids.license or 'n/a'), inline = false },
                { name = 'Discord', value = tostring(ids.discord or 'n/a'), inline = true },
            },
            footer = { text = 'LucidGuard · staff only' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'LucidGuard Cases',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

_G.SendCaseToDiscord = SendCaseToDiscord

function Evidence.List(limit)
    limit = limit or 30
    local list = {}
    for _, c in pairs(cases) do
        list[#list + 1] = c
    end
    table.sort(list, function(a, b) return a.id > b.id end)
    local out = {}
    for i = 1, math.min(limit, #list) do
        out[i] = list[i]
    end
    return out
end

function Evidence.Get(id)
    return cases[tonumber(id)]
end

function Evidence.AddNote(caseId, adminName, note)
    local c = cases[tonumber(caseId)]
    if not c then return false end
    c.timeline[#c.timeline + 1] = {
        ts = os.time(),
        event = 'note',
        note = tostring(note or ''),
        by = adminName
    }
    return true
end

function Evidence.Close(caseId, adminName)
    local c = cases[tonumber(caseId)]
    if not c then return false end
    c.status = 'closed'
    c.timeline[#c.timeline + 1] = { ts = os.time(), event = 'closed', by = adminName }
    return true
end

local function requestScreenshot(targetId, requestor, reason)
    if GetResourceState('screenshot-basic') ~= 'started' then
        return false, 'screenshot-basic not started'
    end
    local webhook = Config.Panel and Config.Panel.ScreenshotWebhook or ''
    if webhook == '' then
        return false, 'set lucidguard_screenshot_webhook'
    end
    TriggerClientEvent('lg_ac:panel:takeScreenshot', targetId, requestor or 0, webhook)
    return true
end

-- Auto-open cases + optional auto screenshot
AddEventHandler('lucidguard:onDetection', function(playerId, detectionType, severity, details)
    if not Config.Evidence or Config.Evidence.Enabled == false then return end
    local sev = tostring(severity or '')
    local auto = Config.Evidence.AutoCaseSeverities or { HIGH = true, CRITICAL = true }
    if not auto[sev] then return end

    local case = newCase(playerId, detectionType, sev, details)

    if Config.Evidence.AutoScreenshot and (sev == 'CRITICAL' or sev == 'HIGH') then
        local ok = requestScreenshot(playerId, 0, detectionType)
        if ok then
            case.screenshots = case.screenshots + 1
            case.timeline[#case.timeline + 1] = { ts = os.time(), event = 'screenshot', note = 'auto' }
        end
    end
end)

-- Panel API
RegisterNetEvent('lg_ac:evidence:list', function()
    local src = source
    if not (IsPlayerAdmin and IsPlayerAdmin(src)) then return end
    TriggerClientEvent('lg_ac:evidence:data', src, Evidence.List(40))
end)

RegisterNetEvent('lg_ac:evidence:note', function(caseId, note)
    local src = source
    if not (IsPlayerAdmin and IsPlayerAdmin(src)) then return end
    Evidence.AddNote(caseId, GetPlayerName(src), note)
    TriggerClientEvent('lg_ac:evidence:data', src, Evidence.List(40))
end)

RegisterNetEvent('lg_ac:evidence:close', function(caseId)
    local src = source
    if not (IsPlayerAdmin and IsPlayerAdmin(src)) then return end
    Evidence.Close(caseId, GetPlayerName(src))
    TriggerClientEvent('lg_ac:evidence:data', src, Evidence.List(40))
end)

RegisterNetEvent('lg_ac:evidence:screenshot', function(targetId)
    local src = source
    if not (IsPlayerAdmin and IsPlayerAdmin(src)) then return end
    targetId = tonumber(targetId)
    local ok, err = requestScreenshot(targetId, src, 'manual')
    TriggerClientEvent('lg_ac:panel:toast', src, ok and 'Screenshot requested' or err)
end)

RegisterNetEvent('lg_ac:evidence:spectate', function(targetId)
    local src = source
    if not (IsPlayerAdmin and IsPlayerAdmin(src)) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    TriggerClientEvent('lg_ac:evidence:doSpectate', src, targetId)
    pushPanel({ type = 'system', message = ('%s spectating #%s'):format(GetPlayerName(src), targetId) })
end)

RegisterNetEvent('lg_ac:evidence:freeze', function(targetId, freeze)
    local src = source
    if not (IsPlayerAdmin and IsPlayerAdmin(src)) then return end
    targetId = tonumber(targetId)
    if not targetId then return end
    TriggerClientEvent('lg_ac:evidence:doFreeze', targetId, freeze and true or false)
    pushPanel({
        type = 'system',
        message = ('%s %s #%s'):format(GetPlayerName(src), freeze and 'froze' or 'unfroze', targetId)
    })
end)

RegisterNetEvent('lg_ac:evidence:timeline', function(targetId)
    local src = source
    if not (IsPlayerAdmin and IsPlayerAdmin(src)) then return end
    targetId = tonumber(targetId)
    -- Build from recent feed if Panel has it — reconstruct from cases
    local events = {}
    for _, c in pairs(cases) do
        if c.playerId == targetId then
            events[#events + 1] = {
                ts = c.ts,
                detection = c.detection,
                severity = c.severity,
                details = c.details,
                caseId = c.id
            }
        end
    end
    table.sort(events, function(a, b) return (a.ts or 0) > (b.ts or 0) end)
    TriggerClientEvent('lg_ac:evidence:playerTimeline', src, targetId, events)
end)

exports('EvidenceList', Evidence.List)
exports('EvidenceGet', Evidence.Get)
_G.Evidence = Evidence

print('^2[LucidGuard]^7 Evidence workflow loaded')
