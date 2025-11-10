    -- HunterSurvival.lua
    -- August 2025 by Smufrik & SaschaDaSilva

-- Early return if not a Hunter
if select(2, UnitClass('player')) ~= 'HUNTER' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]

-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
    

local class = Hekili.Class
local state = Hekili.State

-- Custom variable to track if the last spell cast was Steady Shot.
local mm_last_spell_was_steady = false

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local spec = Hekili:NewSpecialization( 254, true )



    -- Use MoP power type numbers instead of Enum
    -- Focus = 2 in MoP Classic
    spec:RegisterResource( 2, {
    steady_shot = {
        resource = "focus",
            cast = function(x) return x > 0 and x or nil end,
            aura = function(x)
                -- Only predict focus if casting Steady Shot
                if state.buff.casting.up and state.casting and state.casting.name == "steady_shot" then
                    return "casting"
                end
                return nil
            end,
        last = function()
                return state.buff.casting.applied
            end,
            interval = function() return state.buff.casting.duration end,
            value = function()
                -- Steady Shot provides 14 focus (17 with Steady Focus active)
                if state.buff.steady_focus and state.buff.steady_focus.up then
                    return 17
                end
                return 14
            end,
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

        interval = 1,
            value = 5,
            duration = 10,
        },
    } )

    -- Talents
spec:RegisterTalents( {
        -- Tier 1 (Level 15)
        posthaste = { 1, 1, 109215 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 60% for 4 sec.
        narrow_escape = { 1, 2, 109298 }, -- When Disengage is activated, you also activate a web trap which encases all targets within 8 yards in sticky webs, preventing movement for 8 sec. Damage caused may interrupt the effect.
        crouching_tiger_hidden_chimera = { 1, 3, 118675 }, -- Reduces the cooldown of Disengage by 6 sec and Deterrence by 10 sec.

        -- Tier 2 (Level 30)
        binding_shot = { 2, 1, 109248 }, -- Your next Arcane Shot, Chimera Shot, or Multi-Shot also deals 50% of its damage to all other enemies within 8 yards of the target, and reduces the movement speed of those enemies by 50% for 4 sec.
        wyvern_sting = { 2, 2, 19386 }, -- A stinging shot that puts the target to sleep for 30 sec. Any damage will cancel the effect. When the target wakes up, the Sting causes 0 Nature damage over 6 sec. Only one Sting per Hunter can be active on the target at a time.
        intimidation = { 2, 3, 19577 }, -- Command your pet to intimidate the target, causing a high amount of threat and reducing the target's movement speed by 50% for 3 sec.

        -- Tier 3 (Level 45)
        exhilaration = { 3, 1, 109260 }, -- Instantly heals you for 30% of your total health.
        aspect_of_the_iron_hawk = { 3, 2, 109260 }, -- Reduces all damage taken by 15%.
        spirit_bond = { 3, 3, 109212 }, -- While your pet is active, you and your pet will regenerate 2% of total health every 2 sec, and your pet will grow to 130% of normal size.

        -- Tier 4 (Level 60)
        fervor = { 4, 1, 82726 }, -- Instantly resets the cooldown on your Kill Command and causes you and your pet to generate 50 Focus over 3 sec.
        dire_beast = { 4, 2, 120679 }, -- Summons a powerful wild beast that attacks your target and roars, increasing your Focus regeneration by 50% for 8 sec.
        thrill_of_the_hunt = { 4, 3, 34720 }, -- You have a 30% chance when you fire a ranged attack that costs Focus to reduce the Focus cost of your next 3 Arcane Shots or Multi-Shots by 20.

        -- Tier 5 (Level 75)
        a_murder_of_crows = { 5, 1, 131894 }, -- Sends a murder of crows to attack the target, dealing 0 Physical damage over 15 sec. If the target dies while under attack, A Murder of Crows' cooldown is reset.
        blink_strikes = { 5, 2, 109304 }, -- Your pet's Basic Attacks deal 50% additional damage, and your pet can now use Blink Strike, teleporting to the target and dealing 0 Physical damage.
        lynx_rush = { 5, 3, 120697 }, -- Your pet charges your target, dealing 0 Physical damage and causing the target to bleed for 0 Physical damage over 8 sec.

        -- Tier 6 (Level 90)
        glaive_toss = { 6, 1, 117050 }, -- Throws a glaive at the target, dealing 0 Physical damage to the target and 0 Physical damage to all enemies in a line between you and the target. The glaive returns to you, damaging enemies in its path again.
        powershot = { 6, 2, 109259 }, -- A powerful shot that deals 0 Physical damage and reduces the target's movement speed by 50% for 6 sec.
        barrage = { 6, 3, 120360 }, -- Rapidly fires a spray of shots for 3 sec, dealing 0 Physical damage to all enemies in front of you.
        
    } )

    -- Auras
spec:RegisterAuras( {
        -- Internal helper for opener gating on Stormlash.
        stormlash_totem_raid = {
            id = 0, -- internal only
            duration = 10,
            max_stack = 1,
        },
        -- Stormlash (player buff) for burst-window awareness.
        stormlash = {
            id = 120676,
            duration = 10,
            max_stack = 1,
            generate = function( t )
                local name, _, _, _, duration, expires, caster = FindUnitBuffByID( "player", 120676 )
                if name then
                    t.name = name
                    t.count = 1
                    t.applied = expires - duration
                    t.expires = expires
                    t.caster = caster
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        -- Common aspects
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
        aspect_of_the_iron_hawk = {
            id = 109260,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
                local name, _, _, _, _, _, caster = FindUnitBuffByID( "player", 109260 )
                
                if name then
                    t.name = name
                t.count = 1
                    t.applied = state.query_time
                    t.expires = state.query_time + 3600
                t.caster = "player"
                return
            end
                
            t.count = 0
            t.applied = 0
                t.expires = 0
            t.caster = "nobody"
        end,
    },
        casting = {
            id = 116951,
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
        cobra_shot = {
            id = 19386,
        duration = 6,
        max_stack = 1
    },

        disengage = {
            id = 781,
            duration = 20,
            max_stack = 1
        },

        focus_fire = {
            id = 82692,
            duration = 20,
            max_stack = 1
        },
        kill_command = {
            id = 34026,
            duration = 5,
        max_stack = 1
    },
        multi_shot = {
            id = 2643,
            duration = 4,
        max_stack = 1
    },
        rapid_fire = {
            id = 3045,
        duration = 15,
        max_stack = 1
    },
        -- Master Marksman (Aimed Shot!); expose as master_marksman for APL compatibility
        master_marksman = {
            -- Ready, Set, Aim... buff for instant/free Aimed Shot
            id = 82926,
            duration = 8,
            max_stack = 1
        },
        master_marksman_counter = {
            -- Counter for Master Marksman stacks (hidden)
            id = 82925,
            duration = 30,
            max_stack = 2
        },
    steady_focus = {
        id = 53220,
        duration = 20,
        max_stack = 1,
        haste = 0.15
    
    },

        -- Internal helper aura to track consecutive Steady Shots for Steady Focus maintenance.
        -- Not a real game aura; used by APL conditions like buff.steady_focus_pre.stack.
        steady_focus_pre = {
            id = 0, -- internal only
            duration = 10,
            max_stack = 2,
        },

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
    
        hunters_mark = {
            id = 1130,
            duration = 300,
        type = "Ranged",
        max_stack = 1
    },



    serpent_sting = { --- Debuff
        id = 118253,    
        duration = 15,
        tick_time = 3,
        type = "Ranged",
        max_stack = 1
    },

        concussive_shot = {
            id = 5116,
            duration = 6,
            max_stack = 1
        },

        deterrence = {
            id = 19263,
            duration = 5,
            max_stack = 1
        },

        mend_pet = {
            id = 136,
            duration = 10,
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
    
        misdirection = {
            id = 34477,
            duration = 8,
            max_stack = 1
    },
    
    aspect_of_the_cheetah = {
        id = 5118,
        duration = 3600,
            max_stack = 1
        },

        a_murder_of_crows = {
            id = 131894,
            duration = 30,
            max_stack = 1
        },

        lynx_rush = {
            id = 120697,
            duration = 4,
            max_stack = 1
        },

        barrage = {
            id = 120360,
            duration = 3,
            max_stack = 1
        },

        black_arrow = {
            id = 3674,
            duration = 15,
        max_stack = 1,
            debuff = true
        },

        lock_and_load = {
        id = 56453,
        duration = 8,
        max_stack = 3,
        },

        piercing_shots = {
            id = 82924,
            duration = 8,
            max_stack = 1
        },


        blink_strikes = {
            id = 109304,
            duration = 0,
            max_stack = 1
        },

        -- Tier 2 Talent Auras (Active abilities only)
        binding_shot = {
            id = 109248,
            duration = 4,
            max_stack = 1
        },
    
    wyvern_sting = {
        id = 19386,
        duration = 30,
            max_stack = 1
        },

        intimidation = {
            id = 19577,
            duration = 3,
            max_stack = 1
        },

        -- Tier 3 Talent Auras (Active abilities only)
        exhilaration = {
            id = 109260,
            duration = 0,
            max_stack = 1
        },

        -- Tier 4 Talent Auras (Active abilities only)
        fervor = {
            id = 82726,
            duration = 3,
            max_stack = 1
        },



        counter_shot = {
            id = 147362,
            duration = 3,
            mechanic = "interrupt",
            max_stack = 1
        },

        silencing_shot = {
            id = 34490,
            duration = 3,
            max_stack = 1
        },

        explosive_shot = {
            id = 53301,
            duration = 4, -- DoT duration
            max_stack = 1
        },

        stampede = {
            id = 121818,
            duration = 12,
        max_stack = 1,
            
        },

        explosive_trap = {
            id = 13813,
            duration = 20,
            max_stack = 1
        },
        -- Dire Beast focus regen aura (used by resources)
        dire_beast = {
            id = 120694,
            duration = 15,
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

        -- Tier set bonuses for MoP (for APL expressions that reference them)
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



        
    } )

    spec:RegisterStateFunction( "apply_aspect", function( name )
        removeBuff( "aspect_of_the_hawk" )
        removeBuff( "aspect_of_the_iron_hawk" )
        removeBuff( "aspect_of_the_cheetah" )
        removeBuff( "aspect_of_the_pack" )

        if name then applyBuff( name ) end
    end )



    -- Abilities
    spec:RegisterAbilities( {
       arcane_shot = {
            id = 3044,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
            spend = function () return buff.thrill_of_the_hunt.up and 10 or 30 end,
        spendType = "focus",
        startsCombat = true,
        handler = function ()
                mm_last_spell_was_steady = false
        end,
    },
    
        aspect_of_the_hawk = {
            id = 13165,
            cast = 0,
        cooldown = 0,
        gcd = "spell",
            
            startsCombat = false,
            texture = 136076,
        
        handler = function ()
                apply_aspect( "aspect_of_the_hawk" )
            end,
        },
        
        black_arrow = {
            id = 3674,
            cast = 0,
            cooldown = 30,
            gcd = "spell",

            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "black_arrow" )
        end,
    },
    
    cobra_shot = {
        id = 77767,
            cast = function() return 2.0 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = -14,
        spendType = "focus",
        startsCombat = true,
        
        handler = function ()
                -- Cobra Shot maintains Serpent Sting in MoP (key Survival mechanic)
            if debuff.serpent_sting.up then
                debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                    if debuff.serpent_sting.expires > query_time + 15 then
                        debuff.serpent_sting.expires = query_time + 15 -- Cap at max duration
                end
            end
        end,
    },
    

        disengage = {
            id = 781,
        cast = 0,
            cooldown = 20,
            gcd = "off",

            startsCombat = false,
        
        handler = function ()
                applyBuff( "disengage" )
        end,
    },
    


        kill_command = {
            id = 34026,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

            spend = 40,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
                applyBuff( "kill_command" )
        end,
    },
    
        multi_shot = {
            id = 2643,
        cast = 0,
            cooldown = 0,
        gcd = "spell",

            spend = function () return buff.thrill_of_the_hunt.up and 20 or 40 end,
        spendType = "focus",
        
        startsCombat = true,
        
        handler = function ()
                -- Apply Multi-Shot buff for tracking
                applyBuff( "multi_shot" )
                
                -- Serpent Spread: Multi-Shot spreads Serpent Sting to all targets hit (Survival passive)
                if debuff.serpent_sting.up then
                    -- In MoP, Multi-Shot spreads Serpent Sting to all enemies within range
                    applyDebuff( "target", "serpent_sting" )
                    -- Note: In a real implementation, this would spread to all targets in AoE range
                end
        end,
    },
    
        rapid_fire = {
            id = 3045,
        cast = 0,
            cooldown = 300,
        gcd = "off",
        
            toggle = "cooldowns",
        startsCombat = false,
            
        
    handler = function ()
                applyBuff( "rapid_fire" )
        -- Break Steady Focus pre-chain on non-Steady cast
        removeBuff("steady_focus_pre")
        end,
    },
    
        steady_shot = {
            id = 56641,
            cast = function() return 2.0 / haste end,
            cooldown = 0,
        gcd = "spell",
            school = "physical",

            spend = function()
                -- Steady Shot provides 14 focus (17 with Steady Focus)
                return buff.steady_focus.up and -17 or -14
            end,
            spendType = "focus",

            startsCombat = true,
            texture = 132213,
        
        handler = function ()
                -- Track consecutive Steady Shots for Steady Focus precondition.
                -- Increment steady_focus_pre stack count (max 2)
                local current_stacks = buff.steady_focus_pre.stack or 0
                applyBuff("steady_focus_pre", 10, math.min(2, current_stacks + 1))
                -- Master Marksman: 50% chance to gain a stack on Steady Shot cast
                -- At 2 stacks, gain Ready, Set, Aim... buff for instant free Aimed Shot
                if talent.master_marksman.enabled then
                    if math.random() < 0.5 then
                        if buff.master_marksman_counter.stack == 1 then
                            removeBuff("master_marksman_counter")
                            applyBuff("master_marksman", 8) -- Ready, Set, Aim...
                        else
                            applyBuff("master_marksman_counter")
                        end
                    end
                end
        end,
    },
    
        serpent_sting = {
            id = 1978,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        school = "nature",
            
        spend = 15,
        spendType = "focus",
            
        startsCombat = true,

    handler = function ()
                applyDebuff( "target", "serpent_sting" )
        removeBuff("steady_focus_pre")
        end,
    },
    
        explosive_shot = {
            id = 53301,
        cast = 0,
            cooldown = 6, -- 6-second cooldown in MoP
        gcd = "spell",
        
            spend = function() return buff.lock_and_load.up and 0 or 25 end,
        spendType = "focus",
        
        startsCombat = true,
        
    handler = function ()
                -- Apply Explosive Shot DoT (fires a shot that explodes after a delay)
                applyDebuff( "target", "explosive_shot" )
                
                -- Handle Lock and Load charge consumption
                if buff.lock_and_load.up then
                    -- Consume one charge when Explosive Shot is cast during Lock and Load
                    removeBuff( "lock_and_load", 1 )
                end
                
                -- Explosive Shot is the signature Survival ability
                -- It does high fire damage and is central to the rotation
                removeBuff("steady_focus_pre")
        end,
    },
    
        stampede = {
            id = 121818,
        cast = 0,
            cooldown = 300,
            gcd = "off",
        
            toggle = "cooldowns",
        startsCombat = true,
            
        
    handler = function ()
                applyBuff( "stampede" )
        removeBuff("steady_focus_pre")
        end,
    },
    

        tranquilizing_shot = {
            id = 19801,
        cast = 0,
            cooldown = 8,
        gcd = "spell",
        
        startsCombat = true,
        
        handler = function ()
                -- Dispel magic effect
        end,
    },
    
        -- Counter Shot exists in MoP but Marksmanship uses Silencing Shot when talented; prefer silencing_shot.

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
    
        hunters_mark = {
            id = 1130,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
            startsCombat = false,
        
        handler = function ()
                applyDebuff( "target", "hunters_mark", 300 )
        end,
    },
    
        aimed_shot = {
            id = 19434,
            cast = function()
                -- Master Marksman makes Aimed Shot instant cast
                if buff.master_marksman.up then
                    return 0
                end
                return 2.5 / haste
            end,
            cooldown = 0,
            gcd = "spell",
            
            spend = function()
                -- Master Marksman makes Aimed Shot free
                return buff.master_marksman.up and 0 or 50
            end,
            spendType = "focus",
            
            startsCombat = true,
            usable = function()
                -- Always allow instant proc version
                if buff.master_marksman.up then return true end
                -- Gate hard-casts per 'aimed' logic
                local focus_now = (state.focus and state.focus.current) or 0
                if focus_now >= 85 then return true end
                if buff.rapid_fire and buff.rapid_fire.up then return true end
                local cs_in = (cooldown.chimera_shot and cooldown.chimera_shot.remains) or 0
                local crows_in = (cooldown.a_murder_of_crows and cooldown.a_murder_of_crows.remains) or 999
                if cs_in > 3 and crows_in > 3 then return true end
                return false, "aimed gated to avoid starving CS/Crows"
            end,
        
        handler = function ()
                -- Consume Master Marksman buff if present
                if buff.master_marksman.up then
                    removeBuff("master_marksman")
                end
        end,
    },
    
        -- Master Marksman proc version (spell ID changes when buff is active)
        master_marksman_aimed_shot = {
            id = 82928,
            cast = 0, -- Instant when procced
            cooldown = 0,
            gcd = "spell",
            
            spend = 0, -- Free when procced
            spendType = "focus",
            
            startsCombat = true,
            
            copy = "aimed_shot", -- Link to main aimed_shot for keybind sharing
        
        handler = function ()
                -- Consume Master Marksman buff
                removeBuff("master_marksman")
        end,
    },
    
        chimera_shot = {
            id = 53209,
        cast = 0,
            cooldown = 10,
        gcd = "spell",
        
            spend = 45,
            spendType = "focus",
        
            startsCombat = true,
        
        handler = function ()
                -- Refresh Serpent Sting to its full duration (15s) if present
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = query_time + 15
            end
        end,
    },
    
        -- === AUTO SHOT (PASSIVE) ===
        auto_shot = {
            id = 75,
        cast = 0,
            cooldown = function() return ranged_speed or 2.8 end,
        gcd = "off",
        school = "physical",
            
            startsCombat = true,
            texture = 132215,
        },

        kill_shot = {
            id = 53351,
        cast = 0,
            cooldown = 10,
        gcd = "spell",
            
            spend = 0,
            
            startsCombat = true,
            texture = 236174,
        
        handler = function ()
                -- Kill Shot for targets below 20% health
        end,
    },
    
        concussive_shot = {
            id = 5116,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
            spend = 15,
            spendType = "focus",
        
            startsCombat = true,
            texture = 132296,
        
        handler = function ()
                applyDebuff( "target", "concussive_shot", 6 )
        end,
    },
    
        deterrence = {
            id = 19263,
        cast = 0,
            cooldown = 90,
        gcd = "off",
            toggle = "defensives",
        startsCombat = false,
            texture = 132369,
        
        handler = function ()
                applyBuff( "deterrence" )
        end,
    },
    
        feign_death = {
            id = 5384,
        cast = 0,
            cooldown = 0,
            gcd = "off",
        
        startsCombat = false,
            texture = 132293,
        
        handler = function ()
                -- Feign Death drops combat
        end,
    },
    
        mend_pet = {
            id = 136,
            cast = 3,
            cooldown = 0,
            gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                applyBuff( "mend_pet" )
        end,
    },
        revive_pet = {
            id = 982,
            cast = 6,
            cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                -- Revive Pet ability
        end,
    },
    
        call_pet = {
        id = 883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return not pet.alive, "no pet currently active" end,
        
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
    
        call_pet_2 = {
            id = 83242,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
            usable = function () return not pet.exists, "requires no active pet" end,
        handler = function ()
                -- summonPet( "ferocity" ) handled by the system
        end,
    },
    
        call_pet_3 = {
            id = 83243,
            cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,
            usable = function () return not pet.exists, "requires no active pet" end,
        handler = function ()
                -- summonPet( "cunning" ) handled by the system
        end,
    },
    
    dismiss_pet = {
        id = 2641,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        usable = function() return pet.alive, "requires active pet" end,
        
        handler = function ()
                -- dismissPet() handled by the system
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
            -- Basic cat attack
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
            -- Basic canine attack
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
    
        misdirection = {
            id = 34477,
        cast = 0,
            cooldown = 30,
            gcd = "off",

            startsCombat = false,

            handler = function ()
                applyBuff( "misdirection", 8 )
            end,
        },

        aspect_of_the_cheetah = {
            id = 5118,
            cast = 0,
            cooldown = 60,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                apply_aspect( "aspect_of_the_cheetah" )
        end,
    },
    
        aspect_of_the_iron_hawk = {
            id = 109260,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        
        handler = function ()
                apply_aspect( "aspect_of_the_iron_hawk" )
        end,
    },

        a_murder_of_crows = {
            id = 131894,
            cast = 0,
            cooldown = 120,
            gcd = "spell",

            spend = 60,
            spendType = "focus",

            toggle = "cooldowns",
            startsCombat = true,
            

            handler = function ()
                applyDebuff( "target", "a_murder_of_crows" )
            end,
        },

        lynx_rush = {
            id = 120697,
            cast = 0,
            cooldown = 90,
            gcd = "spell",

            toggle = "cooldowns",
            startsCombat = true,
            

            handler = function ()
                applyDebuff( "target", "lynx_rush" )
            end,
        },

        glaive_toss = {
            id = 117050,
            cast = 0,
            cooldown = 15,
            gcd = "spell",

            spend = 15,
            spendType = "focus",

            toggle = "cooldowns",
            startsCombat = true,

            handler = function ()
                -- Glaive Toss deals damage to target and enemies in line
            end,
        },

        powershot = {
            id = 109259,
            cast = 3,
            cooldown = 45,
            gcd = "spell",
            
            spend = 15,
            spendType = "focus",
            
            toggle = "cooldowns",
            startsCombat = true,

            handler = function ()
                -- Power Shot deals damage and knocks back enemies
            end,
        },

        barrage = {
            id = 120360,
            cast = 3,
            channeled = true,
            cooldown = 20,
            gcd = "spell",

            spend = 40,
            spendType = "focus",

            toggle = "cooldowns",
            startsCombat = true,
            usable = function()
                -- Optional gating: prefer during raid burst or when not starving Chimera/Crows soon.
                if settings and settings.mm_gate_barrage_on_burst then
                    if buff.stormlash and buff.stormlash.up then return true end
                    local cs_in = (cooldown.chimera_shot and cooldown.chimera_shot.remains) or 0
                    local crows_in = (cooldown.a_murder_of_crows and cooldown.a_murder_of_crows.remains) or 999
                    if cs_in <= 3 or crows_in <= 3 then return false, "hold for upcoming CS/Crows" end
                end
                return true
            end,

            handler = function ()
                applyBuff( "barrage" )
            end,
        },

        blink_strike = {
            id = 130392,
            cast = 0,
            cooldown = 20,
            gcd = "spell",

            startsCombat = true,
            toggle = "cooldowns",
            handler = function ()
                -- Pet ability, no special handling needed
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
    
        -- Additional talent abilities
        piercing_shots = {
            id = 82924,
        cast = 0,
            cooldown = 0,
            gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
                -- Passive talent, no active handling needed
        end,
    },
    
        -- Pet abilities that can be talented
        blink_strikes = {
            id = 109304,
        cast = 0,
            cooldown = 0,
            gcd = "off",
        
        startsCombat = false,
        
        handler = function ()
                -- Passive talent, no active handling needed
        end,
    },
    
        -- Tier 2 Talents (Active abilities only)
        binding_shot = {
            id = 109248,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
        
            startsCombat = true,
        
        handler = function ()
                -- Passive talent, no active handling needed
        end,
    },
    

        intimidation = {
            id = 19577,
        cast = 0,
            cooldown = 0,
        gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                -- Pet ability, no special handling needed
            end,
        },

        wyvern_sting = {
            id = 19386,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            startsCombat = true,

            handler = function ()
                applyDebuff( "target", "wyvern_sting" )
            end,
        },

        -- Tier 3 Talents (Active abilities only)
        exhilaration = {
            id = 109260,
            cast = 0,
            cooldown = 120,
            gcd = "off",
            
            toggle = "defensives",
        startsCombat = false,
            
        
        handler = function ()
                -- Self-heal ability
        end,
    },
    
        -- Tier 4 Talents (Active abilities only)
        fervor = {
            id = 82726,
        cast = 0,
            cooldown = 30,
        gcd = "off",
            toggle = "cooldowns",
            startsCombat = false,
            
        
        handler = function ()
                applyBuff( "fervor" )
            end,
        },

        dire_beast = {
            id = 120679,
            cast = 0,
            cooldown = 45,
            gcd = "spell",
            toggle = "cooldowns",
            startsCombat = true,
            

            handler = function ()
                applyBuff( "dire_beast" )
        end,
    },

        widow_venom = {
            id = 82654,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            
            spend = 15,
            spendType = "focus",
            
            startsCombat = true,
            
            handler = function ()
                applyDebuff( "target", "widow_venom" )
            end,
        },



    -- duplicate exhilaration and tranquilizing_shot definitions removed
    } )

    -- Pet Registration
    spec:RegisterPet( "tenacity", 1, "call_pet_1" )
    spec:RegisterPet( "ferocity", 2, "call_pet_2" )
    spec:RegisterPet( "cunning", 3, "call_pet_3" )

    -- Gear Registration
    spec:RegisterGear( "tier16", 99169, 99170, 99171, 99172, 99173 )
    spec:RegisterGear( "tier15", 95307, 95308, 95309, 95310, 95311 )
    spec:RegisterGear( "tier14", 84242, 84243, 84244, 84245, 84246 )

-- Combat log event handlers for Survival mechanics
spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID ~= state.GUID then return end
    
    -- Do NOT allow Auto Shot to proc Thrill of the Hunt (MoP requirement)
    
    -- Lock and Load procs from Auto Shot crits and other ranged abilities
    if subtype == "SPELL_DAMAGE" and ( spellID == 2643 or spellID == 3044 ) then -- Multi-Shot, Arcane Shot (exclude Auto Shot)
        if state.talent.lock_and_load.enabled then
            local crit_chance = math.random()
                            -- 15% chance for Lock and Load to proc on ranged crits in MoP
                if crit_chance <= 0.15 then
                    state.applyBuff( "lock_and_load", 8 )
                end
        end
    end
    
    -- Lock and Load procs from trap activation (important Survival mechanic)
    if subtype == "SPELL_CAST_SUCCESS" and ( spellID == 1499 or spellID == 13813 or spellID == 13809 ) then -- Freezing, Explosive, Ice Trap
        if state.talent.lock_and_load.enabled and math.random() <= 0.25 then -- 25% chance from traps
            state.applyBuff( "lock_and_load", 8 )
        end
    end
end )

    -- State Expressions
    -- In-flight tracking for Steady Shot (prevents focus waste)
    spec:RegisterStateExpr( "in_flight", function()
        -- Check if Steady Shot is currently being cast
        if buff.casting.up and action.steady_shot.lastCast and query_time - action.steady_shot.lastCast < 0.5 then
            return true
        end
        -- For now, simplified check - always return false as projectiles travel fast
        -- Can be enhanced later with actual projectile tracking if needed
        return false
    end )
    
    spec:RegisterStateExpr( "focus_time_to_max", function()
        local regen_rate = 6 * haste
        if buff.aspect_of_the_iron_hawk.up then regen_rate = regen_rate * 1.3 end
        if buff.rapid_fire.up then regen_rate = regen_rate * 1.5 end
        
        return math.max( 0, ( (state.focus.max or 100) - (state.focus.current or 0) ) / regen_rate )
    end )
    spec:RegisterStateExpr("ttd", function()
        if state.is_training_dummy then
            return Hekili.Version:match( "^Dev" ) and settings.dummy_ttd or 300
        end
    
        return state.target.time_to_die
    end)

    spec:RegisterStateExpr( "focus_deficit", function()
        return (state.focus.max or 100) - (state.focus.current or 0)
end )

spec:RegisterStateExpr( "pet_alive", function()
    return pet.alive
end )

spec:RegisterStateExpr( "bloodlust", function()
    return buff.bloodlust
end )

    -- Threat is provided by engine; no spec override

    -- MM variables approximating APL logic.
    -- Refresh Steady Focus when we have 2 stacks and <= 7s remains.
    spec:RegisterVariable( "steady_focus", function()
        -- Emulate: 2 consecutive Steady Shots (steady_focus_pre.stack == 2) and Steady Focus buff needs refresh (<=7s).
        local pre = buff.steady_focus_pre and buff.steady_focus_pre.stack == 2
        local needs = buff.steady_focus and buff.steady_focus.remains <= 7
        return (pre and needs) or false
    end )

    -- Permit Aimed Shot hard-cast during high-focus/burst, or when not starving upcoming Chimera/Crows within 3s.
    spec:RegisterVariable( "aimed", function()
        local focus_now = (state.focus and state.focus.current) or 0
        local rf = buff.rapid_fire and buff.rapid_fire.up
        local cs_in = (cooldown.chimera_shot and cooldown.chimera_shot.remains) or 0
        local crows_in = (cooldown.a_murder_of_crows and cooldown.a_murder_of_crows.remains) or 999
        return (focus_now >= 85) or rf or (cs_in > 3 and crows_in > 3)
    end )

-- === SHOT ROTATION STATE EXPRESSIONS ===

    -- For Survival, Cobra Shot is the primary focus generator and maintains Serpent Sting
    spec:RegisterStateExpr( "should_cobra_shot", function()
        -- Cobra Shot is preferred for Survival when:
        -- 1. We need focus and aren't at cap
        -- 2. We need to maintain Serpent Sting
        -- 3. General focus generation
        
        if (focus.current or 0) > 86 then return false end -- Don't cast if we'll cap focus
        
        -- Always prioritize Cobra Shot for Survival
    return true
end )

    -- Steady Shot is not used in Survival, only as emergency fallback
    spec:RegisterStateExpr( "should_steady_shot", function()
        -- Survival should never use Steady Shot - always use Cobra Shot for focus generation
        return false
    end )
    
    -- Focus management for Explosive Shot priority
spec:RegisterStateExpr( "focus_spender_threshold", function()
        -- Survival focus priorities:
        -- Explosive Shot: 25 focus (highest priority)
        -- Black Arrow: 35 focus
    -- Arcane Shot: 20 focus
    
        -- During Lock and Load, save focus for multiple Explosive Shots
        if buff.lock_and_load.up then return 50 end
    
        -- Normal threshold allows for Explosive Shot priority
    return 75
end )

    -- Determines priority for shot rotation based on buffs and cooldowns
spec:RegisterStateExpr( "optimal_shot_window", function()
        -- Optimal windows for Survival shot rotation:
        -- 1. When Explosive Shot is on cooldown
    -- 2. When we have focus room
        -- 3. When maintaining DoTs
        
        if (focus.current or 0) < 25 then return false end
        if cooldown.explosive_shot.ready then return false end -- Save focus for Explosive Shot
    
    return true
end )



    -- Options
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
    package = "Marksmanship",
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

    spec:RegisterSetting( "mark_any", false, {
        name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

    spec:RegisterSetting( "mm_gate_barrage_on_burst", true, {
        name = "Gate Barrage on Burst Window",
        desc = "Prefer using Barrage during raid burst (e.g., Stormlash) and avoid using it within 3s of Chimera Shot or A Murder of Crows becoming ready.",
        type = "toggle",
        width = "full",
    } )

    spec:RegisterPack( "Marksmanship", 20251026, [[Hekili:TRvBVTjYw4FlrRUwoQjU(100v1rknRRA6vB2ElP3E)KbmmoGcgyhgIBKS43(9mdWWamdGDs2URu)qITHzoZzoZ5558cSC0YBxQzBsqlVz8WXZgnC8zdgpz05JwQrEmeTul006EZ7GV4BUb()VBIVpAJPFKJBi9Mp6fyAtLruqm2cgWsTvXUEKR9xUsQGh(wySHil4YZMUuZX12gLowuK1sTBDCJsmO)zMyKT2jgbRHFBrCd8tm8CJiWTxhGtm(i6Exp3bl1yxKQgbHiFeg(2nSDgY3CLhYE57xQLoFyXryyme9iIR)DPll2nm9EFb9NXOicYgwsSnc)RjgAyTeJlsmU83dUI9LR(Ti2NFaHFGQdVcUKJ7ge28KedIdcurncY0(r4tNaqR0a5tqyxZLAhLyyJwfVE9GsAXG4WLeWGurJlMhX0dg8at9nXu1spyTUfoyB0G8rZ3D1gcvWtAtWreZnHiBuD5LFhQyMsft(nWMHU26RDXirrdJAMc7UJPVDjJbZouigWiKy0lXWkiWZoyR)GOh9ndJq6rHyWgfnatnQGg5fqYLgSCNPCVvx(fkZkVGa4YX4hPY4nTzFwZoRRBDsVoveNlABSs9h0JCOQAjRZBvUupycFaxgomOBu91bwXr6y0AmkYr8aHDxMOb5nAyZ7)isaEJNzKt5TVjgtb1ubufNuBZFNNP7diDsqe3FR8bL4aWPE(9Oauq)bKY8eJrZkwAHbVKUd0qFhzftq6HoMriza3cfQFIbGGY2xfgjMNZUDYUdgTX01huJ3bQX0eJJzQgiexF91EU35quAzh3Xt0jIJdOJ8KnOPk3tnqjOGYscgRYH(gtyVG13KXvtpuSe2OMWEXMVpvdGOJhoQac1nUOSJYPfIztShXLlM9edj6IqpBMnujQ6hLVzdyvMvM4GPN2arlW6R7edQtvdn2Y0h1fSkh8ZoBuDu1awvyhD2Wu0q)s7ZPtkBye9OlGj0rMU2deGddSahkDcmbbeKc6787Wyy9IJiL8KRAruhYRlyu4g57NOMzoEIbqh3PiFLyc4bo7krqNGjNntgmrnDqMqTbLvFfcofRVHlUxZSbzIY7r)VRJJHak1Ke)wDIpqc0vjsSvEGWGTimZvTMO43QziDMGYImwY(3NhzPiwkhI1gGkXOcWRUpyLbdiSJLhQUk)HYuR2ZCOQXRKlycmR7rKr5ZG)Bzy3ktACLjnMnPsyeHSWkJsgvkvZvW5hcFplD9YdRjhF8DiYahKPhXzqOfjf)moJBmlKB9ZcrYQWa2NmEgB0AtiExNyzICHpSa1vx0JK5fKPwUr6ukv2oItyuAwCwhjgyltiSt6p0Pf(Kw(JEAbA5rsAlXFgzoLUFChfCbtBZ0ymbtT1JecPJJ9vk4Ss2ApTMkbB4z8jputJBMvXy47BD9HDuB0E1CKay65d7(c5NLABlKIk8x746uolAjuMDskrGreOI4sHuXs9p0SZLQUhuI3Q973)eVv7TxoBWUM32ivluRX0FrZIwTpF3s6vDS)dll8oubEZjHRolEHe1MoS7(YDlT(3oSRoctuT3jIHhKGLdcPU8ckA(OPFZlgXW4Hy0d63zzpyKyjcmDJFRX1UvlG)3WY5PsV4yD(OOBAFi1wSL1ITTqqghZhG)poXik2Ycff5s)zPEVbfZ4BtxH3aFnBbhW2w5eEY61IKqVDYYiCyD(mbopjXTEbtCSKr8spVGTjgxMYJOXonCmX2Nst)GBmD9PAkWZ)AhWr90S9bT5M(0jaXeWpaeG0dy3aW38XSUG2)kTxFfvtGvERlXHkNjLnWPqjMRx5Gl)muYFjHsOJVZ9WzVYcQA6jfT(Qlv)9ZUb9ZUb983niiaKvWMvMTuNwUwzsFque(zM527f078wgvAmUyiTz2aZfCXMPMWKfizpvcjJOqfkg2MGhkvlPIz0mlg4HaH4iS(eqPD0n9Fm13POQ1vayi)upJAXg8iOU7qr6m2QedWRzOy1UuxfagPB7IyHQebzIZSzwrzmzc1UI(EOxqedWcUHntkY3MPv4hvifEj)PCHsaELIjqkvGxB(C7FmINEOPNyK0Z2RiP)1esRBSJ)DTONdlyH6qFDZAOo4vxoytRCaGP07L948PB(TMyFkoAP21BcdWSNB(BR8K6hK8jkVCWAxAYY)YVKyi(keKy8rgbqIXPWnc(me6FWSbdt(eDGFMIQoDf8pqU4aIjvS)AIX7biheq7IZh(VG5)5JpbYSnn3s4QJhEQW1xK2we46VBC2vt(uYNs1qa)NhV4vZFDDE4tCxp)i1C09oQBHi6YYXNuRRzlre6DuASa5lQiBlDL6xJWF3UYK9h3tbn)8H9QtVFXOzYx4YSZ0LUmD(fZhlFIPeY0juL0wHzL72tpNPErxt1zCCiHpbyyLB2kv8n272E16BBU0)V51tlk9Q9y7eATqZFOyOWeFXkVTWUWxqqLY)EQQiRS3tccP24ty1ZoVV8Y87jVe)EkdJa62XS97pKkr7ITG5XuzZZw3lMF(SD7QNy7UD9BmV5lM0R9A2VyYXhN7dDzmjGzgkc(qpAxZ4fh3bpl(SyoYGgXGtPc)pyDxNMA3FgdE2uQqyFqxRrdPx1kW3gSAcRrLE1NUePnPpx(VBom5Sf49XmPL2H4OuZp9OnIs7IwVgiQ6WwqSnZ0vrMzVwLe5QG0afDAnZsDlLaOsjUq8L2LrP(UlvmVB(4oiNsnhHF295f3S4laAzX)5RlU5QfWz3hKD2XOtE(FZ1kqpPN(uEtXmuzXQuKuRK5wdliq7Q8bZlthYEY6IS2vE)1KmRcFjj3mocIIsqBoH(elNZEUOYDc718twvIOlEgNYLOKPK2XdHTxLMLuFgI0qsTyCMAQuB8nnt2wi9rqZ1)sph86dxivyH9GK0T7Pov7EzmW08jYOz(6x0UnX4BxFZV9hFdacFHAebFzWk(63NZjKxuAbF2arIL6MI(hjR0OmQg5XZMECVJ4zmRCDKFIuvz2F0ufjuKUd)0rAvwDuaLlMOxZH5MpsPuFUDboaLx9KkQSIBZuvp2Z7kxX3JT)a)PHDXFQIwNzBE7W2oJMiGFUbIu(Xl1wiw7eRWRRy5Eycrh2W65JqsArPxpeowCHDintltGPi2JnQY4SSOxhSJDX8vIEewINmq(mLa5Iv5GWxQMEdUjft5fe6iOxhkg4jT1QCKjA8t9r1(Q2TxETGBQqX8mhvnceAgkAqilVS8nRuff9iMagkAcVCLPuowplUqkIfuDHK7oxtD2FqtvrS)URvLqXdeIkH0OPffPpv9e5p(N2tcU2CBjHNEzmLZAqeVuWMAw4dc5085KkWtlRDM2E2qOG0SVpDsBXdsLT8hNZXzDxQCgVhjPSRoIOQJWx8)wC1xVDrbcVOTCu893qSEEqRE)FdM0S(eWxUsfB9scGRUqYbWvhfhc0GgV)y8QIy)X4vLqNX4vN4bGtRkIxkCAnR0bHtB2wRcN2YA)3aCAlaN640Rk6dv)SgrLwFNqgF8Uo9QNCT9IIswH6I3pVwF53TJUONnt(0lEz4fer93EE5tM)(Vlm3AVU8YNANHfYNo)DCxyY1EL4LpvHI7L)kW3RFTI(Fg7aQmvsr3y6ARxulQ8xF99ySJvy14D1rX95VY6QoWOxtzQs7218lOEmXjaVutBt8AS79SNp3Y))]] )
