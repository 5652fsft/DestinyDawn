# 创建新卡牌 — 完整流程

## 涉及的文件一览

| 步骤 | 文件 | 操作 |
|---|---|---|
| A | `Cards/CardDatabase.gd` | 注册卡牌（_create_card 调用） |
| B | `Cards/CardEffect.gd` | 实现效果逻辑（如需新效果类型） |
| C | `Scenes/main.gd` | 实现目标选择逻辑（如需新目标类型） |
| D | `Cards/CardData.gd` | 添加枚举值（如需新效果/目标/类型） |
| E | `Menus/DeckBuilder.gd` | 更新 TYPE_NAMES（如需新卡牌类型） |

---

## A) 注册卡牌 — `Cards/CardDatabase.gd`

在 `_register_cards()` 函数末尾（在 `for` 循环之前）添加一行：

```gdscript
_create_card(
	"card_new_id",                # id: 全局唯一标识符
	"显示名称",                    # name: 卡牌名称
	CardData.CardType.ATTACK,     # type: 卡牌类型
	2,                            # cost: 能量消耗
	CardData.TargetType.ENEMY_SINGLE, # target_type: 目标类型
	"描述文本",                    # desc: 卡牌描述
	CardData.EffectType.DAMAGE,   # effect_type: 效果类型
	25,                           # effect_value: 效果数值
	1,                            # effect_duration: 持续回合数（默认1）
	0,                            # effect_radius: 范围半径（默认0，AOE_DAMAGE/AOE_HEAL 已改为全阵营生效，忽略此参数）
)
```

### 参数详解

| 参数 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | 以 `card_` 开头，全局唯一。e.g. `"card_fireball"` |
| `name` | `String` | 中文显示名，用于卡牌 UI |
| `type` | `CardType` | ATTACK(0), HEAL(1), BUFF(2), DEBUFF(3), DISPLACE(4), SHIELD(5), TACTICAL(6) |
| `cost` | `int` | 使用消耗的能量，范围 0~10 |
| `target_type` | `TargetType` | 见下方"目标类型" |
| `desc` | `String` | 卡牌描述文本 |
| `effect_type` | `EffectType` | 见下方"效果类型" |
| `effect_value` | `int` | 伤害量/治疗量/Buff 数值/抽牌数等 |
| `effect_duration` | `int` | 持续回合（Buff/DoT/HoT 等） |
| `effect_radius` | `int` | AOE 半径（格数） |

### 目标类型 (TargetType)

| 值 | 常量 | 说明 |
|---|---|---|
| 0 | `NONE` | 无目标（如抽牌） |
| 1 | `SELF` | 自己 |
| 2 | `ALLY_SINGLE` | 单个友方 |
| 3 | `ENEMY_SINGLE` | 单个敌方 |
| 4 | `ALLY_ALL` | 所有友方 |
| 5 | `ENEMY_ALL` | 所有敌方 |
| 6 | `CELL` | 地面格子 |
| 7 | `ALL_CHARACTERS` | 所有角色 |

---

## B) 效果类型与实现 — `Cards/CardEffect.gd`

### 已有效果类型（无需额外编码）

| EffectType | 效果 | 参数含义 |
|---|---|---|
| `DAMAGE` | 对单目标造成伤害 | value=伤害量 |
| `HEAL` | 治疗单目标 | value=治疗量 |
| `SHIELD` | 获得护盾 | value=护盾量 |
| `BUFF_ATTACK` | 攻击力 Buff | value=数值, duration=回合 |
| `BUFF_DEFENSE` | 防御 Buff | value=数值, duration=回合 |
| `DEBUFF_ATTACK` | 攻击力 Debuff | value=数值, duration=回合 |
| `DEBUFF_MOVE` | 移动力 Debuff | value=数值, duration=回合 |
| `EXTRA_MOVE` | 额外移动力 | value=数值, duration=回合 |
| `DRAW_CARD` | 抽牌 | value=抽牌数 |
| `CLEANSE` | 移除减益 | — |
| `AOE_DAMAGE` | 范围伤害 | value=伤害量, radius=范围 |
| `AOE_HEAL` | 范围治疗 | value=治疗量, radius=范围 |
| `CHAIN_DAMAGE` | 连锁伤害（3跳） | value=初始伤害 |
| `DAMAGE_OVER_TIME` | 持续伤害 | value=每回合伤害, duration=回合 |
| `HEAL_OVER_TIME` | 持续治疗 | value=每回合治疗, duration=回合 |
| `MARK` | 标记（受伤加深） | value=百分比, duration=回合 |
| `TAUNT` | 嘲讽 | duration=回合 |
| `TELEPORT` | 传送至目标旁 | value=额外伤害 |
| `SWAP` | 交换位置 | — |
| `LINEAR_AOE` | 线性范围伤害 | value=伤害量 |

### 添加新效果类型

如果需要全新的效果类型：

1. 在 `Cards/CardData.gd` 的 `enum EffectType` 中添加值
2. 在 `CardEffect.execute()` 的 `match` 中添加分支
3. 实现对应的 `static func _execute_*()` 函数

```gdscript
# CardData.gd
enum EffectType {
	...
	MY_NEW_EFFECT,
}

# CardEffect.gd — execute() 的 match 中添加
CardData.EffectType.MY_NEW_EFFECT:
	_execute_my_new_effect(card, target, main)

# CardEffect.gd — 实现
static func _execute_my_new_effect(card: CardData, target: Node, main: Node):
	# 实现逻辑
	pass
```

> `caster` 参数已废弃，所有卡牌由玩家直接释放到目标，新增效果函数无需 `caster` 参数。

---

## C) 添加新卡牌类型 — `Cards/CardData.gd` + `Menus/DeckBuilder.gd`

1. 在 `CardData.gd` 的 `enum CardType` 中添加值
2. 在 `DeckBuilder.gd` 的 `TYPE_NAMES` 字典中添加名称映射：

```gdscript
const TYPE_NAMES = {0:"攻击", 1:"治疗", 2:"增益", 3:"减益", 4:"位移", 5:"护盾", 6:"战术", 7:"新类型"}
```

---

## D) 添加新目标类型 — `Scenes/main.gd`

1. 在 `CardData.gd` 的 `enum TargetType` 中添加值
2. 在 `main.gd` 的 `_is_valid_target()` 中添加处理逻辑
3. 在 `main.gd` 的 `highlight_targets()` 中添加高亮逻辑

---

## 完整示例：创建新卡牌的检查清单

- [ ] `CardDatabase.gd`: 添加 `_create_card()` 调用
- [ ] （如需要） `CardData.gd`: 添加 EffectType / TargetType / CardType 枚举值
- [ ] （如需要） `CardEffect.gd`: 添加 match 分支 + 实现函数
- [ ] （如需要） `main.gd`: 目标选择/高亮逻辑
- [ ] （如需要） `DeckBuilder.gd`: 更新 TYPE_NAMES
