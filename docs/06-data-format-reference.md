# 数据格式速查

## 角色数据 — `Global/CharacterData.gd`

```gdscript
"<id>": {
	"name":"<中文名>", "hp":<int>, "move":<int>, "atk":<int>, "range":<int>,
	"skill":"<技能名>", "skill_desc":"<描述>", "skill_cd":<int>,
	"skill_energy":<int>,          # 技能能量消耗（可选，默认 0）
	"passive":"<被动名>", "passive_desc":"<描述>"
}
```

### 角色一览

| ID | name | HP | Move | ATK | Range | Skill | SkillCD | Target | Passive |
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

## 卡牌数据 — `Cards/CardDatabase.gd`

```gdscript
_create_card("id", "name", CardType, cost, TargetType, "desc", EffectType, value, duration=1, radius=0)
```

完整卡牌表见 `Cards/CardDatabase.gd` 的 `_register_cards()`。

## Buff 数据 — `Global/BuffDatabase.gd`

```gdscript
"buff_id": { "name":"显示名", "type":BuffType, "is_harmful":bool }
```

### Buff 类型

| BuffType | 说明 | 效果 |
|----------|------|------|
| ATTACK_BUFF | 攻击增益/减益 | `effective_attack` 计算 |
| DEFENSE_BUFF | 防御增益/减益 | `take_damage` 中减免 |
| MARK | 标记 | 受伤 +% |
| MOVE_BUFF | 移动增益/减益 | `effective_move_points` 计算 |
| REGEN | 持续治疗 | `process_buffs` 每回合 tick |
| POISON | 持续伤害 | `process_buffs` 每回合 tick |
| SHIELD_OVERLOAD | 护盾过载 | shield 翻倍 |
| BLOODTHIRST | 嗜血 | 攻击 +% |
| MAGIC_FLOW | 魔力充盈 | 攻击 +% |
| SOFTEN | 松软 | 受伤 +% |
| ASCEND | 攀升 | 受伤 -% |
| EXTRA_MOVE | 额外移动 | 移动 +格 |
| TAUNT | 嘲讽 | 强制攻击目标 |
