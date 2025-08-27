-- DeathKnightBlood.lua
-- Updated August 19, 2025

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'DEATHKNIGHT' then return end

local addon, ns = ...
local Hekili = _G[addon]
local class, state = Hekili.Class, Hekili.State

-- Safe local references to WoW API (helps static analyzers and emulation)
local GetRuneCooldown = rawget(_G, "GetRuneCooldown") or function() return 0, 10, true end
local GetRuneType = rawget(_G, "GetRuneType") or function() return 1 end

local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local strformat = string.format

local spec = Hekili:NewSpecialization(250, true) -- Blood spec ID for MoP

spec.name = "Blood"
spec.role = "TANK"
spec.primaryStat = 1 -- Strength

-- Local shim for resource changes to avoid global gain/spend errors and normalize names.
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

-- Local aliases for core state helpers and tables (improves static checks and readability).
local applyBuff, removeBuff, applyDebuff, removeDebuff = state.applyBuff, state.removeBuff, state.applyDebuff,
    state.removeDebuff
local removeDebuffStack = state.removeDebuffStack
local summonPet, dismissPet, setDistance, interrupt = state.summonPet, state.dismissPet, state.setDistance,
    state.interrupt
local buff, debuff, cooldown, active_dot, pet, totem, action = state.buff, state.debuff, state.cooldown, state
    .active_dot, state.pet, state.totem, state.action

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
            -- runes.time_to_1 .. runes.time_to_6
            local idx = tostring(k):match("time_to_(%d)")
            if idx then
                local i = tonumber(idx)
                local e = t.expiry[i] or 0
                return math.max(0, e - state.query_time)
            end
            if k == "blood" then return buildTypeCounter({ 1, 2 }, 1) end
            if k == "frost" then return buildTypeCounter({ 5, 6 }, 2) end
            if k == "unholy" then return buildTypeCounter({ 3, 4 }, 3) end
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

    -- Keep expiry fresh when we reset the simulation step
    spec:RegisterHook("reset_precast", function()
        if state.runes and state.runes.reset then state.runes.reset() end
    end)
end

-- Register resources
spec:RegisterResource(6) -- RunicPower = 6 in MoP

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

-- Ensure death_knight namespace exists early to avoid unknown key errors in emulation.
if not state.death_knight then state.death_knight = { runeforge = {} } end
if not state.death_knight.runeforge then state.death_knight.runeforge = {} end

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

-- Keep runeforge state fresh using classic-safe events.
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

-- Provide rune_regeneration (mirrors Unholy) representing rune deficit relative to maximum.
spec:RegisterStateExpr("rune_regeneration", function()
    local total = 0
    if state.blood_runes and state.blood_runes.current then total = total + state.blood_runes.current end
    if state.frost_runes and state.frost_runes.current then total = total + state.frost_runes.current end
    if state.unholy_runes and state.unholy_runes.current then total = total + state.unholy_runes.current end
    if state.death_runes and state.death_runes.count then total = total + state.death_runes.count end
    return 6 - total
end)

-- MoP Death Rune conversion tracking
spec:RegisterStateExpr("death_rune_conversion_available", function()
    local br = state.blood_runes and state.blood_runes.current or 0
    local fr = state.frost_runes and state.frost_runes.current or 0
    local ur = state.unholy_runes and state.unholy_runes.current or 0
    return br > 0 or fr > 0 or ur > 0
end)

-- Unify with Unholy: provide 'rune' expression for total ready runes.
spec:RegisterStateExpr("rune", function()
    local total = 0
    for i = 1, 6 do
        local _, _, ready = GetRuneCooldown(i)
        if ready then total = total + 1 end
    end
    return total
end)

-- Ensure the death_runes state is initialized during engine reset so downstream expressions are safe.
spec:RegisterHook("reset_precast", function()
    if state.death_runes and state.death_runes.reset then
        state.death_runes.reset()
    end
end)

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

-- Talents
spec:RegisterTalents({
    -- Tier 1 (Level 56)
    roiling_blood      = { 1, 1, 108170 }, -- Your Blood Boil ability now also triggers Pestilence if it strikes a diseased target.
    plague_leech       = { 1, 2, 123693 }, -- Extract diseases from an enemy target, consuming up to 2 diseases on the target to gain 1 Rune of each type that was removed.
    unholy_blight      = { 1, 3, 115989 }, -- Causes you to spread your diseases to all enemy targets within 10 yards.

    -- Tier 2 (Level 57)
    lichborne          = { 2, 1, 49039 },  -- Draw upon unholy energy to become undead for 10 sec. While undead, you are immune to Charm, Fear, and Sleep effects.
    anti_magic_zone    = { 2, 2, 51052 },  -- Places a large, stationary Anti-Magic Zone that reduces spell damage taken by party or raid members by 40%. The Anti-Magic Zone lasts for 30 sec or until it absorbs a massive amount of spell damage.
    purgatory          = { 2, 3, 114556 }, -- An unholy pact that prevents fatal damage, instead absorbing incoming healing equal to the damage that would have been fatal for 3 sec.

    -- Tier 3 (Level 58)
    deaths_advance     = { 3, 1, 96268 },  -- For 8 sec, you are immune to movement impairing effects and your movement speed is increased by 50%.
    chilblains         = { 3, 2, 50041 },  -- Victims of your Chains of Ice take 5% increased damage from your abilities for 8 sec.
    asphyxiate         = { 3, 3, 108194 }, -- Lifts the enemy target off the ground, crushing their throat and stunning them for 5 sec.

    -- Tier 4 (Level 60)
    death_pact         = { 4, 1, 48743 },  -- Drains 50% of your summoned minion's health to heal you for 25% of your maximum health.
    death_siphon       = { 4, 2, 108196 }, -- Deals Shadow damage to the target and heals you for 150% of the damage dealt.
    conversion         = { 4, 3, 119975 }, -- Continuously converts 2% of your maximum health per second into 20% of maximum health as healing.

    -- Tier 5 (Level 75)
    blood_tap          = { 5, 1, 45529 }, -- Consume 5 charges from your Blood Charges to immediately activate a random depleted rune.
    runic_empowerment  = { 5, 2, 81229 }, -- When you use a rune, you have a 45% chance to immediately regenerate that rune.
    runic_corruption   = { 5, 3, 51462 }, -- When you hit with a Death Coil, Frost Strike, or Rune Strike, you have a 45% chance to regenerate a rune.

    -- Tier 6 (Level 90)
    gorefiends_grasp   = { 6, 1, 108199 }, -- Shadowy tendrils coil around all enemies within 20 yards of a hostile target, pulling them to the target's location.
    remorseless_winter = { 6, 2, 108200 }, -- Surrounds the Death Knight with a swirling blizzard that grows over 8 sec, slowing enemies by up to 50% and reducing their melee and ranged attack speed by up to 20%.
    desecrated_ground  = { 6, 3, 108201 }, -- Corrupts the ground beneath you, causing all nearby enemies to deal 10% less damage for 30 sec.
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

spec:RegisterGear({
    -- Mists of Pandaria Tier Sets
    tier16 = {
        items = { 99369, 99370, 99371, 99372, 99373 }, -- Death Knight T16
        auras = {
            death_shroud = {
                id = 144901,
                duration = 30,
                max_stack = 5
            }
        }
    },
    tier15 = {
        items = { 95339, 95340, 95341, 95342, 95343 }, -- Death Knight T15
        auras = {
            unholy_vigor = {
                id = 138547,
                duration = 15,
                max_stack = 1
            }
        }
    },
    tier14 = {
        items = { 85316, 85314, 85318, 85315, 85317 }, -- Death Knight T14 - Plate of the Lost Catacomb - https://www.wowhead.com/mop-classic/item-set=1124/plate-of-the-lost-catacomb
        auras = {
            shadow_clone = {
                id = 123556,
                duration = 8,
                max_stack = 1
            }
        }
    }
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

    horn_of_winter = {
        id = 57330,
        duration = 300,
        max_stack = 1
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

        usable = function() return not pet.alive end,
        handler = function()
            summonPet("ghoul", 60)
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

-- Pets
spec:RegisterPets({
    ghoul = {
        id = 26125,
        spell = "raise_dead",
        duration = 60,
    }
})

spec:RegisterTotems({
    gargoyle = {
        id = 49206,
        duration = 30,
    },
    ghoul = {
        id = 26125,
        duration = 60,
    },
    army_ghoul = {
        id = 24207,
        duration = 40,
    }
})

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
    [[Hekili:9EvyVTTnq0Flbblibl112joXzioalRTRnaTlikB9BsIsIoMWYIcKuXiag63(UJKYwuYYXPBOfOfwINU7DV7oEV6pW)rFVeII6)TH9hoQ)4Hd7n48bNp03t9so13lNepN8e8JmYc4FVnLZtW3(skNKGFSKxiIHt89IkyPQVK5h12JND2fJgd2MtJHxpQVV3mwsc1ylvg7794mMSme)lPm0g0Yq(u45yfJNvgMYKk44PCrz4NPZzPSE(E6xQZb6usrQc(5305enJeLst8V1eablh9IV3KU(tz49cgxWuVugUdJ(9cfpMiva2uZOauI580e(YmaAhReSS5uL8u40S3viPWpOQ4EN47zYcFp4LbmfDH0xbmrdKwzelMgXlYscGKvXufj0gzXxSgug(PklaIs9EYufIPXxj99aRHhyeOsYwahFZe8amSN1ry5fQibLmVrWEGovqLZkdtyskrsHmDjtbp)xw7H6guNOmdHORHa6aksXH6fjn1bmeXtuvVeAuX0P9IW(PG8uYtf0Ec6ccdjYRbOoOmC1kWfoMpvWLQGP0NPIgwJ515DKxr8mAGCgJMM0i1(yMSqaCZTGfLHEAtmzqrEDqBW6g30dR4yih1riFMSiNjyXbrMbgNO(p2dH4INIvUYWl6)lqF99qNdWHP8LurDamJssvZ6LhRm57f9XOFrhrNUihDqGOaq8skjhFPBnTat4hj5yNk0exiv8fWGNGdO6ysHaMcV6Ibxo4KELHpqHcumTQSdL5YqOUNwgI8sziE1aWAGFEbUmaFldOOQjxzp7S5Vo59AaPi5NYMorZPlzPPb8PbGpdYOXcEohgP7va46JMKacVgRFxNgMwnGEmCfbhb(aLGWYdM(MdgMXvycje0mvkmmJtRidTl6Cu)YWJkdp44J1DyMHLb63vKnJJUr)MtmnLTTkXGbhJC(Y2wDcwbVSJkO2YaPoLAu6AKUlNrZ(TYWHWvbgqH9pWt)Tn6iLl11RKxoDD3fsF2NS9Gvn)lysjl7P6SvTSDyloX8MUiutlIDm3o7aJwqMpUJmx3IS1eh6dWzM7nDfjflYnzpwIZZbVudYc02aBdecZlhHb9QDTA4tWnvrWMNwDufs9gWTwBaNoOFxPcbUWmamV5fapGhOdtIPH(dKSyG0B1RlTTZOhF2Pd(anVMy(U6d6w6DqZTGo8lmc29fciGMviu2XRioYf2UeB3ebV009kYMDaJnDarMVt3POXvx78mTirCwAdKzJ8TWjMlR(dbBHe)HxmCDdktaV2Q111XgZcKgRQ4LUw(b4xO2EJ3NXJCN42BAPv(3CjLtK(tAgvGxS(W9Mo8TpxG(P5Mhh)8vyZOIG3i)zUiZOJ67WRWPbd8zjP1APNbwHxdVuBd4FfOXtqJ5lIiBvtLBvdmvsZIPTxz6CSzR5Bqpg9D3xKMUd9y7seLZw)9yvENngUCttx5E8AVPlZvUiNB3lV27kdhd6yK4jwPYdUY3BjrKbJ0GaUValafkAI(owhvW9kVdCEHcInUpiEoIlyiykdlQhUlbS3DynI9UDBA1(71DcWgC3kAh2SHD3UbUC22TXWzL39AG8WAc3Fft1N)JjGFngbKTwcV1JVUy86FDBT9OyiuI(ntgFL1L)3LCxpKv661b6vLFF9KbRw9QYUbRSyDxAORJIADfiqoO1GiAU2J7P(46o3vVn6)n7JUEYf9R41FcYEX4SbyVbfVw68)zzV1zPT8)lOjvnQ)rhuxGJ2wza5zcl14onk)5icTo2Rdke06EYBMmC1kJAu9pDZKvRoyBQp30lSt5K1dETLVySRPU8Mjdgw1DTBbKDLmvW5httOdkxR3CZa22vi2ECy)f91IxSD315(X9pst6qrXgQ9ufNZfgRveUE4PTMoR7FRs0QhN6k)0rYf5T0K1rJH189t6Lt8Bl(Y)F)d]])
