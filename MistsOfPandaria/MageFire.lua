-- MageFire.lua
-- Updated October 1, 2025 - Modern Structure
-- Mists of Pandaria module for Mage: Fire spec

-- Early return if not a Mage
if select(2, UnitClass('player')) ~= 'MAGE' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]

-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end

local class = Hekili.Class
local state = Hekili.State

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local PTR = ns.PTR

local spec = Hekili:NewSpecialization( 63, true )
-- Register resources
spec:RegisterResource( 0 ) -- Mana = 0 in MoP

-- ===================
-- ENHANCED COMBAT LOG EVENT TRACKING
-- ===================

local fireCombatLogFrame = CreateFrame("Frame")
local fireCombatLogEvents = {}

local function RegisterFireCombatLogEvent(event, handler)
    if not fireCombatLogEvents[event] then
        fireCombatLogEvents[event] = {}
        fireCombatLogFrame:RegisterEvent(event)
    end
    
    tinsert(fireCombatLogEvents[event], handler)
end

fireCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = fireCombatLogEvents[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(event, ...)
        end
    end
end)

-- Fire-specific tracking variables
local fireball_casts = 0
local pyroblast_crits = 0
local hot_streak_procs = 0
local heating_up_procs = 0
local combustion_applications = 0
local living_bomb_explosions = 0

-- Enhanced Combat Log Event Handlers for Fire-specific mechanics
RegisterFireCombatLogEvent("COMBAT_LOG_EVENT_UNFILTERED", function(event, ...)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool = CombatLogGetCurrentEventInfo()
    
    if sourceGUID == UnitGUID("player") then
        -- Track Fire-specific spell interactions
        if subEvent == "SPELL_CAST_SUCCESS" then
            if spellID == 133 then -- Fireball
                fireball_casts = fireball_casts + 1
            elseif spellID == 11366 then -- Pyroblast
                -- Pyroblast cast tracking
            elseif spellID == 44457 then -- Living Bomb
                -- Living Bomb application tracking
            end
        elseif subEvent == "SPELL_DAMAGE" then
            if spellID == 11366 then -- Pyroblast
                -- Track Pyroblast crits for Hot Streak
                local critical = select(21, CombatLogGetCurrentEventInfo())
                if critical then
                    pyroblast_crits = pyroblast_crits + 1
                    -- Convert Heating Up to Hot Streak
                    if buff.heating_up.up then
                        removeBuff( "heating_up" )
                        applyBuff( "hot_streak" )
                    end
                end
            elseif spellID == 133 then -- Fireball
                -- Track Fireball crits for Heating Up
                local critical = select(21, CombatLogGetCurrentEventInfo())
                if critical then
                    -- Apply Heating Up on first crit
                    if not buff.heating_up.up and not buff.hot_streak.up then
                        applyBuff( "heating_up" )
                    -- Convert Heating Up to Hot Streak on second crit
                    elseif buff.heating_up.up then
                        removeBuff( "heating_up" )
                        applyBuff( "hot_streak" )
                    end
                    heating_up_procs = heating_up_procs + 1
                end
            end
        elseif subEvent == "SPELL_AURA_APPLIED" then
            if spellID == 48108 then -- Hot Streak
                hot_streak_procs = hot_streak_procs + 1
            elseif spellID == 48107 then -- Heating Up
                heating_up_procs = heating_up_procs + 1
            elseif spellID == 83853 then -- Combustion
                combustion_applications = combustion_applications + 1
            end
        elseif subEvent == "SPELL_PERIODIC_DAMAGE" then
            if spellID == 44457 then -- Living Bomb explosion
                living_bomb_explosions = living_bomb_explosions + 1
            end
        end
    end
end)

-- ===================
-- ENHANCED TIER SETS AND GEAR REGISTRATION
-- ===================

-- Comprehensive Tier Set Coverage (T14-T16 across all difficulties)
spec:RegisterGear( "tier14", 85370, 85371, 85372, 85373, 85369 ) -- Normal
spec:RegisterGear( "tier14_lfr", 89335, 89336, 89337, 89338, 89339 ) -- LFR versions
spec:RegisterGear( "tier14_heroic", 90465, 90466, 90467, 90468, 90469 ) -- Heroic versions

-- Tier 15 - Throne of Thunder
spec:RegisterGear( "tier15", 95893, 95894, 95895, 95897, 95892 ) -- Normal
spec:RegisterGear( "tier15_lfr", 95316, 95317, 95318, 95319, 95320 ) -- LFR versions
spec:RegisterGear( "tier15_heroic", 96626, 96627, 96628, 96629, 96630 ) -- Heroic versions
spec:RegisterGear( "tier15_thunderforged", 97261, 97262, 97263, 97264, 97265 ) -- Thunderforged versions

-- Tier 16 - Siege of Orgrimmar
spec:RegisterGear( "tier16", 99125, 99126, 99127, 99128, 99129 ) -- Normal
spec:RegisterGear( "tier16_lfr", 99780, 99781, 99782, 99783, 99784 ) -- LFR versions
spec:RegisterGear( "tier16_flex", 100290, 100291, 100292, 100293, 100294 ) -- Flexible versions
spec:RegisterGear( "tier16_heroic", 100945, 100946, 100947, 100948, 100949 ) -- Heroic versions
spec:RegisterGear( "tier16_mythic", 101610, 101611, 101612, 101613, 101614 ) -- Mythic versions

-- Legendary Items
spec:RegisterGear( "legendary_cloak", 102246 ) -- Jina-Kang, Kindness of Chi-Ji (DPS version)
spec:RegisterGear( "legendary_meta_gem", 101817 ) -- Capacitive Primal Diamond

-- Notable Trinkets
spec:RegisterGear( "unerring_vision_of_lei_shen", 94530 ) -- Throne of Thunder trinket
spec:RegisterGear( "breath_of_the_hydra", 105609 ) -- SoO trinket
spec:RegisterGear( "dysmorphic_samophlange_of_discontinuity", 105691 ) -- SoO trinket
spec:RegisterGear( "haromms_talisman", 102664 ) -- SoO trinket
spec:RegisterGear( "purified_bindings_of_immerseus", 102293 ) -- SoO trinket
spec:RegisterGear( "thoks_tail_tip", 104631 ) -- SoO trinket for casters
spec:RegisterGear( "kardris_toxic_totem", 102312 ) -- SoO trinket

-- Fire-specific Weapons
spec:RegisterGear( "gao_lei_shao_do", 89235 ) -- MSV staff
spec:RegisterGear( "nadagast_exsanguinator", 87652 ) -- HoF dagger
spec:RegisterGear( "dragonwrath_tarecgosa_s_rest", 71086 ) -- Legendary staff from Cata (still usable)
spec:RegisterGear( "lei_shen_s_final_orders", 94522 ) -- ToT weapon
spec:RegisterGear( "horridon_s_last_gasp", 93982 ) -- ToT weapon

-- PvP Sets (Season 12-15)
spec:RegisterGear( "season12", 91394, 91395, 91396, 91397, 91398 ) -- Malevolent Gladiator's Silk
spec:RegisterGear( "season13", 93687, 93688, 93689, 93690, 93691 ) -- Tyrannical Gladiator's Silk
spec:RegisterGear( "season14", 95343, 95344, 95345, 95346, 95347 ) -- Grievous Gladiator's Silk
spec:RegisterGear( "season15", 98014, 98015, 98016, 98017, 98018 ) -- Prideful Gladiator's Silk

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 90564, 90565, 90566, 90567, 90568 ) -- Challenge Mode Mage Set

-- Advanced tier set bonus tracking with generate functions
local function check_tier_bonus(tier, pieces)
    return function()
        return equipped[tier] >= pieces
    end
end

spec:RegisterAura( "tier14_2pc_fire", {
    id = 123456, -- Placeholder ID
    generate = check_tier_bonus("tier14", 2)
} )
spec:RegisterAura( "tier14_4pc_fire", {
    id = 123457, -- Placeholder ID
    generate = check_tier_bonus("tier14", 4)
} )
spec:RegisterAura( "tier15_2pc_fire", {
    id = 123458, -- Placeholder ID
    generate = check_tier_bonus("tier15", 2)
} )
spec:RegisterAura( "tier15_4pc_fire", {
    id = 123459, -- Placeholder ID
    generate = check_tier_bonus("tier15", 4)
} )
spec:RegisterAura( "tier16_2pc_fire", {
    id = 123460, -- Placeholder ID
    generate = check_tier_bonus("tier16", 2)
} )
spec:RegisterAura( "tier16_4pc_fire", {
    id = 123461, -- Placeholder ID
    generate = check_tier_bonus("tier16", 4)
} )

-- Spell Power Calculations and State Expressions
spec:RegisterStateExpr( "spell_power", function()
    return GetSpellBonusDamage(3) -- Fire school
end )

spec:RegisterStateExpr( "hot_streak_bonus", function()
    if buff.hot_streak.up then return 0.25 end
    return 0
end )

spec:RegisterStateExpr( "heating_up_bonus", function()
    if buff.heating_up.up then return 0.15 end
    return 0
end )

-- ===================
-- FIRE MAGE VARIABLE LOGIC (From WoWSims APL)
-- ===================

-- Proc State Variables
spec:RegisterStateExpr( "has_instant", function()
    -- True if we have Hot Streak proc (instant Pyroblast)
    if buff.hot_streak.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "has_hu", function()
    -- True if we have Heating Up (need one more crit for Hot Streak)
    if buff.heating_up.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "has_instant_hu", function()
    -- True if we have both Hot Streak and Heating Up (rare case from Ignite spreading)
    if buff.hot_streak.up and buff.heating_up.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "hu_to_hot", function()
    -- Optimization: Can convert Heating Up to Hot Streak with next crit
    -- This helps with predictive ability weighting
    if buff.heating_up.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "no_ignite", function()
    -- True if target doesn't have Ignite debuff
    if not debuff.ignite.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "ignite_active", function()
    -- True if target has Ignite debuff
    if debuff.ignite.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "ignite_expiring", function()
    -- True if Ignite will expire soon (within 2 seconds)
    if debuff.ignite.up and debuff.ignite.remains < 2 then return 1 end
    return 0
end )

-- Timing Window Variables
spec:RegisterStateExpr( "alter_time_ready", function()
    -- True if Alter Time is ready (with 6 second leeway for planning)
    if cooldown.alter_time.ready then return 1 end
    return 0
end )

spec:RegisterStateExpr( "alter_time_soon", function()
    -- True if Alter Time will be ready soon (within 6 seconds)
    if cooldown.alter_time.remains < 6 then return 1 end
    return 0
end )

spec:RegisterStateExpr( "alter_time_dot_window", function()
    -- True if we're in a window where Alter Time cooldown allows burning cooldowns
    -- Essentially: Alter Time is ready OR recently used (allows burst planning)
    if cooldown.alter_time.ready then return 1 end
    if cooldown.alter_time.remains > 172 then return 1 end -- 172 = 180 - 8
    return 0
end )

-- Combustion Threshold Variables (for intelligent Combustion timing)
spec:RegisterStateExpr( "combustion_ready_burst", function()
    -- True if we should use Combustion when all buffs align for burst damage
    -- Requires: Hot Streak/Pyroblast, Alter Time cooldown ready, and sufficient cooldowns
    if buff.hot_streak.up and cooldown.alter_time.ready then return 1 end
    return 0
end )

spec:RegisterStateExpr( "combustion_on_ignite", function()
    -- True if Combustion should be used to snapshot high Ignite DoT
    -- Used for single-target sustained damage when short-term burst unavailable
    if debuff.ignite.up and debuff.ignite.remains > 1 then return 1 end
    return 0
end )

spec:RegisterStateExpr( "combustion_with_invocation", function()
    -- True if Combustion should be used when Invocation buff active (15% spell power increase)
    if buff.invocation.up and cooldown.combustion.ready then return 1 end
    return 0
end )

spec:RegisterStateExpr( "combustion_with_potions", function()
    -- True if Combustion should sync with damage potion for peak burst
    return 0 -- Would need potion detection from combat log
end )

spec:RegisterStateExpr( "combustion_multidot_value", function()
    -- Estimate total damage spread from Combustion to multiple DoTs
    -- Used to determine if multi-target Combustion is worth the cooldown
    local dot_value = 0
    if debuff.ignite.up then dot_value = dot_value + 1 end
    if debuff.living_bomb.up then dot_value = dot_value + 1 end
    if debuff.nether_tempest.up then dot_value = dot_value + 1 end
    return dot_value
end )

-- Additional State Tracking Variables
spec:RegisterStateExpr( "burn_phase_active", function()
    -- True if in a burn phase (Combustion recently used or about to be used)
    -- Used for resource pooling and cooldown alignment decisions
    if cooldown.combustion.remains < 5 or buff.combustion.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "pooling_for_combustion", function()
    -- True if we should pool resources for upcoming Combustion window
    if cooldown.combustion.remains < 10 and not buff.combustion.up then return 1 end
    return 0
end )

-- Talents (MoP 6-tier system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility/Instant Cast
    presence_of_mind      = { 1, 1, 12043 }, -- Your next 3 spells are instant cast
    blazing_speed         = { 1, 2, 108843 }, -- Increases movement speed by 150% for 1.5 sec after taking damage
    ice_floes             = { 1, 3, 108839 }, -- Allows you to cast 3 spells while moving

    -- Tier 2 (Level 30) - Survivability
    flameglow             = { 2, 1, 140468 }, -- Reduces spell damage taken by a fixed amount
    ice_barrier           = { 2, 2, 11426 }, -- Absorbs damage for 1 min
    temporal_shield       = { 2, 3, 115610 }, -- 100% of damage taken is healed back over 6 sec

    -- Tier 3 (Level 45) - Control
    ring_of_frost         = { 3, 1, 113724 }, -- Incapacitates enemies entering the ring
    ice_ward              = { 3, 2, 111264 }, -- Frost Nova gains 2 charges
    frostjaw              = { 3, 3, 102051 }, -- Silences and freezes target

    -- Tier 4 (Level 60) - Utility
    greater_invisibility  = { 4, 1, 110959 }, -- Invisible for 20 sec, 90% damage reduction when visible
    cold_snap             = { 4, 2, 11958 }, -- Finishes cooldown on Frost spells, heals 25%
    cauterize             = { 4, 3, 86949 }, -- Fatal damage brings you to 35% health

    -- Tier 5 (Level 75) - DoT/Bomb Spells
    nether_tempest        = { 5, 1, 114923 }, -- Arcane DoT that spreads
    living_bomb           = { 5, 2, 44457 }, -- Fire DoT that explodes
    frost_bomb            = { 5, 3, 112948 }, -- Frost bomb with delayed explosion

    -- Tier 6 (Level 90) - Power/Mana Management
    invocation            = { 6, 1, 114003 }, -- Evocation increases damage by 25%
    rune_of_power         = { 6, 2, 116011 }, -- Ground rune increases spell damage by 15%
    incanter_s_ward       = { 6, 3, 1463 }, -- Converts 30% damage taken to mana
} )

-- Tier Sets
spec:RegisterGear( 13, 8, { -- Tier 14
    { 86886, head = 86701, shoulder = 86702, chest = 86699, hands = 86700, legs = 86703 }, -- LFR
    { 87139, head = 85370, shoulder = 85372, chest = 85373, hands = 85371, legs = 85369 }, -- Normal
    { 87133, head = 87105, shoulder = 87107, chest = 87108, hands = 87106, legs = 87104 }, -- Heroic
} )

spec:RegisterGear( 14, 8, { -- Tier 15
    { 95890, head = 95308, shoulder = 95310, chest = 95306, hands = 95307, legs = 95309 }, -- LFR
    { 95891, head = 95893, shoulder = 95895, chest = 95897, hands = 95894, legs = 95892 }, -- Normal
    { 95892, head = 96633, shoulder = 96631, chest = 96629, hands = 96632, legs = 96630 }, -- Heroic
} )

-- ===================
-- ENHANCED GLYPH SYSTEM
-- ===================
spec:RegisterGlyphs( {
    -- Major Glyphs for Fire Mage in MoP
    [56368] = "Glyph of Combustion",            -- Your Combustion spreads your Fire DoTs to nearby enemies
    [56375] = "Glyph of Living Bomb",           -- Your Living Bomb explosion reduces the cast time of your next Living Bomb by 1.5 sec
    [56374] = "Glyph of Inferno Blast",         -- Your Inferno Blast spreads living bomb from the target to up to 3 nearby enemies
    [56383] = "Glyph of Fireball",              -- Your Fireball deals 25% additional damage over 4 sec
    [56382] = "Glyph of Pyroblast",             -- Reduces the cast time of Pyroblast by 0.25 sec
    [58659] = "Glyph of Dragon's Breath",       -- Reduces the cooldown of Dragon's Breath by 10 sec
    [58656] = "Glyph of Fire Blast",            -- Increases the critical strike chance of Fire Blast by 50% when the target is below 35% health
    [58734] = "Glyph of Molten Armor",          -- Your Molten Armor grants an additional 2% critical strike chance
    [56372] = "Glyph of Ice Barrier",           -- Your Ice Barrier increases resistance to Frost and Fire effects by 40%
    [56378] = "Glyph of Mage Armor",            -- Your Mage Armor reduces the duration of magic effects by an additional 35%
    [56391] = "Glyph of Blink",                 -- Increases the distance traveled by Blink by 8 yards
    [56384] = "Glyph of Blazing Speed",         -- Your Blazing Speed removes all movement impairing effects
    [56381] = "Glyph of Polymorph",             -- Your Polymorph heals the target for 15% of its maximum health every 2 sec
    [56380] = "Glyph of Evocation",             -- Your Evocation heals you for 40% of your maximum health over its duration
    [58647] = "Glyph of Ice Block",             -- Your Ice Block heals you for 40% of your maximum health
    [58648] = "Glyph of Frost Nova",            -- Your Frost Nova deals 100% more damage
    [58651] = "Glyph of Ring of Frost",         -- Your Ring of Frost affects 2 additional enemies
    [58649] = "Glyph of Frostjaw",              -- Your Frostjaw spreads to 1 nearby enemy
    [58658] = "Glyph of Spellsteal",            -- Your Spellsteal heals you for 5% of your maximum health for each effect stolen
    [58650] = "Glyph of Slow Fall",             -- Your Slow Fall no longer requires a reagent
    [58652] = "Glyph of Momentum",              -- Blink increases your movement speed by 50% for 3 sec
    
    -- Minor Glyphs for MoP
    [58736] = "Glyph of Illusion",              -- You can now cast illusion on party and raid members
    [104065] = "Glyph of the Penguin",          -- Your Polymorph: Sheep is replaced with Polymorph: Penguin
    [104066] = "Glyph of the Porcupine",        -- Your Polymorph: Sheep is replaced with Polymorph: Porcupine
    [58737] = "Glyph of the Monkey",            -- Your Polymorph: Sheep is replaced with Polymorph: Monkey
    [58739] = "Glyph of the Bear Cub",          -- Your Polymorph: Sheep is replaced with Polymorph: Bear Cub
    [58741] = "Glyph of the Turtle",            -- Your Polymorph: Sheep is replaced with Polymorph: Turtle
    [58742] = "Glyph of Rapid Teleportation",   -- Reduces the cast time of teleportation spells by 50%
    [58743] = "Glyph of Conjuring",             -- You can conjure 3 additional charges of conjured items
    [58744] = "Glyph of Arcane Language",       -- Allows you to understand Demonic language
    [58654] = "Glyph of Teleport",              -- Reduces the cast time of your Teleport spells by 50%
    [58646] = "Glyph of Arcane Intellect",      -- Your Arcane Intellect grants an additional 10% mana
    [58653] = "Glyph of Conjure Familiar",      -- Your conjured mana food restores 100% more mana
} )

-- ===================
-- ENHANCED AURA SYSTEM WITH EXTENSIVE GENERATE FUNCTIONS
-- ===================

spec:RegisterAuras( {
    -- ENHANCED FIRE-SPECIFIC CORE MECHANICS
    -- Advanced aura system with extensive generate functions for Fire optimization
    
    -- Core Fire Procs and Mechanics
    combustion = {
        id = 11129,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 11129 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    heating_up = {
        id = 48107,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48107 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    hot_streak = {
        id = 48108,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48108 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Enhanced DoT tracking
    pyroblast = {
        id = 11366,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 11366 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    living_bomb = {
        id = 44457,
        duration = 12,
        max_stack = 3, -- Can be applied to multiple targets
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 44457 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    ignite = {
        id = 12654,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 12654 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Fire-specific proc tracking
    heating_up = {
        id = 48107,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48107 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    hot_streak = {
        id = 48108,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 48108 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- MoP Talent Coordination - Enhanced tracking
    alter_time = {
        id = 110909,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 110909 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    presence_of_mind = {
        id = 12043,
        duration = 10,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12043 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    nether_tempest = {
        id = 114923,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 114923 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    frost_bomb = {
        id = 112948,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 112948 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    invocation = {
        id = 114003,
        duration = 40,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114003 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    rune_of_power = {
        id = 116011,
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 116011 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    incanter_s_ward = {
        id = 1463,
        duration = 25,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1463 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Enhanced Glyph Coordination
    glyph_of_combustion = {
        id = 56368,
        duration = 0,
        max_stack = 1,
        generate = function( t )
            if IsPlayerSpell( 56368 ) then
                t.name = "Glyph of Combustion"
                t.count = 1
                t.expires = 9999999999
                t.applied = 0
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    glyph_of_living_bomb = {
        id = 56375,
        duration = 0,
        max_stack = 1,
        generate = function( t )
            if IsPlayerSpell( 56375 ) then
                t.name = "Glyph of Living Bomb"
                t.count = 1
                t.expires = 9999999999
                t.applied = 0
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    glyph_of_inferno_blast = {
        id = 56374,
        duration = 0,
        max_stack = 1,
        generate = function( t )
            if IsPlayerSpell( 56374 ) then
                t.name = "Glyph of Inferno Blast"
                t.count = 1
                t.expires = 9999999999
                t.applied = 0
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Enhanced Defensive and Utility Tracking
    ice_barrier = {
        id = 11426,
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 11426 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    greater_invisibility = {
        id = 110960,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 110960 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    temporal_shield = {
        id = 115610,
        duration = 4,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 115610 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    flameglow = {
        id = 140468,
        duration = 0,
        max_stack = 1,
        generate = function( t )
            if IsPlayerSpell( 140468 ) then
                t.name = "Flameglow"
                t.count = 1
                t.expires = 9999999999
                t.applied = 0
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Enhanced Movement and Mobility
    blazing_speed = {
        id = 108843,
        duration = 1.5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108843 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    ice_floes = {
        id = 108839,
        duration = 15,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108839 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Enhanced Tier Set and Legendary Tracking
    tier14_2pc_fire = {
        id = 123456, -- Placeholder ID
        duration = 0,
        max_stack = 1,
        generate = function( t )
            if equipped.tier14 >= 2 then
                t.name = "T14 2PC Fire"
                t.count = 1
                t.expires = 9999999999
                t.applied = 0
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    tier15_4pc_fire = {
        id = 123457, -- Placeholder ID
        duration = 0,
        max_stack = 1,
        generate = function( t )
            if equipped.tier15 >= 4 then
                t.name = "T15 4PC Fire"
                t.count = 1
                t.expires = 9999999999
                t.applied = 0
                t.caster = "player"
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    legendary_meta_gem_proc = {
        id = 137323, -- Capacitive Primal Diamond proc
        duration = 30,
        max_stack = 1,
        generate = function( t )
            if not equipped.legendary_meta_gem then
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                return
            end
            
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 137323 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Fire-specific Debuffs and Crowd Control
    polymorph = {
        id = 118,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 118 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    dragons_breath = {
        id = 31661,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 31661 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
    
    -- Shared Mage Auras
    arcane_brilliance = {
        id = 1459,
        duration = 3600,
        max_stack = 1
    },
    
    blink = {
        id = 1953,
        duration = 0.3,
        max_stack = 1
    },
    
    counterspell = {
        id = 2139,
        duration = 6,
        max_stack = 1
    },
    
    frost_nova = {
        id = 122,
        duration = 8,
        max_stack = 1
    },
    
    frostjaw = {
        id = 102051,
        duration = 8,
        max_stack = 1
    },
    
    ice_block = {
        id = 45438,
        duration = 10,
        max_stack = 1
    },
    
    slow = {
        id = 31589,
        duration = 15,
        max_stack = 1
    },
    
    slow_fall = {
        id = 130,
        duration = 30,
        max_stack = 1
    },
    
    time_warp = {
        id = 80353,
        duration = 40,
        max_stack = 1
    },
    
    -- Armor Auras
    frost_armor = {
        id = 7302,
        duration = 1800,
        max_stack = 1
    },
    
    mage_armor = {
        id = 6117,
        duration = 1800,
        max_stack = 1
    },      molten_armor = {
        id = 30482,
        duration = 1800,
        max_stack = 1
    },
} )

-- ===================
-- ABILITIES
-- ===================

spec:RegisterAbilities( {
    -- Fire Core Abilities
    fireball = {
        id = 133,
        cast = function() return 2.25 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135812,
        
        velocity = 24,
        
        handler = function()
            -- Heating Up mechanic handled by combat log events
            -- On crit: gain Heating Up or convert to Hot Streak
        end,
    },
    
    inferno_blast = {
        id = 108853,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135813,
        
        handler = function()
            -- Guaranteed crit - always converts Heating Up to Hot Streak
            if buff.heating_up.up then
                removeBuff( "heating_up" )
                applyBuff( "hot_streak" )
            else
                -- If no Heating Up, gain Heating Up from guaranteed crit
                applyBuff( "heating_up" )
            end
            
            -- Spreads Pyroblast, Combustion, and Ignite DoTs to nearby targets
            -- (actual spread handled by game mechanics)
        end,
    },
    
    pyroblast = {
        id = 11366,
        cast = function() 
            if buff.hot_streak.up then return 0 end
            return 3.5 * haste 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.hot_streak.up then return 0 end
            return 0.05
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135808,
        
        velocity = 24,
        
        handler = function()
            local had_hot_streak = buff.hot_streak.up
            
            if had_hot_streak then
                removeBuff( "hot_streak" )
            end
            
            -- Apply Pyroblast DoT (18s, 6 ticks every 3s)
            applyDebuff( "target", "pyroblast" )
            
            -- Instant Pyroblast DoT gets 25% damage bonus
            -- Heating Up mechanic handled by combat log events
        end,
    },
    
    combustion = {
        id = 11129,
        cast = 0,
        cooldown = function()
            return glyph.glyph_of_combustion.enabled and 90 or 45
        end,
        gcd = "spell",

        toggle = "cooldowns",

        startsCombat = true,
        texture = 135824,        usable = function()
            return debuff.ignite.up, "requires ignite on target"
        end,
        
        handler = function()
            -- Direct damage based on Ignite
            -- Apply Combustion DoT (10 ticks, 20 ticks with glyph)
            applyDebuff( "target", "combustion" )
            
            -- Resets Inferno Blast cooldown
            setCooldown( "inferno_blast", 0 )
        end,
    },
    
    dragons_breath = {
        id = 31661,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = true,
        texture = 134153,
        
        handler = function()
            applyDebuff( "target", "dragons_breath" )
        end,
    },
    
    blast_wave = {
        id = 11113,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135903,
        
        handler = function()
            applyDebuff( "target", "blast_wave" )
        end,
    },
    
    scorch = {
        id = 2948,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135827,
        
        handler = function()
            -- Similar to Fireball, can proc Heating Up / Hot Streak
        end,
    },
    
    living_bomb = {
        id = 44457,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236220,
        
        talent = "living_bomb",
        
        handler = function()
            applyDebuff( "target", "living_bomb" )
        end,
    },
    
    flamestrike = {
        id = 2120,
        cast = 2,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.035,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135826,
        
        handler = function()
            -- Apply Flamestrike DoT
        end,
    },
    
    -- Shared Mage Abilities
    arcane_brilliance = {
        id = 1459,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135932,
        
        handler = function()
            applyBuff( "arcane_brilliance" )
        end,
    },
    
    alter_time = {
        id = 108978,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        startsCombat = false,
        texture = 607849,
        
        handler = function()
            applyBuff( "alter_time" )
        end,
    },
    
    blink = {
        id = 1953,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135736,
        
        handler = function()
            applyBuff( "blink" )
        end,
    },
    
    cone_of_cold = {
        id = 120,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135852,
        
        handler = function()
            applyDebuff( "target", "cone_of_cold" )
        end,
    },
    
    conjure_mana_gem = {
        id = 759,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 134132,
        
        handler = function()
            -- Creates a Mana Gem
        end,
    },
    
    counterspell = {
        id = 2139,
        cast = 0,
        cooldown = 24,
        gcd = "off",
        
        interrupt = true,
        
        startsCombat = true,
        texture = 135856,
        
        toggle = "interrupts",
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        
        handler = function()
            interrupt()
            applyDebuff( "target", "counterspell" )
        end,
    },
    
    evocation = {
        id = 12051,
        cast = 6,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "cooldowns",
        startsCombat = false,
        texture = 136075,
        
        handler = function()
            -- Restore 60% mana over 6 sec
            gain( 0.6 * mana.max, "mana" )
            
            if talent.invocation.enabled then
                applyBuff( "invocation" )
            end
        end,
    },
    
    frost_nova = {
        id = 122,
        cast = 0,
        cooldown = function() return talent.ice_ward.enabled and 20 or 30 end,
        charges = function() return talent.ice_ward.enabled and 2 or nil end,
        recharge = function() return talent.ice_ward.enabled and 20 or nil end,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135848,
        
        handler = function()
            applyDebuff( "target", "frost_nova" )
        end,
    },
    
    frostjaw = {
        id = 102051,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607853,
        
        talent = "frostjaw",
        
        handler = function()
            applyDebuff( "target", "frostjaw" )
        end,
    },
    
    ice_barrier = {
        id = 11426,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135988,
        
        talent = "ice_barrier",
        
        handler = function()
            applyBuff( "ice_barrier" )
        end,
    },
    
    ice_block = {
        id = 45438,
        cast = 0,
        cooldown = 300,
        gcd = "spell",

        toggle = "defensives",
        
        startsCombat = false,
        texture = 135841,
        
        handler = function()
            applyBuff( "ice_block" )
            setCooldown( "hypothermia", 30 )
        end,
    },
    
    ice_floes = {
        id = 108839,
        cast = 0,
        cooldown = 45,
        charges = 3,
        recharge = 45,
        gcd = "off",
        
        startsCombat = false,
        texture = 610877,
        
        talent = "ice_floes",
        
        handler = function()
            applyBuff( "ice_floes" )
        end,
    },
    
    incanter_s_ward = {
        id = 1463,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        startsCombat = false,
        texture = 250986,
        
        talent = "incanter_s_ward",
        
        handler = function()
            applyBuff( "incanter_s_ward" )
        end,
    },
    
    invisibility = {
        id = 66,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132220,
        
        handler = function()
            applyBuff( "invisibility" )
        end,
    },
    
    greater_invisibility = {
        id = 110959,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "cooldowns",
        startsCombat = false,
        texture = 606086,
        
        talent = "greater_invisibility",
        
        handler = function()
            applyBuff( "greater_invisibility" )
        end,
    },
    
    presence_of_mind = {
        id = 12043,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "cooldowns",
        startsCombat = false,
        texture = 136031,
        
        talent = "presence_of_mind",
        
        handler = function()
            applyBuff( "presence_of_mind" )
        end,
    },
    
    ring_of_frost = {
        id = 113724,
        cast = 1.5,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = false,
        texture = 464484,
        
        talent = "ring_of_frost",
        
        handler = function()
            -- Places Ring of Frost at target location
        end,
    },
    
    rune_of_power = {
        id = 116011,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 609815,
        
        talent = "rune_of_power",
        
        handler = function()
            -- Places Rune of Power on the ground
        end,
    },
    
    -- REMOVING THIS DUPLICATE:
    -- slow = {
    --     id = 31589,
    --     cast = 0,
    --     cooldown = 0,
    --     gcd = "spell",
    --     
    --     spend = 0.02,
    --     spendType = "mana",
    --     
    --     startsCombat = true,
    --     texture = 136091,
    --     
    --     handler = function()
    --         applyDebuff( "target", "slow" )
    --     end,
    -- },
    
    -- REMOVING THIS DUPLICATE:
    -- slow_fall = {
    --     id = 130,
    --     cast = 0,
    --     cooldown = 0,
    --     gcd = "spell",
    --     
    --     spend = 0.01,
    --     spendType = "mana",
    --     
    --     startsCombat = false,
    --     texture = 135992,
    --     
    --     handler = function()
    --         applyBuff( "slow_fall" )
    --     end,
    -- },
    
    spellsteal = {
        id = 30449,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135729,
        
        handler = function()
            -- Attempt to steal a buff from the target
        end,
    },
    
    time_warp = {
        id = 80353,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        startsCombat = false,
        texture = 458224,
        
        handler = function()
            applyBuff( "time_warp" )
            applyDebuff( "player", "temporal_displacement" )
        end,
    },
    
    -- Armor Spells
    frost_armor = {
        id = 7302,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135843,
        
        handler = function()
            removeBuff( "mage_armor" )
            removeBuff( "molten_armor" )
            applyBuff( "frost_armor" )
        end,
    },
    
    mage_armor = {
        id = 6117,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135991,
        
        handler = function()
            removeBuff( "frost_armor" )
            removeBuff( "molten_armor" )
            applyBuff( "mage_armor" )
        end,
    },
    
    molten_armor = {
        id = 30482,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132221,
        
        handler = function()
            removeBuff( "frost_armor" )
            removeBuff( "mage_armor" )
            applyBuff( "molten_armor" )
        end,
    },

    nether_tempest = {
        id = 114923,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",

        spend = 0.03,
        spendType = "mana",

        talent = "nether_tempest",
        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "nether_tempest" )
        end,
    },

    frost_bomb = {
        id = 112948,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "frost",

        spend = 0.03,
        spendType = "mana",

        talent = "frost_bomb",
        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "frost_bomb" )
        end,
    },

    alter_time_activate = {
        id = 108978,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = false,
        buff = "alter_time",

        handler = function ()
            -- Activates Alter Time, returning to previous state
            removeBuff( "alter_time" )
        end,
    },

    strictsequence = {
        id = 0, -- Placeholder
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = false,

        handler = function ()
            -- Strict sequence action - handled by SimC
        end,
    },

    mirror_image = {
        id = 55342,
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135994,
        
        handler = function()
            applyBuff( "mirror_image" )
        end,
    },
} )

-- State Functions and Expressions
spec:RegisterStateExpr( "hot_streak", function()
    if buff.pyroblast_clearcasting.up then return 1 end
    return 0
end )

spec:RegisterStateExpr( "combustion_dot_value", function()
    -- Calculate total DoT value for Combustion timing
    local value = 0
    if debuff.ignite.up then
        value = value + (debuff.ignite.damage * debuff.ignite.ticks_remain)
    end
    if debuff.living_bomb.up then
        value = value + (debuff.living_bomb.damage * debuff.living_bomb.ticks_remain)
    end
    if debuff.nether_tempest.up then
        value = value + (debuff.nether_tempest.damage * debuff.nether_tempest.ticks_remain)
    end
    return value
end )

-- Range
spec:RegisterRanges( "fireball", "polymorph", "blink" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 40,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent_potion",
    
    package = "Fire",
} )

-- Register default pack for MoP Fire Mage  
spec:RegisterPack( "Fire", 20260101, [[Hekili:9MvBVTTUv4FlgxaJeuxF9lXP5oevGTIn0BXUDftzRFts020XersuJIkPziq)23HK6fkAsfjFZDfnbosKNZZ5WZB8XbldUlWFpIJd(6QfRUEXYfRMVyXvxV8MaF(Zz4a)m0Uhq3dFifLa)(VryYh(CmfTxS5CAbBh8Oa)TfKy(VMgS1Me3S6kyTz4DbF961b(hj73JvlfNVlW)UJK8YiXpOYOkvwgrpa)9ooHMwgftY5WRpqzLrFg)ajMmpWx(qPjGpGkI5Wh)Q0KWPOTX49b)LaFAgOympWxjPa)hrmI4TIpfxGfa)WH5hP8WCodJEyErMcwmsMAhFJr3vg5ZbRQm6FxT9CPKcvULJO8qsAohLYd4GLFMyaJ4K07dlYKyOR4pwiK86ZuY6wxz00YOxxHv2tLIV6mvStnueYPHaUecFZOf(KYO9yPgi3Ns4ydPNsdvpxi9RhT07t0Qhgk27JsX)HF3IxEG09HmCccoakJUTmALf1J)rgHbowbaUz0ayhLgVN(u6CumhZc5KeHgr7F2iW)oscOJYOVtsHL7i2VvgHkzaq6xEJGuRt4AhQmNcId04YfVrQeSGYOxEPmQxe9r7VFFbdPQx9(YOBCa59qY4tspQe4VffSKrqd9u9t0KTf5kyE3rgo)iSphhU7AwR6WnCBblxMZUC8f5gtCp4Gx6aiW)BtUxEMvejPps3jpRoX91QQA3Nvy8eHFmSvmsWm(QKl6t6zuXNZLIE81iV40AKLrxwg9UYO2xftEuuFElOzRVpfZpkcMWjz4CUAjoGCc0bMicUv6xa6Xx61(PqBDGnQKtj20wYj9S)Z73teFcf305(ogmyHSEM1qDiYonmd68PxCF54RU)AwWYfYWTj2nIw8KbYrC0aJ8e2UijOmR4xJfz5LNqmtNXNQGeyVWdHIdeuvAW2ykDFmi65I3lfUzT7gHd9BEaZHSY8yOTD7Flg4XS6RXMwzSPvYnzw5REt4MCQUMXVHsHXdtGFFpobdJAzAnSIuCi9aK38eMP509GSBuoxwsuQzZAxTYjBh)2BwydlI9zwSPEvDuSbQ)NW7uZY(nXBfgajLdcjvm3CRM5OyWMmSHkDjJyUOnOP7IejLnjfdXhiYHfMJz5QAZ5ikDFE9rw1F0cuNfkDmyP2J7ziB)Ntrz5a08Zed2aqwuceUuGAm03vjYYiyNcSBwpSg7APkUB790rm87kqR0dGTYif4KLa113Gn(lSzOAhog(LlDwmtyHMfpF7oDg0Tb6EfONz0TXq8dC9mgHcARXX95Ah1)kt64(SWr6x5ifGGkFCvMVSz2kZQQaAi7aqH)pfyzAXY)qmjlXic0ywo9)ZOjR23kbJRYVdlUUkLHJJJj3dLta)E1m8BHgBqDeXQQTar8U4M6d246FKyOcZh2iVKQRUbTwQZOllXuQKvDZe9iIeRA6A0byiE(ozQTnaRtu7V)TNCeez5Z1U6FnaZCFrswJXQNWqtJFEaw1eNgwVWxCgb3usaE3TahTkHz(M3yZD9vRCeMV2vN08Du2UJM9gKpeILPvDpHF6eKOdF34CI12qc04QrO20XGkEExmoKJy3lkJ9vOOqc6hHDFQ)AlT01NXwVH(eLRt)1CICevZbFetw)EyT8QR8V2v3VUJRpqmVXcMnM73cSnwrnYfOZvNRbKyyjL4cOJtcIbLGoqIJXSl7pyvIaZgmDuNGeZTO44Ab2cWdvVjqeKcdIGfjriR8kwVfeBhcM4AldefrntNXqR3J)tLrcDkzf4FKjQi)Ff(YdmAsz03PF3NKa5l)g9B2IJprb1Zh4mbUENjuOmDAiILqzD64O)cP7YHTLqym42hG3xWaCJ7qnhT)hMlR2BM70IdXK6ZHbQLx7X(q1Ni0RfI0m6Eydj7CCCtDCLc4oJsP2H2AXMmdSojYX62KHtpIz5I1wtmoKmc3vlvmSBG)VMKrzCruXkdsVNx(fHqPqSkiTFcItgtev5xk)YpbB6B1OQ8lkPNpVbOVZ7NpjiBg5G3eNXF2fIEyv7(nIcDSvTiTzD9GEqCM9n1egjuwDWgC7ntbCT9T3jkriI(cUmL5vUaLk6XC5RTV46OgllxDS1WubugSIgJ)6pGfNlIKYRpW)7fOlH1loLT9nv0OBqJ10vmtqYGNgp)ZOzE5y(mjlgEwMbOxHCSW2(70bEiGWHC0XX0rj66VLHZhDnFvcDfXKtOwZPe68ng0vkJwi18(3VyMALu1BxjJQkJCsRVB1BsYFx97Mj9Hiqbf(drEkJ46bjZwo2hIKbK(Yl9O0p2hx)V)Mk36RXRUBG3oQUol7VAMWz4210udn6NtS0hxoiDyWrUflQdp8tDF9ZbRTkoZ7QQfdA)DjWUReUW0VC57UWkf6Tp)eQZVSkqzyCt7gYNWuTJy8tVb4TBE5fj20EvFvDSZb9Wv3YftNytFQMBFIkMGHr5QVZmvouft16yQHwBrtAJBTl5XqBTfGtboGsMjOhZRMJ6xDf1LgnPywFJDg3qcdRCTERxlpRU2TCyLDfmgOIB9wVa(xfa6JTyDXnQHxMEXel4TiRky41mJ642rqrRBhUKWsbGDMRBPd)uBZJCsr3XXQRoe1IT7fzxCkoQ8HDG7L2ZYuJO9MXK6BGpEedwnux0Ge8mdkw96KH2qtWFqA60aNZH20ZX503mgEFyZPHiJJouNoXb5QQIU1zevBQilv392C5PiUxMnhdaNybH9GMp6TCXVxXBLiZB9QBo8Q0qQRFfrMTxdURMM4SGwhU(0fO2ygZ6qGN3YzNqQN3ATEcw4FC6ehmpQRXUdWmaLUrtP2jquPx7uh6m6VxYahXzELcmP)txcT04Gk4hPSaF)KIdmYdskCc(F]] )
