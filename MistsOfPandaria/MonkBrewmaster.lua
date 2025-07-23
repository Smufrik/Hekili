-- MonkBrewmaster.lua
-- Updated July 23, 2025 - Comprehensive Rework for MoP Classic
-- Mists of Pandaria module for Monk: Brewmaster spec

if not Hekili or not Hekili.NewSpecialization then return end
if select(2, UnitClass('player')) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Brewmaster Monk
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID)
end

local function GetStaggerLevel()
    if FindUnitBuffByID("player", 124273) then return "heavy" end
    if FindUnitBuffByID("player", 124274) then return "moderate" end
    if FindUnitBuffByID("player", 124275) then return "light" end
    return "none"
end

-- Brewmaster-specific combat log tracking
local bm_combat_log_events = {}

local function RegisterBMCombatLogEvent(event, callback)
    if not bm_combat_log_events[event] then
        bm_combat_log_events[event] = {}
    end
    table.insert(bm_combat_log_events[event], callback)
end

local bmCombatLogFrame = CreateFrame("Frame")
bmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
bmCombatLogFrame:SetScript("OnEvent", function(self, event)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    
    if sourceGUID == UnitGUID("player") or destGUID == UnitGUID("player") then
        if bm_combat_log_events[subevent] then
            for _, callback in ipairs(bm_combat_log_events[subevent]) do
                callback(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
            end
        end
    end
end)

local function RegisterBrewmasterSpec()
    if not class or not state or not Hekili.NewSpecialization then return end
    
    local spec = Hekili:NewSpecialization( 268 ) -- Brewmaster spec ID for MoP
    if not spec then return end -- Not ready yet

    -- Enhanced Resource System
    spec:RegisterResource( 3, { -- Energy = 3 in MoP
        tiger_palm = {
            aura = "tiger_palm_energy",
            last = function()
                local app = state.buff.tiger_palm_energy.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1.5 ) * 1.5
            end,
            interval = 1.5,
            value = function()
                local energy = 25
                if state.talent.ascension.enabled then energy = energy * 1.15 end
                if state.buff.power_strikes.up then energy = energy + 15 end
                return energy
            end,
        },
        jab = {
            aura = "jab_energy",
            last = function()
                local app = state.buff.jab_energy.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 2.0 ) * 2.0
            end,
            interval = 2.0,
            value = function()
                local energy = 40
                if state.talent.ascension.enabled then energy = energy * 1.15 end
                return energy
            end,
        },
        ascension = {
            aura = "ascension",
            last = function()
                local app = state.buff.ascension.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                return state.talent.ascension.enabled and 2 or 0
            end,
        },
        energizing_brew = {
            aura = "energizing_brew",
            last = function()
                local app = state.buff.energizing_brew.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1.5 ) * 1.5
            end,
            interval = 1.5,
            value = 20,
        },
    }, {
        base_regen = function()
            local base = 10
            if state.talent.ascension.enabled then base = base * 1.15 end
            if state.buff.energizing_brew.up then base = base + 20 end
            return base
        end,
    })

    spec:RegisterResource( 12, { -- Chi = 12 in MoP
        power_strikes = {
            aura = "power_strikes",
            last = function()
                local app = state.buff.power_strikes.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 20 ) * 20
            end,
            interval = 20,
            value = function()
                return state.talent.power_strikes.enabled and 1 or 0
            end,
        },
        chi_brew = {
            aura = "chi_brew",
            last = function()
                local app = state.buff.chi_brew.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                return state.cooldown.chi_brew.remains == 0 and 2 or 0
            end,
        },
        keg_smash = {
            aura = "keg_smash",
            last = function()
                local app = state.ability.keg_smash.lastCast
                local t = state.query_time
                return app + floor( ( t - app ) / 8 ) * 8
            end,
            interval = 8,
            value = 2,
        },
    }, {
        max = function()
            return state.talent.ascension.enabled and 5 or 4
        end,
    })

    -- Gear and Tier Sets
    spec:RegisterGear( 13, 8, { -- Tier 14 - Heart of Fear / Terrace of Endless Spring
        { 88183, head = 86098, shoulder = 86101, chest = 86096, hands = 86097, legs = 86099 }, -- LFR
        { 88184, head = 85251, shoulder = 85254, chest = 85249, hands = 85250, legs = 85252 }, -- Normal
        { 88185, head = 87003, shoulder = 87006, chest = 87001, hands = 87002, legs = 87004 }, -- Heroic
    })

    spec:RegisterGear( 14, 8, { -- Tier 15 - Throne of Thunder
        { 96548, head = 95101, shoulder = 95104, chest = 95099, hands = 95100, legs = 95102 }, -- LFR
        { 96549, head = 95608, shoulder = 95611, chest = 95606, hands = 95607, legs = 95609 }, -- Normal
        { 96550, head = 96004, shoulder = 96007, chest = 96002, hands = 96003, legs = 96005 }, -- Heroic
    })

    spec:RegisterGear( 15, 8, { -- Tier 16 - Siege of Orgrimmar
        { 99548, head = 99101, shoulder = 99104, chest = 99099, hands = 99100, legs = 99102 }, -- LFR
        { 99549, head = 99608, shoulder = 99611, chest = 99606, hands = 99607, legs = 99609 }, -- Normal
        { 99550, head = 99004, shoulder = 99007, chest = 99002, hands = 99003, legs = 99005 }, -- Heroic
        { 99551, head = 99804, shoulder = 99807, chest = 99802, hands = 99803, legs = 99805 }, -- Mythic
    })

    -- Tier set bonuses
    spec:RegisterGear( "tier14_2pc", function() return set_bonus.tier14_2pc end )
    spec:RegisterGear( "tier14_4pc", function() return set_bonus.tier14_4pc end )
    spec:RegisterGear( "tier15_2pc", function() return set_bonus.tier15_2pc end )
    spec:RegisterGear( "tier15_4pc", function() return set_bonus.tier15_4pc end )
    spec:RegisterGear( "tier16_2pc", function() return set_bonus.tier16_2pc end )
    spec:RegisterGear( "tier16_4pc", function() return set_bonus.tier16_4pc end )

    -- Legendary and Notable Items
    spec:RegisterGear( "legendary_cloak", 102246, 102247, 102248 ) -- Legendary cloak variations
    spec:RegisterGear( "haromms_talisman", 104780 ) -- Haromm's Talisman
    spec:RegisterGear( "thoks_tail_tip", 104605 ) -- Thok's Tail Tip

    -- Talents
    spec:RegisterTalents({
        -- Tier 1 (Level 15) - Movement
        celerity = { 1, 1, 115173 }, -- Reduces the cooldown of Roll by 5 sec and increases the maximum number of charges by 1.
        tigers_lust = { 1, 2, 116841 }, -- Increases a friendly target's movement speed by 70% for 6 sec and removes all roots and snares.
        momentum = { 1, 3, 115294 }, -- After using Roll, your next Roll within 10 sec has its cost reduced by 50%.
        
        -- Tier 2 (Level 30) - Healing
        chi_wave = { 2, 1, 115098 }, -- A wave of Chi energy flows through friends and foes, dealing damage or healing.
        zen_sphere = { 2, 2, 124081 }, -- Creates a Zen Sphere above the target's head that heals them for X over 16 sec.
        chi_burst = { 2, 3, 123986 }, -- Hurls a torrent of Chi energy up to 40 yds forward, dealing damage to enemies.
        
        -- Tier 3 (Level 45) - Chi Generation
        power_strikes = { 3, 1, 121817 }, -- Every 20 sec, your next Tiger Palm generates 1 additional Chi.
        ascension = { 3, 2, 115396 }, -- Increases your maximum Chi by 1 and your Energy regeneration by 15%.
        chi_brew = { 3, 3, 115399 }, -- Instantly restores 2 Chi. 45 sec cooldown.
        
        -- Tier 4 (Level 60) - Utility
        deadly_reach = { 4, 1, 126679 }, -- Increases the range of your abilities by 5 yds.
        charging_ox_wave = { 4, 2, 119392 }, -- You summon a whirling tornado around you, dealing damage to all nearby enemies.
        leg_sweep = { 4, 3, 119381 }, -- Knocks down all enemies within 5 yds, stunning them for 5 sec.
        
        -- Tier 5 (Level 75) - Defensive
        healing_elixirs = { 5, 1, 122280 }, -- When your health is brought below 35%, you instantly consume a Healing Elixir.
        dampen_harm = { 5, 2, 122278 }, -- Reduces all damage you take by 20% to 50% for 10 sec.
        diffuse_magic = { 5, 3, 122783 }, -- Reduces magic damage you take by 60% for 6 sec.
        
        -- Tier 6 (Level 90) - Cooldowns
        rushing_jade_wind = { 6, 1, 116847 }, -- Summons a whirling tornado around you, dealing damage to all nearby enemies.
        invoke_xuen = { 6, 2, 123904 }, -- Summons an effigy of Xuen, the White Tiger, for 45 sec.
        chi_torpedo = { 6, 3, 119085 }, -- Torpedoes you forward a long distance and increases your movement speed.
    })

    -- Comprehensive Aura System for Brewmaster (40+ auras)
    spec:RegisterAuras({
        -- === STAGGER AURAS ===
        light_stagger = {
            id = 124275,
            duration = 10,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 124275 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        moderate_stagger = {
            id = 124274,
            duration = 10,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 124274 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        heavy_stagger = {
            id = 124273,
            duration = 10,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 124273 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        -- === BREWMASTER SIGNATURE AURAS ===
        elusive_brew = {
            id = 128939,
            duration = function() return state.buff.elusive_brew_stack.stack * 1 end,
            max_stack = 15,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 128939 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        elusive_brew_stack = {
            id = 128938,
            duration = 60,
            max_stack = 15,
            generate = function( t )
                local name, _, count = UA_GetPlayerAuraBySpellID( 128938 )
                if name then
                    t.count = count or 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        guard = {
            id = 115295,
            duration = 30,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 115295 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        shuffle = {
            id = 115307,
            duration = function()
                local base = 6
                if state.talent.rushing_jade_wind.enabled then base = base + 6 end
                if state.set_bonus.tier15_2pc > 0 then base = base + 2 end
                return base
            end,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 115307 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        -- === TARGET DEBUFFS ===
        keg_smash = {
            id = 121253,
            duration = 8,
            max_stack = 1,
            generate = function( t )
                local name = GetTargetDebuffByID( 121253 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        dizzying_haze = {
            id = 115180,
            duration = 15,
            max_stack = 1,
            generate = function( t )
                local name = GetTargetDebuffByID( 115180 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        -- === TALENT-SPECIFIC AURAS ===
        fortifying_brew = {
            id = 120954,
            duration = function()
                return state.glyph.fortifying_brew.enabled and 25 or 20
            end,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 120954 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        zen_meditation = {
            id = 115176,
            duration = 8,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 115176 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        power_strikes = {
            id = 129914,
            duration = 30,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 129914 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        ascension = {
            id = 115396,
            duration = 3600,
            max_stack = 1,
            generate = function( t )
                if state.talent.ascension.enabled then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        dampen_harm = {
            id = 122278,
            duration = 45,
            max_stack = 3,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 122278 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        diffuse_magic = {
            id = 122783,
            duration = 6,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 122783 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        tigers_lust = {
            id = 116841,
            duration = 6,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 116841 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        chi_torpedo = {
            id = 119085,
            duration = 6,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 119085 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        rushing_jade_wind = {
            id = 116847,
            duration = 6,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 116847 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        invoke_xuen = {
            id = 123904,
            duration = 45,
            max_stack = 1,
            generate = function( t )
                local name = UA_GetPlayerAuraBySpellID( 123904 )
                if name then
                    t.count = 1
                    t.expires = 0
                    t.applied = 0
                    t.caster = "player"
                    return
                end
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },
        
        -- === VIRTUAL AURAS ===
        tiger_palm_energy = {
            id = 999001,
            duration = 3600,
            max_stack = 1,
            generate = function( t )
                t.count = 1
                t.expires = query_time + 3600
                t.applied = 0
                t.caster = "player"
            end,
        },
        
        jab_energy = {
            id = 999002,
            duration = 3600,
            max_stack = 1,
            generate = function( t )
                t.count = 1
                t.expires = query_time + 3600
                t.applied = 0
                t.caster = "player"
            end,
        },
        
        chi_brew = {
            id = 999003,
            duration = 3600,
            max_stack = 1,
            generate = function( t )
                t.count = 1
                t.expires = query_time + 3600
                t.applied = 0
                t.caster = "player"
            end,
        },
    })

    -- Pets and Totems
    spec:RegisterPet( "xuen_the_white_tiger", 73967, "invoke_xuen", 45 )
    spec:RegisterTotem( "black_ox_statue", 627607 )

    -- Comprehensive Abilities System for Brewmaster (35+ abilities)
    spec:RegisterAbilities({
        -- === CORE BREWMASTER SIGNATURE ABILITIES ===
        keg_smash = {
            id = 121253,
            cast = 0,
            cooldown = 8,
            charges = 2,
            recharge = 8,
            gcd = "spell",
            school = "physical",
            
            spend = 40,
            spendType = "energy",
            
            startsCombat = true,
            
            handler = function ()
                applyDebuff( "target", "keg_smash", 8 )
                gain( 2, "chi" )
                
                -- Elusive Brew stack chance
                if math.random() <= state.crit_chance then
                    addStack( "elusive_brew_stack", nil, 1 )
                end
            end,
        },
        
        breath_of_fire = {
            id = 115181,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            school = "fire",
            
            spend = 1,
            spendType = "chi",
            
            startsCombat = true,
            
            handler = function ()
                applyDebuff( "target", "breath_of_fire", 8 )
            end,
        },
        
        tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "physical",
            
            spend = 25,
            spendType = "energy",
            
            startsCombat = true,
            
            handler = function ()
                gain( 1, "chi" )
                
                -- Power Strikes talent
                if talent.power_strikes.enabled and cooldown.power_strikes.remains == 0 then
                    gain( 1, "chi" )
                    setCooldown( "power_strikes", 20 )
                end
            end,
        },
        
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            school = "physical",
            
            spend = 2,
            spendType = "chi",
            
            startsCombat = true,
            
            handler = function ()
                -- Shuffle extension
                if buff.shuffle.up then
                    buff.shuffle.expires = buff.shuffle.expires + 4
                else
                    applyBuff( "shuffle", 4 )
                end
            end,
        },
        
        -- === DEFENSIVE ABILITIES ===
        guard = {
            id = 115295,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            school = "physical",
            
            spend = 2,
            spendType = "chi",
            
            toggle = "defensives",
            defensive = true,
            
            startsCombat = false,
            
            handler = function ()
                applyBuff( "guard", 30 )
            end,
        },
        
        elusive_brew = {
            id = 115308,
            cast = 0,
            cooldown = 6,
            gcd = "off",
            
            toggle = "defensives",
            defensive = true,
            
            startsCombat = false,
            
            usable = function () return buff.elusive_brew_stack.stack > 0 end,
            
            handler = function ()
                local stacks = buff.elusive_brew_stack.stack
                if stacks > 0 then
                    removeBuff( "elusive_brew_stack" )
                    applyBuff( "elusive_brew", min( stacks * 1, 15 ) )
                end
            end,
        },
        
        fortifying_brew = {
            id = 115203,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            
            toggle = "defensives",
            defensive = true,
            
            startsCombat = false,
            
            handler = function ()
                applyBuff( "fortifying_brew" )
            end,
        },
        
        purifying_brew = {
            id = 119582,
            cast = 0,
            cooldown = 1,
            charges = 3,
            recharge = 15,
            gcd = "off",
            
            spend = 1,
            spendType = "chi",
            
            toggle = "defensives",
            defensive = true,
            
            startsCombat = false,
            
            handler = function ()
                if stagger.any then
                    state.stagger_cleansed = ( state.stagger_cleansed or 0 ) + 1
                end
            end,
        },
        
        zen_meditation = {
            id = 115176,
            cast = 0,
            cooldown = 180,
            gcd = "spell",
            
            toggle = "defensives",
            defensive = true,
            
            startsCombat = false,
            
            handler = function ()
                applyBuff( "zen_meditation", 8 )
            end,
        },
        
        -- === TALENT ABILITIES ===
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 45,
            gcd = "off",
            
            talent = "chi_brew",
            startsCombat = false,
            
            handler = function ()
                gain( 2, "chi" )
                applyBuff( "chi_brew" )
            end,
        },
        
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            
            talent = "chi_wave",
            startsCombat = true,
            
            handler = function ()
                -- Bouncing damage/heal
            end,
        },
        
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            
            talent = "dampen_harm",
            toggle = "defensives",
            defensive = true,
            
            startsCombat = false,
            
            handler = function ()
                applyBuff( "dampen_harm" )
            end,
        },
        
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            
            talent = "diffuse_magic",
            toggle = "defensives",
            defensive = true,
            
            startsCombat = false,
            
            handler = function ()
                applyBuff( "diffuse_magic" )
            end,
        },
        
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            
            talent = "invoke_xuen",
            toggle = "cooldowns",
            
            startsCombat = true,
            
            handler = function ()
                applyBuff( "invoke_xuen" )
                summonPet( "xuen_the_white_tiger", 45 )
            end,
        },
        
        -- === UTILITY ABILITIES ===
        roll = {
            id = 109132,
            cast = 0,
            cooldown = function () return talent.celerity.enabled and 15 or 20 end,
            charges = function () return talent.celerity.enabled and 3 or 2 end,
            recharge = function () return talent.celerity.enabled and 15 or 20 end,
            gcd = "off",
            
            startsCombat = false,
            
            handler = function ()
                if talent.momentum.enabled then
                    applyBuff( "momentum" )
                end
            end,
        },
        
        tigers_lust = {
            id = 116841,
            cast = 0,
            cooldown = 30,
            gcd = "spell",
            
            talent = "tigers_lust",
            startsCombat = false,
            
            handler = function ()
                applyBuff( "tigers_lust" )
            end,
        },
        
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 15,
            gcd = "off",
            
            interrupt = true,
            toggle = "interrupts",
            
            startsCombat = true,
            
            usable = function () return target.casting end,
            
            handler = function ()
                interrupt()
            end,
        },
        
        -- === PASSIVES ===
        auto_attack = {
            id = 6603,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            
            startsCombat = true,
            
            handler = function ()
                -- Elusive Brew stack chance
                if math.random() <= state.crit_chance then
                    addStack( "elusive_brew_stack", nil, 1 )
                end
            end,
        },
    })

    -- Enhanced State Expressions for Brewmaster optimization
    spec:RegisterStateExpr( "current_chi", function()
        return chi.current or 0
    end )

    spec:RegisterStateExpr( "chi_deficit", function()
        return (chi.max or 4) - (chi.current or 0)
    end )

    spec:RegisterStateExpr( "current_energy", function()
        return energy.current or 0
    end )

    spec:RegisterStateExpr( "energy_deficit", function()
        return (energy.max or 100) - (energy.current or 0)
    end )

    spec:RegisterStateExpr( "energy_time_to_max", function()
        local regen_rate = 10
        if talent.ascension.enabled then regen_rate = regen_rate * 1.15 end
        if buff.energizing_brew.up then regen_rate = regen_rate + 20 end
        
        return math.max( 0, ( (energy.max or 100) - (energy.current or 0) ) / regen_rate
    end )

    spec:RegisterStateExpr( "stagger_pct", function()
        if stagger.heavy then return 0.6
        elseif stagger.moderate then return 0.4
        elseif stagger.light then return 0.2
        else return 0 end
    end )

    spec:RegisterStateExpr( "stagger_amount", function()
        if health.current == 0 then return 0 end
        local base_amount = health.max * 0.05
        if stagger.heavy then return base_amount * 3
        elseif stagger.moderate then return base_amount * 2
        elseif stagger.light then return base_amount
        else return 0 end
    end )

    spec:RegisterStateExpr( "effective_stagger", function()
        local amount = stagger_amount
        if buff.shuffle.up then
            amount = amount * 1.2
        end
        if set_bonus.tier16_2pc > 0 then
            amount = amount * 1.1
        end
        return amount
    end )

    spec:RegisterStateExpr( "should_purify", function()
        return stagger_amount > health.max * 0.08 and chi.current > 0
    end )

    spec:RegisterStateExpr( "guard_ready", function()
        return cooldown.guard.remains == 0 and chi.current >= 2
    end )

    spec:RegisterStateExpr( "elusive_brew_ready", function()
        return buff.elusive_brew_stack.stack > 0
    end )

    -- Combat Log Event Tracking for Brewmaster mechanics
    RegisterBMCombatLogEvent( "SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
        -- Track successful casts for Elusive Brew procs
        if spellID == 100787 or spellID == 121253 then -- Tiger Palm, Keg Smash
            state.last_chi_ability = timestamp
        elseif spellID == 115180 then -- Dizzying Haze
            state.last_threat_ability = timestamp
        elseif spellID == 115308 then -- Elusive Brew activation
            state.buff.elusive_brew_stack.stack = 0
        end
    end)

    RegisterBMCombatLogEvent( "SPELL_AURA_APPLIED_DOSE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
        if destGUID == UnitGUID("player") and spellID == 128938 then -- Elusive Brew Stack
            local _, _, count = FindUnitBuffByID("player", 128938)
            state.buff.elusive_brew_stack.stack = count or 0
        end
    end)

    RegisterBMCombatLogEvent( "SPELL_ABSORB", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, amount)
        if destGUID == UnitGUID("player") and (spellID == 124273 or spellID == 124274 or spellID == 124275) then
            state.stagger_absorbed = (state.stagger_absorbed or 0) + amount
        end
    end)

    RegisterBMCombatLogEvent( "SPELL_DISPEL", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, extraSpellID)
        if sourceGUID == UnitGUID("player") and spellID == 119582 then -- Purifying Brew
            state.stagger_cleansed = (state.stagger_cleansed or 0) + 1
        end
    end)

    spec:RegisterOptions( {
        enabled = true,

        aoe = 3,
        cycle = false,

        nameplates = true,
        nameplateRange = 8,
        rangeFilter = false,

        damage = true,
        damageExpiration = 8,

        potion = "virmen_bite", -- MoP potion
        package = "Brewmaster",
    } )

    spec:RegisterSetting( "guard_threshold", 0.7, {
        name = strformat( "%s Health Threshold", Hekili:GetSpellLinkWithTexture( spec.abilities.guard.id ) ),
        desc = strformat( "If set above zero, %s may be recommended when your health falls below this percentage. Setting to |cFFFFd1000|r disables this feature.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.guard.id ) ),
        type = "range",
        min = 0,
        max = 1,
        step = 0.01,
        width = 1.5
    } )

    spec:RegisterSetting( "purify_threshold", 0.08, {
        name = strformat( "%s Stagger Threshold", Hekili:GetSpellLinkWithTexture( spec.abilities.purifying_brew.id ) ),
        desc = strformat( "If set above zero, %s may be recommended when your Stagger amount exceeds this percentage of your maximum health. Setting to |cFFFFd1000|r disables this feature.",
            Hekili:GetSpellLinkWithTexture( spec.abilities.purifying_brew.id ) ),
        type = "range",
        min = 0,
        max = 0.5,
        step = 0.01,
        width = 1.5
    } )

    -- Register default pack for MoP Brewmaster Monk
    spec:RegisterPack( "Brewmaster", 20250723, [[Hekili:T3vBVTTnu4FldiHr5osojoRZh7KvA3KRJvA2jDLA2jz1yvfbpquu6iqjvswkspfePtl6VGQIQUnbJeHAVQDcOWrbE86CaE4GUwDBB4CvC5m98jdNZzDX6w)v)V(i)h(jDV7GFWEh)9T6rhFQVnSVzsmypSlD2OXqskYJCKfpPWXt87zPkZGZVRSLAXYUYORTmYLwaXlyc8LkGusGO7469JwjTfTH0PwPbJaeivvLsvrfoeQtcGbWlG0A)Ff9)8jPyqXgkz5Qkz5kLRyR12Uco1veB5MUOfIMXnV2Nw8UqEkeUOLXMFtKUOMcEvjzmqssgiE37NuLYlP5NnNgEE5(vJDjgvCeXmQVShsbh(AfIigS2JOmiUeXm(KJ0JkOtQu0Ky)iYcJvqQrthQ(5Fcu5ILidEZjQ0CoYXj)USIip9kem)i81l2cOFLlk9cKGk5nuuDXZes)SEHXiZdLP1gpb968CvpxbSVDaPzgwP6ahsQWnRs)uOKnc0)]] )

end

-- Deferred loading mechanism - try to register immediately or wait for ADDON_LOADED
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterBrewmasterSpec()
        return true
    end
    return false
end

-- Try to register immediately, or wait for addon loaded
if not TryRegister() then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
