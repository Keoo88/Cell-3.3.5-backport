local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

local aboutTab = Cell.CreateFrame("CellOptionsFrame_AboutTab", Cell.frames.optionsFrame, nil, nil, true)
Cell.frames.aboutTab = aboutTab
aboutTab:SetAllPoints(Cell.frames.optionsFrame)
aboutTab:Hide()

local authorText
local UpdateFont

-------------------------------------------------
-- description
-------------------------------------------------
local descriptionPane
local function CreateDescriptionPane()
    descriptionPane = Cell.CreateTitledPane(aboutTab, "Cell", 422, 130)
    descriptionPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -5)

    -- Code Snippets button
    local snippetsBtn = Cell.CreateButton(descriptionPane, L["Code Snippets"], "accent", {120, 17})
    snippetsBtn:SetPoint("TOPRIGHT")
    snippetsBtn:SetScript("OnClick", function()
        F.ShowCodeSnippets()
    end)

    local descText = descriptionPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    descText:SetPoint("TOPLEFT", 5, -27)
    descText:SetPoint("BOTTOMRIGHT", -10, 5)
    descText:SetJustifyH("LEFT")
    descText:SetJustifyV("TOP")
    descText:SetSpacing(7)
    descText:SetText(
        "|cfffabd2fCell|r\n"..
        "|cffffffffFast, compact raid and party frames with crisp debuff tracking, healer-friendly indicators, and a no-fuss setup.|r\n\n"..
        "|cff78d5ff3.3.5a backport by|r |cffffffffKeoo|r"
    )
end



-------------------------------------------------
-- author
-------------------------------------------------
local function CreateAuthorPane()
    local authorPane = Cell.CreateTitledPane(aboutTab, L["Author"], 205, 50)
    authorPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -150)

    authorText = authorPane:CreateFontString(nil, "OVERLAY")
    authorText:SetPoint("TOPLEFT", 5, -27)
    authorText.font = GameFontNormal:GetFont()
    authorText.size = 12
    UpdateFont(authorText)

    authorText:SetText("enderneko")
end

-------------------------------------------------
-- slash
-------------------------------------------------
local function CreateSlashPane()
    local slashPane = Cell.CreateTitledPane(aboutTab, L["Slash Commands"], 205, 50)
    slashPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 222, -150)

    local commandText = slashPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    commandText:SetPoint("TOPLEFT", 5, -27)
    commandText:SetText("/cell")
end

-------------------------------------------------
-- links
-------------------------------------------------
local links = {}
local function CreateLink(parent, id, icon, onEnter)
    local f = CreateFrame("Frame", nil, parent, nil)
    P.Size(f, 34, 34)
    f:SetBackdrop({bgFile = Cell.vars.whiteTexture})
    f:SetBackdropColor(0, 0, 0, 1)

    links[id] = f

    f.icon = f:CreateTexture(nil, "ARTWORK")
    P.Point(f.icon, "TOPLEFT", 1, -1)
    P.Point(f.icon, "BOTTOMRIGHT", -1, 1)
    f.icon:SetTexture(icon)

    f:SetScript("OnEnter", function()
        f:SetBackdropColor(Cell.GetAccentColorRGB())
        for  _id, _f in pairs(links) do
            if _id ~= id then
                _f:SetBackdropColor(0, 0, 0, 1)
            end
        end
        if onEnter then onEnter() end
    end)

    f:SetScript("OnHide", function()
        f:SetBackdropColor(0, 0, 0, 1)
    end)

    return f
end

local function CreateLinksPane()
    local linksPane = Cell.CreateTitledPane(aboutTab, L["Links"], 422, 100)
    linksPane:SetPoint("TOPLEFT", aboutTab, "TOPLEFT", 5, -210)

    local current

    local linksEB = Cell.CreateEditBox(linksPane, 412, 20)
    linksEB:SetPoint("TOPLEFT", 5, -27)
    linksEB:SetText("https://discord.gg/sKpJbUrsvR")
    linksEB:SetScript("OnTextChanged", function(self, userChanged)
        if userChanged then
            linksEB:SetText(current)
            linksEB:HighlightText()
        end
        linksEB:SetCursorPosition(0)
    end)
    linksEB:SetScript("OnMouseUp", function(self)
        linksEB:HighlightText()
    end)

    --! discord
    local discord = CreateLink(linksPane, "discord", "Interface\\AddOns\\Cell\\Media\\Links\\discord.tga", function()
        current = "https://discord.gg/sKpJbUrsvR"
        linksEB:SetText(current)
        linksEB:ClearFocus()
    end)
    discord:SetPoint("TOPLEFT", linksEB, "BOTTOMLEFT", 0, -7)

    linksEB:SetScript("OnShow", function()
        discord:GetScript("OnEnter")()
    end)
end

-------------------------------------------------
-- import & export
-------------------------------------------------
local function CreateImportExportPane()
    local iePane = Cell.CreateTitledPane(aboutTab, L["Import & Export All Settings"], 422, 50)
    iePane:SetPoint("TOPLEFT", 5, -320)

    local importBtn = Cell.CreateButton(iePane, L["Import"], "accent-hover", {134, 20})
    importBtn:SetPoint("TOPLEFT", 5, -27)
    importBtn:SetScript("OnClick", F.ShowImportFrame)
    importBtn:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\import", {16, 16}, {"LEFT", 2, 0})

    local exportBtn = Cell.CreateButton(iePane, L["Export"], "accent-hover", {134, 20})
    exportBtn:SetPoint("TOPLEFT", importBtn, "TOPRIGHT", 5, 0)
    exportBtn:SetScript("OnClick", F.ShowExportFrame)
    exportBtn:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\export", {16, 16}, {"LEFT", 2, 0})

    --! WotLK feature: кнопка «Резервные копии» возвращена вместе с
    --! About\Backup.lua - SavedVariable CellDBBackup и локали всё это время были
    --! на месте, не было только самой панели.
    local backupBtn = Cell.CreateButton(iePane, L["Backups"], "accent-hover", {134, 20})
    backupBtn:SetPoint("TOPLEFT", exportBtn, "TOPRIGHT", 5, 0)
    backupBtn:SetScript("OnClick", F.ShowBackupFrame)
    backupBtn:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\backup", {16, 16}, {"LEFT", 2, 0})
end

-------------------------------------------------
-- language selector
-------------------------------------------------
local function CreateLanguagePane()
    local langPane = Cell.CreateTitledPane(aboutTab, L["Language"] or "Language", 422, 50)
    langPane:SetPoint("TOPLEFT", 5, -375)

    -- Build dropdown items from available locales
    local items = {}
    for _, loc in ipairs(Cell.availableLocales) do
        table.insert(items, {
            ["text"] = loc.name,
            ["value"] = loc.code,
            ["onClick"] = function()
                local currentSetting = CellDB["general"]["locale"]
                local newSetting = loc.code
                
                -- Only prompt if actually changing
                if currentSetting ~= newSetting then
                    Cell.SetLocale(newSetting)
                    
                    -- Show reload prompt
                    local popup = StaticPopup_Show("CELL_RELOAD_UI", L["A UI reload is required.\nDo it now?"] or "A UI reload is required.\nDo it now?")
                end
            end,
        })
    end

    local langDropdown = Cell.CreateDropdown(langPane, 200)
    langDropdown:SetPoint("TOPLEFT", 5, -27)
    langDropdown:SetItems(items)

    -- Set current value
    local currentLocale = CellDB["general"]["locale"]
    langDropdown:SetSelectedValue(currentLocale)

    -- Store reference for updates
    langPane.dropdown = langDropdown
end

-------------------------------------------------
-- functions
-------------------------------------------------
local init
local function ShowTab(tab)
    if tab == "about" then
        if not init then
            init = true
            CreateDescriptionPane()
            CreateAuthorPane()
            CreateSlashPane()
            -- CreateTranslatorsPane()
            -- CreateSpecialThanksPane()
            -- CreateSupportersPane()
            CreateLinksPane()
            CreateImportExportPane()
            CreateLanguagePane()
        end
        aboutTab:Show()
        descriptionPane:SetTitle("Cell "..Cell.version)
    else
        aboutTab:Hide()
    end
end
Cell.RegisterCallback("ShowOptionsTab", "AboutTab_ShowTab", ShowTab)

UpdateFont = function(fs)
    if not fs then return end

    local font = fs.font or GameFontNormal:GetFont()
    fs:SetFont(font, fs.size + CellDB["appearance"]["optionsFontSizeOffset"], "")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowColor(0, 0, 0)
    fs:SetShadowOffset(1, -1)
end

function Cell.UpdateAboutFont()
    UpdateFont(authorText)
end
