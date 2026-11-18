# Local patch

- Renamed to `EasyCooldownGlow1s` so addon managers do not update it.
- Removed Chinese/mojibake comments.
- Unset spells now default to a **1 second** glow instead of `Persistent`.
- `Persistent` is stored explicitly as `0`, so it remains selectable.

Files changed: `easyCooldownGlow.lua`, TOC, `Options.lua`, `MinimapHub.lua`,
`README.md`.
