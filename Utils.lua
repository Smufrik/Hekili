-- Utils.lua
-- July 2024

local addon, ns = ...
local Hekili = _G[ addon ]

local format, gsub, lower = string.format, string.gsub, string.lower
local insert, remove = table.insert, table.remove

local class = Hekili.Class
local state = Hekili.State

-- Classic API - Use traditional UnitBuff/UnitDebuff iteration

local GetSpellBookItemInfo = function(index, bookType)
    -- MoP compatibility: Use GetSpellBookItemName instead of GetSpellName
    local name, _, icon, _, _, _, spellID = GetSpellBookItemName(index, bookType)
    return name, icon, spellID
end

ns.UnitBuff = function( unit, index, filter )
    if not unit or type(unit) ~= 'string' then return nil end
    if not index or index < 1 then return nil end
    return UnitBuff(unit, index, filter)
end

ns.UnitDebuff = function( unit, index, filter )
    if not unit or type(unit) ~= 'string' then return nil end
    if not index or index < 1 then return nil end
    return UnitDebuff(unit, index, filter)
end


-- Duplicate spell info lookup.
function ns.FindUnitBuffByID( unit, id, filter )
    local playerOrPet = false

    if filter == "PLAYER|PET" then
        playerOrPet = true
        filter = nil
    end

    local i = 1
    local name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unit, i, filter )

    if type( id ) == "table" then
        while( name ) do
            if id[ spellID ] and ( not playerOrPet or UnitIsUnit( caster, "player" ) or UnitIsUnit( caster, "pet" ) ) then break end
            i = i + 1
            name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unit, i, filter )
        end
    else
        while( name ) do
            if spellID == id and ( not playerOrPet or UnitIsUnit( caster, "player" ) or UnitIsUnit( caster, "pet" ) ) then break end
            i = i + 1
            name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unit, i, filter )
        end
    end

    return name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3
end


function ns.FindUnitDebuffByID( unit, id, filter )
    local playerOrPet = false

    if filter == "PLAYER|PET" then
        playerOrPet = true
        filter = nil
    end

    local i = 1
    local name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitDebuff( unit, i, filter )

    if type( id ) == "table" then
        while( name ) do
            if id[ spellID ] and ( not playerOrPet or UnitIsUnit( caster, "player" ) or UnitIsUnit( caster, "pet" ) ) then break end
            i = i + 1
            name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitDebuff( unit, i, filter )
        end
    else
        while( name ) do
            if spellID == id and ( not playerOrPet or UnitIsUnit( caster, "player" ) or UnitIsUnit( caster, "pet" ) ) then break end
            i = i + 1
            name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitDebuff( unit, i, filter )
        end
    end

    return name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3
end

-- MoP API compatibility - removed faulty GetItemInfo redefinition
-- GetItemInfo is available in MoP and doesn't need local redefinition

local errors = {}
local eIndex = {}

ns.Error = function( output, ... )
    if ... then
        output = format( output, ... )
    end

    if not errors[ output ] then
        errors[ output ] = {
            n = 1,
            last = date( "%X", time() )
        }
        eIndex[ #eIndex + 1 ] = output
        -- if Hekili.DB.profile.Verbose then Hekili:Print( output ) end
    else
        errors[ output ].n = errors[ output ].n + 1
        errors[ output ].last = date( "%X", time() )
    end
end


function Hekili:Error( ... )
    ns.Error( ... )
end

Hekili.ErrorKeys = eIndex
Hekili.ErrorDB = errors


function Hekili:GetErrors()
    for i = 1, #eIndex do
        Hekili:Print( eIndex[i] .. " (n = " .. errors[ eIndex[i] ].n .. "), last at " .. errors[ eIndex[i] ].last .. "." )
    end
end


function ns.SpaceOut( str )
    str = str:gsub( "([!<>=|&()*%-%+/][?]?)", " %1 " ):gsub("%s+", " ")
    str = str:gsub( "([^%%])([%%]+)([^%%])", "%1 %2 %3" )
    str = str:gsub( "%.%s+%(", ".(" )
    str = str:gsub( "%)%s+%.", ")." )

    str = str:gsub( "([<>~!|]) ([|=])", "%1%2" )
    str = str:trim()
    return str
end


local LT = LibStub( "LibTranslit-1.0" )

-- Converts `s' to a SimC-like key: strip non alphanumeric characters, replace spaces with _, convert to lower case.
function ns.formatKey( s )
    s = s:gsub( "|c........", "" ):gsub( "|r", "" )
    s = LT:Transliterate( s )
    s = lower( s or '' ):gsub( "[^a-z0-9_ ]", "" ):gsub( "%s+", "_" )
    return s
end


ns.titleCase = function( s )
    local helper = function( first, rest )
        return first:upper()..rest:lower()
    end

    return s:gsub( "_", " " ):gsub( "(%a)([%w_']*)", helper ):gsub( "[Aa]oe", "AOE" ):gsub( "[Rr]jw", "RJW" ):gsub( "[Cc]hix", "ChiX" ):gsub( "(%W?)[Ss]t(%W?)", "%1ST%2" )
end


local replacements = {
    ['_'] = " ",
    aoe = "AOE",
    rjw = "RJW",
    chix = "ChiX",
    st = "ST",
    cd = "CD",
    cds = "CDs"
}

ns.titlefy = function( s )
    for k, v in pairs( replacements ) do
        s = s:gsub( '%f[%w]' .. k .. '%f[%W]', v ):gsub( "_", " " )
    end

    return s
end


ns.fsub = function( s, pattern, repl )
    return s:gsub( "%f[%w]" .. pattern .. "%f[%W]", repl )
end


ns.escapeMagic = function( s )
    return s:gsub( "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1" )
end


local tblUnpack = {}

ns.multiUnpack = function( ... )

    table.wipe( tblUnpack )

    for i = 1, select( '#', ... ) do
        local tbl = select( i, ... )
        if tbl and type(tbl) == "table" then
            for _, value in ipairs( tbl ) do
                tblUnpack[ #tblUnpack + 1 ] = value
            end
        end
    end

    return unpack( tblUnpack )

end


ns.round = function( num, places )

    return tonumber( format( "%." .. ( places or 0 ) .. "f", num ) )

end


function ns.roundUp( num, places )
    num = num or 0
    local tens = 10 ^ ( places or 0 )

    return ceil( num * tens ) / tens
end


function ns.roundDown( num, places )
    num = num or 0
    local tens = 10 ^ ( places or 0 )

    return floor( num * tens ) / tens
end


-- Deep Copy
-- from http://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
local function tableCopy( obj, seen )
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[ tableCopy(k, s) ] = tableCopy(v, s) end
    return res
end
ns.tableCopy = tableCopy


local toc = {}
local exclusions = { min = true, max = true, _G = true }

ns.commitKey = function( key )
    if not toc[ key ] and not exclusions[ key ] then
        ns.keys[ #ns.keys + 1 ] = key
        toc[ key ] = 1
    end
end


local orderedIndex = {}

local sortHelper = function( a, b )
    local a1, b1 = tostring(a), tostring(b)

    return a1 < b1
end


local function __genOrderedIndex( t )

    for i = #orderedIndex, 1, -1 do
        orderedIndex[i] = nil
    end

    for key in pairs( t ) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex, sortHelper )
    return orderedIndex
end


local function orderedNext( t, state )
    local key = nil

    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[ 1 ]
    else
        for i = 1, #t.__orderedIndex do
            if t.__orderedIndex[ i ] == state then
                key = t.__orderedIndex[ i+1 ]
            end
        end
    end

    if key then
        return key, t[ key ]
    end

    t.__orderedIndex = nil
    return
end


function ns.orderedPairs( t )
    return orderedNext, t, nil
end


function ns.safeMin( ... )
    local result

    for i = 1, select( "#", ... ) do
        local val = select( i, ... )
        if val then result = ( not result or val < result ) and val or result end
    end

    return result or 0
end


function ns.safeMax( ... )
    local result

    for i = 1, select( "#", ... ) do
        local val = select( i, ... )
        if val and type(val) == 'number' then result = ( not result or val > result ) and val or result end
    end

    return result or 0
end


function ns.safeAbs( val )
    val = tonumber( val )
    if val < 0 then return -val end
    return val
end


-- Rivers' iterator for group members.
function ns.GroupMembers( reversed, forceParty )
    local unit = ( not forceParty and IsInRaid() ) and 'raid' or 'party'
    local numGroupMembers = forceParty and GetNumPartyMembers() or GetNumRaidMembers()
    local i = reversed and numGroupMembers or ( unit == 'party' and 0 or 1 )

    return function()
        local ret

        if i == 0 and unit == 'party' then
            ret = 'player'
        elseif i <= numGroupMembers and i > 0 then
            ret = unit .. i
        end

        i = i + ( reversed and -1 or 1 )
        return ret
    end
end


-- Use MoP compatible timer function
function Hekili:After( time, func, ... )
    local args = { ... }
    local function delayfunc()
        func( unpack( args ) )
    end

    -- Use native After function for MoP
    if _G.After then
        After( time, delayfunc )
    else
        -- Fallback timer method
        local frame = CreateFrame("Frame")
        local startTime = GetTime()
        frame:SetScript("OnUpdate", function(self)
            if GetTime() - startTime >= time then
                self:SetScript("OnUpdate", nil)
                delayfunc()
            end
        end)
    end
end

function ns.FindRaidBuffByID( id )

    local unitName
    local buffCounter = 0
    local buffIterator = 1

    local name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3

    if IsInRaid() or IsInGroup() then
        if IsInRaid() then
            unitName = "raid"
            for numGroupMembers=1, GetNumRaidMembers() do
                buffIterator = 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                while( spellID ) do
                    if spellID == id then buffCounter = buffCounter + 1 break end
                    buffIterator = buffIterator + 1
                    name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                end
            end
        elseif IsInGroup() then
            unitName = "party"
            for numGroupMembers=1, GetNumPartyMembers() do
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                while( spellID ) do
                    if spellID == id then buffCounter = buffCounter + 1 break end
                    buffIterator = buffIterator + 1
                    name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                end
            end
            buffIterator = 1
            name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( "player", buffIterator )
            while( spellID ) do
                if spellID == id then buffCounter = buffCounter + 1 break end
                buffIterator = buffIterator + 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( "player", buffIterator )
            end

        else
            unitName = "player"
        end

    end

    return buffCounter
end

function ns.FindLowHpPlayerWithoutBuffByID(id)

    local unitName
    local playerWithoutBuff = 0
    local buffFound = false
    local buffIterator = 1
    local name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3

    if IsInRaid() or IsInGroup() then
        if IsInRaid() then
            unitName = "raid"
            for numGroupMembers=1, GetNumRaidMembers() do
                buffFound = false
                buffIterator = 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                while( name ) do
                    if spellID == id then buffFound = true break end
                    buffIterator = buffIterator + 1
                    name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                end

                if not buffFound then
                    local player = unitName..numGroupMembers
                    local Health = (UnitHealth(player))/1000
                    local HealthMax = (UnitHealthMax(player))/1000
                    local HealthPercent = (UnitHealth(player)/UnitHealthMax(player))*100

                    if HealthPercent <= 80 and UnitName(player) then
                        playerWithoutBuff = playerWithoutBuff + 1
                    end
                end
            end
        elseif IsInGroup() then
            unitName = "party"
            for numGroupMembers=1, GetNumPartyMembers() do
                buffFound = false
                buffIterator = 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                while( name ) do
                    if spellID == id then buffFound = true break end
                    buffIterator = buffIterator + 1
                    name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                end

                if not buffFound then
                    local player = unitName..numGroupMembers
                    local Health = (UnitHealth(player))/1000
                    local HealthMax = (UnitHealthMax(player))/1000
                    local HealthPercent = (UnitHealth(player)/UnitHealthMax(player))*100

                    if HealthPercent <= 80 and UnitName(player) then
                        playerWithoutBuff = playerWithoutBuff + 1
                    end
                end
            end

            buffFound = false
            buffIterator = 1
            name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( "player", buffIterator )
            while( name ) do
                if spellID == id then buffFound = true break end
                buffIterator = buffIterator + 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( "player", buffIterator )
            end

            if not buffFound then
                local player = "player"
                local Health = (UnitHealth(player))/1000
                local HealthMax = (UnitHealthMax(player))/1000
                local HealthPercent = (UnitHealth(player)/UnitHealthMax(player))*100

                if HealthPercent <= 80 then
                    playerWithoutBuff = playerWithoutBuff + 1
                end
            end
        else
            unitName = "player"
        end

    end

    return playerWithoutBuff
end

function ns.FindRaidBuffLowestRemainsByID(id)

    local buffRemainsOld
    local buffRemainsNew
    local buffRemainsReturn
    local unitName = "player"

    local buffIterator = 1
    local name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3

    if IsInRaid() or IsInGroup() then
        if IsInRaid() then
            unitName = "raid"
            for numGroupMembers=1, GetNumRaidMembers() do
                buffIterator = 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                while( name ) do
                    if spellID == id then

                        if buffRemainsOld == nil then
                            buffRemainsOld =  expirationTime - GetTime()
                        end

                        local buffRemainsNew = expirationTime - GetTime()

                        if buffRemainsNew < buffRemainsOld then
                            buffRemainsReturn = buffRemainsNew
                        else
                            buffRemainsReturn = buffRemainsOld
                        end

                        break
                    end
                    buffIterator = buffIterator + 1
                    name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                end
            end
        elseif IsInGroup() then
            unitName = "party"
            for numGroupMembers=1, GetNumPartyMembers() do
                buffIterator = 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                while( name ) do
                    if spellID == id then

                        if buffRemainsOld == nil then
                            buffRemainsOld =  expirationTime - GetTime()
                        end

                        local buffRemainsNew = expirationTime - GetTime()

                        if buffRemainsNew < buffRemainsOld then
                            buffRemainsReturn = buffRemainsNew
                        else
                            buffRemainsReturn = buffRemainsOld
                        end

                        break
                    end
                    buffIterator = buffIterator + 1
                    name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( unitName..numGroupMembers, buffIterator )
                end
            end

            buffIterator = 1
            name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( "player", buffIterator )
            while( name ) do
                if spellID == id then

                    if buffRemainsOld == nil then
                        buffRemainsOld =  expirationTime - GetTime()
                    end

                    local buffRemainsNew = expirationTime - GetTime()

                    if buffRemainsNew < buffRemainsOld then
                        buffRemainsReturn = buffRemainsNew
                    else
                        buffRemainsReturn = buffRemainsOld
                    end

                    break
                end
                buffIterator = buffIterator + 1
                name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID, canApplyAura, isBossDebuff, nameplateShowAll, timeMod, value1, value2, value3 = UnitBuff( "player", buffIterator )
            end
        end
    end

    return buffRemainsReturn == nil and 0 or buffRemainsReturn
end

local function FindPlayerAuraByID( id )
    -- Classic implementation using direct UnitBuff iteration
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, caster, stealable, 
              nameplateShowPersonal, spellID = UnitBuff("player", i)
        if not name then break end
        if spellID == id then
            return name, icon, count, debuffType, duration, expirationTime, caster, stealable, nameplateShowPersonal, spellID
        end
    end
    return nil
end
ns.FindPlayerAuraByID = FindPlayerAuraByID

-- Export the improved debuff/buff functions
ns.FindUnitBuffByID = ns.FindUnitBuffByID
ns.FindUnitDebuffByID = ns.FindUnitDebuffByID

-- For backward compatibility, also set UnitBuffByID and UnitDebuffByID
ns.UnitBuffByID = ns.FindUnitBuffByID
ns.UnitDebuffByID = ns.FindUnitDebuffByID


function ns.IsActiveSpell( id )
    local slot = FindSpellBookSlotBySpellID( id )
    if not slot then return false end
    local name = GetSpellBookItemName( slot, "spell" )
    -- For MoP compatibility, we'll check if the spell name exists
    return name ~= nil
end


function ns.GetUnpackedSpellInfo( spellID )
    if not spellID then
        return nil;
    end

    -- MoP compatibility: GetSpellInfo returns exactly 6 values: name, rank, icon, castTime, minRange, maxRange
    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
    if name then
        -- Return with spellID as the 7th parameter for compatibility with retail expectations
        return name, rank, icon, castTime, minRange, maxRange, spellID, icon;
    end
    
    -- Return nil if spell is not found - this is important for autoAuraKey fallback logic
    return nil;
end


function Hekili:GetSpellLinkWithTexture( id, size, color )
    if not id then return "" end

    if type( id ) ~= "number" and class.abilities[ id ] then
        id = class.abilities[ id ].id
    end

    -- MoP compatibility: GetSpellInfo returns direct values
    local name, _, icon = GetSpellInfo( id )

    if name and icon then
        if type( color ) == "boolean" then
            color = color and "ff00ff00" or "ffff0000"
        end

        if color == nil then color = "ff71d5ff" end

        return "|W|T" .. icon .. ":" .. ( size or 0 ) .. ":" .. ( size or "" ) .. ":::64:64:4:60:4:60|t " .. ( color and ( "|c" .. color ) or "" ) .. name .. ( color and "|r" or "" ) .. "|w"
    end

    return tostring( id )
end

function Hekili:ZoomedTextureWithText( texture, text )
    if not texture or not text then return end
    return "|W|T" .. texture .. ":0::::64:64:4:60:4:60|t " .. text .. "|w"
end


function state.debugformat( val )
    if val == nil then return "nil" end
    if type( val ) == "number" then return format( "%.2f", val ) end
    return tostring( val )
end


-- Tooltip Parsing Utilities (10.0.2)
do
    local CurrentBuild = Hekili.CurrentBuild
    local tooltip = ns.Tooltip

    local DisableText = {        _G.SPELL_FAILED_NOT_HERE,
        _G.SPELL_FAILED_INCORRECT_AREA,
        _G.SPELL_FAILED_NOT_IN_MAGE_TOWER,
        _G.TOOLTIP_NOT_IN_MAGE_TOWER,
        _G.LEVEL_LINKED_NOT_USABLE
    }
      local FindStringInTooltip = function( str, id, ttType, reverse, useMatch )
        -- MoP: C_TooltipInfo not available, tooltip parsing disabled
        return false
    end
    ns.FindStringInTooltip = FindStringInTooltip

    local FindStringInSpellTooltip = function( str, spellID, reverse, useMatch )
        return FindStringInTooltip( str, spellID, "spell", reverse, useMatch )
    end
    ns.FindStringInSpellTooltip = FindStringInSpellTooltip

    local FindStringInItemTooltip = function( str, itemID, reverse, useMatch )
        return FindStringInTooltip( str, itemID, "item", reverse, useMatch )
    end
    ns.FindStringInItemTooltip = FindStringInItemTooltip

    -- Note, this is written to assume we're dealing with the player's inventory only; I'm not messing with inspect right now.
    local FindStringInInventoryItemTooltip = function( str, slot, reverse, useMatch )
        return FindStringInTooltip( str, slot, "inventory", reverse, useMatch )
    end
    ns.FindStringInInventoryItemTooltip = FindStringInInventoryItemTooltip

    local DisabledSpells = {}

    local IsSpellDisabled = function( spellID )
        if DisabledSpells[ spellID ] ~= nil then return DisabledSpells[ spellID ] end

        local isDisabled = FindStringInSpellTooltip( DisableText, spellID, true, true )
        DisabledSpells[ spellID ] = isDisabled

        return isDisabled
    end
    ns.IsSpellDisabled = IsSpellDisabled

    local DisabledItems = {}

    local IsItemDisabled = function( itemID )
        if DisabledItems[ itemID ] ~= nil then return DisabledItems[ itemID ] end

        local isDisabled = FindStringInItemTooltip( DisableText, itemID, true, true )
        DisabledItems[ itemID ] = isDisabled

        return isDisabled
    end
    ns.IsItemDisabled = IsItemDisabled

    local DisabledGear = {}

    local IsInventoryItemDisabled = function( slot )
        if DisabledGear[ slot ] ~= nil then return DisabledGear[ slot ] end

        local isDisabled = FindStringInInventoryItemTooltip( DisableText, slot, true, true )
        DisabledGear[ slot ] = isDisabled

        return isDisabled
    end
    ns.IsInventoryItemDisabled = IsInventoryItemDisabled

    local function IsAbilityDisabled( ability )
        if ability.item then return IsItemDisabled( ability.item ) end
        if ability.id > 0 then return IsSpellDisabled( ability.id ) end
        return false
    end
    ns.IsAbilityDisabled = IsAbilityDisabled

    local ResetDisabledGearAndSpells = function()
        wipe( DisabledSpells )
        wipe( DisabledItems )
        wipe( DisabledGear )
    end
    ns.ResetDisabledGearAndSpells = ResetDisabledGearAndSpells    Hekili.FindStringInTooltip = FindStringInTooltip
    Hekili.FindStringInSpellTooltip = FindStringInSpellTooltip
    Hekili.FindStringInItemTooltip = FindStringInItemTooltip
    Hekili.FindStringInInventoryItemTooltip = FindStringInInventoryItemTooltip


    Hekili.IsSpellDisabled = IsSpellDisabled
    Hekili.IsItemDisabled = IsItemDisabled
    Hekili.IsInventoryItemDisabled = IsInventoryItemDisabled
end


do
    local itemCache = {}
    
    -- Try to get GetItemInfo function from various sources
    local function getItemInfoFunction()
        return _G.GetItemInfo or 
               function() return nil end  -- Fallback that returns nil
    end

    function ns.CachedGetItemInfo( id )
        if not id then return nil end
        
        if itemCache[ id ] then
            return unpack( itemCache[ id ] )
        end

        -- MoP compatibility: Try multiple ways to get GetItemInfo
        local GetItemInfoFunc = getItemInfoFunction()
        
        -- If still not available, return nil
        if not GetItemInfoFunc then
            return nil
        end

        local success, item = pcall(function() return { GetItemInfoFunc( id ) } end)
        if success and item and item[ 1 ] then
            itemCache[ id ] = item
            return unpack( item )
        end
        
        -- Return nil if item info is not available
        return nil    end
end

-- MoP API compatibility for GetItemSpell
do
    local function GetItemSpellCompat(itemID)
        -- In MoP, GetItemSpell function doesn't exist
        -- We need to use a different approach
        if not itemID then return nil, nil end
        
        -- Try to get the spell information from the tooltip
        -- This is a fallback method for MoP compatibility
        
        -- First, try the global GetItemSpell if it exists
        if _G.GetItemSpell then
            return _G.GetItemSpell(itemID)
        end
        
        -- For MoP, we'll return nil as many items don't have spell effects
        -- that need to be tracked, or they're handled differently
        return nil, nil
    end
      -- Export the compatibility function
    ns.GetItemSpell = GetItemSpellCompat
end

-- MoP API compatibility for IsUsableItem
do    local function IsUsableItemCompat(itemID)
        -- In MoP, IsUsableItem function doesn't exist
        -- We'll create a compatibility layer
        if not itemID then return false end
        
        -- First, try the global IsUsableItem if it exists
        if _G.IsUsableItem then
            return _G.IsUsableItem(itemID)
        end
        
        -- For MoP compatibility, we'll check if the item exists
        -- Use the cached GetItemInfo function
        local itemName = ns.CachedGetItemInfo(itemID)
        return itemName ~= nil
    end
      -- Export the compatibility function
    ns.IsUsableItem = IsUsableItemCompat
end

-- MoP API compatibility for GetItemIcon
do
    local function GetItemIconCompat(itemID)
        -- In MoP, GetItemIcon function doesn't exist
        -- We need to get the icon from GetItemInfo
        if not itemID then return nil end
        
        -- First, try the global GetItemIcon if it exists
        if _G.GetItemIcon then
            return _G.GetItemIcon(itemID)
        end
        
        -- For MoP compatibility, extract icon from GetItemInfo
        local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = ns.CachedGetItemInfo(itemID)
        return texture
    end
    
    -- Export the compatibility function
    ns.GetItemIcon = GetItemIconCompat
end


-- Atlas -> Texture Stuff
do
    local db = {}

    local function AddTexString( name, file, width, height, left, right, top, bottom )
        local pctWidth = right - left
        local realWidth = width / pctWidth
        local lPoint = left * realWidth

        local pctHeight = bottom - top
        local realHeight = height / pctHeight
        local tPoint = top * realHeight

        db[ name ] = format( "|T%s:%%d:%%d:%%d:%%d:%d:%d:%d:%d:%d:%d:%%s|t", file, realWidth, realHeight, lPoint, lPoint + width, tPoint, tPoint + height )
    end

    local function GetTexString( name, width, height, x, y, r, g, b )
        return db[ name ] and format( db[ name ], width or 0, height or 0, x or 0, y or 0, ( r and g and b and ( r .. ":" .. g .. ":" .. b ) or "" ) ) or ""
    end    local function AtlasToString( atlas, width, height, x, y, r, g, b )
        if db[ atlas ] then
            return GetTexString( atlas, width, height, x, y, r, g, b )
        end        -- MoP: C_Texture.GetAtlasInfo not available
        return atlas
        -- local a = C_Texture.GetAtlasInfo( atlas )
        -- if not a then return atlas end
        -- AddTexString( atlas, a.file, a.width, a.height, a.leftTexCoord, a.rightTexCoord, a.topTexCoord, a.bottomTexCoord )
        -- return GetTexString( atlas, width, height, x, y, r, g, b )
    end    local function GetAtlasFile( atlas )
        -- MoP: C_Texture.GetAtlasInfo not available
        return atlas
        -- local a = C_Texture.GetAtlasInfo( atlas )
        -- return a and a.file or atlas
    end

    local function GetAtlasCoords( atlas )
        -- MoP: C_Texture.GetAtlasInfo not available
        return nil
        -- local a = C_Texture.GetAtlasInfo( atlas )
        -- return a and { a.leftTexCoord, a.rightTexCoord, a.topTexCoord, a.bottomTexCoord }
    end

    ns.AddTexString, ns.GetTexString, ns.AtlasToString, ns.GetAtlasFile, ns.GetAtlasCoords = AddTexString, GetTexString, AtlasToString, GetAtlasFile, GetAtlasCoords
end



function Hekili:GetSpec()
    if state.spec and state.spec.id and class.specs and class.specs[ state.spec.id ] then
        return class.specs[ state.spec.id ]
    end
    return nil
end



function Hekili:IsValidSpec()
    return state.spec and state.spec.id and class.specs and class.specs[ state.spec.id ] ~= nil
end


local IsAddOnLoaded = IsAddOnLoaded or function(name) return false end

function Hekili:GetLoadoutExportString()
    -- MoP: Talent loadout export not available
    return "MoP Export Unavailable"
end


do
    local cache = {}

    function Hekili:Loadstring( str )
        if cache[ str ] then return cache[ str ][ 1 ], cache[ str ][ 2 ] end
        local func, warn = loadstring( str )
        cache[ str ] = { func, warn }
        return func, warn
    end
end


do
    local marked = {}
    local supermarked = {}
    local pool = {}

    local seen = {}

    function ns.Mark( t, key )
        if not marked[ t ] then marked[ t ] = {} end
        marked[ t ][ key ] = true
    end

    function ns.SuperMark( table, keys )
        supermarked[ table ] = keys
    end

    function ns.AddToSuperMark( table, key )
        local sm = supermarked[ table ]
        if sm then
            insert( sm, key )
        end
    end

    function ns.ClearMarks( super )
        local count = 0
        local startTime = debugprofilestop()
        if super then
            for t, keys in pairs( supermarked ) do
                for key in pairs( keys ) do
                    rawset( t, key, nil )
                    count = count + 1
                end
            end

            wipe( seen )
        else
            for t, data in pairs( marked ) do
                for key in pairs( data ) do
                    rawset( t, key, nil )
                    data[ key ] = nil

                    count = count + 1
                end
            end
        end

        local endTime = debugprofilestop()
        if Hekili.ActiveDebug then Hekili:Debug( "Purged %d marked values in %.2fms.", count, endTime - startTime ) end
    end

    Hekili.Maintenance = {
        Dirty = marked,
        Cleaned = pool
    }
end