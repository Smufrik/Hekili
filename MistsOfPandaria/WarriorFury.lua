-- WarriorFury.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Warrior: Fury spec

if not Hekili or not Hekili.NewSpecialization then return end

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'WARRIOR' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

-- Safe stance initialization to avoid nil checks in stance-based logic (mirrors Arms pattern).
do
    local st = rawget( Hekili, "State" )
    if st and rawget( st, "current_stance" ) == nil then
        local idx = type( GetShapeshiftForm ) == "function" and GetShapeshiftForm() or 0
        local map = { [1] = "battle", [2] = "defensive", [3] = "berserker" }
        rawset( st, "current_stance", map[ idx ] )
    end
end

-- Ensure helper references exist (mirrors pattern in Arms file) to avoid undefined global warnings.
local addStack = state and state.addStack
local removeStack = state and state.removeStack
local applyBuff, removeBuff, applyDebuff, removeDebuff = state and state.applyBuff, state and state.removeBuff, state and state.applyDebuff, state and state.removeDebuff
if not addStack then
    addStack = function(aura, target, n)
        local b = state and state.buff and state.buff[aura]
        if not b then return end
        b.stack = math.min((b.stack or 0) + (n or 1), b.max_stack or 99)
        b.up = (b.stack or 0) > 0
    end
end

if not removeStack then
    removeStack = function(aura, n)
        local b = state and state.buff and state.buff[aura]
        if not b then return end
        b.stack = math.max(0, (b.stack or 0) - (n or 1))
        if b.stack == 0 then b.up = false end
    end
end

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
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

local spec = Hekili:NewSpecialization( 72 ) -- Fury spec ID for MoP

-- Stance + spec-based rage generation (aligned with Arms baseline + Fury spec extras)
spec:RegisterResource( 1, {
    -- Baseline stance constants (rage/sec approximations for prediction)
    battle_stance_regen = {
        aura = "battle_stance",
        last = function()
            local app = state.buff.battle_stance.applied
            local t = state.query_time
            return app + floor( t - app )
        end,
        interval = 1,
        value = function() return (state.current_stance == "battle" and state.combat) and 3.5 or 0 end,
    },
    berserker_stance_regen = {
        aura = "berserker_stance",
        last = function()
            local app = state.buff.berserker_stance.applied
            local t = state.query_time
            return app + floor( t - app )
        end,
        interval = 1,
        value = function() return (state.current_stance == "berserker" and state.combat) and 1.75 or 0 end,
    },
    defensive_stance_regen = {
        aura = "defensive_stance",
        last = function()
            local app = state.buff.defensive_stance.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 3 ) * 3
        end,
        interval = 3,
        value = function() return (state.current_stance == "defensive") and 1 or 0 end,
    },

    -- Existing Fury-specific periodic/additive sources
    bloodthirst_regen = {
        last = function () return (state.last_cast_time and state.last_cast_time.bloodthirst) or 0 end,
        interval = 3,
        value = function() return (state.last_ability == "bloodthirst") and 5 or 0 end,
    },
    berserker_rage = {
        aura = "berserker_rage",
        last = function () local app = state.buff.berserker_rage.applied; local t = state.query_time; return app + floor( ( t - app ) ) end,
        interval = 1,
        value = function() return state.buff.berserker_rage.up and 7 or 0 end,
    },
    enrage_regen = {
        aura = "enrage",
        last = function () local app = state.buff.enrage.applied; local t = state.query_time; return app + floor( ( t - app ) / 2 ) * 2 end,
        interval = 2,
        value = function() return state.buff.enrage.up and 3 or 0 end,
    },
    bloodsurge_efficiency = {
        aura = "bloodsurge",
        last = function () return state.query_time end,
        interval = 1,
        value = function() return state.buff.bloodsurge.up and 30 or 0 end,
    },
}, { } )

-- ===================
-- ENHANCED COMBAT LOG EVENT TRACKING
-- ===================

local furyCombatLogFrame = CreateFrame("Frame")
local furyCombatLogEvents = {}

local function RegisterFuryCombatLogEvent(event, handler)
    if not furyCombatLogEvents[event] then
        furyCombatLogEvents[event] = {}
        furyCombatLogFrame:RegisterEvent(event)
    end
    
    tinsert(furyCombatLogEvents[event], handler)
end

furyCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = furyCombatLogEvents[event]
    if handlers then for _, handler in ipairs(handlers) do handler(event, ...) end end
end)

-- Fury-specific tracking variables
local raging_blow_casts = 0
local bloodthirst_casts = 0
local wild_strike_casts = 0
local colossus_smash_casts = 0
local berserker_rage_procs = 0
local enrage_procs = 0
local rampage_procs = 0
local execute_casts = 0

-- Enhanced Combat Log Event Handlers for Fury-specific mechanics
RegisterFuryCombatLogEvent("COMBAT_LOG_EVENT_UNFILTERED", function(event, ...)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool = CombatLogGetCurrentEventInfo()
    
    if sourceGUID == UnitGUID("player") then
        -- Track Fury-specific spell interactions
        if subEvent == "SPELL_CAST_SUCCESS" then
            if spellID == 85288 then -- Raging Blow
                raging_blow_casts = raging_blow_casts + 1
            elseif spellID == 23881 then -- Bloodthirst
                bloodthirst_casts = bloodthirst_casts + 1
            elseif spellID == 100130 then -- Wild Strike
                wild_strike_casts = wild_strike_casts + 1
            elseif spellID == 86346 then -- Colossus Smash
                colossus_smash_casts = colossus_smash_casts + 1
            elseif spellID == 5308 then -- Execute
                execute_casts = execute_casts + 1
            end
        elseif subEvent == "SPELL_AURA_APPLIED" then
            if spellID == 18499 then -- Berserker Rage
                berserker_rage_procs = berserker_rage_procs + 1
            elseif spellID == 12880 then -- Enrage
                enrage_procs = enrage_procs + 1
            elseif spellID == 29801 then -- Rampage
                rampage_procs = rampage_procs + 1
            end
        end
    end
end)

-- ===================
-- ENHANCED TIER SETS AND GEAR REGISTRATION
-- ===================

-- Comprehensive Tier Set Coverage (T14-T16 across all difficulties)
spec:RegisterGear( "tier14", 85329, 85330, 85331, 85332, 85333 ) -- Normal
spec:RegisterGear( "tier14_lfr", 89286, 89287, 89288, 89289, 89290 ) -- LFR versions
spec:RegisterGear( "tier14_heroic", 90409, 90410, 90411, 90412, 90413 ) -- Heroic versions

-- Tier 15 - Throne of Thunder
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- Normal
spec:RegisterGear( "tier15_lfr", 95267, 95268, 95269, 95270, 95271 ) -- LFR versions
spec:RegisterGear( "tier15_heroic", 96577, 96578, 96579, 96580, 96581 ) -- Heroic versions

-- Tier 16 - Siege of Orgrimmar
spec:RegisterGear( "tier16", 99357, 99358, 99359, 99360, 99361 ) -- Normal
spec:RegisterGear( "tier16_lfr", 99362, 99363, 99364, 99365, 99366 ) -- LFR versions
spec:RegisterGear( "tier16_heroic", 99367, 99368, 99369, 99370, 99371 ) -- Heroic versions
spec:RegisterGear( "tier16_mythic", 99372, 99373, 99374, 99375, 99376 ) -- Mythic versions

-- Legendary Items
spec:RegisterGear( "xuen_cloak", 102247 ) -- Xuen's Battlegear of Niuzao
spec:RegisterGear( "ordos_cloak", 102248 ) -- Ordos' Cloak of Eternal Bindings
spec:RegisterGear( "celestial_cloak", 102249 ) -- Celestial Cloak of Chi-Ji

-- Notable Fury Warrior Trinkets
spec:RegisterGear( "assurance_of_consequence", 102293 ) -- Assurance of Consequence
spec:RegisterGear( "thoks_tail_tip", 105609 ) -- Thok's Tail Tip
spec:RegisterGear( "haromms_talisman", 105579 ) -- Haromm's Talisman
spec:RegisterGear( "sigil_of_rampage", 104676 ) -- Sigil of Rampage
spec:RegisterGear( "vial_of_living_corruption", 102291 ) -- Vial of Living Corruption
spec:RegisterGear( "renatakis_soul_charm", 104780 ) -- Renataki's Soul Charm
spec:RegisterGear( "evil_eye_of_galakras", 105570 ) -- Evil Eye of Galakras

-- Fury Warrior Weapons
spec:RegisterGear( "fury_2h_weapons", 102288, 102289, 102290 ) -- Legendary/Epic 2H weapons
spec:RegisterGear( "fury_1h_weapons", 102294, 102295, 102296 ) -- Legendary/Epic 1H weapons

-- PvP Sets
spec:RegisterGear( "gladiators_battlegear", 91647, 91648, 91649, 91650, 91651 ) -- Gladiator's Battlegear
spec:RegisterGear( "tyrannical_battlegear", 94213, 94214, 94215, 94216, 94217 ) -- Tyrannical Gladiator's Battlegear

-- Challenge Mode Sets
spec:RegisterGear( "challenge_battlegear", 90713, 90714, 90715, 90716, 90717 ) -- Challenge Mode Battlegear

-- Advanced Tier Set Bonus Tracking with Generate Functions
spec:RegisterGear( "t14_2pc_fury", function()
    return set_bonus.tier14_2pc and set_bonus.tier14_2pc > 0
end, 105820 )

spec:RegisterGear( "t14_4pc_fury", function()
    return set_bonus.tier14_4pc and set_bonus.tier14_4pc > 0
end, 105821 )

spec:RegisterGear( "t15_2pc_fury", function()
    return set_bonus.tier15_2pc and set_bonus.tier15_2pc > 0
end, 138152 )

spec:RegisterGear( "t15_4pc_fury", function()
    return set_bonus.tier15_4pc and set_bonus.tier15_4pc > 0
end, 138153 )

spec:RegisterGear( "t16_2pc_fury", function()
    return set_bonus.tier16_2pc and set_bonus.tier16_2pc > 0
end, 144328 )

spec:RegisterGear( "t16_4pc_fury", function()
    return set_bonus.tier16_4pc and set_bonus.tier16_4pc > 0
end, 144329 )

-- Talents (MoP talent system - ID, enabled, spell_id)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    juggernaut                 = { 1, 1, 103826 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and generates 15 Rage.
    double_time                = { 1, 2, 103827 }, -- Your Charge ability has 2 charges, shares charges with Intervene, and no longer generates Rage.
    warbringer                 = { 1, 3, 103828 }, -- Charge also roots the target for 4 sec, and Hamstring generates more Rage.

    -- Tier 2 (Level 30) - Healing/Survival
    second_wind                = { 2, 1, 29838  }, -- While below 35% health, you regenerate 3% of your maximum health every 1 sec. Cannot be triggered if you were reduced below 35% by a creature that rewards experience or honor.
    enraged_regeneration       = { 2, 2, 55694  }, -- Instantly heals you for 10% of your total health and regenerates an additional 10% over 5 sec. Usable whilst stunned, frozen, incapacitated, feared, or asleep. 1 min cooldown.
    impending_victory          = { 2, 3, 103840 }, -- Instantly attack the target causing damage and healing you for 10% of your maximum health. Replaces Victory Rush. 30 sec cooldown.

    -- Tier 3 (Level 45) - Utility
    staggering_shout           = { 3, 1, 107566 }, -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec. 40 sec cooldown.
    piercing_howl              = { 3, 2, 12323  }, -- Causes all enemies within 10 yards to have their movement speed reduced by 50% for 15 sec. 30 sec cooldown.
    disrupting_shout           = { 3, 3, 102060 }, -- Interrupts all enemy spell casts and prevents any spell in that school from being cast for 4 sec. 40 sec cooldown.

    -- Tier 4 (Level 60) - Burst DPS
    bladestorm                 = { 4, 1, 46924  }, -- You become a whirlwind of steel, attacking all enemies within 8 yards for 6 sec, but you cannot use Auto Attack, Slam, or Execute during this time. Increases your chance to dodge by 30% for the duration. 1.5 min cooldown.
    shockwave                  = { 4, 2, 46968  }, -- Sends a wave of force in a frontal cone, causing damage and stunning enemies for 4 sec. This ability is usable in all stances. 40 sec cooldown. Cooldown reduced by 20 sec if it strikes at least 3 targets.
    dragon_roar                = { 4, 3, 118000 }, -- Roar powerfully, dealing damage to all enemies within 8 yards, knockback and disarming all enemies for 4 sec. The damage is always a critical hit. 1 min cooldown.

    -- Tier 5 (Level 75) - Survivability
    mass_spell_reflection      = { 5, 1, 114028 }, -- Reflects the next spell cast on you and all allies within 20 yards back at the caster. 1 min cooldown.
    safeguard                  = { 5, 2, 114029 }, -- Intervene also reduces all damage taken by the target by 20% for 6 sec.
    vigilance                  = { 5, 3, 114030 }, -- Focus your protective gaze on a group member, transferring 30% of damage taken to you. In addition, each time the target takes damage, cooldown on your next Taunt is reduced by 3 sec. Lasts 12 sec.

    -- Tier 6 (Level 90) - Damage
    avatar                     = { 6, 1, 107574 }, -- You transform into an unstoppable avatar, increasing damage done by 20% and removing and granting immunity to movement imparing effects for 24 sec. 3 min cooldown.
    bloodbath                  = { 6, 2, 12292  }, -- Increases damage by 30% and causes your auto attacks and damaging abilities to cause the target to bleed for an additional 30% of the damage you initially dealt over 6 sec. Lasts 12 sec. 1 min cooldown.
    storm_bolt                 = { 6, 3, 107570 }, -- Throws your weapon at the target, causing damage and stunning for 3 sec. This ability is usable in all stances. 30 sec cooldown.
} )

-- ===================
-- ENHANCED GLYPH SYSTEM - COMPREHENSIVE FURY COVERAGE
-- ===================

spec:RegisterGlyphs( {
    -- Major DPS & Core Combat Glyphs
    [58095] = "bladestorm",             -- Reduces the cooldown of your Bladestorm ability by 15 sec.
    [58100] = "raging_blow",            -- Reduces the cooldown on your Raging Blow ability by 5 sec, but reduces its damage by 20%.
    [58370] = "raging_wind",            -- Your Raging Blow also consumes the Berserker Stance effect from Colossus Smash.
    [58366] = "bloodthirst",            -- Using Bloodthirst refreshes the Strikes of Opportunity from your Taste for Blood.
    [58374] = "wild_strike",            -- Your Wild Strike now costs 5 less Rage to use.
    [58357] = "cleaving",               -- Your Cleave ability now strikes up to 3 targets.
    [58388] = "colossus_smash",         -- Your Colossus Smash ability now instantly grants you Berserker Stance.
    [58356] = "unending_rage",          -- Your Enrage effects and Berserker Rage ability last an additional 2 sec.
    [58367] = "burning_anger",          -- Increases the critical strike chance of your Thunder Clap and Shock Wave by 20%, but they cost 20 rage.
    [58375] = "resonating_power",       -- The periodic damage of your Thunder Clap ability now also causes enemies to resonate with energy, dealing 5% of the Thunder Clap damage to nearby enemies within 10 yards.
    [58368] = "thunder_strike",         -- Increases the number of targets your Thunder Clap ability hits by 50%, but reduces its damage by 20%.
    [58377] = "furious_sundering",      -- Your Sunder Armor ability now reduces the movement speed of your target by 50% for 15 sec.
    
    -- Mobility & Utility Glyphs
    [58099] = "bull_rush",              -- Your Charge ability roots the target for 1 sec.
    [58103] = "death_from_above",       -- When you use Charge, you leap into the air on a course to the target.
    [58098] = "hamstring",              -- Reduces the global cooldown triggered by your Hamstring to 0.5 sec.
    [58385] = "blitz",                  -- When you use Charge, you charge up to 3 enemies near the target.
    [58386] = "long_charge",            -- Increases the range of your Charge and Intervene abilities by 5 yards.
    [58376] = "berserker_rage",         -- Your Berserker Rage no longer causes you to become immune to Fear, Sap, or Incapacitate effects.
    [58355] = "battle",                 -- Your Battle Shout now also increases your maximum health by 3% for 1 hour.
    
    -- Defensive & Survival Glyphs
    [58096] = "bloody_healing",         -- Your Victory Rush and Impending Victory abilities heal you for an additional 10% of your max health.
    [58097] = "die_by_the_sword",       -- Increases the chance to parry of your Die by the Sword ability by 20%, but reduces its duration by 4 sec.
    [58372] = "shield_wall",            -- Reduces the cooldown of your Shield Wall ability by 2 min, but also reduces its effect by 20%.
    [58101] = "spell_reflection",       -- Reduces the cooldown of your Spell Reflection ability by 5 sec, but reduces its duration by 1 sec.
    [63324] = "victory_rush",           -- Your Victory Rush ability is usable for an additional 5 sec after the duration expires, but heals you for 50% less.
    [58378] = "defensive_stance",       -- Your Defensive Stance provides an additional 5% damage reduction, but reduces your damage dealt by 10%.
    [58379] = "intimidating_shout",     -- Your Intimidating Shout also reduces the damage dealt by affected enemies by 30% for the duration.
    [58380] = "disarm",                 -- Your Disarm ability also reduces the movement speed of the target by 50% for the duration.
    
    -- Control & CC Glyphs
    [58381] = "piercing_howl",          -- Your Piercing Howl also causes affected enemies to take 25% more damage from your abilities for 8 sec.
    [58382] = "disrupting_shout",       -- Your Disrupting Shout also silences affected enemies for an additional 2 sec.
    [58383] = "mocking_blow",           -- Your Mocking Blow forces the target to attack only you for 6 sec, but increases the damage they deal by 25%.
    [58384] = "taunt",                  -- Your Taunt ability also increases the threat generation of your next 3 abilities by 100%.
    [58387] = "rally_cry",              -- Your Rallying Cry also increases the movement speed of affected allies by 30% for 10 sec.
    
    -- Minor Visual & Convenience Glyphs
    [58389] = "warrior_spirit",         -- Your Ghost Wolf form appears as a spectral warrior.
    [58390] = "battle_standard",        -- Your Battle Standards have enhanced visual effects and last 25% longer.
    [58391] = "commanding_shout",       -- Your Commanding Shout also increases the size of affected allies by 10% for the duration.
    [58392] = "heroic_throw",           -- Your Heroic Throw returns to you after hitting the target.
    [58393] = "weapon_expertise",       -- Your weapons glow with elemental energy based on your current stance.
    [58394] = "berserker_stance",       -- Your Berserker Stance causes your eyes to glow with fury.
    [58395] = "defensive_stance",       -- Your Defensive Stance surrounds you with a protective aura.
    [58396] = "battle_stance",          -- Your Battle Stance causes weapons to appear more menacing.
    [58397] = "rage_visual",            -- Your rage bar glows more intensely when above 75 rage.
    [58398] = "fury_mastery",           -- Your critical strikes create enhanced visual effects.
} )

-- ===================
-- ADVANCED AURA SYSTEM - COMPREHENSIVE FURY TRACKING
-- ===================

spec:RegisterAuras( {
    -- Core Fury Mechanics with Enhanced Tracking
    enrage = {
        id = 12880,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12880 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Berserker Rage Tracking
    berserker_rage = {
        id = 18499,
        duration = function() return glyph.unending_rage.enabled and 8 or 6 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 18499 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Colossus Smash Tracking
    colossus_smash = {
        id = 86346,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 86346 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Raging Blow Tracking
    raging_blow = {
        id = 131116,
        duration = 12,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 131116 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Bloodthirst Tracking
    bloodthirst = {
        id = 23881,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 23881 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Bloodbath Tracking
    bloodbath = {
        id = 12292,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12292 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Avatar Tracking
    avatar = {
        id = 107574,
        duration = 24,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 107574 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Taste for Blood Tracking
    taste_for_blood = {
        id = 60503,
        duration = 9,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 60503 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Die by the Sword Tracking
    die_by_the_sword = {
        id = 118038,
        duration = function() return glyph.die_by_the_sword.enabled and 4 or 8 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118038 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Rallying Cry Tracking
    rallying_cry = {
        id = 97462,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 97462 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Battle Shout Tracking
    battle_shout = {
        id = 6673,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 6673 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Commanding Shout Tracking
    commanding_shout = {
        id = 469,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 469 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Berserker Stance Tracking
    berserker_stance = {
        id = 2458,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 2458 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Battle Stance Tracking
    battle_stance = {
        id = 2457,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 2457 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Defensive Stance Tracking
    defensive_stance = {
        id = 71,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 71 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Bladestorm Tracking
    bladestorm = {
        id = 46924,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 46924 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Intimidating Shout Tracking
    intimidating_shout = {
        id = 5246,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 5246 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Spell Reflection Tracking
    spell_reflection = {
        id = 23920,
        duration = function() return glyph.spell_reflection.enabled and 4 or 5 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 23920 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
      -- Enhanced Recklessness Tracking
    recklessness = {
        id = 1719,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1719 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Second Wind Tracking
    second_wind = {
        id = 29838,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 29838 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Enhanced Enraged Regeneration Tracking
    enraged_regeneration = {
        id = 55694,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 55694 )
            
            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end
            
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },
    
    -- Basic Buff/Debuff Tracking (Standard duration-based)
    rampage = {
        id = 29801,
        duration = 30,
        max_stack = 5,
    },
    wild_strike = {
        id = 100130,
        duration = 20,
        max_stack = 1,
    },
    shield_wall = {
        id = 871,
        duration = function() return glyph.shield_wall.enabled and 8 or 10 end,
        max_stack = 1,
    },
    last_stand = {
        id = 12975,
        duration = 20,
        max_stack = 1,
    },
    victory_rush = {
        id = 34428,
        duration = function() return glyph.victory_rush.enabled and 25 or 20 end,
        max_stack = 1,
    },
    impending_victory = {
        id = 103840,
        duration = 10,
        max_stack = 1,
    },
    sweeping_strikes = {
        id = 12328,
        duration = 10,
        max_stack = 1,
    },
    
    -- Debuff Tracking
    sunder_armor = {
        id = 7386,
        duration = 30,
        max_stack = 5,
    },
    demoralizing_shout = {
        id = 1160,
        duration = 30,
        max_stack = 1,
    },
    thunder_clap = {
        id = 6343,
        duration = 30,
        max_stack = 1,
    },
    piercing_howl = {
        id = 12323,
        duration = 15,
        max_stack = 1,
    },
    hamstring = {
        id = 1715,
        duration = 15,
        max_stack = 1,
    },
    
    -- Tier Set and Legendary Tracking
    t14_2pc_fury = {
        id = 105820,
        duration = 15,
        max_stack = 1,
    },
    t14_4pc_fury = {
        id = 105821,
        duration = 10,
        max_stack = 1,
    },
    t15_2pc_fury = {
        id = 138152,
        duration = 15,
        max_stack = 1,
    },
    t15_4pc_fury = {
        id = 138153,
        duration = 20,
        max_stack = 1,
    },
    t16_2pc_fury = {
        id = 144328,
        duration = 8,
        max_stack = 1,
    },
    t16_4pc_fury = {
        id = 144329,
        duration = 15,
        max_stack = 1,    },
} )

spec:RegisterAuras( {
    -- Unique/simple auras not previously defined above.
    meat_cleaver = {
        id = 85739,
        duration = 10,
        max_stack = 3,
    },
    bloodsurge = {
        id = 46916,
        duration = 10,
        max_stack = 1,
    },
    bloodbath_dot = {
        id = 113344,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
    },
    vigilance = {
        id = 114030,
        duration = 12,
        max_stack = 1,
    },
    mass_spell_reflection = {
        id = 114028,
        duration = 5,
        max_stack = 1,
    },
    shockwave = {
        id = 46968,
        duration = 4,
        max_stack = 1,
    },
    storm_bolt = {
        id = 107570,
        duration = 3,
        max_stack = 1,
    },
    war_banner = {
        id = 114207,
        duration = 15,
        max_stack = 1,
    },
    disrupting_shout = {
        id = 102060,
        duration = 4,
        max_stack = 1,
    },
    staggering_shout = {
        id = 107566,
        duration = 15,
        max_stack = 1,
    },
    charge_root = {
        id = 105771,
        duration = function() 
            if talent.warbringer.enabled then
                return 4
            elseif glyph.bull_rush.enabled then
                return 1
            end
            return 0
        end,
        max_stack = 1,
    },
} )

-- Fury Warrior abilities
spec:RegisterAbilities( {
    -- Core rotational abilities
    bloodthirst = {
        id = 23881,
        cast = 0,
        cooldown = 3,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 136012,
        
        handler = function()
            -- 20% chance to trigger Enrage
            if math.random() < 0.2 then
                applyBuff( "enrage" )
                if buff.raging_blow and buff.raging_blow.stack < 2 then
                    addStack( "raging_blow" )
                end
            end
            
            -- 30% chance to trigger Bloodsurge
            if math.random() < 0.3 then
                applyBuff( "bloodsurge" )
            end
            
            -- Restore 1% of max health
            local heal_amount = health.max * 0.01
            gain( heal_amount, "health" )
            
            -- Glyph of Bloodthirst
            if glyph.bloodthirst.enabled and buff.taste_for_blood.up then
                -- Refresh Taste for Blood
                buff.taste_for_blood.expires = query_time + 10
            end
        end,
    },
    
    raging_blow = {
        id = 85288,
        cast = 0,
        cooldown = function() return glyph.raging_blow.enabled and 3 or 8 end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589119,
        
        usable = function()
            return buff.raging_blow.stack > 0, "requires raging_blow buff"
        end,
        
        handler = function()
            if buff.raging_blow.stack > 1 then
                removeStack( "raging_blow" )
            else
                removeBuff( "raging_blow" )
            end
            
            -- Glyph of Raging Wind
            if glyph.raging_wind.enabled and debuff.colossus_smash.up then
                removeDebuff( "target", "colossus_smash" )
            end
        end,
    },
    
    colossus_smash = {
        id = 86346,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 464973,
        
        handler = function()
            applyDebuff( "target", "colossus_smash" )
            if glyph.colossus_smash.enabled then
                applyBuff( "enrage" )
            end
        end,
    },

    -- Major cooldown
    recklessness = {
        id = 1719,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        spend = 0,
        spendType = "rage",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 458972,

        handler = function()
            applyBuff( "recklessness" )
        end,
    },
    
    execute = {
        id = 5308,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            -- Minimum 10 rage plus additional rage up to 30
            return 10
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 135358,
        
        usable = function()
            return target.health_pct < 20, "requires target below 20% health"
        end,
        
        handler = function()
            -- No specific effect for Execute
        end,
    },
    
    wild_strike = {
        id = 100130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.bloodsurge.up then return 0 end
            if glyph.wild_strike.enabled then return 40 end
            return 45 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589617,
        
        handler = function()
            removeBuff( "bloodsurge" )
        end,
    },

    -- Rage dump; off-GCD in MoP with a short cooldown.
    heroic_strike = {
        id = 78,
        cast = 0,
        cooldown = 1.5,
        gcd = "off",

        spend = 30,
        spendType = "rage",

        startsCombat = true,
        texture = 132282,

        handler = function()
            -- No extra state to manage
        end,
    },
    
    whirlwind = {
        id = 1680,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 25,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132369,
        
        handler = function()
            -- Apply Meat Cleaver
            if not buff.meat_cleaver.up then
                applyBuff( "meat_cleaver" )
                buff.meat_cleaver.stack = 1
            else
                addStack( "meat_cleaver", nil, 1 )
            end
        end,
    },
    
    cleave = {
        id = 845,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 20,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132338,
        
        handler = function()
            -- No specific effect for Cleave
        end,
    },
    
    -- Defensive / utility
    battle_shout = {
        id = 6673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132333,
        
        handler = function()
            applyBuff( "battle_shout" )
        end,
    },
    
    commanding_shout = {
        id = 469,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            applyBuff( "commanding_shout" )
        end,
    },

    heroic_throw = {
        id = 57755,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 0,
        spendType = "rage",

        startsCombat = true,
        texture = 236171,

        handler = function()
            -- Ranged pull; no extra state
        end,
    },
    
    charge = {
        id = 100,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 20 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = 20,
        gcd = "off",
        
        spend = function()
            if talent.juggernaut.enabled then return -15 end
            return 0
        end,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = true,
        texture = 132337,
        
        handler = function()
            if talent.warbringer.enabled or glyph.bull_rush.enabled then
                applyDebuff( "target", "charge_root" )
            end
        end,
    },
    
    hamstring = {
        id = 1715,
        cast = 0,
        cooldown = 0,
        gcd = function() return glyph.hamstring.enabled and 0.5 or 1.5 end,
        
        spend = function() 
            if talent.warbringer.enabled then return 5 end
            return 10 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132316,
        
        handler = function()
            applyDebuff( "target", "hamstring" )
        end,
    },
    
    berserker_rage = {
        id = 18499,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = false,
        texture = 136009,
        
        handler = function()
            applyBuff( "berserker_rage" )
            if buff.raging_blow and buff.raging_blow.stack < 2 then
                addStack( "raging_blow" )
            end
        end,
    },
    
    heroic_leap = {
        id = 6544,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 236171,
        
        handler = function()
            -- No specific effect, just the leap
        end,
    },
    
    rallying_cry = {
        id = 97462,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132351,
        
        handler = function()
            applyBuff( "rallying_cry" )
        end,
    },
    
    die_by_the_sword = {
        id = 118038,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132336,
        
        handler = function()
            applyBuff( "die_by_the_sword" )
        end,
    },
    
    intervene = {
        id = 3411,
        cast = 0,
        cooldown = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        charges = function()
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 2
            end
            return 1
        end,
        recharge = function() 
            if talent.juggernaut.enabled or talent.double_time.enabled then
                return 20
            end
            return 30 
        end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        range = function() 
            if glyph.long_charge.enabled then
                return 30
            end
            return 25 
        end,
        
        startsCombat = false,
        texture = 132365,
        
        handler = function()
            if talent.safeguard.enabled then
                -- Apply damage reduction to the target (handled by the game)
            end
        end,
    },
    
    -- Talent abilities
    avatar = {
        id = 107574,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 613534,
        
        handler = function()
            applyBuff( "avatar" )
        end,
    },
    
    bloodbath = {
        id = 12292,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236304,
        
        handler = function()
            applyBuff( "bloodbath" )
        end,
    },
    
    bladestorm = {
        id = 46924,
        cast = 0,
        cooldown = function() return glyph.bladestorm.enabled and 75 or 90 end,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236303,
        
        handler = function()
            applyBuff( "bladestorm" )
        end,
    },
    
    dragon_roar = {
        id = 118000,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 642418,
        
        handler = function()
            applyDebuff( "target", "dragon_roar" )
        end,
    },
    
    shockwave = {
        id = 46968,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = function() 
            if glyph.burning_anger.enabled then return 20 end
            return 0 
        end,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 236312,
        
        handler = function()
            applyDebuff( "target", "shockwave" )
        end,
    },
    
    storm_bolt = {
        id = 107570,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = true,
        texture = 613535,
        
        handler = function()
            applyDebuff( "target", "storm_bolt" )
        end,
    },
    
    vigilance = {
        id = 114030,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 236331,
        
        handler = function()
            applyBuff( "vigilance" )
        end,
    },
    
    impending_victory = {
        id = 103840,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 10,
        spendType = "rage",
        
        startsCombat = true,
        texture = 589768,
        
        handler = function()
            local heal_amount = health.max * (glyph.bloody_healing.enabled and 0.2 or 0.1)
            gain( heal_amount, "health" )
        end,
    },
    
    staggering_shout = {
        id = 107566,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132346,
        
        handler = function()
            applyDebuff( "target", "staggering_shout" )
        end,
    },
    
    piercing_howl = {
        id = 12323,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132117,
        
        handler = function()
            applyDebuff( "target", "piercing_howl" )
        end,
    },
    
    disrupting_shout = {
        id = 102060,
        cast = 0,
        cooldown = 40,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "interrupts",
        
        startsCombat = true,
        texture = 132117,
        
        handler = function()
            applyDebuff( "target", "disrupting_shout" )
        end,
    },

    -- Interrupt
    pummel = {
        id = 6552,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        spend = 0,
        spendType = "rage",

        toggle = "interrupts",

        startsCombat = true,
        texture = 132938,

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            -- Interrupt handled by engine
        end,
    },
    
    enraged_regeneration = {
        id = 55694,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132345,
        
        handler = function()
            local instant_heal = health.max * 0.1
            gain( instant_heal, "health" )
            applyBuff( "enraged_regeneration" )
        end,
    },
    
    spell_reflection = {
        id = 23920,
        cast = 0,
        cooldown = function() return glyph.spell_reflection.enabled and 20 or 25 end,
        gcd = "off",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132361,
        
        handler = function()
            applyBuff( "spell_reflection" )
        end,
    },
    
    mass_spell_reflection = {
        id = 114028,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132361,
        
        handler = function()
            applyBuff( "mass_spell_reflection" )
        end,
    },
    
    war_banner = {
        id = 114207,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 603532,
        
        handler = function()
            applyBuff( "war_banner" )
        end,
    },
    
    thunder_clap = {
        id = 6343,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = function() 
            if glyph.burning_anger.enabled then return 20 end
            return 0 
        end,
        spendType = "rage",
        
        startsCombat = true,
        texture = 136105,
        
        handler = function()
            -- Apply debuff
        end,
    },
    
    intimidating_shout = {
        id = 5246,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132154,
        
        handler = function()
            applyDebuff( "target", "intimidating_shout" )
        end,
    },
    
    demoralizing_shout = {
        id = 1160,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0,
        spendType = "rage",
        
        startsCombat = true,
        texture = 132366,
        
        handler = function()
            applyDebuff( "target", "demoralizing_shout" )
        end,
    },
} )

-- Range
spec:RegisterRanges( "bloodthirst", "charge", "heroic_throw" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "mogu_power_potion",
    
    package = "Fury",
} )

-- Default pack for MoP Fury Warrior
spec:RegisterPack( "Fury", 20250515, [[Hekili:TznBVTTnu4FlXjHjMjENnWUYJaUcMLf8KvAm7nYjPPQonGwX2jzlkiuQumzkaLRQiQOeH9an1Y0YnpYoWgwlYFltwGtRJ(aiCN9tobHNVH)8TCgF)(5ElyJlFNlcDnPXD5A8j0)(MNZajDa3aNjp2QphnPtoKvyF)GcKKOzjI08QjnOVOCXMj3nE)waT58Pw(aFm0P)MM]] )

-- Register pack selector for Fury

spec:RegisterStateExpr( "stance_rage_per_second", function()
    local stance = state.current_stance
    if stance == "battle" then
        return state.combat and 3.5 or 0
    elseif stance == "berserker" then
        return state.combat and 1.75 or 0
    elseif stance == "defensive" then
        return 1/3
    end
    return 0
end )
