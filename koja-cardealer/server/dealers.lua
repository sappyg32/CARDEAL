Dealers = {}

local DEALERS_FILE = 'data/dealers.json'

LoadDealers = function()
    local raw = LoadResourceFile(GetCurrentResourceName(), DEALERS_FILE)
    if not raw then
        print('[KOJA_CARDEALER] Missing '..DEALERS_FILE..', starting with empty dealer list')
        Dealers = {}
        return
    end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        print('[KOJA_CARDEALER] Failed to parse '..DEALERS_FILE)
        Dealers = {}
        return
    end
    Dealers = decoded.dealers or {}
    print(('[KOJA_CARDEALER] Loaded %s dealer(s) from json'):format(#Dealers))
end

SaveDealers = function()
    SaveResourceFile(GetCurrentResourceName(), DEALERS_FILE, json.encode({ dealers = Dealers }, { indent = true }), -1)
end

SyncDealers = function(target)
    local payload = {
        dealers = Dealers,
        promotions = GetActivePromotions and GetActivePromotions() or {}
    }
    if target then
        TriggerClientEvent('koja_cardealer:syncDealers', target, payload)
    else
        TriggerClientEvent('koja_cardealer:syncDealers', -1, payload)
    end
end

GetDealerById = function(dealerId)
    for i = 1, #Dealers do
        if Dealers[i].id == dealerId then
            return Dealers[i]
        end
    end
    return nil
end

FindDealerCar = function(dealerId, model)
    local dealer = GetDealerById(dealerId)
    if not dealer then return nil end
    for _, category in ipairs(dealer.categories or {}) do
        for _, car in ipairs(category.cars or {}) do
            if car.model == model then
                return car
            end
        end
    end
    return nil
end

DecrementStock = function(dealerId, model)
    local car = FindDealerCar(dealerId, model)
    if not car or not car.limited then return true end
    local stock = tonumber(car.stock) or 0
    if stock <= 0 then return false end
    car.stock = stock - 1
    SaveDealers()
    SyncDealers()
    return true
end

IsDealerAdmin = function(source)
    if IsPlayerAceAllowed(source, KOJA.Admin.aceResource) then
        return true
    end
    local ok, group = pcall(function()
        local xPlayer = KojaLib.Server.GetPlayerBySource(source)
        if KojaLib.Framework == 'esx' then
            return xPlayer.getGroup()
        elseif KojaLib.Framework == 'qb' then
            return QBCore and QBCore.Functions.HasPermission(source, KOJA.Admin.groups) and KOJA.Admin.groups[1] or nil
        end
        return nil
    end)
    if ok and group then
        for _, g in ipairs(KOJA.Admin.groups) do
            if group == g then return true end
        end
    end
    return false
end

KojaLib.Server.RegisterServerCallback('koja:getDealers', function(source, data, cb)
    cb({
        dealers = Dealers,
        theme = Theme,
        promotions = GetActivePromotions and GetActivePromotions() or {}
    })
end)

KojaLib.Server.RegisterServerCallback('koja:checkAdmin', function(source, data, cb)
    cb({ admin = IsDealerAdmin(source) })
end)

SanitizeCoords = function(t)
    if type(t) ~= 'table' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z, heading = tonumber(t.heading) or 0.0 }
end

SanitizeDealers = function(dealers)
    if type(dealers) ~= 'table' then return nil end
    local out = {}
    for _, d in ipairs(dealers) do
        if type(d) == 'table' and type(d.name) == 'string' then
            local dealer = {
                id = tostring(d.id or d.name:lower():gsub('%s+', '_')..'_'..math.random(1000, 9999)),
                name = d.name,
                pos = {
                    x = tonumber(d.pos and d.pos.x) or 0.0,
                    y = tonumber(d.pos and d.pos.y) or 0.0,
                    z = tonumber(d.pos and d.pos.z) or 0.0,
                    heading = tonumber(d.pos and d.pos.heading) or 0.0
                },
                interaction = (d.interaction == 'npc' or d.interaction == 'zone') and d.interaction or 'marker',
                markerType = math.max(0, math.min(43, math.floor(tonumber(d.markerType) or 2))),
                blip = {
                    sprite = tonumber(d.blip and d.blip.sprite) or KOJA.Defaults.blip.sprite,
                    colour = tonumber(d.blip and d.blip.colour) or KOJA.Defaults.blip.colour,
                    rgb = (d.blip and type(d.blip.rgb) == 'table' and #d.blip.rgb == 3) and {
                        math.max(0, math.min(255, math.floor(tonumber(d.blip.rgb[1]) or 0))),
                        math.max(0, math.min(255, math.floor(tonumber(d.blip.rgb[2]) or 0))),
                        math.max(0, math.min(255, math.floor(tonumber(d.blip.rgb[3]) or 0)))
                    } or nil
                },
                permissions = d.permissions or { enable = false, groups = {} },
                vipOnly = d.vipOnly == true,
                blipPos = SanitizeCoords(d.blipPos),
                vehicleSpawn = SanitizeCoords(d.vehicleSpawn),
                vehicleBuySpawn = SanitizeCoords(d.vehicleBuySpawn),
                testDrive = SanitizeCoords(d.testDrive),
                categories = {}
            }
            for _, c in ipairs(d.categories or {}) do
                if type(c) == 'table' and type(c.name) == 'string' then
                    local category = { name = c.name, cars = {} }
                    for _, car in ipairs(c.cars or {}) do
                        if type(car) == 'table' and type(car.model) == 'string' and car.model ~= '' then
                            category.cars[#category.cars + 1] = {
                                name = tostring(car.name or car.model),
                                model = car.model,
                                price = math.max(0, math.floor(tonumber(car.price) or 0)),
                                limited = car.limited == true,
                                stock = math.max(0, math.floor(tonumber(car.stock) or 0)),
                                prestige = math.max(0, math.floor(tonumber(car.prestige) or 0)),
                                noPromo = car.noPromo == true
                            }
                        end
                    end
                    dealer.categories[#dealer.categories + 1] = category
                end
            end
            out[#out + 1] = dealer
        end
    end
    return out
end

KojaLib.Server.RegisterServerCallback('koja:saveDealers', function(source, data, cb)
    if not IsDealerAdmin(source) then
        cb({ success = false, message = 'game.noPerms' })
        return
    end
    local sanitized = SanitizeDealers(data and data.dealers)
    if not sanitized then
        cb({ success = false, message = 'game.notification.error' })
        return
    end
    Dealers = sanitized
    SaveDealers()
    if RollPromotions then
        RollPromotions()
    end
    SyncDealers()
    local logData = {
        message = string.format("**Admin:** %s\n**Updated car dealer configuration** (%s dealers)", GetPlayerName(source), #Dealers),
        title = 'Car Dealer Config Update',
        footertext = 'KOJA_CARDEALER'
    }
    KojaLib.Server.LogMessage(logData, 'cardealer')
    cb({ success = true })
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LoadDealers()
end)
