
function Debug(msg, data)
    if not AprRC.settings.profile.debug then
        return
    end
    if type(data) == 'table' then
        for key, value in pairs(data) do
            print(msg, ' - ', key, value)
        end
    else
        print(msg, ' - ', data)
    end
end
