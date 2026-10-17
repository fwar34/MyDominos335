--[[
totemBar
A dominos totem bar
--]]
--[[
	中文说明：本文件为图腾条模块 totemBar.lua
	职责：为萨满提供图腾动作条。包含两套实现：
	       1) 原生图腾条 LoadTotemBars：为每系图腾建立 Dominos Frame("totem1".."totem4")，
	          按钮取自图腾动作槽（起始动作 ID = 132），并监听 UPDATE_MULTI_CAST_ACTIONBAR 刷新。
	       2) 备用图腾条 LoadAltTotemBars：当 Dominos:ATotemBar() 开启时启用，接管暴雪原生
	          MultiCastActionBarFrame 及各 MultiCastSlot/Summon/Recall 控件的位置与显示（思路复制自 aTotemBar）。
	     按钮：CALL 为“召唤 X 图腾”法术按钮，RECALL 为“图腾召回”法术按钮，均来自 Dominos.SpellButton。
	关键依赖：Dominos（Frame/ActionButton/SpellButton、Delay、db.profile.totemBar）、AceEvent-3.0、
	     暴雪原生图腾 API（TOTEM_MULTI_CAST_*、GetTotemInfo、DestroyTotem、MultiCastActionBarFrame 等旧 API）。
	被谁使用：由 modules/totemBar/totemBar.xml → modules/_load.xml 加载。
	注意：插件对外名已改为 MyDominos335，但内部标识仍为 Dominos——模块名、类名与全局表仍为 Dominos，均属内部标识。
--]]
--no reason to load if we're not playing a shaman...
assert(Dominos, "Dominos not found!")
-- 仅萨满加载：非萨满职业则直接退出本模块
if Dominos.MyClass ~= "SHAMAN" then return end

local Dominos = Dominos
local DTB = Dominos:NewModule("totems", "AceEvent-3.0")
local TotemBar, hooked, _

--hurray for constants
local MAX_TOTEMS = MAX_TOTEMS --fire, earth, water, air
local RECALL_SPELL = TOTEM_MULTI_CAST_RECALL_SPELLS[1]
local START_ACTION_ID = 132 --actionID start of the totembar
local SUMMON_SPELLS = TOTEM_MULTI_CAST_SUMMON_SPELLS

--[[ Module ]]
-- 模块入口：由 Dominos:ATotemBar() 决定走原生图腾条（LoadTotemBars）还是备用 aTotemBar（LoadAltTotemBars）
function DTB:Load()
	if Dominos:ATotemBar() then
		self:Unload()
		self:LoadAltTotemBars()
	else
		self:LoadTotemBars()
		self:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")
	end
end

function DTB:Unload()
	self:FreeTotemBars()

	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self:UnregisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")
end

function DTB:UPDATE_MULTI_CAST_ACTIONBAR()
	if not InCombatLockdown() then
		self:LoadTotemBars()
	else
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
end

function DTB:PLAYER_REGEN_ENABLED()
	self:LoadTotemBars()
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

do
	local function Dominos_RestoreSaturation(self, icon)
		if icon and icon:IsDesaturated() then
			icon:SetDesaturated(false)
		end
	end

	local function Dominos_TotemButton_Update(button, start, duration)
		local icon = _G[button:GetName() .. "IconTexture"]
		if duration and duration >= 2.01 then
			local nextTime = math.ceil(start + duration - GetTime())
			Dominos:Delay(math.min(duration, nextTime), Dominos_RestoreSaturation, button, icon)

			if not icon:IsDesaturated() then
				icon:SetDesaturated(true)
			end
		else
			Dominos_RestoreSaturation(button)
		end
	end

	-- 原生图腾条实现：为四系图腾建立/复用 Dominos Frame，并挂钩暴雪 TotemButton_Update 以驱动图腾计时置灰
	function DTB:LoadTotemBars()
		for i, spell in pairs(SUMMON_SPELLS) do
			local f = Dominos.Frame:Get("totem" .. i)
			if f then
				f:LoadButtons()
			else
				TotemBar:New(i, spell)
			end
		end

		if not hooked then
			hooksecurefunc("TotemButton_Update", Dominos_TotemButton_Update)
			hooked = true
		end
	end
end

function DTB:FreeTotemBars()
	for i, _ in pairs(SUMMON_SPELLS) do
		local f = Dominos.Frame:Get("totem" .. i)
		if f then
			f:Free()
		end
	end
end

--[[ Totem Bar ]]
TotemBar = Dominos:CreateClass("Frame", Dominos.Frame)

function TotemBar:New(id, spell)
	local f = self.super.New(self, "totem" .. id)
	f.totemBarID = id
	f.callSpell = spell
	f:LoadButtons()
	f:Layout()

	return f
end

local totembarDfaults

function TotemBar:GetDefaults()
	if not totembarDfaults then
		totembarDfaults = {
			point = "CENTER",
			spacing = 2,
			showRecall = true,
			showTotems = true
		}
	end
	return totembarDfaults
end

function TotemBar:NumButtons()
	local numButtons = 0

	if self:IsCallKnown() then
		numButtons = numButtons + 1
	end

	if self:ShowingTotems() then
		numButtons = numButtons + MAX_TOTEMS
	end

	if self:ShowingRecall() and self:IsRecallKnown() then
		numButtons = numButtons + 1
	end

	return numButtons
end

function TotemBar:GetBaseID()
	return START_ACTION_ID + (MAX_TOTEMS * (self.totemBarID - 1))
end

--handle displaying the totemic recall button
function TotemBar:SetShowRecall(show)
	self.sets.showRecall = show and true or false
	self:LoadButtons()
	self:Layout()
end

function TotemBar:ShowingRecall()
	return self.sets.showRecall
end

--handle displaying all of the totem buttons
function TotemBar:SetShowTotems(show)
	self.sets.showTotems = show and true or false
	self:LoadButtons()
	self:Layout()
end

function TotemBar:ShowingTotems()
	return self.sets.showTotems
end

--[[ button stuff]]
local tinsert = table.insert

function TotemBar:LoadButtons()
	local buttons = self.buttons

	--remove old buttons
	for i, b in pairs(buttons) do
		b:Free()
		buttons[i] = nil
	end

	--add call of X button
	if self:IsCallKnown() then
		tinsert(buttons, self:GetCallButton())
	end

	--add totem actions
	if self:ShowingTotems() then
		for _, totemID in ipairs(TOTEM_PRIORITIES) do
			tinsert(buttons, self:GetTotemButton(totemID))
		end
	end

	--add recall button
	if self:ShowingRecall() and self:IsRecallKnown() then
		tinsert(buttons, self:GetRecallButton())
	end

	self.header:Execute([[ control:ChildUpdate('action', nil) ]])
end

function TotemBar:IsCallKnown()
	return IsSpellKnown(self.callSpell, false)
end

-- CALL 按钮：“召唤 X 图腾”法术按钮
function TotemBar:GetCallButton()
	return self:CreateSpellButton(self.callSpell)
end

function TotemBar:IsRecallKnown()
	return IsSpellKnown(RECALL_SPELL, false)
end

-- RECALL 按钮：“图腾召回”法术按钮
function TotemBar:GetRecallButton()
	return self:CreateSpellButton(RECALL_SPELL)
end

function TotemBar:GetTotemButton(id)
	return self:CreateActionButton(self:GetBaseID() + id)
end

function TotemBar:CreateSpellButton(spellID)
	local b = Dominos.SpellButton:New(spellID)
	b:SetParent(self.header)
	return b
end

function TotemBar:CreateActionButton(actionID)
	local b = Dominos.ActionButton:New(actionID)
	b:SetParent(self.header)
	b:LoadAction()
	return b
end

--[[ right click menu ]]
function TotemBar:AddLayoutPanel(menu)
	local L = LibStub("AceLocale-3.0"):GetLocale("Dominos-Config", "enUS")
	local panel = menu:AddLayoutPanel()

	--add show totemic recall toggle
	local showRecall = panel:NewCheckButton(L.ShowTotemRecall)
	showRecall:SetScript("OnClick", function(b)
		self:SetShowRecall(b:GetChecked())
		panel.colsSlider:OnShow() --force update the columns slider
	end)
	showRecall:SetScript("OnShow", function(b) b:SetChecked(self:ShowingRecall()) end)

	--add show totems toggle
	local showTotems = panel:NewCheckButton(L.ShowTotems)
	showTotems:SetScript("OnClick", function(b)
		self:SetShowTotems(b:GetChecked())
		panel.colsSlider:OnShow()
	end)
	showTotems:SetScript("OnShow", function(b) b:SetChecked(self:ShowingTotems()) end)
end

function TotemBar:CreateMenu()
	self.menu = Dominos:NewMenu(self.id)
	self:AddLayoutPanel(self.menu)
	self.menu:AddAdvancedPanel()
end

-- shamelessly copied from aTotemBar
do
	local db
	local aTotemBar
	local BlizzardTimers = true
	local aTotemBarTimers = true
	local TotemTimers = {}
	local spacing = 4

	local defaults = {Anchor = "CENTER", X = 0, Y = 0, Scale = 1.0}
	local Dominos_aTotemBar_Destroy
	local Dominos_aTotemBar_Update

	local function Dominos_TotemBar_Lock(self)
		self.bg:Hide()
		self:SetMovable(false)
		self:EnableMouse(false)
		self:SavePosition()
	end

	local function Dominos_TotemBar_Unlock(self)
		self.bg:Show()
		self:SetMovable(true)
		self:EnableMouse(true)
	end

	local function Dominos_TotemBar_SavePosition(self)
		if self then
			local x, y = self:GetLeft(), self:GetTop()
			local s = db.Scale or self:GetEffectiveScale()
			db.X, db.Y = x * s, y * s
		end
	end

	local function Dominos_TotemBar_RestorePosition(self)
		if self then
			local x, y = db.X, db.Y
			if not x or not y or (x == 0 and y == 0) then
				self:ClearAllPoints()
				self:SetPoint("CENTER", UIParent)
			else
				local s = db.Scale or self:GetEffectiveScale()
				self:ClearAllPoints()
				self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
			end
		end
	end

	local function aTotemBar_PLAYER_ENTERING_WORLD(totemBar)
		aTotemBar = aTotemBar or totemBar
		if not aTotemBar then
			return
		elseif HasMultiCastActionBar() == false then
			aTotemBar:Hide()
		else
			aTotemBar:Show()
		end
		for i = 1, MAX_TOTEMS do
			Dominos_aTotemBar_Update(i)
		end
	end

	-- 备用图腾条初始化：接管并重定位暴雪原生 MultiCastActionBarFrame 等控件，为四系图腾创建计时 Cooldown
	local function SetupTotemBar()
		if aTotemBar then return end

		aTotemBar = Dominos:CreateClass("Frame", Dominos.Frame)
		aTotemBar:SetClampedToScreen(true)
		aTotemBar:SetSize(190 + (spacing * 5), 38)
		aTotemBar:SetPoint("CENTER")

		aTotemBar.bg = aTotemBar:CreateTexture(nil, "BACKGROUND")
		aTotemBar.bg:SetTexture(0.2, 0.3, 0.4, 0.85)
		aTotemBar.bg:SetAllPoints(aTotemBar)
		aTotemBar.bg:Hide()

		-- add functions
		aTotemBar.Lock = Dominos_TotemBar_Lock
		aTotemBar.Unlock = Dominos_TotemBar_Unlock
		aTotemBar.SavePosition = Dominos_TotemBar_SavePosition
		aTotemBar.RestorePosition = Dominos_TotemBar_RestorePosition

		MultiCastActionBarFrame:SetParent(aTotemBar)
		MultiCastActionBarFrame:SetWidth(0.01)

		MultiCastSummonSpellButton:SetParent(aTotemBar)
		MultiCastSummonSpellButton:ClearAllPoints()
		MultiCastSummonSpellButton:SetPoint("BOTTOMLEFT", aTotemBar, 5, 5)

		for i = 1, 4 do
			_G["MultiCastSlotButton" .. i]:SetParent(aTotemBar)
		end

		MultiCastSlotButton1:ClearAllPoints()
		MultiCastSlotButton1:SetPoint("LEFT", MultiCastSummonSpellButton, "RIGHT", spacing, 0)

		for i = 2, 4 do
			local b = _G["MultiCastSlotButton" .. i]
			local b2 = _G["MultiCastSlotButton" .. i - 1]
			b:ClearAllPoints()
			b:SetPoint("LEFT", b2, "RIGHT", spacing, 0)
		end

		MultiCastRecallSpellButton:ClearAllPoints()
		MultiCastRecallSpellButton:SetPoint("LEFT", MultiCastSlotButton4, "RIGHT", spacing, 0)

		for i = 1, 12 do
			local b = _G["MultiCastActionButton" .. i]
			local b2 = _G["MultiCastSlotButton" .. (i % 4 == 0 and 4 or i % 4)]
			b:ClearAllPoints()
			b:SetPoint("CENTER", b2, "CENTER", 0, 0)
		end

		for i = 1, 4 do
			local b = _G["MultiCastSlotButton" .. i]
			b.SetParent = Multibar_EmptyFunc
			b.SetPoint = Multibar_EmptyFunc
		end
		MultiCastRecallSpellButton.SetParent = Multibar_EmptyFunc
		MultiCastRecallSpellButton.SetPoint = Multibar_EmptyFunc

		TotemTimers[1] = CreateFrame("Cooldown", "TotemTimers1", MultiCastSlotButton2)
		TotemTimers[2] = CreateFrame("Cooldown", "TotemTimers2", MultiCastSlotButton1)
		TotemTimers[3] = CreateFrame("Cooldown", "TotemTimers3", MultiCastSlotButton3)
		TotemTimers[4] = CreateFrame("Cooldown", "TotemTimers4", MultiCastSlotButton4)
		TotemTimers[1]:SetAllPoints(MultiCastSlotButton2)
		TotemTimers[2]:SetAllPoints(MultiCastSlotButton1)
		TotemTimers[3]:SetAllPoints(MultiCastSlotButton3)
		TotemTimers[4]:SetAllPoints(MultiCastSlotButton4)

		aTotemBar:RegisterEvent("PLAYER_ENTERING_WORLD")
		aTotemBar:RegisterEvent("PLAYER_TOTEM_UPDATE")
		aTotemBar:SetScript("OnEvent", function(self, event, ...)
			if event == "PLAYER_ENTERING_WORLD" then
				aTotemBar_PLAYER_ENTERING_WORLD(self)
			elseif event == "PLAYER_TOTEM_UPDATE" then
				Dominos_aTotemBar_Update(select(1, ...))
			end
		end)

		aTotemBar:SetScript("OnMouseDown", function() aTotemBar:StartMoving() end)
		aTotemBar:SetScript("OnMouseUp", function() aTotemBar:StopMovingOrSizing() end)

		Dominos.aTotemBar = aTotemBar
		aTotemBar_PLAYER_ENTERING_WORLD(aTotemBar)
	end

	function Dominos_aTotemBar_Destroy(self, button)
		if button ~= "RightButton" then
			return
		elseif
			self:GetName() == "MultiCastActionButton1" or
			self:GetName() == "MultiCastActionButton5" or
			self:GetName() == "MultiCastActionButton9"
		then
			DestroyTotem(2)
		elseif
			self:GetName() == "MultiCastActionButton2" or
			self:GetName() == "MultiCastActionButton6" or
			self:GetName() == "MultiCastActionButton10"
		then
			DestroyTotem(1)
		elseif
			self:GetName() == "MultiCastActionButton3" or
			self:GetName() == "MultiCastActionButton7" or
			self:GetName() == "MultiCastActionButton11"
		then
			DestroyTotem(3)
		elseif
			self:GetName() == "MultiCastActionButton4" or
			self:GetName() == "MultiCastActionButton8" or
			self:GetName() == "MultiCastActionButton12"
		then
			DestroyTotem(4)
		end
	end

	for i = 1, 12 do
		local hooker = _G["MultiCastActionButton" .. i]
		if hooker then
			hooker:HookScript("OnClick", Dominos_aTotemBar_Destroy)
		end
	end

	function Dominos_aTotemBar_Update(totemN)
		if BlizzardTimers == false then
			TotemFrame:Hide()
		end
		if aTotemBarTimers == true then
			local haveTotem, _, startTime, duration = GetTotemInfo(totemN)
			if duration and (duration == 0) then
				TotemTimers[totemN]:SetCooldown(0, 0)
			else
				TotemTimers[totemN]:SetCooldown(startTime, duration)
			end
		end
	end

	function DTB:OnEnable()
		if Dominos.db then
			if not Dominos.db.profile.totemBar then
				Dominos.db.profile.totemBar = defaults
			end
			db = Dominos.db.profile.totemBar
		end

		if aTotemBar then
			aTotemBar:SetScale(db.Scale)
			aTotemBar:RestorePosition()
		end
	end

	-- 备用实现：启用 aTotemBar（接管暴雪原生 MultiCast 图腾条）
	function DTB:LoadAltTotemBars()
		SetupTotemBar()
		Dominos:Delay(0.25, aTotemBar_PLAYER_ENTERING_WORLD, aTotemBar)
	end
end