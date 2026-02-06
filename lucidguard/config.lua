--[[
    ██╗     ██╗   ██╗  ██████╗ ██╗ ██████╗   ██████╗  ██╗   ██╗  █████╗  ██████╗  ██████╗
    ██║     ██║   ██║ ██╔════╝ ██║ ██╔══██╗ ██╔════╝  ██║   ██║ ██╔══██╗ ██╔══██╗ ██╔══██╗
    ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║  ███╗ ██║   ██║ ███████║ ██████╔╝ ██║  ██║
    ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║   ██║ ██║   ██║ ██╔══██║ ██╔══██╗ ██║  ██║
    ███████╗╚██████╔╝ ╚██████╗ ██║ ██████╔╝ ╚██████╔╝ ╚██████╔╝ ██║  ██║ ██║  ██║ ██████╔╝
    ╚══════╝ ╚═════╝   ╚═════╝ ╚═╝ ╚═════╝   ╚═════╝   ╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═════╝

    Configuration (FREE Tier) | Created by OnlyLucidVibes
    Customize all settings below to match your server's needs
]]

Config = {}

-- ============================================================================
-- GENERAL SETTINGS
-- ============================================================================

Config.Debug = false -- Enable debug prints (disable in production)
Config.ResourceName = 'lucidguard' -- Name of this resource

-- ============================================================================
-- DISCORD WEBHOOK SETTINGS
-- ============================================================================

Config.Discord = {
    Enabled = true,
    -- Load webhook from environment variable for security
    -- Set via server.cfg: set discord_webhook 'https://discord.com/api/webhooks/YOUR_WEBHOOK_URL'
    WebhookURL = GetConvar('discord_webhook') ~= '' and GetConvar('discord_webhook') or '',
    BotName = 'LucidGuard Anticheat',
    BotAvatar = 'https://i.imgur.com/iq5dSYr.png', -- Custom avatar URL

    -- Webhook rate limiting (Discord allows 30/min)
    RateLimit = {
        MaxPerMinute = 25, -- Stay under Discord limit
        QueueEnabled = true
    },

    -- Color codes for embed severity (decimal format)
    Colors = {
        LOW = 16776960,      -- Yellow
        MEDIUM = 16744448,   -- Orange
        HIGH = 16729344,     -- Red-Orange
        CRITICAL = 16711680, -- Red
        INFO = 3447003,      -- Blue
        VPN = 10181046       -- Purple (VPN detection)
    }
}

-- ============================================================================
-- ADMIN IMMUNITY SETTINGS
-- ============================================================================

Config.AdminGroups = {
    'admin',
    'superadmin',
    'mod',
    'moderator',
    'owner'
}

-- Full admin immunity - admins bypass ALL detection systems including:
-- Economy monitoring, rate limits, chat analysis, item checks, etc.
-- SECURITY FIX: Disabled to enable admin action auditing via AdminMonitoring module
Config.AdminFullImmunity = false

-- ============================================================================
-- DETECTION MODULES (Enable/Disable) - FREE Tier
-- ============================================================================

Config.Modules = {
    Heartbeat = true,
    ConnectionScreening = true,
    RateLimiting = true,
    VPNDetection = true,
    EntityLockdown = true,
    ExplosionMonitoring = true,
    ClientIntegrity = true,
    FingerprintBanning = true,
    BurstFilter = true,
    VectorValidation = true,
    JunkEvents = true,
    ResourceScanner = true
}

-- ============================================================================
-- RESOURCE SCANNER (Cheat Menu Detection)
-- ============================================================================

Config.ResourceScanner = {
    -- Scan interval
    ScanOnSpawn = true,
    PeriodicScanInterval = 300000, -- Scan every 5 minutes

    -- Blacklisted resource names (case-insensitive partial matches)
    BlacklistedResources = {
        -- ==========================
        -- GTA V / FiveM MOD MENUS
        -- ==========================
        'eulen', 'cherax', 'stand', '2take1', 'kiddion', 'modest',
        'redengine', 'impulse', 'paragon', 'ozark', 'phantom-x',
        'luna', 'disturbed', 'kingpin', 'terror', 'position',
        'nightfall', 'fragment', 'skid', 'hausen', 'brutan',
        'desudo', 'ellusive', 'rebound', 'overdrive', 'subversive',
        'midnight', 'aether', 'astro', 'celestial', 'comet',
        'delusion', 'fatality', 'helix', 'hydra', 'illusion',
        'quantum', 'raven', 'spectral', 'tempest', 'vendetta',
        'kitsune', 'lynx', 'nero_menu', 'nexus_menu', 'orbit',
        'predator', 'requiem', 'spooky', 'storm', 'toxic',
        'void_menu', 'zenith', 'riptide', 'hammafia', 'dopamine',
        'los_pollos', 'lospollos', 'cipher_menu', 'havoc', 'omega',
        'sigma_menu', 'ares_menu', 'artemis', 'atlas_cheat',
        'chronos', 'cosmos', 'prism_menu', 'solaris', 'titan_menu',
        'vortex_menu', 'xcheats', 'scarlet', 'eternity',

        -- ==========================
        -- FIVEM-SPECIFIC CHEATS
        -- ==========================
        'fivemhax', 'fivem_cheat', 'fivem_hack', 'fivem_mod',
        'fivem_trainer', 'fivem_menu', 'fivemenu', 'fiveguard',
        'five_menu', 'five_hack', 'five_cheat',
        'ixcheats', 'ix-cheats', 'ix_cheats',
        'darkstar', 'lambda_exec', 'raw_exec', 'bald_exec',
        'serial_exec', 'nexon_exec', 'resurrected',

        -- ==========================
        -- LUA EXECUTORS / INJECTORS
        -- ==========================
        'executor', 'injector', 'loader', 'bypass',
        'lua_exec', 'luaexec', 'lua_inject', 'luainject',
        'lua_loader', 'lualoader', 'lua_bypass', 'luabypass',
        'script_hook', 'scripthook', 'script_inject',
        'dll_inject', 'dllinject', 'code_inject',
        'extreme_injector', 'xenos_injector',

        -- ==========================
        -- GENERIC SUSPICIOUS NAMES
        -- ==========================
        'cheat', 'hack', 'mod_menu', 'modmenu', 'trainer',
        'godmode', 'money_drop', 'moneydrop', 'aimbot',
        'wallhack', 'esp_hack', 'triggerbot', 'speedhack',
        'noclip_menu', 'noclip_hack', 'fly_hack', 'flyhack',
        'teleport_hack', 'tphack', 'infinite_ammo', 'inf_ammo',
        'crasher', 'booter', 'spoofer', 'hwid_spoof',
        'unbanner', 'unban_tool', 'ban_bypass', 'anti_ban',
        'antiban', 'anti_kick', 'antikick',
        'money_hack', 'moneyhack', 'cash_drop', 'cashdrop',
        'weapon_spawn', 'weaponspawn', 'weapon_hack',
        'vehicle_spawn', 'veh_spawn', 'car_spawn',
        'admin_hack', 'adminhack', 'admin_abuse',
        'invisible_hack', 'invis_hack', 'ghost_mode',
        'rage_hack', 'ragehack', 'rage_menu',
        'recovery', 'recovery_tool', 'money_recovery',
        'debugger_menu', 'debug_exploit',
        'exploit', 'exploiter', 'exploit_menu',
    },

    -- Whitelist known legitimate resources with similar names
    WhitelistedResources = {
        'es_extended', 'esx_', 'qb-', 'ox_', 'screenshot-basic',
        -- Whitelist anticheat resources to prevent false positives
        'anticheat', 'lucidguard', 'xx_ac', 'ac_', '_ac'
    }
}

-- ============================================================================
-- HEARTBEAT SYSTEM
-- ============================================================================

Config.Heartbeat = {
    Interval = 30000,            -- Client sends heartbeat every 30 seconds
    MaxMissedBeats = 4,          -- 4 missed = 2 minutes without response
    Enabled = true
}

-- ============================================================================
-- CONNECTION SCREENING
-- ============================================================================

Config.Connection = {
    -- Ban evasion detection via hardware tokens
    CheckHardwareTokens = true,

    -- VPN/Proxy detection
    VPNDetection = {
        Enabled = true,
        -- Using ip-api.com (free, 45 requests/min)
        APIURL = 'http://ip-api.com/json/{ip}?fields=status,proxy,hosting',
        FlagOnly = true,  -- Just flag, don't block (as requested)
        CacheResults = true,
        CacheDuration = 3600, -- Cache for 1 hour
        -- Database persistence (NEW v1.4.1)
        -- Caches VPN results in database to prevent rate-limit issues
        DatabaseCache = {
            Enabled = true,
            TableName = 'anticheat_vpn_cache',
            CacheExpiry = 3600  -- Expire DB records after 1 hour
        }
    }
}

-- ============================================================================
-- RATE LIMITING / DDOS PROTECTION
-- ============================================================================

Config.RateLimit = {
    -- Default rate limit for all events
    DefaultLimit = {
        MaxCalls = 15,
        WindowMs = 1000  -- 15 calls per second
    },

    -- Specific event limits
    EventLimits = {
        -- Economy events (stricter)
        ['esx:giveInventoryItem'] = { MaxCalls = 3, WindowMs = 5000 },
        ['esx:removeInventoryItem'] = { MaxCalls = 5, WindowMs = 5000 },
        ['esx_society:withdrawMoney'] = { MaxCalls = 2, WindowMs = 10000 },
        ['esx_society:depositMoney'] = { MaxCalls = 2, WindowMs = 10000 },

        -- Anticheat events
        ['xx_ac:heartbeat'] = { MaxCalls = 2, WindowMs = 25000 },
        ['xx_ac:report'] = { MaxCalls = 5, WindowMs = 10000 }
    },

    -- Connection rate limiting
    ConnectionSpamThreshold = 5, -- Max reconnects in window
    ConnectionSpamWindow = 60000 -- 1 minute window
}

-- ============================================================================
-- PUNISHMENT SEVERITY LEVELS
-- NOTE: All actions are kicks, not bans. Admins should review via Discord/txAdmin
-- ============================================================================

Config.Severity = {
    LOW = {
        Action = 'log',          -- Just log and notify Discord
        ConsoleColor = '^3',     -- Yellow
        DiscordColor = 'LOW'
    },
    MEDIUM = {
        Action = 'log',          -- Changed to LOG only - let admins review (was 'kick')
        ConsoleColor = '^3',     -- Yellow
        DiscordColor = 'MEDIUM',
        KickMessage = 'You have been flagged by the anticheat. An admin will review.'
    },
    HIGH = {
        Action = 'kick',         -- Kick but admin should review before ban
        ConsoleColor = '^1',     -- Red
        DiscordColor = 'HIGH',
        KickMessage = 'You have been kicked for suspicious activity. Contact an admin if this is an error.',
        RecommendedBan = 'Admin review required'
    },
    CRITICAL = {
        Action = 'kick',         -- Still kick but requires admin review for ban
        ConsoleColor = '^1',
        DiscordColor = 'CRITICAL',
        KickMessage = 'You have been kicked for suspicious activity. Appeal via Discord if this is an error.',
        RecommendedBan = 'Admin review required - possible permanent'
    }
}

-- ============================================================================
-- CONSOLE LOGGING
-- ============================================================================

Config.Console = {
    Enabled = true,
    Prefix = '[LucidGuard]',

    -- Color codes
    Colors = {
        Reset = '^0',
        Red = '^1',
        Green = '^2',
        Yellow = '^3',
        Blue = '^4',
        Cyan = '^5',
        Magenta = '^6',
        White = '^7'
    }
}

-- ============================================================================
-- ENTITY LOCKDOWN (Server-Side Entity Protection)
-- ============================================================================

Config.EntityLockdown = {
    -- Mass entity spawn protection (Nuke detection)
    NukeProtection = {
        Enabled = true,
        MaxEntitiesPerSecond = 20,   -- Max entities one player can spawn in 1 second
        MaxEntitiesPerMinute = 100,  -- Max entities one player can spawn in 1 minute
        BanOnNuke = true             -- Instant ban if nuke detected
    },

    -- Allowed entity spawners (by job)
    AllowedSpawners = {
        ['mechanic'] = { 'vehicles' },
        ['police'] = { 'vehicles', 'peds' },
        ['ambulance'] = { 'vehicles', 'peds' },
        ['cardealer'] = { 'vehicles' }
    },

    -- Blacklisted entity models (always block these)
    BlacklistedModels = {
        -- Add model hashes of props/vehicles that shouldn't be spawned
        -- Example: `prop_gold_bar` = true
    },

    -- Whitelisted resources that can spawn entities
    WhitelistedResources = {
        'es_extended', 'esx_', 'qb-', 'spawnmanager', 'mapmanager'
    }
}

-- ============================================================================
-- ENTITY LOCKDOWN (Routing Bucket Mode)
-- ============================================================================

Config.EntityLockdown = Config.EntityLockdown or {}
Config.EntityLockdown.RoutingBucketMode = 'strict'  -- 'strict' or 'relaxed'
Config.EntityLockdown.AdditionalBuckets = {}  -- Additional bucket IDs to lock down

-- ============================================================================
-- EXPLOSION MONITORING
-- ============================================================================

Config.ExplosionMonitoring = {
    Enabled = true,

    -- Explosions that require specific conditions
    RestrictedExplosions = {
        -- ExplosionType = { requireVehicle = bool, allowedWeapons = {}, severity = 'HIGH'/'CRITICAL' }
        [2] = { name = 'GRENADE', requireWeapon = true, severity = 'HIGH' },
        [4] = { name = 'MOLOTOV', requireWeapon = true, severity = 'HIGH' },
        [5] = { name = 'GAS_CANISTER', severity = 'MEDIUM' },
        [6] = { name = 'TANKER', requireVehicle = true, severity = 'HIGH' },
        [7] = { name = 'PROPANE', severity = 'MEDIUM' },
        [8] = { name = 'PLANE', requireVehicle = true, severity = 'HIGH' },
        [10] = { name = 'VEHICLE', requireVehicle = true, severity = 'MEDIUM' },
        [14] = { name = 'BOAT', requireVehicle = true, severity = 'HIGH' },
        [16] = { name = 'BULLET', severity = 'LOW' },
        [17] = { name = 'SMOKEGRENADELAUNCHER', requireWeapon = true, severity = 'MEDIUM' },
        [18] = { name = 'SMOKEGRENADE', requireWeapon = true, severity = 'MEDIUM' },
        [19] = { name = 'BZGAS', requireWeapon = true, severity = 'HIGH' },
        [20] = { name = 'FLARE', requireWeapon = true, severity = 'MEDIUM' },
        [21] = { name = 'GAS_CANISTER2', severity = 'MEDIUM' },
        [25] = { name = 'PROGRAMMABLEAR', severity = 'CRITICAL' },
        [26] = { name = 'TRAIN', requireVehicle = true, severity = 'CRITICAL' },
        [27] = { name = 'BARREL', severity = 'MEDIUM' },
        [29] = { name = 'DIR_FLAME', severity = 'HIGH' },
        [30] = { name = 'TANKER2', requireVehicle = true, severity = 'CRITICAL' },
        [31] = { name = 'BLIMP', requireVehicle = true, severity = 'CRITICAL' },
        [32] = { name = 'DIR_FLAME_EXPLODE', severity = 'HIGH' },
        [33] = { name = 'TANKER_UNKNOWN', requireVehicle = true, severity = 'CRITICAL' },
        [34] = { name = 'PLANE_ROCKET', requireVehicle = true, severity = 'CRITICAL' },
        [35] = { name = 'VEHICLE_BULLET', requireVehicle = true, severity = 'HIGH' },
        [36] = { name = 'GAS_TANK', severity = 'MEDIUM' },
        [38] = { name = 'EXTINGUISHER', severity = 'LOW' },
        [47] = { name = 'DVORE', severity = 'CRITICAL' },
        [50] = { name = 'ORBITAL_CANNON', severity = 'CRITICAL' },
    },

    -- Max explosions per player per minute
    MaxExplosionsPerMinute = 15,

    -- Instant ban explosion types (never allowed from players)
    InstantBanExplosions = { 47, 50 }  -- DVORE, ORBITAL_CANNON
}

-- ============================================================================
-- CLIENT INTEGRITY (Honey Pots & Resource Verification)
-- ============================================================================

Config.ClientIntegrity = {
    -- Honey Pot Variables
    HoneyPots = {
        Enabled = true,
        Variables = {
            -- These variables are traps - if changed, it's a cheat
            'Config.AdminMenu',
            'Config.GodModeEnabled',
            'Config.MoneyHack',
            'Config.InfiniteAmmo',
            'Config.NoClipEnabled'
        }
    },

    -- Resource Count Verification
    ResourceVerification = {
        Enabled = true,
        CheckInterval = 60000,  -- Check every minute
        -- If client has more resources than server expects = ghost resource injected
        ToleranceCount = 0       -- 0 = must match exactly
    }
}

-- ============================================================================
-- FINGERPRINT BANNING (Combined Identifier Hash)
-- ============================================================================

Config.FingerprintBanning = {
    Enabled = true,

    -- Identifiers to include in fingerprint
    IncludeIdentifiers = {
        'steam',
        'license',
        'license2',
        'discord',
        'fivem',
        'ip'
    },

    -- Include hardware tokens in fingerprint
    IncludeHardwareTokens = true,
    MaxTokensToInclude = 3,  -- First 3 hardware tokens

    -- Store fingerprint hash for ban checks
    HashAlgorithm = 'combined'  -- Combines all identifiers into unique hash
}

-- ============================================================================
-- BURST FILTER (Token Bucket Rate Limiting)
-- ============================================================================

Config.BurstFilter = {
    Enabled = true,

    -- Default limit for unlisted events
    DefaultLimit = {
        maxTokens = 10,           -- Max burst capacity
        refillRate = 1,           -- Tokens per second
        maxBurstPerSecond = 10    -- Max triggers per second
    },

    -- Specific event limits
    EventLimits = {
        ['esx:giveInventoryItem'] = {
            maxTokens = 5,
            refillRate = 0.5,     -- 1 token every 2 seconds
            maxBurstPerSecond = 3
        },
        ['esx:useItem'] = {
            maxTokens = 10,
            refillRate = 2,
            maxBurstPerSecond = 5
        },
        ['esx_shops:buy'] = {
            maxTokens = 5,
            refillRate = 0.5,
            maxBurstPerSecond = 3
        },
        ['esx_weaponshop:buyWeapon'] = {
            maxTokens = 3,
            refillRate = 0.2,     -- Very slow refill
            maxBurstPerSecond = 2
        },
        ['esx_garage:spawnVehicle'] = {
            maxTokens = 3,
            refillRate = 0.1,
            maxBurstPerSecond = 1
        },
        ['esx_banking:withdraw'] = {
            maxTokens = 5,
            refillRate = 0.5,
            maxBurstPerSecond = 2
        },
        ['esx_banking:transfer'] = {
            maxTokens = 3,
            refillRate = 0.2,
            maxBurstPerSecond = 1
        }
    }
}

-- ============================================================================
-- VECTOR VALIDATION (Raycast Noclip Detection)
-- ============================================================================

Config.VectorValidation = {
    Enabled = true,

    -- Maximum Z-axis change on foot without vehicle/elevator
    MaxZChangeOnFoot = 15.0,      -- meters

    -- Minimum distance to trigger raycast check
    MinDistanceForRaycast = 3.0,  -- meters

    -- Violations before flagging
    ViolationsBeforeFlag = 3,
    WallClipThreshold = 2,        -- Wall clips before alert (very suspicious)

    -- Custom elevator locations (add your server's elevators)
    ElevatorLocations = {
        -- Format: {x, y, z, radius}
        -- Maze Bank
        {x = -75.0, y = -827.0, z = 243.0, radius = 10.0},
        {x = -75.0, y = -827.0, z = 37.0, radius = 10.0},
        -- Add more...
    }
}

-- ============================================================================
-- JUNK EVENTS (Trap Events for Event Dumpers)
-- ============================================================================

Config.JunkEvents = {
    Enabled = true,

    -- Action when trap triggered
    InstantBan = true,            -- Trap events = guaranteed cheater

    -- Track unknown event calls
    TrackUnknownEvents = true,
    UnknownEventThreshold = 5,    -- Flag after X calls to unknown event

    -- Suspicious event patterns
    SuspiciousPatterns = {
        'money', 'cash', 'weapon', 'spawn', 'god', 'admin', 'cheat', 'hack',
        'give', 'add', 'set', 'teleport', 'noclip', 'invisible', 'ban'
    }
}

-- ============================================================================
-- SMART DETECTION SYSTEM (AI-Like False Positive Prevention)
-- ============================================================================

Config.SmartDetection = {
    Enabled = true,                    -- Enable intelligent detection system

    -- Trust System
    TrustEnabled = true,               -- Build trust over time for clean players
    InitialTrustScore = 100,           -- Starting trust (0-200 scale)
    TrustGainPerMinute = 0.5,          -- Trust gained per clean minute
    MaxTrustScore = 200,               -- Maximum trust score

    -- Confidence Requirements (higher = fewer false positives)
    BaseConfidenceRequired = 75,       -- Base confidence needed to take action
    VeteranConfidenceBonus = 20,       -- Extra confidence needed for veteran players
    TrustedConfidenceBonus = 15,       -- Extra confidence needed for trusted players

    -- Grace Periods
    JoinGracePeriod = 120,             -- Seconds after joining with no detection
    RespawnGracePeriod = 10,           -- Seconds after respawn with no detection
    TeleportGracePeriod = 5,           -- Seconds after legit teleport with no detection

    -- Multi-Detection Requirement
    RequireMultipleTypes = true,       -- Require 2+ different detection types before action
    MinUniqueDetections = 2,           -- Minimum unique detection types for action

    -- Ping Tolerance
    HighPingThreshold = 250,           -- Ping above this reduces confidence
    ExtremePingThreshold = 500,        -- Ping above this ignores detection entirely

    -- Action Thresholds
    FlagConfidence = 60,               -- Confidence to flag for review (no kick)
    KickConfidence = 85,               -- Confidence to kick
    BanConfidence = 95                 -- Confidence to ban (only critical detections)
}

-- ============================================================================
-- LOGGING SYSTEM
-- ============================================================================

Config.Logging = {
    Enabled = true,

    -- Minimum log level: DEBUG, INFO, WARN, ALERT, CRITICAL
    MinLevel = 'INFO',

    -- Console logging
    ConsoleEnabled = true,
    ConsoleColors = true,           -- Use colored console output

    -- File logging
    FileEnabled = true,
    FilePath = 'logs/',             -- Relative to resource folder
    MaxFileSize = 5242880,          -- 5MB per log file
    MaxFiles = 10,                  -- Keep last 10 log files

    -- Discord logging
    DiscordEnabled = true,
    DiscordMinLevel = 'WARN',       -- Minimum level for Discord
    DiscordRateLimit = 2000,        -- 2 seconds between Discord messages
    DiscordBatchSize = 5,           -- Batch up to 5 logs per message

    -- Include extra context in logs
    IncludeIdentifiers = true,      -- Steam, license, etc.
    IncludePosition = true,         -- Player coordinates
    IncludePing = true,             -- Player latency
    IncludeViolationHistory = true  -- Past violations count
}

-- ============================================================================
-- FALSE POSITIVE PREVENTION
-- ============================================================================

Config.FalsePositive = {
    Enabled = true,

    -- State cooldowns (ms) - immunity after certain events
    Cooldowns = {
        SPAWNING = 10000,           -- 10s after spawn/respawn
        LOADING = 15000,            -- 15s after loading
        TELEPORTING = 5000,         -- 5s after teleport
        VEHICLE_ENTER = 3000,       -- 3s after entering/exiting vehicle
        CUTSCENE = 5000,            -- 5s after cutscene
        PAUSED = 2000,              -- 2s after unpausing
        DEAD = 10000,               -- 10s after death
        FALLING = 2000,             -- 2s after landing
        SWIMMING = 2000,            -- 2s after exiting water
        RAGDOLL = 3000,             -- 3s after ragdoll ends
        MISSION = 5000,             -- 5s after mission activity
        INTERIOR = 5000,            -- 5s after interior transition
        VEHICLE_SEAT_CHANGE = 3000  -- 3s after changing seats in vehicle
    },

    -- Ping-based tolerance multipliers
    PingTolerance = {
        [50] = 1.0,                 -- <50ms = normal tolerance
        [100] = 1.2,                -- <100ms = 20% extra
        [150] = 1.4,                -- <150ms = 40% extra
        [200] = 1.6,                -- <200ms = 60% extra
        [300] = 1.8,                -- <300ms = 80% extra
        [999] = 2.0                 -- >300ms = double tolerance
    }
}

-- ============================================================================
-- VIOLATION THRESHOLDS (Override defaults per detection type)
-- ============================================================================

Config.ViolationThresholds = {
    -- Format: { violations = count, window = ms, action = 'KICK'/'BAN'/'FLAG'/'WARN', cooldown = ms }

    -- Movement
    SPEED = { violations = 5, window = 60000, action = 'KICK', cooldown = 5000 },
    TELEPORT = { violations = 3, window = 60000, action = 'KICK', cooldown = 10000 },
    NOCLIP = { violations = 4, window = 60000, action = 'KICK', cooldown = 5000 },

    -- Combat
    GODMODE = { violations = 3, window = 60000, action = 'BAN', cooldown = 10000 },
    AIMBOT = { violations = 5, window = 120000, action = 'BAN', cooldown = 5000 },

    -- Weapons
    WEAPON_SPAWN = { violations = 2, window = 60000, action = 'KICK', cooldown = 10000 },
    WEAPON_BLACKLIST = { violations = 1, window = 60000, action = 'KICK', cooldown = 30000 },

    -- Integrity
    FILE_TAMPERING = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 },
    RESOURCE_INJECT = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 },

    -- Network
    STATE_BAG_HACK = { violations = 2, window = 60000, action = 'BAN', cooldown = 30000 },
    LAG_SWITCH = { violations = 5, window = 120000, action = 'KICK', cooldown = 10000 },

    -- Economy
    MONEY_EXPLOIT = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 },
    GHOST_FARMING = { violations = 3, window = 120000, action = 'KICK', cooldown = 30000 },

    -- Honeypots (instant action)
    MENU_TRAP = { violations = 1, window = 60000, action = 'BAN', cooldown = 60000 }
}

-- ============================================================================
-- PLAYER SAFETY CONFIGURATION (v1.3.2)
-- ============================================================================

Config.PlayerSafety = {
    -- SAFE MODE - START WITH THIS ENABLED!
    -- When SafeMode is enabled, detections are LOGGED but NO ONE is banned
    -- This lets you review detections before enabling auto-bans
    SafeMode = {
        Enabled = true,             -- SET TO FALSE ONLY AFTER REVIEWING LOGS
        DurationHours = 72,         -- Keep safe mode on for 72 hours minimum
        LogOnly = true,             -- Only log, don't kick/ban
        NotifyDiscord = true,       -- Send alerts to Discord for review
        ShowConsoleWarnings = true  -- Show "[SAFE MODE]" in console
    },

    -- Minimum violations before ANY action (extra safety layer)
    MinimumViolations = {
        SPEED = 10,                 -- Very common false positive
        TELEPORT = 5,               -- Moderately common
        NOCLIP = 8,                 -- Common with interiors
        AIMBOT = 10,                -- Good players can trigger this
        GODMODE = 5,                -- Spawn invincibility exists
        LAG_SWITCH = 8,             -- Bad internet exists!
        WEAPON_BLACKLIST = 3,       -- Should be accurate
        FILE_TAMPERING = 999,       -- MANUAL REVIEW ONLY
        RESOURCE_INJECT = 999,      -- MANUAL REVIEW ONLY
        MENU_TRAP = 999,            -- MANUAL REVIEW ONLY
        STATE_BAG_HACK = 999        -- MANUAL REVIEW ONLY
    },

    -- Time windows - violations must occur within these windows to count
    -- Longer windows = safer but slower to catch real cheaters
    ViolationWindows = {
        SPEED = 120000,             -- 2 minutes
        TELEPORT = 180000,          -- 3 minutes
        GODMODE = 180000,           -- 3 minutes
        NOCLIP = 120000,            -- 2 minutes
        AIMBOT = 300000,            -- 5 minutes (skilled players have streaks)
        LAG_SWITCH = 300000,        -- 5 minutes
        DEFAULT = 120000            -- 2 minutes default
    },

    -- Safety multipliers - make thresholds more lenient
    SafetyMultipliers = {
        SPEED = 1.5,                -- 50% extra tolerance
        TELEPORT = 2.0,             -- 100% extra tolerance
        GODMODE = 1.5,              -- 50% extra tolerance
        NOCLIP = 2.0,               -- 100% extra tolerance
        AIMBOT = 2.0,               -- 100% extra (good players exist!)
        DAMAGE = 1.5,               -- 50% extra
        LAG_SWITCH = 2.0            -- 100% extra (bad internet exists)
    },

    -- High ping protection
    HighPingProtection = {
        Enabled = true,
        PingThreshold = 200,        -- Ping above this = extra protection
        DisableMovementChecks = true,   -- Disable speed/teleport/noclip checks
        DisableLagSwitchCheck = true    -- Disable lag switch detection
    },

    -- Review queue (instead of auto-banning)
    ReviewQueue = {
        Enabled = true,             -- Send suspicious players to review queue
        NotifyDiscord = true,       -- Alert admins on Discord
        RequireConfirmation = true, -- Require admin confirmation before ban
        AutoClearHours = 168        -- Clear from queue after 7 days if no action
    }
}

-- ============================================================================
-- HELPER FUNCTION - Check if value is in table
-- ============================================================================

function Config.TableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- ============================================================================
-- HELPER FUNCTION - Check partial match in table
-- ============================================================================

function Config.TableContainsPartial(tbl, value)
    local lowerValue = string.lower(value)
    for _, v in pairs(tbl) do
        if string.find(lowerValue, string.lower(v)) then
            return true
        end
    end
    return false
end
