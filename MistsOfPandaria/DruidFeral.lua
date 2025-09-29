-- DruidFeral.lua
--july 2025 by smufrik
-- DruidFeral.lua loading

-- MoP: Use UnitClass instead of UnitClassBase

local _, playerClass = UnitClass('player')
if playerClass ~= 'DRUID' then 
    -- Not a druid, exiting DruidFeral.lua
    return 
end
-- Druid detected, continuing DruidFeral.lua loading

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

local spec = Hekili:NewSpecialization(103, true)

spec.name = "Feral"
spec.role = "DAMAGER"
spec.primaryStat = 2 -- Agility

-- Use MoP power type numbers instead of Enum
-- Energy = 3, ComboPoints = 4, Rage = 1, Mana = 0 in MoP Classic
spec:RegisterResource( 3 ) -- Energy
spec:RegisterResource( 4 ) -- ComboPoints 
spec:RegisterResource( 1 ) -- Rage
spec:RegisterResource( 0 ) -- Mana


-- Add reset_precast hook for state management and form checking
spec:RegisterHook( "reset_precast", function()
    -- Set safe default values to avoid errors
    local current_form = GetShapeshiftForm() or 0
    local current_energy = -1
    local current_cp = -1
    
    -- Safely access resource values using the correct state access pattern
    if state.energy then
        current_energy = state.energy.current or -1
    end
    if state.combo_points then
        current_cp = state.combo_points.current or -1
    end
    
    -- Fallback to direct API calls if state resources are not available
    if current_energy == -1 then
        current_energy = UnitPower("player", 3) or 0 -- Energy = power type 3
    end
    if current_cp == -1 then
        current_cp = UnitPower("player", 4) or 0 -- ComboPoints = power type 4
    end
    
    local cat_form_up = "nej"

    -- Hantera form-buffen
    if current_form == 3 then -- Cat Form
        applyBuff( "cat_form" )
        cat_form_up = "JA"
    else
        removeBuff( "cat_form" )
    end
    
    -- Removed workaround sync - testing core issue
end )

-- Additional debugging hook for when recommendations are generated
spec:RegisterHook( "runHandler", function( ability )
    -- Only log critical issues
    if not ability then
        -- Nil ability passed to runHandler
        return
    end
end )

-- Debug hook to check state at the beginning of each update cycle
spec:RegisterHook( "reset", function()
    -- Minimal essential verification
    if not state or not state.spec or state.spec.id ~= 103 then
        return
    end
    
    -- Basic state verification - level check
    if level and level < 10 then
        return
    end
end )

-- Talents - MoP compatible talent structure
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility
    feline_swiftness               = { 1, 1, 131768 }, -- Increases movement speed by 15%.
    displacer_beast                = { 1, 2, 102280 }, -- Teleports you forward and shifts you into Cat Form, removing all snares.
    wild_charge                    = { 1, 3, 102401 }, -- Grants a movement ability based on your form.

    -- Tier 2 (Level 30) - Healing/Utility
    yseras_gift                    = { 2, 1, 145108 }, -- Heals you for 5% of your maximum health every 5 seconds.
    renewal                        = { 2, 2, 108238 }, -- Instantly heals you for 30% of your maximum health.
    cenarion_ward                  = { 2, 3, 102351 }, -- Protects a friendly target, healing them when they take damage.

    -- Tier 3 (Level 45) - Crowd Control
    faerie_swarm                   = { 3, 1, 102355 }, -- Reduces the target's movement speed and prevents stealth.
    mass_entanglement              = { 3, 2, 102359 }, -- Roots all enemies within 12 yards of the target in place for 20 seconds.
    typhoon                        = { 3, 3, 132469 }, -- Strikes targets in front of you, knocking them back and dazing them.

    -- Tier 4 (Level 60) - Specialization Enhancement
    soul_of_the_forest             = { 4, 1, 102543 }, -- Finishing moves grant 4 Energy per combo point spent and increase damage.
    incarnation_king_of_the_jungle = { 4, 2, 114107 }, -- Improved Cat Form for 30 sec, allowing all abilities and reducing energy cost.
    force_of_nature                = { 4, 3, 106737 }, -- Summons treants to attack your enemy.

    -- Tier 5 (Level 75) - Disruption
    disorienting_roar              = { 5, 1, 99 },      -- Causes all enemies within 10 yards to become disoriented for 3 seconds.
    ursols_vortex                  = { 5, 2, 108292 },  -- Creates a vortex that pulls and roots enemies.
    mighty_bash                    = { 5, 3, 5211 },    -- Stuns the target for 5 seconds.

    -- Tier 6 (Level 90) - Major Enhancement
    heart_of_the_wild              = { 6, 1, 102793 }, -- Dramatically improves your ability to tank, heal, or deal spell damage for 45 sec.
    dream_of_cenarius              = { 6, 2, 108373 }, -- Increases healing or causes your next healing spell to increase damage.
    natures_vigil                  = { 6, 3, 124974 }, -- Increases all damage and healing done, and causes all single-target healing and damage spells to also heal a nearby friendly target.
} )



-- Ticks gained on refresh (MoP version).
local tick_calculator = setfenv( function( t, action, pmult )
    local state = _G["Hekili"] and _G["Hekili"].State or {}
    local remaining_ticks = 0
    local potential_ticks = 0
    local remains = t.remains
    local tick_time = t.tick_time
    local ttd = min( state.fight_remains or 300, state.target and state.target.time_to_die or 300 )

    local aura = action
    if action == "primal_wrath" then aura = "rip" end

    local class = _G["Hekili"] and _G["Hekili"].Class or {}
    local duration_field = class.auras and class.auras[ aura ] and class.auras[ aura ].duration or 0
    local duration = type( duration_field ) == "function" and duration_field() or duration_field
    local app_duration = min( ttd, duration )
    local app_ticks = app_duration / tick_time

    remaining_ticks = min( remains, ttd ) / tick_time
    duration = max( 0, min( remains + duration, 1.3 * duration, ttd ) )
    potential_ticks = min( duration, ttd ) / tick_time

    if action == "thrash" then aura = "thrash" end

    return max( 0, potential_ticks - remaining_ticks )
end, {} )

-- Auras
spec:RegisterAuras( {
    faerie_fire = {
        id = 770, -- Faerie Fire (unified in MoP)
        duration = 300, 
        max_stack = 1,
        name = "Faerie Fire",
    },

    mangle = {
        id = 33876, -- Mangle (Cat) debuff
        duration = 60,
        max_stack = 1,
        name = "Mangle",
    },

    jungle_stalker = {
        duration = 15,
        max_stack = 1,
    },


    savage_roar = {
        id = 52610,
        copy = { 127568, 127538, 127539, 127540, 127541 },
        duration = function() return 12 + (combo_points.current * 6) end, -- MoP: 12s + 6s per combo point
        max_stack = 1,
    },
    rejuvenation = {
        id = 774,
        duration = 12,
        type = "Magic",
        max_stack = 1,
    },
    -- Engineering: Synapse Springs (Agi tinker) for FoN alignment
    synapse_springs = {
        id = 96228,
        duration = 10,
        max_stack = 1,
    },
    -- Dream of Cenarius damage bonus (used by APL sequences)
    dream_of_cenarius_damage = {
        id = 145152,
        duration = 30,
        max_stack = 1,
    },
    armor = {
        alias = { "faerie_fire" },
        aliasMode = "first",
        aliasType = "debuff",
        duration = 300,
        max_stack = 1,
    },
    mark_of_the_wild = {
        id = 1126,

        duration = 3600,
        max_stack = 1,
    },
    leader_of_the_pack = {
        id = 24932,

        duration = 3600,
        max_stack = 1,
    },
    champion_of_the_guardians_of_hyjal = {
        id = 93341,

        duration = 3600,
        max_stack = 1,
    },
    -- MoP/Classic aura IDs and durations

    aquatic_form = {
        id = 1066,

        duration = 3600,
        max_stack = 1,
    },
    bear_form = {
        id = 5487,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    berserk = {
        id = 106951,
        duration = 15,
        max_stack = 1,
        copy = { 106951, "berserk_cat" },
        multiplier = 1.5,
    },

    incarnation_king_of_the_jungle = {
        id = 114107,
        duration = 30,
        max_stack = 1,
        copy = { "incarnation" },
    },
    -- Bloodtalons removed (not in MoP)
    cat_form = {
        id = 768,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    cenarion_ward = {
        id = 102351,
        duration = 30,
        max_stack = 1
    },
    clearcasting = {
        id = 135700,

        duration = 15,
        type = "Magic",
        max_stack = 1,
        multiplier = 1,
    },
    dash = {
        id = 1850,

        duration = 15,
        type = "Magic",
        max_stack = 1
    },
    entangling_roots = {
        id = 339,
        duration = 30,
        mechanic = "root",
        type = "Magic",
        max_stack = 1
    },
    frenzied_regeneration = {
        id = 22842,
        duration = 6,
        max_stack = 1,
    },
    growl = {
        id = 6795,
        duration = 3,
        mechanic = "taunt",
        max_stack = 1
    },
    heart_of_the_wild = {
        id = 108292,
        duration = 45,
        type = "Magic",
        max_stack = 1,
    },
    hibernate = {
        id = 2637,
        duration = 40,
        mechanic = "sleep",
        type = "Magic",
        max_stack = 1
    },
    incapacitating_roar = {
        id = 99,
        duration = 3,
        mechanic = "incapacitate",
        max_stack = 1
    },
    infected_wounds = {
        id = 58180,
        duration = 12,
        type = "Disease",
        max_stack = 1,
    },
    innervate = {
        id = 29166,
        duration = 10,
        type = "Magic",
        max_stack = 1
    },
    ironfur = {
        id = 192081,
        duration = 7,
        type = "Magic",
        max_stack = 1
    },
    maim = {
        id = 22570,
        duration = function() return 1 + combo_points.current end,
        max_stack = 1,
    },
    mass_entanglement = {
        id = 102359,
        duration = 20,
        tick_time = 2.0,
        mechanic = "root",
        type = "Magic",
        max_stack = 1
    },
    mighty_bash = {
        id = 5211,
        duration = 5,
        mechanic = "stun",
        max_stack = 1
    },
    moonfire = {
        id = 8921,

        duration = 16,
        tick_time = 2,
        type = "Magic",
        max_stack = 1
    },
    moonkin_form = {
        id = 24858,
        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    predatory_swiftness = {
        id = 69369,
        duration = 8,
        type = "Magic",
        max_stack = 1,
    },
    natures_swiftness = {
        id = 132158,
        duration = 10,
        type = "Magic",
        max_stack = 1,
    },
    prowl_base = {
        id = 5215,

        duration = 3600,
        max_stack = 1,
        multiplier = 1.6,
    },
    prowl = {
        alias = { "prowl_base" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3600,
        max_stack = 1
    },
    rake = {
        id = 1822, -- Correct Rake ID for MoP
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
        copy = "rake_debuff",
    },
    regrowth = {
        id = 8936,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    rejuvenation_germination = {
        id = 155777,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    rip = {
        id = 1079,

        duration = function () return 4 + ( combo_points.current * 4 ) end,
        tick_time = 2,
        mechanic = "bleed",
        max_stack = 1,
    },
    shadowmeld = {
        id = 58984,
        duration = 10,
        max_stack = 1,
    },
    sunfire = {
        id = 93402,
        duration = 12,
        type = "Magic",
        max_stack = 1
    },
    survival_instincts = {
        id = 61336,
        duration = 6,
        max_stack = 1
    },
    thrash = {
        id = 106830,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
        copy = {77758},
    },

    thrash_cat = {
        id = 106830,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 1,
    },
    tiger_dash = {
        id = 252216,
        duration = 5,
        type = "Magic",
        max_stack = 1
    },
    tigers_fury = {
        id = 5217,

        duration = 8, -- MoP: 8s duration
        multiplier = 1.15,
    },
    travel_form = {
        id = 783,

        duration = 3600,
        type = "Magic",
        max_stack = 1
    },
    stag_form = {
        id = 165962, -- Stag Form spell ID (MoP)
        duration = 3600,
        type = "Magic",
        max_stack = 1,
    },
    typhoon = {
        id = 61391,
        duration = 6,
        type = "Magic",
        max_stack = 1
    },
    ursols_vortex = {
        id = 102793,
        duration = 10,
        type = "Magic",
        max_stack = 1
    },
    wild_charge = {
        id = 102401,
        duration = 0.5,
        max_stack = 1
    },
    wild_growth = {
        id = 48438,
        duration = 7,
        type = "Magic",
        max_stack = 1
    },
    weakened_blows = {
        id = 115767,
        duration = 30,
        max_stack = 1,
        type = "debuff",
        unit = "target",
    },
    challenging_roar = {
        id = 5209,
        duration = 6,
        name = "Challenging Roar",
        max_stack = 1,
    },

    -- Bear-Weaving and Wrath-Weaving auras
    lacerate = {
        id = 33745,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 3,
    },

    -- Bear Form specific auras
    bear_form_weaving = {
        duration = 3600,
        max_stack = 1,
    },
} )

-- Move the spell ID mapping to after all registrations are complete

-- Tweaking for new Feral APL.
local rip_applied = false

spec:RegisterEvent( "PLAYER_REGEN_ENABLED", function ()
    rip_applied = false
end )

-- Event handler to ensure Feral spec is enabled  
spec:RegisterEvent( "PLAYER_ENTERING_WORLD", function ()
    if state.spec.id == 103 then
        -- Ensure the spec is enabled in the profile
        if Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.specs then
            if not Hekili.DB.profile.specs[103] then
                Hekili.DB.profile.specs[103] = {}
            end
            Hekili.DB.profile.specs[103].enabled = true
            
            -- Set default package if none exists
            if not Hekili.DB.profile.specs[103].package then
                Hekili.DB.profile.specs[103].package = "Feral"
            end
        end
    end
end )

--[[spec:RegisterStateExpr( "opener_done", function ()
    return rip_applied
end )--]]

-- Bloodtalons combat log and state tracking removed for MoP

spec:RegisterStateFunction( "break_stealth", function ()
    removeBuff( "shadowmeld" )
    if buff.prowl.up then
        setCooldown( "prowl", 6 )
        removeBuff( "prowl" )
    end
end )

-- Function to remove any form currently active.
spec:RegisterStateFunction( "unshift", function()
    if conduit.tireless_pursuit and conduit.tireless_pursuit.enabled and ( buff.cat_form.up or buff.travel_form.up ) then applyBuff( "tireless_pursuit" ) end

    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "travel_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )

    -- MoP: No Oath of the Elder Druid legendary or Restoration Affinity in MoP.
end )

local affinities = {
    bear_form = "guardian_affinity",
    cat_form = "feral_affinity",
    moonkin_form = "balance_affinity",
}

-- Function to apply form that is passed into it via string.
spec:RegisterStateFunction( "shift", function( form )
    -- MoP: No tireless_pursuit or wildshape_mastery in MoP.
    removeBuff( "cat_form" )
    removeBuff( "bear_form" )
    removeBuff( "travel_form" )
    removeBuff( "moonkin_form" )
    removeBuff( "aquatic_form" )
    removeBuff( "stag_form" )
    applyBuff( form )
    -- MoP: No Oath of the Elder Druid legendary or Restoration Affinity in MoP.
end )



spec:RegisterHook( "runHandler", function( ability )
    local a = class.abilities[ ability ]

    if not a or a.startsCombat then
        break_stealth()
    end
end )

spec:RegisterHook( "gain", function( amt, resource, overflow )
    if overflow == nil then overflow = true end
    if amt > 0 and resource == "combo_points" then
    end

end )





local combo_generators = {
    rake              = true,
    shred             = true,
    swipe_cat         = true,
    thrash_cat        = true,
    mangle_cat        = true,
    lacerate          = true,
    maul              = true,
    thrash_bear       = true,
    mangle_bear       = true,
    lacerate_bear     = true,
    maul_bear         = true
}



spec:RegisterStateTable( "druid", setmetatable( {},{
    __index = function( t, k )
        if k == "catweave_bear" then return false
        elseif k == "owlweave_bear" then return false
        elseif k == "owlweave_cat" then
            return false -- MoP: No Balance Affinity
        elseif k == "no_cds" then return not toggle.cooldowns
        -- MoP: No Primal Wrath or Lunar Inspiration
        elseif k == "primal_wrath" then return false
        elseif k == "lunar_inspiration" then return false
        elseif k == "delay_berserking" then return state.settings.delay_berserking
        elseif debuff[ k ] ~= nil then return debuff[ k ]
        end
    end
} ) )

-- MoP: Bleeding only considers Rake, Rip, and Thrash (no Thrash Bear for Feral).
spec:RegisterStateExpr( "bleeding", function ()
    return debuff.rake.up or debuff.rip.up or debuff.thrash.up
end )

-- MoP: Effective stealth is only Prowl or Incarnation (no Shadowmeld for snapshotting in MoP).
spec:RegisterStateExpr( "effective_stealth", function ()
    return buff.prowl.up or ( buff.incarnation and buff.incarnation.up )
end )

-- Essential state expressions for APL functionality
spec:RegisterStateExpr( "time_to_die", function ()
    return target.time_to_die or 300
end )

spec:RegisterStateExpr( "spell_targets", function ()
    return active_enemies or 1
end )



spec:RegisterStateExpr( "energy_deficit", function ()
    return energy.max - energy.current
end )

spec:RegisterStateExpr( "energy_time_to_max", function ()
    return energy.deficit / energy.regen
end )

spec:RegisterStateExpr( "cp_max_spend", function ()
    return combo_points.current >= 5 or ( combo_points.current >= 4 and buff.savage_roar.remains < 2 )
end )

spec:RegisterStateExpr( "time_to_pool", function ()
    local deficit = energy.max - energy.current
    if deficit <= 0 then return 0 end
    return deficit / energy.regen
end )

-- Advanced energy pooling system based on WoWSims pooling_actions.go
-- Calculate floating energy needed for upcoming ability refreshes
spec:RegisterStateExpr( "floating_energy", function()
    local floatingEnergy = 0
    local currentTime = query_time or 0
    local regenRate = energy.regen or 10
    
    -- Pooling actions that need energy in the near future
    local poolingActions = {}
    
    -- Add Rake refresh (35 energy, refresh when < 4.5s remaining)
    if debuff.rake.up and debuff.rake.remains < 8 then
        local refreshTime = debuff.rake.remains
        table.insert(poolingActions, {refreshTime = refreshTime, cost = 35})
    end
    
    -- Add Rip refresh (20 energy, refresh when < 4s remaining) 
    if debuff.rip.up and debuff.rip.remains < 6 then
        local refreshTime = debuff.rip.remains
        table.insert(poolingActions, {refreshTime = refreshTime, cost = 20})
    end
    
    -- Add Savage Roar refresh (25 energy, refresh when < 1s remaining)
    if buff.savage_roar.up and buff.savage_roar.remains < 3 then
        local refreshTime = buff.savage_roar.remains
        table.insert(poolingActions, {refreshTime = refreshTime, cost = 25})
    end
    
    -- Sort actions by refresh time
    table.sort(poolingActions, function(a, b) return a.refreshTime < b.refreshTime end)
    
    -- Calculate floating energy needed
    local previousTime = 0
    local tfPending = false
    
    for _, action in ipairs(poolingActions) do
        local elapsedTime = action.refreshTime - previousTime
        local energyGain = elapsedTime * regenRate
        
        -- Check if Tiger's Fury will be available before this refresh
        if not tfPending and cooldown.tigers_fury.remains <= action.refreshTime then
            tfPending = true
            action.cost = action.cost - 60 -- Tiger's Fury gives 60 energy
        end
        
        if energyGain < action.cost then
            floatingEnergy = floatingEnergy + (action.cost - energyGain)
            previousTime = action.refreshTime
        else
            previousTime = previousTime + (action.cost / regenRate)
        end
    end
    
    return floatingEnergy
end )

-- Check if we should pool energy for upcoming refreshes (based on SimC pool input)
spec:RegisterStateExpr( "should_pool_energy", function()
    local poolLevel = state.settings.pool or 0 -- 0=no pooling, 1=light, 2=heavy
    
    if poolLevel == 0 then
        return false -- No pooling
    end
    
    -- Never pool when we have combo points to spend
    if combo_points.current >= 1 then
        return false
    end
    
    -- Simple pooling logic - let pool_resource handle the actual pooling
    return true
end )

-- Next refresh time for energy pooling decisions
spec:RegisterStateExpr( "next_refresh_time", function()
    local nextTime = 999
    
    -- Find the earliest refresh time
    if debuff.rake.up and debuff.rake.remains < 8 and debuff.rake.remains < nextTime then
        nextTime = debuff.rake.remains
    end
    if debuff.rip.up and debuff.rip.remains < 6 and debuff.rip.remains < nextTime then
        nextTime = debuff.rip.remains
    end
    if buff.savage_roar.up and buff.savage_roar.remains < 3 and buff.savage_roar.remains < nextTime then
        nextTime = buff.savage_roar.remains
    end
    
    return nextTime < 999 and nextTime or 0
end )

-- Energy efficiency calculations for pooling decisions
spec:RegisterStateExpr( "energy_efficiency", function()
    -- Calculate how efficiently we're using energy
    local currentEfficiency = energy.current / energy.max
    local poolingThreshold = floating_energy / energy.max
    
    -- Return efficiency score (0-1, higher is better)
    if floating_energy == 0 then return 1 end
    return math.min(1, currentEfficiency / poolingThreshold)
end )

-- Check if we're in a pooling phase (holding energy for upcoming refreshes)
spec:RegisterStateExpr( "in_pooling_phase", function()
    return should_pool_energy and next_refresh_time > 0 and next_refresh_time < 8
end )

-- Advanced Ferocious Bite conditions based on WoWSims canBite() logic
spec:RegisterStateExpr( "can_bite", function()
    local isExecutePhase = target.health.pct <= 25
    local biteTime = buff.berserk.up and 6 or 11 -- BerserkBiteTime vs BiteTime
    
    -- Must have enough Savage Roar duration
    if buff.savage_roar.remains < biteTime then
        return false
    end
    
    -- In execute phase: allow if we have a better snapshot or during berserk
    if isExecutePhase then
        return (rip_damage_increase_pct > 0.001) or buff.berserk.up
    end
    
    -- Normal phase: ensure Rip has enough duration
    return debuff.rip.remains >= biteTime
end )

-- Rip break-even threshold calculation (based on WoWSims calcRipEndThresh)
spec:RegisterStateExpr( "rip_end_threshold", function()
    if combo_points.current < 5 then
        return 0 -- Can't cast Rip without 5 CPs
    end
    
    -- Calculate break-even point between Rip and Ferocious Bite
    local expectedBiteDPE = 1.0 -- Simplified - would need actual damage calculations
    local expectedRipTickDPE = 0.3 -- Simplified - would need actual damage calculations
    local numTicksToBreakEven = 1 + math.ceil(expectedBiteDPE / expectedRipTickDPE)
    
    -- Return minimum Rip duration needed to be worth casting
    return numTicksToBreakEven * 2 -- Assuming 2s tick time
end )

-- Savage Roar clipping logic (based on WoWSims clipRoar)
spec:RegisterStateExpr( "should_clip_roar", function()
    local isExecutePhase = target.health.pct <= 25
    local ripRemaining = debuff.rip.remains or 0
    local simTimeRemaining = target.time_to_die or 300
    
    -- Don't clip if no Rip or fight ending soon
    if not debuff.rip.up or (simTimeRemaining - ripRemaining < rip_end_threshold) then
        return false
    end
    
    -- Project Rip end time with Shred extensions
    local remainingExtensions = 12 - 6 -- maxRipTicks - currentTickCount (simplified)
    local ripDur = ripRemaining + (remainingExtensions * 2) -- Assuming 2s tick time
    local roarDur = buff.savage_roar.remains or 0
    
    -- Don't clip if Roar already covers Rip duration + leeway
    if roarDur > (ripDur + 1) then -- 1s leeway
        return false
    end
    
    -- Don't clip if roar covers rest of fight
    if roarDur >= simTimeRemaining then
        return false
    end
    
    -- Calculate new Roar duration with current CPs
    local newRoarDur = combo_points.current * 6 + 6 -- Simplified calculation
    
    -- If new roar covers rest of fight, clip now for CP efficiency
    if newRoarDur >= simTimeRemaining then
        return true
    end
    
    -- Don't clip if waiting one more GCD would be more efficient
    if newRoarDur + 1.5 + (combo_points.current < 5 and 5 or 0) >= simTimeRemaining then
        return false
    end
    
    -- Execute phase: optimize for minimal Roar casts
    if isExecutePhase then
        if combo_points.current < 5 then return false end
        local minRoarsPossible = math.ceil((simTimeRemaining - roarDur) / newRoarDur)
        local projectedRoarCasts = math.ceil(simTimeRemaining / newRoarDur)
        return projectedRoarCasts == minRoarsPossible
    end
    
    -- Normal phase: clip if new roar expires well after current rip
    return newRoarDur >= (ripDur + 30) -- 30s offset
end )

-- Tiger's Fury timing prediction (based on WoWSims tfExpectedBefore)
-- Removed duplicate - using StateFunction version below

-- Builder DPE calculation (based on WoWSims calcBuilderDpe)
spec:RegisterStateExpr( "rake_vs_shred_dpe", function()
    -- Simplified DPE comparison - in real implementation would need actual damage calculations
    local rakeDPE = 1.0 -- Would calculate: (initial_damage + tick_damage * potential_ticks) / energy_cost
    local shredDPE = 0.8 -- Would calculate: expected_damage / energy_cost
    
    return rakeDPE > shredDPE
end )

-- Energy threshold with latency consideration (based on WoWSims calcTfEnergyThresh)
spec:RegisterStateExpr( "tf_energy_threshold", function()
    local reaction_time = 0.1
    local delay_time = reaction_time
    if buff.clearcasting.up then
        delay_time = delay_time + 1.0
    end
    return 40 - ( delay_time * energy.regen )
end )

-- Cat Excess Energy calculation (based on WoWSims APLValueCatExcessEnergy)
spec:RegisterStateExpr( "cat_excess_energy", function()
    local floatingEnergy = 0
    local simTimeRemain = target.time_to_die or 300
    local regenRate = energy.regen or 10
    local currentTime = query_time or 0
    
    -- Create pooling actions array (enhanced version of WoWSims PoolingActions)
    local poolingActions = {}
    
    -- Rip refresh (if active and will expire before fight end, and we have 5 CPs)
    if debuff.rip.up and debuff.rip.remains < (simTimeRemain - 10) and combo_points.current == 5 then
        local ripCost = tf_expected_before( debuff.rip.remains ) and 10 or 20 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = debuff.rip.remains, cost = ripCost})
    end
    
    -- Rake refresh (if active and will expire before fight end)
    if debuff.rake.up and debuff.rake.remains < (simTimeRemain - 9) then -- Rake duration is ~9s
        local rakeCost = tf_expected_before( debuff.rake.remains ) and 17.5 or 35 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = debuff.rake.remains, cost = rakeCost})
    end
    
    -- Mangle refresh (if bleed aura will expire - represented by Rake being down/expiring)
    if not debuff.rake.up or debuff.rake.remains < (simTimeRemain - 1) then
        local mangleCost = tf_expected_before( debuff.rake.remains or 0 ) and 20 or 40 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = (debuff.rake.remains or 0), cost = mangleCost})
    end
    
    -- Savage Roar refresh (if active)
    if buff.savage_roar.up then
        local roarCost = tf_expected_before( buff.savage_roar.remains ) and 12.5 or 25 -- 50% cost during TF
        table.insert(poolingActions, {refreshTime = buff.savage_roar.remains, cost = roarCost})
    end
    
    -- Sort actions by refresh time (earliest first)
    table.sort(poolingActions, function(a, b) return a.refreshTime < b.refreshTime end)
    
    -- Calculate floating energy needed (enhanced algorithm from WoWSims)
    local previousTime = currentTime
    local tfPending = false
    
    for _, action in ipairs(poolingActions) do
        local elapsedTime = action.refreshTime - previousTime
        local energyGain = elapsedTime * regenRate
        
        -- Check if Tiger's Fury will be available before this refresh
        if not tfPending and tf_expected_before( action.refreshTime ) then
            tfPending = true
            action.cost = action.cost - 60 -- Tiger's Fury gives 60 energy
        end
        
        if energyGain < action.cost then
            floatingEnergy = floatingEnergy + (action.cost - energyGain)
            previousTime = action.refreshTime
        else
            previousTime = previousTime + (action.cost / regenRate)
        end
    end
    
    return energy.current - floatingEnergy
end )

-- New Savage Roar Duration based on combo points (based on WoWSims SavageRoarDurationTable)
spec:RegisterStateExpr( "new_savage_roar_duration", function()
    -- Savage Roar duration table from WoWSims: [0, 18, 24, 30, 36, 42] seconds
    -- Glyphed: [12, 18, 24, 30, 36, 42] seconds
    local isGlyphed = false -- Would need to check for glyph in real implementation
    local durationTable = {0, 18, 24, 30, 36, 42}
    if isGlyphed then
        durationTable = {12, 18, 24, 30, 36, 42}
    end
    
    local cp = math.min(combo_points.current, 5)
    return durationTable[cp + 1] or 42
end )

-- Savage Roar pandemic effect calculation (based on WoWSims tick tracking)
spec:RegisterStateExpr( "savage_roar_pandemic_duration", function()
    if not buff.savage_roar.up then
        return new_savage_roar_duration
    end
    
    local currentRemaining = buff.savage_roar.remains or 0
    local newDuration = new_savage_roar_duration
    
    -- Pandemic effect: can extend duration up to 130% of base duration
    local maxExtension = newDuration * 1.3
    local pandemicDuration = math.min(currentRemaining + newDuration, maxExtension)
    
    return pandemicDuration
end )

-- Check if we should clip Savage Roar for pandemic optimization
spec:RegisterStateExpr( "should_clip_roar_pandemic", function()
    if not buff.savage_roar.up then return true end
    
    local currentRemaining = buff.savage_roar.remains or 0
    local newDuration = new_savage_roar_duration
    
    -- Clip if we're within 1 tick (3 seconds) of pandemic threshold
    local pandemicThreshold = newDuration * 0.3
    return currentRemaining <= pandemicThreshold + 3
end )

-- Expected Swipe Damage calculation (based on WoWSims calcExpectedSwipeDamage)
spec:RegisterStateExpr( "expected_swipe_damage", function()
    -- Simplified calculation - would need actual damage formulas
    local baseSwipeDamage = 100 -- Base damage per target
    local swipeDamage = baseSwipeDamage * active_enemies
    local swipeDPE = swipeDamage / 45 -- Assuming 45 energy cost
    
    return swipeDamage
end )

-- Expected Swipe DPE calculation (separate for cleaner access)
spec:RegisterStateExpr( "expected_swipe_dpe", function()
    local baseSwipeDamage = 100 -- Base damage per target
    local swipeDamage = baseSwipeDamage * active_enemies
    local swipeDPE = swipeDamage / 45 -- Assuming 45 energy cost
    
    return swipeDPE
end )

-- Roar vs Swipe DPE comparison (based on WoWSims AoE rotation logic)
spec:RegisterStateExpr( "roar_vs_swipe_dpe", function()
    if combo_points.current < 1 then return false end
    
    -- Calculate Roar DPE
    local baseAutoDamage = 50 -- Simplified auto attack damage
    local buffEnd = math.min(target.time_to_die or 300, new_savage_roar_duration)
    local numBuffedAutos = 1 + math.floor(buffEnd / 2) -- Assuming 2s auto attack speed
    local roarMultiplier = 1.4 -- Savage Roar multiplier
    local roarDPE = ((roarMultiplier - 1) * baseAutoDamage * numBuffedAutos) / 25 -- Assuming 25 energy cost
    
    -- Get Swipe DPE
    local swipeDPE = expected_swipe_dpe
    
    return roarDPE >= swipeDPE
end )

-- Multi-target Rake target selection (based on WoWSims AoE rotation)
spec:RegisterStateExpr( "best_rake_target", function()
    -- Simplified - would need to track multiple targets
    -- For now, just return current target if Rake is down or expiring
    if not debuff.rake.up or debuff.rake.remains < 4.5 then
        return true
    end
    
    return false
end )

-- AoE bear weave energy threshold
spec:RegisterStateExpr( "aoe_bear_weave_energy", function()
    local swipeCost = 45 -- Swipe Cat cost
    local bearShiftCost = 0 -- No energy cost to shift forms
    local totalCost = swipeCost + bearShiftCost
    
    -- Pool energy for bear weave if we have excess
    return energy.current > totalCost + 20 -- 20 energy buffer
end )

-- Thrash AoE efficiency (based on WoWSims bear AoE rotation)
spec:RegisterStateExpr( "thrash_aoe_efficient", function()
    -- Thrash is more efficient than other bear abilities for AoE
    -- In bear form, Thrash is the primary AoE ability
    return active_enemies >= 3 and buff.bear_form.up
end )

-- Sophisticated bleed refresh timing (based on WoWSims calcBleedRefreshTime)
spec:RegisterStateExpr( "rake_refresh_time", function()
    if not debuff.rake.up then
        return 0 -- Refresh immediately if not up
    end
    
    local currentRemaining = debuff.rake.remains or 0
    local tickLength = 3 -- Rake ticks every 3 seconds
    
    -- Check for snapshot improvements (simplified)
    local hasSnapshotImprovement = rake_damage_increase_pct > 0.001
    
    if hasSnapshotImprovement then
        return 0 -- Refresh immediately for snapshot
    end
    
    -- Standard refresh: 1 tick before expiration, but return as time until refresh needed
    local standardRefresh = currentRemaining - tickLength
    
    -- Return time until refresh is needed (0 = refresh now)
    return math.max(0, standardRefresh)
end )

spec:RegisterStateExpr( "rip_refresh_time", function()
    if not debuff.rip.up then
        return 0 -- Refresh immediately
    end
    
    local currentRemaining = debuff.rip.remains or 0
    local tickLength = 2 -- Rip ticks every 2 seconds
    
    -- Standard refresh: 1 tick before expiration
    local standardRefresh = currentRemaining - tickLength
    
    -- Check for snapshot improvements (simplified)
    local hasSnapshotImprovement = rip_damage_increase_pct > 0.001
    
    if hasSnapshotImprovement then
        return 0 -- Refresh immediately for snapshot
    end
    
    return math.max(0, standardRefresh)
end )

-- Tiger's Fury energy threshold with reaction time (based on WoWSims calcTfEnergyThresh)
spec:RegisterStateExpr( "tf_energy_threshold_advanced", function()
    local reactionTime = 0.1 -- 100ms reaction time
    local clearcastingDelay = buff.clearcasting.up and 1.0 or 0.0
    local totalDelay = reactionTime + clearcastingDelay
    
    -- Energy threshold: 40 - (delay_time * regen_rate)
    local threshold = 40 - (totalDelay * energy.regen)
    
    return math.max(0, threshold)
end )

-- Advanced Tiger's Fury timing logic
spec:RegisterStateExpr( "tf_timing", function()
    if cooldown.tigers_fury.ready then
        -- Use advanced energy threshold
        return energy.current <= tf_energy_threshold_advanced
    end
    
    -- Don't wait too long for TF if we need energy now
    return energy.current <= 20 and cooldown.tigers_fury.remains <= 3
end )

-- State expression to check if we can make recommendations
spec:RegisterStateExpr( "can_recommend", function ()
    return state.spec and state.spec.id == 103 and level >= 10
end )
        

-- Essential state expressions for APL functionality
spec:RegisterStateExpr( "current_energy", function ()
    return energy.current or 0
end )

spec:RegisterStateExpr( "current_combo_points", function ()
    return combo_points.current or 0
end )

spec:RegisterStateExpr( "max_energy", function ()
    return energy.max or 100
end )

spec:RegisterStateExpr( "energy_regen", function ()
    return energy.regen or 10
end )

spec:RegisterStateExpr( "in_combat", function ()
    return combat > 0
end )

spec:RegisterStateExpr( "player_level", function ()
    return level or 85
end )

-- Additional essential state expressions for APL compatibility
spec:RegisterStateExpr( "cat_form", function ()
    return buff.cat_form.up
end )

spec:RegisterStateExpr( "bear_form", function ()
    return buff.bear_form.up
end )

spec:RegisterStateExpr( "health_pct", function ()
    return health.percent or 100
end )

spec:RegisterStateExpr( "target_health_pct", function ()
    return target.health.percent or 100
end )

spec:RegisterStateExpr( "behind_target", function ()
    return UnitExists("target") and UnitExists("targettarget") and UnitGUID("targettarget") ~= UnitGUID("player")
end )


-- MoP Tier Sets

-- Tier 15 (MoP - Throne of Thunder)
spec:RegisterGear( "tier15", 95841, 95842, 95843, 95844, 95845 )
-- 2-piece: Increases the duration of Savage Roar by 6 sec.
spec:RegisterAura( "t15_2pc", {
    id = 138123, -- Custom ID for tracking
    duration = 3600,
    max_stack = 1
} )
-- 4-piece: Your finishing moves have a 10% chance per combo point to grant Tiger's Fury for 3 sec.
spec:RegisterAura( "t15_4pc", {
    id = 138124, -- Custom ID for tracking
    duration = 3,
    max_stack = 1
} )

-- Tier 16 (MoP - Siege of Orgrimmar)
spec:RegisterGear( "tier16", 99155, 99156, 99157, 99158, 99159 )
-- 2-piece: When you use Tiger's Fury, you gain 1 combo point.
spec:RegisterAura( "t16_2pc", {
    id = 145164, -- Custom ID for tracking
    duration = 3600,
    max_stack = 1
} )
-- 4-piece: Finishing moves increase the damage of your next Mangle, Shred, or Ravage by 40%.
spec:RegisterAura( "t16_4pc", {
    id = 145165, -- Custom ID for tracking
    duration = 15,
    max_stack = 1
} )



-- MoP: Update calculate_damage for MoP snapshotting and stat scaling.
local function calculate_damage( coefficient, masteryFlag, armorFlag, critChanceMult )
    local hekili = _G["Hekili"]
    local state = hekili and hekili.State or {}
    local class = hekili and hekili.Class or {}
    
    local feralAura = 1
    local armor = armorFlag and 0.7 or 1
    local crit = 1 + ( (state.stat and state.stat.crit or 0) * 0.01 * ( critChanceMult or 1 ) )
    local mastery = masteryFlag and ( 1 + ((state.stat and state.stat.mastery_value or 0) * 0.01) ) or 1
    local tf = (state.buff and state.buff.tigers_fury and state.buff.tigers_fury.up) and 
               ((class.auras and class.auras.tigers_fury and class.auras.tigers_fury.multiplier) or 1.15) or 1

    return coefficient * (state.stat and state.stat.attack_power or 1000) * crit * mastery * feralAura * armor * tf
end

-- Force reset when Combo Points change, even if recommendations are in progress.
spec:RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, function( _, _, powerType )
    if powerType == "COMBO_POINTS" then
        Hekili:ForceUpdate( powerType, true )
    end
end )

-- Removed duplicate debuff registration - auras should be sufficient

-- Abilities (MoP version, updated)
spec:RegisterAbilities( {
    -- Maintain armor debuff (controlled by maintain_ff toggle)
    faerie_fire= {
        id = 16857,
        copy = { 770 },
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        texture = 136033,
        startsCombat = true,
        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },
    -- Debug ability that should always be available for testing
    savage_roar = {
        -- Use dynamic ID so keybinds match action bar (glyphed vs base)
        id = function()
            if IsSpellKnown and IsSpellKnown(127568) then return 127568 end
            return 52610
        end,
        copy = { 52610, 127568, 127538, 127539, 127540, 127541 },
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        texture = 236167,
        spend = 25,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function()
            applyBuff("savage_roar")
            -- Spend combo points only if we actually have some (glyph allows 0 CP pre-pull)
            if combo_points.current and combo_points.current > 0 then
                spend(combo_points.current, "combo_points")
            end
        end,
    },
    mangle_cat = {
        id = 33876,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function()
            gain(1, "combo_points")
        end,
    },
    faerie_fire_feral = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        startsCombat = true,

        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },
    -- Alias for SimC import token
    faerie_fire = {
        id = 770,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        startsCombat = true,
        handler = function()
            applyDebuff("target", "faerie_fire")
        end,
    },
    mark_of_the_wild = {
        id = 1126,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        startsCombat = false,
        handler = function()
            applyBuff("mark_of_the_wild")
        end,
    },
    healing_touch = {
        id = 5185,
        cast = function()
            if buff.natures_swiftness.up or buff.predatory_swiftness.up then return 0 end
            return 2.5 * haste
        end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = function() return buff.natures_swiftness.up and 0 or 0.1 end,
        spendType = "mana",
        startsCombat = false,
        usable = function()
            -- Disallow hardcasting in Cat; require an instant proc (NS or PS)
            return (talent.dream_of_cenarius and talent.dream_of_cenarius.enabled) and (buff.natures_swiftness.up or buff.predatory_swiftness.up)
        end,
        handler = function()
            if buff.natures_swiftness.up then removeBuff("natures_swiftness") end
            -- no HoT; just consume NS on CD and return to cat
            if talent.dream_of_cenarius and talent.dream_of_cenarius.enabled then
                applyBuff( "dream_of_cenarius_damage" )
            end
        end,
    },
    frenzied_regeneration = {
        id = 22842,
        cast = 0,
        cooldown = 36,
        gcd = "off",
        school = "physical",
        spend = 10,
        spendType = "rage",
        startsCombat = false,
        form = "bear_form",
        handler = function()
            applyBuff("frenzied_regeneration")
        end,
    },
    -- Barkskin: Reduces all damage taken by 20% for 12 sec. Usable in all forms.
    barkskin = {
        id = 22812,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "nature",
        startsCombat = false,
        handler = function ()
            applyBuff( "barkskin" )
        end
    },

    -- Bear Form: Shapeshift into Bear Form.
    bear_form = {
        id = 5487,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        essential = true,
        noform = "bear_form",
        handler = function ()
            -- Only allow form swap if we'll actually weave in bear.
            if opt_bear_weave and should_bear_weave then
                shift( "bear_form" )
            end
        end,
    },

    -- Berserk: Reduces the cost of all Cat Form abilities by 50% for 15 sec.
    berserk = {
        id = 106951,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "cooldowns",
        handler = function ()
            if buff.cat_form.down then shift( "cat_form" ) end
            applyBuff( "berserk" )
        end,
        copy = { "berserk_cat" }
    },

    -- Cat Form: Shapeshift into Cat Form.
    cat_form = {
        id = 768,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        essential = true,
        noform = "cat_form",
        handler = function ()
            -- Do not recommend Cat swap unless we are not weaving or bear form is active.
            if buff.bear_form.up or not opt_bear_weave then
                shift( "cat_form" )
            end
        end,
    },

    -- Dash: Increases movement speed by 70% for 15 sec.
    dash = {
        id = 1850,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        school = "physical",
        startsCombat = false,
        handler = function ()
            shift( "cat_form" )
            applyBuff( "dash" )
        end,
    },

    -- Disorienting Roar (MoP talent): Disorients all enemies within 10 yards for 3 sec.
    disorienting_roar = {
        id = 99,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "physical",
        talent = "disorienting_roar",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "incapacitating_roar" )
        end,
    },

    -- Entangling Roots: Roots the target in place for 30 sec.
    entangling_roots = {
        id = 339,
        cast = 1.7,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.1,
        spendType = "mana",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "entangling_roots" )
        end,
    },

    -- Faerie Swarm (MoP talent): Reduces target's movement speed and prevents stealth.
    faerie_swarm = {
        id = 102355,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        talent = "faerie_swarm",
        startsCombat = true,
        handler = function ()
            -- Debuff application handled elsewhere if needed
        end,
    },

    -- Ferocious Bite: Finishing move that causes Physical damage per combo point.
    ferocious_bite = {
        id = 22568,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = function ()
            return max( 25, min( 35, energy.current ) )
        end,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function () return combo_points.current > 0 end,
        handler = function ()
            spend( min( 5, combo_points.current ), "combo_points" )
        end,
    },

    -- Growl: Taunts the target to attack you.
    growl = {
        id = 6795,
        cast = 0,
        cooldown = 8,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        form = "bear_form",
        handler = function ()
            applyDebuff( "target", "growl" )
        end,
    },

    -- Incarnation: King of the Jungle (MoP talent): Improved Cat Form for 30 sec.
    incarnation_king_of_the_jungle = {
        id = 102543,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        talent = "incarnation_king_of_the_jungle",
        startsCombat = false,
        toggle = "cooldowns",
        handler = function ()
            if buff.cat_form.down then shift( "cat_form" ) end
            applyBuff( "incarnation_king_of_the_jungle" )
        end,
        copy = { "incarnation" }
    },

    -- Maim: Finishing move that causes damage and stuns the target.
    maim = {
        id = 22570,
        cast = 0,
        cooldown = 20,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        talent = "maim",
        startsCombat = false,
        form = "cat_form",
        usable = function () return combo_points.current > 0 end,
        handler = function ()
            applyDebuff( "target", "maim", combo_points.current )
            spend( combo_points.current, "combo_points" )
        end,
    },

    -- Mass Entanglement (MoP talent): Roots the target and nearby enemies.
    mass_entanglement = {
        id = 102359,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "mass_entanglement",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "mass_entanglement" )
        end,
    },

    -- Mighty Bash: Stuns the target for 5 sec.
    mighty_bash = {
        id = 5211,
        cast = 0,
        cooldown = 50,
        gcd = "spell",
        school = "physical",
        talent = "mighty_bash",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "mighty_bash" )
        end,
    },

    -- Moonfire: Applies a DoT to the target.
    moonfire = {
        id = 8921,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "arcane",
        spend = 0.06,
        spendType = "mana",
        startsCombat = false,
        form = "moonkin_form",
        handler = function ()
            if not buff.moonkin_form.up then unshift() end
            applyDebuff( "target", "moonfire" )
        end,
    },

    -- Prowl: Enter stealth.
    prowl = {
        id = 5215,
        cast = 0,
        cooldown = 6,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        nobuff = "prowl",
        handler = function ()
            shift( "cat_form" )
            applyBuff( "prowl_base" )
        end,
    },

    -- Rake: Bleed damage and awards 1 combo point.
    rake = {
        id = 1822,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 35,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",

        handler = function ()
            applyDebuff( "target", "rake" )
            gain( 1, "combo_points" )
            local snap = bleed_snapshot[ target.unit ]
            snap.rake_mult = current_bleed_multiplier()
            snap.rake_time = query_time
        end,
    },

    -- Regrowth: Heals a friendly target.
    regrowth = {
        id = 8936,
        cast = function ()
            if buff.predatory_swiftness.up then return 0 end
            return 1.5 * haste
        end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.10,
        spendType = "mana",
        startsCombat = false,
        handler = function ()
            if buff.predatory_swiftness.down then
                unshift()
            end
            removeBuff( "predatory_swiftness" )
            applyBuff( "regrowth" )
        end,
    },

    -- Nature's Swiftness (for SimC import compatibility)
    natures_swiftness = {
        id = 132158,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        school = "nature",
        startsCombat = false,
        handler = function()
            applyBuff( "natures_swiftness" )
        end,
    },

    -- Rejuvenation: Heals the target over time.
    rejuvenation = {
        id = 774,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.08,
        spendType = "mana",
        startsCombat = false,
        handler = function ()
            if buff.cat_form.up or buff.bear_form.up then
                unshift()
            end
            applyBuff( "rejuvenation" )
        end,
    },

    -- Rip: Finishing move that causes Bleed damage over time.
    rip = {
        id = 1079,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 20,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        usable = function ()
            return combo_points.current > 0
        end,
        handler = function ()
            applyDebuff( "target", "rip" )
            spend( combo_points.current, "combo_points" )
            local snap = bleed_snapshot[ target.unit ]
            snap.rip_mult = current_bleed_multiplier()
            snap.rip_time = query_time
        end,
    },

    -- Shred: Deals damage and awards 1 combo point.
    -- Handles both normal Shred (5221) and glyph-enhanced Shred! (114236)
    shred = {
        id = 5221,
        copy = { 114236 }, -- Glyph of Shred enhanced version
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Skull Bash: Interrupts spellcasting.
    skull_bash = {
        id = 80965,
        cast = 0,
        cooldown = 10,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        toggle = "interrupts",
        interrupt = true,
        form = function ()
            return buff.bear_form.up and "bear_form" or "cat_form"
        end,
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        handler = function ()
            interrupt()
        end,
    },

    -- Survival Instincts: Reduces all damage taken by 50% for 6 sec.
    survival_instincts = {
        id = 61336,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        handler = function ()
            applyBuff( "survival_instincts" )
        end,
    },

    -- Thrash (Cat): Deals damage and applies a bleed to all nearby enemies.
    thrash_cat = {
        id = 106830,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = 40,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            applyDebuff( "target", "thrash" )
            applyDebuff( "target", "weakened_blows" )
            gain( 1, "combo_points" )
        end,
    },
    thrash_bear = {
        id = 77758,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        school = "physical",
        spend = 25,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function ()
            applyDebuff( "target", "thrash" )
            applyDebuff( "target", "weakened_blows" )
            gain( 1, "combo_points" )
        end,
    },
    -- Tiger's Fury: Instantly restores 60 Energy and increases damage done by 15% for 6 sec.
    tigers_fury = {
        id = 5217,
        cast = 0,
        cooldown = 30,
        gcd = "off",
        school = "physical",
        spend = -60,
        spendType = "energy",
        startsCombat = false,
        
        usable = function()
            return not buff.berserk.up, "cannot use while Berserk is active"
        end,
        
        handler = function ()
            shift( "cat_form" )
            applyBuff( "tigers_fury" )
        end,
    },

    -- Swipe (Cat): Swipe nearby enemies, dealing damage and awarding 1 combo point.
    swipe_cat = {
        id = 62078,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 45,
        spendType = "energy",
        startsCombat = true,
        form = "cat_form",
        handler = function ()
            gain( 1, "combo_points" )
        end,
    },

    -- Wild Charge (MoP talent): Movement ability that varies by shapeshift form.
    wild_charge = {
        id = 102401,
        cast = 0,
        cooldown = 15,
        gcd = "off",
        school = "physical",
        talent = "wild_charge",
        startsCombat = false,
        handler = function ()
            applyBuff( "wild_charge" )
        end,
    },

    -- Cenarion Ward (MoP talent): Protects a friendly target, healing them when they take damage.
    cenarion_ward = {
        id = 102351,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "cenarion_ward",
        startsCombat = false,
        handler = function ()
            applyBuff( "cenarion_ward" )
        end,
    },

    -- Typhoon (MoP talent): Knocks back enemies and dazes them.
    typhoon = {
        id = 132469,
        cast = 0,
        cooldown = 30,
        gcd = "spell",
        school = "nature",
        talent = "typhoon",
        startsCombat = true,
        handler = function ()
            applyDebuff( "target", "typhoon" )
        end,
    },

    -- Heart of the Wild (MoP talent): Temporarily improves abilities not associated with your specialization.
    heart_of_the_wild = {
        id = 108292,
        cast = 0,
        cooldown = 360,
        gcd = "off",
        school = "nature",
        talent = "heart_of_the_wild",
        startsCombat = false,
        handler = function ()
            applyBuff( "heart_of_the_wild" )
        end,
    },

    -- Renewal (MoP talent): Instantly heals you for 30% of max health.
    renewal = {
        id = 108238,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "nature",
        talent = "renewal",
        startsCombat = false,
        handler = function ()
            -- Healing handled by game
        end,
    },

    -- Force of Nature (MoP talent): Summons treants to assist in combat.
    force_of_nature = {
        id = 102703,
        cast = 0,
        cooldown = 60,
        gcd = "spell",
        school = "nature",
        talent = "force_of_nature",
        startsCombat = true,
        handler = function ()
            -- Summon handled by game
        end,
    },

    -- Shadowmeld: Night Elf racial ability
    shadowmeld = {
        id = 58984,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        school = "physical",
        startsCombat = false,
        handler = function ()
            applyBuff( "shadowmeld" )
        end,
    },

    -- Wrath (for Wrath-Weaving during Heart of the Wild)
    wrath = {
        id = 5176,
        cast = function() return 2 / haste end,
        cooldown = 0,
        gcd = "spell",
        school = "nature",
        spend = 0.06,
        spendType = "mana",
        startsCombat = true,
        handler = function()
            -- Wrath damage during Heart of the Wild
        end,
    },

    -- Mangle (Bear) for Bear-Weaving
    mangle_bear = {
        id = 33878,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 20,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function()
            -- Mangle damage in Bear Form
        end,
    },
    -- Maul (Bear): Off-GCD rage dump
    maul = {
        id = 6807,
        cast = 0,
        cooldown = 3,
        gcd = "off",
        school = "physical",
        spend = 30,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function()
        end,
    },

    -- Lacerate for Bear-Weaving (if talented)
    lacerate = {
        id = 33745,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        school = "physical",
        spend = 15,
        spendType = "rage",
        startsCombat = true,
        form = "bear_form",
        handler = function()
            applyDebuff("target", "lacerate")
        end,
    },
} )

-- Feral Druid Advanced Techniques
-- Simple toggle system for Bear-Weaving and Wrath-Weaving

-- Additional auras for advanced techniques
spec:RegisterAuras( {
    lacerate = {
        id = 33745,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 3,
    },

    -- Bear Form specific auras
    bear_form_weaving = {
        duration = 3600,
        max_stack = 1,
    },
} )

-- Auras for advanced techniques
spec:RegisterAuras( {
    lacerate = {
        id = 33745,
        duration = 15,
        tick_time = 3,
        mechanic = "bleed",
        max_stack = 3,
    },

    -- Bear Form specific auras
    bear_form_weaving = {
        duration = 3600,
        max_stack = 1,
    },
} )

-- State expressions for advanced techniques
spec:RegisterStateExpr( "should_bear_weave", function()
    if not state.settings.bear_weaving_enabled then return false end
    
    -- Bear-weave when energy is high and we're not in immediate danger
    return energy.current >= 80 and 
           not buff.berserk.up and 
           not buff.incarnation_king_of_the_jungle.up and
           target.time_to_die > 10
end )

spec:RegisterStateExpr( "should_wrath_weave", function()
    if not state.settings.wrath_weaving_enabled then return false end
    
    -- Wrath-weave during Heart of the Wild when not in combat forms
    return buff.heart_of_the_wild.up and 
           not buff.cat_form.up and 
           not buff.bear_form.up and
           mana.current >= 0.06 * mana.max
end )

-- Settings for advanced techniques
spec:RegisterSetting( "bear_weaving_enabled", false, {
    name = "Enable Bear-Weaving",
    desc = "If checked, Bear-Weaving will be recommended when appropriate. This involves shifting to Bear Form to pool energy and deal damage.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "wrath_weaving_enabled", false, {
    name = "Enable Wrath-Weaving", 
    desc = "If checked, Wrath-Weaving will be recommended during Heart of the Wild when not in combat forms.",
    type = "toggle",
    width = "full"
} )

-- SimC-style toggles for parity with Feral_SimC_APL.simc
spec:RegisterSetting( "maintain_ff", true, {
    name = "Maintain Faerie Fire",
    desc = "If checked, maintain Faerie Fire (armor) on the target.",
    type = "toggle",
    width = "full"
} )

-- Consolidated: Use base flags; variables in APL map to these via state expressions below.

spec:RegisterSetting( "opt_snek_weave", true, {
    name = "Enable Snek-Weave ",
    desc = "Use Predatory Swiftness/Nature's Swiftness for Regrowth snapshots.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "opt_use_ns", false, {
    name = "Use Nature's Swiftness ",
    desc = "Use Nature's Swiftness to enable snapshot Regrowths.",
    type = "toggle",
    width = "full"
} )

spec:RegisterSetting( "opt_melee_weave", true, {
    name = "Melee-Weave Focus ",
    desc = "Prefer Cat Form melee time; monocat keeps this on while other weaves are off.",
    type = "toggle",
    width = "full"
} )

spec:RegisterRanges( "rake", "shred", "skull_bash", "growl", "moonfire" )

spec:RegisterOptions( {
    enabled = true,

    aoe = 3,
    cycle = false,

    nameplates = true,
    nameplateRange = 10,
    rangeFilter = false,

    damage = true,
    damageDots = false,
    damageExpiration = 3,

    potion = "tempered_potion",

    package = "Feral"
} )

-- Solo/positioning toggle
spec:RegisterSetting( "disable_shred_when_solo", false, {
    type = "toggle",
    name = "Disable Shred when Solo",
    desc = "If checked, Shred will not be recommended when not in a group/raid and on single targets.",
    width = "full",
} )

-- Feature toggles
spec:RegisterSetting( "use_trees", false, {
    type = "toggle",
    name = "Use Force of Nature",
    desc = "If checked, Force of Nature will be used on cooldown.",
    width = "full",
} )

spec:RegisterSetting( "use_hotw", false, {
    type = "toggle",
    name = "Use Heart of the Wild",
    desc = "If checked, Heart of the Wild will be used on cooldown.",
    width = "full",
} )

spec:RegisterSetting( "pool", 1, {
    name = "Energy Pooling",
    desc = "Controls how aggressively the rotation pools energy for optimal timing.\n0 = No pooling (cast immediately)\n1 = Light pooling (pool for major abilities)\n2 = Heavy pooling (optimal rotation timing)",
    type = "select",
    values = { [0] = "No Pooling", [1] = "Light Pooling", [2] = "Heavy Pooling" },
    width = "full",
} )


spec:RegisterSetting( "rip_duration", 9, {
    name = strformat( "%s Duration", Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    desc = strformat( "If set above |cFFFFD1000|r, %s will not be recommended if the target will die within the specified timeframe.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.rip.id ) ),
    type = "range",
    min = 0,
    max = 18,
    step = 0.1,
    width = 1.5
} )

spec:RegisterSetting( "regrowth", true, {
    name = strformat( "Filler %s", Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    desc = strformat( "If checked, %s may be recommended as a filler when higher priority abilities are not available. This is generally only at very low energy.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.regrowth.id ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterVariable( "regrowth", function()
    return state.settings.regrowth ~= false
end )

spec:RegisterStateExpr( "filler_regrowth", function()
    return state.settings.regrowth ~= false
end )

spec:RegisterSetting( "solo_prowl", false, {
    name = strformat( "Allow %s in Combat When Solo", Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    desc = strformat( "If checked, %s can be recommended in combat when you are solo. This is off by default because it may drop combat outside of a group/encounter.",
        Hekili:GetSpellLinkWithTexture( spec.abilities.prowl.id ) ),
    type = "toggle",
    width = "full",
} )

spec:RegisterSetting( "allow_shadowmeld", nil, {
    name = strformat( "Use %s", Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    desc = strformat( "If checked, %s can be recommended for Night Elf players if its conditions for use are met. Only recommended in boss fights or groups to avoid resetting combat.",
        Hekili:GetSpellLinkWithTexture( spec.auras.shadowmeld.id ) ),
    type = "toggle",
    width = "full",
    get = function () return not Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled end,
    set = function ( _, val )
        Hekili.DB.profile.specs[ 103 ].abilities.shadowmeld.disabled = not val
    end,
} )

spec:RegisterSetting( "lazy_swipe", false, {
    name = strformat( "Minimize %s in AOE", Hekili:GetSpellLinkWithTexture( spec.abilities.shred.id ) ),
    desc = "If checked, Shred will be minimized in multi-target situations. This is a DPS loss but can be easier to execute.",
    type = "toggle",
    width = "full"
} )

spec:RegisterVariable( "use_thrash", function()
    return active_enemies >= 4
end )

spec:RegisterVariable( "aoe", function()
    return active_enemies >= 3
end )

spec:RegisterVariable( "use_rake", function()
    return true
end )

spec:RegisterVariable( "pool_energy", function()
    return energy.current < 50 and not buff.omen_of_clarity.up and not buff.berserk.up
end )

spec:RegisterVariable( "lazy_swipe", function()
    return state.settings.lazy_swipe ~= false
end )

spec:RegisterVariable( "solo_prowl", function()
    return state.settings.solo_prowl ~= false
end )

-- Bleed snapshot tracking (minimal: Tiger's Fury multiplier)
spec:RegisterStateTable( "bleed_snapshot", setmetatable( {
    cache = {},
    reset = function( t )
        table.wipe( t.cache )
    end
}, {
    __index = function( t, k )
        if not t.cache[ k ] then
            t.cache[ k ] = {
                rake_mult = 0,
                rip_mult = 0,
                rake_time = 0,
                rip_time = 0,
            }
        end
        return t.cache[ k ]
    end
} ) )

spec:RegisterStateFunction( "current_bleed_multiplier", function()
    -- Primary MoP snapshot driver is Tiger's Fury (1.15)
    local tf = ( buff.tigers_fury and buff.tigers_fury.up ) and 1.15 or 1
    return tf
end )

spec:RegisterStateExpr( "rake_stronger", function()
    local snap = bleed_snapshot[ target.unit ]
    local now_mult = current_bleed_multiplier()
    return now_mult > ( snap.rake_mult or 0 ) + 0.001
end )

spec:RegisterStateExpr( "rip_stronger", function()
    local snap = bleed_snapshot[ target.unit ]
    local now_mult = current_bleed_multiplier()
    return now_mult > ( snap.rip_mult or 0 ) + 0.001
end )

-- Percent increase if we were to reapply the bleed now (0.05 = 5%).
spec:RegisterStateExpr( "rake_damage_increase_pct", function()
    local snap = bleed_snapshot[ target.unit ]
    local last = snap.rake_mult or 0
    local now = current_bleed_multiplier()
    if last <= 0 then return 0 end
    return max( 0, ( now / last ) - 1 )
end )

spec:RegisterStateExpr( "rip_damage_increase_pct", function()
    local snap = bleed_snapshot[ target.unit ]
    local last = snap.rip_mult or 0
    local now = current_bleed_multiplier()
    if last <= 0 then return 0 end
    return max( 0, ( now / last ) - 1 )
end )

-- Bear-weave trigger logic mirroring the provided APL conditions.
spec:RegisterStateExpr( "bearweave_trigger_ok", function()
    if not buff.cat_form.up then return false end
    if active_enemies > 1 then return false end
    if energy.current >= 15 then return false end
    if debuff.rake.remains < 8 or debuff.rip.remains < 8 then return false end
    if cooldown.tigers_fury.remains < 7 then return false end
    if buff.berserk.up then return false end

    -- Predatory Swiftness window OR minimal expected rake snapshot gain
    if buff.predatory_swiftness.up and buff.predatory_swiftness.remains >= 5 then return true end
    if buff.predatory_swiftness.down and rake_damage_increase_pct <= 0.05 then return true end

    return false
end )

-- State expressions for advanced techniques
spec:RegisterStateExpr( "should_bear_weave", function()
    if not opt_bear_weave then return false end
    -- Avoid immediate flip-flop right after swapping to Cat
    if query_time <= ( action.cat_form.lastCast + gcd.max ) then return false end
    -- Don't start a weave if any core timers need attention soon
    local urgent_refresh = ( (debuff.rip.remains > 0 and debuff.rip.remains <= 3)
        or (debuff.rake.remains > 0 and debuff.rake.remains <= 3)
        or (buff.savage_roar.up and buff.savage_roar.remains <= 4)
        or cooldown.tigers_fury.remains <= 2 )
    if urgent_refresh then return false end
    -- Trigger bear-weave when energy is LOW to pool (e.g., <= 35)
    return energy.current <= 35 and not buff.berserk.up and not buff.incarnation_king_of_the_jungle.up and target.time_to_die > 10
end )

spec:RegisterStateExpr( "should_wrath_weave", function()
    if not opt_wrath_weave then return false end
    if buff.cat_form.up or buff.bear_form.up then return false end
    if not buff.heart_of_the_wild.up then return false end
    if buff.clearcasting.up then return false end

    local cast_time = 2 / haste
    local remaining_gcd = gcd.max

    if buff.heart_of_the_wild.remains <= ( cast_time + remaining_gcd ) then return false end

    local regen_rate = energy.regen
    local furor_cap = 100 - ( 1.5 * regen_rate )
    local starting_energy = energy.current + ( remaining_gcd * regen_rate )

    if combo_points.current < 3 and ( starting_energy + ( cast_time * regen_rate * 2 ) > furor_cap ) then
        return false
    end

    local reaction_time = 0.1
    local time_to_next_cat_special = remaining_gcd + cast_time + reaction_time + gcd.max

    if not debuff.rip.up or debuff.rip.remains <= time_to_next_cat_special then return false end
    if not debuff.rake.up or debuff.rake.remains <= time_to_next_cat_special then return false end

    if should_delay_bleed_for_tf( debuff.rip, 2, true ) or should_delay_bleed_for_tf( debuff.rake, 3, false ) then return false end

    return mana.current >= 0.06 * mana.max
end )

spec:RegisterStateFunction( "tf_expected_before", function( future_time )
    local ft = future_time or gcd.max
    if ft <= 0 then ft = gcd.max end
    if cooldown.tigers_fury.ready then
        if buff.berserk.up then
            return buff.berserk.remains < ft
        end
        return true
    end
    return cooldown.tigers_fury.remains < ft
end )

spec:RegisterStateFunction( "should_delay_bleed_for_tf", function( dot, tick_length, is_rip )
    if not dot or not dot.up then return false end
    if buff.tigers_fury.up or buff.berserk.up or buff.dream_of_cenarius_damage.up then return false end

    local tickTime = ( dot.tick_time and dot.tick_time > 0 ) and dot.tick_time or tick_length
    local fight_remains = target.time_to_die or 300
    local future_ticks = math.min( is_rip and 12 or 3, math.floor( fight_remains / tickTime ) )
    if future_ticks <= 0 then return false end

    local delay_breakpoint = tickTime + ( 0.15 * future_ticks * tickTime )
    if not tf_expected_before( delay_breakpoint ) then return false end

    if is_rip and buff.dream_of_cenarius_damage.up and buff.dream_of_cenarius_damage.remains <= delay_breakpoint then
        return false
    end

    local reaction_time = 0.1 + ( buff.clearcasting.up and 1.0 or 0.0 )
    local tf_threshold = 40 - ( reaction_time * energy.regen )
    local energy_after_delay = energy.current + ( delay_breakpoint * energy.regen ) - tf_threshold
    local casts_to_dump = math.ceil( energy_after_delay / 40 )

    return casts_to_dump < delay_breakpoint
end )

spec:RegisterStateExpr( "delay_rip_for_tf", function()
    return should_delay_bleed_for_tf( debuff.rip, 2, true )
end )

spec:RegisterStateExpr( "delay_rake_for_tf", function()
    return should_delay_bleed_for_tf( debuff.rake, 3, false )
end )

spec:RegisterStateExpr( "berserk_clip_for_hotw", function()
    if not buff.berserk.up then return false end
    if buff.heart_of_the_wild.up then return false end
    if cooldown.heart_of_the_wild.remains > 8 then return false end
    return buff.berserk.remains <= 4
end )

-- Expose SimC-style toggles directly in state for APL expressions
spec:RegisterStateExpr( "maintain_ff", function() return state.settings.maintain_ff ~= false end )
-- Map APL variables to consolidated settings.
spec:RegisterStateExpr( "opt_bear_weave", function() return state.settings.bear_weaving_enabled ~= false end )
spec:RegisterStateExpr( "opt_wrath_weave", function() return state.settings.wrath_weaving_enabled ~= false end )
spec:RegisterStateExpr( "opt_snek_weave", function() return state.settings.opt_snek_weave ~= false end )
spec:RegisterStateExpr( "opt_use_ns", function() return state.settings.opt_use_ns ~= false end )
spec:RegisterStateExpr( "opt_melee_weave", function() return state.settings.opt_melee_weave ~= false end )
spec:RegisterStateExpr( "use_trees", function() return state.settings.use_trees ~= false end )
spec:RegisterStateExpr( "use_hotw", function() return state.settings.use_hotw ~= false end )
spec:RegisterStateExpr( "disable_shred_when_solo", function()
    return state.settings.disable_shred_when_solo ~= false
end )
-- Provide in_group for APL compatibility in emulated environment
spec:RegisterStateExpr( "in_group", function()
    -- Avoid calling globals in the sandbox; treat as solo in emulation
    return false
end )

-- Missing variables for bearweave and other APL logic
spec:RegisterStateExpr( "bearweave_trigger_ok", function()
    -- Check if bearweave is appropriate (low health, need survivability)
    return health.pct <= 50 or incoming_damage_3s > (health.current * 0.3)
end )

spec:RegisterStateExpr( "thrash_aoe_efficient", function()
    -- Thrash is efficient for AoE when there are 2+ enemies
    return active_enemies >= 2
end )

spec:RegisterStateExpr( "energy_time_to_max", function()
    -- Calculate time to reach max energy
    if energy.current >= energy.max then return 0 end
    local deficit = energy.max - energy.current
    local regen_rate = energy.regen or 10
    return deficit / regen_rate
end )

spec:RegisterStateExpr( "clip_rip_with_snapshot", function()
    if not debuff.rip.up then return false end
    if buff.dream_of_cenarius_damage.up and buff.dream_of_cenarius_damage.remains <= gcd.max then
        return true
    end
    if not buff.dream_of_cenarius_damage.up then return false end
    if combo_points.current <= 3 then return true end
    return false
end )

spec:RegisterStateExpr( "clip_rake_with_snapshot", function()
    if not debuff.rake.up then return false end
    if buff.dream_of_cenarius_damage.up and buff.dream_of_cenarius_damage.remains <= gcd.max then
        return true
    end
    if not buff.dream_of_cenarius_damage.up then return false end
    if combo_points.current <= 3 then return true end
    return false
end )

spec:RegisterStateExpr( "clip_roar_for_min_offset", function()
    if buff.savage_roar.down then return false end
    if not debuff.rip.up then return false end
    local roar_end = buff.savage_roar.remains or 0
    local rip_refresh = debuff.rip.remains or 0
    local min_offset = 40
    if player.level >= 90 and talent.dream_of_cenarius and talent.dream_of_cenarius.enabled then min_offset = 30 end
    if roar_end >= rip_refresh + min_offset then return false end
    if roar_end >= target.time_to_die then return false end
    return true
end )

spec:RegisterStateExpr( "combo_points_for_rip", function()
    return combo_points.current >= ( target.health.pct <= 25 and 1 or 5 )
end )

spec:RegisterStateExpr( "should_bite_emergency", function()
    if target.health.pct > 25 then return false end
    if not debuff.rip.up then return false end
    if debuff.rip.remains >= debuff.rip.tick_time then return false end
    return combo_points.current >= 1
end )

spec:RegisterStateExpr( "bear_weave_energy_cap", function()
    local regen = energy.regen or 10
    return 100 - ( 1.5 * regen )
end )

spec:RegisterStateExpr( "bear_weave_ready", function()
    if not opt_bear_weave then return false end
    if buff.clearcasting.up or buff.berserk.up then return false end
    local furor_cap = bear_weave_energy_cap
    if energy.current - floating_energy > furor_cap then return false end
    if delay_rip_for_tf or delay_rake_for_tf then return false end
    if not tf_expected_before( gcd.max ) then return false end
    return true
end )

spec:RegisterStateExpr( "should_bite", function()
    if combo_points.current < 5 then return false end
    if not debuff.rip.up or buff.savage_roar.down then return false end
    if target.health.pct <= 25 then return true end
    local rip_refresh = debuff.rip.remains or 0
    local roar_refresh = buff.savage_roar.remains or 0
    local bite_time = buff.berserk.up and 3 or 4
    return min( rip_refresh, roar_refresh ) >= bite_time
end )

spec:RegisterPack( "Feral", 20250927, [[Hekili:vZrApQns2Fl8flqjI1anjtKGwk7Uz1oJ025dKpJXTPOXQn2iBt3tlH43((QdBxhVQSn0zIMJmjDD8UQx9olN1tw)J1R2gwsw)Wu)PZ9)Y0pp2FI)SzFE9QY3oswV6yy0ZHpb)H0WdW)))qYdtOJ(wsw4w6UlYoLhbZSE1JNItk)901pQbYpnE605)28VaR9ijA9da8xVAF82Te(AjfrRx9J9Xfx2q)v4LncKEzt2o4NJkJZsVSjjUOeMExw(Ln)xYZXjXJxVIniLm(63)g8BpWyisA4JjKTR)NRxLDeWkPC9kouwV6LW8y6S0)uYj438zJfWzVdHXPLWVc2TBDjWa9gAtKHw2XYGhjWp(kj8fcfGZ0ayfCIctsc4)qaLL4mMamrHLbaOIpas(s4F5ujg3gLhxsakQHWglXrx24DzZwYJN2TB8UqyDKGDX5KXBZEnLnhLaEHeqsjhIjGOEXYlBMYMHThkDas)dJpDSHYLaeMeRHIkdZFIucaPOmo9Pgau88jG3FmSypN5OcmU8QBmOQqMtTvGiOmp(PNi5bzp3Gq2IP8HB6LXY1Rf4zgOZb1YXrNYZjPLx2CpvanNnXaqRnN8Y4Y95aRWOOgukpiIwqBivS9Wm4Sz3U4OygYTqnwX6D9eRgAdx2mdbRlur6HW0Nsi1iD(phK2cR(PEIvtGpZxsVpbwVqVT5YI4apiB3UGNI2cx0oLyLfKLpNO3IF4Z9KenPeXe216QUVsr3V1t01gtOCi)L3vGNegbozkzMtM43tqp8YgaS5p9wayVeU)NfCi8p5wYOhsK)KeDQeSsC(mykmRCCE4ZKX5eQvsHbVzstgFuDU585IYYsO6bJlJbJlfb7oL)M6cbRMJqpiadCBZICBARmmb0dhVnNeEauVcIGvLhFQySy1vmQIjWIuYZvMaP0OYKNkibusBKQms6smqZ35lTGHcnoq7c8LNL)wqXRX7ktjffkAKyZBij4uuhGkDzSfKgwEkNuOn9O2UtYrru2HhZcoMbo(kuVvFx1QQoD57e)8MT8rYKFTcJ22u1HyQqJK(pN(p3tctaEa0upfTVnpODqVa9C3ZMqHRt7jPsBk5R5myX(vM(CCkDLbsyaSo4P0queSn8a1wUGoWzAXTCxEBStM0d7o4n9xaLjmkdZ1bhVxh9vFf6kiVkbxl(M)fqyXh7Gd5RMUMFJ0vlEU)fqxIdYw863gHPJ5g7Z2rnyB4yTgEBXg8ZGaeXzXPGs1uZU9Spl3f8yw6Pcm3anXs4itrEIHxDEMcFafy23Sdbl5K9ked3ErMVYyHnoMfQEJbPuRLrqtcKiwB6csAZpRc2OrZHy9Ol4bvbub4qgFyMa60PzHqf9hF7H)93F460oN8RS2iTdqFDakRZHOd3oeNm329XURTkDguss3clQx6HUk8dvFWzQdqqQard7acPuKRcadYFgbXtfWd6h0ZUSzYCLitFeYIHK)CtG0oIX2HXXMSHChiBlwElcFbmthKNfM3Gw7b1pbLSydsbrWlSykb)gBP1ZS2vsdsChOjnc)gZ(2lwMdMOocA7KRfxmocZ89f)SbhYcT3qOvL0lAeRmaoYIlA7bHEnu)IQKi6RUG1tD7XIQtFlQPpzKtrqaeNgBcSmi)8yofpGw41KW3OlMTPYDvJhLadrh(1yW2vrA4XI9zLQHbUk6n4YyaVeQfuda86aNLMrL0xLTDdJNQwJ7V592Sg)oyFVPihCbGW(Af)3yuvuVfj050G0ae1ohQnZKrMSvpv8DN8YeMy1wI(feoR(sC(bsArWJa9bAACaubiXpxP9wRMqJkxf42ZOX(fO5QkEoZ)Otqzhjplko7eNB4hB8qa7E59LuKy3AGliNs2QgHzf(QcVeqZXCcLeXVGyE4Fim)zA4EL7jWDXKTAjxRojM(KP6NesmSj50Ptn7xKLaI48Sxt4wHHWV48eVCmsQf0142Jr)0YlLtiWPaSU2rfVrTErckoMdHmqRCu423AG)(W0TfaAsOM34)GdPyjaJNjLtQ2q9p7i9gXAMQTNPM3gtYY2IDNDoYDww7QuwvR9xGhovvjnfT(QQI0BJjIsI9PEEJ3(nArolXPrH5PH01RuvqgzjxTA5ZDPn5(cVEvJHaj)IVn43P4ivvfXRirhQDyLX1sxvLO(ofTQOL5ecVWOcjhaZic9goVoKDx6PTrkn4OYekeb4N)vzAypiNkvmbjtfdrdwNvYC(ibSqjOrxWbSuuzgqMFbFlzx4PKRmac58bFpttup1(33CgnknX7CgKAHP4kagdV)Dd68I6RdzXOigN6gupqsieCIwEkeJqTd)6lCYqUzqeBoDdMu1CDqYgdXoq7qCBCb9Ndk2NtGGl2tsdOEFLrGTLGDNVDe24BxghsJsbR(9YMGm6tHdkAjgO)Eu3aPoiAwJG6EhIN7ip5qrV8ebqYt9cwh(ObhHyuaVqrv887wENDiWV(8UDObwWoE8VApOApJh7brATmaZRCsH0Lu6pgKt2Ltk2hWP2f8UjwplV28bqSiquJW94Jr8am8h7RQZ1sHnWyE8oAurVgr1q3HOt)dQ1kocb5wFtWr9qww1YBpbJrRKcZCbRskk1cGonwXaOJBRAaIMVyVYkTCa9tqg6(879JNTh1T1AYG2QFAXwSRmct(RtxeRgsukIKUfcDJsXqQwQpyboFnstmFvLzYzggcQZOuOv0I0eMVfcuxdY5i0IK0qUCFDhmnFbgn1sS7hasEJuQ)Q9KHej1rF)gL7hZuryx(NRqWLXrpZ8PAJj4KJJsP0zz01WSgvNXr(tcdHSuujhadHK0O36cM7zPODrDoYSsI8Q05RgQoLH)QPw7bCzjigRQclRSKAh)QV)JjDkmkS7JAxMR1GBEhuo1whjfkMCHqg1fHVUjXbQp0nlXFJc56tSbSQM9uEgJkKIjJceMOYE4yDXzQrqW9NhB0qd0QzM2HQ94YWct5w0MyacC4WFD)SKi(FF)HV)V(6pWYKOtzLu1UIRQQagnpwlR0R7fpOLNem7lWPjDJvF8c3TE1RH5P06zUE1VF4ywEjTEm0eH4qv8Hjm(YFai9u5(S81RwD40U84NzvLDxmLl4RT4dl)hvC2hPKWsPW8)iJtLh5YFyBBQvcrStTxcVZnlvNdPDlxODNBVPogs7w6jO6CZ8sviTrXZu05MKoUL2P0O23EDLgeBSP(Fo3cTscs7GvtnRBWILjX(Tz3Yk4AkcGacs9b4pQ3246oCaaqVdfFmE3sExhqASboiQmeGplNCaO(IzZjoFUUXel9X3UKZUgstR(VsSwDVhGTsf)GDUdFKwv)LSohqbH7(o0fqv1tHES2P4RTPHcwMVUvc4ZZRXp)WhPzau2vZJ65ZMTvyXYPFch(s14Ncl7TlWJHgTs57ILOGtnf67)Ipgu8mJ4GckpefbpvxOaB5z46eLM0kgVI2A91Ep3L8V7saJQQBGpQrdV2QUV3qJ4ioFgTM(JKVHWCuq55Ms3OGFjhjEwQEuVKZv4R5d2IRjj)zDjtFBZI4YOM33UKQN1xxN3WxK79BJtLZNvMG70yK3qvLVflVZhgKlsX)od8SoNiEFqom68zNWaoGOtI9c4hztrF4qSOXUF5DEdLtM)8zTefxC3ik5OuxnXIKY7DXSrW)448JFEyqXD6mbrY7HXmlN71(xsWsFVbwLE9sLKZsuPqTbshV6xukEXYz6OCwRySjQ8)AX7nXPGEw)ry8X)(GV5xb(Ujb6vGW6NhxNWQk4PwkAd(njU)UHGguu)YQzE)fF5Dk(CutbXd7dXfhCsFaJsX6ew)X95j)jAE)YPZ9gO)HpELag7JR1aB4Ww6ZGeh2gQhYWDHnW2kj7eSUi3tjDr4oZ3MhSbgFXRg0coQRuOWrVj2Gb72XBVpcWbt13C6Tad38Oimf5pl1flL(KurCOVCMzOalNF(SRp)uAOlYxzzz0deh73nUQkLVVN5JQtgof0i)KWhfudRBzmqt6Tl((jZfbJihxRZCaqnRvGK7OiYm9YNkIjdPaUlwobIGsV)UMJu3X3rOg8VF5K2O0BjyCQQX9(9kaigoRCIHgMXCp9ahnAg7IL(IrrA8190MEnYmjnHKLks0jytVG6bPd2ya94bM1SKQCJfR00rEgnt1BGrlf9gyPzI9tIDJmRDr5TqY8iJW60PE6d693KF(I3xZ3PJxDZug9SSXsgLghvliQ7tzLCqVdL6MGuIVzishj5yYSBKq(r4oACX7A819qiF6MPV3moxerKUzcLEfjLhDt7exqdYrRnIM0ZmlgQUvL4wPx0UbAdWwiJBbPEdm6U37l2rYXt3HdEwb(TbzMfmj)y6kK4nGJwcalN1JeE(Ako4OoCe7nyyBnwtdkGqBqvR0g5uC5YWQs8aDHmBoHd0QSldZkDQsslrYTs3pOAGnKqWVOqE4ywlMhvbvDMADsLetB3JfVJYN5LoRRyQfXsRTSh799nbdlNA8TbAVHdmyplHwmz0Tl4R8WmTZsFDCs9UR8nETCIjUxa4g1)VU33ppEAFCW2qmuku0p0pO3sQQpgwrdP8TTl9gUk1NZ(TL6kT3VT1AMo9dC1z45Ooh9dIBZI4o8B5Vnx6fqb1iuL1(bLcfTbr)6n0eqB(SF32NzFN74gn64SVmPY)qa)awlmRNQtnG0yxsoaqMvyOhzMwAOhYoObvInSzG)sU(r2Gzytw3B9UTFjSrRrwE)1V)nJtjZNYGV7nGQhnrFp9IUeprf7MH4AyyBOlp5GjDhtwiq(FBm0bz3Kw3tBIphBZ5Tql7tZ()K5i7axuW1m78YLKCSNKZ6))]] )
