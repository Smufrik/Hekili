-- EvokerDevastation.lua
-- January 2025

if UnitClassBase( "player" ) ~= "EVOKER" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local strformat = string.format

local spec = Hekili:NewSpecialization( 1467 )

spec:RegisterResource( Enum.PowerType.Essence )
spec:RegisterResource( Enum.PowerType.Mana )

-- Talents
spec:RegisterTalents( {
    -- Evoker
    aerial_mastery                  = {  93352, 365933, 1 }, -- Hover gains 1 additional charge.
    afterimage                      = {  94929, 431875, 1 }, -- Empower spells send up to 3 Chrono Flames to your targets.
    ancient_flame                   = {  93271, 369990, 1 }, -- Casting Emerald Blossom or Verdant Embrace reduces the cast time of your next Living Flame by 40%.
    attuned_to_the_dream            = {  93292, 376930, 2 }, -- Your healing done and healing received are increased by 3%.
    blast_furnace                   = {  93309, 375510, 1 }, -- Fire Breath's damage over time lasts 4 sec longer.
    bountiful_bloom                 = {  93291, 370886, 1 }, -- Emerald Blossom heals 2 additional allies.
    cauterizing_flame               = {  93294, 374251, 1 }, -- Cauterize an ally's wounds, removing all Bleed, Poison, Curse, and Disease effects. Heals for 65,292 upon removing any effect.
    chrono_flame                    = {  94954, 431442, 1 }, -- Living Flame is enhanced with Bronze magic, repeating 25% of the damage or healing you dealt to the target in the last 5 sec as Arcane, up to 46,638.
    clobbering_sweep                = { 103844, 375443, 1 }, -- Tail Swipe's cooldown is reduced by 2 min.
    doubletime                      = {  94932, 431874, 1 }, -- Ebon Might and Prescience gain a chance equal to your critical strike chance to grant 50% additional stats.
    draconic_legacy                 = {  93300, 376166, 1 }, -- Your Stamina is increased by 8%.
    enkindled                       = {  93295, 375554, 2 }, -- Living Flame deals 3% more damage and healing.
    expunge                         = {  93306, 365585, 1 }, -- Expunge toxins affecting an ally, removing all Poison effects.
    extended_flight                 = {  93349, 375517, 2 }, -- Hover lasts 4 sec longer.
    exuberance                      = {  93299, 375542, 1 }, -- While above 75% health, your movement speed is increased by 10%.
    fire_within                     = {  93345, 375577, 1 }, -- Renewing Blaze's cooldown is reduced by 30 sec.
    foci_of_life                    = {  93345, 375574, 1 }, -- Renewing Blaze restores you more quickly, causing damage you take to be healed back over 4 sec.
    forger_of_mountains             = {  93270, 375528, 1 }, -- Landslide's cooldown is reduced by 30 sec, and it can withstand 200% more damage before breaking.
    golden_opportunity              = {  94942, 432004, 1 }, -- Prescience has a 20% chance to cause your next Prescience to last 100% longer.
    heavy_wingbeats                 = { 103843, 368838, 1 }, -- Wing Buffet's cooldown is reduced by 2 min.
    inherent_resistance             = {  93355, 375544, 2 }, -- Magic damage taken reduced by 4%.
    innate_magic                    = {  93302, 375520, 2 }, -- Essence regenerates 5% faster.
    instability_matrix              = {  94930, 431484, 1 }, -- Each time you cast an empower spell, unstable time magic reduces its cooldown by up to 6 sec.
    instinctive_arcana              = {  93310, 376164, 2 }, -- Your Magic damage done is increased by 2%.
    landslide                       = {  93305, 358385, 1 }, -- Conjure a path of shifting stone towards the target location, rooting enemies for 15 sec. Damage may cancel the effect.
    leaping_flames                  = {  93343, 369939, 1 }, -- Fire Breath causes your next Living Flame to strike 1 additional target per empower level.
    lush_growth                     = {  93347, 375561, 2 }, -- Green spells restore 5% more health.
    master_of_destiny               = {  94930, 431840, 1 }, -- Casting Essence spells extends all your active Threads of Fate by 1 sec.
    motes_of_acceleration           = {  94935, 432008, 1 }, -- Warp leaves a trail of Motes of Acceleration. Allies who come in contact with a mote gain 20% increased movement speed for 30 sec.
    natural_convergence             = {  93312, 369913, 1 }, -- Disintegrate channels 20% faster.
    obsidian_bulwark                = {  93289, 375406, 1 }, -- Obsidian Scales has an additional charge.
    obsidian_scales                 = {  93304, 363916, 1 }, -- Reinforce your scales, reducing damage taken by 30%. Lasts 12 sec.
    oppressing_roar                 = {  93298, 372048, 1 }, -- Let out a bone-shaking roar at enemies in a cone in front of you, increasing the duration of crowd controls that affect them by 50% in the next 10 sec.
    overawe                         = {  93297, 374346, 1 }, -- Oppressing Roar removes 1 Enrage effect from each enemy, and its cooldown is reduced by 30 sec.
    panacea                         = {  93348, 387761, 1 }, -- Emerald Blossom and Verdant Embrace instantly heal you for 35,196 when cast.
    potent_mana                     = {  93715, 418101, 1 }, -- Source of Magic increases the target's healing and damage done by 3%.
    primacy                         = {  94951, 431657, 1 }, -- For each damage over time effect from Upheaval, gain 3% haste, up to 9%.
    protracted_talons               = {  93307, 369909, 1 }, -- Azure Strike damages 1 additional enemy.
    quell                           = {  93311, 351338, 1 }, -- Interrupt an enemy's spellcasting and prevent any spell from that school of magic from being cast for 4 sec.
    recall                          = {  93301, 371806, 1 }, -- You may reactivate Deep Breath within 3 sec after landing to travel back in time to your takeoff location.
    regenerative_magic              = {  93353, 387787, 1 }, -- Your Leech is increased by 4%.
    renewing_blaze                  = {  93354, 374348, 1 }, -- The flames of life surround you for 8 sec. While this effect is active, 100% of damage you take is healed back over 8 sec.
    rescue                          = {  93288, 370665, 1 }, -- Swoop to an ally and fly with them to the target location. Clears movement impairing effects from you and your ally.
    reverberations                  = {  94925, 431615, 1 }, -- Upheaval deals 50% additional damage over 8 sec.
    scarlet_adaptation              = {  93340, 372469, 1 }, -- Store 20% of your effective healing, up to 40,315. Your next damaging Living Flame consumes all stored healing to increase its damage dealt.
    sleep_walk                      = {  93293, 360806, 1 }, -- Disorient an enemy for 20 sec, causing them to sleep walk towards you. Damage has a chance to awaken them.
    source_of_magic                 = {  93344, 369459, 1 }, -- Redirect your excess magic to a friendly healer for 1 |4hour:hrs;. When you cast an empowered spell, you restore 0.25% of their maximum mana per empower level. Limit 1.
    spatial_paradox                 = {  93351, 406732, 1 }, -- Evoke a paradox for you and a friendly healer, allowing casting while moving and increasing the range of most spells by 100% for 10 sec. Affects the nearest healer within 60 yds, if you do not have a healer targeted.
    tailwind                        = {  93290, 375556, 1 }, -- Hover increases your movement speed by 70% for the first 4 sec.
    temporal_burst                  = {  94955, 431695, 1 }, -- Tip the Scales overloads you with temporal energy, increasing your haste, movement speed, and cooldown recovery rate by 30%, decreasing over 30 sec.
    temporality                     = {  94935, 431873, 1 }, -- Warp reduces damage taken by 20%, starting high and reducing over 3 sec.
    terror_of_the_skies             = {  93342, 371032, 1 }, -- Deep Breath stuns enemies for 3 sec.
    threads_of_fate                 = {  94947, 431715, 1 }, -- Casting an empower spell during Temporal Burst causes a nearby ally to gain a Thread of Fate for 10 sec, granting them a chance to echo their damage or healing spells, dealing 15% of the amount again.
    time_convergence                = {  94932, 431984, 1 }, -- Non-defensive abilities with a 45 second or longer cooldown grant 5% Intellect for 15 sec. Essence spells extend the duration by 1 sec.
    time_spiral                     = {  93351, 374968, 1 }, -- Bend time, allowing you and your allies within 40 yds to cast their major movement ability once in the next 10 sec, even if it is on cooldown.
    tip_the_scales                  = {  93350, 370553, 1 }, -- Compress time to make your next empowered spell cast instantly at its maximum empower level.
    twin_guardian                   = {  93287, 370888, 1 }, -- Rescue protects you and your ally from harm, absorbing damage equal to 30% of your maximum health for 5 sec.
    unravel                         = {  93308, 368432, 1 }, -- Sunder an enemy's protective magic, dealing 197,312 Spellfrost damage to absorb shields.
    verdant_embrace                 = {  93341, 360995, 1 }, -- Fly to an ally and heal them for 141,237, or heal yourself for the same amount.
    walloping_blow                  = {  93286, 387341, 1 }, -- Wing Buffet and Tail Swipe knock enemies further and daze them, reducing movement speed by 70% for 4 sec. 
    warp                            = {  94948, 429483, 1 }, -- Hover now causes you to briefly warp out of existence and appear at your destination. Hover's cooldown is also reduced by 5 sec. Hover continues to allow Evoker spells to be cast while moving.
    zephyr                          = {  93346, 374227, 1 }, -- Conjure an updraft to lift you and your 4 nearest allies within 20 yds into the air, reducing damage taken from area-of-effect attacks by 20% and increasing movement speed by 30% for 8 sec.

    -- Devastation
    animosity                       = {  93330, 375797, 1 }, -- Casting an empower spell extends the duration of Dragonrage by 5 sec, up to a maximum of 20 sec.
    arcane_intensity                = {  93274, 375618, 2 }, -- Disintegrate deals 8% more damage.
    arcane_vigor                    = {  93315, 386342, 1 }, -- Casting Shattering Star grants Essence Burst.
    azure_celerity                  = {  93325, 1219723, 1 }, -- Disintegrate ticks 1 additional time, but deals 10% less damage.
    azure_essence_burst             = {  93333, 375721, 1 }, -- Azure Strike has a 15% chance to cause an Essence Burst, making your next Disintegrate or Pyre cost no Essence.
    burnout                         = {  93314, 375801, 1 }, -- Fire Breath damage has 16% chance to cause your next Living Flame to be instant cast, stacking 2 times.
    catalyze                        = {  93280, 386283, 1 }, -- While channeling Disintegrate your Fire Breath on the target deals damage 100% more often.
    causality                       = {  93366, 375777, 1 }, -- Disintegrate reduces the remaining cooldown of your empower spells by 0.50 sec each time it deals damage. Pyre reduces the remaining cooldown of your empower spells by 0.40 sec per enemy struck, up to 2.0 sec.
    charged_blast                   = {  93317, 370455, 1 }, -- Your Blue damage increases the damage of your next Pyre by 5%, stacking 20 times.
    dense_energy                    = {  93284, 370962, 1 }, -- Pyre's Essence cost is reduced by 1.
    dragonrage                      = {  93331, 375087, 1 }, -- Erupt with draconic fury and exhale Pyres at 3 enemies within 25 yds. For 18 sec, Essence Burst's chance to occur is increased to 100%, and you gain the maximum benefit of Mastery: Giantkiller regardless of targets' health.
    engulfing_blaze                 = {  93282, 370837, 1 }, -- Living Flame deals 25% increased damage and healing, but its cast time is increased by 0.3 sec.
    essence_attunement              = {  93319, 375722, 1 }, -- Essence Burst stacks 2 times.
    eternity_surge                  = {  93275, 359073, 1 }, -- Focus your energies to release a salvo of pure magic, dealing 149,519 Spellfrost damage to an enemy. Damages additional enemies within 25 yds when empowered. I: Damages 2 enemies. II: Damages 4 enemies. III: Damages 6 enemies.
    eternitys_span                  = {  93320, 375757, 1 }, -- Eternity Surge and Shattering Star hit twice as many targets.
    event_horizon                   = {  93318, 411164, 1 }, -- Eternity Surge's cooldown is reduced by 3 sec.
    eye_of_infinity                 = {  93318, 411165, 1 }, -- Eternity Surge deals 15% increased damage to your primary target.
    feed_the_flames                 = {  93313, 369846, 1 }, -- After casting 9 Pyres, your next Pyre will explode into a Firestorm. In addition, Pyre and Disintegrate deal 20% increased damage to enemies within your Firestorm.
    firestorm                       = {  93278, 368847, 1 }, -- An explosion bombards the target area with white-hot embers, dealing 55,401 Fire damage to enemies over 6 sec.
    focusing_iris                   = {  93315, 386336, 1 }, -- Shattering Star's damage taken effect lasts 2 sec longer.
    font_of_magic                   = {  93279, 411212, 1 }, -- Your empower spells' maximum level is increased by 1, and they reach maximum empower level 20% faster.
    heat_wave                       = {  93281, 375725, 2 }, -- Fire Breath deals 20% more damage.
    honed_aggression                = {  93329, 371038, 2 }, -- Azure Strike and Living Flame deal 5% more damage.
    imminent_destruction            = {  93326, 370781, 1 }, -- Deep Breath reduces the Essence costs of Disintegrate and Pyre by 1 and increases their damage by 10% for 12 sec after you land.
    imposing_presence               = {  93332, 371016, 1 }, -- Quell's cooldown is reduced by 20 sec.
    inner_radiance                  = {  93332, 386405, 1 }, -- Your Living Flame and Emerald Blossom are 30% more effective on yourself.
    iridescence                     = {  93321, 370867, 1 }, -- Casting an empower spell increases the damage of your next 2 spells of the same color by 20% within 10 sec.
    lay_waste                       = {  93273, 371034, 1 }, -- Deep Breath's damage is increased by 20%.
    onyx_legacy                     = {  93327, 386348, 1 }, -- Deep Breath's cooldown is reduced by 1 min.
    power_nexus                     = {  93276, 369908, 1 }, -- Increases your maximum Essence to 6.
    power_swell                     = {  93322, 370839, 1 }, -- Casting an empower spell increases your Essence regeneration rate by 100% for 4 sec.
    pyre                            = {  93334, 357211, 1 }, -- Lob a ball of flame, dealing 45,820 Fire damage to the target and nearby enemies.
    ruby_embers                     = {  93282, 365937, 1 }, -- Living Flame deals 6,613 damage over 12 sec to enemies, or restores 12,203 health to allies over 12 sec. Stacks 3 times.
    ruby_essence_burst              = {  93285, 376872, 1 }, -- Your Living Flame has a 20% chance to cause an Essence Burst, making your next Disintegrate or Pyre cost no Essence.
    scintillation                   = {  93324, 370821, 1 }, -- Disintegrate has a 15% chance each time it deals damage to launch a level 1 Eternity Surge at 50% power.
    scorching_embers                = {  93365, 370819, 1 }, -- Fire Breath causes enemies to take up to 40% increased damage from your Red spells, increased based on its empower level.
    shattering_star                 = {  93316, 370452, 1 }, -- Exhale bolts of concentrated power from your mouth at 2 enemies for 50,547 Spellfrost damage that cracks the targets' defenses, increasing the damage they take from you by 20% for 4 sec. Grants Essence Burst.
    snapfire                        = {  93277, 370783, 1 }, -- Pyre and Living Flame have a 15% chance to cause your next Firestorm to be instantly cast without triggering its cooldown, and deal 100% increased damage.
    spellweavers_dominance          = {  93323, 370845, 1 }, -- Your damaging critical strikes deal 230% damage instead of the usual 200%.
    titanic_wrath                   = {  93272, 386272, 1 }, -- Essence Burst increases the damage of affected spells by 15.0%.
    tyranny                         = {  93328, 376888, 1 }, -- During Deep Breath and Dragonrage you gain the maximum benefit of Mastery: Giantkiller regardless of targets' health.
    volatility                      = {  93283, 369089, 2 }, -- Pyre has a 15% chance to flare up and explode again on a nearby target.

    -- Scalecommander
    bombardments                    = {  94936, 434300, 1 }, -- Mass Disintegrate marks your primary target for destruction for the next 6 sec. You and your allies have a chance to trigger a Bombardment when attacking marked targets, dealing 73,725 Volcanic damage split amongst all nearby enemies.
    diverted_power                  = {  94928, 441219, 1 }, -- Bombardments have a chance to generate Essence Burst.
    extended_battle                 = {  94928, 441212, 1 }, -- Essence abilities extend Bombardments by 1 sec.
    hardened_scales                 = {  94933, 441180, 1 }, -- Obsidian Scales reduces damage taken by an additional 10%.
    maneuverability                 = {  94941, 433871, 1 }, -- Deep Breath can now be steered in your desired direction. In addition, Deep Breath burns targets for 174,419 Volcanic damage over 12 sec.
    mass_disintegrate               = {  94939, 436335, 1, "scalecommander" }, -- Empower spells cause your next Disintegrate to strike up to $s1 targets. When striking fewer than $s1 targets, Disintegrate damage is increased by $s2% for each missing target.
    melt_armor                      = {  94921, 441176, 1 }, -- Deep Breath causes enemies to take 20% increased damage from Bombardments and Essence abilities for 12 sec.
    menacing_presence               = {  94933, 441181, 1 }, -- Knocking enemies up or backwards reduces their damage done to you by 15% for 8 sec.
    might_of_the_black_dragonflight = {  94952, 441705, 1 }, -- Black spells deal 20% increased damage.
    nimble_flyer                    = {  94943, 441253, 1 }, -- While Hovering, damage taken from area of effect attacks is reduced by 10%.
    onslaught                       = {  94944, 441245, 1 }, -- Entering combat grants a charge of Burnout, causing your next Living Flame to cast instantly.
    slipstream                      = {  94943, 441257, 1 }, -- Deep Breath resets the cooldown of Hover.
    unrelenting_siege               = {  94934, 441246, 1 }, -- For each second you are in combat, Azure Strike, Living Flame, and Disintegrate deal 1% increased damage, up to 15%.
    wingleader                      = {  94953, 441206, 1 }, -- Bombardments reduce the cooldown of Deep Breath by 1 sec for each target struck, up to 3 sec.

    -- Flameshaper
    burning_adrenaline              = {  94946, 444020, 1 }, -- Engulf quickens your pulse, reducing the cast time of your next spell by 30%. Stacks up to 2 charges.
    conduit_of_flame                = {  94949, 444843, 1 }, -- Critical strike chance against targets above 50% health increased by 15%.
    consume_flame                   = {  94922, 444088, 1 }, -- Engulf consumes 2 sec of Fire Breath from the target, detonating it and damaging all nearby targets equal to 750% of the amount consumed, reduced beyond 5 targets.
    draconic_instincts              = {  94931, 445958, 1 }, -- Your wounds have a small chance to cauterize, healing you for 30% of damage taken. Occurs more often from attacks that deal high damage.
    engulf                          = {  94950, 443328, 1, "flameshaper" }, -- Engulf your target in dragonflame, damaging them for $443329s1 Fire or healing them for $443330s1. For each of your periodic effects on the target, effectiveness is increased by $s1%.
    enkindle                        = {  94956, 444016, 1 }, -- Essence abilities are enhanced with Flame, dealing 20% of healing or damage done as Fire over 8 sec.
    expanded_lungs                  = {  94956, 444845, 1 }, -- Fire Breath's damage over time is increased by 30%. Dream Breath's heal over time is increased by 30%.
    flame_siphon                    = {  99857, 444140, 1 }, -- Engulf reduces the cooldown of Fire Breath by 6 sec.
    fulminous_roar                  = {  94923, 1218447, 1 }, -- Fire Breath deals its damage in 20% less time.
    lifecinders                     = {  94931, 444322, 1 }, -- Renewing Blaze also applies to your target or 1 nearby injured ally at 50% value.
    red_hot                         = {  94945, 444081, 1 }, -- Engulf gains 1 additional charge and deals 20% increased damage and healing.
    shape_of_flame                  = {  94937, 445074, 1 }, -- Tail Swipe and Wing Buffet scorch enemies and blind them with ash, causing their next attack within 4 sec to miss.
    titanic_precision               = {  94920, 445625, 1 }, -- Living Flame and Azure Strike have 1 extra chance to trigger Essence Burst when they critically strike.
    trailblazer                     = {  94937, 444849, 1 }, -- Hover and Deep Breath travel 40% faster, and Hover travels 40% further.
} )

-- PvP Talents
spec:RegisterPvpTalents( { 
    chrono_loop          = 5456, -- (383005) Trap the enemy in a time loop for 5 sec. Afterwards, they are returned to their previous location and health. Cannot reduce an enemy's health below 20%.
    divide_and_conquer   = 5556, -- (384689) 
    dreamwalkers_embrace = 5617, -- (415651) 
    nullifying_shroud    = 5467, -- (378464) Wreathe yourself in arcane energy, preventing the next 3 full loss of control effects against you. Lasts 30 sec.
    obsidian_mettle      = 5460, -- (378444) 
    scouring_flame       = 5462, -- (378438) 
    swoop_up             = 5466, -- (370388) Grab an enemy and fly with them to the target location.
    time_stop            = 5464, -- (378441) Freeze an ally's timestream for 5 sec. While frozen in time they are invulnerable, cannot act, and auras do not progress. You may reactivate Time Stop to end this effect early.
    unburdened_flight    = 5469, -- (378437) Hover makes you immune to movement speed reduction effects.
} )

-- Support 'in_firestorm' virtual debuff.
local firestorm_enemies = {}
local firestorm_last = 0
local firestorm_cast = 368847
local firestorm_tick = 369374

local eb_col_casts = 0
local animosityExtension = 0 -- Maintained by CLEU

spec:RegisterCombatLogEvent( function( _, subtype, _,  sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID == state.GUID then
        if subtype == "SPELL_CAST_SUCCESS" then
            if spellID == firestorm_cast then
                wipe( firestorm_enemies )
                firestorm_last = GetTime()
                return
            elseif spellID == spec.abilities.emerald_blossom.id then
                eb_col_casts = ( eb_col_casts + 1 ) % 3
                return
            elseif spellID == 375087 then  -- Dragonrage
                animosityExtension = 0
                return
            end

            if state.talent.animosity.enabled and animosityExtension < 4 then
                -- Empowered spell casts increment this extension tracker by 1
                for _, ability in pairs( class.abilities ) do
                    if ability.empowered and spellID == ability.id then
                        animosityExtension = animosityExtension + 1
                        break
                    end
                end
            end
        end

        if subtype == "SPELL_DAMAGE" and spellID == firestorm_tick then
            local n = firestorm_enemies[ destGUID ]

            if n then
                firestorm_enemies[ destGUID ] = n + 1
                return
            else
                firestorm_enemies[ destGUID ] = 1
            end
            return
        end
    end
end )

spec:RegisterStateExpr( "cycle_of_life_count", function()
    return eb_col_cast
end )

-- Auras
spec:RegisterAuras( {
    -- Talent: The cast time of your next Living Flame is reduced by $w1%.
    -- https://wowhead.com/beta/spell=375583
    ancient_flame = {
        id = 375583,
        duration = 3600,
        max_stack = 1
    },
    -- Damage taken has a chance to summon air support from the Dracthyr.
    bombardments = {
        id = 434473,
        duration = 6.0,
        pandemic = true,
        max_stack = 1
    },
    -- Next spell cast time reduced by $s1%.
    burning_adrenaline = {
        id = 444019,
        duration = 15.0,
        max_stack = 2
    },
    -- Talent: Next Living Flame's cast time is reduced by $w1%.
    -- https://wowhead.com/beta/spell=375802
    burnout = {
        id = 375802,
        duration = 15,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Your next Pyre deals $s1% more damage.
    -- https://wowhead.com/beta/spell=370454
    charged_blast = {
        id = 370454,
        duration = 30,
        max_stack = 20
    },
    chrono_loop = {
        id = 383005,
        duration = 5,
        max_stack = 1
    },
    cycle_of_life = {
        id = 371877,
        duration = 15,
        max_stack = 1
    },
    --[[ Suffering $w1 Volcanic damage every $t1 sec.
    -- https://wowhead.com/beta/spell=353759
    deep_breath = {
        id = 353759,
        duration = 1,
        tick_time = 0.5,
        type = "Magic",
        max_stack = 1
    }, -- TODO: Effect of impact on target. ]]
    -- Spewing molten cinders. Immune to crowd control.
    -- https://wowhead.com/beta/spell=357210
    deep_breath = {
        id = 357210,
        duration = 6,
        type = "Magic",
        max_stack = 1
    },
    -- Suffering $w1 Spellfrost damage every $t1 sec.
    -- https://wowhead.com/beta/spell=356995
    disintegrate = {
        id = 356995,
        duration = function () return 3 * ( talent.natural_convergence.enabled and 0.8 or 1 ) * ( buff.burning_adrenaline.up and 0.7 or 1 ) end,
        tick_time = function () return spec.auras.disintegrate.duration / ( 4 + talent.azure_celerity.rank ) end,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Essence Burst has a $s2% chance to occur.$?s376888[    Your spells gain the maximum benefit of Mastery: Giantkiller regardless of targets' health.][]
    -- https://wowhead.com/beta/spell=375087
    dragonrage = {
        id = 375087,
        duration = 18,
        max_stack = 1
    },
    -- Releasing healing breath. Immune to crowd control.
    -- https://wowhead.com/beta/spell=359816
    dream_flight = {
        id = 359816,
        duration = 6,
        type = "Magic",
        max_stack = 1
    },
    -- Healing for $w1 every $t1 sec.
    -- https://wowhead.com/beta/spell=363502
    dream_flight_hot = {
        id = 363502,
        duration = 15,
        type = "Magic",
        max_stack = 1,
        dot = "buff"
    },
    -- When $@auracaster casts a non-Echo healing spell, $w2% of the healing will be replicated.
    -- https://wowhead.com/beta/spell=364343
    echo = {
        id = 364343,
        duration = 15,
        max_stack = 1
    },
    -- Healing and restoring mana.
    -- https://wowhead.com/beta/spell=370960
    emerald_communion = {
        id = 370960,
        duration = 5,
        max_stack = 1
    },
    enkindle = {
        id = 444017,
        duration = 8,
        type = "Magic",
        tick_time = 2,
        max_stack = 1
    },
    -- Your next Disintegrate or Pyre costs no Essence.
    -- https://wowhead.com/beta/spell=359618
    essence_burst = {
        id = 359618,
        duration = 15,
        max_stack = function() return talent.essence_attunement.enabled and 2 or 1 end
    },
    eternity_surge_x3 = { -- TODO: This is the channel with 3 ranks.
        id = 359073,
        duration = 2.5,
        max_stack = 1
    },
    eternity_surge_x4 = { -- TODO: This is the channel with 4 ranks.
        id = 382411,
        duration = 3.25,
        max_stack = 1
    },
    eternity_surge = {
        alias = { "eternity_surge_x4", "eternity_surge_x3" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3.25
    },
    feed_the_flames_stacking = {
        id = 405874,
        duration = 120,
        max_stack = 9
    },
    feed_the_flames_pyre = {
        id = 411288,
        duration = 60,
        max_stack = 1
    },
    fire_breath = {
        id = 357209,
        duration = function ()
            local base = 26 + 4 * talent.blast_furnace.rank
            base = base - 6 * empowerment_level
            return base * ( talent.fulminous_roar.enabled and 0.8 or 1 )
        end,
        -- TODO: damage = function () return 0.322 * stat.spell_power * action.fire_breath.spell_targets * ( talent.heat_wave.enabled and 1.2 or 1 ) * ( debuff.shattering_star.up and 1.2 or 1 ) end,
        type = "Magic",
        max_stack = 1,
        copy = "fire_breath_damage"
    },
    firestorm = { -- TODO: Check for totem?
        id = 369372,
        duration = 6,
        max_stack = 1
    },
    -- Increases the damage of Fire Breath by $s1%.
    -- https://wowhead.com/beta/spell=377087
    full_belly = {
        id = 377087,
        duration = 600,
        type = "Magic",
        max_stack = 1
    },
    -- Movement speed increased by $w2%.$?e0[ Area damage taken reduced by $s1%.][]; Evoker spells may be cast while moving. Does not affect empowered spells.$?e9[; Immune to movement speed reduction effects.][]
    hover = {
        id = 358267,
        duration = function () return talent.extended_flight.enabled and 10 or 6 end,
        tick_time = 1,
        max_stack = 1
    },
    -- Essence costs of Disintegrate and Pyre are reduced by $s1, and their damage increased by $s2%.
    imminent_destruction = {
        id = 411055,
        duration = 12,
        max_stack = 1
    },
    in_firestorm = {
        duration = 6,
        max_stack = 1,
        generate = function( t )
            t.name = class.auras.firestorm.name

            if firestorm_last + 6 > query_time and firestorm_enemies[ target.unit ] then
                t.applied = firestorm_last
                t.duration = 6
                t.expires = firestorm_last + 6
                t.count = 1
                t.caster = "player"
                return
            end

            t.applied = 0
            t.duration = 0
            t.expires = 0
            t.count = 0
            t.caster = "nobody"
        end
    },
    -- Your next Blue spell deals $s1% more damage.
    -- https://wowhead.com/beta/spell=386399
    iridescence_blue = {
        id = 386399,
        duration = 10,
        max_stack = 2
    },
    -- Your next Red spell deals $s1% more damage.
    -- https://wowhead.com/beta/spell=386353
    iridescence_red = {
        id = 386353,
        duration = 10,
        max_stack = 2
    },
    -- Talent: Rooted.
    -- https://wowhead.com/beta/spell=355689
    landslide = {
        id = 355689,
        duration = 15,
        mechanic = "root",
        type = "Magic",
        max_stack = 1
    },
    leaping_flames = {
        id = 370901,
        duration = 30,
        max_stack = function() return max_empower end
    },
    -- Sharing $s1% of healing to an ally.
    -- https://wowhead.com/beta/spell=373267
    lifebind = {
        id = 373267,
        duration = 5,
        max_stack = 1
    },
    -- Burning for $w2 Fire damage every $t2 sec.
    -- https://wowhead.com/beta/spell=361500
    living_flame = {
        id = 361500,
        duration = 12,
        type = "Magic",
        max_stack = 3,
        copy = { "living_flame_dot", "living_flame_damage" }
    },
    -- Healing for $w2 every $t2 sec.
    -- https://wowhead.com/beta/spell=361509
    living_flame_hot = {
        id = 361509,
        duration = 12,
        type = "Magic",
        max_stack = 3,
        dot = "buff",
        copy = "living_flame_heal"
    },
    --
    -- https://wowhead.com/beta/spell=362980
    mastery_giantkiller = {
        id = 362980,
        duration = 3600,
        max_stack = 1
    },
    -- $?e0[Suffering $w1 Volcanic damage every $t1 sec.][]$?e1[ Damage taken from Essence abilities and bombardments increased by $s2%.][]
    melt_armor = {
        id = 441172,
        duration = 12.0,
        tick_time = 2.0,
        max_stack = 1
    },
    -- Damage done to $@auracaster reduced by $s1%.
    menacing_presence = {
        id = 441201,
        duration = 8.0,
        max_stack = 1
    },
    -- Talent: Armor increased by $w1%. Magic damage taken reduced by $w2%.$?$w3=1[  Immune to interrupt and silence effects.][]
    -- https://wowhead.com/beta/spell=363916
    obsidian_scales = {
        id = 363916,
        duration = 12,
        max_stack = 1
    },
    -- Talent: The duration of incoming crowd control effects are increased by $s2%.
    -- https://wowhead.com/beta/spell=372048
    oppressing_roar = {
        id = 372048,
        duration = 10,
        max_stack = 1
    },
    -- Talent: Movement speed reduced by $w1%.
    -- https://wowhead.com/beta/spell=370898
    permeating_chill = {
        id = 370898,
        duration = 3,
        mechanic = "snare",
        max_stack = 1
    },
    power_swell = {
        id = 376850,
        duration = 4,
        max_stack = 1
    },
    -- Talent: $w1% of damage taken is being healed over time.
    -- https://wowhead.com/beta/spell=374348
    renewing_blaze = {
        id = 374348,
        duration = function() return talent.foci_of_life.enabled and 4 or 8 end,
        max_stack = 1
    },
    -- Talent: Restoring $w1 health every $t1 sec.
    -- https://wowhead.com/beta/spell=374349
    renewing_blaze_heal = {
        id = 374349,
        duration = function() return talent.foci_of_life.enabled and 4 or 8 end,
        max_stack = 1
    },
    recall = {
        id = 371807,
        duration = 10,
        max_stack = function () return talent.essence_attunement.enabled and 2 or 1 end
    },
    -- Talent: About to be picked up!
    -- https://wowhead.com/beta/spell=370665
    rescue = {
        id = 370665,
        duration = 1,
        max_stack = 1
    },
    -- Next attack will miss.
    shape_of_flame = {
        id = 445134,
        duration = 4.0,
        max_stack = 1
    },
    -- Healing for $w1 every $t1 sec.
    -- https://wowhead.com/beta/spell=366155
    reversion = {
        id = 366155,
        duration = 12,
        max_stack = 1
    },
    scarlet_adaptation = {
        id = 372470,
        duration = 3600,
        max_stack = 1
    },
    -- Talent: Taking $w3% increased damage from $@auracaster.
    -- https://wowhead.com/beta/spell=370452
    shattering_star = {
        id = 370452,
        duration = function () return talent.focusing_iris.enabled and 6 or 4 end,
        type = "Magic",
        max_stack = 1,
        copy = "shattering_star_debuff"
    },
    -- Talent: Asleep.
    -- https://wowhead.com/beta/spell=360806
    sleep_walk = {
        id = 360806,
        duration = 20,
        mechanic = "sleep",
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Your next Firestorm is instant cast and deals $s2% increased damage.
    -- https://wowhead.com/beta/spell=370818
    snapfire = {
        id = 370818,
        duration = 10,
        max_stack = 1
    },
    -- Talent: $@auracaster is restoring mana to you when they cast an empowered spell.
    -- https://wowhead.com/beta/spell=369459
    source_of_magic = {
        id = 369459,
        duration = 3600,
        max_stack = 1,
        dot = "buff",
        friendly = true
    },
    -- Able to cast spells while moving and spell range increased by $s4%.
    spatial_paradox = {
        id = 406732,
        duration = 10.0,
        tick_time = 1.0,
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=370845
    spellweavers_dominance = {
        id = 370845,
        duration = 3600,
        max_stack = 1
    },
    -- Movement speed reduced by $s2%.
    -- https://wowhead.com/beta/spell=368970
    tail_swipe = {
        id = 368970,
        duration = 4,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Stunned.
    -- https://wowhead.com/beta/spell=372245
    terror_of_the_skies = {
        id = 372245,
        duration = 3,
        mechanic = "stun",
        max_stack = 1
    },
    -- Talent: May use Death's Advance once, without incurring its cooldown.
    -- https://wowhead.com/beta/spell=375226
    time_spiral = {
        id = 375226,
        duration = 10,
        max_stack = 1
    },
    time_stop = {
        id = 378441,
        duration = 5,
        max_stack = 1
    },
    -- Talent: Your next empowered spell casts instantly at its maximum empower level.
    -- https://wowhead.com/beta/spell=370553
    tip_the_scales = {
        id = 370553,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Absorbing $w1 damage.
    -- https://wowhead.com/beta/spell=370889
    twin_guardian = {
        id = 370889,
        duration = 5,
        max_stack = 1
    },
    -- Movement speed reduced by $s2%.
    -- https://wowhead.com/beta/spell=357214
    wing_buffet = {
        id = 357214,
        duration = 4,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Damage taken from area-of-effect attacks reduced by $w1%.  Movement speed increased by $w2%.
    -- https://wowhead.com/beta/spell=374227
    zephyr = {
        id = 374227,
        duration = 8,
        max_stack = 1
    }
} )

local lastEssenceTick = 0

do
    local previous = 0

    spec:RegisterUnitEvent( "UNIT_POWER_UPDATE", "player", nil, function( event, unit, power )
        if power == "ESSENCE" then
            local value, cap = UnitPower( "player", Enum.PowerType.Essence ), UnitPowerMax( "player", Enum.PowerType.Essence )

            if value == cap then
                lastEssenceTick = 0

            elseif lastEssenceTick == 0 and value < cap or lastEssenceTick ~= 0 and value > previous then
                lastEssenceTick = GetTime()
            end

            previous = value
        end
    end )
end

spec:RegisterStateExpr( "empowerment_level", function()
    return buff.tip_the_scales.down and args.empower_to or max_empower
end )

-- This deserves a better fix; when args.empower_to = "maximum" this will cause that value to become max_empower (i.e., 3 or 4).
spec:RegisterStateExpr( "maximum", function()
    return max_empower
end )

spec:RegisterStateExpr( "animosity_extension", function() return animosityExtension end )

spec:RegisterHook( "runHandler", function( action )
    local ability = class.abilities[ action ]
    local color = ability.color

    if color == "blue" then

        if buff.iridescence_blue.up then removeStack( "iridescence_blue" ) end
        if talent.charged_blast.enabled then
            addStack( "charged_blast", nil, ( min( active_enemies, ability.spell_targets ) ) )
        end

    elseif color == "red" then

       if buff.iridescence_red.up then removeStack( "iridescence_red" ) end

    else
        -- Other colors?
    end

    if ability.empowered then
        if talent.power_swell.enabled then applyBuff( "power_swell" ) end -- TODO: Modify Essence regen rate.
        if talent.animosity.enabled and animosity_extension < 4 then
            animosity_extension = animosity_extension + 1
            buff.dragonrage.expires = buff.dragonrage.expires + 5
        end
        if talent.iridescence.enabled and color then
                local iridescenceBuffType = "iridescence_" .. color -- Constructs "iridescence_red", "iridescence_blue", etc.
                applyBuff( iridescenceBuffType, nil, 2 ) -- Apply the dynamically determined buff with 2 stacks.
        end
        if talent.mass_disintegrate.enabled then
            addStack( "mass_disintegrate_stacks" )
        end
        if buff.tip_the_scales.up then
            removeBuff( "tip_the_scales" )
            setCooldown( "tip_the_scales", spec.abilities.tip_the_scales.cooldown )
        end
        removeBuff( "jackpot" )
    end

    if ability.spendType == "essence" then
        removeStack( "essence_burst" )
        if talent.enkindle.enabled then
            applyDebuff( "target", "enkindle" )
        end
        if talent.extended_battle.enabled then
            if debuff.bombardments.up then debuff.bombardments.expires = debuff.bombardments.expires + 1 end
        end
    end

    empowerment.active = false
end )

spec:RegisterGear({
    -- The War Within
    tww2 = {
        items = { 229283, 229281, 229279, 229280, 229278 },
        auras = {
            jackpot = {
                id = 1217769,
                duration = 40,
                max_stack = 2
            }
        }
    },
    -- Dragonflight
    tier31 = {
        items = { 207225, 207226, 207227, 207228, 207230 },
        auras = {
            emerald_trance = {
                id = 424155,
                duration = 10,
                max_stack = 5,
                copy = { "emerald_trance_stacking", 424402 }
            }
        }
    },
    tier30 = {
        items = { 202491, 202489, 202488, 202487, 202486, 217178, 217180, 217176, 217177, 217179 },
        auras = {
            obsidian_shards = {
                id = 409776,
                duration = 8,
                tick_time = 2,
                max_stack = 1
            },
            blazing_shards = {
                id = 409848,
                duration = 5,
                max_stack = 1
            }
        }
    },
    tier29 = {
        items = { 200381, 200383, 200378, 200380, 200382 },
        auras = {
            limitless_potential = {
                id = 394402,
                duration = 6,
                max_stack = 1
            }
        }
    }
})

local EmeraldTranceTick = setfenv( function()
    addStack( "emerald_trance" )
end, state )

local EmeraldBurstTick = setfenv( function()
    addStack( "essence_burst" )
end, state )

local ExpireDragonrage = setfenv( function()
    buff.emerald_trance.expires = query_time + 5 * buff.emerald_trance.stack
    for i = 1, buff.emerald_trance.stack do
        state:QueueAuraEvent( "emerald_trance", EmeraldBurstTick, query_time + i * 5, "AURA_PERIODIC" )
    end
end, state )

local QueueEmeraldTrance = setfenv( function()
    local tick = buff.dragonrage.applied + 6
    while( tick < buff.dragonrage.expires ) do
        if tick > query_time then state:QueueAuraEvent( "dragonrage", EmeraldTranceTick, tick, "AURA_PERIODIC" ) end
        tick = tick + 6
    end
    if set_bonus.tier31_4pc > 0 then
        state:QueueAuraExpiration( "dragonrage", ExpireDragonrage, buff.dragonrage.expires )
    end
end, state )

spec:RegisterHook( "reset_precast", function()
    animosity_extension = nil
    cycle_of_life_count = nil

    max_empower = talent.font_of_magic.enabled and 4 or 3

    if essence.current < essence.max and lastEssenceTick > 0 then
        local partial = min( 0.99, ( query_time - lastEssenceTick ) * essence.regen )
        gain( partial, "essence" )
        if Hekili.ActiveDebug then Hekili:Debug( "Essence increased to %.2f from passive regen.", partial ) end
    end

    if buff.dragonrage.up and set_bonus.tier31_2pc > 0 then
        QueueEmeraldTrance()
    end
end )

spec:RegisterStateTable( "evoker", setmetatable( {},{
    __index = function( t, k )
        if k == "use_early_chaining" then k = "use_early_chain" end
        local val = state.settings[ k ]
        if val ~= nil then return val end
        return false
    end
} ) )

local empowered_cast_time

do
    local stages = {
        1,
        1.75,
        2.5,
        3.25
    }

    empowered_cast_time = setfenv( function()
        if buff.tip_the_scales.up then return 0 end
        local power_level = args.empower_to or max_empower

        if settings.fire_breath_fixed > 0 then
            power_level = min( settings.fire_breath_fixed, max_empower )
        end

        return stages[ power_level ] * ( talent.font_of_magic.enabled and 0.8 or 1 ) * ( buff.burning_adrenaline.up and 0.7 or 1 ) * haste
    end, state )
end
-- Support SimC expression release.dot_duration
spec:RegisterStateTable( "release", setmetatable( {},{
    __index = function( t, k )
        if k == "dot_duration" then
            return spec.auras.fire_breath.duration
        else return 0 end

    end
} ) )

-- Abilities
spec:RegisterAbilities( {
    -- Project intense energy onto 3 enemies, dealing 1,161 Spellfrost damage to them.
    azure_strike = {
        id = 362969,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "spellfrost",
        color = "blue",

        -- spend = 0.009,
        -- spendType = "mana",

        startsCombat = true,

        minRange = 0,
        maxRange = 25,

        damage = function () return stat.spell_power * 0.755 * ( debuff.shattering_star.up and 1.2 or 1 ) end, -- PvP multiplier = 1.
        critical = function() return stat.crit + conduit.spark_of_savagery.mod end,
        critical_damage = function () return talent.tyranny.enabled and 2.2 or 2 end,
        spell_targets = function() return talent.protracted_talons.enabled and 3 or 2 end,

        handler = function ()
            -- Many Color, Essence and Empower interactions have been moved to the runHandler hook
            if talent.azure_essence_burst.enabled and buff.dragonrage.up then addStack( "essence_burst", nil, 1 ) end
            if talent.charged_blast.enabled then addStack( "charged_blast", nil, min( active_enemies, spell_targets.azure_strike ) ) end
        end
    },

    -- Weave the threads of time, reducing the cooldown of a major movement ability for all party and raid members by 15% for 1 |4hour:hrs;.
    blessing_of_the_bronze = {
        id = 364342,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "arcane",
        color = "bronze",

        spend = 0.01,
        spendType = "mana",

        startsCombat = false,
        nobuff = "blessing_of_the_bronze",

        handler = function ()
            applyBuff( "blessing_of_the_bronze" )
            applyBuff( "blessing_of_the_bronze_evoker")
        end
    },

    -- Talent: Cauterize an ally's wounds, removing all Bleed, Poison, Curse, and Disease effects. Heals for 4,480 upon removing any effect.
    cauterizing_flame = {
        id = 374251,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "fire",
        color = "red",

        spend = 0.014,
        spendType = "mana",

        talent = "cauterizing_flame",
        startsCombat = true,

        healing = function () return 3.50 * stat.spell_power end,

        usable = function()
            return buff.dispellable_poison.up or buff.dispellable_curse.up or buff.dispellable_disease.up, "requires dispellable effect"
        end,

        handler = function ()
            removeBuff( "dispellable_poison" )
            removeBuff( "dispellable_curse" )
            removeBuff( "dispellable_disease" )
            health.current = min( health.max, health.current + action.cauterizing_flame.healing )
            if talent.everburning_flame.enabled and debuff.fire_breath.up then debuff.fire_breath.expires = debuff.fire_breath.expires + 1 end
        end
    },

    -- Take in a deep breath and fly to the targeted location, spewing molten cinders dealing 6,375 Volcanic damage to enemies in your path. Removes all root effects. You are immune to movement impairing and loss of control effects while flying.
    deep_breath = {
        id = function ()
            if buff.recall.up then return 371807 end
            if talent.maneuverability.enabled then return 433874 end
            return 357210
        end,
        cast = 0,
        cooldown = function ()
            return talent.onyx_legacy.enabled and 60 or 120
        end,
        gcd = "spell",
        school = "firestorm",
        color = "black",

        startsCombat = true,
        texture = 4622450,
        toggle = "cooldowns",
        notalent = "breath_of_eons",

        min_range = 20,
        max_range = 50,

        damage = function () return 2.30 * stat.spell_power end,

        usable = function() return settings.use_deep_breath, "settings.use_deep_breath is disabled" end,

        handler = function ()
            if buff.recall.up then
                removeBuff( "recall" )
            else
                setCooldown( "global_cooldown", 6 ) -- TODO: Check.
                applyBuff( "recall", 9 )
                buff.recall.applied = query_time + 6
            end

            if talent.terror_of_the_skies.enabled then applyDebuff( "target", "terror_of_the_skies" ) end
        end,

        copy = { "recall", 371807, 357210, 433874 }
    },

    -- Tear into an enemy with a blast of blue magic, inflicting 4,930 Spellfrost damage over 2.1 sec, and slowing their movement speed by 50% for 3 sec.
    disintegrate = {
        id = 356995,
        cast = function() return 3 * ( talent.natural_convergence.enabled and 0.8 or 1 ) * ( buff.burning_adrenaline.up and 0.7 or 1 ) end,
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        school = "spellfrost",
        color = "blue",

        spend = function () return buff.essence_burst.up and 0 or ( buff.imminent_destruction.up and 2 or 3 ) end,
        spendType = "essence",

        cycle = function() if talent.bombardments.enabled and buff.mass_disintegrate_stacks.up then return "bombardments" end end,

        startsCombat = true,

        damage = function () return 2.28 * stat.spell_power * ( 1 + 0.08 * talent.arcane_intensity.rank ) * ( talent.energy_loop.enabled and 1.2 or 1 ) * ( debuff.shattering_star.up and 1.2 or 1 ) end,
        critical = function () return stat.crit + conduit.spark_of_savagery.mod end,
        critical_damage = function () return talent.tyranny.enabled and 2.2 or 2 end,
        spell_targets = function() if buff.mass_disintegrate_stacks.up then return min( active_enemies, 3 ) end
            return 1
        end,

        min_range = 0,
        max_range = 25,

        start = function ()
            -- Many Color, Essence and Empower interactions have been moved to the runHandler hook
            applyDebuff( "target", "disintegrate" )
            if buff.mass_disintegrate_stacks.up then
                if talent.bombardments.enabled then applyDebuff( "target", "bombardments" ) end
                removeStack( "mass_disintegrate_stacks" )
            end

            removeStack( "burning_adrenaline" )

            -- Legacy
            if set_bonus.tier30_2pc > 0 then applyDebuff( "target", "obsidian_shards" ) end

        end,

        tick = function ()
            if talent.causality.enabled then
                reduceCooldown( "fire_breath", 0.5 )
                reduceCooldown( "eternity_surge", 0.5 )
            end
            if talent.charged_blast.enabled then addStack( "charged_blast" ) end
        end
    },

    -- Talent: Erupt with draconic fury and exhale Pyres at 3 enemies within 25 yds. For 14 sec, Essence Burst's chance to occur is increased to 100%, and you gain the maximum benefit of Mastery: Giantkiller regardless of targets' health.
    dragonrage = {
        id = 375087,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        color = "red",

        talent = "dragonrage",
        startsCombat = true,

        toggle = "cooldowns",

        spell_targets = function () return min( 3, active_enemies ) end,
        damage = function () return action.living_pyre.damage * action.dragonrage.spell_targets end,

        handler = function ()

            for i = 1, ( max( 3, active_enemies ) ) do
                spec.abilities.pyre.handler()
            end
            applyBuff( "dragonrage" )

            if set_bonus.tww2 >= 2 then
            -- spec.abilities.shattering_star.handler()
            -- Except essence burst, so we can't use the handler.
                applyDebuff( "target", "shattering_star" )
                if talent.charged_blast.enabled then addStack( "charged_blast", nil, min( action.shattering_star.spell_targets, active_enemies ) ) end
            end

            -- Legacy
            if set_bonus.tier31_2pc > 0 then
                QueueEmeraldTrance()
            end
        end
    },

    -- Grow a bulb from the Emerald Dream at an ally's location. After 2 sec, heal up to 3 injured allies within 10 yds for 2,208.
    emerald_blossom = {
        id = 355913,
        cast = 0,
        cooldown = function()
            if talent.dream_of_spring.enabled or state.spec.preservation and level > 57 then return 0 end
            return 30.0 * ( talent.interwoven_threads.enabled and 0.9 or 1 )
        end,
        gcd = "spell",
        school = "nature",
        color = "green",

        spend = 0.14,
        spendType = "mana",

        startsCombat = false,

        healing = function () return 2.5 * stat.spell_power end,   

        handler = function ()
            if state.spec.preservation then
                removeBuff( "ouroboros" )
                if buff.stasis.stack == 1 then applyBuff( "stasis_ready" ) end
                removeStack( "stasis" )
            end

            removeBuff( "nourishing_sands" )

            if talent.ancient_flame.enabled then applyBuff( "ancient_flame" ) end
            if talent.causality.enabled then reduceCooldown( "essence_burst", 1 ) end
            if talent.cycle_of_life.enabled then
                if cycle_of_life_count > 1 then
                    cycle_of_life_count = 0
                    applyBuff( "cycle_of_life" )
                else
                    cycle_of_life_count = cycle_of_life_count + 1
                end
            end
            if talent.dream_of_spring.enabled and buff.ebon_might.up then buff.ebon_might.expires = buff.ebon_might.expires + 1 end
        end
    },

    -- Engulf your target in dragonflame, damaging them for $443329s1 Fire or healing them for $443330s1. For each of your periodic effects on the target, effectiveness is increased by $s1%.
    engulf = {
        id = 443328,
        color = 'red',
        cast = 0.0,
        cooldown = 27,
        hasteCD = true,
        charges = function() return talent.red_hot.enabled and 2 or nil end,
        recharge = function() return talent.red_hot.enabled and 30 or nil end,
        gcd = "spell",

        spend = 0.050,
        spendType = 'mana',

        talent = "engulf",
        startsCombat = true,

        handler = function()
            -- Assume damage occurs.
            if talent.burning_adrenaline.enabled then addStack( "burning_adrenaline" ) end
            if talent.flame_siphon.enabled then reduceCooldown( "fire_breath", 6 ) end
            if talent.consume_flame.enabled and debuff.fire_breath.up then debuff.fire_breath.expires = debuff.fire_breath.expires - 2 end
        end,

        copy = "engulf_damage"
    },

    -- Talent: Focus your energies to release a salvo of pure magic, dealing 4,754 Spellfrost damage to an enemy. Damages additional enemies within 12 yds of the target when empowered. I: Damages 1 enemy. II: Damages 2 enemies. III: Damages 3 enemies.
    eternity_surge = {
        id = function() return talent.font_of_magic.enabled and 382411 or 359073 end,
        known = 359073,
        cast = empowered_cast_time,
        -- channeled = true,
        empowered = true,
        cooldown = function() return 30 - ( 3 * talent.event_horizon.rank ) end,
        gcd = "off",
        school = "spellfrost",
        color = "blue",

        talent = "eternity_surge",
        startsCombat = true,

        spell_targets = function () return min( active_enemies, ( talent.eternitys_span.enabled and 2 or 1 ) * empowerment_level ) end,
        damage = function () return spell_targets.eternity_surge * 3.4 * stat.spell_power end,

        handler = function ()
            -- Many Color, Essence and Empower interactions have been moved to the runHandler hook

            -- TODO: Determine if we need to model projectiles instead.
            if talent.charged_blast.enabled then addStack( "charged_blast", nil, spell_targets.eternity_surge ) end

            if set_bonus.tier29_2pc > 0 then applyBuff( "limitless_potential" ) end
            if set_bonus.tier30_4pc > 0 then applyBuff( "blazing_shards" ) end
        end,

        copy = { 382411, 359073 }
    },

    -- Talent: Expunge toxins affecting an ally, removing all Poison effects.
    expunge = {
        id = 365585,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        school = "nature",
        color = "green",

        spend = 0.10,
        spendType = "mana",

        talent = "expunge",
        startsCombat = false,
        toggle = "interrupts",
        buff = "dispellable_poison",

        handler = function ()
            removeBuff( "dispellable_poison" )
        end
    },

    -- Inhale, stoking your inner flame. Release to exhale, burning enemies in a cone in front of you for 8,395 Fire damage, reduced beyond 5 targets. Empowering causes more of the damage to be dealt immediately instead of over time. I: Deals 2,219 damage instantly and 6,176 over 20 sec. II: Deals 4,072 damage instantly and 4,323 over 14 sec. III: Deals 5,925 damage instantly and 2,470 over 8 sec. IV: Deals 7,778 damage instantly and 618 over 2 sec.
    fire_breath = {
        id = function() return talent.font_of_magic.enabled and 382266 or 357208 end,
        known = 357208,
        cast = empowered_cast_time,
        -- channeled = true,
        empowered = true,
        cooldown = function() return 30 * ( talent.interwoven_threads.enabled and 0.9 or 1 ) end,
        gcd = "off",
        school = "fire",
        color = "red",

        spend = 0.026,
        spendType = "mana",

        startsCombat = true,
        caption = function()
            local power_level = settings.fire_breath_fixed
            if power_level > 0 then return power_level end
        end,

        spell_targets = function () return active_enemies end,
        damage = function () return 1.334 * stat.spell_power * ( 1 + 0.1 * talent.blast_furnace.rank ) * ( debuff.shattering_star.up and 1.2 or 1 ) end,
        critical = function () return stat.crit + conduit.spark_of_savagery.mod end,
        critical_damage = function () return talent.tyranny.enabled and 2.2 or 2 end,

        handler = function()
            -- Many Color, Essence and Empower interactions have been moved to the runHandler hook
            if talent.leaping_flames.enabled then applyBuff( "leaping_flames", nil, empowerment_level ) end
            if talent.mass_eruption.enabled then applyBuff( "mass_eruption_stacks" ) end -- ???

            applyDebuff( "target", "fire_breath" )
            applyDebuff( "target", "fire_breath_damage" )

            if set_bonus.tier29_2pc > 0 then applyBuff( "limitless_potential" ) end
            if set_bonus.tier30_4pc > 0 then applyBuff( "blazing_shards" ) end
        end,

        copy = { 382266, 357208 }
    },

    -- Talent: An explosion bombards the target area with white-hot embers, dealing 2,701 Fire damage to enemies over 12 sec.
    firestorm = {
        id = 368847,
        cast = function() return buff.snapfire.up and 0 or 2 end,
        cooldown = function() return buff.snapfire.up and 0 or 20 end,
        gcd = "spell",
        school = "fire",
        color = "red",

        talent = "firestorm",
        startsCombat = true,

        min_range = 0,
        max_range = 25,

        spell_targets = function () return active_enemies end,
        damage = function () return action.firestorm.spell_targets * 0.276 * stat.spell_power * 7 end,

        handler = function ()
            removeBuff( "snapfire" )
            applyDebuff( "target", "in_firestorm" )
            if talent.everburning_flame.enabled and debuff.fire_breath.up then debuff.fire_breath.expires = debuff.fire_breath.expires + 1 end
        end
    },

    -- Increases haste by 30% for all party and raid members for 40 sec. Allies receiving this effect will become Exhausted and unable to benefit from Fury of the Aspects or similar effects again for 10 min.
    fury_of_the_aspects = {
        id = 390386,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        school = "arcane",

        spend = 0.04,
        spendType = "mana",

        startsCombat = false,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "fury_of_the_aspects" )
            applyDebuff( "player", "exhaustion" )
        end
    },

    -- Launch yourself and gain $s2% increased movement speed for $<dura> sec.; Allows Evoker spells to be cast while moving. Does not affect empowered spells.
    hover = {
        id = 358267,
        cast = 0,
        charges = function()
            local actual = 1 + ( talent.aerial_mastery.enabled and 1 or 0 ) + ( buff.time_spiral.up and 1 or 0 )
            if actual > 1 then return actual end
        end,
        cooldown = 35,
        recharge = function()
            local actual = 1 + ( talent.aerial_mastery.enabled and 1 or 0 ) + ( buff.time_spiral.up and 1 or 0 )
            if actual > 1 then return 35 end
        end,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff( "hover" )
        end
    },

    -- Talent: Conjure a path of shifting stone towards the target location, rooting enemies for 30 sec. Damage may cancel the effect.
    landslide = {
        id = 358385,
        cast = function() return ( talent.engulfing_blaze.enabled and 2.5 or 2 ) * ( buff.burnout.up and 0 or 1 ) end,
        cooldown = function() return 90 - ( talent.forger_of_mountains.enabled and 30 or 0 ) end,
        gcd = "spell",
        school = "firestorm",
        color = "black",

        spend = 0.014,
        spendType = "mana",

        talent = "landslide",
        startsCombat = true,

        toggle = "cooldowns",

        handler = function ()
        end
    },

    -- Send a flickering flame towards your target, dealing 2,625 Fire damage to an enemy or healing an ally for 3,089.
    living_flame = {
        id = 361469,
        cast = function() return ( talent.engulfing_blaze.enabled and 2.3 or 2 ) * ( buff.ancient_flame.up and 0.6 or 1 ) * haste end,
        cooldown = 0,
        gcd = "spell",
        school = "fire",
        color = "red",

        spend = 0.12,
        spendType = "mana",

        velocity = 45,
        startsCombat = true,

        damage = function () return 1.61 * stat.spell_power * ( talent.engulfing_blaze.enabled and 1.4 or 1 ) end,
        healing = function () return 2.75 * stat.spell_power * ( talent.engulfing_blaze.enabled and 1.4 or 1 ) * ( 1 + 0.03 * talent.enkindled.rank ) * ( talent.inner_radiance.enabled and 1.3 or 1 ) end,
        spell_targets = function () return buff.leaping_flames.up and min( active_enemies, 1 + buff.leaping_flames.stack ) end,

        handler = function ()
            -- Many Color, Essence and Empower interactions have been moved to the runHandler hook
            if buff.burnout.up then removeStack( "burnout" )
            else removeBuff( "ancient_flame" ) end

            if talent.ruby_essence_burst.enabled and buff.dragonrage.up then
                addStack( "essence_burst", nil, buff.leaping_flames.up and ( true_active_enemies > 1 or group or health.percent < 100 ) and 2 or 1 )
            end

            removeBuff( "leaping_flames" )
            removeBuff( "scarlet_adaptation" )

        end,

        impact = function() 
            if talent.ruby_embers.enabled then addStack( "living_flame" ) end
        end,

        copy = "living_flame_damage"
    },

    -- Talent: Reinforce your scales, reducing damage taken by 30%. Lasts 12 sec.
    obsidian_scales = {
        id = 363916,
        cast = 0,
        charges = function() return talent.obsidian_bulwark.enabled and 2 or nil end,
        cooldown = 90,
        recharge = function() return talent.obsidian_bulwark.enabled and 90 or nil end,
        gcd = "off",
        school = "firestorm",
        color = "black",

        talent = "obsidian_scales",
        startsCombat = false,

        toggle = "defensives",

        handler = function ()
            applyBuff( "obsidian_scales" )
        end
    },

    -- Let out a bone-shaking roar at enemies in a cone in front of you, increasing the duration of crowd controls that affect them by $s2% in the next $d.$?s374346[; Removes $s1 Enrage effect from each enemy.][]
    oppressing_roar = {
        id = 372048,
        cast = 0,
        cooldown = function() return 120 - 30 * talent.overawe.rank end,
        gcd = "spell",
        school = "physical",
        color = "black",

        talent = "oppressing_roar",
        startsCombat = true,

        toggle = "interrupts",

        handler = function ()
            applyDebuff( "target", "oppressing_roar" )
            if talent.overawe.enabled and debuff.dispellable_enrage.up then
                removeDebuff( "target", "dispellable_enrage" )
                reduceCooldown( "oppressing_roar", 20 )
            end
        end
    },

    -- Talent: Lob a ball of flame, dealing 1,468 Fire damage to the target and nearby enemies.
    pyre = {
        id = 357211,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "fire",
        color = "red",

        spend = function()
            if buff.essence_burst.up then return 0 end
            return 3 - talent.dense_energy.rank - ( buff.imminent_destruction.up and 1 or 0 )
        end,
        spendType = "essence",
        timeToReadyOverride = function()
            return buff.essence_burst.up and 0 or nil -- Essence Burst makes the spell ready immediately.
        end,

        talent = "pyre",
        startsCombat = true,

        handler = function ()
            -- Many Color, Essence and Empower interactions have been moved to the runHandler hook
            removeBuff( "feed_the_flames_pyre" )

            if talent.causality.enabled then
                reduceCooldown( "fire_breath", min( 2, true_active_enemies * 0.4 ) )
                reduceCooldown( "eternity_surge", min( 2, true_active_enemies * 0.4 ) )
            end
            if talent.feed_the_flames.enabled then
                if buff.feed_the_flames_stacking.stack == 8 then
                    applyBuff( "feed_the_flames_pyre" )
                    removeBuff( "feed_the_flames_stacking" )
                else
                    addStack( "feed_the_flames_stacking" )
                end
            end
            removeBuff( "charged_blast" )

            -- Legacy
            if set_bonus.tier30_2pc > 0 then applyDebuff( "target", "obsidian_shards" ) end
        end
    },

    -- Talent: Interrupt an enemy's spellcasting and preventing any spell from that school of magic from being cast for 4 sec.
    quell = {
        id = 351338,
        cast = 0,
        cooldown = function () return talent.imposing_presence.enabled and 20 or 40 end,
        gcd = "off",
        school = "physical",

        talent = "quell",
        startsCombat = true,

        toggle = "interrupts",
        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            interrupt()
        end
    },

    -- Talent: The flames of life surround you for 8 sec. While this effect is active, 100% of damage you take is healed back over 8 sec.
    renewing_blaze = {
        id = 374348,
        cast = 0,
        cooldown = function () return talent.fire_within.enabled and 60 or 90 end,
        gcd = "off",
        school = "fire",
        color = "red",

        talent = "renewing_blaze",
        startsCombat = false,

        toggle = "defensives",

        -- TODO: o Pyrexia would increase all heals by 20%.

        handler = function ()
            if talent.everburning_flame.enabled and debuff.fire_breath.up then debuff.fire_breath.expires = debuff.fire_breath.expires + 1 end
            applyBuff( "renewing_blaze" )
            applyBuff( "renewing_blaze_heal" )
        end
    },

    -- Talent: Swoop to an ally and fly with them to the target location.
    rescue = {
        id = 370665,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "physical",

        talent = "rescue",
        startsCombat = false,
        toggle = "interrupts",

        usable = function() return not solo, "requires an ally" end,

        handler = function ()
            if talent.twin_guardian.enabled then applyBuff( "twin_guardian" ) end
        end
    },

    action_return = {
        id = 361227,
        cast = 10,
        cooldown = 0,
        school = "arcane",
        gcd = "spell",
        color = "bronze",

        spend = 0.01,
        spendType = "mana",

        startsCombat = true,
        texture = 4622472,

        handler = function ()
        end,

        copy = "return"
    },

    -- Talent: Exhale a bolt of concentrated power from your mouth for 2,237 Spellfrost damage that cracks the target's defenses, increasing the damage they take from you by 20% for 4 sec.
    shattering_star = {
        id = 370452,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        school = "spellfrost",
        color = "blue",

        talent = "shattering_star",
        startsCombat = true,

        spell_targets = function () return min( active_enemies, talent.eternitys_span.enabled and 2 or 1 ) end,
        damage = function () return 1.6 * stat.spell_power end,
        critical = function () return stat.crit + conduit.spark_of_savagery.mod end,
        critical_damage = function () return talent.tyranny.enabled and 2.2 or 2 end,

        handler = function ()
            applyDebuff( "target", "shattering_star" )
            if talent.arcane_vigor.enabled then addStack( "essence_burst" ) end
            if talent.charged_blast.enabled then addStack( "charged_blast", nil, min( action.shattering_star.spell_targets, active_enemies ) ) end
            if set_bonus.tww2 >= 4 then addStack( "jackpot" ) end
        end
    },

    -- Talent: Disorient an enemy for 20 sec, causing them to sleep walk towards you. Damage has a chance to awaken them.
    sleep_walk = {
        id = 360806,
        cast = function() return 1.7 + ( talent.dream_catcher.enabled and 0.2 or 0 ) end,
        cooldown = function() return talent.dream_catcher.enabled and 0 or 15.0 end,
        gcd = "spell",
        school = "nature",
        color = "green",

        spend = 0.01,
        spendType = "mana",

        talent = "sleep_walk",
        startsCombat = true,

        toggle = "interrupts",

        handler = function ()
            applyDebuff( "target", "sleep_walk" )
        end
    },

    -- Talent: Redirect your excess magic to a friendly healer for 30 min. When you cast an empowered spell, you restore 0.25% of their maximum mana per empower level. Limit 1.
    source_of_magic = {
        id = 369459,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "spellfrost",
        color = "blue",

        talent = "source_of_magic",
        startsCombat = false,

        handler = function ()
            active_dot.source_of_magic = 1
        end
    },

    -- Evoke a paradox for you and a friendly healer, allowing casting while moving and increasing the range of most spells by $s4% for $d.; Affects the nearest healer within $407497A1 yds, if you do not have a healer targeted.
    spatial_paradox = {
        id = 406732,
        color = 'bronze',
        cast = 0.0,
        cooldown = 180,
        gcd = "off",

        talent = "spatial_paradox",
        startsCombat = false,
        toggle = "cooldowns",

        handler = function()
            applyBuff( "spatial_paradox" )
        end,

    },

    swoop_up = {
        id = 370388,
        cast = 0,
        cooldown = 90,
        gcd = "spell",

        pvptalent = "swoop_up",
        startsCombat = false,
        texture = 4622446,

        toggle = "cooldowns",

        handler = function ()
        end
    },

    tail_swipe = {
        id = 368970,
        cast = 0,
        cooldown = function() return 180 - ( talent.clobbering_sweep.enabled and 120 or 0 ) end,
        gcd = "spell",

        startsCombat = true,
        toggle = "interrupts",

        handler = function()
            if talent.walloping_blow.enabled then applyDebuff( "target", "walloping_blow" ) end
        end
    },

    -- Talent: Bend time, allowing you and your allies to cast their major movement ability once in the next 10 sec, even if it is on cooldown.
    time_spiral = {
        id = 374968,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "arcane",
        color = "bronze",

        talent = "time_spiral",
        startsCombat = false,

        toggle = "interrupts",

        handler = function ()
            applyBuff( "time_spiral" )
            active_dot.time_spiral = group_members
            setCooldown( "hover", 0 )
        end
    },

    time_stop = {
        id = 378441,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        icd = 1,

        pvptalent = "time_stop",
        startsCombat = false,
        texture = 4631367,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "target", "time_stop" )
        end
    },

    -- Talent: Compress time to make your next empowered spell cast instantly at its maximum empower level.
    tip_the_scales = {
        id = 370553,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "arcane",
        color = "bronze",

        talent = "tip_the_scales",
        startsCombat = false,

        toggle = "cooldowns",
        nobuff = "tip_the_scales",

        handler = function ()
            applyBuff( "tip_the_scales" )
        end
    },

    -- Talent: Sunder an enemy's protective magic, dealing 6,991 Spellfrost damage to absorb shields.
    unravel = {
        id = 368432,
        cast = 0,
        cooldown = 9,
        gcd = "spell",
        school = "spellfrost",
        color = "blue",

        spend = 0.01,
        spendType = "mana",

        talent = "unravel",
        startsCombat = true,
        debuff = "all_absorbs",
        spell_targets = 1,

        usable = function() return settings.use_unravel, "use_unravel setting is OFF" end,

        handler = function ()
            removeDebuff( "all_absorbs" )
            if buff.iridescence_blue.up then removeStack( "iridescence_blue" ) end
            if talent.charged_blast.enabled then addStack( "charged_blast" ) end
        end
    },

    -- Talent: Fly to an ally and heal them for 4,557.
    verdant_embrace = {
        id = 360995,
        cast = 0,
        cooldown = 24,
        gcd = "spell",
        school = "nature",
        color = "green",
        icd = 0.5,

        spend = 0.10,
        spendType = "mana",

        talent = "verdant_embrace",
        startsCombat = false,

        usable = function()
            return settings.use_verdant_embrace, "use_verdant_embrace setting is off"
        end,

        handler = function ()
            if talent.ancient_flame.enabled then applyBuff( "ancient_flame" ) end
        end
    },

    wing_buffet = {
        id = 357214,
        cast = 0,
        cooldown = function() return 180 - ( talent.heavy_wingbeats.enabled and 120 or 0 ) end,
        gcd = "spell",

        startsCombat = true,

        handler = function()
            if talent.walloping_blow.enabled then applyDebuff( "target", "walloping_blow" ) end
        end,
    },

    -- Talent: Conjure an updraft to lift you and your 4 nearest allies within 20 yds into the air, reducing damage taken from area-of-effect attacks by 20% and increasing movement speed by 30% for 8 sec.
    zephyr = {
        id = 374227,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        school = "physical",

        talent = "zephyr",
        startsCombat = false,

        toggle = "defensives",

        handler = function ()
            applyBuff( "zephyr" )
            active_dot.zephyr = min( 5, group_members )
        end
    },
} )

spec:RegisterSetting( "dragonrage_pad", 0.5, {
    name = strformat( "%s: %s Padding", Hekili:GetSpellLinkWithTexture( spec.abilities.dragonrage.id ), Hekili:GetSpellLinkWithTexture( spec.talents.animosity[2] ) ),
    type = "range",
    desc = strformat( "If set above zero, extra time is allotted to help ensure that %s and %s are used before %s expires, reducing the risk that you'll fail to extend "
        .. "it.\n\nIf %s is not talented, this setting is ignored.", Hekili:GetSpellLinkWithTexture( spec.abilities.fire_breath.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.eternity_surge.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.dragonrage.id ),
        Hekili:GetSpellLinkWithTexture( spec.talents.animosity[2] ) ),
    min = 0,
    max = 1.5,
    step = 0.05,
    width = "full",
} )

spec:RegisterStateExpr( "dr_padding", function()
    return talent.animosity.enabled and settings.dragonrage_pad or 0
end )

spec:RegisterSetting( "use_deep_breath", true, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.abilities.deep_breath.id ) ),
    type = "toggle",
    desc = strformat( "If checked, %s may be recommended, which will force your character to select a destination and move.  By default, %s requires your Cooldowns "
        .. "toggle to be active.\n\n"
        .. "If unchecked, |W%s|w will never be recommended, which may result in lost DPS if left unused for an extended period of time.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.deep_breath.id ), spec.abilities.deep_breath.name, spec.abilities.deep_breath.name ),
    width = "full",
} )

spec:RegisterSetting( "use_unravel", false, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.abilities.unravel.id ) ),
    type = "toggle",
    desc = strformat( "If checked, %s may be recommended if your target has an absorb shield applied.  By default, %s also requires your Interrupts toggle to be active.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.unravel.id ), spec.abilities.unravel.name ),
    width = "full",
} )

spec:RegisterSetting( "fire_breath_fixed", 0, {
    name = strformat( "%s: Empowerment", Hekili:GetSpellLinkWithTexture( spec.abilities.fire_breath.id ) ),
    type = "range",
    desc = strformat( "If set to |cffffd1000|r, %s will be recommended at different empowerment levels based on the action priority list.\n\n"
        .. "To force %s to be used at a specific level, set this to 1, 2, 3 or 4.\n\n"
        .. "If the selected empowerment level exceeds your maximum, the maximum level will be used instead.", Hekili:GetSpellLinkWithTexture( spec.abilities.fire_breath.id ),
        spec.abilities.fire_breath.name ),
    min = 0,
    max = 4,
    step = 1,
    width = "full"
} )

spec:RegisterSetting( "use_early_chain", false, {
    name = strformat( "%s: Chain Channel", Hekili:GetSpellLinkWithTexture( spec.abilities.disintegrate.id ) ),
    type = "toggle",
    desc = strformat( "If checked, %s may be recommended while already channeling |W%s|w, extending the channel.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.disintegrate.id ), spec.abilities.disintegrate.name ),
    width = "full"
} )

spec:RegisterSetting( "use_clipping", false, {
    name = strformat( "%s: Clip Channel", Hekili:GetSpellLinkWithTexture( spec.abilities.disintegrate.id ) ),
    type = "toggle",
    desc = strformat( "If checked, other abilities may be recommended during %s, breaking its channel.", Hekili:GetSpellLinkWithTexture( spec.abilities.disintegrate.id ) ),
    width = "full",
} )

spec:RegisterSetting( "use_verdant_embrace", false, {
    name = strformat( "%s: %s", Hekili:GetSpellLinkWithTexture( spec.abilities.verdant_embrace.id ), Hekili:GetSpellLinkWithTexture( spec.talents.ancient_flame[2] ) ),
    type = "toggle",
    desc = strformat( "If checked, %s may be recommended to cause %s.", spec.abilities.verdant_embrace.name, spec.auras.ancient_flame.name ),
    width = "full"
} )

spec:RegisterRanges( "azure_strike" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    gcdSync = false,

    nameplates = false,
    rangeChecker = 30,

    damage = true,
    damageDots = true,
    damageOnScreen = true,
    damageExpiration = 8,

    potion = "tempered_potion",

    package = "Devastation",
} )

spec:RegisterPack( "Devastation", 20250325, [[Hekili:S3t7YXTns(S46QilToESgkPeNu2AlBl7DtUSjPI8UPU6QtuC4GrdxZHCwsoswPCnp7x3najbabiXqYXFC79J4ypeSrJg93DdWRME1BV6Y5bfSR(zVJ9o74t8oBYXEEp9KV7QllUFn7Qlxhe(UGBG)ssWk4pVGDBqErqruAc(S7JtdMJWipDtwi88LffRZ)(N8KBIkwUz2KW0vpjpA1My6ncZcwuG)7WNmloD2tkwYUli7oyOrjpHLCtuc7jHXb55(RsNVjML)KG1X4)5ZUn9DSSjHRxF1LZ2efx8djxnZmM)uazwZcV6NNE638TacfnFoJpywE4vxId(XhFYJ9o773E9LrRE12R)7Rr4S9h3(JLpC6XvpCd)HxFyrwuY7yfhjpUJpHpUWQXv9qVh79u4HV93)DyeSG80KTx7PnStF8XF3J9MQnx5YpDkIMVioo9UTxFrwWnPjWFaOteaUx8lVUEOF7J9(2VE71WRC8PI)po))DbiVErw6kX8i)o4c4Tlba(7bzWFqBfxDzCuEroUTYW)8NjUewsWSy28RE5vxgeY3)zfSSKOI79Z3KHSiSvRtVJL5xKE1LtV6YW7dJz(fbWZaO9Z4VKfbVsuahe3Y8zjSvri69SNV96PBV(rBVUiiMLumPe25(5RdsMiM9Tx)Hpa7fBV(2aamWVmjmiXN9(cwYC)5Wk4GkaeKeTknhGG67kE6kKlBEuEusb7MmGevpQJiOOJGNtt7jYO4I0Kc)0f(RcUjkS(9HbC62R)tDUsoIJqZ2SyXK5vBTtYyRcIsqscqrM8TNrGc4OJJ9xcIEmc7S(sNZPJgEf7KLdSro5YmzrR5B3VwSqa2iC)g4Y2KdWoli5DBVgaAbq1wVookeHemHP4KsB(tUQaet7bxK3UZf5r7aEUSd0f53BsFO(g2ZWL)j9y5FYUV85CON46Y)bDXnFGlImTtirSAIxpiLgO)iL80EqjpTDkPBlrt07tDvGhW8cWKzgdSjolOWKE1uW6woROEfvkwI)T4nW)tyeAsX0ja5WhK)8rkOq12N2hgLpzvuwwAgYfTidwdBYyZbQ)Qu4xVl30lKhDtcJy7aFb8xNfLMDpTS95UBigT)uAkZnPgzhiAETTa(08WDKO5TlenVAIMUYNUjAS)1MO1RzZNmJLxasKXPGqJ0KChlyDAs9mOlukMHOfMNdnWKFFsOS8OTzhqnFwCo8Ihp5SkCDkIaNnklrso(SPNYTFm9mntG)T7bhKaV9sta1xldYMhMoh1o8yWlkWC3fW)fTADmBfOha0BLUIHouDd3FTCYrr0S4)CdASe0db)t05lcHMyIUaUA7Zrxyj(n2PX1KUkt5AYoK62dveadttJNNExYK5BYih03E9xT966FTwTC9aavEhZzkBFCFvxZunGuvjSmffwaM7qG8cy9rABbxWcJMd0S7GnILvVmNUUoic8bedOq2BzWrfqT7cwg5wWQOKnOXNGK5KRsL)BbGYnR(HZGAHvYgl532pzIA5xDXIg7TEw2B9(OT3ACMmS36zzVTvc4t3zzAvEPzSyqnk8h5KQY8njHbXXiJqt(UK7xTHbAQHf7TSyqOfSEhLmh9K1GDR13VcDhjl3)o2mD)KbTjR4rDfuZxjKYbxEUhPVRwdOoQzGuausdbnlle)K49aM35r3grAzW3KEwnLUA4CRlrfiVEko(8jBV(VgWXb0FgyDhwG(PppArescomCdqBskIVhDA9S3Fexg6gWfh6LwgDZsCCKbgYTF8XsGQCLnrecPXzjh2ZJrChxLldsUbxiiAjn66zikjmdcwgjDPWlpNj(NWu8c43UdEd(BhiphlWXgTqMCJAbWXMMv(3ssrnYGavPcIsAE(eZI8Rcs2eeJSHFx)zd92b2qVDHn0ZeBOjDi1lJPhVZRJJntAsVjCoidNxqGD3DJ1iy90a7aC0JKrZ2m7E)7wYIx7NVKyCAkhdgrGGlqbrFG1lilbeB9JcfqVX6M9(W4nZjBXt3DxQu376a982z0Ztb96P)yLaRuKu26ZdKYtqnnP2aKDRt4kRlBxQMVWh5xRM7iYDSdncfUmnFesqq1T7JkZGJQhqopntnpn6HePzqBA1EVhTPyXh195MIPNBEFPHlN0sTXJjYqfTCVVR9S)8hJTTg7CnGunTxSJEcTJAXLCx0cynay5eyPOoWCGFgIAYmunjIwB6fZstRmD4YTNE0opyf4bP)EJp(avkv8TX8eijtRHFSDHZD3zZPtoUr(PuDf83OCJcrziYfLySGZhbyeGGFIk0PSPK5pF63rCYKNhzmRyvf9odOXS1eC8dsjSArWM4ckryky4)q86cVOadsjCh9a9azakUeCsI8tvScYfdCZAWhw6bx8BIYrK(6juKWVHk1Wk0HrkWAymNMZaPWCgBf8(XrVJj8An)og4a56u0n3zBkqhyFi6Pmd5xbWtobgHIO5akTaRrbmb)1sCIWKvPze4caC4BWjbSpIbxG(cpJDdLnrCbndZ8g31wWtmroPn5sKde41GVJ(WS7hotI2EmbstUd5aiv2ZaxGQb7t3BBzx(wovWKRwoGYnkwGcDWKdsoa013NPT(5GZIdnTiEQt341IduSEzbO2qEobhUZXvrXsabrYhnJ6wRRMiw28GKcF2QzzbH6I8)fm4JljonGaLfJ)ZxmpyDHWy1VcBYBIJnK95C(W9dQgTuUJ)zpDtnnE)fra2xKMTsj79hkNKFwYnBIxyReaKlPWQcyzKktv9cVAci8r3wGIUC7OKur40XMdAdtQrJyiEyWJ4fXbKwsjwLwQvjOJH()A5skoau0SgdnKlpWJJ8(0nGEcuTsWS0nIKlD5LKYhSqxyiZq8CSBdW08rcxPRzjmU0i(EeeUJE8f)2Jp)nV8XNF5Lp(8S0YANxtTu2GKY3IcftVojBwxwOs(RxLeM8Lbff8qgq1b0aramNrGq7X(IFUCu6v44CEb1klvjO2KMZfr3SSWxUuzNCw)YnVPenvd3kF)QgMAnEQhkSX8uUx()z1xa5a9NLXckwAy06jxSw1kypb27yiAYtLdxnBcOVdiMYvIpNNyM7sZEhPCLZWGw3wf8(OvBwHMEkadDjIFw(TdNlYejWWKvRXgmhcUWLMra8vO6A2IfuUsyLjxsjRfiA5xd3DoL)nSRfn3GcMOvG5d4VaCn5fzBcvurjRVU5UldSSPVlaSnFlXoXYbTVHmyulIcrZ2IQyZD7JyqfdbC4llVGyx5S(zbrZ9z3sv2E(88jOum(28fPY8wNJnWLTJNCQIQOvSyqXBg4lH5sFMW2aQ9dMff3OJcmjZCcYAzVQi7Kz1gBdnkHVgt8)9RNdVHiFHxEFw0I)hILV694qpNmhLXk2KrUiHSMjBqDU80kwni4HRzzaxXkeOK2UILiB)C5uSt9cqePif8doyUuUjXSDgZEpyh8x)j8FLa4hc3k(etA347VgX5NrfC9ODUQpg9EZKzRzXOx4lacdyF3edrEyAwiwzNgMlRht4sSuZZ9jGzAarzyAAdjwFdpw16y7Yxg1YjAhGdKvFYHzDv23E9zDjcAq(dmDe(oAFWWdbTE(Ibu(2QKcXdrtlhBQSwQrqTzTW(7QGQWgqP(yGhdzvxgSE99173)Rnm05kEDgw4Ft4C0NGYIXuokr6vLNwdLBOC0y2A95)dFS1O4niLACY5MsuS9w14CE42GA0OWcQzekNSSnjwNlmuotjY1L3LYQk8t3KbwIm5PKQxSzK9QlXOvZjH758DbaHV5gKU)IKWiQkNVjMJBcCGTc0tgJ71G3cPRQClWQ3ZYBbf81yl(XP5at7T1XHMRKLq9sP60mqHlZ)2OBKv(l7MQL(N5aZDeYjLEMzZTBnsn2gFc7vySX5ySW)YAK6ZRtbUmrxiwqX5I(cqX6fiktZnXPZcIfEriIaK)Ibyx)XGr96xU96Tx)YGnREfvbgqW77XIvN8q0xMuEfvEd392FMTPiJxVaDV5QPRswDxLElvTBYY7ZOiWLmBVeEAwj9gKfv7VNJNCwPEEA0nA)gUEKCTnS(1LosXXqyLjDe26rR6aFu36aXdKQx9yQ4BHWC(IlFXVktW4(ENeSghA5Yrkmjg2Zhlz8yAYLd7ZwZoj5zJgsjVpt9wkHJx8svEimmhClN(V3(gAV)rNC874bcD2Bn2Duw8c6GUCJ6bwCiVMqyZb)YatANqz3SPI922CF1GVeDT7)IW)1MOSsBs8mjRkM9FGTx7)jStX9mI3dUuBJeismMeRZDlJIlbggRjp0mEagGI9ey8t2E9pS963LGDdSWZkHVu8HDtq2mkScrU04rLWd45rETU52gLTZui0M)fNAEiCxcYL7va5e4RfqdxkwyAtXr(Pt80tJHPyOps4VyR(A8xawBGcdULT96FJCGUuGrcrqDRuiE3Kfbolr5zR0102CzObf3eAEqRgSoSDxhLKtS7FA7MM4arefkYWjjTQ4nXIzn8Psk8t3CRQiAnVE4aXILRNSUiyn)AqmaddhCXllDDe1i(Cl9iDAd69rDgqxhhCpTDqoKa(jSMIKbMHS7IWGtiq(MxoU5EPBxW7m3fcE)ohNcWmoD166S0nVDT7FKjVyTADH7fHr3hAXFTpt8oZIRzC2lFSIw8)6KLSGyGiVoSWOV3YY104Pe4xKcEOWe(571AIcoOKNU5Bo9SUt82XgLalm0xgk7JVIka1Bi7xVKyJG9YlX8ycyr0FqzPe2E)LemxN8QvHUmi6zibMu2BnX0ZFA(J4YJGAju4Kr)vQumONTSCkldyzAo54C3uv2B5tftog7VCjJn6Llt3Gs7hLeYGPFE06LPj6sAhAFV9PQ5FQ1ZJYoPuUrJZ8fa5uov208)pb)(xNwun5palSxH)S0Kn5tkU7op)txh2FkO(rfWPi9zum(nA8hLeizjtwntVcf(VjN5lm08o9n43HL6M9Ngy8LnTDEG2UFnY6PYJ0hFrFw3(IEo5lQErb4bqHUKZD0iIIAMLtHpJHsUGoEEV(LFTK3He5cxL47I(N)Ql0JoGo8Guy8iSP8Q(AcHA6VEHHMhQkHl070jVW80czfh(8EYq7a3irLT7k(5d0vC90vlLI6FK3y8P8oJnvKv5h69WgPvgDl8Ix(kmb2lyzipSE6LHaLWb(EI4zV4P2tqjzb2RHJEwu)Hz3aKFikXPoshk3cXAEtOPEnvRuqiPxR9D6rkrkvsAvSbsLgsYoH1zsXR12hQGCZBHR6U66rycIMASmD)DKR4VfGouCHea5UO8QxIH9MuukDggSMOT2cdXEMuOP5ck89sxKOJX7BXYDKWDObR6uPBq8(lPmOXOIhI)i24ZWlphCJk4MauEUSBL57ci1(hUyYowUTs)4nwCmA5Q7fVcVM668xVhX3tF7JizWtW)ppdI)Ju8GBht9h2J5cd89mUuisPHF(xbod()G0HDXVPP5XKFVNsVzPjkJRurywsgAUTcD2XGERTezwlyTonz8KktiEyoBgS3yPdqDewQyuvqBMLfvDCQvr)kXwJ(eWna05yMk7rdNYDizv)XoUBQ)QN5WR(NknorrO2OTTkzUvAnKUSikvVVnzjGvBd(bx(KgobBnCFzEGZKGKHU7rzljGxpfoUlLJb6HXSG1vlSCP8b1A9Xn5150(SooPgt6N3K6kW5rF(tVPurJy9bAqOfi2RAOoYVxCSnQsTJy74RR(B88EIJMxwAwzlAGRRzcL24qYtbcoX7Ohwmi1H35bt1qX)RuSUEZfaDUIzM40BWtbO4ov4TM40WrNLTznpvcI7VcSIdHXrRX16bndv4GIiqs98N7DWHMRWY5EF4dk1vbORmGT6EFArOpvspcNW(aDfbgBL95Cvfh1f9XjnxwQxt3UyqZGfFKkm0vJ7UsIsdlLfUr2GIM6HoyWRyxrNAxeLVuySSe0Ikhr4TEaMnBVq1AVksaxeEKIClTkvbIlRYXKNfnvkj9qfExLiL51yUWqxB6gTvpcpC7cmk(hS680zCZSOLU2m4p2qnwAw0709)5naPAgPNAHGi2GPGknDvP(BR(0AhjlnpZnMu)Mz1B6jhRO)xcQzS1PzQXOimZGEtzlrHuZwyo6x1ycmu(mdW60JPN0U)qIXDu5DhKgPXqfMljIjmikGy8SBeSg1JLarmhYY6IA6M)wDI0NvIW2qJwQuSGfb0IGhNC5)Tlmch2XHCyhQJQP(af3LRpMevdTAXFKKwx1IZO6XrRtICIH0RUabJgRqLZGY0kE5bUyflgljDxjzszkh)O6CAqlL2iy4aCA5yyxvCy9mzKS(8VWp8MAysJZ)eUM0es1EHAE(QxcfJ)MJljdTKTNAnhDKpdDFsniD2jXQBIHEDcLoR0LgBjp2OJVmAeUSJzNlob2FDz46yK58gBcyVOBVimxD4Dia(B63Ia4PCwO)x0B483fPLNQgx8R5Taf(cOcdPSfu5i780nZWQ9JeQTsN17ckdJ01lb5ylnfblOAPC5Lp5nVuGLsE6YtUiGE)swfwxFKCARhsetRx)vonD)OCA6NPkN8(eQCAABkNmrW6wEZZYGM6IYjpZkNACiq7s5KXlqIpdvo55cXqZSVxBTvesm8bpku60(kilF)64Q7bh6G5QUP7EhxXFAEPkMWUSR1nj9etLBWKQLdDGvVBRDDSWM26cBAFxydutX(wN3hj9zUuwPpEYYN4YGM2TnPUbINdEDxQ0OwHGHgvR7am0ANv16s3LL7w89uBFZYz5w2B3DrjuJBXexut9CEDAlXn1glwu2i(6ADg7wKImzQ8zbAC5hDstz7lzoU0EO(pRkFYAMtPCaGjm4rTTCoQzwy)HfO3Jyd(qoCIuwQERcCT(QeI6LCe7kpNpK7NuR1XFTQ9iUxOy1Tsyr8N3n0MLwwATk4u1DHT62QMX2DueWRZRxGEic45ONzsdOlrGwU(0(CxeyQrraJl5pwIaT1qQv6s)3hDNMX)QBIPpoSjFoQPuZ8QH(ITTWO))66BmJ)FKzB(mu7sZ4)kOJExxN3o8Mh4fHCs9pXpdy8Rcf8IUJLNRE)OCdRGF8rMXqxXFqzcRF3s8oclM9E(j5aZQLFmUwCRlfB)ocGN2HdATmGFtTuHDCXqI)nFUAYP(Pzf1NpQfGTQn7UR8G0u25a4QOQ1b2s3WotCROy1m9nimU2qoD3xvi3vl9HAJUn1EZMoENbVM(nvsUehuoLDN)MyYa(uSk4FnEUkWTP81rzOUlrTXxX7p8egUQ5BKf3XcWRibtPK0sJzytBGjg4knogdKvP8vvJ4lIJKH1TNUpan8ldj8uViCkxPBkqmINXAcN(ALtltb)a4mXukSAuf3ED0aT2)Z2BwZU3Dn0KV227OHwzoZnzxtDTSC6nCbbFQUnV2AiExwgoFuc6CA7Cj21zCPTtQINTtQIEGEk8XAF1jQB(gQxdLS)snbr9r)YnL(wSeANcDGvb1dS2t7LAILpudhi5krZVHjpWCz63vRh2c0PX5iqRKAzy)SFjDUZ5vx6RRoU4IoQTSstVGoCaBV(FqNoGRgTJFGgNQXJGGXdRw5sCe7k(Gsd9ielhrbDbsqNXfP7RrJdnkXFb55dkXuE8fpQPQhwY7OB6xvXredREc2cxKQBdVUXBVRsii3MmvlHwaMEsEL5YRhL1JHA332u6tOvqTydi9MX49gRGE3Tz3hP2dznDvO6rstmmnZLqUUxeQCPwPzoTm0FB9cFwojT1KZw4MvldY0JBBSkU2CMBXX98bDEqAJ60A0wAgi1kqIIiSUpbg5zKovEpWb6T640M9MgYDGvFq8JkldfTtkRCRSzpsQLFp3cUO4FCvBC)mLgew)DuACCR71TV3awhxZcleC5dGuCKZYShvnydT)20J1mzErkMw7BsNtncY98UVyjdM5emi9Wakp3ysZxWcWlKZ7OdWeDfoGRuCg)ZBV(JYrHsV35vBfskW7YuetUAnz71)kDnjgKLUbdMa7etcRYxY)moGrwarJNtFxoqC6IFBYxSNM4wZxvDk5uVTwDW1Azfb2CQVPnfkaF)LPzr)rQ2NUlND33Kfqjay(8lx7NlY8g08q3yjmb(A0wycnuV2(P2TkMkNnf3vvQpWAYVOF2qr2LjI2FChmvDg0vlBtTKAaHIyNpz4no6dYIgLwN6kjxpW1TdRb(lZDznZbs8sdbmTqCpYAciACe6DiI0VeutQFcKXSo)FG3ru)A2MeKAXtux1f348n0NZrmJR13AJIoqmyo9nPPG)9Rcp7Yx6Fjgc7BlVeLfXOlUeW)cqfTBAvLvKB7ojWue)kyEJBCAxcQz3XpXO5FheZXpFog84u(PkU5u5pytfnDM6HgxtckIq)EaDFyHShV5LpbVMF43q7vhvwKTphVD1ijOGerVg8xWtr)D8VOqaHBtCbNpNFzyrcejPOazcDhfUisuNeyjjj1HxrOHx16TNzn36DaQASd92LV8SDy2r6NLZywf9xUUtYFJaOWSmzzQQwnwb)J7Iz78N3Nj9ktxFfQuBZjY8lfcUR0uBPR98EtvT1hPQhNn1QkYVFcjPdU5IPCJfEKOuEPabpnF8d)uoxwK9E66JJsYNhE5wK7qAtBJ2AoFGsP87XTLWWJi6t1(t5CjD(7C4wE4tgcB5uOz6gFqdLLUZiRbc(dv3d)wVxd6MVO6qjkU1kRQQQijV8JKlmx0h39Ctz3v)8r3vmfDxBoTZDSKp7Mpe0pW4UqDwtSDZgRKveNXMRmD1k0OCygtf7bw9J)GAMnz65b2tDBB4iUW2T3RQeKI0xB6nnMe7d0krLALk0)9M58Pb11(X602j(3W1zHG7EnDRwGosaI2cVawakLtvVAnrarxLUIBHF8c6e)3yRPKRDzxWV9pK3WfH8GuNsHsTAi12fRj9U2VCSPXWXpTpjdxz8GS)VlEr7e07WHv7bJ0Wv2ghKC1(HOX1qJKVmQ3Bp6hvF6a5lYS4ZE(u(ncqlh3DTT4EEC87AwudRUTBiOhiXNO8LJOO(suuiGmd)ONNnhXXQuZFLPd7UPiY)84w5XsweSjIwYFFO9psftfI41ItPj3)E)y2nbH33GzUfajoQuDae(vNI9oVX(c8JC2HuKXTLEiRjVPXnaqdZZDUiA)RkIAvUOVKiT4hID8S12CPwWI)9WItvAWPvDmv4RSM3Mch1UKQIz0ctFvNmF7OCbA6u0jgVgvRbgixsYr8E)NrjhIcWVY)rSnJsaUksrfm(ySdJeNTv8nX4qe)ZILrzyGlr0LYq9x5TOvydBsFwLMTPOiL(492NlFLD)Uq5GdBkC8HpOy6AkA6ApFLSSdOXyySWcJJ9NfoR5Zk)IUz0QiY0zleM6aDm6Hx1JTEV7BsEHMXwVJJ)m6owP9oOOuQ36hoofy1uV(dmh1Hsyk4uRD3Ry6ME5e3UsUMB(sYrlT4GL8FiPmXe15cNNnIFqQ85oy(sy6K7MUT6zFoMWdw4McMunZ1l8sdkHKCJmKNfVPEQngLClHZ2DiPvnLHoZ9Zfm3N0ANMlDz3W1RYvgynfffu1JA5gVrPMtcpUHGeXpRQnfhAT9vmelPYkx7UH8mZHzwR8YE424hVVGCi6M0cF1UJrPA)gloo3PZYZUwg9fELFb1NjUH6XptoY3s9pHJiIp5OUqg)CLUDOZKoDriBD)SklZjM659VOOqTTCvxRNAQp47yTEyTUmlzTCkDJvQ(rjMqmRVKiFy6VIYc1Cg2TLzEtEQ(CPR3fhzHujxtn1i6dMC5nPpulJ04bsW6Kn2O))px6IPOxKvptnCFhK1oLQf2CBL2dO1jt86b134w2(M4pak8jxj(YRbEwtFKy(zVJ9o74tWMi7UGmmoGCX9yep8gHL5hYYFioL0HHAEzT5d2uKkUnJcPQ4Npz7p(trypyJfY)vPjW0qp(HLkPkKVE2Fi3(K5hwUEHbD403FuxqUIoRb0g0FhHxJSnPbxRzJYr4RWTQbBJCYoc3pdPWE7nm9Kp2qEW7AwG7OXTD6Ng4pik(2F0GcN8IDtHJfMmtPxtd9AldCoYkVVjV1MF0aCZ6P4iehmJSngbYluDgafxt1H0z2OPkzBTbf1yUyDf2vj6vhSnYaSoe)M9mhGf43BLVFPHVF7hh41d(0NAbZKopy6iNHJkMou)oB4h)uw1advpwwocnPEaqdGg6oahHPw2a1GRLZYGJWwkdwAW1W5v5tim3N0aD))1bULWdCe6dWIYNe8vTr00GT5Z7KJq(Zw(IPhp6BD2azV1UAdGkhveDDyMogjUc4rZULTjqUBX0GTPgjZvWwDWv0GzJd0IRaCVti(IGnB3TIp1s0TJCGc2MMb45Pvqogok)fh(AjsSHW1AbK9NRDFhT4NSjq6uAObAdNUJga1soq6pD2sSO9hGwC1FO2g2hENBdO9q1ONntIQDnQ(k3CpL2a4w0gmabwBGS3772a4OjpT)NG9TgbplcVs95NgOn0bGFCaQfTcJSHEBtZamCAfKJHHtplPeBSjlwYluztbQbA9EfSb4SOLtPFLAiUBOBNCfWnBJjDm2AFo56uO1ipgvv3OnF0b(jT6zCVbUXuYpNTiyt8oMx(XxTVfLfJmdSTc10FXARL(zeKQhBpGSOKGowi(l2KLe0iBjkpBhH7iL7ilqx5qTObAJFMtDeUdkZrwG5o52MrP01zSq8aomu5uXvyl)t9cVVcbNdIJzH10W6R5wJds1r1HpbytlJdShGEfDl7EFByE9qgxGpaSgEwU4RmCByU6Wg)jzaRaQLyAd3lhWyc4bGVyJf1g6kE(ic2DhzJYNSkkllndls7ISGWInzymyPGXNS07Ynmro8kUp55r3KWOkeJH9r3a4M4CSpsv3JSmvEUOxWYGg7jW2EKdG2MUbJdzCb(aW620jyDyJ)KmGvGz9dggWyc4bGVg1q085Jiy3DK1bTi6tKdVI7tUtkEABKktvJiuR0Xv1R1L9vPbTBMgZEf87na)PhVHnSLP8lwC)q8(PYS1KgJPn8oDnJJa58d03dT9fB4GdBd9)QVQ(NQJmT8Pp)4p8H2E(x9vTbB8TBBfEujzONO(GW8HH4v7knA)Mk55U5MmpgLn9Xg87na)PhV7wiZ8yAdV7wiZRbNQb0F0eYmaBfEvdRq7czUH6dcZhgIxTR0OCvYAwNXIbtTWFKZ7rMnj4jfLLzwhBlJwHrO1Pm5(vByGdgj01Dl1NlRv7MnL5STH7(KQ(v2X8m1ymkGVrEALLDCMm21ODFkDNm25WDFs7GmAEmQXoAZhoAlGkP5DlzXR9Zxkx)yLnkdJAhMJ7wgLVM3GvraHpljOG5hfA0HLogU6S2ifUYuUoxz2g1omhUVY6C4QZAJeixnR4PzFsqY9(ZxN3MrjBJBSNhuPS)GHpVug(0hH9oxmAdEVmJTMkiBZXuhPA2h3ypp9B3rh(TsR6yW7LzS1DNgPYFN5PDB3z4Zt77oUc)Xt2zKMXET74op9W2DCFE63UZoYjpc7o74m26UtRjfWP894CIMTox7HClnTL4WIV1ORb8F2nOm1muMAek264JXSfhS0ThvxkoAqU((jChb4ovE02b1G66oplhRO(VGhVZPKnq1ZfmvI5fPXXP3fr3)1Gck8(SJH3)iGC9CPB9A(z1F714LYdDRyvoo6B93c(DrF9ONphh88GIGzb5SVF7pYV2IZIkSuB7GuubZqQQTO)hg2z26J(rVUpCbMH0O1iG2oG0JrVIUp7)TXVD9SDcB3JuIEWp8XPBiTyQzuOfJrhZ0kKgqpPzXgZ4dXb1Zr26jZXP7Rgpt2wA)(bqnT1q)d9uWBbU9ynBRbxhMLkBTE6WTunEh7aBNtObSDBdK9UFiTbWHEIq23NhG))JjfZusGgfzlBGDeeUSc6EiDn(g7Agi9WbPLywgpEalAQhz)FSDASUnnoOWKxR1pyxb5iz12g4hYMPfqo4(W22butCLMQbYYl6uBaZIAN(EcvSEQgh6juXIUG(INTQAzCpWiIetnsxDC7UUVX34N9IZvv)EX9UxfORtXNHHShbUDW2B6PDeeZXBjgya50ESJaTpR69kW7eSUNRFNQPWWNMwlPGDW3Dti5qJeo2GVlg6biwBVkHDYMyCi7rGBhS9wS2oc2QyDJh7iq7ZQEVc8obR7fy1jX6HpnTkwBh8Dl35qRlo2GVlg6biwBV8YDYM0TPLXf47cy3jY7UJ17e47eW9tK0rSUFaFxa7ozHA3X6Dc82bCVv9p(jhWHf9oSvTxbENGTFIYoIZ9d4vG1EZm0hWQHZJlWDaSJsJN6awVt622ZG3oGhSq4EMqBVTu6K9OBz8Xf4oa2Ujjo074oG17KU(9m4Td4bZ7TNj02oda9t10Ef4oa2Ujjoio6awVtkM2ZG3oGhmV3EMqB7Gt0pvt7vG7ay7MK4G4Ody9oPyApdE7aEW8E7ncTXuRVahWWtQ(yvejZqVhbKyROmJdEA7lrYOHNdUHsSKBZrA9VhlfWiT()iDrwn2WBK2FS1g1dLQo2FKg2dns2)B3DTWBBCRL(3IrbuKSDKLgj3BqxlvehB3BUB72GQSTyXInYJKOSMBK0m78WoUWW)23Z5WhdjhYrJCCs2BXfxKAnC4qE45X35bjfQ6ElPLd70xzwoXOQSpmjjnEz0A2hM8DF3JxVkppj7ho5KBIYxvmd02V5KSOnfRjv9ZtdxMJ)98tGhSjkp7K8vS7ctXlUZOTN8AQVFhw9(We9NXVWj87g3Ply3c6HPEPl2bp(pWV2)zcF2SieVJV4x)NtI28gGu8lHW8cZ7nMIA8AedRI5fdF1PVQpoN4tJSUQtMRJgDIC3gFmE1LosyiqUV(pM2kfJkTGu9GQPCVbx9COY5ZG1k5HTIZNthRjoFcwp26piAhhPhwT112LyFOjboPjUo8Ek)WvpICC(mN0e7J6fNpXKMS7J5eR2(uPj3XctI3AqqqiajjSfDNXYYbKFRJZZ2JUk7(TZpoozuglpAPOl7Z)3PS1zSr96E6XZJ3Uic7qpFnq64xUhKQMJxrUGWXQW0fZJPBDBqs49GqZfXeaM1017khUckfEdF3aqczKW1)Sa34a0TvkTfbObs39z(aYT8DIun0NdpT)WGd7FknYVGnNUTFVdg)GqSyDIpCscJsLY6xOqaEmEfpZwI3n4bpE9MOTfOgHqCVn0V8VfDuJwmkL)3Z1JDFYG4af8Z1XTGJUw)qlW1bdY(qmc(SjgvobhC4o6ZfXWrxRtmCDaoqSFxcCLiM9mGdsJPHZ5)41ZWlC64njWudLwiHc5hIFdvt)K49aoZfr3grsE4BsptoC0AoswarVC6UkhBpyD96)EiFmO0NIxiZlIwgHm6TNxKMcYU4fGD)UN(PoCbKBIULrV0QOBwHTlryqL)yTUsoZGpe3DgxFLmGcTgh7mPhml4x25ATU8lebg5XRat45OprlyI)e(eVM2HsRxZF7q9Vb5)u0sDYnkIJTnov(Fr7xjK9tk9lP5znszuP04MWTfHRRyqpY)reHLaK3t1bBZSgEpUpdYa3dYAphlSySBWG0r4v2Nbz)PX3mFXu8Uxxmo7TpVEWN3R3Fk7tZxxSG5AH0(eDWAHX7zWW(mac8maCEKsyr0FwgasPoB1Xb6QJ7RPm(aVMM8PM(Hh8RaxtdUZAKOZHTD8YOaCNd99Q6BB5oJBRzXSXFI(wFI62z07LTVQK7OLL23CadCG(6qLXPQ7AY6t1NuDbQcARdR8iGWae1V4lCN9JF5x5(Cw6CPXWf8)Jco0uvPJ2Gmbk8SUAqvzl5Oz0GMmhweUbq3m9lGqVxMQwAZ613UESoLc(BcJ0VfU9Je2AXvzT4(2gSkhIUlaaOynz2L2NmamfBVenz3EhQF3DJFTFx8scOcGI1TC0m4L1g85wbibiWyIrtMOHfjW3LEWf)g3VMxhFzxYfORsJ3ayqqurKxiqBgMXaWfzm2MmmahFKjGMLDhdqjLeJy5OnqDu(lq4GGpSKVfesNie(wgmKwgMsFG)UCmrJeWPtQ7cHXW3JFeCfkJd4Bg7Mi84AdNqZqkfh)gyHVzqBwKcSfSeIionmMDSquz0qKljLb8jnPBsa8utHb705Zu9qpTE4zDDyY73)PgauqoUE1EnZmUr3Dp3(ozOTQRFWynG9dyVE90KibdRYjJOTyWQMYVVLI2USaVo3N2tP0BCJa4KCFQXu1Aj49)XFaupWj3j5OhdnOdbuGz4upFf0l4kKyC)kQ)(jeR9eINBc)WLaesuNUepE97aYFbiy7(dXsxeUnhdEyA4CgQmufyr7dQc39G6uyq7Dv)wR2hye57hEq(3AhpcESeSgC6cGxr7JdSVpWUZbiz69DRQ9mgOqkAeRdbb9e0)doRl3zL7JlaMguSoCwCHi8etMqc)BIZi)YaC6SBd3kZruCcBlJl4GVh1d3rp(IF7LJV68xoEYKxoon2IIbth4Rd)x4errtk999HhOiGP5mCrshG4P4mTVEllsE4Hfm6LSE0uXpJTa)63cMu2Y2eXYgpkOd8HaLsTwcEwMpvKxZZgCQLUbqlhmJyixg3lAUEITGOdOOunibQyg3N47It)iPDGtgrDUBc)u0MInOcXCq9R88Pq)TNVqeHhGmMwQYbusdMHJtPo8nO(g2YLKBQmPF9D1PSMcl4GCA5xXwexJelN(ayh1JLBLqWRS0YM8Yx1z8pw2iKdC6mWV48vATOdxj0BjDipE9Lc1mGai386Bf6tY4mFa14(xq8E3ggTMt3b9m0KwJiPRydMRcnukDy4sTu5VUslKpRklvRdCohmEqvon)0ALbNOfAs)U2BFMkdlHWvUUWaJeM00Z(BTyzz0EVhE7O5r5Jh1V1b00s8ay(NMLJtG2PHrlMsxdQDdxSid0LpEeFCB03Yp4H96ouPaP88OqQeX6GVOQO0aEKM(VVeqPjJm0K7tJw()qQpuz7HB2kJ0eNYYlsjCcOKW2cuhfpasQgbpeCReiPBWoLu5KVcLYwOhP0Imgh4bqLYzHl0IcfgxR1SpbMaE3pJ)LafzM)frtBRLlJQPG5kMdUQ2oMTNnStd4BaGkAA2nUTBA5jbxYF3yZnk)rTZRHwggh2j)Ndz6ZgnOvPIbEMBfpA8PUynDWzcIqZ)4zoEaOECk9q(BzUvnPhmkOhhOErIW00MqfIwKBFnSYJmqRctsUxNy))waGVpMhw0LtVz(Ir91FSiIs6)egaQP8)CkMyqdVVm4Dsl2wTHiKvqupAEo45cSGwryzN9qwUWw9R)1lnZr5)2Jx)RjO5dEmdrDsOnLLeCC04aHEnueY0Bwhpd15sMveyA5Vi8WLPmuX85pE9JxFEyXM3qrdLx3bxeV9fOXTyE0nVIJc4)GvKNgQHDcMPWuWsh5XZVF(AWdpCjmpJtcA7YIdiRifU02l8L4ym2h7TmPIa3yNwMOPShwRIbnwMR74qrtZ4gOfBibLTN99cvP0BHdn4fu83ywaA1wMSpZTdoNVntB2uPj26lpB0qU(YjWsjQytIHJcw(CGG)6jV(D2ZhdOLCSoYnIlAYsIh08KUH(m6RUyD0mH(QxCUjNdAggxOP))7VIwXpAqVpYrjE67ThpA2r00tAzQOvvBknWQRfUde8M7PxlNyEDzYLlonNQMjJuuysE(oSQt(3Hzg3IYsYRAkzJHcVQ1wSUBv0AzNHaL5yn54ab56Tq7bNZF7Jx)XTX3PSijSbXB2nHPZi0FchX5GhZ4e)a)eFN(zyrBQ4THp13dR(iUg4mm)sLr2Ycm5zk7fh2VBqPZmLTOdNn)NaUbGoawJa93e8ajBNg8xuVeHx(M0i2sUx3kWcwZE3kOxotJyuoiA5r3t7QwjvSz2MzT118Wdc454sSgBCfzeDORGZUraF1LaNc6qbyNknojIQ1dUYsK7Oa9EQmyejGVAeT4kAnfmUrGKGv507IqCpuxE152F48OeE6uasflB)8ZQEua7W5aGFzhT4SAHziLHnk6iBYFNkQ14gTEkwR4K(PafcaH8d8)Q7kw4AymLmp)lN1RAnEPbWL4PPrff1O8yW2cdqre4agElxTS)PU9ZLdO6nuaoVIulEoNj(6lMG(2dDs0FsEUde3FDl6)ppAOOLcrYAr9HqNktQ5A65Vk7iopmitHm0m6)CH4gCa4hZKHoCqVS9r2UH8WUtOUuBNsDMDCgl1GPqWxA3r7OwQdQ6Okz(vLoqzdaOtt1x4EYVxcWpFtEmKlu))pbaojX5uNFa4TW0zXBlY6MF3DbthMmVPZBt1b7aoXbo8SY2jJbCqueAg0(lxLzebCLLriyr0ClxJwFV88J1mYqcRyCRX3fng)MlSHcGibMqiPX(MC(8sUS6Umo3eaXpnVJ(C048Wdvx6AzS(YhabDAmYHZ8JCyCprib0cdW)Gx6vX86mjw45(lcErfx3r7JxC(BWGeSKLIKcBx4bqvyd)KnTx4GRls(I4CDzVP8urvcYhN4(W6mE3yDShjyGVvq1D4rlOyoOLttlYre6ccS2F4qpFpSKrrk4VeIAuVqtWJRJ(nNJWj3MlfeMhMurQt7LCr0EY(8a8qkAPwGXeAS82Jkmc13m6FoSTmteh1RB)oAeKlia8sRziZsW7XafTLB7bJiM0Ifp9usaPr5Va)rS4GGxEbyXl8Mquixwrp8PlIH9Tx0TzEe5YBepXTJMbV7ECKm89hrYmdW)L7Z(VRoiVON0pG8PFo6TqSy1(Ly8vJxZ)dsLf4zNh(Y22Ohg(sUwjNNgzaYqLMMYtumVaMLQFClZn2kMih2R7F70oFgcdL)MHGwNwozcL21QHVwWN6qb9OGAEwFPnQXJAp4L7GAw20tRTPhgi4T5q1(5RKmeRzHjCFs5(6FDb626YFquCzkFhehtzhR(V4(EITMhsvMmBg4sLazc1KSyyeyZazKkkxkAvrWK)1e0l5HLMbefNUyixQpv8MooL4vRqMhWzO)l0plinYZ7x0DppHk3gur)Mo6g80IWjFP8)kgdM4czAGmuDVo(gSoN5XEys14UuNkBG9pAl8VmGID)u6VqxB4B7GUyWW0EcqGALhbm8GTpJugOfySXs2DzGX6Cm(1ttlsYT655RJsqIElhq3EkFgGtQPn2NCEL4UTl7pqF5uutj4GWwwgLTsOEvgcozK72trfP2trV0YsqPmJ2VMZMlIdGWp3iSojBMle3KYyBnsNHMyJWAKTOulhyWRDc6yczcKmsE6(rtSRGr6mGQJeuxZKW)SGkDG0OpwH4jIp(LcmVGCc6tHmzqPu18GjTMcZY6O5Im5gld1IELOWW4WB6CYXc3waN7qHQQlC2mw9pYjkC9ONzKzPwE90SQtuwq5h3EWrUcsYrdp05yOtvVeL6Y6dMD1loPksUkSX9nAM9GVL7jzJjXbnHehG1VMBISV5xq3Mo9SienEKpOjJ8bhnW3i)axRK1KibFZ0rd6g0W5QfrPXt1H1OaRjP8Wh)PquwpcuMYX8aLMkIuASv0spH3P6c0lNjIqUemUbRMMwkBqRT95N7inpnoTQpVOfidfDTWcLjmdqveNRof1oBKra4A24DWxNXB7gmG9WT2PztKHFDMiUgHnBaYXU2(zwxzNMQS0wIzu)opFCrb1p3EY6j3JzNNLExLL1Z38MKECY1cwM9soE6kt)8PhnCYlYRgvjztWVFM8MsIuqMgDZnyu3TGnQOzeCquB)gwA4A0B54SmWDJknWQIifFySKb57UzaJmIXuwdX42Gc87XSWIbD18uNoJHHf9GYVsgwzJORdr5SnCGQFCfU9rwZ(eptMrGVtamwyU7lOW1x3FOYIwE8I47nZjm)aUydflnthYurn(ozsGLEQJ58TmfZuzI31A6vxi9RpVsodCKFdU1ePDyA(lIjoSGHUxEmM5qC(MLeHjjt605gE2C2YkpYpYVJfsLZO586zU8kkZpkVwYPKAsHCZmwgOqmpExKy8XgjdnNNFv7LaRKHwzm3WmR8VkPg1yU)eRsd7EjvpDK1tgmYjG7P5WYmm4GrUAAk6aK(6)OVYD(R21aPMC25mBGohA(YoRRCUg4YT1Yq(qrSvrRfU5RL5)MRAXvmySnnzICYr2HSt)NhJz6vUJex2U0h9(vPyw5MqfWgpbChRQ7mzYkebF51u6UE86FNURuSic2jB7jNCnTfCT0RXdh0fXy4vVjMxgD3Zt83kw4TO93zS5HK7k01yilmLkrCmfwub)GmQO20F8RC(WiQZNr6W49Jyfv(0CQyjPSgdUJ7SjrBNUKSyJcd8pPrgf)OyB7IFF5F1fJpiqg0AO2gxG3w9qnPgovEnl2bL2rJQ8zx7vGYUZ41wwaYBPmEkgiAq9kSpAOtZiIFuRRHoDb9z31aRKh1Qj7yWzxg7Ibyh)5VXd3rjG0(981gLXSt)SsOQ7PKV(txzVP9(so6H1hAFQeooWRFkYNy27D8WR8exIvdfnbnTrTN1XJe5KySZVQc(HqX3zImxy3orkSCs3RJUbgcsyZbDCpLjxhVS0DGhzA9e450cvKmpvKTZUpE97OT1uyk)kGfdZmPxndREtXUmbaXNrNelOw1l(TUFRQ0PASExtHo5vuYDr9KL7PME8bksx9cHGF6Q40O)mEBTGKQQGZzrtP2OcGPYW1(at5TYQ8cxerg2aTMELGuzm0eRe9tw6rOoY7dCSG5aaPtYLfc(DxSyUq2RkNvNLBWUjrvCbO0vtdFf6OkC2D2uNt3o1Ga(FjKITktmmwiFhwv9VlTyBPxZQTG0Ick)tyCe02)r8TKr4IfQCaFlce(YjtXYzB67L7Tv5UEsSNUBIgKAQwWNdni1LOQ2oRoWQfrO6ZvzV8wpGQ6)2INXd(x2D0Xuc9P1(LsWjctM1xIIaN6FesBeaCv4QZpblEB((AxvHqi3vgUroig1WTu8iE86FcROW74h2qWKRyD(JL3l5C(YTXiF)wksDlJebjdgCAm3wR43bdMJZyZRLkHl)nmRJEv95iQOcc2rQUw)Wo4qx6fPGV5P7Ez9iX2VpYoPsUD))BbHA30d3J1X7lfPC7frCCCnD9565ci2Zmftg5aopj8zC(B2NO9Ic5(Daw8S2OxSt8)EqFC5EUYl8x64H86M5qbDTArsymWmQAGVQdmRbcYx7D)APV(OQTeXM)sfUzryq414f0zXfPZz7AHOTf5XnASgwItERMkF774Q7d0gxov2rU0tPLOfxa7CyAnZB5lQbv)2(JWqf7fToqe1dxT2rSpQMBtJcGtLVtDVT0PjL8jjuHHIMBaUwHTILGUIyZDEgpFALNLa4(xd)7GEvRxuEPXAr4LfiQaCioNKSYAHr0E3MrT19g31Uawgf8xfGmE7HDHQOAjBBlxBuMF5LBsPOT)GyHzgE2GKUatXIkih2f(hv3DchOptUPSRP63ikEJR6UD1B(RoCN1R33Wc42LhvUY2yfozW9txN1c9bUEjhx827)001SBcNFpWx4S5FFVwoA8oYLJRX3ZUxGA84MUb2O8m5Cy4IaOcgyVUd9wC8o1svgHrXjnuLkkOVK2kT)6PCr5r6hvHkshZLOSeOOCfXbr5Ieu6PokkkTiFnqCGfasqbA)AmnKHlj)iX3eryj(Z8vrPiKSiQShlpjT4x9c0rNZSI8CCwwN(GVbL9BRkLlbYVyOMSpfdNDxFWFr)47J(l3vnSJFD(m9FLZNPBAwzG0Zo4VkGqBE09RuFRXQ5NrL(6pFisbOkfIVRAew8BAaXmWPfzueWLfATvyDogpJGKENuglhUljVTm012YjvoOSCX5i2OlUdu(y2NyZlYzIGVFG7rVJq8pBDbV7Rab3dk66rgFQDL)oQVDDtZvGiQSd)(bPFfbipgtQu5nMNCUECDQTze57pONafG2BdWUaDzC0F8DFCBhPchWf6QE(SW0B9od75C38xMHNEDAWmfmKLgUgpEodtqvJBxbceSu3tz3H2T2rHOyw0o1SL8TKR40bznYllpaVwiolUpwIPbHVWRMlQaOey5XJkE83SpS4XZ7A5ztd)aCJ)UiSPHMy(VKxVx4lGtznivQcSzrCbvR8ChkeJ)JPHocJcZdFKQyZew1Mm5eSADcvrBGVBI4P1hgE)AQAuxEUvw)cfEk6lpYD67Jz01b7k2USMCiJuntaAhuOQwjwuLjTTsK)31XsNb7CNAo9ubhLB)Kg1DCDCCHHdvnz0VeT1p5MTNKooEK1hEoi2IJm6ooo8vLhm56Nv1op7ChBxLXLTVuktL2zaPS)CkJQuQkTQ2h7wY11mzRBc1C(2GMZ32)zHVT6T02xE(2GVu8T99W3wDsw3szGJh2Vo(2Gk8TEoxP9Y364EA4ReFBqDtOgW3ItKPGXWfgrgx)SaVoDUUUdmAgXjOhwga(64608uh1yGE5NylO562lPzAG8my77DW2VPd2NKy0ZJa(ZQqCDL9ZZfR(GA1FxJgXALFQdbabQ7TlLUJqiHqeour7jEVYB7eQw4XPKCVmr4Ie5geFnv)ZHhXJUqe)57U3Mfldmwz)uR8TzrpxbD1(CSQlneQTk75uDhrn0mLcvU5oQvJXiWRJ26vqEVU9BDqsk7wC(bl6ArJA)zgRvvundzrqk84j0zNAvotGRrd6DKVXwND4iJ)1Za3RNb1Cm5341ZG6ndx(SAwpDENo91E9SV96PJH8x11Z)kir6AGPUuCEEw3()DYH)vqYZ1a7zED7BG82hMewKVko9dtW7qZpKd)Vp8)n]] )