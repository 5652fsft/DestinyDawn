# 单机人机对战 — 维护指南

> 新增角色时必须同步更新 AI 逻辑，否则 AI 无法控制新角色。

## 新增角色时必改项

### `AI/AIController.gd`

**`_evaluate_skill_target()`** — 在 `match name:` 添加分支：

| 技能目标类型 | 推荐策略 |
|-------------|---------|
| 对敌伤害 | `_find_lowest_hp_enemy()` |
| 对敌 AOE | `_find_best_aoe_target(chara)` |
| 对敌 debuff | `_find_highest_attack_enemy()` |
| 友方治疗/护盾 | `_find_lowest_hp_ally()` |
| 自身增益 | 返回 `chara` 自身 |

### `Scenes/main.gd`

`_generate_ai_team_and_deck()` 的 `all_chars` 数组添加新角色 ID。

## 技能能量

技能能量消耗定义在 `CharacterData.gd` 的 `skill_energy` 字段，AI 施放前自动通过 `SkillEffect.get_skill_block_reason()` 检查。

## AI 决策流程

```
_build_action_queue()
├ 移动队列：评估移动目标
└ 行动队列：技能 → 卡牌 → 攻击
→ _execute_current_action() 逐个执行
→ 队列清空 → _end_phase()
```

## 检查清单

- [ ] `AIController.gd` — `_evaluate_skill_target()` 新角色分支
- [ ] `main.gd` — AI 角色池已包含新角色 ID
- [ ] 运行 AI 模式确认 AI 能正确控制新角色
