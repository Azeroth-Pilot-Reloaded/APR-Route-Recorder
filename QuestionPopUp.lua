local _G = _G

AprRC.questionDialog = AprRC:NewModule("QuestionDialog")

---------------------------------------------------------------------------------------
--------------------------- Dialog for some actions xD --------------------------------
---------------------------------------------------------------------------------------
function AprRC.questionDialog:CreateQuestionPopup(text, onAcceptFunction, onCancelFunction, acceptButtonText,
                                                  cancelButtonText, hideOnEscape)
    local dialogName = "QUESTION_DIALOG"
    StaticPopupDialogs[dialogName] = {
        text = text or CONFIRM_CONTINUE,
        button1 = acceptButtonText or ACCEPT,
        button2 = cancelButtonText or CANCEL,
        OnAccept = onAcceptFunction,
        OnCancel = onCancelFunction,
        timeout = 0,
        whileDead = true,
        hideOnEscape = hideOnEscape or true,
    }

    StaticPopup_Show(dialogName)
end

function AprRC.questionDialog:CreateMessagePopup(text, closeButtonText)
    local dialogName = "MESSAGE_DIALOG"
    StaticPopupDialogs[dialogName] = {
        text = text or CONFIRM_CONTINUE,
        button1 = closeButtonText or OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopup_Show(dialogName)
end

function AprRC.questionDialog:CreateEditBoxPopup(text, closeButtonText, editBoxText)
    local dialogName = "EDITBOX_DIALOG"
    StaticPopupDialogs[dialogName] = {
        text = text or "General Kenobi",
        hasEditBox = 1,
        button1 = closeButtonText or OKAY,
        OnShow = function(self)
            if editBoxText then
                local box = getglobal(self:GetName() .. "EditBox")
                if box then
                    box:SetWidth(275)
                    box:SetText(editBoxText)
                    box:HighlightText()
                    box:SetFocus()
                end
            end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopup_Show(dialogName)
end
