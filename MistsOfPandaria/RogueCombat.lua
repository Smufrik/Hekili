-- RogueCombat.lua
-- July 2025
-- by Smufrik

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'ROGUE' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization( 260, true ) -- Combat spec ID for Hekili (260 = Combat in MoP Classic)

-- Ensure state is properly initialized
if not state then 
    state = Hekili.State 
end

-- Enhanced resource registration for Combat Rogue with signature mechanics
spec:RegisterResource( 3, { -- Energy with Combat-specific enhancements
    -- Adrenaline Rush energy bonus (Combat signature cooldown)
    adrenaline_rush = {
        aura = "adrenaline_rush",
        last = function ()
            local app = state.buff.adrenaline_rush.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Adrenaline Rush doubles energy regeneration (Combat signature)
            return state.buff.adrenaline_rush.up and 10 or 0 -- Additional 10 energy per second
        end,
    },
    
    -- Combat Potency proc energy (Combat passive) - MoP: 20% chance for 15 energy on off-hand hit
    combat_potency = {
        last = function ()
            return state.query_time -- Continuous proc chance tracking
        end,
        interval = 0.5, -- Off-hand attacks happen roughly every 0.5 seconds with dual-wield
        value = function()
            if not state.combat then return 0 end
            
            -- Combat Potency: 20% chance to gain 15 energy on off-hand hit
            -- More accurate simulation based on weapon speed and proc chance
            local weapon_speed = state.swings.offhand_speed or 2.6
            local attacks_per_second = 1 / weapon_speed
            local proc_chance = 0.20 -- 20% proc chance
            local energy_per_proc = 15
            
            -- Expected energy per second = attacks_per_second * proc_chance * energy_per_proc
            return attacks_per_second * proc_chance * energy_per_proc
        end,
    },
    
    -- Shadow Focus talent energy reduction mechanics
    shadow_focus = {
        aura = "stealth",
        last = function ()
            return state.buff.stealth.applied or state.buff.vanish.applied or 0
        end,
        interval = 1,
        value = function()
            -- Shadow Focus reduces energy costs while stealthed
            return (state.buff.stealth.up or state.buff.vanish.up) and 3 or 0 -- +3 energy per second while stealthed
        end,
    },
    
    -- Blade Flurry energy efficiency
    blade_flurry = {
        aura = "blade_flurry",
        last = function ()
            local app = state.buff.blade_flurry.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            -- Slight energy efficiency bonus during Blade Flurry
            return state.buff.blade_flurry.up and 1 or 0 -- +1 energy per second during Blade Flurry
        end,
    },
    
    -- Relentless Strikes energy return (Combat gets good benefit)
    relentless_strikes_energy = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Relentless Strikes: 20% chance per combo point spent to generate 25 energy
            if state.talent.relentless_strikes.enabled and state.last_finisher_cp then
                local energy_chance = state.last_finisher_cp * 0.04 -- 4% chance per combo point for energy return
                return math.random() < energy_chance and 25 or 0
            end
            return 0
        end,
    },
}, {
    -- Enhanced base energy regeneration for Combat with MoP mechanics
    base_regen = function ()
        local base = 10 -- Base energy regeneration in MoP (10 energy per second)
        
        -- Haste scaling for energy regeneration (minor in MoP)
        local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
        
        -- Combat doesn't get inherent energy regeneration bonuses like other specs
        return base * haste_bonus
    end,
    
    -- Blade Flurry energy efficiency during cleave
    blade_flurry_efficiency = function ()
        return state.buff.blade_flurry.up and 1.05 or 1.0 -- 5% energy efficiency during Blade Flurry
    end,
    
    -- Glyph of Energy enhanced regeneration
    glyph_energy_bonus = function ()
        return state.glyph.energy.enabled and 1.05 or 1.0 -- 5% energy regen bonus if glyphed
    end,
} )

-- Combo Points resource registration with Combat-specific mechanics
spec:RegisterResource( 4, { -- Combo Points = 4 in MoP
    -- Bandit's Guile combo point synergy (Combat passive)
    bandits_guile = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Bandit's Guile doesn't generate combo points directly but affects their efficiency
            local insight_bonus = 0
            if state.buff.shallow_insight.up then insight_bonus = 0.1
            elseif state.buff.moderate_insight.up then insight_bonus = 0.2
            elseif state.buff.deep_insight.up then insight_bonus = 0.3
            end
            return insight_bonus -- Effective combo point value multiplier
        end,
    },
    
    -- Restless Blades combo point consumption tracking
    restless_blades_cd_reduction = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Track combo points spent for Restless Blades cooldown reduction
            if state.talent.restless_blades.enabled and state.last_finisher_cp then
                return -state.last_finisher_cp -- Negative to track consumption for CDR
            end
            return 0
        end,
    },
    
    -- Ruthlessness combo point retention (Combat gets good benefit)
    ruthlessness_retention = {
        last = function ()
            return state.query_time
        end,
        interval = 1,
        value = function()
            -- Ruthlessness: 20% chance per combo point spent to not consume a combo point
            if state.talent.ruthlessness.enabled and state.last_finisher_cp then
                local retention_chance = state.last_finisher_cp * 0.2
                return math.random() < retention_chance and 1 or 0
            end
            return 0
        end,
    },
    
    -- Marked for Death instant combo points (if talented)
    marked_for_death_generation = {
        last = function ()
            return (state.last_cast_time and state.last_cast_time.marked_for_death) or 0
        end,
        interval = 1,
        value = function()
            -- Marked for Death instantly generates 5 combo points
            return 0 -- Simplified: marked_for_death tracking removed for Hekili compatibility
        end,
    },
}, {
    -- Base combo point mechanics for Combat
    max_combo_points = function ()
        return 5 -- Maximum 5 combo points in MoP
    end,
    
    -- Combat's enhanced combo point efficiency
    combat_efficiency = function ()
        return 1.0 -- Combat doesn't get inherent combo point generation bonuses
    end,
} )

-- Talents
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    nightstalker = { 1, 1, 14062 }, -- Increases damage done while stealthed.
    subterfuge = { 1, 2, 108208 }, -- Allows abilities to be used for 3 seconds after leaving stealth.
    shadow_focus = { 1, 3, 108209 }, -- Reduces energy cost of abilities while stealthed.
    
    -- Tier 2 (Level 30) 
    deadly_throw = { 2, 1, 48673 }, -- Throws a blade that damages and slows target movement.
    nerve_strike = { 2, 2, 108210 }, -- Reduces damage done by targets affected by Kidney Shot or Cheap Shot.
    combat_readiness = { 2, 3, 74001 }, -- Defensive cooldown that reduces damage taken with consecutive hits.
    
    -- Tier 3 (Level 45)
    cheat_death = { 3, 1, 31230 }, -- Prevents fatal damage and reduces damage taken afterward.
    leeching_poison = { 3, 2, 108211 }, -- Attacks heal you for a portion of damage done.
    elusiveness = { 3, 3, 79008 }, -- Reduces damage taken when Feint is active.
    
    -- Tier 4 (Level 60)
    preparation = { 4, 1, 14185 }, -- Resets the cooldown of several rogue abilities.
    shadowstep = { 4, 2, 36554 }, -- Teleport behind target and increases damage of next ability.
    burst_of_speed = { 4, 3, 108212 }, -- Increases movement speed and removes movement impairing effects.
    
    -- Tier 5 (Level 75)
    prey_on_the_weak = { 5, 1, 131223 }, -- Increases damage against targets affected by stuns.
    paralytic_poison = { 5, 2, 108215 }, -- Attacks have a chance to stun the target.
    dirty_tricks = { 5, 3, 108216 }, -- Reduces cost of Blind and Sap.
    
    -- Tier 6 (Level 90)
    shuriken_toss = { 6, 1, 114014 }, -- Ranged attack that generates combo points.
    marked_for_death = { 6, 2, 137619 }, -- Marks target and generates 5 combo points; resets on kill.
    anticipation = { 6, 3, 114015 }, -- Can store extra combo points beyond the normal limit.
} )

-- Glyphs (Enhanced System - authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs - Combat Rogue
    [54825] = "adrenaline_rush",      -- Adrenaline Rush now also increases your movement speed by 50%
    [54760] = "killing_spree",        -- Killing Spree now has a 50% chance to not trigger a cooldown
    [54821] = "blade_flurry",         -- Blade Flurry now affects 2 additional targets
    [54832] = "slice_and_dice",       -- Slice and Dice now lasts 50% longer
    [54743] = "eviscerate",           -- Eviscerate now has a 50% chance to not consume combo points
    [54829] = "sinister_strike",      -- Sinister Strike now has a 50% chance to not trigger a cooldown
    [54754] = "backstab",             -- Backstab now has a 50% chance to not trigger a cooldown
    [54755] = "hemorrhage",           -- Hemorrhage now has a 50% chance to not trigger a cooldown
    [116218] = "shadowstep",          -- Shadowstep now has a 50% chance to not trigger a cooldown
    [125390] = "sprint",              -- Sprint now also increases your attack speed by 20%
    [125391] = "evasion",             -- Evasion now also increases your dodge chance by 20%
    [125392] = "feint",               -- Feint now also reduces damage taken by 20%
    [125393] = "stealth",             -- Stealth now also increases your movement speed by 30%
    [125394] = "vanish",              -- Vanish now also grants immunity to movement impairing effects
    [125395] = "cloak_of_shadows",    -- Cloak of Shadows now also removes all harmful effects
    
    -- Major glyphs - Utility/Defensive
    [94388] = "sap",                 -- Sap now affects all enemies within 5 yards
    [59219] = "blind",               -- Blind now affects all enemies within 5 yards
    [114235] = "gouge",              -- Gouge now affects all enemies within 5 yards
    [125396] = "kick",               -- Kick now has a 50% chance to not trigger a cooldown
    [125397] = "kidney_shot",        -- Kidney Shot now has a 50% chance to not trigger a cooldown
    [125398] = "cheap_shot",         -- Cheap Shot now has a 50% chance to not trigger a cooldown
    [125399] = "garrote",            -- Garrote now has a 50% chance to not trigger a cooldown
    [125400] = "rupture",            -- Rupture now has a 50% chance to not trigger a cooldown
    [125401] = "expose_armor",       -- Expose Armor now has a 50% chance to not trigger a cooldown
    [54828] = "pick_pocket",         -- Pick Pocket now has a 100% chance to succeed
    
    -- Major glyphs - Defensive/Survivability
    [125402] = "evasion",            -- Evasion now also increases your dodge chance by 20%
    [125403] = "feint",              -- Feint now also reduces damage taken by 20%
    [125404] = "stealth",            -- Stealth now also increases your movement speed by 30%
    [125405] = "vanish",             -- Vanish now also grants immunity to movement impairing effects
    [125406] = "cloak_of_shadows",   -- Cloak of Shadows now also removes all harmful effects
    [125407] = "shadow_dance",       -- Shadow Dance now also increases your movement speed by 50%
    [125408] = "shadow_blades",      -- Shadow Blades now also increases your attack speed by 20%
    [125409] = "preparation",        -- Preparation now also resets all cooldowns
    [125410] = "shadowstep",         -- Shadowstep now also increases your movement speed by 50%
    [125411] = "shadow_walk",        -- Shadow Walk now also increases your movement speed by 50%
    
    -- Major glyphs - Control/CC
    [125412] = "sap",                -- Sap now affects all enemies within 5 yards
    [125413] = "blind",              -- Blind now affects all enemies within 5 yards
    [125414] = "gouge",              -- Gouge now affects all enemies within 5 yards
    [125415] = "kidney_shot",        -- Kidney Shot now affects all enemies within 5 yards
    [125416] = "cheap_shot",         -- Cheap Shot now affects all enemies within 5 yards
    [125417] = "garrote",            -- Garrote now affects all enemies within 5 yards
    
    -- Minor glyphs - Visual/Convenience
    [57856] = "stealth",             -- Your stealth has enhanced visual effects
    [57862] = "vanish",              -- Your vanish has enhanced visual effects
    [57863] = "shadowstep",          -- Your shadowstep has enhanced visual effects
    [57855] = "pick_pocket",         -- Your pick pocket has enhanced visual effects
    [57861] = "lock_picking",        -- Your lock picking has enhanced visual effects
    [57857] = "distract",            -- Your distract has enhanced visual effects
    [57858] = "detect_traps",        -- Your detect traps has enhanced visual effects
    [57860] = "safe_fall",           -- Your safe fall has enhanced visual effects
    [121840] = "blur",               -- Your abilities create a blur effect
    [125418] = "shadow_walk",        -- Your movement leaves shadowy footprints
    [125419] = "floating",           -- Your spells cause you to hover slightly above the ground
    [125420] = "glow",               -- Your abilities cause you to glow with shadow energy
} )

-- Auras
spec:RegisterAuras( {
    -- Core Combat Rogue buffs
    slice_and_dice = {
        id = 5171,
        duration = function() return 6 + (6 * combo_points.current) + (talent.improved_slice_and_dice.enabled and 6 or 0) end, -- MoP Classic: 6s base + 6s per combo point + talent bonus
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
        -- Stealth: Primary spell ID in MoP Classic is 1784. Some data sources (or client tooltips) may surface
        -- an alternate stealth aura ID (115191). Include both so the engine recognizes the buff regardless
        -- of which variant is applied. This resolves buff.stealth.up returning false when the player uses
        -- the 1784 Stealth ability.
        id = 1784,
        copy = { 115191 },
        duration = 3600,
        max_stack = 1
    },
    
    -- Combat Rogue debuffs
    revealing_strike = {
        id = 84617,
        duration = 24,
        max_stack = 1
    },
    rupture = {
        id = 1943,
        duration = function() return 8 + (4 * combo_points.current) end, -- MoP Classic: 8s base + 4s per combo point
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
        duration = function() return 1 + combo_points.current end, -- MoP Classic: 1s base + 1s per combo point
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
    
    -- MoP Tier Set Bonuses
    tier14_2pc = {
        id = 123122,
        duration = 15,
        max_stack = 1
    },
    tier15_2pc = {
        id = 138151,
        duration = 10,
        max_stack = 1
    },
    tier16_2pc = {
        id = 145210,
        duration = 15,
        max_stack = 1
    },
    
    -- MoP talents and abilities
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
    find_weakness = {
        id = 91021,
        duration = 10,
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
    shuriken_toss = {
        id = 114014,
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
    combat_insight = {
        id = 74002,
        duration = 10,
        max_stack = 1
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
    bandit_guile = {
        id = 84654,
        duration = 15,
        max_stack = 3
    },
    prey_on_the_weak = {
        id = 131231,
        duration = 8,
        max_stack = 1
    },
    
    -- Rogue generic abilities
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
    bandits_guile = {
        id = 84654,
        duration = 3600,
        max_stack = 12 -- Stacks from 0-12, triggers insight buffs at 4, 8, 12
    },
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
    }
} )


-- Mists of Pandaria
spec:RegisterGear( "tier14", 85299, 85300, 85301, 85302, 85303 ) -- Heroic Malevolent Gladiator's Leather Armor
spec:RegisterGear( "tier15", 95305, 95306, 95307, 95308, 95309 ) -- Battlegear of the Thousandfold Blades
spec:RegisterGear( "tier16", 99009, 99010, 99011, 99012, 99013 ) -- Battlegear of the Barbed Assassin

spec:RegisterAuras( {
    -- Tier 14 (2-piece) - Your Sinister Strike critical strikes have a 20% chance to generate an extra combo point.
    t14_2pc_combat = {
        id = 123122,
        duration = 15,
        max_stack = 1
    },
    
    -- Tier 15 (2-piece) - Adrenaline Rush also grants 40% increased critical strike chance.
    t15_2pc_crit_bonus = {
        id = 138150,
        duration = 15,
        max_stack = 1
    },
    
    -- Tier 16 (2-piece) - Increases the damage of your Sinister Strike, Revealing Strike, and Eviscerate by 10%.
    t16_2pc_damage_bonus = {
        id = 145183,
        duration = 3600,
        max_stack = 1
    },
    
    -- Tier 16 (4-piece) - When you activate Killing Spree, you gain 30% increased attack speed for 10 sec.
    t16_4pc_attack_speed = {
        id = 145210,
        duration = 10,
        max_stack = 1
    }
} )

spec:RegisterHook( "runHandler", function( action, pool )
    if buff.stealth.up and not (action == "stealth" or action == "garrote" or action == "ambush" or action == "cheap_shot") then 
        removeBuff("stealth") 
    end
    if buff.vanish.up and not (action == "vanish" or action == "garrote" or action == "ambush" or action == "cheap_shot") then 
        removeBuff("vanish") 
    end
end )

local function IsActiveSpell( id )
    local slot = FindSpellBookSlotBySpellID( id )
    if not slot then return false end

    local _, _, spellID = GetSpellBookItemName( slot, "spell" )
    return id == spellID
end

-- Set up the state reference correctly with multiple fallbacks
local function ensureState()
    if not state then 
        state = Hekili.State 
    end
    if not state and Hekili and Hekili.State then
        state = Hekili.State
    end
    if state and state.IsActiveSpell == nil then
        state.IsActiveSpell = IsActiveSpell
    end
end

-- Call it immediately and also register as a hook for safety
ensureState()

-- Also ensure state is available in a hook for delayed initialization
-- Combined reset_precast hook to avoid conflicts
spec:RegisterHook( "reset_precast", function()
    -- Ensure state is properly initialized first
    ensureState()
    
    -- Forced distance reset on Shadowstep
    if now - action.shadowstep.lastCast < 1.5 then
        setDistance(5)
    end

    -- Force sync Revealing Strike if there's a mismatch between game and Hekili state
    if UnitExists("target") then
        for i = 1, 40 do
            local name, _, _, _, _, expires, caster, _, _, spellID = UnitDebuff("target", i)
            if not name then break end
            if spellID == 84617 and caster == "player" then -- Revealing Strike
                local gameRemains = expires > 0 and (expires - GetTime()) or 0
                if gameRemains > 0 and (not debuff.revealing_strike.up or debuff.revealing_strike.remains <= 0) then
                    applyDebuff("target", "revealing_strike", gameRemains)
                end
                break
            end
        end
    end

    -- Force sync Rupture if there's a mismatch
    if UnitExists("target") then
        for i = 1, 40 do
            local name, _, _, _, _, expires, caster, _, _, spellID = UnitDebuff("target", i)
            if not name then break end
            if spellID == 1943 and caster == "player" then -- Rupture
                local gameRemains = expires > 0 and (expires - GetTime()) or 0
                if gameRemains > 0 and (not debuff.rupture.up or debuff.rupture.remains <= 0) then
                    applyDebuff("target", "rupture", gameRemains)
                end
                break
            end
        end
    end

    -- Auto-sync missing player buffs
    for i = 1, 40 do
        local name, _, _, _, _, expires, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        
        -- Sync missing buffs based on spell IDs
        local gameRemains = expires > 0 and (expires - GetTime()) or 0
        if gameRemains > 0 then
            if spellID == 5171 and not buff.slice_and_dice.up then -- Slice and Dice
                applyBuff("slice_and_dice", gameRemains)
            elseif spellID == 13750 and not buff.adrenaline_rush.up then -- Adrenaline Rush
                applyBuff("adrenaline_rush", gameRemains)
            elseif spellID == 51690 and not buff.killing_spree.up then -- Killing Spree
                applyBuff("killing_spree", gameRemains)
            elseif spellID == 13877 and not buff.blade_flurry.up then -- Blade Flurry
                applyBuff("blade_flurry", gameRemains)
            elseif spellID == 121471 and not buff.shadow_blades.up then -- Shadow Blades
                applyBuff("shadow_blades", gameRemains)
            end
        end
    end

    -- MoP tier bonus handling
    if set_bonus.tier14_2pc > 0 then
        -- T14 2pc - Sinister Strike crits have 20% chance to generate an extra combo point
        if action.sinister_strike.lastCast > now - 5 and GetTime() % 1 < 0.2 then
            gain(1, "combo_points")
        end
    end
    
    if set_bonus.tier15_2pc > 0 and buff.adrenaline_rush.up then
        -- T15 2pc - Adrenaline Rush grants 40% increased critical strike chance
        applyBuff("t15_2pc_crit_bonus")
    end

    if set_bonus.tier16_2pc > 0 then
        -- T16 2pc - Increases the damage of your Sinister Strike, Revealing Strike, and Eviscerate by 10%
        applyBuff("t16_2pc_damage_bonus")
    end
    
    if set_bonus.tier16_4pc > 0 and action.killing_spree.lastCast > now - 1 then
        -- T16 4pc - When you activate Killing Spree, you gain 30% increased attack speed for 10 sec
        applyBuff("t16_4pc_attack_speed", 10)
    end
end )

-- MoP Talent Detection Hook
spec:RegisterHook( "PLAYER_TALENT_UPDATE", function()
    if not GetTalentInfo then return end
    
    local specGroup = GetActiveSpecGroup and GetActiveSpecGroup() or 1
    
    -- Debug output for talent detection
    -- if Hekili.ActiveDebug then
    --     print("=== MOP TALENT DETECTION DEBUG ===")
    --     for tier = 1, 6 do
    --         for column = 1, 3 do
    --             local id, name, icon, selected = GetTalentInfo(tier, column, specGroup)
    --             if selected then
    --                 print("SELECTED TALENT: Tier " .. tier .. ", Column " .. column .. " - " .. (name or "Unknown") .. " (ID: " .. (id or "nil") .. ")")
    --             end
    --         end
    --     end
    --     print("=== END TALENT DEBUG ===")
    -- end
end )

-- State Expressions for MoP Combat Rogue
-- Note: combo_points is automatically available via RegisterResource(4)

spec:RegisterStateExpr("bandit_guile_stack", function()
    if buff.deep_insight.up then
        return 3
    elseif buff.moderate_insight.up then
        return 2
    elseif buff.shallow_insight.up then
        return 1
    else
        return 0
    end
end)

spec:RegisterStateExpr("in_combat", function()
    return combat == 1
end)

spec:RegisterStateExpr("effective_combo_points", function()
    local cp = combo_points.current or 0
    -- Account for Anticipation talent
    if talent.anticipation.enabled and buff.anticipation.up then
        return cp + buff.anticipation.stack
    end
    return cp
end)

-- T16H compatibility: anticipation_charges for SimC APL
spec:RegisterStateExpr("anticipation_charges", function()
    return buff.anticipation.stack or 0
end)

spec:RegisterStateExpr("energy_regen_combined", function()
    local regen = GetPowerRegen()
    -- Add energy regen from Adrenaline Rush
    if buff.adrenaline_rush.up then
        regen = regen * 2
    end
    return regen
end)

spec:RegisterStateExpr("energy_time_to_max", function()
    if energy_regen_combined == 0 then return 999 end
    return (UnitPowerMax("player", 3) - UnitPower("player", 3)) / energy_regen_combined
end)

-- Calculate cooldown reduction from Restless Blades for Combat Rogues
spec:RegisterStateFunction("restless_blades_cdr", function(cp_spent)
    if not talent.restless_blades.enabled then return 0 end
    return cp_spent * 2 -- 2 seconds per combo point in MoP
end)

-- Function to calculate duration of Slice and Dice based on combo points
spec:RegisterStateFunction("slice_and_dice_duration", function(cp)
    if not cp or cp == 0 then return 0 end
    -- Base duration: 12 seconds + 6 seconds per combo point
    local duration = 12 + (cp * 6)
    -- Add 6 seconds if the improved slice and dice talent is enabled
    if talent.improved_slice_and_dice and talent.improved_slice_and_dice.enabled then
        duration = duration + 6
    end
    return duration
end)

-- Helper function to calculate rupture duration based on combo points
spec:RegisterStateFunction("rupture_duration", function(cp)
    if not cp or cp == 0 then return 0 end
    -- Base duration is 8 seconds + 4 seconds per combo point
    return 8 + (cp * 4)
end)

-- Helper function to detect if we're stealthed or have stealth-like buffs
spec:RegisterStateExpr("is_stealthed", function()
    return buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up
end)

-- Stealth state for keybinding system
spec:RegisterStateExpr("stealthed", function()
    return {
        all = buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up
    }
end)

-- Intelligent positioning logic for Combat Rogue
spec:RegisterStateExpr("behind_target", function()
    -- Intelligent positioning logic for Combat
    -- Stealth abilities work regardless of positioning
    if buff.stealth.up or buff.vanish.up or buff.shadow_dance.up or buff.subterfuge.up then
        return true -- Stealth negates positioning requirements
    end
    
    -- In group content, assume tank has aggro and we can be behind
    if group then
        return true -- Tank should have aggro in groups
    end
    
    -- Solo PvE: assume we can position behind mobs
    if target.exists and not target.is_player then
        return true -- PvE mobs, can usually get behind
    end
    
    -- PvP or uncertain cases: use time-based deterministic positioning
    -- This prevents blocking abilities while being somewhat realistic
    local time_factor = (query_time % 10) / 10 -- 0-1 based on time
    return time_factor > 0.3 -- 70% of time cycles we're "behind"
end)

-- Combat Rogue specific cooldown reduction tracking (for Killing Spree, Adrenaline Rush)
spec:RegisterStateFunction("update_rogue_cooldowns", function()
    -- Implementation depends on Hekili's internal handling of cooldown reduction
    -- This is a placeholder for now
end)

-- Abilities
spec:RegisterAbilities( {
    -- Basic Attacks
    
    -- A strike that deals Physical damage and awards 1 combo point.
    sinister_strike = {
        id = 1752,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            -- Generate combo points
            gain(1, "combo_points")
            
            -- MoP mechanics - chance for extra combo point
            if GetTime() % 1 < 0.2 then -- 20% chance
                gain(1, "combo_points")
            end
            
            -- Combat Potency for off-hand attacks (simulated)
            if GetTime() % 1 < 0.3 then -- 30% chance to simulate off-hand
                if GetTime() % 1 < 0.2 then -- 20% chance for Combat Potency
                    gain(15, "energy")
                end
            end
            
            -- Bandit's Guile tracking - MoP: Every Sinister Strike and Revealing Strike builds stacks
            if not buff.bandits_guile.up then
                applyBuff("bandits_guile", 15, 1) -- Start with 1 stack, 15 second duration
            else
                if buff.bandits_guile.stack < 4 then
                    addStack("bandits_guile", 15, 1) -- Add stack and refresh duration
                end
            end
            
            -- Cycle through Insight buffs based on stack count
            if buff.bandits_guile.stack == 4 and not buff.shallow_insight.up then
                applyBuff("shallow_insight", 15) -- 10% damage increase
                removeBuff("moderate_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 8 and not buff.moderate_insight.up then
                applyBuff("moderate_insight", 15) -- 20% damage increase
                removeBuff("shallow_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 12 and not buff.deep_insight.up then
                applyBuff("deep_insight", 15) -- 30% damage increase
                removeBuff("shallow_insight")
                removeBuff("moderate_insight")
                -- Reset the stack counter to maintain Deep Insight
                buff.bandits_guile.stack = 12
            end
            
            -- Tier bonuses
            if set_bonus.tier14_2pc > 0 and GetTime() % 1 < 0.2 then
                applyBuff("t14_2pc_combat")
            end
        end,
    },
    
    -- A strike that deals Physical damage and increases the damage of your finishing moves against the target by 35% for 24 sec.
    revealing_strike = {
        id = 84617,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "revealing_strike")
            gain(1, "combo_points")
            
            -- Bandit's Guile tracking - MoP: Every Sinister Strike and Revealing Strike builds stacks
            if not buff.bandits_guile.up then
                applyBuff("bandits_guile", 15, 1) -- Start with 1 stack, 15 second duration
            else
                if buff.bandits_guile.stack < 4 then
                    addStack("bandits_guile", 15, 1) -- Add stack and refresh duration
                end
            end
            
            -- Cycle through Insight buffs based on stack count
            if buff.bandits_guile.stack == 4 and not buff.shallow_insight.up then
                applyBuff("shallow_insight", 15) -- 10% damage increase
                removeBuff("moderate_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 8 and not buff.moderate_insight.up then
                applyBuff("moderate_insight", 15) -- 20% damage increase
                removeBuff("shallow_insight")
                removeBuff("deep_insight")
            elseif buff.bandits_guile.stack == 12 and not buff.deep_insight.up then
                applyBuff("deep_insight", 15) -- 30% damage increase
                removeBuff("shallow_insight")
                removeBuff("moderate_insight")
                -- Reset the stack counter to maintain Deep Insight
                buff.bandits_guile.stack = 12
            end
        end,
    },
    
    -- Finishing move that causes damage per combo point and consumes up to 5 combo points.
    eviscerate = {
        id = 2098,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points and track for talents
            spend(cp, "combo_points")
            state.last_finisher_cp = cp
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Finishing move that causes damage over time. Lasts longer per combo point.
    rupture = {
        id = 1943,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            
            -- MoP Classic: 8 seconds base + 4 seconds per combo point
            applyDebuff("target", "rupture", 8 + (4 * cp))
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points and track for talents
            spend(cp, "combo_points")
            state.last_finisher_cp = cp
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Finishing move that increases attack speed by 40%. Lasts longer per combo point.
    slice_and_dice = {
        id = 5171,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            
            -- MoP Classic: 6 seconds base + 6 seconds per combo point
            applyBuff("slice_and_dice", 6 + (6 * cp))
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points and track for talents
            spend(cp, "combo_points")
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Major Cooldowns
    
    -- Increases energy regeneration rate by 100% for 15 sec.
    adrenaline_rush = {
        id = 13750,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("adrenaline_rush")
            
            -- Tier 15 2pc - Adrenaline Rush also grants 40% increased critical strike chance
            if set_bonus.tier15_2pc > 0 then
                applyBuff("t15_2pc_crit_bonus")
            end
        end,
    },
    
    -- Increases your attack speed by 20% for 15 sec. While active, your successful attacks strike an additional nearby opponent.
    blade_flurry = {
        id = 13877,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,

        handler = function ()
            if buff.blade_flurry.up then
                removeBuff("blade_flurry")
            else
                applyBuff("blade_flurry")
            end
        end,
    },
    
    -- You attack with both weapons for a total of 7 attacks over 3 sec, while jumping from target to target. Can hit up to 5 enemies within 10 yards. The damage of each attack is based on the weapons you have equipped. Cannot be used with ranged weapons.
    killing_spree = {
        id = 51690,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = true,

        handler = function ()
            applyBuff("killing_spree")
            
            -- Tier 16 4pc - When you activate Killing Spree, you gain 30% increased attack speed for 10 sec
            if set_bonus.tier16_4pc > 0 then
                applyBuff("t16_4pc_attack_speed", 10)
            end
        end,
    },
    
    -- For the next 12 sec, your successful melee attacks have a 100% chance to grant you an extra combo point.
    shadow_blades = {
        id = 121471,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "shadow",
        
    
        startsCombat = false,

        handler = function ()
            applyBuff("shadow_blades")
        end,
    },
    
    -- Utility Abilities
    
    -- Redirect your combo points from your last target to your current target.
    redirect = {
        id = 73981,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            -- This is a placeholder since Hekili doesn't track combo points per target
        end,
    },
    
    -- Reduces all damage taken by 30% for 5 sec.
    feint = {
        id = 1966,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "physical",

        spend = 20,
        spendType = "energy",
        
        startsCombat = false,

        handler = function ()
            applyBuff("feint")
            
            -- Elusiveness talent increases damage reduction
            if talent.elusiveness.enabled then
                applyBuff("elusiveness")
            end
        end,
    },
    
    -- Increases your movement speed by 70% for 8 sec. Usable while stealthed.
    sprint = {
        id = 2983,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,

        handler = function ()
            applyBuff("sprint")
        end,
    },
    
    -- Strikes the target, dealing Physical damage and interrupting spellcasting, preventing any spell in that school from being cast for 5 sec.
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
        handler = function () interrupt() end,
    },    -- Increases your dodge chance by 50% for 10 sec.
    evasion = {
        id = 5277,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        
        toggle = "defensives",
        startsCombat = false,

        handler = function ()
            applyBuff("evasion")
        end,
    },    -- Allows the rogue to enter stealth mode. Lasts until cancelled.
    stealth = {
        id = 1784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        
        startsCombat = false,
        
        usable = function() 
            return not buff.stealth.up and not buff.vanish.up and not buff.shadow_dance.up 
                and not buff.shadowmeld.up and not in_combat
        end,

        handler = function ()
            applyBuff("stealth")
            
            -- Apply Stealth-related buffs
            if talent.subterfuge.enabled then
                applyBuff("subterfuge")
            end
            
            if talent.shadow_focus.enabled then
                applyBuff("shadow_focus")
            end
        end,
    },
    
    -- Instantly enter stealth, but breaks when damaged. For 3 sec after you vanish, damage and harmful effects received will not break stealth.
    vanish = {
        id = 1856,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        
    
        startsCombat = false,

        handler = function ()
            applyBuff("vanish")
            applyBuff("stealth")
            
            -- Apply Stealth-related buffs
            if talent.subterfuge.enabled then
                applyBuff("subterfuge")
            end
            
            if talent.shadow_focus.enabled then
                applyBuff("shadow_focus")
            end
            
            -- Reset threat
            setCooldown("vanish", 120)
        end,
    },
    
    -- Strikes an enemy, dealing Physical damage and incapacitating the target for 4 sec. Must be facing the target. Any damage caused will revive the target. Awards 1 combo point.
    gouge = {
        id = 1776,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "physical",

        spend = 45,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "gouge")
            gain(1, "combo_points")
        end,
    },
    
    -- Blinds the target, causing it to wander disoriented for 1 min. Any damage caused will remove the effect.
    blind = {
        id = 2094,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        school = "physical",

        spend = function() return talent.dirty_tricks.enabled and 0 or 15 end,
        spendType = "energy",
        
    
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "blind")
        end,
    },
    
    -- Finishing move that stuns the target. Lasts longer per combo point.
    kidney_shot = {
        id = 408,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        school = "physical",

        spend = 25,
        spendType = "energy",
        
    
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            -- MoP Classic: 1 second base + 1 second per combo point
            applyDebuff("target", "kidney_shot", 1 + cp)
            
            -- Nerve Strike talent
            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike")
            end
            
            -- Prey on the Weak talent
            if talent.prey_on_the_weak.enabled then
                applyDebuff("target", "prey_on_the_weak")
            end
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points and track for talents
            spend(cp, "combo_points")
            state.last_finisher_cp = cp
        end,
    },
    
    -- Creates a cloud of dense smoke in a 10-yard radius around the Rogue for 5 sec. Enemies are unable to target into or out of the smoke cloud.
    smoke_bomb = {
        id = 76577,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",
        
        
        startsCombat = false,

        handler = function ()
            applyBuff("smoke_bomb")
        end,
    },
    
    -- Provides a moment of magic immunity, instantly removing all harmful spell effects. The cloak lingers, causing you to resist harmful spells for 5 sec.
    cloak_of_shadows = {
        id = 31224,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        school = "physical",
        
        toggle = "defensives",
        startsCombat = false,

        handler = function ()
            applyBuff("cloak_of_shadows")
            removeDebuff("target", "all")
        end,
    },    -- Disarm the enemy's weapon for 10 sec.
    dismantle = {
        id = 51722,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",
        
        toggle = "interrupts",
        startsCombat = true,

        handler = function ()
            applyDebuff("target", "dismantle")
        end,
    },
    
    -- MoP-specific abilities
    
    -- Finishing move that deals damage over time to up to 8 nearby enemies. Deals more damage per combo point.
    crimson_tempest = {
        id = 121411,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            applyDebuff("target", "crimson_tempest", 6 + 2 * cp)
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
            
            -- Handle Anticipation talent
            if talent.anticipation.enabled and buff.anticipation.stack > 0 then
                gain(1, "combo_points")
                removeStack("anticipation")
            end
        end,
    },
    
    -- Talent: Throw a deadly blade at the target, dealing Physical damage and generating 1 combo point. Can be used at range.
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

        handler = function ()
            gain(1, "combo_points")
        end,
    },
    
    -- Talent: Marks the target, instantly generating 5 combo points. When the target dies, the cooldown is reset.
    marked_for_death = {
        id = 137619,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "physical",
        
        talent = "marked_for_death",
        startsCombat = false,

        handler = function ()
            gain(5, "combo_points")
            applyDebuff("target", "marked_for_death", 60)
        end,
    },
    
    -- Talent: You gain 5 stacks of Anticipation, allowing combo points from your abilities to be stored beyond the normal maximum.
    anticipation = {
        id = 115189,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",
        
        talent = "anticipation",
        startsCombat = false,

        handler = function ()
            applyBuff("anticipation", nil, 5)
        end,
    },
    
    -- Ambushes the target, causing Physical damage. Must be stealthed. Awards 2 combo points.
    ambush = {
        id = 8676,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 60,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            gain(2, "combo_points")
            
            -- Subterfuge talent extends stealth after abilities
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },
    
    -- Garrote the enemy, causing Bleed damage over 18 sec. Awards 1 combo point.
    garrote = {
        id = 703,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 45,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            applyDebuff("target", "garrote")
            gain(1, "combo_points")
            
            -- Subterfuge talent extends stealth after abilities
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },
    
    -- Stuns the target for 4 sec. Must be stealthed. Awards 2 combo points.
    cheap_shot = {
        id = 1833,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 40,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            applyDebuff("target", "cheap_shot")
            gain(2, "combo_points")
            
            -- Nerve Strike talent
            if talent.nerve_strike.enabled then
                applyDebuff("target", "nerve_strike")
            end
            
            -- Prey on the Weak talent
            if talent.prey_on_the_weak.enabled then
                applyDebuff("target", "prey_on_the_weak")
            end
            
            -- Subterfuge talent extends stealth after abilities
            if not talent.subterfuge.enabled then
                removeBuff("stealth")
                removeBuff("vanish")
            end
        end,
    },
    
    -- Talent: Step through the shadows to appear behind your target and gain 70% increased movement speed for 2 sec.
    shadowstep = {
        id = 36554,
        cast = 0,
        cooldown = 20,
        gcd = "off",
        school = "physical",
        
        talent = "shadowstep",
        startsCombat = false,

        handler = function ()
            applyBuff("shadowstep")
            setDistance(5)
        end,
    },
    
    -- Talent: Removes all movement impairing effects and increases your movement speed by 70% for 4 sec.
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

        handler = function ()
            applyBuff("burst_of_speed")
            removeDebuff("player", "movement")
        end,
    },
    
    -- Talent: You become shrouded in a veil of shadows for 3 min, reducing your threat in combat. Increases your movement speed by 70% and allows the use of stealth abilities for 3 sec.
    preparation = {
        id = 14185,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "physical",
        
        talent = "preparation",
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            setCooldown("vanish", 0)
            setCooldown("sprint", 0)
            setCooldown("evasion", 0)
        end,
    },
    
    -- A useful ability for rogues to recharge health.
    recuperate = {
        id = 73651,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 30,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            applyBuff("recuperate", 6 + 6 * cp)
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
        end,
    },
    
    -- Talent: When activated, will begin reducing damage taken by 10%. Each attack against you increases the damage reduction by an additional 10%. Lasts 20 sec or 5 attacks.
    combat_readiness = {
        id = 74001,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        
        talent = "combat_readiness",
        toggle = "defensives",
        startsCombat = false,

        handler = function ()
            applyBuff("combat_readiness")
        end,
    },
    
    -- Stuns and blinds nearby targets for 8 sec. Also interrupts spellcasting and prevents any spell in that school from being cast for 3 sec.
    shroud_of_concealment = {
        id = 114018,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",
        
        toggle = "cooldowns",
        startsCombat = false,

        handler = function ()
            applyBuff("shroud_of_concealment")
        end,
    },
    
    -- Finishing move that heals you for a moderate amount every 3 sec. Lasts longer per combo point.
    deadly_throw = {
        id = 26679,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 35,
        spendType = "energy",
        
        startsCombat = true,
        
        usable = function() return combo_points.current > 0, "requires combo points" end,

        handler = function ()
            local cp = combo_points.current
            applyDebuff("target", "deadly_throw")
            
            -- Apply Restless Blades cooldown reduction
            local cdr = restless_blades_cdr(cp)
            if cdr > 0 then
                reduceCooldown("adrenaline_rush", cdr)
                reduceCooldown("killing_spree", cdr)
                reduceCooldown("sprint", cdr)
                reduceCooldown("shadow_blades", cdr)
                reduceCooldown("redirect", cdr)
            end
            
            -- Consume combo points
            spend(cp, "combo_points")
        end,
    },
    
    -- Talent: Transfers all threat to the targeted party or raid member, causing your threat to be equal to the target's threat. Lasts 6 sec.
    tricks_of_the_trade = {
        id = 57934,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",
        
        startsCombat = false,

        handler = function ()
            applyBuff("tricks_of_the_trade")
        end,
    },
    
    -- Immobilizes the target in place for 1 min and deals damage over time. Only affects Humanoids and Beasts. Only usable while stealthed.
    sap = {
        id = 6770,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function() return talent.dirty_tricks.enabled and 0 or 35 end,
        spendType = "energy",
        
        startsCombat = false,
        
        usable = function() return is_stealthed, "requires stealth" end,

        handler = function ()
            applyDebuff("target", "sap")
        end,
    },
    
    -- Auto Attack - basic melee auto attacks
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",

        startsCombat = true,

        handler = function ()
            -- Enable auto attacks if not already active
        end,
    },
    
    -- Shiv - instant attack that deals damage and applies poison
    shiv = {
        id = 5938,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 20,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            -- Shiv applies poison and deals damage
            gain(1, "combo_points")
        end,
    },
    
    -- Fan of Knives - AoE ability that throws knives at all nearby enemies
    fan_of_knives = {
        id = 51723,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 50,
        spendType = "energy",
        
        startsCombat = true,

        handler = function ()
            -- Fan of Knives hits all enemies within 8 yards
            gain(1, "combo_points")
        end,
    },
    
    -- Jade Serpent Potion - MoP agility potion
    jade_serpent_potion = {
        id = 76089,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        
        usable = function() return not combat and not buff.jade_serpent_potion.up end,

        handler = function ()
            applyBuff("jade_serpent_potion", 25)
        end,
    },
} )

spec:RegisterRanges( "shuriken_toss", "throw", "deadly_throw" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 2,
    cycle = false,

    nameplates = true,
    nameplateRange = 8,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "virmen_bite_potion", -- MoP-era agility potion

    package = "Combat"
} )

spec:RegisterSetting( "use_killing_spree", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 51690 ) ), -- Killing Spree
    desc = "If checked, Killing Spree will be recommended based on the Combat Rogue priority. If unchecked, it will not be recommended.",
    type = "toggle",
    width = "full"
} )

-- Optional: Avoid casting Killing Spree while Adrenaline Rush is active (can cause energy waste)
spec:RegisterSetting( "avoid_killing_spree_during_ar", true, {
    name = strformat( "Avoid %s during %s", Hekili:GetSpellLinkWithTexture( 51690 ), Hekili:GetSpellLinkWithTexture( 13750 ) ), -- KS during AR
    desc = "If checked, Killing Spree will not be recommended while Adrenaline Rush is active.",
    type = "toggle",
    width = "full"
} )

-- Optional: Allow auto-toggling Blade Flurry based on enemy count
spec:RegisterSetting( "auto_blade_flurry", true, {
    name = strformat( "Auto-toggle %s", Hekili:GetSpellLinkWithTexture( 13877 ) ), -- Blade Flurry
    desc = "If checked, Blade Flurry is toggled on for cleave and off for single-target.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "bandits_guile_threshold", 3, {
    name = strformat( "Bandit's Guile Threshold for Eviscerate" ),
    desc = "Minimum Bandit's Guile stack level before recommending Eviscerate (0 = None, 1 = Shallow, 2 = Moderate, 3 = Deep)",
    type = "range",
    min = 0,
    max = 3,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "blade_flurry_toggle", "aoe", {
    name = strformat( "%s Toggle", Hekili:GetSpellLinkWithTexture( 13877 ) ), -- Blade Flurry
    desc = "Select when Blade Flurry should be recommended:",
    type = "select",
    values = {
        aoe = "Only in AoE",
        always = "Always",
        never = "Never"
    },
    width = 1.5
} )

spec:RegisterSetting( "anticipation_management", true, {
    name = strformat( "Manage %s", Hekili:GetSpellLinkWithTexture( 114015 ) ), -- Anticipation
    desc = "If checked, the addon will optimize combo point usage to avoid wasting combo points when using the Anticipation talent.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "allow_shadowstep", true, {
    name = strformat( "Allow %s", Hekili:GetSpellLinkWithTexture( 36554 ) ), -- Shadowstep
    desc = "If checked, Shadowstep may be recommended for mobility and positioning. If unchecked, it will only be recommended for damage bonuses.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "use_tricks_of_the_trade", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 57934 ) ), -- Tricks of the Trade
    desc = "If checked, Tricks of the Trade will be recommended based on the Combat Rogue priority. If unchecked, it will not be recommended automatically.",
    type = "toggle",
    width = "full"
} )

spec:RegisterPack( "Combat", 20251009, [[Hekili:fNvBVTnos4FlgfqjbBQxlzl3TlSdW1E42DdUDrXPE3hLeTeTTG1BhfvkcGH(TFZqQxOKPKtslWv0TRTi5mpZmpCEXY109RUoHeo19VSwyzBUyXhNBzTCT9sxh(Z5uxNCsWjYb4dPKe4F)CwYochF8ZXzKq84fzLSayjxNDLrX8)i1DNgzATAPLRdPKFmJ564KuUNfDY15yuyivEcArGRZxpgvu5J)hPYVw3v(z7HVhWJYsR8JJk4WY7Zyv()o9uuC0CxhXdrWSpknQ4iLbF(VeghnLSlMg6(jxNaweNYIiGPffCQWJrtirGe3u5Bv5Bu5ZjSdu(CEuc1JN5fgbQ(HTWQRflFReepr9OP0KiArZrpFUYFwL)UY97NVlMes92hxYyppVmVY)oWQfq31HvMZlzuPTYIYLp9RMR)9kF0XMv5)LSOuEL))O2mkC5GxCu7yiCqW(bbwdZ4ZH9LuKL6XPj50c0U6z1OH1HTbBg17suVnRtFkQiGYWWQcwW95Ca0pSqMwNEZ53ts9Y27DkfaCbgWsPEbHUo2VaVXV1OGIRz8RM2FDzCxj4qFIsayDWRGdut6fEGcmMacQz9HUHq6EszmFAMxnhjllmUecjmkiDjbsh5dq4QfDiipt8)BmXMhFcSQ(OrcCTaOHN(ebzycgkqxcYYIdZ(wAZJLUi0Pw5VwfbmAobcf1Wy1eE6ea)qezH06e6S4ibuIN4ksbO6o5EKKgcb3I4mEZxaXB)Js8chU3(s2ZOyx)dtSWfuk7eWzqX(HrflsFp8SiCQ6mjSaskgSzmAQ4g3VmnVzisuajjeKbrCRIvwhxhLvH38vWbqNtpr5Mn()2Vdi6J))erwdqKfIiZfJcjnjOfPVfu8XtqlX1Oz3nEbz2vxtBcTpHBaYRl2bOPsE275zhoelYZyAQEFMKSdCydUrBovwnK1c3unx0uNkaZF6LJPpL2XYwJKtIb22CskKmmkxCvEETyfNwDbVGJy0QveDUknrFm)XO6F13V(xj0F7FLkQtG1GzFwqzrpbQLn2cwL7MwluTWgXwUdCZ7lpq7j0MJH8Rp27CZUoIM9AK(AP0viBYC0APz)hXsv(FlId)7FtXvw5xuMNNXe5zmhV(GI)WEHAnMyzTrOcGKYETC)aF0wP4PkvrC(XtURaHL2VOeXdIUc5pEwEPWIJcOEqLgiduaTRGxxhDTS8X3PPTs6byhr8cVdqtW05fCO3vrPetZ6kSQ3ie9Q0lO2xlAdUo4wWliaj5Vl(Omm)jHMVbe7VH6gAFoLtp0vL2C8kt10Wec7efkqMX8cPe(XEKXlVoJwvBxMd7Bs0Mj81Ew3qfiG1WQDAm52o)(5MoIbECECexhfxTr7up5N9WjduT4lYmz)9MzsgkLxRVQdbHJNCuQU2MrNXWcTVatz2vGC7fNqkn3d4SrhoYBRd32Yx)RvD07AUlUx9wEnjE8kc1nxo(Pxo0N0o(g2J7Wc9VaxsBItzEt9EazUF9RP24lWmEFFU)OXpUO14a5WXndamOT9(1ZhwoVnpahipWfe14S01kxaZ7nzd(x5k903jNiP(lvSdsKXLENNGwLXLB(jbw668nclfUwuGd9JjTsWQt1d2FtR38MkFg9)wgXqgDrgwzbBEkbgefEaWMsb208Qh)NqYFGq9Rv()706kD4gKOceijpp(zmmcd5EdS)Qh)JKMnTAWVUaSmyh50aaUyd75SS9qIvxN3v5)VYous)v5eQeaU3(NzFbOkZTNBcvPRE8Dy(4cuQO4CIs(CL)xJW8wMRXFWcwwuqLFTery8o4eFPXAHeAcGuu9OerfZB9e)02FEFmP4094pmZwOqmMIbMSPa8kJTFySN6TtjEji3LHrNuC(t6ihs1tDFmLFKeVfI1HXpRF)s6T(1QjT6xCix6(O9BVwbj9APhL7fjgPF)pf)oadD5T2ekjDdSF(8LdXSz1cvbGZK3tGDdoJsDw)zWngz(7hw3tOLfup4(yY94urBfJjlmwafBxC(S(mWkNVBm4x3XAhZ9vDS(J3IhvMDEZugvZSNTU(HAOwXxoDP2GYwRRRlRFK6civxBGV(rKU5gryClUu3iOpS1YyMUHpV785bBDJLH2n2lIigSubKVGXfupVKC2qcEWCHXTQvh3Seq1eDKyORrGnlrBzKXjhi)vVf5V6o4pg3E7edLzm6iIg1uwRf31P7lhAREBpS9JI9nBkDn76sz9I7URFYeLHVuUiz3JC3Z91gKS7ra6BIkIAP9O3OBzlVL5p6bWlstpX8vBSAPf6x302yS5U2AAAOsCEy7QE(Z3qHNbmXTMgt1Q)DkETx1imQOCqBU3JDDUTTPteZ9GK9B5YX2vgZUIHCfa10XUOQ2e6VMEnyuKZNNEmeWrBE(SoOdXu95nGQP63)YRBm98U13gxVqh0riR75nfUTFFVbnFuHqm272OR3MwyGTWP(EtUV(1MS1gb4WAfR0lHHXwzQHUxeYgl9NBW77ycBO9Tv1jOgAHWtlERxxQwJllIcf8wBCrLTZN1xeuR6g8IS05O(GX1E9yqXCTcx5TGHJ14()(]] )
