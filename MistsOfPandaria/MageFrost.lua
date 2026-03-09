-- MageFrost.lua
-- Updated October 1, 2025 - Modern Structure
-- Mists of Pandaria module for Mage: Frost spec

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

local spec = Hekili:NewSpecialization( 64, true )

-- Register resources
spec:RegisterResource( 0 ) -- Mana = 0 in MoP

-- ===================
-- ENHANCED COMBAT LOG EVENT TRACKING
-- ===================

local frostCombatLogFrame = CreateFrame("Frame")
local frostCombatLogEvents = {}

local function RegisterFrostCombatLogEvent(event, handler)
    if not frostCombatLogEvents[event] then
        frostCombatLogEvents[event] = {}
        frostCombatLogFrame:RegisterEvent(event)
    end
    
    tinsert(frostCombatLogEvents[event], handler)
end

frostCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = frostCombatLogEvents[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(event, ...)
        end
    end
end)

-- Frost-specific tracking variables
local frostbolt_casts = 0
local brain_freeze_procs = 0
local fingers_of_frost_procs = 0
local icy_veins_activations = 0
local water_elemental_summoned = 0

-- MageFrost.lua -- REPLACEMENT COMBAT LOG HANDLER
-- This new handler uses more precise logic to track events without relying on the core files.

RegisterFrostCombatLogEvent("COMBAT_LOG_EVENT_UNFILTERED", function(event, ...)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, auraType, amount = CombatLogGetCurrentEventInfo()
    
    local playerGUID = UnitGUID("player")
    local petGUID = UnitGUID("pet")
    local now = GetTime()
    local event_processed = false

    -- Only process events that are either FROM the player/pet or TO the player.
    if sourceGUID ~= playerGUID and destGUID ~= playerGUID and (not petGUID or sourceGUID ~= petGUID) then
        return
    end

    -- 1. AURA MANAGEMENT (PROCS GAINED/LOST) - Auras applied TO the player.
    if destGUID == playerGUID and (subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_AURA_REMOVED") then
        local aura = class.auras[spellId]
        if aura then
            event_processed = true
            -- No need to manually call applyBuff here, as the state reset will scrape auras.
            -- We just need to ensure an update is triggered.
        end
    end

    -- 2. PLAYER ACTIONS - Events caused BY the player.
    if sourceGUID == playerGUID then
        local ability = class.abilities[spellId]
        if not ability then return end -- Only track abilities Hekili knows.

        event_processed = true -- Any known player action should trigger an update.

        -- This is the CRITICAL part: interacting with Hekili's internal event queue.
        if subEvent == "SPELL_CAST_SUCCESS" then
            state:RemoveSpellEvent(ability.key, true, "CAST_FINISH") -- Remove the predicted cast finish event.

            if ability.channeled then
                local _, _, _, start, finish = UnitChannelInfo("player")
                if start then
                    start, finish = start / 1000, finish / 1000
                    state:QueueEvent(ability.key, start, finish, "CHANNEL_FINISH", destGUID, true)
                    
                    local tick_time = ability.tick_time or (ability.aura and class.auras[ability.aura].tick_time)
                    if tick_time and tick_time > 0 then
                        local current_tick = start + tick_time
                        while current_tick < finish do
                            state:QueueEvent(ability.key, start, current_tick, "CHANNEL_TICK", destGUID, true)
                            current_tick = current_tick + tick_time
                        end
                    end
                end
            end
            
            -- Queue a projectile impact if necessary.
            if ability.isProjectile and not state:IsInFlight(ability.key, true) then
                local travelTime = ability.flightTime or (state.target.maxR / (ability.velocity or 40))
                state:QueueEvent(ability.impactSpell or ability.key, now, travelTime, "PROJECTILE_IMPACT", destGUID, true)
            end

            state:AddToHistory(ability.key, destGUID)

        elseif subEvent == "SPELL_CAST_FAILED" then
            if state:RemoveSpellEvent(ability.key, true, "CAST_FINISH") then
                if ability.isProjectile then state:RemoveSpellEvent(ability.key, true, "PROJECTILE_IMPACT", true) end
            end

        elseif subEvent == "SPELL_DAMAGE" then
            -- If this damage event was from a projectile, remove it from the queue.
            if state:RemoveSpellEvent(ability.key, true, "PROJECTILE_IMPACT") then
                -- A projectile impact is a significant state change.
                event_processed = true
            end
        end
    end

    -- If any relevant event was processed, force Hekili to update its recommendations.
    if event_processed then
        Hekili:ForceUpdate(subEvent)
    end
end)

    -- Tier 14 - Regalia of the Burning Scroll (Complete Coverage)
    spec:RegisterGear( "tier14", 85370, 85371, 85372, 85373, 85369 ) -- Normal
    spec:RegisterGear( "tier14_lfr", 89335, 89336, 89337, 89338, 89339 ) -- LFR versions
    spec:RegisterGear( "tier14_heroic", 90465, 90466, 90467, 90468, 90469 ) -- Heroic versions

    -- Tier 15 - Kirin Tor Garb (Complete Coverage)
    spec:RegisterGear( "tier15", 95893, 95894, 95895, 95897, 95892 ) -- Normal
    spec:RegisterGear( "tier15_lfr", 95316, 95317, 95318, 95319, 95320 ) -- LFR versions
    spec:RegisterGear( "tier15_heroic", 96626, 96627, 96628, 96629, 96630 ) -- Heroic versions
    spec:RegisterGear( "tier15_thunderforged", 97261, 97262, 97263, 97264, 97265 ) -- Thunderforged versions

    -- Tier 16 - Chronomancer Regalia (Complete Coverage)
    spec:RegisterGear( "tier16", 99125, 99126, 99127, 99128, 99129 ) -- Normal
    spec:RegisterGear( "tier16_lfr", 99780, 99781, 99782, 99783, 99784 ) -- LFR versions
    spec:RegisterGear( "tier16_flex", 100290, 100291, 100292, 100293, 100294 ) -- Flexible versions
    spec:RegisterGear( "tier16_heroic", 100945, 100946, 100947, 100948, 100949 ) -- Heroic versions
    spec:RegisterGear( "tier16_heroic_tf", 101610, 101611, 101612, 101613, 101614 ) -- Heroic Thunderforged versions (was Mythic)

    -- Legendary Items (MoP specific)
    spec:RegisterGear( "legendary_cloak", 102246 ) -- Jina-Kang, Kindness of Chi-Ji (DPS version)
    spec:RegisterGear( "legendary_meta_gem", 101817 ) -- Capacitive Primal Diamond

    -- Notable Trinkets and Weapons (Frost-specific)
    spec:RegisterGear( "unerring_vision_of_lei_shen", 94530 ) -- Throne of Thunder trinket
    spec:RegisterGear( "breath_of_the_hydra", 105609 ) -- SoO trinket
    spec:RegisterGear( "dysmorphic_samophlange_of_discontinuity", 105691 ) -- SoO trinket
    spec:RegisterGear( "haromms_talisman", 102664 ) -- SoO trinket
    spec:RegisterGear( "purified_bindings_of_immerseus", 102293 ) -- SoO trinket

    -- Frost Weapons
    spec:RegisterGear( "gao_lei_shao_do", 89235 ) -- MSV staff
    spec:RegisterGear( "nadagast_exsanguinator", 87652 ) -- HoF dagger
    spec:RegisterGear( "torall_rod_of_the_endless_storm", 95939 ) -- ToT staff
    spec:RegisterGear( "xing_ho_breath_of_yu_lon", 104555 ) -- SoO staff
    spec:RegisterGear( "kardris_toxic_totem", 103988 ) -- SoO weapon

    -- PvP Sets (Arena/RBG specific)
    spec:RegisterGear( "malevolent_gladiator", 84407, 84408, 84409, 84410, 84411 ) -- Season 12
    spec:RegisterGear( "tyrannical_gladiator", 91677, 91678, 91679, 91680, 91681 ) -- Season 13
    spec:RegisterGear( "grievous_gladiator", 100050, 100051, 100052, 100053, 100054 ) -- Season 14
    spec:RegisterGear( "prideful_gladiator", 103036, 103037, 103038, 103039, 103040 ) -- Season 15

    -- Challenge Mode Sets
    spec:RegisterGear( "challenge_mode", 90318, 90319, 90320, 90321, 90322 ) -- Ethereal set
    spec:RegisterGear( "challenge_mode_weapons", 90431, 90432, 90433 ) -- Challenge Mode weapons

    -- Notable Meta Gems and Enchants
    spec:RegisterGear( "capacitive_primal_diamond", 101817 ) -- Legendary meta gem
    spec:RegisterGear( "burning_primal_diamond", 76884 ) -- Primary meta gem for Frost
    spec:RegisterGear( "ember_primal_diamond", 76895 ) -- Alternative meta gem

    -- Corrected T15 2pc Bonus Aura
    spec:RegisterAura( "tier15_2pc_frost", {
        id = 138302, -- Arcane Potency
        duration = 15,
        max_stack = 5,
    } )

    -- Advanced tier set bonus tracking with generate functions
    local function check_tier_bonus(tier, pieces)
        return function()
            local count = 0
            local gear_set = spec.gear[tier] or {}
            for itemID in pairs(gear_set) do
                if IsEquippedItem(itemID) then
                    count = count + 1
                end
            end
            return count >= pieces
        end
    end

    spec:RegisterGear( "tier14_2pc", nil, {
        generate = check_tier_bonus("tier14", 2)
    } )

    spec:RegisterGear( "tier14_4pc", nil, {
        generate = check_tier_bonus("tier14", 4)
    } )

    spec:RegisterGear( "tier15_2pc", nil, {
        generate = check_tier_bonus("tier15", 2)
    } )

    spec:RegisterGear( "tier15_4pc", nil, {
        generate = check_tier_bonus("tier15", 4)
    } )

    spec:RegisterGear( "tier16_2pc", nil, {
        generate = check_tier_bonus("tier16", 2)
    } )

    spec:RegisterGear( "tier16_4pc", nil, {
        generate = check_tier_bonus("tier16", 4)
    } )

    -- Talents (MoP 6-tier system)
    spec:RegisterTalents( {
        -- Tier 1 (Level 15) - Mobility/Instant Cast
        presence_of_mind      = { 1, 1, 12043 }, -- Your next Mage spell with a cast time less than 10 sec becomes an instant cast spell.
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

    -- Glyphs
    spec:RegisterGlyphs( {
        -- Major Glyphs
        [104035] = "Glyph of Arcane Explosion",
        [104036] = "Glyph of Arcane Power",
        [104037] = "Glyph of Armors",
        [104038] = "Glyph of Blink",
        [104039] = "Glyph of Combustion",
        [104040] = "Glyph of Cone of Cold",
        [104041] = "Glyph of Dragon's Breath",
        [104042] = "Glyph of Evocation",
        [104043] = "Glyph of Frost Armor",
        [104044] = "Glyph of Frost Nova",
        [104045] = "Glyph of Frostbolt",
        [104046] = "Glyph of Frostfire",
        [104047] = "Glyph of Frostfire Bolt",
        [104048] = "Glyph of Ice Block",
        [104049] = "Glyph of Ice Lance",
        [104050] = "Glyph of Icy Veins",
        [104051] = "Glyph of Inferno Blast",
        [104052] = "Glyph of Invisibility",
        [104053] = "Glyph of Mage Armor",
        [104054] = "Glyph of Mana Gem",
        [104055] = "Glyph of Mirror Image",
        [104056] = "Glyph of Polymorph",
        [104057] = "Glyph of Remove Curse",
        [104058] = "Glyph of Slow Fall",
        [104059] = "Glyph of Spellsteal",
        [104060] = "Glyph of Water Elemental",
        [56372] = "Glyph of Splitting Ice", -- MoP Glyph ID
        [56377] = "Glyph of Icy Veins", -- MoP Glyph Spell ID
        -- Minor Glyphs
        [104061] = "Glyph of Illusion",
        [104062] = "Glyph of Momentum",
        [104063] = "Glyph of the Bear Cub",
        [104064] = "Glyph of the Monkey",
        [104065] = "Glyph of the Penquin",
        [104066] = "Glyph of the Porcupine",
    } )

    -- Auras
    spec:RegisterAuras( {
        -- Frost-specific Auras
        
        frozen = {
            id = 33395, -- Shared Freeze effect from pet
            duration = 5,
            max_stack = 1
        },
        
        -- Shared Mage Auras
        arcane_brilliance = {
            id = 1459,
            duration = 3600,
            max_stack = 1
        },
        
        alter_time = {
            id = 110909,
            duration = 6,
            max_stack = 1
        },
        
        blink = {
            id = 1953,
            duration = 0.3,
            max_stack = 1
        },
        
        polymorph = {
            id = 118,
            duration = 60,
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
        
        ice_block = {
            id = 45438,
            duration = 10,
            max_stack = 1
        },
        
        ice_barrier = {
            id = 11426,
            duration = 60,
            max_stack = 1,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 11426 )
                
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
            end
        },
        
        icy_veins = {
            id = 12472,
            duration = 20,
            max_stack = 1
        },

        invokers_energy = {
            id = 116257, -- Invocation damage buff after Evocation
            duration = 40,
            max_stack = 1
        },
        
        incanter_s_ward = {
            id = 1463,
            duration = 15,
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
        
        presence_of_mind = {
            id = 12043,
            duration = 10,
            max_stack = 1
        },
        
        ring_of_frost = {
            id = 113724,
            duration = 10,
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
        },
          molten_armor = {
            id = 30482,
            duration = 1800,
            max_stack = 1
        },
        
        -- ENHANCED FROST-SPECIFIC AURA TRACKING
        -- Advanced aura system with extensive generate functions for Frost optimization
        
        -- Core Frost Procs and Mechanics
        brain_freeze = {
            id = 57761,
            copy = 44549,
            duration = 15,
            max_stack = 1,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 57761 )
                
                if not name then
                    name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 44549 )
                end
                
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
        
        fingers_of_frost = {
            id = 44544,
            duration = 15,
            max_stack = 2,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 44544 )
                
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
        
        -- Enhanced Deep Freeze tracking with shatter mechanics
        deep_freeze = {
            id = 44572,
            duration = 5,
            max_stack = 1,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 44572 )
                
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
        
        -- Frost Bomb dot tracking
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
        
        blizzard = {
            id = 10,
            duration = 8,
            max_stack = 1,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 10 )
                
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
        
        -- Living Bomb tracking (if talented)
        living_bomb = {
            id = 44457,
            duration = 12,
            max_stack = 1,
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
        
        -- Enhanced Frozen Orb tracking
        frozen_orb = {
            id = 84714,
            duration = 10,
            max_stack = 1,
            generate = function( t )
                -- Frozen Orb is not a player buff in MoP, this logic is for tracking the cooldown/debuff on targets
                -- This generate function is left for potential future logic, but won't find a player buff.
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end
        },
        
        -- MoP Talent Coordination - Enhanced tracking
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
        
        -- Enhanced Glyph Coordination
        glyph_of_icy_veins = {
            duration = 20,
            max_stack = 1,
            generate = function( t )
                if not IsPlayerSpell( 56377 ) then -- Check if glyph is learned (spell id for the glyph effect)
                    t.count = 0
                    t.expires = 0
                    t.applied = 0
                    t.caster = "nobody"
                    return
                end
    
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12472 )
    
                if name then
                    t.name = "Enhanced Icy Veins"
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
        
        glyph_of_splitting_ice = {
            duration = 0,
            max_stack = 1,
            generate = function( t )
                if IsPlayerSpell( 56372 ) then
                    t.name = "Glyph of Splitting Ice"
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
        mana_shield = {
            id = 1463,
            duration = 60,
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
        
        -- Enhanced CC and Control Effects
        ring_of_frost_freeze = {
            id = 82691,
            duration = 10,
            max_stack = 1,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 82691 )
                
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
        
        frostjaw = {
            id = 102051,
            duration = 8,
            max_stack = 1,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 102051 )
                
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
        
        -- Enhanced Pet Tracking
        water_elemental = {
            id = 31687,
            duration = 45,
            max_stack = 1,
            generate = function( t )
                if UnitExists("pet") and UnitCreatureType("pet") == "Elemental" then
                    t.name = "Water Elemental"
                    t.count = 1
                    t.expires = GetTime() + 45 -- Approximate remaining duration
                    t.applied = GetTime() - 1
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
        
        ice_floes_buff = {
            -- Keep aura key distinct from the castable ability key (`ice_floes`) to avoid key collisions.
            id = 108839,
            duration = 15,
            max_stack = 3,
            copy = "ice_floes",
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
        tier14_2pc_frost = {
            duration = 0,
            max_stack = 1,
            generate = function( t )
                if state.gear.tier14_2pc.equipped then
                    t.name = "T14 2PC Frost"
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
        
        tier15_4pc_frost = {
            duration = 0,
            max_stack = 1,
            generate = function( t )
                if state.gear.tier15_4pc.equipped then
                    t.name = "T15 4PC Frost"
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
                if not state.gear.legendary_meta_gem.equipped then
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
    } )

    -- Spell Power Calculations and State Expressions
    spec:RegisterStateExpr( "spell_power", function()
        return GetSpellBonusDamage(5) -- Frost school
    end )

    spec:RegisterStateExpr( "brain_freeze_bonus", function()
        return state.buff.brain_freeze.up and 0.2 or 0 -- 20% damage bonus
    end )

    spec:RegisterStateExpr( "fingers_of_frost_bonus", function()
        return state.buff.fingers_of_frost.up and 0.15 or 0 -- 15% damage bonus
    end )

    spec:RegisterStateExpr( "icy_veins_bonus", function()
        return state.buff.icy_veins.up and 0.2 or 0 -- 20% damage bonus
    end )

    -- Abilities
    spec:RegisterAbilities( {
        -- Frost Core Abilities
        mirror_image = {
            id = 55342,
            cast = 0,
            cooldown = 120,
            gcd = "off",
            toggle = "cooldowns",
            startsCombat = true,
            texture = 135994,
        },
        
        freeze = {
            id = 33395, -- Spell ID for Water Elemental's Freeze
            cast = 0,
            cooldown = 25,
            gcd = "off",
            startsCombat = true,
            texture = 135848, -- Icon: Spell_Frost_FrostNova
            usable = function()
                -- Ensures the pet is active and able to cast.
                return state.pet.water_elemental.up
            end,
        },
        frostbolt = {
            id = 116,
            cast = 2,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.04,
            spendType = "mana",
            
            startsCombat = true,
            texture = 135846,
            
            handler = function()
                -- Logic handled by combat log events for procs
            end,
        },
        
        frost_bomb = {
            id = 112948,
            cast = 1.5,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.06,
            spendType = "mana",
            
            startsCombat = true,
            texture = 609814,
            
            talent = "frost_bomb",
            
            handler = function()
                applyDebuff( "target", "frost_bomb" )
            end,
        },
        
        frozen_orb = {
            id = 84714,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            
            spend = 0.03,
            spendType = "mana",
            
            startsCombat = true,
            texture = 629077,
            
            toggle = "cooldowns",
            
            handler = function()
                applyBuff( "frozen_orb" )
            end,
        },
        
        ice_lance = {
            id = 30455,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.02,
            spendType = "mana",
            
            startsCombat = true,
            texture = 135844,
            
            handler = function()
                if state.buff.fingers_of_frost.up then
                    state.removeStack( "fingers_of_frost" )
                end
            end,
        },
         freeze = {
            id = 33395, -- Spell ID for Water Elemental's Freeze
            cast = 0,
            cooldown = 25,
            gcd = "off",
            
            startsCombat = true,
            texture = 135848, -- Icon: Spell_Frost_FrostNova
            
            -- This is a pet ability.
            handler = function()
                -- This action instructs the pet to use Freeze.
            end,
            
            usable = function()
                -- Ensures the pet is active and able to cast.
                return pet.alive
            end,
        },
        
        deep_freeze = {
            id = 44572,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            
            spend = 0.04,
            spendType = "mana",
            
            startsCombat = true,
            texture = 236214,
            
            toggle = "cooldowns",
            
            handler = function()
                applyDebuff( "target", "deep_freeze" )
            end,
        },
        
        frostfire_bolt = {
            id = 44614,
            cast = function() return state.buff.brain_freeze.up and 0 or 2 end,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.04,
            spendType = "mana",
            
            startsCombat = true,
            texture = select( 3, GetSpellInfo( 44614 ) ) or "Interface\\Icons\\Spell_Frost_FrostFireBolt02",

            -- In MoP, Frostfire Bolt may be effectively "proc-only" for Frost.
            -- Treat it as known while Brain Freeze is active so it can be recommended.
            known = function()
                return state.buff.brain_freeze.up or state.IsSpellKnownOrOverridesKnown(44614, true)
            end,

            usable = function()
                return state.buff.brain_freeze.up
            end,
            
            handler = function()
                if buff.brain_freeze.up then
                    removeBuff( "brain_freeze" )
                end
            end,
        },
        
        icy_veins = {
            id = 12472,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            
            toggle = "cooldowns",
            
            startsCombat = false,
            texture = 135838,
            
            handler = function()
                applyBuff( "icy_veins" )
            end,
        },
        
        cold_snap = {
            id = 11958,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            
            toggle = "cooldowns",
            
            startsCombat = false,
            texture = 135865,
            
            talent = "cold_snap",
            
            handler = function()
                state.setCooldown( "frost_nova", 0 )
                state.setCooldown( "ice_barrier", 0 )
                state.setCooldown( "ice_block", 0 )
                state.setCooldown( "icy_veins", 0 )
                
                -- Heal for 25% of max health
                state.gain( state.health.max * 0.25, "health" )
            end,
        },
        
        summon_water_elemental = {
            id = 31687,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            
            spend = 0.16,
            spendType = "mana",
            
            startsCombat = false,
            texture = 135862,
            
            essential = true,
            
            usable = function()
                -- Primary source of truth is the registered pet token.
                -- Fall back to the real pet unit, in case pet ID matching fails or the pet model changes.
                -- Prefer the tracked pet state (same pattern hunters use).
                local pet = state.pet
                local petUp = (pet.water_elemental and pet.water_elemental.up) or pet.alive

                if not petUp then
                    -- Fallback to direct unit queries when the tracker is not populated.
                    local hasUnitExists = type( UnitExists ) == "function"
                    local hasUnitHealth = type( UnitHealth ) == "function"

                    if hasUnitExists and hasUnitHealth then
                        local hasUnitIsDeadOrGhost = type( UnitIsDeadOrGhost ) == "function"
                        local hasUnitIsDead = type( UnitIsDead ) == "function"

                        local petDead = false
                        if hasUnitIsDeadOrGhost then
                            petDead = UnitIsDeadOrGhost( "pet" )
                        elseif hasUnitIsDead then
                            petDead = UnitIsDead( "pet" )
                        end

                        if not petDead then
                            petUp = UnitExists( "pet" ) and UnitHealth( "pet" ) > 0
                        end
                    end
                end

                return not petUp, "water elemental already summoned"
            end,
            
            handler = function()
                state.summonPet( "water_elemental" )
            end,
        },
        
        -- Shared Mage Abilities
        arcane_brilliance = {
            id = 1459,
            name = "Arcane Brilliance",
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 0.04,
            spendType = "mana",
            startsCombat = false,
            texture = 135932,
            usable = function()
                return not ( buff.arcane_brilliance.up or FindUnitBuffByID( "player", 1459 ) )
            end,
            -- CRITICAL FIX: The handler tells Hekili the buff is now active.
            handler = function()
                -- Apply a virtual buff with a 3600-second (1 hour) duration.
                applyBuff("arcane_brilliance", 3600)
            end,
        },
        
        alter_time = {
            id = 108978,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            
            toggle = "cooldowns",
            
            startsCombat = false,
            texture = select( 3, GetSpellInfo( 108978 ) ) or 607849,
            
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
        
        arcane_explosion = {
            id = 1449,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.22,
            spendType = "mana",
            
            startsCombat = true,
            texture = 136116,
            
            handler = function()
                -- AoE damage around the caster
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
            
            talent = function() return not state.talent.rune_of_power.enabled end,
            
            handler = function()
                -- Restore 60% mana over 6 sec
                state.gain( 0.6 * state.mana.max, "mana" )
                
                if state.talent.invocation.enabled then
                    applyBuff( "invokers_energy", 40 )
                end
            end,
        },
        
        frost_nova = {
            id = 122,
            cast = 0,
            cooldown = function() return state.talent.ice_ward.enabled and 20 or 30 end,
            charges = function() return state.talent.ice_ward.enabled and 2 or nil end,
            recharge = function() return state.talent.ice_ward.enabled and 20 or nil end,
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
                state.setCooldown( "hypothermia", 30 )
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
            
            toggle = "defensives",
            
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
            
            toggle = "defensives",
            
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
                applyBuff( "rune_of_power" )
            end,
        },
        
        slow = {
            id = 31589,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.02,
            spendType = "mana",
            
            startsCombat = true,
            texture = 136091,
            
            handler = function()
                applyDebuff( "target", "slow" )
            end,
        },
        
        slow_fall = {
            id = 130,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.01,
            spendType = "mana",
            
            startsCombat = false,
            texture = 135992,
            
            handler = function()
                applyBuff( "slow_fall" )
            end,
        },
        
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
        
        blizzard = {
            id = 10,
            cast = 8,
            channeled = true,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.08,
            spendType = "mana",
            
            startsCombat = true,
            texture = 135857,
            
            handler = function()
                applyDebuff( "target", "blizzard" )
            end,
        },
        
        nether_tempest = {
            id = 114923,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.04,
            spendType = "mana",
            
            startsCombat = true,
            texture = 610472,
            
            talent = "nether_tempest",
            
            handler = function()
                applyDebuff( "target", "nether_tempest" )
            end,
        },
        
        living_bomb = {
            id = 44457,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.04,
            spendType = "mana",
            
            startsCombat = true,
            texture = select( 3, GetSpellInfo( 44457 ) ) or 236220,
            
            talent = "living_bomb",
            
            handler = function()
                applyDebuff( "target", "living_bomb" )
            end,
        },
    } )

    -- Water Elemental Abilities
    -- Use a dynamic ID derived from the player's current pet GUID.
    -- This avoids repeated summon recommendations when the hard-coded NPC id doesn't match MoP Classic.
    spec:RegisterPet( "water_elemental", function()
        local guid = UnitGUID("pet")
        if not guid then return 0 end
        local pid = guid:match("%-(%d+)%-[0-9A-F]+$")
        return pid and tonumber(pid) or 0
    end, "summon_water_elemental", 600 )


    -- State Functions and Expressions
    spec:RegisterStateExpr( "brain_freeze_active", function()
        return state.buff.brain_freeze.up
    end )

    spec:RegisterStateExpr( "fingers_of_frost_active", function()
        return state.buff.fingers_of_frost.up
    end )

    spec:RegisterStateTable( "frost_info", {
        -- For Virtual Fingers of Frost / Brain Freeze procs
    } )

    -- Range
    spec:RegisterRanges( "frostbolt", "polymorph", "blink" )

    -- Options
    spec:RegisterOptions( {
        enabled = true,
        
        aoe = 3,
        
        nameplates = true,
        nameplateRange = 40,
        
        damage = true,
        damageExpiration = 8,
        
        potion = "jade_serpent_potion",
        
        package = "Frost",
    } )

    -- Essential Frost Mage settings
    spec:RegisterSetting( "aoe_enemy_threshold", 3, {
        name = "AoE Enemy Threshold",
        desc = "Number of enemies at which AoE abilities like Blizzard should be used (default: 3)",
        type = "range",
        min = 2,
        max = 6,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "evocation_mana_threshold", 45, {
        name = "Evocation Mana Threshold",
        desc = "Mana percentage below which Evocation should be used (default: 45%)",
        type = "range",
        min = 20,
        max = 80,
        step = 5,
        width = 1.5
    } )

    spec:RegisterSetting( "water_elemental_freeze", true, {
        name = "Water Elemental Freeze",
        desc = "If checked, Water Elemental's Freeze will be recommended when Fingers of Frost stacks are low",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "ice_lance_moving", true, {
        name = "Ice Lance While Moving",
        desc = "If checked, Ice Lance will be recommended while moving as a fallback option",
        type = "toggle",
        width = "full"
    } )


-- Register default pack for MoP Frost Mage
-- Updated March 3, 2026 - Synced with exported MageFrost.simc profile
spec:RegisterPack( "Frost", 20260303, [[Hekili:vRvBZTjss4FlPsv(SYAtSKJCU8Isvjzpxx8LnBQfF1(njHGbRznWWnawrPCXV9R7EgqWWGKCSZUz)qITHz6PFVF6Pz6WPxo1nWlNn9tJoz0zNC6jVWz0jNoE8lM6MVoLn1n1Z)AVRGFjXlg()ZLISC8PRJeEb4UZefsF4ntDxuWJY)qY0f2i5Zg9SPUEf5lfYPUUXfHs(1tDxYdcyQDWY8N6E5sEw5C8FELZ1hD5Cri83(5Crs58iEwo86qHSC()MDnpI7m1LEijkSqVIOC4x)ejASeVfrSGPVtDasEksLPU)I4gwmljxrpGCCj(Jd)GpCCNhjyWrO2l8lKmVqebly1sEeSIyXn8KRgaNSITM667ffnt9hZqscprYZzsU3ux1QvC5mLAmwF(tZbTKbJwrYCjp5Aw(qqfhjYB(3Bi9IIWqhU)6z3W4jzofPLZV92Y50Jxejebrfz51p2xiIceRsC8IG9plNhZCKmVG1gANFn54ImqmHtjo7LGUpnvk(cpgmQLZ)DXV7YJrlurUW3ll)xZxYKVxtA45hgis(hGUkl1lgTDHh7V2pIbAlqypD7c7OVlcxl93iKnE22Co(nrbkO5IY5Vv8VQCr8G)D6pbp2tEflp7iq0qbFfh1uK6Y9YN((iM3nm1w2tVd8X3WMXsyXC0B7ntGZPLZINGH884EuDDjEJ9MHUyyaRK5lIx4zn0OIsEsFVe2SfsEue3lbJQBh1arJVuhpa25Fr85bLZpU2L4yVi(vjSaq1CfC4PrERpgSai3W9H1FHhe)I5eu7Qkg84mVqqLTINVSCEZaqynFwk8rpjwsaecPYmKiqNRcWNKLLXcahI1GHcn6LZVeS6GjIhtRgiWh5xTew(5IZH8jGhc9CrseSLeMN0yJWgA57JcsoEehwjIz5RXeav((nJnavKsWCbEtiXSuF8DLZFA58pDj9JZH)AHe0Rlzzn9aEK2NUJ6h8TTLGO7odrlYmpzSqI7P2G2452c(ArOuwUZkpm0Hfr2fVihLV5g6LvehdEzglRH3ff2n1D4yBbzvujMlLc5mqNH1vm37zoJT5TVHxHteowhEYnGjaPOt1YQpbw1R6sEI4NTlIlladHiCwQyft2L(TED3Z4uLi8CJtrfr(hEbSzzmzkM(VMIPc7SlLT6F2JImSQWK99LRsDS)1c7wfCaeldz5s0zctLCbOQG8u7zYT7yPpJSn)bwKNo48LsrXvltlY3KOptZWoTuiFLLmtixu7Ux9Q66inpWT4KgXroF2cqPccewaBMoZpQoDJ9(YS2p19ul(rnOsLxu58dQkI4G2Qz5IzbCMkXFGO9EGeNxtw0Y5pbklq79r2xgPNnuGCi8KNGhxezGXfJ4RGhfdWK4hR5JTvEjHHL5MbPdtzKXDF0fJTOlAtOwQdTizSIkPAFcyvz66ONrcZAKIKwq3mKKv2seBRvboBqYzkARLAUrnkMuRDvoTcabXH(IKmW7N0)QACUxIihnW5afg4jZcLm2xRY7Bg2BSJqq3ahiMhI4VwYf3NnlIkHde6f9iwlI4F9REYadbIy(qOiejohEnJLIrDjqsRB8WccqsbjdJJlN)EX7F6BHLxKaqLHvVwuaiN)sAe3NNJvzx5HcoyxJBl02G9qznhEsZW2gP4Ag2MtiB2cuMgva6jM4d11pGI4jbOi5dIeKXj2lb7(qku8y06UwlS4Z1OYh4F5vRbGMXarbX41GyGaduPH3AXB8yC8lKsY1a34ZgFYjNytg2cWzJsrTe2)dz5(nyfQEO(mUgvRuOTBfLyxfaXcC23YGuG1HuSfPlAVOwO0B)k7kPY5d2wE4g5TBjBvnCGucAHeRyPHFwfM1cz3kEcS6Sni5W4umOSTxzVnrSTEm0sf6b)8DGD5(s)XnCpYwN4LMbyjGQYjxLzlnz78ueeJxQ1tQ(Bwuafqpc)zoMcM6BlaoqmEiLjdz(0ZlacECkLNJbHiRji2mh7qA2lPv5czppwwo04VsEhcEhTwSrAYg(A9rgGkJASmdTwBASxnBoOdQTTu5yJKBMKDJ35lXKnSq8ph9fDVkvUPdQmoailXkqHuTaOt03b)itGTQG2iwgz9Ky3rfjqpmb7RNTs9UlZHspoqPw21I12Ud6ZQnW0UUxA(6hR07TF2wnSeDMfwixB8CG5zseLH20Ul029bc4TrR8wNPHbaMgjvJ5CsIPReXOVvLvBbBjhxULUx3pic9vzFt5Fd2mba957LcUCbfXPQB1amRKzdzQ4ywahAVZwrVT5zSPY9DGBCvkRHhRje5yNiKXGZ(6JQ6thBBxHQcQkNTe6SUkDo4TRAVFbluizT0JoGw)sQYhG9OAdGyFw91lEf4sqsUmNUvGuburao1ivvsEOYgLLdiHkNVuaaLY0G6Il8x6my3ki0NQUy59k3pX4K75W(G883YowqbQVla9hIopg2)LM8G26XWNza7TQr22TRo0eBrRaQZjq7VeVBlcjlDPaXuqwFxI9gO7nV6nkerdt8WyJllFjapGUy8kkay5y6MXh4yd7obyVUX)TaBVVmfFwFXdyY0CzbE)CjqKBcDpSQlOqrnIP0ClcXK4pZRwSEpQRWRRQPPQanHkfsr6EKtCxxzN1m59vJzl4(rnviYHgAQ)lAkQZLuVQQmnsp0rhLF8Yy9xIHnzopHSYygujlIR0Jyc3mbghRgZcnZLRZgyRpHnhtZiG(5Id209WM3P0CM9by24vZLB1ttH(ENbsMqL)BDw02UaVdEf2fl1GJh1AKrip0tFkIPmKkx20BhXtQ)vqJuGfIPIUyRtQ(ftySawGAAo9H69hIm39F9jpKjUPuBqY2m8vvt8eCjw5jtO2YC)qmonaK4JngJPt5fqBCPmFWD8z4D4kcbZ0u3hxo)HBulx849AAl6LDVg4IMg3PzUO3Z9CSlAQSptEP8cy1pgLu9nMxEHYOK5uFj6)0KN2zymhXdN8iYTW2CAStKgZFzZ2BpSg7B0(GwiA0)CAoQ9qaMmCSDI3C(lM75mNE2u9LrHmrVJGXKC9qSw3ludcA9(MmP5P9XIQUcpcVtIjnVsctcmAlglSiIL1RCzERo49JemOFMNL6L7VKC(EG(GcQ5mGFmNRIsWQG3GAnD68lio470q7BYra9NHK)iCG6tQ(EeqoPtp83EBN(3V92(7aAxhYOhKdH0tput3F3MkpbL0qfCwDt3VzYP7ENahPD524x1CQCKG8qJjgP53iS4nbuvNeiA1y5RTD26p22oBJcUE7M3IKYE(9hWBVshDqnZhAcd(G(4RdEuh0S9RjAPe2NTOr8Qvq)5ah0kV0aR6rTq7nz4rDqao50gQslaOpOl453mPxGZp50dEupWLTYQTXrUhC74gCRDyQkgWoa1(T2kT1gA3fLkqxl4tRYy4cuhnUxs8jb)rN3IQt9nn)RnCBwhSakVs7Zd71t2mMNTqIMtc71tOPGP9DVBtWY4mUtOmo4qviP50S01ySojRgI3Gk1)7kOc)aI8KevWvd0UQe3pCJUYqGRRnIcBV1b7RejjsVzYZhBqvJlw)(q7Xv21h(zrzW09IfCBC)bhUL75(ntgoqVaJcrAxe7BBYi9R7oFc9l2bIMbAv2FgdmYqjUr)Sd1220Btgn42B3HI9aBQ1bvQ7Dc5JEu9mH2L(U1SGQEwZ5anytlITBg(W6wSpcZzMZpEfe)RJQ)ombidZXDcw0DzspDsJStGBAlR(S26CCE19Doo4j8TmkNxDhgLZDxduKcvm(gZdEwTh2L6pmRFwCPjenQqa9vAfiO2kJ50ng1Ir)rhGv2FPqRYEWav9EYTu)5pUU6RJc8Oy)VcScULq12GW)ryYm2um05wD9gy7WFUwgpSr)WdmUKJ7Yxk6MJfAi(UFVg79NbQ5500g0(n1fuQpI99dL0Ks)Oh)P4Y)YcaRne3ZiWwLI3)pYsRmYEua10Bzpkguv1DxF6KV6B8tN0KPQ(0nTDbtJTk31dID6))p]] )

