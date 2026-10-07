-- ============================================================================
--  KOJA_CARDEALER -> GARAGE BRIDGE (ESX / QBCore)
--  Replaces the old SaveVehicleToGarage row insert.
--
--  The old insert only wrote (owner/identifier, plate, vehicle, state) which is
--  the ESX default owned_vehicles layout. Lunar Garage (and most modern garages)
--  read the row with the same column names the framework itself uses:
--
--      ESX     : owner, plate, vehicle, type, job, stored
--      QBCore  : citizenid, plate, mods, garage, state, vehicle, type, ...
--
--  Missing 'stored' (or stored = 0) makes the vehicle show up as IMPOUNDED
--  instead of stored in the garage; that is why the car appeared "registered to
--  you" but was never listed in the garage menu.
--
--  The 'vehicle' column must hold a FULL vehicle properties table, not a stub.
--  Lunar Garage decodes the column straight into lib.setVehicleProperties when
--  the car is taken out and re-encodes it on save (setVehicleProps). A stub
--  containing only { model, plate } leaves the car with no mod fields: it spawns
--  stock, and the owner's first save then persists those empty props over the
--  row - which is why mods stayed consistent for the account that had real props
--  and drifted for every other player. Saving a full properties table means the
--  first load already has every field the garage reads back.
--
--  The 'type' column must match what the garage queries with. This file writes
--  'car' (the convention used by esx_garage, most third party garages, and the
--  Type values in Lunar Garage's own config/config.lua), so it matches Lunar
--  Garage's garage and interior queries as-is. Do not normalise 'car' to
--  'automobile' on either side: the row and the config already agree.
-- ============================================================================

if IsDuplicityVersion() then
    -- Identifier lookup: prefer the framework helper, fall back to the raw ESX
    -- identifier so an older core build still works.
    local function resolveIdentifier(source, xPlayer)
        local identifier
        if KojaLib and KojaLib.Server and KojaLib.Server.GetPlayerIdentifier then
            identifier = KojaLib.Server.GetPlayerIdentifier(source)
        end
        if not identifier and xPlayer then
            if type(xPlayer) == 'table' then
                identifier = xPlayer.identifier
            elseif type(xPlayer) == 'string' then
                identifier = xPlayer
            end
        end
        return identifier
    end

    -- ESX owner column type detection (VARCHAR(60) licence vs INT identifier).
    -- Detected once, cached for the session.
    local ownerIsInt = nil
    local ownerCheckStarted = false

    local function detectOwnerColumn()
        if ownerIsInt ~= nil or ownerCheckStarted then return end
        ownerCheckStarted = true
        MySQL.query('SELECT owner FROM owned_vehicles LIMIT 1', {}, function(rows)
            local sample = rows and rows[1] and rows[1].owner
            ownerIsInt = (sample ~= nil and tostring(sample):match('^%d+$') ~= nil)
        end)
    end

    ---@param data table { player, source, identifier, vehicle = { name, plate, price, payment } }
    SaveVehicleToGarage = function(data)
        if not data then return end
        local vehicle = data.vehicle or {}
        local model = vehicle.name
        local plate = vehicle.plate
        if not model or not plate then
            print('[KOJA_CARDEALER] SaveVehicleToGarage called without model/plate, aborting')
            return
        end

        local xPlayer = data.player
        local source = data.source or (type(xPlayer) == 'table' and xPlayer.source) or nil
        local identifier = data.identifier
        if not identifier and source then
            identifier = resolveIdentifier(source, xPlayer)
        end

        local props = json.encode({
            model = joaat(model),
            plate = plate,
            modEngine = -1,
            modBrakes = -1,
            modTransmission = -1,
            modSuspension = -1,
            modArmor = -1,
            modTurbo = false,
            modSmokeEnabled = false,
            modXenon = false,
            windowTint = -1,
            plateIndex = -1,
            colour1 = 0,
            colour2 = 0,
            pearlescentColor = 0,
            wheelColour = 0,
            dashboardColour = 0,
            interiorColour = 0,
            tyreSmokeColor = { 0, 0, 0 },
            neonEnabled = { false, false, false, false },
            neonColor = { 0, 0, 0 },
            extras = {},
            wheels = 0,
            wheelType = 0,
            livery = -1,
            dirtLevel = 0.0,
            fuelLevel = 100.0,
            bodyHealth = 1000.0,
            engineHealth = 1000.0,
            tankHealth = 1000.0,
        })
        -- 1 = stored in a garage, 0 = out / impounded
        local stored = 1
        -- Vehicle class column. 'car' matches esx_garage and most third party
        -- garages; the Lunar Garage ESX adapter accepts 'car' as well.
        local vehicleType = 'car'

        local function logPurchase()
            local logData = {
                message = string.format("**Player:** %s\n**Purchased Vehicle**\n**Vehicle Model:** %s\n**License Plate:** %s\n**Price:** %s",
                    source and GetPlayerName(source) or tostring(identifier), model, plate, vehicle.price),
                title = 'Vehicle Purchase',
                footertext = 'KOJA_CARDEALER'
            }
            KojaLib.Server.LogMessage(logData, 'cardealer')
        end

        if KojaLib.Framework == 'qb' then
            local citizenid = identifier
            if source and QBCore then
                local qbPlayer = QBCore.Functions.GetPlayer(source)
                citizenid = (qbPlayer and qbPlayer.PlayerData and qbPlayer.PlayerData.citizenid) or identifier
            end
            MySQL.insert(
                'INSERT INTO player_vehicles (citizenid, plate, vehicle, mods, garage, state, type, jobVehicle) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                { citizenid, plate, props, props, 'OUT', stored, vehicleType, 0 },
                function() logPurchase() end
            )
        else
            detectOwnerColumn()
            local owner = identifier
            if ownerIsInt then owner = tonumber(identifier) or identifier end

            -- Modern ESX layout - what Lunar Garage and esx_garage expect.
            MySQL.insert(
                'INSERT INTO owned_vehicles (owner, plate, vehicle, type, job, stored) VALUES (?, ?, ?, ?, ?, ?)',
                { owner, plate, props, vehicleType, nil, stored },
                function(rowsChanged)
                    -- Fallback for old / stripped owned_vehicles tables.
                    if rowsChanged and rowsChanged > 0 then
                        logPurchase()
                        return
                    end
                    MySQL.insert(
                        'INSERT INTO owned_vehicles (owner, plate, vehicle, state) VALUES (?, ?, ?, ?)',
                        { owner, plate, props, stored },
                        function(rowsChanged2)
                            if rowsChanged2 and rowsChanged2 > 0 then
                                logPurchase()
                                return
                            end
                            MySQL.insert(
                                'INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (?, ?, ?)',
                                { owner, plate, props },
                                function() logPurchase() end
                            )
                        end
                    )
                end
            )
        end
    end

    exports('SaveVehicleToGarage', SaveVehicleToGarage)
end
