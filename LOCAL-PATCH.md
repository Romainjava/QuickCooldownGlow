# Local patch

- Renamed to `QuickCooldownGlow` (display name **Quick Cooldown Glow**, formerly
  `EasyCooldownGlow1s`) so addon managers do not update it, and so it can coexist with the
  original `easyCooldownGlow` addon.
- Saved variables renamed with it: `quickCooldownGlowDB`, `QuickCooldownGlowHubDB`.
- Removed Chinese/mojibake comments.
- Unset spells now default to a **1 second** glow instead of `Persistent`.
- `Persistent` is stored explicitly as `0`, so it remains selectable.
- Tracks **Utility Cooldown Manager** spells as well as built-in learned **Traps**, **Important Class Cooldowns**, and **Combat Racials** (togglable per spec in `/qcg`).
- Supports multi-rank Classic/Forever spells, all 8 Blizzard action bars, fixed macro spell resolution, and combat secret-value cooldown fallbacks (shared Hunter trap cooldown + cooldown resets).

Files changed: `easyCooldownGlow.lua`, TOC, `Options.lua`, `MinimapHub.lua`,
`README.md`.
