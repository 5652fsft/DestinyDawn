# 创建新角色 — 完整流程

## 涉及的文件一览

| 步骤 | 文件 | 操作 |
|---|---|---|
| A | `Global/CharacterData.gd` | 添加数据字典条目 |
| B | `Characters/NewChar/NewChar.gd` | 新建角色脚本 |
| C | `Characters/NewChar/NewChar.tscn` | 新建角色场景 |
| D | `Assets/Sprites/Characters/` | 添加阵营贴图 |
| D | `Assets/Sprites/Standee/` | 添加立绘 |
| E | `Scenes/main.gd` | 注册 PackedScene + 编队 map |
| F | `Skills/SkillEffect.gd` | 实现技能逻辑 |

---

## A) 角色数据 — `Global/CharacterData.gd`

在 `DATA` 字典中添加条目：

```gdscript
"newchar": {
    "name":"角色名",           # 中文显示名
    "hp":80,                   # 基础生命值
    "move":5,                  # 移动力（格数）
    "atk":16,                  # 基础攻击力
    "range":2,                 # 攻击射程（格数）
    "skill":"技能名",          # 主动技能名称
    "skill_desc":"技能描述",   # 主动技能描述文本
    "skill_cd":3,              # 主动技能冷却（回合）
    "passive":"被动名",        # 被动技能名称
    "passive_desc":"被动描述"   # 被动技能描述文本
}
```

> 此字典是编队界面、角色卡牌、结算等所有 UI 中角色信息的**唯一数据源**。

---

## B) 角色脚本 — `Characters/NewChar/NewChar.gd`

```gdscript
extends "res://Characters/BaseCharacter.gd"

var active_skill: BaseSkill
var passive_skill: BaseSkill

func _ready():
    # 1. 设置角色属性（在 super() 之前）
    max_hp = 80
    hp = 80
    attack = 16
    attack_range = 2
    move_points = 5
    affinity = {
        attack_bonus = 0.0,    # 攻击卡加成 (0.15 = +15%)
        heal_bonus = 0.0,      # 治疗卡加成
        shield_bonus = 0.0,    # 护盾卡加成
        debuff_bonus = 0.0,    # 减益卡加成
    }

    # 2. 调用父类 _ready（必须放在属性设置之后）
    super()

    # 3. 设置显示名（必须放在 super() 之后）
    character_name = "角色名"

    # 4. 创建被动技能
    passive_skill = BaseSkill.new()
    passive_skill.skill_name = "被动名"
    passive_skill.description = "被动描述"
    passive_skill.is_passive = true

    # 5. 创建主动技能
    active_skill = BaseSkill.new()
    active_skill.skill_name = "技能名"
    active_skill.description = "技能描述"
    active_skill.cooldown = 3
    active_skill.target_type = BaseSkill.SkillTarget.ENEMY_SINGLE
    # 可选: ALLY_SINGLE / SELF / NONE
    active_skill.is_passive = false

# 主动技能执行入口（必须实现）
func use_active_skill(target: Node) -> bool:
    return SkillEffect.execute_active(self, active_skill, target, main)

# 被动 — 受击减伤（如果被动影响受伤）
@rpc("any_peer", "call_local", "reliable")
func take_damage(damage: int):
    var modified = SkillEffect.get_passive_modifier(self, "incoming_damage", damage)
    super(modified)

# 被动 — 攻击增强（如果被动影响输出）
@rpc("any_peer", "call_local", "reliable")
func perform_attack(target_path: NodePath):
    super(target_path)
    # 额外逻辑（如 SilverWolf 的 50% 附加减益）
```

### 角色属性设置顺序（重要）

```
max_hp → hp → attack → attack_range → move_points → affinity → super() → character_name
```

> `_ready()` 中 `super()` 之前设置 `max_hp` 和 `hp`，`super()` 之后设置 `character_name`，因为 `_register_character()` 依赖 `character_name`。

---

## C) 角色场景 — `Characters/NewChar/NewChar.tscn`

使用文本编辑器或 Godot 创建，节点树如下：

```
CharacterBody2D (NewChar.gd)
├ CollisionShape2D
│  └ shape: CircleShape2D (radius=59)
├ Sprite2D
│  └ texture: (占位，运行时通过 _update_sprite_texture 加载)
├ MultiplayerSynchronizer
│  └ replication: .:position
├ FloatingBar (instance from Characters/FloatingBar.tscn)
```

### 场景文件关键设置

```gdscript
# NewChar.tscn (gd_scene format=3)
[node name="NewChar" type="CharacterBody2D"]
input_pickable = true     # 允许鼠标点击拾取
script = ExtResource("...NewChar.gd")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
visible = false            # 隐藏碰撞体
shape = SubResource("CircleShape2D_xxxxx")

[node name="Sprite2D" type="Sprite2D" parent="."]

[node name="MultiplayerSynchronizer" type="MultiplayerSynchronizer" parent="."]
replication_interval = 0.0
[ sync ]
.:position = 2            # 复制 position

[node name="FloatingBar" parent="." instance=ExtResource("...FloatingBar.tscn")]
```

---

## D) 素材准备

```
Assets/Sprites/Characters/
├ newchar_Blue.png          # 蓝方阵营（Host 用）
└ newchar_Red.png           # 红方阵营（Client 用）

Assets/Sprites/Standee/
└ newchar_Standee.png       # 编队立绘 (240×144)
```

> 贴图通过 `_update_sprite_texture()` 动态加载：`char_id + "_Blue.png"` 或 `"_Red.png"`。

---

## E) 注册到战斗系统 — `Scenes/main.gd`

### 1. 添加 PackedScene 常量（文件顶部）

```gdscript
const CHARACTER_NEWCHAR = preload("res://Characters/NewChar/NewChar.tscn")
```

### 2. 注册到编队映射表（`_build_team_from_selection` 中）

```gdscript
var map = {
    "bronya": CHARACTER_BRONYA,
    "seele": CHARACTER_SEELE,
    "elaina": CHARACTER_ELAINA,
    "firefly": CHARACTER_FIREFLY,
    "silverwolf": CHARACTER_SILVERWOLF,
    "newchar": CHARACTER_NEWCHAR,  # ← 添加
}
```

### 3. （可选）调整出生点数量

如果队伍上限超过 3 人，需扩展 `GlobalGameData.host_birth_point` 和 `client_birth_point` 数组。

---

## F) 技能逻辑 — `Skills/SkillEffect.gd`

### 主动技能

在 `execute_active()` 的 `match character.character_name` 中添加分支：

```gdscript
"角色名":  # 对应 character_name
    _newchar_active(character, target)
    return true
```

实现函数：

```gdscript
static func _newchar_active(character: Node, target: Node):
    # 示例：造成伤害
    target.rpc("take_damage", 25)
    # 示例：施加 Buff
    var bm = character.main.buff_manager
    bm.apply_buff(target, "attack_buff", 10, 2)
    # 示例：播放 VFX
    target.rpc("_play_vfx_preset", "explosion")
```

### 被动技能

方式一（推荐）：在角色脚本中直接覆写 `take_damage` 或 `perform_attack`（参考 Firefly / SilverWolf）。

方式二：注册到 `get_passive_modifier()` 系统（参考 Bronya / Seele）：

```gdscript
"角色名":
    match modifier_key:
        "incoming_damage":
            return int(base_value * 0.8)  # -20%
        "outgoing_damage":
            return int(base_value * 1.2)  # +20%
```

---

## 完整示例：创建新角色的检查清单

- [ ] `CharacterData.gd`: DATA 条目
- [ ] `NewChar.gd`: 脚本（extends BaseCharacter, _ready, use_active_skill）
- [ ] `NewChar.tscn`: 场景（节点结构正确）
- [ ] `Assets/Sprites/Characters/newchar_Blue.png`
- [ ] `Assets/Sprites/Characters/newchar_Red.png`
- [ ] `Assets/Sprites/Standee/newchar_Standee.png`
- [ ] `main.gd`: 添加 `const CHARACTER_NEWCHAR` + map 条目
- [ ] `SkillEffect.gd`: execute_active 分支 / get_passive_modifier 分支
