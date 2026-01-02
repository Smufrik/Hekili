local MAJOR, MINOR = "LibClassicSwingTimerAPI", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local callbacks = LibStub("CallbackHandler-1.0"):New(lib)
lib.callbacks = callbacks

if not lib.frame then
    lib.frame = CreateFrame("Frame")
end

local frame = lib.frame

local lastMainhandSwing = 0
local lastOffhandSwing = 0
local mainhandSpeed = 0
local offhandSpeed = 0

local function updateSwingSpeeds()
    local mhSpeed, ohSpeed = UnitAttackSpeed("player")
    if mhSpeed then
        mainhandSpeed = mhSpeed
    end
    if ohSpeed then
        offhandSpeed = ohSpeed
    end
end

local function onSwingEvent(event, ...)
    if event == "UNIT_ATTACK_SPEED" then
        local unit = ...
        if unit ~= "player" then return end
        updateSwingSpeeds()
        callbacks:Fire("SWING_TIMER_SPEED", mainhandSpeed, offhandSpeed)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        updateSwingSpeeds()
        callbacks:Fire("SWING_TIMER_SPEED", mainhandSpeed, offhandSpeed)
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellId = CombatLogGetCurrentEventInfo()
        local playerGUID = UnitGUID("player")

        if sourceGUID ~= playerGUID then return end

        if subEvent == "SWING_DAMAGE" or subEvent == "SWING_MISSED" then
            lastMainhandSwing = timestamp
            callbacks:Fire("SWING_TIMER_MAINHAND", timestamp, mainhandSpeed)
        elseif subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_MISSED" then
            -- Stormstrike / Lava Lash can count for offhand swings; treat specific spell IDs as offhand proxies
            if spellId == 25504 or spellId == 60103 or spellId == 17364 or spellId == 115356 then
                lastOffhandSwing = timestamp
                callbacks:Fire("SWING_TIMER_OFFHAND", timestamp, offhandSpeed)
            end
        end
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    onSwingEvent(event, ...)
end)

frame:RegisterEvent("UNIT_ATTACK_SPEED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

if not mainhandSpeed or mainhandSpeed == 0 then
    updateSwingSpeeds()
end

callbacks:Fire("SWING_TIMER_READY", mainhandSpeed, offhandSpeed)

return lib
