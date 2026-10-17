--[[
	MyDominos335（内部标识仍为 Dominos）—— 掷骰条模块 rollBar.lua

	负责掷骰/需求-贪婪条：接管暴雪原生 GroupLootFrame1..NUM_GROUP_LOOT_FRAMES，将它们作为
	本条按钮排布。条继承 core 的 Dominos.Frame，并以模块 "roll"（DRB）形式加载/卸载。

	关键依赖：
		- Dominos:NewModule("roll")：模块化加载（Load / Unload）
		- 语言键取自 "Dominos"

	注意事项：
		- 内部标识仍为 Dominos。
		- 面向 3.3.5a（Interface 30300）旧 API（NUM_GROUP_LOOT_FRAMES 等）。
		- 文件末尾将 UIPARENT_MANAGED_FRAME_POSITIONS["GroupLootFrame1"] 置空，取消暴雪对该
		  框架的自动定位/显隐管理，交由本插件接管。
--]]

assert(Dominos, "Dominos not found!")
local Dominos = Dominos
local DRB = Dominos:NewModule("roll")
local L = LibStub("AceLocale-3.0"):GetLocale("Dominos")
local RollBar

-- 模块加载：创建掷骰条框架
function DRB:Load()
	self.frame = RollBar:New()
end

-- 模块卸载：释放掷骰条框架
function DRB:Unload()
	if self.frame then
		self.frame:Free()
	end
end

--[[ Roll Bar Object ]]
-- 掷骰条类：继承 core 的 Dominos.Frame，按钮复用暴雪的 GroupLootFrame 系列。
RollBar = Dominos:CreateClass("Frame", Dominos.Frame)

function RollBar:New()
	local f = self.super.New(self, "roll", L.TipRollBar)
	f:LoadButtons()
	f:Layout()

	return f
end

function RollBar:GetDefaults()
	return {
		point = "LEFT",
		numButtons = NUM_GROUP_LOOT_FRAMES,
		columns = 1,
		spacing = 2
	}
end

-- 第 i 个按钮复用暴雪 GroupLootFrame(5-i)：即把 5..1 号框架倒序映射到 1..5 号按钮
function RollBar:AddButton(i)
	local b = _G["GroupLootFrame" .. (5 - i)]
	b:SetParent(self.header)
	self.buttons[i] = b
end

function RollBar:RemoveButton(i)
	local b = self.buttons[i]
	b:SetParent(nil)
	self.buttons[i] = nil
end

-- 取消暴雪对 GroupLootFrame1 的自动定位管理，避免与本条的 Layout 冲突
UIPARENT_MANAGED_FRAME_POSITIONS["GroupLootFrame1"] = nil