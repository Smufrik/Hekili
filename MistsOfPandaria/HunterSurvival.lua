    -- HunterSurvival.lua
    -- july 2025 by smufrik

-- Early return if not a Hunter
if select(2, UnitClass('player')) ~= 'HUNTER' then return end

    local addon, ns = ...
local Hekili = _G[ "Hekili" ]
    
-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end
    
local class = Hekili.Class
local state = Hekili.State

local strformat = string.format
    local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
    local PTR = ns.PTR

    local spec = Hekili:NewSpecialization( 255, true )

    -- Lock and Load: implement an internal cooldown (ICD) using local state and expressions.
    -- MoP behavior: LnL primarily procs from Black Arrow ticks and trap triggers; gate with ~10s ICD.
    local lnl_icd_duration = 10
    local lnl_last_proc = 0
    local function lnl_icd_remains(now)
        local t = now or GetTime()
        local rem = (lnl_last_proc + lnl_icd_duration) - t
        return rem > 0 and rem or 0
    end
    local function lnl_icd_ready(now)
        return lnl_icd_remains(now) == 0
    end



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
        
        -- Additional talents
        piercing_shots = { 7, 1, 82924 }, -- Your critical strikes have a chance to apply Piercing Shots, dealing damage over time.
        lock_and_load = { 7, 2, 56453 }, -- Your critical strikes have a chance to reset the cooldown on Aimed Shot.
        careful_aim = { 7, 3, 82926 }, -- After killing a target, your next 2 shots deal increased damage.
    } )

    -- Auras
spec:RegisterAuras( {
        aspect_of_the_hawk = {
            id = 13165,
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
        steady_focus = {
        id = 109259,
        duration = 10,
        max_stack = 1
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
        max_stack = 1,
        debuff = true
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

        careful_aim = {
            id = 82926,
            duration = 20,
            max_stack = 2
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



        silencing_shot = {
            id = 34490,
            duration = 3,
            max_stack = 1
        },

        explosive_shot = {
            id = 53301,
            duration = 2, -- 2 ticks @ 1s in MoP
            tick_time = 1,
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
            debuff = true
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
                -- Cost reduction / stack handling occurs via buff system
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
            cooldown = 24,
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
                
                -- Cobra Shot maintains Serpent Sting
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = debuff.serpent_sting.expires + 6
                    if debuff.serpent_sting.expires > query_time + 15 then
                        debuff.serpent_sting.expires = query_time + 15
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

            spend = 40,
            spendType = "focus",

            startsCombat = true,

            handler = function ()
                -- Apply Multi-Shot buff for tracking
                applyBuff( "multi_shot" )
                
                -- Serpent Spread: spread/maintain Serpent Sting on primary target
                -- Always apply/refresh Serpent Sting when Multi-Shot hits (Improved Serpent Sting / Serpent Spread behavior)
                    applyDebuff( "target", "serpent_sting" )
            end,
        },

        rapid_fire = {
            id = 3045,
            cast = 0,
            cooldown = 300,
            gcd = "off",

            startsCombat = false,
            toggle = "cooldowns",

            -- Extra guard: do not recommend if the Cooldowns toggle is off (Primary/Auto cleanliness).
            usable = function() return state.toggle and state.toggle.cooldowns, "cooldowns off" end,

            handler = function ()
                applyBuff( "rapid_fire" )
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
            texture = 132213,

            handler = function () end,
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
            end,
        },

        stampede = {
            id = 121818,
            cast = 0,
            cooldown = 300,
            gcd = "off",

            startsCombat = true,
            toggle = "cooldowns",

            -- Extra guard: do not recommend if the Cooldowns toggle is off (Primary/Auto cleanliness).
            usable = function() return state.toggle and state.toggle.cooldowns, "cooldowns off" end,

            handler = function ()
                applyBuff( "stampede" )
            end,
        },


        tranquilizing_shot = {
            id = 19801,
            cast = 0,
            cooldown = 8,
            gcd = "spell",

            startsCombat = true,

            toggle = "interrupts",

            usable = function ()
                if buff.dispellable_magic.up or buff.dispellable_enrage.up then return true end
                return false, "requires dispellable (magic/enrage)"
            end,

            handler = function ()
                -- Dispel magic effect
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
            cast = 2.4,
            cooldown = 10,
            gcd = "spell",
            
            spend = 50,
            spendType = "focus",
            
            startsCombat = true,

            handler = function ()
                -- Basic Aimed Shot handling
            end,
        },

        chimera_shot = {
            id = 53209,
            cast = 0,
            cooldown = 9,
            gcd = "spell",

            spend = 35,
            spendType = "focus",

            startsCombat = true,
            texture = 132215,

            handler = function ()
                -- Refresh Serpent Sting if present
                if debuff.serpent_sting.up then
                    debuff.serpent_sting.expires = debuff.serpent_sting.expires + 9
                    if debuff.serpent_sting.expires > query_time + 18 then
                        debuff.serpent_sting.expires = query_time + 18
                    end
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
            cooldown = 0,
            gcd = "spell",
            
            spend = 35,
            spendType = "focus",
            
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

            startsCombat = true,
            toggle = "cooldowns",

            -- Extra guard: do not recommend if the Cooldowns toggle is off (Primary/Auto cleanliness).
            usable = function() return state.toggle and state.toggle.cooldowns, "cooldowns off" end,

            handler = function ()
                applyDebuff( "target", "a_murder_of_crows" )
            end,
        },

        lynx_rush = {
            id = 120697,
            cast = 0,
            cooldown = 90,
            gcd = "spell",

            startsCombat = true,
            toggle = "cooldowns",

            -- Extra guard: do not recommend if the Cooldowns toggle is off (Primary/Auto cleanliness).
            usable = function() return state.toggle and state.toggle.cooldowns, "cooldowns off" end,

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

            startsCombat = true,

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

        careful_aim = {
            id = 82926,
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
            
            startsCombat = false,
            toggle = "defensives",

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
            
            startsCombat = false,
            toggle = "cooldowns",

            -- Extra guard: do not recommend if the Cooldowns toggle is off (Primary/Auto cleanliness).
            usable = function() return state.toggle and state.toggle.cooldowns, "cooldowns off" end,

            handler = function ()
                applyBuff( "fervor" )
            end,
        },

        dire_beast = {
            id = 120679,
            cast = 0,
            cooldown = 45,
            gcd = "spell",
            
            startsCombat = true,
            toggle = "cooldowns",

            -- Extra guard: do not recommend if the Cooldowns toggle is off (Primary/Auto cleanliness).
            usable = function() return state.toggle and state.toggle.cooldowns, "cooldowns off" end,

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

    -- Duplicate ability definitions removed: exhilaration, tranquilizing_shot
    } )

    -- Pet Registration
    spec:RegisterPet( "tenacity", 1, "call_pet_1" )
    spec:RegisterPet( "ferocity", 2, "call_pet_2" )
    spec:RegisterPet( "cunning", 3, "call_pet_3" )

    -- Gear Registration
    spec:RegisterGear( "tier16", 99169, 99170, 99171, 99172, 99173 )
    spec:RegisterGear( "tier15", 95307, 95308, 95309, 95310, 95311 )
    spec:RegisterGear( "tier14", 84242, 84243, 84244, 84245, 84246 )

-- Real Lock and Load aura detection is sufficient; no RNG proc simulation here.

    -- State Expressions
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

    -- Publish Lock and Load ICD helpers for APL/visibility
    spec:RegisterStateExpr( "lock_and_load_icd_remains", function()
        return lnl_icd_remains( state.query_time )
    end )
    spec:RegisterStateExpr( "lock_and_load_icd_up", function()
        return lnl_icd_remains( state.query_time ) > 0
    end )

    -- Threat is managed by the engine; no spec-level override

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

    potion = "virmens_bite_potion",
        package = "Survival",
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

    spec:RegisterSetting( "use_opener", true, {
        name = "Use Opener Sequence",
        desc = "If checked, the 'opener' action list will be used at the start of combat.",
        type = "toggle",
        width = "full"
    } )

    spec:RegisterSetting( "mark_any", false, {
        name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( spec.abilities.hunters_mark.id ) ),
        type = "toggle",
        width = "full"
    } )

    spec:RegisterPack( "Survival", 20250831, [[Hekili:vV12YTnYr0VLTCfgXYAPPU54SRLQIwI2wETeDjsNu5fsoKyijIab4IlswPuHhZhq(eZxs6UNbaZam4cLOxx5H1RiXmD3tp9Lt3n44dgpA8qlwiF81h29Wt6(MJoOd8hhFYbJhg(Wg(4HByZVLTe(dx2A4Fhg5FN9Dmh8bp44XSqce4f5phE44HZISDcV0D8mZufw6g(C4Bpb(Zv2wwCXs5bZhpC0k7G4P4)XINkzB8uVfWNNhA75gp1XoieE8cp)4PFKFRTJDNXdPVeLcgsB6pVMowCx2mhU143bpIiqYsM4Tys4k(KvS7VvWCF7nIf0B4x6F(O4Px176EFO)v9VgOd80qUVnB8WFkE6SOfl6uKmDI2epTv8uyfHmhUByU1y775kwyIufcAHCs5wYidRiJnrBk7uNUgqechp0Bd3L7xLsJ)TnoEb23XNeSYlmNcBWx6FD)BINEZGr9gD5GRJNU37T9dcJNg)4bhgpnGp3Z1kOnSc(VhXdc5w4xc)P7C(VepTFcXJNoeOE80)7)()ep9DoW1F80E((E3l)QEWLsKVf3xysCo8Ka5JEp3)o0KG(WvroH2)ScTggYwVHBbm4La7UJ7)q4kB3LGGgSXh(JG9JN6ZMBZCG)yJxyB5(kizxe5t7duIGmqQnyh2GW8zpuAzUw4FYG)DJV3CKU2RxZTSbhbNhaZwBFUbYsBZI7WGLeecC4vlDyWZFLv06nbQwf0fUdWRjWEMGoF41CLgsZ98CS8U3TJ(LyhFoZ6bYqAH38iqrE2PXtpUBPx6atoQkRvlojCZW7Tjm8AlXqvH(hDsg9vwjs8JlZHDYA6shnENJx55m)g5dNIqV4PZzOnxVR8opEQR39YlgjZXyko0xMyQCVTJd4bbxcrbOf5)mc3oBriAFH0tilWwHVgd9qx6U8VbF8dNFrh1JFIdFErnXvNudPxefxMX7Ix3fvlNuQoxY0f05XmNKplJ87LYH3ImiE6JpsF5o)aijp4j1o7Quio4P611DQ2DsIuvwH9eip)Lsm(wJHsmf07s0N39ZGzVnisxpyKWJhSVUNZqpBBx1arVAi3hcxeIgCqUl45ZSxMDo08X1KBTi9MC8Ftd8jdemFcfBjXRmK5VKh2j0EnFsO3elBqOolE6bNunltvnAefLK)Aj6Waz03CAWsdkplY1c972Z2DUteShiXbBdQMFpf(KIwgcbIVLhg02yOUewkSgqH7GU1hG0h5YemgTIvuIIq5HQAHSVM4szjqxbcDGzr9bx2MaigRitKuIhg4GMCITHeoF89ecl1dhKSJ0pJBkF86CB6WCB6qAt5JdBqMN545bh6i)hse3Sy6jpHOv5bVYOf3hSKUfnmZtR0Nq0kFidby07S9xZDdMmdi8ei1TWfxsb5NXD)0DWV4Yls9Txy7AhScGECraLmpiCFkVa4RZSSm5WxRJDjUOKqV79TRW99G8(VfIjlaLaemOKOXQlWyC4ghCrHse6Mg49(SH3qwalyWvOjOWAghx17YRvb8(LBUCWnxo6FaMmxoCugpMZCCMi(WeSifnLkC5q5jbFBQcMjclAjA8kX0j2lbOQkMPq1SmngWXPD2oOdaIAqF445fYWVcIeF0ltSPqy8)C80rd(s2PUzNx8RbLnC4wBJX0pJeEfrK5XnHdut4oSJbO2ZIOQn2SIfGPn(4LF4J9hos9w5EHlkjbk4r8JCltAlX(urC1E4esgmHxZS)M(P6Ooy5M6MuGs(DmcykEd4TyHnwFs80Lr2yoZEB2GfuqAH1mB3qgc4ifLXWqr9nzGC95l85bRqcod245EZ8zI6pAVtcSyauxJQE8Cc1EHsIWdDInlComxEv8umbPJOEYnmFQkR2LeY94U6bRmfVOkOG3cQYYpa)gPOfY(EcZnHUsu6XmUdwg7HD)tGmZzoHRARhGLuRIN0zZCyxV9uC5Mq4zQ(jtIKEf05uOyPrjcOWiXH0(uJvweHFHvKp5)xI9rDf6vU9c843ufGrM)CMRrJLVIo49OhNw7CqkFXQLt81VNJgh4jkiI8Di3c5cj7Of87tdQvIjZjctM8rUORMAavwpvoJOIjGivbKCo63wUzOIBnCjlfILycfXvPQ6XYZ9phMOL4UErlxLQHiZGcDFayBKJ1efzWe00cRpie9TKcDwvbzFPjSQ65KWiKxWxai9iRu6c8RH2o2Hpicvoy0Obx1SuskXWTsiPrKV6IWXyErQnAqWAMlBjFnzt905Es3kjOhB85Z9wpJze8rQNHwB8MVIZdzRYjOFmYLAHrsBAjj8kpkFD)ZhC176rPg7)LE3qPAgxBthL8rPVJR9qMiq)T27ojcYNzZmByxtlrziBNz19OQEHOMoQMPaOdDjYIA)vlGNrtG2WdNWWiV5mzWV)atWjY29EysVWqQOX1mFelYdI(5id6Advfb4NPMWKf)XcY1TImrcMGBlEkehQBtRAqDNc7we12tTZXcyMzTngHzoQ3nFO)OHTRfbuIZ2Vyaryi7wmel6tXTW2md7)o0PONhWr2mmWbfeMIZTM9n71rRHaES10ahkGgre00iie54kiLRjWNTRhvPbxhdzf0vDVFW5FDO6qki9fD8i1OmndOgPCMQTeV2mMkO9LAipGRRrDpXaHAA7Z2DKj)Z6GxPcScH4Y)gFEuicOL5QlevcIQSUlxUcgp3hNPj)fDLyWg2A0aW2ZNYbTNNlIhxOkDte2CwmcJ6pAVCfAlMTzr2witexm1RTepcHUT2gfwwHjzEOH(Sn50ckEcJGNkboMYzg2pUGqqKHWqTRSApvzuIGuNZ1uIH4ASSsmkhlC5OG)EbRTScikh6MkOnHfKTRbyRKzsMryLiZk05LJnvkrvq1mqHsaVfAUy4NAwHpp48FdUWU(cWPzqp4FF3xVHIO(XEd7xBAHcbPxcSbochbhgFUPG74CJGfSNRx65DUh1zp8BsSwAN0(5C7paLdE2GJOjdgso4IRY8jjEw5dAsuY0KFjHx43HYHLC2L5uqnocAzbUlVAnSfQSqk)QsghJsX(PJVtR4oCmCqs87iVG5SnBiqx1O)YB4(MUJtAUNeSFLwMRSDyIQLYDCUO)77F9Wl)B9LgNFD0LFMa7RQajiSQerRtPAAwmEE1WMZTC1UxkEuqiy7vnQ3Wv(CwyNa7Wiz38Yx4PDGfyyl(uL4vLMhw2ayxhhCbzubIG7(7raUQ)fCfLwvxTdVmWg(FZt2IMUsYn0SqdQT(wmLuOaxU)ba8NRStwQ8iTzqARWyRJpubfS6QnfXVGay7cPkSTkAqKkaAROwbqD1cJ7S(7wHXTYWQYLbAWGpFXG)(1fauwvKwLHYLow99n)wASV0vpBMFI8nQZFhHLUMQHbtRgi(Inqbm2KHwMo9PmVUQ7M(tyq6zJ5(efVYSbCxHd5pKbC3GP6LBOPkj7LZVTcqKQZRr306d0ta4JuPOfV2ldr2oCMtvbCuoyw1XTAu3yEkT6d0wSgWkxSieWHhuKqF3L2UCUiV3shOqu0FicxPaHqTTEwzQQ6S8gMWJuPI2FoH02HRsrIKgDiFfV8flGi)gpY5hYlPx3ZK3LORd03l9tWVRD1aolDaWBpFY0tAtmUS2lNnY8CVhrI3OaJtspFJEZrlZtsV0U4jqmf657ttiwtmgiUX8ZFZAOKW3sVpvPTG1GwqH712J1ElLTtvm18mOAG84zhS(vKbHte2eZkM9EoWzPBsB8UPdMNYDbjtdWpkFtrp41qgwMVl6dbGixVXZN614BI1Flq7e)jGIrHRGiUdHc5x4BFl2hvVf2ycJxavAxwRq)u8NErz9dn(tcUe0jTLSV80xzSJO7BV40FQYgM26NKTkTLOJHnH4yJdlJYY2q26NAwZsBc7s3uT8SMEJIN1YpJzT1K4tAJpnVA1(mIRFVcT68Xh1BZz7wIYRk0GZt72Qy56NDWjsJGQhLFQ0LCceFK6L)(OxWPY3cuqgrY)2doS(TKgnozxND6rsPz7h(E9SJ5XrgjvpYoYCwch3ftuxvgYntDHiyO9aOizU8nHCT9Zeh31UCS4QNkTHHtgWLmL8kT129Z6wvg1BQckKuEIZo94UTQ(TKrv62(bzRkdP9NGmTZ3oH3E6HD1y2oBe1QYGsh8uVP0BSxlPU5OtmDJD6BqXKe0VxJCwvIvAHIY12jDBP7ZcQp1DL166Q20z4Muu57(jeRfbkTbKOmvSRKQUuz9quzTQnGugsCBN9B9ret7eucl2Iz7wp1LJ1vs7g)RJaxSXFGe4d()NFJeO0(d5NjrgqcbhngrSKmonyNvgbTvAKwd0AlJhrAWY(rn8RFN)rnyq8l0obrO9QBIrR6AGrY591M0yIQ7u4JERzAzSTmTebZE7R7(4J7TJKpGyTB)drNa2a74FIbgoggZG86UsK(nWn5zclQug9IkIhTD)8amj0skR5vR38ld7kRteA7lFpiLhj9(wuKAG35eOo517JTn4uQVt6IJP(nvlDsAzrtx4HgJwL02hnbQq3GmSZ0(oOVZ893P4ofTdqK90qtf09gEEVp(BJxqzViS7C)aduuPTMkXwm0n0wL3j0K4jv4OTlt8rxtpRH3se4728BrQVBgHBMEZqHTBdUJxOxV12n526KIMulM0XA3pL26eUCL8yu)KyC9MeJRI)0SZyJe19l)dPBALXSDwV0Kh4sg5CMGKwjdz1Ln1zLygMggDlf7Gt6AMCktygPMYooUKDOojzsaYn65ZuQFvBJfhESIjRY4MnVB9bcRCYnpC5w6dw2mnvNWRcfnni5wvme5el4dpXmBuNJRcBmnU4wvmQyv2ik1)jmpxQ(Z)ahPBMgjfI6UcMLkbFA1siq)R6AOsZV)W)nX1gHBLUg3MzUAMx7w4hsXAlgq6VwCaPMf0NiqAP1(oz6PMfSgIJU1EfnKF8r9zC2Ueo0m82nKdY2oikBQj66IfBu7At6ezzZ4SeVnTXLMIr)ThDsD6LeydnEYMMjynLNKIFrDwNjS(z8gUJ7)73l5UXUk(CEp3vqh5X3sqWn(TzpTJ8FhEH2ZFaAA)1pQao(IVN65PDdXM)d9Lq)PQpoUQ26SvVq5LBsHVW4OuyG3L9YLBQ0BPAUIXqLtc2YE5w2SLErU5W08x678cundCjnh8X53yTJFjBR0BPX4)3d]] )

    -- Pet targeting debug command: /hpetdebug
    SLASH_HEKILIPETDEBUG1 = "/hpetdebug"
    SlashCmdList.HEKILIPETDEBUG = function( msg )
        if not Hekili then
            print( "Hekili not loaded." )
            return
        end

        print( "=== HEKILI PET TARGETING DIAGNOSTICS ===" )

        -- Check if pet-based detection is available for this class
        local canUse = Hekili:CanUsePetBasedTargetDetection()
        print( "Pet detection available for class: " .. tostring(canUse) )

        if canUse then
            -- Check pet status
            local petExists = UnitExists( "pet" )
            local petAlive = not UnitIsDead( "pet" )
            print( "Pet exists: " .. tostring(petExists) )
            print( "Pet alive: " .. tostring(petAlive) )

            if petExists and petAlive then
                -- Check setup status
                local hasSpell = Hekili:HasPetBasedTargetSpell()
                print( "Pet spell configured: " .. tostring(hasSpell) )

                if hasSpell then
                    local status = Hekili:GetPetAbilityDetectionStatus()
                    print( "Detection status: " .. status )

                    -- Check if ready
                    local ready, reason = Hekili:PetBasedTargetDetectionIsReady()
                    print( "Detection ready: " .. tostring(ready) )
                    if not ready then
                        print( "Reason: " .. reason )
                    else
                        print( "Pet-based target detection is working!" )
                    end
                else
                    print( "No pet ability configured. Setup will be attempted automatically." )
                    Hekili:SetupPetBasedTargetDetection()
                    local newStatus = Hekili:GetPetAbilityDetectionStatus()
                    print( "After setup: " .. newStatus )
                end
            else
                if not petExists then
                    print( "ERROR: No pet summoned. Please summon your pet." )
                else
                    print( "ERROR: Pet is dead. Please revive your pet." )
                end
            end
        else
            print( "Pet-based detection not available for Hunters." )
        end

        -- Check nameplate settings
        local nameplatesEnabled = GetCVar( "nameplateShowEnemies" ) == "1"
        print( "Enemy nameplates enabled: " .. tostring(nameplatesEnabled) )

        if not nameplatesEnabled then
            print( "WARNING: Enemy nameplates are disabled. Enable them for better target detection." )
        end

        print( "=== END DIAGNOSTICS ===" )
    end
