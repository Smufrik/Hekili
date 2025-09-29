if not Hekili or not Hekili.NewSpecialization then return end
-- DruidGuardian.lua
-- December 2024 - Rebuilt from retail structure for MoP compatibility

local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then 
    return 
end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization(104, true)

-- Local wrappers to satisfy linter and forward to state helpers if available.
local function shift( form )
    if state and state.shift then return state.shift( form ) end
end

local function unshift()
    if state and state.unshift then return state.unshift() end
end

local function interrupt()
    if state and state.interrupt then return state.interrupt() end
end

spec.name = "Guardian"
spec.role = "TANK"
spec.primaryStat = 2 -- Agility

-- Use MoP power type numbers instead of Enum
-- Energy = 3, ComboPoints = 4, Rage = 1, Mana = 0 in MoP Classic
spec:RegisterResource( 1 ) -- Rage (primary for Guardian)
spec:RegisterResource( 0 ) -- Mana (for healing spells)
spec:RegisterResource( 3 ) -- Energy (for Heart of the Wild cat form)
spec:RegisterResource( 4 ) -- ComboPoints (for Heart of the Wild cat form)


-- Talents (MoP system - different from retail)
spec:RegisterTalents( {
    -- Row 1 (15)
    feline_swiftness      = { 1, 1, 131768 },
    displacer_beast       = { 1, 2, 102280 },
    wild_charge           = { 1, 3, 102401 },

    -- Row 2 (30)
    yseras_gift           = { 2, 1, 145108 },
    renewal               = { 2, 2, 108238 },
    cenarion_ward         = { 2, 3, 102351 },

    -- Row 3 (45)
    faerie_swarm          = { 3, 1, 102355 },
    mass_entanglement     = { 3, 2, 102359 },
    typhoon               = { 3, 3, 132469 },

    -- Row 4 (60)
    soul_of_the_forest    = { 4, 1, 158477 },
    incarnation           = { 4, 2, 102558 },
    force_of_nature       = { 4, 3, 106737 },

    -- Row 5 (75)
    disorienting_roar     = { 5, 1, 99    },
    ursols_vortex         = { 5, 2, 102793 },
    mighty_bash           = { 5, 3, 5211   },

    -- Row 6 (90)
    heart_of_the_wild     = { 6, 1, 108292 },
    dream_of_cenarius     = { 6, 2, 108373 },
    natures_vigil         = { 6, 3, 124974 },

    -- Extras treated like toggles here
    savage_defense        = { 0, 0, 62606 },
} )

-- Glyphs disabled for Guardian (simplified)

-- Gear Sets
spec:RegisterGear( "tier13", 78699, 78700, 78701, 78702, 78703, 78704, 78705, 78706, 78707, 78708 )
spec:RegisterGear( "tier14", 85304, 85305, 85306, 85307, 85308 )
spec:RegisterGear( "tier15", 95941, 95942, 95943, 95944, 95945 )
spec:RegisterGear( "tier16", 99344, 99345, 99346, 99347, 99348 )

-- T14 Set Bonuses
spec:RegisterSetBonuses( "tier14_2pc", 123456, 1, "Mangle has a 10% chance to apply 2 stacks of Lacerate." )
spec:RegisterSetBonuses( "tier14_4pc", 123457, 1, "Savage Defense also provides 20% dodge chance for 6 sec." )

-- T15 Set Bonuses  
spec:RegisterSetBonuses( "tier15_2pc", 123458, 1, "Your melee critical strikes reduce the cooldown of Enrage by 2 sec." )
spec:RegisterSetBonuses( "tier15_4pc", 123459, 1, "Frenzied Regeneration also reduces damage taken by 20%." )

-- T16 Set Bonuses
spec:RegisterSetBonuses( "tier16_2pc", 123460, 1, "Mangle critical strikes grant 1500 mastery for 8 sec." )
spec:RegisterSetBonuses( "tier16_4pc", 123461, 1, "Thrash periodic damage has a chance to reset the cooldown of Mangle." )

-- Auras
spec:RegisterAuras( {
    -- Enrage - MoP Guardian ability
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
    },

    -- Savage Defense - MoP Guardian ability
    savage_defense = {
        id = 132402,
        duration = 6,
        max_stack = 1,
    },

    -- Tooth and Claw buff - MoP Guardian talent
    tooth_and_claw = {
        id = 135286,
        duration = 10,
        max_stack = 2,
    },

    -- Tooth and Claw debuff - MoP Guardian talent
    tooth_and_claw_debuff = {
        id = 135601,
        duration = 15,
        max_stack = 1,
    },

    -- Vengeance buff for Guardian Druid
    vengeance = {
        id = 132365,
        duration = 20,
        max_stack = 1,
        generate = function(t)
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 132365)
            
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
        end,
    },
    
    -- Bear Form
    bear_form = {
        id = 5487,
        duration = 3600,
        max_stack = 1,
    },

    -- Defensive abilities
    -- Enhanced Barkskin with glyph support
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
        copy = "barkskin_buff",
    },
    
    disorienting_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Survival Instincts with glyph support
    survival_instincts = {
        id = 61336,
        duration = function() return glyph.survival_instincts.enabled and 6 or 12 end,
        max_stack = 1,
        copy = "survival_instincts_buff",
    },

    frenzied_regeneration = {
        id = 22842,
        duration = 20,
        max_stack = 1,
    },

    -- Enhanced Savage Defense with proper charge system
    savage_defense = {
        id = 62606,
        duration = 6,
        max_stack = 3, -- 3 charges can be stored
        copy = "savage_defense_buff",
    },

    -- Offensive abilities - Enhanced Enrage with tick mechanics
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
        tick_time = 1,
        copy = "enrage_buff",
    },

    -- Berserk buff
    berserk = {
        id = 50334,
        duration = function() return buff.bear_form.up and 10 or 15 end,
        max_stack = 1,
        copy = "berserk_buff",
    },

    -- Debuffs
    lacerate = {
        id = 33745,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
        copy = "lacerate_dot",
    },

    thrash_bear = {
        id = 77758,
        duration = 16,
        max_stack = 1,
        tick_time = 2,
        copy = "thrash_bear_dot",
    },

    faerie_fire = {
        id = 770,
        duration = 300,
        max_stack = 1,
    },

    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Demoralizing Roar ability
    demoralizing_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132117,

        form = "bear_form",

        handler = function ()
            applyDebuff( "target", "demoralizing_roar", 30 )
            if active_enemies > 1 then
                active_dot.demoralizing_roar = active_enemies
            end
        end,
    },

    -- Buffs from talents
    incarnation = {
        id = 102558,
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Heart of the Wild with proper stat modifications
    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
        copy = "heart_of_the_wild_buff",
    },

    nature_swiftness = {
        id = 132158,
        duration = 8,
        max_stack = 1,
    },

    -- Heart of the Wild Feral auras (needed for DPS rotation)
    predatory_swiftness = {
        id = 69369,
        duration = 8,
        max_stack = 1,
        copy = "predatory_swiftness_buff",
    },

    clearcasting = {
        id = 135700,
        duration = 15,
        max_stack = 1,
        copy = "clearcasting_buff",
    },

    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1,
    },

    -- Other forms
    cat_form = {
        id = 768,
        duration = 3600,
        max_stack = 1,
    },

    moonkin_form = {
        id = 24858,
        duration = 3600,
        max_stack = 1,
    },

    travel_form = {
        id = 783,
        duration = 3600,
        max_stack = 1,
    },

    aquatic_form = {
        id = 1066,
        duration = 3600,
        max_stack = 1,
    },

    -- Prowl (for stealth mechanics)
    prowl_base = {
        id = 5215,
        duration = 3600,
        max_stack = 1,
        multiplier = 1.6,
    },
    
    prowl = {
        alias = { "prowl_base" },
        aliasMode = "first", 
        aliasType = "buff",
        duration = 3600,
        max_stack = 1
    },

    -- Generic buffs
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },

    -- Procs and special effects - Enhanced Tooth & Claw with absorb
    tooth_and_claw = {
        id = 135286,
        duration = 6,
        max_stack = 2,
        copy = "tooth_and_claw_absorb",
    },

    -- Glyphs
    glyph_of_fae_silence = {
        id = 114302,
        duration = 5,
        max_stack = 1,
    },

    -- Raid buffs/debuffs
    weakened_armor = {
        id = 113746,
        duration = 30,
        max_stack = 3,
    },

    sunder_armor = {
        id = 58567,
        duration = 30,
        max_stack = 3,
    },

    -- Missing auras from APL
    incarnation_son_of_ursoc = {
        id = 102558,
        duration = 30,
        max_stack = 1,
    },

    natures_vigil = {
        id = 124974,
        duration = 12,
        max_stack = 1,
    },

    pulverize = {
        id = 80313,
        duration = 20,
        max_stack = 1,
    },

    symbiosis = {
        id = 110309,
        duration = 3600,
        max_stack = 1,
    },

    -- Enhanced Dream of Cenarius with proper mechanics
    dream_of_cenarius_damage = {
        id = 108373,
        duration = 15,
        max_stack = 2,
        copy = "dream_of_cenarius_dmg",
    },

    dream_of_cenarius_healing = {
        id = 108374, -- Different ID for healing version
        duration = 15, 
        max_stack = 2,
        copy = "dream_of_cenarius_heal",
    },

    mangle = {
        id = 33878,
        duration = 0,
        max_stack = 1,
    },

    tooth_and_claw_debuff = {
        id = 135286,
        duration = 6,
        max_stack = 1,
    },

    -- Weakened Blows debuff (applied by Thrash)
    weakened_blows = {
        id = 113746,
        duration = 30,
        max_stack = 3,
        copy = "weakened_blows_debuff",
    },

    -- Additional debuffs needed for APL
    mighty_bash = {
        id = 5211,
        duration = 5,
        max_stack = 1,
    },

    growl = {
        id = 6795,
        duration = 3,
        max_stack = 1,
    },

    challenging_roar = {
        id = 5209,
        duration = 6,
        max_stack = 1,
    },

    -- Ironfur (defensive buff)
    ironfur = {
        id = 102543,
        duration = 6,
        max_stack = 1,
    },

    -- Vengeance (tank mechanic)
    vengeance = {
        id = 132365,
        duration = 20,
        max_stack = 999,
        meta = {
            stack = function( t ) return t.count end,
            stack_up = function( t ) return t.count > 0 end,
            stack_down = function( t ) return t.count == 0 end,
        },
    },

    -- Primal Fury passive (crit-based resource generation)
    primal_fury = {
        id = 16961,
        duration = -1,
        max_stack = 1,
        copy = "primal_fury_passive",
    },

    -- Pulverize buff (crit bonus from consuming Lacerate stacks)
    pulverize = {
        id = 80951,
        duration = 18, -- 10s base + 8s from Endless Carnage if talented
        max_stack = 3,
        copy = "pulverize_buff",
    },

    -- Demoralizing Roar debuff
    demoralizing_roar = {
        id = 99,
        duration = 30,
        max_stack = 1,
        copy = "demoralizing_roar_debuff",
    },

    -- Heart of the Wild Cat Form debuffs
    -- Rake debuff (HotW Cat form)
    rake = {
        id = 155722, -- MoP Rake ID
        duration = 9,
        max_stack = 1,
        tick_time = 3,
        copy = "rake_debuff",
    },

    -- Rip debuff (HotW Cat form)
    rip = {
        id = 1079,
        duration = function() return 16 + ( combo_points.spent * 2 ) end,
        max_stack = 1,
        tick_time = 2,
        copy = "rip_debuff",
    },

} )

-- Primal Fury implementation
spec:RegisterHook( "criticalStrike", function( action, result )
    if not buff.bear_form.up then return end
    
    local rageGain = 0
    if action == "auto_attack" then
        rageGain = 15
    elseif action == "mangle" then
        -- Soul of the Forest increases Mangle rage gen by 30% for Guardian
        rageGain = talent.soul_of_the_forest.enabled and 19.5 or 15
    end
    
    if rageGain > 0 then
        gain( rageGain, "rage" )
    end
end )

-- Survival Instincts damage reduction mechanics
spec:RegisterHook( "runHandler", function( action )
    if action == "survival_instincts" then
        -- Apply 50% damage reduction
        if buff.survival_instincts.up then
            state.pseudoStats.damageTakenMultiplier = state.pseudoStats.damageTakenMultiplier * 0.5
        end
    end
end )

-- Dream of Cenarius proc mechanics
spec:RegisterHook( "spend", function( amt, resource )
    if resource == "rage" and amt > 0 and talent.dream_of_cenarius.enabled then
        -- Dream of Cenarius: Spending rage builds healing stacks
        if amt >= 30 then
            if buff.dream_of_cenarius_healing.stack < 2 then
                applyBuff( "dream_of_cenarius_healing", 15, min( 2, buff.dream_of_cenarius_healing.stack + 1 ) )
            end
        end
    end
end )

spec:RegisterHook( "runHandler", function( action )
    if talent.dream_of_cenarius.enabled then
        local ability = class.abilities[ action ]
        if ability and ability.startsCombat and action ~= "auto_attack" then
            -- Damage abilities build damage stacks
            if action == "mangle" or action == "lacerate" or action == "thrash_bear" then
                if buff.dream_of_cenarius_damage.stack < 2 then
                    applyBuff( "dream_of_cenarius_damage", 15, min( 2, buff.dream_of_cenarius_damage.stack + 1 ) )
                end
            end
        end
    end
end )

-- Enhanced Enrage tick mechanics
spec:RegisterHook( "reset_precast", function()
    -- Handle Enrage rage generation over time
    if buff.enrage.up then
        local ticks = math.floor( buff.enrage.remains )
        if ticks > 0 then
            -- Simulate the remaining rage ticks
            forecastResources( "rage" )
        end
    end
end )

-- Bear Form drop cancels Enrage and Symbiosis interaction tracking
spec:RegisterHook( "runHandler", function( action )
    if action == "unshift" or ( action ~= "bear_form" and not buff.bear_form.up ) then
        if buff.enrage.up then
            removeBuff( "enrage" )
        end
    end
    
    -- Track Symbiosis cooldown interactions
    if buff.symbiosis.up and action == "survival_instincts" then
        -- Symbiosis may modify cooldown behavior for survival abilities
        if talent.incarnation.enabled then
            setCooldown( action, max( 0, cooldown[ action ].remains - 30 ) )
        end
    end
end )

-- Shapeshift helpers for Guardian (parallel to Feral's implementations).
spec:RegisterStateFunction( "unshift", function()
    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )
end )

spec:RegisterStateFunction( "shift", function( form )
    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )
    if form then applyBuff( form ) end
end )

-- Comprehensive Variable System using local functions
local function rage_cap()
    return rage.max - 10
end

local function rage_floor()
    return 50 -- Keep enough rage for emergency defensives
end

local function rage_pool()
    return rage_cap() - 20
end

local function rage_deficit()
    return rage_cap() - rage.current
end

local function should_spend_rage()
    return rage.current > rage_pool()
end

local function can_spend_rage_on_maul()
    return rage.current - 30 >= rage_floor()
end

local function has_lacerate_threat()
    return active_dot.lacerate / active_enemies * 100 > 75
end

-- Defensive layering system adapted for MoP
local function defensive_layer_stack()
    local stack = 0
    if buff.berserk.up then stack = stack + 1 end
    if buff.barkskin.up then stack = stack + 1 end
    if buff.survival_instincts.up then stack = stack + 1 end
    if buff.frenzied_regeneration.up then stack = stack + 1 end
    if buff.savage_defense.up then stack = stack + 1 end
    return stack
end

local function can_use_defensive_buff()
    local stack = defensive_layer_stack()
    local health_pct = health.pct
    
    -- Allow first defensive layer always
    if stack < 1 then return true end
    
    -- Second layer at 50% health
    if stack < 2 and health_pct < 50 then return true end
    
    -- Third layer at 30% health
    if stack < 3 and health_pct < 30 then return true end
    
    return false
end

-- Rage generation calculations
local function rage_per_second_auto_attack()
    return 4 / (2 * attack_haste)
end

local function rage_gain_mangle()
    return talent.soul_of_the_forest.enabled and 6.5 or 5
end

-- State Expressions for simc integration
spec:RegisterStateExpr( "rage_cap", rage_cap )
spec:RegisterStateExpr( "rage_floor", rage_floor )
spec:RegisterStateExpr( "rage_pool", rage_pool )
spec:RegisterStateExpr( "rage_deficit", rage_deficit )
spec:RegisterStateExpr( "should_spend_rage", should_spend_rage )
spec:RegisterStateExpr( "can_spend_rage_on_maul", can_spend_rage_on_maul )
spec:RegisterStateExpr( "has_lacerate_threat", has_lacerate_threat )
spec:RegisterStateExpr( "defensive_layer_stack", defensive_layer_stack )
spec:RegisterStateExpr( "can_use_defensive_buff", can_use_defensive_buff )
spec:RegisterStateExpr( "rage_per_second_auto_attack", rage_per_second_auto_attack )
spec:RegisterStateExpr( "rage_gain_mangle", rage_gain_mangle )

-- Health threshold state expressions
spec:RegisterStateExpr( "barkskin_health_pct", function() return defensive_health_pct end )
spec:RegisterStateExpr( "frenzied_regeneration_health_pct", function() return moderate_damage_pct end )
spec:RegisterStateExpr( "survival_instincts_health_pct", function() return emergency_health_pct end )
spec:RegisterStateExpr( "healing_touch_health_pct", function() return emergency_health_pct end )

-- Rage cost state expressions
spec:RegisterStateExpr( "rage_cost_savage_defense", function() return 60 end )
spec:RegisterStateExpr( "rage_cost_maul", function() return 30 end )

-- Settings for Guardian Druid
spec:RegisterSetting( "maul_rage", 20, {
    name = strformat( "%s Rage Threshold", Hekili:GetSpellLinkWithTexture( spec.abilities.maul.id ) ),
    desc = strformat( "If set above zero, %s can be recommended only if you'll still have this much Rage after use.\n\n"
        .. "This option helps to ensure that %s or %s are available if needed.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.maul.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.savage_defense.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.frenzied_regeneration.id ) ),
    type = "range",
    min = 0,
    max = 60,
    step = 0.1,
    width = 1.5
} )

spec:RegisterSetting( "ironfur_damage_threshold", 5, {
    name = strformat( "%s Damage Threshold", Hekili:GetSpellLinkWithTexture( spec.abilities.ironfur.id ) ),
    desc = strformat( "If set above zero, %s will not be recommended for mitigation purposes unless you've taken this much damage in the past 5 seconds (as a percentage "
        .. "of your total health).\n\n"
        .. "This value is halved when playing solo.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.ironfur.id ) ),
    type = "range",
    min = 0,
    max = 200,
    step = 0.1,
    width = 1.5
} )

spec:RegisterSetting( "max_ironfur", 1, {
    name = strformat( "%s Maximum Stacks", Hekili:GetSpellLinkWithTexture( spec.abilities.ironfur.id ) ),
    desc = strformat( "When set above zero, %s will not be recommended for mitigation purposes if you already have this many stacks.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.ironfur.id ) ),
    type = "range",
    min = 0,
    max = 14,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "defensive_health_pct", 50, {
    name = "Defensive Health Threshold",
    desc = "Health percentage below which defensive abilities like Barkskin and Frenzied Regeneration will be recommended.",
    type = "range",
    min = 1,
    max = 100,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "moderate_damage_pct", 70, {
    name = "Moderate Damage Threshold", 
    desc = "Health percentage below which moderate defensive abilities will be recommended.",
    type = "range",
    min = 1,
    max = 100,
    step = 1,
    width = 1.5
} )

spec:RegisterSetting( "emergency_health_pct", 30, {
    name = "Emergency Health Threshold",
    desc = "Health percentage below which emergency defensive abilities like Survival Instincts will be recommended.",
    type = "range", 
    min = 1,
    max = 100,
    step = 1,
    width = 1.5
} )

-- State expressions for settings
spec:RegisterStateExpr( "ironfur_damage_threshold", function ()
    return ( settings.ironfur_damage_threshold or 0 ) / 100 * health.max * ( solo and 0.5 or 1 )
end )

spec:RegisterStateExpr( "max_ironfur", function()
    return settings.max_ironfur or 1
end )

spec:RegisterStateExpr( "defensive_health_pct", function()
    return settings.defensive_health_pct or 50
end )

spec:RegisterStateExpr( "moderate_damage_pct", function()
    return settings.moderate_damage_pct or 70
end )

spec:RegisterStateExpr( "emergency_health_pct", function()
    return settings.emergency_health_pct or 30
end )

-- Comprehensive State Functions adapted from retail simc
local function rage_spent_recently( amt )
    amt = amt or 1

    for i = 1, #state.recentRageSpent do
        if state.recentRageSpent[i] >= amt then return true end
    end

    return false
end

local function lacerate_up()
    return state.debuff.lacerate.up
end

local function thrash_up()
    return state.debuff.thrash_bear.up
end

-- Rage management calculations
local function rage_above_floor()
    return rage.current > rage_floor()
end

-- Defensive layering calculations
local function incoming_damage_3s()
    return state.incoming_damage_3s or 0
end

local function incoming_damage_5s()
    return state.incoming_damage_5s or 0
end

local function health_deficit()
    return health.max - health.current
end

local function health_deficit_percent()
    return (health.max - health.current) / health.max * 100
end

-- Threat and positioning calculations
local function target_in_melee_range()
    return target.within8
end

local function multiple_targets()
    return active_enemies > 1
end

-- Cooldown availability checks
local function survival_instincts_available()
    return cooldown.survival_instincts.ready
end

local function barkskin_available()
    return cooldown.barkskin.ready
end

local function frenzied_regeneration_available()
    return cooldown.frenzied_regeneration.ready
end

-- Buff uptime calculations
local function savage_defense_uptime()
    return buff.savage_defense.up
end

local function pulverize_stacks()
    return buff.pulverize.stack
end

-- Damage prediction
local function predicted_damage_3s()
    return incoming_damage_3s() * 1.2 -- Add 20% buffer for prediction
end

local function emergency_health_threshold()
    return health.current < (health.max * 0.3) -- 30% health
end

local function defensive_health_threshold()
    return health.current < (health.max * 0.5) -- 50% health
end

local function moderate_damage_threshold()
    return health.current < (health.max * 0.7) -- 70% health
end

-- Mitigation and healing priority calculations
local function should_use_savage_defense()
    return rage.current >= 60 and not buff.savage_defense.up and buff.savage_defense.stack < 3
end

local function should_use_maul()
    return rage.current >= 30 and target.within8 and rage.current > rage_floor()
end

local function should_use_frenzied_regeneration()
    return cooldown.frenzied_regeneration.ready and 
           health.current < (health.max * 0.5) and 
           not buff.frenzied_regeneration.up
end

local function should_use_barkskin()
    return cooldown.barkskin.ready and 
           health.current < (health.max * 0.5)
end

local function should_use_survival_instincts()
    return cooldown.survival_instincts.ready and 
           health.current < (health.max * 0.3)
end

local function should_use_healing_touch()
    return health.current < (health.max * 0.3) and 
           (buff.nature_swiftness.up or buff.predatory_swiftness.up or buff.dream_of_cenarius_healing.stack > 0)
end

local function should_use_rejuvenation()
    return health.current < (health.max * 0.7) and 
           not buff.rejuvenation.up and 
           (buff.predatory_swiftness.up or buff.dream_of_cenarius_healing.stack > 0)
end

-- Threat generation calculations
local function should_use_pulverize()
    return debuff.lacerate.stack >= 3 and debuff.lacerate.remains <= 4
end

local function should_refresh_lacerate()
    return debuff.lacerate.remains <= 3 or debuff.lacerate.stack < 3
end

local function should_refresh_thrash()
    return debuff.thrash_bear.remains <= 3
end

local function should_use_multi_target_rotation()
    return active_enemies >= 3
end

-- Cooldown usage calculations
local function should_use_berserk()
    return cooldown.berserk.ready and 
           not buff.berserk.up and 
           (active_enemies >= 2 or target.classification == "worldboss")
end

local function should_use_incarnation()
    return talent.incarnation.enabled and 
           cooldown.incarnation.ready and 
           not buff.incarnation.up and 
           (active_enemies >= 2 or target.classification == "worldboss")
end

local function should_use_enrage()
    return rage.current < 40 and not buff.enrage.up
end

-- Register Options
spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 8,
    rangeFilter = false,

    damage = true,
    damageExpiration = 6,

    potion = "tempered_potion",

    package = "Guardian",
} )

-- Abilities
spec:RegisterAbilities( {
    -- Enrage - MoP Guardian ability
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",

        startsCombat = false,
        form = "bear_form",

        handler = function ()
            gain( 20, "rage" )
            applyBuff( "enrage" )
        end,
    },

    -- Savage Defense - MoP Guardian ability
    savage_defense = {
        id = 62606,
        cast = 0,
        cooldown = 1.5,
        gcd = "off",
        school = "nature",

        spend = 60,
        spendType = "rage",

        startsCombat = false,
        form = "bear_form",

        handler = function ()
            applyBuff( "savage_defense" )
        end,
    },

    -- Tooth and Claw - MoP Guardian talent
    tooth_and_claw = {
        id = 135288,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function() return buff.tooth_and_claw.up and 0 or 40 end,
        spendType = "rage",

        startsCombat = true,
        form = "bear_form",
        buff = "tooth_and_claw",

        handler = function ()
            if buff.tooth_and_claw.up then
                removeBuff( "tooth_and_claw" )
                applyDebuff( "target", "tooth_and_claw_debuff" )
            end
        end,
    },

    -- Bear Form
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        essential = true,

        handler = function ()
            shift( "bear_form" )
        end,
    },

    -- Basic attacks
    auto_attack = {
        id = 6603,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        startsCombat = true,
        texture = 132938,

    usable = function () return state and state.melee and state.melee.range and state.melee.range <= 5 end,
        handler = function ()
            removeBuff( "prowl" )
        end,
    },

    mangle = {
        id = 33878,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = -5,
        spendType = "rage",

        startsCombat = true,
        texture = 132135,

        form = "bear_form",

        handler = function ()
            -- Generate rage (5 base, 6.5 with Soul of the Forest for Guardian)
            local rageGain = talent.soul_of_the_forest.enabled and 6.5 or 5
            gain( rageGain, "rage" )
            
            if talent.infected_wounds.enabled then
                applyDebuff( "target", "infected_wounds" )
            end
            
            removeBuff( "tooth_and_claw" )
            
            -- Berserk removes Mangle CD
            if buff.berserk.up then
                setCooldown( "mangle", 0 )
            end
            
            if set_bonus.tier16_4pc == 1 and active_dot.thrash_bear > 0 then
                if math.random() < 0.4 then
                    setCooldown( "mangle", 0 )
                end
            end
        end,
    },
    
    disorienting_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132121,

        form = "bear_form",
        duration = 30,
        max_stack = 1,
    },

    -- Enhanced Lacerate (Guardian ability) with APL-based logic
    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 3, -- 3 second internal cooldown from Go sim
        gcd = "spell",

        spend = 0, -- No rage cost in MoP for Guardian
        spendType = "rage",

        startsCombat = true,
        texture = 132131,

        form = "bear_form",

        handler = function ()
            -- Apply or refresh Lacerate DoT with stacking
            local currentStacks = debuff.lacerate.stack or 0
            local newStacks = min( 3, currentStacks + 1 )
            applyDebuff( "target", "lacerate", 15, newStacks )
            
            -- 25% chance to reset Mangle cooldown (matches Go sim)
            if math.random() < 0.25 then
                setCooldown( "mangle", 0 )
            end
            
            if talent.tooth_and_claw.enabled then
                if math.random() < 0.4 then
                    applyBuff( "tooth_and_claw", 6, min( 2, ( buff.tooth_and_claw.stack or 0 ) + 1 ) )
                end
            end
        end,
    },

    -- Enhanced Pulverize (Guardian ability) with proper mechanics
    pulverize = {
        id = 80313,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 236149,

        form = "bear_form",
        
        usable = function() return debuff.lacerate.up and debuff.lacerate.stack >= 1 end,

        handler = function ()
            local stacks = debuff.lacerate.stack
            if stacks >= 1 then
                -- Consume Lacerate DoT and apply Pulverize buff
                removeDebuff( "target", "lacerate" )
                applyBuff( "pulverize", 18, stacks ) -- Duration affected by Endless Carnage
                -- Each stack gives 3% crit chance
            end
        end,
    },

    -- Enhanced Maul with rage dumping logic
    maul = {
        id = 6807,
        cast = 0,
        cooldown = 3, -- 3 second cooldown from APL analysis
        gcd = "spell",

        spend = function() return buff.bear_form.up and 20 or 30 end, -- Guardian gets reduced cost
        spendType = "rage",

        startsCombat = true,
        texture = 132136,

        form = "bear_form",
        
        -- Rage dumping logic from APL analysis
        usable = function() return rage.current >= ( buff.bear_form.up and 20 or 30 ) end,

        handler = function ()
            if buff.tooth_and_claw.up then
                local stacks = buff.tooth_and_claw.stack
                removeBuff( "tooth_and_claw" )
                applyDebuff( "target", "tooth_and_claw_debuff", 6 )
                -- Apply absorb shield based on attack power and stacks
                local absorb_amount = stat.attack_power * 0.65 * stacks
                absorbDamage( absorb_amount )
            end
            
            -- Benefits from Rend and Tear if bleeds are active
            local hasBleed = debuff.lacerate.up or debuff.thrash_bear.up or debuff.rake.up or debuff.rip.up
            if hasBleed then
                -- 20% damage bonus applied via damage calculation
            end
        end,
    },



    -- Defensive abilities
    -- Enhanced Barkskin with Guardian-specific cooldown
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 30, -- Guardian gets 30s CD instead of 60s
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 136097,

        handler = function ()
            applyBuff( "barkskin", 12 )
            -- 20% damage reduction + glyph effects applied via aura mechanics
        end,
    },

    -- Enhanced Survival Instincts with proper glyph mechanics
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = function() return glyph.survival_instincts.enabled and 120 or 180 end,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 236169,
        
        form = function() return buff.bear_form.up and "bear_form" or buff.cat_form.up and "cat_form" or "none" end,
        usable = function() return buff.bear_form.up or buff.cat_form.up end,

        handler = function ()
            local duration = glyph.survival_instincts.enabled and 6 or 12
            applyBuff( "survival_instincts", duration )
            -- 50% damage reduction applied via aura
        end,
    },

    frenzied_regeneration = {
        id = 22842,
        cast = 0,
        cooldown = 90,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 132091,

        handler = function ()
            applyBuff( "frenzied_regeneration" )
            health.actual = min( health.max, health.actual + ( health.max * 0.3 ) )
        end,
    },

    -- Rage generators - Enhanced Enrage with proper tick mechanics
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 132126,

        form = "bear_form",

        handler = function ()
            -- Initial 20 rage burst
            gain( 20, "rage" )
            -- Apply buff that will tick for 10 seconds, giving +1 rage per tick
            applyBuff( "enrage", 10 )
        end,
    },

    -- Enhanced Berserk with Bear form mechanics
    berserk = {
        id = 50334,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 236149,

        talent = "berserk",
        
        usable = function() return buff.bear_form.up or buff.cat_form.up end,

        handler = function ()
            if buff.bear_form.up then
                applyBuff( "berserk", 10 )
                setCooldown( "mangle", 0 ) -- Immediate Mangle reset
                -- Enable multi-target Mangle and remove CD during berserk
            elseif buff.cat_form.up then
                applyBuff( "berserk", 15 )
                -- 50% energy cost reduction handled elsewhere
            end
        end,
    },

    -- Utility
    -- Enhanced Faerie Fire (unified ability with form-specific behavior)
    faerie_fire = {
        id = 770, -- Base Faerie Fire ID (Bear form version 16857 handled via copy)
        cast = 0,
        cooldown = function() return buff.bear_form.up and 6 or 0 end,
        gcd = "spell",

        startsCombat = true,
        texture = 136033,
        
        copy = { 16857 }, -- Bear form version

        handler = function ()
            if buff.bear_form.up then
                -- Bear form version does damage and has shorter CD
                -- 25% chance to reset Mangle cooldown
                if math.random() < 0.25 then
                    setCooldown( "mangle", 0 )
                end
            end
            
            applyDebuff( "target", "faerie_fire", 300 )
            applyDebuff( "target", "weakened_armor", 30, 3 )
        end,
    },

    -- Faerie Fire (Bear) - explicit registration for ID 16857
    faerie_fire_bear = {
        id = 16857,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        startsCombat = true,
        texture = 136033,
        
        form = "bear_form",

        handler = function ()
            -- Bear form version does damage and has shorter CD
            -- 25% chance to reset Mangle cooldown
            if math.random() < 0.25 then
                setCooldown( "mangle", 0 )
            end
            
            applyDebuff( "target", "faerie_fire", 300 )
            applyDebuff( "target", "weakened_armor", 30, 3 )
        end,
    },

    demoralizing_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",

        spend = 10,
        spendType = "rage",

        startsCombat = true,
        texture = 132117,

        handler = function ()
            applyDebuff( "target", "demoralizing_roar" )
            if active_enemies > 1 then
                active_dot.demoralizing_roar = active_enemies
            end
        end,
    },

    growl = {
        id = 6795,
        cast = 0,
        cooldown = 8,
        gcd = "spell",

        startsCombat = true,
        texture = 132270,

        handler = function ()
            -- Taunt effect
        end,
    },

    challenging_roar = {
        id = 5209, -- Challenging Roar (Guardian ability in MoP)
        cast = 0,
        cooldown = 180,
        gcd = "spell",

        startsCombat = true,
        texture = 132117,

        handler = function ()
            -- AoE taunt
        end,
    },

    -- Incarnation
    incarnation = {
        id = 102558,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "incarnation",
        toggle = "cooldowns",

        startsCombat = false,
        texture = 571586,

        handler = function ()
            applyBuff( "incarnation" )
            if not buff.bear_form.up then
                shift( "bear_form" )
            end
        end,
    },

    -- Incarnation: Son of Ursoc (Guardian version)
    incarnation_son_of_ursoc = {
        id = 102558,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        talent = "incarnation",

        startsCombat = false,
        texture = 571586,

        handler = function ()
            applyBuff( "incarnation_son_of_ursoc" )
            if not buff.bear_form.up then
                shift( "bear_form" )
            end
        end,
    },

    -- Savage Defense (Guardian ability) - Enhanced with charge system
    savage_defense = {
        id = 62606,
        cast = 0,
        charges = 3,
        cooldown = 9, -- 9 second recharge per charge
        recharge = 9,
        gcd = "spell", -- 1.5s to respect GCD

        spend = 60,
        spendType = "rage",

        talent = "savage_defense",
        toggle = "defensives",

        startsCombat = false,
        texture = 132278,
        
        usable = function() return rage.current >= 60 and charges_fractional >= 1 end,

        handler = function ()
            applyBuff( "savage_defense", 6 )
            spend( 60, "rage" )
        end,
    },

    -- Nature's Vigil (talent)
    natures_vigil = {
        id = 124974,
        cast = 0,
        cooldown = 90,
        gcd = "off",

        talent = "natures_vigil",
        toggle = "defensives",

        startsCombat = false,
        texture = 132123,

        handler = function ()
            applyBuff( "natures_vigil" )
        end,
    },



    -- Enhanced Swipe (Bear form) with Guardian mechanics
    swipe_bear = {
        id = 779,
        cast = 0,
        cooldown = 3, -- 3 second cooldown
        gcd = "spell",

        spend = 0, -- Guardian Druids have 0 rage cost
        spendType = "rage",

        startsCombat = true,
        texture = 134296,

        form = "bear_form",
        
        usable = function() return active_enemies > 1 end,

        handler = function ()
            -- Benefits from Rend and Tear damage multiplier
            local multiplier = ( debuff.lacerate.up or debuff.thrash_bear.up or debuff.rake.up or debuff.rip.up ) and 1.2 or 1.0
            
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                -- Hit multiple enemies with Rend and Tear bonus
            end
        end,
    },

    -- Thrash (Bear form)
    thrash_bear = {
        id = 77758,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = -5,
        spendType = "rage",

        startsCombat = true,
        texture = 451161,

        form = "bear_form",

        handler = function ()
            -- Apply DoT to primary target
            applyDebuff( "target", "thrash_bear", 16 )
            
            -- 25% chance to reset Mangle cooldown (matches Go sim)
            if math.random() < 0.25 then
                setCooldown( "mangle", 0 )
            end
            
            -- Apply Weakened Blows debuff
            applyDebuff( "target", "weakened_blows", 30 )
            
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                for i = 1, applied do
                    if i == 1 then
                        applyDebuff( "target", "thrash_bear", 16 )
                    else
                        applyDebuff( "target" .. i, "thrash_bear", 16 )
                        applyDebuff( "target" .. i, "weakened_blows", 30 )
                    end
                end
            end
        end,
    },

    -- Thrash: General ability that maps to thrash_bear for Guardian
    -- This allows keybind detection to work properly
    thrash = {
        id = 77758,
        copy = "thrash_bear",
    },

    -- Enhanced Symbiosis (MoP ability) with proper target conditions
    symbiosis = {
        id = 110309,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        startsCombat = false,
        texture = 136033,
        
        usable = function() 
            return settings.use_symbiosis and group_members > 1 
        end,

        handler = function ()
            applyBuff( "symbiosis", 3600 )
            -- Symbiosis grants different abilities based on target class
            -- For Guardian, commonly grants survival abilities like:
            -- Death Knight: Bone Shield, Paladin: Consecration, etc.
        end,
    },

    -- Skull Bash (interrupt)
    skull_bash = {
        id = 80965,
        cast = 0,
        cooldown = 10,
        gcd = "off",

        toggle = "interrupts",

        startsCombat = false,
        texture = 132091,

        form = "bear_form",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            interrupt()
        end,
    },

    -- Mighty Bash (talent interrupt)
    mighty_bash = {
        id = 5211,
        cast = 0,
        cooldown = 50,
        gcd = "spell",

        talent = "mighty_bash",
        toggle = "interrupts",

        startsCombat = true,
        texture = 132091,

        handler = function ()
            applyDebuff( "target", "mighty_bash" )
    end,
    },

    -- Wild Charge (talent)
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",

        talent = "wild_charge",

        startsCombat = false,
        texture = 132091,

        handler = function ()
            applyBuff( "wild_charge" )
        end,
    },

    -- Heart of the Wild (talent)
    heart_of_the_wild = {
        id = 108292,
        cast = 0,
        cooldown = 360,
        gcd = "off",

        talent = "heart_of_the_wild",
        toggle = "defensives",

        startsCombat = false,
        texture = 132123,

        handler = function ()
            applyBuff( "heart_of_the_wild" )
            -- Apply form-specific stat bonuses based on current form
            if buff.bear_form.up then
                -- Guardian: +25% stamina, enables Cat abilities at full effectiveness
                stat.stamina_multiplier = stat.stamina_multiplier * 1.25
            elseif buff.cat_form.up then
                -- Feral: +25% agility, enables Caster abilities at full effectiveness  
                stat.agility_multiplier = stat.agility_multiplier * 1.25
            else
                -- Caster forms: +25% intellect, enables physical abilities
                stat.intellect_multiplier = stat.intellect_multiplier * 1.25
            end
        end,
    },

    -- Force of Nature (talent)
    force_of_nature = {
        id = 106737,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        talent = "force_of_nature",

        startsCombat = true,
        texture = 132123,

        handler = function ()
            -- Summon treants
        end,
    },

    -- Nature's Swiftness (if talented)
    natures_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        talent = "nature_swiftness",

        startsCombat = false,
        texture = 136076,

        handler = function ()
            applyBuff( "nature_swiftness" )
        end,
    },

    -- Healing Touch (for Nature's Swiftness)
    healing_touch = {
        id = 5185,
        cast = function() return buff.nature_swiftness.up and 0 or 3 end,
        cooldown = 0,
        gcd = "spell",

        spend = function() return buff.nature_swiftness.up and 0 or 0.15 end,
        spendType = "mana",

        startsCombat = false,
        texture = 136041,

        handler = function ()
            removeBuff( "nature_swiftness" )
            health.actual = min( health.max, health.actual + ( health.max * 0.4 ) )
        end,
    },

    -- Heart of the Wild Cat Form DPS Abilities
    -- Shred (Heart of the Wild Cat form)
    shred_hotw = {
        id = 5221,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 40,
        spendType = "energy",

        startsCombat = true,
        texture = 136231,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and energy.current >= 40 end,
        
        handler = function ()
            if combo_points.current < combo_points.max then
                gain( 1, "combo_points" )
            end
            if debuff.rip.up then
                -- 20% damage bonus with Rend and Tear if bleeds active
            end
        end,
    },

    -- Rake (Heart of the Wild Cat form)
    rake_hotw = {
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 35,
        spendType = "energy",

        startsCombat = true,
        texture = 132122,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and energy.current >= 35 end,

        handler = function ()
            applyDebuff( "target", "rake", 9 )
            if combo_points.current < combo_points.max then
                gain( 1, "combo_points" )
            end
        end,
    },

    -- Rip (Heart of the Wild Cat form finisher)
    rip_hotw = {
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 30,
        spendType = "energy",

        startsCombat = true,
        texture = 132152,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and combo_points.current >= 1 and energy.current >= 30 end,

        handler = function ()
            local cp = combo_points.current
            applyDebuff( "target", "rip", 16 + ( cp * 2 ) ) -- Longer duration with more CP
            spend( cp, "combo_points" )
        end,
    },

    -- Ferocious Bite (Heart of the Wild Cat form finisher)
    ferocious_bite_hotw = {
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 25,
        spendType = "energy",

        startsCombat = true,
        texture = 132127,

        form = "cat_form",
        usable = function() return buff.heart_of_the_wild.up and buff.cat_form.up and combo_points.current >= 1 and energy.current >= 25 end,

        handler = function ()
            local cp = combo_points.current
            spend( cp, "combo_points" )
        end,
    },

    -- Cat Form for Heart of the Wild DPS switching
    cat_form_hotw = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 132115,
        
        essential = true,
        nomounted = true,
        
        usable = function() return buff.heart_of_the_wild.up and not buff.cat_form.up and health.pct >= 80 end,

        handler = function ()
            shift( "cat_form" )
        end,
    },



    -- Ironfur (defensive ability)
    ironfur = {
        id = 102543,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 45,
        spendType = "rage",

        startsCombat = false,
        texture = 132787,

        form = "bear_form",

        handler = function ()
            applyBuff( "ironfur" )
        end,
    },

    -- Mark of the Wild (buff ability)
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 136078,

        handler = function ()
            applyBuff( "mark_of_the_wild" )
        end,
    },

    -- Nature's Swiftness (talent ability)
    nature_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        texture = 136076,

        talent = "nature_swiftness",

        handler = function ()
            applyBuff( "nature_swiftness" )
        end,
    },

    -- Prowl (stealth ability)
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "off",

        startsCombat = false,
        texture = 514640,

        nobuff = "prowl",
        
        usable = function() return not buff.bear_form.up end,

        handler = function ()
            applyBuff( "prowl_base" )
        end,
    },

} )

-- State table and hooks
spec:RegisterStateExpr( "lacerate_up", function()
    return debuff.lacerate.up
end )

spec:RegisterStateExpr( "thrash_up", function()
    return debuff.thrash_bear.up
end )

spec:RegisterStateExpr( "rage_spent_recently", function()
    local t = state and state.recentRageSpent
    if type( t ) ~= 'table' then return false end
    for i = 1, #t do if t[i] and t[i] > 0 then return true end end
    return false
end )

-- Vengeance state expressions
spec:RegisterStateExpr("vengeance_stacks", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_stacks()
end)

spec:RegisterStateExpr("vengeance_attack_power", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_attack_power()
end)

spec:RegisterStateExpr("vengeance_value", function()
    if not state.vengeance then
        return 0
    end
    return state.vengeance:get_stacks()
end)

spec:RegisterStateExpr("high_vengeance", function()
    if not state.vengeance or not state.settings then
        return false
    end
    return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end)

spec:RegisterStateExpr("should_prioritize_damage", function()
    if not state.vengeance or not state.settings or not state.settings.vengeance_optimization or not state.settings.vengeance_stack_threshold then
        return false
    end
    return state.settings.vengeance_optimization and state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end)

-- Register representative abilities for range checking.
-- Include core melee-range and utility abilities to standardize distance evaluation.
spec:RegisterRanges( "mangle", "maul", "lacerate", "swipe_bear", "thrash_bear", "skull_bash", "growl" )
spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageDots = false,
    damageExpiration = 3,

    potion = "tempered_potion",

    package = "Guardian"
} )

-- Guardian-specific settings
spec:RegisterSetting( "defensive_health_threshold", 80, {
    name = "Defensive Health Threshold",
    desc = "The health percentage at which defensive abilities will be recommended.",
    type = "range",
    min = 50,
    max = 100,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "use_symbiosis", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 110309 ) ),
    desc = strformat( "If checked, %s will be recommended when available.",
        Hekili:GetSpellLinkWithTexture( 110309 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "use_savage_defense", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( 62606 ) ),
    desc = strformat( "If checked, %s will be recommended when you have sufficient rage (60 rage cost, 3 charges).",
        Hekili:GetSpellLinkWithTexture( 62606 ) ),
    type = "toggle",
    width = "full",
} )

-- Remove old rage threshold setting since it's now fixed at 60 rage per charge

spec:RegisterSetting( "lacerate_stacks", 3, {
    name = strformat( "%s Stacks", Hekili:GetSpellLinkWithTexture( 33745 ) ),
    desc = strformat( "The number of %s stacks to maintain on the target.",
        Hekili:GetSpellLinkWithTexture( 33745 ) ),
    type = "range",
    min = 1,
    max = 3,
    step = 1,
    width = 1.5,
} )

spec:RegisterSetting( "maintain_faerie_fire", true, {
    name = strformat( "Maintain %s", Hekili:GetSpellLinkWithTexture( 770 ) ),
    desc = strformat( "If checked, %s will be maintained on the target.",
        Hekili:GetSpellLinkWithTexture( 770 ) ),
    type = "toggle",
    width = "full",
} )

-- Vengeance system variables and settings (Lua-based calculations)
spec:RegisterVariable( "vengeance_stacks", function()
    return state.vengeance:get_stacks()
end )

spec:RegisterVariable( "vengeance_attack_power", function()
    return state.vengeance:get_attack_power()
end )

spec:RegisterVariable( "high_vengeance", function()
    return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
end )

spec:RegisterVariable( "vengeance_active", function()
    return state.vengeance:is_active()
end )

-- Health-based defensive automation variables (StateExpr for SimC access)
spec:RegisterStateExpr( "emergency_health", function()
    return health.pct <= ( settings.emergency_health_pct or 30 )
end )

spec:RegisterStateExpr( "defensive_health", function()
    return health.pct <= ( settings.defensive_health_pct or 50 )
end )

spec:RegisterStateExpr( "moderate_damage", function()
    return health.pct <= ( settings.moderate_damage_pct or 70 )
end )

spec:RegisterStateExpr( "needs_emergency_healing", function()
    return health.pct <= ( settings.emergency_health_pct or 30 ) and not buff.frenzied_regeneration.up
end )

spec:RegisterStateExpr( "should_use_defensives", function()
    return health.pct <= ( settings.defensive_health_pct or 50 ) and incoming_damage_3s > 0
end )

-- Heart of the Wild DPS rotation switching mechanics (StateExpr for SimC access)
spec:RegisterStateExpr( "hotw_active", function()
    return buff.heart_of_the_wild.up
end )

spec:RegisterStateExpr( "should_dps_rotation", function()
    -- Switch to DPS rotation during Heart of the Wild if health is stable
    return buff.heart_of_the_wild.up and health.pct >= 70 and not boss and active_enemies <= 3
end )

spec:RegisterStateExpr( "hotw_cat_form_ready", function()
    -- Can switch to Cat form during HotW for DPS
    return buff.heart_of_the_wild.up and not buff.bear_form.up and health.pct >= 80
end )

spec:RegisterStateExpr( "hotw_caster_form_ready", function()
    -- Can switch to caster form during HotW for ranged DPS
    return buff.heart_of_the_wild.up and not buff.bear_form.up and not buff.cat_form.up and health.pct >= 70 and target.distance >= 15
end )

-- Advanced defensive automation logic (StateExpr for SimC access)
spec:RegisterStateExpr( "auto_survival_instincts", function()
    return health.pct <= ( settings.emergency_health_pct or 30 ) and not buff.survival_instincts.up and not buff.barkskin.up
end )

spec:RegisterStateExpr( "auto_savage_defense", function()
    -- Check if we should automatically use Savage Defense
    if not settings.use_savage_defense then return false end
    if rage.current < 60 then return false end
    if buff.savage_defense.up then return false end
    if incoming_damage_3s <= 0 then return false end
    
    -- Access charges correctly - use cooldown.charges or ability charges
    local charges_available = cooldown.savage_defense.charges_fractional or 0
    return charges_available >= 1
end )

-- Settings-based StateExpr for SimC access
spec:RegisterStateExpr( "auto_pulverize", function()
    return settings.auto_pulverize
end )

spec:RegisterStateExpr( "faerie_fire_auto", function()
    return settings.faerie_fire_auto
end )

spec:RegisterStateExpr( "rage_dump_threshold", function()
    return settings.rage_dump_threshold or 90
end )

spec:RegisterStateExpr( "use_symbiosis", function()
    return settings.use_symbiosis
end )

spec:RegisterStateExpr( "auto_barkskin", function()
    return health.pct <= ( settings.defensive_health_pct or 50 ) and not buff.barkskin.up and not buff.survival_instincts.up
end )

-- Vengeance-based ability conditions (using RegisterStateExpr instead of RegisterVariable)

spec:RegisterSetting( "vengeance_optimization", true, {
    name = strformat( "Optimize for %s", Hekili:GetSpellLinkWithTexture( 132365 ) ),
    desc = "If checked, the rotation will prioritize damage abilities when Vengeance stacks are high.",
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "vengeance_stack_threshold", 5, {
    name = "Vengeance Stack Threshold",
    desc = "Minimum Vengeance stacks before prioritizing damage abilities over pure threat abilities.",
    type = "range",
    min = 1,
    max = 10,
    step = 1,
    width = "full",
} )

spec:RegisterSetting( "faerie_fire_auto", true, {
    name = strformat( "Auto %s", Hekili:GetSpellLinkWithTexture( 770 ) ),
    desc = strformat( "If checked, %s will be automatically applied when the debuff is not present on the target.",
        Hekili:GetSpellLinkWithTexture( 770 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "auto_pulverize", true, {
    name = strformat( "Auto %s", Hekili:GetSpellLinkWithTexture( 80313 ) ),
    desc = strformat( "If checked, %s will be used automatically when Lacerate has 3 stacks and is about to expire.",
        Hekili:GetSpellLinkWithTexture( 80313 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "rage_dump_threshold", 90, {
    name = "Rage Dump Threshold",
    desc = "Use Maul to dump rage when above this amount.",
    type = "range",
    min = 70,
    max = 100,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "enrage_rage_threshold", 40, {
    name = strformat( "%s Rage Threshold", Hekili:GetSpellLinkWithTexture( 5229 ) ),
    desc = strformat( "Use %s when rage falls below this amount.", Hekili:GetSpellLinkWithTexture( 5229 ) ),
    type = "range",
    min = 20,
    max = 60,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "primal_fury", true, {
    name = strformat( "%s Enabled", Hekili:GetSpellLinkWithTexture( 16961 ) ),
    desc = strformat( "If checked, %s crit-based rage generation is factored into resource calculations.",
        Hekili:GetSpellLinkWithTexture( 16961 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "rend_and_tear_multiplier", 1.2, {
    name = "Rend and Tear Damage Multiplier",
    desc = "Damage multiplier applied when bleeds are active (default 1.2 = 20% bonus).",
    type = "range",
    min = 1.0,
    max = 1.5,
    step = 0.1,
    width = 1.5,
} )

spec:RegisterSetting( "emergency_health_pct", 30, {
    name = "Emergency Health Threshold",
    desc = "Health percentage for emergency defensive abilities (Survival Instincts, etc.).",
    type = "range",
    min = 15,
    max = 50,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "moderate_damage_pct", 70, {
    name = "Moderate Damage Health Threshold", 
    desc = "Health percentage for moderate healing/defensive abilities.",
    type = "range",
    min = 50,
    max = 90,
    step = 5,
    width = 1.5,
} )

spec:RegisterSetting( "defensive_health_pct", 50, {
    name = "Defensive Health Threshold",
    desc = "Health percentage for defensive abilities like Barkskin (emergency threshold is separate).",
    type = "range",
    min = 30,
    max = 70,
    step = 5,
    width = 1.5,
} )



-- Priority List - Comprehensive Guardian Druid APL adapted for MoP
spec:RegisterPack( "Guardian", 20250128, [[Hekili:T31sVTnoq4FlJ4r7zJy4mNr2w6v7SZzYVTJSMIIjWu95E4bsSeA8c4BBKsKYkmwFbELYdNFIYF1CJRT1hFVCEwT7EF2JKNY2T0d5CFnTdrYpRYn2)Nxv8BU9)Zl5ZV97E)69D7FVYyv5I8SZJ)qmT7Yp8XVnpNplVE(k5dzS)2JiA8FU7YBF)KmKKRxb)2N25l7GlYJE2NSMqfqf1V3E73T)2M9B3F)5FPz2v58XKMKlYJNv)9M9N2F57p8)73Y9Rxlg)N95lEo79YJE)jz8M)1N9B)7YJu7G)KW)EFB7VE3E7)9YbWa9YxUo)7s5Fl)MF5B)87V4Y)52U82s7DxTDVDlz)75YYJmcF)x)Y7E58JmcVF6r2JKtE55Bt2)YNFx95p87xz2JpZX8UBmI(FSEF8F5YsZM)1V)2FYJCIpKoEn(d(8cZI)1hJKZ)8FpFBKT4pZXS4pZXEIUfvOWGKt3FE8DnhCIF3E7Xz8J)jDz(Jdz)3YnLl(g57Myn9z3r2x8J4k)3VBZMYlES(3p8kJ8xEGYBX5pZnwc)Ep(6YK)FxtGOdmz)6XKuCJ(2M0dVWm4CGANJRaR31n5RFkMB2nYxVJtSY)lnxfZjIh3vJ(N)hVU5GtzJ)9Y7uJ6Y7OOlz2l0N)9n7h7z3pXs1bznhUJB)2VYwSb1HGXxIKXsf6YNFEnOTF6bVv7(5(7lN7VhB)2p1YczjlX5h93nKpFnHn8lKQ1(3J)GJ3)x)JDLNpnBFo)XHVF6jHdVcMGKKKKK1d6Z7(n4()Y7YFKdEkqGvdHjK)zt8ZV(7)n(3sJ6l6f5X)7YYBl3FKYTVMVFoFpZYmJH7F5T)kJ)j7n)72V7hYJO(7NF7x55XzpZxmj5l5XUgJ(Blhfvfz)ck54pZJYx(g8JQbEWHKK)1)8JR)3EFtVE7cEL5xfxS5vXLfBEvoElGTEEjFzFjxgJxXL5GdJfBlwSwmNnLKQtKLJfBSwS7w8KFWWWvXLrXLnL5GdqOo7fBUcwdNXLQYTIl1mBv5swS8USFP8Yg8U5vXLLXcEIz8)HhY7c5XuSHJGhRhZbOxlvLQdFSGJZJJHzPwQYYhzKGCFCnOx2nv8owbhXsOWYQvPYwGJlBl1hEQsYMpbdFhsQ7xVIKXdVa9gIINRmxhNfqJxhJOhYT3FNpQzqVoZEo)LFhFKYk5ZqUX8dIVF0Vnh5dZ4z2FNmGz(J6ZDgYHYlzlHpKzgR0Blz2KusSjGzKRNx(mGbwlG)8Fh)Bv7sWJIvVEMqK(h)YXzQK7Gf)m9FrghsI6Bh1uNJF)YS9lKGVmW47gOjlwFj7eMy0TjYIH7rYjHYGGa5FNPE)2ZMnR5Q5Yf6aPNZCHaVzV5Y0yZL1lhOZV4F5(x1CUjqKK70mHUuPwlhjOKzNAQkJL1fJ6f7ysGY8jdLxLVXoOGOQkJNHc(7gRcKVP5E8vMLzzPgZYzgJaOXpbqVw(GDN1n4VrEX2Z3Zh2gKQ2t(Hv6Ky8I6JxcJmOyELGlp(D4V6Y8owFfMTF5zhAZ6E)yPKzsHR6xFtAzznjNuIqYF1M7E0b(cZmzOiE9WBjMEzf1sIYa5CnFO8y8GYJJJOQqLK(T5HrGj21fk3cCQMqGwWrmB1PVV8GhVYKCO2yC8FcDLTj9O)YYqHO5E3RuEQ4YIOGh8SyBLEWh(G3owI)(Jy2jZJnvgFfxSXKzGEBHhhfWJlvFvn1fXHzrCOF8GVxOLxBwCKLYR8)2S6f)LhggLzPVr5vHcELAzj(8v)2)mH1pwLBLTaVbIkLhJd1hhOFx2J0Fg)LKl9S)Sc1jjKGx87()V8FxgW8DMMCC7JHmhVy2BxCFxgPvAUIJ(7B9LTVnSh3Q9x85YGOx(NMjmJ5dI((3gEIXCPuUZGVZKzO38J6CY95MUjvxSrApkJ4kL6gKLVRG3t)jrJUB5LUHYuwsn48X4lJIvOKGBCEFb2TIjr6JTZXz3j6d6X9qgKE)X(qJZtXnKTzAGPo4ZfGJoSfxaVT2BPJY3(jvSJKcTGZKLLYMJYZdHjr8qohCE31uXKpPLPWQTLnJjQsZbj)lnJNPQ8F2HhJLSa8gvGdGa85KYGtPd(o6qhZ)dDCTGZG0q85hAirhJRZdoKsGqhjx1JtQqUF8qZMPV4W)RjFe4BOqD8Vd)R6VKUNbQqTN4aDIUYGHFtCCc4KIgzaXJqaGvg8MJO25H8ZT26dYYLXHNqozJGO4CCFqgQM85LQXKCpzY2Qf8kTbOI0RIklrP1GiryQ8cGE9Fy4aOdjOhg8U46vGAe0GgkPcyq9(LvDCzjvBAkMSkWQqwMILDaF7YhJRGVpCJqGqe6lSjWFO)YGu9GSEeYmzKdS2PKFjqJGnTjkLzD2SFXxhKcNpJMSdgI1aXLuKfScBTiOPgaSP3Lz4HjmTF9CmTsAPgaSZ1tHBGPX8H3MjDlGd5(RdJdjLQS1sC(Zt5AuKQhCx4n5YFNLHqaQJNuWyZg1PGVZfYLPx)g6hSxWrxJGhIRYEOGzYQJ9y9E9JGOFyeD8q0QqSsrF6IxdLBGRTZO8MtFgKI8zStAw81fUKJYYOY0gKPn(MqB2sSvTQHzjGGxPeYmEP9vGuBxIe9Qm4FKzxcrnFKIcm4QIzaU2u9kbyS7aTpvTODJRc5uxDLrKGzABaJKYEGCIhWz7gFGLX2sJ6Qg8qqFJXdKLmOb8KhGWPQQJQzOLCOX2GF29QqoMvX2aQvKyL2bCvKdXFGRkBhHJJXbVhSJzLTZzVGcwPu5CqmjEUWZxA5mJBqOScm4vSKSmJR2qOvDiOEjRuYNTJrYcgC8BLmGqfJnOr0cFODCnuYjzKDjyTbWE2eINfQ(ycNVmTGOhfKGZqTfyWEGHZJnLTBBKOBCiXMGAXzTIXGC1yKwrQQERAOqJhJgjb0KumDbgxcgCCHXzgTRH6GJKHPo5JvCzWnFCYK9KxfQHG4vOeqO1XO(qKO2Mj6LTvgGRMSqh1vgDqdjuWuNz3tBhsKFmkB1P8CzYUe(ZGLPKcxfBu2oVUW4gZECedbr2vvZfqZsVpOgeCGGV7r)PSkO8K7vlnWTK2Dpe2BXxTPdON47iKqoUXJNUGLFrNQJLI(gX2sjnF6jYLPQnYHXHjpvgH)X4j2DZ0uQQXnQqHvLdJNgGaTkGJsXxOv4H2xFiYyGQsgJvL0iJaBfv5mU2oQJFMYQLRUfL3NRqYPeHvJeYBLGZLLRJL6DdY6vKMPPOIZsOyqGAj4fUTTKkUqjrHUDgKnhG6KReBczgfNJQgm2yecN3iGt6RUevH8GTWsOJh4OyMjnDbRJNJ2hLFW2J9nBOKXJBZy(YHt1CbLOVQyJWsLFGcKBGMQ6GJOQYYBLj1yGDKUcfhQcZejKi4mFhJlmSvHchzgWD1b7dGKZEJnmMwvDbsGqgq4qjPeZRbD4uKKoYgbLGFDzNNpJXlOH9C35vJGWH2qjJd2QoGI02KIK6(UrN4)zyxZiAjNPtXJt6Y1vUGjV5T2tTbFTdnmTjVF12oAqBdejYE6XsDDdHPrUvnCZnG51OP2QqEv6MNJKBfJUcjR7BhvHJ9qnY5DZs14R1RK9NmBRt7YSQ4YZKmdCFcI5EFVfZYWDq7lJPY0sFvUHCpYZVlXWPq4eLpVTzLqhOaU4qGbXHkQ8E5G1GjvmJaKKrL2w4zLSk3vvTnOPQIzJLrOTB2ZQnZAjLxLn6YKdqI8iCr5XbdxPXKPDnzjbGwrwLpyHPqz8vwIg4YUvmJ4vX)GBX4QXSC8oOqrGcOwBGcxb6m(pCEQxEwfDEsj8kwXLJZ2OZbCvPnrJNvY8KHNj(v3YFLLnlNm3ILNnvvFxdIqRUQa3LmPgAaKQHQqzQLHaG8BrCZBUMjnVYv)xpnCXCzOIhvnFKdKC1FUcvPwNKJPq6GmQakmGrVJfBKGhzT4vjQgxZK6)d0sGUJCgHLOCEf4O5lVWsF8)y7sAGJZlNjgG(0s)iK48eO9(AhIg0YqiKUVB7uPrEhRrEfxUqjdaGrKCZCKJ5OiF3OL2O8g2kSJuiHb0lGGbX7U1nY6w23GUqfK5i43BLKcPGQmllqf8ySHGh6x(dGr4FnP3qiGv3iyKgLyqAI4VzMXa8FgJyK3OGDngHmjvzA8JXDH3GcEUf6gLKK3n71oNfFGDqJmZYGNFhJ)r3WzSzNOzGY2PNGo1e6zZDFoUUqczmKKLrCjkB6Q2rMNYL9P7qOHROEHYJB0G7MNabyOZT2VhJq6n1Aou2c)bJFGrMvK(XaBNKmcmKxWOl7UJc9GXzJZq0i6RZE84UqwM3eAaZJfyQmYFBqvgLyJNIFqbMo8dP6y0WfX8JrnfzVcFyKzoJpyqDGlYhGUd5GHvQsGGOEKlEGhOVKr0vKQQXOD4nKg)K4Q4HSRpq0yEaVhJYgKuBZGWKuoJU2h1uD1p7ScsNcOGrEp4YQnKGVhJjMJGZfQZOdHnZnudQqZpQzX8nQTbOLFagOO4Lk1Cq5RWKcw97BNRgJmIJU8QkJOFTz3rTn8kJKOhj06S9)KLnJ8IhKKvd4M2dA1JKrQYZrUKrdwsyb6g8fJTDmjPdgrPTsv6bMiQVGbOiuFmBtKagGXIbqUIa2XKmJjX4VC(2sIjBg2nLHyJqbcUe0nI8FfFULnK1gKLFJl6gnUfOvKJgUaINQ8rn0sIxWKk2DKfCuKpx6dMd8kXgBbEKc0XJmUQGLBXUDXOQgF(I9EB42KdPDgNNaOWJKSZzMKzDQhE4zqgY)Bzt5v7IHH1Fn7iOzmnPdpUcpwK9HIbpZO5FNO87OQ8dIjMzEK(GxQBk80SbgIj2SbOaDnM3n1WP7Ndb(iXqxW3mKKGWqN9mQ(8z7CHUDbKrSpyJYbKNpKCdUVNkL0DLhHLqJrZT8zjnLm0qj3f(FhJpyxaRJnI6dELBs1GMGUqVe6rUbzJoNJMxhLKCMI9cNdPsAKNiMR8U3sjJkJ1oAUQ8JsQj4QiZd34xwfqyGj9YIxlFurlpEIjf8CTAjIqfq4AqpGmYlq1nXEKQQgGhKr4zOa96k(r4Sb2dWoI6u9iDIkD7f)q6Ww4oLJlNyYQ6cYKbMIU82iGXUKLGNOsYxFNOAGU2TdEfnQdMM8KyXcJkn4aJW4gKHkoCHKNKCtbOBzWw5ivcppNPsKIK14Cb8A2K5KdECX94Ay9l0i0s7KLKvpFzUqJ3RXZhfCJU5vu3UJBfZM)OPKu1LqZ3CaAM39kY1jfmJLlGHKfx8Y21s5lZwNNzs5gYgUTz8t0KSKvqGgCKfKqz5E(hxaWv3yNqN(AHvyRNnyKQHt7)fqqTUe1ZRZQ9dHfwFyacFryGX7aNd9UOtRQhEKLV2xHjSNlJyKkLFCLpCrr8HFH3Vdz6OOELVCHzXy4fRd9qrMBjJJ1X9w3i9lL9vD8Vfq5lbJQCRsLr6LmSXcJPMQq(QmJq1YBT0K86xlfOsJrrP3vCKKKKKCZ7JOwJKkRD8(3mC1Ajs)bSDjLvCmwEK4Zo67vPPwgHzDMvFHYCH6o4J0HqaRJROvGsQDjLxrCCg5LNmLhzKH5u3WVOP4yYklOgLRl4HKwLU4AO6OOWDOBC9KLLtmJZiCwA7UHqJLQrZtb1kfMLz1k1Jg1BNGKpPGzfYqGGv0pCMGk2Uj5b40Yb0X4OHFKd4Y4xUrZCU7ETUP8EjFrJpN8(3lF2M6YzEL85u)qDyxCEOAyb6QKPJsEZUYjNOQfXU0y0sYxvxJMM3l(O6CxqfLg7J1Q80Y1uvw5hUQC(2YYfJ7c1xzKfRfzCd75IFXh1Lj)q5fJMuJqX5p)0qg2qI3w10n3SoRQ1Bt7lSMcQLGGf3hCkL(K2YmGP5x(h9qAH8xPJKgEjH)95YvC6DdlpgMlG9pD9bJh3IzWNn8fYYZK)v(YkT7F5rHdFFvU(wfKHJ9Y0Uw5zppj87tA5xqpkKO4tA5gZLY8f)MYDnRu4xyX8XHDbPJ4vyFh)YsKDvD05XjKLUvRVNLBvPPJvUGT70LgVJYlVrCyxKvxFW(k(t)fKKUOVJjETD)pDO5v(Lz7PB)VH6RGnRjGnOFAGUx0y3FkOZo3O0B6Ay0B5pL77jjgmQ0PnAmWF5pn9qUB)Eqk7TwznHuZn2Sn2Py04n2n1n(3J5YfO2bBTAn15iBkBN3ZFiPv(Pu3PJR2BT2zS3S)SPMA8bT3r(X8qZ2PJH66QPMsno9VfE5JJyKhc9E)Vr)h8p7oV87y7SXMk7(BHGLdMAYYFgpOVUGDHa0qNyUaZdyVPc75YQRjjgZUd6Y7hNLyTzY(bxVq8G4bBrXw5Uo1g09x0xF5B1E95LV(Uw5fL5xNz8FHKo3XENGcSDvqGzHGlS8E(IzEX1(5qfF89LzJxf1YIb12fz71cRFi66Zw5ZI5b3U6Z8gFvEVNFu(IqTwrx)bnJl4g1Y2WwNKo1v)qY3vPO9qQ(NWS)N1xCnyE9Aq18b9q1vKWwHHpJcE1gFKGLZmQ1zxI2LIx4Kz6BFUT(JztFzLF1b9(pnAK5rSFZhK5oP3yKrIYhJNL67lCZWd(z4v8U74b8hQlJvqAfN84z4b7zN(x0nqflVmYpCE2UwHX7FlFvSKXzr7(nnJqGIzYUnhTDG0X77oD5uNX9pV4nKEr(IzvnGnpz(xf5gJWr8z3qhqI4l7d6tI8wfX1fNGN4j7N4BDm5nDMZEGT6Q2FXH7x(dJ)0Sq8m(S3Gd)g8sYXgmFDm1cBj4QiHrNDEomHXOOxjgF(Gd9K5cF(fqjSq7lmOtK8w0cINdwOJe7Dp5E(oMJTn9J3QBF3qpVUvPz3MnwN8c1TU(2R3P7QHzE17Y5E7m)pFAE)UFJBQxj3o7RF)DxA9m8)2NEYM6IwdF(IEU)tz(V)9g4G7YHHL0LPpUHRZfDVnN4Sw7gk)TzKR(w6uv(Gn9zKbgRV8X86hBxp8VVmv)VVl3z2k9pMFd)1RxlzrHF6FVh1p7L7XAXF5c5Y6pF2nJRxFKIYfP4aVzp1(5vQ7U90THCzEvzVnzQM3E5h8FnvfFzK5lSWZ5E(TUESwQvwTQ5)5OYLv6(Ej)N5MZR7f)0Wc5SXPMgKFy8BKLvHkD5YEP2Xj)LbKSSPQB5rRIDjqBXyT4vSDTiCJO3I)8Yp9KvYLcF93IZpVpEo(T7BBzZMt(h70M)GFVX4(w3d9xp)HZZ)cOZqZN7EFPXJvGSDcXpNG76tPUDZ9R3VHmpmLVFZk7hx5pYrm5Lq5gCZ4xhFLw3NL9)VKsRHgAvJEzjYFDfITglPAPDtMZMhrvdx2zSlR0p8U(NKjDXXUTPT2O34N)0YNZQYOJBnYZNSJNDgNRHIGU4qvvb21hQzNR3Ns9XG4Kb6PB8zr6RQRp7Y2VZlpd0FhJO9pFXyZPpQ23Uq0UQBDVS2Wv3tJ4H0V1wQSb0G0wJ6rEhR8G09rL)qIhM)3NpI47fGYH5Mh2vKpV)nRhEfnCZKovXJVcPz6xd2FE)I]])  
