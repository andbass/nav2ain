
AddCSLuaFile()

local function ReverseEnumLookup(tbl, value)
    for i, v in pairs(tbl) do
        if v == value then return i end
    end

    return nil
end

function enum(tbl)
    setmetatable(tbl, {
        __index = ReverseEnumLookup
    })

    return tbl
end

function MsgF(fmt, ...)
    MsgN(string.format(fmt, ...))
end

local colorErr = Color(200, 25, 0)

function MsgE(fmt, ...)
    MsgC(colorErr, string.format(fmt, ...) .. "\n")
end
