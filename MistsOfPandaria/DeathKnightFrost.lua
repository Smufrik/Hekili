-- DeathKnightFrost.lua
-- Updated june 1, 2025 - Mists of Pandaria Frost Death Knight Module
-- MoP API Compatibility: Uses UnitClass, GetRuneCooldown, GetRuneType instead of retail APIs

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass("player")
if playerClass ~= "DEATHKNIGHT" then
	return
end

local addon, ns = ...
local Hekili = _G[addon]
local class, state = Hekili.Class, Hekili.State

-- Initialize state.runes early to prevent nil reference errors
if not state.runes then
    state.runes = { expiry = { 0, 0, 0, 0, 0, 0 }, cooldown = 10, max = 6 }
end

-- Ensure state.runes.expiry is always available
if not state.runes.expiry then
    state.runes.expiry = { 0, 0, 0, 0, 0, 0 }
end

-- Ensure state.runes.expiry[6] exists to prevent State.lua errors
if not state.runes.expiry[6] then
    state.runes.expiry[6] = 0
end

local spec = Hekili:NewSpecialization(251)

-- Local function declarations for increased performance
-- Strings
local strformat = string.format

-- Tables
local insert, remove, sort, wipe = table.insert, table.remove, table.sort, table.wipe

-- Math
local abs, ceil, floor, max, min, sqrt = math.abs, math.ceil, math.floor, math.max, math.min, math.sqrt

-- Common WoW APIs (MoP compatible)
local GetRuneCooldown = GetRuneCooldown
local GetRuneType = GetRuneType
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID


-- Runes (unified model matching retail structure)
spec:RegisterResource( 5, { -- Runes = 5 in MoP (Total rune count for UI display)
    rune_regen = {
        last = function () return state.query_time end,
        stop = function( x ) return x == 6 end,

        interval = function( time, val )
            val = floor( val )
            if val == 6 then return -1 end
            return state.runes.expiry[ val + 1 ] - time
        end,
        value = 1,
    },
}, setmetatable( {
    expiry = { 0, 0, 0, 0, 0, 0 },
    cooldown = 10,
    regen = 0,
    max = 6,
    forecast = {},
    fcount = 0,
    times = {},
    values = {},
    resource = "runes_total",

    reset = function()
        if not state.runes then
            state.runes = { expiry = { 0, 0, 0, 0, 0, 0 }, cooldown = 10, max = 6 }
        end
        if not state.runes.expiry then
            state.runes.expiry = { 0, 0, 0, 0, 0, 0 }
        end
        -- Ensure all expiry slots exist
        for i = 1, 6 do
            if not state.runes.expiry[i] then
                state.runes.expiry[i] = 0
            end
        end
        local t = state.runes
        for i = 1, 6 do
            local start, duration, ready = GetRuneCooldown( i )
            start = start or 0
            duration = duration or ( 10 * state.haste )
            t.expiry[ i ] = ready and 0 or ( start + duration )
            t.cooldown = duration
        end
        table.sort( t.expiry )
        t.actual = nil -- Reset actual to force recalculation
    end,

    gain = function( amount )
        local t = state.runes
        for i = 1, amount do
            table.insert( t.expiry, 0 )
            t.expiry[ 7 ] = nil
        end
        table.sort( t.expiry )
        t.actual = nil
    end,

    spend = function( amount )
        local t = state.runes
        for i = 1, amount do
            local nextReady = ( t.expiry[ 4 ] > 0 and t.expiry[ 4 ] or state.query_time ) + t.cooldown
            table.remove( t.expiry, 1 )
            table.insert( t.expiry, nextReady )
        end

        state.gain( amount * 10, "runic_power" )

        if state.talent.gathering_storm and state.talent.gathering_storm.enabled and state.buff.remorseless_winter and state.buff.remorseless_winter.up then
            state.buff.remorseless_winter.expires = state.buff.remorseless_winter.expires + ( 0.5 * amount )
        end

        t.actual = nil
    end,

    timeTo = function( x )
        return state:TimeToResource( state.runes, x )
    end,
}, {
    __index = function( t, k )
        if k == "actual" then
            -- Calculate the number of runes available based on `expiry`.
            local amount = 0
            for i = 1, 6 do
                if t.expiry[ i ] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount

        elseif k == "current" then
            -- If this is a modeled resource, use our lookup system.
            if t.forecast and t.fcount > 0 then
                local q = state.query_time
                local index, slice

                if t.values[ q ] then return t.values[ q ] end

                for i = 1, t.fcount do
                    local v = t.forecast[ i ]
                    if v.t <= q and v.v ~= nil then
                        index = i
                        slice = v
                    else
                        break
                    end
                end

                -- We have a slice.
                if index and slice and slice.v then
                    t.values[ q ] = max( 0, min( t.max, slice.v ) )
                    return t.values[ q ]
                end
            end

            return t.actual

        elseif k == "deficit" then
            return t.max - t.current

        elseif k == "time_to_next" then
            return t[ "time_to_" .. t.current + 1 ]

        elseif k == "time_to_max" then
            return t.current == t.max and 0 or max( 0, t.expiry[ 6 ] - state.query_time )

        else
            local amount = k:match( "time_to_(%d+)" )
            amount = amount and tonumber( amount )
            if amount then return t.timeTo( amount ) end
        end
    end
} ))

-- Keep expiry fresh when we reset the simulation step
spec:RegisterHook("reset_precast", function()
    if state.runes and state.runes.reset then
        state.runes.reset()
    end
end)
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
            -- Compute live rune readiness from the game API to avoid stale expiry data.
            local readyCount = 0
            for slot = 1, 2 do
                local _, _, ready = GetRuneCooldown( slot )
                if ready then readyCount = readyCount + 1 end
            end
            return readyCount
        elseif k == "current" or k == "count" then
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
            -- Frost runes live readiness from slots 3-4.
            local readyCount = 0
            for slot = 3, 4 do
                local _, _, ready = GetRuneCooldown( slot )
                if ready then readyCount = readyCount + 1 end
            end
            return readyCount
        elseif k == "current" or k == "count" then
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
            -- Unholy runes live readiness from slots 5-6.
            local readyCount = 0
            for slot = 5, 6 do
                local _, _, ready = GetRuneCooldown( slot )
                if ready then readyCount = readyCount + 1 end
            end
            return readyCount
        elseif k == "current" or k == "count" then
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

-- Add missing abilities that were defined outside RegisterAbilities
spec:RegisterAbilities( {
    outbreak = {
        id = 77575,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "frost_fever", 30)
            applyDebuff("target", "blood_plague", 30)
        end,
    },
    
    pestilence = {
        id = 50842,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy
        
        startsCombat = true,
        
        usable = function()
            return debuff.frost_fever.up or debuff.blood_plague.up
        end,
        
        handler = function()
            gain(10, "runic_power")
            if debuff.frost_fever.up then
                active_dot.frost_fever = min(active_enemies, active_dot.frost_fever + active_enemies - 1)
            end
            if debuff.blood_plague.up then
                active_dot.blood_plague = min(active_enemies, active_dot.blood_plague + active_enemies - 1)
            end
        end,
    },
    
    soul_reaper = {
        id = 114867,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 0, 1}, -- 0 Blood, 0 Frost, 1 Unholy
        
        gain = 10,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "soul_reaper", 5)
        end,
    },
} )


spec:RegisterAuras( {
    antimagic_shell = {
        id = 48707,
        duration = 5,
        max_stack = 1,
        copy = "magic_immunity"
    },

    army_of_the_dead = {
        id = 42650,
        duration = 40,
        max_stack = 1,
    },

    blood_charge = {
        id = 114851,
        duration = 25,
        max_stack = 12,
    },

    blood_fury = {
        id = 33697,
        duration = 15,
        max_stack = 1,
    },

    blood_plague = {
        id = 59879,
        duration = 30,
        tick_time = 3,
        max_stack = 1,
        type = "Disease",
        copy = "blood_plague_enhanced"
    },
    blood_presence = {
        id = 48263,
        duration = 10,
        max_stack = 1,
    },
    blood_tap = {
        id = 45529,
        duration = 20,
        max_stack = 1,
    },

    chains_of_ice = {
        id = 45524,
        duration = 8,
        max_stack = 1,
        type = "Magic",
        copy = "frost_slow"
    },

    death_and_decay = {
        id = 43265,
        duration = 10,
        max_stack = 1,
        tick_time = 1,
    },

    death_grip = {
        id = 49560,
        duration = 3,
        max_stack = 1,
        type = "Magic",
    },

    frost_fever = {
        id = 55095,
        duration = 30,
        tick_time = 3,
        max_stack = 1,
        type = "Disease",
        copy = "frost_fever_enhanced"
    },
    frost_presence = {
        id = 48266,
        duration = 10,
        max_stack = 1,
    },

    horn_of_winter = {
        id = 57330,
        duration = 120,
        max_stack = 1,
        copy = "strength_agility_buff"
    },

    icebound_fortitude = {
        id = 48792,
        duration = 12,
        max_stack = 1,
    },

    killing_machine = {
        id = 51124,
        duration = 10,
        max_stack = 1,
        copy = { "km", "guaranteed_crit" }
    },

    path_of_frost = {
        id = 3714,
        duration = 3600,
        max_stack = 1,
    },

    pillar_of_frost = {
        id = 51271,
        duration = 20,
        max_stack = 1,
        copy = { "pillar_of_frost_enhanced", "strength_boost" }
    },

    rime = {
        id = 59052,
        duration = 15,
        max_stack = 1,
        copy = "rime_proc"
    },

    runic_corruption = {
        id = 51460,
        duration = 3,
        max_stack = 1,
        copy = "enhanced_rune_regen"
    },

    runic_empowerment = {
        id = 81229,
        duration = 5,
        max_stack = 1,
        copy = "instant_rune_refresh"
    },

    soul_reaper = {
        id = 114867,
        duration = 5,
        max_stack = 1,
    },

    tier14_2pc = {
        id = 123456,
        duration = 3600,
        max_stack = 1,
        generate = function( aura )
            if state.set_bonus.tier14_2pc > 0 then
                aura.count = 1
                aura.expires = GetTime() + 3600
                aura.applied = GetTime()
                aura.caster = "player"
                aura.spread_count = frostEventData.disease_management.disease_refreshes or 0
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
    },

    tier15_2pc = {
        id = 123457,
        duration = 20,
        max_stack = 1,
        generate = function( aura )
            if state.set_bonus.tier15_2pc > 0 and state.buff.pillar_of_frost.up then
                aura.count = 1
                aura.expires = state.buff.pillar_of_frost.expires
                aura.applied = state.buff.pillar_of_frost.applied
                aura.caster = "player"
                aura.crit_bonus = 0.05
                return
            end
            aura.count = 0
            aura.expires = 0
            aura.applied = 0
            aura.caster = "nobody"
        end,
    },
    unholy_presence = {
        id = 48265,
        duration = 10,
        max_stack = 1,
    },
    unholy_blight = {
        id = 115989,
        duration = 10,
        max_stack = 1,
        type = "Disease",
    },

} )

-- Register auxiliary cooldown abilities used by APL windows (racials/engineering)
spec:RegisterAbilities( {
    obliterate = {
        id = 49020,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 1, 1}, -- 0 Blood, 1 Frost, 1 Unholy
        
        gain = 20,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            -- Rime proc chance (45% base in MoP)
            if math.random() < 0.45 then
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
        
        spend = 35,
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
            removeStack("killing_machine")
            
            applyDebuff("target", "frost_fever")
            active_dot.frost_fever = active_enemies
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
            -- Spend Frost rune explicitly (engine doesn't process spend_runes here).
            spend( 1, "frost_runes" )
            applyDebuff("target", "frost_fever")
            
            -- Base RP generation
            local rp_gain = 10
            
            -- Chill of the Grave: additional RP from Icy Touch
            if talent.chill_of_the_grave.enabled then
                rp_gain = rp_gain + 5 -- Extra 5 RP per talent point
            end
            
            gain(rp_gain, "runic_power")
            
            -- Glyph of Icy Touch: increased Frost Fever damage
            -- Frost Fever will deal 20% more damage if glyphed
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
            -- Deal additional frost damage scaled by attack power if glyphed
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
        cooldown = 45,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        
        handler = function ()
            applyBuff("antimagic_shell")
        end,
    },
    
    icebound_fortitude = {
        id = 48792,
        cast = 0,
        cooldown = 180,
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
            -- Increased damage from glyph if glyphed
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
            gain(10, "runic_power")
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
    -- Howling Blast - Core AoE ability
    howling_blast = {
        id = 49184,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 1, 0}, -- 0 Blood, 1 Frost, 0 Unholy
        
        gain = 10,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            -- Apply Frost Fever to all targets hit
            applyDebuff("target", "frost_fever")
            
            -- Rime proc chance (45% base in MoP)
            if math.random() < 0.45 then
                applyBuff("rime")
            end
        end,
    },

    -- Pillar of Frost - Major cooldown
    pillar_of_frost = {
        id = 51271,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        
        spend_runes = {1, 0, 0}, -- 1 Blood, 0 Frost, 0 Unholy
        
        gain = 10,
        gainType = "runic_power",
        
        startsCombat = false,
        toggle = "cooldowns",
        
        handler = function ()
            applyBuff("pillar_of_frost")
        end,
    },

    -- Army of the Dead - Major cooldown
    army_of_the_dead = {
        id = 42650,
        cast = 0,
        cooldown = 600,
        gcd = "spell",
        
        startsCombat = false,
        toggle = "cooldowns",
        
        handler = function ()
            -- Summon ghouls and generate runic power
            gain(30, "runic_power")
        end,
    },

    -- Death and Decay - AoE ability
    death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        
        spend_runes = {1, 0, 1}, -- 1 Blood, 0 Frost, 1 Unholy
        
        gain = 10,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "death_and_decay")
        end,
    },

    
    -- Additional abilities for APL compatibility (alphabetical order)
    antimagic_shell = {
        id = 48707,
        cast = 0,
        cooldown = 45,
        gcd = "off",
        
        startsCombat = false,
        
        toggle = function()
            if settings.dps_shell then
                return
            end
            return "defensives"
        end,
        
        handler = function ()
            applyBuff("antimagic_shell")
        end,
    },
    
    blood_tap = {
        id = 45529,
        cast = 0,
        cooldown = 1,
        gcd = "off",
        
        startsCombat = false,
        
        usable = function ()
            return buff.blood_charge.stack >= 5
        end,
        
        handler = function ()
            removeBuff("blood_charge", 5)
            gain(1, "runes")
        end,
    },
    
    death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 0, 1}, -- 0 Blood, 0 Frost, 1 Unholy
        
        gain = 10,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "death_and_decay", 10)
        end,
    },
    
    empower_rune_weapon = {
        id = 47568,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            gain(6, "runes")
            gain(25, "runic_power")
        end,
    },
    
    icy_touch = {
        id = 45477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {0, 1, 0}, -- 0 Blood, 1 Frost, 0 Unholy
        
        gain = 10,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "frost_fever", 30)
        end,
    },
    
    mind_freeze = {
        id = 47528,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        
        startsCombat = true,
        
        toggle = "interrupts",
        
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        
        handler = function ()
            interrupt()
        end,
    },
    
    pillar_of_frost = {
        id = 51271,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        startsCombat = false,
        
        toggle = "cooldowns",
        
        handler = function ()
            applyBuff("pillar_of_frost", 20)
        end,
    },
    
    plague_leech = {
        id = 123693,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        talent = "plague_leech",
        startsCombat = true,
        
        usable = function ()
            return debuff.frost_fever.up and debuff.blood_plague.up
        end,
        
        handler = function ()
            removeDebuff("target", "frost_fever")
            removeDebuff("target", "blood_plague")
            gain(1, "runes")
        end,
    },
    
    plague_strike = {
        id = 45462,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend_runes = {1, 0, 0}, -- 1 Blood, 0 Frost, 0 Unholy
        
        gain = 10,
        gainType = "runic_power",
        
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "blood_plague", 30)
        end,
    },
    
    unholy_blight = {
        id = 115989,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        talent = "unholy_blight",
        startsCombat = true,
        
        handler = function ()
            applyDebuff("target", "unholy_blight", 10)
        end,
    },
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
    
    -- Return simple object with timeTo method for APL compatibility
    return {
        count = total,
        timeTo = function(amount)
            if amount <= total then return 0 end
            -- Calculate time to get 'amount' runes
            local needed = amount - total
            if needed <= 0 then return 0 end
            
            -- Find the next rune that will be ready
            local nextReady = math.huge
            for i = 1, 6 do
                local start, duration, ready = GetRuneCooldown(i)
                if not ready and start and duration then
                    local readyTime = start + duration
                    if readyTime < nextReady then
                        nextReady = readyTime
                    end
                end
            end
            
            if nextReady == math.huge then return 0 end
            return max(0, nextReady - state.query_time)
        end
    }
end )

-- Individual rune type counts for APL compatibility
spec:RegisterStateExpr( "runes_total", function()
    -- Return total rune count for resource display
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end )

spec:RegisterStateExpr( "runes", function()
    return {
        blood = { count = state.blood_runes and state.blood_runes.current or 0 },
        frost = { count = state.frost_runes and state.frost_runes.current or 0 },
        unholy = { count = state.unholy_runes and state.unholy_runes.current or 0 },
        death = { count = state.death_runes and state.death_runes.count or 0 }
    }
end )

spec:RegisterStateExpr( "runes_by_type", function()
    return {
        blood = { count = state.blood_runes and state.blood_runes.current or 0 },
        frost = { count = state.frost_runes and state.frost_runes.current or 0 },
        unholy = { count = state.unholy_runes and state.unholy_runes.current or 0 },
        death = { count = state.death_runes and state.death_runes.count or 0 }
    }
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


-- Soul Reaper execute check normalized to importer's math
-- Equivalent to: target.health.pct - 3 * ( target.health.pct / target.time_to_die ) <= 35
spec:RegisterStateExpr( "sr_exec_window_3s", function()
    if not target or not target.time_to_die or target.time_to_die <= 0 then return false end
    local hp = target.health and target.health.pct or 100
    return ( hp - 3 * ( hp / target.time_to_die ) ) <= 35
end )


    
spec:RegisterRanges( "mind_freeze", "howling_blast", "obliterate", "frost_strike" )

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

-- Frost Death Knight specific settings
spec:RegisterSetting( "frost_runic_power_threshold", 80, {
    name = "Runic Power Threshold for Frost Strike",
    desc = "Minimum runic power to spend on Frost Strike",
    type = "range",
    min = 20,
    max = 100,
    step = 5,
    width = "full",
} )

spec:RegisterSetting( "frost_km_priority", true, {
    name = "Prioritize Killing Machine",
    desc = "Always use Killing Machine procs immediately",
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "frost_rime_priority", true, {
    name = "Prioritize Rime Procs",
    desc = "Always use Rime procs for free Howling Blast",
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "frost_execute_threshold", 35, {
    name = "Execute Threshold for Soul Reaper",
    desc = "Target health percentage to use Soul Reaper",
    type = "range",
    min = 20,
    max = 50,
    step = 5,
    width = "full",
} )

-- Register default pack for MoP Frost Death Knight
spec:RegisterPack(
	"Frost", 20251009, [[Hekili:TRvFVTTnA8plbfNBCxIRSDSJZqSb2l3qxVBBfN7T7)KeTmDmrKf1PxMroyOp73ZdPTLOePKSDUEyaDORnrI85n(75vk7(2F2E(ssc1(xhynyuFlRh6b)W99FWEEYlHu75HeVNjpb)qazd83)uepobF6l(CYsC3X80ip4n2ZxKY8t(5a7fAiPL1DdTNtstwZJSNpFt6Qi2Z2ZxZwUKk3bn2ZE(NxZIZCX)NK5UN1zU8vWV7LW4bzU(S4e41R4rzUFG(mZN1ZEU4HcHHf8Kp1jHe9enbEWVkuqAazHpDP93Bp3lILqJyeq9i(0GKEl858LWgc7TFvzUDYCVoZDr6Qv7FR3AKE9ItabkZDwMBFRdRkknG55eY3sJeV5(XzU72P5vtZChi3LGWGG7dYQZgI3AwaTxefuWm3UY)awkH6c20dIN0cfXcLp)Fgd2LTRPGfzlJ6VeOvMBYwoyScO3UMeSe1KTusipi2obolmAiQtEqvPSkozsU4TcHdoXjWHjf5YqJCzjLKSwA8KKvSv5dYP3A(wHySWNaWmGG3105xAWAU)lWgypToP8zi8NL8KEsPCf9pOrGITHWcae0JzUdLscUePDo0N8ukT8AupruyikIJQreryyV1uIFY6EHOb9wbfFNq00863F8PjSnaoM7SKrfsWJaaA4OCXaC78DGtPqAujOXN7p(dzUZH3N5(pelq4USj1N8TGtveDjZdDHKmkZvYFWRlqiBXupEWsbMzCtgFJop61Ulu5fe3JZ9xY3g0RGbi)adwNLzxiqLU3OkDvvSscZ7zanwd8CstKtbxTNEc9qcJe4FRCgixybhQhQ3TncmusF1AeY(wgjs1WxM9T7BowArLrODxvxyUCwWbViGeyYcKbIyu6vJc8fxP54m7rMsfJUrOABWNueHEqENQe8PIc3yWhJ4)xtW)mj2hJuzoNeOjtmJ67BogvLSu3zvJfzS6juuGdFLZwwqcgfs9iYSNMjJNjH3St2EkT3RXNs9wxLyfFRGEpuuj2drCa7a1rMVuvtsWWRRiP(ARN4azibWXg5jWugVM67JvaTru2eu)d8FhZaFuOahdseA9wjROsX4vh8UkgreD06yDhMwY4cLFuI99sdvapHCX)2q(3ZHn1B4pKnvfhSkn6LsgifC4cAumnsgPwzv3xCvKipsakQrraMP0kldXocXjyQW5X(8Kd)sZbL1zCXZgtwSbf84axTGNPj9pWZJ)E9XXFT47Gs8DqEG)dRmIWIPoq5Cll7XxUeZJ7inWr(ZoyH6fLB8X)b1Hgq3WOXYaqdL1Z7iB4GWPAJ4Fge)XY0wTBbHRouEKhFZcsUZERI2zs1LbqbIgtdWMKkuFG4it99O)XbV)Cy7Mxq2MSwRr)oLGk89UwfxXO2h2PC9E6oYlObHaOI4dMyPPdpPAthxARypNzvQV2KTnKgNW8lBxRTORAZxavBqD8GFyWeDXGVC2AUvLJf1QUKI9HC3dvKW7SBz5s11Hsn1XuFhWLJsVpBT5EgoLAnnx8G(s3eDx6aXNbuQh5fDH01sIb2LltOnLEFQfWyv8GsrvlfbT9bCQeSTvffvtXVvQsYCni1sGYLpF41TPoRKTCh5OlAvGK)Ko6MF7ytp3UI7LgJYDepHGVfNMd2l(AW)h5nQZql5EeKJ6cgwQeGtQFlZNWNYiFmxH4zoYNgJw9))r(u3GrE9A8RUr(uBmYM8pELBq91B6mnooLtB6mMJG)knDMMQiVDJNXCGUtjLznze0RnLg(YW2wnXxhlYxhlY(ULa3WyC5IB6X6bOS05BjrbaYjgVlh4GIb0jkz)918wLgUElK2J(Vtzri(iMVbwnjnHVbaKWdGdYGNOX9Y(4FhsKL5o6BZC)bEaWrXR5HiYf4DSCW1VTc252HV76kp8Vufm19XPdhbYscV1u59MOYrPDCJsR(Z6oxxLBNKI0PUiWtT62nxtVqjWKrOzj4OvQ)DNTzQDYOoR0SHJ2TZqeJztN0cdu74To7tJ8gmnzFuJJtELXNMxtZ4W2OkFP8AUVrP9cXSF1RPnY4Fo9A(zHddAqgv6RfaEnu8Ci1dYtnQpoJp(kMp089BYC)rzpk)TaS0EWU(tYwuU(x4FciuVr9S6kQrrEPQ)g0c3g2)byYhH9(9erVBiFMZ28dWIyy1c9hJFzcrCMhEBRcwflw)80queHJPfCKPltj(3kU9EKHqHw0irLfahbxDX15F8M8VoVRXUybpm)LXOw)gGUF6WmlZC)opjq4JsdqCVJZZ8BM((vqXCpFd(zDmvwBsSZcGMgwmyPLRfQb07zNqAyiwpaBrSyolXRHIBd1Vx1kGmqFLjFQFnLN9P(vjN6PH3PoVt9lkF8MhSO)cbDKkBmrjs9AEUrElptLxYtXfAIXhL3ByRMwfRdHcS2T7ADVySvhdt5VBrQRPWntSYmflsW87Gr5PhVZffZJYDSu8nPGfgWABUbVEHPIBsX8RpCPhOGBqc3TtNgnWQrIo4cjArWsHNQEle3G3VWucNImdFE(1qmB6Wg3OszYvjXJdpGt)o(FnhM6E9WV5q3sX5yIEGyGgJIZWqIiQzykL2C(mVXDAQZ5o103Xn7ND90btUmIRvE7u)a0F8UhQH)k96w(LhtKvWKvn5MPKt9TktVIToIKSqFMZUFC5vxAS24gKk40(vSIfNnrHfo4S0O6e7Q2p9r7vKlbyOah1Hr6CQ6wLfQj43bxL5cFkihTW)qKt)hX8V)lD5FXS1N0xyxUGO472wZDNRnJG6CTkgbspu8bq4PoMh9B3UDnlALXIMjZUDfz5KjMPPIZKWFgHWZ6VBNGBZ6BERNuekOGBdJ59XH72zA8UpoSR8W915BKZSUuOi(czFpJ6UXEdUyWvlR9(S7o6eGdxzykUMjrfN)RmMIqIuMzDcYtPX02ENftbUlVV8PSMh4AMvNRQ5QKAN03ErDpWW4NeNM4UNjq78Xzn1Jx71wLGJ3vlwqFERZs3Be)2MeGMjsnj2(m0L4h2Nn63jrmOffiDwkM9kr(10VkZfDvfdqs(X1N3zPmC4zFLK5sC(eQARj7ltspf5s1zSnUGkBVoOwXKIkB6eYiQSVVyPd1Y9)hLa7CqjxquLtm7v9NBnN6sz)xuER6LeJjTAnATygRA8qofb7YoKp)Z42N5O1whL0gL0y95moDvUEuZPLTqHc6)UAtST)V)]]
)
