
include "nav2ain/util.lua"

local sampler = {}

function sampler.Constant(value)
    return function()
        return value
    end
end

function sampler.UniformNumber(params)
    if params.min and params.max then
        if params.int then
            return function()
                return math.random(params.min, params.max)
            end
        end

        local delta = params.max - params.min
        return function()
            return params.min + delta * math.random()
        end
    end

    error("Invalid UnifornNumber params!")
end

function sampler.UniformInt(params)
    return sampler.UniformNumber {
        int = true,
        min = params.min,
        max = params.max,
    }
end

function sampler.Choice(params)
    local isValidWeightedChoiceParam = table.All(params, function(choice, param)
        return type(param) == "table" and param.chance ~= nil
    end)

    if not isValidWeightedChoiceParam then
        local isValidUniformDistrib = table.All(params, function(idx, param)
            return type(idx) == "number"
        end)

        if not isValidUniformDistrib then
            error("Invalid Choice params!")
        end
    
        return function()
            return params[math.random(1, #params)]
        end
    end

    local totalChance = 0
    for _, param in pairs(params) do
        totalChance = totalChance + param.chance
    end

    return function()
        local rand = math.random(1, totalChance)

        for choice, param in pairs(params) do
            rand = rand - param.chance
            if rand <= 0 then
                return choice  
            end
        end

        -- Shuold never hit
        error("Weighted choice - invalid initial `rand` value")
    end
end

function sampler.Table(tbl)
    local samplers = {}
    for key, value in pairs(tbl) do
        if type(value) == "function" then
            samplers[key] = value
        end
    end

    return function()
        local instance = setmetatable({}, { __index = tbl })
        for key, sampleFunc in pairs(samplers) do
            instance[key] = sampleFunc()
        end

        return instance
    end
end

function sampler.Eval(value)
    if type(value) == "function" then
        return value()
    end

    return value
end

return sampler