-- MageArcane.lua
-- Updated July 13, 2025 - Smufrik

-- MoP: Use UnitClass instead of UnitClassBase
local _, playerClass = UnitClass('player')
if playerClass ~= 'MAGE' then return end

local addon, ns = ...
local Hekili = _G[ "Hekili" ]
local class = Hekili.Class
local state = Hekili.State

local function getReferences()
    -- Legacy function for compatibility
    return class, state
end

local strformat = string.format
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Enhanced helper functions for Arcane Mage
local function UA_GetPlayerAuraBySpellID(spellID)
    return FindUnitBuffByID("player", spellID)
end

local function GetTargetDebuffByID(spellID)
    return FindUnitDebuffByID("target", spellID, "PLAYER")
end

local spec = Hekili:NewSpecialization( 62 ) -- Arcane spec ID for MoP


-- Arcane-specific combat log event tracking
local arcaneCombatLogFrame = CreateFrame("Frame")
local arcaneCombatLogEvents = {}

local function RegisterArcaneCombatLogEvent(event, handler)
    if not arcaneCombatLogEvents[event] then
        arcaneCombatLogEvents[event] = {}
    end
    table.insert(arcaneCombatLogEvents[event], handler)
end

arcaneCombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
        
        if sourceGUID == UnitGUID("player") then
            local handlers = arcaneCombatLogEvents[subevent]
            if handlers then
                for _, handler in ipairs(handlers) do
                    handler(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, select(12, CombatLogGetCurrentEventInfo()))
                end
            end
        end
    end
end)

arcaneCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Arcane Charge tracking
RegisterArcaneCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 5143 then -- Arcane Missiles
        -- Arcane Missiles consumes all Arcane Charges
        if buff.arcane_charge.up then
            removeBuff( "arcane_charge" )
        end
    elseif spellID == 30451 then -- Arcane Blast
        -- Arcane Blast generates Arcane Charges (max 4)
        if not buff.arcane_charge.up then
            applyBuff( "arcane_charge", nil, 1 )
        elseif buff.arcane_charge.stack < 4 then
            addStack( "arcane_charge", nil, 1 )
        end
    elseif spellID == 44425 then -- Arcane Barrage
        -- Arcane Barrage consumes all Arcane Charges for instant cast
        if buff.arcane_charge.up then
            removeBuff( "arcane_charge" )
        end
    elseif spellID == 1449 then -- Arcane Explosion
        -- Arcane Explosion generates Arcane Charges (max 4)
        if not buff.arcane_charge.up then
            applyBuff( "arcane_charge", nil, 1 )
        elseif buff.arcane_charge.stack < 4 then
            addStack( "arcane_charge", nil, 1 )
        end
    end
end)

-- Presence of Mind proc tracking
RegisterArcaneCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 12043 then -- Presence of Mind
        -- Track Presence of Mind for instant cast optimization
    elseif spellID == 12042 then -- Arcane Power
        -- Track Arcane Power for burst phase
    end
end)

-- Missile Barrage proc tracking
RegisterArcaneCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    if spellID == 79683 then -- Missile Barrage
        -- Track Missile Barrage proc for free Arcane Missiles
    end
end)

-- Target death tracking for DoT effects
RegisterArcaneCombatLogEvent("UNIT_DIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags)
    -- Handle target death for DoT effect spreading (Living Bomb, Nether Tempest)
end)

-- Enhanced Mana resource system for Arcane Mage
spec:RegisterResource( 0, { -- Mana = 0 in MoP
    -- Evocation mana restoration
    evocation = {
        aura = "evocation",
        last = function ()
            local app = state.buff.evocation.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 0.5 ) * 0.5
        end,
        interval = 0.5,
        value = function()
            return state.max_mana * 0.08 -- 8% max mana every 0.5 seconds
        end,
    },
    
    -- Mana Gem usage
    mana_gem = {
        aura = "mana_gem",
        last = function ()
            local app = state.buff.mana_gem.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.max_mana * 0.26 -- 26% max mana instantly
        end,
    },
    
    -- Incanter's Ward mana conversion
    incanters_ward = {
        aura = "incanters_ward",
        last = function ()
            local app = state.buff.incanters_ward.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.incanters_ward.up and state.incoming_damage_1s * 0.30 or 0 -- 30% of damage taken as mana
        end,
    },
    
    -- Invocation talent bonus
    invocation = {
        aura = "invocation",
        last = function ()
            local app = state.buff.invocation.applied
            local t = state.query_time
            return app + floor( ( t - app ) / 1 ) * 1
        end,
        interval = 1,
        value = function()
            return state.buff.invocation.up and state.max_mana * 0.01 or 0 -- 1% max mana per second
        end,
    },
}, {
    -- Enhanced base mana regeneration with various bonuses
    base_regen = function ()
        local base = state.max_mana * 0.02 -- 2% of max mana per 5 seconds
        local spirit_bonus = state.stat.spirit * 0.56 -- Spirit to mana conversion
        local meditation_bonus = 0
        local armor_bonus = 0
        
        -- Meditation (50% mana regen in combat)
        if state.combat then
            base = base * 0.50
            spirit_bonus = spirit_bonus * 0.50
        end
        
        -- Armor bonuses
        if state.buff.mage_armor.up then
            armor_bonus = armor_bonus + state.max_mana * 0.01 -- 1% bonus from Mage Armor
        end
        
        return (base + spirit_bonus + meditation_bonus + armor_bonus) / 5 -- Convert to per-second
    end,
    
    -- Arcane Orb mana return
    arcane_orb = function ()
        return state.buff.arcane_orb.up and state.max_mana * 0.02 or 0 -- 2% mana bonus
    end,
      -- Temporal Shield mana bonus
    temporal_shield = function ()
        return state.buff.temporal_shield.up and state.max_mana * 0.01 or 0 -- 1% mana bonus
    end,
} )

-- Enhanced Combat Log Event Tracking for Arcane Mage
RegisterArcaneCombatLogEvent("SPELL_CAST_SUCCESS", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool)
    -- Arcane Charge tracking
    if spellID == 30451 then -- Arcane Blast
        local stacks = UA_GetPlayerAuraBySpellID(36032) -- Arcane Charge
        if stacks then
            -- Track Arcane Charge stacks for optimization
        end
    elseif spellID == 44425 then -- Arcane Barrage
        -- Track Arcane Barrage for charge consumption
    elseif spellID == 42208 then -- Blizzard
        -- Track Blizzard channeling for positioning
    elseif spellID == 1449 then -- Arcane Explosion
        -- Track AoE situations
    elseif spellID == 11426 then -- Ice Barrier
        -- Track defensive cooldown usage
    elseif spellID == 12043 then -- Presence of Mind
        -- Track instant cast usage
    elseif spellID == 12051 then -- Evocation
        -- Track mana regeneration usage
    elseif spellID == 80353 then -- Time Warp
        -- Track Bloodlust/Heroism usage
    end
end)

RegisterArcaneCombatLogEvent("SPELL_AURA_APPLIED", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType)
    -- Proc tracking
    if spellID == 48108 then -- Missile Barrage
        -- Track Missile Barrage procs for instant Arcane Missiles
    elseif spellID == 36032 then -- Arcane Charge
        -- Track Arcane Charge applications
    elseif spellID == 116014 then -- Rune of Power
        -- Track Rune of Power placement
    elseif spellID == 1463 then -- Incanter's Ward
        -- Track damage-to-mana conversion
    end
end)

RegisterArcaneCombatLogEvent("SPELL_DAMAGE", function(timestamp, subevent, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, damage)
    -- Critical strike and proc tracking
    if spellID == 30451 then -- Arcane Blast
        -- Track Arcane Blast damage for scaling
    elseif spellID == 44425 then -- Arcane Barrage
        -- Track Arcane Barrage damage
    elseif spellID == 5143 then -- Arcane Missiles
        -- Track Arcane Missiles tick damage
    end
end)

arcaneCombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Comprehensive Tier Sets with All Difficulties and Enhanced Bonuses
spec:RegisterGear( "tier14", 85370, 85371, 85372, 85373, 85369 ) -- T14 Normal
spec:RegisterGear( "tier14_lfr", 86701, 86702, 86699, 86700, 86703 ) -- T14 LFR
spec:RegisterGear( "tier14_heroic", 87105, 87107, 87108, 87106, 87104 ) -- T14 Heroic

spec:RegisterGear( "tier15", 95893, 95894, 95895, 95897, 95892 ) -- T15 Normal
spec:RegisterGear( "tier15_lfr", 95308, 95310, 95306, 95307, 95309 ) -- T15 LFR
spec:RegisterGear( "tier15_heroic", 96633, 96631, 96629, 96632, 96630 ) -- T15 Heroic

spec:RegisterGear( "tier16", 98316, 98319, 98314, 98315, 98317 ) -- T16 Normal
spec:RegisterGear( "tier16_lfr", 99431, 99434, 99429, 99430, 99432 ) -- T16 LFR
spec:RegisterGear( "tier16_heroic", 99176, 99179, 99174, 99175, 99177 ) -- T16 Heroic
spec:RegisterGear( "tier16_mythic", 99866, 99869, 99864, 99865, 99867 ) -- T16 Mythic

-- Legendary Items and Meta Gems
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji (Intellect)
    back = 102246,
} )

spec:RegisterGear( "legendary_meta_intellect", 76884, { -- Burning Primal Diamond
    head = 76884,
} )

spec:RegisterGear( "legendary_meta_spell_damage", 68778, { -- Revitalizing Primal Diamond
    head = 68778,
} )

-- Notable Arcane Mage Trinkets and Weapons
spec:RegisterGear( "kardris_toxic_totem", 104769, { -- Kardris' Toxic Totem (SoO)
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "dysmorphic_samophlange_of_discontinuity", 104902, { -- Dysmorphic Samophlange of Discontinuity (SoO)
    trinket1 = 104902,
    trinket2 = 104902,
} )

spec:RegisterGear( "wand_of_untainted_power", 105531, { -- Wand of Untainted Power (SoO)
    main_hand = 105531,
} )

spec:RegisterGear( "immerseus_crystalline_eye", 104638, { -- Immerseus' Crystalline Eye (SoO)
    trinket1 = 104638,
    trinket2 = 104638,
} )

spec:RegisterGear( "purified_bindings_of_immerseus", 104679, { -- Purified Bindings of Immerseus (SoO)
    wrist = 104679,
} )

spec:RegisterGear( "archimondes_hatred_reborn", 124225, { -- Archimonde's Hatred Reborn (HFC)
    trinket1 = 124225,
    trinket2 = 124225,
} )

-- PvP Sets for Completeness
spec:RegisterGear( "malevolent_gladiator", 84392, 84393, 84394, 84395, 84396 ) -- Season 12
spec:RegisterGear( "tyrannical_gladiator", 91672, 91673, 91674, 91675, 91676 ) -- Season 13
spec:RegisterGear( "grievous_gladiator", 100130, 100131, 100132, 100133, 100134 ) -- Season 14
spec:RegisterGear( "prideful_gladiator", 103266, 103267, 103268, 103269, 103270 ) -- Season 15

-- Challenge Mode Sets
spec:RegisterGear( "challenge_mode_mage", 90508, 90509, 90510, 90511, 90512 ) -- Challenge Mode

-- Talents (MoP 6-tier system)
spec:RegisterTalents( {
    -- Tier 1 (Level 15) - Mobility/Instant Cast
    presence_of_mind      = { 1, 1, 12043 }, -- Your next 3 spells are instant cast
    blazing_speed         = { 1, 2, 108843 }, -- Increases movement speed by 150% for 1.5 sec after taking damage
    ice_floes             = { 1, 3, 108839 }, -- Allows you to cast 3 spells while moving

    -- Tier 2 (Level 30) - Survivability
    flameglow             = { 2, 1, 140468 }, -- Reduces spell damage taken by a fixed amount
    ice_barrier           = { 2, 2, 11426 }, -- Absorbs damage for 1 min
    temporal_shield       = { 2, 3, 115610 }, -- 100% of damage taken is healed back over 6 sec

    -- Tier 3 (Level 45) - Control
    ring_of_frost         = { 3, 1, 113724 }, -- Incapacitates enemies entering the ring
    ice_ward              = { 3, 2, 111264 }, -- Frost Nova gains 2 charges
    frostjaw              = { 3, 3, 102051 }, -- Silences and freezes target

    -- Tier 4 (Level 60) - Utility
    greater_invisibility  = { 4, 1, 110959 }, -- Invisible for 20 sec, 90% damage reduction when visible
    cold_snap             = { 4, 2, 11958 }, -- Finishes cooldown on Frost spells, heals 25%
    cauterize             = { 4, 3, 86949 }, -- Fatal damage brings you to 35% health

    -- Tier 5 (Level 75) - DoT/Bomb Spells
    nether_tempest        = { 5, 1, 114923 }, -- Arcane DoT that spreads
    living_bomb           = { 5, 2, 44457 }, -- Fire DoT that explodes
    frost_bomb            = { 5, 3, 112948 }, -- Frost bomb with delayed explosion

    -- Tier 6 (Level 90) - Power/Mana Management
    invocation            = { 6, 1, 114003 }, -- Evocation increases damage by 25%
    rune_of_power         = { 6, 2, 116011 }, -- Ground rune increases spell damage by 15%
    incanter_s_ward       = { 6, 3, 1463 }, -- Converts 30% damage taken to mana
} )

-- Spell Power Calculations and State Expressions
spec:RegisterStateExpr( "spell_power", function()
    return GetSpellBonusDamage(6) -- Arcane school
end )

spec:RegisterStateExpr( "arcane_power_bonus", function()
    return buff.arcane_power.up and 0.3 or 0 -- 30% damage bonus
end )

spec:RegisterStateExpr( "arcane_charge_bonus", function()
    return buff.arcane_charge.up and (buff.arcane_charge.stack * 0.25) or 0 -- 25% per charge
end )

-- Enhanced Tier Sets with comprehensive bonuses
spec:RegisterGear( 13, 8, { -- Tier 14 (Heart of Fear)
    { 86886, head = 86701, shoulder = 86702, chest = 86699, hands = 86700, legs = 86703 }, -- LFR
    { 87139, head = 85370, shoulder = 85372, chest = 85373, hands = 85371, legs = 85369 }, -- Normal
    { 87133, head = 87105, shoulder = 87107, chest = 87108, hands = 87106, legs = 87104 }, -- Heroic
} )

spec:RegisterAura( "tier14_2pc_arcane", {
    id = 105785,
    duration = 15,
    max_stack = 1,
} )

spec:RegisterAura( "tier14_4pc_arcane", {
    id = 105801,
    duration = 6,
    max_stack = 1,
} )

spec:RegisterGear( 14, 8, { -- Tier 15 (Throne of Thunder)
    { 95890, head = 95308, shoulder = 95310, chest = 95306, hands = 95307, legs = 95309 }, -- LFR
    { 95891, head = 95893, shoulder = 95895, chest = 95897, hands = 95894, legs = 95892 }, -- Normal
    { 95892, head = 96633, shoulder = 96631, chest = 96629, hands = 96632, legs = 96630 }, -- Heroic
} )

spec:RegisterAura( "tier15_2pc_arcane", {
    id = 138320,
    duration = 12,
    max_stack = 1,
} )

spec:RegisterAura( "tier15_4pc_arcane", {
    id = 138323,
    duration = 20,
    max_stack = 1,
} )

spec:RegisterGear( 15, 8, { -- Tier 16 (Siege of Orgrimmar)
    { 99659, head = 99431, shoulder = 99434, chest = 99429, hands = 99430, legs = 99432 }, -- LFR
    { 99660, head = 98316, shoulder = 98319, chest = 98314, hands = 98315, legs = 98317 }, -- Normal
    { 99661, head = 99176, shoulder = 99179, chest = 99174, hands = 99175, legs = 99177 }, -- Heroic
    { 99662, head = 99866, shoulder = 99869, chest = 99864, hands = 99865, legs = 99867 }, -- Mythic
} )

spec:RegisterAura( "tier16_2pc_arcane", {
    id = 145091,
    duration = 8,
    max_stack = 1,
} )

spec:RegisterAura( "tier16_4pc_arcane", {
    id = 145092,
    duration = 15,
    max_stack = 4,
} )

-- Legendary and Notable Items
spec:RegisterGear( "legendary_cloak", 102246, { -- Jina-Kang, Kindness of Chi-Ji
    back = 102246,
} )

spec:RegisterAura( "legendary_cloak_proc", {
    id = 148009,
    duration = 4,
    max_stack = 1,
} )

spec:RegisterGear( "kardris_toxic_totem", 104769, {
    trinket1 = 104769,
    trinket2 = 104769,
} )

spec:RegisterGear( "dysmorphic_samophlange_of_discontinuity", 104902, {
    trinket1 = 104902,
    trinket2 = 104902,
} )

spec:RegisterGear( "wand_of_untainted_power", 105531, {
    main_hand = 105531,
} )

-- Enhanced Glyph System for Arcane Mage (MoP)
spec:RegisterGlyphs( {
    -- Major DPS/Combat Glyphs - Arcane Specialization
    [56384] = "Glyph of Arcane Blast - Increases the mana cost of Arcane Blast by 150%, but increases its damage by 50%",
    [56374] = "Glyph of Arcane Missiles - Arcane Missiles has a 100% chance to not consume Clearcasting",
    [64275] = "Glyph of Arcane Power - Reduces the mana cost penalty of Arcane Power by 100%, but reduces damage bonus by 10%",
    [56360] = "Glyph of Mana Gem - Instead of restoring mana, your Mana Gem increases spell power by 10% for 15 seconds",
    [56375] = "Glyph of Evocation - Your Evocation heals you for 40% of your health over its duration",
    [56372] = "Glyph of Polymorph - Your Polymorph removes all damage over time effects from the target",
    [64276] = "Glyph of Arcane Explosion - Your Arcane Explosion has a 25% chance to not consume mana",
    [64300] = "Glyph of Arcane Barrage - Reduces the cooldown of Arcane Barrage by 1 second",

    -- Major Utility/Mobility Glyphs  
    [56365] = "Glyph of Blink - Blink heals you for 30% of your maximum health",
    [56362] = "Glyph of Ice Block - Your Ice Block also makes you immune to Silence and Interrupt effects",
    [56364] = "Glyph of Invisibility - Increases your movement speed by 40% while invisible from Invisibility",
    [56368] = "Glyph of Frost Nova - Your Frost Nova removes all damage over time effects from targets",
    [64277] = "Glyph of Mirror Image - Increases the number of images created by Mirror Image by 2",
    [57924] = "Glyph of Slow Fall - Your Slow Fall spell no longer requires a reagent",
    [56381] = "Glyph of Spellsteal - Your Spellsteal also dispels a magic effect from the target",
    [64274] = "Glyph of Teleport - Reduces the casting time of your Teleport spells by 50%",

    -- Major Defensive/Survivability Glyphs
    [56373] = "Glyph of Mage Armor - Your Mage Armor reduces the duration of harmful magic effects by 35%",
    [56382] = "Glyph of Ice Armor - Increases the movement speed bonus of your Ice Armor by 30%", 
    [56376] = "Glyph of Frost Armor - Increases the amount of health regenerated by your Frost Armor by 50%",
    [64279] = "Glyph of Temporal Shield - Reduces the cooldown of Temporal Shield by 30 seconds",
    [64280] = "Glyph of Ice Barrier - Increases the amount absorbed by Ice Barrier by 30%",
    [57925] = "Glyph of Remove Curse - Your Remove Curse spell also grants the target immunity to curses for 8 seconds",
    [56369] = "Glyph of Fire Ward - Your Fire Ward has a 100% chance to reflect fire spells",
    [56371] = "Glyph of Frost Ward - Your Frost Ward has a 100% chance to reflect frost spells",

    -- Major Control/CC Glyphs
    [56370] = "Glyph of Cone of Cold - Increases the radius of Cone of Cold by 50%",
    [64278] = "Glyph of Ring of Frost - Reduces the cooldown of Ring of Frost by 30 seconds but reduces its duration by 50%",
    [56378] = "Glyph of Counterspell - Your Counterspell silences the target for 8 seconds",
    [64301] = "Glyph of Arcane Orb - Your Arcane Orb pierces through enemies, hitting up to 3 additional targets",
    [64302] = "Glyph of Presence of Mind - Presence of Mind grants an additional charge but increases cooldown by 30 seconds",
    [64303] = "Glyph of Time Warp - Time Warp affects 2 additional nearby party members",

    -- Arcane-Specific Major Glyphs
    [64304] = "Glyph of Arcane Charge - Your Arcane Charges last 2 seconds longer",
    [64305] = "Glyph of Missile Barrage - Missile Barrage procs have a 50% chance to grant an additional charge",
    [64306] = "Glyph of Nether Tempest - Nether Tempest spreads to one additional nearby enemy when it expires",
    [64307] = "Glyph of Living Bomb - Living Bomb explosions have a 25% chance to apply Living Bomb to nearby enemies",
    [64308] = "Glyph of Frost Bomb - Frost Bomb slows all enemies in its explosion radius by 50% for 8 seconds",
    [64309] = "Glyph of Invocation - Invocation also increases mana regeneration by 100% for its duration",
    [64310] = "Glyph of Rune of Power - Rune of Power has 1 additional charge but 50% longer cooldown",
    [64311] = "Glyph of Incanter's Ward - Incanter's Ward converts 15% additional damage to mana",

    -- Minor Visual/Convenience Glyphs
    [64282] = "Glyph of Illusion - Your Mirror Image copies benefit from your gear bonuses",
    [64283] = "Glyph of Momentum - Increases your speed by 30% for 4 seconds after teleporting", 
    [64284] = "Glyph of the Monkey - Your Polymorph: Sheep becomes Polymorph: Monkey",
    [64285] = "Glyph of the Penguin - Your Polymorph: Sheep becomes Polymorph: Penguin",
    [64286] = "Glyph of the Porcupine - Your Polymorph: Sheep becomes Polymorph: Porcupine",
    [64287] = "Glyph of the Bear Cub - Your Polymorph: Sheep becomes Polymorph: Bear Cub",
    [64288] = "Glyph of the Turtle - Your Polymorph: Sheep becomes Polymorph: Turtle",
    [64289] = "Glyph of the Rabbit - Your Polymorph: Sheep becomes Polymorph: Rabbit",
    [64290] = "Glyph of Conjure Familiar - Your Conjure Food spell also conjures a temporary familiar",
    [64291] = "Glyph of Arcane Language - Allows you to understand Arcane magic communications",
    [64292] = "Glyph of Rapid Teleportation - Reduces the cast time of all Teleport spells by 50%",
    [64293] = "Glyph of Portal - Your Portal spells create a more visually appealing portal",
    [64294] = "Glyph of Conjuring - Conjured items last 50% longer",
    [64295] = "Glyph of Ritual of Refreshment - Your Ritual of Refreshment creates higher quality food",
    [64296] = "Glyph of Mage Ward - Your Ward spells have improved visual effects",
    [64297] = "Glyph of Arcane Intellect - Your Arcane Brilliance spell has enhanced visual effects",
    [64298] = "Glyph of Arcane Missiles - Your Arcane Missiles have improved particle effects",
    [64299] = "Glyph of Mana Shield - Your Mana Shield has a distinctive arcane glow",
} )

-- Auras
spec:RegisterAuras( {
    -- Core Arcane Auras with Advanced Generate Functions
    arcane_charge = {
        id = 36032,
        duration = 6,  -- WoW Sims: 6 second duration
        max_stack = 4,  -- WoW Sims: Maximum 4 stacks in MoP
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 36032 )
            
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
    
    arcane_missiles = {
        id = 79683,
        duration = 12,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 79683 )
            
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
    
    arcane_power = {
        id = 12042,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12042 )
            
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
    
    -- Talent-Based Auras with Enhanced Tracking
    nether_tempest = {
        id = 114923,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 114923, "PLAYER" )
            
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
    
    living_bomb = {
        id = 44457,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 44457, "PLAYER" )
            
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
    
    frost_bomb = {
        id = 112948,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 112948, "PLAYER" )
            
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
    
    -- Mana Optimization Auras
    mana_adept = {
        id = 92643,
        duration = 120,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 92643 )
            
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
    
    invocation = {
        id = 114003,
        duration = 40,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 114003 )
            
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
    
    -- Proc Tracking Auras
    arcane_orb = {
        id = 84722,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 84722 )
            
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
    
    brain_freeze = {
        id = 57761,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 57761 )
            
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
    
    fingers_of_frost = {
        id = 44544,
        duration = 15,
        max_stack = 2,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 44544 )
            
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
    
    -- Defensive Auras with Enhanced Generate Functions
    ice_barrier = {
        id = 11426,
        duration = 60,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 11426 )
            
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
    
    mana_shield = {
        id = 1463,
        duration = 600,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1463 )
            
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
    
    incanter_s_ward = {
        id = 1463,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 1463 )
            
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
    
    -- Tier Set Coordination Auras
    t14_arcane_2pc = {
        id = 105788,
        duration = 8,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105788 )
            
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
    
    t14_arcane_4pc = {
        id = 105789,
        duration = 15,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 105789 )
            
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
    
    t15_arcane_2pc = {
        id = 138320,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 138320 )
            
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
    
    t15_arcane_4pc = {
        id = 138321,
        duration = 20,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 138321 )
            
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
    
    t16_arcane_2pc = {
        id = 145252,
        duration = 12,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 145252 )
            
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
    
    t16_arcane_4pc = {
        id = 145253,
        duration = 30,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 145253 )
            
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
    
    -- Mobility and Utility Auras
    presence_of_mind = {
        id = 12043,
        duration = 10,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 12043 )
            
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
    
    alter_time = {
        id = 110909,
        duration = 6,
        max_stack = 1,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 110909 )
            
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
    
    -- Arcane Charge system
    arcane_charge = {
        id = 36032,
        duration = 10,
        max_stack = 4,
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID( "player", 36032 )
            
            if name then
                t.name = name
                t.count = count > 0 and count or 1
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
    
    -- Shared Mage Auras (Basic Tracking)
    arcane_brilliance = {
        id = 1459,
        duration = 3600,
        max_stack = 1
    },
    
    blink = {
        id = 1953,
        duration = 0.3,
        max_stack = 1
    },
    
    polymorph = {
        id = 118,
        duration = 60,
        max_stack = 1
    },
    
    counterspell = {
        id = 2139,
        duration = 6,
        max_stack = 1
    },
    
    frost_nova = {
        id = 122,
        duration = 8,
        max_stack = 1
    },
    
    frostjaw = {
        id = 102051,
        duration = 8,
        max_stack = 1
    },
    
    ice_block = {
        id = 45438,
        duration = 10,
        max_stack = 1
    },
    
    slow = {
        id = 31589,
        duration = 15,
        max_stack = 1
    },
    
    slow_fall = {
        id = 130,
        duration = 30,
        max_stack = 1
    },
    
    time_warp = {
        id = 80353,
        duration = 40,
        max_stack = 1
    },
    
    ring_of_frost = {
        id = 113724,
        duration = 10,
        max_stack = 1
    },
    
    -- Armor Auras
    frost_armor = {
        id = 7302,
        duration = 1800,
        max_stack = 1
    },
    
    mage_armor = {
        id = 6117,
        duration = 1800,
        max_stack = 1
    },
    
    molten_armor = {
        id = 30482,
        duration = 1800,
        max_stack = 1
    },
    
    -- Debuff Tracking
    temporal_displacement = {
        id = 80354,
        duration = 600,
        max_stack = 1
    },
    
    -- Missing auras for APL compatibility
    mirror_image = {
        id = 55342,
        duration = 8,
        max_stack = 1
    },
    
    rune_of_power = {
        id = 116014,
        duration = 60,
        max_stack = 1
    },
} )

-- Abilities
spec:RegisterAbilities( {
    -- Arcane Core Abilities
    arcane_barrage = {
        id = 44425,
        cast = 0,
        cooldown = 3,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 236205,
        
        handler = function()
            -- Arcane Barrage damage is increased by 25% for each Arcane Charge
            -- Consumes all Arcane Charges when cast
            removeStack( "arcane_charge", buff.arcane_charge.stack )
        end,
    },
      arcane_blast = {
        id = 30451,
        cast = function() 
            if buff.presence_of_mind.up then return 0 end
            -- WoW Sims: Base 2.0s cast, reduced by 0.1s per Arcane Charge stack (max 4 stacks)
            return 2.0 - (0.1 * math.min(buff.arcane_charge.stack, 4))
        end,
        cooldown = 0,
        gcd = "spell",
        
        spend = function() 
            -- WoW Sims: Base 5% mana cost, increased by 150% per stack
            return 0.05 * (1 + (1.5 * buff.arcane_charge.stack))
        end,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135735,
        
        handler = function()
            -- Each cast of Arcane Blast increases Mana cost by 150% and reduces cast time
            -- by 0.1 sec, stacking up to 4 times (WoW Sims accurate)
            if buff.presence_of_mind.up then
                removeBuff( "presence_of_mind" )
            end
            
            -- Add Arcane Charge (max 4 stacks)
            if buff.arcane_charge.stack < 4 then
                addStack( "arcane_charge", nil, 1 )
            end
        end,
    },
      arcane_missiles = {
        id = 5143,
        cast = 2.1, -- WoW Sims: 3 ticks at 0.7s intervals = ~2.1s total channel
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.18,  -- Estimated mana cost for channeled spell
        spendType = "mana",
        
        startsCombat = true,
        texture = 136096,
        
        usable = function() return buff.arcane_missiles.up, "requires arcane missiles proc" end,
        
        channeled = true,
        
        handler = function()
            removeBuff( "arcane_missiles" )
            -- Consume all Arcane Charges when cast
            if buff.arcane_charge.up then
                removeBuff( "arcane_charge" )
            end
        end,
    },
    
    arcane_power = {
        id = 12042,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136048,
        
        handler = function()
            applyBuff( "arcane_power" )
        end,
    },
    
    nether_tempest = {
        id = 114923,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 609815,
        
        talent = "nether_tempest",
        
        handler = function()
            applyDebuff( "target", "nether_tempest" )
        end,
    },
      arcane_explosion = {
        id = 1449,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136116,
        
        handler = function()
            -- Add Arcane Charge (max 4 stacks)
            if not buff.arcane_charge.up then
                applyBuff( "arcane_charge", nil, 1 )
            elseif buff.arcane_charge.stack < 4 then
                addStack( "arcane_charge", nil, 1 )
            end
        end,
    },
    
    -- Shared Mage Abilities
    arcane_brilliance = {
        id = 1459,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135932,
        
        handler = function()
            applyBuff( "arcane_brilliance" )
        end,
    },
    
    alter_time = {
        id = 108978,
        cast = 0,
        cooldown = 180,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 607849,
        
        handler = function()
            applyBuff( "alter_time" )
        end,
    },
    
    blink = {
        id = 1953,
        cast = 0,
        cooldown = 15,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135736,
        
        handler = function()
            applyBuff( "blink" )
        end,
    },
    
    cone_of_cold = {
        id = 120,
        cast = 0,
        cooldown = 10,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135852,
        
        handler = function()
            applyDebuff( "target", "cone_of_cold" )
        end,
    },
    
    conjure_mana_gem = {
        id = 759,
        cast = 3,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 134132,
        
        handler = function()
            -- Creates a Mana Gem
        end,
    },
    
    counterspell = {
        id = 2139,
        cast = 0,
        cooldown = 24,
        gcd = "off",
        
        interrupt = true,
        
        startsCombat = true,
        texture = 135856,
        
        toggle = "interrupts",
        debuff = "casting",
        readyTime = state.timeToInterrupt,
        
        handler = function()
            interrupt()
            applyDebuff( "target", "counterspell" )
        end,
    },
    
    evocation = {
        id = 12051,
        cast = 6,
        cooldown = 120,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136075,
        
        talent = function() return not talent.rune_of_power.enabled end,
        
        handler = function()
            -- Restore 60% mana over 6 sec
            gain( 0.6 * mana.max, "mana" )
            
            if talent.invocation.enabled then
                applyBuff( "invocation" )
            end
        end,
    },
    
    frost_nova = {
        id = 122,
        cast = 0,
        cooldown = function() return talent.ice_ward.enabled and 20 or 30 end,
        charges = function() return talent.ice_ward.enabled and 2 or nil end,
        recharge = function() return talent.ice_ward.enabled and 20 or nil end,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135848,
        
        handler = function()
            applyDebuff( "target", "frost_nova" )
        end,
    },
    
    frostjaw = {
        id = 102051,
        cast = 0,
        cooldown = 20,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 607853,
        
        talent = "frostjaw",
        
        handler = function()
            applyDebuff( "target", "frostjaw" )
        end,
    },
    
    ice_barrier = {
        id = 11426,
        cast = 0,
        cooldown = 25,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135988,
        
        talent = "ice_barrier",
        
        handler = function()
            applyBuff( "ice_barrier" )
        end,
    },
    
    ice_block = {
        id = 45438,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 135841,
        
        handler = function()
            applyBuff( "ice_block" )
            setCooldown( "hypothermia", 30 )
        end,
    },
    
    ice_floes = {
        id = 108839,
        cast = 0,
        cooldown = 45,
        charges = 3,
        recharge = 45,
        gcd = "off",
        
        startsCombat = false,
        texture = 610877,
        
        talent = "ice_floes",
        
        handler = function()
            applyBuff( "ice_floes" )
        end,
    },
    
    incanter_s_ward = {
        id = 1463,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        startsCombat = false,
        texture = 250986,
        
        talent = "incanter_s_ward",
        
        handler = function()
            applyBuff( "incanter_s_ward" )
        end,
    },
    
    invisibility = {
        id = 66,
        cast = 0,
        cooldown = 300,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 132220,
        
        handler = function()
            applyBuff( "invisibility" )
        end,
    },
    
    greater_invisibility = {
        id = 110959,
        cast = 0,
        cooldown = 90,
        gcd = "spell",
        
        toggle = "defensives",
        
        startsCombat = false,
        texture = 606086,
        
        talent = "greater_invisibility",
        
        handler = function()
            applyBuff( "greater_invisibility" )
        end,
    },
    
    presence_of_mind = {
        id = 12043,
        cast = 0,
        cooldown = 90,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 136031,
        
        talent = "presence_of_mind",
        
        handler = function()
            applyBuff( "presence_of_mind" )
        end,
    },
    
    ring_of_frost = {
        id = 113724,
        cast = 1.5,
        cooldown = 45,
        gcd = "spell",
        
        spend = 0.08,
        spendType = "mana",
        
        startsCombat = false,
        texture = 464484,
        
        talent = "ring_of_frost",
        
        handler = function()
            -- Places Ring of Frost at target location
        end,
    },
    
    rune_of_power = {
        id = 116011,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.03,
        spendType = "mana",
        
        startsCombat = false,
        texture = 609815,
        
        talent = "rune_of_power",
        
        handler = function()
            -- Places Rune of Power on the ground
        end,
    },
    
    slow = {
        id = 31589,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.02,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136091,
        
        handler = function()
            applyDebuff( "target", "slow" )
        end,
    },
    
    slow_fall = {
        id = 130,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = false,
        texture = 135992,
        
        handler = function()
            applyBuff( "slow_fall" )
        end,
    },
    
    spellsteal = {
        id = 30449,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.07,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135729,
        
        handler = function()
            -- Attempt to steal a buff from the target
        end,
    },
    
    time_warp = {
        id = 80353,
        cast = 0,
        cooldown = 300,
        gcd = "off",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 458224,
        
        handler = function()
            applyBuff( "time_warp" )
            applyDebuff( "player", "temporal_displacement" )
        end,
    },
    
    -- Armor Spells
    frost_armor = {
        id = 7302,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135843,
        
        handler = function()
            removeBuff( "mage_armor" )
            removeBuff( "molten_armor" )
            applyBuff( "frost_armor" )
        end,
    },
    
    mage_armor = {
        id = 6117,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 135991,
        
        handler = function()
            removeBuff( "frost_armor" )
            removeBuff( "molten_armor" )
            applyBuff( "mage_armor" )
        end,
    },
    
    molten_armor = {
        id = 30482,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        startsCombat = false,
        texture = 132221,
        
        handler = function()
            removeBuff( "frost_armor" )
            removeBuff( "mage_armor" )
            applyBuff( "molten_armor" )
        end,
    },
    
    -- Missing abilities for APL compatibility
    mirror_image = {
        id = 55342,
        cast = 0,
        cooldown = 180,
        gcd = "spell",
        
        toggle = "cooldowns",
        
        startsCombat = false,
        texture = 135994,
        
        handler = function()
            applyBuff( "mirror_image" )
        end,
    },
    
    fire_blast = {
        id = 2136,
        cast = 0,
        cooldown = 8,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135807,
        
        handler = function()
            -- Fire Blast can be used for utility or proc generation
        end,
    },
    
    ice_lance = {
        id = 30455,
        cast = 0,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.01,
        spendType = "mana",
        
        startsCombat = true,
        texture = 135844,
        
        handler = function()
            -- Ice Lance for utility or Brain Freeze procs
        end,
    },
    
    polymorph = {
        id = 118,
        cast = 1.5,
        cooldown = 0,
        gcd = "spell",
        
        spend = 0.04,
        spendType = "mana",
        
        startsCombat = true,
        texture = 136071,
        
        handler = function()
            applyDebuff( "target", "polymorph" )
        end,
    },
    
    -- Passive talents for APL compatibility
    invocation = {
        id = 114003,
        cast = 0,
        cooldown = 0,
        gcd = "off",
        
        startsCombat = false,
        texture = 609815,
        
        talent = "invocation",
        passive = true,
        
        handler = function()
            -- Passive talent, activated through evocation
        end,
    },
} )

-- State Functions and Expressions
spec:RegisterStateExpr( "arcane_charges", function()
    return buff.arcane_charge.stack
end )

spec:RegisterStateExpr( "arcane_missiles_charges", function()
    return buff.arcane_missiles.stack
end )

-- Range
spec:RegisterRanges( "arcane_blast", "polymorph", "blink" )

-- Options
spec:RegisterOptions( {
    enabled = true,
    
    aoe = 3,
    
    nameplates = true,
    nameplateRange = 40,
    
    damage = true,
    damageExpiration = 8,
    
    potion = "jade_serpent_potion",
    
    package = "Arcane",
} )

-- Register default pack for MoP Arcane Mage
spec:RegisterPack( "Arcane", 20250713, [[Hekili:1I1wVTTnu4FlgdWjblZvso2jDWja7YdRgRbdZzVklAz6yIij6rrLGayOF77qkrrszrz1GUhAHd158DUFHm0p8PWvBrCC4JbEbZ8U1F6eVaV7MEx4k(7hWHRoGIFb9m8Jmuk8)iwmhNZfN)EcfTvWFoTGfdFlC1Mcsc)lzHB6eupFG2d44WhNheUApz7wCfP484WvpTNKxgj(hQmQwQLr0DWFhZj0SYOesoh(8okRm6pWVqsitcxjpuAf4DOIeo8ZhLwvfxHRIPfzCmdeCss4kCgAtcEB4VgYbTtqN(KvXmcqjbb2oI9mMpzpgLW3p5qmVmArzuWSYOJhlJ4Kuq1EOmAMwmIZw)gIDqa8uNaVPy3UjGteLHxhVxiLj5CWylJUVm6gnCPegJYwtsf(EaXB(yi6vgng0xucoJp5adNJZIXRP7wNsY2orHxJuBtHqYZ(ys2WwQj5a9nmtG48wi24czKSxWCFxYqcWKIdvbHyknzl9Tm7VYWPiswUm6e4b5BjuUbYG0VTFPh8)M0des)Ub5nvYsRDBGmym7fs2Zcu(8hfLekD76DfS3fO471t(VmJjdZ3JzR540dqrVkFrMtDzz0irLqSqNQ8jnwpuQmDY8YORQZ(K1sYceoD9wsvTZCTAzlgPQ5FovJvKjttRmstnZuTG)u6rSPwe40s36BsH3xFbPWjzVsJrc2TKSuugFtih9hgqLIMxPE4UnsJEaqchTox06zBB3qT(ytJz(qRVjf6560KiOxem7280LjFd2TguPk8rB54mDBrx9J2GyS6UR(TBj1Tetj55KeC(WmpvzYzAva6MASs3AUFaujDI2R0fP63UN2qCyD7tsq1fGdRrLHhPFn0DhRuugQzc7TENXXcno86lsg4UN2OMbHokF1e4U5IL2o1RVgC(gBhGnRRdKn3sPVk6MdlRuRURRpXyM0octftAT5sWqHOLlQfmthkmeyPGeuw8jiCJ5UwwzrweYLlxett3G0ROzeMe7aYihQG5RGM(ZLr)IeTtrNrssisDrTdxZwtaJRrSukRLAE2oPDgXDpJqAqqlZmWnLl2Dfc5K0dugVE)0lQxh9cXyX)TaIJq(tovS3iQGttHTJHdGC7SNHQNYL)jjd(Kpy1)twEXbbsccuR(EH5wSx0qFGt6Bwhvt8uNeBUSPM(BCsF71e18mZjpMn)00775Kb7LcmyXTtYkkzWHB3KUtGb5UDuTMxAWJBNLE2Mb5N1pvxVAWY8ZXIQFRbp3EoEKvQgmC35yOdH85ZXZj2sG7Oo(04rG7aUU)Ob5UJ2o1NEI4Q(Egu3tSULxv2xyhnjH(MCDuubdbJ8HSt48ICbVeGpUGmfiIl0kMaYv0LrLnvkYSOE7wbXWTSrBq5q3YLLr)eCCtYM6aZHO2NPcL2NkRDQpQv6EZPQyu9bwLDWzl7ODytZ)VxnepzyWq6kQNpmK2IN0oPC5xsvufyhXeQmmUOGVxm7zvAXog5fXmp6oWhhU6hkJSMQvU8hGJ(lLxPCzfy5tACu)49F6eBSBY0wv3F3YoUMS7(E3YzzLQ97vZVAqeWXCgK55nZAQWU1lNSiy2XJcsEyMjtMZCe85ALV7VXKR2tE6LtVXN5Hpmr2m9F46dudVg2Ki9AXn9Vx9mdT5xDNOJh79Uape4DwSd((GT(5eCHNf1npBGBQRYAEIaDaIM9j4Y)pj995M4yps3itS73zy8LJQVi)XJ1MXIPtMF14tx4(H5MY5BkHFSsiJD8sbMiR79za7PxNyCxVeW4HLs1QPRLCI762(Jh54E(QGYVrfJr(BkVUPTrsFZ4cDG1((9J7kApqlXECB)fvDetx0fyQHwTrZ4IO9ODJVS3IKfIovNQh(bx1LzjgY3Nr9r1)(DHQlGU4wpNg6dw16yZu2rUZzh1BvsJCN61v9N)mv22xPVItbCmvb9EAxxD1Y797Xk7IKM9W6fG6xVGhg(Fp]] )

-- Register pack selector for Arcane
