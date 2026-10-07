local leasingOpen = false

OpenLeasingPanel = function()
    if not KOJA.Leasing.enable then return end
    KojaLib.Client.TriggerServerCallback('koja:getLeases', {}, function(payload)
        leasingOpen = true
        SetNuiFocus(true, true)
        Koja.Client.SendReactMessage('koja_cardealer:setLeasingVisible', true)
        Koja.Client.SendReactMessage('koja_cardealer:sendLeases', payload)
    end)
end

RegisterCommand(KOJA.Leasing.command, function()
    OpenLeasingPanel()
end, false)

RegisterNUICallback('leasingClose', function(_, cb)
    cb(1)
    leasingOpen = false
    SetNuiFocus(false, false)
    Koja.Client.SendReactMessage('koja_cardealer:setLeasingVisible', false)
end)

RegisterNUICallback('payLease', function(data, cb)
    KojaLib.Client.TriggerServerCallback('koja:payLease', data, function(result)
        if result.success then
            local notify = {
                title = 'game.notification.notify',
                desc = result.paidOff and 'game.leasing.paid_off' or 'game.leasing.payment_done',
                time = 5000
            }
            SendNotify(notify)
        else
            local notify = {
                title = 'game.notification.notify',
                desc = result.message,
                time = 5000
            }
            SendNotify(notify)
        end
        cb(result)
    end)
end)

RegisterNUICallback('redeemCoupon', function(data, cb)
    KojaLib.Client.TriggerServerCallback('koja:redeemCoupon', data, function(result)
        if result.success then
            local notify = {
                title = 'game.notification.notify',
                desc = 'game.coupon.redeemed',
                time = 5000,
                variables = { discount = result.discount }
            }
            SendNotify(notify)
        else
            local notify = {
                title = 'game.notification.notify',
                desc = result.message,
                time = 5000
            }
            SendNotify(notify)
        end
        cb(result)
    end)
end)

RegisterNUICallback('buyVip', function(data, cb)
    KojaLib.Client.TriggerServerCallback('koja:buyVip', data, function(result)
        if result.success then
            local notify = {
                title = 'game.notification.notify',
                desc = 'game.vip.purchased',
                time = 5000
            }
            SendNotify(notify)
        else
            local notify = {
                title = 'game.notification.notify',
                desc = result.message,
                time = 5000
            }
            SendNotify(notify)
        end
        cb(result)
    end)
end)
