-- MonkBrewmaster.lua
-- Test Version: July 22, 2025
-- A comprehensive Mists of Pandaria module for Monk: Brewmaster spec.

-- MoP: Use UnitClass instead of UnitClassBase
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

--[[
    Resource registration for Energy (3) and Chi (12).
    This models the passive regeneration and max resources, modified by talents like Ascension.
--]]
spec:RegisterResource(3, { -- Energy
    base_regen = function() local b=10; if state.talent.ascension.enabled then b=b*1.15 end; if state.buff.energizing_brew.up then b=b+20 end; return b; end,
})
spec:RegisterResource(12, { -- Chi
    max = function() return state.talent.ascension.enabled and 5 or 4 end,
})


--[[
    Comprehensive Gear Registration
    Includes all raid tier sets and notable trinkets from MoP.
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
spec:RegisterGear( "steadfast_talisman", 102305 )  -- Steadfast Talisman (SoO)
spec:RegisterGear( "thoks_tail_tip", 102300 )      -- Thok's Tail Tip (SoO)
spec:RegisterGear( "haromms_talisman", 102298 )    -- Haromm's Talisman (SoO)
spec:RegisterGear( "vial_of_living_corruption", 94532 ) -- Vial of Living Corruption (ToT)
spec:RegisterGear( "ji_kuns_rising_spleen", 94519 )    -- Ji-Kun's Rising Spleen (ToT)
spec:RegisterGear( "badge_of_the_iron_company", 81261 ) -- Badge of the Iron Company (MSV)


--[[
    Complete Mists of Pandaria Talent List
--]]
spec:RegisterTalents({
    -- Tier 1 (Level 15) - Mobility
    celerity = { 1, 1, 115173 },
    tigers_lust = { 1, 2, 116841 },
    momentum = { 1, 3, 115294 },

    -- Tier 2 (Level 30) - Utility/Healing
    chi_wave = { 2, 1, 115098 },
    zen_sphere = { 2, 2, 124081 },
    chi_burst = { 2, 3, 123986 },

    -- Tier 3 (Level 45) - Resources
    power_strikes = { 3, 1, 121817 },
    ascension = { 3, 2, 115396 },
    chi_brew = { 3, 3, 115399 },

    -- Tier 4 (Level 60) - Crowd Control
    ring_of_peace = { 4, 1, 116844 },
    charging_ox_wave = { 4, 2, 119392 },
    leg_sweep = { 4, 3, 119381 },

    -- Tier 5 (Level 75) - Defensives
    healing_elixirs = { 5, 1, 122280 },
    dampen_harm = { 5, 2, 122278 },
    diffuse_magic = { 5, 3, 122783 },

    -- Tier 6 (Level 90) - Throughput
    rushing_jade_wind = { 6, 1, 116847 },
    invoke_xuen = { 6, 2, 123904 },
    chi_torpedo = { 6, 3, 115008 },
})


--[[
    Comprehensive Monk Glyphs for MoP
--]]
spec:RegisterGlyphs( {
    -- Major Glyphs
    [125731] = "afterlife", [125872] = "blackout_kick", [125671] = "breath_of_fire",
    [146961] = "clash", [125697] = "crackling_jade_lightning", [125732] = "detox",
    [125757] = "enduring_healing_sphere", [125672] = "expel_harm", [125676] = "fighting_pose",
    [125675] = "fists_of_fury", [125687] = "fortifying_brew", [125677] = "guard",
    [146960] = "jab", [146959] = "leer_of_the_ox", [123763] = "mana_tea",
    [125767] = "paralysis", [125674] = "renewing_mist", [125755] = "retreat",
    [125708] = "rising_sun_kick", [125678] = "spinning_crane_kick", [146958] = "stoneskin",
    [125750] = "surging_mist", [125709] = "touch_of_karma", [125679] = "touch_of_death",
    [125680] = "transcendence", [125681] = "uplift", [125682] = "zen_meditation",

    -- Minor Glyphs
    [125703] = "blackout_kick_visual", [125705] = "breath_of_fire_visual", [146955] = "crackling_tiger_lightning",
    [125698] = "honor", [146953] = "jab_visual", [146954] = "rising_sun_kick_visual",
    [125699] = "spirit_roll", [125694] = "spinning_fire_blossom", [125701] = "water_roll", [125700] = "zen_flight",
} )


--[[
    Robust Aura Definitions
    Includes all buffs, debuffs, procs, and cooldowns.
--]]
spec:RegisterAuras({
    -- Core Brewmaster Buffs
    shuffle = { id = 115307, duration = 6 },
    guard = { id = 115295, duration = 30 },
    elusive_brew = { id = 128939 }, -- Active Dodge Buff
    elusive_brew_stack = { id = 128938, duration = 30, max_stack = 15 },
    fortifying_brew = { id = 115203, duration = 20 },
    zen_meditation = { id = 115176, duration = 8 },
    energizing_brew = { id = 115288, duration = 6 },
    
    -- Stagger Debuffs (on player)
    light_stagger = { id = 124275, duration = 10 },
    moderate_stagger = { id = 124274, duration = 10 },
    heavy_stagger = { id = 124273, duration = 10 },

    -- Core Debuffs (on target)
    keg_smash_debuff = { id = 121253, duration = 8, debuff = true, key = "keg_smash" },
    breath_of_fire_dot = { id = 123725, duration = 8, tick_time = 1, debuff = true, key = "breath_of_fire" },

    -- Talent Auras
    dampen_harm = { id = 122278, duration = 45, max_stack = 3 },
    diffuse_magic = { id = 122783, duration = 6 },
    rushing_jade_wind = { id = 116847, duration = 6 },
    invoke_xuen = { id = 123904, duration = 45 }, -- The buff for having Xuen out
    
    -- Tier Set Procs
    dancing_mists = { id = 146193, duration = 10 }, -- T16 4pc
    
    -- Trinket Procs
    steadfast_resolve = { id = 146045, duration = 20 }, -- Proc from Steadfast Talisman
    thoks_acid_breath = { id = 146039, duration = 10, debuff = true }, -- Proc from Thok's Tail Tip
    
    -- External/Raid Buffs
    bloodlust = { id = 2825 }, heroism = { id = 32182 }, time_warp = { id = 80353 },
    power_infusion = { id = 10060 },
})


--[[
    Complete Ability List (Declarative Style)
--]]
spec:RegisterAbilities({
    -- Core Rotational Abilities
    keg_smash = { id = 121253, cooldown = 8, spend = 40, spend_type = "energy", gain = 2, gain_type = "chi", debuff = "keg_smash_debuff" },
    blackout_kick = { id = 100784, spend = 2, spend_type = "chi", buff = "shuffle" },
    jab = { id = 100780, spend = 40, spend_type = "energy", gain = 1, gain_type = "chi" },
    tiger_palm = { id = 100787, spend = 25, spend_type = "energy", gain = 1, gain_type = "chi" },
    expel_harm = { id = 115072, cooldown = 15, spend = 40, spend_type = "energy", gain = 1, gain_type = "chi" },
    spinning_crane_kick = { id = 101546, spend = 40, spend_type = "energy" },
    breath_of_fire = { id = 115181, cooldown = 15, spend = 2, spend_type = "chi", debuff = "breath_of_fire_dot" },

    -- Mitigation & Cooldowns
    purifying_brew = { id = 119582, cooldown = 1, spend = 1, spend_type = "chi", toggle = "defensives" },
    guard = { id = 115295, cooldown = 30, spend = 2, spend_type = "chi", buff = "guard", toggle = "defensives" },
    elusive_brew = { id = 115308, cooldown = 1, buff = "elusive_brew", consume_buff = "elusive_brew_stack", toggle = "defensives" },
    fortifying_brew = { id = 115203, cooldown = 180, buff = "fortifying_brew", toggle = "cooldowns" },
    zen_meditation = { id = 115176, cooldown = 180, buff = "zen_meditation", toggle = "defensives" },
    energizing_brew = { id = 115288, cooldown = 60, buff = "energizing_brew", toggle = "cooldowns" },

    -- Talented Abilities
    chi_brew = { id = 115399, cooldown = 45, charges = 2, gain = 2, gain_type = "chi", talent = "chi_brew" },
    chi_wave = { id = 115098, cooldown = 15, talent = "chi_wave" },
    dampen_harm = { id = 122278, cooldown = 90, buff = "dampen_harm", talent = "dampen_harm", toggle = "defensives" },
    diffuse_magic = { id = 122783, cooldown = 90, buff = "diffuse_magic", talent = "diffuse_magic", toggle = "defensives" },
    invoke_xuen = { id = 123904, cooldown = 180, buff = "invoke_xuen", talent = "invoke_xuen", toggle = "cooldowns" },
    leg_sweep = { id = 119381, cooldown = 45, talent = "leg_sweep" },
    rushing_jade_wind = { id = 116847, cooldown = 6, spend = 2, spend_type = "chi", buff = "rushing_jade_wind", talent = "rushing_jade_wind" },
    
    -- Utility
    provoke = { id = 115546, cooldown = 8 },
    roll = { id = 109132, cooldown = 20, charges = 2 },
    detox = { id = 115450, cooldown = 8 },
    transcendence = { id = 101643, cooldown = 45 },
    transcendence_transfer = { id = 119996, cooldown = 25 },
    clash = { id = 122425, cooldown = 35 },
    spear_hand_strike = { id = 116705, cooldown = 15, interrupt = true },
    
    -- Racials
    blood_fury = { id = 20572, cooldown = 120, toggle = "cooldowns" }, -- Orc
    berserking = { id = 26297, cooldown = 180, toggle = "cooldowns" }, -- Troll
    arcane_torrent = { id = 28730, cooldown = 120 }, -- Blood Elf
})

-- State Expressions for easier APL conditions
spec:RegisterStateExpr("stagger_percent_of_health", function()
    local hp = state.health.max
    if hp == 0 then return 0 end
    if state.buff.heavy_stagger.up then return 0.06 * 100 end -- Stagger DOT is 6% of health per second
    if state.buff.moderate_stagger.up then return 0.03 * 100 end -- 3%
    if state.buff.light_stagger.up then return 0.015 * 100 end -- 1.5%
    return 0
end)

spec:RegisterStateExpr("should_purify", function()
    -- Purify heavy stagger always, or moderate if health is dropping.
    if state.buff.heavy_stagger.up then return true end
    if state.buff.moderate_stagger.up and state.health.percent < 70 then return true end
    return false
end)

-- The string below is a placeholder.
spec:RegisterPack("Brewmaster", 20250722, [[Hekili: PLACEHOLDER - REPLACE WITH NEW STRING]])
