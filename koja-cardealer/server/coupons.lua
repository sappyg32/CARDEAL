CouponCodes = {}
local playerUses = {}
local activeCoupons = {}

LoadCoupons = function()
    local function load()
        MySQL.query('SELECT identifier, code FROM koja_cardealer_coupon_uses', {}, function(rows)
            for i = 1, #(rows or {}) do
                playerUses[rows[i].identifier] = playerUses[rows[i].identifier] or {}
                playerUses[rows[i].identifier][rows[i].code] = true
            end
        end)
        MySQL.query('SELECT * FROM koja_cardealer_coupon_codes', {}, function(rows)
            CouponCodes = {}
            for i = 1, #(rows or {}) do
                local r = rows[i]
                CouponCodes[r.code] = { discount = r.discount, maxUses = r.maxUses, oncePerPlayer = r.oncePerPlayer == 1, uses = r.uses }
            end
            if not next(CouponCodes) and KOJA.Coupons.codes then
                for code, cfg in pairs(KOJA.Coupons.codes) do
                    SaveCouponCode(code, cfg.discount, cfg.maxUses or 0, cfg.oncePerPlayer ~= false)
                end
            end
        end)
    end
    if KOJA.CreateAutoTable then
        MySQL.query([[CREATE TABLE IF NOT EXISTS koja_cardealer_coupon_codes (
            code VARCHAR(32) PRIMARY KEY,
            discount INT NOT NULL,
            maxUses INT NOT NULL DEFAULT 0,
            oncePerPlayer TINYINT NOT NULL DEFAULT 1,
            uses INT NOT NULL DEFAULT 0
        )]], {}, function()
            MySQL.query('CREATE TABLE IF NOT EXISTS koja_cardealer_coupon_uses (identifier VARCHAR(64), code VARCHAR(32), PRIMARY KEY (identifier, code))', {}, load)
        end)
    else
        load()
    end
end

SaveCouponCode = function(code, discount, maxUses, oncePerPlayer)
    code = tostring(code):upper():gsub('%s', '')
    if code == '' then return false end
    local existing = CouponCodes[code]
    local uses = existing and existing.uses or 0
    CouponCodes[code] = {
        discount = math.max(0, math.min(100, math.floor(tonumber(discount) or 0))),
        maxUses = math.max(0, math.floor(tonumber(maxUses) or 0)),
        oncePerPlayer = oncePerPlayer == true,
        uses = uses
    }
    MySQL.query('INSERT INTO koja_cardealer_coupon_codes (code, discount, maxUses, oncePerPlayer, uses) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE discount = VALUES(discount), maxUses = VALUES(maxUses), oncePerPlayer = VALUES(oncePerPlayer)',
        { code, CouponCodes[code].discount, CouponCodes[code].maxUses, CouponCodes[code].oncePerPlayer and 1 or 0, uses })
    return true
end

DeleteCouponCode = function(code)
    code = tostring(code):upper()
    CouponCodes[code] = nil
    MySQL.query('DELETE FROM koja_cardealer_coupon_codes WHERE code = ?', { code })
end

GetCouponList = function()
    local list = {}
    for code, cfg in pairs(CouponCodes) do
        list[#list + 1] = {
            code = code,
            discount = cfg.discount,
            maxUses = cfg.maxUses,
            oncePerPlayer = cfg.oncePerPlayer,
            uses = cfg.uses
        }
    end
    return list
end

GetActiveCoupon = function(source)
    local code = activeCoupons[source]
    if not code then return nil end
    local cfg = CouponCodes[code]
    if not cfg then return nil end
    return { code = code, discount = cfg.discount }
end

ConsumeCoupon = function(source)
    local code = activeCoupons[source]
    if not code then return end
    local cfg = CouponCodes[code]
    if not cfg then return end
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    cfg.uses = (cfg.uses or 0) + 1
    playerUses[identifier] = playerUses[identifier] or {}
    playerUses[identifier][code] = true
    activeCoupons[source] = nil
    MySQL.query('UPDATE koja_cardealer_coupon_codes SET uses = ? WHERE code = ?', { cfg.uses, code })
    MySQL.query('INSERT IGNORE INTO koja_cardealer_coupon_uses (identifier, code) VALUES (?, ?)', { identifier, code })
end

KojaLib.Server.RegisterServerCallback('koja:redeemCoupon', function(source, data, cb)
    if not KOJA.Coupons.enable then
        cb({ success = false, message = 'game.coupon.disabled' })
        return
    end
    local code = tostring(data and data.code or ''):upper():gsub('%s', '')
    local cfg = CouponCodes[code]
    if not cfg then
        cb({ success = false, message = 'game.coupon.invalid' })
        return
    end
    if cfg.maxUses > 0 and (cfg.uses or 0) >= cfg.maxUses then
        cb({ success = false, message = 'game.coupon.exhausted' })
        return
    end
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    if cfg.oncePerPlayer and playerUses[identifier] and playerUses[identifier][code] then
        cb({ success = false, message = 'game.coupon.already_used' })
        return
    end
    activeCoupons[source] = code
    cb({ success = true, code = code, discount = cfg.discount })
end)

KojaLib.Server.RegisterServerCallback('koja:getCoupons', function(source, data, cb)
    if not IsDealerAdmin(source) then
        cb({ coupons = {} })
        return
    end
    cb({ coupons = GetCouponList() })
end)

KojaLib.Server.RegisterServerCallback('koja:saveCoupon', function(source, data, cb)
    if not IsDealerAdmin(source) then
        cb({ success = false, message = 'game.noPerms' })
        return
    end
    local ok = SaveCouponCode(data.code, data.discount, data.maxUses, data.oncePerPlayer)
    cb({ success = ok, coupons = GetCouponList() })
end)

KojaLib.Server.RegisterServerCallback('koja:deleteCoupon', function(source, data, cb)
    if not IsDealerAdmin(source) then
        cb({ success = false, message = 'game.noPerms' })
        return
    end
    DeleteCouponCode(data.code)
    cb({ success = true, coupons = GetCouponList() })
end)

AddEventHandler('playerDropped', function()
    activeCoupons[source] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LoadCoupons()
end)
