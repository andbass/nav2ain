
return {
    SideLimit = CreateConVar("randbattle_side_limit", 0, { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "If nonzero, overrides the NPC limit per-side in the active config"),
    MinPlayerDist = CreateConVar("randbattle_min_player_dist", 0, { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "If nonzero, overrides the minimum distance an NPC must be from a player when choosing NPC spawn points"),

    ItemLimit = CreateConVar("randbattle_item_limit", 0, { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "If nonzero, limits the amount of items that can be spawned"),
    ItemMinDist = CreateConVar("randbattle_item_min_dist", 500, { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "The min distance an item must be from another item to spawn in"),
    InitialItems = CreateConVar("randbattle_initial_items", 3, { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "If nonzero, some initial item boxes will be spawned in burst mode"),

    HealthScale = CreateConVar("randbattle_health_scale", 1.0, { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "Scales health to all entities spawned - useful for balancing overpowered SWEPS"),
}