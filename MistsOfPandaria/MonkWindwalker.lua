-- MonkWindwalker.lua July 2025
-- Adapted from MonkBrewmaster.lua by Smufrik, Tacodilla, Uilyam

if select(2, UnitClass('player')) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

-- Early return if Hekili is not available
if not Hekili or not Hekili.NewSpecialization then return end

local strformat = string.format



-- Define FindUnitBuffByID and FindUnitDebuffByID from the namespace
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Create frame for deferred loading and combat log events
local wwCombatLogFrame = CreateFrame("Frame")

-- Define Windwalker specialization registration
local function RegisterWindwalkerSpec()
    -- Create the Windwalker spec (269 is Windwalker in MoP)
    local spec = Hekili:NewSpecialization(269, true)

    spec.name = "Windwalker"
    spec.role = "DPS"
    spec.primaryStat = 2 -- Agility

    -- Ensure state is properly initialized
    if not state then
        state = Hekili.State
    end

    -- Register Chi resource (ID 12 in MoP)
    -- Use default resource state (with metatable); UnitPowerMax already reflects Ascension.
    spec:RegisterResource(12, {})

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
        base_energy_regen = {
            last = function ()
                return state.query_time
            end,
            interval = 1,
            value = function()
                local base = 10 -- Base energy regen (10 energy per second)
                local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
                return base * haste_bonus
            end,
        },
        energizing_brew = {
            aura = "energizing_brew",
            last = function ()
                local app = state.buff.energizing_brew.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                return state.buff.energizing_brew.up and 20 or 0 -- Additional 20 energy per second
            end,
        },
    })

    -- Talents for MoP Windwalker Monk
    spec:RegisterTalents({
        celerity = { 1, 1, 115173 },
        tigers_lust = { 1, 2, 116841 },
        momentum = { 1, 3, 115174 },
        chi_wave = { 2, 1, 115098 },
        zen_sphere = { 2, 2, 124081 },
        chi_burst = { 2, 3, 123986 },
        power_strikes = { 3, 1, 121817 },
        ascension = { 3, 2, 115396 },
        chi_brew = { 3, 3, 115399 },
        deadly_reach = { 4, 1, 115176 },
        charging_ox_wave = { 4, 2, 119392 },
        leg_sweep = { 4, 3, 119381 },
        healing_elixirs = { 5, 1, 122280 },
        dampen_harm = { 5, 2, 122278 },
        diffuse_magic = { 5, 3, 122783 },
        rushing_jade_wind = { 6, 1, 116847 },
        invoke_xuen = { 6, 2, 123904 },
        chi_torpedo = { 6, 3, 115008 }
    })

    -- Auras for Windwalker Monk
    spec:RegisterAuras({
        tigereye_brew = {
            id = 1247279,
            duration = 120,
            max_stack = 20
        },
        tigereye_brew_use = {
            id = 1247275,
            duration = 15,
            max_stack = 1
        },
        touch_of_karma = {
            id = 122470,
            duration = 10,
            max_stack = 1

        },
        tiger_power = {
            id = 125359,
            duration = 20,
            max_stack = 1

        },
        power_strikes = {
            id = 129914,
            duration = 1,
            max_stack = 1

        },
        combo_breaker_tp = {
            id = 116768,
            duration = 15,
            max_stack = 1

        },
        combo_breaker_bok = {
            id = 116767,
            duration = 15,
            max_stack = 1

        },
        energizing_brew = {
            id = 115288,
            duration = 6,
            max_stack = 1

        },
        rising_sun_kick = {
            id = 130320,
            duration = 15,
            max_stack = 1
        },
        zen_sphere = {
            id = 124081,
            duration = 16,
            max_stack = 1
        },
        rushing_jade_wind = {
            id = 116847,
            duration = 6,
            max_stack = 1
        },
        dampen_harm = {
            id = 122278,
            duration = 10,
            max_stack = 1
        },
        diffuse_magic = {
            id = 122783,
            duration = 6,
            max_stack = 1
        },
        legacy_of_the_emperor = {
            id = 117666,
            duration = 3600,
            max_stack = 1
        },
        legacy_of_the_white_tiger = {
            id = 116781,
            duration = 3600,
            max_stack = 1
        },
        death_note = {
            id = 121125,
            duration = 3600,
            max_stack = 1
        }
    })

    -- Abilities for Windwalker Monk
    spec:RegisterAbilities({
        legacy_of_the_emperor = {
            id = 115921,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,

            handler = function()
                applyBuff("legacy_of_the_emperor", 3600)
            end
        },
        legacy_of_the_white_tiger = {
            id = 116781,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = false,

            handler = function()
                applyBuff("legacy_of_the_white_tiger", 3600)
            end
        },
        expel_harm = {
            id = 115072,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            startsCombat = true,

            spend = 40,
            spendType = "energy",

            handler = function()
                gain(1, "chi")
            end
        },
        tigereye_brew = {
            id = 1247275,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            startsCombat = false,

            toggle = "cooldowns",

            handler = function()
                -- Consume current Tigereye Brew stacks (simplified MoP model: each stack grants damage buff percentage; we just track duration)
                if buff.tigereye_brew.up and buff.tigereye_brew.stack > 0 then
                    -- Apply a use buff; we can store the consumed stacks in v1 for scaling if needed later.
                    local stacks = buff.tigereye_brew.stack
                    removeBuff("tigereye_brew")
                    applyBuff("tigereye_brew_use", 15)
                    buff.tigereye_brew_use.v1 = stacks
                end
            end
        },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "spell",
            startsCombat = true,

            spend = 3,
            spendType = "chi",

            toggle = "cooldowns",

            handler = function()
                removeBuff("death_note")
            end
        },

        jab = {
            id = 100780,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = true,

            spend = 40,
            spendType = "energy",

            handler = function()
                local chi_gain = talent.power_strikes.enabled and buff.power_strikes.up and 3 or 2
                gain(chi_gain, "chi")

                if talent.power_strikes.enabled and buff.power_strikes.up then
                    removeBuff("power_strikes")
                end
            end,

            copy = { 108561, 115697, 120267, 121278, 124146, 108557, 115693 },
        },

        tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = true,

            spend = function() return state.buff.combo_breaker_tp.up and 0 or 1 end,
            spendType = "chi",

            handler = function()
                applyBuff("tiger_power", 20)
                removeBuff("combo_breaker_tp")
            end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            startsCombat = true,

            spend = function() return state.buff.combo_breaker_bok.up and 0 or 2 end,
            spendType = "chi",

            handler = function()
                removeBuff("combo_breaker_bok")
            end
        },
        rising_sun_kick = {
            id = 107428,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            startsCombat = true,

            spend = 2,
            spendType = "chi",

            handler = function()
                applyDebuff("target", "rising_sun_kick", 15)
            end
        },
        fists_of_fury = {
            id = 113656,
            cast = 0,
            cooldown = 25,
            gcd = "spell",
            startsCombat = true,

            spend = 3,
            spendType = "chi",

            handler = function() end
        },
        spinning_crane_kick = {
            id = 101546,
            cast = function()
                return talent.rushing_jade_wind.enabled and 0 or 3
            end,
            cooldown = function()
                return talent.rushing_jade_wind.enabled and 6 or 0
            end,
            gcd = "spell",
            startsCombat = true,

            channeled = function()
                return talent.rushing_jade_wind.enabled and false or true
            end,

            spend = 2,
            spendType = "chi",

            handler = function() end
        },
        energizing_brew = {
            id = 115288,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            startsCombat = false,

            handler = function()
                applyBuff("energizing_brew", 6)
            end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 45,
            charges = 2,
            startsCombat = false,

            gcd = "off",
            talent = "chi_brew",

            handler = function() end
        },
        rushing_jade_wind = {
            id = 116847,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            startsCombat = true,

            spend = 40,
            spendType = "energy",

            talent = "rushing_jade_wind",

            handler = function()
                -- Gain chi if hits three or more enemies
                local chi_gain = active_enemies >= 3 and 1 or 0
                if chi_gain > 0 then
                    gain(chi_gain, "chi")
                end
                applyBuff("rushing_jade_wind", 6)
            end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            startsCombat = true,

            talent = "zen_sphere",

            handler = function()
                applyBuff("zen_sphere", 16)
            end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            startsCombat = true,

            talent = "chi_wave",

            handler = function() end
        },
        chi_burst = {
            id = 123986,
            cast = 1,
            cooldown = 30,
            gcd = "spell",
            startsCombat = true,

            spend = 2,
            spendType = "chi",

            talent = "chi_burst",

            handler = function()
                spend(2, "chi") -- CORRECTED: Added spend command
            end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            startsCombat = true,

            talent = "invoke_xuen",
            toggle = "cooldowns",

            handler = function() end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            startsCombat = false,

            talent = "dampen_harm",
            toggle = "defensives",

            handler = function()
                applyBuff("dampen_harm", 10)
            end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            startsCombat = false,

            talent = "diffuse_magic",
            toggle = "defensives",

            handler = function()
                applyBuff("diffuse_magic", 6)
            end
        },
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 10,
            gcd = "off",
            startsCombat = true,

            toggle = "interrupts",

            debuff = "casting",
            readyTime = state.timeToInterrupt,

            handler = function() interrupt() end
        },
        chi_torpedo = {
            id = 115008,
            cooldown = 20,
            charges = 2,

            talent = "chi_torpedo"
        }
    })

    -- Combo tracking (basic SimC-style) to enable combo_strike / combo_break style conditions if desired.
    spec:RegisterStateTable( "combos", {
        jab = true,
        tiger_palm = true,
        blackout_kick = true,
        rising_sun_kick = true,
        fists_of_fury = true,
        spinning_crane_kick = true
    } )

    local prev_combo, actual_combo, last_combo = "none", "none", "none"
    spec:RegisterStateExpr( "last_combo", function() return actual_combo end )
    spec:RegisterStateExpr( "combo_break", function() return state.this_action == last_combo end )
    spec:RegisterStateExpr( "combo_strike", function()
        local a = state.this_action
        local c = state.combos
        return not c[ a ] or a ~= last_combo
    end )

    -- Tigereye Brew stack accumulation + combo tracking hooks.
    local chiSpentForBrew = 0

    spec:RegisterHook( "spend", function( amt, resource )
        if resource == "chi" and amt > 0 then
            -- Track Tigereye Brew stacks: 1 stack per 4 chi spent (simplified), max 20.
            chiSpentForBrew = chiSpentForBrew + amt
            while chiSpentForBrew >= 4 do
                chiSpentForBrew = chiSpentForBrew - 4
                if buff.tigereye_brew.up then
                    buff.tigereye_brew.stack = math.min( 20, ( buff.tigereye_brew.stack or 0 ) + 1 )
                else
                    applyBuff( "tigereye_brew" )
                    buff.tigereye_brew.stack = 1
                end
                if buff.tigereye_brew.stack >= 20 then
                    chiSpentForBrew = 0
                    break
                end
            end
        end
    end )

    spec:RegisterHook( "runHandler", function( key )
        local c = state.combos
        if c[ key ] then
            if last_combo == key then
                -- If we wanted to model a hit_combo style buff we could remove it here; placeholder for future.
            else
                prev_combo = actual_combo
                actual_combo = key
            end
            last_combo = key
        end
    end )

    spec:RegisterHook( "reset_precast", function() chiSpentForBrew = 0 end )

    spec:RegisterStateExpr("time_to_max_energy", function()
        if state.energy.active_regen and state.energy.active_regen > 0 then
            local deficit = state.energy.max - state.energy.current
            if deficit <= 0 then
                return 0
            end
            return deficit / state.energy.active_regen
        end
        return 3600 -- Large number indicating it will never be reached
    end)

    -- Temporary expression to fix a warning about missing threat value
    -- Should probably remove this
    spec:RegisterStateExpr("threat", function()
        return {
            situation = threat_situation or 0,
            percentage = threat_percent or 0
        }
    end)

    -- Consolidated event handler
    wwCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")
    wwCombatLogFrame:RegisterEvent("ADDON_LOADED")

    wwCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_POWER_UPDATE" then
            local unit, powerTypeString = ...
            if unit == "player" and state.spec.id == 269 then
                if powerTypeString == "CHI" then
                    local currentChi = UnitPower(unit, 12)
                    if state.chi.current ~= currentChi then
                        state.chi.current = currentChi
                        state.chi.actual = currentChi
                        Hekili:ForceUpdate(event)
                    end
                elseif powerTypeString == "ENERGY" then
                    local currentEnergy = UnitPower(unit, 3)
                    if state.energy.current ~= currentEnergy then
                        state.energy.current = currentEnergy
                        state.energy.actual = currentEnergy
                        Hekili:ForceUpdate(event)
                    end
                end
            end
        elseif event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == "Hekili" or TryRegister() then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end
    end )

    -- Options
    spec:RegisterOptions({
        enabled = true,
        aoe = 3,
        cycle = false,
        nameplates = true,
        nameplateRange = 8,
        damage = true,
        damageExpiration = 8,
        package = "Windwalker"
    })

    spec:RegisterSetting("use_energizing_brew", true, {
        name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(115288)), -- Energizing Brew
        desc = "If checked, Energizing Brew will be recommended when energy is low.",
        type = "toggle",
        width = "full"
    })

    spec:RegisterSetting("energizing_brew_energy", 40, {
        name = "Energizing Brew Energy Threshold (%)",
        desc = "Energizing Brew will be recommended when your energy drops below this percentage.",
        type = "range", min = 10, max = 80, step = 5,
        width = "full"
    })

    spec:RegisterSetting("chi_brew_chi", 2, {
        name = "Chi Brew Chi Threshold",
        desc = "Chi Brew will be recommended when you have fewer than this many Chi.",
        type = "range", min = 0, max = 4, step = 1,
        width = "full"
    })

    spec:RegisterSetting("defensive_health_threshold", 60, {
        name = "Defensive Health Threshold (%)",
        desc = "Defensive abilities (Dampen Harm, Diffuse Magic) will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 90, step = 5,
        width = "full"
    })

    spec:RegisterPack("Windwalker", 20250806, [[Hekili:LM1EVTTnq8plbdWijT2ZpZshScqxxbAd2kgGcW(pjrlrzXAzrbjQ46Ia9zFhPSKOLiPvYAr3S5J7997UJ2zMZto2big25BZNoF107ND3K5txD3S7CSzhtXo2Pi)DOTWhsq7H)7)sscoGI3HZ4BDmMIc4KiNwK5dBBt2)PmuiR0B1Y7hFVJ9Mcsm7RjoBuZMvo2OcwefO2xi7Xih7isqaU684CFh7NIi5LE8)Hk9ojmLE0q47(mcnP0lMKZGTdPzLEFbVJetMaYwgnKeds0Vu6930KD)EPxROx(iSAhrT8r(FH1Tu)hXE)tgE8NO73GGBzJzfPMVrLeMpjnd7lU17S(1y8wK)rxAOllc7I3NIZOzVNeATPimCsodXYNeqpKms8DLNwS)qO(Hicd7YiBXTCWpJW0YaPlyGjPuHH)YMR)ehItYjpJb3ZFbEPHzTcAUfWRaeOZjUrOS9CvGHIXjG83U6eCcAtmoOsDy0c)iU2Sd2cvPNryumlAsQpBT1Dt1Xhsyyro2DpAlXxMtYR)651fnrFIMHhKzPXU34j3etPbXf5SjfPV8cdLTfZMWGSixg1nGGptBHRZvdW9UpxEXn4SCC2osYw5v9JiUBYWhKme1l1ydGfwBnF01SmsYoGZqgN)eWkftyhfs01(rCzk3A2ii4r8zxU4T2A20BE5L6DNRu2pT7TWrLfmrOPBkkEFJz40s0dqmBgEpIKKV2Abx8EWAwV7IpIB0S2RxVQlyJKsooBpEUP)oR5tFZ0uisGfthTb5DLsJXYP3mkalUwgjh8vU5fjU7i(7ad9OEwboSuRiItWzBj)KFRgx6jAVh9dxX2hFyL8v6We(v0WEj96v4Me3sdfp5cFy2ifs5mfUvsYZ0Dy3FuGtKcxLwToI9mneyx13C5LpEpV4MfII5uGV(Zyol3tW5pyT4IxKRbXGSk8C9jX6fdaiWwqJXpjOrP312pDZGWfMCgZ52(AyPamIf1y)fFZnHYW8ygHzCHEIOicOJxU3vc5LH58nSi7ydB7e9v56v4zx2pmUosy5fLwo20b0Z4oWv8LAGRuWtdkJaTRilN1fbKV2BKM)eQyLNgbz9V3)OFZoa(OetApKrUm6Qa6zhMbEjzq8ECFtmGWqlyn(ZQUbGA6uUNbbTf5UHURj4WGIOi7(C6WsBWL6Trde98U5Y94Z3rBof4nb09XxsS6PHvgR3v9)MCkNmdVfNCRpLgZdf1c)yTCAJD4I5UFeuVX0WXFome7ZtE)i9Zdm7fWCeOk5rCX47OaOjmOpvPiIE71wbUrj6DePsaNyXBn67IbAvKFaPGQUYfZX6zPucmvhJ0905PKKe(59Zqj4MBC1LmT99pdb1)uYj02LJ9ZqFvWXRN3zkmp1bugxwYDS)6(uAgdyJ3QoJXmP8rhBXNetvjZbyHVjgx7Km68hWStI7cJQDgMF1OtzK0Qn1fdQSKJUiwhB(Gd4mcIptx36jLEJk9aFqP3daDx4Wa9UJO2E9MZnVvb64w5eyHwcOTWIqm6dxcCR0BPytDfzKoIKA0iENvBJlCl1kC6c(niAs2H6RX5XQHWJZtwgote3JZL70es1MYRGZ9XjmYAXMxv6PgkbOVmGepkhKRFZS7xvHRZDFsk8zvg4e)(xdXfvZAJE0vrR0BTvTU2ieZKYrBQAYLGpyk9qaL5nwTYavf5ey2uTuO20)Uspf1(k9Ufi8fQ)vX1LthSjLXbDcrfXgXPQMGDO4tIzJhmGK84WLEV8ceo2BsQkFeGpxdqvlynZgll21Gqn6CZSYDo1GqdKhEU1S2gZCniWQhLUsBUMFdXqXGnbISex6SbRRO2mWPDt1vKp)Cd2ePtE7jc0bTaKDZqs6bw5Y0IbMv0fmsf97nxDhG9ZNPUs3N2HH1Nzaang4zBErTduVuiu7vg9blRCCaL0oRV6AyfPgup9qDAqRx1sSo1ynJBz4fc0IIOOSVbCnLVJGjdMCX9zMQqnBGXNZ6cS1ltxX7o0smPnfutFpsNaSp9ac96hPt)OvTm6w9c9qhRcIRV)PUeF9GP95nKkq9BEyyt4(kFg7oLb6)k99EIETJtP4H5hCDJ2NCVn7s)ZUBU12QgeQFHDD0R7RSRZojDUE1IQRKkxhIv58n4h6nWZqlfREc3HyJV4OwImpttYQYK))Pl1xzJO6ZJ00QV6U5hwpcYDZRPHD91Gf4xwcCmEhKgHz1xP9kEbkZ(SwkRyaBZ1uBaDR6d7TI60(B3ykCx6NjAOb69(jREfX4k(vPKky3)xlsSz7VyuVMtnfTO83L6nXTwRLmjDozOZtX(G4C3heF15)(d]])

end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterWindwalkerSpec()
        wwCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

-- Attempt immediate registration or wait for ADDON_LOADED
TryRegister()
