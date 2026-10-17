--[[
spellButton.lua
A dominos spell button
]] --
--[[
	中文说明：本文件为图腾条的技能按钮 spellButton.lua
	职责：定义 Dominos.SpellButton 类（继承 Dominos.BindableButton），供图腾条上的法术按钮使用；
	     通过 active/unused 两个表组成对象池，复用而非反复创建按钮。
	关键依赖：Dominos（CreateClass、BindableButton、Masque 皮肤、ActionButton 体系）、
	     Blizzard 的 SecureActionButtonTemplate/ActionButtonTemplate、LibKeyBound-1.0（悬停时绑定快捷键）、
	     IsSpellKnown/GetSpellCooldown/IsUsableSpell/IsSpellInRange 等旧 API（客户端 Interface 30300）。
	被谁使用：由 modules/totemBar/totemBar.xml 先于 totemBar.lua 加载，供 totemBar.lua 的 CreateSpellButton 调用。
	注意：插件对外名已改为 MyDominos335，但内部标识仍为 Dominos——全局类 Dominos.SpellButton、
	     动态框架全局名 DominosSpellButton%d 均未随插件改名。
--]]
--dont create the spell button object class if it already exists
assert(Dominos, "Dominos not found!")
local Dominos = Dominos
if Dominos.SpellButton then return end

local SpellButton = Dominos:CreateClass("CheckButton", Dominos.BindableButton)
Dominos.SpellButton = SpellButton

--lists of active and unused spell buttons
-- 对象池：active 保存正在使用的按钮，unused 保存空闲可复用的按钮
SpellButton.active = {}
SpellButton.unused = {}

--[[ Constructor ]]
function SpellButton:New(spellID)
	local b = self:Restore() or self:Create()
	b:SetSpell(spellID)
	b:UpdateHotkey()

	return b
end

function SpellButton:Create()
	local b = self:Bind(CreateFrame(
		"CheckButton",
		string.format("DominosSpellButton%d", self:GetNextID()),
		nil,
		"SecureActionButtonTemplate, ActionButtonTemplate"
	))
	b:SetAttribute("type", "spell")

	b:ClearAllPoints()
	b:EnableMouseWheel(true)
	b:Skin()
	b:SetScript("OnEvent", b.OnEvent)
	b:SetScript("OnEnter", b.OnEnter)
	b:SetScript("OnLeave", b.OnLeave)
	b:SetScript("OnShow", b.OnShow)
	b:SetScript("OnHide", b.OnHide)
	b:SetScript("PostClick", b.PostClick)

	return b
end

do
	local id = 1
	function SpellButton:GetNextID()
		local result = id
		id = id + 1
		return result
	end
end

-- 从空闲池取出一个可复用按钮（无则返回 nil，由调用方再创建）
function SpellButton:Restore()
	local b = next(self.unused)
	if b then
		self.unused[b] = nil
		b:Show()
		self.active[b] = true
	end
	return b
end

function SpellButton:Skin()
	if not Dominos:Masque("Action Bar", self) then
		_G[self:GetName() .. "Icon"]:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		self:GetNormalTexture():SetVertexColor(1, 1, 1, 0.5)
	end
end

--[[ Destructor ]]
-- 回收按钮：注销事件、脱离父级并隐藏后放回空闲池
function SpellButton:Free()
	self.active[self] = nil

	self:UnregisterAllEvents()
	self:SetParent(nil)
	self:Hide()

	self.unused[self] = true
end

--[[ Frame Events ]]
function SpellButton:PostClick()
	self:UpdateState()
end

function SpellButton:OnShow()
	self:UpdateEvents()
	self:UpdateSpell()
	self.elapsed = -1
end

function SpellButton:OnHide()
	self:UpdateEvents()
end

function SpellButton:OnEnter()
	local spell = self:GetSpell()
	if spell then
		if GetCVar("UberTooltips") == "1" then
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
		GameTooltip:SetHyperlink(GetSpellLink(spell))
	end
	LibStub("LibKeyBound-1.0"):Set(self)
end

function SpellButton:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

--TODO: make this better
function SpellButton:OnUpdate(elapsed)
	self.elapsed = (self.elapsed or 0.1) - elapsed
	if self.elapsed < 0 then
		self.elapsed = 0.1
		self:UpdateColor()
	end
end

-- 事件分发：把事件转发给同名方法处理（如 SPELL_UPDATE_COOLDOWN）
function SpellButton:OnEvent(event, ...)
	local action = self[event]
	if action then
		action(self, event, ...)
	end
end

--[[ Events ]]
function SpellButton:PLAYER_ENTERING_WORLD()
	self:UpdateSpell()
	self:UpdateEvents()
end

function SpellButton:SPELLS_CHANGED()
	self:UpdateSpell()
	self:UpdateEvents()
end

function SpellButton:SPELL_UPDATE_COOLDOWN()
	self:UpdateCooldown()
	self:UpdateState()
end

function SpellButton:SPELL_UPDATE_USABLE()
	self:UpdateColor()
	self:UpdateState()
end

function SpellButton:UPDATE_SHAPESHIFT_FORM()
	self:UpdateSpell()
end

function SpellButton:UPDATE_BINDINGS()
	self:UpdateHotkey()
end

function SpellButton:START_AUTOREPEAT_SPELL()
	self:UpdateState()
end

function SpellButton:STOP_AUTOREPEAT_SPELL()
	self:UpdateState()
end

function SpellButton:CURRENT_SPELL_CAST_CHANGED()
	self:UpdateState()
end

--[[ Update Methods ]]
function SpellButton:UpdateCooldown()
	if not self:IsVisible() then
		return
	end

	local spellName, spellID = self:GetSpell()
	local cooldown = _G[self:GetName() .. "Cooldown"]

	if spellID and IsSpellKnown(spellID) then
		local start, duration, enable = GetSpellCooldown(spellID)
		CooldownFrame_SetTimer(cooldown, start, duration, enable)
	else
		cooldown:Hide()
	end
end

function SpellButton:UpdateColor()
	if not self:IsVisible() then
		return
	end

	local spell = self:GetSpell()
	local icon = _G[self:GetName() .. "Icon"]
	local normalTexture = _G[self:GetName() .. "NormalTexture"]

	if spell then
		local isUsable, notEnoughMana = IsUsableSpell(spell)

		if isUsable then
			--out of range coloring
			if SpellHasRange(spell) and IsSpellInRange(spell) == 0 then
				icon:SetVertexColor(0.8, 0.1, 0.1)
				normalTexture:SetVertexColor(0.8, 0.1, 0.1)
			else
				icon:SetVertexColor(1, 1, 1)
				normalTexture:SetVertexColor(1, 1, 1)
			end
		elseif notEnoughMana then
			icon:SetVertexColor(0.5, 0.5, 1)
			normalTexture:SetVertexColor(0.5, 0.5, 1)
		else
			icon:SetVertexColor(0.4, 0.4, 0.4)
			normalTexture:SetVertexColor(1, 1, 1)
		end
	else
		normalTexture:SetVertexColor(1, 1, 1)
	end
end

-- 事件更新：按可见性与是否存在法术，注册/注销相应事件与 OnUpdate
function SpellButton:UpdateEvents()
	self:UnregisterAllEvents()

	if self:IsVisible() then
		if self:GetSpell() then
			self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
			self:RegisterEvent("SPELL_UPDATE_USABLE")
			self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
			self:RegisterEvent("START_AUTOREPEAT_SPELL")
			self:RegisterEvent("STOP_AUTOREPEAT_SPELL")
			self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")

			self:SetScript("OnUpdate", self.OnUpdate)
		else
			self:SetScript("OnUpdate", nil)
		end

		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("UPDATE_BINDINGS")
	end
end

function SpellButton:UpdateSpell()
	if not self:IsVisible() then
		return
	end

	local spell = self:GetSpell()
	local icon = spell and GetSpellTexture(spell)
	if icon then
		_G[self:GetName() .. "Icon"]:SetTexture(icon)
		_G[self:GetName() .. "Icon"]:Show()
		_G[self:GetName() .. "HotKey"]:Show()

		self:SetNormalTexture([[Interface\Buttons\UI-Quickslot2]])
	else
		_G[self:GetName() .. "Icon"]:Hide()
		_G[self:GetName() .. "HotKey"]:Hide()
		self:SetNormalTexture([[Interface\Buttons\UI-Quickslot]])
	end

	self:UpdateCooldown()
	self:UpdateColor()
	self:UpdateState()
end

function SpellButton:UpdateState()
	local spell = self:GetSpell()
	if spell then
		self:SetChecked(IsCurrentSpell(spell) or IsAutoRepeatSpell(spell))
	else
		self:SetChecked(false)
	end
end

--[[ Spell Property Accessish ]]
local function getProperSpellName(id)
	local name, rank = GetSpellInfo(id)
	if name and rank and rank ~= "" then
		return string.format("%s(%s)", name, rank)
	end
	return name
end

function SpellButton:SetSpell(id)
	self:SetAttribute("spell", getProperSpellName(id))
	self.spellID = id

	if self:IsVisible() then
		self:UpdateSpell()
		self:UpdateEvents()
	end
end

function SpellButton:GetSpell()
	return self:GetAttribute("spell"), self.spellID
end

function SpellButton:GetSpellInfo()
	local spellName = self:GetSpell()
	if spellName then
		return GetSpellInfo(spellName)
	end
	return nil
end