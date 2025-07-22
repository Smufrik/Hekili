-- MoP Brewmaster Monk (5.5.0)
-- Hekili Specialization File
-- Last Updated: July 22, 2025 (State Error Fix Applied)

-- Boilerplate and Class Check
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

state.items = state.items or {}

local spec = Hekili:NewSpecialization( 268 ) -- Brewmaster spec ID for MoP
if not spec then
    print("Brewmaster: Failed to initialize specialization (ID 268).")
    return
end

-- =================================================================
--                        Advanced State Tracking
-- =================================================================
-- Initialize state variables to prevent nil errors.
ns.stagger_tick_amount = 0
ns.last_stagger_tick_time = 0
ns.purify_count = 0
ns.last_purify_time = 0
ns.stagger_purified_total = 0

-- Helper function to get the current stagger level as a string.
-- This is useful and more readable for action lists (e.g., 'stagger_level == "heavy"').
function spec:GetStaggerLevel()
    if state.buff.heavy_stagger.up then return "heavy" end
    if state.buff.moderate_stagger.up then return "moderate" end
    if state.buff.light_stagger.up then return "light" end
    return "none"
end

--[[
    Resource registration for Energy (3) and Chi (12).
--]]
spec:RegisterResource(3, { -- Energy
    base_regen = function() local b=10; if state.talent.ascension.enabled then b=b*1.15 end; if state.buff.energizing_brew.up then b=b+20 end; return b; end,
})
spec:RegisterResource(12, { -- Chi
    max = function() return state.talent.ascension.enabled and 5 or 4 end,
})


--[[
    Comprehensive Gear Registration
--]]
-- Tier 14: Vestments of the Red Crane
spec:RegisterGear( "tier14_lfr", 86326, 86329, 86332, 86335, 86338 )
spec:RegisterGear( "tier14", 85468, 85471, 85474, 85477, 85480 )
spec:RegisterGear( "tier14_heroic", 87040, 87043, 87046, 87049, 87052 )

-- Tier 15: Vestments of the Seven Sacred Seals
spec:RegisterGear( "tier15_lfr", 95832, 95833, 95834, 95835, 95836 )
spec:RegisterGear( "tier15", 95094, 95097, 95100, 95103, 95106 )
spec:RegisterGear( "tier15_heroic", 96510, 96513, 96516, 96519, 96522 )

-- Tier 16: Vestments of the Shattered Vale
spec:RegisterGear( "tier16_lfr", 104884, 104887, 104890, 104893, 104896 )
spec:RegisterGear( "tier16_flex", 105556, 105559, 105562, 105565, 105568 )
spec:RegisterGear( "tier16", 99250, 99253, 99256, 99259, 99262 )
spec:RegisterGear( "tier16_heroic", 103855, 103858, 103861, 103864, 103867 )

-- Legendary Items
spec:RegisterGear( "legendary_cloak_tank", 102246 ) -- Qian-Ying, Fortitude of Niuzao
spec:RegisterGear( "legendary_cloak_dps", 102247 ) -- Qian-Le, Courage of Niuzao

-- Notable MoP Tanking Trinkets
spec:RegisterGear( "steadfast_talisman", 102305 )
spec:RegisterGear( "thoks_tail_tip", 102300 )
spec:RegisterGear( "haromms_talisman", 102298 )
spec:RegisterGear( "vial_of_living_corruption", 94532 )
spec:RegisterGear( "ji_kuns_rising_spleen", 94519 )
spec:RegisterGear( "badge_of_the_iron_company", 81261 )


--[[
    Complete Mists of Pandaria Talent List
--]]
spec:RegisterTalents({
    celerity = { 1, 1, 115173 }, tigers_lust = { 1, 2, 116841 }, momentum = { 1, 3, 115294 },
    chi_wave = { 2, 1, 115098 }, zen_sphere = { 2, 2, 124081 }, chi_burst = { 2, 3, 123986 },
    power_strikes = { 3, 1, 121817 }, ascension = { 3, 2, 115396 }, chi_brew = { 3, 3, 115399 },
    ring_of_peace = { 4, 1, 116844 }, charging_ox_wave = { 4, 2, 119392 }, leg_sweep = { 4, 3, 119381 },
    healing_elixirs = { 5, 1, 122280 }, dampen_harm = { 5, 2, 122278 }, diffuse_magic = { 5, 3, 122783 },
    rushing_jade_wind = { 6, 1, 116847 }, invoke_xuen = { 6, 2, 123904 }, chi_torpedo = { 6, 3, 115008 },
})

--[[
    Brewmaster Glyphs
--]]
spec:RegisterGlyphs( {
    [146961] = "clash", [125697] = "crackling_jade_lightning", [125732] = "detox", [125672] = "expel_harm",
    [125687] = "fortifying_brew", [125677] = "guard", [146960] = "jab", [125767] = "paralysis", [125755] = "retreat",
    [146958] = "stoneskin", [125679] = "touch_of_death", [125680] = "transcendence", [125682] = "zen_meditation",
} )


--[[
    Brewmaster Auras and Debuffs
--]]
spec:RegisterAuras({
    shuffle = { id = 115307, duration = 6 },
    guard = { id = 115295, duration = 30 },
    elusive_brew = { id = 128939 },
    elusive_brew_stack = { id = 128938, duration = 30, max_stack = 15 },
    fortifying_brew = { id = 115203, duration = 20 },
    zen_meditation = { id = 115176, duration = 8 },
    energizing_brew = { id = 115288, duration = 6 },
    light_stagger = { id = 124275, duration = 10 },
    moderate_stagger = { id = 124274, duration = 10 },
    heavy_stagger = { id = 124273, duration = 10 },
    keg_smash_debuff = { id = 121253, duration = 8, debuff = true, key = "keg_smash" },
    weakened_blows = { id = 115798, duration = 30, debuff = true, key = "dizzying_haze" },
})


-- =================================================================
--                    Combat Log Event Processing
-- =================================================================
spec:RegisterCombatLogEvent( function(timestamp, event, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, ...)
    if sourceGUID ~= state.GUID and destGUID ~= state.GUID then return end

    if event == "SPELL_CAST_SUCCESS" and sourceGUID == state.GUID and spellID == 119582 then -- Purifying Brew
        ns.purify_count = ns.purify_count + 1
        ns.last_purify_time = timestamp
        ns.stagger_purified_total = (ns.stagger_purified_total or 0) + (ns.stagger_tick_amount * 10)
    end

    if event == "SPELL_PERIODIC_DAMAGE" and destGUID == state.GUID then
        if spellID == 124273 or spellID == 124274 or spellID == 124275 then -- Heavy, Moderate, or Light Stagger
            local amount = select(1, ...)
            ns.stagger_tick_amount = amount
            ns.last_stagger_tick_time = timestamp
        end
    end
end )


--[[
    Brewmaster Abilities
--]]
spec:RegisterAbilities({
    keg_smash = { id = 121253, cooldown = 8, spend = 40, spendType = "energy", handler = function() gain(2, "chi"); applyDebuff("target", "keg_smash_debuff") end },
    blackout_kick = { id = 100784, spend = 2, spendType = "chi", handler = function() applyBuff("player", "shuffle") end },
    jab = { id = 100780, spend = 40, spendType = "energy", handler = function() gain(1, "chi") end },
    expel_harm = { id = 115072, cooldown = 15, spend = 40, spendType = "energy", handler = function() gain(1, "chi") end },
    purifying_brew = { id = 119582, cooldown = 1, spend = 1, spendType = "chi", toggle = "defensives" },
    guard = { id = 115295, cooldown = 30, spend = 2, spendType = "chi", toggle = "defensives", handler = function() applyBuff("player", "guard") end },
    elusive_brew = { id = 115308, cooldown = 1, toggle = "defensives", usable = function() return state.buff.elusive_brew_stack.stack > 0 end, handler = function() local s = state.buff.elusive_brew_stack.stack; removeBuff("player", "elusive_brew_stack"); applyBuff("player", "elusive_brew", s) end },
    fortifying_brew = { id = 115203, cooldown = 180, toggle = "cooldowns", handler = function() applyBuff("player", "fortifying_brew") end },
    zen_meditation = { id = 115176, cooldown = 180, toggle = "defensives", handler = function() applyBuff("player", "zen_meditation") end },
    energizing_brew = { id = 115288, cooldown = 60, toggle = "cooldowns", handler = function() applyBuff("player", "energizing_brew") end },
    chi_brew = { id = 115399, cooldown = 45, charges = 2, talent = "chi_brew", handler = function() gain(2, "chi") end },
    dampen_harm = { id = 122278, cooldown = 90, toggle = "defensives", talent = "dampen_harm", handler = function() applyBuff("player", "dampen_harm") end },
    diffuse_magic = { id = 122783, cooldown = 90, toggle = "defensives", talent = "diffuse_magic", handler = function() applyBuff("player", "diffuse_magic") end },
    invoke_xuen = { id = 123904, cooldown = 180, toggle = "cooldowns", talent = "invoke_xuen", handler = function() summonPet("xuen_the_white_tiger", 45) end },
    spear_hand_strike = { id = 116705, cooldown = 15, interrupt = true, handler = function() interrupt() end },
    provoke = { id = 115546, cooldown = 8 },
})


--[[
    State Expressions for smarter APL
--]]
spec:RegisterStateExpr("stagger_level", function() return spec:GetStaggerLevel() end)
spec:RegisterStateExpr("stagger_dtps", function() if state.query_time - (ns.last_stagger_tick_time or 0) > 1.5 then return 0 end; return ns.stagger_tick_amount or 0 end)
spec:RegisterStateExpr("should_purify", function() local t=state.settings.purify_threshold; local l=spec:GetStaggerLevel(); if t=="heavy" and l=="heavy" then return true end; if t=="moderate" and (l=="heavy" or l=="moderate") then return true end; if t=="aggressive" and l~="none" then return true end; return false end)
spec:RegisterStateExpr("elusive_brew_stacks", function() return state.buff.elusive_brew_stack.stack or 0 end)
spec:RegisterStateExpr("shuffle_remains", function() return state.buff.shuffle.remains or 0 end)


--[[
    User Settings
--]]
spec:RegisterSetting( "purify_threshold", "heavy", {
    name = "Purify Stagger Threshold",
    desc = "Determines when to recommend Purifying Brew.\n\n|cFFFFD100Heavy|r: Only purify at heavy (red) stagger.\n|cFFFFD100Moderate|r: Purify at moderate (yellow) or heavy stagger.\n|cFFFFD100Aggressive|r: Purify frequently, even at light stagger.",
    type = "select", width = 1.5,
    values = { heavy = "Heavy Stagger", moderate = "Moderate Stagger", aggressive = "Aggressive (Any Stagger)" }
} )

spec:RegisterSetting( "guard_usage", "reactive", {
    name = "Guard Usage",
    desc = "Controls the logic for recommending Guard.\n\n|cFFFFD100Reactive|r: Use Guard in response to high incoming damage or when health is low.\n|cFFFFD100Uptime|r: Use Guard as often as possible to maximize uptime.",
    type = "select", width = 1.5,
    values = { reactive = "Reactive", uptime = "Maximize Uptime" }
} )

-- CORRECTED SETTING TO PREVENT LOAD-TIME ERRORS
spec:RegisterSetting( "fortify_health_pct", 35, {
    name = function()
        return strformat( "Use %s Below Health %%", Hekili:GetSpellLinkWithTexture( spec.abilities.fortifying_brew.id ) )
    end,
    desc = "The health percentage at which Fortifying Brew will be recommended as an emergency defensive cooldown.",
    type = "range", min = 0, max = 100, step = 5, width = "full"
} )


--[[
    Brewmaster APL Package
--]]
spec:RegisterPack("Brewmaster", 20250722, [[
[
    ["action_lists"]={
        ["defensives"]={
            ["name"]="Defensives",
            ["type"]="action_list",
            ["actions"]={
                {
                    ["action"]="fortifying_brew",
                    ["if"]="player.health.percent <= settings.fortify_health_pct"
                },
                {
                    ["action"]="dampen_harm",
                    ["if"]="talent.dampen_harm.enabled and player.health.percent <= 40 and buff.fortifying_brew.down"
                },
                {
                    ["action"]="diffuse_magic",
                    ["if"]="talent.diffuse_magic.enabled and player.health.percent <= 50 and buff.fortifying_brew.down"
                },
                {
                    ["action"]="guard",
                    ["if"]="(settings.guard_usage == 'uptime') or (settings.guard_usage == 'reactive' and player.health.percent <= 60)"
                },
                {
                    ["action"]="elusive_brew",
                    ["if"]="elusive_brew_stacks >= 10 or (elusive_brew_stacks >= 6 and (stagger_level == 'heavy' or player.health.percent < 70))"
                },
                {
                    ["action"]="purifying_brew",
                    ["if"]="should_purify and chi >= 1"
                },
                {
                    ["action"]="zen_meditation",
                    ["if"]="player.health.percent < 30 and buff.fortifying_brew.down"
                }
            }
        },
        ["default"]={
            ["name"]="Single Target",
            ["type"]="action_list",
            ["actions"]={
                {
                    ["action"]="spear_hand_strike",
                    ["if"]="target.interrupt.any"
                },
                {
                    ["action"]="blackout_kick",
                    ["if"]="shuffle_remains < 2"
                },
                {
                    ["action"]="keg_smash"
                },
                {
                    ["action"]="expel_harm",
                    ["if"]="chi.max - chi >= 1 and player.health.percent <= 85"
                },
                {
                    ["action"]="blackout_kick",
                    ["if"]="chi >= 4 and shuffle_remains < 6"
                },
                {
                    ["action"]="jab",
                    ["if"]="chi.max - chi >= 1"
                }
            }
        }
    },
    ["displays"]={
        ["Defensives"]={
            ["type"]="display",
            ["action_list"]="defensives",
            ["enabled"]=true
        },
        ["Primary"]={
            ["type"]="display",
            ["opacities"]={
                ["range"]=0.5
            },
            ["action_list"]="default",
            ["enabled"]=true
        }
    }
}
]])

print("Brewmaster: Script loaded successfully with state error fix.")
