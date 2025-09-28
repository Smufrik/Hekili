---@meta

-- This file is for development diagnostics only and is not loaded by the addon.
-- It declares common World of Warcraft API globals and addon-scoped globals to
-- silence undefined-global warnings in the Lua language server/linter.

-- WoW UI object stubs
---@class Frame: table
local Frame = {}
---@return AnimationGroup
function Frame:CreateAnimationGroup() return {} end
function Frame:SetScript(event, handler) end

---@class Animation: table
local Animation = {}
function Animation:SetDuration(seconds) end

---@class AnimationGroup: table
local AnimationGroup = {}
function AnimationGroup:CreateAnimation(typeName) return Animation end
function AnimationGroup:Play() end
function AnimationGroup:Stop() end
function AnimationGroup:SetScript(event, handler) end

---@param frameType string
---@param name? string
---@param parent? any
---@param template? string
---@return Frame
function CreateFrame(frameType, name, parent, template) end

-- Common WoW API stubs
---@param unit string
---@param indexOrName any
---@param rank? string
---@param filter? string
function UnitBuff(unit, indexOrName, rank, filter) end

---@param unit string
---@param indexOrName any
---@param rank? string
---@param filter? string
function UnitDebuff(unit, indexOrName, rank, filter) end

---@param spell any
---@return string name, string rank, number icon, number castTime, number minRange, number maxRange, number spellId
function GetSpellInfo(spell) end

---@param spellID number
---@return string description
function GetSpellDescription(spellID) end

---@param spellID number
---@return string texture
function GetSpellTexture(spellID) end

---@param prefix string
---@return boolean ok
function RegisterAddonMessagePrefix(prefix) end

---@return string shape
function GetMinimapShape() end

---@param addon string
---@return boolean loaded
function IsAddOnLoaded(addon) end

---@param addon string
---@return boolean loaded
function LoadAddOn(addon) end

---@param index number
---@param bookType string
---@return string name
function GetSpellBookItemName(index, bookType) end

---@return integer count
function GetNumRaidMembers() end

---@return integer count
function GetNumPartyMembers() end

---@param index number
---@return boolean usable
function IsPetActionUsable(index) end

-- Global frames/tables referenced by the addon
OpacitySliderFrame = OpacitySliderFrame or {}
InterfaceOptionsFramePanelContainer = InterfaceOptionsFramePanelContainer or {}
HekiliTooltip = HekiliTooltip or {}
HekiliNotification = HekiliNotification or {}
HekiliDisplayPrimary = HekiliDisplayPrimary or {}
HekiliEngine = HekiliEngine or {}
ElvUI = ElvUI or {}

-- Addon/editor helpers sometimes referenced
AceGUIEditBoxInsertLink = AceGUIEditBoxInsertLink or function(...) end
AceGUIMultiLineEditBoxInsertLink = AceGUIMultiLineEditBoxInsertLink or function(...) end
HekiliCustomEditorInsertLink = HekiliCustomEditorInsertLink or function(...) end

-- Lua globals used in test/vendor code (harmless for diagnostics)
require = require
package = package
os = os
io = io
debug = debug
loadfile = loadfile


