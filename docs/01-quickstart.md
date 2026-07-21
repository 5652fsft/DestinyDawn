# Destiny Dawn 游戏项目 — AI快速导览

**目标读者**：AI大模型 | **开发者**：5652 | **引擎**：Godot 4.7.1

---

## 1. 项目概述

Destiny Dawn 是一款基于 Godot 4.7.1 的回合制六边形战棋卡牌游戏，两名玩家各控制 3 名角色，在六角格地图上使用卡牌与技能对战。

### 核心定位

| 维度 | 说明 |
|---|---|
| 玩法 | 回合制战棋 + 卡牌策略 |
| 对战 | 3v3 角色对战 |
| 模式 | LAN联机、单机人机（AI） |
| 网络 | ENet P2P（MultiplayerAPI） |
| 画面 | Control节点 + StyleBoxFlat手写样式（无 .theme 文件） |

### 游戏流程

```
编队(选3角色) → 卡组(选8张牌) → 开始战斗 → 回合制对战 → 胜负判定
```

---

## 2. 文档导航 — AI阅读顺序

> AI应当**先读本文档**快速了解项目全貌，再根据开发任务查阅对应文档。

| 文档 | 内容 | 何时查阅 |
|---|---|---|
| **01-quickstart.md** ← 先读 | 项目总览、架构概览、规范汇总 | 初次了解、全局参考 |
| **02-creating-a-character.md** | 新增角色的完整流程与规范 | 创建/修改角色时 |
| **03-creating-a-card.md** | 新增卡牌的完整流程与类型定义 | 创建/修改卡牌时 |
| **04-creating-ui.md** | UI主题、按钮、场景布局规范 | 创建/修改UI时 |
| **05-rpc-conventions.md** | 网络同步、RPC模式、同步流程 | 涉及网络同步时 |
| **06-data-format-reference.md** | 所有数据结构的精确格式 | 操作数据时速查 |
| **07-git-conventions.md** | Git分支策略、提交规范 | 提交代码时 |
| **08-ai-mode.md** | AI模式维护、新增角色AI更新 | 修改AI逻辑时 |
| **09-audio-system.md** | 音效系统架构、集成点 | 涉及音效时 |

---

## 3. 项目架构概览

### 3.1 目录结构

```
destiny-dawn/
├ Assets/
│  ├ Fonts/                    # SourceHanSerifCN 字体
│  └ Sprites/
│     ├ Characters/            # 角色阵营贴图 (*_Blue.png / *_Red.png)
│     ├ Standee/               # 立绘 (240x144, *_Standee.png)
│     └ menubg.jpg             # 背景图
├ Cards/
│  ├ CardData.gd               # 卡牌数据资源类 + 枚举定义
│  ├ CardDatabase.gd           # 卡牌注册与查询
│  ├ CardEffect.gd             # 卡牌效果执行器
│  ├ BuffData.gd               # Buff 数据资源类（class_name BuffData）
│  └ BuffDatabase.gd           # Buff 注册表（class_name BuffDatabase）
├ Characters/                  # 各角色目录（Bronya/Seele/Elaina/Firefly/SilverWolf/Hamster）
│  ├ BaseCharacter.gd          # 角色基类
│  └ FloatingBar.gd/.tscn      # 血条/护盾
├ Global/
│  ├ BackgroundManager.gd      # 动态背景管理器（Autoload）
│  ├ BackgroundSingleton.gd    # 背景单例（Autoload）
│  ├ SingletonMenuBackground.gd/.tscn # 单例背景场景
│  ├ AudioManager.gd           # 音效/音乐管理器（Autoload）
│  ├ ButtonTheme.gd            # 按钮主题（Autoload）
│  ├ CharacterData.gd          # 角色数据字典
│  ├ DeckManager.gd            # 卡组/手牌管理（场景子节点，非Autoload）
│  ├ EnergySystem.gd           # 能量系统（场景子节点，非Autoload）
│  ├ VFXManager.gd             # 特效管理器
│  ├ AILogger.gd               # AI日志工具
│  └ MarkdownConverter.gd      # Markdown 转换工具
├ GlobalGameData.gd            # 全局状态单例（Autoload）
├ AI/
│  └ AIController.gd           # AI控制器
├ Effects/
│  └ FloatingNumber.gd/.tscn   # 浮动数字效果
├ Menus/
│  ├ MainMenu.tscn/.gd         # 主菜单
│  ├ TeamFormation.tscn/.gd    # 编队管理
│  ├ DeckBuilder.tscn/.gd      # 卡组构筑
│  ├ SettingsScene.tscn/.gd    # 设置界面
│  ├ GuideScene.tscn/.gd       # 游戏指南
│  └ Widgets/
│     ├ CharacterCard.tscn/.gd # 角色卡片组件
│     └ DeckCardUI.tscn/.gd    # 卡牌卡片组件
├ Scenes/
│  ├ scene.tscn                # 主战斗场景
│  ├ main.gd                   # 战斗主逻辑
│  └ camera.gd                 # 摄像机控制
├ Skills/
│  ├ BaseSkill.gd              # 技能资源类
│  └ SkillEffect.gd            # 技能效果执行器
├ UI/
│  ├ Theme/GameTheme.tres      # UI 主题文件
│  ├ BattleResult.tscn/.gd     # 结算界面
│  ├ CardUI.tscn/.gd           # 战斗手牌卡片
│  ├ CardTheme.gd              # 卡牌样式常量
│  ├ HandPanel.tscn/.gd        # 手牌面板
│  ├ SkillPanel.tscn/.gd       # 技能按钮面板
│  ├ CharacterInfoPanel.tscn/.gd # 角色详情面板
│  ├ PlayerInfoPanel.tscn/.gd  # 玩家信息面板
│  ├ TurnIndicator.tscn/.gd    # 回合指示器
│  └ Toast.tscn/.gd            # 提示系统
└ docs/                        # 本文档目录
```

### 3.2 Autoload 单例

| 脚本 | 用途 |
|---|---|
| `GlobalGameData.gd` | 全局状态：回合、编队、战斗统计、音量设置 |
| `BackgroundManager.gd` | 动态背景切换与持久化 |
| `BackgroundSingleton.gd` | 背景单例管理（跨场景保持背景实例） |
| `AudioManager.gd` | BGM/SFX播放与音量控制 |
| `ButtonTheme.gd` | 全局按钮主题与动效 |

> 注意：`DeckManager`、`EnergySystem`、`BuffManager` 不是 Autoload，它们是战斗场景 `scene.tscn` 的子节点，由 `main.gd` 的 `@onready` 变量引用。

### 3.3 战斗场景节点结构

```
scene.tscn (Node2D) — main.gd
├ Camera (Camera2D)              — 视角控制（camera.gd，支持拖拽+缩放）
├ Map/
│  ├ Ground (TileMapLayer)       — 地形网格
│  └ Highlight (TileMapLayer)    — 高亮显示（移动/攻击范围）
├ Characters (Node2D)            — 角色容器（MultiplayerSpawner 自动生成）
├ MultiplayerSpawner             — 网络生成器
├ EnergySystem (Node)            — 能量系统（EnergySystem.gd）
├ DeckManager (Node)             — 卡牌管理（DeckManager.gd）
├ UI (CanvasLayer)
│  ├ CharacterInfoPanel          — 角色属性面板
│  ├ PassiveSkillPanel           — 被动技能面板
│  ├ TurnIndicator               — 回合指示器+结束回合按钮
│  ├ HandPanel                   — 手牌面板
│  ├ SkillPanel                  — 技能按钮面板
│  ├ HostPlayerPanel             — 主机玩家信息
│  ├ ClientPlayerPanel           — 客户端玩家信息
│  ├ Toast                       — 提示系统
│  ├ BattleResult                — 结算界面
│  ├ MoveButton                  — 移动按钮
│  └ AttackButton                — 普通攻击按钮
└ main.gd                        — 战斗主控制器（回合管理+RPC+角色生成）
```

---

## 4. 核心设计约束

> 以下为整个项目通用的约束，所有新开发不得违反。

### 4.1 卡牌系统约束
- **无施法者概念**：卡牌由玩家直接从手牌释放到目标，`CardEffect.gd` 中 `caster` 参数已废弃（始终为当前选中角色或队伍中第一个存活角色），新增卡牌效果时无需关心
- **无亲和力系统**：`_affinity_multiplier()` 已废弃，始终返回 1.0
- 卡牌通过 `_create_card()` 在 `CardDatabase.gd` 中注册

### 4.2 回合系统约束
- **无独立的移动/攻击阶段**：每个角色在回合内可移动 1 次 + 攻击/技能 1 次，顺序由玩家自由决定；卡牌由玩家独立释放，不消耗角色的行动次数
- 回合流程：`START_ROUND → PLAYER_TURN → ENEMY_TURN → 循环`
- 先手顺序每回合随机决定
- 必须点击"结束回合"按钮手动推进到对方回合

### 4.3 地形系统约束
- 地形类型：平原（消耗1）、森林（消耗2）
- **山地不可通行**，不能移动到山地格上
- 所有格子的移动力消耗不能为负数

### 4.4 网络同步约束
- **服务端权威**：所有状态变更由Host（peer 1）验证和执行
- **RPC模式**：严格按照 `docs/05-rpc-conventions.md` 选择

### 4.5 角色设计约束
- 每个角色有唯一的 `character_name`（中文名）
- 技能范围 `skill_range = 0` 表示无限制（全图），> 0 表示最大 hex 格数
- 优先在角色脚本中覆写 `take_damage` / `perform_attack` 实现被动

---

## 5. 开发规范速查

### 5.1 开发原则

- **数据驱动设计**：所有游戏数据与逻辑分离，通过数据库类统一管理
- **模块化封装**：每个功能模块独立封装，节点间通过信号通信，避免直接引用
- **服务端权威**：所有状态变更由Host验证执行，客户端从不主动修改游戏状态
- **防御性编程**：所有外部数据都要验证，重要操作记录日志

### 5.2 新增角色需改动文件

| 文件 | 操作 |
|---|---|
| `Global/CharacterData.gd` | 添加数据条目 |
| `Characters/NewChar/NewChar.gd` | 新建角色脚本（extends BaseCharacter） |
| `Characters/NewChar/NewChar.tscn` | 新建角色场景 |
| `Assets/Sprites/Characters/` | 添加阵营贴图（Blue/Red） |
| `Assets/Sprites/Standee/` | 添加立绘 |
| `Scenes/main.gd` | 添加PackedScene常量 + 编队map |
| `Skills/SkillEffect.gd` | 实现技能逻辑 |
| `AI/AIController.gd` | 添加技能策略分支 |
| `Scenes/main.gd` | AI角色池添加新角色ID |

### 5.2 新增卡牌需改动文件

| 文件 | 操作 |
|---|---|
| `Cards/CardDatabase.gd` | 添加 `_create_card()` 调用 |
| `Cards/CardEffect.gd` | 如需要新效果类型，添加实现 |
| `Cards/CardData.gd` | 如需要新枚举值 |
| `Scenes/main.gd` | 如需要新目标选择逻辑 |
| `Menus/DeckBuilder.gd` | 如需要新卡牌类型名 |

### 5.3 命名规范

| 类型 | 规范 | 示例 |
|---|---|---|
| 文件名 | PascalCase | `CharacterData.gd` |
| 变量名 | snake_case | `character_move_used` |
| 常量 | SCREAMING_SNAKE_CASE | `DEFAULT_TEAM` |
| 信号 | snake_case | `buffs_changed` |

### 5.4 提交规范

格式：`<type>: <简短描述（中文）>`

| Type | 用途 |
|---|---|
| feat | 新功能 |
| fix | 修复Bug |
| refactor | 重构 |
| style | UI变更 |
| docs | 文档 |
| revert | 回滚 |

---

## 6. 运行方式

| 方式 | 说明 |
|---|---|
| 单机调试 | MainMenu.tscn → 创建主机（默认编队+卡组） |
| LAN联机 | 主机点"创建游戏"，客户端输入IP点"加入" |
| 主场景 | `project.godot` 中 `run/main_scene=res://Menus/MainMenu.tscn` |

---

## 7. 技术栈

| 技术 | 版本/说明 |
|---|---|
| Godot | 4.7.1 (GDScript 2.0) |
| 联机 | ENet (MultiplayerAPI) |
| UI | Control + StyleBoxFlat（无theme文件） |
| 网格 | TileMapLayer (Ground + Highlight) |
| 视频 | Theora编码（.ogv） |
| 字体 | SourceHanSerifCN |
| 音效 | .ogg格式 |

---

## 8. 调试与性能

### 日志
```gdscript
var Logger = load("res://Global/AILogger.gd")
Logger.log("消息", "类别")  # 类别如 Battle/Skill/Card/Buff/Network
```

### 性能优化惯例
- **对象池**：特效对象复用，避免频繁创建销毁
- **状态差分**：只同步变化的状态，不传输完整数据
- **异步加载**：资源使用 `preload()` 提前加载，避免运行时卡顿

### 扩展新内容时注意
- 新角色 → 同步更新 `AI/AIController.gd` 技能策略
- 新Buff → 在 `Global/BuffDatabase.gd` 注册元数据
- 新效果类型 → 在 `CardData.EffectType` 添加枚举值
