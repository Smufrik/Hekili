-- WarlockAffliction.lua
-- Updated Sep 28, 2025


-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'WARLOCK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Cache global API references to avoid environment issues during emulation/state generation
local _GetSpellCritChance = ( _G and type( _G.GetSpellCritChance ) == "function" ) and _G.GetSpellCritChance or nil
local _GetSpellBonusDamage = ( _G and type( _G.GetSpellBonusDamage ) == "function" ) and _G.GetSpellBonusDamage or nil
local _UnitStat = ( _G and type( _G.UnitStat ) == "function" ) and _G.UnitStat or nil
local _UnitSpellHaste = ( _G and type( _G.UnitSpellHaste ) == "function" ) and _G.UnitSpellHaste or nil
local _GetMastery = ( _G and type( _G.GetMastery ) == "function" ) and _G.GetMastery or nil

-- Enhanced helper functions for Affliction Warlock
local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end



local spec = Hekili:NewSpecialization( 265 ) -- Affliction spec ID for MoP

-- Affliction-specific combat log event tracking
local afflictionCombatLogFrame = CreateFrame("Frame")
local afflictionCombatLogEvents = {}
local hauntFlight = { active = false, destGUID = nil, expires = 0 }

local function RegisterAfflictionCombatLogEvent(event, handler)
    if not afflictionCombatLogEvents[event] then
        afflictionCombatLogEvents[event] = {}
    end
    table.insert(afflictionCombatLogEvents[event], handler)
end

afflictionCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

        if sourceGUID == UnitGUID("player") then
            local handlers = afflictionCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        dot_snapshot.agony.value = 0; dot_snapshot.agony.crit = 0
        dot_snapshot.corruption.value = 0; dot_snapshot.corruption.crit = 0
        dot_snapshot.unstable_affliction.value = 0; dot_snapshot.unstable_affliction.crit = 0
        hauntFlight.active = false; hauntFlight.destGUID = nil; hauntFlight.expires = 0
    end
end)

afflictionCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
afflictionCombatLogFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

-- Provide safe state expression shims so loader doesn't warn before events populate these.
spec:RegisterStateExpr( "last_dot_tick", function()
    return rawget( state, "last_dot_tick" ) or 0
end )

spec:RegisterStateExpr( "last_target_death", function()
    return rawget( state, "last_target_death" ) or 0
end )

spec:RegisterStateExpr( "target_died", function()
    return rawget( state, "target_died" ) or false
end )

-- Safety shims to prevent unknown key warnings in parser/emulator.
spec:RegisterStateExpr( "last_ability", function()
    return rawget( state, "last_ability" ) or ""
end )

spec:RegisterStateTable( "last_cast_time", setmetatable( {}, { __index = function() return 0 end } ) )

spec:RegisterStateExpr( "tick_time", function()
    return 0
end )

-- Planned DoT casts within a single recommendation build (prevents duplicate DoT spam in queue)
spec:RegisterStateTable( "planned_dot", setmetatable( {}, { __index = function() return false end } ) )

-- Clear planned DoTs at the beginning of each recommendation build
spec:RegisterHook( "reset_precast", function ()
    if state.planned_dot then
        for k in pairs( state.planned_dot ) do
            state.planned_dot[ k ] = nil
        end
    end
end )

-- Pet stat tracking
local function update_pet_stats()
    local pet_health = UnitHealth("pet") or 0
    local pet_max_health = UnitHealthMax("pet") or 1
    local pet_health_pct = pet_max_health > 0 and pet_health / pet_max_health or 0
    state.pet_health_pct = pet_health_pct
end

spec:RegisterStateExpr("pet_health_pct", function()
    return state.pet_health_pct or 0
end)

-- Haunt projectile in-flight tracking
spec:RegisterStateExpr( "haunt_in_flight", function()
    if not hauntFlight.active then return 0 end
    if hauntFlight.destGUID ~= UnitGUID("target") then return 0 end
    local now = state.query_time or GetTime()
    return (hauntFlight.expires > now) and 1 or 0
end )

-- DoT snapshot tracking for percent_increase logic
local dot_snapshot = {
    agony = { value = 0, crit = 0 },
    corruption = { value = 0, crit = 0 },
    unstable_affliction = { value = 0, crit = 0 },
}

-- Helper to get current snapshot value (spell power + haste + mastery)
local function get_dot_snapshot_value()
    local sp = ( _GetSpellBonusDamage and _GetSpellBonusDamage( 6 ) ) or 0
    local crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
    local mastery = ( _GetMastery and _GetMastery() ) or 0
    local critMult = 1 + ( crit / 100 )
    local mastMult = 1 + ( mastery / 100 )
    return sp * critMult * mastMult
end

-- Calculate percent increase for a DoT
local function get_dot_percent_increase(dot)
    local last = dot_snapshot[dot] and dot_snapshot[dot].value or 0
    local current = get_dot_snapshot_value()
    if last == 0 then return 0 end
    return math.floor(((current - last) / last) * 100)
end

-- Register state expressions for percent_increase with safe aura access
for _, dot in ipairs({"agony", "corruption", "unstable_affliction"}) do
    spec:RegisterStateExpr("dot." .. dot .. ".percent_increase", function()
        -- Safe access to avoid nil aura errors
        local aura_table = state.debuff and state.debuff[dot]
        if aura_table and aura_table.up then
            return get_dot_percent_increase(dot)
        end
        return 0
    end)
end

-- Provide accurate ticks_remain for DoTs from predicted/live aura
for _, dot in ipairs({"agony", "corruption", "unstable_affliction"}) do
    spec:RegisterStateExpr("dot." .. dot .. ".ticks_remain", function()
        local now = state.query_time or GetTime()
        local aura_table = state.debuff and state.debuff[dot]

        local expires
        if aura_table and (aura_table.expires or 0) > now then
            expires = aura_table.expires
        else
            -- Fallback to live aura
            local spellId = (dot == "agony" and 980) or (dot == "corruption" and 146739) or (dot == "unstable_affliction" and 30108)
            local name, _, _, _, duration, expirationTime, caster = GetTargetDebuffByID( spellId )
            if name and caster == "player" and (expirationTime or 0) > now then
                expires = expirationTime
            else
                return 0
            end
        end

        local remains = math.max(0, (expires or 0) - now)
        local tick = (dot == "agony" or dot == "unstable_affliction") and 2 or 3
        return remains / tick
    end)
end

-- Provide crit percentage per-dot
for _, dot in ipairs({"agony", "corruption", "unstable_affliction"}) do
    spec:RegisterStateExpr("dot." .. dot .. ".crit_pct", function()
        local crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
        return crit
    end)
end

-- Alias for wowsims APL: dotPercentIncrease(spellId)
spec:RegisterStateFunction("dotPercentIncrease", function(spellId)
    local dot
    if spellId == 980 then
        dot = "agony"
    elseif spellId == 172 then
        dot = "corruption"
    elseif spellId == 30108 then
        dot = "unstable_affliction"
    end
    if not dot then return 0 end

    -- Safe access to avoid nil aura errors
    local aura_table = state.debuff and state.debuff[dot]
    if aura_table and aura_table.up then
        local v = get_dot_percent_increase(dot)
        if v == nil then return 0 end
        return v
    end
    return 0
end)

-- Hook DoT application to update snapshot
local dot_spell_ids = {
    agony = 980, -- Agony
    corruption = 172, -- Corruption
    unstable_affliction = 30108, -- Unstable Affliction
}

RegisterAfflictionCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID)
    for dot, id in pairs(dot_spell_ids) do
        if spellID == id and destGUID == UnitGUID("target") then
            dot_snapshot[dot].value = get_dot_snapshot_value()
            dot_snapshot[dot].crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
        end
    end
end)

-- Also update snapshots on refresh events.
RegisterAfflictionCombatLogEvent("SPELL_AURA_REFRESH", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID)
    for dot, id in pairs(dot_spell_ids) do
        if spellID == id and destGUID == UnitGUID("target") then
            dot_snapshot[dot].value = get_dot_snapshot_value()
            dot_snapshot[dot].crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
        end
    end
end)

-- Clear snapshots if the DoT is removed from the current target
RegisterAfflictionCombatLogEvent("SPELL_AURA_REMOVED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID)
    for dot, id in pairs(dot_spell_ids) do
        if spellID == id and destGUID == UnitGUID("target") then
            dot_snapshot[dot].value = 0
            dot_snapshot[dot].crit = 0
        end
    end
    if spellID == 48181 and hauntFlight.active and hauntFlight.destGUID == destGUID then
        hauntFlight.active = false
        hauntFlight.expires = 0
    end
end)

-- Soul Shard generation tracking
RegisterAfflictionCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 686 then -- Shadow Bolt
        -- Shadow Bolt can generate Soul Shards
    elseif spellID == 1120 then -- Drain Soul
        -- Drain Soul generates Soul Shards when target dies
    elseif spellID == 48181 then -- Haunt
        -- Mark Haunt as in-flight until it applies (or short timeout)
        hauntFlight.active = true
        hauntFlight.destGUID = destGUID
        hauntFlight.expires = ( state.query_time or GetTime() ) + 0.6
    end
end)

-- DoT application and tick tracking with pandemic refresh
RegisterAfflictionCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 172 then -- Corruption
        -- Track Corruption application for pandemic refresh
        local remaining = select(6, FindUnitDebuffByID("target", 172, "PLAYER"))
        if remaining then
            -- Pandemic refresh: if remaining duration is less than 30% of base duration, extend it
            local base_duration = 18 -- Corruption base duration in MoP
            if remaining < (base_duration * 0.3) then
                -- Note: Extension handled by default aura system
            end
        end
    elseif spellID == 30108 then -- Unstable Affliction
        -- Track UA application for pandemic refresh
        local remaining = select(6, FindUnitDebuffByID("target", 30108, "PLAYER"))
        if remaining then
            -- Pandemic refresh: if remaining duration is less than 30% of base duration, extend it
            local base_duration = 15 -- UA base duration in MoP
            if remaining < (base_duration * 0.3) then
                -- Note: Extension handled by default aura system
            end
        end
    elseif spellID == 980 then -- Agony
        -- Agony application (stack building handled in aura system elsewhere)
        -- Ensure internal tracking starts
    elseif spellID == 48181 then -- Haunt
        -- Clear in-flight on application
        if hauntFlight.active and hauntFlight.destGUID == destGUID then
            hauntFlight.active = false
            hauntFlight.expires = 0
        end
    end
end)

-- DoT tick damage tracking for Malefic Grasp and Soul Shard generation
RegisterAfflictionCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if (spellID == 172 or spellID == 30108 or spellID == 980) and state and state.soul_shards then
        -- Deterministic expected shard gain model: average proc chance converted to fractional value.
        -- Approximate: baseline 2% per tick, criticals double contribution.
        local critical = select(21, CombatLogGetCurrentEventInfo())
        local base = 0.02
        if spellID == 30108 then base = 0.025 end -- UA slightly higher
        if spellID == 980 then
            -- Agony ramps: use stack-based scaling up to ~4% at 10 stacks.
            local stacks = select(3, FindUnitDebuffByID("target", 980, "PLAYER")) or 1
            base = 0.01 + 0.003 * stacks
        end
        if critical then base = base * 2 end
        -- Record last DoT tick time for state consumers.
        state.last_dot_tick = timestamp or state.query_time or GetTime()
        -- Soul shard generation is handled by the resource system automatically
    end
end)

-- Track target death time to support drain_soul_death modeling and guard UI loader warnings.
RegisterAfflictionCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    if destGUID and destGUID == UnitGUID("target") then
        state.last_target_death = timestamp or state.query_time or GetTime()
        state.target_died = true
    end
end)

-- Nightfall proc tracking
RegisterAfflictionCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 17941 then -- Nightfall
        -- Track Nightfall proc for instant Shadow Bolt
    elseif spellID == 74434 then -- Soulburn
        -- Track Soul Burn application for enhanced spells
    end
end)

-- Enhanced Mana resource system for Affliction Warlock
spec:RegisterResource( 0 )

-- Soul Shards resource system for Affliction
spec:RegisterResource( 7, {
    -- Soul Shard generation from DoT ticks
    dot_generation = {
        last = function ()
            return state.last_dot_tick or 0
        end,
        interval = 3, -- DoT tick interval
    value = function()
            -- Corruption, Agony, and UA ticks can generate Soul Shards
            local shards_generated = 0
            if state.debuff.corruption.up then shards_generated = shards_generated + 0.1 end
            if state.debuff.agony.up then shards_generated = shards_generated + 0.15 end
            if state.debuff.unstable_affliction.up then shards_generated = shards_generated + 0.2 end
            return shards_generated
        end,
    },

    -- Drain Soul generation when target dies
    drain_soul_death = {
        last = function ()
            return state.last_target_death or 0
        end,
        interval = 1,
        value = function()
            -- Drain Soul generates 4 Soul Shards when target dies
            local la = rawget( state, "last_ability" )
            return ( la == "drain_soul" ) and state.target_died and 4 or 0
        end,
    },
}, {
    -- Soul Shard generation modifiers
    nightfall_bonus = function ()
        return state.talent.nightfall.enabled and 0.1 or 0 -- 10% bonus from Nightfall
    end,

    soul_harvest_bonus = function ()
        return state.talent.soul_harvest.enabled and 0.2 or 0 -- 20% bonus from Soul Harvest
    end,
} )

-- Comprehensive Tier Sets with all difficulty levels
spec:RegisterGear( "tier14", { -- Tier 14 (Heart of Fear) - Sha-Skin Regalia
    85316, 85317, 85318, 85319, 85320, -- LFR
    85943, 85944, 85945, 85946, 85947, -- Normal
    86590, 86591, 86592, 86593, 86594, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_affliction", {
    id = 105843,
    duration = 30,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_affliction", {
    id = 105844,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterGear( "tier15", { -- Tier 15 (Throne of Thunder) - Vestments of the Faceless Shroud
    95298, 95299, 95300, 95301, 95302, -- LFR
    95705, 95706, 95707, 95708, 95709, -- Normal
    96101, 96102, 96103, 96104, 96105, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_affliction", {
    id = 138129,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_affliction", {
    id = 138132,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterGear( "tier16", { -- Tier 16 (Siege of Orgrimmar) - Horrorific Regalia
    99593, 99594, 99595, 99596, 99597, -- LFR
    98278, 98279, 98280, 98281, 98282, -- Normal
    99138, 99139, 99140, 99141, 99142, -- Heroic
    99828, 99829, 99830, 99831, 99832, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_affliction", {
    id = 144912,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_affliction", {
    id = 144915,
    duration = 8,
    max_stack = 3,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148009,
    duration = 4,
    max_stack = 1,
} )

-- Notable Trinkets
spec:RegisterGear( "kardris_toxic_totem", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "purified_bindings_of_immerseus", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

spec:RegisterGear( "black_blood_of_yshaarj", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

spec:RegisterGear( "assurance_of_consequence", 104736, {
    trinket1 = 104736,
    trinket2 = 104736,
} )

spec:RegisterGear( "bloodtusk_shoulderpads", 105564, {
    shoulder = 105564,
} )

-- Meta Gems
spec:RegisterGear( "burning_primal_diamond", 76884, {
    head = 76884,
} )

spec:RegisterGear( "chaotic_primal_diamond", 76895, {
    head = 76895,
} )

-- PvP Sets
spec:RegisterGear( "grievous_gladiator", { -- Season 14 PvP
    -- Head, Shoulder, Chest, Hands, Legs
} )

spec:RegisterGear( "prideful_gladiator", { -- Season 15 PvP
    -- Head, Shoulder, Chest, Hands, Legs
} )

-- Challenge Mode Set
spec:RegisterGear( "challenge_mode", {
    -- Challenge Mode Warlock set
} )

-- Comprehensive Talent System (MoP Talent Trees)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Self-Healing
    dark_regeneration         = { 1, 1, 108359 }, -- Instantly restores 30% of your maximum health. Restores an additional 6% of your maximum health for each of your damage over time effects on hostile targets within 20 yards. 2 min cooldown.
    soul_leech                = { 1, 2, 108370 }, -- When you deal damage with Malefic Grasp, Drain Soul, Shadow Bolt, Touch of Chaos, Chaos Bolt, Incinerate, Fel Flame, Haunt, or Soul Fire, you create a shield that absorbs (45% of Spell power) damage for 15 sec.
    harvest_life              = { 1, 3, 108371 }, -- Drains the health from up to 3 nearby enemies within 20 yards, causing Shadow damage and gaining 2% of maximum health per enemy every 1 sec. Lasts 6 sec. 2 min cooldown.

    -- Tier 2 (Level 30) - Crowd Control
    howl_of_terror            = { 2, 1, 5484 },   -- Causes all nearby enemies within 10 yards to flee in terror for 8 sec. Targets are disoriented for 3 sec. 40 sec cooldown.
    mortal_coil               = { 2, 2, 6789 },   -- Horrifies an enemy target, causing it to flee in fear for 3 sec. The caster restores 11% of maximum health when the effect successfully horrifies an enemy. 30 sec cooldown.
    shadowfury                = { 2, 3, 30283 },  -- Stuns all enemies within 8 yards for 3 sec. 30 sec cooldown.

    -- Tier 3 (Level 45) - Survivability
    soul_link                 = { 3, 1, 108415 }, -- 20% of all damage taken by the Warlock is redirected to your demon pet instead. While active, both your demon and you will regenerate 3% of maximum health each second. Lasts as long as your demon is active.
    sacrificial_pact          = { 3, 2, 108416 }, -- Sacrifice your summoned demon to prevent 300% of your maximum health in damage divided among all party and raid members within 40 yards. Lasts 8 sec. 3 min cooldown.
    dark_bargain              = { 3, 3, 110913 }, -- Prevents all damage for 8 sec. When the shield expires, 50% of the total amount of damage prevented is dealt to the caster over 8 sec. 3 min cooldown.

    -- Tier 4 (Level 60) - Utility
    blood_fear                = { 4, 1, 111397 }, -- When you use Healthstone, enemies within 15 yards are horrified for 4 sec. 45 sec cooldown.
    burning_rush              = { 4, 2, 111400 }, -- Increases your movement speed by 50%, but also deals damage to you equal to 4% of your maximum health every 1 sec. Toggle ability.
    unbound_will              = { 4, 3, 108482 }, -- Removes all Magic, Curse, Poison, and Disease effects and makes you immune to controlling effects for 6 sec. 2 min cooldown.

    -- Tier 5 (Level 75) - Demon Enhancement
    grimoire_of_supremacy     = { 5, 1, 108499 }, -- Your demons deal 20% more damage and are transformed into more powerful demons with enhanced abilities.
    grimoire_of_service       = { 5, 2, 108501 }, -- Summons a second demon with 100% increased damage for 15 sec. The demon uses its special ability immediately. 2 min cooldown.
    grimoire_of_sacrifice     = { 5, 3, 108503 }, -- Sacrifices your demon to grant you an ability depending on the demon sacrificed, and increases your damage by 15%. Lasts until you summon a demon.

    -- Tier 6 (Level 90) - DPS/Utility
    archimondes_vengeance     = { 6, 1, 108505 }, -- When you take direct damage, you reflect 15% of the damage taken back at the attacker. For the next 10 sec, you reflect 45% of all direct damage taken. This ability has 3 charges. 30 sec recharge.
    kiljaedens_cunning        = { 6, 2, 108507 }, -- Your Malefic Grasp, Drain Life, Drain Soul, and Harvest Life can be cast while moving. When you stop moving, their damage is increased by 15% for 5 sec.
    mannoroths_fury           = { 6, 3, 108508 }, -- Your Rain of Fire, Hellfire, and Immolation Aura have no cooldown, cost no Soul Shards, and their damage is increased by 500%. They also no longer apply a damage over time effect.
} )

-- Comprehensive Glyph System (40+ Glyphs)
spec:RegisterGlyphs( {
    -- Major Glyphs - Combat Enhancement
    [56232] = "dark_soul",              -- Your Dark Soul also increases the critical strike damage bonus of your critical strikes by 10%.
    [56249] = "drain_life",             -- When using Drain Life, your Mana regeneration is increased by 10% of spirit and you gain 2% of your maximum health per second.
    [56235] = "drain_soul",             -- You gain 30% increased movement speed while channeling Drain Soul, and Drain Soul channels 50% faster.
    [56212] = "fear",                   -- Your Fear spell no longer causes the target to run in fear. Instead, the target is disoriented and takes 20% more damage for 8 sec.
    [56218] = "health_funnel",          -- Health Funnel heals your demon for 50% more but costs 20% less health.
    [56228] = "healthstone",            -- Increases the amount of health restored by your Healthstone by 20% and reduces its cooldown by 30 sec.
    [63302] = "howl_of_terror",         -- Reduces the cooldown of your Howl of Terror by 8 sec and its radius is increased by 5 yards.
    [56240] = "life_tap",               -- Life Tap generates 20% additional mana and no longer costs health.
    [56214] = "malefic_grasp",          -- Malefic Grasp channels 20% faster and increases the damage of your damage over time spells by an additional 10%.
    [56229] = "shadowburn",             -- Shadowburn generates a Soul Shard when it deals damage, rather than only when it kills the target.
    [58070] = "shadow_bolt",            -- Shadow Bolt has a 15% chance to not consume a Soul Shard when empowered by Soul Burn.
    [56226] = "soul_swap",              -- Soul Swap can now affect up to 2 additional nearby targets when used on a target with Corruption, Agony, and Unstable Affliction.
    [56248] = "unstable_affliction",    -- Unstable Affliction can be applied to 3 targets, but its damage is reduced by 25%.
    [63320] = "voidwalker",            -- Increases your Voidwalker's health by 30% and its Taunt now affects up to 3 enemies.

    -- Major Glyphs - Resource Management
    [56233] = "demon_training",         -- Your demons deal 10% more damage and take 10% less damage.
    [70947] = "eternal_resolve",        -- Reduces the cooldown of Unending Resolve by 60 sec.
    [56241] = "imp_swarm",              -- Your Wild Imp demons have 30% increased damage and summoning them costs 50% fewer resources.
    [70946] = "dark_regeneration",      -- Dark Regeneration heals you for an additional 25% over 8 sec.
    [56244] = "soul_link",              -- Soul Link spreads 5% of damage taken to all party and raid members within 20 yards.
    [58054] = "burning_rush",           -- Burning Rush increases movement speed by an additional 20% but the health cost is increased by 2%.
    [56239] = "harvest_life",           -- Harvest Life affects 2 additional targets and heals you for 50% more.
    [58079] = "sacrificial_pact",       -- Reduces the cooldown of Sacrificial Pact by 60 sec and increases its absorption by 50%.

    -- Major Glyphs - Utility Enhancement
    [56224] = "banish",                 -- Increases the duration of your Banish by 5 sec and allows it to be used on Aberrations.
    [56231] = "create_healthstone",     -- You can have up to 5 Healthstones in your bags, and creating them grants you one immediately.
    [56230] = "create_soulstone",       -- Reduces the mana cost of Create Soulstone by 70% and allows you to have 2 in your bags.
    [63311] = "curse_of_elements",      -- Your Curse of the Elements also increases all damage dealt to the target by 5%.
    [56213] = "enslave_demon",          -- Reduces the cast time of Enslave Demon by 50% and its duration is increased by 10 sec.
    [56223] = "eye_of_kilrogg",         -- Increases the movement speed of your Eye of Kilrogg by 50% and extends its duration by 45 sec.
    [56217] = "unending_breath",        -- Your Unending Breath spell also grants water breathing and increases swim speed by 50%.

    -- Minor Glyphs - Visual and Convenience
    [58081] = "verdant_spheres",        -- Your Soul Shards appear as green orbs instead of purple.
    [63310] = "soul_stone",             -- Reduces the mana cost of your Soulstone by 50%.
    [70945] = "floating_shards",        -- Your Soul Shards float around you instead of being contained.
    [58080] = "dark_apotheosis",        -- Changes the visual of your Metamorphosis to be more shadow-themed.
    [63312] = "felguard",               -- Your Felguard appears larger and more intimidating.
    [70944] = "wrathguard",             -- Your Wrathguard dual-wields larger weapons.
    [58077] = "observer",               -- Your Observer has an improved visual effect and tracking abilities.
    [58078] = "abyssal",                -- Your Infernal and Abyssal have enhanced fire effects.
    [63313] = "imp",                    -- Your Imp appears in different colors based on your current specialization.
    [63314] = "succubus",               -- Your Succubus has an improved seduction animation and visual effects.    [63315] = "voidlord",               -- Your Voidwalker appears as a more intimidating Voidlord when using Grimoire of Supremacy.
    [63316] = "shivarra",               -- Your Succubus appears as a Shivarra when using Grimoire of Supremacy.
    [70948] = "terrorguard",            -- Your Felguard appears as a Terrorguard when using Grimoire of Supremacy.
    [70949] = "doomguard",              -- Enhances the visual effects of your Doomguard summon.
    [58076] = "infernal",               -- Your Infernal has enhanced meteor impact and fire aura effects.
      -- Minor Glyphs
    [57259] = "conflagrate",       -- Your Conflagrate spell no longer consumes Immolate from the target.
    [57260] = "demonic_circle",     -- Your Demonic Circle: Teleport spell no longer clears your Soul Shards.
    [56246] = "eye_of_kilrogg",     -- Increases the vision radius of your Eye of Kilrogg by 30 yards.
    [58068] = "falling_meteor",     -- Your Meteor Strike now creates a surge of fire outward from the demon's position.
    [58094] = "felguard",           -- Increases the size of your Felguard, making him appear more intimidating.
    [57261] = "health_funnel",      -- Increases the effectiveness of your Health Funnel spell by 30%.
    [57262] = "hand_of_guldan",     -- Your Hand of Gul'dan creates a shadow explosion that can damage up to 5 nearby enemies.
    [57263] = "shadow_bolt",        -- Your Shadow Bolt now creates a column of fire that damages all enemies in its path.
    [45785] = "verdant_spheres",    -- Changes the appearance of your Shadow Orbs to 3 floating green fel spheres.
    [58093] = "voidwalker",         -- Increases the size of your Voidwalker, making him appear more intimidating.
} )

-- Advanced Aura System with sophisticated generate functions
spec:RegisterAuras( {
    -- Core Affliction DoTs with enhanced tracking
    corruption = {
        id = 146739,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        debuff = true,
        pandemic = true,
        generate = function( t )
            local now = state.query_time or GetTime()
            local p = state.debuff and state.debuff.corruption

            if p and (p.applied or 0) > 0 then
                t.name = "Corruption"
                t.count = (p.count and p.count > 0) and p.count or 1
                t.expires = p.expires or 0
                t.applied = p.applied or 0
                t.duration = math.max( 0, (t.expires or 0) - (t.applied or 0) )
                t.caster = "player"
            else
                -- Fallback to live aura if no prediction is present.
                local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 146739 )
                if name and caster == "player" then
                    t.name = name
                    t.count = 1
                    t.expires = expirationTime
                    t.applied = expirationTime - duration
                    t.caster = caster
                    t.duration = duration
                else
                    t.count = 0
                    t.expires = 0
                    t.applied = 0
                    t.caster = "nobody"
                    t.duration = 18
                end
            end

            -- Derived helpers for APL compatibility
            t.percent_increase = get_dot_percent_increase("corruption") or 0
            t.snapshot_value = ( dot_snapshot.corruption and dot_snapshot.corruption.value ) or 0
            t.crit_pct = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0

            -- Calculate ticks_remain and refreshable with level-appropriate pandemic mechanics
            local remains = math.max(0, (t.expires or 0) - now)
            t.ticks_remain = remains / 3

            local has_pandemic = UnitLevel("player") >= 90
            local pandemic_threshold = (t.duration or 18) * (has_pandemic and 0.5 or 0.1)

            if t.expires > 0 and t.expires > now then
                t.refreshable = remains <= pandemic_threshold
            else
                t.refreshable = true
            end
        end,
    },

    agony = {
        id = 980,
        duration = 24,
        tick_time = 2,
        max_stack = 10,
        debuff = true,
        pandemic = true,
        generate = function( t )
            local now = state.query_time or GetTime()
            local p = state.debuff and state.debuff.agony

            if p and (p.applied or 0) > 0 then
                t.name = "Agony"
                t.count = (p.count and p.count > 0) and p.count or 1
                t.expires = p.expires or 0
                t.applied = p.applied or 0
                t.duration = math.max( 0, (t.expires or 0) - (t.applied or 0) )
                t.caster = "player"
            else
                local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 980 )
                if name and caster == "player" then
                    t.name = name
                    t.count = count or 1
                    t.expires = expirationTime
                    t.applied = expirationTime - duration
                    t.caster = caster
                    t.duration = duration
                else
                    t.count = 0
                    t.expires = 0
                    t.applied = 0
                    t.caster = "nobody"
                    t.duration = 24
                end
            end
            -- Derived helpers for APL compatibility
            t.percent_increase = get_dot_percent_increase("agony") or 0
            t.snapshot_value = ( dot_snapshot.agony and dot_snapshot.agony.value ) or 0
            t.crit_pct = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0

            -- Calculate ticks_remain and refreshable with level-appropriate pandemic mechanics
            local remains = math.max(0, (t.expires or 0) - now)
            t.ticks_remain = remains / 2

            local has_pandemic = UnitLevel("player") >= 90
            local pandemic_threshold = (t.duration or 24) * (has_pandemic and 0.5 or 0.1)

            if t.expires > 0 and t.expires > now then
                t.refreshable = remains <= pandemic_threshold
            else
                t.refreshable = true
            end
        end,
    },

    unstable_affliction = {
        id = 30108,
        duration = 14,
        tick_time = 2,
        max_stack = 1,
        debuff = true,
        pandemic = true,
        generate = function( t )
            local now = state.query_time or GetTime()
            local p = state.debuff and state.debuff.unstable_affliction

            if p and (p.applied or 0) > 0 then
                t.name = "Unstable Affliction"
                t.count = 1
                t.expires = p.expires or 0
                t.applied = p.applied or 0
                t.duration = math.max( 0, (t.expires or 0) - (t.applied or 0) )
                t.caster = "player"
            else
                local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 30108 )
                if name and caster == "player" then
                    t.name = name
                    t.count = 1
                    t.expires = expirationTime
                    t.applied = expirationTime - duration
                    t.caster = caster
                    t.duration = duration
                else
                    t.count = 0
                    t.expires = 0
                    t.applied = 0
                    t.caster = "nobody"
                    t.duration = 14
                end
            end
            -- Derived helpers for APL compatibility
            t.percent_increase = get_dot_percent_increase("unstable_affliction") or 0
            t.snapshot_value = ( dot_snapshot.unstable_affliction and dot_snapshot.unstable_affliction.value ) or 0
            t.crit_pct = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0

            -- Calculate ticks_remain and refreshable with level-appropriate pandemic mechanics
            local remains = math.max(0, (t.expires or 0) - now)
            t.ticks_remain = remains / 2

            local has_pandemic = UnitLevel("player") >= 90
            local pandemic_threshold = (t.duration or 14) * (has_pandemic and 0.5 or 0.1)

            if t.expires > 0 and t.expires > now then
                t.refreshable = remains <= pandemic_threshold
            else
                t.refreshable = true
            end
        end,
    },

    haunt = {
        id = 48181,
        duration = 8,
        max_stack = 1,
        debuff = true,
    },

    -- Moved to ./Classes.lua, use magic_vulnerability instead
    -- curse_of_elements = {
    --     id = 1490,
    --     duration = 300,
    --     max_stack = 1,
    --     debuff = true,
    --     generate = function( t )
    --         local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 1490 )

    --         if name and caster == "player" then
    --             t.name = name
    --             t.count = 1
    --             t.expires = expirationTime
    --             t.applied = expirationTime - duration
    --             t.caster = caster
    --             t.duration = duration
    --             return
    --         end

    --         t.count = 0
    --         t.expires = 0
    --         t.applied = 0
    --         t.caster = "nobody"
    --         t.duration = 300
    --         return
    --     end,
    -- },

    seed_of_corruption = {
        id = 27243,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 27243 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 18
            return
        end,
    },

    soulburn_seed_of_corruption = {
        id = 114790,
        duration = 18,
        max_stack = 1,
        debuff = true,

        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 114790 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 18
            return
        end,
    },

    -- Player buffs (using default aura tracking)
    nightfall = {
        id = 17941,
        duration = 12,
        max_stack = 1,
    },

    soul_burn = {
        id = 74434,
        duration = 30,
        max_stack = 1,
    },

    -- Dark Soul forms with enhanced tracking
    dark_soul_knowledge = {
        id = 113858,
        duration = 20,
        max_stack = 1,
    },

    dark_soul_misery = {
        id = 113860,
        duration = 20,
        max_stack = 1,
    },

    -- Channeled abilities
    malefic_grasp = {
        id = 103103,
        duration = 3,
        tick_time = 1,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 103103 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 3
        end,
    },

    drain_soul = {
        id = 1120,
        duration = 6,
        tick_time = 1,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 1120 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 6
        end,
    },

    -- Defensive and utility auras (using default tracking)
    unending_resolve = {
        id = 104773,
        duration = 8,
        max_stack = 1,
    },

    dark_bargain = {
        id = 110913,
        duration = 8,
        max_stack = 1,
    },

    sacrificial_pact = {
        id = 108416,
        duration = 8,
        max_stack = 1,
    },

    -- Movement and utility
    burning_rush = {
        id = 111400,
        duration = 3600,
        max_stack = 1,
    },

    unbound_will = {
        id = 108482,
        duration = 6,
        max_stack = 1,
    },

    -- Armor buffs
    fel_armor = {
        id = 28176,
        duration = 1800,
        max_stack = 1,
    },

    demon_armor = {
        id = 687,
        duration = 1800,
        max_stack = 1,
    },

    -- Talent-based auras
    soul_link = {
        id = 108415,
        duration = 3600,
        max_stack = 1,
    },

    grimoire_of_sacrifice = {
        id = 108503,
        duration = 15,
        max_stack = 1,
    },

    -- Tier set bonuses (using default tracking)
    tier14_2pc_affliction = {
        id = 105843,
        duration = 30,
        max_stack = 1,
    },

    tier14_4pc_affliction = {
        id = 105844,
        duration = 8,
        max_stack = 1,
    },

    tier15_2pc_affliction = {
        id = 138129,
        duration = 15,
        max_stack = 1,
    },

    tier15_4pc_affliction = {
        id = 138132,
        duration = 6,
        max_stack = 1,
    },

    tier16_2pc_affliction = {
        id = 144912,
        duration = 20,
        max_stack = 1,
    },

    tier16_4pc_affliction = {
        id = 144915,
        duration = 8,
        max_stack = 3,
    },

    -- Legendary cloak proc
    legendary_cloak_proc = {
        id = 148009,
        duration = 4,
        max_stack = 1,
    },

    -- Missing auras referenced in action lists (using default tracking)
    dark_soul = {
        id = 113860,
        duration = 20,
        max_stack = 1,
    },

    soulburn = {
        id = 74434,
        duration = 30,
        max_stack = 1,
    },

    haunting_spirits = {
        id = 157698, -- Custom tracking ID
        duration = 8,
        max_stack = 1,
        generate = function( t )
            -- This is typically generated from Haunt expiration
            local haunt_expired = state.debuff.haunt.remains == 0 and state.debuff.haunt.applied > 0

            if haunt_expired then
                t.name = "Haunting Spirits"
                t.count = 1
                t.expires = state.query_time + 8
                t.applied = state.query_time
                t.caster = "player"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    drain_life = {
        id = 689,
        duration = 5,
        tick_time = 1,
        max_stack = 1,
        debuff = true,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 689 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 5
        end,
    },

    soul_swap = {
        id = 86211,
        duration = 20,
        max_stack = 1,

    },

    soul_swap_exhale = {
        id = 86213,
        duration = 0.1, -- Very short duration, just for state tracking
        max_stack = 1,
        generate = function( t )
            -- This is a state tracker for when Soul Swap has been exhaled
            if state.prev_gcd[1] and state.prev_gcd[1].soul_swap_exhale then
                t.name = "Soul Swap Exhale"
                t.count = 1
                t.expires = state.query_time + 0.1
                t.applied = state.query_time
                t.caster = "player"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    -- Dark Intent aura
    dark_intent = {
        id = 109773,
        duration = 3600,
        max_stack = 1,
    },
} )

-- Affliction Warlock abilities
spec:RegisterAbilities( {
    -- Core Rotational Abilities (Shadow Bolt is not used by MoP Affliction)
    haunt = {
        id = 48181,
        cast = function() return 1.5 * haste end,
        cooldown = 8,
        gcd = "spell",

        spend = 1,
        spendType = "soul_shards",

        startsCombat = true,
        texture = 236298,

    handler = function() applyDebuff( "target", "haunt" ) end,
    },

    agony = {
        id = 980,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.1,
        spendType = "mana",

        startsCombat = true,
        texture = 136139,

        aura = "agony",

        usable = function()
            if state.planned_dot and state.planned_dot.agony then return false, "agony already planned" end
            return true
        end,

        handler = function()
            applyDebuff( "target", "agony" )
            state.last_ability = "agony"
            dot_snapshot.agony.value = get_dot_snapshot_value()
            dot_snapshot.agony.crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
            if state.planned_dot then state.planned_dot.agony = true end
        end,
    },

    corruption = {
        id = 172,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.1,
        spendType = "mana",

        startsCombat = true,
        texture = 136118,

        aura = "corruption",

        usable = function()
            if state.planned_dot and state.planned_dot.corruption then return false, "corruption already planned" end
            return true
        end,

        handler = function()
            applyDebuff( "target", "corruption" )
            state.last_ability = "corruption"
            dot_snapshot.corruption.value = get_dot_snapshot_value()
            dot_snapshot.corruption.crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
            if state.planned_dot then state.planned_dot.corruption = true end
        end,
    },

    unstable_affliction = {
        id = 30108,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        spend = 0.15,
        spendType = "mana",

        startsCombat = true,
        texture = 136228,

        usable = function()
            if state.planned_dot and state.planned_dot.unstable_affliction then return false, "unstable_affliction already planned" end
            return true
        end,

        handler = function()
            applyDebuff( "target", "unstable_affliction" )
            state.last_ability = "unstable_affliction"
            dot_snapshot.unstable_affliction.value = get_dot_snapshot_value()
            dot_snapshot.unstable_affliction.crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
            if state.planned_dot then state.planned_dot.unstable_affliction = true end
        end,
    },

    malefic_grasp = {
        id = 103103,
        cast = function() return 3 * haste end,
        cooldown = 0,
        gcd = "spell",

        channeled = true,

        spend = 0.04, -- Per tick
        spendType = "mana",

        startsCombat = true,
        texture = 236296,

        handler = function()
            applyDebuff( "target", "malefic_grasp" )
        end,

        finish = function()
            removeDebuff( "target", "malefic_grasp" )
        end,
    },

    drain_soul = {
        id = 1120,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",

        channeled = true,

        spend = 0.04, -- Per tick
        spendType = "mana",

        startsCombat = true,
        texture = 136163,

        handler = function()
            applyDebuff( "target", "drain_soul" )
        end,

        finish = function()
            removeDebuff( "target", "drain_soul" )
            -- Target died while channeling?
            if target.health.pct <= 0 then
                gain( 1, "soul_shards" )
            end
        end,
    },

    seed_of_corruption = {
        id = 27243,
        cast = function() return 2 * haste end,
        cooldown = 0,
        gcd = "spell",

        spend = 0.15,
        spendType = "mana",

        startsCombat = true,
        texture = 136193,

        handler = function()
            applyDebuff( "target", "seed_of_corruption" )
        end,
    },

    life_tap = {
        id = 1454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 136126,

        handler = function()
            -- Costs 15% health, returns 15% mana
            local health_cost = health.max * 0.15
            local mana_return = mana.max * 0.15

            spend( health_cost, "health" )
            gain( mana_return, "mana" )
        end,
    },

    fear = {
        id = 5782,
        cast = function() return 1.5 * haste end,
        cooldown = function() return glyph.nightmares.enabled and 15 or 23 end,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = true,
        texture = 136183,

        handler = function()
            applyDebuff( "target", "fear" )
        end,
    },

    curse_of_elements = {
        id = 1490,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.1,
        spendType = "mana",

        startsCombat = true,
        texture = 136130,

        handler = function()
            applyDebuff( "target", "curse_of_elements" )
        end,
    },

    -- Soul Shards spenders
    soul_swap = {
        id = 86121,
        cast = 0,
        cooldown = function() return glyph.soul_swap.enabled and 0 or 30 end,
        gcd = "spell",

        spend = function() return glyph.soul_swap.enabled and 1 or 0 end,
        spendType = "soul_shards",

        startsCombat = false,
        texture = 460857,

        usable = function()
            -- Check if there are DoTs on the target
            if not (debuff.agony.up or debuff.corruption.up or debuff.unstable_affliction.up) then
                return false, "target has no affliction DoTs to swap"
            end
            return true
        end,

        handler = function()
            -- Store target's DoTs
            applyBuff( "soul_swap" )

            -- Remove DoTs from target if not using Exhale
            if buff.soul_swap_exhale.down then
                removeDebuff( "target", "agony" )
                removeDebuff( "target", "corruption" )
                removeDebuff( "target", "unstable_affliction" )
            end
        end,

        copy = { 119678 },
    },

    soul_swap_exhale = {
        id = 86213,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,
        texture = 460857,

        usable = function()
            return buff.soul_swap.up, "soul_swap buff not active"
        end,

        handler = function()
            -- Apply DoTs from Soul Swap to target
            applyDebuff( "target", "agony" )
            applyDebuff( "target", "corruption" )
            applyDebuff( "target", "unstable_affliction" )

            removeBuff( "soul_swap" )
            applyBuff( "soul_swap_exhale" )
        end,
    },

    -- Cooldowns
    dark_soul_misery = {
        id = 113860,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 463284,

        handler = function()
            applyBuff( "dark_soul_misery" )
        end,
    },

    -- Dark Intent (precombat self-buff in APL imports)
    dark_intent = {
        id = 109773, -- Using MoP era raid-wide spellpower/haste buff ID
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
        texture = 463285,
        handler = function()
            applyBuff( "dark_intent" )
        end,
        usable = function()
            if buff.dark_intent.up then return false, "dark_intent active" end
            return true
        end,
    },

    summon_doomguard = {
        id = 18540,
        cast = 0,
        cooldown = 600,
        gcd = "spell",

        toggle = "cooldowns",

        spend = 1,
        spendType = "soul_shards",

        startsCombat = false,
        texture = 615103,

        handler = function()
            -- Summon guardian
        end,
    },

    summon_terrorguard = {
        id = 112927,
        cast = 0,
        cooldown = 600,
        gcd = "spell",

        toggle = "cooldowns",

        spend = 1,
        spendType = "soul_shards",

        startsCombat = false,
        texture = 615098,

        handler = function()
            -- Summon guardian
        end,
    },

    -- Defensive and Utility
    dark_bargain = {
        id = 110913,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "defensives",

        startsCombat = false,
        texture = 538038,

        handler = function()
            applyBuff( "dark_bargain" )
        end,
    },

    unending_resolve = {
        id = 104773,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "defensives",

        startsCombat = false,
        texture = 136150,

        handler = function()
            applyBuff( "unending_resolve" )
        end,
    },

    demonic_circle_summon = {
        id = 48018,
        cast = 0.5,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 136126,

        handler = function()
            applyBuff( "demonic_circle" )
        end,
    },

    demonic_circle_teleport = {
        id = 48020,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        startsCombat = false,
        texture = 607512,

        handler = function()
            -- Teleport to circle
        end,
    },

    -- Talent abilities
    howl_of_terror = {
        id = 5484,
        cast = 0,
        cooldown = 40,
        gcd = "spell",

        spend = 0.1,
        spendType = "mana",

        startsCombat = true,
        texture = 607510,

        handler = function()
            -- Fear all enemies in 10 yards
        end,
    },

    mortal_coil = {
        id = 6789,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 0.06,
        spendType = "mana",

        startsCombat = true,
        texture = 607514,

        handler = function()
            -- Fear target and heal 11% of max health
            local heal_amount = health.max * 0.11
            gain( heal_amount, "health" )
        end,
    },

    shadowfury = {
        id = 30283,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 0.06,
        spendType = "mana",

        startsCombat = true,
        texture = 457223,

        handler = function()
            -- Stun all enemies in 8 yards
        end,
    },

    grimoire_of_sacrifice = {
        id = 108503,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        startsCombat = false,
        texture = 538443,

        handler = function()
            applyBuff( "grimoire_of_sacrifice" )
        end,
    },

    fel_flame = {
        id = 77799,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = true,
        texture = 135795,

        handler = function()
            -- Instant damage spell
        end,
    },

    summon_infernal = {
        id = 1122,
        cast = 0,
        cooldown = 600,
        gcd = "spell",

        toggle = "cooldowns",

        spend = 1,
        spendType = "soul_shards",

        startsCombat = false,
        texture = 136219,

        handler = function()
            -- Summon infernal
        end,
    },

    drain_life = {
        id = 689,
        cast = function() return 5 * haste end,
        cooldown = 0,
        gcd = "spell",

        channeled = true,

        spend = 0.04, --Per tick
        spendType = "mana",

        startsCombat = true,
        texture = 136169,

        handler = function()
            applyDebuff( "target", "drain_life" )
        end,

        finish = function()
            removeDebuff( "target", "drain_life" )
        end,
    },

    soulburn = {
        id = 74434,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 1,
        spendType = "soul_shards",

        startsCombat = false,
        texture = 463286,

        usable = function()
            if buff.soul_burn.up then return false, "soul burn active" end
            local shards = ( state.soul_shards and state.soul_shards.current ) or 0
            if shards < 1 then return false, "requires 1 soul shard" end
            return true
        end,

        handler = function()
            applyBuff( "soul_burn" )
        end,
    },

    soulburn_seed_of_corruption = {
        id = 114790,
        cast = 2,
        cooldown = 0,
        gcd = "spell",

        spend = 0,
        spendType = "soul_shards",

        startsCombat = true,
        texture = 136193,

        handler = function()
            applyDebuff( "target", "soulburn_seed_of_corruption" )
        end,
    },

    -- Summon demons (MoP: cost 1 Soul Shard, 6s cast)
    summon_imp = {
        id = 688,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136218,
        handler = function()
            -- Emulate pet becoming active as soon as the summon is committed in the planner.
            state.pet.alive = true
            state.pet.family = "Imp"
        end,
    },
    summon_voidwalker = {
        id = 697,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136221,
        handler = function()
            state.pet.alive = true
            state.pet.family = "Voidwalker"
        end,
    },
    summon_succubus = {
        id = 712,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136220,
        handler = function()
            state.pet.alive = true
            state.pet.family = "Succubus"
        end,
    },
    summon_felhunter = {
        id = 691,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 136217,
        handler = function()
            state.pet.alive = true
            state.pet.family = "Felhunter"
        end,
    },
    summon_observer = {
        id = 112869,
        cast = function() return 6 * haste end,
        cooldown = 0,
        gcd = "spell",
        spend = 1,
        spendType = "soul_shards",
        startsCombat = false,
        texture = 538445,
        handler = function()
            state.pet.alive = true
            state.pet.family = "Observer"
        end,
    },
} )

-- Ability aliases for action list compatibility
spec:RegisterAbilities( {
    summon_pet = { id = 691, alias = "summon_felhunter" },
} )

-- State Expressions for Affliction
-- Avoid naming collision with the soul_shards resource table; rely on resource access or the alias below.
spec:RegisterStateExpr( "soul_shards_deficit", function()
    local r = class and class.resources and class.resources.soul_shards and class.resources.soul_shards.state
    if r then
        local max_val = r.max or 0
        local cur = r.current or 0
        return max_val - cur
    end
    return 0
end )
spec:RegisterStateExpr( "current_soul_shards", function()
    local r = class and class.resources and class.resources.soul_shards and class.resources.soul_shards.state
    if r then
        return r.current or 0
    end
    return 0
end )

-- Rely on the resource system to create `state.soul_shards`; avoid shadow proxy tables that can mask initialization.

-- Provide minimal movement table for APL references like movement.remains
spec:RegisterStateTable( "movement", setmetatable( { remains = 0 }, { __index = function() return 0 end } ) )

spec:RegisterStateExpr( "nightfall_proc", function()
    return buff.nightfall.up and 1 or 0
end )

spec:RegisterStateExpr( "soul_harvest_active", function()
    return buff.soul_harvest.up and 1 or 0
end )

spec:RegisterStateExpr( "haunt_debuff_active", function()
    return debuff.haunt.up and 1 or 0
end )

spec:RegisterStateExpr( "malefic_grasp_bonus", function()
    return buff.malefic_grasp.up and 0.25 or 0 -- 25% damage bonus
end )

spec:RegisterStateExpr( "dark_soul_bonus", function()
    return buff.dark_soul.up and 0.3 or 0 -- 30% damage bonus
end )

spec:RegisterStateExpr( "spell_power", function()
    local sp = ( _GetSpellBonusDamage and _GetSpellBonusDamage( 6 ) ) or 0
    return sp
end )

-- Current crit chance for Shadow school; safe during import
spec:RegisterStateExpr( "crit_pct_current", function()
    local crit = ( _GetSpellCritChance and _GetSpellCritChance( 6 ) ) or 0
    return crit
end )

-- Expose options to APL via state expressions
spec:RegisterStateExpr( "soc_spread", function()
    return state.settings and state.settings.soc_spread and 1 or 0
end )

-- Pet management settings exposure
spec:RegisterStateExpr( "auto_resummon_pet", function()
    return state.settings and state.settings.auto_resummon_pet and 1 or 0
end )

spec:RegisterStateExpr( "need_pet", function()
    -- Returns 1 if auto-resummon is enabled and we need to summon or swap to preferred pet.
    if not ( state.settings and state.settings.auto_resummon_pet ) then return 0 end
    if not ( pet and pet.alive ) then return 1 end
    local pref = ( state.settings and state.settings.preferred_pet ) or "felhunter"
    local fam = UnitCreatureFamily and UnitCreatureFamily( "pet" ) or nil
    if not fam then return 1 end
    local desired = ({ imp = "Imp", voidwalker = "Voidwalker", succubus = "Succubus", felhunter = "Felhunter" })[ pref ] or "Felhunter"
    return fam ~= desired and 1 or 0
end )

-- Range
spec:RegisterRanges( "agony", "fear" )

-- Options
spec:RegisterOptions( {
    enabled = true,

    aoe = 3,

    gcd = 1645,

    nameplates = true,
    nameplateRange = 8,

    damage = true,
    damageExpiration = 8,

    potion = nil,

    package = "Affliction",
} )

-- Settings
-- APL currently doesn't support these options, will need tweaks
-- spec:RegisterSetting( "soc_spread", true, {
--     name = strformat( "Enable %s Spread", Hekili:GetSpellLinkWithTexture( 27243 ) ),
--     desc = strformat( "When enabled, the APL may use %s with %s to spread DoTs in AoE. Disable to avoid SoC spread on cleave.",
--         Hekili:GetSpellLinkWithTexture( 27243 ), Hekili:GetSpellLinkWithTexture( 74434 ) ),
--     type = "toggle",
--     width = "full",
-- } )

-- spec:RegisterSetting( "preferred_pet", "felhunter", {
--     name = "Preferred Demon (Precombat)",
--     desc = "Which demon to keep active outside combat.",
--     type = "select",
--     width = 1.5,
--     values = function()
--         return {
--             imp = "Imp",
--             voidwalker = "Voidwalker",
--             succubus = "Succubus",
--             felhunter = "Felhunter",
--         }
--     end,
-- } )

-- spec:RegisterSetting( "auto_resummon_pet", true, {
--     name = "Auto Resummon Preferred Pet (OOC)",
--     desc = "If enabled, precombat recommendations will summon or swap to your preferred demon.",
--     type = "toggle",
--     width = 1.5,
-- } )

-- Default pack for MoP Affliction Warlock
spec:RegisterPack( "Affliction", 20250928, [[Hekili:TR1wVTTVv8plbfqWgTZZ2nojDioaB7L28qFrfyVjjAzkBHOlgusPiag6Z(oKusKI6qzL2KUh2)hAJdVCUXFNRXER8(HN7Esj177RxUEZYVS(UfR285BU(wp3Yxor9CprcFICa(qgjf())zuusCyzCEgFRxsYj75KOiVIfcB7gN(VzKOY6GnxF3F7op3DvXjLFlZBhkBw(f4QNOHWY3SXZ9y8(9u5zPfHEU)4yCrDa)FK6GgbPoipc(DHiuhKexucBhLZQd(k9P4K4fEUIf5sfjNc)47cLK0i0fvPP5z(XzruwgjXZLMr2Lq379V8kbXGFu1kQBLxLSRIbFkKfxszXeUQffTODJf7Z)jipo1bxvhSpVSBd)ckDVFEKFyoJvDItUfLXHpfNDO94sMm6nIZ8b7(HJL(L5(Le2bAP42874xCKW2dwHhQdwcc4lHj0MZuWvEqT(SHAztjQoPRcKd5zVykS8ngQk9Tu(f)KCIZ3RhXCkp0LefC2zvkXv)n2eJbgAD5zwDG9NyBpiWwDY486GZNRdgqN(w5)aaL54MLBSywosQYk1TeJOV7PcDtCLfmAkjodqI3xheskGZgNcoSFeSjmYZ0KMFF642BTIBtjzKfNclf862LkHpjoItfb87olkyeikrjI4zxsjrLRsEaQisvszx4fuHSX4Ksoeh6)CvsgLr2bXOkFrGLucuyfRGYFjPj0uAgWhKyrgEk7sYZ3NuvukWtCGMugxCKsskp2yC2whSwZ6Ckx8Z2qcTlxbChiEAHr4WR1pe3YkyQXH2OFODuqtysxXENYeS1ZWxssaTEbHfEmgIodr)93typLrlkw0CNoFPjDwhXrdpYTiacJBfASrS4SNaJ0jwEi4SustsOHAMWMTlkjcppFBNd3uVAPWRFUYEWfnFbApngmmVmoQUr3oWanlMjqefey7O4qApL7eWCss8ZufNqVeMxGID8R(m1NMrtJPshXBueKvL5l)SppJQmVQVSmaEMvG0F5vPjvN4bicFPvtgKugUllNDOcclWP(QLtaZ864W(88uf9T75AgW2s(Tv29rBJ63bagGX(fHGH5qOw5BLaSjH6QmHmAeJcHwbrssqJuOO7xLbSdwXN0vFx)dohpSTy1HzjrkCIBTSxgYm7IbphyHVm1sJxgQEn65ufjm4iJPzwJO(60BZYGg1dCvFAlWAQsp(dbRSH3TwjfwbDtv5AQhAMbq(efAPiRekvpKrjfujb20vwicCxvXLb44s0YM)rFcIbpVeLNINLfiiEnrRgntQOqm)Uczee2EzzRwSXgR7xmiNV2tBPEnK4unt2V7tPHll47PenXTeIM9uCgpUdKV3omYysQwdgCX1EAtBiMbY97fu8sAccne1QApv9mrRlDfS01L0ul1zIP619vF7PDBqlCskFDMpOAdOpJJG3dLjmr2R2yG9zkc1aULVdkW85gMDHMhuPp6YSy0ur36960AJLoTwpi1(ra845UYZLNIrG(9JJAtuiI0S9ATYKzWXfcK2fexxVKYXsg3legiPxleRbzETiwZgq873UE55ZZWlE4(1ZB2ZsbiQdCPsAuNepu5dR24GgIercSDx8ixTeOxV733mJb5IDzl(iKPy(CNbwPh0BUmfqTG)G)bgP4KX7i)XWS4b5h9tZFM3UO927VB5qG4ajbbx62qzzEZ1I8MQLgYEKXdOKwofU1SDyjB0peihGFAyE6oc6Wb61xi3cLvkN2jlUzau)hcljp8P)rDGAwR1bdgSAVOhkFAjj5DSm6ee(RGYY4K27i5TpMS9UaMSP5102FVXY0m3hdOka9azRGVt3C59C)jHLbEefEUFl9uoRKZ7pBmY9f1pYb65rXjGS8H6auu7JFyaWT(X6hLuQyrNJYh3(31aVFkoA7viiA8lA(QYV9SR6muoxnfJl(PmFD5bmF7OMZfWUZhvFBbwcJLsBNcJXPlQGWP(K0yLRckXLWpT3EyTbZ8KZSlmXu97lPj)sdgh65ZOPZ1VD3ep1xSBcN6lQMOP(QMZ1t8omHrtQGqJDkNznJUC7AqxS1yVAl7JRe1uSA5856kZB9BpqsJHh(j(yd3sYfuLVUAUapCJ(9gojqBYHvyTIkDt7t)1z6ePDafDym9)coghKVSi0ZGPZ8B9akMkZd3m3zgAnGNpBV8o5ExONV5oA1n)WshK)Gx2u0jvC72vder09rkXE7ktHd1PEcIC3JObWBLdYu2CENEbXfQEd4z7QPiKvNCM9)0(fMYOhAP0LGFgpX6gjrhichxJzA502QsVUtStiHLqKCP3yQ(L76QF3B9sP1z3AzNXONEdEcSZDeBDRyyBKsVdVOJjH)FqTAVTvO1utcVnZUKq9hDJdYyBCA7u((n9Ceudz5tD9MdXCeZeHh7rBIiB7nNgzkySGVAh7(R15vVzbCz29xZF5xE(lOGf5qnKju6qd3TuHmgomnnY0naKo6GXe9w5Gk72A8nRQ3M6fpGKZByoCNR4MM2Lg57gJZvnwSXolYxSdl5l0ewR1(jLTEFVJKlH8n3XkDVOva4donry)a2mWeGXVzyMDmt1vnSHJyXngVJpuZnvozHbi6dQSJ9fusRYbTVysJJi0Jd35fD7GJPCDMOa65sQkpMZ8C)kideXuz8(Vd]] )
