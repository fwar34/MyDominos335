--[[--------------------------------------------------------------------
minimapBar.lua —— 小地图模块（模块注册名："minimap"）

职责：
	把暴雪小地图(Minimap)从其原生父框架中取出，改挂到本模块自建的
	全局框架 "MinimapBar" 上，使整个小地图区域可被 Dominos 自由摆放与缩放；
	同时接管小地图周围的一批暴雪子控件（追踪、日历、副本难度、随机组队眼睛等），
	作为本框架的按钮统一布局。

模块注册名：Dominos:NewModule("minimap")
	说明：插件对外名为 MyDominos335，但内部标识仍沿用经典 Dominos，
	故全局表仍为 Dominos、存档仍为 DominosDB。

依赖与前置条件（OnInitialize）：
	需要 Dominos:UseMinimap() 为真；否则 self:Disable() 停用且不做任何接管。

注意事项：
	面向 3.3.5a（Interface 30300）旧 API，不使用 C_Timer 等现代接口。
]]--
assert(Dominos, "Dominos not found!")
local Dominos = Dominos
local L

-- used to kill old function
local function noFunc() return end
-- killFrame 用于“冻结”某个暴雪子框架：把 SetParent / ClearAllPoints / SetPoint /
-- SetFrameStrata 覆盖为空函数，使暴雪后续代码无法再重新定位该框架，
-- 从而保留我们手动设置的锚点（下方 MiniMapInstanceDifficulty / MiniMapLFGFrame 会用到）。
local function killFrame(frame)
	if frame then
		frame.SetParent = noFunc
		frame.ClearAllPoints = noFunc
		frame.SetPoint = noFunc
		frame.SetFrameStrata = noFunc
	end
end

-- 自建框架：以暴雪 MinimapClusterBar 为父创建全局框架 "MinimapBar"，
-- 之后 Minimap 与相关子控件都会改挂到这里。
local minimapBar = CreateFrame("Frame", "MinimapBar", _G.MinimapClusterBar)

local select = select

local mod = Dominos:NewModule("minimap")
local class = Dominos:CreateClass("Frame", Dominos.Frame)

local menuButtons = {}
do
	local loadButtons = function(...)
		for i = 1, select("#", ...) do
			local btn = select(i, ...)
			tinsert(menuButtons, btn)
		end
	end

	-- 初始化：仅在 Dominos:UseMinimap() 为真时接管。
	-- 把暴雪小地图边框/背景交给主菜单栏美术框架，将 Minimap 改挂到 minimapBar，
	-- 并收集 minimapBar 的子控件作为可布局按钮；否则 Disable() 停用本模块。
	function mod:OnInitialize()
		if Dominos:UseMinimap() then
			MinimapBorderTop:SetParent(MainMenuBarArtFrame)
			MinimapBackdrop:SetParent(MainMenuBarArtFrame)
			Minimap:SetParent(minimapBar)
			loadButtons(minimapBar:GetChildren())
		else
			self:Disable()
		end
	end
end

-- 加载：给 Minimap 套用插件自带小地图背景纹理，创建可布局框架，
-- 并把副本难度图标与随机组队眼睛图标重新定位后用 killFrame 冻结，
-- 避免暴雪再次改写它们的位置；最后登记 DOMINOS_RESCALE 回调同步缩放。
function mod:Load()
	Minimap:SetBackdrop({
		bgFile = [[Interface\AddOns\MyDominos335\textures\minimap.blp]],
		insets = {top = -3, bottom = -2, left = -3, right = -2}
	})
	Minimap:SetBackdropColor(0, 0, 0, 1)

	self.frame = class:New()
	self.frame:SetFrameStrata("LOW")

	MiniMapInstanceDifficulty:ClearAllPoints()
	MiniMapInstanceDifficulty:SetPoint("TOPLEFT", Minimap)
	MiniMapInstanceDifficulty:SetFrameStrata("LOW")
	killFrame(MiniMapInstanceDifficulty)
	MiniMapInstanceDifficulty:SetScale(self.frame:GetScale() * 0.75)

	MiniMapLFGFrame:SetParent(minimapBar)
	MiniMapLFGFrame:ClearAllPoints()
	MiniMapLFGFrame:SetPoint("BOTTOMLEFT", Minimap)
	killFrame(MiniMapLFGFrame)
	MiniMapLFGFrame:SetScale(self.frame:GetScale() * 0.75)

	Dominos.RegisterCallback(self, "DOMINOS_RESCALE")
end

function mod:DOMINOS_RESCALE()
	MiniMapInstanceDifficulty:SetScale(self.frame:GetScale() * 0.75)
	MiniMapLFGFrame:SetScale(self.frame:GetScale() * 0.75)
end

function mod:Unload()
	if self.frame then
		self.frame:Free()
	end
end

-- 创建本模块的可布局框架实例（框架 id 为 "minimap"）。
function class:New()
	local f = self.super.New(self, "minimap")
	if not f.value then
		f:SetFrameStrata("BACKGROUND")
		f:LoadButtons()
	end
	f:Layout()
	return f
end

function class:GetDefaults()
	return {scale = 1, point = "TOPRIGHT", y = 0, x = 0}
end

function class:NumButtons()
	return #menuButtons
end

function class:AddButton(i)
	local btn = menuButtons[i]
	if not btn then return end
	btn:SetParent(self.header)
	btn:Show()
	self.buttons[i] = btn
end

function class:RemoveButton(i)
	local btn = self.buttons[i]
	if not btn then return end
	btn:SetParent(nil)
	btn:Hide()
	self.buttons[i] = nil
end

local function AddLayoutPanel(menu)
	local p = menu:NewPanel(L.Layout)
	p:NewPaddingSlider()
	p:NewOpacitySlider()
	p:NewFadeSlider()
	p:NewScaleSlider()
end

local function AddShowState(self)
	local p = self:NewPanel(L.ShowStates)
	p.height = 56

	local editBox = CreateFrame("EditBox", p:GetName() .. "StateText", p, "InputBoxTemplate")
	editBox:SetWidth(148)
	editBox:SetHeight(20)
	editBox:SetPoint("TOPLEFT", 12, -10)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnShow", function(self)
		self:SetText(self:GetParent().owner:GetShowStates() or "")
	end)
	editBox:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		self:GetParent().owner:SetShowStates(text ~= "" and text or nil)
	end)
	editBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
	editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

	local set = CreateFrame("Button", p:GetName() .. "Set", p, "UIPanelButtonTemplate")
	set:SetWidth(30)
	set:SetHeight(20)
	set:SetText(L.Set)
	set:SetScript("OnClick", function(self)
		local text = editBox:GetText()
		self:GetParent().owner:SetShowStates(text ~= "" and text or nil)
		editBox:SetText(self:GetParent().owner:GetShowStates() or "")
	end)
	set:SetPoint("BOTTOMRIGHT", -8, 2)

	return p
end

-- 构建配置菜单：布局面板 + 显示状态(ShowStates)设置。
function class:CreateMenu()
	local menu = self.menu or Dominos:NewMenu(self.id)
	L = LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")
	AddLayoutPanel(menu)
	AddShowState(menu)
	self.menu = menu
end