-- MonkMistweaver.lua
-- A complete data-driven overhaul for Mists of Pandaria (MoP) Mistweaver.

-- Boilerplate and Class Check
if not Hekili or not Hekili.NewSpecialization then return end
if select(2, UnitClass('player')) ~= 'MONK' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

-- Helper functions
local strformat = string.format

-- Mistweaver specific combat log tracking
local mw_combat_log_events = {}

local function RegisterMWCombatLogEvent(event, callback)
    if not mw_combat_log_events[event] then
        mw_combat_log_events[event] = {}
    end
    table.insert(mw_combat_log_events[event], callback)
end

-- Hook into combat log for Mistweaver-specific tracking
local mwCombatLogFrame = CreateFrame("Frame")
mwCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mwCombatLogFrame:SetScript("OnEvent", function(self, event)
    local timestamp, subevent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= state.GUID then return end

    if mw_combat_log_events[subevent] then
        for _, callback in ipairs(mw_combat_log_events[subevent]) do
            callback(timestamp, subevent, sourceGUID, destGUID, spellID)
        end
    end
end)


local function RegisterMistweaverSpec()
    if not class or not state or not Hekili.NewSpecialization then return end

    local spec = Hekili:NewSpecialization(270) -- Mistweaver spec ID for MoP
    if not spec then return end

    -- Resource Registration
    spec:RegisterResource(0) -- Mana (Primary)
    spec:RegisterResource(12, { -- Chi (Secondary)
        max = function() return state.talent.ascension.enabled and 5 or 4 end,
    })

    -- MoP Tier Gear Registration
    spec:RegisterGear("tier14", 85470, 85473, 85476, 85479, 85482)
    spec:RegisterGear("tier15", 95863, 95866, 95869, 95872, 95875)
    spec:RegisterGear("tier16", 99252, 99255, 99258, 99261, 99264)

    -- MoP Talent Registration (Shared with other Monk specs)
    spec:RegisterTalents({
        celerity = { 1, 1, 115173 }, tigers_lust = { 1, 2, 116841 }, momentum = { 1, 3, 115174 },
        chi_wave = { 2, 1, 115098 }, zen_sphere = { 2, 2, 124081 }, chi_burst = { 2, 3, 123986 },
        power_strikes = { 3, 1, 121817 }, ascension = { 3, 2, 115396 }, chi_brew = { 3, 3, 115399 },
        ring_of_peace = { 4, 1, 116844 }, charging_ox_wave = { 4, 2, 119392 }, leg_sweep = { 4, 3, 119381 },
        healing_elixirs = { 5, 1, 122280 }, dampen_harm = { 5, 2, 122278 }, diffuse_magic = { 5, 3, 122783 },
        rushing_jade_wind = { 6, 1, 116847 }, invoke_xuen = { 6, 2, 123904 }, chi_torpedo = { 6, 3, 115008 },
    })

    -- MoP Glyph Registration
    spec:RegisterGlyphs({
        [123394] = "renewing_mist", -- Removes Renewing Mist's cooldown, but makes it cost mana.
        [123399] = "uplift", -- Uplift no longer requires Renewing Mist, but has a mana cost.
        [123403] = "mana_tea", -- Mana Tea can be channeled while moving.
        [123402] = "soothing_mist", -- Soothing Mist can be channeled while moving.
        [123408] = "life_cocoon",
    })

    -- MoP Aura Registration
    spec:RegisterAuras({
        -- Stances
        stance_of_the_wise_serpent = { id = 115070 },
        stance_of_the_spirited_crane = { id = 118852 },

        -- Core Buffs & HoTs
        renewing_mist = { id = 115151, duration = 18, tick_time = 3, hot = true },
        enveloping_mist = { id = 124682, duration = 6, tick_time = 1, hot = true },
        soothing_mist_channel = { id = 115175, duration = 8, channeled = true }, -- The buff while channeling Soothing Mist
        thunder_focus_tea = { id = 116680, duration = 30 },
        mana_tea_stack = { id = 115867, duration = 300, max_stack = 20, name = "Mana Tea" },

        -- Cooldowns
        revival = { id = 115310 },
        life_cocoon = { id = 116849, duration = 12, absorb = true },

        -- Talent Auras
        zen_sphere_heal = { id = 124081, duration = 16, hot = true },
    })

    -- Ability Registration (MoP 5.4.8 accurate)
    spec:RegisterAbilities({
        -- Stances
        stance_of_the_wise_serpent = { id = 115070, handler = function() removeBuff("stance_of_the_spirited_crane"); applyBuff("stance_of_the_wise_serpent") end },
        stance_of_the_spirited_crane = { id = 118852, handler = function() removeBuff("stance_of_the_wise_serpent"); applyBuff("stance_of_the_spirited_crane") end },

        -- Serpent Stance Abilities (Healing)
        soothing_mist = { id = 115175, cast = 8, channeled = true, spend = 0, spendType = "mana", -- cost is per tick
            usable = function() return buff.stance_of_the_wise_serpent.up end },
        surging_mist = { id = 116694, cast = function() return buff.soothing_mist_channel.up and 0 or 1.5 end, spend = 0.063, spendType = "mana",
            handler = function() gain(1, "chi") end },
        enveloping_mist = { id = 124682, cast = function() return buff.soothing_mist_channel.up and 0 or 2 end, spend = 3, spendType = "chi" },
        renewing_mist = { id = 115151, cooldown = 8, spend = 0.044, spendType = "mana" },
        uplift = { id = 116670, spend = 2, spendType = "chi",
            usable = function() return settings.uplift_min_targets <= active_dot.renewing_mist end },

        -- Crane Stance Abilities (Fistweaving)
        jab = { id = 118841, spend = 0, spendType = "mana", usable = function() return buff.stance_of_the_spirited_crane.up end,
            handler = function() gain(1, "chi") end },
        tiger_palm = { id = 100787, spend = 1, spendType = "chi", usable = function() return buff.stance_of_the_spirited_crane.up end },
        blackout_kick = { id = 100784, spend = 2, spendType = "chi", usable = function() return buff.stance_of_the_spirited_crane.up end },
        spinning_crane_kick = { id = 101546, spend = 0.048, spendType = "mana", channeled = true,
            usable = function() return buff.stance_of_the_spirited_crane.up and enemies >= 3 end },

        -- Shared Abilities
        detox = { id = 115450, cooldown = 8, spend = 0.046, spendType = "mana" },
        thunder_focus_tea = { id = 116680, cooldown = 45,
            handler = function() applyBuff("thunder_focus_tea", 30) end },
        mana_tea = { id = 115294, cast = 10, channeled = true,
            usable = function() return buff.mana_tea_stack.stack > 0 end,
            handler = function() removeBuff("mana_tea_stack") end },
        revival = { id = 115310, cooldown = 180, toggle = "cooldowns" },
        life_cocoon = { id = 116849, cooldown = 120, toggle = "cooldowns" },

        -- Talent Abilities
        chi_brew = { id = 115399, cooldown = 45, charges = 2, talent = "chi_brew", handler = function() gain(2, "chi") end },
        chi_wave = { id = 115098, cooldown = 15, talent = "chi_wave" },
        chi_burst = { id = 123986, cooldown = 30, cast = 1, talent = "chi_burst" },
    })

    -- Combat Log Logic: Mana Tea Generation
    -- Mana Tea: For every 4 Chi you consume, you gain a charge of Mana Tea.
    local chi_spent_for_tea = 0
    RegisterMWCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, destGUID, spellID)
        local ability = class.abilities[spellID]
        if not ability or ability.spendType ~= "chi" or ability.spend <= 0 then return end


        chi_spent_for_tea = chi_spent_for_tea + ability.spend
        if chi_spent_for_tea >= 4 then
            local stacks_to_add = math.floor(chi_spent_for_tea / 4)
            state.buff.mana_tea_stack.stack = (state.buff.mana_tea_stack.stack or 0) + stacks_to_add
            chi_spent_for_tea = chi_spent_for_tea % 4
        end
    end)

    -- State Expressions for APL
    spec:RegisterStateExpr("active_stance", function()
        if buff.stance_of_the_spirited_crane.up then return "crane" end
        return "serpent"
    end)
    spec:RegisterStateExpr("renewing_mist_count", function()
        return active_dot.renewing_mist or 0
    end)
    spec:RegisterStateExpr("mana_deficit", function()
        return mana.max - mana.current
    end)
    spec:RegisterStateExpr("mana_tea_ready", function()
        return buff.mana_tea_stack.stack >= settings.mana_tea_min_stacks and mana.pct < settings.mana_tea_health_pct
    end)

    -- Options and Settings
    spec:RegisterOptions({
        enabled = true,
        aoe = 5, -- Default number of allies to consider for AoE healing
        cycle = false,
        nameplates = false,
        damage = false, -- Mistweaver is primarily a healer
        package = "Mistweaver",
    })

    spec:RegisterSetting("uplift_min_targets", 4, {
        name = strformat("Min. %s Targets", Hekili:GetSpellLinkWithTexture(spec.abilities.uplift.id)),
        desc = "The minimum number of players with Renewing Mist before Uplift will be recommended.",
        type = "range", min = 1, max = 20, step = 1, width = "full"
    })
    spec:RegisterSetting("mana_tea_min_stacks", 10, {
        name = strformat("Min. %s Stacks", Hekili:GetSpellLinkWithTexture(spec.abilities.mana_tea.id)),
        desc = "The minimum number of Mana Tea stacks required before it will be recommended.",
        type = "range", min = 1, max = 20, step = 1, width = 1.5
    })
    spec:RegisterSetting("mana_tea_health_pct", 75, {
        name = strformat("%s Mana %% Threshold", Hekili:GetSpellLinkWithTexture(spec.abilities.mana_tea.id)),
        desc = "The mana percentage below which Mana Tea will be recommended.",
        type = "range", min = 1, max = 99, step = 1, width = 1.5
    })
    spec:RegisterSetting("fistweave_mana_pct", 85, {
        name = "Fistweave Mana % Threshold",
        desc = "The mana percentage above which you may be prompted to enter Crane Stance to conserve mana.",
        type = "range", min = 1, max = 100, step = 5, width = "full"
    })

    -- APL Package
    spec:RegisterPack("Mistweaver", 20250723, [[Hekili:fZt2UTRsZ5RldiVL0Jxc53C1(z(z8x5D8rS2pEa6vE4oY5qYl6I(I(rA6(B4o(U(R4Fv7eT5v3L3TCLo2RjAjsjoQZt)9vA3wD3DD5D5D3rS3z6p(I(l6V(VGRsV1WSl7I(R4FvJDr3T2L3LCLo2p(I(lE4E4E8E8E8E4E4E4E8E4(B4(B4o(o(U(U(U(UE8E8E8(B4E4E4E8(B4o(o(o(R(R(R(R(lE4(R(R(R(R(R(R(RE8E8E8(B4o(U(R4FvJE8(B4E4E8E8E8E8(B4(B4E4(B4o(o(o(U(U(UE8(B4E8(B4o(o(o(R(R(R(RE4(RE8(B4E4(B4o(U(R4FvJE8(B4E4(B4E4(B4E8E4E8E8(B4(B4o(U(R(l(lE4E4(B4E4E4(B4E4(B4E4E4E4E4E4E4E4E4(B4o(U(R(lE8(B4E4E4E4E4E4(B4(B4E4E4(B4o(o(U(U(R(lE4(B4(B4o(R(lE8E8E8(B4E4(B4E4E4E4(B4(B4o(U(R(lE4E8(B4E4E4E4E4(B4o(o(U(R(l(lE4E4(B4(B4o(U(R(lE8E8E8E8(B4(B4o(o(o(o(o(o(o(o(R(R(R(R(R(R(R(R(R(R(RE8(B4(B4(B4(B4(B4(B4(B4(B4(B4(B4E4(B4(B4E4E4(B4E4(B4E4E4E4E4E4(B4E4(B4o(o(U(U(R(lE4(B4(B4E4E4E4(B4o(U(R(l(lE8(B4(B4(B4o(U(R(lE8(B4E4E4E4(B4E4E4E4E4(B4o(o(U(U(R(lE8(B4E4E4E4(B4o(U(R(l(lE4E4E4E4E4E4E4E4(B4E4(B4o(U(R(lE4(B4(B4E4(B4o(U(R(lE8E8(B4(B4(B4E4E4(B4o(o(o(R(R(lE4(B4E4(B4E4(B4(B4o(o(U(R(lE8(B4(B4E4E4(B4o(o(U(R(l(l(lE8(B4(B4(B4E4(B4(B4o(R(l(lE8E8(B4(B4(B4o(o(o(R(R(R(lE4(B4E4E4E4E4E4E4(B4o(U(U(R(lE8(B4E4E4E4E4(B4o(U(R(lE8E8E8(B4E4(B4o(o(o(o(o(U(U(U(U(UE8(B4E4E4E4E4E4(B4o(o(o(o(o(U(R(R(R(RE8(B4(B4(B4E4E4E4E4E4(B4o(o(o(o(U(U(U(R(lE4E4(B4(B4E4(B4o(U(R(l(lE8(B4E4E4E4E4E4(B4(B4E4E4(B4(B4o(o(o(U(U(R(l(lE4E4(B4E4E4(B4(B4o(o(U(U(R(lE8(B4E4E4E4(B4o(o(o(o(o(U(U(U(R(lE4(B4(B4E4E4(B4E4(B4(B4E4(B4o(U(R(l(lE8(B4(B4E4(B4(B4E4(B4o(o(o(o(o(U(U(R(l(lE4(B4E4(B4(B4o(U(R(l(lE8(B4(B4E4E4E4E4E4(B4o(o(U(U(R(lE8E8E8(B4E4E4(B4o(U(R(lE4(B4(B4(B4o(U(R(lE8E8(B4(B4o(o(o(U(U(U(R(lE4E4E4(B4(B4E4(B4o(o(o(o(U(U(U(R(l(lE8(B4E4E4E4E4E4(B4o(o(U(U(R(lE8(B4(B4(B4E4E4(B4o(U(R(l(lE4E4(B4E4(B4o(U(R(l(lE8(B4E4E4E4(B4o(o(o(o(o(o(U(U(U(U(U(R(l(lE8(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(U(U(U(U(U(U(R(R(lE8E8E8E8E8E8E8E8(B4(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(U(U(U(R(lE8E8E8E8E8E8(B4E4(B4o(o(U(U(U(R(lE8(B4E4E4E4E4(B4o(U(U(R(lE8E8E8E8E8(B4E4(B4o(o(o(o(o(o(o(o(U(U(U(U(R(R(l(lE8E8(B4(B4(B4(B4(B4(B4(B4(B4(B4(B4(B4o(U(U(U(U(U(U(U(U(U(U(R(lE8(B4(B4(B4(B4(B4(B4(B4(B4(B4(B4o(U(U(U(U(U(U(U(U(U(R(l(lE8E8E8E8E8E8E8E8E8(B4(B4E4(B4o(o(o(o(o(U(U(U(U(U(U(R(l(lE8E8E8(B4E4E4E4(B4o(o(o(o(o(o(U(U(U(U(U(U(R(lE4(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(U(U(U(R(l(lE8(B4(B4(B4(B4(B4E4(B4o(o(o(o(o(o(U(U(U(R(l(l(lE8(B4(B4(B4(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(U(U(R(lE8E8(B4(B4(B4(B4(B4(B4(B4(B4E4(B4o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(R(l(lE8E8E8(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(U(U(U(R(l(lE8E8E8E8E8E8E8E8E8E8E8E8(B4E4E4(B4E4(B4E4(B4E4E4(B4E4E4(B4E4(B4o(o(U(U(U(R(lE8(B4E4E4E4E4(B4(B4o(o(o(o(o(U(U(R(R(lE8(B4(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(U(U(U(R(lE8E8E8(B4E4E4(B4o(o(U(U(R(lE8(B4E4E4(B4o(U(R(l(lE8(B4(B4(B4E4(B4(B4o(o(o(o(o(o(o(U(U(U(R(l(lE8(B4(B4(B4(B4(B4(B4E4(B4o(o(o(o(o(o(U(U(U(U(R(lE8E8(B4E4(B4o(o(U(R(l(lE8E8E8(B4(B4E4(B4o(o(o(o(o(U(U(U(U(R(R(lE8E8(B4E4(B4o(o(U(R(lE4E4E4E4(B4(B4(B4E4(B4(B4(B4o(U(R(l(lE8(B4E4E4E4(B4o(U(R(l(l(l(lE8(B4(B4(B4(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(U(U(U(U(R(l(lE8E8E8E8E8E8E8E8E8E8E8E8(B4E4E4(B4E4E4E4E4(B4E4(B4(B4E4(B4(B4(B4(B4E4E4E4(B4(B4o(o(o(o(U(U(U(U(U(R(lE8E8E8E8(B4(B4E4E4(B4o(o(o(U(U(U(U(R(R(R(lE8(B4(B4(B4E4(B4o(U(U(R(lE8(B4E4(B4o(o(o(U(U(U(U(R(lE8(B4(B4(B4E4(B4o(o(U(R(R(l(lE8E8(B4E4(B4(B4E4(B4o(o(o(o(o(U(U(U(U(U(U(R(l(lE8(B4E4E4(B4o(U(R(l(lE8(B4(B4E4(B4E4(B4o(U(R(l(l(l(lE8(B4E4(B4(B4(B4E4(B4(B4(B4E4(B4o(o(o(o(o(o(U(U(U(U(U(U(U(R(l(l(lE8E8(B4(B4(B4E4(B4o(o(o(U(U(U(U(R(l(lE8(B4(B4(B4(B4(B4E4(B4o(o(o(o(o(U(U(R(R(lE8(B4(B4E4(B4(B4o(U(R(lE8(B4(B4(B4E4E4(B4o(o(U(R(l(lE8(B4E4(B4o(U(R(lE4E4(B4o(U(U(R(lE8E8(B4E4E4(B4o(o(o(U(U(U(R(R(lE8E8(B4E4(B4o(o(o(o(o(o(o(o(U(U(U(U(R(lE8(B4(B4(B4(B4(B4E4E4(B4o(o(U(U(U(U(U(R(l(l(lE8(B4E4E4E4E4(B4o(U(U(U(R(R(lE8(B4(B4E4(B4o(U(U(R(lE8(B4(B4(B4(B4(B4E4(B4o(U(U(R(l(lE8E8(B4(B4(B4o(o(o(U(U(U(U(R(lE8E8(B4(B4(B4(B4(B4o(o(o(o(U(U(U(R(l(lE8(B4E4(B4o(o(U(U(R(l(lE8(B4(B4E4E4(B4(B4(B4(B4o(o(o(o(o(o(U(U(U(U(R(lE4(B4E4(B4(B4(B4E4(B4E4E4(B4o(o(U(R(lE8(B4E4(B4o(U(U(R(l(l(lE8E8E8(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(U(U(U(R(l(lE8(B4(B4(B4(B4(B4E4(B4o(o(o(o(o(o(U(U(R(R(lE8(B4E4(B4o(U(U(R(lE8E8(B4E4E4E4(B4o(U(R(l(lE8E8(B4E4E4E4(B4E4E4E4E4(B4o(o(U(R(lE4(B4E4(B4o(U(U(R(R(R(lE8E8E8(B4E4(B4(B4(B4(B4(B4(B4o(o(o(o(U(U(U(R(l(lE8E8(B4(B4(B4(B4o(o(o(o(U(U(U(R(lE8E8E8E8E8E8E8E8(B4(B4E4(B4o(o(o(o(U(U(U(R(lE8E8(B4E4(B4o(o(U(R(R(lE8(B4E4(B4(B4o(o(U(U(R(l(l(lE8E8(B4E4E4(B4(B4(B4o(o(o(o(o(o(o(U(U(U(R(l(lE8E8E8E8(B4(B4(B4E4(B4E4(B4o(o(U(R(lE4E4E4(B4o(U(R(lE8E8E8E8E8E8E8E8(B4E4(B4(B4o(o(o(o(o(U(U(U(U(R(l(lE8(B4(B4E4E4E4(B4o(o(o(o(U(U(R(lE8(B4E4E4E4(B4o(o(U(R(lE8E8(B4E4(B4o(o(o(o(U(U(U(U(R(l(l(lE8(B4(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(U(U(U(R(lE8E8E8(B4(B4(B4(B4(B4E4E4E4E4(B4o(o(U(U(U(U(U(R(lE8E8E8(B4(B4E4E4E4(B4o(o(o(o(o(U(U(U(R(lE8(B4E4E4E4(B4o(o(o(o(U(U(U(R(l(lE8(B4E4(B4(B4o(o(o(o(U(U(U(R(l(lE8(B4(B4(B4(B4(B4(B4(B4(B4o(o(o(U(U(U(U(R(R(lE8(B4E4(B4(B4o(o(U(U(U(R(lE8(B4(B4E4(B4E4E4(B4o(o(U(R(l(l(lE8(B4(B4(B4(B4(B4E4E4(B4o(o(U(R(lE4E4(B4(B4o(o(U(U(R(lE8(B4(B4(B4o(o(o(U(U(R(lE4E4(B4E4(B4o(U(U(R(l(lE8(B4E4(B4o(U(U(R(lE4E4E4E4E4(B4E4(B4o(U(R(l(l(l(lE8(B4(B4E4E4(B4(B4o(o(o(U(U(U(U(R(l(lE8E8(B4E4E4E4(B4E4E4(B4o(U(U(R(lE4E4(B4o(o(U(R(lE8(B4E4E4E4(B4E4(B4(B4o(U(R(l(l(lE8E8(B4E4(B4(B4(B4(B4(B4(B4o(o(o(U(U(U(R(l(lE8(B4(B4(B4(B4(B4(B4(B4(B4o(o(o(U(U(U(U(U(U(R(lE8(B4(B4(B4(B4(B4(B4o(o(o(o(U(U(U(R(lE8E8(B4(B4(B4(B4o(o(o(o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(U(R(R(lE8(B4(B4(B4E4E4E4E4(B4o(o(o(o(o(U(U(U(U(U(U(R(lE8(B4(B4(B4E4E4(B4o(U(R(lE8E8(B4E4(B4o(U(R(lE4E4E4(B4(B4E4(B4o(U(U(R(R(lE8(B4E4E4(B4o(U(R(lE8(B4E4E4E4E4(B4o(U(U(R(lE8E8E8E8E8(B4E4(B4o(U(U(U(R(lE8E8(B4(B4(B4o(U(U(R(lE8(B4E4(B4(B4E4E4E4(B4E4E4(B4o(o(o(o(o(U(U(R(lE8(B4E4(B4o(o(o(o(o(o(o(U(U(U(U(U(R(l(lE8(B4(B4E4(B4o(U(R(lE4(B4E4(B4o(o(o(o(o(o(o(o(o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(U(U(U(U(U(U(U(U(U(U(U(U(R(l(lE8(B4(B4(B4(B4E4(B4(B4(B4E4E4(B4(B4(B4o(o(o(o(o(o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(U(U(U(U(U(U(U(U(R(lE8(B4(B4(B4(B4E4E4E4(B4E4E4(B4o(o(o(U(U(U(U(U(U(R(lE8(B4E4(B4o(o(o(U(U(U(U(U(R(lE8(B4(B4(B4E4(B4o(o(U(U(R(lE8(B4E4(B4(B4o(U(R(lE4E4E4(B4(B4E4E4E4(B4o(U(R(l(l(lE8(B4(B4E4E4E4(B4o(U(U(U(R(lE8(B4(B4(B4(B4o(U(R(R(l(lE8E8(B4E4(B4(B4(B4E4(B4(B4(B4o(o(o(o(U(U(R(lE8(B4E4E4E4(B4(B4o(o(o(U(R(lE8(B4E4E4E4(B4(B4o(o(o(o(U(U(R(lE8(B4E4(B4(B4E4(B4(B4E4E4(B4E4E4E4E4(B4E4(B4o(U(R(lE4E4(B4(B4(B4E4(B4E4(B4o(U(R(R(lE8(B4E4E4(B4E4(B4o(o(o(U(U(R(lE8E8E8(B4E4E4(B4(B4E4(B4(B4E4E4(B4o(o(o(o(U(U(U(R(l(l(lE8(B4(B4(B4(B4(B4(B4(B4(B4o(o(o(o(o(o(o(o(o(U(U(U(U(R(lE8(B4E4(B4(B4(B4(B4E4E4(B4(B4o(o(U(U(U(U(R(l(lE8(B4E4(B4o(o(U(U(R(l(lE8E8(B4E4E4E4(B4(B4(B4o(U(U(R(lE8(B4E4(B4o(o(U(U(U(R(l(lE8E8E8E8(B4(B4o(o(o(o(U(U(R(lE8E8(B4(B4(B4E4(B4(B4(B4o(o(U(U(R(lE4E4E4E4(B4E4E4(B4(B4(B4(B4o(U(R(lE8E8(B4E4(B4o(o(U(R(l(lE8E8E8E8(B4(B4(B4(B4(B4E4(B4o(o(o(o(o(U(U(U(U(R(lE8E8(B4(B4(B4E4E4(B4(B4(B4o(o(o(o(U(U(U(R(lE8(B4E4E4E4E4E4(B4(B4o(o(U(U(U(U(U(U(U(U(U(U(R(l(lE8(B4E4(B4(B4E4(B4E4(B4E4(B4E4E4E4(B4o(U(R(l(lE8E8E8(B4(B4(B4(B4E4E4E4(B4E4E4(B4(B4E4(B4E4E4(B4E4E4E4(B4E4(B4E4E4(B4(B4(B4(B4o(o(o(o(o(U(R(lE8E8(B4E4(B4(B4E4(B4(B4o(o(U(U(R(l(l(l(lE8(B4(B4E4(B4(B4(B4E4E4(B4(B4(B4o(o(o(U(U(U(U(U(R(l(lE8E8(B4(B4E4(B4o(o(o(o(U(U(U(U(U(R(l(lE8E8(B4E4E4E4(B4(B4o(o(U(U(U(U(U(U(U(U(R(l(lE8E8E8E8E8(B4E4(B4o(U(R(l(lE8E8E8(B4(B4(B4(B4E4E4E4(B4(B4o(U(U(U(U(U(U(U(U(R(lE8(B4(B4(B4E4E4E4(B4o(o(U(U(U(U(U(U(U(U(U(R(lE8(B4(B4(B4(B4(B4E4(B4(B4o(o(U(U(U(U(U(U(U(R(lE8E8E8(B4(B4(B4E4(B4E4(B4o(U(U(U(U(U(U(R(lE8(B4E4E4E4E4E4(B4E4(B4o(o(U(U(U(U(U(U(U(U(R(lE8E8E8E8(B4E4(B4o(U(U(U(R(lE8(B4E4E4E4E4E4E4E4(B4o(o(o(o(o(U(U(U(U(U(U(U(U(U(U(R(lE8E8(B4E4E4(B4o(U(R(l(lE8(B4E4E4E4E4(B4E4(B4o(U(R(l(l(lE8(B4(B4(B4(B4(B4(B4E4(B4E4E4E4(B4o(o(o(o(o(o(o(o(o(o(o(o(U(U(U(U(U(R(lE8E8(B4E4(B4E4E4E4E4E4E4(B4(B4o(o(U(U(U(R(lE8(B4E4E4E4E4(B4(B4o(U(U(U(U(R(lE8E8E8(B4(B4E4E4E4E4E4(B4o(o(o(U(U(U(R(lE8(B4E4(B4(B4o(U(U(U(U(U(R(lE8(B4(B4(B4(B4(B4(B4(B4o(o(o(o(U(U(U(U(U(R(lE8E8(B4E4(B4E4(B4o(o(U(U(U(U(U(U(R(lE8(B4E4(B4(B4o(o(o(U(U(U(R(l(lE8E8(B4(B4E4E4(B4o(U(R(l(lE8(B4(B4(B4E4(B4E4(B4E4(B4o(o(U(U(U(R(lE8E-)]])

end

-- Deferred loading mechanism
local function TryRegister()
    if Hekili and Hekili.Class and Hekili.Class.specs and Hekili.Class.specs[0] then
        RegisterMistweaverSpec()
        mwCombatLogFrame:UnregisterEvent("ADDON_LOADED")
        return true
    end
    return false
end

if not TryRegister() then
    mwCombatLogFrame:RegisterEvent("ADDON_LOADED")
    mwCombatLogFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "Hekili" or TryRegister() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
