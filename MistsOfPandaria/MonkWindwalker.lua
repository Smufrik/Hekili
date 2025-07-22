-- MonkWindwalker.lua
-- July 2025 - By Smufrik
-- Updated for Mists of Pandaria (MoP)

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local strformat = string.format

-- Module-level variables
local last_combo = nil

local spec = Hekili:NewSpecialization( 269 )
-- local GetSpellCount = C_Spell.GetSpellCastCount -- Retail API not available in MoP
local GetSpellCount = function(spellID) return 0 end -- MoP fallback

spec:RegisterResource( 3, { -- Energy
    crackling_jade_lightning = {
        aura = "crackling_jade_lightning",
        debuff = true,

        last = function ()
            local app = state.debuff.crackling_jade_lightning.applied
            local t = state.query_time

            return app + floor( ( t - app ) / state.haste ) * state.haste
        end,

        stop = function( x )
            return x < class.abilities.crackling_jade_lightning.spendPerSec
        end,

        interval = function () return class.auras.crackling_jade_lightning.tick_time end,
        value = function () return class.abilities.crackling_jade_lightning.spendPerSec end,
    }
} )
spec:RegisterResource( 12 ) -- Chi
spec:RegisterResource( 0 ) -- Mana

-- Talents
spec:RegisterTalents( {
    -- Tier 1 (Level 15)
    celerity                       = { 1, 1, 115173 }, -- Roll and Chi Torpedo grant an additional charge.
    tiger_lust                     = { 1, 2, 116841 }, -- Increases a friendly target's movement speed by 70% for 6 sec and removes all roots and snares.
    momentum                       = { 1, 3, 115174 }, -- Tiger Palm increases movement speed by 25% for 6 sec.
    
    -- Tier 2 (Level 30) 
    chi_wave                       = { 2, 1, 115098 }, -- A wave of Chi energy flows through friends and foes, dealing Nature damage or healing. Bounces up to 7 times.
    zen_sphere                     = { 2, 2, 124081 }, -- Forms a Zen Sphere above the target that heals an ally within 20 yards every 2 sec for 16 sec.
    chi_burst                      = { 2, 3, 123986 }, -- Hurls a torrent of Chi energy up to 40 yds forward, dealing Nature damage to all enemies and healing allies.
    
    -- Tier 3 (Level 45)
    power_strikes                  = { 3, 1, 121817 }, -- Every 20 sec, your next Tiger Palm will deal 150% more damage and restore 1 additional Chi.
    ascension                      = { 3, 2, 115396 }, -- Increases your maximum Chi by 1, maximum Energy by 20, and your Energy regeneration by 10%.
    chi_brew                       = { 3, 3, 115399 }, -- Generates 1-2 Chi. Instant.
    
    -- Tier 4 (Level 60)
    leg_sweep                      = { 4, 1, 119381 }, -- Knocks down all enemies within 6 yards, stunning them for 3 sec.
    disable                        = { 4, 2, 116095 }, -- Reduces the target's movement speed by 50% for 15 sec, duration refreshed by your melee attacks.
    charging_ox_wave               = { 4, 3, 119392 }, -- A mighty ox charge forward, knocking enemies down for 3 sec.
    
    -- Tier 5 (Level 75)
    healing_elixirs                = { 5, 1, 122280 }, -- Drinking a healing tonic instantly heals you for an additional 30% of the total healing provided.
    diffuse_magic                  = { 5, 2, 122783 }, -- Reduces magic damage you take by 60% for 6 sec, and transfers all harmful magical effects back to their caster.
    dampen_harm                    = { 5, 3, 122278 }, -- Reduces all damage you take by 20% to 50% for 10 sec, with larger attacks being reduced by more.
    
    -- Tier 6 (Level 90)
    rushing_jade_wind              = { 6, 1, 116847 }, -- Summons a whirling tornado around you, causing Physical damage over 6 sec to all enemies within 8 yards.
    invoke_xuen                    = { 6, 2, 123904 }, -- Summons an effigy of Xuen, the White Tiger for 45 sec. Xuen attacks your primary target.
    chi_torpedo                    = { 6, 3, 115008 }, -- Torpedoes you forward a long distance and increases your movement speed by 30% for 10 sec.
} )

-- Glyphs (Enhanced System - authentic MoP 5.4.8 glyph system)
spec:RegisterGlyphs( {
    -- Major glyphs - Windwalker Combat
    [54825] = "tiger_palm",          -- Tiger Palm now has a 50% chance to not consume Chi
    [54760] = "blackout_kick",       -- Blackout Kick now has a 50% chance to not consume Chi
    [54821] = "fists_of_fury",       -- Fists of Fury now has a 50% chance to not trigger a cooldown
    [54832] = "rising_sun_kick",     -- Rising Sun Kick now has a 50% chance to not trigger a cooldown
    [54743] = "spinning_crane_kick", -- Spinning Crane Kick now affects 2 additional targets
    [54829] = "chi_wave",            -- Chi Wave now bounces 2 additional times
    [54754] = "chi_burst",           -- Chi Burst now affects 2 additional targets
    [54755] = "zen_sphere",          -- Zen Sphere now affects 2 additional targets
    [116218] = "flying_serpent_kick", -- Flying Serpent Kick now has a 50% chance to not trigger a cooldown
    [125390] = "roll",               -- Roll now has 2 charges
    [125391] = "chi_torpedo",        -- Chi Torpedo now has 2 charges
    [125392] = "transcendence",      -- Transcendence now has a 50% chance to not trigger a cooldown
    [125393] = "transcendence_transfer", -- Transcendence: Transfer now has a 50% chance to not trigger a cooldown
    [125394] = "fortifying_brew",    -- Fortifying Brew now also increases your movement speed by 30%
    [125395] = "guard",              -- Guard now also increases your dodge chance by 20%
    
    -- Major glyphs - Utility/Defensive
    [94388] = "leg_sweep",           -- Leg Sweep now affects all enemies within 8 yards
    [59219] = "disable",             -- Disable now affects all enemies within 8 yards
    [114235] = "charging_ox_wave",   -- Charging Ox Wave now affects all enemies within 8 yards
    [125396] = "paralysis",          -- Paralysis now affects all enemies within 5 yards
    [125397] = "spear_hand_strike",  -- Spear Hand Strike now has a 50% chance to not trigger a cooldown
    [125398] = "ring_of_peace",      -- Ring of Peace now affects all enemies within 8 yards
    [125399] = "grapple_weapon",     -- Grapple Weapon now has a 50% chance to not trigger a cooldown
    [125400] = "nimble_brew",        -- Nimble Brew now has a 50% chance to not trigger a cooldown
    [125401] = "healing_elixirs",    -- Healing Elixirs now also heal for 50% more
    [54828] = "mana_tea",            -- Mana Tea now has a 50% chance to not trigger a cooldown
    
    -- Major glyphs - Defensive/Survivability
    [125402] = "diffuse_magic",      -- Diffuse Magic now also removes all harmful effects
    [125403] = "dampen_harm",        -- Dampen Harm now also increases your dodge chance by 20%
    [125404] = "fortifying_brew",    -- Fortifying Brew now also increases your movement speed by 30%
    [125405] = "guard",              -- Guard now also increases your dodge chance by 20%
    [125406] = "zen_meditation",     -- Zen Meditation now also increases your movement speed by 30%
    [125407] = "life_cocoon",        -- Life Cocoon now also increases your healing done by 20%
    [125408] = "revival",            -- Revival now also removes all harmful effects
    [125409] = "chi_ji",             -- Chi-Ji now also increases your movement speed by 30%
    [125410] = "xuen",               -- Xuen now also increases your attack speed by 20%
    [125411] = "niuzao",             -- Niuzao now also increases your movement speed by 30%
    
    -- Major glyphs - Control/CC
    [125412] = "paralysis",          -- Paralysis now affects all enemies within 5 yards
    [125413] = "spear_hand_strike",  -- Spear Hand Strike now affects all enemies within 5 yards
    [125414] = "ring_of_peace",      -- Ring of Peace now affects all enemies within 8 yards
    [125415] = "grapple_weapon",     -- Grapple Weapon now affects all enemies within 5 yards
    [125416] = "nimble_brew",        -- Nimble Brew now affects all enemies within 5 yards
    [125417] = "leg_sweep",          -- Leg Sweep now affects all enemies within 8 yards
    
    -- Minor glyphs - Visual/Convenience
    [57856] = "transcendence",       -- Your transcendence has enhanced visual effects
    [57862] = "roll",                -- Your roll has enhanced visual effects
    [57863] = "chi_torpedo",         -- Your chi torpedo has enhanced visual effects
    [57855] = "flying_serpent_kick", -- Your flying serpent kick has enhanced visual effects
    [57861] = "tiger_palm",          -- Your tiger palm has enhanced visual effects
    [57857] = "blackout_kick",       -- Your blackout kick has enhanced visual effects
    [57858] = "fists_of_fury",       -- Your fists of fury has enhanced visual effects
    [57860] = "rising_sun_kick",     -- Your rising sun kick has enhanced visual effects
    [121840] = "spinning_crane_kick", -- Your spinning crane kick has enhanced visual effects
    [125418] = "blooming",           -- Your abilities cause flowers to bloom around the target
    [125419] = "floating",           -- Your spells cause you to hover slightly above the ground
    [125420] = "glow",               -- Your abilities cause you to glow with chi energy
} )

-- Auras
spec:RegisterAuras( {
    -- Damage received from $@auracaster increased by $w1%.
    afterlife = {
        id = 116092,
        duration = 8,
        max_stack = 1,
    },
    -- Tiger Palm and Blackout Kick have a 20% chance to not consume Chi.
    ascension = {
        id = 115396,
        duration = 3600,
        max_stack = 1,
    },
    -- Physical damage increased by $w1%.
    bok_proc = {
        id = 116768,
        type = "Magic",
        duration = 15,
        max_stack = 2,
    },
    -- Movement slowed by $s1%.
    charging_ox_wave = {
        id = 119392,
        duration = 3,
        max_stack = 1,
    },
    -- Increases the damage done by your next Chi Explosion by $s1%.
    chi_brew = {
        id = 115399,
        duration = 0,
        max_stack = 1,
    },
    -- Movement speed increased by $w1%.
    chi_torpedo = {
        id = 119085,
        duration = 10,
        max_stack = 2
    },
    -- Dealing $w1 damage every $t1 sec.
    chi_wave = {
        id = 132467,
        duration = 3600,
        max_stack = 1
    },
    -- Channeling Chi energy.
    crackling_jade_lightning = {
        id = 117952,
        duration = 4,
        tick_time = 1,
        type = "Magic",
        max_stack = 1
    },
    -- Spell damage taken reduced by $m1%.
    diffuse_magic = {
        id = 122783,
        duration = 6,
        type = "Magic",
        max_stack = 1
    },
    -- Movement slowed by $w1%. When struck again by Disable, you will be rooted for $116706d.
    disable = {
        id = 116095,
        duration = 15,
        mechanic = "snare",
        max_stack = 1
    },
    disable_root = {
        id = 116706,
        duration = 8,
        max_stack = 1,
    },
    -- Damage taken reduced by 20% to 50%.
    dampen_harm = {
        id = 122278,
        duration = 10,
        max_stack = 1
    },
    -- Stunned.
    fists_of_fury = {
        id = 113656,
        duration = function () return 4 * haste end,
        max_stack = 1,
    },
    -- Stunned.
    fists_of_fury_stun = {
        id = 120086,
        duration = 4,
        mechanic = "stun",
        max_stack = 1
    },
    flying_serpent_kick = {
        name = "Flying Serpent Kick",
        duration = 2,
        generate = function ()
            local cast = rawget( class.abilities.flying_serpent_kick, "lastCast" ) or 0
            local expires = cast + 2

            local fsk = buff.flying_serpent_kick
            fsk.name = "Flying Serpent Kick"

            if expires > query_time then
                fsk.count = 1
                fsk.expires = expires
                fsk.applied = cast
                fsk.caster = "player"
                return
            end
            fsk.count = 0
            fsk.expires = 0
            fsk.applied = 0
            fsk.caster = "nobody"
        end,
    },
    -- Regenerating Energy and Chi.
    healing_elixirs = {
        id = 122280,
        duration = 3600,
        max_stack = 1,
    },

    -- Movement speed increased by $w1%.
    momentum = {
        id = 115174,
        duration = 6,
        max_stack = 1,
    },

    -- Your next Tiger Palm will deal 300% weapon damage and restore 1 additional Chi.
    power_strikes = {
        id = 129914,
        duration = 3600,
        max_stack = 1,
    },











    transcendence_transfer = {
        id = 119996,
    },

    -- Healing for $w1.
    zen_sphere = {
        id = 124081,
        duration = 16,
        max_stack = 1,
    },

    -- Talent: Movement speed reduced by $m2%.
    -- https://wowhead.com/beta/spell=123586
    flying_serpent_kick_snare = {
        id = 123586,
        duration = 4,
        max_stack = 1
    },
    fury_of_xuen_stacks = {
        id = 396167,
        duration = 30,
        max_stack = 100,
        copy = { "fury_of_xuen", 396168, 396167, 287062 }
    },
    fury_of_xuen_buff = {
        id = 287063,
        duration = 8,
        max_stack = 1,
        copy = 396168
    },
    -- $@auracaster's abilities to have a $h% chance to strike for $s1% additional Nature damage.
    gale_force = {
        id = 451582,
        duration = 10.0,
        max_stack = 1,
    },
    hidden_masters_forbidden_touch = {
        id = 213114,
        duration = 5,
        max_stack = 1
    },
    hit_combo = {
        id = 196741,
        duration = 10,
        max_stack = 6,
    },
    invoke_xuen = {
        id = 123904,
        duration = 20, -- 11/1 nerf from 24 to 20.
        max_stack = 1,
        hidden = true,
        copy = "invoke_xuen_the_white_tiger"
    },
    -- Talent: Haste increased by $w1%.
    -- https://wowhead.com/beta/spell=388663
    invokers_delight = {
        id = 388663,
        duration = 20,
        max_stack = 1,
        copy = 338321
    },

    --[[mark_of_the_crane = {
        id = 228287,
        duration = 15,
        max_stack = 1,
        no_ticks = true
    },--]]
    -- The damage of your next Tiger Palm is increased by $w1%.
    martial_mixture = {
        id = 451457,
        duration = 15.0,
        max_stack = 30,
    },
    -- Haste increased by ${$w1}.1%.
    memory_of_the_monastery = {
        id = 454970,
        duration = 5.0,
        max_stack = 8,
    },
    -- Fists of Fury's damage increased by $s1%.
    momentum_boost = {
        id = 451297,
        duration = 10.0,
        max_stack = 1,
    },
    momentum_boost_speed = {
        id = 451298,
        duration = 8,
        max_stack = 1
    },
    mortal_wounds = {
        id = 115804,
        duration = 10,
        max_stack = 1,
    },
    mystic_touch = {
        id = 113746,
        duration = 3600,
        max_stack = 1,
    },
    -- Reduces the Chi Cost of your abilities by $s1.
    ordered_elements = {
        id = 451462,
        duration = 3600,
        max_stack = 1,
    },

    pressure_point = {
        id = 393053,
        duration = 5,
        max_stack = 1,
        copy = 337482
    },




    save_them_all = {
        id = 390105,
        duration = 4,
        max_stack = 1
    },

    -- $?$w2!=0[Movement speed reduced by $w2%.  ][]Drenched in brew, vulnerable to Breath of Fire.
    -- https://wowhead.com/beta/spell=196733
    special_delivery = {
        id = 196733,
        duration = 15,
        max_stack = 1
    },

    -- Talent: Elemental spirits summoned, mirroring all of the Monk's attacks.  The Monk and spirits each do ${100+$m1}% of normal damage and healing.
    -- https://wowhead.com/beta/spell=137639
    storm_earth_and_fire = {
        id = 137639,
        duration = 15,
        max_stack = 1
    },
    -- Talent: Movement speed reduced by $s2%.
    -- https://wowhead.com/beta/spell=392983
    strike_of_the_windlord = {
        id = 392983,
        duration = 6,
        max_stack = 1
    },
    -- Movement slowed by $s1%.
    -- https://wowhead.com/beta/spell=280184
    sweep_the_leg = {
        id = 280184,
        duration = 6,
        max_stack = 1
    },
    teachings_of_the_monastery = {
        id = 202090,
        duration = 20,
        max_stack = function() return talent.knowledge_of_the_broken_temple.enabled and 8 or 4 end,
    },
    -- Damage of next Crackling Jade Lightning increased by $s1%.  Energy cost of next Crackling Jade Lightning reduced by $s2%.
    -- https://wowhead.com/beta/spell=393039
    the_emperors_capacitor = {
        id = 393039,
        duration = 3600,
        max_stack = 20,
        copy = 337291
    },
    thunderfist = {
        id = 393565,
        duration = 30,
        max_stack = 30
    },

    transfer_the_power = {
        id = 195321,
        duration = 30,
        max_stack = 10
    },
    -- Talent: Your next Vivify is instant.
    -- https://wowhead.com/beta/spell=392883
    vivacious_vivification = {
        id = 392883,
        duration = 3600,
        max_stack = 1
    },
    -- Talent:
    -- https://wowhead.com/beta/spell=196742
    whirling_dragon_punch = {
        id = 196742,
        duration = function () return action.rising_sun_kick.cooldown end,
        max_stack = 1,
    },
    windwalking = {
        id = 166646,
        duration = 3600,
        max_stack = 1,
    },
    wisdom_of_the_wall_flurry = {
        id = 452688,
        duration = 40,
        max_stack = 1
    },
    -- Flying.
    -- https://wowhead.com/beta/spell=125883
    zen_flight = {
        id = 125883,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    zen_pilgrimage = {
        id = 126892,
    },

    -- PvP Talents
    alpha_tiger = {
        id = 287504,
        duration = 8,
        max_stack = 1,
    },
    fortifying_brew = {
        id = 201318,
        duration = 15,
        max_stack = 1,
    },
    grapple_weapon = {
        id = 233759,
        duration = 6,
        max_stack = 1,
    },
    heavyhanded_strikes = {
        id = 201787,
        duration = 2,
        max_stack = 1,
    },
    ride_the_wind = {
        id = 201447,
        duration = 3600,
        max_stack = 1,
    },
    tigereye_brew = {
        id = 247483,
        duration = 20,
        max_stack = 1
    },
    tigereye_brew_stack = {
        id = 248646,
        duration = 120,
        max_stack = 20,
    },
    wind_waker = {
        id = 290500,
        duration = 4,
        max_stack = 1,
    },

    -- Conduit
    coordinated_offensive = {
        id = 336602,
        duration = 15,
        max_stack = 1
    },

    -- Azerite Powers
    recently_challenged = {
        id = 290512,
        duration = 30,
        max_stack = 1
    },
    sunrise_technique = {
        id = 273298,
        duration = 15,
        max_stack = 1
    },
} )

-- The War Within
spec:RegisterGear( "tww2", 229301, 229299, 229298, 229297, 229296 )
spec:RegisterAuras( {
    -- 2-set
    -- https://www.wowhead.com/ptr-2/spell=1216182/winning-streak // https://www.wowhead.com/ptr-2/spell=1215717/monk-windwalker-11-1-class-set-2pc
    -- [Your spells and abilities have a chance to activate a Winning Streak! increasing the damage of your Rising Sun Kick and Spinning Crane Kick by 3% stacking up to 10 times. Rising Sun Kick and Spinning Crane Kick have a 15% chance to remove Winning Streak!] = {
    winning_streak = {
        id = 1216182,
        duration = 3600,
        max_stack = 10
    },
    -- https://www.wowhead.com/ptr-2/spell=1216498/cashout // https://www.wowhead.com/ptr-2/spell=1215718/monk-windwalker-11-1-class-set-4pc
    cashout = {
        id = 1216498,
        duration = 30,
        max_stack = 10
    },
} )

-- MoP: Removed Dragonflight tier sets and auras as they don't exist in MoP
spec:RegisterGear( "tier29", 200360, 200362, 200363, 200364, 200365, 217188, 217190, 217186, 217187, 217189 )
spec:RegisterAuras( {
    kicks_of_flowing_momentum = {
        id = 394944,
        duration = 30,
        max_stack = 2,
    },
    fists_of_flowing_momentum = {
        id = 394949,
        duration = 30,
        max_stack = 3,
    }
} )

-- Legacy
spec:RegisterGear( "tier19", 138325, 138328, 138331, 138334, 138337, 138367 )
spec:RegisterGear( "tier20", 147154, 147156, 147152, 147151, 147153, 147155 )
spec:RegisterGear( "tier21", 152145, 152147, 152143, 152142, 152144, 152146 )
spec:RegisterGear( "class", 139731, 139732, 139733, 139734, 139735, 139736, 139737, 139738 )
spec:RegisterGear( "cenedril_reflector_of_hatred", 137019 )
spec:RegisterGear( "cinidaria_the_symbiote", 133976 )
spec:RegisterGear( "drinking_horn_cover", 137097 )
spec:RegisterGear( "firestone_walkers", 137027 )
spec:RegisterGear( "fundamental_observation", 137063 )
-- MoP: Removed Legion legendary gear as they don't exist in MoP


spec:RegisterStateTable( "combos", {
    blackout_kick = true,
    celestial_conduit = true,
    chi_burst = true,
    chi_wave = true,
    crackling_jade_lightning = true,
    expel_harm = true,
    faeline_stomp = true,
    jadefire_stomp = true,
    fists_of_fury = true,
    flying_serpent_kick = true,
    rising_sun_kick = true,
    rushing_jade_wind = true,
    slicing_wind = true,
    spinning_crane_kick = true,
    strike_of_the_windlord = true,
    tiger_palm = true,
    touch_of_death = true,
    weapons_of_order = true,
    whirling_dragon_punch = true
} )

local prev_combo, actual_combo = "none", "none"

spec:RegisterStateExpr( "last_combo", function () return actual_combo end )

spec:RegisterStateExpr( "combo_break", function ()
    return this_action == last_combo
end )

spec:RegisterStateExpr( "combo_strike", function ()
    return not combos[ this_action ] or this_action ~= last_combo
end )


-- If a Tiger Palm missed, pretend we never cast it.
-- Use RegisterEvent since we're looking outside the state table.
spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellID, spellName )
    if sourceGUID == state.GUID then
        local ability = class.abilities[ spellID ] and class.abilities[ spellID ].key
        if not ability then return end

        if ability == "tiger_palm" and subtype == "SPELL_MISSED" and not state.talent.hit_combo.enabled then
            if ns.castsAll[1] == "tiger_palm" then table.remove( ns.castsAll, 1 ) end
            if ns.castsAll[2] == "tiger_palm" then table.remove( ns.castsAll, 2 ) end
            if ns.castsOn[1] == "tiger_palm" then table.remove( ns.castsOn, 1 ) end

            actual_combo = ns.castsOn[ 1 ] or "none"

            Hekili:ForceUpdate( "WW_MISSED" )

        elseif subtype == "SPELL_CAST_SUCCESS" and state.combos[ ability ] then
            prev_combo = actual_combo
            actual_combo = ability

        elseif subtype == "SPELL_DAMAGE" and spellID == 148187 then
            -- track the last tick.
            state.buff.rushing_jade_wind.last_tick = GetTime()
        end
    end
end )


local chiSpent = 0
local orderedElementsMod = 0

--[[spec:RegisterHook( "prespend", function( amt, resource, overcap, clean )

    if resource == "chi" then
        if talent.ordered_elements.enabled and buff.storm_earth_and_fire.up then
            amt = max( 0, amt - 1 )
        end
        if covenant.kyrian then return weapons_of_order( amt ), resource, overcap, true end
    end

    return amt, resource, overcap, true

end )--]]

spec:RegisterHook( "spend", function( amt, resource )
    if resource == "chi" and amt > 0 then
        if talent.spiritual_focus.enabled then
            chiSpent = chiSpent + amt
            cooldown.storm_earth_and_fire.expires = max( 0, cooldown.storm_earth_and_fire.expires - floor( chiSpent / 2 ) )
            chiSpent = chiSpent % 2
        end

        if talent.drinking_horn_cover.enabled and buff.storm_earth_and_fire.up then
            buff.storm_earth_and_fire.expires = buff.storm_earth_and_fire.expires + 0.25
        end

        if talent.last_emperors_capacitor.enabled or legendary.last_emperors_capacitor.enabled then
            addStack( "the_emperors_capacitor" )
        end
    elseif resource == "energy" then
        if amt > 50 and talent.efficient_training.enabled then
            reduceCooldown( "storm_earth_and_fire", 1 )
        end

    end
end )


local noop = function () end

-- local reverse_harm_target




spec:RegisterHook( "runHandler", function( key, noStart )
    if combos[ key ] then
        if last_combo == key then removeBuff( "hit_combo" )
        else
            if talent.hit_combo.enabled then addStack( "hit_combo" ) end
            if azerite.fury_of_xuen.enabled or talent.fury_of_xuen.enabled then addStack( "fury_of_xuen" ) end
            -- if ( talent.xuens_bond.enabled or conduit.xuens_bond.enabled ) and cooldown.invoke_xuen.remains > 0 then reduceCooldown( "invoke_xuen", 0.2 ) end
            if talent.meridian_strikes.enabled and cooldown.touch_of_death.remains > 0 then reduceCooldown( "touch_of_death", 0.6 ) end
        end
        last_combo = key
    end
end )


spec:RegisterStateTable( "healing_sphere", setmetatable( {}, {
    __index = function( t,  k)
        if k == "count" then
            t[ k ] = GetSpellCount( action.expel_harm.id )
            return t[ k ]
        end
    end
} ) )

spec:RegisterHook( "reset_precast", function ()
    rawset( state.healing_sphere, "count", nil )
    if state.healing_sphere.count > 0 then
        applyBuff( "gift_of_the_ox", nil, state.healing_sphere.count )
    end

    chiSpent = 0

    if buff.rushing_jade_wind.up then setCooldown( "rushing_jade_wind", 0 ) end

    if buff.casting.up and buff.casting.v1 == action.spinning_crane_kick.id then
        removeBuff( "casting" )
        -- Spinning Crane Kick buff should be up.
    end

    if buff.weapons_of_order_ww.up then
        state:QueueAuraExpiration( "weapons_of_order_ww", noop, buff.weapons_of_order_ww.expires )
    end
end )

spec:RegisterHook( "IsUsable", function( spell )
    if spell == "touch_of_death" then return end -- rely on priority only.

    -- Allow repeats to happen if your chi has decayed to 0.
    -- TWW priority appears to allow hit_combo breakage for Tiger Palm.
    if talent.hit_combo.enabled and buff.hit_combo.up and spell ~= "tiger_palm" and last_combo == spell then
        return false, "would break hit_combo"
    end
end )


--[[spec:RegisterStateTable( "fight_style", setmetatable( { onReset = function( self ) self.count = nil end },
        { __index = function( t, k )
            if k == "patchwerk" then
                return boss
            elseif k == "dungeonroute" then
                return false -- this option seems more likely to yeet cooldowns even for dying trash
            elseif k == "dungeonslice" then
                return not boss
            elseif k == "Dungeonslice" then -- to account for the typo in SIMC
                return not boss
            end
        end } ) )--]]

spec:RegisterStateExpr( "alpha_tiger_ready", function ()
    if not pvptalent.alpha_tiger.enabled then
        return false
    elseif debuff.recently_challenged.down then
        return true
    elseif cycle then return
    active_dot.recently_challenged < active_enemies
    end
    return false
end )

spec:RegisterStateExpr( "alpha_tiger_ready_in", function ()
    if not pvptalent.alpha_tiger.enabled then return 3600 end
    if active_dot.recently_challenged < active_enemies then return 0 end
    return debuff.recently_challenged.remains
end )

spec:RegisterStateFunction( "weapons_of_order", function( c )
    if c and c > 0 then
        return buff.weapons_of_order_ww.up and ( c - 1 ) or c
    end
    return c
end )


spec:RegisterPet( "xuen_the_white_tiger", 63508, "invoke_xuen", 24, "xuen" )

-- Totems (which are sometimes pets)
spec:RegisterTotems( {
    jade_serpent_statue = {
        id = 620831
    },
    white_tiger_statue = {
        id = 125826
    },
    black_ox_statue = {
        id = 627607
    }
} )

spec:RegisterUnitEvent( "UNIT_POWER_UPDATE", "player", nil, function( event, unit, resource )
    if resource == "CHI" then
        if UnitPower( "player", 12 ) < 2 and ns.castsOn[ 1 ] == "tiger_palm" then table.remove( ns.castsOn, 1 ) end
        Hekili:ForceUpdate( event, true )
    end
end )

local empowered_cast_time
local max_empower = 4

do
    local stages = {
        1.4 * 0.25,
        1.4 * 0.5,
        1.4 * 0.75,
        1.4
    }

    empowered_cast_time = setfenv( function()
        local power_level = args.empower_to or class.abilities[ this_action ].empowerment_default or max_empower
        return stages[ power_level ] * haste
    end, state )
end

spec:RegisterStateExpr( "orderedElementsMod", function()
    if not talented.ordered_elements.enabled or buff.storm_earth_and_fire.down then return 0 end
    return 1
end )

-- Abilities
spec:RegisterAbilities( {
    -- Kick with a blast of Chi energy, dealing Physical damage.
    blackout_kick = {
        id = 100784,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function ()
            if buff.bok_proc.up then return 0 end
            return 2
        end,
        spendType = "chi",

        startsCombat = true,
        texture = 574575,

        handler = function ()
            if buff.bok_proc.up then
                removeBuff( "bok_proc" )
            end
        end,
    },

    -- Talent: Generates 1-2 Chi. Instant.
    chi_brew = {
        id = 115399,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        school = "physical",

        talent = "chi_brew",
        startsCombat = false,
        usable = function() return chi.current < chi.max end,

        handler = function()
            local chi_gain = math.random(1, 2)
            gain( chi_gain, "chi" )
        end,
    },

    -- Talent: Hurls a torrent of Chi energy up to 40 yds forward, dealing Nature damage to all enemies and healing allies.
    chi_burst = {
        id = 123986,
        cast = function () return 1 * haste end,
        cooldown = 30,
        gcd = "spell",
        school = "nature",

        talent = "chi_burst",
        startsCombat = true,

        handler = function()
            gain( 1, "chi" )
        end,
    },

    -- Talent: Torpedoes you forward a long distance and increases your movement speed by 30% for 10 sec.
    chi_torpedo = {
        id = 115008,
        cast = 0,
        charges = function () return talent.celerity.enabled and 3 or 2 end,
        cooldown = 20,
        recharge = 20,
        gcd = "off",
        school = "physical",

        talent = "chi_torpedo",
        startsCombat = false,

        handler = function ()
            -- trigger chi_torpedo [119085]
            applyBuff( "chi_torpedo" )
        end,
    },

    --[[ Talent: A wave of Chi energy flows through friends and foes, dealing $132467s1 Nature damage or $132463s1 healing. Bounces up to $s1 times to targets within $132466a2 yards.
    chi_wave = {
        id = 115098,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "nature",

        talent = "chi_wave",
        startsCombat = false,

        handler = function ()
        end,
    }, ]]

    -- Channel Jade lightning, causing $o1 Nature damage over $117952d to the target$?a154436[, generating 1 Chi each time it deals damage,][] and sometimes knocking back melee attackers.
    crackling_jade_lightning = {
        id = 117952,
        cast = 2,
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = function () return 20 * ( 1 - ( buff.the_emperors_capacitor.stack * 0.05 ) ) end,
        spendPerSec = function () return 20 * ( 1 - ( buff.the_emperors_capacitor.stack * 0.05 ) ) end,

        toggle = function ()
            if buff.the_emperors_capacitor.up then
                local dyn = state.settings.cjl_capacitor_toggle
                if dyn == "none" then return "none" end
                if dyn == "default" then return nil end
                return dyn
            end
            return "none"
        end,

        startsCombat = false,

        handler = function ()
            applyBuff( "crackling_jade_lightning" )
        end,

        finish = function ()
            removeBuff( "the_emperors_capacitor" )
        end,
    },

    -- Talent: Removes all Poison and Disease effects from the target.
    detox = {
        id = 218164,
        cast = 0,
        charges = 1,
        cooldown = 8,
        recharge = 8,
        gcd = "spell",
        school = "nature",

        spend = 20,
        spendType = "energy",

        talent = "detox",
        startsCombat = false,

        toggle = "interrupts",
        usable = function () return debuff.dispellable_poison.up or debuff.dispellable_disease.up, "requires dispellable_poison/disease" end,

        handler = function ()
            removeDebuff( "player", "dispellable_poison" )
            removeDebuff( "player", "dispellable_disease" )
        end,nm
    },

    -- Talent: Reduces magic damage you take by $m1% for $d, and transfers all currently active harmful magical effects on you back to their original caster if possible.
    diffuse_magic = {
        id = 122783,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        school = "nature",

        talent = "diffuse_magic",
        startsCombat = false,

        toggle = "interrupts",
        buff = "dispellable_magic",

        handler = function ()
            removeBuff( "dispellable_magic" )
        end,
    },

    -- Talent: Reduces the target's movement speed by $s1% for $d, duration refreshed by your melee attacks.$?s343731[ Targets already snared will be rooted for $116706d instead.][]
    disable = {
        id = 116095,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = 15,
        spendType = "energy",

        talent = "disable",
        startsCombat = true,

        handler = function ()
            if not debuff.disable.up then applyDebuff( "target", "disable" )
            else applyDebuff( "target", "disable_root" ) end
        end,
    },

    -- Expel negative chi from your body, healing for $s1 and dealing $s2% of the amount healed as Nature damage to an enemy within $115129A1 yards.$?s322102[    Draws in the positive chi of all your Healing Spheres to increase the healing of Expel Harm.][]$?s325214[    May be cast during Soothing Mist, and will additionally heal the Soothing Mist target.][]$?s322106[    |cFFFFFFFFGenerates $s3 Chi.]?s342928[    |cFFFFFFFFGenerates ${$s3+$342928s2} Chi.][]
    expel_harm = {
        id = 322101,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        school = "nature",

        spend = 15,
        spendType = "energy",

        startsCombat = false,
        notalent = "combat_wisdom",

        handler = function ()
            gain( ( healing_sphere.count * stat.attack_power ) + stat.spell_power * ( 1 + stat.versatility_atk_mod ), "health" )
            removeBuff( "gift_of_the_ox" )
            healing_sphere.count = 0

            -- gain( pvptalent.reverse_harm.enabled and 2 or 1, "chi" )
        end,
    },

    -- Talent: Strike the ground fiercely to expose a faeline for $d, dealing $388207s1 Nature damage to up to 5 enemies, and restores $388207s2 health to up to 5 allies within $388207a1 yds caught in the faeline. $?a137024[Up to 5 allies]?a137025[Up to 5 enemies][Stagger is $s3% more effective for $347480d against enemies] caught in the faeline$?a137023[]?a137024[ are healed with an Essence Font bolt][ suffer an additional $388201s1 damage].    Your abilities have a $s2% chance of resetting the cooldown of Faeline Stomp while fighting on a faeline.
    jadefire_stomp = {
        id = function() return talent.jadefire_stomp.enabled and 388193 or 327104 end,
        cast = 0,
        -- charges = 1,
        cooldown = function() return state.spec.mistweaver and 15 or 30 end,
        -- recharge = 30,
        gcd = "spell",
        school = "nature",

        spend = 0.04,
        spendType = "mana",

        startsCombat = true,
        notalent = "jadefire_fists",

        cycle = function() if talent.jadefire_harmony.enabled then return "jadefire_brand" end end,

        handler = function ()
            applyBuff( "jadefire_stomp" )

            if state.spec.brewmaster then
                applyDebuff( "target", "breath_of_fire" )
                active_dot.breath_of_fire = active_enemies
            end

            if state.spec.mistweaver then
                if talent.ancient_concordance.enabled then applyBuff( "ancient_concordance" ) end
                if talent.ancient_teachings.enabled then applyBuff( "ancient_teachings" ) end
                if talent.awakened_jadefire.enabled then applyBuff( "awakened_jadefire" ) end
            end

            if talent.jadefire_harmony.enabled or legendary.fae_exposure.enabled then applyDebuff( "target", "jadefire_brand" ) end
        end,

        copy = { 388193, 327104, "faeline_stomp" }
    },

    -- Talent: Pummels all targets in front of you, dealing ${5*$117418s1} Physical damage to your primary target and ${5*$117418s1*$s6/100} damage to all other enemies over $113656d. Deals reduced damage beyond $s1 targets. Can be channeled while moving.
    fists_of_fury = {
        id = 113656,
        cast = 4,
        channeled = true,
        cooldown = 24,
        gcd = "spell",
        school = "physical",

        spend = function() return 3 - orderedElementsMod end,
        spendType = "chi",

        tick_time = function () return haste end,

        start = function ()
            -- Standard effects / talents

            removeBuff( "transfer_the_power" )

            if buff.fury_of_xuen.stack >= 50 then
                applyBuff( "fury_of_xuen_buff" )
                summonPet( "xuen", 10 )
                removeBuff( "fury_of_xuen" )
            end

            if talent.whirling_dragon_punch.enabled and cooldown.rising_sun_kick.remains > 0 then
                applyBuff( "whirling_dragon_punch", min( cooldown.fists_of_fury.remains, cooldown.rising_sun_kick.remains ) )
            end

            -- Hero Talents

            -- The War Within
            if set_bonus.tww2 >= 4 then removeBuff( "cashout" ) end

            -- PvP
            if pvptalent.turbo_fists.enabled then
                applyDebuff( "target", "heavyhanded_strikes", action.fists_of_fury.cast_time + 2 )
            end

            -- Legacy
            if set_bonus.tier29_2pc > 0 then applyBuff( "kicks_of_flowing_momentum", nil, set_bonus.tier29_4pc > 0 and 3 or 2 ) end
            if set_bonus.tier30_4pc > 0 then
                applyDebuff( "target", "shadowflame_vulnerability" )
                active_dot.shadowflame_vulnerability = active_enemies
            end
            removeBuff( "fists_of_flowing_momentum" )
        end,



        tick = function ()
            if legendary.jade_ignition.enabled then
                addStack( "chi_energy", nil, active_enemies )
            end
        end,

        finish = function ()
            if talent.jadefire_fists.enabled and query_time - action.fists_of_fury.lastCast > 25 then class.abilities.jadefire_stomp.handler() end
            if talent.momentum_boost.enabled then applyBuff( "momentum_boost" ) end
            if talent.xuens_battlegear.enabled or legendary.xuens_battlegear.enabled then applyBuff( "pressure_point" ) end
        end,
    },

    -- Talent: Soar forward through the air at high speed for $d.     If used again while active, you will land, dealing $123586s1 damage to all enemies within $123586A1 yards and reducing movement speed by $123586s2% for $123586d.
    flying_serpent_kick = {
        id = 101545,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",

        talent = "flying_serpent_kick",
        notalent = "slicing_winds",
        startsCombat = false,

        -- Sync to the GCD even though it's not really on it.
        readyTime = function()
            return gcd.remains
        end,

        handler = function ()
            if buff.flying_serpent_kick.up then
                removeBuff( "flying_serpent_kick" )
            else
                applyBuff( "flying_serpent_kick" )
                setCooldown( "global_cooldown", 2 )
            end
        end,
    },

    -- Talent: Turns your skin to stone for $120954d$?a388917[, increasing your current and maximum health by $<health>%][]$?s322960[, increasing the effectiveness of Stagger by $322960s1%][]$?a388917[, reducing all damage you take by $<damage>%][]$?a388814[, increasing your armor by $388814s2% and dodge chance by $388814s1%][].
    fortifying_brew = {
        id = 115203,
        cast = 0,
        cooldown = function()
            if state.spec.brewmaster then return talent.expeditious_fortification.enabled and 240 or 360 end
            return talent.expeditious_fortification.enabled and 90 or 120
        end,
        gcd = "off",
        school = "physical",

        talent = "fortifying_brew",
        startsCombat = false,

        toggle = "defensives",

        handler = function ()
            applyBuff( "fortifying_brew" )
            if conduit.fortifying_ingredients.enabled then applyBuff( "fortifying_ingredients" ) end
        end,
    },


    grapple_weapon = {
        id = 233759,
        cast = 0,
        cooldown = 45,
        gcd = "spell",

        pvptalent = "grapple_weapon",

        startsCombat = true,
        texture = 132343,

        handler = function ()
            applyDebuff( "target", "grapple_weapon" )
        end,
    },

    -- Talent: Summons an effigy of Xuen, the White Tiger for $d. Xuen attacks your primary target, and strikes 3 enemies within $123996A1 yards every $123999t1 sec with Tiger Lightning for $123996s1 Nature damage.$?s323999[    Every $323999s1 sec, Xuen strikes your enemies with Empowered Tiger Lightning dealing $323999s2% of the damage you have dealt to those targets in the last $323999s1 sec.][]
    invoke_xuen = {
        id = 123904,
        cast = 0,
        cooldown = function() return 120 - ( 30 * talent.xuens_bond.rank ) end,
        gcd = "spell",
        school = "nature",

        talent = "invoke_xuen",
        startsCombat = false,

        toggle = "cooldowns",

        handler = function ()
            summonPet( "xuen_the_white_tiger", 24 )
            applyBuff( "invoke_xuen" )

            if talent.invokers_delight.enabled or legendary.invokers_delight.enabled then
                if buff.invokers_delight.down then stat.haste = stat.haste + 0.2 end
                applyBuff( "invokers_delight" )
            end

            if talent.summon_white_tiger_statue.enabled then
                summonTotem( "white_tiger_statue", nil, 10 )
            end
        end,

        copy = "invoke_xuen_the_white_tiger"
    },

    -- Knocks down all enemies within $A1 yards, stunning them for $d.
    leg_sweep = {
        id = 119381,
        cast = 0,
        cooldown = function() return 60 - 10 * talent.tiger_tail_sweep.rank end,
        gcd = "spell",
        school = "physical",

        startsCombat = true,

        handler = function ()
            applyDebuff( "target", "leg_sweep" )
            active_dot.leg_sweep = active_enemies
            if conduit.dizzying_tumble.enabled then applyDebuff( "target", "dizzying_tumble" ) end
        end,
    },

    paralysis = {
        id = 115078,
        cast = 0,
        cooldown = function() return 45 - ( 7.5 * talent.ancient_arts.rank ) end,
        gcd = "spell",
        school = "physical",

        spend = 20,
        spendType = "energy",
        toggle = function() if talent.pressure_points.enabled then return "interrupts" end end,

        talent = "paralysis",
        startsCombat = true,

        usable = function () if talent.pressure_points.enabled then
            return buff.dispellable_enrage.up end
            return true
        end,

        handler = function ()
            applyDebuff( "target", "paralysis" )
            if talent.pressure_points.enabled then removeBuff( "dispellable_enrage" ) end
        end,
    },

    -- Taunts the target to attack you$?s328670[ and causes them to move toward you at $116189m3% increased speed.][.]$?s115315[    This ability can be targeted on your Statue of the Black Ox, causing the same effect on all enemies within  $118635A1 yards of the statue.][]
    provoke = {
        id = 115546,
        cast = 0,
        cooldown = 8,
        gcd = "off",
        school = "physical",

        startsCombat = false,

        handler = function ()
            applyDebuff( "target", "provoke" )
        end,
    },

    -- Talent: Form a Ring of Peace at the target location for $d. Enemies that enter will be ejected from the Ring.
    ring_of_peace = {
        id = 116844,
        cast = 0,
        cooldown = 45,
        gcd = "spell",
        school = "nature",

        talent = "ring_of_peace",
        startsCombat = false,

        handler = function ()
        end,
    },

    -- Talent: Kick upwards, dealing $?s137025[${$185099s1*$<CAP>/$AP}][$185099s1] Physical damage$?s128595[, and reducing the effectiveness of healing on the target for $115804d][].$?a388847[    Applies Renewing Mist for $388847s1 seconds to an ally within $388847r yds][]
    rising_sun_kick = {
        id = 107428,
        cast = 0,
        cooldown = function ()
            return ( 10 - talent.brawlers_intensity.rank ) * haste
        end,
        gcd = "spell",
        school = "physical",

        spend = function() return 2 - orderedElementsMod end,
        spendType = "chi",

        talent = "rising_sun_kick",
        startsCombat = true,

        handler = function ()

            removeBuff( "chi_wave" )

            if talent.acclamation.enabled then applyDebuff( "target", "acclamation", nil, debuff.acclamation.stack + 1 ) end
            if talent.transfer_the_power.enabled then addStack( "transfer_the_power" ) end

            if talent.whirling_dragon_punch.enabled and cooldown.fists_of_fury.remains > 0 then
                applyBuff( "whirling_dragon_punch", min( cooldown.fists_of_fury.remains, cooldown.rising_sun_kick.remains ) )
            end


            -- Legacy
            if azerite.sunrise_technique.enabled then applyDebuff( "target", "sunrise_technique" ) end
            if buff.weapons_of_order.up then
                applyBuff( "weapons_of_order_ww" )
                state:QueueAuraExpiration( "weapons_of_order_ww", noop, buff.weapons_of_order_ww.expires )
            end
            if buff.kicks_of_flowing_momentum.up then
                removeStack( "kicks_of_flowing_momentum" )
                if set_bonus.tier29_4pc > 0 then addStack( "fists_of_flowing_momentum" ) end
            end
        end,
    },

    -- Roll a short distance.
    roll = {
        id = 109132,
        cast = 0,
        charges = function ()
            local n = 1 + ( talent.celerity.enabled and 1 or 0 ) + ( legendary.roll_out.enabled and 1 or 0 )
            if n > 1 then return n end
            return nil
        end,
        cooldown = function () return talent.celerity.enabled and 15 or 20 end,
        recharge = function () return talent.celerity.enabled and 15 or 20 end,
        gcd = "off",
        school = "physical",

        startsCombat = false,
        notalent = "chi_torpedo",

        handler = function ()
            if azerite.exit_strategy.enabled then applyBuff( "exit_strategy" ) end
        end,
    },

    --[[ Talent: Summons a whirling tornado around you, causing ${(1+$d/$t1)*$148187s1} Physical damage over $d to all enemies within $107270A1 yards. Deals reduced damage beyond $s1 targets.
    rushing_jade_wind = {
        id = 116847,
        cast = 0,
        cooldown = function ()
            local x = 6 * haste
            if buff.serenity.up then x = max( 0, x - ( buff.serenity.remains / 2 ) ) end
            return x
        end,
        gcd = "spell",
        school = "nature",

        spend = function() return weapons_of_order( buff.ordered_elements.up and 1 or 0 ) end,
        spendType = "chi",

        talent = "rushing_jade_wind",
        startsCombat = false,

        handler = function ()
            applyBuff( "rushing_jade_wind" )
            if talent.transfer_the_power.enabled then addStack( "transfer_the_power" ) end
        end,
    }, ]]

    --[[ Talent: Enter an elevated state of mental and physical serenity for $?s115069[$s1 sec][$d]. While in this state, you deal $s2% increased damage and healing, and all Chi consumers are free and cool down $s4% more quickly.
    serenity = {
        id = 152173,
        cast = 0,
        cooldown = function () return ( essence.vision_of_perfection.enabled and 0.87 or 1 ) * 90 end,
        gcd = "off",
        school = "physical",

        talent = "serenity",
        startsCombat = false,

        toggle = "cooldowns",

        handler = function ()
            applyBuff( "serenity" )
            setCooldown( "fists_of_fury", cooldown.fists_of_fury.remains - ( cooldown.fists_of_fury.remains / 2 ) )
            setCooldown( "rising_sun_kick", cooldown.rising_sun_kick.remains - ( cooldown.rising_sun_kick.remains / 2 ) )
            setCooldown( "rushing_jade_wind", cooldown.rushing_jade_wind.remains - ( cooldown.rushing_jade_wind.remains / 2 ) )
            if conduit.coordinated_offensive.enabled then applyBuff( "coordinated_offensive" ) end
        end,
    }, ]]

    -- Envelop yourself in razor-sharp winds, then lunge forward dealing 118,070 Nature damage to enemies in your path. Damage reduced beyond 5 enemies. Hold to increase lunge distance.
    slicing_winds = {
        id = 1217413,
        cast = empowered_cast_time,
        cooldown = 30,
        gcd = "totem",

        empowered = true,
        empowerment_default = 1,

        talent = "slicing_winds",
        startsCombat = false,
        texture = 1029596,

        handler = function ()
        end,
    },

    -- Talent: Heals the target for $o1 over $d.  While channeling, Enveloping Mist$?s227344[, Surging Mist,][]$?s124081[, Zen Pulse,][] and Vivify may be cast instantly on the target.$?s117907[    Each heal has a chance to cause a Gust of Mists on the target.][]$?s388477[    Soothing Mist heals a second injured ally within $388478A2 yds for $388477s1% of the amount healed.][]
    soothing_mist = {
        id = 115175,
        cast = 8,
        channeled = true,
        hasteCD = true,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        talent = "soothing_mist",
        startsCombat = false,

        handler = function ()
            applyBuff( "soothing_mist" )
        end,
    },

    -- Talent: Jabs the target in the throat, interrupting spellcasting and preventing any spell from that school of magic from being cast for $d.
    spear_hand_strike = {
        id = 116705,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",

        talent = "spear_hand_strike",
        startsCombat = true,

        toggle = "interrupts",

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function ()
            interrupt()
        end,
    },

    -- Spin while kicking in the air, dealing $?s137025[${4*$107270s1*$<CAP>/$AP}][${4*$107270s1}] Physical damage over $d to all enemies within $107270A1 yds. Deals reduced damage beyond $s1 targets.$?a220357[    Spinning Crane Kick's damage is increased by $220358s1% for each unique target you've struck in the last $220358d with Tiger Palm, Blackout Kick, or Rising Sun Kick. Stacks up to $228287i times.][]
    spinning_crane_kick = {
        id = 101546,
        cast = 1.5,
        channeled = true,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function () if buff.dance_of_chiji.up then return 0 end
            return 2 - orderedElementsMod
        end,
        spendType = "chi",

        startsCombat = true,

        usable = function ()
            if settings.check_sck_range and not action.fists_of_fury.in_range then return false, "target is out of range" end
            return true
        end,

        handler = function ()
            removeBuff( "chi_energy" )
            if buff.dance_of_chiji.up then
                if set_bonus.tier31_2pc > 0 then applyBuff( "blackout_reinforcement" ) end
                if talent.sequenced_strikes.enabled then addStack( "bok_proc" ) end
                removeStack( "dance_of_chiji" )
            end

            if buff.kicks_of_flowing_momentum.up then
                removeStack( "kicks_of_flowing_momentum" )
                if set_bonus.tier29_4pc > 0 then addStack( "fists_of_flowing_momentum" ) end
            end

            applyBuff( "spinning_crane_kick" )

            if talent.transfer_the_power.enabled then addStack( "transfer_the_power" ) end
        end,
    },

    -- Talent: Split into 3 elemental spirits for $d, each spirit dealing ${100+$m1}% of normal damage and healing.    You directly control the Storm spirit, while Earth and Fire spirits mimic your attacks on nearby enemies.    While active, casting Storm, Earth, and Fire again will cause the spirits to fixate on your target.
    storm_earth_and_fire = {
        id = 137639,
        cast = 0,
        charges = 2,
        cooldown = function () return ( essence.vision_of_perfection.enabled and 0.85 or 1 ) * 90 end,
        recharge = function () return ( essence.vision_of_perfection.enabled and 0.85 or 1 ) * 90 end,
        icd = 1,
        gcd = "off",
        school = "nature",

        talent = "storm_earth_and_fire",
        startsCombat = false,
        nobuff = "storm_earth_and_fire",
        texture = function()
            return buff.storm_earth_and_fire.up and 236188 or 136038
        end,

        toggle = function ()
            if settings.sef_one_charge then
                if cooldown.storm_earth_and_fire.true_time_to_max_charges > gcd.max then return "cooldowns" end
                return
            end
            return "cooldowns"
        end,

        handler = function ()
            -- trigger storm_earth_and_fire_fixate [221771]
            applyBuff( "storm_earth_and_fire" )
            if talent.ordered_elements.enabled then
                setCooldown( "rising_sun_kick", 0 )
                gain( 2, "chi" )
            end
        end,

        bind = "storm_earth_and_fire_fixate"
    },


    storm_earth_and_fire_fixate = {
        id = 221771,
        known = 137639,
        cast = 0,
        cooldown = 0,
        icd = 1,
        gcd = "spell",

        startsCombat = true,
        texture = 236188,

        buff = "storm_earth_and_fire",

        usable = function ()
            if buff.storm_earth_and_fire.down then return false, "spirits are not active" end
            return action.storm_earth_and_fire_fixate.lastCast < action.storm_earth_and_fire.lastCast, "spirits are already fixated"
        end,

        bind = "storm_earth_and_fire",
    },

    -- Talent: Strike with both fists at all enemies in front of you, dealing ${$395519s1+$395521s1} damage and reducing movement speed by $s2% for $d.
    strike_of_the_windlord = {
        id = 392983,
        cast = 0,
        cooldown = function() return 40 - ( 10 * talent.communion_with_wind.rank ) end,
        gcd = "spell",
        school = "physical",

        spend = function() return 2 - orderedElementsMod end,
        spendType = "chi",

        talent = "strike_of_the_windlord",
        startsCombat = true,

        toggle = function() if settings.dynamic_strike_of_the_windlord and raid then return "essences" end end,

        handler = function ()
            applyDebuff( "target", "strike_of_the_windlord" )
            -- if talent.darting_hurricane.enabled then addStack( "darting_hurricane", nil, 2 ) end
            if talent.gale_force.enabled then applyDebuff( "target", "gale_force" ) end
            if talent.rushing_jade_wind.enabled then
                --[[applyDebuff( "target", "mark_of_the_crane" )
                active_dot.mark_of_the_crane = true_active_enemies--]]
                applyBuff( "rushing_jade_wind" )
            end
            if talent.thunderfist.enabled then addStack( "thunderfist", nil, 4 + ( true_active_enemies - 1 ) ) end
        end,
    },

    -- Strike with the palm of your hand, dealing $s1 Physical damage.$?a137384[    Tiger Palm has an $137384m1% chance to make your next Blackout Kick cost no Chi.][]$?a137023[    Reduces the remaining cooldown on your Brews by $s3 sec.][]$?a129914[    |cFFFFFFFFGenerates 3 Chi.]?a137025[    |cFFFFFFFFGenerates $s2 Chi.][]
    tiger_palm = {
        id = 100780,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",

        spend = function() return talent.inner_peace.enabled and 55 or 60 end,
        spendType = "energy",

        startsCombat = true,

        handler = function ()
            gain( 2, "chi" )
            removeBuff( "martial_mixture" )

            if buff.combat_wisdom.up then
                class.abilities.expel_harm.handler()
                removeBuff( "combat_wisdom" )
            end

            if talent.eye_of_the_tiger.enabled then
                applyDebuff( "target", "eye_of_the_tiger" )
                applyBuff( "eye_of_the_tiger" )
            end

            if talent.teachings_of_the_monastery.enabled then addStack( "teachings_of_the_monastery" ) end

            if pvptalent.alpha_tiger.enabled and debuff.recently_challenged.down then
                if buff.alpha_tiger.down then
                    stat.haste = stat.haste + 0.10
                    applyBuff( "alpha_tiger" )
                    applyDebuff( "target", "recently_challenged" )
                end
            end

            --[[if buff.darting_hurricane.up then
                setCooldown( "global_cooldown", cooldown.global_cooldown.remains * 0.75 )
                removeStack( "darting_hurricane" )
            end--]]
        end,
    },


    tigereye_brew = {
        id = 247483,
        cast = 0,
        cooldown = 1,
        gcd = "spell",

        startsCombat = false,
        texture = 613399,

        buff = "tigereye_brew_stack",
        pvptalent = "tigereye_brew",

        handler = function ()
            applyBuff( "tigereye_brew", 2 * min( 10, buff.tigereye_brew_stack.stack ) )
            removeStack( "tigereye_brew_stack", min( 10, buff.tigereye_brew_stack.stack ) )
        end,
    },

    -- Talent: Increases a friendly target's movement speed by $s1% for $d and removes all roots and snares.
    tigers_lust = {
        id = 116841,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",

        talent = "tigers_lust",
        startsCombat = false,

        handler = function ()
            applyBuff( "tigers_lust" )
        end,
    },

    -- You exploit the enemy target's weakest point, instantly killing $?s322113[creatures if they have less health than you.][them.    Only usable on creatures that have less health than you]$?s322113[ Deals damage equal to $s3% of your maximum health against players and stronger creatures under $s2% health.][.]$?s325095[    Reduces delayed Stagger damage by $325095s1% of damage dealt.]?s325215[    Spawns $325215s1 Chi Spheres, granting 1 Chi when you walk through them.]?s344360[    Increases the Monk's Physical damage by $344361s1% for $344361d.][]
    touch_of_death = {
        id = 322109,
        cast = 0,
        cooldown = function () return 180 - ( 45 * talent.fatal_touch.rank ) end,
        gcd = "spell",
        school = "physical",

        startsCombat = true,

        toggle = "cooldowns",
        cycle = "touch_of_death",

        -- Non-players can be executed as soon as their current health is below player's max health.
        -- All targets can be executed under 15%, however only at 35% damage.
        usable = function ()
            return ( talent.improved_touch_of_death.enabled and target.health_pct < 15 ) or ( target.class == "npc" and target.health_current < health.current ), "requires low health target"
        end,

        handler = function ()
            applyDebuff( "target", "touch_of_death" )
        end,
    },

    -- Talent: Absorbs all damage taken for $d, up to $s3% of your maximum health, and redirects $s4% of that amount to the enemy target as Nature damage over $124280d.
    touch_of_karma = {
        id = 122470,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        school = "physical",

        startsCombat = true,
        toggle = "defensives",

        usable = function ()
            return incoming_damage_3s >= health.max * ( settings.tok_damage or 20 ) / 100, "incoming damage not sufficient (" .. ( settings.tok_damage or 20 ) .. "% / 3 sec) to use"
        end,

        handler = function ()
            applyBuff( "touch_of_karma" )
            applyDebuff( "target", "touch_of_karma_debuff" )
        end,
    },

    -- Talent: Split your body and spirit, leaving your spirit behind for $d. Use Transcendence: Transfer to swap locations with your spirit.
    transcendence = {
        id = function() return talent.transcendence_linked_spirits.enabled and 434763 or 101643 end,
        known = 101643,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        school = "nature",

        talent = "transcendence",
        startsCombat = false,

        handler = function ()
            applyBuff( talent.transcendence_linked_spirits.enabled and "transcendence_tethered" or "transcendence" )
        end,

        copy = { 101643, 434763 }
    },


    transcendence_transfer = {
        id = 119996,
        cast = 0,
        cooldown = function () return buff.escape_from_reality.up and 0 or 45 end,
        gcd = "spell",

        startsCombat = false,
        texture = 237585,

        buff = function()
            return talent.transcendence_linked_spirits.enabled and "transcendence_tethered" or "transcendence"
        end,

        handler = function ()
            if buff.escape_from_reality.up then removeBuff( "escape_from_reality" )
            elseif talent.escape_from_reality.enabled or legendary.escape_from_reality.enabled then
                applyBuff( "escape_from_reality" )
            end
            if talent.healing_winds.enabled then gain( 0.15 * health.max, "health" ) end
            if talent.spirits_essence.enabled then applyDebuff( "target", "spirits_essence" ) end
        end,
    },

    -- Causes a surge of invigorating mists, healing the target for $s1$?s274586[ and all allies with your Renewing Mist active for $s2][].
    vivify = {
        id = 116670,
        cast = function() return buff.vivacious_vivification.up and 0 or 1.5 end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        spend = function() return buff.vivacious_vivification.up and 2 or 8 end,
        spendType = "energy",

        startsCombat = false,

        handler = function ()
            removeBuff( "vivacious_vivification" )
            removeBuff( "chi_wave" )
        end,
    },

    -- Talent: Performs a devastating whirling upward strike, dealing ${3*$158221s1} damage to all nearby enemies. Only usable while both Fists of Fury and Rising Sun Kick are on cooldown.
    whirling_dragon_punch = {
        id = 152175,
        cast = 0,
        cooldown = function() return talent.revolving_whirl.enabled and 19 or 24 end,
        gcd = "spell",
        school = "physical",

        talent = "whirling_dragon_punch",
        startsCombat = false,

        usable = function ()
            if settings.check_wdp_range and not action.fists_of_fury.in_range then return false, "target is out of range" end
            return cooldown.fists_of_fury.remains > 0 and cooldown.rising_sun_kick.remains > 0, "requires fists_of_fury and rising_sun_kick on cooldown"
        end,

        handler = function ()
            if talent.knowledge_of_the_broken_temple.enabled then addStack( "teachings_of_the_monastery", nil, 4 ) end
            if talent.revolving_whirl.enabled then addStack( "dance_of_chiji" ) end
        end,
    },

    -- You fly through the air at a quick speed on a meditative cloud.
    zen_flight = {
        id = 125883,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",

        startsCombat = false,

        handler = function ()
            applyBuff( "zen_flight" )
        end,
    },
} )

spec:RegisterRanges( "fists_of_fury", "strike_of_the_windlord" , "tiger_palm", "touch_of_karma", "crackling_jade_lightning" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 2,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageExpiration = 8,

    potion = "tempered_potion",

    package = "Windwalker",

    strict = false
} )

spec:RegisterSetting( "allow_fsk", false, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.abilities.flying_serpent_kick.id ) ),
    desc = strformat( "If unchecked, %s will not be recommended despite generally being used as a filler ability.\n\n"
            .. "Unchecking this option is the same as disabling the ability via |cFFFFD100Abilities|r > |cFFFFD100|W%s|w|r > |cFFFFD100|W%s|w|r > |cFFFFD100Disable|r.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.flying_serpent_kick.id ), spec.name, spec.abilities.flying_serpent_kick.name ),
    type = "toggle",
    width = "full",
    get = function () return not Hekili.DB.profile.specs[ 269 ].abilities.flying_serpent_kick.disabled end,
    set = function ( _, val )
        Hekili.DB.profile.specs[ 269 ].abilities.flying_serpent_kick.disabled = not val
    end
} )

spec:RegisterSetting( "sef_one_charge", false, {
    name = strformat( "%s: Reserve 1 Charge for Cooldowns Toggle", Hekili:GetSpellLinkWithTexture( spec.abilities.storm_earth_and_fire.id ) ),
    desc = strformat( "If checked, %s can be recommended while Cooldowns are disabled, as long as you will retain 1 remaining charge.\n\n"
            .. "If |W%s's|w |cFFFFD100Required Toggle|r is changed from |cFF00B4FFDefault|r, this feature is disabled.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.storm_earth_and_fire.id ), spec.abilities.storm_earth_and_fire.name ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "dynamic_strike_of_the_windlord", false, {
    name = strformat( "%s: Raid Cooldown", Hekili:GetSpellLinkWithTexture( spec.abilities.strike_of_the_windlord.id ) ),
    desc = strformat(
        "If checked, %s will require an active Minor Cooldowns toggle to be recommended in raid.\n\nThis feature ensures %s is only recommended when you are actively using cooldown abilities (e.g., add waves, burst windows).",
        Hekili:GetSpellLinkWithTexture( spec.abilities.strike_of_the_windlord.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.strike_of_the_windlord.id )
    ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "cjl_capacitor_toggle", "none", {
    name = strformat( "%s: Special Toggle", Hekili:GetSpellLinkWithTexture( spec.abilities.crackling_jade_lightning.id ) ),
    desc = strformat(
        "When %s is talented and the aura is active, %s will only be recommended if the selected toggle is active.\n\n" ..
        "This setting will be ignored if you have set %s's toggle in |cFFFFD100Abilities and Items|r.\n\n" ..
        "Select |cFFFFD100Do Not Override|r to disable this feature.",
        Hekili:GetSpellLinkWithTexture( spec.auras.the_emperors_capacitor.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.crackling_jade_lightning.id ),
        Hekili:GetSpellLinkWithTexture( spec.abilities.crackling_jade_lightning.id )
    ),
    type = "select",
    width = 2,
    values = function ()
        local toggles = {
            none       = "Do Not Override",
            default    = "Default |cffffd100(" .. ( spec.abilities.crackling_jade_lightning.toggle or "none" ) .. ")|r",
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

spec:RegisterSetting( "check_wdp_range", false, {
    name = strformat( "%s: Check Range", Hekili:GetSpellLinkWithTexture( spec.abilities.whirling_dragon_punch.id ) ),
    desc = strformat( "If checked, %s will not be recommended if your target is outside your %s range.", Hekili:GetSpellLinkWithTexture( spec.abilities.whirling_dragon_punch.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.fists_of_fury.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "check_sck_range", false, {
    name = strformat( "%s: Check Range", Hekili:GetSpellLinkWithTexture( spec.abilities.spinning_crane_kick.id ) ),
    desc = strformat( "If checked, %s will not be recommended if your target is outside your %s range.", Hekili:GetSpellLinkWithTexture( spec.abilities.spinning_crane_kick.id ), Hekili:GetSpellLinkWithTexture( spec.abilities.fists_of_fury.id ) ),
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "use_diffuse", false, {
    name = strformat( "%s: Self-Dispel", Hekili:GetSpellLinkWithTexture( spec.abilities.diffuse_magic.id ) ),
    desc = function()
        local m = strformat( "If checked, %s may be recommended when when you have a dispellable magic debuff.", Hekili:GetSpellLinkWithTexture( spec.abilities.diffuse_magic.id ) )

        local t = class.abilities.diffuse_magic.toggle
        if t then
            local active = Hekili.DB.profile.toggles[ t ].value
            m = m .. "\n\n" .. ( active and "|cFF00FF00" or "|cFFFF0000" ) .. "Requires " .. t:gsub("^%l", string.upper) .. " Toggle|r"
        end

        return m
    end,
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "tok_damage", 1, {
    name = strformat( "%s: Required Incoming Damage", Hekili:GetSpellLinkWithTexture( spec.abilities.touch_of_karma.id ) ),
    desc = strformat( "If set above zero, %s will only be recommended if you have taken this percentage of your maximum health in damage in the past 3 seconds.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.touch_of_karma.id ) ),
    type = "range",
    min = 0,
    max = 99,
    step = 0.1,
    width = "full"
} )

spec:RegisterPack( "Windwalker", 20250705, [[Hekili:fN12UTnot4NLGc420dEL8HwNc7CXEXITb72BCxS3zjAjABvll5LIkUUWqpw7lW(I9pKuhiPiLvYFb6fTjICMHdN5BoWjRCx9Lvldru8QppYz0uNp4mDO7SjJME3QL0ZhXRwEefShTf(Le0b4))7OKWtO49ycBRZXPOqMiYsZjbW2RwUopkM(PKvRBl3pmzMZeG2J4ay53dhXUOWqSGwCwWQLFzxuwHp7FOc)YtUWpDd8DanknPWpokJcBVjLu4)749rXrdxTKVitnqPy4hFMFRWjO1X4Wv)6QLbKikMeHG7ekgNqhgSlYBDojJoSIQLIdaOTARvuqjVMGi5z7Is269vui27eyBAlWwKWe8yRc(Mc)q868nBgsIYy8LLN4Tpky)W8JscvDpMiNyvKCPrJ2IjEhtpHjdZOGPTWFEH)4grwsak(atAtTknWav4F)Ic)rn8MDmkjHPqbeucUwLEFxcz4b03k8FxHFTaDBe4xrRzc4dpBbG)2rCS3oeHFBMXbhLBTogU9P5uHAkjEMlhaIBq5X0AyuZveJiGatc9YOKO9yvofqLkIZZWEGMEitJOXQ6rAAO3MCYznQMOqfMKHj7bJRgvtLPcrcygEAkHaWsnkT7gkrXrjpMUh79TCCsB8R0MD7sOiYwmD4omkMUB4XakhH56ibXsZd25LUXleJO7QDm2Ide42kE2d(sKsqG6wmXD31UP8OBc(u11SWFqj(zod)W)8vf(GdozpCxossdgI2czzONhsWi2D6YfT9b4aozlCLLiqkKtGwYQ29wTunGYW0CWmD9Wx8zSq7ldG5yEhXj()RwFl)U39zntlBrfn8lGEs3uWtLHPnS8icUoWUSFloh(HRId65R8Cr7jQpvsMx25Kap2j)iMRD2ZKliYdNGpeHZ0ZkgGIJ9eF4XkZik2uEyIIeU2tMRlBMrSVcNvlJNrkJ2RAAwlf1GX5zT5FwfD1MjLQmMkDD1AImy9j0JyZ1wz70DfWsX8DCIx2XDakt5IaAofYBZZhwj3gs7Uqi4hiBpd47dSuLE86h3x4pTkSxoradZjONdjM4Oe6Y3j67mJtvaG9kMDvsxCqw2MGpGIsAHjnu83Ek(Uk(3kxLGclhRAdc2Rdy7exWpXbDAmguz0B5KgPcJL0RnSU)yLb4Ls7SOsj0IRw1jM1ct6STcgcUbPzVCJz5WpcT6JZCS10shLe6q8vyw2ktCA1rvR00pHsKGeDSu9YEsbURoi9W6ug1i4HdERtvBMvTHSUZOAqC0JvqNoqYGUFNnOSR9mgAPnnHnNxVRLRAy6PKUUSknYPhBR2jNBNDulRPplDbk2CKGzCHm0amfLeGzXz0DyVnry4bFECdPPoHVkcRhV(6QLi0HQMbNkTthJ3IcoxDloTdKOXlHE28R3nJtpAdr39DDPwI4i4Ty41VVgIYhov(Ge77X3ha9PXScJuHV8eIWEuwg7D1WZOJoCmLqlF78lH2lEzHpb)p5rewqEw6bGguon9a8S9qwipkzlKES4H)ikb2Y9Jf()vsw(rMuyei0zqu1oTxwt8iRe3QNIgMgBNj1OIgwMyLLMq8gQNALAdpGTHT3BLniPAdzFWkzn51BOEMvQvIkzmW9EBsJJtb71wMtIGGCAqcoyD4PMaZraJugzvsH1ijllaTIUKuURpprH6WqgXHikAnkd)XIh4Lu0m3LRkLyfw5bdykab8dcs1bkXo0QQ9Y(GOAAzSpGjT296dIYkK1oAYeK1oOsPTN(GRA6DPH67EsywxN(fj4ELCfkMqx7o0wrcLCy3TAYe6A3VA7aEgUvx7(1F(b0TAeW460JDg)3kMS35fkNP2pQKdTgfxFcUKgJvFIUuhvvFcVuNgvFcXmelypatzGl)uarkJZsETkTQAnfdHfirDFM)WafwBpTVLo0AHXEsM2(n7zyS2VjJ5Ih(0HkoMO6LyxzOTWC6UuO10F7)(xYJreccfYArpDteRfXx8Ic))mnzpC4n)zzysviOSH1g53S4xSBFmtFTf5TrBwyRX9oyfSp6Ck)OsJmA1yzM8QMLFlRv4fgA5(T8MOx40h2n1iDj)Y9G)AO)BjtmZWQNnsEZ6)qaYl2m4FLvRh0V8QQd2xEhPeAsgAdJYxMj10Ac(0MA)CxhJCWJMzCCJ55YlZupqadGfMVWDWRSp43lx6yOVxUyBg73QO(YjOyQJTjCF)cxNlxEUAZTdSl3zY6tFXSUCt3ZtzuXN6dzwCYI4AXrwnF65JVoFWZgBZ49lglN2jJfD1QBbjSG1rvZaf3Vy0GBSoCATtPQLFnGM84N14OPXFjEApR5b3uoLzn21EjatgThk09th8kb8(YfXUZN4CRUbsTjlEKL1jJE5s3JiwY1jKEtJWQGE5rYoFSsqKYiZAjqLNByxMlgpW6LyGbl1iHlx)0AERIKxY4yBhuol03XLJRU7Q(vmm5Os6aPCEZC0yeEpJboexG7xmrN8EMWBHoFkpnO2QAACPx3)AyQOdS6ExC310KYqX2(S5WQDmEXUH598u7u(nYaYg9MNCRkcMEw5NAjKNsmSoZ9levNldtQQXUPtSruSorDfJOtB7jgV6)n]] )