    -- HunterBeastMastery.lua
    -- july 2025 by smufrik


    local _, playerClass = UnitClass('player')
    if playerClass ~= 'HUNTER' then return end

    local addon, ns = ...
    local Hekili = _G[ addon ]
    local class, state = Hekili.Class, Hekili.State

    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local strformat = string.format

local spec = Hekili:NewSpecialization( 253, true )



    -- Use MoP power type numbers instead of Enum
    -- Focus = 2 in MoP Classic
    spec:RegisterResource( 2, {
        steady_shot = {
            resource = "focus",
            cast = function(x) return x > 0 and x or nil end,
            aura = function(x) return x > 0 and "casting" or nil end,
            
            last = function()
                return state.buff.casting.applied
            end,
            
            interval = function() return state.buff.casting.duration end,
            value = 14,
        },
        
        cobra_shot = {
            resource = "focus",
            cast = function(x) return x > 0 and x or nil end,
            aura = function(x) return x > 0 and "casting" or nil end,
            
            last = function()
                return state.buff.casting.applied
            end,
            
            interval = function() return state.buff.casting.duration end,
            value = 14,
        },
        
        dire_beast = {
            resource = "focus",
            aura = "dire_beast",
            
            last = function()
                local app = state.buff.dire_beast.applied
                local t = state.query_time
                
                return app + floor( ( t - app ) / 2 ) * 2
            end,
            
            interval = 2,
            value = 5,
        },
        
        fervor = {
            resource = "focus",
            aura = "fervor",
            
            last = function()
                return state.buff.fervor.applied
            end,
            
            interval = 0.1,
            value = 50,
        }
    } )

    -- Talents
    spec:RegisterTalents( {
        -- Tier 1 (Level 15)
        posthaste = { 1, 1, 109215 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 60% for 4 sec.
        narrow_escape = { 1, 2, 109298 }, -- When Disengage is activated, you also activate a web trap which encases all targets within 8 yards in sticky webs, preventing movement for 8 sec. Damage caused may interrupt the effect.
        crouching_tiger_hidden_chimera = { 1, 3, 109215 }, -- Reduces the cooldown of Disengage by 6 sec and Deterrence by 10 sec.

        -- Tier 2 (Level 30)
        silencing_shot = { 2, 1, 34490 }, -- Interrupts spellcasting and prevents any spell in that school from being cast for 3 sec.
        wyvern_sting = { 2, 2, 19386 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, they will be poisoned, taking Nature damage over 6 sec. Only one Sting per Hunter can be active on the target at a time.
        binding_shot = { 2, 3, 109248 }, -- Fires a magical projectile, tethering the enemy and any other enemies within 5 yards, stunning them for 5 sec if they move more than 5 yards from the arrow.

        -- Tier 3 (Level 45)
        intimidation = { 3, 1, 19577 }, -- Commands your pet to intimidate the target, causing a high amount of threat and stunning the target for 3 sec.
        spirit_bond = { 3, 2, 19579 }, -- While your pet is active, you and your pet regen 2% of total health every 10 sec.
        iron_hawk = { 3, 3, 109260 }, -- Reduces all damage taken by 10%.

        -- Tier 4 (Level 60)
        dire_beast = { 4, 1, 120679 }, -- Summons a powerful wild beast that attacks the target for 15 sec.
        fervor = { 4, 2, 82726 }, -- Instantly restores 50 Focus to you and your pet, and increases Focus regeneration by 50% for you and your pet for 10 sec.
        a_murder_of_crows = { 4, 3, 131894 }, -- Summons a flock of crows to attack your target over 30 sec. If the target dies while the crows are attacking, their cooldown is reset.

        -- Tier 5 (Level 75)
        blink_strikes = { 5, 1, 130392 }, -- Your pet's Basic Attacks deal 50% increased damage and can be used from 30 yards away. Their range is increased to 40 yards while Dash or Stampede is active.
        lynx_rush = { 5, 2, 120697 }, -- Commands your pet to rush the target, performing 9 attacks in 4 sec for 800% normal damage. Each hit deals bleed damage to the target over 8 sec. Bleeds stack and persist on the target.
        thrill_of_the_hunt = { 5, 3, 109306 }, -- You have a 30% chance when you hit with Multi-Shot or Arcane Shot to make your next Steady Shot or Cobra Shot cost no Focus and deal 150% additional damage.

        -- Tier 6 (Level 90)
        glaive_toss = { 6, 1, 117050 }, -- Throws a pair of glaives at your target, dealing Physical damage and reducing movement speed by 30% for 3 sec. The glaives return to you, also dealing damage to any enemies in their path.
        powershot = { 6, 2, 109259 }, -- A powerful aimed shot that deals weapon damage to the target and up to 5 targets in the line of fire. Knocks all targets back, reduces your maximum Focus by 20 for 10 sec and refunds some Focus for each target hit.
        barrage = { 6, 3, 120360 }, -- Rapidly fires a spray of shots for 3 sec, dealing Physical damage to all enemies in front of you. Usable while moving.
    } )

-- Glyphs (Enhanced System - authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs - Beast Mastery Combat
    [54825] = "aspect_of_the_beast",  -- Aspect of the Beast now also increases your pet's damage by 10%
    [54760] = "bestial_wrath",        -- Bestial Wrath now also increases your pet's movement speed by 50%
    [54821] = "kill_command",         -- Kill Command now has a 50% chance to not trigger a cooldown
    [54832] = "mend_pet",             -- Mend Pet now also heals you for 50% of the amount
    [54743] = "revive_pet",           -- Revive Pet now has a 100% chance to succeed
    [54829] = "scare_beast",          -- Scare Beast now affects all beasts within 10 yards
    [54754] = "tame_beast",           -- Tame Beast now has a 100% chance to succeed
    [54755] = "call_pet",             -- Call Pet now summons your pet instantly
    [116218] = "aspect_of_the_pack",  -- Aspect of the Pack now also increases your pet's movement speed by 30%
    [125390] = "aspect_of_the_cheetah", -- Aspect of the Cheetah now also increases your pet's movement speed by 30%
    [125391] = "aspect_of_the_hawk",  -- Aspect of the Hawk now also increases your pet's attack speed by 10%
    [125392] = "aspect_of_the_monkey", -- Aspect of the Monkey now also increases your pet's dodge chance by 10%
    [125393] = "aspect_of_the_viper", -- Aspect of the Viper now also increases your pet's mana regeneration by 50%
    [125394] = "aspect_of_the_wild",  -- Aspect of the Wild now also increases your pet's critical strike chance by 5%
    [125395] = "aspect_mastery",      -- Your aspects now last 50% longer
    
    -- Major glyphs - Pet Abilities
    [94388] = "growl",                -- Growl now has a 100% chance to succeed
    [59219] = "claw",                 -- Claw now has a 50% chance to not trigger a cooldown
    [114235] = "bite",                -- Bite now has a 50% chance to not trigger a cooldown
    [125396] = "dash",                -- Dash now also increases your pet's attack speed by 20%
    [125397] = "cower",               -- Cower now also reduces the target's attack speed by 20%
    [125398] = "demoralizing_screech", -- Demoralizing Screech now affects all enemies within 10 yards
    [125399] = "monkey_business",     -- Monkey Business now has a 100% chance to succeed
    [125400] = "serpent_swiftness",   -- Serpent Swiftness now also increases your pet's movement speed by 30%
    [125401] = "great_stamina",       -- Great Stamina now also increases your pet's health by 20%
    [54828] = "great_resistance",     -- Great Resistance now also increases your pet's resistance by 20%
    
    -- Major glyphs - Defensive/Survivability
    [125402] = "mend_pet",            -- Mend Pet now also heals you for 50% of the amount
    [125403] = "revive_pet",          -- Revive Pet now has a 100% chance to succeed
    [125404] = "call_pet",            -- Call Pet now summons your pet instantly
    [125405] = "dismiss_pet",         -- Dismiss Pet now has no cooldown
    [125406] = "feed_pet",            -- Feed Pet now has a 100% chance to succeed
    [125407] = "play_dead",           -- Play Dead now has a 100% chance to succeed
    [125408] = "tame_beast",          -- Tame Beast now has a 100% chance to succeed
    [125409] = "beast_lore",          -- Beast Lore now provides additional information
    [125410] = "track_beasts",        -- Track Beasts now also increases your damage against beasts by 5%
    [125411] = "track_humanoids",     -- Track Humanoids now also increases your damage against humanoids by 5%
    
    -- Major glyphs - Control/CC
    [125412] = "freezing_trap",       -- Freezing Trap now affects all enemies within 5 yards
    [125413] = "ice_trap",            -- Ice Trap now affects all enemies within 5 yards
    [125414] = "snake_trap",          -- Snake Trap now summons 3 additional snakes
    [125415] = "explosive_trap",      -- Explosive Trap now affects all enemies within 5 yards
    [125416] = "immolation_trap",     -- Immolation Trap now affects all enemies within 5 yards
    [125417] = "black_arrow",         -- Black Arrow now has a 50% chance to not trigger a cooldown
    
    -- Minor glyphs - Visual/Convenience
    [57856] = "aspect_of_the_beast",  -- Your pet appears as a different beast type
    [57862] = "aspect_of_the_cheetah", -- Your pet leaves a glowing trail when moving
    [57863] = "aspect_of_the_hawk",   -- Your pet has enhanced visual effects
    [57855] = "aspect_of_the_monkey", -- Your pet appears more agile and nimble
    [57861] = "aspect_of_the_viper",  -- Your pet appears more serpentine
    [57857] = "aspect_of_the_wild",   -- Your pet appears more wild and untamed
    [57858] = "beast_lore",           -- Beast Lore provides enhanced visual information
    [57860] = "track_beasts",         -- Track Beasts has enhanced visual effects
    [121840] = "track_humanoids",     -- Track Humanoids has enhanced visual effects
    [125418] = "blooming",            -- Your abilities cause flowers to bloom around the target
    [125419] = "floating",            -- Your spells cause you to hover slightly above the ground
    [125420] = "glow",                -- Your abilities cause you to glow with natural energy
} )

-- Auras
    spec:RegisterAuras( {
        -- Talent: Under attack by a flock of crows.
        -- https://wowhead.com/beta/spell=131894
        a_murder_of_crows = {
            id = 131894,
            duration = 30,
            tick_time = 1,
            max_stack = 1
        },
        -- Movement speed increased by $w1%.
        -- https://wowhead.com/beta/spell=186258
        aspect_of_the_cheetah = {
            id = 5118,
            duration = 3600,
            max_stack = 1
        },
        -- Talent: Damage dealt increased by $w1%.
        -- https://wowhead.com/beta/spell=19574
        bestial_wrath = {
            id = 19574,
            duration = 10,
            type = "Ranged",
            max_stack = 1
        },
        -- Stunned.
        binding_shot_stun = {
            id = 117526,
            duration = 5,
            max_stack = 1,
        },
        -- Movement slowed by $s1%.
        concussive_shot = {
            id = 5116,
            duration = 6,
            mechanic = "snare",
            type = "Ranged",
            max_stack = 1
        },
        -- Talent: Haste increased by $s1%.
        dire_beast = {
            id = 120694,
            duration = 15,
            max_stack = 1
        },
        -- Feigning death.
        feign_death = {
            id = 5384,
            duration = 360,
            max_stack = 1
        },
        -- Restores Focus.
        fervor = {
            id = 82726,
            duration = 10,
            max_stack = 1
        },
        -- Incapacitated.
        freezing_trap = {
            id = 3355,
            duration = 8,
            type = "Magic",
            max_stack = 1
        },
        -- Talent: Increased movement speed by $s1%.
        posthaste = {
            id = 118922,
            duration = 4,
            max_stack = 1
        },
        -- Silenced.
        silencing_shot = {
            id = 34490,
            duration = 3,
            mechanic = "silence",
            max_stack = 1
        },
        -- Asleep.
        wyvern_sting = {
            id = 19386,
            duration = 30,
            mechanic = "sleep",
            max_stack = 1
        },
        -- Poisoned.
        wyvern_sting_dot = {
            id = 19386,
            duration = 6,
            tick_time = 2,
            max_stack = 1
        },
        -- Stunned.
        intimidation = {
            id = 19577,
            duration = 3,
            max_stack = 1
        },
        -- Health regeneration increased.
        spirit_bond = {
            id = 19579,
            duration = 3600,
            max_stack = 1
        },
        -- Damage taken reduced by $s1%.
        iron_hawk = {
            id = 109260,
            duration = 3600,
            max_stack = 1
        },
        -- Talent: Bleeding for $w1 damage every $t1 sec.
        lynx_rush = {
            id = 120697,
            duration = 8,
            tick_time = 1,
            max_stack = 9
        },
        -- Talent: Next Steady Shot or Cobra Shot costs no Focus and deals additional damage.
        thrill_of_the_hunt = {
            id = 109306,
            duration = 20,
            max_stack = 1
        },
        -- Talent: Movement speed reduced by $s1%.
        glaive_toss = {
            id = 117050,
            duration = 3,
            mechanic = "snare",
            max_stack = 1
        },
        -- Talent: Focus reduced by $s1.
        powershot = {
            id = 109259,
            duration = 10,
            max_stack = 1
        },
        -- Talent: Rapidly firing.
        barrage = {
            id = 120360,
            duration = 3,
            tick_time = 0.2,
            max_stack = 1
        },
        -- Movement speed reduced by $s1%.
        wing_clip_debuff = {
            id = 2974,
            duration = 10,
            max_stack = 1
        },
        -- Healing over time.
        mend_pet = {
            id = 136,
            duration = 10,
            type = "Magic",
            max_stack = 1,
            generate = function( t )
                local name, _, count, _, duration, expires, caster = FindUnitBuffByID( "pet", 136 )

                if name then
                    t.name = name
                    t.count = count
                    t.expires = expires
                    t.applied = expires - duration
                    t.caster = caster
                    return
                end

                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end
        },
        -- Threat redirected from Hunter.
        misdirection = {
            id = 35079,
            duration = 8,
            max_stack = 1
        },
        -- Feared.
        scare_beast = {
            id = 1513,
            duration = 20,
            mechanic = "flee",
            type = "Magic",
            max_stack = 1
        },
        -- Disoriented.
        scatter_shot = {
            id = 213691,
            duration = 4,
            type = "Ranged",
            max_stack = 1
        },
        -- Casting.
        casting = {
            duration = function () return haste end,
            max_stack = 1,
            generate = function ()
                if action.steady_shot.channeling or action.cobra_shot.channeling then
                    return {
                        name = "Casting",
                        count = 1,
                        applied = action.steady_shot.channelStart or action.cobra_shot.channelStart,
                        expires = action.steady_shot.channelStart + action.steady_shot.castTime or action.cobra_shot.channelStart + action.cobra_shot.castTime,
                        caster = "player"
                    }
                end
            end,
        },
        -- MoP specific auras
        improved_steady_shot = {
            id = 53220,
            duration = 15,
            max_stack = 1
        },
        serpent_sting = {
            id = 118253,    
            duration = 15,
            tick_time = 3,
            type = "Ranged",
            max_stack = 1
        },
        frenzy = {
            id = 19615,
            duration = 8,
            max_stack = 5
        },
        beast_cleave = {
            id = 115939,
            duration = 4,
            max_stack = 1
        },
        hunters_mark = {
            id = 1130,
            duration = 300,
            type = "Ranged",
            max_stack = 1
        },
        aspect_of_the_iron_hawk = {
            id = 109260,
            duration = 3600,
            max_stack = 1
        },
        rapid_fire = {
            id = 3045,
            duration = 3,
            tick_time = 0.2,
            max_stack = 1
        },
        explosive_trap = {
            id = 13813,
            duration = 20,
            max_stack = 1
        },
        -- Tier set bonuses
        tier14_4pc = {
            id = 105919,
            duration = 3600,
            max_stack = 1
        },
        tier15_2pc = {
            id = 138267,
            duration = 3600,
            max_stack = 1
        },
        tier15_4pc = {
            id = 138268,
            duration = 3600,
            max_stack = 1
        },
        tier16_2pc = {
            id = 144659,
            duration = 5,
            max_stack = 1
        },
        tier16_4pc = {
            id = 144660,
            duration = 5,
            max_stack = 1
        },
        -- Additional missing auras
        deterrence = {
            id = 19263,
            duration = 5,
            max_stack = 1
        },
        aspect_of_the_hawk = {
            id = 13165,
            duration = 3600,
            max_stack = 1
        },

    } )

    spec:RegisterStateFunction( "apply_aspect", function( name )
        removeBuff( "aspect_of_the_hawk" )
        removeBuff( "aspect_of_the_iron_hawk" )
        removeBuff( "aspect_of_the_cheetah" )
        removeBuff( "aspect_of_the_pack" )

        if name then applyBuff( name ) end
    end )

    -- Pets
    spec:RegisterPets({
        dire_beast = {
            id = 100,
            spell = "dire_beast",
            duration = 15
        },
    } )



    --- Mists of Pandaria
    spec:RegisterGear( "tier16", 99169, 99170, 99171, 99172, 99173 )
    spec:RegisterGear( "tier15", 95307, 95308, 95309, 95310, 95311 )
    spec:RegisterGear( "tier14", 84242, 84243, 84244, 84245, 84246 )


    spec:RegisterHook( "spend", function( amt, resource )
        if amt < 0 and resource == "focus" and talent.fervor.enabled and buff.fervor.up then
            amt = amt * 1.5
        end

        return amt, resource
    end )


    -- State Expressions for MoP Beast Mastery Hunter
    spec:RegisterStateExpr( "current_focus", function()
    return focus.current or 0
end )

    spec:RegisterStateExpr( "focus_deficit", function()
    return (focus.max or 100) - (focus.current or 0)
end )

spec:RegisterStateExpr( "should_focus_fire", function()
    -- Use Focus Fire immediately at 5 stacks, or every 20 seconds at lower stacks
    return pet.alive and (
        buff.frenzy.stack >= 5 or 
        (buff.frenzy.stack >= 1 and cooldown.focus_fire.remains == 0)
    )
end )

spec:RegisterStateExpr( "threat", function()
    -- Threat situation for misdirection logic
    return {
        situation = 0 -- Default to no threat situation
    }
end )

    spec:RegisterStateExpr( "focus_time_to_max", function()
        return focus.time_to_max
    end )

    -- Abilities
    spec:RegisterAbilities( {
        a_murder_of_crows = {
            id = 131894,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            talent = "a_murder_of_crows",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "a_murder_of_crows" )
            end,
        },

        arcane_shot = {
            id = 3044,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "arcane",

            spend = function () return buff.thrill_of_the_hunt.up and 0 or 20 end,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end
            end,
        },

        aspect_of_the_cheetah = {
            id = 5118,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                spec:apply_aspect( "aspect_of_the_cheetah" )
            end,
        },

        aspect_of_the_hawk = {
            id = 13165,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                applyBuff( "aspect_of_the_hawk" )
            end,
        },

        aspect_of_the_iron_hawk = {
            id = 109260,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                applyBuff( "aspect_of_the_iron_hawk" )
            end,
        },

        barrage = {
            id = 120360,
            cast = function () return 3 * haste end,
            channeled = true,
            cooldown = 20,
            gcd = "spell",
            school = "physical",

            spend = 40,
            spendType = "focus",

            talent = "barrage",
            startsCombat = true,
            toggle = "cooldowns",

            start = function ()
                applyBuff( "barrage" )
            end,
        },

        bestial_wrath = {
            id = 19574,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "physical",

            startsCombat = false,

            toggle = "cooldowns",

            handler = function ()
                applyBuff( "bestial_wrath" )
            end,
        },

        binding_shot = {
            id = 109248,
            cast = 0,
            cooldown = 45,
            gcd = "spell",
            school = "nature",

            talent = "binding_shot",
            startsCombat = false,
            toggle = "interrupts",

            handler = function ()
                applyDebuff( "target", "binding_shot_stun" )
            end,
        },

        call_pet = {
            id = 883,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,

            usable = function () return not pet.exists, "requires no active pet" end,

            handler = function ()
                summonPet( "hunter_pet", 3600 )
            end,
        },

        call_pet_1 = {
            id = 883,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,

            usable = function () return not pet.exists, "requires no active pet" end,

            handler = function ()
                summonPet( "hunter_pet", 3600 )
            end,
        },

        cobra_shot = {
            id = 77767,
            cast = 2,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end
            end,
        },

        concussive_shot = {
            id = 5116,
            cast = 0,
            cooldown = 5,
            gcd = "spell",
            school = "physical",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "concussive_shot" )
            end,
        },

        deterrence = {
            id = 19263,
            cast = 0,
            cooldown = function () return talent.crouching_tiger_hidden_chimera.enabled and 170 or 180 end,
            gcd = "spell",
            school = "physical",

            startsCombat = false,

            toggle = "defensives",

            handler = function ()
                applyBuff( "deterrence" )
            end,
        },

        dire_beast = {
            id = 120679,
            cast = 0,
            cooldown = 20,
            gcd = "spell",
            school = "nature",

            talent = "dire_beast",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "dire_beast" )
                summonPet( "dire_beast", 15 )
            end,
        },

        disengage = {
            id = 781,
            cast = 0,
            cooldown = function () return talent.crouching_tiger_hidden_chimera.enabled and 14 or 20 end,
            gcd = "off",
            school = "physical",

            startsCombat = false,

            handler = function ()
                if talent.posthaste.enabled then applyBuff( "posthaste" ) end
                if talent.narrow_escape.enabled then
                    -- Apply web trap effect
                end
            end,
        },

        dismiss_pet = {
            id = 2641,
            cast = 0,
            cooldown = 0,
            gcd = "spell",

            startsCombat = false,

            usable = function () return pet.exists, "requires an active pet" end,

            handler = function ()
                dismissPet()
            end,
        },

        explosive_trap = {
            id = 13813,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "fire",

            startsCombat = false,

            handler = function ()
                applyDebuff( "target", "explosive_trap" )
            end,
        },

        feign_death = {
            id = 5384,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            school = "physical",

            startsCombat = false,

            toggle = "defensives",

            handler = function ()
                applyBuff( "feign_death" )
            end,
        },

        focus_fire = {
            id = 82692,
            cast = 0,
            cooldown = 20,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            usable = function () 
                return should_focus_fire, "requires pet with frenzy stacks" 
            end,

            handler = function ()
                local stacks = buff.frenzy.stack
                removeBuff( "frenzy" )
                -- Focus Fire converts frenzy stacks to haste
            end,
        },

        fervor = {
            id = 82726,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "nature",

            spend = -50,
            spendType = "focus",

            talent = "fervor",
            startsCombat = false,

            handler = function ()
                applyBuff( "fervor" )
            end,
        },

        freezing_trap = {
            id = 1499,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "frost",

            startsCombat = false,

            handler = function ()
                -- Freezing trap effects
            end,
        },

        glaive_toss = {
            id = 117050,
            cast = 3,
            cooldown = 6,
            gcd = "spell",
            school = "physical",

            spend = 15,
            spendType = "focus",

            talent = "glaive_toss",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "target", "glaive_toss" )
            end,
        },

        hunters_mark = {
            id = 1130,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            handler = function ()
                applyDebuff( "target", "hunters_mark" )
            end,
            copy = 1130,    
        },

        intimidation = {
            id = 19577,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            talent = "intimidation",
            startsCombat = true,
            toggle = "interrupts",

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                applyDebuff( "target", "intimidation" )
            end,
        },

        kill_command = {
            id = 34026,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            school = "physical",

            spend = 25,
            spendType = "focus",

            startsCombat = true,

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                -- Kill Command effects
            end,
        },

        kill_shot = {
            id = 53351,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            school = "physical",

            spend = 25,
            spendType = "focus",

            startsCombat = true,

            usable = function () return target.health_pct <= 20, "requires target below 20% health" end,

            handler = function ()
                -- Kill Shot effects
            end,
        },

        lynx_rush = {
            id = 120697,
            cast = 0,
            cooldown = 90,
            gcd = "spell",
            school = "physical",

            talent = "lynx_rush",
            startsCombat = true,
            toggle = "cooldowns",

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                applyDebuff( "target", "lynx_rush" )
            end,
        },

        masters_call = {
            id = 53271,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            usable = function () return pet.alive, "requires a living pet" end,

            handler = function ()
                -- Masters Call removes movement impairing effects
            end,
        },

        mend_pet = {
            id = 136,
            cast = 10,
            channeled = true,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            usable = function ()
                if not pet.alive then return false, "requires a living pet" end
                if settings.pet_healing > 0 and pet.health_pct > settings.pet_healing then return false, "pet health is above threshold" end
                return true
            end,

            start = function ()
                applyBuff( "mend_pet" )
            end,
        },

        misdirection = {
            id = 34477,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            school = "physical",

            startsCombat = false,

            handler = function ()
                applyBuff( "misdirection" )
            end,
        },

        multi_shot = {
            id = 2643,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = 30,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- Multi-Shot effects
            end,
        },

        powershot = {
            id = 109259,
            cast = 2.5,
            cooldown = 45,
            gcd = "spell",
            school = "physical",

            spend = 45,
            spendType = "focus",

            talent = "powershot",
            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyDebuff( "player", "powershot" )
            end,
        },

        rapid_fire = {
            id = 3045,
            cast = 3,
            channeled = true,
            cooldown = 300,
            gcd = "spell",
            school = "physical",

            startsCombat = true,
            toggle = "cooldowns",

            start = function ()
                applyBuff( "rapid_fire" )
            end,
        },

        scare_beast = {
            id = 1513,
            cast = 1.5,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            spend = 25,
            spendType = "focus",

            startsCombat = false,

            usable = function() return target.is_beast, "requires a beast target" end,

            handler = function ()
                applyDebuff( "target", "scare_beast" )
            end,
        },

        scatter_shot = {
            id = 19503,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "physical",

            startsCombat = false,

            handler = function ()
                applyDebuff( "target", "scatter_shot" )
            end,
        },

        serpent_sting = {
            id = 1978,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            spend = 25,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "serpent_sting" )
            end,
        },

        silencing_shot = {
            id = 34490,
            cast = 0,
            cooldown = 20,
            gcd = "spell",
            school = "physical",

            talent = "silencing_shot",
            startsCombat = true,
            toggle = "interrupts",

            debuff = "casting",
            readyTime = state.timeToInterrupt,

            handler = function ()
                applyDebuff( "target", "silencing_shot" )
                interrupt()
            end,
        },

        steady_shot = {
            id = 56641,
            cast = 2,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = function () return buff.thrill_of_the_hunt.up and 0 or -14 end,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                if buff.thrill_of_the_hunt.up then
                    removeBuff( "thrill_of_the_hunt" )
                end
            end,
        },

        thrill_of_the_hunt_active = {
            id = 109306,
            cast = 0,
            cooldown = 0,
            gcd = "off",

            startsCombat = false,

            usable = function () return buff.thrill_of_the_hunt.up, "requires thrill of the hunt buff" end,

            handler = function ()
                -- Active version of thrill of the hunt
            end,
        },

        wing_clip = {
            id = 2974,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = 20,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "wing_clip" )
            end,
        },

        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 60,
            gcd = "spell",
            school = "nature",

            talent = "wyvern_sting",
            startsCombat = true,
            toggle = "interrupts",

            handler = function ()
                applyDebuff( "target", "wyvern_sting" )
            end,
        },
    } )

    spec:RegisterRanges( "arcane_shot", "kill_command", "wing_clip" )

    spec:RegisterOptions( {
        enabled = true,

        aoe = 3,
        cycle = false,

        nameplates = false,
        nameplateRange = 40,
        rangeFilter = false,

        damage = true,
        damageExpiration = 3,

        potion = "tempered_potion",
        package = "Beast Mastery",
    } )

    spec:RegisterSetting( "pet_healing", 0, {
        name = strformat( "%s Below Health %%", Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
        desc = strformat( "If set above zero, %s may be recommended when your pet falls below this health percentage. Setting to |cFFFFd1000|r disables this feature.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.mend_pet.id ) ),
        icon = 132179,
        iconCoords = { 0.1, 0.9, 0.1, 0.9 },
        type = "range",
        min = 0,
        max = 100,
        step = 1,
        width = 1.5
    } )

    spec:RegisterSetting( "avoid_bw_overlap", false, {
        name = strformat( "Avoid %s Overlap", Hekili:GetSpellLinkWithTexture( spec.abilities.bestial_wrath.id ) ),
        desc = strformat( "If checked, %s will not be recommended if the buff is already active.", Hekili:GetSpellLinkWithTexture( spec.abilities.bestial_wrath.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "mark_any", false, {
        name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "check_pet_range", false, {
        name = strformat( "Check Pet Range for %s", Hekili:GetSpellLinkWithTexture( spec.abilities.kill_command.id ) ),
        desc = function ()
            return strformat( "If checked, %s will only be recommended if your pet is in range of your target.\n\n" ..
                            "Requires |c" .. ( state.settings.petbased and "FF00FF00" or "FFFF0000" ) .. "Pet-Based Target Detection|r",
                            Hekili:GetSpellLinkWithTexture( spec.abilities.kill_command.id ) )
        end,
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "thrill_of_the_hunt_priority", true, {
        name = strformat( "Prioritize %s Usage", Hekili:GetSpellLinkWithTexture( spec.talents.thrill_of_the_hunt.id ) ),
        desc = strformat( "If checked, %s or %s will be prioritized when %s is active to use the Focus-free proc.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.steady_shot.id ),
            Hekili:GetSpellLinkWithTexture( spec.abilities.cobra_shot.id ),
            Hekili:GetSpellLinkWithTexture( spec.talents.thrill_of_the_hunt.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "focus_dump_threshold", 80, {
        name = "Focus Dump Threshold",
        desc = strformat( "Focus level at which to prioritize spending abilities like %s and %s to avoid Focus capping.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.arcane_shot.id ),
            Hekili:GetSpellLinkWithTexture( spec.abilities.multi_shot.id ) ),
        type = "range",
        min = 50,
        max = 120,
        step = 5,
        width = 1.5
    } )

    spec:RegisterSetting( "pet_to_call", 1, {
        name = "Pet to Call",
        desc = "Which pet slot to call when no pet is active. Set to 0 to disable automatic pet calling.",
        type = "range",
        min = 0,
        max = 5,
        step = 1,
        width = 1.5
    } )

    spec:RegisterPack( "Beast Mastery", 20250722, [[Hekili:vZvBVTnos4FlfloFPBt9jBhNKUxCa2UVGT5UTOaUlUpCyTmJeDSUilzijhxxeOF73mKuIVisjz3CF4WIDrSe5ZmC4WHpZqQDXOfFEX8qsbDXhh7nEQ3vJhpC01Ex6D5I5fh2sxmFlj4rYdWFKq2a)3cAEbjhF8H4usi2980DzbWRwm)(DrXfFizX9nX8QjtrmZ3sdGhpDYI5RJcdP82sZdwm)ZRJYlxI)lPCPqQLltxb)oOiknPCzCuEb86vPzLl)n6JrXrdxmN9qunwffhtZG)6JSbfnHCFmnCX7xmpilQGMfrqjD)UvRgMtZ2stk8ZlIsEy4UTlMZfb0007Zi(5Rtl4Qvw0w(l(NP7F7Q0GDO8zcc0XSOua5ik8SZiHKTf0q4TzPBGHrciXvKaADZoW1)xVOag)ovqHiUzw5Yl8kxoOC5Rkx2PwNxqjHh4Qn(pWerwEr7MIT0IHK4ONOmPiK7TGCN6jb(Ey2oIe7VpJuS2WI8EugWWBnjhNNGNUj6Re27ADiwqIHrXqI)MDzH0m)0v(bzP7ZhkAntFydynPRnGB0zuKt6sKXhs(IF2U81AIs3q0HGRHaf4f9042bMGJCSFq6MnKKqe2PoHLb0QmAYxpmewgg8iFgBsFKcBg2FvugfLXLTldtym9rUqXhHKfqsOvoFF8Qta5oDWvwwY8VdstJdt3NK3UpUdj(8ZLllizpatsGtl1Vi1pmIYx1DPQ3FCAAO)QDzhmC9)XDfPVnGGU)PfRXyb1k0lxOGVrLp)qczBomVacn5HowG8kH7tgzBuiZjPAQ5mhowTRiJMwU81sDrcB7lB6vOHttJU0ttJSgaX9cVJiaYPPEggmTWmUxRkuRqWW6Fpf8hnnu8f9H0vrbrfvlD5AIdLurjKW2(6AHwSIM9uAMMgOSB2KRucfXAjFLm9l0GDavHJyVkHnCnLexS2FBqbxcJ9CesvFT7VWfy9gxNXHdmi0409im)LYLCS7ybQt94iIw22EwTHUJiMMsEIN7yOGr1hSpalRnae9J3eyHOH1oZINMLMwWEQuwBaNgAwUFajo2W()j0wVRaiVHXbH5NYLkArFyoabubQgHmQgAUBctggygmhQpsB92TahhPQQIwNbj1DebhS7jfkwyy06JM1rClmSUJMKdTUDJBucaeOW(HKnGDWFAoth5Z8d3q(s5YVVCP3WluwAsH(c8aqA3Aw3FUsKQ0tB3QAk(joe)LQlGJEibcRGKcB1KPBVWFvSod6g4lJqETyok5rq(kEpr5ySNaXusrf5LJ1BTp0j0nF)kFPJuq6eBF52C)fINpjTdFlSNpr9Pj0nS8uybfuS07IlISzi(X0FrDerc)p7YlqdshotTfxYMUm26ByMfhrU6MM)9KSmy6tl0Gnzp1mAPg3poi9IVYdXee8I088of6ytHosjwKcqTZhXgYxy4gr)Y240CgEa)ln)i9xXDLGafz(3NMSlN2bR6CichRHdX(m6c)l2giZar(ml7hn1XoH6oFFocPuNJBuW2FyBwAWXKHPHco1FCdfK9SkfSokLdceT601qynTgtvTgDUi3CFA(wy(57JkcwBBMPQJR3LW20Ddj7raMdbXW8lRZ5yNmSXcwpCyzBxYS1qNipzMpFZf4QYAiM4tB72cSqAD(YDOV2qDKxFIDOHOfRsRZTwJEkNCzCJ95wmMrWAGvozly7moBbltG8cTXtuZhs6mppDtUX81VXm4)q5Y3tz5D(7mgwqO5)ylwQnyM7UDXWphp(CKK4yi4w5Y50cCyNZCX9XD0HFndSBVTCjJhM4rGng2wg02yaNZ8E7ippafODHr5OwM)AWo)ukKd3979tFIMft2oBfjg5pdq9J4RqnJLmr5Y)fMnb4cXBiUDA2J(KKdkDHpC(R54aj7r037q1en4dUMg8iJivgj5bQs3(j8nSrt5s27evd8FalxH3YxVYgn46xi3oi7CF0x1VAVSzfz74y9jb)OVc)8ZSoWR2i0fU(b0uZjCrWYIA3MT(12PzxZnJcgd4l1TItbZ4yVxJYH(w(CplMg6uZJQHdcfknYaJ7aV8QD7mx1i8vOqcSald)SOaQFsAAymTNP4tWsWwuzBIYst8xt2)OE510Ad(6ETpOlOR6Jd8RBy7759kRbQ14CZtv2E8qjMTMmBVOHPftbG7Ad44LkpmJqtIc8jpWs2r2)TPMmBXsJ0B6TwkUyZAcoTInG7QUvvZkJ3Mr3qIsYnZtsP(Hw5m)RWBuPm(sXu2YCUEvPB1RVJIIAPizU9Y7alLQf2QFCFgqhz5zBDaDKfK1XacCv3ab07278vv5fR5aQVIhcWtliRBjMJOfgUA)UqderqfvrOD)hb7byNmipt077wr520ilhKMaEXmkXyKxdczAVRRCqmehYh5AjyWlOjp0zMfv2A76DNrOAwVCi(swAbNoxRZF9T6Aw4T)tPyiGkX8)MdiZALQLQMELM7rHjCt5V7T7CvMAfN6tQmZNqLu7UiXDu7AjMA1EUZQ(UnDpShlUKPXGV(v22ISbqnlIT6Ig1kr)Ux2nVh55epRGvV)i7yfCSM7JJABfMRQgibZOsaJo6JjYOoWkBKBub6rUxKOaWvVZnaUxOCAfJ4JJMQsJtTyDsPuvGvcKOLTaAoOGPVDcmpk3Tsggk)aKB1MEyK77zXvt4R9aB6e7YfjVnez3ciJmDlxIBcSWg7xJt5ydfuRKGdnZZOFXfRJoOTrawbNwjwkvnqwHOQzluQM6Z)Hpg738OcYIaU7Wq4N)0C5(k8R8HpFcwEqWwcS6wmkiyNaULiQ9cn9nATeaTxO0OC3wcG2pG43jglbn1m0ZJk2X0ym7DowIBBtpLdwhABHsD35oP6mvta1CpTfATpsPVhYYenXkpbhBbH7LPX4y2SfXTp6p(4g1swtq61j0wG5EPVA1bUoyCVqPZmlued)gkjONUNKLWsxrCjW2MLcEUu(TbBteW9gRrv(UTBtZkeL8bIUbYkacadz68iTiFiwXRpuW7eRCByiikRCqy8D6tS6LjdZdUeX7crJjncVfh)q5DSs68V)dSAtFa2ci)ppVC5(1rbRvBnVwvcPwUmjfbh2edpJ9yjUH4FjkNuLq)7LlbDxiMpZHacO)NIeAKpASIK3Zknv9isazrvtzwd2Js2T5EAgk48yGqw5DFydAWWhGjoOTWgE7cSstRb6JZZ3SBvw0Jyzkzg(fZ)UQs01SIJ39DTw0X7ynOUYJ4p(Ml(icYPx)rS3hzjiXU8TwfseJx2crIi(nvls(Ctpliz5DChgGasvXRFZS)2Qys(JNJvHCMrbRD0(00qrZTvZs7DQz9hppA1Sx1r9l7dw1ThbSFLT0oSsMxmvtYBYARvlfP9wOLJbdsxhjI1UZzyEogBDMbPxXSE7KDRrTDSqfZAS9NFUjp4BMDPNq4UPJQkyx20b2OcpBKAxRyBIDu2pD(R3m1BWRSZKVAHHn(Mn0qL984gj5L)RZMALTz3DtJwz3n3K)yp6b)onlcE7Koy3abmbX5aD6k3oBs39SIIh29gCcVD20UrOMTgcrtcF3kj799arVUXtN6w3TxJbMnRW4EGHc9RUBnJfLZfLIPZxOBRQmWtD3b9swK4ti2GnanQG9leQY6ck3jrReIdo7iKYOPoSgnQ3N62mUkx4rj6l9Ci66Y2PiYg18BGm24XiuNJxzH5uKAZk5n4mTlI6TZUW75NTkFhYHxNtfzOxI0bm4Vz2KReU8FZNjLunSgXMrSP656750484Gqxo22zq7Na3Tt7wl06OMI0DF77kTUrQhbb6bi))ZqH5J9YCAhQ(7k7XdAs9PSWD7novMBMn2ZDF7mCxhIvCmioMfm7Yjf1ZnChXIDxqCKbdDdu9zyOauJJ8WD37z8r3aCcPfycHS(5y)B7inGDxCdJYjsOmwSD1hD7Nip4aNlU4ZUaHXP9ghrpU6DU7H(zmOAhBCWe9XqIvWHtTY51KvcdWig6S8cHzJy4eZM3JjnWwzcZyJNCZSlmbwCVwvMcnUUSnaDA1uIk3koy92NWIMkaD0utqBoxz25lg0YShpzxRxuaPKQYV4nM1hqCVdyEi8CLhyRSdYlWGvmnUXakbWL5ZmAA9OO5LpWkQ1xDal4DZSRDOjQ(rwsRcudNruyMsRFrbszvNZfQG1FvcOW6kbSlSdIY3wGnuMyGYL2rr9tiqNFg(x8pcHB8gE9aXhFqvfaA7Jtrkj9edNP(1UOUCT6RL55Nn)szCbfO5QFpkklQS9rVmq)dEzqtQ7QuiBijNLBruKinQ0VeFseMSV01M(eXRveu(6iQ3waIa6nW9EMSr4XCvOLkGwY(VrVeFNRDnJNnsze14ItBBwBINB5OZiWIGCnATjOrETTJHPO7ypSbIn0nUu0vw5oVu)kcwPiin3V323Fax2AF7bv7Wm1ZjWMCDT9HdOGC1hnGnIJgiR7nB7BeqdxHg3UFQ7p4EPAWki0BAlzkBMLQEDse5h0rMwvGFKCY7lSoZxPVaONiVL03N0xKog(TxyX8R70yV7T7I8I9)Lkuc0YW5ecqx1VtnS8X8H6kfR47jUvhJosMwcHXeQ1(zBcvIGUrZoaUIxxLjKh7qYx8F)]] )
