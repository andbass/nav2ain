
local sampler = include "randbattle/sampler.lua"

return {
    name = "max_payne",
    author = "abass",
    description = "Config for spawning NPCs from Geist's Max Payne Pack (https://steamcommunity.com/sharedfiles/filedetails/?id=2843144040)",

    archetypes = {
        mp_rand_enemy = sampler.Table {
            npc = "npc_mp1_randomenemy_h"
        },
        mp_swat_enemy = sampler.Table {
            npc = "npc_mp1_SWAT_h",
            randWeaponFromNpcData = true,
        },
        mp_suit_enemy = sampler.Table {
            npc = "npc_mp1_killersuit_h",
            randWeaponFromNpcData = true,
        }
    },

    squads = {
        mp_rand_squad = sampler.Table {
            archetypes = sampler.Table {
                mp_rand_enemy = sampler.Table {
                    count = sampler.UniformInt { min = 3, max = 4 }
                } 
            }
        },
        mp_swat_squad = sampler.Table {
            archetypes = sampler.Table {
                mp_swat_enemy = sampler.Table {
                    count = sampler.UniformInt { min = 3, max = 4 }
                },
            }
        },
        mp_suit_squad = sampler.Table {
            archetypes = sampler.Table {
                mp_suit_enemy = sampler.Table {
                    count = sampler.UniformInt { min = 3, max = 4 }
                },
            } 
        }
    },

    scenarios = {
        mp_rand = {
            sides = {
                mp_enemies = sampler.Table {
                    squads = sampler.Choice {
                        mp_rand_squad = {
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
        mp_police = {
            sides = {
                mp_enemies = sampler.Table {
                    squads = sampler.Choice {
                        mp_swat_squad = {
                            chance = 3,
                        },
                        mp_suit_squad = {
                            chance = 2,
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
        }
    }
}