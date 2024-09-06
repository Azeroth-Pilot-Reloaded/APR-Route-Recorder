local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local AceTimer = LibStub("AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.export = AprRC:NewModule('Export')

local frame
function AprRC.export:Hide()
    if frame then
        AceGUI:Release(frame)
    end
    frame = nil
end

function AprRC.export:Show()
    local refreshTimer


    frame = AceGUI:Create("Frame")
    frame:SetTitle("Export")
    frame:SetLayout("Flow")
    frame:SetStatusText(L_APR["COPY_HELPER"])
    frame:SetHeight(775)

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
    AprRC.export.editbox = editbox

    local function AutoScrollToBottom()
        C_Timer.After(0.1, function()
            local scrollFrame = editbox.scrollFrame
            scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
        end)
    end

    local function StartAutoRefresh(dropdown, editbox)
        if not refreshTimer then
            refreshTimer = AceTimer:ScheduleRepeatingTimer(function()
                if dropdown:GetValue() then
                    if AprRCData.CurrentRoute.name ~= "" then
                        AprRC:UpdateRouteByName(AprRCData.CurrentRoute.name, AprRCData.CurrentRoute)
                        local route = AprRCData.Routes[dropdown:GetValue()]
                        if route then
                            editbox:SetText(AprRC:TableToString(route.steps))
                            AutoScrollToBottom()
                        end
                    end
                end
            end, 2)
        end
    end

    local function StopAutoRefresh()
        if refreshTimer then
            AceTimer:CancelTimer(refreshTimer)
            refreshTimer = nil
        end
    end


    local btnExportELT = AceGUI:Create("Button")
    btnExportELT:SetText("Export Extra Line Text")
    btnExportELT:SetWidth(200)
    btnExportELT:SetCallback("OnClick", function()
        AprRC.exportExtraLineText.Show()
        AceGUI:Release(frame)
        frame = nil
    end)
    frame:AddChild(btnExportELT)

    local btnSave = AceGUI:Create("Button")
    btnSave:SetText("Save Route")
    btnSave:SetWidth(200)
    btnSave:SetCallback("OnClick", function()
        local routeText = editbox:GetText()
        local newStepRouteTable = AprRC:StringToTable(routeText)
        if not newStepRouteTable then
            AprRC:Error("Route not saved, incorrect format")
            return
        end
        local newRoute = { name = selectedRouteName, steps = newStepRouteTable }
        AprRC:UpdateRouteByName(selectedRouteName, newRoute)
        if AprRCData.CurrentRoute.name == selectedRouteName then
            AprRCData.CurrentRoute = newRoute
        end
        AprRCData.BackupRoute = { }
        for k, v in pairs(newStepRouteTable) do
            AprRCData.BackupRoute[k] = v
        end
        AutoScrollToBottom()
    end)
    frame:AddChild(btnSave)

    local exportToAPRBtn = AceGUI:Create("Button")
    exportToAPRBtn:SetText("Export this route into APR")
    exportToAPRBtn:SetWidth(200)
    exportToAPRBtn:SetCallback("OnClick", function()
        local route = AprRC:FindRouteByName(selectedRouteName)
        local name = route.name .. ' - Custom'
        APRData.CustomRoute[name] = route.steps
        APR.RouteQuestStepList[name] = route.steps
        APR.RouteList.Custom[name] = name:match("%d+-(.*)")
        AutoScrollToBottom()
    end)
    frame:AddChild(exportToAPRBtn)

    local checkbox = AceGUI:Create("CheckBox")
    checkbox:SetLabel("Enable Auto Refresh")
    checkbox:SetWidth(200)
    checkbox:SetValue(false)
    checkbox:SetDisabled(true)
    checkbox:SetCallback("OnValueChanged", function(widget, event, value)
        if value then
            StartAutoRefresh(dropdown, editbox)
        else
            StopAutoRefresh()
        end
    end)
    frame:AddChild(checkbox)

    if defaultIndex then
        if AprRCData.Routes[defaultIndex].name == AprRCData.CurrentRoute.name then
            checkbox:SetDisabled(false)
        end
        dropdown:SetValue(defaultIndex)
        editbox:SetText(AprRC:TableToString(AprRCData.Routes[defaultIndex].steps))
        AutoScrollToBottom()
    end

    dropdown:SetCallback("OnValueChanged", function(widget, event, index)
        local selectedRoute = AprRCData.Routes[index]
        if selectedRoute then
            editbox:SetText(AprRC:TableToString(selectedRoute.steps))
            selectedRouteName = selectedRoute.name
            if selectedRouteName == AprRCData.CurrentRoute.name then
                checkbox:SetDisabled(false)
            else
                checkbox:SetDisabled(true)
                checkbox:SetValue(false)
                StopAutoRefresh()
            end
            AutoScrollToBottom()
        end
    end)

    frame:SetCallback("OnClose", function(widget)
        StopAutoRefresh()
        AceGUI:Release(widget)
        frame = nil
    end)
end
