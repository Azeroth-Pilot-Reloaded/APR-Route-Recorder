local AceGUI = LibStub("AceGUI-3.0")

AprRC.SelectRoute = AprRC:NewModule('SelectRoute')

function AprRC.SelectRoute:Show()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Select Route")
    frame.statustext:GetParent():Hide()
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetWidth(600)
    frame:SetHeight(100)
    frame:SetLayout("Flow")

    local dropdown = AceGUI:Create("Dropdown")
    dropdown:SetFullWidth(true)
    local routeList = {}
    for index, route in ipairs(AprRCData.Routes) do
        routeList[index] = route.name
    end
    local selectedRouteName = routeList[1]
    dropdown:SetList(routeList)
    dropdown:SetValue(1)
    frame:AddChild(dropdown)

    dropdown:SetCallback("OnValueChanged", function(widget, event, index)
        selectedRouteName = routeList[index]
    end)

    local confirmBtn = AceGUI:Create("Button")
    confirmBtn:SetText(CONTINUE)
    confirmBtn:SetWidth(200)
    confirmBtn:SetCallback("OnClick", function()
        local route = AprRC:FindRouteByName(selectedRouteName)
        AprRCData.CurrentRoute = { name = selectedRouteName, steps = route.steps }
        AceGUI:Release(frame)
        AprRC.record:UpdateRecordButton()
    end)
    frame:AddChild(confirmBtn)

    local newRouteBtn = AceGUI:Create("Button")
    newRouteBtn:SetText(NEW)
    newRouteBtn:SetWidth(200)
    newRouteBtn:SetCallback("OnClick", function()
        AceGUI:Release(frame)
        AprRC.questionDialog:CreateEditBoxPopupWithCallback("Route Name", function(text)
            AprRC:InitRoute(text)
            AprRC.record:UpdateRecordButton()
        end)
    end)
    frame:AddChild(newRouteBtn)
end
