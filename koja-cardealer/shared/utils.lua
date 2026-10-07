Misc = {}
Misc.Utils = {
    Charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    NumberCharset = "0123456789",
}

Misc.Utils.customNotify = function(source, type, icon, color, title, desc, time)
    if source and source > 0 then -- server

    else -- client

    end
end

Misc.Utils.GetPlayerJob = function()
    return KojaLib.Client.GetPlayerJob()
end

Misc.Utils.CarDealerState = function(state)
    --TriggerEvent('your_triggername', state)
    --exports('your_resourcename'):function(state)
end

Misc.Utils.VehicleSpawned = function(entity)
    --Add custom functions after vehicle spawned
end

---@class DealerData
---@field spawnCoords vector3       The world coordinates where the vehicle should spawn
---@field heading number            The heading (rotation) for the spawned vehicle
---@field dealer string             The dealer name
---@field vehicleBuySpawn table     The zone/config data for the vehicle-buy area
---@field testDrive table           The zone/config data for the test-drive area
Misc.Utils.DealerData = function(data)
    --Dealer data from client after buy vehicle
end

Misc.Utils.GetPlayerPrestige = function(source)
    if GetPrestigeData then
        local data = GetPrestigeData(source)
        return data.prestige, data.xp
    end
    return 0, 0
end

Misc.Utils.OnVehiclePurchased = function(source, price)
    local xp = KOJA.Prestige.xpPerPurchase or 0
    if not KOJA.Prestige.enable or xp <= 0 then return end
    if AddPrestigeXP then
        AddPrestigeXP(source, xp)
    end
end

--- Added by the garage fix: hands the bought vehicle to the garage bridge.
--- Runs AFTER SaveVehicleToGarage, so the database row already exists.
--- (Server-side implementation lives in shared/s_utils.lua.)
Misc.Utils.SaveVehicle = function(data)
end

Misc.Utils.GetRandomString = function(length, charset)
    local output = ""
    for i = 1, length do
        local rand = math.random(1, #charset)
        output = output .. charset:sub(rand, rand)
    end
    return output
end

Misc.Utils.GeneratePlate = function()
    local generatedPlate

    while true do
        Citizen.Wait(0)
        generatedPlate = string.upper(Misc.Utils.GetRandomString(KOJA.PlateFormat.Letters, Misc.Utils.Charset)..KOJA.PlateFormat.Separator..Misc.Utils.GetRandomString(KOJA.PlateFormat.Numbers, Misc.Utils.NumberCharset))

        local exists = MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ?', { generatedPlate })

        if not exists then
            break
        end
    end

    return generatedPlate
end

if IsDuplicityVersion() then
    exports('GeneratePlate', Misc.Utils.GeneratePlate)
end
