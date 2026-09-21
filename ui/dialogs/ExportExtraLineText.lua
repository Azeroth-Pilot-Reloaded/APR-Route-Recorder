local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.exportExtraLineText = AprRC:NewModule('ExportExtraLineText')

function AprRC.exportExtraLineText.Show()
    local frame = AprRC:CreateWidget("Frame")
    frame:SetTitle(L["Export"])
    frame:SetLayout("Flow")
    frame:SetStatusText(L_APR["COPY_HELPER"])
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetHeight(450)

    local scrollContainer = AprRC:CreateWidget("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(300)
    scrollContainer:SetLayout("Fill")
    frame:AddChild(scrollContainer)

    local editbox = AprRC:CreateWidget("MultiLineEditBox")
    editbox:SetLabel('')
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    editbox:DisableButton(true)
    scrollContainer:AddChild(editbox)

    local btnExportRoute = AprRC:CreateWidget("Button")
    btnExportRoute:SetText(L["Export Route"])
    btnExportRoute:SetWidth(200)
    btnExportRoute:SetCallback("OnClick", function()
        AprRC.export.Show()
        AceGUI:Release(frame)
    end)
    frame:AddChild(btnExportRoute)

    local btnReset = AprRC:CreateWidget("Button")
    btnReset:SetText(L["Reset local Extra line text"])
    btnReset:SetWidth(200)
    btnReset:SetCallback("OnClick", function()
        AprRCData.ExtraLineTexts = {}
        editbox:SetText('')
    end)
    frame:AddChild(btnReset)

    local btnSave = AprRC:CreateWidget("Button")
    btnSave:SetText(L["Save Extra Line Text"])
    btnSave:SetWidth(200)
    btnSave:SetCallback("OnClick", function()
        local editedText = editbox:GetText()
        local formattedText = AprRC:FormatTextToTableString(editedText)
        local newTable = AprRC:StringToTable(formattedText, true)


        if not formattedText then
            APR:PrintError(L["Failed to save. Incorrect format."])
            return
        end

        AprRCData.ExtraLineTexts = newTable
        AprRC:Debug(L["Extra Line Text saved successfully."])
    end)
    frame:AddChild(btnSave)


    local text = AprRC:ExtraLinetableToString(AprRCData.ExtraLineTexts)
    text = string.gsub(text, '" = "', ' = "')
    text = string.gsub(text, ',\n  "', '\n')
    text = string.gsub(text, '{\n  "', '')
    text = string.gsub(text, ',\n}', '')
    editbox:SetText(text)
end
