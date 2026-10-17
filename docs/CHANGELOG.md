# 变更日志（CHANGELOG）

本项目格式大致遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。
版本号沿用上游 Dominos 的版本号（当前 `1.18.7`）。

---

## [未发布]

### 新增
- `README.md`：项目简介、适配版本、安装与启用、主要功能、斜杠命令、目录结构、
  模块说明、依赖库、配置文件、FAQ、致谢与许可等中文文档。
- `docs/ARCHITECTURE.md`：代码分层、加载流程、核心对象（Dominos / Frame / DragFrame /
  FadeManager / BindableButton / 小地图按钮）、模块实现要点与扩展指引。
- `docs/CHANGELOG.md`：本变更日志。
- 为 `core/`、`modules/`、`locales/` 下的自有源文件补充**中文文件头注释**与关键逻辑注释。

### 说明
- 本次改动**仅新增文档与注释，不修改任何业务逻辑**，行为与改动前保持一致。

---

## [1.18.7] - 2022-05-24（Kader's Edition / WotLK 3.3.5 移植版）

### 背景
- 基于 Dominos 官方版本的 **WotLK（3.3.5）移植版**（由 bkader 维护，Kader's Edition）。
- 面向客户端 `Interface: 30300`。
- 本仓库在此基础上完成整体重命名为 `MyDominos335`。

### 重命名（对外标识）
- 插件目录：`Dominos` → `MyDominos335`
- 主清单：`Dominos.toc` → `MyDominos335.toc`
- TOC 元数据：`Title` / `Title-zhCN` / `Title-zhTW`
- AceAddon 注册名：`MyDominos335`
- 相关 API 调用参数：`GetAddOnMetadata` / `GetAddOnInfo` / `LoadAddOn`
- 贴图路径：`Interface\AddOns\MyDominos335\...`
- 配套设置插件：`Dominos_Config` → `MyDominos335_Config`

### 保持不变（内部标识）
- 全局表 `Dominos`、存档变量 `DominosDB` / `DominosVersion`
- AceLocale 语言键 `"Dominos"` / `"Dominos-Config"`
- 部分动态框架全局名（如 `DominosActionButton`、`DominosCastingBar`）
- 斜杠命令 `/dominos`、`/dom`

> 保留内部标识是为了不破坏既有存档与第三方库的兼容性。详见 [README 第三章](../README.md#三来源与重命名说明)。

---

## 上游历史（摘要）

> 以下为 Dominos 上游相对重要的历史节点摘要，仅作背景参考，具体以上游仓库为准。

- **1.18.x**：BfA 风格背景纹理支持（`/dom bfa`）、Masque / LibButtonFacade 皮肤接管完善。
- **1.15**：图腾条设置更新（`showRecall` / `showTotems`）。
- **1.13**：新的布局选项（左右 / 上下方向）。
- **更早**：基础动作条、宠物条、职业条、分页与配置档案系统成型。

---

## 备注

- 上游原始插件与版权归 **Tuller（Jason Greer）** 所有（BSD 许可）。
- WotLK 3.3.5 移植由 **bkader** 完成。
