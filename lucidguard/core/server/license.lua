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
function LicenseManager.Init()
    -- Wait a moment for all resources to start
    CreateThread(function()
        Wait(2000)

        local hasBasic = GetResourceState('lucidguard-basic') == 'started'
        local hasAdvanced = GetResourceState('lucidguard-advanced') == 'started'

        if hasAdvanced and hasBasic then
            Config.Tier = 'ADVANCED'
            Config.TierLevel = 3
            print('[^2LucidGuard^0] Tier detected: ^2ADVANCED^0 (all modules active)')
        elseif hasAdvanced then
            Config.Tier = 'ADVANCED'
            Config.TierLevel = 3
            print('[^2LucidGuard^0] Tier detected: ^2ADVANCED^0 (advanced modules active)')
        elseif hasBasic then
            Config.Tier = 'BASIC'
            Config.TierLevel = 2
            print('[^3LucidGuard^0] Tier detected: ^3BASIC^0 (basic modules active)')
        else
            Config.Tier = 'FREE'
            Config.TierLevel = 1
            print('[^3LucidGuard^0] Tier detected: ^1FREE^0 (core modules only)')
            print('[^3LucidGuard^0] Upgrade at your Tebex store for Basic & Advanced features.')
        end
    end)

    -- Set defaults immediately (thread above will update)
    Config.Tier = 'FREE'
    Config.TierLevel = 1
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

-- Sync tier to clients on join
AddEventHandler('playerJoining', function()
    local src = source
    TriggerClientEvent('lg_ac:setTier', src, Config.Tier)
end)

-- Global access
_G.LicenseManager = LicenseManager

-- Exports
exports('RequiresTier', LicenseManager.RequiresTier)
exports('GetTier', LicenseManager.GetTier)
exports('GetTierLevel', LicenseManager.GetTierLevel)

print('[^2LucidGuard^0] Tier Detection loaded')
