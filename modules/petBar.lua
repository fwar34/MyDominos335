--[[
	MyDominos335（内部标识仍为 Dominos）—— 宠物动作条模块 petBar.lua

	负责宠物动作条：直接复用暴雪原生按钮 PetActionButton1..NUM_PET_ACTION_SLOTS，
	不新建按钮。条本身继承 core 的 Dominos.Frame，按钮继承 Dominos.BindableButton。

	关键依赖：
		- Dominos:Masque("Pet Bar", ...)：皮肤；不可用时回退 Dominos 自带外观（PetButton:Skin）
		- LibKeyBound-1.0：悬停高亮并显示按键绑定
		- hooksecurefunc 挂接暴雪的 PetActionBar_UpdateCooldowns / PetActionButton_SetHotkeys

	注意事项：
		- 内部标识仍为 Dominos：语言键仍是 "Dominos"。
		- 面向 3.3.5a（Interface 30300）旧 API，使用 NUM_PET_ACTION_SLOTS、PetHasActionBar、
		  GetPetActionInfo 等，无现代 C_ 系列接口。
--]]

assert(Dominos, "Dominos not found!")
local Dominos = Dominos

local _G = _G
local format = string.format

local KeyBound = LibStub("LibKeyBound-1.0")
local unused, hooked

--[[ Pet Button ]]
-- 宠物动作条按钮类：继承 Dominos.BindableButton，直接复用暴雪原生 PetActionButtonXX。
local PetButton = Dominos:CreateClass("CheckButton", Dominos.BindableButton)

local function Dominos_RestoreSaturation(self, icon)
	if icon and icon:IsDesaturated() then
		icon:SetDesaturated(false)
	end
end

-- 挂钩暴雪冷却刷新：仅当冷却时长 >= 2.01 秒时才做去饱和（变灰）转圈效果，避免短 GCD 误触发；
-- 通过 Dominos:Delay 在冷却结束附近恢复图标饱和度。
local function Dominos_PetActionBar_UpdateCooldowns(self)
	for i = 1, NUM_PET_ACTION_SLOTS, 1 do
		local icon = _G["PetActionButton" .. i .. "Icon"]
		if icon then
			local start, duration = GetPetActionCooldown(i)
			if duration and duration >= 2.01 then
				local nextTime = math.ceil(start + duration - GetTime())
				Dominos:Delay(math.min(duration, nextTime), Dominos_RestoreSaturation, self, icon)

				if not icon:IsDesaturated() then
					icon:SetDesaturated(true)
				end
			else
				Dominos_RestoreSaturation(self)
			end
		end
	end
end

-- 取得按钮：复用空闲池或新建，刷新热键；首次调用时挂接暴雪的冷却更新函数（hooked 保证只挂一次）。
function PetButton:New(id)
	local b = self:Restore(id) or self:Create(id)
	b:UpdateHotkey()

	if not hooked then
		hooksecurefunc("PetActionBar_UpdateCooldowns", Dominos_PetActionBar_UpdateCooldowns)
		hooked = true
	end

	return b
end

-- 绑定暴雪原生 PetActionButtonXX，并标记 buttonType（暴雪默认显示为 BONUSACTIONBUTTON 键位）。
function PetButton:Create(id)
	local b = self:Bind(_G["PetActionButton" .. id])
	b.buttonType = "BONUSACTIONBUTTON"
	b:SetScript("OnEnter", self.OnEnter)
	b:Skin()

	return b
end

--if we have button facade support, then skin the button that way
--otherwise, apply the dominos style to the button to make it pretty
function PetButton:Skin()
	if not Dominos:Masque("Pet Bar", self) then
		_G[self:GetName() .. "Icon"]:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		self:GetNormalTexture():SetVertexColor(1, 1, 1, 0.5)
	end
end

function PetButton:Restore(id)
	local b = unused and unused[id]
	if b then
		unused[id] = nil
		b:Show()

		return b
	end
end

--saving them thar memories
function PetButton:Free()
	if not unused then
		unused = {}
	end
	unused[self:GetID()] = self

	self:SetParent(nil)
	self:Hide()
end

--keybound support
function PetButton:OnEnter()
	if Dominos:ShowTooltips() then
		PetActionButton_OnEnter(self)
	end
	KeyBound:Set(self)
end

--override keybinding display
hooksecurefunc("PetActionButton_SetHotkeys", PetButton.UpdateHotkey)

--[[ Pet Bar ]]
-- 宠物条类：继承 core 的 Dominos.Frame；按钮数固定为 NUM_PET_ACTION_SLOTS。
local PetBar = Dominos:CreateClass("Frame", Dominos.Frame)
Dominos.PetBar = PetBar

function PetBar:New()
	local f = self.super.New(self, "pet")
	f:LoadButtons()
	f:Layout()

	return f
end

-- 宠物条显隐条件：存在可控宠物、且不在载具（bonusbar:5）时显示，否则隐藏
function PetBar:GetShowStates()
	return "[target=pet,exists,nobonusbar:5]show;hide"
end

function PetBar:GetDefaults()
	return {point = "CENTER", x = 0, y = -32, spacing = 6}
end

--dominos frame method overrides
function PetBar:NumButtons()
	return NUM_PET_ACTION_SLOTS
end

function PetBar:AddButton(i)
	local b = PetButton:New(i)
	b:SetParent(self.header)
	self.buttons[i] = b
end

function PetBar:RemoveButton(i)
	local b = self.buttons[i]
	self.buttons[i] = nil
	b:Free()
end

--[[ keybound  support ]]
-- 进入按键绑定模式：强制显示宠物条并显示所有按钮，便于玩家查看/设置绑定
function PetBar:KEYBOUND_ENABLED()
	self.header:SetAttribute("state-visibility", "display")

	for _, button in pairs(self.buttons) do
		button:Show()
	end
end

-- 退出按键绑定模式：恢复默认显隐状态，并按“是否有宠物 / 该槽位是否有宠物动作”逐钮显示或隐藏
function PetBar:KEYBOUND_DISABLED()
	self:UpdateShowStates()

	local petBarShown = PetHasActionBar()
	for _, button in pairs(self.buttons) do
		if petBarShown and GetPetActionInfo(button:GetID()) then
			button:Show()
		else
			button:Hide()
		end
	end
end