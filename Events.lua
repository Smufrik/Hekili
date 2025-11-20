-- Events.lua
-- July 2024

local addon, ns = ...
local Hekili = _G[addon]

local class = Hekili.Class
local state = Hekili.State

-- Performance optimization: debounce ForceUpdate calls
local pendingUpdate
local function RequestUpdate(reason)
    if pendingUpdate then return end
    pendingUpdate = true
    C_Timer.After(0, function()
        Hekili:ForceUpdate(reason, true)
        pendingUpdate = nil
    end)
end

-- Swing timer integration will be initialized after StartEventHandler is called
local swingTimerInitialized = false
local function InitializeSwingTimer()
    if swingTimerInitialized then return end
    
    local SwingAPI = LibStub and LibStub:GetLibrary("LibClassicSwingTimerAPI", true)
    if not SwingAPI then return end
    
    local function SyncSwingSpeeds(mhSpeed, ohSpeed)
        local sw = state.swings
        if not sw then return end

        local changed

        if mhSpeed and mhSpeed > 0 then
            sw.mh_speed = mhSpeed
            state.mainhand_speed = mhSpeed
            if sw.mh_actual and sw.mh_actual > 0 then
                sw.mh_projected = sw.mh_actual + mhSpeed
                sw.mh_pseudo = sw.mh_actual
                sw.mh_pseudo_speed = mhSpeed
                state.nextMH = sw.mh_projected
            end
            changed = true
        end

        if ohSpeed and ohSpeed > 0 then
            sw.oh_speed = ohSpeed
            state.offhand_speed = ohSpeed
            if sw.oh_actual and sw.oh_actual > 0 then
                sw.oh_projected = sw.oh_actual + ohSpeed
                sw.oh_pseudo = sw.oh_actual
                sw.oh_pseudo_speed = ohSpeed
                state.nextOH = sw.oh_projected
            end
            changed = true
        end

        if changed then
            RequestUpdate("SWING_TIMER_SPEED")
        end
    end

    SwingAPI:RegisterCallback("SWING_TIMER_READY", function(event, mhSpeed, ohSpeed)
        SyncSwingSpeeds(mhSpeed, ohSpeed)
    end)

    SwingAPI:RegisterCallback("SWING_TIMER_SPEED", function(event, mhSpeed, ohSpeed)
        SyncSwingSpeeds(mhSpeed, ohSpeed)
    end)

    SwingAPI:RegisterCallback("SWING_TIMER_MAINHAND", function(event, timestamp, speed)
        local sw = state.swings
        if not sw then return end

        local now = timestamp or GetTime()
        sw.mh_actual = now

        if speed and speed > 0 then
            sw.mh_speed = speed
            state.mainhand_speed = speed
        end

        local mhSpeed = sw.mh_speed or speed or 0
        if mhSpeed > 0 then
            sw.mh_projected = now + mhSpeed
            sw.mh_pseudo = now
            sw.mh_pseudo_speed = mhSpeed
            state.nextMH = sw.mh_projected
        end

        RequestUpdate("SWING_TIMER_MAINHAND")
    end)

    SwingAPI:RegisterCallback("SWING_TIMER_OFFHAND", function(event, timestamp, speed)
        local sw = state.swings
        if not sw then return end

        local now = timestamp or GetTime()
        sw.oh_actual = now

        if speed and speed > 0 then
            sw.oh_speed = speed
            state.offhand_speed = speed
        end

        local ohSpeed = sw.oh_speed or speed or 0
        if ohSpeed > 0 then
            sw.oh_projected = now + ohSpeed
            sw.oh_pseudo = now
            sw.oh_pseudo_speed = ohSpeed
            state.nextOH = sw.oh_projected
        end

        RequestUpdate("SWING_TIMER_OFFHAND")
    end)
    
    swingTimerInitialized = true
end

local PTR = ns.PTR
local TTD = ns.TTD

local formatKey = ns.formatKey

local abs = math.abs
local lower = string.lower
local insert, remove, sort, wipe = table.insert, table.remove, table.sort, table.wipe

-- MoP API compatibility
local CGetItemInfo = ns.CachedGetItemInfo
-- Use a local wrapper to check if an itemID is equipped without deprecated APIs.
local function IsEquippedItemLocal(itemID)
    if type(itemID) ~= "number" then return false end
    if C_Item and C_Item.IsEquippedItemByID then
        local ok = C_Item.IsEquippedItemByID(itemID)
        if ok ~= nil then return ok end
    end
    for slot = 1, 19 do
        local id = GetInventoryItemID( "player", slot )
        if id == itemID then return true end
    end
    return false
end
local GetDetailedItemLevelInfo = function(itemLink) 
    local _, _, _, itemLevel = CGetItemInfo(itemLink)
    return itemLevel or 0
end

-- MoP: Local talent detection function (not global override)
local function HekiliGetTalentInfoByID(talentID, groupIndex)
    -- If no talentID is provided, return early
    if not talentID then
        return nil, nil, nil, false, nil, nil, nil, nil, nil, false
    end
    
    local enabled = false
    local spellID = nil
    
    if type(talentID) == "table" and talentID[1] and talentID[2] and talentID[3] then
        local tier, column, spellIdFromTable = talentID[1], talentID[2], talentID[3]
        spellID = spellIdFromTable
        
        -- For MoP, we need to check which talent is actually selected in each tier
        -- We'll use IsPlayerSpell but only allow ONE talent per tier to be enabled
        local isKnown = IsPlayerSpell(spellID)
        
        -- If this talent is known, check if it's the ONLY one in this tier that's known
        if isKnown then
            enabled = true
            -- Check other talents in the same tier to ensure only one is enabled
            if class and class.talents then
                for k, v in pairs(class.talents) do
                    if type(v) == "table" and v[1] == tier and v[2] ~= column and v[3] then
                        if IsPlayerSpell(v[3]) then
                            -- Another talent in the same tier is also known, this shouldn't happen
                            -- But we'll allow it for now and let the user decide
                            enabled = true
                        end
                    end
                end
            end
        end
        
        -- Return values: id, name, tier, enabled, available, spellID, icon, row, column, known
        -- The key is that 'known' should be the same as 'enabled' for our logic
        return nil, nil, tier, enabled, enabled, spellID, nil, tier, column, enabled
    elseif talentID and type(talentID) == "number" and talentID > 0 then
        spellID = talentID
        enabled = IsPlayerSpell(spellID)
        return nil, nil, nil, enabled, nil, spellID, nil, nil, nil, enabled
    end
    
    return nil, nil, nil, false, nil, nil, nil, nil, nil, false
end

-- Store the function in Hekili namespace for internal use
Hekili.GetTalentInfoByID = HekiliGetTalentInfoByID



-- MoP: UnitGetTotalAbsorbs compatibility (didn't exist in MoP)
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs or function(unit)
    return 0  -- Absorbs didn't exist as a mechanic in MoP
end

-- MoP: SpellIsSelfBuff compatibility
local SpellIsSelfBuff = SpellIsSelfBuff or function(spellID)
    -- In MoP, this function doesn't exist
    -- We'll assume false as a safe default for compatibility
    return false
end

-- Ensure UnitBuff is locally referenced (prevents undefined-global linter warnings)
local UnitBuff = rawget( _G, "UnitBuff" ) or function( ... )
    return nil
end

-- MoP: GetSpecialization/GetSpecializationInfo compatibility
local GetSpecialization = GetSpecialization or function()
    -- Enhanced MoP Classic spec detection
    local _, class = UnitClass("player")
    
    if class == "DRUID" then
        -- Detect Druid specialization based on abilities and forms
        if IsPlayerSpell(33876) or IsPlayerSpell(5221) then return 1 -- Feral (maps to 103)
        elseif IsPlayerSpell(33878) or IsPlayerSpell(6807) then return 2 -- Guardian (maps to 104)  
        elseif IsPlayerSpell(78674) or IsPlayerSpell(8921) then return 3 -- Balance (maps to 102)
        elseif IsPlayerSpell(18562) or IsPlayerSpell(2908) then return 4 -- Restoration (maps to 105)
        else return 1 end -- Default to Feral
    end

    local Hekili = _G["Hekili"]
local state  = Hekili and Hekili.State

-- Create a dedicated event frame for encounter tracking
local bossEvtFrame = CreateFrame("Frame", "HekiliBossEvents")

-- Register boss-relevant events
bossEvtFrame:RegisterEvent("ENCOUNTER_START")
bossEvtFrame:RegisterEvent("ENCOUNTER_END")
bossEvtFrame:RegisterEvent("PLAYER_ENTERING_WORLD") -- for resets on zoning/reload

-- Define what happens on those events
bossEvtFrame:SetScript("OnEvent", function(self, event, ...)
    if not state then return end

    if event == "ENCOUNTER_START" then
        local encounterID, encounterName, difficultyID, groupSize = ...
        state.encounterID   = encounterID or 0
        state.encounterName = encounterName
        Hekili:ForceUpdate(event)

    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if state.encounterID == encounterID then
            state.encounterID   = 0
            state.encounterName = nil
            Hekili:ForceUpdate(event)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        state.encounterID   = 0
        state.encounterName = nil
        Hekili:ForceUpdate(event)
    end
end)
    
    -- For other classes, use talent group as fallback
    local activeTalentGroup = GetActiveTalentGroup and GetActiveTalentGroup() or 1
    return activeTalentGroup
end

local GetSpecializationInfo = GetSpecializationInfo or function(specIndex)
    if not specIndex or specIndex == 0 then return nil end
    
    -- Fallback for MoP - try to determine spec based on known spells
    local _, class = UnitClass("player")
    local specID = 0
    local specName = "Unknown"
    
    -- Simple spec detection based on key spells (this is very basic)
    if class == "WARRIOR" then
        if IsPlayerSpell(46924) then specID = 71; specName = "Arms"  -- Bladestorm
        elseif IsPlayerSpell(23881) then specID = 72; specName = "Fury"  -- Bloodthirst  
        elseif IsPlayerSpell(871) then specID = 73; specName = "Protection"  -- Shield Wall
        else specID = 71; specName = "Arms" end
    elseif class == "PALADIN" then
        if IsPlayerSpell(31884) then specID = 70; specName = "Retribution"  -- Avenging Wrath
        elseif IsPlayerSpell(31850) then specID = 66; specName = "Protection"  -- Ardent Defender
        elseif IsPlayerSpell(20473) then specID = 65; specName = "Holy"  -- Holy Shock
        else specID = 70; specName = "Retribution" end
    elseif class == "HUNTER" then
        if IsPlayerSpell(19574) then specID = 253; specName = "Beast Mastery"  -- Bestial Wrath
        elseif IsPlayerSpell(19506) then specID = 254; specName = "Marksmanship"  -- Improved Tracking
        elseif IsPlayerSpell(53301) then specID = 255; specName = "Survival"  -- Explosive Shot
        else 
            -- Fallback detection based on other abilities
            if IsPlayerSpell(34026) then specID = 253; specName = "Beast Mastery"  -- Kill Command
            elseif IsPlayerSpell(82928) then specID = 254; specName = "Marksmanship"  -- Aimed Shot
            elseif IsPlayerSpell(3674) then specID = 255; specName = "Survival"  -- Black Arrow
            else specID = 255; specName = "Survival" end -- Default to Survival
        end
    elseif class == "DRUID" then
        -- Druid spec detection for MoP Classic - Better prioritization
        -- Check for Restoration-specific spells FIRST (highest priority for healers)
        if IsPlayerSpell(18562) then specID = 105; specName = "Restoration"  -- Swiftmend - Restoration specific
        elseif IsPlayerSpell(33763) then specID = 105; specName = "Restoration"  -- Lifebloom - Restoration specific
        
        -- Check for Feral-specific spells (higher priority than shared spells)
        elseif IsPlayerSpell(52610) then specID = 103; specName = "Feral"  -- Savage Roar - Feral specific  
        elseif IsPlayerSpell(22568) then specID = 103; specName = "Feral"  -- Ferocious Bite - Feral specific
        elseif IsPlayerSpell(33876) then specID = 103; specName = "Feral"  -- Mangle (Cat) - Feral specific
        elseif IsPlayerSpell(5221) then specID = 103; specName = "Feral"  -- Shred - Core Feral ability
        elseif IsPlayerSpell(1822) then specID = 103; specName = "Feral"  -- Rake - Core Feral ability
        
        -- Check for Guardian-specific spells
        elseif IsPlayerSpell(33878) then specID = 104; specName = "Guardian"  -- Mangle (Bear) - Guardian specific
        elseif IsPlayerSpell(6807) then specID = 104; specName = "Guardian"  -- Maul - Guardian specific
        
        -- Check for Balance-specific spells (lower priority since some are shared)
        elseif IsPlayerSpell(78674) then specID = 102; specName = "Balance"  -- Starsurge - Balance specific
        elseif IsPlayerSpell(8921) then specID = 102; specName = "Balance"  -- Moonfire - Available to all but assume Balance
        
        else 
            -- Last resort fallback based on form or default to Feral
            if GetShapeshiftForm and (GetShapeshiftForm() == 1 or IsPlayerSpell(768)) then -- Cat Form
                specID = 103; specName = "Feral"
            elseif GetShapeshiftForm and (GetShapeshiftForm() == 2 or IsPlayerSpell(5487)) then -- Bear Form  
                specID = 104; specName = "Guardian"
            else specID = 103; specName = "Feral" end -- Default to Feral
        end
    elseif class == "ROGUE" then
        -- Rogue spec detection for MoP Classic - prioritize Combat over Assassination  
        if IsPlayerSpell(13750) then specID = 260; specName = "Combat"  -- Adrenaline Rush - Combat specific
        elseif IsPlayerSpell(13877) then specID = 260; specName = "Combat"  -- Blade Flurry - Combat specific
        elseif IsPlayerSpell(84617) then specID = 260; specName = "Combat"  -- Revealing Strike - Combat specific
        elseif IsPlayerSpell(51690) then specID = 260; specName = "Combat"  -- Killing Spree - Combat specific
        
        -- Check for Assassination-specific spells
        elseif IsPlayerSpell(2823) then specID = 259; specName = "Assassination"  -- Deadly Poison - Assassination
        elseif IsPlayerSpell(32645) then specID = 259; specName = "Assassination"  -- Envenom - Assassination specific
        elseif IsPlayerSpell(79140) then specID = 259; specName = "Assassination"  -- Vendetta - Assassination specific
        
        -- Check for Subtlety-specific spells  
        elseif IsPlayerSpell(36554) then specID = 261; specName = "Subtlety"  -- Shadowstep - Subtlety specific
        elseif IsPlayerSpell(14183) then specID = 261; specName = "Subtlety"  -- Premeditation - Subtlety specific
        elseif IsPlayerSpell(51713) then specID = 261; specName = "Subtlety"  -- Shadow Dance - Subtlety specific
        
        else specID = 260; specName = "Combat" end -- Default to Combat
    -- Add more classes as needed
    else
        specID = 1
        specName = "Unknown"
    end
    
    return specID, specName, nil, nil, nil, class
end

-- Enhanced MoP Classic UnitBuff for better APL compatibility
-- Iterate player buffs to find a matching aura by spellID (number) or name (string).
local UA_GetPlayerAuraBySpellID = function(spellID)
    if not spellID then return nil end

    local i = 1
    while true do
        -- In MoP Classic, UnitBuff signature is UnitBuff(unit, index[, filter])
        local name, icon, count, dispelType, duration, expirationTime, source, isStealable,
              nameplateShowPersonal, foundSpellId = UnitBuff("player", i)

        if not name then break end

        local matches = false
        if type(spellID) == "number" then
            matches = (foundSpellId == spellID)
        elseif type(spellID) == "string" then
            -- Only match if the provided string is the actual aura name.
            matches = (name == spellID)
        end

        if matches then
            local auraData = {
                name = name,
                icon = icon,
                applications = count or 1,
                dispelType = dispelType,
                duration = duration or 0,
                expirationTime = expirationTime or 0,
                sourceUnit = source,
                isStealable = isStealable,
                nameplateShowPersonal = nameplateShowPersonal,
                spellId = foundSpellId,
                isFromPlayerOrPlayerPet = (source == "player" or source == "pet")
            }
            
            -- Enhanced aura data for APL compatibility
            if Hekili.DB.profile.enhancedEvents then
                auraData.remains = max(0, expirationTime - GetTime())
                auraData.applied = expirationTime - duration
                auraData.count = count or 1
            end
            
            return auraData
        end

        i = i + 1
    end

    return nil
end

local IsUsableItem = ns.IsUsableItem
local GetItemSpell = ns.GetItemSpell

-- MoP API compatibility for spell cooldowns
-- Avoid shadowing/global recursion: call the real API explicitly.
local function GetSpellCooldownMoP(spellID)
    local start, duration, enable, modRate = _G.GetSpellCooldown(spellID)
    return start, duration, enable, modRate
end

local GetSpellInfo = ns.GetUnpackedSpellInfo

local FindStringInInventoryItemTooltip = ns.FindStringInInventoryItemTooltip
local ResetDisabledGearAndSpells = ns.ResetDisabledGearAndSpells

local RC = LibStub( "LibRangeCheck-3.0", true ) -- MoP: Use silent loading to prevent errors

-- Abandoning AceEvent in favor of darkend's solution from:
-- http://andydote.co.uk/2014/11/23/good-design-in-warcraft-addons.html
-- This should be a bit friendlier for our modules.

local events = CreateFrame( "Frame" )
Hekili:ProfileFrame( "GeneralEvents", events )
local handlers = {}
local unitHandlers = {}

local itemCallbacks = {}
local spellCallbacks = {}
local activeDisplays = {}


function Hekili:GetActiveDisplays()
    return activeDisplays
end


local handlerCount = {}
Hekili.ECount = handlerCount
Hekili.IC = itemCallbacks

local eventData = {}
Hekili.EData = eventData

local function GenericOnEvent( self, event, ... )
    local eventHandlers = handlers[ event ]

    if not eventHandlers then return end

    for i, handler in ipairs( eventHandlers ) do
        local key = event .. "_" .. i
        local start = debugprofilestop()
        handler( event, ... )
        local finish = debugprofilestop()

        handlerCount[ key ] = ( handlerCount[ key ] or 0 ) + 1

        eventData[ key ] = eventData[ key ] or {}
        eventData[ key ].max = max( eventData[ key ].max or 0, finish - start )
        eventData[ key ].total = ( eventData[ key ].total or 0 ) + ( finish - start )
        
        -- Enhanced event tracking for APL compatibility
        if Hekili.DB.profile.enhancedEvents and eventData[ key ].total > 1000 then
            Hekili:ForceUpdate( "EVENT_PERFORMANCE", true )
        end
    end
end

local function UnitSpecificOnEvent( self, event, unit, ... )
    local unitFrame = unitHandlers[ unit ]

    if unitFrame then
        local eventHandlers = unitFrame.events[ event ]

        if not eventHandlers then return end

        for i, handler in ipairs( eventHandlers ) do
            local key = event .. "_" .. unit .. "_" .. i
            local start = debugprofilestop()
            handler( event, unit, ... )
            local finish = debugprofilestop()

            handlerCount[ key ] = ( handlerCount[ key ] or 0 ) + 1

            eventData[ key ] = eventData[ key ] or {}
            eventData[ key ].max = max( eventData[ key ].max or 0, finish - start )
            eventData[ key ].total = ( eventData[ key ].total or 0 ) + ( finish - start )
        end
    end
end

function ns.StartEventHandler()
    events:SetScript( "OnEvent", GenericOnEvent )

    for unit, unitFrame in pairs( unitHandlers ) do
        unitFrame:SetScript( "OnEvent", UnitSpecificOnEvent )
    end
    
    -- Enhanced event handler with performance monitoring
    events:SetScript( "OnUpdate", function( self, elapsed )
        if Hekili.PendingSpecializationChange then
            if Hekili.SpecializationChanged then
                Hekili:SpecializationChanged()
                Hekili.PendingSpecializationChange = false
                -- Spec updates are expensive; exit and do other work in the next frame.
                return
            end
        end

        -- Enhanced frame update handling for APL compatibility
        if handlers.FRAME_UPDATE then
            for i, handler in pairs( handlers.FRAME_UPDATE ) do
                local key = "FRAME_UPDATE_" .. i
                local start = debugprofilestop()
                handler( "FRAME_UPDATE", elapsed )
                local finish = debugprofilestop()

                handlerCount[ key ] = ( handlerCount[ key ] or 0 ) + 1

                eventData[ key ] = eventData[ key ] or {}
                eventData[ key ].max = max( eventData[ key ].max or 0, finish - start )
                eventData[ key ].total = ( eventData[ key ].total or 0 ) + ( finish - start )
                
                -- Enhanced performance monitoring for APL compatibility
                if Hekili.DB.profile.enhancedEvents and eventData[ key ].total > 5000 then
                    Hekili:ForceUpdate( "FRAME_UPDATE_PERFORMANCE", true )
                end
            end
        end
        
        -- Enhanced event performance monitoring
        if Hekili.DB.profile.enhancedEvents then
            local totalEventTime = 0
            for _, data in pairs( eventData ) do
                totalEventTime = totalEventTime + ( data.total or 0 )
            end
            
            if totalEventTime > 10000 then
                Hekili:ForceUpdate( "EVENT_PERFORMANCE_MONITOR", true )
            end
        end
    end )

    Hekili:RunSpellCallbacks()
    
    -- Initialize swing timer integration after event system is ready
    InitializeSwingTimer()
end


function ns.StopEventHandler()
    events:SetScript( "OnEvent", nil )

    for unit, unitFrame in pairs( unitHandlers ) do
        unitFrame:SetScript( "OnEvent", nil )
    end

    events:SetScript( "OnUpdate", nil )
end


Hekili.EventSources = {}

ns.RegisterEvent = function( event, handler )

    handlers[ event ] = handlers[ event ] or {}
    insert( handlers[ event ], handler )

    if event ~= "FRAME_UPDATE" then events:RegisterEvent( event ) end

    local key = event .. "_" .. #handlers[event]
    Hekili:ProfileCPU( key, handler )

    local stack = debugstack(2)
    local file, line = stack:match([[Hekili/(.-)"%]:(%d+)]])
    Hekili.EventSources[ key ] = file and ( file .. ":" .. ( line or 0 ) ) or stack:match( "^(.*)\n" )
    
    -- Enhanced event registration for APL compatibility
    if Hekili.DB.profile.enhancedEvents then
        -- Track important events for APL compatibility
        if event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "UNIT_AURA" or event == "PLAYER_TARGET_CHANGED" then
            Hekili:ForceUpdate( "EVENT_REGISTERED", true )
        end
    end
end
local RegisterEvent = ns.RegisterEvent


ns.UnregisterEvent = function( event, handler )
    local hands = handlers[ event ]

    if not hands then return end

    for i = #hands, 1, -1 do
        if hands[i] == handler then
            remove( hands, i )
        end
    end

    if #hands == 0 then events:UnregisterEvent( event ) end
end
local UnregisterEvent = ns.UnregisterEvent


-- For our purposes, all UnitEvents are player/target oriented.
ns.RegisterUnitEvent = function( event, unit1, unit2, handler )
    if not unit1 then unit1 = "player" end

    if not unitHandlers[ unit1 ] then
        unitHandlers[ unit1 ] = CreateFrame( "Frame" )
        Hekili:ProfileFrame( "UnitEvents:" .. unit1, unitHandlers[ unit1 ] )

        unitHandlers[ unit1 ].events = {}
    end

    local unitFrame = unitHandlers[ unit1 ]

    unitFrame.events[ event ] = unitFrame.events[ event ] or {}
    insert( unitFrame.events[ event ], handler )

    local stack = debugstack(2)
    local file, line = stack:match([[Hekili/(.-)"%]:(%d+)]])
    Hekili.EventSources[ event .. "_" .. unit1 .. "_" .. #unitFrame.events[ event ] ] = file and ( file .. ":" .. ( line or 0 ) ) or stack:match( "^(.*)\n" )

    unitFrame:RegisterUnitEvent( event, unit1 )
    Hekili:ProfileCPU( event .. "_" .. unit1 .. "_" .. #unitFrame.events[ event ], handler )

    if unit2 then
        if not unitHandlers[ unit2 ] then
            unitHandlers[ unit2 ] = CreateFrame( "Frame" )
            Hekili:ProfileFrame( "UnitEvents:" .. unit2, unitHandlers[ unit2 ] )

            unitHandlers[ unit2 ].events = {}
        end

        unitFrame = unitHandlers[ unit2 ]

        unitFrame.events[ event ] = unitFrame.events[ event ] or {}
        insert( unitFrame.events[ event ], handler )

        Hekili.EventSources[ event .. "_" .. unit2 .. "_" .. #unitFrame.events[ event ] ] = file and ( file .. ":" .. ( line or 0 ) ) or stack:match( "^(.*)\n" )

        unitFrame:RegisterUnitEvent( event, unit2 )
        Hekili:ProfileCPU( event .. "_" .. unit2 .. "_" .. #unitFrame.events[ event ], handler )
    end
end
local RegisterUnitEvent = ns.RegisterUnitEvent


function ns.UnregisterUnitEvent( event, handler )
    local hands = unitHandlers[ event ]

    if not hands then return end

    for i = #hands, 1, -1 do
        if hands[i] == handler then
            remove( hands, i )
        end
    end
end


ns.FeignEvent = function( event, ... )
    local eventHandlers = handlers[ event ]

    if not eventHandlers then return end

    for i, handler in pairs( eventHandlers ) do
        handler( event, ... )
    end
end
Hekili.FeignEvent = ns.FeignEvent


do
    local isUnregistered = false
    local next = _G.next

    local requeued = {}

    local function HandleSpellData( event, spellID, success )
        local callbacks = spellCallbacks[ spellID ]

        if callbacks then
            for i = #callbacks, 1, -1 do
                callbacks[i]( event, spellID, success )
                remove( callbacks, i )
            end

            if #callbacks == 0 then
                spellCallbacks[ spellID ] = nil
            end
        end

        if spellCallbacks == nil or next( spellCallbacks ) == nil then
            UnregisterEvent( "SPELL_DATA_LOAD_RESULT", HandleSpellData )
            isUnregistered = true
        end
    end

    function Hekili:ContinueOnSpellLoad( spellID, func )
        -- MoP: No spell data caching system, call immediately
        func( true )
        return
    end

    function Hekili:RunSpellCallbacks()
        for spell, callbacks in pairs( spellCallbacks ) do
            for i = #callbacks, 1, -1 do
                if not callbacks[ i ]( true ) == false then remove( callbacks, i ) end
            end

            if #callbacks == 0 then
                spellCallbacks[ spell ] = nil
            end
        end
    end
end


RegisterEvent( "DISPLAY_SIZE_CHANGED", function()
    Hekili:BuildUI()
end )



RegisterEvent( "PLAYER_ENTERING_WORLD", function( event, login, reload )
    if not Hekili.PLAYER_ENTERING_WORLD and ( login or reload ) then        Hekili.PLAYER_ENTERING_WORLD = true
        if Hekili.SpecializationChanged then
            Hekili:SpecializationChanged()
        end
        if Hekili.RestoreDefaults then
            Hekili:RestoreDefaults()
        end

        ns.checkImports()
        ns.updateGear()

        if state.combat == 0 and InCombatLockdown() then
            state.combat = GetTime() - 0.01
        end

        local _, zone, _, _, _, _, _, instanceID = GetInstanceInfo()
        state.bg = zone == "pvp"
        state.arena = zone == "arena"
        
        state.instance_id = instanceID or -1

        Hekili:BuildUI()
    end
end )






do    if Hekili.IsWrath() then
        RegisterEvent( "ACTIVE_TALENT_GROUP_CHANGED", function()
            if Hekili.SpecializationChanged then
                Hekili:SpecializationChanged()
            end
        end )
    else
        local specializationEvents = {
            ACTIVE_PLAYER_SPECIALIZATION_CHANGED = 1,
            ACTIVE_TALENT_GROUP_CHANGED = 1,
            CONFIRM_TALENT_WIPE = 1,
            PLAYER_TALENT_UPDATE = 1,
            SPEC_INVOLUNTARILY_CHANGED = 1,
            TALENTS_INVOLUNTARILY_RESET = 1
        }        local function CheckForTalentUpdate( event )
            local specialization = GetSpecialization()
            local specID = specialization and GetSpecializationInfo( specialization )
            
            -- MoP Classic: Use our enhanced spec detection if needed
            if not specID then
                specID = ns.getSpecializationID(specialization)
            end

            -- Don't trigger spec change if we already have a valid detection
            -- or if our fallback would produce the same result
            if specID and state.spec.id then
                -- Try our enhanced detection to see what it would return
                local enhancedSpecID = Hekili and Hekili.GetMoPSpecialization and Hekili:GetMoPSpecialization()
                
                -- Only trigger change if both basic detection and enhanced detection disagree with current state
                if enhancedSpecID and enhancedSpecID ~= state.spec.id and specID ~= state.spec.id then
                    Hekili.PendingSpecializationChange = true
                elseif not enhancedSpecID and specID ~= state.spec.id then
                    -- Fallback case if enhanced detection isn't available
                    Hekili.PendingSpecializationChange = true
                end
            elseif specID and not state.spec.id then
                -- No current spec, so trigger detection
                Hekili.PendingSpecializationChange = true
            end
        end

        RegisterEvent( "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", CheckForTalentUpdate )

        for event in pairs( specializationEvents ) do
            RegisterEvent( event, CheckForTalentUpdate )
        end
    end
end


do
    local function UpdateZoneInfo()
        local _, zone, _, _, _, _, _, instanceID = GetInstanceInfo()
        state.bg = zone == "pvp"
        state.arena = zone == "arena"
        
        state.instance_id = instanceID or -1
    end

    RegisterEvent( "ZONE_CHANGED", UpdateZoneInfo )
    RegisterEvent( "ARENA_PREP_OPPONENT_SPECIALIZATIONS", UpdateZoneInfo )
end


-- Hide when going into the barbershop.
RegisterEvent( "BARBER_SHOP_OPEN", function ()
    Hekili.Barber = true
end )

RegisterEvent( "BARBER_SHOP_CLOSE", function ()
    Hekili.Barber = false
end )


-- Update visibility when getting on/off a taxi.
RegisterEvent( "PLAYER_CONTROL_LOST", function ()
    Hekili:After( 0.1, Hekili.UpdateDisplayVisibility, Hekili )
end )

RegisterEvent( "PLAYER_CONTROL_GAINED", function ()
    Hekili:After( 0.1, Hekili.UpdateDisplayVisibility, Hekili )
end )


function ns.updateTalents()
    if type(state.talent) ~= "table" then state.talent = {} end
    if type(class.talents) ~= "table" then class.talents = {} end
    for k, _ in pairs( state.talent ) do
        state.talent[ k ].enabled = false
    end

    -- local specGroup = GetSpecialization()

    for k, v in pairs( class.talents ) do
        local enabled, name, sID, known
        
        -- Use our local talent detection function instead of global override
        _, name, _, enabled, _, sID, _, _, _, _, known = HekiliGetTalentInfoByID( v, 1 )

        if not name then
            -- We probably used a spellID.
            if v and type(v) == "number" and v > 0 then
                enabled = IsPlayerSpell( v )
            end
        end

        if rawget( state.talent, k ) then
            state.talent[ k ].enabled = enabled
        else
            state.talent[ k ] = { enabled = enabled }
        end
    end

    if type(state.pvptalent) ~= "table" then state.pvptalent = {} end
    if type(class.pvptalents) ~= "table" then class.pvptalents = {} end
    for k, _ in pairs( state.pvptalent ) do
        state.pvptalent[ k ]._enabled = false
    end
    for k, v in pairs( class.pvptalents ) do
        -- MoP: GetPvpTalentInfoByID doesn't exist, use IsPlayerSpell fallback
        local enabled = false
        
        if GetPvpTalentInfoByID then
            local _, name, _, enabled, _, sID, _, _, _, known = GetPvpTalentInfoByID( v, 1 )
            if not name then
                enabled = IsPlayerSpell( v )
            end
            enabled = enabled or known
        else
            -- MoP: PvP talents don't exist, check if it's a known spell
            enabled = IsPlayerSpell( v )
        end

        if rawget( state.pvptalent, k ) then
            state.pvptalent[ k ]._enabled = enabled
        else
            state.pvptalent[ k ] = {
                _enabled = enabled
            }
        end
    end

    ResetDisabledGearAndSpells()
end


-- TBD:  Consider making `boss' a check to see whether the current unit is a boss# unit instead.
RegisterEvent( "ENCOUNTER_START", function ( _, id, name, difficulty, groupSize )
    state.encounterID = id
    state.encounterName = name
    state.encounterDifficulty = difficulty
    state.encounterSize = groupSize
end )

RegisterEvent( "ENCOUNTER_END", function ()
    state.encounterID = 0
    state.encounterName = "None"
    state.encounterDifficulty = 0
    state.encounterSize = 0
end )





do
    local function itemSorter( a, b )
        local abA = class.abilities[ a.action ]
        local abB = class.abilities[ b.action ]

        if not abA and not abB then return false end
        if not abA then return false end
        if not abB then return true end

        local action1, action2 = abA.cooldown, abB.cooldown
        return action1 > action2
    end

    local function buildUseItemsList()
        local itemList = class.itemPack.lists.items
        wipe( itemList )

        if #state.items > 0 then
            for i, item in ipairs( state.items ) do
                if not Hekili:IsItemScripted( item ) then
                    insert( itemList, {
                        action = item,
                        enabled = true,
                        criteria = "( ! settings.boss || boss ) & " ..
                            "( settings.targetMin = 0 || active_enemies >= settings.targetMin ) & " ..
                            "( settings.targetMax = 0 || active_enemies <= settings.targetMax )"
                    } )
                end
            end
        end        sort( itemList, itemSorter )

        Hekili:LoadItemScripts()
    end

    function Hekili:UpdateUseItems()
        if not Hekili.PLAYER_ENTERING_WORLD then
            Hekili:After( 1, buildUseItemsList )
            return
        end

        buildUseItemsList()
    end


    local GearHooks = {}

    -- This is a simple way to separate expansion-based gear into separate systems.
    function Hekili:RegisterGearHook( r, u )
        insert( GearHooks, {
            reset = r,
            update = u
        } )
    end    local wasWearing = {}
    -- MoP: Use legacy item slot constant
    local maxItemSlot = Hekili.IsWrath() and INVSLOT_LAST_EQUIPPED or 19 -- INVSLOT_LAST_EQUIPPED = 19 in MoP

    local timer

    local function Update()
        ns.updateGear()
    end

    local function QueueUpdate()
        if timer and not timer:IsCancelled() then timer:Cancel() end
        timer = Hekili:After( 1, Update )
    end    function ns.updateGear()
        if not Hekili.PLAYER_ENTERING_WORLD then
            QueueUpdate()
            return
        end        -- Ensure critical state tables are initialized
        if not state.swings then
            state.swings = {
                mh_actual = 0,
                mh_speed = 2.6,
                mh_projected = 2.6,
                oh_actual = 0,
                oh_speed = 2.6,
                oh_projected = 3.9
            }
        end

        if not state.equipped then state.equipped = {} end
        if not state.trinket then state.trinket = {} end
        if not state.trinket.main_hand then 
            state.trinket.main_hand = {
                slot = "main_hand",
                __proc = false,
                cooldown = nil
            } 
        end
        if not state.trinket.t1 then 
            state.trinket.t1 = {
                slot = "t1",
                __proc = false,
                cooldown = nil
            } 
        end
        if not state.trinket.t2 then 
            state.trinket.t2 = {
                slot = "t2",
                __proc = false,
                cooldown = nil
            } 
        end

        if type(state.set_bonus) ~= "table" then state.set_bonus = {} else wipe( state.set_bonus ) end

        for _, hook in ipairs( GearHooks ) do
            if hook.reset then hook.reset() end
        end

        if type(wasWearing) ~= "table" then wasWearing = {} else wipe( wasWearing ) end


        if type(state.items) == "table" then
            for i, item in ipairs( state.items ) do
                wasWearing[ i ] = item
            end
        end

        if type(state.items) ~= "table" then state.items = {} else wipe( state.items ) end

        for set, items in pairs( class.gear ) do
            state.set_bonus[ set ] = 0
            for item, _ in pairs( items ) do
                if type(item) == "number" and item > maxItemSlot and IsEquippedItemLocal( item ) then
                    state.set_bonus[ set ] = state.set_bonus[ set ] + 1
                end
            end
        end

        for bonus, aura in pairs( class.setBonuses ) do
            if UA_GetPlayerAuraBySpellID( aura ) then
                state.set_bonus[ bonus ] = 1
            end
        end

        -- Trinkets
        -- We want to know:
        -- 1. Which trinket?
        -- 2. Does it have a spell?  (GetItemSpell)
        -- 3. Does it have an on-use?  (IsItemUsable)
    -- 4. ???
    local T1 = GetInventoryItemID( "player", 13 )

        if not state.trinket then state.trinket = {} end
        if not state.trinket.t1 then state.trinket.t1 = {} end
        if not state.trinket.t2 then state.trinket.t2 = {} end

        state.trinket.t1.__id = 0
        state.trinket.t1.ilvl = 0
        state.trinket.t1.__ability = "null_cooldown"
        state.trinket.t1.__usable = false
        state.trinket.t1.__has_use_buff = false
        state.trinket.t1.__use_buff_duration = nil

        if T1 then
            state.trinket.t1.__id = T1
            -- So this isn't *truly* accurate, but it's accurate relatively speaking.
            state.trinket.t1.ilvl = GetDetailedItemLevelInfo( T1 )

            local isUsable = IsUsableItem( T1 )
            local name, spellID = GetItemSpell( T1 )
            local tSpell = class.itemMap[ T1 ]            if tSpell then
                class.abilities.trinket1 = class.abilities[ tSpell ]
                if class.specs and class.specs[0] then
                    class.specs[ 0 ].abilities.trinket2 = class.abilities[ tSpell ]
                end

                state.trinket.t1.__usable = isUsable
                state.trinket.t1.__ability = tSpell

                local ability = class.abilities[ tSpell ]
                local aura = ability and class.auras[ ability.self_buff or spellID ]                if spellID and SpellIsSelfBuff( spellID ) and aura then
                    state.trinket.t1.__has_use_buff = not aura.ignore_buff and not ( ability and ability.proc and ( ability.proc == "damage" or ability.proc == "healing" or ability.proc == "mana" or ability.proc == "absorb" or ability.proc == "speed" ) )
                    state.trinket.t1.__use_buff_duration = aura.duration > 0 and aura.duration or 0.01
                elseif ability and ability.self_buff then
                    state.trinket.t1.__has_use_buff = not aura.ignore_buff and not ( ability and ability.proc and ( ability.proc == "damage" or ability.proc == "healing" or ability.proc == "mana" or ability.proc == "absorb" or ability.proc == "speed" ) )
                    state.trinket.t1.__use_buff_duration = aura and aura.duration > 0 and aura.duration or 0.01
                end                if not isUsable then
                    if state.cooldown then
                        state.trinket.t1.cooldown = state.cooldown.null_cooldown
                    end
                else
                    if state.cooldown then
                        state.cooldown.trinket1 = ability and state.cooldown[ ability.key ] or state.cooldown.null_cooldown
                        state.trinket.t1.cooldown = state.cooldown.trinket1
                    end
                end
            else
                class.abilities.trinket1 = class.abilities.actual_trinket1
                if class.specs and class.specs[0] then
                    class.specs[ 0 ].abilities.trinket1 = class.abilities.actual_trinket1
                end
                if state.cooldown then
                    state.trinket.t1.cooldown = state.cooldown.null_cooldown
                end
            end

            state.trinket.t1.__proc = FindStringInInventoryItemTooltip( "^" .. ITEM_SPELL_TRIGGER_ONEQUIP, 13, true, true )
        end

        local T2 = GetInventoryItemID( "player", 14 )

        state.trinket.t2.__id = 0
        state.trinket.t2.__ability = "null_cooldown"
        state.trinket.t2.__usable = false
        state.trinket.t2.__has_use_buff = false
        state.trinket.t2.__use_buff_duration = nil
        state.trinket.t2.ilvl = 0

        if T2 then
            state.trinket.t2.__id = T2
             -- So this isn't *truly* accurate, but it's accurate relatively speaking.
             state.trinket.t2.ilvl = GetDetailedItemLevelInfo( T2 )

            local isUsable = IsUsableItem( T2 )
            local name, spellID = GetItemSpell( T2 )
            local tSpell = class.itemMap[ T2 ]            if tSpell then
                class.abilities.trinket2 = class.abilities[ tSpell ]
                if class.specs and class.specs[0] then
                    class.specs[ 0 ].abilities.trinket2 = class.abilities[ tSpell ]
                end

                state.trinket.t2.__usable = isUsable
                state.trinket.t2.__ability = tSpell                local ability = class.abilities[ tSpell ]
                local aura = ability and class.auras[ ability.self_buff or spellID ]

                if spellID and SpellIsSelfBuff( spellID ) and aura then
                    state.trinket.t2.__has_use_buff = not aura.ignore_buff and not ( ability and ability.proc and ( ability.proc == "damage" or ability.proc == "healing" or ability.proc == "mana" or ability.proc == "absorb" or ability.proc == "speed" ) )
                    state.trinket.t2.__use_buff_duration = aura.duration > 0 and aura.duration or 0.01
                elseif ability and ability.self_buff then
                    state.trinket.t2.__has_use_buff = true
                    state.trinket.t2.__use_buff_duration = aura and aura.duration > 0 and aura.duration or 0.01
                end                if not isUsable then
                    if state.cooldown then
                        state.trinket.t2.cooldown = state.cooldown.null_cooldown
                    end
                else
                    if state.cooldown then
                        state.cooldown.trinket2 = ability and state.cooldown[ ability.key ] or state.cooldown.null_cooldown
                        state.trinket.t2.cooldown = state.cooldown.trinket2
                    end
                end            else
                class.abilities.trinket2 = class.abilities.actual_trinket2
                if class.specs and class.specs[0] then
                    class.specs[ 0 ].abilities.trinket2 = class.abilities.actual_trinket2
                end
                if state.cooldown then
                    state.trinket.t2.cooldown = state.cooldown.null_cooldown
                end
            end            state.trinket.t2.__proc = FindStringInInventoryItemTooltip( "^" .. ITEM_SPELL_TRIGGER_ONEQUIP, 14, true, true )
        end

        -- Initialize weapon slots if they don't exist
        if not state.main_hand then state.main_hand = {} end
        if not state.off_hand then state.off_hand = {} end
        
        state.main_hand.size = 0
        state.off_hand.size = 0

        local MH = GetInventoryItemID( "player", 16 )

        class.abilities.main_hand = class.abilities.actual_main_hand

        if MH then
            local isUsable = IsUsableItem( MH )
            local name, spellID = GetItemSpell( MH )
            local tSpell = class.itemMap[ MH ]
            local ability = class.abilities[ tSpell ]            if ability and tSpell then
                class.abilities.main_hand = class.abilities[ tSpell ]
                if class.specs and class.specs[0] then
                    class.specs[ 0 ].abilities.main_hand = class.abilities[ tSpell ]
                end

                local aura = ability and class.auras[ ability.self_buff or spellID ]

                if spellID and SpellIsSelfBuff( spellID ) and aura then
                    state.trinket.main_hand.__has_use_buff = not aura.ignore_buff and not ( ability and ability.proc and ( ability.proc == "damage" or ability.proc == "healing" or ability.proc == "mana" or ability.proc == "absorb" or ability.proc == "speed" ) )
                    state.trinket.main_hand.__use_buff_duration = aura.duration > 0 and aura.duration or 0.01
                elseif ability.self_buff then
                    state.trinket.main_hand.__has_use_buff = true
                    state.trinket.main_hand.__use_buff_duration = aura and aura.duration > 0 and aura.duration or 0.01
                end

                if not isUsable then
                    state.trinket.main_hand.cooldown = state.cooldown.null_cooldown                else
                    if state.cooldown and ability and ability.key then
                        state.cooldown.main_hand = state.cooldown[ ability.key ]
                        if state.trinket and state.trinket.main_hand then
                            state.trinket.main_hand.cooldown = state.cooldown.main_hand
                        end
                    end
                end
            else
                class.abilities.main_hand = class.abilities.actual_main_hand
                if class.specs and class.specs[0] then
                    class.specs[ 0 ].abilities.main_hand = class.abilities.actual_main_hand
                end
                if state.trinket and state.trinket.main_hand and state.cooldown then
                    state.trinket.main_hand.cooldown = state.cooldown.null_cooldown
                end            end

            if state.trinket and state.trinket.main_hand then
                state.trinket.main_hand.__proc = FindStringInInventoryItemTooltip( "^" .. ITEM_SPELL_TRIGGER_ONEQUIP, 16, true, true )
            end
        end

        for i = 1, 19 do
            local item = GetInventoryItemID( "player", i )

            if item then
                state.set_bonus[ item ] = 1
                local key, _, _, _, _, _, _, _, equipLoc = CGetItemInfo( item )
                if key then
                    key = formatKey( key )
                    state.set_bonus[ key ] = 1
                end

                if i == 16 then
                    if equipLoc == "INVTYPE_2HWEAPON" then
                        state.main_hand.size = 2
                    elseif equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then
                        state.main_hand.size = 1
                    elseif equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" then
                        state.set_bonus.ranged = 1
                    end
                elseif i == 17 then
                    if equipLoc == "INVTYPE_2HWEAPON" then
                        state.off_hand.size = 2
                    elseif equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND" then
                        state.off_hand.size = 1
                    elseif equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" then
                        state.set_bonus.ranged = 1
                    elseif equipLoc == "INVTYPE_SHIELD" then
                        state.set_bonus.shield = 1
                    end
                end



                -- Fire any/all GearHooks (may be expansion-driven).
                for _, hook in ipairs( GearHooks ) do
                    if hook.update then hook.update( i, item ) end
                end

                local usable = class.itemMap[ item ]
                if usable then insert( state.items, usable ) end
            end
        end        -- Improve Pocket-Sized Computronic Device.
        -- MoP: This item doesn't exist in MoP, skip this section
        --[[ 
        if state.equipped.pocketsized_computation_device then
            local tName = CGetItemInfo( 167555 )
            -- MoP: C_Item.GetItemGem not available, skip gem detection
            local redName, redLink = nil, nil

            if redName and redLink then
                local redID = tonumber( redLink:match("item:(%d+)") )
                local action = class.itemMap[ redID ]

                if action and class.abilities[ action ] and redID then
                    state.set_bonus[ action ] = 1
                    state.set_bonus[ redID ] = 1
                    class.abilities.pocketsized_computation_device = class.abilities[ action ]
                    class.abilities[ tName ] = class.abilities[ action ]
                    insert( state.items, action )
                end
            else                if class.abilities.inactive_red_punchcard then
                    class.abilities.pocketsized_computation_device = class.abilities.inactive_red_punchcard
                    class.abilities[ tName ] = class.abilities.inactive_red_punchcard
                end
            end
        end
        --]]
        
        -- MoP: updatePowers is a retail-only function, not needed in MoP
        -- ns.updatePowers()
        ns.updateTalents()

        local sameItems = #wasWearing == #state.items

        if sameItems then
            for i = 1, #state.items do
                if wasWearing[i] ~= state.items[i] then
                    sameItems = false
                    break
                end
            end
        end

        Hekili:UpdateUseItems()
        state.swings.mh_speed, state.swings.oh_speed = UnitAttackSpeed( "player" )
    end

    RegisterEvent( "PLAYER_EQUIPMENT_CHANGED", QueueUpdate )
end


do
    local timer

    local function Update()
        ns.updateTalents()
    end

    local function QueueUpdate()
        if timer and not timer:IsCancelled() then timer:Cancel() end
        timer = Hekili:After( 0.5, Update )
    end    local talentEvents = {
        -- MoP: Modern trait/combat config events don't exist, use classic events
        "PLAYER_TALENT_UPDATE",
        "PLAYER_ALIVE",
        "PLAYER_UNGHOST"
    }

    for _, event in pairs( talentEvents ) do
        RegisterEvent( event, QueueUpdate )
    end
end





local last_combat, combat_ended = 0, 0
local COMBAT_RESUME_TIME = 5

RegisterEvent( "PLAYER_REGEN_DISABLED", function( event )
    local t = GetTime()

    if t - combat_ended <= COMBAT_RESUME_TIME then
        state.combat = last_combat
    else
        state.combat = GetTime() - 0.01
    end

    if Hekili.Config and not LibStub( "AceConfigDialog-3.0" ).OpenFrames[ "Hekili" ] then
        ns.StopConfiguration()
        Hekili:UpdateDisplayVisibility()
    end

    -- Hekili:ExpireTTDs( true )
    Hekili:ForceUpdate( event ) -- Force update on entering combat since OOC refresh can be very slow (0.5s).
end )


RegisterEvent( "PLAYER_REGEN_ENABLED", function ()
    last_combat = state.combat
    combat_ended = GetTime()    state.combat = 0

    if state.swings then
        state.swings.mh_actual = 0
        state.swings.oh_actual = 0
    end

    Hekili:After( 5, function ()
        if not InCombatLockdown() then
            ns.Audit( "combatExit" )
        end
    end )

    Hekili:ReleaseHolds( true )
    Hekili:UpdateDisplayVisibility()
end )


local dynamic_keys = setmetatable( {}, {
    __index = function( t, k )
        local name = GetSpellInfo( k )
        local key = name and formatKey( name ) or k
        t[k] = key
        return t[k]
    end
} )


ns.castsOff = { 'no_action', 'no_action', 'no_action', 'no_action', 'no_action' }
ns.castsOn = { 'no_action', 'no_action', 'no_action', 'no_action', 'no_action' }
ns.castsAll = { 'no_action', 'no_action', 'no_action', 'no_action', 'no_action' }

local castsOn, castsOff, castsAll = ns.castsOn, ns.castsOff, ns.castsAll


function state:AddToHistory( spellID, destGUID )
    local ability = class.abilities[ spellID ]
    local key = ability and ability.key or dynamic_keys[ spellID ]

    local now = GetTime()
    local player = self.player

    player.lastcast = key
    player.casttime = now

    if ability then
        local history = self.prev.history
        insert( history, 1, key )
        history[6] = nil

        if ability.gcd ~= "off" then
            history = self.prev_gcd.history
            player.lastgcd = key
            player.lastgcdtime = now
        else
            history = self.prev_off_gcd.history
            player.lastoffgcd = key
            player.lastoffgcdtime = now
        end
        insert( history, 1, key )
        history[6] = nil

        ability.realCast = now
        ability.realUnit = destGUID
    end
end


local SpellQueueWindow = 0.4

local function UpdateSpellQueueWindow( event, variable, value )
    if variable == "SpellQueueWindow" then
        SpellQueueWindow = ( tonumber( value ) or 400 ) / 1000
    end
end

RegisterEvent( "CVAR_UPDATE", UpdateSpellQueueWindow )
RegisterEvent( "VARIABLES_LOADED", UpdateSpellQueueWindow )

Hekili:After( 60, UpdateSpellQueueWindow )


do
    local box, text
    local info = {}

    hooksecurefunc( "ChatEdit_SendText", function( b )
        if box and box == b and text then
            local action, target = SecureCmdOptionParse( text )
            local ability = action and class.abilities[ action ]

            if ability and ability.key then
                local m = info[ ability.key ] or {}

                m.target = UnitGUID( target or "target" )
                m.time   = GetTime()

                info[ ability.key ] = m
            end

            text = nil
            return
        end

        if not box and b ~= DEFAULT_CHAT_FRAME.editBox then
            box = b

            box:HookScript( "OnTextSet", function( self )
                local t = self:GetText()
                if t and t ~= "" then text = t end
            end )
        end
    end )

    function Hekili:GetMacroCastTarget( spell, castTime, source )
        local ability = class.abilities[ spell ]
        local buffer = 0.1 + SpellQueueWindow

        if ability and ability.key then
            local m = info[ ability.key ]

            if m and abs( castTime - m.time ) < buffer then
                return m.target -- This is a GUID.
            end
        end
    end
end


local lowLevelWarned = false
local noClassWarned = false

-- Need to make caching system.
RegisterUnitEvent( "UNIT_SPELLCAST_SUCCEEDED", "player", "target", function( event, unit, _, spellID )
    if not noClassWarned and not class.initialized then
        Hekili:Notify( UnitClass( "player" ) .. " does not have any Hekili modules loaded (yet).\nWatch for updates.", 5 )
        noClassWarned = true
    elseif not lowLevelWarned and UnitLevel( "player" ) < 70 then
        Hekili:Notify( "Hekili is designed for current content.\nUse below level 70 at your own risk.", 5 )
        lowLevelWarned = true
    end

    if unit == "player" and class and class.abilities then
        local ability = class.abilities[ spellID ]

        if ability then
            Hekili:ForceUpdate( event )
            if state.holds[ ability.key ] then Hekili:RemoveHold( ability.key, true ) end
        end
    end
end )


RegisterUnitEvent( "UNIT_SPELLCAST_START", "player", "target", function( event, unit, cast, spellID )
    if unit == "player" and class and class.abilities then
        local ability = class.abilities[ spellID ]
        if ability then
            Hekili:ForceUpdate( event )
            if state.holds[ ability.key ] then Hekili:RemoveHold( ability.key, true ) end
        end

        Hekili:ForceUpdate( event, true )
    end
end )


-- Empowerment events removed (not available in MoP)


RegisterUnitEvent( "UNIT_SPELLCAST_CHANNEL_START", "player", nil, function( event, unit, cast, spellID )
    if class and class.abilities then
        local ability = class.abilities[ spellID ]

        if ability then
            Hekili:ForceUpdate( event )
            if state.holds[ ability.key ] then Hekili:RemoveHold( ability.key, true ) end
        end
    end
end )


RegisterUnitEvent( "UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, function( event, unit, cast, spellID )
    if class and class.abilities then
        local ability = class.abilities[ spellID ]
        if ability then
            Hekili:ForceUpdate( event )
            if state.holds[ ability.key ] then Hekili:RemoveHold( ability.key, true ) end
        end
    end
end )


RegisterUnitEvent( "UNIT_SPELLCAST_STOP", "player", nil, function( event, unit, cast, spellID )
    if class and class.abilities then
        local ability = class.abilities[ spellID ]
        if ability then
            Hekili:ForceUpdate( event )
            if state.holds[ ability.key ] then Hekili:RemoveHold( ability.key, true ) end
        end
    end
end )


RegisterUnitEvent( "UNIT_SPELLCAST_DELAYED", "player", nil, function( event, unit, _, spellID )
    if not class or not class.abilities then return end
    local ability = class.abilities[ spellID ]

    if ability then
        local action = ability.key
        local _, _, _, start, finish = UnitCastingInfo( "player" )
        local target = select( 5, state:GetEventInfo( action, nil, nil, "CAST_FINISH", nil, true ) )

        state:RemoveSpellEvent( action, true, "CAST_FINISH" )
        state:RemoveSpellEvent( action, true, "PROJECTILE_IMPACT", true )

        if start and finish then
            if not target then target = Hekili:GetMacroCastTarget( action, start / 1000, "DELAYED" ) end
            state:QueueEvent( action, start / 1000, finish / 1000, "CAST_FINISH", target, true )

            if ability.isProjectile then
                local travel

                if ability.flightTime then
                    travel = ability.flightTime

                elseif target then
                    local u = Hekili:GetUnitByGUID( target ) or Hekili:GetNameplateUnitForGUID( target ) or "target"                    if u then
                        local _, maxR
                        if RC and RC.GetRange then
                            _, maxR = RC:GetRange( u )
                        end
                        maxR = maxR or select( 6, GetSpellInfo( ability.id ) ) or 40
                        travel = maxR / ability.velocity
                    end
                end

                if not travel then
                    travel = ( select( 6, GetSpellInfo( ability.id ) ) or 40 ) / ability.velocity
                end

                state:QueueEvent( ability.impactSpell or ability.key, finish / 1000, 0.05 + travel, "PROJECTILE_IMPACT", target, true )
            end
        end

        Hekili:ForceUpdate( event )
    end
end )


-- TODO:  This should be changed to stash this information and then commit it on next UNIT_SPELLCAST_START or UNIT_SPELLCAST_SUCCEEDED.
RegisterEvent( "UNIT_SPELLCAST_SENT", function ( event, unit, target_name, castID, spellID )
    Hekili:ForceUpdate( event )

    if target_name and UnitGUID( target_name ) then
        state.cast_target = UnitGUID( target_name )
        return
    end

    local gubn = Hekili:GetUnitByName( target_name )
    if gubn and UnitGUID( gubn ) then
        state.cast_target = UnitGUID( gubn )
        return
    end

    if UnitName( "target" ) == target_name then
        state.cast_target = UnitGUID( "target" )
        return
    end

    state.cast_target = nil
end )


--[[ This event is too spammy.
RegisterEvent( "CURRENT_SPELL_CAST_CHANGED", function( event, cancelled )
    Hekili:ForceUpdate( event, true )
end ) ]]


--[[ Update due to player totems.
RegisterEvent( "PLAYER_TOTEM_UPDATE", function( event )
    Hekili:ForceUpdate( event )
end ) -- TODO:  Re-evaluate whether this is necessary to force a faster update. ]]


local power_tick_data = {
    focus_avg = 0.10,
    focus_ticks = 1,

    energy_avg = 0.10,
    energy_ticks = 1,
}


local spell_names = setmetatable( {}, {
    __index = function( t, k )
        t[ k ] = GetSpellInfo( k )
        return t[ k ]
    end
} )


local lastPower = {}

local function UNIT_POWER_FREQUENT( event, unit, power )

    if power == "FOCUS" and rawget( state, "focus" ) then
        local now = GetTime()
        local elapsed = now - ( state.focus.last_tick or 0 )

        elapsed = elapsed > power_tick_data.focus_avg * 1.5 and power_tick_data.focus_avg or elapsed

        if elapsed > 0.075 then
            power_tick_data.focus_avg = ( elapsed + ( power_tick_data.focus_avg * power_tick_data.focus_ticks ) ) / ( power_tick_data.focus_ticks + 1 )
            power_tick_data.focus_ticks = power_tick_data.focus_ticks + 1
            state.focus.last_tick = now
        end

    elseif power == "ENERGY" and rawget( state, "energy" ) then
        local now = GetTime()
        local elapsed = min( 0.12, now - ( state.energy.last_tick or 0 ) )

        elapsed = elapsed > power_tick_data.energy_avg * 1.5 and power_tick_data.energy_avg or elapsed

        if elapsed > 0.075 then
            power_tick_data.energy_avg = ( elapsed + ( power_tick_data.energy_avg * power_tick_data.energy_ticks ) ) / ( power_tick_data.energy_ticks + 1 )
            power_tick_data.energy_ticks = power_tick_data.energy_ticks + 1
            state.energy.last_tick = now
        end
    end

    -- MoP: Use legacy power type constants
    local powerType = tonumber(power) or 0
    if power == "Mana" then powerType = 0
    elseif power == "Rage" then powerType = 1
    elseif power == "Focus" then powerType = 2
    elseif power == "Energy" then powerType = 3
    elseif power == "Chi" then powerType = 12 -- MoP introduced Chi
    elseif power == "RunicPower" then powerType = 6
    elseif power == "SoulShards" then powerType = 7
    elseif power == "LunarPower" then powerType = 8
    elseif power == "HolyPower" then powerType = 9
    elseif power == "Maelstrom" then powerType = 11
    end
    
    local newPower = UnitPower( "player", powerType )

    if lastPower[ power ] and newPower < lastPower[ power ] then
        Hekili:ForceUpdate( event, true )
    end

    lastPower[ power ] = newPower
end
Hekili:ProfileCPU( "UNIT_POWER_FREQUENT", UNIT_POWER_FREQUENT )

RegisterUnitEvent( "UNIT_POWER_FREQUENT", "player", nil, UNIT_POWER_FREQUENT )


local autoAuraKey = setmetatable( {}, {
    __index = function( t, k )
        local name = GetSpellInfo( k )
        local key = name and formatKey( name ) or k

        if class.auras[ key ] then
            local i = 1

            while ( true ) do
                local new = key .. '_' .. i

                if not class.auras[ new ] then
                    key = new
                    break
                end

                i = i + 1
            end
        end

        -- Enhanced aura registration for APL compatibility
        -- Store the aura and save the key if we can.
        if ns.addAura then
            ns.addAura( key, k, 'name', name )
            t[k] = key
            
            -- Enhanced aura tracking for important auras
            if class.auras[ key ] and (class.auras[ key ].important or class.auras[ key ].tracking) then
                Hekili:ForceUpdate( "AURA_REGISTERED", true )
            end
        end

        return t[k]
    end
} )


do
    local playerInstances = {}
    local targetInstances = {}    local instanceDB    -- MoP: C_UnitAuras doesn't exist, create fallbacks
    local GetAuraDataByAuraInstanceID = function() return nil end
    local ForEachAura = function() return nil end

    local function StoreInstanceInfo( aura )
        local id = aura.spellId
        local model = class.auras[ id ]

        instanceDB[ aura.auraInstanceID ] = aura.isBossAura or aura.isStealable or model and ( model.shared or model.used and aura.isFromPlayerOrPlayerPet )
    end    RegisterUnitEvent( "UNIT_AURA", "player", "target", function( event, unit )
        -- Cataclysm-style UNIT_AURA handling - simple and direct
        state[ unit ].updated = true
        Hekili:ForceUpdate( event, true )
    end )    RegisterEvent( "PLAYER_TARGET_CHANGED", function( event )
        state.target.updated = true
        Hekili:ForceUpdate( event, true )
    end )
end



do
    local MOVEMENT_ICD = 0.5

    local lastStart = 0
    local lastEnd = 0

    RegisterEvent( "PLAYER_STARTED_MOVING", function( event )
        local now = GetTime()

        if now - lastStart > MOVEMENT_ICD then
            lastStart = now
            Hekili:ForceUpdate( event )
        end
    end )


    RegisterEvent( "PLAYER_STOPPED_MOVING", function( event )
        local now = GetTime()

        if now - lastEnd > MOVEMENT_ICD then
            lastEnd = now
            Hekili:ForceUpdate( event )
        end
    end )
end


local cast_events = {
    SPELL_CAST_START        = true,
    SPELL_CAST_FAILED       = true,
    SPELL_CAST_SUCCESS      = true,
    SPELL_DAMAGE            = true,
    SPELL_AURA_REMOVED      = true
}


local aura_events = {
    SPELL_AURA_APPLIED      = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REFRESH      = true,
    SPELL_AURA_REMOVED      = true,
    SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_BROKEN       = true,
    SPELL_AURA_BROKEN_SPELL = true,
    SPELL_CAST_SUCCESS      = true -- it appears you can refresh stacking buffs w/o a SPELL_AURA_x event.
}


local dmg_events = {
    SPELL_DAMAGE            = true,
    SPELL_MISSED            = true,
    SPELL_PERIODIC_DAMAGE   = true,
    SPELL_PERIODIC_MISSED   = true,
    SWING_DAMAGE            = true,
    SWING_MISSED            = true,
    RANGE_DAMAGE            = true,
    RANGE_MISSED            = true,
    ENVIRONMENTAL_DAMAGE    = true,
    ENVIRONMENTAL_MISSED    = true
}


local direct_dmg_events = {
    SPELL_DAMAGE            = true,
    SPELL_MISSED            = true,
    SWING_DAMAGE            = true,
    SWING_MISSED            = true,
    RANGE_DAMAGE            = true,
    RANGE_MISSED            = true,
    ENVIRONMENTAL_DAMAGE    = true,
    ENVIRONMENTAL_MISSED    = true
}


local death_events = {
    UNIT_DIED               = true,
    UNIT_DESTROYED          = true,
    UNIT_DISSIPATES         = true,
    PARTY_KILL              = true,
    SPELL_INSTAKILL         = true,
}

local dmg_filtered = {
    [280705] = true, -- Laser Matrix.
    [450412] = true, -- Sentinel.
    [462952] = true, -- Squall Sailor's Citrine
}

-- Enhanced damage filtering for APL compatibility
local enhanced_dmg_filtered = {
    -- Add more filtered spells as needed for APL compatibility
    [280705] = true, -- Laser Matrix.
    [450412] = true, -- Sentinel.
    [462952] = true, -- Squall Sailor's Citrine
}


local function IsActuallyFriend( unit )
    if not IsInGroup() then return false end
    if not UnitIsPlayer( unit ) then return false end
    if UnitInRaid( unit ) or UnitInParty( unit ) then return true end
    return false
end


local countDamage = false
local countDots = false
local countPets = false


function Hekili:UpdateDamageDetectionForCLEU()
    local profile = self.DB.profile
    local spec = rawget( profile.specs, state.spec.id )

    countDamage = spec and spec.damage or false
    countDots = spec and spec.damageDots or false
    countPets = spec and spec.damagePets or false
end


-- Enhanced combat log event handler for better APL compatibility
-- Use dots/debuffs to count active targets.
-- Track dot power (until 6.0) for snapshotting.
-- Note that this was ported from an unreleased version of Hekili, and is currently only counting damaged enemies.
local function CLEU_HANDLER( event, timestamp, subtype, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, school, amount, interrupt, a, b, c, d, offhand, multistrike, ... )
    -- This is used by both RegisterCombatLogEvent( x ) and RegisterHook( "COMBAT_LOG_EVENT_UNFILTERED", x ).
    if ns.callHook then
        ns.callHook( "COMBAT_LOG_EVENT_UNFILTERED", timestamp, subtype, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, school, amount, interrupt, a, b, c, d, offhand, multistrike, ... )
    end

    if death_events[ subtype ] then
        if ns.isTarget( destGUID ) then
            ns.eliminateUnit( destGUID, true )
            -- Hekili:ForceUpdate( subtype )

        elseif ns.isMinion( destGUID ) then
            local npcid = destGUID:match("(%d+)-%x-$")
            npcid = npcid and tonumber( npcid )

            if npcid == state.pet.guardian_of_azeroth.id then
                state.pet.guardian_of_azeroth.summonTime = 0
            end

            ns.updateMinion( destGUID )
        end
        return
    end

    local time = GetTime()

    local amSource  = ( sourceGUID == state.GUID )
    local petSource = ( UnitExists( "pet" ) and sourceGUID == UnitGUID( "pet" ) )
    local amTarget  = ( destGUID   == state.GUID )
    local isSensePower = ( class.auras.sense_power_active and spellID == 361022 )

    if not InCombatLockdown() and not ( amSource or petSource or amTarget ) then return end

    if subtype == 'SPELL_SUMMON' and amSource then
        -- Guardian of Azeroth check.
        -- ID is 152396.
        local npcid = destGUID:match("(%d+)-%x-$")
        npcid = npcid and tonumber( npcid )

        if npcid == state.pet.guardian_of_azeroth.id then
            state.pet.guardian_of_azeroth.summonTime = time
        end

        ns.updateMinion( destGUID, time )
        return
    end

    local hostile = ( bit.band( destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY ) == 0 ) and not IsActuallyFriend( destName )

    if dmg_events[ subtype ] and not ( amSource or petSource ) and amTarget then
        local damage, damageType

        if subtype:sub( 1, 13 ) == "ENVIRONMENTAL" then
            damageType = 1

            if subtype:sub(-7) == "_DAMAGE" then
                damage = spellName

            elseif spellName == "ABSORB" then
                damage = amount

            end

        elseif subtype:sub( 1, 5 ) == "SWING" then
            damageType = 1

            if subtype == "SWING_DAMAGE" then
                damage = spellID

            else
                if spellID == "ABSORB" then
                    damage = interrupt
                end

            end

        else -- SPELL_x
            if subtype:find( "_MISSED" ) then
                if amount == "ABSORB" then
                    damage = a
                    damageType = school or 1
                end

            else
                damage = amount
                damageType = school

            end

        end

        if damage and damage > 0 then
            ns.storeDamage( time, damage, bit.band( damageType, 0x1 ) == 1 )
        end
    end    local minion = ns.isMinion( sourceGUID )

    if not ( amSource or petSource or isSensePower ) and not ( state.role and state.role.tank and destGUID == state.GUID ) and ( not minion or not countPets ) then
        return
    end

    if amSource then
        if cast_events[ subtype ] then
            local ability = class.abilities[ spellID ]

            if ability then
                if subtype == "SPELL_CAST_START" then
                    local _, _, _, start, finish = UnitCastingInfo( "player" )

                    if destGUID:len() == 0 then
                        destGUID = Hekili:GetMacroCastTarget( ability.key, GetTime(), "START" ) or UnitGUID( "target" )
                    end

                    if start then
                        state:QueueEvent( ability.key, start / 1000, finish / 1000, "CAST_FINISH", destGUID, true )

                        if ability.isProjectile then
                            local travel

                            if ability.flightTime then
                                travel = ability.flightTime                            elseif destGUID then
                                local unit = Hekili:GetUnitByGUID( destGUID ) or Hekili:GetNameplateUnitForGUID( destGUID ) or "target"

                                if unit then
                                    local _, maxR
                                    if RC and RC.GetRange then
                                        _, maxR = RC:GetRange( unit )
                                    end
                                    maxR = maxR or select( 6, GetSpellInfo( ability.id ) ) or 40
                                    travel = maxR / ability.velocity
                                end
                            end

                            if not travel then travel = ( select( 6, GetSpellInfo( ability.id ) ) or 40 ) / ability.velocity end

                            state:QueueEvent( ability.impactSpell or ability.key, finish / 1000, travel, "PROJECTILE_IMPACT", destGUID, true )
                        end
                    end

                elseif subtype == "SPELL_CAST_FAILED" then
                    if state:RemoveSpellEvent( ability.key, true, "CAST_FINISH" ) then -- remove next cast finish.
                        if ability.isProjectile then state:RemoveSpellEvent( ability.key, true, "PROJECTILE_IMPACT", true ) end -- remove last impact.
                    end
                    -- Hekili:ForceUpdate( "SPELL_CAST_FAILED" ) ]]

                elseif subtype == "SPELL_AURA_REMOVED" and ability.channeled then
                    state:RemoveSpellEvents( ability.key, true ) -- remove ticks, finish, impacts.
                    -- Hekili:ForceUpdate( "SPELL_AURA_REMOVED_CHANNEL" )

                elseif subtype == "SPELL_CAST_SUCCESS" then
                    state:RemoveSpellEvent( ability.key, true, "CAST_FINISH" ) -- remove next cast finish.

                    if ability.channeled then
                        local _, _, _, start, finish = UnitChannelInfo( "player" )

                        if destGUID:len() == 0 then
                            destGUID = Hekili:GetMacroCastTarget( ability.key, GetTime(), "START" ) or UnitGUID( "target" )
                        end

                        if start then
                            start = start / 1000
                            finish = finish / 1000

                            state:QueueEvent( ability.key, start, finish, "CHANNEL_FINISH", destGUID, true )

                            local tick_time = ability.tick_time or ( ability.aura and class.auras[ ability.aura ].tick_time )

                            if tick_time and tick_time > 0 then
                                local tick = tick_time

                                while ( start + tick < finish ) do
                                    state:QueueEvent( ability.key, start, start + tick, "CHANNEL_TICK", destGUID, true )
                                    tick = tick + tick_time
                                end
                            end
                        end
                    end

                    if ability.isProjectile and not state:IsInFlight( ability.key, true ) then
                        local travel

                        if ability.flightTime then
                            travel = ability.flightTime                        elseif destGUID then
                            local unit = Hekili:GetUnitByGUID( destGUID ) or Hekili:GetNameplateUnitForGUID( destGUID ) or "target"

                            if unit then
                                local _, maxR
                                if RC and RC.GetRange then
                                    _, maxR = RC:GetRange( unit )
                                end
                                maxR = maxR or select( 6, GetSpellInfo( ability.id ) ) or 40
                                travel = maxR / ability.velocity
                            end
                        end

                        if not travel then travel = state.target.maxR / ability.velocity end

                        state:QueueEvent( ability.impactSpell or ability.key, time, travel, "PROJECTILE_IMPACT", destGUID, true )
                    end

                    state:AddToHistory( ability.key, destGUID )

                elseif subtype == "SPELL_DAMAGE" then
                    -- Could be an impact.
                    if state:RemoveSpellEvent( ability.key, true, "PROJECTILE_IMPACT" ) then
                        RequestUpdate( "PROJECTILE_IMPACT" )
                    end
                end
            end

            state.gcd.lastStart = max( state.gcd.lastStart, ( GetSpellCooldown( 61304 ) ) )
            -- if subtype ~= "SPELL_DAMAGE" then Hekili:ForceUpdate( subtype, true ) end
        end
    end

    if state.role.tank and state.GUID == destGUID and subtype:sub(1,5) == 'SWING' and not IsActuallyFriend( sourceName ) then
        ns.updateTarget( sourceGUID, time, true )

    elseif subtype:sub( 1, 5 ) == 'SWING' and not multistrike then
        if subtype == 'SWING_MISSED' then offhand = spellName end

        local sw = state.swings

        if offhand and time > sw.oh_actual and sw.oh_speed then
            sw.oh_actual = time
            sw.oh_speed = select( 2, UnitAttackSpeed( 'player' ) ) or sw.oh_speed
            sw.oh_projected = sw.oh_actual + sw.oh_speed

        elseif not offhand and time > sw.mh_actual then
            sw.mh_actual = time
            sw.mh_speed = UnitAttackSpeed( 'player' ) or sw.mh_speed
            sw.mh_projected = sw.mh_actual + sw.mh_speed

        end

    -- Player/Minion Event
    elseif ( amSource or petSource or isSensePower ) or ( countPets and minion ) or ( sourceGUID == destGUID and sourceGUID == UnitGUID( 'target' ) ) then
        --[[ if aura_events[ subtype ] then
            if subtype == "SPELL_CAST_SUCCESS" or state.GUID == destGUID then
                if class.abilities[ spellID ] or class.auras[ spellID ] then
                    Hekili:ForceUpdate( subtype, true )
                end
            end

            if UnitGUID( 'target' ) == destGUID then
                if class.auras[ spellID ] then Hekili:ForceUpdate( subtype ) end
            end
        end ]]

        local aura = class.auras and class.auras[ spellID ]

        if aura then
            -- Enhanced aura tracking for better APL compatibility
            if hostile and sourceGUID ~= destGUID and not aura.friendly then
                -- Aura Tracking
                if subtype == 'SPELL_AURA_APPLIED' or subtype == 'SPELL_AURA_REFRESH' or subtype == 'SPELL_AURA_APPLIED_DOSE' then
                    ns.trackDebuff( spellID, destGUID, time, true )
                    if ( not minion or countPets ) and countDots then ns.updateTarget( destGUID, time, amSource, spellID ) end

                    -- Enhanced tracking for important debuffs
                    if aura.important or aura.tracking then
                        RequestUpdate( "SPELL_AURA_APPLIED" )
                        
                        -- Enhanced aura tracking for APL compatibility
                        if Hekili.DB.profile.enhancedEvents then
                            Hekili:TrackImportantAura(spellID, aura.key, aura.important, aura.tracking)
                            Hekili:UpdateAuraHistory(spellID, "APPLIED", {
                                destGUID = destGUID,
                                time = time,
                                source = amSource
                            })
                        end
                    end

                elseif subtype == 'SPELL_PERIODIC_DAMAGE' or subtype == 'SPELL_PERIODIC_MISSED' then
                    ns.trackDebuff( spellID, destGUID, time )
                    if countDots and ( not minion or countPets ) then
                        ns.updateTarget( destGUID, time, amSource )
                    end
                    
                    -- Enhanced periodic tracking for APL compatibility
                    if Hekili.DB.profile.enhancedEvents and (aura.important or aura.tracking) then
                        Hekili:UpdateAuraHistory(spellID, "PERIODIC", {
                            destGUID = destGUID,
                            time = time,
                            source = amSource,
                            damage = (subtype == 'SPELL_PERIODIC_DAMAGE') and amount or 0
                        })
                    end

                elseif destGUID and (subtype == 'SPELL_AURA_REMOVED' or subtype == 'SPELL_AURA_BROKEN' or subtype == 'SPELL_AURA_BROKEN_SPELL') then
                    ns.trackDebuff( spellID, destGUID )
                    
                    -- Enhanced friendly aura removal tracking for APL compatibility
                    if Hekili.DB.profile.enhancedEvents and (aura.important or aura.tracking) then
                        Hekili:UpdateAuraHistory(spellID, "FRIENDLY_REMOVED", {
                            destGUID = destGUID,
                            time = time,
                            source = amSource
                        })
                    end
                    
                    -- Enhanced removal tracking
                    if aura.important or aura.tracking then
                        RequestUpdate( "SPELL_AURA_REMOVED" )
                        
                        -- Enhanced aura tracking for APL compatibility
                        if Hekili.DB.profile.enhancedEvents then
                            Hekili:UpdateAuraHistory(spellID, "REMOVED", {
                                destGUID = destGUID,
                                time = time,
                                source = amSource
                            })
                        end
                    end

                end

            elseif ( amSource or petSource or isSensePower ) and aura.friendly then -- friendly effects
                if subtype == 'SPELL_AURA_APPLIED'  or subtype == 'SPELL_AURA_REFRESH' or subtype == 'SPELL_AURA_APPLIED_DOSE' then
                    ns.trackDebuff( spellID, destGUID, time, true )
                    
                    -- Enhanced friendly aura tracking for APL compatibility
                    if Hekili.DB.profile.enhancedEvents and (aura.important or aura.tracking) then
                        Hekili:TrackImportantAura(spellID, aura.key, aura.important, aura.tracking)
                        Hekili:UpdateAuraHistory(spellID, "FRIENDLY_APPLIED", {
                            destGUID = destGUID,
                            time = time,
                            source = amSource
                        })
                    end

                elseif subtype == 'SPELL_PERIODIC_HEAL' or subtype == 'SPELL_PERIODIC_MISSED' then
                    ns.trackDebuff( spellID, destGUID, time )
                    
                    -- Enhanced periodic heal tracking for APL compatibility
                    if Hekili.DB.profile.enhancedEvents and (aura.important or aura.tracking) then
                        Hekili:UpdateAuraHistory(spellID, "PERIODIC_HEAL", {
                            destGUID = destGUID,
                            time = time,
                            source = amSource,
                            healing = (subtype == 'SPELL_PERIODIC_HEAL') and amount or 0
                        })
                    end

                elseif destGUID and (subtype == 'SPELL_AURA_REMOVED' or subtype == 'SPELL_AURA_BROKEN' or subtype == 'SPELL_AURA_BROKEN_SPELL') then
                    ns.trackDebuff( spellID, destGUID )

                end

            end

        end

        if hostile and ( countDots and dmg_events[ subtype ] or direct_dmg_events[ subtype ] ) and not Hekili:IsEventFiltered( spellID, subtype ) then
            -- Enhanced damage tracking for better APL compatibility
            -- Don't wipe overkill targets in rested areas (it is likely a dummy).
            -- Interrupt is actually overkill.
            if not IsResting() and ( ( ( subtype == "SPELL_DAMAGE" or subtype == "SPELL_PERIODIC_DAMAGE" ) and interrupt > 0 ) or ( subtype == "SWING_DAMAGE" and spellName > 0 ) ) and ns.isTarget( destGUID ) then
                ns.eliminateUnit( destGUID, true )
                -- Enhanced overkill tracking
                Hekili:ForceUpdate( "SPELL_DAMAGE_OVERKILL", true )
            elseif not ( subtype == "SPELL_MISSED" and amount == "IMMUNE" ) then
                ns.updateTarget( destGUID, time, amSource, spellID )
                
                -- Enhanced damage tracking for important abilities
                if amSource and class.abilities[ spellID ] and class.abilities[ spellID ].important then
                    Hekili:ForceUpdate( "SPELL_DAMAGE_IMPORTANT", true )
                end
            end
        end
    end
end
Hekili:ProfileCPU( "CLEU_HANDLER", CLEU_HANDLER )
RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED", function ( event ) CLEU_HANDLER( event, CombatLogGetCurrentEventInfo() ) end )

-- Enhanced event system for better APL compatibility
-- Initialize damage detection settings when addon loads
RegisterEvent( "PLAYER_ENTERING_WORLD", function( event )
    Hekili:UpdateDamageDetectionForCLEU()
    
    -- Enhanced initialization for APL compatibility
    if Hekili.DB.profile.enhancedEvents then
        Hekili:ForceUpdate( "PLAYER_ENTERING_WORLD", true )
    end
end )

-- Update damage detection when spec changes
RegisterEvent( "PLAYER_SPECIALIZATION_CHANGED", function( event, unit )
    if unit == "player" then
        Hekili:UpdateDamageDetectionForCLEU()
        
        -- Enhanced spec change handling for APL compatibility
        if Hekili.DB.profile.enhancedEvents then
            Hekili:ForceUpdate( "PLAYER_SPECIALIZATION_CHANGED", true )
        end
    end
end )

-- Enhanced combat state tracking for APL compatibility
RegisterEvent( "PLAYER_REGEN_DISABLED", function( event )
    if Hekili.DB.profile.enhancedEvents then
        Hekili:ForceUpdate( "PLAYER_REGEN_DISABLED", true )
    end
end )

RegisterEvent( "PLAYER_REGEN_ENABLED", function( event )
    if Hekili.DB.profile.enhancedEvents then
        Hekili:ForceUpdate( "PLAYER_REGEN_ENABLED", true )
    end
end )


do
    local function UNIT_COMBAT( event, unit, action, _, amount )
        if amount > 0 and action == 'HEAL' then
            ns.storeHealing( GetTime(), amount )
        end
    end
    Hekili:ProfileCPU( "UNIT_COMBAT", UNIT_COMBAT )
    RegisterUnitEvent( "UNIT_COMBAT", "player", nil, UNIT_COMBAT )
end


local keys = ns.hotkeys
Hekili.KeybindInfo = keys
local updatedKeys = {}

local bindingSubs = {
    -- Keep substitutions minimal and readable to prevent keybind text overflow.
    -- Modifiers -> lowercase with trailing hyphen.
--    { "CTRL%-", "ctrl-" },
--    { "ALT%-", "alt-" },
--    { "SHIFT%-", "shift-" },
    -- Mouse wheel directions -> concise lowercase.
--    { "MOUSEWHEELUP", "mwup" },
--    { "MOUSEWHEELDOWN", "mwdown" },
    -- Generic mouse button -> short prefix (e.g., BUTTON4 -> m4).
--    { "BUTTON", "m" },
}

local function improvedGetBindingText( binding )
    if not binding then return "" end

    for i, rep in ipairs( bindingSubs ) do
        binding = binding:gsub( rep[1], rep[2] )
    end

    -- Ensure the label looks grammatical by capitalizing the leading character if it's alphabetic.
    local first = binding:sub( 1, 1 )
    if first:match( "%a" ) then
        binding = first:upper() .. binding:sub( 2 )
    end

    return binding
end


local itemToAbility = {
    [5512]   = "healthstone",
    [177278] = "phial_of_serenity"
}


local function StoreKeybindInfo( page, key, aType, id, console )

    if not key or not aType or not id then return end

    local action, ability

    if aType == "item" then
        local item, link = CGetItemInfo( id )
        ability = item and ( class.abilities[ item ] or class.abilities[ link ] )
        action = ability and ability.key

        if not action then
            if itemToAbility[ id ] then
                action = itemToAbility[ id ]
            else
                -- Check for Synapse Springs (hands slot item)
                local synapseIDs = {96228, 96229, 96230, 82174, 126734, 141330}
                for _, synapseID in ipairs(synapseIDs) do
                    if id == synapseID then
                        action = "hands"
                        break
                    end
                end
                
                -- Check for potions
                if not action then
                    for k, v in pairs( class.potions ) do
                        if v.item == id then
                            action = "potion"
                            break
                        end
                    end
                end
            end
        end
    elseif aType == "macro" then
        local GetMacroInfo = rawget( _G, "GetMacroInfo" )
        if GetMacroInfo then
            local _, _, body = GetMacroInfo( id )
            if type( body ) == "string" then
                local text = body:lower()

                -- Equipment slots
                if text:match( "/use%s*%b[]%s*10" ) or text:match( "/use%s+10" ) or 
                   text:match( "/use%s*%b[]%s*hands" ) or text:match( "/use%s+hands" ) or
                   text:match( "/use%s*%b[]%s*gloves" ) or text:match( "/use%s+gloves" ) then
                    action = "hands"
                elseif text:match( "/use%s*%b[]%s*13" ) or text:match( "/use%s+13" ) or
                       text:match( "/use%s*%b[]%s*trinket1" ) or text:match( "/use%s+trinket1" ) then
                    action = "trinket1"
                elseif text:match( "/use%s*%b[]%s*14" ) or text:match( "/use%s+14" ) or
                       text:match( "/use%s*%b[]%s*trinket2" ) or text:match( "/use%s+trinket2" ) then
                    action = "trinket2"
                end

                -- Explicit item by ID in the macro text
                if not action then
                    local itemID = tonumber( text:match( "item:(%d+)" ) )
                    if itemID then
                        local item, link = CGetItemInfo( itemID )
                        ability = item and ( class.abilities[ item ] or class.abilities[ link ] )
                        action = ability and ability.key
                        if not action then
                            if itemToAbility[ itemID ] then
                                action = itemToAbility[ itemID ]
                            else
                                for k, v in pairs( class.potions ) do
                                    if v.item == itemID then
                                        action = "potion"
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                -- Explicit item by name (e.g., /use Virmen's Bite)
                if not action then
                    local useName = text:match( "/use%s+[^\n\r;]*" )
                    if useName then
                        useName = useName:gsub( "%b[]", "" ):gsub( "/use", "" ):gsub( "^%s+", "" ):gsub( "%s+$", "" )
                        local item, link = CGetItemInfo( useName )
                        if item or link then
                            ability = item and ( class.abilities[ item ] or class.abilities[ link ] )
                            action = ability and ability.key
                            if not action then
                                for k, v in pairs( class.potions ) do
                                    if v.name == useName or v.link == link then
                                        action = "potion"
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                -- Spells cast via macro (/cast ...)
                if not action then
                    local castName = text:match( "/castsequence[^\n\r;]*;?%s*([^\n\r;]+)" ) or text:match( "/cast%s+([^\n\r;]+)" )
                    if castName then
                        castName = castName:gsub( "%b[]", "" ):gsub( "^%s+", "" ):gsub( "%s+$", "" )
                        
                        -- Check for specific spell names that have variants
                        if castName:lower():match("shred!?") or castName:lower():match("shred") then
                            action = "shred"
                        elseif castName:lower():match("thrash") then
                            action = "thrash"
                        elseif castName:lower():match("explosive_trap") or castName:lower():match("explosive trap") then
                            action = "explosive_trap"
                        elseif castName:lower():match("freezing_trap") or castName:lower():match("freezing trap") then
                            action = "freezing_trap"
                        elseif castName:lower():match("ice_trap") or castName:lower():match("ice trap") then
                            action = "ice_trap"
                        elseif castName:lower():match("snake_trap") or castName:lower():match("snake trap") then
                            action = "snake_trap"
                        elseif castName:lower():match("immolation_trap") or castName:lower():match("immolation trap") then
                            action = "immolation_trap"
                        else
                            local GetSpellInfo = rawget( _G, "GetSpellInfo" )
                            if GetSpellInfo then
                                local _, _, _, _, _, _, spellID = GetSpellInfo( castName )
                                if spellID then
                                    ability = class.abilities[ spellID ]
                                    action = ability and ability.key
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        ability = class.abilities[ id ]
        action = ability and ability.key
        
        -- Check for spell IDs with variants if not found above
        if not action then
            local spellIDs = {
                -- Shred variants (normal and glyph-enhanced)
                [5221] = "shred",              -- Shred (normal)
                [114236] = "shred",            -- Shred! (glyph-enhanced)
                -- Thrash variants (Bear and Cat forms)
                [77758] = "thrash",            -- Thrash (Bear Form) - used by Guardian and Feral
                [106830] = "thrash",           -- Thrash (Cat Form) - used by Feral
                -- Trap spells
                [13813] = "explosive_trap",    -- Explosive Trap
                [1499] = "freezing_trap",      -- Freezing Trap  
                [13809] = "ice_trap",          -- Ice Trap
                [34600] = "snake_trap",         -- Snake Trap
                [13795] = "immolation_trap"    -- Immolation Trap
            }
            if spellIDs[id] then
                action = spellIDs[id]
            end
        end
    end

    if action then
        keys[ action ] = keys[ action ] or {
            lower = {},
            upper = {},
            console = {}
        }

        if console == "cPort" then
            local newKey = key:gsub( ":%d+:%d+:0:0", ":0:0:0:0" )
            keys[ action ].console[ page ] = newKey
        else
            keys[ action ].upper[ page ] = improvedGetBindingText( key )
            keys[ action ].lower[ page ] = lower( keys[ action ].upper[ page ] )
        end
        updatedKeys[ action ] = true

        local bind = ability and ability.bind

        if bind then
            if type( bind ) == 'table' then
                for _, b in ipairs( bind ) do
                    keys[ b ] = keys[ b ] or {
                        lower = {},
                        upper = {},
                        console = {}
                    }

                    keys[ b ].lower[ page ] = keys[ action ].lower[ page ]
                    keys[ b ].upper[ page ] = keys[ action ].upper[ page ]
                    keys[ b ].console[ page ] = keys[ action ].console[ page ]

                    updatedKeys[ b ] = true
                end
            else
                keys[ bind ] = keys[ bind ] or {
                    lower = {},
                    upper = {},
                    console = {}
                }

                keys[ bind ].lower[ page ] = keys[ action ].lower[ page ]
                keys[ bind ].upper[ page ] = keys[ action ].upper[ page ]
                keys[ bind ].console[ page ] = keys[ action ].console[ page ]

                updatedKeys[ bind ] = true
            end
        end
    end
end


local defaultBarMap = {
    WARRIOR = {
        { bonus = 1, bar = 7 },
        { bonus = 2, bar = 8 },
    },
    ROGUE = {
        { bonus = 1, bar = 7 },
        { bonus = 2, bar = 7 },
        { bonus = 3, bar = 7 },
    },
    DRUID = {
        { bonus = 1, stealth = false, bar = 7 },
        { bonus = 1, stealth = true,  bar = 8 },
        { bonus = 2, bar = 8 },
        { bonus = 3, bar = 9 },
        { bonus = 4, bar = 10 },
    },
    MONK = {
        { bonus = 1, bar = 7 },
        { bonus = 2, bar = 8 },
        { bonus = 3, bar = 9 },
    },
    PRIEST = {
        { bonus = 1, bar = 7 },
    },
}


local slotsUsed = {}

local function ReadKeybindings( event )
        if not Hekili:IsValidSpec() then return end

        for k, v in pairs( keys ) do
            wipe( v.console )
            wipe( v.upper )
            wipe( v.lower )
        end

        -- Bartender4 support; if BT4 bindings are set, use them, otherwise fall back on default UI bindings below.
        -- This will still get viewed as misleading...
        if _G["Bartender4"] then
            table.wipe( slotsUsed )

            for i = 1, 180 do
                local keybind = "CLICK BT4Button" .. i .. ":Keybind"
                local bar = ceil( i / 12 )

                if GetBindingKey( keybind ) then
                    StoreKeybindInfo( bar, GetBindingKey( keybind ), GetActionInfo( i ) )
                    slotsUsed[ i ] = true
                end
            end

        -- Use ElvUI's actionbars only if they are actually enabled.
        elseif _G["ElvUI"] and _G[ "ElvUI_Bar1Button1" ] then
            table.wipe( slotsUsed )

            for i = 1, 15 do
                for b = 1, 12 do
                    local btn = _G["ElvUI_Bar" .. i .. "Button" .. b]

                    if btn then
                        local binding = btn.bindstring or btn.keyBoundTarget or ( "CLICK " .. btn:GetName() .. ":LeftButton" )

                        if i > 6 then
                            -- Checking whether bar is active.
                            local bar = _G["ElvUI_Bar" .. i]

                            if not bar or not bar.db.enabled then
                                binding = "ACTIONBUTTON" .. b
                            end
                        end

                        local action, aType = btn._state_action, "spell"

                        if action and type( action ) == "number" then
                            slotsUsed[ action ] = true

                            binding = GetBindingKey( binding )
                            action, aType = GetActionInfo( action )
                            if binding then StoreKeybindInfo( i, binding, action, aType ) end
                        end
                    end
                end
            end
        end

            for i = 1, 12 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 1, GetBindingKey( "ACTIONBUTTON" .. i ), GetActionInfo( i ) )
                end
            end

            for i = 13, 24 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 2, GetBindingKey( "ACTIONBUTTON" .. i - 12 ), GetActionInfo( i ) )
                end
            end

            for i = 25, 36 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 3, GetBindingKey( "MULTIACTIONBAR3BUTTON" .. i - 24 ), GetActionInfo( i ) )
                end
            end

            for i = 37, 48 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 4, GetBindingKey( "MULTIACTIONBAR4BUTTON" .. i - 36 ), GetActionInfo( i ) )
                end
            end

            for i = 49, 60 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 5, GetBindingKey( "MULTIACTIONBAR2BUTTON" .. i - 48 ), GetActionInfo( i ) )
                end
            end

            for i = 61, 72 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 6, GetBindingKey( "MULTIACTIONBAR1BUTTON" .. i - 60 ), GetActionInfo( i ) )
                end
            end

            for i = 72, 143 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 7 + floor( ( i - 72 ) / 12 ), GetBindingKey( "ACTIONBUTTON" .. 1 + ( i - 72 ) % 12 ), GetActionInfo( i + 1 ) )
                end
            end

            for i = 145, 156 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 13, GetBindingKey( "MULTIACTIONBAR5BUTTON" .. i - 144 ), GetActionInfo( i ) )
                end
            end

            for i = 157, 168 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 14, GetBindingKey( "MULTIACTIONBAR6BUTTON" .. i - 156 ), GetActionInfo( i ) )
                end
            end

            for i = 169, 180 do
                if not slotsUsed[ i ] then
                    StoreKeybindInfo( 15, GetBindingKey( "MULTIACTIONBAR7BUTTON" .. i - 168 ), GetActionInfo( i ) )
                end
            end

        local ConsolePort = rawget( _G, "ConsolePort" )
        if ConsolePort then
            for i = 1, 180 do
                local action, id = GetActionInfo( i )

                if action and id then
                    local bind = ConsolePort:GetActionBinding( i )
                    local key, mod = ConsolePort:GetCurrentBindingOwner( bind )

                    if key then
                        StoreKeybindInfo( math.ceil( i / 12 ), ConsolePort:GetFormattedButtonCombination( key, mod ), action, id, "cPort" )
                    end
                end
            end
        end

        for k, v in pairs( keys ) do
            local ability = class.abilities[ k ]

            if ability and ability.bind then
                if type( ability.bind ) == 'table' then
                    for _, b in ipairs( ability.bind ) do
                        for page, value in pairs( v.lower ) do
                            keys[ b ] = keys[ b ] or {
                                lower = {},
                                upper = {},
                                console = {}
                            }
                            keys[ b ].lower[ page ] = value
                            keys[ b ].upper[ page ] = v.upper[ page ]
                            keys[ b ].console[ page ] = v.console[ page ]
                        end
                    end
                else
                    for page, value in pairs( v.lower ) do
                        keys[ ability.bind ] = keys[ ability.bind ] or {
                            lower = {},
                            upper = {},
                            console = {}
                        }
                        keys[ ability.bind ].lower[ page ] = value
                        keys[ ability.bind ].upper[ page ] = v.upper[ page ]
                        keys[ ability.bind ].console[ page ] = v.console[ page ]
                    end
                end
            end
        end

        -- This is also the right time to update pet-based target detection.
        Hekili:SetupPetBasedTargetDetection()
end
ns.ReadKeybindings = ReadKeybindings

local function ReadOneKeybinding( event, slot )
    if not Hekili:IsValidSpec() then return end
    if not slot or slot == 0 then return end

    local actionBarNumber = ceil( slot / 12 )
    local keyNumber = slot - ( 12 * ( actionBarNumber - 1 ) )

    local ability
    local completed = false

    -- Bartender4 support; if BT4 bindings are set, use them, otherwise fall back on default UI bindings below.
    -- This will still get viewed as misleading...
    if _G["Bartender4"] then
        local keybind = "CLICK BT4Button" .. slot .. ":Keybind"

        if GetBindingKey( keybind ) then
            StoreKeybindInfo( actionBarNumber, GetBindingKey( keybind ), GetActionInfo( slot ) )
            completed = true
        end

    elseif _G["ElvUI"] and _G["ElvUI_Bar1Button1"] then
        local btn = _G[ "ElvUI_Bar" .. actionBarNumber .. "Button" .. keyNumber ]

        if btn then
            local binding = btn.bindstring or btn.keyBoundTarget or ( " CLICK " .. btn:GetName() .. ":LeftButton" )

            if actionBarNumber > 6 then
                -- Checking whether bar is active.
                local bar = _G[ "ElvUI_Bar" .. actionBarNumber ]

                if not bar or not bar.db.enabled then
                    binding = "ACTIONBUTTON" .. keyNumber
                end
            end

            local action, aType = btn._state_action, "spell"

            if action and type( action ) == "number" then
                binding = GetBindingKey( binding )
                action, aType = GetActionInfo( action )
                if binding then StoreKeybindInfo( actionBarNumber, binding, action, aType ) end
            end
        end
    end

    if not completed then
        if actionBarNumber == 1 or actionBarNumber == 2 or ( actionBarNumber > 6  and actionBarNumber < 13 ) then
            ability = StoreKeybindInfo( keyNumber, GetBindingKey( "ACTIONBUTTON" .. keyNumber ), GetActionInfo( slot ) )

        elseif actionBarNumber > 2 and actionBarNumber < 5 then
            ability = StoreKeybindInfo( actionBarNumber, GetBindingKey( "MULTIACTIONBAR" .. actionBarNumber .. "BUTTON" .. keyNumber ), GetActionInfo( slot ) )

        elseif actionBarNumber == 5 then
            ability = StoreKeybindInfo( actionBarNumber, GetBindingKey( "MULTIACTIONBAR2BUTTON" .. keyNumber ), GetActionInfo( slot ) )

        elseif actionBarNumber == 6 then
            ability = StoreKeybindInfo( actionBarNumber, GetBindingKey( "MULTIACTIONBAR1BUTTON" .. keyNumber ), GetActionInfo( slot ) )

        elseif actionBarNumber == 13 then
            ability = StoreKeybindInfo( actionBarNumber, GetBindingKey( "MULTIACTIONBAR5BUTTON" .. keyNumber ), GetActionInfo( slot ) )

        elseif actionBarNumber == 14 then
            ability = StoreKeybindInfo( actionBarNumber, GetBindingKey( "MULTIACTIONBAR6BUTTON" .. keyNumber ), GetActionInfo( slot ) )

        elseif actionBarNumber == 15 then
            ability = StoreKeybindInfo( actionBarNumber, GetBindingKey( "MULTIACTIONBAR7BUTTON" .. keyNumber ), GetActionInfo( slot ) )

        end
    end

    local ConsolePort = rawget( _G, "ConsolePort" )
    if ConsolePort then
        local action, id = GetActionInfo( slot )

        if action and id then
            local bind = ConsolePort:GetActionBinding( slot )
            local key, mod = ConsolePort:GetCurrentBindingOwner( bind )

            if key then
                ability = StoreKeybindInfo( actionBarNumber, ConsolePort:GetFormattedButtonCombination( key, mod ), action, id, "cPort" )
            end
        end
    end


    -- This is also the right time to update pet-based target detection.
    Hekili:SetupPetBasedTargetDetection()
end


local allTimer

local function DelayedUpdateKeybindings( event )
    if allTimer and not allTimer:IsCancelled() then allTimer:Cancel() end
    allTimer = Hekili:After( 0.2, function()
        ReadKeybindings( event )
    end )
end

--[[ local function DelayedUpdateOneKeybinding( event, slot )
    if oneTimer and not oneTimer:IsCancelled() then oneTimer:Cancel() end
    oneTimer = Hekili:After( 0.2, function() ReadOneKeybinding( event, slot ) end )
end ]]

RegisterEvent( "UPDATE_BINDINGS", DelayedUpdateKeybindings )
RegisterEvent( "SPELLS_CHANGED", DelayedUpdateKeybindings )
RegisterEvent( "ACTIONBAR_SHOWGRID", DelayedUpdateKeybindings )
RegisterEvent( "ACTIONBAR_HIDEGRID", DelayedUpdateKeybindings )
-- RegisterEvent( "ACTIONBAR_PAGE_CHANGED", DelayedUpdateKeybindings )
-- RegisterEvent( "UPDATE_SHAPESHIFT_FORM", DelayedUpdateKeybindings )

if Hekili.IsWrath() then
    RegisterEvent( "ACTIVE_TALENT_GROUP_CHANGED", DelayedUpdateKeybindings )
else
    RegisterEvent( "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", DelayedUpdateKeybindings )
    RegisterEvent( "TRAIT_CONFIG_UPDATED", DelayedUpdateKeybindings )
end



if select( 2, UnitClass( "player" ) ) == "DRUID" then
    local prowlOrder = { 8, 7, 1, 2, 3, 4, 5, 6, 10, 9, 13, 14, 15 }
    local catOrder = { 7, 8, 1, 2, 3, 4, 5, 6, 10, 9, 13, 14, 15 }
    local bearOrder = { 9, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 1 }
    local owlOrder = { 10, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15 }
    local defaultOrder = { 1, 2, 3, 4, 5, 6, 10, 7, 8, 9, 13, 14, 15 }

    function Hekili:GetBindingForAction( key, display, i )
        if not key then return "" end

        local ability = class.abilities[ key ]
        key = ability and ability.key or key

        local override = state.spec.id
        local overrideType = ability and ability.item and "items" or "abilities"

        override = override and rawget( self.DB.profile.specs, override )
        override = override and override[ overrideType ][ key ]
        override = override and override.keybind

        if override and override ~= "" then
            return override
        end

        if not keys[ key ] then return "" end

        local caps, console = true, false

        local queued = ( i or 1 ) > 1 and display.keybindings.separateQueueStyle

        if display then
            caps = not ( queued and display.keybindings.queuedLowercase or display.keybindings.lowercase )
            console = ( rawget( _G, "ConsolePort" ) ~= nil ) and display.keybindings.cPortOverride
        end

        local db = console and keys[ key ].console or ( caps and keys[ key ].upper or keys[ key ].lower )

        local output, source

        local order = defaultOrder
        -- TODO: These checks should use actual aura data rather than potential stale/manipulated virtual state data.
        if class.file == "DRUID" then
            order = ( state.prowling and prowlOrder ) or ( state.buff.cat_form.up and catOrder ) or ( state.buff.bear_form.up and bearOrder ) or ( state.buff.moonkin_form.up and owlOrder ) or order
        end

        if order then
            for _, n in ipairs( order ) do
                output = db[ n ]

                if output then
                    source = n
                    break
                end
            end
        end

        output = output or ""
        source = source or -1

        if output ~= "" and console then
            local size = output:match( "Icons(%d%d)" )
            size = tonumber(size)

            if size then
                local margin = floor( size * display.keybindings.cPortZoom * 0.5 )
                output = output:gsub( ":0|t", ":0:" .. size .. ":" .. size .. ":" .. margin .. ":" .. ( size - margin ) .. ":" .. margin .. ":" .. ( size - margin ) .. "|t" )
            end
        end

        return output
    end

elseif select( 2, UnitClass( "player" ) ) == "ROGUE" then
    local stealthedOrder = { 7, 8, 1, 2, 3, 4, 5, 6, 9, 10, 13, 14, 15 }
    local defaultOrder = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 }

    function Hekili:GetBindingForAction( key, display, i )
        if not key then return "" end

        local ability = class.abilities[ key ]
        key = ability and ability.key or key

        local override = state.spec.id
        local overrideType = ability and ability.item and "items" or "abilities"

        override = override and rawget( self.DB.profile.specs, override )
        override = override and override[ overrideType ][ key ]
        override = override and override.keybind

        if override and override ~= "" then
            return override
        end

        if not keys[ key ] then
            return ""
        end

        local queued = ( i or 1 ) > 1 and display.keybindings.separateQueueStyle

        local caps, console = true, false
        if display then
            caps = not ( queued and display.keybindings.queuedLowercase or display.keybindings.lowercase )
            console = ( rawget( _G, "ConsolePort" ) ~= nil ) and display.keybindings.cPortOverride
        end

        local db = console and keys[ key ].console or ( caps and keys[ key ].upper or keys[ key ].lower )

        local output, source
        local order = state.stealthed.all and stealthedOrder or defaultOrder

        for _, n in ipairs( order ) do
            output = db[ n ]

            if output then
                source = n
                break
            end
        end

        output = output or ""
        source = source or -1

        if output ~= "" and console then
            local size = output:match( "Icons(%d%d)" )
            size = tonumber(size)

            if size then
                local margin = floor( size * display.keybindings.cPortZoom * 0.5 )
                output = output:gsub( ":0|t", ":0:" .. size .. ":" .. size .. ":" .. margin .. ":" .. ( size - margin ) .. ":" .. margin .. ":" .. ( size - margin ) .. "|t" )
            end
        end

        return output, source
    end

else
    function Hekili:GetBindingForAction( key, display, i )
        local ability = class.abilities[ key ]
        key = ability and ability.key or key

        local override = state.spec.id
        local overrideType = ability and ability.item and "items" or "abilities"

        override = override and rawget( self.DB.profile.specs, override )
        override = override and override[ overrideType ][ key ]
        override = override and override.keybind

        if override and override ~= "" then
            return override
        end

        if not keys[ key ] then return "" end

        local queued = ( i or 1 ) > 1 and display.keybindings.separateQueueStyle

        local caps, console = true, false
        if display then
            caps = not ( queued and display.keybindings.queuedLowercase or display.keybindings.lowercase )
            console = ( rawget( _G, "ConsolePort" ) ~= nil ) and display.keybindings.cPortOverride
        end

        local db = console and keys[ key ].console or ( caps and keys[ key ].upper or keys[ key ].lower )

        local output, source

        for _, n in ipairs( { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 13, 14, 15 } ) do
            output = db[ n ]

            if output then
                source = n
                break
            end
        end

        output = output or ""
        source = source or -1

        if output ~= "" and console then
            local size = output:match( "Icons(%d%d)" )
            size = tonumber(size)

            if size then
                local margin = floor( size * display.keybindings.cPortZoom * 0.5 )
                output = output:gsub( ":0:0:0:0|t", ":0:0:0:0:" .. size .. ":" .. size .. ":" .. margin .. ":" .. ( size - margin ) .. ":" .. margin .. ":" .. ( size - margin ) .. "|t" )
            end
        end

        return output, source
    end
end

-- Enhanced event performance monitoring for APL compatibility
function Hekili:GetEventPerformanceStats()
    if not Hekili.DB.profile.enhancedEvents then
        return nil
    end
    
    local stats = {
        totalEvents = 0,
        totalTime = 0,
        maxEventTime = 0,
        eventCounts = {},
        performanceWarnings = {}
    }
    
    for event, data in pairs( eventData ) do
        stats.totalEvents = stats.totalEvents + ( handlerCount[ event ] or 0 )
        stats.totalTime = stats.totalTime + ( data.total or 0 )
        stats.maxEventTime = max( stats.maxEventTime, data.max or 0 )
        
        if data.total and data.total > 1000 then
            stats.performanceWarnings[ event ] = data.total
        end
    end
    
    return stats
end

-- Enhanced event debugging for APL compatibility
function Hekili:DebugEventPerformance()
    if not Hekili.DB.profile.enhancedEvents then
        return
    end
    
    local stats = self:GetEventPerformanceStats()
    if stats then
        print( "Hekili Event Performance:" )
        print( "Total Events:", stats.totalEvents )
        print( "Total Time:", string.format( "%.2fms", stats.totalTime ) )
        print( "Max Event Time:", string.format( "%.2fms", stats.maxEventTime ) )
        
        if next( stats.performanceWarnings ) then
            print( "Performance Warnings:" )
            for event, time in pairs( stats.performanceWarnings ) do
                print( "  ", event, string.format( "%.2fms", time ) )
            end
        end
    end
end

-- Enhanced aura tracking system for APL compatibility
local enhancedAuraTracker = {
    importantAuras = {},
    trackedAuras = {},
    auraHistory = {},
    maxHistorySize = 100
}

function Hekili:TrackImportantAura(spellID, key, important, tracking)
    if not Hekili.DB.profile.enhancedEvents then
        return
    end
    
    enhancedAuraTracker.importantAuras[spellID] = {
        key = key,
        important = important,
        tracking = tracking,
        lastSeen = GetTime()
    }
end

function Hekili:GetEnhancedAuraInfo(spellID)
    if not Hekili.DB.profile.enhancedEvents then
        return nil
    end
    
    return enhancedAuraTracker.importantAuras[spellID]
end

function Hekili:UpdateAuraHistory(spellID, event, data)
    if not Hekili.DB.profile.enhancedEvents then
        return
    end
    
    local now = GetTime()
    local history = enhancedAuraTracker.auraHistory[spellID] or {}
    
    insert(history, {
        time = now,
        event = event,
        data = data
    })
    
    -- Keep only recent history
    while #history > enhancedAuraTracker.maxHistorySize do
        remove(history, 1)
    end
    
    enhancedAuraTracker.auraHistory[spellID] = history
end

-- Enhanced combat log event filtering for APL compatibility
function Hekili:IsEventFiltered(spellID, eventType)
    if not Hekili.DB.profile.enhancedEvents then
        return dmg_filtered[spellID] or false
    end
    
    -- Use enhanced filtering when available
    return enhanced_dmg_filtered[spellID] or dmg_filtered[spellID] or false
end

-- Enhanced aura history retrieval for APL compatibility
function Hekili:GetAuraHistory(spellID, eventType, timeWindow)
    if not Hekili.DB.profile.enhancedEvents then
        return nil
    end
    
    local history = enhancedAuraTracker.auraHistory[spellID]
    if not history then
        return nil
    end
    
    local now = GetTime()
    local filteredHistory = {}
    
    for _, entry in ipairs(history) do
        if (not timeWindow or (now - entry.time) <= timeWindow) and
           (not eventType or entry.event == eventType) then
            insert(filteredHistory, entry)
        end
    end
    
    return filteredHistory
end

-- Enhanced aura tracking status for APL compatibility
function Hekili:GetAuraTrackingStatus(spellID)
    if not Hekili.DB.profile.enhancedEvents then
        return nil
    end
    
    local info = enhancedAuraTracker.importantAuras[spellID]
    if not info then
        return nil
    end
    
    return {
        key = info.key,
        important = info.important,
        tracking = info.tracking,
        lastSeen = info.lastSeen,
        timeSinceLastSeen = GetTime() - info.lastSeen
    }
end
