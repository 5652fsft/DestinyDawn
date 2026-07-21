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

### 内置角色数据（此处仅为举例，不是最新版数据！）

| ID | name | HP | Move | ATK | Range | Skill | Skill Range | Passive |
|---|---|---|---|---|---|---|---|---|
| bronya | 布洛妮娅 | 68 | 5 | 15 | 1 | 护卫指令 | 0 | 铁壁 |
| seele | 希儿 | 65 | 6 | 18 | 1 | 相位突进 | 10 | 暗影突袭 |
| elaina | 伊蕾娜 | 60 | 5 | 20 | 3 | 星尘爆裂 | 6 | 魔力共鸣 |
| firefly | 流萤 | 85 | 5 | 14 | 1 | 烈焰冲锋 | 6 | 燃烧装甲 |
| silverwolf | 银狼 | 65 | 5 | 16 | 2 | 系统入侵 | 0 | 数据篡改 |
| hamster | 芝士仓鼠 | 48 | 6 | 26 | 4 | 动作如潮 | 0 | 钢铁直架 |

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
| defense_buff | 伤害减免 | DEFENSE_BUFF | PHYSICAL | 2 | 否 |
| move_debuff | 迟缓 | MOVE_DEBUFF | MAGIC | 2 | 否 |
| poison | 中毒 | DAMAGE_OVER_TIME | PHYSICAL | 5 | 是 |
| burn | 灼烧 | DAMAGE_OVER_TIME | MAGIC | 3 | 是 |
| regen | 再生 | HEAL_OVER_TIME | MAGIC | 3 | 是 |
| mark | 标记 | MARK | SPECIAL | 1 | 否 |
| bloodthirst | 嗜血成性 | ATTACK_BUFF | SPECIAL | 3 | 否 |
| magic_flow | 魔力充盈 | ATTACK_BUFF | SPECIAL | 3 | 否 |

Buff 条目结构：

```gdscript
{
	"value": int,         # 数值
	"remaining": int,     # 剩余回合
	"source_path": NodePath,  # 来源角色
}
```

---

## 卡牌数值参考

### 费用-强度映射

| 费用 | 预期总价值 | 说明 |
|---|---|---|
| 0 | 20-30 效果值 | 带代价的高收益 |
| 1 | 20-35 效果值 | 单体低费卡 |
| 2 | 30-50 效果值 | 单体中费卡 |
| 3 | 45-70 效果值 | 高费复合/AOE 卡 |

### 全卡牌数值

| ID | 费用 | 效果 | 定位 |
|---|---|---|---|
| `overload` | 0 | +2能量，自伤5 | 能量加速 |
| `ice_shard` | 1 | 8伤害+迟缓1回合 | 伤害+控制 |
| `siphon` | 1 | 6伤害+抽1 | 伤害+发育 |
| `poison_blade` | 1 | 4伤害+中毒6×3回合 | DOT 消耗 |
| `reckoning` | 1 | 6×buff数伤害 | 针对 buff 手 |
| `small_heal` | 1 | 10治疗 | 廉价治疗 |
| `life_split` | 1 | 12治疗+满血抽1 | 条件收益 |
| `regen` | 1 | HOT 5×3回合 | 持续恢复 |
| `shield_overload` | 1 | 8护盾/翻倍 | 条件护盾 |
| `strength` | 1 | ATK+8,2回合 | 攻击 buff |
| `fortify` | 1 | DEF+8,2回合 | 防御 buff |
| `haste` | 1 | MOVE+3,2回合 | 机动 buff |
| `double_edge` | 1 | ATK+10, DEF-5,2回合自 | 风险收益 |
| `weakness` | 1 | ATK-6,2回合 | 攻击 debuff |
| `slow` | 1 | MOVE-2,1回合 | 机动 debuff |
| `mark` | 1 | +50%受伤,2回合 | 伤害加深 |
| `hemorrhage` | 1 | DOT 7×3回合 | 纯消耗 |
| `draw` | 1 | 抽1 | 过牌 |
| `cleanse` | 1 | 移除减益 | 解 debuff |
| `taunt` | 1 | 赋予我方角色嘲讽 | 嘲讽控制 |
| `fireball` | 2 | 20伤害+灼烧5×2回合 | 持续伤害 |
| `aim` | 2 | 28伤害 | 爆发 |
| `frostbite` | 2 | 12伤害+迟缓2回合 | 伤害+长控制 |
| `shadowstep` | 2 | 传送+12伤害 | 机动+伤害 |
| `heal` | 2 | 20治疗 | 单体治疗 |
| `heal_wave` | 2 | AOE 10治疗 | 群体治疗 |
| `shield` | 2 | 16护盾 | 保护 |
| `ice_shield` | 2 | 18护盾 | 强护盾 |
| `iron_wall` | 2 | DEF+12,3回合自 | 自坦克 |
| `disarm` | 2 | ATK-8,3回合 | 长 debuff |
| `echo` | 2 | 抽2 | 大量过牌 |
| `firestorm` | 3 | 范围1内24伤害 | 集中 AOE |
| `arrow_rain` | 3 | 范围2内16伤害 | 大范围 AOE |
| `chain_lightning` | 3 | 20+链式 | 链式伤害 |
| `mass_heal` | 3 | AOE 14治疗 | 群奶 |

新增卡牌时数值必须符合费用-强度映射，同费用卡牌必须有不同定位。

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
@export var skill_range: int = 0      # 0 = 无限制，>0 = 最大 hex 格数
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

---

## 卡牌强度设计原则

> 新增或调整卡牌时，必须遵守以下原则。

### 前置说明：卡牌直接由玩家释放

卡牌系统中**不存在「施法者」概念**。所有卡牌由玩家从手牌中直接释放，
效果目标是场上选择的角色（或区域）。`Cards/CardEffect.gd` 中各函数的 `caster` 参数
已废弃（始终为当前选中的角色或队伍中第一个存活角色），新增卡牌效果时无需关心。

同理 `_affinity_multiplier()` 因亲和力系统已废弃，始终返回 `1.0`。

### 原则一：强度与费用正相关

| 费用 | 预期总价值 | 说明 |
|---|---|---|
| 0 | 20-30 效果值 | 带代价的高收益（如过载：2能量-自伤5） |
| 1 | 20-35 效果值 | 单体低费卡基准 |
| 2 | 30-50 效果值 | 单体中费卡基准 |
| 3 | 45-70 效果值 | 高费复合/AOE 卡基准 |

### 原则二：同费用卡牌必须有不同定位

同一费用的卡牌不能只是数值不同，必须有**使用场景上的区分**。

| 费用 | 冲突 | 解法 |
|---|---|---|
| 2 | 火球术 vs 瞄准射击都是纯伤害 | 火球术改为 20伤害+灼烧2回合（持续伤害）；瞄准保持 28 纯伤害（爆发） |
| 1 | 冰晶碎片 vs 其他攻击卡 | 冰晶碎片改为 8伤害+迟缓1回合（控制）；法力汲取 6伤害+抽牌（发育）；毒刃 4伤害+DOT（消耗） |

### 原则三：价值计算规则

- **伤害/治疗**：1 点 = 1 效果值
- **护盾**：1 点 = 1 效果值
- **Buff/Debuff**：持续 2 回合的 buff，总价值 = 数值 × 回合数 × 0.6
- **抽牌**：1 张牌 ≈ 12 效果值
- **AOE**：每个额外目标按 0.5 倍计算
- **位移（传送）**：额外 +8 效果值
- **自伤代价**：1 点自伤 ≈ -3 效果值
- **灼烧/中毒（DOT）**：每回合价值 × 0.7（延迟收益折扣）
```

---

## 音频系统 — `Global/AudioManager.gd`

### BGM（背景音乐）

| 文件名 | 说明 |
|---|---|
| `battle1.mp3` ~ `battle6.mp3` | 战斗 BGM 曲库，共 6 首 |
| 播放方式 | 进入战斗时随机打乱顺序播放，每首播完自动接下一首，曲库循环 |

### SFX（音效）

| 文件名 | 映射用途 | 说明 |
|---|---|---|
| `click.ogg` | **UI 交互** | 按钮点击、菜单翻页、移动/攻击按钮点击等所有界面交互音效 |
| `card_play.ogg` | **卡牌** | 打出卡牌时播放 |
| `deck_select.ogg` | **卡牌** | 卡组选择时播放 |
| `move.ogg` | **角色** | 角色在棋盘上移动时播放 |
| `attack.ogg` | **角色** | 角色普通攻击时播放 |
| `heal.ogg` | **角色** | 角色受到治疗时播放 |
| `shield.ogg` | **角色** | 护盾生成时播放 |
| `death.ogg` | **角色** | 角色阵亡时播放 |
| `attack_sword.ogg` | **技能** | 布洛妮娅·护卫指令、希儿·相位突进、流萤·烈焰冲锋使用 |
| `attack_digital.ogg` | **技能** | 银狼·系统入侵使用 |
| `attack_magic.ogg` | **技能** | 伊蕾娜·星尘爆裂使用 |
| `attack_gun.ogg` | **技能** | 芝士仓鼠·动作如潮使用 |
| `turn_start.ogg` | **战局** | 回合开始时播放 |
| `victory.ogg` | **战局** | 胜利时播放 |
| `defeat.ogg` | **战局** | 败北时播放 |

### 技能音效映射（`Skills/SkillEffect.gd`）

| 角色 | 技能名 | 音效文件 |
|---|---|---|
| 布洛妮娅 | 护卫指令 | `attack_sword.ogg` |
| 希儿 | 相位突进 | `attack_sword.ogg` |
| 伊蕾娜 | 星尘爆裂 | `attack_magic.ogg` |
| 流萤 | 烈焰冲锋 | `attack_sword.ogg` |
| 银狼 | 系统入侵 | `attack_digital.ogg` |
| 芝士仓鼠 | 动作如潮 | `attack_gun.ogg` |

### 卡牌效果音效（`Cards/CardEffect.gd`）

卡牌效果音效直接在 `CardEffect.gd` 各函数中通过 `play_sfx()` 指定，当前使用 `heal`、`shield`、`skill` 等通用音效，可根据需要替换或新增。
