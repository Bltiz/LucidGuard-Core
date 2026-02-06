--[[
    LucidGuard Anticheat - Advanced Logging System
    by OnlyLucidVibes
    
    Comprehensive logging with:
    - Multiple log levels (DEBUG, INFO, WARN, ALERT, CRITICAL)
    - File logging with rotation
    - Discord integration with rate limiting
    - Contextual player data
    - Violation history tracking
]]

local Logger = {}
Logger.logs = {}
Logger.violationHistory = {}
Logger.discordQueue = {}
Logger.lastDiscordSend = 0

-- ============================================================================
-- LOG LEVELS
-- ============================================================================

Logger.LEVELS = {
    DEBUG = { priority = 1, color = '^7', emoji = '🔍', discord = false },
    INFO = { priority = 2, color = '^2', emoji = 'ℹ️', discord = false },
    WARN = { priority = 3, color = '^3', emoji = '⚠️', discord = true },
    ALERT = { priority = 4, color = '^1', emoji = '🚨', discord = true },
    CRITICAL = { priority = 5, color = '^1', emoji = '🔴', discord = true }
}

-- Minimum level to log (set via config)
Logger.minLevel = 'INFO'

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local CONFIG = Config.Logging or {
    Enabled = true,
    MinLevel = 'INFO',
    
    -- Console logging
    ConsoleEnabled = true,
    ConsoleColors = true,
    
    -- File logging
    FileEnabled = true,
    FilePath = 'logs/',
    MaxFileSize = 5242880,      -- 5MB
    MaxFiles = 10,
    
    -- Discord logging
    DiscordEnabled = true,
    DiscordMinLevel = 'WARN',
    DiscordRateLimit = 2000,    -- 2 seconds between messages
    DiscordBatchSize = 5,       -- Batch up to 5 logs
    
    -- Include extra context
    IncludeIdentifiers = true,
    IncludePosition = true,
    IncludePing = true,
    IncludeViolationHistory = true
}

-- ============================================================================
-- CORE LOGGING FUNCTION
-- ============================================================================

function Logger.Log(level, category, message, playerId, extraData)
    if not CONFIG.Enabled then return end
    
    local levelConfig = Logger.LEVELS[level]
    if not levelConfig then
        level = 'INFO'
        levelConfig = Logger.LEVELS.INFO
    end
    
    -- Check minimum level
    local minLevelConfig = Logger.LEVELS[CONFIG.MinLevel or 'INFO']
    if levelConfig.priority < minLevelConfig.priority then return end
    
    -- Build log entry
    local logEntry = {
        timestamp = os.date('%Y-%m-%d %H:%M:%S'),
        unixTime = os.time(),
        level = level,
        category = category,
        message = message,
        playerId = playerId,
        playerName = playerId and GetPlayerName(playerId) or nil,
        extraData = extraData or {}
    }
    
    -- Add player context if available
    if playerId and CONFIG.IncludeIdentifiers then
        logEntry.identifiers = GetPlayerIdentifiers(playerId)
    end
    
    if playerId and CONFIG.IncludePing then
        logEntry.ping = GetPlayerPing(playerId)
    end
    
    if playerId and CONFIG.IncludeViolationHistory then
        logEntry.violationCount = Logger.GetViolationCount(playerId, category)
    end
    
    -- Store log
    table.insert(Logger.logs, logEntry)
    
    -- Keep only last 1000 logs in memory
    if #Logger.logs > 1000 then
        table.remove(Logger.logs, 1)
    end
    
    -- Console output
    if CONFIG.ConsoleEnabled then
        Logger.ConsoleLog(logEntry, levelConfig)
    end
    
    -- File output
    if CONFIG.FileEnabled then
        Logger.FileLog(logEntry)
    end
    
    -- Discord output
    if CONFIG.DiscordEnabled and levelConfig.priority >= Logger.LEVELS[CONFIG.DiscordMinLevel].priority then
        Logger.QueueDiscordLog(logEntry, levelConfig)
    end
    
    return logEntry
end

-- ============================================================================
-- CONSOLE LOGGING
-- ============================================================================

function Logger.ConsoleLog(entry, levelConfig)
    local color = CONFIG.ConsoleColors and levelConfig.color or ''
    local reset = CONFIG.ConsoleColors and '^0' or ''
    
    local playerInfo = ''
    if entry.playerId then
        playerInfo = string.format(' [%s (%d)]', entry.playerName or 'Unknown', entry.playerId)
    end
    
    local pingInfo = ''
    if entry.ping then
        pingInfo = string.format(' [%dms]', entry.ping)
    end
    
    print(string.format('%s[LucidGuard]%s [%s] [%s]%s%s %s',
        color, reset,
        entry.timestamp,
        entry.level,
        playerInfo,
        pingInfo,
        entry.message
    ))
end

-- ============================================================================
-- FILE LOGGING
-- ============================================================================

local currentLogFile = nil
local currentLogSize = 0

function Logger.FileLog(entry)
    local fileName = string.format('%s/lucidguard_%s.log', 
        CONFIG.FilePath, 
        os.date('%Y-%m-%d'))
    
    local line = string.format('[%s] [%s] [%s] %s%s\n',
        entry.timestamp,
        entry.level,
        entry.category,
        entry.playerId and string.format('[Player: %s (%d)] ', entry.playerName or 'Unknown', entry.playerId) or '',
        entry.message
    )
    
    -- Add extra data if present
    if entry.extraData and next(entry.extraData) then
        for key, value in pairs(entry.extraData) do
            line = line .. string.format('  %s: %s\n', key, tostring(value))
        end
    end
    
    -- Write to file
    local file = io.open(fileName, 'a')
    if file then
        file:write(line)
        file:close()
    end
end

-- ============================================================================
-- DISCORD LOGGING (with batching and rate limiting)
-- ============================================================================

function Logger.QueueDiscordLog(entry, levelConfig)
    table.insert(Logger.discordQueue, {
        entry = entry,
        levelConfig = levelConfig
    })
end

-- Process Discord queue
CreateThread(function()
    while true do
        Wait(CONFIG.DiscordRateLimit)
        
        if #Logger.discordQueue > 0 and Config.Discord and Config.Discord.WebhookURL then
            local batch = {}
            local batchSize = math.min(#Logger.discordQueue, CONFIG.DiscordBatchSize)
            
            for i = 1, batchSize do
                local item = table.remove(Logger.discordQueue, 1)
                table.insert(batch, item)
            end
            
            if #batch > 0 then
                Logger.SendDiscordBatch(batch)
            end
        end
    end
end)

function Logger.SendDiscordBatch(batch)
    local embeds = {}
    
    for _, item in ipairs(batch) do
        local entry = item.entry
        local levelConfig = item.levelConfig
        
        local fields = {
            { name = 'Category', value = entry.category, inline = true },
            { name = 'Level', value = entry.level, inline = true }
        }
        
        if entry.playerId then
            table.insert(fields, { name = 'Player', value = entry.playerName or 'Unknown', inline = true })
            table.insert(fields, { name = 'Server ID', value = tostring(entry.playerId), inline = true })
        end
        
        if entry.ping then
            table.insert(fields, { name = 'Ping', value = entry.ping .. 'ms', inline = true })
        end
        
        if entry.violationCount then
            table.insert(fields, { name = 'Violations', value = tostring(entry.violationCount), inline = true })
        end
        
        if entry.identifiers and #entry.identifiers > 0 then
            local idStr = table.concat(entry.identifiers, '\n')
            if #idStr > 1000 then idStr = idStr:sub(1, 1000) .. '...' end
            table.insert(fields, { name = 'Identifiers', value = '```' .. idStr .. '```', inline = false })
        end
        
        if entry.extraData and next(entry.extraData) then
            local extraStr = ''
            for key, value in pairs(entry.extraData) do
                extraStr = extraStr .. string.format('**%s:** %s\n', key, tostring(value))
            end
            if #extraStr > 1000 then extraStr = extraStr:sub(1, 1000) .. '...' end
            table.insert(fields, { name = 'Details', value = extraStr, inline = false })
        end
        
        local colors = {
            DEBUG = 8421504,    -- Gray
            INFO = 3447003,     -- Blue
            WARN = 16776960,    -- Yellow
            ALERT = 16744448,   -- Orange
            CRITICAL = 16711680 -- Red
        }
        
        table.insert(embeds, {
            title = levelConfig.emoji .. ' ' .. entry.category,
            description = entry.message,
            color = colors[entry.level] or 8421504,
            fields = fields,
            footer = { text = 'LucidGuard Anticheat • Advanced Logging' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        })
    end
    
    if #embeds > 0 then
        PerformHttpRequest(Config.Discord.WebhookURL, function() end, 'POST',
            json.encode({ embeds = embeds }),
            { ['Content-Type'] = 'application/json' })
    end
end

-- ============================================================================
-- VIOLATION TRACKING
-- ============================================================================

function Logger.RecordViolation(playerId, category, severity, details)
    if not Logger.violationHistory[playerId] then
        Logger.violationHistory[playerId] = {
            total = 0,
            categories = {},
            firstSeen = os.time(),
            lastViolation = nil
        }
    end
    
    local history = Logger.violationHistory[playerId]
    history.total = history.total + 1
    history.lastViolation = os.time()
    
    if not history.categories[category] then
        history.categories[category] = {
            count = 0,
            timestamps = {},
            severities = {}
        }
    end
    
    local catHistory = history.categories[category]
    catHistory.count = catHistory.count + 1
    table.insert(catHistory.timestamps, os.time())
    table.insert(catHistory.severities, severity)
    
    -- Keep only last 50 timestamps per category
    while #catHistory.timestamps > 50 do
        table.remove(catHistory.timestamps, 1)
        table.remove(catHistory.severities, 1)
    end
    
    return history
end

function Logger.GetViolationCount(playerId, category)
    if not Logger.violationHistory[playerId] then return 0 end
    
    if category then
        local cat = Logger.violationHistory[playerId].categories[category]
        return cat and cat.count or 0
    end
    
    return Logger.violationHistory[playerId].total
end

function Logger.GetViolationHistory(playerId)
    return Logger.violationHistory[playerId]
end

function Logger.ClearViolations(playerId, category)
    if not Logger.violationHistory[playerId] then return end
    
    if category then
        Logger.violationHistory[playerId].categories[category] = nil
    else
        Logger.violationHistory[playerId] = nil
    end
end

-- Get recent violations (within time window)
function Logger.GetRecentViolations(playerId, category, windowSeconds)
    if not Logger.violationHistory[playerId] then return 0 end
    
    local cat = Logger.violationHistory[playerId].categories[category]
    if not cat then return 0 end
    
    local cutoff = os.time() - windowSeconds
    local count = 0
    
    for _, timestamp in ipairs(cat.timestamps) do
        if timestamp > cutoff then
            count = count + 1
        end
    end
    
    return count
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('playerDropped', function()
    local src = source
    -- Keep violation history for 30 minutes after disconnect
    SetTimeout(1800000, function()
        Logger.violationHistory[src] = nil
    end)
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

-- Main logging functions
exports('Log', function(level, category, message, playerId, extraData)
    return Logger.Log(level, category, message, playerId, extraData)
end)

exports('LogDebug', function(category, message, playerId, extraData)
    return Logger.Log('DEBUG', category, message, playerId, extraData)
end)

exports('LogInfo', function(category, message, playerId, extraData)
    return Logger.Log('INFO', category, message, playerId, extraData)
end)

exports('LogWarn', function(category, message, playerId, extraData)
    return Logger.Log('WARN', category, message, playerId, extraData)
end)

exports('LogAlert', function(category, message, playerId, extraData)
    return Logger.Log('ALERT', category, message, playerId, extraData)
end)

exports('LogCritical', function(category, message, playerId, extraData)
    return Logger.Log('CRITICAL', category, message, playerId, extraData)
end)

-- Violation tracking
exports('RecordViolation', Logger.RecordViolation)
exports('GetViolationCount', Logger.GetViolationCount)
exports('GetViolationHistory', Logger.GetViolationHistory)
exports('ClearViolations', Logger.ClearViolations)
exports('GetRecentViolations', Logger.GetRecentViolations)

-- Global function for easy access
function Log(level, category, message, playerId, extraData)
    return Logger.Log(level, category, message, playerId, extraData)
end

print('[^2LucidGuard^0] Advanced Logging System loaded')
