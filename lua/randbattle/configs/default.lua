
local sampler = include "randbattle/sampler.lua"

return {
    name = "default",
    author = "abass",
    description = "A sample config",

    archetypes = {
        grunt = sampler.Table {
            npc = "npc_combine_s",
            weapon = sampler.Choice {
                weapon_smg1 = {
                    chance = 2
                },
                weapon_ar2 = {
                    chance = 1
                },
            },
            accuracy = sampler.Choice {
                [WEAPON_PROFICIENCY_VERY_GOOD] = {
                    chance = 1
                },
                [WEAPON_PROFICIENCY_GOOD] = {
                    chance = 2
                }
            },
            grenades = 5,
        },
        elite = sampler.Table {
            npc = "npc_combine_s",
            weapon = "weapon_ar2",
            accuracy = WEAPON_PROFICIENCY_VERY_GOOD,
            grenades = 5,
            model = "elite",
        },
        shotgunner = sampler.Table {
            npc = "npc_combine_s",
            weapon = "weapon_shotgun",
            accuracy = WEAPON_PROFICIENCY_GOOD,
            grenades = 5,
            skin = 1,
        },
        rebel = sampler.Table {
            npc = "npc_citizen",
            weapon = sampler.Choice {
                weapon_smg1 = {
                    chance = 3,
                },
                weapon_ar2 = {
                    chance = 2,
                }
            },
            accuracy = WEAPON_PROFICIENCY_GOOD,
            type = CT_REBEL,
        }
    },

    squads = {
        combineSquad = sampler.Table {
            archetypes = sampler.Table {
                grunt = sampler.Table {
                    count = sampler.UniformInt {
                        min = 2,
                        max = 3,
                    },
                },
                elite = sampler.Table {
                    count = sampler.UniformInt {
                        min = 0,
                        max = 1,
                    },
                },
                shotgunner = sampler.Table {
                    count = 1,
                }
            }
        },
        rebelSquad = sampler.Table {
            archetypes = sampler.Table {
                rebel = sampler.Table {
                    count = 3
                }
            }
        }
    },

    scenarios = {
        default = {
            sides = {
                combine = sampler.Table {
                    squads = sampler.Choice { -- TODO squadToSpawn
                        combineSquad = {
                            chance = 1,
                        }
                    },
                    maxNpcs = 50,

                    spawnInterval = sampler.UniformNumber {
                        min = 2.0,
                        max = 5.0
                    },

                    minPlayerDist = 1000.0,
                    minEnemyDist = 1000.0,
                    minFriendlyDist = 650.0,
                }
            }
        },
        battle = {
            sides = {
                combine = sampler.Table {
                    squads = sampler.Choice { -- TODO squadToSpawn
                        combineSquad = {
                            chance = 1,
                        }
                    },
                    maxNpcs = 50,

                    spawnInterval = sampler.UniformNumber {
                        min = 2.0,
                        max = 5.0
                    },

                    minPlayerDist = 1000.0,
                    minEnemyDist = 1000.0,
                    minFriendlyDist = 650.0,
                },
                rebel = sampler.Table {
                    squads = sampler.Choice {
                        rebelSquad = {
                            chance = 1,
                        }
                    },
                    maxNpcs = 50,

                    spawnInterval = sampler.UniformNumber {
                        min = 2.0,
                        max = 5.0
                    },

                    minPlayerDist = 500.0,
                    minEnemyDist = 1000.0,
                    minFriendlyDist = 500.0,
                }
            }
        }
    },

    itemboxes = {
        dynamic = sampler.Table {
            item = "item_dynamic_resupply",
            count = sampler.UniformInt { min = 1, max = 3 },

            keyValues = sampler.Table {
                DesiredAmmoAR2 = sampler.UniformNumber { min = 0.33, max = 1.0 },
                DesiredAmmoBuckshot = sampler.UniformNumber { min = 0.5, max = 1.0 },
                DesiredAmmo357 = sampler.UniformNumber { min = 0.35, max = 1.0 },
            },
        }
    }
}