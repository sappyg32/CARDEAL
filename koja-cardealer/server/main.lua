Koja = {}
Koja.Misc = Misc.Utils
Koja.Server = {
    MySQL = {
        Async = {},
        Sync = {}
    }
}

ChargePlayer = function(source, price, method)
    if price <= 0 then return true, nil end
    method = (method == 'bank') and 'bank' or 'cash'
    local balance = KojaLib.Server.getMoney(source, method)
    if balance < price then
        return false, (method == 'bank') and 'game.purchase_modal.purchase_enough_bank' or 'game.purchase_modal.purchase_enough_cash'
    end
    KojaLib.Server.removeMoney(source, price, method)
    return true, nil
end

ResolveFinalPrice = function(source, dealerId, model, basePrice)
    local applied = {}
    local price, promo = ApplyPromotion(dealerId, model, basePrice)
    if promo then applied.promo = promo end
    local vipPrice, vipApplied = ApplyVipDiscount(source, price)
    price = vipPrice
    if vipApplied then applied.vip = KOJA.Vip.discount end
    local coupon = GetActiveCoupon(source)
    if coupon then
        price = math.floor(price * (100 - coupon.discount) / 100)
        applied.coupon = coupon
    end
    return price, applied
end

KojaLib.Server.RegisterServerCallback("koja:purchaseVehicle", function(source, data, cb)
    local _source = source
    local xPlayer = KojaLib.Server.GetPlayerBySource(_source)
    local identifier = KojaLib.Server.GetPlayerIdentifier(_source)
    local car = FindDealerCar(data.dealer, data.model)
    if not car then
        cb({ success = false, message = 'game.purchase_modal.purchase_enough_error' })
        return
    end
    local dealer = GetDealerById(data.dealer)
    if dealer and dealer.vipOnly and not IsPlayerVip(_source) then
        cb({ success = false, message = 'game.vip.dealer_locked' })
        return
    end
    if KOJA.Prestige.enable and (car.prestige or 0) > 0 then
        local prestige = Misc.Utils.GetPlayerPrestige(_source)
        if prestige < car.prestige then
            cb({ success = false, message = 'game.purchase_modal.purchase_prestige', variables = { prestige = car.prestige } })
            return
        end
    end
    if KOJA.LimitedStock.enable and car.limited and (tonumber(car.stock) or 0) <= 0 then
        cb({ success = false, message = 'game.purchase_modal.purchase_soldout' })
        return
    end
    local price, applied = ResolveFinalPrice(_source, data.dealer, data.model, car.price)
    local useLeasing = data.leasing == true and KOJA.Leasing.enable
    local chargeAmount = useLeasing and GetLeaseDownPayment(price) or price
    local charged, err = ChargePlayer(_source, chargeAmount, data.payment)
    if not charged then
        cb({ success = false, message = err })
        return
    end
    if KOJA.LimitedStock.enable and car.limited then
        if not DecrementStock(data.dealer, data.model) then
            KojaLib.Server.addMoney(_source, chargeAmount, (data.payment == 'bank') and 'bank' or 'cash')
            cb({ success = false, message = 'game.purchase_modal.purchase_soldout' })
            return
        end
    end
    local plate = Misc.Utils.GeneratePlate()
    if applied.coupon then
        ConsumeCoupon(_source)
    end
    local lease = nil
    if useLeasing then
        lease = CreateLease(identifier, { name = car.name, model = data.model, plate = plate }, price)
    end
    local saveData = {
        player = xPlayer,
        source = _source,
        identifier = identifier,
        vehicle = {
            name = data.model,
            plate = plate,
            price = price,
            payment = useLeasing and 'leasing' or ((data.payment == 'bank') and 'bank' or 'cash')
        }
    }
    SaveVehicleToGarage(saveData)
    Misc.Utils.SaveVehicle(saveData)
    Misc.Utils.OnVehiclePurchased(_source, price)
    cb({ success = true, plate = plate, price = price, applied = applied, lease = lease })
end)

KojaLib.Server.RegisterServerCallback("koja:payTestDriveTuning", function(source, data, cb)
    local price = KOJA.TestDrive.tuningPrice or 0
    if price <= 0 then
        cb({ success = true })
        return
    end
    local charged, err = ChargePlayer(source, price, data and data.payment)
    if not charged then
        cb({ success = false, message = err })
        return
    end
    cb({ success = true })
end)

KojaLib.Server.RegisterServerCallback("koja:getPlayerProfile", function(source, data, cb)
    local prestige, xp = Misc.Utils.GetPlayerPrestige(source)
    local vip, vipExpiry = IsPlayerVip(source)
    cb({
        name = GetPlayerName(source),
        prestige = prestige or 0,
        xp = xp or 0,
        xpPerLevel = KOJA.Prestige.xpPerLevel,
        prestigeEnabled = KOJA.Prestige.enable,
        vip = vip,
        vipExpiry = vipExpiry
    })
end)
