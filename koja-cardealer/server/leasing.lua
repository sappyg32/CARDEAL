local leases = {}

LoadLeases = function()
    local function load()
        MySQL.query('SELECT * FROM koja_cardealer_leases', {}, function(rows)
            leases = rows or {}
        end)
    end
    if KOJA.CreateAutoTable then
        MySQL.query([[CREATE TABLE IF NOT EXISTS koja_cardealer_leases (
            plate VARCHAR(16) PRIMARY KEY,
            identifier VARCHAR(64) NOT NULL,
            model VARCHAR(64) NOT NULL,
            name VARCHAR(64) NOT NULL,
            total INT NOT NULL,
            remaining INT NOT NULL,
            installment INT NOT NULL,
            paidCount INT NOT NULL DEFAULT 0,
            installments INT NOT NULL,
            nextDueAt INT NOT NULL,
            intervalHours INT NOT NULL,
            missed INT NOT NULL DEFAULT 0
        )]], {}, load)
    else
        load()
    end
end

SaveLease = function(lease)
    MySQL.query([[INSERT INTO koja_cardealer_leases (plate, identifier, model, name, total, remaining, installment, paidCount, installments, nextDueAt, intervalHours, missed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE remaining = VALUES(remaining), paidCount = VALUES(paidCount), nextDueAt = VALUES(nextDueAt), missed = VALUES(missed)]],
        { lease.plate, lease.identifier, lease.model, lease.name, lease.total, lease.remaining, lease.installment, lease.paidCount, lease.installments, lease.nextDueAt, lease.intervalHours, lease.missed })
end

DeleteLease = function(plate)
    MySQL.query('DELETE FROM koja_cardealer_leases WHERE plate = ?', { plate })
end

CreateLease = function(identifier, vehicle, price)
    local cfg = KOJA.Leasing
    local downPayment = math.floor(price * cfg.downPaymentPercent / 100)
    local financed = price - downPayment
    local total = math.floor(financed * (100 + cfg.interestPercent) / 100)
    local installment = math.ceil(total / cfg.installments)
    local lease = {
        identifier = identifier,
        plate = vehicle.plate,
        model = vehicle.model,
        name = vehicle.name,
        total = total,
        remaining = total,
        installment = installment,
        paidCount = 0,
        installments = cfg.installments,
        nextDueAt = os.time() + cfg.paymentIntervalHours * 3600,
        intervalHours = cfg.paymentIntervalHours,
        missed = 0
    }
    leases[#leases + 1] = lease
    SaveLease(lease)
    return lease
end

GetLeaseDownPayment = function(price)
    return math.floor(price * KOJA.Leasing.downPaymentPercent / 100)
end

-- Framework owner column used by the garage tables.
local function ownerColumn()
    return (KojaLib.Framework == 'qb') and 'citizenid' or 'owner'
end

RemoveVehicleFromGarage = function(plate)
    if KojaLib.Framework == 'qb' then
        MySQL.query('DELETE FROM player_vehicles WHERE plate = ?', { plate })
    else
        MySQL.query('DELETE FROM owned_vehicles WHERE plate = ?', { plate })
    end
end

GetPlayerLeases = function(identifier)
    local out = {}
    for _, lease in ipairs(leases) do
        if lease.identifier == identifier then
            out[#out + 1] = lease
        end
    end
    return out
end

FindLease = function(identifier, plate)
    for i, lease in ipairs(leases) do
        if lease.identifier == identifier and lease.plate == plate then
            return lease, i
        end
    end
    return nil, nil
end

KojaLib.Server.RegisterServerCallback('koja:getLeases', function(source, data, cb)
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    cb({ leases = GetPlayerLeases(identifier), config = KOJA.Leasing })
end)

KojaLib.Server.RegisterServerCallback('koja:payLease', function(source, data, cb)
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    local lease, index = FindLease(identifier, data and data.plate)
    if not lease then
        cb({ success = false, message = 'game.leasing.not_found' })
        return
    end
    local amount = data.full and lease.remaining or math.min(lease.installment, lease.remaining)
    local charged, err = ChargePlayer(source, amount, data.payment)
    if not charged then
        cb({ success = false, message = err })
        return
    end
    lease.remaining = lease.remaining - amount
    lease.paidCount = lease.paidCount + 1
    lease.missed = 0
    lease.nextDueAt = os.time() + lease.intervalHours * 3600
    local paidOff = lease.remaining <= 0
    if paidOff then
        -- Ownership transfers to the player once the finance is paid off.
        MySQL.update('UPDATE owned_vehicles SET '..ownerColumn()..' = ? WHERE plate = ?', { identifier, lease.plate })
        table.remove(leases, index)
        DeleteLease(lease.plate)
        local logData = {
            message = string.format("**Player:** %s\n**Paid off lease** for %s (%s)", GetPlayerName(source), lease.name, lease.plate),
            title = 'Lease Paid Off',
            footertext = 'KOJA_CARDEALER'
        }
        KojaLib.Server.LogMessage(logData, 'cardealer')
    else
        SaveLease(lease)
    end
    cb({ success = true, paidOff = paidOff, leases = GetPlayerLeases(identifier) })
end)

CreateThread(function()
    while true do
        Wait(60 * 1000)
        if KOJA.Leasing.enable then
            local now = os.time()
            for i = #leases, 1, -1 do
                local lease = leases[i]
                if now > lease.nextDueAt + KOJA.Leasing.graceHours * 3600 then
                    lease.missed = (lease.missed or 0) + 1
                    lease.nextDueAt = now + lease.intervalHours * 3600
                    if lease.missed > KOJA.Leasing.maxMissedPayments then
                        RemoveVehicleFromGarage(lease.plate)
                        table.remove(leases, i)
                        DeleteLease(lease.plate)
                        local logData = {
                            message = string.format("**Repossessed vehicle** %s (%s) - lease defaulted by %s", lease.name, lease.plate, lease.identifier),
                            title = 'Vehicle Repossessed',
                            footertext = 'KOJA_CARDEALER'
                        }
                        KojaLib.Server.LogMessage(logData, 'cardealer')
                    else
                        SaveLease(lease)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LoadLeases()
end)
