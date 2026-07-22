# 单机人机对战 — 维护指南

> 新增角色时必须同步更新 AI 逻辑，否则 AI 无法控制新角色。

---

## 新增角色时必改项

### `AI/AIController.gd`

**① `_evaluate_skill_target()` — 新增角色技能策略**

在 `match name:` 中添加新角色的技能策略分支：

```gdscript
"新角色名":
	return _xxx_skill_strategy(chara)
```

策略模板：

| 技能目标类型 | 推荐策略 |
|---|---|
| 对敌伤害 | `_find_lowest_hp_enemy()` |
| 对敌 AOE | `_find_best_aoe_target(chara)` |
| 对敌 debuff | `_find_highest_attack_enemy()` |
| 友方治疗/护盾 | `_find_lowest_hp_ally()` |
| 自身增益 | 返回 `chara` 自身 |
| 无目标 | 返回 `null` |

**② `_generate_ai_team_and_deck()` — AI 随机队伍池**

在 `Scenes/main.gd` 的角色 ID 列表中添加新角色：

```gdscript
var all_chars = ["bronya", "seele", "elaina", "firefly", "silverwolf", "hamster", "karrigan", "zephyr", "anpan"]
```

### 角色名映射

`_evaluate_skill_target()` 中的 `match` 值必须与 `BaseCharacter.gd` 的 `character_name` 完全一致：

| 角色 ID | `character_name` |
|---|---|
| bronya | "布洛妮娅" |
| seele | "希儿" |
| elaina | "伊蕾娜" |
| firefly | "流萤" |
| silverwolf | "银狼" |
| hamster | "芝士仓鼠" |
| karrigan | "karrigan" |
| zephyr | "Zephyr" |
| anpan | "あんパン" |

---

## 调试验证

AI 日志路径：`user://logs/ai.log`

查看关键条目确认技能按预期使用。如果技能未触发，检查：
1. `_should_use_skill()` 是否因 `cooldown` 或 `attack_used` 阻止
2. `match` 的角色名是否与 `character_name` 完全一致

---

## 新增角色检查清单

- [ ] `AI/AIController.gd` — `_evaluate_skill_target()` 已添加新角色分支
- [ ] `Scenes/main.gd` — `_generate_ai_team_and_deck()` 角色池已包含新角色 ID
- [ ] 运行 AI 模式，日志确认 AI 能正确控制新角色移动和技能
- [ ] LAN 联机模式不受影响（`GlobalGameData.is_ai_mode == false`）
