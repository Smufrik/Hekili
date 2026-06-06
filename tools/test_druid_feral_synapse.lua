local function read_file(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function expect(condition, message)
    if not condition then
        error(message, 2)
    end
end

local feral = read_file("MistsOfPandaria/DruidFeral.lua")

expect(feral:find('local GetInventoryItemSpell = rawget( _G, "GetInventoryItemSpell" ) or function() return nil, nil end', 1, true), "Feral must use a safe GetInventoryItemSpell fallback.")
expect(feral:find('local INVSLOT_HAND = rawget( _G, "INVSLOT_HAND" ) or 10', 1, true), "Feral must use a safe INVSLOT_HAND fallback.")
expect(feral:find("local function hasSynapseSprings()", 1, true), "Feral must centralize Synapse Springs detection in a file-local helper.")
expect(not feral:find("local function has_synapse_springs", 1, true), "Feral refresh expressions must not declare unsafe local Synapse Springs helpers.")

local rakeExpr = feral:match('spec:RegisterStateExpr%(%s*"rake_refresh_time"%s*,%s*function%(%)(.-)end%s*%)')
local ripExpr = feral:match('spec:RegisterStateExpr%(%s*"rip_refresh_time"%s*,%s*function%(%)(.-)end%s*%)')

expect(rakeExpr and rakeExpr:find("hasSynapseSprings()", 1, true), "Rake refresh logic must use the safe Synapse Springs helper.")
expect(ripExpr and ripExpr:find("hasSynapseSprings()", 1, true), "Rip refresh logic must use the safe Synapse Springs helper.")
expect(not rakeExpr:find("GetInventoryItemSpell", 1, true), "Rake refresh logic must not call GetInventoryItemSpell directly.")
expect(not ripExpr:find("GetInventoryItemSpell", 1, true), "Rip refresh logic must not call GetInventoryItemSpell directly.")

print("druid feral synapse checks passed")
