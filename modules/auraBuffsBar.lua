--[[--------------------------------------------------------------------
auraBuffsBar.lua —— 玩家增益(Buff)条模块（模块注册名："Buffs"）

职责：
	接管暴雪原生光环显示，在可自由摆放的框架内创建并排列玩家的有益光环按钮，
	每个按钮按 UnitAura(player, i, "HELPFUL") 的结果更新图标、层数、计时与冷却。

模块注册名：Dominos:NewModule("Buffs")
	说明：插件对外名为 MyDominos335，但内部标识仍沿用经典 Dominos，
	故全局表仍为 Dominos、存档仍为 DominosDB，
	动态创建的按钮全局名仍为 "DominosBuff<i>"。

依赖与前置条件（OnInitialize）：
	仅当 Dominos:UseAuras() 为真时启用，并会 Hide() 暴雪自带 BuffFrame；
	否则调用 self:Disable() 停用本模块。

注意事项：
	面向 3.3.5a（Interface 30300）旧 API；计时依赖暴雪 CooldownFrame_SetTimer
	与全局 AuraButton_OnUpdate（来自 BuffButton 模板）。
]]--
assert(Dominos, "Dominos not found!")
local Dominos = Dominos

local BuffsModule = Dominos:NewModule("Buffs")
local BuffsFrame = Dominos:CreateClass("Frame", Dominos.Frame)
local L

-- 初始化：仅在 Dominos:UseAuras() 为真时接管，并隐藏暴雪原生 BuffFrame；
-- 否则 Disable() 停用本模块。
function BuffsModule:OnInitialize()
	if Dominos:UseAuras() then
		BuffFrame:Hide()
	else
		self:Disable()
	end
end

function BuffsModule:Load()
    self.frame = BuffsFrame:New()
end

function BuffsModule:Unload()
	if self.frame then
		self.frame:Free()
	end
end

-- 用 Masque 皮肤美化按钮（"Buffs" 为本模块在 Dominos:Masque 中的分组名）。
function BuffsFrame:SkinButton(btn)
	return Dominos:Masque("Buffs", btn)
end

function BuffsFrame:New()
    local f = self.super.New(self, "buffs")
    if not self.buffs then
        f:CreateBuffs()
        f:SetFrameStrata("LOW")
    end

    f:LoadButtons()
    f:Layout()
    return f
end

function BuffsFrame:GetDefaults()
    return {scale = 1, point = "CENTER", numButtons = 36, y = 0, x = 0}
end

function BuffsFrame:NumButtons()
    return self.sets.numButtons or 36
end

function BuffsFrame:AddButton(i)
	local b = self.buffs[i]
	if not b then return end
	b:SetParent(self.header)
	self:SkinButton(b)
	self.buttons[i] = b
end

function BuffsFrame:RemoveButton(i)
    local b = self.buttons[i]
    if not b then return end
    b:SetParent(nil)
    b:Hide()
    self.buttons[i] = nil
end

-- 预创建 36 个 Buff 按钮（数量上限），后续按需启用/禁用。
function BuffsFrame:CreateBuffs()
    self.buffs = self.buffs or {}
    for i = 1, 36 do
        self.buffs[i] = self.buffs[i] or self:CreateBuff(i)
    end
end

-- 每帧累加经过时间，超过 0.01 秒才刷新一次，避免每帧都调用 UnitAura。
local lastUpdated = 0
local function OnUpdate(self, elapsed)
	lastUpdated = lastUpdated + elapsed
	if lastUpdated > 0.01 then
		lastUpdated = 0
		for i = 1, self:NumButtons() do
			self:UpdateBuff(i, elapsed)
		end
	end
end

-- 创建一个 Buff 按钮：动态全局名为 "DominosBuff<id>"（沿用经典 Dominos 命名），
-- 模板 BuffButtonTemplate + TargetBuffFrameTemplate；左键点击取消该增益。
function BuffsFrame:CreateBuff(id)
    local frameName = "DominosBuff" .. id
    local buff = CreateFrame("Button", frameName, UIParent, "BuffButtonTemplate, TargetBuffFrameTemplate")
    buff:SetSize(34, 34)
    buff.icon = _G[frameName .. "Icon"]
    buff.icon:SetTexCoord(.1, .9, .1, .9)
    buff:SetScript("OnClick", function() CancelUnitBuff("player", id, "HELPFUL") end)
    buff.cooldown = _G[frameName .. "Cooldown"]
    self:SetScript("OnUpdate", OnUpdate)
    return buff
end

-- 更新第 id 个 Buff 按钮：以 "HELPFUL" 过滤调用 AuraButtonUpdate。
function BuffsFrame:UpdateBuff(id, elapsed)
	local buff = self.buffs[id]
	if not buff then return end
	BuffsFrame:AuraButtonUpdate(buff:GetName(), id, "HELPFUL")
	buff.id = id
end

local function AddSizeSlider(p)
    L = L or LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")
    local size = p:NewSlider(L.Size, 1, 1, 1)
    size.OnShow = function(self)
        self:SetMinMaxValues(1, 36)
        self:SetValue(self:GetParent().owner:NumButtons())
    end
    size.UpdateValue = function(self, value)
        self:GetParent().owner:SetNumButtons(value)
        _G[self:GetParent():GetName() .. L.Columns]:OnShow()
    end
end

local function AddLayoutPanel(menu)
    L = L or LibStub("AceLocale-3.0"):GetLocale("Dominos-Config")
    local p = menu:NewPanel(L.Layout)
    p:NewOpacitySlider()
    p:NewFadeSlider()
    p:NewScaleSlider()
    p:NewPaddingSlider()
    p:NewSpacingSlider()
    p:NewColumnsSlider()
    AddSizeSlider(p)
end

local function AddAdvancedLayout(self)
    self:AddAdvancedPanel()
end

function BuffsFrame:CreateMenu()
    local menu = self.menu or Dominos:NewMenu(self.id)
    AddLayoutPanel(menu)
    AddAdvancedLayout(menu)
    self.menu = menu
end

-- 核心更新函数：读取 UnitAura 返回值并驱动按钮显示。
-- UnitAura(unit, index, filter) 返回：
--   name, rank, texture, count, debuffType, duration, expirationTime
--   name 为 nil 表示该槽位无光环 -> 隐藏按钮。
-- 处理内容：隐藏暴雪合并后的增益框 ConsolidatedBuffs、图标与层数、
--   有限时长时的冷却扇形计时与剩余秒数文字、鼠标悬停时的提示。
function BuffsFrame:AuraButtonUpdate(buttonName, index, filter)
	if ConsolidatedBuffs:IsShown() then
		ConsolidatedBuffs:Hide()
	end

    local unit = "player"
    local name, rank, texture, count, debuffType, duration, expirationTime = UnitAura(unit, index, filter)
    local buffName = buttonName
    local buff = _G[buffName]

    if not name then
        -- hide the buff button if it exists
        if buff then
            buff:Hide()
            buff.duration:Hide()
        end
        return nil
    end

    -- Setup Buff
    buff:SetID(index)
    buff.unit = unit
    buff.filter = filter
    buff:SetAlpha(1.0)
    buff.exitTime = nil
    buff:Show()

    if duration > 0 and expirationTime then
        buff.cooldown:Show()
        CooldownFrame_SetTimer(buff.cooldown, expirationTime - duration, duration, 1)

        if SHOW_BUFF_DURATIONS == "1" then
            buff.duration:Show()
        else
            buff.duration:Hide()
        end

        if not buff.timeLeft then
            buff.timeLeft = expirationTime - GetTime()
            buff:SetScript("OnUpdate", AuraButton_OnUpdate)
        else
            buff.timeLeft = expirationTime - GetTime()
        end
        buff.expirationTime = expirationTime
    else
        buff.cooldown:Hide()
        buff.duration:Hide()
        if buff.timeLeft then
            buff:SetScript("OnUpdate", nil)
        end
        buff.timeLeft = nil
    end

    -- set the buff count
    buff.count:SetText(count > 1 and count or "")
    buff.icon:SetTexture(texture)

    if GameTooltip:IsOwned(buff) then
        GameTooltip_SetDefaultAnchor(GameTooltip, buff)
        GameTooltip:SetUnitAura("player", index, filter)
    end
    return 1
end