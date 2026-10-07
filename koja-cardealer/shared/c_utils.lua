--- Draws 3D text at a specified position in the game world.
---@param x number # X coordinate
---@param y number # Y coordinate
---@param z number # Z coordinate
---@param text string # The text to display
DrawText3D = function(x, y, z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 245)
    SetTextOutline(true)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
end

--- Loads a vehicle model asynchronously if it's not already loaded.
---@param modelHash number|string # Hash or name of the vehicle model
WaitForVehicleToLoad = function(modelHash)
    modelHash = (type(modelHash) == 'number' and modelHash or GetHashKey(modelHash))

    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)

        BeginTextCommandBusyspinnerOn('STRING')
        AddTextComponentSubstringPlayerName('Loading model...')
        EndTextCommandBusyspinnerOn(4)

        SetNuiFocus(false, false)
        while not HasModelLoaded(modelHash) do
            Citizen.Wait(0)
            DisableAllControlActions(0)
        end

        BusyspinnerOff()

        SetNuiFocus(true, true)
    end
end

--- Checks if the player has the required permissions based on their job group.
---@param playerJob string # The player's job name (e.g., "police", "ambulance")
---@param permissions table # Table containing permission configuration
--- - permissions.enable boolean # Whether permissions are enabled
--- - permissions.groups table # List of job groups allowed access
---@return boolean # Returns true if the player has permissions; false otherwise
hasPermission = function(playerJob, permissions)
    if not permissions or not permissions.enable then
        return true
    end

    for _, group in ipairs(permissions.groups) do
        if playerJob == group then
            return true
        end
    end

    return false
end

-- ============================================================================
--  GARAGE BRIDGE (server side)
--  Some garage resources register the vehicle themselves once it is spawned
--  after the purchase. Send the plate + model out so a custom bridge can
--  insert / finish the record. Harmless when nothing listens.
-- ============================================================================
if IsDuplicityVersion() then
    Misc.Utils.SaveVehicle = function(data)
        if not data or not data.vehicle then return end

        TriggerEvent('koja_cardealer:vehiclePurchased', data)

        local model = data.vehicle.name
        local plate = data.vehicle.plate
        if not model or not plate then return end

        local playerId = data.source
        if not playerId and type(data.player) == 'table' then playerId = data.player.source end
        if not playerId then return end

        -- Optional bridge for garages exposing their own "add vehicle" export.
        if GetResourceState('lunar_garage') == 'started' then
            pcall(function()
                exports.lunar_garage:AddVehicle(playerId, model, plate)
            end)
        end
    end
end
