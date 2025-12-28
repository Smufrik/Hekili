-- Classes.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Classes loading

local addon, ns = ...
local Hekili = _G[ addon ]

if not Hekili then return end

local class, all

local function getReferences()
    if not class and Hekili and Hekili.Class then
        class = Hekili.Class
    end
    if not all and class and class.specs then
        all = class.specs[0]
    end
    return class, all
end

if not Hekili or not Hekili.CurrentBuild or Hekili.CurrentBuild < 50400 then return end



-- spellFilters[ instanceID ][ npcID ][ spellID ] = { name = ..., interrupt = true, ... }
-- For Mists of Pandaria specific dungeon and raid encounters
local spellFilters = {
    -- Mogu'shan Vaults
    [ 1008 ] = {
        name = "Mogu'shan Vaults",
        -- Stone Guard
        [ 60051 ] = {
            name = "Jade Guardian",
            [ 115840 ] = {
                interrupt = true,
            }, -- Cobalt Mine
        },
        [ 60043 ] = {
            name = "Amethyst Guardian",
            [ 115844 ] = {
                spell_reflection = true,
            }, -- Amethyst Pool
        },
        -- Feng the Accursed
        [ 60009 ] = {
            name = "Feng the Accursed",
            [ 116157 ] = {
                spell_reflection = true,
            }, -- Lightning Fists
            [ 116018 ] = {
                interrupt = true,
            }, -- Epicenter
        },
    },

    -- Heart of Fear
    [ 1009 ] = {
        name = "Heart of Fear",
        -- Imperial Vizier Zor'lok
        [ 62980 ] = {
            name = "Imperial Vizier Zor'lok",
            [ 122336 ] = {
                spell_reflection = true,
            }, -- Sonic Ring
        },
        -- Blade Lord Ta'yak
        [ 62543 ] = {
            name = "Blade Lord Ta'yak",
            [ 122949 ] = {
                interrupt = true,
            }, -- Unseen Strike
        },
    },

    -- Terrace of Endless Spring
    [ 996 ] = {
        name = "Terrace of Endless Spring",
        -- Protector Kaolan
        [ 60583 ] = {
            name = "Protector Kaolan",
            [ 117519 ] = {
                spell_reflection = true,
            }, -- Touch of Sha
        },
        -- Tsulong
        [ 62442 ] = {
            name = "Tsulong",
            [ 122752 ] = {
                interrupt = true,
            }, -- Shadow Breath
        },
    },

    -- Throne of Thunder
    [ 1098 ] = {
        name = "Throne of Thunder",
        -- Horridon
        [ 68476 ] = {
            name = "Horridon",
            [ 136740 ] = {
                spell_reflection = true,
            }, -- Double Swipe
        },
        -- Council of Elders
        [ 69078 ] = {
            name = "Frost King Malakk",
            [ 136992 ] = {
                interrupt = true,
            }, -- Frostbite
        },
    },

    -- Siege of Orgrimmar
    [ 1136 ] = {
        name = "Siege of Orgrimmar",
        -- Immerseus
        [ 71543 ] = {
            name = "Immerseus",
            [ 143436 ] = {
                spell_reflection = true,
            }, -- Corrosive Blast
        },
        -- Norushen
        [ 72276 ] = {
            name = "Manifestation of Corruption",
            [ 144639 ] = {
                interrupt = true,
            }, -- Corruption
        },
    },

    -- MoP Dungeons
    [ 962 ] = {
        name = "Gate of the Setting Sun",
        [ 56906 ] = {
            name = "Saboteur Kip'tilak",
            [ 107268 ] = {
                spell_reflection = true,
            }, -- Sabotage
        },
    },

    [ 994 ] = {
        name = "Mogu'shan Palace",
        [ 61444 ] = {
            name = "Ming the Cunning",
            [ 118312 ] = {
                interrupt = true,
            }, -- Magnetic Field
        },
    },

    [ 959 ] = {
        name = "Shado-Pan Monastery",
        [ 56541 ] = {
            name = "Master Snowdrift",
            [ 106434 ] = {
                spell_reflection = true,
            }, -- Tornado Kick
        },
    },

    [ 960 ] = {
        name = "Temple of the Jade Serpent",
        [ 56448 ] = {
            name = "Wise Mari",
            [ 106055 ] = {
                interrupt = true,
            }, -- Hydrolance
        },
    },

    [ 961 ] = {
        name = "Stormstout Brewery",
        [ 56637 ] = {
            name = "Ook-Ook",
            [ 106807 ] = {
                spell_reflection = true,
            }, -- Barrel Toss
        },
    },

    [ 1011 ] = {
        name = "Siege of Niuzao Temple",
        [ 61567 ] = {
            name = "General Pa'valak",
            [ 124255 ] = {
                interrupt = true,
            }, -- Blade Rush
        },
    },
}

--[[
    The RegisterMistsAuras and RegisterMistsGear functions were previously defined in a way
    that prevented them from executing properly. They are now defined at the top level
    and called correctly within the TryRegister function.
--]]

local function RegisterMistsAuras()
    local class, all = getReferences()
    if not class or not all then return end -- Not ready yet

    -- Set up spell filters
    class.spellFilters = spellFilters

    do
        local interruptibleFilters = {}

        for zoneID, zoneData in pairs( spellFilters ) do
            for npcID, npcData in pairs( zoneData ) do
                if type(npcID) == "number" and type(npcData) == "table" then
                    for spellID, spellData in pairs( npcData ) do
                        if type(spellID) == "number" and type(spellData) == "table" and spellData.interrupt then
                            interruptibleFilters[spellID] = true
                        end
                    end
                end
            end
        end

        class.interruptibleFilters = interruptibleFilters
    end

    all:RegisterAuras({
        -- Legendary Cloak Procs
        spirit_of_chi_ji = {
            id = 146198,
            duration = 10,
            max_stack = 1,
        },

        endurance_of_niuzao = {
            id = 146197,
            duration = 10,
            max_stack = 5,
        },

        essence_of_yulon = {
            id = 146199,
            duration = 10,
            max_stack = 10,
        },

        flurry_of_xuen = {
            id = 146200,
            duration = 10,
            max_stack = 10,
        },

        -- Bloodlust effects
        bloodlust = {
            id = 2825,
            duration = 40,
            max_stack = 1,
            shared = "player",
        },

        heroism = {
            id = 32182,
            duration = 40,
            max_stack = 1,
            shared = "player",
        },

        time_warp = {
            id = 80353,
            duration = 40,
            max_stack = 1,
            shared = "player",
        },

        ancient_hysteria = {
            id = 90355,
            duration = 40,
            max_stack = 1,
            shared = "player",
        },

        -- Exhaustion effects
        exhaustion = {
            id = 57723,
            duration = 600,
            max_stack = 1,
            shared = "player",
        },

        sated = {
            id = 57724,
            duration = 600,
            max_stack = 1,
            shared = "player",
        },

        temporal_displacement = {
            id = 80354,
            duration = 600,
            max_stack = 1,
            shared = "player",
        },

        insanity = {
            id = 95809,
            duration = 600,
            max_stack = 1,
            shared = "player",
        },

        -- Tier Set Bonuses
        -- T14 - MSV, HoF, ToES
        tier14_2pc_agility = {
            id = 123157,
            duration = 15,
            max_stack = 1,
        },

        tier14_2pc_strength = {
            id = 123154,
            duration = 15,
            max_stack = 1,
        },

        tier14_2pc_intellect = {
            id = 123156,
            duration = 15,
            max_stack = 1,
        },

        -- T15 - ToT
        tier15_2pc_agility = {
            id = 138216,
            duration = 15,
            max_stack = 3,
        },

        tier15_2pc_strength = {
            id = 138217,
            duration = 15,
            max_stack = 3,
        },

        tier15_2pc_intellect = {
            id = 138218,
            duration = 15,
            max_stack = 3,
        },

        -- T16 - SoO
        tier16_2pc_agility = {
            id = 144654,
            duration = 10,
            max_stack = 1,
        },

        tier16_2pc_strength = {
            id = 144653,
            duration = 10,
            max_stack = 1,
        },

        tier16_2pc_intellect = {
            id = 144865,
            duration = 10,
            max_stack = 1,
        },

        -- Trinket Procs
        vicious_talisman_of_the_shado_pan_assault = {
            id = 138699,
            duration = 20,
            max_stack = 1,
        },

        renatakis_soul_charm = {
            id = 138729,
            duration = 20,
            max_stack = 1,
        },

        restless_spirit = {
            id = 138728,
            duration = 10,
            max_stack = 1,
        },

        breath_of_hydra = {
            id = 138963,
            duration = 10,
            max_stack = 1,
        },

        wushoolays_final_choice = {
            id = 138703,
            duration = 15,
            max_stack = 1,
        },

        feather_of_ji_kun = {
            id = 138759,
            duration = 10,
            max_stack = 1,
        },

        unerring_vision_of_lei_shen = {
            id = 139133,
            duration = 4,
            max_stack = 1,
        },

        rune_of_reorigination = {
            id = 139120,
            duration = 10,
            max_stack = 1,
        },

        -- SoO Trinkets
        amplification = {
            id = 146046,
            duration = 20,
            max_stack = 1,
        },

        cleave = {
            id = 146048,
            duration = 20,
            max_stack = 1,
        },

        multistrike = {
            id = 146051,
            duration = 20,
            max_stack = 1,
        },
          readiness = {
            id = 146047,
            duration = 20,
            max_stack = 1,
        },
    })
end


-- Register shared MoP gear/trinkets
local function RegisterMistsGear()
    local class, all = getReferences()
    if not all then return end

    -- MoP Trinkets - shared across all specializations
    -- Celestial Arena Trinkets (from Celestials)
    all:RegisterGear( "relic_of_chi_ji", 94511 )
    all:RegisterGear( "relic_of_niuzao", 94512 )
    all:RegisterGear( "relic_of_xuen", 94513 )
    all:RegisterGear( "relic_of_yu_lon", 94514 )

    -- Heart of Fear Trinkets
    all:RegisterGear( "bottle_of_infinite_stars", 86301 )      -- Normal
    all:RegisterGear( "bottle_of_infinite_stars_lfr", 86326 )  -- LFR
    all:RegisterGear( "bottle_of_infinite_stars_heroic", 86350 ) -- Heroic

    all:RegisterGear( "stuff_of_nightmares", 86308 )          -- Normal
    all:RegisterGear( "stuff_of_nightmares_lfr", 86333 )      -- LFR
    all:RegisterGear( "stuff_of_nightmares_heroic", 86357 )   -- Heroic

    -- Throne of Thunder Trinkets
    all:RegisterGear( "lei_shens_final_orders", 95802 )       -- Normal
    all:RegisterGear( "lei_shens_final_orders_lfr", 96540 )   -- LFR
    all:RegisterGear( "lei_shens_final_orders_heroic", 96741 ) -- Heroic

    all:RegisterGear( "bad_juju", 95810 )                     -- Normal
    all:RegisterGear( "bad_juju_lfr", 96548 )                 -- LFR
    all:RegisterGear( "bad_juju_heroic", 96749 )              -- Heroic

    all:RegisterGear( "wushoolays_final_choice", 95815 )      -- Normal
    all:RegisterGear( "wushoolays_final_choice_lfr", 96553 )  -- LFR
    all:RegisterGear( "wushoolays_final_choice_heroic", 96754 ) -- Heroic

    all:RegisterGear( "renatakis_soul_charm", 95802 )         -- Normal (duplicate ID, different item)
    all:RegisterGear( "renatakis_soul_charm_lfr", 96540 )     -- LFR
    all:RegisterGear( "renatakis_soul_charm_heroic", 96741 )  -- Heroic

    -- Siege of Orgrimmar Trinkets
    all:RegisterGear( "ticking_ebon_detonator", 101801 )      -- Normal
    all:RegisterGear( "ticking_ebon_detonator_lfr", 102293 )  -- LFR
    all:RegisterGear( "ticking_ebon_detonator_heroic", 102658 ) -- Heroic

    all:RegisterGear( "haromms_talisman", 101797 )            -- Normal
    all:RegisterGear( "haromms_talisman_lfr", 102289 )        -- LFR
    all:RegisterGear( "haromms_talisman_heroic", 102654 )     -- Heroic

    all:RegisterGear( "assurance_of_consequence", 101805 )    -- Normal
    all:RegisterGear( "assurance_of_consequence_lfr", 102297 ) -- LFR
    all:RegisterGear( "assurance_of_consequence_heroic", 102662 ) -- Heroic

    all:RegisterGear( "rooks_unlucky_talisman", 101804 )      -- Normal
    all:RegisterGear( "rooks_unlucky_talisman_lfr", 102296 )  -- LFR
    all:RegisterGear( "rooks_unlucky_talisman_heroic", 102661 ) -- Heroic

    -- MoP Idols/Relics (class-specific items)
    all:RegisterGear( "inscribed_tiger_staff", 86196 )       -- Feral/Guardian
    all:RegisterGear( "inscribed_crane_staff", 86197 )       -- Balance/Resto
    all:RegisterGear( "inscribed_serpent_staff", 86198 )     -- All druids
    all:RegisterGear( "flawless_pandaren_relic", 88368 )     -- Generic
end

-- Register when ready
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterMistsAuras()
        RegisterMistsGear()
        return true
    end
    return false
end

-- Try to register immediately, or wait for addon loaded
if not TryRegister() then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
