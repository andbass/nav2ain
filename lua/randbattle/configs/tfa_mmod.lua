
local sampler = include "randbattle/sampler.lua"

return {
    name = "tfa_mmod_default",
    author = "abass",
    description = "Modifiers to replace spawned weapons with TFA MMod equivalents",

    modifiers = {
        tfa_mmod_replace = {
            overrideWeapon = function(weapon, npc)
                return ({
                    weapon_smg1 = "tfa_projecthl2_smg",
                    weapon_shotgun = "tfa_projecthl2_spas12",
                    weapon_ar2 = "tfa_projecthl2_ar2",
                })[weapon]
            end
        }
    }
}