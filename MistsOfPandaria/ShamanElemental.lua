-- ShamanElemental.lua
-- August 2025 - MoP Structure based on Retail
-- Created by Smufrik


-- MoP: Use UnitClass instead of UnitClassBase
if select(2, UnitClass('player')) ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
    
-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
local class = Hekili.Class
local state = Hekili.State


local strformat = string.format
    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local spec = Hekili:NewSpecialization( 262, true )

-- Enhanced Mana resource system for Elemental Shaman
-- Mana resource registration for Elemental Shaman (simplified for MoP compatibility)
spec:RegisterResource( 0 ) -- Mana = 0 in MoP (use simple registration like other specs)

-- Talents (MoP Elemental Shaman talents)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Survivability
    nature_guardian       = { 1, 1, 31616  }, -- When you fall below 30% health, you instantly heal for a percentage of your maximum health. 30 sec internal cooldown.
    stone_bulwark_totem   = { 1, 2, 108270 }, -- Summons a Stone Bulwark Totem for 30 sec that grants you a damage-absorbing shield that periodically strengthens.
    astral_shift          = { 1, 3, 108271 }, -- Reduces all damage you take by 40% for 6 sec.

    -- Tier 2 (Level 30) - Control/Mobility
    frozen_power          = { 2, 1, 63374  }, -- Frost Shock roots the target in place for 5 sec. Internal cooldown applies per target.
    earthgrab_totem       = { 2, 2, 51485  }, -- Summons an Earthgrab Totem that roots enemies within 8 yards for 8 sec, then slows them.
    windwalk_totem        = { 2, 3, 108273 }, -- Summons a Windwalk Totem that grants immunity to movement-impairing effects to allies for 6 sec.

    -- Tier 3 (Level 45) - Totem Utility
    call_of_the_elements  = { 3, 1, 108285 }, -- Resets the cooldown of totems with a base CD shorter than 3 min.
    totemic_persistence   = { 3, 2, 108294 }, -- Allows one additional totem of the same element to be active concurrently.
    totemic_projection    = { 3, 3, 108287 }, -- Relocate your active totems to the targeted location.

    -- Tier 4 (Level 60) - Throughput/Haste
    elemental_mastery     = { 4, 1, 16166  }, -- Increases your spell haste by 30% and grants burst casting for a short duration.
    ancestral_swiftness   = { 4, 2, 16188  }, -- Grants 5% passive haste and an on-use effect making your next spell instant.
    echo_of_the_elements  = { 4, 3, 108283 }, -- Your spells and abilities have a chance to trigger an additional duplicate cast.

    -- Tier 5 (Level 75) - Healing/Support
    healing_tide_totem    = { 5, 1, 108280 }, -- Summons a totem that heals nearby allies over 10 sec.
    ancestral_guidance    = { 5, 2, 108281 }, -- Converts a portion of your damage and healing into healing on up to 3 injured allies.
    conductivity          = { 5, 3, 108282 }, -- While you damage enemies within your Healing Rain, allies standing in it are healed for a portion of the damage dealt.

    -- Tier 6 (Level 90) - Capstone
    unleashed_fury        = { 6, 1, 117012 }, -- Empowers Unleash Elements, enhancing the following spell based on your weapon imbue.
    primal_elementalist   = { 6, 2, 117013 }, -- Your Fire and Earth Elementals become powerful guardians with additional abilities and grant you increased damage.
    elemental_blast       = { 6, 3, 117014 }, -- A strong elemental attack that also grants a random secondary stat bonus for a short time.
} )

-- Glyphs (Enhanced System - authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs - Elemental Combat
    [54825] = "lightning_bolt",       -- Lightning Bolt now has a 50% chance to not trigger a cooldown
    [54760] = "chain_lightning",      -- Chain Lightning now affects 2 additional targets
    [54821] = "earth_shock",          -- Earth Shock now has a 50% chance to not trigger a cooldown
    [54832] = "flame_shock",          -- Flame Shock now has a 50% chance to not trigger a cooldown
    [54743] = "frost_shock",          -- Frost Shock now has a 50% chance to not trigger a cooldown
    [54829] = "lava_burst",           -- Lava Burst now has a 50% chance to not trigger a cooldown
    [54754] = "earthquake",           -- Earthquake now affects 2 additional targets
    [54755] = "thunderstorm",         -- Thunderstorm now affects 2 additional targets
    [116218] = "elemental_mastery",   -- Elemental Mastery now also increases your movement speed by 50%
    [125390] = "ancestral_swiftness", -- Ancestral Swiftness now also increases your movement speed by 30%
    [125391] = "echo_of_the_elements", -- Echo of the Elements now also increases your damage by 20%
    [125392] = "unleash_life",        -- Unleash Life now also increases your healing done by 20%
    [125393] = "ancestral_guidance",  -- Ancestral Guidance now also increases your healing done by 20%
    [125394] = "primal_elementalist", -- Primal Elementalist now also increases your damage by 20%
    [125395] = "elemental_focus",     -- Elemental Focus now also increases your critical strike chance by 10%
    
    -- Major glyphs - Utility/Defensive
    [94388] = "hex",                  -- Hex now affects all enemies within 5 yards
    [59219] = "wind_shear",           -- Wind Shear now has a 50% chance to not trigger a cooldown
    [114235] = "purge",               -- Purge now affects all enemies within 5 yards
    [125396] = "cleanse_spirit",      -- Cleanse Spirit now affects all allies within 5 yards
    [125397] = "healing_stream_totem", -- Healing Stream Totem now affects 2 additional allies
    [125398] = "healing_rain",        -- Healing Rain now affects 2 additional allies
    [125399] = "chain_heal",          -- Chain Heal now affects 2 additional allies
    [125400] = "healing_wave",        -- Healing Wave now has a 50% chance to not trigger a cooldown
    [125401] = "lesser_healing_wave", -- Lesser Healing Wave now has a 50% chance to not trigger a cooldown
    [54828] = "healing_surge",        -- Healing Surge now has a 50% chance to not trigger a cooldown
    
    -- Major glyphs - Defensive/Survivability
    [125402] = "shamanistic_rage",    -- Shamanistic Rage now also increases your dodge chance by 20%
    [125403] = "astral_shift",        -- Astral Shift now also increases your movement speed by 30%
    [125404] = "stone_bulwark_totem", -- Stone Bulwark Totem now also increases your armor by 20%
    [125405] = "healing_tide_totem",  -- Healing Tide Totem now affects 2 additional allies
    [125406] = "mana_tide_totem",     -- Mana Tide Totem now affects 2 additional allies
    [125407] = "tremor_totem",        -- Tremor Totem now affects all allies within 10 yards
    [125408] = "grounding_totem",     -- Grounding Totem now affects all allies within 10 yards
    [125409] = "earthbind_totem",     -- Earthbind Totem now affects all enemies within 10 yards
    [125410] = "searing_totem",       -- Searing Totem now affects 2 additional enemies
    [125411] = "magma_totem",         -- Magma Totem now affects 2 additional enemies
    
    -- Major glyphs - Control/CC
    [125412] = "hex",                 -- Hex now affects all enemies within 5 yards
    [125413] = "wind_shear",          -- Wind Shear now affects all enemies within 5 yards
    [125414] = "purge",               -- Purge now affects all enemies within 5 yards
    [125415] = "cleanse_spirit",      -- Cleanse Spirit now affects all allies within 5 yards
    [125416] = "healing_stream_totem", -- Healing Stream Totem now affects all allies within 10 yards
    [125417] = "healing_rain",        -- Healing Rain now affects all allies within 10 yards
    
    -- Minor glyphs - Visual/Convenience
    [57856] = "ghost_wolf",           -- Your ghost wolf has enhanced visual effects
    [57862] = "water_walking",        -- Your water walking has enhanced visual effects
    [57863] = "water_breathing",      -- Your water breathing has enhanced visual effects
    [57855] = "unburdening",          -- Your unburdening has enhanced visual effects
    [57861] = "astral_recall",        -- Your astral recall has enhanced visual effects
    [57857] = "the_prismatic_eye",    -- Your the prismatic eye has enhanced visual effects
    [57858] = "far_sight",            -- Your far sight has enhanced visual effects
    [57860] = "deluge",               -- Your deluge has enhanced visual effects
    [121840] = "lightning_shield",    -- Your lightning shield has enhanced visual effects
    [125418] = "blooming",            -- Your abilities cause flowers to bloom around the target
    [125419] = "floating",            -- Your spells cause you to hover slightly above the ground
    [125420] = "glow",                -- Your abilities cause you to glow with elemental energy
} )

-- Auras
spec:RegisterAuras( {
    -- Forms and Stances
    ghost_wolf = {
        id = 2645,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Weapon Imbues (MoP Classic IDs)
    flametongue = {
        id = 8024,
        duration = 3600,
        max_stack = 1,
    },
    
    frostbrand = {
        id = 8033,
        duration = 3600,
        max_stack = 1,
    },
    
    windfury = {
        id = 8232,
        duration = 3600,
        max_stack = 1,
    },
    
    rockbiter = {
        id = 8017,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Shields
    lightning_shield = {
        id = 324,
        duration = 600,
        max_stack = 7, -- Track up to 7 stacks for Fulmination (ES spender)
    },
    
    earth_shield = {
        id = 974,
        duration = 600,
        max_stack = 9,
    },
    
    water_shield = {
        id = 52127,
        duration = 600,
        max_stack = 3,
    },
    
    -- Buffs
    lava_surge = {
        id = 77756,
        duration = 10,
        max_stack = 1,
    },
    
    clearcasting = {
        id = 16246,
        duration = 15,
        max_stack = 1,
    },
    
    -- Talent Buffs
    elemental_mastery = {
        id = 16166,
        duration = 30,
        max_stack = 1,
    },
    
    ancestral_swiftness = {
        id = 16188,
        duration = 10,
        max_stack = 1,
    },
    
    echo_of_the_elements = {
        id = 108283,
        duration = 10,
        max_stack = 1,
    },
    
    -- Debuffs
    flame_shock = {
        id = 8050,
        duration = 30,
        tick_time = 3,
        type = "Magic",
        max_stack = 1,
    },
    
    frost_shock = {
        id = 8056,
        duration = 8,
        type = "Magic",
        max_stack = 1,
    },
    
    -- Totem auras with proper tracking
    searing_totem = {
        duration = 50,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 1 )
            
            if up and texture == 135825 then -- Searing Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    fire_elemental = {
        duration = 120,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 1 )
            
            if up and texture == 135790 then -- Fire Elemental texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    earth_elemental = {
        duration = 120,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 2 )
            
            if up and texture == 136024 then -- Earth Elemental texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    magma_totem = {
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 1 )
            
            if up and texture == 135826 then -- Magma Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    healing_stream_totem = {
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 3 )
            
            if up and texture == 135127 then -- Healing Stream Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    mana_tide_totem = {
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local up, name, start, duration, texture = GetTotemInfo( 3 )
            
            if up and texture == 135861 then -- Mana Tide Totem texture
                t.count = 1
                t.expires = start + duration
                t.applied = start
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Cooldown Buffs
    ascendance = {
        id = 114050,
        duration = 15,
        max_stack = 1,
    },
    
    thunderstorm = {
        id = 51490,
        duration = 10,
        max_stack = 1,
    },
    
    spiritwalkers_grace = {
        id = 79206,
        duration = 15,
        max_stack = 1,
    },
    
    astral_shift = {
        id = 108271,
        duration = 6,
        max_stack = 1,
    },

    stone_bulwark_totem = {
        id = 108270,
        duration = 30,
        max_stack = 1,
    },
} )

-- Register totem models for icon-based detection
spec:RegisterTotems( {
    searing_totem = { id = 135825 },
    magma_totem = { id = 135826 },
    fire_elemental = { id = 135790 },
    earth_elemental = { id = 136024 },
    healing_stream_totem = { id = 135127 },
    mana_tide_totem = { id = 135861 },
    stormlash_totem = { id = 237579 },
    earthbind_totem = { id = 136102 },
    grounding_totem = { id = 136039 },
    stoneclaw_totem = { id = 136097 },
    stoneskin_totem = { id = 136098 },
    tremor_totem = { id = 136108 },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Basic Abilities
    lightning_bolt = {
        id = 403,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.06 end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136048,
        
        handler = function()
            removeBuff( "clearcasting" )
            -- Build Lightning Shield stacks for Fulmination (up to 7)
            local stacks = state.buff.lightning_shield.stack or 0
            if state.buff.lightning_shield.up then
                applyBuff( "lightning_shield", nil, math.min( 7, stacks + 1 ) )
            end
        end,
    },
    
    chain_lightning = {
        id = 421,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.12 end,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            removeBuff( "clearcasting" )
            -- Build Lightning Shield stacks for Fulmination (up to 7) on CL as well
            local stacks = state.buff.lightning_shield.stack or 0
            if state.buff.lightning_shield.up then
                applyBuff( "lightning_shield", nil, math.min( 7, stacks + 1 ) )
            end
        end,
    },
    
    lava_burst = {
        id = 51505,
        cast = function() return state.buff.lava_surge.up and 0 or 2.0 end,
    cooldown = function() return buff.ascendance.up and 0 or 8 end,
        gcd = "spell",
        
        spend = function() return state.buff.lava_surge.up and 0 or 0.10 end,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            removeBuff( "lava_surge" )
            if state.debuff.flame_shock.up then
                -- Guaranteed crit on flame shocked targets
            end
        end,
    },
    
    earth_shock = {
        id = 8042,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            -- Consume Lightning Shield charges (Fulmination); leave baseline 1
            if state.buff.lightning_shield.up then
                applyBuff( "lightning_shield", nil, 1 )
            end
        end,
    },
    
    flame_shock = {
        id = 8050,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            applyDebuff( "target", "flame_shock" )
        end,
    },
    
    frost_shock = {
        id = 8056,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.17,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            applyDebuff( "target", "frost_shock" )
        end,
    },

    -- Ascendance (major cooldown)
    ascendance = {
        id = 114049,
        texture = 135791,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        startsCombat = false,

        toggle = "cooldowns",

        handler = function()
            applyBuff("ascendance")
        end,
    },

    -- Thunderstorm (mana restore, knockback)
    thunderstorm = {
        id = 51490,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function()
            -- Mana restore and knockback handled elsewhere if needed
            -- Could set a flag or update state if needed
        end,
    },
    
    -- Shields
    lightning_shield = {
        id = 324,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.lightning_shield.up and "lightning_shield" or ( state.buff.earth_shield.up and "earth_shield" ) or ( state.buff.water_shield.up and "water_shield" ) end,
        
        handler = function()
            removeBuff( "earth_shield" )
            removeBuff( "water_shield" )
            -- Apply Lightning Shield baseline; Fulmination stacks build via LB/CL
            applyBuff( "lightning_shield", nil, 1 )
        end,
        
        copy = { 324, 325, 905, 945, 8134, 10431, 10432, 25469, 25472, 49280, 49281 }
    },
    
    earth_shield = {
        id = 974,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.earth_shield.up and "earth_shield" or ( state.buff.lightning_shield.up and "lightning_shield" ) or ( state.buff.water_shield.up and "water_shield" ) end,
        
        handler = function()
            removeBuff( "lightning_shield" )
            removeBuff( "water_shield" )
            applyBuff( "earth_shield", nil, 9 )
        end,
        
        copy = { 974, 32593, 32594, 49283, 49284 }
    },
    
    water_shield = {
        id = 52127,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        essential = true,
        
        nobuff = function() return state.buff.water_shield.up and "water_shield" or ( state.buff.lightning_shield.up and "lightning_shield" ) or ( state.buff.earth_shield.up and "earth_shield" ) end,
        
        handler = function()
            removeBuff( "lightning_shield" )
            removeBuff( "earth_shield" )
            applyBuff( "water_shield", nil, 3 )
        end,
        
        copy = { 52127, 52129, 52131, 52134, 52136, 52138 }
    },
    
    -- Weapon Imbues
    flametongue_weapon = {
        id = 8024,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "flametongue",
        
        handler = function()
            applyBuff( "flametongue" )
        end,
    },
    
    frostbrand_weapon = {
        id = 8033,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "frostbrand",
        
        handler = function()
            applyBuff( "frostbrand" )
        end,
    },
    
    windfury_weapon = {
        id = 8232,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "windfury",
        
        handler = function()
            applyBuff( "windfury" )
        end,
    },
    
    rockbiter_weapon = {
        id = 8017,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        essential = true,
        
        nobuff = "rockbiter",
        
        handler = function()
            applyBuff( "rockbiter" )
        end,
    },
    
    -- Talent Abilities
    elemental_blast = {
        id = 117014,
        cast = 2.0,
        cooldown = 12,
        gcd = "spell",
        
        talent = "elemental_blast",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            -- Buffs a random stat
        end,
    },
    
    elemental_mastery = {
        id = 16166,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        talent = "elemental_mastery",
    toggle = "cooldowns",
        
        handler = function()
            applyBuff( "elemental_mastery" )
        end,
    },
    
    ancestral_swiftness = {
        id = 16188,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        talent = "ancestral_swiftness",
    toggle = "cooldowns",
        
        handler = function()
            applyBuff( "ancestral_swiftness" )
        end,
    },
    
    -- Utility
    purge = {
        id = 370,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136075,
        
        usable = function() return buff.dispellable_magic.up end,
        
        handler = function()
            removeBuff( "dispellable_magic" )
        end,
    },
    
    wind_shear = {
        id = 57994,
        cast = 0,
        cooldown = 12,
        gcd = "off",
        
        startsCombat = true,
        
        toggle = "interrupts",
        interrupt = true,
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        
        handler = function()
            -- Interrupt spell (actual interruption handled by Hekili core)
        end,
    },
    
    ghost_wolf = {
        id = 2645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        handler = function()
            applyBuff( "ghost_wolf" )
        end,
    },
    
    -- Totems
    searing_totem = {
        id = 3599,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        
        usable = function()
            -- Don't suggest if Searing Totem already active
            return not buff.searing_totem.up, "searing totem already active"
        end,
        
        handler = function()
            -- Searing Totem provides continuous damage
        end,
    },
    
    magma_totem = {
        id = 8190,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.35,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            -- Magma Totem provides AoE damage pulses
        end,
    },
    
    fire_elemental_totem = {
        id = 2894,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
    toggle = "cooldowns",
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            -- Summons Fire Elemental for 120 seconds
        end,
    },
    
    earth_elemental_totem = {
        id = 2062,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
    toggle = "cooldowns", -- treat as major CD so hidden when CDs disabled
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = false,
        
        handler = function()
            -- Summons Earth Elemental for 120 seconds
        end,
    },
    
    stormlash_totem = {
        id = 120668,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
    toggle = "cooldowns",
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = false,
        
        handler = function()
            -- Stormlash Totem buffs raid damage
        end,
    },
    
    -- Other Abilities
    unleash_elements = {
        id = 73680,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        spend = 0.17,
        spendType = "mana",
        startsCombat = true,
        handler = function()
            if state.buff.flametongue.up then
                -- Flame damage and movement bonus
            elseif state.buff.frostbrand.up then
                -- Frost damage and slow
            elseif state.buff.windfury.up then
                -- Lightning damage and speed
            elseif state.buff.rockbiter.up then
                -- Earth damage and damage reduction
            end
        end,
    },
    
    spiritwalkers_grace = {
        id = 79206,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        toggle = "defensives",
        startsCombat = false,
        handler = function()
            applyBuff( "spiritwalkers_grace" )
        end,
    },
    
    earthquake = {
        id = 61882,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        channeled = true,
        
        spend = 0.44,
        spendType = "mana",
        
        startsCombat = true,
        
        handler = function()
            -- Earthquake channeled AoE
        end,
    },
    
    call_of_the_elements = {
        id = 108285,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
    toggle = "cooldowns",
        
        talent = "call_of_the_elements",
        
        startsCombat = false,
        
        handler = function()
            -- Reduces totem cooldowns
        end,
    },

    -- Defensives (Talents Tier 1)
    astral_shift = {
        id = 108271,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        talent = "astral_shift",
        toggle = "defensives",
        startsCombat = false,
        handler = function()
            applyBuff( "astral_shift" )
        end,
    },

    stone_bulwark_totem = {
        id = 108270,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        talent = "stone_bulwark_totem",
        toggle = "defensives",
        startsCombat = false,
        handler = function()
            applyBuff( "stone_bulwark_totem" )
        end,
    },
    
    -- Ascendance abilities
    lava_beam = {
        id = 114074,
        cast = 2.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() return state.buff.clearcasting.up and 0 or 0.12 end,
        spendType = "mana",
        
        startsCombat = true,
        
        usable = function() return buff.ascendance.up end,
        
        handler = function()
            state:RemoveBuff( "clearcasting" )
            -- Build Lightning Shield stacks while beaming, too.
            local stacks = state.buff.lightning_shield.stack or 0
            if state.buff.lightning_shield.up then
                applyBuff( "lightning_shield", nil, math.min( 7, stacks + 1 ) )
            end
        end,
    },
} )

-- State Variables and Expressions
spec:RegisterStateExpr( "lightning_shield_max_stack", function()
    return 3 -- Lightning Shield has max 3 stacks in MoP
end )

spec:RegisterStateExpr( "time_to_bloodlust", function()
    -- Simple implementation - return a large number if no bloodlust planned
    return buff.bloodlust.up and 0 or 999
end )

-- Enchant tracking (weapon imbues) - using MoP Classic weapon enchant detection
local _GetWeaponEnchantInfo = _G.GetWeaponEnchantInfo -- may be nil on some clients/builds.
spec:RegisterStateTable( "enchant", setmetatable( {}, {
    __index = function( t, k )
        -- Fallback: if API not present just use self-buff presence.
        if k == "flametongue" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 5 ) ) or state.buff.flametongue.up }
            end
            return { weapon = state.buff.flametongue.up }
        elseif k == "frostbrand" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 2 ) ) or state.buff.frostbrand.up }
            end
            return { weapon = state.buff.frostbrand.up }
        elseif k == "windfury" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 283 ) ) or state.buff.windfury.up }
            end
            return { weapon = state.buff.windfury.up }
        elseif k == "rockbiter" then
            if _GetWeaponEnchantInfo then
                local has, _, _, enchantID = _GetWeaponEnchantInfo()
                return { weapon = ( has and ( enchantID == 1 ) ) or state.buff.rockbiter.up }
            end
            return { weapon = state.buff.rockbiter.up }
        end
        return { weapon = false }
    end
} ) )

-- Earthquake tracking (for ticking/remains)
spec:RegisterStateExpr( "ticking", function()
    return false -- Would need to track if earthquake is currently channeling
end )

spec:RegisterStateExpr( "remains", function()
    return 0 -- Earthquake remaining time - would need proper implementation
end )

-- Priority List
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    cycle = false,
    
    nameplates = false,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "volcanic_potion",
    
    package = "Elemental",
} )

spec:RegisterPack( "Elemental", 202508016, [[Hekili:vRrApUTn2FldwaJzWm1RpMRMm2anBBW2GnTfR7I9BYI2I2wDKe1ksnZAad9BFFpsDlsk5MMMSFibJ5X7(MYzQZV6SYJiOo)0SjZUBYJtVF807N84TFRZkXXyQZQyY2Nj7H)iIec))peqdPrcsaUZXagXdHaNLMSf21z1Mu)aXpg5SrpyFaoBmDlS89ZCwDW3ZJQolLV1z1VEWNN5I)JK5MJ4mx2o43Bf(SOm3aFUa2EhljZ9VtF2pWFmqijSD(ba6)lzURoqcjrVjZTKqZC)Mm3pY(Lm37gF34jzU)tMGiH2hGZ)ocN6b4aG9)M96bkb(X(uFpaVKi4VjPIday83MdJ4eFwIVWNYZ(Gea)scDllCdrG7rJjj5WwrX8XXf7F9I)AG)(dIi)O9R5h8PbE34VBXfBs3TBC7DgNgRhe7ca1GGfTpLU(vkjMfjbcnA7bsKyCTThR22ay8tORPfIO1cMGgkbK8Vg3CBJedNssqAU91BSoC7rMaBXgHK9HKYJRhzXmCTBqZWf)gXJUMttIbaTwTrPYGWbvX)OqEcAywaSq2PPGDZgky5aQ240aWU4Yq)KewcSoGKqP5fBp)Q(0DBaaImRWpK(00CZGps8H7NuAALdc4IjPrRv)AnA9Qyagq50KkOmR(n4X(Gj2RKGNPj817tiBP4jdzViLCJ9aWqI2sxoP(T2scc6IOTmwGh71iE)hLWKObx)fqnfrdbR8LlM3)n5GyjGUwqs2tf5cK)wjILoTvc1skQFDksos3dcFlnYd5zW840j5AvwVHGkNMCuULIggJsvWEATNp9Pf3orp23eWyER3LMC8SrKbac6lAYZG04piaEUUPJUSl)VC6Dt0kxMF3PtfiRoDMqdbJz(YPZMCLEYcCVfhSqxT2)prcRTKfjkBG6r7O6PBZvznuJ6XnxWscdi8dvId5vLwzbPCHj7ZztKomVhCT2a58GCx(qgVige6Q4QQeuyuRBYC9syXqIUc0blKMiJ0bMd4rdj)gMECtQ8xV6hbu4Gj5Ii4n3rQbpl75RgPcSDNK3WZZfjWj4V6Vter5555JjCoeTb(rKmb7BHyOumqxMRaeaKxy(qsy)Wywca4m30ONJaIVSGajW1Wz6qOwrqf)GCVhvYqYSOqMy22NnQUt501(OqJhWelGKVE8ggB8JrKy4m8yu5WblkI3XZvic8hWG)CmIEsWBqHZUekQZF)kWeb8Za50bqyrXAvWcLQv2ZhvWrjj5i1CGbgehWLneUPIVlnF1rxJ8yIgcjO(imQxN1lCJMpYaSkoWIz5Pn(zzIri3mA(K5(eu1gVqmK7cGf39Xm3RrHWBB4iWIcoQ8EuonYkjLPZQCGQ4Cvo4b65oYSJH0qFXunawB4i4Nys8UYcAezta1lhEtgFNviUbicHw4j3PeAxAjzzxJXRSWnTSoUWGZcQQUgl2ISt6YMRYYRlJ8cuA)7uHMqf13vIDmKhS4rOcIcLwxAiaU)AzKTIANwUy6Ol0fJwshZ6qh1rOScFw03a(Ya1aQtUgu2mcHcLZgzI5H2lOXbee6fri4yqybyEs)VXb(B9b(dJzipa3qCUTq4cHmOEKFqzionuNHWqfKP9Wr9cpbC4NPIP1a5qVZSg3rQmM3uzKl)3qpYI8EdUwyClle5bWiecz51)ROaAUJouG53RSGu2)qtC9zTylrUHRuk(QwopqEpzkQKnksUOyiEnp28TOQsqlCy1rtnA9ipq5kzn3i7ll6UwRhvqOrD5d1d(0jnlxpoTjO)7Gvb(47ZlEPYVemf4XKWwMcxIfeHz92te0RmtfdxNpGBkxINchW6n)S3hCBe(vvb4TjUZQKQoC25MGBO6tT0XiJo4kFSyzDvVpni0ps5D5Id65bWcvaLQZFBzOBVoMXWEVsWG9PrcmgoA7IfKa3Cd64E5Y75wKIkvyZAX6mLijvSCXd6Yao6sZ(XlV3Uc(EBoy6Ig9DSFOwii3lNFDrKP68iHrV(RQMAveunVoKoufFunaKB17DA0zUn4pl)HCruZa1nPONwm3MU9PzNoPpYEhgVPhsxSylgOccTSsnbIVe2T1iW)tk5zTZ26w9sekjSVKhQJV9aG21LSNZQxOjCy)IXEpz6ToRELKGBYDw9JQ67GWf33AK2JZ(GZk5FHJtxL5h(RFsoF(8iDoVZzL6soRA1gIAa6j(XQD12eLZk4aqXx(eCk9TAVjZDuM7fyXO6BYrUFo0wK5o1raSylARc891ItlObT6uXzDUeIQ5dhvntoGi6sCwig6bkZ90P8TBQODVQdlRHeLidjWBnsGGqvRZyf4QTocQ7mZRsIzjsmf6RUuEfCR8UrWE)aa7mjy7HCRWgc2hmyGk7ebStHock)HzuAVnLww3FgBWc5OhnWrf9czGpk41YJbG6BTdQzdduZqqnDIr93WTbM2oCsfqmxi0amjAHLEdmOVDGk41UtcjuLXakXyJIqQJnKea7LDKuyDnrqByk18vBQaFR3SPREccPcSPmI9A1dJMhZ2ACXoVGdOWHWF1cR39LF0f(R44TFnMgeu5G9ShFQzkrLf48bIcijOUiwd6UnkRuP1kFUnBz(Axlrln658(VFkp(RH39TvKF9v)aUowntUaNNRP3ZTvEJgpfS9uLLP37uXAnyQP28EZVPVz3MLu0Tk5gB3S06Aoe1bQoBnLXKM3oScg5)wtoqtrtAyr9hYBkRpcIYSh9ISyWRvL0KeT191WSakkuQBhvYquq3wQkL0TpWjZVtTTLAZvWzgaNRSB9RlG0T2Sw6XqRssw7A29uoRkGgEOvSmY5fsAZn5iLOZucutvpIsXZVasZeu3o9o)6i7d6ABcuPFFWC9SdrETu2q1qmaVVHGRw3R6QLThBYwWr2KPUcipNk1GopllCSmnA7MmBvStvI((k3P13KH1ON2O6ADnzUPkTHkq52eDHMnhp4SrFf4R(apS7V)PGIYp5JbMM8lCO3EZ0Bo6rjl0D6YFH4bTJb3EqQ(qXJdHuEsMrs)KdQrD6MKH5ymAMjJfr2S6Dn0AyqwAI1(CJ(S(jOOVOr9tA6s9zc6jQtJr2GwDow6bVws8McbCPb9TQCZz(TQm0puL(Rer38ak4RoZAPNNa(tqC3C8o2NVGf4GZxq)3tI29Q7fwR8IUWU6GQHQOVCjr7wrTvkETB2QTtF9VgBlJEd1YHcAR1dkzaRzj)eMSIPPluRUVMm7VVNSTNcHSM9C4LNoG0x)50OQ5uq)FuEuZzRoRwKmxrS9X3RlxA5i3BhyVhAR5CMBpLttMtgdZwV1HwHc67rJVXYJgFZqE04UEgF10AvzsGsXP1b1It)ivCGLaIns4gg7zICvN)3d]] )

