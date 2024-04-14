local _G = _G
local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("APR-Recorder")
local L_APR = LibStub("AceLocale-3.0"):GetLocale("APR")

AprRC.export = AprRC:NewModule('Export')


function AprRC.export.Show()
  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Export")
  frame:SetLayout("Fill")
  frame:SetStatusText(L_APR["COPY_HELPER"])
  frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
  
  frame.scrollContainer = AceGUI:Create("ScrollFrame")
  frame.scrollContainer:SetLayout("Fill")
  frame.scrollContainer:SetFullHeight(true)
  frame:AddChild(frame.scrollContainer)

  local editbox = AceGUI:Create("MultiLineEditBox")
  editbox:SetLabel('')
  editbox:SetFullWidth(true)
  editbox:SetFullHeight(true)
  editbox:DisableButton(true)
  editbox:SetText('dayta')
  frame.scrollContainer:AddChild(editbox)
end
