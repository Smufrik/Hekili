-- MoP Brewmaster Monk (5.5.0)
-- Hekili Specialization File
-- Last Updated: July 22, 2025

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

-- Initialize state variables to prevent nil errors and keep them organized.
ns.last_defensive_ability = "none"
ns.last_defensive_time = 0
ns.purify_count = 0
ns.stagger_tick_amount = 0
ns.last_stagger_tick_time = 0
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
    This models the passive regeneration and max resources, modified by talents like Ascension.
--]]
spec:RegisterResource(3, { -- Energy
    base_regen = function() local b=10; if state.talent.ascension.enabled then b=b*1.15 end; if state.buff.energizing_brew.up then b=b+20 end; return b; end,
})
spec:RegisterResource(12, { -- Chi
    max = function() return state.talent.ascension.enabled and 5 or 4 end,
})


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

spec:RegisterGlyphs( {
    -- Major Glyphs
    [125731] = "afterlife",                 -- Your Healing Spheres have a 100% chance to summon a Healing Sphere when they expire.
    [125872] = "blackout_kick",             -- Your Blackout Kick can be used from 10 yards away.
    [125671] = "breath_of_fire",            -- Your Breath of Fire also disorients targets for 3 sec if they are facing you.
    [146961] = "clash",                     -- You and your target are stunned for 3 sec at the destination.
    [125697] = "crackling_jade_lightning",  -- Your Crackling Jade Lightning also knocks the target back.
    [125732] = "detox",                     -- Your Detox also heals the target for 4% of their maximum health.
    [125757] = "enduring_healing_sphere",   -- Increases the duration of your Healing Spheres by 30 sec.
    [125672] = "expel_harm",                -- Increases the range of Expel Harm by 10 yards.
    [125676] = "fighting_pose",             -- Your Guard now also causes all spells cast against you to be redirected to your Black Ox Statue.
    [125675] = "fists_of_fury",             -- Increases your chance to parry by 100% while channeling Fists of Fury.
    [125687] = "fortifying_brew",           -- Your Fortifying Brew also makes you immune to movement impairing effects.
    [125677] = "guard",                    -- Your Guard also increases healing received by 10%.
    [146960] = "jab",                       -- Your Jab deals 10% more damage but no longer generates Chi.
    [146959] = "leer_of_the_ox",            -- Teaches you the ability Leer of the Ox, which forces all targets within 10 yards of your Black Ox Statue to attack it for 6 sec.
    [123763] = "mana_tea",                  -- Your Mana Tea can now be channeled while moving.
    [125767] = "paralysis",                 -- Your Paralysis now removes all damage over time effects from the target.
    [125674] = "renewing_mist",             -- Your Renewing Mist now travels to the 2 nearest injured targets within 20 yards.
    [125755] = "retreat",                   -- Your Roll or Chi Torpedo now causes you to travel backwards.
    [125708] = "rising_sun_kick",           -- Your Rising Sun Kick now also applies a healing absorb effect on the target for 100% of the damage dealt.
    [125678] = "spinning_crane_kick",       -- You move at full speed while channeling Spinning Crane Kick.
    [146958] = "stoneskin",                 -- Increases the physical damage reduction of your Fortifying Brew by 5%.
    [125750] = "surging_mist",              -- Your Surging Mist can now be cast while moving.
    [125709] = "touch_of_karma",            -- Increases the range of your Touch of Karma by 10 yards.
    [125679] = "touch_of_death",            -- Your Touch of Death no longer has a Chi cost.
    [125680] = "transcendence",             -- Reduces the cooldown of your Transcendence: Transfer by 5 sec.
    [125681] = "uplift",                    -- Your Uplift can now be cast on targets that do not have your Renewing Mist active.
    [125682] = "zen_meditation",            -- You can now move while channeling Zen Meditation.

    -- Minor Glyphs (Cosmetic / Utility)
    [125703] = "blackout_kick_visual", 
    [125705] = "breath_of_fire_visual", 
    [146955] = "crackling_tiger_lightning",
    [125698] = "honor", 
    [146953] = "jab_visual", 
    [146954] = "rising_sun_kick_visual",
    [125699] = "spirit_roll", 
    [125694] = "spinning_fire_blossom", 
    [125701] = "water_roll", 
    [125700] = "zen_flight",
} )


spec:RegisterAuras({
    -- Core Brewmaster Buffs
    shuffle = { 
        id = 115307, duration = 6, 
        generate = function(t) local n,_,c,_,d,e,s=FindUnitBuffByID("player", t.id) if n then t.name,t.count,t.expires,t.applied,t.caster,t.up,t.down,t.remains=n,c or 1,e,e-d,s,true,false,e-GetTime() else t.count=0;t.up=false;t.down=true;t.remains=0 end end
    },
    guard = { 
        id = 115295, duration = 30, 
        generate = function(t) local n,_,c,_,d,e,s=FindUnitBuffByID("player", t.id) if n then t.name,t.count,t.expires,t.applied,t.caster,t.up,t.down,t.remains=n,c or 1,e,e-d,s,true,false,e-GetTime() else t.count=0;t.up=false;t.down=true;t.remains=0 end end
    },
    elusive_brew = { id = 128939 }, -- Active Dodge Buff
    elusive_brew_stack = { id = 128938, duration = 30, max_stack = 15 },
    fortifying_brew = { id = 115203, duration = 20 },
    zen_meditation = { id = 115176, duration = 8 },
    energizing_brew = { id = 115288, duration = 6 },
    tiger_power = { id = 125359, duration = 20 }, -- Armor pen buff from Tiger Palm
    
    -- Stagger Debuffs (on player)
    light_stagger = { id = 124275, duration = 10 },
    moderate_stagger = { id = 124274, duration = 10 },
    heavy_stagger = { id = 124273, duration = 10 },

    -- Core Debuffs (on target)
    keg_smash_debuff = { id = 121253, duration = 8, debuff = true, key = "keg_smash" },
    breath_of_fire_dot = { id = 123725, duration = 8, tick_time = 1, debuff = true, key = "breath_of_fire" },
    weakened_blows = { id = 115798, duration = 30, debuff = true, key = "dizzying_haze" },
    touch_of_death_debuff = { id = 115080, duration = 8, debuff = true, key = "touch_of_death" },

    -- Talent Auras & Procs
    power_strikes = { id = 129914, duration = 30 },
    dampen_harm = { id = 122278, duration = 45, max_stack = 3 },
    diffuse_magic = { id = 122783, duration = 6 },
    rushing_jade_wind = { id = 116847, duration = 6 },
    invoke_xuen = { id = 123904, duration = 45 },
    
    -- Tier Set Procs
    dancing_mists = { id = 146193, duration = 10 }, -- T16 4pc
    
    -- External/Raid Buffs
    bloodlust = { id = 2825 }, heroism = { id = 32182 }, time_warp = { id = 80353 },
    power_infusion = { id = 10060 },
})

spec:RegisterHook( "runHandler", function( key )
    -- This hook fires after any handler runs, allowing for centralized tracking.
    local ability = class.abilities[ key ]
    if not ability then return end

    if ability.toggle == "defensives" or ability.toggle == "cooldowns" then
        ns.last_defensive_ability = key
        ns.last_defensive_time = state.query_time
    end
end )

spec:RegisterCombatLogEvent( function(timestamp, event, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, ...)
    -- Only process events where the player is the source or destination.
    if sourceGUID ~= state.GUID and destGUID ~= state.GUID then return end

    -- Track when Purifying Brew is used successfully.
    if event == "SPELL_CAST_SUCCESS" and sourceGUID == state.GUID and spellID == 119582 then -- Purifying Brew
        ns.purify_count = ns.purify_count + 1
        ns.last_purify_time = timestamp
        
        -- Estimate the damage cleared by this Purify.
        -- We capture the stagger tick amount right before this event for a rough estimate.
        ns.stagger_purified_total = (ns.stagger_purified_total or 0) + (ns.stagger_tick_amount * 10) -- Stagger lasts 10s
    end

    -- Track Stagger damage ticks to calculate Stagger's damage per second (DTPS).
    if event == "SPELL_PERIODIC_DAMAGE" and destGUID == state.GUID then
        if spellID == 124273 or spellID == 124274 or spellID == 124275 then -- Heavy, Moderate, or Light Stagger
            local amount = select(1, ...)
            ns.stagger_tick_amount = amount
            ns.last_stagger_tick_time = timestamp
        end
    end
end )

spec:RegisterAbilities({
    -- Core Rotation
    keg_smash = { id = 121253, cooldown = 8, spend = 40, spendType = "energy", startsCombat = true, handler = function() gain(2, "chi"); applyDebuff("target", "keg_smash_debuff") end },
    blackout_kick = { id = 100784, spend = 2, spendType = "chi", startsCombat = true, handler = function() applyBuff("shuffle") end },
    jab = { id = 100780, spend = 40, spendType = "energy", startsCombat = true, handler = function() gain(1, "chi") end },
    tiger_palm = { id = 100787, spend = 25, spendType = "energy", startsCombat = true, handler = function() gain(1, "chi") end },
    expel_harm = { id = 115072, cooldown = 15, spend = 40, spendType = "energy", startsCombat = true, handler = function() gain(1, "chi") end },
    spinning_crane_kick = { id = 101546, spend = 40, spendType = "energy", startsCombat = true, handler = function() end },
    breath_of_fire = { id = 115181, cooldown = 15, spend = 2, spendType = "chi", startsCombat = true, handler = function() applyDebuff("target", "breath_of_fire_dot") end },

    -- Mitigation & Cooldowns
    purifying_brew = { id = 119582, cooldown = 1, spend = 1, spendType = "chi", toggle = "defensives", handler = function() removeBuff("heavy_stagger"); removeBuff("moderate_stagger"); removeBuff("light_stagger") end },
    guard = { id = 115295, cooldown = 30, spend = 2, spendType = "chi", toggle = "defensives", handler = function() applyBuff("guard") end },
    elusive_brew = { id = 115308, cooldown = 1, toggle = "defensives", usable = function() return state.buff.elusive_brew_stack.stack > 0 end, handler = function() local s = state.buff.elusive_brew_stack.stack; removeBuff("elusive_brew_stack"); applyBuff("elusive_brew", s) end },
    fortifying_brew = { id = 115203, cooldown = 180, toggle = "cooldowns", handler = function() applyBuff("fortifying_brew") end },
    zen_meditation = { id = 115176, cooldown = 180, toggle = "defensives", handler = function() applyBuff("zen_meditation") end },
    energizing_brew = { id = 115288, cooldown = 60, toggle = "cooldowns", handler = function() applyBuff("energizing_brew") end },

    -- Talented Abilities
    chi_brew = { id = 115399, cooldown = 45, charges = 2, talent = "chi_brew", handler = function() gain(2, "chi") end },
    chi_wave = { id = 115098, cooldown = 15, talent = "chi_wave", handler = function() end },
    dampen_harm = { id = 122278, cooldown = 90, toggle = "defensives", talent = "dampen_harm", handler = function() applyBuff("dampen_harm") end },
    diffuse_magic = { id = 122783, cooldown = 90, toggle = "defensives", talent = "diffuse_magic", handler = function() applyBuff("diffuse_magic") end },
    invoke_xuen = { id = 123904, cooldown = 180, toggle = "cooldowns", talent = "invoke_xuen", handler = function() summonPet("xuen_the_white_tiger", 45); applyBuff("invoke_xuen") end },
    leg_sweep = { id = 119381, cooldown = 45, talent = "leg_sweep", handler = function() end },
    rushing_jade_wind = { id = 116847, cooldown = 6, spend = 2, spendType = "chi", talent = "rushing_jade_wind", handler = function() applyBuff("rushing_jade_wind") end },
    
    -- Utility & Racials
    provoke = { id = 115546, cooldown = 8, handler = function() end },
    roll = { id = 109132, cooldown = 20, charges = 2, handler = function() end },
    spear_hand_strike = { id = 116705, cooldown = 15, interrupt = true, handler = function() interrupt() end },
    blood_fury = { id = 20572, cooldown = 120, toggle = "cooldowns", handler = function() applyBuff("blood_fury") end },
    berserking = { id = 26297, cooldown = 180, toggle = "cooldowns", handler = function() applyBuff("berserking") end },

    -- Newly Added Abilities
    touch_of_death = {
        id = 115080,
        cooldown = 90,
        spend = function() return state.glyph.touch_of_death.enabled and 0 or 3 end,
        spendType = "chi",
        toggle = "cooldowns",
        handler = function() applyDebuff("target", "touch_of_death_debuff") end
    },
    summon_black_ox_statue = {
        id = 115315,
        cooldown = 30,
        toggle = "cooldowns",
        handler = function() summonPet("black_ox_statue", 900) end
    },
    dizzying_haze = {
        id = 116330,
        spend = 20,
        spendType = "energy",
        handler = function() applyDebuff("target", "weakened_blows") end
    },
    transcendence = {
        id = 101643,
        toggle = "utility"
    },
    transcendence_transfer = {
        id = 119996,
        cooldown = function() return state.glyph.transcendence.enabled and 40 or 45 end,
        toggle = "defensives",
        handler = function() end
    },
    detox = {
        id = 115451,
        cooldown = 8,
        spend = 20,
        spendType = "energy",
        toggle = "utility",
        handler = function() dispel("Poison", "Disease") end
    },
    paralysis = {
        id = 115078,
        cooldown = 15,
        toggle = "interrupts",
        handler = function() end
    },
    clash = {
        id = 122281,
        cooldown = 45,
        toggle = "utility",
        handler = function() end
    },
})

-- Exposes the current stagger level ("none", "light", "moderate", "heavy").
spec:RegisterStateExpr("stagger_level", function()
    return spec:GetStaggerLevel()
end)

-- Calculates the current damage per second (DTPS) from Stagger.
-- This is critical for deciding when to Purify.
spec:RegisterStateExpr("stagger_dtps", function()
    if state.query_time - (ns.last_stagger_tick_time or 0) > 1.5 then
        -- If it's been more than 1.5 seconds since the last tick, assume it's gone.
        return 0
    end
    -- Stagger ticks every second, so the last tick amount is our DTPS.
    return ns.stagger_tick_amount or 0
end)

-- A direct check to see if you should purify based on your settings.
spec:RegisterStateExpr("should_purify", function()
    local threshold = state.settings.purify_threshold
    local level = spec:GetStaggerLevel()
    
    if threshold == "heavy" and level == "heavy" then return true end
    if threshold == "moderate" and (level == "heavy" or level == "moderate") then return true end
    if threshold == "aggressive" and level ~= "none" then return true end
    
    return false
end)

-- Provides the current number of Elusive Brew stacks for easier use in the APL.
spec:RegisterStateExpr("elusive_brew_stacks", function()
    return state.buff.elusive_brew_stack.stack or 0
end)

-- Provides the remaining duration on Shuffle.
spec:RegisterStateExpr("shuffle_remains", function()
    return state.buff.shuffle.remains or 0
end)

spec:RegisterSetting( "purify_threshold", "heavy", {
    name = "Purify Stagger Threshold",
    desc = "Determines when to recommend Purifying Brew.\n\n|cFFFFD100Heavy|r: Only purify at heavy (red) stagger.\n|cFFFFD100Moderate|r: Purify at moderate (yellow) or heavy stagger.\n|cFFFFD100Aggressive|r: Purify frequently, even at light stagger.",
    type = "select",
    width = 1.5,
    values = {
        heavy = "Heavy Stagger",
        moderate = "Moderate Stagger",
        aggressive = "Aggressive (Any Stagger)"
    }
} )

spec:RegisterSetting( "guard_usage", "reactive", {
    name = "Guard Usage",
    desc = "Controls the logic for recommending Guard.\n\n|cFFFFD100Reactive|r: Use Guard in response to high incoming damage or when health is low.\n|cFFFFD100Uptime|r: Use Guard as often as possible to maximize uptime.",
    type = "select",
    width = 1.5,
    values = {
        reactive = "Reactive",
        uptime = "Maximize Uptime"
    }
} )

spec:RegisterSetting( "fortify_health_pct", 35, {
    name = strformat( "Use %s Below Health %%", Hekili:GetSpellLinkWithTexture( spec.abilities.fortifying_brew.id ) ),
    desc = "The health percentage at which Fortifying Brew will be recommended as an emergency defensive cooldown.",
    type = "range",
    min = 0,
    max = 100,
    step = 5,
    width = "full"
} )

-- Register default pack
spec:RegisterPack("Brewmaster", 20250722, [[Hekili:T3vBVTTnu4FldiHr5osojoRZh7KvA3KRJvA2jDLA2jz1yvfbpquu6iqjvswkspfePtl6VGQIQUnbJeHAVQDcOWrbE86CaE4GUwDBB4CvC5m98jdNZzDX6w)v)V(i)h(jDV7GFWEh)9T6rhFQVnSVzsmypSlD2OXqskYJCKfpPWXt87zPkZGZVRSLAXYUYORTmYLwaXlyc8LkGusGO7469JwjTfTH0PwPbJaeivvLsvrfoeQtcGbWlG0A)Ff9)8jPyqXgkz5Qkz5kLRyR12Uco1veB5MUOfIMXnV2Nw8UqEkeUOLXMFtKUOMcEvjzmqssgiE37NuLYlP5NnNgEE5(vJDjgvCeXmQVShsbh(AfIigS2JOmiUeXm(KJ0JkOtQu0Ky)iYcJvqQrthQ(5Fcu5ILidEZjQ0CoYXj)USIip9kem)i81l2cOFLlk9cKGk5nuuDXZes)SEHXiZdLP1gpb968CvpxbSVDaPzgwP6ahsQWnRs)uOKnc0)]])

print("Brewmaster: Script loaded successfully with advanced trackers.")
