# Destiny Dawn 游戏项目 — AI快速导览

**目标读者**：AI大模型 | **开发者**：5652 | **引擎**：Godot 4.7.1

---

## 1. 项目概述

Destiny Dawn 是一款基于 Godot 4.7.1 的回合制六边形战棋卡牌游戏，两名玩家各控制 3 名角色（从 11 名角色中选择），在六角格地图上使用卡牌与技能对战。

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

| 步骤 | 文档 | 说明 |
|---|---|---|
| 1 | `docs/05-rpc-conventions.md` | **先读**：网络同步模式、AI 模式短路规则、RPC 保护 |
| 2 | `docs/02-creating-a-character.md` | 角色数据/脚本/技能/AI 注册 |
| 3 | `docs/03-creating-a-card.md` | 卡牌注册/效果实现/描述规范 |
| 4 | `docs/06-data-format-reference.md` | CharacterData/BuffData 字段速查 |
| 5 | `docs/04-creating-ui.md` | 按钮/面板/字体规范 |
| 6 | `docs/08-ai-mode.md` | AI 策略分支注册 |
| 7 | `docs/09-audio-system.md` | 音效添加与调用 |

---

## 3. 文件架构

```
destiny-dawn/
├── Global/                    # 单例 + 工具
│   ├── GlobalGameData.gd         # autoload，全局战斗状态
│   ├── HexUtils.gd               # 六边形 BFS / HEX_DIRS / HEX_RADIUS / HEX_SPACING
│   ├── AudioManager.gd           # 音效管理（autoload）
│   ├── BuffManager.gd / BuffDatabase.gd
│   ├── ButtonTheme.gd            # 按钮主题（autoload）
│   ├── CharacterData.gd          # 角色基础数据（含 skill_energy）
│   ├── FieldEffectManager.gd     # 场地效果（烟雾等）
│   └── VFXManager.gd             # GPUParticles2D 特效（7 种 preset）
├── Scenes/                    # 主战斗场景 main.gd（~1400行）+ camera.gd
├── Characters/                # 每个角色独立子目录
│   ├── BaseCharacter.gd          # class_name BaseCharacter
│   └── Bronya/Seele/Elaina/...   # 11 个角色（extends BaseCharacter）
├── Cards/                     # 卡牌系统
│   ├── CardDatabase.gd / CardData.gd / CardEffect.gd
├── Skills/                    # 技能效果
│   └── SkillEffect.gd            # 主动技能 + 被动修正
├── AI/                        # AI 控制器
│   └── AIController.gd           # 决策队列 + 策略函数
├── UI/                        # 战斗界面（HandPanel / SkillPanel / CardUI 等）
├── Menus/                     # 主菜单 / 编队 / 卡组 / 设置
├── Effects/                   # 浮动伤害数字
└── Assets/                    # 贴图 / 音效 / 字体
```

### 核心机制

- **回合合并**：每个角色每回合可执行 1 次移动 + 1 次攻击/技能，顺序自由
- **卡牌独立**：卡牌由玩家释放，不消耗角色行动次数，无 caster 概念
- **AOE 阵营**：通过 `main.current_card_player_id` 判断，不使用 `GlobalGameData.is_host`
- **角色能量**：技能能量消耗定义在 `CharacterData.gd` 的 `skill_energy` 字段，通过 `CharacterData.get_data(id).get("skill_energy", 0)` 读取，不硬编码
- **网络模式**：`@rpc("any_peer", "call_local", "reliable")` 攻击伤害双方可见；AI 模式无 peer，所有 `is_server()` 前必须短路 `GlobalGameData.is_ai_mode`
