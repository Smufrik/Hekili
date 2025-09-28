-- ShamanRestoration.lua
-- Updated May 28, 2025 - Modern Structure
-- Mists of Pandaria module for Shaman: Restoration spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 264 ) -- Restoration spec ID for MoP

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

-- Register resources
spec:RegisterResource( 0 ) -- Mana = 0 in MoP

-- ===================
-- ENHANCED COMBAT LOG EVENT TRACKING
-- ===================

local restorationCombatLogFrame = CreateFrame("Frame")
local restorationCombatLogEvents = {}

local function RegisterRestorationCombatLogEvent(event, handler)
    if not restorationCombatLogEvents[event] then
        restorationCombatLogEvents[event] = {}
        restorationCombatLogFrame:RegisterEvent(event)
    end
    
    tinsert(restorationCombatLogEvents[event], handler)
end

restorationCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local handlers = restorationCombatLogEvents[event]
    if handlers then
        for _, handler in ipairs(handlers) do
            handler(event, ...)
        end
    end
end)

-- Restoration-specific tracking variables
local healing_rain_casts = 0
local chain_heal_casts = 0
local healing_stream_procs = 0
local tidal_waves_procs = 0
local ancestral_awakening_procs = 0
local riptide_applications = 0
local earth_shield_absorbs = 0

-- Enhanced Combat Log Event Handlers for Restoration-specific mechanics
RegisterRestorationCombatLogEvent("COMBAT_LOG_EVENT_UNFILTERED", function(event, ...)
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool = CombatLogGetCurrentEventInfo()
    
    if sourceGUID == UnitGUID("player") then
        -- Track Restoration-specific spell interactions
        if subEvent == "SPELL_CAST_SUCCESS" then
            if spellID == 73920 then -- Healing Rain
                healing_rain_casts = healing_rain_casts + 1
            elseif spellID == 1064 then -- Chain Heal
                chain_heal_casts = chain_heal_casts + 1
            elseif spellID == 61295 then -- Riptide
                riptide_applications = riptide_applications + 1
            end
        elseif subEvent == "SPELL_HEAL" then
            if spellID == 52042 then -- Healing Stream Totem
                healing_stream_procs = healing_stream_procs + 1
            elseif spellID == 16207 then -- Ancestral Awakening
                ancestral_awakening_procs = ancestral_awakening_procs + 1
            end
        elseif subEvent == "SPELL_AURA_APPLIED" then
            if spellID == 53390 then -- Tidal Waves
                tidal_waves_procs = tidal_waves_procs + 1
            elseif spellID == 974 then -- Earth Shield
                -- Earth Shield application tracking
            end
        elseif subEvent == "SPELL_ABSORBED" then
            if spellID == 974 then -- Earth Shield
                earth_shield_absorbs = earth_shield_absorbs + 1
            end
        end
    end
end)

-- ===================
-- ENHANCED TIER SETS AND GEAR REGISTRATION
-- ===================

-- Comprehensive Tier Set Coverage (T14-T16 across all difficulties)
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 ) -- Normal
spec:RegisterGear( "tier14_lfr", 89281, 89282, 89283, 89284, 89285 ) -- LFR versions
spec:RegisterGear( "tier14_heroic", 90404, 90405, 90406, 90407, 90408 ) -- Heroic versions

-- Tier 15 - Throne of Thunder
spec:RegisterGear( "tier15", 95298, 95299, 95300, 95301, 95302 ) -- Normal
spec:RegisterGear( "tier15_lfr", 95262, 95263, 95264, 95265, 95266 ) -- LFR versions
spec:RegisterGear( "tier15_heroic", 96572, 96573, 96574, 96575, 96576 ) -- Heroic versions
spec:RegisterGear( "tier15_thunderforged", 97207, 97208, 97209, 97210, 97211 ) -- Thunderforged versions

-- Tier 16 - Siege of Orgrimmar
spec:RegisterGear( "tier16", 99071, 99072, 99073, 99074, 99075 ) -- Normal
spec:RegisterGear( "tier16_lfr", 99726, 99727, 99728, 99729, 99730 ) -- LFR versions
spec:RegisterGear( "tier16_flex", 100236, 100237, 100238, 100239, 100240 ) -- Flexible versions
spec:RegisterGear( "tier16_heroic", 100891, 100892, 100893, 100894, 100895 ) -- Heroic versions
spec:RegisterGear( "tier16_mythic", 101556, 101557, 101558, 101559, 101560 ) -- Mythic versions

-- Legendary Items
spec:RegisterGear( "legendary_cloak", 102246 ) -- Jina-Kang, Kindness of Chi-Ji (Healing version)
spec:RegisterGear( "legendary_meta_gem", 101817 ) -- Revitalizing Primal Diamond

-- Notable Restoration Trinkets
spec:RegisterGear( "prismatic_prison_of_pride", 104651 ) -- SoO healing trinket
spec:RegisterGear( "dysmorphic_samophlange_of_discontinuity", 105691 ) -- SoO trinket
spec:RegisterGear( "purified_bindings_of_immerseus", 102293 ) -- SoO trinket
spec:RegisterGear( "horridon_s_last_gasp", 93982 ) -- ToT healing trinket
spec:RegisterGear( "lei_shen_s_final_orders", 94522 ) -- ToT weapon
spec:RegisterGear( "rune_of_reorigination", 94535 ) -- ToT trinket
spec:RegisterGear( "wushoolay_s_final_choice", 94521 ) -- ToT healing trinket

-- Restoration-specific Weapons and Shields
spec:RegisterGear( "gao_lei_shao_do", 89235 ) -- MSV staff
spec:RegisterGear( "lei_shen_s_final_orders", 94522 ) -- ToT weapon
spec:RegisterGear( "korven_s_crimson_crescent", 105674 ) -- SoO weapon
spec:RegisterGear( "shield_of_mockery", 102248 ) -- SoO shield
spec:RegisterGear( "kardris_toxic_totem", 102312 ) -- SoO off-hand

-- PvP Sets (Season 12-15)
spec:RegisterGear( "season12", 91340, 91341, 91342, 91343, 91344 ) -- Malevolent Gladiator's Mail
spec:RegisterGear( "season13", 93633, 93634, 93635, 93636, 93637 ) -- Tyrannical Gladiator's Mail
spec:RegisterGear( "season14", 95289, 95290, 95291, 95292, 95293 ) -- Grievous Gladiator's Mail
spec:RegisterGear( "season15", 97960, 97961, 97962, 97963, 97964 ) -- Prideful Gladiator's Mail

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", 90510, 90511, 90512, 90513, 90514 ) -- Challenge Mode Shaman Set

-- Advanced tier set bonus tracking with generate functions
local function check_tier_bonus(tier, pieces)
    return function()
        return equipped[tier] >= pieces
    end
end

spec:RegisterAura( "tier14_2pc_restoration", {
    id = 123456, -- Placeholder ID
    generate = check_tier_bonus("tier14", 2)
} )
spec:RegisterAura( "tier14_4pc_restoration", {
    id = 123457, -- Placeholder ID
    generate = check_tier_bonus("tier14", 4)
} )
spec:RegisterAura( "tier15_2pc_restoration", {
    id = 123458, -- Placeholder ID
    generate = check_tier_bonus("tier15", 2)
} )
spec:RegisterAura( "tier15_4pc_restoration", {
    id = 123459, -- Placeholder ID
    generate = check_tier_bonus("tier15", 4)
} )
spec:RegisterAura( "tier16_2pc_restoration", {
    id = 123460, -- Placeholder ID
    generate = check_tier_bonus("tier16", 2)
} )
spec:RegisterAura( "tier16_4pc_restoration", {
    id = 123461, -- Placeholder ID
    generate = check_tier_bonus("tier16", 4)
} )

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Survivability
    nature_guardian            = { 1, 1, 30884  }, -- Instant heal for 20% health when below 30%
    stone_bulwark_totem        = { 1, 2, 108270 }, -- Absorb totem that regenerates shield
    astral_shift               = { 1, 3, 108271 }, -- 40% damage shifted to DoT for 6 sec

    -- Tier 2 (Level 30) - Utility/Control
    frozen_power               = { 2, 1, 63374 }, -- Frost Shock roots targets for 5 sec
    earthgrab_totem            = { 2, 2, 51485  }, -- Totem roots nearby enemies
    windwalk_totem             = { 2, 3, 108273 }, -- Removes movement impairing effects

    -- Tier 3 (Level 45) - Totem Enhancement
    call_of_the_elements       = { 3, 1, 108285 }, -- Reduces totem cooldowns by 50% for 1 min
    totemic_restoration        = { 3, 2, 108284 }, -- Destroyed totems get 50% cooldown reduction
    totemic_projection         = { 3, 3, 108287 }, -- Relocate totems to target location

    -- Tier 4 (Level 60) - Healing Enhancement
    elemental_mastery          = { 4, 1, 16166  }, -- Instant cast and 30% spell damage buff
    ancestral_swiftness        = { 4, 2, 16188  }, -- 5% haste passive, instant cast active
    echo_of_the_elements       = { 4, 3, 108283 }, -- 6% chance to cast spell twice

    -- Tier 5 (Level 75) - Healing/Support
    healing_tide_totem         = { 5, 1, 108280 }, -- Raid healing totem for 10 sec
    ancestral_guidance         = { 5, 2, 108281 }, -- Heals lowest health ally for 25% of damage dealt
    conductivity               = { 5, 3, 108282 }, -- When you cast Healing Rain, you may cast Lightning Bolt, Chain Lightning, Lava Burst, or Elemental Blast on enemies standing in the area to heal all allies in the Healing Rain for 20% of the damage dealt.
    
    -- Tier 6 (Level 90) - Ultimate
    unleashed_fury             = { 6, 1, 117012 }, -- Enhances Unleash Elements effects
    primal_elementalist        = { 6, 2, 117013 }, -- Gain control over elementals, 10% more damage
    elemental_blast            = { 6, 3, 117014 }  -- High damage + random stat buff
} )

-- ===================
-- ENHANCED GLYPH SYSTEM - COMPREHENSIVE RESTORATION COVERAGE
-- ===================

spec:RegisterGlyphs( {
    -- Major Healing & Core DPS Glyphs
    [55448] = "riptide",             -- Increases the initial direct healing of your Riptide by 75%, but removes the periodic healing effect.
    [55452] = "chaining",            -- Increases the amount healed by Chain Heal by 10% when it jumps to each successive target.
    [55441] = "healing_wave",        -- Your Healing Wave also heals you for 20% of the amount when you heal someone else.
    [55440] = "healing_stream_totem", -- Your Healing Stream Totem also reduces damage taken by 10% for allies within its radius.
    [55460] = "healing_stream",      -- Your Healing Stream Totem heals for 30% more, but affects one target at a time.
    [55446] = "water_shield",        -- Increases the amount of mana generated by your Water Shield by 50%.
    [63273] = "cleansing_waters",    -- When you Cleanse Spirit harmful effects from yourself, you are healed for a small amount.
    [55449] = "totemic_recall",      -- Your Totemic Recall spell no longer restores mana when recalling totems.
    [55447] = "fire_elemental_totem", -- Increases the duration of your Fire Elemental Totem by 1 min, but increases the cooldown by 2.5 min.
    [55455] = "flame_shock",         -- Increases the duration of Flame Shock by 6 sec.
    [55456] = "frost_shock",         -- Your Frost Shock no longer slows your enemies, but also no longer shares a cooldown with other shock spells.
    
    -- Mobility & Utility Glyphs
    [55438] = "spiritwalkers_grace", -- Reduces the cooldown of Spiritwalker's Grace by 60 sec, but reduces the duration by 5 sec.
    [55439] = "hex",                 -- Increases the duration of your Hex spell by 20 sec.
    [58057] = "deluge",              -- Increases the range of your Chain Lightning and Chain Heal spells by 5 yards.
    [57720] = "reach_of_the_elements", -- Increases the range of your totems by 5 yards.
    [58058] = "elemental_familiars", -- Your totems no longer have Taunt abilities.
    [58056] = "totemic_vigor",       -- Increases the health of your totems by 5%.
    [55454] = "capacitor_totem",     -- Reduces the time before your Capacitor Totem detonates by 2 sec, but increases the cooldown by 15 sec.
    [55437] = "thunderstorm",        -- Your Thunderstorm knocks enemies back a shorter distance.
    
    -- Defensive & Survival Glyphs
    [55442] = "earth_shield",        -- Your Earth Shield also protects you, but the cooldown of your Earth Shield is increased by 5 seconds.
    [55443] = "lightning_shield",    -- Your Lightning Shield can no longer drop below 3 charges, but has a 10 second longer cooldown.
    [55444] = "shamanistic_rage",    -- Increases the duration of Shamanistic Rage by 5 sec, but decreases the damage reduction by 10%.
    [55445] = "astral_shift",        -- Increases the damage reduction of Astral Shift by 10%, but increases the cooldown by 30 seconds.
    [55464] = "healing_totem",       -- Your Healing Stream Totem also provides a 15% damage reduction to all party and raid members, but heals for 30% less.
    [55465] = "cleanse_spirit_shield", -- Your Cleanse Spirit also provides a damage absorption shield equal to 30% of your spell power.
    
    -- Control & CC Glyphs
    [55466] = "bind_elemental",      -- Your Bind Elemental spell lasts 20 sec longer, but has a 2 min longer cooldown.
    [55467] = "earthgrab_totem",     -- Your Earthgrab Totem has a 15 sec longer duration but a 15 sec longer cooldown.
    [55468] = "grounding_totem",     -- Your Grounding Totem has 2 additional charges but lasts 5 sec less.
    [55469] = "tremor_totem",        -- Your Tremor Totem also provides immunity to charm effects but has a 30 sec longer cooldown.
    [55470] = "windwalk_totem",      -- Your Windwalk Totem provides immunity to movement-impairing effects for 2 sec longer.
    
    -- Minor Visual & Convenience Glyphs
    [58059] = "arctic_wolf",         -- Your Ghost Wolf form appears as an Arctic Wolf.
    [63270] = "astral_recall",       -- Reduces the cooldown on your Astral Recall spell by 2 min.
    [63271] = "astral_fixation",     -- Your Far Sight ability now casts instantly.
    [58063] = "lava_lash",           -- Your Lava Lash no longer increases damage when your offhand weapon is enchanted with Flametongue, but instead generates one stack of Searing Flame, increasing the damage of your next Searing Totem by 5%, stacking up to 5 times.
    [55461] = "spirit_wolf",         -- Each of your Spirit Wolves attacks add a stack of Spirit Hunt to your target, increasing the healing you receive by 1% for 10 sec and stacking up to 5 times.
    [57958] = "water_walking",       -- Your Water Walking spell no longer cancels when recipients take damage.
    [55471] = "spirit_walk",         -- Your Ghost Wolf form provides 30% movement speed but you cannot cast spells.
    [55472] = "renewed_life",        -- Your Ancestral Spirit spell has a 100% chance to not consume a reagent.
    [55473] = "totemic_encirclement", -- Your totems have a 30% chance to not consume reagents when summoned.
    [55474] = "elemental_harmony",   -- Your totems glow with their respective elemental colors.
    [55475] = "healing_stream_visual", -- Your Healing Stream Totem has enhanced visual effects.
} )

-- ===================
-- ADVANCED AURA SYSTEM - COMPREHENSIVE RESTORATION TRACKING
-- ===================

spec:RegisterAuras( {
    -- Core Restoration Mechanics with Enhanced Tracking
    water_shield = {
        id = 52127,
        duration = 1800,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 52127 )
            
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
    
    tidal_waves = {
        id = 53390,
        duration = 15,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 53390 )
            
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
    
    -- Enhanced Earth Shield Tracking
    earth_shield = {
        id = 974,
        duration = 600,
        max_stack = 9,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 974 )
            
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
    
    -- Enhanced Riptide Tracking
    riptide = {
        id = 61295,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 61295 )
            
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
    
    -- Enhanced Healing Rain Tracking
    healing_rain = {
        id = 73920,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 73920 )
            
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
    
    -- Enhanced Spiritwalker's Grace Tracking
    spiritwalkers_grace = {
        id = 79206,
        duration = function() return glyph.spiritwalkers_grace.enabled and 10 or 15 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 79206 )
            
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
    
    -- Enhanced Ancestral Swiftness Tracking
    ancestral_swiftness = {
        id = 16188,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 16188 )
            
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
    
    -- Enhanced Elemental Mastery Tracking
    elemental_mastery = {
        id = 16166,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 16166 )
            
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
    
    -- Enhanced Unleash Life Tracking
    unleash_life = {
        id = 73685,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 73685 )
            
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
    
    -- Enhanced Healing Stream Totem Tracking
    healing_stream_totem = {
        id = 5394,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 5394 )
            
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
    
    -- Enhanced Mana Tide Totem Tracking
    mana_tide_totem = {
        id = 16190,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 16190 )
            
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
    
    -- Enhanced Spirit Link Totem Tracking
    spirit_link_totem = {
        id = 98008,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 98008 )
            
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
    
    -- Enhanced Healing Tide Totem Tracking
    healing_tide_totem = {
        id = 108280,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108280 )
            
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
    
    -- Enhanced Earthliving Weapon Tracking
    earthliving_weapon = {
        id = 51730,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 51730 )
            
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
    
    -- Enhanced Astral Shift Tracking
    astral_shift = {
        id = 108271,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108271 )
            
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
    
    -- Enhanced Stone Bulwark Totem Tracking
    stone_bulwark_totem = {
        id = 108270,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108270 )
            
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
    
    -- Enhanced Capacitor Totem Tracking
    capacitor_totem = {
        id = 118905,
        duration = 5,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118905 )
            
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
    
    -- Enhanced Fire Elemental Totem Tracking
    fire_elemental_totem = {
        id = 2894,
        duration = function() return glyph.fire_elemental_totem.enabled and 120 or 60 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 2894 )
            
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
    
    -- Enhanced Ancestral Guidance Tracking
    ancestral_guidance = {
        id = 108281,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108281 )
            
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
    
    -- Enhanced Conductivity Tracking
    conductivity = {
        id = 108282,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 108282 )
            
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
    
    -- Enhanced Ghost Wolf Tracking
    ghost_wolf = {
        id = 2645,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 2645 )
            
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
    
    -- Basic Totem Tracking (Standard duration-based)
    earthbind_totem = {
        id = 2484,
        duration = 30,
        max_stack = 1,
    },
    earthgrab_totem = {
        id = 51485,
        duration = 20,
        max_stack = 1,
    },
    grounding_totem = {
        id = 8177,
        duration = 15,
        max_stack = 1,
    },
    stoneclaw_totem = {
        id = 5730,
        duration = 15,
        max_stack = 1,
    },
    stoneskin_totem = {
        id = 8071,
        duration = 15,
        max_stack = 1,
    },
    stormlash_totem = {
        id = 120668,
        duration = 10,
        max_stack = 1,
    },
    tremor_totem = {
        id = 8143,
        duration = 10,
        max_stack = 1,
    },
    windwalk_totem = {
        id = 108273,
        duration = 6,
        max_stack = 1,
    },
    
    -- Healing Effect Tracking
    healing_stream = {
        id = 5672,
        duration = 15,
        max_stack = 1,
    },
    earthliving = {
        id = 51945,
        duration = 12,
        tick_time = 3,
        max_stack = 1,
    },
    
    -- Debuff Tracking
    flame_shock = {
        id = 8050,
        duration = function() return glyph.flame_shock.enabled and 27 or 21 end,
        tick_time = 3,
        max_stack = 1,
    },
    frost_shock = {
        id = 8056,
        duration = 8,
        max_stack = 1,
    },
    frozen = {
        id = 94794,
        duration = 5,
        max_stack = 1,
    },
    earthgrab = {
        id = 64695,
        duration = 5,
        max_stack = 1,
    },
    
    -- Defensive Effect Tracking
    stone_bulwark_absorb = {
        id = 114893,
        duration = 30,
        max_stack = 1,
    },
    
    -- Utility Effect Tracking
    water_walking = {
        id = 546,
        duration = 600,
        max_stack = 1,
    },
    water_breathing = {
        id = 131,
        duration = 600,
        max_stack = 1,
    },
    
    -- Tier Set and Legendary Tracking
    t14_2pc_resto = {
        id = 105821,
        duration = 15,
        max_stack = 1,
    },
    t14_4pc_resto = {
        id = 105822,
        duration = 10,
        max_stack = 1,
    },
    t15_2pc_resto = {
        id = 138154,
        duration = 15,
        max_stack = 1,
    },
    t15_4pc_resto = {
        id = 138155,
        duration = 20,
        max_stack = 1,
    },
    t16_2pc_resto = {
        id = 144330,
        duration = 8,
        max_stack = 1,
    },
    t16_4pc_resto = {
        id = 144331,
        duration = 15,
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

-- Restoration Shaman abilities
spec:RegisterAbilities( {
    -- Core healing abilities
    healing_wave = {
        id = 77472,
        cast = function() return buff.tidal_waves.up and 1.5 * 0.7 * haste or 1.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.10,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136043,
        
        handler = function()
            if buff.tidal_waves.up then
                removeStack("tidal_waves")
            end
            -- Earthliving proc
            if buff.earthliving_weapon.up and math.random() < 0.20 then -- 20% proc chance
                applyDebuff("target", "earthliving")
            end
        end,
    },
    
    greater_healing_wave = {
        id = 77472,
        cast = function() return buff.tidal_waves.up and 3 * 0.7 * haste or 3 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.18,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136043,
        
        handler = function()
            if buff.tidal_waves.up then
                removeStack("tidal_waves")
            end
            -- Earthliving proc
            if buff.earthliving_weapon.up and math.random() < 0.20 then -- 20% proc chance
                applyDebuff("target", "earthliving")
            end
        end,
    },
    
    healing_surge = {
        id = 8004,
        cast = function() return buff.tidal_waves.up and 1.5 * 0.7 * haste or 1.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.22,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136044,
        
        handler = function()
            if buff.tidal_waves.up then
                removeStack("tidal_waves")
            end
            -- Earthliving proc
            if buff.earthliving_weapon.up and math.random() < 0.20 then -- 20% proc chance
                applyDebuff("target", "earthliving")
            end
        end,
    },
    
    chain_heal = {
        id = 1064,
        cast = function() return 2.5 * haste end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.20,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136042,
        
        handler = function()
            -- Earthliving proc
            if buff.earthliving_weapon.up and math.random() < 0.20 then -- 20% proc chance
                applyDebuff("target", "earthliving")
            end
            addStack("tidal_waves", nil, 2)
        end,
    },
    
    riptide = {
        id = 61295,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = false,
        texture = 252995,
        
        handler = function()
            if not glyph.riptide.enabled then
                applyBuff("target", "riptide")
            end
            -- Earthliving proc
            if buff.earthliving_weapon.up and math.random() < 0.20 then -- 20% proc chance
                applyDebuff("target", "earthliving")
            end
            addStack("tidal_waves", nil, 2)
        end,
    },
    
    earth_shield = {
        id = 974,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.10,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136089,
        
        handler = function()
            applyBuff("target", "earth_shield")
            buff.earth_shield.stack = 9
        end,
    },
    
    healing_rain = {
        id = 73920,
        cast = function() return 2 * haste end,
        cooldown = 10,
        gcd = "spell",
        
        spend = 0.38,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136037,
        
        handler = function()
            applyBuff("healing_rain")
        end,
    },
    
    -- Totems
    healing_stream_totem = {
        id = 5394,
        cast = 0,
        cooldown = 30,
        gcd = "totem",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135127,
        
        handler = function()
            applyBuff("healing_stream_totem")
        end,
    },
    
    healing_tide_totem = {
        id = 108280,
        cast = 0,
        cooldown = 180,
        gcd = "totem",
        
        toggle = "cooldowns",
        
        spend = 0.18,
        spendType = "mana",
        
        startsCombat = false,
        texture = 538569,
        
        handler = function()
            applyBuff("healing_tide_totem")
        end,
    },
    
    mana_tide_totem = {
        id = 16190,
        cast = 0,
        cooldown = 180,
        gcd = "totem",
        
        toggle = "cooldowns",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = false,
        texture = 4710368,
        
        handler = function()
            applyBuff("mana_tide_totem")
        end,
    },
    
    spirit_link_totem = {
        id = 98008,
        cast = 0,
        cooldown = 180,
        gcd = "totem",
        
        toggle = "cooldowns",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 237586,
        
        handler = function()
            applyBuff("spirit_link_totem")
        end,
    },
    
    capacitor_totem = {
        id = 108269,
        cast = 0,
        cooldown = function() return glyph.capacitor_totem.enabled and 60 or 45 end,
        gcd = "totem",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136013,
        
        handler = function()
            applyBuff("capacitor_totem")
        end,
    },
    
    earthbind_totem = {
        id = 2484,
        cast = 0,
        cooldown = 30,
        gcd = "totem",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136102,
        
        handler = function()
            applyBuff("earthbind_totem")
        end,
    },
    
    tremor_totem = {
        id = 8143,
        cast = 0,
        cooldown = 60,
        gcd = "totem",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = false,
        texture = 136108,
        
        handler = function()
            applyBuff("tremor_totem")
        end,
    },
    
    -- Utility and defensives
    water_shield = {
        id = 52127,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 132315,
        
        handler = function()
            applyBuff("water_shield")
            buff.water_shield.stack = 3
        end,
    },
    
    earthliving_weapon = {
        id = 51730,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.1,
        spendType = "mana",
        
        startsCombat = false,
        texture = 237575,
        
        handler = function()
            applyBuff("earthliving_weapon")
        end,
    },
    
    purify_spirit = {
        id = 77130,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = false,
        texture = 451166,
        
        handler = function()
            -- Cleanse effects
            if glyph.cleansing_waters.enabled then
                -- Apply self heal from glyph
            end
        end,
    },
    
    spiritwalkers_grace = {
        id = 79206,
        cast = 0,
        cooldown = function() return glyph.spiritwalkers_grace.enabled and 60 or 120 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 451170,
        
        handler = function()
            applyBuff("spiritwalkers_grace")
        end,
    },
    
    ghost_wolf = {
        id = 2645,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 136095,
        
        handler = function()
            applyBuff("ghost_wolf")
        end,
    },
    
    astral_shift = {
        id = 108271,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 538565,
        
        handler = function()
            applyBuff("astral_shift")
        end,
    },
    
    stone_bulwark_totem = {
        id = 108270,
        cast = 0,
        cooldown = 60,
        gcd = "totem",
        
        toggle = "defensives",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135861,
        
        handler = function()
            applyBuff("stone_bulwark_totem")
            applyBuff("stone_bulwark_absorb")
        end,
    },
    
    -- Talents
    elemental_mastery = {
        id = 16166,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136115,
        
        handler = function()
            applyBuff("elemental_mastery")
        end,
    },
    
    ancestral_swiftness = {
        id = 16188,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136076,
        
        handler = function()
            applyBuff("ancestral_swiftness")
        end,
    },
    
    ancestral_guidance = {
        id = 108281,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 538564,
        
        handler = function()
            applyBuff("ancestral_guidance")
        end,
    },
    
    unleash_elements = {
        id = 73680,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = false,
        texture = 462650,
        
        handler = function()
            applyBuff("unleash_life")
        end,
    },
} )

-- State Expressions for Restoration
spec:RegisterStateExpr( "tidal_stacks", function()
    return buff.tidal_waves.stack
end )

-- Range
spec:RegisterRanges( "healing_wave", "flame_shock", "earth_shock", "frost_shock", "wind_shear" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    gcd = 1645,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent",
    
    package = "Restoration",
} )

-- Default pack for MoP Restoration Shaman
spec:RegisterPack( "Restoration", 20250515, [[Hekili:T1vBVTTnu4FlXiPaQWKrdpvIbKmEbvJRLwwxP2rI1mzQiQ1GIugwwtyQsyBvHnYJP6LP56NHJUHX2Z)OnRXYQZl6R)UNB6QL(zhdkr9bQlG(tB8L4Wdpb3NNVh(GWdFOdpNFpdO8Hdm6Tw(acm2nDWZ5MjsXyJKCtj3cU5sIVOd8jkzPsMLIX65MuLY1jrwLkKWrZA3CluOKCvId8LHIyyIeLSr1WIJ1jPr7cYeKwrJIuWXRKtFDlYkLmCPFJr(4OsZQR]] )

-- Register pack selector for Restoration
