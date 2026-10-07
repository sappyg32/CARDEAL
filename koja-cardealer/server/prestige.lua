local cache = {}

LoadPrestige = function()
    local function load()
        MySQL.query('SELECT identifier, prestige, xp FROM koja_cardealer_prestige', {}, function(rows)
            for i = 1, #(rows or {}) do
                cache[rows[i].identifier] = { prestige = rows[i].prestige, xp = rows[i].xp }
            end
        end)
    end
    if KOJA.CreateAutoTable then
        MySQL.query('CREATE TABLE IF NOT EXISTS koja_cardealer_prestige (identifier VARCHAR(64) PRIMARY KEY, prestige INT NOT NULL DEFAULT 0, xp INT NOT NULL DEFAULT 0)', {}, load)
    else
        load()
    end
end

local function normalize(data)
    local per = KOJA.Prestige.xpPerLevel or 0
    if per > 0 then
        while data.xp >= per do
            data.xp = data.xp - per
            data.prestige = data.prestige + 1
        end
    end
    if data.xp < 0 then data.xp = 0 end
    if data.prestige < 0 then data.prestige = 0 end
end

local function persist(identifier, data)
    MySQL.query('INSERT INTO koja_cardealer_prestige (identifier, prestige, xp) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE prestige = VALUES(prestige), xp = VALUES(xp)',
        { identifier, data.prestige, data.xp })
end

local function dataFor(source)
    local identifier = KojaLib.Server.GetPlayerIdentifier(source)
    if not identifier then return nil, nil end
    if not cache[identifier] then
        cache[identifier] = { prestige = 0, xp = 0 }
    end
    return cache[identifier], identifier
end

--- @param source number
--- @return table # { prestige, xp }
GetPrestigeData = function(source)
    local data = dataFor(source)
    return data or { prestige = 0, xp = 0 }
end

AddPrestigeXP = function(source, amount)
    local data, identifier = dataFor(source)
    if not data then return false end
    data.xp = data.xp + math.floor(tonumber(amount) or 0)
    normalize(data)
    persist(identifier, data)
    return true, data.prestige, data.xp
end

SetPrestigeXP = function(source, amount)
    local data, identifier = dataFor(source)
    if not data then return false end
    data.xp = math.max(0, math.floor(tonumber(amount) or 0))
    normalize(data)
    persist(identifier, data)
    return true, data.prestige, data.xp
end

AddPrestigeLevel = function(source, amount)
    local data, identifier = dataFor(source)
    if not data then return false end
    data.prestige = math.max(0, data.prestige + math.floor(tonumber(amount) or 0))
    persist(identifier, data)
    return true, data.prestige, data.xp
end

SetPrestigeLevel = function(source, amount)
    local data, identifier = dataFor(source)
    if not data then return false end
    data.prestige = math.max(0, math.floor(tonumber(amount) or 0))
    persist(identifier, data)
    return true, data.prestige, data.xp
end

exports('GetPrestige', function(source)
    local data = GetPrestigeData(source)
    return data.prestige, data.xp
end)
exports('AddPrestigeXP', AddPrestigeXP)
exports('SetPrestigeXP', SetPrestigeXP)
exports('AddPrestige', AddPrestigeLevel)
exports('SetPrestige', SetPrestigeLevel)

local function runCommand(source, args, fn, label)
    if source ~= 0 and not IsDealerAdmin(source) then
        return
    end
    local target = tonumber(args[1])
    local amount = tonumber(args[2])
    if not target or not amount then
        print(('[KOJA_CARDEALER] Usage: %s <playerId> <amount>'):format(label))
        return
    end
    if not GetPlayerName(target) then
        print(('[KOJA_CARDEALER] Player %s is not online'):format(target))
        return
    end
    local ok, prestige, xp = fn(target, amount)
    if ok then
        print(('[KOJA_CARDEALER] %s -> player %s (%s) is now Prestige %s / %s XP'):format(label, target, GetPlayerName(target), prestige, xp))
    end
end

RegisterCommand(KOJA.Prestige.commands.addXp, function(source, args)
    runCommand(source, args, AddPrestigeXP, KOJA.Prestige.commands.addXp)
end, false)

RegisterCommand(KOJA.Prestige.commands.setXp, function(source, args)
    runCommand(source, args, SetPrestigeXP, KOJA.Prestige.commands.setXp)
end, false)

RegisterCommand(KOJA.Prestige.commands.addPrestige, function(source, args)
    runCommand(source, args, AddPrestigeLevel, KOJA.Prestige.commands.addPrestige)
end, false)

RegisterCommand(KOJA.Prestige.commands.setPrestige, function(source, args)
    runCommand(source, args, SetPrestigeLevel, KOJA.Prestige.commands.setPrestige)
end, false)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    LoadPrestige()
end)
