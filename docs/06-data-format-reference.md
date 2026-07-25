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

### 内置角色数据

| ID | name | HP | Move | ATK | Range | Skill | CD | Target | Passive |
|---|---|---|---|---|---|---|---|---|---|
| bronya | 布洛妮娅 | 68 | 5 | 15 | 1 | 护卫指令 | 3 | ALLY_SINGLE | 铁壁 |
| seele | 希儿 | 65 | 6 | 18 | 1 | 相位突进 | 3 | ENEMY_SINGLE | 暗影突袭 |
| elaina | 伊蕾娜 | 60 | 5 | 20 | 3 | 星尘爆裂 | 4 | ENEMY_SINGLE | 魔力共鸣 |
| firefly | 流萤 | 85 | 5 | 14 | 1 | 烈焰冲锋 | 3 | ENEMY_SINGLE | 燃烧装甲 |
| silverwolf | 银狼 | 65 | 5 | 16 | 2 | 系统入侵 | 4 | ENEMY_SINGLE | 数据篡改 |
| hamster | 芝士仓鼠 | 48 | 6 | 24 | 3 | 动作如潮 | 3 | SELF | 钢铁直架 |
| karrigan | karrigan | 65 | 9 | 10 | 6 | 狂野·纵横烟中 | 3 | CELL | 倒霉·混烟致残 |
| zephyr | Zephyr | 85 | 5 | 8 | 3 | 引煞赴烬 | 0 | SELF | 血煞逆锋 |
| anpan | あんパン | 65 | 5 | 13 | 3 | 极速高温烘焙 | 3 | SELF | 面包大家族 |
| M1DorG | M1DorG | 72 | 6 | 11 | 1 | 我玩蔚蓝去了 | 4 | SELF | Intel工程师 |
| Richardovo | Richardovo | 70 | 7 | 14 | 1 | 突破 | 2 | SELF | 闭麦 |

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
