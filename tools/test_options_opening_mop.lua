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

local devtools = read_file("Options/DevTools.lua")
local options = read_file("Options/Options.lua")
local ui = read_file("UI.lua")

expect(devtools:find("local IsPassiveSpell = C_Spell and C_Spell.IsSpellPassive", 1, true), "DevTools must guard C_Spell.IsSpellPassive for MoP clients.")
expect(devtools:find("local IsHarmfulSpell = C_Spell and C_Spell.IsSpellHarmful", 1, true), "DevTools must guard C_Spell.IsSpellHarmful for MoP clients.")
expect(devtools:find("local IsHelpfulSpell = C_Spell and C_Spell.IsSpellHelpful", 1, true), "DevTools must guard C_Spell.IsSpellHelpful for MoP clients.")
expect(devtools:find("local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID", 1, true), "DevTools must guard C_ClassTalents before reading modern talent data.")
expect(devtools:find("local costs = C_Spell and C_Spell.GetSpellPowerCost", 1, true), "DevTools must guard C_Spell.GetSpellPowerCost for MoP clients.")

expect(ui:find("local ok, err = pcall( function()", 1, true), "StartConfiguration must protect options opening with pcall.")
expect(ui:find('error( "AceConfigDialog did not return an options frame." )', 1, true), "StartConfiguration must detect missing AceConfig frames.")
expect(ui:find("ns.StopConfiguration()", 1, true), "StartConfiguration must leave mover mode when options opening fails.")
expect(ui:find('Hekili:Print( "Unable to open options: " .. tostring( err ) )', 1, true), "StartConfiguration must report options opening failures.")

expect(options:find("Hekili.DB.profile.packs[ packControl.newPackName ] = Hekili.DB.profile.packs[ packControl.newPackName ] or {", 1, true), "Create New Pack must initialize the pack table before setting spec.")
expect(options:find("if not entry or not entry.lists then return end", 1, true), "Pack action list lookups must tolerate missing or broken packs.")
expect(options:find("if not apack or not apack.lists then return end", 1, true), "Pack action option lookups must tolerate missing or broken packs.")
expect(options:find("width = tonumber( width ) or ( GetScreenWidth and tonumber( GetScreenWidth() ) ) or 1280", 1, true), "Display option ranges must tolerate missing gxWindowedResolution width.")
expect(options:find("height = tonumber( height ) or ( GetScreenHeight and tonumber( GetScreenHeight() ) ) or 720", 1, true), "Display option ranges must tolerate missing gxWindowedResolution height.")

print("options opening MoP compatibility checks passed")
