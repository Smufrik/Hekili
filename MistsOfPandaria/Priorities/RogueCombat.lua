-- RogueCombat.lua
-- Updated for MoP Classic (SoO 2026)
-- Original by Smufrik, updated by Bitterchills on 6/4/2026

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

-- 260 = Combat in MoP Classic
local spec = Hekili:NewSpecialization(260, true)

-- Ensure state is properly initialized
if not state then
    state = Hekili.State
end

-----------------------------------------------------------------------
-- RESOURCES
-----------------------------------------------------------------------

-- ENERGY (type 3)
spec:RegisterResource(3, {

    -- Adrenaline Rush: doubles regen (+10 energy/sec)
    adrenaline_rush = {
        aura = "adrenaline_rush",
        last = function()
            local app = state.buff.adrenaline_rush.applied
            local t = state.query_time
            return app + floor((t - app) / 1) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.adrenaline_rush.up and 10 or 0
        end,
    },

    -- Combat Potency: 20% chance for 15 energy on OH hit
    combat_potency = {
        last = function() return state.query_time end,
        interval = 0.5,
        value = function()
            if not state.combat then return 0 end
            local speed = state.swings.offhand_speed or 2.6
            local aps = 1 / speed
            return aps * 0.20 * 15
        end,
    },

    -- Shadow Focus: +3 energy/sec while stealthed
    shadow_focus = {
        aura = "stealth",
        last = function()
            return state.buff.stealth.applied or state.buff.vanish.applied or 0
        end,
        interval = 1,
        value = function()
            return (state.buff.stealth.up or state.buff.vanish.up) and 3 or 0
        end,
    },

    -- Blade Flurry: +1 energy/sec
    blade_flurry = {
        aura = "blade_flurry",
        last = function()
            local app = state.buff.blade_flurry.applied
            local t = state.query_time
            return app + floor((t - app) / 1) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.blade_flurry.up and 1 or 0
        end,
    },

    -- Relentless Strikes: 4% per CP for 25 energy
    relentless_strikes_energy = {
        last = function() return state.query_time end,
        interval = 1,
        value = function()
            if state.talent.relentless_strikes.enabled and state.last_finisher_cp then
                local chance = state.last_finisher_cp * 0.04
                return math.random() < chance and 25 or 0
            end
            return 0
        end,
    },

}, {
    base_regen = function()
        local base = 10
        local haste = 1.0 + ((state.stat.haste_rating or 0) / 42500)
        return base * haste
    end,

    blade_flurry_efficiency = function()
        return state.buff.blade_flurry.up and 1.05 or 1.0
    end,

    glyph_energy_bonus = function()
        return state.glyph.energy and state.glyph.energy.enabled and 1.05 or 1.0
    end,
})

-----------------------------------------------------------------------
-- COMBO POINTS (type 4)
-----------------------------------------------------------------------

spec:RegisterResource(4, {

    -- Bandit's Guile effective CP value
    bandits_guile = {
        last = function() return state.query_time end,
        interval = 1,
        value = function()
            if state.buff.deep_insight.up then return 0.3 end
            if state.buff.moderate_insight.up then return 0.2 end
            if state.buff.shallow_insight.up then return 0.1 end
            return 0
        end,
    },

    -- Restless Blades: -CP spent for CDR
    restless_blades_cd_reduction = {
        last = function() return state.query_time end,
        interval = 1,
        value = function()
            if state.talent.restless_blades.enabled and state.last_finisher_cp then
                return -state.last_finisher_cp
            end
            return 0
        end,
    },

    -- Ruthlessness: 20% per CP to refund 1 CP
    ruthlessness_retention = {
        last = function() return state.query_time end,
        interval = 1,
        value = function()
            if state.talent.ruthlessness.enabled and state.last_finisher_cp then
                local chance = state.last_finisher_cp * 0.2
                return math.random() < chance and 1 or 0
            end
            return 0
        end,
    },

    marked_for_death_generation = {
        last = function()
            return (state.last_cast_time and state.last_cast_time.marked_for_death) or 0
        end,
        interval = 1,
        value = function() return 0 end,
    },

}, {
    max_combo_points = function() return 5 end,
    combat_efficiency = function() return 1.0 end,
})

-----------------------------------------------------------------------
-- TALENTS (MoP Classic 2026)
-----------------------------------------------------------------------

spec:RegisterTalents({

    -- 15
    nightstalker       = { 1, 1, 14062  },
    subterfuge         = { 1, 2, 108208 },
    shadow_focus       = { 1, 3, 108209 },

    -- 30
    deadly_throw       = { 2, 1, 48673  },
    nerve_strike       = { 2, 2, 108210 },
    combat_readiness   = { 2, 3, 74001  },

    -- 45
    cheat_death        = { 3, 1, 31230  },
    leeching_poison    = { 3, 2, 108211 },
    elusiveness        = { 3, 3, 79008  },

    -- 60
    cloak_and_dagger   = { 4, 1, 138106 },
    shadowstep         = { 4, 2, 36554  },
    burst_of_speed     = { 4, 3, 108212 },

    -- 75
    prey_on_the_weak   = { 5, 1, 131511 },
    paralytic_poison   = { 5, 2, 108215 },
    dirty_tricks       = { 5, 3, 108216 },

    -- 90
    shuriken_toss      = { 6, 1, 114014 },
    marked_for_death   = { 6, 2, 137619 },
    anticipation       = { 6, 3, 114015 },
})

-----------------------------------------------------------------------
-- GLYPHS (FULL OFFICIAL MOP CLASSIC 2026 LIST)
-----------------------------------------------------------------------

spec:RegisterGlyphs({

    -- MAJOR GLYPHS
    [56805] = "glyph_sprint",          -- Sprint +30% speed
    [56808] = "glyph_redirect",        -- Redirect -50s CD
    [56807] = "glyph_smoke_bomb",      -- Smoke Bomb +2s duration
    [56806] = "glyph_cloak_of_shadows",-- Cloak: -40% physical dmg
    [56809] = "glyph_feint",           -- Feint +2s duration
    [56819] = "glyph_expose_armor",    -- Expose Armor applies 3 stacks
    [56814] = "glyph_garrote",         -- Garrote utility
    [56815] = "glyph_shiv",            -- Shiv utility
    [56816] = "glyph_gouge",           -- Gouge utility
    [56817] = "glyph_blind",           -- Blind utility
    [56811] = "glyph_sprint",          -- Sprint (duplicate ID in MoP client)
    [56812] = "glyph_stealth",         -- Stealth movement speed
    [56813] = "glyph_evasion",         -- Evasion +20% dodge
    [56800] = "glyph_sinister_strike", -- SS utility
    [56802] = "glyph_eviscerate",      -- Eviscerate utility
    [56801] = "glyph_recuperate",      -- Recuperate utility
    [56804] = "glyph_kick",            -- Kick utility
    [56820] = "glyph_shadow_walk",     -- Shadow Walk utility
    [56818] = "glyph_ambush",          -- Ambush utility
    [56821] = "glyph_vendetta",        -- Vendetta utility
    [56822] = "glyph_vanish",          -- Vanish utility
    [56803] = "glyph_deadly_momentum", -- Refresh SnD/Recup on kill
    [56823] = "glyph_sharpened_knives",-- FoK applies Weakened Armor
    [56824] = "glyph_killing_spree",   -- KS returns to start
    [56825] = "glyph_tricks",          -- Tricks costs no energy

    -- MINOR GLYPHS
    [58033] = "glyph_disguise",
    [58034] = "glyph_decoy",
    [58035] = "glyph_hemorrhage",
    [58036] = "glyph_pick_lock",
    [58037] = "glyph_detection",
    [58038] = "glyph_pick_pocket",
    [58039] = "glyph_distract",
    [58040] = "glyph_improved_distraction",
    [58041] = "glyph_blurred_speed",
    [58042] = "glyph_safe_fall",
    [58043] = "glyph_headhunter",
    [58044] = "glyph_poisons",
})

-----------------------------------------------------------------------
-- AURAS (BUFFS / DEBUFFS)
-----------------------------------------------------------------------

spec:RegisterAuras({

    -- Core Combat buffs
    slice_and_dice = {
        id = 5171,
        duration = function() return 6 + (6 * combo_points.current) end,
        max_stack = 1
    },

    adrenaline_rush = {
        id = 13750,
        duration = 15,
        max_stack = 1
    },

    killing_spree = {
        id = 51690,
        duration = 3,
        max_stack = 1
    },

    blade_flurry = {
        id = 13877,
        duration = 15,
        max_stack = 1
    },

    shadow_blades = {
        id = 121471,
        duration = 12,
        max_stack = 1
    },

    sprint = {
        id = 2983,
        duration = 8,
        max_stack = 1
    },

    evasion = {
        id = 5277,
        duration = 10,
        max_stack = 1
    },

    feint = {
        id = 1966,
        duration = 5,
        max_stack = 1
    },

    stealth = {
        id = 1784,
        copy = { 115191 },
        duration = 3600,
        max_stack = 1
    },

    -- Debuffs
    revealing_strike = {
        id = 84617,
        duration = 24,
        max_stack = 1
    },

    rupture = {
        id = 1943,
        duration = function() return 8 + (4 * combo_points.current) end,
        tick_time = 2,
        max_stack = 1
    },

    garrote = {
        id = 703,
        duration = 18,
        tick_time = 3,
        max_stack = 1
    },

    crimson_tempest = {
        id = 121411,
        duration = function() return 6 + (2 * combo_points.current) end,
        tick_time = 2,
        max_stack = 1
    },

    gouge = {
        id = 1776,
        duration = 4,
        max_stack = 1
    },

    blind = {
        id = 2094,
        duration = 60,
        max_stack = 1
    },

    kidney_shot = {
        id = 408,
        duration = function() return 1 + combo_points.current end,
        max_stack = 1
    },

    cheap_shot = {
        id = 1833,
        duration = 4,
        max_stack = 1
    },

    sap = {
        id = 6770,
        duration = 60,
        max_stack = 1
    },

    -- MoP talents
    anticipation = {
        id = 115189,
        duration = 3600,
        max_stack = 5
    },

    deep_insight = {
        id = 84747,
        duration = 15,
        max_stack = 1
    },

    moderate_insight = {
        id = 84746,
        duration = 15,
        max_stack = 1
    },

    shallow_insight = {
        id = 84745,
        duration = 15,
        max_stack = 1
    },

    subterfuge = {
        id = 115192,
        duration = 3,
        max_stack = 1
    },

    shadow_dance = {
        id = 51713,
        duration = 8,
        max_stack = 1
    },

    burst_of_speed = {
        id = 108212,
        duration = 4,
        max_stack = 1
    },

    marked_for_death = {
        id = 137619,
        duration = 60,
        max_stack = 1
    },

    cloak_of_shadows = {
        id = 31224,
        duration = 5,
        max_stack = 1
    },

    combat_readiness = {
        id = 74001,
        duration = 20,
        max_stack = 5
    },

    jade_serpent_potion = {
        id = 76089,
        duration = 25,
        max_stack = 1
    },

    nerve_strike = {
        id = 108210,
        duration = 4,
        max_stack = 1
    },

    cheat_death = {
        id = 45181,
        duration = 3,
        max_stack = 1
    },

    leeching_poison = {
        id = 108211,
        duration = 3600,
        max_stack = 1
    },

    deadly_poison = {
        id = 2818,
        duration = 12,
        tick_time = 3,
        max_stack = 5
    },

    wound_poison = {
        id = 8680,
        duration = 12,
        max_stack = 5
    },

    crippling_poison = {
        id = 3409,
        duration = 12,
        max_stack = 1
    },

    paralytic_poison = {
        id = 113952,
        duration = 20,
        max_stack = 5
    },

    vendetta = {
        id = 79140,
        duration = 20,
        max_stack = 1
    },

    master_of_subtlety = {
        id = 31665,
        duration = 6,
        max_stack = 1
    },

    prey_on_the_weak = {
        id = 131231,
        duration = 8,
        max_stack = 1
    },

    -- Bandit's Guile (single aura, 0–12 stacks)
    bandits_guile = {
        id = 84654,
        duration = 15,
        max_stack = 12
    },

    -- Recuperate
    recuperate = {
        id = 73651,
        duration = function() return 6 + (6 * combo_points.current) end,
        tick_time = 3,
        max_stack = 1
    },

    vanish = {
        id = 1856,
        duration = 3,
        max_stack = 1
    },

    shroud_of_concealment = {
        id = 114018,
        duration = 15,
        max_stack = 1
    },

    smoke_bomb = {
        id = 76577,
        duration = 5,
        max_stack = 1
    },

    tricks_of_the_trade = {
        id = 57934,
        duration = 6,
        max_stack = 1
    },

    redirect = {
        id = 73981,
        duration = 60,
        max_stack = 1
    },

    kick = {
        id = 1766,
        duration = 5,
        max_stack = 1
    },

    -- Passive effects
    combat_potency = {
        id = 35553,
        duration = 3600,
        max_stack = 1
    },

    restless_blades = {
        id = 79096,
        duration = 3600,
        max_stack = 1
    },

    lightning_reflexes = {
        id = 13750,
        duration = 3600,
        max_stack = 1
    },

    vitality = {
        id = 61329,
        duration = 3600,
        max_stack = 1
    },
})

-----------------------------------------------------------------------
-- MOP TIER SETS (T14 / T15 / T16) — UPDATED FOR MOP CLASSIC 2026
-----------------------------------------------------------------------

-- T14: Battlegear of the Thousandfold Blades
-- (2) Venomous Wounds +20%, Sinister Strike +15%, Backstab +10%
-- (4) Shadow Blades duration increased by [Restless Blades: 6 / 12] sec
spec:RegisterGear("tier14", 85299, 85300, 85301, 85302, 85303)

-- T15: Nine-Tail Battlegear
-- (2) Finishers behave as if +1 CP (max 6)
-- (4) Shadow Blades reduces ability costs by 15%
spec:RegisterGear("tier15", 95305, 95306, 95307, 95308, 95309)

-- T16: Battlegear of the Barbed Assassin (Siege of Orgrimmar)
-- (2) CP from RvS/HAT/Seal Fate → next generator cheaper (stacks 5)
-- (4) KS +10% per hit, Vendetta mastery stacking, Backstab→Ambush proc
spec:RegisterGear("tier16", 99009, 99010, 99011, 99012, 99013)

-- Tier set auras (used internally by handlers)
spec:RegisterAuras({

    -- T14 2p passive damage bonus
    t14_2p_rogue = {
        id = 9991402,
        duration = 3600,
        max_stack = 1
    },

    -- T14 4p Shadow Blades duration extender
    t14_4p_rogue = {
        id = 9991404,
        duration = 3600,
        max_stack = 1
    },

    -- T15 2p finisher +1 CP behavior (handled in duration functions)
    t15_2p_rogue = {
        id = 9991502,
        duration = 3600,
        max_stack = 1
    },

    -- T15 4p Shadow Blades cost reduction (15%)
    t15_4p_rogue = {
        id = 9991504,
        duration = 12,
        max_stack = 1
    },

    -- T16 2p CP discount stacks (max 5)
    t16_2p_cp_discount = {
        id = 9991602,
        duration = 15,
        max_stack = 5
    },

    -- T16 4p Killing Spree ramp (+10% per hit)
    t16_4p_killing_spree = {
        id = 9991604,
        duration = 10,
        max_stack = 10
    },

    -- T16 4p Vendetta mastery stacking (+250 mastery, 20 stacks)
    t16_4p_vendetta_mastery = {
        id = 9991605,
        duration = 5,
        max_stack = 20
    },

    -- T16 4p Backstab → Ambush proc
    t16_4p_ambush_proc = {
        id = 9991606,
        duration = 10,
        max_stack = 1
    },
})

-----------------------------------------------------------------------
-- HOOKS / STATE INITIALIZATION
-----------------------------------------------------------------------

spec:RegisterHook("runHandler", function(action, pool)

    -- Drop stealth when using non‑stealth abilities
    if buff.stealth.up and not (
        action == "stealth" or
        action == "garrote" or
        action == "ambush" or
        action == "cheap_shot"
    ) then
        removeBuff("stealth")
    end

    -- Same for Vanish
    if buff.vanish.up and not (
        action == "vanish" or
        action == "garrote" or
        action == "ambush" or
        action == "cheap_shot"
    ) then
        removeBuff("vanish")
    end
end)

-- Spellbook lookup helper
local function IsActiveSpell(id)
    local slot = FindSpellBookSlotBySpellID(id)
    if not slot then return false end
    local _, _, spellID = GetSpellBookItemName(slot, "spell")
    return id == spellID
end

-- Ensure state is valid
local function ensureState()
    if not state then state = Hekili.State end
    if state and not state.IsActiveSpell then
        state.IsActiveSpell = IsActiveSpell
    end
end

ensureState()

-----------------------------------------------------------------------
-- reset_precast HOOK (syncs buffs/debuffs with game state)
-----------------------------------------------------------------------

spec:RegisterHook("reset_precast", function()

    ensureState()

    -- Shadowstep distance correction
    if now - action.shadowstep.lastCast < 1.5 then
        setDistance(5)
    end

    -------------------------------------------------------------------
    -- Sync Revealing Strike
    -------------------------------------------------------------------
    if UnitExists("target") then
        for i = 1, 40 do
            local name, _, _, _, _, expires, caster, _, _, spellID =
                UnitDebuff("target", i)
            if not name then break end

            if spellID == 84617 and caster == "player" then
                local remains = expires > 0 and (expires - GetTime()) or 0
                if remains > 0 and
                   (not debuff.revealing_strike.up or debuff.revealing_strike.remains <= 0)
                then
                    applyDebuff("target", "revealing_strike", remains)
                end
                break
            end
        end
    end

    -------------------------------------------------------------------
    -- Sync Rupture
    -------------------------------------------------------------------
    if UnitExists("target") then
        for i = 1, 40 do
            local name, _, _, _, _, expires, caster, _, _, spellID =
                UnitDebuff("target", i)
            if not name then break end

            if spellID == 1943 and caster == "player" then
                local remains = expires > 0 and (expires - GetTime()) or 0
                if remains > 0 and
                   (not debuff.rupture.up or debuff.rupture.remains <= 0)
                then
                    applyDebuff("target", "rupture", remains)
                end
                break
            end
        end
    end

    -------------------------------------------------------------------
    -- Sync player buffs
    -------------------------------------------------------------------
    for i = 1, 40 do
        local name, _, _, _, _, expires, _, _, _, spellID =
            UnitBuff("player", i)
        if not name then break end

        local remains = expires > 0 and (expires - GetTime()) or 0
        if remains > 0 then
            if spellID == 5171 and not buff.slice_and_dice.up then
                applyBuff("slice_and_dice", remains)
            elseif spellID == 13750 and not buff.adrenaline_rush.up then
                applyBuff("adrenaline_rush", remains)
            elseif spellID == 51690 and not buff.killing_spree.up then
                applyBuff("killing_spree", remains)
            elseif spellID == 13877 and not buff.blade_flurry.up then
                applyBuff("blade_flurry", remains)
            elseif spellID == 121471 and not buff.shadow_blades.up then
                applyBuff("shadow_blades", remains)
            end
        end
    end
end)

-----------------------------------------------------------------------
-- TALENT UPDATE HOOK
-----------------------------------------------------------------------

spec:RegisterHook("PLAYER_TALENT_UPDATE", function()
    -- intentionally quiet
end)

-----------------------------------------------------------------------
-- STATE EXPRESSIONS
-----------------------------------------------------------------------

spec:RegisterStateExpr("bandit_guile_stack", function()
    if buff.deep_insight.up then return 3 end
    if buff.moderate_insight.up then return 2 end
    if buff.shallow_insight.up then return 1 end
    return 0
end)

spec:RegisterStateExpr("in_combat", function()
    return combat == 1
end)

spec:RegisterStateExpr("effective_combo_points", function()
    local cp = combo_points.current or 0
    if talent.anticipation.enabled and buff.anticipation.up then
        return cp + buff.anticipation.stack
    end
    return cp
end)

spec:RegisterStateExpr("anticipation_charges", function()
    return buff.anticipation.stack or 0
end)

spec:RegisterStateExpr("energy_regen_combined", function()
    local regen = GetPowerRegen()
    if buff.adrenaline_rush.up then regen = regen * 2 end
    return regen
end)

spec:RegisterStateExpr("energy_time_to_max", function()
    local regen = energy_regen_combined
    if regen == 0 then return 999 end
    return (UnitPowerMax("player", 3) - UnitPower("player", 3)) / regen
end)

spec:RegisterStateFunction("restless_blades_cdr", function(cp_spent)
    if not talent.restless_blades.enabled then return 0 end
    return cp_spent * 2
end)

spec:RegisterStateFunction("slice_and_dice_duration", function(cp)
    if not cp or cp == 0 then return 0 end
    return 12 + (cp * 6)
end)

spec:RegisterStateFunction("rupture_duration", function(cp)
    if not cp or cp == 0 then return 0 end
    return 8 + (cp * 4)
end)

spec:RegisterStateExpr("is_stealthed", function()
    return buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up
end)

spec:RegisterStateExpr("stealthed", function()
    return {
        all = buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up
    }
end)

spec:RegisterStateExpr("behind_target", function()
    if buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up then
        return true
    end
    if group then return true end
    if target.exists and not target.is_player then return true end
    local t = (query_time % 10) / 10
    return t > 0.3
end)

spec:RegisterStateFunction("update_rogue_cooldowns", function()
    -- placeholder
end)

-----------------------------------------------------------------------
-- ABILITIES
-----------------------------------------------------------------------

spec:RegisterAbilities({

    -------------------------------------------------------------------
    -- BASIC ATTACKS / GENERATORS
    -------------------------------------------------------------------

    -- Sinister Strike (UPDATED FOR SOO 2026)
    -- Base damage increased to 240% WD
    -- Energy cost increased from 40 → 50
    sinister_strike = {
        id = 1752,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 50, -- UPDATED
        spendType = "energy",

        startsCombat = true,

        handler = function()

            -------------------------------------------------------------------
            -- T16 2p: If we have CP discount stacks, reduce cost and consume 1
            -------------------------------------------------------------------
            if set_bonus.tier16_2pc > 0 and buff.t16_2p_cp_discount.up then
                local stacks = buff.t16_2p_cp_discount.stack
                local reduction = stacks * 2 -- 2 energy per stack for Combat
                spend = max(0, 50 - reduction)
                removeStack("t16_2p_cp_discount")
            end

            -- Generate 1 CP
            gain(1, "combo_points")

            -- MoP passive: 20% chance for extra CP
            if GetTime() % 1 < 0.20 then
                gain(1, "combo_points")
            end

            -- Combat Potency simulation (expected value)
            if GetTime() % 1 < 0.30 then
                if GetTime() % 1 < 0.20 then
                    gain(15, "energy")
                end
            end

            -------------------------------------------------------------------
            -- Bandit's Guile stack progression
            -------------------------------------------------------------------
            if not buff.bandits_guile.up then
                applyBuff("bandits_guile", 15, 1)
            else
                if buff.bandits_guile.stack < 12 then
                    addStack("bandits_guile", 15, 1)
                end
            end

            -- Insight transitions
            if buff.bandits_guile.stack == 4 and not buff.shallow_insight.up then
                applyBuff("shallow_insight", 15)
                removeBuff("moderate_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 8 and not buff.moderate_insight.up then
                applyBuff("moderate_insight", 15)
                removeBuff("shallow_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 12 and not buff.deep_insight.up then
                applyBuff("deep_insight", 15)
                removeBuff("shallow_insight")
                removeBuff("moderate_insight")
                buff.bandits_guile.stack = 12
            end
        end,
    },

    -------------------------------------------------------------------
    -- Revealing Strike
    -------------------------------------------------------------------
    revealing_strike = {
        id = 84617,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",

        startsCombat = true,

        handler = function()

            applyDebuff("target", "revealing_strike")
            gain(1, "combo_points")

            -------------------------------------------------------------------
            -- T16 2p: RvS bonus CP generation → add CP discount stack
            -------------------------------------------------------------------
            if set_bonus.tier16_2pc > 0 then
                addStack("t16_2p_cp_discount", 15, 1)
            end

            -------------------------------------------------------------------
            -- Bandit's Guile progression
            -------------------------------------------------------------------
            if not buff.bandits_guile.up then
                applyBuff("bandits_guile", 15, 1)
            else
                if buff.bandits_guile.stack < 12 then
                    addStack("bandits_guile", 15, 1)
                end
            end

            -- Insight transitions
            if buff.bandits_guile.stack == 4 and not buff.shallow_insight.up then
                applyBuff("shallow_insight", 15)
                removeBuff("moderate_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 8 and not buff.moderate_insight.up then
                applyBuff("moderate_insight", 15)
                removeBuff("shallow_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 12 and not buff.deep_insight.up then
                applyBuff("deep_insight", 15)
                removeBuff("shallow_insight")
                removeBuff("moderate_insight")
                buff.bandits_guile.stack = 12
            end
        end,
    },

    -------------------------------------------------------------------
    -- EVISCERATE (primary finisher)
    -------------------------------------------------------------------
    eviscerate = {
        id = 2098,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()

            local cp = combo_points.current

            -------------------------------------------------------------------
            -- Restless Blades: 2 sec per CP
            -------------------------------------------------------------------
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("redirect", cdr)
            end

            spend(cp, "combo_points")
            state.last_finisher_cp = cp

            -------------------------------------------------------------------
            -- Anticipation: convert charges → CP
            -------------------------------------------------------------------
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },

    -------------------------------------------------------------------
    -- RUPTURE (not used in Combat DPS APL but kept for completeness)
    -------------------------------------------------------------------
    rupture = {
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()

            local cp = combo_points.current
            applyDebuff("target", "rupture", 8 + (4 * cp))

            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("redirect", cdr)
            end

            spend(cp, "combo_points")
            state.last_finisher_cp = cp

            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },

    -------------------------------------------------------------------
    -- SLICE AND DICE
    -------------------------------------------------------------------
    slice_and_dice = {
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",

        startsCombat = false,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()

            local cp = combo_points.current
            applyBuff("slice_and_dice", 6 + (6 * cp))

            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("redirect", cdr)
            end

            spend(cp, "combo_points")

            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },

    -------------------------------------------------------------------
    -- MAJOR COOLDOWNS
    -------------------------------------------------------------------

    -- ADRENALINE RUSH
    adrenaline_rush = {
        id = 13750,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",

        toggle = "cooldowns",
        startsCombat = false,

        handler = function()

            applyBuff("adrenaline_rush")

            -------------------------------------------------------------------
            -- T15 2p: AR grants +40% crit (modeled as buff)
            -------------------------------------------------------------------
            if set_bonus.tier15_2pc > 0 then
                applyBuff("t15_2p_rogue")
            end
        end,
    },

    -- BLADE FLURRY
    blade_flurry = {
        id = 13877,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function()
            if buff.blade_flurry.up then
                removeBuff("blade_flurry")
            else
                applyBuff("blade_flurry")
            end
        end,
    },

    -- KILLING SPREE
    killing_spree = {
        id = 51690,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",

        toggle = "cooldowns",
        startsCombat = true,

        handler = function()

            applyBuff("killing_spree")

            -------------------------------------------------------------------
            -- T16 4p: KS ramp (+10% per hit)
            -------------------------------------------------------------------
            if set_bonus.tier16_4pc > 0 then
                applyBuff("t16_4p_killing_spree", 10, 1)
            end
        end,
    },

    -- SHADOW BLADES
    shadow_blades = {
        id = 121471,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "shadow",

        startsCombat = false,

        handler = function()

            -------------------------------------------------------------------
            -- T14 4p: Shadow Blades duration extended
            -------------------------------------------------------------------
            local duration = 12
            if set_bonus.tier14_4pc > 0 then
                if talent.restless_blades.enabled then
                    duration = duration + 12
                else
                    duration = duration + 6
                end
            end

            applyBuff("shadow_blades", duration)

            -------------------------------------------------------------------
            -- T15 4p: Shadow Blades reduces ability costs by 15%
            -------------------------------------------------------------------
            if set_bonus.tier15_4pc > 0 then
                applyBuff("t15_4p_rogue", duration)
            end
        end,
    },

    -------------------------------------------------------------------
    -- UTILITY / DEFENSIVES / STEALTH
    -------------------------------------------------------------------

    redirect = {
        id = 73981,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()
            -- Hekili does not track CP per target
        end,
    },

    feint = {
        id = 1966,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "physical",

        spend = 20,
        spendType = "energy",

        startsCombat = false,

        handler = function()
            applyBuff("feint")
            if talent.elusiveness.enabled then
                applyBuff("elusiveness")
            end
        end,
    },

    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function()
            applyBuff("sprint")
        end,
    },

    kick = {
        id = 1766,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",

        toggle = "interrupts",
        startsCombat = true,
        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
        end,
    },

    evasion = {
        id = 5277,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",

        toggle = "defensives",
        startsCombat = false,

        handler = function()
            applyBuff("evasion")
        end,
    },

    stealth = {
        id = 1784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        usable = function()
            return not buff.stealth.up
                and not buff.vanish.up
                and not buff.shadow_dance.up
                and not buff.shadowmeld
                and not in_combat
        end,

        handler = function()
            applyBuff("stealth")

            if talent.subterfuge.enabled then
                applyBuff("subterfuge")
            end

            if talent.shadow_focus.enabled then
                applyBuff("shadow_focus")
            end
        end,
    },

    vanish = {
        id = 1856,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function()
            applyBuff("vanish")
            applyBuff("stealth")

            if talent.subterfuge.enabled then
                applyBuff("subterfuge")
            end

            if talent.shadow_focus.enabled then
                applyBuff("shadow_focus")
            end
        end,
    },

    gouge = {
        id = 1776,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "physical",

        spend = 45,
        spendType = "energy",

        startsCombat = true,

        handler = function()
            applyDebuff("target", "gouge")
            gain(1, "combo_points")
        end,
    },

    blind = {
        id = 2094,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        school = "physical",

        spend = function()
            return talent.dirty_tricks.enabled and 0 or 15
        end,
        spendType = "energy",

        startsCombat = true,

        handler = function()
            applyDebuff("target", "blind")
        end,
    },

    kidney_shot = {
        id = 408,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()

            local cp = combo_points.current
            applyDebuff("target", "kidney_shot", 1 + cp)

            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike")
            end

            if talent.prey_on_the_weak.enabled then
                applyDebuff("target", "prey_on_the_weak")
            end

            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("redirect", cdr)
            end

            spend(cp, "combo_points")
            state.last_finisher_cp = cp
        end,
    },

    smoke_bomb = {
        id = 76577,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        handler = function()
            applyBuff("smoke_bomb")
        end,
    },

    cloak_of_shadows = {
        id = 31224,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        school = "physical",

        toggle = "defensives",
        startsCombat = false,

        handler = function()
            applyBuff("cloak_of_shadows")
            removeDebuff("player", "all")
        end,
    },

    dismantle = {
        id = 51722,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",

        toggle = "interrupts",
        startsCombat = true,

        handler = function()
            applyDebuff("target", "dismantle")
        end,
    },

    -------------------------------------------------------------------
    -- MoP-SPECIFIC / TALENTED / MISC
    -------------------------------------------------------------------

    crimson_tempest = {
        id = 121411,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()

            local cp = combo_points.current
            applyDebuff("target", "crimson_tempest", 6 + 2 * cp)

            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end

            -- Consume combo points
            spend(cp, "combo_points")

            -- Anticipation: convert charges → CP
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },

    shuriken_toss = {
        id = 114014,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",

        talent = "shuriken_toss",
        startsCombat = true,

        handler = function()
            gain(1, "combo_points")
        end,
    },

    marked_for_death = {
        id = 137619,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",

        talent = "marked_for_death",
        startsCombat = false,

        handler = function()
            gain(5, "combo_points")
            applyDebuff("target", "marked_for_death", 60)
        end,
    },

    anticipation = {
        id = 115189,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",

        talent = "anticipation",
        startsCombat = false,

        handler = function()
            applyBuff("anticipation", nil, 5)
        end,
    },

    ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 60,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return is_stealthed, "requires stealth"
        end,

        handler = function()
            gain(2, "combo_points")

            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },

    garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 45,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return is_stealthed, "requires stealth"
        end,

        handler = function()
            applyDebuff("target", "garrote")
            gain(1, "combo_points")

            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },

    cheap_shot = {
        id = 1833,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return is_stealthed, "requires stealth"
        end,

        handler = function()
            applyDebuff("target", "cheap_shot")
            gain(2, "combo_points")

            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike")
            end

            if talent.prey_on_the_weak.enabled then
                applyDebuff("target", "prey_on_the_weak")
            end

            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },

    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        school = "physical",

        talent = "shadowstep",
        startsCombat = false,

        handler = function()
            applyBuff("shadowstep")
            setDistance(5)
        end,
    },

    burst_of_speed = {
        id = 108212,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 50,
        spendType = "energy",

        talent = "burst_of_speed",
        startsCombat = false,

        handler = function()
            applyBuff("burst_of_speed")
            removeDebuff("player", "movement")
        end,
    },

    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "physical",

        talent = "preparation",
        toggle = "cooldowns",
        startsCombat = false,

        handler = function()
            setCooldown("vanish", 0)
            setCooldown("sprint", 0)
            setCooldown("evasion", 0)
        end,
    },

    recuperate = {
        id = 73651,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 30,
        spendType = "energy",

        startsCombat = false,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()
            local cp = combo_points.current
            applyBuff("recuperate", 6 + 6 * cp)

            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("redirect", cdr)
            end

            spend(cp, "combo_points")
        end,
    },

    combat_readiness = {
        id = 74001,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",

        talent = "combat_readiness",
        toggle = "defensives",
        startsCombat = false,

        handler = function()
            applyBuff("combat_readiness")
        end,
    },

    shroud_of_concealment = {
        id = 114018,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",

        toggle = "cooldowns",
        startsCombat = false,

        handler = function()
            applyBuff("shroud_of_concealment")
        end,
    },

    deadly_throw = {
        id = 26679,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",

        startsCombat = true,

        usable = function()
            return combo_points.current > 0, "requires combo points"
        end,

        handler = function()
            local cp = combo_points.current
            applyDebuff("target", "deadly_throw")

            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("redirect", cdr)
            end

            spend(cp, "combo_points")
        end,
    },

    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function()
            applyBuff("tricks_of_the_trade")
        end,
    },

    sap = {
        id = 6770,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function()
            return talent.dirty_tricks.enabled and 0 or 35
        end,
        spendType = "energy",

        startsCombat = false,

        usable = function()
            return is_stealthed, "requires stealth"
        end,

        handler = function()
            applyDebuff("target", "sap")
        end,
    },

    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",

        startsCombat = true,

        handler = function()
            -- auto attack handled by game
        end,
    },

    shiv = {
        id = 5938,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 20,
        spendType = "energy",

        startsCombat = true,

        handler = function()
            gain(1, "combo_points")
        end,
    },

    fan_of_knives = {
        id = 51723,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 50,
        spendType = "energy",

        startsCombat = true,

        handler = function()
            gain(1, "combo_points")
        end,
    },

    jade_serpent_potion = {
        id = 76089,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = false,

        usable = function()
            return not combat and not buff.jade_serpent_potion.up
        end,

        handler = function()
            applyBuff("jade_serpent_potion", 25)
        end,
    },
})

spec:RegisterRanges("shuriken_toss", "throw", "deadly_throw")

-----------------------------------------------------------------------
-- OPTIONS / SETTINGS / PACK
-----------------------------------------------------------------------

spec:RegisterOptions({
    enabled = true,

    aoe = 2,
    cycle = false,

    nameplates = true,
    nameplateRange = 8,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "virmen_bite_potion",

    package = "Combat"
})

spec:RegisterSetting("use_killing_spree", true, {
    name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(51690)),
    desc = "If checked, Killing Spree will be recommended based on the Combat Rogue priority.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("avoid_killing_spree_during_ar", true, {
    name = strformat("Avoid %s during %s", Hekili:GetSpellLinkWithTexture(51690), Hekili:GetSpellLinkWithTexture(13750)),
    desc = "If checked, Killing Spree will not be recommended while Adrenaline Rush is active.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("auto_blade_flurry", true, {
    name = strformat("Auto-toggle %s", Hekili:GetSpellLinkWithTexture(13877)),
    desc = "If checked, Blade Flurry is toggled on for cleave and off for single-target.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("bandits_guile_threshold", 3, {
    name = "Bandit's Guile Threshold for Eviscerate",
    desc = "Minimum Bandit's Guile stack level before recommending Eviscerate (0 = None, 1 = Shallow, 2 = Moderate, 3 = Deep)",
    type = "range",
    min = 0,
    max = 3,
    step = 1,
    width = 1.5
})

spec:RegisterSetting("blade_flurry_toggle", "aoe", {
    name = strformat("%s Toggle", Hekili:GetSpellLinkWithTexture(13877)),
    desc = "Select when Blade Flurry should be recommended:",
    type = "select",
    values = {
        aoe = "Only in AoE",
        always = "Always",
        never = "Never"
    },
    width = 1.5
})

spec:RegisterSetting("anticipation_management", true, {
    name = strformat("Manage %s", Hekili:GetSpellLinkWithTexture(114015)),
    desc = "If checked, the addon will optimize combo point usage to avoid wasting combo points when using the Anticipation talent.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("allow_shadowstep", true, {
    name = strformat("Allow %s", Hekili:GetSpellLinkWithTexture(36554)),
    desc = "If checked, Shadowstep may be recommended for mobility and positioning.",
    type = "toggle",
    width = "full"
})

spec:RegisterSetting("use_tricks_of_the_trade", true, {
    name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(57934)),
    desc = "If checked, Tricks of the Trade will be recommended based on the Combat Rogue priority.",
    type = "toggle",
    width = "full"
})

-----------------------------------------------------------------------
-- PACK (UNCHANGED FROM ORIGINAL FILE)
-----------------------------------------------------------------------

spec:RegisterPack("Combat", 20251111, [[Hekili:9MvBpUnUr4FlgbWDn6gfzzlNMcRfOxlYD3wCPb13NLeTfTTGLLeKO2ClGH(T3zi1lK0uYEtABqswTIKZ8mVpdL)C)F3FteHr9)IJTJ7C4pwo22RM74VH9Ao1Ftoz3jYb4HuYz4))7zN3sy4RFnjJeHhVmRQyhSK)MTvXjSFn1FRknTxz544(r7fWEZP7GxVY2FZX4OiQyV0YD(B(9JXL1H4)i1HnCTomBp877yXzP1HjXLmy59zf1H)c9uCsSL)g(lrySponU8iTaE(lCXIMs2MqJ8)jbhkIZrYamA(QFPoefKS6WVMfNYQd)CZHl93aBKrlIjO4SFVvzs8oAajnkicEWQGEMeNcOyTxDiOKeydemLT5ZaHudd90LfV7uzGGsaHa6uhoToKrkoqzwS4Z0awgqhq8Fc5Yk(YpiueVqdOP0ZX0Y2JE5sD4K6qoA3MqIOb7tQkkE1QkVoCwpelQYzvfCSTyqSPZceaFKZ)OmMfSVZLzPbm65CAjIvfjrvLOTzKVlr(2Uo9L4YD0c0rrcl4(2Ca4pSqMrJz753tsdY2hCkfaCj6iKsd2f5VX9wYZY7WH4NBrq5nSLKeAkZ6mP4enkaCndIOe2rRMnZ1C7qkhKJegqaaa7EHq)GJBDqBqb9fkbe2dbLSI4tAUKlKS3AB8kdqj60duUDDDRqeDpPkHzYgOfKSnjllkPQerhqDHpPj)zWJDPK0NNX)zRgU91Na3kv0mIoP11)fcgcZD6568SKOSVL2(6oL0t1HRKrqbnNag6gySuJnz5GAIY63)leGPWQ4tjvWpMJudEBGi)ijpVi7pq)TIdVIITBo3Z39nt42xyzIK1HFOou8gq0GWL6W3xho3XYvgmNj)rqR6VbhREZ4OttcjCfEtGotYRd4Bhu1zOewG8e7IcIHqwimTlxnGOpoq49rizAPAAZZur4JW)sKE(ibaxapVxjy8XmXzS2tdK)VmsA47IET4H7JhSVQ4vKSF6)AKfk6qlobkwKSZThKUcRnpes2bMuSJKIk8IcireNgdLWeIYtprzZVUgNg6KaojcilHNBTOQj8AWGBm)VDRfOJBiK0tGQbjN)VcjhoKgoJcepWa7rPfPcOJCj12cXgQfZRuZxF4AXcCoyH8PJCWzYoI9lZLe9KwsscdQaWosJSijjs(mN3cko(z1ZlPzgIO0CiOTm(WrwBQ1ohrqIDTLZCGb1CQQNLrp6ascp3UvzQwEeufl60tnvxjPqJgX58S0kvwLxiy3r0bOJe9ABdouycTb5)YFC(Vuy0A)BNxtdbBaZ(SDvLke0OdEhyLsb4yllHTKTAlOM3xDGQq02JHUOFs5CtUnIM8wO(kBDNvjNc9e9gtT5AlPT6deFjlokqPauquvb(lKIBP4M11I89sVzYTIiThUyCRckGVTRupwYUD8ZpCLdj1Wc37Q4HMaZBKA4kiDLPnwlwev6oU2CCwpCxI)GSwwMVsJ6OxCXqZ9BWXZW4vWN9FWF8BXSJ1H)e8My2FccA)zy2v41qsa6HM(bV7rb7gdRlzZW7uwm3Y5EzWbK3wLmyOxENdZNByUb(Klk(MgM5uVOMbvr3KnF4ZDQ)Y8KywRo5VjLutAAIQ0aXZb4i3YkNRsG6(JMaviQISpgN5bh8e(vU6aHtttM9ZnIkJHRlo5giRl07Q6F4kDDeRgyQmhgAcX9AwaBSLdxFQPu7WNEH2O9AghjDICV2odxUVlnUilUznGiHQ51KNWYLpwGSFX9Hvz7hJpC2oX9n1ocQ2GJQZio8u6teQyr3qQzteVB8rmVzBuJ6PnWP1AJJlWVaddGlkU4mB7p5V5BKIuSML)MF9CEwbdDpxQDNyw1pJkRS9X4CBVRo8FNDOI(xf3PbbcSF43Y(kyvSCTCGQH1px)87GD91w1leZZjxz9Zc6wA1P6)ZEFyFcP80J41b6bLbXOqywOYYSZdSFHXX8AnkJhJ37nrrXyE7cvmU77yZYAutmqi1)g)UQ0f4oyJh00DAC5Y1ZxSEPTmbWRTqHG93TahoQxtX0bUIINGWpoqFEZ)6l9ZwJ3jk4v9AZ9F(p3aPWIpZZbskYQWcBqjvy12K6saPLgpIrzEMUpHh5d77nFL9WNtB4(MJm61u8b5RO4941tmm5n2zqdtg)oiE)q3)GmZQkPbqq55hXrb94xpaAuWD7zF5I5CWsNVF8)32X6gV)nDm1P6XJk0KRvnqQcv7e3DUW6COHXx3DLrNBpNBZlN)3Wl9i5HNiF6dpGhRFy6N8CMoX0y0ZUCrBRRDMACJZuSe3ide3pgDw70eA9mmTXY55AB(qOE4P52tFqUE56faChPhLPMAny9cuihyCxn6V87H(lNb)bu5Jm040bNDOvr4ypRN3xpuzZ2EY7t89nzmEn52uzLTQ9ujdIuGLlyaE4(gqCyrea8K7JgkysXy15sOKRuJBsaFH79Kp56Jp(izpn3DyXCuS)DsxeVqrVV)X1uaLYKr95Omow2ANUGgZR3czdJR5nF(u5WQN8wotsoEtZAjlaAnjlQq21DmkqkbZUFpbZElNozSHRMDta1vLg7Uze(34GQLy8YLXhKAnOCVCXe0bTS58Cq2wZ7FXTfgfTBt2Jv2MGocztVVTbo33Rmr8Zsoed9rg7BOTdgyJ3YFHZhB(aNEUia1l6T0mf0)8I8KlJ)jlv8N9SntxDFgKUJ9Xjx7TWmH0(gKJOS6(e99eQ1)7nhX75yKinFHCrg4(VSn0NW1TSa9zSA6vnua5)n2sHr2P9bYnzw)40B9z3hswK)66qxthHzQ385Sdr00u(SM()Np]] )
