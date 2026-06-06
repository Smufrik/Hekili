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

local range = read_file("Libs/LibRangeCheck-3.0/LibRangeCheck-3.0.lua")
local spellflash = read_file("Libs/SpellFlashCore/SpellFlashCore.lua")

expect(range:find("local function safeRegisterEvent", 1, true), "LibRangeCheck must guard event registration for removed MoP events.")
expect(not range:find('frame:RegisterEvent("LEARNED_SPELL_IN_TAB"', 1, true), "LibRangeCheck must not directly register removed LEARNED_SPELL_IN_TAB.")
expect(range:find('safeRegisterEvent(frame, "SPELLS_CHANGED")', 1, true), "LibRangeCheck must use SPELLS_CHANGED for spellbook refreshes.")
expect(range:find('safeRegisterEvent(frame, "CHARACTER_POINTS_CHANGED")', 1, true), "LibRangeCheck must guard CHARACTER_POINTS_CHANGED for client compatibility.")

expect(spellflash:find("local function SafeRegisterEvent", 1, true), "SpellFlashCore must guard event registration for removed MoP events.")
expect(not spellflash:find("Event.LEARNED_SPELL_IN_TAB", 1, true), "SpellFlashCore must not register removed LEARNED_SPELL_IN_TAB.")
expect(spellflash:find("Event.SPELLS_CHANGED = RegisterAll", 1, true), "SpellFlashCore must use SPELLS_CHANGED for spellbook refreshes.")
expect(spellflash:find("SafeRegisterEvent(EventFrame, event)", 1, true), "SpellFlashCore must use safe event registration in its event loop.")
expect(spellflash:find("if not SafeRegisterEvent(DebugEventFrame, event) then", 1, true), "SpellFlashCore debug events must also use safe event registration.")

print("legacy event compatibility checks passed")
