-- Record the selected option ID, including timelines introduced after this addon.
hooksecurefunc(C_ChromieTime, "SelectChromieTimeOption", function(optionID)
    if not AprRC:IsRecordingContext() or type(optionID) ~= "number" or optionID <= 0 then return end
    local context = AprRC:CaptureRecordingContext()
    local step = { ChromiePick = optionID }
    AprRC:SetStepCoord(step)
    local attempts = 0
    local function checkSelection()
        if not AprRC:IsRecordingContext(context) then return end
        local info = C_ChromieTime.GetChromieTimeExpansionOption(optionID)
        if info and info.alreadyOn then
            if AprRC:GetLastStep().ChromiePick ~= optionID then AprRC:NewStep(step) end
        elseif attempts < 10 then
            attempts = attempts + 1
            C_Timer.After(0.3, checkSelection)
        end
    end
    C_Timer.After(0.1, checkSelection)
end)
