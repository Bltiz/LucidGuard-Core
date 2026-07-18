--[[ Free tier — basic executor / overlay side-effect signals ]]

CreateThread(function()
    while true do
        Wait(10000)
        if not Config.Modules.DevTools then goto continue end

        -- Sudden huge ped health/armor spikes (menus often set 1000+)
        local ped = PlayerPedId()
        local hp = GetEntityHealth(ped)
        local armor = GetPedArmour(ped)
        if hp > 250 then
            ReportDetection('HEALTH_OVERFLOW', 'CRITICAL', ('Health=%s'):format(hp))
        end
        if armor > 100 then
            ReportDetection('ARMOR_OVERFLOW', 'HIGH', ('Armor=%s'):format(armor))
        end

        -- Run-speed multiplier native abuse
        local mult = GetRunSprintMultiplierForPlayer(PlayerId())
        if mult and mult > 1.35 then
            ReportDetection('SPEED_MULTIPLIER', 'HIGH', ('Sprint mult=%.2f'):format(mult))
        end

        ::continue::
    end
end)
