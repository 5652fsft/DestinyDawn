# Bug 修复与平衡性调整 — 规划文档

> 分支：`feature/ai-mode`（AI 模式相关修复）/ `master`（共享 bug 修复后 cherry-pick）
> 创建日期：2026-07-19

---

## 一、AI 模式 Bug 修复

### 1.1 AI 先手时不行动 ✅ 已修复

**根因**：`AIController._is_ai_phase()` 始终检查 `ENEMY_MOVE/ENEMY_ATTACK`，但 AI 先手时
（`is_host_turn == false`），AI 的行动阶段是 `PLAYER_MOVE/PLAYER_ATTACK`。

**修复**：`AI/AIController.gd:81` — 根据 `is_host_turn` 动态判断：
- `is_host_turn == true` → AI 检查 `ENEMY_*` 阶段
- `is_host_turn == false` → AI 检查 `PLAYER_*` 阶段

### 1.2 AI 角色移动视觉反馈 ✅ 已修复

**根因**：AI 控制的 Client 角色出生点在屏幕内可见，但移动时镜头未跟随。

**修复**：`AI/AIController.gd:39` — 新增 `_pan_to(chara)`，AI 每次执行动作前镜头平滑
移动到该角色位置（tween 0.4s）。

---

## 二、角色 Bug 修复

### 2.1 芝士仓鼠异常额外行动

**根因**：`reset_character_state()`（`main.gd:682`）每回合重置 `move_used`/`attack_used`，
但**没有重置 `_extra_attacks`**。如果 Hamster 在回合结束时仍有未消耗的 `_extra_attacks`
（例如：使用了技能但回合提前结束），该值会跨回合继承，导致下回合不消耗技能即可获得额外行动。

**触发路径**：
1. Hamster 使用"动作如潮" → `_extra_attacks = 1`
2. 本回合其他角色全部行动完毕 → `check_attack()` 推进阶段
3. 下回合开始 → `reset_character_state()` 不重置 `_extra_attacks`
4. Hamster 的 `_get_extra_attacks() > 0` → 可无消耗获得额外行动

**修复方案**：`reset_character_state()` 中遍历所有角色时，如果角色有 `_extra_attacks` 变量，
将其重置为 0。

```gdscript
# main.gd reset_character_state() 中追加：
if "_extra_attacks" in c:
    c._extra_attacks = 0
```

### 2.2 芝士仓鼠射程削弱

**需求**：`attack_range` 从 4 改为 3。

**修改文件**：`Characters/Hamster/Hamster.gd:13`
```gdscript
attack_range = 3  # 原为 4
```

---

## 三、卡牌 Bug 修复（14 项）

### 概述

卡牌系统的根本问题是 `CardEffect.gd` 的 `execute()` 函数使用**单一 EffectType** 分发，
但许多卡牌需要**复合效果**（伤害 + debuff、伤害 + 抽牌、条件判定等）。

### 3.1 冻结术 — `card_frostbite`

| 维度 | 内容 |
|---|---|
| **描述** | 造成 15 点伤害并附加迟缓 2 回合 |
| **现状** | 仅附加迟缓，无伤害 |
| **根因** | `EffectType.DEBUFF_MOVE` 只执行 debuff |
| **修复** | 新增复合效果处理：先调用 `target.take_damage(15)`，再执行 debuff |

```gdscript
# CardEffect.gd 新增 EffectType.FROSTBITE 或在 _execute_damage 后追加 debuff
# 最简方案：在 execute() 的 DEBUFF_MOVE 分支中，检查 card_id 是否为 frostbite，
# 如果是，先执行 15 点伤害
```

### 3.2 法力汲取 — `card_siphon`

| 维度 | 内容 |
|---|---|
| **描述** | 造成 8 点伤害并抽 1 张牌 |
| **现状** | 仅抽牌，无伤害 |
| **根因** | `EffectType.DRAW_CARD` 只执行抽牌 |
| **修复** | 在 `_execute_draw_card` 中或通过新 EffectType 先执行伤害再抽牌 |

### 3.3 能量过载 — `card_overload`

| 维度 | 内容 |
|---|---|
| **描述** | 获得 2 能量，自身受到 5 点伤害 |
| **现状** | 抽 1 张牌（完全无关） |
| **根因** | `EffectType.DRAW_CARD` 映射错误 |
| **修复** | 新增 `EffectType.ENERGY_SELF_DAMAGE` 或自定义处理：调用 `energy_system.set_energy()` + `caster.take_damage()` |

### 3.4 双刃剑 — `card_double_edge`

| 维度 | 内容 |
|---|---|
| **描述** | 攻击 +15，防御 -5（持续 2 回合） |
| **现状** | 仅攻击 +15，无防御 debuff |
| **根因** | `EffectType.BUFF_ATTACK` 只执行一种 buff |
| **修复** | `_execute_buff_attack` 中检查 card_id 是否为 double_edge，额外附加 `defense_debuff` |

### 3.5 护盾过载 — `card_shield_overload`

| 维度 | 内容 |
|---|---|
| **描述** | 获得 10 护盾，若已有护盾则翻倍 |
| **现状** | 始终加 10，不翻倍 |
| **根因** | `_execute_shield` 无翻倍逻辑 |
| **修复** | 在 shield 增加前检查 `target.shield > 0`，若大于 0 则将 `effect_value` 设为 `target.shield`（翻倍）而不是固定 10 |

### 3.6 生命分流 — `card_life_split`

| 维度 | 内容 |
|---|---|
| **描述** | 治疗 15 点，若目标满血则额外抽 1 张牌 |
| **现状** | 仅治疗；满血时因 `heal_amount <= 0` 直接 return false |
| **根因** | HEAL 逻辑中满血时提前退出 |
| **修复** | `_execute_heal` 中检查 `target.hp == target.max_hp` 时调用 `main.draw_extra_card()` |

### 3.7 惩戒 — `card_reckoning`

| 维度 | 内容 |
|---|---|
| **描述** | 造成 8×目标身上 buff 数的伤害 |
| **现状** | 始终 8 点伤害 |
| **根因** | 未读取目标 buff 数量 |
| **修复** | `_execute_damage` 中检查 card_id，若为 reckoning 则计算 buff 数量：`var buff_count = 0; for buff_list in target.buffs.values(): buff_count += buff_list.size(); dmg = 8 * buff_count` |

### 3.8 嘲讽 — `card_taunt`

| 维度 | 内容 |
|---|---|
| **描述** | 嘲讽目标，使其强制攻击施法者（持续 1 回合） |
| **现状** | Buff 已存储但无强制攻击逻辑 |
| **根因** | 战斗系统和 AI 均未检查 taunt buff |
| **修复** | 范围较大，需修改 `handle_attack()` 和 AI 的 `_evaluate_attack_target()`：如果目标有 taunt buff 且施法者存活，必须优先攻击施法者 |

### 3.9 回响 — `card_echo`

| 维度 | 内容 |
|---|---|
| **描述** | 额外抽 2 张牌 |
| **现状** | 抽 1 张牌 |
| **根因** | `draw_extra_card()` 硬编码抽 1 张 |
| **修复** | `draw_extra_card()` 增加 `count` 参数，`_execute_draw_card` 传入 `card.effect_value` |

### 3.10 施法者选取 — 所有卡牌

| 维度 | 内容 |
|---|---|
| **描述** | 卡牌应该由选中的角色释放 |
| **现状** | 施法者总是选取玩家方第一个存活的角色 |
| **根因** | `main.gd _execute_play_card()` 第 464-475 行遍历查找第一个存活角色 |
| **修复** | 将 caster 改为 `selected_character`（需要确保 AI 调用时也传入正确的 caster） |

### 3.11 自选目标验证 — SELF 卡牌

| 维度 | 内容 |
|---|---|
| **描述** | SELF 卡牌必须只能点击自己 |
| **现状** | 点击任意角色都被接受 |
| **根因** | `_is_valid_target` 中 SELF 分支仅检查 `selected_character != null` |
| **修复** | 改为 `return hit == selected_character` |

### 3.12 暗影步 — `card_shadowstep` 传送验证

| 维度 | 内容 |
|---|---|
| **描述** | 传送目标必须有效（不越界、不重叠、不穿墙） |
| **现状** | 随机选取邻居格，无任何验证 |
| **修复** | 在选取邻居格时检查 `get_move_cost()` 和 `is_cell_occupied()` |

### 3.13 闪电链 — `card_chain_lightning` 友伤

| 维度 | 内容 |
|---|---|
| **描述** | 闪电链应该只伤害敌人 |
| **现状** | 伤害所有附近角色（包括友方） |
| **根因** | `_execute_chain_damage` 未过滤敌友 |
| **修复** | 增加 `_is_host_side()` 过滤，只伤害敌方 |

### 3.14 传送/交换卡牌单机崩溃风险

| 维度 | 内容 |
|---|---|
| **描述** | 单机模式下调用 `rpc()` 可能崩溃 |
| **现状** | `_execute_teleport` 等函数无条件调用 `target.rpc(...)` |
| **修复** | 统一使用 `if target.has_method("rpc"): target.rpc(...) else: target.take_damage(...)` 模式 |

---

## 四、卡牌平衡性调整

### 4.1 核心原则：卡牌强度与费用正相关

> **写入 `docs/06-data-format-reference.md`**：所有卡牌的 `effect_value` 必须与 `cost` 成正比，
> 确保高费卡牌比低费卡牌提供更高的总价值。

| 费用 | 预期总价值 | 示例 |
|---|---|---|
| 0 | 20-30 点效果值 | 过载（2能量=约20价值，自伤5为代价） |
| 1 | 25-40 点效果值 | 冰晶碎片(12)、小治愈(10)、毒刃(8+DoT) |
| 2 | 40-60 点效果值 | 火球术(25)、护盾(15)、瞄准(35) |
| 3 | 60-80 点效果值 | 烈焰风暴(AOE 30)、箭雨(AOE 20)、闪电链 |

### 4.2 具体调整方案

#### 攻击类卡牌

| 卡牌 | 费用 | 当前 | 调整后 | 理由 |
|---|---|---|---|---|
| 火球术 `fireball` | 2 | 伤害25 | 伤害30 | 2费单体标杆 |
| 冰晶碎片 `ice_shard` | 1 | 伤害12 | 伤害12 | 1费基准，合理 |
| 瞄准射击 `aim` | 2 | 伤害35 | 伤害35 | 无附加效果，高伤合理 |
| 冻结术 `frostbite` | 2 | 伤害15+减速 | 伤害15+减速 | 修复后为复合效果，合理 |
| 法力汲取 `siphon` | 1 | 伤害8+抽1 | 伤害8+抽1 | 修复后为1费高价值 |
| 毒刃 `poison_blade` | 1 | 伤害8+3回合DoT | 伤害6+3回合DoT(每回合8) | 提高 DoT 到每回合8 |
| 惩戒 `reckoning` | 1 | 伤害8×buff数 | 伤害8×buff数 | 修复后为可成长伤害 |
| 烈焰风暴 `firestorm` | 3 | AOE 30 | AOE 30 | 3费 AOE，合理 |
| 箭雨 `arrow_rain` | 3 | AOE 20 | AOE 20 | 范围更大，合理 |
| 闪电链 `chain_lightning` | 3 | 连锁伤害20递减 | 连锁伤害24递减 | 修复后剔除友伤 |
| 双刃剑 `double_edge` | 1 | ATK+15/DEF-5 | ATK+15/DEF-5 | 修复后1费合理 |

#### 治疗类卡牌

| 卡牌 | 费用 | 当前 | 调整后 | 理由 |
|---|---|---|---|---|
| 治愈之光 `heal` | 2 | 治疗20 | 治疗25 | 2费治疗标杆 |
| 小治愈 `small_heal` | 1 | 治疗10 | 治疗12 | 1费低标 |
| 群体治愈 `mass_heal` | 3 | AOE 15 | AOE 18 | 3费 AOE 治疗 |
| 治疗波 `heal_wave` | 2 | AOE 12 | AOE 12 | 2费 AOE，合理 |
| 生命分流 `life_split` | 1 | 治疗15+condition | 治疗15+condition | 修复后1费高价值 |
| 再生术 `regen` | 1 | HOT 6×3回合 | HOT 6×3回合 | 持续效果，合理 |

#### 护盾类卡牌

| 卡牌 | 费用 | 当前 | 调整后 | 理由 |
|---|---|---|---|---|
| 护盾屏障 `shield` | 2 | 护盾15 | 护盾20 | 2费标杆 |
| 冰盾 `ice_shield` | 2 | 护盾20 | 护盾20 | 与护盾对齐 |
| 护盾过载 `shield_overload` | 1 | 护盾10/翻倍 | 护盾10/翻倍 | 修复后1费高价值 |

#### Buff/Debuff 类卡牌

| 卡牌 | 费用 | 当前 | 调整后 | 理由 |
|---|---|---|---|---|
| 力量强化 `strength` | 1 | ATK+10,2回合 | ATK+12,2回合 | 1费 buff 基准上调 |
| 铁壁防御 `fortify` | 1 | DEF+8,2回合 | DEF+10,2回合 | 与力量对齐 |
| 加速 `haste` | 1 | MOVE+3,2回合 | MOVE+3,2回合 | 合理 |
| 铁壁形态 `iron_wall` | 2 | DEF+15,3回合 | DEF+15,3回合 | 自身限定，合理 |
| 虚弱诅咒 `weakness` | 1 | ATK-8,2回合 | ATK-8,2回合 | 1费 debuff 基准 |
| 迟缓术 `slow` | 1 | MOVE-2,1回合 | MOVE-2,1回合 | 合理 |
| 标记 `mark` | 1 | +50%伤害,2回合 | +50%伤害,2回合 | 合理 |
| 出血 `hemorrhage` | 1 | DOT 8×3回合 | DOT 8×3回合 | 合理 |
| 时停 `disarm` | 2 | ATK-10,3回合 | ATK-12,3回合 | 2费 debuff 增强 |

#### 战术类卡牌

| 卡牌 | 费用 | 当前 | 调整后 | 理由 |
|---|---|---|---|---|
| 谋略 `draw` | 1 | 抽1 | 抽1 | 合理 |
| 回响 `echo` | 2 | 抽2 | 抽2 | 修复后价值提升 |
| 净化 `cleanse` | 1 | 移除减益 | 移除减益 | 情景卡，合理 |
| 能量过载 `overload` | 0 | 修复前抽1 | +2能量，自伤5 | 修复后为核心战术卡 |
| 嘲讽 `taunt` | 1 | 强制攻击 | 强制攻击 | 修复后 1费情景卡 |
| 暗影步 `shadowstep` | 2 | 传送+15伤害 | 传送+15伤害 | 位移+伤害复合 |

---

## 五、实施顺序

### Phase 1：AI 模式 Bug（已完成）
- [x] AI 先手不行动 — `_is_ai_phase()` 修复
- [x] AI 移动视觉反馈 — `_pan_to()` 镜头跟随

### Phase 2：角色修复（估算 1h）
- [ ] Hamster `_extra_attacks` 跨回合重置 — `main.gd reset_character_state()`
- [ ] Hamster 射程 4→3 — `Hamster.gd`

### Phase 3：卡牌复合效果（估算 3-4h）
- [ ] `draw_extra_card()` 增加 count 参数
- [ ] `frostbite` — 伤害 + debuff 复合
- [ ] `siphon` — 伤害 + 抽牌复合
- [ ] `double_edge` — buff + debuff 复合
- [ ] `shield_overload` — 翻倍逻辑
- [ ] `life_split` — 满血抽牌条件
- [ ] `reckoning` — buff 计数动态伤害
- [ ] `overload` — 能量 + 自伤效果（新 EffectType）

### Phase 4：卡牌系统修复（估算 2-3h）
- [ ] 施法者选取改为 `selected_character`
- [ ] SELF 目标验证修复
- [ ] `shadowstep` 传送验证
- [ ] `chain_lightning` 过滤友伤
- [ ] 单机 rpc 安全保护
- [ ] `taunt` AI 强制攻击逻辑

### Phase 5：平衡性调整（估算 2h）
- [ ] 按 4.2 节调整所有卡牌数值
- [ ] 更新 `docs/06-data-format-reference.md` — 加入强度与费用正相关原则

### Phase 6：回归测试（估算 2h）
- [ ] LAN 联机模式完整测试
- [ ] AI 模式完整测试
- [ ] 单张卡牌逐个功能测试
- [ ] AI 日志检查确认无异常

---

## 六、Git 提交计划

```
fix: reset Hamster _extra_attacks on turn start
fix: reduce Hamster attack_range from 4 to 3
fix: add count parameter to draw_extra_card
fix: implement composite effects for frostbite/siphon/double_edge
fix: implement shield_overload doubling logic
fix: implement life_split conditional draw
fix: implement reckoning buff-count damage scaling
fix: implement overload energy+self-damage effect
fix: use selected_character as card caster
fix: validate SELF target_type correctly
fix: validate shadowstep teleport destination
fix: filter friendly fire in chain_lightning
fix: safe rpc fallback for single-player
fix: implement taunt AI enforcement
balance: adjust card values per cost curve
docs: add cost-strength correlation principle to docs/06
```

---

## 七、风险与注意事项

| 风险 | 影响 | 应对 |
|---|---|---|
| 复合效果改动影响其他卡牌 | 连锁崩溃 | 每次改动后用日志验证所有相关卡牌 |
| `selected_character` 作为施法者可能为空 | 卡牌无法释放 | 增加 fallback：如果 `selected_character` 为空则使用第一个存活角色 |
| 平衡调整使部分关卡过难/过易 | 游戏体验下降 | 调整后需至少进行 3 局 AI 对战测试 |
| `taunt` 的 AI 逻辑可能过于复杂 | 开发成本高 | 暂缓实现，先修复其他卡牌；taunt 作为 AI 后续迭代 |
