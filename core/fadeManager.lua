--[[
fadeManager.lua
Handles fading out frames when not moused over
Necessary since using the blizzard fading functions can cause issues in combat
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
		淡出管理器：当鼠标不悬停在框架上时，把框架透明度平滑过渡到其
		期望值（GetExpectedAlpha）。因暴雪自带的淡出函数在战斗中可能出问题，
		故自行实现基于 OnUpdate 的定时轮询与线性插值淡出。

	内部标识说明：
		对外改名为 MyDominos335，但本文件仍向全局表 Dominos 挂载
		Dominos.FadeManager，内部标识仍为 Dominos。

	关键依赖：
		- core：Dominos.lua（全局表）。被管理的框架需实现 GetExpectedAlpha/GetAlpha。
		- 使用全局 API：CreateFrame / SetScript / SetAlpha（3.3.5 旧 API）。

	被使用：
		core/frame.lua 的 Frame:UpdateFader / Frame:Free 通过
		FadeManager:Add / FadeManager:Remove 注册或注销需要淡出的框架。
]]
assert(Dominos, "Dominos not found!")
local Dominos = Dominos

local FadeManager = {}
Dominos.FadeManager = FadeManager

local FadeWatcher = CreateFrame("Frame")
local Fader = CreateFrame("Frame")

--[[ Registers Frames for Fading ]]--
-- 注册/注销需要自动淡出的框架：Add 加入监视集合（并唤醒监视器），
-- Remove 移除。对应的实际逻辑在下方 watcher 的 Add/Remove 中实现。
function FadeManager:Add(f)
	FadeWatcher:Add(f)
end

function FadeManager:Remove(f)
	FadeWatcher:Remove(f)
end

--[[ Watch Frames For Fade Changing ]]--
-- 监视器：以固定间隔（DELAY=0.12 秒）轮询被登记的框架，
-- 若其期望透明度（GetExpectedAlpha）与当前透明度（GetAlpha）差异大于 0.01，
-- 就交给 Fader 做 0.1 秒的线性淡入/淡出。watchedFrames 为空时自动隐藏该帧。
do
	local watchedFrames = {}

	FadeWatcher:Hide()
	FadeWatcher.nextUpdate = 0
	FadeWatcher.DELAY = 0.12

	FadeWatcher:SetScript("OnUpdate", function(self, elapsed)
		if not next(watchedFrames) then
			self:Hide()
		end

		self.nextUpdate = self.nextUpdate - elapsed
		if self.nextUpdate < 0 then
			self.nextUpdate = self.DELAY
			for f in pairs(watchedFrames) do
				local expectedAlpha, currentAlpha = f:GetExpectedAlpha(), f:GetAlpha()
				if abs(expectedAlpha - currentAlpha) > 0.01 then
					Fader:Fade(f, 0.1, currentAlpha, expectedAlpha)
				end
			end
		end
	end)

	FadeWatcher:SetScript("OnHide", function(self) self.nextUpdate = 0 end)

	function FadeWatcher:Add(f)
		watchedFrames[f] = true
		self:Show()
	end

	function FadeWatcher:Remove(f)
		watchedFrames[f] = nil
	end
end

--[[ Handle Fading ]]--
-- 淡出执行器：对 fadingFrames 中每个框架，按经过时间在起始与结束透明度间
-- 做线性插值；到达时间上限后落到 endAlpha 并移出列表。列表为空时隐藏本帧。
do
	local fadingFrames = {}

	Fader:Hide()

	Fader:SetScript("OnUpdate", function(self, elapsed)
		if not next(fadingFrames) then
			self:Hide()
		end

		for frame, fadeInfo in pairs(fadingFrames) do
			fadeInfo.fadeTimer = (fadeInfo.fadeTimer or 0) + elapsed

			if fadeInfo.fadeTimer < fadeInfo.timeToFade then
				local pct = fadeInfo.fadeTimer / fadeInfo.timeToFade
				local delta = fadeInfo.endAlpha - fadeInfo.startAlpha

				frame:SetAlpha(fadeInfo.startAlpha + pct * delta)
			else
				frame:SetAlpha(fadeInfo.endAlpha)
				fadingFrames[frame] = nil
			end
		end
	end)

	-- 启动一段淡入/淡出：立即设为起始透明度，并把淡出信息挂到 frame.fadeInfo，
	-- 加入 fadingFrames 由 OnUpdate 逐帧插值；若该帧已在淡出列表中则不重复添加。
	function Fader:Fade(frame, timeToFade, startAlpha, endAlpha)
		frame:SetAlpha(startAlpha)

		if not fadingFrames[frame] then
			local fadeInfo = frame.fadeInfo or {}
			fadeInfo.timeToFade = timeToFade
			fadeInfo.startAlpha = startAlpha
			fadeInfo.endAlpha = endAlpha
			fadeInfo.fadeTimer = 0
			frame.fadeInfo = fadeInfo

			fadingFrames[frame] = fadeInfo
			self:Show()
		end
	end
end