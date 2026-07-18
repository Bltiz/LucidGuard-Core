# LucidGuard — Free FiveM Anti-Cheat Core

```
  ██╗     ██╗   ██╗  ██████╗ ██╗ ██████╗   ██████╗  ██╗   ██╗  █████╗  ██████╗  ██████╗
  ██║     ██║   ██║ ██╔════╝ ██║ ██╔══██╗ ██╔════╝  ██║   ██║ ██╔══██╗ ██╔══██╗ ██╔══██╗
  ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║  ███╗ ██║   ██║ ███████║ ██████╔╝ ██║  ██║
  ██║     ██║   ██║ ██║      ██║ ██║  ██║ ██║   ██║ ██║   ██║ ██╔══██║ ██╔══██╗ ██║  ██║
  ███████╗╚██████╔╝ ╚██████╗ ██║ ██████╔╝ ╚██████╔╝ ╚██████╔╝ ██║  ██║ ██║  ██║ ██████╔╝
  ╚══════╝ ╚═════╝   ╚═════╝ ╚═╝ ╚═════╝   ╚═════╝   ╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝ ╚═════╝
```

**Created by OnlyLucidVibes** · ESX · Version **2.0.1**

Open-source **Free Core** protection for FiveM. Basic and Advanced detection modules are sold separately (not in this repo).

Repository: [Bltiz/LucidGuard-Core](https://github.com/Bltiz/LucidGuard-Core)

---

## What's new in 2.0.1

- Staff **browser panel** (`http://127.0.0.1:30120/lucidguard/`) + in-game **F7** panel UI
- Ban store / case evidence hooks, safer punishment pipeline
- Free-tier hardening (connection screening, entity lockdown, event abuse helpers)
- SQL schema under `lucidguard/sql/`
- Safer defaults (panel password via convar; Safe Mode on by default)

---

## Feature tiers

| Area | Free (this repo) | Basic | Advanced |
|------|:----------------:|:-----:|:--------:|
| Entity lockdown, connection screening, resource scanner | Y | Y | Y |
| Event burst / junk traps, vector checks, integrity honeypots | Y | Y | Y |
| Explosion filter, Discord logs, Safe Mode, smart FP filter | Y | Y | Y |
| Heartbeat + rate limiting | Y | Y | Y |
| Staff web panel + F7 NUI | Y | Y | Y |
| Speed / teleport / godmode / weapons / noclip / aimbot | - | Y | Y |
| Economy, combat-log, chat / latency / state-bag checks | - | Y | Y |
| Shadowban, event tokens, file hash, ESP / screenshots | - | - | Y |
| Admin HWID whitelist, txAdmin hooks, silent spectate | - | - | Y |

---

## Install (Free)

1. Download this repo (or clone it).
2. Copy the **`lucidguard`** folder into your server `resources/`.
3. In `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure es_extended
   ensure lucidguard

   set discord_webhook "https://discord.com/api/webhooks/YOUR_WEBHOOK"
   set lucidguard_web_password "changeme"
   ```
4. Import `lucidguard/sql/lucidguard.sql` if you use the ban/case tables.
5. Edit `lucidguard/config.lua` as needed.
6. Restart the server.

### Optional panel convars

```cfg
set lucidguard_web_password "your-strong-password"
# set lucidguard_panel_url "http://YOUR_PUBLIC_IP:30120/lucidguard/"
# set lucidguard_case_webhook "https://discord.com/api/webhooks/..."
# set lucidguard_screenshot_webhook "https://discord.com/api/webhooks/..."
```

- Local panel: `http://127.0.0.1:30120/lucidguard/`
- In-game: **F7** (admin groups in `config.lua`)

---

## Requirements

- ESX (`es_extended`)
- `oxmysql`
- OneSync recommended
- Discord webhook for logging (optional but recommended)
- `screenshot-basic` only if you enable screenshot features

---

## Basic / Advanced (not included here)

Paid modules ship via Tebex / Keymaster as separate resources:

```cfg
ensure lucidguard
ensure lucidguard-basic      # purchased
ensure lucidguard-advanced   # purchased
```

They are **not** published in this open-source repository.

---

## Support

- **Free:** [GitHub Issues](https://github.com/Bltiz/LucidGuard-Core/issues)
- **Basic / Advanced:** Discord — `onlylucidvibes`

---

## License

- **Free Core** in this repository: **GPL-3.0** (see `LICENSE`)
- **Basic / Advanced** modules: proprietary (Tebex / escrow) — not in this repo

Copyright (c) 2024–2026 OnlyLucidVibes.
