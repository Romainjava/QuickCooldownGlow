-- Options.lua

local CG = EasyCooldownGlow
local L = CG.L

local PANEL_W = 680
local ROW_W   = PANEL_W - 44
local ROW_H   = 36

local VISIBLE_ROWS = 11
local LIST_H = VISIBLE_ROWS * ROW_H

local W_DUR = 116

local ADDON_TITLE = "Quick Cooldown Glow"

local STUB_W = 520

local configFrame
local rows = {}
local refreshing = false

local SOURCE_TAGS = {
    trap      = { key = "TAG_TRAP",      r = 0.45, g = 0.85, b = 1.0  },
    utility   = { key = "TAG_UTILITY",   r = 0.72, g = 0.78, b = 0.92 },
    important = { key = "TAG_IMPORTANT", r = 1.0,  g = 0.82, b = 0.35 },
}

local function AddTip(widget, text)
    local prevEnter = widget:GetScript("OnEnter")
    local prevLeave = widget:GetScript("OnLeave")
    widget:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function(self, ...)
        if prevLeave then prevLeave(self, ...) end
        GameTooltip:Hide()
    end)
end

local function SetDdText(dd, text)
    if dd.SetText then
        dd:SetText(text)
    elseif dd.SetDefaultText then
        dd:SetDefaultText(text)
    end
end

local function SetupDurMenu(dd)
    dd:SetupMenu(function(_, rootDescription)
        for _, v in ipairs(CG.DUR_VALUES) do
            rootDescription:CreateRadio(CG.DurationLabel(v), function()
                return (CG.GetDuration(dd._spellID) or 0) == v
            end, function()
                if InCombatLockdown() or not dd._spellID then return end
                CG.SetDuration(dd._spellID, v)
                SetDdText(dd, CG.DurationLabel(v))
            end)
        end
    end)
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, configFrame.rows)
    row:SetSize(ROW_W, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)

    row.icon = CreateFrame("Button", nil, row)
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon.tex = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.tex:SetAllPoints()
    row.icon:SetScript("OnEnter", function(self)
        local id = self.spellID
        if not id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(id)
        else
            GameTooltip:SetText(CG.GetSpellDisplayName(id))
        end
        GameTooltip:Show()
    end)
    row.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetJustifyH("LEFT")

    row.tag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tag:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.tag:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", row.tag, "RIGHT", 8, 0)
    row.status:SetJustifyH("LEFT")

    row.durDd = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    row.durDd:SetSize(W_DUR, 24)
    row.durDd:SetPoint("RIGHT", -28, 0)
    SetupDurMenu(row.durDd)
    AddTip(row.durDd, L("COL_DURATION"))

    return row
end

local function UpdateRow(row, spellID, barSet)
    row.name:SetText(CG.GetSpellDisplayName(spellID))
    row.icon.spellID = spellID
    row.icon.tex:SetTexture(CG.GetSpellIcon(spellID))

    local src = CG.GetTrackedSource and CG.GetTrackedSource(spellID) or nil
    local tagInfo = src and SOURCE_TAGS[src] or nil
    if tagInfo then
        row.tag:SetText("[" .. L(tagInfo.key) .. "]")
        row.tag:SetTextColor(tagInfo.r, tagInfo.g, tagInfo.b)
    else
        row.tag:SetText("")
    end

    if barSet and not barSet[spellID] then
        row.status:SetText(L("STATUS_NOT_ON_BAR"))
        row.status:SetTextColor(1, 0.4, 0.4)
    else
        row.status:SetText("")
    end

    row.durDd._spellID = spellID
    SetDdText(row.durDd, CG.DurationLabel(CG.GetDuration(spellID)))
end

local function BuildRowList()
    local seenID, seenName, list = {}, {}, {}
    local function add(id)
        if not id or seenID[id] then return end
        local name = CG.GetSpellName(id)
        if name and seenName[name] then return end
        seenID[id] = true
        if name then seenName[name] = true end
        list[#list + 1] = id
    end
    for id in pairs(CG.GetTrackedSpellIDs()) do add(id) end
    local specID = CG.GetCurrentSpecID()
    local db = quickCooldownGlowDB
    local specs = db and db.specs
    local durs = specs and specs[specID] and specs[specID].durations
    if durs then
        for id in pairs(durs) do add(id) end
    end
    table.sort(list, function(a, b)
        return CG.GetSpellDisplayName(a) < CG.GetSpellDisplayName(b)
    end)
    return list
end

local function DoRefresh()
    if not configFrame then return end

    local specName = L("SPEC_UNKNOWN")
    local specID, name = CG.GetSpecInfo()
    if name and name ~= "" then
        specName = name
    elseif specID then
        specName = tostring(specID)
    end

    configFrame.specText:SetText(
        L("CLASS_LABEL") .. ": " .. (UnitClass("player"))
        .. " - " .. L("SPEC_LABEL") .. ": " .. specName)

    if configFrame.enableCheck then
        configFrame.enableCheck:SetChecked(CG.IsEnabled())
    end
    if configFrame.utilityCheck then
        configFrame.utilityCheck:SetChecked(CG.IsUtilityEnabled())
    end
    if configFrame.importantCheck then
        configFrame.importantCheck:SetChecked(CG.IsImportantEnabled())
    end

    local list = BuildRowList()
    local barSet = CG.GetBarSpellIDs()

    for i = 1, #list do
        local spellID = list[i]
        local row = rows[i]
        if not row then
            row = CreateRow(i)
            rows[i] = row
        end
        row.spellID = spellID
        row:Show()
        UpdateRow(row, spellID, barSet)
    end
    for i = #list + 1, #rows do
        rows[i].spellID = nil
        rows[i].icon.spellID = nil
        rows[i]:Hide()
    end

    local count = math.max(#list, 1)

    local empty = (#list == 0)
    configFrame.noSpells:SetShown(empty)
    configFrame.scroll:SetShown(not empty)
    configFrame.rows:SetSize(ROW_W, count * ROW_H)

    if configFrame.scroll.UpdateScrollChildRect then
        pcall(configFrame.scroll.UpdateScrollChildRect, configFrame.scroll)
    end

    local pTop, rTop = configFrame:GetTop(), configFrame.scroll:GetTop()
    local headerH = (pTop and rTop and pTop > rTop) and (pTop - rTop) or 116
    configFrame:SetSize(PANEL_W, headerH + LIST_H + 20)
end

function CG.RefreshPanel()
    if not configFrame or refreshing then return end
    refreshing = true
    pcall(DoRefresh)
    refreshing = false
end

local function BuildConfigFrame()
    configFrame = CreateFrame("Frame", "EasyCooldownGlowConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(PANEL_W, 360)
    configFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:SetClampedToScreen(true)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:Hide()

    local titleText = (configFrame.TitleContainer and configFrame.TitleContainer.TitleText) or configFrame.TitleText
    if titleText then titleText:SetText(ADDON_TITLE) end

    configFrame.specText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    configFrame.specText:SetPoint("TOPLEFT", 16, -36)

    configFrame.enableCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    configFrame.enableCheck:SetSize(24, 24)
    configFrame.enableCheck:SetPoint("TOPRIGHT", -14, -32)
    configFrame.enableLabel = configFrame.enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configFrame.enableLabel:SetPoint("RIGHT", configFrame.enableCheck, "LEFT", -4, 0)
    configFrame.enableLabel:SetText(L("ENABLE"))
    configFrame.enableCheck:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(not self:GetChecked())
            return
        end
        CG.SetEnabled(self:GetChecked() and true or false)
    end)

    configFrame.utilityCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    configFrame.utilityCheck:SetSize(22, 22)
    configFrame.utilityCheck:SetPoint("TOPLEFT", 14, -56)
    configFrame.utilityLabel = configFrame.utilityCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configFrame.utilityLabel:SetPoint("LEFT", configFrame.utilityCheck, "RIGHT", 2, 0)
    configFrame.utilityLabel:SetText(L("OPT_UTILITY"))
    AddTip(configFrame.utilityCheck, L("TIP_UTILITY"))
    configFrame.utilityCheck:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(not self:GetChecked())
            return
        end
        CG.SetUtilityEnabled(self:GetChecked() and true or false)
        CG.RefreshPanel()
    end)

    configFrame.importantCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    configFrame.importantCheck:SetSize(22, 22)
    configFrame.importantCheck:SetPoint("LEFT", configFrame.utilityLabel, "RIGHT", 18, 0)
    configFrame.importantLabel = configFrame.importantCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    configFrame.importantLabel:SetPoint("LEFT", configFrame.importantCheck, "RIGHT", 2, 0)
    configFrame.importantLabel:SetText(L("OPT_IMPORTANT"))
    AddTip(configFrame.importantCheck, L("TIP_IMPORTANT"))
    configFrame.importantCheck:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(not self:GetChecked())
            return
        end
        CG.SetImportantEnabled(self:GetChecked() and true or false)
        CG.RefreshPanel()
    end)

    configFrame.divTitle = configFrame:CreateTexture(nil, "ARTWORK")
    configFrame.divTitle:SetColorTexture(0.7, 0.7, 0.7, 0.35)
    configFrame.divTitle:SetSize(PANEL_W - 24, 1)
    configFrame.divTitle:SetPoint("TOPLEFT", 12, -84)

    configFrame.noSpells = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    configFrame.noSpells:SetPoint("TOPLEFT", 18, -96)
    configFrame.noSpells:SetWidth(PANEL_W - 40)
    configFrame.noSpells:SetJustifyH("LEFT")
    configFrame.noSpells:SetText(L("NO_SPELLS"))
    configFrame.noSpells:Hide()

    configFrame.scroll = CreateFrame("ScrollFrame", "EasyCooldownGlowConfigScroll", configFrame, "UIPanelScrollFrameTemplate")
    configFrame.scroll:SetPoint("TOPLEFT", 16, -92)
    configFrame.scroll:SetSize(ROW_W, LIST_H)
    configFrame.scroll:EnableMouseWheel(true)
    configFrame.scroll:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar or _G["EasyCooldownGlowConfigScrollScrollBar"]
        if not bar or not bar:IsShown() then return end
        local lo, hi = bar:GetMinMaxValues()
        local v = (bar:GetValue() or 0) - delta * ROW_H
        if v < lo then v = lo elseif v > hi then v = hi end
        bar:SetValue(v)
    end)

    configFrame.rows = CreateFrame("Frame", nil, configFrame.scroll)
    configFrame.rows:SetPoint("TOPLEFT", configFrame.scroll, "TOPLEFT", 0, 0)
    configFrame.rows:SetSize(ROW_W, LIST_H)
    configFrame.scroll:SetScrollChild(configFrame.rows)

    local bar = configFrame.scroll.ScrollBar or _G["EasyCooldownGlowConfigScrollScrollBar"]
    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", configFrame.scroll, "TOPRIGHT", -2, -14)
        bar:SetPoint("BOTTOMRIGHT", configFrame.scroll, "BOTTOMRIGHT", -2, 14)
    end

    configFrame:SetScript("OnShow", function()
        CG.EnsureDB()
        CG.Rescan()
        CG.RefreshPanel()
    end)
end

function CG.ShowConfigFrame()
    if InCombatLockdown() then return end
    if not configFrame then BuildConfigFrame() end

    if EasyMinimapHub and EasyMinimapHub.NotifyConfigFrameShown then
        EasyMinimapHub.NotifyConfigFrameShown(configFrame)
    end
    configFrame:Show()
end

function CG.ToggleConfigFrame()
    if InCombatLockdown() then return end
    if not configFrame then BuildConfigFrame() end
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        if EasyMinimapHub and EasyMinimapHub.NotifyConfigFrameShown then
            EasyMinimapHub.NotifyConfigFrameShown(configFrame)
        end
        configFrame:Show()
    end
end

function CG.OnCombatChanged(inCombat)
    if not configFrame then return end
    if inCombat then
        if configFrame:IsShown() then
            CG._restoreConfig = true
            configFrame:Hide()
        end
    elseif CG._restoreConfig then
        CG._restoreConfig = nil
        CG.ShowConfigFrame()
    end
end

local function BuildBlizzardStub()
    local stub = CreateFrame("Frame")
    stub:SetSize(STUB_W, 200)

    stub.OnCommit  = function() end
    stub.OnDefault = function() end
    stub.OnRefresh = function() end

    local title = stub:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", stub, "TOP", 0, -18)

    title:SetFont(STANDARD_TEXT_FONT, 22, "")
    title:SetTextColor(0.910, 0.737, 0.459)
    title:SetText(ADDON_TITLE)

    local hint = stub:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOP", stub, "TOP", 0, -64)
    hint:SetWidth(STUB_W - 40)
    hint:SetJustifyH("CENTER")
    hint:SetText(L("STUB_HINT"))

    local template = "SharedButtonLargeTemplate"
    local hasTemplate = false
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, template)
        hasTemplate = ok and info ~= nil
    end
    if not hasTemplate then template = "UIPanelDynamicResizeButtonTemplate" end
    local button = CreateFrame("Button", nil, stub, template)
    button:SetText(L("OPEN_OPTIONS"))
    button.padding = 40
    if DynamicResizeButton_Resize then pcall(DynamicResizeButton_Resize, button) end
    button:SetPoint("TOP", hint, "BOTTOM", 0, -30)
    button:SetScript("OnClick", function() CG.ToggleConfigFrame() end)

    return stub
end

local function RegisterSettings()
    if CG._stubRegistered then return end
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    CG._stubRegistered = true
    local stub = BuildBlizzardStub()

    local category = Settings.RegisterCanvasLayoutCategory(stub, ADDON_TITLE)
    Settings.RegisterAddOnCategory(category)
end

SLASH_EASYCOOLDOWNGLOW1 = "/ecg"
SLASH_EASYCOOLDOWNGLOW2 = "/qcg"
SlashCmdList["EASYCOOLDOWNGLOW"] = function(msg)
    local cmd = type(msg) == "string" and string.lower(string.gsub(msg, "^%s*(.-)%s*$", "%1")) or ""
    if cmd == "test" then
        if CG.TestGlow then CG.TestGlow() end
    elseif cmd == "debug" then
        if CG.PrintDebug then CG.PrintDebug() end
    else
        CG.ToggleConfigFrame()
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent(event)
    RegisterSettings()
    BuildConfigFrame()
    CG.RefreshPanel()
end)
