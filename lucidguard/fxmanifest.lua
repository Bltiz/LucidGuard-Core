--[[
    ██╗     ██╗   ██╗  ██████╗ ██╗ ██████╗   ██████╗  ██╗   ██╗  █████╗  ██████╗  ██████╗
    ██║     ██║   ██║ ██╔════╝ ██║ ██╔══██╗ ██╔════╝  ██║   ██║ ██╔══██╗ ██╔══██╗ ██╔══██╗
    ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║  ███╗ ██║   ██║ ███████║ ██████╔╝ ██║  ██║
    ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║   ██║ ██║   ██║ ██╔══██║ ██╔══██╗ ██║  ██║
    ███████╗╚██████╔╝ ╚██████╗ ██║ ██████╔╝ ╚██████╔╝ ╚██████╔╝ ██║  ██║ ██║  ██║ ██████╔╝
    ╚══════╝ ╚═════╝   ╚═════╝ ╚═╝ ╚═════╝   ╚═════╝   ╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═════╝

    Free FiveM Anticheat | Created by OnlyLucidVibes
    ESX Framework Integration | txAdmin Compatible | Version 2.0.0

    Open-source core protection. Upgrade to Basic or Advanced for premium features.
    Purchase at the Tebex store - delivered via FiveM asset escrow.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'OnlyLucidVibes'
description 'LucidGuard - Free FiveM Anticheat with Core Protection, ESX Integration, Discord Logging'
version '2.0.0'

-- Shared configuration (loaded first)
shared_scripts {
    'config.lua'
}

-- Server-side scripts
server_scripts {
    -- Core systems (load order matters - license first, then logging, then FP, then main)
    'core/server/license.lua',
    'core/server/logging.lua',
    'core/server/falsepositive.lua',
    'core/server/violationmanager.lua',
    'core/server/main.lua',
    'core/server/punish.lua',
    'core/server/ratelimit.lua',
    'core/server/playersafety.lua',
    'core/server/safepunishment.lua',
    'core/server/smartdetection.lua',
    -- FREE tier modules (always active)
    'modules/free/server/*.lua'
}

-- Client-side scripts
client_scripts {
    -- Core systems (load order matters - main first for RequiresTier)
    'core/client/main.lua',
    'core/client/heartbeat.lua',
    'core/client/statereporter.lua',
    'core/client/legitimacy.lua',
    -- FREE tier modules (always active)
    'modules/free/client/*.lua'
}

-- Dependencies
dependencies {
    'es_extended'
}

-- Prevent resource from being stopped by exploits
dont_auto_start_resources { 'lucidguard' }
