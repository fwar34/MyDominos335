--[[--------------------------------------------------------------------
minimapZoneTextBar.lua —— 小地图区域文字模块（模块注册名："Zone-Text"）

职责：
	把暴雪的小地图区域名称按钮 MinimapZoneTextButton 改挂到自建的全局框架
	"ZoneText" 下，使其成为可自由摆放的独立元素（区域名/坐标文字随之移动）。

模块注册名：Dominos:NewModule("Zone-Text")
	说明：插件对外名为 MyDominos335，但内部标识仍沿用经典 Dominos；
	本模块与 minimapBar.lua 同属小地图体系，共用 Dominos:UseMinimap() 开关。

依赖与前置条件（OnInitialize）：
	需要 Dominos:UseMinimap() 为真，否则 self:Disable() 停用。
]]--
assert(Dominos, "Dominos not found!")
local Dominos = Dominos

-- 模块注册名为 "Zone-Text"；zoneText 为承载区域文字的全局框架 "ZoneText"。
local mod = Dominos:NewModule("Zone-Text")
local class = Dominos:CreateClass("Frame", Dominos.Frame)
local zoneText = CreateFrame("Frame", "ZoneText", UIParent)

local menuButtons = {}
do
    local loadButtons = function(...)
        for i = 1, select("#", ...) do
            local btn = select(i, ...)
            if btn and btn.GetName then
                tinsert(menuButtons, btn)
            end
        end
    end

	-- 初始化：仅在 Dominos:UseMinimap() 为真时接管，把区域名按钮改挂到 zoneText 下，
	-- 并收集 zoneText 的子控件（带 GetName 的）作为可布局按钮；否则 Disable() 停用。
	function mod:OnInitialize()
		if Dominos:UseMinimap() then
			MinimapZoneTextButton:SetParent(zoneText)
			loadButtons(zoneText:GetChildren())
		else
			self:Disable()
		end
	end
end

-- 加载：创建本模块的可布局框架实例。
function mod:Load()
    self.frame = class:New()
    self.frame:SetFrameStrata("LOW")
end

function mod:Unload()
    if self.frame then
		self.frame:Free()
    end
end

-- 创建本模块的可布局框架实例（框架 id 为 "Zone-Text"）。
function class:New()
    local f = self.super.New(self, "Zone-Text")
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
    if not btn then
        return
    end
    btn:SetParent(self.header)
    btn:Show()
    self.buttons[i] = btn
end

function class:RemoveButton(i)
    local btn = self.buttons[i]
    if not btn then
        return
    end
    btn:SetParent(nil)
    btn:Hide()
    self.buttons[i] = nil
end

local function AddLayoutPanel(menu)
    local p = menu:NewPanel(LibStub("AceLocale-3.0"):GetLocale("Dominos-Config").Layout)
    p:NewPaddingSlider()
    p:NewOpacitySlider()
    p:NewFadeSlider()
    p:NewScaleSlider()
end

local function AddShowState(self)
    local L = LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")
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

-- 构建配置菜单：布局面板 + 显示状态设置。
function class:CreateMenu()
    local menu = self.menu or Dominos:NewMenu(self.id)
    AddLayoutPanel(menu)
    AddShowState(menu)
    self.menu = menu
end