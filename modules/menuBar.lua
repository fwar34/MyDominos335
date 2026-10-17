--[[
	MyDominos335（内部标识仍为 Dominos）—— 微型菜单条模块 menuBar.lua

	负责微型菜单条：复用暴雪主菜单栏 MainMenuBarArtFrame 下所有以 “MicroButton” 结尾的
	子按钮（角色/法术书/天赋/成就/任务/社交/PVP/寻求组队/主菜单/帮助等）。条继承 core 的
	Dominos.Frame。

	关键依赖：
		- 依赖暴雪全局的 *MicroButton 框架与 MicroButtonTooltipText 等
		- 因微按钮尺寸不规则，重写 Layout（引入 WIDTH_OFFSET / HEIGHT_OFFSET 偏移）

	注意事项：
		- 内部标识仍为 Dominos。
		- 面向 3.3.5a（Interface 30300）旧 API（UnitCharacterPoints 等），无现代 C_ 系列接口。
		- 对天赋按钮做了事件特化，对成就按钮取消了其自动事件。
--]]

assert(Dominos, "Dominos not found!")
local Dominos = Dominos

--[[
local menuButtons = {
	CharacterMicroButton,
	SpellbookMicroButton,
	TalentMicroButton,
	AchievementMicroButton,
	QuestLogMicroButton,
	SocialsMicroButton,
	PVPMicroButton,
	LFDMicroButton,
	MainMenuMicroButton,
	HelpMicroButton
}
--]]
local menuButtons
do
	-- 从主菜单栏的子框架中筛选名字形如 “XxxMicroButton” 的按钮，收集为本条按钮集合
	local loadButtons = function(...)
		menuButtons = {}

		for i = 1, select("#", ...) do
			local b = select(i, ...)
			local name = b:GetName()
			if name and name:match("(%w+)MicroButton$") then
				table.insert(menuButtons, b)
			end
		end
	end
	loadButtons(_G["MainMenuBarArtFrame"]:GetChildren())
end

do
	-- 天赋按钮事件特化：升级/登录时，若尚有未分配天赋点且角色面板未开则脉动提示；绑定变化时刷新提示文本
	TalentMicroButton:SetScript("OnEvent", function(self, event)
		if (event == "PLAYER_LEVEL_UP" or event == "PLAYER_LOGIN") then
			if UnitCharacterPoints("player") > 0 and not CharacterFrame:IsShown() then
				SetButtonPulse(self, 60, 1)
			end
		elseif event == "UPDATE_BINDINGS" then
			self.tooltipText = MicroButtonTooltipText(TALENTS_BUTTON, "TOGGLETALENTS")
		end
	end)
	TalentMicroButton:UnregisterAllEvents()
	TalentMicroButton:RegisterEvent("PLAYER_LEVEL_UP")
	TalentMicroButton:RegisterEvent("PLAYER_LOGIN")
	TalentMicroButton:RegisterEvent("UPDATE_BINDINGS")

	-- 成就按钮同理：注销其全部事件，避免本条误触发
	--simialr thing, but the achievement button
	AchievementMicroButton:UnregisterAllEvents()
end

--[[ Menu Bar ]]
-- 微型菜单条类：继承 core 的 Dominos.Frame；按钮集合即上文筛选出的 menuButtons。
local MenuBar = Dominos:CreateClass("Frame", Dominos.Frame)
Dominos.MenuBar = MenuBar

function MenuBar:New()
	local f = self.super.New(self, "menu")
	f:LoadButtons()
	f:Layout()

	return f
end

function MenuBar:GetDefaults()
	return {point = "BOTTOMRIGHT", x = -244, y = 0}
end

function MenuBar:NumButtons()
	return #menuButtons
end

function MenuBar:AddButton(i)
	local b = menuButtons[i]
	if b then
		b:SetParent(self.header)
		b:Show()

		self.buttons[i] = b
	end
end

function MenuBar:RemoveButton(i)
	local b = self.buttons[i]
	if b then
		b:SetParent(nil)
		b:Hide()

		self.buttons[i] = nil
	end
end

-- 重写布局：微按钮尺寸不规则，故引入偏移量修正行列位置与尺寸
--override, because the menu bar has weird button sizes
local WIDTH_OFFSET = 2
local HEIGHT_OFFSET = 20

function MenuBar:Layout()
	if #self.buttons > 0 then
		local cols = min(self:NumColumns(), #self.buttons)
		local rows = ceil(#self.buttons / cols)
		local pW, pH = self:GetPadding()
		local spacing = self:GetSpacing()

		local b = self.buttons[1]
		local w = b:GetWidth() + spacing - WIDTH_OFFSET
		local h = b:GetHeight() + spacing - HEIGHT_OFFSET

		for i, btn in pairs(self.buttons) do
			local col = (i - 1) % cols
			local row = ceil(i / cols) - 1
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", w * col + pW, -(h * row + pH) + HEIGHT_OFFSET)
		end

		self:SetWidth(max(w * cols - spacing + pW * 2 + WIDTH_OFFSET, 8))
		self:SetHeight(max(h * ceil(#self.buttons / cols) - spacing + pH * 2, 8))
	else
		self:SetWidth(30)
		self:SetHeight(30)
	end
end