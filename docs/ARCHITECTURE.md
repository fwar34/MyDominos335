# MyDominos335 架构说明

本文说明 `MyDominos335` 的代码组织、加载流程、核心对象模型与关键机制，帮助阅读与二次开发。
阅读前建议先看 [README.md](../README.md) 了解项目背景与命名规则。

---

## 一、总体分层

```
┌─────────────────────────────────────────────────────────┐
│                     游戏客户端 3.3.5a                     │
└─────────────────────────────────────────────────────────┘
                ▲                          ▲
        (接管暴雪原生框架)            (通过事件 / 状态驱动)
                │                          │
┌───────────────┴──────────────────────────┴──────────────┐
│                        modules/                          │
│  actionBar / petBar / classBar / bagBar / menuBar / ...  │
│  （每个条 = 一个 Frame 实例 + 若干 Button）               │
└───────────────▲──────────────────────────────────────────┘
                │ 继承 Frame 基类
┌───────────────┴──────────────────────────────────────────┐
│                         core/                            │
│  Dominos.lua   主驱动 / 模块注册 / 配置档案 / 斜杠命令    │
│  frame.lua     Frame 通用容器（布局/缩放/透明/贴靠/显隐） │
│  drag.lua      拖拽遮罩                                   │
│  fadeManager   淡出管理器                                 │
│  bindableButton 抽象按钮（KeyBound 支持）                 │
│  minimap.lua   圆形小地图按钮                             │
└───────────────▲──────────────────────────────────────────┘
                │ 依赖
┌───────────────┴──────────────────────────────────────────┐
│   libs/  Ace3 · LibStub · LibKeyBound · LibSharedMedia    │
│          LibDataBroker · FlyPaper ...                     │
└──────────────────────────────────────────────────────────┘
```

要点：

- **core 层**提供与具体界面无关的通用能力；**modules 层**在其之上构建具体的条。
- 所有条都继承自 `Dominos.Frame`，绝大多数「布局 / 缩放 / 透明度 / 贴靠 / 显隐状态」逻辑在 core 中实现，
  modules 只需实现「按钮从哪来」「按钮数量是多少」「默认设置是什么」等少量差异。
- 设置界面由独立插件 `MyDominos335_Config` 提供，通过 `LoadAddOn` 按需加载，不属于 core。

---

## 二、加载流程

### 2.1 文件加载顺序（由 XML 决定）

`MyDominos335.toc` 依次加载 4 个 xml：

```
libs\_load.xml       → 第三方库
locales\_load.xml    → 本地化（enUS 必须最先，其余语言随后）
core\_load.xml       → 底层框架
modules\_load.xml    → 功能模块
```

`core/_load.xml` 内部顺序（**不可颠倒**）：

```
Dominos.lua       → 先创建 Dominos 表与 Addon 对象
fadeManager.lua   → 依赖 Dominos
drag.lua          → 依赖 Dominos
frame.lua         → 依赖 Dominos / FadeManager / Drag
bindableButton.lua→ 依赖 Dominos / LibKeyBound
minimap.lua       → 依赖 Dominos
```

`modules/_load.xml` 顺序：先「默认模块」，再「集成外部模块」，最后「附加自定义模块」。

### 2.2 运行时初始化时序

```
AceAddon:OnInitialize (仅一次)
  ├─ 创建 AceDB（DominosDB），注册 Profile 回调
  ├─ 版本升级检查 UpdateSettings / UpdateVersion
  ├─ RegisterSlashCommands()  注册 /dominos、/dom
  ├─ 为选项面板挂一个 OnShow 触发器（LoadAddOn("MyDominos335_Config")）
  └─ 注册 KeyBound / LibButtonFacade 回调

AceAddon:OnEnable (每次启用 / 换 Profile)
  ├─ HideBlizzard()  隐藏并卸载暴雪原生框架的事件
  ├─ Load()          创建所有条、皮肤、模块、重锚定、小地图按钮
  └─ 若存在 LibDataBroker → LoadDataBrokerPlugin()

换 Profile：Unload() → SetProfile/CopyProfile/ResetProfile → Load()
```

### 2.3 模块（Module）

- 通过 `Dominos:NewModule("名字")` 注册，继承 AceAddon 的模块机制。
- 模块可实现 `OnInitialize` / `OnEnable` / `Load` / `Unload`。
- `OnInitialize` 常用于「根据设置决定是否 `self:Disable()`」；
  例如 `Castbar` 模块在未开启 `UseCastbar()` 时直接 `Disable()`。
- `Dominos:Load()` 会遍历已启用的模块并调用其 `Load()`；`Unload()` 时调用 `Unload()`。

---

## 三、核心对象

### 3.1 Dominos（[core/Dominos.lua](../core/Dominos.lua)）

主驱动对象，职责包括：

- **存档**：`db = AceDB("DominosDB", defaults, UnitClass("player"))`；
  默认设置见 `GetDefaults()`（动作条数量、网格、皮肤、各条样式等）。
- **模块加载**：`Load()` 创建 `ActionBar:New(i)`、`ClassBar/PetBar/BagBar/MenuBar/VehicleBar`，
  处理皮肤、模块、重锚定、小地图按钮。
- **暴雪屏蔽**：`HideBlizzard()` 卸载 `MainMenuBar`、各 `MultiBar*`、姿态条、经验条、载具条等的事件并隐藏。
- **配置档案**：`SaveProfile / SetProfile / CopyProfile / DeleteProfile / ResetProfile / ListProfiles`
  以及对应的 `OnProfileChanged` 等回调。
- **斜杠命令**：`RegisterSlashCommands()` + `OnCmd()` 分派到各 setter。
- **设置读写**：大量 `SetXxx / GetXxx / UseXxx / ShowingXxx` 方法，直接读写 `self.db.profile.*`。
- **工具函数**：`CreateClass(type, parentClass)`（基于 `CreateFrame` 的简易类系统）、
  `Delay(delay, func, ...)`（基于 OnUpdate 的延时调度，3.3.5 无 `C_Timer` 时使用）。
- **皮肤**：`Masque(group, button, data)` / `RemoveMasque(...)` 兼容 Masque 与 LibButtonFacade。

### 3.2 Frame（[core/frame.lua](../core/frame.lua)）

所有「条」的基类（`Dominos:CreateClass("Frame")`）。为一个容器 `Frame`，内含：

- `header`：`SecureHandlerStateTemplate` 子框架，负责状态驱动（`_onstate-display` 控制显示与透明度、
  `_onstate-page` 控制分页）。
- `drag`：拖拽遮罩（`Dominos.DragFrame:New(f)`）。
- `buttons`：按钮表，由子类通过 `AddButton` / `RemoveButton` 填充。

关键能力（按功能分组）：

| 分组 | 代表方法 | 说明 |
| --- | --- | --- |
| 构造 / 析构 | `New` / `Create` / `Restore` / `Free` / `Delete` | 对象池：`Restore` 复用未使用的框架 |
| 设置装载 | `LoadSettings` / `GetDefaults` | 子类必须提供 `GetDefaults` |
| 布局 | `Layout` / `SetNumButtons` / `SetColumns` / `SetSpacing` / `SetPadding` / `SetLeftToRight` / `SetTopToBottom` | 计算并摆放按钮 |
| 缩放 | `SetFrameScale` / `Rescale` / `GetScale` / `GetScaledCoords` | |
| 透明度 | `SetFrameAlpha` / `SetFadeMultiplier` / `UpdateAlpha` / `GetExpectedAlpha` | `GetExpectedAlpha` 综合了「链接透明度 / 状态透明度 / 淡出乘数」 |
| 显隐 | `ShowFrame` / `HideFrame` / `ToggleFrame` / `SetShowStates` / `UpdateShowStates` | 用 `RegisterStateDriver(self.header, "display", states)` |
| 贴靠 | `Stick` / `StickToEdge` / `SetAnchor` / `ClearAnchor` / `Reanchor` | 依赖 `FlyPaper`：先试吸附到其它条，再试吸附屏幕边缘 |
| 定位 | `SavePosition` / `Reposition` / `GetRelPosition` / `SetFramePoint` | 以「点 + 相对坐标」保存 |
| 锁定 | `Lock` / `Unlock` | 锁定隐藏拖拽遮罩 |
| 菜单 | `ShowMenu` / `CreateMenu` | 通过 `Dominos:NewMenu` 打开 Config 的右键面板 |
| 元操作 | `Get` / `GetAll` / `ForAll` / `ForFrame` | `ForFrame("all" \| id \| a-b, method, ...)` |

> 说明：`Frame:AddButton` / `Frame:NumButtons` 是**占位方法**，必须由子类覆盖。

### 3.3 DragFrame（[core/drag.lua](../core/drag.lua)）

拖拽遮罩，一个覆盖在 owner 之上的 `Button`，帧层级 +5。监听：

- `OnMouseDown / OnMouseUp`：拖动移动（`StartMoving` / `StopMovingOrSizing` + `Stick`）；
- `OnMouseWheel`：调整不透明度（每次 ±0.1）；
- `OnClick`：右键（Shift 则切换显隐，否则打开菜单）、中键切换显隐；
- `OnEnter`：提示当前条名称、操作说明与不透明度。

`Drag:UpdateColor()` 根据「是否显示 / 是否吸附到其它条」改变底色，直观提示状态。

### 3.4 FadeManager（[core/fadeManager.lua](../core/fadeManager.lua)）

处理「鼠标不在条上时淡出」。因暴雪自带的淡出函数在战斗中可能出问题，故自行实现：

- `FadeWatcher`：低频（`DELAY = 0.12`）轮询被监视框架的「期望透明度 vs 当前透明度」，
  差值超阈值则交给 `Fader` 渐变；
- `Fader`：按 0.1 秒做线性渐变（`Fade(frame, time, from, to)`）；
- 空集合时自动 `Hide()`，避免常驻 OnUpdate。

### 3.5 BindableButton（[core/bindableButton.lua](../core/bindableButton.lua)）

抽象按钮基类（继承 `CheckButton`），让 KeyBound 对「暴雪绑定」与「点击绑定」透明工作：

- `GetBlizzBindings`：读取 `buttonType..id` 的绑定；
- `GetClickBindings`：读取 `CLICK <name>:LeftButton`；
- `UpdateHotkey`：按 `self:GetName().."HotKey"` 命名约定刷新快捷键文本；
- `SetKey` / `ClearBindings`：设置 / 清除绑定。

### 3.6 小地图按钮（[core/minimap.lua](../core/minimap.lua)）

一个环绕小地图的圆形按钮 `DominosMinimapButton`：

- `OnClick`：左键切换设置模式（Shift 则进入绑定模式），右键打开设置；
- `OnDragStart / OnUpdate / OnDragStop`：沿小地图边缘拖动，角度换算成位置（`UpdatePosition`）；
- 位置（角度）保存到 `db.profile.minimapPos`。

---

## 四、模块实现要点

每个条通常需要实现：

```lua
-- 以 PetBar 为例
local PetBar = Dominos:CreateClass("Frame", Dominos.Frame)
function PetBar:New() ... end            -- 构造函数，调用 self.super.New(self, "pet")
function PetBar:GetDefaults() ... end    -- 默认设置（point/x/y/spacing 等）
function PetBar:NumButtons() ... end     -- 按钮数量
function PetBar:AddButton(i) ... end     -- 从哪取得按钮
function PetBar:RemoveButton(i) ... end  -- 释放按钮
function PetBar:CreateMenu() ... end     -- 右键设置面板（需 Config）
```

`New()` 内部一般调用 `self.super.New(self, id)`（id 同时用作框架标识与存档键），随后
`LoadButtons()` + `Layout()`。

### 动作条的分页机制（[modules/actionBar.lua](../modules/actionBar.lua)）

- 通过 `ActionBar.conditions` 有序条件表 + `RegisterStateDriver(self.header, "page", header)` 实现翻页。
- 每个按钮的属性 `action--base`（基础动作 ID）与 `action--S<n>`（各状态下对应的动作 ID）配合
  `_childupdate-action` 推导出的 `action` 属性，实现「同一个按钮在不同状态下显示不同技能」。
- 按钮复用暴雪原生按钮（`ActionButton1..12`、`MultiBar*` 等），超过部分才新建 `DominosActionButton*`；
  为防暴雪翻页逻辑干扰，按钮的 `SetID` 被置 0，原 ID 存入 `bindingid`。

### 图腾条的两套实现（[modules/totemBar/totemBar.lua](../modules/totemBar/totemBar.lua)）

- 默认：接管暴雪 `MultiCast*` 系列按钮（`LoadTotemBars`）。
- 备用（`ATotemBar()` 为真）：`LoadAltTotemBars` / `SetupTotemBar`，自建一个类似 aTotemBar 的面板。
- 文件开头 `if Dominos.MyClass ~= "SHAMAN" then return end`，**仅萨满加载**。

---

## 五、配置与状态驱动速查

| 概念 | 实现位置 | 备注 |
| --- | --- | --- |
| 动作条页条件 | `ActionBar.conditions` | `[bar:n]`、`[bonusbar:n]`、`[form:n]`、`[mod:...]`、`[help]/[harm]/[noexists]` |
| 状态透明度 | `frame.header` 的 `_onstate-display` | 由 `RegisterStateDriver(header, "display", states)` 驱动 |
| 显示状态 | `Frame:SetShowStates` | 支持 `[combat]` 等宏条件 |
| 链接透明度 | `Dominos:IsLinkedOpacityEnabled` + `Frame:GetExpectedAlpha` | 吸附在一起的条统一透明度 |
| 延时调度 | `Dominos:Delay` | 替代 `C_Timer` |

---

## 六、扩展指引

1. **新增一个条 / 面板**：继承 `Dominos.Frame`，实现 `New/GetDefaults/NumButtons/AddButton/RemoveButton`，
   如需设置界面再实现 `CreateMenu`，并在 `modules/_load.xml` 中登记文件，在 `Dominos:Load()` 中调用其 `New`。
2. **新增一个模块**：`local M = Dominos:NewModule("名字")`，实现 `Load/Unload`，必要时实现 `OnInitialize`。
3. **保持内部标识为 `Dominos`**：新增代码中引用全局表仍用 `Dominos`；仅新增的「对外名称 / 贴图路径」
   使用 `MyDominos335`（见 README 第三章）。
4. **注意 3.3.5a API 限制**：不要使用 `C_AddOns`、`C_Timer`、`WOW_PROJECT_ID` 等现代 API。
