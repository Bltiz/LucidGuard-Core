--[[ Free — keep-alive so server knows AC client is still executing ]]

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(200) end
    Wait(8000)
    while true do
        Wait((Config.DeadMan and Config.DeadMan.PingMs) or 8000)
        if Config.Modules.DeadMan == false then goto continue end
        TriggerServerEvent('lg_ac:alive', tostring(GetGameTimer()))
        ::continue::
    end
end)

-- If this resource is stopping unexpectedly, try one last scream (best-effort)
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        TriggerServerEvent('lg_ac:report', 'AC_CLIENT_STOP', 'CRITICAL', 'lucidguard client resource stopping')
    end
end)
