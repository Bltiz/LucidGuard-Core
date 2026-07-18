--[[ Client evidence helpers — spectate + freeze for staff review ]]

local spectating = false
local specTarget = nil

RegisterNetEvent('lg_ac:evidence:doSpectate', function(targetId)
    targetId = tonumber(targetId)
    if not targetId then return end

    if spectating and specTarget == targetId then
        -- toggle off
        local me = PlayerId()
        NetworkSetInSpectatorMode(false, PlayerPedId())
        spectating = false
        specTarget = nil
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('~g~LucidGuard: spectate off')
        EndTextCommandThefeedPostTicker(false, false)
        return
    end

    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    if targetPed and targetPed ~= 0 then
        NetworkSetInSpectatorMode(true, targetPed)
        spectating = true
        specTarget = targetId
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(('~y~Spectating #%s (F7 → Cases to stop)'):format(targetId))
        EndTextCommandThefeedPostTicker(false, false)
    end
end)

RegisterNetEvent('lg_ac:evidence:doFreeze', function(freeze)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, freeze and true or false)
    if freeze then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('~r~You have been frozen by staff')
        EndTextCommandThefeedPostTicker(false, false)
    end
end)

RegisterNetEvent('lg_ac:evidence:data', function(list)
    SendNUIMessage({ action = 'cases', cases = list or {} })
end)

RegisterNetEvent('lg_ac:evidence:playerTimeline', function(targetId, events)
    SendNUIMessage({ action = 'timeline', targetId = targetId, events = events or {} })
end)

RegisterNUICallback('evidenceList', function(_, cb)
    TriggerServerEvent('lg_ac:evidence:list')
    cb('ok')
end)

RegisterNUICallback('evidenceNote', function(data, cb)
    TriggerServerEvent('lg_ac:evidence:note', data.id, data.note)
    cb('ok')
end)

RegisterNUICallback('evidenceClose', function(data, cb)
    TriggerServerEvent('lg_ac:evidence:close', data.id)
    cb('ok')
end)

RegisterNUICallback('evidenceSpectate', function(data, cb)
    TriggerServerEvent('lg_ac:evidence:spectate', data.id)
    cb('ok')
end)

RegisterNUICallback('evidenceFreeze', function(data, cb)
    TriggerServerEvent('lg_ac:evidence:freeze', data.id, data.freeze)
    cb('ok')
end)

RegisterNUICallback('evidenceTimeline', function(data, cb)
    TriggerServerEvent('lg_ac:evidence:timeline', data.id)
    cb('ok')
end)

RegisterNUICallback('evidenceScreenshot', function(data, cb)
    TriggerServerEvent('lg_ac:evidence:screenshot', data.id)
    cb('ok')
end)
