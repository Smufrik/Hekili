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
    barkskin = {
        id = 22812,
        duration = 12,
        max_stack = 1,
    },

    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1,
    },

    frenzied_regeneration = {
        id = 22842,
        duration = 20,
        max_stack = 1,
    },

    savage_defense = {
        id = 62606,
        duration = 6,
        max_stack = 1,
    },

    -- Offensive abilities
    enrage = {
        id = 5229,
        duration = 10,
        max_stack = 1,
    },

    berserk = {
        id = 50334,
        duration = 15,
        max_stack = 1,
    },

    -- Debuffs
    lacerate = {
        id = 33745,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
    },

    thrash_bear = {
        id = 77758,
        duration = 15,
        max_stack = 3,
        tick_time = 3,
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

    -- Buffs from talents
    incarnation = {
        id = 102558,
        duration = 30,
        max_stack = 1,
    },

    heart_of_the_wild = {
        id = 108291,
        duration = 45,
        max_stack = 1,
    },

    nature_swiftness = {
        id = 132158,
        duration = 8,
        max_stack = 1,
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

    -- Generic buffs
    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
    },

    -- Procs and special effects
    tooth_and_claw = {
        id = 135286,
        duration = 6,
        max_stack = 2,
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

    dream_of_cenarius_damage = {
        id = 108373,
        duration = 15,
        max_stack = 1,
    },

    dream_of_cenarius_healing = {
        id = 108373,
        duration = 15,
        max_stack = 1,
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


} )

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

-- State Functions
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

-- Abilities
spec:RegisterAbilities( {
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
            if talent.infected_wounds.enabled then
                applyDebuff( "target", "infected_wounds" )
            end
            
            removeBuff( "tooth_and_claw" )
            
            if set_bonus.tier16_4pc == 1 and active_dot.thrash_bear > 0 then
                if math.random() < 0.4 then
                    setCooldown( "mangle", 0 )
                end
            end
        end,
    },

    -- Lacerate (Guardian ability)
    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 132131,

        form = "bear_form",

        handler = function ()
            applyDebuff( "target", "lacerate", 15, min( 3, debuff.lacerate.stack + 1 ) )
            
            if talent.tooth_and_claw.enabled then
                if math.random() < 0.4 then
                    applyBuff( "tooth_and_claw", 6, 2 )
                end
            end
        end,
    },

    -- Pulverize (Guardian ability)
    pulverize = {
        id = 80313,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 20,
        spendType = "rage",

        startsCombat = true,
        texture = 236149,

        form = "bear_form",

        handler = function ()
            if debuff.lacerate.stack >= 3 then
                removeDebuff( "target", "lacerate" )
                applyBuff( "pulverize" )
            end
        end,
    },

    maul = {
        id = 6807,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 30,
        spendType = "rage",

        startsCombat = true,
        texture = 132136,

        form = "bear_form",

        handler = function ()
            if buff.tooth_and_claw.up then
                local stacks = buff.tooth_and_claw.stack
                removeBuff( "tooth_and_claw" )
                applyDebuff( "target", "tooth_and_claw_debuff", 6 )
            end
        end,
    },



    -- Defensive abilities
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 136097,

        handler = function ()
            applyBuff( "barkskin" )
        end,
    },

    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        defensive = true,
        toggle = "defensives",

        startsCombat = false,
        texture = 236169,

        handler = function ()
            applyBuff( "survival_instincts" )
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

    -- Rage generators
    enrage = {
        id = 5229,
        cast = 0,
        cooldown = 60,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 136224,

        form = "bear_form",

        handler = function ()
            applyBuff( "enrage" )
            gain( 20, "rage" )
        end,
    },

    berserk = {
        id = 50334,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 236149,

        talent = "berserk",

        handler = function ()
            applyBuff( "berserk" )
            setCooldown( "mangle", 0 )
        end,
    },

    -- Utility
    faerie_fire = {
        id = 770, -- Faerie Fire (unified in MoP)
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = true,
        texture = 136033,

        handler = function ()
            applyDebuff( "target", "faerie_fire" )
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

    -- Savage Defense (Guardian ability)
    savage_defense = {
        id = 62606,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        talent = "savage_defense",
        toggle = "defensives",

        startsCombat = false,
        texture = 132091,

        handler = function ()
            applyBuff( "savage_defense" )
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



    -- Swipe (Bear form)
    swipe_bear = {
        id = 779,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 15,
        spendType = "rage",

        startsCombat = true,
        texture = 134296,

        form = "bear_form",

        handler = function ()
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                -- Hit multiple enemies
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
            applyDebuff( "target", "thrash_bear", 15 )
            
            if active_enemies > 1 then
                local applied = min( active_enemies, 8 )
                for i = 1, applied do
                    if i == 1 then
                        applyDebuff( "target", "thrash_bear", 15 )
                    else
                        applyDebuff( "target" .. i, "thrash_bear", 15 )
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

    -- Symbiosis (MoP ability)
    symbiosis = {
        id = 110309,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        startsCombat = false,
        texture = 136033,

        handler = function ()
            applyBuff( "symbiosis" )
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
    desc = strformat( "If checked, %s will be recommended when you have sufficient rage.",
        Hekili:GetSpellLinkWithTexture( 62606 ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "savage_defense_rage_threshold", 80, {
    name = "Savage Defense Rage Threshold",
    desc = "The minimum rage required to use Savage Defense.",
    type = "range",
    min = 50,
    max = 100,
    step = 5,
    width = 1.5,
} )

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



-- Priority List
spec:RegisterPack( "Guardian", 20250918, [[Hekili:1E1wVTTnu4FlffWPflvZXjoDRRPa7g2AqxrbC7EzOsIw6ilclr6rsfp3h0V9DiPUqRBo1d7HMMiE435(HFh)R8)O)QyIc8F)I5lwo)7V678wSyXYL(Ruh2b(R2rI2s2G)cJKJ)CtbretjmI(KdzCsSgajVqeHN6VADbnt9wM)6br9MxIYUdI8F)vZVXFvknogSYcYi)vFmLkld1)JugwP4YqEc(3rkkNvgMrLk84eUOm83HT0mQN)kZhn(bKqkYu4V(EJFbmY6mi2)NSkqq3PrXF1pZfiUcUIyrDpvLwg(aW2aewKwLOG50VqSIBvo()fkEarPqdZxHEwhvG4RabfJmkIydO8IisfLTPmCwzOZNcOmuorbQd8QTWl3wKLfSMit1OFDh0RLkIGcz)JaTJBD)aB2bdaatsFaKAiU5CGiIZZI57zgewEoi0ehdQJWAOU9CGsQiSySGdbapyNaI45RjNob)lIcA8Rkd)TQQ1YWN9h8p88YWFLLQTS4YWF8dVRoX)NTjE5bPcYXAqmfTr0j)VgiIaS0lF6S)tkdxxKK4LteBd4jbQuiypnl2RyxlwDpCOuUngKZ3ueSJVhe4pp2GQ(BtWPnVnqWP1desqSTx7q9vD8cJlujVN(0tvYNbmLhLfremtCZRsot5Vbn3dni2yxoNmuGONAsXmH6OyBpL1xKJvzVZTHrNoOjIJYcXd0hizyRSUfpch)0PaSggC01ACkLIc4yRNLs3KcsfoCtq5OtD45UohAszQuVDrOaVUm865thY7i(Y5o5zS6sULEIGzhaUDEB0lraSVqH4abSbyGyOK2GYm0CNofvubNLuimOz0OWmM)n3vgEZsNAcRydngQdGQubo0mq3EI9yToH73L6P2wLCTtdur2diqFbSj)MXntK6ZjSnzqN0DZeKxu9YHUsS99LNTpfyh9aJXC0VZPFisxvGZMEb(kbKVJlicA2HYWyQSQM2QBPx)jRFZDFR1GUKMCNmLxKfhuvBHgrqmj3eBNeaByAkaMPV)dqaMLZXc53C3ItaPCpD3KMupeV(eiMrI0vytdAmx5vlONaYjy75RrKxvLxpkNGUnquViHhviH4N3RQYgxFeJ(o2vS1ylAlySH3P7ehccNYut4C6oRHCD7uKwyQpF6wQyWobGG)jeKqfq3((2tAEyVB3rlYOeV0vIgJ4izmTF7X3aq(ssnrqSOLQ7fuvK9UOIB3fyoe(7cu3y2uYZ1f3iTSCer8dr4R7BaPx59VJYWJUc5a8jMSyNgP2ojeohUCxGIxE)WQS6TGVoTEZOATAM2fnIUCurBgnnQ5vpT6RZ4gpKyZDT221JkPPESvWBFeqAS)eEwgFVHsmPa7kqcyGEaOUbuZ5chaMcht2xpkxvlhJBC(c2rshhRfg32GGCNHxHrl9OuRQTHo9gf7e8eAgyxViNkLgZOYORcPMNXOriWckBlOWOwyz4Bv2lzyFMdSyTXQsj4NbmfDO91CTvfLveRBHbKAjiQTM)6tsqJeKl)8LO7KsJsDLMWo0Q1khf(NDz0iQkRfxx)UwP)aUUIOwnF0cbMM)Sg0y3pTWrZiHNmhpQcsvTOMOH5tSICKeOPYkdhXuE)BZRZYl7SwgEOzhPuUWF1Q8IebDRM0UjU7V6PLHJrl)(NEwmZ1j36hnA2naFROHN(Wh3L6T(jLNmgJ9HHWs8(snb976XpxBwOd9vTKzJAqWDgn5(521d1g8XRyoB01lDrO7Qww7VDk3PLTzjJtlA)xXp9DQNOvfbF0KOBtsToJoI1JLUoY1Y691xpFKBwZFUJ8lht(bPc35Y3oF2jOwpc4vpAOHRh)5zAUZV5UBwoYDBEfP52htwE2WeL18XQRI7MX9AkcmTAMfeBq3DHXHVHZQE264X2BC2G7momO9wMZb6r3vC2e7jw59))YRxRHAV5CP2Fsmol29Ne1ZHG)jb9)chFB(6Xq0VTcQECZrr6UC)hu82G6aXUbKVjCnquzaXDdeJ5VdCnhI5MBomr(j8)jngdhD))9p]] )
