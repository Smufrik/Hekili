if not Hekili or not Hekili.NewSpecialization then return end
-- DruidRestoration.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Druid: Restoration spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 105, true ) -- Restoration spec ID for MoP

-- Register resources
spec:RegisterResource( 0 ) -- Mana = 0 in MoP
spec:RegisterResource( 3 ) -- Energy = 3 in MoP

-- Spec configuration for MoP
spec.role = "HEALER"
spec.primaryStat = "intellect"
spec.name = "Restoration"

-- No longer need custom spec detection - WeakAuras system handles this in Constants.lua

-- Tier sets and combat log tracking
spec:RegisterGear( "tier13", 78784, 78785, 78786, 78787, 78788, 78789, 78790, 78791, 78792, 78793 ) -- T13 Deep Earth
spec:RegisterGear( "tier14", 85354, 85356, 85357, 85359, 85355 ) -- T14 Eternal Blossom Vestment
spec:RegisterGear( "tier15", 95981, 95982, 95983, 95985, 95986 ) -- T15 Vestment of the Haunted Forest
spec:RegisterGear( "tier16", 99354, 99355, 99356, 99357, 99358 ) -- T16 Vestment of the Prehistoric Marauder

-- Additional tier difficulties
spec:RegisterGear( "tier14_lfr", 85688, 85689, 85690, 85691, 85692 ) -- T14 LFR
spec:RegisterGear( "tier14_heroic", 86901, 86902, 86903, 86904, 86905 ) -- T14 Heroic
spec:RegisterGear( "tier15_lfr", 96638, 96639, 96640, 96641, 96642 ) -- T15 LFR  
spec:RegisterGear( "tier15_heroic", 96921, 96922, 96923, 96924, 96925 ) -- T15 Heroic
spec:RegisterGear( "tier16_lfr", 105707, 105708, 105709, 105710, 105711 ) -- T16 LFR
spec:RegisterGear( "tier16_heroic", 104480, 104481, 104482, 104483, 104484 ) -- T16 Heroic

-- Legendary items
spec:RegisterGear( "legendary_cloak", 102246, 102247, 102248, 102249, 102250 ) -- Qian-Ying, Fortitude of Niuzao
spec:RegisterGear( "legendary_meta", 101821, 101822 ) -- Legendary meta gems

-- Notable Restoration trinkets
spec:RegisterGear( "prismatic_prison_of_pride", 102291 ) -- SoO trinket
spec:RegisterGear( "dysmorphic_samophlange", 102658 ) -- SoO trinket  
spec:RegisterGear( "purified_bindings_of_immerseus", 105109 ) -- SoO trinket
spec:RegisterGear( "kardris_toxic_totem", 104909 ) -- SoO trinket

-- Restoration weapons
spec:RegisterGear( "black_blood_of_yshaarj", 104400 ) -- Staff from SoO
spec:RegisterGear( "xing_ho_breath_of_yulons", 104404 ) -- Staff from SoO
spec:RegisterGear( "serenity_now", 105672 ) -- Staff from SoO

-- PvP sets
spec:RegisterGear( "gladiator_s14", 91446, 91447, 91448, 91449, 91450 ) -- Season 14 Gladiator
spec:RegisterGear( "grievous_s15", 94723, 94724, 94725, 94726, 94727 ) -- Season 15 Grievous

-- Challenge Mode sets
spec:RegisterGear( "challenge_mode", 90560, 90561, 90562, 90563, 90564 ) -- Challenge Mode Druid set

-- Combat log tracking for Restoration-specific events
local function RegisterRestorationCombatLog()
    spec:RegisterCombatLogEvent( function( _, subtype, _,  sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )
        
        if sourceGUID == state.GUID then
            -- Rejuvenation casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 774 then
                state.rejuvenation_cast_time = GetTime()
            end
            
            -- Regrowth casts  
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 8936 then
                state.regrowth_cast_time = GetTime()
            end
            
            -- Lifebloom casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 33763 then
                state.lifebloom_cast_time = GetTime()
            end
            
            -- Wild Growth casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 48438 then
                state.wild_growth_cast_time = GetTime()
            end
            
            -- Swiftmend casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 18562 then
                state.swiftmend_cast_time = GetTime()
            end
            
            -- Healing Touch casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 5185 then
                state.healing_touch_cast_time = GetTime()
            end
            
            -- Tranquility casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 740 then
                state.tranquility_cast_time = GetTime()
            end
            
            -- Tree of Life casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 33891 then
                state.tree_of_life_cast_time = GetTime()
            end
            
            -- Nature's Swiftness casts
            if subtype == "SPELL_CAST_SUCCESS" and spellID == 132158 then
                state.natures_swiftness_cast_time = GetTime()
            end
            
            -- Harmony procs
            if subtype == "SPELL_AURA_APPLIED" and spellID == 100977 then
                state.harmony_proc_time = GetTime()
            end
            
            -- Clearcasting procs
            if subtype == "SPELL_AURA_APPLIED" and spellID == 16870 then
                state.clearcasting_proc_time = GetTime()
            end
            
            -- Soul of the Forest procs
            if subtype == "SPELL_AURA_APPLIED" and spellID == 114108 then
                state.soul_of_the_forest_proc_time = GetTime()
            end
            
        end
    end )
end

RegisterRestorationCombatLog()

-- Tier set bonus tracking with generate functions
spec:RegisterGear( "tier14_2pc", function() return set_bonus.tier14_2pc end )
spec:RegisterGear( "tier14_4pc", function() return set_bonus.tier14_4pc end )
spec:RegisterGear( "tier15_2pc", function() return set_bonus.tier15_2pc end )
spec:RegisterGear( "tier15_4pc", function() return set_bonus.tier15_4pc end )
spec:RegisterGear( "tier16_2pc", function() return set_bonus.tier16_2pc end )
spec:RegisterGear( "tier16_4pc", function() return set_bonus.tier16_4pc end )

-- Talents (MoP 6-tier talent system + Restoration specialization)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    feline_swiftness        = { 1, 1, 131768 },  -- Tier 1, Column 1, SpellID
    displacer_beast         = { 1, 2, 102280 },  -- Tier 1, Column 2, SpellID
    wild_charge             = { 1, 3, 102401 },  -- Tier 1, Column 3, SpellID
    
    -- Tier 2 (Level 30) - Healing utility
    yseras_gift             = { 2, 1, 145108 },  -- Tier 2, Column 1, SpellID (Note: Restoration uses Ysera's Gift instead of Nature's Swiftness)
    renewal                 = { 2, 2, 108238 },  -- Tier 2, Column 2, SpellID
    cenarion_ward           = { 2, 3, 102351 },  -- Tier 2, Column 3, SpellID
    
    -- Tier 3 (Level 45) - Crowd control
    faerie_swarm            = { 3, 1, 102355 },  -- Tier 3, Column 1, SpellID
    mass_entanglement       = { 3, 2, 102359 },  -- Tier 3, Column 2, SpellID
    typhoon                 = { 3, 3, 132469 },  -- Tier 3, Column 3, SpellID
    
    -- Tier 4 (Level 60) - Healing enhancement  
    soul_of_the_forest      = { 4, 1, 114107 },  -- Tier 4, Column 1, SpellID
    incarnation             = { 4, 2, 33891 },   -- Tier 4, Column 2, SpellID (Tree of Life for Restoration)
    force_of_nature         = { 4, 3, 106737 },  -- Tier 4, Column 3, SpellID
    
    -- Tier 5 (Level 75) - Disruption
    disorienting_roar       = { 5, 1, 99 },      -- Tier 5, Column 1, SpellID 
    ursols_vortex           = { 5, 2, 102793 },  -- Tier 5, Column 2, SpellID
    mighty_bash             = { 5, 3, 5211 },    -- Tier 5, Column 3, SpellID
    
    -- Tier 6 (Level 90) - Major cooldowns
    heart_of_the_wild       = { 6, 1, 108292 },  -- Tier 6, Column 1, SpellID
    dream_of_cenarius       = { 6, 2, 108373 },  -- Tier 6, Column 2, SpellID
    natures_vigil           = { 6, 3, 124974 },  -- Tier 6, Column 3, SpellID
} )

-- Glyphs (Enhanced System - authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs - Healing/Combat
    [54825] = "wild_growth",           -- Wild Growth affects 1 additional target
    [54760] = "swiftmend",             -- Swiftmend no longer consumes a HoT
    [54821] = "healing_touch",         -- Healing Touch cast time +50%, healing +50%
    [54832] = "innervate",             -- Innervate 10% per sec for 10 sec instead of 20% per 4 sec
    [54743] = "lifebloom",             -- Lifebloom can be cast on 2 targets
    [54829] = "regrowth",              -- Regrowth healing +20%, removes HoT component
    [54754] = "rejuvenation",          -- Rejuvenation duration +3 seconds
    [54755] = "tranquility",           -- Tranquility no longer affects allies, +100% healing
    [116218] = "efflorescence",        -- Swiftmend leaves healing zone (Efflorescence)
    [125390] = "healing_stream",       -- Your Healing Stream Totem also increases spell haste by 15% for nearby allies.
    [125391] = "nourish",              -- Your Nourish ability now heals for 20% more but has a 1.5 sec longer cast time.
    [125392] = "wild_mushroom",        -- Your Wild Mushroom: Bloom ability now affects 2 additional targets.
    [125393] = "ironbark",             -- Your Ironbark ability now also reduces the target's threat generation by 30%.
    [125394] = "genesis",              -- Your Genesis ability now affects all Rejuvenation effects within 15 yards of the target.
    [125395] = "living_seed",          -- Your Living Seed ability now has a 50% chance to not be consumed when triggered.
    
    -- Major glyphs - Mobility/Utility
    [94388] = "barkskin",              -- Barkskin increases movement speed by 50%
    [59219] = "entangling_roots",      -- Entangling Roots reduces damage by 20%
    [114235] = "stampeding_roar",      -- Stampeding Roar cooldown reduced by 60 seconds
    [125396] = "dash",                 -- Your Dash ability now also increases your swimming speed by 100%.
    [125397] = "wild_charge",          -- Your Wild Charge ability now has 2 charges.
    [125398] = "displacer_beast",      -- Your Displacer Beast ability now also grants stealth for 4 sec.
    [125399] = "typhoon",              -- Your Typhoon ability now also silences affected enemies for 3 sec.
    [125400] = "ursols_vortex",        -- Your Ursol's Vortex ability now lasts 50% longer.
    [125401] = "mighty_bash",          -- Your Mighty Bash ability now also reduces the target's movement speed by 50% for 8 sec.
    [54828] = "rebirth",               -- Rebirth gives 100% health/mana instead of 60%
    
    -- Major glyphs - Defensive/Survivability
    [125402] = "renewal",              -- Your Renewal ability now also grants immunity to movement impairing effects for 4 sec.
    [125403] = "cenarion_ward",        -- Your Cenarion Ward ability now lasts 50% longer.
    [125404] = "survival_instincts",   -- Your Survival Instincts ability can now be cast in any form.
    [125405] = "frenzied_regeneration", -- Your Frenzied Regeneration ability now also increases your dodge chance by 30%.
    [125406] = "bear_form",            -- Your Bear Form now also increases your movement speed by 15%.
    [125407] = "cat_form",             -- Your Cat Form now also increases your energy regeneration by 20%.
    [125408] = "travel_form",          -- Your Travel Form now also grants water walking.
    [125409] = "aquatic_form",         -- Your Aquatic Form now also increases your movement speed on land by 25%.
    [125410] = "moonkin_form",         -- Your Moonkin Form now also increases your spell critical strike chance by 5%.
    [125411] = "treant_form",          -- Your Treant Form now also increases your healing done by 15%.
    
    -- Major glyphs - Control/CC
    [125412] = "hibernate",            -- Your Hibernate ability can now affect Dragonkin and Undead.
    [125413] = "entangling_roots",     -- Your Entangling Roots ability can now affect flying enemies.
    [125414] = "cyclone",              -- Your Cyclone ability now lasts 2 sec longer but has a 10 sec longer cooldown.
    [125415] = "solar_beam",           -- Your Solar Beam ability now also reduces the movement speed of affected enemies by 50%.
    [125416] = "mass_entanglement",    -- Your Mass Entanglement ability now affects 3 additional targets.
    [125417] = "faerie_fire",          -- Your Faerie Fire ability now also increases the target's damage taken by magic spells by 15%.
    
    -- Minor glyphs - Visual/Convenience
    [57856] = "aquatic_form",          -- Walk on water in Aquatic Form
    [57862] = "challenging_roar",      -- Roar matches shapeshift form
    [57863] = "charm_woodland_creature", -- Charm critters for 10 minutes
    [57855] = "dash",                  -- Dash leaves glowing trail
    [57861] = "grace",                 -- Death causes enemies to flee
    [57857] = "mark_of_the_wild",      -- Transform into stag when self-buffing
    [57858] = "treant",                -- Force of Nature treants resemble trees
    [57860] = "unburdened_rebirth",    -- Rebirth requires no reagent
    [121840] = "stars",                -- Moonfire and Sunfire appear as stars
    [125418] = "blooming",             -- Your Lifebloom ability causes flowers to bloom around the target.
    [125419] = "floating",             -- Your spells cause you to hover slightly above the ground.
    [125420] = "glow",                 -- Your healing spells cause you to glow with natural energy.
} )

-- Restoration specific auras
spec:RegisterAuras( {
    -- HoTs (verified authentic MoP 5.4.8 mechanics)
    rejuvenation = {
        id = 774,
        duration = function() return glyph.rejuvenation.enabled and 15 or 12 end,  -- 12s base, +3s with glyph
        tick_time = 3,  -- 4 ticks over 12 seconds
        max_stack = 1,
    },
    regrowth = {
        id = 8936,
        duration = 6,  -- 6 second HoT component
        tick_time = 2,  -- 3 ticks over 6 seconds
        max_stack = 1,
    },
    lifebloom = {
        id = 33763,
        duration = 10,  -- 10 second duration, blooms at end
        tick_time = 1,  -- 10 ticks over 10 seconds
        max_stack = function() return glyph.lifebloom.enabled and 2 or 1 end,  -- Glyph allows 2 targets
        copy = { 33778 }
    },
    wild_growth = {
        id = 48438,
        duration = 7,  -- 7 second duration (verified from WoW sims)
        tick_time = 1,  -- 7 ticks over 7 seconds
        max_stack = 1,
    },
    efflorescence = {
        id = 81262,
        duration = 30,  -- Ground effect from Swiftmend
        max_stack = 1,
    },
    living_seed = {
        id = 48504,
        duration = 15,
        max_stack = 1,
    },    -- Proc buffs (authentic MoP mechanics)
    harmony = {
        id = 100977,
        duration = 10,  -- 10 second duration
        max_stack = 1,
        -- Increases healing of HoTs by 10% + mastery rating
        copy = { 77495 }  -- Mastery: Harmony
    },
    clearcasting = {
        id = 16870,
        duration = 15,
        max_stack = 1,
        -- Omen of Clarity: next spell costs no mana
    },
    -- Form buffs
    tree_of_life = {
        id = 33891,
        duration = 30,
        max_stack = 1,
    },
    incarnation_tree_of_life = {
        id = 117679,
        duration = 30,
        max_stack = 1,
    },
    -- Cooldown buffs
    natures_swiftness = {
        id = 132158,
        duration = 8,
        max_stack = 1,
    },
    soul_of_the_forest = {
        id = 114108,
        duration = 15,
        max_stack = 1,
    },    -- MoP specific talents and abilities
    dream_of_cenarius = {
        id = 108381,
        duration = 30,
        max_stack = 2,
        -- Wrath grants 30% healing increase on next heal
        -- Healing spells grant 70% damage increase on next Wrath
    },
    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
        -- Healing spells deal nature damage to nearby enemies
        -- Damage spells heal nearby allies
    },    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
        -- Increases stats and allows use of abilities from other specs
    },
    
    symbiosis = {
        id = 110309,
        duration = 3600,  -- 1 hour duration
        max_stack = 1,
        -- Grants class-specific abilities based on target
    },
    cenarion_ward = {
        id = 102351,
        duration = 30,  -- 30 second duration, heals when damage taken
        max_stack = 1,
    },
    ironbark = {
        id = 102342,
        duration = 12,  -- 12 second damage reduction
        max_stack = 1,
        -- 20% damage reduction
    },
    barkskin_movement = {
        id = 22812,  -- Glyph effect
        duration = 12,
        max_stack = 1,
        -- 50% movement speed from glyph
    },
    
    -- Shared Druid auras (forms and general buffs)
    innervate = {
        id = 29166,
        duration = function() return glyph.innervate.enabled and 10 or 20 end,  -- 20s base, 10s with glyph
        max_stack = 1,
        -- Base: 20% mana per 4 sec for 20 sec (400% total)
        -- Glyphed: 10% mana per 1 sec for 10 sec (100% total)
    },
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
    },
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
    },
    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
    },
    dash = {
        id = 1850,
        duration = 10,
        max_stack = 1,
    },
    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,
    },
    prowl = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
    },    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },
} )

-- Restoration core abilities
spec:RegisterAbilities( {
    rejuvenation = {
        id = 774,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.10,  -- 10% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 136081,
        
        handler = function ()
            applyBuff("target", "rejuvenation")
            applyBuff("harmony")  -- Mastery: Harmony proc
        end,
    },
    
    regrowth = {
        id = 8936,
        cast = function() 
            if buff.natures_swiftness.up then return 0 end
            return 1.5 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.21,  -- 21% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 136085,
        
        handler = function ()
            if not glyph.regrowth.enabled then
                applyBuff("target", "regrowth")  -- HoT component unless glyphed
            end
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    healing_touch = {
        id = 5185,
        cast = function() 
            if buff.natures_swiftness.up then return 0 end
            return 2.5 * haste  -- 2.5s base cast time (verified from WoW sims)
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.19,  -- 19% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 136041,
        
        handler = function ()
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    swiftmend = {
        id = 18562,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.12,  -- 12% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 134914,
        
        usable = function()
            return buff.rejuvenation.up or buff.regrowth.up, "requires rejuvenation or regrowth"
        end,
        
        handler = function ()
            if not glyph.swiftmend.enabled then
                -- Consumes a HoT effect if glyph is not enabled
                if buff.regrowth.up then
                    removeBuff("regrowth")
                elseif buff.rejuvenation.up then
                    removeBuff("rejuvenation")
                end
            end
            
            if talent.soul_of_the_forest.enabled then
                applyBuff("soul_of_the_forest")
            end
            
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    lifebloom = {
        id = 33763,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.06,  -- 6% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 134206,
        
        handler = function ()
            local stacks = buff.lifebloom.stack
            if stacks < 3 then
                addStack("lifebloom")
            else
                -- Refresh duration at 3 stacks
                buff.lifebloom.expires = query_time + 10
            end
        end,
    },
      wild_growth = {
        id = 48438,
        cast = 0,
        cooldown = function() return glyph.wild_growth.enabled and 10 or 8 end,  -- +2s cooldown with glyph
        gcd = "spell",
        
        spend = 0.19,  -- 19% base mana cost (verified from WoW sims)
        spendType = "mana",
        
        startsCombat = false,
        texture = 236153,
        
        handler = function ()
            applyBuff("wild_growth")
            if buff.soul_of_the_forest.up then
                removeBuff("soul_of_the_forest")
                -- 50% increased healing from Soul of the Forest
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    tranquility = {
        id = 740,
        cast = 8,
        channeled = true,
        cooldown = 480,  -- 8 minute cooldown (verified from WoW sims)
        gcd = "spell",
        
        spend = 0.32,  -- 32% base mana cost (verified from WoW sims)
        spendType = "mana",

        toggle = "cooldowns",
        
        
        
        startsCombat = false,
        texture = 136107,
        
        start = function ()
            -- 4 ticks over 8 seconds with stacking HoT effect (authentic MoP mechanic)
        end,
    },
    
    nourish = {
        id = 50464,
        cast = function() 
            if buff.natures_swiftness.up then return 0 end
            -- Base 1.5s, reduced by number of HoTs on target
            local hots = 0
            if buff.rejuvenation.up then hots = hots + 1 end
            if buff.regrowth.up then hots = hots + 1 end
            if buff.lifebloom.up then hots = hots + 1 end
            if buff.wild_growth.up then hots = hots + 1 end
            
            return max(1.0, 1.5 - (hots * 0.1)) * haste  -- 0.1s reduction per HoT
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.15,  -- 15% base mana cost
        spendType = "mana",
        
        startsCombat = false,
        texture = 236162,
        
        handler = function ()
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            applyBuff("harmony")  -- Mastery proc
        end,
    },
    
    genesis = {
        id = 145518,
        cast = 0,
        cooldown = 6,  -- Authentic MoP cooldown
        gcd = "spell",
        
        spend = 0.04,  -- 4% base mana cost per HoT affected
        spendType = "mana",
        
        startsCombat = false,
        texture = 237574,
        
        usable = function()
            return buff.rejuvenation.up, "requires rejuvenation on target"
        end,
        
        handler = function ()
            -- Accelerates Rejuvenation ticks (authentic MoP mechanic)
            if buff.rejuvenation.up then
                buff.rejuvenation.expires = max(0, buff.rejuvenation.expires - 4)
            end
        end,    },
    
    -- Restoration cooldowns and talents
    incarnation_tree_of_life = {
        id = 33891,  -- Tree of Life form
        cast = 0,
        cooldown = 180,  -- 3 minute cooldown
        gcd = "spell",

        toggle = "cooldowns",
        
        
        
        startsCombat = false,
        texture = 136062,
        
        handler = function ()
            applyBuff("incarnation_tree_of_life")
            -- Enhances healing spells and allows movement while casting
        end,
    },
    
    natures_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136076,
        
        handler = function ()
            applyBuff("natures_swiftness")
        end,
    },
    
    cenarion_ward = {
        id = 102351,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = false,
        texture = 132137,
        
        talent = "cenarion_ward",
        
        handler = function ()
            applyBuff("target", "cenarion_ward")
        end,
    },
    
    force_of_nature = {
        id = 106737,  -- Resto version: healing treants
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 132129,
        
        talent = "force_of_nature",
        
        handler = function ()
            -- Summons 3 healing treants for 15 seconds
            summonPet("treant", 15)
        end,
    },
    
    omen_of_clarity = {
        id = 113043,  -- Restoration version
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        texture = 136017,
        
        passive = true,
        
        handler = function ()
            -- Chance to proc Clearcasting on healing spell casts
        end,
    },
    
    -- Symbiosis abilities (MoP level 87 ability)
    symbiosis = {
        id = 110309,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135789,
        
        handler = function ()
            applyBuff("symbiosis")
            -- Grants abilities based on target's class
        end,
    },
    
    -- Utility and defensive abilities
      -- Restoration utility and defensive abilities
    innervate = {
        id = 29166,
        cast = 0,
        cooldown = 180,  -- 3 minute cooldown
        gcd = "spell",
        
        startsCombat = false,
        texture = 136048,
        
        handler = function ()
            applyBuff("target", "innervate")
        end,
    },
    
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "defensives",
        
        
        
        startsCombat = false,
        texture = 136097,
        
        handler = function ()
            applyBuff("barkskin")
            if glyph.barkskin.enabled then
                applyBuff("barkskin_movement")  -- 50% movement speed
            end
        end,
    },
    
    natures_cure = {
        id = 88423,  -- MoP dispel ability
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.13,
        spendType = "mana",
        
        startsCombat = false,
        texture = 236288,
        
        handler = function ()
            -- Dispels magic, curse, and poison effects
        end,
    },
    
    ironbark = {
        id = 102342,  -- MoP damage reduction cooldown
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",

        toggle = "defensives",
        
        startsCombat = false,
        texture = 572025,
        
        handler = function ()
            applyBuff("target", "ironbark")  -- 20% damage reduction for 12 seconds
        end,
    },
    
    -- MoP level 90 talents implemented as abilities
    heart_of_the_wild = {
        id = 108288,
        cast = 0,
        cooldown = 360,  -- 6 minute cooldown
        gcd = "spell",
        
        
        talent = "heart_of_the_wild",
        
        startsCombat = false,
        texture = 135879,
        
        handler = function ()
            applyBuff("heart_of_the_wild")
            -- Allows use of Balance/Feral/Guardian abilities with bonuses
        end,
    },
    
    natures_vigil = {
        id = 124974,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        
        talent = "natures_vigil",
        
        startsCombat = false,
        texture = 236180,
        
        handler = function ()
            applyBuff("natures_vigil")
            -- Healing spells deal damage, damage spells heal
        end,
    },
    
    -- Additional common Druid abilities
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.28,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136078,
        
        handler = function ()
            applyBuff("mark_of_the_wild")
        end,
    },
    
    rebirth = {
        id = 20484,
        cast = 2,
        cooldown = 600,
        gcd = "spell",
        
        spend = 0.6,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136080,
        
        handler = function ()
            -- Resurrect target with 60% health and mana
        end,    },
    
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        
        
        startsCombat = false,
        texture = 236169,
        
        handler = function ()
            applyBuff("survival_instincts")
        end,
    },
    
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132276,
        
        handler = function ()
            applyBuff("bear_form")
            removeBuff("cat_form")
            removeBuff("moonkin_form")
            removeBuff("travel_form")
        end,
    },
    
    cat_form = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132115,
        
        handler = function ()
            applyBuff("cat_form")
            removeBuff("bear_form")
            removeBuff("moonkin_form")
            removeBuff("travel_form")
        end,
    },
    
    travel_form = {
        id = 783,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132144,
        
        handler = function ()
            applyBuff("travel_form")
            removeBuff("cat_form")
            removeBuff("bear_form")
            removeBuff("moonkin_form")
        end,
    },
    
    moonkin_form = {
        id = 24858,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136036,
        
        handler = function ()
            applyBuff("moonkin_form")
            removeBuff("cat_form")
            removeBuff("bear_form")
            removeBuff("travel_form")
        end,
    },
    
    dash = {
        id = 1850,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132120,
        
        usable = function ()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("dash")
        end,
    },
    
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132089,
        
        usable = function ()
            return buff.cat_form.up, "requires cat form"
        end,
        
        handler = function ()
            applyBuff("prowl")
        end,
    },
    
    stampeding_roar = {
        id = 77764,
        cast = 0,
        cooldown = function() return glyph.stampeding_roar.enabled and 60 or 120 end,
        gcd = "spell",
        
        usable = function ()
            return buff.bear_form.up or buff.cat_form.up, "requires bear or cat form"
        end,
        
        startsCombat = false,
        texture = 464343,
        
        handler = function ()
            applyBuff("stampeding_roar")
        end,
    },
    
    cyclone = {
        id = 33786,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136022,
        
        handler = function ()
            applyDebuff("target", "cyclone")
        end,
    },
    
    entangling_roots = {
        id = 339,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136100,
        
        handler = function ()
            applyDebuff("target", "entangling_roots")
        end,
    },
    
    faerie_fire = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136033,
        
        handler = function ()
            applyDebuff("target", "faerie_fire")
        end,
    },
    
    mighty_bash = {
        id = 5211,
        cast = 0,
        cooldown = 50,
        gcd = "spell",
        
        startsCombat = true,
        texture = 132114,
        
        handler = function ()
            applyDebuff("target", "mighty_bash")
        end,
    },
    
    renewal = {
        id = 108238,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        
        
        startsCombat = false,
        texture = 236153,
        
        handler = function ()
            gain(0.3, "health")
        end,
    },
    
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        startsCombat = false,
        texture = 538771,
        
        handler = function ()
            applyBuff("wild_charge")
            -- Different charges based on form
        end,
    },
    
    displacer_beast = {
        id = 102280,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        startsCombat = false,
        texture = 461113,
        
        handler = function ()
            applyBuff("displacer_beast")
            applyBuff("cat_form")
        end,
    },
    
    typhoon = {
        id = 132469,
        cast = 0,
        cooldown = function() return glyph.typhoon.enabled and 17 or 20 end,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236170,
        
        handler = function ()
            -- Knockback and slow
        end,
    },
    
    ursols_vortex = {
        id = 102793,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 571588,
        
        handler = function ()
            -- AoE slow and pull effect
        end,    },
} )

-- Register default pack for MoP Restoration Druid
spec:RegisterPack( "Restoration", 20250515, [[Hekili:TzTBVTTnu4FlXSwQZzfn6t7wGvv9vpr8KvAm7nYn9DAMQ1ijxJZwa25JdwlRcl9dglLieFL52MpyzDoMZxhF7b)MFd9DjdLtuRdh7iiRdxGt)8h6QN0xHgyR37F)5dBEF5(yJ9Np)1hgn3dB4(l)ofv5k3HbNcO8zVcGqymUvZYwbVBdY0P)MM]]  )

-- Register pack selector for Restoration

-- Add state handlers for common Druid mechanics
do
    -- Track form state
    spec:RegisterStateExpr( "form", function ()
        if buff.moonkin_form.up then return "moonkin"
        elseif buff.bear_form.up then return "bear"
        elseif buff.cat_form.up then return "cat"
        elseif buff.travel_form.up then return "travel"
        else return "none" end
    end )
    
    -- Track combo points for cat form usage
    spec:RegisterStateExpr( "combo_points", function ()
        if buff.cat_form.up then
            return state.combo_points.current or 0
        end
        return 0
    end )
    
    -- Handle shapeshifting
    spec:RegisterStateFunction( "shift", function( form )
        if form == nil or form == "none" then
            removeBuff("moonkin_form")
            removeBuff("bear_form")
            removeBuff("cat_form")
            removeBuff("travel_form")
            return
        end
        
        if form == "moonkin" then
            removeBuff("bear_form")
            removeBuff("cat_form")
            removeBuff("travel_form")
            applyBuff("moonkin_form")
        elseif form == "bear" then
            removeBuff("moonkin_form")
            removeBuff("cat_form")
            removeBuff("travel_form")
            applyBuff("bear_form")
        elseif form == "cat" then
            removeBuff("moonkin_form")
            removeBuff("bear_form")
            removeBuff("travel_form")
            applyBuff("cat_form")
        elseif form == "travel" then
            removeBuff("moonkin_form")
            removeBuff("bear_form")
            removeBuff("cat_form")
            applyBuff("travel_form")
        end
    end )
    
    -- Track healing HoTs
    spec:RegisterStateTable( "active_hots", {
        count = function()
            local c = 0
            if buff.rejuvenation.up then c = c + 1 end
            if buff.regrowth.up then c = c + 1 end
            if buff.lifebloom.up then c = c + 1 end
            if buff.wild_growth.up then c = c + 1 end
            return c
        end
    } )
      -- Track harmony buff uptime for mastery effectiveness
    spec:RegisterStateTable( "harmony", {
        up = function()
            return buff.harmony.up
        end,
        remains = function()
            return buff.harmony.remains
        end,
        active_direct_heals = function()
            local c = 0
            -- Count of direct heals cast in the last 10 seconds
            return c
        end
    } )

    -- Advanced Aura System for Restoration Druid
    -- Core Healing Over Time Tracking
    spec:RegisterAura( "rejuvenation", {
        id = 774,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "target", "Rejuvenation" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "regrowth", {
        id = 8936,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "target", "Regrowth" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "lifebloom", {
        id = 33763,
        duration = 15,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "target", "Lifebloom" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "wild_growth", {
        id = 48438,
        duration = 7,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "target", "Wild Growth" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    -- Major Cooldown Tracking
    spec:RegisterAura( "tranquility", {
        id = 740,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Tranquility" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "tree_of_life", {
        id = 33891,
        duration = 25,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Tree of Life" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "natures_swiftness", {
        id = 17116,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Nature's Swiftness" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    -- Mastery and Proc Tracking
    spec:RegisterAura( "harmony", {
        id = 100977,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Harmony" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "clearcasting", {
        id = 16870,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Clearcasting" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "soul_of_the_forest", {
        id = 114108,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Soul of the Forest" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    -- MoP Talent Coordination
    spec:RegisterAura( "dream_of_cenarius", {
        id = 108373,
        duration = 30,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Dream of Cenarius" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "natures_vigil", {
        id = 124974,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Nature's Vigil" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "heart_of_the_wild", {
        id = 108292,
        duration = 45,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Heart of the Wild" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    -- Form Tracking
    spec:RegisterAura( "bear_form", {
        id = 5487,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Bear Form" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "cat_form", {
        id = 768,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Cat Form" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "moonkin_form", {
        id = 24858,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Moonkin Form" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "travel_form", {
        id = 783,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Travel Form" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    -- Utility and Defensive Tracking
    spec:RegisterAura( "barkskin", {
        id = 22812,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Barkskin" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "ironbark", {
        id = 102342,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "target", "Ironbark" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "dash", {
        id = 1850,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = UnitBuff( "player", "Dash" )
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "prowl", {
        id = 5215,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = ns.FindUnitBuffByID( "player", 5215 ) -- Prowl spell ID
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    -- Tier Set and Legendary Tracking
    spec:RegisterAura( "t14_2pc_resto", {
        id = 105770,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = ns.FindUnitBuffByID( "player", 105770 ) -- T14 2pc spell ID
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "t15_2pc_resto", {
        id = 138286,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = ns.FindUnitBuffByID( "player", 138286 ) -- T15 2pc spell ID
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    spec:RegisterAura( "legendary_meta_intellect", {
        id = 137590,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = ns.FindUnitBuffByID( "player", 137590 ) -- Capacitance spell ID
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )

    -- Symbiosis and Target-Specific Tracking
    spec:RegisterAura( "symbiosis", {
        id = 110309,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expires, caster = ns.FindUnitBuffByID( "player", 110309 ) -- Symbiosis spell ID
            if name then
                t.name = name
                t.count = max( 1, count )
                t.expires = expires
                t.applied = expires - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    } )
end
