local translations = {}

Koja.Client.SendReactMessage = function(action, data)
    SendNUIMessage({
        action = action, data = data
    })
end

function Koja.Client.RoundNumber(number)
    return math.round(number, 0.5)
end

RegisterNUICallback('loadLocale', function(_, cb)
    cb(1)
    local resource = GetCurrentResourceName()
    local locale = KOJA.Locale
    local jsonFile = LoadResourceFile(resource, ('locales/%s.json'):format(locale)) or LoadResourceFile(resource, 'locales/en.json')
    translations = json.decode(jsonFile)
    Koja.Client.SendReactMessage('setLocale', json.decode(jsonFile))
end)

function substituteVariables(text, variables)
    if variables then
        for varName, varValue in pairs(variables) do
            text = string.gsub(text, "%%" .. varName, tostring(varValue))
        end
    end
    return text
end

function getTranslation(key, default)
    local keys = {}
    for k in string.gmatch(key, "[^%.]+") do
        table.insert(keys, k)
    end

    local result = translations
    for _, k in ipairs(keys) do
        if result[k] then
            result = result[k]
        else
            print("Missing key: " .. key)
            return default
        end
    end

    if type(result) == "string" then
        result = string.gsub(result, "%%([%a%d_]+)", function(varName)
            return "%" .. varName
        end)
    end
    return result or default
end

SendNotify = function(data)
    local title = getTranslation(data.title, "Missing translate(TITLE): "..data.title)
    local desc = getTranslation(data.desc, "Missing translate(DESC): "..data.desc)
    desc = substituteVariables(desc, data.variables)
    local notify = {
        title = title,
        desc = desc
    }
    KojaLib.Client.SendNotify(notify)
end
