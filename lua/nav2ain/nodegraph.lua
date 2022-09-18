
include "nav2ain/util.lua"

--[[ 
-- A class that represents a loaded AIN file and its associated nodes and links 
--
-- Note that you shouldn't directly modify any of the class's fields, such as 'nodes' and 'links'
--
-- Use the appropriate methods to add and remove nodes and links as 'Graph' keeps track of additional
-- metadata automatically upon node and link creation and deletion
--
-- Reading data from the fields is fine, of course
-- ]]--
local Graph = {}

-- Enums
local Type = enum {
    Any  = 0,
    Deleted = 1,
    Ground = 2,
    Air = 3,
    Climb = 4,
    Water = 5,
}

local Zone = enum {
    Unknown = 0,
    Solo = 1,
    Universal = 3,
    First = 4,
}

local Hull = enum {
    Human = 1,
    SmallCentered = 2,
    WideHuman = 3,

    Tiny = 4,
    WideShort = 5,
    Medium = 6,
    TinyCentered = 7,

    Large = 8,
    LargeCentered = 9,

    MediumTall = 10,
}

local Capability = enum {
    MoveGround  = 0x00000001, -- walk/run
    MoveJump = 0x00000002, -- jump/leap
    MoveFly = 0x00000004, -- can fly, move all around
    MoveClimb = 0x00000008, -- climb ladders
    MoveSwim = 0x00000010, -- navigate in water          -- undone - not yet implemented
    MoveCrawl = 0x00000020, -- crawl                      -- undone - not yet implemented
    MoveShoot = 0x00000040, -- tries to shoot weapon while moving

    SkipNavGroundCheck = 0x00000080, -- optimization - skips ground tests while computing navigation
    Use = 0x00000100, -- open doors/push buttons/pull levers
    AutoDoors = 0x00000400, -- can trigger auto doors
    OpenDoors = 0x00000800, -- can open manual doors
    TurnHead = 0x00001000, -- can turn head, always bone controller 0

    WeaponRangeAttack1 = 0x00002000, -- can do a weapon range attack 1
    WeaponRangeAttack2 = 0x00004000, -- can do a weapon range attack 2
    WeaponMeleeAttack1 = 0x00008000, -- can do a weapon melee attack 1
    WeaponMeleeAttack2 = 0x00010000, -- can do a weapon melee attack 2

    InnateRangeAttack1 = 0x00020000, -- can do a innate range attack 1
    InnateRangeAttack2 = 0x00040000, -- can do a innate range attack 1
    InnateMeleeAttack1 = 0x00080000, -- can do a innate melee attack 1
    InnateMeleeAttack2 = 0x00100000, -- can do a innate melee attack 1

    UseWeapons = 0x00200000, -- can use weapons (non-innate attacks)
    AnimatedFace = 0x00800000, -- has animated eyes/face
    UseShotRegulator = 0x01000000, -- uses the shot regulator for range attack1
    FriendlyDmgImmune = 0x02000000, -- don't take damage from npc's that are dli

    Squad = 0x04000000, -- can form squads
    Duck = 0x08000000, -- cover and reload ducking
    NoHitPlayer = 0x10000000, -- don't hit players
    AimGun = 0x20000000, -- use arms to aim gun, not just body
    NoHitSquadmates = 0x40000000, -- none
    SimpleRadiusDamage = 0x80000000, -- do not use robust radius damage model on this character.
}

local LoadStatus = {
    NoAinFile = 0,
    Fail = 1,
    Success = 2,
}

local numHulls = 10
local ainVersionNumber = 37
local maxNodes = 1500

-- This is not exactly what the Source human hull is
-- sized as, but it works well enough for walkability checking
-- The 20 unit gap for the `mins` is to accommodate bumpy terrain
local humanHull = {
    mins = Vector(-13, -13, 20),
    maxs = Vector(13, 13, 72),
}

function Graph.New(cls, path)
    file.CreateDir("nodegraphs")

    local path = path or string.format("maps/graphs/%s.ain", game.GetMap())
    local self = {
        path = path,
        pathForSaving = string.format("nodegraphs/%s.ain.txt", game.GetMap()),

        version = ainVersionNumber,
        mapVersion = game.GetMapVersion(),
    
        nodes = {},
        neighbors = {},
    }

    setmetatable(self, { __index = Graph })
    return self
end
setmetatable(Graph, { __call = Graph.New })

function Graph:Load()
    local ainFp = file.Open(self.path, "rb", "GAME")
    if ainFp == nil then
        MsgE("Failed to open nodegraph %s", self.path)    
        return LoadStatus.NoAinFile
    end

    self.version = ainFp:ReadLong()
    self.mapVersion = ainFp:ReadLong()

    -- Read in nodes
    local numNodes = ainFp:ReadLong()
    self.nodes = {}

    for i=1, numNodes do
        local node = {}

        node.pos = Vector(ainFp:ReadFloat(), ainFp:ReadFloat(), ainFp:ReadFloat())
        node.yaw = ainFp:ReadFloat()

        node.hullOffsets = {}
        for j=1, numHulls do
            table.insert(node.hullOffsets, ainFp:ReadFloat())
        end

        node.type = ainFp:ReadByte()
        node.info = ainFp:ReadUShort()
        node.zone = ainFp:ReadShort()

        table.insert(self.nodes, node)
    end

    -- Then links, very similar to how nodes are read in
    local numLinks = ainFp:ReadLong()

    for i=1, numLinks do
        local src = ainFp:ReadShort()
        local dest = ainFp:ReadShort()

        local acceptedMoveTypes = {}
        for j=1, numHulls do
            table.insert(acceptedMoveTypes, ainFp:ReadByte())
        end

        self:AddLink(self.nodes[src + 1], self.nodes[dest + 1], acceptedMoveTypes) -- compensate for lua tables starting from 1
    end

    ainFp:Close()
    return LoadStatus.Success
end

function Graph:Save()
    local ainFp = file.Open(self.pathForSaving, "wb", "DATA")

    ainFp:WriteLong(self.version)
    ainFp:WriteLong(self.mapVersion)

    ainFp:WriteLong(#self.nodes)

    for i, node in ipairs(self.nodes) do
        ainFp:WriteFloat(node.pos.x)
        ainFp:WriteFloat(node.pos.y)
        ainFp:WriteFloat(node.pos.z)

        ainFp:WriteFloat(node.yaw)

        for i, hullOffset in ipairs(node.hullOffsets) do
            ainFp:WriteFloat(hullOffset)
        end

        ainFp:WriteByte(node.type)
        ainFp:WriteUShort(node.info)
        ainFp:WriteShort(node.zone)
    end

    local links = self:Links()
    ainFp:WriteLong(#links)

    for i, link in ipairs(links) do
        ainFp:WriteShort(link.src - 1)
        ainFp:WriteShort(link.dest - 1)

        for i, moveType in ipairs(link.acceptedMoveTypes) do
            ainFp:WriteByte(moveType)
        end
    end

    -- TODO whats up with the WC table lookup?
    -- This definitely is not correct
    for i, node in ipairs(self.nodes) do
        ainFp:WriteLong(i - 1)
    end

    ainFp:Close()
end

-- Creates a new node in graph's node list, returns the node's ID and structure
function Graph:AddNode(pos, nodeData)
    local node = {
        pos = pos,
        yaw = 0,

        hullOffsets = {},

        type = Type.Ground,
        zone = Zone.Unknown,
        info = 0,

        id = #self.nodes + 1
    }

    if nodeData then
        table.Merge(node, nodeData)
    end

    for i=1, numHulls do
        table.insert(node.hullOffsets, 0)
    end

    table.insert(self.nodes, node)
    return node
end

function Graph:RemoveNode(node)
    self:DisconnectNode(node)
    table.RemoveByValue(self.nodes, node)
end

function Graph:DisconnectNode(node)
    local neighbors = {}
    for neighbor, moveTypes in self:NeighborsFor(node) do
        table.insert(neighbors, neighbor)
    end

    for i, neighbor in ipairs(neighbors) do
        self:RemoveLink(node, neighbor)
    end
end

function Graph:MergeNodes(a, b)
    -- In essence, a new node is formed whose position is the average of `a` and `b`s positions
    -- It is linked to all nodes that were linked to `a` and `b`
    -- Rather than creating an entire new node, `a` is shifted to this intermediate position and is linked to all of the neighbors of `b`

    a.pos = (a.pos + b.pos) / 2
    for neighbor, moveTypes in self:NeighborsFor(b) do
        self:AddLink(a, neighbor)
    end

    self:RemoveNode(b)
end

-- Returns whether merging nodes `a` and `b` will result in
-- a merged link colliding through geometry
function Graph:IsSafeToMerge(a, b)
    local mergedPos = (a.pos + b.pos) / 2

    local function CheckLink(neighbor)
        local tr = util.TraceHull {
            start = mergedPos,
            endpos = neighbor.pos,

            mins = humanHull.mins,
            maxs = humanHull.maxs,
            mask = MASK_PLAYERSOLID,
        }

        return not tr.Hit
    end

    for i, node in ipairs { a, b } do
        for neighbor, _ in self:NeighborsFor(node) do
            if not CheckLink(neighbor) then return false end
        end
    end

    return true
end

-- Adds a one way link from the 'src' node to the 'dest' node
function Graph:AddOneWayLink(src, dest, acceptedMoveTypes)
    if src == dest then return end

    self.neighbors[src] = self.neighbors[src] or {}
    self.neighbors[src][dest] = acceptedMoveTypes
end

-- Adds a two way link between 'a' and 'b'
function Graph:AddLink(a, b, acceptedMoveTypes)
    acceptedMoveTypes = acceptedMoveTypes or {}
    local defaultMoveTypes = {
        [Hull.Human] = Capability.MoveGround,
        [Hull.SmallCentered] = Capability.MoveGround,
        [Hull.WideHuman] = Capability.MoveGround,

        [Hull.Tiny] = Capability.MoveGround,
        [Hull.WideShort] = Capability.MoveGround,
        [Hull.Medium] = Capability.MoveGround,
        [Hull.TinyCentered] = Capability.MoveGround,

        [Hull.Large] = 0,
        [Hull.LargeCentered] = 0,

        [Hull.MediumTall] = Capability.MoveGround,
    }

    table.Merge(defaultMoveTypes, acceptedMoveTypes)

    self:AddOneWayLink(a, b, defaultMoveTypes)
    self:AddOneWayLink(b, a, defaultMoveTypes)
end

function Graph:RemoveOneWayLink(a, b)
    if self.neighbors[a] then
        self.neighbors[a][b] = nil
    end
end

function Graph:RemoveLink(a, b)
    self:RemoveOneWayLink(a, b)
    self:RemoveOneWayLink(b, a)
end

function Graph:NeighborsFor(node)
    return pairs(self.neighbors[node] or {})
end

function Graph:NeighborsList(node)
    return table.GetKeys(self.neighbors[node] or {})
end

function Graph:AreOneWayLinked(a, b)
    return self.neighbors[a] ~= nil and self.neighbors[a][b] ~= nil
end

function Graph:AreLinked(a, b)
    return self:AreOneWayLinked(a, b) and self:AreOneWayLinked(b, a)
end

function Graph:Links()
    local links = {}
    local idxTable = self:BuildNodeIndexTable()

    for i, node in ipairs(self.nodes) do
        for neighbor, moveTypes in self:NeighborsFor(node) do
            local j = idxTable[neighbor]

            if i < j then
                table.insert(links, { src = i, dest = j, acceptedMoveTypes = moveTypes })
            end
        end
    end

    return links
end

function Graph:BuildNodeIndexTable()
    local table = {}

    for i, node in ipairs(self.nodes) do
        table[node] = i
    end

    return table
end

local spawnEntNames = { 
    "info_player_teamspawn", "info_player_deathmatch",
    "info_player_counterterrorist", "info_player_terrorist",
    "info_survivor_rescue", "info_survivor_position",
    "info_player_start",
}

function Graph:ConvertNavmesh(options)
    options = table.Inherit(options or {}, {
        simplify = true,
    })

    self.areaNodes = {} -- used to associate NavAreas with created nodes

    local spawnEnts
    if options.spawnEntName then
        spawnEnts = ents.FindByClass(options.spawnEntName)
    else
        for i, spawnEntName in ipairs(spawnEntNames) do
            spawnEnts = ents.FindByClass(spawnEntName)
            if #spawnEnts > 0 then break end
        end
    end

    local seedPositions = options.additionalSeedPositions or {}
    for i, spawnEnt in ipairs(spawnEnts) do
        table.insert(seedPositions, spawnEnt:GetPos())
    end

    if #seedPositions == 0 then
        MsgE("Could not find any valid seed positions")
        return
    end

    local spawnAreas = {}
    for i, pos in ipairs(seedPositions) do
        local area = navmesh.GetNearestNavArea(pos)
        if area:IsValid() then
            local id = area:GetID()
            
            if id then -- some NavAreas don't have IDs, for whatever reason
                spawnAreas[id] = area -- don't want duplicates, hence why using ID as key rather than just using `table.insert`
            end
        end
    end

    for id, area in pairs(spawnAreas) do
        self:PopulateFromAreaSeed(area)
    end

    if options.simplify then
        MsgF("Before simplifying, we have %s nodes", #self.nodes)
        self:Simplify(options.simplificationMaxDist)

        if #self.nodes > maxNodes then
            MsgF("Needs additional simplification, still have %s nodes, greater than max of %s", #self.nodes, maxNodes)
            self:Simplify(options.simplificationMaxDist * 2.5)
        end
    end

    if #self.nodes > maxNodes then
        MsgE("We still have %s nodes which is greater than the engine max of %s, your nodegraph won't load correctly :(. Try with simplification on?", #self.nodes, maxNodes)
    end
end

local function AreNavAreasWalkable(area1, area2)
    -- Check if the areas are both connected to each other
    -- A one-way connection indicates we can drop down from one area to another, but our nodegraph
    -- currently only handles areas that are walkable from each other, requiring a two-way connection
    if not area1:IsConnected(area2) or not area2:IsConnected(area1) then
        return false
    end

    local closeEnoughCorners = 0
    local allowedDiff = 20

    if area1:HasAttributes(NAV_MESH_STAIRS) or area2:HasAttributes(NAV_MESH_STAIRS) then
        allowedDiff = 40
    end

    for i = 0, 3 do
        for j = 0, 3 do
            local corner1 = area1:GetCorner(i)
            local corner2 = area2:GetCorner(j)

            local diff = math.abs(corner1.z - corner2.z)
            if diff < allowedDiff then
                closeEnoughCorners = closeEnoughCorners + 1
            end
        end
    end

    return closeEnoughCorners >= 2
end

local isEntOkInHullTrace = {
    func_door = true, func_door_rotating = true,
    prop_door = true, prop_door_rotating = true,
}

local function IsNavAreaStandable(area)
    if area:IsUnderwater() then
        return false
    end

    local tr = util.TraceHull {
        start = area:GetCenter(),
        endpos = area:GetCenter(),

        mins = humanHull.mins,
        maxs = humanHull.maxs,
        mask = MASK_PLAYERSOLID,
    }

    return not tr.Hit or isEntOkInHullTrace[tr.Entity:GetClass()]
end

function Graph:PopulateFromAreaSeed(areaSeed)
    local navAreasToVisit = { areaSeed }

    while #navAreasToVisit > 0 do
        local area = table.remove(navAreasToVisit)  
        local areaId = area:GetID()

        self.areaNodes[areaId] = self.areaNodes[areaId] or self:AddNavArea(area)
        local neighborAreas = area:GetAdjacentAreas()

        while #neighborAreas > 0 do
            local neighborArea = table.remove(neighborAreas)
            local neighborId = neighborArea:GetID()

            if AreNavAreasWalkable(area, neighborArea) and IsNavAreaStandable(neighborArea) then
                if not self.areaNodes[neighborId] then
                    self.areaNodes[neighborId] = self:AddNavArea(neighborArea)
                    table.insert(navAreasToVisit, neighborArea)
                end

                self:AddLink(self.areaNodes[areaId], self.areaNodes[neighborId])
            end
        end
    end
end

function Graph:AddNavArea(area)
    return self:AddNode(area:GetCenter() + Vector(0, 0, 10))
end

function Graph:Simplify(maxDistToMerge)
    while true do
        local nodesToBeMerged = {}
        local isNodeBeingMerged = {}

        for i, node in ipairs(self.nodes) do
            if not isNodeBeingMerged[node] then
                local nearestDist = math.huge
                local nearestNeighbor = nil

                for neighbor, moveTypes in self:NeighborsFor(node) do
                    local dist = node.pos:Distance(neighbor.pos)
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestNeighbor = neighbor
                    end
                end

                if nearestDist < maxDistToMerge and not isNodeBeingMerged[nearestNeighbor] and self:IsSafeToMerge(node, nearestNeighbor) then
                    table.insert(nodesToBeMerged, { node, nearestNeighbor })

                    isNodeBeingMerged[node] = true
                    isNodeBeingMerged[nearestNeighbor] = true
                end
            end
        end

        if #nodesToBeMerged == 0 then break end

        for i, nodesToMerge in ipairs(nodesToBeMerged) do
            self:MergeNodes(nodesToMerge[1], nodesToMerge[2])
        end
    end
end

function Graph:Draw(ply, drawRate)
    timer.Create("nav2ain_DrawGraph", drawRate, 0, function()
        for i, node in ipairs(self.nodes) do
            if node.type == Type.Ground then
                if node.pos:Distance(ply:GetPos()) < 1000 then
                    debugoverlay.Cross(node.pos, 10, drawRate + 0.1, Color(0, 0, 255))
                    debugoverlay.EntityTextAtPosition(node.pos, 0, "Node " .. i, drawRate + 0.1)
                end

                for neighbor, moveTypes in self:NeighborsFor(node) do
                    if moveTypes[Hull.Human] == Capability.MoveGround then
                        debugoverlay.Line(node.pos, neighbor.pos, drawRate + 0.1, Color(0, 255, 0))
                    end
                end
            end
        end
    end)
end

function Graph.DrawClear()
    timer.Remove("nav2ain_DrawGraph")
end

return {
    Graph = Graph,
    LoadStatus = LoadStatus,

    Type = Type,
    Zone = Zone,
    Hull = Hull,
    Capability = Capability,
}
