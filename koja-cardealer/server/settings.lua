Theme = '#9ca4aa'

LoadSettings = function()
    local function load()
        MySQL.query('SELECT v FROM koja_cardealer_settings WHERE k = ?', { 'theme' }, function(rows)
            if rows and rows[1] and rows[1].v then
                Theme = rows[1].v
                SyncTheme()
            end
        end)
    end
    if KOJA.CreateAutoTable then
        MySQL.query('CREATE TABLE IF NOT EXISTS koja_cardealer_settings (k VARCHAR(32) PRIMARY KEY, v VARCHAR(255) NOT NULL)', {}, load)
    else
        load()
    end
end

SaveTheme = function(color)
    Theme = color
    MySQL.query('INSERT INTO koja_cardealer_settings (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = ?', { 'theme', color, color })
end

SyncTheme = function(target)
    TriggerClientEvent('koja_cardealer:themeUpdate', target or -1, Theme)
end

KojaLib.Server.RegisterServerCallback('koja:getTheme', function(source, data, cb)
    cb({ theme = Theme })
end)

KojaLib.Server.RegisterServerCallback('koja:saveTheme', function(source, data, cb)
    if not IsDealerAdmin(source) then
        cb({ success = false, message = 'game.noPerms' })
        return
    end
    if type(data.theme) == 'string' and data.theme:match('^#%x%x%x%x%x%x$') then
        SaveTheme(data.theme)
        SyncTheme()
        cb({ success = true })
    else
        cb({ success = false })
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LoadSettings()
end)
