--[[
	bindableButton.lua
		An abstract button class used to allow keybound to work transparently on both the stock blizzard bindings, and click bindings
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
		抽象的按钮类 BindableButton（继承 CheckButton），用于让 LibKeyBound
		能透明地同时处理暴雪原生按键绑定与点击绑定（CLICK 绑定），
		并向按钮显示快捷键文本（HotKey 字体串）。

	内部标识说明：
		对外改名为 MyDominos335，但本文件仍向全局表 Dominos 挂载
		Dominos.BindableButton，内部标识仍为 Dominos。

	关键依赖：
		- core：Dominos.lua（CreateClass）。
		- 库：LibKeyBound-1.0（将按键映射转成短标题 ToShortKey）。
		- 使用全局 API：GetBindingKey / GetBindingText / SetBinding /
		  SetBindingClick（3.3.5 旧 API）。

	被使用：
		modules 中的动作按钮实例作为其绑定对象，调用 UpdateHotkey / GetBindings /
		SetKey / ClearBindings 等。
]]
assert(Dominos, "Dominos not found!")
local Dominos = Dominos

local BindableButton = Dominos:CreateClass('CheckButton')
Dominos.BindableButton = BindableButton

local KeyBound = LibStub('LibKeyBound-1.0')
local _G = _G

-- 更新按钮的快捷键文字：约定所有快捷键字体串命名都遵循 <按钮名>HotKey 规则。
-- 当显示绑定文字开关打开且存在绑定时显示按键，否则清空字体串并隐藏
-- （清空是为了覆盖 RANGE_INDICATOR 等非空内容）。
--there's a nice assumption here: all hotkey text will use the same naming convention
--the call here is wacky because this functionality is actually called for the blizzard buttons _before_ I'm able to bind the action button methods to them
function BindableButton:UpdateHotkey(buttonType)
	local key = BindableButton.GetHotkey(self, buttonType)
	if key ~= ''  and Dominos:ShowBindingText() then
		_G[self:GetName()..'HotKey']:SetText(key)
		_G[self:GetName()..'HotKey']:Show()
	else
		_G[self:GetName()..'HotKey']:SetText('') --blank out non blank text, such as RANGE_INDICATOR
		_G[self:GetName()..'HotKey']:Hide()
	end
end

-- 返回按钮应显示的快捷键：优先取暴雪按键绑定，其次取点击（CLICK）绑定，
-- 再经 LibKeyBound 的 ToShortKey 转成简短标题；无绑定时返回空串。
--returns what hotkey to display for the button
function BindableButton:GetHotkey(buttonType)
	local key = BindableButton.GetBlizzBindings(self, buttonType) or BindableButton.GetClickBindings(self)
	return key and KeyBound:ToShortKey(key) or ''
end

--returns all blizzard bindings assigned to the button
function BindableButton:GetBlizzBindings(buttonType)
	buttonType = buttonType or self.buttonType
	if buttonType then
		local id = self:GetAttribute('bindingid') or self:GetID()
		return GetBindingKey(buttonType .. id)
	end
end

--returns all click bindings assigned to the button
function BindableButton:GetClickBindings()
	return GetBindingKey(format('CLICK %s:LeftButton', self:GetName()))
end

--returns a comma separated list of all bindings for the given action button
--used for keybound support
local function getKeyStrings(...)
	local keys
	for i = 1, select('#', ...) do
		local key = select(i, ...)
		if keys then
			keys = keys .. ", " .. GetBindingText(key, "KEY_")
		else
			keys = GetBindingText(key, "KEY_")
		end
	end
	return keys
end

-- 汇总该按钮的全部绑定为逗号分隔的可读文本（暴雪绑定在前、点击绑定在后），
-- 供 LibKeyBound 提示或调试展示使用。
function BindableButton:GetBindings()
	local blizzKeys = getKeyStrings(self:GetBlizzBindings())
	local clickKeys = getKeyStrings(self:GetClickBindings())

	if blizzKeys then
		if clickKeys then
			return blizzKeys .. ', ' .. clickKeys
		end
		return blizzKeys
	else
		return clickKeys
	end
end

-- 为按钮设置按键绑定：有 buttonType（暴雪动作按钮）时绑到 类型+id，
-- 否则绑成对该按钮本体的点击（CLICK）绑定。
--set bindings (more keybound support)
function BindableButton:SetKey(key)
	if self.buttonType then
		local id = self:GetAttribute('bindingid') or self:GetID()
		SetBinding(key, self.buttonType .. id)
	else
		SetBindingClick(key, self:GetName(), 'LeftButton')
	end
end

--clears all bindings from the button (keybound support again)
local function ClearBindings(...)
	for i = 1, select('#', ...) do
		SetBinding(select(i, ...), nil)
	end
end

function BindableButton:ClearBindings()
	ClearBindings(self:GetBlizzBindings())
	ClearBindings(self:GetClickBindings())
end