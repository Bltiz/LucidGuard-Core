--[[
    LucidGuard Anticheat - Server Main
    Created by OnlyLucidVibes
    Core server-side functionality, ESX integration, and utilities
]]

-- ============================================================================
-- VARIABLES
-- ============================================================================

local ESX = nil
local PlayerData = {} -- Store player session data
local isReady = false

-- Core version - used by Basic/Advanced bridges to verify compatibility
local LG_VERSION = '2.0.0'
local LG_VERSION_MAJOR = 2
local LG_VERSION_MINOR = 0

function GetVersion()
    return LG_VERSION
end

function GetVersionParts()
    return LG_VERSION_MAJOR, LG_VERSION_MINOR
end

-- ============================================================================
-- STARTUP BANNER
-- ============================================================================

local function PrintBanner()
    local p = '^6'  -- purple/magenta
    local c = '^5'  -- cyan
    local y = '^3'  -- yellow
    local w = '^7'  -- white
    local r = '^0'  -- reset

    print('')
    print(p .. '  ╔═══════════════════════════════════════════════════════════════════════════════╗')
    print(p .. '  ║                                                                               ║')
    print(p .. '  ║   ██╗     ██╗   ██╗  ██████╗ ██╗ ██████╗   ██████╗  ██╗   ██╗  █████╗  ██████╗  ██████╗  ║')
    print(p .. '  ║   ██║     ██║   ██║ ██╔════╝ ██║ ██╔══██╗ ██╔════╝  ██║   ██║ ██╔══██╗ ██╔══██╗ ██╔══██╗ ║')
    print(p .. '  ║   ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║  ███╗ ██║   ██║ ███████║ ██████╔╝ ██║  ██║ ║')
    print(p .. '  ║   ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║   ██║ ██║   ██║ ██╔══██║ ██╔══██╗ ██║  ██║ ║')
    print(p .. '  ║   ███████╗╚██████╔╝ ╚██████╗ ██║ ██████╔╝ ╚██████╔╝ ╚██████╔╝ ██║  ██║ ██║  ██║ ██████╔╝ ║')
    print(p .. '  ║   ╚══════╝ ╚═════╝   ╚═════╝ ╚═╝ ╚═════╝   ╚═════╝   ╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═════╝  ║')
    print(p .. '  ║                                                                               ║')
    print(p .. '  ╠═══════════════════════════════════════════════════════════════════════════════╣')
    print(p .. '  ║' .. w .. '                   FiveM Anticheat  |  Version ' .. LG_VERSION .. '                        ' .. p .. '║')
    print(p .. '  ║' .. y .. '                         Created by OnlyLucidVibes                        ' .. p .. '║')
    print(p .. '  ║' .. w .. '              ESX Framework  |  txAdmin Compatible  |  lua54               ' .. p .. '║')
    print(p .. '  ╠═══════════════════════════════════════════════════════════════════════════════╣')
    print(p .. '  ║' .. c .. '         Discord Webhooks  |  DDoS Protection  |  Smart Detection          ' .. p .. '║')
    print(p .. '  ╚═══════════════════════════════════════════════════════════════════════════════╝' .. r)
    print('')
end

-- ============================================================================
-- ESX INITIALIZATION
-- ============================================================================

CreateThread(function()
    -- Print the banner first
    PrintBanner()
    
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        
        -- Modern ESX method
        if ESX == nil then
            pcall(function()
                ESX = exports['es_extended']:getSharedObject()
            end)
        end
        
        Wait(100)
    end
    
    isReady = true
    
    print('^2[LucidGuard]^7 ✓ ESX Framework initialized')
    print('^2[LucidGuard]^7 ✓ Anticheat system loaded successfully')
    print('')
    print('^3[LucidGuard]^7 Active Protection Modules:')
    
    local enabledCount = 0
    local disabledCount = 0
    
    for module, enabled in pairs(Config.Modules) do
        if enabled then
            print('^2[LucidGuard]^7   ✓ ' .. module)
            enabledCount = enabledCount + 1
        else
            disabledCount = disabledCount + 1
        end
    end
    
    print('')
    print('^5[LucidGuard]^7 ═══════════════════════════════════════════════════')
    print('^2[LucidGuard]^7 ' .. enabledCount .. ' modules enabled | ' .. disabledCount .. ' modules disabled')
    print('^5[LucidGuard]^7 ═══════════════════════════════════════════════════')
    print('')
    print('^2[LucidGuard]^7 🛡️  Server is now protected! ^0')
    print('')
end)

-- ============================================================================
-- EXPORTS FOR OTHER SERVER FILES
-- ============================================================================

-- Get ESX object
function GetESX()
    return ESX
end

-- Check if system is ready
function IsSystemReady()
    return isReady and ESX ~= nil
end

-- ============================================================================
-- CONSOLE LOGGING
-- ============================================================================

function Log(level, message)
    if not Config.Console.Enabled then return end
    
    local colors = Config.Console.Colors
    local prefix = Config.Console.Prefix
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local colorCode = colors.White
    
    if level == 'INFO' then
        colorCode = colors.Green
    elseif level == 'WARN' then
        colorCode = colors.Yellow
    elseif level == 'ALERT' then
        colorCode = colors.Red
    elseif level == 'BAN' then
        colorCode = colors.Magenta
    elseif level == 'DEBUG' then
        if not Config.Debug then return end
        colorCode = colors.Cyan
    end
    
    print(string.format('%s%s%s [%s] [%s] %s', 
        colorCode, 
        prefix, 
        colors.Reset,
        timestamp,
        level,
        message
    ))
end

-- Log detection specifically
function LogDetection(severity, playerId, detectionType, details)
    local playerName = GetPlayerName(playerId) or 'Unknown'
    local identifiers = GetAllIdentifiers(playerId)
    
    local colorCode = Config.Severity[severity].ConsoleColor or '^0'
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    
    print(string.format('%s%s^0 [%s] [%s] Player: %s (ID: %s) | Detection: %s | Details: %s',
        colorCode,
        Config.Console.Prefix,
        timestamp,
        severity,
        playerName,
        playerId,
        detectionType,
        details or 'N/A'
    ))
    
    -- Also log identifiers for reference
    if Config.Debug then
        for idType, idValue in pairs(identifiers) do
            print(string.format('  └─ %s: %s', idType, idValue))
        end
    end
end

-- ============================================================================
-- PLAYER DATA MANAGEMENT
-- ============================================================================

-- Initialize player data on join
function InitPlayerData(playerId)
    local identifiers = GetAllIdentifiers(playerId)
    
    PlayerData[playerId] = {
        name = GetPlayerName(playerId),
        identifiers = identifiers,
        tokens = GetAllTokens(playerId),
        joinTime = os.time(),
        lastPosition = nil,
        lastHealth = 200,
        violations = {},
        isAdmin = false,
        heartbeatMissed = 0,
        lastHeartbeat = os.time(),
        economyTracker = {
            moneyAdded = 0,
            bankAdded = 0,
            blackMoneyAdded = 0,
            itemsAdded = 0,
            lastReset = os.time()
        }
    }
    
    -- Check admin status
    CreateThread(function()
        Wait(2000) -- Wait for ESX to load player
        if ESX then
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                local group = xPlayer.getGroup()
                PlayerData[playerId].isAdmin = Config.TableContains(Config.AdminGroups, group)
                
                if PlayerData[playerId].isAdmin then
                    Log('INFO', string.format('Admin detected: %s (%s) - Group: %s', 
                        GetPlayerName(playerId), playerId, group))
                end
            end
        end
    end)
    
    return PlayerData[playerId]
end

-- Get player data
function GetPlayerData(playerId)
    return PlayerData[playerId]
end

-- Update player data
function UpdatePlayerData(playerId, key, value)
    if PlayerData[playerId] then
        PlayerData[playerId][key] = value
    end
end

-- Remove player data on disconnect
function RemovePlayerData(playerId)
    PlayerData[playerId] = nil
end

-- ============================================================================
-- ADMIN CHECK
-- ============================================================================

function IsPlayerAdmin(playerId)
    -- Check cached data first
    if PlayerData[playerId] and PlayerData[playerId].isAdmin then
        return true
    end
    
    -- Fallback to ESX check
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            local group = xPlayer.getGroup()
            return Config.TableContains(Config.AdminGroups, group)
        end
    end
    
    return false
end

-- ============================================================================
-- IDENTIFIER HELPERS
-- ============================================================================

function GetAllIdentifiers(playerId)
    local identifiers = {
        steam = nil,
        license = nil,
        license2 = nil,
        discord = nil,
        xbl = nil,
        live = nil,
        fivem = nil,
        ip = nil
    }
    
    local numIds = GetNumPlayerIdentifiers(playerId)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(playerId, i)
        if id then
            if string.find(id, 'steam:') then
                identifiers.steam = id
            elseif string.find(id, 'license2:') then
                identifiers.license2 = id
            elseif string.find(id, 'license:') then
                identifiers.license = id
            elseif string.find(id, 'discord:') then
                identifiers.discord = id
            elseif string.find(id, 'xbl:') then
                identifiers.xbl = id
            elseif string.find(id, 'live:') then
                identifiers.live = id
            elseif string.find(id, 'fivem:') then
                identifiers.fivem = id
            elseif string.find(id, 'ip:') then
                identifiers.ip = id
            end
        end
    end
    
    return identifiers
end

function GetAllTokens(playerId)
    local tokens = {}
    local numTokens = GetNumPlayerTokens(playerId)
    
    for i = 0, numTokens - 1 do
        local token = GetPlayerToken(playerId, i)
        if token then
            table.insert(tokens, token)
        end
    end
    
    return tokens
end

-- Get specific identifier
function GetIdentifier(playerId, idType)
    local identifiers = GetAllIdentifiers(playerId)
    return identifiers[idType]
end

-- ============================================================================
-- VIOLATION TRACKING
-- ============================================================================

function AddViolation(playerId, detectionType)
    if not PlayerData[playerId] then return 0 end
    
    if not PlayerData[playerId].violations[detectionType] then
        PlayerData[playerId].violations[detectionType] = {
            count = 0,
            firstViolation = os.time(),
            lastViolation = os.time()
        }
    end
    
    local violation = PlayerData[playerId].violations[detectionType]
    violation.count = violation.count + 1
    violation.lastViolation = os.time()
    
    return violation.count
end

function GetViolationCount(playerId, detectionType)
    if not PlayerData[playerId] then return 0 end
    if not PlayerData[playerId].violations[detectionType] then return 0 end
    
    return PlayerData[playerId].violations[detectionType].count
end

function ResetViolations(playerId, detectionType)
    if not PlayerData[playerId] then return end
    
    if detectionType then
        PlayerData[playerId].violations[detectionType] = nil
    else
        PlayerData[playerId].violations = {}
    end
end

-- ============================================================================
-- COORDINATE HELPERS
-- ============================================================================

function GetDistance(pos1, pos2)
    if not pos1 or not pos2 then return 0 end
    
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function FormatCoords(coords)
    if not coords then return 'N/A' end
    return string.format('%.2f, %.2f, %.2f', coords.x or 0, coords.y or 0, coords.z or 0)
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Player joined
AddEventHandler('playerJoining', function()
    local playerId = source
    InitPlayerData(playerId)
    Log('INFO', string.format('Player joining: %s (ID: %s)', GetPlayerName(playerId), playerId))
end)

-- Player dropped
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    Log('INFO', string.format('Player dropped: %s (ID: %s) - Reason: %s', 
        GetPlayerName(playerId) or 'Unknown', playerId, reason))
    RemovePlayerData(playerId)
end)

-- ESX player loaded
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if not playerId then playerId = source end
    
    -- Update admin status
    if PlayerData[playerId] and xPlayer then
        local group = xPlayer.getGroup()
        PlayerData[playerId].isAdmin = Config.TableContains(Config.AdminGroups, group)
    end
end)

-- ============================================================================
-- RECEIVE CLIENT DETECTIONS
-- ============================================================================

RegisterNetEvent('xx_ac:detection')
AddEventHandler('xx_ac:detection', function(detectionType, severity, details)
    local playerId = source
    
    -- Validate source
    if not playerId or playerId <= 0 then return end
    
    -- Admin immunity
    if IsPlayerAdmin(playerId) then return end
    
    -- Process detection
    ProcessDetection(playerId, detectionType, severity, details)
end)

-- Process detection (called from various modules)
function ProcessDetection(playerId, detectionType, severity, details)
    -- ========================================================================
    -- FALSE POSITIVE PREVENTION (state-aware validation)
    -- ========================================================================

    if Config.FalsePositive and Config.FalsePositive.Enabled and FalsePositive then
        local isValid, reasons = FalsePositive.ValidateDetection(playerId, detectionType)
        if not isValid then
            if Config.Debug then
                Log('DEBUG', string.format('[FP] Blocked %s for %s: %s',
                    detectionType, GetPlayerName(playerId) or playerId,
                    table.concat(reasons, ', ')))
            end
            return  -- False positive, don't process
        end
    end

    -- ========================================================================
    -- SMART DETECTION FILTER (AI-Like False Positive Prevention)
    -- ========================================================================
    
    if Config.SmartDetection and Config.SmartDetection.Enabled and SmartDetection then
        local shouldProceed, decisionInfo = SmartDetection.ProcessDetection(playerId, detectionType, severity, details)
        
        if not shouldProceed then
            -- Smart Detection blocked this - likely false positive
            if Config.Debug then
                local reason = type(decisionInfo) == 'table' and decisionInfo.reason or table.concat(decisionInfo or {'unknown'}, ', ')
                Log('DEBUG', string.format('[SMART] Blocked %s for player %s: %s', 
                    detectionType, GetPlayerName(playerId) or playerId, reason))
            end
            return  -- Don't process further
        end
        
        -- Smart Detection approved - check what action to take
        if type(decisionInfo) == 'table' then
            if decisionInfo.action == 'LOG' then
                -- Just log, don't punish
                LogDetection(severity, playerId, detectionType, details)
                return
            elseif decisionInfo.action == 'FLAG' then
                -- Flag for review only (send to Discord but don't kick)
                LogDetection(severity, playerId, detectionType, details)
                if Config.Discord.Enabled then
                    SendDiscordDetection(playerId, detectionType, 'LOW', 
                        string.format('[FLAGGED FOR REVIEW] %s | Confidence: %.1f%%', 
                            details, decisionInfo.confidence or 0))
                end
                return
            end
            -- If action is KICK or BAN, continue to normal processing below
        end
    end
    
    -- ========================================================================
    -- STANDARD DETECTION PROCESSING
    -- ========================================================================

    -- Log to console
    LogDetection(severity, playerId, detectionType, details)

    -- Send to Discord
    if Config.Discord.Enabled then
        SendDiscordDetection(playerId, detectionType, severity, details)
    end

    -- Route through ViolationManager threshold system instead of instant punishment.
    -- This ensures multiple violations are required before any kick/ban action,
    -- preventing innocent players from being removed on a single detection.
    if ViolationManager and ViolationManager.RecordViolation then
        local detailsTable = type(details) == 'table' and details or { reason = details or 'No details' }
        local thresholdReached, count, threshold, action = ViolationManager.RecordViolation(
            playerId, detectionType, detailsTable, severity
        )

        if action ~= 'COOLDOWN' and thresholdReached then
            ViolationManager.TakeAction(playerId, detectionType, action, {
                count = count,
                threshold = threshold,
                details = detailsTable,
                severity = severity
            })
        end
    else
        -- Fallback if ViolationManager not loaded yet
        ExecutePunishment(playerId, severity, detectionType, details)
    end
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetESX', GetESX)
exports('IsSystemReady', IsSystemReady)
exports('IsPlayerAdmin', IsPlayerAdmin)
exports('GetPlayerData', GetPlayerData)
exports('GetAllIdentifiers', GetAllIdentifiers)
exports('GetAllTokens', GetAllTokens)
exports('AddViolation', AddViolation)
exports('GetViolationCount', GetViolationCount)
exports('ProcessDetection', ProcessDetection)
exports('Log', Log)
exports('LogDetection', LogDetection)
exports('GetVersion', GetVersion)
exports('GetVersionParts', GetVersionParts)
