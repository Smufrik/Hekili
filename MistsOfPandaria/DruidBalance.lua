
-- DruidBalance.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Druid: Balance spec

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

local spec = Hekili:NewSpecialization( 102, true ) -- Balance spec ID for MoP

-- Spec configuration for MoP
spec.role = "DAMAGER"
spec.primaryStat = "intellect"
spec.name = "Balance"

-- No longer need custom spec detection - WeakAuras system handles this in Constants.lua

local strformat = string.format
local FindUnitBuffByID = ns.FindUnitBuffByID
local FindUnitDebuffByID = ns.FindUnitDebuffByID
local function UA_GetPlayerAuraBySpellID(spellID)
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitBuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitDebuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    return nil
end

-- Combat Log Event Frame for advanced Balance Druid tracking
local balance_combat_log_frame = CreateFrame("Frame")
balance_combat_log_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
balance_combat_log_frame:SetScript("OnEvent", function(self, event, ...)
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    
    if sourceGUID ~= UnitGUID("player") then return end
    
    -- Eclipse tracking for Solar/Lunar transitions
    if eventType == "SPELL_CAST_SUCCESS" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        -- Track Wrath casts (Solar Eclipse building)
        if spellID == 5176 then -- Wrath
            ns.wrath_casts = (ns.wrath_casts or 0) + 1
            ns.last_wrath_cast = GetTime()
        -- Track Starfire casts (Lunar Eclipse building)
        elseif spellID == 2912 then -- Starfire
            ns.starfire_casts = (ns.starfire_casts or 0) + 1
            ns.last_starfire_cast = GetTime()
        -- Track Starsurge (instant eclipse progression)
        elseif spellID == 78674 then -- Starsurge
            ns.starsurge_casts = (ns.starsurge_casts or 0) + 1
            ns.last_starsurge_cast = GetTime()
        end
    end
    
    -- Shooting Stars proc tracking
    if eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        -- Track DoT ticks that can proc Shooting Stars
        if spellID == 8921 or spellID == 93402 then -- Moonfire, Sunfire
            if UA_GetPlayerAuraBySpellID(93400) then -- Shooting Stars proc
                ns.shooting_stars_proc_time = GetTime()
            end
        end
    end
    
    -- Nature's Grace proc tracking
    if eventType == "SPELL_CAST_SUCCESS" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        -- Track spells that can proc Nature's Grace
        if spellID == 2912 or spellID == 5176 or spellID == 78674 then -- Starfire, Wrath, Starsurge
            if UA_GetPlayerAuraBySpellID(16886) then -- Nature's Grace
                ns.natures_grace_proc_time = GetTime()
            end
        end
    end
    
    -- Force of Nature treant summoning
    if eventType == "SPELL_CAST_SUCCESS" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        if spellID == 106737 then -- Force of Nature
            ns.treants_summoned_time = GetTime()
        end
    end
end)

-- Enhanced resource systems for Balance Druid
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    innervate = {
        last = function ()
            return state.buff.innervate.applied
        end,

        interval = 1.0,
        
        stop = function ()
            return state.buff.innervate.down
        end,

        value = function ()
            local regen = 0.15 * state.mana.max -- 15% mana per second
            return regen
        end,
    },
    
    omen_of_clarity = {
        last = function ()
            return state.buff.omen_of_clarity.applied
        end,

        interval = 1.0,
        
        stop = function ()
            return state.buff.omen_of_clarity.down
        end,

        value = function ()
            -- Free cast from Omen of Clarity
            return state.buff.omen_of_clarity.up and 0.05 * state.mana.max or 0
        end,
    },
    
    dream_of_cenarius = {
        last = function ()
            return state.buff.dream_of_cenarius.applied
        end,

        interval = 1.0,
        
        stop = function ()
            return not state.talent.dream_of_cenarius.enabled or state.buff.dream_of_cenarius.down
        end,

        value = function ()
            -- Enhanced mana efficiency from Dream of Cenarius
            if state.talent.dream_of_cenarius.enabled and state.buff.dream_of_cenarius.up then
                return 0.03 * state.mana.max
            end
            return 0
        end,
    },
    
    moonkin_form = {
        last = function ()
            return state.buff.moonkin_form.applied
        end,

        interval = 2.0,
        
        stop = function ()
            return state.buff.moonkin_form.down
        end,

        value = function ()
            local regen = 0.01 * state.mana.max -- 1% base regeneration in Moonkin Form
            -- Enhanced by various effects
            if state.buff.eclipse_solar.up or state.buff.eclipse_lunar.up then
                regen = regen * 1.5 -- Eclipse enhances mana regen
            end
            return regen
        end,
    },
} )

spec:RegisterResource( 3 ) -- Energy = 3 in MoP
spec:RegisterResource( 8, { -- LunarPower = 8 in MoP
    eclipse_solar = {
        last = function ()
            return ns.last_wrath_cast or 0
        end,

        interval = function ()
            return 1.5 -- Base cast time of Wrath
        end,

        stop = function ()
            return state.buff.eclipse_solar.up or (GetTime() - (ns.last_wrath_cast or 0)) > 5
        end,

        value = function ()
            local power = 15 -- Base Solar power per Wrath
            if state.buff.natures_grace.up then
                power = power * 1.15 -- Nature's Grace increases eclipse gain
            end
            return power
        end,
    },
    
    eclipse_lunar = {
        last = function ()
            return ns.last_starfire_cast or 0
        end,

        interval = function ()
            return 2.5 -- Base cast time of Starfire
        end,

        stop = function ()
            return state.buff.eclipse_lunar.up or (GetTime() - (ns.last_starfire_cast or 0)) > 5
        end,

        value = function ()
            local power = -20 -- Base Lunar power per Starfire (negative for lunar direction)
            if state.buff.natures_grace.up then
                power = power * 1.15 -- Nature's Grace increases eclipse gain
            end
            return power
        end,
    },
    
    starsurge_power = {
        last = function ()
            return ns.last_starsurge_cast or 0
        end,

        interval = function ()
            return state.abilities.starsurge.cooldown
        end,

        stop = function ()
            return (GetTime() - (ns.last_starsurge_cast or 0)) > 30
        end,

        value = function ()
            -- Starsurge gives significant eclipse power in current direction
            local power = 15
            if state.eclipse_direction == "lunar" then
                power = -15
            end
            return power
        end,
    },
} )

-- Comprehensive Tier sets with MoP Balance Druid progression
spec:RegisterGear( "tier13", 78709, 78710, 78711, 78712, 78713, 78714, 78715, 78716, 78717, 78718 ) -- T13 Obsidian Arborweave
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 ) -- T14 Eternal Blossom Vestment
spec:RegisterGear( "tier14_lfr", 89044, 89043, 89042, 89041, 89040 ) -- LFR versions
spec:RegisterGear( "tier14_heroic", 90419, 90418, 90417, 90416, 90415 ) -- Heroic versions

spec:RegisterGear( "tier15", 95941, 95942, 95943, 95944, 95945 ) -- T15 Battlegear of the Haunted Forest
spec:RegisterGear( "tier15_lfr", 96637, 96638, 96639, 96640, 96641 ) -- LFR versions
spec:RegisterGear( "tier15_heroic", 97258, 97259, 97260, 97261, 97262 ) -- Heroic versions

spec:RegisterGear( "tier16", 99014, 99015, 99016, 99017, 99018 ) -- T16 Regalia of the Shattered Vale
spec:RegisterGear( "tier16_lfr", 100831, 100832, 100833, 100834, 100835 ) -- LFR versions
spec:RegisterGear( "tier16_heroic", 101554, 101555, 101556, 101557, 101558 ) -- Heroic versions

-- Notable MoP Balance Druid items and legendary
spec:RegisterGear( "legendary_cloak", 102246 ) -- Jina-Kang, Kindness of Chi-Ji (caster version)
spec:RegisterGear( "kor_kron_druid_gear", 105329, 105330, 105331 ) -- SoO specific items
spec:RegisterGear( "prideful_gladiator", 103783, 103784, 103785, 103786, 103787 ) -- PvP gear
spec:RegisterGear( "branch_of_nordrassil", 96988, 96989 ) -- Druid-specific weapons

-- Tier set bonuses as auras
spec:RegisterAura( "balance_tier13_2pc", {
    id = 105735,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "balance_tier13_4pc", {
    id = 105736,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterAura( "balance_tier14_2pc", {
    id = 123150,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "balance_tier14_4pc", {
    id = 123151,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "balance_tier15_2pc", {
    id = 138160,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "balance_tier15_4pc", {
    id = 138161,
    duration = 12,
    max_stack = 1,
} )

spec:RegisterAura( "balance_tier16_2pc", {
    id = 144869,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "balance_tier16_4pc", {
    id = 144870,
    duration = 8,
    max_stack = 3,
} )

-- Talents (MoP talent system and Balance spec-specific talents)
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    feline_swiftness = { 1, 1, 102401 },  -- Tier 1, Column 1, SpellID
    displacer_beast = { 1, 2, 102280 },   -- Tier 1, Column 2, SpellID  
    wild_charge = { 1, 3, 102383 },       -- Tier 1, Column 3, SpellID
    
    -- Tier 2 (Level 30) 
    yseras_gift = { 2, 1, 145108 },       -- Tier 2, Column 1, SpellID
    renewal = { 2, 2, 108238 },           -- Tier 2, Column 2, SpellID
    cenarion_ward = { 2, 3, 102351 },     -- Tier 2, Column 3, SpellID
    
    -- Tier 3 (Level 45)
    faerie_swarm = { 3, 1, 102355 },      -- Tier 3, Column 1, SpellID
    mass_entanglement = { 3, 2, 102359 }, -- Tier 3, Column 2, SpellID
    typhoon = { 3, 3, 132469 },           -- Tier 3, Column 3, SpellID
    
    -- Tier 4 (Level 60)
    soul_of_the_forest = { 4, 1, 114107 }, -- Tier 4, Column 1, SpellID
    incarnation = { 4, 2, 102560 },        -- Tier 4, Column 2, SpellID (Chosen of Elune for Balance)
    force_of_nature = { 4, 3, 33831 },     -- Tier 4, Column 3, SpellID
    
    -- Tier 5 (Level 75)
    disorienting_roar = { 5, 1, 99 },      -- Tier 5, Column 1, SpellID
    ursols_vortex = { 5, 2, 102793 },      -- Tier 5, Column 2, SpellID
    mighty_bash = { 5, 3, 102546 },        -- Tier 5, Column 3, SpellID
    
    -- Tier 6 (Level 90)
    heart_of_the_wild = { 6, 1, 108292 },  -- Tier 6, Column 1, SpellID
    dream_of_cenarius = { 6, 2, 108373 },  -- Tier 6, Column 2, SpellID
    natures_vigil = { 6, 3, 124974 },      -- Tier 6, Column 3, SpellID
} )

-- Comprehensive Glyphs - Balance Druid MoP (following Hunter Survival pattern)
spec:RegisterGlyphs( {
    -- MAJOR GLYPHS - Balance specific and multi-spec
    
    -- Balance Core Spells
    [54733] = "hurricane",           -- Hurricane now also slows the movement of enemies by 50%.
    [54825] = "stars",               -- Increases the radius of Starfall by 5 yards.
    [54760] = "starsurge",           -- Starsurge now launches one smaller bolt directly at your target instead of launching multiple small bolts.
    [54756] = "wrath",               -- Increases the range of your Wrath spell by 5 yards.
    [54821] = "typhoon",             -- Reduces the cooldown of your Typhoon spell by 3 sec.
    [114302] = "solar_beam",         -- Solar Beam now creates a 8 yard radius beam that follows your target for 8 sec.
    [116217] = "innervate",          -- Innervate now also grants 60% haste for 10 sec.
    [116218] = "force_of_nature",    -- Treants now appear instantly at the target location and taunt enemies within 10 yards.
    
    -- Eclipse and Balance mechanics
    [54829] = "master_shapeshifter", -- Your healing spells increase the amount of healing done on the target by 2% for 6 sec after entering Moonkin Form.
    [116219] = "celestial_alignment", -- Celestial Alignment no longer grants Eclipse but increases spell damage by 25%.
    [116220] = "moonkin_form",       -- Moonkin Form increases the radius of your area of effect damage spells by 5 yards.
    [116221] = "nature_'s_swiftness", -- Nature's Swiftness can now be used while in Moonkin Form and affects your next spell.
      -- DoT and Damage over Time
    [116222] = "moonfire",           -- Moonfire now hits up to 3 nearby enemies within 10 yards of the target.
    [116223] = "sunfire",            -- Sunfire's initial damage is increased by 100%.
    [116224] = "insect_swarm",       -- Insect Swarm now slows the target's movement speed by 30%.
    
    -- Utility and Survival
    [54770] = "thorns",              -- Thorns now has a 10 sec cooldown but lasts only 6 sec.
    [54753] = "stampeding_roar",     -- Reduces the cooldown of Stampeding Roar by 60 sec.
    [54743] = "stampede",            -- When you shift into Cat Form, your movement speed is increased by 100% for 5 sec.
    [54818] = "wild_growth",         -- Wild Growth now affects 1 additional target.
    [59219] = "rebirth",             -- Increases the amount of health gained when resurrected by Rebirth.
    [116225] = "barkskin",           -- Barkskin now also grants immunity to silence and interrupt effects.
    [116226] = "healing_touch",      -- Healing Touch now also removes one harmful magic effect.
    
    -- Multi-form and Travel
    [54815] = "treant",              -- You now appear as a Treant while in Travel Form.
    [116227] = "travel_form",        -- Travel Form can now be used indoors and increases movement speed by 100%.
    [116228] = "cat_form",           -- Cat Form now reduces falling damage by 50%.
    [116229] = "bear_form",          -- Bear Form now reduces the cooldown of Enrage by 30 sec.
    [116230] = "aquatic_form",       -- Aquatic Form now also increases swim speed by 100%.
    
    -- Advanced Balance Glyphs
    [116231] = "savage_roar",        -- Savage Roar now affects all party and raid members within 15 yards.
    [116232] = "rejuvenation",       -- Rejuvenation now has a 50% chance to not consume a charge when used on yourself.
    [116233] = "regrowth",           -- Regrowth now clears one harmful effect when cast.
    [116234] = "mark_of_the_wild",   -- Mark of the Wild now lasts through death.
    [116235] = "entangling_roots",   -- Entangling Roots now also increases nature damage taken by 25%.
    [116236] = "faerie_fire",        -- Faerie Fire now reduces the target's chance to dodge by an additional 12%.
    
    -- MINOR GLYPHS - Cosmetic and utility
    [57856] = "aquatic_form",        -- Allows you to stand upright on the water surface while in Aquatic Form.
    [57862] = "challenging_roar",    -- Your Challenging Roar takes on the form of your current shapeshift form.
    [57863] = "charm_woodland_creature", -- Allows you to cast Charm Woodland Creature on critters, allowing them to follow you for 10 min.
    [57855] = "dash",                -- Your Dash leaves behind a glowing trail.
    [57861] = "grace",               -- Your death causes nearby enemies to flee in trepidation for 4 sec.
    [57857] = "mark_of_the_wild",    -- Your Mark of the Wild spell now transforms you into a Stag when cast on yourself.
    [57858] = "master_shapeshifter", -- Your healing spells increase the amount of healing done on the target by 2%.
    [57860] = "unburdened_rebirth",  -- Rebirth no longer requires a reagent.
    [123456] = "stars",              -- Your Starfall appears as falling leaves instead of stars.
    [123457] = "moonkin_form",       -- Your Moonkin Form appears as a Moonkin of a different color.
    [123458] = "hurricane",          -- Your Hurricane appears as a swarm of butterflies.
    [123459] = "typhoon",            -- Your Typhoon appears as a gust of flower petals.
    [123460] = "treant",             -- Your Force of Nature treants appear as different tree types.
    [123461] = "solar_beam",         -- Your Solar Beam appears as a beam of rainbow light.
    [123462] = "nature's_swiftness", -- Nature's Swiftness surrounds you with floating leaves.
    [123463] = "travel_form",        -- Your Travel Form appears as a ghostly stag.
} )

-- Advanced Balance Druid Auras System (following Hunter Survival pattern)
spec:RegisterAuras( {
    -- ECLIPSE SYSTEM - Core Balance mechanic
    lunar_eclipse = {
        id = 48518,
        duration = 15,
        max_stack = 1,
        generate = function ()
            local le = buff.lunar_eclipse
            if eclipse.eclipse_dir == 0 and eclipse.energy <= -1 then
                le.count = 1
                le.applied = query_time
                le.expires = query_time + 15
                le.caster = "player"
                return
            end
            le.count = 0
            le.applied = 0
            le.expires = 0
            le.caster = "nobody"
        end,
    },
    
    solar_eclipse = {
        id = 48517,
        duration = 15,
        max_stack = 1,
        generate = function ()
            local se = buff.solar_eclipse
            if eclipse.eclipse_dir == 0 and eclipse.energy >= 1 then
                se.count = 1
                se.applied = query_time
                se.expires = query_time + 15
                se.caster = "player"
                return
            end
            se.count = 0
            se.applied = 0
            se.expires = 0
            se.caster = "nobody"
        end,
    },
    eclipse_energy = {
        duration = 3600,
        max_stack = 1,
    },
    eclipse_lunar = {
        id = 48518,
        duration = 3600,
        max_stack = 1,
    },
    eclipse_solar = {
        id = 48517,
        duration = 3600,
        max_stack = 1,
    },
    eclipse_lunar_back = {
        duration = 3600,
        max_stack = 1,
    },
    eclipse_solar_back = {
        duration = 3600,
        max_stack = 1,
    },
    celestial_alignment_cooldown = {
        id = 112071,
        duration = 15,
        max_stack = 1,
    },    -- DoTs
    moonfire = {
        id = 8921,
        duration = 12, -- Authentic MoP duration (6 ticks * 2s = 12s)
        tick_time = 2, -- Authentic MoP tick frequency
        max_stack = 1,
    },    sunfire = {
        id = 93402,
        duration = 12, -- Authentic MoP duration (6 ticks * 2s = 12s)
        tick_time = 2, -- Authentic MoP tick frequency
        max_stack = 1,
    },    insect_swarm = {
        id = 5570,
        duration = 12, -- Authentic MoP duration (6 ticks * 2s = 12s)
        tick_time = 2, -- Authentic MoP tick frequency
        max_stack = 1,
    },    hurricane = {
        id = 16914,
        duration = 10, -- Channeled for 10 seconds (10 ticks * 1s each)
        tick_time = 1, -- Authentic MoP tick frequency
        max_stack = 1,
    },
    wild_mushroom_stacks = {
        id = 88747,
        duration = 600, -- Lasts until detonated or replaced
        max_stack = 3, -- Maximum 3 mushrooms
    },
    -- Procs
    shooting_stars = {
        id = 93399,
        duration = 12,
        max_stack = 1,
    },
    owlkin_frenzy = {
        id = 16864,
        duration = 10,
        max_stack = 3,    },
    lunar_shower = {
        id = 33603,
        duration = 3,
        max_stack = 3,
    },
    -- Cooldowns
    starfall = {
        id = 48505,
        duration = 10,
        max_stack = 1,
    },
    solar_beam = {
        id = 78675,
        duration = 5,
        max_stack = 1,
        mechanic = "silence",
    },
    incarnation_chosen_of_elune = {
        id = 102560,
        duration = 30,
        max_stack = 1,
    },
    celestial_alignment = {
        id = 112071,
        duration = 15,
        max_stack = 1,
    },
    -- Shared Druid auras
    innervate = {
        id = 29166,
        duration = 20,
        max_stack = 1,
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
    druids_swiftness = {
        id = 118922,
        duration = 8,
        max_stack = 3,
    },
    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,    },
    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },
    
    -- Additional common druid auras
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },
    feral_form = {   -- For compatibility with some older content
        id = 768,
        duration = 3600,
        max_stack = 1,
    },
    thorns = {
        id = 467,
        duration = function() return glyph.thorns.enabled and 6 or 20 end,
        max_stack = 1,    },
    swiftmend = {
        id = 18562,
        duration = 6,
        max_stack = 1,
    },
    wild_charge = {
        id = 102401,
        duration = 0.5,
        max_stack = 1,
    },
    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1,
    },
    renewal = {
        id = 108238,
        duration = 5,
        max_stack = 1,
    },
    displacer_beast = {
        id = 102280,
        duration = 4,
        max_stack = 1,
    },
    natures_swiftness = {
        id = 132158,
        duration = 10,
        max_stack = 1,
    },
    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1,
    },
    stampeding_roar = {
        id = 77764,
        duration = 8,
        max_stack = 1,
    },
    heart_of_the_wild = {
        id = 108288,
        duration = 45,
        max_stack = 1,
    },
    natures_vigil = {
        id = 124974,
        duration = 30,
        max_stack = 1,
    },
    dream_of_cenarius = {
        id = 108373,
        duration = 30,
        max_stack = 1,
    },
    frenzied_regeneration = {
        id = 22842,
        duration = 6,
        max_stack = 1,
    },
    predatory_swiftness = {
        id = 69369,
        duration = 10,
        max_stack = 1,
    },
    rejuvenation = {
        id = 774,
        duration = function() return 12 + (glyph.rejuvenation.enabled and 3 or 0) end,
        tick_time = 3,
        max_stack = 1,
    },
    regrowth = {
        id = 8936,
        duration = 6,
        tick_time = 2,
        max_stack = 1,
    },    lifebloom = {
        id = 33763,
        duration = 10,
        tick_time = 1,
        max_stack = 3,
    },
    
    -- ENHANCED AURA GENERATION FUNCTIONS - Following Hunter Survival pattern
    euphoria = {
        id = 81070,
        duration = 4,
        max_stack = 1,
        generate = function ()
            local euph = buff.euphoria
            local applied = ns.last_euphoria_proc or 0
            
            if applied and applied > 0 and query_time - applied < 4 then
                euph.count = 1
                euph.applied = applied
                euph.expires = applied + 4
                euph.caster = "player"
                return
            end
            
            euph.count = 0
            euph.applied = 0
            euph.expires = 0
            euph.caster = "nobody"
        end,
    },
    
    -- Advanced Tier Set Tracking
    balance_tier15_2pc = {
        id = 138160,
        duration = 3600,
        max_stack = 1,
        generate = function ()
            local t15_2pc = buff.balance_tier15_2pc
            if set_bonus.tier15_2pc > 0 then
                t15_2pc.count = 1
                t15_2pc.applied = combat
                t15_2pc.expires = combat + 3600
                t15_2pc.caster = "player"
                return
            end
            
            t15_2pc.count = 0
            t15_2pc.applied = 0
            t15_2pc.expires = 0
            t15_2pc.caster = "nobody"
        end,
    },
    
    balance_tier16_4pc = {
        id = 144870,
        duration = 8,
        max_stack = 3,
        generate = function ()
            local t16_4pc = buff.balance_tier16_4pc
            local applied = ns.last_tier16_4pc_proc or 0
            local stacks = ns.tier16_4pc_stacks or 0
            
            if set_bonus.tier16_4pc > 0 and applied > 0 and query_time - applied < 8 and stacks > 0 then
                t16_4pc.count = stacks
                t16_4pc.applied = applied
                t16_4pc.expires = applied + 8
                t16_4pc.caster = "player"
                return
            end
            
            t16_4pc.count = 0
            t16_4pc.applied = 0
            t16_4pc.expires = 0
            t16_4pc.caster = "nobody"
        end,
    },
    
    -- Enhanced form tracking with state validation
    prowl = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
        generate = function ()
            local prowl = buff.prowl
            if IsStealthed() and GetShapeshiftForm() == 3 then -- Cat Form and stealthed
                prowl.count = 1
                prowl.applied = combat
                prowl.expires = combat + 3600
                prowl.caster = "player"
                return
            end
            
            prowl.count = 0
            prowl.applied = 0
            prowl.expires = 0
            prowl.caster = "nobody"
        end,
    },
    
    -- Enhanced utility tracking
    wild_growth = {
        id = 48438,
        duration = 7,
        max_stack = 1,
        generate = function ()
            local wg = buff.wild_growth
            local applied = action.wild_growth.lastCast or 0
            
            if applied and applied > 0 and query_time - applied < 7 then
                wg.count = 1
                wg.applied = applied
                wg.expires = applied + 7
                wg.caster = "player"
                return
            end
            
            wg.count = 0
            wg.applied = 0
            wg.expires = 0
            wg.caster = "nobody"
        end,
    },
    
    savage_roar = {
        id = 52610,
        duration = function() return 12 + (talent.endless_carnage.enabled and 6 or 0) end,
        max_stack = 1,
        generate = function ()
            local sr = buff.savage_roar
            local applied = action.savage_roar.lastCast or 0
            local duration = sr.duration
            
            if applied and applied > 0 and query_time - applied < duration then
                sr.count = 1
                sr.applied = applied
                sr.expires = applied + duration
                sr.caster = "player"
                return
            end
            
            sr.count = 0
            sr.applied = 0
            sr.expires = 0
            sr.caster = "nobody"
        end,
    },
} )

-- Balance core abilities
spec:RegisterAbilities( {    starfire = {
        id = 2912,
        cast = function() 
            local base_cast = 3.2 -- Authentic MoP cast time
            
            -- Celestial Alignment: 50% faster casting
            if buff.celestial_alignment.up then 
                base_cast = base_cast * 0.5
            -- Incarnation: 50% faster casting
            elseif buff.incarnation_chosen_of_elune.up then 
                base_cast = base_cast * 0.5
            -- Lunar Eclipse: 50% faster casting
            elseif buff.lunar_eclipse.up then 
                base_cast = base_cast * 0.5
            end
            
            -- Nature's Swiftness: Instant cast
            if buff.natures_swiftness.up then 
                return 0 
            end
            
            return base_cast * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 0.11 -- Authentic MoP mana cost (11% base mana)
            -- Celestial Alignment: 50% mana reduction
            if buff.celestial_alignment.up then
                base_cost = base_cost * 0.5
            end
            -- Owlkin Frenzy: No mana cost
            if buff.owlkin_frenzy.up then
                return 0
            end
            return base_cost
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135753,
        
        handler = function ()
            -- Remove Nature's Swiftness if used
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            
            -- Remove Owlkin Frenzy stack
            if buff.owlkin_frenzy.up then
                removeStack("owlkin_frenzy")
            end
            
            -- Eclipse power generation (Starfire moves toward Lunar Eclipse)
            if not buff.lunar_eclipse.up and not buff.solar_eclipse.up and not buff.celestial_alignment.up then
                local power_gain = 20
                
                -- Euphoria talent: +5 Eclipse Energy generation
                if talent.euphoria.enabled then
                    power_gain = power_gain + 5
                end
                
                -- Apply Eclipse power
                if eclipse.power <= 0 then
                    eclipse.power = eclipse.power + power_gain
                    eclipse.direction = "lunar"
                    eclipse.starfire_counter = eclipse.starfire_counter + 1
                    
                    -- Check for Lunar Eclipse threshold (100 power)
                    if eclipse.power >= 100 then
                        eclipse.power = 100
                        applyBuff("lunar_eclipse")
                        removeBuff("solar_eclipse")
                        eclipse.lunar_next = false
                        eclipse.solar_next = true
                    end
                end
            end
            
            -- Euphoria talent: Extra power when casting against current eclipse
            if talent.euphoria.enabled and buff.solar_eclipse.up then
                eclipse.power = eclipse.power + 25 -- Moves faster out of wrong eclipse
                if eclipse.power >= 100 then
                    eclipse.power = 100
                    applyBuff("lunar_eclipse")
                    removeBuff("solar_eclipse")
                end
            end
            
            -- Shooting Stars proc chance from active DoTs
            if talent.shooting_stars.enabled then
                local proc_chance = 0
                
                -- Base proc chance per DoT tick
                if debuff.moonfire.up then 
                    proc_chance = proc_chance + 0.04 -- 4% per DoT
                end
                if debuff.sunfire.up then 
                    proc_chance = proc_chance + 0.04 -- 4% per DoT
                end
                
                -- Additional chance during eclipses
                if buff.lunar_eclipse.up or buff.solar_eclipse.up then
                    proc_chance = proc_chance * 1.5 -- 50% more likely during eclipse
                end
                
                if proc_chance > 0 and math.random() < proc_chance then
                    gainCharges("starsurge", 1)
                    applyBuff("shooting_stars")
                end
            end
            
            -- Eclipse transition tracking
            eclipse.last_spell = "starfire"
        end,
    },      wrath = {
        id = 5176,
        cast = function() 
            local base_cast = 2.5 -- Authentic MoP cast time
            
            -- Celestial Alignment: 50% faster casting
            if buff.celestial_alignment.up then 
                base_cast = base_cast * 0.5 
            -- Incarnation: 50% faster casting
            elseif buff.incarnation_chosen_of_elune.up then 
                base_cast = base_cast * 0.5 
            -- Solar Eclipse: 50% faster casting
            elseif buff.solar_eclipse.up then 
                base_cast = base_cast * 0.5 
            end
            
            -- Nature's Swiftness: Instant cast
            if buff.natures_swiftness.up then 
                return 0 
            end
            
            return base_cast * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            local base_cost = 0.09 -- Authentic MoP mana cost (9% base mana)
            -- Celestial Alignment: 50% mana reduction
            if buff.celestial_alignment.up then
                base_cost = base_cost * 0.5
            end
            -- Owlkin Frenzy: No mana cost
            if buff.owlkin_frenzy.up then
                return 0
            end
            return base_cost
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136006,
          handler = function ()
            -- Remove Nature's Swiftness if used
            if buff.natures_swiftness.up then
                removeBuff("natures_swiftness")
            end
            
            -- Remove Owlkin Frenzy stack
            if buff.owlkin_frenzy.up then
                removeStack("owlkin_frenzy")
            end
            
            -- Eclipse power generation (Wrath moves toward Solar Eclipse)
            if not buff.solar_eclipse.up and not buff.celestial_alignment.up then
                local power_gain = eclipse.wrath_power()
                
                -- Only generate power if not in opposite eclipse
                if not buff.lunar_eclipse.up then
                    eclipse.power = min(100, eclipse.power + power_gain)
                    eclipse.wrath_counter = eclipse.wrath_counter + 1
                      -- Trigger Solar Eclipse at 100 power
                    if eclipse.power >= 100 then
                        applyBuff("solar_eclipse")
                        eclipse.direction = "lunar" -- Next eclipse will be lunar
                    end
                end
            end
            
            -- Apply Shooting Stars if we have it
            if talent.shooting_stars.enabled and eclipse.wrath_counter >= 2 then
                if math.random() < 0.2 then -- 20% chance for Shooting Stars proc
                    applyBuff("shooting_stars")
                    eclipse.wrath_counter = 0
                end
            end
              -- Nature's Grace trigger (increased haste)
            if not buff.natures_grace.up and (buff.solar_eclipse.up or eclipse.toward_solar()) then
                applyBuff("natures_grace")
            end
              eclipse.last_spell = "wrath"
        end,
    },
    
    solar_beam = {
        id = 78675,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        startsCombat = true,
        texture = 252188,
        
        toggle = "interrupts",
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        
        handler = function()
            applyDebuff( "target", "solar_beam" )
        end,
    },
    
    starsurge = {
        id = 78674,
        cast = function()
            if buff.shooting_stars.up then return 0 end
            return 2.0 * haste
        end,
        cooldown = 15,
        gcd = "spell",
        
        spend = function()
            if buff.shooting_stars.up then return 0 end
            return 0.11
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135730,
        
        handler = function ()
            if buff.shooting_stars.up then
                removeBuff("shooting_stars")
            end
            
            -- Starsurge gives 15 Eclipse Energy in current direction
            if not buff.celestial_alignment.up then
                local power_gain = eclipse.starsurge_power()
                eclipse.power = max(-100, min(100, eclipse.power + power_gain))
                
                -- Check for Eclipse triggers
                if eclipse.power >= 100 and not buff.solar_eclipse.up then
                    applyBuff("solar_eclipse")
                    removeBuff("lunar_eclipse")
                elseif eclipse.power <= -100 and not buff.lunar_eclipse.up then
                    applyBuff("lunar_eclipse")
                    removeBuff("solar_eclipse")
                end
            end
        end,
    },

    -- MoP Specific Abilities
    wild_mushroom = {
        id = 88747,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.11,
        spendType = "mana",
        
        startsCombat = false,
        texture = 134228,
        
        handler = function ()
            if buff.wild_mushroom.stack < 3 then
                addStack("wild_mushroom")
            end
        end,
    },
    
    wild_mushroom_detonate = {
        id = 88751,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        startsCombat = true,
        texture = 134206,
        
        usable = function () return buff.wild_mushroom.up end,
        
        handler = function ()
            removeBuff("wild_mushroom")
        end,
    },
    
    starfall = {
        id = 48505,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        spend = 0.35,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236168,
        
        handler = function ()
            applyBuff("starfall")
            if talent.glyph_of_focus.enabled then
                applyBuff("glyph_of_focus")
            end
        end,
    },
    
    celestial_alignment = {
        id = 112071,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        startsCombat = false,
        texture = 136060,
        
        toggle = "cooldowns",
        
        handler = function ()
            applyBuff("celestial_alignment")
            -- Reset eclipse energy
            eclipse.power = 0
        end,
    },
    
    incarnation_chosen_of_elune = {
        id = 102560,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        talent = "incarnation",
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 571586,
        
        handler = function ()
            applyBuff("incarnation_chosen_of_elune")
            shift("moonkin")
        end,
    },
} )

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
    
    -- Track Eclipse power
    spec:RegisterStateTable( "eclipse", {
        power = 0,
        direction = "solar", -- "solar" or "lunar"
        solar_next = false,
        lunar_next = false,
        wrath_counter = 0,
        starfire_counter = 0,
        
        -- Check if we're in Solar Eclipse
        in_solar = function()
            return state.buff.solar_eclipse.up or (state.eclipse.power >= 100)
        end,
        
        -- Check if we're in Lunar Eclipse
        in_lunar = function()
            return state.buff.lunar_eclipse.up or (state.eclipse.power <= -100)
        end,
        
        -- Check if we're moving toward Solar Eclipse
        toward_solar = function()
            return state.eclipse.power > 0 and state.eclipse.power < 100
        end,
        
        -- Check if we're moving toward Lunar Eclipse  
        toward_lunar = function()
            return state.eclipse.power < 0 and state.eclipse.power > -100
        end,
        
        -- Power gain from Wrath (moves toward Solar)
        wrath_power = function()
            local power = 13 -- Base power per Wrath
            if state.talent.euphoria.enabled then
                power = power + 4 -- Euphoria increases power generation
            end
            if state.buff.natures_grace.up then
                power = power + 2 -- Nature's Grace bonus
            end
            return power
        end,
        
        -- Power gain from Starfire (moves toward Lunar)
        starfire_power = function()
            local power = -13 -- Base power per Starfire (negative for lunar)
            if state.talent.euphoria.enabled then
                power = power - 4 -- Euphoria increases power generation
            end
            if state.buff.natures_grace.up then
                power = power - 2 -- Nature's Grace bonus
            end
            return power
        end,
        
        -- Power gain from Starsurge (moves in current direction)
        starsurge_power = function()
            local power = 15
            if state.eclipse.direction == "lunar" or state.eclipse.power < 0 then
                power = -15
            end
            if state.talent.euphoria.enabled then
                power = power * 1.5 -- Euphoria affects Starsurge too
            end
            return power
        end
    } )
    
    -- Track HOTs for wild mushroom and swiftmend mechanics
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
end

-- Register default pack for MoP Balance Druid with authentic Eclipse rotation
spec:RegisterPack( "Balance", 20250812, [[Hekili:nJvBVTTTt8plbfWnbRXtw2jnTZoVOTd4FdwlkGtXEXqLfTeTn)BjrpsQ45Ha9zFhPEIuHu2bODyVOfou397EK3D8cgfCFW8yKah8zFp)R8UzK)qVrEJVACWCXHD4G57qrBrRHFKHsH)FjkbLfPo)qcffl5NtZzYJGVMtseFmlyPDqhb0Udhf85rE(bZ3qIJXL0I5rbZVFdHxek)hQiSsSfH0vWFhji0SIWecxaFEfLve()WBjjKHbZvhQmd8kuEIa(5NvMfodTmbhh8UG5rmIaZiOG5NveUmF1QHPuA2ws2caR0H57cMxkJG56FiqawGeQ6pY3MNKSyjIVrhEGQXof4gmkrSz4Uirr40IWjEfHdkcfOeCMyidNH3JsgwZzJGQ(Ge6jNk0J90ScY6nIf0vlYzCAKeMRovyUsdMLi2wo4nKaC9PcW1xPBh))8haMu)faYRDcsLhjMHrPsfpcOIrY51(gLBRo69eQweJsH0fisQOtr0oggscPSdl47jRezyo3islvBs26fcAE0gPYDJtLtHxeobZfeuYcGV1zPs1vhVLyghZaV1AjyV5ywk4uYzy(IhiRjjgw55vgGDbwe(4JkpreLMet3NzLogofrYGllx0QGgsuQJJ8oMssYIqSYW3)kQOM8ukO7lY4OeYooEbCrHT(qr4SIqpJCKJfUS8DLi9pMpbQmeHLjFL(ZNTF50Ck3kVqB4B6ixLY6UUJsn2tsIxKMZ3WO00HCbuuTSurlQgKOW0Dbh3yoZnMlIXcAMSBGeC3LHKm)GkEMsWshGeZ2BZCAcITOkQBEpoNXirOSsb4Um1reqsEMdbG4cgeK4IQwcJCxfRuv3qPczLfW5W4qifasRhI8WC26s11DnNUj43wNG39dtb7W37u8uMI2DfQNibxIw6cV0u6UDJgs33DPNZTihLyUXH9R(41YllLxWSdW1o5(MswP7eKuYFJJHlAqapJtQc)w1F3vMob3WkuIQaSV7InnfcMQYsRSlRbyxH(oqOvkHNNTIuwcX3DjKEuHUMNR4VBvqoNvJo4UKJTlTtoLCDJQc(pVYotoL05Uvf8Dx5Xsc50zDVtfTbLjh4f(WOJKkB2xypdjuZV47UUKnC6tdU8ikX0UkHkRUmCc16GrVIOPlrwhgxoTpJSRKVpWYjXVTi8D1VRO35WX9mZD9OYnaaZUk7wk2GxiBi1Hw3zeFVMeTNjnDNQCQtVOxms5Y3dZnbYGlFhfedjP7GQyvVv6Lvpn6LfHm8FMdHjWi40uGouUGMcnNHdkd)8Hf39BKm4tJGWYxZ457KijjOu2aC6XMx2q)yN0x9AMwsN4gAJhU0YX19aE7tmAPFKBT3IRvJp3wHXunAC42ySphKgRx5K1MYxAu72hOxlsJHx7KHM0hnQV5zr9BEou779SO2DSRU5PgX(UjUSlNgTUdU1TJ0i2DC1sWX3DO0EWX3D0uvqxJY(dJ1AT6A)kAscDpuhqEZMHG(z7Xm48CUKpcWJqswnaYDNil4iQPlJQQzKNzqDCSKy4X0OLio(Tf3PAqy5Eu1xmAAwDMLxJx9fZXLRpuVXE1zgxNGZUZsLUMop)yR11tbSoTDoLsyg3b(psC8UY1XTJrxrsWL7LlLW5kDQYiQC6RLtfqIaPWizBXcWTgwe(rrjtQacaASuZfBqWX4hWSdsSjuOX3bPkgLKhlh)ctavLvRA)XxHGpGeoL)Txb22gs0gDQrzhALALvJ)RDjKiIiPfxDNqTq)fyGFwTyUVecip4BsqJ1pYxtYqanrZIQGuutQYBOoklpDjUm1lHkGO6htRJ6(MHnzoi0wpxSHYcMppnFfJSvobLYVhm)ffHDMrQ4Uxah(L6e9I7kHJpSj3)NM9Z6PT2PyvcIV1XNO0yhW2j72ovgZ78kYQzhBKQbNDSHPSlOMlosHCwFBE5UsV2hkheQbToEQwy6SFyDgAxcS(PvZ4irODFOtN4nW(QEn0aJzE6GWypDsRxiBhIUYZuvANiQdHxFLoH)aItd6z1R1bH3xTamUHL1S9uPI0BOSLjJnAQzaw3T6GZ7b1hF8StzVCxOlDTLvQjBlRm97UKTqNudmFL2mVb9FLOfVoRwuZACSSZJyrNIbD7yVlQZi(DzPKWpv1AhQKF(NOFb63GL9PjrMgVXyanjlwwl50XozRzy8(4F24A97tqndYLqXM1yJAhndckHrEC7MeUD24b23wJg)6Jg2depzBlvQ1VwnEu49nRRc0vugCvSSlUwrl9kLo3sPtomZSU1BG5btN57DCRTheN2fXBNDznKp16Da55DG4YBEIEE51Ex84JDj86Nq3nqUz4l02jyDZ9whDhTq(QKgFBVQC5RsK0wDty6yqLS69S5tBy6IUDXCcBx1XMF1oS9MGp54H8JLGp5etWF)HizNkJ7ZYxjzjSpDwB0SCm)zJSeZ9U4jrWk3xxkFkExAbWPExOwetW)a]] )


