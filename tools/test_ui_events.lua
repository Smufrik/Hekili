local function read_file( path )
    local file = assert( io.open( path, "rb" ) )
    local contents = file:read( "*a" )
    file:close()
    return contents
end

local function assert_contains( text, needle, message )
    if not text:find( needle, 1, true ) then
        error( message or ( "expected to find " .. needle ), 2 )
    end
end

local function assert_not_contains( text, needle, message )
    if text:find( needle, 1, true ) then
        error( message or ( "expected not to find " .. needle ), 2 )
    end
end

local ui = read_file( "UI.lua" )

assert_contains( ui, "SPELLS_CHANGED", "5.5.4 spellbook updates should use SPELLS_CHANGED" )
assert_not_contains( ui, "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_TAB is not available in the 5.5.4 client" )

print( "UI event regression checks passed" )
