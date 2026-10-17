--[[
	MyDominos335（内部标识仍为 Dominos）—— 职业/形态条模块 classBar.lua

	负责“职业条”：显示德鲁伊/战士/牧师/盗贼/术士等职业的形态或变身按钮。暴雪没有可
	直接复用的独立形态按钮，故本模块自行创建 DominosClassButton1..N，并借助
	GetNumShapeshiftForms / GetShapeshiftFormInfo / GetShapeshiftFormCooldown 驱动。
	条继承 core 的 Dominos.Frame，按钮继承 Dominos.BindableButton。

	关键依赖：
		- Dominos:Masque("Class Bar", ...)：皮肤；不可用时回退 Dominos 自带外观（ClassButton:Skin）
		- LibKeyBound-1.0：悬停高亮并显示按键绑定

	注意事项：
		- 内部标识仍为 Dominos。
		- 面向 3.3.5a（Interface 30300）旧 API（UPDATE_SHAPESHIFT_FORMS 等），
		  无现代 C_ 系列接口。
--]]

assert(Dominos, "Dominos not found!")
local Dominos = Dominos

--libs and omgspeed
local _G = _G
local format = string.format

local BUTTON_SIZE = 30
local NT_SIZE = (66 / 36) * BUTTON_SIZE
local KeyBound = LibStub("LibKeyBound-1.0")

--[[ Class Button ]]
-- 职业/形态按钮类：继承 Dominos.BindableButton；因无暴雪按钮可复用，故完全自建。
local ClassButton = Dominos:CreateClass("CheckButton", Dominos.BindableButton)

--[[ Constructor ]]
function ClassButton:New(id)
	return self:Restore(id) or self:Create(id)
end

-- 自建形态按钮：装配图标/普通/按下/高亮/选中贴图、热键字串与冷却框，
-- 设为 "spell" 安全属性按钮（点击即施放对应形态法术），并绑定各回调。
function ClassButton:Create(id)
	local name = format("DominosClassButton%d", id)

	local b = self:Bind(CreateFrame("CheckButton", name, nil, "SecureActionButtonTemplate"))
	b:SetWidth(BUTTON_SIZE)
	b:SetHeight(BUTTON_SIZE)
	b:SetID(id)

	b.icon = b:CreateTexture(name .. "Icon", "BACKGROUND")
	b.icon:SetAllPoints(b)

	b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")

	local nt = b:GetNormalTexture()
	nt:ClearAllPoints()
	nt:SetPoint("CENTER", 0, -1)
	nt:SetWidth(NT_SIZE)
	nt:SetHeight(NT_SIZE)
	_G[name .. "NormalTexture"] = nt

	b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")

	b.hotkey = b:CreateFontString(name .. "HotKey", "ARTWORK")
	b.hotkey:SetFontObject("NumberFontNormalSmallGray")
	b.hotkey:SetPoint("TOPRIGHT", 2, -2)
	b.hotkey:SetJustifyH("RIGHT")
	b.hotkey:SetWidth(BUTTON_SIZE)
	b.hotkey:SetHeight(10)

	b.cooldown = CreateFrame("Cooldown", name .. "Cooldown", b, "CooldownFrameTemplate")
	b.cooldown:SetAllPoints(b)

	b:SetAttribute("type", "spell")
	b:SetScript("PostClick", b.PostClick)
	b:SetScript("OnEvent", b.OnEvent)
	b:SetScript("OnEnter", b.OnEnter)
	b:SetScript("OnLeave", b.OnLeave)
	b:SetScript("OnShow", b.UpdateEvents)
	b:SetScript("OnHide", b.UpdateEvents)

	b:UpdateSpell()
	b:UpdateEvents()
	b:UpdateHotkey()
	b:Skin()

	return b
end

function ClassButton:Skin()
	if not Dominos:Masque("Class Bar", self) then
		self.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		self:GetNormalTexture():SetVertexColor(1, 1, 1, 0.5)
	end
end

function ClassButton:Restore(id)
	local unused = self.unused
	if unused then
		local b = unused[id]
		if b then
			unused[id] = nil
			b:Show()
			return b
		end
	end
end

function ClassButton:Free()
	local unused = ClassButton.unused or {}
	unused[self:GetID()] = self
	ClassButton.unused = unused

	self:SetParent(nil)
	self:Hide()
end

--[[ Frame Events ]]
-- 仅当按钮可见时注册相关事件，隐藏时全部注销，避免无谓刷新。
function ClassButton:UpdateEvents()
	if self:IsShown() then
		self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("SPELL_UPDATE_USABLE")
		self:RegisterEvent("UNIT_AURA")
		self:RegisterEvent("UPDATE_BINDINGS")
	else
		self:UnregisterAllEvents()
	end
end

-- 事件分发：按键绑定变化→刷新热键；形态数量变化且本钮超出→隐藏；自身光环变化→刷新；其余→刷新
function ClassButton:OnEvent(event, arg1)
	if event == "UPDATE_BINDINGS" then
		self:UpdateHotkey()
	elseif event == "UPDATE_SHAPESHIFT_FORMS" and (self:GetID() > GetNumShapeshiftForms()) then
		self:Hide()
	elseif event == "UNIT_AURA" then
		if arg1 == "player" then
			self:Update()
		end
	else
		self:Update()
	end
end

function ClassButton:OnEnter()
	if Dominos:ShowTooltips() then
		if GetCVar("UberTooltips") == "1" then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
		GameTooltip:SetShapeshift(self:GetID())
	end
	KeyBound:Set(self)
end

function ClassButton:OnLeave()
	GameTooltip:Hide()
end

function ClassButton:PostClick()
	self:SetChecked(not self:GetChecked())
end

--[[ Update Functions ]]
-- 刷新按钮：读取形态信息设置选中态、图标与可用颜色，并刷新形态冷却转圈。
function ClassButton:Update()
	local texture, name, isActive, isCastable = GetShapeshiftFormInfo(self:GetID())
	self:SetChecked(isActive)

	--update icon
	local icon = self.icon
	icon:SetTexture(texture)
	if isCastable then
		icon:SetVertexColor(1, 1, 1)
	else
		icon:SetVertexColor(0.4, 0.4, 0.4)
	end

	--update cooldown
	if texture then
		local start, duration, enable = GetShapeshiftFormCooldown(self:GetID())
		CooldownFrame_SetTimer(self.cooldown, start, duration, enable)
	else
		self.cooldown:Hide()
	end
end

-- 将本槽形态对应的法术名写入安全属性 "spell"，供安全模板按钮点击时施放；随后刷新显示。
function ClassButton:UpdateSpell()
	self:SetAttribute("spell", select(2, GetShapeshiftFormInfo(self:GetID())))
	self:Update()
end

--[[ Class Bar ]]
-- 职业条类：继承 core 的 Dominos.Frame，并监听 UPDATE_SHAPESHIFT_FORMS 以在形态变化时重建。
local ClassBar = Dominos:CreateClass("Frame", Dominos.Frame)
Dominos.ClassBar = ClassBar

function ClassBar:New()
	local f = self.super.New(self, "class")
	f:SetScript("OnEvent", f.UpdateForms)
	f:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	f:UpdateForms()

	return f
end

function ClassBar:GetDefaults()
	return {point = "CENTER", spacing = 2}
end

function ClassBar:Free()
	self:UnregisterAllEvents()
	self.super.Free(self)
end

--[[ button stuff]]
function ClassBar:LoadButtons()
	self:UpdateForms()
end

function ClassBar:AddButton(i)
	local b = ClassButton:New(i)
	b:SetParent(self.header)
	self.buttons[i] = b

	return b
end

function ClassBar:RemoveButton(i)
	local b = self.buttons[i]
	self.buttons[i] = nil
	b:Free()
end

-- 按当前可用形态数量增补/刷新按钮并显示，最后同步本条的按钮数
function ClassBar:UpdateForms()
	for i = 1, GetNumShapeshiftForms() do
		local b = self.buttons[i] or self:AddButton(i)
		b:UpdateSpell()
		b:Show()
	end
	self:SetNumButtons(GetNumShapeshiftForms() or 0)
end