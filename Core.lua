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

local STANDING_COLORS = {
    [1] = { r = 0.80, g = 0.15, b = 0.15, hex = "cc2626" }, -- Hated (Dark Red)
    [2] = { r = 0.95, g = 0.25, b = 0.25, hex = "f24040" }, -- Hostile (Red)
    [3] = { r = 0.95, g = 0.55, b = 0.10, hex = "f28c1a" }, -- Unfriendly (Orange)
    [4] = { r = 1.00, g = 0.85, b = 0.10, hex = "ffd91a" }, -- Neutral (Yellow)
    [5] = { r = 0.20, g = 0.80, b = 0.20, hex = "33cc33" }, -- Friendly (Green)
    [6] = { r = 0.00, g = 0.65, b = 0.95, hex = "00a6f2" }, -- Honored (Blue/Cyan)
    [7] = { r = 0.65, g = 0.35, b = 0.95, hex = "a659f2" }, -- Revered (Purple)
    [8] = { r = 0.00, g = 0.90, b = 0.70, hex = "00e6b3" }, -- Exalted (Teal/Aquamarine)
}

local function GetStandingColor(standingID)
    if _G.FACTION_BAR_COLORS and _G.FACTION_BAR_COLORS[standingID] then
        local c = _G.FACTION_BAR_COLORS[standingID]
        return c.r or 1, c.g or 1, c.b or 1
    end
    local c = STANDING_COLORS[standingID] or STANDING_COLORS[4]
    return c.r, c.g, c.b
end

local function GetStandingHex(standingID)
    local c = STANDING_COLORS[standingID] or STANDING_COLORS[4]
    return c.hex or "ffffff"
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
        btn = CreateFrame("Button", name, parent)
        if btn.SetNormalFontObject then btn:SetNormalFontObject("GameFontHighlightSmall") end
        if btn.SetDisabledFontObject then btn:SetDisabledFontObject("GameFontDisableSmall") end
        if text then btn:SetText(text) end
        if Utils and Utils.FrameHelper and Utils.FrameHelper.StyleButtonAsMetal then
            Utils.FrameHelper:StyleButtonAsMetal(btn)
        end
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
    leftArea:SetWidth(348)
    container.LeftArea = leftArea
    
    -- Top Control Bar (Search Input + Expand/Collapse All + Summary)
    -- Positioned at y = -52 to completely clear the top-left circular portrait ring
    local topBar = CreateFrame("Frame", "OnePanel_ReputationTopBar", leftArea)
    topBar:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 10, -52)
    topBar:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", -10, -52)
    topBar:SetHeight(26)
    
    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "OnePanel_ReputationSearchBox", topBar, "InputBoxTemplate")
    searchBox:SetSize(140, 22)
    searchBox:SetPoint("LEFT", topBar, "LEFT", 2, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    
    local searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
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
    toggleAllBtn:SetSize(86, 22)
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
    local exaltedSummary = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    exaltedSummary:SetPoint("RIGHT", topBar, "RIGHT", -2, 0)
    exaltedSummary:SetJustifyH("RIGHT")
    topBar.ExaltedSummary = exaltedSummary
    
    -- Scroll View Container for Factions
    local scrollFrame = CreateFrame("ScrollFrame", "OnePanel_ReputationScrollFrame", leftArea, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftArea, "BOTTOMRIGHT", -6, 8)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local step = 42
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - (delta * step))))
    end)
    
    local scrollBarName = scrollFrame:GetName() .. "ScrollBar"
    local scrollBar = _G[scrollBarName]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 18)
        scrollBar:SetValueStep(42)
        
        local upBtn = _G[scrollBarName .. "ScrollUpButton"]
        local downBtn = _G[scrollBarName .. "ScrollDownButton"]
        if upBtn then
            upBtn:SetScript("OnClick", function()
                local cur = scrollFrame:GetVerticalScroll()
                scrollFrame:SetVerticalScroll(math.max(0, cur - 42))
            end)
        end
        if downBtn then
            downBtn:SetScript("OnClick", function()
                local cur = scrollFrame:GetVerticalScroll()
                local maxScroll = scrollFrame:GetVerticalScrollRange()
                scrollFrame:SetVerticalScroll(math.min(maxScroll, cur + 42))
            end)
        end
    end
    
    local listContent = CreateFrame("Frame", "OnePanel_ReputationListContent", scrollFrame)
    listContent:SetSize(318, 400)
    scrollFrame:SetScrollChild(listContent)
    listContent.rows = {}
    
    ---------------------------------------------------------------------------
    -- Right Area: Collapsible Side Details Panel
    ---------------------------------------------------------------------------
    
    local subPanel = CreateFrame("Frame", "OnePanel_ReputationSubPanel", container)
    subPanel:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -12)
    subPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -10, 12)
    subPanel:SetWidth(208)
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
    
    local detailHeader = subPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailHeader:SetPoint("TOPLEFT", subPanel, "TOPLEFT", 6, -6)
    detailHeader:SetPoint("TOPRIGHT", subPanel, "TOPRIGHT", -6, -6)
    detailHeader:SetJustifyH("CENTER")
    detailHeader:SetWordWrap(true)
    subPanel.Header = detailHeader
    
    -- Standing Badge Tag (e.g. "[ Revered ]" with colored text and background)
    local standingBadge = CreateFrame("Frame", nil, subPanel)
    standingBadge:SetSize(180, 20)
    standingBadge:SetPoint("TOP", detailHeader, "BOTTOM", 0, -6)
    
    local standingBadgeBg = standingBadge:CreateTexture(nil, "BACKGROUND")
    standingBadgeBg:SetAllPoints(standingBadge)
    standingBadgeBg:SetColorTexture(0.12, 0.12, 0.14, 0.8)
    
    local standingBadgeText = standingBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    standingBadgeText:SetPoint("CENTER", standingBadge, "CENTER", 0, 0)
    subPanel.StandingBadgeText = standingBadgeText
    
    -- Detail Progress Bar
    local detailBar = CreateFrame("StatusBar", nil, subPanel)
    detailBar:SetSize(188, 16)
    detailBar:SetPoint("TOP", standingBadge, "BOTTOM", 0, -8)
    detailBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    
    local detailBarBg = detailBar:CreateTexture(nil, "BACKGROUND")
    detailBarBg:SetAllPoints(detailBar)
    detailBarBg:SetColorTexture(0.08, 0.08, 0.08, 0.9)
    
    local detailBarText = detailBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailBarText:SetPoint("CENTER", detailBar, "CENTER", 0, 0)
    subPanel.DetailBar = detailBar
    subPanel.DetailBarText = detailBarText
    
    -- Exact Numerical Progress Lines
    local statsText = subPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsText:SetPoint("TOPLEFT", detailBar, "BOTTOMLEFT", 2, -6)
    statsText:SetPoint("TOPRIGHT", detailBar, "BOTTOMRIGHT", -2, -6)
    statsText:SetJustifyH("LEFT")
    subPanel.StatsText = statsText
    
    -- Scrollable Faction Description Box
    local descScroll = CreateFrame("ScrollFrame", "OnePanel_ReputationDescScroll", subPanel, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -10)
    descScroll:SetPoint("BOTTOMRIGHT", subPanel, "BOTTOMRIGHT", -24, 82)
    descScroll:EnableMouseWheel(true)
    
    local descContent = CreateFrame("Frame", nil, descScroll)
    descContent:SetSize(170, 200)
    descScroll:SetScrollChild(descContent)
    
    local descText = descContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    descText:SetPoint("TOPLEFT", descContent, "TOPLEFT", 2, -2)
    descText:SetWidth(164)
    descText:SetJustifyH("LEFT")
    subPanel.DescText = descText
    subPanel.DescContent = descContent
    
    -- Checkboxes: Watch on XP bar, At War, Make Inactive
    local watchCheck = CreateFrame("CheckButton", "OnePanel_RepWatchCheck", subPanel, "UICheckButtonTemplate")
    watchCheck:SetSize(22, 22)
    watchCheck:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 6, 54)
    local watchLabel = _G[watchCheck:GetName() .. "Text"]
    if watchLabel then
        watchLabel:SetText("Show as Exp Bar")
        watchLabel:SetFontObject("GameFontHighlightSmall")
    end
    subPanel.WatchCheck = watchCheck
    
    local atWarCheck = CreateFrame("CheckButton", "OnePanel_RepAtWarCheck", subPanel, "UICheckButtonTemplate")
    atWarCheck:SetSize(22, 22)
    atWarCheck:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 6, 30)
    local atWarLabel = _G[atWarCheck:GetName() .. "Text"]
    if atWarLabel then
        atWarLabel:SetText("At War")
        atWarLabel:SetFontObject("GameFontHighlightSmall")
    end
    subPanel.AtWarCheck = atWarCheck
    
    local inactiveCheck = CreateFrame("CheckButton", "OnePanel_RepInactiveCheck", subPanel, "UICheckButtonTemplate")
    inactiveCheck:SetSize(22, 22)
    inactiveCheck:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 6, 6)
    local inactiveLabel = _G[inactiveCheck:GetName() .. "Text"]
    if inactiveLabel then
        inactiveLabel:SetText("Move to Inactive")
        inactiveLabel:SetFontObject("GameFontHighlightSmall")
    end
    subPanel.InactiveCheck = inactiveCheck
    
    -- Empty Details Placeholder (Shown when no faction is selected)
    local emptyDetailText = subPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyDetailText:SetPoint("CENTER", subPanel, "CENTER", 0, 0)
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
        
        detailHeader:SetText(string.format("|cffffcc00%s|r", data.name))
        
        local standingName = STANDING_LABELS[data.standingID] or "Neutral"
        local r, g, b = GetStandingColor(data.standingID)
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
        detailBar:SetStatusBarColor(r, g, b, 1)
        
        local pct = math.min(100, math.floor((currentVal / maxRange) * 100))
        if isExalted and currentVal >= maxRange then
            detailBarText:SetText(string.format("%s (Max)", standingName))
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
        row:SetSize(318, 38)
        
        -- Background
        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        row.Bg = bg
        
        -- Highlight Overlay
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.2)
        hl:SetAllPoints(row)
        
        -- Selected Overlay
        local sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        sel:SetBlendMode("ADD")
        sel:SetAlpha(0.35)
        sel:SetAllPoints(row)
        sel:Hide()
        row.SelectedHighlight = sel
        
        -- Header Title (for Category rows)
        local headerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headerText:SetPoint("LEFT", row, "LEFT", 26, 0)
        headerText:SetJustifyH("LEFT")
        headerText:Hide()
        row.HeaderText = headerText
        
        -- Header Toggle Icon ([+] / [-])
        local headerIcon = row:CreateTexture(nil, "OVERLAY")
        headerIcon:SetSize(14, 14)
        headerIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
        headerIcon:Hide()
        row.HeaderIcon = headerIcon
        
        -- Header Counts Badge
        local headerCount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        headerCount:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        headerCount:SetJustifyH("RIGHT")
        headerCount:Hide()
        row.HeaderCount = headerCount
        
        -- Faction Name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
        nameText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -26, -4)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        nameText:SetTextColor(0.95, 0.95, 0.95, 1)
        row.NameText = nameText
        
        -- Status Progress Bar
        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 5)
        bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 5)
        bar:SetHeight(14)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        
        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(bar)
        barBg:SetColorTexture(0.08, 0.08, 0.10, 0.9)
        
        local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
        barText:SetFont(GameFontHighlightSmall:GetFont(), 10, "OUTLINE")
        barText:SetTextColor(1, 1, 1, 1)
        
        row.Bar = bar
        row.BarText = barText
        
        -- Watched Star / Check Icon
        local watchedIcon = row:CreateTexture(nil, "OVERLAY")
        watchedIcon:SetSize(14, 14)
        watchedIcon:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
        watchedIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        watchedIcon:Hide()
        row.WatchedIcon = watchedIcon
        
        -- At War Swords Icon
        local atWarIcon = row:CreateTexture(nil, "OVERLAY")
        atWarIcon:SetSize(14, 14)
        atWarIcon:SetPoint("RIGHT", watchedIcon, "LEFT", -2, 0)
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
                        -- Render as Category Header
                        row:SetHeight(26)
                        row.Bg:SetColorTexture(0.16, 0.16, 0.20, 0.95)
                        row.HeaderText:Show()
                        row.HeaderText:SetText(d.name)
                        
                        row.HeaderIcon:Show()
                        row.HeaderIcon:SetTexture(d.isCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                        
                        local stats = categoryStats[d.name]
                        if stats and stats.total > 0 then
                            row.HeaderCount:Show()
                            row.HeaderCount:SetText(string.format("|cffaaaaaa(%d/%d Exalted)|r", stats.exalted, stats.total))
                        else
                            row.HeaderCount:Hide()
                        end
                        
                        row.NameText:Hide()
                        row.Bar:Hide()
                        row.WatchedIcon:Hide()
                        row.AtWarIcon:Hide()
                        row.SelectedHighlight:Hide()
                        
                        row:SetScript("OnClick", function()
                            SafeToggleHeader(d.index, d.isCollapsed)
                            RefreshList()
                        end)
                        
                        yOffset = yOffset - 30
                    else
                        -- Render as Faction Row
                        row:SetHeight(38)
                        
                        if rowIndex % 2 == 1 then
                            row.Bg:SetColorTexture(0.10, 0.10, 0.12, 0.7)
                        else
                            row.Bg:SetColorTexture(0.05, 0.05, 0.07, 0.7)
                        end
                        
                        row.HeaderText:Hide()
                        row.HeaderIcon:Hide()
                        row.HeaderCount:Hide()
                        
                        row.NameText:Show()
                        row.NameText:SetText(d.name)
                        
                        row.Bar:Show()
                        local standingName = STANDING_LABELS[d.standingID] or "Neutral"
                        local r, g, b = GetStandingColor(d.standingID)
                        row.Bar:SetStatusBarColor(r, g, b, 1)
                        
                        local barMin = d.barMin or 0
                        local barMax = d.barMax or 1
                        local barValue = d.barValue or 0
                        local maxRange = barMax - barMin
                        local currentVal = barValue - barMin
                        if maxRange <= 0 then maxRange = 1 end
                        if currentVal < 0 then currentVal = 0 end
                        
                        row.Bar:SetMinMaxValues(0, maxRange)
                        row.Bar:SetValue(math.min(maxRange, currentVal))
                        
                        local isExalted = (d.standingID == 8)
                        if isExalted and currentVal >= maxRange then
                            row.BarText:SetText(string.format("%s", standingName))
                        else
                            local pct = math.min(100, math.floor((currentVal / maxRange) * 100))
                            row.BarText:SetText(string.format("%s - %s / %s (%d%%)", standingName, FormatNumber(currentVal), FormatNumber(maxRange), pct))
                        end
                        
                        row.WatchedIcon:SetShown(d.isWatched == true)
                        row.AtWarIcon:SetShown(d.atWarWith == true)
                        
                        -- Selection match
                        if not selectedFactionID and rowIndex == 1 and not d.isHeader then
                            selectedFactionID = d.factionID or d.index
                        end
                        
                        local isSelected = (selectedFactionID == (d.factionID or d.index))
                        row.SelectedHighlight:SetShown(isSelected)
                        if isSelected then selectedData = d end
                        
                        row:SetScript("OnClick", function()
                            selectedFactionID = d.factionID or d.index
                            UpdateDetails(d)
                            RefreshList()
                        end)
                        
                        yOffset = yOffset - 42
                    end
                    
                    row:Show()
                    rowIndex = rowIndex + 1
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
