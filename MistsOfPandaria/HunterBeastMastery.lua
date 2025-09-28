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
            value = 9,
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
        },
    } )

    -- Talents
    spec:RegisterTalents( {
        -- Tier 1 (Level 15)
        posthaste = { 1, 1, 109215 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 60% for 4 sec.
        narrow_escape = { 1, 2, 109298 }, -- When Disengage is activated, you also activate a web trap which encases all targets within 8 yards in sticky webs, preventing movement for 8 sec. Damage caused may interrupt the effect.
        crouching_tiger_hidden_chimera = { 1, 3, 118675 }, -- Reduces the cooldown of Disengage by 6 sec and Deterrence by 10 sec.

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
        thrill_of_the_hunt = { 5, 3, 34720 }, -- You have a 30% chance when you hit with Multi-Shot or Arcane Shot to make your next Steady Shot or Cobra Shot cost no Focus and deal 150% additional damage.

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
            duration = function() return 10 + ((state.set_bonus.tier14_4pc or 0) > 0 and 6 or 0) end,
            type = "Ranged",
            max_stack = 1
        },
        -- Alias used by some APLs/imports for Bestial Wrath
        the_beast_within = {
            id = 19574,
            duration = function() return 10 + ((state.set_bonus.tier14_4pc or 0) > 0 and 6 or 0) end,
            type = "Ranged",
            max_stack = 1,
            copy = "bestial_wrath"
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
        -- Interrupted.
        counter_shot = {
            id = 147362,
            duration = 3,
            mechanic = "interrupt",
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
        -- Talent: Thrill of the Hunt - next 3 Arcane/Multi-Shots cost 20 less Focus (tracked from game aura)
        thrill_of_the_hunt = {
            id = 34720,
            duration = 12,
            max_stack = 3,
            generate = function( t )
                local name, _, _, count = FindUnitBuffByID( "player", 34720 )
                if name then
                    t.name = name
                    t.count = count and count > 0 and count or 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 12
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
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
        -- Summons a herd of stampeding animals from the wild to fight for you for 12 sec.
        stampede = {
            id = 121818,
            duration = 12,
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
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "pet", 136 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 10
                    t.caster = "pet"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
            end,
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
            generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "player", 116951 )
                
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 2.5
                    t.caster = "player"
                    return
                end
                
                t.count = 0
                t.applied = 0
                t.expires = 0
                t.caster = "nobody"
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
        focus_fire = {
            id = 82692,
            duration = 20,
            max_stack = 5,  -- Stacks correspond to consumed frenzy stacks
            copy = "focus_fire_buff"
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
        aspect_of_the_pack = {
            id = 13159,
            duration = 3600,
            max_stack = 1
        },

        -- === PET ABILITY AURAS ===
        -- Pet basic abilities
        pet_dash = {
            id = 61684,
            duration = 16,
            max_stack = 1,
            generate = function( t )
                if state.pet.alive then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "pet"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        pet_prowl = {
            id = 24450,
            duration = 3600,
            max_stack = 1,
            generate = function( t )
                if state.pet.alive and state.pet.family == "cat" then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "pet"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        -- Pet debuffs on targets
        growl = {
            id = 2649,
            duration = 3,
            max_stack = 1,
            type = "Taunt",
        },

        widow_venom = {
            id = 82654,
            duration = 12,
            max_stack = 1,
            debuff = true
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
    return state.focus.current or 0
end )

    spec:RegisterStateExpr( "focus_deficit", function()
    return (state.focus.max or 100) - (state.focus.current or 0)
end )

spec:RegisterStateExpr( "should_focus_fire", function()
    -- Enhanced Focus Fire logic for optimal Beast Mastery play
    if not pet.alive or buff.frenzy.stack == 0 then return false end
    
    -- Always use at 5 stacks
    if buff.frenzy.stack >= 5 then return true end
    
    -- Use at 3+ stacks if Bestial Wrath is on cooldown > 10s
    if buff.frenzy.stack >= 3 and cooldown.bestial_wrath.remains > 10 then return true end
    
    -- Use at 2+ stacks if frenzy is about to expire (< 3s remaining)
    if buff.frenzy.stack >= 2 and buff.frenzy.remains < 3 then return true end
    
    -- Never use during Bestial Wrath (waste of synergy)
    if buff.bestial_wrath.up then return false end
    
    return false
end )

-- Threat is handled by engine; no spec override

spec:RegisterStateExpr( "should_maintain_beast_cleave", function()
    -- Beast Cleave is a passive buff that needs to be refreshed every 4 seconds
    -- Track when Multi-Shot was last cast to maintain Beast Cleave uptime
    local last_multi_shot = state.history.casts.multi_shot or 0
    local current_time = state.query_time or 0
    
    -- Return true if it's been more than 3.5 seconds since last Multi-Shot
    -- This ensures we refresh Beast Cleave before it expires (4 second duration)
    return (current_time - last_multi_shot) >= 3.5
end )

spec:RegisterStateExpr( "beast_cleave_remains", function()
    -- Calculate remaining time on Beast Cleave based on last Multi-Shot cast
    local last_multi_shot = state.history.casts.multi_shot or 0
    local current_time = state.query_time or 0
    local time_since_cast = current_time - last_multi_shot
    
    -- Beast Cleave lasts 4 seconds, return remaining time
    return math.max(0, 4 - time_since_cast)
end )

    spec:RegisterStateExpr( "focus_time_to_max", function()
        return focus.time_to_max
    end )

    spec:RegisterStateExpr( "pet_alive", function()
        return pet.alive
    end )

    spec:RegisterStateExpr( "bloodlust", function()
        return buff.bloodlust
    end )

    -- Enhanced frenzy tracking for better Focus Fire timing
    spec:RegisterStateExpr( "frenzy_duration_remaining", function()
        return buff.frenzy.remains or 0
    end )

    spec:RegisterStateExpr( "can_generate_frenzy", function()
        return pet.alive and buff.frenzy.stack < 5
    end )

    -- === SHOT ROTATION STATE EXPRESSIONS ===
    
    -- Determines if we should use Cobra Shot over Steady Shot
    spec:RegisterStateExpr( "should_cobra_shot", function()
        -- Cobra Shot is preferred for Beast Mastery when:
        -- 1. We need focus and aren't at cap
        -- 2. We need to maintain Serpent Sting
        -- 3. General focus generation
        
        if (state.focus.current or 0) > 86 then return false end -- Don't cast if we'll cap focus
        
        -- Always prioritize Cobra Shot for Beast Mastery (pulled from Survival logic)
        return true
    end )
    
    -- Determines if we should use Steady Shot
    spec:RegisterStateExpr( "should_steady_shot", function()
        -- Beast Mastery should never use Steady Shot - always use Cobra Shot for focus generation
        return false
    end )
    
    -- Optimal focus threshold for casting focus spenders
    spec:RegisterStateExpr( "focus_spender_threshold", function()
        -- Beast Mastery focus thresholds:
        -- Kill Command: 40 focus (highest priority)
        -- Arcane Shot: 20 focus
        -- Reserve at least 20 focus for emergency Kill Command
        
        if not pet.alive then return 80 end -- Higher threshold without pet
        
        -- During Bestial Wrath, be more aggressive
        if buff.bestial_wrath.up then return 60 end
        
        -- Normal threshold allows for Kill Command priority
        return 70
    end )
    
    -- Determines if we're in an optimal shot weaving window
    spec:RegisterStateExpr( "optimal_shot_window", function()
        -- Optimal windows for shot rotation:
        -- 1. Not during Bestial Wrath (save focus for Kill Command spam)
        -- 2. When we have focus room
        -- 3. When cooldowns aren't ready
        
        if buff.bestial_wrath.up then return false end
        if (state.focus.current or 0) < 30 then return false end
        if cooldown.kill_command.ready and pet.alive then return false end
        
        return true
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
                -- Cost reduction/stack usage is handled by the real aura; no manual consume/proc here.
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
                apply_aspect( "aspect_of_the_cheetah" )
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

        stampede = {
            id = 121818,
            cast = 0,
            cooldown = 300,
            gcd = "off",

            startsCombat = true,
            toggle = "cooldowns",

            handler = function ()
                applyBuff( "stampede" )
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
                -- spec:summonPet( "hunter_pet" ) handled by the system
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
                -- summonPet( "hunter_pet", 3600 ) handled by the system
            end,
        },

        cobra_shot = {
            id = 77767,
            cast = function() return 2.0 / haste end,
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
                
                -- Cobra Shot maintains Serpent Sting in MoP
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                    if debuff.serpent_sting.expires > query_time + 15 then
                        debuff.serpent_sting.expires = query_time + 15 -- Cap at max duration
                    end
                end
                
                -- ToTH procs are handled by the game; don't simulate.
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
                -- summonPet( "dire_beast", 15 ) handled by the system
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
                -- dismissPet() handled by the system
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
                return state.should_focus_fire and true or false, "requires pet with frenzy stacks" 
            end,

            handler = function ()
                local stacks = buff.frenzy.stack
                removeBuff( "frenzy" )
                
                -- Focus Fire converts frenzy stacks to haste buff
                -- Each stack provides 3% haste for 20 seconds
                if stacks > 0 then
                    applyBuff( "focus_fire", 20, stacks )
                end
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

        -- === BASIC PET ABILITIES ===
        pet_growl = {
            id = 2649,
            cast = 0,
            cooldown = 5,
            gcd = "off",
            school = "physical",

            startsCombat = true,

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                -- Pet taunt - forces target to attack pet
                applyDebuff( "target", "growl", 3 )
            end,
        },

        pet_claw = {
            id = 16827,
            cast = 0,
            cooldown = 6,
            gcd = "off",
            school = "physical",

            startsCombat = true,

            usable = function() return pet.alive and pet.family == "cat", "requires cat pet" end,

            handler = function ()
                -- Basic cat attack with frenzy generation (10% chance)
                if state.can_generate_frenzy and math.random() <= 0.1 then
                    applyBuff( "frenzy", 8, min( 5, buff.frenzy.stack + 1 ) )
                end
            end,
        },

        pet_bite = {
            id = 17253,
            cast = 0,
            cooldown = 6,
            gcd = "off",
            school = "physical",

            startsCombat = true,

            usable = function() return pet.alive and (pet.family == "wolf" or pet.family == "dog"), "requires wolf or dog pet" end,

            handler = function ()
                -- Basic canine attack with frenzy generation (10% chance)
                if state.can_generate_frenzy and math.random() <= 0.1 then
                    applyBuff( "frenzy", 8, min( 5, buff.frenzy.stack + 1 ) )
                end
            end,
        },

        pet_dash = {
            id = 61684,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            school = "physical",

            startsCombat = false,

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                applyBuff( "pet_dash", 16 )
            end,
        },

        pet_prowl = {
            id = 24450,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            school = "physical",

            startsCombat = false,

            usable = function() return pet.alive and pet.family == "cat", "requires cat pet" end,

            handler = function ()
                applyBuff( "pet_prowl" )
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

            spend = function () return buff.thrill_of_the_hunt.up and 20 or 40 end, -- ToTH reduces by 20
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- ToTH procs are handled by the game; don't simulate.
                
                -- Apply Beast Cleave buff when Multi-Shot is used
                if pet.alive then
                    applyBuff( "beast_cleave", 4 )
                end
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

        counter_shot = {
            id = 147362,
            cast = 0,
            cooldown = 24,
            gcd = "spell",
            school = "physical",

            startsCombat = true,
            toggle = "interrupts",

            debuff = "casting",
            readyTime = state.timeToInterrupt,

            handler = function ()
                applyDebuff( "target", "counter_shot" )
                -- interrupt() handled by the system
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
                -- interrupt() handled by the system
            end,
        },

        steady_shot = {
            id = 56641,
            cast = function() return 2.0 / haste end,
            cooldown = 0,
            gcd = "spell",
            school = "physical",

            spend = -14,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- No Thrill of the Hunt consumption/proc simulation on generators.
            end,
        },



        thrill_of_the_hunt_active = {
            id = 34720, -- Corrected ID to match talent
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

        widow_venom = {
            id = 82654,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",
            
            spend = 15,
            spendType = "focus",
            
            startsCombat = true,
            
            handler = function ()
                applyDebuff( "target", "widow_venom" )
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

    spec:RegisterPack( "Beast Mastery", 20250914, [[Hekili:D31EZTTTY(plz6CvSpnrvpSCsAT8mUjU9KCZJoXUZzU)JKGjHS41uK6Wh2XD8Op73DXdcasaqkBN0CptN0etrSyxGf7(BFa5zdND(SZcjf0zFC0Grtg8QHh0F04rhmy8SZkUDdD2zBibxrUe(hjK1W))xPK8ITl(a8)Pz3IF8TXPKqKm5PLzbWRm7SlkJIlEBYSlSt7rW7UHgapEcmnRIcdP83LMhm7SZxfLVDb(hY2fIzF7I0LWphueLMSDrCuEb8XltZ2U4FsVkkoQ)SZypezJ0n0eAg8V(it4OjKlIPHZ(1zNXhpmJLjaZNpFnj7k(SMfTH)rF6po9JN(5Tl(8No)KZF7N(42f79BrzOepCW2f50G0KW893U4KnBIVfMDgLEAoUGKD1Z2UOyffyWFLMxerI3U4FLrkwTDXZpE7I)7Oy4bVoD9Assi)rFMSjc(NWeq5p4ScY6n0q5pDBczto8dNTjlk5Y8FQa(RROf5)ugjaiF(pTjLVGGV9ByurS9Gp43Jjrxdp6808CbbPzWAtbopa94p7KSascohRslMDgSqaYtez2z7HsBb(E59X1P5KeqEV7oqejzxsl6hLp)cgLHvJE89MRPZdtl6RV8UDX0TlgWEdX4kIwtNxKopmcMvGbgozwbOjuBRsXiBGXqIzsspCppOeMZJbQozGAh9c(c(8BW1BKEJ7i9UOC5Y(gJUF5gfDbDR45b89mKSh4KSOyXKNjQrNH7VZxcBm4yNStJnxOkGJ8qx6XaxLRtOG004W0Bs6NZvDMNZ1C6NrjHWH18yCtMpmGUVWbDf6zdLdO6NHX8s)JzuTXmchZRWXuTvfNMclkLOXdfDG3A4aJxd0GOzxbCF9xR(PAUDPRJYwttaDsyTyo)CHIyIFghTBfTcsmC4OFiSDn)c8yuF5Rvrh1NXOLBLmbTUKDee02ZZLeRUw8qT9CTxNrF3ABpz7Iqkt3nNFMEEoEu1q314ty0ZTgO1Jb1z1XASkHz2yEoA1a)pGcGvsFgDnokzA09xlzwy3SIGw7sHNUo6VictBBx8NBqNiWkxr62fRjfbRWZTSHCtucOVJlgvKB7I)hWpuJ3aopLHoniWFYtXxd)x3MwUDXkY10M2Szhz4ZzjYwmR2XeMNhWaxuSXOHxb(4OcX7fvG(eOFzdOWe2hT8(VlPjb0Fg8aWmqBoB9Lp2WjboUnK1M2ObANG8un3j3W87W4zheBxTb61OCh1xypPYOKUgayrAnjkjN7cWLELhZ4ItyK5RlZcPzZtxopil9gZZzTyDVXGBXepFkJVn5lZZkZxzmvDzjTAIRiHn)cYxki9ImcFLW84YVXxI5WgaTbGPGNtIraj0VeexgI80YS01vNcqWrpd1vtczm8f3k2PyENap1jaiR1mSbOYf56ueyszodMqyzg7Vn1z1xzaMSmoCUghZSjq)cnOeG)D)SkCkF0v2f2JdGayEAmEIE0G)lqIOK4Iv77w5wG6G)EZ3eaJ)OP4G9RG7Cy1vYpyqhvYh0)W7HAEZvwB6hSv7Iiqt(I0eWuuUVLC952Cf)CGcmyFcRyBYsdmTh3WgaoPdpy(bBcSyayYUS20U9g2Cnz(i1CvTv7gXM7LwDAQX)T6xT(6EiDja8azcpl6HuywZqxa1wZFJC04YDukWDrudmDrjG0a8W8qYA4q68j8LmUMjan)lBx8pWvWd8VcwNmJDqgnL0L0OltMhs3ri14pvScCfHNzqs(sXbXeoAoj5xhLJ4PceqZkuWx9Q(Ac1V2I5PNFYBF)PVb869Pp9(38P)fe)2FE2j)(PG1sdJM5A2cJsCAlenBAyrmA9M0Sc8ucei4Y4OaenqJO92U40K8sCIehgyNMQh9fywLDMcSldlExMGyvWHB42UJrc5wZ1WpBNopc7zJTPlzjQgZvFZWzHvEgSPCm29cQaW1gaBBeqXNXqKfCLuOrtnQaC7audms0kbX8Jne5jgbTAe85rtLrFwx1UrqyMcQwy6cPS4MOa8emQzSm6YvOZ2CgWqwskmWIMBXpt9GIhZ3P2ZbscdzsCeM7JIp09TbKXsqm2m)FW2fNZa6KxpNcczfXolx5bXmcmqWGECbfK1gaP7uewsHLFmemOgfGqPL(x7YEni5tecUlavlPzxNMvhmf7HkPJdKwC4cj6aqgVeczTl4GeciFISkCCTUjcHYXMltkCf0Vh33RYyMoWuLvSIYZoftY(dso3fZf0eyXf1o)FlX9uHznbRfq2SHzIUUtsgHruYazNJP3PMZEuMEzNmUOC27k5dnbLBtlDIMw6jBx8b2q4I(RXb1fdqjGD9eQmWYBiOkh74kZy0ohSrNoS2Wa0HYJRUsSIkwbZ1H3dpF7IpdFGZJM8D7aMUk3mBDxvxucYCyAYtX)IgtU9EgVJFzVTZUc70SLHx5yzqp3i1YEqm40a9QMfDfnxxFxShZjbFVg5EUg0HAAq1svQ9vtqZjItiMsY6Y4IONZ3wV3P(PkTx2a6qYYyjE3uA5pTDZX8nCnypwysXu4Ibp00lKcKu1olYRGuc6zRJOIrnwSt2irDQSXDdnZI9R)q(8hPTGQ5XL8DaFdWfqh9mvwdOd)mf5IOygEDbcVDe(IBtcZ8NDX7hnTLAvBzzu(AQSaRM5hGnoEqaYmDJP9SzYLBKHYA8YOVn8YiE4igeEoewmefOVq8CHR6mmGAKVYO8sKj1xaBO5cv56gMLPTKHO8gWvt0A4vVSmkKWIHSRGQQm9Q95ImB2RDdZSfS2suIlipDI4QJKMW(0lUJa3M3qq9h7dGJdoLBpcEpj8Z0hxBYJzImRNhc35ExZGuDmuDAMAKkEGT1II1NkBucMANqrQDmngZuAlqdC3kux1Jm(Z01PxtzpeleC(8acc9CVsiW3nSyKfrwlJyEF90pEDerJ404Cka72QhkDo0q7sC(oGKZJMUNZcm2s9fFsDSmWM2fe98Sbs2CCnDyv(EiGJhBRRgRGFGeLiPwvYDaXn)wyfBTT6w1bB89Kg9qFtXag(ozWRx9Q2Q7mM93EI3xt(RLG21uGMjb3Ywb11p8U(wvwzKMaNY1Cq8q7AwMmYoBvAqEsRPFhyXquISD638qqw0AsgiFV5podmFNwioPyS0W)H5yUImuGzUxqlpd4nNWC(gUO9e8AsOndaktNTlSn5rnMXMlopXE6LwQS35j6oVuWAw4SfBulht640XlzPLyom9EhvuY22zi(eHsWB2KoPhydI8id(GKsTgiGBACeJeDsidsHvZknxBWYvtdAsFnhmrEbIZq4lUJtLC4wbvRMLUMq7XDCAv5F3gQ5orIAEm9Hk2lDmkbd3xCgv4pXxfzWUHQqMFLGvuAbPE4(8on6NRYgNObS0Qo(7kXW(g9INHLPAeepnehCg95shqSd3kGNEmxZotzLNKUGGxADkYqCFXWgViycVUzTq3vKBUsJOY8Sy8orzWsn7fLe2Xch(o(DH0jMWYBOyb9fGRnkNHJr4hHj3548A1WYaXHh3eFl7rRkMZO55S4RWq4eWYPFztCAolFizKngwOn)iBUoSHtso6k0lfCZOTvPzlzD4d)57p)Tp)8t(8VF65g993jPNUplteVnHvt9C5YdSQFturWkgUZj)iwThMD5FgZdjMrcEFAKZ6DJvyshxfD5kAUbkW9yjJeJUddQJcZ0ONFGoPaeWjHKSqfUdvs8ywaEDmLvHbetqbiWnIl8Ev4BtuwUGxORoP7vAYmNba5SglgTPKv1N61I1RQ6aR8g3PBWTbXWBZgzoQQ02HtFmGnh7JTVWG5AYLeB5eU8fz53YMo7htlWwjswW4)sQfa)ruHcdneEnnop98)PK3q)h83V2l)ZywkwMrZxj120vP5eIvBbCDHxi11r58(ebZJb5I0srjtxs4fJyz)ga2CxqbvsDaMAEaJNmJJVVOIEpX2BYQEsJ08nWVDQ9SRUWNglFylB0moy)VIsdFen7bfB85eRAtwSY2iY7oLa7UmV16Qr3y53PKs3YKktEUf09(HMprA3ZLRlFgFgnWNJnpa81KVx8kNgxzFq3kWMcwIzNg5b9FJwnYdF4k3)6HkyKKnpXdiMxaolj82hHjwJqEJiW8wa0W1Gghkuf0hqFClWNQW4b1RBzDSdEdZ4BJxrHJjlUflCfnUhewQbuVg769EJoeOqYMcvVkIWyYwscmEjm6kpT3hVWuz0K)62(IgkX4uSB0l71P8SorRq9IPPH979THOQslB36r)AUnE0QSrvp)VJvvsZIQQAyIM1spXc3dG3VM1TikWTQ2FZzxFJ4mIPpxcdxnwJ()wRzRfxtN6TEv0sSYWfk0qKyFToT5tfDH9sv4aikOMnLAFmc83U0YSNBhNeSXhtXO1kGDlwc(e33i4uaDzX(Igr)1OHvoBuXz16qCGubLy7gwuvbygsn2koN6V4vvdwNGFZIGO7bk0fBFEax7gFFR1m6qxEZ6uXCeoYFy(RDJATTEsrJK2AZ9wX)zPIEAD7Z4xOz3VQ(CTITRLEjrrtJoK3ncoxv6xpdbYMnWpcSD)2)4gjLBe0orf7SjeCElaovIVe77aYgwcPKMlpj9uS3jqtFFc7EBm11CGvktMIM7hCAI9ypGwfc6lh(KCVycTIOYhwox4Yk0Yx8dm1OFqqhrYnf1vSMHdzAq75khFQuC638MWQOzkYhwpSbWUnCwHb)NPxA2a5gFMFBEnMowV2PRuMttUueQJBBDosTVGVB1QATEEh28UgovHFe)Q9(YXaG5Bizy6hYXorKkR8RO)gEkVSxpftVW)UeVvu41WcHPqklsxZ90haEMUKM3F77EFe6nBe4b)p1lOmNDaQz4n5PWayZ4Y0yWjmtTMuMHjydo7tRUCwYuxiPcV7UzTah)9yqcwMwMy82HHmegKcYfKCauX7yWtm4a4zVZImZkWuxf5VlLa9cA8DRGOUdk6pGDrrmFa)nSjNIA6)DRi2L9kRXR1vjIFGBOZdCkI)DXPn8z8WXCSyqsPDv0)Bqyu54Bh2Fnc467yHRlsIOtb6Qu0M253HUdE7Ajxo8aZ5afiWZAzXk8YiC26YLzrxHvkoDzumab(hKFTs0SyVV7h8wV33H)3p05Y(U9DC2kVFvvQ)XP)KvurplA50N4f0uVNiQiCpEHr7cXX6J6IYIQT27jDRMWDz6QguRZzlLagLv3YOQ6TS5PQ(U2FB9KkIV)EnQO7D3zwn397H0XsDCNoOxZCdDmaXZ6eBMFAgR6mL3wjaV2Rpdlp7u9QZkuc93(BvK0dHqEYAUd6XFQwlWvTgPj5hn9WQfezHW5SM7gxtNTAUpYdsTNTgyB6q9HkBWmCGQXz2YAhnzGqrRrA(KNIT18zn4q(pY6ff(sihPno14IXrdh0(qS0gy449NFuy91Pa02ew5bO9x1(vZS1HXWE7udsSe7U3UAFcaegi5fNffPu)4PJAFKgoYBsJJ6ajKHZHJUrODhpDs7uOQRPqs0SLSow1ow)Jb9h3o9mBHQ2FF9ile7gD87Ej8v)pYV(LuMz5hH)w7DOAwnoTyAdJDAeuWgyzy6j40Cu(TsOOG6QflnFDSn(tETC9(sGI1CWjY6NHfazkR(hg20Sx(L2OJ82Q01xCKTL3QkPyDTxE5CS8HU8uk(cpYYiu5SKTy58UI0CKAjOuBOwYPPuNWQQKrkL0bz0O6LnhRwQWDdfqm5JNimI4(Raa8t)69TaaF2)A(vbGAfQY7zhpR2ZxLooE4GEERrXrJfc3J3973UOyE63629D35htcypZouWHs9Jh4D33oNByqQPr2Xd6TNdXXOgB4D4)OXd2xWQnUp(m97Oh8vY3Um0rlf92Z42AD80dg02MYrtKs0d(Y2BN15fGsJTnRDLGLpcojC3Dw3hQwXFKUb92ztB2ZS2jC9e87lB5K5Xd6FOHUYetDLVoxmEhcx9ImQTD4SgLTDSOw0CYTPVox9D7YvvHi1KNgvXSNYORljQv7wsHBxVo767)hAU))qVw72xrUxad4I29(UR7W3hNEACrTEhuYbhknaBCf2V7obu5QG3gl3eEqxfD7mBvHO1y3g1TwYWhmPYNR)RAUJfMkeME8KA)mMlugsuPpse0oQAwio7e13VhlaaDSNTonJEqtttCK3NoAtXUwbDIo1QEULyP074naHNJ8W0BVwS6mr4p0SZ2oAy)jDGbVxbyTRw8BU96ID6GoVec4J(9XxXDwYK2oGTQATR(T1VxRPIRnwOnmsTob9QH7tpfa2NsvtdGtRVyqoA4O2iM7Kl0MN12OCnyzclW6yVCsyM60xR(yKRQ(DtRmISZ)FRBg1DkOLZvP6KYBCTgD8OPJg0YyTQk2s6WBqP7r2rQtID4q2HUPI9ZaV4vDj(dN08(erGBY1MbmrmtJFHBsSJy5DtOoHLZ9W7O7a3eOZqW5L7QtDkild87CZc2vfZgnsONdfQ(euBK6xperbgFqxCtKcpA3DtKypcxFt1AcjLUJgP0gXoyAQNzeqhnPobnTqzCrrMo0NflRfByqT5tRAzwNpF03KsqSB1LLPhW2xE43vsMY23WRlz91e1f3RczR90gjXw38YgIq6V7UN08Zl3SFvmNn0MmN49QV3D3D71HnH93)bZx3Dx1)SX2Edn2oBBuLEI2j6UKPHwjwZoVOXq65SxmSDUQPDaN(ZRFEFxCWZjDl21BmdnZYcli6Ah7BZMF3ilMiSMw6nNkJsQAXGMRl7NTf(Xnw4)6AVKztJBpYApVR4gztb8J(AOlEZ5yTDN0(c)WgnR1c7A(NunHWqLwCZUH3kvR6LDl07OPV0bNORoAPxia2WjOAEfvS9nWUAUQAucKbR(wChNS26AIdSteTVw1TrLX1OYH2PI(3E6ME6X)f)7F9Jg0)L9eFVRltSP3Vw3yzCCN)MD7xA)B2nLmy2NiGGO)n8MM9vBFXVjpJi(sFZ2rMjEMjNn0LOj10ZKUVFjiOMc9MyPPvxUNA9FbjOvs2DWUBTzPogp10i)DJGTqyQreZJn6KqWP(pZ84(BShKIF)9lTNA5F5VRFV9O2czloEb53s6hKey3ASIwuvhAH(3Ni)7kZVJbX7IS1tIF3)9OZV84(7rNMsyRrolIQV7)6XrnhIFL84vlQLinvKOMEK1XPqXVlM8uZrllgSlJ2S)V]] )
