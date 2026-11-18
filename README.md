# Easy Cooldown Glow 1s

Local build of Easy Cooldown Glow 1.0.5 for **World of Warcraft: Forever** (1.60.1).

- Tracks the spells enabled in Blizzard's Cooldown Manager (Essential cooldowns).
- Glows their action bar button when the cooldown finishes.
- **Default glow is now 1 second** for spells you have not configured.
- `Persistent` and `None` are still selectable per spell in `/ecg`.

The original `easyCooldownGlow` folder is kept outside `AddOns`, so the addon
manager does not update this patched copy.

Command: `/ecg`

## License

MIT — see [LICENSE](LICENSE). Original addon by ray929, local 1s patch by
Romainjava. Bundled libraries keep their own terms: `Libs/LibStub` is public
domain, `Libs/LibCustomGlow-1.0` contains work of Hendrick "nevcairiel" Leppkes.
