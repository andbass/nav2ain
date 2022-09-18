
local sampler = include "randbattle/sampler.lua"

local dataManager = {
    dataDir = "randbattle/",
    luaConfigDir = "randbattle/configs/",
}

function dataManager.Init()
    if dataManager.ready then return end

    file.CreateDir(dataManager.dataDir)

    dataManager.LoadConfigs()
    dataManager.UseScenario("default")

    dataManager.ready = true
end

function dataManager.LoadConfigs()
    local configFileNames = file.Find(dataManager.luaConfigDir .. "*.lua", "LUA")

    dataManager.activeConfig = nil
    dataManager.activeModifiers = {}
    dataManager.loadedConfigs = {}

    for _, configFileName in ipairs(configFileNames) do
        local config = include(dataManager.luaConfigDir .. configFileName)

        table.insert(dataManager.loadedConfigs, {
            name = config.name,
            author = config.author,
            description = config.description,
            scenarios = table.GetKeys(config.scenarios or {}),
        })

        -- Remove metadata before setting the active config and doing any merging,
        -- we keep track of this stuff in `loadedConfigs`
        config.name = nil
        config.author = nil
        config.description = nil

        if dataManager.activeConfig == nil then
            dataManager.activeConfig = config 
        else
            -- Merge all of the inner tables together
            for key, data in pairs(config) do
                dataManager.activeConfig[key] = dataManager.activeConfig[key] or {}
                table.Merge(dataManager.activeConfig[key], data) 
            end
        end
    end

    MsgF("Loaded configs:")
    for i, configInfo in ipairs(dataManager.loadedConfigs) do
        MsgF("\tName = '%s', Author = '%s', Description = '%s'", configInfo.name, configInfo.author, configInfo.description)
    end
end

function dataManager.UseScenario(scenarioName)
    local scenario = dataManager.activeConfig.scenarios[scenarioName]
    if scenario == nil then
        MsgE("Could not find a scenario with scenario name %s", scenarioName)
        return false
    end

    scenario.name = scenarioName
    dataManager.activeScenario = scenario
    return true
end

function dataManager.UseModifiers(modifierNames)
    dataManager.activeModifiers = {}
    for i, modifierName in ipairs(modifierNames) do
        local modifier = dataManager.activeConfig.modifiers[modifierName]        
        if not modifier then
            MsgE("'%s' does not reference an available modifier", modifierName)
            dataManager.activeModifiers = {} 
            return false
        end

        dataManager.activeModifiers[modifierName] = modifier
    end

    return true
end

function dataManager.CallModifier(modifierType, ...)
    for modifierName, modifier in pairs(dataManager.activeModifiers) do
        if modifier[modifierType] then
            local result = modifier[modifierType](...)
            if result ~= nil then
                return result
            end
        end
    end

    return nil
end

function dataManager.Sides()
    local scenario = dataManager.activeScenario
    return table.GetKeys(scenario.sides)
end

return dataManager