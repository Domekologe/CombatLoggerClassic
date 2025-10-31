CombatLoggerClassic = CombatLoggerClassic or
    LibStub("AceAddon-3.0"):NewAddon("CombatLoggerClassic", "AceConsole-3.0", "AceEvent-3.0")
	
local LSM = LibStub("LibSharedMedia-3.0")
LSM:Register("font", "Fitz", "Interface\\AddOns\\CombatLoggerClassic\\Media\\FrizQuadrataTT.ttf")
local fitzFont = LSM:Fetch("font", "Fitz")

local L = LibStub("AceLocale-3.0"):GetLocale("CombatLoggerClassic")

local RECHECK_DELAY_SEC = 0.5
CombatLoggerClassic._manualOverride = nil  -- "on", "off" or nil

--[[
    Initializing the addon using Ace3.
    It includes options, commands, saved variables and basic events to register to.
--]]

function CombatLoggerClassic:OnInitialize()
	-- Lade die SavedVariables
    self.db = LibStub("AceDB-3.0"):New("CombatLoggerClassicDB", {
		global = {
			framePosition = nil, -- Default value for the frame position
			showLog = true, -- Default value for showing the log
			frameMovable = false, -- Default value for frame movability
			--- CLASSIC ---
			[169] = true, -- Emerald Dream
			[249] = true, -- Onyxias Lair
			[409] = true, -- Molten Core
			[469] = true, -- Blackwing Lair
			[509] = true, -- Ruins of AhnQiraj
			[531] = true, -- AnQiraj Temple
			--- TBC ---
			[532] = true, -- Karazhan
			[534] = true, -- The Battle for Mount Hyjal
			[544] = true, -- Magtheridon's Lair
			[548] = true, -- Coilfang: Serpentshrine Cavern
			[550] = true, -- Tempest Keep
			[564] = true, -- Black Temple
			[565] = true, -- Gruul's Lair
			[580] = true, -- The Sunwell
			--- WOTLK ---
			[533] = true, -- Naxxramas
			[603] = true, -- Ulduar
			[615] = true, -- The Obsidian Sanctum
			[616] = true, -- The Eye of Eternity
			[624] = true, -- Vault of Archavon
			[631] = true, -- Icecrown Citadel
			[649] = true, -- Trial of the Crusader
			[724] = true, -- The Ruby Sanctum
			--- CATA ---
			[757] = true, -- Baradin Hold
			[669] = true, -- Blackwing Descent
			[671] = true, -- The Bastion of Twilight
			[754] = true, -- Throne of the Four Winds
			[720] = true, -- Firelands
			[967] = true, -- Dragon Soul
			--- PANDA ---
			[996] = true, -- Terrace of Endless Spring
			[1008] = true, -- Mogu'shan Vaults
			[1009] = true, -- Heart of Fear
			[1098] = true, -- Throne of Thunder
			[1136] = true, -- Siege of Orgrimmar
		},
	})
	
	-- Standardwerte, wenn keine gespeicherten Werte vorhanden sind
    CombatLoggerClassicDB = CombatLoggerClassicDB or {
        showLog = true,
        frameMovable = false,
		--- CLASSIC ---
			[169] = true, -- Emerald Dream
			[249] = true, -- Onyxias Lair
			[409] = true, -- Molten Core
			[469] = true, -- Blackwing Lair
			[509] = true, -- Ruins of AhnQiraj
			[531] = true, -- AnQiraj Temple
			--- TBC ---
			[532] = true, -- Karazhan
			[534] = true, -- The Battle for Mount Hyjal
			[544] = true, -- Magtheridon's Lair
			[548] = true, -- Coilfang: Serpentshrine Cavern
			[550] = true, -- Tempest Keep
			[564] = true, -- Black Temple
			[565] = true, -- Gruul's Lair
			[580] = true, -- The Sunwell
			--- WOTLK ---
			[533] = true, -- Naxxramas
			[603] = true, -- Ulduar
			[615] = true, -- The Obsidian Sanctum
			[616] = true, -- The Eye of Eternity
			[624] = true, -- Vault of Archavon
			[631] = true, -- Icecrown Citadel
			[649] = true, -- Trial of the Crusader
			[724] = true, -- The Ruby Sanctum
			--- CATA ---
			[757] = true, -- Baradin Hold
			[669] = true, -- Blackwing Descent
			[671] = true, -- The Bastion of Twilight
			[754] = true, -- Throne of the Four Winds
			[720] = true, -- Firelands
			[967] = true, -- Dragon Soul
			--- PANDA ---
			[996] = true, -- Terrace of Endless Spring
			[1008] = true, -- Mogu'shan Vaults
			[1009] = true, -- Heart of Fear
			[1098] = true, -- Throne of Thunder
			[1136] = true, -- Siege of Orgrimmar
    }
	
	CombatLoggerClassic:SetupMenu()
end

function CombatLoggerClassic:OnEnable()
    -- Events that can change instance/logging state
    self:RegisterEvent("UPDATE_INSTANCE_INFO")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("PLAYER_UNGHOST")

    -- Initial check
    --CombatLoggerClassic:CheckInstanceAndLog()
	self:RequestRecheck()
	self:CreateTextFrame()
	self:StartTimer()
end

function CombatLoggerClassic:OnDisable()
end

--[[
    Events
--]]

function CombatLoggerClassic:UPDATE_INSTANCE_INFO()
    CombatLoggerClassic:CheckInstanceAndLog()
end

--[[
    Core functions
--]]

function CombatLoggerClassic:OnDisable()
    -- Intentionally left empty
end

function CombatLoggerClassic:IsRaidForced(idNum, instanceType)
    if not idNum or idNum == 0 then return false end
    if instanceType ~= "raid" then return false end
    -- only raids that are enabled in options are forced
    return self.db and self.db.global and self.db.global[idNum] == true
end

-- Event handlers just request a debounced re-check
function CombatLoggerClassic:UPDATE_INSTANCE_INFO() self:RequestRecheck() end
function CombatLoggerClassic:PLAYER_ENTERING_WORLD() self:RequestRecheck() end
function CombatLoggerClassic:ZONE_CHANGED_NEW_AREA() self:RequestRecheck() end
function CombatLoggerClassic:PLAYER_DEAD() self:RequestRecheck() end
function CombatLoggerClassic:PLAYER_UNGHOST() self:RequestRecheck() end

function CombatLoggerClassic:RequestRecheck()
    if self._pendingRecheck then return end
    self._pendingRecheck = true
    if C_Timer and C_Timer.After then
        C_Timer.After(RECHECK_DELAY_SEC, function()
            self._pendingRecheck = false
            self:CheckInstanceAndLog()
        end)
    else
        -- Fallback if C_Timer isn’t available (should be in MoP Classic)
        self._pendingRecheck = false
        self:CheckInstanceAndLog()
    end
end

-- Core logic: print only when logging state actually changes
-- Core logic: print only on state changes; forced raids override manual override
function CombatLoggerClassic:CheckInstanceAndLog()
    local name, instanceType, _, _, _, _, _, instanceID, instanceGroupSize = GetInstanceInfo()
    local idNum = tonumber(instanceID)

    -- Transient/invalid during ghost/phase transitions; do nothing
    if not idNum or idNum == 0 then
        return
    end

    local isLogging = LoggingCombat()
    local isRaidForced = self:IsRaidForced(idNum, instanceType)
    local isTracked = self.db and self.db.global and self.db.global[idNum] == true

    -- 1) Forced raids (selected in options) always log, ignore manual override
    if isRaidForced then
        if not isLogging then
            LoggingCombat(true)
            self._lastActiveInstanceId = idNum
            if name and instanceGroupSize then
                self:Print(L.LogInstanceActivated .. name .. " (" .. tostring(instanceGroupSize) .. ").")
            else
                self:Print(L.LogInstanceActivated .. tostring(idNum) .. ".")
            end
        end
        return
    end

    -- 2) Outside forced raids: respect manual override if present
    if self._manualOverride == "on" then
        if not isLogging then
            LoggingCombat(true)  -- keep ON
            -- no print; manual button already printed L.LogStart
        end
        return
    elseif self._manualOverride == "off" then
        if isLogging then
            LoggingCombat(false) -- keep OFF
            -- no print; manual button already printed L.LogStopped
        end
        return
    end

    -- 3) No manual override -> normal auto rules (selected instances only)
    if isTracked and not isLogging then
        LoggingCombat(true)
        self._lastActiveInstanceId = idNum
        if name and instanceGroupSize then
            self:Print(L.LogInstanceActivated .. name .. " (" .. tostring(instanceGroupSize) .. ").")
        else
            self:Print(L.LogInstanceActivated .. tostring(idNum) .. ".")
        end
        return
    end

    if (not isTracked) and isLogging then
        self:Print(L.LogInstanceDeactivated)
        LoggingCombat(false)
        self._lastActiveInstanceId = nil
        return
    end

    -- already correct state: do nothing (no spam)
    if isTracked and isLogging then
        self._lastActiveInstanceId = idNum
    end
end



--[[
    Frame  on display
--]]



function CombatLoggerClassic:CreateTextFrame()
    local frame = CreateFrame("Frame", "MyTextFrame", UIParent, "BackdropTemplate")
    frame:SetSize(225, 25)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)

    self.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.text:SetPoint("CENTER", frame, "CENTER")
    self.text:SetText(L.FrameText)
	self.text:SetFont(fitzFont, 14)
	
	-- Configure Right Click Menu
	frame:SetScript("OnMouseDown", function(self, button)
		if button == "RightButton" then
			-- Menü anzeigen
			MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
				-- Menü erstellen
				rootDescription:CreateTitle(L.MenuName)
				
				-- Open Config
				rootDescription:CreateButton(L.MenuOpenConfig, function()
					CombatLoggerClassic:ShowConfig()
				end)

				-- Lock Frame
				rootDescription:CreateButton(L.MenuLockFrame, function()
					CombatLoggerClassic.db.global.frameMovable = false
					CombatLoggerClassic:MakeFrameMovable(false)
					LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
				end)
				
				-- Unlock frame
				rootDescription:CreateButton(L.MenuUnlockFrame, function()
					CombatLoggerClassic.db.global.frameMovable = true
					CombatLoggerClassic:MakeFrameMovable(true)
					LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
				end)

				-- Hide
				rootDescription:CreateButton(L.MenuHideFrame, function()
					CombatLoggerClassic:ShowHide(false)
				end)
				
				-- Start Log
				rootDescription:CreateButton(L.MenuStartLog, function()
					LoggingCombat(true)
					CombatLoggerClassic._manualOverride = "on"
					print(L.LogStart)
					CombatLoggerClassic:RequestRecheck()
				end)

				-- Stop Log
				rootDescription:CreateButton(L.MenuStopLog, function()
					LoggingCombat(false)
					CombatLoggerClassic._manualOverride = "off"
					print(L.LogStopped)
					CombatLoggerClassic:RequestRecheck()
				end)

				-- Menü schließen
				rootDescription:CreateButton(CLOSE, function()
					-- Schließen wird automatisch durch das System behandelt
				end)
			end)
		end
	end)
	
	self.frame = frame
	self:RestoreFramePosition()
end



function CombatLoggerClassic:MakeFrameMovable(enabled)
    if not self.frame then
        self:Print(L.FrameIsHidden)
        return
    end

    if enabled then
        self.frame:EnableMouse(true)
        self.frame:SetMovable(true)
        self.frame:RegisterForDrag("LeftButton")
        self.frame:SetScript("OnDragStart", self.frame.StartMoving)
        self.frame:SetScript("OnDragStop", self.frame.StopMovingOrSizing)
    else
        self.frame:EnableMouse(false)
        self.frame:SetMovable(false)
        self.frame:RegisterForDrag()
        self.frame:SetScript("OnDragStart", nil)
        self.frame:SetScript("OnDragStop", nil)
    end
	
	self.frame:SetScript("OnDragStop", function(frame)
		frame:StopMovingOrSizing()
		CombatLoggerClassic:SaveFramePosition()
	end)
	
	CombatLoggerClassic:ReSetupRightClickMenu()
end

function CombatLoggerClassic:ShowHide(enabled)
    if not self.frame then
        self:Print(L.FrameIsHidden)
        return
    end

    if enabled then
        self.frame:Show()
    else
        self.frame:Hide()
    end
end


function CombatLoggerClassic:SaveFramePosition()
    if not self.frame then return end
    local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint()
    self.db.global.framePosition = { point, relativePoint, xOfs, yOfs }
end

function CombatLoggerClassic:RestoreFramePosition()
    if self.db.global.framePosition then
        local point, relativePoint, xOfs, yOfs = unpack(self.db.global.framePosition)
        self.frame:ClearAllPoints()
        self.frame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER")
    end
end

-- Optionspanel erstellen
function CLCOptionsPanel()
    local CLCOptions = CreateFrame("FRAME", "CombatLoggerClassicOptionsPanel", InterfaceOptionsFrame)
    CLCOptions.name = L.Name

    local mainCategory, mainLayout = Settings.RegisterCanvasLayoutCategory(CLCOptions, CLCOptions.name);
	mainCategory.ID = CLCOptions.name
	catID = Settings.RegisterAddOnCategory(mainCategory);
	CLCOptions:SetPoint("TOPLEFT", InterfaceOptionsFrame, "BOTTOMRIGHT", 0, 0)
end

function CombatLoggerClassic:GetLogStatus()
	local combatActive = LoggingCombat()
    if (combatActive == true) then
        return L.IsLogging -- Green Text
	end
    if (combatActive == false) then
        return L.IsNotLogging -- Red Text
    end
	if (combatActive == nil) then
        return L.LogError
    end
end

function CombatLoggerClassic:StartTimer()
    local function timerFunction()
		local logText = self:GetLogStatus()
		if (logText ~= "ERROR") then
			self.text:SetText(L.FrameText .. logText)
			self.text:SetFont(fitzFont, 14)
		end        
    end
    C_Timer.NewTicker(5, timerFunction)
end


function CombatLoggerClassic:ReSetupRightClickMenu()

	self.frame:SetScript("OnMouseDown", function(self, button)
		if button == "RightButton" then
			-- Menü anzeigen
			MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
				-- Menü erstellen
				rootDescription:CreateTitle(L.MenuName)
				
				-- Open Config
				rootDescription:CreateButton(L.MenuOpenConfig, function()
					CombatLoggerClassic:ShowConfig()
				end)

				-- Lock Frame
				rootDescription:CreateButton(L.MenuLockFrame, function()
					CombatLoggerClassic.db.global.frameMovable = false
					CombatLoggerClassic:MakeFrameMovable(false)
					LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
				end)
				
				-- Unlock frame
				rootDescription:CreateButton(L.MenuUnlockFrame, function()
					CombatLoggerClassic.db.global.frameMovable = true
					CombatLoggerClassic:MakeFrameMovable(true)
					LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
				end)

				-- Hide
				rootDescription:CreateButton(L.MenuHideFrame, function()
					CombatLoggerClassic:ShowHide(false)
				end)
				
				-- Start Log
				rootDescription:CreateButton(L.MenuStartLog, function()
					LoggingCombat(true)
					CombatLoggerClassic._manualOverride = "on"
					print(L.LogStart)
					CombatLoggerClassic:RequestRecheck()
				end)

				-- Stop Log
				rootDescription:CreateButton(L.MenuStopLog, function()
					LoggingCombat(false)
					CombatLoggerClassic._manualOverride = "off"
					print(L.LogStopped)
					CombatLoggerClassic:RequestRecheck()
				end)

				-- Menü schließen
				rootDescription:CreateButton(CLOSE, function()
					-- Schließen wird automatisch durch das System behandelt
				end)
			end)
		end
	end)

end

---
-- AceConfigDialog Menu Adding
---

function CombatLoggerClassic:SetupMenu()
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("CombatLoggerClassic", self.GenerateOptions)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("CombatLoggerClassicSlashCommand", self.OptionsSlash, "clc")
	
	-- The ordering here matters, it determines the order in the Blizzard Interface Options
	local ACD3 = LibStub("AceConfigDialog-3.0")
	self.optionsFrames = {}
	self.optionsFrames.CombatLoggerClassic,catID = ACD3:AddToBlizOptions("CombatLoggerClassic", "Combat Logger Classic "..L.Version, nil, "General")
	self:RegisterModuleOptions("CLCSlashCommand", self.OptionsSlash, "Slash Command")

end


---
-- AceConfig Menu Frame
---
local moduleOptions = {}    -- Table for LoD module options registration

function CombatLoggerClassic:RegisterModuleOptions(name, optionTbl, displayName)
	if moduleOptions then
		moduleOptions[name] = optionTbl
	else
		self.Options.args[name] = (type(optionTbl) == "function") and optionTbl() or optionTbl
	end
	self.optionsFrames[name] = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CombatLoggerClassic", displayName, "Combat Logger Classic "..L.Version, name)
	
end


function CombatLoggerClassic.GenerateOptions()
	if CombatLoggerClassic.noconfig then assert(false, CombatLoggerClassic.noconfig) end
	if not CombatLoggerClassic.Options then
		CombatLoggerClassic.GenerateOptionsInternal()
		CombatLoggerClassic.GenerateOptionsInternal = nil
		moduleOptions = nil
	end
	return CombatLoggerClassic.Options
end

function CombatLoggerClassic:ShowConfig()
	Settings.OpenToCategory(catID)
end


-- Building Slash Commands

-- Option table for the slash command only
CombatLoggerClassic.OptionsSlash = {
	type = "group",
	name = "Slash Commands",
	order = -3,
	args = {
		options = {
			type = "execute",
			name = "Options",
			desc = L.ChatOptions,
			func = function() 
				CombatLoggerClassic:ShowConfig()
			end,
		},
		show = {
			type = "execute",
			name = "Show",
			desc = L.ChatShowFrame,
			func = function() 
				CombatLoggerClassic.db.global.showLog = true
				CombatLoggerClassic:ShowHide(true)
			end,
		},
		hide = {
			type = "execute",
			name = "Hide",
			desc = L.ChatHideFrame,
			func = function() 
				CombatLoggerClassic.db.global.showLog = false
				CombatLoggerClassic:ShowHide(false)
			end,
		},
		move = {
			type = "execute",
			name = "Move",
			desc = L.ChatMoveFrame,
			func = function() 
				CombatLoggerClassic.db.global.frameMovable = true
				CombatLoggerClassic:MakeFrameMovable(true)
			end,
		},
		lock = {
			type = "execute",
			name = "Lock",
			desc = L.ChatLockFrame,
			func = function() 
				CombatLoggerClassic.db.global.frameMovable = false
				CombatLoggerClassic:MakeFrameMovable(false)
			end,
		},
	},
}



-- Building Menu

function CombatLoggerClassic.GenerateOptionsInternal()
	local outlines = {
		[""]             = "None",
		["OUTLINE"]      = "Outline",
		["THICKOUTLINE"] = "Thick Outline",
	}

	local function GetFuBarMinimapAttachedStatus(info)
		return CombatLoggerClassic:IsFuBarMinimapAttached() or db.FuBar.HideMinimapButton
	end

	-- Option table for the AceGUI config only
	CombatLoggerClassic.Options = {
		type = "group",
		name = L.Name,
		args = {
			General = {
				order = 1,
				type = "group",
				name = L.SettingsGeneral,
				desc = L.SettingsGeneral,
				args = {
					logstatus = {
						name = L.SettingsLockStatus,
						order = 1,
						desc = L.SettingsLockStatusDesc,
						type = "toggle",
						set = function(info, value)
							CombatLoggerClassic.db.global.showLog = value
							CombatLoggerClassic:ShowHide(value)
							LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
						end,
						get = function(info)
							return CombatLoggerClassic.db.global.showLog
						end,
					},
					moveframe = {
						name = L.SettingsMoveStatus,
						order = 2,
						desc = L.SettingsMoveStatusDesc,
						type = "toggle",
						set = function(info, value)
							CombatLoggerClassic.db.global.frameMovable = value
							CombatLoggerClassic:MakeFrameMovable(value)
							LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
						end,
						get = function(info)
							return CombatLoggerClassic.db.global.frameMovable
						end,
					},
					RaidBegin = {
						type = "header",
						name = L.RaidsName,
						order = 3

					},
					Classic = {
						type = "group",
						name = L.RaidsClassicName,
						guiInline = true,
						order = 21,
						args ={
							infoTextClassic = {
								type = "description",
								name = L.RaidsClassicDesc,
								fontSize = "medium", -- "small", "medium", "large"
								order = 0,
							},
							RaidsClassicEmerald = {
								name = L.RaidsClassicEmerald,
								order = 1,
								desc = L.RaidsClassicEmeraldDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[169] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[169]
								end,
							},
							RaidsClassicOnyxias = {
								name = L.RaidsClassicOnyxias,
								order = 2,
								desc = L.RaidsClassicOnyxiasDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[249] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[249]
								end,
							},
							RaidsClassicMolten = {
								name = L.RaidsClassicMolten,
								order = 3,
								desc = L.RaidsClassicMoltenDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[409] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[409]
								end,
							},
							RaidsClassicBlackwing = {
								name = L.RaidsClassicBlackwing,
								order = 4,
								desc = L.RaidsClassicBlackwingDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[469] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[469]
								end,
							},
							RaidsClassicRuins = {
								name = L.RaidsClassicRuins,
								order = 5,
								desc = L.RaidsClassicRuinsDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[509] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[509]
								end,
							},
							RaidsClassicAnQiraj = {
								name = L.RaidsClassicAnQiraj,
								order = 6,
								desc = L.RaidsClassicAnQirajDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[531] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[531]
								end,
							},
						},
					},
					TBC = {
						type = "group",
						name = L.RaidsTBCName,
						guiInline = true,
						order = 22,
						args ={
							infoTextTBC = {
								type = "description",
								name = L.RaidsTBCDesc,
								fontSize = "medium", -- "small", "medium", "large"
								order = 0,
							},
							RaidsTBCKarazhan = {
								name = L.RaidsTBCKarazhan,
								order = 1,
								desc = L.RaidsTBCKarazhanDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[532] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[532]
								end,
							},
							RaidsTBCMount = {
								name = L.RaidsTBCMount,
								order = 2,
								desc = L.RaidsTBCMountDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[534] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[534]
								end,
							},
							RaidsTBCMagtheridon = {
								name = L.RaidsTBCMagtheridon,
								order = 3,
								desc = L.RaidsTBCMagtheridonDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[544] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[544]
								end,
							},
							RaidsTBCCoilfang = {
								name = L.RaidsTBCCoilfang,
								order = 4,
								desc = L.RaidsTBCCoilfangDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[548] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[548]
								end,
							},
							RaidsTBCTempest = {
								name = L.RaidsTBCTempest,
								order = 5,
								desc = L.RaidsTBCTempestDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[550] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[550]
								end,
							},
							RaidsTBCTemple = {
								name = L.RaidsTBCTemple,
								order = 6,
								desc = L.RaidsTBCTempleDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[564] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[564]
								end,
							},
							RaidsTBCSunwell = {
								name = L.RaidsTBCSunwell,
								order = 7,
								desc = L.RaidsTBCSunwellDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[565] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[565]
								end,
							},
							RaidsTBCGruul = {
								name = L.RaidsTBCGruul,
								order = 8,
								desc = L.RaidsTBCGruulDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[580] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[580]
								end,
							},
						},
					},
					WotLK = {
						type = "group",
						name = L.RaidsWotLKName,
						guiInline = true,
						order = 23,
						args ={
							infoTextWotLK = {
								type = "description",
								name = L.RaidsWotLKDesc,
								fontSize = "medium", -- "small", "medium", "large"
								order = 0,
							},
							RaidsWotLKNaxxramas = {
								name = L.RaidsWotLKNaxxramas,
								order = 1,
								desc = L.RaidsWotLKNaxxramasDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[533] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[533]
								end,
							},
							RaidsWotLKUlduar = {
								name = L.RaidsWotLKUlduar,
								order = 2,
								desc = L.RaidsWotLKUlduarDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[603] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[603]
								end,
							},
							RaidsWotLKObsidian = {
								name = L.RaidsWotLKObsidian,
								order = 3,
								desc = L.RaidsWotLKObsidianDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[615] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[615]
								end,
							},
							RaidsWotLKEternity = {
								name = L.RaidsWotLKEternity,
								order = 4,
								desc = L.RaidsWotLKEternityDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[616] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[616]
								end,
							},
							RaidsWotLKArchavon = {
								name = L.RaidsWotLKArchavon,
								order = 5,
								desc = L.RaidsWotLKArchavonDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[624] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[624]
								end,
							},
							RaidsWotLKIcecrown = {
								name = L.RaidsWotLKIcecrown,
								order = 6,
								desc = L.RaidsWotLKIcecrownDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[631] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[631]
								end,
							},
							RaidsWotLKCrusader = {
								name = L.RaidsWotLKCrusader,
								order = 7,
								desc = L.RaidsWotLKCrusaderDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[649] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[649]
								end,
							},
							RaidsWotLKRuby = {
								name = L.RaidsWotLKRuby,
								order = 8,
								desc = L.RaidsWotLKRubyDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[724] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[724]
								end,
							},
						},
					},
					Cataclysm = {
						type = "group",
						name = L.RaidsCataName,
						guiInline = true,
						order = 24,
						args ={
							infoTextCata = {
								type = "description",
								name = L.RaidsCataDesc,
								fontSize = "medium", -- "small", "medium", "large"
								order = 0,
							},
							catabara = {
								name = L.RaidsCataBaradin,
								order = 1,
								desc = L.RaidsCataBaradinDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[757] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[757]
								end,
							},
							catablack = {
								name = L.RaidsCataBlackwing,
								order = 2,
								desc = L.RaidsCataBlackwingDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[669] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[669]
								end,
							},
							catabast = {
								name = L.RaidsCataBastion,
								order = 3,
								desc = L.RaidsCataBastionDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[671] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[671]
								end,
							},
							catathrone = {
								name = L.RaidsCataThrone,
								order = 4,
								desc = L.RaidsCataThroneDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[754] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[754]
								end,
							},
							catafire = {
								name = L.RaidsCataFirelands,
								order = 5,
								desc = L.RaidsCataFirelandsDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[720] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[720]
								end,
							},
							catadragon = {
								name = L.RaidsCataDragonsoul,
								order = 6,
								desc = L.RaidsCataDragonsoulDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[967] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[967]
								end,
							},
						},
					},
					Pandaria = {
						type = "group",
						name = L.RaidsMoPName,
						guiInline = true,
						order = 25,
						args ={
							infoTextMoP = {
								type = "description",
								name = L.RaidsMoPDesc,
								fontSize = "medium", -- "small", "medium", "large"
								order = 0,
							},
							RaidsMoPTerrace = {
								name = L.RaidsMoPTerrace,
								order = 1,
								desc = L.RaidsMoPTerraceDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[996] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[996]
								end,
							},
							RaidsMoPVaults = {
								name = L.RaidsMoPVaults,
								order = 2,
								desc = L.RaidsMoPVaultsDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[1008] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[1008]
								end,
							},
							RaidsMoPFear = {
								name = L.RaidsMoPFear,
								order = 3,
								desc = L.RaidsMoPFearDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[1009] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[1009]
								end,
							},
							RaidsMoPThunder = {
								name = L.RaidsMoPThunder,
								order = 4,
								desc = L.RaidsMoPThunderDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[1098] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[1098]
								end,
							},
							RaidsMoPOrgrimmar = {
								name = L.RaidsMoPOrgrimmar,
								order = 5,
								desc = L.RaidsMoPOrgrimmarDesc,
								type = "toggle",
								set = function(info, value)
									CombatLoggerClassic.db.global[1136] = value
									--CombatLoggerClassic:ShowHide(value)
									LibStub("AceConfigRegistry-3.0"):NotifyChange("CombatLoggerClassic")
								end,
								get = function(info)
									return CombatLoggerClassic.db.global[1136]
								end,
							},
						},
					},
				},
			},
		},
	}


	for k, v in pairs(moduleOptions) do
		CombatLoggerClassic.Options.args[k] = (type(v) == "function") and v() or v
	end
end

