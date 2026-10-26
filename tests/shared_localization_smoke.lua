local locale = LibStub("AceLocale-3.0"):GetLocale("APR")
local own = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local settings = AprRC.settings
settings.profile = { enableMinimapButton = true, enableAddon = true, minimap = {} }

-- An empty/old APR catalog must not report missing entries. Shared UI uses
-- translated recorder fallbacks, and Blizzard owns the Close button label.
settings:createBlizzOptions()
TestOptions.args.discordButton.func()
assert(TestPopup[1] == own.COPY_HELPER)
assert(TestPopup[2] == "Fermer")
TestOptions.args.githubButton.func()
assert(TestPopup[2] == "Fermer")
TestOptions.args.resetButton.func()
assert(TestConfirmation == "Réinitialiser les paramètres du recorder et recharger l’interface ?")
settings:CreateMiniMapButton()
local tooltip = {}
TestBroker.OnTooltipShow(tooltip)
assert(tooltip[2] == "Clic gauche : |cffeda55fAtelier de routes|r")
assert(tooltip[3]:find(own.DISABLE, 1, true))
settings.profile.enableAddon = false
tooltip = {}; TestBroker.OnTooltipShow(tooltip)
assert(tooltip[3]:find(own.ENABLE, 1, true))
assert(rawget(locale, "LEFT_CLICK_ACTION") == nil and rawget(locale, "LEFT_CLICK") == nil,
    "Missing shared keys must not be inserted into APR's locale table")

-- Prefer current APR translations and format their action parameter exactly
-- once. Legacy click labels and RESET_SETTINGS_CONFIRM deliberately stay absent.
locale.LEFT_CLICK_ACTION, locale.RIGHT_CLICK_ACTION = "Primaire : %s", "Secondaire : %s"
locale.JOIN_DISCORD, locale.COPY_HELPER = "Communauté APR", "Copier le lien APR"
assert(AprRC:APRText("JOIN_DISCORD") == "Communauté APR")
settings:createBlizzOptions()
assert(TestOptions.args.discordButton.name == "Communauté APR")
TestOptions.args.discordButton.func()
assert(TestPopup[1] == "Copier le lien APR" and TestPopup[2] == "Fermer")
tooltip = {}; TestBroker.OnTooltipShow(tooltip)
assert(tooltip[2] == "Primaire : |cffeda55fAtelier de routes|r")
assert(tooltip[3]:sub(1, #"Secondaire : ") == "Secondaire : ")

-- These validation messages belong to APR-Recorder, even when APR has no
-- entries for their keys. Exercise each invalid input without namespace fallback.
local valid, message = AprRC:ValidateRouteTable(false)
assert(not valid and message == "pas un tableau")
valid, message = AprRC:ValidateRouteTable({ bad = {} })
assert(not valid and message:find("bad", 1, true))
valid, message = AprRC:ValidateRouteTable({ false })
assert(not valid and message == "l'étape 1 n'est pas une table")
assert(#LocaleErrors == 0, table.concat(LocaleErrors, "\n"))
print("Shared APR localization: old/current catalogs, minimap click formats, settings and validation namespaces passed.")
