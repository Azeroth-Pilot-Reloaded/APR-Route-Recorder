local _G = _G

AprRC.questionDialog = AprRC:NewModule("QuestionDialog")

function AprRC.questionDialog:CreateEditBoxPopupWithCallback(text, onAcceptCallback)
    local dialogName = "EDITBOX_DIALOG"
    StaticPopupDialogs[dialogName] = {
        text = text or "General Kenobi",
        hasEditBox = true,
        button1 = CONTINUE,
        OnShow = function(self)
            local box = _G[self:GetName() .. "EditBox"]
            local button = _G[self:GetName() .. "Button1"] -- Récupère le bouton OK

            if box then
                box:SetWidth(275)
                box:SetText('')
                box:HighlightText()
                box:SetFocus()

                if box:GetText() == "" then
                    button:Disable()
                else
                    button:Enable()
                end

                box:SetScript("OnTextChanged", function(self)
                    if self:GetText() == "" then
                        button:Disable()
                    else
                        button:Enable()
                    end
                end)
            end
        end,
        OnAccept = function(self)
            local editBox = _G[self:GetName() .. "EditBox"]
            local text = editBox:GetText()
            if text ~= "" and onAcceptCallback and type(onAcceptCallback) == "function" then
                onAcceptCallback(text)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
    }

    StaticPopup_Show(dialogName)
end
