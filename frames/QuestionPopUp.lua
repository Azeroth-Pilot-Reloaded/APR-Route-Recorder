local _G = _G

AprRC.questionDialog = AprRC:NewModule("QuestionDialog")

function AprRC.questionDialog:CreateEditBoxPopupWithCallback(text, onAcceptCallback, defaultText)
    local dialogName = "APRRC_EDITBOX_DIALOG"

    local currentDefaultText = defaultText or ""

    StaticPopupDialogs[dialogName] = {
        text = text or "General Kenobi",
        hasEditBox = true,
        button1 = CONTINUE,
        button2 = CANCEL,
        OnShow = function(self)
            local box = _G[self:GetName() .. "EditBox"]
            local button = _G[self:GetName() .. "Button1"]

            if box then
                box:SetWidth(275)
                box:SetText(currentDefaultText)
                box:HighlightText()
                box:SetFocus()

                if box:GetText() == "" then
                    button:Disable()
                else
                    button:Enable()
                end

                box:SetScript("OnTextChanged", function(self2)
                    if self2:GetText() == "" then
                        button:Disable()
                    else
                        button:Enable()
                    end
                end)
            end
        end,
        OnAccept = function(self)
            local editBox = _G[self:GetName() .. "EditBox"]
            local inputText = editBox:GetText()
            if inputText ~= "" and type(onAcceptCallback) == "function" then
                onAcceptCallback(inputText)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3, -- ensures no conflict with other popups
    }

    -- Trigger the popup
    StaticPopup_Show(dialogName)
end
