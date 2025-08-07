-- MonkWindwalker.lua July 2025
-- Adapted from MonkBrewmaster.lua by Smufrik, Tacodilla, Uilyam

local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

-- Enhanced MoP Specialization Detection for Monks
function Hekili:GetMoPSpecialization()
    -- Prioritize the most defining abilities for each spec
    
    -- Windwalker check
    if IsPlayerSpell(113656) or IsPlayerSpell(107428) then -- Fists of Fury or Rising Sun Kick
        return 269
    end

    -- Brewmaster check
    if IsPlayerSpell(121253) or IsPlayerSpell(115295) then -- Keg Smash or Guard
        return 268
    end
    
    -- Mistweaver check (currently not implemented, but placeholder for completeness)
    -- if IsPlayerSpell(115175) or IsPlayerSpell(115151) then -- Soothing Mist or Renewing Mist
    --     return 270
    -- end

    return nil -- Return nil if no specific spec is detected, to allow fallbacks
end

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

    -- Initialize and update Chi
    local function UpdateChi()
        local chi = UnitPower("player", 12) or 0
        local maxChi = UnitPowerMax("player", 12) or (state.talent.ascension.enabled and 5 or 4)

        state.chi = state.chi or {}
        state.chi.current = chi
        state.chi.max = maxChi
        state.chi.actual = chi -- This was the missing line

        return chi, maxChi
    end

    -- Initialize and update Energy
    local function UpdateEnergy()
        local energy = UnitPower("player", 3) or 0
        local maxEnergy = UnitPowerMax("player", 3) or 100

        state.energy = state.energy or {}
        state.energy.current = energy
        state.energy.max = maxEnergy
        state.energy.actual = energy

        return energy, maxEnergy
    end

    UpdateChi() -- Initial Chi sync
    UpdateEnergy() -- Initial Energy sync

    -- Ensure Chi and Energy stay in sync
    for _, fn in pairs({ "resetState", "refreshResources" }) do
        spec:RegisterStateFunction(fn, UpdateChi)
        spec:RegisterStateFunction(fn, UpdateEnergy)
    end

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {}, {
        max = function() return 100 end,
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end
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
            id = 116740, -- This is the Spell ID for the Tigereye Brew buff
            duration = 15,
            max_stack = 20,
            emulated = true,
        },
        touch_of_karma = {
            id = 122470,
            duration = 10,
            max_stack = 1,
            emulated = true,
          
        },
        tiger_power = {
            id = 125359,
            duration = 20,
            max_stack = 1,
            emulated = true,
            
        },
        power_strikes = {
            id = 129914,
            duration = 1,
            max_stack = 1,
            emulated = true,
         
        },
        combo_breaker_tp = {
            id = 116768,
            duration = 15,
            max_stack = 1,
            emulated = true,
           
        },
        combo_breaker_bok = {
            id = 116767,
            duration = 15,
            max_stack = 1,
            emulated = true,
                
        },
        energizing_brew = {
            id = 115288,
            duration = 6,
            max_stack = 1,
            emulated = true,
            
        },
        rising_sun_kick_debuff = {
            id = 130320,
            duration = 15,
            max_stack = 1,
            emulated = true,
        },
        zen_sphere = {
            id = 124081,
            duration = 16,
            max_stack = 1,
            emulated = true,
        },
        rushing_jade_wind = {
            id = 116847,
            duration = 6,
            max_stack = 1,
            emulated = true,
        },
        dampen_harm = {
            id = 122278,
            duration = 10,
            max_stack = 1,
            emulated = true,
        },
        diffuse_magic = {
            id = 122783,
            duration = 6,
            max_stack = 1,
            emulated = true,
        }
    })

    -- Abilities for Windwalker Monk
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
            end
        },
        tigereye_brew = {
            id = 116740,
            cast = 0,
            cooldown = 0,
            gcd = "off",
            toggle = "cooldowns",
            startsCombat = false,
            handler = function()
                removeBuff("tigereye_brew")
            end
        },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "spell",
            spend = 3,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(3, "chi")
            end
        },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "spell",
            spend = 3,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(3, "chi") -- CORRECTED: Added spend command
            end
        },
        auto_attack = {
            id = 6603,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            handler = function() end
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
            end
        },
       tiger_palm = {
            id = 100787,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            -- The cost is now 1 Chi, unless Combo Breaker makes it free.
            spend = function() return state.buff.combo_breaker_tp.up and 0 or 1 end,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                -- Only spend Chi if it's not a free cast.
                if not state.buff.combo_breaker_tp.up then
                    spend(1, "chi")
                end
                applyBuff("tiger_power", 20)
                if state.buff.combo_breaker_tp.up then
                    removeBuff("combo_breaker_tp")
                end
            end
        },
        blackout_kick = {
            id = 100784,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = function() return state.buff.combo_breaker_bok.up and 0 or 2 end,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                if not state.buff.combo_breaker_bok.up then
                    spend(2, "chi") -- CORRECTED: Added spend command
                else
                    removeBuff("combo_breaker_bok")
                end
            end
        },
        rising_sun_kick = {
            id = 107428,
            cast = 0,
            cooldown = 8,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                applyDebuff("target", "rising_sun_kick_debuff", 15)
                spend(2, "chi") -- CORRECTED: Added spend command
            end
        },
        fists_of_fury = {
            id = 113656,
            cast = 0,
            cooldown = 25,
            gcd = "spell",
            spend = 3,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(3, "chi") -- CORRECTED: Added spend command
            end
        },
        spinning_crane_kick = {
            id = 101546,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 2,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(2, "chi") -- CORRECTED: Added spend command
            end
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
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            handler = function()
                gain(2, "chi")
            end
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
                spend(1, "chi") -- CORRECTED: Added spend command
                applyBuff("rushing_jade_wind", 6)
            end
        },
        zen_sphere = {
            id = 124081,
            cast = 0,
            cooldown = 10,
            gcd = "spell",
            talent = "zen_sphere",
            startsCombat = true,
            handler = function()
                applyBuff("zen_sphere", 16)
            end
        },
        chi_wave = {
            id = 115098,
            cast = 0,
            cooldown = 15,
            gcd = "spell",
            talent = "chi_wave",
            startsCombat = true,
            handler = function() end
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
            handler = function()
                spend(2, "chi") -- CORRECTED: Added spend command
            end
        },
        invoke_xuen = {
            id = 123904,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            talent = "invoke_xuen",
            toggle = "cooldowns",
            startsCombat = true,
            handler = function() end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "dampen_harm",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                applyBuff("dampen_harm", 10)
            end
        },
        diffuse_magic = {
            id = 122783,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "diffuse_magic",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                applyBuff("diffuse_magic", 6)
            end
        },
        spear_hand_strike = {
            id = 116705,
            cast = 0,
            cooldown = 10,
            gcd = "off",
            toggle = "interrupts",
            startsCombat = true,
            handler = function() end
        }
    })

    -- Consolidated event handler
    wwCombatLogFrame:RegisterEvent("UNIT_POWER_UPDATE")
    wwCombatLogFrame:RegisterEvent("ADDON_LOADED")

    wwCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_POWER_UPDATE" then
            local unit, powerTypeString = ...
            if unit == "player" and state.spec.id == 269 then
                if powerTypeString == "CHI" then
                    -- CORRECTED: Removed 'or 0' to match Brewmaster implementation
                    local currentChi = UnitPower(unit, 12)
                    if state.chi.current ~= currentChi then
                        state.chi.current = currentChi
                        state.chi.actual = currentChi
                        Hekili:ForceUpdate(event)
                    end
                elseif powerTypeString == "ENERGY" then
                    -- CORRECTED: Removed 'or 0' to match Brewmaster implementation
                    local currentEnergy = UnitPower(unit, 3)
                    if state.energy.current ~= currentEnergy then
                        state.energy.current = currentEnergy
                        state.energy.actual = currentEnergy
                        Hekili:ForceUpdate(event)
                        if Hekili.ActiveDebug then
                            Hekili:Debug("Energy updated to %d for player", currentEnergy)
                        end
                    end
                end
            end
        elseif event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == "Hekili" or TryRegister() then
                self:UnregisterEvent("ADDON_LOADED")
            end
        end
    end)

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

    spec:RegisterPack("Windwalker", 20250722, [[Hekili:DN1EVTjsq8plrrYQnTHZVItIKDKsZvPRr9IQer6(pG1WI9gdSOfioUYIp73SS8ybVyOr5Yj1e1hMD2z(nVNbBmY4rdDhum24HXdhFXWRgotB0vxmDYmd94DHyd9qK9g0k4)eG8H)(FiboBrEBWm(r78OiholIOjmB4yd9LjeV4VfySubFhoB0yG2qSn84zxBOVM44Gf0IJSn0FCnjk1I)huQvUKtTOUWNTJj0GulpsumCSlLLA9x4nepIMHE2d5WWMYWW)(qMAHdql9WogFbEoJeJzeeirmYlETwODCQ18uRRgMAni1chGzR2LADZIuRPIhzVMOzNWy4abLxKADwQvmYdEGgkYghebaslxiPwFcUzgjN0ovg6c1aW2lHypZ1iMVq1zKqXblu)tQ1DGQLA9fW66GzGf4dFNUfhby7hmcfuVDFm1QLlBedM7wTiV76(tOLaII5kUlkXlwLdRGwBKNNP4dMCVCFTw)nIabl3Mh08Dc3q1cXIWhtr4najoSFghPYO1oQKyHnL65q3gKXHj9Mdvoe(JFgBc(fFcokZbmPMeI4wVhM(gWAUpVoVrumN5x0BMxtZzyHNnKHTP(lrk9TvWjpwbc3mxMWIIpmwP8O(64)bdF(DzIo1shhNe(kZkKHgdVTfKbNiu4kNUcfUFi)Ucw0z8AbesIWMaE9RIvlozPhL6y6MW2jdKI4XsQGcjy2gsWQgunvMkeZgfGnJPz1dAqzZ4KdmGKGNPBWMVKGvujq6qoZM1fZA6nuuSAXBt1QuRZtTgR0B)WLTcZLjUUAXKvygEhwG0OyOlMirB0Wk(vJiotVQJ6ZAWntqEcnuzzAUeKAWWVf5NGVvkknQZ8r2kCSwJEK1WnnXETj110bJIx33qBWrVYdF(JzSh(yioiVjM(JV22wGYNBwZSfFiZDw5amdH2JmnE()(9koGH9Hwe5vxtT(ydxJziYZxvbCfaySeaCWzsIrI4w(OKaZne7nM5pUanhNQ2HwJlOQlGc8njdFknnd6cl5eLhdgt85fcm9rVaSUwcIlFemEGrwrNJwziJX82duEOjcgL0CjDdik56xqwdnjUunBV0GcUfhwG7J42bdZ1T50BpdVYPFeW2EUSuDSTONXQ7QWpHZMR7In)ehygfUgkKuRGyrEG0XY22QhZfcKC3PUkYWYfkljAnps5jKd2ClSnGszFivYq4GtlNhSy4R(m2GdYhkKKneTsmuwRAdqbQiKOwXnq5MjvDtIJ9T02FwI5UAB3NXnCiUU8U6(Ove73kLsMNcdnFiV)xAeClKHEo198V66ITR3j4w6x)DPvqp6d87wn933AfhPDGQc0rHKGaopSz8jzlmZTxL)xzVeXV6pdrX8teVUJlhdIFlIXLAKH(38dPSyUAFzJ3KHw698TLOUepybQtBnbi9(tvTBZ9h7gcbfPvUm2Nw8hL4(Ze3fTPMh5QWOKnVP8843FCeDQI6L9sfQ6maarQkTewu0nyWjQlzoOQU28fZg2MyKRBkliv1O7TO60a1CnWEzFkx)eWD5wHQpUA1WwoVCPq1NxFDq10iTxNKHtXQGQVEpI0giT7Z8fxCwB7X9PPNDsBND(y1IV2UzCm02AD3Sy0q1SOX2xCMuBnU5lMoSUkmQxHgD(ka7z0cdZbz57GKJpPa1RgoqG2BAcZxNH(aj)eAzLj5ntiDA)o(AO9Y0fXRewF2hruAJ5LMlhziUu5Se8la6le9m4dNOOf((9TnIY8jFSbxB0IVK1Jbw31ua733R9qpuO1MlOuKtgOqxg0figC4yi3mUH8QTGvzcPQnipQnVTnfpe3fA(IR7cjcJDdQkwIRr9l5n(ACJQDYKUZHR3L3LP2IDndiAoUKu0wxtLLZEvZJ1JSRUMTVx5xWMjVIeS8B9wNHjyB7PyDMH1KvVJjo5y))QOH6IrXa2Qsoee3Zrq7mEtXxXtFcX4iOXxIXN5F9flQg(RBAl713nPc9K)4QV4L5t6(EGX6WlcblDFZSVggDus8AkZq)rKnT8naB8V)]])

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
