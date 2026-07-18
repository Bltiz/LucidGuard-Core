--[[ LucidGuard Admin Panel — client NUI bridge ]]

local open = false
LucidGuardPanelOpen = false

local function setOpen(state, payload)
    open = state
    LucidGuardPanelOpen = state and true or false
    SetNuiFocus(state, state)
    SendNUIMessage({
        action = state and 'open' or 'close',
        data = payload
    })
end

-- Default key: F7
CreateThread(function()
    while true do
        Wait(0)
        if Config.Panel and Config.Panel.Enabled == false then
            Wait(500)
            goto continue
        end
        if IsControlJustReleased(0, 168) then -- F7
            if open then
                setOpen(false)
            else
                TriggerServerEvent('lg_ac:panel:requestOpen')
            end
        end
        ::continue::
    end
end)

RegisterNetEvent('lg_ac:panel:open', function(payload)
    setOpen(true, payload)
end)

RegisterNetEvent('lg_ac:panel:denied', function()
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('~r~LucidGuard: admin only')
    EndTextCommandThefeedPostTicker(false, false)
end)

RegisterNetEvent('lg_ac:panel:data', function(payload)
    SendNUIMessage({ action = 'data', data = payload })
end)

RegisterNetEvent('lg_ac:panel:feed', function(entry)
    if open then
        SendNUIMessage({ action = 'feed', entry = entry })
    end
end)

RegisterNetEvent('lg_ac:panel:toast', function(msg)
    SendNUIMessage({ action = 'toast', message = msg })
end)

RegisterNetEvent('lg_ac:panel:takeScreenshot', function(requestor, webhook)
    if GetResourceState('screenshot-basic') ~= 'started' then return end
    if type(webhook) ~= 'string' or webhook == '' then
        TriggerServerEvent('lg_ac:panel:screenshotDone', requestor, false, 'no webhook')
        return
    end
    exports['screenshot-basic']:requestScreenshotUpload(webhook, 'files[]', function()
        TriggerServerEvent('lg_ac:panel:screenshotDone', requestor, true)
    end)
end)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('lg_ac:panel:refresh')
    cb('ok')
end)

RegisterNUICallback('setSafeMode', function(data, cb)
    TriggerServerEvent('lg_ac:panel:setSafeMode', data.enabled and true or false)
    cb('ok')
end)

RegisterNUICallback('kick', function(data, cb)
    TriggerServerEvent('lg_ac:panel:kick', data.id, data.reason)
    cb('ok')
end)

RegisterNUICallback('ban', function(data, cb)
    TriggerServerEvent('lg_ac:panel:ban', data.id, data.reason)
    cb('ok')
end)

RegisterNUICallback('clearRisk', function(data, cb)
    TriggerServerEvent('lg_ac:panel:clearRisk', data.id)
    cb('ok')
end)

RegisterNUICallback('clearFeed', function(_, cb)
    TriggerServerEvent('lg_ac:panel:clearFeed')
    cb('ok')
end)

RegisterNUICallback('screenshot', function(data, cb)
    TriggerServerEvent('lg_ac:panel:screenshot', data.id)
    cb('ok')
end)

RegisterNUICallback('announce', function(data, cb)
    TriggerServerEvent('lg_ac:panel:announce', data.message)
    cb('ok')
end)

RegisterNUICallback('warn', function(data, cb)
    TriggerServerEvent('lg_ac:panel:warn', data.id, data.reason)
    cb('ok')
end)

RegisterNUICallback('shadowban', function(data, cb)
    TriggerServerEvent('lg_ac:panel:shadowban', data.id)
    cb('ok')
end)

RegisterNUICallback('watch', function(data, cb)
    TriggerServerEvent('lg_ac:panel:watch', data.id, data.reason)
    cb('ok')
end)

RegisterNUICallback('lookupIds', function(data, cb)
    TriggerServerEvent('lg_ac:panel:lookupIds', data.id)
    cb('ok')
end)

RegisterNUICallback('forceRecheck', function(data, cb)
    TriggerServerEvent('lg_ac:panel:forceRecheck', data.id)
    cb('ok')
end)

RegisterNUICallback('testCaseWebhook', function(_, cb)
    TriggerServerEvent('lg_ac:panel:testCaseWebhook')
    cb('ok')
end)

RegisterNetEvent('lg_ac:panel:identifiers', function(payload)
    SendNUIMessage({ action = 'identifiers', data = payload or {} })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then
        SetNuiFocus(false, false)
    end
end)
