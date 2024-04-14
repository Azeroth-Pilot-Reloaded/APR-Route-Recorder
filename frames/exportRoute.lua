local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.export = AprRC:NewModule('Export')

function AprRC.export:Show()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Export")
    frame:SetLayout("Flow")
    frame:SetStatusText(L_APR["COPY_HELPER"])
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetHeight(750)

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetLabel("Select Route")
    dropdown:SetFullWidth(true)
    local routeList = {}
    local defaultIndex = nil
    for index, route in ipairs(AprRCData.Routes) do
        routeList[index] = route.name
        if AprRCData.CurrentRoute and route.name == AprRCData.CurrentRoute.name then
            defaultIndex = index
        end
    end
    dropdown:SetList(routeList)
    frame:AddChild(dropdown)

    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(600)
    scrollContainer:SetLayout("Fill")
    frame:AddChild(scrollContainer)

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox:SetLabel('')
    editbox:SetFullWidth(true)
    editbox:SetFullHeight(true)
    editbox:DisableButton(true)
    scrollContainer:AddChild(editbox)

    local btnReset = AceGUI:Create("Button")
    btnReset:SetText("Export Extra Line Text")
    btnReset:SetWidth(200)
    btnReset:SetCallback("OnClick", function()
        AprRC.exportExtraLineText.Show()
        AceGUI:Release(frame)
    end)
    frame:AddChild(btnReset)

    if defaultIndex then
        dropdown:SetValue(defaultIndex)
        editbox:SetText(AprRC:tableToString(AprRCData.Routes[defaultIndex].steps))
    end

    dropdown:SetCallback("OnValueChanged", function(widget, event, key)
        local selectedRoute = AprRCData.Routes[key]
        if selectedRoute then
            editbox:SetText(AprcRC:tableToString(selectedRoute.steps))
        end
    end)
end
