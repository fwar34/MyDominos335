--[[
	MyDominos335（内部标识仍为 Dominos）—— 背包条模块 bagBar.lua

	负责背包条：复用暴雪原生背包按钮 MainMenuBarBackpackButton 与 CharacterBag0..3Slot，
	并自建钥匙链按钮 DominosKeyringButton（暴雪未提供可复用的钥匙链按钮）。支持两种选项：
	“单背包模式”（oneBag，只显示主背包按钮）与显示/隐藏钥匙链。

	关键依赖：
		- Dominos:Masque("Bag Bar", ...)：皮肤（见 SkinButton）
		- 使用暴雪 ItemButtonTemplate 创建钥匙链按钮

	注意事项：
		- 内部标识仍为 Dominos：右键菜单文本取自语言键 "Dominos-Config"。
		- 面向 3.3.5a（Interface 30300）旧 API（PutKeyInKeyRing / ToggleKeyRing / KEYRING 等全局函数）。
--]]

assert(Dominos, "Dominos not found!")
local Dominos = Dominos

local NT_RATIO = 64 / 37
local _G = _G

--load up the bag set...
local bags = {}
do
	-- 统一调整物品按钮尺寸，并同步“数量/存量”字串的字体与位置
	local function ResizeItemButton(b, size)
		b:SetWidth(size)
		b:SetHeight(size)
		b:GetNormalTexture():SetWidth(size * NT_RATIO)
		b:GetNormalTexture():SetHeight(size * NT_RATIO)

		local count = _G[b:GetName() .. "Count"]
		count:SetFontObject("NumberFontNormalSmall")
		count:SetPoint("BOTTOMRIGHT", 0, 2)

		_G[b:GetName() .. "Stock"]:SetFontObject("NumberFontNormalSmall")
		_G[b:GetName() .. "Stock"]:SetVertexColor(1, 1, 0)
	end

	-- 自建钥匙链按钮：点击/拖入时把光标物品放入钥匙链，否则开关钥匙链界面，并带 KEYRING 提示
	local function CreateKeyRing(name)
		local b = CreateFrame("CheckButton", name, UIParent, "ItemButtonTemplate")
		b:RegisterForClicks("anyUp")
		b:Hide()

		b:SetScript("OnClick", function()
			if CursorHasItem() then
				PutKeyInKeyRing()
			else
				ToggleKeyRing()
			end
		end)

		b:SetScript("OnReceiveDrag", function()
			if CursorHasItem() then
				PutKeyInKeyRing()
			end
		end)

		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")

			local color = HIGHLIGHT_FONT_COLOR
			GameTooltip:SetText(KEYRING, color.r, color.g, color.b)
			GameTooltip:AddLine()
		end)

		b:SetScript("OnLeave", function() GameTooltip:Hide() end)

		_G[b:GetName() .. "IconTexture"]:SetTexture("Interface\\ContainerFrame\\KeyRing-Bag-Icon")
		_G[b:GetName() .. "IconTexture"]:SetTexCoord(0, 0.9, 0.1, 1)

		ResizeItemButton(b, 30)
	end

	CreateKeyRing("DominosKeyringButton")
	ResizeItemButton(_G["MainMenuBarBackpackButton"], 30)
end

--[[ Bag Bar ]]--
-- 背包条类：继承 core 的 Dominos.Frame；按钮集合在 Reload 时构建于 self.bags 表中。
local BagBar = Dominos:CreateClass("Frame", Dominos.Frame)
Dominos.BagBar = BagBar

function BagBar:New()
	local f = self.super.New(self, "bags")
	f:Reload()

	return f
end

function BagBar:SkinButton(b)
	return Dominos:Masque("Bag Bar", b)
end

function BagBar:GetDefaults()
	return {point = "BOTTOMRIGHT", spacing = 2}
end

-- 设置“单背包模式”：仅保留主背包按钮，随后重载按钮集合
function BagBar:SetSetOneBag(enable)
	self.sets.oneBag = enable or nil
	self:Reload()
end

-- 设置是否显示钥匙链按钮（写入 hideKeyring 标志后重载）
function BagBar:SetShowKeyring(enable)
	if enable then
		self.sets.hideKeyring = nil
	else
		self.sets.hideKeyring = true
	end
	self:Reload()
end

-- 依据当前选项重建按钮集合顺序：钥匙链（未隐藏）→ 四个背包槽（非单背包模式）→ 主背包，最后同步按钮数
function BagBar:Reload()
	if not self.bags then
		self.bags = {}
	else
		for i = 1, #self.bags do
			self.bags[i] = nil
		end
	end

	if not self.sets.hideKeyring then
		table.insert(self.bags, _G["DominosKeyringButton"])
	end

	if not self.sets.oneBag then
		table.insert(self.bags, _G["CharacterBag3Slot"])
		table.insert(self.bags, _G["CharacterBag2Slot"])
		table.insert(self.bags, _G["CharacterBag1Slot"])
		table.insert(self.bags, _G["CharacterBag0Slot"])
	end

	table.insert(self.bags, _G["MainMenuBarBackpackButton"])

	self:SetNumButtons(#self.bags)
end

--[[ Frame Overrides ]]--
-- 复用 bags 表中的暴雪按钮：挂到 header、显示、套用皮肤，并记入 buttons
function BagBar:AddButton(i)
	local b = self.bags[i]
	b:SetParent(self.header)
	b:Show()
	self:SkinButton(b)

	self.buttons[i] = b
end

function BagBar:RemoveButton(i)
	local b = self.buttons[i]
	if b then
		b:SetParent(nil)
		b:Hide()
		self.buttons[i] = nil
	end
end

-- 按新数量先移除全部旧按钮，再按顺序重新添加
function BagBar:UpdateButtonCount(numButtons)
	for i = 1, #self.buttons do
		self:RemoveButton(i)
	end

	for i = 1, numButtons do
		self:AddButton(i)
	end
end

function BagBar:NumButtons()
	return #self.bags
end

-- 构建右键菜单：布局面板 + “单背包”“显示钥匙链”两个复选框 + 高级面板
function BagBar:CreateMenu()
	local menu = self.menu or Dominos:NewMenu(self.id)
	local panel = menu:AddLayoutPanel()
	local L = LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")

	--add onebag and showkeyring options
	local oneBag = panel:NewCheckButton(L.OneBag)
	oneBag:SetScript("OnShow", function()
		oneBag:SetChecked(self.sets.oneBag)
	end)
	oneBag:SetScript("OnClick", function()
		self:SetSetOneBag(oneBag:GetChecked())
		_G[panel:GetName() .. L.Columns]:OnShow()
	end)

	local showKeyring = panel:NewCheckButton(L.ShowKeyring)
	showKeyring:SetScript("OnShow", function()
		showKeyring:SetChecked(not self.sets.hideKeyring)
	end)
	showKeyring:SetScript("OnClick", function()
		self:SetShowKeyring(showKeyring:GetChecked())
		_G[panel:GetName() .. L.Columns]:OnShow()
	end)

	menu:AddAdvancedPanel()
	self.menu = menu
end