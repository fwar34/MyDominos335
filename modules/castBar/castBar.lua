--[[
castBar.lua
A dominos based casting bar
--]]
--[[
	Copyright (c) 2008-2009 Jason Greer
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

		* Redistributions of source code must retain the above copyright notice,
		  this list of conditions and the following disclaimer.
		* Redistributions in binary form must reproduce the above copyright
		  notice, this list of conditions and the following disclaimer in the
		  documentation and/or other materials provided with the distribution.
		* Neither the name of the author nor the names of its contributors may
		  be used to endorse or promote products derived from this software
		  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
	LIABLE FORANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.
--]]
--[[
	中文说明：本文件为施法条模块 castBar.lua
	职责：基于 Dominos 框架体系实现玩家施法/引导进度条，取代暴雪默认施法条 CastingBarFrame；
	     模块内部注册名为 "CastingBar"（局部变量 DCB），由 Dominos:UseCastbar() 决定启用或禁用。
	关键依赖：Dominos（Frame/StatusBar 框架类、菜单与布局、Delay 等）、AceLocale-3.0（语言键 "Dominos" 与 "Dominos-Config"）、
	     暴雪原生 API（CastingBarFrame_OnLoad/OnEvent/OnUpdate、IsHelpfulSpell、IsHarmfulSpell 等，客户端 Interface 30300 旧 API）。
	被谁使用：由 modules/castBar/castBar.xml → modules/_load.xml 挂载加载。
	注意：插件对外名已改为 MyDominos335，但内部标识仍为 Dominos——全局表仍叫 Dominos、
	     动态框架全局名仍为 DominosCastingBar、语言键仍为 "Dominos"/"Dominos-Config"，代码中出现的 Dominos 均为内部标识。
--]]
local Dominos = Dominos
local L = LibStub("AceLocale-3.0"):GetLocale("Dominos")
local DCB = Dominos:NewModule("CastingBar")
local CastBar, CastingBar

function DCB:OnInitialize()
	if Dominos:UseCastbar() then
		CastingBarFrame:UnregisterAllEvents()
		CastingBarFrame:Hide()
	else
		self:Disable()
	end
end

function DCB:Load()
	self.frame = CastBar:New()
	-- Hide Default Blizzard Cast bar:
	CastingBarFrame:UnregisterAllEvents()
	CastingBarFrame:Hide()
end

function DCB:Unload()
	if self.frame then
		self.frame:Free()
	end
end

--[[ Dominos Frame Object ]]--
-- 外层施法条框架 CastBar：继承 Dominos.Frame，负责定位/缩放/标题与右键菜单
CastBar = Dominos:CreateClass("Frame", Dominos.Frame)

-- 创建施法条框架：叠加层设为 HIGH；内部再创建 CastingBar 本体，并隐藏外层标题
function CastBar:New()
	local f = self.super.New(self, "cast")
	f:SetFrameStrata("HIGH")

	if not f.cast then
		f.cast = CastingBar:New(f)
		f.header:SetParent(nil)
		f.header:ClearAllPoints()
		f:SetWidth(240)
		f:SetHeight(24)
	end

	f:UpdateText()
	f:Layout()

	return f
end

function CastBar:GetDefaults()
	return {
		point = "CENTER",
		x = 0,
		y = 30,
		showText = true
	}
end

function CastBar:ToggleText(enable)
	self.sets.showText = enable or nil
	self:UpdateText()
end

function CastBar:UpdateText()
	if self.sets.showText then
		self.cast.time:Show()
	else
		self.cast.time:Hide()
	end
	self.cast:AdjustWidth()
end

function CastBar:CreateMenu()
	local menu = self.menu or Dominos:NewMenu(self.id)
	local panel = menu:NewPanel(LibStub("AceLocale-3.0"):GetLocale("Dominos-Config").Layout)

	local time = panel:NewCheckButton(L.ShowTime)
	time:SetScript("OnClick", function(b) self:ToggleText(b:GetChecked()) end)
	time:SetScript("OnShow", function(b) b:SetChecked(self.sets.showText) end)

	panel:NewOpacitySlider()
	panel:NewFadeSlider()
	panel:NewScaleSlider()
	panel:NewPaddingSlider()

	self.menu = menu
end

-- 布局：依据内部施法条宽度与内边距调整外层框架尺寸（最小 8）
function CastBar:Layout()
	self:SetWidth(max(self.cast:GetWidth() + 4 + self:GetPadding() * 2, 8))
	self:SetHeight(max(24 + self:GetPadding() * 2, 8))
end

--[[ CastingBar Object ]]--
-- 内层施法条本体 CastingBar：继承 StatusBar，直接复用暴雪原生施法条的绘制/事件逻辑
CastingBar = Dominos:CreateClass("StatusBar")

--omg speed
local BORDER_SCALE = 197 / 150 --its magic!
local TEXT_PADDING = 18

-- 创建施法条对象：以动态全局名 DominosCastingBar 实例化模板，并缓存时间/文本/边框/闪光子部件
function CastingBar:New(parent)
	local f = self:Bind(CreateFrame("StatusBar", "DominosCastingBar", parent, "DominosCastingBarTemplate"))
	f:SetPoint("CENTER")

	local name = f:GetName()
	local _G = _G
	f.time = _G[name .. "Time"]
	f.text = _G[name .. "Text"]
	f.borderTexture = _G[name .. "Border"]
	f.flashTexture = _G[name .. "Flash"]

	f.normalWidth = f:GetWidth()
	f:SetScript("OnUpdate", f.OnUpdate)
	f:SetScript("OnEvent", f.OnEvent)

	return f
end

-- 施法事件：先交给原生处理，再按事件类型标记施法失败/中断，并刷新颜色
function CastingBar:OnEvent(event, ...)
	CastingBarFrame_OnEvent(self, event, ...)

	local unit, spell = ...
	if unit == self.unit then
		if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
			self.failed = true
		elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
			self.failed = nil
		end
		self:UpdateColor(spell)
	end
end

-- 每帧更新：调用原生刷新进度，并更新剩余/已用时间文本，随后触发宽度自适应
function CastingBar:OnUpdate(elapsed)
	CastingBarFrame_OnUpdate(self, elapsed)

	if self.casting then
		self.time:SetFormattedText("%.1f", self.maxValue - self.value)
		self:AdjustWidth()
	elseif self.channeling then
		self.time:SetFormattedText("%.1f", self.value)
		self:AdjustWidth()
	end
end

-- 宽度自适应：按“技能名 + 时间”文本宽度调整自身及边框/闪光贴图宽度，使长技能名不被截断
function CastingBar:AdjustWidth()
	local textWidth = self.text:GetStringWidth() + TEXT_PADDING
	local timeWidth = (self.time:IsShown() and (self.time:GetStringWidth() + 4) * 2) or 0
	local width = textWidth + timeWidth

	local diff = width - self.normalWidth
	if diff > 0 then
		diff = width - self:GetWidth()
	else
		diff = self.normalWidth - self:GetWidth()
	end

	if diff ~= 0 then
		local newWidth = self:GetWidth() + diff
		self:SetWidth(newWidth)
		self.borderTexture:SetWidth(newWidth * BORDER_SCALE)
		self.flashTexture:SetWidth(newWidth * BORDER_SCALE)

		self:GetParent():Layout()
	end
end

-- 颜色区分：失败/中断=红，增益法术=绿，减益法术=紫，其它=橙
function CastingBar:UpdateColor(spell)
	if self.failed then
		self:SetStatusBarColor(0.86, 0.08, 0.24)
	elseif spell and IsHelpfulSpell(spell) then
		self:SetStatusBarColor(0.31, 0.78, 0.47)
	elseif spell and IsHarmfulSpell(spell) then
		self:SetStatusBarColor(0.63, 0.36, 0.94)
	else
		self:SetStatusBarColor(1, 0.7, 0)
	end
end