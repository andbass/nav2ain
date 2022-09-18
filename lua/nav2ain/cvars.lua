
return {
    DrawSimplifiedMesh = CreateConVar("nav_draw_simplified_mesh", "0", { FCVAR_REPLICATED }, 'Whether or not to draw the simplified nav mesh onto the screen'),
    DrawRate = CreateConVar("nav_draw_simplified_mesh_rate", "0.5", { FCVAR_REPLICATED }, 'The rate at which the simplified nav mesh is drawn, given that "nav_draw_simplified_mesh" is not equal to 0'),

    SimplifyNodeGraph = CreateConVar("nav2ain_simplify", "1", { FCVAR_REPLICATED }, "Whether to simplify the final nodegraph or not. Helps performance + can help if too many nodes are initially created beyond the engine limit"),
    SimplifyMaxDist = CreateConVar("nav2ain_simplify_max_dist",  "150", { FCVAR_REPLICATED }, "The maximum distance at which neighboring nodes are merged during simplication. Smaller values result in more complex nodegraphs but preserve more detail"),
}
