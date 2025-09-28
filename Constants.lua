-- Constants.lua
-- july

local addon, ns = ...
local Hekili = _G[ addon ]

-- MoP Classic API Compatibility Laye
-- Handle API changes between Classic/MoP 

-- Function to detect if we're running MoP Classic
local function IsMoP()
    return select(4, GetBuildInfo()) == 50500 or select(4, GetBuildInfo()) == 50400
end

-- Set up specialization APIs with MoP compatibility
if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    GetSpecialization = C_SpecializationInfo.GetSpecialization
else
    GetSpecialization = _G.GetSpecialization
end

if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
    GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo
else
    GetSpecializationInfo = _G.GetSpecializationInfo
end

if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
    GetNumSpecializationsForClassID = C_SpecializationInfo.GetNumSpecializationsForClassID
else
    GetNumSpecializationsForClassID = _G.GetNumSpecializationsForClassID
end

-- MoP Classic specialization mappings
if IsMoP() then
    local specsByClassID = {
        [1] = { 71, 72, 73 },        -- Warrior: Arms, Fury, Protection
        [2] = { 65, 66, 70 },        -- Paladin: Holy, Protection, Retribution
        [3] = { 253, 254, 255 },     -- Hunter: Beast Mastery, Marksmanship, Survival
        [4] = { 259, 260, 261 },     -- Rogue: Assassination, Combat, Subtlety
        [5] = { 256, 257, 258 },     -- Priest: Discipline, Holy, Shadow
        [6] = { 250, 251, 252 },     -- Death Knight: Blood, Frost, Unholy
        [7] = { 262, 263, 264 },     -- Shaman: Elemental, Enhancement, Restoration
        [8] = { 62, 63, 64 },        -- Mage: Arcane, Fire, Frost
        [9] = { 265, 266, 267 },     -- Warlock: Affliction, Demonology, Destruction
        [10] = { 268, 270, 269 },    -- Monk: Brewmaster, Mistweaver, Windwalker
        [11] = { 102, 103, 104, 105 }, -- Druid: Balance, Feral, Guardian, Restoration
    }
    
    GetSpecializationInfoForClassID = function(classID, specIndex)
        local specs = specsByClassID[classID]
        if not specs or not specs[specIndex] then
            return nil
        end
        local specID = specs[specIndex]
        if GetSpecializationInfoByID then
            return GetSpecializationInfoByID(specID)
        end
        return nil
    end
else
    GetSpecializationInfoForClassID = _G.GetSpecializationInfoForClassID
end

-- Store these globally for spec files to use
ns.GetSpecialization = GetSpecialization
ns.GetSpecializationInfo = GetSpecializationInfo
ns.GetSpecializationInfoForClassID = GetSpecializationInfoForClassID
ns.GetNumSpecializationsForClassID = GetNumSpecializationsForClassID

-- Class Localization
ns.getLocalClass = function ( class )
    if not ns.player.sex then ns.player.sex = UnitSex( "player" ) end
    return ns.player.sex == 1 and LOCALIZED_CLASS_NAMES_MALE[ class ] or LOCALIZED_CLASS_NAMES_FEMALE[ class ]
end


local InverseDirection = {
    LEFT = "RIGHT",
    RIGHT = "LEFT",
    TOP = "BOTTOM",
    BOTTOM = "TOP"
}

ns.getInverseDirection = function ( dir )

    return InverseDirection[ dir ] or dir

end


local ClassIDs = {}

local function InitializeClassIDs()
    if GetNumClasses and GetClassInfo then
        for i = 1, GetNumClasses() do
            local _, classTag = GetClassInfo( i )
            if classTag then ClassIDs[ classTag ] = i end
        end
    else
        -- Fallback to manual class IDs for MoP Classic
        ClassIDs = {
            WARRIOR = 1,
            PALADIN = 2,
            HUNTER = 3,
            ROGUE = 4,
            PRIEST = 5,
            DEATHKNIGHT = 6,
            SHAMAN = 7,
            MAGE = 8,
            WARLOCK = 9,
            MONK = 10,
            DRUID = 11,
            DEMONHUNTER = 12
        }
    end
end

-- Initialize class IDs
InitializeClassIDs()

ns.getClassID = function( class )
    -- Ensure ClassIDs is initialized
    if not next(ClassIDs) then
        -- Try to initialize, but gracefully handle if not ready
        if GetNumClasses and GetClassInfo then
            InitializeClassIDs()
        else
            -- If APIs not available yet, return fallback values
            local fallbackClassIDs = {
                WARRIOR = 1,
                PALADIN = 2,
                HUNTER = 3,
                ROGUE = 4,
                PRIEST = 5,
                DEATHKNIGHT = 6,
                SHAMAN = 7,
                MAGE = 8,
                WARLOCK = 9,
                MONK = 10,
                DRUID = 11,
                DEMONHUNTER = 12
            }
            return fallbackClassIDs[class] or -1
        end
    end
    return ClassIDs[ class ] or -1
end


-- MoP Classic Power Type numbers
local MoPPowerTypes = {
    -- health       = -2, -- HealthCost doesn't exist in MoP
    none            = -1,
    mana            = 0,
    rage            = 1,
    focus           = 2,
    energy          = 3,
    combo_points    = 4,
    runes           = 5,
    runic_power     = 6,
    soul_shards     = 7,
    astral_power    = 8,  -- LunarPower in MoP
    holy_power      = 9,
    alternate       = 10,
    maelstrom       = 11,
    chi             = 12,
    insanity        = 13,

    burning_embers  = 14,
    obsolete2       = 15,
    arcane_charges  = 16,
    fury            = 17,
    pain            = 18,
    essence         = 19,
    blood_runes     = 20,
    frost_runes     = 21,
    unholy_runes    = 22,
    shadow_orbs     = 28,
}

local ResourceInfo = {
    -- health       = (Enum and Enum.PowerType and Enum.PowerType.HealthCost) or -1,
    none            = (Enum and Enum.PowerType and Enum.PowerType.None) or MoPPowerTypes.None,
    mana            = (Enum and Enum.PowerType and Enum.PowerType.Mana) or MoPPowerTypes.Mana,
    rage            = (Enum and Enum.PowerType and Enum.PowerType.Rage) or MoPPowerTypes.Rage,
    focus           = (Enum and Enum.PowerType and Enum.PowerType.Focus) or MoPPowerTypes.Focus,
    energy          = (Enum and Enum.PowerType and Enum.PowerType.Energy) or MoPPowerTypes.Energy,
    combo_points    = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or MoPPowerTypes.ComboPoints,
    runes           = (Enum and Enum.PowerType and Enum.PowerType.Runes) or MoPPowerTypes.Runes,
    runic_power     = (Enum and Enum.PowerType and Enum.PowerType.RunicPower) or MoPPowerTypes.RunicPower,
    soul_shards     = (Enum and Enum.PowerType and Enum.PowerType.SoulShards) or MoPPowerTypes.SoulShards,
    astral_power    = (Enum and Enum.PowerType and Enum.PowerType.LunarPower) or MoPPowerTypes.LunarPower,
    holy_power      = (Enum and Enum.PowerType and Enum.PowerType.HolyPower) or MoPPowerTypes.HolyPower,
    alternate       = (Enum and Enum.PowerType and Enum.PowerType.Alternate) or MoPPowerTypes.Alternate,
    maelstrom       = (Enum and Enum.PowerType and Enum.PowerType.Maelstrom) or MoPPowerTypes.Maelstrom,
    chi             = (Enum and Enum.PowerType and Enum.PowerType.Chi) or MoPPowerTypes.Chi,
    insanity        = (Enum and Enum.PowerType and Enum.PowerType.Insanity) or MoPPowerTypes.Insanity,
    burning_embers  = (Enum and Enum.PowerType and Enum.PowerType.BurningEmbers) or MoPPowerTypes.burning_embers,
    obsolete2       = (Enum and Enum.PowerType and Enum.PowerType.Obsolete2) or MoPPowerTypes.Obsolete2,
    arcane_charges  = (Enum and Enum.PowerType and Enum.PowerType.ArcaneCharges) or MoPPowerTypes.ArcaneCharges,
    fury            = (Enum and Enum.PowerType and Enum.PowerType.Fury) or MoPPowerTypes.Fury,
    pain            = (Enum and Enum.PowerType and Enum.PowerType.Pain) or MoPPowerTypes.Pain,
    essence         = (Enum and Enum.PowerType and Enum.PowerType.Essence) or MoPPowerTypes.Essence,
    blood_runes     = (Enum and Enum.PowerType and Enum.PowerType.RuneBlood) or MoPPowerTypes.RuneBlood,
    frost_runes     = (Enum and Enum.PowerType and Enum.PowerType.RuneFrost) or MoPPowerTypes.RuneFrost,
    unholy_runes    = (Enum and Enum.PowerType and Enum.PowerType.RuneUnholy) or MoPPowerTypes.RuneUnholy,
    shadow_orbs     = (Enum and Enum.PowerType and Enum.PowerType.ShadowOrbs) or MoPPowerTypes.ShadowOrbs,
}

local ResourceByID = {}

for k, powerType in pairs( ResourceInfo ) do
    ResourceByID[ powerType ] = k
end


function ns.GetResourceInfo()
    return ResourceInfo
end


function ns.GetResourceID( key )
    return ResourceInfo[ key ]
end


function ns.GetResourceKey( id )
    return ResourceByID[ id ]
end


local passive_regen = {
    mana = 1,
    focus = 1,
    energy = 1,
    essence = 1
}

function ns.ResourceRegenerates( key )
    -- Does this resource have a passive gain from waiting?
    if passive_regen[ key ] then return true end
    return false
end

-- Primary purpose of this table is to store information we know about a spec, but is not directly retrieveable via API calls in-game.
ns.Specializations = {
    [250] = {
        key = "blood",
        class = "DEATHKNIGHT",
        ranged = false
    },
    [251] = {
        key = "frost",
        class = "DEATHKNIGHT",
        ranged = false
    },
    [252] = {
        key = "unholy",
        class = "DEATHKNIGHT",
        ranged = false
    },
    [102] = {
        key = "balance",
        class = "DRUID",
        ranged = true
    },
    [103] = {
        key = "feral",
        class = "DRUID",
        ranged = false
    },
    [104] = {
        key = "guardian",
        class = "DRUID",
        ranged = false
    },
    [105] = {
        key = "restoration",
        class = "DRUID",
        ranged = true
    },
    [253] = {
        key = "beast_mastery",
        class = "HUNTER",
        ranged = true
    },
    [255] = {
        key = "survival",
        class = "HUNTER",
        ranged = true
    },
    [254] = {
        key = "marksmanship",
        class = "HUNTER",
        ranged = true
    },
    [62] = {
        key = "arcane",
        class = "MAGE",
        ranged = true
    },
    [63] = {
        key = "fire",
        class = "MAGE",
        ranged = true
    },
    [64] = {
        key = "frost",
        class = "MAGE",
        ranged = true
    },
    [268] = {
        key = "brewmaster",
        class = "MONK",
        ranged = false
    },
    [269] = {
        key = "windwalker",
        class = "MONK",
        ranged = false
    },
    [270] = {
        key = "mistweaver",
        class = "MONK",
        ranged = false
    },
    [65] = {
        key = "holy",
        class = "PALADIN",
        ranged = false
    },
    [66] = {
        key = "protection",
        class = "PALADIN",
        ranged = false
    },
    [70] = {
        key = "retribution",
        class = "PALADIN",
        ranged = false
    },
    [256] = {
        key = "discipline",
        class = "PRIEST",
        ranged = true
    },
    [257] = {
        key = "holy",
        class = "PRIEST",
        ranged = true
    },
    [258] = {
        key = "shadow",
        class = "PRIEST",
        ranged = true
    },
    [259] = {
        key = "assassination",
        class = "ROGUE",
        ranged = false
    },
    [260] = {
        key = "combat",
        class = "ROGUE",
        ranged = false
    },
    [261] = {
        key = "subtlety",
        class = "ROGUE",
        ranged = false
    },
    [262] = {
        key = "elemental",
        class = "SHAMAN",
        ranged = true
    },
    [263] = {
        key = "enhancement",
        class = "SHAMAN",
        ranged = false
    },
    [264] = {
        key = "restoration",
        class = "SHAMAN",
        ranged = true
    },
    [265] = {
        key = "affliction",
        class = "WARLOCK",
        ranged = true
    },
    [266] = {
        key = "demonology",
        class = "WARLOCK",
        ranged = true
    },
    [267] = {
        key = "destruction",
        class = "WARLOCK",
        ranged = true
    },
    [71] = {
        key = "arms",
        class = "WARRIOR",
        ranged = false
    },
    [72] = {
        key = "fury",
        class = "WARRIOR",
        ranged = false
    },
    [73] = {
        key = "protection",
        class = "WARRIOR",
        ranged = false
    },

}

ns.getSpecializationKey = function ( id )
    local spec = ns.Specializations[ id ]
    return spec and spec.key or "none"
end

-- MoP Classic spec detection function
ns.getSpecializationID = function( specIndex )
    local playerClass = select(2, UnitClass("player"))
    local selectedSpec = specIndex or (GetSpecialization and GetSpecialization()) or 1
    
    -- Basic fallback mapping for MoP Classic
    local fallbackMapping = {
        HUNTER = { [1] = 253, [2] = 254, [3] = 255 },       -- Beast Mastery, Marksmanship, Survival
        DEATHKNIGHT = { [1] = 250, [2] = 251, [3] = 252 },  -- Blood, Frost, Unholy
        DRUID = { [1] = 102, [2] = 103, [3] = 104, [4] = 105 }, -- Balance, Feral, Guardian, Restoration
        MAGE = { [1] = 62, [2] = 63, [3] = 64 },            -- Arcane, Fire, Frost
        MONK = { [1] = 268, [2] = 270, [3] = 269 },         -- Brewmaster, Mistweaver, Windwalker
        PALADIN = { [1] = 65, [2] = 66, [3] = 70 },         -- Holy, Protection, Retribution
        PRIEST = { [1] = 256, [2] = 257, [3] = 258 },       -- Discipline, Holy, Shadow
        ROGUE = { [1] = 259, [2] = 260, [3] = 261 },        -- Assassination, Combat, Subtlety
        SHAMAN = { [1] = 262, [2] = 263, [3] = 264 },       -- Elemental, Enhancement, Restoration
        WARLOCK = { [1] = 265, [2] = 266, [3] = 267 },      -- Affliction, Demonology, Destruction
        WARRIOR = { [1] = 71, [2] = 72, [3] = 73 }          -- Arms, Fury, Protection
    }
    
    if fallbackMapping[playerClass] and fallbackMapping[playerClass][selectedSpec] then
        return fallbackMapping[playerClass][selectedSpec]
    end
    
    return 0  -- Complete fallback
end




ns.PvpDummies = {
    [67229] = true,   -- Training Dummy (Level 93 Elite - MoP)
    [46647] = true,   -- Training Dummy (Level 85 - Cataclysm)
    [31146] = true,   -- Raider's Training Dummy (Level 80)
    [32666] = true,   -- Training Dummy
    [32667] = true    -- Training Dummy
}

ns.TargetDummies = {
    [   4952 ] = "Theramore Combat Dummy",
    [   5652 ] = "Undercity Combat Dummy",
    [  25225 ] = "Practice Dummy",
    [  25297 ] = "Drill Dummy",
    [  31144 ] = "Training Dummy",
    [  31146 ] = "Raider's Training Dummy",
    [  32541 ] = "Initiate's Training Dummy",
    [  32543 ] = "Veteran's Training Dummy",
    [  32546 ] = "Ebon Knight's Training Dummy",
    [  32542 ] = "Disciple's Training Dummy",
    [  32545 ] = "Training Dummy",
    [  32666 ] = "Training Dummy",
    [  32667 ] = "Training Dummy",
    [  44171 ] = "Training Dummy",
    [  44548 ] = "Training Dummy",
    [  44389 ] = "Training Dummy",
    [  44614 ] = "Training Dummy",
    [  44703 ] = "Training Dummy",
    [  44794 ] = "Training Dummy",
    [  44820 ] = "Training Dummy",
    [  44848 ] = "Training Dummy",
    [  44937 ] = "Training Dummy",
    [  46647 ] = "Training Dummy",
    [  48304 ] = "Training Dummy",
    [  60197 ] = "Training Dummy",
    [  64446 ] = "Training Dummy",
    [  67127 ] = "Training Dummy",
    [  70245 ] = "Training Dummy",
}


ns.FrameStratas = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",

    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8
}