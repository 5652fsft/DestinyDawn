# 创建新角色 — 流程

| 步骤 | 文件 | 操作 |
|------|------|------|
| A | `Global/CharacterData.gd` | DATA 字典添加条目 |
| B | `Characters/NewChar/NewChar.gd` | 新建脚本，extends BaseCharacter |
| C | `Characters/NewChar/NewChar.tscn` | 新建场景（CharacterBody2D + Sprite2D + CollisionShape2D + FloatingBar） |
| D | `Assets/Sprites/Characters/` | 阵营贴图（id_Blue.png / id_Red.png） |
| E | `Assets/Sprites/Standee/` | 立绘（id_Standee.png） |
| F | `Scenes/main.gd` | 注册 PackedScene + 编队 map + AI 角色池 |
| G | `Skills/SkillEffect.gd` | 主动/被动技能逻辑 |

---

## A) 角色数据 — `CharacterData.gd`

```gdscript
"newchar": {
	"name":"角色名", "hp":80, "move":5, "atk":16, "range":2,
	"skill":"技能名", "skill_desc":"技能描述", "skill_cd":3,
	"skill_energy":4,        # 技能能量消耗（默认 0）
	"passive":"被动名", "passive_desc":"被动描述"
}
```

> `skill_energy` 定义技能的能量消耗，`SkillEffect.gd` 中通过 `CharacterData.get_data(id).get("skill_energy", 0)` 读取。

## B) 角色脚本 — `NewChar.gd`

- `extends BaseCharacter`（使用 class_name，非路径字符串）
- `_ready()` 中先设 `max_hp` / `attack` / `move_points` / `attack_range` 再 `super()`
- 必须实现 `use_active_skill(target: Node) -> bool`
- 被动在 `perform_attack` / `take_damage` 中覆写，调用 `super()` 后追加逻辑
- 攻击加成用 `effective_attack`（含 buff 计算），不直接读 `attack`

## C) 角色场景 — `NewChar.tscn`

```
CharacterBody2D (input_pickable=true)
├ CollisionShape2D (CircleShape2D radius=59, visible=false)
├ Sprite2D
├ MultiplayerSynchronizer (sync .:position)
└ FloatingBar (instance from Characters/FloatingBar.tscn)
```

## D) 素材

`Assets/Sprites/Characters/{id}_Blue.png`（友方）/ `{id}_Red.png`（敌方），运行时通过 `_update_sprite_texture()` 加载。

## E) 注册战斗

- `main.gd` 顶部添加 `const CHARACTER_NEWCHAR = preload(...)`，编队 map 添加映射
- `_generate_ai_team_and_deck()` 角色池添加新 ID

## F) 技能逻辑 — `SkillEffect.gd`

- **主动技能**：`execute_active()` → `match char_name` 添加分支，引用角色名（`character_name`）
- **被动技能**：`get_passive_modifier()` 添加分支，或直接在角色脚本覆写 `take_damage` / `perform_attack`
- 能量消耗通过 `CharacterData.get_data(character).get("skill_energy")` 读取，不硬编码

## G) AI — `AIController.gd`

- `_evaluate_skill_target()` 添加技能策略分支（`match name:`）
- 伤害类用 `_find_lowest_hp_enemy`，增益类用 `_find_lowest_hp_ally`，自增益返回自身
