local vips = {}

LoadVips = function()
    local function load()
        MySQL.query('SELECT identifier, expiry FROM koja_cardealer_vips', {}, function(rows)
            for i = 1, #(rows or {}) do
                vips[rows[i].identifier] = rows[i].expiry
            end
        end)
    end
    if KOJA.CreateAutoTable then
        MySQL.query('CREATE TABLE IF NOT EXISTS koja_cardealer_vips (identifier VARCHAR(64) PRIMARY KEY, expiry INT NOT NULL DEFAULT 0)', {}, load)
    else
        load()
    end
end

IsVipIdentifier = function(identifier)
    local expiry = vips[identifier]
    if not expiry then return false, 0 end
    if expiry ~= 0 and expiry < os.time() then
        vips[identifier] = nil
        MySQL.query('DELETE FROM koja_cardealer_vips WHERE identifier = ?', { identifier })
        return false, 0
    end
    return true, expiry
end

IsPlayerVip = function(source)
    if not KOJA.Vip.enable then return false, 0 end
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    if not identifier then return false, 0 end
    return IsVipIdentifier(identifier)
end

SetPlayerVip = function(source, days)
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    if not identifier then return false end
    days = tonumber(days) or 0
    if days <= 0 then
        vips[identifier] = 0
    else
        local base = os.time()
        local _, currentExpiry = IsVipIdentifier(identifier)
        if currentExpiry and currentExpiry > base then
            base = currentExpiry
        end
        vips[identifier] = base + days * 24 * 60 * 60
    end
    MySQL.query('INSERT INTO koja_cardealer_vips (identifier, expiry) VALUES (?, ?) ON DUPLICATE KEY UPDATE expiry = ?', { identifier, vips[identifier], vips[identifier] })
    return true
end

RemovePlayerVip = function(source)
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    if not identifier then return false end
    vips[identifier] = nil
    MySQL.query('DELETE FROM koja_cardealer_vips WHERE identifier = ?', { identifier })
    return true
end

exports('IsPlayerVip', function(source) local vip = IsPlayerVip(source) return vip end)
exports('SetPlayerVip', SetPlayerVip)
exports('RemovePlayerVip', RemovePlayerVip)

ApplyVipDiscount = function(source, price)
    if not KOJA.Vip.enable or (KOJA.Vip.discount or 0) <= 0 then return price, false end
    local vip = IsPlayerVip(source)
    if not vip then return price, false end
    return math.floor(price * (100 - KOJA.Vip.discount) / 100), true
end

KojaLib.Server.RegisterServerCallback('koja:buyVip', function(source, data, cb)
    if not KOJA.Vip.enable or not KOJA.Vip.purchasable then
        cb({ success = false, message = 'game.vip.disabled' })
        return
    end
    local vip = IsPlayerVip(source)
    if vip then
        cb({ success = false, message = 'game.vip.already' })
        return
    end
    local charged, err = ChargePlayer(source, KOJA.Vip.price, data and data.payment)
    if not charged then
        cb({ success = false, message = err })
        return
    end
    SetPlayerVip(source, KOJA.Vip.days)
    local logData = {
        message = string.format("**Player:** %s\n**Purchased VIP** (%s days) for $%s", GetPlayerName(source), KOJA.Vip.days, KOJA.Vip.price),
        title = 'VIP Purchase',
        footertext = 'KOJA_CARDEALER'
    }
    KojaLib.Server.LogMessage(logData, 'cardealer')
    local _, expiry = IsPlayerVip(source)
    cb({ success = true, expiry = expiry })
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LoadVips()
end)
