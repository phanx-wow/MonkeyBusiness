﻿--[[----------------------------------------------------------------------------
	Monkey Business
	Brewmaster buff and cooldown monitor
	Copyright (c) 2015 Phanx <addons@phanx.net>. All rights reserved.
	See the accompanying LICENSE.txt file for more information.
	https://github.com/Phanx/MonkeyBusiness
	http://www.curse.com/addons/wow/monkeybusiness
	http://www.wowinterface.com/downloads/info
--------------------------------------------------------------------------------
	Design Guidelines
	=================

	Buffs to keep up:
	- show when missing
	- glow red when resources available

	Self-healing abilities to use on cooldown:
	- show when ready
	- glow green when resources available

	Other abilities to use on cooldown:
	- show when ready
	- glow yellow when resources available
------------------------------------------------------------------------------]]

if select(2, UnitClass("player")) ~= "MONK" then return end

local Monkey = CreateFrame("Frame", "MonkeyBusiness")
Monkey:RegisterEvent("PLAYER_ENTERING_WORLD")
Monkey:RegisterEvent("PLAYER_REGEN_DISABLED")
Monkey:RegisterEvent("PLAYER_REGEN_ENABLED")
Monkey:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "player")
Monkey:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
Monkey:SetScript("OnEvent", function(self, event, ...)
	if GetShapeshiftFormID() ~= 23 or not UnitAffectingCombat("player") or UnitHasVehiclePlayerFrameUI("player") then
		for i = 1, #self.Business do
			self.Business[i]:Deactivate()
		end
	else
		for i = 1, #self.Business do
			self.Business[i]:Activate()
		end
	end
end)

Monkey.Business = {}

function Monkey:Test(state)
	for i = 1, #self.Business do
		local socks = self.Business[i]
		socks[state and "Activate" or "Deactivate"](socks)
	end
end

--------------------------------------------------------------------------------
-- Stagger bar

local Stagger = CreateFrame("StatusBar", "MonkeyBusinessStagger", UIParent, "MirrorTimerTemplate")
Stagger:SetPoint("CENTER")
Stagger:EnableMouse(true)
Stagger:SetMovable(true)
Stagger:RegisterForDrag("LeftButton")
Stagger:SetScript("OnDragStart", Stagger.StartMoving)
Stagger:SetScript("OnDragStop", Stagger.StopMovingOrSizing)
Stagger:SetScript("OnHide", Stagger.StopMovingOrSizing)
tinsert(Monkey.Business, Stagger)

Stagger:UnregisterAllEvents()
Stagger:SetScript("OnUpdate", nil)

Stagger.Text = _G[Stagger:GetName().."Text"]
Stagger.Bar  = _G[Stagger:GetName().."StatusBar"]

Stagger.bg = Stagger:CreateTexture(nil, "BACKGROUND")
Stagger.bg:SetAllPoints(true)
Stagger.bg:SetTexture(Stagger.Bar:GetStatusBarTexture())

function Stagger:Activate()
	self:RegisterUnitEvent("UNIT_AURA", "player")
	self:Show()
	self:Update()
end

function Stagger:Deactivate()
	self:Hide()
	self:UnregisterEvent("UNIT_AURA", "player")
end

function Stagger:Update()
	local maxHealth = UnitHealthMax("player")
	local stagger = UnitStagger("player")
	local staggerPercent = stagger / maxHealth
	local color = PowerBarColor["STAGGER"] -- BREWMASTER_POWER_BAR_NAME
	if staggerPercent > 0.6 then -- STAGGER_RED_TRANSITION
		color = color[3] -- RED_INDEX
	elseif staggerPercent > 0.3 then -- STAGGER_YELLOW_TRANSITION
		color = color[2] -- YELLOW_INDEX
	else
		color = color[1] -- GREEN_INDEX
	end
	self.Bar:SetMinMaxValues(0, maxHealth)
	self.Bar:SetValue(stagger)
	self.Bar:SetStatusBarColor(color.r, color.g, color.b)
	self.bg:SetVertexColor(color.r * 0.2, color.g * 0.2, color.b * 0.2)
	self.Text:SetFormattedText("%d%%", floor(staggerPercent * 100 + 0.5))
end

Stagger:SetScript("OnEvent", Stagger.Update)

--------------------------------------------------------------------------------
-- Icon utilities

local function IconButton_OnEnter(self)
	local x, y = self:GetCenter()
	local w, h = UIParent:GetSize()
	local TOP, LEFT, BOTTOM, RIGHT = "TOP", "LEFT", "BOTTOM", "RIGHT"
	if x > w * 0.5 then LEFT, RIGHT = RIGHT, LEFT end
	if y < h * 0.5 then TOP, BOTTOM = BOTTOM, TOP end
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint(TOP..LEFT, self, BOTTOM..RIGHT)
	GameTooltip:SetSpellByID(self.spell)
end

local function IconButton_OnEvent(self, event, ...)
	return (self[event] or self.Update)(self, event, ...)
end

local function CreateIconButton(spell, name)
	assert(type(spell) == "number", "CreateIcon: spell must be a number")
	local sname, _, iconpath = GetSpellInfo(spell)
	assert(sname and iconpath, "CreateIcon: invalid spell specified")
	name = name or gsub(sname, "[%s%-'’]", "")
	assert(name and strlen(name) > 0, "CreateIcon: name cannot be empty")

	local button = CreateFrame("Button", "MonkeyBusiness"..name, Stagger, "PetBattleActionButtonTemplate") -- 52x52
	-- regions: Icon, CooldownShadow, CooldownFlash, Cooldown, HotKey, SelectedHighlight, Lock, BetterIcon
	button:SetScript("OnEvent", IconButton_OnEvent)

	button.Icon:SetTexture(iconpath)

	button.Count = button.Cooldown
	button.Count:Show()

	button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.Cooldown:SetAllPoints(button.Icon)
	button.Cooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
	button.Cooldown:SetSwipeTexture(0, 0, 0)
	button.Cooldown.noCooldownCount = true

	button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	button.Text:SetPoint("LEFT", 4, 0)

	button.spell = spell
	button:SetScript("OnEnter", IconButton_OnEnter)
	button:SetScript("OnLeave", GameTooltip_Hide)

	tinsert(Monkey.Business, button)
	return button
end

--------------------------------------------------------------------------------
-- Guard icon

local GUARD_ID, GUARD_NAME = 115295, GetSpellInfo(115295)

local Guard = CreateIconButton(GUARD_ID, "Guard")
Guard:SetPoint("BOTTOM", Stagger, "TOP", 0, 10)
Guard:Hide()

function Guard:Activate()
	self:RegisterUnitEvent("UNIT_AURA", "player")
	self:RegisterUnitEvent("UNIT_POWER", "player")
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:Show()
	self:Update()
end

function Guard:Deactivate()
	self:Hide()
	self:UnregisterEvent("UNIT_AURA")
	self:UnregisterEvent("UNIT_POWER")
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
end

function Guard:Update()
	local chi = UnitPower("player", 12) -- SPELL_POWER_CHI
	local _, _, _, _, _, buffDuration, buffExpires = UnitBuff("player", GUARD_NAME)
	local numCharges, maxCharges, rechargeStarted, rechargeDuration = GetSpellCharges(GUARD_ID)
	if buffDuration then
		self.state = "ACTIVE"
		self.endTime = buffExpires
		self:SetAlpha(0.25)
		self.SelectedHighlight:Hide()
		self:SetScript("OnUpdate", self.OnUpdate)
	elseif numCharges > 0 and chi >= 2 then
		self.state = "MISSING"
		self:SetAlpha(1)
		self.SelectedHighlight:Show()
		self.SelectedHighlight:SetVertexColor(1, 0, 0)
		self:SetScript("OnUpdate", self.OnUpdate)
	elseif numCharges > 0 then
		self.state = "RESOURCE"
		self:SetAlpha(0.5)
		self.SelectedHighlight:Hide()
		self:SetScript("OnUpdate", nil)
		self.Count:Hide()
	else
		self.state = "COOLDOWN"
		self:SetAlpha(0.5)
		self.endTime = rechargeStarted + rechargeDuration
		self.SelectedHighlight:Hide()
		self:SetScript("OnUpdate", nil)
		self.Count:Hide()
	end
end

function Guard:OnUpdate(elapsed)
	if self.state == "ACTIVE" then
		local t = self.endTime - GetTime()
		self.Count:SetFormattedText("%.01f", t)
	elseif self.state == "COOLDOWN" then
		local t = self.endTime - GetTime()
		self.Count:SetFormattedText("%.01f", t)
	end
end

--------------------------------------------------------------------------------
-- Tiger Palm reminder icon
-- Shown if missing, glow always (no resource requirement)

local TIGER_PALM_ID, TIGER_PALM_NAME = 100787, GetSpellInfo(100787)
local TIGER_POWER_ID, TIGER_POWER_NAME = 125359, GetSpellInfo(125359)

local TigerPalm = CreateIconButton(TIGER_PALM_ID, "TigerPalm")
TigerPalm:SetPoint("TOPLEFT", Stagger, "BOTTOMLEFT", 0, -10 * (1 / 0.6))
TigerPalm:SetScale(0.6)

TigerPalm.SelectedHighlight:SetVertexColor(1, 0, 0)
TigerPalm.SelectedHighlight:Show()

function TigerPalm:Activate()
	self:RegisterUnitEvent("UNIT_AURA", "player")
	self:Update()
end

function TigerPalm:Deactivate()
	self:Hide()
	self:UnregisterEvent("UNIT_AURA")
end

function TigerPalm:Update()
	local _, _, _, _, _, buffDuration, buffExpires = UnitBuff("player", TIGER_POWER_NAME)
	self:SetShown(not buffDuration)
end

--------------------------------------------------------------------------------
-- Death Note reminder icon
-- Shown if usable on current target, glow if resources available

local DEATH_NOTE_ID, DEATH_NOTE_NAME = 121125, GetSpellInfo(121125)

local DeathNote = CreateIconButton(DEATH_NOTE_ID, "DeathNote")
DeathNote:SetPoint("TOPLEFT", Stagger, "BOTTOMLEFT", 0, -10 * (1 / 0.6))
DeathNote:SetScale(0.6)

function DeathNote:Activate()
	self:RegisterUnitEvent("UNIT_AURA", "player")
	self:RegisterUnitEvent("UNIT_POWER", "player")
	self:Update()
end

function DeathNote:Deactivate()
	self:Hide()
	self:UnregisterEvent("UNIT_AURA")
	self:UnregisterEvent("UNIT_POWER")
end

function DeathNote:Update()
	local _, _, _, _, _, buffDuration, buffExpires = UnitBuff("player", DEATH_NOTE_NAME)
	if not buffDuration then
		self:Hide()
	else
		local chi = UnitPower("player", 12) -- SPELL_POWER_CHI
		self.SelectedHighlight:SetShown(chi >= 3)
		self:Show()
		if TigerPalm:IsShown() then
			self:SetPoint("TOPLEFT", TigerPalm, "TOPRIGHT", -4 * (1 / 0.6), 0)
		else
			self:SetPoint("TOPLEFT", Stagger, "BOTTOMLEFT", 0, -10 * (1 / 0.6))
		end
	end
end

--------------------------------------------------------------------------------
-- Shuffle icon
-- Show if missing, glow if resources available, show transparent under 12s

local SHUFFLE_ID, SHUFFLE_NAME = 115307, GetSpellInfo(115307)

local Shuffle = CreateIconButton(SHUFFLE_ID, "Shuffle")
Shuffle:SetPoint("BOTTOMRIGHT", Stagger, "TOPRIGHT", 0, 15 * (1 / 0.6))
Shuffle:SetScale(0.6)

Shuffle.SelectedHighlight:SetVertexColor(1, 0, 0)

function Shuffle:Activate()
	self:RegisterUnitEvent("UNIT_AURA", "player")
	self:RegisterUnitEvent("UNIT_POWER", "player")
	self:Update()
end

function Shuffle:Deactivate()
	self:UnregisterEvent("UNIT_AURA")
	self:UnregisterEvent("UNIT_POWER")
	self:Hide()
end

function Shuffle:Update()
	local _, _, _, _, _, buffDuration, buffExpires = UnitBuff("player", SHUFFLE_NAME)
	if not buffDuration then
		local chi = UnitPower("player", 12) -- SPELL_POWER_CHI
		self:SetScript("OnUpdate", nil)
		self.SelectedHighlight:SetShown(chi >= 2)
		self.Count:SetText(nil)
		self:SetAlpha(1)
		self:Show()
	elseif buffDuration > 12 then
		self:Hide()
		self:SetScript("OnUpdate", nil)
		self.SelectedHighlight:Hide()
		self.Count:SetText(nil)
		self:SetAlpha(1)
	else
		self.SelectedHighlight:Hide()
		self.expirationTime = buffExpires
		self:SetScript("OnUpdate", self.OnUpdate)
		self:Show()
	end
end

function Shuffle:OnUpdate(elapsed)
	local t = self.expirationTime - GetTime()
	self.Count:SetFormattedText("%.01f", t)
	self:SetAlpha(1 - (0.9 * (t / 12))) -- 10% at 12 sec, 100% at 0 sec
end

--------------------------------------------------------------------------------
-- Expel Harm icon
-- Show if off cooldown, glow if resources available

local EXPEL_HARM_ID, EXPEL_HARM_NAME = 115072, GetSpellInfo(115072)

local ExpelHarm = CreateIconButton(EXPEL_HARM_ID, "ExpelHarm")
ExpelHarm:SetPoint("TOPRIGHT", Stagger, "BOTTOMRIGHT", 0, -10 * (1 / 0.6))
ExpelHarm:SetScale(0.6)

ExpelHarm.SelectedHighlight:SetVertexColor(0, 1, 0)

function ExpelHarm:Activate()
	self:RegisterUnitEvent("UNIT_HEALTH", "player")
	self:RegisterUnitEvent("UNIT_POWER", "player")
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:Update()
end

function ExpelHarm:Deactivate()
	self:Hide()
	self:UnregisterEvent("UNIT_HEALTH")
	self:UnregisterEvent("UNIT_POWER")
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
end

function ExpelHarm:Update()
	local start, duration = GetSpellCooldown(EXPEL_HARM_ID)
	local health, healthMax = UnitHealth("player"), UnitHealthMax("player")
	if start == 0 and health < healthMax then
		local energy = UnitPower("player", 3) -- SPELL_POWER_ENERGY
		self.SelectedHighlight:SetShown(energy >= 40)
		self:Show()
	else
		self:Hide()
	end
end

--------------------------------------------------------------------------------
-- Chi Wave icon
-- Show if off cooldown, glow always (no resource requirement)

local CHI_WAVE_ID, CHI_WAVE_NAME = 115098, GetSpellInfo(115098)

local ChiWave = CreateIconButton(CHI_WAVE_ID, "ChiWave")
ChiWave:SetPoint("TOPRIGHT", Stagger, "BOTTOMRIGHT", 0, -10 * (1 / 0.6))
ChiWave:SetScale(0.6)

ChiWave.SelectedHighlight:SetVertexColor(0, 1, 0)
ChiWave.SelectedHighlight:Show()

function ChiWave:PLAYER_TALENT_UPDATE()

end

function ChiWave:Activate()
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:Update()
end

function ChiWave:Deactivate()
	self:Hide()
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
end

function ChiWave:Update()
	local start, duration = GetSpellCooldown(self.spellID or CHI_WAVE_ID)
	if start == 0 then
		if ExpelHarm:IsShown() then
			self:SetPoint("TOPRIGHT", ExpelHarm, "TOPLEFT", -10 * (1 / 0.6), 0)
		else
			self:SetPoint("TOPRIGHT", Stagger, "BOTTOMRIGHT", 0, -10 * (1 / 0.6))
		end
		self:Show()
	else
		self:Hide()
	end
end
