    -- HunterBeastMastery.lua
    -- july 2025 by smufrik


    if select(2, UnitClass('player')) ~= 'HUNTER' then return end

    if not Hekili or not Hekili.NewSpecialization then return end

    local addon, ns = ...
    local Hekili = _G[ addon ]
    local class, state = Hekili.Class, Hekili.State

    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local strformat = string.format

local spec = Hekili:NewSpecialization( 253, true )

spec.role = "DAMAGER"
spec.primaryStat = "agility"
spec.name = "Beast Mastery"



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

            

            handler = function ()
                applyBuff( "feign_death" )
            end,
        },

        exhilaration = {
            id = 109304,
            cast = 0,
            cooldown = 120,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            toggle = "defensives",

            handler = function ()
                -- Heals for 30% of max health
                gain( health.max * 0.3, "health" )
            end,
        },

        focus_fire = {
            id = 82692,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "nature",

            startsCombat = false,

            usable = function () 
                return pet.alive and buff.frenzy.stack > 0 and not buff.focus_fire.up, "requires pet with frenzy stacks and no active focus fire" 
            end,

            handler = function ()
                local stacks = buff.frenzy.stack
                removeBuff( "frenzy" )
                
                -- Focus Fire consumes frenzy stacks and grants ranged haste
                -- Each stack provides 6% ranged haste for 20 seconds
                -- Pet gains 6 focus per stack consumed
                if stacks > 0 then
                    applyBuff( "focus_fire", 20, stacks )
                    -- Pet focus gain is handled by the game
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

                toggle = "cooldowns",

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

            spend = 40,
            spendType = "focus",

            startsCombat = true,

            usable = function() return pet.alive, "requires a living pet" end,

            handler = function ()
                -- Kill Command damage is done by pet
                -- 40% chance to proc Frenzy stack (handled by pet combat log)
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

            spend = 0,

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
                -- Apply Serpent Sting DoT (15s duration, 3s tick time, 5 ticks total)
                applyDebuff( "target", "serpent_sting", 15 )
            end,
        },

        counter_shot = {
            id = 147362,
            cast = 0,
            cooldown = 24,
            gcd = "spell",
            school = "physical",

            toggle = "interrupts",
            startsCombat = true,

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



        trinket1 = {
            id = 0,
            cast = 0,
            cooldown = 0,
            gcd = "off",

            startsCombat = false,

            toggle = "cooldowns",

            handler = function ()
                -- Trinket 1 usage
            end,
        },

        trinket2 = {
            id = 0,
            cast = 0,
            cooldown = 0,
            gcd = "off",

            startsCombat = false,

            toggle = "cooldowns",

            handler = function ()
                -- Trinket 2 usage
            end,
        },

        hands = {
            id = 0,
            cast = 0,
            cooldown = 60,
            gcd = "off",

            startsCombat = false,

            toggle = "cooldowns",

            handler = function ()
                -- Hands usage (Synapse Springs)
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

            toggle = "cooldowns",
            talent = "wyvern_sting",
            startsCombat = true,

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

    spec:RegisterPack( "Beast Mastery", 20260201, [[Hekili:vVXAVTTrYFlgbWXUjvNiLv8LcjdKhxUMGg3GQeKVrYvKRSimfPkFehFWG)2Vz2Lp2LCxskkNE9(qtJiNz2zN3pySmS(S1kpsk16AZPMVyQ5uJjMtNFHHH1Q073tTwTN4El5g4Ves2b)5RPKK0CNpc)jn(E813her8qYKeLf7cGyTADMFq67dTwlq75ggMtTwrYs3gfBTA1USnX(3ATARVNhLdknX1A1N36NK7G)hj3P4WZDI2a)2n1pkm3jWpjfE9MO4CNFLERFG)eRvShICr0EAing(BxZUB0qY6aQN1R50p2Fpse48P)zgn0L(l5oVMMK6tcYD(AmjDBUZpFvUZQ7dj7tGdE1(y)WBskEAkz3EQhL)R)GS33l35D(Xfp4vGCjl2JgZ533ehDxbIVLbtHSdFW)oG4)n4rFokPae3OWu)Wm4zXrPeotcSliL9jGyMMoHeWq5u8Q7MbOD1YCN5Om1Ld(A(fX(o8EyLcIDucu(2TKqVerbcaWmrasHB6T0uJgWCHcymBaZCrywhef5zVjdnpKG6fsqrJtOX3cc3gqDPiu7J4)Fji(NnuS1IPu)DGecKMZRjrsHsdX8LheMXOc2EdO7qCnMQhzsaneuq27yQF7On2UOYFsj0vKSfimk30sTfL9aEWEnA(0MK1VJrlZ(O1nmtp7uWYRKynnQmeeccGZO)mT0)KChp66SnBMakwWlm1gmhdVzs2EbLH4By07cT0RYMVgDWzpW2nA3oWwMH9CTyZyejpcGrAErNjCrjXUKqQDY2iuqMIuigKPkcKCqSOE9XG4JR1lVFm0NPOLpyoUokmlHM09TvPiTzaMoVYAukp8ag)lkWl6UWgVoMUJ4hMWCnnNQiyvNIOh9ZZKlZ8OBOHjOEVtb2wkjaO5ExiQ)IgbRPFFRFajMhPVtHMFiyobUl2EKDqYq75CURG47iFp35NYDMorqj7rbCJX8BC(T8Y2Jc(iYY8dq8BOnu8Ou4PK4BG7hgOhS(T98PCLIOwwmxH(at9fUNj9ol354U(MtZDoVNmh6d)DWjoErFKk4(WVBhNLSv6AkBYC0xAJ5sx6QZSiISiE2j0ui8tNg0fS(gA83IIvfDenaMDz9bYHSBR6rLNtVjRsAvjtwaYeZA66gToMiKJce)2qMgiSWoa5UfgNiOTeOibYxHKXO7BTSIg)fpaKDv0nqFG8EYeKA4lHFWaw9laTTGNhW(EiBufFLKf8d4(i1dWNOaNxl9aZ3YIW9o))nx9wMjs877dXO6z7tfThYWhwvTqZGws4)fSHgE)riNXBacmMZIzCfeDfBpXyk(sqsGDlijv5)WgB1YQvPZOH6uEFy28wfl6etrykjU6naPB0C3Wo3(cNGkMxW0cNOjSKe7Qk4II4I65mbAvNVTSHMdLcS4tSeEI(3kA(zisQbC5z16QOdPHqE8XqjLG2ENpTOIbtjYtIu3c1yO(IMe3ncesvnnRQFQHCm7I(gtgdPmHQayogSkFKoQsGSu1P1qoLHwl3mPJTUCtvDGni7Pgjku151GOJu3cQ6aRDeh4UVdhNtiK5nM4c2GWVUZhh1sZrVCgztkB8jSqhNpaB4sMUQ5dd9fYCCLMOR7dJM(3)apqt2bQF(h9iKeMmdsh9tdPp6up7gmhBtVAjtGF1)gqXUp2pcO(9GzWA)aFWkkX6VLvuB2vXKSgiAM7xunXA(VmxS5F9ngzQVmZHmQc9T88i2xLzNrm(mZsOBZKrvo)F77V5At9bskyX9r3bEEG5LUb9CHGLrfWmA3Xmtp0ofn7ykQCATMehdzA0YLIttGdkR23oJJ82OplwSU1r3qMEh9E6idlRuScCHoYUEwNnC8oWHdQiUTa7OMH31Zo45Hm0PGE9m9HeeiWLVupb0pIIA1g977dIsyxjiEMKEt(vw8MEJH2t2TMOS)q5KpSUJ(LQvVuS2QCNVShxmfiK)D30O1yjhgphdzzc(NVMKGVb7g5RrFDLpw8YhJ(uUZR(0VbnOeDJVBUJcLOFmuW0wYD3kPcl79GKSN6MI5As3sTRHv8YQbgMtxxIXJKbaWudupmyjV15kb6TfDP9l1qDlq10gBzs1MHWgJJ6zMSi(nBwzwnz3LfK6xNcV)0PmzCtIUqIMnZZQxEPI5mBK5bmHTDdOKVrLNs0K58SqNOcsujFExXHLV36961hRvTGapg2BuvMWv8zgOog9k37bM3MJxcQsthWappUiP9wKW4Za3BY9XL0uFEDLg6LregrG3owEQuQGb4q0ihbFSaksO205w9qroGvAWU0BIPH)N7Na1K6EBUd2JVW7Qob5e(x05CKyVCav)jyBuFqwfBOrCig9muBH(qMmG(q6x4mMyvpkoC9UKLX7W1BOIX5WPpeXOkdvFyHHvFLE))JOk2xoq)XQXHvAVwIJNFcn8g2NnKmkasFduriqcFuq3rIdXPKJF9p4aJ2TpkoT4l85P8zb90CNy6FMb(lGIkjcN4mjlnAhVko3TKWBOjtY)WV5hcV6cOKVVeMKThjecaNXaQvoiLNcWM)bfhN4aUoSdD24p0I9DCyNNXLd8aF)UsamM1ys7W7bJsOOoSV8zyP1rB8da12tYD0v88hEsN1pJVEqLqJS2taG)um9N51ZN)boZLmPQe)NT8FOPW1N7VzPUcFp9K(k5DaNu5HCYJ8Pux(lJ61zOucTCEy1WWRfUuE(rWdV(RiRcJL6pxMoRRTHvre4WkxxfsKkACQ8wXwSu1IVov1dVAAX5xTDlXdtC)wfWDWBXsIEnMT9ZXPAVKtnMbfuE6cJswsXQP6Nyk2Jes5UlpyXYxuyn1Q2IEpWQLn1pOklGQF0yBhcVeJKdHMYqSXNxxu4vln7htPYIAtJfdGeLjPqSBTKNRwoVFkuT(fKeT3GZv1BV5NMozw)0tExm9dVykjrNa)rVyfXZKT5KbPCl36HwGF4HUTYVYCQc6z(yrV61BmORt9wm6aCM0w7omejxR1jiKGs7Ino9SXEXL0Hv17ZpZg7PyXsz5u9odgVK3yERZVORbP8cIavUeGoo02djGZ78eB)ERG(NPiAp7BVMNA8CM27)d(uVRtRZDqzwNcch5CTSO4qKRPkqJ5nR45L(U6FLPkMOYJsjhw6)O4LLLK06fIwbOE(Q5kas2cvlyJYLtbDQ3VHabAVqefyk0oRaQk6jUuPzO6Ei1JgR4mDZyRnU976jiVQ7DuRtyjJoBErWVwBKt0NMVGnHRU8U54eBXYzxkIu1wVeWR123oT2EFKXinMlfJSA4acNARPluE7Vqk82HAFGoh8jgiaFJXnuDsLfB2ybxsropy7dSwIQ(2rm6AAaqXNf8aFbvIu5ymWhHfNwmlG5YxkcJCVrIcMwd2SmhsZmaRW6ZRDvuu8(OSY1qOdxrQHqhGY1WS8U)MwnkmPQ3HdoJJiMpYfuir7JOQbvKBuPmgBeiXQ0K4IdnGIeY)vg(KB48o(Oi5L)8X2HOMOSVs0XP65Y2tTMd)Y5NQz(7lwEHMoJpTNlW8kF(mwrIFAljriRiRP2HLaTeu1XKeIBvb5OcBw6LIs5)OSYqNZwbEZbybKmZCjlkHMJFwxDbmPzxaQXTBPqtug1DuhXgB25we6Gs8QJiJioDts0B(RwyCaX0Xe29tMQbcwm1JACkNdcluuXO6lH(TLt7Og8QbGWY5w)VBjKpfnWeZpiIt9)CKqm6BckvEcSjsQkCJ8auE2GgPAtu(XmgtSEzFSRWxxoUMsgqCiopBWtDPjApQJGrdXpY5XWLcVk6Fj0ERZzMpR8tairicgjcnpQ)2dWtgFN4ucN1eCTHQovg1fTWS7dYSktz7pXIfgtM)WdN0(9z7pxvaf(5jhgr67zyPrxHvAEtGCGTlY5kJwh4rfsMtIrhiMJ(Oc)YrTD18TmfoTJ67LjMUWV9AJ04FHvw)3)]] )
