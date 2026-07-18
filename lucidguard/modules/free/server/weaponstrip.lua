--[[ Free — continuously strip impossible / blacklisted weapons server-side ]]

local HASHES = nil

local function rebuild()
    HASHES = {}
    for _, name in ipairs(Config.WeaponStrip and Config.WeaponStrip.Blacklist or {}) do
        HASHES[joaat(name)] = name
    end
end

CreateThread(function()
    Wait(2000)
    if not Config.Modules.WeaponStrip then return end
    rebuild()
    print('^2[LucidGuard]^7 Weapon strip active')

    while true do
        Wait((Config.WeaponStrip and Config.WeaponStrip.SampleMs) or 6000)
        if not Config.Modules.WeaponStrip then goto continue end

        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if src and not (IsPlayerAdmin and IsPlayerAdmin(src)) then
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    local ok, weapon = pcall(GetSelectedPedWeapon, ped)
                    if ok and weapon and HASHES[weapon] then
                        RemoveWeaponFromPed(ped, weapon)
                        if ProcessDetection then
                            ProcessDetection(src, 'WEAPON_STRIP', 'CRITICAL',
                                ('Stripped blacklisted weapon %s'):format(HASHES[weapon]))
                        end
                    end
                end
            end
        end
        ::continue::
    end
end)
