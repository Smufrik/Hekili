-- HunterMarksmanship.lua
-- January 2025

if UnitClassBase( "player" ) ~= "HUNTER" then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local strformat = string.format

local spec = Hekili:NewSpecialization( 254, true )

spec:RegisterResource( Enum.PowerType.Focus, {
    chakram = {
        aura = "chakram",

        last = function ()
            return state.buff.chakram.applied + floor( ( state.query_time - state.buff.chakram.applied ) / class.auras.chakram.tick_time ) * class.auras.chakram.tick_time
        end,

        interval = function () return class.auras.chakram.tick_time end,
        value = function () return state.conduit.necrotic_barrage.enabled and 5 or 3 end,
    },
    rapid_fire = {
        channel = "rapid_fire",

        last = function ()
            local app = state.buff.casting.applied
            local t = state.query_time

            return app + floor( ( t - app ) / class.auras.rapid_fire.tick_time ) * class.auras.rapid_fire.tick_time
        end,

        interval = function () return class.auras.rapid_fire.tick_time end,
        value = 2,
    }
} )

-- Talents
spec:RegisterTalents( {
    -- Hunter
    better_together         = {  94962, 472357, 1 }, -- Howl of the Pack Leader's cooldown is reduced to 25 sec. Your pets gain an extra 5% of your attack power.
    binding_shackles        = { 102388, 321468, 1 }, -- Targets stunned by Binding Shot, knocked back by High Explosive Trap, knocked up by Implosive Trap, incapacitated by Scatter Shot, or stunned by Intimidation deal 10% less damage to you for 8 sec after the effect ends.
    binding_shot            = { 102386, 109248, 1 }, -- Fires a magical projectile, tethering the enemy and any other enemies within 5 yds for 10 sec, stunning them for 4 sec if they move more than 5 yds from the arrow. Targets stunned by Binding Shot deal 10% less damage to you for 8 sec after the effect ends.
    blackrock_munitions     = { 102392, 462036, 1 }, -- The damage of Explosive Shot is increased by 8%.
    born_to_be_wild         = { 102416, 266921, 1 }, -- Reduces the cooldowns of Aspect of the Cheetah, and Aspect of the Turtle by 30 sec.
    bursting_shot           = { 102421, 186387, 1 }, -- Fires an explosion of bolts at all enemies in front of you, knocking them back, snaring them by 50% for 6 sec, and dealing 5,522 Physical damage.
    camouflage              = { 102414, 199483, 1 }, -- You and your pet blend into the surroundings and gain stealth for 1 min. While camouflaged, you will heal for 2% of maximum health every 1 sec.
    concussive_shot         = { 102407,   5116, 1 }, -- Dazes the target, slowing movement speed by 50% for 6 sec. Steady Shot will increase the duration of Concussive Shot on the target by 3.0 sec.
    counter_shot            = { 102402, 147362, 1 }, -- Interrupts spellcasting, preventing any spell in that school from being cast for 3 sec.
    deathblow               = { 102410, 343248, 1 }, -- Aimed Shot has a 10% chance to grant Deathblow.  Deathblow The cooldown of Kill Shot is reset. Your next Kill Shot can be used on any target, regardless of their current health.
    devilsaur_tranquilizer  = { 102415, 459991, 1 }, -- If Tranquilizing Shot removes only an Enrage effect, its cooldown is reduced by 5 sec.
    dire_summons            = {  94992, 472352, 1 }, -- Kill Command reduces the cooldown of Howl of the Pack Leader by 1.0 sec. Cobra Shot reduces the cooldown of Howl of the Pack Leader by 1.0 sec.
    disruptive_rounds       = { 102395, 343244, 1 }, -- When Tranquilizing Shot successfully dispels an effect or Counter Shot interrupts a cast, gain 10 Focus.
    emergency_salve         = { 102389, 459517, 1 }, -- Feign Death and Aspect of the Turtle removes poison and disease effects from you.
    entrapment              = { 102403, 393344, 1 }, -- When Tar Trap is activated, all enemies in its area are rooted for 4 sec. Damage taken may break this root.
    envenomed_fangs         = {  94972, 472524, 1 }, -- Initial damage from your Bear will consume Serpent Sting from up to 8 nearby targets, dealing 100% of its remaining damage instantly.
    explosive_shot          = { 102420, 212431, 1 }, -- Fires an explosive shot at your target. After 3 sec, the shot will explode, dealing 329,144 Fire damage to all enemies within 8 yds. Deals reduced damage beyond 5 targets.
    fury_of_the_wyvern      = {  94984, 472550, 1 }, -- Your pet's attacks increase your Wyvern's damage bonus by 1%, up to 10%. Casting Wildfire Bomb extends the duration of your Wyvern by 2.0 sec, up to 10 additional sec.
    ghillie_suit            = { 102385, 459466, 1 }, -- You take 20% reduced damage while Camouflage is active. This effect persists for 3 sec after you leave Camouflage.
    high_explosive_trap     = { 102739, 236776, 1 }, -- Hurls a fire trap to the target location that explodes when an enemy approaches, causing 44,960 Fire damage and knocking all enemies away. Limit 1. Trap will exist for 1 min. Targets knocked back by High Explosive Trap deal 10% less damage to you for 8 sec after being knocked back.
    hogstrider              = {  94988, 472639, 1 }, -- Each time your Boar deals damage, you have a 25% chance to gain a stack of Mongoose Fury and Cobra Shot strikes 1 additional target. Stacks up to 4 times.
    horsehair_tether        = {  94979, 472729, 1 }, -- When an enemy is stunned by Binding Shot, it is dragged to Binding Shot's center.
    howl_of_the_pack_leader = {  94991, 471876, 1 }, -- While in combat, every 30 sec your next Kill Command summons the aid of a Beast.  Wyvern A Wyvern descends from the skies, letting out a battle cry that increases the damage of you and your pets by 10% for 15 sec.  Boar A Boar charges through your target 3 times, dealing 313,698 physical damage to the primary target and 125,479 damage to up to 8 nearby enemies.  Bear A Bear leaps into the fray, rending the flesh of your enemies, dealing 601,164 damage over 10 sec to up to 8 nearby enemies.
    hunters_avoidance       = { 102423, 384799, 1 }, -- Damage taken from area of effect attacks reduced by 5%.
    implosive_trap          = { 102739, 462031, 1 }, -- Hurls a fire trap to the target location that explodes when an enemy approaches, causing 44,960 Fire damage and knocking all enemies up. Limit 1. Trap will exist for 1 min. Targets knocked up by Implosive Trap deal 10% less damage to you for 8 sec after being knocked up.
    improved_traps          = { 102418, 343247, 1 }, -- The cooldown of Tar Trap, High Explosive Trap, Implosive Trap, and Freezing Trap is reduced by 5.0 sec.
    intimidation            = { 103990, 474421, 1 }, -- Your Spotting Eagle descends from the skies, stunning your target for 5 sec. Targets stunned by Intimidation deal 10% less damage to you for 8 sec after the effect ends. This ability does not require line of sight when used against players.
    keen_eyesight           = { 102409, 378004, 2 }, -- Critical strike chance increased by 2%.
    kill_shot               = { 102399,  53351, 1 }, -- You attempt to finish off a wounded target, dealing 358,594 Physical damage. Only usable on enemies with less than 20% health.
    kindling_flare          = { 102425, 459506, 1 }, -- Flare's radius is increased by 50%.
    kodo_tranquilizer       = { 102415, 459983, 1 }, -- Tranquilizing Shot removes up to 1 additional Magic effect from up to 2 nearby targets.
    lead_from_the_front     = {  94966, 472741, 1 }, -- Casting Coordinated Assault grants Howl of the Pack Leader and increases the damage dealt by your Beasts by 25% and your pet by 0% for 12 sec.
    lone_survivor           = { 102391, 388039, 1 }, -- Reduce the cooldown of Survival of the Fittest by 30 sec, and increase its duration by 2.0 sec. Reduce the cooldown of Counter Shot and Muzzle by 2 sec.
    misdirection            = { 102419,  34477, 1 }, -- Misdirects all threat you cause to the targeted party or raid member, beginning with your next attack within 30 sec and lasting for 8 sec.
    moment_of_opportunity   = { 102426, 459488, 1 }, -- When a trap triggers, you gain 30% movement speed for 3 sec. Can only occur every 1 min.
    natural_mending         = { 102401, 270581, 1 }, -- Every 10 Focus you spend reduces the remaining cooldown on Exhilaration by 1.0 sec.
    no_hard_feelings        = { 102412, 459546, 1 }, -- When Misdirection targets your pet, it reduces the damage they take by 50% for 5 sec. The cooldown of Misdirection is reduced by 5 sec.
    no_mercy                = {  94969, 472660, 1 }, -- Damage from your Kill Shot sends your pets into a rage, causing all active pets within 20 yds and your Bear to pounce to the target and Smack, Claw, or Bite it. Your pets will not leap if their target is already in melee range.
    pack_mentality          = {  94985, 472358, 1 }, -- Howl of the Pack Leader causes your Kill Command to generate an additional stack of Tip of the Spear. Summoning a Beast reduces the cooldown of Wildfire Bomb by 10.0 sec.
    padded_armor            = { 102406, 459450, 1 }, -- Survival of the Fittest gains an additional charge.
    pathfinding             = { 102404, 378002, 1 }, -- Movement speed increased by 4%.
    posthaste               = { 102411, 109215, 1 }, -- Disengage also frees you from all movement impairing effects and increases your movement speed by 50% for 4 sec.
    quick_load              = { 102413, 378771, 1 }, -- When you fall below 40% health, Bursting Shot and Scatter Shot have their cooldown immediately reset. This can only occur once every 25 sec.
    rejuvenating_wind       = { 102381, 385539, 1 }, -- Maximum health increased by 8%, and Exhilaration now also heals you for an additional 12.0% of your maximum health over 8 sec.
    roar_of_sacrifice       = { 102405,  53480, 1 }, -- Instructs your pet to protect a friendly target from critical strikes, making attacks against that target unable to be critical strikes. Lasts 12 sec. While Roar of Sacrifice is active, your Spotting Eagle cannot apply Spotter's Mark.
    scare_beast             = { 102382,   1513, 1 }, -- Scares a beast, causing it to run in fear for up to 20 sec. Damage caused may interrupt the effect. Only one beast can be feared at a time.
    scatter_shot            = { 102421, 213691, 1 }, -- A short-range shot that deals 4,672 damage, removes all harmful damage over time effects, and incapacitates the target for 4 sec. Any damage caused will remove the effect. Turns off your attack when used. Targets incapacitated by Scatter Shot deal 10% less damage to you for 8 sec after the effect ends.
    scouts_instincts        = { 102424, 459455, 1 }, -- You cannot be slowed below 80% of your normal movement speed while Aspect of the Cheetah is active.
    scrappy                 = { 102408, 459533, 1 }, -- Casting Aimed Shot reduces the cooldown of Intimidation and Binding Shot by 0.5 sec.
    serrated_tips           = { 102384, 459502, 1 }, -- You gain 5% more critical strike from critical strike sources.
    shell_cover             = {  94967, 472707, 1 }, -- When dropping below 60% health, summon the aid of a Turtle, reducing the damage you take by 10% for 6 sec. This effect can only occur once every 1.5 min.
    slicked_shoes           = {  94979, 472719, 1 }, -- When Disengage removes a movement impairing effect, its cooldown is reduced by 4 sec.
    specialized_arsenal     = { 102390, 459542, 1 }, -- Aimed Shot deals 10% increased damage.
    survival_of_the_fittest = { 102422, 264735, 1 }, -- Reduces all damage you and your pet take by 30% for 8 sec.
    tar_trap                = { 102393, 187698, 1 }, -- Hurls a tar trap to the target location that creates a 8 yd radius pool of tar around itself for 30 sec when the first enemy approaches. All enemies have 50% reduced movement speed while in the area of effect. Limit 1. Trap will exist for 1 min.
    tarcoated_bindings      = { 102417, 459460, 1 }, -- Binding Shot's stun duration is increased by 1 sec.
    territorial_instincts   = { 102394, 459507, 1 }, -- The cooldown of Intimidation is reduced by 10 sec.
    trailblazer             = { 102400, 199921, 1 }, -- Your movement speed is increased by 30% anytime you have not attacked for 3 sec.
    tranquilizing_shot      = { 102380,  19801, 1 }, -- Removes 1 Enrage and 1 Magic effect from an enemy target. Successfully dispelling an effect generates 10 Focus.
    trigger_finger          = { 102396, 459534, 2 }, -- You and your pet have 5.0% increased attack speed. This effect is increased by 100% if you do not have an active pet.
    unnatural_causes        = { 102387, 459527, 1 }, -- Your damage over time effects deal 10% increased damage. This effect is increased by 50% on targets below 20% health.
    ursine_fury             = {  94972, 472476, 1 }, -- Your Bear's periodic damage has a 10% chance to reduce the cooldown of Butchery or Flanking Strike by 2.0 sec.
    wilderness_medicine     = { 102383, 343242, 1 }, -- Natural Mending now reduces the cooldown of Exhilaration by an additional 0.5 sec Mend Pet heals for an additional 25% of your pet's health over its duration, and has a 25% chance to dispel a magic effect each time it heals your pet.

    -- Marksmanship
    aimed_shot              = { 103982,  19434, 1 }, -- A powerful aimed shot that deals 553,260 Physical damage.
    ammo_conservation       = { 103975, 459794, 1 }, -- Rapid Fire shoots 3 additional shots. Aimed Shot cooldown reduced by 1.0 sec.
    aspect_of_the_hydra     = { 103957, 470945, 1 }, -- Aimed Shot, Rapid Fire, and Arcane Shot now hit a second nearby target for 40% of their damage.
    bullet_hell             = { 104095, 473378, 1 }, -- Damage from Multi-Shot and Volley reduces the cooldown of Rapid Fire by 0.25 sec. Damage from Aimed Shot reduces the cooldown of Volley by 0.25 sec.
    bulletstorm             = { 103962, 389019, 1 }, -- Damage from Rapid Fire increases the damage of Aimed Shot by 2% for 15 sec, stacking up to 15 times. New stacks do not refresh duration and are removed upon casting Rapid Fire.
    bullseye                = { 103950, 204089, 2 }, -- When your abilities damage a target below 20% health, you gain 1% increased critical strike chance for 6 sec, stacking up to 15 times.
    calling_the_shots       = { 103958, 260404, 1 }, -- Consuming Spotter's Mark reduces the cooldown of Trueshot by 3.0 sec.
    cunning                 = { 103986, 474440, 1 }, -- Your Spotting Eagle gains the Cunning specialization, granting you Master's Call and Pathfinding.  Master's Call Your pet removes all root and movement impairing effects from itself and a friendly target, and grants immunity to all such effects for 4 sec.  Pathfinding Your movement speed is increased by 8%.
    deadeye                 = { 103972, 321460, 1 }, -- Kill Shot now has 2 charges and has its cooldown reduced by 2.0 sec.
    double_tap              = { 103953, 473370, 1 }, -- Casting Trueshot or Volley grants Double Tap, causing your next Aimed Shot to fire again at 80% power, or your next Rapid Fire to fire 80% additional shots during its channel.
    eagles_accuracy         = { 103973, 473369, 2 }, -- Aimed Shot and Rapid Fire's damage is increased by 5.0%.
    feathered_frenzy        = { 103984, 470943, 1 }, -- Trueshot sends your Spotting Eagle into a frenzy, instantly applying Spotter's Mark to your target. During Trueshot, your chance to apply Spotter's Mark is increased by 100%.
    focused_aim             = { 103987, 378767, 1 }, -- Consuming Precise Shots reduces the cooldown of Aimed Shot by 0.75 sec.
    headshot                = { 103972, 471363, 1 }, -- Kill Shot can now benefit from Precise Shots at 25% effectiveness. Kill Shot consumes Precise Shots.
    improved_deathblow      = { 103969, 378769, 1 }, -- Aimed Shot now has a 15% chance and Rapid Fire now has a 25% chance to grant Deathblow. Kill Shot critical strike damage is increased by 25%.  Deathblow The cooldown of Kill Shot is reset. Your next Kill Shot can be used on any target, regardless of their current health.
    improved_spotters_mark  = { 104127, 466867, 1 }, -- The damage bonus of Spotter's Mark is increased by 20%.  Spotter's Mark Damaging an enemy with abilities empowered by Precise Shots has a 30% chance to apply Spotter's Mark to the primary target, causing your next Aimed Shot to deal 30% increased damage to the target.
    improved_streamline     = { 103987, 471427, 1 }, -- Streamline's cast time reduction effect is increased to 30%.
    in_the_rhythm           = { 103948, 407404, 1 }, -- When Rapid Fire finishes channeling, the time between your Auto Shots is reduced by 1.0 sec for 12 sec.
    incendiary_ammunition   = { 103985, 471428, 1 }, -- Bulletstorm now increases your critical strike damage by 2%. Additionally, Bulletstorm now stacks 5 more times.
    kill_zone               = { 103960, 459921, 1 }, -- Your spells and attacks deal 8% increased damage and ignore line of sight against any target in your Volley.
    killer_mark             = { 104096, 1215032, 1 }, -- Spotter's Mark now additionally increases the critical strike chance of Aimed Shot by 15%.
    lock_and_load           = { 103988, 194595, 1 }, -- Your ranged auto attacks have a 8% chance to trigger Lock and Load, causing your next Aimed Shot to cost no Focus and be instant.
    magnetic_gunpowder      = { 103981, 473522, 1 }, -- Consuming Precise Shots reduces the cooldown of Explosive Shot by 2.0 sec. Consuming Lock and Load reduces the cooldown of Explosive Shot by 8.0 sec.
    master_marksman         = { 103974, 260309, 1 }, -- Your ranged ability critical strikes cause the target to bleed for an additional 15% of the damage dealt over 6 sec.
    moving_target           = { 103980, 474296, 1 }, -- Consuming Precise Shots increases the damage of your next Aimed Shot by 20% and grants Streamline.  Streamline Your next Aimed Shot has its Focus cost and cast time reduced by 20%. Stacks up to 2 times.
    no_scope                = { 103955, 473385, 1 }, -- Rapid Fire grants Precise Shots.
    obsidian_arrowhead      = { 103959, 471350, 1 }, -- The damage of Auto Shot is increased by 25% and its critical strike chance is increased by 15%.
    ohnahran_winds          = { 103979, 1215021, 1 }, -- When your Eagle applies Spotter's Mark, it has a 25% chance to apply a Spotter's Mark to up to 3 additional nearby enemies.
    on_target               = { 103959, 471348, 1 }, -- Consuming Spotter's Mark grants 4% increased Haste for 10 sec, stacking up to 4 times. Multiple instances of this effect can overlap.
    penetrating_shots       = { 104130, 459783, 1 }, -- Gain critical strike damage equal to 40% of your critical strike chance.
    precise_shots           = { 103977, 260240, 1 }, -- Aimed Shot causes your next Arcane Shot or Multi-Shot to deal 80% more damage and cost 70% less Focus. Your Auto Shot damage is increased by 100% but the time between your Auto Shots is increased by 2.0 sec.
    precision_detonation    = { 103949, 471369, 1 }, -- Casting Explosive Shot grants Streamline. When Aimed Shot damages a target affected by your Explosive Shot, Explosive Shot instantly explodes, dealing 25% increased damage.  Streamline Your next Aimed Shot has its Focus cost and cast time reduced by 20%. Stacks up to 2 times.
    quickdraw               = { 103963, 473380, 1 }, -- Lock and Load now increases the damage of Aimed Shot by 15%.
    rapid_fire              = { 103961, 257044, 1 }, -- Shoot a stream of 10 shots at your target over 1.7 sec, dealing a total of 803,344 Physical damage. Usable while moving. Rapid Fire causes your next Aimed Shot to cast 20% faster. Each shot generates 2 Focus.
    razor_fragments         = { 103965, 384790, 1 }, -- After gaining Deathblow, your next Kill Shot will deal 75% increased damage, and shred up to 5 targets near your Kill Shot target for 35% of the damage dealt by Kill Shot over 6 sec.
    salvo                   = { 103960, 400456, 1 }, -- Volley now also applies Explosive Shot to up to 2 targets hit.
    shrapnel_shot           = { 104126, 473520, 1 }, -- Damaging an enemy with Explosive Shot increases the damage they receive from your next Arcane Shot or Multi-Shot by 30%.
    small_game_hunter       = { 103978, 459802, 1 }, -- Multi-Shot deals 75% increased damage and Explosive Shot deals 15% increased damage.
    streamline              = { 103983, 260367, 1 }, -- Rapid Fire's damage is increased by 15%. Casting Rapid Fire grants Streamline.  Streamline Your next Aimed Shot has its Focus cost and cast time reduced by 20%. Stacks up to 2 times.
    surging_shots           = { 103964, 391559, 1 }, -- Rapid Fire deals 35% additional damage, and Aimed Shot has a 15% chance to reset the cooldown of Rapid Fire.
    target_acquisition      = { 103968, 473379, 1 }, -- Consuming Spotter's Mark reduces the cooldown of Aimed Shot by 2.0 sec.
    tenacious               = { 103986, 474456, 1 }, -- Your Spotting Eagle gains the Tenacity specialization, granting you Endurance Training and Air Superiority.  Endurance Training You gain 5% increased maximum health.  Air Superiority Your Spotting Eagle alerts you to oncoming danger, reducing all damage you take by 3%
    tensile_bowstring       = { 103966, 471366, 1 }, -- While Trueshot is active, consuming Precise Shots extends Trueshot's duration by 1.0 sec, up to 5.0 sec. Additionally, Trueshot now increases the effectiveness of Streamline by 50%.
    trick_shots             = { 103957, 257621, 1 }, -- When Multi-Shot hits 3 or more targets, your next Aimed Shot or Rapid Fire will ricochet and hit up to 5 additional targets for 75% of normal damage.
    trueshot                = { 103947, 288613, 1 }, -- Increases your critical strike chance by 20% and critical strike damage by 30% for 15 sec. Reduces the cooldown of your Aimed Shot and Rapid Fire by 60%. Consuming Spotter's Mark reduces the cooldown of Trueshot by 3.0 sec
    unbreakable_bond        = { 104127, 1223323, 1 }, -- Regain access to Call Pet. While outdoors, your pet deals 15% increased damage and takes 15% reduced damage.
    unerring_vision         = { 103953, 474738, 1 }, -- Trueshot now increases your critical strike chance by an additional 10% and increases your critical strike damage by an additional 20%. Additionally, Calling the Shots reduces Trueshot's cooldown by an additional 1.0 sec.
    volley                  = { 103956, 260243, 1 }, -- Rain a volley of arrows down over 6 sec, dealing up to 754,054 Physical damage to any enemy in the area, and gain the effects of Trick Shots for as long as Volley is active.
    windrunner_quiver       = { 103952, 473523, 1 }, -- Precise Shots can now stack up to 2 times, but its damage bonus is reduced to 80%. Casting Aimed Shot has a 50% chance to grant an additional stack of Precise Shots.

    -- Dark Ranger
    banshees_mark           = {  94957, 467902, 1 }, -- Murder of Crows now deals Shadow damage. Black Arrow's initial damage has a 25% chance to summon a Murder of Crows on your target.  A Murder of Crows
    black_arrow             = {  94987, 466932, 1, "dark_ranger" }, -- Your Kill Shot is replaced with Black Arrow.  Black Arrow You attempt to finish off a wounded target, dealing 358,172 Shadow damage and 35,873 Shadow damage over 10 sec. Only usable on enemies above 80% health or below 20% health.
    bleak_arrows            = {  94961, 467749, 1 }, -- Your auto shot now deals Shadow damage, allowing it to bypass armor. Your auto shot has a 8% chance to grant Deathblow.  Deathblow The cooldown of Kill Shot is reset. Your next Kill Shot can be used on any target, regardless of their current health.
    bleak_powder            = {  94974, 467911, 1 }, -- Casting Black Arrow while Trick Shots is active causes Black Arrow to explode upon hitting its target, dealing 323,501 Shadow damage to other nearby enemies.
    dark_chains             = {  94960, 430712, 1 }, -- While in combat, Disengage will chain the closest target to the ground, causing them to move 40% slower until they move 8 yards away.
    ebon_bowstring          = {  94986, 467897, 1 }, -- Casting Black Arrow has a 15% chance to grant Deathblow.  Deathblow The cooldown of Kill Shot is reset. Your next Kill Shot can be used on any target, regardless of their current health.
    embrace_the_shadows     = {  94959, 430704, 1 }, -- You heal for 15% of all Shadow damage dealt by you or your pets.
    phantom_pain            = {  94986, 467941, 1 }, -- When Aimed Shot deals damage, 8% of the damage dealt is replicated to each other unit affected by Black Arrow.
    shadow_dagger           = {  94960, 467741, 1 }, -- While in combat, Disengage releases a fan of shadow daggers, dealing 392 Shadow damage per second and reducing affected target's movement speed by 30% for 6 sec.
    shadow_hounds           = {  94983, 430707, 1 }, -- Each time Black Arrow deals damage, you have a small chance to manifest a Dark Hound to charge to your target and deal Shadow damage to nearby targets for 8 sec.
    shadow_surge            = {  94982, 467936, 1 }, -- Periodic damage from Black Arrow has a small chance to erupt in a burst of darkness, dealing 117,821 Shadow damage to all enemies near the target. Damage reduced beyond 8 targets.
    smoke_screen            = {  94959, 430709, 1 }, -- Exhilaration grants you 3 sec of Survival of the Fittest. Survival of the Fittest activates Exhilaration at 50% effectiveness.
    soul_drinker            = {  94983, 469638, 1 }, -- When an enemy affected by Black Arrow dies, you have a 10% chance to gain Deathblow.  Deathblow The cooldown of Kill Shot is reset. Your next Kill Shot can be used on any target, regardless of their current health.
    the_bell_tolls          = {  94968, 467644, 1 }, -- Black Arrow is now usable on enemies with greater than 80% health or less than 20% health.
    withering_fire          = {  94993, 466990, 1 }, -- While Trueshot is active, you surrender to darkness, granting you Deathblow. Casting Black Arrow while under the effects of Withering Fire causes you to additionally fire a barrage of 2 additional Black Arrows at nearby targets at 50% effectiveness.

    -- Sentinel
    catch_out               = {  94990, 451516, 1 }, -- When a target affected by Sentinel deals damage to you, they are rooted for 3 sec. May only occur every 1 min per target.
    crescent_steel          = {  94980, 451530, 1 }, -- Targets you damage below 20% health gain a stack of Sentinel every 3 sec.
    dont_look_back          = {  94989, 450373, 1 }, -- Each time Sentinel deals damage to an enemy you gain an absorb shield equal to 1.0% of your maximum health, up to 10%.
    extrapolated_shots      = {  94973, 450374, 1 }, -- When you apply Sentinel to a target not affected by Sentinel, you apply 1 additional stack.
    eyes_closed             = {  94970, 450381, 1 }, -- For 8 sec after activating Trueshot, all abilities are guaranteed to apply Sentinel.
    invigorating_pulse      = {  94971, 450379, 1 }, -- Each time Sentinel deals damage to an enemy it has an up to 15% chance to generate 5 Focus. Chances decrease with each additional Sentinel currently imploding applied to enemies.
    lunar_storm             = {  94978, 450385, 1 }, -- Every 30 sec your next Rapid Fire launches a celestial arrow that conjures a 12 yd radius Lunar Storm at the target's location dealing 104,729 Arcane damage. For the next 12 sec, a random enemy affected by Sentinel within your Lunar Storm gets struck for 98,184 Arcane damage every 0.4 sec. Any target struck by this effect takes 10% increased damage from you and your pet for 8 sec.
    overwatch               = {  94980, 450384, 1 }, -- All Sentinel debuffs implode when a target affected by more than 3 stacks of your Sentinel falls below 20% health. This effect can only occur once every 15 sec per target.
    release_and_reload      = {  94958, 450376, 1 }, -- When you apply Sentinel on a target, you have a 15% chance to apply a second stack.
    sentinel                = {  94976, 450369, 1, "sentinel" }, -- Your attacks have a chance to apply Sentinel on the target, stacking up to 10 times. While Sentinel stacks are higher than 3, applying Sentinel has a chance to trigger an implosion, causing a stack to be consumed on the target every sec to deal 84,588 Arcane damage.
    sentinel_precision      = {  94981, 450375, 1 }, -- Aimed Shot and Rapid Fire deal 5% increased damage.
    sentinel_watch          = {  94970, 451546, 1 }, -- Whenever a Sentinel deals damage, the cooldown of Trueshot is reduced by 1 sec, up to 15 sec.
    sideline                = {  94990, 450378, 1 }, -- When Sentinel starts dealing damage, the target is snared by 40% for 3 sec.
    symphonic_arsenal       = {  94965, 450383, 1 }, -- Multi-Shot discharges arcane energy from all targets affected by your Sentinel, dealing 30,350 Arcane damage to up to 5 targets within 8 yds of your Sentinel targets.
} )

-- PvP Talents
spec:RegisterPvpTalents( {
    aspect_of_the_fox      = 5700, -- (1219162)
    chimaeral_sting        =  653, -- (356719) Stings the target, dealing 117,636 Nature damage and initiating a series of venoms. Each lasts 3 sec and applies the next effect after the previous one ends.  Scorpid Venom: 90% reduced movement speed.  Spider Venom: Silenced.  Viper Venom: 20% reduced damage and healing.
    consecutive_concussion = 5440, -- (357018)
    diamond_ice            = 5533, -- (203340)
    explosive_powder       = 5688, -- (1218150)
    hunting_pack           = 3729, -- (203235)
    rangers_finesse        =  659, -- (248443)
    snipers_advantage      =  660, -- (1217102) Trueshot and Volley increase the range of all shots by 30% for their duration.
    survival_tactics       =  651, -- (202746)
} )

-- Auras
spec:RegisterAuras( {
    a_murder_of_crows = {
        id = 131894,
        duration = 15.0,
        tick_time = 1.0,
        max_stack = 1,
    },
    aspect_of_the_chameleon = {
        id = 61648,
        duration = 60,
        max_stack = 1
    },
    -- Movement speed increased by $w1%.
    -- https://wowhead.com/beta/spell=186257
    aspect_of_the_cheetah_sprint = {
        id = 186257,
        duration = 3,
        max_stack = 1
    },
    -- Movement speed increased by $w1%.
    -- https://wowhead.com/beta/spell=186258
    aspect_of_the_cheetah = {
        id = 186258,
        duration = 9,
        max_stack = 1
    },
    -- The range of $?s259387[Mongoose Bite][Raptor Strike] is increased to $265189r yds.
    -- https://wowhead.com/beta/spell=186289
    aspect_of_the_eagle = {
        id = 186289,
        duration = 15,
        max_stack = 1
    },
    -- Deflecting all attacks.  Damage taken reduced by $w4%.
    -- https://wowhead.com/beta/spell=186265
    aspect_of_the_turtle = {
        id = 186265,
        duration = 8,
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=120360
    barrage = {
        id = 120360,
        duration = function() return ( talent.rapid_fire_barrage.enabled and 2 or 3 ) * haste end,
        tick_time = function() return talent.rapid_fire_barrage.enabled and spec.auras.rapid_fire.tick_time or ( 3 * haste / 16) end,
        max_stack = 1
    },
     -- Lore revealed.
     beast_lore = {
        id = 1462,
        duration = 30.0,
        max_stack = 1,
    },
    -- Dealing $s1% less damage to the Hunter.
    binding_shackles = {
        id = 321469,
        duration = 8.0,
        max_stack = 1,
    },
    -- Taking $w1 Shadow damage every $t1 seconds.
    black_arrow = {
        id = 468572,
        duration = 14,
        tick_time = 1,
        max_stack = 1,
    },
    -- Firing at the target, probably not needed?
    bleak_arrows = {
        id = 467718,
        duration = 60.0,
        max_stack = 1,
     },
    -- Bleeding for $w1 Physical damage every $t1 sec.  Taking $s2% increased damage from the Hunter's pet.
    -- https://wowhead.com/beta/spell=321538
    bloodshed = {
        id = 321538,
        duration = 18,
        tick_time = 3,
        max_stack = 1
    },
    bulletstorm = {
        id = 389020,
        duration = 15,
        max_stack = function() return 15 + 5 * talent.incendiary_ammunition.rank end
    },
    -- Talent: Critical strike chance increased by $s1%.
    -- https://wowhead.com/beta/spell=204090
    bullseye = {
        id = 204090,
        duration = 6,
        max_stack = function() return 15 * talent.bullseye.rank end,
    },
    -- Talent: Movement speed reduced by $s4%.
    -- https://wowhead.com/beta/spell=186387
    bursting_shot = {
        id = 186387,
        duration = 6,
        type = "Ranged",
        max_stack = 1
    },
    -- Talent: Disoriented.
    -- https://wowhead.com/beta/spell=224729
    bursting_shot_disorient = {
        id = 224729,
        duration = 4,
        mechanic = "snare",
        max_stack = 1
    },
    -- Talent: Stealthed.
    -- https://wowhead.com/beta/spell=199483
    camouflage = {
        id = 199483,
        duration = 60,
        max_stack = 1
    },
    -- Rooted.
    catch_out = {
        id = 451517,
        duration = 3.0,
        max_stack = 1,
    },
    -- Taking $w2% increased damage from $@auracaster.
    chakram = {
        id = 375893,
        duration = 10.0,
        max_stack = 1,
    },
    -- Talent: Movement slowed by $s1%.
    -- https://wowhead.com/beta/spell=5116
    concussive_shot = {
        id = 5116,
        duration = 6,
        mechanic = "snare",
        type = "Ranged",
        max_stack = 1
    },
    -- Stunned.
    consecutive_concussion = {
        id = 357021,
        duration = 4.0,
        max_stack = 1,
    },
    -- Your abilities are empowered.    $@spellname187708: Reduces the cooldown of Wildfire Bomb by an additional 1 sec.  $@spellname320976: Applies Bleeding Gash to your target.
    -- https://wowhead.com/beta/spell=361738
    coordinated_assault = {
        id = 361738,
        duration = 5,
        max_stack = 1
    },
    -- Talent: Your next Kill Shot can be used on any target, regardless of their current health.
    -- https://wowhead.com/beta/spell=378770
    deathblow = {
        id = 378770,
        duration = 12,
        max_stack = 1
    },
    -- Talent: Your next Aimed Shot will fire a second time instantly at $s4% power and consume no Focus, or your next Rapid Fire will shoot $s3% additional shots during its channel.
    -- https://wowhead.com/beta/spell=260402
    double_tap = {
        id = 260402,
        duration = 15,
        max_stack = 1
    },
    -- Vision is enhanced.
    -- https://wowhead.com/beta/spell=6197
    eagle_eye = {
        id = 6197,
        duration = 60,
        type = "Magic",
        max_stack = 1
    },
    -- Rooted.
    entrapment = {
        id = 393456,
        duration = 4.0,
        max_stack = 1,
    },
    -- Talent: Exploding for $212680s1 Fire damage after $t1 sec.
    -- https://wowhead.com/beta/spell=212431
    explosive_shot = {
        id = 212431,
        duration = 3,
        tick_time = 3,
        type = "Ranged",
        max_stack = 1
    },
    -- All abilities are guaranteed to apply Sentinel.
    eyes_closed = {
        id = 451180,
        duration = 8.0,
        max_stack = 1,
    },
    -- Directly controlling pet.
    -- https://wowhead.com/beta/spell=321297
    eyes_of_the_beast = {
        id = 321297,
        duration = 60,
        type = "Magic",
        max_stack = 1
    },
    -- Feigning death.
    -- https://wowhead.com/beta/spell=5384
    feign_death = {
        id = 5384,
        duration = 360,
        max_stack = 1
    },
    -- Covenant: Bleeding for $s1 Shadow damage every $t1 sec.
    -- https://wowhead.com/beta/spell=324149
    flayed_shot = {
        id = 324149,
        duration = 18,
        tick_time = 2,
        mechanic = "bleed",
        type = "Ranged",
        max_stack = 1
    },
    freezing_trap = {
        id = 3355,
        duration = 60,
        max_stack = 1,
    },
    -- Can always be seen and tracked by the Hunter.; Damage taken increased by $428402s4% while above $s3% health.
    -- https://wowhead.com/beta/spell=257284
    hunters_mark = {
        id = 257284,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    in_the_rhythm = {
        id = 407405,
        duration = 6,
        max_stack = 1
    },
    -- Talent: Bleeding for $w2 damage every $t2 sec.
    -- https://wowhead.com/beta/spell=259277
    kill_command = {
        id = 259277,
        duration = 8,
        max_stack = 1
    },
    -- $@auracaster can attack this target regardless of line of sight.; $@auracaster deals $w2% increased damage to this target.
    kill_zone = {
        id = 393480,
        duration = 3600,
        max_stack = 1,
    },
    -- Injected with Latent Poison. $?s137015[Barbed Shot]?s137016[Aimed Shot]?s137017&!s259387[Raptor Strike][Mongoose Bite]  consumes all stacks of Latent Poison, dealing ${$378016s1/$s1} Nature damage per stack consumed.
    -- https://wowhead.com/beta/spell=378015
    latent_poison = {
        id = 378015,
        duration = 15,
        max_stack = 10
    },
   -- Talent: Aimed Shot costs no Focus and is instant.
    -- https://wowhead.com/beta/spell=194594
    lock_and_load = {
        id = 194594,
        duration = 15,
        max_stack = 1
    },
    lone_wolf = {
        id = 164273,
        duration = 3600,
        max_stack = 1,
    },
    -- Damage taken from $@auracaster and their pets increased by $w1%.
    lunar_storm = {
        id = 450884,
        duration = 8.0,
        max_stack = 1,
    },
    lunar_storm_cooldown = {
        id = 451803,
        duration = 30,
        max_stack = 1,
        onRemove = function()
            applyBuff( "lunar_storm_ready" )
        end,
    },
    lunar_storm_ready = {
        id = 451805,
        duration = 3600,
        max_stack = 1
    },
    -- https://www.wowhead.com/spell=269576
    master_marksman = {
        id = 269576,
        duration = 6,
        max_stack = 1,
    },
    -- Talent: Threat redirected from Hunter.
    -- https://wowhead.com/beta/spell=34477
    misdirection = {
        id = 34477,
        duration = 30,
        max_stack = 1
    },
    --
    moving_target = {
        id = 474293,
        duration = 15,
        max_stack = 1
    },
    -- Damage taken reduced by $w1%
    no_hard_feelings = {
        id = 459547,
        duration = 5.0,
        max_stack = 1,
    },
    on_target = {
        id = 474257,
        duration = 10,
        max_stack = 4
    },
    pathfinding = {
        id = 264656,
        duration = 3600,
        max_stack = 1,
    },
    -- Suffering $w1 Fire damage every $t1 sec.
    -- https://wowhead.com/beta/spell=270332
    pheromone_bomb = {
        id = 270332,
        duration = 6,
        tick_time = 1,
        type = "Ranged",
        max_stack = 1
    },
    -- Talent: Increased movement speed by $s1%.
    -- https://wowhead.com/beta/spell=118922
    posthaste = {
        id = 118922,
        duration = 4,
        max_stack = 1
    },
    -- Damage of $?s342049[Chimaera Shot][Arcane Shot] or Multi-Shot increased by $s1 and their Focus cost is reduced by $s6%.
    precise_shots = {
        id = 260242,
        duration = 15,
        max_stack = function() return 1 + talent.windrunner_quiver.rank end,
        copy = { "precise_shot" } -- just incase simc uses it
    },
    -- Recently benefitted from Quick Load.
    quick_load = {
        id = 385646,
        duration = 25.0,
        max_stack = 1,
        copy = "quick_load_icd"
    },
    rangers_finesse = {
        id = 408518,
        duration = 18,
        max_stack = 3
    },
    -- Talent: Being targeted by Rapid Fire.
    -- https://wowhead.com/beta/spell=257044
    rapid_fire = {
        id = 257044,
        duration = function () return 2 * haste end,
        tick_time = function ()
            return ( 2 * haste ) / ( action.rapid_fire.shots )
        end,
        type = "Ranged",
        max_stack = 1
    },
    -- Your next Kill Shot will deal 75% increased damage, and shred up to 5 targets near your Kill shot target for 25% of the damage dealt by Kill Shot over 6 sec.
    razor_fragments = {
        id = 388998,
        duration = 15,
        max_stack = 1,
    },
    -- Bleeding for $w1 damage every $t1 sec.
    razor_fragments_bleed = {
        id = 385638,
        duration = 6,
        tick_time = 2,
        mechanic = "bleed",
        max_stack = 1
    },
    -- Heals you for $w1 every $t sec.
    rejuvenating_wind = {
        id = 385540,
        duration = 8.0,
        max_stack = 1,
    },
    salvo = {
        id = 400456,
        duration = 15,
        max_stack = 1
    },
    -- Talent: Feared.
    -- https://wowhead.com/beta/spell=1513
    scare_beast = {
        id = 1513,
        duration = 20,
        mechanic = "flee",
        type = "Magic",
        max_stack = 1
    },
    -- Talent: Disoriented.
    -- https://wowhead.com/beta/spell=213691
    scatter_shot = {
        id = 213691,
        duration = 4,
        type = "Ranged",
        max_stack = 1
    },
    -- $w1% reduced movement speed.
    scorpid_venom = {
        id = 356723,
        duration = 3.0,
        max_stack = 1,
    },
    -- Sentinel from $@auracaster has a chance to start dealing $450412s1 Arcane damage every sec.
    sentinel = {
        id = 450387,
        duration = 1200.0,
        max_stack = 1,
    },
    -- Leech increased by $s1%.
    sentinels_protection = {
        id = 393777,
        duration = 12.0,
        max_stack = 1,
    },
    -- Suffering $s2 Nature damage every $t2 sec.
    serpent_sting = {
        id = 271788,
        duration = 18,
        tick_time = 3,
        max_stack = 1,
    },
    -- https://www.wowhead.com/spell=474310
    shrapnel_shot = {
        id = 474310,
        duration = 12,
        max_stack = 1,
    },
    -- Movement slowed by $w1%.
    sideline = {
        id = 450845,
        duration = 3.0,
        max_stack = 1,
    },
    -- Range of all shots increased by $w3%.
    sniper_shot = {
        id = 203155,
        duration = 6.0,
        max_stack = 1,
    },
    -- https://www.wowhead.com/spell=466872
    spotters_mark = {
        id = 466872,
        duration = 12,
        max_stack = 1,
    },
    -- Talent: Haste increased by $s1%.
    -- https://wowhead.com/beta/spell=193534
    steady_focus = {
        id = 193534,
        duration = 15,
        max_stack = 1
    },
    -- Talent: Bleeding for $w1 damage every $t1 seconds.
    -- https://wowhead.com/beta/spell=162487
    steel_trap = {
        id = 162487,
        duration = 20,
        tick_time = 2,
        mechanic = "bleed",
        type = "Ranged",
        max_stack = 1
    },
    -- Talent: Aimed Shot cast time reduced by $s1%.
    -- https://wowhead.com/beta/spell=342076
    streamline = {
        id = 342076,
        duration = 15,
        max_stack = 1,
        -- Focus cost
        streamlineCostMultiplier = function() return 1 - ( buff.streamline.stack * 0.2 * ( talent.tensile_bowstring.enabled and buff.trueshot.up and 1.5 or 1 ) ) end,
        -- Cast speed reduction
        streamlineCastMultiplier = function() return 1 - ( buff.streamline.stack * ( 0.2 + 0.1 * talent.improved_streamline.rank ) * ( talent.tensile_bowstring.enabled and buff.trueshot.up and 1.5 or 1 ) ) end
    },
    survival_of_the_fittest = {
        id = 281195,
        duration = function() return 6 + 2 * talent.lone_survivor.rank end,
        max_stack = 1,
    },
    -- Taming a pet.
    tame_beast = {
        id = 1515,
        duration = 6.0,
        pandemic = true,
        max_stack = 1,
    },
    tar_trap = {
        id = 135299,
        duration = 30,
        max_stack = 1
    },
    -- Dealing bonus Nature damage to the target every $t sec for $d.
    titans_thunder = {
        id = 207094,
        duration = 8.0,
        tick_time = 1.0,
        max_stack = 1,
    },
    trailblazer = {
        id = 231390,
        duration = 3600,
        max_stack = 1,
    },
    trick_shots = {
        id = 257622,
        duration = 20,
        max_stack = 1
    },
    trueshot = {
        id = 288613,
        duration = function () return ( 15 + ( legendary.eagletalons_true_focus.enabled and 3 or 0 ) ) * ( 1 + ( conduit.sharpshooters_focus.mod * 0.01 ) ) end,
        max_stack = 1,
    },
    -- Talent: Raining arrows down in the target area.
    -- https://wowhead.com/beta/spell=260243
    volley = {
        id = 260243,
        duration = 6,
        tick_time = 0.5,
        max_stack = 1
    },
    -- Movement speed reduced by $s1%.
    -- https://wowhead.com/beta/spell=195645
    wing_clip = {
        id = 195645,
        duration = 15,
        max_stack = 1
    },
    withering_fire = {
        id = 466991,
        duration = function () return spec.auras.trueshot.duration end,
        max_stack = 1

    },
    -- Conduit
    brutal_projectiles = {
        id = 339929,
        duration = 3600,
        max_stack = 1,
    },

    -- Legendaries
    nessingwarys_trapping_apparatus = {
        id = 336744,
        duration = 5,
        max_stack = 1,
        copy = { "nesingwarys_trapping_apparatus", "nesingwarys_apparatus", "nessingwarys_apparatus" }
    },
    secrets_of_the_unblinking_vigil = {
        id = 336892,
        duration = 20,
        max_stack = 1,
    },

    -- stub.
    eagletalons_true_focus_stub = {
        duration = 10,
        max_stack = 1,
        copy = "eagletalons_true_focus"
    }
} )


spec:RegisterStateExpr( "trick_shots", function ()
    return buff.trick_shots.up or buff.volley.up or false
end )


--[[
local lunar_storm_expires = 0

spec:RegisterCombatLogEvent( function( _, subtype, _,  sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )

    if sourceGUID == state.GUID then
        if ( subtype == "SPELL_AURA_APPLIED" or subtype == "SPELL_AURA_REFRESH" or subtype == "SPELL_AURA_APPLIED_DOSE" ) then
                if spellID == 450978 then
                lunar_storm_expires = GetTime() + 13.7
            end
        end
    end
end )--]]


local ExpireNesingwarysTrappingApparatus = setfenv( function()
    focus.regen = focus.regen * 0.5
    forecastResources( "focus" )
end, state )


spec:RegisterStateTable( "tar_trap", setmetatable( {}, {
    __index = function( t, k )
        return state.debuff.tar_trap[ k ]
    end
} ) )



spec:RegisterGear( "tww1", 212018, 212019, 212020, 212021, 212023 )
spec:RegisterGear( "tww2", 229271, 229269, 229274, 229272, 229270 )
spec:RegisterAuras( {
    -- 2-set
    -- https://www.wowhead.com/spell=1218033
    -- Jackpot! Auto shot damage increased by 200% and the time between auto shots is reduced by 0.5 sec.
    jackpot = {
        id = 1218033,
        duration = 10,
        max_stack = 1,
    },

} )

-- Dragonflight
spec:RegisterGear( "tier29", 200390, 200392, 200387, 200389, 200391 )
spec:RegisterAuras( {
    -- 2pc
    find_the_mark = {
        id = 394366,
        duration = 15,
        max_stack = 1
    },
    hit_the_mark = {
        id = 394371,
        duration = 6,
        max_stack = 1
    },
    -- 4pc
    focusing_aim = {
        id = 394384,
        duration = 15,
        max_stack = 1
    }
} )
spec:RegisterGear( "tier30", 202482, 202480, 202479, 202478, 202477 )
spec:RegisterGear( "tier31", 207216, 207217, 207218, 207219, 207221, 217183, 217185, 217181, 217182, 217184 )


local SpottersMarkConsumer = setfenv( function ( max_targets )

    local markConsumptions = 0
    local trueshotCDR = talent.unerring_vision.enabled and 3 or 2

    if max_targets >= active_enemies then
        -- Case where all consumptions are guaranteed
        markConsumptions = min( active_enemies, active_dot.spotters_mark )
    else
        -- Case where not all targets can be hit, ONLY apply CDR based on what we can guarantee
        local guaranteedHits = min( max_targets, active_dot.spotters_mark )
        local overflowTargets = active_enemies - max_targets
        markConsumptions = max( 0, guaranteedHits - overflowTargets )
    end

    removeDebuff( "target", "spotters_mark" )
    active_dot.spotters_mark = max( 0, active_dot.spotters_mark - ( markConsumptions - 1 ) )
    if talent.calling_the_shots.enabled then reduceCooldown( "trueshot", trueshotCDR * markConsumptions ) end
    if talent.target_acquisition.enabled then reduceCooldown( "aimed_shot", 2 * markConsumptions ) end
    if talent.on_target.enabled then addStack( "on_target", nil, markConsumptions ) end

end, state )

local tensileTrueshotExtension = 0

local PreciseShotsConsumer = setfenv( function ()

    local count = buff.precise_shots.stack

    if set_bonus.tww1 >= 4 or talent.moving_target.enabled then
        applyBuff( "moving_target" )
        addStack( "streamline", nil, count )
    end

    if talent.magnetic_gunpowder.enabled then reduceCooldown( "explosive_shot", 2 * count ) end

    if talent.focused_aim.enabled then reduceCooldown( "aimed_shot", 0.75 * count ) end

    if talent.tensile_bowstring.enabled and tensileTrueshotExtension < 5 then

        if tensileTrueshotExtension == 4 then
            -- If consuming 2 stacks @ 4, it still caps at 5. Don't roll over to 6
            buff.trueshot.expires = buff.trueshot.expires + 1
        else
            buff.trueshot.expires = buff.trueshot.expires + count
        end

        tensileTrueshotExtension = tensileTrueshotExtension + count
    end

    removeBuff( "precise_shots" )
end, state )

spec:RegisterHook( "reset_precast", function ()
    if debuff.tar_trap.up then
        debuff.tar_trap.expires = debuff.tar_trap.applied + 30
    end

    if legendary.nessingwarys_trapping_apparatus.enabled then
        if buff.nesingwarys_apparatus.up then
            state:QueueAuraExpiration( "nesingwarys_apparatus", ExpireNesingwarysTrappingApparatus, buff.nesingwarys_apparatus.expires )
        end
    end

    if legendary.eagletalons_true_focus.enabled then
        rawset( buff, "eagletalons_true_focus", buff.trueshot_aura )
    else
        rawset( buff, "eagletalons_true_focus", buff.eagletalons_true_focus_stub )
    end

    if covenant.kyrian then if now - action.resonating_arrow.lastCast < 6 then applyBuff( "resonating_arrow", 10 - ( now - action.resonating_arrow.lastCast ) ) end end

end )

-- Abilities
spec:RegisterAbilities( {
    -- Trait: A powerful aimed shot that deals $s1 Physical damage$?s260240[ and causes your next 1-$260242u ][]$?s342049&s260240[Chimaera Shots]?s260240[Arcane Shots][]$?s260240[ or Multi-Shots to deal $260242s1% more damage][].$?s260228[    Aimed Shot deals $393952s1% bonus damage to targets who are above $260228s1% health.][]$?s378888[    Aimed Shot also fires a Serpent Sting at the primary target.][]
    aimed_shot = {
        id = 19434,
        cast = function ()
            if buff.lock_and_load.up then return 0 end
            return 3 * haste * ( spec.auras.streamline.streamlineCastMultiplier )
        end,
        charges = 2,
        cooldown = function () return haste * 12 * ( buff.trueshot.up and 0.4 or 1 ) - ( 1 * talent.ammo_conservation.rank ) end,
        recharge = function () return haste * 12 * ( buff.trueshot.up and 0.4 or 1 ) - ( 1 * talent.ammo_conservation.rank ) end,
        gcd = "spell",
        school = "physical",

        cycle_to = true,
        cycle = "spotters_mark",

        max_targets = function() return ( trick_shots and min( 6, active_enemies ) ) or ( talent.aspect_of_the_hydra.enabled and min ( 2, active_enemies ) ) or 1 end,

        spend = function ()
            if buff.lock_and_load.up or buff.secrets_of_the_unblinking_vigil.up then return 0 end
            return 35 * ( spec.auras.streamline.streamlineCostMultiplier * ( legendary.eagletalons_true_focus.enabled and 0.75 or 1 ) )
        end,
        spendType = "focus",

        talent = "aimed_shot",
        texture = 135130,
        startsCombat = true,
        indicator = function() if settings.trueshot_rapid_fire and buff.trueshot.up then return spec.abilities.rapid_fire.texture end end,

        usable = function ()
            if action.aimed_shot.cast > 0 and moving and settings.prevent_hardcasts then return false, "prevent_hardcasts is checked and player is moving" end
            return true
        end,

        handler = function ()
            -- Simple buffs
            removeDebuff( "target", "spotters_mark" )
            removeBuff ( "moving_target" )
            if talent.precise_shots.enabled then addStack( "precise_shots", nil, 1 + talent.windrunner_quiver.rank ) end
            if debuff.spotters_mark.up then SpottersMarkConsumer( action.aimed_shot.max_targets ) end

            if buff.lock_and_load.up then
                removeBuff( "lock_and_load" )
                if talent.magnetic_gunpowder.enabled then reduceCooldown( "explosive_shot", 8 ) end
                if set_bonus.tww2 >= 4 then spec.abilities.explosive_shot.handler() end
            else
                removeBuff( "streamline" )
            end
            if debuff.explosive_shot.up and talent.precision_detonation.enabled then removeDebuff( "target", "explosive_shot" ) end

            if buff.double_tap.up then
                removeBuff( "double_tap" )
                spec.abilities.aimed_shot.handler()
            end

            if talent.bullet_hell.enabled then reduceCooldown( "volley", 0.5 * action.aimed_shot.max_targets ) end

            -- Trick Shots
            if buff.trick_shots.up and buff.volley.down then
                removeBuff( "trick_shots" )
            end

            --- Legacy / PvP stuff
            if set_bonus.tier29_2pc > 0 then
                if buff.find_the_mark.up then
                 removeBuff( "find_the_mark" )
                    applyDebuff( "target", "hit_the_mark" )
                end
            end
            if legendary.secrets_of_the_unblinking_vigil.enabled then
                if buff.secrets_of_the_unblinking_vigil.up then removeBuff( "secrets_of_the_unblinking_vigil" ) end
            end
            if pvptalent.rangers_finesse.enabled then addStack( "rangers_finesse" ) end
        end,
    },

    -- A quick shot that causes $sw2 Arcane damage.$?s260393[    Arcane Shot has a $260393h% chance to reduce the cooldown of Rapid Fire by ${$260393m1/10}.1 sec.][]
    arcane_shot = {
        id = 185358,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        max_targets = function() return ( trick_shots and min( 6, active_enemies ) ) or ( talent.aspect_of_the_hydra.enabled and min ( 2, active_enemies ) ) or 1 end,

        spend = function () return  40  * ( buff.precise_shots.up and 0.6 or 1 ) * ( buff.trueshot.up and legendary.eagletalons_true_focus.enabled and 0.75 or 1 ) end,
        spendType = "focus",

        startsCombat = true,
        cycle = "spotters_mark",

        -- notalent = "chimaera_shot",

        handler = function ()

            if buff.precise_shots.up then PreciseShotsConsumer() end

            -- Legacy / PvP stuff
            if set_bonus.tier29_4pc > 0 then
                removeBuff( "focusing_aim" )
            end

        end,
    },


    -- The Hunter takes on the aspect of a chameleon, becoming untrackable.
    aspect_of_the_chameleon = {
        id = 61648,
        cast = 0.0,
        cooldown = 180.0,
        gcd = "spell",

        startsCombat = false,

        handler = function ()
            applyBuff( "aspect_of_the_chameleon" )
        end,
    },

    -- Increases your movement speed by $s1% for $d, and then by $186258s1% for another $186258d$?a445701[, and then by $445701s1% for another $445701s2 sec][].$?a459455[; You cannot be slowed below $s2% of your normal movement speed.][]
    aspect_of_the_cheetah = {
        id = 186257,
        cast = 0.0,
        cooldown = function() return ( 180.0 - 30 * talent.born_to_be_wild.rank ) * ( talent.hunting_pack.enabled and 0.5 or 1 ) end,
        gcd = "off",

        startsCombat = false,

        handler = function ()
            applyBuff( "aspect_of_the_cheetah" )
        end,
    },

    -- Deflects all attacks and reduces all damage you take by $s4% for $d, but you cannot attack.$?s83495[  Additionally, you have a $83495s1% chance to reflect spells back at the attacker.][]
    aspect_of_the_turtle = {
        id = 186265,
        cast = 0.0,
        cooldown = function() return 180.0 - 30 * talent.born_to_be_wild.rank end,
        gcd = "off",

        startsCombat = false,

        handler = function ()
            applyBuff( "aspect_of_the_turtle" )
        end,
    },

    -- Talent: Fires a magical projectile, tethering the enemy and any other enemies within $s2 yards for $d, stunning them for $117526d if they move more than $s2 yards from the arrow.$?s321468[    Targets stunned by Binding Shot deal $321469s1% less damage to you for $321469d after the effect ends.][]
    binding_shot = {
        id = 109248,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",

        talent = "binding_shot",
        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "binding_shot" )
        end,
    },

    -- Fire a Black Arrow into your target, dealing $o1 Shadow damage over $d.; Each time Black Arrow deals damage, you have a $s2% chance to generate a charge of $?a137015[Barbed Shot]?a137016[Aimed Shot and reduce its cast time by $439659s2%][Barbed Shot or Aimed Shot].
    black_arrow = {
        id = 466930,
        cast = 0.0,
        cooldown = function() return 10 - ( 2 * talent.deadeye.rank ) end,
        charges = function() if talent.deadeye.enabled then return 2 end end,
        recharge = function() if talent.deadeye.enabled then return 10 end end,
        gcd = "spell",

        spend = 10,
        spendType = 'focus',

        talent = "black_arrow",
        startsCombat = true,

        cycle = "black_arrow",

        usable = function () return buff.deathblow.up or buff.flayers_mark.up or ( talent.the_bell_tolls.enabled and target.health_pct > 80 ) or target.health_pct < 20, "requires flayers_mark or target health below 20 percent or above 80 percent" end,
        handler = function ()
            applyDebuff( "target", "black_arrow" )
            spec.abilities.kill_shot.handler()
        end,
        bind = "kill_shot"
    },

    -- Talent: Fires an explosion of bolts at all enemies in front of you, knocking them back, snaring them by $s4% for $d, and dealing $s1 Physical damage.$?s378771[    When you fall below $378771s1% heath, Bursting Shot's cooldown is immediately reset. This can only occur once every $385646d.][]
    bursting_shot = {
        id = 186387,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",

        spend = function () return 10 * ( legendary.eagletalons_true_focus.enabled and buff.trueshot.up and 0.75 or 1 ) end,
        spendType = "focus",

        talent = "bursting_shot",
        startsCombat = true,

        handler = function ()
            if buff.rangers_finesse.stack == 3 then
                removeBuff( "rangers_finesse" )
                reduceCooldown( "aspect_of_the_turtle", 20 )
            end
            applyBuff( "bursting_shot" )
        end,
    },

    -- Throw a deadly chakram at your current target that will rapidly deal $375893s1 Physical damage $x times, bouncing to other targets if they are nearby. Enemies struck by Death Chakram take $375893s2% more damage from you and your pet for $375893d.; Each time the chakram deals damage, its damage is increased by $s3% and you generate $s4 Focus.
    chakram = {
        id = 375891,
        cast = 0.0,
        cooldown = 45.0,
        gcd = "spell",

        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "chakram" )
        end,
    },

    -- Talent: A two-headed shot that hits your primary target for $344120sw1 Nature damage and another nearby target for ${$344121sw1*($s1/100)} Frost damage.$?s260393[    Chimaera Shot has a $260393h% chance to reduce the cooldown of Rapid Fire by ${$260393m1/10}.1 sec.][]
    --[[chimaera_shot = {
        id = 342049,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = function () return 40 * ( buff.precise_shots.up and 0.3 or 1 ) * ( buff.trueshot.up and legendary.eagletalons_true_focus.enabled and 0.75 or 1 ) end,
        spendType = "focus",

        talent = "chimaera_shot",
        startsCombat = true,

        handler = function ()
            if buff.precise_shots.up then PreciseShotsConsumer() end

            -- Legacy / PvP stuff
            if set_bonus.tier29_4pc > 0 then
                removeBuff( "focusing_aim" )
            end

        end,
    },--]]

    -- Stings the target, dealing $s1 Nature damage and initiating a series of venoms. Each lasts $356723d and applies the next effect after the previous one ends.; $@spellicon356723 $@spellname356723:; $356723s1% reduced movement speed.; $@spellicon356727 $@spellname356727:; Silenced.; $@spellicon356730 $@spellname356730:; $356730s1% reduced damage and healing.
    chimaeral_sting = {
        id = 356719,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        pvptalent = "chimaeral_sting",
        startsCombat = false,
        texture = 132211,

        toggle = "cooldowns",

        handler = function ()
            applyDebuff( "target", "scorpid_venom" )
        end,

        auras = {
            scorpid_venom = {
                id = 356723,
                duration = 3,
                max_stack = 1
            },
            spider_venom = {
                id = 356727,
                duration = 3,
                max_stack = 1
            },
            viper_venom = {
                id = 356730,
                duration = 3,
                max_stack = 1
            }
        }
    },

    -- Talent: Dazes the target, slowing movement speed by $s1% for $d.    $?s193455[Cobra Shot][Steady Shot] will increase the duration of Concussive Shot on the target by ${$56641m3/10}.1 sec.
    concussive_shot = {
        id = 5116,
        cast = 0,
        cooldown = 5,
        gcd = "spell",
        school = "physical",

        talent = "concussive_shot",
        startsCombat = true,

        handler = function ()
            applyBuff( "concussive_shot" )
        end,
    },

    -- Changes your viewpoint to the targeted location for $d. Only usable outdoors.
    eagle_eye = {
        id = 6197,
        cast = 60,
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",

        startsCombat = false,

        start = function ()
            applyBuff( "eagle_eye" )
        end,
    },

    -- Talent: Fires an explosive shot at your target. After $t1 sec, the shot will explode, dealing $212680s1 Fire damage to all enemies within $212680A1 yards. Deals reduced damage beyond $s2 targets.
    explosive_shot = {
        id = 212431,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "fire",

        spend = 20,
        spendType = "focus",

        talent = "explosive_shot",
        startsCombat = true,

        handler = function ()
            -- It does technically trigger the explosion, but we just need to model the debuff presence
            applyDebuff( "target", "explosive_shot", debuff.explosive_shot.remains + spec.auras.explosive_shot.duration )
            if talent.precision_detonation.enabled then addStack( "streamline" ) end
        end,
    },

    interlope = {
        id = 248518,
        cast = 0,
        cooldown = 45,
        gcd = "off",

        pvptalent = "interlope",
        startsCombat = false,
        texture = 132180,

        handler = function ()
        end,
    },

    -- Your Spotting Eagle descends from the skies, stunning your target for 5 sec. Targets stunned by Intimidation deal 10% less damage to you for 8 sec after the effect ends. This ability does not require line of sight.
    intimidation = {
        id = 474421,
        cast = 0,
        cooldown = function() return 60 - ( 10* talent.territorial_instincts.rank ) end,
        gcd = "spell",

        talent = "intimidation",
        startsCombat = true,
        texture = 1392564,


        handler = function ()
            applyDebuff( "target", "intimidation" )
        end,
    },

    -- Talent: You attempt to finish off a wounded target, dealing $s1 Physical damage. Only usable on enemies with less than $s2% health.$?s343248[    Kill Shot deals $343248s1% increased critical damage.][]
    kill_shot = {
        id = 53351,
        cast = 0,
        cooldown = function() return 10 - ( 2 * talent.deadeye.rank ) end,
        charges = function() if talent.deadeye.enabled then return 2 end end,
        recharge = function() if talent.deadeye.enabled then return 10 end end,
        gcd = "spell",
        school = "physical",

        spend = function () return buff.flayers_mark.up and 0 or 10 end,
        spendType = "focus",

        cycle = "spotters_mark",
        talent = "kill_shot",
        notalent = "black_arrow",
        startsCombat = true,

        usable = function () return buff.deathblow.up or target.health_pct < 20 or buff.flayers_mark.up, "requires flayers_mark or target health below 20 percent" end,
        handler = function ()

            removeBuff( "deathblow" )
            if buff.razor_fragments.up then
                removeBuff( "razor_fragments" )
                applyDebuff( "target", "razor_fragments_bleed" )
            end

            if talent.headshot.enabled and buff.precise_shots.up then PreciseShotsConsumer() end

            --- Legacy / PvP Stuff
            if covenant.venthyr then
                if buff.flayers_mark.up and legendary.pouch_of_razor_fragments.enabled then
                    applyDebuff( "target", "pouch_of_razor_fragments" )
                    removeBuff( "flayers_mark" )
                end
            end
            if set_bonus.tier30_4pc > 0 then
                reduceCooldown( "aimed_shot", 1.5 )
                reduceCooldown( "rapid_fire", 1.5 )
            end
        end,

        bind = "black_arrow"
    },

    lunar_storm = {
        cast = 0,
        cooldown = 30,
        gcd = "off",
        hidden = true,
        readyTime = function() return debuff.lunar_storm_cooldown.remains end,
    },

        -- Your pet removes all root and movement impairing effects from itself and a friendly target, and grants immunity to all such effects for 4 sec.
        masters_call = {
            id = 272682,
            cast = 0,
            cooldown = function() return pvptalent.kindred_beasts.enabled and 22.5 or 45 end,
            gcd = "spell",

            startsCombat = false,
            texture = off,
            talent = "cunning",

            handler = function ()
                applyBuff( "masters_call" )
            end,

            copy = 53271, -- Pet's version.

            auras = {
                masters_call = {
                    id = 62305,
                    duration = 4,
                    max_stack = 1
                }
            }
        },

    -- Talent: Fires several missiles, hitting your current target and all enemies within $A1 yards for $s1 Physical damage. Deals reduced damage beyond $2643s1 targets.$?s260393[    Multi-Shot has a $260393h% chance to reduce the cooldown of Rapid Fire by ${$260393m1/10}.1 sec.][]
    multishot = {
        id = 257620,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function () return 30 * ( buff.precise_shots.up and 0.6 or 1 ) * ( buff.trueshot.up and legendary.eagletalons_true_focus.enabled and 0.75 or 1 ) end,
        spendType = "focus",

        cycle = "spotters_mark",
        startsCombat = true,

        handler = function ()

            if buff.precise_shots.up then PreciseShotsConsumer() end
            if talent.trick_shots.enabled and active_enemies > 2 then applyBuff( "trick_shots" ) end
            if talent.bullet_hell.enabled then reduceCooldown( "rapid_fire", 0.3 * active_enemies ) end

            -- Legacy / PvP stuff
            if set_bonus.tier29_4pc > 0 then
                removeBuff( "focusing_aim" )
            end

        end,
    },

    -- Talent: Shoot a stream of $s1 shots at your target over $d, dealing a total of ${$m1*$257045sw1} Physical damage.  Usable while moving.$?s260367[    Rapid Fire causes your next Aimed Shot to cast $342076s1% faster.][]    |cFFFFFFFFEach shot generates $263585s1 Focus.|r
    rapid_fire = {
        id = 257044,
        cast = function () return ( 2 * haste ) end,
        channeled = true,
        cooldown = function() return 20 * ( buff.trueshot.up and 0.4 or 1 ) end,
        gcd = "spell",
        school = "physical",

        max_targets = function() return ( trick_shots and min( 6, active_enemies ) ) or ( talent.aspect_of_the_hydra.enabled and min ( 2, active_enemies ) ) or 1 end,
        shots = function() return ( 7 + 3 * talent.ammo_conservation.rank ) * ( buff.double_tap.up and 1.8 or 1 ) end,

        talent = "rapid_fire",
        startsCombat = true,
        texture = 461115,

        toggle = function ()
            if buff.lunar_storm_ready.up then
                local dyn = state.settings.lunar_toggle
                if dyn == "none" then return "none" end
                if dyn == "default" then return nil end  -- let the base toggle apply
                return dyn
            end
            return "none"
        end,

        start = function ()
            if talent.bulletstorm.enabled and trick_shots then
                addStack( "bulletstorm", nil, action.rapid_fire.max_targets * action.rapid_fire.shots )
            end
            if talent.lunar_storm.enabled and buff.lunar_storm_ready.up then
                removeBuff( "lunar_storm_ready" )
                applyDebuff( "player", "lunar_storm_cooldown" )
                applyDebuff( "target", "lunar_storm" )
            end
            if talent.streamline.enabled then addStack( "streamline" ) end
            if talent.no_scope.enabled then addStack( "precise_shots" ) end
            -- Legacy / PvP stuff
            if conduit.brutal_projectiles.enabled then removeBuff( "brutal_projectiles" ) end
            if set_bonus.tier31_2pc > 0 then applyBuff( "volley", 2 * haste ) end
            removeBuff( "double_tap" )
        end,

        finish = function ()
            if buff.volley.down then
                if buff.trick_shots.up then
                    removeBuff( "trick_shots" )
                end
            end
            if talent.in_the_rhythm.up then applyBuff( "in_the_rhythm" ) end
        end,
    },

    sniper_shot = {
        id = 203155,
        cast = 3,
        cooldown = 10,
        gcd = "spell",

        spend = 40,
        spendType = "focus",

        pvptalent = "sniper_shot",
        startsCombat = false,
        texture = 1412205,

        handler = function ()
        end,
    },

    -- A steady shot that causes $s1 Physical damage.    Usable while moving.$?s321018[    |cFFFFFFFFGenerates $s2 Focus.|r][]
    steady_shot = {
        id = 56641,
        cast = 1.7,
        cooldown = 0,
        gcd = "spell",

        spend = -20,
        spendType = "focus",

        startsCombat = true,
        texture = 132213,

        handler = function ()
            if debuff.concussive_shot.up then debuff.concussive_shot.expires = debuff.concussive_shot.expires + 3 end
            reduceCooldown( "aimed_shot", 2 )
        end,
    },

    -- Talent: Reduces the cooldown of your Aimed Shot and Rapid Fire by ${100*(1-(100/(100+$m1)))}%, and causes Aimed Shot to cast $s4% faster for $d.    While Trueshot is active, you generate $s5% additional Focus$?s386878[ and you gain $386877s1% critical strike chance and $386877s2% increased critical damage dealt every $386876t1 sec, stacking up to $386877u times.][].$?s260404[    Every $260404s2 Focus spent reduces the cooldown of Trueshot by ${$260404m1/1000}.1 sec.][]
    trueshot = {
        id = 288613,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",

        talent = "trueshot",
        startsCombat = false,

        toggle = "cooldowns",

        nobuff = function ()
            if settings.trueshot_vop_overlap then return end
            return "trueshot"
        end,

        handler = function ()
            tensileTrueshotExtension = 0
            focus.regen = focus.regen * 1.5
            reduceCooldown( "aimed_shot", cooldown.aimed_shot.remains * 0.6 )
            reduceCooldown( "rapid_fire", cooldown.rapid_fire.remains * 0.6 )
            applyBuff( "trueshot" )

            if talent.withering_fire.enabled then
                applyBuff ( "withering_fire" )
                applyBuff( "deathblow" )
            end
            if talent.feathered_frenzy.enabled then applyDebuff( "target", "spotters_mark" ) end

        end,

        meta = {
            duration_guess = function( t )
                return ( t.duration - ( 15 * talent.sentinel_watch.rank) - ( 15 * talent.calling_the_shots.rank ) )
            end,
        }
    },

    -- Talent: Rain a volley of arrows down over $d, dealing up to ${$260247s1*12} Physical damage to any enemy in the area, and gain the effects of Trick Shots for as long as Volley is active.
    volley = {

        id = 260243,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "physical",

        talent = "volley",
        startsCombat = true,

        handler = function ()
            applyBuff( "volley" )
            applyBuff( "trick_shots", 6 )
            if talent.double_tap.enabled then applyBuff( "double_tap" ) end

            -- There are weird situations where it doesn't do the below .. but this is usually what happens
            if talent.salvo.enabled then
                if active_enemies < 3 then
                    spec.abilities.explosive_shot.handler()
                    if active_enemies > 1 then active_dot.explosive_shot = min( true_active_enemies, active_dot.explosive_shot + 1 ) end
                else
                   active_dot.explosive_shot = min( true_active_enemies, active_dot.explosive_shot + 2 )
                end
            end

            if pvptalent.rangers_finesse.enabled then
                if buff.rangers_finesse.stack == 3 then
                    removeBuff( "rangers_finesse" )
                    reduceCooldown( "aspect_of_the_turtle", 20 )
                end
            end
        end,

        tick = function()
            if talent.bullet_hell.enabled then reduceCooldown( "rapid_fire", 0.3 * active_enemies ) end
        end,
    },


    wild_kingdom = {
        id = 356707,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        pvptalent = "wild_kingdom",
        startsCombat = false,
        texture = 236159,

        toggle = "cooldowns",

        handler = function ()
        end,
    },
} )

spec:RegisterRanges( "aimed_shot", "scatter_shot", "wing_clip", "arcane_shot" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = false,
    nameplateRange = 40,
    rangeFilter = false,

    damage = true,
    damageExpiration = 6,

    potion = "tempered_potion",

    package = "Marksmanship",
} )


local beastMastery = class.specs[ 253 ]

spec:RegisterSetting( "pet_healing", 0, {
    name = strformat( "%s Below Health %%", Hekili:GetSpellLinkWithTexture( beastMastery.abilities.mend_pet.id ) ),
    desc = strformat( "If set above zero, %s may be recommended when your pet falls below this health percentage.\n\n"
        .. "Setting to |cFFFFD1000|r disables this feature.",
        Hekili:GetSpellLinkWithTexture( beastMastery.abilities.mend_pet.id )
    ),
    icon = 132179,
    iconCoords = { 0.1, 0.9, 0.1, 0.9 },
    type = "range",
    min = 0,
    max = 100,
    step = 1,
    width = "1.5"
} )

spec:RegisterSetting( "mark_any", false, {
    name = strformat( "%s Any Target", Hekili:GetSpellLinkWithTexture( beastMastery.abilities.hunters_mark.id ) ),
    desc = strformat( "If checked, %s may be recommended for any target rather than only bosses.", Hekili:GetSpellLinkWithTexture( beastMastery.abilities.hunters_mark.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "trueshot_rapid_fire", true, {
    name = strformat( "|T135130:0|t %s Icon in %s", Hekili:GetSpellLinkWithTexture( spec.abilities.rapid_fire.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.trueshot.id ) ),
    desc = strformat( "If checked, when %s is recommended during %s, a %s indicator will also be shown.\n\n"
        .. "This icon means that you should attempt to queue %s during the cast, in case %s's cooldown is reset by %s.\n\n"
        .. "Otherwise, follow the next recommendation.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.aimed_shot.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.trueshot.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.rapid_fire.id ),
        spec.abilities.rapid_fire.name,
        spec.abilities.rapid_fire.name,
        -- Hekili:GetSpellLinkWithTexture( spec.talents.improved_deathblow[ 2 ] ), -- no longer resets Rapid Fire?
        Hekili:GetSpellLinkWithTexture( spec.talents.surging_shots[ 2 ] ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "lunar_toggle", "none", {
    name = strformat( "|T461115:0|t %s: Special Toggle", Hekili:GetSpellLinkWithTexture( spec.talents.lunar_storm[2] ) ),
    desc = strformat(
        "When %s is talented and is not on cooldown, %s will only be recommended if the selected toggle is active.\n\n" ..
        "This setting will be ignored if you have set %s's toggle in |cFFFFD100Abilities and Items|r.\n\n" ..
        "Select |cFFFFD100Do Not Override|r to disable this feature.",
        Hekili:GetSpellLinkWithTexture( spec.talents.lunar_storm[2] ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.rapid_fire.id ),
        spec.abilities.rapid_fire.name
    ),
    type = "select",
    width = 2,
    values = function ()
        local toggles = {
            none       = "Do Not Override",
            default    = "Default |cffffd100(" .. ( spec.abilities.rapid_fire.toggle or "none" ) .. ")|r",
            cooldowns  = "Cooldowns",
            essences   = "Minor CDs",
            defensives = "Defensives",
            interrupts = "Interrupts",
            potions    = "Potions",
            custom1    = spec.custom1Name or "Custom 1",
            custom2    = spec.custom2Name or "Custom 2",
        }
        return toggles
    end
} )

spec:RegisterSetting( "prevent_hardcasts", false, {
    name = "Prevent Hardcasts While Moving",
    desc = strformat( "If checked, the addon will not recommend %s when moving and hardcasting.", Hekili:GetSpellLinkWithTexture( spec.abilities.aimed_shot.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterPack( "Marksmanship", 20250508, [[Hekili:T3tBZTTnt(BjtNQyn2wwIooVD2EMK0RxBV0EzEuZ1pCZjkyjklEMIuLKYoUJh9B)2DbijaiaFrwkXoJNPn2MayXIDxS7Iflagny0FoA4uwQ3O)WPVZj9pP)R7n4K(V5KbJgME7sVrdxYMCf7s4xczlG)93zXxLSGfMm3Fjw4TbrSPiqsIwfpbQWpSE8800LjV9OJU0pD(Ql6njAXrj(lwfWs9JcNeZMLI)9KJgn8Iv(bP)A4OlmHeVcrc2Q05rXJgo0FXhgnCU)0PE8Q7Lmz0qS6h2h(Vx(21JxL4TE8uVlwnB26XZIIxpoyvid(rsAu8I1)gVYhF4X9HkJWB94pVe72IICgyTOb2BvFhOOFYlWd(44HSGRJYkZ5qNxdL9N)1Fbf4XsIcxp2bWufa4C4Gxbv6tXEb(l8bm(21JhmO3G1JF3N(ivPxa9(HoVjhbKApVOJFl1K(9or8X(Vb((bRhJ)8eZTR)RHIGQ44yVCICK6XMcO0phnzvY6XrHbWF4dK4uwGxyQ30I63hrro1bQ5S4OfcixudeIFgzu)YkOTXphQhksbmjV0u)WlZQ6Ro0bjk)UFiYibXLmS7FtWO1AFrZqAXFohQXFH8()cKb9dhnmWpjnbLttJ9NCvY8i6V(ds(3lKDrG30rVF0WjX(au9zJg(SSbyVPrRGIDtzl7LvZHSjOS8OHxhfe4D7OuqY1kKUMb)a(CV04vEyp7gJu0cGK9DemhRbguop2FjVIdVHTerR4l9sHbEAeqzw6foLeEM4JKLH4ilJ2)hqfgojAj8DysNhqoylxgClsMhpCzuQcdGfeZz0iytrc4Yy)fK0iVh7bdQBNauI)KJaJgoOymatVt9PbH0ihNk2Bjh1CjAEVvWaOZ6X7LntTxchpsCHU6kGwFdmf5U7wpMkCr01aY6k6FEHDLkNyMciJLIuWxOrb1yvQu0FgLU(jIbdsnSLW8HGOBqk1)nvDqspKierWGc(lqOZpaQPGJb66yjYKUy)lV0lgMtid0EY0eRcveDHgvsLLnOoXYG6Iaq9Slloo6gTr27cUHDlGBtyjaA(ESEGcfSIRhFdmPahe(43esmiJHuA((apg85pfDZuV4ELyNYK8vlrC7LwWnM)cVPUCzcfu7tCYP))aKN3HvIJeaDeia(ir1)Y5ipiDodO()l2sFOk)SFShxXJFkk1ojicf4rP1jZrbeCSUCjjCZW5eVFfWbt5k)h7tdrLHZEcYTQaAHeOrbuH8RbPtSKUffQsNk((ffyv23NbFc0jWhfUPafz94txp(Yjt7TG9fKe)klK4yK04odOmAK4)I4WqtaDQEbGu98OGPAKsIBJOaschC0XGUDI4I02iO6eHGugWLQxp(JC7Pd5KuuYpjcnPH)2YOKeFulxnsmzt)b9RapoYnn2ZRxIarvi8K1BxIs5MHq9I9wW8dH(7COBjQGBbYE06XhxpieQrq66RTqx9(Ysq6Y)AptIVCAlxJRpo8)jV0OqY5gGqFddLGf6jyivoiaNZHJCfH9BIwHSKq63HjPEL1ItY2qr9aoN3FVI4AFmcN0sc4FeC9ItfUwmZyvcj(tAVFXYjMu8SmdVDNMJ2kQGYMweeHAwcN6IE4rmoKW(mYsT7frHRs6b9ZnS4BitSUjK)nUoUqhNntyxmfd5BVPTQCuO8iL6gVNJen08zQzcFUuFzlLiX)3jmd1VtOg3tdftUavbAYcpgkUQ3dt4C)l84sg3m3lut(WxO8(BMolKqpOpsPTnTOGdGv1UVuZ4UoUpFabQ6UehTNItoGciLC59rc5UPBM)qdCKrajVmK7BIBpJbfM7txwla6m6NOjewbYPXSqygwG))GKhd1w3XSiy5pWmbj)leU5H)wWkpSRfkCY8VRNWlb(edUoWygOa37ACMjB60KEEFbDuLZm1lJglRhFgOTwAcwHJQOPLeVB9kMoJqzgymfP5f6nlJytxftkcCVe(aNtjei0QaPJ1rYdS8(mjL8W4m9VdmxxrzkOCSF4vGey6GEGluUGl9U8fUHqwQqJk(pUFv1JOXg7lNQ6lNg2xoM6ltSRmwzhB86cJH6LuqU3VCH(85ooNyUBXIb8(L9TIyI(v)ZYJ6bfT(IOe(GqtqsGcD100cgd9IHLXM7Rgxtgyj8YOiqKK7EdQGLwgxMN0Ojog6BcHqGRia4w4)pcQqk7kCfLf(HNqTNHo9HqpHDnkUtE0q6iwIUENVqj0)KGiYXWeokDtu4Ztr1LbmaArxJ65NZcY8)jJ(dy1)fyKdmXH4kJBjN6LKfWFjaGWGranOrIlx6YB2mVjP5sojhiSCW11lmv)EX8KdYrgY4Da51UyeIULrFL4azdt2xWiBatSs6rkFC5bOrBrMgwquHE5LG88Cpwq6C3LiMcSu4tU4NaKtsTlSgtxOKQwjYeGE4k8idxSnFj3cKAY0KQwPqLTnJ8zYpyfdJIiiG2tIrpxUvmXLBQZpXLljZ1mW9AYDki5nNSqWTvskW6t1q0ouE1nncjqUVUpn5WPFbQl3ytEuwGHIE0l0BHVhF(ZX5(uj0GlBaopwdj4xrtHnKGLKAYfj7icoIAFVifhfYam6rs0IlyPvhwfXaDv4fG85vyfqFjNwoYkjRwSa6xHuNE0vQ36Bz9(fRtqZ2HQrHMz2q1eMpi05dRTo2nAM7SyaPwfdoIMgTicxXDUrajqwFtSz1PW4WPMnbwubDqGEFLV(s5MwuG9MCMTM0Po88S6WZU5wBQY1G65mLOYFVt0SB8LmyatQbZEuOu4GIBPk52WjzrbkdWjGTUFneTcLmbu3tgNYS3(wvtACDgtzliRtIVDa3el2xqHGIHykGJ5G3w5KHoKKGiayrAIplG(SWlHjrHj(tXQ(700fU5WFoBcd4brXmMBavkfXnkkLcIKgMdMDN4jmZVKhQpYdILbOFbx4LEJhAEMiFtxCzHzCY2n9zziQz7LiYUdCZi8B2kharCPGgxcMg6rhLE0Uf)hkMj19IWU1j(QDqm0qjoekuy)KhJ3YgtKIlqMBiMwVP(IkZD9WGjT65IwJ7VYuw0byURY5IOG4lkVHr7bQQFmce5jUmPPZCzr(uzQfuFOivInQWBW2BjvDLGRww9a4(I)CUC5ba)7B28jtReNwfdF9U6dis)SicE0e(7nN5gFCXcxuf7HWNQ2)cbGb)ZscIsL)B0(x0SzUxozk5)MK3wvBknxcTqePurL1)0G1nxymFt7cZiyXcuR20ipqWLxZATnCFuTvPbyjAxLd(ZTI3hc6YoPEaav7eYzdlGPJ1sa0)fNqyG2axWqkrYDkrYReZAqv2CK)8Zms8T1fy1T3h3BHhBXxsXrsnQCL97(1bpJCTcpJntsYMpzFW60VQkCQzaRtn62oF0n7Yl3NbJkg4A3Byy7AG6JALHktuBIcsvQATDIOEDBAS02kdmnRzFob9vYCePkTgaHxU(jCtw8ntkkp0uI4rLTNH8aMrwiZT6vSi7SO)jc1gF3AzfHTlZjBIu0d3uYGGe(3raWfzeMpf(1R5kVpV3VnVpybyCbrZSYbemGPUseGipNTCPxysjK0q8aTn8icfZ4sSealBVDOrkmAazaeD0w3KHHHF4mVy4)Yh)Kt6QSqIkslzlfwTgowtZg6G3bhYUmmkj1FcpsPc3wqOeftRLkpKIjSfYJVLm)yA1z0Utf7LSkivIxXRnVVRkyGc45O5RItJ8vPztfRYrchBtymTFcBMVkLnC2aZnvOGTAFvm2qt(QyqDCLd(w5RIjaS5M7BTVkLDpSsmRbvzZrEJ(QyVl2g(QuHWtJIu4M6RIr41uFvkVXCBjFvQWZnR(QuF0cV)(QuZcTUpAOAAFuVVkw0eSn8vPDdmEywsmUNb5RM3uE79lrO9PSC0tjtMOi7DZ8iCL5fMRnU1Gy0atxrcp0UZrUpSa81akyfA(vjFPkwep7AMFaIO8EuS92EFjnMjs7mrwNX3FoA)ejFPixnat6rRGF5Djljt552I)LBNgZ610Kqnx(LxbgbnCZeay5oNaLsEaypWAuaEmLrj8oOGVLNTz9K1uWzuYL69fVjRsLsLTxwmzSivfYYcUCSSR6CQ2KAeIn9wSzvfSDtd8Z55pHPGHLjZznV6KtDrfHJkYtouYZIysw2jY3s4mXz1eZKN5ITtUXuM11PjzfNkxQszQovZm7yJW3XEcsUxnz3ubMfg5MGzzLKWJPqdozZscBBHGRY0cuw0GsbUPImaMYvo4h3Y3TdsrW)EgKYt91WPz5kivHmoUEsdsckLYbqUmYbR1Y0b9KotoLdr9yuAhoDJYsWgLeGnGLE)syn9CuS6Tw4r(yRQDZOP2nFSKV76j6HYG4)KmeJY0hPMx7xGPGG3ATtVGYSaEkFcRbor4tWVaJe(qdpmstXDHKisu69yPPavl5kFH)gLsT0lIOCVUbznA2wEKro5jOU1ZyHsY(xIcpxmqktF3rNaJcTX276y2)efJP3WLlGkMLvPLssgRd5RawTqz7J5bSEY4yiFY985Bx9WBxSCEuig6M3fdwVXDdhLhhYt4S)dkcm8d)eig(7OhThYL9MGB6nf0PeeJWjQ0ebDRacPy8OCr7GAEAY1apmEyC(FQY3IM79sHVZjz0CyYfrYv9CoRwihW9sGb4Y3oBnNp45kDJeRzXaZYRKG9UHEnYuYz)a6a5yNkjLn)t29PaVLJHtDlVjlR2ZtRN9QDHo58l9dduxz3QbhbNgVkm0l29Vxbc75YBJYZl(2S0LVHhji07akY2XEjOvpvbHCbOlOmVHwMesL4rHhZe5vHbuAP7lRLl27Wsvv)SsS7oKrDVpSAXkbp9m(WtshtD6SQyTSdQ8OJ(i)aW0sDeBxfee11Eov9SgUIbvxiQAviwxXjIi2xFJD)tm7djcn9vpOEEJfh97c(r0Q4SJaEkL3pZah0qzKPReQ(j)fu4JtMIhJ0meq989GCTP1CsSjEIu(hvB4jHzcfJxGd7fFfMo7gI3tDDsUgb9ehIM5LD0qQcvEPmPpkc0mVk(2QdvXxbuHfoXljnMf4I54D1Pm4ocDEtb2GgRiIt1lFxfrOvkMdIae(jU)FRMs(DBADXvnIKwmpHibRskgQc9a8dkrVSdkHtJoHmhlPQc03G)ui2dwSWz)IR8IJpU)OHGIJqmZmhnKU)c8xSmkovyu(5P55B)ZrBF0PbDkATf96GTknAbdVlgqxVcVetM2F7JuEaJ3IcFike6oQyqXmF3ss4l1)5cIHCS46S3ZkB18U7AGfZZ1Sw(JhxDZW)P7Z5ko2TyYrnctaQ26FZaXxC6cBhL)yvk)ZZ2ke1TVjB0Bz3DGI3BWx62aGQtbmaydvzhc82bwWOq1aLxH2JVncW1csNQzALkUr4z583XaG3uM2Mb82bwt0wdvO94BJaSnqwshNjJvaa6S3EpZ8MmD3Dgp7TNnOlOrYYPT9U7uu)FE5ov9u2UVM9mrH)OZD3LVGHItw7zQFl)u1siKzvh3DxfZop)4(2khOmkq1Xgull(OcvDgw3YKvo5Utz(aQ732PID)Y7(3PoNug4(HN)Y(g6ua2wo7RNpaRpApVJcZeaFUzQhtcth9KW0duHjBEAKFmkBNVgovA2kJYzXSLuXkAQTb07LdmvJPBObw7yADhZsdyFdAsJ686pJNggLnOjnSZlCTviPxLbvP6StbFTa2qEDvL3BTfV3uWxlGLsEmtecPYAkEAfCdAp4EWJD1YuEswTXGVba(XI(7nL1TJbFTaEtzDneV3uWxlGFWRN4Hn2vlt5jz1gdEBoiN0spJh4utWb2AHy8hpwBbDABgO0sXu2iWtpBaUqNA3aWoQB(35dYxs6wBiC0x)HGn(Sq4OLr7(f7ctE2aA5LSw1mslHVB7c8Ab7MoDSHy9Mc(DgG)wJ33l3I2UYg7uGVJa7t48t48dtCEt1y0qSEtb)odWpH3BgERiB1OT1QHyC7bCBazRwJr7X4wb(Ab8oX7UnC5Hp5iqTG9jcX9aSFtW5slA2YCRo7z4ouq6JIMjDu(RCha7E3DpRTaSmkqG6C55U6Ay(XJv3HUkR8(oQBlPY4VIbZ5gXRdhCsvn6Wto1yZ6y8R7)ItoxzGaeWkoH2D2RIEUYcBhAD(zow3jxb4o)mZWBJyMM3l6SYpvHczPh2VkiOrJ72TITP2cfXPV5co1eGkgzuFzBl6L4ys2NoRFPjr8GWuX2YFVMXwpm1OevNeao97ABx0VhOzn(i8ivp2rpPh77h9yh9DRESJEsp2wtpwUhBNSlC32gqhuctQAXYfvzhc8AbRbbXgT6ZgI1Bk43za(BnEFVwu(2v2yNc8DeyFcNFcNFyIZBQgJgI1Bk43za(j8EZWBfzRgDkCAig3Ea3gqALiyUoTfJBf4RfW7eV7C2S8S6jhbQfSpriUhG9BcoBpY31TSqZb4XX0c7kJpnpIronpIrg0IBpY3gQSAeJgyjIrLhmniIrLBu7cntJIy0atrmQCpxzHTdT0IyKjWTPrmYiZ0CWc2WigzacvfXiDJUBCeJmyiSuKV1N8jJ0TlIrwd8B7NXwpmThXidZAAxeJAkAwJpcps1JzpY3pPhBlGwFD1JD03T6Xkf57N0JTPOj6X26F7xPCghDu7Lzxvx4dXBskMs4JgIzI(O)W5KxGVpPrZ8X3eSF4hwpEEA6YK3E0rx6NoF1faWxCuI)IvbetAsmBwk(3tockyHFAYrY3Qth9oQBe3zE3(rSZoIFHasxLujlyHjZ9x2dHW6Fd7UplUr1MYWx5F(167q)fF4T0fQ1e4VCEn8)9X7v9dxp(nx8QjZEXRWXhFiL0l)ybV)zhv8YOEG)SZS8GQcD86Xp9Cq(v)5G0mlltk)a8jF7SY6XpGEO6olF2S65YUyIG(esTgKvGKgM6poZfkDQ)0hxGjMulx0NLktPHzk2KBq23mwXZmuXovGjNvbMOO)TH0tzs0J2HDBKmDkjzwHtiMbS8l(jQNAVsV7OWyw5nhTB2Pds)1g9S(Dm(kJcwwm33fxkGypREMJoBWD3P9fNopt59d1IA3IlUojnZqb0T5bO8NxsX3tJzH)9k)a))bVnb5LQQu(Phi)Vspq(YSfDjE5NdaH0E(SNDXv8Yw6QD5ECpbz7MDXGVBYxbl6og3Tc7pg0szcKo6G8r9L6ISu2cWPPmx0GFiU9arfxNc)Pl(NO4TSAeTxBFU85KPj1xPSjqY18RS(xR4g8tWqH)eyYqzLXNEmAmMp)iT4M)REOMMFBiwb0p3bvuJoG)bsxePw4tCN8(1WzRsivNCTnfVWbIlMAEdZmeaSbax8dVo6ka8FbinHSaswNJpKRJU(cGIOI6S2CPhhTP)No44cZn8EP4klTmCwT0OWNbGKFzJAgiMuXvm)0ux8s9Uq9seDN1n53oOBPE4n6DG2DhA5UbbVEJ4xMNMqPo7XvblDpIMptR4oe9uhl6roEaj0UE83XpXvfeZeYhuAmI0YNv61cbC926PkVKJCdeMelFZp3zVcdnLEfR2NJn2UI3p9LfkPKo57D7AWOKn3badnfRMttl1GUCDn)pdVn2F2)lfcGpZD(PIxQjunfS8uAvZCHJKSv6k3kYSAp6TbcOkt9Pr6HK7AOq2d43ZknHKcMdkOu((oOtD3URfmrdIsDkZFlDxf0rmtx9cQ1IaxrVL9uv1vBaLPYahosRUs2D0sSOhxVRuAdy17YCPyxz6QqVtdUs1RG4B5oENZc1VF37Y)S(dUKg6RUOYh6O(piEgJ25V1tw1LxwvoHQAp2teM(98d6Kg9r6(3)aLx1aUdSA3F)DmiLGkDS(wWimaw(DGPBHcjvGx(blsdJZFcME4IV)q2JpXJGhrjnQB(7MKjQ72JAw2ywvgd3Z27I0D3z7Tqs36M0lC0UDKvYg5x5hWi7wjmmS3AA9l)wfDA1oXUFreKnDbpz4IDc7gBVerst5(o)bfQsVq387DRSpy7odBtVOTkFbBrSQhZV(pTAc22z(vToU(Sg4IxHbmtojwHBbsRdoZ0hXe3EVgpADU5D2Oxrm2Qzn6wAstxGZWBylLmGslTeTUwwQzwC0cfzm2mA9VGs6GBjXXYcR5UVgP7gPGDBb7)kzywuI8QkZDl(RTd8wy4TWr(3fCdTBp8TXx1xE(QovJfao3Nmr8(ap2vuWzbNQSHsAtskr4eUc(GWzafexDPJBnNamqa6yWmUjNfUCY0VjbDQhkJKeDa(cUtK9zezVWxaGX4LB1G8t4ck3p(WpDGiadF4Nqt1Kz0V5UHyMDR6KGjU02WXHg8EgjrF(uMniAdOfgHoadvdoJqO5GLfQioXsncrsX4HIVJz3g4MSh)V4xzNgcPe3bf(mnXw8sQLblM2ONTlWr8Px6rebSg3aB2D3AXL57i3U(gPkRrcdwQKKhniAolAYQe(kGI9U0l8u6d4MJxNXFXEX8NK3v(YjogO1llCpt9s8JL2RekD6yRlsYoC0LzaKAbxbPsNtBG7(6PNqrktlsnHQCKsdlVVijFMAJXsE1fOPGFMVPyC8JYSfHUgAs)9MAwSHvTLKsQtRiFpOY5zGbH8FobtWgEFRN4kLsEsXSv)eogY1YfLNblI0wjZGepVAics(GSWSuwscjYihUBjSIS7jl7ePTred2j0Hj8VJaGNorcQLiHiLhfj8EaaXT59bFxcrQQCEdfWutHZ1J3Bo4rKxysjK0qAdzB4rekMXCtvaSmTv0ifgnD5XYtlHtnmm8dN5fpZloF8ZcVvNfsurkxxtXa6nLZrOHEqu6HSldJssX4iMeLlLIqjkMh9VSrwcfsXCuFjZpMsRvsFBSxcOqrIxXRTOVnjYIzsJFQ3IdWFjA2mxWHnyPhioLLTh84VAmLEA6H4W0Tms5m2P5NHJMF7fz8m(y5iCyOUkNGdlxDrgs9OAp)gLBt7oNen64By6IlQChxvzTdPup8gMG2gE2nmYenMVyB2j3WaaQ4GBONlzB652W4bRRBLPnSec3QdTXgDBfzCcATq06j2WW0K2DGnAioUPQ5CKvZv3WRUJwwv56yZvZ18JQMrzjlQ5Q7GQz5CQTjhtT77XbRrQ5mDk1Q6qQDFrkv1CBXJOMrMy1NeIwPMRDNpTT1XtZOYBv1CvCiiALAUn6OPv5jtRo3DkRMBNCU0mGJ0J79O))p]] )
