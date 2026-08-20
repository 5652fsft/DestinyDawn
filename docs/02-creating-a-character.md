# 创建新角色 — 完整流程

| 步骤 | 文件 | 操作 |
|------|------|------|
| A | `Global/CharacterData.gd` | 添加数据字典条目 |
| B | `Characters/NewChar/NewChar.gd` | 新建角色脚本 |
| C | `Characters/NewChar/NewChar.tscn` | 新建角色场景 |
| D | `Assets/Sprites/Characters/` | 添加阵营贴图 |
| D | `Assets/Sprites/Standee/` | 添加立绘 |
| E | `Scenes/main.gd` | 注册 PackedScene + 编队 map |
| F | `Skills/SkillEffect.gd` | 实现技能逻辑 |
| G | `AI/` | 实现 AI 控制 |
| H | `Effects/`等 | 角色音效与特效 |

---

## A) 角色数据 — `Global/CharacterData.gd`

在 `DATA` 字典中添加条目，必填字段见下方示例。技能能量消耗通过 `skill_energy` 定义，`SkillEffect.gd` 中用 `CharacterData.get_data(id).get("skill_energy", 0)` 动态读取：

```gdscript
"newchar": {
	"name":"角色名", "hp":80, "move":5, "atk":16, "range":2,
	"skill":"技能名", "skill_desc":"技能描述", "skill_cd":3, "skill_energy":4,
	"passive":"被动名", "passive_desc":"被动描述"
}
```

---

## B) 角色脚本 — `Characters/NewChar/NewChar.gd`

- `extends BaseCharacter`（使用 class_name，非路径字符串）
- `_ready()` 中先设属性再 `super()`，顺序：`max_hp` → `hp` → `attack` → `attack_range` → `move_points` → `super()` → `character_name`
- 必须实现 `use_active_skill(target) -> bool`
- 被动在 `perform_attack` / `take_damage` 中覆写，调用 `super()` 后追加逻辑
- 攻击加成用 `effective_attack`（含 buff 计算），不直接读 `attack`
- 技能能量消耗不硬编码，从 `CharacterData.get_data(character_name).get("skill_energy")` 读取
- **技能/被动数值软编码**：数值写入 `CharacterData` 的 `skill_*` / `passive_*` 键（键列表见 `docs/06-data-format-reference.md`），执行器、角色脚本、AI（`Strategist.simulate_damage` / `Playbook`）统一 `CharacterData.get_data(id).get("键", 原默认值)` 读取；无对应键的数值（如倍率=1.0、护盾值=0）也要写键并让执行器读，避免多处漂移

### 技能范围

`skill_range` 限制技能最大 hex 距离，`0` = 无限制。参考已有角色设置。

### 属性设置顺序

```
max_hp → hp → attack → attack_range → move_points → super() → character_name
```

`super()` 前设 `max_hp` / `hp`，之后设 `character_name`（`_register_character()` 依赖 `character_name`）。

---

## C) 角色场景 — `Characters/NewChar/NewChar.tscn`

```
CharacterBody2D (input_pickable=true, script=NewChar.gd)
├ CollisionShape2D (CircleShape2D radius=59, visible=false)
├ Sprite2D
├ MultiplayerSynchronizer (replication: .:position)
└ FloatingBar (instance from Characters/FloatingBar.tscn)
```

---

## D) 素材准备

从 `C:\Users\10932\Documents\5652\DestinyDawn\character` 和 `C:\Users\10932\Documents\5652\DestinyDawn\standee` 及 `C:\Users\10932\Documents\5652\DestinyDawn\audio` 中导入素材
`Assets/Sprites/Characters/{id}_Blue.png`（友方）/ `{id}_Red.png`（敌方），运行时通过 `_update_sprite_texture()` 加载。立绘放在 `Assets/Sprites/Standee/{id}_Standee.png`。

---

## E) 注册到战斗系统 — `Scenes/main.gd`

1. 顶部添加 `const CHARACTER_NEWCHAR = preload("res://Characters/NewChar/NewChar.tscn")`
2. `_build_team_from_selection()` 的 `var map` 中添加 `"newchar": CHARACTER_NEWCHAR`
3. `_generate_ai_team_and_deck()` 的 `all_chars` 数组添加新角色 ID
4. 如果技能涉及场地效果，还需在 `FieldEffectManager.gd` 添加管理逻辑

---

## F) 技能逻辑 — `Skills/SkillEffect.gd`

- **主动技能**：`execute_active()` → `match character.character_name` 添加分支，实现 `_newchar_active()`
- **被动技能**：覆写 `take_damage` / `perform_attack`（方式一），或注册到 `get_passive_modifier()`（方式二）
- 伤害调用使用 `take_damage_safe`，不使用 `rpc("take_damage")`
- VFX 调用使用 `play_vfx_preset_safe`，不使用 `rpc("_play_vfx_preset")`

---

## G) AI 控制

---

## H) 角色音效与特效

---

## 检查清单

- [ ] `CharacterData.gd`: DATA 条目
- [ ] `NewChar.gd`: 脚本（extends BaseCharacter, _ready, use_active_skill）
- [ ] `NewChar.tscn`: 场景
- [ ] `Assets/Sprites/Characters/newchar_Blue.png` + `newchar_Red.png`
- [ ] `Assets/Sprites/Standee/newchar_Standee.png`
- [ ] `main.gd`: `const CHARACTER_NEWCHAR` + map 条目 + AI 角色池
- [ ] `SkillEffect.gd`: execute_active / get_passive_modifier 分支
- [ ] `AI/AIController.gd`: `_evaluate_skill_target()` 新增分支
