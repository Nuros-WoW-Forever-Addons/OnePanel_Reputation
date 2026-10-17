--[[
    OnePanel_Reputation - Core.lua
    Modular Reputation management plugin for OnePanel Suite.
    Featuring real-time search filtering, collapsible expansion headers,
    color-coded standing progress bars, exact reputation counters,
    and interactive faction management (Watch on XP bar, At War, Inactive).
--]]

local addonName, addonTable = ...
local OnePanel = _G.OnePanel
local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- Constants & Reputation Configuration
-------------------------------------------------------------------------------

local STANDING_LABELS = {
    [1] = _G["FACTION_STANDING_LABEL1"] or "Hated",
    [2] = _G["FACTION_STANDING_LABEL2"] or "Hostile",
    [3] = _G["FACTION_STANDING_LABEL3"] or "Unfriendly",
    [4] = _G["FACTION_STANDING_LABEL4"] or "Neutral",
    [5] = _G["FACTION_STANDING_LABEL5"] or "Friendly",
    [6] = _G["FACTION_STANDING_LABEL6"] or "Honored",
    [7] = _G["FACTION_STANDING_LABEL7"] or "Revered",
    [8] = _G["FACTION_STANDING_LABEL8"] or "Exalted",
}

-- Bright, vibrant text colors for standing labels displayed on dark backgrounds
local STANDING_TEXT_COLORS = {
    [1] = { r = 0.95, g = 0.25, b = 0.25, hex = "f24040" }, -- Hated (Red)
    [2] = { r = 1.00, g = 0.35, b = 0.35, hex = "ff5959" }, -- Hostile (Red)
    [3] = { r = 1.00, g = 0.65, b = 0.20, hex = "ffa633" }, -- Unfriendly (Orange)
    [4] = { r = 1.00, g = 0.85, b = 0.20, hex = "ffd933" }, -- Neutral (Yellow/Gold)
    [5] = { r = 0.30, g = 0.90, b = 0.30, hex = "4de64d" }, -- Friendly (Green)
    [6] = { r = 0.20, g = 0.75, b = 1.00, hex = "33bfff" }, -- Honored (Blue)
    [7] = { r = 0.75, g = 0.45, b = 1.00, hex = "bf73ff" }, -- Revered (Purple)
    [8] = { r = 0.20, g = 0.95, b = 0.80, hex = "33f2cc" }, -- Exalted (Teal)
}

-- Rich, deeper tones calibrated specifically for progress bar fills to ensure
-- pure white text and numbers maintain maximum readability and high contrast
local BAR_FILL_COLORS = {
    [1] = { r = 0.65, g = 0.10, b = 0.10 }, -- Hated (Deep Crimson)
    [2] = { r = 0.75, g = 0.15, b = 0.15 }, -- Hostile (Dark Red)
    [3] = { r = 0.75, g = 0.42, b = 0.08 }, -- Unfriendly (Rust Orange)
    [4] = { r = 0.68, g = 0.52, b = 0.06 }, -- Neutral (Rich Amber Bronze - high contrast with white text!)
    [5] = { r = 0.12, g = 0.52, b = 0.14 }, -- Friendly (Deep Forest Green)
    [6] = { r = 0.08, g = 0.42, b = 0.72 }, -- Honored (Deep Cobalt Blue)
    [7] = { r = 0.45, g = 0.18, b = 0.72 }, -- Revered (Deep Royal Purple)
    [8] = { r = 0.00, g = 0.58, b = 0.48 }, -- Exalted (Deep Teal)
}

local function GetBarFillColor(standingID)
    local c = BAR_FILL_COLORS[standingID] or BAR_FILL_COLORS[4]
    return c.r, c.g, c.b
end

local function GetStandingColor(standingID)
    local c = STANDING_TEXT_COLORS[standingID] or STANDING_TEXT_COLORS[4]
    return c.r, c.g, c.b
end

local function GetStandingHex(standingID)
    local c = STANDING_TEXT_COLORS[standingID] or STANDING_TEXT_COLORS[4]
    return c.hex or "ffffff"
end

local function GetStandardFont()
    local fontObj = _G.GameFontHighlight or _G.SystemFont_Med1 or _G.GameFontNormal
    if fontObj and fontObj.GetFont then
        local fontPath = fontObj:GetFont()
        if fontPath and fontPath ~= "" then return fontPath end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetStatusBarFont()
    return GetStandardFont()
end

local function SafeHasAtlas(atlasName)
    if not atlasName then return false end
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlasName)
        return ok and info ~= nil
    end
    return false
end

local function ApplyModernReputationBarTexture(bar, standingID)
    if not bar then return end

    local atlas = nil
    local r, g, b = 1, 1, 1

    if standingID == 8 then -- Exalted
        if SafeHasAtlas("ui-castingbar-full-applyingcrafting") then
            atlas = "ui-castingbar-full-applyingcrafting"
        elseif SafeHasAtlas("ui-castingbar-filling-channel") then
            atlas = "ui-castingbar-filling-channel"
        end
    elseif standingID == 7 then -- Revered (Royal Purple)
        if SafeHasAtlas("common-stat-bar-white") then
            atlas = "common-stat-bar-white"
            r, g, b = 0.70, 0.35, 1.00
        elseif SafeHasAtlas("ui-castingbar-filling-standard") then
            atlas = "ui-castingbar-filling-standard"
            r, g, b = 0.85, 0.45, 1.00
        end
    elseif standingID == 6 then -- Honored (Jade/Turquoise)
        if SafeHasAtlas("ui-castingbar-filling-channel") then
            atlas = "ui-castingbar-filling-channel"
        end
    elseif standingID == 5 then -- Friendly (Green)
        if SafeHasAtlas("ui-castingbar-filling-applyingcrafting") then
            atlas = "ui-castingbar-filling-applyingcrafting"
        end
    elseif standingID == 4 then -- Neutral (Amber Gold)
        if SafeHasAtlas("ui-castingbar-filling-standard") then
            atlas = "ui-castingbar-filling-standard"
        end
    elseif standingID == 3 then -- Unfriendly (Rust Orange)
        if SafeHasAtlas("common-stat-bar-white") then
            atlas = "common-stat-bar-white"
            r, g, b = 1.00, 0.55, 0.15
        elseif SafeHasAtlas("ui-castingbar-filling-standard") then
            atlas = "ui-castingbar-filling-standard"
            r, g, b = 1.00, 0.60, 0.20
        end
    else -- Hated / Hostile (Crimson Red)
        if SafeHasAtlas("common-stat-bar-white") then
            atlas = "common-stat-bar-white"
            r, g, b = 0.95, 0.22, 0.22
        elseif SafeHasAtlas("ui-castingbar-filling-standard") then
            atlas = "ui-castingbar-filling-standard"
            r, g, b = 1.00, 0.30, 0.30
        end
    end

    if not atlas then
        if SafeHasAtlas("ui-castingbar-filling-standard") then
            atlas = "ui-castingbar-filling-standard"
        elseif SafeHasAtlas("common-stat-bar-white") then
            atlas = "common-stat-bar-white"
        end
    end

    if atlas then
        pcall(bar.SetStatusBarTexture, bar, atlas)
        bar:SetStatusBarColor(r, g, b, 1)
    else
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        local br, bg, bb = GetBarFillColor(standingID)
        bar:SetStatusBarColor(br, bg, bb, 1)
    end
end

local function UpdateStatusBarSpark(bar, currentVal, maxRange)
    if not bar or not bar.Spark then return end
    if not maxRange or maxRange <= 0 then maxRange = 1 end

    local pct = math.min(1, math.max(0, (currentVal or 0) / maxRange))
    if pct > 0.02 and pct < 0.98 then
        bar.Spark:ClearAllPoints()
        bar.Spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * pct, 0)
        bar.Spark:Show()
    else
        bar.Spark:Hide()
    end
end

local function FormatNumber(value)
    if not value then return "0" end
    local formatted = tostring(math.floor(value))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-------------------------------------------------------------------------------
-- Safe WoW Reputation API Helpers
-------------------------------------------------------------------------------

local function SafeGetNumFactions()
    if C_Reputation and C_Reputation.GetNumFactions then
        local ok, num = pcall(C_Reputation.GetNumFactions)
        if ok and num then return num end
    end
    if GetNumFactions then
        local ok, num = pcall(GetNumFactions)
        if ok and num then return num end
    end
    return 0
end

local function SafeGetFactionData(index)
    if not index or index < 1 then return nil end
    
    if C_Reputation and C_Reputation.GetFactionDataByIndex then
        local ok, d = pcall(C_Reputation.GetFactionDataByIndex, index)
        if ok and d and d.name then
            return {
                index = index,
                name = d.name or "Unknown Faction",
                description = d.description or "",
                standingID = d.reaction or d.currentReaction or 4,
                barMin = d.currentReactionThreshold or d.barMin or 0,
                barMax = d.nextReactionThreshold or d.barMax or 1,
                barValue = d.currentStanding or d.barValue or 0,
                atWarWith = d.atWarWith or false,
                canToggleAtWar = d.canToggleAtWar or false,
                isHeader = d.isHeader or false,
                isCollapsed = d.isCollapsed or false,
                hasRep = d.isHeaderWithRep or d.hasRep or false,
                isWatched = d.isWatched or false,
                isChild = d.isChild or false,
                factionID = d.factionID or 0,
                hasBonusRep = d.hasBonusRep or false,
                canSetInactive = d.canSetInactive or false,
            }
        end
    end
    
    if GetFactionInfo then
        local ok, name, description, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRep, canSetInactive = pcall(GetFactionInfo, index)
        if ok and name then
            return {
                index = index,
                name = name,
                description = description or "",
                standingID = standingID or 4,
                barMin = barMin or 0,
                barMax = barMax or 1,
                barValue = barValue or 0,
                atWarWith = atWarWith or false,
                canToggleAtWar = canToggleAtWar or false,
                isHeader = isHeader or false,
                isCollapsed = isCollapsed or false,
                hasRep = hasRep or false,
                isWatched = isWatched or false,
                isChild = isChild or false,
                factionID = factionID or 0,
                hasBonusRep = hasBonusRep or false,
                canSetInactive = canSetInactive or false,
            }
        end
    end
    
    return nil
end

local function SafeToggleHeader(index, isCollapsed)
    if isCollapsed then
        if C_Reputation and C_Reputation.ExpandFactionHeader then
            pcall(C_Reputation.ExpandFactionHeader, index)
        elseif ExpandFactionHeader then
            pcall(ExpandFactionHeader, index)
        end
    else
        if C_Reputation and C_Reputation.CollapseFactionHeader then
            pcall(C_Reputation.CollapseFactionHeader, index)
        elseif CollapseFactionHeader then
            pcall(CollapseFactionHeader, index)
        end
    end
end

local function SafeToggleWatched(index, isCurrentlyWatched)
    local targetIndex = isCurrentlyWatched and 0 or index
    if C_Reputation and C_Reputation.SetWatchedFactionByIndex then
        pcall(C_Reputation.SetWatchedFactionByIndex, targetIndex)
    elseif SetWatchedFactionIndex then
        pcall(SetWatchedFactionIndex, targetIndex)
    end
end

local function SafeToggleAtWar(index)
    if C_Reputation and C_Reputation.SetFactionAtWar then
        local d = SafeGetFactionData(index)
        if d then
            pcall(C_Reputation.SetFactionAtWar, index, not d.atWarWith)
        end
    elseif FactionToggleAtWar then
        pcall(FactionToggleAtWar, index)
    end
end

local function SafeToggleInactive(index, isCurrentlyInactive)
    if C_Reputation and C_Reputation.SetFactionInactive then
        pcall(C_Reputation.SetFactionInactive, index, not isCurrentlyInactive)
    elseif isCurrentlyInactive then
        if SetFactionActive then pcall(SetFactionActive, index) end
    else
        if SetFactionInactive then pcall(SetFactionInactive, index) end
    end
end

-------------------------------------------------------------------------------
-- UI Helper: Create Silver Button
-------------------------------------------------------------------------------

local function CreateSilverActionButton(parent, name, text)
    local btn
    if Utils and Utils.FrameHelper and Utils.FrameHelper.CreateSilverButton then
        btn = Utils.FrameHelper:CreateSilverButton(parent, name, text)
    else
        btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        if text then btn:SetText(text) end
        if Utils and Utils.FrameHelper and Utils.FrameHelper.StyleButtonAsMetal then
            Utils.FrameHelper:StyleButtonAsMetal(btn)
        end
    end
    local fontStr = btn:GetFontString()
    if fontStr then
        fontStr:SetFont(GetStandardFont(), 12, "")
        fontStr:SetShadowOffset(1, -1)
        fontStr:SetShadowColor(0, 0, 0, 1)
    end
    return btn
end

-------------------------------------------------------------------------------
-- View Construction: Reputation Master Container
-------------------------------------------------------------------------------

local function CreateReputationView(parentFrame)
    local container = CreateFrame("Frame", "OnePanel_ReputationContainer", parentFrame)
    container:SetAllPoints(parentFrame)
    
    local selectedFactionID = nil
    local searchQuery = ""
    
    ---------------------------------------------------------------------------
    -- Left Area: Search Bar, Category Controls & Faction Scroll List
    ---------------------------------------------------------------------------
    
    local leftArea = CreateFrame("Frame", "OnePanel_ReputationLeftArea", container)
    leftArea:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    leftArea:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    leftArea:SetWidth(338)
    container.LeftArea = leftArea
    
    -- Top Control Bar (Search Input + Expand/Collapse All + Summary)
    -- Positioned at y = -52 to completely clear the top-left circular portrait ring
    local topBar = CreateFrame("Frame", "OnePanel_ReputationTopBar", leftArea)
    topBar:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 10, -52)
    topBar:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", -12, -52)
    topBar:SetHeight(26)
    
    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "OnePanel_ReputationSearchBox", topBar, "InputBoxTemplate")
    searchBox:SetSize(130, 24)
    searchBox:SetPoint("LEFT", topBar, "LEFT", 2, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    searchBox:SetFont(GetStandardFont(), 13, "")
    searchBox:SetShadowOffset(1, -1)
    searchBox:SetShadowColor(0, 0, 0, 1)
    
    local searchHint = searchBox:CreateFontString(nil, "OVERLAY")
    searchHint:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
    searchHint:SetFont(GetStandardFont(), 13, "")
    searchHint:SetTextColor(0.5, 0.5, 0.5, 1)
    searchHint:SetShadowOffset(1, -1)
    searchHint:SetShadowColor(0, 0, 0, 1)
    searchHint:SetText("Search factions...")
    searchBox.Hint = searchHint
    
    -- Search Clear Button
    local clearSearchBtn = CreateFrame("Button", nil, searchBox)
    clearSearchBtn:SetSize(16, 16)
    clearSearchBtn:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    clearSearchBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    clearSearchBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
    clearSearchBtn:Hide()
    
    clearSearchBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
    
    local RefreshList = nil -- Forward declaration
    
    searchBox:SetScript("OnTextChanged", function(self)
        local text = (self:GetText() or ""):match("^%s*(.-)%s*$")
        searchQuery = string.lower(text or "")
        searchHint:SetShown(searchQuery == "")
        clearSearchBtn:SetShown(searchQuery ~= "")
        if RefreshList then RefreshList() end
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    
    -- Collapse / Expand All Button
    local toggleAllBtn = CreateSilverActionButton(topBar, "OnePanel_ReputationToggleAllBtn", "Collapse All")
    toggleAllBtn:SetSize(88, 24)
    toggleAllBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
    
    local allCollapsed = false
    toggleAllBtn:SetScript("OnClick", function(self)
        allCollapsed = not allCollapsed
        local num = SafeGetNumFactions()
        for i = num, 1, -1 do
            local d = SafeGetFactionData(i)
            if d and d.isHeader then
                if allCollapsed and not d.isCollapsed then
                    SafeToggleHeader(i, false)
                elseif not allCollapsed and d.isCollapsed then
                    SafeToggleHeader(i, true)
                end
            end
        end
        self:SetText(allCollapsed and "Expand All" or "Collapse All")
        if RefreshList then RefreshList() end
    end)
    
    -- Exalted Counter Summary (Top Right)
    local exaltedSummary = topBar:CreateFontString(nil, "OVERLAY")
    exaltedSummary:SetPoint("RIGHT", topBar, "RIGHT", -2, 0)
    exaltedSummary:SetJustifyH("RIGHT")
    exaltedSummary:SetFont(GetStandardFont(), 13, "")
    exaltedSummary:SetShadowOffset(1, -1)
    exaltedSummary:SetShadowColor(0, 0, 0, 1)
    topBar.ExaltedSummary = exaltedSummary
    
    -- Scroll View Container for Factions
    local scrollFrame = CreateFrame("ScrollFrame", "OnePanel_ReputationScrollFrame", leftArea, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftArea, "BOTTOMRIGHT", -14, 10)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local step = 46
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - (delta * step))))
    end)
    
    local scrollBarName = scrollFrame:GetName() .. "ScrollBar"
    local scrollBar = _G[scrollBarName]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 18)
        scrollBar:SetValueStep(46)
        
        local upBtn = _G[scrollBarName .. "ScrollUpButton"]
        local downBtn = _G[scrollBarName .. "ScrollDownButton"]
        if upBtn then
            upBtn:SetScript("OnClick", function()
                local cur = scrollFrame:GetVerticalScroll()
                scrollFrame:SetVerticalScroll(math.max(0, cur - 46))
            end)
        end
        if downBtn then
            downBtn:SetScript("OnClick", function()
                local cur = scrollFrame:GetVerticalScroll()
                local maxScroll = scrollFrame:GetVerticalScrollRange()
                scrollFrame:SetVerticalScroll(math.min(maxScroll, cur + 46))
            end)
        end
    end
    
    local listContent = CreateFrame("Frame", "OnePanel_ReputationListContent", scrollFrame)
    listContent:SetSize(288, 400)
    scrollFrame:SetScrollChild(listContent)
    listContent.rows = {}
    
    ---------------------------------------------------------------------------
    -- Right Area: Collapsible Side Details Panel
    ---------------------------------------------------------------------------
    
    local subPanel = CreateFrame("Frame", "OnePanel_ReputationSubPanel", container)
    subPanel:SetPoint("TOPRIGHT", container, "TOPRIGHT", -6, -12)
    subPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -6, 12)
    subPanel:SetWidth(198)
    container.SubPanel = subPanel
    
    -- Vertical Metal Divider separating list from details
    local vDivider = container:CreateTexture("OnePanel_ReputationVerticalDivider", "OVERLAY", nil, 2)
    vDivider:SetTexture("Interface\\FrameGeneral\\UIFrameMetalVertical")
    vDivider:SetTexCoord(258/512, 265/512, 0, 1)
    vDivider:SetVertTile(true)
    vDivider:SetWidth(7)
    vDivider:SetPoint("TOP", leftArea, "TOPRIGHT", 1, 10)
    vDivider:SetPoint("BOTTOM", leftArea, "BOTTOMRIGHT", 1, -14)
    container.VerticalDivider = vDivider
    
    -- Native Right-Side Collapse / Expand Toggle Button (Matches Character tab position)
    local toggleBtn = CreateFrame("Button", "OnePanel_ReputationSideToggleButton", leftArea)
    toggleBtn:SetSize(28, 28)
    toggleBtn:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", -14, -18)
    toggleBtn:SetFrameLevel(510)
    
    local toggleIcon = toggleBtn:CreateTexture(nil, "ARTWORK")
    toggleIcon:SetAllPoints(toggleBtn)
    local setNorm = pcall(function() toggleIcon:SetTexture(130869) end)
    if not setNorm or not toggleIcon:GetTexture() then
        toggleIcon:SetTexture("Interface\\Buttons\\UI-SpellbookSearch-DrillDown")
    end
    toggleBtn.Icon = toggleIcon
    
    local toggleHilight = toggleBtn:CreateTexture(nil, "HIGHLIGHT")
    toggleHilight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    toggleHilight:SetBlendMode("ADD")
    toggleHilight:SetAllPoints(toggleBtn)
    
    local function UpdateToggleIcon()
        if OnePanel and OnePanel.isExpanded then
            toggleIcon:SetTexCoord(0, 1, 0, 1)
        else
            toggleIcon:SetTexCoord(1, 0, 0, 1)
        end
    end
    toggleBtn.UpdateIcon = UpdateToggleIcon
    UpdateToggleIcon()
    
    toggleBtn:SetScript("OnClick", function()
        if OnePanel and OnePanel.SetPanelExpanded then
            OnePanel:SetPanelExpanded(not OnePanel.isExpanded)
        end
        UpdateToggleIcon()
    end)
    
    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText((OnePanel and OnePanel.isExpanded) and "Collapse Details Panel" or "Expand Details Panel", 1, 1, 1)
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function() GameTooltip_Hide() end)
    container.RightSideToggleButton = toggleBtn
    
    -- Sync subPanel and vertical divider visibility with OnePanel master expand state
    if OnePanel then
        subPanel:SetShown(OnePanel.isExpanded ~= false)
        vDivider:SetShown(OnePanel.isExpanded ~= false)
    end
    if Utils and Utils.EventBus then
        Utils.EventBus:Register("ONEPANEL_EXPAND_STATE_CHANGED", function(isExpanded)
            if subPanel and subPanel.SetShown then
                subPanel:SetShown(isExpanded)
            end
            if vDivider and vDivider.SetShown then
                vDivider:SetShown(isExpanded)
            end
            if toggleBtn and toggleBtn.UpdateIcon then
                toggleBtn:UpdateIcon()
            end
        end)
    end
    
    ---------------------------------------------------------------------------
    -- Sub-Panel Details Content Components
    ---------------------------------------------------------------------------
    
    local detailHeader = subPanel:CreateFontString(nil, "OVERLAY")
    detailHeader:SetPoint("TOPLEFT", subPanel, "TOPLEFT", 4, -6)
    detailHeader:SetPoint("TOPRIGHT", subPanel, "TOPRIGHT", -4, -6)
    detailHeader:SetJustifyH("CENTER")
    detailHeader:SetWordWrap(true)
    detailHeader:SetFont(GetStandardFont(), 17, "")
    detailHeader:SetTextColor(1, 0.82, 0, 1)
    detailHeader:SetShadowOffset(1, -1)
    detailHeader:SetShadowColor(0, 0, 0, 1)
    subPanel.Header = detailHeader
    
    -- Standing Badge Tag (e.g. "[ Revered ]" with colored text and background)
    local standingBadge = CreateFrame("Frame", nil, subPanel)
    standingBadge:SetSize(174, 22)
    standingBadge:SetPoint("TOP", detailHeader, "BOTTOM", 0, -6)
    
    local standingBadgeBg = standingBadge:CreateTexture(nil, "BACKGROUND")
    standingBadgeBg:SetAllPoints(standingBadge)
    standingBadgeBg:SetColorTexture(0.10, 0.10, 0.12, 0.85)
    
    local standingBadgeText = standingBadge:CreateFontString(nil, "OVERLAY")
    standingBadgeText:SetPoint("CENTER", standingBadge, "CENTER", 0, 0)
    standingBadgeText:SetFont(GetStandardFont(), 13, "")
    standingBadgeText:SetShadowOffset(1, -1)
    standingBadgeText:SetShadowColor(0, 0, 0, 1)
    subPanel.StandingBadgeText = standingBadgeText
    
    -- Detail Progress Bar (24px height, modern cast bar styling)
    local detailBar = CreateFrame("StatusBar", nil, subPanel)
    detailBar:SetSize(178, 24)
    detailBar:SetPoint("TOP", standingBadge, "BOTTOM", 0, -8)
    
    local detailBarBg = detailBar:CreateTexture(nil, "BACKGROUND", nil, -2)
    detailBarBg:SetAllPoints(detailBar)
    if SafeHasAtlas("ui-castingbar-background") then
        detailBarBg:SetAtlas("ui-castingbar-background")
    else
        detailBarBg:SetColorTexture(0.04, 0.04, 0.06, 0.95)
    end
    detailBar.Bg = detailBarBg
    
    local detailBarBorder = detailBar:CreateTexture(nil, "OVERLAY", nil, 1)
    detailBarBorder:SetPoint("TOPLEFT", detailBar, "TOPLEFT", -2, 2)
    detailBarBorder:SetPoint("BOTTOMRIGHT", detailBar, "BOTTOMRIGHT", 2, -2)
    if SafeHasAtlas("ui-castingbar-frame") then
        detailBarBorder:SetAtlas("ui-castingbar-frame")
    else
        detailBarBorder:SetColorTexture(0.20, 0.18, 0.15, 0.9)
    end
    detailBar.Border = detailBarBorder
    
    local detailSpark = detailBar:CreateTexture(nil, "OVERLAY", nil, 2)
    detailSpark:SetSize(8, 24)
    if SafeHasAtlas("ui-castingbar-pip") then
        detailSpark:SetAtlas("ui-castingbar-pip")
    else
        detailSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        detailSpark:SetBlendMode("ADD")
    end
    detailSpark:Hide()
    detailBar.Spark = detailSpark
    
    local detailBarText = detailBar:CreateFontString(nil, "OVERLAY", nil, 3)
    detailBarText:SetPoint("CENTER", detailBar, "CENTER", 0, 0)
    detailBarText:SetFont(GetStandardFont(), 13, "")
    detailBarText:SetShadowOffset(1, -1)
    detailBarText:SetShadowColor(0, 0, 0, 1)
    detailBarText:SetTextColor(1, 1, 1, 1)
    subPanel.DetailBar = detailBar
    subPanel.DetailBarText = detailBarText
    
    -- Exact Numerical Progress Lines (Clear 13pt text)
    local statsText = subPanel:CreateFontString(nil, "OVERLAY")
    statsText:SetPoint("TOPLEFT", detailBar, "BOTTOMLEFT", 2, -8)
    statsText:SetPoint("TOPRIGHT", detailBar, "BOTTOMRIGHT", -2, -8)
    statsText:SetJustifyH("LEFT")
    statsText:SetFont(GetStandardFont(), 13, "")
    statsText:SetSpacing(4)
    statsText:SetShadowOffset(1, -1)
    statsText:SetShadowColor(0, 0, 0, 1)
    subPanel.StatsText = statsText
    
    -- Scrollable Faction Description Box
    local descScroll = CreateFrame("ScrollFrame", "OnePanel_ReputationDescScroll", subPanel, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -10)
    descScroll:SetPoint("BOTTOMRIGHT", subPanel, "BOTTOMRIGHT", -20, 84)
    descScroll:EnableMouseWheel(true)
    
    local descContent = CreateFrame("Frame", nil, descScroll)
    descContent:SetSize(158, 200)
    descScroll:SetScrollChild(descContent)
    
    local descText = descContent:CreateFontString(nil, "OVERLAY")
    descText:SetPoint("TOPLEFT", descContent, "TOPLEFT", 2, -2)
    descText:SetWidth(152)
    descText:SetJustifyH("LEFT")
    descText:SetFont(GetStandardFont(), 13, "")
    descText:SetSpacing(3)
    descText:SetTextColor(0.90, 0.90, 0.90, 1)
    descText:SetShadowOffset(1, -1)
    descText:SetShadowColor(0, 0, 0, 1)
    subPanel.DescText = descText
    subPanel.DescContent = descContent
    
    -- Checkboxes: Watch on XP bar, At War, Make Inactive (Shifted right for clean alignment)
    local watchCheck = CreateFrame("CheckButton", "OnePanel_RepWatchCheck", subPanel, "UICheckButtonTemplate")
    watchCheck:SetSize(22, 22)
    watchCheck:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 12, 54)
    local watchLabel = _G[watchCheck:GetName() .. "Text"]
    if watchLabel then
        watchLabel:SetText("Show as Exp Bar")
        watchLabel:SetFont(GetStandardFont(), 13, "")
        watchLabel:SetShadowOffset(1, -1)
        watchLabel:SetShadowColor(0, 0, 0, 1)
    end
    subPanel.WatchCheck = watchCheck
    
    local atWarCheck = CreateFrame("CheckButton", "OnePanel_RepAtWarCheck", subPanel, "UICheckButtonTemplate")
    atWarCheck:SetSize(22, 22)
    atWarCheck:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 12, 30)
    local atWarLabel = _G[atWarCheck:GetName() .. "Text"]
    if atWarLabel then
        atWarLabel:SetText("At War")
        atWarLabel:SetFont(GetStandardFont(), 13, "")
        atWarLabel:SetShadowOffset(1, -1)
        atWarLabel:SetShadowColor(0, 0, 0, 1)
    end
    subPanel.AtWarCheck = atWarCheck
    
    local inactiveCheck = CreateFrame("CheckButton", "OnePanel_RepInactiveCheck", subPanel, "UICheckButtonTemplate")
    inactiveCheck:SetSize(22, 22)
    inactiveCheck:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 12, 6)
    local inactiveLabel = _G[inactiveCheck:GetName() .. "Text"]
    if inactiveLabel then
        inactiveLabel:SetText("Move to Inactive")
        inactiveLabel:SetFont(GetStandardFont(), 13, "")
        inactiveLabel:SetShadowOffset(1, -1)
        inactiveLabel:SetShadowColor(0, 0, 0, 1)
    end
    subPanel.InactiveCheck = inactiveCheck
    
    -- Empty Details Placeholder (Shown when no faction is selected)
    local emptyDetailText = subPanel:CreateFontString(nil, "OVERLAY")
    emptyDetailText:SetPoint("CENTER", subPanel, "CENTER", 0, 0)
    emptyDetailText:SetFont(GetStandardFont(), 13, "")
    emptyDetailText:SetShadowOffset(1, -1)
    emptyDetailText:SetShadowColor(0, 0, 0, 1)
    emptyDetailText:SetText("|cff888888Select a faction\nto view details.|r")
    subPanel.EmptyText = emptyDetailText
    
    ---------------------------------------------------------------------------
    -- Detail Update Logic
    ---------------------------------------------------------------------------
    
    local function UpdateDetails(data)
        if not data then
            detailHeader:Hide()
            standingBadge:Hide()
            detailBar:Hide()
            statsText:Hide()
            descScroll:Hide()
            watchCheck:Hide()
            atWarCheck:Hide()
            inactiveCheck:Hide()
            emptyDetailText:Show()
            return
        end
        
        emptyDetailText:Hide()
        detailHeader:Show()
        standingBadge:Show()
        detailBar:Show()
        statsText:Show()
        descScroll:Show()
        watchCheck:Show()
        atWarCheck:Show()
        inactiveCheck:Show()
        
        detailHeader:SetText(data.name)
        
        local standingName = STANDING_LABELS[data.standingID] or "Neutral"
        local hex = GetStandingHex(data.standingID)
        standingBadgeText:SetText(string.format("|cff%s[ %s ]|r", hex, standingName))
        
        -- Progress values
        local isExalted = (data.standingID == 8)
        local barMin = data.barMin or 0
        local barMax = data.barMax or 1
        local barValue = data.barValue or 0
        local maxRange = barMax - barMin
        local currentVal = barValue - barMin
        if maxRange <= 0 then maxRange = 1 end
        if currentVal < 0 then currentVal = 0 end
        
        detailBar:SetMinMaxValues(0, maxRange)
        detailBar:SetValue(math.min(maxRange, currentVal))
        ApplyModernReputationBarTexture(detailBar, data.standingID)
        UpdateStatusBarSpark(detailBar, currentVal, maxRange)
        
        local pct = math.min(100, math.floor((currentVal / maxRange) * 100))
        if isExalted and currentVal >= maxRange then
            detailBarText:SetText(string.format("%s / %s (Max)", FormatNumber(currentVal), FormatNumber(maxRange)))
            statsText:SetText(string.format(
                "|cffccccccCurrent:|r |cffffffff%s|r\n|cff00e6b3Maximum reputation achieved!|r",
                FormatNumber(currentVal)
            ))
        else
            detailBarText:SetText(string.format("%s / %s (%d%%)", FormatNumber(currentVal), FormatNumber(maxRange), pct))
            local needed = math.max(0, maxRange - currentVal)
            statsText:SetText(string.format(
                "|cffccccccCurrent:|r |cffffffff%s|r\n|cffccccccTo Next Rank:|r |cffffffff%s|r",
                FormatNumber(currentVal),
                FormatNumber(needed)
            ))
        end
        
        -- Description Text
        local desc = (data.description and data.description ~= "") and data.description or "No faction description available."
        descText:SetText(desc)
        descContent:SetHeight(math.max(100, descText:GetStringHeight() + 10))
        descScroll:SetVerticalScroll(0)
        
        -- Checkbox states
        watchCheck:SetChecked(data.isWatched == true)
        watchCheck:SetScript("OnClick", function(self)
            SafeToggleWatched(data.index, not self:GetChecked())
            if RefreshList then RefreshList() end
        end)
        
        atWarCheck:SetChecked(data.atWarWith == true)
        atWarCheck:SetEnabled(data.canToggleAtWar == true)
        if data.canToggleAtWar then
            atWarLabel:SetTextColor(1, 1, 1, 1)
        else
            atWarLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        end
        atWarCheck:SetScript("OnClick", function()
            SafeToggleAtWar(data.index)
            if RefreshList then RefreshList() end
        end)
        
        inactiveCheck:SetChecked(data.isChild == true)
        inactiveCheck:SetEnabled(data.canSetInactive == true)
        if data.canSetInactive then
            inactiveLabel:SetTextColor(1, 1, 1, 1)
        else
            inactiveLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        end
        inactiveCheck:SetScript("OnClick", function(self)
            SafeToggleInactive(data.index, not self:GetChecked())
            if RefreshList then RefreshList() end
        end)
    end
    
    ---------------------------------------------------------------------------
    -- Row Creation & Dynamic Pool
    ---------------------------------------------------------------------------
    
    local function GetOrCreateRow(idx)
        local row = listContent.rows[idx]
        if row then return row end
        
        row = CreateFrame("Button", "OnePanel_RepRow_" .. idx, listContent)
        row:SetSize(288, 44)
        
        -- Background
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0.06, 0.06, 0.08, 0.7)
        row.Bg = bg
        
        -- Highlight Overlay
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.25)
        hl:SetAllPoints(row)
        row.Highlight = hl
        
        -- Selected Overlay
        local sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        sel:SetBlendMode("ADD")
        sel:SetAlpha(0.35)
        sel:SetAllPoints(row)
        sel:Hide()
        row.SelectedHighlight = sel
        
        -- Header Button (matches Character Stats button banner style with centered text)
        local headerBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        headerBtn:SetAllPoints(row)
        headerBtn:Disable()
        headerBtn:Hide()
        if headerBtn.SetDisabledFontObject then
            headerBtn:SetDisabledFontObject("GameFontNormal")
        end
        local hFont = headerBtn:GetFontString()
        if hFont then
            hFont:SetFont(GetStandardFont(), 13, "")
            hFont:SetTextColor(1, 0.85, 0.1, 1)
            hFont:SetShadowOffset(1, -1)
            hFont:SetShadowColor(0, 0, 0, 1)
        end
        row.HeaderButton = headerBtn
        
        -- Faction Name (14pt clean font matching Skills)
        local nameText = row:CreateFontString(nil, "ARTWORK")
        nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
        nameText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -84, -4)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        nameText:SetFont(GetStandardFont(), 14, "")
        nameText:SetShadowOffset(1, -1)
        nameText:SetShadowColor(0, 0, 0, 1)
        nameText:SetTextColor(0.95, 0.95, 0.95, 1)
        row.NameText = nameText
        
        -- Standing Text Badge (Top line right, e.g. "[ Friendly ]")
        local standingText = row:CreateFontString(nil, "ARTWORK")
        standingText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -4)
        standingText:SetJustifyH("RIGHT")
        standingText:SetFont(GetStandardFont(), 13, "")
        standingText:SetShadowOffset(1, -1)
        standingText:SetShadowColor(0, 0, 0, 1)
        standingText:Hide()
        row.StandingText = standingText
        
        -- Modern Gradient Status Bar (20px tall, cast bar frame, bg, spark, text)
        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)
        bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 4)
        bar:SetHeight(20)
        
        local barBg = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
        barBg:SetAllPoints(bar)
        if SafeHasAtlas("ui-castingbar-background") then
            barBg:SetAtlas("ui-castingbar-background")
        else
            barBg:SetColorTexture(0.04, 0.04, 0.06, 0.95)
        end
        bar.Bg = barBg
        
        local barBorder = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        barBorder:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        barBorder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
        if SafeHasAtlas("ui-castingbar-frame") then
            barBorder:SetAtlas("ui-castingbar-frame")
        else
            barBorder:SetColorTexture(0.20, 0.18, 0.15, 0.9)
        end
        bar.Border = barBorder
        
        local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        spark:SetSize(8, 20)
        if SafeHasAtlas("ui-castingbar-pip") then
            spark:SetAtlas("ui-castingbar-pip")
        else
            spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            spark:SetBlendMode("ADD")
        end
        spark:Hide()
        bar.Spark = spark
        
        local barText = bar:CreateFontString(nil, "OVERLAY", nil, 3)
        barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
        barText:SetFont(GetStandardFont(), 13, "")
        barText:SetShadowOffset(1, -1)
        barText:SetShadowColor(0, 0, 0, 1)
        barText:SetTextColor(1, 1, 1, 1)
        
        row.Bar = bar
        row.BarText = barText
        
        -- Watched Star / Check Icon
        local watchedIcon = row:CreateTexture(nil, "OVERLAY")
        watchedIcon:SetSize(14, 14)
        watchedIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        watchedIcon:Hide()
        row.WatchedIcon = watchedIcon
        
        -- At War Swords Icon
        local atWarIcon = row:CreateTexture(nil, "OVERLAY")
        atWarIcon:SetSize(14, 14)
        atWarIcon:SetTexture("Interface\\WorldStateFrame\\CombatIcon")
        atWarIcon:Hide()
        row.AtWarIcon = atWarIcon
        
        listContent.rows[idx] = row
        return row
    end
    
    ---------------------------------------------------------------------------
    -- Faction List Renderer
    ---------------------------------------------------------------------------
    
    RefreshList = function()
        for _, r in ipairs(listContent.rows) do r:Hide() end
        
        local totalFactions = SafeGetNumFactions()
        local yOffset = -2
        local rowIndex = 1
        local totalExaltedCount = 0
        local selectedData = nil
        
        -- Category aggregation stats for headers
        local categoryStats = {}
        local currentCategory = nil
        
        for i = 1, totalFactions do
            local d = SafeGetFactionData(i)
            if d then
                if d.isHeader then
                    currentCategory = d.name
                    categoryStats[currentCategory] = { total = 0, exalted = 0 }
                elseif currentCategory then
                    categoryStats[currentCategory].total = categoryStats[currentCategory].total + 1
                    if d.standingID == 8 then
                        categoryStats[currentCategory].exalted = categoryStats[currentCategory].exalted + 1
                    end
                end
                if not d.isHeader and d.standingID == 8 then
                    totalExaltedCount = totalExaltedCount + 1
                end
            end
        end
        
        exaltedSummary:SetText(string.format("|cff00e6b3Exalted: %d|r", totalExaltedCount))
        
        -- Filter & Render Rows
        for i = 1, totalFactions do
            local d = SafeGetFactionData(i)
            if d then
                local shouldShow = true
                if searchQuery ~= "" and not d.isHeader then
                    local match = string.find(string.lower(d.name or ""), searchQuery, 1, true)
                    shouldShow = (match ~= nil)
                end
                
                if shouldShow then
                    local row = GetOrCreateRow(rowIndex)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 1, yOffset)
                    
                    if d.isHeader then
                        -- Render as Category Header Button (Grey metal button banner)
                        if rowIndex > 1 then
                            yOffset = yOffset - 4
                        end
                        row:SetHeight(26)
                        
                        row.Bg:Hide()
                        if row.Highlight then row.Highlight:Hide() end
                        row.SelectedHighlight:Hide()
                        row.NameText:Hide()
                        row.StandingText:Hide()
                        row.Bar:Hide()
                        row.WatchedIcon:Hide()
                        row.AtWarIcon:Hide()
                        
                        local headerBtn = row.HeaderButton
                        headerBtn:Show()
                        headerBtn:SetAllPoints(row)
                        headerBtn:SetHeight(26)
                        
                        local stats = categoryStats[d.name]
                        if stats and stats.total > 0 then
                            headerBtn:SetText(string.format("%s   (%d/%d Exalted)", d.name, stats.exalted, stats.total))
                        else
                            headerBtn:SetText(d.name)
                        end
                        headerBtn:Disable()
                        headerBtn:EnableMouse(true)
                        
                        local headerIndex = d.index
                        local wasCollapsed = d.isCollapsed
                        headerBtn:SetScript("OnMouseUp", function(self, button)
                            if button == "LeftButton" then
                                SafeToggleHeader(headerIndex, wasCollapsed)
                                RefreshList()
                            end
                        end)
                        row:SetScript("OnClick", function()
                            SafeToggleHeader(headerIndex, wasCollapsed)
                            RefreshList()
                        end)
                        
                        row:Show()
                        rowIndex = rowIndex + 1
                        yOffset = yOffset - 30
                    else
                        -- Render as Faction Row (44px tall, high contrast gradient bar)
                        row:SetHeight(44)
                        row.HeaderButton:Hide()
                        
                        row.Bg:Show()
                        if rowIndex % 2 == 1 then
                            row.Bg:SetColorTexture(0.10, 0.10, 0.12, 0.7)
                        else
                            row.Bg:SetColorTexture(0.05, 0.05, 0.07, 0.7)
                        end
                        
                        if row.Highlight then row.Highlight:Show() end
                        
                        row.NameText:Show()
                        row.NameText:SetText(d.name)
                        
                        local standingName = STANDING_LABELS[d.standingID] or "Neutral"
                        local hex = GetStandingHex(d.standingID)
                        row.StandingText:Show()
                        row.StandingText:SetText(string.format("|cff%s[ %s ]|r", hex, standingName))
                        
                        row.Bar:Show()
                        local barMin = d.barMin or 0
                        local barMax = d.barMax or 1
                        local barValue = d.barValue or 0
                        local maxRange = barMax - barMin
                        local currentVal = barValue - barMin
                        if maxRange <= 0 then maxRange = 1 end
                        if currentVal < 0 then currentVal = 0 end
                        
                        row.Bar:SetMinMaxValues(0, maxRange)
                        row.Bar:SetValue(math.min(maxRange, currentVal))
                        
                        ApplyModernReputationBarTexture(row.Bar, d.standingID)
                        UpdateStatusBarSpark(row.Bar, currentVal, maxRange)
                        
                        local isExalted = (d.standingID == 8)
                        if isExalted and currentVal >= maxRange then
                            row.BarText:SetText(string.format("%s / %s (Max)", FormatNumber(currentVal), FormatNumber(maxRange)))
                        else
                            local pct = math.min(100, math.floor((currentVal / maxRange) * 100))
                            row.BarText:SetText(string.format("%s / %s (%d%%)", FormatNumber(currentVal), FormatNumber(maxRange), pct))
                        end
                        
                        -- Status icons layout
                        if d.isWatched == true then
                            row.WatchedIcon:ClearAllPoints()
                            row.WatchedIcon:SetPoint("RIGHT", row.StandingText, "LEFT", -4, 0)
                            row.WatchedIcon:Show()
                        else
                            row.WatchedIcon:Hide()
                        end
                        
                        if d.atWarWith == true then
                            row.AtWarIcon:ClearAllPoints()
                            if d.isWatched == true then
                                row.AtWarIcon:SetPoint("RIGHT", row.WatchedIcon, "LEFT", -2, 0)
                            else
                                row.AtWarIcon:SetPoint("RIGHT", row.StandingText, "LEFT", -4, 0)
                            end
                            row.AtWarIcon:Show()
                        else
                            row.AtWarIcon:Hide()
                        end
                        
                        -- Selection match
                        if not selectedFactionID and rowIndex == 1 and not d.isHeader then
                            selectedFactionID = d.factionID or d.index
                        end
                        
                        local isSelected = (selectedFactionID == (d.factionID or d.index))
                        row.SelectedHighlight:SetShown(isSelected)
                        if isSelected then
                            row.NameText:SetTextColor(1, 0.85, 0.2, 1)
                            selectedData = d
                        else
                            row.NameText:SetTextColor(0.95, 0.95, 0.95, 1)
                        end
                        
                        row:SetScript("OnClick", function()
                            selectedFactionID = d.factionID or d.index
                            UpdateDetails(d)
                            RefreshList()
                        end)
                        
                        row:Show()
                        rowIndex = rowIndex + 1
                        yOffset = yOffset - 48
                    end
                end
            end
        end
        
        listContent:SetHeight(math.abs(yOffset) + 30)
        UpdateDetails(selectedData)
    end
    
    container.Refresh = RefreshList
    
    ---------------------------------------------------------------------------
    -- Event Listener
    ---------------------------------------------------------------------------
    
    local eventFrame = CreateFrame("Frame", nil, container)
    eventFrame:RegisterEvent("UPDATE_FACTION")
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    eventFrame:SetScript("OnEvent", function(self, event)
        if container:IsVisible() and RefreshList then
            RefreshList()
        end
    end)
    
    return container
end

-------------------------------------------------------------------------------
-- OnePanel Plugin Registration
-------------------------------------------------------------------------------

local function RegisterReputationPlugin()
    if not OnePanel then return end
    
    OnePanel:RegisterPlugin({
        id = "Reputation",
        title = "Reputation",
        order = 20, -- Sits directly beneath Character (order 10)
        icon = "Interface\\Icons\\Achievement_Reputation_01",
        CreateView = CreateReputationView,
        OnShow = function(container)
            if OnePanel and OnePanel.SetTitleText then
                OnePanel:SetTitleText("Reputation")
            end
            if OnePanel and OnePanel.SetHeaderPortrait then
                OnePanel:SetHeaderPortrait("Interface\\Icons\\Achievement_Reputation_01", nil, false)
            end
            if container and container.Refresh then
                container:Refresh()
            end
        end,
        OnHide = function(container)
            -- Clean up any open popups or tooltips if needed
            GameTooltip_Hide()
        end
    })
end

local loadFrame = CreateFrame("Frame", "OnePanel_Reputation_LoadFrame")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event)
    RegisterReputationPlugin()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
