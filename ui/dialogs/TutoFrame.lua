AprRC.TutoFrame = AprRC:NewModule('TutoFrame')

function AprRC.TutoFrame:ShowCustomTutorialFrame(message, direction, anchor)
    return TutorialPointerFrame:Show(message, direction, anchor, 0, 10)
end

function AprRC.TutoFrame:HideCustomTutorialFrame(frameID)
    if frameID then
        TutorialPointerFrame:Hide(frameID)
    end
end
