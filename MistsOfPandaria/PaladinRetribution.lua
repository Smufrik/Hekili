-- PaladinRetribution.lua
-- Updated Sep 28, 2025 - Modern Structure
-- Mists of Pandaria module for Paladin: Retribution spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'PALADIN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State
local spec = Hekili:NewSpecialization( 70 )

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local function UA_GetPlayerAuraBySpellID(spellID)
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitBuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    for i = 1, 40 do
        local name, _, count, _, duration, expires, caster, _, _, id = UnitDebuff("player", i)
        if not name then break end
        if id == spellID then return name, _, count, _, duration, expires, caster end
    end
    return nil
end

-- MoP Seal detection
local function GetActiveSeal()
    -- In MoP, check for active seal through stance/shapeshift detection
    local numForms = GetNumShapeshiftForms()
    for i = 1, numForms do
        local _, active, castable, spellID = GetShapeshiftFormInfo(i)
        if active then
            if spellID == 31801 then -- Seal of Truth
                return "seal_of_truth", spellID
            elseif spellID == 20164 then -- Seal of Justice
                return "seal_of_justice", spellID
            elseif spellID == 20165 then -- Seal of Insight
                return "seal_of_insight", spellID
            elseif spellID == 20154 then -- Seal of Righteousness
                return "seal_of_righteousness", spellID
            end
        end
    end
    return nil, nil
end

-- Planned seals within a single recommendation build (prevents duplicate seal spam in queue)
spec:RegisterStateTable( "planned_seal", setmetatable( {}, { __index = function() return false end } ) )

-- Clear planned seals at the beginning of each recommendation build
spec:RegisterHook( "reset_precast", function ()
    if state.planned_seal then
        for k in pairs( state.planned_seal ) do
            state.planned_seal[ k ] = nil
        end
    end
end )

-- Combat Log Event Frame for advanced tracking
local retri_combat_log_frame = CreateFrame("Frame")
retri_combat_log_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
retri_combat_log_frame:SetScript("OnEvent", function(self, event, ...)
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    if sourceGUID ~= UnitGUID("player") then return end

    -- Divine Purpose proc tracking
    if eventType == "SPELL_CAST_SUCCESS" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        -- Track Holy Power spending abilities for Divine Purpose proc potential
        if spellID == 85256 or spellID == 53385 or spellID == 114165 then -- Templar's Verdict, Divine Storm, Holy Wrath
            -- Store last Holy Power ability for Divine Purpose checks
            ns.last_holy_power_ability = GetTime()
        end
    end

    -- Art of War proc tracking
    if eventType == "SPELL_CAST_SUCCESS" or eventType == "SPELL_DAMAGE" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        -- Track auto attacks and certain abilities that can proc Art of War
        if spellID == 6603 or spellID == 35395 then -- Auto Attack, Crusader Strike
            -- Check for Art of War proc (instant Exorcism)
            if UA_GetPlayerAuraBySpellID(59578) then
                ns.art_of_war_proc_time = GetTime()
            end
        end
    end

    -- Zealotry stack tracking for Enhanced Crusader Strike
    if eventType == "SPELL_CAST_SUCCESS" then
        local spellID = select(12, CombatLogGetCurrentEventInfo())
        if spellID == 35395 then -- Crusader Strike
            ns.crusader_strike_stacks = (ns.crusader_strike_stacks or 0) + 1
            if ns.crusader_strike_stacks > 3 then
                ns.crusader_strike_stacks = 3
            end
        end
    end
end)

-- Enhanced resource systems
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    seal_of_insight = {
        last = function ()
            return state.swing.last_taken
        end,

        interval = function ()
            return state.swing.swing_time
        end,

        stop = function ()
            return state.buff.seal_of_insight.down or state.swing.last_taken == 0
        end,

        value = function ()
            return 0.04 * state.mana.max -- 4% mana on melee hit
        end,
    },
} )

spec:RegisterResource( 9, { -- HolyPower = 9 in MoP
    crusader_strike = {
        last = function ()
            return state.abilities.crusader_strike.lastCast
        end,

        interval = function ()
            return state.abilities.crusader_strike.cooldown
        end,

        stop = function ()
            return state.abilities.crusader_strike.lastCast == 0
        end,

        value = 1,
    },

    hammer_of_wrath = {
        last = function ()
            return state.abilities.hammer_of_wrath.lastCast
        end,

        interval = function ()
            return state.abilities.hammer_of_wrath.cooldown
        end,

        stop = function ()
            return state.abilities.hammer_of_wrath.lastCast == 0 or state.target.health_pct > 20
        end,

        value = 1,
    },

    divine_purpose = {
        last = function ()
            return ns.last_holy_power_ability or 0
        end,

        interval = 1.0,

        stop = function ()
            return not state.talent.divine_purpose.enabled or not state.buff.divine_purpose.up
        end,

        value = function ()
            return state.talent.divine_purpose.enabled and state.buff.divine_purpose.up and 3 or 0
        end,
    },
} )

-- Comprehensive Tier sets with MoP gear progression
spec:RegisterGear( "tier14", 85339, 85340, 85341, 85342, 85343, 86679, 86680, 86681, 86682, 86683, 87099, 87100, 87101, 87102, 87103 )
spec:RegisterGear( "tier15", 95280, 95281, 95282, 95283, 95284, 95910, 95911, 95912, 95913, 95914, 96654, 96655, 96656, 96657, 96658 )
spec:RegisterGear( "tier16", 99132, 99136, 99137, 99138, 99139, 98985, 98986, 98987, 99002, 99052, 99372, 99373, 99374, 99379, 99380 )

-- Notable MoP Paladin items and legendary
spec:RegisterGear( "legendary_cloak", 102249 ) -- Qian-Ying, Fortitude of Niuzao
spec:RegisterGear( "kor_kron_dark_shaman_gear", 105369, 105370, 105371 ) -- SoO specific items
spec:RegisterGear( "prideful_gladiator", 103823, 103824, 103825, 103826, 103827 ) -- PvP gear

-- Tier set bonuses as auras
spec:RegisterAura( "ret_tier14_2pc", {
    id = 123108,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "ret_tier14_4pc", {
    id = 70762,
    duration = 3600,
    max_stack = 1,
} )

spec:RegisterAura( "ret_tier15_2pc", {
    id = 138159,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterAura( "ret_tier15_4pc", {
    id = 138164,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterAura( "ret_tier16_2pc", {
    id = 144586,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterAura( "ret_tier16_4pc", {
    id = 144593,
    duration = 3600,
    max_stack = 1,
} )

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Movement
    speed_of_light            = { 1, 1, 85499  }, -- +70% movement speed for 8 sec
    long_arm_of_the_law       = { 1, 2, 87172 }, -- Judgments increase movement speed by 45% for 3 sec
    pursuit_of_justice        = { 1, 3, 26023  }, -- +15% movement speed per Holy Power charge

    -- Tier 2 (Level 30) - Control
    fist_of_justice           = { 2, 1, 105593 }, -- Reduces Hammer of Justice cooldown by 50%
    repentance                = { 2, 2, 20066  }, -- Puts the enemy target in a state of meditation, incapacitating them for up to 1 min.
    blinding_light            = { 2, 3, 115750 }, -- Emits dazzling light in all directions, blinding enemies within 10 yards for 6 sec.

    -- Tier 3 (Level 45) - Healing
    selfless_healer           = { 3, 1, 85804  }, -- Your Holy power spending abilities reduce the cast time and mana cost of your next Flash of Light.
    eternal_flame             = { 3, 2, 114163 }, -- Consumes all Holy Power to place a protective Holy flame on a friendly target, which heals over 30 sec.
    sacred_shield             = { 3, 3, 20925  }, -- Places a Sacred Shield on a friendly target, absorbing damage every 6 sec for 30 sec.

    -- Tier 4 (Level 60) - Utility/CC
    hand_of_purity            = { 4, 1, 114039 }, -- Protects a party or raid member, reducing harmful periodic effects by 70% for 6 sec.
    unbreakable_spirit        = { 4, 2, 114154 }, -- Reduces the cooldown of your Divine Shield, Divine Protection, and Lay on Hands by 50%.
    clemency                  = { 4, 3, 105622 }, -- Increases the number of charges on your Hand spells by 1.

    -- Tier 5 (Level 75) - DPS
    divine_purpose            = { 5, 1, 86172  }, -- Your Holy Power abilities have a 15% chance to make your next Holy Power ability free and more effective.
    holy_avenger              = { 5, 2, 105809 }, -- Your Holy power generating abilities generate 3 charges of Holy Power for 18 sec.
    sanctified_wrath          = { 5, 3, 53376  }, -- Increases the duration of Avenging Wrath by 5 sec and causes your Judgment to generate 1 additional Holy Power during Avenging Wrath.

    -- Tier 6 (Level 90) - DPS/Utility
    holy_prism                = { 6, 1, 114165 }, -- Fires a beam of light that hits a target for Holy damage or healing.
    lights_hammer             = { 6, 2, 114158 }, -- Hurls a Light-infused hammer to the ground, dealing Holy damage to enemies and healing allies.
    execution_sentence        = { 6, 3, 114157 }  -- A hammer slowly falls from the sky, dealing Holy damage to an enemy or healing an ally.
} )

-- Comprehensive Retribution Paladin Glyphs for MoP
spec:RegisterGlyphs( {
    -- Major Glyphs
    [54927] = "avenging_wrath",    -- While Avenging Wrath is active, you are healed for 1% of your maximum health every 2 sec.
    [54943] = "blessed_life",      -- You have a 50% chance to gain a charge of Holy Power whenever you are affected by a Stun, Fear or Immobilize effect.
    [54934] = "blinding_light",    -- Your Blinding Light now knocks down targets for 3 sec instead of Blinding them.
    [54931] = "burden_of_guilt",   -- Your Judgment hits fill your target with doubt and remorse, reducing movement speed by 50% for 2 sec.
    [146955] = "devotion_aura",     -- Devotion Aura no longer affects party or raid members, but the cooldown is reduced by 60 sec.
    [54924] = "divine_protection", -- Reduces the magical damage reduction of your Divine Protection to 20% but adds 20% physical damage reduction.
    [146956] = "divine_shield",     -- Removing harmful effects with Divine Shield heals you for 10% for each effect removed.  This heal cannot exceed 50% of your maximum health.
    [63220] = "divine_storm",      -- Your Divine Storm also heals you for 5% of your maximum health.
    [63221] = "divinity",      		-- Increases the cooldown of your Lay on Hands by 2 min but causes it to give you 10% of your maximum mana.
    [54922] = "double_jeopardy",   -- Your Judgment deals 20% additional damage when striking a target already affected by your Judgment.
    [57955] = "flash_of_light",    -- When you Flash of Light a target, it increases your next heal done to that target within 7 sec by 10%.
    [63219] = "hammer_of_the_righteous", -- The physical damage reduction caused by Hammer of the Righteous now lasts 50% longer.
    [146957] = "hand_of_sacrifice", -- Hand of Sacrifice no longer redirects damage to the Paladin.
    [54938] = "harsh_words", 		-- Your Word of Glory can now also be used on enemy targets, causing Holy damage approximately equal to the amount it would have healed.
    [54939] = "immediate_truth", 		-- Increases the instant damage done by Seal of Truth by 40%, but decreases the damage done by Censure by 50%.
    [63225] = "inquisition",       -- When you land a killing blow on an opponent that yields experience or honor, the duration of your Inquisition is increased by 30 sec.
    [122028] = "mass_exorcism",     -- Reduces the range of Exorcism to melee range, but causes 25% damage to all enemies within 8 yards of the primary target.
    [93466] = "protector_of_the_innocent",     -- When you use Word of Glory to heal another target, it also heals you for 20% of the amount.
    [54926] = "templars_verdict",  -- You take 10% less damage for 6 sec after dealing damage with Templar's Verdict or Exorcism.
	[119477] = "the_battle_healer",     -- Melee attacks from Seal of Insight heal the most wounded member of your raid or party for 30% of the normal heal instead of you.
    [54936] = "word_of_glory",     -- Increases your damage by 3% per Holy Power spent after you cast Word of Glory or Eternal Flame on a friendly target. Lasts 6 sec.

	--	[54935] = "final_wrath",       -- Your Holy Wrath does an additional 50% damage to targets with less than 20% health.
    --	[56417] = "zealotry",          -- Your Zealotry ability lasts 10 additional seconds.
	--	[54928] = "consecration",      -- You can now target Consecration anywhere within 25 yards.
    --	[56419] = "turn_evil",         -- Your Turn Evil spell is now instant cast.
    --	[63218] = "divine_favor",      -- Your Divine Favor now increases your spell critical strike chance by 25% for the next 3 spells.
    --	[56418] = "cleanse",           -- Your Cleanse spell can be cast on hostile targets to remove beneficial magic effects.
    --	[57958] = "divine_storm_heal", -- Your Divine Storm heals you for 25% of total damage done.
    --	[57956] = "blessing_of_kings", -- Your Blessing of Kings increases stats by an additional 5%.
    --	[57957] = "blessing_of_might", -- Your Blessing of Might increases attack power by an additional 10%.
    --	[63217] = "holy_light",        -- Reduces the cast time of your Holy Light by 0.5 sec.
	--	[54936] = "lay_on_hands",      -- Your Lay on Hands grants forbearance for 30 sec less.
    --	[57959] = "retribution_aura",  -- Your Retribution Aura reflects 50% more damage.
    --	[57960] = "concentration_aura", -- Your Concentration Aura also provides 15% resistance to interrupt effects.
    --	[56423] = "guardian_spirit",   -- Your Guardian Spirit prevents the target from dying below 10% health.
    --	[57961] = "shadow_resistance_aura", -- Your Shadow Resistance Aura also reduces shadow damage taken by 20%.
    --	[57962] = "fire_resistance_aura",   -- Your Fire Resistance Aura also reduces fire damage taken by 20%.
    --	[57963] = "frost_resistance_aura",  -- Your Frost Resistance Aura also reduces frost damage taken by 20%.

    -- Minor Glyphs - all just comesmitc
    --	[115934] = "bladed_judgment", -- Your Judgment spell depicts an axe or sword instead of a hammer, if you have an axe or sword equipped.
    --	[125043] = "contemplation", -- Allows you a moment of peace as you kneel in quiet contemplation to ponder the nature of the Light.
    --	[57954] = "fire_from_heaven",  -- Your Judgment and Hammer of Wrath criticals call down fire from the sky.
    --	[115933] = "righteous_retreat", -- During Divine Shield, you can invoke your Hearthstone 50% faster.
    --	[57948] = "insight",           -- Your spells and abilities reduce the remaining cooldown on your Lay on Hands by 5 sec when they critically hit.
    --	[57949] = "justice",           -- Increases the range of your Hammer of Justice by 5 yards.
    --	[57950] = "seal_of_blood",     -- Your melee attacks heal you for 2% of the damage dealt.
    --	[57951] = "sense_undead",      -- Your Sense Undead ability also increases movement speed by 30% for 15 sec.
    --	[57952] = "the_wise",          -- Reduces the mana cost of your Blessing spells by 50%.
    --	[57953] = "truth",             -- Reduces the cooldown of your Hand of Reckoning by 2 sec.
    --	[43340] = "blessing_of_wisdom", -- Your Blessing of Wisdom increases mana regeneration by an additional 50%.
    --	[43355] = "blessing_of_sanctuary", -- Your Blessing of Sanctuary reduces damage taken by an additional 5%.
    --	[43356] = "crusader_strike",   -- Your Crusader Strike heals a nearby injured ally for 30% of the damage dealt.
    --	[43357] = "divine_storm_visual", -- Your Divine Storm creates a more dramatic visual effect.
    --	[43358] = "hammer_of_wrath_range", -- Increases the range of your Hammer of Wrath by 5 yards.
    --	[43359] = "seal_of_command",   -- Your Seal of Command has a 25% chance to not trigger its cooldown.
} )

-- Helper function for consistent aura detection
-- GetPlayerAuraBySpellID equivalent for older clients
local function GetPlayerAuraBySpellID(spellID)
    if UA_GetPlayerAuraBySpellID then
        return UA_GetPlayerAuraBySpellID(spellID)
    end
    return FindUnitBuffByID("player", spellID)
end

-- Enhanced target debuff detection
local function GetTargetDebuffByID(spellID, caster)
    caster = caster or "player"
    local name, icon, count, debuffType, duration, expirationTime, unitCaster = FindUnitDebuffByID("target", spellID)
    if name and (unitCaster == caster or caster == "any") then
        return name, icon, count, debuffType, duration, expirationTime, unitCaster
    end
    return nil
end

-- Advanced Retribution Paladin Auras with Enhanced Generate Functions
spec:RegisterAuras({
    blessing_of_kings = {
        id = 20217,
        duration = 3600,
        max_stack = 1,
    },

    blessing_of_might = {
        id = 19740,
        duration = 3600,
        max_stack = 1,
    },

    -- Alias aura that represents any blessing being active
    blessing = {
        alias = { "blessing_of_kings", "blessing_of_might" },
        aliasMode = "first",
        aliasType = "buff",
    },

    -- Inquisition: Key damage buff with enhanced tracking
    inquisition = {
        id = 84963,
        duration = function()
            local duration = 20 + (10 * state.holy_power.current) -- Base + per Holy Power
            if state.glyph.inquisition.enabled then
                duration = duration + 30
            end
            return duration
        end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(84963)

            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.stacks = count
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.stacks = 0
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Divine Purpose: Free and enhanced Holy Power ability
    divine_purpose = {
        id = 90174,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(86172)

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Art of War: Instant Exorcism proc
    art_of_war = {
        id = 59578,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(59578)

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Zealotry: Enhanced Crusader Strike damage
    --	zealotry = {
    --	    id = 85696,
    --	    duration = 20,
    --	    max_stack = 3,
    --	    generate = function( t )
    --	        local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(85696)
	--
    --	        if name then
    --	            t.name = name
    --	            t.count = count > 0 and count or 1
    --	            t.expires = expirationTime
    --	            t.applied = expirationTime - duration
    --	            t.caster = caster
    --	            t.stacks = count
    --	            t.up = true
    --	            t.down = false
    --	            t.remains = expirationTime - GetTime()
    --	            return
    --	        end

    --	        t.count = 0
    --	        t.expires = 0
    --	        t.applied = 0
    --	        t.caster = "nobody"
    --	        t.stacks = 0
    --	        t.up = false
    --	        t.down = true
    --	        t.remains = 0
    --	    end
    --	},

    -- Ancient Power: Guardian of the Kings Buff
    ancient_power = {
        id = 86700,
        duration = 30,
        max_stack = 12,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(86700)

            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.stacks = count
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.stacks = 0
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Avenging Wrath: Wings!
    avenging_wrath = {
        id = 31884,
        duration = function()
            local duration = 20
            if state.talent.sanctified_wrath.enabled then
                duration = duration + 5
            end
            if state.glyph.avenging_wrath.enabled then
                -- Glyph effect
            end
            return duration
        end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(31884)

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Guardian of Ancient Kings
    guardian_of_ancient_kings = {
        id = 86659,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(86659)

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Divine Protection
    divine_protection = {
        id = 498,
        duration = function()
            local duration = 10
            if state.glyph.divine_protection.enabled then
                duration = 20 -- Glyph increases duration but reduces effectiveness
            end
            return duration
        end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(498)

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Divine Shield
    divine_shield = {
        id = 642,
        duration = function()
            local duration = 8
            if state.glyph.divine_shield.enabled then
                duration = duration - 4 -- Glyph reduces duration but also cooldown
            end
            return duration
        end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(642)

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Seals
    seal_of_truth = {
        id = 31801,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_truth" then
                t.name = GetSpellInfo(31801) or "Seal of Truth"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    seal_of_justice = {
        id = 20164,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_justice" then
                t.name = GetSpellInfo(20164) or "Seal of Justice"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    seal_of_insight = {
        id = 20165,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_insight" then
                t.name = GetSpellInfo(20165) or "Seal of Insight"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    seal_of_righteousness = {
        id = 20154,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local activeSeal, spellID = GetActiveSeal()

            if activeSeal == "seal_of_righteousness" then
                t.name = GetSpellInfo(20154) or "Seal of Righteousness"
                t.count = 1
                t.expires = GetTime() + 3600 -- Seals don't expire
                t.applied = GetTime()
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Target debuffs
    censure = {
        id = 31803,
        duration = 15,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID(31803, "player")

            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.stacks = count
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.stacks = 0
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Judgment debuffs
    judgment_of_justice = {
        id = 20170,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID(20170, "player")

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    judgment_of_truth = {
        id = 31804,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID(31804, "player")

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    holy_avenger = {
        id = 105809,
        duration = 18,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(105809)

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    divine_crusader = {
        id = 144595,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(144595)

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Tier set bonuses
    ret_tier14_2pc = {
        id = 123108,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.set_bonus.tier14_2pc > 0 then
                t.name = "Retribution T14 2-Piece Bonus"
                t.count = 1
                t.expires = query_time + 3600
                t.applied = query_time
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    ret_tier14_4pc = {
        id = 70762,
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            if state.set_bonus.tier14_4pc > 0 then
                t.name = "Retribution T14 4-Piece Bonus"
                t.count = 1
                t.expires = query_time + 3600
                t.applied = query_time
                t.caster = "player"
                t.up = true
                t.down = false
                t.remains = 3600
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- T15 2pc: Target takes 6% increased Holy damage from your attacks for 6 sec after Exorcism.
    ret_tier15_2pc = {
        id = 138159,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            -- Only relevant if you own the set bonus.
            if ( state.set_bonus.tier15_2pc or 0 ) <= 0 then
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                t.up = false
                t.down = true
                t.remains = 0
                return
            end

            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 138159, "player" )
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end,
    },

    -- T15 4pc: Your next Templar's Verdict is dealt as holy damage.
    ret_tier15_4pc = {
        id = 138164,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            if ( state.set_bonus.tier15_4pc or 0 ) <= 0 then
                t.count = 0
                t.expires = 0
                t.applied = 0
                t.caster = "nobody"
                t.up = false
                t.down = true
                t.remains = 0
                return
            end

            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID( 138169 )
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    ret_tier16_2pc = {
        id = 144586,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetPlayerAuraBySpellID(144586)

            if name and state.set_bonus.tier16_2pc > 0 then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end
              t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },
} )



-- Abilities
spec:RegisterAbilities( {
    -- Guardian of Ancient Kings (Ret version): Major damage cooldown
    guardian_of_ancient_kings = {
        id = 86698,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 86698 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Holy Avenger: Holy Power abilities more effective
    holy_avenger = {
        id = 105809,
        duration = 18,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105809 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime - GetTime()
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Divine Protection: Reduces damage taken
    divine_protection = {
        id = 498,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 498 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Divine Shield: Complete immunity
    divine_shield = {
        id = 642,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 642 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Forbearance: Cannot receive certain immunities again
    forbearance = {
        id = 25771,
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "player", 25771 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Speed of Light: Increased movement speed
    speed_of_light = {
        id = 85499,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 85499 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Long Arm of the Law: Increased movement speed after Judgment
    long_arm_of_the_law = {
        id = 87173,
        duration = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 87173 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Pursuit of Justice: Increased movement speed from Holy Power
    pursuit_of_justice = {
        id = 26023,
        duration = 3600,
        max_stack = 3,
        generate = function( t )
            t.count = state.holy_power.current
            t.expires = 3600
            t.applied = 0
            t.caster = "player"
        end
    },

    -- Hand of Freedom: Immunity to movement impairing effects
    hand_of_freedom = {
        id = 1044,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1044, "PLAYER" )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Hand of Protection: Immunity to physical damage
    hand_of_protection = {
        id = 1022,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1022, "PLAYER" )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Hand of Sacrifice: Redirects damage to Paladin
    hand_of_sacrifice = {
        id = 6940,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "target", 6940, "PLAYER" )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Sacred Shield: Absorbs damage periodically
    sacred_shield = {
        id = 65148,
        duration = 30,
        tick_time = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 65148 )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },

    -- Eternal Flame: HoT from talent
    eternal_flame = {
        id = 114163,
        duration = function() return 30 + (3 * state.holy_power.current) end,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114163, "PLAYER" )

            if name then
                t.name = name
                t.count = count
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end
    },
} )

-- Retribution Paladin abilities
spec:RegisterAbilities( {
    -- Core Retribution abilities
    templars_verdict = {
        id = 85256,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function()
            if state.buff.divine_purpose.up then return 0 end
            return 3
        end,
        spendType = "holy_power",

        startsCombat = true,
        texture = 461860,

        handler = function()
            -- Templar's Verdict mechanic
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            end
            -- T15 4pc: Consumes the proc damage buff (if emulated/predicted).
            if state.buff.ret_tier15_4pc.up then
                removeBuff("ret_tier15_4pc")
            end
        end
    },

    divine_storm = {
        id = 53385,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function()
            if state.buff.divine_purpose.up then return 0 end
            return 3
        end,
        spendType = "holy_power",

        startsCombat = true,
        texture = 236250,

        handler = function()
            -- Divine Storm mechanic
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            end
        end
    },

    exorcism = {
        id = function()
            return state.glyph.mass_exorcism.enabled and 122032 or 879
        end,
        -- Map both spellIDs to this same ability key.
        copy = { 879, 122032 },
        cast = 0,
		cooldown = 15,
        gcd = "spell",

        spend = function()
            if state.buff.art_of_war.up then return 0 end
            return 0.18
        end,
        spendType = "mana",

        startsCombat = true,
        texture = 135903,

            -- Exorcism should be considered known if the player knows the spell.
            -- NOTE: The second parameter to IsSpellKnownOrOverridesKnown is 'isPetSpell'; passing true would incorrectly hide Exorcism.
            known = function()
                return state.IsSpellKnownOrOverridesKnown(879)
                    or state.IsSpellKnown(879)
                    or state.IsSpellKnownOrOverridesKnown(122032)
                    or state.IsSpellKnown(122032)
                    or state.buff.art_of_war.up
            end,

        usable = function()
            -- Always usable from the engine perspective; range/targeting handled by the client.
            return true
        end,

        handler = function()
            -- Exorcism mechanic
            if state.buff.art_of_war.up then
                removeBuff("art_of_war")
            end
            if state.set_bonus.tier15_2pc > 0 then
                applyDebuff("target", "ret_tier15_2pc")
            end

            gain(1, "holy_power")
        end,
    },

    inquisition = {
        id = 84963,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function()
            if state.buff.divine_purpose.up then return 0 end
            return 3
        end,
        spendType = "holy_power",

        startsCombat = false,
        texture = 461858,

        handler = function()
            -- Inquisition mechanic - consumes all Holy Power for duration
            local duration = 30 * state.holy_power.current

            if state.buff.divine_purpose.up then
                -- If Divine Purpose, treat as 3 Holy Power
                removeBuff("divine_purpose")
                duration = 90
            end

            -- Glyph of Inquisition increases duration by 30 sec
            if state.glyph.inquisition.enabled then
                duration = duration + 30
            end

            applyBuff("inquisition", duration)
        end
    },

    guardian_of_ancient_kings = {
        id = 86698,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        toggle = "cooldowns",

        startsCombat = false,
        texture = 135919,

        handler = function()
            applyBuff("guardian_of_ancient_kings")
        end
    },

    avenging_wrath = {
        id = 31884,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        startsCombat = false,
        texture = 135875,

        handler = function()
            applyBuff("avenging_wrath")
        end
    },

    holy_avenger = {
        id = 105809,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        

        talent = "holy_avenger",
    toggle = "cooldowns",

        startsCombat = false,
        texture = 571555,

        handler = function()
            applyBuff("holy_avenger")
        end
    },

    holy_prism = {
        id = 114852,
        cast = 0,
        cooldown = 20,
        gcd = "spell",

        spend = 0.35,
        spendType = "mana",

        talent = "holy_prism",

        startsCombat = function() return not (state.settings and state.settings.holy_prism_heal) end,
        texture = 613407,

        handler = function()
            -- Holy Prism mechanic
            -- If cast on enemy, damages target and heals 5 nearby friendlies
            -- If cast on friendly, heals target and damages 5 nearby enemies
        end
    },

    lights_hammer = {
        id = 114158,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        spend = 0.38,
        spendType = "mana",

        talent = "lights_hammer",

        startsCombat = true,
        texture = 613955,

        handler = function()
            -- Light's Hammer mechanic - ground target AoE that heals allies and damages enemies
        end
    },

    execution_sentence = {
        id = 114157,
        cast = 0,
        cooldown = 60,
        gcd = "spell",

        spend = 0.38,
        spendType = "mana",

        talent = "execution_sentence",

        startsCombat = function() return not (state.settings and state.settings.execution_sentence_heal) end,
    toggle = "cooldowns",
        texture = 613954,

        handler = function()
            -- Execution Sentence mechanic
            -- If cast on enemy, damages after 10 seconds
            -- If cast on friendly, heals after 10 seconds
        end
    },

    divine_shield = {
        id = 642,
        cast = 0,
        cooldown = function()
            return state.talent.unbreakable_spirit.enabled and 150 or 300
        end,
        gcd = "spell",

        

        startsCombat = false,
        toggle = "defensives",
        texture = 524354,

        handler = function()
            applyBuff("divine_shield")
            applyDebuff("player", "forbearance")
        end
    },

    divine_protection = {
        id = 498,
        cast = 0,
        cooldown = function()
            return state.talent.unbreakable_spirit.enabled and 30 or 60
        end,
        gcd = "off",

        

        startsCombat = false,
        toggle = "defensives",
        texture = 524353,

        handler = function()
            applyBuff("divine_protection")
        end
    },

    flash_of_light = {
        id = 19750,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",

        spend = 0.378,
        spendType = "mana",

        startsCombat = false,
        texture = 135907,

        handler = function()
            -- Heals target for some amount of health
        end
    },

    lay_on_hands = {
        id = 633,
        cast = 0,
        cooldown = function()
            return state.talent.unbreakable_spirit.enabled and 360 or 600
        end,
        gcd = "spell",

        

        startsCombat = false,
        texture = 135928,

        handler = function()
            -- Heals target for Paladin's maximum health
            -- Applies Forbearance
            applyDebuff("target", "forbearance")
        end
    },

    hand_of_freedom = {
        id = 1044,
        cast = 0,
        cooldown = function()
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 25 }
            end
            return 25
        end,
        gcd = "spell",

        startsCombat = false,
        texture = 135968,

        handler = function()
            applyBuff("hand_of_freedom")
        end
    },

    hand_of_protection = {
        id = 1022,
        cast = 0,
        cooldown = function()
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 300 }
            end
            return 300
        end,
        gcd = "spell",

        

        startsCombat = false,
        texture = 135964,

        handler = function()
            applyBuff("hand_of_protection")
            applyDebuff("player", "forbearance")
        end
    },

    hand_of_sacrifice = {
        id = 6940,
        cast = 0,
        cooldown = function()
            if state.talent.clemency.enabled then
                return { charges = 2, execRate = 120 }
            end
            return 120
        end,
        gcd = "off",

        

        startsCombat = false,
        texture = 135966,

        handler = function()
            applyBuff("hand_of_sacrifice", "target")
        end
    },

    hand_of_purity = {
        id = 114039,
        cast = 0,
        cooldown = 30,
        gcd = "off",

        talent = "hand_of_purity",

        startsCombat = false,
        texture = 458726,

        handler = function()
            -- Applies Hand of Purity effect
        end
    },

    -- Shared Paladin abilities
    crusader_strike = {
        id = 35395,
        cast = 0,
        cooldown = 4.5,
        gcd = "spell",

        spend = 0.06,
        spendType = "mana",

        startsCombat = true,
        texture = 135891,

        handler = function()
            gain(1, "holy_power")
            -- T15 4pc: 40% chance to make next TV deal 40% more damage
            if state.set_bonus.tier15_4pc > 0 and state.buff.avenging_wrath.up then
                if math.random() < 0.40 then
                    applyBuff("ret_tier15_4pc", 6)
                end
            end
        end
    },

    hammer_of_the_righteous = {
        id = 53595,
        cast = 0,
        cooldown = 4.5,
        gcd = "spell",

        spend = 0.03,
        spendType = "mana",

        startsCombat = true,
        texture = 236253,

        handler = function()
            gain(1, "holy_power")
        end
    },

    judgment = {
        id = 20271,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = true,
        texture = 135959,

        handler = function()
            -- Sanctified Wrath talent interaction - Judgment generates 1 additional Holy Power during Avenging Wrath
            if state.buff.avenging_wrath.up and state.talent.sanctified_wrath.enabled then
                gain(2, "holy_power")
            else
                gain(1, "holy_power")
            end

            -- Long Arm of the Law movement speed
            if state.talent.long_arm_of_the_law.enabled then
                applyBuff("long_arm_of_the_law")
            end
        end
    },

    cleanse = {
        id = 4987,
        cast = 0,
        cooldown = 8,
        gcd = "spell",

        spend = 0.14,
        spendType = "mana",

        startsCombat = false,
        texture = 135949,

        handler = function()
            -- Removes 1 Poison effect, 1 Disease effect, and 1 Magic effect from a friendly target
        end
    },

    hammer_of_justice = {
        id = 853,
        cast = 0,
        cooldown = function()
            if state.talent.fist_of_justice.enabled then
                return 30
            end
            return 60
        end,
        gcd = "spell",

        startsCombat = true,
        texture = 135963,

        handler = function()
            -- Stuns target for 6 seconds
        end
    },

    hammer_of_wrath = {
        id = 24275,
        cast = 0,
        cooldown = 6,
        gcd = "spell",

        spend = 0.12,
        spendType = "mana",

        usable = function()
            -- Usable when target below 20% health or during Avenging Wrath
            return target.health_pct < 20 or state.buff.avenging_wrath.up
        end,

        startsCombat = true,
        texture = 613533,

        handler = function()
            gain(1, "holy_power")
        end
    },

    consecration = {
        id = 26573,
        cast = 0,
        cooldown = 9,
        gcd = "spell",

        spend = 0.24,
        spendType = "mana",

        startsCombat = true,
        texture = 135926,

        handler = function()
            -- Creates consecrated ground that deals Holy damage over time
        end
    },

    word_of_glory = {
        id = 85673,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = function()
            if state.buff.divine_purpose.up then return 0 end
            return 3
        end,
        spendType = "holy_power",

        startsCombat = false,
        texture = 646176,

        handler = function()
            -- Word of Glory mechanic - consumes all Holy Power
            if state.buff.divine_purpose.up then
                removeBuff("divine_purpose")
            else
                -- Modify healing based on Holy Power consumed
                -- Word of Glory's base healing amount is multiplied per Holy Power
            end

            -- Selfless Healer reductions for next Flash of Light if talented
            if state.talent.selfless_healer.enabled then
                applyBuff("selfless_healer", nil, 3)
            end

            -- Eternal Flame talent application instead of direct heal
            if state.talent.eternal_flame.enabled then
                applyBuff("eternal_flame")
            end
        end
    },

    repentance = {
        id = 20066,
        cast = 1.5,
        cooldown = 15,
        gcd = "spell",

        talent = "repentance",

        spend = 0.09,
        spendType = "mana",

        startsCombat = false,
        texture = 135942,

        handler = function()
            -- Incapacitates target for up to 1 minute
        end
    },

    blinding_light = {
        id = 115750,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        talent = "blinding_light",

        spend = 0.18,
        spendType = "mana",

        startsCombat = true,
        texture = 571553,

        handler = function()
            -- Disorients all nearby enemies
        end
    },

    speed_of_light = {
        id = 85499,
        cast = 0,
        cooldown = 45,
        gcd = "off",

        talent = "speed_of_light",

        startsCombat = false,
        texture = 538056,

        handler = function()
            applyBuff("speed_of_light")
        end
    },

    sacred_shield = {
        id = 20925,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        talent = "sacred_shield",

        spend = 0.23,
        spendType = "mana",

        startsCombat = false,
        texture = 612316,

        handler = function()
            applyBuff("sacred_shield")
        end
    },

    blessing_of_kings = {
        id = 20217,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 135993,

        handler = function()
            applyBuff("blessing_of_kings")
            removeBuff("blessing_of_might")
        end
    },

    blessing_of_might = {
        id = 19740,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        spend = 0.05,
        spendType = "mana",

        startsCombat = false,
        texture = 135908,

        handler = function()
            applyBuff("blessing_of_might")
            removeBuff("blessing_of_kings")
        end
    },

    seal_of_truth = {
        id = 31801,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 135969,

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_truth then return false, "seal_of_truth already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_righteousness")
            removeBuff("seal_of_justice")
            removeBuff("seal_of_insight")
            applyBuff("seal_of_truth")
            if state.planned_seal then state.planned_seal.seal_of_truth = true end
        end
    },

    seal_of_righteousness = {
        id = 20154,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 135960,

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_righteousness then return false, "seal_of_righteousness already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_truth")
            removeBuff("seal_of_justice")
            removeBuff("seal_of_insight")
            applyBuff("seal_of_righteousness")
            if state.planned_seal then state.planned_seal.seal_of_righteousness = true end
        end
    },

    seal_of_justice = {
        id = 20164,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 135971,

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_justice then return false, "seal_of_justice already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_truth")
            removeBuff("seal_of_righteousness")
            removeBuff("seal_of_insight")
            applyBuff("seal_of_justice")
            if state.planned_seal then state.planned_seal.seal_of_justice = true end
        end
    },

    seal_of_insight = {
        id = 20165,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        startsCombat = false,
        texture = 135917,

        usable = function()
            if state.planned_seal and state.planned_seal.seal_of_insight then return false, "seal_of_insight already planned" end
            return true
        end,

        handler = function()
            removeBuff("seal_of_truth")
            removeBuff("seal_of_righteousness")
            removeBuff("seal_of_justice")
            applyBuff("seal_of_insight")
            if state.planned_seal then state.planned_seal.seal_of_insight = true end
        end
    }
} )

-- States and calculations for Retribution specific mechanics
-- local function checkArtOfWar()
--     -- 20% chance to proc Art of War on Crusader Strike
--     return buff.art_of_war.up
-- end

-- state.RegisterExpressions( {
--     ['artOfWarActive'] = function()
--         return checkArtOfWar()
--     end
-- } )

-- Range
spec:RegisterRanges( "judgment", "hammer_of_justice", "rebuke", "crusader_strike" )

spec:RegisterAbilities({
    rebuke = {
        id = 96231,
    toggle = "interrupts",
        cast = 0,
        cooldown = 15,
        gcd = "off",

        
        startsCombat = true,

        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function() interrupt() end,
    },
})

-- Options
spec:RegisterOptions( {
    enabled = true,

    aoe = 2,

    nameplates = true,
    nameplateRange = 8,

    damage = true,
    damageExpiration = 8,

    potion = "jade_serpent_potion",

    package = "Retribution",

    holy_prism_heal = false,
    execution_sentence_heal = false,
} )

-- Expose settings to APL/emulator by name
spec:RegisterStateExpr( "recommend_seals", function()
    return state.settings and state.settings.recommend_seals or false
end )

spec:RegisterStateExpr( "seal_of_righteousness_threshold", function()
    return ( state.settings and state.settings.seal_of_righteousness_threshold ) or 4
end )

spec:RegisterSetting("recommend_seals", true, {
    name = "Recommend Seals",
    desc = "If checked, the addon will recommend the best seal to use based on the current number of targets.",
    type = "toggle",
    width = "full"
} )
-- Slider option to set number of targets to recommend Seal of Righteousness, default is 4
spec:RegisterSetting("seal_of_righteousness_threshold", 4, {
    name = "Seal of Righteousness Threshold",
    desc = "The number of targets to recommend Seal of Righteousness (recommended: 4). " ..
        "This setting will be disregarded if 'Recommend Seals' is unchecked.",
    type = "range", min = 1, max = 6, step = 1,
    width = "full"
} )

-- Register default pack for MoP Retribution Paladin
spec:RegisterPack( "Retribution", 20260102, [[Hekili:9Q1xVTTnq8plfdWOPRtZw2jTDikpS9sBFOyyQpljAjABUilPrsLudyOp77iLLfjfPKshwrr7sipE3V7V8oQfTk6RrHzioo6l(l9VB5QL(E(R3C367Ic5NQWrHvO0hr7HFOaDe(3)cZPKT1CszHyVt5LOmbpyL10uy)qYX)GI2XBsUDZ7)L3hfUTMKZ)ur0wRYXhKdRcNg9L3Tmk8ajld3skMLgf(1dewtI4VOMKlaPjPCh87Pce0KKtyCy7DL0MKpIFKKt8ayrl3rYbW8tnj)jkhLrk(TMefK3852ZZ8QO40YJBr8Fo4x3MJzmsX(4YDXpc)x2Bj7c2wVBNhJJ4mVSYNlwi)9okLlnnZos2FGFLzhrmoME6LXUQsXAVv4dcowUVoUQ8zmnUDz7h5VRZ2FexWB(S4pxOawNHr5cuXP18d9QO6QTytCKNWX4c8rcMDFhfuH2GlRzfaQJ5hOy2HY8SfTc(vblxibbi6SyXzybapX2qGgNgGeTDTHOhcMcstbKrTQca96l(NYYS8Ag3JIHdF(C7YOIucyFBpKxDvRZe9eUyVWX)mfbwY6QBoFMJO7XCpo5ioMxgNrW3hSz5nQqHu8p1egrxWklknaNppyzk(iIuWUpW)MfVgu6tTW5HG1wfBpfVXF5f2LrEIuGJRQPvLmCRoQHnDv6QJsfg1vQhyFnIMrqfcFtNvspJY9zLiukrmvqohLdh3tDzpCbcYzYwm0kbEHEvuyuuzDndht44JToCOAqXJy(kHqEcrjcw6DzXy2PI0ywEjpy1cBcXweGIhsFdO8r6JbRMby8Nam()pbgzeE8UA6jTvXugMkCCArd0uuHiGIsLvx63b)nCQS(kKUvWXfPyfh4Wnh3n(9PuAAvUOSal(acQbOglPT()7O4s6fdmyhfGWSiMVAEBWTJKu2v4rlxqlIhs7hx4Q8oLwZqzalKmFHkiuzbeJwLJOS4NWqsDQ8ImlaEuqnf)CQYlSVtBnVnA1nKEtrfhzvk1TEgr4VLHtdslHBfaVNNbXDCuaLPO5HLlMIK7dw65)D6fSFhYSSFdovlZOqfeobtxDB8MQudM1jDaBuYJ4r4fdyZ2YIAMxpZaBHnrO1gZlcX2DO8d4(R4TLcPfi013Z8KIHby8WgdITg24Gg1WghKmiSb)TsAkH5OQH(kqdfkUifhIV0nTp)u1brRNS4oU2v4ZMTBCZqhvw1FZnvvCZ9(pKOmR4lBvuSzGhxDVAWSPUMBQQUM7nqDDc8b5SME7nVSBygC1whA3ml4m5jBl2tVeRQ2YMCXUqTOqGZm4m9tbgf(mIwi6nmk8thRkPCiImX3ycpVMphfk)j58Q4DO6Co8JFro)Ah3)9OWuk0tf0(KyUZD2MQPjzrlV7nqnj33KmXOeYJ1oHttYRcAswkxXyaJMeyhXqgrHTWhgUvfbrCqXNhIho9JvK)qW8G(8bQgxeaETbG7oq7usQkWRBsK6GX8snjNp3K0TP5uts45OoDYnTND4GmGpd0GnGx4MUxMyWaCcWVXP1UdpMZy1krxH9TY1xISfsLQVpNwVX6rGSo1Vby0sfXzTALq)6S4k4rOB3oEKKENS9Cr3mly0DFFmY5uEcE(oN8CKb66SPweRClvRxNFOhpQCuaH37iWTBWpvq5EMlzQYQ(OulWYEOTrWKLrfAzTVsm8vObW)dJdF)xa89)XcFFb8xTuG)oq3pGPQojiBLgzxN40KmFvY0hb1KuZcwdc9Cpk6ubG)3nvArSdbIubCx0ASby)bJDnmiHT76r2U1Y3wbuy9BNSIO6TjgtDoOkXLkY6qxTFjjYNOaO9gqnfLa7Jid3fehXaml1tP0GrdCsbBwg0UYzyJx4Yd0DliC57eY9dQzSgtkBKY6V0aJq)3aqNym7EUl6zxvXM6KGHRRdUPjvCrd03UeNt0UP7af7n44oCXFI2eT0RuNugm7W4(jF3Llhrs2EnafRQnGiSY9qXygyjsCx3BkZNvf7LvpAJTGvTxEqY0jkvmcg7g(vYM3PMCyAlmsomtG1toC8ycZi5WXjTLC4Ku1KdZgwMt9FZDKD1BeHP)ygkWBKh1q9o22DKJYO1tYvhIU9ETzsUU928nmMHH28i2SWdPrX0UEIQbwR74U4Y6js5TDLW45AR3OAyVAYnmSMjK6gwZxlzggwZJyZWoKgvd7ePZdF7uRbTtEz4A33(7o3yqJCQA5MrCVtCJ)myPvDWD(9ip4Z1AQx3lsWTWRFP6ilVIt3H2A(f5B)FmakPQDFRFC)b6B)xVV3SUv9tUlREnUnt9J27IlwHT8B)lnFgcW1JwCLlgpIX4vTK2uun)qjnk8JKJyKCPO)9]] )
