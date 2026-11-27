# Changelog

## 1.1.0 - 2026-11-27

### English
- Added support for Blizzard's **Utility Cooldown Manager** (`UtilityCooldownViewer`) alongside Essential cooldowns, with per-spec toggle in `/qcg`.
- Added built-in tracking for learned **Hunter Traps** (Immolation, Freezing, Frost, Explosive), **Important Class Cooldowns** (all 9 Classic/Forever classes, including Hunter Raptor Strike), and **Combat Racials** (per-spec toggle in `/qcg`, enabled by default).
- Added multi-rank spell resolution and deduplication across all Classic/Forever spell ranks.
- Expanded action bar support to all 8 Blizzard action bars (`ActionButton` + `MultiBarBottomLeft/Right`, `MultiBarLeft/Right`, `MultiBar5/6/7`).
- Fixed macro spell resolution on WoW Forever 1.60.1 / 12.x (`GetActionInfo` `subType == "spell"`, single-return `GetMacroSpell`, and macro body fallback).
- Added secret-value-safe combat cooldown detection, exact cooldown-end wake timers, shared Hunter trap cooldown tracking, and cooldown-reset handling (Readiness, Cold Snap, Preparation).
- Improved `/qcg` window layout (aligned dropdowns, source tags `[Trap]` / `[Utility]` / `[Important]`, French `frFR` localization) and added `/qcg test` and `/qcg debug`.
- Fixed `LEARNED_SPELL_IN_TAB` unknown-event error on 12.x / Forever clients.

### Français
- Prise en charge de la barre **CD utilitaires** (`UtilityCooldownViewer`) du Gestionnaire de temps de recharge Blizzard en plus des CD essentiels (activable/désactivable par spé dans `/qcg`).
- Suivi intégré des **Pièges Chasseur** appris (Immolation, Givrant, Givre, Explosif), des **temps de recharge importants de classe** (les 9 classes Classic/Forever, dont Attaque du raptor) et des **raciaux de combat** (activé par défaut, réglable par spé dans `/qcg`).
- Résolution multi-rangs et déduplication par nom de sort (tous rangs reconnus, sur les barres comme en macro).
- Prise en charge des 8 barres d'action Blizzard (`MultiBar5` à `7` incluses) et correction de la détection des sorts dans les macros sur WoW Forever 1.60.1.
- Détection des temps de recharge sécurisée face aux valeurs secrètes en combat, timers exacts de fin de CD, suivi du CD partagé des pièges et réinitialisations (Promptitude, Morsure de froid, Préparation).
- Fenêtre `/qcg` améliorée (menus alignés à droite, badges `[Piège]` / `[Utilitaire]` / `[Important]`, traduction `frFR`) + commandes `/qcg test` et `/qcg debug`.
- Correction de l'erreur d'événement inconnu `LEARNED_SPELL_IN_TAB` sur client 12.x / Forever.
