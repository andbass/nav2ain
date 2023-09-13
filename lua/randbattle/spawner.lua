local spawner = {}

include "nav2ain/util.lua"
local nodegraph = include "nav2ain/nodegraph.lua"
local sampler  = include "randbattle/sampler.lua"
local cvars = include "randbattle/cvars.lua"

function spawner.Init(dataManager)
    if spawner.ready then return true end

    spawner.dataManager = dataManager

    spawner.graph = nodegraph.Graph()
    spawner.graph:Load()

    if #spawner.graph.nodes == 0 or #spawner.graph:Links() == 0 then
        PrintMessage(HUD_PRINTTALK, "RANDBATTLE ERROR: Loaded nodegraph has no nodes or links - need to generate or make one")
        return false
    end

    spawner.FindHidingSpots()
    if #spawner.hidingSpots == 0 then
        PrintMessage(HUD_PRINTTALK, "RANDBATTLE WARNING: No hiding spots were present in navmesh - maybe need to generate or make one (see `nav_generate` concommand). Items will NOT spawn")
    end

    spawner.MakeRandomNodeFunc()
    spawner.MakeRandomHidingSpotFunc()

    spawner.nextSquadIdx = 0

    spawner.spawnedSquads = {}
    spawner.spawnCount = {}
    spawner.squadRepresentativeNpcs = {}

    spawner.spawnedItems = {}
    spawner.nextItemId = 0

    spawner.ready = true
end

function spawner.FindHidingSpots()
    spawner.hidingSpots = {}

    for _, area in ipairs(navmesh.GetAllNavAreas()) do
        for _, hidingSpot in ipairs(area:GetHidingSpots()) do
            table.insert(spawner.hidingSpots, hidingSpot)
        end
    end
end

function spawner.MakeRandomNodeFunc()
    local choices = {}
    for i, node in ipairs(spawner.graph.nodes) do
        local neighborCount = #spawner.graph:NeighborsList(node)
        if neighborCount > 0 then
            local neighborBoost = #spawner.graph:NeighborsList(node) < 3 and 1 or 0

            local tr = util.TraceLine {
                start = node.pos + Vector(0, 0, 10),
                endpos = node.pos + Vector(0, 0, 10000),
            }
            local insideBoost = (not tr.HitSky) and 4 or 0

            choices[node] = {
                chance = 1 + neighborBoost + insideBoost
            }
        else
            choices[node] = {
                chance = 0
            }
        end
    end

    spawner.RandomNode = sampler.Choice(choices)
end

function spawner.MakeRandomHidingSpotFunc()
    -- Maybe someday this is more complicated
    if #spawner.hidingSpots > 0 then
        spawner.RandomHidingSpot = sampler.Choice(spawner.hidingSpots)
    else
        spawner.RandomHidingSpot = function()
            return nil
        end
    end
end

spawner.knownModels = {
    elite  = "models/combine_super_soldier.mdl",
}

function spawner.OverrideWeapon(weapon)
    return spawner.dataManager.CallModifier("overrideWeapon", weapon) or weapon
end

function spawner.ApplyKeyValues(ent, keyValues)
    for key, value in pairs(keyValues or {}) do
        ent:SetKeyValue(key, value)
    end
end

function spawner.InstantiateArchetype(archetypeDef, options)
    options = table.Inherit(options or {}, {
        pos = Vector(),
        yaw = math.random(0, 359),
        squad = nil,
        spawnEffect = true,
        patrol = false,
    })

    local archetype = sampler.Eval(archetypeDef)
    local npc = ents.Create(archetype.npc)

    if not IsValid(npc) then
        -- Could be a reference to a NPC from the NPC list, see if we can find it there
        local npcList = list.Get("NPC")
        local npcData = npcList[archetype.npc]

        -- Some addons (i.e. Geist's Max Payne Pack) rely on these hooks
        -- to do special things to NPCs from the NPC list
        gamemode.Call("PlayerSpawnNPC", player.GetAll()[1], archetype.npc)
        npc = ents.Create(npcData.Class)

        if npcData.Health then
            npc:SetHealth(npcData.Health)
        end
	    if npcData.Material then
		    npc:SetMaterial(npcData.Material)
	    end
        if npcData.KeyValues then
            for k, v in pairs(npcData.KeyValues) do
                npc:SetKeyValue(k, v)
            end
        end
        if npcData.Model then
            npc:SetModel(npcData.Model)
        end
        if npcData.Skin then
            npc:SetSkin(npcData.Skin)
        end

        if archetype.randWeaponFromNpcData then
            local weapon = spawner.OverrideWeapon(table.Random(npcData.Weapons))
            npc:Give(weapon)
        end

        gamemode.Call("PlayerSpawnedNPC", player.GetAll()[1], npc)
    end

    if archetype.weapon ~= nil then
        npc:Give(spawner.OverrideWeapon(archetype.weapon))
    end

    if archetype.grenades ~= nil then
        npc:SetKeyValue("NumGrenades", archetype.grenades)
    end

    if archetype.model ~= nil then
        local model = spawner.knownModels[archetype.model:lower()] or archetype.model
        npc:SetModel(model)
    end

    if archetype.skin ~= nil then
        npc:SetSkin(archetype.skin)
    end
    
    if archetype.type ~= nil then
        npc.type = archetype.type
        npc:SetKeyValue("citizentype", archetype.type)
    end

    if archetype.accuracy ~= nil then
        npc:SetCurrentWeaponProficiency(archetype.accuracy)
    end

    if options.squad ~= nil then
        npc.squad = options.squad
        npc:Fire("SetSquad", options.squad, 0.5)
    end

    npc:SetPos(options.pos)
    npc:SetAngles(Angle(0, options.yaw, 0))

    if options.spawnEffect then
        spawner.PropSpawnEffect(npc)
    end

    if options.patrol then
        npc:Fire("StartPatrolling", "")
    end

    npc:CallOnRemove("randbattle_OnRemove", spawner.OnRemove)

    npc:Spawn()
    npc:Activate()

    npc:SetMaxHealth(npc:GetMaxHealth() * cvars.HealthScale:GetFloat())
    npc:SetHealth(npc:Health() * cvars.HealthScale:GetFloat())

    return npc
end

function spawner.InstantiateSquad(sideName, squadDef, options)
    options = table.Inherit(options or {}, {
        node = nil,
        yaw = math.random(0, 359),
        spawnEffect = true,
        patrol = false,
    })

    local config = spawner.dataManager.activeConfig

    local squadName = spawner.NextSquadName(sideName)
    local squad = sampler.Eval(squadDef)

    local node = options.node
    local neighbors = spawner.graph:NeighborsList(node)

    local totalSpawned = 0

    local npcs = {}
    spawner.spawnedSquads[squadName] = {}

    for archetypeName, params in pairs(squad.archetypes) do
        local archetypeDef = config.archetypes[archetypeName]
        for i = 1, params.count do
            local neighbor = neighbors[1 + (totalSpawned % #neighbors)]
            local dirToNeighbor = (neighbor.pos - node.pos):GetNormalized()

            local offset = dirToNeighbor * totalSpawned * 40
            offset.z = math.max(offset.z, 0)

            local pos = node.pos + offset + Vector(0, 0, 10 + offset.z * 10)

            local npc = spawner.InstantiateArchetype(archetypeDef, {
                pos = pos,
                yaw = options.yaw,
                squad = squadName,
                spawnEffect = options.spawnEffect,
                patrol = options.patrol
            })
            npc.side = sideName

            table.insert(npcs, npc)
            spawner.spawnedSquads[squadName][npc] = true

            totalSpawned = totalSpawned + 1
        end
    end

    spawner.spawnCount[sideName] = (spawner.spawnCount[sideName] or 0) + totalSpawned

    local repNpc = npcs[math.random(1, #npcs)]
    spawner.squadRepresentativeNpcs[repNpc] = sideName

    return npcs
end

function spawner.SpawnRandomSquad(sideName, options)
    options = table.Inherit(options or {}, {
        patrol = true,
        lineOfSightCheck = false,
    })

    local config = spawner.dataManager.activeConfig
    local scenario  = spawner.dataManager.activeScenario

    local sideDef = scenario.sides[sideName]
    local side = sampler.Eval(sideDef)

    local limit = (cvars.SideLimit:GetInt() > 0) and cvars.SideLimit:GetInt() or side.maxNpcs
    if (spawner.spawnCount[sideName] or 0) > limit then
        MsgF("Hit max npc limit for side %s of %s, bailing", sideName, limit)
        return false, side.spawnInterval
    end

    local node = spawner.GetSquadSpawnPoint(sideName, side, {
        lineOfSightCheck = options.lineOfSightCheck,
    })

    if node == nil then
        MsgF("For side %s, managed to spawn in %s NPCs before running out of available space", sideName, spawner.spawnCount[sideName])
        return false, side.spawnInterval
    end

    local squadName = side.squads -- This looks a bit weird, but it makes the config look nicer
    local squadDef = config.squads[squadName]

    spawner.InstantiateSquad(sideName, squadDef, {
        node = node,
        patrol = options.patrol,
    })

    return true, side.spawnInterval
end

local function Sqr(x)
    return x * x
end

function spawner.GetSquadSpawnPoint(sideName, side, options)
    options = table.Inherit(options or {}, {
        lineOfSightCheck = false,
    })

    local limit = 10000 -- TODO convar prolly

    local minPlayerDistCvar = cvars.MinPlayerDist:GetInt()
    local minPlayerDistSqr = Sqr((minPlayerDistCvar > 0) and minPlayerDistCvar or side.minPlayerDist or 0.0)
    local maxPlayerDistSqr = Sqr(side.maxPlayerDist or math.huge)

    local minEnemyDistSqr = Sqr(side.minEnemyDist or 0.0)
    local maxEnemyDistSqr = Sqr(side.maxEnemyDist or math.huge)

    local minFriendlyDistSqr = Sqr(side.minFriendlyDist or 0.0)
    local maxFriendlyDistSqr = Sqr(side.maxFriendlyDist or math.huge)

    for i = 1, limit do
        local node = spawner.RandomNode()
        
        -- Player checks
        local plyRangeOk = true
        for i, ply in ipairs(player.GetAll()) do
            local distSqr = ply:GetPos():DistToSqr(node.pos)
            if distSqr < minPlayerDistSqr or distSqr > maxPlayerDistSqr then
                plyRangeOk = false
                break
            end
        end

        if plyRangeOk then
            local npcRangeOk = true
            for npc, npcSideName in pairs(spawner.squadRepresentativeNpcs) do
                local distSqr = npc:GetPos():DistToSqr(node.pos)

                local minDistSqr = minEnemyDistSqr
                local maxDistSqr = maxEnemyDistSqr
                if npcSideName == sideName then -- TODO str compare sucks
                    minDistSqr = minFriendlyDistSqr
                    maxDistSqr = maxFriendlyDistSqr
                end

                if distSqr < minDistSqr or distSqr > maxDistSqr then
                    npcRangeOk = false
                    break
                end
            end

            if npcRangeOk then
                --MsgF("Found node after %s iterations", i)
                return node 
            end
        end
    end

    MsgF("Warning: failed to find node for side %s with retry limit %s", sideName, limit)
    return nil
end

function spawner.InstantiateItem(itemName, options)
    options = table.Inherit(options or {}, {
        pos = Vector(0, 0, 0)
    })

    local config = spawner.dataManager.activeConfig
    local itemboxInfo = sampler.Eval(config.itemboxes[itemName])

    local itemboxId = spawner.nextItemId
    spawner.nextItemId = spawner.nextItemId + 1

    local itembox = ents.Create("item_item_crate")
    itembox.itemId = itemboxId
    
    itembox:SetPos(options.pos)
    itembox:SetKeyValue("ItemClass", itemboxInfo.item)
    itembox:SetKeyValue("ItemCount", itemboxInfo.count)

    spawner.ApplyKeyValues(itembox, itemboxInfo.keyValues)

    itembox:CallOnRemove("randbattle_OnRemove", spawner.OnRemoveItem)

    itembox:Spawn()
    itembox:Activate()

    spawner.spawnedItems[itemboxId] = itembox
    return itembox
end

function spawner.SpawnRandomItem(options)
    options = table.Inherit(options or {}, {
        -- TODO what do we need? 
    })

    local config = spawner.dataManager.activeConfig

    local spawnPoint = spawner.GetItemSpawnPoint()
    if spawnPoint == nil then
        MsgF("Managed to spawn in %s items before running out of acceptable hiding spots", table.Count(spawner.spawnedItems))
        return false
    end

    local _, itemName = table.Random(config.itemboxes)
    spawner.InstantiateItem(itemName, {
        pos = spawnPoint,
    })
    
    return true
end

function spawner.GetItemSpawnPoint(options)
    options = table.Inherit(options or {}, {
        -- TODO what do we need? 
    })

    local minItemDistSqr = Sqr(cvars.ItemMinDist:GetInt())
    local limit = 10000 -- TODO convar prolly

    for i = 1, limit do
        local hidingSpot = spawner.RandomHidingSpot()
        if hidingSpot == nil then
            return nil
        end

        local distCheckOkay = true
        for otherId, otherItem in pairs(spawner.spawnedItems) do
            local distSqr = (otherItem:GetPos() - hidingSpot):LengthSqr()
            if distSqr < minItemDistSqr then
                distCheckOkay = false
                break
            end
        end

        if distCheckOkay then
            return hidingSpot
        end
    end

    MsgF("Warning: failed to find hiding spot for item after %s iterations, bailing", limit)
    return nil
end

function spawner.NearestNode(pos)
    local closestDist = math.huge
    local closestNode = nil

    for i, node in ipairs(spawner.graph.nodes) do
        local dist = pos:DistToSqr(node.pos)
        if dist < closestDist then
            closestDist = dist
            closestNode = node
        end
    end

    return closestNode
end

function spawner.NextSquadName(prefix)
    local squadIdx = spawner.nextSquadIdx
    spawner.nextSquadIdx = spawner.nextSquadIdx + 1

    return ("squad_%s_%s"):format(prefix, squadIdx)
end

function spawner.PropSpawnEffect(ent)
    local effectData = EffectData()
    effectData:SetEntity(ent)

    util.Effect("propspawn", effectData, true, true)
end

function spawner.OnRemove(npc)
    spawner.squadRepresentativeNpcs[npc] = nil

    if npc.side ~= nil then
        spawner.spawnCount[npc.side] = spawner.spawnCount[npc.side] - 1
    end

    if npc.squad ~= nil  then
        spawner.spawnedSquads[npc.squad][npc] = nil
    end
end

function spawner.OnRemoveItem(item)
    spawner.spawnedItems[item.itemId] = nil
end

spawner.debug = {
    drawRate = 0.25,

    PrintStats = function()
        MsgF("# of hiding spots = %s", #spawner.hidingSpots)
    end,

    TimerName = function(name)
        return "randbattle_Debug" .. name
    end,

    AddTimer = function(name, func)
        fullName = spawner.debug.TimerName(name)
        timer.Create(fullName, spawner.debug.drawRate, 0, func)
    end,

    RemoveTimer = function(name)
        timer.Remove(spawner.debug.TimerName(name))
    end,

    DrawHidingSpots = function(ply)
        local boxSize = 15
        local color = Color(128, 128, 255)

        spawner.debug.AddTimer("DrawHidingSpots", function()
            for _, pos  in ipairs(spawner.hidingSpots) do
                if pos:Distance(ply:GetPos()) < 1000 then
                    debugoverlay.Sphere(pos, 15, spawner.debug.drawRate + 0.1, Color(128, 128, 255))
                end
            end
        end) 
    end,

    DrawAll = function(ply)
        spawner.debug.DrawHidingSpots(ply)
    end,

    ClearDraw = function()
        spawner.debug.RemoveTimer("DrawHidingSpots")
    end,
}

return spawner