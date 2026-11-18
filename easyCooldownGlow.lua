-- easyCooldownGlow.lua
-- Easy Cooldown Glow

EasyCooldownGlow = EasyCooldownGlow or {}
local CG = EasyCooldownGlow
CG.ADDON_NAME = ...

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local LOCALES = {
    enUS = {
        SPEC_LABEL        = "Config Spec",
        CLASS_LABEL       = "Current Class",
        SPEC_UNKNOWN      = "Unknown",
        PAGE_DESC         = "Spells enabled in Blizzard's Cooldown Manager (Essential cooldowns) glow on the action bar when their cooldown finishes. Pick how long each spell stays lit.",
        NO_SPELLS         = "No spells found. Enable cooldowns in Blizzard's Cooldown Manager (Essential cooldowns) first, then reopen this page.",
        ENABLE            = "Enable",
        COL_DURATION      = "Glow",
        DUR_PERSISTENT    = "Persistent",
        DUR_SEC           = "%d sec",
        DUR_NONE          = "None",
        STATUS_NOT_ON_BAR = "not on action bars",
        OPEN_OPTIONS      = "Open Options",
        STUB_HINT         = "Click the button below, or type /ecg, to open the configuration window.",
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

local function IsSecret(v)
    local ok, res = pcall(function() return issecretvalue and issecretvalue(v) end)
    return ok and res
end
CG.IsSecret = IsSecret

function CG.GetSpellDisplayName(sid)
    if sid and C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, sid)
        if ok and name then return name end
    end
    return sid and tostring(sid) or ""
end

function CG.GetSpellIcon(sid)
    if sid and C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, sid)
        if ok and icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local ScheduleEvaluate
local SetExpiry

function CG.EnsureDB()
    easyCooldownGlowDB = easyCooldownGlowDB or {}

end

local function SpecGetIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, idx = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and idx and idx > 0 then return idx end
    end
    if GetSpecialization then
        local ok, idx = pcall(GetSpecialization)
        if ok and idx and idx > 0 then return idx end
    end
    return nil
end

function CG.GetSpecInfo(specIndex)
    local idx = specIndex or SpecGetIndex()
    if not idx or idx <= 0 then return nil end
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local ok, id, name = pcall(C_SpecializationInfo.GetSpecializationInfo, idx)
        if ok and id then return id, name end
    end
    if GetSpecializationInfo then
        local ok, id, name = pcall(GetSpecializationInfo, idx)
        if ok and id then return id, name end
    end
    return nil
end

local function GetCurrentSpecID()
    return CG.GetSpecInfo() or 0
end
CG.GetCurrentSpecID = GetCurrentSpecID

local function GetSpecSlot(specID)
    CG.EnsureDB()
    local db = easyCooldownGlowDB
    db.specs = db.specs or {}
    local spec = db.specs[specID] or {}
    db.specs[specID] = spec
    if spec.enabled == nil then
        spec.enabled = (easyCooldownGlowDB.enabled ~= false)
    end
    spec.durations = spec.durations or {}
    return spec
end

function CG.IsEnabled()
    if not easyCooldownGlowDB then return nil end
    local specs = easyCooldownGlowDB.specs
    local spec = specs and specs[GetCurrentSpecID()]
    if spec and spec.enabled ~= nil then
        return spec.enabled
    end
    return easyCooldownGlowDB.enabled ~= false
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

local function GetDurations(specID)
    return GetSpecSlot(specID).durations
end

function CG.GetDuration(sid)
    if not easyCooldownGlowDB then return 1 end
    local specID = GetCurrentSpecID()
    local specs = easyCooldownGlowDB.specs
    local durs = specs and specs[specID] and specs[specID].durations
    local v = durs and durs[sid]
    if v == nil then return 1 end
    return v
end

function CG.SetDuration(sid, n)
    CG.EnsureDB()
    local durs = GetDurations(GetCurrentSpecID())
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

local function ResolveSpellID(info)
    if not info then return nil end
    if info.linkedSpellIDs and info.linkedSpellIDs[1] then
        return info.linkedSpellIDs[1]
    end
    return info.overrideSpellID or info.spellID
end

local function GetTrackedFromViewer()
    local set = {}
    local viewer = _G.EssentialCooldownViewer
    if not viewer or not viewer.itemFramePool or not viewer.itemFramePool.EnumerateActive then
        return set
    end
    for frame in viewer.itemFramePool:EnumerateActive() do
        local cid = frame and frame.cooldownID
        if cid then
            local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, cid)
            if ok and info then
                local sid = ResolveSpellID(info)
                if sid and sid > 0 then set[sid] = true end

                if info.linkedSpellIDs then
                    for _, lsid in ipairs(info.linkedSpellIDs) do
                        if lsid and lsid > 0 then set[lsid] = true end
                    end
                end
            end
        end
    end
    return set
end

CG._trackedCache = CG._trackedCache or {}

local function ComputeTracked()
    local set = GetTrackedFromViewer()
    CG._trackedCache = set
    local ids = {}
    for sid in pairs(set) do
        ids[#ids + 1] = sid
    end
    table.sort(ids)
    return table.concat(ids, ",")
end

local function GetTrackedSpellIDs()
    if not next(CG._trackedCache) then
        return GetTrackedFromViewer()
    end
    return CG._trackedCache
end
CG.GetTrackedSpellIDs = GetTrackedSpellIDs

function CG.Rescan()
    ComputeTracked()
end

local GetSpellCD = (C_Spell and C_Spell.GetSpellCooldown) or nil

local function IsOnCooldown(btn, sid)
    if not sid then return false end
    if not GetSpellCD then

        if btn and btn.cooldown and btn.cooldown:IsShown() then return true end
        if btn and btn.chargeCooldown and btn.chargeCooldown:IsShown() then return true end
        return false
    end
    local ok, cd = pcall(GetSpellCD, sid)
    if ok and type(cd) == "table" then
        if cd.isActive and not cd.isOnGCD then return true end
        return false
    end

    return false
end

local ACTION_BAR_PREFIXES = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
}
CG.ACTION_BAR_PREFIXES = ACTION_BAR_PREFIXES

local _sidCache = setmetatable({}, { __mode = "k" })

local function ComputeButtonSpellID(btn)
    if not btn.action then return nil end
    local ok, at, id = pcall(GetActionInfo, btn.action)
    if not ok or not at or not id then return nil end
    if at == "spell" then
        return (id > 0) and id or nil
    elseif at == "macro" then
        if not (id and id > 0) then return nil end

        local sid
        if C_Macro and C_Macro.GetMacroSpell then
            local _, spellID = C_Macro.GetMacroSpell(id)
            sid = spellID
        elseif GetMacroSpell then
            local _, spellID = GetMacroSpell(id)
            sid = spellID
        end

        if not (sid and sid > 0) then
            local okN, nm = pcall(CG.GetSpellDisplayName, id)
            if okN and nm and nm ~= tostring(id) then sid = id end
        end
        return (sid and sid > 0) and sid or nil
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
    SPELLS_CHANGED              = true,
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
                if sid then set[sid] = true end
            end
        end
    end
    return set
end

CG._glowing = CG._glowing or {}   -- [button] = spellID
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

function SetExpiry(sid, dur)
    if dur and dur > 0 then
        CG._expiry[sid] = GetTime() + dur
        if CG._timers[sid] then
            pcall(CG._timers[sid].Cancel, CG._timers[sid])
            CG._timers[sid] = nil
        end
        CG._timers[sid] = C_Timer.After(dur, function()
            CG._timers[sid] = nil
            ScheduleEvaluate()
        end)
    else
        CG._expiry[sid] = nil

        if CG._timers[sid] then
            pcall(CG._timers[sid].Cancel, CG._timers[sid])
            CG._timers[sid] = nil
        end
    end
end

function CG.Evaluate()
    if not CG.IsEnabled() then return end
    if not LCG then return end

    local now = GetTime()

    local tracked = GetTrackedSpellIDs()
    local specID = GetCurrentSpecID()
    local specs = easyCooldownGlowDB and easyCooldownGlowDB.specs
    local durs = (specs and specs[specID] and specs[specID].durations) or {}

    local shouldGlow = {}
    for _, prefix in ipairs(ACTION_BAR_PREFIXES) do
        for i = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
            local btn = _G[prefix .. i]
            if btn and btn:IsShown() and btn.action then
                local sid = GetButtonSpellID(btn)
                if sid and sid > 0 and tracked[sid] then
                    local dur = durs[sid]
                    if dur == nil then dur = 1 end
                    if dur == -1 then

                        CG._expiry[sid] = nil
                        if CG._timers[sid] then
                            pcall(CG._timers[sid].Cancel, CG._timers[sid])
                            CG._timers[sid] = nil
                        end
                        CG._wasCd[sid] = nil
                    else
                        local onCd = IsOnCooldown(btn, sid)
                        if onCd then

                            CG._expiry[sid] = nil
                            if CG._timers[sid] then
                                pcall(CG._timers[sid].Cancel, CG._timers[sid])
                                CG._timers[sid] = nil
                            end
                            CG._wasCd[sid] = true
                        else

                            if dur > 0 then
                                if CG._wasCd[sid] or CG._wasCd[sid] == nil or not CG._expiry[sid] then
                                    SetExpiry(sid, dur)
                                end
                            else
                                CG._expiry[sid] = nil
                            end
                            CG._wasCd[sid] = false
                            local exp = CG._expiry[sid]
                            if exp and now > exp then
                                shouldGlow[btn] = false
                            else
                                shouldGlow[btn] = true
                                if not CG._glowing[btn] then
                                    ProcGlowStart(btn)
                                    CG._glowing[btn] = sid
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

    for sid, t in pairs(CG._timers) do
        pcall(t.Cancel, t)
        CG._timers[sid] = nil
    end
    for sid in pairs(CG._expiry) do CG._expiry[sid] = nil end
    for sid in pairs(CG._wasCd) do CG._wasCd[sid] = nil end
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
evFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
evFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
evFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
evFrame:RegisterEvent("SPELLS_CHANGED")
evFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
evFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

evFrame:SetScript("OnEvent", function(_, event)

    if SID_INVALIDATE_EVENTS[event] then
        wipe(_sidCache)
    end
    if event == "PLAYER_LOGIN" then
        CG.EnsureDB()
        if CG.IsEnabled() then
            CG.Start()

            C_Timer.After(1.0, function()
                if CG.IsEnabled() then ScheduleEvaluate() end
            end)
            C_Timer.After(3.0, function()
                if CG.IsEnabled() then ScheduleEvaluate() end
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then

        if CG.OnCombatChanged then CG.OnCombatChanged(false) end
    elseif event == "PLAYER_REGEN_DISABLED" then

        if CG.OnCombatChanged then CG.OnCombatChanged(true) end
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
        for _, exp in pairs(CG._expiry) do
            if exp and now > exp then
                need = true
                break
            end
        end
    end
    if need then
        ScheduleEvaluate()
    end
end)
