--[[
    Free — dead-man switch
    If the LucidGuard client stops talking (menu killed AC / blocked events), flag hard.
]]

local lastAlive = {}
local strikes = {}

RegisterNetEvent('lg_ac:alive', function()
    lastAlive[source] = os.time()
    strikes[source] = 0
end)

AddEventHandler('playerJoining', function()
    lastAlive[source] = os.time()
end)

CreateThread(function()
    Wait(25000)
    while true do
        Wait((Config.DeadMan and Config.DeadMan.CheckMs) or 10000)
        if not Config.Modules.DeadMan then goto continue end

        local timeout = (Config.DeadMan and Config.DeadMan.TimeoutSec) or 45
        local now = os.time()
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if src and not (IsPlayerAdmin and IsPlayerAdmin(src)) then
                local last = lastAlive[src]
                -- Prefer explicit alive ping; fall back to core heartbeat field
                if not last then
                    local data = GetPlayerData and GetPlayerData(src)
                    last = data and data.lastHeartbeat or now
                end
                local data = GetPlayerData and GetPlayerData(src)
                if data and data.lastHeartbeat and data.lastHeartbeat > (last or 0) then
                    last = data.lastHeartbeat
                end

                if last and (now - last) >= timeout then
                    strikes[src] = (strikes[src] or 0) + 1
                    if strikes[src] >= (Config.DeadMan.Strikes or 2) then
                        strikes[src] = 0
                        if ProcessDetection then
                            ProcessDetection(src, 'AC_DEADMAN', 'CRITICAL',
                                ('No LucidGuard client signal for %ss — AC stopped/blocked?'):format(now - last))
                        end
                    end
                else
                    strikes[src] = 0
                end
            end
        end
        ::continue::
    end
end)

AddEventHandler('playerDropped', function()
    lastAlive[source] = nil
    strikes[source] = nil
end)

print('^2[LucidGuard]^7 Dead-man switch loaded')
