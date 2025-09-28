-- PaladinHoly.lua
-- Updated Sep 28, 2025 - Modern Structure
-- Mists of Pandaria module for Paladin: Holy spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'PALADIN' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 65 ) -- Holy spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local function UA_GetPlayerAuraBySpellID(spellID)
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitBuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitDebuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    return nil
end

spec:RegisterResource( 0 ) -- Mana = 0 in MoP
spec:RegisterResource( 9, { -- HolyPower = 9 in MoP
    beacon_of_light = {
        aura = "beacon_of_light",
        
        last = function()
            local app = state.buff.beacon_of_light.applied
            local t = state.query_time
            
            return app > 0 and app or t
        end,
        
        interval = 1,
        value = 0,
    }
} )

-- Tier sets
spec:RegisterGear( "tier14", 85354, 85355, 85356, 85357, 85358 ) -- T14 Holy Paladin Set
spec:RegisterGear( "tier15", 95290, 95292, 95288, 95291, 95289 ) -- T15 Holy Paladin Set

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Movement
    speed_of_light            = { 1, 1, 85499 }, -- +70% movement speed for 8 sec
    long_arm_of_the_law       = { 1, 2, 87172 }, -- Judgments increase movement speed by 45% for 3 sec
    pursuit_of_justice        = { 1, 3, 26023 }, -- +15% movement speed per Holy Power charge

    -- Tier 2 (Level 30) - Control
    fist_of_justice           = { 2, 1, 105593 }, -- Reduces Hammer of Justice cooldown by 50%
    repentance                = { 2, 2, 20066 }, -- Incapacitates target for up to 1 min
    blinding_light            = { 2, 3, 115750 }, -- Blinds nearby enemies for 6 sec   
    -- Tier 3 (Level 45) - Healing
    selfless_healer           = { 3, 1, 85804  }, -- Holy Power reduces Flash of Light cast time and cost
    eternal_flame             = { 3, 2, 114163 }, -- Holy flame heals over 30 sec based on Holy Power
    sacred_shield             = { 3, 3, 20925  }, -- Absorb shield every 6 sec for 30 sec

    -- Tier 4 (Level 60) - Utility
    hand_of_purity            = { 4, 1, 114039 }, -- Reduces periodic effects by 70% for 6 sec
    unbreakable_spirit        = { 4, 2, 114154 }, -- Reduces major cooldowns by 50%
    clemency                  = { 4, 3, 105622 }, -- +1 charge on Hand spells

    -- Tier 5 (Level 75) - Holy Power
    divine_purpose            = { 5, 1, 86172  }, -- 15% chance for free and improved Holy Power ability
    holy_avenger              = { 5, 2, 105809 }, -- Abilities generate 3 Holy Power for 18 sec
    sanctified_wrath          = { 5, 3, 53376  }, -- Holy Shock cooldown reduced by 50% during Avenging Wrath

    -- Tier 6 (Level 90) - Ultimate
    holy_prism                = { 6, 1, 114165 }, -- Light beam splits to 5 targets
    lights_hammer             = { 6, 2, 114158 }, -- Hammer damages and heals for 14 sec
    execution_sentence        = { 6, 3, 114157 }  -- Hammer deals damage or healing after 10 sec
} )

-- Holy-specific Glyphs
spec:RegisterGlyphs( {
    -- Major Glyphs
    [56416] = "beacon_of_light",     -- Your Beacon of Light now transfers 100% of the healing done by your Flash of Light, but Flash of Light now costs 50% more mana.
    [56414] = "divinity",            -- While Divine Plea is active, your healing is reduced by 20% instead of 50%.
    [56418] = "light_of_dawn",       -- Your Light of Dawn now heals 6 targets for 20% less healing each.
    [66918] = "protector_of_the_innocent", -- Your Word of Glory and Flash of Light spells also heal you for 20% of the healing done.
    [56420] = "word_of_glory",       -- Increases the effectiveness of your Word of Glory by 20% when you use it to heal yourself.
    [63219] = "flash_of_light",      -- Increases the mana cost and healing of Flash of Light by 50%.
    
    -- Minor Glyphs
    [43367] = "blessing_of_kings",   -- Increases the duration of your Blessing of Kings by 5 min.
    [57954] = "dazing_shield",       -- Your Avenger's Shield now also dazes targets for 10 sec.
    [57947] = "blessed_life",        -- You have a 50% chance to generate 1 charge of Holy Power when you take at least 3% of your maximum health in damage from a single attack.
} )

-- Holy Paladin specific auras
spec:RegisterAuras( {
    -- Beacon of Light: 20% of healing you do is transferred to your Beacon target
    beacon_of_light = {
        id = 53563,
        duration = 300,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 53563, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Divine Plea: Restore mana over time, but reduce healing done
    divine_plea = {
        id = 54428,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 54428 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Infusion of Light: Holy Shock crits reduce cast time of next Flash of Light or Holy Light
    infusion_of_light = {
        id = 53576,
        duration = 15,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 53576 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Divine Favor: Increases crit chance of healing spells
    divine_favor = {
        id = 31842,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 31842 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Eternal Flame: HoT from talent
    eternal_flame = {
        id = 114163,
        duration = function() return 30 + (3 * state.holy_power.current) end,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 114163, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Sacred Shield: Absorbs damage periodically
    sacred_shield = {
        id = 65148,
        duration = 30,
        tick_time = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 65148, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Holy Avenger: Holy Power abilities more effective
    holy_avenger = {
        id = 105809,
        duration = 18,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105809 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Avenging Wrath: Increased damage and healing
    avenging_wrath = {
        id = 31884,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 31884 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Divine Protection: Reduces damage taken
    divine_protection = {
        id = 498,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 498 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Divine Shield: Complete immunity
    divine_shield = {
        id = 642,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 642 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Forbearance: Cannot receive certain immunities again
    forbearance = {
        id = 25771,
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "player", 25771 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Speed of Light: Increased movement speed
    speed_of_light = {
        id = 85499,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 85499 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Long Arm of the Law: Increased movement speed after Judgment
    long_arm_of_the_law = {
        id = 114158,
        duration = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114158 )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Pursuit of Justice: Increased movement speed from Holy Power
    pursuit_of_justice = {
        id = 26023,
        duration = 3600,
        max_stack = 3,
        generate = function( t )
            t.count = state.holy_power.current
            t.expires = 3600
            t.applied = 0
            t.caster = "player"
        end
    },
    
    -- Hand of Freedom: Immunity to movement impairing effects
    hand_of_freedom = {
        id = 1044,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 1044, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Hand of Protection: Immunity to physical damage
    hand_of_protection = {
        id = 1022,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 1022, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Hand of Sacrifice: Redirects damage to Paladin
    hand_of_sacrifice = {
        id = 6940,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 6940, "PLAYER" )
            
            if name then
                t.name = name
                t.count = count
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
    
    -- Divine Purpose: Free and enhanced Holy Power ability
    divine_purpose = {
        id = 86172,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 86172 )
            
            if name then
                t.name = name
                t.count = count
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
} )

-- Holy Paladin abilities
spec:RegisterAbilities( {
    -- Core Holy abilities
    holy_shock = {
        id = 20473,
        cast = 0,
        cooldown = function() 
            if buff.avenging_wrath.up and talent.sanctified_wrath.enabled then
                return 3 -- 6 second cooldown reduced by 50% during Avenging Wrath
            end
            return 6
        end,
        gcd = "spell",
        
        spend = 0.22,
        spendType = "mana",
        
        startsCombat = function() return not (state.settings and state.settings.holy_shock_heal) end,
        texture = 135972,
        
        handler = function()
            if not (state.settings and state.settings.holy_shock_heal) then
                -- Damage
                -- Cast on enemy for damage
            else
                -- Healing
                -- Cast on friendly for healing
            end
            
            gain(1, "holy_power")
            
            -- Chance for Infusion of Light proc on crit
            if math.random() < state.stat.crit / 100 then
                if FindUnitBuffByID("player", 53576) then
                    -- If already have a stack, increase to 2 stacks
                    removeBuff("infusion_of_light")
                    applyBuff("infusion_of_light", nil, 2)
                else
                    -- Otherwise apply 1 stack
                    applyBuff("infusion_of_light", nil, 1)
                end
            end
        end,
        
        copy = { 25912, 25914 } -- Copy IDs for Rank 2 and 3 of Holy Shock
    },
    
    word_of_glory = {
        id = 85673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = false,
        texture = 646176,
        
        handler = function()
            -- Word of Glory mechanic - consumes all Holy Power
            if buff.divine_purpose.up then
                removeBuff("divine_purpose")
            else
                -- Modify healing based on Holy Power consumed
                -- Word of Glory's base healing amount is multiplied per Holy Power
            end
            
            -- Selfless Healer reductions for next Flash of Light if talented
            if talent.selfless_healer.enabled then
                applyBuff("selfless_healer", nil, 3)
            end
            
            -- Eternal Flame talent application instead of direct heal
            if talent.eternal_flame.enabled then
                applyBuff("eternal_flame", "target")
            end
            
            -- Divine Purpose talent proc chance
            if talent.divine_purpose.enabled and not buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    holy_light = {
        id = 635,
        cast = function() 
            if buff.infusion_of_light.up then 
                return 1.05 -- 30% faster with Infusion of Light
            end
            return 1.5 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135981,
        
        handler = function()
            -- Holy Light mechanic
            if buff.infusion_of_light.up then
                removeStack("infusion_of_light", 1)
            end
            
            -- Sacred Shield interaction
            if talent.sacred_shield.enabled and FindUnitBuffByID("target", 65148, "PLAYER") then
                -- Extra healing to targets with Sacred Shield
            end
        end,
        
        copy = { 639, 647, 1026, 1042, 3472, 10328, 10329, 25292, 27135, 27136 } -- All ranks
    },
    
    flash_of_light = {
        id = 19750,
        cast = function() 
            if buff.infusion_of_light.up then 
                return 0.75 -- 50% faster with Infusion of Light
            end
            if buff.selfless_healer.up then
                -- Each stack of Selfless Healer reduces cast time by 35%
                return 1.5 * (1 - 0.35 * buff.selfless_healer.stack)
            end
            return 1.5 
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function()
            if buff.selfless_healer.up then
                -- Each stack of Selfless Healer reduces mana cost by 35%
                return 0.27 * (1 - 0.35 * buff.selfless_healer.stack)
            end
            return 0.27
        end,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135907,
        
        handler = function()
            -- Flash of Light mechanic
            if buff.infusion_of_light.up then
                removeStack("infusion_of_light", 1)
            end
            
            if buff.selfless_healer.up then
                removeBuff("selfless_healer")
            end
            
            -- Sacred Shield interaction
            if talent.sacred_shield.enabled and FindUnitBuffByID("target", 65148, "PLAYER") then
                -- Extra healing to targets with Sacred Shield
            end
        end,
        
        copy = { 19939, 19940, 19941, 19942, 19943, 27137 } -- All ranks
    },
    
    light_of_dawn = {
        id = 85222,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            if buff.divine_purpose.up then return 0 end
            return 3 
        end,
        spendType = "holy_power",
        
        startsCombat = false,
        texture = 461859,
        
        handler = function()
            -- Light of Dawn mechanic - consumes all Holy Power
            if buff.divine_purpose.up then
                removeBuff("divine_purpose")
            else
                -- Modify healing based on Holy Power consumed
                -- Light of Dawn's base healing amount is multiplied per Holy Power
            end
            
            -- Divine Purpose talent proc chance
            if talent.divine_purpose.enabled and not buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    divine_plea = {
        id = 54428,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 237537,
        
        handler = function()
            applyBuff("divine_plea")
        end
    },
    
    holy_prism = {
        id = 114165,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.35,
        spendType = "mana",
        
        talent = "holy_prism",
        
        startsCombat = function() return not (state.settings and state.settings.holy_prism_heal) end,
        texture = 613407,
        
        handler = function()
            -- Holy Prism mechanic
            -- If cast on enemy, damages target and heals 5 nearby friendlies
            -- If cast on friendly, heals target and damages 5 nearby enemies
        end
    },
    
    light_hammer = {
        id = 114158,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.38,
        spendType = "mana",
        
        talent = "light_hammer",
        
        startsCombat = true,
        texture = 613952,
        
        handler = function()
            -- Light's Hammer mechanic - ground target AoE that heals allies and damages enemies
        end
    },
    
    execution_sentence = {
        id = 114157,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        
        spend = 0.38,
        spendType = "mana",
        
        talent = "execution_sentence",
        
        startsCombat = function() return not (state.settings and state.settings.execution_sentence_heal) end,
        texture = 613954,
        
        handler = function()
            -- Execution Sentence mechanic
            -- If cast on enemy, damages after 10 seconds
            -- If cast on friendly, heals after 10 seconds
        end
    },
    
    beacon_of_light = {
        id = 53563,
        cast = 0,
        cooldown = 3,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        startsCombat = false,
        texture = 236247,
        
        handler = function()
            applyBuff("beacon_of_light", "target")
        end
    },
      divine_favor = {
        id = 31842,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135915,
        
        handler = function()
            applyBuff("divine_favor")
        end
    },
    
    holy_radiance = {
        id = 82327,
        cast = function() 
            if buff.infusion_of_light.up then 
                return 2.25 -- 0.75 sec faster with Infusion of Light
            end
            return 3
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.40,
        spendType = "mana",
        
        startsCombat = false,
        texture = 458223,
        
        handler = function()
            -- Holy Radiance mechanic - heals primary target and all allies within 10 yards
            -- Also applies a HoT that heals over 3 seconds
            
            if buff.infusion_of_light.up then
                removeStack("infusion_of_light", 1)
            end
            
            -- Holy Power generation
            gain(1, "holy_power")
            
            -- Divine Purpose talent proc chance
            if talent.divine_purpose.enabled and not buff.divine_purpose.up and math.random() < 0.15 then
                applyBuff("divine_purpose")
            end
        end
    },
    
    avenging_wrath = {
        id = 31884,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135875,
        
        handler = function()
            applyBuff("avenging_wrath")
        end
    },
    
    holy_avenger = {
        id = 105809,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        talent = "holy_avenger",
        
        startsCombat = false,
        texture = 571555,
        
        handler = function()
            applyBuff("holy_avenger")
        end
    },
    
    divine_shield = {
        id = 642,
        cast = 0,
        cooldown = function()
            return talent.unbreakable_spirit.enabled and 150 or 300
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 524354,
        
        handler = function()
            applyBuff("divine_shield")
            applyDebuff("player", "forbearance")
        end
    },
    
    divine_protection = {
        id = 498,
        cast = 0,
        cooldown = function()
            return talent.unbreakable_spirit.enabled and 30 or 60
        end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 524353,
        
        handler = function()
            applyBuff("divine_protection")
        end
    },
    
    lay_on_hands = {
        id = 633,
        cast = 0,
        cooldown = function() 
            return talent.unbreakable_spirit.enabled and 360 or 600
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135928,
        
        handler = function()
            -- Heals target for Paladin's maximum health
            -- Applies Forbearance
            applyDebuff("target", "forbearance")
        end
    },    hand_of_freedom = {
        id = 1044,
        cast = 0,
        cooldown = function() 
            if talent.clemency.enabled then
                return { charges = 2, execRate = 25 }
            end
            return 25
        end,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135968,
        
        handler = function()
            applyBuff("hand_of_freedom", "target")
        end
    },
    
    hand_of_protection = {
        id = 1022,
        cast = 0,
        cooldown = function() 
            if talent.clemency.enabled then
                return { charges = 2, recharge = 300 }
            end
            return 300
        end,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135964,
        
        handler = function()
            applyBuff("hand_of_protection", "target")
            applyDebuff("target", "forbearance")
        end
    },
      hand_of_sacrifice = {
        id = 6940,
        cast = 0,
        cooldown = function() 
            if talent.clemency.enabled then
                return { charges = 2, recharge = 120 }
            end
            return 120
        end,
        gcd = "off",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135966,
        
        handler = function()
            applyBuff("hand_of_sacrifice", "target")
        end
    },
    
    hand_of_purity = {
        id = 114039,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        
        talent = "hand_of_purity",
        
        startsCombat = false,
        texture = 458726,
        
        handler = function()
            -- Applies Hand of Purity effect
        end
    },
    
    -- Shared Paladin abilities
    crusader_strike = {
        id = 35395,
        cast = 0,
        cooldown = 4.5,
        gcd = "spell",
        
        spend = 0.06,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135891,
        
        handler = function()
            gain(1, "holy_power")
            
            -- Crusader's Might talent interaction
            if talent.crusaders_might.enabled then
                setCooldown("holy_shock", max(0, cooldown.holy_shock.remains - 1))
            end
        end
    },
    
    judgment = {
        id = 20271,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.05,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135959,
        
        handler = function()
            gain(1, "holy_power")
            
            -- Long Arm of the Law movement speed
            if talent.long_arm_of_the_law.enabled then
                applyBuff("long_arm_of_the_law")
            end
            
            -- Crusader's Might talent interaction
            if talent.crusaders_might.enabled then
                setCooldown("holy_shock", max(0, cooldown.holy_shock.remains - 1))
            end
        end
    },
    
    cleanse = {
        id = 4987,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.14,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135949,
        
        handler = function()
            -- Removes 1 Poison effect, 1 Disease effect, and 1 Magic effect from a friendly target
        end
    },
    
    hammer_of_justice = {
        id = 853,
        cast = 0,
        cooldown = function() 
            if talent.fist_of_justice.enabled then
                return 30
            end
            return 60
        end,
        gcd = "spell",
        
        startsCombat = true,
        texture = 135963,
        
        handler = function()
            -- Stuns target for 6 seconds
        end
    },
    
    hammer_of_wrath = {
        id = 24275,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        
        spend = 0.12,
        spendType = "mana",
        
        usable = function()
            return target.health_pct < 20
        end,
        
        startsCombat = true,
        texture = 138168,
        
        handler = function()
            gain(1, "holy_power")
        end
    },
    
    consecration = {
        id = 26573,
        cast = 0,
        cooldown = 9,
        gcd = "spell",
        
        spend = 0.24,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135926,
        
        handler = function()
            -- Creates consecrated ground that deals Holy damage over time
        end
    },
    
    repentance = {
        id = 20066,
        cast = 1.5,
        cooldown = 15,
        gcd = "spell",
        
        talent = "repentance",
        
        spend = 0.09,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135942,
        
        handler = function()
            -- Incapacitates target for up to 1 minute
        end
    },
    
    blinding_light = {
        id = 115750,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        
        talent = "blinding_light",
        
        spend = 0.18,
        spendType = "mana",
        
        startsCombat = true,
        texture = 571553,
        
        handler = function()
            -- Disorients all nearby enemies
        end
    },
    
    speed_of_light = {
        id = 85499,
        cast = 0,
        cooldown = 45,
        gcd = "off",
        
        talent = "speed_of_light",
        
        startsCombat = false,
        texture = 538056,
        
        handler = function()
            applyBuff("speed_of_light")
        end
    },
    
    sacred_shield = {
        id = 20925,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        talent = "sacred_shield",
        
        spend = 0.23,
        spendType = "mana",
        
        startsCombat = false,
        texture = 612316,
        
        handler = function()
            applyBuff("sacred_shield", "target")
        end
    },
} )

-- Range
spec:RegisterRanges( 
    "holy_shock",       -- 40 yards
    "judgment",         -- 30 yards
    "hammer_of_justice", -- 10 yards 
    "crusader_strike",  -- Melee
    "holy_prism",       -- 40 yards
    "light_of_dawn"     -- 30 yards, cone
)

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 2,
    
    nameplates = true,
    nameplateRange = 8,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent_potion",
    
    package = "Holy",
    
    holy_shock_heal = true,       -- Use Holy Shock for healing (true) or damage (false) 
    holy_prism_heal = true,       -- Use Holy Prism for healing (true) or damage (false)
    execution_sentence_heal = true, -- Use Execution Sentence for healing (true) or damage (false)
    
    -- Additional Holy-specific options
    beacon_target = "tank",       -- Default target for Beacon of Light (tank, focus, custom)
    conserve_mana = false,        -- Prioritize mana-efficient healing
    enable_mastery_range = true,  -- Consider mastery (proximity) bonus for healing
} )

-- Register default pack for MoP Holy Paladin
spec:RegisterPack( "Holy", 20250515, [[Hekili:T1PBVTTn04FlXjHj0OfnrQ97Lvv9n0KxkzPORkyzyV1ikA2JC7fSOhtkfLjjRKKGtkLQfifs4YC7O3MF11Fw859fNZXPb72TQWN3yiOtto8jREEP(D)CaaR7oXR]hYdVp)NhS4(SZdhFpzmYBPn2qGdjcw5Jt8jc((52Lbb6W0P)MM]] )

-- Register pack selector for Holy

-- State expressions for Holy Paladin
spec:RegisterStateExpr( "infusion_stack", function()
    return buff.infusion_of_light.stack
end )

spec:RegisterStateExpr( "beacon_target", function()
    -- In MoP, there's only one Beacon of Light target
    return FindUnitBuffByID( "target", 53563, "PLAYER" ) and "target" or "none"
end )

spec:RegisterStateExpr( "sacred_shield_active", function()
    return FindUnitBuffByID( "target", 65148, "PLAYER" ) and true or false
end )

spec:RegisterStateExpr( "divine_plea_active", function()
    return buff.divine_plea.up
end )

spec:RegisterStateExpr( "has_beacon", function()
    -- Check if any beacon is active
    for unit in pairs( Hekili.unitIDs ) do
        if FindUnitBuffByID( unit, 53563, "PLAYER" ) then
            return true
        end
    end
    return false
end )
