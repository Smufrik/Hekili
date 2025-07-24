-- MoP Brewmaster Monk (Data-Driven Rework V6.0)
-- Hekili Specialization File
-- FINAL VERSION 4: July 23, 2025 - Added manual Energy Regen override.

-- Boilerplate and Class Check
if not Hekili or not Hekili.NewSpecialization then return end
if select(2, UnitClass('player')) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

-- Helper functions
local strformat = string.format

-- Brewmaster specific combat log tracking
local bm_combat_log_events = {}

local function RegisterBMCombatLogEvent(event, callback)
    if not bm_combat_log_events[event] then
        bm_combat_log_events[event] = {}
    end
    table.insert(bm_combat_log_events[event], callback)
end

-- Declare the frame here, but do not create it yet.
local bmCombatLogFrame

local function RegisterBrewmasterSpec()
    if not class or not state or not Hekili.NewSpecialization then return end

    local spec = Hekili:NewSpecialization( 268 ) -- Brewmaster spec ID for MoP
    if not spec then return end -- Not ready yet
    
    -- Create and register the combat log frame ONLY when the Brewmaster spec is being initialized.
    if not bmCombatLogFrame then
        bmCombatLogFrame = CreateFrame("Frame")
        bmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        bmCombatLogFrame:SetScript("OnEvent", function(self, event)
            -- Add a spec check as a final safeguard.
            if not state or not state.spec or state.spec.id ~= 268 then return end
            
            local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, _, _, amount, _, _, _, _, _, critical = CombatLogGetCurrentEventInfo()
            if sourceGUID ~= state.GUID and destGUID ~= state.GUID then return end

            if bm_combat_log_events[subevent] then
                for _, callback in ipairs(bm_combat_log_events[subevent]) do
                    callback(timestamp, subevent, sourceGUID, destGUID, spellID, amount, critical)
                end
            end
        end)
    end

    -- Enhanced resource registration for Brewmaster Monk
    spec:RegisterResource(3, { -- Energy with Brewmaster-specific mechanics
        -- Energizing Brew energy restoration (Brewmaster signature cooldown)
        energizing_brew = {
            aura = "energizing_brew",
            last = function ()
                local app = state.buff.energizing_brew.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                -- Energizing Brew provides massive energy boost
                return state.buff.energizing_brew.up and 20 or 0 -- +20 energy per second during Energizing Brew
            end,
        },
        
        -- Chi Brew energy boost (if talented)
        chi_brew = {
            aura = "chi_brew_energy",
            last = function ()
                local app = state.buff.chi_brew_energy.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                -- Chi Brew provides energy alongside Chi
                return state.buff.chi_brew_energy.up and 15 or 0 -- +15 energy per second briefly after Chi Brew
            end,
        },
        
        -- Tiger Palm energy refund mechanics
        tiger_palm_efficiency = {
            last = function ()
                return state.query_time -- Continuous tracking
            end,
            interval = 1,
            value = function()
                -- Tiger Palm reduces energy costs of other abilities
                return state.buff.tiger_power.up and 1 or 0 -- +1 energy per second with Tiger Power active
            end,
        },
        
        -- Ascension talent bonus (if talented)
        ascension = {
            last = function ()
                return state.query_time -- Continuous passive
            end,
            interval = 1,
            value = function()
                -- Ascension provides passive energy bonus
                return state.talent.ascension.enabled and 2 or 0 -- +2 energy per second with Ascension
            end,
        },
    }, {
        -- Enhanced base energy regeneration for MoP Brewmaster
        base_regen = 10, -- Base 10 energy per second in MoP
        haste_scaling = false, -- Energy doesn't scale with haste in MoP
        
        regenerates = function()
            local base = 10 -- Standard energy regen
            local bonus = 0
            
            -- Stance-specific bonuses
            if state.buff.stance_of_the_sturdy_ox.up then
                bonus = bonus + 1 -- +1 energy per second in Ox Stance
            end
            
            -- Combat efficiency
            if state.combat then
                bonus = bonus + 1 -- +1 energy per second in combat (Monk training)
            end
            
            return base + bonus
        end,
    } )
    
    spec:RegisterResource(12, -- Chi (secondary resource for Brewmaster)
        {},
        {
            max = function() return state.talent.ascension.enabled and 5 or 4 end
        }
    )

    -- This hook runs on every update and manually sets the correct energy regen.
    spec:RegisterHook("reset_precast", function()
        if state.energy then
            local base = 10
            if state.talent.ascension.enabled then base = base * 1.15 end
            if state.buff.energizing_brew.up then base = base + 20 end
            
            -- Hekili stores the per-second regen rate in 'active_regen'.
            state.energy.active_regen = base * state.haste
        end
    end)

    --[[
        Comprehensive Gear, Talent, and Glyph Registration
    ]]
    spec:RegisterGear( "tier14", 85468, 85471, 85474, 85477, 85480 )
    spec:RegisterGear( "tier15", 95094, 95097, 95100, 95103, 95106 )
    spec:RegisterGear( "tier16", 99250, 99253, 99256, 99259, 99262 )
    spec:RegisterGear( "tier14_2pc", function() return state.set_bonus.tier14_2pc end)
    spec:RegisterGear( "tier14_4pc", function() return state.set_bonus.tier14_4pc end)
    spec:RegisterGear( "tier15_2pc", function() return state.set_bonus.tier15_2pc end)
    spec:RegisterGear( "tier15_4pc", function() return state.set_bonus.tier15_4pc end)
    spec:RegisterGear( "tier16_2pc", function() return state.set_bonus.tier16_2pc end)
    spec:RegisterGear( "tier16_4pc", function() return state.set_bonus.tier16_4pc end)
    spec:RegisterGear( "legendary_cloak_tank", 102246 )
    spec:RegisterGear( "steadfast_talisman", 102305 )
    spec:RegisterGear( "thoks_tail_tip", 102300 )
    spec:RegisterGear( "haromms_talisman", 102298 )

    -- Talents
    spec:RegisterTalents({
        celerity        = { 1, 1, 115173 },
        tigers_lust     = { 1, 2, 116841 },
        momentum        = { 1, 3, 115174 },
        chi_wave        = { 2, 1, 115098 },
        zen_sphere      = { 2, 2, 124081 },
        chi_burst       = { 2, 3, 123986 },
        power_strikes   = { 3, 1, 121817 },
        ascension       = { 3, 2, 115396 },
        chi_brew        = { 3, 3, 115399 },
        ring_of_peace   = { 4, 1, 116844 },
        charging_ox_wave= { 4, 2, 119392 },
        leg_sweep       = { 4, 3, 119381 },
        healing_elixirs = { 5, 1, 122280 },
        dampen_harm     = { 5, 2, 122278 },
        diffuse_magic   = { 5, 3, 122783 },
        rushing_jade_wind = { 6, 1, 116847 },
        invoke_xuen     = { 6, 2, 123904 },
        chi_torpedo     = { 6, 3, 115008 },
    })

    -- Glyphs
    spec:RegisterGlyphs( {
        [146961] = "clash",
        [125672] = "expel_harm",
        [125687] = "fortifying_brew",
        [125677] = "guard",
        [146958] = "stoneskin",
        [125679] = "touch_of_death",
    })

    -- Auras and Debuffs
    spec:RegisterAuras({
        shuffle = { id = 115307, duration = 6, dr_type = "parry" },
        guard = { id = 115295, duration = 30, absorb = true },
        elusive_brew_stack = { id = 128938, duration = 30, max_stack = 15 },
        elusive_brew = { id = 128939, dr_type = "dodge" },
        stance_of_the_sturdy_ox = { id = 115069 },
        energizing_brew = { id = 115288, duration = 20 },
        fortifying_brew = { id = 115203, duration = 20, dr = 0.2 },
        dampen_harm = { id = 122278, duration = 45, max_stack = 3 },
        diffuse_magic = { id = 122783, duration = 6, dr_type = "magic" },
        zen_meditation = { id = 115176, duration = 8, dr = 0.9 },
        heavy_stagger = { id = 124273, duration = 10, debuff = true },
        moderate_stagger = { id = 124274, duration = 10, debuff = true },
        light_stagger = { id = 124275, duration = 10, debuff = true },
        breath_of_fire_dot = { id = 123725, duration = 8, debuff = true, dot = true },
        weakened_blows = { id = 115798, duration = 30, debuff = true },
        tier14_4pc = { id = 124473, duration = 12 },
        tier16_2pc = { id = 144634, duration = 10 },
    })

    -- Abilities
    spec:RegisterAbilities({
        keg_smash = { id = 121253, cooldown = 8, spend = 40, spend_type = "energy", handler = function() state.gain(2, "chi"); state.applyDebuff("target", "weakened_blows", 30) end },
        blackout_kick = { id = 100784, spend = 2, spend_type = "chi", handler = function() state.applyBuff("player", "shuffle", 6) end },
        jab = { id = 100780, spend = 40, spend_type = "energy", handler = function() state.gain(1, "chi") end },
        tiger_palm = { id = 100787, spend = 25, spend_type = "energy" },
        expel_harm = { id = 115072, cooldown = 15, spend = 40, spend_type = "energy", handler = function() state.gain(1, "chi") end },
        breath_of_fire = { id = 115181, spend = 2, spend_type = "chi", handler = function() state.applyDebuff("target", "breath_of_fire_dot", 8) end },
        spinning_crane_kick = { id = 101546, spend = 40, spend_type = "energy", aoe = true, usable = function() return state.active_enemies >= 3 end },
        rushing_jade_wind = { id = 116847, cooldown = 6, spend = 1, spend_type = "chi", talent = "rushing_jade_wind", aoe = true },
        purifying_brew = { id = 119582, cooldown = 1, spend = 1, spend_type = "chi", toggle = "defensives", usable = function() local level = spec:GetStaggerLevel(); return level == "heavy" or level == "moderate" end },
        guard = { id = 115295, cooldown = 30, spend = 2, spend_type = "chi", toggle = "defensives", handler = function() state.applyBuff("player", "guard", 30) end },
        elusive_brew = { id = 115308, cooldown = 1, toggle = "defensives", usable = function() return state.buff.elusive_brew_stack.stack >= state.settings.elusive_brew_threshold end, handler = function() local s = state.buff.elusive_brew_stack.stack or 0; state.removeBuff("player", "elusive_brew_stack"); state.applyBuff("player", "elusive_brew", s) end },
        fortifying_brew = { id = 115203, cooldown = 180, toggle = "cooldowns", handler = function() state.applyBuff("player", "fortifying_brew", 20) end },
        energizing_brew = { id = 115288, cooldown = 60, toggle = "cooldowns", handler = function() state.applyBuff("player", "energizing_brew", 20); state.gain(state.chi.max, "chi") end },
        invoke_xuen = { id = 123904, cooldown = 180, toggle = "cooldowns", talent = "invoke_xuen" },
        summon_black_ox_statue = { id = 115315, cooldown = 30 },
        chi_brew = { id = 115399, cooldown = 45, charges = 2, talent = "chi_brew", handler = function() state.gain(2, "chi"); state.addStack("elusive_brew_stack", nil, 2) end },
        chi_wave = { id = 115098, cooldown = 15, talent = "chi_wave" },
        zen_meditation = { id = 115176, cooldown = 180, toggle = "defensives" },
        dampen_harm = { id = 122278, cooldown = 90, toggle = "defensives", talent = "dampen_harm" },
        diffuse_magic = { id = 122783, cooldown = 90, toggle = "defensives", talent = "diffuse_magic" },
        provoke = { id = 115546, cooldown = 8 },
        spear_hand_strike = { id = 116705, cooldown = 15, interrupt = true },
        stance_of_the_sturdy_ox = { id = 115069, handler = function() state.applyBuff("player", "stance_of_the_sturdy_ox") end },
    })

    -- Advanced State Tracking
    ns.stagger_tick_amount = 0
    ns.last_stagger_tick_time = 0
    spec.GetStaggerLevel = function()
        if state.buff.heavy_stagger.up then return "heavy" end
        if state.buff.moderate_stagger.up then return "moderate" end
        if state.buff.light_stagger.up then return "light" end
        return "none"
    end

    -- State Expressions
    spec:RegisterStateExpr("stagger_dtps", function()
        if state.query_time - (ns.last_stagger_tick_time or 0) > 1.5 then return 0 end
        return ns.stagger_tick_amount or 0
    end)
    spec:RegisterStateExpr("stagger_level", function()
        local level = spec:GetStaggerLevel(); if level == "heavy" then return 3 end; if level == "moderate" then return 2 end; if level == "light" then return 1 end; return 0
    end)
    spec:RegisterStateExpr("shuffle_gap", function()
        if state.buff.shuffle.up then return 0 end; local time_to_keg = state.cooldown.keg_smash.remains; if not state.energy or not state.energy.regen or state.energy.regen == 0 then return time_to_keg end; local energy_for_kick = 2 * (40 / state.energy.regen); return math.min(time_to_keg, energy_for_kick)
    end)
    spec:RegisterStateExpr("time_to_die", function()
        if state.stagger_dtps == 0 then return 999 end; local total_dtps = state.stagger_dtps + (state.unmitigated_dtps or 0); if total_dtps == 0 then return 999 end; return state.health.current / total_dtps
    end)

    -- Combat Log Event Processing
    RegisterBMCombatLogEvent("SPELL_PERIODIC_DAMAGE", function(timestamp, subevent, sourceGUID, destGUID, spellID, amount, critical)
        if destGUID == state.GUID and (spellID == 124273 or spellID == 124274 or spellID == 124275) then ns.stagger_tick_amount = amount; ns.last_stagger_tick_time = GetTime() end
    end)
    RegisterBMCombatLogEvent("SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, destGUID, spellID, amount, critical)
        if sourceGUID == state.GUID and critical and (spellID == 100780 or spellID == 115072 or spellID == 121253) then state.addStack(128938, nil, 1) end
    end)

    -- Addon Options
    spec:RegisterOptions({ enabled = true, aoe = 3, package = "Brewmaster" })

    -- User Settings
    spec:RegisterSetting("proactive_shuffle", true, { name = "Proactive Shuffle Management", type = "toggle" })
    spec:RegisterSetting("purify_level", 2, { name = "Purify at Stagger Level", desc="1=Light, 2=Moderate, 3=Heavy", type = "range", min = 1, max = 3, step = 1 })
    spec:RegisterSetting("elusive_brew_threshold", 8, { name = "Elusive Brew Stack Threshold", type = "range", min = 1, max = 15, step = 1 })
    spec:RegisterSetting("guard_health_threshold", 65, { name = "Reactive Guard Health %", type = "range", min = 30, max = 90, step = 5 })
    spec:RegisterSetting("fortify_health_pct", 35, { name = function() return strformat("Use %s Below Health %%", Hekili:GetSpellLinkWithTexture(115203)) end, desc = "The health percentage at which Fortifying Brew will be recommended.", type = "range", min = 0, max = 100, step = 5, width = "full" })

    -- Default APL Pack
spec:RegisterPack("Brewmaster", 20250724, [[Hekili:nEvBtUPnq4)n(AstC8zF(Y12Z3mn9ln30MjZ40(LobqgwmkwGOsIZN7Cd)27UcWimGD(qCoKw9Sp7Q9fTEx79fV1rmd49P5ZMVC27NVy68Rx((536T2Cih8wNZc3X2I)rglf)LPJO1oiKSi6SAzHkex3B9McUW8XmVndd4su2Ciex(278wNWJIGkzbDO36VKW1Lb0)yLb1QSmqgJFhA4YSYabxBWTJLQYGFh2Xf8PERTls0iukfrY9z0hFYAuqgBJaI8(aUPIBafNHMetazMP8SNK7a)NlGSPnYTUsrERD20ZG0DuWGmqT9W0WcLcbTm4(vLb3mRmyszqycV76x3IV9y8)JNT1FJc2t6yXLimINv4g2oSsOfszpxg82YG5TkS5WOMmK)oMvimh9tnsTd26Rtz6exMCw7hXTm4buVZT05hkd2uehpvNG)kGPkiLXZ0vuBrzWlVugObJbnC90CLKu8tGFT4wig)8BdJQmTxBX6vT8EJaJwKfg)D8WDN3zMamHjzAoGrSn(S7w24lXVp6cDUTEohe(jmvkH9nFVoJiWAlOBNzs8LX(XCf4hjntPOuRi12pgoKYbD9HDSRohLu(YlfLOk0juy13yrG)EEw0PHlvk56wFD)tq0RLe92N4XTJYJHmPfwTnkdJ46tY)058SmsOqfldoET((Z76pn(3jH7BSnea3Dj3hLNSN9e0VKqZoem)03D9aY6VBwlkg(wq5NZePhZeHmn6WUqrlTHTLoPaEcevW2MhvO4XhA2QZTCRIReYTGZ4j1dLJCuBBlyQi)kr8njkqNGLD7QxNqyR4NpL0gfcIcYnyzNpATH7MA)9eBTJyh1UtQQZ(Npz9Sgj2HXq(0AZmp00QI69CDLxmRmILMdz2siDYhhIelDcxCo35Z6A0dpoUqd(PST8WlQPBD1K7jRInZvqOmDdRFFc8MjleO6sMeS6TPqfDWx(C3Ugwm2ZuuESM6UJ135P5O3RUd(v1THUQmqb)BbwHdPQwMIYXkmYu8beruqflBlONw(OfHyPqiXQgBjHumSaZEqHRJChfMJLvnKyUVyGQZzAKltAvFrwhPJIiHXNSW2W0Wpx(OT(rVkv46pw9kfS3vmN6yrFKY1AlJ0f5o23wQyape1HINTdmOneug8rt1HSo3uilI4TjHHlJjWQde2CjEXEGiyOOiIQIcCKOQgI9p)LgiKGu9xFdAzj8WexPzzhA1ATnJnXe8qUr0IRRlOrP)c(IlvJA(sfeyHKVsGg5U0ChnVNleowunKMgrTEd7szfPBGQ7zb2hS8XpAdiOfU5KN5HBIbCfMePcdEyHsBY26AhV363Ie8pLFUm4d464BwWebAHmSIXV(5)aFkYVjtZzg(g8vIKV8VbLgr)vLpsNS(l0mMoJUvP1SXxxDmQ)QtJIuf0lrKyKpgrbOrH)FLOO5yyklNRoc94MAywnsYsxT22hONAtOG8naGlOX8hbpMBdzK2GEYTl4uwxtooLYaH7Cjtl6R62h4n84vDAT8WQbBRmblT)WQRhcXFC17S14jO6wK5(vxOPrfQZhbv3s5e4NTnHdVhUfXik5KI5N1i63uyeqDQAtaoEpGjNQRLZgds3YZUGoub)EWE7jX4hNuQxWgVz8Qd4mDyLn23OpKX1u5DfM60PJq4eMDCTvoZp5q2bg5AGdtx9DhpIGO7dRUF1nZM4m7Z9UXMUi1m3JdloDoQU4u)(X3oVx(zDRQ((RgxfvlvjnmAFMOTKA3ercMvhh0Q3wiN7mndr8Q0Kj)WqJgD)QfV8Y4Junz4ZGJs96fVAiL3oRZq5c3TK8w338i7HiFNrwCy)5NgAsnTRhB40Qc1G3RHSZ16Od(ux7AYzg2ziDnWiiK2oLNlMCXXAgcDCEKAFtBi31djyZyhNea7oJYqhRDoJ(jppScNiHEDM3))]])

end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterBrewmasterSpec()
        bmCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

if not TryRegister() then
    bmCombatLogFrame:RegisterEvent("ADDON_LOADED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
