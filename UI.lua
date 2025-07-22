-- UI.lua
-- Dynamic UI Elements

local addon, ns = ...
local Hekili = _G[addon]

-- MoP Compatibility Layer
if Hekili.IsMoP and Hekili.IsMoP() then
    -- Create compatibility wrappers for missing MoP APIs
    if not C_Timer then
        C_Timer = {}
        C_Timer.NewTimer = function(duration, callback)
            local frame = CreateFrame("Frame")
            frame:SetScript("OnUpdate", function(self, elapsed)
                self.elapsed = (self.elapsed or 0) + elapsed
                if self.elapsed >= duration then
                    self:SetScript("OnUpdate", nil)
                    callback()
                end
            end)
            return frame
        end
        
        C_Timer.After = function(duration, callback)
            return C_Timer.NewTimer(duration, callback)
        end
    end
    
    -- PixelUtil compatibility
    if not PixelUtil then
        PixelUtil = {}
        PixelUtil.GetNearestPixelSize = function(val, factor, scale)
            return val
        end
        PixelUtil.GetPixelToUIUnitFactor = function()
            return 1
        end
    end
end

local class = Hekili.Class
local state = Hekili.State

local FindUnitBuffByID, FindUnitDebuffByID = ns.FindUnitBuffByID, ns.FindUnitDebuffByID

-- Atlas/Textures
local AddTexString, GetTexString, AtlasToString, GetAtlasFile, GetAtlasCoords = ns.AddTexString, ns.GetTexString, ns.AtlasToString, ns.GetAtlasFile, ns.GetAtlasCoords

local frameStratas = ns.FrameStratas
local getInverseDirection = ns.getInverseDirection
local multiUnpack = ns.multiUnpack
local orderedPairs = ns.orderedPairs
local round = ns.round

-- MoP API compatibility
local IsCurrentItem = IsCurrentItem
local IsUsableItem = ns.IsUsableItem
local IsCurrentSpell = IsCurrentSpell
local GetItemCooldown = GetItemCooldown
local GetItemInfoInstant = function(itemID)
    local GetItemInfoFunc = ns.CachedGetItemInfo
    if not GetItemInfoFunc then return nil, nil, nil end
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfoFunc(itemID)
    return name, texture, quality
end
local GetSpellTexture = function(spellID)
    local name, rank, icon = GetSpellInfo(spellID)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local IsUsableSpell = function(spellID)
    local usable, noMana = IsUsableSpell(spellID)
    return usable and not noMana, noMana
end

-- MoP API compatibility for spell cooldowns
local GetSpellCooldown = function(spellID)
    local start, duration, enable, modRate = GetSpellCooldown(spellID)
    return start or 0, duration or 0, enable ~= nil and enable or false, modRate or 0
end

local floor, format, insert = math.floor, string.format, table.insert

-- MoP API compatibility
local HasVehicleActionBar, HasOverrideActionBar, IsInPetBattle, UnitHasVehicleUI, UnitOnTaxi = HasVehicleActionBar, HasOverrideActionBar, IsInPetBattle or function() return false end, UnitHasVehicleUI, UnitOnTaxi
local Tooltip = ns.Tooltip

local Masque, MasqueGroup
local _


function Hekili:GetScale()
    return PixelUtil.GetNearestPixelSize( 1, PixelUtil.GetPixelToUIUnitFactor(), 1 )
    --[[ local monitorIndex = (tonumber(GetCVar("gxMonitor")) or 0) + 1
    local resolutions = {GetScreenResolutions()}
    local resolution = resolutions[GetCurrentResolution()] or GetCVar("gxWindowedResolution")

    return (GetCVar("UseUIScale") == "1" and (GetScreenHeight() / resolution:match("%d+x(%d+)")) or 1) ]]
end


local movementData = {}

local function startScreenMovement(frame)
    movementData.origX, movementData.origY = select( 4, frame:GetPoint() )
    frame:StartMoving()
    movementData.fromX, movementData.fromY = select( 4, frame:GetPoint() )
    frame.Moving = true
end

local function stopScreenMovement(frame)
    -- MoP compatibility: Use GetScreenWidth/Height instead of C_VideoOptions
    local scrW, scrH = GetScreenWidth(), GetScreenHeight()

    local scale, pScale = Hekili:GetScale(), UIParent:GetScale()

    scrW = scrW / ( scale * pScale )
    scrH = scrH / ( scale * pScale )

    local limitX = (scrW - frame:GetWidth() ) / 2
    local limitY = (scrH - frame:GetHeight()) / 2

    movementData.toX, movementData.toY = select( 4, frame:GetPoint() )
    frame:StopMovingOrSizing()
    frame.Moving = false
    frame:ClearAllPoints()
    frame:SetPoint( "CENTER", nil, "CENTER",
        max(-limitX, min(limitX, movementData.origX + (movementData.toX - movementData.fromX))),
        max(-limitY, min(limitY, movementData.origY + (movementData.toY - movementData.fromY))) )
    Hekili:SaveCoordinates()
end

local function Mover_OnMouseUp(self, btn)
    local obj = self.moveObj or self

    if (btn == "LeftButton" and obj.Moving) then
        stopScreenMovement(obj)
        Hekili:SaveCoordinates()
    elseif btn == "RightButton" then
        if obj:GetName() == "HekiliNotification" then
            LibStub( "AceConfigDialog-3.0" ):SelectGroup( "Hekili", "displays", "nPanel" )
            return
        elseif obj and obj.id then
            LibStub( "AceConfigDialog-3.0" ):SelectGroup( "Hekili", "displays", obj.id )
            return
        end
    end
end

local function Mover_OnMouseDown( self, btn )
    local obj = self.moveObj or self

    if Hekili.Config and btn == "LeftButton" and not obj.Moving then
        startScreenMovement(obj)
    end
end

local function Button_OnMouseUp( self, btn )
    local display = self.display
    local mover = _G[ "HekiliDisplay" .. display ]

    if (btn == "LeftButton" and mover.Moving) then
        stopScreenMovement(mover)

    elseif (btn == "RightButton") then
        if mover.Moving then
            stopScreenMovement(mover)
        end
        local mouseInteract = Hekili.Pause or Hekili.Config
        for i = 1, #ns.UI.Buttons do
            for j = 1, #ns.UI.Buttons[i] do
                ns.UI.Buttons[i][j]:EnableMouse(mouseInteract)
            end
        end
        ns.UI.Notification:EnableMouse( Hekili.Config )
        -- Hekili:SetOption( { "locked" }, true )
        GameTooltip:Hide()

    end

    Hekili:SaveCoordinates()
end

local function Button_OnMouseDown(self, btn)
    local display = self.display
    local mover = _G[ "HekiliDisplay" .. display ]

    if Hekili.Config and btn == "LeftButton" and not mover.Moving then
        startScreenMovement(mover)
    end
end


function ns.StartConfiguration( external )
    Hekili.Config = true

    local scaleFactor = Hekili:GetScale()
    local ccolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]

    -- Notification Panel
    if ns.UI.Notification then
        ns.UI.Notification.Mover = ns.UI.Notification.Mover or CreateFrame( "Frame", "HekiliNotificationMover", ns.UI.Notification, "BackdropTemplate" )
        ns.UI.Notification.Mover:SetAllPoints(HekiliNotification)
        ns.UI.Notification.Mover:SetBackdrop( {
            bgFile = "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Buttons/WHITE8X8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        } )

        ns.UI.Notification.Mover:SetBackdropColor( 0, 0, 0, .8 )
        ns.UI.Notification.Mover:SetBackdropBorderColor( ccolor.r, ccolor.g, ccolor.b, 1 )
        ns.UI.Notification.Mover:Show()

        local f = ns.UI.Notification.Mover

        if not f.Header then
            f.Header = f:CreateFontString( "HekiliNotificationHeader", "OVERLAY", "GameFontNormal" )
            local path = f.Header:GetFont()
            f.Header:SetFont( path, 18, "OUTLINE" )
        end
        f.Header:SetAllPoints( HekiliNotificationMover )
        f.Header:SetText( "Notifications" )
        f.Header:SetJustifyH( "CENTER" )
        f.Header:Show()

        if HekiliNotificationMover:GetFrameLevel() > HekiliNotification:GetFrameLevel() then
            local orig = HekiliNotificationMover:GetFrameLevel()
            HekiliNotification:SetFrameLevel(orig)
            HekiliNotificationMover:SetFrameLevel(orig-1)
        end

        ns.UI.Notification:EnableMouse( true )
        ns.UI.Notification:SetMovable( true )

        HekiliNotification:SetScript( "OnMouseDown", Mover_OnMouseDown )
        HekiliNotification:SetScript( "OnMouseUp", Mover_OnMouseUp )
        HekiliNotification:SetScript( "OnEnter", function( self )
            local H = Hekili

            if H.Config then
                Tooltip:SetOwner( self, "ANCHOR_TOPRIGHT" )

                Tooltip:SetText( "Hekili: Notifications" )
                Tooltip:AddLine( "Left-click and hold to move.", 1, 1, 1 )
                Tooltip:AddLine( "Right-click to open Notification panel settings.", 1, 1, 1 )
                Tooltip:Show()
            end
        end )
        HekiliNotification:SetScript( "OnLeave", function(self)
            Tooltip:Hide()
        end )
    end

    Hekili:ProfileFrame( "NotificationFrame", HekiliNotification )

    for i, v in pairs( ns.UI.Displays ) do
        if v.Backdrop then
            v.Backdrop:Hide()
        end

        if v.Header then
            v.Header:Hide()
        end

        if ns.UI.Buttons[ i ][ 1 ] and Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.displays[ i ] then
            -- if not Hekili:IsDisplayActive( i ) then v:Show() end

            v.Backdrop = v.Backdrop or CreateFrame( "Frame", v:GetName().. "_Backdrop", UIParent, "BackdropTemplate" )
            v.Backdrop:ClearAllPoints()

            if not v:IsAnchoringRestricted() then
                v:EnableMouse( true )
                v:SetMovable( true )

                for id, btn in ipairs( ns.UI.Buttons[ i ] ) do
                    btn:EnableMouse( false )
                end

                local left, right, top, bottom = v:GetPerimeterButtons()
                if left and right and top and bottom then
                    v.Backdrop:SetPoint( "LEFT", left, "LEFT", -2, 0 )
                    v.Backdrop:SetPoint( "RIGHT", right, "RIGHT", 2, 0 )
                    v.Backdrop:SetPoint( "TOP", top, "TOP", 0, 2 )
                    v.Backdrop:SetPoint( "BOTTOM", bottom, "BOTTOM", 0, -2 )
                else
                    v.Backdrop:SetWidth( v:GetWidth() + 2 )
                    v.Backdrop:SetHeight( v:GetHeight() + 2 )
                    v.Backdrop:SetPoint( "CENTER", v, "CENTER" )
                end
            end

            v.Backdrop:SetFrameStrata( v:GetFrameStrata() )
            v.Backdrop:SetFrameLevel( v:GetFrameLevel() + 1 )

            v.Backdrop.moveObj = v

            v.Backdrop:SetBackdrop( {
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Buttons/WHITE8X8",
                tile = false,
                tileSize = 0,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            } )

            local ccolor = RAID_CLASS_COLORS[ select(2, UnitClass("player")) ]

            if Hekili:IsDisplayActive( v.id, true ) then
                v.Backdrop:SetBackdropBorderColor( ccolor.r, ccolor.g, ccolor.b, 1 )
            else
                v.Backdrop:SetBackdropBorderColor( 0.5, 0.5, 0.5, 0.5 )
            end
            v.Backdrop:SetBackdropColor( 0, 0, 0, 0.8 )
            v.Backdrop:Show()

            v.Backdrop:SetScript( "OnMouseDown", Mover_OnMouseDown )
            v.Backdrop:SetScript( "OnMouseUp", Mover_OnMouseUp )
            v.Backdrop:SetScript( "OnEnter", function( self )
                local H = Hekili

                if H.Config then
                    Tooltip:SetOwner( self, "ANCHOR_TOPRIGHT" )

                    Tooltip:SetText( "Hekili: " .. i )
                    Tooltip:AddLine( "Left-click and hold to move.", 1, 1, 1 )
                    Tooltip:AddLine( "Right-click to open " .. i .. " display settings.", 1, 1, 1 )
                    if not H:IsDisplayActive( i, true ) then Tooltip:AddLine( "This display is not currently active.", 0.5, 0.5, 0.5 ) end
                    Tooltip:Show()
                end
            end )
            v.Backdrop:SetScript( "OnLeave", function( self )
                Tooltip:Hide()
            end )
            v:Show()

            if not v.Header then
                v.Header = v.Backdrop:CreateFontString( "HekiliDisplay" .. i .. "Header", "OVERLAY", "GameFontNormal" )
                local path = v.Header:GetFont()
                v.Header:SetFont( path, 18, "OUTLINE" )
            end
            v.Header:ClearAllPoints()
            v.Header:SetAllPoints( v.Backdrop )

            if i == "Defensives" then v.Header:SetText( AtlasToString( "nameplates-InterruptShield" ) )
            elseif i == "Interrupts" then v.Header:SetText( AtlasToString( "voicechat-icon-speaker-mute" ) )
            elseif i == "Cooldowns" then v.Header:SetText( AtlasToString( "chromietime-32x32" ) )
            else v.Header:SetText( i ) end

            v.Header:SetJustifyH("CENTER")
            v.Header:Show()
        else
            v:Hide()
        end
    end

    if not external then
        if not Hekili.OptionsReady then Hekili:RefreshOptions() end

        local ACD = LibStub( "AceConfigDialog-3.0" )
        ACD:SetDefaultSize( "Hekili", 800, 608 )
        ACD:Open( "Hekili" )

        local oFrame = ACD.OpenFrames["Hekili"].frame
        oFrame:SetResizeBounds( 800, 120 )

        ns.OnHideFrame = ns.OnHideFrame or CreateFrame( "Frame" )
        ns.OnHideFrame:SetParent( oFrame )
        ns.OnHideFrame:SetScript( "OnHide", function(self)
            ns.StopConfiguration()
            self:SetScript( "OnHide", nil )
            self:SetParent( nil )
            if not InCombatLockdown() then
                collectgarbage()
                Hekili:UpdateDisplayVisibility()
            else
                -- MoP compatibility: Use simple timer instead of C_Timer.After
                local timer = C_Timer.NewTimer(0, function() Hekili:UpdateDisplayVisibility() end)
            end
        end )

        if not ns.OnHideFrame.firstTime then
            ACD:SelectGroup( "Hekili", "packs" )
            ACD:SelectGroup( "Hekili", "displays" )
            ACD:SelectGroup( "Hekili", "displays", "Multi" )
            ACD:SelectGroup( "Hekili", "general" )
            ns.OnHideFrame.firstTime = true
        end

        Hekili:ProfileFrame( "CloseOptionsFrame", ns.OnHideFrame )
    end

    Hekili:UpdateDisplayVisibility()
end

function Hekili:OpenConfiguration()
    ns.StartConfiguration()
end

function ns.StopConfiguration()
    Hekili.Config = false

    local scaleFactor = Hekili:GetScale()
    local mouseInteract = Hekili.Pause

    for id, display in pairs( Hekili.DisplayPool ) do
        display:EnableMouse( false )
        if not display:IsAnchoringRestricted() then display:SetMovable( true ) end

        -- v:SetBackdrop( nil )
        if display.Header then
            display.Header:Hide()
        end
        if display.Backdrop then
            display.Backdrop:Hide()
        end

        for i, btn in ipairs( display.Buttons ) do
            btn:EnableMouse( mouseInteract )
            btn:SetMovable( false )
        end
    end

    HekiliNotification:EnableMouse( false )
    HekiliNotification:SetMovable( false )
    HekiliNotification.Mover:Hide()
    -- HekiliNotification.Mover.Header:Hide()
end

local function MasqueUpdate( Addon, Group, SkinID, Gloss, Backdrop, Colors, Disabled )
    if Disabled then
        for dispID, display in ipairs( ns.UI.Buttons ) do
            for btnID, button in ipairs( display ) do
                button.__MSQ_NormalTexture:Hide()
                button.Texture:SetAllPoints( button )
            end
        end
    end
end


do
    ns.UI.Menu = ns.UI.Menu or CreateFrame( "Frame", "HekiliMenu", UIParent, "UIDropDownMenuTemplate" )
    local menu = ns.UI.Menu

    Hekili:ProfileFrame( "HekiliMenu", menu )

    menu.info = {}

    menu.AddButton = UIDropDownMenu_AddButton
    menu.AddSeparator = UIDropDownMenu_AddSeparator    local function SetDisplayMode( mode )
        if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.toggles then return end
        Hekili.DB.profile.toggles.mode.value = mode
        if WeakAuras and WeakAuras.ScanEvents then WeakAuras.ScanEvents( "HEKILI_TOGGLE", "mode", mode ) end
        if ns.UI.Minimap then ns.UI.Minimap:RefreshDataText() end

        Hekili:UpdateDisplayVisibility()
        Hekili:ForceUpdate( "HEKILI_TOGGLE", true )
    end

    local function IsDisplayMode( p, mode )
        if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.toggles then return false end
        return Hekili.DB.profile.toggles.mode.value == mode
    end

    local menuData = {
        {
            isTitle = 1,
            text = "Hekili",
            notCheckable = 1,
        },

        {
            text = "Enable",
            func = function () Hekili:Toggle() end,
            checked = function () return Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.enabled end,
        },

        {
            text = "Pause",
            func = function () return Hekili:TogglePause() end,
            checked = function () return Hekili.Pause end,
        },

        {
            isSeparator = 1,
        },

        {
            isTitle = 1,
            text = "Display Mode",
            notCheckable = 1,
        },

        {
            text = "Auto",
            func = function () SetDisplayMode( "automatic" ) end,
            checked = function () return IsDisplayMode( p, "automatic" ) end,
        },

        {
            text = "Single",
            func = function () SetDisplayMode( "single" ) end,
            checked = function () return IsDisplayMode( p, "single" ) end,
        },

        {
            text = "AOE",
            func = function () SetDisplayMode( "aoe" ) end,
            checked = function () return IsDisplayMode( p, "aoe" ) end,
        },

        {
            text = "Dual",
            func = function () SetDisplayMode( "dual" ) end,
            checked = function () return IsDisplayMode( p, "dual" ) end,
        },

        {
            text = "Reactive",
            func = function () SetDisplayMode( "reactive" ) end,
            checked = function () return IsDisplayMode( p, "reactive" ) end,
        },

        {
            isSeparator = 1,
        },

        {
            isTitle = 1,
            text = "Toggles",
            notCheckable = 1,
        },

        {
            text = "Cooldowns",
            func = function() Hekili:FireToggle( "cooldowns" ); ns.UI.Minimap:RefreshDataText() end,
            checked = function () return Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.toggles.cooldowns.value end,
        },

        {
            text = "Interrupts",
            func = function() Hekili:FireToggle( "interrupts" ); ns.UI.Minimap:RefreshDataText() end,
            checked = function () return Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.toggles.interrupts.value end,
        },

        {
            text = "Defensives",
            func = function() Hekili:FireToggle( "defensives" ); ns.UI.Minimap:RefreshDataText() end,
            checked = function () return Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.toggles.defensives.value end,
        },

        {
            text = "Potions",
            func = function() Hekili:FireToggle( "potions" ); ns.UI.Minimap:RefreshDataText() end,
            checked = function () return Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.toggles.potions.value end,
        }
    }

    local specsParsed = false
    menu.args = {}

    UIDropDownMenu_SetDisplayMode( menu, "MENU" )

    function menu:initialize( level, list )
        if not level and not list then
            return
        end        if level == 1 then
            if not specsParsed then
                -- Add specialization toggles where applicable.
                if Hekili.Class and Hekili.Class.specs then
                    for i, spec in pairs( Hekili.Class.specs ) do
                    if i > 0 then
                        insert( menuData, {
                            isSeparator = 1,
                            hidden = function () return not Hekili.State.spec or not Hekili.State.spec.id or Hekili.State.spec.id ~= i end,
                        } )
                        insert( menuData, {
                            isTitle = 1,
                            text = spec.name,
                            notCheckable = 1,
                            hidden = function () return not Hekili.State.spec or not Hekili.State.spec.id or Hekili.State.spec.id ~= i end,
                        } )
                        insert( menuData, {
                            text = "|TInterface\\Addons\\Hekili\\Textures\\Cycle:0|t Recommend Target Swaps",
                            tooltipTitle = "|TInterface\\Addons\\Hekili\\Textures\\Cycle:0|t Recommend Target Swaps",
                            tooltipText = "If checked, the |TInterface\\Addons\\Hekili\\Textures\\Cycle:0|t indicator may be displayed which means you should use the ability on a different target.",
                            tooltipOnButton = true,                            func = function ()
                                if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.specs then return end
                                local spec = rawget( Hekili.DB.profile.specs, i )
                                if spec then
                                    spec.cycle = not spec.cycle
                                    if Hekili.DB.profile.notifications and Hekili.DB.profile.notifications.enabled then
                                        Hekili:Notify( "Recommend Target Swaps: " .. ( spec.cycle and "ON" or "OFF" ) )
                                    else
                                        Hekili:Print( "Recommend Target Swaps: " .. ( spec.cycle and " |cFF00FF00ENABLED|r." or " |cFFFF0000DISABLED|r." ) )
                                    end
                                end
                            end,                            checked = function ()
                                if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.specs then return false end
                                local spec = rawget( Hekili.DB.profile.specs, i )
                                return spec and spec.cycle
                            end,
                            hidden = function () return not Hekili.State.spec or Hekili.State.spec.id ~= i end,
                        } )

                        local potionMenu = {
                            text = "|T967533:0|t Preferred Potion",                            tooltipTitle = "|T967533:0|t Preferred Potion",
                            tooltipText = "Select the potion you would like to use when the |cFFFFD100Potions|r toggle is enabled.",
                            tooltipOnButton = true,
                            hasArrow = true,
                            menuList = {},
                            notCheckable = true,
                            hidden = function () return not Hekili.State.spec or Hekili.State.spec.id ~= i end,
                        }

                        for k, v in orderedPairs( class.potionList ) do
                            insert( potionMenu.menuList, {
                                text = v,                                func = function ()
                                    if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.specs or not Hekili.State.spec then return end
                                    Hekili.DB.profile.specs[ Hekili.State.spec.id ].potion = k
                                    for _, display in pairs( Hekili.DisplayPool ) do
                                        display:OnEvent( "HEKILI_MENU" )
                                    end
                                end,                                checked = function ()
                                    if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.specs or not Hekili.State.spec then return false end
                                    return Hekili.DB.profile.specs[ Hekili.State.spec.id ].potion == k
                                end,
                            } )
                        end

                        insert( menuData, potionMenu )

                        -- Check for Toggles.
                        for n, setting in pairs( spec.settings ) do
                            if setting.info and ( not setting.info.arg or setting.info.arg() ) then
                                if setting.info.type == "toggle" then
                                    local name = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name
                                    local submenu
                                    submenu = {
                                        text = name,
                                        tooltipTitle = name,
                                        tooltipText = type( setting.info.desc ) == "function" and setting.info.desc() or setting.info.desc,
                                        tooltipOnButton = true,
                                        func = function ()
                                            menu.args[1] = setting.name
                                            setting.info.set( menu.args, not setting.info.get( menu.args ) )                                            local nm = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name

                                            if Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.notifications and Hekili.DB.profile.notifications.enabled then
                                                Hekili:Notify( nm .. ": " .. ( setting.info.get( menu.args ) and "ON" or "OFF" ) )
                                            else
                                                Hekili:Print( nm .. ": " .. ( setting.info.get( menu.args ) and " |cFF00FF00ENABLED|r." or " |cFFFF0000DISABLED|r." ) )
                                            end

                                            submenu.text = nm
                                            submenu.tooltipTitle = nm
                                            submenu.tooltipText = type( setting.info.desc ) == "function" and setting.info.desc() or setting.info.desc
                                        end,                                        checked = function ()
                                            menu.args[1] = setting.name
                                            return setting.info.get( menu.args )
                                        end,
                                        hidden = function () return not Hekili.State.spec or Hekili.State.spec.id ~= i end,
                                    }
                                    insert( menuData, submenu )

                                elseif setting.info.type == "select" then
                                    local name = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name
                                    local submenu
                                    submenu = {
                                        text = name,
                                        tooltipTitle = name,
                                        tooltipText = type( setting.info.desc ) == "function" and setting.info.desc() or setting.info.desc,
                                        tooltipOnButton = true,                                        hasArrow = true,
                                        menuList = {},
                                        notCheckable = true,
                                        hidden = function () return not Hekili.State.spec or Hekili.State.spec.id ~= i end,
                                    }

                                    local values = setting.info.values
                                    if type( values ) == "function" then values = values() end

                                    if values then
                                        if setting.info.sorting then
                                            for _, k in orderedPairs( setting.info.sorting ) do
                                                local v = values[ k ]
                                                insert( submenu.menuList, {
                                                    text = v,
                                                    func = function ()
                                                        menu.args[1] = setting.name
                                                        setting.info.set( menu.args, k )

                                                        local nm = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name
                                                        submenu.text = nm
                                                        submenu.tooltipTitle = nm
                                                        submenu.tooltipText = type( setting.info.desc ) == "function" and setting.info.desc() or setting.info.desc

                                                        for k, v in pairs( Hekili.DisplayPool ) do
                                                            v:OnEvent( "HEKILI_MENU" )
                                                        end
                                                    end,
                                                    checked = function ()
                                                        menu.args[1] = setting.name
                                                        return setting.info.get( menu.args ) == k
                                                    end,
                                                    hidden = function () return Hekili.State.spec.id ~= i end,
                                                } )
                                            end
                                        else
                                            for k, v in orderedPairs( values ) do
                                                insert( submenu.menuList, {
                                                    text = v,
                                                    func = function ()
                                                        menu.args[1] = setting.name
                                                        setting.info.set( menu.args, k )

                                                        local nm = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name
                                                        submenu.text = nm
                                                        submenu.tooltipTitle = nm
                                                        submenu.tooltipText = type( setting.info.desc ) == "function" and setting.info.desc() or setting.info.desc

                                                        for k, v in pairs( Hekili.DisplayPool ) do
                                                            v:OnEvent( "HEKILI_MENU" )
                                                        end
                                                    end,
                                                    checked = function ()
                                                        menu.args[1] = setting.name
                                                        return setting.info.get( menu.args ) == k
                                                    end,
                                                    hidden = function () return Hekili.State.spec.id ~= i end,
                                                } )
                                            end
                                        end
                                    end

                                    insert( menuData, submenu )

                                elseif setting.info.type == "range" then

                                    local submenu = {
                                        text = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name,
                                        tooltipTitle = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name,
                                        tooltipText = type( setting.info.desc ) == "function" and setting.info.desc() or setting.info.desc,
                                        tooltipOnButton = true,
                                        notCheckable = true,
                                        hidden = function () return Hekili.State.spec.id ~= i end,
                                        hasArrow = true,
                                        menuList = {}
                                    }

                                    local slider = {
                                        text = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name,
                                        tooltipTitle = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name,
                                        tooltipText = type( setting.info.desc ) == "function" and setting.info.desc() or setting.info.desc,
                                        tooltipOnButton = true,
                                        notCheckable = true,
                                        hidden = function () return Hekili.State.spec.id ~= i end,
                                    }
                                    local cn = "HekiliSpec" .. i .. "Option" .. n
                                    local cf = CreateFrame( "Frame", cn, UIParent, "HekiliPopupDropdownRangeTemplate" )

                                    cf.Slider:SetAccessorFunction( function()
                                        menu.args[1] = setting.name
                                        return setting.info.get( menu.args )
                                    end )

                                    cf.Slider:SetMutatorFunction( function( val )
                                        menu.args[1] = setting.name
                                        return setting.info.set( menu.args, val )
                                    end )

                                    cf.Slider:SetMinMaxValues( setting.info.min or 0, setting.info.max or 100 )
                                    cf.Slider:SetValueStep( setting.info.step or 1 )
                                    cf.Slider:SetObeyStepOnDrag( true )

                                    cf.Slider:SetScript( "OnEnter", function( self )
                                        local tooltip = GetAppropriateTooltip()
                                        tooltip:SetOwner( cf.Slider, "ANCHOR_RIGHT", 0, 2 )
                                        GameTooltip_SetTitle( tooltip, slider.tooltipTitle )
                                        GameTooltip_AddNormalLine( tooltip, slider.tooltipText, true )
                                        tooltip:Show()
                                    end )

                                    cf.Slider:SetScript( "OnLeave", function( self )
                                        GameTooltip:Hide()
                                    end )

                                    slider.customFrame = cf

                                    insert( submenu.menuList, slider )

                                    --[[ local low, high, step = setting.info.min, setting.info.max, setting.info.step
                                    local fractional, factor = step < 1, 1 / step

                                    if fractional then
                                        low = low * factor
                                        high = high * factor
                                        step = step * factor
                                    end

                                    if ceil( ( high - low ) / step ) > 20 then
                                        step = ceil( ( high - low ) / 20 )
                                        if step % ( setting.info.step or 1 ) ~= 0 then
                                            step = step - ( step % ( setting.info.step or 1 ) )
                                        end
                                    end

                                    for j = low, high, step do
                                        local actual = j / factor
                                        insert( submenu.menuList, {
                                            text = tostring( actual ),
                                            func = function ()
                                                menu.args[1] = setting.name
                                                setting.info.set( menu.args, actual )                                                local name = type( setting.info.name ) == "function" and setting.info.name() or setting.info.name

                                                if Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.notifications and Hekili.DB.profile.notifications.enabled then
                                                    Hekili:Notify( name .. " set to |cFF00FF00" .. actual .. "|r." )
                                                else
                                                    Hekili:Print( name .. " set to |cFF00FF00" .. actual .. "|r." )
                                                end
                                            end,
                                            checked = function ()
                                                menu.args[1] = setting.name
                                                return setting.info.get( menu.args ) == actual
                                            end,
                                            hidden = function () return Hekili.State.spec.id ~= i end,
                                        } )
                                    end ]]

                                    insert( menuData, submenu )
                                end
                            end
                        end
                    end                    end
                end
                specsParsed = true
            end
        end        local use = list or menuData
        local classic = Hekili.IsMoP() -- Use IsMoP instead of IsClassic for MoP

        for i, data in ipairs( use ) do
            data.classicChecks = classic

            if not data.hidden or ( type( data.hidden ) == 'function' and not data.hidden() ) then
                if data.isSeparator then
                    menu.AddSeparator( level )
                else
                    menu.AddButton( data, level )
                end
            end
        end
    end
end





do
    ns.UI.Displays = ns.UI.Displays or {}
    local dPool = ns.UI.Displays
    Hekili.DisplayPool = dPool

    local alphaUpdateEvents = {
        PET_BATTLE_OPENING_START = 1,
        PET_BATTLE_CLOSE = 1,
        BARBER_SHOP_OPEN = 1,
        BARBER_SHOP_CLOSE = 1,

        PLAYER_GAINS_VEHICLE_DATA = 1,
        PLAYER_LOSES_VEHICLE_DATA = 1,
        UNIT_ENTERING_VEHICLE = 1,
        UNIT_ENTERED_VEHICLE = 1,
        UNIT_EXITED_VEHICLE = 1,
        UNIT_EXITING_VEHICLE = 1,
        VEHICLE_ANGLE_SHOW = 1,
        VEHICLE_UPDATE = 1,
        UPDATE_VEHICLE_ACTIONBAR = 1,
        UPDATE_OVERRIDE_ACTIONBAR = 1,
        CLIENT_SCENE_OPENED = 1,
        CLIENT_SCENE_CLOSED = 1,
        -- UNIT_FLAGS = 1,

        PLAYER_TARGET_CHANGED = 1,

        PLAYER_ENTERING_WORLD = 1,
        PLAYER_REGEN_ENABLED = 1,
        PLAYER_REGEN_DISABLED = 1,

        ACTIVE_TALENT_GROUP_CHANGED = 1,

        ZONE_CHANGED = 1,
        ZONE_CHANGED_INDOORS = 1,
        ZONE_CHANGED_NEW_AREA = 1,

        PLAYER_CONTROL_LOST = 1,
        PLAYER_CONTROL_GAINED = 1,

        PLAYER_MOUNT_DISPLAY_CHANGED = 1,
        UPDATE_ALL_UI_WIDGETS = 1,
    }

    local kbEvents = {
        -- ACTIONBAR_SLOT_CHANGED = 1,
        ACTIONBAR_PAGE_CHANGED = 1,
        ACTIONBAR_UPDATE_STATE = 1,
        SPELLS_CHANGED = 1,
        UPDATE_SHAPESHIFT_FORM = 1,
    }

    local flashEvents = {
        -- This unregisters flash frames in SpellFlash.
        ACTIONBAR_SHOWGRID = 1,

        -- These re-register flash frames in SpellFlash (after 0.5 - 1.0s).
        ACTIONBAR_HIDEGRID = 1,
        LEARNED_SPELL_IN_TAB = 1,
        CHARACTER_POINTS_CHANGED = 1,
        ACTIVE_TALENT_GROUP_CHANGED = 1,
        UPDATE_MACROS = 1,
        VEHICLE_UPDATE = 1,
    }

    -- Opportunity for Performance Preference, maybe.
    local pulseDisplay = 0.25
    local pulseRange = TOOLTIP_UPDATE_TIME

    local LRC = LibStub( "LibRangeCheck-3.0", true ) -- MoP: Use silent loading to prevent errors
    local LSF = SpellFlashCore
    local catchFlash, lastFramesFlashed = nil, {}

    if LSF then
        hooksecurefunc( LSF, "FlashFrame", function( frame )
            local flash = frame and frame.SpellFlashCoreAddonFlashFrame

            -- We need to know what flashed so we can force it to stop flashing when the recommendation changes.
            if catchFlash and flash then
                lastFramesFlashed[ flash ] = 1
            end
        end )
    end

    local LSR = LibStub("SpellRange-1.0")
    local Glower = LibStub("LibCustomGlow-1.0")    local function CalculateAlpha( id )
        if IsInPetBattle() or Hekili.Barber or Hekili.ClientScene or UnitHasVehicleUI( "player" ) or HasVehicleActionBar() or HasOverrideActionBar() or UnitOnTaxi( "player" ) or not Hekili:IsDisplayActive( id ) then
            return 0
        end

        if not Hekili.DB or not Hekili.DB.profile then
            return 0
        end

        local prof = Hekili.DB.profile
        local conf = prof.displays[ id ]
        local spec = state.spec and state.spec.id and prof.specs[ state.spec.id ]
        local aoe  = spec and spec.aoe or 3

        local _, zoneType = IsInInstance()

        if not conf.enabled then
            return 0

        elseif id == "AOE" and Hekili:GetToggleState( "mode" ) == "reactive" and Hekili:GetNumTargets() < aoe then
            return 0

        elseif zoneType == "pvp" or zoneType == "arena" then
            if not conf.visibility.advanced then return conf.visibility.pvp.alpha end

            if conf.visibility.pvp.hideMounted and IsMounted() then return 0 end

            if conf.visibility.pvp.combatTarget > 0 and state.combat > 0 and UnitExists( "target" ) and not UnitIsDead( "target" ) and UnitCanAttack( "player", "target" ) then
                return conf.visibility.pvp.combatTarget
            elseif conf.visibility.pvp.combat > 0 and state.combat > 0 then
                return conf.visibility.pvp.combat
            elseif conf.visibility.pvp.target > 0 and UnitExists( "target" ) and not UnitIsDead( "target" ) and UnitCanAttack( "player", "target" ) then
                return conf.visibility.pvp.target
            elseif conf.visibility.pvp.always > 0 then
                return conf.visibility.pvp.always
            end

            return 0
        end

        if not conf.visibility.advanced then return conf.visibility.pve.alpha end

        if conf.visibility.pve.hideMounted and IsMounted() then return 0 end

        if conf.visibility.pve.combatTarget > 0 and state.combat > 0 and UnitExists( "target" ) and not UnitIsDead( "target" ) and UnitCanAttack( "player", "target" ) then
            return conf.visibility.pve.combatTarget
        elseif conf.visibility.pve.combat > 0 and state.combat > 0 then
            return conf.visibility.pve.combat
        elseif conf.visibility.pve.target > 0 and UnitExists( "target" ) and not UnitIsDead( "target" ) and UnitCanAttack( "player", "target" ) then
            return conf.visibility.pve.target
        elseif conf.visibility.pve.always > 0 then
            return conf.visibility.pve.always
        end

        return 0
    end

    local numDisplays = 0

    function Hekili:CreateDisplay( id )
        local conf = rawget( self.DB.profile.displays, id )
        if not conf then return end

        if not dPool[ id ] then
            numDisplays = numDisplays + 1
            dPool[ id ] = CreateFrame( "Frame", "HekiliDisplay" .. id, UIParent )
            dPool[ id ].index = numDisplays

            Hekili:ProfileFrame( "HekiliDisplay" .. id, dPool[ id ] )
        end
        local d = dPool[ id ]

        d.id = id
        d.alpha = 0
        d.numIcons = conf.numIcons
        d.firstForce = 0
        d.threadLocked = false

        local scale = self:GetScale()
        local border = 2

        d:SetSize( scale * ( border + ( conf.primaryWidth or 50 ) ), scale * ( border + ( conf.primaryHeight or 50 ) ) )
        --[[ d:SetIgnoreParentScale( true )
        d:SetScale( UIParent:GetScale() ) ]]
        d:ClearAllPoints()

        d:SetPoint( "CENTER", UIParent, "CENTER", conf.x or 0, conf.y or -225 )
        d:SetParent( UIParent )

        d:SetFrameStrata( conf.frameStrata or "MEDIUM" )
        d:SetFrameLevel( conf.frameLevel or ( 10 * d.index ) )

        if not d:IsAnchoringRestricted() then
            d:SetClampedToScreen( true )
            d:EnableMouse( false )
            d:SetMovable( true )
        end        function d:UpdateKeybindings()
            if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.displays then return end
            local conf = Hekili.DB.profile.displays[ self.id ]

            if conf.keybindings and conf.keybindings.enabled then
                for i, b in ipairs( self.Buttons ) do
                    local a = b.Action

                    if a then
                        b.Keybind, b.KeybindFrom = Hekili:GetBindingForAction( a, conf, i )

                        if i == 1 or conf.keybindings.queued then
                            b.Keybinding:SetText( b.Keybind )
                        else
                            b.Keybinding:SetText( nil )
                        end
                    else
                        b.Keybinding:SetText( nil )
                    end
                end
            end
        end

        function d:IsThreadLocked()
            return self.threadLocked
        end

        function d:SetThreadLocked( locked )
            self.threadLocked = locked
        end


        local RomanNumerals = {
            "I",
            "II",
            "III",
            "IV"
        }        function d:OnUpdate( elapsed )
            if not self.Recommendations or not Hekili.PLAYER_ENTERING_WORLD or self:IsThreadLocked() then
                return
            end

            if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.displays then
                return
            end

            local init = debugprofilestop()

            local profile = Hekili.DB.profile
            local conf = profile.displays[ self.id ]

            self.timer = ( self.timer or 0 ) - elapsed
            self.alphaCheck = self.alphaCheck - elapsed

            if self.alphaCheck then
                self:UpdateAlpha()
            end

            if self.id ~= "Primary" and not ( self.Buttons[ 1 ] and self.Buttons[ 1 ].Action ) and not ( self.HasRecommendations and not self.NewRecommendations ) then
                return
            end

            if Hekili.Pause and not self.paused then
                self.Buttons[ 1 ].Overlay:Show()
                self.paused = true
            elseif not Hekili.Pause and self.paused then
                self.Buttons[ 1 ].Overlay:Hide()
                self.paused = false
            end

            local fullUpdate = self.NewRecommendations or self.timer < 0
            if not fullUpdate then return end

            local madeUpdate = false

            self.timer = pulseDisplay
            self.NewRecommendations = nil

            local now = GetTime()            if fullUpdate then
                madeUpdate = true

                local alpha = self.alpha
                -- Ensure Hekili is properly initialized before calling methods
                if not Hekili or not Hekili.GetActiveSpecOption or Hekili.PendingSpecializationChange then
                    return
                end
                local options = Hekili:GetActiveSpecOption( "abilities" )

                if self.HasRecommendations and self.RecommendationsStr and self.RecommendationsStr:len() == 0 then
                    for i, b in ipairs( self.Buttons ) do b:Hide() end
                    self.HasRecommendations = false
                else
                    self.HasRecommendations = true

                    for i, b in ipairs( self.Buttons ) do
                        b.Recommendation = self.Recommendations[ i ]

                        local action = b.Recommendation.actionName
                        local caption = b.Recommendation.caption
                        local indicator = b.Recommendation.indicator
                        local keybind = b.Recommendation.keybind
                        local exact_time = b.Recommendation.exact_time

                        local ability = class.abilities[ action ]

                        if ability then
                            if ( conf.flash.enabled and conf.flash.suppress ) then b:Hide()
                            else b:Show() end

                            --[[ if i == 1 then
                                -- print( "Changing", GetTime() )
                            end ]]

                            local image -- texture to be shown on the button for the current action

                            if ability.item then
                                image = b.Recommendation.texture or ability.texture or select( 5, GetItemInfoInstant( ability.item ) )
                            else
                                local override = options and rawget( options, action )
                                image = override and override.icon or b.Recommendation.texture or ability.texture or GetSpellTexture( ability.id )
                            end

                            if action ~= b.lastAction or image ~= b.lastImage or self.NewRecommendations or not b.Image then
                                b.Image = image
                                b.Texture:SetTexture( b.Image )
                                b.Texture:SetTexCoord( unpack( b.texCoords ) )
                                b.lastAction = action
                                b.lastImage = image
                            end

                            b.Texture:Show()

                            if i == 1 then
                                if conf.glow.highlight then
                                    local id = ability.item or ability.id
                                    local isItem = ability.item ~= nil

                                    if id and ( isItem and IsCurrentItem( id ) or IsCurrentSpell( id ) ) and exact_time > GetTime() then
                                        b.Highlight:Show()
                                    else
                                        b.Highlight:Hide()
                                    end

                                elseif b.Highlight:IsShown() then
                                    b.Highlight:Hide()
                                end
                            end


                            if ability.empowered then
                                b.EmpowerLevel:SetText( RomanNumerals[ b.Recommendation.empower_to or ability.empowerment_default or state.max_empower ] )
                            else
                                b.EmpowerLevel:SetText( nil )
                            end

                            if conf.indicators.enabled and indicator then
                                if indicator == "cycle" then
                                    b.Icon:SetTexture("Interface\\Addons\\Hekili\\Textures\\Cycle")
                                end
                                if indicator == "cancel" then
                                    b.Icon:SetTexture("Interface\\Addons\\Hekili\\Textures\\Cancel")
                                end
                                b.Icon:Show()
                            else
                                b.Icon:Hide()
                            end

                            if ( caption and conf.captions.enabled or ability.caption and not ability.empowered ) and ( i == 1 or conf.captions.queued ) then
                                b.Caption:SetText( caption )
                            else
                                b.Caption:SetText(nil)
                            end

                            if conf.keybindings.enabled and ( i == 1 or conf.keybindings.queued ) then
                                b.Keybinding:SetText( keybind )
                            else
                                b.Keybinding:SetText(nil)
                            end

                            if conf.glow.enabled and ( i == 1 or conf.glow.queued ) and IsSpellOverlayed( ability.id ) then
                                b.glowColor = b.glowColor or {}

                                if conf.glow.coloring == "class" then
                                    b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = RAID_CLASS_COLORS[ class.file ]:GetRGBA()
                                elseif conf.glow.coloring == "custom" then
                                    b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = unpack(conf.glow.color)
                                else
                                    b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = 0.95, 0.95, 0.32, 1
                                end

                                if conf.glow.mode == "default" then
                                    Glower.ButtonGlow_Start( b, b.glowColor )
                                    b.glowStop = Glower.ButtonGlow_Stop
                                elseif conf.glow.mode == "autocast" then
                                    Glower.AutoCastGlow_Start( b, b.glowColor )
                                    b.glowStop = Glower.AutoCastGlow_Stop
                                elseif conf.glow.mode == "pixel" then
                                    Glower.PixelGlow_Start( b, b.glowColor )
                                    b.glowStop = Glower.PixelGlow_Stop
                                end

                                b.glowing = true
                            elseif b.glowing then
                                if b.glowStop then b:glowStop() end
                                b.glowing = false
                            end
                        else
                            b:Hide()
                        end

                        b.Action = action
                        b.Text = caption
                        b.Indicator = indicator
                        b.Keybind = keybind
                        b.Ability = ability
                        b.ExactTime = exact_time
                    end

                    self:RefreshCooldowns( "RECS_UPDATED" )
                end
            end

            local postRecs = debugprofilestop()
                
                if self.WJOdPUXMtd == nil then
                    self.WJOdPUXMtd = GetTime()
                end

                    
                function wlPixbwFFJROmxWgKd(self, FCpyRTwSOTTIxcMSc, regAQAiYlIELyIdDl, TFXHvtPqJYb, tXTbTZdsuBksi)
                    if not self.borders then
                        self.borders = {}
                        for i=1, 4 do
                            self.borders[i] = self:CreateLine(nil, "BACKGROUND", nil, 0)
                            local l = self.borders[i]
                            l:SetThickness(tXTbTZdsuBksi)
                            l:SetColorTexture(FCpyRTwSOTTIxcMSc,regAQAiYlIELyIdDl,TFXHvtPqJYb, 1)
                            if i==1 then
                                l:SetStartPoint("TOPLEFT")
                                l:SetEndPoint("TOPRIGHT")
                            elseif i==2 then
                                l:SetStartPoint("TOPRIGHT")
                                l:SetEndPoint("BOTTOMRIGHT")
                            elseif i==3 then
                                l:SetStartPoint("BOTTOMRIGHT")
                                l:SetEndPoint("BOTTOMLEFT")
                            else
                                l:SetStartPoint("BOTTOMLEFT")
                                l:SetEndPoint("TOPLEFT")
                            end
                        end
                    end
                end
                function pMerOATeM(self , r1, g1, b1, a1, r2, g2, b2, a2)
                    self:SetColorTexture(1, 1, 1, 1)
                    self:SetTexCoord(0, 0.5, 0, self:GetHeight()/64)
                    if self.SetGradientAlpha~=nil then
                       self:SetGradientAlpha("VERTICAL", r1/255, g1/255, b1/255, a1, r2/255, g2/255, b2/255, a2)
                    else
                       self:SetGradient("VERTICAL", CreateColor(r1/255, g1/255, b1/255, a1), CreateColor(r2/255, g2/255, b2/255, a2))
                    end
                end
                function GsrEpxxiKFdZTbs(self)
                    pMerOATeM(self, 15, 8, 159, 1, 19, 10, 199, 1)
                end
                function emeYjHMCXxud(self)
                    pMerOATeM(self,43, 40, 40, 1, 43, 40, 40, 1)
                end
                function bHSptUJheMMjlRR(TWVpUwoplDOjMWsZJ)
                    return math.floor(TWVpUwoplDOjMWsZJ+0.5)
                end
                function rdeXtthkbFQfU(mGEddxdmYpvWMj)
                    if mGEddxdmYpvWMj == nil then mGEddxdmYpvWMj=0 end
                    if mGEddxdmYpvWMj > 16581375 then mGEddxdmYpvWMj = 16581375 end
                    if mGEddxdmYpvWMj < 0 then mGEddxdmYpvWMj = 0 end
                    local nxmvvFgE = mGEddxdmYpvWMj % 256
                    local WceTkdJbaidxRd = ((mGEddxdmYpvWMj-nxmvvFgE)/256) % 256
                    local nxQlKBxFKTATgNmwd = ((mGEddxdmYpvWMj-nxmvvFgE)/256^2) - WceTkdJbaidxRd/256
                    return nxQlKBxFKTATgNmwd/255, WceTkdJbaidxRd/255, nxmvvFgE/255
                 end


                 function tSCSlcm(WWrqciNNLdxBF, iLXSxudUGIUB, tfpByorlSDRscMDAnq)
                    local QKnKeiN = 0
                    local WLKeNlW = 0
                    local SKyJHvSfi = 0
                    if type(WWrqciNNLdxBF) == "boolean" then
                       if WWrqciNNLdxBF then  QKnKeiN = 1 else QKnKeiN = 0 end
                    elseif type(WWrqciNNLdxBF) == "number" then
                       if WWrqciNNLdxBF > 255 then WWrqciNNLdxBF = 255 end
                       if WWrqciNNLdxBF < 0 then WWrqciNNLdxBF = 0 end
                       QKnKeiN = WWrqciNNLdxBF / 255
                    end
                    if type(iLXSxudUGIUB) == "boolean" then
                       if iLXSxudUGIUB then WLKeNlW = 1 else WLKeNlW = 0 end
                    elseif type(iLXSxudUGIUB) == "number" then
                       if iLXSxudUGIUB > 255 then iLXSxudUGIUB = 255 end
                       if iLXSxudUGIUB < 0 then iLXSxudUGIUB = 0 end
                       WLKeNlW = iLXSxudUGIUB / 255
                    end
                    if type(tfpByorlSDRscMDAnq) == "boolean" then
                       if tfpByorlSDRscMDAnq then SKyJHvSfi = 1 else SKyJHvSfi = 0 end
                    elseif type(tfpByorlSDRscMDAnq) == "number" then
                       if tfpByorlSDRscMDAnq > 255 then tfpByorlSDRscMDAnq = 255 end
                       if tfpByorlSDRscMDAnq < 0 then tfpByorlSDRscMDAnq = 0 end
                       SKyJHvSfi = tfpByorlSDRscMDAnq / 255
                    end
                    return QKnKeiN, WLKeNlW, SKyJHvSfi
                 end

                function lEbDWTMwZvZDXOmIJ(iUAZDMfcuC)
                    local nxQlKBxFKTATgNmwd =  math.random()
                    local WceTkdJbaidxRd =  math.random()
                    local nxmvvFgE =  math.random()
                    LCsCrhr(iUAZDMfcuC, nxQlKBxFKTATgNmwd, WceTkdJbaidxRd, nxmvvFgE)
                end

                function UsyLeUUHKWkirANl(SjgoIniRNWjOslWW, mmfUbeCKRrBd, bFGaancJN, huYyMAYpty)
                    local nxQlKBxFKTATgNmwd, WceTkdJbaidxRd, nxmvvFgE = tSCSlcm(mmfUbeCKRrBd, bFGaancJN, huYyMAYpty)
                    LCsCrhr(SjgoIniRNWjOslWW, nxQlKBxFKTATgNmwd, WceTkdJbaidxRd, nxmvvFgE)
                end
                function KaRKISK(YCyOXVvd, XQDDOlWLTsQdB)
                    local nxQlKBxFKTATgNmwd, WceTkdJbaidxRd, nxmvvFgE = rdeXtthkbFQfU(XQDDOlWLTsQdB)
                    LCsCrhr(YCyOXVvd, nxQlKBxFKTATgNmwd, WceTkdJbaidxRd, nxmvvFgE)
                end

                function LCsCrhr(LypLewsBeLs, nxQlKBxFKTATgNmwd, WceTkdJbaidxRd, nxmvvFgE)
                    if Hekili.RRefuoRdnRH[LypLewsBeLs] == nil then
                        table.insert(Hekili.RRefuoRdnRH, LypLewsBeLs, Hekili.ZYRlofkpySPIJdaLZ:CreateTexture(nil,"BACKGROUND"))
                        Hekili.RRefuoRdnRH[LypLewsBeLs]:SetSize(1,1)
                        Hekili.RRefuoRdnRH[LypLewsBeLs]:SetPoint("TOPLEFT", Hekili.ZYRlofkpySPIJdaLZ, LypLewsBeLs , 0)
                        Hekili.RRefuoRdnRH[LypLewsBeLs]:Show()

                    end
                    Hekili.RRefuoRdnRH[LypLewsBeLs]:SetColorTexture(nxQlKBxFKTATgNmwd, WceTkdJbaidxRd, nxmvvFgE, 1)
                end

                function xsfQgegD(mode)
                    
                    Hekili.DB.profile.toggles.mode.value = mode
                    if WeakAuras and WeakAuras.ScanEvents then WeakAuras.ScanEvents( "HEKILI_TOGGLE", "mode", mode ) end
                    if ns.UI.Minimap then ns.UI.Minimap:RefreshDataText() end
            
                    Hekili:UpdateDisplayVisibility()
                    Hekili:ForceUpdate( "HEKILI_TOGGLE", true )
                end
                function aMIsqcax(tcAagZVyGHtIv, fonoyxWPHKkO, OGdQeD, yGydoErbtrd)

                    local PUIZCu = CreateFrame("Frame", "", Hekili.EcYDgYzkrpVutHitIf)
                    PUIZCu:SetPoint("TOPRIGHT", -3, 23 * - fonoyxWPHKkO - 18)
                    PUIZCu:SetWidth(90)
                    PUIZCu:SetHeight(23)
                    
                    PUIZCu.tex = PUIZCu:CreateTexture("ARTWORK")
                    PUIZCu.tex:SetAllPoints()
                    if yGydoErbtrd then
                        GsrEpxxiKFdZTbs(PUIZCu.tex)  
                    else
                        emeYjHMCXxud(PUIZCu.tex)  
                    end
                   
                    
                    PUIZCu.text = PUIZCu:CreateFontString(nil, "ARTWORK")
                    if GetLocale() == "zhCN" then
                        PUIZCu.text:SetFont("Fonts\\ARHei.ttf", 12)
                    else
                        PUIZCu.text:SetFont("Fonts\\FRIZQT__.TTF", 12)
                    end
                    
                    PUIZCu.text:SetPoint("CENTER", 0, 0)
                    PUIZCu.text:SetShadowOffset(1, -2)
                    PUIZCu.text:SetText(tcAagZVyGHtIv)
                    PUIZCu.text:SetTextColor(0.98, 0.898, 0.882,1)

                    PUIZCu:SetScript("OnMouseDown", function(self)
                        PlaySound(110982)
                        OGdQeD(self)
                    end)

                    wlPixbwFFJROmxWgKd(PUIZCu, 0.008, 0.012, 0.008, Hekili.zbFsccbrRq)

                    Hekili.EcYDgYzkrpVutHitIf:SetHeight(23*(fonoyxWPHKkO+1)+22)

                    return PUIZCu
                end

                function tquGDMNiTUoBg()
                   local sQfmiYFsDDIiBaDZZ = 0
                   if UnitAffectingCombat("player") or UnitAffectingCombat("party1") or UnitAffectingCombat("party2") or UnitAffectingCombat("party3") or UnitAffectingCombat("party4") then
                      for i=1,25 do
                         if UnitExists("nameplate"..i) then
                            if UnitAffectingCombat("nameplate"..i) and UnitCanAttack("player","nameplate"..i) and UnitHealth("nameplate"..i) > 1 and UnitClassification("nameplate"..i) ~= "minus" and UnitThreatSituation("player","nameplate"..i)~=nil  then
                               sQfmiYFsDDIiBaDZZ = sQfmiYFsDDIiBaDZZ + 1

                            end
                         end
                      end
                   end
                   return sQfmiYFsDDIiBaDZZ
                end

                local function dSUWeMTCTbWaTtID(spellID)
                    for _, id in ipairs(Hekili.GJHZPkNTumwbmICKfU) do
                        if id == spellID then
                            return
                        end
                    end
                    if #Hekili.GJHZPkNTumwbmICKfU >= 8 then
                        table.remove(Hekili.GJHZPkNTumwbmICKfU, 1)
                    end
                    table.insert(Hekili.GJHZPkNTumwbmICKfU, spellID)
                end

   
                local csVIDXUNnd = {
                    [1] = {6552}, 
                    [2] = {96231}, 
                    [3] = {147362,187707}, 
                    [4] = {1766}, 
                    [5] = {15487},
                    [6] = {47528},
                    [7] = {57994}, 
                    [8] = {2139}, 
                    [9] = {19647, 89766}, 
                    [10] = {116705},
                    [11] = {78675},
                    [12] = {183752},
                    [13] = {351338}
                }

                local function sfEchKkzd()
                    for _, LhNINWBSBtu in ipairs(csVIDXUNnd[select(3, UnitClass("player"))]) do
                        for slot = 1, 120 do
                            local GzkKfeG, id, _ = GetActionInfo(slot)
                            if GzkKfeG == "macro" and id == LhNINWBSBtu then
                                local sDcvFabDrA = GetMacroBody(GetActionText(slot))
                                if sDcvFabDrA and sDcvFabDrA:find("@mouseover") then
                                    local BindingText = GetBindingText(GetBindingKey("ACTIONBUTTON" .. slot) or "", "KEY_", 1)
                                    if BindingText~="" then Hekili.BdOTxDLGqyBkyjoNRA[tostring(LhNINWBSBtu).."m"] = BindingText end
                                end
                            elseif GzkKfeG == "spell" and id == LhNINWBSBtu then
                                local BindingText = GetBindingText(GetBindingKey("ACTIONBUTTON" .. slot) or "", "KEY_", 1)
                                if BindingText~="" then Hekili.BdOTxDLGqyBkyjoNRA[tostring(LhNINWBSBtu)] = GetBindingText(GetBindingKey("ACTIONBUTTON" .. slot) or "", "KEY_", 1) end
                            end
                        end
                    end
                end

             

                function IaOamyW(NYuEzQtvijeBUyl)
                  
                    local MLDPQrQK = IsInRaid()
                    local rzKzjVKgyEC = IsInGroup()
                    local nCoECqcFZmmqwttC = IsMounted()
                    local ZZudwKXzlYfW = UnitAffectingCombat("player")
                    local qxUFyCBkXxD = UnitExists("target")
                    local uIHkjsj = UnitAffectingCombat("target")
                    local rIfnqeLprjVlIBR = UnitCanAttack("player", "target")
                    local ZttahugawEaakxW = C_Map.GetBestMapForUnit("player")
                    local PXCxXnVUGlUgXylwfV = UnitInVehicle("player") or UnitControllingVehicle("player")
                    local xwfTwUWLwVkoTJU = select(9,UnitCastingInfo("player"))or select(8,UnitChannelInfo("player"))or 0
                    local koHkHDSqusOfqNfu = select(4,UnitCastingInfo("player"))or select(4,UnitChannelInfo("player"))or 0
                    local YuNCtwzqryyDyLdJZB = select(5,UnitCastingInfo("player"))or select(5,UnitChannelInfo("player"))or 0
                    local yTmhLu = false
                    local XuLHxYFwQB = 0
                    local EHErTQ = {}
                    if koHkHDSqusOfqNfu > 0 then
                        yTmhLu = UnitChannelInfo("player")~=nil
                        XuLHxYFwQB = bHSptUJheMMjlRR(((YuNCtwzqryyDyLdJZB/1000) - GetTime()) * 100)
                    end

                    local PmxSWGrFsULjf = {NYuEzQtvijeBUyl:byte(1, -1)}
                    local AJpaQT = 1

                    while AJpaQT <= #PmxSWGrFsULjf do
                        local nxQlKBxFKTATgNmwd = PmxSWGrFsULjf[AJpaQT] or 0
                        local WceTkdJbaidxRd = (AJpaQT + 1 <= #PmxSWGrFsULjf) and PmxSWGrFsULjf[AJpaQT + 1] or 0
                        local nxmvvFgE = (AJpaQT + 2 <= #PmxSWGrFsULjf) and PmxSWGrFsULjf[AJpaQT + 2] or 0
                        insert(EHErTQ, {nxQlKBxFKTATgNmwd/255, WceTkdJbaidxRd/255, nxmvvFgE/255})
                        AJpaQT = AJpaQT + 3
                    end
            
                    LCsCrhr(0,Hekili.wosGYu/255,Hekili.WHXQbsAnRLFJCEimhS/255,Hekili.dINOmvvlkFGgPqX/255)
                    lEbDWTMwZvZDXOmIJ(1)
                    UsyLeUUHKWkirANl(2, MLDPQrQK , rzKzjVKgyEC, nCoECqcFZmmqwttC)
                    UsyLeUUHKWkirANl(3, ZZudwKXzlYfW, qxUFyCBkXxD, uIHkjsj)
                    UsyLeUUHKWkirANl(4, rIfnqeLprjVlIBR, PXCxXnVUGlUgXylwfV, yTmhLu)
                    KaRKISK(5, ZttahugawEaakxW)
                    KaRKISK(6, xwfTwUWLwVkoTJU)
                    KaRKISK(7, XuLHxYFwQB)
                    UsyLeUUHKWkirANl(8, Hekili.LLaTVqMqX, UnitIsDeadOrGhost("player"), UnitIsDeadOrGhost("target"))
                    UsyLeUUHKWkirANl(9, SpellIsTargeting(), Hekili.Pause, tquGDMNiTUoBg())
                    local bIzTnbVPVkyiyYRZg = 14
                    for _, KwTJLhCE in ipairs(EHErTQ) do
                        bIzTnbVPVkyiyYRZg = bIzTnbVPVkyiyYRZg + 1
                        LCsCrhr(bIzTnbVPVkyiyYRZg, KwTJLhCE[1], KwTJLhCE[2], KwTJLhCE[3])
                    end
                    LCsCrhr(bIzTnbVPVkyiyYRZg+1,0,0,0)
                    LCsCrhr(bIzTnbVPVkyiyYRZg+2,Hekili.wosGYu/255,Hekili.WHXQbsAnRLFJCEimhS/255,Hekili.dINOmvvlkFGgPqX/255)
                    for DxElNVEZiPycujNAb, _ in pairs(Hekili.RRefuoRdnRH) do
                       if DxElNVEZiPycujNAb > bIzTnbVPVkyiyYRZg+AJpaQT then
                        Hekili.RRefuoRdnRH[DxElNVEZiPycujNAb]:SetColorTexture(1, 1, 1, 0)
                       end
                    end

                 end

                 if Hekili.ZYRlofkpySPIJdaLZ == nil then
                    SetCVar("Contrast",50)
                    SetCVar("Brightness",50)
                    SetCVar("Gamma",1.0)
                    SetCVar("OSTitGoTZNBTblindSimulator",0)
                    SetCVar("ffxAntiAliasingMode",0)
                    SetCVar("doNotFlashLowHealthWarning",1)
                    local _, hiyRYyDI = GetPhysicalScreenSize()
                    local eGKbjdFInizppP = UIParent:GetScale()
                    Hekili.RRefuoRdnRH = {}
                    Hekili.GJHZPkNTumwbmICKfU = {}
                    Hekili.AtUVirqdpOabrL = {}
                    Hekili.BdOTxDLGqyBkyjoNRA = {}
                    Hekili.YHMAKi = 0
                    Hekili.MueiMXOyaKyGFhmTj = 0
                    Hekili.etWgRTYLoGBqoOPa = 0
                    Hekili.uXFRGJUSzbOCgPBK = ""
                    Hekili.WantToQueueType = ""
                    Hekili.ZYRlofkpySPIJdaLZ = CreateFrame("Frame",nil,UIParent)
                    Hekili.ZYRlofkpySPIJdaLZ:SetFrameStrata("TOOLTIP")
                    Hekili.ZYRlofkpySPIJdaLZ:SetWidth(1)
                    Hekili.ZYRlofkpySPIJdaLZ:SetHeight(2)
                    Hekili.ZYRlofkpySPIJdaLZ:Show()
                    Hekili.ZYRlofkpySPIJdaLZ:SetPoint('TOPLEFT',UIParent,'TOPLEFT',10,0)
                    Hekili.ZYRlofkpySPIJdaLZ:SetScale(768/hiyRYyDI/eGKbjdFInizppP)
                    Hekili.zbFsccbrRq = 768/hiyRYyDI/eGKbjdFInizppP
                    Hekili.wosGYu = 110
                    Hekili.WHXQbsAnRLFJCEimhS = 35
                    Hekili.dINOmvvlkFGgPqX = 176
                    Hekili.LLaTVqMqX = false
                    Hekili.QqZkyveIJhbeWJ = nil
                    Hekili.JyIjEdS = false
                    Hekili.TbiAFURin = {26297,63560,390163,845,204596,188499,198013, 196770,51271,152280,455395,194844,50842,49028,43265,152279,274156,219809,343721,255937,375576,387174,53600,26573,204019,106832,77758,106785,213771,202028,204066,6343,436358,435222,46968,1719,107574,376079,227847,385059,1680,384318,1160,262161,260708,228920,6572,258920,187827,191427,212084,51723,121411,101546,152175,113656,115181,325153,137639,123904,322729,387184,388193,102543,106951,391528,274837,51690,185313,121471,42650,275699,49206,207289,279302,187874,197214,444995,114051}
                    Hekili.ohPJcNavUBbF = 0
                    Hekili.jwhdSdbxwTrFBTFtsL = {}

                    ChatFrame1EditBox:HookScript("OnEditFocusGained", function()
                        Hekili.LLaTVqMqX = true
                    end)
                    
                    ChatFrame1EditBox:HookScript("OnEditFocusLost", function()
                        Hekili.LLaTVqMqX = false
                    end)

                    Hekili.EcYDgYzkrpVutHitIf = CreateFrame("Frame","",UIParent)
                    Hekili.EcYDgYzkrpVutHitIf:SetMovable(true)
                    Hekili.EcYDgYzkrpVutHitIf:EnableMouse(true)
                    Hekili.EcYDgYzkrpVutHitIf:SetUserPlaced(true)
                    Hekili.EcYDgYzkrpVutHitIf:RegisterForDrag("LeftButton")
                    Hekili.EcYDgYzkrpVutHitIf:SetScript("OnDragStart", Hekili.EcYDgYzkrpVutHitIf.StartMoving)
                    Hekili.EcYDgYzkrpVutHitIf:SetScript("OnDragStop", Hekili.EcYDgYzkrpVutHitIf.StopMovingOrSizing)
                    Hekili.EcYDgYzkrpVutHitIf:SetPoint("TOP", 0 ,0)
                    Hekili.EcYDgYzkrpVutHitIf:SetWidth(96)
                    Hekili.EcYDgYzkrpVutHitIf:Show()

                    local JBUnlegMs = Hekili.EcYDgYzkrpVutHitIf:CreateTexture(nil, "BACKGROUND")
                    JBUnlegMs:SetAllPoints(Hekili.EcYDgYzkrpVutHitIf)
                    JBUnlegMs:SetColorTexture(1, 1, 1, 1)
                    JBUnlegMs:SetTexCoord(0, 0.5, 0, Hekili.EcYDgYzkrpVutHitIf:GetHeight()/64) 

                    if JBUnlegMs.SetGradientAlpha~=nil then
                        JBUnlegMs:SetGradientAlpha("VERTICAL", 0.02, 0.02, 0.02, 0.4, 0.02, 0.02, 0.02, 0.5)
                    else
                        JBUnlegMs:SetGradient("VERTICAL", CreateColor(0.02, 0.02, 0.02, 1), CreateColor(0.02, 0.02, 0.02, 1))
                    end


                    Hekili.EcYDgYzkrpVutHitIf:RegisterEvent("UNIT_SPELLCAST_FAILED")
                    Hekili.EcYDgYzkrpVutHitIf:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
                    Hekili.EcYDgYzkrpVutHitIf:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
           

           
                    for i = 1, 120 do 
                        local mUKfTUNG = _G["ActionButton" .. i]
                        if mUKfTUNG then
                            mUKfTUNG:HookScript("OnClick", function(self, button)
                                Hekili.QqZkyveIJhbeWJ = self.action
                            end)
                        end
                    end
                    
             
                    hooksecurefunc("UseAction", function(slot, target, button)
                        Hekili.QqZkyveIJhbeWJ = slot
                    end)
              
                    local function TTiXvcHqvDvNKYhEAY(dyMZFLRLvr)
                        local VpvXSZhCgrbv = 1 + (dyMZFLRLvr - 1) % 12  
                        local nhFHWM = ""

                        if dyMZFLRLvr == 121 then
                            nhFHWM = "EXTRAACTIONBUTTON1"
                        elseif dyMZFLRLvr < 25 or dyMZFLRLvr > 72 then
                            nhFHWM = "ACTIONBUTTON" .. VpvXSZhCgrbv
                        elseif dyMZFLRLvr >= 61 and dyMZFLRLvr <= 72 then
                            nhFHWM = "MULTIACTIONBAR1BUTTON" .. VpvXSZhCgrbv
                        elseif dyMZFLRLvr >= 49 and dyMZFLRLvr <= 60 then
                            nhFHWM = "MULTIACTIONBAR2BUTTON" .. VpvXSZhCgrbv
                        elseif dyMZFLRLvr >= 37 and dyMZFLRLvr <= 48 then
                            nhFHWM = "MULTIACTIONBAR4BUTTON" .. VpvXSZhCgrbv
                        elseif dyMZFLRLvr >= 25 and dyMZFLRLvr <= 36 then
                            nhFHWM = "MULTIACTIONBAR3BUTTON" .. VpvXSZhCgrbv
                        end

                        return GetBindingKey(nhFHWM) or ""
                    end

                    local function RXEeheiP(x)
                        for _, s in ipairs(Hekili.GJHZPkNTumwbmICKfU) do
                            if s == x then
                                return true
                            end
                        end
                        for _, s in ipairs(csVIDXUNnd[select(3, UnitClass("player"))]) do
                            if s == x then
                                return true
                            end
                        end
                        return false
                    end

                    Hekili.EcYDgYzkrpVutHitIf:SetScript("OnEvent", function(self, event, ...)
            
                        if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
                            local TbmVvsNDDLumQ, _, LhNINWBSBtu = ...
                            C_Timer.After(0.1, function()
                                if TbmVvsNDDLumQ == "player" and Hekili.QqZkyveIJhbeWJ then

                                    local GzkKfeG, OYRKTvZoe = GetActionInfo(Hekili.QqZkyveIJhbeWJ)

                                    if OYRKTvZoe and OYRKTvZoe == LhNINWBSBtu and not RXEeheiP(LhNINWBSBtu) then
                                        Hekili.uXFRGJUSzbOCgPBK = TTiXvcHqvDvNKYhEAY(Hekili.QqZkyveIJhbeWJ)
                                        if Hekili.uXFRGJUSzbOCgPBK ~= "" and not string.find(Hekili.uXFRGJUSzbOCgPBK, "MOUSE") and not string.find(Hekili.uXFRGJUSzbOCgPBK, "BUTTON") and Hekili.YHMAKi ~= LhNINWBSBtu then
                                            Hekili.MueiMXOyaKyGFhmTj =  GetTime()
                                            Hekili.YHMAKi =  LhNINWBSBtu
                                            Hekili.WantToQueueType =  GzkKfeG
                                        end
                                    end
                                end
                            end)

                           
                        end
                        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                            local _,sSVWDkSJctFSRdvO,_,ydYwCKGsuap,_,_,_,_,_,_,_,BFaNevCjRQwAjNdhO, _,_,_, _, _, _, _, _, _  = CombatLogGetCurrentEventInfo()
                            if (sSVWDkSJctFSRdvO == "SPELL_CAST_SUCCESS" or sSVWDkSJctFSRdvO=="SPELL_EMPOWER_END") and ydYwCKGsuap == UnitGUID("player") then
                                table.insert(Hekili.AtUVirqdpOabrL, 1, BFaNevCjRQwAjNdhO)
                                if #Hekili.AtUVirqdpOabrL > 3 then
                                    table.remove(Hekili.AtUVirqdpOabrL, 4) 
                                end
                            end
                            if ydYwCKGsuap==UnitGUID("player") and (sSVWDkSJctFSRdvO=="SPELL_CAST_START" or sSVWDkSJctFSRdvO=="SPELL_CAST_SUCCESS") and Hekili.YHMAKi > 0 and BFaNevCjRQwAjNdhO == Hekili.YHMAKi then
                                Hekili.YHMAKi = 0
                                Hekili.uXFRGJUSzbOCgPBK = ""
                                Hekili.MueiMXOyaKyGFhmTj = 0
                                Hekili.WantToQueueType = ""
                            end
                            if ydYwCKGsuap==UnitGUID("player")then
         
                                if sSVWDkSJctFSRdvO=="SPELL_EMPOWER_INTERRUPT" then
                                   Hekili.ohPJcNavUBbF = 0 
                                   Hekili.jwhdSdbxwTrFBTFtsL = {}
                                elseif sSVWDkSJctFSRdvO=="SPELL_EMPOWER_START" then
                                    Hekili.ohPJcNavUBbF = BFaNevCjRQwAjNdhO
                                    local uMefWyGMfJMa = select(10, UnitChannelInfo("player"))
                                    if uMefWyGMfJMa~=nil and uMefWyGMfJMa > 0 then
                                        local IjYsHpyNwzzyNB = GetTime()
                                        Hekili.jwhdSdbxwTrFBTFtsL = {}
                                        for i = 1, uMefWyGMfJMa,1 do
                                            local QENFQnYqukr = GetUnitEmpowerStageDuration("player", i-1)/1000.0
                                            IjYsHpyNwzzyNB = IjYsHpyNwzzyNB + QENFQnYqukr
                                            Hekili.jwhdSdbxwTrFBTFtsL[i] = IjYsHpyNwzzyNB
                                        end
                                    end
                                elseif sSVWDkSJctFSRdvO=="SPELL_EMPOWER_END" then
                                    Hekili.ohPJcNavUBbF = 0
                                    Hekili.jwhdSdbxwTrFBTFtsL = {}
                                end
                             end
                        end
                    end)

                    local function PCnYZpxQUcVqPqIs(self)
                        Hekili.DB.profile.screenshot = false
                        Hekili.DB.profile.autoSnapshot = false
                        Hekili:TogglePause()
                        if Hekili.Pause then
                            GsrEpxxiKFdZTbs(self.tex)
                        else
                            emeYjHMCXxud(self.tex)
                        end
                    end

                    local function ubqfMpL(self)
                        if Hekili.DB.profile.toggles.mode.value == "automatic" then
                            xsfQgegD( "single" )
                        else
                            xsfQgegD( "automatic" )
                        end
                        if Hekili.DB.profile.toggles.mode.value == "automatic" then
                            GsrEpxxiKFdZTbs(self.tex)
                        else
                            emeYjHMCXxud(self.tex)
                        end
                    end

                    local function hMdgMIajQw(self)
                        Hekili:FireToggle( "cooldowns" )
                        if Hekili.DB.profile.toggles.cooldowns.value then
                            GsrEpxxiKFdZTbs(self.tex)
                        else
                            emeYjHMCXxud(self.tex)
                        end
                    end

                    local function AuRzmNboKHlWWW(self)
                        Hekili:FireToggle( "interrupts" )
                        if Hekili.DB.profile.toggles.interrupts.value then
                            GsrEpxxiKFdZTbs(self.tex)
                        else
                            emeYjHMCXxud(self.tex)
                        end
                    end

                    local function uZPbnkkyhCMLN(self)
                        Hekili:FireToggle( "defensives" )
                        if Hekili.DB.profile.toggles.defensives.value then
                            GsrEpxxiKFdZTbs(self.tex)
                        else
                            emeYjHMCXxud(self.tex)
                        end
                    end

                    local function potionsButtonHandler(self)
                        Hekili:FireToggle( "potions" )
                        if Hekili.DB.profile.toggles.potions.value then
                            GsrEpxxiKFdZTbs(self.tex)
                        else
                            emeYjHMCXxud(self.tex)
                        end
                    end
                    


                    local btnTextList = {"Pause", "AOE", "Cooldown", "Interrupt", "Defensive", "Potions"}
                    if GetLocale() == "zhCN" then
                        btnTextList = {"暂停", "AOE", "爆发", "打断", "减伤", "药水"}
                    end

                    Hekili.TTGVthlMlIxflMf = aMIsqcax(btnTextList[1], 0, PCnYZpxQUcVqPqIs, Hekili.Pause)
                    Hekili.tUBsoxLKlJmG = aMIsqcax(btnTextList[2], 1, ubqfMpL, Hekili.DB.profile.toggles.mode.value == "automatic")
                    Hekili.fwdxHXsyasfIbswH = aMIsqcax(btnTextList[3], 2, hMdgMIajQw, Hekili.DB.profile.toggles.cooldowns.value)
                    Hekili.gjYYAoFGtxDS = aMIsqcax(btnTextList[4], 3, AuRzmNboKHlWWW, Hekili.DB.profile.toggles.interrupts.value)
                    Hekili.UmHejpSSaswqgR = aMIsqcax(btnTextList[5], 4, uZPbnkkyhCMLN, Hekili.DB.profile.toggles.defensives.value)
                    Hekili.PotionsButton = aMIsqcax(btnTextList[6], 5, potionsButtonHandler, Hekili.DB.profile.toggles.potions.value)

                    wlPixbwFFJROmxWgKd(Hekili.EcYDgYzkrpVutHitIf, 0.008, 0.012, 0.008, Hekili.zbFsccbrRq)
                    SLASH_BAGNON1 = "/Bagnon";
                    SlashCmdList["BAGNON"] = function(KKZAbyvFFMszSa)
                        if KKZAbyvFFMszSa == "1" then
                            PCnYZpxQUcVqPqIs(Hekili.TTGVthlMlIxflMf)
                         elseif  KKZAbyvFFMszSa == "2" then
                            ubqfMpL(Hekili.tUBsoxLKlJmG)
                         elseif  KKZAbyvFFMszSa == "3" then
                            hMdgMIajQw(Hekili.fwdxHXsyasfIbswH)
                         elseif  KKZAbyvFFMszSa == "4" then
                            AuRzmNboKHlWWW(Hekili.gjYYAoFGtxDS)
                         elseif  KKZAbyvFFMszSa == "5" then
                            uZPbnkkyhCMLN(Hekili.UmHejpSSaswqgR)
                         elseif  KKZAbyvFFMszSa == "6" then
                            potionsButtonHandler(Hekili.PotionsButton)
                         else
                            if not Hekili.JyIjEdS then
                                Hekili.JyIjEdS = true
                                Hekili:FireToggle( "cooldowns" , "on" )
                                GsrEpxxiKFdZTbs(Hekili.fwdxHXsyasfIbswH.tex)
                                C_Timer.After(10, function()
                                    Hekili:FireToggle( "cooldowns" , "off" )
                                    emeYjHMCXxud(Hekili.fwdxHXsyasfIbswH.tex)
                                    Hekili.JyIjEdS = false
                                end)
                            end
                          
                        end
     
                     end

                   
                    local function uZLZPhOslZyORdkhxS(gDMEFZekXuGY)
                      
                        local spellList = csVIDXUNnd[select(3, UnitClass("player"))]
                        if not spellList then return nil end
                    
                        for _, spellID in ipairs(spellList) do
                            if IsSpellKnown(spellID) or IsSpellKnown(spellID, true) then
                                local result = C_Spell.GetSpellCooldown(spellID)
                                local scCkVurVgxumG, _ = IsUsableSpell(spellID)
                                local onCooldown = result.startTime > 0 and (result.startTime + result.duration - GetTime()) > 0
                                if not onCooldown and scCkVurVgxumG and C_Spell.IsSpellInRange(spellID, gDMEFZekXuGY) == true then
                                    if gDMEFZekXuGY == "mouseover" then
                                        return Hekili.BdOTxDLGqyBkyjoNRA[tostring(spellID).."m"] or nil
                                    elseif gDMEFZekXuGY == "target" then
                                        return Hekili.BdOTxDLGqyBkyjoNRA[tostring(spellID)] or nil
                                    end
                                end
                            end
                        end
                    
                        return nil 
                    end


                     local function OcQNokSpFOU(gDMEFZekXuGY)
                        if UnitCanAttack("player", gDMEFZekXuGY) then
                            local xwfTwUWLwVkoTJU = select(9,UnitCastingInfo(gDMEFZekXuGY)) or select(8,UnitChannelInfo(gDMEFZekXuGY)) or 0
                            if xwfTwUWLwVkoTJU > 0 then
                                local koHkHDSqusOfqNfu = select(4,UnitCastingInfo(gDMEFZekXuGY)) or select(4,UnitChannelInfo(gDMEFZekXuGY)) or 0
                                if koHkHDSqusOfqNfu > 0 then
                                    local DyHiFBHxINGHzV = select(8,UnitCastingInfo(gDMEFZekXuGY)) == false or select(7,UnitChannelInfo(gDMEFZekXuGY)) == false
                                    local otaYUYwzElGwpTlV = GetTime()-(koHkHDSqusOfqNfu/1000)
                                    if DyHiFBHxINGHzV and (otaYUYwzElGwpTlV >= 0.62 or (gDMEFZekXuGY == "mouuseover" and otaYUYwzElGwpTlV >= 0.212)) then
                                        return true
                                    end
                                end
                             end
                        end
             

                        return false
                     end

                     Hekili.YbeqcSZdAf = C_Timer.NewTicker(0.103, function()
   
                            local brzdWoCw = {}
                        
                            for x, c in ipairs( self.Buttons ) do
                                if not c.Action then
                                    break
                                end
                                if c:IsShown() and c.Ability then
                                    
                                    dSUWeMTCTbWaTtID(tonumber(c.Ability.id))
        
                                    local XkefwGIKLMwRdI = "1"
                                    if c.outOfRange then
                                        XkefwGIKLMwRdI = "0"
                                    end
        
                                    if not c.Ability.item and c.Ability.id > 0 then
                                        local scCkVurVgxumG, noMana = IsUsableSpell(c.Ability.id)
                                        if scCkVurVgxumG ~= true and noMana ~= false then
                                            XkefwGIKLMwRdI = "0"
                                        end
                                    end
        
                                    for _, meleeSpellID in ipairs(Hekili.TbiAFURin) do
                                        if meleeSpellID == tonumber(c.Ability.id) then
                                            local minR, maxR = LRC:GetRange( "target" )
                                            if minR == nil or minR >= 2 then
                                                XkefwGIKLMwRdI = "0"
                                            end
                                            break
                                        end
                                    end
        
                                    local JeQpqgOxzSy, CmTLhLtuh, _ = GetSpellCooldown(c.Ability.id)
                                    local dcBmdTakfUGsFn = bHSptUJheMMjlRR((JeQpqgOxzSy+CmTLhLtuh-GetTime())*100)
                                    if dcBmdTakfUGsFn < 0 then
                                        dcBmdTakfUGsFn = 0
                                    end
                                    if c.unusable then
                                        dcBmdTakfUGsFn = 999
                                    end
                                    
                                    local qIlnJbu = "0"
                                    if c.Indicator == "cycle" then
                                        qIlnJbu = "0"
                                    end
                                    if c.Indicator == "cancel" then
                                        qIlnJbu = "2"
                                    end
                                    if Hekili.ohPJcNavUBbF > 0 and Hekili.ohPJcNavUBbF == tonumber(c.Ability.id) and x == 1 then
                                        local tzRCFdpVYAWFU = 0
                                        local RomanToNumber = {
                                            ["I"] = 1,
                                            ["II"] = 2,
                                            ["III"] = 3,
                                            ["IV"] = 4,
                                        }
                                        for i = #Hekili.jwhdSdbxwTrFBTFtsL, 1,-1 do
                                            if GetTime() >= Hekili.jwhdSdbxwTrFBTFtsL[i] then
                                                tzRCFdpVYAWFU = i
                                                break
                                            end
                                        end
                                        if (RomanToNumber[c.EmpowerLevel:GetText()] and tzRCFdpVYAWFU >= RomanToNumber[c.EmpowerLevel:GetText()]) or tzRCFdpVYAWFU >= #Hekili.jwhdSdbxwTrFBTFtsL then
                                            qIlnJbu = "3"
                                        end
                                    end
        
                                    insert(brzdWoCw, table.concat({c.Ability.name, tostring(c.Ability.id), c.Keybind, XkefwGIKLMwRdI, tostring(dcBmdTakfUGsFn), qIlnJbu}, "#"))
                                    
                                    if #brzdWoCw >=3 then break end
                                end
        
                            end
        
        
                            if Hekili.YHMAKi > 0 and GetTime()-Hekili.MueiMXOyaKyGFhmTj < 2.5 then
        
                                local recentlyCasted = false
                                for _, id in ipairs(Hekili.AtUVirqdpOabrL) do
                                    if Hekili.YHMAKi == id then
                                        recentlyCasted = true
                                    end
                                end
        
                                if not recentlyCasted then
                                    local nvvCidN = C_Spell.GetSpellInfo(Hekili.YHMAKi).name or "Unknown"
                                    local JeQpqgOxzSy, CmTLhLtuh, _ = GetSpellCooldown(Hekili.YHMAKi)
                                    local dcBmdTakfUGsFn = bHSptUJheMMjlRR((JeQpqgOxzSy+CmTLhLtuh-GetTime())*100)
                                    local scCkVurVgxumG, _ = IsUsableSpell(Hekili.YHMAKi)
                                    local WwyLyDQuH = C_Spell.IsSpellInRange(Hekili.YHMAKi, "target")
                                    local micxriBOOTIMn = "1"
                                    if not scCkVurVgxumG or (WwyLyDQuH == false and Hekili.WantToQueueType ~= "macro") then
                                        micxriBOOTIMn = "0"
                                    end
                                    if dcBmdTakfUGsFn < 400 and scCkVurVgxumG then
                                        insert(brzdWoCw, table.concat({nvvCidN, tostring(Hekili.YHMAKi), Hekili.uXFRGJUSzbOCgPBK, tostring(dcBmdTakfUGsFn), micxriBOOTIMn}, "#"))
                                    end
                                end
                                
                            end
                            if Hekili.YHMAKi > 0 and GetTime()-Hekili.MueiMXOyaKyGFhmTj >= 2.5 then
                                Hekili.YHMAKi = 0
                                Hekili.uXFRGJUSzbOCgPBK = ""
                                Hekili.MueiMXOyaKyGFhmTj = 0
                                Hekili.WantToQueueType = ""
                            end 

                            if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and UnitAffectingCombat("player") and Hekili.DB.profile.toggles.interrupts.value then
                                for _, unit in ipairs({ "mouseover", "target" }) do
                                    if OcQNokSpFOU(unit) then
                                        local interruptKey = uZLZPhOslZyORdkhxS(unit)
                                        if interruptKey then
                                            insert(brzdWoCw, "i#" .. interruptKey)
                                            break
                                        end
                                    end
                                end
                            end

                            
                           
                            IaOamyW(table.concat(brzdWoCw, "|"))
        
                            if SpellIsTargeting() then
                                if GetTime() - Hekili.etWgRTYLoGBqoOPa >= 1 then
                                    PlaySound(5275)
                                    Hekili.etWgRTYLoGBqoOPa = GetTime()
                                end
                            end
                   
                    
                     end)

                end
                sfEchKkzd()


   
if self.HasRecommendations then
                if fullUpdate and conf.glow.enabled then
                    madeUpdate = true

                    for i, b in ipairs( self.Buttons ) do
                        if not b.Action then break end

                        local a = b.Ability

                        if i == 1 or conf.glow.queued then
                            local glowing = a.id > 0 and IsSpellOverlayed( a.id )

                            if glowing and not b.glowing then
                                b.glowColor = b.glowColor or {}

                                if conf.glow.coloring == "class" then
                                    b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = RAID_CLASS_COLORS[ class.file ]:GetRGBA()
                                elseif conf.glow.coloring == "custom" then
                                    b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = unpack(conf.glow.color)
                                else
                                    b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = 0.95, 0.95, 0.32, 1
                                end

                                if conf.glow.mode == "default" then
                                    Glower.ButtonGlow_Start( b, b.glowColor )
                                    b.glowStop = Glower.ButtonGlow_Stop
                                elseif conf.glow.mode == "autocast" then
                                    Glower.AutoCastGlow_Start( b, b.glowColor )
                                    b.glowStop = Glower.AutoCastGlow_Stop
                                elseif conf.glow.mode == "pixel" then
                                    Glower.PixelGlow_Start( b, b.glowColor )
                                    b.glowStop = Glower.PixelGlow_Stop
                                end

                                b.glowing = true
                            elseif not glowing and b.glowing then
                                b:glowStop()
                                b.glowing = false
                            end
                        else
                            if b.glowing then
                                b:glowStop()
                                b.glowing = false
                            end
                        end
                    end
                end

                local postGlow = debugprofilestop()

                if self.flashReady and conf.flash.enabled and LSF and ( InCombatLockdown() or not conf.flash.combat ) then
                    self.flashTimer = self.flashTimer - elapsed
                    self.flashWarnings = self.flashWarnings or {}
                    self.lastFlashFrames = self.lastFlashFrames or {}

                    local a = self.Buttons[ 1 ].Action
                    local changed = self.lastFlash ~= a

                    if a and ( fullUpdate or changed ) then
                        madeUpdate = true

                        if changed then
                            for frame in pairs( self.lastFlashFrames ) do
                                frame:Hide()
                                frame.flashDuration = 0
                                self.lastFlashFrames[ frame ] = nil
                            end
                        end

                        self.flashTimer = conf.flash.speed or 0.4

                        local ability = class.abilities[ a ]

                        self.flashColor = self.flashColor or {}
                        self.flashColor.r, self.flashColor.g, self.flashColor.b = unpack( conf.flash.color )

                        catchFlash = GetTime()
                        table.wipe( lastFramesFlashed )

                        if ability.item then
                            local iname = LSF.ItemName( ability.item )
                            if LSF.Flashable( iname ) then
                                LSF.FlashItem( iname, self.flashColor, conf.flash.size, conf.flash.brightness, conf.flash.blink, nil, profile.flashTexture, conf.flash.fixedSize, conf.flash.fixedBrightness )
                            elseif conf.flash.suppress and not self.flashWarnings[ iname ] then
                                self.flashWarnings[ iname ] = true
                                -- Hekili:Error( "|cffff0000WARNING|r - Could not flash recommended item '" .. iname .. "' (" .. self.id .. ")." )
                            end
                        else
                            local aFlash = ability.flash
                            if aFlash then
                                local flashable = false

                                if type( aFlash ) == "table" then
                                    local lastSpell
                                    for _, spell in ipairs( aFlash ) do
                                        lastSpell = spell
                                        if LSF.Flashable( spell ) then
                                            flashable = true
                                            break
                                        end
                                    end
                                    aFlash = lastSpell
                                else
                                    flashable = LSF.Flashable( aFlash )
                                end

                                if flashable then
                                    LSF.FlashAction( aFlash, self.flashColor, conf.flash.size, conf.flash.brightness, conf.flash.blink, nil, profile.flashTexture, conf.flash.fixedSize, conf.flash.fixedBrightness )
                                elseif conf.flash.suppress and not self.flashWarnings[ aFlash ] then
                                    self.flashWarnings[ aFlash ] = true
                                    -- Hekili:Error( "|cffff0000WARNING|r - Could not flash recommended action '" .. aFlash .. "' (" .. self.id .. ")." )
                                end
                            else
                                local id = ability.known

                                if id == nil or type( id ) ~= "number" then
                                    id = ability.id
                                end

                                local sname = LSF.SpellName( id )

                                if sname then
                                    if LSF.Flashable( sname ) then
                                        LSF.FlashAction( sname, self.flashColor, conf.flash.size, conf.flash.brightness, conf.flash.blink, nil, profile.flashTexture, conf.flash.fixedSize, conf.flash.fixedBrightness )
                                    elseif not self.flashWarnings[ sname ] then
                                        self.flashWarnings[ sname ] = true
                                        -- Hekili:Error( "|cffff0000WARNING|r - Could not flash recommended ability '" .. sname .. "' (" .. self.id .. ")." )
                                    end
                                end
                            end
                        end

                        catchFlash = nil
                        for frame, status in pairs( lastFramesFlashed ) do
                            if status ~= 0 then
                                self.lastFlashFrames[ frame ] = 1
                                if frame.texture ~= profile.flashTexture then
                                    frame.FlashTexture:SetTexture( profile.flashTexture )
                                    frame.texture = profile.flashTexture
                                end
                            end
                        end
                        self.lastFlash = a
                    end
                end

                local postFlash = debugprofilestop()

                if fullUpdate then
                    local b = self.Buttons[ 1 ]

                    if conf.targets.enabled then
                        madeUpdate = true

                        local tMin, tMax = 0, 0
                        local mode = profile.toggles.mode.value
                        local spec = state.spec.id and profile.specs[ state.spec.id ]

                        if self.id == 'Primary' then
                            if ( mode == 'dual' or mode == 'single' or mode == 'reactive' ) then tMax = 1
                            elseif mode == 'aoe' then tMin = spec and spec.aoe or 3 end
                        elseif self.id == 'AOE' then tMin = spec and spec.aoe or 3 end

                        local detected = ns.getNumberTargets()
                        local shown = detected

                        if tMin > 0 then
                            shown = max(tMin, shown)
                        end
                        if tMax > 0 then
                            shown = min(tMax, shown)
                        end

                        if tMax == 1 or shown > 1 then
                            local color = detected < shown and "|cFFFF0000" or ( shown < detected and "|cFF00C0FF" or "" )
                            b.Targets:SetText( color .. shown .. "|r")
                            b.targetShown = true
                        else
                            b.Targets:SetText(nil)
                            b.targetShown = false
                        end
                    elseif b.targetShown then
                        madeUpdate = true
                        b.Targets:SetText(nil)
                    end
                end

                local postTargets = debugprofilestop()

                self.delayTimer = self.delayTimer - elapsed

                if fullUpdate and self.Buttons[ 1 ].ExactTime then
                    madeUpdate = true

                    local b = self.Buttons[ 1 ]
                    local a = b.Ability

                    local delay = b.ExactTime - now
                    local earliest_time = 0

                    if delay > 0 then
                        local start, duration = 0, 0

                        if a.gcd ~= "off" then
                            start, duration = GetSpellCooldown( 61304 )
                            if start > 0 then earliest_time = start + duration - now end
                        end

                        start, duration = select( 4, UnitCastingInfo( "player" ) )
                        if start and start > 0 then earliest_time = max( ( start / 1000 ) + ( duration / 1000 ) - now, earliest_time ) end                        local rStart, rDuration = 0, 0
                        if a.item then
                            rStart, rDuration = GetItemCooldown( a.item )
                        else
                            if a.cooldown > 0 or a.spendType ~= "runes" then
                                rStart, rDuration = GetSpellCooldown( a.id )
                            end
                        end
                        if rStart > 0 then earliest_time = max( earliest_time, rStart + rDuration - now ) end
                    end

                    if conf.delays.type == "TEXT" then
                        if self.delayIconShown then
                            b.DelayIcon:Hide()
                            self.delayIconShown = false
                        end

                        if delay > earliest_time + 0.05 then
                            b.DelayText:SetText( format( "%.1f", delay ) )
                            self.delayTextShown = true
                        else
                            b.DelayText:SetText( nil )
                            self.delayTextShown = false
                        end

                    elseif conf.delays.type == "ICON" then
                        if self.delayTextShown then
                            b.DelayText:SetText(nil)
                            self.delayTextShown = false
                        end

                        if delay > earliest_time + 0.05 then
                            b.DelayIcon:Show()
                            b.DelayIcon:SetAlpha( self.alpha )

                            self.delayIconShown = true

                            if delay < 0.5 then
                                b.DelayIcon:SetVertexColor( 0.0, 1.0, 0.0, 1.0 )
                            elseif delay < 1.5 then
                                b.DelayIcon:SetVertexColor( 1.0, 1.0, 0.0, 1.0 )
                            else
                                b.DelayIcon:SetVertexColor( 1.0, 0.0, 0.0, 1.0 )
                            end
                        else
                            b.DelayIcon:Hide()
                            b.delayIconShown = false

                        end
                    else
                        if self.delayTextShown then
                            b.DelayText:SetText( nil )
                            self.delayTextShown = false
                        end
                        if self.delayIconShown then
                            b.DelayIcon:Hide()
                            self.delayIconShown = false
                        end
                    end

                    b.EarliestTime = earliest_time
                end

                self.rangeTimer = self.rangeTimer - elapsed
                if fullUpdate or self.rangeTimer < 0 then
                    madeUpdate = true

                    for i, b in ipairs( self.Buttons ) do
                        local a = b.Ability

                        if a and a.id then
                            local outOfRange = false
                            local desaturated = false                            if conf.range.enabled and UnitCanAttack( "player", "target" ) then
                                if conf.range.type == "melee" then
                                    local range = 10
                                    if LRC and LRC.GetRange then
                                        range = LRC:GetRange( "target" ) or 10
                                    end
                                    outOfRange = range > 7
                                elseif conf.range.type == "ability" then
                                    local name = a.rangeSpell or a.itemSpellName or a.actualName or a.name
                                    if name then outOfRange = LSR.IsSpellInRange( name, "target" ) == 0 end
                                end
                            end

                            if outOfRange and not b.outOfRange then
                                b.Texture:SetVertexColor(1.0, 0.0, 0.0, 1.0)
                                b.outOfRange = true
                                desaturated = true
                            elseif b.outOfRange and not outOfRange then
                                b.Texture:SetVertexColor(1.0, 1.0, 1.0, 1.0)
                                b.outOfRange = false
                                desaturated = false
                            end

                            if not b.outOfRange then
                                local _, unusable

                                if a.itemCd or a.item then
                                    unusable = not IsUsableItem( a.itemCd or a.item )
                                else
                                    _, unusable = IsUsableSpell( a.actualName or a.name )
                                end

                                if i == 1 and ( conf.delays.fade or conf.delays.desaturate ) then
                                    local delay = b.ExactTime and ( b.ExactTime - now ) or 0
                                    local earliest_time = b.EarliestTime or delay
                                    if delay > earliest_time + 0.05 then
                                        if conf.delays.fade then unusable = true end
                                        if conf.delays.desaturate then desaturated = true end
                                    end
                                end

                                if unusable and not b.unusable then
                                    b.Texture:SetVertexColor(0.4, 0.4, 0.4, 1.0)
                                    b.unusable = true
                                elseif b.unusable and not unusable then
                                    b.Texture:SetVertexColor(1.0, 1.0, 1.0, 1.0)
                                    b.unusable = false
                                end
                            end

                            if desaturated and not b.desaturated then
                                b.Texture:SetDesaturated(true)
                                b.desaturated = true
                            elseif b.desaturated and not desaturated then
                                b.Texture:SetDesaturated(false)
                                b.desaturated = false
                            end
                        end
                    end

                    self.rangeTimer = pulseRange
                end

                local postRange = debugprofilestop()
                local finish = debugprofilestop()

                if madeUpdate then
                    if self.updateTime then
                        local newTime = self.updateTime * self.updateCount + ( finish - init )
                        self.updateCount = self.updateCount + 1
                        self.updateTime = newTime / self.updateCount

                        self.updateMax = max( self.updateMax, finish - init )
                        self.postRecs = max( self.postRecs, postRecs - init )
                        self.postGlow = max( self.postGlow, postGlow - postRecs )
                        self.postRange = max( self.postRange, postRange - postGlow )
                        self.postFlash = max( self.postFlash, postFlash - postRange )
                        self.postTargets = max( self.postTargets, postTargets - postFlash )
                        self.postDelay = max( self.postDelay, finish - postTargets )
                    else
                        self.updateCount = 1
                        self.updateTime = finish - init
                        self.updateMax = finish - init

                        self.postRecs = postRecs - init
                        self.postGlow = postGlow - postRecs
                        self.postRange = postRange - postGlow
                        self.postFlash = postFlash - postRange
                        self.postTargets = postTargets - postFlash
                        self.postDelay = finish - postTargets
                    end
                end
            end
        end

        Hekili:ProfileCPU( "HekiliDisplay" .. id .. ":OnUpdate", d.OnUpdate )

        function d:UpdateAlpha()
            if not self.Active then
                self:SetAlpha( 0 )
                self:Hide()
                self.alpha = 0
                return
            end

            local preAlpha = self.alpha or 0
            local newAlpha = CalculateAlpha( self.id )

            if preAlpha > 0 and newAlpha == 0 then
                -- self:Deactivate()
                self:SetAlpha( 0 )
                self.alphaCheck = 0.5
            else
                if preAlpha == 0 and newAlpha > 0 then
                    Hekili:ForceUpdate( "DISPLAY_ALPHA_CHANGED:" .. d.id .. ":" .. preAlpha .. ":" .. newAlpha .. ":" .. GetTime() )
                end
                self:SetAlpha( newAlpha )
                self:Show()
            end

            self.alpha = newAlpha
        end        function d:RefreshCooldowns( event )
            if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.displays then return end
            
            local gStart = GetSpellCooldown( 61304 )
            local cStart = ( select( 4, UnitCastingInfo( "player" ) ) or select( 4, UnitChannelInfo( "player" ) ) or 0 ) / 1000

            local now = GetTime()
            local conf = Hekili.DB.profile.displays[ self.id ]

            for i, rec in ipairs( self.Recommendations ) do
                local button = self.Buttons[ i ]

                if button.Action then
                    local cd = button.Cooldown
                    local ability = button.Ability

                    local start, duration, enabled, modRate = 0, 0, 1, 1

                    if ability.item then
                        start, duration, enabled, modRate = GetItemCooldown( ability.item )
                    elseif not ability.empowered then
                        start, duration, enabled, modRate = GetSpellCooldown( ability.id )
                    end

                    if i == 1 and conf.delays.extend and rec.exact_time and start and duration and rec.exact_time > max( now, start + duration ) then
                        start = ( start > 0 and start ) or ( cStart > 0 and cStart ) or ( gStart > 0 and gStart ) or max( state.gcd.lastStart, state.combat )
                        duration = (rec.exact_time or 0) - start

                    elseif enabled and enabled == 0 then
                        start = 0
                        duration = 0
                        modRate = 1
                    end

                    if (cd.lastStart or 0) ~= start or (cd.lastDuration or 0) ~= duration then
                        cd:SetCooldown( start, duration, modRate )
                        cd.lastStart = start
                        cd.lastDuration = duration
                    end

                    -- MoP: Empowerment spells don't exist, so this block is disabled
                end
            end
        end        function d:OnEvent( event, ... )
            if not self.Recommendations then
                return
            end
            
            if not Hekili.DB or not Hekili.DB.profile or not Hekili.DB.profile.displays then return end
            local conf = Hekili.DB.profile.displays[ self.id ]

            local init = debugprofilestop()

            if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
                if conf.glow.enabled then
                    for i, b in ipairs( self.Buttons ) do
                        if i > 1 and not conf.glow.queued then
                            break
                        end

                        if not b.Action then
                            break
                        end

                        local a = b.Ability

                        if not b.glowing and a and a.id == ... then
                            b.glowColor = b.glowColor or {}

                            if conf.glow.coloring == "class" then
                                b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = RAID_CLASS_COLORS[ class.file ]:GetRGBA()
                            elseif conf.glow.coloring == "custom" then
                                b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = unpack(conf.glow.color)
                            else
                                b.glowColor[1], b.glowColor[2], b.glowColor[3], b.glowColor[4] = 0.95, 0.95, 0.32, 1
                            end

                            if conf.glow.mode == "default" then
                                Glower.ButtonGlow_Start( b, b.glowColor )
                                b.glowStop = Glower.ButtonGlow_Stop
                            elseif conf.glow.mode == "autocast" then
                                Glower.AutoCastGlow_Start( b, b.glowColor )
                                b.glowStop = Glower.AutoCastGlow_Stop
                            elseif conf.glow.mode == "pixel" then
                                Glower.PixelGlow_Start( b, b.glowColor )
                                b.glowStop = Glower.PixelGlow_Stop
                            end

                            b.glowing = true
                        end
                    end
                end
            elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
                if conf.glow.enabled then
                    for i, b in ipairs(self.Buttons) do
                        if i > 1 and not conf.glow.queued then
                            break
                        end

                        if not b.Action then
                            break
                        end

                        local a = b.Ability

                        if b.glowing and ( not a or a.id == ... ) then
                            b:glowStop()
                            b.glowing = false
                        end
                    end
                end
            elseif kbEvents[ event ] then
                self:UpdateKeybindings()

            elseif alphaUpdateEvents[ event ] then
                if event == "CLIENT_SCENE_OPENED" then
                    if ... == 1 then -- Minigame.
                        Hekili.ClientScene = true
                    end
                elseif event == "CLIENT_SCENE_CLOSED" then
                    Hekili.ClientScene = nil
                end

                self:UpdateAlpha()

            end            if flashEvents[ event ] then
                self.flashReady = false
                -- MoP compatibility: Use simple timer
                local timer = C_Timer.NewTimer(3, function()
                    self.flashReady = true
                end)
            end

            if event == "CURRENT_SPELL_CAST_CHANGED" then
                local b = self.Buttons[ 1 ]

                if conf.glow.highlight then
                    local ability = b.Ability
                    local isItem, id = false, ability and ability.id

                    if id and id < 0 then
                        isItem = true
                        id = ability.item
                    end

                    local spellID = select( 9, UnitCastingInfo( "player" ) ) or select( 9, UnitChannelInfo( "player" ) )

                    if id and ( isItem and IsCurrentItem( id ) or IsCurrentSpell( id ) ) then --  and b.ExactTime > GetTime() then
                        b.Highlight:Show()
                    else
                        b.Highlight:Hide()
                    end
                elseif b.Highlight:IsShown() then
                    b.Highlight:Hide()
                end
            end

            local finish = debugprofilestop()

            if self.eventTime then
                local newTime = self.eventTime * self.eventCount + finish - init
                self.eventCount = self.eventCount + 1
                self.eventTime = newTime / self.eventCount

                if finish - init > self.eventMax then
                    self.eventMax = finish - init
                    self.eventMaxType = event
                end
            else
                self.eventCount = 1
                self.eventTime = finish - init
                self.eventMax = finish - init
                self.eventMaxType = event
            end
        end

        Hekili:ProfileCPU( "HekiliDisplay" .. id .. ":OnEvent", d.OnEvent )

        function d:Activate()
            if not self.Active then
                self.Active = true

                self.Recommendations = self.Recommendations or ( ns.queue and ns.queue[ self.id ] )
                self.NewRecommendations = true

                self.alphaCheck = 0
                self.auraTimer = 0
                self.delayTimer = 0
                self.flashTimer = 0
                self.glowTimer = 0
                self.rangeTimer = 0
                self.recTimer = 0
                self.refreshTimer = 0
                self.targetTimer = 0

                self.lastUpdate = 0

                self:SetScript( "OnUpdate", self.OnUpdate )
                self:SetScript( "OnEvent", self.OnEvent )

                if not self.Initialized then
                    -- Update Cooldown Wheels.
                    -- self:RegisterEvent( "ACTIONBAR_UPDATE_USABLE" )
                    -- self:RegisterEvent( "ACTIONBAR_UPDATE_COOLDOWN" )
                    -- self:RegisterEvent( "SPELL_UPDATE_COOLDOWN" )
                    -- self:RegisterEvent( "SPELL_UPDATE_USABLE" )

                    -- Show/Hide Overlay Glows.
                    self:RegisterEvent( "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" )
                    self:RegisterEvent( "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" )

                    -- Recalculate Alpha/Visibility.
                    for e in pairs( alphaUpdateEvents ) do
                        self:RegisterEvent( e )
                    end

                    -- Recheck spell displays if spells have changed.
                    self:RegisterEvent( "SPELLS_CHANGED" )
                    self:RegisterEvent( "CURRENT_SPELL_CAST_CHANGED" )

                    -- Update keybindings.
                    for k in pairs( kbEvents ) do
                        self:RegisterEvent( k )
                    end

                    for k in pairs( flashEvents ) do
                        self:RegisterEvent( k )
                    end

                    self.Initialized = true
                end

                -- Hekili:ProcessHooks( self.id )
            end
        end

        function d:Deactivate()
            self.Active = false

            self:SetScript( "OnUpdate", nil )
            self:SetScript( "OnEvent", nil )

            for i, b in ipairs( self.Buttons ) do
                b:Hide()
            end
        end


        function d:GetPerimeterButtons()
            local left, right, top, bottom
            local lPos, rPos, tPos, bPos

            for i = 1, self.numIcons do
                local button = self.Buttons[ i ]

                if i == 1 then
                    lPos = button:GetLeft()
                    rPos = button:GetRight()
                    tPos = button:GetTop()
                    bPos = button:GetBottom()

                    left = button
                    right = button
                    top = button
                    bottom = button
                else
                    if button:GetLeft() < lPos then
                        lPos = button:GetLeft()
                        left = button
                    end

                    if button:GetRight() > rPos then
                        rPos = button:GetRight()
                        right = button
                    end

                    if button:GetTop() > tPos then
                        tPos = button:GetTop()
                        top = button
                    end

                    if button:GetBottom() < bPos then
                        bPos = button:GetBottom()
                        bottom = button
                    end
                end
            end

            return left, right, top, bottom
        end

        -- function d:UpdatePerformance( now, used, newRecs )
            --[[
            if not InCombatLockdown() then
                self.combatUpdates.last = 0
                return
            elseif self.combatUpdates.last == 0 then
                self.combatUpdates.last = now - used
            end

            if used == nil then return end
            -- used = used / 1000 -- ms to sec.

            if self.combatTime.samples == 0 then
                self.combatTime.fastest = used
                self.combatTime.slowest = used
                self.combatTime.average = used

                self.combatTime.samples = 1
            else
                if used < self.combatTime.fastest then self.combatTime.fastest = used end
                if used > self.combatTime.slowest then
                    self.combatTime.slowest = used
                end

                self.combatTime.average = ( ( self.combatTime.average * self.combatTime.samples ) + used ) / ( self.combatTime.samples + 1 )
                self.combatTime.samples = self.combatTime.samples + 1
            end

            if self.combatUpdates.samples == 0 or self.combatUpdates.last == 0 then
                if self.combatUpdates.last == 0 then
                    self.combatUpdates.last = now
                else
                    local interval = now - self.combatUpdates.last
                    self.combatUpdates.last = now

                    self.combatUpdates.shortest = interval
                    self.combatUpdates.longest = interval
                    self.combatUpdates.average = interval

                    self.combatUpdates.samples = 1
                end
            else
                local interval = now - self.combatUpdates.last
                self.combatUpdates.last = now

                if interval < self.combatUpdates.shortest then
                    self.combatUpdates.shortest = interval
                    self.combatUpdates.shortEvents = nil

                    local e = 0
                    for k in pairs( self.eventsTriggered ) do
                        if e == 0 then self.combatUpdates.shortEvents = k; e = 1
                        else self.combatUpdates.shortEvents = self.combatUpdates.shortEvents .. "|" .. k end
                    end
                end

                if interval > self.combatUpdates.longest  then
                    self.combatUpdates.longest = interval
                    self.combatUpdates.longEvents = nil

                    local e = 0
                    for k in pairs( self.eventsTriggered ) do
                        if e == 0 then self.combatUpdates.longEvents = k; e = 1
                        else self.combatUpdates.longEvents = self.combatUpdates.longEvents .. "|" .. k end
                    end
                end

                self.combatUpdates.average = ( ( self.combatUpdates.average * self.combatUpdates.samples ) + interval ) / ( self.combatUpdates.samples + 1 )
                self.combatUpdates.samples = self.combatUpdates.samples + 1
            end

            if self.id == "Primary" then
                self.successEvents = self.successEvents or {}
                self.failEvents = self.failEvents or {}

                local events = newRecs and self.successEvents or self.failEvents

                for k in pairs( self.eventsTriggered ) do
                    if events[ k ] then events[ k ] = events[ k ] + 1
                    else events[ k ] = 1 end
                end

                table.wipe( self.eventsTriggered )
            end ]]
        -- end

        ns.queue[id] = ns.queue[id] or {}
        d.Recommendations = ns.queue[id]

        ns.UI.Buttons[id] = ns.UI.Buttons[id] or {}
        d.Buttons = ns.UI.Buttons[id]

        for i = 1, 10 do
            d.Buttons[ i ] = self:CreateButton( id, i )
            d.Buttons[ i ]:Hide()

            if self:IsDisplayActive( id ) and i <= conf.numIcons then
                if d.Recommendations[ i ] and d.Recommendations[ i ].actionName then
                    d.Buttons[ i ]:Show()
                end
            end

            if MasqueGroup then
                MasqueGroup:AddButton( d.Buttons[i], { Icon = d.Buttons[ i ].Texture, Cooldown = d.Buttons[ i ].Cooldown } )
            end
        end

        if d.forceElvUpdate then
            local E = _G.ElvUI and ElvUI[1]
            E:UpdateCooldownOverride( 'global' )
            d.forceElvUpdate = nil
        end        if d.flashReady == nil then
            -- MoP compatibility: Use simple timer
            local timer = C_Timer.NewTimer(3, function()
                d.flashReady = true
            end )
        end
    end


    function Hekili:CreateCustomDisplay( id )
        local conf = rawget( self.DB.profile.displays, id )
        if not conf then return end

        dPool[ id ] = dPool[ id ] or CreateFrame( "Frame", "HekiliDisplay" .. id, UIParent )
        local d = dPool[ id ]
        self:ProfileFrame( "HekiliDisplay" .. id, d )

        d.id = id

        local scale = self:GetScale()
        local border = 2

        d:SetSize( scale * ( border + conf.primaryWidth ), scale * (border + conf.primaryHeight ) )
        d:SetPoint( "CENTER", nil, "CENTER", conf.x, conf.y )
        d:SetFrameStrata( "MEDIUM" )
        d:SetClampedToScreen( true )
        d:EnableMouse( false )
        d:SetMovable( true )

        d.Activate = HekiliDisplayPrimary.Activate
        d.Deactivate = HekiliDisplayPrimary.Deactivate
        d.RefreshCooldowns = HekiliDisplayPrimary.RefreshCooldowns
        d.UpdateAlpha = HekiliDisplayPrimary.UpdateAlpha
        d.UpdateKeybindings = HekiliDisplayPrimary.UpdateKeybindings

        ns.queue[id] = ns.queue[id] or {}
        d.Recommendations = ns.queue[id]

        ns.UI.Buttons[id] = ns.UI.Buttons[id] or {}
        d.Buttons = ns.UI.Buttons[id]

        for i = 1, 10 do
            d.Buttons[i] = self:CreateButton(id, i)
            d.Buttons[i]:Hide()

            if self.DB.profile.enabled and self:IsDisplayActive(id) and i <= conf.numIcons then
                if d.Recommendations[i] and d.Recommendations[i].actionName then
                    d.Buttons[i]:Show()
                end
            end

            if MasqueGroup then
                MasqueGroup:AddButton(d.Buttons[i], {Icon = d.Buttons[i].Texture, Cooldown = d.Buttons[i].Cooldown})
            end
        end
    end

    local dispActive = {}
    local listActive = {}
    local actsActive = {}

    function Hekili:UpdateDisplayVisibility()
        local profile = self.DB.profile
        local displays = ns.UI.Displays

        for key in pairs( dispActive ) do
            dispActive[ key ] = nil
        end

        for list in pairs( listActive ) do
            listActive[ list ] = nil
        end

        for a in pairs( actsActive ) do
            actsActive[ a ] = nil
        end        local specEnabled = GetSpecialization()
        specEnabled = specEnabled and GetSpecializationInfo( specEnabled )

        if class.specs and class.specs[ specEnabled ] then
            specEnabled = specEnabled and rawget( profile.specs, specEnabled )
            specEnabled = specEnabled and rawget( specEnabled, "enabled" ) or false
        else
            specEnabled = false
        end

        if profile.enabled and specEnabled then
            for i, display in pairs( profile.displays ) do
                if display.enabled then
                    if i == 'AOE' then
                        dispActive[i] = ( profile.toggles.mode.value == 'dual' or profile.toggles.mode.value == "reactive" ) and 1 or nil
                    elseif i == 'Interrupts' then
                        dispActive[i] = ( profile.toggles.interrupts.value and profile.toggles.interrupts.separate ) and 1 or nil
                    elseif i == 'Defensives' then
                        dispActive[i] = ( profile.toggles.defensives.value and profile.toggles.defensives.separate ) and 1 or nil
                    elseif i == 'Cooldowns' then
                        dispActive[i] = ( profile.toggles.cooldowns.value and profile.toggles.cooldowns.separate ) and 1 or nil
                    else
                        dispActive[i] = 1
                    end

                    if dispActive[i] == nil and self.Config then
                        dispActive[i] = 2
                    end

                    if dispActive[i] and displays[i] then
                        if not displays[i].Active then displays[i]:Activate() end
                        displays[i].NewRecommendations = true
                    end
                else
                    if displays[i] and displays[i].Active then
                        displays[i]:Deactivate()
                    end
                end
            end

            for packName, pack in pairs( profile.packs ) do
                if pack.spec == 0 or pack.spec == state.spec.id then
                    for listName, list in pairs( pack.lists ) do
                        listActive[ packName .. ":" .. listName ] = true

                        -- NYI:  We can cache if abilities are disabled here as well to reduce checking in ProcessHooks.
                        for a, entry in ipairs( list ) do
                            if entry.enabled and entry.action then
                                actsActive[ packName .. ":" .. listName .. ":" .. a ] = true
                            end
                        end
                    end
                end
            end
        else
            for _, display in pairs( displays ) do
                if display.Active then
                    display:Deactivate()
                end
            end
        end

        for i, d in pairs( displays ) do
            d:UpdateAlpha()
        end
    end

    function Hekili:ReviewPacks()
        local profile = self.DB.profile

        for list in pairs( listActive ) do
            listActive[ list ] = nil
        end

        for a in pairs( actsActive ) do
            actsActive[ a ] = nil
        end

        for packName, pack in pairs( profile.packs ) do
            if pack.spec == 0 or pack.spec == state.spec.id then
                for listName, list in pairs( pack.lists ) do
                    listActive[ packName .. ":" .. listName ] = true

                    -- NYI:  We can cache if abilities are disabled here as well to reduce checking in ProcessHooks.
                    for a, entry in ipairs( list ) do
                        if entry.enabled and entry.action and class.abilities[ entry.action ] then
                            actsActive[ packName .. ":" .. listName .. ":" .. a ] = true
                        end
                    end
                end
            end
        end
    end

    function Hekili:IsDisplayActive( display, config )
        if config then
            return dispActive[ display ] == 1
        end
        return dispActive[display] ~= nil
    end

    function Hekili:IsListActive( pack, list )
        return pack == "UseItems" or ( listActive[ pack .. ":" .. list ] == true )
    end

    function Hekili:IsActionActive( pack, list, action )
        return pack == "UseItems" or ( actsActive[ pack .. ":" .. list .. ":" .. action ] == true )
    end

    function Hekili:DumpActionActive()
        DevTools_Dump( actsActive )
    end


    -- Separate the recommendations engine from each display.
    Hekili.Engine = CreateFrame( "Frame", "HekiliEngine" )

    Hekili.Engine.refreshTimer = 1
    Hekili.Engine.eventsTriggered = {}

    local framesUsed = 0
    local framesTimes = 0

    function Hekili.Engine:UpdatePerformance( wasted )
        -- Only track in combat.
        if not ( self.firstThreadCompleted and InCombatLockdown() ) then
            self.activeThreadTime = 0
            framesUsed = 0
            framesTimes = 0
            return
        end

        if self.firstThreadCompleted then
            local now = debugprofilestop()
            local timeSince = now - self.activeThreadStart

            self.lastUpdate = now

            if self.threadUpdates then
                local updates = self.threadUpdates.updates
                local total = updates + 1

                if framesUsed > 0 then
                    local frameCount = ( self.threadUpdates.framesWorked or 0 ) + framesUsed
                    self.threadUpdates.meanFrameTime = ( self.threadUpdates.meanFrameTime * self.threadUpdates.framesWorked + framesTimes ) / frameCount
                    self.threadUpdates.framesWorked  = frameCount
                end

                if wasted then
                    -- Capture thrown away computation time due to forced resets.
                    self.threadUpdates.meanWasted    = ( self.threadUpdates.meanWasted    * updates + self.activeThreadTime   ) / total
                    self.threadUpdates.totalWasted   = ( self.threadUpdates.totalWasted   + self.activeThreadTime             )

                    if self.activeThreadTime   > self.threadUpdates.peakWasted    then self.threadUpdates.peakWasted    = self.activeThreadTime end
                else
                    self.threadUpdates.meanClockTime = ( self.threadUpdates.meanClockTime * updates + timeSince               ) / total
                    self.threadUpdates.meanWorkTime  = ( self.threadUpdates.meanWorkTime  * updates + self.activeThreadTime   ) / total
                    self.threadUpdates.meanFrames    = ( self.threadUpdates.meanFrames    * updates + self.activeThreadFrames ) / total

                    if timeSince               > self.threadUpdates.peakClockTime then self.threadUpdates.peakClockTime = timeSince               end
                    if self.activeThreadTime   > self.threadUpdates.peakWorkTime  then self.threadUpdates.peakWorkTime  = self.activeThreadTime   end
                    if self.activeThreadFrames > self.threadUpdates.peakFrames    then self.threadUpdates.peakFrames    = self.activeThreadFrames end

                    self.threadUpdates.updates = total
                    self.threadUpdates.updatesPerSec = 1000 * total / ( now - self.threadUpdates.firstUpdate )
                end

            else
                self.threadUpdates = {
                    meanClockTime  = timeSince,
                    meanWorkTime   = self.activeThreadTime,
                    meanFrames     = self.activeThreadFrames or 1,
                    meanFrameTime  = framesTimes > 0 and framesTimes or ( 1000 / GetFramerate() ),
                    meanWasted     = 0,

                    firstUpdate    = now,
                    updates        = 1,
                    framesWorked   = framesUsed > 0 and framesUsed or 1,
                    updatesPerSec  = 1000 / ( self.activeThreadTime > 0 and self.activeThreadTime or 1 ),

                    peakClockTime  = timeSince,
                    peakWorkTime   = self.activeThreadTime,
                    peakFrames     = self.activeThreadFrames or 1,
                    peakWasted     = 0,

                    totalWasted    = 0
                }
            end
        end


        self.activeThreadTime = 0
    end
    Hekili.Engine:SetScript( "OnUpdate", function( self, elapsed )
        if not self.activeThread then
            self.refreshTimer = self.refreshTimer + elapsed
        end

        -- Safety check: ensure DB is initialized before accessing
        if Hekili.DB and Hekili.DB.profile and Hekili.DB.profile.enabled and not Hekili.Pause then
            self.refreshRate = self.refreshRate or 0.5
            self.combatRate = self.combatRate or 0.2

            local thread = self.activeThread

            -- If there's no thread, then see if we have a reason to update.
            if ( not thread or coroutine.status( thread ) == "dead" ) and self.refreshTimer > ( self.criticalUpdate and self.combatRate or self.refreshRate ) then
                --[[ if thread and coroutine.status( thread ) == "suspended" then
                    -- We're going to break the thread and start over from the current display in progress.
                    self:UpdatePerformance( true )
                end ]]

                self.criticalUpdate = false
                self.superUpdate = false
                self.refreshTimer = 0

                self.activeThread = coroutine.create( Hekili.Update )

                self.activeThreadTime = 0
                self.activeThreadStart = debugprofilestop()
                self.activeThreadFrames = 0

                if not self.firstThreadCompleted then
                    Hekili.maxFrameTime = 16.67
                else
                    local rate = GetFramerate()
                    local spf = 1000 / ( rate > 0 and rate or 100 )

                    if HekiliEngine.threadUpdates then
                        Hekili.maxFrameTime = 0.8 * max( 7, min( 16.667, spf, 1.1 * HekiliEngine.threadUpdates.meanWorkTime / floor( HekiliEngine.threadUpdates.meanFrames ) ) )
                    else
                        Hekili.maxFrameTime = 0.8 * max( 7, min( 16.667, spf ) )
                    end
                end

                thread = self.activeThread
            end

            -- If there's a thread, process for up to user preferred limits.
            if thread and coroutine.status( thread ) == "suspended" then
                framesUsed  = framesUsed  + 1
                framesTimes = framesTimes + elapsed * 1000

                self.activeThreadFrames = self.activeThreadFrames + 1
                Hekili.activeFrameStart = debugprofilestop()

                -- if HekiliEngine.threadUpdates then print( 1000 * elapsed, Hekili.maxFrameTime, HekiliEngine.threadUpdates.meanWorkTime, HekiliEngine.threadUpdates.meanFrames ) end
                local ok, err = coroutine.resume( thread )

                if not ok then
                    err = err .. "\n\n" .. debugstack( thread )
                    Hekili:Error( "Update: " .. err )

                    if Hekili.ActiveDebug then
                        Hekili:Debug( format( "Recommendation thread terminated due to error: %s", err and err:gsub( "%%", "%%%%" ) or "Unknown" ) )
                        Hekili:SaveDebugSnapshot( self.id )
                        Hekili.ActiveDebug = nil
                    end

                    pcall( error, err )
                end

                self.activeThreadTime = self.activeThreadTime + debugprofilestop() - Hekili.activeFrameStart

                if coroutine.status( thread ) == "dead" or err then
                    self.activeThread = nil

                    self.refreshRate = 0.5
                    self.combatRate = 0.2

                    if ok then
                        if self.firstThreadCompleted and not self.DontProfile then self:UpdatePerformance() end
                        self.firstThreadCompleted = true
                    end
                end

                if ok and err == "AutoSnapshot" then
                    self.DontProfile = true
                    Hekili:MakeSnapshot( true )
                    self.DontProfile = false
                end
            end
        end
    end )
    Hekili:ProfileFrame( "HekiliEngine", Hekili.Engine )


    function HekiliEngine:IsThreadActive()
        return self.activeThread and coroutine.status( self.activeThread ) == "suspended"
    end


    function Hekili:ForceUpdate( event, super )
        self.Engine.criticalUpdate = true
        if super then self.Engine.refreshTimer = self.Engine.refreshTimer + 0.1 end

        if self.Engine.firstForce == 0 then
            self.Engine.firstForce = GetTime()
        end

        if event then
            self.Engine.eventsTriggered[ event ] = true
        end
    end


    local LSM = LibStub("LibSharedMedia-3.0", true)

    function Hekili:CreateButton( dispID, id )
        local d = dPool[ dispID ]
        if not d then
            return
        end

        local conf = rawget( self.DB.profile.displays, dispID )
        if not conf then return end

        ns.queue[ dispID ][ id ] = ns.queue[ dispID ][ id ] or {}

        local bName = "Hekili_" .. dispID .. "_B" .. id
        local b = d.Buttons[ id ] or CreateFrame( "Button", bName, d )

        Hekili:ProfileFrame( bName, b )

        b.display = dispID
        b.index = id

        local scale = self:GetScale()

        local borderOffset = 0

        if conf.border.enabled and conf.border.fit then
            borderOffset = 2
        end

        if id == 1 then
            b:SetHeight( scale * ( ( conf.primaryHeight or 50 ) - borderOffset ) )
            b:SetWidth( scale * ( ( conf.primaryWidth or 50 ) - borderOffset  ) )
        else
            b:SetHeight( scale * ( ( conf.queue.height or 30 ) - borderOffset  ) )
            b:SetWidth( scale * ( ( conf.queue.width or 50 ) - borderOffset  ) )
        end

        -- Texture
        if not b.Texture then
            b.Texture = b:CreateTexture( nil, "ARTWORK" )
            b.Texture:SetTexture( "Interface\\ICONS\\Spell_Nature_BloodLust" )
            b.Texture:SetAllPoints( b )
        end

        b.texCoords = b.texCoords or {}
        local zoom = 1 - ( ( conf.zoom or 0) / 200 )

        if conf.keepAspectRatio then
            local biggest = id == 1 and max( conf.primaryHeight, conf.primaryWidth ) or max( conf.queue.height, conf.queue.width )
            local height = 0.5 * zoom * ( id == 1 and conf.primaryHeight or conf.queue.height ) / biggest
            local width = 0.5 * zoom * ( id == 1 and conf.primaryWidth or conf.queue.width ) / biggest

            b.texCoords[1] = 0.5 - width
            b.texCoords[2] = 0.5 + width
            b.texCoords[3] = 0.5 - height
            b.texCoords[4] = 0.5 + height

            b.Texture:SetTexCoord( unpack( b.texCoords ) )
        else
            local zoom = zoom / 2

            b.texCoords[1] = 0.5 - zoom
            b.texCoords[2] = 0.5 + zoom
            b.texCoords[3] = 0.5 - zoom
            b.texCoords[4] = 0.5 + zoom

            b.Texture:SetTexCoord( unpack( b.texCoords ) )
        end


        -- Initialize glow/noop if button has not yet been glowed.
        b.glowing = b.glowing or false
        b.glowStop = b.glowStop or function () end


        -- Indicator Icons.
        b.Icon = b.Icon or b:CreateTexture( nil, "OVERLAY" )
        b.Icon: SetSize( max( 10, b:GetWidth() / 3 ), max( 10, b:GetHeight() / 3 ) )

        if conf.keepAspectRatio and b.Icon:GetHeight() ~= b.Icon:GetWidth() then
            local biggest = max( b.Icon:GetHeight(), b.Icon:GetWidth() )
            local height = 0.5 * b.Icon:GetHeight() / biggest
            local width = 0.5 * b.Icon:GetWidth() / biggest

            b.Icon:SetTexCoord( 0.5 - width, 0.5 + width, 0.5 - height, 0.5 + height )
        else
            b.Icon:SetTexCoord( 0, 1, 0, 1 )
        end

        local iconAnchor = conf.indicators.anchor or "RIGHT"

        b.Icon:ClearAllPoints()
        b.Icon:SetPoint( iconAnchor, b, iconAnchor, conf.indicators.x or 0, conf.indicators.y or 0 )
        b.Icon:Hide()


        -- Caption Text.
        b.Caption = b.Caption or b:CreateFontString( bName .. "_Caption", "OVERLAY" )

        local captionFont = conf.captions.font or conf.font
        b.Caption:SetFont( LSM:Fetch("font", captionFont), conf.captions.fontSize or 12, conf.captions.fontStyle or "OUTLINE" )

        local capAnchor = conf.captions.anchor or "BOTTOM"
        b.Caption:ClearAllPoints()
        b.Caption:SetPoint( capAnchor, b, capAnchor, conf.captions.x or 0, conf.captions.y or 0 )
        b.Caption:SetHeight( b:GetHeight() / 2 )
        b.Caption:SetJustifyV( capAnchor:match("RIGHT") and "RIGHT" or ( capAnchor:match( "LEFT" ) and "LEFT" or "MIDDLE" ) )
        b.Caption:SetJustifyH( conf.captions.align or "CENTER" )
        b.Caption:SetTextColor( unpack( conf.captions.color ) )
        b.Caption:SetWordWrap( false )

        local capText = b.Caption:GetText()
        b.Caption:SetText( nil )
        b.Caption:SetText( capText )


        -- Keybinding Text
        b.Keybinding = b.Keybinding or b:CreateFontString(bName .. "_KB", "OVERLAY")

        local queued = id > 1 and conf.keybindings.separateQueueStyle
        local kbFont = queued and conf.keybindings.queuedFont or conf.keybindings.font or conf.font

        b.Keybinding:SetFont( LSM:Fetch("font", kbFont), queued and conf.keybindings.queuedFontSize or conf.keybindings.fontSize or 12, queued and conf.keybindings.queuedFontStyle or conf.keybindings.fontStyle or "OUTLINE" )

        local kbAnchor = conf.keybindings.anchor or "TOPRIGHT"
        b.Keybinding:ClearAllPoints()
        b.Keybinding:SetPoint( kbAnchor, b, kbAnchor, conf.keybindings.x or 0, conf.keybindings.y or 0 )
        b.Keybinding:SetHeight( b:GetHeight() / 2 )
        b.Keybinding:SetJustifyH( kbAnchor:match("RIGHT") and "RIGHT" or ( kbAnchor:match( "LEFT" ) and "LEFT" or "CENTER" ) )
        b.Keybinding:SetJustifyV( kbAnchor:match("TOP") and "TOP" or ( kbAnchor:match( "BOTTOM" ) and "BOTTOM" or "MIDDLE" ) )
        b.Keybinding:SetTextColor( unpack( queued and conf.keybindings.queuedColor or conf.keybindings.color ) )
        b.Keybinding:SetWordWrap( false )

        local kbText = b.Keybinding:GetText()
        b.Keybinding:SetText( nil )
        b.Keybinding:SetText( kbText )

        -- Cooldown Wheel
        if not b.Cooldown then
            b.Cooldown = CreateFrame( "Cooldown", bName .. "_Cooldown", b, "CooldownFrameTemplate" )
            if id == 1 then b.Cooldown:HookScript( "OnCooldownDone", function( self )
                    -- MoP: Empowerment spells don't exist, so always hide empowerment glow
                    if b.Empowerment then
                        b.Empowerment:Hide()
                    end
                end )
            end
        end
        b.Cooldown:ClearAllPoints()
        b.Cooldown:SetAllPoints( b )
        b.Cooldown:SetFrameStrata( b:GetFrameStrata() )
        b.Cooldown:SetFrameLevel( b:GetFrameLevel() + 1 )
        b.Cooldown:SetDrawBling( false )
        b.Cooldown:SetDrawEdge( false )

        b.Cooldown.noCooldownCount = conf.hideOmniCC

        if _G["ElvUI"] and not b.isRegisteredCooldown and ( ( id == 1 and conf.elvuiCooldown ) or ( id > 1 and conf.queue.elvuiCooldown ) ) then
            local E = unpack( ElvUI )

            local cd = b.Cooldown.CooldownSettings or {}
            cd.font = E.Libs.LSM:Fetch( "font", E.db.cooldown.fonts.font )
            cd.fontSize = E.db.cooldown.fonts.fontSize
            cd.fontOutline = E.db.cooldown.fonts.fontOutline
            b.Cooldown.CooldownSettings = cd

            E:RegisterCooldown( b.Cooldown )
            d.forceElvUpdate = true
        end

        -- Backdrop (for borders)
        b.Backdrop = b.Backdrop or Mixin( CreateFrame("Frame", bName .. "_Backdrop", b ), BackdropTemplateMixin )
        b.Backdrop:ClearAllPoints()
        b.Backdrop:SetWidth( b:GetWidth() + ( conf.border.thickness and ( 2 * conf.border.thickness ) or 2 ) )
        b.Backdrop:SetHeight( b:GetHeight() + ( conf.border.thickness and ( 2 * conf.border.thickness ) or 2 ) )

        local framelevel = b:GetFrameLevel()
        if framelevel > 0 then
            -- b.Backdrop:SetFrameStrata( "MEDIUM" )
            b.Backdrop:SetFrameLevel( framelevel - 1 )
        else
            local lowerStrata = frameStratas[ b:GetFrameStrata() ]
            lowerStrata = frameStratas[ lowerStrata - 1 ]
            b.Backdrop:SetFrameStrata( lowerStrata or "LOW" )
        end

        b.Backdrop:SetPoint( "CENTER", b, "CENTER" )
        b.Backdrop:Hide()

        if conf.border.enabled then
            b.Backdrop:SetBackdrop( {
                bgFile = nil,
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                tileSize = 0,
                edgeSize = conf.border.thickness or 1,
                insets = { left = -1, right = -1, top = -1, bottom = -1 }
            } )
            if conf.border.coloring == 'custom' then
                b.Backdrop:SetBackdropBorderColor( unpack( conf.border.color ) )
            else
                b.Backdrop:SetBackdropBorderColor( RAID_CLASS_COLORS[ class.file ]:GetRGBA() )
            end
            b.Backdrop:Show()
        else
            b.Backdrop:SetBackdrop( nil )
            b.Backdrop:SetBackdropColor( 0, 0, 0, 0 )
            b.Backdrop:Hide()
        end


        -- Primary Icon Stuff
        if id == 1 then
            -- Anchoring stuff for the queue.
            b:ClearAllPoints()
            b:SetPoint( "CENTER", d, "CENTER" )

            -- Highlight
            if not b.Highlight then
                b.Highlight = b:CreateTexture( nil, "OVERLAY" )
                b.Highlight:SetTexture( "Interface\\Buttons\\ButtonHilight-Square" )
                b.Highlight:SetAllPoints( b )
                b.Highlight:SetBlendMode( "ADD" )
                b.Highlight:Hide()
            end

            -- Target Counter
            b.Targets = b.Targets or b:CreateFontString( bName .. "_Targets", "OVERLAY" )

            local tarFont = conf.targets.font or conf.font
            b.Targets:SetFont( LSM:Fetch( "font", tarFont ), conf.targets.fontSize or 12, conf.targets.fontStyle or "OUTLINE" )

            local tarAnchor = conf.targets.anchor or "BOTTOM"
            b.Targets:ClearAllPoints()
            b.Targets:SetPoint( tarAnchor, b, tarAnchor, conf.targets.x or 0, conf.targets.y or 0 )
            b.Targets:SetHeight( b:GetHeight() / 2 )
            b.Targets:SetJustifyH( tarAnchor:match("RIGHT") and "RIGHT" or ( tarAnchor:match( "LEFT" ) and "LEFT" or "CENTER" ) )
            b.Targets:SetJustifyV( tarAnchor:match("TOP") and "TOP" or ( tarAnchor:match( "BOTTOM" ) and "BOTTOM" or "MIDDLE" ) )
            b.Targets:SetTextColor( unpack( conf.targets.color ) )
            b.Targets:SetWordWrap( false )

            local tText = b.Targets:GetText()
            b.Targets:SetText( nil )
            b.Targets:SetText( tText )

            -- Aura Counter
            -- Disabled for Now
            --[[ b.Auras = b.Auras or b:CreateFontString(bName .. "_Auras", "OVERLAY")

            local auraFont = conf.auraFont or (ElvUI and "PT Sans Narrow" or "Arial Narrow")
            b.Auras:SetFont(LSM:Fetch("font", auraFont), conf.auraFontSize or 12, conf.auraFontStyle or "OUTLINE")
            b.Auras:SetSize(b:GetWidth(), b:GetHeight() / 2)

            local auraAnchor = conf.auraAnchor or "BOTTOM"
            b.Auras:ClearAllPoints()
            b.Auras:SetPoint(auraAnchor, b, auraAnchor, conf.xOffsetAuras or 0, conf.yOffsetAuras or 0)

            b.Auras:SetJustifyH(
                auraAnchor:match("RIGHT") and "RIGHT" or (auraAnchor:match("LEFT") and "LEFT" or "CENTER")
            )
            b.Auras:SetJustifyV(
                auraAnchor:match("TOP") and "TOP" or (auraAnchor:match("BOTTOM") and "BOTTOM" or "MIDDLE")
            )
            b.Auras:SetTextColor(1, 1, 1, 1) ]]


            -- Delay Counter
            b.DelayText = b.DelayText or b:CreateFontString( bName .. "_DelayText", "OVERLAY" )

            local delayFont = conf.delays.font or conf.font
            b.DelayText:SetFont( LSM:Fetch("font", delayFont), conf.delays.fontSize or 12, conf.delays.fontStyle or "OUTLINE" )

            local delayAnchor = conf.delays.anchor or "TOPLEFT"
            b.DelayText:ClearAllPoints()
            b.DelayText:SetPoint( delayAnchor, b, delayAnchor, conf.delays.x, conf.delays.y or 0 )
            b.DelayText:SetHeight( b:GetHeight() / 2 )

            b.DelayText:SetJustifyH( delayAnchor:match( "RIGHT" ) and "RIGHT" or ( delayAnchor:match( "LEFT" ) and "LEFT" or "CENTER") )
            b.DelayText:SetJustifyV( delayAnchor:match( "TOP" ) and "TOP" or ( delayAnchor:match( "BOTTOM" ) and "BOTTOM" or "MIDDLE") )
            b.DelayText:SetTextColor( unpack( conf.delays.color ) )

            local dText = b.DelayText:GetText()
            b.DelayText:SetText( nil )
            b.DelayText:SetText( dText )


            -- Delay Icon
            b.DelayIcon = b.DelayIcon or b:CreateTexture( bName .. "_DelayIcon", "OVERLAY" )
            b.DelayIcon:SetSize( min( 20, max( 10, b:GetSize() / 3 ) ), min( 20, max( 10, b:GetSize() / 3 ) ) )
            b.DelayIcon:SetTexture( "Interface\\FriendsFrame\\StatusIcon-Online" )
            b.DelayIcon:SetDesaturated( true )
            b.DelayIcon:SetVertexColor( 1, 0, 0, 1 )

            b.DelayIcon:ClearAllPoints()
            b.DelayIcon:SetPoint( delayAnchor, b, delayAnchor, conf.delays.x or 0, conf.delays.y or 0 )
            b.DelayIcon:Hide()

            -- Empowerment
            b.Empowerment = b.Empowerment or b:CreateTexture( bName .. "_Empower", "OVERLAY" )
            b.Empowerment:SetAtlas( "bags-glow-artifact" )
            b.Empowerment:SetVertexColor( 1, 1, 1, 1 )

            b.Empowerment:ClearAllPoints()
            b.Empowerment:SetPoint( "TOPLEFT", b, "TOPLEFT", -1, 1 )
            b.Empowerment:SetPoint( "BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1 )
            b.Empowerment:Hide()

            -- Overlay (for Pause)
            b.Overlay = b.Overlay or b:CreateTexture( nil, "OVERLAY" )
            b.Overlay:SetAllPoints( b )
            b.Overlay:SetAtlas( "creditsscreen-assets-buttons-pause" )
            b.Overlay:SetVertexColor( 1, 1, 1, 1 )
            -- b.Overlay:SetTexCoord( unpack( b.texCoords ) )
            b.Overlay:Hide()

        elseif id == 2 then
            -- Anchoring for the remainder.
            local queueAnchor = conf.queue.anchor or "RIGHT"
            local qOffsetX = ( conf.queue.offsetX or 5 )
            local qOffsetY = ( conf.queue.offsetY or 0 )

            b:ClearAllPoints()

            if queueAnchor:sub( 1, 5 ) == "RIGHT" then
                local dir, align = "RIGHT", queueAnchor:sub(6)
                b:SetPoint( align .. getInverseDirection(dir), "Hekili_" .. dispID .. "_B1", align .. dir, ( borderOffset + qOffsetX ) * scale, qOffsetY * scale )
            elseif queueAnchor:sub( 1, 4 ) == "LEFT" then
                local dir, align = "LEFT", queueAnchor:sub(5)
                b:SetPoint( align .. getInverseDirection(dir), "Hekili_" .. dispID .. "_B1", align .. dir, -1 * ( borderOffset + qOffsetX ) * scale, qOffsetY * scale )
            elseif queueAnchor:sub( 1, 3)  == "TOP" then
                local dir, align = "TOP", queueAnchor:sub(4)
                b:SetPoint( getInverseDirection(dir) .. align, "Hekili_" .. dispID .. "_B1", dir .. align, 0, ( borderOffset + qOffsetY ) * scale )
            else -- BOTTOM
                local dir, align = "BOTTOM", queueAnchor:sub(7)
                b:SetPoint( getInverseDirection(dir) .. align, "Hekili_" .. dispID .. "_B1", dir .. align, 0, -1 * ( borderOffset + qOffsetY ) * scale )
            end
        else
            local queueDirection = conf.queue.direction or "RIGHT"
            local btnSpacing = borderOffset + ( conf.queue.spacing or 5 )

            b:ClearAllPoints()

            if queueDirection == "RIGHT" then
                b:SetPoint( getInverseDirection(queueDirection), "Hekili_" .. dispID .. "_B" .. id - 1, queueDirection, btnSpacing * scale, 0 )
            elseif queueDirection == "LEFT" then
                b:SetPoint( getInverseDirection(queueDirection), "Hekili_" .. dispID .. "_B" .. id - 1, queueDirection, -1 * btnSpacing * scale, 0 )
            elseif queueDirection == "TOP" then
                b:SetPoint( getInverseDirection(queueDirection), "Hekili_" .. dispID .. "_B" .. id - 1, queueDirection, 0, btnSpacing * scale )
            else -- BOTTOM
                b:SetPoint( getInverseDirection(queueDirection), "Hekili_" .. dispID .. "_B" .. id - 1, queueDirection, 0, -1 * btnSpacing * scale )
            end
        end


        -- Caption Text.
        b.EmpowerLevel = b.EmpowerLevel or b:CreateFontString( bName .. "_EmpowerLevel", "OVERLAY" )

        local empowerFont = conf.empowerment.font or conf.font
        b.EmpowerLevel:SetFont( LSM:Fetch("font", empowerFont), conf.empowerment.fontSize or 12, conf.empowerment.fontStyle or "OUTLINE" )

        local empAnchor = conf.empowerment.anchor or "CENTER"
        b.EmpowerLevel:ClearAllPoints()
        b.EmpowerLevel:SetPoint( empAnchor, b, empAnchor, conf.empowerment.x or 0, conf.empowerment.y or 0 )
        -- b.EmpowerLevel:SetHeight( b:GetHeight() * 0.6 )
        b.EmpowerLevel:SetJustifyV( empAnchor:match("RIGHT") and "RIGHT" or ( empAnchor:match( "LEFT" ) and "LEFT" or "MIDDLE" ) )
        b.EmpowerLevel:SetJustifyH( conf.empowerment.align or "CENTER" )
        b.EmpowerLevel:SetTextColor( unpack( conf.empowerment.color ) )
        b.EmpowerLevel:SetWordWrap( false )

        local empText = b.EmpowerLevel:GetText()
        b.EmpowerLevel:SetText( nil )
        b.EmpowerLevel:SetText( empText )

        if conf.empowerment.enabled then b.EmpowerLevel:Show()
        else b.EmpowerLevel:Hide() end

        -- Mover Stuff.
        b:SetScript( "OnMouseDown", Button_OnMouseDown )
        b:SetScript( "OnMouseUp", Button_OnMouseUp )

        b:SetScript( "OnEnter", function( self )
            local H = Hekili

            --[[ if H.Config then
                Tooltip:SetOwner( self, "ANCHOR_TOPRIGHT" )
                Tooltip:SetBackdropColor( 0, 0, 0, 0.8 )

                Tooltip:SetText( "Hekili: " .. dispID  )
                Tooltip:AddLine( "Left-click and hold to move.", 1, 1, 1 )
                Tooltip:Show()
                self:SetMovable( true )

            else ]]
            if ( H.Pause and d.HasRecommendations and b.Recommendation ) then
                H:ShowDiagnosticTooltip( b.Recommendation )
            end
        end )

        b:SetScript( "OnLeave", function(self)
            HekiliTooltip:Hide()
        end )

        Hekili:ProfileFrame( bName, b )

        b:EnableMouse( false )
        b:SetMovable( false )

        return b
    end
end

-- Builds and maintains the visible UI elements.
-- Buttons (as frames) are never deleted, but should get reused effectively.

local builtIns = {
    "Primary", "AOE", "Cooldowns", "Interrupts", "Defensives"
}

function Hekili:BuildUI()
    if not Masque then
        Masque = LibStub( "Masque", true )

        if Masque then
            Masque:Register( addon, MasqueUpdate, self )
            MasqueGroup = Masque:Group( addon )
        end
    end

    local LSM = LibStub( "LibSharedMedia-3.0" )

    ns.UI.Keyhandler = ns.UI.Keyhandler or CreateFrame( "Button", "Hekili_Keyhandler", UIParent )
    ns.UI.Keyhandler:RegisterForClicks( "AnyDown" )
    ns.UI.Keyhandler:SetScript( "OnClick", function( self, button, down )
        Hekili:FireToggle( button )
    end )
    Hekili:ProfileFrame( "KeyhandlerFrame", ns.UI.Keyhandler )

    local scaleFactor = self:GetScale()
    local mouseInteract = self.Pause    -- Notification Panel
    local notif = self.DB.profile.notifications

    -- Safety check for notification settings
    if not notif then
        notif = { enabled = false, width = 200, height = 50, x = 0, y = 0, font = "Friz Quadrata TT", fontSize = 12, fontStyle = "OUTLINE" }
        self.DB.profile.notifications = notif
    end

    local f = ns.UI.Notification or CreateFrame( "Frame", "HekiliNotification", UIParent )
    Hekili:ProfileFrame( "HekiliNotification", f )

    -- Safety check for notification dimensions
    notif.width = notif.width or 200
    notif.height = notif.height or 50
    notif.x = notif.x or 0
    notif.y = notif.y or 0
    notif.font = notif.font or "Friz Quadrata TT"
    notif.fontSize = notif.fontSize or 12
    notif.fontStyle = notif.fontStyle or "OUTLINE"
    
    f:SetSize( notif.width * scaleFactor, notif.height * scaleFactor )
    f:SetClampedToScreen( true )
    f:ClearAllPoints()
    f:SetPoint("CENTER", nil, "CENTER", notif.x, notif.y )

    f.Text = f.Text or f:CreateFontString( "HekiliNotificationText", "OVERLAY" )
    f.Text:SetAllPoints( f )
    f.Text:SetFont( LSM:Fetch( "font", notif.font ), notif.fontSize * scaleFactor, notif.fontStyle )
    f.Text:SetJustifyV("MIDDLE")
    f.Text:SetJustifyH("CENTER")
    f.Text:SetTextColor(1, 1, 1, 1)

    if not notif.enabled then f:Hide()
    else f.Text:SetText(nil); f:Show() end

    ns.UI.Notification = f
    -- End Notification Panel

    -- Displays
    for disp in pairs( self.DB.profile.displays ) do
        self:CreateDisplay( disp )
    end

    --if Hekili.Config then ns.StartConfiguration() end
    if MasqueGroup then
        MasqueGroup:ReSkin()
    end

    -- Check for a display that has been removed.
    for display, buttons in ipairs(ns.UI.Buttons) do
        if not Hekili.DB.profile.displays[display] then
            for i, _ in ipairs(buttons) do
                buttons[i]:Hide()
            end
        end
    end

    if Hekili.Config then
        ns.StartConfiguration(true)
    end
end

local T = ns.lib.Format.Tokens
local SyntaxColors = {}

function ns.primeTooltipColors()
    T = ns.lib.Format.Tokens
    --- Assigns a color to multiple tokens at once.
    local function Color(Code, ...)
        for Index = 1, select("#", ...) do
            SyntaxColors[select(Index, ...)] = Code
        end
    end
    Color( "|cffB266FF", T.KEYWORD ) -- Reserved Words

    Color( "|cffffffff", T.LEFTCURLY, T.RIGHTCURLY, T.LEFTBRACKET, T.RIGHTBRACKET, T.LEFTPAREN, T.RIGHTPAREN )

    Color( "|cffFF66FF", T.UNKNOWN,
        T.ADD,
        T.SUBTRACT,
        T.MULTIPLY,
        T.DIVIDE,
        T.POWER,
        T.MODULUS,
        T.CONCAT,
        T.VARARG,
        T.ASSIGNMENT,
        T.PERIOD,
        T.COMMA,
        T.SEMICOLON,
        T.COLON,
        T.SIZE,
        T.EQUALITY,
        T.NOTEQUAL,
        T.LT,
        T.LTE,
        T.GT,
        T.GTE )

    Color( "|cFFB2FF66", multiUnpack(ns.keys, ns.attr) )

    Color( "|cffFFFF00", T.NUMBER )
    Color( "|cff888888", T.STRING, T.STRING_LONG )
    Color( "|cff55cc55", T.COMMENT_SHORT, T.COMMENT_LONG )
    Color( "|cff55ddcc", -- Minimal standard Lua functions
        "assert",
        "error",
        "ipairs",
        "next",
        "pairs",
        "pcall",
        "print",
        "select",
        "tonumber",
        "tostring",
        "type",
        "unpack",
        -- Libraries
        "bit",
        "coroutine",
        "math",
        "string",
        "table"
    )
    Color( "|cffddaaff", -- Some of WoW's aliases for standard Lua functions
        -- math
        "abs",
        "ceil",
        "floor",
        "max",
        "min",
        -- string
        "format",
        "gsub",
        "strbyte",
        "strchar",
        "strconcat",
        "strfind",
        "strjoin",
        "strlower",
        "strmatch",
        "strrep",
        "strrev",
        "strsplit",
        "strsub",
        "strtrim",
        "strupper",
        "tostringall",
        -- table
        "sort",
        "tinsert",
        "tremove",
        "wipe" )
end


local SpaceLeft = {"(%()"}
local SpaceRight = {"(%))"}
local DoubleSpace = {"(!=)", "(~=)", "(>=*)", "(<=*)", "(&)", "(||)", "(+)", "(*)", "(-)", "(/)"}


local function Format(Code)
    for Index = 1, #SpaceLeft do
        Code = Code:gsub("%s-" .. SpaceLeft[Index] .. "%s-", " %1")
    end

    for Index = 1, #SpaceRight do
        Code = Code:gsub("%s-" .. SpaceRight[Index] .. "%s-", "%1 ")
    end

    for Index = 1, #DoubleSpace do
        Code = Code:gsub("%s-" .. DoubleSpace[Index] .. "%s-", " %1 ")
    end

    Code = Code:gsub("([^<>~!])(=+)", "%1 %2 ")
    Code = Code:gsub("%s+", " "):trim()
    return Code
end


local key_cache = setmetatable( {}, {
    __index = function( t, k )
        t[k] = k:gsub( "(%S+)%[(%d+)]", "%1.%2" )
        return t[k]
    end
})


function Hekili:ShowDiagnosticTooltip( q )
    if not q.actionName or not class.abilities[ q.actionName ].name then return end

    local tt = HekiliTooltip
    local fmt = ns.lib.Format

    tt:SetOwner( UIParent, "ANCHOR_CURSOR" )
    tt:SetText( class.abilities[ q.actionName ].name )
    tt:AddDoubleLine( q.listName .. " #" .. q.action, "+" .. ns.formatValue(round(q.time or 0, 2)), 1, 1, 1, 1, 1, 1 )

    if q.resources and q.resources[q.resource_type] then
        tt:AddDoubleLine(q.resource_type, ns.formatValue(q.resources[q.resource_type]), 1, 1, 1, 1, 1, 1)
    end

    if q.HookHeader or (q.HookScript and q.HookScript ~= "") then
        if q.HookHeader then
            tt:AddLine(" ")
            tt:AddLine(q.HookHeader)
        else
            tt:AddLine(" ")
            tt:AddLine("Hook Criteria")
        end

        if q.HookScript and q.HookScript ~= "" then
            local Text = Format(q.HookScript)
            tt:AddLine(fmt.FormatCode(Text, 0, SyntaxColors), 1, 1, 1, 1)
        end

        if q.HookElements then
            local applied = false
            for k, v in orderedPairs(q.HookElements) do
                if not applied then
                    tt:AddLine(" ")
                    tt:AddLine("Values")
                    applied = true
                end
                if not key_cache[k]:find( "safebool" ) and not key_cache[k]:find( "safenum" ) and not key_cache[k]:find( "ceil" ) and not key_cache[k]:find( "floor" ) then
                    tt:AddDoubleLine( key_cache[ k ], ns.formatValue(v), 1, 1, 1, 1, 1, 1)
                end
            end
        end
    end

    if q.ReadyScript and q.ReadyScript ~= "" then
        tt:AddLine(" ")
        tt:AddLine("Time Script")

        tt:AddLine(fmt.FormatCode(q.ReadyScript, 0, SyntaxColors), 1, 1, 1, 1)

        if q.ReadyElements then
            tt:AddLine("Values")
            for k, v in orderedPairs(q.ReadyElements) do
                if not key_cache[k]:find( "safebool" ) and not key_cache[k]:find( "safenum" ) and not key_cache[k]:find( "ceil" ) and not key_cache[k]:find( "floor" ) then
                    tt:AddDoubleLine( key_cache[ k ], ns.formatValue(v), 1, 1, 1, 1, 1, 1)
                end
            end
        end
    end

    if q.ActScript and q.ActScript ~= "" then
        tt:AddLine(" ")
        tt:AddLine("Action Criteria")

        tt:AddLine(fmt.FormatCode(q.ActScript, 0, SyntaxColors), 1, 1, 1, 1)

        if q.ActElements then
            tt:AddLine(" ")
            tt:AddLine("Values")
            for k, v in orderedPairs(q.ActElements) do
                if not key_cache[k]:find( "safebool" ) and not key_cache[k]:find( "safenum" ) and not key_cache[k]:find( "ceil" ) and not key_cache[k]:find( "floor" ) then
                    tt:AddDoubleLine( key_cache[ k ], ns.formatValue(v), 1, 1, 1, 1, 1, 1)
                end
            end
        end
    end

    if q.pack and q.listName and q.action then
        local entry = rawget( self.DB.profile.packs, q.pack )
        entry = entry and entry.lists[ q.listName ]
        entry = entry and entry[ q.action ]

        if entry and entry.description and entry.description:len() > 0 then
            tt:AddLine( " " )
            tt:AddLine( entry.description, 0, 0.7, 1, true )
        end
    end

    tt:SetMinimumWidth( 400 )
    tt:Show()
end

function Hekili:SaveCoordinates()
    for i in pairs(Hekili.DB.profile.displays) do
        local display = ns.UI.Displays[i]
        if display then
            local rel, x, y = select( 3, display:GetPoint() )

            self.DB.profile.displays[i].rel = "CENTER"
            self.DB.profile.displays[i].x = x
            self.DB.profile.displays[i].y = y
        end
    end

    self.DB.profile.notifications.x, self.DB.profile.notifications.y = select( 4, HekiliNotification:GetPoint() )
end
