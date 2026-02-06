# LucidGuard: The Most Advanced Free FiveM Anti-Cheat

```
  ██╗     ██╗   ██╗  ██████╗ ██╗ ██████╗   ██████╗  ██╗   ██╗  █████╗  ██████╗  ██████╗
  ██║     ██║   ██║ ██╔════╝ ██║ ██╔══██╗ ██╔════╝  ██║   ██║ ██╔══██╗ ██╔══██╗ ██╔══██╗
  ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║  ███╗ ██║   ██║ ███████║ ██████╔╝ ██║  ██║
  ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║   ██║ ██║   ██║ ██╔══██║ ██╔══██╗ ██║  ██║
  ███████╗╚██████╔╝ ╚██████╗ ██║ ██████╔╝ ╚██████╔╝ ╚██████╔╝ ██║  ██║ ██║  ██║ ██████╔╝
  ╚══════╝ ╚═════╝   ╚═════╝ ╚═╝ ╚═════╝   ╚═════╝   ╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═════╝
```

**Created by OnlyLucidVibes** | ESX Framework | txAdmin Compatible | Version 2.0.0

> Open-source core protection for your FiveM server. Upgrade to Basic or Advanced for premium detection systems.

**Basic & Advanced editions coming soon to our Tebex store - stay tuned!**

---

## Feature Comparison

| Feature | Free | Basic | Advanced |
|---------|:----:|:-----:|:--------:|
| **Core Protection** | | | |
| Entity Lockdown (Server-Side Spawn Protection) | Y | Y | Y |
| Connection Screening & VPN Detection | Y | Y | Y |
| Resource Scanner (Cheat Menu Detection) | Y | Y | Y |
| Event Burst Filter (Rate Limiting) | Y | Y | Y |
| Junk Event Flooding (Event Dumper Traps) | Y | Y | Y |
| Vector Validation (Raycast Checks) | Y | Y | Y |
| Client Integrity Checks (Honey Pots) | Y | Y | Y |
| Discord Webhook Logging | Y | Y | Y |
| Explosion Monitoring & Filtering | Y | Y | Y |
| Fingerprint Ban Tracking | Y | Y | Y |
| Safe Mode (No Auto-Bans by Default) | Y | Y | Y |
| Smart Detection (AI-Like FP Prevention) | Y | Y | Y |
| Heartbeat System | Y | Y | Y |
| Rate Limiting / DDoS Protection | Y | Y | Y |
| **Detection Modules** | | | |
| Speed Hack Detection | - | Y | Y |
| Teleport Detection | - | Y | Y |
| Godmode Detection | - | Y | Y |
| Weapon Modification Detection | - | Y | Y |
| Noclip Detection | - | Y | Y |
| Aimbot / Vector Trajectory Analysis | - | Y | Y |
| Economy Protection (ESX) | - | Y | Y |
| Combat Log Protection | - | Y | Y |
| Chat Pattern Analysis | - | Y | Y |
| Latency / Lag Switch Analysis | - | Y | Y |
| State Bag Protection | - | Y | Y |
| Ped & Vehicle Scrutiny | - | Y | Y |
| Semantic Integrity Checks | - | Y | Y |
| Post-Join Screenshot | - | Y | Y |
| Value Validation (Anti-Negative Exploit) | - | Y | Y |
| Logic-Based Checks (Distance/Job) | - | Y | Y |
| **Advanced Anti-Bypass** | | | |
| Screen Captures & ESP Detection | - | - | Y |
| Event Tokenization (Secret Handshake) | - | - | Y |
| Dynamic Rotating Event Keys | - | - | Y |
| Shadowban System (Silent Delayed Bans) | - | - | Y |
| Ghost Player Detection | - | - | Y |
| Menu Trap Honeypots (Instant Catch) | - | - | Y |
| Native Hook Detection | - | - | Y |
| Native State Monitor | - | - | Y |
| File Hash Verification (SHA-256) | - | - | Y |
| Hash Master (Automated Verification) | - | - | Y |
| Resource Integrity Monitoring | - | - | Y |
| Vehicle Handling Sanity Checks | - | - | Y |
| Screen Overlay / External ESP Detection | - | - | Y |
| Texture Trap (Anti-External ESP) | - | - | Y |
| Double Screenshot (HUD Comparison) | - | - | Y |
| Net Object Filter (Anti-Crash) | - | - | Y |
| Phone Home (Stealth Integrity Monitor) | - | - | Y |
| Job Action Verification (Anti-Ghost Farm) | - | - | Y |
| File Integrity RPF Scanner | - | - | Y |
| **Admin Tools** | | | |
| Admin HWID Whitelist | - | - | Y |
| Admin Action Monitoring & Logging | - | - | Y |
| txAdmin Security Integration | - | - | Y |
| Silent Admin Spectate (Drone Mode) | - | - | Y |
| Suspicious Volume Detection | - | - | Y |
| Session Summaries | - | - | Y |
| **Support** | | | |
| Community Support (GitHub Issues) | Y | Y | Y |
| Priority Technical Support | - | - | Y |

---

## Installation (Free Edition)

1. Download or clone this repository
2. Place the `lucidguard` folder in your server's `resources/` directory
3. Add to your `server.cfg`:
   ```
   ensure lucidguard
   ```
4. Set your Discord webhook in `server.cfg`:
   ```
   set discord_webhook "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
   ```
5. Configure `config.lua` to match your server's needs
6. Restart your server

### Requirements

- **ESX Framework** (`es_extended`)
- FiveM server with OneSync enabled
- Discord webhook URL (for logging)

---

## Upgrading to Basic / Advanced

**Basic** and **Advanced** editions are **coming soon** to our Tebex store. They will be delivered via **FiveM asset escrow** - no license keys needed.

Once released:

1. Purchase **Basic** or **Advanced** from our Tebex store
2. The resource will appear in your **FiveM Keymaster**
3. Download and place alongside `lucidguard` in your `resources/` folder
4. Add to your `server.cfg` (after `ensure lucidguard`):
   ```
   ensure lucidguard-basic
   ensure lucidguard-advanced
   ```
5. Configure the tier-specific config file (`config_basic.lua` or `config_advanced.lua`)
6. Restart your server

The system automatically detects which modules are installed and adjusts the active tier.

---

## What's Included in Each Tier

### Free (This Repository)
The free edition provides solid **core protection** out of the box:
- **Entity Lockdown** - Blocks unauthorized entity spawns, nuke detection
- **Connection Screening** - VPN/proxy detection, ban evasion via hardware tokens
- **Resource Scanner** - Detects known cheat menus and Lua executors
- **Event Rate Limiting** - Token bucket rate limiting, DDoS protection
- **Junk Events** - Trap events that poison event dumpers
- **Vector Validation** - Raycast-based wall clip and noclip detection
- **Client Integrity** - Honey pot variables and resource count verification
- **Explosion Filtering** - Blocks dangerous explosion types and orbital cannon
- **Discord Logging** - Multi-level logging with severity-based embeds
- **Safe Mode** - Enabled by default, no auto-bans until you review detections
- **Smart Detection** - Trust-based, confidence-weighted false positive prevention

### Basic (Coming Soon)
Everything in Free, plus **active detection modules**:
- **Movement Detection** - Speed, teleport, and noclip with ping-tolerant thresholds
- **Combat Detection** - Godmode, aimbot via vector trajectory analysis
- **Weapon Checks** - Blacklist enforcement, ammo validation, damage monitoring
- **Economy Protection** - Transaction limits, item duplication detection
- **Behavioral Analysis** - Lag switch detection, state bag monitoring
- **Combat Log Protection** - Anti Alt+F4 with state save/restore
- **Chat Analysis** - Detects cheat menu commands typed in chat
- **Ped & Vehicle Scrutiny** - Alpha/visibility checks, rainbow car detection

### Advanced (Coming Soon)
Everything in Free + Basic, plus **anti-bypass and admin security**:
- **Shadowban** - Silently delay bans so cheaters don't know they're caught
- **Event Tokenization** - Cryptographic handshake on protected events
- **Dynamic Keys** - Rotating authentication keys that cheat menus can't keep up with
- **File Integrity** - SHA-256 verification of client files at runtime
- **Native Hook Detection** - Catches silent menus that modify game natives
- **ESP Detection** - Screenshot comparison, texture traps, overlay detection
- **Ghost Detection** - Math challenges to detect killed anticheat scripts
- **Net Object Filter** - Blocks crash entities, NaN coords, malformed spawns
- **Admin HWID Whitelist** - Only pre-approved hardware can use admin commands
- **Admin Monitoring** - Every admin action logged, suspicious volume alerts
- **txAdmin Integration** - Ban/kick/warn event logging and brute-force detection
- **Silent Spectate** - Invisible drone camera that bypasses "admin nearby" alerts

---

## Configuration

All configuration is done through `config.lua` (free tier) and the tier-specific config files.

### Key Settings

| Setting | Description |
|---------|-------------|
| `Config.Debug` | Enable debug prints (disable in production) |
| `Config.Discord.WebhookURL` | Your Discord webhook for alerts |
| `Config.AdminGroups` | Admin groups that bypass detections |
| `Config.Modules.*` | Enable/disable individual modules |
| `Config.PlayerSafety.SafeMode.Enabled` | Safe Mode (recommended: start with `true`) |

### Safe Mode

Safe Mode is **enabled by default**. This means:
- All detections are **logged** but **no one is automatically banned**
- Suspicious players are sent to a **review queue**
- Admins are notified via **Discord** for manual review
- Set `Config.PlayerSafety.SafeMode.Enabled = false` only after reviewing your logs

---

## Server Recommendations

Add these to your `server.cfg` for enhanced protection:

```cfg
# Prevent cheaters from taking control of other players' entities
sv_filterRequestControl 1

# Limit entity creation rate
rateLimiter_stateBag_rate 50
rateLimiter_stateBag_burst 150

# Discord webhook (required for logging)
set discord_webhook "https://discord.com/api/webhooks/YOUR_URL"
```

---

## 🛠️ Support
If you encounter any issues or have questions regarding LucidGuard, please use the appropriate channel below:

Free Edition: Please open a "New Issue" on our GitHub Repository.

Basic/Advanced Edition: Customers receive Priority Support via our Discord Server (Add me: onlylucidvibes).

Direct Inquiries: For business or partnership inquiries, contact onlylucidvibes on Discord.

- **Free Edition**: Open an issue on [GitHub](https://github.com/OnlyLucidVibes/lucidguard/issues)
- **Basic/Advanced**: Priority support will be included with your Tebex purchase once released
---

## ⚖️ Licensing & Copyright
Copyright (c) 2024-2026 OnlyLucidVibes. All rights reserved.

🟢 LucidGuard Core (Free)
The core engine files in this repository are licensed under the GNU General Public License v3.0 (GPL-3.0).

You are free to use, modify, and redistribute the core engine.

Any redistributed versions must remain open-source under the same GPL-3.0 license.

See the LICENSE file for the full legal text.

🔴 LucidGuard Basic & Advanced (Modules)
The Basic and Advanced expansion modules are Proprietary Software. They are NOT included in this open-source repository and are not covered by the GPL-3.0 license.

These modules are sold exclusively through our Tebex Store.

Unauthorized distribution, decompilation, "leaking," or reverse engineering of the paid modules is strictly prohibited and protected by Cfx.re Asset Escrow.

---

**Basic & Advanced editions coming soon to our Tebex store!**
