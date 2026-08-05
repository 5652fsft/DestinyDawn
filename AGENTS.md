# Destiny Dawn — AGENTS.md

## Agent 操作要求
### 任务应遵循流程
`制定计划 -> 询问修改 -> 确定规划细则 -> 执行操作或实现功能-> 检查语法与逻辑错误 -> 询问修改文档 -> 版本管理`
过于简单的任务不用严格遵循

### 代码注意事项
模块化、可复用性、易维护，数值易修改

### 认知盲区提醒
- 如果用户的复杂需求描述过于直接跳到实现，AI 应先反问目标、成功标准等，避免为了做功能而做功能。
- 当发现用户可能把“实现方案”误当成“真实需求”时，AI 应主动区分：用户目标、当前方案、可选方案、推荐方案。
  
### 工程决策透明化
- 涉及架构、状态管理、数据模型、权限、依赖、路由、主要 UI 结构的变更时，AI 必须先说明自己的技术判断依据。
- 每次重要实现前，AI 应简短列出：本次改动影响范围、可能破坏的模块、验证方式。
- 如果存在多个实现路径，AI 应给出至少两个方案，并比较复杂度、扩展性、风险和开发成本，再推荐一个。
- 不允许为了短期跑通而引入长期难维护的临时方案；如必须临时处理，必须标记 TODO、说明原因
  
### 文档与实现一致性
- 所有大的涉及功能、信息架构、数据结构、权限模型或主要布局的调整，都要询问用户是否同步更新 /docs 中对应文档与 readme.md，并提出更新大纲。
- 定期检查当前项目实际功能、UI、数据模型、交互流程是否与 /docs 规范一致；发现不一致时，主动提醒用户选择：更新代码、更新文档、或记录偏差原因。
- 当代码实现与文档方案发生偏离时，AI 必须说明偏离点、偏离原因、潜在影响。
  
### 用户能力提升
- AI 在给出实现结果时，应适度解释关键工程判断，让用户理解为什么这样做，而不只是交付代码。
- AI 不应一味迎合用户的即时指令；当更好的长期方案存在时，应礼貌但明确地提出。

## 项目概览

回合制六边形战棋 + 卡牌对战游戏，Godot 4.7，GDScript。入口场景 `Menus/MainMenu.tscn`，战斗场景 `Scenes/main.gd`（当前场景）。

## 目录结构速览

| 目录 | 职责 |
|------|------|
| `Global/` | Autoload 单例 & 共享工具（`GlobalGameData`, `AudioManager`, `CharacterData`, `HexUtils` 等） |
| `Characters/` | 每个角色一个子目录（`Script.gd` + `Scene.tscn`），`BaseCharacter.gd` 为基类 |
| `Cards/` | 卡牌系统（`CardDatabase`, `CardEffect`, `CardData`, `BuffData`, `BuffDatabase`） |
| `Skills/` | 技能系统（`BaseSkill`, `SkillEffect`） |
| `AI/` | `AIController.gd` — 单机 AI |
| `UI/` | 战斗 UI（`HandPanel`, `CardUI`, `CharacterInfoPanel` 等） |
| `Menus/` | 主菜单、编队、卡组构筑 |
| `Scenes/` | `main.gd` — 战斗主逻辑 |
| `docs/` | 9 篇技术文档（创建角色/卡牌/UI、RPC 规范、数据格式、AI、音效等） |

## Autoload 单例

在 `project.godot` 中注册（可在代码中通过名称直接访问）：

- `GlobalGameData` — 全局状态（回合、角色、统计数据）
- `AudioManager` — 音效管理（`Engine.get_singleton("AudioManager")` 调用）
- `ButtonTheme` — 按钮主题
- `BackgroundManager` / `BackgroundSingleton` — 背景管理
- `MCPRuntimeProbe` — Godot MCP 插件运行时探针

## 关键命令

项目无测试框架、无包管理器、无构建脚本。所有操作通过 Godot 编辑器完成。

- **运行项目**：Godot 编辑器中点击"运行当前场景"或 F5
- **导出**：`export_presets.cfg` 中配置 Windows Desktop 导出到 `../../5652/DestinyDawn/release/`
- **Godot MCP**：插件已安装，HTTP 模式端口 9080，OpenCode 通过 `http://localhost:9080/mcp` 连接

## 新增角色完整流程

参见 `docs/02-creating-a-character.md`，核心步骤：

1. `Global/CharacterData.gd` 的 `DATA` 字典添加条目
2. 新建 `Characters/{id}/{id}.gd`（`extends BaseCharacter`）+ `{id}.tscn`
3. 属性设置顺序：`max_hp` → `hp` → `attack` → `attack_range` → `move_points` → `super()` → `character_name`
4. 实现 `use_active_skill(target) -> bool`
5. `Scenes/main.gd` 添加 `const CHARACTER_XXX` + `_build_team_from_selection()` map + `_generate_ai_team_and_deck()` 角色池
6. `Skills/SkillEffect.gd` 的 `execute_active()` 添加 `match` 分支
7. `AI/AIController.gd` 的 `_evaluate_skill_target()` 添加分支
8. 精灵命名：`Assets/Sprites/Characters/{id}_Blue.png`（友方）/`{id}_Red.png`（敌方）

## Buff 类型速查

`BuffData.BuffType` 枚举（`Cards/BuffData.gd`）：`ATTACK_BUFF`, `ATTACK_DEBUFF`, `DEFENSE_BUFF`, `MOVE_DEBUFF`, `DAMAGE_OVER_TIME`, `HEAL_OVER_TIME`, `MARK`

## 关键编码规范

- 角色 `class_name BaseCharacter`，不使用路径字符串
- 攻击加成用 `effective_attack`（含 buff 计算），不直接读 `attack`
- 伤害调用用 `take_damage_safe()`，不用 `rpc("take_damage")`
- VFX 调用用 `play_vfx_preset_safe()`，不用 `rpc("_play_vfx_preset")`
- 技能能量消耗从 `CharacterData.get_data(id).get("skill_energy", 0)` 读取，不硬编码
- 卡牌效果函数签名 `static func _execute_xxx(card, target, main)` —**无 caster 参数**
- AOE 阵营判定用 `main.current_card_player_id`，**不使用 `GlobalGameData.is_host`**
- 卡牌描述格式：恢复→**为**，造成→**为**，术语统一

## RPC 与网络关键规则

- **单人/联机守卫短路顺序**：`not GlobalGameData.is_ai_mode and not multiplayer.is_server()`（`is_ai_mode` 在前，AI 模式无 peer）
- 所有 `rpc()` / `rpc_id()` 前检查 `multiplayer.has_multiplayer_peer()`
- 卡牌效果仅在服务端执行（`_server_play_card`）
- `call_local` 函数内部不要再调 `rpc()`
- 服务端 peer=1，客户端 peer 随机生成，端口 1145

## Git 规范

- 分支：`master`（稳定） + `feature/*`（本地开发）
- 合并策略：fast-forward，推送前 `pull --rebase`
- 提交格式：`<type>: <描述>`（type: feat/fix/refactor/style/docs/revert）
- 中文描述，首行 ≤72 字符
- 不使用 `git add -A`，手动选择文件
- `.uid` 文件由 Godot 自动生成，不手动修改
- `.tscn` 文件勿用 `Set-Content`（损坏编码），用编辑器保存或 `[System.IO.File]::WriteAllText`

## 现有文档

`docs/` 目录是权威参考源，涉及任务时优先查阅对应文档。
