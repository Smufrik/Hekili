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

    -- Register Chi resource (ID 12 in MoP)
    spec:RegisterResource(12, {}, {
        max = function() return state.talent.ascension.enabled and 5 or 4 end
    })

    -- Register Energy resource (ID 3 in MoP)
    spec:RegisterResource(3, {
        -- No special energy regeneration mechanics for Brewmaster in MoP
    }, {
        max = function() return 100 end,
        base_regen = function()
            local base = 10 -- Base energy regen (10 energy per second)
            local haste_bonus = 1.0 + ((state.stat.haste_rating or 0) / 42500) -- Approximate haste scaling
            return base * haste_bonus
        end
    })

    -- --- Compatibility wrappers for group/raid checks (MoP-era safe) ---
            -- MoP-safe wrappers
        local function BM_IsInGroup()
            if IsInGroup then return IsInGroup() end
            local raid  = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
            local party = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or (GetNumPartyMembers and GetNumPartyMembers()) or 0
            return (raid > 0) or (party > 0)
        end

        local function BM_IsInRaid()
            if IsInRaid then return IsInRaid() end
            local raid = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
            return raid > 0
        end

        local function BM_IsInInstance()
            if IsInInstance then
                local inInstance, instanceType = IsInInstance()
                return inInstance, instanceType
            end
            -- Fallback: derive from GetInstanceInfo()
            local _, instanceType = GetInstanceInfo()
            local inInstance = instanceType and instanceType ~= "none"
            return inInstance or false, instanceType or "none"
        end


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
        -- Vengeance buff for Brewmaster Monk
        vengeance = {
            id = 132365,
            duration = 20,
            max_stack = 1,
            generate = function(t)
                local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 132365)
                
                if name then
                    t.name = name
                    t.count = count or 1
                    t.expires = expirationTime
                    t.applied = expirationTime - duration
                    t.caster = caster
                    return
                end
                
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
            end,
        },

         death_note = { 
            id = 121125, -- This is the Spell ID for the buff
            duration = 1, 
            max_stack = 1, 
            emulated = true,
        },
         power_strikes = { 
            id = 129914, -- This is the Spell ID for the Tiger Power buff
            duration = 1, 
            max_stack = 1, 
            emulated = true,
        },    
        tiger_power = { 
            id = 125359, -- This is the Spell ID for the Tiger Power buff
            duration = 20, 
            max_stack = 1, 
            emulated = true,
        },
        elusive_brew_stacks = {
            id = 128939, -- This is the Spell ID for the stacks buff itself
            duration = 30,
            max_stack = 15,
            emulated = true,
        },
        legacy_of_the_emperor = { 
            id = 115921, 
            duration = 3600, 
            max_stack = 1, 
            emulated = true,
        },
        shuffle = { 
            id = 115307, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
        },
        elusive_brew = { 
            id = 115308, 
            duration = 6, 
            max_stack = 1, 
            emulated = true,
        },
        fortifying_brew = { 
            id = 120954, 
            duration = 15, 
            max_stack = 1, 
            emulated = true,
        },
        guard = { 
            id = 115295, 
            duration = 30, 
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
        },
        dizzying_haze_dot = { 
            id = 116330, 
            duration = 15, 
            max_stack = 1,
            type = "debuff",
            unit = "target", 
        },
        breath_of_fire_dot = { 
            id = 123725, 
            duration = 8, 
            tick_time = 2, 
            max_stack = 1,
            type = "debuff",
            unit = "target", 
        },
        heavy_stagger = {
            id = 124273,
            duration = 10,
            type = "debuff",      -- important
            unit = "player",      -- debuff on you
            max_stack = 1,
        },
        moderate_stagger = { 
            id = 124274, 
            duration = 10,
            type = "debuff",      -- important
            unit = "player",      -- debuff on you
            max_stack = 1,
        },
        light_stagger = { 
            id = 124275, 
            duration = 10,
            type = "debuff",      -- important
            unit = "player",      -- debuff on you
            max_stack = 1,
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
        }
    })

    -- State Expressions
    spec:RegisterStateExpr("boss", function()
        -- ENCOUNTER_START triggered (works for raids & dungeons)
        if state.encounterID and state.encounterID ~= 0 then return true end

        -- Boss frames active
        for i = 1, 5 do
            local u = "boss" .. i
            if UnitExists(u) and UnitCanAttack("player", u) then return true end
        end

        -- World boss check
        if UnitExists("target") and UnitClassification("target") == "worldboss" then return true end

        -- Blizzard's internal boss flag (works for dungeon bosses)
        if UnitExists("target") and UnitCanAttack("player", "target") and UnitIsBossMob and UnitIsBossMob("target") then
            return true
        end

        return false
    end)

        spec:RegisterStateExpr("ingroup", function()
            return BM_IsInGroup()
        end)

        spec:RegisterStateExpr("inraid", function()
            return BM_IsInRaid()
        end)

        spec:RegisterStateExpr("ininstance", function()
            local inInst = BM_IsInInstance()
            return inInst
        end)

        spec:RegisterStateExpr("indungeon", function()
            local _, t = BM_IsInInstance()
            return t == "party" or t == "scenario"
        end)

        spec:RegisterStateExpr("inraidinstance", function()
            local _, t = BM_IsInInstance()
            return t == "raid"
        end)




    spec:RegisterStateExpr("elusive_brew_stacks", function()
        -- This now points directly to the stack count of our new aura
        return state.buff.elusive_brew_stacks.count
    end)


    spec:RegisterStateExpr("stagger_level", function()
    if state.debuff.heavy_stagger and state.debuff.heavy_stagger.up then
        return 3
    elseif state.debuff.moderate_stagger and state.debuff.moderate_stagger.up then
        return 2
    elseif state.debuff.light_stagger and state.debuff.light_stagger.up then
        return 1
    end
    return 0
    end)

    -- Vengeance state expressions
    spec:RegisterStateExpr("vengeance_stacks", function()
        if not state.vengeance then
            return 0
        end
        return state.vengeance:get_stacks()
    end)

    spec:RegisterStateExpr("vengeance_attack_power", function()
        if not state.vengeance then
            return 0
        end
        return state.vengeance:get_attack_power()
    end)

    spec:RegisterStateExpr("vengeance_value", function()
        if not state.vengeance then
            return 0
        end
        return state.vengeance:get_stacks()
    end)

    spec:RegisterStateExpr("high_vengeance", function()
        if not state.vengeance or not state.settings then
            return false
        end
        return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
    end)

    spec:RegisterStateExpr("should_prioritize_damage", function()
        if not state.vengeance or not state.settings or not state.settings.vengeance_optimization or not state.settings.vengeance_stack_threshold then
            return false
        end
        return state.settings.vengeance_optimization and state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
    end)

    -- Abilities for Brewmaster Monk
    spec:RegisterAbilities({
        auto_attack = {
                id  = 6603,
                cast     = 0,
                cooldown = 0,
                gcd      = "spell",
                handler  = function()
            end,
         },
        touch_of_death = {
            id = 115080,
            cast = 0,
            cooldown = 90,
            gcd = "on",
            toggle = "cooldowns",
            startsCombat = true,
            handler = function() end
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
        legacy_of_the_emperor = {
            id = 115921,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
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
            startsCombat = true,
            toggle = "cooldowns",
            handler = function() end,
            generate = function(t) end
        },
        dampen_harm = {
            id = 122278,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "dampen_harm",
            startsCombat = false,
            toggle = "defensives",
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
            toggle = "defensives",
            handler = function()
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
            toggle = "defensives",
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
            startsCombat = false,
            toggle = "defensives",
            handler = function()
                applyBuff("fortifying_brew", 15)
            end,
            generate = function(t) end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 45,
            charges = 2,
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            toggle = "cooldowns",
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
            spend = 2, 
            spendType = "chi",
            startsCombat = true,
            handler = function()
                spend(2, "chi") 
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
    -- Settings for Defensive Thresholds
    spec:RegisterSetting("purify_level", 2, {
        name = "Purify Stagger At",
        desc = "The stagger level at which Purifying Brew will be recommended.",
        type = "select",
        values = { [1] = "Light", [2] = "Moderate", [3] = "Heavy" },
        width = "full"
    })

    spec:RegisterSetting("guard_health_threshold", 50, {
        name = "Guard Health Threshold (%)",
        desc = "Guard will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 90, step = 5,
        width = "full"
    })

    spec:RegisterSetting("elusive_brew_threshold", 8, {
        name = "Elusive Brew Stacks Threshold",
        desc = "Elusive Brew will be recommended when you have at least this many stacks.",
        type = "range", min = 1, max = 15, step = 1,
        width = "full"
    })

    spec:RegisterSetting("fortify_health_pct", 30, {
        name = "Fortifying Brew Health Threshold (%)",
        desc = "Fortifying Brew will be recommended when your health drops below this percentage.",
        type = "range", min = 10, max = 50, step = 5,
        width = "full"
    })

    -- Vengeance system variables and settings (Lua-based calculations)
    spec:RegisterVariable( "vengeance_stacks", function()
        return state.vengeance:get_stacks()
    end )

    spec:RegisterVariable( "vengeance_attack_power", function()
        return state.vengeance:get_attack_power()
    end )

    spec:RegisterVariable( "high_vengeance", function()
        return state.vengeance:is_high_vengeance(state.settings.vengeance_stack_threshold)
    end )

    spec:RegisterVariable( "vengeance_active", function()
        return state.vengeance:is_active()
    end )

    -- Vengeance-based ability conditions (using RegisterStateExpr instead of RegisterVariable)

    spec:RegisterSetting( "vengeance_optimization", true, {
        name = strformat( "Optimize for %s", Hekili:GetSpellLinkWithTexture( 132365 ) ),
        desc = "If checked, the rotation will prioritize damage abilities when Vengeance stacks are high.",
        type = "toggle",
        width = "full",
    } )

    spec:RegisterSetting( "vengeance_stack_threshold", 5, {
        name = "Vengeance Stack Threshold",
        desc = "Minimum Vengeance stacks before prioritizing damage abilities over pure threat abilities.",
        type = "range",
        min = 1,
        max = 10,
        step = 1,
        width = "full",
    } )

    spec:RegisterPack("Brewmaster", 20250728, [[Hekili:T3vwpUTrs4FldcIgP4XY6AUYoJbsI9UXoxgrtqEyXkPwKTgrpuKA5HNmgcc5188(0(E(L5FjBv9bp7MKI6ygeSbij28O7Q(Q7Q7MAu3r3mAOjjGo6h71P3PDUOZLT7E5Px078rddEyjD0WLeJ7i3c)bhYc4)(vMKLbwFGUEYx7rVFbXpG6TEY3sVZY2A9e3zZSmSi24R9GTlXehEF3qpd4vhnCAOLDWBCgnv9CoaE2Lud4YNDXOHZTmnP8NL6BmA4nZT8xpb)xY6jcQcNr4VBey56SEITLFaC7zUruuBGq8CNzzdt)NTEY1Q)N1VfU378OgUlMscwpXNgeUKDrTVaFk9BVu(wx7hqCmOJDNnoyoDSFqON5dJD)T1VT4bcU3ROZOo(aM6x8JkgQFXhy7xBh6hjfwp5(5uG)bsW4oeF8GBm3625Na4W74yMJlWyZcTTHR9pcjEM8lB6EVdCfId83FWneVGZN(9)l8SeBpkX8byGi48amfEtteZNgoBwmeygr(p7AkNSgpfOQtSMDn(KTtEXXCASn7)9YR72PXCkXoyE7LuqhXj4QUD60G9w3IezBK(AKFuyxbVxeQ8UqpRzpy5CResEoQdq(Wdmy52BrT0Md685pRLGBtacmSbzhGrvYwVyPC0J4mJ5wTnc98aAgyJgGktaCB)2H(0XPF6ghz46AJeRGNy4Adbvn2M(bQ9lVUFb8Xp4As9a7LKSsFoRybQ)2U3ZLZOEFc2cnjKtTGPJEFplFCo2dCBZmc0Rh0z1kLqqRSyqVKA4cgbmF5sg7hew2OIDcoHzSdm)N(J)C9KZ785Cm5V76fKghT8Doowmp5ERayucSyJXsI9IIuRFbJQZbe9uRPolAUzic)ontXRG58K(RwLfQoVtl(qWORXlDVN61gDfXGL880ZfyfYXzmQfcCkWMuVy3amDfeYIWp8QCi9EId6(mWfuBMtCqlDgXYVezHBOdaG2e0JVAykdNh5bibcLt94uq9iTEq)wcg(vKflr)AFlXBbJz)EiCd6M3r44Np5uP)p4T9EiyodGO2mGjnAaE4og9nAbxWe5qDmIjBMhphM4iMiX1ktyNLPZBsuHWc34gAasLFAggHGaARLeCa1qSqU7g3xbS4IfutlqwH2nO(bgyR)Zwp5BMBjqJfukkVN667)IapIpmzEH2yuijMe4AcGrasiyGntKmYzf0VrtCiwTkG4DlnOTKznqlKorYYWflftosngKLlPanmLcailKILTzkps85EQneNWnmy8Dwg3LBQp9lci2WFQnX3afEUoTPoKP2uZNn4los39eu03rb1KHly8DZN1JrCGh1p97)hmIaOGbAtazMLIUJE7yF8TYqnxvtQ559AKCu63G6q9U9H2WSgsaNIr6k)8B)vKq7Ec3agPyUtS3nScKTxOpAym(9et647TCyEZ4odhdZ4clQpkkfuzUNwsTnICKN)r4X1A2KP9Z8Dbr79SUJcXjw2yNavTwTQ5r7VXVBRwPfgcOF438DBb07V0YXbHkdpIdnstop4FuPOFoDJ)Ab3ChN(ZH)Rnf0NwqSC8Fz32xkKdV(3wIHJ4XdaBwP8O)gjpO4Oe5Bxr(NhwuU)EgL7PrP(TKPBHs97jtr07WcvhCfY8Xvj3sWShWOPSsIOyKu8kgewIiW)c(bnMJb36lc4nZZDHieh1BhgEno6Q20cG79ncp2LwDzuTLOm16JjZDwwLbwsbxKlYHa5Vi(rgBaZGIgnirPcMsxbtckTmRBsAGHBXtoxIHyA0SgLoRYPhg5O5viULxkouwIzVx(Im51OE1LrLyQf6(mbf9tGPYmgjvnGg4pmVowQSCvmKxFL1h)ipj)VL8rroSHlpbbbubiQsMPHEyufz17d5En5p)uIZDyIosOXvqzygvSjf13Mbtzg1TRRPLJAh3x0OPjLN7SGNaVUFKcwRRwP6gJnDdGB2QH4MPjv2DvKo9lHYMuu4iVKa0oLjBqxyCGYk4yFwNQG78Qtyvn4WrEwFauvBqc4tvLGBhQLT8X8Oy(Yef8lJZmzzwNmP6K93GXtqz6Augki966YvvZEHL1FZHquyKI)E3BTmAvMDd7()aakbmFWrA8Sc3ziWcl)091WaMhv8PSRldAKPI(JsjdIQ9M7ymz6hmtvQ)srNz(bkXp0Jk7qzMMjjiJ0zEWnaKdX4fIriBWS6jfuKeJ8zth6mDrrm(mzLryP)3IJfJlJQFJfnG3Hbh3qS7bIWczzzTLl1)zD1YyARbkw4FdVZnVd5fqrs0OI(dKnftQjWYTbWDlpv6fI(SqSxKwPOzUUWG2NRwL7YcJ0RUUNmu8x9tV(lffRHt9qrY)a2Hz)dGlObYjrSACUpD)tK9GHZ4NiSBLEUwM08vq6hSc6YRiTd0oRSUyoBolN3h6f5LRuyQ0K93bmZwyQDqzV(pFtm5ACuZmjIQmXBPE)ptNboVMNmrKzYGTKPGVxUVeMPiLBBS9ERBQkI5vx3F1QS(XBLl7YFLTUgjZU8erAbstItQQuatT8Ey4YKTjEP82zr3jIC39kHxDXPi)wU3URYIPDRHVVbTECYQvQUKlJ28UbZO3OUpdD3p5RgL6Yx7(DXCuPk9Pj5scaI55sCEq2X(ki53Q4CmArsbSfpzMLTn(3ylrtC04ezlKQUrWKkzF6d9rL4kt2P117FM6cj1Mjj2rpyYr1QBeAFVaYbfcaJ252uMJHMF6p(ZEmQg1Hkn3uzdvq2DgosmUB4nCpD28X2Gn25d2ZGKKzDLF57Ez329t06a)G4EWKwBherz9LFX5XEFIYhlr716xP4vha2t0aQLCDAbzS)y6nk(gJ9zA3sU2qOPev6yYqeYKJ568(HSngbmp1KBoCzDTR4ZDPSChX9BK8wRToMJV7RXLGxKfdRu2Q6N4WuJaX9XSeHZ2nIRYuwtZS7Vvzz3Wo6wAJY5Z9OctjgP7BK989mYwDd(NggohC)C8CHuRnnJyBpfYjDpQouya6l3lOdJN1WXkng2ECO2vwxfembGmisIYJHlPBrRWzEpWmVKL7Y7gU6nkMmGoEBvjVWHaLXVRKLXr1W0O52l9BbdIwDUwGs3GYDhdi8EdFRK)4hruFqvaWQPCxKQQnN)dMtG)YGZeyMPlvUznVZbROe3wgvfB4D7yWzvXMQiVsd2BEL0xtnhuYwavcTPsQMMdnPlMopcTjSnB1BBgvq(QvP7HuCSfTzcl6LbKAdJiXYV9dkl5zbdHDCd0ygZ)RJXT99j4Ut)AZe7K6YE2axZelcd23gafPSfFrcePxz(O930rau75cpO6n82QvnLpa8Ka8X2y4L)W4Q83Qv5eUr865x2JkxPpKrtAvw3L2RsuNhT8Nc()QQ7R8xeuLvQ9M4njHbUJjb4I3pAiaaideDsd62U7z9739IrdVNWA0OpEWcWIBxS01lqu57XixCmUto(3HwSUX77UaEiCOxqy7db(oK1V963YE9zU2aoZSbjHEeSvgupQyLxzRPmB3Iqek7idH96mq(C8TNVBOtQN200LTA0bKPeF6xcMa4UGn)sgI2gk4cWCGeAhuvg57z7R2bFjU6SoaWXUTlBQqKLtyhVt0JoMVyaPhS6owT1W(sT)nJ)7wc)Vdy)h7DlHe93EW)rNtIeB9ouIT6SDn21aETOHiOQ)(hQ2DmSwR74y9BM9Dz(3uTsr16eEu9Z3Hc0ARM6nyMFmIFL7KCPrchD262mbm6a)xC8dxIJfRd1cI(ynhrpPkgMuT40cYZWoApKigmbHX2omwgat6z5ChnaM6jRN8Ma(lXi6fuhtCQHkyceNlfCSTC9ScWQ(CmSdnXQz4NphjY8pzlG6BcOl8)xNG59BHNaK4NMTcFYzva60FBPnu9yGD84MugiN0)gRZHIP5g(qay1)subr8L6LyMVhkajbhjgYa5JYqd2LCcxmLYfp2G361V9nlKO)LP1Aq50OHS)eE2qHSWH)3pYogQcl(rF9OH83aVDYmW5NeupRL8BQRqH8NCgT1uSJoXmJgcuvaOuqG)uSr86jV8A2UaUX6jn5V26jRwjBqBIAb4pzVoRN0AuaKSQg4i1AeNbnQ4bSPqs901t(cz)luuK6eamgWEKJ0)ui93xd9hvzzgAVIhfhT0(v7iANzD0JjVsp(sPyQIG5y2GoihpqdhNRldz48n7q9KeasxcusvTYAWbN)kPtqsL2M8TxzU(3OaK2XcHwCBLMSh(XGg6YOHwQvhqH(PAe6k6mCgX(MDGIQMy)Okk5vQd))f3flUzxvvU2aacVA7lr9HZ0OpeVj9YOguVZZus1H055XO1UD68Kvo3)jGCUxzM1NRrm(EY0mYVn7iuLuU9uu48K3iefoxuNmf3PNFRDrYEX56faHlckkf48ADAtMDZ3uB6tmE)VBVkkQgQt1tNxSlopDgm5wVcHp5SHfvUIEfLUTgd(9kQOEjapCyvZm2DXk1ACh0QOe(1GGB)2lR2aIWlBwFl7ghyvtDtxTc7nWAhRtDaGWAPfIkfqTUf5mTOcO16ku9zvtVRZQCc1sc(IDlnJhhKhAFzKS4OmPGgUSiVxAZ6SwNLTKemVd(Qo4A7xfd96IvWQBt7jX2Es403ScMQ8Zy56uiUOJJlYhs8I8NHD2YtoxX6RYewZEqc4jaL7wrHEeUzAvuX0L1bL90wJSA1CxPcURuRwEC8ZwMrZgxrBDouBvSE29goSvUv0vS4tbeQVSKQA5MzRIfRToTIIax)JqyTcN2uxhDUIZHOVR8HCf83LA4pdXP7tLuFlp2HjzsH40iZPmmT)gJmN0qoNDyTMGH(ItraRBNmiwoj2v6fyD36Wmdq5MQWKiPPnDXuBebvI099HDSAHH0OGRVFLr4PM9PbhrlyVAi7rtX7ydg4wNfZk5jLSW(T0Jnf6YTBJZgk9XOC)N0t3nopUD(HUSyMmV1C)Zu4)anr5vGj2ZzQkcRAvBPyxHQRuReEDZSzb5RW8y(NS44DkIQYLYvwtITcAA3PQ2oOsnbEhtT4BLtrQH6xJ3OUSM8fyVVC7IwVHG30XwPC1vi0Gl)Eb1gv47gTpuvvpsmQMn9HR3vXAQkpk3gGfvKrjmk47xrYWL0(Kko6(bQsJSeV(vCSjU0OCXKVqQThB8mYmEJ2Xn138n3Nr7YnE1STCKD0rQLvqBDyEPI)yJvvAn(lJM(M5uNViAJ0VqpxPRUoHhuTDZXq81ltBELv6JLMMuit(zrtz2HjYNi)Nin2tCjxCfzSvut4kkRkTcI0FH1krGDitlB)4DRO03U4WK9g7rYwUj6(58ofPPY2XIQut3zFy2oCOF8UVSksKCLMhHv6cWwuoWBYh3T9nIeLBNmrQICgNWbrvnUt8tGqzUIFS)HpixgJA)5nqu6Ah16gXTTrRMM6FYdkY2l93I)mO)o6NiHcRhJxyzb)(ait1nkR6e)GaWF3KBLzz6ofycTXS8E7xtHDaW0uTtemJbr3OuJBT0bD9uLCEv9uFG)TxO4c9l2ur12IxIOzGLRJAUNA)1s0mxf88LBtxjezOGS7aLNo)2nKZbwg8uJo4PcDWSkz8n1LQ6JKitIF4eYGkhGFGhYxGFMFghQGoKkusTzkpojw2vbbilBfT0gaSOp7m6dB(x3fi7S9CRSRWY)OVBs6XKJQiS8iWX67yC7lReKexuVI9aDbrXlFltVNuJ389gZorqE(tabz9wyp9D67rYlWbyzYRbsvG3(csIOCZGs(y9un5rvvClDBdE5JGqzZAfBmtVJxK7ndiZGddk1r5gUj03dFmAQgQwj2)OT26oR8zhPljLJnlwxVLqDFqLIbQy3p80gjhuxyyZTAsRixW(OOI65v)lfu1ecXBfHbNTzw4L5Qu56PEaCvMBFxir4nBjMR33GOQb61d7UkLoDMLUgRuvvpy47tySgTWG5Uq1H)IL9dKfSRn6)9d]])
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
