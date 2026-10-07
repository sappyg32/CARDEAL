Koja = {}
Koja.Misc = Misc.Utils
Koja.Client = {}

local points = {}
local peds = {}
local blips = {}

DealersData = {}
PromotionsData = {}

local currentVehicle = {}
local menuOpen = false
local currentDealer = nil

VehicleStatistic = function(vehicle)
    local maxSpeed = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveMaxFlatVel")
    local acceleration = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fInitialDriveForce")
    local braking = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fBrakeForce")
    local traction = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fTractionCurveMax")
    local scale = function(value, max)
        local v = math.floor((value / max) * 10 + 0.5)
        if v < 1 then v = 1 end
        if v > 10 then v = 10 end
        return v
    end
    return {
        speed = scale(maxSpeed, 200.0),
        acceleration = scale(acceleration, 0.5),
        braking = scale(braking, 1.5),
        handling = scale(traction, 3.0)
    }
end

OffsetFromDealer = function(dealer, distance)
    local rad = math.rad(dealer.pos.heading or 0.0)
    return {
        coords = vec3(dealer.pos.x - math.sin(rad) * distance, dealer.pos.y + math.cos(rad) * distance, dealer.pos.z),
        heading = dealer.pos.heading or 0.0
    }
end

GetBuySpawn = function(dealer)
    if dealer.vehicleBuySpawn then
        return {
            coords = vec3(dealer.vehicleBuySpawn.x, dealer.vehicleBuySpawn.y, dealer.vehicleBuySpawn.z),
            heading = dealer.vehicleBuySpawn.heading or 0.0
        }
    end
    return OffsetFromDealer(dealer, 5.0)
end

GetTestDriveSpawn = function(dealer)
    if dealer.testDrive then
        return {
            coords = vec3(dealer.testDrive.x, dealer.testDrive.y, dealer.testDrive.z),
            heading = dealer.testDrive.heading or 0.0
        }
    end
    return OffsetFromDealer(dealer, 5.0)
end

ClearInteractions = function()
    for _, pts in pairs(points) do
        pts:remove()
    end
    points = {}
    for _, ped in pairs(peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    peds = {}
    for _, blip in pairs(blips) do
        RemoveBlip(blip)
    end
    blips = {}
end

SetupDealers = function()
    ClearInteractions()
    for i = 1, #DealersData do
        local dealer = DealersData[i]
        local pos = vec3(dealer.pos.x, dealer.pos.y, dealer.pos.z)

        if KOJA.Defaults.blip.visible then
            local blipPos = dealer.blipPos and vec3(dealer.blipPos.x, dealer.blipPos.y, dealer.blipPos.z) or pos
            local blip = AddBlipForCoord(blipPos)
            SetBlipSprite(blip, dealer.blip.sprite or KOJA.Defaults.blip.sprite)
            SetBlipScale(blip, KOJA.Defaults.blip.scale)
            SetBlipColour(blip, dealer.blip.colour or KOJA.Defaults.blip.colour)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(dealer.name)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end

        if dealer.interaction == 'npc' then
            CreateThread(function()
                local hash = KOJA.Defaults.ped.pedHash
                RequestModel(hash)
                while not HasModelLoaded(hash) do
                    Wait(100)
                end
                local ped = CreatePed(4, hash, dealer.pos.x, dealer.pos.y, dealer.pos.z - 0.99, (dealer.pos.heading or 0.0) + 0.0, false, true)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                peds[#peds + 1] = ped

                if KOJA.Target then
                    exports.ox_target:addLocalEntity(ped, {
                        {
                            onSelect = function()
                                currentVehicle.backCoords = GetEntityCoords(PlayerPedId())
                                Wait(250)
                                OpenDealerMenu(dealer)
                            end,
                            icon = "fa-solid fa-car",
                            label = KOJA.Defaults.ped.drawTextTarget
                        }
                    })
                end
            end)
        end

        if not (dealer.interaction == 'npc' and KOJA.Target) then
            local interactPoint = KojaLib.Client.points.new(
                pos,
                3.0,
                {
                    nearby = function()
                        if dealer.interaction == 'marker' then
                            DrawMarker(dealer.markerType or 2, dealer.pos.x, dealer.pos.y, dealer.pos.z + 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 63, 214, 143, 200, true, true, 2, false, nil, nil, false)
                        end
                        DrawText3D(dealer.pos.x, dealer.pos.y, dealer.pos.z + (dealer.interaction == 'npc' and 1.0 or 0.9), KOJA.Defaults.ped.drawText)
                        if IsControlJustPressed(0, 51) then
                            currentVehicle.backCoords = GetEntityCoords(PlayerPedId())
                            Citizen.Wait(250)
                            OpenDealerMenu(dealer)
                        end
                    end
                }
            )
            points[#points + 1] = interactPoint
        end
    end
end

BuildDealerPayload = function(dealer, refresh)
    local categories = {}
    local categoryData = {}
    for _, category in ipairs(dealer.categories or {}) do
        categories[#categories + 1] = { label = category.name, value = category.name }
        local carList = {}
        for _, car in ipairs(category.cars or {}) do
            carList[#carList + 1] = {
                name = car.name,
                model = car.model,
                price = car.price,
                limited = car.limited or false,
                stock = car.stock or 0,
                prestige = car.prestige or 0
            }
        end
        categoryData[category.name] = carList
    end
    local promotions = {}
    for _, promo in ipairs(PromotionsData) do
        if promo.dealer == dealer.id then
            promotions[#promotions + 1] = promo
        end
    end
    return {
        dealer = dealer.id,
        refresh = refresh or false,
        categories = categories,
        categoryData = categoryData,
        promotions = promotions,
        zoneData = { title = dealer.name, desc = '' },
        imagesPath = KOJA.ImagesPath,
        testDrive = {
            tuningPrice = KOJA.TestDrive.tuningPrice,
            secondslimit = KOJA.TestDrive.secondslimit
        },
        limitedStock = KOJA.LimitedStock,
        prestige = KOJA.Prestige,
        coupons = { enable = KOJA.Coupons.enable },
        vip = {
            enable = KOJA.Vip.enable,
            purchasable = KOJA.Vip.purchasable,
            price = KOJA.Vip.price,
            days = KOJA.Vip.days,
            discount = KOJA.Vip.discount,
            benefits = KOJA.Vip.benefits or {},
            dealerVipOnly = dealer.vipOnly or false
        },
        leasing = {
            enable = KOJA.Leasing.enable,
            downPaymentPercent = KOJA.Leasing.downPaymentPercent,
            installments = KOJA.Leasing.installments,
            interestPercent = KOJA.Leasing.interestPercent,
            paymentIntervalHours = KOJA.Leasing.paymentIntervalHours
        }
    }
end

OpenDealerMenu = function(dealer)
    local playerJob = Misc.Utils.GetPlayerJob()
    if not hasPermission(playerJob, dealer.permissions) then
        local notify = {
            title = 'game.notification.notify',
            desc = 'game.noPerms',
            time = 'game.notification.duration',
        }
        SendNotify(notify)
        return
    end

    if dealer.vipOnly and KOJA.Vip.enable then
        local profile = nil
        local done = false
        KojaLib.Client.TriggerServerCallback('koja:getPlayerProfile', {}, function(result)
            profile = result
            done = true
        end)
        while not done do Wait(10) end
        if not profile or not profile.vip then
            local notify = {
                title = 'game.notification.notify',
                desc = 'game.vip.dealer_locked',
                time = 'game.notification.duration',
            }
            SendNotify(notify)
            return
        end
    end

    NetworkStartSoloTutorialSession()

    menuOpen = true
    currentDealer = dealer
    if dealer.vehicleSpawn then
        currentVehicle.spawnCoords = vec3(dealer.vehicleSpawn.x, dealer.vehicleSpawn.y, dealer.vehicleSpawn.z)
        currentVehicle.heading = dealer.vehicleSpawn.heading or 0.0
    else
        currentVehicle.spawnCoords = KOJA.Defaults.vehicleSpawn.coords
        currentVehicle.heading = KOJA.Defaults.vehicleSpawn.heading
    end
    currentVehicle.dealer = dealer.id
    currentVehicle.vehicleBuySpawn = GetBuySpawn(dealer)
    currentVehicle.testDrive = GetTestDriveSpawn(dealer)

    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(10) end

    SetEntityVisible(PlayerPedId(), false)
    SetFollowVehicleCamViewMode(2)
    DisplayRadar(false)
    SetEntityInvincible(PlayerPedId(), true)
    FreezeEntityPosition(PlayerPedId())
    SetEntityCoords(PlayerPedId(), currentVehicle.spawnCoords.x, currentVehicle.spawnCoords.y, currentVehicle.spawnCoords.z + 2)

    Koja.Client.SendReactMessage('koja_cardealer:setVisible', true)
    Misc.Utils.CarDealerState(true)
    SetNuiFocus(true, true)

    Koja.Client.SendReactMessage('koja_cardealer:sendAllData', BuildDealerPayload(dealer))

    KojaLib.Client.TriggerServerCallback('koja:getPlayerProfile', {}, function(profile)
        Koja.Client.SendReactMessage('koja_cardealer:setProfile', profile)
    end)
end

RegisterNUICallback('getVehicleData', function(data, cb)
    ClearAreaOfVehicles(currentVehicle.spawnCoords, 5.0, false, false, false, false, false)
    stopDragCam()

    if currentVehicle.entity then
        SetModelAsNoLongerNeeded(GetEntityModel(currentVehicle.entity))
        SetVehicleAsNoLongerNeeded(currentVehicle.entity)
        DeleteEntity(currentVehicle.entity)
    end

    local hash = joaat(data.model)

    WaitForVehicleToLoad(data.model)

    local entity = CreateVehicle(hash, vec3(currentVehicle.spawnCoords.x, currentVehicle.spawnCoords.y, currentVehicle.spawnCoords.z), currentVehicle.heading, false, false)
    currentVehicle.entity = entity

    SetVehicleOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetVehicleDirtLevel(entity, 0.0)
    SetEntityCollision(entity, false, false)
    SetVehRadioStation(entity, 'OFF')
    SetVehicleRadioEnabled(entity, false)

    if GetVehicleLivery(entity) ~= -1 then
        SetVehicleLivery(entity, 0)
        currentVehicle.livery = 0
    end

    local stats = VehicleStatistic(entity)

    startDragCam(entity, {
        initial = 5.0,
        min = 2.5,
        max = 10.0,
        scrollIncrements = 0.5
    })

    if not IsScreenFadedIn() then
        DoScreenFadeIn(400)
    end

    cb({ stats = stats, class = GetVehicleClass(entity) })
end)

RgbToVector = function(color)
    if color == nil then
        return vec3(0, 0, 0)
    end
    local r, g, b = color[1], color[2], color[3]
    return vec3(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
end

RegisterNUICallback('changeVehicleColor', function(data, cb)
    cb(1)
    if data.colors[1] then
        local color = RgbToVector(data.colors[1])
        currentVehicle.PrimaryColour = color
        SetVehicleCustomPrimaryColour(currentVehicle.entity, math.floor(color.x), math.floor(color.y), math.floor(color.z))
    end
    if data.colors[2] then
        local color = RgbToVector(data.colors[2])
        currentVehicle.SecondaryColour = color
        SetVehicleCustomSecondaryColour(currentVehicle.entity, math.floor(color.x), math.floor(color.y), math.floor(color.z))
    end
end)

ApplyFullTuning = function(entity)
    SetVehicleModKit(entity, 0)
    for modType = 0, 49 do
        local count = GetNumVehicleMods(entity, modType)
        if count > 0 then
            SetVehicleMod(entity, modType, count - 1, false)
        end
    end
    ToggleVehicleMod(entity, 18, true)
end

SpawnTestDriveVehicle = function(model, fullTuning)
    Koja.Client.SendReactMessage('koja_cardealer:setVisible', false)
    Misc.Utils.CarDealerState(false)
    SetNuiFocus(false, false)
    SetEntityVisible(PlayerPedId(), true)
    SetFollowVehicleCamViewMode(1)
    stopDragCam()
    menuOpen = false

    local testZone = currentVehicle.testDrive

    if currentVehicle.entity then
        SetModelAsNoLongerNeeded(GetEntityModel(currentVehicle.entity))
        SetVehicleAsNoLongerNeeded(currentVehicle.entity)
        DeleteEntity(currentVehicle.entity)
    end

    SetEntityCoords(PlayerPedId(), testZone.coords)

    local hash = joaat(model)

    local entity = CreateVehicle(hash, testZone.coords, testZone.heading, false, false)
    currentVehicle.entity = entity

    if fullTuning then
        ApplyFullTuning(entity)
    end

    if currentVehicle.PrimaryColour then
        local color = currentVehicle.PrimaryColour
        SetVehicleCustomPrimaryColour(currentVehicle.entity, math.floor(color.x), math.floor(color.y), math.floor(color.z))
    end

    if currentVehicle.SecondaryColour then
        local color = currentVehicle.SecondaryColour
        SetVehicleCustomSecondaryColour(currentVehicle.entity, math.floor(color.x), math.floor(color.y), math.floor(color.z))
    end

    SetPedIntoVehicle(PlayerPedId(), entity, -1)
    FreezeEntityPosition(PlayerPedId(), false)
    SetVehicleEngineOn(entity, true, true, true)
    startTestDrive()
    SetEntityInvincible(PlayerPedId(), false)
end

RegisterNUICallback("testDriveVehicle", function(data, cb)
    cb(1)
    if data.fullTuning and (KOJA.TestDrive.tuningPrice or 0) > 0 then
        KojaLib.Client.TriggerServerCallback("koja:payTestDriveTuning", { payment = data.payment }, function(result)
            if result.success then
                SpawnTestDriveVehicle(data.model, true)
            else
                local notify = {
                    title = 'game.notification.notify',
                    desc = result.message,
                    time = 5000
                }
                SendNotify(notify)
            end
        end)
    else
        SpawnTestDriveVehicle(data.model, false)
    end
end)

function startTestDrive()
    local secondslimit = KOJA.TestDrive.secondslimit

    local notify = {
        title = 'game.notification.notify',
        desc = 'game.drivetest.startNotify',
        time = 'game.notification.time',
        variables = {
            seconds = secondslimit
        }
    }
    SendNotify(notify)

    local playerPed = PlayerPedId()
    local testDriveActive = true
    local wasCancelled = false

    CreateThread(function()
        local startTime = GetGameTimer()
        local duration = secondslimit * 1000

        while testDriveActive and
              (GetGameTimer() - startTime < duration) and DoesEntityExist(currentVehicle.entity) and not IsEntityDead(playerPed) do

            if IsControlJustPressed(0, KOJA.TestDrive.cancelKey) then
                wasCancelled = true
                break
            end

            if GetVehiclePedIsIn(playerPed, false) == 0 and DoesEntityExist(currentVehicle.entity) then
                SetPedIntoVehicle(playerPed, currentVehicle.entity, -1)
            end

            Wait(0)
        end

        testDriveActive = false

        if currentVehicle.entity then
            SetModelAsNoLongerNeeded(GetEntityModel(currentVehicle.entity))
            SetVehicleAsNoLongerNeeded(currentVehicle.entity)
            DeleteEntity(currentVehicle.entity)
        end

        SetEntityCoords(playerPed, currentVehicle.backCoords)
        DisplayRadar(true)
        NetworkEndTutorialSession()

        local notify = {
            title = 'game.notification.notify',
            desc = wasCancelled and 'game.drivetest.cancelNotify' or 'game.drivetest.endNotify',
            time = 'game.notification.time',
            variables = {
                seconds = secondslimit
            }
        }
        SendNotify(notify)

        currentVehicle = {}
        currentDealer = nil
    end)
end

RegisterNUICallback("buyVehicle", function(data, cb)
    cb(1)
    local payload = {
        dealer = currentVehicle.dealer,
        model = data.model,
        payment = data.payment,
        leasing = data.leasing
    }

    KojaLib.Client.TriggerServerCallback("koja:purchaseVehicle", payload, function(result)
        if result.success then
            local notify = {
                title = 'game.notification.notify',
                desc = 'game.purchase_modal.purchase_confirm',
                time = 5000,
                variables = {
                    plate = result.plate
                }
            }
            SendNotify(notify)
            Koja.Client.SendReactMessage('koja_cardealer:setVisible', false)
            Misc.Utils.CarDealerState(false)
            SetNuiFocus(false, false)
            stopDragCam()
            SetEntityVisible(PlayerPedId(), true)
            SetFollowVehicleCamViewMode(1)
            menuOpen = false

            if currentVehicle.entity then
                SetModelAsNoLongerNeeded(GetEntityModel(currentVehicle.entity))
                SetVehicleAsNoLongerNeeded(currentVehicle.entity)
                DeleteEntity(currentVehicle.entity)
            end

            NetworkEndTutorialSession()
            SetEntityInvincible(PlayerPedId(), false)
            FreezeEntityPosition(PlayerPedId(), false)
            local hash = joaat(data.model)
            local entity = CreateVehicle(hash, currentVehicle.vehicleBuySpawn.coords, currentVehicle.vehicleBuySpawn.heading, true, true)

            SetPedIntoVehicle(PlayerPedId(), entity, -1)
            SetVehicleNumberPlateText(entity, result.plate)

            if currentVehicle.PrimaryColour ~= nil then
                local color = currentVehicle.PrimaryColour
                SetVehicleCustomPrimaryColour(entity, math.floor(color.x), math.floor(color.y), math.floor(color.z))
            end

            if currentVehicle.SecondaryColour ~= nil then
                local color = currentVehicle.SecondaryColour
                SetVehicleCustomSecondaryColour(entity, math.floor(color.x), math.floor(color.y), math.floor(color.z))
            end

            Misc.Utils.VehicleSpawned(entity)
            Misc.Utils.DealerData(currentVehicle)

            DisplayRadar(true)
            currentVehicle = {}
            currentDealer = nil
        else
            local notify = {
                title = 'game.notification.notify',
                desc = result.message,
                time = 5000,
                variables = result.variables
            }
            SendNotify(notify)
        end
    end)
end)

CloseMenu = function()
    if not IsScreenFadedIn() then
        DoScreenFadeIn(400)
    end
    DisplayRadar(true)
    NetworkEndTutorialSession()
    Misc.Utils.CarDealerState(false)
    SetNuiFocus(false, false)
    SetEntityCoords(PlayerPedId(), currentVehicle.backCoords)
    SetEntityInvincible(PlayerPedId(), false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityVisible(PlayerPedId(), true)
    SetFollowVehicleCamViewMode(1)
    stopDragCam()
    menuOpen = false
    if currentVehicle.entity then
        SetModelAsNoLongerNeeded(GetEntityModel(currentVehicle.entity))
        SetVehicleAsNoLongerNeeded(currentVehicle.entity)
        DeleteEntity(currentVehicle.entity)
    end
    currentDealer = nil
end

RegisterNUICallback('exit', function(_, cb)
    cb(1)
    CloseMenu()
end)

RegisterNetEvent('koja_cardealer:themeUpdate', function(theme)
    Koja.Client.SendReactMessage('koja_cardealer:setTheme', theme)
end)

RegisterNetEvent('koja_cardealer:syncDealers', function(payload)
    DealersData = payload.dealers or {}
    PromotionsData = payload.promotions or {}
    SetupDealers()
    if menuOpen and currentDealer then
        local refreshed = nil
        for i = 1, #DealersData do
            if DealersData[i].id == currentDealer.id then
                refreshed = DealersData[i]
                break
            end
        end
        if refreshed then
            currentDealer = refreshed
            Koja.Client.SendReactMessage('koja_cardealer:sendAllData', BuildDealerPayload(refreshed, true))
        end
    end
end)

CreateThread(function()
    Wait(1000)
    KojaLib.Client.TriggerServerCallback('koja:getDealers', {}, function(payload)
        DealersData = payload.dealers or {}
        PromotionsData = payload.promotions or {}
        if payload.theme then
            Koja.Client.SendReactMessage('koja_cardealer:setTheme', payload.theme)
        end
        SetupDealers()
    end)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ClearInteractions()
end)
