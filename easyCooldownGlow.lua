-- easyCooldownGlow.lua
-- Quick Cooldown Glow

EasyCooldownGlow = EasyCooldownGlow or {}
local CG = EasyCooldownGlow
CG.ADDON_NAME = ...

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local LOCALES = {
    enUS = {
        SPEC_LABEL        = "Config Spec",
        CLASS_LABEL       = "Current Class",
        SPEC_UNKNOWN      = "Unknown",
        PAGE_DESC         = "Spells enabled in Blizzard's Cooldown Manager (Essential & Utility), plus learned traps and important cooldowns, glow on the action bar when ready.",
        NO_SPELLS         = "No spells found. Enable cooldowns in Blizzard's Cooldown Manager, or enable Traps & Important CDs above.",
        ENABLE            = "Enable",
        OPT_UTILITY       = "Utility CDs",
        OPT_IMPORTANT     = "Traps & Important CDs",
        TIP_UTILITY       = "Also track spells enabled in Blizzard's Cooldown Manager (Utility cooldowns).",
        TIP_IMPORTANT     = "Also track learned class traps, major cooldowns, and combat racials even if they are not in Blizzard's Cooldown Manager.",
        COL_DURATION      = "Glow",
        DUR_PERSISTENT    = "Persistent",
        DUR_SEC           = "%d sec",
        DUR_NONE          = "None",
        STATUS_NOT_ON_BAR = "not on action bars",
        TAG_TRAP          = "Trap",
        TAG_UTILITY       = "Utility",
        TAG_IMPORTANT     = "Important",
        OPEN_OPTIONS      = "Open Options",
        STUB_HINT         = "Click the button below, or type /qcg (/ecg), to open the configuration window.",
    },
    frFR = {
        SPEC_LABEL        = "Spé",
        CLASS_LABEL       = "Classe",
        SPEC_UNKNOWN      = "Inconnue",
        PAGE_DESC         = "Les sorts du Gestionnaire de temps de recharge (Essentiels & Utilitaires), ainsi que vos pièges et temps de recharge importants appris, brillent sur les barres d'action dès qu'ils sont prêts.",
        NO_SPELLS         = "Aucun sort trouvé. Activez des sorts dans le Gestionnaire de temps de recharge ou cochez Pièges & CD importants ci-dessus.",
        ENABLE            = "Activer",
        OPT_UTILITY       = "CD utilitaires",
        OPT_IMPORTANT     = "Pièges & CD importants",
        TIP_UTILITY       = "Suit aussi les sorts activés dans la barre Utilitaire du Gestionnaire de temps de recharge Blizzard.",
        TIP_IMPORTANT     = "Suit aussi les pièges, temps de recharge importants de classe et raciaux de combat appris, même s'ils ne sont pas dans le Gestionnaire de temps de recharge.",
        COL_DURATION      = "Brillance",
        DUR_PERSISTENT    = "Persistant",
        DUR_SEC           = "%d s",
        DUR_NONE          = "Aucun",
        STATUS_NOT_ON_BAR = "absent des barres",
        TAG_TRAP          = "Piège",
        TAG_UTILITY       = "Utilitaire",
        TAG_IMPORTANT     = "Important",
        OPEN_OPTIONS      = "Ouvrir les options",
        STUB_HINT         = "Cliquez sur le bouton ci-dessous, ou tapez /qcg (/ecg), pour ouvrir la fenêtre de configuration.",
    },
}

local activeLocale = LOCALES[GetLocale()] or LOCALES.enUS

local function L(key)
    local v = activeLocale[key]
    if v == nil then v = LOCALES.enUS[key] end
    return v
end
CG.L = L

local GLOW_COLOR = { 0.3, 1.0, 0.4, 1 }
local GLOW_SCALE = 0.8
local GLOW_KEY   = "BAR"
local GLOBAL_COOLDOWN = 1.51
local CAST_GRACE      = 0.35

local function IsSecret(v)
    if v == nil then return false end
    local ok, res = pcall(function() return issecretvalue and issecretvalue(v) end)
    return ok and res or false
end
CG.IsSecret = IsSecret

local function ReadableNumber(v)
    if v == nil or IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function ReadableString(v)
    if v == nil or IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end

local function ReadableBool(v)
    if v == nil or IsSecret(v) or type(v) ~= "boolean" then return nil end
    return v
end

function CG.GetSpellName(sid)
    if not sid then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, sid)
        if ok then return ReadableString(name) end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, sid)
        if ok then return ReadableString(name) end
    end
    return nil
end

function CG.GetSpellDisplayName(sid)
    local name = CG.GetSpellName(sid)
    if name then return name end
    return sid and tostring(sid) or ""
end

function CG.GetSpellIcon(sid)
    if sid and C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, sid)
        if ok and icon and not IsSecret(icon) then return icon end
    end
    if sid and GetSpellTexture then
        local ok, icon = pcall(GetSpellTexture, sid)
        if ok and icon and not IsSecret(icon) then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Verified Classic / WoW Forever (1.60.1) traps, important class cooldowns, and combat racials.
-- Only spells actually learned by the current character are included, resolved across all ranks.
local HUNTER_TRAPS = {
    13795, -- Immolation Trap (ranks: 13795, 14302, 14303, 14304, 14305)
    1499,  -- Freezing Trap   (ranks: 1499, 14310, 14311)
    13809, -- Frost Trap
    13813, -- Explosive Trap  (ranks: 13813, 14316, 14317)
}

local HUNTER_TRAP_ALL_IDS = {
    [13795] = true, [14302] = true, [14303] = true, [14304] = true, [14305] = true,
    [1499]  = true, [14310] = true, [14311] = true,
    [13809] = true,
    [13813] = true, [14316] = true, [14317] = true,
}

local CLASS_IMPORTANT_COOLDOWNS = {
    HUNTER = {
        3045,    -- Rapid Fire
        19574,   -- Bestial Wrath
        19263,   -- Deterrence
        5384,    -- Feign Death
        19577,   -- Intimidation
        19503,   -- Scatter Shot
        23989,   -- Readiness
        19386,   -- Wyvern Sting
        1543,    -- Flare
        1221404, -- Enchanted Flare (Forever)
        781,     -- Disengage
        19801,   -- Tranquilizing Shot
        5116,    -- Concussive Shot
        20736,   -- Distracting Shot
        1293241, -- Summon Hawk (Forever)
    },
    DRUID = {
        29166,   -- Innervate
        17116,   -- Nature's Swiftness
        22812,   -- Barkskin
        5217,    -- Tiger's Fury
        417141,  -- Berserk
        22842,   -- Frenzied Regeneration
        740,     -- Tranquility
        5211,    -- Bash
        16979,   -- Feral Charge
        414924,  -- Feral Charge (Cat)
        16689,   -- Nature's Grasp
        5229,    -- Enrage
        1850,    -- Dash
    },
    MAGE = {
        12043,   -- Presence of Mind
        12042,   -- Arcane Power
        11129,   -- Combustion
        12051,   -- Evocation
        11958,   -- Ice Block
        11426,   -- Ice Barrier
        12472,   -- Cold Snap
        2139,    -- Counterspell
        1953,    -- Blink
        122,     -- Frost Nova
        11113,   -- Blast Wave
        120,     -- Cone of Cold
    },
    PALADIN = {
        642,     -- Divine Shield
        498,     -- Divine Protection
        633,     -- Lay on Hands
        1310994, -- Swift Judgement (Forever)
        853,     -- Hammer of Justice
        1022,    -- Blessing of Protection
        1044,    -- Blessing of Freedom
        20216,   -- Divine Favor
        20925,   -- Holy Shield
        1310911, -- Light's Vigil (Forever)
        1311015, -- Templar's Bulwark (Forever)
        1310897, -- Voice of Truth (Forever)
    },
    PRIEST = {
        14751,   -- Inner Focus
        10060,   -- Power Infusion
        586,     -- Fade
        8122,    -- Psychic Scream
        15487,   -- Silence
        6346,    -- Fear Ward
        13908,   -- Desperate Prayer
        1277370, -- Divine Grace (Forever)
        13896,   -- Feedback
        2651,    -- Elune's Grace
        1277331, -- Chastise (Forever)
        1277455, -- Confounding Flash (Forever)
        1277462, -- Contingency Plan (Forever)
        1277324, -- Dark Sacrifice (Forever)
    },
    ROGUE = {
        13750,   -- Adrenaline Rush
        13877,   -- Blade Flurry
        14177,   -- Cold Blood
        14185,   -- Preparation
        5277,    -- Evasion
        1856,    -- Vanish
        2983,    -- Sprint
        2094,    -- Blind
        1766,    -- Kick
        408,     -- Kidney Shot
        14183,   -- Premeditation
    },
    SHAMAN = {
        16166,   -- Elemental Mastery
        16188,   -- Nature's Swiftness
        16190,   -- Mana Tide Totem
        8177,    -- Grounding Totem
        2484,    -- Earthbind Totem
        408341,  -- Fire Nova
        437009,  -- Totemic Projection
    },
    WARLOCK = {
        6789,    -- Death Coil
        5484,    -- Howl of Terror
        17877,   -- Shadowburn
        17962,   -- Conflagrate
        1293817, -- Conflagrate (Forever Rank 1)
        18708,   -- Fel Domination
        18288,   -- Amplify Curse
        6353,    -- Soul Fire
        6229,    -- Shadow Ward
        1225228, -- Bane of Havoc (Forever)
    },
    WARRIOR = {
        1719,    -- Recklessness
        12328,   -- Death Wish
        2687,    -- Bloodrage
        12292,   -- Sweeping Strikes
        18499,   -- Berserker Rage
        20230,   -- Retaliation
        871,     -- Shield Wall
        12975,   -- Last Stand
        5246,    -- Intimidating Shout
        1161,    -- Challenging Shout
        20252,   -- Intercept
        2565,    -- Shield Block
        676,     -- Disarm
        6552,    -- Pummel
        72,      -- Shield Bash
        355,     -- Taunt
    },
}

local RACIAL_COOLDOWNS = {
    20572,   -- Blood Fury
    20554,   -- Berserking
    20594,   -- Stoneform
    20580,   -- Shadowmeld
    7744,    -- Will of the Forsaken
    20589,   -- Escape Artist
    20549,   -- War Stomp
    20600,   -- Perception
    1259799, -- Elune's Light (Forever)
    1259813, -- Eureka (Forever)
    1259718, -- Will to Survive (Forever)
    1299026, -- Shatter Curse (Forever)
}

local COOLDOWN_RESETS = {
    [23989] = "HUNTER", -- Readiness
    [12472] = { 11958, 11426, 122, 120 }, -- Cold Snap (Frost spells)
    [14185] = { 5277, 2983, 1856, 14177, 14183 }, -- Preparation
}

local ScheduleEvaluate
local SetExpiry

function CG.EnsureDB()
    quickCooldownGlowDB = quickCooldownGlowDB or {}
end

local function SpecGetIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, idx = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and idx and not IsSecret(idx) and idx > 0 then return idx end
    end
    if GetSpecialization then
        local ok, idx = pcall(GetSpecialization)
        if ok and idx and not IsSecret(idx) and idx > 0 then return idx end
    end
    return nil
end

function CG.GetSpecInfo(specIndex)
    local idx = specIndex or SpecGetIndex()
    if not idx or idx <= 0 then return nil end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local ok, id, name = pcall(C_SpecializationInfo.GetSpecializationInfo, idx)
        if ok and id and not IsSecret(id) then return id, ReadableString(name) end
    end
    if GetSpecializationInfo then
        local ok, id, name = pcall(GetSpecializationInfo, idx)
        if ok and id and not IsSecret(id) then return id, ReadableString(name) end
    end
    return nil
end

local function GetCurrentSpecID()
    return CG.GetSpecInfo() or 0
end
CG.GetCurrentSpecID = GetCurrentSpecID

local function GetSpecSlot(specID)
    CG.EnsureDB()
    local db = quickCooldownGlowDB
    db.specs = db.specs or {}
    local spec = db.specs[specID] or {}
    db.specs[specID] = spec
    if spec.enabled == nil then
        spec.enabled = (quickCooldownGlowDB.enabled ~= false)
    end
    if spec.includeUtility == nil then
        spec.includeUtility = true
    end
    if spec.includeImportant == nil then
        spec.includeImportant = true
    end
    spec.durations = spec.durations or {}
    return spec
end

function CG.IsEnabled()
    if not quickCooldownGlowDB then return nil end
    local specs = quickCooldownGlowDB.specs
    local spec = specs and specs[GetCurrentSpecID()]
    if spec and spec.enabled ~= nil then
        return spec.enabled
    end
    return quickCooldownGlowDB.enabled ~= false
end

function CG.SetEnabled(v)
    local spec = GetSpecSlot(GetCurrentSpecID())
    spec.enabled = v and true or false
    if v then
        CG.Start()
    else
        CG.StopAll()
    end
end

function CG.IsUtilityEnabled()
    if not quickCooldownGlowDB then return true end
    local specs = quickCooldownGlowDB.specs
    local spec = specs and specs[GetCurrentSpecID()]
    if spec and spec.includeUtility ~= nil then
        return spec.includeUtility
    end
    return true
end

function CG.SetUtilityEnabled(v)
    local spec = GetSpecSlot(GetCurrentSpecID())
    spec.includeUtility = v and true or false
    CG.Rescan()
    ScheduleEvaluate()
end

function CG.IsImportantEnabled()
    if not quickCooldownGlowDB then return true end
    local specs = quickCooldownGlowDB.specs
    local spec = specs and specs[GetCurrentSpecID()]
    if spec and spec.includeImportant ~= nil then
        return spec.includeImportant
    end
    return true
end

function CG.SetImportantEnabled(v)
    local spec = GetSpecSlot(GetCurrentSpecID())
    spec.includeImportant = v and true or false
    CG.Rescan()
    ScheduleEvaluate()
end

local function GetDurations(specID)
    return GetSpecSlot(specID).durations
end

function CG.GetDuration(sid)
    if not quickCooldownGlowDB then return 1 end
    local specID = GetCurrentSpecID()
    local specs = quickCooldownGlowDB.specs
    local durs = specs and specs[specID] and specs[specID].durations
    if not durs then return 1 end
    local v = durs[sid]
    if v == nil then
        local name = CG.GetSpellName(sid)
        if name then
            local canon = CG._trackedByName and CG._trackedByName[name]
            if canon and durs[canon] ~= nil then
                v = durs[canon]
            else
                for savedId, savedVal in pairs(durs) do
                    if CG.GetSpellName(savedId) == name then
                        v = savedVal
                        break
                    end
                end
            end
        end
    end
    if v == nil then return 1 end
    return v
end

function CG.SetDuration(sid, n)
    CG.EnsureDB()
    local durs = GetDurations(GetCurrentSpecID())
    local name = CG.GetSpellName(sid)
    if name then
        for savedId in pairs(durs) do
            if savedId ~= sid and CG.GetSpellName(savedId) == name then
                durs[savedId] = nil
            end
        end
    end
    -- Keep 0 (Persistent) distinct from "not set" (default 1 s).
    durs[sid] = n

    if n and n > 0 then
        SetExpiry(sid, n)
    else
        SetExpiry(sid, 0)
    end
    ScheduleEvaluate()
end

CG.DUR_VALUES = { 0, 1, 2, 3, 4, 5, -1 }

function CG.DurationLabel(v)
    v = v or 0
    if v == -1 then return L("DUR_NONE") end
    if v > 0 then return string.format(L("DUR_SEC"), v) end
    return L("DUR_PERSISTENT")
end

-- Spellbook & learned-rank index (handles Classic / WoW Forever multi-rank spells)
local bookByID = {}
local bookByName = {}
local bookRankByName = {}
local bookBuilt = false

local function GetSpellRankNum(sid)
    if not (C_Spell and C_Spell.GetSpellSubtext) then return 0 end
    local ok, sub = pcall(C_Spell.GetSpellSubtext, sid)
    sub = ok and ReadableString(sub) or nil
    if not sub then return 0 end
    local digits = string.match(sub, "(%d+)")
    return digits and tonumber(digits) or 0
end

local function InvalidateSpellBook()
    bookBuilt = false
end

local function EnsureSpellBook()
    if bookBuilt then return end
    wipe(bookByID)
    wipe(bookByName)
    wipe(bookRankByName)
    bookBuilt = true

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local futureType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
        local okN, numLines = pcall(C_SpellBook.GetNumSpellBookSkillLines)
        numLines = okN and ReadableNumber(numLines) or 0
        for line = 1, numLines do
            local okL, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, line)
            if okL and type(info) == "table" and not IsSecret(info) then
                local offset = ReadableNumber(info.itemIndexOffset) or 0
                local count = ReadableNumber(info.numSpellBookItems) or 0
                for slot = offset + 1, offset + count do
                    local okI, item = pcall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                    if okI and type(item) == "table" and not IsSecret(item) then
                        local itemType = not IsSecret(item.itemType) and item.itemType or nil
                        local isPassive = ReadableBool(item.isPassive)
                        local sid = ReadableNumber(item.spellID)
                        if sid and sid > 0 and itemType ~= futureType and not isPassive then
                            bookByID[sid] = true
                            local name = ReadableString(item.name) or CG.GetSpellName(sid)
                            if name then
                                local rank = GetSpellRankNum(sid)
                                local prevRank = bookRankByName[name]
                                if prevRank == nil or rank >= prevRank then
                                    bookByName[name] = sid
                                    bookRankByName[name] = rank
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function IsKnownDirect(sid)
    if not sid or sid <= 0 then return false end
    if bookByID[sid] then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, sid)
        if ok and ReadableBool(known) == true then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local ok, inBook = pcall(C_SpellBook.IsSpellInSpellBook, sid)
        if ok and ReadableBool(inBook) == true then return true end
    end
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, sid)
        if ok and ReadableBool(known) == true then return true end
    end
    return false
end

local function ResolveLearnedSpellID(baseID)
    if not baseID or baseID <= 0 then return nil end
    EnsureSpellBook()

    local effectiveID = baseID
    if C_Spell and C_Spell.GetOverrideSpell then
        local ok, ov = pcall(C_Spell.GetOverrideSpell, baseID)
        ov = ok and ReadableNumber(ov) or nil
        if ov and ov > 0 then effectiveID = ov end
    end

    local name = CG.GetSpellName(effectiveID) or CG.GetSpellName(baseID)
    if name and bookByName[name] then
        return bookByName[name]
    end
    if IsKnownDirect(effectiveID) then
        return effectiveID
    end
    if effectiveID ~= baseID and IsKnownDirect(baseID) then
        return baseID
    end
    return nil
end

local function CollectViewerSpells(viewerName, sourceTag, addFn)
    local viewer = _G[viewerName]
    if not viewer or not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then
        return
    end
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then
        return
    end
    for frame in viewer.itemFramePool:EnumerateActive() do
        local cid = frame and ReadableNumber(frame.cooldownID)
        if cid then
            local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
            if ok and type(info) == "table" and not IsSecret(info) then
                local primary = ReadableNumber(info.overrideSpellID) or ReadableNumber(info.spellID)
                local linked = (type(info.linkedSpellIDs) == "table" and not IsSecret(info.linkedSpellIDs)) and info.linkedSpellIDs or nil
                if not primary and linked then
                    primary = ReadableNumber(linked[1])
                end
                if primary and primary > 0 then
                    local aliases = {}
                    local sid = ReadableNumber(info.spellID)
                    local ov = ReadableNumber(info.overrideSpellID)
                    if sid and sid > 0 then aliases[#aliases + 1] = sid end
                    if ov and ov > 0 then aliases[#aliases + 1] = ov end
                    if linked then
                        for _, lsid in ipairs(linked) do
                            local lid = ReadableNumber(lsid)
                            if lid and lid > 0 then aliases[#aliases + 1] = lid end
                        end
                    end
                    addFn(primary, sourceTag, aliases)
                end
            end
        end
    end
end

local function GetPlayerClassToken()
    if UnitClass then
        local ok, _, token = pcall(UnitClass, "player")
        if ok then return ReadableString(token) end
    end
    return nil
end

CG._trackedCache = CG._trackedCache or {}
CG._trackedByID = CG._trackedByID or {}
CG._trackedByName = CG._trackedByName or {}
CG._trackedSource = CG._trackedSource or {}
CG._trapCanonIDs = CG._trapCanonIDs or {}

local function ComputeTracked()
    EnsureSpellBook()

    local canonicalSet = {}   -- [canonSid] = true
    local byID = {}           -- [anySpellID] = canonSid
    local byName = {}         -- [spellName] = canonSid
    local sourceMap = {}      -- [canonSid] = "essential" | "utility" | "trap" | "important"
    local trapCanon = {}      -- [canonSid] = true

    local function registerSpell(sid, sourceTag, aliases, isTrap)
        if not sid or sid <= 0 then return end
        local name = CG.GetSpellName(sid)
        -- Prefer the player's learned spellbook rank ID when available
        if name and bookByName[name] then
            sid = bookByName[name]
        end

        local canon = byID[sid] or (name and byName[name]) or nil
        if not canon then
            canon = sid
            canonicalSet[canon] = true
            sourceMap[canon] = sourceTag
        end
        if isTrap then
            trapCanon[canon] = true
            if sourceMap[canon] == "important" or sourceMap[canon] == "utility" then
                sourceMap[canon] = "trap"
            end
        end

        byID[canon] = canon
        byID[sid] = canon
        if name then
            byName[name] = canon
        end
        if aliases then
            for _, aid in ipairs(aliases) do
                if aid and aid > 0 then
                    byID[aid] = canon
                    local aname = CG.GetSpellName(aid)
                    if aname and not byName[aname] then
                        byName[aname] = canon
                    end
                end
            end
        end
    end

    -- 1. Blizzard Cooldown Manager: Essential cooldowns
    CollectViewerSpells("EssentialCooldownViewer", "essential", registerSpell)

    -- 2. Blizzard Cooldown Manager: Utility cooldowns
    if CG.IsUtilityEnabled() then
        CollectViewerSpells("UtilityCooldownViewer", "utility", registerSpell)
    end

    -- 3. Built-in Traps & Important Cooldowns (learned spells only)
    if CG.IsImportantEnabled() then
        local classToken = GetPlayerClassToken()
        if classToken == "HUNTER" then
            for _, baseID in ipairs(HUNTER_TRAPS) do
                local learned = ResolveLearnedSpellID(baseID)
                if learned then
                    registerSpell(learned, "trap", { baseID }, true)
                end
            end
        end
        local classList = classToken and CLASS_IMPORTANT_COOLDOWNS[classToken]
        if classList then
            for _, baseID in ipairs(classList) do
                local learned = ResolveLearnedSpellID(baseID)
                if learned then
                    registerSpell(learned, "important", { baseID }, false)
                end
            end
        end
        for _, baseID in ipairs(RACIAL_COOLDOWNS) do
            local learned = ResolveLearnedSpellID(baseID)
            if learned then
                registerSpell(learned, "important", { baseID }, false)
            end
        end
    end

    -- Keep trapCanon populated even if a trap came solely from Utility/Essential viewer
    for canon in pairs(canonicalSet) do
        if not trapCanon[canon] then
            if HUNTER_TRAP_ALL_IDS[canon] then
                trapCanon[canon] = true
            else
                local cname = CG.GetSpellName(canon)
                if cname then
                    for _, baseID in ipairs(HUNTER_TRAPS) do
                        if CG.GetSpellName(baseID) == cname then
                            trapCanon[canon] = true
                            break
                        end
                    end
                end
            end
        end
    end

    CG._trackedCache = canonicalSet
    CG._trackedByID = byID
    CG._trackedByName = byName
    CG._trackedSource = sourceMap
    CG._trapCanonIDs = trapCanon

    local ids = {}
    for sid in pairs(canonicalSet) do
        ids[#ids + 1] = sid
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function GetTrackedSpellIDs()
    if not next(CG._trackedCache) then
        ComputeTracked()
    end
    return CG._trackedCache
end
CG.GetTrackedSpellIDs = GetTrackedSpellIDs

function CG.GetTrackedSource(sid)
    return CG._trackedSource and CG._trackedSource[sid] or nil
end

local function ResolveTrackedCanonical(sid)
    if not sid or sid <= 0 then return nil end
    local canon = CG._trackedByID[sid]
    if canon then return canon end
    local name = CG.GetSpellName(sid)
    if name then
        canon = CG._trackedByName[name]
        if canon then
            CG._trackedByID[sid] = canon
            return canon
        end
    end
    return nil
end

function CG.Rescan()
    InvalidateSpellBook()
    ComputeTracked()
end

-- Tooltip cooldown parser (fallback for combat cast tracking when GetSpellBaseCooldown returns 0)
local COOLDOWN_WORDINGS = {
    { "SPELL_RECAST_TIME_SEC",   1 },
    { "SPELL_RECAST_TIME_MIN",   60 },
    { "SPELL_RECAST_TIME_HOURS", 3600 },
}
local wordingPatterns = {}

local function NormalizeSpaces(s)
    if not s then return nil end
    return (string.gsub(s, "\194\160", " "))
end

local function GetWordingPattern(globalName)
    local pat = wordingPatterns[globalName]
    if pat ~= nil then return pat or nil end
    local wording = _G[globalName]
    if type(wording) ~= "string" then
        wordingPatterns[globalName] = false
        return nil
    end
    wording = NormalizeSpaces(wording)
    pat = string.gsub(wording, "|4[^;]*;", "#PLURAL#")
    pat = string.gsub(pat, "%%[%-%d%.]*[dfgs]", "#NUMBER#")
    pat = string.gsub(pat, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    pat = string.gsub(pat, "#NUMBER#", "([%%d%%.,]+)")
    pat = string.gsub(pat, "#PLURAL#", ".-")
    pat = "^" .. pat .. "$"
    wordingPatterns[globalName] = pat
    return pat
end

local function MatchCooldownText(text)
    if not text then return nil end
    text = NormalizeSpaces(text)
    for _, entry in ipairs(COOLDOWN_WORDINGS) do
        local pat = GetWordingPattern(entry[1])
        if pat then
            local num = string.match(text, pat)
            if num then
                local val = tonumber((string.gsub(num, ",", ".")))
                if val and val > 0 then
                    return val * entry[2]
                end
            end
        end
    end
    return nil
end

local tooltipCooldownCache = {}

local function ReadTooltipCooldown(sid)
    local cached = tooltipCooldownCache[sid]
    if cached ~= nil then return cached end
    if not (C_TooltipInfo and C_TooltipInfo.GetSpellByID) then
        tooltipCooldownCache[sid] = 0
        return 0
    end
    local ok, tip = pcall(C_TooltipInfo.GetSpellByID, sid)
    if not ok or type(tip) ~= "table" or IsSecret(tip) or type(tip.lines) ~= "table" then
        return 0
    end
    for _, line in ipairs(tip.lines) do
        if type(line) == "table" and not IsSecret(line) then
            local sec = MatchCooldownText(ReadableString(line.leftText))
                or MatchCooldownText(ReadableString(line.rightText))
            if sec and sec > GLOBAL_COOLDOWN then
                tooltipCooldownCache[sid] = sec
                return sec
            end
        end
    end
    tooltipCooldownCache[sid] = 0
    return 0
end

local function GetBaseCooldownSeconds(sid)
    if GetSpellBaseCooldown then
        local ok, cd, gcd = pcall(GetSpellBaseCooldown, sid)
        if ok then
            cd = ReadableNumber(cd)
            gcd = ReadableNumber(gcd)
            if cd and cd > 0 then
                if cd < 500 then
                    local g = (gcd and gcd < 500) and gcd or 1.5
                    if cd > g + 0.05 and cd > GLOBAL_COOLDOWN then
                        return cd
                    end
                else
                    local g = gcd or 1500
                    if cd > g + 50 then
                        return cd / 1000
                    end
                end
            end
        end
    end
    local tipSec = ReadTooltipCooldown(sid)
    if tipSec > GLOBAL_COOLDOWN then return tipSec end
    return 0
end

-- Cooldown state tracking (multi-tier, 100% secret-value safe)
local GetSpellCD = (C_Spell and C_Spell.GetSpellCooldown) or nil

CG._knownCdDur   = CG._knownCdDur or {}   -- [canonSid] = observed duration > GLOBAL_COOLDOWN
CG._castEndsAt   = CG._castEndsAt or {}   -- [canonSid] = GetTime() + cd
CG._castAt       = CG._castAt or {}       -- [canonSid] = GetTime()
CG._castTimers   = CG._castTimers or {}   -- [canonSid] = timer
CG._cdEndAt      = CG._cdEndAt or {}      -- [canonSid] = scheduled exact cooldown end timestamp
CG._cdEndTimers  = CG._cdEndTimers or {}  -- [canonSid] = timer

local function CancelCdEndTimer(canonSid)
    local t = CG._cdEndTimers[canonSid]
    if t then
        if t.Cancel then pcall(t.Cancel, t) end
        CG._cdEndTimers[canonSid] = nil
    end
    CG._cdEndAt[canonSid] = nil
end

local function ScheduleCooldownEndTimer(canonSid, endAt, now)
    if not canonSid or not endAt or endAt <= now then return end
    local prev = CG._cdEndAt[canonSid]
    if prev and math.abs(prev - endAt) < 0.05 and CG._cdEndTimers[canonSid] then
        return
    end
    CancelCdEndTimer(canonSid)
    CG._cdEndAt[canonSid] = endAt
    local delay = math.max(endAt - now + 0.03, 0.03)
    if C_Timer and C_Timer.NewTimer then
        CG._cdEndTimers[canonSid] = C_Timer.NewTimer(delay, function()
            CG._cdEndTimers[canonSid] = nil
            CG._cdEndAt[canonSid] = nil
            ScheduleEvaluate()
        end)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            CG._cdEndAt[canonSid] = nil
            ScheduleEvaluate()
        end)
    end
end

local viewerCdByName = {}
local viewerCdStamp = -1

local function RefreshViewerCooldownStates(now)
    if viewerCdStamp == now then return end
    viewerCdStamp = now
    wipe(viewerCdByName)
    if not (C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo) then return end
    for _, vName in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer" }) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
            for item in viewer.itemFramePool:EnumerateActive() do
                local onActual = item and ReadableBool(item.isOnActualCooldown)
                local cid = item and ReadableNumber(item.cooldownID)
                if onActual ~= nil and cid then
                    local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
                    if ok and type(info) == "table" and not IsSecret(info) then
                        local sid = ReadableNumber(info.overrideSpellID) or ReadableNumber(info.spellID)
                        local name = sid and CG.GetSpellName(sid)
                        if name and (onActual or viewerCdByName[name] == nil) then
                            viewerCdByName[name] = onActual
                        end
                    end
                end
            end
        end
    end
end

local function CancelCastTimer(canonSid)
    local t = CG._castTimers[canonSid]
    if t then
        if t.Cancel then pcall(t.Cancel, t) end
        CG._castTimers[canonSid] = nil
    end
end

local function StartCastCooldown(canonSid, cdSec, now)
    if not canonSid or not cdSec or cdSec <= GLOBAL_COOLDOWN then return end
    CG._castAt[canonSid] = now
    CG._castEndsAt[canonSid] = now + cdSec
    CancelCastTimer(canonSid)
    if C_Timer and C_Timer.NewTimer then
        CG._castTimers[canonSid] = C_Timer.NewTimer(cdSec + 0.05, function()
            CG._castTimers[canonSid] = nil
            ScheduleEvaluate()
        end)
    elseif C_Timer and C_Timer.After then
        C_Timer.After(cdSec + 0.05, function()
            ScheduleEvaluate()
        end)
    end
end

local function IsHunterTrapSpell(sid)
    if not sid then return false end
    if HUNTER_TRAP_ALL_IDS[sid] then return true end
    local name = CG.GetSpellName(sid)
    if not name then return false end
    for _, baseID in ipairs(HUNTER_TRAPS) do
        if CG.GetSpellName(baseID) == name then return true end
    end
    return false
end

local function OnPlayerSpellCastSucceeded(spellID)
    local sid = ReadableNumber(spellID)
    if not sid or sid <= 0 then return end
    local now = GetTime()

    -- Handle cooldown reset abilities (Readiness, Cold Snap, Preparation)
    local didReset = false
    local resetRule = COOLDOWN_RESETS[sid]
    if resetRule then
        if resetRule == "HUNTER" then
            local selfCanon = ResolveTrackedCanonical(sid)
            for csid in pairs(CG._castEndsAt) do
                if csid ~= selfCanon then
                    CG._castEndsAt[csid] = nil
                    CancelCastTimer(csid)
                    didReset = true
                end
            end
        elseif type(resetRule) == "table" then
            for _, targetBase in ipairs(resetRule) do
                local tcanon = ResolveTrackedCanonical(targetBase)
                if tcanon and CG._castEndsAt[tcanon] then
                    CG._castEndsAt[tcanon] = nil
                    CancelCastTimer(tcanon)
                    didReset = true
                end
            end
        end
    end

    local canon = ResolveTrackedCanonical(sid)
    if not canon then
        if didReset then ScheduleEvaluate() end
        return
    end

    local isTrap = CG._trapCanonIDs[canon] or IsHunterTrapSpell(sid)
    local cdSec = math.max(CG._knownCdDur[canon] or 0, GetBaseCooldownSeconds(sid), GetBaseCooldownSeconds(canon))
    if cdSec <= GLOBAL_COOLDOWN and isTrap then
        cdSec = 30
    end
    if cdSec <= GLOBAL_COOLDOWN then
        if didReset then ScheduleEvaluate() end
        return
    end

    StartCastCooldown(canon, cdSec, now)

    -- Hunter traps share a cooldown in Classic / WoW Forever
    if isTrap then
        for trapCanon in pairs(CG._trapCanonIDs) do
            if trapCanon ~= canon then
                local trapCd = math.max(cdSec, CG._knownCdDur[trapCanon] or 0)
                StartCastCooldown(trapCanon, trapCd, now)
            end
        end
    end
    ScheduleEvaluate()
end

local function ReadActionSlotCooldown(btn)
    if not btn or not btn.action then return nil, nil end
    if C_ActionBar and C_ActionBar.GetActionCooldown then
        local ok, info = pcall(C_ActionBar.GetActionCooldown, btn.action)
        if ok and type(info) == "table" and not IsSecret(info) then
            return ReadableNumber(info.startTime), ReadableNumber(info.duration)
        end
    end
    if GetActionCooldown then
        local ok, start, dur = pcall(GetActionCooldown, btn.action)
        if ok then
            return ReadableNumber(start), ReadableNumber(dur)
        end
    end
    return nil, nil
end

local function IsOnCooldown(btn, sid, canonSid, now)
    if not sid then return false end
    local key = canonSid or sid

    if not GetSpellCD then
        if btn and btn.cooldown and btn.cooldown:IsShown() then return true end
        if btn and btn.chargeCooldown and btn.chargeCooldown:IsShown() then return true end
        return false
    end

    local apiKnownReady = false
    local apiWasSecret = false

    local ok, cd = pcall(GetSpellCD, sid)
    if ok and type(cd) == "table" and not IsSecret(cd) then
        local dur = ReadableNumber(cd.duration)
        local start = ReadableNumber(cd.startTime)
        if dur and dur > GLOBAL_COOLDOWN then
            CG._knownCdDur[key] = dur
        end

        -- 1. Readable startTime/duration is ground truth (works out of combat & whenever unmasked)
        if start ~= nil and dur ~= nil then
            if start > 0 and dur > GLOBAL_COOLDOWN and (start + dur) > now then
                ScheduleCooldownEndTimer(key, start + dur, now)
                return true
            end
            apiKnownReady = true
        elseif IsSecret(cd.startTime) or IsSecret(cd.duration) then
            apiWasSecret = true
        end

        -- 2. Modern 12.x / Forever booleans (isActive / isOnGCD)
        local isActive = ReadableBool(cd.isActive)
        local isOnGCD = ReadableBool(cd.isOnGCD)
        if isActive ~= nil and not IsSecret(cd.isOnGCD) then
            if isActive and not isOnGCD then
                return true
            end
            if not isActive then
                apiKnownReady = true
            end
        elseif IsSecret(cd.isActive) or IsSecret(cd.isOnGCD) then
            apiWasSecret = true
        end
    end

    -- 3. Action bar slot cooldown (handles shared category cooldowns or rank/macro mismatches)
    local aStart, aDur = ReadActionSlotCooldown(btn)
    if aStart ~= nil and aDur ~= nil then
        if aDur > GLOBAL_COOLDOWN then
            CG._knownCdDur[key] = aDur
        end
        if aStart > 0 and aDur > GLOBAL_COOLDOWN and (aStart + aDur) > now then
            ScheduleCooldownEndTimer(key, aStart + aDur, now)
            return true
        end
    end

    if apiKnownReady and not apiWasSecret then
        CancelCdEndTimer(key)
        if (now - (CG._castAt[key] or -CAST_GRACE)) > CAST_GRACE then
            CG._castEndsAt[key] = nil
        end
        return false
    end

    -- 4. Fallback: Blizzard CooldownViewer icon state (when C_Spell.GetSpellCooldown is secret in combat)
    RefreshViewerCooldownStates(now)
    local name = CG.GetSpellName(key)
    if name and viewerCdByName[name] ~= nil then
        if viewerCdByName[name] == true then
            return true
        end
        if (now - (CG._castAt[key] or -CAST_GRACE)) > CAST_GRACE then
            CG._castEndsAt[key] = nil
            return false
        end
    end

    -- 5. Fallback: Self-cast cooldown timer from UNIT_SPELLCAST_SUCCEEDED
    local endsAt = CG._castEndsAt[key]
    if endsAt then
        if now < endsAt then
            return true
        end
        CG._castEndsAt[key] = nil
    end

    return false
end

local ACTION_BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button",
}
CG.ACTION_BAR_PREFIXES = ACTION_BAR_PREFIXES

local _sidCache = setmetatable({}, { __mode = "k" })

local function ReadMacroFirstSpellID(macroIndex)
    if not GetMacroBody then return nil end
    local ok, body = pcall(GetMacroBody, macroIndex)
    body = ok and ReadableString(body) or nil
    if not body then return nil end
    for line in string.gmatch(body, "[^\r\n]+") do
        local token = string.match(line, "^%s*#showtooltip%s+(.-)%s*$")
            or string.match(line, "^%s*#show%s+(.-)%s*$")
            or string.match(line, "^%s*/[cC][aA][sS][tT]%s+(.-)%s*$")
            or string.match(line, "^%s*/[uU][sS][eE]%s+(.-)%s*$")
        if token and token ~= "" then
            token = string.gsub(token, "%b[]", " ")
            token = string.match(token, "^%s*!?([^;]+)")
            if token then
                token = string.gsub(token, "%s*%([^)]*%d[^)]*%)%s*$", "")
                token = string.gsub(token, "^%s+", "")
                token = string.gsub(token, "%s+$", "")
                if token ~= "" and C_Spell and C_Spell.GetSpellInfo then
                    local okS, info = pcall(C_Spell.GetSpellInfo, token)
                    if okS and type(info) == "table" and not IsSecret(info) then
                        local sid = ReadableNumber(info.spellID)
                        if sid and sid > 0 then return sid end
                    end
                end
            end
        end
    end
    return nil
end

local function ResolveMacroSpellID(id, subType, slot)
    if not id or id <= 0 then return nil end
    -- On WoW 12.x / Forever, GetActionInfo(slot) returns ("macro", spellID, "spell") directly when showing a spell
    if subType == "spell" then
        return id
    end

    local macroIndex = id
    if subType == "item" and slot and C_ActionBar and C_ActionBar.GetActionText and GetMacroIndexByName then
        local okT, mName = pcall(C_ActionBar.GetActionText, slot)
        mName = okT and ReadableString(mName) or nil
        if mName then
            local okM, idx = pcall(GetMacroIndexByName, mName)
            idx = okM and ReadableNumber(idx) or nil
            if idx and idx > 0 then macroIndex = idx end
        end
    end

    local sid
    if C_Macro and C_Macro.GetMacroSpell then
        local ok, r1, r2 = pcall(C_Macro.GetMacroSpell, macroIndex)
        if ok then
            sid = ReadableNumber(r1) or ReadableNumber(r2)
        end
    elseif GetMacroSpell then
        local ok, r1, r2 = pcall(GetMacroSpell, macroIndex)
        if ok then
            sid = ReadableNumber(r1) or ReadableNumber(r2)
        end
    end

    if not (sid and sid > 0) then
        sid = ReadMacroFirstSpellID(macroIndex)
    end
    if not (sid and sid > 0) then
        local nm = CG.GetSpellName(id)
        if nm and nm ~= tostring(id) then sid = id end
    end
    return (sid and sid > 0) and sid or nil
end

local function ComputeButtonSpellID(btn)
    if not btn.action then return nil end
    local ok, at, id, subType, spellFromAction = pcall(GetActionInfo, btn.action)
    if not ok then return nil end
    at = ReadableString(at)
    id = ReadableNumber(id)
    subType = ReadableString(subType)
    spellFromAction = ReadableNumber(spellFromAction)
    if not at then return nil end
    if at == "spell" then
        local sid = spellFromAction or id
        return (sid and sid > 0) and sid or nil
    elseif at == "macro" then
        return ResolveMacroSpellID(id, subType, btn.action)
    end
    return nil
end

local function GetButtonSpellID(btn)
    local cached = _sidCache[btn]
    if cached ~= nil then return cached or nil end
    local sid = ComputeButtonSpellID(btn)
    _sidCache[btn] = sid or false
    return sid
end

local SID_INVALIDATE_EVENTS = {
    ACTIONBAR_SLOT_CHANGED      = true,
    ACTIONBAR_PAGE_CHANGED      = true,
    UPDATE_BONUS_ACTIONBAR      = true,
    UPDATE_VEHICLE_ACTIONBAR    = true,
    UPDATE_POSSESS_BAR          = true,
    UPDATE_MACROS               = true,
    MODIFIER_STATE_CHANGED      = true,
    SPELLS_CHANGED              = true,
    LEARNED_SPELL_IN_TAB        = true,
    PLAYER_TALENT_UPDATE        = true,
    ACTIVE_TALENT_GROUP_CHANGED = true,
}

local SPELLBOOK_INVALIDATE_EVENTS = {
    SPELLS_CHANGED              = true,
    LEARNED_SPELL_IN_TAB        = true,
    PLAYER_TALENT_UPDATE        = true,
    ACTIVE_TALENT_GROUP_CHANGED = true,
}

function CG.GetBarSpellIDs()
    local set = {}
    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
            local btn = _G[prefix .. i]
            if btn and btn.action then
                local sid = GetButtonSpellID(btn)
                if sid then
                    set[sid] = true
                    local canon = ResolveTrackedCanonical(sid)
                    if canon then set[canon] = true end
                end
            end
        end
    end
    return set
end

CG._glowing = CG._glowing or {}   -- [button] = canonSid
CG._expiry  = CG._expiry or {}
CG._wasCd   = CG._wasCd or {}
CG._timers  = CG._timers or {}

local function ProcGlowStart(btn)
    if not LCG then return end
    if btn then
        pcall(LCG.ProcGlow_Stop, btn, GLOW_KEY)
    end
    LCG.ProcGlow_Start(btn, { key = GLOW_KEY, startAnim = true, color = GLOW_COLOR, scale = GLOW_SCALE })
end

local function ProcGlowStop(btn)
    if not LCG then return end
    pcall(LCG.ProcGlow_Stop, btn, GLOW_KEY)
end

local function StopGlow(btn)
    ProcGlowStop(btn)
    CG._glowing[btn] = nil
end

local function CancelExpiryTimer(sid)
    local t = CG._timers[sid]
    if t then
        if t.Cancel then pcall(t.Cancel, t) end
        CG._timers[sid] = nil
    end
end

function SetExpiry(sid, dur)
    CancelExpiryTimer(sid)
    if dur and dur > 0 then
        CG._expiry[sid] = GetTime() + dur
        if C_Timer and C_Timer.NewTimer then
            CG._timers[sid] = C_Timer.NewTimer(dur + 0.02, function()
                CG._timers[sid] = nil
                ScheduleEvaluate()
            end)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(dur + 0.02, function()
                ScheduleEvaluate()
            end)
        end
    else
        CG._expiry[sid] = nil
    end
end

function CG.Evaluate()
    if not CG.IsEnabled() then return end
    if not LCG then return end

    local now = GetTime()

    if not next(CG._trackedCache) then
        ComputeTracked()
    end

    local shouldGlow = {}
    local cdDecision = {} -- [canonSid] = boolean (consistent across duplicate buttons/ranks)

    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
            local btn = _G[prefix .. i]
            if btn and btn:IsShown() and btn.action then
                local sid = GetButtonSpellID(btn)
                local canon = sid and ResolveTrackedCanonical(sid) or nil
                if canon then
                    local dur = CG.GetDuration(canon)
                    if dur == -1 then
                        CG._expiry[canon] = nil
                        CancelExpiryTimer(canon)
                        CG._wasCd[canon] = nil
                    else
                        local onCd = cdDecision[canon]
                        if onCd == nil then
                            onCd = IsOnCooldown(btn, sid, canon, now)
                            cdDecision[canon] = onCd
                        end
                        if onCd then
                            CG._expiry[canon] = nil
                            CancelExpiryTimer(canon)
                            CG._wasCd[canon] = true
                        else
                            if dur > 0 then
                                if CG._wasCd[canon] or CG._wasCd[canon] == nil or not CG._expiry[canon] then
                                    SetExpiry(canon, dur)
                                end
                            else
                                CG._expiry[canon] = nil
                            end
                            CG._wasCd[canon] = false
                            local exp = CG._expiry[canon]
                            if exp and now >= exp then
                                shouldGlow[btn] = false
                            else
                                shouldGlow[btn] = true
                                if not CG._glowing[btn] then
                                    ProcGlowStart(btn)
                                    CG._glowing[btn] = canon
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for btn in pairs(CG._glowing) do
        if not shouldGlow[btn] then
            StopGlow(btn)
        end
    end
end

function CG.StopAll()
    if not LCG then return end
    for btn in pairs(CG._glowing) do
        ProcGlowStop(btn)
    end
    CG._glowing = {}

    for sid in pairs(CG._timers) do
        CancelExpiryTimer(sid)
    end
    for sid in pairs(CG._castTimers) do
        CancelCastTimer(sid)
    end
    for sid in pairs(CG._cdEndTimers) do
        CancelCdEndTimer(sid)
    end
    for sid in pairs(CG._expiry) do CG._expiry[sid] = nil end
    for sid in pairs(CG._wasCd) do CG._wasCd[sid] = nil end
end

function CG.TestGlow()
    if not LCG then return end
    CG.EnsureDB()
    ComputeTracked()
    local count = 0
    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
            local btn = _G[prefix .. i]
            if btn and btn:IsShown() and btn.action then
                local sid = GetButtonSpellID(btn)
                local canon = sid and ResolveTrackedCanonical(sid) or nil
                if canon and CG.GetDuration(canon) ~= -1 then
                    local dur = CG.GetDuration(canon)
                    if dur == 0 then dur = 1 end
                    CG._wasCd[canon] = true
                    CG._expiry[canon] = nil
                    count = count + 1
                end
            end
        end
    end
    CG.Evaluate()
    if print then
        print(string.format("|cff4dff66QuickCooldownGlow|r: test glow (%d buttons)", count))
    end
end

function CG.PrintDebug()
    local now = GetTime()
    ComputeTracked()
    if not print then return end
    print("|cff4dff66QuickCooldownGlow|r debug (enabled=" .. tostring(CG.IsEnabled()) .. ", LCG=" .. tostring(LCG ~= nil) .. "):")
    local found = 0
    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
            local btn = _G[prefix .. i]
            if btn and btn:IsShown() and btn.action then
                local sid = GetButtonSpellID(btn)
                local canon = sid and ResolveTrackedCanonical(sid) or nil
                if canon then
                    found = found + 1
                    local ok, cd = pcall(GetSpellCD, sid)
                    local sStr, dStr, aStr, gStr = "?", "?", "?", "?"
                    if ok and type(cd) == "table" and not IsSecret(cd) then
                        sStr = IsSecret(cd.startTime) and "SECRET" or tostring(cd.startTime)
                        dStr = IsSecret(cd.duration) and "SECRET" or tostring(cd.duration)
                        aStr = IsSecret(cd.isActive) and "SECRET" or tostring(cd.isActive)
                        gStr = IsSecret(cd.isOnGCD) and "SECRET" or tostring(cd.isOnGCD)
                    end
                    local onCd = IsOnCooldown(btn, sid, canon, now)
                    print(string.format("  %s%d: %s (sid=%d canon=%d src=%s) durOpt=%d onCd=%s wasCd=%s glow=%s [s=%s d=%s act=%s gcd=%s]",
                        prefix, i, CG.GetSpellDisplayName(canon), sid, canon, tostring(CG.GetTrackedSource(canon)),
                        CG.GetDuration(canon), tostring(onCd), tostring(CG._wasCd[canon]), tostring(CG._glowing[btn] ~= nil),
                        sStr, dStr, aStr, gStr))
                end
            end
        end
    end
    if found == 0 then
        print("  (no tracked spells found on visible action bars)")
    end
end

local dirty = false
local dispatchFrame = CreateFrame("Frame")
dispatchFrame:Hide()
dispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    dirty = false
    if CG.IsEnabled() then CG.Evaluate() end
end)

ScheduleEvaluate = function()
    if dirty then return end
    dirty = true
    dispatchFrame:Show()
end

function CG.Start()
    if not LCG then return end
    InvalidateSpellBook()
    ComputeTracked()
    ScheduleEvaluate()
end

function CG.EvaluateNow()
    ScheduleEvaluate()
end

local evFrame = CreateFrame("Frame")
CG._evFrame = evFrame
evFrame:RegisterEvent("PLAYER_LOGIN")
evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
evFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
evFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
evFrame:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
evFrame:RegisterEvent("UPDATE_POSSESS_BAR")
evFrame:RegisterEvent("UPDATE_MACROS")
evFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
evFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
evFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
evFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
evFrame:RegisterEvent("SPELLS_CHANGED")
evFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
evFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
evFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
if evFrame.RegisterUnitEvent then
    evFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
    evFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

evFrame:SetScript("OnEvent", function(_, event, arg1, _, arg3)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if ReadableString(arg1) == "player" then
            OnPlayerSpellCastSucceeded(arg3)
        end
        return
    end

    if SID_INVALIDATE_EVENTS[event] then
        wipe(_sidCache)
    end
    if SPELLBOOK_INVALIDATE_EVENTS[event] then
        InvalidateSpellBook()
        wipe(tooltipCooldownCache)
        ComputeTracked()
    end

    if event == "PLAYER_LOGIN" then
        CG.EnsureDB()
        if CG.IsEnabled() then
            CG.Start()

            C_Timer.After(1.0, function()
                if CG.IsEnabled() then
                    InvalidateSpellBook()
                    ComputeTracked()
                    ScheduleEvaluate()
                end
            end)
            C_Timer.After(3.0, function()
                if CG.IsEnabled() then
                    InvalidateSpellBook()
                    ComputeTracked()
                    ScheduleEvaluate()
                end
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        wipe(_sidCache)
        if CG.OnCombatChanged then CG.OnCombatChanged(false) end
        ScheduleEvaluate()
    elseif event == "PLAYER_REGEN_DISABLED" then
        wipe(_sidCache)
        if CG.OnCombatChanged then CG.OnCombatChanged(true) end
        ScheduleEvaluate()
    else
        ScheduleEvaluate()
    end
end)

local lastTrackedSig = ""
C_Timer.NewTicker(0.5, function()
    local sig = ComputeTracked()
    if not CG.IsEnabled() then
        lastTrackedSig = sig
        return
    end
    local need = false
    if sig ~= lastTrackedSig then
        lastTrackedSig = sig
        need = true
    end
    if not need then
        local now = GetTime()
        for _, wasOnCd in pairs(CG._wasCd) do
            if wasOnCd then
                need = true
                break
            end
        end
        if not need then
            for _, exp in pairs(CG._expiry) do
                if exp and now >= exp then
                    need = true
                    break
                end
            end
        end
        if not need then
            for _, endsAt in pairs(CG._castEndsAt) do
                if endsAt and now >= endsAt then
                    need = true
                    break
                end
            end
        end
    end
    if need then
        ScheduleEvaluate()
    end
end)
