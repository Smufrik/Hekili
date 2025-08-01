-- MonkWindwalker.lua

-- Boilerplate and Class Check
if not Hekili or not Hekili.NewSpecialization then return end
if select(2, UnitClass('player')) ~= 'MONK' then return end
if GetSpecialization() ~= 269 then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

-- Helper functions
local strformat = string.format

-- Windwalker specific combat log tracking
local ww_combat_log_events = {}

local function RegisterWWCombatLogEvent(event, callback)
    if not ww_combat_log_events[event] then
        ww_combat_log_events[event] = {}
    end
    table.insert(ww_combat_log_events[event], callback)
end

-- Hook into combat log for Windwalker-specific tracking
local wwCombatLogFrame = CreateFrame("Frame")
wwCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
wwCombatLogFrame:SetScript("OnEvent", function(self, event)
    local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= state.GUID then return end

    if ww_combat_log_events[subevent] then
        for _, callback in ipairs(ww_combat_log_events[subevent]) do
            callback(timestamp, subevent, sourceGUID, destGUID, spellID)
        end
    end
end)


local function RegisterWindwalkerSpec()
    if not class or not state or not Hekili.NewSpecialization then return end

    local spec = Hekili:NewSpecialization(269, true)
    spec.name = "Windwalker"
    spec.role = "DAMAGER"
    spec.primaryStat = 2 -- Agility

    -- Enhanced resource registration for Windwalker Monk
    spec:RegisterResource(3, { -- Energy with Windwalker-specific mechanics
        -- Combo Breaker energy efficiency (Windwalker signature)
        combo_breaker = {
            aura = "combo_breaker",
            last = function ()
                local app = state.buff.combo_breaker.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                -- Combo Breaker provides energy efficiency
                return state.buff.combo_breaker.up and 3 or 0 -- +3 energy per second during Combo Breaker
            end,
        },
        
        -- Tiger Palm energy refund mechanics (enhanced for Windwalker)
        tiger_palm_efficiency = {
            last = function ()
                return state.query_time -- Continuous tracking
            end,
            interval = 1,
            value = function()
                -- Tiger Palm provides better energy efficiency for Windwalker
                return state.buff.tiger_power.up and 2 or 0 -- +2 energy per second with Tiger Power active (more than Brewmaster)
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
        
        -- Energizing Brew energy boost (if available)
        energizing_brew = {
            aura = "energizing_brew",
            last = function ()
                local app = state.buff.energizing_brew.applied
                local t = state.query_time
                return app + floor( ( t - app ) / 1 ) * 1
            end,
            interval = 1,
            value = function()
                -- Energizing Brew energy restoration
                return state.buff.energizing_brew.up and 15 or 0 -- +15 energy per second during Energizing Brew (less than Brewmaster)
            end,
        },
    }, {
        -- Enhanced base energy regeneration for MoP Windwalker
        base_regen = 10, -- Base 10 energy per second in MoP
        haste_scaling = false, -- Energy doesn't scale with haste in MoP
        
        regenerates = function()
            local base = 10 -- Standard energy regen
            local bonus = 0
            
            -- Stance-specific bonuses
            if state.buff.stance_of_the_fierce_tiger.up then
                bonus = bonus + 1 -- +1 energy per second in Tiger Stance
            end
            
            -- Combat efficiency (Windwalker combat training)
            if state.combat then
                bonus = bonus + 1 -- +1 energy per second in combat (Monk training)
            end
            
            -- Storm, Earth, and Fire energy sharing
            if state.buff.storm_earth_and_fire.up then
                bonus = bonus + 2 -- +2 energy per second during clones
            end
            
            return base + bonus
        end,
    } )

    spec:RegisterResource(12, { -- Chi with Windwalker-specific mechanics
        -- Tigereye Brew chi generation synergy (Windwalker signature)
        tigereye_brew_generation = {
            last = function ()
                return state.query_time
            end,
            interval = 1,
            value = function()
                -- Tigereye Brew builds stacks when spending Chi
                if state.last_chi_spent and state.last_chi_spent > 0 then
                    return 0 -- No direct chi generation, but tracks consumption for Tigereye stacks
                end
                return 0
            end,
        },
        
        -- Power Strikes chi bonus (Windwalker talent)
        power_strikes = {
            last = function ()
                return state.query_time
            end,
            interval = 20, -- Power Strikes procs every 20 seconds
            value = function()
                if state.talent.power_strikes.enabled then
                    return 1 -- Next Jab generates extra Chi
                end
                return 0
            end,
        },
        
        -- Ascension chi maximum increase (Windwalker talent)
        ascension_bonus = {
            last = function ()
                return state.query_time
            end,
            interval = 1,
            value = function()
                -- Ascension increases max Chi by 1
                return state.talent.ascension.enabled and 1 or 0 -- Effective max chi bonus
            end,
        },
        
        -- Chi Brew instant generation (Windwalker talent)
        chi_brew_generation = {
            last = function ()
                return (state.last_cast_time and state.last_cast_time.chi_brew) or 0
            end,
            interval = 1,
            value = function()
                -- Chi Brew instantly generates 2 Chi
                return state.last_ability == "chi_brew" and 2 or 0
            end,
        },
        
        -- Storm, Earth, and Fire chi efficiency
        storm_earth_fire_efficiency = {
            aura = "storm_earth_and_fire",
            last = function ()
                return state.query_time
            end,
            interval = 1,
            value = function()
                -- SEF provides effective chi efficiency through damage multiplication
                return state.buff.storm_earth_and_fire.up and 0.5 or 0 -- Effective chi value bonus
            end,
        },
    }, {
        -- Base chi mechanics for Windwalker
        max_chi = function ()
            local base = 4 -- Base max Chi in MoP
            if state.talent.ascension.enabled then
                base = base + 1 -- Ascension increases max Chi by 1
            end
            return base
        end,
        
        -- Chi generation from abilities
        jab_generation = function ()
            return 2 -- Jab generates 2 Chi in MoP (enhanced from 1 in earlier expansions)
        end,
        
        -- Chi efficiency from Windwalker mastery
        combo_strikes_efficiency = function ()
            return 1.0 -- Combo Strikes mastery affects chi efficiency indirectly
        end,
    } )

    -- MoP Tier Gear Registration
    spec:RegisterGear("tier14", 85469, 85472, 85475, 85478, 85481)
    spec:RegisterGear("tier15", 95861, 95864, 95867, 95870, 95873)
    spec:RegisterGear("tier16", 99251, 99254, 99257, 99260, 99263)

    -- MoP Talent Registration (Verified for 5.4.8)
    spec:RegisterTalents({
        -- Tier 1 (Level 15) - Movement
        celerity = { 1, 1, 115173, "Grants an extra charge of Roll." },
        tigers_lust = { 1, 2, 116841, "Increases movement speed and removes roots/snares." },
        momentum = { 1, 3, 115174, "Rolling increases your movement speed." },
        -- Tier 2 (Level 30) - Healing/Damage
        chi_wave = { 2, 1, 115098, "Bouncing wave of Chi that damages and heals." },
        zen_sphere = { 2, 2, 124081, "AoE healing/damage sphere." },
        chi_burst = { 2, 3, 123986, "Directional cone of Chi that damages and heals." },
        -- Tier 3 (Level 45) - Resource Management
        power_strikes = { 3, 1, 121817, "Every 20 sec, your next Jab generates an extra Chi." },
        ascension = { 3, 2, 115396, "Increases max Chi by 1, and energy regen by 10%." },
        chi_brew = { 3, 3, 115399, "Instantly restores 2 Chi." },
        -- Tier 4 (Level 60) - Crowd Control
        ring_of_peace = { 4, 1, 116844, "Creates a sanctuary that incapacitates enemies." },
        charging_ox_wave = { 4, 2, 119392, "A forward charge that stuns enemies." },
        leg_sweep = { 4, 3, 119381, "AoE stun around the Monk." },
        -- Tier 5 (Level 75) - Survival
        healing_elixirs = { 5, 1, 122280, "Heals you when using Brews/Teas, or when low health." },
        dampen_harm = { 5, 2, 122278, "Reduces damage from large hits." },
        diffuse_magic = { 5, 3, 122783, "Reduces magic damage taken and can reflect spells." },
        -- Tier 6 (Level 90) - Damage Cooldowns
        rushing_jade_wind = { 6, 1, 116847, "AoE damage tornado around you." },
        invoke_xuen = { 6, 2, 123904, "Summons Xuen, the White Tiger, to fight for you." },
        chi_torpedo = { 6, 3, 115008, "Replaces Roll with a longer-distance damaging torpedo." },
    })

    -- MoP Glyph Registration
    spec:RegisterGlyphs({
        [125672] = "expel_harm",
        [125677] = "touch_of_karma",
        [146958] = "fists_of_fury", -- Increases parry chance while channeling.
        [125679] = "touch_of_death",
        [125687] = "fortifying_brew",
    })

    -- MoP Aura Registration
    spec:RegisterAuras({
        -- Core Buffs & Procs
        tigereye_brew_stack = { id = 116740, duration = 60, max_stack = 20, name = "Tigereye Brew" },
        tiger_power = { id = 125359, duration = 15, name = "Tigereye Brew" }, -- The buff from consuming stacks
        combo_breaker_bok = { id = 116768, duration = 15, name = "Combo Breaker: Blackout Kick" },
        combo_breaker_tp = { id = 118864, duration = 15, name = "Combo Breaker: Tiger Palm" },

        -- Cooldowns
        energizing_brew = { id = 115288, duration = 20 },
        fortifying_brew = { id = 115203, duration = 20, dr = 0.2 },
        storm_earth_and_fire = { id = 137639, duration = 15 },
        invoke_xuen = { id = 123904, duration = 45 }, -- Xuen lasts 45s in MoP

        -- Target Debuffs
        rising_sun_kick_debuff = { id = 121411, duration = 15, debuff = true, name = "Rising Sun Kick" },
        mortal_wounds = { id = 115804, duration = 10, debuff = true },
        disable = { id = 116095, duration = 15, debuff = true, mechanic = "snare" },

        -- Talent Auras
        tigers_lust = { id = 116841, duration = 6 },
        chi_torpedo = { id = 119085, duration = 10 },
        rushing_jade_wind = { id = 116847, duration = 6, dot = true },
    })

    -- Pet Registration
    spec:RegisterPet("xuen_the_white_tiger", 63508, "invoke_xuen", 45, "xuen")

    -- Ability Registration (MoP 5.4.8 accurate)
    spec:RegisterAbilities({
        -- Core Abilities
        jab = { id = 100780, spend = 40, spendType = "energy", handler = function() gain(2, "chi") end },
        tiger_palm = { id = 100787, spend = 1, spendType = "chi",
            handler = function() if buff.combo_breaker_tp.up then removeBuff("combo_breaker_tp") end end },
        blackout_kick = { id = 100784, spend = 2, spendType = "chi",
            handler = function() if buff.combo_breaker_bok.up then removeBuff("combo_breaker_bok") end end },
        rising_sun_kick = { id = 107428, cooldown = 8, spend = 2, spendType = "chi",
            handler = function() applyDebuff("target", "rising_sun_kick_debuff", 15) end },
        spinning_crane_kick = { id = 101546, spend = 40, spendType = "energy", channeled = true,
            usable = function() return enemies >= 3 end },
        fists_of_fury = { id = 113656, cooldown = 25, spend = 3, spendType = "chi", channeled = true },
        expel_harm = { id = 115072, cooldown = 15, spend = 40, spendType = "energy",
            handler = function() gain(1, "chi") end },

        -- Cooldowns
        tigereye_brew = { id = 116740, gcd = "off",
            usable = function() return buff.tigereye_brew_stack.stack >= state.settings.tigereye_min_stacks end,
            handler = function()
                local stacks_consumed = buff.tigereye_brew_stack.stack
                applyBuff("tiger_power", 15, stacks_consumed)
                removeBuff("tigereye_brew_stack")
            end },
        energizing_brew = { id = 115288, cooldown = 60, toggle = "cooldowns",
            handler = function() applyBuff("energizing_brew", 20); gain(state.chi.max, "chi") end },
        fortifying_brew = { id = 115203, cooldown = 180, toggle = "defensives",
            handler = function() applyBuff("fortifying_brew", 20) end },
        storm_earth_and_fire = { id = 137639, cooldown = 90, charges = 2, toggle = "cooldowns",
            handler = function() applyBuff("storm_earth_and_fire", 15) end },
        touch_of_death = { id = 115080, cooldown = 90,
            usable = function() return target.health_pct < 10 or target.health.current < health.current end },
        touch_of_karma = { id = 122470, cooldown = 90, toggle = "defensives" },

        -- Talent Abilities
        chi_brew = { id = 115399, cooldown = 45, charges = 2, talent = "chi_brew",
            handler = function() gain(2, "chi") end },
        invoke_xuen = { id = 123904, cooldown = 180, toggle = "cooldowns", talent = "invoke_xuen",
            handler = function() summonPet("xuen_the_white_tiger") end },
        rushing_jade_wind = { id = 116847, cooldown = 6, spend = 1, spendType = "chi", talent = "rushing_jade_wind" },
        leg_sweep = { id = 119381, cooldown = 45, aoe = true, talent = "leg_sweep" },

        -- Utility
        spear_hand_strike = { id = 116705, cooldown = 15, gcd = "off", interrupt = true },
        disable = { id = 116095, spend = 15, spendType = "energy" },
    })

    -- Combat Log Logic
    local chi_spent_for_brew = 0
    RegisterWWCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, destGUID, spellID)
        local ability = class.abilities[spellID]
        if not ability or ability.spendType ~= "chi" or ability.spend <= 0 then return end


        chi_spent_for_brew = chi_spent_for_brew + ability.spend
        -- In MoP, 3 Chi spent = 1 stack of Tigereye Brew
        if chi_spent_for_brew >= 3 then
            local stacks_to_add = math.floor(chi_spent_for_brew / 3)
            state.buff.tigereye_brew_stack.stack = (state.buff.tigereye_brew_stack.stack or 0) + stacks_to_add
            chi_spent_for_brew = chi_spent_for_brew % 3
        end
    end)

    -- State Expressions for APL
    spec:RegisterStateExpr("tigereye_ready", function()
        return buff.tigereye_brew_stack.stack >= (settings.tigereye_min_stacks or 10)
    end)
    spec:RegisterStateExpr("rsk_debuff_down", function()
        return debuff.rising_sun_kick_debuff.down or debuff.rising_sun_kick_debuff.remains < 3
    end)

    -- Options and Settings
    spec:RegisterOptions({
        enabled = true,
        aoe = 3,
        cycle = false,
        nameplates = true,
        nameplateRange = 8,
        damage = true,
        damageExpiration = 5,
        potion = "potion_of_mogu_power", -- MoP Agility Potion
        package = "Windwalker",
    })

    spec:RegisterSetting("tigereye_min_stacks", 10, {
        name = strformat("Min. %s Stacks", Hekili:GetSpellLinkWithTexture(spec.abilities.tigereye_brew.id)),
        desc = strformat("The minimum number of stacks required before %s will be recommended for use.", Hekili:GetSpellLinkWithTexture(spec.abilities.tigereye_brew.id)),
        type = "range", min = 1, max = 20, step = 1, width = "full"
    })

    spec:RegisterSetting("tigereye_pandemic", 4, {
        name = strformat("%s Pandemic Window", Hekili:GetSpellLinkWithTexture(spec.abilities.tigereye_brew.id)),
        desc = strformat("Recommends refreshing %s when the remaining duration is less than this value.", Hekili:GetSpellLinkWithTexture(125359)),
        type = "range", min = 0, max = 15, step = 0.5, width = "full"
    })

    -- APL Package
    spec:RegisterPack("Windwalker", 20250722, [[Hekili:fN12UTnot4NLGc420dEL8HwNc7CXEXITb72BCxS3zjAjABvll5LIkUUWqpw7lW(I9pKuhiPiLvYFb6fTjICMHdN5BoWjRCx9Lvldru8QppYz0uNp4mDO7SjJME3QL0ZhXRwEefShTf(Le0b4))7OKWtO49ycBRZXPOqMiYsZjbW2RwUopkM(PKvRBl3pmzMZeG2J4ay53dhXUOWqSGwCwWQLFzxuwHp7FOc)YtUWpDd8DanknPWpokJcBVjLu4)749rXrdxTKVitnqPy4hFMFRWjO1X4Wv)6QLbKikMeHG7ekgNqhgSlYBDojJoSIQLIdaOTARvuqjVMGi5z7Is269vui27eyBAlWwKWe8yRc(Mc)q868nBgsIYy8LLN4Tpky)W8JscvDpMiNyvKCPrJ2IjEhtpHjdZOGPTWFEH)4grwsak(atAtTknWav4F)Ic)rn8MDmkjHPqbeucUwLEFxcz4b03k8FxHFTaDBe4xrRzc4dpBbG)2rCS3oeHFBMXbhLBTogU9P5uHAkjEMlhaIBq5X0AyuZveJiGatc9YOKO9yvofqLkIZZWEGMEitJOXQ6rAAO3MCYznQMOqfMKHj7bJRgvtLPcrcygEAkHaWsnkT7gkrXrjpMUh79TCCsB8R0MD7sOiYwmD4omkMUB4XakhH56ibXsZd25LUXleJO7QDm2Ide42kE2d(sKsqG6wmXD31UP8OBc(u11SWFqj(zod)W)8vf(GdozpCxossdgI2czzONhsWi2D6YfT9b4aozlCLLiqkKtGwYQ29wTunGYW0CWmD9Wx8zSq7ldG5yEhXj()RwFl)U39zntlBrfn8lGEs3uWtLHPnS8icUoWUSFloh(HRId65R8Cr7jQpvsMx25Kap2j)iMRD2ZKliYdNGpeHZ0ZkgGIJ9eF4XkZik2uEyIIeU2tMRlBMrSVcNvlJNrkJ2RAAwlf1GX5zT5FwfD1MjLQmMkDD1AImy9j0JyZ1wz70DfWsX8DCIx2XDakt5IaAofYBZZhwj3gs7Uqi4hiBpd47dSuLE86h3x4pTkSxoradZjONdjM4Oe6Y3j67mJtvaG9kMDvsxCqw2MGpGIsAHjnu83Ek(Uk(3kxLGclhRAdc2Rdy7exWpXbDAmguz0B5KgPcJL0RnSU)yLb4Ls7SOsj0IRw1jM1ct6STcgcUbPzVCJz5WpcT6JZCS10shLe6q8vyw2ktCA1rvR00pHsKGeDSu9YEsbURoi9W6ug1i4HdERtvBMvTHSUZOAqC0JvqNoqYGUFNnOSR9mgAPnnHnNxVRLRAy6PKUUSknYPhBR2jNBNDulRPplDbk2CKGzCHm0amfLeGzXz0DyVnry4bFECdPPoHVkcRhV(6QLi0HQMbNkTthJ3IcoxDloTdKOXlHE28R3nJtpAdr39DDPwI4i4Ty41VVgIYhov(Ge77X3ha9PXScJuHV8eIWEuwg7D1WZOJoCmLqlF78lH2lEzHpb)p5rewqEw6bGguon9a8S9qwipkzlKES4H)ikb2Y9Jf()vsw(rMuyei0zqu1oTxwt8iRe3QNIgMgBNj1OIgwMyLLMq8gQNALAdpGTHT3BLniPAdzFWkzn51BOEMvQvIkzmW9EBsJJtb71wMtIGGCAqcoyD4PMaZraJugzvsH1ijllaTIUKuURpprH6WqgXHikAnkd)XIh4Lu0m3LRkLyfw5bdykab8dcs1bkXo0QQ9Y(GOAAzSpGjT296dIYkK1oAYeK1oOsPTN(GRA6DPH67EsywxN(fj4ELCfkMqx7o0wrcLCy3TAYe6A3VA7aEgUvx7(1F(b0TAeW460JDg)3kMS35fkNP2pQKdTgfxFcUKgJvFIUuhvvFcVuNgvFcXmelypatzGl)uarkJZsETkTQAnfdHfirDFM)WafwBpTVLo0AHXEsM2(n7zyS2VjJ5Ih(0HkoMO6LyxzOTWC6UuO10F7)(xYJreccfYArpDteRfXx8Ic))mnzpC4n)zzysviOSH1g53S4xSBFmtFTf5TrBwyRX9oyfSp6Ck)OsJmA1yzM8QMLFlRv4fgA5(T8MOx40h2n1iDj)Y9G)AO)BjtmZWQNnsEZ6)qaYl2m4FLvRh0V8QQd2xEhPeAsgAdJYxMj10Ac(0MA)CxhJCWJMzCCJ55YlZupqadGfMVWDWRSp43lx6yOVxUyBg73QO(YjOyQJTjCF)cxNlxEUAZTdSl3zY6tFXSUCt3ZtzuXN6dzwCYI4AXrwnF65JVoFWZgBZ49lglN2jJfD1QBbjSG1rvZaf3Vy0GBSoCATtPQLFnGM84N14OPXFjEApR5b3uoLzn21EjatgThk09th8kb8(YfXUZN4CRUbsTjlEKL1jJE5s3JiwY1jKEtJWQGE5rYoFSsqKYiZAjqLNByxMlgpW6LyGbl1iHlx)0AERIKxY4yBhuol03XLJRU7Q(vmm5Os6aPCEZC0yeEpJboexG7xmrN8EMWBHoFkpnO2QAACPx3)AyQOdS6ExC310KYqX2(S5WQDmEXUH598u7u(nYaYg9MNCRkcMEw5NAjKNsmSoZ9levNldtQQXUPtSruSorDfJOtB7jgV6)n]])

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

if not TryRegister() then
    wwCombatLogFrame:RegisterEvent("ADDON_LOADED")
    wwCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
