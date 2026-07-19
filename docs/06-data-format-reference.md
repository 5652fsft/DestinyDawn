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
        "passive":     "<被动名>",   # 被动技能名称
        "passive_desc":"<被动描述>", # 被动技能描述文本
    },
}
```

### 内置角色数据

| ID | name | HP | Move | ATK | Range | Skill | Passive |
|---|---|---|---|---|---|---|---|
| bronya | 布洛妮娅 | 80 | 5 | 15 | 1 | 护卫指令 | 铁壁 |
| seele | 希儿 | 65 | 6 | 18 | 1 | 相位突进 | 暗影突袭 |
| elaina | 伊蕾娜 | 60 | 5 | 20 | 3 | 星尘爆裂 | 魔力共鸣 |
| firefly | 流萤 | 90 | 5 | 14 | 1 | 烈焰冲锋 | 燃烧装甲 |
| silverwolf | 银狼 | 65 | 5 | 16 | 2 | 系统入侵 | 数据篡改 |

---

## 卡牌数据 — `Cards/CardDatabase.gd`

### 注册参数

```gdscript
_create_card(
    id: String,                    # "card_xxx"
    name: String,                  # 中文显示名
    type: CardType,                # ATTACK(0) / HEAL(1) / BUFF(2) / DEBUFF(3) / DISPLACE(4) / SHIELD(5) / TACTICAL(6)
    cost: int,                     # 能量消耗 (0~10)
    target_type: TargetType,       # 见下方
    desc: String,                  # 卡牌描述
    effect_type: EffectType,       # 见下方
    effect_value: int,             # 主要数值
    effect_duration: int = 1,      # 持续回合 (Buff/DoT/HoT)
    effect_radius: int = 0,        # AOE 半径 (格数)
)
```

### 效果类型枚举 (`CardData.EffectType`)

| 值 | 常量 | 说明 |
|---|---|---|
| 0 | DAMAGE | 单体伤害 |
| 1 | HEAL | 单体治疗 |
| 2 | BUFF_ATTACK | 攻击力增益 |
| 3 | BUFF_DEFENSE | 防御增益 |
| 4 | DEBUFF_ATTACK | 攻击力减益 |
| 5 | DEBUFF_MOVE | 移动力减益 |
| 6 | SHIELD | 护盾 |
| 7 | TELEPORT | 传送 |
| 8 | SWAP | 交换位置 |
| 9 | EXTRA_MOVE | 额外移动力 |
| 10 | DRAW_CARD | 抽牌 |
| 11 | CLEANSE | 净化 |
| 12 | AOE_DAMAGE | 范围伤害 |
| 13 | AOE_HEAL | 范围治疗 |
| 14 | CHAIN_DAMAGE | 连锁伤害 |
| 15 | DAMAGE_OVER_TIME | 持续伤害 |
| 16 | HEAL_OVER_TIME | 持续治疗 |
| 17 | LINEAR_AOE | 线性范围伤害 |
| 18 | MARK | 标记 |
| 19 | TAUNT | 嘲讽 |

### 目标类型枚举 (`CardData.TargetType`)

| 值 | 常量 | 说明 |
|---|---|---|
| 0 | NONE | 无目标 |
| 1 | SELF | 自己 |
| 2 | ALLY_SINGLE | 单体友方 |
| 3 | ENEMY_SINGLE | 单体敌方 |
| 4 | ALLY_ALL | 全体友方 |
| 5 | ENEMY_ALL | 全体敌方 |
| 6 | CELL | 地面格子 |
| 7 | ALL_CHARACTERS | 全体角色 |

### 卡牌类型枚举 (`CardData.CardType`)

| 值 | 常量 | DeckBuilder 显示名 |
|---|---|---|
| 0 | ATTACK | 攻击 |
| 1 | HEAL | 治疗 |
| 2 | BUFF | 增益 |
| 3 | DEBUFF | 减益 |
| 4 | DISPLACE | 位移 |
| 5 | SHIELD | 护盾 |
| 6 | TACTICAL | 战术 |

---

## Buff 数据 — `Global/BuffDatabase.gd`

| Buff ID | 显示名 | 类型 | 分类 | 最大层数 | 每回合触发 |
|---|---|---|---|---|---|
| attack_buff | 力量强化 | ATTACK_BUFF | MAGIC | 3 | 否 |
| attack_debuff | 虚弱 | ATTACK_DEBUFF | MAGIC | 3 | 否 |
| defense_buff | 铁壁 | DEFENSE_BUFF | PHYSICAL | 2 | 否 |
| move_debuff | 迟缓 | MOVE_DEBUFF | MAGIC | 2 | 否 |
| poison | 中毒 | DAMAGE_OVER_TIME | PHYSICAL | 5 | 是 |
| burn | 灼烧 | DAMAGE_OVER_TIME | MAGIC | 3 | 是 |
| regen | 再生 | HEAL_OVER_TIME | MAGIC | 3 | 是 |
| mark | 标记 | MARK | SPECIAL | 1 | 否 |

Buff 条目结构：

```gdscript
{
    "value": int,         # 数值
    "remaining": int,     # 剩余回合
    "source_path": NodePath,  # 来源角色
}
```

---

## Skill 数据 — `Skills/BaseSkill.gd`

```gdscript
class_name BaseSkill extends Resource

enum SkillTarget { NONE, SELF, ALLY_SINGLE, ENEMY_SINGLE }

@export var skill_name: String = ""
@export var description: String = ""
@export var cooldown: int = 0
var current_cooldown: int = 0      # 运行时：0 = 可用
@export var target_type: SkillTarget = SkillTarget.NONE
@export var is_passive: bool = false
```

---

## 战斗统计 — `GlobalGameData.gd`

```gdscript
var battle_stats: Dictionary = {
    host_damage_dealt: 0,       # Host 造成的总伤害
    host_healing_done: 0,       # Host 的总治疗量
    host_cards_played: 0,       # Host 使用的卡牌数
    host_kills: 0,              # Host 的击杀数
    client_damage_dealt: 0,     # Client 造成的总伤害
    client_healing_done: 0,     # Client 的总治疗量
    client_cards_played: 0,     # Client 使用的卡牌数
    client_kills: 0,            # Client 的击杀数
    turns_taken: 0,             # 总回合数
}
```

---

## 角色出生点 — `GlobalGameData.gd`

```gdscript
var host_birth_point = [
    Vector2(-252, -37),     # Host 角色 0 出生点
    Vector2(-252, 404),     # Host 角色 1 出生点
    Vector2(252, 404),      # Host 角色 2 出生点
]
var client_birth_point = [
    Vector2(756, -698),     # Client 角色 0 出生点
    Vector2(1260, -698),    # Client 角色 1 出生点
    Vector2(1260, -257),    # Client 角色 2 出生点
]
```

---

## 角色回合追踪 — `GlobalGameData.gd`

```gdscript
var character_move_used: Dictionary = {}     # { "HostCharacter_0": true/false }
var character_move_used_num: int = 0         # 已使用的移动次数（限制每回合）
var character_attack_used: Dictionary = {}   # { "HostCharacter_0": true/false }
var character_attack_used_num: int = 0       # 已使用的攻击次数
```
