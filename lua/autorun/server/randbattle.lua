
include "nav2ain/util.lua"

local dataManager = include "randbattle/datamanager.lua"
local sampler = include "randbattle/sampler.lua"
local spawner = include "randbattle/spawner.lua"

local function ListScenarios(ply, cmd, args, str)
    MsgF("Listing all available scenarios from loaded configs:")
    for name, scenario in pairs(dataManager.activeConfig.scenarios) do
        MsgF("\t%s", name)
    end
end

local function ListOrActivateModifiers(ply, cmd, args, str)
    MsgF("Listing all available modifiers")
    for name, modifier in pairs(dataManager.activeConfig.modifiers) do
        MsgF("\t%s", name)
    end

    MsgF("Listing all active modifiers")
    for name, modifier in pairs(dataManager.activeModifiers) do
        MsgF("\t%s", name)
    end
end

local function ActivateModifiers(ply, cmd, args, str)
    dataManager.UseModifiers(args)
end

local function Start(ply, cmd, args, str)
end

local function Stop(ply, cmd, args, str)


end

local function Burst(ply, cmd, args, str)
    if not spawner.ready then
        MsgE("Spanwer is not initialized - cannot perform spawn burst")
        return false
    end

    if not dataManager.UseScenario(args[1] or "default") then
        MsgE("Failed to load scenario - cannot perform spawn burst")
        return false
    end

    local sides = dataManager.Sides()
    local exhaustedSides = {}

    while table.Count(exhaustedSides) < #sides do
        for i, side in ipairs(sides) do
            local couldSpawn = spawner.SpawnRandomSquad(side, {
                patrol = true,
            })

            if not couldSpawn then
                exhaustedSides[side] = true
            end
        end
    end

    return true
end

local function DoStartupBurst(ply)
    local world = game.GetWorld()
    if ply.StartupBurstScenario ~= nil and not world.StartupBurstPerformed then
        -- `world.StartupBurstPerformed` is saved so if we go back to a prior level
        -- we won't do multiple bursts
        Burst(ply, "randbattle_burst", { ply.StartupBurstScenario })
        world.StartupBurstPerformed = true
    end
end

local function StartupBurst(ply, cmd, args, str)
    if #args == 0 then
        MsgF("Disabling startup burst for this session and subsequent save games")
        ply.StartupBurstScenario = nil
        return
    end

    -- `StartupBurstScenario` will persist between transitions
    -- so we know whether to do a startup burst when the player spawns in
    ply.StartupBurstScenario = args[1]

    MsgF("Startup burst enabled, now performing inital burst")
    DoStartupBurst(ply)
end

local function DrawHidingSpots(ply, cmd, args, str)
    spawner.debug.DrawHidingSpots(ply)
end

local function ClearDraw(ply, cmd, args, str)
    spawner.debug.ClearDraw() 
end

local function DebugProficiency(ply, cmd, args, str)
    for _, ent in ipairs(ents.FindByClass("npc_*")) do
        MsgF("Ent: %s, proficiency = %s", ent, ent:GetCurrentWeaponProficiency())
    end
end

local function DebugPrint(ply, cmd, args, str)
    PrintTable(spawner.spawnCount)
end

local function SpawnSquad(ply, cmd, args, str)
    local tr = ply:GetEyeTrace()
    if not tr.Hit then return end

    local squadDef = dataManager.activeConfig.squads[args[1]]
    spawner.InstantiateSquad("test", squadDef, {
        node = spawner.NearestNode(tr.HitPos)
    })
end

hook.Add("InitPostEntity", "randbattle_Initialize", function()
    dataManager.Init()

    -- Slight hack - if the AIN was stale or nonexistent,
    -- its possible we need to wait for the node graph (re)build to finish, so
    -- sleep for half a second here. TODO actually check on the rebuild progress somehow?
    -- Should be done within ~2 ticks based on my skim of `ai_networkmanager.cpp`
    timer.Simple(0.5, function()
        spawner.Init(dataManager)

        -- Handle any startup bursts we need to perform
        for i, ply in ipairs(player.GetAll()) do
            DoStartupBurst(ply)
        end
    end)
end)

concommand.Add("randbattle_scenarios", ListScenarios, nil, "TODO")
concommand.Add("randbattle_modifiers", ListOrActivateModifiers, nil, "TODO")
concommand.Add("randbattle_set_modifiers", ActivateModifiers, nil, "TODO")
concommand.Add("randbattle_start",  Start, nil, "TODO")
concommand.Add("randbattle_stop", Stop, nil, "TODO")
concommand.Add("randbattle_burst", Burst, nil, "TODO")
concommand.Add("randbattle_startup_burst", StartupBurst, nil, "TODO")

concommand.Add("randbattle_draw_hiding_spots", DrawHidingSpots, nil, "TODO")
concommand.Add("randbattle_clear_draw", ClearDraw, nil, "TODO")
concommand.Add("randbattle_debug_print", DebugPrint, nil, "TODO")
concommand.Add('randbattle_debug_proficiency', DebugProficiency, nil, "TOOD")
concommand.Add("randbattle_spawn_squad", SpawnSquad, nil, "TODO")