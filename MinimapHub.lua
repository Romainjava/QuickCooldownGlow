-- MinimapHub.lua

local ADDON_NAME = ...

local HUB = _G.EasyMinimapHub
local IS_CREATOR = false
if not HUB then
    HUB = { addons = {} }
    _G.EasyMinimapHub = HUB
    IS_CREATOR = true
end

local configFrames = {}
function HUB.NotifyConfigFrameShown(frame)
    if not frame then return end
    local known = false
    for _, f in ipairs(configFrames) do
        if f == frame then
            known = true
        elseif f.IsShown and f:IsShown() then
            f:Hide()
        end
    end
    if not known then
        configFrames[#configFrames + 1] = frame
    end
end

local L = {
    TITLE     = "Easy Add-ons",
    HINT_MENU = "Left-click: plugin menu",
    HINT_MOVE = "Right-drag: move button",
}

if IS_CREATOR then

    local function DB()
        if type(EasyMinimapHubDB) ~= "table" then
            EasyMinimapHubDB = {}
        end
        if EasyMinimapHubDB.angle == nil then
            EasyMinimapHubDB.angle = 220
        end
        return EasyMinimapHubDB
    end
    DB()

    local ITEM_H = 22
    local PAD    = 6

    local RADIUS_BIAS = 8

    local btn = CreateFrame("Button", "EasyMinimapButton", Minimap)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetSize(31, 31)
    btn:RegisterForClicks("AnyUp")

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local HAS_COMPARTMENT = _G.AddonCompartmentFrame ~= nil

    local icon = btn:CreateTexture(nil, "ARTWORK")
    if HAS_COMPARTMENT then
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER")
    else
        icon:SetSize(17, 17)
        icon:SetPoint("TOPLEFT", 7, -6)
    end
    icon:SetMask("Interface\\Minimap\\MinimapMask")
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    local borderSize = HAS_COMPARTMENT and 50 or 53
    border:SetSize(borderSize, borderSize)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local iconSet = false
    function HUB.SetIcon(tex)
        if tex and not iconSet then
            icon:SetTexture(tex)
            iconSet = true
        end
    end

    local function UpdatePosition()
        local a = math.rad(DB().angle)
        local r = Minimap:GetWidth() / 2 + RADIUS_BIAS
        btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end

    local dragging = false
    btn:SetScript("OnUpdate", function()
        if not dragging then return end
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local s = Minimap:GetEffectiveScale()
        px, py = px / s, py / s
        local dx, dy = px - mx, py - my
        if dx ~= 0 or dy ~= 0 then
            DB().angle = math.deg(math.atan2(dy, dx))
            UpdatePosition()
        end
    end)
    btn:SetScript("OnMouseDown", function(_, mouse)
        if mouse == "RightButton" then dragging = true end
    end)
    btn:SetScript("OnMouseUp", function(_, mouse)
        if mouse == "RightButton" then dragging = false end
    end)

    local menu = CreateFrame("Frame", "EasyMinimapMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    menu:SetBackdropColor(0, 0, 0, 0.9)
    menu:SetBackdropBorderColor(0.4, 0.4, 0.4)
    menu:Hide()

    local cloak = CreateFrame("Frame", "EasyMinimapMenuCloak", UIParent)
    cloak:SetFrameStrata("HIGH")
    cloak:SetAllPoints(UIParent)
    cloak:EnableMouse(true)
    cloak:Hide()

    local pool = {}
    local function GetItem(idx)
        local item = pool[idx]
        if not item then
            item = CreateFrame("Button", nil, menu)
            item:SetSize(194, ITEM_H)
            item:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            local ic = item:CreateTexture(nil, "ARTWORK")
            ic:SetSize(16, 16)
            ic:SetPoint("LEFT", 8, 0)
            local tx = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            tx:SetPoint("LEFT", ic, "RIGHT", 6, 0)
            item.icon, item.text = ic, tx
            pool[idx] = item
        end
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -(PAD + (idx - 1) * ITEM_H) - 2)
        item:Show()
        return item
    end

    local function CloseMenu()
        cloak:Hide()
        menu:Hide()
    end

    local function OpenMenu()
        local n = #HUB.addons
        if n == 0 then return end
        for i, a in ipairs(HUB.addons) do
            local item = GetItem(i)
            item.icon:SetTexture(a.icon)
            item.text:SetText(a.title)
            item:SetScript("OnClick", function()
                CloseMenu()
                if a.toggle then a.toggle() end
            end)
        end
        for i = n + 1, #pool do
            pool[i]:Hide()
        end

        local textW = 0
        for i = 1, n do
            local w = pool[i].text:GetStringWidth()
            if w > textW then textW = w end
        end
        local menuW = 8 + 16 + 6 + math.ceil(textW) + 12
        for i = 1, n do
            pool[i]:SetSize(menuW - 16, ITEM_H)
        end
        menu:SetSize(menuW, PAD * 2 + n * ITEM_H)

        menu:ClearAllPoints()
        menu:SetPoint("TOPRIGHT", btn, "TOPLEFT", -6, 4)
        cloak:Show()
        menu:Show()
    end

    cloak:SetScript("OnMouseDown", CloseMenu)

    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "LeftButton" then
            if menu:IsShown() then CloseMenu() else OpenMenu() end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L.TITLE, 1, 0.82, 0.46)
        GameTooltip:AddLine(L.HINT_MENU, 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L.HINT_MOVE, 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()

    C_Timer.After(0, UpdatePosition)
end -- IS_CREATOR

--   HUB.Register(name, title, icon, toggle)

function HUB.Register(name, title, icon, toggle)
    for _, a in ipairs(HUB.addons) do
        if a.name == name then return end
    end
    HUB.addons[#HUB.addons + 1] = { name = name, title = title, icon = icon, toggle = toggle }
    if HUB.SetIcon then HUB.SetIcon(icon) end
end

HUB.Register(ADDON_NAME, "Easy Cooldown Glow 1s", "Interface\\AddOns\\EasyCooldownGlow1s\\ButtonIcon.tga", function()
    if EasyCooldownGlow and EasyCooldownGlow.ToggleConfigFrame then
        EasyCooldownGlow.ToggleConfigFrame()
    end
end)
