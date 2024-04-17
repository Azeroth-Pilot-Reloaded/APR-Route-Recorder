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
    local selectedRouteName = ''
    for index, route in ipairs(AprRCData.Routes) do
        if index == 1 then
            selectedRouteName = route.name
        end
        routeList[index] = route.name
        if AprRCData.CurrentRoute and route.name == AprRCData.CurrentRoute.name then
            defaultIndex = index
            selectedRouteName = route.name
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

    local btnExportELT = AceGUI:Create("Button")
    btnExportELT:SetText("Export Extra Line Text")
    btnExportELT:SetWidth(200)
    btnExportELT:SetCallback("OnClick", function()
        AprRC.exportExtraLineText.Show()
        AceGUI:Release(frame)
    end)
    frame:AddChild(btnExportELT)

    local btnSave = AceGUI:Create("Button")
    btnSave:SetText("Save Route")
    btnSave:SetWidth(200)
    btnSave:SetCallback("OnClick", function()
        local routeText = editbox:GetText()
        local newStepRouteTable = AprRC:stringToTable(routeText)
        local newRoute = { name = selectedRouteName, steps = newStepRouteTable }
        AprRC:UpdateRouteByName(selectedRouteName, newRoute)
        if AprRCData.CurrentRoute.name == selectedRouteName then
            AprRCData.CurrentRoute = newRoute
        end
    end)
    frame:AddChild(btnSave)

    -- local btnDelete = AceGUI:Create("Button")
    -- btnDelete:SetText("Delete this route")
    -- btnDelete:SetWidth(200)
    -- btnDelete:SetCallback("OnClick", function()
    --     routeList[defaultIndex] = nil
    --     AprRCData.Routes[defaultIndex] = nil
    --     dropdown:SetList(routeList)
    --     dropdown:SetValue(1)
    --     editbox:SetText(AprRC:RouteToString(AprRCData.Routes[1].steps))
    -- end)
    -- frame:AddChild(btnDelete)

    if defaultIndex then
        dropdown:SetValue(defaultIndex)
        editbox:SetText(AprRC:RouteToString(AprRCData.Routes[defaultIndex].steps))
    end

    dropdown:SetCallback("OnValueChanged", function(widget, event, index)
        local selectedRoute = AprRCData.Routes[index]
        if selectedRoute then
            editbox:SetText(AprRC:RouteToString(selectedRoute.steps))
            selectedRouteName = selectedRoute.name
        end
    end)
end
