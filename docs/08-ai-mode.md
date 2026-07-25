# 单机人机对战 — 维护指南

> 新增角色时必须同步更新 AI 逻辑，否则 AI 无法控制新角色。

## 新增角色时必改项

### `AI/AIController.gd`

**① `_evaluate_skill_target()` — 新增角色技能策略**

在 `match name:` 中添加分支：

| 技能目标类型 | 推荐策略函数 |
|-------------|-------------|
| 对敌伤害 | `_find_lowest_hp_enemy()` |
| 对敌 AOE | `_find_best_aoe_target(chara)` |
| 对敌 debuff | `_find_highest_attack_enemy()` |
| 友方治疗/护盾 | `_find_lowest_hp_ally()` |
| 自身增益 | 返回 `chara` 自身 |
| 无目标 | 返回 `null` |

**② `_evaluate_move_target()` — 移动策略**

默认就近接敌。如需特殊移动行为（如远程角色保持距离），在新角色分支中覆写。

### `Scenes/main.gd`

`_generate_ai_team_and_deck()` 的 `all_chars` 数组添加新角色 ID，否则 AI 不会选用。

## 技能能量系统

- 技能能量消耗定义在 `CharacterData.gd` 的 `skill_energy` 字段
- AI 施放技能前自动调用 `SkillEffect.get_skill_block_reason()` 检查能量是否足够
- 能量不足时按钮禁用并提示"能量不足"

## AI 决策流程

```
_build_action_queue()
├ 移动队列：为每个存活角色评估移动目标
└ 行动队列：
   ├ 技能（如有能量且条件满足）
   ├ 卡牌（如有可用且评分高）
   └ 攻击（如有目标在射程内）

→ _execute_current_action() 逐个执行动作
→ 队列清空后 _end_phase() 结束当前回合
```
