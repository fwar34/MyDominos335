--[[--------------------------------------------------------------------
xpBar.lua —— 经验条 / 声望条模块（模块注册名："xp"）

职责：
	绘制一条可自由摆放的状态条，用于显示经验值或当前追踪的声望进度；
	经验模式下还会叠加显示休息经验，并在条中央显示数值文字。
	两种显示模式由 ShouldWatchFaction() 决定：
		强制只显示经验(sets.alwaysShowXP) 为真 -> 经验模式 WatchExperience
		否则若 GetWatchedFactionInfo() 有返回值      -> 声望模式 WatchReputation

模块注册名：Dominos:NewModule("xp")
	说明：插件对外名为 MyDominos335，但内部标识仍沿用经典 Dominos，
	故全局表仍为 Dominos、存档仍为 DominosDB / DominosVersion、
	AceLocale 语言键仍为 "Dominos" / "Dominos-Config"。

依赖与前置条件：
	依赖 Dominos.Frame（通过 Dominos:CreateClass("Frame", Dominos.Frame) 派生），
	并使用 LibSharedMedia-3.0 提供状态条材质（缺失时回退 DEFAULT_STATUSBAR_TEXTURE）。

注意事项：
	面向 3.3.5a（Interface 30300）旧 API，不使用 C_Timer / C_AddOns 等现代接口；
	右键交互复刻了暴雪 FFF_ReputationWatchBar_* / MainMenuExpBar 的原始处理器行为。
]]--
assert(Dominos, "Dominos not found!")
local Dominos = Dominos

-- 文本模板：
--   XP_FORMAT   经验模式（当前值 / 上限 [百分比]）
--   REST_FORMAT 经验模式且有休息经验（当前值 / 上限 (+休息经验) [百分比]）
--   REP_FORMAT  声望模式（声望名: 当前值 / 上限 (等级))
local XP_FORMAT = "%s / %s [%s%%]"
local REST_FORMAT = "%s / %s (+%s) [%s%%]"
local REP_FORMAT = "%s:  %s / %s (%s)"
-- 语言表键名仍沿用经典 Dominos（对外名称虽为 MyDominos335）
local L = LibStub("AceLocale-3.0"):GetLocale("Dominos")
local _G = _G

--taken from http://lua-users.org/wiki/FormattingNumbers
--a semi clever way to format numbers with commas (ex, 1,000,000)
-- 将数字格式化为带千位分隔符的字符串（例如 1000000 -> 1,000,000）
local function comma_value(n)
	local left, num, right = string.match(tostring(n), "^([^%d]*%d)(%d*)(.-)$")
	return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

--[[ Module Stuff ]]--
-- 模块注册名为 "xp"；DXP 为模块实例，XP 是由 Dominos.Frame 派生的状态条类
local DXP = Dominos:NewModule("xp")
local XP

function DXP:Load()
	self.frame = XP:New()
	self.frame:SetFrameStrata("BACKGROUND")
end

function DXP:Unload()
	if self.frame then
		self.frame:Free()
	end
end

--[[ XP Object ]]--
XP = Dominos:CreateClass("Frame", Dominos.Frame)

function XP:New()
	local f = self.super.New(self, "xp")
	if not f.value then
		f:Load()
	end

	f:Layout()
	f:UpdateTexture()
	f:UpdateWatch()
	f:UpdateTextShown()

	return f
end

function XP:GetDefaults()
	return {
		alwaysShowText = true,
		point = "TOP",
		width = 0.75,
		height = 14,
		y = -32,
		x = 0,
		texture = "blizzard"
	}
end

function XP:Load()
	local bg = self:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(self)
	if bg.SetHorizTile then
		bg:SetHorizTile(false)
	end
	self.bg = bg

	local rest = CreateFrame("StatusBar", nil, self)
	rest:EnableMouse(false)
	rest:SetAllPoints(self)
	self.rest = rest

	local value = CreateFrame("StatusBar", nil, rest)
	value:EnableMouse(false)
	value:SetAllPoints(self)
	self.value = value

	local text = value:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("CENTER")
	self.text = text

	local click = CreateFrame("Button", nil, value)
	click:SetScript("OnClick", function(_, ...) self:OnClick(...) end)
	click:SetScript("OnEnter", function(_, ...) self:OnEnter(...) end)
	click:SetScript("OnLeave", function(_, ...) self:OnLeave(...) end)
	click:RegisterForClicks("anyUp")
	click:SetAllPoints(self)

	self:UpdateTextShown()
end

local wfxf = nil -- frostmourne specific
local wflv = UnitLevel("player")
-- 点击行为：
--   右键：在经验 / 声望显示之间切换——优先转发给暴雪原生经验条处理器
--         (MainMenuExpBar 的 OnMouseDown)；否则把 alwaysShowXP 置假并转发给
--         暴雪的声望监听处理器 FFF_ReputationWatchBar_OnClick。
--   其他键：翻转 sets.alwaysShowXP（强制只显示经验条）并刷新提示。
function XP:OnClick(button)
	if button == "RightButton" then
		wfxf = _G.MainMenuExpBar and _G.MainMenuExpBar:GetScript("OnMouseDown")
		if wfxf and not IsModifierKeyDown() and wflv < 80 then
			wfxf(_G.MainMenuExpBar, button)
		elseif (not wfxf or IsModifierKeyDown()) and _G.FFF_ReputationWatchBar_OnClick then
			self:SetAlwaysShowXP(false)
			FFF_ReputationWatchBar_OnClick(self, button)
		end
	else
		self:SetAlwaysShowXP(not self.sets.alwaysShowXP)
		self:OnEnter()
	end
	self:UpdateRepWatcherTooltip()
end

function XP:OnEnter()
	self:UpdateTextShown()

	if (FFF_ReputationWatchBar_OnEnter and self:ShouldWatchFaction()) then
		FFF_ReputationWatchBar_OnEnter(self)
	end
end

function XP:OnLeave()
	self:UpdateTextShown()

	if (FFF_ReputationWatchBar_OnLeave) then
		FFF_ReputationWatchBar_OnLeave(self)
	end
end

function XP:UpdateRepWatcherTooltip()
	if GameTooltip:IsOwned(self) and self:ShouldWatchFaction() then
		if FFF_ReputationWatchBar_OnEnter then
			FFF_ReputationWatchBar_OnEnter(self)
		end
	else
		if FFF_ReputationWatchBar_OnLeave then
			FFF_ReputationWatchBar_OnLeave(self)
		end
	end
end

function XP:UpdateWatch()
	if self:ShouldWatchFaction() then
		self:WatchReputation()
	else
		self:WatchExperience()
	end
end

function XP:ShouldWatchFaction()
	return (not self.sets.alwaysShowXP) and GetWatchedFactionInfo()
end

--[[ Experience ]]--
-- 切换到经验模式：先注销全部事件，再按需注册（事件驱动刷新）。
-- 仅当未强制显示经验(alwaysShowXP 为假) 时才额外监听 UPDATE_FACTION，
-- 便于玩家开始追踪声望时自动切到声望模式；其余事件刷新经验与休息经验。
-- 本模式配色：紫色进度条 + 深紫色休息条 + 半透明背景。
function XP:WatchExperience()
	self:UnregisterAllEvents()
	self:SetScript("OnEvent", self.OnXPEvent)

	if not self.sets.alwaysShowXP then
		self:RegisterEvent("UPDATE_FACTION")
	end
	self:RegisterEvent("UPDATE_EXHAUSTION")
	self:RegisterEvent("PLAYER_XP_UPDATE")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("PLAYER_LOGIN")

	self.rest:SetStatusBarColor(0.25, 0.25, 1)
	self.value:SetStatusBarColor(0.6, 0, 0.6)
	self.bg:SetVertexColor(0.3, 0, 0.3, 0.6)
	self:UpdateExperience()
end

-- 经验模式事件回调：收到 UPDATE_FACTION 且当前应显示声望则切换到声望模式，
-- 否则刷新经验数值。
function XP:OnXPEvent(event)
	if event == "UPDATE_FACTION" and self:ShouldWatchFaction() then
		self:WatchReputation()
	else
		self:UpdateExperience()
	end
end

-- 刷新经验数值：value 条显示已获得经验，
-- rest 条叠加显示 (已获得 + 休息经验)，并更新中央文字。
function XP:UpdateExperience()
	local value = UnitXP("player")
	local max = UnitXPMax("player")
	local pct = math.floor((value / math.max(max, 1)) * 100 + 0.5)
	wflv = UnitLevel("player")

	self.value:SetMinMaxValues(0, max)
	self.value:SetValue(value)

	local rest = GetXPExhaustion()
	self.rest:SetMinMaxValues(0, max)

	if rest then
		self.rest:SetValue(value + rest)
		self.text:SetFormattedText(REST_FORMAT, comma_value(value), comma_value(max), comma_value(rest), pct)
	else
		self.rest:SetValue(0)
		self.text:SetFormattedText(XP_FORMAT, comma_value(value), comma_value(max), pct)
	end
end

--[[ Reputation ]]--
-- 切换到声望模式：注销其他事件，只监听 UPDATE_FACTION；
-- 并把休息经验条清零且设为完全透明（该模式不再显示休息经验）。
function XP:WatchReputation()
	self:UnregisterAllEvents()
	self:RegisterEvent("UPDATE_FACTION")
	self:SetScript("OnEvent", self.OnRepEvent)

	self.rest:SetValue(0)
	self.rest:SetStatusBarColor(0, 0, 0, 0)
	self:UpdateReputation()
end

-- 声望模式事件回调：仍应显示声望则刷新声望，否则调用 UpdateWatch() 重新判定模式。
function XP:OnRepEvent(event)
	if self:ShouldWatchFaction() then
		self:UpdateReputation()
	else
		self:UpdateWatch()
	end
end

-- 刷新声望数值：以区间下限归零，按阵营反应色给进度条与背景着色，
-- 文字显示 声望名 / 当前值 / 上限 / 等级标签。
function XP:UpdateReputation()
	local name, reaction, min, max, value = GetWatchedFactionInfo()
	max = max - min
	value = value - min

	local color = FACTION_BAR_COLORS[reaction]
	self.value:SetStatusBarColor(color.r, color.g, color.b)
	self.bg:SetVertexColor(color.r - 0.3, color.g - 0.3, color.b - 0.3, 0.6)

	self.value:SetMinMaxValues(0, max)
	self.value:SetValue(value)

	local repLevel = _G["FACTION_STANDING_LABEL" .. reaction]
	self.text:SetFormattedText(REP_FORMAT, name, comma_value(value), comma_value(max), repLevel)
end

--[[ Layout ]]--
function XP:Layout()
	self:SetWidth(GetScreenWidth() * self.sets.width)
	self:SetHeight(self.sets.height)
end

function XP:SetTexture(texture)
	self.sets.texture = texture
	self:UpdateTexture()
end

-- 应用材质：优先从 LibSharedMedia 取 "statusbar" 材质，取不到则回退
-- DEFAULT_STATUSBAR_TEXTURE；把进度条、休息条与背景纹理一并设置为该材质。
function XP:UpdateTexture()
	local LSM = LibStub("LibSharedMedia-3.0", true)

	local texture = (LSM and LSM:Fetch("statusbar", self.sets.texture)) or DEFAULT_STATUSBAR_TEXTURE
	self.value:SetStatusBarTexture(texture)
	if self.value:GetStatusBarTexture().SetHorizTile then
		self.value:GetStatusBarTexture():SetHorizTile(false)
	end
	self.rest:SetStatusBarTexture(texture)
	if self.rest:GetStatusBarTexture().SetHorizTile then
		self.rest:GetStatusBarTexture():SetHorizTile(false)
	end
	self.bg:SetTexture(texture)
end

-- 设置是否强制只显示经验条（alwaysShowXP）；关闭时才允许自动切到声望模式。
function XP:SetAlwaysShowXP(enable)
	self.sets.alwaysShowXP = enable
	self:UpdateWatch()
end

--[[ Text ]]--
-- 文字显隐：鼠标悬停或 alwaysShowText 为真时显示文字，否则隐藏文字并隐藏整个状态条。
-- alwaysShowText 对应配置面板的 "Always show text" 复选框。
function XP:UpdateTextShown()
	if (self.IsMouseOver and self:IsMouseOver()) or self:IsMouseOver() or self.sets.alwaysShowText then
		self.text:Show()
	else
		self.text:Hide()
		self:Hide()
	end
end

-- 设置是否常显数值文字（alwaysShowText）。
function XP:ToggleText(enable)
	self.sets.alwaysShowText = enable or nil
	self:UpdateTextShown()
end

--[[ Layout Panel ]]--
local function CreateWidthSlider(p)
	local s = p:NewSlider(L.Width, 1, 100, 1)

	s.OnShow = function(self)
		self:SetValue(self:GetParent().owner.sets.width * 100)
	end

	s.UpdateValue = function(self, value)
		local f = self:GetParent().owner
		f.sets.width = value / 100
		f:Layout()
	end
end

local function CreateHeightSlider(p)
	local s = p:NewSlider(L.Height, 1, 128, 1)

	s.OnShow = function(self)
		self:SetValue(self:GetParent().owner.sets.height)
	end

	s.UpdateValue = function(self, value)
		local f = self:GetParent().owner
		f.sets.height = value
		f:Layout()
	end
end

-- 布局面板：宽/高滑块，以及 AlwaysShowText（常显文字）
-- 与 AlwaysShowXP（强制只显示经验条）两个复选框。
local function AddLayoutPanel(menu)
	local p = menu:NewPanel(LibStub("AceLocale-3.0"):GetLocale("Dominos-Config").Layout)

	p:NewOpacitySlider()
	p:NewFadeSlider()
	p:NewScaleSlider()
	CreateHeightSlider(p)
	CreateWidthSlider(p)

	local showText = p:NewCheckButton(L.AlwaysShowText)
	showText:SetScript("OnClick", function(self) self:GetParent().owner:ToggleText(self:GetChecked()) end)
	showText:SetScript("OnShow", function(self) self:SetChecked(self:GetParent().owner.sets.alwaysShowText) end)

	local showXP = p:NewCheckButton(L.AlwaysShowXP)
	showXP:SetScript("OnClick", function(self) self:GetParent().owner:SetAlwaysShowXP(self:GetChecked()) end)
	showXP:SetScript("OnShow", function(self) self:SetChecked(self:GetParent().owner.sets.alwaysShowXP) end)
end

--[[Texture Picker]]--
-- 材质选择面板：滚动浏览 LibSharedMedia 的 "statusbar" 列表并选择材质。
--yeah I know I'm bad in that I didn't capitialize some constants
local NUM_ITEMS = 9
local width, height, offset = 140, 20, 2

local function TextureButton_OnClick(self)
	DXP.frame:SetTexture(self:GetText())
	self:GetParent():UpdateList()
end

local function TextureButton_OnMouseWheel(self, direction)
	local scrollBar = _G[self:GetParent().scroll:GetName() .. "ScrollBar"]
	scrollBar:SetValue(scrollBar:GetValue() - direction * (scrollBar:GetHeight() / 2))
	self:GetParent():UpdateList()
end

local function TextureButton_Create(name, parent)
	local button = CreateFrame("Button", name, parent)
	button:SetWidth(width)
	button:SetHeight(height)

	button.bg = button:CreateTexture()
	button.bg:SetAllPoints(button)

	local r, g, b = max(random(), 0.2), max(random(), 0.2), max(random(), 0.2)
	button.bg:SetVertexColor(r, g, b)
	button:EnableMouseWheel(true)
	button:SetScript("OnClick", TextureButton_OnClick)
	button:SetScript("OnMouseWheel", TextureButton_OnMouseWheel)
	button:SetNormalFontObject("GameFontNormalLeft")
	button:SetHighlightFontObject("GameFontHighlightLeft")

	return button
end

local function Panel_UpdateList(self)
	local SML = LibStub("LibSharedMedia-3.0")
	local textures = LibStub("LibSharedMedia-3.0"):List("statusbar")
	local currentTexture = DXP.frame.sets.texture

	local scroll = self.scroll
	FauxScrollFrame_Update(scroll, #textures, #self.buttons, height + offset)

	for i, button in pairs(self.buttons) do
		local index = i + scroll.offset

		if index <= #textures then
			button:SetText(textures[index])
			button.bg:SetTexture(SML:Fetch("statusbar", textures[index]))
			button:Show()
		else
			button:Hide()
		end
	end
end

local function AddTexturePanel(menu)
	local p = menu:NewPanel(L.Texture)
	p.UpdateList = Panel_UpdateList
	p:SetScript("OnShow", function() p:UpdateList() end)
	p.textures = LibStub("LibSharedMedia-3.0"):List("statusbar")

	local name = p:GetName()
	local scroll = CreateFrame("ScrollFrame", name .. "ScrollFrame", p, "FauxScrollFrameTemplate")
	scroll:SetScript("OnVerticalScroll", function(self, arg1)
		FauxScrollFrame_OnVerticalScroll(self, arg1, height + offset, function() p:UpdateList() end)
	end)
	scroll:SetScript("OnShow", function() p.buttons[1]:SetWidth(width) end)
	scroll:SetScript("OnHide", function() p.buttons[1]:SetWidth(width + 20) end)
	scroll:SetPoint("TOPLEFT", 8, 0)
	scroll:SetPoint("BOTTOMRIGHT", -24, 2)
	p.scroll = scroll

	--add list buttons
	p.buttons = {}
	for i = 1, NUM_ITEMS do
		local b = TextureButton_Create(name .. i, p)
		if i == 1 then
			b:SetPoint("TOPLEFT", 4, 0)
		else
			b:SetPoint("TOPLEFT", name .. i - 1, "BOTTOMLEFT", 0, -offset)
			b:SetPoint("TOPRIGHT", name .. i - 1, "BOTTOMRIGHT", 0, -offset)
		end
		p.buttons[i] = b
	end

	p.height = 200
end

--[[ Menu Code ]]--
-- 构建右键配置菜单：布局面板 + 材质面板。
function XP:CreateMenu()
	local menu = self.menu or Dominos:NewMenu(self.id)
	AddLayoutPanel(menu)
	AddTexturePanel(menu)

	self.menu = menu
end