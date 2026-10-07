local adminOpen = false

OpenAdminMenu = function()
    KojaLib.Client.TriggerServerCallback('koja:checkAdmin', {}, function(result)
        if not result.admin then
            local notify = {
                title = 'game.notification.notify',
                desc = 'game.noPerms',
                time = 'game.notification.duration',
            }
            SendNotify(notify)
            return
        end
        KojaLib.Client.TriggerServerCallback('koja:getDealers', {}, function(payload)
            adminOpen = true
            SetNuiFocus(true, true)
            Koja.Client.SendReactMessage('koja_cardealer:setAdminVisible', true)
            Koja.Client.SendReactMessage('koja_cardealer:sendAdminData', {
                dealers = payload.dealers or {},
                theme = payload.theme,
                promotions = payload.promotions or {}
            })
        end)
    end)
end

RegisterCommand(KOJA.Admin.command, function()
    OpenAdminMenu()
end, false)

RegisterNUICallback('adminGetMyPos', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    cb({
        x = tonumber(string.format('%.4f', coords.x)),
        y = tonumber(string.format('%.4f', coords.y)),
        z = tonumber(string.format('%.4f', coords.z)),
        heading = tonumber(string.format('%.4f', heading))
    })
end)

RegisterNUICallback('adminSaveDealers', function(data, cb)
    KojaLib.Client.TriggerServerCallback('koja:saveDealers', { dealers = data.dealers }, function(result)
        if result.success then
            local notify = {
                title = 'game.notification.notify',
                desc = 'game.admin.saved',
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

RegisterNUICallback('adminGetCoupons', function(_, cb)
    KojaLib.Client.TriggerServerCallback('koja:getCoupons', {}, function(result)
        cb(result)
    end)
end)

RegisterNUICallback('adminSaveCoupon', function(data, cb)
    KojaLib.Client.TriggerServerCallback('koja:saveCoupon', data, function(result)
        cb(result)
    end)
end)

RegisterNUICallback('adminDeleteCoupon', function(data, cb)
    KojaLib.Client.TriggerServerCallback('koja:deleteCoupon', data, function(result)
        cb(result)
    end)
end)

RegisterNUICallback('getTheme', function(_, cb)
    KojaLib.Client.TriggerServerCallback('koja:getTheme', {}, function(result)
        cb(result)
    end)
end)

RegisterNUICallback('adminSaveTheme', function(data, cb)
    KojaLib.Client.TriggerServerCallback('koja:saveTheme', { theme = data.theme }, function(result)
        cb(result)
    end)
end)

RegisterNUICallback('adminClose', function(_, cb)
    cb(1)
    adminOpen = false
    SetNuiFocus(false, false)
    Koja.Client.SendReactMessage('koja_cardealer:setAdminVisible', false)
end)
