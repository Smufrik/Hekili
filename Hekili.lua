-- Hekili.lua
-- July 2024

-- MoP Classic API globals that may not be in annotations
---@diagnostic disable: undefined-global
---@diagnostic disable: lowercase-global

local addon, ns = ...

-- Initialize MoP compatibility tables
ns.TargetDummies = ns.TargetDummies or {}

-- MoP API compatibility - Set up early for libraries
-- Note: We no longer override global functions to prevent interference with Blizzard's talent system
-- Instead, we use local functions for internal talent detection

Hekili = LibStub("AceAddon-3.0"):NewAddon( "Hekili", "AceConsole-3.0", "AceSerializer-3.0", "AceTimer-3.0" )

-- MoP compatibility - simple version detection
Hekili.Version = "v5.5.2-1.0.0r"
Hekili.Flavor = "MoP"

local format = string.format
local insert, concat = table.insert, table.concat

-- MoP API compatibility
local GetBuffDataByIndex = function(unit, index)
    local name, icon, count, debuffType, duration, expirationTime, source, isStealable,
          nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
          nameplateShowAll, timeMod = UnitBuff(unit, index)
    if name then
        return {
            name = name,
            icon = icon,
            applications = count or 1,
            dispelType = debuffType,
            duration = duration or 0,
            expirationTime = expirationTime or 0,
            sourceUnit = source,
            isStealable = isStealable,
            nameplateShowPersonal = nameplateShowPersonal,
            spellId = spellId,
            canApplyAura = canApplyAura,
            isBossAura = isBossDebuff,
            isFromPlayerOrPlayerPet = castByPlayer,
            nameplateShowAll = nameplateShowAll,
            timeMod = timeMod
        }
    end
end

local GetDebuffDataByIndex = function(unit, index)
    local name, icon, count, debuffType, duration, expirationTime, source, isStealable,
          nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
          nameplateShowAll, timeMod = UnitDebuff(unit, index)
    if name then
        return {
            name = name,
            icon = icon,
            applications = count or 1,
            dispelType = debuffType,
            duration = duration or 0,
            expirationTime = expirationTime or 0,
            sourceUnit = source,
            isStealable = isStealable,
            nameplateShowPersonal = nameplateShowPersonal,
            spellId = spellId,
            canApplyAura = canApplyAura,
            isBossAura = isBossDebuff,
            isFromPlayerOrPlayerPet = castByPlayer,
            nameplateShowAll = nameplateShowAll,
            timeMod = timeMod
        }
    end
end

-- MoP doesn't have UnpackAuraData, so we create a compatibility function
local UnpackAuraData = function(auraData)
    if type(auraData) == "table" then
        return auraData.name, auraData.icon, auraData.applications, auraData.dispelType,
               auraData.duration, auraData.expirationTime, auraData.sourceUnit, auraData.isStealable,
               auraData.nameplateShowPersonal, auraData.spellId, auraData.canApplyAura,
               auraData.isBossAura, auraData.isFromPlayerOrPlayerPet, auraData.nameplateShowAll,
               auraData.timeMod
    end
end

-- MoP AuraUtil compatibility - avoid conflicts with ElvUI
local ElvUI = _G.ElvUI
if ElvUI then
    -- ElvUI detected - don't create global AuraUtil to avoid conflicts
    -- print("DEBUG: ElvUI detected - skipping global AuraUtil creation to prevent conflicts")

    -- Create internal AuraUtil for Hekili's own use only
    if not ns.AuraUtil then
        ns.AuraUtil = {}
        ns.AuraUtil.ForEachAura = function(unit, filter, maxCount, func)
            -- Internal Hekili-only aura processing
            local i = 1
            while true do
                local name, icon, count, dispelType, duration, expirationTime, source, isStealable,
                      nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
                      nameplateShowAll, timeMod

                if filter == "HELPFUL" then
                    name, icon, count, dispelType, duration, expirationTime, source, isStealable,
                    nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
                    nameplateShowAll, timeMod = UnitBuff(unit, i)
                else
                    name, icon, count, dispelType, duration, expirationTime, source, isStealable,
                    nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
                    nameplateShowAll, timeMod = UnitDebuff(unit, i)
                end

                if not name then break end

                local aura = {
                    name = name,
                    icon = icon,
                    applications = count or 1,
                    dispelType = dispelType,
                    duration = duration or 0,
                    expirationTime = expirationTime or 0,
                    sourceUnit = source,
                    isStealable = isStealable,
                    nameplateShowPersonal = nameplateShowPersonal,
                    spellId = spellId,
                    canApplyAura = canApplyAura,
                    isBossAura = isBossDebuff,
                    isFromPlayerOrPlayerPet = castByPlayer,
                    nameplateShowAll = nameplateShowAll,
                    timeMod = timeMod or 1
                }

                func(aura)
                i = i + 1

                if maxCount and i > maxCount then break end
            end
        end
        -- print("DEBUG: Created internal ns.AuraUtil for Hekili (ElvUI compatibility mode)")
    end
else
    -- No ElvUI detected - safe to create global AuraUtil
    if not AuraUtil then
        AuraUtil = {}
        -- print("DEBUG: Created global AuraUtil (no ElvUI detected)")
    end

    -- Only create ForEachAura if it doesn't exist or isn't functional
    local needsCustomImplementation = not AuraUtil.ForEachAura
    if not needsCustomImplementation then
        -- Test if the existing implementation works for MoP
        local testWorked = pcall(function()
            AuraUtil.ForEachAura("player", "HELPFUL", 1, function() end)
        end)
        needsCustomImplementation = not testWorked
    end

    if needsCustomImplementation then
        -- Create MoP-compatible ForEachAura function
        local customForEachAura = function(unit, filter, maxCount, func)
            local i = 1
            while true do
                local name, icon, count, dispelType, duration, expirationTime, source, isStealable,
                      nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
                      nameplateShowAll, timeMod

                if filter == "HELPFUL" then
                    name, icon, count, dispelType, duration, expirationTime, source, isStealable,
                    nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
                    nameplateShowAll, timeMod = UnitBuff(unit, i)
                else
                    name, icon, count, dispelType, duration, expirationTime, source, isStealable,
                    nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer,
                    nameplateShowAll, timeMod = UnitDebuff(unit, i)
                end

                if not name then break end

                local aura = {
                    name = name,
                    icon = icon,
                    applications = count or 1,
                    dispelType = dispelType,
                    duration = duration or 0,
                    expirationTime = expirationTime or 0,
                    sourceUnit = source,
                    isStealable = isStealable,
                    nameplateShowPersonal = nameplateShowPersonal,
                    spellId = spellId,
                    canApplyAura = canApplyAura,
                    isBossAura = isBossDebuff,
                    isFromPlayerOrPlayerPet = castByPlayer,
                    nameplateShowAll = nameplateShowAll,
                    timeMod = timeMod or 1
                }

                func(aura)
                i = i + 1

                if maxCount and i > maxCount then break end
            end
        end
        -- print("DEBUG: Created global AuraUtil.ForEachAura (no ElvUI detected)")
    else
        -- print("DEBUG: AuraUtil.ForEachAura already exists")
    end
end

local buildStr, _, _, buildNum = GetBuildInfo()

-- MoP compatibility: Set proper build number for MoP
if not buildNum or buildNum < 50000 then
    buildNum = 18414 -- MoP 5.4.8 build number
    buildStr = "5.4.8"
end

Hekili.CurrentBuild = buildNum

if Hekili.Version == ( "@" .. "project-version" .. "@" ) then
    Hekili.Version = format( "Dev-%s (%s)", buildStr, date( "%Y%m%d" ) )
    Hekili.IsDev = true
end

Hekili.AllowSimCImports = true

Hekili.IsRetail = function()
    return false
end

Hekili.IsWrath = function()
    return false
end

Hekili.IsClassic = function()
    return true
end

Hekili.IsMoP = function()
    return true
end

Hekili.IsDragonflight = function()
    return false
end

Hekili.BuiltFor = 50400
Hekili.GameBuild = buildStr

ns.PTR = false
Hekili.IsPTR = ns.PTR

ns.Patrons = "|cFFFFD100Current Status|r\n\n"
    .. "All existing specializations are currently supported, though healer priorities are experimental and focused on rotational DPS only.\n\n"
    .. "If you find odd recommendations or other issues, please follow the |cFFFFD100Report Issue|r link below and submit all the necessary information to have your issue investigated.\n\n"
    .. "Please |cffff0000do not|r submit tickets for routine priority updates (i.e., from SimulationCraft). They are routinely updated."

do
    local cpuProfileDB = {}

    function Hekili:ProfileCPU( name, func )
        cpuProfileDB[ name ] = func
    end

	ns.cpuProfile = cpuProfileDB

	local frameProfileDB = {}

	function Hekili:ProfileFrame( name, f )
		frameProfileDB[ name ] = f
	end

	ns.frameProfile = frameProfileDB
end


ns.lib = {
    Format = {}
}


-- 04072017:  Let's go ahead and cache aura information to reduce overhead.
ns.auras = {
    target = {
        buff = {},
        debuff = {}
    },
    player = {
        buff = {},
        debuff = {}
    }
}

Hekili.Class = {
    specs = {},
    num = 0,

    file = "NONE",
    initialized = false,

	resources = {},
	resourceAuras = {},
    talents = {},
    pvptalents = {},
    glyphs = {},
	auras = {},
	auraList = {},
    powers = {},
	gear = {},
    setBonuses = {},

	knownAuraAttributes = {},

    stateExprs = {},
    stateFuncs = {},
    stateTables = {},

	abilities = {},
	abilityByName = {},
    abilityList = {},
    itemList = {},
    itemMap = {},
    itemPack = {
        lists = {
            items = {}
        }
    },

    packs = {},

    pets = {},
    totems = {},

    potions = {},
    potionList = {},

	hooks = {},
    range = 8,
	settings = {},
    stances = {},
	toggles = {},
	variables = {},
}
local class = Hekili.Class

Hekili.Scripts = {
    DB = {},
    Channels = {},
    PackInfo = {},
}

Hekili.State = {}

ns.hotkeys = {}
ns.keys = {}
ns.queue = {}
ns.targets = {}
ns.TTD = {}

ns.UI = {
    Displays = {},
    Buttons = {}
}

ns.debug = {}
ns.snapshots = {}


function Hekili:Query( ... )
	local output = ns

	for i = 1, select( '#', ... ) do
		output = output[ select( i, ... ) ]
    end

    return output
end


function Hekili:Run( ... )
	local n = select( "#", ... )
	local fn = select( n, ... )

	local func = ns

	for i = 1, fn - 1 do
		func = func[ select( i, ... ) ]
    end

    return func( select( fn, ... ) )
end


local debug = ns.debug
local active_debug
local current_display

local lastIndent = 0

function Hekili:SetupDebug( display )
    if not self.ActiveDebug then return end
    if not display then return end

    current_display = display

    debug[ current_display ] = debug[ current_display ] or {
        log = {},
        index = 1
    }
    active_debug = debug[ current_display ]
	active_debug.index = 1

	lastIndent = 0

	local pack = self.State.system.packName

    if not pack then return end

	self:Debug( "New Recommendations for [ %s ] requested at %s ( %.2f ); using %s( %s ) priority.", display, date( "%H:%M:%S"), GetTime(), self.DB.profile.packs[ pack ].builtIn and "built-in " or "", pack )
end


function Hekili:Debug( ... )
    if not self.ActiveDebug then return end
	if not active_debug then return end

	local indent, text = ...
	local start

	if type( indent ) ~= "number" then
		indent = lastIndent
		text = ...
		start = 2
	else
		lastIndent = indent
		start = 3
	end

	local prepend = format( indent > 0 and ( "%" .. ( indent * 4 ) .. "s" ) or "%s", "" )
	text = text:gsub("\n", "\n" .. prepend )
    text = format( "%" .. ( indent > 0 and ( 4 * indent ) or "" ) .. "s", "" ) .. text

    if select( start, ... ) ~= nil then
	    active_debug.log[ active_debug.index ] = format( text, select( start, ... ) )
    else
        active_debug.log[ active_debug.index ] = text
    end
    active_debug.index = active_debug.index + 1
end


local snapshots = ns.snapshots
local hasScreenshotted = false

function Hekili:SaveDebugSnapshot( dispName )
    local snapped = false
    local formatKey = ns.formatKey
    local state = Hekili.State
    local class = Hekili.Class

	for k, v in pairs( debug ) do
		if not dispName or dispName == k then
			for i = #v.log, v.index, -1 do
				v.log[ i ] = nil
			end

            -- Store aura data using simple UnitBuff/UnitDebuff calls
            local auraString = "\nplayer_buffs:"
            local now = GetTime()

            for i = 1, 40 do
                local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitBuff( "player", i )

                if not name then break end

                local aura = class.auras[ spellId ]
                local key = aura and aura.key
                if key and state.auras and state.auras.player and state.auras.player.buff and not state.auras.player.buff[ key ] then
                    key = key .. " [MISSING]"
                end

                auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
            end

            auraString = auraString .. "\n\nplayer_debuffs:"

            for i = 1, 40 do
                local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitDebuff( "player", i )

                if not name then break end

                local aura = class.auras[ spellId ]
                local key = aura and aura.key
                if key and state.auras and state.auras.player and state.auras.player.debuff and not state.auras.player.debuff[ key ] then
                    key = key .. " [MISSING]"
                end

                auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
            end


            if not UnitExists( "target" ) then
                auraString = auraString .. "\n\ntarget_auras:  target does not exist"
            else
                auraString = auraString .. "\n\ntarget_buffs:"

                for i = 1, 40 do
                    local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitBuff( "target", i )

                    if not name then break end

                    local aura = class.auras[ spellId ]
                    local key = aura and aura.key
                    if key and state.auras and state.auras.target and state.auras.target.buff and not state.auras.target.buff[ key ] then
                        key = key .. " [MISSING]"
                    end

                    auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
                end

                auraString = auraString .. "\n\ntarget_debuffs:"

                for i = 1, 40 do
                    local name, _, count, debuffType, duration, expirationTime, source, _, _, spellId, canApplyAura, isBossDebuff, castByPlayer = UnitDebuff( "target", i, "PLAYER" )

                    if not name then break end

                    local aura = class.auras[ spellId ]
                    local key = aura and aura.key
                    if key and state.auras and state.auras.target and state.auras.target.debuff and not state.auras.target.debuff[ key ] then
                        key = key .. " [MISSING]"
                    end

                    auraString = format( "%s\n   %6d - %-40s - %3d - %-6.2f", auraString, spellId or 0, key or ( "*" .. formatKey( name ) ), count > 0 and count or 1, expirationTime > 0 and ( expirationTime - now ) or 3600 )
                end
            end

            auraString = auraString .. "\n\n"

            insert( v.log, 1, auraString )
            if Hekili.TargetDebug and Hekili.TargetDebug:len() > 0 then
                insert( v.log, 1, "targets:\n" .. Hekili.TargetDebug )
            end
            insert( v.log, 1, self:GenerateProfile() )

            local custom = ""
            local packName = state.system and state.system.packName or "Unknown"
            local pack = self.DB and self.DB.profile and self.DB.profile.packs and self.DB.profile.packs[packName]

            if pack and not pack.builtIn then
                custom = format( " |cFFFFA700(Custom: %s[%d])|r", state.spec and state.spec.name or "Unknown", state.spec and state.spec.id or 0 )
            end

            local overview = format( "%s%s; %s|r", packName, custom, dispName or "Unknown" )
            local displayPool = Hekili.DisplayPool and Hekili.DisplayPool[dispName]
            local recs = displayPool and displayPool.Recommendations or {}

            for i, rec in ipairs( recs ) do
                if not rec.actionName then
                    if i == 1 then
                        overview = format( "%s - |cFF666666N/A|r", overview )
                    end
                    break
                end
                if not class.abilities[ rec.actionName ] then
                    if i == 1 then
                        overview = format( "%s - |cFF666666N/A|r", overview )
                    end
                    break
                end
                local abilityName = class.abilities[ rec.actionName ].name or rec.actionName or "Unknown"
                overview = format( "%s%s%s|cFFFFD100(%0.2f)|r", overview, ( i == 1 and " - " or ", " ), abilityName, rec.time or 0 )
            end

            insert( v.log, 1, overview )

            local snap = {
                header = "|cFFFFD100[" .. date( "%H:%M:%S" ) .. "]|r " .. overview,
                log = concat( v.log, "\n" ),
                data = ns.tableCopy( v.log ),
                recs = {}
            }

            insert( snapshots, snap )
            snapped = true
		end
    end

    if snapped then
        if Hekili.DB.profile.screenshot then Screenshot() end
        return true
    end

    return false
end

Hekili.Snapshots = ns.snapshots



ns.Tooltip = CreateFrame( "GameTooltip", "HekiliTooltip", UIParent, "GameTooltipTemplate" )
Hekili:ProfileFrame( "HekiliTooltip", ns.Tooltip )

ns.db = nil -- Placeholder for AceDB

-- Initialize Hekili.DB as early as possible with a placeholder
-- This will be replaced when OnInitialize runs
Hekili.DB = { profile = { enabled = false, displays = {}, toggles = { mode = { value = "automatic" }, cooldowns = { value = true }, interrupts = { value = true }, defensives = { value = true }, potions = { value = true } }, specs = {}, notifications = { enabled = false } } }

function Hekili:OnInitialize()
    -- Initialization code
    ns.db = LibStub("AceDB-3.0"):New("HekiliDB", ns.Defaults, true)
    self.db = ns.db
    self.DB = ns.db  -- Make sure Hekili.DB is properly set

    -- Register slash commands, etc.
    self:RegisterChatCommand("hekili", "ChatCommand")

    -- Initialize other modules that depend on DB being ready
    if ns.Options and ns.Options.Initialize then
        ns.Options:Initialize()
    end

    if ns.UI and ns.UI.Initialize then  -- Ensure UI is initialized after DB
        ns.UI:Initialize()
    end

    self.initialized = true
    self:Print("Hekili Initialized for MoP!")
end

function Hekili:OnEnable()
    -- Enabling code
    if not self.initialized then self:OnInitialize() end

    if ns.Events and ns.Events.Register then
        ns.Events:Register()
    end

    -- Start UI updates if not paused
    if ns.UI and ns.UI.StartUpdates then
        ns.UI:StartUpdates()
    end


    self:Print("Hekili Enabled!")
end

function Hekili:OnDisable()
    -- Disabling code
    if ns.Events and ns.Events.Unregister then
        ns.Events:Unregister()
    end

    if ns.UI and ns.UI.StopUpdates then
        ns.UI:StopUpdates()
    end    self:Print("Hekili Disabled!")
end

-- Store class information but don't overwrite the Class table
Hekili.ClassName = select( 2, UnitClass( "player" ) )
Hekili.ClassIndex = select( 3, UnitClass( "player" ) )

-- Placeholder for callHook (defined in Classes.lua)
local callHook = callHook
if not callHook then
    function callHook(hookName, ...)
        -- This is a placeholder, the actual function is in Classes.lua
        -- print("Placeholder callHook:", hookName)
    end
end

-- Fallback for GetSpecialization / GetSpecializationInfo / CanPlayerUseTalentSpecUI

-- MoP Classic spec detection function
function Hekili:GetMoPSpecialization()
    local _, class = UnitClass("player")
    if not class then
        return nil, nil
    end

    -- Use the proper mapping from Constants.lua
    local selectedSpec = GetSpecialization and GetSpecialization() or GetActiveTalentGroup and GetActiveTalentGroup() or 1
    
    -- Use the fallback mapping from Constants.lua
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
    
    local specID = fallbackMapping[class] and fallbackMapping[class][selectedSpec] or 0
    
    -- Get spec name from the Specializations table
    local specName = "Unknown"
    if specID > 0 and ns.Specializations[specID] then
        specName = ns.Specializations[specID].key:gsub("_", " "):gsub("^%l", string.upper)
        -- Convert "beast mastery" to "Beast Mastery", "marksmanship" to "Marksmanship", etc.
        specName = specName:gsub(" %l", string.upper)
    end

    return specID, specName
end

-- Manual function to force spec detection and update
function Hekili:ForceSpecDetection()
    local specID, specName = self:GetMoPSpecialization()

    if specID and specID > 0 then
        -- Manually set state.spec values
        if not self.State then
            self.State = { spec = {}, role = {} }
        end
        if not self.State.spec then
            self.State.spec = {}
        end

        self.State.spec.id = specID
        self.State.spec.name = specName

        -- Try to get spec key using the getSpecializationKey function from Constants.lua
        if ns.getSpecializationKey then
            self.State.spec.key = ns.getSpecializationKey(specID)
        else
            -- Fallback spec key generation
            self.State.spec.key = specName and specName:lower():gsub("%s+", "_") or "unknown"
        end




        -- Force a spec change event
        if self.SpecializationChanged then
            self:SpecializationChanged()
        end

        return true
    else
        return false
    end
end


