
local nodegraph = include "nav2ain/nodegraph.lua"
local cvars = include "nav2ain/cvars.lua"

local drawRate = 0.25
local devMode = GetConVar("developer")

local convertedGraph = nil
local drawnGraph = nil

local additionalSeedPositions = {}

local function Convert(ply, cmd, args, str)
    if not game.SinglePlayer() then
        MsgE("Please run in single player mode")
        return
    end

    local graph = nodegraph.Graph()
    graph:ConvertNavmesh { 
        simplify = true,
        simplificationMaxDist = 150,
        spawnEntName = args[1],
        additionalSeedPositions = additionalSeedPositions
    }

    MsgF("Final # of Nodes: %s, Links: %s", #graph.nodes, #graph:Links())
    graph:Draw(ply, drawRate)
    
    convertedGraph = graph
end

local function Save(ply, cmd, args, str)
    if not game.SinglePlayer() then
        MsgE("Please run in single player mode")
        return
    end

    if convertedGraph == nil then
        MsgE("No graph has been generated yet, please use the 'nav2ain_convert' command first")
        return
    end

    convertedGraph:Save()

    MsgF("Done writing, the graph has been saved to: '$YOUR_GMOD_FOLDER/data/%s'", convertedGraph.pathForSaving)
    MsgF("Rename the file to '%s' and move the file into the '$YOUR_GMOD_FOLDER/maps/graphs' directory. Upon reloading the map, the new nodegraph should be used", game.GetMap() .. ".ain")
    MsgN("I recommend backing up any old nodegraphs first")
    MsgN("You will need to exit the current map in order to overwrite the nodegraph file")
end

local function Load(ply, cmd, args, str)
    if not game.SinglePlayer() then
        MsgE("Please run in single player mode")
        return
    end

    local graph = nodegraph.Graph(args[1])
    MsgF("Graph path: %s", graph.path)

    graph:Load()
    MsgN("Loading complete")

    MsgF("# Nodes = %s, # Links = %s", #graph.nodes, #graph:Links())
    MsgF("AIN Version = %s, Map Version = %s", graph.version, graph.mapVersion)

    MsgN("Drawing nodes and links")
    graph:Draw(ply, drawRate)
end

local function ClearDraw(ply, cmd, args, str)
    timer.Remove("nav2ain_DrawWalkable")
    nodegraph.Graph.DrawClear()
end

local function MarkWalkable(ply, cmd, args, str)
    local tr = ply:GetEyeTrace()
    if tr.Hit then
        local pos = tr.HitPos + Vector(0, 0, 10)
        table.insert(additionalSeedPositions, pos)

        timer.Create("nav2ain_DrawWalkable", drawRate, 0, function()
            for i, pos in ipairs(additionalSeedPositions) do
                debugoverlay.Sphere(pos, 15, drawRate + 0.1, Color(255, 0, 255))
            end
        end)
    end
end

concommand.Add("nav2ain_convert", Convert, nil, "Converts a generated navigation mesh (through the console command 'nav_generate') to an AI Node Graph")
concommand.Add("nav2ain_save", Save, nil, "Saves a generated node graph (through the console command 'nav2ain_convert') to an .ain file on the disk")
concommand.Add("nav2ain_load", Load, nil, "Loads and renders the saved nodegraph for the given path or the current map, if no arguments are given (developer mode must be enabled for drawing to activate")
concommand.Add("nav2ain_clear_draw", ClearDraw, nil, "Stops rendering any nodegraph currently being drawn")
concommand.Add("nav2ain_mark_walkable", MarkWalkable, nil, "Adds an additional position to be used when finding initial NavAreas")