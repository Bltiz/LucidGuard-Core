--[[
    LucidGuard Free Core | Created by OnlyLucidVibes
    ESX Legacy | Version 2.0.1
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'OnlyLucidVibes'
description 'LucidGuard - Free FiveM Anticheat Core (ESX)'
version '2.0.1'
name 'lucidguard'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/snow.js'
}

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'core/server/license.lua',
    'core/server/logging.lua',
    'core/server/falsepositive.lua',
    'core/server/violationmanager.lua',
    'core/server/main.lua',
    'core/server/banstore.lua',
    'core/server/punish.lua',
    'core/server/ratelimit.lua',
    'core/server/playersafety.lua',
    'core/server/safepunishment.lua',
    'core/server/smartdetection.lua',
    'core/server/panel.lua',
    'core/server/evidence.lua',
    'core/server/http_panel.lua',
    'core/server/startup_announce.lua',
    'modules/free/server/*.lua'
}

client_scripts {
    'core/client/main.lua',
    'core/client/heartbeat.lua',
    'core/client/statereporter.lua',
    'core/client/legitimacy.lua',
    'core/client/panel.lua',
    'core/client/evidence.lua',
    'modules/free/client/*.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}
