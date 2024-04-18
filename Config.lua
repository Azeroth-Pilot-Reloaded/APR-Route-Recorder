local _G = _G

-- Locale
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")


AprRC.settings = AprRC:NewModule("Settings", "AceConsole-3.0")

-- Ace option config table
local aceConfig = _G.LibStub("AceConfig-3.0")
local aceDialog = _G.LibStub("AceConfigDialog-3.0")

-- Databroker support -- minimapIcon
local libDataBroker = LibStub("LibDataBroker-1.1")
local libDBIcon = LibStub("LibDBIcon-1.0")

local function GetProfileOption(info) return AprRC.settings.profile[info[#info]] end

local function SetProfileOption(info, value)
    AprRC.settings.profile[info[#info]] = value
end

function AprRC.settings:ResetSettings()
    SettingsDB:ResetProfile()
    self:RefreshProfile()
end

function AprRC.settings:InitializeBlizOptions()
    self:InitializeSettings()
    self:createBlizzOptions()
    self:CreateMiniMapButton()

    self:RegisterChatCommand("aprrc", self.ChatCommand)
end

function AprRC.settings:InitializeSettings()
    -- Default setting
    local settingsDBDefaults = {
        profile = {
            -- frame
            recordBarFrame = {
                rotation = "HORIZONTAL",
                position = {},
                isRecording = false,
            },
            commandsBarFrame = {
                rotation = "HORIZONTAL",
                position = {},
                isRecording = false,
            },
            --debug
            minimap = { minimapPos = 285 },
            enableMinimapButton = true,
            debug = false,
            enableAddon = true,
        }
    }

    SettingsDB = LibStub("AceDB-3.0"):New("AprRCSettings", settingsDBDefaults)

    SettingsDB.RegisterCallback(self, "OnProfileChanged", "RefreshProfile")
    SettingsDB.RegisterCallback(self, "OnProfileCopied", "RefreshProfile")
    SettingsDB.RegisterCallback(self, "OnProfileReset", "RefreshProfile")
    self.profile = SettingsDB.profile
end

function AprRC.settings.ChatCommand(input)
    AprRC.command:SlashCmd(input)
end

function AprRC.settings:RefreshProfile()
    self.profile = SettingsDB.profile
    C_UI.Reload()
end

function AprRC.settings:createBlizzOptions()
    -- Setting definition
    local optionsTable = {
        name = AprRC.title .. ' - ' .. AprRC.version,
        type = "group",
        args = {
            discordButton = {
                order = 1.1,
                name = L_APR["JOIN_DISCORD"],
                type = "execute",
                width = 0.75,
                func = function()
                    APR.questionDialog:CreateEditBoxPopup(L_APR["COPY_HELPER"], L_APR["CLOSE"], AprRC.discord)
                end
            },
            githubButton = {
                order = 1.2,
                name = "Github",
                type = "execute",
                width = 0.75,
                func = function()
                    APR.questionDialog:CreateEditBoxPopup(L_APR["COPY_HELPER"], L_APR["CLOSE"], AprRC.github)
                end
            },
            buttonOffset = {
                order = 1.3,
                name = "",
                type = "description",
                width = 1.35,
            },
            resetButton = {
                order = 1.4,
                name = L_APR["RESET_SETTINGS"],
                type = "execute",
                width = 0.75,
                func = function()
                    APR.questionDialog:CreateQuestionPopup(
                        nil,
                        function() AprRC.settings:ResetSettings() end
                    )
                end
            },
            header_Automation = {
                order = 2,
                type = "header",
                width = "full",
                name = "Somthing :)",
            },
            somthing = {
                order = 3,
                type = "group",
                name = "What a group",
                inline = true,
                args = {
                    enableAddon = {
                        order = 3.1,
                        type = "toggle",
                        name = L_APR["ENABLE_ADDON"],
                        width = "full",
                        get = GetProfileOption,
                        set = function(info, value)
                            SetProfileOption(info, value)
                            self:ToggleAddon()
                        end,
                    },
                    enableMinimapButton = {
                        name = L_APR["ENABLE_MINIMAP_BUTTON"],
                        desc = L_APR["ENABLE_MINIMAP_BUTTON_DESC"],
                        type = "toggle",
                        width = "full",
                        order = 9.20,
                        get = GetProfileOption,
                        set = function(info, value)
                            SetProfileOption(info, value)
                            if value then
                                libDBIcon:Show(AprRC.title)
                            else
                                libDBIcon:Hide(AprRC.title)
                            end
                        end
                    },
                    debug = {
                        order = 3.2,
                        type = "toggle",
                        name = L_APR["DEBUG"],
                        width = "full",
                        get = GetProfileOption,
                        set = SetProfileOption,
                        disabled = function()
                            return not self.profile.enableAddon
                        end,
                    },
                }
            },
        }
    }

    -- Register setting to the option table
    aceConfig:RegisterOptionsTable(AprRC.title, optionsTable)
    -- Add settings to bliz option
    AprRC.Options = aceDialog:AddToBlizOptions(AprRC.title, AprRC.title)

    -- add profile to bliz option
    aceConfig:RegisterOptionsTable(AprRC.title .. "/Profile", _G.LibStub("AceDBOptions-3.0"):GetOptionsTable(SettingsDB))
    aceDialog:AddToBlizOptions(AprRC.title .. "/Profile", L_APR["PROFILES"], AprRC.title)
end

function AprRC.settings:CreateMiniMapButton()
    if not self.profile.enableMinimapButton then return end

    local minimapButton = libDataBroker:NewDataObject(AprRC.title, {
        type = "launcher",
        icon = "Interface\\AddOns\\APR-Recorder\\assets\\logo",
        OnClick = function(_, button)
            if button == "RightButton" then
                self.profile.enableAddon = not self.profile.enableAddon
                self:ToggleAddon()
            else
                AprRC.settings:OpenSettings(AprRC.title)
            end
        end,
        OnTooltipShow = function(tooltip)
            local toggleAddon = ''
            if self.profile.enableAddon then
                toggleAddon = "|ccce0000f " .. L_APR["DISABLE"] .. "|r"
            else
                toggleAddon = "|c33ecc00f " .. L_APR["ENABLE"] .. "|r"
            end
            tooltip:AddLine(AprRC.title)
            tooltip:AddLine(L_APR["LEFT_CLICK"] .. ": |cffeda55f" .. L_APR["SHOW_MENU"] .. "|r",
                unpack(AprRC.Color.white))
            tooltip:AddLine(L_APR["RIGHT_CLICK"] .. ": " .. toggleAddon .. "|cffeda55f " .. L_APR["ADDON"] .. "|r",
                unpack(AprRC.Color.white))
        end
    })

    libDBIcon:Register(AprRC.title, minimapButton, self.profile.minimap);
end

function AprRC.settings:ToggleAddon()
    AprRC.record:RefreshFrameAnchor()
end

function AprRC.settings:OpenSettings(name)
    if name == AprRC.title then
        InterfaceOptionsFrame_OpenToCategory(AprRC.title)
        AprRC.settings:OpenSettings(L_APR["PROFILES"])
    end
    if AprRC.Options then
        if SettingsPanel then
            local category = SettingsPanel:GetCategoryList():GetCategory(AprRC.Options.name)
            if category then
                SettingsPanel:Open()
                SettingsPanel:SelectCategory(category)
                if AprRC.OptionsRoute and category:HasSubcategories() then
                    for _, subcategory in pairs(category:GetSubcategories()) do
                        if subcategory:GetName() == name then
                            SettingsPanel:SelectCategory(subcategory)
                            break
                        end
                    end
                end
            end
            return
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory(AprRC.Options)
            if AprRC.OptionsRoute then
                InterfaceOptionsFrame_OpenToCategory(AprRC.OptionsRoute)
            end
            return
        end
    end
end
