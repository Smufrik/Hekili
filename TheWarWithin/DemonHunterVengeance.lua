-- DemonHunterVengeance.lua
-- January 2025

-- TODO: Support soul_fragments.total, .inactive

if UnitClassBase( "player" ) ~= "DEMONHUNTER" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format
local IsSpellOverlayed = IsSpellOverlayed

local spec = Hekili:NewSpecialization( 581 )

spec:RegisterResource( Enum.PowerType.Fury, {
    -- Immolation Aura now grants 8 up front, then 2 per second
    immolation_aura = {
        aura    = "immolation_aura",

        last = function ()
            local app = state.buff.immolation_aura.applied
            local t = state.query_time

            return app + floor( t - app )
        end,

        interval = 1,
        value = 2
    },
    -- 5 fury every 2 seconds for 8 seconds
    student_of_suffering = {
        aura    = "student_of_suffering",

        last = function ()
            local app = state.buff.student_of_suffering.applied
            local t = state.query_time

            return app + floor( t - app )
        end,

        interval = 2,
        value = 5
    },
} )

-- Talents
spec:RegisterTalents( {
    -- DemonHunter
    aldrachi_design           = {  90999, 391409, 1 }, -- Increases your chance to parry by 3%.
    aura_of_pain              = {  90933, 207347, 1 }, -- Increases the critical strike chance of Immolation Aura by 6%.
    blazing_path              = {  91008, 320416, 1 }, -- Infernal Strike gains an additional charge.
    bouncing_glaives          = {  90931, 320386, 1 }, -- Throw Glaive ricochets to 1 additional target.
    champion_of_the_glaive    = {  90994, 429211, 1 }, -- Throw Glaive has 2 charges and 10 yard increased range.
    chaos_fragments           = {  95154, 320412, 1 }, -- Each enemy stunned by Chaos Nova has a 30% chance to generate a Lesser Soul Fragment.
    chaos_nova                = {  90993, 179057, 1 }, -- Unleash an eruption of fel energy, dealing 6,678 Chaos damage and stunning all nearby enemies for 2 sec. Each enemy stunned by Chaos Nova has a 30% chance to generate a Lesser Soul Fragment.
    charred_warblades         = {  90948, 213010, 1 }, -- You heal for 4% of all Fire damage you deal.
    collective_anguish        = {  95152, 390152, 1 }, -- Fel Devastation summons an allied Havoc Demon Hunter who casts Eye Beam, dealing 56,864 Chaos damage over 1.7 sec. Deals reduced damage beyond 5 targets.
    consume_magic             = {  91006, 278326, 1 }, -- Consume 1 beneficial Magic effect removing it from the target.
    darkness                  = {  91002, 196718, 1 }, -- Summons darkness around you in an 8 yd radius, granting friendly targets a 15% chance to avoid all damage from an attack. Lasts 8 sec. Chance to avoid damage increased by 100% when not in a raid.
    demon_muzzle              = {  90928, 388111, 1 }, -- Enemies deal 8% reduced magic damage to you for 8 sec after being afflicted by one of your Sigils.
    demonic                   = {  91003, 213410, 1 }, -- Fel Devastation causes you to enter demon form for 5 sec after it finishes dealing damage.
    disrupting_fury           = {  90937, 183782, 1 }, -- Disrupt generates 30 Fury on a successful interrupt.
    erratic_felheart          = {  90996, 391397, 2 }, -- The cooldown of Infernal Strike is reduced by 10%.
    felblade                  = {  95150, 232893, 1 }, -- Charge to your target and deal 19,419 Fire damage. Fracture has a chance to reset the cooldown of Felblade. Generates 40 Fury.
    felfire_haste             = {  90939, 389846, 1 }, -- Infernal Strike increases your movement speed by 10% for 8 sec.
    flames_of_fury            = {  90949, 389694, 2 }, -- Sigil of Flame deals 35% increased damage and generates 1 additional Fury per target hit.
    illidari_knowledge        = {  90935, 389696, 1 }, -- Reduces magic damage taken by 5%.
    imprison                  = {  91007, 217832, 1 }, -- Imprisons a demon, beast, or humanoid, incapacitating them for 1 min. Damage may cancel the effect. Limit 1.
    improved_disrupt          = {  90938, 320361, 1 }, -- Increases the range of Disrupt to 10 yds.
    improved_sigil_of_misery  = {  90945, 320418, 1 }, -- Reduces the cooldown of Sigil of Misery by 30 sec.
    infernal_armor            = {  91004, 320331, 2 }, -- Immolation Aura increases your armor by 20% and causes melee attackers to suffer 2,916 Fire damage.
    internal_struggle         = {  90934, 393822, 1 }, -- Increases your mastery by 3.6%.
    live_by_the_glaive        = {  95151, 428607, 1 }, -- When you parry an attack or have one of your attacks parried, restore 2% of max health and 10 Fury. This effect may only occur once every 5 sec.
    long_night                = {  91001, 389781, 1 }, -- Increases the duration of Darkness by 3 sec.
    lost_in_darkness          = {  90947, 389849, 1 }, -- Spectral Sight has 5 sec reduced cooldown and no longer reduces movement speed. 
    master_of_the_glaive      = {  90994, 389763, 1 }, -- Throw Glaive has 2 charges and snares all enemies hit by 50% for 6 sec.
    pitch_black               = {  91001, 389783, 1 }, -- Reduces the cooldown of Darkness by 120 sec.
    precise_sigils            = {  95155, 389799, 1 }, -- All Sigils are now placed at your target's location.
    pursuit                   = {  90940, 320654, 1 }, -- Mastery increases your movement speed.
    quickened_sigils          = {  95149, 209281, 1 }, -- All Sigils activate 1 second faster.
    rush_of_chaos             = {  95148, 320421, 2 }, -- Reduces the cooldown of Metamorphosis by 30 sec.
    shattered_restoration     = {  90950, 389824, 1 }, -- The healing of Shattered Souls is increased by 10%.
    sigil_of_misery           = {  90946, 207684, 1 }, -- Place a Sigil of Misery at the target location that activates after 1 sec. Causes all enemies affected by the sigil to cower in fear, disorienting them for 17 sec.
    sigil_of_spite            = {  90997, 390163, 1 }, -- Place a demonic sigil at the target location that activates after 1 sec. Detonates to deal 103,800 Chaos damage and shatter up to 3 Lesser Soul Fragments from enemies affected by the sigil. Deals reduced damage beyond 5 targets.
    soul_rending              = {  90936, 204909, 2 }, -- Leech increased by 6%. Gain an additional 6% leech while Metamorphosis is active.
    soul_sigils               = {  90929, 395446, 1 }, -- Afflicting an enemy with a Sigil generates 1 Lesser Soul Fragment. 
    swallowed_anger           = {  91005, 320313, 1 }, -- Consume Magic generates 20 Fury when a beneficial Magic effect is successfully removed from the target.
    the_hunt                  = {  90927, 370965, 1 }, -- Charge to your target, striking them for 135,929 Chaos damage, rooting them in place for 1.5 sec and inflicting 105,579 Chaos damage over 6 sec to up to 5 enemies in your path. The pursuit invigorates your soul, healing you for 25% of the damage you deal to your Hunt target for 20 sec.
    unrestrained_fury         = {  90941, 320770, 1 }, -- Increases maximum Fury by 20.
    vengeful_bonds            = {  90930, 320635, 1 }, -- Vengeful Retreat reduces the movement speed of all nearby enemies by 70% for 3 sec.
    vengeful_retreat          = {  90942, 198793, 1 }, -- Remove all snares and vault away. Nearby enemies take 3,600 Physical damage.
    will_of_the_illidari      = {  91000, 389695, 1 }, -- Increases maximum health by 5%.

    -- Vengeance
    agonizing_flames          = {  90971, 207548, 1 }, -- Immolation Aura increases your movement speed by 10% and its duration is increased by 50%.
    ascending_flame           = {  90960, 428603, 1 }, -- Sigil of Flame's initial damage is increased by 50%. Multiple applications of Sigil of Flame may overlap.
    bulk_extraction           = {  90956, 320341, 1 }, -- Demolish the spirit of all those around you, dealing 7,825 Fire damage to nearby enemies and extracting up to 5 Lesser Soul Fragments, drawing them to you for immediate consumption.
    burning_alive             = {  90959, 207739, 1 }, -- Every 1 sec, Fiery Brand spreads to one nearby enemy.
    burning_blood             = {  90987, 390213, 1 }, -- Fire damage increased by 8%.
    calcified_spikes          = {  90967, 389720, 1 }, -- You take 12% reduced damage after Demon Spikes ends, fading by 1% per second.
    chains_of_anger           = {  90964, 389715, 1 }, -- Increases the duration of your Sigils by 2 sec and radius by 2 yds.
    charred_flesh             = {  90962, 336639, 2 }, -- Immolation Aura damage increases the duration of your Fiery Brand and Sigil of Flame by 0.25 sec.
    cycle_of_binding          = {  90963, 389718, 1 }, -- Sigil of Flame reduces the cooldown of your Sigils by 5 sec.
    darkglare_boon            = {  90985, 389708, 1 }, -- When Fel Devastation finishes fully channeling, it refreshes 15-30% of its cooldown and refunds 15-30 Fury.
    deflecting_spikes         = {  90989, 321028, 1 }, -- Demon Spikes also increases your Parry chance by 15% for 10 sec.
    down_in_flames            = {  90961, 389732, 1 }, -- Fiery Brand has 12 sec reduced cooldown and 1 additional charge.
    extended_spikes           = {  90966, 389721, 1 }, -- Increases the duration of Demon Spikes by 2 sec.
    fallout                   = {  90972, 227174, 1 }, -- Immolation Aura's initial burst has a chance to shatter Lesser Soul Fragments from enemies.
    feast_of_souls            = {  90969, 207697, 1 }, -- Soul Cleave heals you for an additional 33,553 over 6 sec.
    feed_the_demon            = {  90983, 218612, 1 }, -- Consuming a Soul Fragment reduces the remaining cooldown of Demon Spikes by 0.35 sec.
    fel_devastation           = {  90991, 212084, 1 }, -- Unleash the fel within you, damaging enemies directly in front of you for 69,683 Fire damage over 2 sec. Causing damage also heals you for up to 114,962 health.
    fel_flame_fortification   = {  90955, 389705, 1 }, -- You take 10% reduced magic damage while Immolation Aura is active.
    fiery_brand               = {  90951, 204021, 1 }, -- Brand an enemy with a demonic symbol, instantly dealing 50,546 Fire damage and 46,950 Fire damage over 12 sec. The enemy's damage done to you is reduced by 40% for 12 sec.
    fiery_demise              = {  90958, 389220, 2 }, -- Fiery Brand also increases Fire damage you deal to the target by 15%.
    focused_cleave            = {  90975, 343207, 1 }, -- Soul Cleave deals 50% increased damage to your primary target.
    fracture                  = {  90970, 263642, 1 }, -- Rapidly slash your target for 33,941 Physical damage, and shatter 2 Lesser Soul Fragments from them. Generates 25 Fury.
    frailty                   = {  90990, 389958, 1 }, -- Enemies struck by Sigil of Flame are afflicted with Frailty for 6 sec. You heal for 8% of all damage you deal to targets with Frailty.
    illuminated_sigils        = {  90961, 428557, 1 }, -- Sigil of Flame has 5 sec reduced cooldown and 1 additional charge. You have 12% increased chance to parry attacks from enemies afflicted by your Sigil of Flame.
    last_resort               = {  90979, 209258, 1 }, -- Sustaining fatal damage instead transforms you to Metamorphosis form. This may occur once every 8 min.
    meteoric_strikes          = {  90953, 389724, 1 }, -- Reduce the cooldown of Infernal Strike by 10 sec.
    painbringer               = {  90976, 207387, 2 }, -- Consuming a Soul Fragment reduces all damage you take by 1% for 6 sec. Multiple applications may overlap.
    perfectly_balanced_glaive = {  90968, 320387, 1 }, -- Reduces the cooldown of Throw Glaive by 6 sec.
    retaliation               = {  90952, 389729, 1 }, -- While Demon Spikes is active, melee attacks against you cause the attacker to take 3,510 Physical damage. Generates high threat.
    revel_in_pain             = {  90957, 343014, 1 }, -- When Fiery Brand expires on your primary target, you gain a shield that absorbs up 160,940 damage for 15 sec, based on your damage dealt to them while Fiery Brand was active. 
    roaring_fire              = {  90988, 391178, 1 }, -- Fel Devastation heals you for up to 50% more, based on your missing health.
    ruinous_bulwark           = {  90965, 326853, 1 }, -- Fel Devastation heals for an additional 10%, and 100% of its healing is converted into an absorb shield for 10 sec.
    shear_fury                = {  90970, 389997, 1 }, -- Shear generates 10 additional Fury.
    sigil_of_chains           = {  90954, 202138, 1 }, -- Place a Sigil of Chains at the target location that activates after 1 sec. All enemies affected by the sigil are pulled to its center and are snared, reducing movement speed by 70% for 8 sec.
    sigil_of_silence          = {  90988, 202137, 1 }, -- Place a Sigil of Silence at the target location that activates after 1 sec. Silences all enemies affected by the sigil for 6 sec.
    soul_barrier              = {  90956, 263648, 1 }, -- Shield yourself for 15 sec, absorbing 279,615 damage. Consumes all available Soul Fragments to add 74,564 to the shield per fragment.
    soul_carver               = {  90982, 207407, 1 }, -- Carve into the soul of your target, dealing 75,092 Fire damage and an additional 32,588 Fire damage over 3 sec. Immediately shatters 3 Lesser Soul Fragments from the target and 1 additional Lesser Soul Fragment every 1 sec.
    soul_furnace              = {  90974, 391165, 1 }, -- Every 10 Soul Fragments you consume increases the damage of your next Soul Cleave or Spirit Bomb by 40%.
    soulcrush                 = {  90980, 389985, 1 }, -- Multiple applications of Frailty may overlap. Soul Cleave applies Frailty to your primary target for 8 sec.
    soulmonger                = {  90973, 389711, 1 }, -- When consuming a Soul Fragment would heal you above full health it shields you instead, up to a maximum of 184,766.
    spirit_bomb               = {  90978, 247454, 1 }, -- Consume up to 5 available Soul Fragments then explode, damaging nearby enemies for 8,870 Fire damage per fragment consumed, and afflicting them with Frailty for 6 sec, causing you to heal for 8% of damage you deal to them. Deals reduced damage beyond 8 targets.
    stoke_the_flames          = {  90984, 393827, 1 }, -- Fel Devastation damage increased by 35%.
    void_reaver               = {  90977, 268175, 1 }, -- Frailty now also reduces all damage you take from afflicted targets by 3%. Enemies struck by Soul Cleave are afflicted with Frailty for 6 sec.
    volatile_flameblood       = {  90986, 390808, 1 }, -- Immolation Aura generates 5-10 Fury when it deals critical damage. This effect may only occur once per 1 sec.
    vulnerability             = {  90981, 389976, 2 }, -- Frailty now also increases all damage you deal to afflicted targets by 2%.

    -- Aldrachi Reaver
    aldrachi_tactics          = {  94914, 442683, 1 }, -- The second enhanced ability in a pattern shatters an additional Soul Fragment.
    army_unto_oneself         = {  94896, 442714, 1 }, -- Felblade surrounds you with a Blade Ward, reducing damage taken by 10% for 5 sec.
    art_of_the_glaive         = {  94915, 442290, 1, "aldrachi_reaver" }, -- Consuming 20 Soul Fragments or casting The Hunt converts your next Throw Glaive into Reaver's Glaive.  Reaver's Glaive: Throw a glaive enhanced with the essence of consumed souls at your target, dealing 61,066 Physical damage and ricocheting to 3 additional enemies. Begins a well-practiced pattern of glaivework, enhancing your next Fracture and Soul Cleave. The enhanced ability you cast first deals 10% increased damage, and the second deals 20% increased damage.
    evasive_action            = {  94911, 444926, 1 }, -- Vengeful Retreat can be cast a second time within 3 sec.
    fury_of_the_aldrachi      = {  94898, 442718, 1 }, -- When enhanced by Reaver's Glaive, Soul Cleave casts 3 additional glaive slashes to nearby targets. If cast after Fracture, cast 6 slashes instead.
    incisive_blade            = {  94895, 442492, 1 }, -- Soul Cleave deals 10% increased damage.
    incorruptible_spirit      = {  94896, 442736, 1 }, -- Each Soul Fragment you consume shields you for an additional 15% of the amount healed.
    keen_engagement           = {  94910, 442497, 1 }, -- Reaver's Glaive generates 20 Fury.
    preemptive_strike         = {  94910, 444997, 1 }, -- Throw Glaive deals 3,813 Physical damage to enemies near its initial target.
    reavers_mark              = {  94903, 442679, 1 }, -- When enhanced by Reaver's Glaive, Fracture applies Reaver's Mark, which causes the target to take 7% increased damage for 20 sec. If cast after Soul Cleave, Reaver's Mark is increased to 14%.
    thrill_of_the_fight       = {  94919, 442686, 1 }, -- After consuming both enhancements, gain Thrill of the Fight, increasing your attack speed by 15% for 20 sec and your damage and healing by 20% for 10 sec.
    unhindered_assault        = {  94911, 444931, 1 }, -- Vengeful Retreat resets the cooldown of Felblade.
    warblades_hunger          = {  94906, 442502, 1 }, -- Consuming a Soul Fragment causes your next Fracture to deal 7,627 additional Physical damage.
    wounded_quarry            = {  94897, 442806, 1 }, -- Expose weaknesses in the target of your Reaver's Mark, causing your Physical damage to any enemy to also deal 20% of the damage dealt to your marked target as Chaos. 

    -- Fel-Scarred
    burning_blades            = {  94905, 452408, 1 }, -- Your blades burn with Fel energy, causing your Soul Cleave, Throw Glaive, and auto-attacks to deal an additional 40% damage as Fire over 6 sec.
    demonic_intensity         = {  94901, 452415, 1 }, -- Activating Metamorphosis greatly empowers Fel Devastation, Immolation Aura, and Sigil of Flame. Demonsurge damage is increased by 10% for each time it previously triggered while your demon form is active.
    demonsurge                = {  94917, 452402, 1, "felscarred" }, -- Metamorphosis now also greatly empowers Soul Cleave and Spirit Bomb. While demon form is active, the first cast of each empowered ability induces a Demonsurge, causing you to explode with Fel energy, dealing 38,941 Fire damage to nearby enemies.
    enduring_torment          = {  94916, 452410, 1 }, -- The effects of your demon form persist outside of it in a weakened state, increasing maximum health by 5% and Armor by 20%.
    flamebound                = {  94902, 452413, 1 }, -- Immolation Aura has 2 yd increased radius and 30% increased critical strike damage bonus.
    focused_hatred            = {  94918, 452405, 1 }, -- Demonsurge deals 50% increased damage when it strikes a single target. Each additional target reduces this bonus by 10%.
    improved_soul_rending     = {  94899, 452407, 1 }, -- Leech granted by Soul Rending increased by 2% and an additional 2% while Metamorphosis is active.
    monster_rising            = {  94909, 452414, 1 }, -- Agility increased by 8% while not in demon form.
    pursuit_of_angriness      = {  94913, 452404, 1 }, -- Movement speed increased by 1% per 10 Fury.
    set_fire_to_the_pain      = {  94899, 452406, 1 }, -- 5% of all non-Fire damage taken is instead taken as Fire damage over 6 sec. Fire damage taken reduced by 10%.
    student_of_suffering      = {  94902, 452412, 1 }, -- Sigil of Flame applies Student of Suffering to you, increasing Mastery by 14.4% and granting 5 Fury every 2 sec, for 6 sec.
    untethered_fury           = {  94904, 452411, 1 }, -- Maximum Fury increased by 50.
    violent_transformation    = {  94912, 452409, 1 }, -- When you activate Metamorphosis, the cooldowns of your Sigil of Flame and Fel Devastation are immediately reset.
    wave_of_debilitation      = {  94913, 452403, 1 }, -- Chaos Nova slows enemies by 60% and reduces attack and cast speed 15% for 5 sec after its stun fades. 
} )

-- PvP Talents
spec:RegisterPvpTalents( { 
    blood_moon        = 5434, -- (355995) 
    cleansed_by_flame =  814, -- (205625) 
    cover_of_darkness = 5520, -- (357419) 
    demonic_trample   = 3423, -- (205629) Transform to demon form, moving at 175% increased speed for 3 sec, knocking down all enemies in your path and dealing 2347.4 Physical damage. During Demonic Trample you are unaffected by snares but cannot cast spells or use your normal attacks. Shares charges with Infernal Strike.
    detainment        = 3430, -- (205596) 
    everlasting_hunt  =  815, -- (205626) 
    glimpse           = 5522, -- (354489) 
    illidans_grasp    =  819, -- (205630) You strangle the target with demonic magic, stunning them in place and dealing 133,481 Shadow damage over 5 sec while the target is grasped. Can move while channeling. Use Illidan's Grasp again to toss the target to a location within 20 yards.
    jagged_spikes     =  816, -- (205627) 
    rain_from_above   = 5521, -- (206803) You fly into the air out of harm's way. While floating, you gain access to Fel Lance allowing you to deal damage to enemies below. 
    reverse_magic     = 3429, -- (205604) Removes all harmful magical effects from yourself and all nearby allies within 10 yards, and sends them back to their original caster if possible.
    sigil_mastery     = 1948, -- (211489) 
    tormentor         = 1220, -- (207029) You focus the assault on this target, increasing their damage taken by 3% for 6 sec. Each unique player that attacks the target increases the damage taken by an additional 3%, stacking up to 5 times. Your melee attacks refresh the duration of Focused Assault.
    unending_hatred   = 3727, -- (213480) 
} )

-- Auras
spec:RegisterAuras( {
    -- $w1 Soul Fragments consumed. At $?a212612[$442290s1~][$442290s2~], Reaver's Glaive is available to cast.
    art_of_the_glaive = {
        id = 444661,
        duration = 30.0,
        max_stack = 30,
    },
    -- Damage taken reduced by $s1%.
    blade_ward = {
        id = 442715,
        duration = 5.0,
        max_stack = 1,
    },
    -- Versatility increased by $w1%.
    -- https://wowhead.com/beta/spell=355894
    blind_faith = {
        id = 355894,
        duration = 20,
        max_stack = 1
    },
    -- Taking $w1 Chaos damage every $t1 seconds.  Damage taken from $@auracaster's Immolation Aura increased by $s2%.
    -- https://wowhead.com/beta/spell=391191
    burning_wound = {
        id = 391191,
        duration = 15,
        tick_time = 3,
        max_stack = 1
    },
    calcified_spikes = {
        id = 391171,
        duration = 12,
        max_stack = 1
    },
    -- https://www.wowhead.com/spell=1490
    chaos_brand = {
        id = 1490,
        duration = 3600,
        max_stack = 1,
    },
    -- Talent: Stunned.
    -- https://wowhead.com/beta/spell=179057
    chaos_nova = {
        id = 179057,
        duration = 2,
        type = "Magic",
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=196718
    darkness = {
        id = 196718,
        duration = function() return ( talent.long_night.enabled and 11 or 8 ) + ( talent.cover_of_darkness.enabled and 2 or 0 ) end,
        max_stack = 1
    },
    demon_soul = {
        id = 347765,
        duration = 15,
        max_stack = 1,
    },
    -- Armor increased by ${$W2*$AGI/100}.$?s321028[  Parry chance increased by $w1%.][]
    -- https://wowhead.com/beta/spell=203819
    demon_spikes = {
        id = 203819,
        duration = function() return 8 + talent.extended_spikes.rank end,
        max_stack = 1
    },
    -- https://www.wowhead.com/spell=452416
    -- Demonsurge Damage of your next Demonsurge is increased by 10%.  
    demonsurge = {
        id = 452416,
        duration = 12,
        max_stack = 6,
    },
    -- Fake buffs for demonsurge damage procs
    demonsurge_hardcast = {
        id = 452489
    },
    demonsurge_consuming_fire = {},
    demonsurge_fel_desolation = {},
    demonsurge_sigil_of_doom = {},
    demonsurge_soul_sunder = {},
    demonsurge_spirit_burst = {},
    -- Vengeful Retreat may be cast again.
    evasive_action = {
        id = 444929,
        duration = 3.0,
        max_stack = 1,
    },
    feast_of_souls = {
        id = 207693,
        duration = 6,
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=212084
    fel_devastation = {
        id = 212084,
        duration = 2,
        tick_time = 0.2,
        max_stack = 1
    },
    fel_flame_fortification = {
        id = 393009,
        duration = function () return class.auras.immolation_aura.duration end,
        max_stack = 1
    },
    -- Talent: Movement speed increased by $w1%.
    -- https://wowhead.com/beta/spell=389847
    felfire_haste = {
        id = 389847,
        duration = 8,
        max_stack = 1
    },
    -- Talent: Branded, taking $w3 Fire damage every $t3 sec, and dealing $204021s1% less damage to $@auracaster$?s389220[ and taking $w2% more Fire damage from them][].
    -- https://wowhead.com/beta/spell=207744
    fiery_brand = {
        id = 207771,
        duration = 12,
        type = "Magic",
        max_stack = 1,
        copy = "fiery_brand_dot"
    },
    -- Talent: Battling a demon from the Theater of Pain...
    -- https://wowhead.com/beta/spell=391430
    fodder_to_the_flame = {
        id = 391430,
        duration = 25,
        max_stack = 1,
        copy = 329554
    },
    -- Talent: $@auracaster is healed for $w1% of all damage they deal to you.$?$w3!=0[  Dealing $w3% reduced damage to $@auracaster.][]$?$w4!=0[  Suffering $w4% increased damage from $@auracaster.][]
    -- https://wowhead.com/beta/spell=247456
    frailty = {
        id = 247456,
        duration = 5,
        tick_time = 1,
        type = "Magic",
        max_stack = 1
    },
    glaive_flurry = {
        id = 442435,
        duration = 30,
        max_stack = 1
    },
    -- Falling speed reduced.
    -- https://wowhead.com/beta/spell=131347
    glide = {
        id = 131347,
        duration = 3600,
        max_stack = 1
    },
    -- Burning nearby enemies for $258922s1 $@spelldesc395020 damage every $t1 sec.$?a207548[    Movement speed increased by $w4%.][]$?a320331[    Armor increased by $w5%. Attackers suffer $@spelldesc395020 damage.][]
    -- https://wowhead.com/beta/spell=258920
    immolation_aura = {
        id = 258920,
        duration = function () return talent.agonizing_flames.enabled and 9 or 6 end,
        tick_time = 1,
        max_stack = 1
    },
    -- Talent: Incapacitated.
    -- https://wowhead.com/beta/spell=217832
    imprison = {
        id = 217832,
        duration = 60,
        mechanic = "sap",
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Movement speed reduced by $s1%.
    -- https://wowhead.com/beta/spell=213405
    master_of_the_glaive = {
        id = 213405,
        duration = 6,
        mechanic = "snare",
        max_stack = 1
    },
    -- Maximum health increased by $w2%.  Armor increased by $w8%.  $?s235893[Versatility increased by $w5%. ][]$?s263642[Fracture][Shear] generates $w4 additional Fury and one additional Lesser Soul Fragment.
    -- https://wowhead.com/beta/spell=187827
    metamorphosis = {
        id = 187827,
        duration = 15,
        max_stack = 1,
        -- This copy is for SIMC compatability while avoiding managing a virtual buff
        copy = "demonsurge_demonic"
    },
    -- Stunned.
    -- https://wowhead.com/beta/spell=200166
    metamorphosis_stun = {
        id = 200166,
        duration = 3,
        type = "Magic",
        max_stack = 1
    },
    -- Dazed.
    -- https://wowhead.com/beta/spell=247121
    metamorphosis_daze = {
        id = 247121,
        duration = 3,
        type = "Magic",
        max_stack = 1
    },
    -- Agility increased by $w1%.
    monster_rising = {
        id = 452550,
        duration = 3600,
        max_stack = 1
    },
    painbringer = {
        id = 212988,
        duration = 6,
        max_stack = 30
    },
    -- $w3
    pursuit_of_angriness = {
        id = 452404,
        duration = 0.0,
        tick_time = 1.0,
        max_stack = 1,
    },
    reavers_glaive = {
    },
    reavers_mark = {
        id = 442624,
        duration = 20,
        max_stack = 1
    },
    rending_strike = {
        id = 442442,
        duration = 30,
        max_stack = 1
    },
    ruinous_bulwark = {
        id = 326863,
        duration = 10,
        max_stack = 1
    },
    -- Taking $w1 Fire damage every $t1 sec.
    set_fire_to_the_pain = {
        id = 453286,
        duration = 6.0,
        tick_time = 1.0,
        max_stack = 1,
    },
    -- Talent: Movement slowed by $s1%.
    -- https://wowhead.com/beta/spell=204843
    sigil_of_chains = {
        id = 204843,
        duration = function () return 6 + ( 2 * talent.chains_of_anger.rank ) end,
        type = "Magic",
        max_stack = 1
    },
    sigil_of_doom = {
        id = 462030,
        duration = 8,
        max_stack = 1
    },
    sigil_of_doom_active = {
        id = 452490,
        duration = 2,
        max_stack = 1
    },
    -- Talent: Sigil of Flame is active.
    -- https://wowhead.com/beta/spell=204596
    sigil_of_flame_active = {
        id = 204596,
        duration = 2,
        max_stack = 1,
        copy = 389810
    },
    -- Talent: Suffering $w2 $@spelldesc395020 damage every $t2 sec.
    -- https://wowhead.com/beta/spell=204598
    sigil_of_flame = {
        id = 204598,
        duration = function () return 6 + ( 2 * talent.chains_of_anger.rank ) end,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Disoriented.
    -- https://wowhead.com/beta/spell=207685
    sigil_of_misery_debuff = {
        id = 207685,
        duration = function () return 15 + ( 2 * talent.chains_of_anger.rank ) end,
        mechanic = "flee",
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Silenced.
    -- https://wowhead.com/beta/spell=204490
    sigil_of_silence = {
        id = 204490,
        duration = function () return 4 + ( 2 * talent.chains_of_anger.rank ) end,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Absorbs $w1 damage.
    -- https://wowhead.com/beta/spell=263648
    soul_barrier = {
        id = 263648,
        duration = 15,
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Suffering $s1 Fire damage every $t1 sec.
    -- TODO: Trigger more Lesser Soul Fragments...
    -- https://wowhead.com/beta/spell=207407
    soul_carver = {
        id = 207407,
        duration = 3,
        tick_time = 1,
        max_stack = 1
    },
    -- Consume to heal for $210042s1% of your maximum health.
    -- https://wowhead.com/beta/spell=203795
    soul_fragment = {
        id = 203795,
        duration = 20,
        max_stack = 5
    },
    soul_fragments = {
        id = 203981,
        duration = 3600,
        max_stack = 5,
    },
    -- Talent: $w1 Soul Fragments consumed. At $u, the damage of your next Soul Cleave is increased by $391172s1%.
    -- https://wowhead.com/beta/spell=391166
    soul_furnace_stack = {
        id = 391166,
        duration = 30,
        max_stack = 9,
        copy = 339424
    },
    soul_furnace = {
        id = 391172,
        duration = 30,
        max_stack = 1,
        copy = "soul_furnace_damage_amp"
    },
    -- Suffering $w1 Chaos damage every $t1 sec.
    -- https://wowhead.com/beta/spell=390181
    soulrend = {
        id = 390181,
        duration = 6,
        tick_time = 2,
        max_stack = 1
    },
    -- Can see invisible and stealthed enemies.  Can see enemies and treasures through physical barriers.
    -- https://wowhead.com/beta/spell=188501
    spectral_sight = {
        id = 188501,
        duration = 10,
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=247454
    spirit_bomb = {
        id = 247454,
        duration = 1.5,
        max_stack = 1
    },
    spirit_of_the_darkness_flame = {
        id = 337542,
        duration = 3600,
        max_stack = 15
    },
    -- Mastery increased by ${$w1*$mas}.1%. ; Generating $453236s1 Fury every $t2 sec.
    student_of_suffering = {
        id = 453239,
        duration = 6,
        max_stack = 1
    },
    -- Talent: Suffering $w1 $@spelldesc395042 damage every $t1 sec.
    -- https://wowhead.com/beta/spell=345335
    the_hunt_dot = {
        id = 370969,
        duration = 6,
        tick_time = 2,
        type = "Magic",
        max_stack = 1,
        copy = 345335
    },
    -- Talent: Marked by the Demon Hunter, converting $?c1[$345422s1%][$345422s2%] of the damage done to healing.
    -- https://wowhead.com/beta/spell=370966
    the_hunt = {
        id = 370966,
        duration = 30,
        max_stack = 1,
        copy = 323802
    },
    the_hunt_root = {
        id = 370970,
        duration = 1.5,
        max_stack = 1,
        copy = 323996
    },
    -- Attack Speed increased by $w1%
    thrill_of_the_fight = {
        id = 442695,
        duration = 20.0,
        max_stack = 1,
        copy = "thrill_of_the_fight_attack_speed"
    },
    thrill_of_the_fight_damage = {
        id = 442688,
        duration = 10,
        max_stack = 1
    },
    -- Taunted.
    -- https://wowhead.com/beta/spell=185245
    torment = {
        id = 185245,
        duration = 3,
        max_stack = 1
    },
    -- Talent: Movement speed reduced by $s1%.
    -- https://wowhead.com/beta/spell=198813
    vengeful_retreat = {
        id = 198813,
        duration = 3,
        max_stack = 1
    },
    void_reaver = {
        id = 268178,
        duration = 12,
        max_stack = 1,
    },
    -- Your next $?a212612[Chaos Strike]?s263642[Fracture][Shear] will deal $442507s1 additional Physical damage.
    warblades_hunger = {
        id = 442503,
        duration = 30.0,
        max_stack = 1,
    },

    -- PvP Talents
    demonic_trample = {
        id = 205629,
        duration = 3,
        max_stack = 1,
    },
    everlasting_hunt = {
        id = 208769,
        duration = 3,
        max_stack = 1,
    },
    focused_assault = { -- Tormentor.
        id = 206891,
        duration = 6,
        max_stack = 5,
    },
    illidans_grasp = {
        id = 205630,
        duration = 6,
        type = "Magic",
        max_stack = 1,
    },
} )

spec:RegisterStateExpr( "soul_fragments", function ()
    return buff.soul_fragments.stack
end )

spec:RegisterStateExpr( "last_infernal_strike", function ()
    return action.infernal_strike.lastCast
end )

spec:RegisterStateExpr( "activation_time", function()
    return talent.quickened_sigils.enabled and 1 or 2
end )

spec:RegisterStateTable( "fragments", {
    real = 0,
    realTime = 0,
} )

spec:RegisterStateFunction( "queue_fragments", function( num, extraTime )
    fragments.real = fragments.real + num
    fragments.realTime = GetTime() + 1.25 + ( extraTime or 0 )
end )

spec:RegisterStateFunction( "purge_fragments", function()
    fragments.real = 0
    fragments.realTime = 0
end )


-- Variable to track the total bonus timed earned on fiery brand from immolation aura.
local bonus_time_from_immo_aura = 0
-- Variable to track the GUID of the initial target
local initial_fiery_brand_guid = ""

spec:RegisterHook( "COMBAT_LOG_EVENT_UNFILTERED", function( _ , subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID ~= GUID then return end

    if talent.charred_flesh.enabled and subtype == "SPELL_DAMAGE" and spellID == 258922 and destGUID == initial_fiery_brand_guid then
        bonus_time_from_immo_aura = bonus_time_from_immo_aura + ( 0.25 * talent.charred_flesh.rank )

    elseif subtype == "SPELL_CAST_SUCCESS" then
        if talent.charred_flesh.enabled and spellID == 204021 then
            bonus_time_from_immo_aura = 0
            initial_fiery_brand_guid = destGUID
        end

        -- Fracture:  Generate 2 frags.
        if spellID == 263642 then
            queue_fragments( 2 )
        end

        -- Shear:  Generate 1 frag.
        if spellID == 203782 then
            queue_fragments( 1 )
        end

        -- We consumed or generated a fragment for real, so let's purge the real queue.
    elseif spellID == 203981 and fragments.real > 0 and ( subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_APPLIED_DOSE" ) then
        fragments.real = fragments.real - 1

    end
end, false )

local sigil_types = { "chains", "flame", "misery", "silence" }

-- Abilities that may trigger Demonsurge.
local demonsurge = {
    demonic = { "soul_sunder", "spirit_burst" },
    hardcast = { "consuming_fire", "fel_desolation", "sigil_of_doom" },
}

spec:RegisterHook( "reset_precast", function ()
    if fragments.realTime > 0 and fragments.realTime < now then
        fragments.real = 0
        fragments.realTime = 0
    end

    if buff.demonic_trample.up then
        setCooldown( "global_cooldown", max( cooldown.global_cooldown.remains, buff.demonic_trample.remains ) )
    end

    if buff.illidans_grasp.up then
        setCooldown( "illidans_grasp", 0 )
    end

    if buff.soul_fragments.down then
        -- Apply the buff with zero stacks.
        applyBuff( "soul_fragments", nil, 0 + fragments.real )
    elseif fragments.real > 0 then
        addStack( "soul_fragments", nil, fragments.real )
    end

    if IsSpellKnownOrOverridesKnown( 442294 ) then
        applyBuff( "reavers_glaive" )
        if Hekili.ActiveDebug then Hekili:Debug( "Applied Reaver's Glaive." ) end
    end

    if talent.demonsurge.enabled and buff.metamorphosis.up then
        local metaRemains = buff.metamorphosis.remains

        for _, name in ipairs( demonsurge.demonic ) do
            if IsSpellOverlayed( class.abilities[ name ].id ) then
                applyBuff( "demonsurge_" .. name, metaRemains )
            end
        end
        if talent.demonic_intensity.enabled then
            local metaApplied = ( buff.metamorphosis.applied - 0.005 ) -- fudge-factor because GetTime has ms precision
            if action.metamorphosis.lastCast >= metaApplied or action.fel_desolation.lastCast >= metaApplied then
                applyBuff( "demonsurge_hardcast", metaRemains )
            end
            for _, name in ipairs( demonsurge.hardcast ) do
                if IsSpellOverlayed( class.abilities[ name ].id ) then
                    applyBuff( "demonsurge_" .. name, metaRemains )
                end
            end
        end

        if Hekili.ActiveDebug then
            Hekili:Debug( "Demonsurge status:\n" ..
                " - Hardcast " .. ( buff.demonsurge_hardcast.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Demonic " .. ( buff.demonsurge_demonic.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Consuming Fire " .. ( buff.demonsurge_consuming_fire.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Fel Desolation " .. ( buff.demonsurge_fel_desolation.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Sigil of Doom " .. ( buff.demonsurge_sigil_of_doom.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Soul Sunder " .. ( buff.demonsurge_soul_sunder.up and "ACTIVE" or "INACTIVE" ) .. "\n" ..
                " - Spirit Burst " .. ( buff.demonsurge_spirit_burst.up and "ACTIVE" or "INACTIVE" ) )
        end
    end

    fiery_brand_dot_primary_expires = nil
    fury_spent = nil
end )

spec:RegisterHook( "spend", function( amt, resource )
    if set_bonus.tier31_4pc == 0 or amt < 0 or resource ~= "fury" then return end

    fury_spent = fury_spent + amt
    if fury_spent > 40 then
        reduceCooldown( "sigil_of_flame", floor( fury_spent / 40 ) )
        fury_spent = fury_spent % 40
    end
end )

-- approach that actually calculated time remaining of fiery_brand via combat log. last modified 1/27/2023.
spec:RegisterStateExpr( "fiery_brand_dot_primary_expires", function()
    return action.fiery_brand.lastCast + bonus_time_from_immo_aura + class.auras.fiery_brand.duration
end )

spec:RegisterStateExpr( "fiery_brand_dot_primary_remains", function()
    return max( 0, fiery_brand_dot_primary_expires - query_time )
end )

spec:RegisterStateExpr( "fiery_brand_dot_primary_ticking", function()
    return fiery_brand_dot_primary_remains > 0
end )

--[[
-- Incoming Souls calculation added to APL in August 2023.
spec:RegisterVariable( "incoming_souls", function()
    -- actions+=/variable,name=incoming_souls,op=reset
    local souls = 0
    
    -- actions+=/variable,name=incoming_souls,op=add,value=2,if=prev_gcd.1.fracture&!buff.metamorphosis.up
    if action.fracture.time_since < ( 0.25 + gcd.max ) and not buff.metamorphosis.up then souls = souls + 2 end

    -- actions+=/variable,name=incoming_souls,op=add,value=3,if=prev_gcd.1.fracture&buff.metamorphosis.up
    if action.fracture.time_since < ( 0.25 + gcd.max ) and buff.metamorphosis.up then souls = souls + 3 end

    -- actions+=/variable,name=incoming_souls,op=add,value=2,if=talent.soul_sigils&(prev_gcd.2.sigil_of_flame|prev_gcd.2.sigil_of_silence|prev_gcd.2.sigil_of_chains|prev_gcd.2.elysian_decree)
    if talent.soul_sigils.enabled and ( ( action.sigil_of_flame.time_since < ( 0.25 + 2 * gcd.max ) and action.sigil_of_flame.time_since > gcd.max ) or
        ( action.sigil_of_silence.time_since < ( 0.25 + 2 * gcd.max ) and action.sigil_of_silence.time_since > gcd.max ) or
        ( action.sigil_of_chains.time_since  < ( 0.25 + 2 * gcd.max ) and action.sigil_of_chains.time_since  > gcd.max ) or
        ( action.elysian_decree.time_since   < ( 0.25 + 2 * gcd.max ) and action.elysian_decree.time_since   > gcd.max ) ) then
        souls = souls + 2
    end

    -- actions+=/variable,name=incoming_souls,op=add,value=active_enemies>?3,if=talent.elysian_decree&prev_gcd.2.elysian_decree
    if talent.elysian_decree.enabled and ( action.elysian_decree.time_since < ( 0.25 + 2 * gcd.max ) and action.elysian_decree.time_since > gcd.max ) then
        souls = souls + min( 3, active_enemies )
    end

    -- actions+=/variable,name=incoming_souls,op=add,value=0.6*active_enemies>?5,if=talent.fallout&prev_gcd.1.immolation_aura
    if talent.fallout.enabled and action.immolation_aura.time_since < ( 0.25 + gcd.max ) then souls = souls + ( 0.6 * min( 5, active_enemies ) ) end

    -- actions+=/variable,name=incoming_souls,op=add,value=active_enemies>?5,if=talent.bulk_extraction&prev_gcd.1.bulk_extraction
    if talent.bulk_extraction.enabled and action.bulk_extraction.time_since < ( 0.25 + gcd.max ) then souls = souls + min( 5, active_enemies ) end

    -- actions+=/variable,name=incoming_souls,op=add,value=3-(cooldown.soul_carver.duration-ceil(cooldown.soul_carver.remains)),if=talent.soul_carver&cooldown.soul_carver.remains>57
    if talent.soul_carver.enabled and cooldown.soul_carver.true_remains > 57 then souls = souls + ( 3 - ( cooldown.soul_carver.duration - ceil( cooldown.soul_carver.remains ) ) ) end

    return souls
end )--]]

-- The War Within
spec:RegisterGear( "tww2", 229316, 229314, 229319, 229317, 229315 )

-- Dragonflight
spec:RegisterGear( "tier29", 200345, 200347, 200342, 200344, 200346 )
spec:RegisterAura( "decrepit_souls", {
    id = 394958,
    duration = 8,
    max_stack = 1
} )
spec:RegisterGear( "tier30", 202527, 202525, 202524, 202523, 202522 )
-- 2 pieces (Vengeance) : Soul Fragments heal for 10% more and generating a Soul Fragment increases your Fire damage by 2% for 6 sec. Multiple applications may overlap.
-- TODO: Track each application to keep count for Recrimination.
spec:RegisterAura( "fires_of_fel", {
    id = 409645,
    duration = 6,
    max_stack = 1
} )
-- 4 pieces (Vengeance) : Shear and Fracture deal Fire damage, and after consuming 20 Soul Fragments, your next cast of Shear or Fracture will apply Fiery Brand for 6 sec to its target.
spec:RegisterAura( "recrimination", {
    id = 409877,
    duration = 30,
    max_stack = 1
} )
spec:RegisterGear( "tier31", 207261, 207262, 207263, 207264, 207266, 217228, 217230, 217226, 217227, 217229 )
-- (2) When you attack a target afflicted by Sigil of Flame, your damage and healing are increased by 2% and your Stamina is increased by 2% for 8 sec, stacking up to 5.
-- (4) Sigil of Flame's periodic damage has a chance to flare up, shattering an additional Soul Fragment from a target and dealing $425672s1 additional damage. Each $s1 Fury you spend reduces its cooldown by ${$s2/1000}.1 sec.
spec:RegisterAura( "fiery_resolve", {
    id = 425653,
    duration = 8,
    max_stack = 5
} )

local furySpent = 0

local FURY = Enum.PowerType.Fury
local lastFury = -1

spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( event, unit, powerType )
    if powerType == "FURY" and state.set_bonus.tier31_4pc > 0 then
        local current = UnitPower( "player", FURY )

        if current < lastFury - 3 then
            furySpent = ( furySpent + lastFury - current )
        end

        lastFury = current
    end
end )

spec:RegisterStateExpr( "fury_spent", function ()
    if set_bonus.tier31_4pc == 0 then return 0 end
    return furySpent
end )

-- Legacy
spec:RegisterGear( "tier19", 138375, 138376, 138377, 138378, 138379, 138380 )
spec:RegisterGear( "tier20", 147130, 147132, 147128, 147127, 147129, 147131 )
spec:RegisterGear( "tier21", 152121, 152123, 152119, 152118, 152120, 152122 )
spec:RegisterGear( "class", 139715, 139716, 139717, 139718, 139719, 139720, 139721, 139722 )
spec:RegisterGear( "convergence_of_fates", 140806 )

local ConsumeSoulFragments = setfenv( function( amt )
    if talent.soul_furnace.enabled then
        local overflow = buff.soul_furnace_stack.stack + amt
        if overflow >= 10 then
            applyBuff( "soul_furnace" )
            overflow = overflow - 10
            if overflow > 0 then -- stacks carry over past 10 to start a new stack
                applyBuff( "soul_furnace_stack", nil, overflow )
            end
        else
            addStack( "soul_furnace_stack", nil, amt )
        end
    end
    -- Reaver Tree
    if talent.art_of_the_glaive.enabled then
        addStack( "art_of_the_glaive", nil, amt )
        if  buff.art_of_the_glaive.stack == 20 then
            removeBuff( "art_of_the_glaive" )
            applyBuff( "reavers_glaive" )
        end
    end
    if talent.warblades_hunger.enabled then
        addStack( "warblades_hunger", nil, amt )
    end

    gainChargeTime( "demon_spikes", ( 0.35 * talent.feed_the_demon.rank * amt ) )
    buff.soul_fragments.count = max( 0, buff.soul_fragments.stack - amt )
end, state )

local sigilList = { "sigil_of_flame", "sigil_of_misery", "sigil_of_spite", "sigil_of_silence", "sigil_of_chains", "sigil_of_doom" }

local TriggerDemonic = setfenv( function()
    local demonicExtension = 7

    if buff.metamorphosis.up then
        buff.metamorphosis.expires = buff.metamorphosis.expires + demonicExtension
        -- Fel-Scarred
        if talent.demonsurge.enabled then
            local metaExpires = buff.metamorphosis.expires

            for _, name in ipairs( demonsurge.demonic ) do
                local aura = buff[ "demonsurge_" .. name ]
                if aura.up then aura.expires = metaExpires end
            end

            if talent.demonic_intensity.enabled and buff.demonsurge_hardcast.up then
                buff.demonsurge_hardcast.expires = metaExpires

                for _, name in ipairs( demonsurge.hardcast ) do
                    local aura = buff[ "demonsurge_" .. name ]
                    if aura.up then aura.expires = metaExpires end
                end
            end
        end
    else
        applyBuff( "metamorphosis", demonicExtension )
        if talent.inner_demon.enabled then applyBuff( "inner_demon" ) end
        -- Fel-Scarred
        if talent.demonsurge.enabled then
            local metaRemains = buff.metamorphosis.remains

            for _, name in ipairs( demonsurge.demonic ) do
                applyBuff( "demonsurge_" .. name, metaRemains )
            end
        end
    end
end, state )

-- Abilities
spec:RegisterAbilities( {
    -- Talent: Demolish the spirit of all those around you, dealing $s1 Fire damage to nearby enemies and extracting up to $s2 Lesser Soul Fragments, drawing them to you for immediate consumption.
    bulk_extraction = {
        id = 320341,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "fire",

        talent = "bulk_extraction",
        startsCombat = true,
        texture = 136194,

        toggle = "cooldowns",

        handler = function ()
        end,
    },

    -- Talent: Unleash an eruption of fel energy, dealing $s2 Chaos damage and stunning all nearby enemies for $d.$?s320412[    Each enemy stunned by Chaos Nova has a $s3% chance to generate a Lesser Soul Fragment.][]
    chaos_nova = {
        id = 179057,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "chromatic",

        spend = 25,
        spendType = "fury",

        talent = "chaos_nova",
        startsCombat = true,
        texture = 135795,

        handler = function ()
            applyDebuff( "target", "chaos_nova" )
        end,
    },

    -- Talent: Consume $m1 beneficial Magic effect removing it from the target$?s320313[ and granting you $s2 Fury][].
    consume_magic = {
        id = 278326,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "chromatic",

        talent = "consume_magic",
        startsCombat = false,

        toggle = "interrupts",
        buff = "dispellable_magic",

        handler = function ()
            removeBuff( "dispellable_magic" )
            if talent.swallowed_anger.enabled then gain( 20, "fury" ) end
        end,
    },

    -- Summons darkness around you in a$?a357419[ 12 yd][n 8 yd] radius, granting friendly targets a $209426s2% chance to avoid all damage from an attack. Lasts $d.; Chance to avoid damage increased by $s3% when not in a raid.
    darkness = {
        id = 196718,
        cast = 0,
        cooldown = function() return talent.pitch_black.enabled and 180 or 300 end,
        gcd = "spell",
        school = "physical",

        talent = "darkness",
        startsCombat = false,
        texture = 1305154,

        toggle = "defensives",

        handler = function ()
            last_darkness = query_time
            applyBuff( "darkness" )
        end,
    },

    -- Surge with fel power, increasing your Armor by ${$203819s2*$AGI/100}$?s321028[, and your Parry chance by $203819s1%, for $203819d][].
    demon_spikes = {
        id = 203720,
        cast = 0,
        charges = 2,
        cooldown = 20,
        recharge = 20,
        hasteCD = true,

        icd = 1.5,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        toggle = "defensives",
        defensive = true,

        handler = function ()
            if talent.calcified_spikes.enabled and buff.demon_spikes.up then applyBuff( "calcified_spikes" ) end
            applyBuff( "demon_spikes", buff.demon_spikes.remains + buff.demon_spikes.duration )
        end,
    },

    demonic_trample = {
        id = 205629,
        cast = 0,
        charges = 2,
        cooldown = 12,
        recharge = 12,
        gcd = "spell",
        icd = 0.8,

        pvptalent = "demonic_trample",
        nobuff = "demonic_trample",

        startsCombat = false,
        texture = 134294,
        nodebuff = "rooted",

        handler = function ()
            spendCharges( "infernal_strike", 1 )
            setCooldown( "global_cooldown", 3 )
            applyBuff( "demonic_trample" )
        end,
    },

    -- Interrupts the enemy's spellcasting and locks them from that school of magic for $d.|cFFFFFFFF$?s183782[    Generates $218903s1 Fury on a successful interrupt.][]|r
    disrupt = {
        id = 183752,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "chromatic",

        startsCombat = true,

        toggle = "interrupts",
        interrupt = true,

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            if talent.disrupting_fury.enabled then gain( 30, "fury" ) end
            interrupt()
        end,
    },

    -- Talent: Unleash the fel within you, damaging enemies directly in front of you for ${$212105s1*(2/$t1)} Fire damage over $d.$?s320639[ Causing damage also heals you for up to ${$212106s1*(2/$t1)} health.][]
    fel_devastation = {
		id = 212084,
        cast = 2,
        channeled = true,
        cooldown = 40,
        fixedCast = true,
        gcd = "spell",
        school = "fire",

        spend = 50,
        spendType = "fury",

        talent = "fel_devastation",
        startsCombat = true,
        texture = 1450143,
        nobuff = function () return talent.demonic_intensity.enabled and "metamorphosis" or nil end,

        start = function ()
            applyBuff( "fel_devastation" )
            if talent.demonic.enabled then TriggerDemonic() end
        end,

        finish = function ()
            if talent.darkglare_boon.enabled then
                gain( 15, "fury" )
                reduceCooldown( "fel_devastation", 6 )
            end
            if talent.ruinous_bulwark.enabled then applyBuff( "ruinous_bulwark" ) end
        end,

        bind = "fel_desolation"
    },

    fel_desolation = {
		id = 452486,
        known = 212084,
        cast = 2,
        channeled = true,
        cooldown = 40,
        fixedCast = true,
        gcd = "spell",
        school = "fire",

        spend = 50,
        spendType = "fury",

        talent = "demonic_intensity",
        startsCombat = true,
        texture = 135798,
        buff = "demonsurge_hardcast",

        start = function ()
            if buff.demonsurge_fel_desolation.up then
                removeBuff( "demonsurge_fel_desolation" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
            spec.abilities.fel_devastation.start()
        end,

        finish = function ()
            spec.abilities.fel_devastation.finish()
        end,

        bind = "fel_devastation"
    },

    -- Talent: Charge to your target and deal $213243sw2 $@spelldesc395020 damage.    $?s203513[Shear has a chance to reset the cooldown of Felblade.    |cFFFFFFFFGenerates $213243s3 Fury.|r]?a203555[Demon Blades has a chance to reset the cooldown of Felblade.    |cFFFFFFFFGenerates $213243s3 Fury.|r][Demon's Bite has a chance to reset the cooldown of Felblade.    |cFFFFFFFFGenerates $213243s3 Fury.|r]
    felblade = {
        id = 232893,
        cast = 0,
        cooldown = 15,
        hasteCD = true,
        gcd = "spell",
        school = "physical",

        spend = -40,
        spendType = "fury",

        talent = "felblade",
        startsCombat = true,
        nodebuff = "rooted",

        handler = function ()
            setDistance( 5 )
        end,
    },

    -- Talent: Brand an enemy with a demonic symbol, instantly dealing $sw2 Fire damage$?s320962[ and ${$207771s3*$207744d} Fire damage over $207744d][]. The enemy's damage done to you is reduced by $s1% for $207744d.
    fiery_brand = {
        id = 204021,
        cast = 0,
        charges = function() return talent.down_in_flames.enabled and 2 or nil end,
        cooldown = function() return ( talent.down_in_flames.enabled and 48 or 60 ) + ( conduit.fel_defender.mod * 0.001 ) end,
        recharge = function() return talent.down_in_flames.enabled and ( 48 + ( conduit.fel_defender.mod * 0.001 ) ) or nil end,
        gcd = "spell",
        school = "fire",

        talent = "fiery_brand",
        startsCombat = true,

        readyTime = function ()
            if ( settings.brand_charges or 1 ) == 0 then return end
            return ( ( 1 + ( settings.brand_charges or 1 ) ) - cooldown.fiery_brand.charges_fractional ) * cooldown.fiery_brand.recharge
        end,

        handler = function ()
            applyDebuff( "target", "fiery_brand_dot" )
            fiery_brand_dot_primary_expires = query_time + class.auras.fiery_brand.duration
            removeBuff( "spirit_of_the_darkness_flame" )

            if talent.charred_flesh.enabled then applyBuff( "charred_flesh" ) end
        end,
    },

    -- Talent: Rapidly slash your target for ${$225919sw1+$225921sw1} Physical damage, and shatter $s1 Lesser Soul Fragments from them.    |cFFFFFFFFGenerates $s4 Fury.|r
    fracture = {
        id = 263642,
        cast = 0,
        charges = 2,
        cooldown = 4.5,
        recharge = 4.5,
        hasteCD = true,
        gcd = "spell",
        school = "physical",

        spend = function() return ( buff.metamorphosis.up and -45 or -25 ) end,
        spendType = "fury",

        talent = "fracture",
        bind = "shear",
        startsCombat = true,

        handler = function ()

            spec.abilities.shear.handler()
            addStack( "soul_fragments", nil, 1 )

        end,
    },

    illidans_grasp = {
        id = function () return debuff.illidans_grasp.up and 208173 or 205630 end,
        known = 205630,
        cast = 0,
        channeled = true,
        cooldown = function () return buff.illidans_grasp.up and ( 54 + buff.illidans_grasp.remains ) or 0 end,
        gcd = "off",

        pvptalent = "illidans_grasp",
        aura = "illidans_grasp",
        breakable = true,

        startsCombat = true,
        texture = function () return buff.illidans_grasp.up and 252175 or 1380367 end,

        start = function ()
            if buff.illidans_grasp.up then removeBuff( "illidans_grasp" )
            else applyBuff( "illidans_grasp" ) end
        end,

        copy = { 205630, 208173 }
    },

    -- Engulf yourself in flames, $?a320364 [instantly causing $258921s1 $@spelldesc395020 damage to enemies within $258921A1 yards and ][]radiating ${$258922s1*$d} $@spelldesc395020 damage over $d.$?s320374[    |cFFFFFFFFGenerates $<havocTalentFury> Fury over $d.|r][]$?(s212612 & !s320374)[    |cFFFFFFFFGenerates $<havocFury> Fury.|r][]$?s212613[    |cFFFFFFFFGenerates $<vengeFury> Fury over $d.|r][]
    immolation_aura = {
        id = function() return buff.demonsurge_hardcast.up and 452487 or 258920 end,
        cast = 0,
        cooldown = 15,
        hasteCD = true,

        gcd = "spell",
        school = "fire",
        texture = function() return buff.demonsurge_hardcast.up and 135794 or 1344649 end,
        -- nobuff = "demonsurge_hardcast",

        spend = -8,
        spendType = "fury",
        startsCombat = true,

        handler = function ()
            applyBuff( "immolation_aura" )
            if legendary.fel_flame_fortification.enabled then applyBuff( "fel_flame_fortification" ) end
            if pvptalent.cleansed_by_flame.enabled then
                removeDebuff( "player", "reversible_magic" )
            end

            if talent.fallout.enabled then
                addStack( "soul_fragments", nil, active_enemies < 3 and 1 or 2 )
            end

            -- Fel-Scarred
            if buff.demonsurge_consuming_fire.up then
                removeBuff( "demonsurge_consuming_fire" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end

        end,

        tick = function ()
            if talent.charred_flesh.enabled then
                if debuff.fiery_brand.up then applyDebuff( "target", debuff.fiery_brand.remains + 0.25 * talent.charred_flesh.rank ) end
                if debuff.sigil_of_flame.up then applyDebuff( "target", debuff.sigil_of_flame.remains + 0.25 * talent.charred_flesh.rank ) end
            end
        end,

        bind = "consuming_fire",
        copy = "consuming_fire"
    },

    --[[consuming_fire = {
        id = 452487,
        known = 258920,
        cast = 0,
        cooldown = 15,
        hasteCD = true,
        gcd = "spell",
        school = "fire",
        texture = 135794,

        spend = -8,
        spendType = "fury",
        startsCombat = true,
        talent = "demonic_intensity",
        buff = "demonsurge_hardcast",

        handler = function ()
            applyBuff( "immolation_aura" )
            if legendary.fel_flame_fortification.enabled then applyBuff( "fel_flame_fortification" ) end
            if pvptalent.cleansed_by_flame.enabled then
                removeDebuff( "player", "reversible_magic" )
            end

            if talent.fallout.enabled then
                addStack( "soul_fragments", nil, active_enemies < 3 and 1 or 2 )
            end
            if buff.demonsurge_consuming_fire.up then
                removeBuff( "demonsurge_consuming_fire" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
        end,

        bind = "immolation_aura",
    },--]]

    -- Talent: Imprisons a demon, beast, or humanoid, incapacitating them for $d. Damage will cancel the effect. Limit 1.
    imprison = {
        id = 217832,
        cast = 0,
        cooldown = function () return pvptalent.detainment.enabled and 60 or 45 end,
        gcd = "spell",
        school = "shadow",

        talent = "imprison",
        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "imprison" )
        end,
    },

    -- Leap through the air toward a targeted location, dealing $189112s1 Fire damage to all enemies within $189112a1 yards.
    infernal_strike = {
        id = 189110,
        cast = 0,
        charges = function() return talent.blazing_path.enabled and 2 or nil end,
        cooldown = function() return ( 20 - ( 10 * talent.meteoric_strikes.rank ) ) * ( 1 - 0.1 * talent.erratic_felheart.rank ) end,
        recharge = function() return talent.blazing_path.enabled and ( 20 - ( 10 * talent.meteoric_strikes.rank ) ) * ( 1 - 0.1 * talent.erratic_felheart.rank ) or nil end,

        gcd = "off",
        school = "physical",
        icd = function () return gcd.max + 0.1 end,

        startsCombat = false,
        nodebuff = "rooted",

        readyTime = function ()
            if ( settings.infernal_charges or 1 ) == 0 then return end
            return ( ( 1 + ( settings.infernal_charges or 1 ) ) - cooldown.infernal_strike.charges_fractional ) * cooldown.infernal_strike.recharge
        end,

        handler = function ()
            setDistance( 5 )
            spendCharges( "demonic_trample", 1 )

            if talent.felfire_haste.enabled or conduit.felfire_haste.enabled then applyBuff( "felfire_haste" ) end
        end,
    },

    -- Transform to demon form for $d, increasing current and maximum health by $s2% and Armor by $s8%$?s235893[. Versatility increased by $s5%][]$?s321067[. While transformed, Shear and Fracture generate one additional Lesser Soul Fragment][]$?s321068[ and $s4 additional Fury][].
    metamorphosis = {
        id = 187827,
        cast = 0,
        cooldown = function() return ( 180 - ( 30 * talent.rush_of_chaos.rank) ) end,
        gcd = "off",
        school = "chaos",

        startsCombat = false,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "metamorphosis", buff.metamorphosis.remains + 15 )
            gain( health.max * 0.4, "health" )

            if talent.demonsurge.enabled then
                local metaRemains = buff.metamorphosis.remains

                for _, name in ipairs( demonsurge.demonic ) do
                    applyBuff( "demonsurge_ " .. name, metaRemains )
                end

                if talent.violent_transformation.enabled then
                    setCooldown( "sigil_of_flame", 0 )
                    setCooldown( "fel_devastation", 0 )
                    if talent.demonic_intensity.enabled then
                        setCooldown( "sigil_of_doom", 0 )
                        setCooldown( "fel_desolation", 0 )
                    end
                end

                if talent.demonic_intensity.enabled then
                    removeBuff( "demonsurge" )
                    applyBuff( "demonsurge_hardcast", metaRemains )

                    for _, name in ipairs( demonsurge.hardcast ) do
                        applyBuff( "demonsurge_ " .. name, metaRemains )
                    end
                end
            end
        end,
    },

    reverse_magic = {
        id = 205604,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        -- toggle = "cooldowns",
        pvptalent = "reverse_magic",

        startsCombat = false,
        texture = 1380372,

        buff = "reversible_magic",

        handler = function ()
            if debuff.reversible_magic.up then removeDebuff( "player", "reversible_magic" ) end
        end,
    },

    -- Shears an enemy for $s1 Physical damage, and shatters $?a187827[two Lesser Soul Fragments][a Lesser Soul Fragment] from your target.    |cFFFFFFFFGenerates $m2 Fury.|r
    shear = {
        id = 203782,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function () return -1 * ( 10 + 10 * talent.shear_fury.rank + ( buff.metamorphosis.up and 20 or 0 ) ) end,

        notalent = "fracture",
        bind = "fracture",
        startsCombat = true,

        handler = function ()
            if buff.rending_strike.up then -- Reaver stuff
                applyDebuff( "target", "reavers_mark" )
                removeBuff( "rending_strike" )
                if talent.thrill_of_the_fight.enabled and buff.glaive_flurry.down then
                    applyBuff( "thrill_of_the_fight" )
                    applyBuff( "thrill_of_the_fight_damage" )
                end
            end

            -- Legacy
            if buff.recrimination.up then
                applyDebuff( "target", "fiery_brand", 6 )
                removeBuff( "recrimination" )
            end

            addStack( "soul_fragments", nil, buff.metamorphosis.up and 2 or 1 )
        end,
    },

    -- Talent: Place a Sigil of Chains at the target location that activates after $d.    All enemies affected by the sigil are pulled to its center and are snared, reducing movement speed by $204843s1% for $204843d.
    sigil_of_chains = {
        id = function() return talent.precise_sigils.enabled and 389807 or 202138 end,
        known = 202138,
        cast = 0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 90 end,
        gcd = "spell",
        school = "physical",

        talent = "sigil_of_chains",
        startsCombat = false,

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_chains.lastCast + activation_time end,
        impact = function ()
            applyDebuff( "target", "sigil_of_chains" )
        end,

        copy = { 202138, 389807 }
    },

    -- Talent: Place a Sigil of Flame at your location that activates after $d.    Deals $204598s1 Fire damage, and an additional $204598o3 Fire damage over $204598d, to all enemies affected by the sigil.    |CFFffffffGenerates $389787s1 Fury.|R
    sigil_of_flame = {
        id = function () return talent.precise_sigils.enabled and 389810 or 204596 end,
        known = 204596,
        cast = 0,
        cooldown = function() return ( pvptalent.sigil_of_mastery.enabled and 0.75 or 1 ) * 30 - ( talent.illuminated_sigils.enabled and 5 or 0 ) end,
        charges = function () return talent.illuminated_sigils.enabled and 2 or 1 end,
        recharge = function() return ( pvptalent.sigil_of_mastery.enabled and 0.75 or 1 ) * 30 - ( talent.illuminated_sigils.enabled and 5 or 0 ) end,
        gcd = "spell",
        icd = function() return 0.25 + activation_time end,
        school = "physical",

        spend = -30,
        spendType = "fury",

        startsCombat = false,
        texture = 1344652,
        nobuff = "demonsurge_hardcast",

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_flame.lastCast + activation_time end,

        handler = function ()
            if talent.cycle_of_binding.enabled then
                for _, sigil in ipairs( sigilList ) do
                    reduceCooldown( sigil, 5 )
                end
            end
        end,

        impact = function()
            applyDebuff( "target", "sigil_of_flame" )
            active_dot.sigil_of_flame = active_enemies
            if talent.soul_sigils.enabled then addStack( "soul_fragments", nil, 1 ) end
            if talent.student_of_suffering.enabled then applyBuff( "student_of_suffering" ) end
            if talent.flames_of_fury.enabled then gain( talent.flames_of_fury.rank * active_enemies, "fury" ) end
            if talent.frailty.enabled then
                if talent.soulcrush.enabled and debuff.frailty.up then
                    -- Soulcrush allows for multiple applications of Frailty.
                    applyDebuff( "target", "frailty", nil, debuff.frailty.stack + 1 )
                else
                    applyDebuff( "target", "frailty" )
                end
                active_dot.frailty = active_enemies
            end
        end,

        bind = "sigil_of_doom",
        copy = { 204596, 389810 }
    },

    sigil_of_doom = {
        id = function () return talent.precise_sigils.enabled and 469991 or 452490 end,
        known = 204596,
        cast = 0,
        cooldown = function() return ( pvptalent.sigil_of_mastery.enabled and 0.75 or 1 ) * 30 - ( talent.illuminated_sigils.enabled and 5 or 0 ) end,
        charges = function () return talent.illuminated_sigils.enabled and 2 or 1 end,
        recharge = function() return ( pvptalent.sigil_of_mastery.enabled and 0.75 or 1 ) * 30 - ( talent.illuminated_sigils.enabled and 5 or 0 ) end,
        gcd = "spell",
        icd = function() return 0.25 + activation_time end,
        school = "physical",

        spend = -30,
        spendType = "fury",

        startsCombat = false,
        texture = 1121022,
        talent = "demonic_intensity",
        buff = "demonsurge_hardcast",

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_doom.lastCast + activation_time end,

        handler = function ()
            if buff.demonsurge_sigil_of_doom.up then
                removeBuff( "demonsurge_sigil_of_doom" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
            spec.abilities.sigil_of_flame.handler()
            -- Sigil of Doom and Sigil of Flame share a cooldown.
            setCooldown( "sigil_of_flame", action.sigil_of_doom.cooldown )
        end,

        impact = function()
            applyDebuff( "target", "sigil_of_doom" )
            active_dot.sigil_of_doom = active_enemies
            if talent.soul_sigils.enabled then addStack( "soul_fragments", nil, 1 ) end
            if talent.student_of_suffering.enabled then applyBuff( "student_of_suffering" ) end
            if talent.flames_of_fury.enabled then gain( talent.flames_of_fury.rank * active_enemies, "fury" ) end
            if talent.frailty.enabled then
                if talent.soulcrush.enabled and debuff.frailty.up then
                    -- Soulcrush allows for multiple applications of Frailty.
                    applyDebuff( "target", "frailty", nil, debuff.frailty.stack + 1 )
                else
                    applyDebuff( "target", "frailty" )
                end
                active_dot.frailty = active_enemies
            end
        end,

        bind = "sigil_of_flame",
        copy = { 452490, 469991 }
    },

    -- Talent: Place a Sigil of Misery at your location that activates after $d.    Causes all enemies affected by the sigil to cower in fear. Targets are disoriented for $207685d.
    sigil_of_misery = {
        id = function () return talent.precise_sigils.enabled and 389813 or 207684 end,
        known = 207684,
        cast = 0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 120 - ( talent.improved_sigil_of_misery.enabled and 30 or 0 ) end,
        gcd = "spell",
        school = "physical",

        talent = "sigil_of_misery",
        startsCombat = false,

        toggle = "interrupts",

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_misery.lastCast + activation_time end,

        impact = function ()
            applyDebuff( "target", "sigil_of_misery_debuff" )
        end,

        copy = { 207684, 389813 }
    },

    sigil_of_silence = {
        id = function () return talent.precise_sigils.enabled and 389809 or 202137 end,
        known = 202137,
        cast = 0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 60 end,
        gcd = "spell",

        startsCombat = true,
        texture = 1418288,

        toggle = "interrupts",

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_silence.lastCast + activation_time end,

        usable = function () return debuff.casting.remains > activation_time end,

        impact = function()
            interrupt()
            applyDebuff( "target", "sigil_of_silence" )
        end,

        copy = { 202137, 389809 },

        auras = {
            -- Conduit, applies after SoS expires.
            demon_muzzle = {
                id = 339589,
                duration = 6,
                max_stack = 1
            }
        }
    },

    -- Place a demonic sigil at the target location that activates after $d.; Detonates to deal $389860s1 Chaos damage and shatter up to $s3 Lesser Soul Fragments from enemies affected by the sigil. Deals reduced damage beyond $s1 targets.
    sigil_of_spite = {
        id = function () return talent.precise_sigils.enabled and 389815 or 390163 end,
        known = 390163,
        cast = 0.0,
        cooldown = function () return ( pvptalent.sigil_mastery.enabled and 0.75 or 1 ) * 60 end,
        gcd = "spell",

        talent = "sigil_of_spite",
        startsCombat = false,

        flightTime = function() return activation_time end,
        delay = function() return activation_time end,
        placed = function() return query_time < action.sigil_of_spite.lastCast + activation_time end,

        impact = function()
            addStack( "soul_fragments", nil, talent.soul_sigils.enabled and 4 or 3 )
        end,

        copy = { 390163, 389815 }
    },

    -- Talent: Shield yourself for $d, absorbing $<baseAbsorb> damage.    Consumes all Soul Fragments within 25 yds to add $<fragmentAbsorb> to the shield per fragment.
    soul_barrier = {
        id = 263648,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "shadow",

        talent = "soul_barrier",
        startsCombat = false,


        toggle = "defensives",

        handler = function ()

            ConsumeSoulFragments( buff.soul_fragments.stack )
            applyBuff( "soul_barrier" )

        end,
    },

    -- Talent: Carve into the soul of your target, dealing ${$s2+$214743s1} Fire damage and an additional $o1 Fire damage over $d.  Immediately shatters $s3 Lesser Soul Fragments from the target and $s4 additional Lesser Soul Fragment every $t1 sec.
    soul_carver = {
        id = 207407,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "fire",

        talent = "soul_carver",
        startsCombat = true,

        handler = function ()
            addStack( "soul_fragments", nil, 3 )
            applyBuff( "soul_carver" )
        end,
    },

    -- Viciously strike up to $228478s2 enemies in front of you for $228478s1 Physical damage and heal yourself for $s4.    Consumes up to $s3 available Soul Fragments$?s321021[ and heals you for an additional $s5 for each Soul Fragment consumed][].
    soul_cleave = {
		id = 228477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 30,
        spendType = "fury",

        startsCombat = true,
        texture = 1344653,
        nobuff = function() if talent.demonsurge.enabled then return "demonsurge_demonic" end end,

        handler = function ()
            removeBuff( "soul_furnace" )

            -- 
            if buff.glaive_flurry.up then -- Reaver stuff
                removeBuff( "glaive_flurry" )
                if talent.thrill_of_the_fight.enabled and buff.rending_strike.down then
                    applyBuff( "thrill_of_the_fight" )
                    applyBuff( "thrill_of_the_fight_damage" )
                end
            end

            if talent.feast_of_souls.enabled then applyBuff( "feast_of_souls" ) end
            if talent.soulcrush.enabled then
                if debuff.frailty.up then
                    -- Soulcrush allows for multiple applications of Frailty.
                    applyDebuff( "target", "frailty", 8, debuff.frailty.stack + 1 )
                else
                    applyDebuff( "target", "frailty", 8 )
                end
            end
            if talent.void_reaver.enabled then active_dot.frailty = true_active_enemies end

            ConsumeSoulFragments( min( 2, buff.soul_fragments.stack ) )

            if legendary.fiery_soul.enabled then reduceCooldown( "fiery_brand", 2 * min( 2, buff.soul_fragments.stack ) ) end
        end,

        bind = "soul_sunder"
    },

    -- Viciously strike up to $228478s2 enemies in front of you for $228478s1 Physical damage and heal yourself for $s4.    Consumes up to $s3 available Soul Fragments$?s321021[ and heals you for an additional $s5 for each Soul Fragment consumed][].
    soul_sunder = {
		id = 452436,
        known = 228477,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 30,
        spendType = "fury",

        startsCombat = true,
        texture = 1355117,
        talent = "demonsurge",
        buff = "demonsurge_demonic",

        handler = function ()

            if buff.demonsurge_soul_sunder.up then
                removeBuff( "demonsurge_soul_sunder" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
            spec.abilities.soul_cleave.handler()
        end,

        bind = "soul_cleave"
    },

    -- Allows you to see enemies and treasures through physical barriers, as well as enemies that are stealthed and invisible. Lasts $d.    Attacking or taking damage disrupts the sight.
    spectral_sight = {
        id = 188501,
        cast = 0,
        cooldown = function() return 30 - ( 5 * talent.lost_in_darkness.rank ) end,
        gcd = "spell",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyBuff( "spectral_sight" )
        end,
    },

    -- Talent: Consume up to $s2 available Soul Fragments then explode, damaging nearby enemies for $247455s1 Fire damage per fragment consumed, and afflicting them with Frailty for $247456d, causing you to heal for $247456s1% of damage you deal to them. Deals reduced damage beyond $s3 targets.
    spirit_bomb = {
		id = 247454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "fire",

        spend = 40,
        spendType = "fury",

        talent = "spirit_bomb",
        startsCombat = false,
        buff = "soul_fragments",
        nobuff = function() if talent.demonsurge.enabled then return "demonsurge_demonic" end end,

        handler = function ()
            if talent.soulcrush.enabled and debuff.frailty.up then
                -- Soulcrush allows for multiple applications of Frailty.
                applyDebuff( "target", "frailty", nil, debuff.frailty.stack + 1 )
            else
                applyDebuff( "target", "frailty" )
            end
            active_dot.frailty = active_enemies
            removeBuff( "soul_furnace" )
            ConsumeSoulFragments( min( 5, buff.soul_fragments.stack ) )
        end,


        bind = "spirit_burst"
    },

    spirit_burst = {
        id = 452437,
        known = 247454,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "fire",

        spend = 40,
        spendType = "fury",

        talent = "demonsurge",
        startsCombat = false,
        buff = function () return buff.metamorphosis.down and "metamorphosis" or "soul_fragments" end,

        handler = function ()
            if buff.demonsurge_spirit_burst.up then
                removeBuff( "demonsurge_spirit_burst" )
                if talent.demonic_intensity.enabled then addStack( "demonsurge" ) end
            end
            spec.abilities.spirit_bomb.handler()
        end,

        bind = "spirit_bomb"
    },

    -- Talent / Covenant (Night Fae): Charge to your target, striking them for $370966s1 $@spelldesc395042 damage, rooting them in place for $370970d and inflicting $370969o1 $@spelldesc395042 damage over $370969d to up to $370967s2 enemies in your path.     The pursuit invigorates your soul, healing you for $?c1[$370968s1%][$370968s2%] of the damage you deal to your Hunt target for $370966d.
    the_hunt = {
        id = function() return talent.the_hunt.enabled and 370965 or 323639 end,
        cast = 1,
        cooldown = function() return talent.the_hunt.enabled and 90 or 180 end,
        gcd = "spell",
        school = "nature",

        startsCombat = true,
        toggle = "cooldowns",
        nodebuff = "rooted",

        handler = function ()
            applyDebuff( "target", "the_hunt" )
            applyDebuff( "target", "the_hunt_dot" )
            setDistance( 5 )

            if legendary.blazing_slaughter.enabled then
                applyBuff( "immolation_aura" )
                applyBuff( "blazing_slaughter" )
            end
            -- Hero Talents
            if talent.art_of_the_glaive.enabled then applyBuff( "reavers_glaive" ) end

        end,

        copy = { 370965, 323639 }
    },

    reavers_glaive = {
        id = 442294,
        cast = 0,
        charges = function() return 1 + talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank end,
        cooldown = function() return talent.perfectly_balanced_glaive.enabled and 3 or 9 end,
        recharge = function() if ( talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank ) > 0 then
            return ( talent.perfectly_balanced_glaive.enabled and 3 or 9 ) end
            end,
        gcd = "spell",
        school = "physical",
        known = 442290,

        spend = function() return talent.keen_engagement.enabled and -20 or nil end,
        spendType = function() return talent.keen_engagement.enabled and "fury" or nil end,

        startsCombat = true,
        buff = "reavers_glaive",

        handler = function ()
            removeBuff( "reavers_glaive" )
            if talent.master_of_the_glaive.enabled then applyDebuff( "target", "master_of_the_glaive" ) end
            applyBuff( "rending_strike" )
            applyBuff( "glaive_flurry" )
        end,

        bind = "throw_glaive"
    },

    -- Throw a demonic glaive at the target, dealing $337819s1 Physical damage. The glaive can ricochet to $?$s320386[${$337819x1-1} additional enemies][an additional enemy] within 10 yards.
    throw_glaive = {
        id = 204157,
        cast = 0,
        charges = function() return 1 + talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank end,
        cooldown = function() return talent.perfectly_balanced_glaive.enabled and 3 or 9 end,
        recharge = function() if ( talent.champion_of_the_glaive.rank + talent.master_of_the_glaive.rank ) > 0 then
            return ( talent.perfectly_balanced_glaive.enabled and 3 or 9 ) end
            end,
        gcd = "spell",
        school = "physical",

        -- spend = function() return talent.furious_throws.enabled and 25 or nil end,
        -- spendType = function() return talent.furious_throws.enabled and "fury" or nil end,

        startsCombat = true,
        nobuff = "reavers_glaive",

        handler = function ()
            if talent.master_of_the_glaive.enabled then applyDebuff( "target", "master_of_the_glaive" ) end
            if set_bonus.tier31_4pc > 0 then reduceCooldown( "the_hunt", 2 ) end
        end,

        bind = "reavers_glaive"
    },

    -- Taunts the target to attack you.
    torment = {
        id = 185245,
        cast = 0,
        cooldown = 8,
        gcd = "off",
        school = "shadow",

        startsCombat = false,
        nopvptalent = "tormentor",

        handler = function ()
            applyDebuff( "target", "torment" )
        end,
    },

    tormentor = {
        id = 207029,
        cast = 0,
        cooldown = 20,
        gcd = "spell",

        startsCombat = true,
        texture = 1344654,

        pvptalent = "tormentor",

        handler = function ()
            applyDebuff( "target", "focused_assault" )
        end,
    },

    -- Talent: Remove all snares and vault away. Nearby enemies take $198813s2 Physical damage$?s320635[ and have their movement speed reduced by $198813s1% for $198813d][].$?a203551[    |cFFFFFFFFGenerates ${($203650s1/5)*$203650d} Fury over $203650d if you damage an enemy.|r][]
    vengeful_retreat = {
        id = 198793,
        cast = 0,
        cooldown = 25,
        gcd = "spell",

        startsCombat = true,
        nodebuff = "rooted",
        talent = "vengeful_retreat",

        readyTime = function ()
            if settings.recommend_movement then return 0 end
            return 3600
        end,

        handler = function ()
            if talent.evasive_action.enabled and buff.evasive_action.down then
                applyBuff( "evasive_action" )
                setCooldown( "vengeful_retreat", 0 )
            end
            if talent.vengeful_bonds.enabled and action.chaos_strike.in_range then -- 20231116: and target.within8 then
                applyDebuff( "target", "vengeful_retreat" )
            end

            if talent.unhindered_assault.enabled then setCooldown( "felblade", 0 ) end
            if pvptalent.glimpse.enabled then applyBuff( "glimpse" ) end
        end,
    }
} )


spec:RegisterRanges( "disrupt", "fiery_brand", "torment", "throw_glaive", "the_hunt" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "tempered_potion",

    package = "Vengeance",
} )


spec:RegisterSetting( "infernal_charges", 1, {
    name = strformat( "Reserve %s Charges", Hekili:GetSpellLinkWithTexture( 189110 ) ),
    desc = strformat( "If set above zero, %s will not be recommended if it would leave you with fewer charges.", Hekili:GetSpellLinkWithTexture( 189110 ) ),
    type = "range",
    min = 0,
    max = 2,
    step = 0.1,
    width = "full"
} )


spec:RegisterSetting( "brand_charges", 0, {
    name = strformat( "Reserve %s Charges", Hekili:GetSpellLinkWithTexture( spec.abilities.fiery_brand.id ) ),
    desc = strformat( "If set above zero, %s will not be recommended if it would leave you with fewer charges.", Hekili:GetSpellLinkWithTexture( spec.abilities.fiery_brand.id ) ),
    type = "range",
    min = 0,
    max = 2,
    step = 0.1,
    width = "full"
} )


spec:RegisterPack( "Vengeance", 20250303, [[Hekili:S3ZFVnUUr(zj4HZp7KnETuI3nVEXU4UwC46dfV)OP46FC4STITCIqSTCLK39Tab(Z(rsrsXFmdfLL8M0(kqrFznPgoZWHZV4qYzbZ(RZEyvur8SFjCu44r3m6MHbHH3okC2dfFBF8Sh2hT8LONi)XUOTK)))N4DpfhTBjRLVTjnAffc5PhYO)0Zff7Z)DF8JpLu88HhhUmD7hZt2Eyturs6ULzrRlO)7LFC2dpEiztXFA3ShHg(GX3rG5(4LZ(LX3fqaBYQvXL9noF5Shi992RdgDD4p97oUiiy4OHJp(Zh)z5phq(5hs2(hoU4WEk0)WXfjKHpokp(4IvXRJ3LN8L4DX55hxeDCXJjfYpF0pDDyOXNR2yaTX)sCY29BI3gVR44I)y820D5hYEsVFJCaKru8(V(14OxoU4lrzjrpUHGyugmbHksjye5FUKa1K8c2ySon74I)Rhi9oF4Xf)h)L)DYpL8Rhx81icQVytA6EnWhqiy6)9ouC4ZxhEdfhEMmq)TicW)BKzSKDKj1S01jBitLrlPZz5d3NftMgFmQ4QjFuGRFGIQtYt290M45fresV4dFjAZbYVTpEZg(pLpmFFswsX8hjF)KGJ)ShGCBe5ZJsJRdCtNe2dTX7Nm2Nb7XKN8BO(KpqRilz3lXfZdM)4H1RZ5qL)Rddg(Cu(8d5XSwF91(6nq)XHrpLSjP4BV(kqBBJisczWT9L4SCYcm0V9z63c2YscnoOjexiiXfIrCHoiUqhexynexikXf6fXfLTmAhrYnnlJU8cSp5jemEE665R3q4aFiz9KNJZsNxKfhpmAZQSOLpNmNOsHGGekUQT1XBYxgra8QEfrBiGFyEXbI2RckSYjiwmbvFcbXs2UnTuz58Odzr01R8UrACvsE2H9fA)ev3ZCIW6lX5FGobKUE98NwUAsafHVGXhu7ZWd771ViA3leuGW0s2gF)4bQauFAF3HTKpm6R7O)0CIs(n5FiD)KS4CYcEIE0OdBkMmQXF)2OFLlbXqtbBI08CgxpV3Y00nRs)6UH6Zce0VfdwOYGTMm)vCilUAKe)YWLpt1bKpN9dKrkAZ0jb9k5LBJlI2MMT)5uIQ52Hn30gSPBqMOvRWMhisWeb7E9RMiQ(1HzXBJs2LpfU1vebxkAC9nd0eTs2re9j4)8CYI1xI1fxv7y2bI0p7FnFdXayjjeL9b63TSGlAdTGRwGq0CPceyyuTYmkZ2a1(hNx8mzbWZekNYdjResw)bIT6vj0psoJMquOnNS0ljpU3QuXp8yw0UvdlswsxaY599fJWqndQxoEWvknjmmQ)ZCtyxE7GsGnNqhDfeDYhi6pjsup6GdOybvyHLkKqKJFI63u(0jvOIgtvHqg5doqKNt39Uarsj2uisZncx6RJmxjXfG1SdApQUk9afCzBNZxedHSvsdvDp(xjOEC(1uBgdMoIJ910r)XlYQYNEkoBEkrdY6nPFLJw8HzuL1SN2erCDNyo4qw23OMZk)zID8vezDUUf2VtSR(f60bXHNsZ05Zl)yNis2tZJ39mnaN5l3q)migKKSnrBINao8J82bK2xN80ZfcU)9bJiMHz9DiLHrCjz(QKyYppqQz2BEitgz(JXKGfINVl(xjJcHHe)3petOgqr)RkDnlJ5BsXZXCgeXJfsqFTyS0ST0pyyWL9dUIa0Is31gm4sirmop56(LJRXS2W4FnE5HcclIWNUI3fPzsOglnkXMe1BNkuWhSR6tID8s6pqSmpyGBLEnGOV5kBVAOcX2o2qKqkIfOZ9U4lCS86(HxBd8oe11XtB7((GKVVWgIRig4d15dcFF7hY3KwicKP0Zc1f3Qr0rw7I1uV(9r0cbQZIQgav7eTr2xr0UNSzJyLzPAJvrBJEskTm9ozNnwRqgzjpJ(1pFGiTiyyJTLZbzhHWSJqC2r4)KWo2Ns)h2bu1uYYHjOF4h0gXLmNXm9xLSYG5YCEhp4AdnONYQRhvDzgCWE9vyuZFCqlugB(EzGQV(Av4rXBiox)LiQnLstfLsatcnnrkMUR8GWw2OVlZGxPBYCW9wdHQtDKrrUQG7wypdx8MgQXx0neO3uL2UACSqKQH1eXO0dfvs7gjuqk0lT4zqlg9Nj3vNhniSvvfewAMN2)n0k)vO27Tt6tFoNnkFjx8M1eLSHMeznYc4ZiZfsRv3kmE)3pqcdmEx8kPf8b9(NjEjMEfPl(c1j2liXZS7T9wfR9rBJYEHTg2f)5TJ9iNsDy(In9wxNKYpVH0cHyEV63(B8CSsAvC5Al1(0G3XRLrDssau5VRcr2s)F4hoU4)9)o(LKnj)Fhx8ht39JfSTWQinJ8hf09zklT0A9Xfp(TJloqZn1XfXeI8B0EwoYhxSpnpp5r6(H91NJ3X)09h2S54Ie621TzBAobIuTidlhwnToWosfLnNJXmD6(gdUP1HkwQt3jWNEVFsFT5I3WjBQyRUJj3FJWXDpDfIjoBXK09g6F8zsnNLyWrE8WMxiIFf8m4)BbUIUpJt)9KySG4m64E5sZdzFtjD0wPJ7YqA6Q5Uq9sC8os7prmqsz)xsfhNo5Mre0d3QBubffjUBhhVQoxRim93s2CDPtCqVlqIkKhsMvyHgtaWAljmDIVT77M5J7)n00Hb3vzpFy8YlG2Ci6xqMIm2JOjm)e49NAyCEYUYijY7rMti4qwC5wdYq7Q45Q(kVgLEi5lrjwB7eMWfUqw8pDsGOh17p70X4XGXciwgLqDoqtfuNo5Urk6q5bG)6RM)cBlJy8kZTFXTwnrQSZI(6CwMSNVFzX74SzpGMTIAmqBYBmLHJ384MOvLkN9LZ2JozC)TwBxbT2XicVeEtbHDuaKGTMoc9UqnNqmmLAhLVe4WUNt2TkoJeJDuEoTAfmPoohVjJnWpZ34pm6wjpoElo)BqbtJK6v5NKzHo4mm032iOc9WkrpjgkhEan69dVsvPEvE412t)E1lmzBwszjDDzuvyyPuYECZxr30bOdxq30H2LUbhMC526mfsTvtGQpH99FnkJrT5uJTprcULBmDS7GqnYTSAzwIf8HUV5tUbHUXhxZwEookdrgZkB8zPFvUfaQnkIp39MbG8fNT4iAJ71k4xTUzJfoyRPcI33i4KhBmcYx6Hivp3oigIHu6jnhPtkoWwhyyUqI1PkRYydKUEdQaRA(MK7o3v0IB7lPVepx8tS9bLVx3FB7JPmK5509XNce2N(14mI))RpKZXcX3ZrqfN6oKLxifOwjRm95QTRNObUQiAdV(QP2KBfzMwx7Mmz0CDGxgQL(Ff0IcV8duv2GyvvZmK6IAq72InwrwidjB53ilOOn9ycBPozKWkvdr9nEFvpaXNRcUdkjBtc7vdvIZjR8H0gOGBhfdJRB8GgovJFnMaabOIth1ol7woPo8T1G3Aay6PVcVUauy9GkNmaJ9Umw5DhTC(iiePT0S5YsdVhsh4LwowZKW9rrcJKtaL0G(L2FKWwcbIVxm7EKwN)u8oITYaIXgmLkq)k3Zhl9ndCKPIAwVDFFqp8n89tphQQAmuquLbE(J0StX3ph64AV6uYrTJF5TGdwVy3BQ6VaAWmDbD2tmdJxQ83hayiqYo01O6Gx4MqNYM4ERjtx6)RAkCiMRr2YYvP9Xtz47jIWNxjyvT8DcZLN3qpjUA5w1I46U)z0j6H57d5XlNmAyzYW6is8IgQfYhrUPeK8Z(QjSMLGYyzBcEoEeUycwuMRTpzm0djgnxz61BUi)mg1WJOZYiUOLifT59e9ax(Pbd(3cgXkvDfBy6Gy6irMm(cRmR2ex(7pUjnDLtevqIIsjGzathRdVQFOmvuNgWQQ7woCWCnOk3kkNRfnxZA7OIFeWuuiJuKvwsqAd55ajnRZonSeRi86a00CPHX5M4KHrf1goC8LRjINz8T8f60mknf(7DtsdgOipbcOy2XDzvppgRa4YOKjj4N4VBc)Mr01tcHF2wVXGpPZxAKGx9XMPkRDIODb(FNtbu)WJoanc1KEqqd)eCCcHGoax)mrwVY4kxBF3H)4Q(7D2jTq1t)6QOSxiMhjr08yknMOYfDohfIBgKir)T3zFeYNHsVUO7FAtoPFMUMvHnMSw4t8LtmPBpeKThD(oFuiprew478)sQwo5XsGCtM1CjhzWC9EEXmUM3vi03zr7tfLP5QGfqeqKcn9lRmJiImur2xnJADz4cEGgg(wPIjxIecxzKSoh4vP7kMRgAkWmnCDjyMyzYGTAzelRZCeV2Ct75gC4FUzPjUGMdazpp9ujmqxNuT7VUeFVPH47GodHD75KJ086y5TE54XNy5cwtP3WhZ5)dAwubV(oaxoauIbtuR0evP7bOGUF)GRbA66GbdUeCyf5ZDW9tCNNtSjFayvlOCoTOTfg1mxKSzZHTj7IkKhJkHg3wWEm0zi5qtBadQoGvdS8NbXxi9(JhHOv4e5siqZF(epxcUmBdKTboNcnrdcf2oZuHRZ8N)g0n3zphuIXHvuy1xDSCrr4hFrNKI)yVCFnfcIOsQ941cN3J655G93el9dGnIlVQsG)QE1S5MbSccVMDIQ6kEt2r5ctiQuCE9RU90KFNyCRrLNF8)wFtc8py8)qp5)bg8)G2Z)boa3SLq3wF)UaJ8iCh8mT27c5boGF4ZTJcc)a9sRvmS54M6b4GQdJE9WIm22GsKif2rC6Itq0ZGjduOhoS14OkoWAsQiT(bUga0tyX3Wb2tUWtWAIYpXAJBK3sO2OwvOTbxIiqNWgAX0d65EpiF29UmqmXr4A8CDU6bpv)CNgAAVh(oRJ7FNi)3ntRwF316eqTqHxlAOOOgkzFDH0Kvq(mCQ72lt02jda1dsw0215F59tucI1AohLBuD(5QXSsvQE0t3Xa96G3aXD0yL9kBbdJYTSUQT0GyffmS5At1kfbTQHeOLAqSQ7JBvT4a21b9QLG7BDenOBdUO2(T0mJu8p6koAqQFPz44cBlFkAt0YCRY50t1oPJI4X6ebDZ9tgZiVPtUL5CIE7e1HLngqVGJqTm9DTwWazqoo5E1yK2IMjRwHUB0gsMOEbGhyuZ0qow0RbIa1kJovvzccYGCQ8OchF3qLk1eAOI(bpQYeUz(sbxQjlYNwdoFM1Af5x)mrBaVU(sM6PBh9o1hylCx9ir9oh3rJceC8fNGtCmaASeFLR5ykxIyKDDYYKcQMA3l28FzG(QkV)U1wNUlUXDSsMRPhmlTVaYNbpoUpADcUI6bbJznTMx3X9rFG0xmRYgKoN5MlOvXnW7809bWq1RYXVrHXqhfWlwayea6Sna3tZzn9IAvJ9CvT3SH6dH6hwoDKZZsbs0eaB1KtiQTSKECt9A)2iU(BQZxGxA(jBnGk6lfdi85B9SIgYjSvPPBvKUGs3kSpG9asoa(4z9kg4nI5m9ioUk(GBb2DA6y1tph30FQID76g6ZH0fgxgovpOjuZfsZesCTvdor(gG6UKgDKm(RejrQ6eX3K13MoZFJ1vN5ex3DMEUY)7xqQYfNnogvRjiKWv1dKcZ166YXd7IqXk8Yb3p5tdKby6i0uFeSKHz20qa9XNXMeeOdC1Nal8oLjUL2X7NThtGYcEFMARBYxjWla)HBj3c8QicjKvLjzEfRna6zorUrKv1cJFl7LrR0ujmGCOAw0oTJmBG)dNa(J0K8kR59b15ch9afTfDuvxzhZtnRPArokoP1jDTCoC8M1q04uxVlSQM0glgwJNaghFoxIkWZSvFRYvm8vMvHG7NzKa)ac2tesDq58DlLWKFaEcuy)U5Lucg6v7Lus7Xw2TrI24JEakRAR(7yOt(kdQAqWYervpqdQrHkGLgfNeelbjRhnhUeK25xxCgm1CDm01lIdS0agkHoTlpalRjXjY97KzeQ8cDexma(fjabT0QlcBqHiAxMFptwe0jJw9Ucdbt9)jvWjvdpBOfYOoNxpBQVXyjgsYUCNEFJH6zc9Tx0ez5pFDeM2oGUPA0dBrTAQ3aHI5PkV(fn0Z29DV9RBQH74qJTJoBKHy4odLPySjs9mg7S3Q5yF2duxbi9L)Whhego7HVgLTJWqZN9a7D5nz7E2LNo7X)9h5Mz(XJlYiqoH(ufUipLq5lIouKULMeVJlitMeJL5dp(Z)5KDKMOpwX)H0DKXI18pIAt8hlF3HX7G4qcs6y)GFDWqQqoawUoVziyamcQEW6nqn1MSrkqOMUpUCFQZPVd0eqDkNVFXyjoN)c0QTW6Juyvh)a4iJAWwa6bg35g4Xqn(odGR2eguVdbQAhCAt4Q1i6S53dMsW5HReClmyvs)LbuvAbfOJpha9tNdG(5ZdxfryRD46pDgaA4OZbqruR3sUAiIyL(2nAay9grbnIWL9oqzaE7oGoeiIAD5qGj2bSJmMZQoUSl8Dym3UfJHWSzuWJiNBS5zgq3O1Mc8oc3Vbz5uhojJneDffyzmd)mBihcExkG7Z5f(1dz7tnIfGb7IF49Pb9k4APRe)mA4cWO87Ug(1dz7tjIRjsm(D3c9k4I4Wd)WHyAwQ8xrxSCo8E6gmVN6wT43CEC9bdSDGr6BrymTeJ)od2wjBCEakIZpMfzJbKnBUPGVD485r69wSOepvWcNeIY0Y8JnkteiX)16jjqmmRANx6eS0yZwmqsJwrNColWgK(12FVMXbqWYo0dqKrO1scLqhB1A3A9bzu6eF8FdGDh58nIsToM3JmkDenCEdoelxBTYysas(kAhqppwOWsTuBblsCXNmybvRUkEnpz(TxHQsPZzo5OuuDiKlMlF8nDYKsL7XDJukCIqdtjq1U(arV86(0V5b5PQULZeYqYEokFoTShOBvMe7QchZOz3wZ0akBV3IitLjfFdbWgDPBbElW6T035SmNyDvx6wG3cSM0woDpjQHFR3TUFqAbfWEF5CH7Io0LaUf4lDN4CHU827qWIHSwAfZePkY56BRMBaqDUeeSlDlWBbwJTeeSlDlWBbw7APhA36(bPfua8YqGo0LaUf4l4cr727qWIHSN7WlyEASoDZM0VMqF78PLuq(XfFnolM(E6thZeXlMFzvjCCbTK(oU4XdfI(TlL5MYHDA9E1kANxfve9yuE8VJ4xZIRjoOq4boIGV7kiLt2nyNqTv5efKQJYAg5Ien15HCBv4uijwQvW8CK9(aSnuVnHRCEakwiFNYoHeIvOuDrsxWaEhLtbSn)VLjwKdCeLUDdWppjdadSTsF1zfJT3TWYVTtkKq(qGmr2jdHRTj4eSIDEQvmKKMCEZ7CRHoIDsX9QqZySiIzDYI5ZZwNC8N)tmkNcYGB197IsxZEG9xZ(RZEGxbVK)8xcO)7YUo7br5Gp7bo0N9FoRy2Ves7t1V8a1zmIJHrZE4ccJd4eVCCrpcYx3IIQX18G1m7bLtwdfhjiXnQiQEjUAGU3Q2tJdlJrxhRr9801P3hcYSoxYPu4cP7j4rCHcvWRSC6FT5a5)0xmjGvsUhxCfz6tYQGkm3JlUKSI54IbS)3hPEimsDgGoaGpWxhxm94IrQZeoQbvgYpFhJxkqoOz(6P5qbnfYWC(zgKG8QdXAOxMg5KSX4rIiWX4XhavwIdfDm2rLelRhINaaVqWB7cee7IzHUW51xvqqJ25L4YXf3FCH8ymaJQ(qlJ7uAX(DhZGyqEtH6kQ5tnwuDeeCnFfaOG(ZnMrfoCmt8N9GnXwo0Ng67A33zgKLS)(64fLAcae3Df4otS3tmGOHPCId9EbbzXmeN7UgZ5UzKUceXIzW6ZN1dxVaAgSQ(DXARgq()uJj)78ATL)iRVyAWOgJQHis4Oi7PiCxdejcREtHq2VDtHFMVkwI0v2Tp)uE9gTzRQ7qgeKX(AebcbWy4N0nVXcixaypUaW4HaM5gp9wnXHaKRqcozYELcy6oKtHAxgdmHHXSjWsfxvDt8myH3f(LyaRd3Y1Si8D87XWr54q(04bhV62heYAKD(Z0zNJKuQ(DMdrMDIknzoTsryihxAecZUhi(EJ1ioO0aSMFlK0oeVpn4xDC)kfuh4zaJjivp9b5LKh0xU5dl2)ALRxdhLLd5ELhSCLBeL2jlv3IaJjwkkd5suZq5VdlETX7qi)JAiE)EA5laf288BOfaLCB4KrKf2Chk4PlrDjT6Tnstun4ru(aOCZtabCgEuXA2AwKebvELhudsDIgOnV8KS8Rw)EEIN2owlRaFcdSuRACldA)MyrdqPVswGimIByYJ9eoot99txegZ7q23DpTgohX(tAmQxORKuz1wz7qTW0Fu2mKEGBf5ARsJUjlrSCvCv7XGLiiaWlpligryNWio)CbQe4j6XLYspRNTeOiha3yjhsDkRSfNAncNzIsxqMnQMBfxHSmQw9oLvmPAFRKu23aCTm2VFILy1tvVHISzADLed8CilfxcyLfbsNVM1E5e4L1YWg4lpJkjCIEXA9W7am9JFUi0fbWsHtffnToQr1C6zJBJIEd8adf87t0RAOhZOVBSCeRbVRy6OwSkz7NON1qVmvnmxTyo(5iDSQMFQn7U9zk3VwMzvSANqr7)j6ZU57WfaJaPSq05b1t54ptKNcjx5ElDhPqC83HhH9Lde(YRY9LR0YadbdBgccYJLf7pdXn9NxGV8simyM((4kDsG3U4jbuYKX7GCf7j5vPQLpCaCrnWOx9kuPUmnsZoBnFar0rPEQToG8QGYI5eQWCukAtZJRodRQdpK(JsFjlvMaPZYMXyzmlhw3SCyDZYH)wAwg4AqW5SCa0SS9LsqlMLdzZYMHLQOivOd52Q5EZAEGcbZyi1KkW5sCMUR9cumXvP2ZOccvRbbGmDWAg9z5S0TGB8s8R)jge0a154lA4iWWrObqKNz5mRoV6uxf5EA2mqnTPzp8(qGGsIX0iU7ouzbsILgLQdfjnJHawdfYZlkFAqgMgsyBOqIt9TKqPtCU7b3btXIAhSdtx8Ryh0pY(HZHrZJemIQ5v4uHX5hvRoHJYUu3kAWWdmKXDfzVjjR0xg9A6BDf9Q9QKY0QfoQcoM3pWLf0MivdY3pj2yy6YQpz(YdJp9T7I(RCqjBQ2egPWDmE5o1jkEGBek6wt)q9HICMlVYxhvADT5fUOnammY0btTLXEWjrJftjLA1hVgn1f9HsX4GMYMlRjskLHxWJE4pX9QPAxpBUkwaCs810ftFDGLDnfmr6LUOPFmmjvX4wAvMP4vdrL)r7eU)h91NOLkiZvFjCy0QE(Y0RuoLtgn(Nmq3dYAYAT(3ELAXmYGtzgBj9D8iD9DIQOLs34gK9u3DD7ZbYwGkqY(ggjaDatt1UXEww5zunUWDbSBISPrfuby3RUPCrZyfUklh0AUXB(DsBGvFqWyvFTuS5wjCWMtW9)qJvHvX52kNmKzvYfTxrGCf9YEq3hr)MZ6Rs93nQ1UOIWQ5Qy1srH6XoI(EgbX214kmopURoWoU3RfY)ETsFkS1dfIqr)iJeW9EbKT)(HcOfQdLaWDnctfGHBU27RO2cTsto0HAmUplDZqX)r6qH7mcQKvhYBfshJX9Cat6OdXc(m8y8Sf0xrNX9LAyLkMBuuVV7IRgX(746874Fg5f1MMnq8u8qR5lEcHlQWqDgrCYAOZi4EeP(GrjCbazA1Vui4VMkCdtnaEkQJUt1Ny4dw0Vm(N0DCw9nzqTJ0KPipfBZeNejJtiLeo6XPPpIoJRrwacQcGwpsgLLUGAjQXnVHC(0k7)iHOjlzEYqwecP2VMivHrB9OrPfvN2dzflYF3HjR)bkl5(Uq93tjEptOH4m6vyFOJSd02ISaciRW(e)ubiT8VQMZvg4JYyzlKck(iqmsT8LY(PMIMhpS5fIKAbFJAPJ5NufYDEU9(S2AgLKgP3T7abyPpM69uB9LAqa6DR8SpOOMr1mS1srrozaorGgYAUsauDwsqQjhCn71wOrdC64cUMbpsRqFFYSqxI86kVD6UZ7MW5GcQkSAjMNzleiMk810OJyTHQ7DwImcT2HcMtL8H9Ia3(FTCtWe0Qjud7ZbUlcD7qwrLfgPM0Pkh13IsvDNc4w(Q6dDYQDE8UH3Cd9TJP171cQbcNRURlU6(6g2R27cx1vjlpsCl21PK2H7(o0Hxcykbx3w74HUgKmvwYoTcP0QFOkBB229aB22PYP3Rto4oc4u927DlnbQX0Do4BsHA3VOFL7zHLbDlRADskARJ9nv6B()yX48ZgUAhchA6OmIbCCJCnF1QOe1)ESsvALgp9SNT5pU8XjXDG9U5Nmcib6szXiQf4umeyE9UGhAJ95)TluwBS1ygPjjWyRdDKbeL93V1zaPAab3RYt8MMbpI1XEhX6N8lI1p79Skl3rqoo6zn8swh8VozMnC4aCP2tUnxZdaFgylaXkuCifvv0ZEJJT7jEC75y68Z)zXuhDpXJcNaDFpDem1jSt8ewv9WTlpKfAQTLdO1l8E5M5kklc6Dffg96bmGCzR(cLFeuQmTZ3BVQ0lbKOylxHmYjScZI8rp9uCM8bVbYHhp57wzgEg0w9zoGsFfQPCx19RWQO4c4N7VYVFiDcyEr68vjXvL)m2KzaKts1pvbiW7kZWAMqORaebmUl(xj0s1BsT0BhdSX9zULWvcggW042N5vmbDOM)kVyNfojFPUEARLkIJxe35BJCOJgtT8rDaPdk(4y3hZJaiz4hXVLzuRUObh1pMh1YdpH7VNByiaq5Civ)vjr7t1zvpVwsHL8D06jr6hrZzdn)s(5gy6SY3RtLiBiM38dl)zdZVwuGbnb)nDKq6K9z(4gbBsaBRdLGh1GHANyqHyMozZgHwUsTXRI2g9K(Hm7oRpeEVgLtuIOp0MLgRS83(0(yDv9yWKpBN2NFJWKzh2gRRxinhQoz2HdpueZI4PO36YdYyZhShv5woGS36oqNgwy4MkcWtHK8Skn2i)Col9j1KKyeApaJYz(FCiX0VUT6(kBV(lZIJk(PUz7wx1naoiYJlblbKtzgjnMUmt1NzZv6)BG7M9CE4TKtuUUic18Frjlg6fNM1fPJ2QR6r0bQ5JfB(0u7gG9UPc9BVp9(7ki)bfSuGd(L1T3JgB19PTwLJ64G(1Z95SU0fJgCoRz)VE8b()V9U22PXrcI(3ezeAxnKb4PSZl7)brwkMjOHzYkhplVX3(6BD319QTDie0YRyt6UQUQQRRh))1JsE9ozOMeXuVS5ldfNnbf8DvOFGFww)dPErrLdFzYEzcrgUsq7cLC86yZLnTFfWvTpSH6(brcdYIndik44c86kF9RlwgW1MouNwU4ZytDf2ONJ3KW0ZXaKTj4pNfhFCKwKAiIlZZaOCi1nXncdi)e9JfiVQxUogq095HXYz46EkBol)FYTv52fe3HETh)TJb9lW5fABzgqNj3jeqE9PUBXb9k)aLB5Htzth93gtyv1UCDCEus4s(up7ayJcjVnJvadh2o)IdB(uAyssdPJZCNZcgQVP01zQn9q3AO3uNjcWhjo6fQeqrsgJb)loZD2kOoJyi4UjunQyzoRi3aFZCI(6Brd3pi2OnncWthjG58IhmN5OE4LP)vPb8RqSfbY5MRcHsBwx(Y2(kBo8TNyyL(GxDtGvnQBqSMbLHbF6zsv1BkgC4j3MezEsVcn4Opa7fRyNiYGMTt4kgUPdMb930p(AMZyZKOfXhbNBuvElObjnGZSjOZ)Pw6c0stLzO)aXpyfTHD2H)C5NBK1ZY9ea5t3Yk38x0VuxR5caSEVCuvih1cY1S85FWa528RLh03Lvi0ZrX(PUl3lzXo7Mo1DQCjKHIDrDFHkYYJYOZzCTvjd3Uw67)TEPSUNdFSZZXVxvd9i8ozcXaUZyfjTZVs1CwzGszsZ8SzobUf194pk3Y9y4WcUBiVhQ5XpUVQK2L33I)6Kkpga3IAzCZwOhx8C)5xo7z09Rc2noowHYEp0vxhQEzHO0NZshmMsuNc7G)uBGo19PzkMlE73Yq1c1T8OvlpeN2BSPw9QgYAk4G(Udh(z3UcjNA)b31e3ocTcOh(KwmLkA79MRuR7Dh5fwpuLV7Ea9eEQf(wkGNa)0OdAYKd5wj)mi5EPAB4KFYKUbrRFnPV6vXuWp9b35Is5ux6m2I6xUYQiZFbkjJ0fw(T1JPfvw7(IUNV49eofJ2WiNrI(yh46ux0ugUpw79QKGoHH5GNcurKhRxwZelgGUCxiE(EDWgFNuW9y6RpaGVyPcYp(jHAzmNE5XbYjvxznwK4OEeubO6L9VZOkzc0aTs9dRTI1t9tex3Cod5Pikack3ClXHlOwh(ESBUd72L4Ge611MlfSwdVM4ruCuNqIrjutXOpnv5Sf(jAwfmdrYsXzM7Q0jM(qAtCGA9RsvnnEiAaV0CSEBUY9GRi9a(JtnhtX0O(LtNkYw9XKS3DbWyaUmB0WP2eZeOen5ASj(uaJI7ZmqWYfbwMjvFJwm02O6jsf1OPEYhcaTBgfvMsGRviDQTaLJR4xzdy45ejVrhhmb5O27GAzFDPRkgHF4T290X6F)p0lPm9Mij93j4)JkyEBBAVapQogtM0Di(a8Fvm5yKfVBONQRuhfXW0ijmITjYE472K0Gc3kDk)7oozKcbAbCybAAI7E9quL4VVOsBZg5r91ERj9zwpLGBP9v8P2FO10YnFguH04(AtfF9TIkMljin7V2JCNQmYySsqQOWlEQVP)ojGa6pIjmkdcQ31hnyX4PF1g(ElNBSDyiMb0DFOvgzFv9HTn1v9i(XX29yD7ln15eQS2jY1tYQ84XbJGPVen6GFHXbTrnCgs3C6SaDPSKf1fTAJjlyLDl(pKiDWEkaBfAgzx0(5E4snE5PMnx7fc8nZAF5XTDIUDkZXGknF(5(HinqYuPQzxptYFTd5l98Z9dfj)1jYhviIY6wxKAvko0QeZIlwpYZKjGYN31ARF)tBhQ3BKLizKOx9iRuJAo5niGL1mn2nOPEC7Jp98Zv1m)T08ZZ1HlwFlkhXWmXPitaicdvrGepHFT7j0PbSsHWQiZ6tbhK0zz0o)EayD(qpI2jY)kGblJWII9PCbixN0g6mgGHqZJUA67sy(5C(PvL9EnvZIXFjk3vhS6IKwo01CgQ6S4A6hVSsX41POuvEHBxPzI)cM0LnR4HzNFiiOH6PlCPmLA8xY3pLoQL4qtn0a)cCzwhFT4uJv)AdQ3jChVEDRAEjZRaM9yJgF29tqy3E1OhRbY0Kp7GwXgfqEHmU1u4(1g8yRnR7UUH4DfdOQMEufOFsoGv5z76SmudGzCXqzWqXheviBOnmTKDwiVnZ6d(WaSn(7M9hA97Q1t0)U)V8W)9]] )
