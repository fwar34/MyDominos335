# MyDominos335

`MyDominos335` 是一款面向 **《魔兽世界》巫妖王之怒 3.3.5a（Interface 30300）** 客户端的模块化动作条 / 界面框架插件。
它以经典插件 **Dominos** 为基础，采用 **bkader 的 WotLK（3.3.5）移植版 Dominos v1.18.7（Kader's Edition）** 作为蓝本，
并将对外标识（目录名、TOC 名、插件注册名、贴图路径等）整体重命名为 `MyDominos335`，以便在 3.3.5a 客户端中稳定运行。

> 本仓库只包含**主插件** `MyDominos335`。配套的图形化设置界面位于同级的独立插件 `MyDominos335_Config`（不在本仓库内）。

---

## 目录

- [一、项目简介](#一项目简介)
- [二、适配版本](#二适配版本)
- [三、来源与重命名说明](#三来源与重命名说明)
- [四、安装与启用](#四安装与启用)
- [五、主要功能](#五主要功能)
- [六、斜杠命令](#六斜杠命令)
- [七、鼠标与拖拽操作](#七鼠标与拖拽操作)
- [八、目录结构](#八目录结构)
- [九、模块说明](#九模块说明)
- [十、依赖库](#十依赖库)
- [十一、配置文件与存档](#十一配置文件与存档)
- [十二、常见问题（FAQ）](#十二常见问题faq)
- [十三、致谢与许可](#十三致谢与许可)

---

## 一、项目简介

Dominos 的核心理念是「**把暴雪自带的动作条全部接管并重新排布**」：它隐藏了暴雪原生的主动作条、
多动作条、姿态/形态条、宠物条、载具条、经验条、施法条、目标追踪等界面元素，并用自己实现的一套
**可自由拖拽、缩放、隐藏、分页、贴靠（sticky）** 的框架（Frame）取而代之。

插件本身高度模块化：

- `core/` 提供底层框架对象（Frame、拖拽、淡出管理、可绑定按钮、小地图按钮等）；
- `modules/` 以「模块（Module）」为单位按需加载各类动作条与信息条；
- 每个条都是一个独立的 **Frame 实例**，拥有自己的位置、缩放、透明度、按钮数量、分页条件等设置；
- 所有设置通过 **AceDB** 以「配置文件（Profile）」的形式保存，支持多角色共享 / 分档。

---

## 二、适配版本

| 项目 | 取值 |
| --- | --- |
| 游戏客户端 | World of Warcraft: Wrath of the Lich King（巫妖王之怒） |
| 客户端版本 | 3.3.5a（版本号 12340） |
| TOC `Interface` 版本 | `30300` |
| 插件版本 | `1.18.7` |
| 运行环境 | 仅支持 3.3.5a 客户端，**不兼容** 现代正式服 / 怀旧服客户端 |

> 注意：3.3.5a 使用旧版 API（如全局函数 `GetAddOnMetadata` / `GetAddOnInfo` / `LoadAddOn`），
> 不存在 `C_AddOns`、`C_Timer`、`WOW_PROJECT_ID` 等现代 API。本插件及所带库均已按此适配。

---

## 三、来源与重命名说明

- **原始插件**：Dominos，作者 Tuller（Jason Greer），采用 BSD 许可。
- **移植版本**：bkader 的 3.3.5 适配版（Kader's Edition），版本号 1.18.7。
- **本次改动**：在移植版基础上，将插件整体重命名为 `MyDominos335`。

重命名遵循「**对外标识全部改名、内部标识保持原名**」的原则，原因是为避免破坏与存档 / 第三方库的兼容性：

**已改为 `MyDominos335` 的部分：**

- 插件目录名：`MyDominos335`
- TOC 文件名：`MyDominos335.toc`
- TOC 元数据：`Title` / `Title-zhCN` / `Title-zhTW` 等
- AceAddon 注册名：`MyDominos335`
- `GetAddOnMetadata("MyDominos335", ...)` / `GetAddOnInfo("MyDominos335")` / `LoadAddOn(...)` 的调用参数
- 贴图路径：`Interface\AddOns\MyDominos335\...`

**仍然保留为 `Dominos` 的部分（重要）：**

- 全局表：`Dominos`
- 存档变量：`DominosDB`、`DominosVersion`
- AceLocale 语言表键：`"Dominos"`、`"Dominos-Config"`
- 部分动态创建的框架全局名：如 `DominosActionButton`、`DominosCastingBar`
- 斜杠命令：`/dominos`、`/dom`

> 因此，在代码 / 报错信息中看到 `Dominos` 字样属于预期行为，并不代表插件仍未改名。

---

## 四、安装与启用

1. 将本目录 `MyDominos335` 放入：

   ```
   <游戏根目录>\Interface\AddOns\MyDominos335
   ```

2. 将配套设置插件 `MyDominos335_Config` 放入：

   ```
   <游戏根目录>\Interface\AddOns\MyDominos335_Config
   ```

3. 登录角色选择界面，点击左下角「插件」按钮，**同时勾选**：

   - `MyDominos335`
   - `MyDominos335 Config`（图形化设置界面，`LoadOnDemand`，依赖主插件）

4. 进入游戏后即可看到被接管 / 重排后的动作条。

> `MyDominos335_Config` 是**可选**的：不勾选也能正常使用，只是无法通过界面进行可视化设置
> （仍可通过斜杠命令调整）。主插件在需要时会通过 `LoadAddOn("MyDominos335_Config")` 动态加载它。

首次进入时，插件会为当前角色创建一个以「角色名 - 服务器名」命名的默认配置文件。

---

## 五、主要功能

- **动作条（Action Bar）**：接管全部暴雪动作条按钮（最多 120 个 / 最多 120 个分条），
  支持自定义条数、每行按钮数、按钮大小、间距、内边距、缩放、透明度。
- **分页（Paging）**：支持基于姿态 / 形态（`[bonusbar:n]`、`[form:n]`）、
  动作条页（`[bar:2..6]`）、组合键（`[mod:...]`）、目标状态（`[help]` / `[harm]` / `[noexists]`）、
  以及「控制载具」等条件的自动翻页。
- **宠物条（Pet Bar）**：接管宠物动作条。
- **职业条 / 形态条（Class Bar）**：战士姿态、德鲁伊形态、盗贼潜行 / 暗影之舞、牧师暗影形态等。
- **背包条（Bag Bar）**：接管背包 / 钥匙链 / 主背包按钮，可合并为「单背包」模式。
- **菜单条（Menu Bar）**：接管微型菜单（角色、法术书、天赋、成就、任务、社交、PvP、随机本等按钮）。
- **载具条（Vehicle Bar）**：接管载具的瞄准 / 离开按钮。
- **掷点条（Roll Bar）**：团队掷点面板（`GroupLootFrame`）的重新排布。
- **经验 / 声望条（XP Bar）**：可切换「经验」与「声望」显示，支持 LibSharedMedia 材质选择。
- **施法条（Cast Bar）**：内置一条可自定义的施法 / 引导条，取代暴雪施法条。
- **图腾条（Totem Bar）**：萨满专属，支持原生图腾条与 aTotemBar 风格的备用图腾条。
- **增益 / 减益条（Aura Bars）**：玩家 Buff / Debuff 的网格化显示。
- **小地图模块**：接管小地图边框、区域名称、小地图按钮，并提供可拖拽的圆形小地图按钮。
- **目标追踪（Quest Tracker）**：接管任务目标追踪框，支持滚动条、宽度 / 高度 / 内边距调整。
- **贴靠（Sticky）**：拖动条时会自动吸附到其它条或屏幕边缘，并可自动居中。
- **键位绑定（KeyBound）**：集成 `LibKeyBound-1.0`，可在条上直接显示 / 设置快捷键。
- **外观皮肤（Masque / LibButtonFacade）**：检测到 `Masque` 或 `LibButtonFacade` 时自动接管按钮皮肤。
- **配置文件（Profiles）**：基于 AceDB 的多配置档系统，支持保存 / 切换 / 复制 / 删除 / 重置 / 列出。

---

## 六、斜杠命令

主命令：`/dominos` 或 `/dom`（`/dominos` 的缩写）。

| 命令 | 说明 |
| --- | --- |
| `/dom` | 打开设置界面（未安装设置插件时打印帮助） |
| `/dom config` / `/dom lock` | 切换「设置模式（锁定 / 解锁）」 |
| `/dom scale <frameList> <值>` | 设置指定条的缩放 |
| `/dom setalpha <frameList> <值>` | 设置指定条的不透明度 |
| `/dom fade <frameList> <值>` | 设置指定条的「淡出（鼠标未悬停时）」透明度 |
| `/dom setcols <frameList> <列数>` | 设置指定条每行按钮数 |
| `/dom pad <frameList> <值>` | 设置指定条的内边距 |
| `/dom space <frameList> <值>` | 设置指定条的按钮间距 |
| `/dom show <frameList>` | 显示指定条 |
| `/dom hide <frameList>` | 隐藏指定条 |
| `/dom toggle <frameList>` | 切换指定条的显示 / 隐藏 |
| `/dom numbars <数量>` | 设置动作条分条数量 |
| `/dom numbuttons <数量>` | 设置每个动作条的按钮数量 |
| `/dom save <配置名>` | 保存当前设置为新配置并切换过去 |
| `/dom set <配置名>` | 切换到指定配置 |
| `/dom copy <配置名>` | 从指定配置复制设置 |
| `/dom delete <配置名>` | 删除指定配置 |
| `/dom reset` | 重置当前配置为默认值 |
| `/dom list` | 列出所有可用配置 |
| `/dom version` | 打印当前插件版本 |
| `/dom bfa <short\|small\|large\|long> [noart]` | 设置 BfA 风格背景纹理 |
| `/dom bfa scale <值>` | 设置 BfA 背景纹理的缩放 |
| `/dom help` / `/dom ?` | 打印命令帮助 |

其中 `<frameList>` 支持：

- `all`：代表全部框架；
- 单个 ID，如 `1`、`pet`、`class`、`bags`、`menu`、`vehicle`；
- 区间，如 `1-6`（表示 ID 1 到 6 的所有框架）。

---

## 七、鼠标与拖拽操作

在**设置模式（未锁定）**下，把鼠标移到任意条上会出现半透明的拖拽遮罩（drag frame）：

| 操作 | 效果 |
| --- | --- |
| 拖动（左键按住） | 移动该条 |
| 右键 | 打开该条的右键设置菜单 |
| 中键 / Shift + 右键 | 显示 / 隐藏该条 |
| 滚轮上 / 下 | 调整该条不透明度（每次 10%） |

设置模式下的浮窗提示：拖到附近可吸附到其它条或屏幕边缘，按 `Alt` 可临时禁用吸附。

---

## 八、目录结构

```
MyDominos335/
├── MyDominos335.toc          # 主插件清单（Interface 30300）
├── .gitignore
├── README.md                 # 本文档
├── docs/
│   ├── ARCHITECTURE.md       # 架构与加载流程说明
│   └── CHANGELOG.md          # 变更日志
├── core/                     # 底层框架
│   ├── _load.xml
│   ├── Dominos.lua           # 主驱动：初始化 / 模块加载 / 配置档案 / 斜杠命令
│   ├── frame.lua             # 通用容器对象 Frame（布局 / 缩放 / 透明度 / 贴靠 / 显隐状态）
│   ├── drag.lua              # 拖拽遮罩
│   ├── fadeManager.lua       # 鼠标未悬停时的淡出管理
│   ├── bindableButton.lua    # 抽象可绑定按钮（KeyBound 支持）
│   └── minimap.lua           # 圆形小地图按钮
├── modules/                  # 各功能模块
│   ├── _load.xml
│   ├── actionBar.lua         # 动作条
│   ├── petBar.lua            # 宠物条
│   ├── classBar.lua          # 职业 / 形态条
│   ├── bagBar.lua            # 背包条
│   ├── menuBar.lua           # 微型菜单条
│   ├── vehicleBar.lua        # 载具条
│   ├── rollBar.lua           # 掷点条
│   ├── xpBar.lua             # 经验 / 声望条
│   ├── auraBuffsBar.lua      # 增益条
│   ├── auraDebuffsBar.lua    # 减益条
│   ├── minimapBar.lua        # 小地图条
│   ├── minimapZoneTextBar.lua# 小地图区域文字
│   ├── questTracker.lua      # 目标追踪
│   ├── castBar/
│   │   ├── castBar.lua
│   │   └── castBar.xml
│   └── totemBar/
│       ├── spellButton.lua   # 法术按钮（图腾用）
│       ├── totemBar.lua
│       └── totemBar.xml
├── locales/                  # 本地化
│   ├── _load.xml
│   ├── enUS.lua / deDE.lua / esES.lua / frFR.lua
│   └── koKR.lua / ruRU.lua / zhCN.lua / zhTW.lua
├── libs/                     # 第三方库（勿修改）
│   └── ...
└── textures/                 # 贴图资源
    ├── logo.tga / minimap.blp
    └── BfA/ ...
```

---

## 九、模块说明

`core/_load.xml` 与 `modules/_load.xml` 负责按顺序加载文件。加载顺序很关键：底层对象先于模块创建。
各类「条」均实现自 `Frame` 基类，并注册为 Dominos 的模块（Module）。

| 模块 | 文件 | 触发 / 说明 |
| --- | --- | --- |
| 动作条 | [actionBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/actionBar.lua) | 常驻；接管全部暴雪动作条按钮，含分页与状态驱动 |
| 宠物条 | [petBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/petBar.lua) | 常驻；接管 `PetActionButton*` |
| 职业条 | [classBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/classBar.lua) | 非猎人 / 法师 / 萨满职业时创建 |
| 背包条 | [bagBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/bagBar.lua) | 常驻；接管背包 / 钥匙链按钮 |
| 菜单条 | [menuBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/menuBar.lua) | 常驻；接管微型菜单按钮 |
| 载具条 | [vehicleBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/vehicleBar.lua) | 常驻；接管载具瞄准 / 离开按钮 |
| 掷点条 | [rollBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/rollBar.lua) | 模块名 `roll` |
| 经验条 | [xpBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/xpBar.lua) | 模块名 `xp`；经验 / 声望切换 |
| 增益条 | [auraBuffsBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/auraBuffsBar.lua) | 模块名 `Buffs`；需开启 Aura |
| 减益条 | [auraDebuffsBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/auraDebuffsBar.lua) | 模块名 `Debuffs`；需开启 Aura |
| 小地图条 | [minimapBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/minimapBar.lua) | 模块名 `minimap`；需开启 Minimap |
| 区域文字 | [minimapZoneTextBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/minimapZoneTextBar.lua) | 模块名 `Zone-Text`；需开启 Minimap |
| 目标追踪 | [questTracker.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/questTracker.lua) | 模块名 `QuestLog`；需开启 Quest |
| 施法条 | [castBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/castBar/castBar.lua) | 模块名 `CastingBar`；需开启 Castbar |
| 图腾条 | [totemBar.lua](file:///m:/wowLK/World%20of%20Warcraft/Interface/AddOns/MyDominos335/modules/totemBar/totemBar.lua) | 模块名 `totems`；**仅萨满**加载 |

> 模块是否启用，取决于 `Dominos:UseAuras()` / `UseQuest()` / `UseMinimap()` / `UseCastbar()` /
> `ATotemBar()` 等设置。未启用时模块会调用 `self:Disable()` 自行关闭。

---

## 十、依赖库

`libs/` 目录内为本插件自带（内嵌）的第三方库，**请勿手动修改**。
TOC 文件的 `## OptionalDeps: Ace3, LibKeyBound-1.0, ButtonFacade` 表明这些库为可选依赖
（插件已内嵌，无需单独安装）。

| 库 | 作用 |
| --- | --- |
| Ace3（AceAddon / AceDB / AceLocale / AceConsole / AceEvent / CallbackHandler） | 插件模块系统、存档、本地化、聊天命令、事件、回调 |
| LibStub | 库加载与版本管理 |
| LibKeyBound-1.0 | 快捷键绑定 / 显示 |
| LibSharedMedia-3.0 | 共享媒体（经验条材质等） |
| LibDataBroker-1.1 | 数据源（配合面板 / 小地图按钮） |
| LibButtonFacade / Masque（外置时） | 按钮皮肤外观接管 |
| FlyPaper | 框架贴靠（吸附）算法 |

---

## 十一、配置文件与存档

- **存档变量（SavedVariables）**：`DominosDB`、`DominosVersion`（在 `MyDominos335.toc` 中声明）。
- **配置文件（Profile）**：基于 `AceDB`，默认以「角色名 - 服务器名」命名，可多角色共享。
- **版本更新**：`Dominos:UpdateSettings()` 处理从旧版本升级（如 1.13 之前的布局选项、1.15 之前的图腾条设置）。
- **重置 / 备份**：可通过 `/dom reset` 重置；也可直接备份 `WTF\Account\<账号>\SavedVariables\DominosDB.lua`。

> 想彻底恢复默认，可删除存档中的 `DominosDB` 变量后重登。

---

## 十二、常见问题（FAQ）

**Q1：登录界面插件列表提示「版本错误 / 过期」怎么办？**
A：确认 `MyDominos335.toc` 的 `## Interface: 30300` 与客户端一致。3.3.5a 的 Interface 版本即 `30300`。

**Q2：为什么报错信息里还是出现 `Dominos`？**
A：这是预期的。为兼容存档与第三方库，仅「对外标识」被改名，「内部标识」（全局表 `Dominos`、
存档 `DominosDB`、语言键 `Dominos` 等）保持不变，详见 [第三章](#三来源与重命名说明)。

**Q3：设置菜单打不开？**
A：设置界面由独立的 `MyDominos335_Config` 提供，请确认该插件已安装并在插件列表中勾选。
主插件会用 `LoadAddOn("MyDominos335_Config")` 按需加载它。

**Q4：动作条没有接管暴雪原生动作条？**
A：请确认插件已启用且未被其它动作条插件（如 Bartender4）冲突。同一时间只应启用一个动作条接管类插件。

**Q5：萨满没有图腾条？**
A：图腾条模块**仅在萨满角色**下加载（`totemBar.lua` 开头会检测职业并提前 `return`）。

**Q6：想改回默认外观 / 布局？**
A：使用 `/dom reset` 重置当前配置，或在设置界面中使用 Profiles 面板重置。

---

## 十三、致谢与许可

- **原作者**：Tuller（Jason Greer）——Dominos 原作者，BSD 许可。
- **移植者**：bkader ——3.3.5（WotLK）适配版（Kader's Edition）。
- **本仓库**：在移植版基础上重命名为 `MyDominos335`，并补充中文文档与注释。

本插件中的自有代码沿用原 Dominos 的 **BSD 许可**（各源文件头部保留原始版权声明）。
`libs/` 下第三方库遵循各自许可，请以对应库内的许可声明为准。
