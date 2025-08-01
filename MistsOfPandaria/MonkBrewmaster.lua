-- MonkBrewmaster.lua July 2025
-- by Smufrik, Tacodilla , Uilyam

local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

-- Define FindUnitBuffByID and FindUnitDebuffByID from the namespace
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Create frame for deferred loading and combat log events
local bmCombatLogFrame = CreateFrame("Frame")

-- Define Brewmaster specialization registration
local function RegisterBrewmasterSpec()
    -- Create the Brewmaster spec (268 is Brewmaster in MoP)
    local spec = Hekili:NewSpecialization(268, true)

    spec.name = "Brewmaster"
    spec.role = "TANK"
    spec.primaryStat = 2 -- Agility

    -- Ensure state is properly initialized
    if not state then
        state = Hekili.State
    end

    -- Force Chi initialization with fallback
    local function UpdateChi()
        local chi = UnitPower("player", 12) or 0
        local maxChi = UnitPowerMax("player", 12) or (state.talent.ascension.enabled and 5 or 4)

        state.chi = state.chi or {}
        state.chi.current = chi
        state.chi.max = maxChi

        return chi, maxChi
    end

    UpdateChi() -- Initial Chi sync

    -- Ensure Chi stays in sync, but not so often it overwrites prediction.
    for _, fn in pairs({ "resetState", "refreshResources" }) do
        spec:RegisterStateFunction(fn, UpdateChi)
    end

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
        -- No special energy regeneration mechanics for Brewmaster in MoP
    }, {
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end
    })

    -- Talents for MoP Brewmaster Monk
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

    -- Auras for Brewmaster Monk
    spec:RegisterAuras({
        tiger_power = { 
            id = 125359, -- This is the Spell ID for the Tiger Power buff
            duration = 20, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 125359)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        elusive_brew_stacks = {
            id = 128939, -- This is the Spell ID for the stacks buff itself
            duration = 30,
            max_stack = 15,
            emulated = true,
            generate = function(t)
                -- Find the buff on the player by its ID
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 128939)
                if name then
                    -- If the buff exists, update its state
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                -- If the buff doesn't exist, reset its state
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        legacy_of_the_emperor = { 
            id = 115921, 
            duration = 3600, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115921)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        shuffle = { 
            id = 115307, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115307)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        elusive_brew = { 
            id = 115308, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115308)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        fortifying_brew = { 
            id = 115203, 
            duration = 15, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115203)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        guard = { 
            id = 115295, 
            duration = 30, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 115295)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        dampen_harm = { 
            id = 122278, 
            duration = 10, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122278)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        diffuse_magic = { 
            id = 122783, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 122783)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        breath_of_fire_dot = { 
            id = 123725, 
            duration = 8, 
            tick_time = 2, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("target", 123725)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        heavy_stagger = { 
            id = 124273, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124273)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        moderate_stagger = { 
            id = 124274, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124274)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        light_stagger = { 
            id = 124275, 
            duration = 10, 
            tick_time = 1, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID("player", 124275)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        zen_sphere = { 
            id = 124081, 
            duration = 16, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 124081)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        },
        rushing_jade_wind = { 
            id = 116847, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116847)
                if name then
                    t.name = name; t.count = count; t.expires = expirationTime; t.applied = expirationTime - duration; t.caster = caster; return
                end
                t.count = 0; t.expires = 0; t.applied = 0; t.caster = "nobody"
            end
        }
    })

    -- State Expressions

    spec:RegisterStateExpr("elusive_brew_stacks", function()
        -- This now points directly to the stack count of our new aura
        return state.buff.elusive_brew_stacks.count
    end)

    spec:RegisterStateExpr("stagger_level", function()
        if state.buff.heavy_stagger and state.buff.heavy_stagger.up then
            return "heavy"
        elseif state.buff.moderate_stagger and state.buff.moderate_stagger.up then
            return "moderate"
        elseif state.buff.light_stagger and state.buff.light_stagger.up then
            return "light"
        end
        return "none"
    end)

    -- Abilities for Brewmaster Monk
    spec:RegisterAbilities({
        expel_harm = {
            id = 115072,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(1, "chi")
                gain(0.05 * health.max, "health") -- ADDED: Simulates the self-heal
            end,
            generate = function(t) end
        },
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 10,
            gcd = "off",
            toggle = "interrupts",
            startsCombat = true,
            handler = function() end
        },
        legacy_of_the_emperor = {
            id = 115921,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            toggle = "buffs",
            startsCombat = false,
            handler = function() applyBuff("legacy_of_the_emperor", 3600) end,
            generate = function(t) end
        },
        chi_burst = {
            id = 123986,
            cast = 1,
            cooldown = 30,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            talent = "chi_burst",
            startsCombat = true,
            handler = function() spend(2, "chi") end,
            generate = function(t) end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            talent = "zen_sphere",
            startsCombat = true,
            handler = function() applyBuff("zen_sphere", 16) end,
            generate = function(t) end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            talent = "invoke_xuen",
            toggle = "cooldowns",
            startsCombat = true,
            handler = function() end,
            generate = function(t) end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "dampen_harm",
            toggle = "defensives",
            startsCombat = false,
            handler = function() applyBuff("dampen_harm", 10) end,
            generate = function(t) end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "diffuse_magic",
            toggle = "defensives",
            startsCombat = false,
            handler = function() applyBuff("diffuse_magic", 6) end,
            generate = function(t) end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            talent = "chi_wave",
            startsCombat = true,
            handler = function() end,
            generate = function(t) end
        },
        elusive_brew = {
            id = 115308,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            startsCombat = false,
            handler = function()
                state.elusive_brew_manual_stacks = 0
                applyBuff("elusive_brew", 6)
            end,
            generate = function(t) end
        },
        jab = {
            id = 100780,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(1, "chi")
                if state.talent.power_strikes.enabled and math.random() <= 0.2 then
                    gain(1, "chi")
                end
            end,
            generate = function(t) end
        },
        keg_smash = {
            id = 121253,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(2, "chi")
                applyDebuff("target", "breath_of_fire_dot", 8)
            end,
            generate = function(t) end
        },
        tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 25,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                applyBuff("tiger_power", 20)
            end,
            generate = function(t) end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyBuff("shuffle", 6)
            end,
            generate = function(t) end
        },
        purifying_brew = {
            id = 119582,
            cast = 0,
            cooldown = 1,
            gcd = "off",
            spend = 1,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                removeDebuff("heavy_stagger")
                removeDebuff("moderate_stagger")
                removeDebuff("light_stagger")
            end,
            generate = function(t) end
        },
        guard = {
            id = 115295,
            cast = 0,
            cooldown = 30,
            gcd = "off",
            spend = 2,
            spendType = "chi",
            startsCombat = false,
            handler = function()
                applyBuff("guard", 30)
            end,
            generate = function(t) end
        },
        breath_of_fire = {
            id = 115181,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyDebuff("target", "breath_of_fire_dot", 8)
            end,
            generate = function(t) end
        },
        rushing_jade_wind = {
            id = 116847,
            cast = 0,
            cooldown = 6,
            gcd = "spell",
            spend = 1,
            spendType = "chi",
            talent = "rushing_jade_wind",
            startsCombat = true,
            handler = function()
                spend(1, "chi")
                applyBuff("rushing_jade_wind", 6)
            end,
            generate = function(t) end
        },
        fortifying_brew = {
            id = 115203,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                applyBuff("fortifying_brew", 15)
            end,
            generate = function(t) end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            handler = function()
                gain(2, "chi") -- This is the correct function call
            end,
            generate = function(t) end
        },
       spinning_crane_kick = {
            id = 101546,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2, -- CORRECTED from 1
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(2, "chi") -- CORRECTED from 1
            end,
            generate = function(t) end
        },
        expel_harm = {
            id = 115072,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            spend = 40,
            spendType = "energy",
            startsCombat = true,
            handler = function()
                gain(1, "chi")
            end,
            generate = function(t) end
        },
        energizing_brew = {
            id = 115288,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            startsCombat = false,
            handler = function() end,
            generate = function(t) end
        }
    })

bmCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")

bmCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_POWER_UPDATE" then
        local unit, powerTypeString = ...

        -- Only update for the player and if the Brewmaster spec is active
        if unit == "player" and state.spec.id == 268 then
            if powerTypeString == "CHI" then
                local currentChi = UnitPower(unit, 12)
                if state.chi.current ~= currentChi then
                    state.chi.current = currentChi
                    state.chi.actual = currentChi
                    Hekili:ForceUpdate(event) -- Force a display refresh
                end
            elseif powerTypeString == "ENERGY" then
                local currentEnergy = UnitPower(unit, 3)
                if state.energy.current ~= currentEnergy then
                    state.energy.current = currentEnergy
                    state.energy.actual = currentEnergy
                    Hekili:ForceUpdate(event) -- Force a display refresh
                end
            end
        end
    end
end)

    -- Options
    spec:RegisterOptions({
        enabled = true,
        aoe = 2,
        cycle = false,
        nameplates = true,
        nameplateRange = 8,
        damage = true,
        damageExpiration = 8,
        package = "Brewmaster"
    })

    spec:RegisterSetting("use_purifying_brew", true, {
        name = strformat("Use %s", Hekili:GetSpellLinkWithTexture(119582)), -- Purifying Brew
        desc = "If checked, Purifying Brew will be recommended based on stagger level.",
        type = "toggle",
        width = "full"
    })

    spec:RegisterSetting("proactive_shuffle", true, {
        name = "Proactive Shuffle",
        desc = "If checked, Blackout Kick will be recommended to maintain Shuffle proactively.",
        type = "toggle",
        width = "full"
    })

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:TIvxZTjou0FlD2zYSDAJR)ijnDN4mtsQZSUtxNob39rabimQgqmcrs9(a)23ReyqaciP7(qYylKUNZ9kDp6ymNzU10WdXXMBMpD(5t)4IztMpBX5ZMzAWpKGnnsqU7r7GpeJIG)Fld)CekLJz52BXPCXeoesrEIaLsZyUWKmnCYiH81XMo6I(zNDgm3eSlm8fxAAeq88WfZfN6AASnGKMBl(dLBxIFUn1h(UlNqJZTdjPC4X(uGf)jEpjKmbicJ6tcb4)TC7)IgV)pYTvy7xGr)EmXNG9YT)gJqze(HCBh4pJOmFgz)7Hmc5s9iHHO8VixW3EC1Dp8x3EZ28VuaD6Keg2Lg5G4VB5hcX7qUhSO(w8aSfokbZOS3t8x(gNmF)jPCepDswI(fNqfJ9ErzD5teweo2YHWXLiF6PNMB)5v3VAJX6)ELrXaIhuuCefGIsuwQiHePbWbyjyFCCk5jm8ipsAsicEckgMcdlk5IYMCIC6UDH4j1CZRALa5W)mbhAfGyrI0jaJc5btG0ZfhZVA5NMEs5YRxupbkjJr8pqI3z5a7fIGbvLD7WmRq8t4WRxMI5C4XqTroZIHpXnGmXnJXa4UE5SxmA7YqmpDmUcf5mSkEmSRbfLaAOxt8M)IXdhMj(yvUvS5EI6Wwq(6UpvjrB80Ak8sXeo0ZBvs7nBlN7X8nXL)IHXdbhNJRocWrHqONOm6eCmYje7DsB0V4LF6WJ47dhGTIq7iUQWOoEfqV0O(padttcWmSsiRhCO4vitSz99Rx95C7hFy7nBx)Wg5ORJbzewwIOd60RZTVJc7A0NJl)6n0v52Faet2cRJcD(cHQJ8dif08HyqHl2doraQnLCJTdZN4csuW(1rcrQrsrmqfpHwqDOfvkq5ikvgYIy4wnBLjsIFIUhB9ZmCSsLrz02LgTrb6vQo5vgIJdvTEL(PRwk(se6NNoFWW6esPEw(zSdJLgoywkMThQy6NPsn7HhxPSnwjIEhLbsGih4IdobxPIsGRwCO8GIDrPQPyBvb694DwPWnkbnzo0HtZ4w7jU7fuQq9pa(pqmgocrItVArlrMsEkp3Ctnt(95VtCpK4Cr6BvrHLLgiA6)bYdB9mj2tP(35z62iUE5IteHdKEWX4ianjluYdggbQeW1z(KIENwYIdU60esCSGeUmumUQw0EnN1wRvwS6MaI9YYsKb8Kq8XQsZQ1SJd)wz33wz9awcOs5bhtgCBQbroEiDwRSC5S2N9Fg9eU1zFXqhl5DAvYyP829kIX0Vhnx987TF)(7bZm3SEZ2vBUzZDWrLtYTVF9x)6Qh7idWjIRvtqHrvNblhI(mMvDo8c1108EEiLz7ouXLlN2OpUQcPgGFGCAvkVAHEszA8eSHadRAgCXSpo9CtJNrmXrNutJ1rjWDwIMXfTS7bwvmnKFs6zTs0g(2gPn2YYP5TMgUG5omJGaVLnUCk3(QL52FAQSm2r(30OaqiuvLLcpPmssXd0Al7)BpzMCOe1Bg1W)uU91qcP1dLmhv2xkM6SXs9Mg2euzXRQ4oItl9SA(ySsgmbzoRxYu49sgin(VAvO07bBmwOUkbzo)xRY01v2ya3YZNa7l6f7(TQjHrh1Uy0ocLOjq)JJIUohCJcI6IeWC5yW01v3yyuVcaaUuibLfYhwfPPpnviQ9QvdrhRETer66V8xXC5WQeTDfvZUk3I6K2AAYC4U)(TpQwG0WaLvmClDpUl7QHiodxE9eq8w6jAyWXioCtC)RV2R6iTI9hHkpS6AN0SXOXj7RZgBn2vMyhUftNlwOulVzwRiUA9rXQLaLpn2ECVoy1JvbfA6uRdl6eZwf2bTEly9SP9FBJ(RWgHrnDylHOFrhDX6SHU)CaN0QItDSPl5r)sjDqtTtBM20wy0OVtdn3d(p4Txs7rLNABpVPiG4jY48YeHuTTpAtq1kKa0VmtFo1L9AxuhpvR0Dfig9Nkizr)svn9(djtU9Lt1O02A7xRNzbs97qOD8wuhd4xtixSuusxExhq5L3vVp1HV((nL9ghFHS1Xw7BWTv5T77s(18IKRFhY6UWU4LQR86FvmItlVLxMPOmEGGzIaxEZf308F)d]])
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

-- Attempt immediate registration or wait for ADDON_LOADED
if not TryRegister() then
    bmCombatLogFrame:RegisterEvent("ADDON_LOADED")
    bmCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
