--[[
	MyDominos335（内部标识仍为 Dominos）—— 载具条模块 vehicleBar.lua

	负责载具条：复用暴雪载具菜单栏的 VehicleMenuBarLeaveButton（离开载具）与
	VehicleMenuBarPitchUpButton / VehicleMenuBarPitchDownButton（俯仰按钮）。条继承 core 的
	Dominos.Frame。

	关键依赖：
		- 通过 Dominos 皮肤数据（GetSkinData）给三个按钮套皮（见 ApplySkin）
		- 监听 UNIT_ENTERED_VEHICLE / UNIT_ENTERING_VEHICLE 事件以更新按钮显隐
		- 语言键取自 "Dominos"

	注意事项：
		- 内部标识仍为 Dominos。
		- 面向 3.3.5a（Interface 30300）旧 API（IsVehicleAimAngleAdjustable / CanExitVehicle 等）。
--]]

assert(Dominos, "Dominos not found!")
local Dominos = Dominos

local VehicleBar = Dominos:CreateClass("Frame", Dominos.Frame)
Dominos.VehicleBar = VehicleBar

local L = LibStub("AceLocale-3.0"):GetLocale("Dominos")
-- 复用暴雪载具菜单栏的三个按钮：离开、俯仰向上、俯仰向下
local buttons = {VehicleMenuBarLeaveButton, VehicleMenuBarPitchUpButton, VehicleMenuBarPitchDownButton}

function VehicleBar:New()
	local f = self.super.New(self, "vehicle", L.TipVehicleBar)
	f:SkinButtons()
	f:LoadButtons()
	f:Layout()
	f:SetScript("OnEvent", f.OnEvent)
	f:RegisterEvent("UNIT_ENTERED_VEHICLE")
	f:RegisterEvent("UNIT_ENTERING_VEHICLE")

	return f
end

function VehicleBar:OnEvent(event, arg1)
	if event == "UNIT_ENTERED_VEHICLE" then
		if arg1 == "player" then
			self:UpdateButtonVisibility()
		end
	end
end

-- 按载具能力更新显隐：可调俯仰角才显示俯仰按钮；可离开载具才显示离开按钮
function VehicleBar:UpdateButtonVisibility()
	if IsVehicleAimAngleAdjustable() then
		_G["VehicleMenuBarPitchUpButton"]:Show()
		_G["VehicleMenuBarPitchDownButton"]:Show()
	else
		_G["VehicleMenuBarPitchUpButton"]:Hide()
		_G["VehicleMenuBarPitchDownButton"]:Hide()
	end

	if CanExitVehicle() then
		_G["VehicleMenuBarLeaveButton"]:Show()
	else
		_G["VehicleMenuBarLeaveButton"]:Hide()
	end
end

-- 依次给三个载具按钮套用皮肤
function VehicleBar:SkinButtons()
	self:ApplySkin("PitchUpButton")
	self:ApplySkin("PitchDownButton")
	self:ApplySkin("LeaveButton")
end

-- 取该按钮的皮肤数据并套用：统一尺寸为 30x30，按数据替换普通/按下贴图及纹理坐标
function VehicleBar:ApplySkin(frameName)
	local skin = self:GetSkinData(frameName)
	local frame = _G["VehicleMenuBar" .. frameName]
	frame:SetWidth(30)
	frame:SetHeight(30)

	if skin.normalTexture then
		frame:GetNormalTexture():SetTexture(skin.normalTexture)
		frame:GetNormalTexture():SetTexCoord(unpack(skin.normalTexCoord))
	end

	if skin.pushedTexture then
		frame:GetPushedTexture():SetTexture(skin.pushedTexture)
		frame:GetPushedTexture():SetTexCoord(unpack(skin.pushedTexCoord))
	end

	if skin.texture then
		frame:SetTexture(skin.texture)
		frame:SetTexCoord(unpack(skin.texCoord))
	end
end

-- 返回三个载具按钮各自的皮肤数据（尺寸、锚点、贴图路径与纹理坐标）
function VehicleBar:GetSkinData(frameName)
	if frameName == "PitchUpButton" then
		return {
			--Pitch up button
			height = 36,
			width = 38,
			point = "BOTTOMLEFT",
			xOfs = 146,
			yOfs = 41,
			normalTexture = [[Interface\Vehicles\UI-Vehicles-Button-Pitch-Up]],
			normalTexCoord = {0.21875, 0.765625, 0.234375, 0.78125},
			pushedTexture = [[Interface\Vehicles\UI-Vehicles-Button-Pitch-Down]],
			pushedTexCoord = {0.21875, 0.765625, 0.234375, 0.78125},
			pitchHidden = 1
		}
	elseif frameName == "PitchDownButton" then
		return {
			--Pitch up button
			height = 36,
			width = 38,
			point = "BOTTOMLEFT",
			xOfs = 146,
			yOfs = 3,
			normalTexture = [[Interface\Vehicles\UI-Vehicles-Button-PitchDown-Up]],
			normalTexCoord = {0.21875, 0.765625, 0.234375, 0.78125},
			pushedTexture = [[Interface\Vehicles\UI-Vehicles-Button-PitchDown-Down]],
			pushedTexCoord = {0.21875, 0.765625, 0.234375, 0.78125},
			pitchHidden = 1
		}
	elseif frameName == "LeaveButton" then
		return {
			--Leave button
			height = 47,
			width = 50,
			point = "BOTTOMRIGHT",
			xOfs = -148,
			yOfs = 18,
			normalTexture = [[Interface\Vehicles\UI-Vehicles-Button-Exit-Up]],
			normalTexCoord = {0.140625, 0.859375, 0.140625, 0.859375},
			pushedTexture = [[Interface\Vehicles\UI-Vehicles-Button-Exit-Down]],
			pushedTexCoord = {0.140625, 0.859375, 0.140625, 0.859375}
		}
	end
end

function VehicleBar:GetDefaults()
	return {point = "CENTER", x = -244, y = 0, numButtons = #buttons}
end

function VehicleBar:AddButton(i)
	local b = buttons[i]
	b:SetParent(self.header)
	b:Show()

	self.buttons[i] = b
end

function VehicleBar:RemoveButton(i)
	local b = self.buttons[i]
	b:SetParent(nil)
	b:Hide()

	self.buttons[i] = nil
end

-- 载具条显隐条件：存在载具目标时显示，否则隐藏
function VehicleBar:GetShowStates()
	return "[target=vehicle,exists]show;hide"
end