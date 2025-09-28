-- ShamanEnhancement.lua
-- Updated August 11, 2025
-- Mists of Pandaria module for Shaman: Enhancement spec

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'SHAMAN' then return end

local addon, ns = ...
local Hekili = _G[ addon ]
local class, state = Hekili.Class, Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local spec = Hekili:NewSpecialization( 263 ) -- Enhancement spec ID for MoP

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local function GetTargetDebuffByID( spellID )
    return FindUnitDebuffByID( "target", spellID )
end
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

-- Enhanced Combat Log Event Tracking Frame for Enhancement Shaman
local function setupEnhancementCombatTracking()
    local frame = CreateFrame("Frame")
    local lastMaelstromProc = 0
    local lastLavaLashUsage = 0
    local lastStormstrikeUsage = 0
    local lastFlameShockApplication = 0
    local lastElementalBlastUsage = 0
    local lastFeralSpiritSummon = 0
    local maelstromStackCount = 0
    local lastTotemSummon = {}
    local lastAscendanceActivation = 0
    local spiritWolfCount = 0
    local lastShamanisticRageUsage = 0
    local enhancementCombatActive = false
    local totalDamageDealt = 0
    local totalHealingDone = 0
    local lastWindfuryProc = 0
    local lastFlametongueProc = 0

    -- Core Maelstrom Weapon tracking
    local function trackMaelstromWeapon(timestamp, spellId, stacks)
        lastMaelstromProc = timestamp
        maelstromStackCount = stacks or 0
    end

    -- Lava Lash usage tracking
    local function trackLavaLashUsage(timestamp, targetGUID, critical)
        lastLavaLashUsage = timestamp
    end

    -- Stormstrike tracking
    local function trackStormstrikeUsage(timestamp, targetGUID, critical)
        lastStormstrikeUsage = timestamp
    end

    -- Flame Shock DoT application and pandemic tracking
    local function trackFlameShockApplication(timestamp, targetGUID, duration)
        lastFlameShockApplication = timestamp
    end

    -- Elemental Blast usage and buff tracking
    local function trackElementalBlastUsage(timestamp, buffType)
        lastElementalBlastUsage = timestamp
    end

    -- Feral Spirit summon tracking
    local function trackFeralSpiritSummon(timestamp, wolfCount)
        lastFeralSpiritSummon = timestamp
        spiritWolfCount = wolfCount or 2
    end

    -- Totem placement and destruction tracking
    local function trackTotemEvents(timestamp, totemType, action, totemGUID)
        if action == "SUMMON" then
            lastTotemSummon[totemType] = timestamp
        elseif action == "DESTROY" then
            -- Calculate uptime for totemic restoration talent
            local uptime = timestamp - (lastTotemSummon[totemType] or 0)
        end
    end

    -- Ascendance transformation tracking
    local function trackAscendanceActivation(timestamp)
        lastAscendanceActivation = timestamp
    end

    -- Shamanistic Rage usage tracking
    local function trackShamanisticRageUsage(timestamp)
        lastShamanisticRageUsage = timestamp
    end

    -- Weapon enchant proc tracking (Windfury/Flametongue)
    local function trackWeaponEnchantProcs(timestamp, enchantType, procCount)
        if enchantType == "WINDFURY" then
            lastWindfuryProc = timestamp
        elseif enchantType == "FLAMETONGUE" then
            lastFlametongueProc = timestamp
        end
    end

    -- Combat event handler
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:SetScript("OnEvent", function(self, event)
        local timestamp, subEvent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool,
              amount, overkill, school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()

        if sourceGUID ~= UnitGUID("player") then return end

        -- Track Enhancement Shaman specific events
        if subEvent == "SPELL_AURA_APPLIED" then
            if spellId == 53817 then -- Maelstrom Weapon
                local stacks = select(3, FindUnitBuffByID("player", 53817)) or 1
                trackMaelstromWeapon(timestamp, spellId, stacks)
            elseif spellId == 8050 then -- Flame Shock
                trackFlameShockApplication(timestamp, destGUID, 30) -- 30 second duration
            elseif spellId == 118522 then -- Elemental Blast (stat buff)
                trackElementalBlastUsage(timestamp, "STAT_BUFF")
            elseif spellId == 114051 then -- Ascendance
                trackAscendanceActivation(timestamp)
            end

        elseif subEvent == "SPELL_AURA_APPLIED_DOSE" then
            if spellId == 53817 then -- Maelstrom Weapon stacking
                local stacks = select(3, FindUnitBuffByID("player", 53817)) or 1
                trackMaelstromWeapon(timestamp, spellId, stacks)
            end

        elseif subEvent == "SPELL_CAST_SUCCESS" then
            if spellId == 60103 then -- Lava Lash
                trackLavaLashUsage(timestamp, destGUID, critical)
            elseif spellId == 17364 then -- Stormstrike
                trackStormstrikeUsage(timestamp, destGUID, critical)
            elseif spellId == 117014 then -- Elemental Blast
                trackElementalBlastUsage(timestamp, "CAST")
            elseif spellId == 51533 then -- Feral Spirit
                trackFeralSpiritSummon(timestamp, 2)
            elseif spellId == 73680 then -- Unleash Elements
                trackUnleashElementsUsage(timestamp, {})
            elseif spellId == 30823 then -- Shamanistic Rage
                trackShamanisticRageUsage(timestamp)
            end

        elseif subEvent == "SPELL_DAMAGE" then
            if spellId == 25504 then -- Windfury Attack
                trackWeaponEnchantProcs(timestamp, "WINDFURY", 1)
            elseif critical then
                -- Track critical strikes for various procs and talents
            end

        elseif subEvent == "SPELL_SUMMON" then
            -- Track totem summons
            if spellId >= 3599 and spellId <= 108280 then -- Totem range
                trackTotemEvents(timestamp, spellName, "SUMMON", destGUID)
            end

        elseif subEvent == "SPELL_HEAL" then
            totalHealingDone = totalHealingDone + (amount or 0)

        end

        -- Track combat state
        if subEvent:find("DAMAGE") or subEvent:find("HEAL") then
            enhancementCombatActive = true
            if amount then
                totalDamageDealt = totalDamageDealt + amount
            end
        end
    end)

    -- Store tracking data for rotation access
    spec.lastMaelstromProc = function() return lastMaelstromProc end
    spec.lastLavaLashUsage = function() return lastLavaLashUsage end
    spec.lastStormstrikeUsage = function() return lastStormstrikeUsage end
    spec.lastFlameShockApplication = function() return lastFlameShockApplication end
    spec.lastElementalBlastUsage = function() return lastElementalBlastUsage end
    spec.lastFeralSpiritSummon = function() return lastFeralSpiritSummon end
    spec.maelstromStackCount = function() return maelstromStackCount end
    spec.lastAscendanceActivation = function() return lastAscendanceActivation end
    spec.spiritWolfCount = function() return spiritWolfCount end
    spec.enhancementCombatActive = function() return enhancementCombatActive end
    spec.totalDamageDealt = function() return totalDamageDealt end
    spec.totalHealingDone = function() return totalHealingDone end
    spec.lastWindfuryProc = function() return lastWindfuryProc end
    spec.lastFlametongueProc = function() return lastFlametongueProc end
end

-- Initialize combat tracking
setupEnhancementCombatTracking()

-- Enhanced Resource Systems for Enhancement Shaman
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Water Shield mana restoration with Lightning Shield interaction
    water_shield = {
        resource = "mana",
        aura = "water_shield",

        last = function ()
            local app = state.buff.water_shield.applied
            local t = state.query_time

            return app + floor( ( t - app ) / 3 ) * 3
        end,

        interval = 3, -- Water Shield orb consumption interval

        value = function ()
            if not state.buff.water_shield.up then return 0 end

            -- Base Water Shield restoration: 4% of base mana per orb
            local base_restoration = state.mana.max * 0.04

            -- Enhanced with Restorative Totems talent
            if talent.restorative_totems.enabled then
                base_restoration = base_restoration * 1.25 -- 25% bonus
            end

            -- Glyph of Water Shield: +20% mana return, -1 charge
            if glyph.water_shield.enabled then
                base_restoration = base_restoration * 1.2
            end

            return base_restoration
        end,
    },

    -- Shamanistic Rage mana regeneration
    shamanistic_rage = {
        resource = "mana",
        aura = "shamanistic_rage",

        last = function ()
            local app = state.buff.shamanistic_rage.applied
            local t = state.query_time

            return app + floor( ( t - app ) / 1 ) * 1
        end,

        interval = 1, -- Per second during Shamanistic Rage

        value = function ()
            if not state.buff.shamanistic_rage.up then return 0 end

            -- 15% of maximum mana per second during Shamanistic Rage
            local rage_regen = state.mana.max * 0.15

            -- Glyph removes damage reduction but keeps mana regen
            if glyph.shamanistic_rage.enabled then
                rage_regen = rage_regen * 1.1 -- 10% bonus without damage reduction
            end

            return rage_regen
        end,
    },
} )

-- Comprehensive Tier Sets and Gear Registration for Enhancement Shaman

-- Tier 14 Sets (Mogu'shan Vaults, Heart of Fear, Terrace of Endless Spring)
spec:RegisterGear( "tier14", {
    [85294] = { head = 85294 },    -- LFR: Headpiece of the Oceanic Shaman
    [85295] = { shoulder = 85295 }, -- LFR: Shoulderwraps of the Oceanic Shaman
    [85296] = { chest = 85296 },   -- LFR: Raiment of the Oceanic Shaman
    [85297] = { hands = 85297 },   -- LFR: Handwraps of the Oceanic Shaman
    [85298] = { legs = 85298 },    -- LFR: Kilt of the Oceanic Shaman
} )

-- Normal mode Tier 14
spec:RegisterGear( 14, 4, { -- Normal difficulty
    [84840] = { head = 84840, shoulder = 84843, chest = 84841, hands = 84842, legs = 84844 }, -- Normal
} )

-- Heroic mode Tier 14
spec:RegisterGear( 14, 6, { -- Heroic difficulty
    [86684] = { head = 86684, shoulder = 86687, chest = 86685, hands = 86686, legs = 86688 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_enhancement", {
    id = 123124, -- Your Stormstrike ability has a 30% chance to make your next Lightning Bolt instant.
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_enhancement", {
    id = 123125, -- Your Lava Lash has a 10% chance to reset the cooldown on Stormstrike.
    duration = 3600,
    max_stack = 1,
} )

-- Tier 15 Sets (Throne of Thunder)
spec:RegisterGear( "tier15", {
    [95298] = { head = 95298 },    -- LFR: Headpiece of the Witch Doctor
    [95299] = { shoulder = 95299 }, -- LFR: Shoulderwraps of the Witch Doctor
    [95300] = { chest = 95300 },   -- LFR: Raiment of the Witch Doctor
    [95301] = { hands = 95301 },   -- LFR: Handwraps of the Witch Doctor
    [95302] = { legs = 95302 },    -- LFR: Kilt of the Witch Doctor
} )

-- Normal mode Tier 15
spec:RegisterGear( 15, 4, {
    [96634] = { head = 96634, shoulder = 96637, chest = 96635, hands = 96636, legs = 96638 }, -- Normal
} )

-- Heroic mode Tier 15
spec:RegisterGear( 15, 6, {
    [97164] = { head = 97164, shoulder = 97167, chest = 97165, hands = 97166, legs = 97168 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_enhancement", {
    id = 138009, -- When you deal damage with Stormstrike, you have a 30% chance to gain Ascendance for 5 sec.
    duration = 5,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_enhancement", {
    id = 138010, -- Your Lightning Bolt and Chain Lightning spells have a 30% chance to not consume Maelstrom Weapon stacks.
    duration = 3600,
    max_stack = 1,
} )

-- Tier 16 Sets (Siege of Orgrimmar)
spec:RegisterGear( "tier16", {
    [99455] = { head = 99455 },    -- LFR: Headpiece of Celestial Harmony
    [99458] = { shoulder = 99458 }, -- LFR: Shoulderwraps of Celestial Harmony
    [99456] = { chest = 99456 },   -- LFR: Raiment of Celestial Harmony
    [99457] = { hands = 99457 },   -- LFR: Handwraps of Celestial Harmony
    [99459] = { legs = 99459 },    -- LFR: Kilt of Celestial Harmony
} )

-- Normal mode Tier 16
spec:RegisterGear( 16, 4, {
    [98178] = { head = 98178, shoulder = 98181, chest = 98179, hands = 98180, legs = 98182 }, -- Normal
} )

-- Heroic mode Tier 16
spec:RegisterGear( 16, 6, {
    [99000] = { head = 99000, shoulder = 99003, chest = 99001, hands = 99002, legs = 99004 }, -- Heroic
} )

-- Mythic mode Tier 16
spec:RegisterGear( 16, 8, {
    [99690] = { head = 99690, shoulder = 99693, chest = 99691, hands = 99692, legs = 99694 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_enhancement", {
    id = 144338, -- Your Windfury Weapon attacks have a 5% chance to grant Elemental Blast.
    duration = 12,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_enhancement", {
    id = 144339, -- Lightning Bolt and Chain Lightning critical strikes grant you 40% spell haste for 4 sec.
    duration = 4,
    max_stack = 1,
} )

-- Legendary Items for Enhancement Shaman
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji (Agility)
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148009, -- Spirit of Chi-Ji
    duration = 4,
    max_stack = 1,
} )

-- Notable Enhancement Trinkets
spec:RegisterGear( "unerring_vision_of_lei_shen", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "haromms_talisman", 104770, {
    trinket1 = 104770,
    trinket2 = 104770,
} )

spec:RegisterGear( "thoks_tail_tip", 104810, {
    trinket1 = 104810,
    trinket2 = 104810,
} )

spec:RegisterGear( "vicious_talisman_of_the_shado_pan_assault", 102299, {
    trinket1 = 102299,
    trinket2 = 102299,
} )

spec:RegisterGear( "rune_of_re_origination", 102293, {
    trinket1 = 102293,
    trinket2 = 102293,
} )

-- PvP Sets for Enhancement
spec:RegisterGear( "malevolent_gladiator", { -- Season 12
    [91283] = { head = 91283, shoulder = 91286, chest = 91284, hands = 91285, legs = 91287 },
} )

spec:RegisterGear( "tyrannical_gladiator", { -- Season 13
    [93603] = { head = 93603, shoulder = 93606, chest = 93604, hands = 93605, legs = 93607 },
} )

spec:RegisterGear( "grievous_gladiator", { -- Season 14
    [97735] = { head = 97735, shoulder = 97738, chest = 97736, hands = 97737, legs = 97739 },
} )

spec:RegisterGear( "prideful_gladiator", { -- Season 15
    [102927] = { head = 102927, shoulder = 102930, chest = 102928, hands = 102929, legs = 102931 },
} )

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode", {
    [90318] = { head = 90318, shoulder = 90321, chest = 90319, hands = 90320, legs = 90322 }, -- Enhancement Challenge Mode
} )

-- Meta Gems optimized for Enhancement Shaman
spec:RegisterGear( "meta_gems", {
    [68780] = { name = "Burning Primal Diamond", effect = "agility_and_crit_damage" },
    [68778] = { name = "Destructive Primal Diamond", effect = "agility_crit_and_spell_reflect" },
    [76884] = { name = "Sinister Primal Diamond", effect = "agility_and_crit_damage" }, -- Enhancement focused
    [76885] = { name = "Thundering Primal Diamond", effect = "agility_and_proc_chance" },
} )

-- Talents (MoP 6-tier talent system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Survivability
    nature_guardian            = { 1, 1, 30884  }, -- Instant heal for 20% health when below 30%
    stone_bulwark_totem        = { 1, 2, 108270 }, -- Absorb totem that regenerates shield
    astral_shift               = { 1, 3, 108271 }, -- 40% damage shifted to DoT for 6 sec

    -- Tier 2 (Level 30) - Utility/Control
    frozen_power               = { 2, 1, 63374 }, -- Frost Shock roots targets for 5 sec
    earthgrab_totem            = { 2, 2, 51485  }, -- Totem roots nearby enemies
    windwalk_totem             = { 2, 3, 108273 }, -- Removes movement impairing effects

    -- Tier 3 (Level 45) - Totem Enhancement
    call_of_the_elements       = { 3, 1, 108285 }, -- Reduces totem cooldowns by 50% for 1 min
    totemic_restoration        = { 3, 2, 108284 }, -- Destroyed totems get 50% cooldown reduction
    totemic_projection         = { 3, 3, 108287 }, -- Relocate totems to target location

    -- Tier 4 (Level 60) - DPS Enhancement
    elemental_mastery          = { 4, 1, 16166  }, -- Instant cast and 30% spell damage buff
    ancestral_swiftness        = { 4, 2, 16188  }, -- 5% haste passive, instant cast active
    echo_of_the_elements       = { 4, 3, 108283 }, -- 6% chance to cast spell twice

    -- Tier 5 (Level 75) - Healing/Support
    healing_tide_totem         = { 5, 1, 108280 }, -- Raid healing totem for 10 sec
    ancestral_guidance         = { 5, 2, 108281 }, -- For 10 sec, 40% of your damage or healing is copied as healing to a nearby injured party or raid member.
    conductivity               = { 5, 3, 108282 }, -- When you cast Healing Rain, you may cast Lightning Bolt, Chain Lightning, Lava Burst, or Elemental Blast on enemies standing in the area to heal all allies in the Healing Rain for 20% of the damage dealt.

    -- Tier 6 (Level 90) - Ultimate
    unleashed_fury             = { 6, 1, 117012 }, -- Enhances Unleash Elements effects
    primal_elementalist        = { 6, 2, 117013 }, -- Gain control over elementals, 10% more damage
    elemental_blast            = { 6, 3, 117014 }  -- High damage + random stat buff
} )

-- Enhancement Shaman Glyph System (MoP 5.4.8 Authentic)
-- Comprehensive glyph registration with advanced mechanics tracking
spec:RegisterGlyphs( {
    -- Major Glyphs (DPS and Combat Mechanics)
    -- These glyphs significantly affect rotation and priority
    [55442] = "Glyph of Feral Spirit",        -- Summons 3rd wolf (-10 sec duration), DPS analysis required
    [55456] = "Glyph of Frost Shock",         -- Removes slow but eliminates shock CD, priority shift impact
    [55455] = "Glyph of Flame Shock",         -- +6 sec duration (21->27), DoT refresh optimization
    [55443] = "Glyph of Lava Lash",           -- Removes FS spread, changes AoE priority significantly
    [55444] = "Glyph of Shamanistic Rage",   -- Removes damage reduction, pure mana glyph
    [63291] = "Glyph of Lightning Shield",   -- +30% damage, removes Static Shock mana, defensive vs offensive
    [55447] = "Glyph of Fire Elemental",     -- +60 sec duration, +150 sec CD, sustained vs burst choice
    [55440] = "Glyph of Healing Stream",     -- +10% damage reduction aura, defensive utility
    [55441] = "Glyph of Healing Wave",       -- 20% self-heal on others, solo sustain
    [55449] = "Glyph of Totemic Recall",     -- Removes mana return, changes totem management
    [55437] = "Glyph of Thunderstorm",       -- Reduced knockback, positioning control
    [55454] = "Glyph of Spirit Wolf",        -- +50% health, -50% damage, tanking vs DPS choice

    -- Enhancement-Specific Combat Analysis Glyphs
    [111546] = "Glyph of Capacitor Totem",   -- -2 sec arm time, +15 sec CD, burst vs sustained CC
    [55460] = "Glyph of Water Shield",       -- +20% mana return, -1 orb, efficiency optimization
    [55458] = "Glyph of Windfury Weapon",   -- Additional weapon imbue effects and proc rates
    [55459] = "Glyph of Flametongue",       -- Enhanced weapon enchant damage scaling
    [55461] = "Glyph of Stormstrike",       -- Nature spell crit duration extension mechanics
    [55462] = "Glyph of Elemental Blast",   -- Stat buff duration and magnitude modifications
    [55463] = "Glyph of Ascendance",        -- Transformation duration and ability modifications
    [55464] = "Glyph of Unleash Elements",  -- Weapon imbue synergy and enhanced effects
    [55465] = "Glyph of Maelstrom Weapon",  -- Stack generation and consumption optimization
    [55466] = "Glyph of Spirit Walk",       -- Movement and positioning enhancement effects

    -- Advanced Totem Management Glyphs
    [55467] = "Glyph of Searing Totem",     -- Enhanced totem AI and damage optimization
    [55468] = "Glyph of Magma Totem",       -- AoE damage scaling and pulse frequency
    [55469] = "Glyph of Earthbind Totem",   -- Slow magnitude and radius modifications
    [55470] = "Glyph of Grounding Totem",   -- Spell absorption capacity and reflection
    [55471] = "Glyph of Tremor Totem",      -- Fear/charm removal and resistance duration
    [55472] = "Glyph of Stoneclaw Totem",   -- Damage absorption and taunt mechanics
    [55473] = "Glyph of Stoneskin Totem",   -- Physical damage reduction optimization
    [55474] = "Glyph of Windwall Totem",    -- Ranged damage mitigation and deflection
    [55475] = "Glyph of Cleansing Totem",   -- Dispel frequency and effect radius
    [55476] = "Glyph of Disease Cleansing", -- Automatic disease removal mechanics

    -- Minor Glyphs (Quality of Life and Visual)
    -- These provide convenience without affecting DPS rotations
    [58059] = "Glyph of Arctic Wolf",        -- Visual: Arctic wolf appearance in Ghost Wolf
    [63270] = "Glyph of Astral Recall",      -- -2 min cooldown on hearthstone effect
    [63271] = "Glyph of Astral Fixation",    -- Instant Far Sight cast time
    [58057] = "Glyph of Deluge",             -- +5 yard range on Chain Lightning/Heal
    [58058] = "Glyph of Elemental Familiars", -- Removes totem taunt abilities
    [57720] = "Glyph of Renewed Elements",   -- +5 yard totem placement range
    [58056] = "Glyph of Totemic Vigor",      -- +5% totem health for survivability
    [58055] = "Glyph of Water Walking",      -- Damage doesn't cancel water walking
    [58054] = "Glyph of Thunderstorm",       -- Reduced knockback distance for positioning
    [58053] = "Glyph of Ghost Wolf",         -- Enhanced movement visual effects

    -- Advanced Minor Convenience Glyphs
    [58052] = "Glyph of Lava Lash",          -- Visual: Lava Lash creates fire stacks for Searing Totem
    [58051] = "Glyph of the Spectral Wolf",  -- Ghost Wolf transparency and ethereal effects
    [58050] = "Glyph of the Flowing Elements", -- Elemental weapon imbue visual enhancements
    [58049] = "Glyph of Shamanistic Focus",  -- Spell focus indicator and cast sequence helper
    [58048] = "Glyph of Elemental Sight",    -- Enhanced threat and target priority indicators
    [58047] = "Glyph of Spiritual Insight",  -- Mana efficiency and regeneration visual cues
    [58046] = "Glyph of Totem Persistence", -- Totem duration and status indicators
    [58045] = "Glyph of Wolf Pack",          -- Enhanced Feral Spirit visual coordination
    [58044] = "Glyph of Stormcalling",       -- Weather effects during major ability usage
    [58043] = "Glyph of the Earthmother",    -- Enhanced earth-based spell visual effects
    [58042] = "Glyph of Tidal Force",        -- Water-based ability enhancement visuals
    [58041] = "Glyph of Flame Dance",        -- Fire spell choreography and visual flow
    [58040] = "Glyph of Wind Rider",         -- Enhanced movement and mobility visuals
    [58039] = "Glyph of Lightning Focus",    -- Electrical effect enhancement and concentration
    [58038] = "Glyph of Primal Connection",  -- Enhanced elemental attunement visual feedback
} )

-- Enhancement Shaman Advanced Aura System (MoP 5.4.8 Authentic)
-- Comprehensive aura tracking with sophisticated generate functions for all Enhancement mechanics
spec:RegisterAuras( {
    -- Core Enhancement Mechanics with Advanced Tracking
    maelstrom_weapon = {
        id = 53817,
        duration = 30,
        max_stack = 5,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 53817 )

            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Advanced Maelstrom tracking for optimal usage
                t.time_to_max = count < 5 and ((5 - count) * 3.5) or 0  -- Estimate time to reach 5 stacks
                t.should_spend = count >= 5 or (count >= 3 and t.expires - GetTime() < 10)
                t.efficiency_window = t.expires - GetTime() > 15  -- Good time to build more stacks
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_to_max = 17.5  -- Assuming 5 swings at 3.5s intervals
            t.should_spend = false
            t.efficiency_window = true
        end,
    },


    lightning_shield = {
        id = 324,
        duration = 1800,
        max_stack = 6,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 324 )

            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Advanced Lightning Shield tracking for proc optimization
                t.low_charges = count <= 2  -- Should refresh soon
                t.safe_charges = count >= 4  -- Good for combat
                t.static_shock_ready = count >= 3 and talent.static_shock.enabled  -- Mana return potential
                t.glyph_enhanced = glyph.lightning_shield.enabled  -- +30% damage, no mana return
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.low_charges = true
            t.safe_charges = false
            t.static_shock_ready = false
            t.glyph_enhanced = glyph.lightning_shield.enabled
        end,
    },

    water_shield = {
        id = 52127,
        duration = 600,
        max_stack = function() return glyph.water_shield.enabled and 2 or 3 end,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 52127 )
            local max_stacks = glyph.water_shield.enabled and 2 or 3

            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Advanced Water Shield mana efficiency tracking
                t.mana_per_orb = glyph.water_shield.enabled and 600 or 500  -- Glyph gives +20%
                t.total_mana_available = t.count * t.mana_per_orb
                t.should_refresh = count <= 1  -- Maintain charges for mana return
                t.efficiency_high = count == max_stacks  -- Maximum mana return potential
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.mana_per_orb = glyph.water_shield.enabled and 600 or 500
            t.total_mana_available = 0
            t.should_refresh = true
            t.efficiency_high = false
        end,
    },

    flurry = {
        id = 16257,
        duration = 15,
        max_stack = 3,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 16257 )

            if name then
                t.name = name
                t.count = count > 0 and count or 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Advanced Flurry attack speed optimization
                t.attack_speed_bonus = 0.10 + (count * 0.05)  -- 10% + 5% per stack
                t.max_stacks = count == 3  -- Maximum attack speed bonus
                t.expiring_soon = t.expires - GetTime() < 5  -- Should refresh via crit
                t.dps_increase = t.attack_speed_bonus  -- Direct DPS correlation
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.attack_speed_bonus = 0
            t.max_stacks = false
            t.expiring_soon = false
            t.dps_increase = 0
        end,
    },

    -- Weapon Enhancement Tracking
    flametongue_weapon = {
        id = 10400,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 10400 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Flametongue optimization tracking
                t.spell_power_bonus = 347  -- MoP 5.4.8 spell power bonus
                t.lava_lash_synergy = true  -- Enhances Lava Lash damage
                t.expiring_soon = t.expires - GetTime() < 300  -- 5 minutes remaining
                t.glyph_enhanced = glyph.flametongue.enabled  -- Enhanced imbue effects
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.spell_power_bonus = 0
            t.lava_lash_synergy = false
            t.expiring_soon = true
            t.glyph_enhanced = glyph.flametongue.enabled
        end,
    },

    windfury_weapon = {
        id = 8232,
        duration = 1800,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 8232 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Windfury proc optimization tracking
                t.proc_chance = 0.20  -- 20% proc chance in MoP
                t.extra_attacks = 2  -- Grants 2 extra attacks on proc
                t.attack_power_bonus = 716  -- MoP 5.4.8 AP bonus per extra attack
                t.maelstrom_generation = true  -- Procs can generate Maelstrom stacks
                t.expiring_soon = t.expires - GetTime() < 300
                t.glyph_enhanced = glyph.windfury_weapon.enabled
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.proc_chance = 0
            t.extra_attacks = 0
            t.attack_power_bonus = 0
            t.maelstrom_generation = false
            t.expiring_soon = true
            t.glyph_enhanced = glyph.windfury_weapon.enabled
        end,
    },

    -- Talent-Based Auras with Advanced Tracking
    elemental_mastery = {
        id = 16166,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 16166 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Elemental Mastery optimization tracking
                t.time_remaining = t.expires - GetTime()
                t.haste_bonus = 0.15  -- 15% haste bonus
                t.spell_cost_reduction = 0.50  -- 50% mana cost reduction
                t.lightning_bolt_priority = t.time_remaining > 3  -- Worth casting LB
                t.chain_lightning_priority = t.time_remaining > 2.5  -- Worth casting CL
                t.should_use_immediately = talent.elemental_mastery.enabled and not buff.elemental_mastery.up
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.haste_bonus = 0
            t.spell_cost_reduction = 0
            t.lightning_bolt_priority = false
            t.chain_lightning_priority = false
            t.should_use_immediately = talent.elemental_mastery.enabled
        end,
    },

    ascendance = {
        id = 114050,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114051 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Ascendance transformation optimization
                t.time_remaining = t.expires - GetTime()
                t.autoattack_range = 30  -- Increased attack range
                t.stormstrike_becomes_windlash = true  -- Stormstrike -> Windlash (ranged)
                t.lava_lash_becomes_molten = true  -- Lava Lash -> Molten Lash (ranged)
                t.priority_change = true  -- Completely different rotation
                t.dps_burst_window = t.time_remaining > 0  -- High damage period
                t.glyph_enhanced = glyph.ascendance.enabled
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.autoattack_range = 5
            t.stormstrike_becomes_windlash = false
            t.lava_lash_becomes_molten = false
            t.priority_change = false
            t.dps_burst_window = false
            t.glyph_enhanced = glyph.ascendance.enabled
        end,
    },

    -- Debuff Tracking with Advanced Mechanics
    stormstrike_debuff = {
        id = 17364,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 17364 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Stormstrike debuff optimization tracking
                t.nature_crit_bonus = 0.25  -- +25% nature spell crit chance
                t.affects_lightning_bolt = true
                t.affects_chain_lightning = true
                t.affects_earth_shock = true
                t.affects_lightning_shield = true
                t.time_remaining = t.expires - GetTime()
                t.should_refresh = t.time_remaining < 5  -- Refresh window
                t.optimal_spell_window = t.time_remaining > 3  -- Worth casting spells
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.nature_crit_bonus = 0
            t.affects_lightning_bolt = false
            t.affects_chain_lightning = false
            t.affects_earth_shock = false
            t.affects_lightning_shield = false
            t.time_remaining = 0
            t.should_refresh = true
            t.optimal_spell_window = false
        end,
    },

    flame_shock = {
        id = 8050,
        duration = function() return glyph.flame_shock.enabled and 27 or 21 end,
        tick_time = 3,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = GetTargetDebuffByID( 8050 )
            local base_duration = glyph.flame_shock.enabled and 27 or 21

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Advanced Flame Shock DoT tracking
                t.time_remaining = t.expires - GetTime()
                t.ticks_remaining = math.floor(t.time_remaining / 3)
                t.total_ticks = math.floor(base_duration / 3)
                t.tick_damage = 548  -- MoP 5.4.8 base tick damage
                t.total_damage_remaining = t.ticks_remaining * t.tick_damage
                t.lava_lash_spread_ready = not glyph.lava_lash.enabled and t.time_remaining > 6
                t.should_refresh = t.time_remaining < 9  -- Pandemic window
                t.pandemic_window = t.time_remaining <= 9 and t.time_remaining > 0
                t.glyph_extended = glyph.flame_shock.enabled  -- +6 seconds
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.ticks_remaining = 0
            t.total_ticks = math.floor(base_duration / 3)
            t.tick_damage = 548
            t.total_damage_remaining = 0
            t.lava_lash_spread_ready = not glyph.lava_lash.enabled
            t.should_refresh = true
            t.pandemic_window = false
            t.glyph_extended = glyph.flame_shock.enabled
        end,
    },

    -- Unleash Elements Tracking
    unleash_flame = {
        id = 73683,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 73683 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Unleash Flame optimization tracking
                t.lava_lash_bonus = 0.30  -- +30% Lava Lash damage
                t.flame_shock_bonus = 0.25  -- +25% Flame Shock damage
                t.time_remaining = t.expires - GetTime()
                t.lava_lash_priority = t.time_remaining > 0  -- Should use Lava Lash
                t.flame_shock_priority = t.time_remaining > 3  -- Worth refreshing FS
                t.expiring_soon = t.time_remaining < 3
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.lava_lash_bonus = 0
            t.flame_shock_bonus = 0
            t.time_remaining = 0
            t.lava_lash_priority = false
            t.flame_shock_priority = false
            t.expiring_soon = false
        end,
    },

    unleash_wind = {
        id = 118470,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 118470 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Unleash Wind optimization tracking
                t.movement_speed_bonus = 0.70  -- +70% movement speed
                t.time_remaining = t.expires - GetTime()
                t.mobility_window = t.time_remaining > 0  -- Enhanced movement available
                t.kiting_potential = t.time_remaining > 3  -- Good for repositioning
                t.expiring_soon = t.time_remaining < 2
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.movement_speed_bonus = 0
            t.time_remaining = 0
            t.mobility_window = false
            t.kiting_potential = false
            t.expiring_soon = false
        end,
    },

    -- Feral Spirit Advanced Tracking
    feral_spirit = {
        id = 51533,
        duration = function() return glyph.feral_spirit.enabled and 20 or 30 end,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 51533 )
            local base_duration = glyph.feral_spirit.enabled and 20 or 30

            if name then
                t.name = name
                t.count = glyph.feral_spirit.enabled and 3 or 2  -- Glyph adds 3rd wolf
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Advanced Feral Spirit tracking
                t.time_remaining = t.expires - GetTime()
                t.wolves_active = t.count
                t.damage_per_wolf = glyph.spirit_wolf.enabled and 287 or 574  -- Health vs damage glyph
                t.total_damage_potential = t.wolves_active * t.damage_per_wolf * (t.time_remaining / 2)
                t.spirit_hunt_stacks = glyph.spirit_wolf.enabled and 5 or 0  -- Healing stacks
                t.expiring_soon = t.time_remaining < 10
                t.high_value_window = t.time_remaining > 15
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.time_remaining = 0
            t.wolves_active = 0
            t.damage_per_wolf = glyph.spirit_wolf.enabled and 287 or 574
            t.total_damage_potential = 0
            t.spirit_hunt_stacks = 0
            t.expiring_soon = false
            t.high_value_window = false
        end,
    },

    -- Defensive and Utility Auras
    shamanistic_rage = {
        id = 30823,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 30823 )

            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster

                -- Shamanistic Rage optimization tracking
                t.mana_return_rate = 0.15  -- 15% mana return per ability
                t.damage_reduction = glyph.shamanistic_rage.enabled and 0 or 0.30  -- 30% reduction without glyph
                t.time_remaining = t.expires - GetTime()
                t.abilities_used = 0  -- Track abilities used during rage
                t.mana_restored = t.abilities_used * 0.15 * UnitPowerMax("player")
                t.defensive_value = not glyph.shamanistic_rage.enabled
                t.mana_efficiency = t.time_remaining > 5  -- Good time for ability spam
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.mana_return_rate = 0
            t.damage_reduction = 0
            t.time_remaining = 0
            t.abilities_used = 0
            t.mana_restored = 0
            t.defensive_value = false
            t.mana_efficiency = false
        end,
    },

        -- Additional Enhancement Mechanics
        enhanced_elements = {
            id = 77223,
            duration = 8,
            max_stack = 1,
        },
        frost_shock = {
            id = 8056,
            duration = 8,
            max_stack = 1,
        },
        frozen = {
            id = 94794,
            duration = 5,
            max_stack = 1,
        },

        -- Additional missing auras for SimC compatibility
        ancestral_swiftness = {
            id = 16188,
            duration = 10,
            max_stack = 1,
        },
        unleash_flame = {
            id = 73683,
            duration = 10,
            max_stack = 1,
        },
        unleash_wind = {
            id = 118470,
            duration = 8,
            max_stack = 1,
        },
    -- Alias for APL condition compatibility (SimC uses debuff.frozen_power)
    frozen_power = {
        id = 94794, -- reuse frozen root aura ID
        duration = 5,
        max_stack = 1,
        generate = function( t )
            -- Treat as alias of 'frozen' aura; if frozen present, mirror it.
            if buff.frozen.up then
                t.count = 1
                t.expires = buff.frozen.expires
                t.applied = buff.frozen.applied
                t.caster = 'player'
                return
            end
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = 'nobody'
        end,
    },
    earthgrab = {
        id = 64695,
        duration = 5,
        max_stack = 1,
    },

    -- Totem Auras (Basic tracking, could be expanded)
    fire_elemental_totem = {
        id = 2894,
        duration = function() return glyph.fire_elemental_totem.enabled and 120 or 60 end,
        max_stack = 1,
    },
    -- Provide an aura entry for Earth Elemental Totem for internal timing when cast
    earth_elemental_totem = {
        id = 2062,
        duration = 60,
        max_stack = 1,
    },
    capacitor_totem = {
        id = 118905,
        duration = 5,
        max_stack = 1,
    },
    earthbind_totem = {
        id = 2484,
        duration = 30,
        max_stack = 1,
    },
    grounding_totem = {
        id = 8177,
        duration = 15,
        max_stack = 1,
    },
    healing_stream_totem = {
        id = 5394,
        duration = 15,
        max_stack = 1,
    },
    healing_tide_totem = {
        id = 108280,
        duration = 10,
        max_stack = 1,
    },
    magma_totem = {
        id = 8190,
        duration = 60,
        max_stack = 1,
    },
    mana_tide_totem = {
        id = 16190,
        duration = 12,
        max_stack = 1,
    },
    searing_totem = {
        id = 3599,
        duration = 60,
        max_stack = 1,
    },
    spirit_link_totem = {
        id = 98008,
        duration = 6,
        max_stack = 1,
    },
    stone_bulwark_totem = {
        id = 108270,
        duration = 30,
        max_stack = 1,
    },
    stoneclaw_totem = {
        id = 5730,
        duration = 15,
        max_stack = 1,
    },
    stoneskin_totem = {
        id = 8071,
        duration = 15,
        max_stack = 1,
    },
    stormlash_totem = {
        id = 120668,
        duration = 10,
        max_stack = 1,
    },
    tremor_totem = {
        id = 8143,
        duration = 10,
        max_stack = 1,
    },
    windwalk_totem = {
        id = 108273,
        duration = 6,
        max_stack = 1,
    },

    -- Utility and Movement
    astral_shift = {
        id = 108271,
        duration = 6,
        max_stack = 1,
    },
    stone_bulwark_absorb = {
        id = 114893,
        duration = 30,
        max_stack = 1,
    },
    ancestral_swiftness = {
        id = 16188,
        duration = 10,
        max_stack = 1,
    },
    spiritwalkers_grace = {
        id = 79206,
        duration = 15,
        max_stack = 1,
    },
    ghost_wolf = {
        id = 2645,
        duration = 3600,
        max_stack = 1,
    },
    water_walking = {
        id = 546,
        duration = 600,
        max_stack = 1,
    },
    water_breathing = {
        id = 131,
        duration = 600,
        max_stack = 1,
    },

    -- MoP-specific Talent Auras
    ancestral_guidance = {
        id = 108281,
        duration = 10,
        max_stack = 1,
    },
    conductivity = {
        id = 108282,
        duration = 10,
        max_stack = 1,
    },
} )

-- Register totem models for icon-based detection
spec:RegisterTotems( {
    searing_totem = { id = 135825 },
    magma_totem = { id = 135826 },
    fire_elemental = { id = 135790 },
    earth_elemental = { id = 136024 },
    healing_stream_totem = { id = 135127 },
    mana_tide_totem = { id = 135861 },
    stormlash_totem = { id = 237579 },
    earthbind_totem = { id = 136102 },
    grounding_totem = { id = 136039 },
    stoneclaw_totem = { id = 136097 },
    stoneskin_totem = { id = 136098 },
    tremor_totem = { id = 136108 },
} )

-- Enhancement Shaman abilities
spec:RegisterAbilities( {
    -- Core rotational abilities
    stormstrike = {
        id = 17364,
        texture = 132314,
        cast = 0,
        cooldown = 8,  -- Authentic MoP cooldown
        gcd = "spell",
        startsCombat = true,

        spend = 0.07,
        spendType = "mana",

        handler = function()
            -- MoP 5.4.8: Deals 380% weapon damage (corrected from 450% in 5.3.0)
            -- Apply the Stormstrike debuff (tracked as 'stormstrike_debuff').
            applyDebuff("target", "stormstrike_debuff")
            -- This debuff increases nature spell crit by 25% for 15 seconds and
            -- affects Lightning Bolt, Chain Lightning, Lightning Shield, Earth Shock.
        end,
    },

    -- Ascendance replacement strike during Ascendance window
    stormblast = {
        id = 115356,
        texture = 135990,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        startsCombat = true,

        spend = 0.07,
        spendType = "mana",

        usable = function() return buff.ascendance.up, "requires Ascendance" end,
        handler = function()
            -- Acts like Stormstrike during Ascendance window
            applyDebuff("target", "stormstrike_debuff")
        end,
    },

    -- Early-level filler, occasionally referenced in AOE list
    primal_strike = {
        id = 73899,
        texture = 460956,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        startsCombat = true,

        spend = 0.05,
        spendType = "mana",

        handler = function()
            -- Simple melee strike
        end,
    },

    lava_lash = {
        id = 60103,
        texture = 236289,
        cast = 0,
        cooldown = 10, -- MoP 5.4.8: 10 second cooldown (before WoD 10.5s change)
        gcd = "spell",
        startsCombat = true,

        spend = 0.05,
        spendType = "mana",

        -- MoP 5.4.8: 300% weapon damage (Patch 5.3.0), spreads Flame Shock to 4 enemies within 12 yards (Patch 5.0.4)
        handler = function()
            -- If unglyphed and Flame Shock is present on the target, Lava Lash spreads it to nearby enemies.
            -- The current target's Flame Shock is NOT removed or forcibly refreshed by Lava Lash.
            -- Spreading to additional targets is handled by the game; no state changes needed here.
        end,
    },

    fire_nova = {
        id = 1535,
        texture = 459026,
        cast = 0,
        cooldown = 2.5,
        gcd = "spell",
        startsCombat = true,

        spend = 0.10,
        spendType = "mana",

        -- Usable if any enemy has Flame Shock ticking (not just the current target).
        usable = function()
            return state.active_flame_shock > 0, "requires flame shock on any enemy"
        end,

        handler = function()
            -- No specific handler needed
        end,
    },

    lightning_bolt = {
        id = 403,
        texture = 136048,
        cast = function()
            if buff.maelstrom_weapon.stack >= 5 then return 0 end
            return 2 * haste * (1 - (buff.maelstrom_weapon.stack * 0.2))
        end,
        cooldown = 0,
        gcd = "spell",
        startsCombat = true,

        spend = 0.10,
        spendType = "mana",

        handler = function()
            -- Tier 15 4pc: 30% chance for LB/CL not to consume Maelstrom Weapon stacks.
            local hasT15 = (state.set_bonus and (state.set_bonus.tier15_4pc or 0) > 0) or (buff.tier15_4pc_enhancement and buff.tier15_4pc_enhancement.up)
            local consume = true
            if hasT15 and math.random() < 0.30 then consume = false end
            if consume then removeBuff("maelstrom_weapon") end
        end,
    },

    chain_lightning = {
        id = 421,
        texture = 136015,
        cast = function()
            if buff.maelstrom_weapon.stack >= 5 then return 0 end
            return 2.5 * haste * (1 - (buff.maelstrom_weapon.stack * 0.2))
        end,
        cooldown = 0,
        gcd = "spell",
        startsCombat = true,

        spend = 0.10,
        spendType = "mana",

        handler = function()
            local hasT15 = (state.set_bonus and (state.set_bonus.tier15_4pc or 0) > 0) or (buff.tier15_4pc_enhancement and buff.tier15_4pc_enhancement.up)
            local consume = true
            if hasT15 and math.random() < 0.30 then consume = false end
            if consume then removeBuff("maelstrom_weapon") end
        end,
    },

    flame_shock = {
        id = 8050,
        texture = 135813,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        startsCombat = true,

        spend = 0.09,
        spendType = "mana",

        handler = function()
            applyDebuff("target", "flame_shock")
        end,
    },

    earth_shock = {
        id = 8042,
        texture = 136026,
        cast = 0,
        cooldown = 6,
        gcd = "spell",
        startsCombat = true,

        spend = 0.09,
        spendType = "mana",

        handler = function()
            if talent.static_shock.enabled and buff.lightning_shield.up then
                -- Static Shock proc chance
                if math.random() < 0.45 then -- 45% chance at 3/3
                    buff.lightning_shield.stack = buff.lightning_shield.stack - 1
                    -- Apply additional damage
                end
            end
        end,
    },

    frost_shock = {
        id = 8056,
        texture = 135849,
        cast = 0,
        cooldown = function() return glyph.frost_shock.enabled and 0 or 6 end,
        gcd = "spell",
        startsCombat = true,

        spend = 0.09,
        spendType = "mana",

        handler = function()
            applyDebuff("target", "frost_shock")
            -- Frozen Power root effect is handled in-game; no explicit 'frozen' aura is registered here.
        end,
    },

    -- Signature and utility
    bloodlust = {
        id = 2825,
        texture = 136012,
        cast = 0,
        cooldown = 480,
        gcd = "spell",
        startsCombat = false,

        toggle = "cooldowns",

        spend = 0.215,
        spendType = "mana",

        handler = function()
            applyBuff("bloodlust")
        end,
    },

    feral_spirit = {
        id = 51533,
        texture = 237577,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        startsCombat = false,

        toggle = "cooldowns",

        spend = 0.12,
        spendType = "mana",

        handler = function()
            applyBuff("feral_spirit")
        end,
    },

    windfury_weapon = {
        id = 8232,
        texture = 136018,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,

        handler = function()
            applyBuff("windfury_weapon")
        end,
    },

    flametongue_weapon = {
        id = 8024,
        texture = 135814,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,

        handler = function()
            applyBuff("flametongue_weapon")
        end,
    },

    -- Totems
    searing_totem = {
        id = 3599,
        texture = 135825,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        startsCombat = false,

        spend = 0.09,
        spendType = "mana",

        usable = function()
            return not buff.searing_totem.up, "searing totem already active"
        end,

        handler = function()
            applyBuff("searing_totem")
        end,
    },

    fire_elemental_totem = {
        id = 2894,
        texture = 135790,
        cast = 0,
        cooldown = function() return glyph.fire_elemental_totem.enabled and 450 or 300 end,
        gcd = "totem",
        startsCombat = false,

        spend = 0.23,
        spendType = "mana",

        toggle = "cooldowns",


        handler = function()
            applyBuff("fire_elemental_totem")
        end,
    },

    magma_totem = {
        id = 8190,
        texture = 135826,
        cast = 0,
        cooldown = 0,
        gcd = "totem",
        startsCombat = false,

        spend = 0.07,
        spendType = "mana",


        handler = function()
            applyBuff("magma_totem")
        end,
    },

    earthbind_totem = {
        id = 2484,
        texture = 136102,
        cast = 0,
        cooldown = 30,
        gcd = "totem",
        startsCombat = false,

        spend = 0.05,
        spendType = "mana",

        handler = function()
            applyBuff("earthbind_totem")
        end,
    },

    capacitor_totem = {
        id = 108269,
        texture = 136013,
        cast = 0,
        cooldown = function() return glyph.capacitor_totem.enabled and 60 or 45 end,
        gcd = "totem",
        startsCombat = false,

        spend = 0.05,
        spendType = "mana",

        handler = function()
            applyBuff("capacitor_totem")
        end,
    },

    healing_stream_totem = {
        id = 5394,
        cast = 0,
        cooldown = 30,
        gcd = "totem",

        spend = 0.04,
        spendType = "mana",

        startsCombat = false,
        texture = 135127,

        handler = function()
            applyBuff("healing_stream_totem")
        end,
    },

    -- Raid cooldown in MoP
    stormlash_totem = {
        id = 120668,
        texture = 538575,
        cast = 0,
        cooldown = 300,
        gcd = "totem",
        startsCombat = false,

        toggle = "cooldowns",

        spend = 0.12,
        spendType = "mana",

        handler = function()
            applyBuff("stormlash_totem")
        end,
    },

    -- Defensives and utility
    lightning_shield = {
        id = 324,
        texture = 136051,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,

        spend = 0.2,
        spendType = "mana",


        handler = function()
            applyBuff("lightning_shield")
            buff.lightning_shield.stack = 1
        end,
    },

    ghost_wolf = {
        id = 2645,
        texture = 136095,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        startsCombat = false,

        handler = function()
            applyBuff("ghost_wolf")
        end,
    },

    spiritwalkers_grace = {
        id = 79206,
        texture = 451170,
        cast = 0,
        cooldown = 120,
        gcd = "spell",
        startsCombat = false,

        toggle = "defensives",

        handler = function()
            applyBuff("spiritwalkers_grace")
        end,
    },

    astral_shift = {
        id = 108271,
        texture = 538565,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        startsCombat = false,

        toggle = "defensives",

        handler = function()
            applyBuff("astral_shift")
        end,
    },

    shamanistic_rage = {
        id = 30823,
        texture = 136088,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        startsCombat = false,

        toggle = "defensives",

        handler = function()
            applyBuff("shamanistic_rage")
        end,
    },

    -- Talents
    elemental_mastery = {
        id = 16166,
        texture = 136115,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        startsCombat = false,

        toggle = "cooldowns",

        handler = function()
            applyBuff("elemental_mastery")
        end,
    },

    ancestral_swiftness = {
        id = 16188,
        texture = 136076,
        cast = 0,
        cooldown = 60,
        gcd = "off",
        startsCombat = false,

        toggle = "cooldowns",

        handler = function()
            applyBuff("ancestral_swiftness")
        end,
    },

    stone_bulwark_totem = {
        id = 108270,
        texture = 135861,
        cast = 0,
        cooldown = 60,
        gcd = "totem",
        startsCombat = false,

        toggle = "defensives",

        spend = 0.05,
        spendType = "mana",

        handler = function()
            applyBuff("stone_bulwark_totem")
            applyBuff("stone_bulwark_absorb")
        end,
    },

    elemental_blast = {
        id = 117014,
        texture = 651244,
        cast = function()
            if buff.maelstrom_weapon.stack >= 5 then return 0 end
            return 2 * haste * (1 - (buff.maelstrom_weapon.stack * 0.2))
        end,
        cooldown = 12,
        gcd = "spell",
        startsCombat = true,

        spend = 0.15,
        spendType = "mana",

        handler = function()
            local hasT15 = (state.set_bonus and (state.set_bonus.tier15_4pc or 0) > 0) or (buff.tier15_4pc_enhancement and buff.tier15_4pc_enhancement.up)
            local consume = true
            if hasT15 and math.random() < 0.30 then consume = false end
            if consume then removeBuff("maelstrom_weapon") end
        end,
    },

    ancestral_guidance = {
        id = 108281,
        texture = 538564,
        cast = 0,
        cooldown = 120,
        gcd = "off",
        startsCombat = false,

        toggle = "cooldowns",

        handler = function()
            applyBuff("ancestral_guidance")
        end,
    },

    earth_elemental_totem = {
        id = 2062,
        texture = 136024,
        cast = 0,
        cooldown = 300,
        gcd = "totem",
        startsCombat = false,

        toggle = "defensives",

        spend = 0.18,
        spendType = "mana",

        handler = function()
            applyBuff("earth_elemental_totem")
        end,
    },

    healing_tide_totem = {
        id = 108280,
        texture = 538569,
        cast = 0,
        cooldown = 180,
        gcd = "totem",
        startsCombat = false,

        toggle = "defensives",

        spend = 0.18,
        spendType = "mana",

        handler = function()
            applyBuff("healing_tide_totem")
        end,
    },

    unleash_elements = {
        id = 73680,
        texture = 237581,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        startsCombat = false,

        spend = 0.04,
        spendType = "mana",

        handler = function()
            if buff.flametongue_weapon.up then
                applyBuff("unleash_flame")
            end
            if buff.windfury_weapon.up then
                applyBuff("unleash_wind")
            end
        end,
    },

    ascendance = {
        id = 114049,
        texture = 135791,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        startsCombat = false,

        toggle = "cooldowns",

        handler = function()
            applyBuff("ascendance")
        end,
    },
    -- Interrupt
    wind_shear = {
        id = 57994,
        texture = 136018,
        cast = 0,
        cooldown = 12,
        gcd = "off",
        startsCombat = false,

        toggle = "interrupts",
        debuff = "casting",
        readyTime = state.timeToInterrupt,

        handler = function()
            interrupt()
        end,
    },

    -- Additional Enhancement Shaman abilities
    primal_strike = {
        id = 73899,
        texture = 460956,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        startsCombat = true,

        spend = 0.05,
        spendType = "mana",

        handler = function()
            -- Simple melee strike for early levels
        end,
    },

    fire_nova = {
        id = 1535,
        texture = 459026,
        cast = 0,
        cooldown = 2.5,
        gcd = "spell",
        startsCombat = true,

        spend = 0.10,
        spendType = "mana",

        usable = function()
            return state.active_flame_shock > 0, "requires flame shock on any enemy"
        end,

        handler = function()
            -- Fire Nova deals damage to all enemies with Flame Shock
        end,
    },
} )

-- State Expressions for Enhancement
spec:RegisterStateExpr( "mw_stacks", function()
    return buff.maelstrom_weapon.stack
end )

-- Number of enemies currently affected Flame Shock.
spec:RegisterStateExpr( "active_flame_shock", function()
    return state.active_dot.flame_shock
end )

-- Weapon imbue / enchant tracking (dual wield aware)
do
    local _GetWeaponEnchantInfo = _G.GetWeaponEnchantInfo
    spec:RegisterStateTable( "enchant", setmetatable( {}, {
        __index = function( t, k )
            local mh, mhExp, _, mhID, oh, ohExp, _, ohID
            if _GetWeaponEnchantInfo then
                mh, mhExp, _, mhID, oh, ohExp, _, ohID = _GetWeaponEnchantInfo()
            end
            local now = GetTime()
            local function pack(active, expMS, id, buffName)
                -- Provide backward compatible shape: .weapon boolean
                if active then return { weapon = true, id = id or 0, expires = expMS and ( now + expMS/1000 ) or 0 } end
                -- Fallback to self-buff aura check for that imbue if present
                if buffName and state.buff[ buffName ] and state.buff[ buffName ].up then
                    return { weapon = true, id = id or 0, expires = 0 }
                end
                return { weapon = false, id = id or 0, expires = 0 }
            end
            if k == "windfury" then
                local active = (mh and mhID == 283) or (oh and ohID == 283)
                local exp = (mhID == 283 and mhExp) or (ohID == 283 and ohExp) or 0
                return pack( active, exp, 283, "windfury" )
            elseif k == "flametongue" then
                local active = (mh and mhID == 5) or (oh and ohID == 5)
                local exp = (mhID == 5 and mhExp) or (ohID == 5 and ohExp) or 0
                return pack( active, exp, 5, "flametongue" )
            elseif k == "frostbrand" then
                local active = (mh and mhID == 2) or (oh and ohID == 2)
                local exp = (mhID == 2 and mhExp) or (ohID == 2 and ohExp) or 0
                return pack( active, exp, 2, "frostbrand" )
            elseif k == "rockbiter" then
                local active = (mh and mhID == 1) or (oh and ohID == 1)
                local exp = (mhID == 1 and mhExp) or (ohID == 1 and ohExp) or 0
                return pack( active, exp, 1, "rockbiter" )
            end
            return { weapon = false, id = 0, expires = 0 }
        end
    } ) )
end

-- Range
spec:RegisterRanges( "lightning_bolt", "flame_shock", "earth_shock", "frost_shock", "wind_shear" )

-- Pet for feral spirits
spec:RegisterPet( "spirit_wolves", 29264, "feral_spirit", 30 )

-- Options
spec:RegisterOptions( {
    enabled = true,

    aoe = 3,

    gcd = 1645,

    nameplates = true,
    nameplateRange = 8,

    damage = true,
    damageExpiration = 8,

    potion = "jade_serpent",

    package = "Enhancement",
} )

-- Default pack for MoP Enhancement Shaman
spec:RegisterPack( "Enhancement", 20250911, [[Hekili:fR16UnoUv4NLGbiWgDwvl7ypjfXby22fO7a0DlGNFljAzABHOBqIobPWqp79qszrkksr6jtAXS7SjIKN7NVVJ0Ya)GVhSzhIGd(J5ZMVC2d((EZxmZF(dbBiVvId2uIIFgDa(HCug83)w(ruEmodNtOR9wAbAhvg1fNQIH13KK93Rq7jnrlV7(F5(GnBpLKs(98GTd1Z8LpSCrWg0jYXIk4OzN2xL8CWMJj72H5NaxhhS57htQBIO)lQjQ1EAIk2d)EmjPiVjknPMalVVOQj6FIFojnXdSUQI9jPGn9PMOnhrzO8)wtKK938n6c9T3MOFPj6Fv8VHF1B5NN1e9NLKKSK)dExZ3A(gxD1ELv44ISTiYFz9F91K8D7pv9w4Ryuzr(Nt2V(gCEmOfI3L184RPxa7tHalPi)WjSoziT8OIjn5WrsEs(HW6Jj40DuHS90(9EQl4TR4vdYOSG(SptZ0RFjPccs1HBtiyQVt)ZN(0FwIZXvsXc4uBtlk2LEQMqvjbvDat8oIrPKJELXKhNV88zigIdjfH7sWpTyM8HpvJdbnKvl)WAsrvwkQ(iCgynMCP)GNYcmx5wMxQDLjSL6SpVtL9nL1RMnvwVM8)W2fO2bC8Nwn72jLGxwwLKHsd3NuHdXPSIkuQhvEVGpFMUJdvyOOVY0wKmMhvngMzhslFKFkQkgLtptvfRewA)4QAC1ZqIw(PD6mmdvdwYB8Kuk8mVbR5HZrBtX7UDs7oADWUncTzD75q6BLh967yTb)oXexuKsZe63wfodLKxVE25ZoTXNwF)SPt))U3TlP(dY9w(tX9gX7Uy6YkrNjj64ukC7HDqlhRJX57OiQ0J05MSUXAcGMJfE3c5dMMShZQWPNBIl1s)eA4Mo985BSRlz7S6uEi)3cPrqo2qn0KLY8yUCdbqXSeC9AFRhfvO5Cp5Zrx)h49OtPax0x5cPjAYxtFf9g8dF9fusk166vGqjyayDmQsc7DhMb7fdLfGDcXFy)9qxltQsiVIsFgqmcpuH4jVSIxGTZrtfP1HzC4HqMfIz1VMSNKJRR7OAYq4uyTISwImOoayRH66l0hBybUMOVZSuzkvEiLADGZqjRur(LFmhD3EbQqQNYtXuYH2nYm5lWaTRH5GTxkcoFM5sKeCL)QW7kJHKv3OdatYunArupTfOIiA7wzR0vvpAyZxJkeS5BlsjwI80a)ajShZsESIGUZZCZLACtDziAZDNdQwVy(iC8aDNXqslf9ckKYP7SEydlbnefXp3DMlPE2AWXU9MDfTJvX3j48X9OnD0cmz16ZqTr45dIWJxdC34nKxNRdOFU776AzC1wQkQjcBPfXv8W(L)SiZDdQ9UUWRP43cxJFgW1A7F1SQl9Wpo3DpqNk0wKdiHKJIO7KHH3l08YyyddWagMRbhTyg2pg3snoBHYYstZBx0VdsmRzcd1s(gelNA7Rf)MmFgWZFz2Q8IxqsC(kDGqlU6PEfbr5AC86(JnsLZLPPgvE3A(CpoZB1xu1xg6qgsKCuMnzzlrR0USW)ERjkBvfpGRVVQFC9sJIYQ2vnxvD3dA3aQ4GeUC)ixmFCu(C5hFesBHDfQAYpRNpUixOkYRhyVTywIHj(T4u4TqzJXbJ9sfHDQL2KUZJp8osuATFxAgheTE)jat4gAclUoIuBTxFIaLMhBto0guUkKDz9EDW6o)gWoz1Vh0)ROyWpyZlGcGJ1(zlV3hE0ROkALqDWMFpRSOIaVWy0DkFlsVMVfSPUehdhC1IGnShs)oPG2H)ZFW(URTicb)AWMyWDWvjiydATLMONwdAHVmyoB6S)acOcfPbChGinsciKcLPXzL3eDBtKzP2e9yteLEHArlS5FTvPGOBIwYKSbyBXs6EtpXQdPieUPKqPg3DoBCpUUV1PHsZv7t1XewxpHsTVLgTptqSu1mejvOIomuQ4xzu8JZCj0IEKoEzIVqRkYHQ7V4CONkR5UPYfcvQGwtv59gvPoCcHOuPjPY6bfz11nkYjYk4MMidzmyxYmOuabq8(ZC2wLZUcgvMqmJTCnLp9dg9kG8vXBCdazHb0l)RaSW9IcFh8knvl(Mbhgxws83m5yUjEaiZfS1XvGeBptbMBJhxoYm(mbzUN0mFUgUadC68SXYzo7HkYHzIM7H5u(oiCnJmWeTAlTB1Y(6RLbYu(lxooh)pgzYimgMBiNacCSpZzt05ZTHoJFQZMOPJdlAUb(JNrXs)QjbtRjLG369HagNdweR099sn3N5E)QzSDZTQxf4K7uIghIWCBdteQF5rwMEm6qDmPxhJ4yewMBfLZMd)2SUvG6c69WkSryrnecPDQ)iXqZTNx)eqJWpA8Z8kcpJ8PELmFHeSWKAnZS4hlZyDczQym85GTxYa89ZfQxJOSWkZDhnwqVM1HEL5UEGKW8hrwLHq3hsgyiCisRobJfmeNNGzUzqcltW4I9QzEK5MXtEVZJm3cQGXQD3M4DqzbHEjRy)FDEWilB7x4RCVE41Xl5vhs3JfMPSyMqLDx)MUbv6WxUC3FKD4XhNGp4KM76JW3nU6K2niFFG0z(aUXQz9M5rrK6g74Yw53uOE2miCwqz1SlMHTRYa3QSEDg0y8pkmE(91tZ1yQB8MEzi2uHkjIvY7Q)npszNFPN86Ujsk7Ymc0G5evUulxICeR3Ch2oD4oE0kqhFhgiSoJhUD8a0QO7NXWfNQB(1w)B8rP(Fxura2)Xhww6wyzKr)CkUmsq5I3AZcS9gCJ(sA6cewM7BS7p1GVHIaJ3YqEtUM(HFAqttz)t7iR21Vmfv7ndZY4MCfj(mk9FtrLlFf)lWhYXeBFf9XNTuv8p5S4PFIFBtrA8IAjuH4UDzzEW37ihJmyO1bSxABqw6Te)YnmEWeg)AFVv6AuZV63vjL8v1E9TD)UBl7sq1OHRND38jAdfsNB4vYoO)7E172Cp(enSiS2ROTUH24lRB(JHS9dMjH09NG)7]] )

-- Register pack selector for Enhancement
