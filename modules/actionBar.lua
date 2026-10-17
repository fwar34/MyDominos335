--[[
	MyDominos335（内部标识仍为 Dominos）—— 动作条模块 actionBar.lua

	本模块负责“主动作条”的创建与管理：由若干条编号动作条组成（条数由
	Dominos:NumBars() 决定），是本插件最核心的模块。这些条均继承自 core 的
	Dominos.Frame；按钮则继承 Dominos.BindableButton，并尽量复用暴雪原生按钮，
	仅在不足时才动态创建。

	关键依赖：
		- Dominos.BindableButton：按钮基类，提供 Bind 等绑定能力
		- Dominos:Masque("Action Bar", ...)：皮肤（Masque/ButtonFacade）；不可用时
		  回退到 Dominos 自带外观（见 ActionButton:Skin）
		- LibKeyBound-1.0：鼠标悬停按钮时高亮并显示按键绑定

	按钮来源（复用暴雪原生全局框架）：
		ActionButton1..12、BonusActionButton1..12、MultiBarRightButton1..12、
		MultiBarLeftButton1..12、MultiBarBottomRightButton1..12、
		MultiBarBottomLeftButton1..12；超过 72 个则新建 DominosActionButtonXX。

	注意事项：
		- 内部标识仍为 Dominos：全局表仍是 Dominos，存档仍是 DominosDB，
		  语言键仍是 "Dominos" / "Dominos-Config"。
		- 面向 3.3.5a（Interface 30300）旧 API，无 C_Timer / C_AddOns 等新接口；
		  延时统一走 Dominos:Delay（基于 OnUpdate）。
		- 分页依赖安全状态驱动（SecureStateDriver）与子状态回调 _childupdate-action。
--]]

assert(Dominos, "Dominos not found!")
local Dominos = Dominos

--libs and omgspeed
local _G = _G
local ceil = math.ceil
local min = math.min
local format = string.format
local MAX_BUTTONS = 120
local NUM_POSSESS_BAR_BUTTONS = 12
local KeyBound = LibStub("LibKeyBound-1.0")

--[[ Action Button ]]--
-- 动作条按钮类：继承 core 的 Dominos.BindableButton（可绑定按钮），底层框架为
-- CheckButton。unused/active 分别缓存“空闲可复用”与“使用中”的按钮。
local ActionButton = Dominos:CreateClass("CheckButton", Dominos.BindableButton)
Dominos.ActionButton = ActionButton
ActionButton.unused = {}
ActionButton.active = {}

--constructor
-- 取得按钮：优先从空闲池 Restore，否则新建 Create，然后写入基础动作 ID 与安全子状态回调。
function ActionButton:New(id)
	local b = self:Restore(id) or self:Create(id)
	if b then
		b:SetAttribute("showgrid", 0)
		-- action--base：该按钮的基础动作 ID（等于其全局编号 id），不随分页变化
		b:SetAttribute("action--base", id)
		-- _childupdate-action：安全“子状态”回调。父框架分页变化时会以 message 携带新状态名
		-- 触发；据此从 action--<state> 取页码对应动作，取不到则回退 action--base，
		-- 最终写入 action 属性供动作按钮使用。
		b:SetAttribute("_childupdate-action", [[
			local id = message and self:GetAttribute('action--' .. message) or self:GetAttribute('action--base')
			self:SetAttribute('action', id)
		]])

		b:UpdateGrid()
		b:UpdateHotkey(b.buttonType)
		b:UpdateMacro()

		--hack #1billion, get rid of range indicator text
		local hotkey = _G[b:GetName() .. "HotKey"]
		if hotkey:GetText() == _G["RANGE_INDICATOR"] then
			hotkey:SetText("")
		end

		self.active[id] = b

		return b
	end
end

-- 依 id 号段选择按钮来源：1..72 复用暴雪原生按钮，超出则以 ActionBarButtonTemplate 新建。
local function Create(id)
	if id <= 12 then
		local b = _G["ActionButton" .. id]
		b.buttonType = "ACTIONBUTTON"
		return b
	-- 13..24：复用暴雪“奖励动作条”按钮 BonusActionButton1..12
	elseif id <= 24 then
		local b = _G["BonusActionButton" .. (id - 12)]
		b:UnregisterEvent("UPDATE_BONUS_ACTIONBAR")
		b.isBonus = nil
		b.buttonType = nil --this is done because blizzard displays action bar 1 bindings on the bonus bar, which is incorrect in the case of Dominos
		return b
	-- 25..72：复用暴雪右侧/左侧/右下/左下动作条按钮
	elseif id <= 36 then
		return _G["MultiBarRightButton" .. (id - 24)]
	elseif id <= 48 then
		return _G["MultiBarLeftButton" .. (id - 36)]
	elseif id <= 60 then
		return _G["MultiBarBottomRightButton" .. (id - 48)]
	elseif id <= 72 then
		return _G["MultiBarBottomLeftButton" .. (id - 60)]
	end
	-- 超过 72：动态创建 Dominos 自有按钮
	return CreateFrame("CheckButton", "DominosActionButton" .. (id - 72), nil, "ActionBarButtonTemplate")
end

function ActionButton:Create(id)
	local b = Create(id)
	if b then
		self:Bind(b)

		-- 用意：保留按钮原始 ID 供旧按键绑定系统使用；但不能让 SetID 保持 >0，
		-- 否则暴雪代码会依据按钮 ID 自行接管分页，导致 Dominos 分页失效，故 SetID(0)。
		--this is used to preserve the button's old id
		--we cannot simply keep a button's id at > 0 or blizzard code will take control of paging
		--but we need the button's id for the old bindings system
		b:SetAttribute("bindingid", b:GetID())
		b:SetID(0)

		b:ClearAllPoints()
		b:SetAttribute("useparent-actionpage", nil)
		b:SetAttribute("useparent-unit", true)
		b:EnableMouseWheel(true)
		b:SetScript("OnEnter", self.OnEnter)
		b:Skin()
	end
	return b
end

-- 从空闲池取出按钮并重新启用：重新注册事件、刷新动作、显示
function ActionButton:Restore(id)
	local b = self.unused[id]
	if b then
		self.unused[id] = nil
		b:LoadEvents()
		ActionButton_UpdateAction(b)
		b:Show()
		self.active[id] = b
		return b
	end
end

--destructor
function ActionButton:Free()
	local id = self:GetAttribute("action--base")

	self.active[id] = nil

	self:UnregisterAllEvents()
	self:SetParent(nil)
	self:Hide()
	self.eventsRegistered = nil
	self.action = nil

	self.unused[id] = self
end

--these are all events that are registered OnLoad for action buttons
function ActionButton:LoadEvents()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ACTIONBAR_SHOWGRID")
	self:RegisterEvent("ACTIONBAR_HIDEGRID")
	self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	self:RegisterEvent("UPDATE_BINDINGS")
end

--keybound support
function ActionButton:OnEnter()
	if Dominos:ShowTooltips() then
		ActionButton_SetTooltip(self)
	end
	KeyBound:Set(self)
end

--override the old update hotkeys function
hooksecurefunc("ActionButton_UpdateHotkeys", ActionButton.UpdateHotkey)

-- Color button red if out of range
hooksecurefunc("ActionButton_OnEvent", function(self, event, ...)
	if event == "PLAYER_TARGET_CHANGED" then
		self.newTimer = self.rangeTimer
	end
end)

hooksecurefunc("ActionButton_UpdateUsable", function(self)
	local icon = _G[self:GetName() .. "Icon"]
	local inRange = IsActionInRange(self.action)
	local isUsable, notEnoughMana = IsUsableAction(self.action)

	if inRange == 0 then
		icon:SetVertexColor(1.0, 0.1, 0.1)
	elseif isUsable then
		icon:SetVertexColor(1.0, 1.0, 1.0)
	elseif notEnoughMana then
		icon:SetVertexColor(0.5, 0.5, 1.0)
	else
		icon:SetVertexColor(0.4, 0.4, 0.4)
	end
end)

do
	local function Dominos_RestoreSaturation(self, icon)
		if icon and icon:IsDesaturated() then
			icon:SetDesaturated(false)
		end
	end

	local function Dominos_ActionButton_UpdateCooldown(self)
		local icon = _G[self:GetName() .. "Icon"]
		if icon and self.action then
			local start, duration = GetActionCooldown(self.action)
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

	hooksecurefunc("ActionButton_UpdateCooldown", Dominos_ActionButton_UpdateCooldown)
end

hooksecurefunc("ActionButton_OnUpdate", function(self, elapsed)
	local rangeTimer = self.newTimer
	if rangeTimer then
		rangeTimer = rangeTimer - elapsed
		if rangeTimer <= 0 then
			ActionButton_UpdateUsable(self)
			rangeTimer = TOOLTIP_UPDATE_TIME
		end
		self.newTimer = rangeTimer
	end
end)

--button visibility
function ActionButton:UpdateGrid()
	if self:GetAttribute("showgrid") > 0 then
		ActionButton_ShowGrid(self)
	else
		ActionButton_HideGrid(self)
	end
end

--macro text
function ActionButton:UpdateMacro()
	if Dominos:ShowMacroText() then
		_G[self:GetName() .. "Name"]:Show()
	else
		_G[self:GetName() .. "Name"]:Hide()
	end
end

--utility function, resyncs the button's current action, modified by state
function ActionButton:LoadAction()
	local state = self:GetParent():GetAttribute("state-page")
	local id = state and self:GetAttribute("action--" .. state) or self:GetAttribute("action--base")
	self:SetAttribute("action", id)
end

function ActionButton:Skin()
	if not Dominos:Masque("Action Bar", self) then
		_G[self:GetName() .. "Icon"]:SetTexCoord(0.06, 0.94, 0.06, 0.94)
		self:GetNormalTexture():SetVertexColor(1, 1, 1, 0.5)

		if _G[self:GetName() .. "FloatingBG"] then
			_G[self:GetName() .. "FloatingBG"]:Hide()
		end
	end
end

--[[ Action Bar ]]--
local ActionBar = Dominos:CreateClass("Frame", Dominos.Frame)
Dominos.ActionBar = ActionBar

--metatable magic.
-- Basically this says, 'create a new table for this index'
--I do this so that I only create page tables for classes the user is actually playing
local POSSESSED_CONDITIONAL = "[bonusbar:5]"

--[[ Constructor Code ]]--
ActionBar.defaultOffsets = {__index = function(t, i)
	t[i] = {}
	return t[i]
end}

--metatable magic.  Basically this says, 'create a new table for this index, with these defaults'
--I do this so that I only create page tables for classes the user is actually playing
ActionBar.mainbarOffsets = {
	__index = function(t, i)
		local pages = {
			["[bar:2]"] = 1,
			["[bar:3]"] = 2,
			["[bar:4]"] = 3,
			["[bar:5]"] = 4,
			["[bar:6]"] = 5
		}

		if i == "DRUID" then
			--			pages['[bonusbar:1,stealth]'] = 5
			pages["[bonusbar:1]"] = 6
			pages["[bonusbar:2]"] = 7
			pages["[bonusbar:3]"] = 8
			pages["[bonusbar:4]"] = 9
		elseif i == "WARRIOR" then
			pages["[bonusbar:1]"] = 6
			pages["[bonusbar:2]"] = 7
			pages["[bonusbar:3]"] = 8
		elseif i == "PRIEST" then
			pages["[bonusbar:1]"] = 6
		elseif i == "ROGUE" then
			pages["[bonusbar:1]"] = 6
			pages["[form:3]"] = 6 --shadowdance
		--[[
		elseif i == 'WARLOCK' then
			pages['[form:2]'] = 6 --demon form, need to watch this to make sure blizzard doesn't change the page
		--]]
		end

		t[i] = pages
		return pages
	end
}

-- 分页条件表：按求值顺序排列。序号（state）与 UpdateStateDriver/UpdateAction 中生成的
-- “action--S<序号>” 状态属性一一对应；安全状态驱动会按顺序命中首个成立的条件来切页。
--this is the set of conditions used for paging, in order of evaluation
ActionBar.conditions = {
	"[mod:SELFCAST]",
	"[mod:alt,mod:ctrl,mod:shift]",
	"[mod:alt,mod:ctrl]",
	"[mod:alt,mod:shift]",
	"[mod:ctrl,mod:shift]",
	"[mod:alt]",
	"[mod:ctrl]",
	"[mod:shift]",
	POSSESSED_CONDITIONAL,
	"[bar:2]",
	"[bar:3]",
	"[bar:4]",
	"[bar:5]",
	"[bar:6]",
	"[bonusbar:1,stealth]", --prowl
	"[form:2]",
	"[form:3]",
	"[bonusbar:1]",
	"[bonusbar:2]",
	"[bonusbar:3]",
	"[bonusbar:4]",
	"[help]",
	"[harm]",
	"[noexists]"
}

ActionBar.class = Dominos.MyClass
local active = {}

function ActionBar:New(id)
	local f = self.super.New(self, id)
	f.sets.pages = setmetatable(f.sets.pages, f.id == 1 and self.mainbarOffsets or self.defaultOffsets)

	f.pages = f.sets.pages[f.class]
	f.baseID = f:MaxLength() * (id - 1)

	f:LoadStateController()
	f:LoadButtons()
	f:UpdateStateDriver()
	f:Layout()
	f:UpdateGrid()
	f:UpdateRightClickUnit()

	active[id] = f

	return f
end

--TODO: change the position code to be based more on the number of action bars
function ActionBar:GetDefaults()
	local defaults = {}
	defaults.point = "BOTTOM"
	defaults.x = 0
	defaults.y = 40 * (self.id - 1)
	defaults.pages = {}
	defaults.spacing = 4
	defaults.padW = 2
	defaults.padH = 2
	defaults.numButtons = self:MaxLength()

	return defaults
end

function ActionBar:Free()
	active[self.id] = nil
	self.super.Free(self)
end

--returns the maximum possible size for a given bar
function ActionBar:MaxLength()
	return floor(MAX_BUTTONS / Dominos:NumBars())
end

--[[ button stuff]]--
function ActionBar:LoadButtons()
	for i = 1, self:NumButtons() do
		local b = ActionButton:New(self.baseID + i)
		if b then
			b:SetParent(self.header)
			self.buttons[i] = b
		else
			break
		end
	end
	self:UpdateActions()
end

function ActionBar:AddButton(i)
	local b = ActionButton:New(self.baseID + i)
	if b then
		self.buttons[i] = b
		b:SetParent(self.header)
		b:LoadAction()
		self:UpdateAction(i)
		self:UpdateGrid()
	end
end

function ActionBar:RemoveButton(i)
	local b = self.buttons[i]
	self.buttons[i] = nil
	b:Free()
end

--[[ Paging Code ]]--
function ActionBar:SetPage(condition, page)
	self.pages[condition] = page
	self:UpdateStateDriver()
end

function ActionBar:GetPage(condition)
	return self.pages[condition]
end

-- 重新构建安全状态驱动：遍历 conditions，为每个已设置页码的条件拼出
-- “<条件>S<序号>;” 片段，末尾附加 “0” 作为默认页；possess（载具页）为特例，
-- 直接拼 “<条件>possess;”（对应 UpdateAction 中写入的 action--possess）。
--note to self:
--if you leave a ; on the end of a statebutton string, it causes evaluation issues,
-- especially if you're doing right click selfcast on the base state
function ActionBar:UpdateStateDriver()
	UnregisterStateDriver(self.header, "page", 0)

	local header = ""
	for state, condition in ipairs(self.conditions) do
		--possess bar: special case
		if condition == POSSESSED_CONDITIONAL then
			if self:IsPossessBar() then
				header = header .. condition .. "possess;"
			end
		elseif self:GetPage(condition) then
			header = header .. condition .. "S" .. state .. ";"
		end
	end

	if header ~= "" then
		RegisterStateDriver(self.header, "page", header .. 0)
	end

	self:UpdateActions()
	self:RefreshActions()
end

local function ToValidID(id)
	return (id - 1) % MAX_BUTTONS + 1
end

-- 为单个按钮推导全部状态下的 actionID：
-- id = action--base + (本条第几页 + 页码 - 1) * 每条长度，再取模 MAX_BUTTONS 归一到 1..MAX_BUTTONS，
-- 写入对应状态属性 action--S<state>；无页码的条件写 nil。
--updates the actionID of a given button for all states
function ActionBar:UpdateAction(i)
	local b = self.buttons[i]
	local maxSize = self:MaxLength()

	for state, condition in ipairs(self.conditions) do
		local page = self:GetPage(condition)
		local id = page and ToValidID(b:GetAttribute("action--base") + (self.id + page - 1) * maxSize) or nil

		b:SetAttribute("action--S" .. state, id)
	end

	if self:IsPossessBar() and i <= NUM_POSSESS_BAR_BUTTONS then
		b:SetAttribute("action--possess", MAX_BUTTONS + i)
	else
		b:SetAttribute("action--possess", nil)
	end
end

-- 为所有按钮推导全部状态下的 actionID（与 UpdateAction 同理，但按按钮序号 i 批量处理），
-- 并统一维护 possess（载具）页：仅前 NUM_POSSESS_BAR_BUTTONS 个按钮映射到 MAX_BUTTONS+i，
-- 其余按钮的 action--possess 置空。
--updates the actionID of all buttons for all states
function ActionBar:UpdateActions()
	local maxSize = self:MaxLength()

	for state, condition in ipairs(self.conditions) do
		-- local page = self:GetPage(condition)
		for i, b in pairs(self.buttons) do
			local page = self:GetPage(condition)
			local id = page and ToValidID(i + (self.id + page - 1) * maxSize) or nil

			b:SetAttribute("action--S" .. state, id)
		end
	end

	if self:IsPossessBar() then
		for i = 1, min(#self.buttons, NUM_POSSESS_BAR_BUTTONS) do
			self.buttons[i]:SetAttribute("action--possess", MAX_BUTTONS + i)
		end
		for i = NUM_POSSESS_BAR_BUTTONS + 1, #self.buttons do
			self.buttons[i]:SetAttribute("action--possess", nil)
		end
	else
		for _, b in pairs(self.buttons) do
			b:SetAttribute("action--possess", nil)
		end
	end
end

-- 注册安全状态回调：当 page 状态变化时，让 header 通知所有子按钮刷新 action。
-- 与按钮上的 _childupdate-action 配合，把 ChildUpdate 的 message 转发为各按钮的 action 更新。
function ActionBar:LoadStateController()
	self.header:SetAttribute("_onstate-page", [[ control:ChildUpdate('action', newstate) ]])
end

function ActionBar:RefreshActions()
	local state = self.header:GetAttribute("state-page")
	if state then
		self.header:Execute(format([[ control:ChildUpdate('action', '%s') ]], state))
	else
		self.header:Execute([[ control:ChildUpdate('action', nil) ]])
	end
end

-- 是否为本插件的 possess（载具/控制）条；是则返回 true
--returns true if the possess bar, false otherwise
function ActionBar:IsPossessBar()
	return self == Dominos:GetPossessBar()
end

--Empty button display
function ActionBar:ShowGrid()
	for _, b in pairs(self.buttons) do
		b:SetAttribute("showgrid", b:GetAttribute("showgrid") + 1)
		b:UpdateGrid()
	end
end

function ActionBar:HideGrid()
	for _, b in pairs(self.buttons) do
		b:SetAttribute("showgrid", max(b:GetAttribute("showgrid") - 1, 0))
		b:UpdateGrid()
	end
end

function ActionBar:UpdateGrid()
	if Dominos:ShowGrid() then
		self:ShowGrid()
	else
		self:HideGrid()
	end
end

--keybound support
function ActionBar:KEYBOUND_ENABLED()
	self:ShowGrid()
end

function ActionBar:KEYBOUND_DISABLED()
	self:HideGrid()
end

--right click targeting support
function ActionBar:UpdateRightClickUnit()
	self.header:SetAttribute("*unit2", Dominos:GetRightClickUnit())
end

--utility functions
function ActionBar:ForAll(method, ...)
	for _, f in pairs(active) do
		f[method](f, ...)
	end
end

--right click menu code for action bars
--TODO: Probably enable the showstate stuff for other bars, since every bar basically has showstate functionality for 'free'
do
	local L

	-- 条件滑块模板：把某个分页条件绑定到 -1..N-1 的滑块（-1 表示禁用该页）
	--state slider template
	local function ConditionSlider_OnShow(self)
		self:SetMinMaxValues(-1, Dominos:NumBars() - 1)
		self:SetValue(self:GetParent().owner:GetPage(self.condition) or -1)
	end

	local function ConditionSlider_UpdateValue(self, value)
		self:GetParent().owner:SetPage(self.condition, (value > -1 and value) or nil)
	end

	local function ConditionSlider_UpdateText(self, value)
		if value > -1 then
			local page = (self:GetParent().owner.id + value - 1) % Dominos:NumBars() + 1
			self.valText:SetFormattedText(L.Bar, page)
		else
			self.valText:SetText(DISABLE)
		end
	end

	-- 新建一个“条件→页码”滑块：标题显示条件或给定文本，右侧显示当前页码（禁用时显示 DISABLE）
	local function ConditionSlider_New(panel, condition, text)
		local s = panel:NewSlider(condition, 0, 1, 1)
		s.OnShow = ConditionSlider_OnShow
		s.UpdateValue = ConditionSlider_UpdateValue
		s.UpdateText = ConditionSlider_UpdateText
		s.condition = condition
		s:SetWidth(s:GetWidth() + 28)

		local title = _G[s:GetName() .. "Text"]
		title:ClearAllPoints()
		title:SetPoint("BOTTOMLEFT", s, "TOPLEFT")
		title:SetJustifyH("LEFT")
		title:SetText(text or condition)

		local value = s.valText
		value:ClearAllPoints()
		value:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT")
		value:SetJustifyH("RIGHT")

		return s
	end

	-- 布局面板：按钮数量滑块（改变本条显示的按钮数）
	local function AddLayout(self)
		local p = self:AddLayoutPanel()

		local size = p:NewSlider(L.Size, 1, 1, 1)
		size.OnShow = function(self)
			self:SetMinMaxValues(1, self:GetParent().owner:MaxLength())
			self:SetValue(self:GetParent().owner:NumButtons())
		end

		size.UpdateValue = function(self, value)
			self:GetParent().owner:SetNumButtons(value)
			_G[self:GetParent():GetName() .. L.Columns]:OnShow()
		end
	end

	-- 高级面板：由 core 提供的通用高级选项
	local function AddAdvancedLayout(self)
		self:AddAdvancedPanel()
	end

	-- 职业/形态分页面板：仅对拥有相应形态页的职业（战士/德鲁伊/牧师/盗贼/术士）显示滑块
	-- 注：用 GetSpellInfo(spellID) 取技能名做标题，便于本地化
	--GetSpellInfo(spellID) is awesome for localization
	local function AddClass(self)
		local lClass, class = UnitClass("player")
		if class == "WARRIOR" or class == "DRUID" or class == "PRIEST" or class == "ROGUE" or class == "WARLOCK" then
			local p = self:NewPanel(lClass)
			if class == "WARRIOR" then
				ConditionSlider_New(p, "[bonusbar:3]", GetSpellInfo(2458))
				ConditionSlider_New(p, "[bonusbar:2]", GetSpellInfo(71))
				ConditionSlider_New(p, "[bonusbar:1]", GetSpellInfo(2457))
			elseif class == "DRUID" then
				ConditionSlider_New(p, "[bonusbar:4]", GetSpellInfo(24858))
				ConditionSlider_New(p, "[bonusbar:3]", GetSpellInfo(5487))
				ConditionSlider_New(p, "[bonusbar:2]", GetSpellInfo(33891))
				ConditionSlider_New(p, "[bonusbar:1,stealth]", GetSpellInfo(5215))
				ConditionSlider_New(p, "[bonusbar:1]", GetSpellInfo(768))
			elseif class == "PRIEST" then
				ConditionSlider_New(p, "[bonusbar:1]", GetSpellInfo(15473))
			elseif class == "ROGUE" then
				ConditionSlider_New(p, "[bonusbar:1]", GetSpellInfo(1784))
				ConditionSlider_New(p, "[form:3]", GetSpellInfo(51713))
			elseif class == "WARLOCK" then
				ConditionSlider_New(p, "[form:2]", GetSpellInfo(47241))
			end
		end
	end

	-- 快捷翻页面板：[bar:2]..[bar:6] 页码滑块（对应暴雪动作条翻页快捷键）
	local function AddPaging(self)
		local p = self:NewPanel(L.QuickPaging)
		for i = 6, 2, -1 do
			ConditionSlider_New(p, format("[bar:%d]", i), _G["BINDING_NAME_ACTIONPAGE" .. i])
		end
	end

	-- 修饰键面板：按住修饰键（Shift/Ctrl/Alt 及其组合）时切换到对应页
	local function AddModifier(self)
		local p = self:NewPanel(L.Modifiers)
		ConditionSlider_New(p, "[mod:SELFCAST]", AUTO_SELF_CAST_KEY_TEXT)
		ConditionSlider_New(p, "[mod:alt,mod:ctrl,mod:shift]", L.CtrlAltShift)
		ConditionSlider_New(p, "[mod:alt,mod:shift]", L.AltShift)
		ConditionSlider_New(p, "[mod:ctrl,mod:shift]", L.CtrlShift)
		ConditionSlider_New(p, "[mod:alt,mod:ctrl]", L.CtrlAlt)
		ConditionSlider_New(p, "[mod:shift]", SHIFT_KEY)
		ConditionSlider_New(p, "[mod:alt]", ALT_KEY)
		ConditionSlider_New(p, "[mod:ctrl]", CTRL_KEY)
	end

	-- 目标状态面板：根据当前目标是否存在/敌对/友方进行切页
	local function AddTargeting(self)
		local p = self:NewPanel(L.Targeting)
		ConditionSlider_New(p, "[noexists]", NONE)
		ConditionSlider_New(p, "[harm]", L.Harm)
		ConditionSlider_New(p, "[help]", L.Help)
	end

	-- 显示状态面板：编辑本条的自定义显隐宏条件（对应 GetShowStates/SetShowStates）
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

	-- 构建动作条右键菜单：按顺序加入 布局 / 职业 / 快捷翻页 / 修饰键 / 目标状态 / 显示状态 / 高级 面板
	function ActionBar:CreateMenu()
		local menu = self.menu or Dominos:NewMenu(self.id)

		L = LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")
		AddLayout(menu)
		AddClass(menu)
		AddPaging(menu)
		AddModifier(menu)
		AddTargeting(menu)
		AddShowState(menu)
		AddAdvancedLayout(menu)

		self.menu = menu
	end
end