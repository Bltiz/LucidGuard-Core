--[[
    LucidGuard Anticheat - Tier Detection & Module Gating
    Created by OnlyLucidVibes

    Detects which LucidGuard resources are installed to determine the active tier.
    No license key needed - Tebex asset escrow handles authorization.

    Tiers: FREE (default), BASIC (lucidguard-basic), ADVANCED (lucidguard-advanced)
]]

local LicenseManager = {}

local TIER_LEVELS = {
    FREE = 1,
    BASIC = 2,
    ADVANCED = 3
}

-- Detect tier based on which resources are installed and started
local function syncTierToClients()
    local tier = Config.Tier or 'FREE'
    for _, playerId in ipairs(GetPlayers()) do
        TriggerClientEvent('lg_ac:setTier', tonumber(playerId), tier)
    end
end

function LicenseManager.RefreshTier()
    local hasBasic = GetResourceState('lucidguard-basic') == 'started'
    local hasAdvanced = GetResourceState('lucidguard-advanced') == 'started'
    local prev = Config.Tier or 'FREE'

    if hasAdvanced then
        Config.Tier = 'ADVANCED'
        Config.TierLevel = 3
    elseif hasBasic then
        Config.Tier = 'BASIC'
        Config.TierLevel = 2
    else
        Config.Tier = 'FREE'
        Config.TierLevel = 1
    end

    if prev ~= Config.Tier then
        print(('[^2LucidGuard^0] Tier detected: ^2%s^0'):format(Config.Tier))
        syncTierToClients()
    end

    return Config.Tier
end

function LicenseManager.Init()
    Config.Tier = 'FREE'
    Config.TierLevel = 1

    CreateThread(function()
        Wait(2000)
        LicenseManager.RefreshTier()
        -- Advanced may finish starting after the first probe
        Wait(3000)
        LicenseManager.RefreshTier()
    end)
end

-- Gate function: modules call this to check if they should run
function LicenseManager.RequiresTier(requiredTier)
    local requiredLevel = TIER_LEVELS[requiredTier] or 3
    return (Config.TierLevel or 1) >= requiredLevel
end

-- Get current tier name
function LicenseManager.GetTier()
    return Config.Tier or 'FREE'
end

-- Get current tier level (1-3)
function LicenseManager.GetTierLevel()
    return Config.TierLevel or 1
end

-- Initialize on load
LicenseManager.Init()

-- Sync tier to clients on join (delay so client handlers exist)
AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(3000, function()
        if GetPlayerName(src) then
            TriggerClientEvent('lg_ac:setTier', src, Config.Tier or 'FREE')
        end
    end)
end)

-- Global access
_G.LicenseManager = LicenseManager

-- Exports
exports('RequiresTier', LicenseManager.RequiresTier)
exports('GetTier', LicenseManager.GetTier)
exports('GetTierLevel', LicenseManager.GetTierLevel)
exports('RefreshTier', LicenseManager.RefreshTier)

print('[^2LucidGuard^0] Tier Detection loaded')
