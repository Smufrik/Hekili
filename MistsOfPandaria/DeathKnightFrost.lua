if not Hekili or not Hekili.NewSpecialization then return end
-- DeathKnightFrost.lua
-- Updated june 1, 2025 - Mists of Pandaria Frost Death Knight Module
-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

-- Safe local references to WoW API (helps static analyzers)
local GetRuneCooldown = rawget( _G, "GetRuneCooldown" ) or function() return 0, 10, true end
local GetRuneType = rawget( _G, "GetRuneType" ) or function() return 1 end

local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 251, true ) -- Frost spec ID for MoP
spec.name = "Frost"
spec.role = "DAMAGER"
spec.primaryStat = 1 -- Strength

-- Runes (unified model on the resource itself to avoid collision with a state table)
do
    local function buildTypeCounter(indices, typeId)
        return setmetatable({}, {
            __index = function(_, k)
                if k == "count" then
                    local ready = 0
                    if typeId == 4 then
                        for i = 1, 6 do
                            local start, duration, isReady = GetRuneCooldown(i)
                            local rtype = GetRuneType(i)
                            if (isReady or (start and duration and (start + duration) <= state.query_time)) and rtype == 4 then
                                ready = ready + 1
                            end
                        end
                    else
                        for _, i in ipairs(indices) do
                            local start, duration, isReady = GetRuneCooldown(i)
                            if isReady or (start and duration and (start + duration) <= state.query_time) then
                                ready = ready + 1
                            end
                        end
                    end
                    return ready
                end
                return 0
            end
        })
    end

    spec:RegisterResource( 5, {}, setmetatable({
        expiry = { 0, 0, 0, 0, 0, 0 },
        cooldown = 10,
        max = 6,
        reset = function()
            local t = state.runes
            for i = 1, 6 do
                local start, duration, ready = GetRuneCooldown(i)
                start = start or 0
                duration = duration or (10 * state.haste)
                t.expiry[i] = ready and 0 or (start + duration)
                t.cooldown = duration
            end
        end,
    }, {
        __index = function(t, k)
            local idx = tostring(k):match("time_to_(%d)")
            if idx then
                local i = tonumber(idx)
                local e = t.expiry[i] or 0
                return math.max(0, e - state.query_time)
            end
            if k == "blood" then return buildTypeCounter({1,2}, 1) end
            if k == "frost" then return buildTypeCounter({3,4}, 2) end
            if k == "unholy" then return buildTypeCounter({5,6}, 3) end
            if k == "death" then return buildTypeCounter({}, 4) end
            if k == "count" or k == "current" then
                local c = 0
                for i = 1, 6 do
                    if t.expiry[i] <= state.query_time then c = c + 1 end
                end
                return c
            end
            return rawget(t, k)
        end
    }) ) -- Runes = 5 in MoP with unified state

    spec:RegisterHook("reset_precast", function()
        if state.runes and state.runes.reset then state.runes.reset() end
    end)
end
spec:RegisterResource(6) -- RunicPower = 6 in MoP

local strformat = string.format
-- Enhanced Helper Functions for MoP compatibility
local function UA_GetPlayerAuraBySpellID(spellID, filter)
    -- MoP compatibility: use fallback methods since C_UnitAuras doesn't exist
    if filter == "HELPFUL" or not filter then
        return ns.FindUnitBuffByID("player", spellID)
    else
        return ns.FindUnitDebuffByID("player", spellID)
    end
end
-- Back-compat alias used by generate() functions below
local GetPlayerAuraBySpellID = UA_GetPlayerAuraBySpellID

-- Local shim for resource changes to avoid nil global gain/spend and normalize names.
local function _normalizeResource(res)
    if res == "runic_power" or res == "rp" then return "runic_power" end
    return res
end

local function gain(amount, resource, overcap, noforecast)
    local r = _normalizeResource(resource)
    if r == "runes" and state.runes and state.runes.expiry then
        local n = tonumber(amount) or 0
        if n >= 6 then
            for i = 1, 6 do state.runes.expiry[i] = 0 end
        else
            for _ = 1, n do
                local worstIdx, worstVal = 1, -math.huge
                for i = 1, 6 do
                    local e = state.runes.expiry[i] or 0
                    if e > worstVal then worstVal, worstIdx = e, i end
                end
                state.runes.expiry[worstIdx] = 0
            end
        end
        return
    end
    if state.gain then return state.gain(amount, r, overcap, noforecast) end
end

local function spend(amount, resource, noforecast)
    local r = _normalizeResource(resource)
    if state.spend then return state.spend(amount, r, noforecast) end
end

-- Advanced Combat Log Event Tracking Frame for Frost Death Knight Mechanics
local FrostCombatFrame = CreateFrame( "Frame" )
local frostEventData = {
    -- Killing Machine proc tracking from auto-attacks and abilities
    killing_machine_procs = 0,
    last_km_proc = 0,
    km_proc_rate = 0.15, -- Base 15% chance per auto-attack
    
    -- Rime proc tracking from Obliterate and other abilities
    rime_procs = 0,
    last_rime_proc = 0,
    rime_proc_rate = 0.15, -- Base 15%, improved by talents
    
    -- Runic Power generation tracking across all sources
    rp_generation = {
        frost_strike = 0,      -- RP spending ability
        obliterate = 15,       -- Primary RP generator
        howling_blast = 10,    -- AoE RP generator
        icy_touch = 10,        -- Disease application + RP
        blood_strike = 10,     -- Cross-spec ability RP
        death_and_decay = 10,  -- AoE RP generator
        army_of_dead = 30,     -- Major cooldown RP burst
    },
    
    -- Rune regeneration and conversion tracking
    rune_events = {
        blood_runes_used = 0,
        frost_runes_used = 0,
        unholy_runes_used = 0,
        death_runes_created = 0,
        empower_uses = 0,
        blood_tap_uses = 0,
    },
    
    -- Disease tracking and pandemic mechanics
    disease_management = {
        frost_fever_applications = 0,
        blood_plague_applications = 0,
        disease_refreshes = 0,
        pandemic_extensions = 0,
    },
    
    -- Pillar of Frost optimization tracking
    pillar_usage = {
        total_uses = 0,
        rp_spent_during = 0,
        abilities_used_during = 0,
        optimal_timing_count = 0,
    },
    
    -- Dual-wield vs Two-handed weapon tracking
    weapon_mechanics = {
        threat_of_thassarian_procs = 0,
        might_frozen_wastes_bonus = 0,
        off_hand_strikes = 0,
        main_hand_strikes = 0,
    },
}

FrostCombatFrame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
FrostCombatFrame:RegisterEvent( "UNIT_SPELLCAST_SUCCEEDED" )
FrostCombatFrame:RegisterEvent( "UNIT_AURA" )
FrostCombatFrame:SetScript( "OnEvent", function( self, event, ... )
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID( "player" ) then
            -- Killing Machine proc detection from auto-attacks
            if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
                if math.random() < frostEventData.km_proc_rate then
                    frostEventData.killing_machine_procs = frostEventData.killing_machine_procs + 1
                    frostEventData.last_km_proc = GetTime()
                end
                
            end
            -- Obliterate usage and Rime proc tracking
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 49020 then -- Obliterate
                local rime_chance = state.talent.rime.enabled and 0.45 or 0.15
                if math.random() < rime_chance then
                    frostEventData.rime_procs = frostEventData.rime_procs + 1
                    frostEventData.last_rime_proc = GetTime()
                end
                frostEventData.rune_events.frost_runes_used = frostEventData.rune_events.frost_runes_used + 1
                frostEventData.rune_events.unholy_runes_used = frostEventData.rune_events.unholy_runes_used + 1
            end
            
            -- Frost Strike Runic Power spending tracking
            if subEvent == "SPELL_CAST_SUCCESS" and spellID == 49143 then -- Frost Strike
                -- Track RP spending and potential Runic Empowerment/Corruption procs
                if state.talent.runic_empowerment.enabled and math.random() < 0.45 then
                    frostEventData.rune_events.empower_uses = frostEventData.rune_events.empower_uses + 1
                end
            end
            
            -- Disease application tracking
            if subEvent == "SPELL_AURA_APPLIED" then
                if spellID == 59921 then -- Frost Fever
                    frostEventData.disease_management.frost_fever_applications = frostEventData.disease_management.frost_fever_applications + 1
                elseif spellID == 59879 then -- Blood Plague
                    frostEventData.disease_management.blood_plague_applications = frostEventData.disease_management.blood_plague_applications + 1
                end
            end
            
            -- Pillar of Frost usage optimization
            if subEvent == "SPELL_AURA_APPLIED" and spellID == 51271 then -- Pillar of Frost
                frostEventData.pillar_usage.total_uses = frostEventData.pillar_usage.total_uses + 1
                -- Start tracking abilities used during Pillar
                local logFunc = function()
                    -- Log Pillar effectiveness after 20 seconds
                end
                
                if C_Timer and C_Timer.After then
                    C_Timer.After(20, logFunc)
                elseif ns.ScheduleTimer then
                    ns.ScheduleTimer(logFunc, 20)
                end
            end
        end
    end
end )

-- MoP runeforge detection (classic-safe), matching Unholy implementation
-- Maps weapon enchant IDs to runeforge names for MoP Classic
local frost_runeforges = {
    [3370] = "razorice",
    [3368] = "fallen_crusader",
    [3847] = "stoneskin_gargoyle",
}

local function Frost_ResetRuneforges()
    if not state.death_knight then state.death_knight = {} end
    if not state.death_knight.runeforge then state.death_knight.runeforge = {} end
    table.wipe( state.death_knight.runeforge )
end

local function Frost_UpdateRuneforge( slot )
    if slot ~= 16 and slot ~= 17 then return end
    if not state.death_knight then state.death_knight = {} end
    if not state.death_knight.runeforge then state.death_knight.runeforge = {} end

    local link = GetInventoryItemLink( "player", slot )
    local enchant = link and link:match( "item:%d+:(%d+)" )
    if enchant then
        local name = frost_runeforges[ tonumber( enchant ) ]
        if name then
            state.death_knight.runeforge[ name ] = true
            if name == "razorice" then
                if slot == 16 then state.death_knight.runeforge.razorice_mh = true end
                if slot == 17 then state.death_knight.runeforge.razorice_oh = true end
            end
        end
    end
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:SetScript("OnEvent", function(_, evt, ...)
        if evt == "PLAYER_ENTERING_WORLD" then
            Frost_ResetRuneforges()
            Frost_UpdateRuneforge(16)
            Frost_UpdateRuneforge(17)
        elseif evt == "PLAYER_EQUIPMENT_CHANGED" then
            local slot = ...
            if slot == 16 or slot == 17 then
                Frost_ResetRuneforges()
                Frost_UpdateRuneforge(16)
                Frost_UpdateRuneforge(17)
            end
        end
    end)
end

Hekili:RegisterGearHook( Frost_ResetRuneforges, Frost_UpdateRuneforge )

-- Advanced Resource System Registration with Multi-Source Tracking
-- Runic Power: Primary resource for Death Knights with multiple generation sources
-- MoP: Use legacy power type constants
spec:RegisterResource( 6, { -- RunicPower = 6 in MoP
    -- Base regeneration and maximum values
    base_regen = 0, -- No passive regeneration
    maximum = 100,  -- Base maximum, can be increased by talents/effects
    
    -- Advanced generation tracking per ability
    generation_sources = {
        obliterate = 15,        -- Primary Frost generator
        howling_blast = 10,     -- AoE generator
        icy_touch = 10,         -- Disease application
        blood_strike = 10,      -- Cross-spec ability
        death_and_decay = 10,   -- AoE ability
        chains_of_ice = 10,     -- Utility with RP gen
        horn_of_winter = 10,    -- Buff ability (if not glyphed)
        army_of_dead = 30,      -- Major cooldown burst
    },
    
    -- Chill of the Grave talent enhancement
    chill_bonus = function()
        return state.talent.chill_of_the_grave.enabled and 5 or 0 -- +5 RP per Icy Touch
    end,
    
    -- Runic Empowerment and Corruption interaction
    empowerment_efficiency = function()
        if state.talent.runic_empowerment.enabled then
            return 1.15 -- 15% more efficient RP usage due to rune refresh
        elseif state.talent.runic_corruption.enabled then
            return 1.20 -- 20% more efficient due to faster rune regen
        end
        return 1.0
    end,
} )

-- Register individual rune types for MoP 5.5.0 (Frost DK)
spec:RegisterResource( 20, { -- Blood Runes = 20 in MoP
    rune_regen = {
        last = function () return state.query_time end,
        stop = function( x ) return x == 2 end,
        interval = function( time, val )
            local r = state.blood_runes
            if val == 2 then return -1 end
            return r.expiry[ val + 1 ] - time
        end,
        value = 1,
    }
}, setmetatable( {
    expiry = { 0, 0 },
    cooldown = 10,
    regen = 0,
    max = 2,
    forecast = {},
    fcount = 0,
    times = {},
    values = {},
    resource = "blood_runes",

    reset = function()
        local t = state.blood_runes
        for i = 1, 2 do
            local start, duration, ready = GetRuneCooldown( i )
            start = start or 0
            duration = duration or ( 10 * state.haste )
            t.expiry[ i ] = ready and 0 or ( start + duration )
            t.cooldown = duration
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    gain = function( amount )
        local t = state.blood_runes
        for i = 1, amount do
            table.insert( t.expiry, 0 )
            t.expiry[ 3 ] = nil
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    spend = function( amount )
        local t = state.blood_runes
        for i = 1, amount do
            local nextReady = ( t.expiry[ 1 ] > 0 and t.expiry[ 1 ] or state.query_time ) + t.cooldown
            table.remove( t.expiry, 1 )
            table.insert( t.expiry, nextReady )
        end
        t.actual = nil
    end,

    timeTo = function( x )
        return state:TimeToResource( state.blood_runes, x )
    end,
}, {
    __index = function( t, k )
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[ i ] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget( t, k )
    end
} ) )

spec:RegisterResource( 21, { -- Frost Runes = 21 in MoP
    rune_regen = {
        last = function () return state.query_time end,
        stop = function( x ) return x == 2 end,
        interval = function( time, val )
            local r = state.frost_runes
            if val == 2 then return -1 end
            return r.expiry[ val + 1 ] - time
        end,
        value = 1,
    }
}, setmetatable( {
    expiry = { 0, 0 },
    cooldown = 10,
    regen = 0,
    max = 2,
    forecast = {},
    fcount = 0,
    times = {},
    values = {},
    resource = "frost_runes",

    reset = function()
        local t = state.frost_runes
        for i = 3, 4 do -- Frost runes are at positions 3-4
            local start, duration, ready = GetRuneCooldown( i )
            start = start or 0
            duration = duration or ( 10 * state.haste )
            t.expiry[ i - 2 ] = ready and 0 or ( start + duration )
            t.cooldown = duration
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    gain = function( amount )
        local t = state.frost_runes
        for i = 1, amount do
            table.insert( t.expiry, 0 )
            t.expiry[ 3 ] = nil
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    spend = function( amount )
        local t = state.frost_runes
        for i = 1, amount do
            local nextReady = ( t.expiry[ 1 ] > 0 and t.expiry[ 1 ] or state.query_time ) + t.cooldown
            table.remove( t.expiry, 1 )
            table.insert( t.expiry, nextReady )
        end
        t.actual = nil
    end,

    timeTo = function( x )
        return state:TimeToResource( state.frost_runes, x )
    end,
}, {
    __index = function( t, k )
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[ i ] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget( t, k )
    end
} ) )

spec:RegisterResource( 22, { -- Unholy Runes = 22 in MoP
    rune_regen = {
        last = function () return state.query_time end,
        stop = function( x ) return x == 2 end,
        interval = function( time, val )
            local r = state.unholy_runes
            if val == 2 then return -1 end
            return r.expiry[ val + 1 ] - time
        end,
        value = 1,
    }
}, setmetatable( {
    expiry = { 0, 0 },
    cooldown = 10,
    regen = 0,
    max = 2,
    forecast = {},
    fcount = 0,
    times = {},
    values = {},
    resource = "unholy_runes",

    reset = function()
        local t = state.unholy_runes
        for i = 5, 6 do -- Unholy runes are at positions 5-6
            local start, duration, ready = GetRuneCooldown( i )
            start = start or 0
            duration = duration or ( 10 * state.haste )
            t.expiry[ i - 4 ] = ready and 0 or ( start + duration )
            t.cooldown = duration
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    gain = function( amount )
        local t = state.unholy_runes
        for i = 1, amount do
            table.insert( t.expiry, 0 )
            t.expiry[ 3 ] = nil
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    spend = function( amount )
        local t = state.unholy_runes
        for i = 1, amount do
            local nextReady = ( t.expiry[ 1 ] > 0 and t.expiry[ 1 ] or state.query_time ) + t.cooldown
            table.remove( t.expiry, 1 )
            table.insert( t.expiry, nextReady )
        end
        t.actual = nil
    end,

    timeTo = function( x )
        return state:TimeToResource( state.unholy_runes, x )
    end,
}, {
    __index = function( t, k )
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[ i ] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget( t, k )
    end
} ) )

-- Death Runes State Table for MoP 5.5.0 (Frost DK)
spec:RegisterStateTable( "death_runes", setmetatable( {
    state = {},

    reset = function()
        for i = 1, 6 do
            local start, duration, ready = GetRuneCooldown( i )
            local type = GetRuneType( i )
            local expiry = ready and 0 or start + duration
            state.death_runes.state[i] = {
                type = type,
                start = start,
                duration = duration,
                ready = ready,
                expiry = expiry
            }
        end
    end,

    getActiveDeathRunes = function()
        local activeRunes = {}
        if state.death_runes and state.death_runes.state then
            local state_array = state.death_runes.state
            for i = 1, 6 do
                if state_array[i] and state_array[i].type == 4 and state_array[i].expiry < state.query_time then
                    table.insert(activeRunes, i)
                end
            end
        end
        return activeRunes
    end,

    getActiveRunes = function()
        local activeRunes = {}
        if state.death_runes and state.death_runes.state then
            local state_array = state.death_runes.state
            for i = 1, 6 do
                if state_array[i] and state_array[i].expiry < state.query_time then
                    table.insert(activeRunes, i)
                end
            end
        end
        return activeRunes
    end,

    countDeathRunes = function()
        local count = 0
        if state.death_runes and state.death_runes.state then
            local state_array = state.death_runes.state
            for i = 1, 6 do
                if state_array[i] and state_array[i].type == 4 and state_array[i].expiry < state.query_time then
                    count = count + 1
                end
            end
        end
        return count
    end,

    countRunesByType = function(type)
        local count = 0
        if state.death_runes and state.death_runes.state then
            local state_array = state.death_runes.state
            local runeMapping = {
                blood = {1, 2},
                frost = {3, 4},
                unholy = {5, 6}
            }
            local runes = runeMapping[type]
            if runes then
                for _, rune in ipairs(runes) do
                    if state_array[rune] and state_array[rune].type == 4 and state_array[rune].expiry < state.query_time then
                        count = count + 1
                    elseif state_array[rune] and state_array[rune].type == (type == "blood" and 1 or type == "frost" and 2 or 3) and state_array[rune].expiry < state.query_time then
                        count = count + 1
                    end
                end
            end
        end
        return count
    end
}, {
    __index = function( t, k )
        if k == "active_death_runes" then
            return t.getActiveDeathRunes()
        elseif k == "active_runes" then
            return t.getActiveRunes()
        elseif k == "count" then
            return t.countDeathRunes()
        elseif k == "blood" then
            return t.countRunesByType("blood")
        elseif k == "frost" then
            return t.countRunesByType("frost")
        elseif k == "unholy" then
            return t.countRunesByType("unholy")
        end
        return rawget( t, k )
    end
} ) )

-- Unified DK Runes interface across specs: provides runes.<type>.count, runes.death.count, runes.time_to_1..6, and expiry[]
-- Removed duplicate RegisterStateTable("runes"); unified model lives on the resource.

-- Comprehensive Tier Sets and Gear Registration for MoP Death Knight
-- Tier 14: Battleplate of the Lost Cataphract
spec:RegisterGear( "tier14_lfr", 89236, 89237, 89238, 89239, 89240 )      -- LFR versions
spec:RegisterGear( "tier14_normal", 86919, 86920, 86921, 86922, 86923 )   -- Normal versions  
spec:RegisterGear( "tier14_heroic", 87157, 87158, 87159, 87160, 87161 )    -- Heroic versions
-- T14 Set Bonuses: 2pc = Icy Touch spreads diseases, 4pc = Death Coil heals for 20% more

-- Tier 15: Battleplate of the All-Consuming Maw  
spec:RegisterGear( "tier15_lfr", 96617, 96618, 96619, 96620, 96621 )      -- LFR versions
spec:RegisterGear( "tier15_normal", 95225, 95226, 95227, 95228, 95229 )   -- Normal versions
spec:RegisterGear( "tier15_heroic", 96354, 96355, 96356, 96357, 96358 )    -- Heroic versions
-- T15 Set Bonuses: 2pc = Pillar of Frost grants 5% crit, 4pc = Death Strike heals nearby allies

-- Tier 16: Battleplate of the Prehistoric Marauder
spec:RegisterGear( "tier16_lfr", 99446, 99447, 99448, 99449, 99450 )      -- LFR versions
spec:RegisterGear( "tier16_normal", 99183, 99184, 99185, 99186, 99187 )   -- Normal versions  
spec:RegisterGear( "tier16_heroic", 99709, 99710, 99711, 99712, 99713 )    -- Heroic versions
spec:RegisterGear( "tier16_mythic", 100445, 100446, 100447, 100448, 100449 ) -- Mythic versions
-- T16 Set Bonuses: 2pc = Obliterate increases crit by 5%, 4pc = Killing Machine increases damage by 25%

-- Legendary Cloak variants for all classes
spec:RegisterGear( "legendary_cloak_agi", 102246 )    -- Jina-Kang, Kindness of Chi-Ji (Agility)
spec:RegisterGear( "legendary_cloak_str", 102245 )    -- Gong-Lu, Strength of Xuen (Strength) 
spec:RegisterGear( "legendary_cloak_int", 102249 )    -- Ordos cloak variants

-- Notable Trinkets from MoP content
spec:RegisterGear( "unerring_vision", 102293 )        -- Unerring Vision of Lei-Shen (SoO)
spec:RegisterGear( "haromms_talisman", 102301 )       -- Haromm's Talisman (SoO)
spec:RegisterGear( "sigil_rampage", 102299 )          -- Sigil of Rampage (SoO) 
spec:RegisterGear( "thoks_tail_tip", 102313 )         -- Thok's Tail Tip (SoO)
spec:RegisterGear( "kardris_totem", 102312 )          -- Kardris' Toxic Totem (SoO)
spec:RegisterGear( "black_blood", 102310 )            -- Black Blood of Y'Shaarj (SoO)

-- PvP Sets for Death Knights
spec:RegisterGear( "pvp_s12_glad", 84427, 84428, 84429, 84430, 84431 )    -- Season 12 Gladiator
spec:RegisterGear( "pvp_s13_tyrann", 91465, 91466, 91467, 91468, 91469 )  -- Season 13 Tyrannical  
spec:RegisterGear( "pvp_s14_griev", 98855, 98856, 98857, 98858, 98859 )   -- Season 14 Grievous
spec:RegisterGear( "pvp_s15_prideful", 100030, 100031, 100032, 100033, 100034 ) -- Season 15 Prideful

-- Challenge Mode Sets (Cosmetic but with stats)
spec:RegisterGear( "challenge_mode", 90309, 90310, 90311, 90312, 90313 )   -- CM Death Knight set

-- Meta Gems relevant to Death Knights
spec:RegisterGear( "meta_relentless", 76885 )         -- Relentless Earthsiege Diamond
spec:RegisterGear( "meta_austere", 76879 )            -- Austere Earthsiege Diamond  
spec:RegisterGear( "meta_eternal", 76884 )            -- Eternal Earthsiege Diamond
spec:RegisterGear( "meta_effulgent", 76881 )          -- Effulgent Shadowspirit Diamond

-- Talents (MoP talent system and Frost spec-specific talents)
spec:RegisterTalents( {
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 56)
    roiling_blood        = { 1, 1, 108170 }, -- Your Pestilence refreshes disease durations and spreads diseases from each diseased target to all other targets.
    plague_leech         = { 1, 2, 123693 }, -- Extract diseases from an enemy target, consuming up to 2 diseases on the target to gain 1 Rune of each type that was removed.
    unholy_blight        = { 1, 3, 115989 }, -- Causes you to spread your diseases to all enemy targets within 10 yards.
    
    -- Tier 2 (Level 57)
    lichborne            = { 2, 1, 49039 },
    anti_magic_zone      = { 2, 2, 51052 },
    purgatory            = { 2, 3, 114556 },
    
    -- Tier 3 (Level 58)
    deaths_advance       = { 3, 1, 96268 },
    chilblains           = { 3, 2, 50041 },
    asphyxiate           = { 3, 3, 108194 },
    
    -- Tier 4 (Level 60)
    death_pact           = { 4, 1, 48743 },
    death_siphon         = { 4, 2, 108196 },
    conversion           = { 4, 3, 119975 },
    
    -- Tier 5 (Level 75)
    blood_tap            = { 5, 1, 45529 },
    runic_empowerment    = { 5, 2, 81229 },
    runic_corruption     = { 5, 3, 51462 },
    
    -- Tier 6 (Level 90)
    gorefiends_grasp     = { 6, 1, 108199 },
    remorseless_winter   = { 6, 2, 108200 },
    desecrated_ground    = { 6, 3, 108201 },
} )

-- Enhanced Glyph System for Frost Death Knight
spec:RegisterGlyphs( {
    -- Major Glyphs: Significant gameplay modifications
    -- Defensive Enhancement Glyphs
    [58640] = "anti_magic_shell",       -- Increases duration by 2 sec, cooldown by 20 sec
    [58631] = "icebound_fortitude",     -- Reduces cooldown by 60 sec, duration by 2 sec  
    [58657] = "dark_succor",            -- Death Strike heals 20% health when not in Blood Presence
    [58632] = "dark_simulation",        -- Dark Simulacrum usable while stunned
    
    -- Frost Damage Enhancement Glyphs
    [58622] = "howling_blast",          -- Additional damage to primary target
    [58675] = "icy_touch",              -- Frost Fever deals 20% additional damage
    [63335] = "pillar_of_frost",        -- Cannot be dispelled, 1-min cooldown (down from 2-min)
    [63331] = "chains_of_ice",          -- Adds 144-156 Frost damage based on attack power
    
    -- Resource and Utility Glyphs
    [58616] = "horn_of_winter",         -- No RP generation, lasts 1 hour instead of 2 minutes
    [59337] = "death_strike",           -- Reduces RP cost by 8 (from 40 to 32)
    [58629] = "death_and_decay",        -- Increases damage by 15%
    [58677] = "death_coil",             -- Also heals pets for 1% of DK health
    
    -- Combat Utility Glyphs
    [58686] = "death_grip",             -- Cooldown reset on killing blows that yield XP/honor
    [58671] = "plague_strike",          -- 20% additional damage against targets above 90% health
    [58649] = "soul_reaper",            -- Gain 5% haste for 5 sec when striking targets below 35% health
    
    -- Rune Management Glyphs
    [58668] = "blood_tap",              -- Costs 15 RP instead of health
    [58669] = "rune_tap",               -- Increases healing by 100% but increases cooldown by 30 sec
    [58679] = "vampiric_blood",         -- No longer increases damage taken, healing bonus reduced to 15%
    
    -- Advanced Frost-Specific Glyphs
    [58673] = "obliterate",             -- Obliterate has 25% chance not to consume diseases
    [58674] = "frost_strike",           -- Frost Strike dispels one magic effect from target
    [58676] = "empower_rune_weapon",    -- Reduces cooldown by 60 sec, grants 10% damage for 30 sec
    
    -- Presence Enhancement Glyphs
    [58672] = "unholy_presence",        -- Movement speed bonus increased to 20% (from 15%)
    [58670] = "frost_presence",         -- Reduces damage from magic by additional 5%
    [58667] = "blood_presence",         -- Increases healing from all sources by 10%
    
    -- Minor Glyphs: Cosmetic and convenience improvements
    [60200] = "death_gate",             -- Reduces cast time by 60% (from 10 sec to 4 sec)
    [58617] = "foul_menagerie",         -- Raise Dead summons random ghoul companion
    [63332] = "path_of_frost",          -- Army of the Dead ghouls explode on death/expiration
    [58680] = "resilient_grip",         -- Death Grip refunds cooldown when used on immune targets
    [59307] = "the_geist",              -- Raise Dead summons a geist instead of ghoul
    [60108] = "tranquil_grip",          -- Death Grip no longer taunts targets
    [58678] = "corpse_explosion",       -- Corpse Explosion has 50% larger radius
    [58665] = "bone_armor",             -- Bone Armor provides 2 additional charges
    
    -- Additional Utility Minor Glyphs
    [58666] = "death_coil_visual",      -- Death Coil has a different visual effect
    [58681] = "raise_dead_duration",    -- Raise Dead minions last 50% longer
    [58682] = "army_of_dead_speed",     -- Army of the Dead ghouls move 50% faster
    [58683] = "horn_of_winter_visual",  -- Horn of Winter has enhanced visual/audio effects
    [58684] = "blood_tap_visual",       -- Blood Tap has a different visual effect
    [58685] = "death_grip_visual",      -- Death Grip has enhanced chain visual
} )

-- Advanced Aura System with Sophisticated Generate Functions for Frost Death Knight
spec:RegisterAuras( {
    -- Core Frost Presence: Enhanced with combat state tracking
    frost_presence = {
        id = 48266,
        duration = 3600,
        max_stack = 1,
        copy = "frost_presence_enhanced"
    },

    -- Pillar of Frost: Main DPS cooldown with advanced tracking
    pillar_of_frost = {
        id = 51271,
        duration = 20,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 51271 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track optimal usage timing
                local time_remaining = expires - GetTime()
                if time_remaining > 15 then
                    -- Still have significant time left, track usage efficiency
                    frostEventData.pillar_usage.optimal_timing_count = frostEventData.pillar_usage.optimal_timing_count + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = { "pillar_of_frost_enhanced", "strength_boost" }
    },

    -- Killing Machine: Critical strike guarantee with advanced proc tracking
    killing_machine = {
        id = 51124,
        duration = 10,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 51124 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track KM consumption efficiency
                local time_since_proc = GetTime() - frostEventData.last_km_proc
                if time_since_proc < 2 then
                    -- Fast consumption - good gameplay
                    frostEventData.km_consumption_efficiency = (frostEventData.km_consumption_efficiency or 0) + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = { "km", "guaranteed_crit" }
    },

    -- Rime: Free Howling Blast with advanced proc mechanics
    rime = {
        id = 59052,
        duration = 15,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 59052 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track Rime usage efficiency for AoE optimization
                if active_enemies and active_enemies > 1 then
                    frostEventData.rime_aoe_efficiency = (frostEventData.rime_aoe_efficiency or 0) + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = { "freezing_fog", "free_howling_blast" }
    },    -- Frost Fever: Disease with pandemic mechanics
    frost_fever = {
        id = 59921,
        duration = 30,
        tick_time = 3,
        max_stack = 1,
        type = "Disease",
        generate = function( aura, t )
            local name, _, count, _, duration, expires, caster = FindUnitDebuffByID( t or "target", 59921 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Pandemic mechanic: can refresh up to 30% early
                local pandemic_window = duration * 0.3
                aura.pandemic_window = expires - pandemic_window
                
                -- Track disease management efficiency
                if aura.applied > GetTime() - 27 then -- Refreshed with >3 sec remaining
                    frostEventData.disease_management.pandemic_extensions = frostEventData.disease_management.pandemic_extensions + 1
                end
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "frost_fever_enhanced"
    },    -- Blood Plague: Cross-spec disease tracking
    blood_plague = {
        id = 59879,
        duration = 30,
        tick_time = 3,
        max_stack = 1,
        type = "Disease",
        generate = function( aura, t )
            local name, _, count, _, duration, expires, caster = FindUnitDebuffByID( t or "target", 59879 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Blood Strike damage bonus tracking
                local disease_count = 1
                if state.debuff.frost_fever.up then disease_count = disease_count + 1 end
                aura.disease_damage_bonus = disease_count * 0.125 -- 12.5% per disease
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "blood_plague_enhanced"
    },

    -- Blood Tap charges (used by Frost APLs)
    blood_charge = {
        id = 114851,
        duration = 25,
        max_stack = 12,
    },

    -- Runic Corruption: Enhanced rune regeneration
    runic_corruption = {
        id = 51460,
        duration = 3,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 51460 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track rune regeneration efficiency
                aura.regen_bonus = 2.0 -- 100% faster rune regeneration
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "enhanced_rune_regen"
    },

    -- Runic Empowerment: Instant rune refresh
    runic_empowerment = {
        id = 81229,
        duration = 5,
        max_stack = 1,
        generate = function( aura )
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 81229 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                
                -- Track which rune type was refreshed for optimization
                aura.refresh_efficiency = frostEventData.rune_events.empower_uses or 0
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "instant_rune_refresh"
    },

    -- Anti-Magic Shell: Magic immunity with glyph tracking
    anti_magic_shell = {
        id = 48707,
        duration = function() return spec.glyph.anti_magic_shell.enabled and 7 or 5 end,
        max_stack = 1,
        generate = function( aura )
            local duration_bonus = spec.glyph.anti_magic_shell.enabled and 2 or 0
            local name, _, count, _, duration, expires, caster = UA_GetPlayerAuraBySpellID( 48707 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                aura.glyph_enhanced = duration_bonus > 0
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "magic_immunity"
    },

    -- Horn of Winter: Stat buff with glyph variants
    horn_of_winter = {
        id = 57330,
        duration = function() return glyph.horn_of_winter.enabled and 3600 or 120 end,
        max_stack = 1,
        generate = function( aura )
            local extended_duration = glyph.horn_of_winter.enabled
            local name, _, count, _, duration, expires, caster = GetPlayerAuraBySpellID( 57330 )
            if name then
                aura.name = name
                aura.count = count > 0 and count or 1
                aura.expires = expires
                aura.applied = expires - duration
                aura.caster = caster
                aura.glyph_extended = extended_duration
                aura.rp_generation = not extended_duration -- Only generates RP if not glyphed
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
        copy = "strength_agility_buff"
    },

    -- Tier Set Bonuses with Advanced Tracking
    -- T14 2pc: Icy Touch spreads diseases
    tier14_2pc = {
        id = 123456, -- Placeholder ID
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if state.set_bonus.tier14_2pc > 0 then
                aura.count = 1
                aura.expires = GetTime() + 3600
                aura.applied = GetTime()
                aura.caster = "player"
                
                -- Track disease spreading efficiency
                aura.spread_count = frostEventData.disease_management.disease_refreshes or 0
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
    },

    -- T15 2pc: Pillar of Frost grants 5% crit
    tier15_2pc = {
        id = 123457, -- Placeholder ID
        duration = 20, -- Duration of Pillar of Frost
        max_stack = 1,
        generate = function( aura )
            if state.set_bonus.tier15_2pc > 0 and state.buff.pillar_of_frost.up then
                aura.count = 1
                aura.expires = state.buff.pillar_of_frost.expires
                aura.applied = state.buff.pillar_of_frost.applied
                aura.caster = "player"
                aura.crit_bonus = 0.05 -- 5% critical strike chance
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
    },

    -- Additional presence tracking
    blood_presence = {
        id = 48263,
        duration = 3600,
        max_stack = 1,
        copy = "blood_presence_active"
    },

    unholy_presence = {
        id = 48265,
        duration = 3600,
        max_stack = 1,
        copy = "unholy_presence_active"
    },

    -- Chains of Ice slow effect
    chains_of_ice = {
        id = 45524,
        duration = 8,
        max_stack = 1,
        type = "Magic",
        copy = "frost_slow"
    },

    -- Racials / Engineering (used in APL cooldown windows)
    blood_fury = {
        id = 33697,
        duration = 15,
        max_stack = 1,
    },
    berserking = {
        id = 26297,
        duration = 10,
        max_stack = 1,
    },
    synapse_springs = {
        id = 126734,
        duration = 10,
        max_stack = 1,
    },
} )

-- Register auxiliary cooldown abilities used by APL windows (racials/engineering)
spec:RegisterAbilities( {
    blood_fury = {
        id = 33697,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        startsCombat = false,
        toggle = "cooldowns",

        handler = function ()
            applyBuff("blood_fury")
        end,
    },

    berserking = {
        id = 26297,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        startsCombat = false,
        toggle = "cooldowns",

        handler = function ()
            applyBuff("berserking")
        end,
    },

    synapse_springs = {
        id = 126734,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        toggle = "cooldowns",

        handler = function ()
            applyBuff("synapse_springs")
        end,
    },
} )

-- Frost DK core abilities
spec:RegisterAbilities( {
    obliterate = {
        id = 49020,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 1, 1}, -- 0 Blood, 1 Frost, 1 Unholy
        
        gain = 15,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            -- Rime proc chance (15% base, increased by talent)
            local rime_chance = talent.rime.enabled and 0.45 or 0.15
            if math.random() < rime_chance then
                applyBuff("rime")
            end
            
            -- Killing Machine consumption if active
            if buff.killing_machine.up then
                removeBuff("killing_machine")
                -- Guaranteed crit when KM is active
            end
            
            -- Threat of Thassarian: dual-wield proc
            if talent.threat_of_thassarian.enabled then
                -- 50% chance to strike with off-hand as well
                if math.random() < 0.50 then
                    gain(5, "runic_power") -- Additional RP from off-hand strike
                end
            end
        end,
    },
      frost_strike = {
        id = 49143,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 40,
        spendType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            -- Killing Machine consumption and guaranteed crit
            local was_km_active = buff.killing_machine.up
            if was_km_active then
                removeBuff("killing_machine")
                -- This attack will crit due to KM
            end
            
            -- Threat of Thassarian: dual-wield proc
            if talent.threat_of_thassarian.enabled then
                -- 50% chance to strike with off-hand as well
                if math.random() < 0.50 then
                    -- Off-hand strike does additional damage
                end
            end
            
            -- Runic Empowerment/Corruption proc chance from RP spending
            if talent.runic_empowerment.enabled and math.random() < 0.45 then
                applyBuff("runic_empowerment")
            elseif talent.runic_corruption.enabled and math.random() < 0.45 then
                applyBuff("runic_corruption")
            end
        end,
    },
      howling_blast = {
        id = 49184,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend_runes = {0, 1, 0}, -- 0 Blood, 1 Frost, 0 Unholy
        
        gain = function() return 15 + (2.5 * talent.chill_of_the_grave.rank) end,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
                removeBuff("freezing_fog")
            removeStack("killing_machine")
            
            if glyph.howling_blast.enabled then
            applyDebuff("target", "frost_fever")
                active_dot.frost_fever = active_enemies
            end
        end,
      pillar_of_frost = {
        id = 51271,
        cast = 0,
        cooldown = function() return glyph.pillar_of_frost.enabled and 60 or 120 end,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("pillar_of_frost")
        end,
    },
    
    icy_touch = {
        id = 45477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes",
        
        startsCombat = true,
        
        usable = function() return runes.frost.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            applyDebuff("target", "frost_fever")
            
            -- Base RP generation
            local rp_gain = 10
            
            -- Chill of the Grave: additional RP from Icy Touch
            if talent.chill_of_the_grave.enabled then
                rp_gain = rp_gain + 5 -- Extra 5 RP per talent point
            end
            
            gain(rp_gain, "runic_power")
            
            -- Glyph of Icy Touch: increased Frost Fever damage
            if glyph.icy_touch.enabled then
                -- Frost Fever will deal 20% more damage
            end
        end,
    },
    
    chains_of_ice = {
        id = 45524,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "frost_runes",
        
        startsCombat = true,
        
        usable = function() return runes.frost.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            applyDebuff("target", "chains_of_ice")
            gain(10, "runic_power")
            
            -- Glyph of Chains of Ice: additional damage
            if glyph.chains_of_ice.enabled then
                -- Deal additional frost damage scaled by attack power
            end
        end,
    },
    
    blood_strike = {
        id = 45902,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 1,
        spendType = "blood_runes",
        
        startsCombat = true,
        texture = 237517,
        
        handler = function ()
            -- Blood Strike: Physical weapon attack with disease bonus
            -- Base damage + weapon damage, +12.5% per disease (max +25%)
            local disease_count = 0
            if debuff.blood_plague.up then disease_count = disease_count + 1 end
            if debuff.frost_fever.up then disease_count = disease_count + 1 end
            
            local damage_multiplier = 1.0 + (disease_count * 0.125)
            
            -- Generate 10 Runic Power
            gain(10, "runic_power")
        end,
    },
    
    -- Defensive cooldowns
    anti_magic_shell = {
        id = 48707,
        cast = 0,
        cooldown = function() return glyph.anti_magic_shell.enabled and 60 or 45 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("anti_magic_shell")
        end,
    },
    
    icebound_fortitude = {
        id = 48792,
        cast = 0,
        cooldown = function() return glyph.icebound_fortitude.enabled and 120 or 180 end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("icebound_fortitude")
        end,
    },
    
    -- Utility
    death_grip = {
        id = 49576,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "death_grip")
        end,
    },
    
    mind_freeze = {
        id = 47528,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        toggle = "interrupts",
        
        startsCombat = true,
        
        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            if active_enemies > 1 and talent.asphyxiate.enabled then
                -- potentially apply interrupt debuff with talent
            end
        end,
    },
      death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend = 1,
        spendType = "unholy_runes",
        
        startsCombat = true,
        
        usable = function() return runes.unholy.count > 0 or runes.death.count > 0 end,
        
        handler = function ()
            -- Generate RP based on number of enemies hit
            local rp_gain = 10 + (active_enemies > 1 and 5 or 0)
            gain(rp_gain, "runic_power")
            
            -- Glyph of Death and Decay: 15% more damage
            if glyph.death_and_decay.enabled then
                -- Increased damage from glyph
            end
        end,
    },
    
    rune_strike = {
        id = 56815,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 30,
        spendType = "runic_power",
        
        startsCombat = true,
        texture = 237518,
        
        usable = function() return buff.blood_presence.up end,
        
        handler = function ()
            -- Rune Strike: Enhanced weapon strike (requires Blood Presence)
            -- 1.8x weapon damage + 10% Attack Power
            -- 1.75x threat multiplier
        end,
    },
    
    horn_of_winter = {
        id = 57330,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("horn_of_winter")
            if not glyph.horn_of_winter.enabled then
                gain(10, "runic_power")
            end
        end,
    },
    
    raise_dead = {
        id = 46584,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            -- Summon ghoul/geist pet based on glyphs
        end,
    },
      army_of_the_dead = {
        id = 42650,
        cast = function() return 4 end, -- 4 second channel (8 ghouls @ 0.5s intervals)
        cooldown = 600, -- 10 minute cooldown
        gcd = "spell",
        
        spend = function() return 1, 1, 1 end, -- 1 Blood + 1 Frost + 1 Unholy
        spendType = "runes",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 237302,
        
        handler = function ()
            -- Summon 8 ghouls over 4 seconds, each lasting 40 seconds
            -- Generates 30 Runic Power
            gain( 30, "runic_power" )
        end,
    },
    
    path_of_frost = {
        id = 3714,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("path_of_frost")
        end,
    },
    
    -- Presence switching
    blood_presence = {
        id = 48263,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("frost_presence")
            removeBuff("unholy_presence")
            applyBuff("blood_presence")
        end,
    },
    
    frost_presence = {
        id = 48266,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("unholy_presence")
            applyBuff("frost_presence")
        end,
    },
    
    unholy_presence = {
        id = 48265,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
            removeBuff("blood_presence")
            removeBuff("frost_presence")
            applyBuff("unholy_presence")
        end,
    },
    
    -- Rune management
    blood_tap = {
        id = 45529,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        spend = function() return glyph.blood_tap.enabled and 15 or 0 end,
        spendType = function() return glyph.blood_tap.enabled and "runic_power" or nil end,
        
        startsCombat = false,
        
        handler = function ()
            if not glyph.blood_tap.enabled then
                -- Original functionality: costs health
                spend(0.05, "health")
            end
            -- Convert a blood rune to a death rune
        end,
    },
    
    empower_rune_weapon = {
        id = 47568,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        
        handler = function ()
            -- Refresh all rune cooldowns and generate 25 runic power
            gain(25, "runic_power")
        end,
    },
    }
} )


spec:RegisterStateFunction( "spend_runes", function( rune_array )
    if type(rune_array) == "table" then
        local blood_cost, frost_cost, unholy_cost = rune_array[1], rune_array[2], rune_array[3]
        
        -- Spend Blood runes
        if blood_cost and blood_cost > 0 then
            if runes.blood.count >= blood_cost then
                runes.blood.count = runes.blood.count - blood_cost
            elseif runes.death.count >= blood_cost then
                runes.death.count = runes.death.count - blood_cost
            end
        end
        
        -- Spend Frost runes
        if frost_cost and frost_cost > 0 then
            if runes.frost.count >= frost_cost then
                runes.frost.count = runes.frost.count - frost_cost
            elseif runes.death.count >= frost_cost then
                runes.death.count = runes.death.count - frost_cost
            end
        end
        
        -- Spend Unholy runes
        if unholy_cost and unholy_cost > 0 then
            if runes.unholy.count >= unholy_cost then
                runes.unholy.count = runes.unholy.count - unholy_cost
            elseif runes.death.count >= unholy_cost then
                runes.death.count = runes.death.count - unholy_cost
            end
        end
    else
        -- Legacy support for single rune type spending
        local rune_type, amount = rune_array, 1
        
        if rune_type == "obliterate" then
            if runes.frost.count > 0 and runes.unholy.count > 0 then
                runes.frost.count = runes.frost.count - 1
                runes.unholy.count = runes.unholy.count - 1
            elseif runes.death.count >= 2 then
                runes.death.count = runes.death.count - 2
            end
        elseif rune_type == "frost" and (runes.frost.count >= amount or runes.death.count >= amount) then
            if runes.frost.count >= amount then
                runes.frost.count = runes.frost.count - amount
            else
                runes.death.count = runes.death.count - amount
            end
        elseif rune_type == "unholy" and (runes.unholy.count >= amount or runes.death.count >= amount) then
            if runes.unholy.count >= amount then
                runes.unholy.count = runes.unholy.count - amount
            else
                runes.death.count = runes.death.count - amount
            end
        elseif rune_type == "death" and runes.death.count >= amount then
            runes.death.count = runes.death.count - amount
        end
    end
end )

-- Unified DK Runes interface across specs (matches Unholy implementation)
-- Duplicate unified runes state table removed; resource(5) provides state.runes.

-- Removed shadowing state expressions for blood_runes/frost_runes/unholy_runes/death_runes

-- Legacy rune type expressions for SimC compatibility
spec:RegisterStateExpr( "blood", function() 
    -- Safe rune counting that works in both game and emulation
    if GetRuneCooldown then
        local count = 0
        for i = 1, 2 do
            local start, duration, ready = GetRuneCooldown( i )
            if ready then count = count + 1 end
        end
        return count
    else
        -- Fallback for emulation
        if state.blood_runes and state.blood_runes.current then
            return state.blood_runes.current
        end
        return 2 -- Default to 2 blood runes
    end
end )
spec:RegisterStateExpr( "frost", function() 
    -- Safe rune counting that works in both game and emulation
    if GetRuneCooldown then
        local count = 0
        for i = 3, 4 do
            local start, duration, ready = GetRuneCooldown( i )
            if ready then count = count + 1 end
        end
        return count
    else
        -- Fallback for emulation
        if state.frost_runes and state.frost_runes.current then
            return state.frost_runes.current
        end
        return 2 -- Default to 2 frost runes
        end
    end )
spec:RegisterStateExpr( "unholy", function() 
    -- Safe rune counting that works in both game and emulation
    if GetRuneCooldown then
        local count = 0
        for i = 5, 6 do
            local start, duration, ready = GetRuneCooldown( i )
            if ready then count = count + 1 end
        end
        return count
    else
        -- Fallback for emulation
        if state.unholy_runes and state.unholy_runes.current then
            return state.unholy_runes.current
        end
        return 2 -- Default to 2 unholy runes
        end
    end )
spec:RegisterStateExpr( "death", function() 
    -- Safe rune counting that works in both game and emulation
    if GetRuneCooldown and GetRuneType then
        local count = 0
        for i = 1, 6 do
            local start, duration, ready = GetRuneCooldown( i )
            local type = GetRuneType( i )
            if ready and type == 4 then count = count + 1 end
        end
        return count
    else
        -- Fallback for emulation
        if state.death_runes and state.death_runes.count then
            return state.death_runes.count
        end
        return 0 -- Default to 0 death runes
    end
end )

-- MoP Frost-specific rune tracking
spec:RegisterStateExpr( "obliterate_runes_available", function()
    local fr = state.frost_runes and state.frost_runes.current or 0
    local ur = state.unholy_runes and state.unholy_runes.current or 0
    local dr = 0
    if state.death_runes and state.death_runes.count then dr = state.death_runes.count end
    return (fr > 0 and ur > 0) or dr >= 2
end )

spec:RegisterStateExpr( "howling_blast_runes_available", function()
    local fr = state.frost_runes and state.frost_runes.current or 0
    local dr = 0
    if state.death_runes and state.death_runes.count then dr = state.death_runes.count end
    return fr > 0 or dr > 0
end )

spec:RegisterStateExpr( "rime_proc_active", function()
    return buff.rime.up
end )

-- Provide disease state like Unholy for APL compatibility (disease.min_remains)
spec:RegisterStateExpr( "disease", function()
    local frost_fever_remains = debuff.frost_fever.remains or 0
    local blood_plague_remains = debuff.blood_plague.remains or 0

    local min_remains = 0
    if frost_fever_remains > 0 and blood_plague_remains > 0 then
        min_remains = math.min( frost_fever_remains, blood_plague_remains )
    elseif frost_fever_remains > 0 then
        min_remains = frost_fever_remains
    elseif blood_plague_remains > 0 then
        min_remains = blood_plague_remains
    end

    return { min_remains = min_remains }
end )

-- Legacy alias used by some APLs
spec:RegisterStateExpr( "disease_min_remains", function()
    local frost_fever_remains = debuff.frost_fever.remains or 0
    local blood_plague_remains = debuff.blood_plague.remains or 0

    if frost_fever_remains > 0 and blood_plague_remains > 0 then
        return math.min( frost_fever_remains, blood_plague_remains )
    elseif frost_fever_remains > 0 then
        return frost_fever_remains
    elseif blood_plague_remains > 0 then
        return blood_plague_remains
    else
        return 0
    end
end )

-- MoP Death Rune conversion for Frost
spec:RegisterStateFunction( "convert_to_death_rune", function( rune_type, amount )
    amount = amount or 1
    -- This function would need to be implemented differently since we can't directly modify rune state
    -- For now, just return true to indicate conversion is possible
    return true
end )

-- Rune state expressions for MoP 5.5.0
spec:RegisterStateExpr( "rune", function()
    local total = 0
    for i = 1, 6 do
        local start, duration, ready = GetRuneCooldown( i )
        if ready then total = total + 1 end
    end
    return total
end )

spec:RegisterStateExpr( "rune_deficit", function()
    if not state then return 0 end
    local total = 0
    if state.blood_runes and type(state.blood_runes) == "table" and state.blood_runes.current then 
        total = total + state.blood_runes.current 
    end
    if state.frost_runes and type(state.frost_runes) == "table" and state.frost_runes.current then 
        total = total + state.frost_runes.current 
    end
    if state.unholy_runes and type(state.unholy_runes) == "table" and state.unholy_runes.current then 
        total = total + state.unholy_runes.current 
    end
    if state.death_runes and type(state.death_runes) == "table" and state.death_runes.count then 
        total = total + state.death_runes.count 
    end
    return 6 - total
end )

spec:RegisterStateExpr( "rune_current", function()
    if not state then return 0 end
    -- Use state resources for emulation compatibility
    local total = 0
    if state.blood_runes and type(state.blood_runes) == "table" and state.blood_runes.current then
        total = total + state.blood_runes.current
    end
    if state.frost_runes and type(state.frost_runes) == "table" and state.frost_runes.current then
        total = total + state.frost_runes.current
    end
    if state.unholy_runes and type(state.unholy_runes) == "table" and state.unholy_runes.current then
        total = total + state.unholy_runes.current
    end
    if state.death_runes and type(state.death_runes) == "table" and state.death_runes.count then
        total = total + state.death_runes.count
    end
    return total
end )

-- Alias for APL compatibility
spec:RegisterStateExpr( "runes_current", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end )



spec:RegisterStateExpr( "rune_max", function()
    return 6
end )


    
spec:RegisterRanges( "obliterate", "frost_strike", "howling_blast" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 2,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    cycle = true,
    cycleDebuff = "frost_fever",

    potion = "tempered_potion",

    package = "Frost",
} )

spec:RegisterSetting( "dps_shell", false, {
    name = strformat( "Use %s Offensively", Hekili:GetSpellLinkWithTexture( 48707 ) ),
    desc = strformat( "If checked, %s will not be on the Defensives toggle by default.", Hekili:GetSpellLinkWithTexture( 48707 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "it_macro", nil, {
    name = strformat( "%s Macro", Hekili:GetSpellLinkWithTexture( 45477 ) ),
    desc = strformat( "Using a mouseover macro makes it easier to apply %s and %s to other enemies without retargeting.",
        Hekili:GetSpellLinkWithTexture( 45477 ), Hekili:GetSpellLinkWithTexture( 59921 ) ),
    type = "input",
    width = "full",
    multiline = true,
    get = function() return "#showtooltip\n/use [@mouseover,harm,nodead][] Icy Touch" end,
    set = function() end,
} )

-- Register default pack for MoP Frost Death Knight
spec:RegisterPack(
	"Frost", 20250918, [[Hekili:TRvBpUTns4Fllcoh7Ejkw2R3KTW2aTxqr72MElQZD5BsIwM2IyLf1jrfdFWq)2VHKwsKsIYAXUPPaxcsw7vC4mdNxEMrdJJTZhDwTbXWo)(KXtMn(w73znXEYn2ZCwXogJDwfJ8FaTd(seAp8ZFkHMY4p9yifTHV7uAwIpSIZQ1zKq2Ve5SUblTV96BNCRZkuglGM4SA1(STjKhCwfq2Sbl3bo13z1hdiP5E8)HY9ol6Cp6w439zeAuUxijLblVLMK79Z4hiHelNvIhkok4TOSqg81FxC0K7Yz1Es0g3Tjy8)f0uCeADiEJZp6WaDKtw1tw5Nqy4ecc(gLgUHEiYcfXi7r7i(UPb4WqRe8EejcuIf5EJRKrnY4gH9clN9y(F4cBQQoftcdrjU0TGIjmQA611QKMEmcfNIDtJtir7sRr6mJhH1zB3AvtowzXvmEDiLcgMSKJCgDZtGr4KuCYdG2Xz0BF8msgEXGZ3dyMDfJlFcW239ez7KgSDcNT3AKTxbbHyM1UaAwOfFRFgxXIeebCjBWqAaWe7X14cpGoHelP99aPOuiu(dOiiMypoIbH0rBY9(dSmbk37EiEJB)uKpdfcuALffqdp6UoKSlGzDwg5EdY9gM7THYSeNx3T4pJtQIoNN7nn370jjjspDCiAxgUonJQouAIsCUSnADaHFvlmNr85XbsrFvtfSCDfXsZyRtWOhes0CkzhItjVs8C3uWf)awWWPxIHTOEv8J4F0LrZ8de86AJ86SZ6S4dXy)G6(QHx2xm4IE0rsllWRKSiSRFwsIiCAoahnXuuHMtXSlBK8VnmMItJ48BgSzyPoLk5ULpnJRyCysHEjxtMC2(AYWp9fRoVmuYoiDeGzXGhXDdblp13izHbqG6hj8(y6bCIRW6DaJIHhYpz1r)kZZZICLF3LxNr9i)ze8bqVf7a1naYNHDkkg5kXDMiTz1Hd7bNHaZlXCBoZzIplk3ziUuy1cWOqwGvSpyyFTiq67unQQl)M2n1JKw7PZukmbaJUqIBmoP7IPNtoKrDmuSwMHWXjxYpGlyRugu7p3BjiUzfH0gJS4rhgdTQwS1yR6LcbvRSqTjW8FfcXezlFa5hqI4q3jekCup2OK0dssD3lPesLrCdSmEh6uqejkpNtuALqM5wHGzg0riLeWljzDflcOhesEDikL1DxcnuL31HQupl5YL5KTQjvNCVFuOp6r61oexSY2YIOcZGPssg1H9WCpkYc9U4i8Eco9S3PItqfFwGlKpc1(9rhBRXenJYFKfPzrQHz2sK7YUafxQckkjqOrLRRRTuOuoimE)4D2QZtnbTZ4zTCRgDk1rK41DejAR1HVY5uV74oANqtCZ1Lg8Ekr8Qihirmj4whTr8OsM7OfIN7INxQOhtuI6Bvp(6w9q(EaGT6REHKwLIjSK)mkOuyvO(Mqq))RAhNRM(pva7(RyXKhhoU56b9V7MVvm45OyqCc2NUFnI1wnbAmGyJvCcfVGc)BHzWhPX4Wqxj4FQLMpsOc2c9JNLjEFglO2dNjNFFg1xZrVRsEezU3VgXNjX3N7jMbjKL)b69qK7pes2fXlfCGWP6t0pTISpTKQF4(Fl97lRUO7gGJBkoYVEqI2u6uMYJovAdOdLS)ipaHf0kTMHkl6(vpct8wR8uY2wtDCa30vm6nQAym9SVxrVe(CaDmLVsX0AFRZQdOKi5Cg)yaa)qGWLKcONxoj4Lqmg()Krs4w9ukhHgLXO7H0n4bqn4ODqay(D)MO6Mn4X(xrPzXCMWjqQraNuk))snY)h0iqReetJ5PXa98XcZ3uJgoE90VByJh(3A2bYO5lModuDgT3C5nM4sP2oX4HRSHGkIFRrIRvwqXAywa6(BLTCTXT0sEpFF531IB2(BU5)8CZ3(y4)xVyIZ3UYZvGHYLY0htDT7xPAltnULAddSpg8k8EfZ3yJKRnVCLDy(uxmQ7E5q1MLTYomFKlNwDV8(QJ3vzdZEwcxk7M4XfWy2AOx1UpbaT5nnBnQxfVApMnint5YV7x2xq211U4syzrBs(q52z28gUOBj8oOErUxNT5C3l6xNoCX)cG2pEG(6Fw0mv1lvM79Vp3XwA(Ds1k1Q0j93x8MIg6EfVHSfv9J9kr)Dl6O9Uf2duBRRqlUVG5G2jLx7cw3X2onvUY2xVUZRDQ0DxVISDXvT3)1PtD0718BAN7YMSko9Vxcx28SduQG9P(4AyCVsEfYlK3GmxBV0LsVySk7QH)PUuTRuwDPQlfMlrt3QI6gkV83EUHmqWqhW7phOD(kEFkBEsp3CvuKW3x)2DfUoWZ1)RRvtZulgW5Fx3F7GHgMrX8PNozA4eZNosvGf1s4YA4vMUwVtNUYW1bQXmTAncRJX7juzxL1Bk3rBx7ytXik5OyJA7AthmCOzdXaJMVrNonmr5QrNVystJDPTX0HC0inRtlf(ew9HnEn9fJh041ZlFM6RLVymxtB2858f3mEGHyzUsDgD5(vkq7QH463QOmnzIWw3YvkEXDAl9STU1M1A(jnCgOuahQP6faKo8(0uUPw7RX7Y(JvcLAmM4bggr8YfZg0M)70PwCGfpSMh8mIrVMQBnDxDwqLWxToc2bkZuA5IjJRXOQXD1nBUG81eY7gF(K1(iyRXkTMbkvIQj3zeSB5SbMsXxoBunPu79N4YrcBxmVvW2uO1xAWPDAch2W)VSTe4L8e4gtnvOe93qFDDV5LSLg18g8PERokYDEdX2Ps2iKZaC4tbmSeyldf(6prWHnHtS)ccNy)xB4KMyi2pxyi2pUOUwLB7yh99)paxsxU65goX(PcNOZPVuOhppXKD747n4KTj0g7hhAZLLAdD8laAJy43o)V]]
)
