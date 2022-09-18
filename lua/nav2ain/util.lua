
AddCSLuaFile()

local function ReverseEnumLookup(tbl, value)
    for i, v in pairs(tbl) do
        if v == value then return i end
    end

    return nil
end

function enum(tbl)
    return setmetatable(tbl, {
        __index = ReverseEnumLookup
    })
end

function class()
    local classTbl = {
        Init = function() end
    }

    local function constructor(classTbl, ...)
        local self = setmetatable({}, {
            __index = classTbl
        })

        self:Init(...)
        return self
    end

    return setmetatable(classTbl, {
        __call = constructor
    })
end

function MsgF(fmt, ...)
    MsgN(string.format(fmt, ...))
end

local colorErr = Color(200, 25, 0)
function MsgE(fmt, ...)
    MsgC(colorErr, string.format(fmt, ...) .. "\n")
end

function table.All(xs, pred)
    for k, v in pairs(xs) do
        if not pred(k, v) then return false end
    end

    return true
end

function table.Any(xs, pred)
    for k, v in pairs(xs) do
        if pred(k, v) then return true end
    end

    return false
end