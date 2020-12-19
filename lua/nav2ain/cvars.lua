
return {
    DrawSimplifiedMesh = CreateConVar("nav_draw_simplified_mesh", "0", { FCVAR_REPLICATED }, 'Whether or not to draw the simplified nav mesh onto the screen'),
    DrawRate = CreateConVar("nav_draw_simplified_mesh_rate", "0.5", { FCVAR_REPLICATED }, 'The rate at which the simplified nav mesh is drawn, given that "nav_draw_simplified_mesh" is not equal to 0'),
}
