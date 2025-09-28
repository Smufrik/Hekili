-- MageFrost.lua
-- Updated Aug 11, 2025 - Corrected for Mists of Pandaria Classic with real-time event handling.
-- Mists of Pandaria module for Mage: Frost spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'MAGE' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
    
-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end

local function RegisterFrostSpec()
    local class = Hekili.Class
    local state = Hekili.State

    local strformat = string.format
    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

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
            id = 44549,
            duration = 15,
            max_stack = 1,
            generate = function( t )
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 44549 )
                
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
                if not IsSpellKnown( 56377 ) then -- Check if glyph is learned (spell id for the glyph effect)
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
                if IsSpellKnown( 56372 ) then
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
                state.applyDebuff( "target", "frost_bomb" )
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
                state.applyBuff( "frozen_orb" )
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
                return UnitExists("pet") and not UnitIsDead("pet")
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
                state.applyDebuff( "target", "deep_freeze" )
            end,
        },
        
        frostfire_bolt = {
            id = 44614,
            cast = function() return state.buff.brain_freeze.up and 0 or 2 end, -- Instant when Brain Freeze active
            cooldown = 0,
            gcd = "spell",
            
            spend = 0.04,
            spendType = "mana",
            
            startsCombat = true,
            texture = 237520,
            
            usable = function() return state.buff.brain_freeze.up, "requires brain freeze proc" end,
            
            handler = function()
                state.removeBuff( "brain_freeze" )
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
                state.applyBuff( "icy_veins" )
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
            -- CRITICAL FIX: The handler tells Hekili the buff is now active.
            handler = function()
                -- Apply a virtual buff with a 3600-second (1 hour) duration.
                state.applyBuff("arcane_brilliance", 3600)
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
                state.applyBuff( "alter_time" )
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
                state.applyBuff( "blink" )
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
                state.applyDebuff( "target", "cone_of_cold" )
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
                    state.applyBuff( "invocation" )
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
                state.applyDebuff( "target", "frost_nova" )
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
                state.applyDebuff( "target", "frostjaw" )
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
                state.applyBuff( "ice_barrier" )
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
                state.applyBuff( "ice_block" )
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
                state.applyBuff( "ice_floes" )
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
                state.applyBuff( "incanter_s_ward" )
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
                state.applyBuff( "invisibility" )
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
                state.applyBuff( "greater_invisibility" )
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
                state.applyBuff( "presence_of_mind" )
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
                state.applyDebuff( "target", "slow" )
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
                state.applyBuff( "slow_fall" )
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
                state.applyBuff( "time_warp" )
                state.applyDebuff( "player", "temporal_displacement" )
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
                state.removeBuff( "mage_armor" )
                state.removeBuff( "molten_armor" )
                state.applyBuff( "frost_armor" )
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
                state.removeBuff( "frost_armor" )
                state.removeBuff( "molten_armor" )
                state.applyBuff( "mage_armor" )
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
                state.removeBuff( "frost_armor" )
                state.removeBuff( "mage_armor" )
                state.applyBuff( "molten_armor" )
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
                state.applyDebuff( "target", "blizzard" )
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
                state.applyDebuff( "target", "nether_tempest" )
            end,
        },
    } )

    -- Water Elemental Abilities
    spec:RegisterPet( "water_elemental", 78116, "summon_water_elemental", 600 )


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

    -- SIMC-derived settings from MageFrost.simc
    spec:RegisterSetting( "time_warp_health_threshold", 25, {
        name = "Time Warp Health Threshold",
        desc = "Target health percentage below which Time Warp should be used (default: 25%)",
        type = "range",
        min = 10,
        max = 50,
        step = 5,
        width = 1.5
    } )

    spec:RegisterSetting( "time_warp_time_threshold", 5, {
        name = "Time Warp Time Threshold",
        desc = "Time in seconds after which Time Warp should be used regardless of target health (default: 5s)",
        type = "range",
        min = 3,
        max = 15,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "trinket_icy_veins_threshold", 20, {
        name = "Trinket Icy Veins Threshold",
        desc = "Seconds remaining on Icy Veins cooldown above which trinkets should be used (default: 20s)",
        type = "range",
        min = 10,
        max = 30,
        step = 5,
        width = 1.5
    } )

    spec:RegisterSetting( "aoe_enemy_threshold", 3, {
        name = "AoE Enemy Threshold",
        desc = "Number of enemies at which AoE abilities like Blizzard should be used (default: 3)",
        type = "range",
        min = 2,
        max = 6,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "use_racial_abilities", true, {
        name = "Use Racial Abilities",
        desc = "If checked, racial abilities like Berserking and Blood Fury will be recommended during Icy Veins or Brain Freeze",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "use_trinkets", true, {
        name = "Use Trinkets",
        desc = "If checked, trinkets will be recommended during Icy Veins or when Icy Veins cooldown is above threshold",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "alter_time_brain_freeze", true, {
        name = "Alter Time with Brain Freeze",
        desc = "If checked, Alter Time will be recommended when Brain Freeze is available",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "alter_time_fingers_of_frost", true, {
        name = "Alter Time with Fingers of Frost",
        desc = "If checked, Alter Time will be recommended when Fingers of Frost has more than 1 stack",
        type = "toggle",
        width = "full"
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

    -- Enhanced Frost-specific settings (based on Hunter Survival patterns)
    spec:RegisterSetting( "mana_dump_threshold", 80, {
        name = "Mana Dump Threshold",
        desc = "Mana level at which to prioritize spending abilities like Frostbolt and Ice Lance to avoid mana capping.",
        type = "range",
        min = 50,
        max = 120,
        step = 5,
        width = 1.5
    } )

    spec:RegisterSetting( "frostbolt_mana_threshold", 4, {
        name = "Frostbolt Mana Threshold",
        desc = "Minimum mana percentage required to cast Frostbolt (default: 4%)",
        type = "range",
        min = 1,
        max = 10,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "ice_lance_mana_threshold", 2, {
        name = "Ice Lance Mana Threshold",
        desc = "Minimum mana percentage required to cast Ice Lance (default: 2%)",
        type = "range",
        min = 1,
        max = 5,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "frostfire_bolt_mana_threshold", 4, {
        name = "Frostfire Bolt Mana Threshold",
        desc = "Minimum mana percentage required to cast Frostfire Bolt (default: 4%)",
        type = "range",
        min = 1,
        max = 10,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "blizzard_mana_threshold", 8, {
        name = "Blizzard Mana Threshold",
        desc = "Minimum mana percentage required to cast Blizzard (default: 8%)",
        type = "range",
        min = 5,
        max = 15,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "fingers_of_frost_stacks", 2, {
        name = "Fingers of Frost Stacks",
        desc = "Number of Fingers of Frost stacks at which to prioritize Ice Lance (default: 2)",
        type = "range",
        min = 1,
        max = 3,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "brain_freeze_priority", true, {
        name = "Brain Freeze Priority",
        desc = "If checked, Frostfire Bolt will be prioritized when Brain Freeze is active",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "frozen_orb_priority", true, {
        name = "Frozen Orb Priority",
        desc = "If checked, Frozen Orb will be used on cooldown for AoE damage",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "deep_freeze_priority", false, {
        name = "Deep Freeze Priority",
        desc = "If checked, Deep Freeze will be used for control and damage",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "water_elemental_priority", true, {
        name = "Water Elemental Priority",
        desc = "If checked, Water Elemental will be summoned when available",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "rune_of_power_priority", true, {
        name = "Rune of Power Priority",
        desc = "If checked, Rune of Power will be used for damage amplification",
        type = "toggle",
        width = "full"
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

    spec:RegisterSetting( "icy_veins_bloodlust_threshold", 180, {
        name = "Icy Veins Bloodlust Threshold",
        desc = "Seconds remaining on Bloodlust/Sated above which Icy Veins should be used (default: 180s)",
        type = "range",
        min = 60,
        max = 300,
        step = 30,
        width = 1.5
    } )

    spec:RegisterSetting( "alter_time_complex_conditions", true, {
        name = "Alter Time Complex Conditions",
        desc = "If checked, Alter Time will use complex conditions including Bloodlust/Sated timing",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "nether_tempest_targets", 5, {
        name = "Nether Tempest Targets",
        desc = "Number of targets at which Nether Tempest should be maintained (default: 5)",
        type = "range",
        min = 1,
        max = 10,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "frost_bomb_priority", true, {
        name = "Frost Bomb Priority",
        desc = "If checked, Frost Bomb will be used when not ticking on target",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "cone_of_cold_moving", true, {
        name = "Cone of Cold While Moving",
        desc = "If checked, Cone of Cold will be used while moving in AoE situations",
        type = "toggle",
        width = "full"
    } )

    -- Register default pack for MoP Frost Mage
    spec:RegisterPack( "Frost", 20250727, [[Hekili:1IvBVTTnq4FlbfWjbRq1s2ojDijaBDBynylyyk7RsIsIkMiuKAuujnbg63(os9gfTK9AXgkAH9DhFUx4X75CdCdEiWpfjXb37T0BZYRCx54Uz9M1Ub(YxlWb(fOKNqpcFGHYH)9xe8sPs6RuokvD6sELib0e4hxrOYpZcINcY1RUcSTaNeC)fRd83sstXnMIltc8FylPSos9xuDuRpRJ4zW3tKeoRoIskLG6mUOo6xXprOehioe8mcf8(7QJ(D4iFFDKocRV7DGK)qGt45Xi4RnOu6u0j67U5dircIHdJfekLGyj43tYU5K4QSmN9u5uvmniLv55Cw4lqclcXuCoMjr0PTvubyYZcl4VGfkNbwcM7msUdMHIP4067AsIFcNHQOdPaGtcVIbUdQMuQPCjjhdrIOObBXJyPZwmIk36uKiV2BZUDktUDJ5HYjcbxesYvvCd5KKxdFgtyLMcZe83WSqUi2ukKJLyOiPYHCcl1i1SvnKDdhpgsfS4jc7r1b11)ENd19D70IIficlmtGXVHDey44JWGY5PHzvIx)2XOQehsK483xs5YBKcc7jS0Dg8s4CAk)fMHybohGV8wVLhfvVVnuB6iEGGH3aB(WfWh1vz7ROszym0ZzCnmiS7cyXjssIQMBE2VQg0EewOtKX2OsIrDtm4bL6jsPQb1SdXsZa6nLhlTQNHnvHpXfWeI)Klr65dg(cA4HdO607RYdI0r2IZMPDOTpjdYkOPuLo6kNtPegjDR75JFfstdlzi9RnJNzRwUOn16TyQUEc8OigjeKMkDB6oies1oCmLobs6qmJiaJ4uzFoF4MDfM0UHEtN07DMcSQtsH38hsxPU2BHYwRHIo9D39bLU1(6ht6N29d8FE6l1yk5T3A7CusFghIz4CcU82BwT4KC(Zw9Yj8M(r1LW0hQ7mnE2h(mfREsPMBUx9vvANT(1GuG)ZqPa03Y8DP3Lb(qxld0vQO4a0j5fCHSLg700Mz7NwhjW)DfCdMwhvYZb7qvsEou(abjBrqnU0P(UFJWavUFey5(lwzvHckLfOwkYthUGoDS5FIZGytB8PFf3mqGj5WrMx9zUF5Chvj8Z5DrJNfNnOoWhYNTCrGVFEvMG8uGVwLE7JMAa8X71BJ0C2aFtsUa)22(GFmqcvxLDds8teWawbbb7Syt6vhDnerBQJ2TdYfIQ0Elm7CWn9CMkGxzgaMeJwbWAt76hvBz0gtJgioTS6IdKlhKbDaBBluWE5SWUhRttTzMrgdEzGLwH)v)3JFpdUc)pAHF)1vlR8)cpopxQUhWBjSpkqjBGj4x3Lh2XE)p4ypTJDpwJW(C41rlQJor1xR5Hh1T1AQg6d9E5alGogD9xNHPFWZJ0PD(QJ58zwaOZ9ZSgGX7VX60oD9HBpTwhq7QZMTh1ObEA6o91QBD05db1Gh0XZMzJhRrvRwQdM5wGWC8yRkn(ZpfPVcoAZctNmX2fMd36vQD0rMRCOh4JxtrJ2rMIm9gjJdonhSgm7rghdS2RUR1mwlmE2oMKtBbSHIto6lgZC7zA1es2tng8941oGoLBGl5UE7U9ggMb2SKJgZ5himpM2aAUeKguplsPMfBS5xN)nRTdmVcKAQOMFTBpD(eJs37hx38FcGGu0O38hYpvR8u)48(1c6CY0)UCRe9OZMMCW48t76(tW)m]])
end

-- Immediately register the spec.
RegisterFrostSpec()
