# 创建新卡牌 — 流程

| 步骤 | 文件 | 操作 |
|------|------|------|
| A | `Cards/CardDatabase.gd` | `_register_cards()` 添加 `_create_card()` 调用 |
| B | `Cards/CardEffect.gd` | 实现效果逻辑（如需新效果类型） |
| C | `Scenes/main.gd` | 目标选择/高亮逻辑（如需新目标类型） |
| D | `Cards/CardData.gd` | 添加枚举值（如需新类型） |
| E | `Menus/DeckBuilder.gd` | 更新 `TYPE_NAMES`（如需新卡牌类型） |

---

## A) 注册卡牌 — `CardDatabase.gd`

```gdscript
_create_card(
	"card_new_id",                       # 全局唯一标识
	"显示名称",                           # 中文名
	CardData.CardType.ATTACK,            # 类型枚举
	2,                                   # 能量消耗
	CardData.TargetType.ENEMY_SINGLE,    # 目标类型
	"描述文本",                           # 显示描述
	CardData.EffectType.DAMAGE,          # 效果类型
	25,                                  # 效果数值
	1,                                   # 持续回合（默认 1）
)
```

**关键规则**：
- 卡牌由**玩家直接释放到目标**，无 caster 概念。所有效果函数签名为 `static func _execute_xxx(card, target, main)`，不使用 `main.selected_character`
- 阵营判断通过 `main.current_card_player_id`，不使用 `GlobalGameData.is_host`
- AOE 效果（`AOE_DAMAGE` / `AOE_HEAL`）使用 `TargetType.NONE`，自动根据 `current_card_player_id` 选择阵营

## B) 效果类型 — `CardEffect.gd`

| EffectType | 参数 | 说明 |
|---|---|---|
| DAMAGE | value=伤害 | 单体伤害 |
| HEAL | value=治疗 | 单体治疗 |
| SHIELD | value=护盾 | 单体护盾 |
| BUFF_ATTACK / BUFF_DEFENSE | value=数值, duration=回合 | 增益 |
| DEBUFF_ATTACK / DEBUFF_MOVE | value=数值, duration=回合 | 减益 |
| DRAW_CARD | value=抽牌数 | 抽牌 |
| CLEANSE | — | 移除减益 |
| AOE_DAMAGE / AOE_HEAL | value=数值 | 全阵营范围效果 |
| CHAIN_DAMAGE | value=初始伤害 | 连锁 3 跳 |
| DAMAGE_OVER_TIME / HEAL_OVER_TIME | value=每回合, duration=回合 | 持续效果 |
| MARK | value=百分比, duration=回合 | 受伤加深 |
| TAUNT | duration=回合 | 嘲讽 |
| TELEPORT / SWAP / LINEAR_AOE | — | 位移（均已移除 caster 依赖） |

## C) 添加新效果类型

1. `CardData.gd` 的 `enum EffectType` 添加值
2. `CardEffect.execute()` 的 `match` 添加分支
3. 实现 `static func _execute_xxx(card, target, main)` — 参数无 caster

## 描述格式规范

- 介词：恢复→**为**，造成/施加→**对**
- 空格：汉字与数字/英文间加空格，中文标点后不加
- `[技能名称]`视为英文，前方汉字后加空格
- 后缀效果用 `，效果为`，避用冒号
- 术语：用"移动范围"非"移动力"，"造成伤害"/"恢复生命值"非"治疗"，"持续 X 回合"
