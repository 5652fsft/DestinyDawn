# 单机人机对战 — 维护指南

> 新增角色时必须同步更新 AI 逻辑，否则 AI 无法控制新角色。

## AI 架构总览（v2）

```
AI/AIController.gd     决策调度 + 动作执行（时序、校验、烟格、防循环）
├── AI/Strategist.gd   通用评估器（静态纯函数：查询/伤害模拟/评分/规划）
│   ├── plan_unit()    单元规划：技能 + 攻击 + 移动的组合
│   ├── plan_cards()   出牌规划（能量预算、分数贪心）
│   └── find_best_smoke_cell()  karrigan 放烟选址
├── AI/Playbook.gd     角色打法档案（12 角色技能时机/目标/价值/独占性）
└── AI/TeamBuilder.gd  配队 + 卡组生成
```

依赖方向：`AIController → Strategist → Playbook`（Playbook 不依赖 Strategist 的规划层，只复用其查询函数）。

## AI 决策流程

```
回合开始 → _plan_and_queue()
├ 1. 出牌规划 plan_cards()：按分数贪心，预算 = 能量 - 技能预留
│      （Anjing 预留 2 / あんパン 预留 4，能量不足则无需预留）
├ 2. 单元规划 plan_unit()：每角色 技能+攻击+移动 组合，按总价值降序入队
│      技能耗行动 → 与普攻二选一（取价值高者）
│      技能不耗行动（仅 Zephyr/芝士仓鼠/Richardovo）→ 先放技能再普攻
│      （Zephyr 自伤增攻 / Richardovo 突破 / 芝士仓鼠 +1 行动）
│      独占技能（M1DorG）→ 先普攻再技能（away 状态锁后续行动）
│      射程过滤：技能目标超出 skill_range 则放弃技能
└ 3. 队列空 → _end_phase()
→ _execute_current_action() 逐个执行（移动 → 攻击 → 技能 → 卡牌）
→ 执行校验：角色/目标存活、攻击六边形射程、卡牌在手牌/能量足够
→ 卡牌执行失败 → 记入 _card_skip，本回合不再尝试
→ 停在烟格 → character_move_used 重置（免费再动，与玩家规则一致）
```

## 距离规则

- **所有距离一律使用六边形格子距离**（`HexUtils.hex_distance`，与 BFS 步数一致），禁止像素距离（`distance_to` / `distance_squared_to`）。
- 攻击射程判定：`HexUtils.hex_distance(攻击者格, 目标格) <= attack_range`。
- 技能射程判定：`SkillEffect.get_cells_in_range(grid_layer, 施法者格, skill_range)`。
- 移动可达：`HexUtils.get_reachable_cells`（BFS，含地形代价）。

## 伤害模拟（simulate_damage）

与实战公式保持一致（`BaseCharacter.take_damage` + 角色被动）：

1. 攻击者被动：Zephyr 附加 `(max_hp - hp) × 0.6`；Seele 打满血目标 ×1.5
2. 受击者 MARK（标记类总值，百分比增伤）
3. 受击者 `defense_buff` 减免（负数=易伤）
4. Zephyr 受击时 `ascend` 层数百分比减伤（clamp 0~20）

击杀判定：`目标 hp + 护盾 <= 最终伤害`，价值 `KILL_SCORE(1000) + 伤害`。

## Playbook — 角色打法档案

各角色技能时机 / 目标选择 / 价值公式的**权威说明在 `AI/Playbook.gd` 顶部注释与各 `_skill_xxx()` 函数注释**（随代码维护，本文件不重复）。要点：

- `evaluate_skill(chara, main, sim_state)` 返回：`{"use", "target", "cell", "value", "exclusive"}`；`sim_state` 供 Zephyr 连续释放评估（模拟层数/血量）
- 技能耗行动 → 不用填 `exclusive`（默认 false）
- 技能用后锁行动（如 M1DorG）→ `"exclusive": true`（AI 会先普攻再技能）
- CELL 型技能（如 karrigan 烟雾）→ 返回 `"cell"`，选址逻辑写进 Strategist 或复用 `find_best_smoke_cell`
- 无冷却不耗行动技能（Zephyr）→ `can_repeat_skill()` + `simulate_after_skill()` 支持同回合连放

## 卡牌评分要点

- 攻击卡：`CARD_KILL_SCORE(220)` 击杀优先；AOE 按命中数放大；`card_reckoning` 按目标效果数放大
- 副数值伤害卡（siphon=6、overload=5、frostbite=12、poison_blade=4 的直伤）：数值存于 `CardData.secondary_value`（overload 回能在 `extra_value`），执行器与 `_card_base_damage` 同源读取，不硬编码
- 治疗/护盾：按目标血线分档（80/60/30/10 等）；AOE 治疗按全队损血估值
- Buff 卡：Richardovo 在场优先给他（突破联动 → 额外行动）；输出名单 Richardovo/Zephyr/Seele/芝士仓鼠/Anjing 有额外加分
- Debuff 卡：虚弱→最高攻击、迟缓→近战敌人、标记→低血集火目标
- 战术卡：overload（能量<max-1 才用）、抽牌（手牌少价值高）、净化（有负面才用）
- 出牌阈值：分数 ≥ 20 才出

## 配队 / 卡组（TeamBuilder）

- 配队软约束：≥1 核心输出（seele/elaina/hamster/richardovo/zephyr/anjing）、≥1 功能辅助（bronya/silverwolf/anpan/karrigan）、≥1 能扛（firefly/bronya/M1DorG/zephyr/karrigan，firefly 为副C兼肉）；随机采样 30 次，失败则兜底 1+1+1，允许双辅助一输出等灵活组合
- 卡组 8 张：1 费 3 + 2 费 3 + 3 费 2（0 费可补位），必带 ≥1 治疗/护盾 + ≥1 debuff，单卡 ≤2 张

## 新增角色时必改项

1. **`AI/Playbook.gd`** — `evaluate_skill()` 的 `match character_name` 添加分支，编写 `_skill_<name>()`，按文件顶部注释格式返回评估字典，并在顶部策略注释补一行
2. **`AI/TeamBuilder.gd`** — `ALL_CHARS` 数组添加新角色 ID；按定位加入 `CORE_OUTPUT` / `SUPPORT` / `TANKY`
3. 运行 AI 模式确认 AI 能正确控制新角色

## 检查清单

- [ ] `AI/Playbook.gd` — `evaluate_skill()` 新角色分支
- [ ] `AI/TeamBuilder.gd` — 角色池已包含新角色 ID
- [ ] 距离计算使用 `HexUtils.hex_distance` / BFS，无像素距离
- [ ] 技能耗能量角色（Anjing / あんパン）已考虑 `_skill_energy_reserve`
- [ ] 独占技能（M1DorG）已标记 `exclusive`
- [ ] 运行 AI 模式确认 AI 能正确控制新角色
