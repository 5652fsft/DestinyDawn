# 单机人机对战 — 实现规划文档

> 分支：`feature/ai-mode`
> 创建日期：2026-07-19
> 状态：规划中

---

## 1. 概述

### 1.1 目标

在原有 LAN 局域网联机模式基础上，新增**单机人机对战**模式：
- 玩家在本地与 AI 对手进行 3v3 回合制对战
- AI 使用 6 名角色中随机选取的 3 名，从 30 张卡牌中随机选取 8 张构成卡组
- AI 难度固定为"普通"（始终选择评估最优的行动）
- 绝对不能影响原有 LAN 联机模式的正常游玩体验

### 1.2 核心原则

| 原则 | 说明 |
|---|---|
| **零侵入** | 现有 LAN 联机路径不做任何逻辑修改 |
| **模式隔离** | 所有 AI 相关逻辑通过 `GlobalGameData.is_ai_mode` 标志分支 |
| **单向依赖** | AI 控制器只调用已有的公共 API，不修改底层系统 |

---

## 2. 架构设计

### 2.1 数据流

```
MainMenu（点击"单机人机"按钮）
  │
  ├── GlobalGameData.is_host = true
  ├── GlobalGameData.is_ai_mode = true
  └── 跳转 scene.tscn
        │
        main.gd _ready()
        ├── 检测 is_ai_mode
        ├── 随机生成 AI 队伍 → GlobalGameData.client_team
        ├── 随机生成 AI 卡组
        ├── 本地生成 Host 方角色（玩家控制）
        ├── 本地生成 Client 方角色（AI 控制，authority=1）
        ├── 初始化双方卡牌系统 + 能量系统
        ├── 创建 AIController 节点
        └── advance_turn_phase()
              │
              回合循环 ──────────────┐
              │                       │
              ├── PLAYER_MOVE: 玩家操作  │
              ├── PLAYER_ATTACK: 玩家操作 │
              ├── ENEMY_MOVE: AIController 控制 AI 角色移动
              ├── ENEMY_ATTACK: AIController 控制 AI 角色攻击/技能/卡牌
              └── START_ROUND → 循环 ──┘
```

### 2.2 文件清单

| 文件 | 操作 | 变更量 |
|---|---|---|
| `AI/AIController.gd` | **新建** | ~250 行 |
| `GlobalGameData.gd` | **修改** | +2 行 |
| `Menus/MainMenu.tscn` | **修改** | +1 个 Button 节点 |
| `Menus/MainMenu.gd` | **修改** | +12 行 |
| `Scenes/main.gd` | **修改** | +50 行 |
| `Characters/BaseCharacter.gd` | **修改** | +8 行 |
| `docs/08-ai-mode-plan.md` | **新建** | 本文档 |

### 2.3 新增/修改文件详情

---

## 3. 详细实现

### 3.1 `GlobalGameData.gd` — 新增标志

**位置**：在第 3 行 `var is_host` 之后。

```gdscript
var is_ai_mode: bool = false
```

> **设计理由**：所有 AI 模式判断均以此标志为唯一入口，LAN 模式下该标志始终为 false，零影响。

---

### 3.2 `Menus/MainMenu.tscn` — 新增按钮

在 `<VBoxContainer>` 中 `JoinButton` 之后、`SettingsButton` 之前插入新按钮：

```tscn
[node name="AIBattleButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
theme_override_fonts/font = ExtResource("2")
theme_override_font_sizes/font_size = 20
text = "单机人机"
```

**信号连接**：
```
[connection signal="pressed" from="VBoxContainer/AIBattleButton" to="." method="_on_ai_battle_pressed"]
```

---

### 3.3 `Menus/MainMenu.gd` — 按钮逻辑

**第 5-7 行 `_ready()` 中的按钮列表**：
```gdscript
var buttons = [$VBoxContainer/TeamButton, $VBoxContainer/DeckButton,
    $VBoxContainer/HostButton, $VBoxContainer/JoinButton,
    $VBoxContainer/AIBattleButton,  # 新增
    $VBoxContainer/SettingsButton, $VBoxContainer/QuitButton]
```

**第 17 行 `_center_button_pivots()`** 同理添加 `AIBattleButton`。

**新增响应函数**（附加在第 80 行之后）：
```gdscript
func _on_ai_battle_pressed():
    GlobalGameData.load_defaults_if_empty()
    GlobalGameData.is_host = true
    GlobalGameData.is_ai_mode = true
    get_tree().change_scene_to_file("res://Scenes/scene.tscn")
```

> **注意**：AI 的队伍和卡组不在主菜单生成，而是在 `main.gd _ready()` 中完成，保持主菜单视图与 LAN 模式一致。

---

### 3.4 `Scenes/main.gd` — AI 模式初始化

#### 3.4.1 `_ready()` 中的 AI 分支

在 `_ready()` 约第 75-87 行的现有 `if not multiplayer.has_multiplayer_peer()` 分支之后，新增 AI 分支：

```gdscript
# === AI 模式初始化 ===
if GlobalGameData.is_ai_mode:
    GlobalGameData.load_defaults_if_empty()
    _build_team_from_selection()   # 构建玩家（Host）编队
    _generate_ai_team_and_deck()   # 随机生成 AI 队伍和卡组
    _build_team_from_selection()   # 重新构建双方编队（读取 host_team / client_team）
    _init_player_card_systems_ai() # 初始化双方卡牌和能量
    # 生成 Host 方角色（玩家控制）
    for i in range(team_roster.size()):
        _spawn_character(team_roster[i].resource_path,
            "HostCharacter_%d" % i, 1, GlobalGameData.host_birth_point[i])
    # 生成 Client 方角色（AI 控制，但 authority 设为本机）
    for i in range(enemy_roster.size()):
        _spawn_character(enemy_roster[i].resource_path,
            "ClientCharacter_%d" % i, 1, GlobalGameData.client_birth_point[i])
    _setup_ai_controller()
    rpc("advance_turn_phase")
    return
```

#### 3.4.2 新增辅助函数

**`_generate_ai_team_and_deck()`**：
```gdscript
func _generate_ai_team_and_deck():
    # 随机队伍：从 6 个角色中选 3 个不重复的
    var all_chars = ["bronya", "seele", "elaina", "firefly", "silverwolf", "hamster"]
    all_chars.shuffle()
    GlobalGameData.client_team = all_chars.slice(0, 3)

    # 随机卡组：从 30 张卡中选 8 张不重复的
    var all_cards = CardDatabase.get_all_card_ids()
    all_cards.shuffle()
    GlobalGameData.ai_deck = all_cards.slice(0, 8)
```

**`_init_player_card_systems_ai()`**：
```gdscript
func _init_player_card_systems_ai():
    # 玩家使用选中的卡组
    deck_manager.init_player(1, GlobalGameData.selected_deck.duplicate())
    # AI 使用随机卡组
    deck_manager.init_player(2, GlobalGameData.ai_deck.duplicate())
    energy_system.init_players([1, 2])
```

**`_setup_ai_controller()`**：
```gdscript
func _setup_ai_controller():
    var ai = load("res://AI/AIController.gd").new()
    ai.name = "AIController"
    add_child(ai)
```

#### 3.4.3 `GlobalGameData.gd` 补充字段

需要额外添加一个字段存储 AI 的随机卡组，在 LAN 模式下用不到：
```gdscript
var ai_deck: Array[String] = []
```

---

### 3.5 `AI/AIController.gd` — AI 控制器（核心）

#### 3.5.1 整体结构

```gdscript
class_name AIController
extends Node

# 动作队列
var _action_queue: Array[Dictionary] = []
var _action_timer: float = 0.0
var _busy: bool = false
const ACTION_DELAY: float = 0.5  # 每个操作之间的延迟（让玩家看到）

# 引用快捷方式
var _main: Node2D = null
var _energy_system: Node = null
var _deck_manager: Node = null
```

#### 3.5.2 生命周期

```gdscript
func _ready():
    _main = get_tree().current_scene
    _energy_system = _main.get_node("EnergySystem")
    _deck_manager = _main.get_node("DeckManager")

func _process(delta):
    if not GlobalGameData.is_ai_mode:
        return
    if not _is_ai_phase():
        return

    # 处理当前动作
    if _busy:
        _action_timer -= delta
        if _action_timer <= 0:
            _execute_current_action()
        return

    # 没有待处理动作时，构建新队列
    if _action_queue.is_empty():
        _build_action_queue()
        if _action_queue.is_empty():
            _end_phase()
            return
        _busy = true
        _action_timer = ACTION_DELAY
```

#### 3.5.3 阶段判断

```gdscript
func _is_ai_phase() -> bool:
    var phase = GlobalGameData.current_turn_phase
    return phase == GlobalGameData.TurnPhase.ENEMY_MOVE \
        or phase == GlobalGameData.TurnPhase.ENEMY_ATTACK
```

#### 3.5.4 动作队列构建 `_build_action_queue()`

```gdscript
func _build_action_queue():
    _action_queue.clear()

    var ai_characters = GlobalGameData.client_characters
    var phase = GlobalGameData.current_turn_phase

    if phase == GlobalGameData.TurnPhase.ENEMY_MOVE:
        # 移动阶段：为每个 AI 角色计算最佳移动
        for chara in ai_characters:
            if chara.hp <= 0:
                continue
            if GlobalGameData.character_move_used.get(chara.name, false):
                continue
            var move_target = _evaluate_move_target(chara)
            if move_target != null:
                _action_queue.append({
                    "type": "move",
                    "character": chara,
                    "cell": move_target
                })

    elif phase == GlobalGameData.TurnPhase.ENEMY_ATTACK:
        # 攻击阶段：为每个 AI 角色计算行动序列
        for chara in ai_characters:
            if chara.hp <= 0:
                continue
            # 子队列：技能 → 卡牌 → 普通攻击
            if _should_use_skill(chara):
                var skill_target = _evaluate_skill_target(chara)
                if skill_target != null:
                    _action_queue.append({
                        "type": "skill",
                        "character": chara,
                        "target": skill_target
                    })
            if _should_play_card(chara):
                var card_action = _evaluate_best_card(chara)
                if card_action != null:
                    _action_queue.append(card_action)
            if not GlobalGameData.character_attack_used.get(chara.name, false):
                var attack_target = _evaluate_attack_target(chara)
                if attack_target != null:
                    _action_queue.append({
                        "type": "attack",
                        "character": chara,
                        "target": attack_target
                    })
```

#### 3.5.5 动作执行 `_execute_current_action()`

```gdscript
func _execute_current_action():
    if _action_queue.is_empty():
        _busy = false
        return

    var action = _action_queue.pop_front()
    var chara = action.character

    match action.type:
        "move":
            _execute_move(chara, action.cell)
        "attack":
            _execute_attack(chara, action.target)
        "skill":
            _execute_skill(chara, action.target)
        "card":
            _execute_card(action.card_id, action.target)

    if _action_queue.is_empty():
        _busy = false
        _end_phase()
    else:
        _busy = true
        _action_timer = ACTION_DELAY
```

#### 3.5.6 执行函数

**移动执行**：
```gdscript
func _execute_move(chara, cell: Vector2i):
    var gl = chara.grid_layer
    if not gl:
        return
    var world_pos = gl.to_global(gl.map_to_local(cell))
    chara.target_world = world_pos
    GlobalGameData.character_move_used[chara.name] = true
    GlobalGameData.character_move_used_num += 1
    _main.check_move()
```

> AI 移动不需要走 `handle_move()` 的输入检测路径，直接设置 `target_world` 即可 — 角色的 `move_toward_target()` 会在 `_process()` 中自动处理移动到目标位置。

**攻击执行**：
```gdscript
func _execute_attack(chara, target):
    chara.perform_attack(target.get_path())
    # perform_attack 内部会处理 attack_used 标记
    _main.check_attack()
```

**技能执行**：
```gdscript
func _execute_skill(chara, target):
    chara.use_active_skill(target)
    # _active_skill_post_exec 处理冷却/行动消耗
    _main._active_skill_post_exec(chara.active_skill)
```

**卡牌执行**：
```gdscript
func _execute_card(card_id: String, target):
    var target_path = target.get_path() if target else ""
    _main._execute_play_card(2, card_id, target_path)
```

#### 3.5.7 决策函数

##### 移动评估 `_evaluate_move_target(chara)`

策略：
1. 获取角色的 `effective_move_points`（考虑 buff 后的实际移动力）
2. 计算角色当前格子到每个敌方角色的六边形距离
3. 找到最近的敌方角色
4. 近战角色（attack_range == 1）：移动到距最近敌人 1 格的位置
5. 远程角色（attack_range >= 2）：移动到距最近敌人 = 角色攻击范围的位置
6. 返回目标格子（Vector2i），如无可达位置返回 null

实现思路：
```gdscript
func _evaluate_move_target(chara) -> Vector2i:
    var gl = chara.grid_layer
    var start_cell = chara.get_current_cell()
    if start_cell == Vector2i(-1, -1):
        return null

    # BFS 找到角色的所有可达格子
    var reachable = _bfs_reachable(chara, chara.effective_move_points)
    if reachable.is_empty():
        return null

    # 找到最近的敌方角色
    var nearest_enemy = _find_nearest_enemy(chara)
    if not nearest_enemy:
        return null
    var enemy_cell = nearest_enemy.get_current_cell()

    # 近战 vs 远程策略不同
    if chara.attack_range <= 1:
        # 近战：选择离敌人最近的格子
        return _pick_closest_to_target(reachable, enemy_cell)
    else:
        # 远程：选择在攻击范围内且离敌人最远的格子（保持距离）
        var in_range = _filter_cells_in_attack_range(reachable, enemy_cell, chara.attack_range)
        if in_range.is_empty():
            return _pick_closest_to_target(reachable, enemy_cell)
        return _pick_farthest_from_target(in_range, enemy_cell)
```

##### 攻击评估 `_evaluate_attack_target(chara)`

策略：
1. 获取角色攻击范围内的所有敌方角色
2. 优先选择 HP 最低的敌方角色（最大化击杀概率）
3. 如果都不在范围，返回 null

```gdscript
func _evaluate_attack_target(chara) -> Node:
    var enemies = _get_enemies_in_attack_range(chara)
    if enemies.is_empty():
        return null
    # 按 HP 升序排列，选择最低的
    enemies.sort_custom(func(a, b): return a.hp < b.hp)
    return enemies[0]
```

##### 技能评估 `_evaluate_skill_target(chara)`

每个角色的技能策略不同（硬编码策略）：

| 角色 | 技能 | 目标策略 |
|---|---|---|
| 布洛妮娅 | 护卫指令（护盾+30） | 给当前 HP 最低的友方角色套盾 |
| 希儿 | 相位突进（瞬移+1.2倍伤害） | 选择 HP 最低且能被 1.2×ATK 击杀的敌人 |
| 伊蕾娜 | 星尘爆裂（AOE 35伤害） | 选择周围有最多敌方聚集的目标 |
| 流萤 | 烈焰冲锋（25伤+灼烧） | 选择 HP 最高或有增益 buff 的敌人 |
| 银狼 | 系统入侵（减攻+减速 3回合） | 选择攻击力最高的敌人 |
| 芝士仓鼠 | 动作如潮（额外行动） | 只要有敌人可攻击就使用 |

实现方式：
```gdscript
func _evaluate_skill_target(chara) -> Node:
    var name = chara.character_name
    match name:
        "布洛妮娅":
            return _find_lowest_hp_ally()
        "希儿":
            return _find_killable_with_bonus(chara)
        "伊蕾娜":
            return _find_best_aoe_target(chara)
        "流萤":
            return _find_highest_value_target()
        "银狼":
            return _find_highest_attack_enemy()
        "芝士仓鼠":
            return _evaluate_attack_target(chara)
        _:
            return null
```

##### 卡牌评估 `_evaluate_best_card(chara)`

策略：
1. 获取 AI 手牌（`_deck_manager.get_hand(2)`）
2. 过滤出能量足够的卡牌
3. 对每张卡牌用简单评分函数评估
4. 选择评分最高的卡牌

评分规则：

| 卡牌类型 | 评分逻辑 |
|---|---|
| ATTACK (伤害) | HP 最低敌人可击杀时 +100；否则 base_damage + 10 |
| HEAL (治疗) | 最低 HP 友方 < 50% 时 +80；< 75% 时 +40 |
| SHIELD (护盾) | 最低 HP 友方 < 40%时 +60 |
| BUFF (强化) | 没有同类 buff 时 +30 |
| DEBUFF (削弱) | 敌人没有同类 debuff 时 +40 |
| TACTICAL (战术) | 手牌<3 时 draw/echo +50；overload +30 |
| DISPLACE (位移) | 敌人聚集时 +20 |

```gdscript
func _evaluate_best_card(chara) -> Dictionary:
    var hand = _deck_manager.get_hand(2)
    var best_action = null
    var best_score = -999

    for card_id in hand:
        var card = CardDatabase.get_card(card_id)
        if not card:
            continue
        if not _energy_system.can_afford(2, card.cost):
            continue

        # 根据目标类型获取可用目标和评分
        var target = null
        var score = _score_card(card, chara)

        if score > best_score:
            best_score = score
            best_action = {
                "type": "card",
                "character": chara,
                "card_id": card_id,
                "target": target  # 目标会在执行前解析
            }

    return best_action if best_score >= 20 else null
```

卡牌目标选取：
```gdscript
func _pick_target_for_card(card: CardData) -> Node:
    match card.target_type:
        CardData.TargetType.NONE:
            return null
        CardData.TargetType.SELF:
            return _get_ai_caster_for_card()
        CardData.TargetType.ALLY_SINGLE:
            return _find_lowest_hp_ally()
        CardData.TargetType.ALLY_ALL:
            return _get_random_ai_character()
        CardData.TargetType.ENEMY_SINGLE:
            return _find_lowest_hp_enemy()
        CardData.TargetType.ENEMY_ALL:
            return _get_random_enemy()
        CardData.TargetType.ALL_CHARACTERS:
            return _get_random_enemy()
        _:
            return null
```

#### 3.5.8 辅助函数

```gdscript
# BFS 找到角色的所有可达格子
func _bfs_reachable(chara, max_move: int) -> Array[Vector2i]:
    var gl = chara.grid_layer
    var start = chara.get_current_cell()
    if start == Vector2i(-1, -1):
        return []
    var result: Array[Vector2i] = []
    var visited: Dictionary = {}
    var queue = [{ "cell": start, "cost": 0 }]
    visited[start] = true

    var dirs = [Vector2i(1,0), Vector2i(1,-1), Vector2i(0,-1),
                Vector2i(-1,0), Vector2i(-1,1), Vector2i(0,1)]

    while queue.size() > 0:
        var current = queue.pop_front()
        for d in dirs:
            var next = current.cell + d
            if visited.has(next):
                continue
            var cost = chara.get_move_cost(next)
            if cost <= 0:
                visited[next] = true
                continue
            if current.cost + cost > max_move:
                continue
            if _main.is_cell_occupied(next, chara):
                visited[next] = true
                continue
            visited[next] = true
            result.append(next)
            queue.append({ "cell": next, "cost": current.cost + cost })

    return result

# 找到最近的敌方角色
func _find_nearest_enemy(chara) -> Node:
    var enemies = _get_enemy_characters_alive()
    var nearest = null
    var min_dist = INF
    var chara_cell = chara.get_current_cell()
    for e in enemies:
        var e_cell = e.get_current_cell()
        var dist = chara_cell.distance_to(e_cell)
        if dist < min_dist:
            min_dist = dist
            nearest = e
    return nearest

# 获取存活敌方角色
func _get_enemy_characters_alive() -> Array:
    var result = []
    for c in GlobalGameData.host_characters:
        if c.hp > 0:
            result.append(c)
    return result

# 获取存活 AI 角色
func _get_ai_characters_alive() -> Array:
    var result = []
    for c in GlobalGameData.client_characters:
        if c.hp > 0:
            result.append(c)
    return result

# 结束当前阶段
func _end_phase():
    # 清除选中状态
    _main.unselect_character(null, true)
    _main.rpc("advance_turn_phase")
```

#### 3.5.9 角色名映射（用于 AI 队伍生成）

在 `_generate_ai_team_and_deck()` 中，队伍使用角色 ID（如 `"bronya"`），后续 `_build_team_from_selection()` 通过 `map` 字典解析角色场景。`GlobalGameData.client_team` 格式与 `selected_team` 一致（`Array[String]`，角色 ID 数组）。

角色 ID 列表：
```
["bronya", "seele", "elaina", "firefly", "silverwolf", "hamster"]
```

---

### 3.6 `Characters/BaseCharacter.gd` — AI 模式适配

#### 3.6.1 `_process()` 调整

约第 708-723 行，当前逻辑：
```gdscript
func _process(delta):
    _check_hover()
    if not multiplayer or not multiplayer.has_multiplayer_peer():
        move_toward_target()
        return
    if not is_multiplayer_authority():
        return
    if name.begins_with("Host") != GlobalGameData.is_host:
        return
    ...
```

AI 模式下，Client 方角色不应处理玩家输入（`handle_move()` / `handle_attack()`），因为 AI 控制器会直接设置 `target_world` 和调用 `perform_attack`。

修改后：
```gdscript
func _process(delta):
    _check_hover()
    if not multiplayer or not multiplayer.has_multiplayer_peer():
        # AI 模式：Client 方角色由 AI 控制，跳过输入处理
        if GlobalGameData.is_ai_mode and name.begins_with("Client"):
            move_toward_target()
            return
        move_toward_target()
        return
    if not is_multiplayer_authority():
        return
    if name.begins_with("Host") != GlobalGameData.is_host:
        return
    ...原有逻辑...
```

> **关键**：AI 模式中 Client 角色仍然执行 `move_toward_target()` 以响应 AI 设置的 `target_world`，但不处理鼠标输入。

---

## 4. 与 LAN 模式的隔离保证

### 4.1 路径覆盖分析

| 代码路径 | LAN 联机 | AI 模式 | 是否共用 |
|---|---|---|---|
| `MainMenu._on_host_pressed()` | ✅ 创建 ENet 服务器 | ❌ | 独立 |
| `MainMenu._on_join_pressed()` | ✅ 连接服务器 | ❌ | 独立 |
| `MainMenu._on_ai_battle_pressed()` | ❌ | ✅ 设置 AI 标志 | 独立 |
| `main.gd _ready()` LAN 分支（75-87） | ✅ 无条件 | ❌ `is_ai_mode` 提前 return | 独立 |
| `main.gd _ready()` AI 分支 | ❌ | ✅ `is_ai_mode` 判断 | 独立 |
| `BaseCharacter._process()` | ✅ 完整 | ✅ 添加 AI 分支 | 共享，有标志保护 |
| `AIController._process()` | ❌ `is_ai_mode` 保护 | ✅ | 独立 |

### 4.2 确保无影响的措施

1. **所有 AI 新代码均以 `GlobalGameData.is_ai_mode` 为前置条件**，LAN 模式下该标志始终为 false
2. **LAN 模式的 `_ready()` 路径不进入任何 AI 分支**，因 AI 分支在 LAN 分支前有 `return`
3. **LAN 模式下 `GlobalGameData.ai_deck` 不会被初始化**，不会被任何读取
4. **LAN 模式的 RPC 调用路径完全不变**，AI 模式不需要 RPC，全部本地调用
5. **Git 分离**：所有改动在 `feature/ai-mode` 分支，`master` 分支不受影响

---

## 5. 开发阶段与输出物

### Phase 1：基础设施
- [x] 创建 `feature/ai-mode` 分支
- [ ] `GlobalGameData.gd` — 添加 `is_ai_mode` 和 `ai_deck` 字段
- [ ] `Menus/MainMenu.tscn` — 添加按钮
- [ ] `Menus/MainMenu.gd` — 添加信号处理

### Phase 2：场景初始化
- [ ] `Scenes/main.gd` — AI 模式初始化分支
- [ ] `Scenes/main.gd` — `_generate_ai_team_and_deck()`
- [ ] `Scenes/main.gd` — `_init_player_card_systems_ai()`
- [ ] `Scenes/main.gd` — `_setup_ai_controller()`

### Phase 3：AI 控制器框架
- [ ] `AI/AIController.gd` — 节点结构与生命周期
- [ ] 阶段感知 + 动作队列机制
- [ ] 移动执行 + `_evaluate_move_target()`
- [ ] 攻击执行 + `_evaluate_attack_target()`
- [ ] 技能执行 + `_evaluate_skill_target()`

### Phase 4：AI 卡牌系统
- [ ] `_evaluate_best_card()` — 卡牌评分
- [ ] `_pick_target_for_card()` — 卡牌目标选取
- [ ] `_execute_card()` — 卡牌执行

### Phase 5：适配与集成
- [ ] `BaseCharacter.gd` — AI 模式下的 `_process()` 适配
- [ ] AI 模式与 LAN 模式兼容性验证

### Phase 6：调试与验证
- [ ] LAN 联机模式回归测试
- [ ] AI 模式功能测试
- [ ] 边界情况测试（角色死亡、游戏结束等）
- [ ] 提交代码

---

## 6. Git 提交计划

```
commit 1: docs: add AI mode implementation plan (docs/08-ai-mode-plan.md)
commit 2: feat: add is_ai_mode flag to GlobalGameData
commit 3: feat: add "单机人机" button to main menu
commit 4: feat: implement AI mode initialization in main.gd
commit 5: feat: create AIController.gd with move/attack/skill logic
commit 6: feat: add AI card play evaluation and execution
commit 7: feat: adapt BaseCharacter for AI-controlled characters
commit 8: fix: address edge cases found during testing
```

---

## 7. 风险与应对

| 风险 | 影响 | 应对方案 |
|---|---|---|
| AI 移动时与角色 `_process` 移动逻辑冲突 | AI 移动异常 | AI 直接设置 `target_world`，角色 `move_toward_target()` 自动处理路径更新 |
| AI 调用 `main._active_skill_post_exec()` 导致状态不一致 | 技能标记错乱 | AI 严格按照 `_on_skill_used` → `use_active_skill` → `_active_skill_post_exec` 顺序调用 |
| `check_move()`/`check_attack()` 在 AI 模式下计数异常 | 阶段提前/延迟 | AI 每执行一个动作后立即调用，计数逻辑与人类操作一致 |
| AI 模式误触 ENet 相关代码 | 游戏崩溃 | 所有 AI 路径在初始化时跳过 `multiplayer` 相关调用 |
