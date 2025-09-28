-- Classes.lua
---@diagnostic disable: undefined-global, need-check-nil, assign-type-mismatch
-- January 2025

local addon, ns = ...
local Hekili = _G[ addon ]

local class = Hekili.Class
local state = Hekili.State

local CommitKey = ns.commitKey
local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID
local GetItemInfo = ns.CachedGetItemInfo
local GetResourceInfo, GetResourceKey = ns.GetResourceInfo, ns.GetResourceKey
local ResetDisabledGearAndSpells = ns.ResetDisabledGearAndSpells
local RegisterEvent = ns.RegisterEvent
local RegisterUnitEvent = ns.RegisterUnitEvent

local LSR = LibStub( "SpellRange-1.0" )

local insert, wipe = table.insert, table.wipe

local mt_resource = ns.metatables.mt_resource

-- MoP API compatibility - use old API calls instead of modern C_* namespaced ones
local GetActiveLossOfControlData, GetActiveLossOfControlDataCount
if C_LossOfControl then
    GetActiveLossOfControlData, GetActiveLossOfControlDataCount = C_LossOfControl.GetActiveLossOfControlData, C_LossOfControl.GetActiveLossOfControlDataCount
else
    -- MoP fallbacks
    GetActiveLossOfControlData = function() return {} end
    GetActiveLossOfControlDataCount = function() return 0 end
end
-- MoP compatible item and spell functions
local function SafeGetItemCooldown( item )
    -- Check for modern C_Item API first
    if C_Item and C_Item.GetItemCooldown and type( item ) == "number" then
        local cooldownInfo = C_Item.GetItemCooldown( item )
        if cooldownInfo and type(cooldownInfo) == "table" then
            -- Extract values safely - C_Item.GetItemCooldown returns a table with startTime and duration
            local startTime = (cooldownInfo).startTime
            local duration = (cooldownInfo).duration
            return (startTime or 0), (duration or 0)
        end
    -- Fallback to legacy API if available
    elseif rawget( _G, "GetItemCooldown" ) and type( item ) == "number" then
        -- Use rawget to avoid directly referencing a deprecated global
        local getter = rawget( _G, "GetItemCooldown" )
        local start, duration = getter( item ) -- luacheck: ignore 113
        return start or 0, duration or 0
    end
    return 0, 0
end

-- Safe local aliases for inventory-based APIs used by tinkers; avoid referencing _G inside setfenv'd functions.
local GetInventoryItemCooldown = rawget( _G, "GetInventoryItemCooldown" ) or function(unit, slot)
    return 0, 0, 0
end
-- Safe fallback for GetInventoryItemSpell - used for tinker detection
-- Note: This API may not be available in all WoW versions
---@diagnostic disable-next-line: undefined-field
local GetInventoryItemSpell = rawget( _G, "GetInventoryItemSpell" ) or function(unit, slot)
    return nil, nil
end
local INVSLOT_HAND = rawget( _G, "INVSLOT_HAND" ) or 10
local GetInventoryItemID = _G.GetInventoryItemID or function(unit, slot)
    local link = _G.GetInventoryItemLink and _G.GetInventoryItemLink(unit, slot)
    if not link then return nil end
    return tonumber( link:match("item:(%d+)") )
end
local GetInventoryItemLink = _G.GetInventoryItemLink or function(unit, slot)
    return _G.GetInventoryItemLink and _G.GetInventoryItemLink(unit, slot) or nil
end
local GetInventoryItemTexture = _G.GetInventoryItemTexture or function(unit, slot)
    return _G.GetInventoryItemTexture and _G.GetInventoryItemTexture(unit, slot) or nil
end
local CreateFrame = _G.CreateFrame

-- Cataclysm-like tinker tracker for MoP
local tinker = { hand = { spell = 0, name = nil, item = 0, texture = nil, enchant = 0 } }
local function UpdateTinkerHand()
    -- MoP clients can return either (name) or (name, spellID); be resilient.
    local a, b = GetInventoryItemSpell("player", INVSLOT_HAND)
    local spellName, spellID
    if type(a) == "number" then
        -- Some clients might (rarely) return spellID as first value.
        spellID = a
        spellName = b
    else
        spellName = a
        spellID = b
    end
    tinker.hand.name = spellName or nil
    tinker.hand.spell = spellID or 0
    tinker.hand.item = GetInventoryItemID("player", INVSLOT_HAND) or 0
    tinker.hand.texture = GetInventoryItemTexture("player", INVSLOT_HAND)
    local link = GetInventoryItemLink("player", INVSLOT_HAND)
    if link then
        local enchant = link:match("item:%d+:(%d+)")
        tinker.hand.enchant = tonumber(enchant) or 0
    else
        tinker.hand.enchant = 0
    end
end
do
    local f = CreateFrame and CreateFrame("Frame")
    if f then
        f:RegisterEvent("PLAYER_LOGIN")
        f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        f:SetScript("OnEvent", function(_, evt)
            if evt == "PLAYER_LOGIN" or evt == "PLAYER_EQUIPMENT_CHANGED" then
                UpdateTinkerHand()
            end
        end)
    end
end
UpdateTinkerHand()
-- Capture original GetSpellInfo early so downstream helpers can safely reference it.
local OriginalGetSpellInfo = rawget(_G, "GetSpellInfo")
local GetSpellInfo = OriginalGetSpellInfo
local _GetSpellDescription = (C_Spell and rawget(C_Spell, "GetSpellDescription")) or rawget(_G, "GetSpellDescription")
local function GetSpellDescription(spellID)
    if type(_GetSpellDescription) == "function" then
        return _GetSpellDescription(spellID)
    end
    local tooltip = CreateFrame("GameTooltip", "HekiliTooltip", nil, "GameTooltipTemplate")
    tooltip:SetSpell(spellID)
    return _G[tooltip:GetName() .. "TextLeft2"]:GetText() or ""
end

local GetSpellTexture = rawget(_G, "GetSpellTexture") or function(spellID)
    local _, _, icon = GetSpellInfo(spellID)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local GetSpellLink = rawget(_G, "GetSpellLink") or function(spellID)
    local name = GetSpellInfo and GetSpellInfo(spellID)
    if name then
        return "|cff71d5ff|Hspell:" .. spellID .. "|h[" .. name .. "]|h|r"
    end
    return nil
end

-- MoP compatible item functions (use rawget to avoid direct deprecated references)
local _GetItemSpell = rawget( _G, "GetItemSpell" )
local function GetItemSpell( item )
    if type( _GetItemSpell ) == "function" then
        return _GetItemSpell( item )
    end
    return nil, nil
end

local _GetItemCount = rawget( _G, "GetItemCount" )
local function GetItemCount( item, includeBank, includeCharges )
    if type( _GetItemCount ) == "function" then
        return _GetItemCount( item, includeBank, includeCharges ) or 0
    end
    return 0
end

local _IsUsableItem = rawget( _G, "IsUsableItem" )
local function IsUsableItem( item )
    if type( _IsUsableItem ) == "function" then
        local usable, noMana = _IsUsableItem( item )
        return usable or false, noMana or false
    end
    return false, false
end

local UnitBuff, UnitDebuff = ns.UnitBuff, ns.UnitDebuff

local specTemplate = {
    enabled = true,

    aoe = 2,
    cycle = false,
    cycle_min = 6,
    gcdSync = true,

    nameplates = true,
    petbased = false,

    damage = true,
    damageExpiration = 8,
    damageDots = false,
    damageOnScreen = true,
    damageRange = 0,
    damagePets = false,

    -- Toggles
    custom1Name = "Custom 1",
    custom2Name = "Custom 2",
    noFeignedCooldown = false,

    abilities = {
        ['**'] = {
            disabled = false,
            toggle = "default",
            clash = 0,
            targetMin = 0,
            targetMax = 0,
            dotCap = 0,
            boss = false
        }
    },
    items = {
        ['**'] = {
            disabled = false,
            toggle = "default",
            clash = 0,
            targetMin = 0,
            targetMax = 0,
            boss = false,
            criteria = nil
        }
    },



    ranges = {},
    settings = {},
    phases = {},
    cooldowns = {},
    utility = {},
    defensives = {},
    custom1 = {},
    custom2 = {},
}
ns.specTemplate = specTemplate -- for options.


local function Aura_DetectSharedAura( t, type )
    if not t then return end
    local finder = type == "debuff" and FindUnitDebuffByID or FindUnitBuffByID
    local aura = class.auras[ t.key ]

    local name, _, count, _, duration, expirationTime, caster = finder( aura.shared, aura.id )

    if name then
        t.count = count > 0 and count or 1

        if expirationTime > 0 then
            t.applied = expirationTime - duration
            t.expires = expirationTime
        else
            t.applied = state.query_time
            t.expires = state.query_time + t.duration
        end
        t.caster = caster
        return
    end

    t.count = 0
    t.applied = 0
    t.expires = 0
    t.caster = "nobody"
end


local protectedFunctions = {
    -- Channels.
    start = true,
    tick = true,
    finish = true,

    -- Casts
    handler = true, -- Cast finish.
    impact = true,  -- Projectile impact.
}


local HekiliSpecMixin = {
    RegisterResource = function( self, resourceID, regen, model, meta )
        local resource = GetResourceKey( resourceID )

        if not resource then
            Hekili:Error( "Unable to identify resource with PowerType " .. resourceID .. "." )
            return
        end

        local r = self.resources[ resource ] or {}

        r.resource = resource
        r.type = resourceID
        r.state = model or setmetatable( {
            resource = resource,
            type = resourceID,

            forecast = {},
            fcount = 0,
            times = {},
            values = {},

            active_regen = 0,
            inactive_regen = 0,
            last_tick = 0,

            swingGen = false,

            add = function( amt, overcap )
                -- Bypasses forecast, useful in hooks.
                if overcap then r.state.amount = r.state.amount + amt
                else r.state.amount = max( 0, min( r.state.amount + amt, r.state.max ) ) end
            end,

            timeTo = function( x )
                return state:TimeToResource( r.state, x )
            end,
        }, mt_resource )
        r.state.regenModel = regen
        r.state.meta = meta or {}

        for _, func in pairs( r.state.meta ) do
            setfenv( func, state )
        end

        if model and not model.timeTo then
            model.timeTo = function( x )
                return state:TimeToResource( r.state, x )
            end
        end

        if r.state.regenModel then
            for _, v in pairs( r.state.regenModel ) do
                -- Add type check to ensure v is a table before trying to index it
                if type( v ) == "table" then
                    v.resource = v.resource or resource
                    self.resourceAuras[ v.resource ] = self.resourceAuras[ v.resource ] or {}

                    if v.aura then
                        self.resourceAuras[ v.resource ][ v.aura ] = true
                    end

                    if v.channel then
                        self.resourceAuras[ v.resource ].casting = true
                    end

                    if v.swing then
                        r.state.swingGen = true
                    end
                end
            end
        end

        self.primaryResource = self.primaryResource or resource
        self.resources[ resource ] = r

        CommitKey( resource )
    end,

    RegisterTalents = function( self, talents )
        for talent, id in pairs( talents ) do
            self.talents[ talent ] = id
            CommitKey( talent )
        end
    end,

    RegisterAura = function( self, aura, data )
        CommitKey( aura )

        local a = setmetatable( {
            funcs = {}
        }, {
            __index = function( t, k )
                if t.funcs[ k ] then return t.funcs[ k ]() end

                local setup = rawget( t, "onLoad" )
                if setup then
                    t.onLoad = nil
                    setup( t )

                    return t[ k ]
                end
            end
        } )

        a.key = aura

        if not data.id then
            self.pseudoAuras = self.pseudoAuras + 1
            data.id = ( -1000 * self.id ) - self.pseudoAuras
        end

        -- default values.
        data.duration  = data.duration or 30
        data.max_stack = data.max_stack or 1

        -- This is a shared buff that can come from anyone, give it a special generator.
        --[[ if data.shared then
            a.generate = Aura_DetectSharedAura
        end ]]

        for element, value in pairs( data ) do
            if type( value ) == "function" then
                setfenv( value, state )
                if element ~= "generate" then a.funcs[ element ] = value
                else a[ element ] = value end
            else
                a[ element ] = value
            end

            class.knownAuraAttributes[ element ] = true
        end

        if data.tick_time and not data.tick_fixed then
            if a.funcs.tick_time then
                local original = a.funcs.tick_time
                a.funcs.tick_time = setfenv( function( ... )
                    local val = original( ... )
                    return ( val or 3 ) * haste
                end, state )
                a.funcs.base_tick_time = original
            else
                local original = a.tick_time
                a.funcs.tick_time = setfenv( function( ... )
                    return ( original or 3 ) * haste
                end, state )
                a.base_tick_time = original
                a.tick_time = nil
            end
        end

        self.auras[ aura ] = a

        -- Always add to class.auras with the key for validation purposes
        class.auras[ aura ] = a

        if a.id then
            if a.id > 0 then
                -- Hekili:ContinueOnSpellLoad( a.id, function( success )
                a.onLoad = function( a )
                    for k, v in pairs( class.auraList ) do
                        if v == a then class.auraList[ k ] = nil end
                    end

                    Hekili.InvalidSpellIDs = Hekili.InvalidSpellIDs or {}
                    Hekili.InvalidSpellIDs[ a.id ] = a.name or a.key

                    -- FIX: Only set a.id to the key if the key is a number and a.id is not already set
                    if not a.id and type(aura) == "number" then
                        a.id = aura
                    end
                    a.name = a.name or a.key

                    return
                end

                a.desc = GetSpellDescription( a.id )

                local texture = a.texture or GetSpellTexture( a.id ) or "Interface\\Icons\\INV_Misc_QuestionMark"

                if self.id > 0 then
                    class.auraList[ a.key ] = "|T" .. texture .. ":0|t " .. a.name
                end

                self.auras[ a.name ] = a
                -- Always add to class.auras with both key and name
                class.auras[ a.key ] = a
                class.auras[ a.name ] = a

                if self.pendingItemSpells[ a.name ] then
                    local items = self.pendingItemSpells[ a.name ]

                    if type( items ) == 'table' then
                        for i, item in ipairs( items ) do
                            local ability = self.abilities[ item ]
                            ability.itemSpellKey = a.key .. "_" .. ability.itemSpellID

                            self.abilities[ ability.itemSpellKey ] = a
                            class.abilities[ ability.itemSpellKey ] = a
                        end
                    else
                        local ability = self.abilities[ items ]
                        ability.itemSpellKey = a.key .. "_" .. ability.itemSpellID

                        self.abilities[ ability.itemSpellKey ] = a
                        class.abilities[ ability.itemSpellKey ] = a
                    end

                    self.pendingItemSpells[ a.name ] = nil
                    self.itemPended = nil
                end
            end

            self.auras[ a.id ] = a
            class.auras[ a.id ] = a
        end

        if data.meta then
            for k, v in pairs( data.meta ) do
                if type( v ) == "function" then data.meta[ k ] = setfenv( v, state ) end
                class.knownAuraAttributes[ k ] = true
            end
        end

        if data.copy then
            if type( data.copy ) ~= "table" then
                self.auras[ data.copy ] = a
                class.auras[ data.copy ] = a
            else
                for _, key in ipairs( data.copy ) do
                    self.auras[ key ] = a
                    class.auras[ key ] = a
                end
            end
        end
    end,

    RegisterAuras = function( self, auras )
        for aura, data in pairs( auras ) do
            self:RegisterAura( aura, data )
        end
    end,

    RegisterGlyphs = function( self, glyphs )
        -- Normalize glyph mappings so lookups work by name -> spellID.
        -- Many specs register as [spellID] = "glyph_name". We store both
        -- directions, but consumers (like state.glyph.<name>.enabled) rely on
        -- name -> spellID being present.
        if not self.glyphs then
            self.glyphs = {}
        end
        for key, value in pairs( glyphs ) do
            if type( key ) == "number" and type( value ) == "string" then
                -- Registered as [id] = name
                self.glyphs[ value ] = key   -- primary: name -> id
                self.glyphs[ key ] = value   -- secondary: id -> name (for debugging/tools)
            elseif type( key ) == "string" and type( value ) == "number" then
                -- Registered as name -> id
                self.glyphs[ key ] = value   -- primary: name -> id
                self.glyphs[ value ] = key   -- secondary: id -> name
            else
                -- Fallback: keep whatever was provided
                self.glyphs[ key ] = value
            end
        end
    end,

    RegisterPower = function( self, power, id, aura )
        self.powers[ power ] = id
        CommitKey( power )

        if aura and type( aura ) == "table" then
            self:RegisterAura( power, aura )
        end
    end,

    RegisterPowers = function( self, powers )
        for k, v in pairs( powers ) do
            self.powers[ k ] = v.id
            self.powers[ v.id ] = k

            for token, ids in pairs( v.triggers ) do
                if not self.auras[ token ] then
                    self:RegisterAura( token, {
                        id = v.id,
                        copy = ids
                    } )
                end
            end
        end
    end,

    RegisterStateExpr = function( self, key, func )
        setfenv( func, state )
        self.stateExprs[ key ] = func
        class.stateExprs[ key ] = func
        CommitKey( key )
    end,

    RegisterStateFunction = function( self, key, func )
        setfenv( func, state )
        self.stateFuncs[ key ] = func
        class.stateFuncs[ key ] = func
        CommitKey( key )
    end,

    RegisterStateTable = function( self, key, data )
        for _, f in pairs( data ) do
            if type( f ) == "function" then
                setfenv( f, state )
            end
        end

        local meta = getmetatable( data )

        if meta and meta.__index then
            setfenv( meta.__index, state )
        end

        self.stateTables[ key ] = data
        class.stateTables[ key ] = data
        CommitKey( key )
    end,

    -- Phases are for more durable variables that should be recalculated over the course of recommendations.
    -- The start/finish conditions are calculated on reset and that state is persistent between sets of recommendations.
    -- Within a set of recommendations, the phase conditions are recalculated when the clock advances and/or when ability handlers are fired.
    -- Notably, finish is only fired if we are currently in the phase.
    RegisterPhase = function( self, key, start, finish, ... )
        if start then start = setfenv( start, state ) end
        if finish then finish = setfenv( finish, state ) end

        self.phases[ key ] = {
            activate = start,
            deactivate = finish,
            virtual = {},
            real = {}
        }

        local phase = self.phases[ key ]
        local n = select( "#", ... )

        for i = 1, n do
            local hook = select( i, ... )

            if hook == "reset_precast" then
                self:RegisterHook( hook, function()
                    local d = display or "Primary"

                    if phase.real[ d ] == nil then
                        phase.real[ d ] = false
                    end

                    local original = phase.real[ d ]

                    if state.time == 0 and not InCombatLockdown() then
                        phase.real[ d ] = false
                        -- Hekili:Print( format( "[ %s ] Phase '%s' set to '%s' (%s) - out of combat.", self.name or "Unspecified", key, tostring( phase.real[ d ] ), hook ) )
                        -- if Hekili.ActiveDebug then Hekili:Debug( "[ %s ] Phase '%s' set to '%s' (%s) - out of combat.", self.name or "Unspecified", key, tostring( phase.virtual[ display or "Primary" ] ), hook ) end
                    end

                    if not phase.real[ d ] and phase.activate() then
                        phase.real[ d ] = true
                    end

                    if phase.real[ d ] and phase.deactivate() then
                        phase.real[ d ] = false
                    end

                    --[[ if phase.real[ d ] ~= original then
                        if d == "Primary" then Hekili:Print( format( "Phase change for %s [ %s ] (from %s to %s).", key, d, tostring( original ), tostring( phase.real[ d ] ) ) ) end
                    end ]]

                    phase.virtual[ d ] = phase.real[ d ]

                    if Hekili.ActiveDebug then Hekili:Debug( "[ %s ] Phase '%s' set to '%s' (%s).", self.name or "Unspecified", key, tostring( phase.virtual[ d ] ), hook ) end
                end )
            else
                self:RegisterHook( hook, function()
                    local d = display or "Primary"
                    local previous = phase.virtual[ d ]

                    if phase.virtual[ d ] ~= true and phase.activate() then
                        phase.virtual[ d ] = true
                    end

                    if phase.virtual[ d ] == true and phase.deactivate() then
                        phase.virtual[ d ] = false
                    end

                    if Hekili.ActiveDebug and phase.virtual[ d ] ~= previous then Hekili:Debug( "[ %s ] Phase '%s' set to '%s' (%s) - virtual.", self.name or "Unspecified", key, tostring( phase.virtual[ d ] ), hook ) end
                end )
            end
        end

        self:RegisterVariable( key, function()
            return self.phases[ key ].virtual[ display or "Primary" ]
        end )
    end,

    RegisterPhasedVariable = function( self, key, default, value, ... )
        value = setfenv( value, state )

        self.phases[ key ] = {
            update = value,
            virtual = {},
            real = {}
        }

        local phase = self.phases[ key ]
        local n = select( "#", ... )

        if type( default ) == "function" then
            phase.default = setfenv( default, state )
        else
            phase.default = setfenv( function() return default end, state )
        end

        for i = 1, n do
            local hook = select( i, ... )

            if hook == "reset_precast" then
                self:RegisterHook( hook, function()
                    local d = display or "Primary"

                    if phase.real[ d ] == nil or ( state.time == 0 and not InCombatLockdown() ) then
                        phase.real[ d ] = phase.default()
                    end

                    local original = phase.real[ d ] or "nil"

                    phase.real[ d ] = phase.update( phase.real[ d ], phase.default() )
                    phase.virtual[ d ] = phase.real[ d ]

                    if Hekili.ActiveDebug then
                        Hekili:Debug( "[ %s ] Phased variable '%s' set to '%s' (%s) - was '%s'.", self.name or "Unspecified", key, tostring( phase.virtual[ display or "Primary" ] ), hook, tostring( original ) )
                    end
                end )
            else
                self:RegisterHook( hook, function()
                    local d = display or "Primary"
                    local previous = phase.virtual[ d ]

                    phase.virtual[ d ] = phase.update( phase.virtual[ d ], phase.default() )

                    if Hekili.ActiveDebug and phase.virtual[ d ] ~= previous then Hekili:Debug( "[ %s ] Phased variable '%s' set to '%s' (%s) - virtual.", self.name or "Unspecified", key, tostring( phase.virtual[ display or "Primary" ] ), hook ) end
                end )
            end
        end

        self:RegisterVariable( key, function()
            return self.phases[ key ].virtual[ display or "Primary" ]
        end )
    end,

    RegisterGear = function( self, ... )
        local arg1 = select( 1, ... )
        if not arg1 then return end

        -- If the first arg is a table, it's registering multiple items/sets
        if type( arg1 ) == "table" then
            for set, data in pairs( arg1 ) do
                self:RegisterGear( set, data )
            end
            return
        end

        local arg2 = select( 2, ... )
        if not arg2 then return end

        -- If the first arg is a string, register it
        if type( arg1 ) == "string" then
            local gear = self.gear[ arg1 ] or {}
            local found = false

            -- If the second arg is a table, it's a tier set with auras
            if type( arg2 ) == "table" then
                if arg2.items then
                    for _, item in ipairs( arg2.items ) do
                        if not gear[ item ] then
                            table.insert( gear, item )
                            gear[ item ] = true
                            found = true
                        end
                    end
                end

                if arg2.auras then
                    -- Register auras (even if no items are found, can be useful for early patch testing).
                    self:RegisterAuras( arg2.auras )
                end
            end

            -- If the second arg is a number, this is a legacy registration with a single set/item
            if type( arg2 ) == "number" then
                local n = select( "#", ... )

                for i = 2, n do
                    local item = select( i, ... )

                    if not gear[ item ] then
                        table.insert( gear, item )
                        gear[ item ] = true
                        found = true
                    end
                end
            end

            if found then
                self.gear[ arg1 ] = gear
                CommitKey( arg1 )
            end

            return
        end

        -- Debug print if needed
        -- Hekili:Print( "|cFFFF0000[Hekili]|r Invalid input passed to RegisterGear." )
    end,


    -- Check for the set bonus based on hidden aura instead of counting the number of equipped items.
    -- This may be useful for tier set items that are crafted so their item ID doesn't match.
    -- The alternative is *probably* to treat sets based on bonusIDs.
    RegisterSetBonus = function( self, key, spellID )
        self.setBonuses[ key ] = spellID
        CommitKey( key )
    end,

    RegisterSetBonuses = function( self, ... )
        local n = select( "#", ... )

        for i = 1, n, 2 do
            self:RegisterSetBonus( select( i, ... ) )
        end
    end,

    RegisterPotion = function( self, potion, data )
        self.potions[ potion ] = data

        data.key = potion

        if data.items then
            if type( data.items ) == "table" then
                for _, key in ipairs( data.items ) do
                    self.potions[ key ] = data
                    CommitKey( key )
                end
            else
                self.potions[ data.items ] = data
                CommitKey( data.items )
            end
        end

        -- MoP compatibility: Use basic item info instead of Item callback system
        local name, link = GetItemInfo( data.item )
        if name then
            data.name = name
            data.link = link
            class.potionList[ potion ] = link
        end

        CommitKey( potion )
    end,

    RegisterPotions = function( self, potions )
        for k, v in pairs( potions ) do
            self:RegisterPotion( k, v )
        end
    end,

    RegisterRecheck = function( self, func )
        self.recheck = func
    end,

    RegisterHook = function( self, hook, func, noState )
        if not ( noState == true or hook == "COMBAT_LOG_EVENT_UNFILTERED" and noState == nil ) then
            func = setfenv( func, state )
        end
        self.hooks[ hook ] = self.hooks[ hook ] or {}
        insert( self.hooks[ hook ], func )
    end,

    RegisterAbility = function( self, ability, data )
        CommitKey( ability )

        local a = setmetatable( {
            funcs = {},
        }, {
            __index = function( t, k )
                local setup = rawget( t, "onLoad" )
                if setup then
                    t.onLoad = nil
                    setup( t )
                    return t[ k ]
                end

                if t.funcs[ k ] then return t.funcs[ k ]() end
                if k == "lastCast" then return state.history.casts[ t.key ] or t.realCast end
                if k == "lastUnit" then return state.history.units[ t.key ] or t.realUnit end
            end,
        } )

        a.key = ability
        a.from = self.id

        if not data.id then
            if data.item then
                class.specs[ 0 ].itemAbilities = class.specs[ 0 ].itemAbilities + 1
                data.id = -100 - class.specs[ 0 ].itemAbilities
            else
                self.pseudoAbilities = self.pseudoAbilities + 1
                data.id = -1000 * self.id - self.pseudoAbilities
            end
            a.id = data.id
        end

        if data.id and type( data.id ) == "function" then
            if not data.copy or type( data.copy ) == "table" and #data.copy == 0 then
                Hekili:Error( "RegisterAbility for %s (Specialization %d) will fail; ability has an ID function but needs to have 'copy' entries for the abilities table.", ability, self.id )
            end
        end


        local item = data.item
        if item and type( item ) == "function" then
            setfenv( item, state )
            item = item()
        end

        if data.meta then
            for k, v in pairs( data.meta ) do
                if type( v ) == "function" then data.meta[ k ] = setfenv( v, state ) end
            end
        end

        -- default values.
        if not data.cast     then data.cast     = 0             end
        if not data.cooldown then data.cooldown = 0             end
        if not data.recharge then data.recharge = data.cooldown end
        if not data.charges  then data.charges  = 1             end

        if data.hasteCD then
            if type( data.cooldown ) == "number" and data.cooldown > 0 then data.cooldown = Hekili:Loadstring( "return " .. data.cooldown .. " * haste" ) end
            if type( data.recharge ) == "number" and data.recharge > 0 then data.recharge = Hekili:Loadstring( "return " .. data.recharge .. " * haste" ) end
        end

        if not data.fixedCast and type( data.cast ) == "number" then
            data.cast = Hekili:Loadstring( "return " .. data.cast .. " * haste" )
        end

        if data.toggle == "interrupts" and data.gcd == "off" and data.readyTime == state.timeToInterrupt and data.interrupt == nil then
            data.interrupt = true
        end

        for key, value in pairs( data ) do
            if type( value ) == "function" then
                setfenv( value, state )

                if not protectedFunctions[ key ] then a.funcs[ key ] = value
                else a[ key ] = value end
                data[ key ] = nil
            else
                a[ key ] = value
            end
        end

        if ( a.velocity or a.flightTime ) and a.impact and a.isProjectile == nil then
            a.isProjectile = true
        end        a.realCast = 0

        if item then
            -- Simple item mapping like in Cataclysm
            class.itemMap[ item ] = ability

            -- Register the item if it doesn't already exist.
            class.specs[0]:RegisterGear( ability, item )
            if data.copy then
                if type( data.copy ) == "table" then
                    for _, iID in ipairs( data.copy ) do
                        if type( iID ) == "number" and iID < 0 then class.specs[0]:RegisterGear( ability, -iID ) end
                    end
                else
                    if type( data.copy ) == "number" and data.copy < 0 then class.specs[0]:RegisterGear( ability, -data.copy ) end
                end
            end
        end

        if data.items then
            for _, itemID in ipairs( data.items ) do
                class.itemMap[ itemID ] = ability
                class.specs[0]:RegisterGear( ability, itemID )
            end
        end

        if a.id and a.id > 0 then
            -- Hekili:ContinueOnSpellLoad( a.id, function( success )
            a.onLoad = function()
                local name, rank, icon, castTime, minRange, maxRange, spellId = OriginalGetSpellInfo( a.id )

                if name == nil then
                    -- Try GetItemInfo as fallback
                    name = GetItemInfo( a.id )
                end

                if name then
                    a.name = name

                    if a.suffix then
                        a.actualName = a.name
                        a.name = a.name .. " " .. a.suffix
                    end

                    a.desc = GetSpellDescription( a.id ) -- was returning raw tooltip data.

                    local texture = a.texture or icon or GetSpellTexture( a.id ) or "Interface\\Icons\\INV_Misc_QuestionMark"

                    self.abilities[ a.name ] = self.abilities[ a.name ] or a
                    class.abilities[ a.name ] = class.abilities[ a.name ] or a

                    if not a.unlisted then
                        class.abilityList[ ability ] = a.listName or ( "|T" .. texture .. ":0|t " .. a.name )
                        class.abilityByName[ a.name ] = class.abilities[ a.name ] or a
                    end

                    if a.rangeSpell and type( a.rangeSpell ) == "number" then
                        Hekili:ContinueOnSpellLoad( a.rangeSpell, function( success )
                            if success then
                                local rangeSpellName = OriginalGetSpellInfo( a.rangeSpell )
                                if rangeSpellName then
                                    a.rangeSpell = rangeSpellName
                                else
                                    a.rangeSpell = nil
                                end
                            else
                                a.rangeSpell = nil
                            end
                        end )
                    end

                    Hekili.OptionsReady = false
                else
                    for k, v in pairs( class.abilityList ) do
                        if v == a then class.abilityList[ k ] = nil end
                    end
                    Hekili.InvalidSpellIDs = Hekili.InvalidSpellIDs or {}
                    table.insert( Hekili.InvalidSpellIDs, a.id )
                    Hekili:Error( "Name info not available for " .. a.id .. "." )
                    return
                end
            end
        end

        -- Store by ability key on the spec (existing behavior).
        self.abilities[ ability ] = a
        -- Also store by ability key in the global class ability map so that import/parse
        -- routines (which reference class.abilities[ key ]) can detect spec abilities.
        -- Previously, only the localized spell name (a.name) was inserted which caused
        -- "Unsupported action" warnings for valid spec ability keys during APL import.
        if not class.abilities[ ability ] then
            class.abilities[ ability ] = a
        end
        self.abilities[ a.id ] = a

        if not a.unlisted then class.abilityList[ ability ] = class.abilityList[ ability ] or a.listName or a.name end

        if data.copy then
            if type( data.copy ) == "string" or type( data.copy ) == "number" then
                self.abilities[ data.copy ] = a
            elseif type( data.copy ) == "table" then
                for _, key in ipairs( data.copy ) do
                    self.abilities[ key ] = a
                end
            end
        end

        if data.items then
            for _, itemID in ipairs( data.items ) do
                class.itemMap[ itemID ] = ability
            end
        end

        if a.dual_cast or a.funcs.dual_cast then
            self.can_dual_cast = true
            self.dual_cast[ a.key ] = true
        end

        if a.empowered or a.funcs.empowered then
            self.can_empower = true
        end

        if a.auras then
            self:RegisterAuras( a.auras )
        end
    end,    RegisterAbilities = function( self, abilities )
        for ability, data in pairs( abilities ) do
            self:RegisterAbility( ability, data )
        end

        -- If this is spec 0 (all), copy the new abilities to all other specs
        if self.id == 0 then
            for specID, spec in pairs( class.specs ) do
                if specID ~= 0 then
                    local copiedCount = 0
                    for ability, data in pairs( abilities ) do
                        if not spec.abilities[ability] then
                            spec.abilities[ability] = data
                            copiedCount = copiedCount + 1
                        end
                        -- Also ensure they're in the global abilities table
                        if not class.abilities[ability] then
                            class.abilities[ability] = data
                        end
                    end
                    if copiedCount > 0 then
                        -- Successfully copied shared abilities
                    end
                end
            end
        end
    end,

    RegisterPack = function( self, name, version, import )
        self.packs[ name ] = {
            version = tonumber( version ),
            import = import:gsub("([^|])|([^|])", "%1||%2")
        }
    end,

    RegisterPriority = function( self, name, version, notes, priority )
    end,

    RegisterRanges = function( self, ... )
        if type( ... ) == "table" then
            self.ranges = ...
            return
        end

        for i = 1, select( "#", ... ) do
            insert( self.ranges, ( select( i, ... ) ) )
        end
    end,

    RegisterRangeFilter = function( self, name, func )
        self.filterName = name
        self.filter = func
    end,

    RegisterOptions = function( self, options )
        self.options = options
    end,

    RegisterEvent = function( self, event, func )
        RegisterEvent( event, function( ... )
            if state.spec.id == self.id then func( ... ) end
        end )
    end,

    RegisterUnitEvent = function( self, event, unit1, unit2, func )
        RegisterUnitEvent( event, unit1, unit2, function( ... )
            if state.spec.id == self.id then func( ... ) end
        end )
    end,

    RegisterCombatLogEvent = function( self, func )
        self:RegisterHook( "COMBAT_LOG_EVENT_UNFILTERED", func )
    end,

    RegisterCycle = function( self, func )
        self.cycle = setfenv( func, state )
    end,

    RegisterPet = function( self, token, id, spell, duration, ... )
        CommitKey( token )

        -- Prepare the main model
        local model = {
            id = type( id ) == "function" and setfenv( id, state ) or id,
            token = token,
            spell = spell,
            duration = type( duration ) == "function" and setfenv( duration, state ) or duration
        }

        -- Register the main pet token
        self.pets[ token ] = model

        -- Register copies, but avoid overwriting unrelated registrations
        local n = select( "#", ... )
        if n and n > 0 then
            for i = 1, n do
                local alias = select( i, ... )

                if self.pets[ alias ] and self.pets[ alias ] ~= model then
                    if Hekili.ActiveDebug then
                        Hekili:Debug( "RegisterPet: Alias '%s' already assigned to a different pet. Skipping for token '%s'.", tostring( alias ), tostring( token ) )
                    end
                else
                    self.pets[ alias ] = model
                end
            end
        end
    end,


    RegisterPets = function( self, pets )
        for token, data in pairs( pets ) do
            -- Extract fields from the pet definition.
            local id = data.id
            local spell = data.spell
            local duration = data.duration
            local copy = data.copy

            -- Register the pet and handle the copy field if it exists.
            if copy then
                self:RegisterPet( token, id, spell, duration, type( copy ) == "string" and copy or unpack( copy ) )
            else
                self:RegisterPet( token, id, spell, duration )
            end
        end
    end,

    RegisterTotem = function( self, token, id, ... )
        -- Register the primary totem.
        self.totems[ token ] = id
        self.totems[ id ] = token

        -- Handle copies if provided.
        local n = select( "#", ... )
        if n and n > 0 then
            for i = 1, n do
                local copy = select( i, ... )
                self.totems[ copy ] = id
                self.totems[ id ] = copy
            end
        end

        -- Commit the primary token.
        CommitKey( token )
    end,

    RegisterTotems = function( self, totems )
        for token, data in pairs( totems ) do
            local id = data.id
            local copy = data.copy

            -- Register the primary totem.
            self.totems[ token ] = id
            self.totems[ id ] = token

            -- Register any copies (aliases).
            if copy then
                if type( copy ) == "string" then
                    self.totems[ copy ] = id
                    self.totems[ id ] = copy
                elseif type( copy ) == "table" then
                    for _, alias in ipairs( copy ) do
                        self.totems[ alias ] = id
                        self.totems[ id ] = alias
                    end
                end
            end

            CommitKey( token )
        end
    end,

    GetSetting = function( self, info )
        local setting = info[ #info ]
        return Hekili.DB.profile.specs[ self.id ].settings[ setting ]
    end,

    SetSetting = function( self, info, val )
        local setting = info[ #info ]
        Hekili.DB.profile.specs[ self.id ].settings[ setting ] = val
    end,

    -- option should be an AceOption table.
    RegisterSetting = function( self, key, value, option )
        CommitKey( key )

        table.insert( self.settings, {
            name = key,
            default = value,
            info = option
        } )

        option.order = 100 + #self.settings

        option.get = option.get or function( info )
            local setting = info[ #info ]
            local val = Hekili.DB.profile.specs[ self.id ].settings[ setting ]

            if val ~= nil then return val end
            return value
        end

        option.set = option.set or function( info, val )
            local setting = info[ #info ]
            Hekili.DB.profile.specs[ self.id ].settings[ setting ] = val
        end
    end,

    -- For faster variables.
    RegisterVariable = function( self, key, func )
        CommitKey( key )
        self.variables[ key ] = setfenv( func, state )
    end,
}


function Hekili:RestoreDefaults()
    local p = self.DB.profile
    local reverted = {}
    local changed = {}

    for k, v in pairs( class.packs ) do
        local existing = rawget( p.packs, k )

        if not existing or not existing.version or existing.version ~= v.version then
            local data = self.DeserializeActionPack( v.import )

            if data and type( data ) == "table" then
                p.packs[ k ] = data.payload
                data.payload.version = v.version
                data.payload.date = v.version
                data.payload.builtIn = true

                if not existing or not existing.version or existing.version < v.version then
                    insert( changed, k )
                else
                    insert( reverted, k )
                end

                local specID = data.payload.spec

                if specID then
                    local spec = rawget( p.specs, specID )
                    if spec then
                        if spec.package then
                            local currPack = p.packs[ spec.package ]
                            if not currPack or currPack.spec ~= specID then
                                spec.package = k
                            end
                        else
                            spec.package = k
                        end
                    end
                end
            end
        end
    end

    if #changed > 0 or #reverted > 0 then
        self:LoadScripts()
    end

    if #changed > 0 then
        local msg

        if #changed == 1 then
            msg = "The |cFFFFD100" .. changed[1] .. "|r priority was updated."
        elseif #changed == 2 then
            msg = "The |cFFFFD100" .. changed[1] .. "|r and |cFFFFD100" .. changed[2] .. "|r priorities were updated."
        else
            msg = "|cFFFFD100" .. changed[1] .. "|r"

            for i = 2, #changed - 1 do
                msg = msg .. ", |cFFFFD100" .. changed[i] .. "|r"
            end

            msg = "The " .. msg .. ", and |cFFFFD100" .. changed[ #changed ] .. "|r priorities were updated."
        end

        if msg then
            C_Timer.After( 5, function()
                if Hekili.DB.profile.notifications.enabled then Hekili:Notify( msg, 6 ) end
                Hekili:Print( msg )
            end )
        end
    end

    if #reverted > 0 then
        local msg

        if #reverted == 1 then
            msg = "The |cFFFFD100" .. reverted[1] .. "|r priority was reverted."
        elseif #reverted == 2 then
            msg = "The |cFFFFD100" .. reverted[1] .. "|r and |cFFFFD100" .. reverted[2] .. "|r priorities were reverted."
        else
            msg = "|cFFFFD100" .. reverted[1] .. "|r"

            for i = 2, #reverted - 1 do
                msg = msg .. ", |cFFFFD100" .. reverted[i] .. "|r"
            end

            msg = "The " .. msg .. ", and |cFFFFD100" .. reverted[ #reverted ] .. "|r priorities were reverted."
        end

        if msg then
            C_Timer.After( 6, function()
                if Hekili.DB.profile.notifications.enabled then Hekili:Notify( msg, 6 ) end
                Hekili:Print( msg )
            end )
        end
    end
end


function Hekili:RestoreDefault( name )
    local p = self.DB.profile

    local default = class.packs[ name ]

    if default then
        local data = self.DeserializeActionPack( default.import )

        if data and type( data ) == "table" then
            p.packs[ name ] = data.payload
            data.payload.version = default.version
            data.payload.date = default.version
            data.payload.builtIn = true
        end
    end
end


ns.restoreDefaults = function( category, purge )
end


ns.isDefault = function( name, category )
    if not name or not category then
        return false
    end

    for i, default in ipairs( class.defaults ) do
        if default.type == category and default.name == name then
            return true, i
        end
    end

    return false
end

function Hekili:NewSpecialization( specID, isRanged, icon )

    if not specID or specID < 0 then return end

    local id, name, _, texture, role, pClass

    -- MoP Classic: Always use spec ID directly
    id = specID
    texture = icon

    if not id then
        Hekili:Error( "Unable to generate specialization DB for spec ID #" .. specID .. "." )
        return nil
    end

    if specID ~= 0 then
        class.initialized = true
    end

    local token = ns.getSpecializationKey( id )

    local spec = class.specs[ id ] or {
        id = id,
        key = token,
        name = name,
        texture = texture,
        role = role,
        class = pClass,
        melee = not isRanged,

        resources = {},
        resourceAuras = {},
        primaryResource = nil,
        primaryStat = nil,

        talents = {},
        pvptalents = {},
        powers = {},

        auras = {},
        pseudoAuras = 0,

        abilities = {},
        pseudoAbilities = 0,
        itemAbilities = 0,
        pendingItemSpells = {},

        pets = {},
        totems = {},

        potions = {},

        ranges = {},
        settings = {},

        stateExprs = {}, -- expressions are returned as values and take no args.
        stateFuncs = {}, -- functions can take arguments and can be used as helper functions in handlers.
        stateTables = {}, -- tables are... tables.

        gear = {},
        setBonuses = {},

        hooks = {},
        funcHooks = {},
        phases = {},
        interrupts = {},

        dual_cast = {},

        packs = {},
        options = {},

        variables = {}
    }

    class.num = class.num + 1

    for key, func in pairs( HekiliSpecMixin ) do
        spec[ key ] = func
    end    class.specs[ id ] = spec

    -- Copy shared abilities from spec 0 (all) to this spec (but not to spec 0 itself)
    if id ~= 0 and class.specs[0] then
        local copiedCount = 0
        for abilityKey, ability in pairs(class.specs[0].abilities) do
            if not spec.abilities[abilityKey] then
                spec.abilities[abilityKey] = ability
                copiedCount = copiedCount + 1
            end
        end
        -- Also ensure they're in the global abilities table
        for abilityKey, ability in pairs(class.specs[0].abilities) do
            if not class.abilities[abilityKey] then
                class.abilities[abilityKey] = ability
            end
        end
        if copiedCount > 0 then
            -- Shared abilities copied successfully
        end
    end

    return spec
end

function Hekili:GetSpecialization( specID )
    if not specID then return class.specs[ 0 ] end
    return class.specs[ specID ]
end


class.file = UnitClassBase( "player" )
local all = Hekili:NewSpecialization( 0, "All", "Interface\\Addons\\Hekili\\Textures\\LOGO-WHITE.blp" )

------------------------------
-- SHARED SPELLS/BUFFS/ETC. --
------------------------------

all:RegisterAuras({

    -- Can be used in GCD calculation.
    shadowform = {
        id = 15473,
        duration = 3600,
        max_stack = 1,
    },

    voidform = {
        id = 194249,
        duration = 15,
        max_stack = 1,
    },

    adrenaline_rush = {
        id = 13750,
        duration = 20,
        max_stack = 1,
    },

    -- Bloodlusts
    ancient_hysteria = {
        id = 90355,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    heroism = {
        id = 32182,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    time_warp = {
        id = 80353,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    netherwinds = {
        id = 160452,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    primal_rage = {
        id = 90355,
        shared = "player", -- use anyone's buff on the player, not just player's.
        duration = 40,
        max_stack = 1,
    },

    bloodlust = {
        alias = { "ancient_hysteria", "bloodlust_actual", "fury_of_the_aspects", "heroism", "netherwinds", "primal_rage", "time_warp" },
        aliasMode = "first",
        aliasType = "buff",
        duration = 3600,
    },

    bloodlust_actual = {
        id = 2825,
        duration = 40,
        shared = "player",
        max_stack = 1,
    },

    exhaustion = {
        id = 57723,
        duration = 600,
        shared = "player",
        max_stack = 1,
        copy = 390435
    },

    insanity = {
        id = 95809,
        duration = 600,
        shared = "player",
        max_stack = 1
    },

    temporal_displacement = {
        id = 80354,
        duration = 600,
        shared = "player",
        max_stack = 1
    },

    fury_of_the_aspects = {
        id = 90355, -- Ancient Hysteria (MoP bloodlust from Core Hound)
        duration = 40,
        max_stack = 1,
        shared = "player",
    },

    mark_of_the_wild = {
        id = 1126,
        duration = 3600,
        max_stack = 1,
        shared = "player",
    },

    sated = {
        alias = { "exhaustion", "insanity", "sated_actual", "temporal_displacement" },
        aliasMode = "first",
        aliasType = "debuff",
        duration = 3600,
    },

    sated_actual = {
        id = 57724,
        duration = 600,
        shared = "player",
        max_stack = 1,
    },

    power_infusion = {
        id = 10060,
        duration = 20,
        max_stack = 1,
        shared = "player",
        dot = "buff"
    },

    battle_shout = {
        id = 6673,
        duration = 3600,
        max_stack = 1,
        shared = "player",
        dot = "buff"
    },

    -- SL Season 3
    old_war = {
        id = 188028,
        duration = 25,
    },

    deadly_grace = {
        id = 188027,
        duration = 25,
    },

    dextrous = {
        id = 146308,
        duration = 20,
    },

    vicious = {
        id = 148903,
        duration = 10,
    },

    -- WoD Legendaries
    archmages_incandescence_agi = {
        id = 177161,
        duration = 10,
    },

    archmages_incandescence_int = {
        id = 177159,
        duration = 10,
    },

    archmages_incandescence_str = {
        id = 177160,
        duration = 10,
    },

    archmages_greater_incandescence_agi = {
        id = 177172,
        duration = 10,
    },

    archmages_greater_incandescence_int = {
        id = 177176,
        duration = 10,
    },

    archmages_greater_incandescence_str = {
        id = 177175,
        duration = 10,
    },

    maalus = {
        id = 187620,
        duration = 15,
    },

    thorasus = {
        id = 187619,
        duration = 15,
    },

    str_agi_int = {
        duration = 3600,
    },

    -- removed duplicate generic stamina; detailed MoP stamina aura defined later

    attack_power_multiplier = {
        duration = 3600,
    },

    haste = {
        duration = 3600,
    },

    spell_power_multiplier = {
        duration = 3600,
    },

    critical_strike = {
        duration = 3600,
    },

    versatility = {
        duration = 3600,
    },


    casting = {
        name = "Casting",
        generate = function( t, auraType )
            local unit = auraType == "debuff" and "target" or "player"

            if unit == "player" or UnitCanAttack( "player", unit ) then
                local spell, _, _, startCast, endCast, _, _, notInterruptible, spellID = UnitCastingInfo( unit )

                if spell then
                    startCast = startCast / 1000
                    endCast = endCast / 1000

                    t.name = spell
                    t.count = 1
                    t.expires = endCast
                    t.applied = startCast
                    t.duration = endCast - startCast
                    t.v1 = spellID
                    t.v2 = notInterruptible and 1 or 0
                    t.v3 = 0
                    t.caster = unit

                    if unit ~= "target" then return end

                    if state.target.is_dummy then
                        -- Pretend that all casts by target dummies are interruptible.
                        if Hekili.ActiveDebug then Hekili:Debug( "Cast '%s' is fake-interruptible", spell ) end
                        t.v2 = 0

                    elseif Hekili.DB.profile.toggles.interrupts.filterCasts and class.spellFilters[ state.instance_id ] and class.interruptibleFilters and not class.interruptibleFilters[ spellID ] then
                        if Hekili.ActiveDebug then Hekili:Debug( "Cast '%s' not interruptible per user preference.", spell ) end
                        t.v2 = 1
                    end

                    return
                end

                spell, _, _, startCast, endCast, _, notInterruptible, spellID = UnitChannelInfo( unit )
                startCast = ( startCast or 0 ) / 1000
                endCast = ( endCast or 0 ) / 1000
                local duration = endCast - startCast

                -- Channels greater than 10 seconds are nonsense.  Probably.
                if spell and duration <= 10 then
                    t.name = spell
                    t.count = 1
                    t.expires = endCast
                    t.applied = startCast
                    t.duration = duration
                    t.v1 = spellID
                    t.v2 = notInterruptible and 1 or 0
                    t.v3 = 1 -- channeled.
                    t.caster = unit

                    if class.abilities[ spellID ] and class.abilities[ spellID ].dontChannel then
                        removeBuff( "casting" )
                        return
                    end

                    if unit ~= "target" then return end

                    if state.target.is_dummy then
                        -- Pretend that all casts by target dummies are interruptible.
                        if Hekili.ActiveDebug then Hekili:Debug( "Channel '%s' is fake-interruptible", spell ) end
                        t.v2 = 0

                    elseif Hekili.DB.profile.toggles.interrupts.filterCasts and class.spellFilters[ state.instance_id ] and class.interruptibleFilters and not class.interruptibleFilters[ spellID ] then
                        if Hekili.ActiveDebug then Hekili:Debug( "Channel '%s' not interruptible per user preference.", spell ) end
                        t.v2 = 1
                    end

                    return
                end
            end

            t.name = "Casting"
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.v1 = 0
            t.v2 = 0
            t.v3 = 0
            t.caster = unit
        end,
    },

    movement = {
        duration = 5,
        max_stack = 1,
        generate = function ()
            local m = buff.movement

            if moving then
                m.count = 1
                m.expires = query_time + 5
                m.applied = query_time
                m.caster = "player"
                return
            end

            m.count = 0
            m.expires = 0
            m.applied = 0
            m.caster = "nobody"
        end,
    },

    -- MoP compatible aura instead of retail repeat_performance
    gift_of_the_naaru = {
        id = 28880,
        duration = 15,
        max_stack = 1,
    },

    berserking = {
        id = 26297, -- Berserking (Troll, MoP ID)
        cast = 0,
        cooldown = 180,
        gcd = "off",
        toggle = "cooldowns",
        handler = function ()
            applyBuff( "berserking" )
        end,
    },

    blood_fury = {
        id = 20572,
        duration = 15,
    },

    shadowmeld = {
        id = 58984,
        duration = 3600,
    },

    -- MoP racial auras
    ancestral_call = {
        id = 33697, -- Blood Fury for casters
        duration = 15,
    },

    arcane_pulse = {
        id = 28880, -- Gift of the Naaru
        duration = 15,
    },

    hyper_organic_light_originator = {
        id = 58984, -- Shadowmeld
        duration = 3600,
    },

    fireblood = {
        id = 65116, -- Stoneform
        duration = 8,
    },

    stoneform = {
        id = 65116,
        duration = 8,
    },

    war_stomp = {
        id = 20549,
        duration = 2,
    },

    -- MoP Buff Categories
    stats = {
        id = 20217, -- Use Blessing of Kings as primary ID
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            -- Blessing of Kings
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 20217)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Embrace of the Shale Spider
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 90363)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Legacy of the Emperor
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 117666)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Mark of the Wild
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 1126)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- No stats buff found
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    mastery = {
        id = 19740, -- Use Blessing of Might as primary ID
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            -- Blessing of Might
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 19740)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Grace of Air (Shaman)
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116956)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Roar of Courage (Hunter pet)
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 93435)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Spirit Beast Blessing (Hunter pet)
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 128997)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- No mastery buff found
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    stamina = {
        id = 21562, -- Use Fortitude as primary ID
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            -- Commanding Shout
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 469)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Power Word: Fortitude
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 21562)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Dark Intent
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 109773)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Qiraji Fortitude (Pet)
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 90364)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- No stamina buff found
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    crit = {
        id = 1459, -- Use Arcane Brilliance as primary ID
        duration = 3600,
        max_stack = 1,
        generate = function( t )
            -- Arcane Brilliance
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 1459)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Furious Howl (Pet)
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 24604)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Leader of the Pack
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 17007)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Legacy of the White Tiger
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 116781)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Terrifying Roar
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 112928)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- Still Water
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitBuffByID("player", 126309)
            if name then
                t.name = name
                t.count = 1
                t.expires = expirationTime or 0
                t.applied = (expirationTime and duration) and (expirationTime - duration) or 0
                t.caster = caster
                t.up = true
                t.down = false
                t.remains = expirationTime and (expirationTime - GetTime()) or 0
                return
            end

            -- No mastery buff found
            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.up = false
            t.down = true
            t.remains = 0
        end
    },

    -- Spell Vulnerability family
    magic_vulnerability = {
        alias = {
            "curse_of_elements",
            "master_poisoner",
            "fire_breath",
            "lightning_breath"
        },
        aliasMode = "first",
        aliasType = "debuff",
        shared = "target",
    },

    curse_of_elements = {
        id = 1490,
        duration = 300,
        max_stack = 1,
        debuff = true,
        shared = "target",
        generate = function( t )
            -- Try to find either 1490 or 104225
            local name, icon, count, debuffType, duration, expirationTime, caster
            name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 1490 )
            if not name then
                name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 104225 )
            end

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 300
            return
        end,

        copy = { 104225 },
    },

    master_poisoner = {
        id = 58410,
        duration = 15,
        max_stack = 1,
        debuff = true,
        shared = "target",
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 58410 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 15
            return
        end,
    },

    fire_breath = {
        id = 34889,
        duration = 15,
        max_stack = 1,
        debuff = true,
        shared = "target",
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 34889 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 15
            return
        end,
    },

    lightning_breath = {
        id = 24844,
        duration = 12,
        max_stack = 1,
        debuff = true,
        shared = "target",
        generate = function( t )
            local name, icon, count, debuffType, duration, expirationTime, caster = FindUnitDebuffByID( "target", 24844 )

            if name and caster == "player" then
                t.name = name
                t.count = 1
                t.expires = expirationTime
                t.applied = expirationTime - duration
                t.caster = caster
                t.duration = duration
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
            t.duration = 12
            return
        end,
    },

    out_of_range = {
        generate = function ( oor )
            oor.rangeSpell = rawget( oor, "rangeSpell" ) or settings.spec.rangeChecker or class.specs[ state.spec.id ].ranges[ 1 ]

            if LSR.IsSpellInRange( class.abilities[ oor.rangeSpell ].name, "target" ) ~= 1 then
                oor.count = 1
                oor.applied = query_time
                oor.expires = query_time + 3600
                oor.caster = "player"
                oor.v1 = oor.rangeSpell
                return
            end

            oor.count = 0
            oor.applied = 0
            oor.expires = 0
            oor.caster = "nobody"
        end,
    },

    loss_of_control = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = 0, 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )

                    if event.lockoutSchool == 0 and event.startTime and event.startTime > 0 and event.timeRemaining and event.timeRemaining > 0 and event.timeRemaining > remains then
                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    disoriented = { -- Disorients (e.g., Polymorph, Dragon's Breath, Blind)
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = 0, 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )
                    if event and event.locType == "CONFUSE"
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > query_time then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    feared = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = 0, 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )
                    if event and ( event.locType == "FEAR" or event.locType == "FEAR_MECHANIC" or event.locType == "HORROR" )
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > (query_time or 0) then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    incapacitated = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = 0, 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )
                    if event and (event.locType == "INCAPACITATE" or event.locType == "STUN")
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > (query_time or 0) then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
        copy = "sapped"
    },

    rooted = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = 0, 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )
                    if event and event.locType == "ROOT"
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > (query_time or 0) then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    snared = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = 0, 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )
                    if event and event.locType == "SNARE"
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > (query_time or 0) then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
        copy = "slowed"
    },

    stunned = {
        duration = 10,
        generate = function( t )
            local max_events = GetActiveLossOfControlDataCount()

            if max_events > 0 then
                local spell, start, duration, remains = 0, 0, 0, 0

                for i = 1, max_events do
                    local event = GetActiveLossOfControlData( i )
                    if event and event.locType == "STUN_MECHANIC"
                        and event.startTime and event.startTime > 0
                        and event.timeRemaining and event.timeRemaining > 0
                        and event.timeRemaining > remains then

                        spell = event.spellID
                        start = event.startTime
                        duration = event.duration
                        remains = event.timeRemaining
                    end
                end

                if start + duration > (query_time or 0) then
                    t.count = 1
                    t.expires = start + duration
                    t.applied = start
                    t.duration = duration
                    t.caster = "anybody"
                    t.v1 = spell
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.duration = 10
            t.caster = "nobody"
            t.v1 = 0
        end,
    },

    dispellable_curse = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Curse" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_poison = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Poison" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_disease = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Disease" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_magic = {
        generate = function( t, auraType )
            if auraType == "buff" then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "Magic" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end

            else
                local i = 1
                local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

                while( name ) do
                    if debuffType == "Magic" then
                        -- Found a Magic debuff, handle after the loop
                    else
                        i = i + 1
                        name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
                    end
                end

                if name and debuffType == "Magic" then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end

            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    stealable_magic = {
        generate = function( t )
            if UnitCanAttack( "player", "target" ) then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "Magic" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    reversible_magic = {
        generate = function( t )
            local i = 1
            local name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )

            while( name ) do
                if debuffType == "Magic" then break end

                i = i + 1
                name, _, count, debuffType, duration, expirationTime = UnitDebuff( "player", i, "RAID" )
            end

            if name then
                t.count = count > 0 and count or 1
                t.expires = expirationTime > 0 and expirationTime or query_time + 5
                t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                t.caster = "nobody"
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    dispellable_enrage = {
        generate = function( t )
            if UnitCanAttack( "player", "target" ) then
                local i = 1
                local name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )

                while( name ) do
                    if debuffType == "" and canDispel then break end

                    i = i + 1
                    name, _, count, debuffType, duration, expirationTime, _, canDispel = UnitBuff( "target", i )
                end

                if canDispel then
                    t.count = count > 0 and count or 1
                    t.expires = expirationTime > 0 and expirationTime or query_time + 5
                    t.applied = expirationTime > 0 and ( expirationTime - duration ) or query_time
                    t.caster = "nobody"
                    return
                end
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
    },

    all_absorbs = {
        duration = 15,
        max_stack = 1,
        -- TODO: Check if function works.
        generate = function( t, auraType )
            local unit = auraType == "debuff" and "target" or "player"
            local amount = UnitGetTotalAbsorbs( unit )

            if amount > 0 then
                -- t.name = ABSORB
                t.count = 1
                t.expires = state.query_time + 10
                t.applied = state.query_time - 5
                t.caster = unit
                return
            end

            t.count = 0
            t.expires = 0
            t.applied = 0
            t.caster = "nobody"
        end,
        copy = "unravel_absorb"
    },

    -- Food and drink auras for MoP Classic
    food = {
        id = 433,
        duration = 30,
        max_stack = 1,
    },

    drink = {
        id = 430,
        duration = 30,
        max_stack = 1,
    },
})

do
    -- MoP Classic Potions - Simplified for compatibility
    local mop_potions = {
        {
            name = "virmen_bite",
            item = 76089,
            duration = 25
        },
        {
            name = "potion_of_mogu_power",
            item = 76093,
            duration = 25
        },
        {
            name = "potion_of_the_jade_serpent",
            item = 76092,
            duration = 25
        },
        {
            name = "flask_of_spring_blossoms",
            item = 76083,
            duration = 3600
        },
        {
            name = "flask_of_the_warm_sun",
            item = 76084,
            duration = 3600
        },
        {
            name = "flask_of_falling_leaves",
            item = 76085,
            duration = 3600
        },
        {
            name = "flask_of_the_earth",
            item = 76086,
            duration = 3600
        },
        {
            name = "flask_of_winter_bite",
            item = 76087,
            duration = 3600
        }
    }

    -- Register generic potion aura
    all:RegisterAura( "potion", {
        duration = 30,
        max_stack = 1,
    } )

    local first_potion, first_potion_key
    local potion_items = {}

    all:RegisterHook( "reset_precast", function ()
        wipe( potion_items )
        for _, potion in ipairs( mop_potions ) do
            if GetItemCount( potion.item, false ) > 0 then
                potion_items[ potion.name ] = potion.item
                if not first_potion then
                    first_potion = potion.item
                    first_potion_key = potion.name
                end
            end
        end
    end )

    for _, potion in ipairs( mop_potions ) do
        local name, link, _, _, _, _, _, _, _, texture = GetItemInfo( potion.item )

        all:RegisterAbility( potion.name, {
            name = name or potion.name,
            listName = link or name or potion.name,
            cast = 0,
            cooldown = potion.duration < 100 and 60 or 0, -- Potions have 60s CD, flasks don't
            gcd = "off",

            startsCombat = false,
            toggle = "potions",

            item = potion.item,
            bagItem = true,
            texture = texture,

            usable = function ()
                return GetItemCount( potion.item ) > 0, "requires " .. (name or potion.name) .. " in bags"
            end,

            readyTime = function ()
                local start, duration = SafeGetItemCooldown( potion.item )
                return max( 0, start + duration - query_time )
            end,

            handler = function ()
                applyBuff( potion.name, potion.duration )
            end,
        } )

        -- Register aura for the potion
        all:RegisterAura( potion.name, {
            duration = potion.duration,
            max_stack = 1,
        } )

        class.abilities[ potion.name ] = all.abilities[ potion.name ]
        class.potions[ potion.name ] = {
            name = name or potion.name,
            link = link or name or potion.name,
            item = potion.item
        }

        class.potionList[ potion.name ] = "|T" .. (texture or 136243) .. ":0|t |cff00ccff[" .. (name or potion.name) .. "]|r"
    end

    -- Generic potion ability
    all:RegisterAbility( "potion", {
        name = "Potion",
        listName = '|T136243:0|t |cff00ccff[Potion]|r',
        cast = 0,
        cooldown = 60,
        gcd = "off",

        startsCombat = false,
        toggle = "potions",

        item = function()
            return first_potion or 76089 -- Default to Virmen Bite
        end,
        bagItem = true,

        usable = function ()
            return first_potion ~= nil, "no valid potions found in inventory"
        end,

        handler = function ()
            if first_potion_key and all.abilities[ first_potion_key ] then
                all.abilities[ first_potion_key ].handler()
            else
                applyBuff( "potion", 25 )
            end
        end,

        copy = "potion_default"
    } )
end




local gotn_classes = {
    WARRIOR = 28880,
    MONK = 121093,
    DEATHKNIGHT = 59545,
    SHAMAN = 59547,
    HUNTER = 59543,
    PRIEST = 59544,
    MAGE = 59548,
    PALADIN = 59542,
    ROGUE = 59546
}

local baseClass = UnitClassBase( "player" ) or "WARRIOR"

all:RegisterAura( "gift_of_the_naaru", {
    id = gotn_classes[ baseClass ],
    duration = 5,
    max_stack = 1,
    copy = { 28800, 121093, 59545, 59547, 59543, 59544, 59548, 59542, 59546 }
} )

all:RegisterAbility( "gift_of_the_naaru", {
    id = gotn_classes[ baseClass ],
    cast = 0,
    cooldown = 180,
    gcd = "off",

    handler = function ()
        applyBuff( "gift_of_the_naaru" )
    end,
} )


all:RegisterAbilities( {
    global_cooldown = {
        id = 61304,
        cast = 0,
        cooldown = 0,
        gcd = "spell",

        unlisted = true,
        known = function () return true end,
    },
} )

-- MoP Classic/Classic compatible racial abilities only
-- Blood Fury spell IDs vary by class (whether you need AP/Int/both).
local bf_classes = {
    DEATHKNIGHT = 20572,
    HUNTER = 20572,
    MAGE = 33702,
    MONK = 33697,
    ROGUE = 20572,
    SHAMAN = 33697,
    WARLOCK = 33702,
    WARRIOR = 20572,
    PRIEST = 33702
}

all:RegisterAbilities( {
    blood_fury = {
        id = function () return bf_classes[ class.file ] or 20572 end,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",

        -- usable = function () return race.orc end,
        handler = function ()
            applyBuff( "blood_fury", 15 )
        end,

        copy = { 33702, 20572, 33697 },
    },

    arcane_torrent = {
        id = function ()
            -- Version-specific spell IDs for Arcane Torrent
            if Hekili.IsMoP() then
                if class.file == "MAGE"         then return 28730 end
                if class.file == "PALADIN"      then return 28730 end
                if class.file == "PRIEST"       then return 28730 end
                if class.file == "WARLOCK"      then return 28730 end
                if class.file == "MONK"         then return 129597 end
                if class.file == "WARRIOR"      then return 69179 end
                if class.file == "ROGUE"        then return 25046 end
                if class.file == "DEATHKNIGHT"  then return 50613 end
                if class.file == "HUNTER"       then return 80483 end
                return 28730
            elseif Hekili.IsRetail() then
                -- Retail spell IDs
                if class.file == "PALADIN"      then return 155145 end
                if class.file == "MONK"         then return 129597 end
                if class.file == "DEATHKNIGHT"  then return  50613 end
                if class.file == "WARRIOR"      then return  69179 end
                if class.file == "ROGUE"        then return  25046 end
                if class.file == "HUNTER"       then return  80483 end
                if class.file == "DEMONHUNTER"  then return 202719 end
                if class.file == "PRIEST"       then return 232633 end
                return 28730
            else
                -- Default/Classic spell IDs
                if class.file == "DEATHKNIGHT"  then return  50613 end
                if class.file == "ROGUE"        then return  25046 end
                return 28730
            end
        end,
        cast = 0,
        cooldown = 120,
        gcd = "spell",

        -- It does start combat if there are enemies in range, but we often use it precombat for resources.
        startsCombat = false,

        -- usable = function () return race.blood_elf end,
        toggle = "cooldowns",

        handler = function ()
            if Hekili.IsMoP() then
                if class.file == "MAGE"         then gain( 2, "mana" ) end
                if class.file == "PALADIN"      then gain( 2, "mana" ) end
                if class.file == "PRIEST"       then gain( 2, "mana" ) end
                if class.file == "WARLOCK"      then gain( 2, "mana" ) end
                if class.file == "MONK"         then gain( 1, "chi" ) end
                if class.file == "WARRIOR"      then gain( 15, "rage" ) end
                if class.file == "ROGUE"        then gain( 15, "energy" ) end
                if class.file == "DEATHKNIGHT"  then gain( 15, "runic_power" ) end
                if class.file == "HUNTER"       then gain( 15, "focus" ) end
            elseif Hekili.IsRetail() then
                if class.file == "DEATHKNIGHT"  then gain( 20, "runic_power" ) end
                if class.file == "HUNTER"       then gain( 15, "focus" ) end
                if class.file == "MONK"         then gain( 1, "chi" ) end
                if class.file == "PALADIN"      then gain( 1, "holy_power" ) end
                if class.file == "ROGUE"        then gain( 15, "energy" ) end
                if class.file == "WARRIOR"      then gain( 15, "rage" ) end
                if class.file == "DEMONHUNTER"  then gain( 15, "fury" ) end
                if class.file == "PRIEST"       then gain( 15, "insanity" ) end
            end
            removeBuff( "dispellable_magic" )
        end,

        copy = { 155145, 129597, 50613, 69179, 25046, 80483, 202719, 232633 }
    },

    -- Herbalist special ability
    lifeblood = {
        id = 121279,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "cooldowns",

        copy = { 81708, 55428, 55480, 55500, 55501, 55502, 55503, 74497 },
    },

    will_to_survive = {
        id = 59752,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "defensives",
    },

    shadowmeld = {
        id = 58984,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        usable = function ()
            if not boss or solo then return false, "requires boss fight or group (to avoid resetting)" end
            if moving then return false, "can't shadowmeld while moving" end
            return true
        end,

        handler = function ()
            applyBuff( "shadowmeld" )
        end,
    },

    berserking = {
        id = 26297,
        cast = 0,
        cooldown = 180,
        gcd = "off",

        toggle = "cooldowns",

        -- usable = function () return race.troll end,
        handler = function ()
            applyBuff( "berserking", 10 )
        end,
    },

    stoneform = {
        id = 20594,
        cast = 0,
        cooldown = 120,
        gcd = "off",

        toggle = "defensives",

        buff = function()
            local aura, remains = "dispellable_poison", buff.dispellable_poison.remains

            for _, effect in pairs( { "dispellable_disease", "dispellable_curse", "dispellable_magic", "dispellable_bleed" } ) do
                local rem = buff[ effect ].remains
                if rem > remains then
                    aura = effect
                    remains = rem
                end
            end

            return aura
        end,

        handler = function ()
            removeBuff( "dispellable_poison" )
            removeBuff( "dispellable_disease" )
            removeBuff( "dispellable_curse" )
            removeBuff( "dispellable_magic" )
            removeBuff( "dispellable_bleed" )

            applyBuff( "stoneform" )
        end,

        auras = {
            stoneform = {
                id = 65116,
                duration = 8,
                max_stack = 1
            }
        }
    },
    -- INTERNAL HANDLERS
    call_action_list = {
        name = "|cff00ccff[Call Action List]|r",
        listName = '|T136243:0|t |cff00ccff[Call Action List]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },

    run_action_list = {
        name = "|cff00ccff[Run Action List]|r",
        listName = '|T136243:0|t |cff00ccff[Run Action List]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },    wait = {
        name = "|cff00ccff[Wait]|r",
        listName = '|T136243:0|t |cff00ccff[Wait]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },

    pool_resource = {
        name = "|cff00ccff[Pool Resource]|r",
        listName = "|T136243:0|t |cff00ccff[Pool Resource]|r",
        cast = 0,
        cooldown = 0,
        gcd = "off",
        known = function() return true end,
        usable = function() return true end,
    },    cancel_action = {
        name = "|cff00ccff[Cancel Action]|r",
        listName = "|T136243:0|t |cff00ccff[Cancel Action]|r",
        cast = 0,
        cooldown = 0,
        gcd = "off",
        known = function() return true end,

        usable = function ()
            local a = args.action_name
            local ability = class.abilities[ a ]
            if not a or not ability then return false, "no action identified" end
            if buff.casting.down or buff.casting.v3 ~= 1 then return false, "not channeling" end
            if buff.casting.v1 ~= ability.id then return false, "not channeling " .. a end
            return true
        end,
        timeToReady = function () return gcd.remains end,
    },

    variable = {
        name = "|cff00ccff[Variable]|r",
        listName = '|T136243:0|t |cff00ccff[Variable]|r',
        cast = 0,
        cooldown = 0,
        gcd = "off",
        essential = true,
        known = function() return true end,
        usable = function() return true end,
    },

    healthstone = {
        name = "Healthstone",
        listName = "|T538745:0|t |cff00ccff[Healthstone]|r",
        cast = 0,
        cooldown = function () return time > 0 and 3600 or 60 end,
        gcd = "off",

        item = function() return talent.pact_of_gluttony.enabled and 224464 or 5512 end,
        items = { 224464, 5512 },
        bagItem = true,

        startsCombat = false,
        texture = function() return talent.pact_of_gluttony.enabled and 538744 or 538745 end,

        usable = function ()
            local item = talent.pact_of_gluttony.enabled and 224464 or 5512
            if GetItemCount( item ) == 0 then return false, "requires healthstone in bags"
            elseif not IsUsableItem( item ) then return false, "healthstone on CD"
            elseif health.current >= health.max then return false, "must be damaged" end
            return true
        end,

        readyTime = function ()
            local start, duration = SafeGetItemCooldown( talent.pact_of_gluttony.enabled and 224464 or 5512 )
            return max( 0, start + duration - query_time )
        end,

        handler = function ()
            gain( 0.25 * health.max, "health" )
        end,
    },

    weyrnstone = {
        name = function () return ( GetItemInfo( 205146 ) ) or "Weyrnstone" end,
        listName = function ()
            local _, link, _, _, _, _, _, _, _, tex = GetItemInfo( 205146 )
            if link and tex then return "|T" .. tex .. ":0|t " .. link end
            return "|cff00ccff[Weyrnstone]|r"
        end,
        cast = 1.5,
        gcd = "spell",

        item = 205146,
        bagItem = true,

        startsCombat = false,
        texture = 5199618,

        usable = function ()
            if GetItemCount( 205146 ) == 0 then return false, "requires weyrnstone in bags" end
            if solo then return false, "must have an ally to teleport" end
            return true
        end,

        readyTime = function ()
            local start, duration = SafeGetItemCooldown( 205146 )
            return max( 0, start + duration - query_time )
        end,

        handler = function ()
        end,

        copy = { "use_weyrnstone", "active_weyrnstone" }
    },

    cancel_buff = {
        name = "|cff00ccff[Cancel Buff]|r",
        listName = '|T136243:0|t |cff00ccff[Cancel Buff]|r',
        cast = 0,
        gcd = "off",

        startsCombat = false,

        buff = function () return args.buff_name or nil end,

        indicator = "cancel",
        texture = function ()
            if not args.buff_name then return 134400 end

            local a = class.auras[ args.buff_name ]
            -- if not a then return 134400 end
            if a.texture then return a.texture end

            a = a and a.id
            a = a and GetSpellTexture( a )

            return a or 134400
        end,

        usable = function () return args.buff_name ~= nil, "no buff name detected" end,
        timeToReady = function () return gcd.remains end,
        handler = function ()
            if not args.buff_name then return end

            local cancel = args.buff_name and buff[ args.buff_name ]
            cancel = cancel and rawget( cancel, "onCancel" )

            if cancel then
                cancel()
                return
            end

            removeBuff( args.buff_name )
        end,
    },

    null_cooldown = {
        name = "|cff00ccff[Null Cooldown]|r",
        listName = "|T136243:0|t |cff00ccff[Null Cooldown]|r",
        cast = 0,
        cooldown = 0.001,
        gcd = "off",

        startsCombat = false,

        unlisted = true
    },

    trinket1 = {
        name = "|cff00ccff[Trinket #1]|r",
        listName = "|T136243:0|t |cff00ccff[Trinket #1]|r",
        cast = 0,
        cooldown = 600,
        gcd = "off",

        usable = false,

        copy = "actual_trinket1",
    },

    trinket2 = {
        name = "|cff00ccff[Trinket #2]|r",
        listName = "|T136243:0|t |cff00ccff[Trinket #2]|r",
        cast = 0,
        cooldown = 600,
        gcd = "off",

        usable = false,

        copy = "actual_trinket2",
    },

    main_hand = {
        name = "|cff00ccff[" .. INVTYPE_WEAPONMAINHAND .. "]|r",
        listName = "|T136243:0|t |cff00ccff[" .. INVTYPE_WEAPONMAINHAND .. "]|r",
        cast = 0,
        cooldown = 600,
        gcd = "off",

        usable = false,

        copy = "actual_main_hand",
    }
} )

-- Support 'use_item,slot=hands' by exposing a pseudo-ability that copies Synapse Springs.
-- This lets APLs request slot-based glove usage while we still drive behavior from synapse_springs.
all:RegisterAbility( "hands", {
    -- Keep simple labels; behavior is inherited from synapse_springs.
    name = "|cff00ccff[Hands]|r",
    listName = "|T136243:0|t |cff00ccff[Hands]|r",

    -- Copy all runtime behavior (cooldown, usable, item, handler, etc.).
    copy = "synapse_springs",

    -- Ensure the correct texture is always shown from the equipped gloves.
    item = function() return (tinker and tinker.hand and tinker.hand.item) or 0 end,
    texture = function()
        -- 1) Try the equipped glove's actual texture from the inventory slot.
        local tex = GetInventoryItemTexture("player", INVSLOT_HAND)
        if tex then return tex end

        -- 2) Try the cached texture from our tinker tracker.
        if tinker and tinker.hand and tinker.hand.texture then
            return tinker.hand.texture
        end

        -- 3) If we know the glove item, try its icon from item info (should be cached when equipped).
        local itemID = (tinker and tinker.hand and tinker.hand.item) or 0
        if itemID and itemID > 0 then
            local _, _, _, _, _, _, _, _, _, invTex = GetItemInfo(itemID)
            if invTex then return invTex end
        end

        -- 4) Fall back to Synapse Springs spell icon so it never shows a question mark.
        if GetSpellTexture then
            local sTex = GetSpellTexture(82174) or GetSpellTexture(96228) or GetSpellTexture(96229) or GetSpellTexture(96230)
            if sTex then return sTex end
        end

        -- 5) Final fallback.
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end,
} )


-- Use Items
do
    -- Should handle trinkets/items internally.
    -- 1.  Check APLs and don't try to recommend items that have their own APL entries.
    -- 2.  Respect item preferences registered in spec options.

    all:RegisterAbility( "use_items", {
        name = "Use Items",
        listName = "|T136243:0|t |cff00ccff[Use Items]|r",
        cast = 0,
        cooldown = 120,
        gcd = "off",
    } )

    all:RegisterAbility( "unusable_trinket", {
        name = "Unusable Trinket",
        listName = "|T136240:0|t |cff00ccff[Unusable Trinket]|r",
        cast = 0,
        cooldown = 180,
        gcd = "off",

        usable = false,
        unlisted = true
    } )

    all:RegisterAbility( "heart_essence", {
        name = function () return ( GetItemInfo( 158075 ) ) or "Heart Essence" end,
        listName = function ()
            local _, link, _, _, _, _, _, _, _, tex = GetItemInfo( 158075 )
            if link and tex then return "|T" .. tex .. ":0|t " .. link end
            return "|cff00ccff[Heart Essence]|r"
        end,
        cast = 0,
        cooldown = 0,
        gcd = "off",

        item = 158075,
        essence = true,

        toggle = "essences",

        usable = function () return false, "your equipped major essence is supported elsewhere in the priority or is not an active ability" end
    } )
end


-- x.x - Heirloom Trinket(s)
all:RegisterAbility( "touch_of_the_void", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 128318,
    toggle = "cooldowns",
} )

-- MoP Classic does not have the complex PvP trinket system from retail
-- Basic trinket usage is handled by the general trinket system

-- BREWFEST
all:RegisterAbility( "brawlers_statue", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 117357,
    toggle = "defensives",

    handler = function ()
        applyBuff( "drunken_evasiveness" )
    end
} )

all:RegisterAura( "drunken_evasiveness", {
    id = 127967,
    duration = 20,
    max_stack = 1
} )


-- HALLOW'S END
all:RegisterAbility( "the_horsemans_sinister_slicer", {
    cast = 0,
    cooldown = 600,
    gcd = "off",

    item = 117356,
    toggle = "cooldowns",
} )


ns.addToggle = function( name, default, optionName, optionDesc )

    table.insert( class.toggles, {
        name = name,
        state = default,
        option = optionName,
        oDesc = optionDesc
    } )

    if Hekili.DB.profile[ 'Toggle State: ' .. name ] == nil then
        Hekili.DB.profile[ 'Toggle State: ' .. name ] = default
    end

end


ns.addSetting = function( name, default, options )

    table.insert( class.settings, {
        name = name,
        state = default,
        option = options
    } )

    if Hekili.DB.profile[ 'Class Option: ' .. name ] == nil then
        Hekili.DB.profile[ 'Class Option: ' ..name ] = default
    end

end


ns.addWhitespace = function( name, size )

    table.insert( class.settings, {
        name = name,
        option = {
            name = " ",
            type = "description",
            desc = " ",
            width = size
        }
    } )

end


ns.addHook = function( hook, func )
    insert( class.hooks[ hook ], func )
end


do
    local inProgress = {}
    local vars = {}

    local function load_args( ... )
        local count = select( "#", ... )
        if count == 0 then return end

        for i = 1, count do
            vars[ i ] = select( i, ... )
        end
    end    ns.callHook = function( event, ... )
        if not class or not class.hooks or not class.hooks[ event ] or inProgress[ event ] then return ... end
        wipe( vars )
        load_args( ... )

        inProgress[ event ] = true
        for i, hook in ipairs( class.hooks[ event ] ) do
            load_args( hook( unpack( vars ) ) )
        end
        inProgress[ event ] = nil

        return unpack( vars )
    end
end


ns.registerCustomVariable = function( var, default )
    state[ var ] = default
end




ns.setClass = function( name )
    -- deprecated.
    --class.file = name
end


function ns.setRange( value )
    class.range = value
end


local function storeAbilityElements( key, values )

    local ability = class.abilities[ key ]

    if not ability then
        ns.Error( "storeAbilityElements( " .. key .. " ) - no such ability in abilities table." )
        return
    end

    for k, v in pairs( values ) do
        ability.elem[ k ] = type( v ) == "function" and setfenv( v, state ) or v
    end

end
ns.storeAbilityElements = storeAbilityElements


local function modifyElement( t, k, elem, value )

    local entry = class[ t ][ k ]

    if not entry then
        ns.Error( "modifyElement() - no such key '" .. k .. "' in '" .. t .. "' table." )
        return
    end

    if type( value ) == "function" then
        entry.mods[ elem ] = setfenv( value, Hekili.State )
    else
        entry.elem[ elem ] = value
    end

end
ns.modifyElement = modifyElement



local function setUsableItemCooldown( cd )
    state.setCooldown( "usable_items", cd or 10 )
end


-- For Trinket Settings.
class.itemSettings = {}

local function addItemSettings( key, itemID, options )

    options = options or {}

    --[[ options.icon = {
        type = "description",
        name = function () return select( 2, GetItemInfo( itemID ) ) or format( "[%d]", itemID )  end,
        order = 1,
        image = function ()
            local tex = select( 10, GetItemInfo( itemID ) )
            if tex then
                return tex, 50, 50
            end
            return nil
        end,
        imageCoords = { 0.1, 0.9, 0.1, 0.9 },
        width = "full",
        fontSize = "large"
    } ]]

    options.disabled = {
        type = "toggle",
        name = function () return format( "Disable %s via |cff00ccff[Use Items]|r", select( 2, GetItemInfo( itemID ) ) or ( "[" .. itemID .. "]" ) ) end,
        desc = function( info )
            local output = "If disabled, the addon will not recommend this item via the |cff00ccff[Use Items]|r action.  " ..
                "You can still manually include the item in your action lists with your own tailored criteria."
            return output
        end,
        order = 25,
        width = "full"
    }

    options.minimum = {
        type = "range",
        name = "Minimum Targets",
        desc = "The addon will only recommend this trinket (via |cff00ccff[Use Items]|r) when there are at least this many targets available to hit.",
        order = 26,
        width = "full",
        min = 1,
        max = 10,
        step = 1
    }

    options.maximum = {
        type = "range",
        name = "Maximum Targets",
        desc = "The addon will only recommend this trinket (via |cff00ccff[Use Items]|r) when there are no more than this many targets detected.\n\n" ..
            "This setting is ignored if set to 0.",
        order = 27,
        width = "full",
        min = 0,
        max = 10,
        step = 1
    }

    class.itemSettings[ itemID ] = {
        key = key,
        name = function () return select( 2, GetItemInfo( itemID ) ) or ( "[" .. itemID .. "]" ) end,
        item = itemID,
        options = options,
    }

end


--[[ local function addUsableItem( key, id )
    class.items = class.items or {}
    class.items[ key ] = id

    addGearSet( key, id )
    addItemSettings( key, id )
end
ns.addUsableItem = addUsableItem ]]


function Hekili:GetAbilityInfo( index )

    local ability = class.abilities[ index ]

    if not ability then return end

    -- Decide if more details are needed later.
    return ability.id, ability.name, ability.key, ability.item
end

class.interrupts = {}


local function addPet( key, permanent )
    state.pet[ key ] = rawget( state.pet, key ) or {}
    state.pet[ key ].name = key
    state.pet[ key ].expires = 0

    ns.commitKey( key )
end
ns.addPet = addPet


local function addStance( key, spellID )
    class.stances[ key ] = spellID
    ns.commitKey( key )
end
ns.addStance = addStance

-- Register Warrior stances so the generic stance metatable (state.stance)
-- can resolve the player's current stance by comparing shapeshift form spellIDs.
do
    local playerClass = UnitClassBase and UnitClassBase("player") or select(2, UnitClass("player"))
    if playerClass == "WARRIOR" then
        -- Battle Stance (2457), Defensive Stance (71), Berserker Stance (2458) in MoP.
        -- These IDs are returned from GetShapeshiftFormInfo(i) as the 5th return value (spellID).
        addStance("battle", 2457)
        addStance("defensive", 71)
        addStance("berserker", 2458)

        -- Register pseudo-auras so buff.battle_stance/defensive_stance/berserker_stance
        -- can be toggled by detection logic without triggering unknown-buff warnings.
        if all and all.RegisterAura then
            all:RegisterAura( "battle_stance",    { id = 2457, duration = 3600, max_stack = 1 } )
            all:RegisterAura( "defensive_stance", { id = 71,   duration = 3600, max_stack = 1 } )
            all:RegisterAura( "berserker_stance", { id = 2458, duration = 3600, max_stack = 1 } )
        end
    end
end


local function setRole( key )

    for k,v in pairs( state.role ) do
        state.role[ k ] = nil
    end

    state.role[ key ] = true

end
ns.setRole = setRole


function Hekili:GetActiveSpecOption( opt )
    if not self.currentSpecOpts then return end
    return self.currentSpecOpts[ opt ]
end


function Hekili:GetActivePack()
    return self:GetActiveSpecOption( "package" )
end


Hekili.SpecChangeHistory = {}

function Hekili:SpecializationChanged()
    local currentSpec, currentID, currentName

    -- MoP Classic: Use our enhanced spec detection logic
    currentSpec = GetSpecialization and GetSpecialization() or 1

    -- Try our enhanced detection first
    if self.GetMoPSpecialization then
        currentID, currentName = self:GetMoPSpecialization()
    end

    -- Fallback to basic detection if enhanced detection fails
    if not currentID then
        currentID = ns.getSpecializationID(currentSpec)
        currentName = ns.getSpecializationKey(currentID)
    end

    -- Don't override if we already have a valid spec ID that matches our detection
    if state.spec.id and state.spec.id == currentID then
        self.PendingSpecializationChange = false
        return
    end

    -- Ensure profile exists for this spec
    if currentID and Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.specs then
        if not Hekili.DB.profile.specs[currentID] then
            -- Create default profile for spec
            Hekili.DB.profile.specs[currentID] = Hekili.DB.profile.specs[currentID] or {}
            -- Copy default settings
            local defaults = Hekili:GetDefaults()
            if defaults and defaults.profile and defaults.profile.specs and defaults.profile.specs["**"] then
                for k, v in pairs(defaults.profile.specs["**"]) do
                    if Hekili.DB.profile.specs[currentID][k] == nil then
                        Hekili.DB.profile.specs[currentID][k] = v
                    end
                end
            end
            -- Ensure enabled is true
            Hekili.DB.profile.specs[currentID].enabled = true
            -- Spec profile created and enabled
        else
            -- Profile exists for spec
        end
    end

    if currentID == nil then
        self.PendingSpecializationChange = true
        return
    end

    self.PendingSpecializationChange = false
    self:ForceUpdate( "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" )

    insert( self.SpecChangeHistory, {
        spec = currentID,
        time = GetTime(),
        bt = debugstack()
    } )

    for k, v in pairs( state.spec ) do
        state.spec[ k ] = nil
    end

    for key in pairs( GetResourceInfo() ) do
        state[ key ] = nil
        class[ key ] = nil
    end

    class.primaryResource = nil

    wipe( state.buff )
    wipe( state.debuff )

    wipe( class.auras )
    wipe( class.abilities )
    wipe( class.hooks )
    wipe( class.talents )
    wipe( class.pvptalents )
    wipe( class.powers )
    wipe( class.gear )
    wipe( class.setBonuses )
    wipe( class.packs )
    wipe( class.resources )
    wipe( class.resourceAuras )

    wipe( class.pets )

    local specs = {}

    -- MoP Classic: Use the detected spec directly
    insert( specs, 1, currentID )

    state.spec.id = currentID
    state.spec.name = currentName or "Unknown"
    state.spec.key = ns.getSpecializationKey( currentID )

    -- Set default role - will be overridden by spec-specific files if needed
    for k in pairs( state.role ) do
        state.role[ k ] = false
    end

    -- Default role assignment (most specs are DPS)
    state.role.attack = true
    state.spec.primaryStat = "agility" -- Default for most physical DPS

    -- Override for known caster specs
    local casterSpecs = {
        [62] = true,   -- Mage Arcane
        [63] = true,   -- Mage Fire
        [64] = true,   -- Mage Frost
        [102] = true,  -- Druid Balance
        [105] = true,  -- Druid Restoration
        [256] = true,  -- Priest Discipline
        [257] = true,  -- Priest Holy
        [258] = true,  -- Priest Shadow
        [262] = true,  -- Shaman Elemental
        [264] = true,  -- Shaman Restoration
        [265] = true,  -- Warlock Affliction
        [266] = true,  -- Warlock Demonology
        [267] = true,  -- Warlock Destruction
    }

    -- Override for known tank specs
    local tankSpecs = {
        [104] = true,  -- Druid Guardian
        [66] = true,   -- Paladin Protection
        [73] = true,   -- Warrior Protection
    }

    if casterSpecs[currentID] then
        state.spec.primaryStat = "intellect"
    elseif tankSpecs[currentID] then
        state.role.attack = false
        state.role.tank = true
    end

    state.spec[ state.spec.key ] = true

    insert( specs, 0 )


    for key in pairs( GetResourceInfo() ) do
        state[ key ] = nil
        class[ key ] = nil
    end
    if rawget( state, "rune" ) then state.rune = nil; class.rune = nil; end
    if rawget( state, "runes" ) then state.runes = nil; class.runes = nil; end

    for k in pairs( class.resourceAuras ) do
        class.resourceAuras[ k ] = nil
    end

    class.primaryResource = nil

    for k in pairs( class.stateTables ) do
        rawset( state, k, nil )
        class.stateTables[ k ] = nil
    end

    for k in pairs( class.stateFuncs ) do
        rawset( state, k, nil )
        class.stateFuncs[ k ] = nil
    end

    for k in pairs( class.stateExprs ) do
        class.stateExprs[ k ] = nil
    end

    self.currentSpec = nil
    self.currentSpecOpts = nil

    for i, specID in ipairs( specs ) do
        local spec = class.specs[ specID ]

if spec then
            if specID == currentID then
                self.currentSpec = spec
                self.currentSpecOpts = rawget( self.DB.profile.specs, specID )

                -- Create default spec profile if it doesn't exist
                if not self.currentSpecOpts then
                    self.DB.profile.specs[ specID ] = self.DB.profile.specs[ specID ] or {}
                    self.currentSpecOpts = self.DB.profile.specs[ specID ]
                end

                state.settings.spec = self.currentSpecOpts

                state.spec.can_dual_cast = spec.can_dual_cast
                state.spec.dual_cast = spec.dual_cast

                for res, model in pairs( spec.resources ) do
                    class.resources[ res ] = model
                    state[ res ] = model.state
                end

                for k,v in pairs( spec.resourceAuras ) do
                    class.resourceAuras[ k ] = v
                end

                class.primaryResource = spec.primaryResource

                for talent, id in pairs( spec.talents ) do
                    class.talents[ talent ] = id
                end

                for talent, id in pairs( spec.pvptalents ) do
                    class.pvptalents[ talent ] = id
                end

                class.variables = spec.variables

                class.potionList.default = "|T967533:0|t |cFFFFD100Default|r"
            end

            if specID == currentID or specID == 0 then
                for event, hooks in pairs( spec.hooks ) do
                    for _, hook in ipairs( hooks ) do
                        class.hooks[ event ] = class.hooks[ event ] or {}
                        insert( class.hooks[ event ], hook )
                    end
                end
            end

            for res, model in pairs( spec.resources ) do
                if not class.resources[ res ] then
                    class.resources[ res ] = model
                    state[ res ] = model.state
                end
            end


            for k, v in pairs( spec.auras ) do
                if not class.auras[ k ] then class.auras[ k ] = v end
            end

            for k, v in pairs( spec.powers ) do
                if not class.powers[ k ] then class.powers[ k ] = v end
            end

            for k, v in pairs( spec.abilities ) do
                if not class.abilities[ k ] then class.abilities[ k ] = v end
            end

            for k, v in pairs( spec.gear ) do
                if not class.gear[ k ] then class.gear[ k ] = v end
            end

            for k, v in pairs( spec.setBonuses ) do
                if not class.setBonuses[ k ] then class.setBonuses[ k ] = v end
            end

            for k, v in pairs( spec.pets ) do
                if not class.pets[ k ] then class.pets[ k ] = v end
            end

            for k, v in pairs( spec.totems ) do
                if not class.totems[ k ] then class.totems[ k ] = v end
            end

            for k, v in pairs( spec.packs ) do
                if not class.packs[ k ] then class.packs[ k ] = v end
            end

            for name, func in pairs( spec.stateExprs ) do
                if not class.stateExprs[ name ] then
                    if rawget( state, name ) then state[ name ] = nil end
                    class.stateExprs[ name ] = func
                end
            end

            for name, func in pairs( spec.stateFuncs ) do
                if not class.stateFuncs[ name ] then
                    if rawget( state, name ) then
                        Hekili:Error( "Cannot RegisterStateFunc for an existing expression ( " .. spec.name .. " - " .. name .. " )." )
                    else
                        class.stateFuncs[ name ] = func
                        rawset( state, name, func )
                        -- Hekili:Error( "Not real error, registered " .. name .. " for " .. spec.name .. " (RSF)." )
                    end
                end
            end

            for name, t in pairs( spec.stateTables ) do
                if not class.stateTables[ name ] then
                    if rawget( state, name ) then
                        Hekili:Error( "Cannot RegisterStateTable for an existing expression ( " .. spec.name .. " - " .. name .. " )." )
                    else
                        class.stateTables[ name ] = t
                        rawset( state, name, t )
                        -- Hekili:Error( "Not real error, registered " .. name .. " for " .. spec.name .. " (RST)." )
                    end
                end
            end

            if spec.id > 0 then
                local s = rawget( Hekili.DB.profile.specs, spec.id )

                if s then
                    for k, v in pairs( spec.settings ) do
                        if s.settings[ v.name ] == nil then s.settings[ v.name ] = v.default end
                    end
                end
            end
        end
    end

    for k in pairs( class.abilityList ) do
        local ability = class.abilities[ k ]

        if ability and ability.id > 0 then
            if not ability.texture or not ability.name then
                local data = GetSpellInfo( ability.id )

                if data and data.name and data.iconID then
                    ability.name = ability.name or data.name
                    class.abilityList[ k ] = "|T" .. data.iconID .. ":0|t " .. ability.name
                end
            else
                class.abilityList[ k ] = "|T" .. ability.texture .. ":0|t " .. ability.name
            end
        end
    end

    state.GUID = UnitGUID( "player" )
    state.player.unit = UnitGUID( "player" )

    ns.callHook( "specializationChanged" )

    ns.updateTalents()
    ResetDisabledGearAndSpells()

    state.swings.mh_speed, state.swings.oh_speed = UnitAttackSpeed( "player" )

    -- Initialize threat state
    state.threat = state.threat or {}
    state.threat.situation = 0 -- 0 = no threat, 1 = low threat, 2 = high threat, 3 = tanking
    state.threat.percentage = 0
    state.threat.raw = 0
    state.threat.rawTarget = 0

    if Hekili.Engine then Hekili.Engine.activeThread = nil end
    self:UpdateDisplayVisibility()
    self:UpdateDamageDetectionForCLEU()
end

-- Tinkers (Classic WoW - simplified for compatibility)
all:RegisterAura( "hyperspeed_acceleration", {
    id = 54758,
    duration = 15,
    max_stack = 1
})
all:RegisterAbility( "hyperspeed_acceleration", {
    id = 54758,
    cast = 0,
    cooldown = 60,
    gcd = "off",

    startsCombat = true,
    toggle = "cooldowns",

    handler = function()
        applyBuff("hyperspeed_acceleration")
    end
} )

all:RegisterAura( "synapse_springs", {
    id = 96228,
    duration = 15,
    max_stack = 1,
    copy = {96228, 96229, 96230, 82174, 126734, 141330}
})
all:RegisterAbility( "synapse_springs", {
    -- Equipment-based, not a learned spell; use a high positive ID to avoid conflicts.
    id = 99982174,
    cast = 0,
    cooldown = 60,
    gcd = "off",

    startsCombat = true,
    toggle = "cooldowns",

    -- Provide item/texture like Cata for UI parity.
    -- Always provide the equipped glove item ID; gating is handled by known/usable.
    item = function() return (tinker and tinker.hand and tinker.hand.item) or 0 end,
    itemKey = "synapse_springs",
    texture = function() return (tinker and tinker.hand) and tinker.hand.texture or nil end,

    -- Always treat as known; 'usable()' below enforces having Synapse Springs equipped.
    known = true,

    usable = function()
        -- Prefer robust slot-use detection: if the glove slot has any on-use spell, treat as Synapse Springs.
        -- MoP clients may return only the spell name; rely on presence of a spell rather than exact IDs.
        local hasUse = GetInventoryItemSpell("player", INVSLOT_HAND) ~= nil

        -- Keep ID-based detection as a secondary signal when available.
        local s = (tinker and tinker.hand) and tinker.hand.spell or 0
        local knownByID = (s == 82174 or s == 96228 or s == 96229 or s == 96230 or s == 126734 or s == 141330)

        if not (hasUse or knownByID) then
            return false, "no synapse springs on gloves"
        end
        return true
    end,

    -- Drive cooldown timing from the glove slot rather than a spell.
    meta = {
        -- Ensure t.duration/t.expires are populated so downstream keys like 'remains' work.
        duration = function(t)
            local start, dur = GetInventoryItemCooldown("player", INVSLOT_HAND)
            if start == nil or dur == nil then dur = 60; start = 0 end
            t.duration = dur or 60
            t.expires = (start and start > 0 and dur) and (start + dur) or 0
            t.true_duration = t.duration
            t.true_expires = t.expires
            return t.duration
        end,
        expires = function(t)
            local start, dur = GetInventoryItemCooldown("player", INVSLOT_HAND)
            if start == nil or dur == nil then dur = 60; start = 0 end
            t.duration = dur or 60
            t.expires = (start and start > 0 and dur) and (start + dur) or 0
            t.true_duration = t.duration
            t.true_expires = t.expires
            return t.expires
        end,
        remains = function(t)
            local start, dur = GetInventoryItemCooldown("player", INVSLOT_HAND)
            if start == nil or dur == nil then dur = 60; start = 0 end
            local expires = (start and start > 0 and dur) and (start + dur) or 0
            t.duration = dur or 60
            t.expires = expires
            t.true_duration = t.duration
            t.true_expires = expires
            local now = (state and state.query_time) or GetTime()
            local remains = expires > 0 and max(0, expires - now) or 0
            return remains
        end,
        ready = function(t)
            local start, dur = GetInventoryItemCooldown("player", INVSLOT_HAND)
            if start == nil or dur == nil then dur = 60; start = 0 end
            local expires = (start and start > 0 and dur) and (start + dur) or 0
            t.duration = dur or 60
            t.expires = expires
            t.true_duration = t.duration
            t.true_expires = expires
            local now = (state and state.query_time) or GetTime()
            return expires == 0 or expires <= now
        end,
    },

    handler = function()
        applyBuff("synapse_springs")
    end
} )
