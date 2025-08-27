-- DeathKnightBlood.lua
-- Updated August 19, 2025

-- TODO:
-- Implement Engineer quickflip_deflection_plates
-- Implement Tier Sets Properly
-- Implement Glyphs on abilities
-- Test Necrotic Strike rune spending
-- Track Scent of Blood Runic Power generation
-- Soul Reaper Haste Effect
-- Check if switching talents breaks Hekili logic on APL (may need a reload after changing talents)

-- MoP: Use UnitClass instead of UnitClassBase
-- TODO: Formatting all files similarly
local _, playerClass = UnitClass('player')
if playerClass ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G["Hekili"]

if not Hekili or not Hekili.NewSpecialization then
    return
end

local class = Hekili.Class
local state = Hekili.State

-- Ensure death_knight namespace exists early to avoid unknown key errors in emulation.
if not state.death_knight then state.death_knight = { runeforge = {} } end
if not state.death_knight.runeforge then state.death_knight.runeforge = {} end

-- Safe local references to WoW API (helps static analyzers and emulation)
local GetRuneCooldown = rawget(_G, "GetRuneCooldown") or function() return 0, 10, true end
local GetRuneType = rawget(_G, "GetRuneType") or function() return 1 end

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization(250) -- Blood spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced Helper Functions (following Hunter Survival pattern)
local function UA_GetPlayerAuraBySpellID(spellID, filter)
    -- MoP compatibility: use fallback methods since C_UnitAuras doesn't exist
    if filter == "HELPFUL" or not filter then
        return FindUnitBuffByID("player", spellID)
    else
        return FindUnitDebuffByID("player", spellID)
    end
end

local function GetTargetDebuffByID(spellID, caster)
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = FindUnitDebuffByID("target", spellID,
        caster or "PLAYER")
    if name then
        return {
            name = name,
            icon = icon,
            count = count or 1,
            duration = duration,
            expires = expirationTime,
            applied = expirationTime - duration,
            caster = unitCaster
        }
    end
    return nil
end

-- Local shim for resource changes to normalize names and avoid global gain/spend calls.
local function _normalizeResource(res)
    if res == "runicpower" or res == "rp" then return "runic_power" end
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

-- Minimal compatibility stubs to avoid undefineds in placeholder logic.
local function heal(amount)
    if state and state.gain then
        state.gain(amount, "health", true, true)
    elseif state and state.health then
        local cur, maxv = state.health.current or 0, state.health.max or 1
        state.health.current = math.min(maxv, cur + (tonumber(amount) or 0))
    end
end

local mastery = { blood_shield = { enabled = false } }
local mastery_value = (state and (state.mastery_value or (state.stat and state.stat.mastery_value))) or 0

-- Combat Log Event Tracking System (following Hunter Survival structure)
local bloodCombatLogFrame = CreateFrame("Frame")
local bloodCombatLogEvents = {}

local function RegisterBloodCombatLogEvent(event, handler)
    if not bloodCombatLogEvents[event] then
        bloodCombatLogEvents[event] = {}
    end
    table.insert(bloodCombatLogEvents[event], handler)
end

bloodCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags =
            CombatLogGetCurrentEventInfo()

        if sourceGUID == UnitGUID("player") then
            local handlers = bloodCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName,
                        destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

bloodCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- MoP runeforge detection (classic-safe), matching Unholy implementation
local blood_runeforges = {
    [3370] = "razorice",
    [3368] = "fallen_crusader",
    [3847] = "stoneskin_gargoyle",
}

local function Blood_ResetRuneforges()
    if not state.death_knight then state.death_knight = {} end
    if not state.death_knight.runeforge then state.death_knight.runeforge = {} end
    table.wipe(state.death_knight.runeforge)
end

local function Blood_UpdateRuneforge(slot)
    if slot ~= 16 and slot ~= 17 then return end
    if not state.death_knight then state.death_knight = {} end
    if not state.death_knight.runeforge then state.death_knight.runeforge = {} end

    local link = GetInventoryItemLink("player", slot)
    local enchant = link and link:match("item:%d+:(%d+)")
    if enchant then
        local name = blood_runeforges[tonumber(enchant)]
        if name then
            state.death_knight.runeforge[name] = true
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
            Blood_ResetRuneforges()
            Blood_UpdateRuneforge(16)
            Blood_UpdateRuneforge(17)
        elseif evt == "PLAYER_EQUIPMENT_CHANGED" then
            local slot = ...
            if slot == 16 or slot == 17 then
                Blood_ResetRuneforges()
                Blood_UpdateRuneforge(16)
                Blood_UpdateRuneforge(17)
            end
        end
    end)
end

Hekili:RegisterGearHook(Blood_ResetRuneforges, Blood_UpdateRuneforge)

-- Blood Shield tracking
RegisterBloodCombatLogEvent("SPELL_AURA_APPLIED",
    function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags,
             destRaidFlags, spellID, spellName, spellSchool)
        if spellID == 77535 then     -- Blood Shield
            -- Track Blood Shield absorption for optimization
        elseif spellID == 49222 then -- Bone Armor
            -- Track Bone Armor stacks
        elseif spellID == 55233 then -- Vampiric Blood
            -- Track Vampiric Blood for survival cooldown
        end
    end)

-- Crimson Scourge proc tracking
RegisterBloodCombatLogEvent("SPELL_AURA_APPLIED",
    function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags,
             destRaidFlags, spellID, spellName, spellSchool)
        if spellID == 81141 then     -- Crimson Scourge
            -- Track Crimson Scourge proc for free Death and Decay
        elseif spellID == 59052 then -- Freezing Fog
            -- Track Freezing Fog proc for Howling Blast
        end
    end)

-- Disease application tracking
RegisterBloodCombatLogEvent("SPELL_AURA_APPLIED",
    function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags,
             destRaidFlags, spellID, spellName, spellSchool)
        if spellID == 55078 then     -- Blood Plague
            -- Track Blood Plague for disease management
        elseif spellID == 55095 then -- Frost Fever
            -- Track Frost Fever for disease management
        end
    end)

-- Death Strike healing tracking
RegisterBloodCombatLogEvent("SPELL_HEAL",
    function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags,
             destRaidFlags, spellID, spellName, spellSchool, amount)
        if spellID == 45470 then -- Death Strike
            -- Track Death Strike healing for survival optimization
        end
    end)

-- Register resources
-- MoP: Use legacy power type constants
spec:RegisterResource(6) -- RunicPower = 6 in MoP
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

    spec:RegisterResource(5, {}, setmetatable({
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
            if k == "blood" then return buildTypeCounter({ 1, 2 }, 1) end
            if k == "frost" then return buildTypeCounter({ 3, 4 }, 2) end
            if k == "unholy" then return buildTypeCounter({ 5, 6 }, 3) end
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
    })) -- Runes = 5 in MoP with unified state

    spec:RegisterHook("reset_precast", function()
        if state.runes and state.runes.reset then state.runes.reset() end
    end)
end

-- Register individual rune types for MoP 5.5.0
spec:RegisterResource(20, { -- Blood Runes = 20 in MoP
    rune_regen = {
        last = function() return state.query_time end,
        stop = function(x) return x == 2 end,
        interval = function(time, val)
            local r = state.blood_runes
            if val == 2 then return -1 end
            return r.expiry[val + 1] - time
        end,
        value = 1,
    }
}, setmetatable({
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
            local start, duration, ready = GetRuneCooldown(i)
            start = start or 0
            duration = duration or (10 * state.haste)
            t.expiry[i] = ready and 0 or (start + duration)
            t.cooldown = duration
        end
        table.sort(t.expiry)
        t.actual = nil
    end,

    gain = function(amount)
        local t = state.blood_runes
        for i = 1, amount do
            table.insert(t.expiry, 0)
            t.expiry[3] = nil
        end
        table.sort(t.expiry)
        t.actual = nil
    end,

    spend = function(amount)
        local t = state.blood_runes
        for i = 1, amount do
            local nextReady = (t.expiry[1] > 0 and t.expiry[1] or state.query_time) + t.cooldown
            table.remove(t.expiry, 1)
            table.insert(t.expiry, nextReady)
        end
        t.actual = nil
    end,

    timeTo = function(x)
        return state:TimeToResource(state.blood_runes, x)
    end,
}, {
    __index = function(t, k)
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[i] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget(t, k)
    end
}))

spec:RegisterResource(21, { -- Frost Runes = 21 in MoP
    rune_regen = {
        last = function() return state.query_time end,
        stop = function(x) return x == 2 end,
        interval = function(time, val)
            local r = state.frost_runes
            if val == 2 then return -1 end
            return r.expiry[val + 1] - time
        end,
        value = 1,
    }
}, setmetatable({
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
        for i = 5, 6 do -- Frost runes are at positions 5-6
            local start, duration, ready = GetRuneCooldown(i)
            start = start or 0
            duration = duration or (10 * state.haste)
            t.expiry[i - 4] = ready and 0 or (start + duration)
            t.cooldown = duration
        end
        table.sort(t.expiry)
        t.actual = nil
    end,

    gain = function(amount)
        local t = state.frost_runes
        for i = 1, amount do
            table.insert(t.expiry, 0)
            t.expiry[3] = nil
        end
        table.sort(t.expiry)
        t.actual = nil
    end,

    spend = function(amount)
        local t = state.frost_runes
        for i = 1, amount do
            local nextReady = (t.expiry[1] > 0 and t.expiry[1] or state.query_time) + t.cooldown
            table.remove(t.expiry, 1)
            table.insert(t.expiry, nextReady)
        end
        t.actual = nil
    end,

    timeTo = function(x)
        return state:TimeToResource(state.frost_runes, x)
    end,
}, {
    __index = function(t, k)
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[i] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget(t, k)
    end
}))

spec:RegisterResource(22, { -- Unholy Runes = 22 in MoP
    rune_regen = {
        last = function() return state.query_time end,
        stop = function(x) return x == 2 end,
        interval = function(time, val)
            local r = state.unholy_runes
            if val == 2 then return -1 end
            return r.expiry[val + 1] - time
        end,
        value = 1,
    }
}, setmetatable({
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
        for i = 3, 4 do -- Unholy runes are at positions 3-4
            local start, duration, ready = GetRuneCooldown(i)
            start = start or 0
            duration = duration or (10 * state.haste)
            t.expiry[i - 2] = ready and 0 or (start + duration)
            t.cooldown = duration
        end
        table.sort(t.expiry)
        t.actual = nil
    end,

    gain = function(amount)
        local t = state.unholy_runes
        for i = 1, amount do
            table.insert(t.expiry, 0)
            t.expiry[3] = nil
        end
        table.sort(t.expiry)
        t.actual = nil
    end,


    spend = function(amount)
        local t = state.unholy_runes
        for i = 1, amount do
            local nextReady = (t.expiry[1] > 0 and t.expiry[1] or state.query_time) + t.cooldown
            table.remove(t.expiry, 1)
            table.insert(t.expiry, nextReady)
        end
        t.actual = nil
    end,

    timeTo = function(x)
        return state:TimeToResource(state.unholy_runes, x)
    end,
}, {
    __index = function(t, k)
        if k == "actual" then
            local amount = 0
            for i = 1, 2 do
                if t.expiry[i] <= state.query_time then
                    amount = amount + 1
                end
            end
            return amount
        elseif k == "current" then
            return t.actual
        end
        return rawget(t, k)
    end
}))

-- Unified DK Runes interface across specs
-- Removed duplicate RegisterStateTable("runes"); unified model lives on the resource.

-- Death Runes State Table for MoP 5.5.0 (Blood DK)
spec:RegisterStateTable("death_runes", setmetatable({
    state = {},

    reset = function()
        for i = 1, 6 do
            local start, duration, ready = GetRuneCooldown(i)
            local type = GetRuneType(i)
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

    spend = function(neededRunes)
        local usedRunes, err = state.death_runes.getRunesForRequirement(neededRunes)
        if not usedRunes then
            return
        end

        local runeMapping = {
            blood = { 1, 2 },
            frost = { 5, 6 },
            unholy = { 3, 4 }
        }

        for _, runeIndex in ipairs(usedRunes) do
            local rune = state.death_runes.state[runeIndex]
            rune.ready = false

            -- Determine other rune in the group
            local otherRuneIndex
            for type, runes in pairs(runeMapping) do
                if runes[1] == runeIndex then
                    otherRuneIndex = runes[2]
                    break
                elseif runes[2] == runeIndex then
                    otherRuneIndex = runes[1]
                    break
                end
            end

            local otherRune = state.death_runes.state[otherRuneIndex]
            local expiryTime = (otherRune.expiry > 0 and otherRune.expiry or state.query_time) + rune.duration
            rune.expiry = expiryTime
        end
    end,

    getActiveDeathRunes = function()
        local activeRunes = {}
        local state_array = state.death_runes.state
        for i = 1, #state_array do
            if state_array[i].type == 4 and state_array[i].expiry < state.query_time then
                table.insert(activeRunes, i)
            end
        end
        return activeRunes
    end,

    getLeftmostActiveDeathRune = function()
        local activeRunes = state.death_runes.getActiveDeathRunes()
        return #activeRunes > 0 and activeRunes[1] or nil
    end,

    getActiveRunes = function()
        local activeRunes = {}
        local state_array = state.death_runes.state
        for i = 1, #state_array do
            if state_array[i].expiry < state.query_time then
                table.insert(activeRunes, i)
            end
        end
        return activeRunes
    end,

    getRunesForRequirement = function(neededRunes)
        local bloodNeeded, frostNeeded, unholyNeeded = unpack(neededRunes)
        -- for rune mapping, see the following in game...
        -- /run for i=1,6 do local t=GetRuneType(i); local s,d,r=GetRuneCooldown(i); print(i,"type",t,"ready",r) end
        local runeMapping = {
            blood = { 1, 2 },
            frost = { 5, 6 },
            unholy = { 3, 4 }, --
            any = { 1, 2, 3, 4, 5, 6 }
        }

        local activeRunes = state.death_runes.getActiveRunes()
        local usedRunes = {}
        local usedDeathRunes = {}

        local function useRunes(runetype, needed)
            local runes = runeMapping[runetype]
            for _, runeIndex in ipairs(runes) do
                if needed == 0 then break end
                if state.death_runes.state[runeIndex].expiry < state.query_time and state.death_runes.state[runeIndex].type ~= 4 then
                    table.insert(usedRunes, runeIndex)
                    needed = needed - 1
                end
            end
            return needed
        end

        -- Use specific runes first
        bloodNeeded = useRunes("blood", bloodNeeded)
        frostNeeded = useRunes("frost", frostNeeded)
        unholyNeeded = useRunes("unholy", unholyNeeded)

        -- Use death runes if needed
        for _, runeIndex in ipairs(activeRunes) do
            if bloodNeeded == 0 and frostNeeded == 0 and unholyNeeded == 0 then break end
            if state.death_runes.state[runeIndex].type == 4 and not usedDeathRunes[runeIndex] then
                if bloodNeeded > 0 then
                    table.insert(usedRunes, runeIndex)
                    bloodNeeded = bloodNeeded - 1
                elseif frostNeeded > 0 then
                    table.insert(usedRunes, runeIndex)
                    frostNeeded = frostNeeded - 1
                elseif unholyNeeded > 0 then
                    table.insert(usedRunes, runeIndex)
                    unholyNeeded = unholyNeeded - 1
                end
                usedDeathRunes[runeIndex] = true
            end
        end

        return usedRunes
    end,

}, {
    __index = function(t, k)
        local countDeathRunes = function()
            local state_array = t.state
            local count = 0
            for i = 1, #state_array do
                if state_array[i].type == 4 and state_array[i].expiry < state.query_time then
                    count = count + 1
                end
            end
            return count
        end
        local runeMapping = {
            blood = { 1, 2 },
            frost = { 5, 6 },
            unholy = { 3, 4 },
            any = { 1, 2, 3, 4, 5, 6 }
        }
        -- Function to access the mappings
        local function getRuneSet(runeType)
            return runeMapping[runeType]
        end

        local countDRForType = function(type)
            local state_array = t.state
            local count = 0
            local runes = getRuneSet(type)
            if runes then
                for _, rune in ipairs(runes) do
                    if state_array[rune].type == 4 and state_array[rune].expiry < state.query_time then
                        count = count + 1
                    end
                end
            end
            return count
        end

        if k == "state" then
            return t.state
        elseif k == "actual" then
            return countDRForType("any")
        elseif k == "current" then
            return countDRForType("any")
        elseif k == "current_frost" then
            return countDRForType("frost")
        elseif k == "current_blood" then
            return countDRForType("blood")
        elseif k == "current_unholy" then
            return countDRForType("unholy")
        elseif k == "current_non_frost" then
            return countDRForType("blood") + countDRForType("unholy")
        elseif k == "current_non_blood" then
            return countDRForType("frost") + countDRForType("unholy")
        elseif k == "current_non_unholy" then
            return countDRForType("blood") + countDRForType("frost")
        elseif k == "cooldown" then
            return t.state[1].duration
        elseif k == "active_death_runes" then
            return t.getActiveDeathRunes()
        elseif k == "leftmost_active_death_rune" then
            return t.getLeftmostActiveDeathRune()
        elseif k == "active_runes" then
            return t.getActiveRunes()
        elseif k == "runes_for_requirement" then
            return t.getRunesForRequirement
        end
    end
}))

-- Ensure the death_runes state is initialized during engine reset so downstream expressions are safe.
spec:RegisterHook("reset_precast", function()
    if state.death_runes and state.death_runes.reset then
        state.death_runes.reset()
    end
end)

-- Tier sets
spec:RegisterGear("tier14", 86919, 86920, 86921, 86922, 86923)                             -- T14 Battleplate of the Lost Cataphract
spec:RegisterGear("tier15", 95225, 95226, 95227, 95228, 95229)                             -- T15 Battleplate of the All-Consuming Maw
spec:RegisterGear(13, 6, {                                                                 -- Tier 14 (Heart of Fear)
    { 86886, head = 86886, shoulder = 86889, chest = 86887, hands = 86888, legs = 86890 }, -- LFR
    { 86919, head = 86919, shoulder = 86922, chest = 86920, hands = 86921, legs = 86923 }, -- Normal
    { 87139, head = 87139, shoulder = 87142, chest = 87140, hands = 87141, legs = 87143 }, -- Heroic
})

spec:RegisterAura("tier14_2pc_blood", {
    id = 105677,
    duration = 15,
    max_stack = 1,
})

spec:RegisterAura("tier14_4pc_blood", {
    id = 105679,
    duration = 30,
    max_stack = 1,
})

spec:RegisterGear(14, 6, {                                                                 -- Tier 15 (Throne of Thunder)
    { 95225, head = 95225, shoulder = 95228, chest = 95226, hands = 95227, legs = 95229 }, -- LFR
    { 95705, head = 95705, shoulder = 95708, chest = 95706, hands = 95707, legs = 95709 }, -- Normal
    { 96101, head = 96101, shoulder = 96104, chest = 96102, hands = 96103, legs = 96105 }, -- Heroic
})

spec:RegisterAura("tier15_2pc_blood", {
    id = 138252,
    duration = 20,
    max_stack = 1,
})

spec:RegisterAura("tier15_4pc_blood", {
    id = 138253,
    duration = 10,
    max_stack = 1,
})

spec:RegisterGear(15, 6,
    {                                                                                          -- Tier 16 (Siege of Orgrimmar)
        { 99625, head = 99625, shoulder = 99628, chest = 99626, hands = 99627, legs = 99629 }, -- LFR
        { 98310, head = 98310, shoulder = 98313, chest = 98311, hands = 98312, legs = 98314 }, -- Normal
        { 99170, head = 99170, shoulder = 99173, chest = 99171, hands = 99172, legs = 99174 }, -- Heroic
        { 99860, head = 99860, shoulder = 99863, chest = 99861, hands = 99862, legs = 99864 }, -- Mythic
    })

spec:RegisterAura("tier16_2pc_blood", {
    id = 144958,
    duration = 8,
    max_stack = 1,
})

spec:RegisterAura("tier16_4pc_blood", {
    id = 144966,
    duration = 15,
    max_stack = 1,
})

spec:RegisterGear("resolve_of_undying", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
})

spec:RegisterGear("juggernaut_s_focusing_crystal", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
})

spec:RegisterGear("bone_link_fetish", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
})

spec:RegisterGear("armageddon", 105531, {
    main_hand = 105531,
})

-- Talents (MoP talent system and Blood spec-specific talents)
spec:RegisterTalents({
    -- Common MoP talent system (Tier 1-6)
    -- Tier 1 (Level 56)
    roiling_blood      = { 1, 1, 108170 }, -- Your Pestilence refreshes disease durations and spreads diseases from each diseased target to all other targets.
    plague_leech       = { 1, 2, 123693 }, -- Extract diseases from an enemy target, consuming up to 2 diseases on the target to gain 1 Rune of each type that was removed.
    unholy_blight      = { 1, 3, 115989 }, -- Causes you to spread your diseases to all enemy targets within 10 yards.

    -- Tier 2 (Level 57)
    lichborne          = { 2, 1, 49039 },  -- Draw upon unholy energy to become undead for 10 sec, immune to charm, fear, and sleep effects.
    anti_magic_zone    = { 2, 2, 51052 },  -- Places an Anti-Magic Zone that reduces spell damage taken by party members by 40%.
    purgatory          = { 2, 3, 114556 }, -- An unholy pact that prevents fatal damage, instead absorbing incoming healing.

    -- Tier 3 (Level 58)
    deaths_advance     = { 3, 1, 96268 },  -- For 8 sec, you are immune to movement impairing effects and take 50% less damage from area of effect abilities.
    chilblains         = { 3, 2, 50041 },  -- Victims of your Chains of Ice, Howling Blast, or Remorseless Winter are Chilblained, reducing movement speed by 50% for 10 sec.
    asphyxiate         = { 3, 3, 108194 }, -- Lifts an enemy target off the ground and crushes their throat, silencing them for 5 sec.

    -- Tier 4 (Level 60)
    death_pact         = { 4, 1, 48743 },  -- Sacrifice your ghoul to heal yourself for 20% of your maximum health.
    death_siphon       = { 4, 2, 108196 }, -- Inflicts Shadow damage to target enemy and heals you for 100% of the damage done.
    conversion         = { 4, 3, 119975 }, -- Continuously converts 2% of your maximum health per second into 20% of maximum health as healing.

    -- Tier 5 (Level 75)
    blood_tap          = { 5, 1, 45529 }, -- Consume 5 charges from your Blood Charges to immediately activate a random depleted rune.
    runic_empowerment  = { 5, 2, 81229 }, -- When you use a rune, you have a 45% chance to immediately regenerate that rune.
    runic_corruption   = { 5, 3, 51462 }, -- When you hit with a Death Coil, Frost Strike, or Rune Strike, you have a 45% chance to regenerate a rune.

    -- Tier 6 (Level 90)
    gorefiends_grasp   = { 6, 1, 108199 }, -- Shadowy tendrils coil around all enemies within 20 yards of a hostile target, pulling them to the target's location.
    remorseless_winter = { 6, 2, 108200 }, -- Surrounds the Death Knight with a swirling blizzard that grows over 8 sec, slowing enemies by up to 50% and reducing their melee and ranged attack speed by up to 20%.
    desecrated_ground  = { 6, 3, 108201 }, -- Corrupts the ground targeted by the Death Knight for 30 sec. While standing on this ground you are immune to effects that cause loss of control.
})

-- Glyphs
spec:RegisterGlyphs({
    -- Major Glyphs (affecting tanking and mechanics)
    [58623] = "antimagic_shell",     -- Causes your Anti-Magic Shell to absorb all incoming magical damage, up to the absorption limit.
    [58620] = "chains_of_ice",       -- Your Chains of Ice also causes 144 to 156 Frost damage, with additional damage depending on your attack power.
    [63330] = "dancing_rune_weapon", -- Increases your threat generation by 100% while your Dancing Rune Weapon is active, but reduces its damage dealt by 25%.
    [63331] = "dark_simulacrum",     -- Reduces the cooldown of Dark Simulacrum by 30 sec and increases its duration by 4 sec.
    [96279] = "dark_succor",         -- When you kill an enemy that yields experience or honor, while in Frost or Unholy Presence, your next Death Strike within 15 sec is free and will restore at least 20% of your maximum health.
    [58629] = "death_and_decay",     -- Your Death and Decay also reduces the movement speed of enemies within its radius by 50%.
    [63333] = "death_coil",          -- Your Death Coil spell is now usable on all allies.  When cast on a non-undead ally, Death Coil shrouds them with a protective barrier that absorbs up to [(1133 + 0.514 * Attack Power) * 1] damage.
    [62259] = "death_grip",          -- Increases the range of your Death Grip ability by 5 yards.
    [58671] = "enduring_infection",  -- Your diseases are undispellable, but their damage dealt is reduced by 15%.
    [146650] = "festering_blood",    -- Blood Boil will now treat all targets as though they have Blood Plague or Frost Fever applied.
    [58673] = "icebound_fortitude",  -- Reduces the cooldown of your Icebound Fortitude by 50%, but also reduces its duration by 75%.
    [58631] = "icy_touch",           -- Your Icy Touch dispels one helpful Magic effect from the target.
    [58686] = "mind_freeze",         -- Reduces the cooldown of your Mind Freeze ability by 1 sec, but also raises its cost by 10 Runic Power.
    [59332] = "outbreak",            -- Your Outbreak spell no longer has a cooldown, but now costs 30 Runic Power.
    [58657] = "pestilence",          -- Increases the radius of your Pestilence effect by 5 yards.
    [58635] = "pillar_of_frost",     -- Empowers your Pillar of Frost, making you immune to all effects that cause loss of control of your character, but also reduces your movement speed by 70% while the ability is active.
    [146648] = "regenerative_magic", -- If Anti-Magic Shell expires after its full duration, the cooldown is reduced by up to 50%, based on the amount of damage absorbtion remaining.
    [58647] = "shifting_presences",  -- You retain 70% of your Runic Power when switching Presences.
    [58618] = "strangulate",         -- Increases the Silence duration of your Strangulate ability by 2 sec when used on a target who is casting a spell.
    [146645] = "swift_death",        -- The haste effect granted by Soul Reaper now also increases your movement speed by 30% for the duration.
    [146646] = "loud_horn",          -- Your Horn of Winter now generates an additional 10 Runic Power, but the cooldown is increased by 100%.
    [59327] = "unholy_command",      -- Immediately finishes the cooldown of your Death Grip upon dealing a killing blow to a target that grants experience or honor.
    [58616] = "unholy_frenzy",       -- Causes your Unholy Frenzy to no longer deal damage to the affected target.
    [58676] = "vampiric_blood",      -- Increases the bonus healing received while your Vampiric Blood is active by an additional 15%, but your Vampiric Blood no longer grants you health.

    -- Minor Glyphs (convenience and visual)
    [58669] = "army_of_the_dead", -- The ghouls summoned by your Army of the Dead no longer taunt their target.
    [59336] = "corpse_explosion", -- Teaches you the ability Corpse Explosion.
    [60200] = "death_gate",       -- Reduces the cast time of your Death Gate spell by 60%.
    [58677] = "deaths_embrace",   -- Your Death Coil refunds 20 Runic Power when used to heal an allied minion, but will no longer trigger Blood Tap when used this way.
    [58642] = "foul_menagerie",   -- Causes your Army of the Dead spell to summon an assortment of undead minions.
    [58680] = "horn_of_winter",   -- When used outside of combat, your Horn of Winter ability causes a brief, localized snow flurry.
    [59307] = "path_of_frost",    -- Your Path of Frost ability allows you to fall from a greater distance without suffering damage.
    [59309] = "resilient_grip",   -- When your Death Grip ability fails because its target is immune, its cooldown is reset.
    [58640] = "geist",            -- Your Raise Dead spell summons a geist instead of a ghoul.
    [146653] = "long_winter",     -- The effect of your Horn of Winter now lasts for 1 hour.
    [146652] = "skeleton",        -- Your Raise Dead spell summons a skeleton instead of a ghoul.
    [63335] = "tranquil_grip",    -- Your Death Grip spell no longer taunts the target.
})

-- Enhanced Tier Sets with comprehensive bonuses for Blood Death Knight tanking
spec:RegisterGear(13, 8,
    {                                                                                          -- Tier 14 (Heart of Fear) - Death Knight
        { 88183, head = 86098, shoulder = 86101, chest = 86096, hands = 86097, legs = 86099 }, -- LFR
        { 88184, head = 85251, shoulder = 85254, chest = 85249, hands = 85250, legs = 85252 }, -- Normal
        { 88185, head = 87003, shoulder = 87006, chest = 87001, hands = 87002, legs = 87004 }, -- Heroic
    })

-- Reduces the cooldown of your Vampiric Blood ability by 20 sec.
spec:RegisterAura("tier14_2pc_blood", {
    id = 123079,
    duration = 3600,
    max_stack = 1,
})

spec:RegisterAura("tier14_4pc_blood", {
    id = 105925,
    duration = 6,
    max_stack = 1,
})

spec:RegisterGear(14, 8,
    {                                                                                          -- Tier 15 (Throne of Thunder) - Death Knight
        { 96548, head = 95101, shoulder = 95104, chest = 95099, hands = 95100, legs = 95102 }, -- LFR
        { 96549, head = 95608, shoulder = 95611, chest = 95606, hands = 95607, legs = 95609 }, -- Normal
        { 96550, head = 96004, shoulder = 96007, chest = 96002, hands = 96003, legs = 96005 }, -- Heroic
    })

spec:RegisterAura("tier15_2pc_blood", {
    id = 138292,
    duration = 15,
    max_stack = 1,
})

spec:RegisterAura("tier15_4pc_blood", {
    id = 138295,
    duration = 8,
    max_stack = 1,
})

spec:RegisterGear(15, 8,
    {                                                                                          -- Tier 16 (Siege of Orgrimmar) - Death Knight
        { 99683, head = 99455, shoulder = 99458, chest = 99453, hands = 99454, legs = 99456 }, -- LFR
        { 99684, head = 98340, shoulder = 98343, chest = 98338, hands = 98339, legs = 98341 }, -- Normal
        { 99685, head = 99200, shoulder = 99203, chest = 99198, hands = 99199, legs = 99201 }, -- Heroic
        { 99686, head = 99890, shoulder = 99893, chest = 99888, hands = 99889, legs = 99891 }, -- Mythic
    })

spec:RegisterAura("tier16_2pc_blood", {
    id = 144953,
    duration = 20,
    max_stack = 1,
})

spec:RegisterAura("tier16_4pc_blood", {
    id = 144955,
    duration = 12,
    max_stack = 1,
})

-- Advanced Mastery and Specialization Bonuses
spec:RegisterGear(16, 8, {                                                                       -- PvP Sets
    { 138001, head = 138454, shoulder = 138457, chest = 138452, hands = 138453, legs = 138455 }, -- Grievous Gladiator's
    { 138002, head = 139201, shoulder = 139204, chest = 139199, hands = 139200, legs = 139202 }, -- Prideful Gladiator's
})

-- Combat Log Event Registration for advanced tracking
spec:RegisterCombatLogEvent(function(_, subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID,
                                     spellName, _, amount, interrupt, a, b, c, d, offhand, multistrike, ...)
    if sourceGUID == state.GUID then
        if subtype == "SPELL_CAST_SUCCESS" then
            if spellID == 49998 then     -- Death Strike
                state.last_death_strike = GetTime()
            elseif spellID == 45462 then -- Plague Strike
                state.last_plague_strike = GetTime()
            elseif spellID == 49930 then -- Blood Boil
                state.last_blood_boil = GetTime()
            end
        elseif subtype == "SPELL_AURA_APPLIED" then
            if spellID == 77535 then -- Blood Shield
                state.blood_shield_applied = GetTime()
            end
        elseif subtype == "SPELL_DAMAGE" then
            if spellID == 49998 then -- Death Strike healing
                state.death_strike_heal = amount
            end
        end
    end
end)

-- Advanced Aura System with Generate Functions (following Hunter Survival pattern)
spec:RegisterAuras({
    -- Core Blood Death Knight Auras with Advanced Generate Functions
    antimagic_shell = {
        id = 48707,
        duration = 5,
        max_stack = 1
    },

    blood_shield = {
        id = 77535,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 77535)

            if name then
                t.name = name
                t.count = count or 1
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

    bone_shield = {
        id = 49222,
        duration = 300,
        max_stack = 6,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 49222)

            if name then
                t.name = name
                t.count = count or 1
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

    crimson_scourge = {
        id = 81141,
        duration = 15,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 81141)

            if name then
                t.name = name
                t.count = count or 1
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

    vampiric_blood = {
        id = 55233,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 55233)

            if name then
                t.name = name
                t.count = count or 1
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

    dancing_rune_weapon = {
        id = 49028,
        duration = 12,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 49028)

            if name then
                t.name = name
                t.count = count or 1
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

    riposte = {
        id = 145677,
        duration = 20,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 145677)

            if name then
                t.name = name
                t.count = count or 1
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

    vengeance = {
        id = 132365,
        duration = 20,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 145677)

            if name then
                t.name = name
                t.count = count or 1
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

    scent_of_blood = {
        id = 50421,
        duration = 20,
        max_stack = 5,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 145677)

            if name then
                t.name = name
                t.count = count or 1
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

    -- Enhanced Tanking Mechanics
    death_pact = {
        id = 48743,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 48743)

            if name then
                t.name = name
                t.count = count or 1
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

    -- Disease Tracking with Enhanced Generate Functions
    blood_plague = {
        id = 55078,
        duration = 21,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 55078,
                "PLAYER")

            if name then
                t.name = name
                t.count = count or 1
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

    frost_fever = {
        id = 55095,
        duration = 30,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 55095,
                "PLAYER")

            if name then
                t.name = name
                t.count = count or 1
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

    -- Proc Tracking Auras
    will_of_the_necropolis = {
        id = 81162,
        duration = 8,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 81162)

            if name then
                t.name = name
                t.count = count or 1
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

    -- Soul Reaper Haste
    soul_reaper = {
        id = 114868,
        duration = 5,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 114868)

            if name then
                t.name = name
                t.count = count or 1
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

    -- Tier Set Coordination Auras
    t14_blood_2pc = {
        id = 105588,
        duration = 15,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 105588)

            if name then
                t.name = name
                t.count = count or 1
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

    t14_blood_4pc = {
        id = 105589,
        duration = 20,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 105589)

            if name then
                t.name = name
                t.count = count or 1
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

    t15_blood_2pc = {
        id = 138165,
        duration = 10,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 138165)

            if name then
                t.name = name
                t.count = count or 1
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

    t15_blood_4pc = {
        id = 138166,
        duration = 30,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 138166)

            if name then
                t.name = name
                t.count = count or 1
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

    t16_blood_2pc = {
        id = 144901,
        duration = 12,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 144901)

            if name then
                t.name = name
                t.count = count or 1
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

    t16_blood_4pc = {
        id = 144902,
        duration = 25,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 144902)

            if name then
                t.name = name
                t.count = count or 1
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

    -- Defensive Cooldown Tracking
    icebound_fortitude = {
        id = 48792,
        -- duration = 12,
        duration = function() return glyph.icebound_fortitude.enabled and 3 or 12 end,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 48792)

            if name then
                t.name = name
                t.count = count or 1
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

    quickflip_deflection_plates = {
        id = 82176,
        duration = 12,
        max_stack = 1,
    },

    blood_tap = {
        id = 114851,
        duration = 20,
        max_stack = 12,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 114851)

            if name then
                t.name = name
                t.count = count or 1
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

    -- Presence Tracking
    blood_presence = {
        id = 48263,
        duration = 3600,
        max_stack = 1,
    },

    unholy_presence = {
        id = 48265,
        duration = 3600,
        max_stack = 1,
    },

    frost_presence = {
        id = 48266,
        duration = 3600,
        max_stack = 1,
    },

    -- Utility and Control
    death_grip = {
        id = 49560, -- Taunt debuff
        duration = 3,
        max_stack = 1
    },

    dark_command = {
        id = 56222,
        duration = 3,
        max_stack = 1
    },

    -- Shared Death Knight Auras (Basic Tracking)
    death_and_decay = {
        id = 43265,
        duration = 10,
        tick_time = 1.0,
        max_stack = 1
    },

    dark_succor = {
        id = 101568,
        duration = 20,
        max_stack = 1
    },

    necrotic_strike = {
        id = 73975,
        duration = 10,
        max_stack = 15
    },

    chains_of_ice = {
        id = 45524,
        duration = 8,
        max_stack = 1
    },

    mind_freeze = {
        id = 47528,
        duration = 4,
        max_stack = 1
    },

    strangulate = {
        id = 47476,
        duration = 5,
        max_stack = 1
    },

    -- Shared Death Knight Runeforging Procs

    unholy_strength = {
        id = 53365,
        duration = 15,
        max_stack = 1,

        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 81162)

            if name then
                t.name = name
                t.count = count or 1
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

    -- Shared Death Knight Talents

    plague_leech = {
        id = 123693,
        duration = 3,
        max_stack = 1
    },
})

-- Blood DK core abilities
spec:RegisterAbilities({
    -- Anti-Magic Shell
    antimagic_shell = {
        id = 48707,
        cast = 0,
        cooldown = 45,
        gcd = "off",

        startsCombat = false,

        toggle = function()
            if settings.dps_shell then return end
            return "defensives"
        end,

        handler = function()
            applyBuff("antimagic_shell")
        end,
    },

    -- Army of the Dead
    army_of_the_dead = {
        id = 42650,
        cast = 4,
        cooldown = 600,
        gcd = "spell",

        spend_runes = { 1, 1, 1 }, -- 1 Blood, 1 Frost, 1 Unholy

        startsCombat = false,
        texture = 237511,

        toggle = "cooldowns",

        handler = function()
            applyBuff("army_of_the_dead", 4)
            summonPet("army_ghoul", 40)
        end,
    },

    -- Blood Boil: Deals damage to nearby enemies and spreads diseases
    blood_boil = {
        id = 48721,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

        startsCombat = true,
        usable = function()
            local bloodReady = (state.blood or 0) > 0 or (state.death or 0) > 0
            if not bloodReady then return false, "no blood/death rune" end
            local enemies = active_enemies or state.active_enemies or 1
            if enemies > 1 then
                if (debuff.frost_fever.up and active_dot.frost_fever < enemies) or (debuff.blood_plague.up and active_dot.blood_plague < enemies) then
                    return true
                end
                if enemies >= 2 and debuff.frost_fever.up and debuff.blood_plague.up then return true end
            end
            return false, "single target / no spread need"
        end,

        handler = function()
            -- Blood Boil base functionality for MoP
            -- Spreads diseases to nearby enemies
            if debuff.frost_fever.up then
                active_dot.frost_fever = min(active_enemies, active_dot.frost_fever + active_enemies - 1)
            end
            if debuff.blood_plague.up then
                active_dot.blood_plague = min(active_enemies, active_dot.blood_plague + active_enemies - 1)
            end
        end,
    },

    -- Blood Presence
    blood_presence = {
        id = 48263,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        startsCombat = false,

        handler = function()
            if buff.frost_presence.up then removeBuff("frost_presence") end
            if buff.unholy_presence.up then removeBuff("unholy_presence") end
            applyBuff("blood_presence")
        end,
    },

    bone_shield = {
        id = 49222,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        startsCombat = false,

        handler = function()
            applyBuff("bone_shield", nil, 10) -- 10 charges
        end,
    },

    chains_of_ice = {
        id = 45524,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        startsCombat = true,

        handler = function()
            applyDebuff("target", "frost_fever")
        end,
    },

    control_undead = {
        id = 111673,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,

        spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

        handler = function()
            applyBuff("control_undead")
        end,
    },

    dancing_rune_weapon = {
        id = 49028,
        cast = 0,
        cooldown = 90,
        gcd = "spell",

        toggle = "cooldowns",

        startsCombat = false,

        handler = function()
            applyBuff("dancing_rune_weapon")
        end,
    },

    dark_command = {
        id = 56222,
        cast = 0,
        cooldown = 8,
        gcd = "off",

        handler = function()
            applyDebuff("target", "dark_command") -- Taunts the target for 3 seconds, increasing threat generated by 200%
        end,
    },

    dark_simulacrum = {
        id = 77606,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        spend = 20,
        spendType = "runicpower",

        startsCombat = true,

        handler = function()
            applyDebuff("dark_simulacrum")
        end,
    },

    -- Fires a blast of unholy energy at the target$?a377580[ and $377580s2 addition...
    death_coil = {
        id = 47541,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 20,
        spendType = "runicpower",

        startsCombat = false,

        handler = function()
            if buff.sudden_doom.up then
                removeBuff("sudden_doom")
            end
        end
    },

    death_gate = {
        id = 50977,
        cast = 10,
        cooldown = 60,
        gcd = "spell",

        startsCombat = false,
    },

    death_grip = {
        id = 49576,
        cast = 0,
        cooldown = 25,
        gcd = "spell",

        startsCombat = true,

        handler = function()
            applyDebuff("target", "death_grip")
        end,
    },

    death_pact = {
        id = 48743,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        startsCombat = false,

        toggle = "defensives",
    },

    death_strike = {
        id = 49998,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend_runes = { 0, 1, 1 }, -- 0 Blood, 1 Frost, 1 Unholy

        gain = 20,
        gainType = "runicpower",

        startsCombat = true,

        handler = function()
            local heal_amount = min(health.max * 0.25, health.max * 0.07)
            heal(heal_amount)
            local shield_amount = heal_amount * 0.5
            applyBuff("blood_shield")
            if mastery.blood_shield.enabled then
                shield_amount = shield_amount * (1 + mastery_value * 0.062)
            end
        end,
    },

    death_and_decay = {
        id = 43265,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = function() return buff.crimson_scourge.up and 0 or 1 end,
        spendType = function() return buff.crimson_scourge.up and nil or "unholy_runes" end,

        startsCombat = true,

        usable = function()
            return buff.crimson_scourge.up or runes.unholy.count > 0 or runes.death.count > 0
        end,

        handler = function()
            applyDebuff("target", "death_and_decay")
            if buff.crimson_scourge.up then
                removeBuff("crimson_scourge")
            end
        end,
        bind = { "defile", "any_dnd" },

        copy = "any_dnd"
    },

    deaths_advance = {
        id = 96268,
        cast = 0,
        cooldown = 30,
        gcd = "off",

        startsCombat = false,

        handler = function()
            applyBuff("death's_advance")
        end,
    },

    -- Empower Rune Weapon
    empower_rune_weapon = {
        id = 47568,
        cast = 0,
        cooldown = 300,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,

        handler = function()
            gain(25, "runicpower")
        end,
    },

    frost_presence = {
        id = 48266,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        startsCombat = false,

        handler = function()
            if buff.blood_presence.up then removeBuff("blood_presence") end
            if buff.unholy_presence.up then removeBuff("unholy_presence") end
            applyBuff("frost_presence")
        end,
    },

    -- Heart Strike
    heart_strike = {
        id = 55050,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

        startsCombat = true,
    },

    horn_of_winter = {
        id = 57330,
        cast = 0,
        cooldown = 20,
        gcd = "spell",

        startsCombat = false,

        handler = function()
            applyBuff("horn_of_winter")
            gain(10, "runic_power")
        end,
    },

    icebound_fortitude = {
        id = 48792,
        cast = 0,
        cooldown = function() return glyph.icebound_fortitude.enabled and 90 or 180 end,
        gcd = "off",

        toggle = "defensives",

        startsCombat = false,

        handler = function()
            applyBuff("icebound_fortitude")
        end,
    },

    icy_touch = {
        id = 45477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend_runes = { 0, 1, 0 }, -- 0 Blood, 1 Frost, 0 Unholy

        startsCombat = true,

        handler = function()
            applyDebuff("target", "frost_fever")
        end,
    },

    mind_freeze = {
        id = 47528,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        toggle = "interrupts",

        startsCombat = true,

        handler = function()
            if active_enemies > 1 and talent.asphyxiate.enabled then
            end
        end,
    },

    necrotic_strike = {
        id = 73975,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 1,
        spendType = "death_runes",

        startsCombat = true,

        handler = function()
            applyDebuff("target", "necrotic_strike")
        end,
    },

    -- Outbreak: Instantly applies both Frost Fever and Blood Plague to the target
    outbreak = {
        id = 77575,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        startsCombat = true,

        handler = function()
            applyDebuff("target", "frost_fever")
            applyDebuff("target", "blood_plague")
        end,
    },

    path_of_frost = {
        id = 3714,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,

        spend_runes = { 0, 1, 0 }, -- 0 Blood, 1 Frost, 0 Unholy

        handler = function()
            applyBuff("path_of_frost")
        end,
    },

    pestilence = {
        id = 50842,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

        startsCombat = true,

        usable = function() return debuff.frost_fever.up or debuff.blood_plague.up end,

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

    plague_strike = {
        id = 45462,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend_runes = { 0, 0, 1 }, -- 0 Blood, 0 Frost, 1 Unholy

        startsCombat = true,

        handler = function()
            applyDebuff("target", "blood_plague")
        end,
    },

    raise_ally = {
        id = 61999,
        cast = 0,
        cooldown = 600,

        spend = 30,
        spendType = "runicpower",
    },

    raise_dead = {
        id = 46584,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        startsCombat = false,

        toggle = "cooldowns",

        handler = function()
        end,
    },

    rune_strike = {
        id = 56815,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 30,
        spendType = "runicpower",

        startsCombat = true,
        -- texture = 237518, -- THIS ISN'T NEEDED? Removing for now
    },

    rune_tap = {
        id = 48982,
        cast = 0,
        cooldown = 30,
        gcd = "off",

        startsCombat = false,

        spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy
    },

    soul_reaper = {
        id = 114866,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

        startsCombat = true,

        handler = function()
            applyDebuff("target", "soul_reaper")
        end,
    },

    strangulate = {
        id = 47476,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "interrupts",

        spend_runes = { 1, 0, 0 }, -- 1 Blood, 0 Frost, 0 Unholy

        startsCombat = true,

        handler = function()
            applyDebuff("target", "strangulate")
        end,
    },

    unholy_presence = {
        id = 48265,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        startsCombat = false,

        handler = function()
            if buff.frost_presence.up then removeBuff("frost_presence") end
            if buff.blood_presence.up then removeBuff("blood_presence") end
            applyBuff("unholy_presence")
        end,
    },

    vampiric_blood = {
        id = 55233,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "defensives",

        startsCombat = false,

        handler = function()
            applyBuff("vampiric_blood")
        end,
    },

    --- TALENT ABILITIES ---

    -- Talent: Extract diseases from target to gain runes (MoP 5.5.0)
    plague_leech = {
        id = 123693,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        talent = "plague_leech",
        startsCombat = true,

        usable = function()
            -- MoP: Can only use when diseases are about to expire or for rune generation
            local deficit = state.rune_deficit
            return (debuff.frost_fever.up and debuff.frost_fever.remains < 3) or
                (debuff.blood_plague.up and debuff.blood_plague.remains < 3) or
                (deficit >= 2 and (debuff.frost_fever.up or debuff.blood_plague.up))
        end,

        handler = function()
            local runes_gained = 0
            if debuff.frost_fever.up then
                removeDebuff("target", "frost_fever")
                runes_gained = runes_gained + 1
            end
            if debuff.blood_plague.up then
                removeDebuff("target", "blood_plague")
                runes_gained = runes_gained + 1
            end
            gain(runes_gained, "runes")
        end,
    },

    -- Talent: Surrounds the caster with unholy energy that damages nearby enemies
    unholy_blight = {
        id = 115989,
        cast = 0,
        cooldown = 90,
        gcd = "spell",

        talent = "unholy_blight",
        startsCombat = true,

        handler = function()
            applyBuff("unholy_blight")
            applyDebuff("target", "frost_fever")
            applyDebuff("target", "blood_plague")
        end,
    },

    -- Talent: Convert Blood Charges to Death Runes.
    blood_tap = {
        id = 45529,
        cast = 0,
        cooldown = 1,
        gcd = "off",

        talent = "blood_tap",
        startsCombat = false,

        usable = function() return buff.blood_charge.stack >= 5 end,

        handler = function()
            removeBuff("blood_charge", 5)
            gain(1, "runes") -- this is wrong
        end,
    },


    --- PROFESSION ABILITIES ---

    -- Quickflip Deflection Plates
    quickflip_deflection_plates = {
        id = 82176,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        usable = function()
            return true
        end,
    },

})

-- Legacy rune type expressions for SimC compatibility
spec:RegisterStateExpr("blood", function()
    if GetRuneCooldown then
        local count = 0
        for i = 1, 2 do
            local start, duration, ready = GetRuneCooldown(i)
            if ready then count = count + 1 end
        end
        return count
    else
        return 2 -- Fallback for emulation
    end
end)
spec:RegisterStateExpr("frost", function()
    if GetRuneCooldown then
        local count = 0
        for i = 5, 6 do
            local start, duration, ready = GetRuneCooldown(i)
            if ready then count = count + 1 end
        end
        return count
    else
        return 2 -- Fallback for emulation
    end
end)
spec:RegisterStateExpr("unholy", function()
    if GetRuneCooldown then
        local count = 0
        for i = 3, 4 do
            local start, duration, ready = GetRuneCooldown(i)
            if ready then count = count + 1 end
        end
        return count
    else
        return 2 -- Fallback for emulation
    end
end)
spec:RegisterStateExpr("death", function()
    if GetRuneCooldown and GetRuneType then
        local count = 0
        for i = 1, 6 do
            local start, duration, ready = GetRuneCooldown(i)
            local type = GetRuneType(i)
            if ready and type == 4 then count = count + 1 end
        end
        return count
    else
        return 0 -- Fallback for emulation
    end
end)

-- Convert runes to death runes (Blood Tap, etc.)
spec:RegisterStateFunction("convert_to_death_rune", function(rune_type, amount)
    amount = amount or 1

    if rune_type == "blood" and state.blood_runes.current >= amount then
        state.blood_runes.current = state.blood_runes.current - amount
        state.death_runes.count = state.death_runes.count + amount
    elseif rune_type == "frost" and state.frost_runes.current >= amount then
        state.frost_runes.current = state.frost_runes.current - amount
        state.death_runes.count = state.death_runes.count + amount
    elseif rune_type == "unholy" and state.unholy_runes.current >= amount then
        state.unholy_runes.current = state.unholy_runes.current - amount
        state.death_runes.count = state.death_runes.count + amount
    end
end)

-- Add function to check runic power generation
spec:RegisterStateFunction("gain_runic_power", function(amount)
    -- Logic to gain runic power
    gain(amount, "runicpower")
end)


-- Unified DK Runes interface across specs (matches Unholy/Frost implementation)
-- Duplicate unified runes state table removed; resource(5) provides state.runes.

-- State Expressions for Blood Death Knight
spec:RegisterStateExpr("blood_shield_absorb", function()
    return buff.blood_shield.v1 or 0 -- Amount of damage absorbed
end)

spec:RegisterStateExpr("diseases_ticking", function()
    local count = 0
    if debuff.blood_plague.up then count = count + 1 end
    if debuff.frost_fever.up then count = count + 1 end
    return count
end)

spec:RegisterStateExpr("bone_shield_charges", function()
    return buff.bone_shield.stack or 0
end)

spec:RegisterStateExpr("total_runes", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end)

spec:RegisterStateExpr("runes_on_cd", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return 6 - total
end)

-- Removed duplicate rune_deficit (defined later with extended context) to prevent re-registration recursion.

-- MoP-specific rune state expressions for Blood DK
-- Removed shadowing expressions blood_runes/frost_runes/unholy_runes/death_runes that returned numeric counts and
-- replaced with direct API-based blood/frost/unholy/death expressions above. This prevents state table name clashes
-- and potential recursive evaluation leading to C stack overflows.

-- MoP Blood-specific rune tracking
spec:RegisterStateExpr("death_strike_runes_available", function()
    -- Prefer unified runes resource to avoid nil state table during early compilation.
    if state.runes and state.runes.count then
        return state.runes.count >= 2
    end
    -- Fallback to API check if unified runes not yet seeded.
    local ready = 0
    for i = 1, 6 do
        local start, duration, isReady = GetRuneCooldown(i)
        if isReady or (start and duration and (start + duration) <= state.query_time) then
            ready = ready + 1
        end
    end
    return ready >= 2
end)

spec:RegisterStateExpr("blood_tap_charges", function()
    return buff.blood_tap.stack or 0
end)

spec:RegisterStateExpr("blood_tap_available", function()
    local charges = (buff.blood_tap and buff.blood_tap.stack) or 0
    local blood = (state.blood_runes and state.blood_runes.current) or 0
    return talent.blood_tap.enabled and (charges >= 5 or blood > 0)
end)

-- MoP Death Rune conversion for Blood
spec:RegisterStateFunction("blood_tap_convert", function(amount)
    amount = amount or 1
    if state.blood_runes.current >= amount then
        state.blood_runes.current = state.blood_runes.current - amount
        state.death_runes.count = state.death_runes.count + amount
        return true
    end
    return false
end)

-- Rune state expressions for MoP 5.5.0
-- Simplified rune count expression; unique name 'rune_count' to avoid collisions with any internal engine usage.
-- Unify with Unholy: provide 'rune' expression for total ready runes.
spec:RegisterStateExpr("rune", function()
    local total = 0
    for i = 1, 6 do
        local _, _, ready = GetRuneCooldown(i)
        if ready then total = total + 1 end
    end
    return total
end)

-- Provide rune_regeneration (mirrors Unholy) representing rune deficit relative to maximum.
spec:RegisterStateExpr("rune_regeneration", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return 6 - total
end)

-- Consolidated rune_deficit definition (single source).
spec:RegisterStateExpr("rune_deficit", function()
    -- Pure API-based calculation to avoid referencing other state expressions.
    local ready = 0
    for i = 1, 6 do
        local _, _, isReady = GetRuneCooldown(i)
        if isReady then ready = ready + 1 end
    end
    return 6 - ready
end)

-- Stub for time_to_wounds to satisfy Unholy script references when Blood profile loaded.
-- Avoid referencing spec.State (not defined in MoP module context).
spec:RegisterStateExpr("time_to_wounds", function() return 999 end)

spec:RegisterStateExpr("rune_current", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end)

-- Alias for APL compatibility
spec:RegisterStateExpr("runes_current", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return total
end)

spec:RegisterStateExpr("rune_max", function()
    return 6
end)

spec:RegisterStateExpr("death_strike_heal", function()
    -- Estimate Death Strike healing based on recent damage taken
    local base_heal = health.max * 0.07                               -- Minimum 7%
    local max_heal = health.max * 0.25                                -- Maximum 25%
    -- In actual gameplay, this would track damage taken in last 5 seconds
    return math.min(max_heal, math.max(base_heal, health.max * 0.15)) -- Estimate 15% average
end)

spec:RegisterOptions({
    enabled = true,

    -- Targeting/rotation
    aoe = 2,      -- how many targets are considered AoE
    cycle = true, -- allow cycling debuffs in ST

    -- GCD/timing
    gcdSync = true,

    -- Nameplates/range
    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    -- Damage tracking (used for time-to-die and dot heuristics)
    damage = true,        -- enable per-target outgoing DPS tracking (used for time-to-die and DoT heuristics).
    damageExpiration = 8, -- seconds to keep recent damage samples; older samples are dropped from calculations.
    -- damageDots = true,    -- enable tracking of damage over time effects
    -- damageRange = 8,      -- maximum range for damage tracking

    -- potion = "tempered_potion",

    -- Default action pack for this spec
    package = "Blood",
})

spec:RegisterSetting("dnd_while_moving", true, {
    name = strformat("Allow %s while moving", Hekili:GetSpellLinkWithTexture(43265)),
    desc = strformat(
        "If checked, then allow recommending %s while the player is moving otherwise only recommend it if the player is standing still.",
        Hekili:GetSpellLinkWithTexture(43265)),
    type = "toggle",
    width = "full",
})

spec:RegisterSetting("dps_shell", false, {
    name = strformat("Use %s Offensively", Hekili:GetSpellLinkWithTexture(48707)),
    desc = strformat("If checked, %s will not be on the Defensives toggle by default.",
        Hekili:GetSpellLinkWithTexture(48707)),
    type = "toggle",
    width = "full",
})

-- Register default pack for MoP Blood Death Knight
spec:RegisterPack("Blood", 20250819,
    [[Hekili:nRv)UTnYr8NLGc4AFvrws2kj2jYanNZHK0EPgh917pkosUKCL0wrUl7UlTJaei6RrF96tsNzxsXpePKCo3IMahlTC5oF9B(nZoiUJDV31jIOPUFzYOjth9MjJgoAYOPx66OxNsDDsjHRilGpWjjW)((yHicxDDSGeHVSsKjdHN46eKXI1FI7gS7joE6vJHTMsdHvNoY1zjlkIA3kvf66C)sMk3h)HK7xiZCFXC47HAMGN7hZuA4XZfYC)psxXIzdb9qkMZIbP)7Y9F52)K7FNKgksci6gl)z7zPgMw(4zbO94bFxr5H0bS5ZErq285dBU(WS0oE5)WSZdeCQNAjJghv7DRwS3xCPqY9eZ9EKX1uz(Nb9)urkUps8zGhqsFzQa0Eg4buzPPcPMgL7hSo3Fn4Wn(HvxBEVUoE4DrN2NnBOUJ5dCTeoJ7eGC703mlKeh7z)Ih6ZhGb(zr05uUI9avTDNGy6EVeHXrIR)a1JYPjmQ6MzxuOo)jkn9CjDo4BxM7hXuuIcowFkrgV2AXCknIgnSUOez6ajLScpznrUGQhgrRhQIjlYOdL0ecJRE3Sl2SP52MlfkT3C6duzTDvOtFVGdRRlqFsnJeN7)d)853sjAqjvmDgXcdb)Mi3)whyRpqyXKaaiQx3qvTkKMKA11ykxpC7AdPCsqmn6Ktnk0SXB2KXxkIxJFkcf3SXNDYlGuL44HzkCVdnl7P0s2kAHc)JG(BvdyplOwKaeF)zfK284skhvFqhLWxdeOnGiXA7b8LM4d6Yn5ujmnBrHrE6hVds4epczGWtm585(ogeneXepYpRU9wx9qt2Ayt2AyWNwsjX6Ldtd1VB2RhTzt9KSAzkgn8hKu6505ZzHmkcs)JIpGjeIqqViXkW7VWQp3Vf9Gw3kawzrpwxon6Clm6SR3n4eiyXOQAuJqjlrbiyviKzTat2p502G3jTHtDJ6wegnmH81VBNT3j6B7UpRW0DsP8OToCzghZlcJPeogMcOqGcS1qsAkJVObMdCWsDTyGr9MnP4C)iBbGa(jiOQiZPA4SIYssRorbOwWP24erPx7aHVYc9sfpsL3m7QrLXkwCmvIm3CeRebuzgs7hiXGBPpqsFkEpIVX2BXBUdbNbT4Kf8Y)mWh1n7pWpn7)A0jG6uqAqWq5T0qYABHnWye8ffAOEjiD9BHGPijXaZbnYcFb(DmjJ)V)N)lyLhj4dz6RBO)BDOGq8ImYO1JRW5TFsNqLBMnU9(6kcuEehkkCBv5c)ZbghTHLS7WrvPLNs14coqTHh89qf3scQ3IeaP1RJmaD3iJyirPh2LGpAs7UkW3ISU2d7tuhttdfw4FhjG)(Bb3iWnx2bGLn1sodF(beGXbGedHxrKeOGqFM5dKKuMeYKn2gk(6uZVcOMlpjp7b5nfy)k2dYvnA4fJm62h4lyG)vAe6sahQqwf7x)RV)6EK))iJfUAEmlfqTZJP2whGKnnvTLpUPowgT)lytpq)gbqZH1tuyr8FVgRNTas4r(NTIOz7rnuJmf1JPPjduXc9mJ2VpXBoOFrO)szHOxEdqNMHGU7nynihoIbgr86(C8MSPc4LrmpcuNyoean940qPivaTqvjUp8vTK0qk2Y62yX6TLhmL4l6fjMwq7aUgG(aFseRvXI(vR6iH3m6KMLq(rYcwyZUeoVOKIGScs6irrL9McniGDDOaTtZsS1hG4f0PptwVTUMQcq0XsqPaPbq(eQrhbw8KqHigBjzyR3VKvEwzTkhDg)8I0fvkYQ5hKP1cEFkelKgiYacwOiPg6amYWiPGJP8SV5yYxUCAze9N(fWnvEfho6oXw2HkiRldUydDyTco27VLqb2UUOzSpExFQknXuz2ZeoFKssf82r0PJoCxL3r1fDdQ4iIZwL6CQfkAnqBS8w0wmAzyMucKLydkzP9cZiqJAqkpPgJxeHhI(TA6Cf6)w7dlX))I5Xxd(nrAHggWGNMMfhRg0uDhyjgdYKGdfQqbGdvF6vh6qNxDbQ(dazpTWlIrF3SXt3SPBUcxhiCQabvE73Xx568irYbPOkVMBXTwTH6eMszS0IR5vyElaHlriceF4ROAWe8Z9)K2(sMR6b9neHLe0lrec1IJsLmH0uRfaMXaMfVzfdizKaDOP9))MP))pbSFQFDac8yHlRVBcFDLulcY0VMgd9JBIYf7mY20hCYvc9TgxFHyU3Ee5(J)1cwPQLMutYirynlQ4i1LB14nmlXZscOsuWiRnes)us59IVS1CcGh66qY0qJkUoqpyROWVnpbhzb0ed8RVyM9rrLD3376a3dakGWiUohUJWC)3nl3)IC)nBW(noqNHf7gKSrjDDkB)0o(djl1U8r1iRRgWwTu9gNYX3)5GNq)NvkFRopr95cJBT45vTEwxhHDDzVo8a7nEUb8sJRoO6DQIV)06sPw7PTeZRQVTMTQ2CNA0wMtYI1DbhkpH2d5OL3(BzSn7BMnh14ASGzp7m5Qy06cA0Vzu5(BY3zJdx0qgyktzC()Rszo(PjTFeyFT8N7FsU)PqGdvXCFeGATa7WnQVsKnVZUWzMx8fyRg9uZTDcdi0w22V5PsTnPPttUYKMSJjvSsvde24XRhzx)fy91DNGtBoIsdTHvTZORo4CREUgA1wYHU5G6EwqLaGUYrM0fyUFSFX8EY9)UEE1EZdA9MN1nzBd38Z)y0q33Rpefo6v6HbVP(90M1fk730RSRnCkBG5Qr9uOOHkCSJfdf(v7RI7(hdwpzfWHoEuJsvnCwnkPnE8Xv6B8KNwTVY6g7TBOMj71MctBuy5J2txnhEWqDvd7iPP3QOnNLsxeX12YH5H7EqtdoWGM2F9YU11A6snfCVfUAtr)Qck6DVxQn1O6UPg2e8o0vsT59z2Xn8npnQ9xiQVRsvQv7zOrTuXdmuQJOaqVJLPv63UOKVLbu9CmDQJDWu7N(Unm6nJm5nDYQ3Jd4zEIv7NY)jaVngYHgtKXgRLj0AB7KkSVPHn4PmnSUkU0ctIJCItTb7NuQ9LtRmODNMv7cY9oFSQsvhf0z6ONqVVDm5Q2WQNHXMvvdDVKXDpsQAa)TJXQLo(BFWzvvV7ud78gAfTqwnzkR)F8u7doeTAhwB7jj8mpfoBFhBV07)7A7OZ))GS)onEIfOV44B8Y(x3)Zd]])
