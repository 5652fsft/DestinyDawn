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
	},
}
```

> `skill_energy` 为可选字段，定义主动技能消耗的能量值。`SkillEffect.gd` 中通过 `CharacterData.get_data(id).get("skill_energy", 0)` 动态读取。

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

详细卡牌列表见 `_register_cards()`。
