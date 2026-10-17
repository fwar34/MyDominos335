--[[
drag.lua
A Dominos frame component that controls frame movement
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
	文件用途 / 架构角色：
		定义一个覆盖在 Dominos 框架之上的可拖动按钮（DragFrame），
		负责框架的移动、缩放提示与解锁后的交互（拖动、滚轮改透明度、
		右键菜单、隐藏/显示切换）。仅在框架解锁时显示。

	内部标识说明：
		对外改名为 MyDominos335，但本文件仍向全局表 Dominos 挂载
		Dominos.DragFrame，内部标识仍为 Dominos。

	关键依赖：
		- core：Dominos.lua（CreateClass、Locked、Frame 交互）。
		- 库：AceLocale-3.0（语言键 "Dominos"）。

	被使用：
		core/frame.lua 的 Frame:Create 中通过 Dominos.DragFrame:New(f) 为每个框架
		创建拖动手柄，并调用其 Hide/Show/SetScale/UpdateColor 等。
]]
assert(Dominos, "Dominos not found!")
local Dominos = Dominos

local Drag = Dominos:CreateClass("Button")
Dominos.DragFrame = Drag

local L = LibStub("AceLocale-3.0"):GetLocale("Dominos")

--constructor（为 owner 框架创建一个覆盖其上的拖动手柄，层级略高于框架本身）
function Drag:New(owner)
	local f = self:Bind(CreateFrame("Button", nil, UIParent))
	f.owner = owner

	f:EnableMouseWheel(true)
	f:SetClampedToScreen(true)
	f:SetFrameStrata(owner:GetFrameStrata())
	f:SetAllPoints(owner)
	f:SetFrameLevel(owner:GetFrameLevel() + 5)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(1, 1, 1, 0.4)
	bg:SetAllPoints(f)
	f:SetNormalTexture(bg)

	local t = f:CreateTexture(nil, "BACKGROUND")
	t:SetTexture(0.2, 0.3, 0.4, 0.5)
	t:SetAllPoints(f)
	f:SetHighlightTexture(t)

	f:SetNormalFontObject("GameFontNormalLarge")
	f:SetText(owner.id)

	f:RegisterForClicks("AnyUp")
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnMouseDown", self.StartMoving)
	f:SetScript("OnMouseUp", self.StopMoving)
	f:SetScript("OnMouseWheel", self.OnMouseWheel)
	f:SetScript("OnClick", self.OnClick)
	f:SetScript("OnEnter", self.OnEnter)
	f:SetScript("OnLeave", self.OnLeave)
	f:Hide()

	return f
end

function Drag:OnEnter()
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(format("Bar: %s", self:GetText():gsub("^%l", string.upper)), 1, 1, 1)

	local tooltipText = self.owner:GetTooltipText()
	if tooltipText then
		GameTooltip:AddLine(tooltipText .. "\n", nil, nil, nil, nil, 1)
	end

	if self.owner.ShowMenu then
		GameTooltip:AddLine(L.ShowConfig)
	end

	if self.owner:IsShown() then
		GameTooltip:AddLine(L.HideBar)
	else
		GameTooltip:AddLine(L.ShowBar)
	end

	GameTooltip:AddLine(format(L.SetAlpha, ceil(self.owner:GetFrameAlpha() * 100)))
	GameTooltip:Show()
end

function Drag:OnLeave()
	GameTooltip:Hide()
end

-- 左键按下开始拖动所属框架（移动期间隐藏提示框）。
-- 松开时停止移动并调用 owner:Stick() 触发贴靠吸附，随后刷新提示框。
function Drag:StartMoving(button)
	if button == "LeftButton" then
		self.isMoving = true
		self.owner:StartMoving()

		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end
end

function Drag:StopMoving()
	if self.isMoving then
		self.isMoving = nil
		self.owner:StopMovingOrSizing()
		self.owner:Stick()
		self:OnEnter()
	end
end

-- 滚轮调整所属框架透明度，每次 ±0.1 并钳制在 [0,1]，变化后刷新提示框文本。
function Drag:OnMouseWheel(arg1)
	local newAlpha = min(max(self.owner:GetAlpha() + (arg1 * 0.1), 0), 1)
	if newAlpha ~= self.owner:GetAlpha() then
		self.owner:SetFrameAlpha(newAlpha)
		self:OnEnter()
	end
end

-- 点击行为（解锁时）：右键=打开分栏菜单（Shift 时切换显隐），
-- 中键=切换显隐；处理完刷新提示框。
function Drag:OnClick(button)
	if button == "RightButton" then
		if IsShiftKeyDown() then
			self.owner:ToggleFrame()
		else
			self.owner:ShowMenu()
		end
	elseif button == "MiddleButton" then
		self.owner:ToggleFrame()
	end
	self:OnEnter()
end

-- 根据框架的显示状态与是否已贴靠其他框架，刷新拖动手柄的底色：
-- 显示中→青色系（贴靠后偏暗青），隐藏中→灰色系（贴靠后偏黑），
-- 便于在解锁界面中一眼区分各条的状态。
--updates the drag button color of a given bar if its attached to another bar
function Drag:UpdateColor()
	if self.owner:IsShown() then
		if self.owner:GetAnchor() then
			self:GetNormalTexture():SetTexture(0, 0.2, 0.2, 0.4)
		else
			self:GetNormalTexture():SetTexture(0, 0.5, 0.7, 0.4)
		end
	else
		if self.owner:GetAnchor() then
			self:GetNormalTexture():SetTexture(0.1, 0.1, 0.1, 0.4)
		else
			self:GetNormalTexture():SetTexture(0.5, 0.5, 0.5, 0.4)
		end
	end
end