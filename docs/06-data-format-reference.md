# 数据格式速查

## 角色数据 — `Global/CharacterData.gd`

```gdscript
const DATA = {
	"<character_id>": {             # 字符串键，全小写英文
		"name":        "<中文名>",   # 显示用中文名
		"hp":          <int>,       # 基础生命值
		"move":        <int>,       # 移动力（格数）
		"atk":         <int>,       # 基础攻击力
		"range":       <int>,       # 攻击射程（格数）
		"skill":       "<技能名>",   # 主动技能名称
		"skill_desc":  "<技能描述>", # 主动技能描述文本
		"skill_cd":    <int>,       # 主动技能冷却回合
		"skill_energy":<int>,       # 技能能量消耗（可选，默认 0）
		"passive":     "<被动名>",   # 被动技能名称
		"passive_desc":"<被动描述>", # 被动技能描述文本
		# —— 数值软编码键（可选，默认值见 SkillEffect/角色脚本）——
		"skill_value":          <int>,   # 技能固定数值（布洛妮娅护盾=30）
		"skill_multiplier":     <float>, # 技能攻击倍率（希儿=1.2、伊蕾娜=1.25、流萤=1.8、Anjing=0.5）
		"skill_radius":         <int>,   # 技能 AOE 半径（伊蕾娜=2、karrigan 烟=3）
		"skill_duration":       <int>,   # 技能效果持续回合（karrigan 烟=2）
		"skill_buff_id":        "<buff_id>",  # 技能施加的 buff（流萤="burn"、Zephyr="ascend"）
		"skill_buff_value":     <int>,   # buff 数值（流萤灼烧=5、Zephyr 攀升=10、あんパン松软=20）
		"skill_buff_duration":  <int>,   # buff 持续回合（流萤=2、あんパン=3）
		"skill_self_damage_pct":<float>, # 自伤百分比（Zephyr=0.2）
		"skill_away_turns":     <int>,   # 锁行动回合（M1DorG=2）
		"skill_extra_actions":  <int>,   # 获得额外行动数（芝士仓鼠=1）
		"skill_attack_value":   <int>,   # 技能减益值（银狼虚弱=8）
		"skill_move_value":     <int>,   # 技能减益值（银狼迟缓=2）
		"skill_hand_damage":    <int>,   # 手牌数×伤害（Anjing=3）
		"passive_chance":        <float>, # 被动触发概率（可选；流萤/银狼被动已改 100% 触发，当前无角色使用该键）
		"passive_reduction":     <float>, # 被动减伤（布洛妮娅=0.2）
		"passive_reduction_low": <float>, # 低血减伤（布洛妮娅=0.35）
		"passive_low_hp":        <float>, # 低血阈值（布洛妮娅=0.5）
		"passive_full_hp_bonus": <float>, # 满血增伤（希儿=0.5）
		"passive_damage_pct":    <float>, # 已损血量加成（Zephyr=0.6）
		"passive_buff_value":    <int>,   # 被动 buff 数值（仓鼠嗜血=50、流萤灼烧=5）
		"passive_buff_duration": <int>,   # 被动 buff 持续（仓鼠=2）
		"passive_magic_value":   <int>,   # 伊蕾娜魔力充盈=15
		"passive_magic_duration":<int>,   # 伊蕾娜=2
		"passive_hot_burn_value":<int>,   # あんパン高温烫嘴=5
		"passive_hot_burn_duration":<int>,# あんパン=2
		"passive_luck_value":    <int>,   # Anjing 牌运=2
		"passive_luck_duration": <int>,   # Anjing=2
		"passive_rope_value":   <int>,   # karrigan 拧绳=5（攻击力+5，永久）
		"passive_heal":          <int>,   # M1DorG 被动回血=10
		"passive_solo_value":    <int>,   # Richardovo 我独自升级=20
	},
}
```

> `skill_energy` 为可选字段，定义主动技能消耗的能量值。**无该字段 = 无能量消耗**。`SkillEffect.gd` 中通过 `CharacterData.get_data(id).get("skill_energy", 0)` 动态读取。
>
> **数值软编码约定**：技能/被动数值一律写入 `CharacterData` 的上述键（缺键即视为数据错误），执行器（`SkillEffect.gd` / 角色脚本）、AI（`Strategist.simulate_damage` / `Playbook`）统一用 `CharacterData.get_data(id)["键"]` 直接读取，**不写兜底默认值**。Buff 叠加上限在 `BuffDatabase.gd` 的 `max_stacks` 定义。

## Buff 数据 — `Global/BuffDatabase.gd` / `BuffData.gd`

Buff 定义在 `BuffDatabase.gd` 中，各字段：

- `id`: 唯一标识（如 `"attack_buff"`）
- `name`: 显示名
- `type`: `BuffData.BuffType` 枚举
- `category`: `BuffData.Category`（POSITIVE / NEGATIVE / NEUTRAL）
- `is_harmful`: 是否为有害效果
- `max_stacks`: 最大叠加层数
- `has_tick`: 是否有每回合 tick 效果

### BuffType 枚举 (`BuffData.gd`)

| 枚举值 | 说明 | 效果 |
|--------|------|------|
| `ATTACK_BUFF` | 攻击增益 | `effective_attack` 计算 |
| `ATTACK_DEBUFF` | 攻击减益 | `effective_attack` 计算 |
| `DEFENSE_BUFF` | 防御增益/减益 | `take_damage` 中减免 |
| `MOVE_DEBUFF` | 移动减益 | `effective_move_points` 计算 |
| `DAMAGE_OVER_TIME` | 持续伤害 | `process_buffs` tick |
| `HEAL_OVER_TIME` | 持续治疗 | `process_buffs` tick |
| `MARK` | 标记 | 受伤 +% |

## 卡牌数据 — `Cards/CardDatabase.gd`

详细卡牌列表见 `_register_cards()`。`_create_card()` 参数顺序：

`id, name, type, cost, target_type, desc, effect_type, effect_value, duration=1, radius=0, secondary_value=0, extra_value=0, secondary_duration=0`

- `effect_value`：主数值（伤害/治疗/抽牌数等）
- `secondary_value`：副数值（直伤卡 siphon=6/overload=5/frostbite=12/poison_blade=4 的直伤、fireball 灼烧值=5、chain 1 格溅射=10）
- `extra_value`：第三数值（overload 回能=2、chain 2 格溅射=5）
- `secondary_duration`：副数值持续时间（fireball 灼烧=2）

> 执行器（`CardEffect.gd`）与 AI 评分（`Strategist._card_base_damage`）统一从卡牌数据读取，禁止在逻辑中硬编码卡牌数值。
