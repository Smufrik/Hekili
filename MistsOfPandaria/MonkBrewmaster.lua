-- MonkBrewmaster.lua July 2025
-- by Smufrik, updated to fix Chi tracking and stagger_level warnings

local addon, ns = ...
local _, playerClass = UnitClass('player')
if playerClass ~= 'MONK' then return end

local Hekili = _G["Hekili"]
local class, state = Hekili.Class, Hekili.State

local floor = math.floor
local strformat = string.format

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
        
local function UpdateEnergy()
    local energy = UnitPower("player", 3) or 0
    local maxEnergy = UnitPowerMax("player", 3) or 100

    state.energy = state.energy or {}
    state.energy.current = energy
    state.energy.max = maxEnergy

    return energy, maxEnergy
end



    UpdateChi() -- Initial Chi sync

    -- Ensure Chi stays in sync throughout the state evaluation cycle
    for _, fn in pairs({ "resetState", "tick", "refreshResources" }) do
     spec:RegisterStateFunction(fn, UpdateChi)
     spec:RegisterStateFunction(fn, UpdateEnergy)
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
        shuffle = {
            id = 115307,
            duration = 6,
            max_stack = 1,
            emulated = true
        },
        elusive_brew = {
            id = 128939,
            duration = 30,
            max_stack = 15,
            emulated = true
        },
        fortifying_brew = {
            id = 115203,
            duration = 15,
            max_stack = 1,
            emulated = true
        },
        guard = {
            id = 115295,
            duration = 30,
            max_stack = 1,
            emulated = true
        },
        dampen_harm = {
            id = 122278,
            duration = 10,
            max_stack = 1,
            emulated = true
        },
        diffuse_magic = {
            id = 122783,
            duration = 6,
            max_stack = 1,
            emulated = true
        },
        breath_of_fire_dot = {
            id = 123725,
            duration = 8,
            tick_time = 2,
            max_stack = 1,
            emulated = true
        },
        heavy_stagger = {
            id = 124273,
            duration = 10,
            tick_time = 1,
            max_stack = 1,
            emulated = true
        },
        moderate_stagger = {
            id = 124274,
            duration = 10,
            tick_time = 1,
            max_stack = 1,
            emulated = true
        },
        light_stagger = {
            id = 124275,
            duration = 10,
            tick_time = 1,
            max_stack = 1,
            emulated = true
        }
    })

    -- State Expressions
-- Use a separate internal variable to avoid conflicts with the actual dodge buff



    spec:RegisterStateExpr("stagger_level", function()
        local level = "none"
        if state.buff.heavy_stagger and state.buff.heavy_stagger.up then
            level = "heavy"
        elseif state.buff.moderate_stagger and state.buff.moderate_stagger.up then
            level = "moderate"
        elseif state.buff.light_stagger and state.buff.light_stagger.up then
            level = "light"
        end
        print("Stagger Level Evaluated:", level, "Chi:", state.chi and state.chi.current or "nil") -- Debug
        return level
    end)




    -- Abilities for Brewmaster Monk
    spec:RegisterAbilities({

chi_wave = {
    id = 115098,
    cast = 0,
    cooldown = 15,
    gcd = "spell",
    spend = 0,
    spendType = nil,
    talent = "chi_wave",
    startsCombat = true,
    handler = function()
        print("Chi Wave: Casted") -- Optional debug
    end
},



elusive_brew = {
    id = 115308,
    cast = 0,
    cooldown = 0,
    gcd = "off",
    spend = 0,
    spendType = nil,
    startsCombat = false,
    handler = function()
        print("Elusive Brew: Consuming stacks") -- Debug
        state.removeStack("elusive_brew", nil, 15) -- Or however many stacks are used
        state.applyBuff("player", "elusive_brew", 6)
    end
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
                print("Jab: Gaining 1 Chi, Current:", state.chi.current) -- Debug
                state.gain(1, "chi")
                if state.talent.power_strikes.enabled and math.random() <= 0.2 then
                    print("Power Strikes: Gaining 1 extra Chi") -- Debug
                    state.gain(1, "chi")
                end
                UpdateChi() -- Sync with UnitPower
            end
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
                print("Keg Smash: Gaining 2 Chi, Current:", state.chi.current) -- Debug
                state.gain(2, "chi")
                state.applyDebuff("target", "breath_of_fire_dot", 8)
                UpdateChi() -- Sync with UnitPower
            end
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
                -- No Chi generation
            end
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
                print("Blackout Kick: Spending 2 Chi, Current:", state.chi.current) -- Debug
                state.spend(2, "chi")
                state.applyBuff("player", "shuffle", 6)
                UpdateChi() -- Sync with UnitPower
            end
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
                print("Purifying Brew: Spending 1 Chi, Current:", state.chi.current) -- Debug
                state.spend(1, "chi")
                state.removeDebuff("player", "heavy_stagger")
                state.removeDebuff("player", "moderate_stagger")
                state.removeDebuff("player", "light_stagger")
                UpdateChi() -- Sync with UnitPower
            end
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
                print("Guard: Spending 2 Chi, Current:", state.chi.current) -- Debug
                state.spend(2, "chi")
                state.applyBuff("player", "guard", 30)
                UpdateChi() -- Sync with UnitPower
            end
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
                print("Breath of Fire: Spending 2 Chi, Current:", state.chi.current) -- Debug
                state.spend(2, "chi")
                state.applyDebuff("target", "breath_of_fire_dot", 8)
                UpdateChi() -- Sync with UnitPower
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
                print("Rushing Jade Wind: Spending 1 Chi, Current:", state.chi.current) -- Debug
                state.spend(1, "chi")
                state.applyBuff("player", "rushing_jade_wind", 6)
                UpdateChi() -- Sync with UnitPower
            end
        },
        fortifying_brew = {
            id = 115203,
            cast = 0,
            cooldown = 180,
            gcd = "off",
            toggle = "defensives",
            startsCombat = false,
            handler = function()
                state.applyBuff("player", "fortifying_brew", 15)
            end
        },
        chi_brew = {
            id = 115399,
            cast = 0,
            cooldown = 90,
            gcd = "off",
            talent = "chi_brew",
            startsCombat = false,
            handler = function()
                print("Chi Brew: Gaining 2 Chi, Current:", state.chi.current) -- Debug
                state.gain(2, "chi")
                UpdateChi() -- Sync with UnitPower
            end
        },
        spinning_crane_kick = {
            id = 101546,
            cast = 0,
            cooldown = 0,
            gcd = "spell",
            spend = 1,
            spendType = "chi",
            startsCombat = true,
            handler = function()
                print("Spinning Crane Kick: Spending 1 Chi, Current:", state.chi.current) -- Debug
                state.spend(1, "chi")
                UpdateChi() -- Sync with UnitPower
            end
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
                print("Expel Harm: Gaining 1 Chi, Current:", state.chi.current) -- Debug
                state.gain(1, "chi")
                UpdateChi() -- Sync with UnitPower
            end
        },
        energizing_brew = {
            id = 115288,
            cast = 0,
            cooldown = 60,
            gcd = "off",
            startsCombat = false,
            handler = function()
                print("Energizing Brew: Activating") -- Debug
            end
        }
    })

    -- Register combat log event for Elusive Brew stacks and Chi updates
    bmCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
bmCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID, _, _, amount, critical = ...
    
    -- Build stacks on crits
    if subevent == "SPELL_DAMAGE" and sourceGUID == state.GUID and critical and (spellID == 100780 or spellID == 115072 or spellID == 121253) then
        state.elusive_brew_manual_stacks = math.min((state.elusive_brew_manual_stacks or 0) + 1, 15)
        print("Elusive Brew stacks:", state.elusive_brew_manual_stacks)
    
    -- Reset stacks on Elusive Brew cast (optional)
    elseif subevent == "SPELL_CAST_SUCCESS" and sourceGUID == state.GUID and spellID == 115308 then
        state.elusive_brew_manual_stacks = 0
        print("Elusive Brew used – stacks reset.")
    end
end)



    -- Periodic Chi sync (every 1 second in combat)
    local lastChiUpdate = 0
    bmCombatLogFrame:SetScript("OnUpdate", function(self, elapsed)
        if InCombatLockdown() then
            lastChiUpdate = lastChiUpdate + elapsed
            if lastChiUpdate >= 1 then
                UpdateChi()
		UpdateEnergy()
                lastChiUpdate = 0
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

    -- Default APL Pack
spec:RegisterPack("Brewmaster", 20250724, [[Hekili:fJvZYTTnq43LCqojnrrswY2j10hAV0KPtUOKtDcjHiHeHniHkiOTvhp8zV7c(hifGKSBMPhIDm4I97d7FyX6p1)B(lJjkQ)xNnz2IjxoBX4PNp)JNFH)s1UTu)LBjr3r2a)Nmsk8tcbxAhxqIXTMlkKrWY(lxvW4QpN5VYU(MdYULgblFXv(ltyXX0kzP5r(l)wclVme)hPmSgXYqXA4VJumrwziNLRGpVwild)d6DmoBS)s9IinIecES4Hm8p(Q(mrZiR40y)Fd(OKPOsgqCfHtZuJzz3lUJg8ybnBCJClRaYFPXh9vaDDQmAgvUz34OcPeuAz41ELHZNugoQmmkH1F9PD6xVn2)WY2eSssFaX48JryqFAHByRDqM1bsZgaTRqB8Asbx1ABAKIuOebeLcS3M4B5u3QxcNhu9hbOXVYfeufA05eo4zQpVRohPKhldFFp70D0nb5PK8euBZpK2kdVbp9AJYRldxvSE948e4NC6yjnLWYYRmqxug(0tLH5uLcm)5J3kfiA3tdQfVm8nDeyfhSlIcvWDmW(aKyXXjXunjYvKnBOYao9EkVmewpvetLqwH(ZjucxLmElfYCQTbxwf30YSICAW2cjB9U24KwEnyDGyxCCIvzD0MMnfez8y0rzNnG0xnPdoT4ikxEQOet14aSJOsceRdwZK0GyHQd0AZoKlKYO51B2W03BRi4xDSuezrEcAtULetdEGLfpmxX0bP53(7aPxhj277ip(OtEy7iDUgnNmmMLBJIDuiFllld3tKKKrBdeNoXjlS6nxyPErBENrLPh3s5bjezQge3LrpXm4BjR0kYDjuJYBpqUNUFX4MVO1J7skdlfJMXlmIHvmmDClHN2wqKMLdURJCFX(jYG99(D2cPEHPUUTnp)IilM8tKyUn22cXUCa0wl3yPMI76669s5fOxstQGC8EQX6FwF(m8WMsE4A12OF912SSirkAeIjPqdiblQtJhUL3wgoz8IoWHMsuNCj56yEaIT0mD2wVkv2O3Ixa9M3rpdOoCD8gQXwVgdwaqyr9ixld0F6K4X5g8WuVvjIBLuqJRi73Bc4NZIO4vaQe4(zvHmExG4X(9PO1XdejwJmh7IeYnyPBb3rDNIN12tYzLHs6FxaxNahLCrkij2(tkKpfJbUKSn08XLF5pzzWNM(PYWVNLxSf1fkqtBONz0E4zTIpZP4d62d3s5xSWZUkspFI(7IS7Pv4k2IviaOXUPr87vfXZtx(AeKMEJ30rhOYaqcLyVTFY7UNH5zqVMkCJ6hkD9IjNcQw58)nv2EqM72dBu5Pt(lCkVr2yN4x6wCZKgCd6GN1coxa9qSbdoKeWC(avcRdsgxzAvOynAbBshlhRAKltOJ8kY6jDCmkm86nYkso9tqOkEJ((fHDhdJpZ45haB)KB86Kod1IJeq14tpT4QlNCkbuw15luLThKp68CBPPVUTnDI7aX223me3DLPMwR(FjMAVEHDes1E)WpRGkhxR0uxgNab8QW1m8TG4FKYYZ1MKALvtSnyDDweCiLSS7Oka6WYWpRQ2KM0P0SyeAvcbwgIzK7qDZeW1T70xLYlIXhkqzavKnwM)675uut008F8oW0MWIsmLMKTRd1AJo455SiMI3PxtFqdO)kKViBG5BvQaSv)avAS5sZmq(bgNBCIQvPQruT1qVuwr6kAL7Hdp1R8lFoTX6pFWyCGpQh(qIqcxAtIevnJwB49x(EGG6GHE()(bEYcmNxaotiiKc0a(DLO63Fl1OuTf8H(1QXZH)h9(DO27Y4(WYAMbfzfJZu6x6v5HZtef8yKmnPmWJy1VjKVZGkD62RFPH3Xw7nOS1R0x4(Qt4IkB6)x8(WXrOPm2REr3p6awD79iAd0P3L1kD2OHtIWUImV6b13bFuaW1jo0ZGg0TrT5tgTF)13mqS3cT97acJR1r17Ul)HgAVfNiYZDHSzhcMyBRn(rUAH3cGN3pRWSvAhjfPKBXFjwxtVpuOWSKDyQz9MnsfAxZZOPAJdGLX0AzZyys)MSrv0FIaA3RXulU2BQDn1m3udwmC2R91ZS9QCu3c0(wODIcTjcRllfkDBleEx55olJNrRpTlISBW0xFho3vVw(BkA70tXtIjJRNvZ7NAkDVrDwVdml912ML61Ex80tUNH6Bmv8(fGS3GM76qhUFktSAR6yVeZE5DxnPNjO3ihnuZHNM5O6dF9y)Ubdi6u6ET5yex5CGLn1DpWqknXWs7Iikd515Jo6yiRb2u5D9uARM5vlgzj0YC)3swDsbGnnJoiVZCOGMI3npV9Z1VX7Ij6bd4)Vd]])

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
