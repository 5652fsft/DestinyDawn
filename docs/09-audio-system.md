# 音效系统设计细则

> 基于 `docs/10-improvement-plan.md` 第一部分"游戏音效系统"展开的详细实现规划。

---

## 一、架构概述

### 设计目标

- 全局音效管理器，菜单与战斗共用
- 支持 BGM 循环播放 + SFX 即时触发
- SFX 支持 2D 空间定位（战斗中的角色音效）
- 音量独立控制（Master / BGM / SFX 三路）
- 与现有 VFX 系统平行的"视听反馈层"

### 核心组件

| 组件 | 文件 | 类型 | 职责 |
|------|------|------|------|
| AudioManager | `Global/AudioManager.gd` | autoload | 所有音频播放的统一入口 |
| AudioBus 配置 | `project.godot` 音频总线 | 资源 | Master / BGM / SFX 三路总线 |
| 音效资源 | `Assets/Audio/SFX/*.ogg` | 文件 | 短音效（< 3s） |
| BGM 资源 | `Assets/Audio/BGM/*.ogg` | 文件 | 背景音乐 |
| AudioStreamPlayer2D | 运行时动态创建 | 节点 | 战斗中带空间定位的 SFX |
| AudioStreamPlayer | 预置在 AudioManager 中 | 节点 | BGM 播放 + 菜单 UI 音效 |

---

## 二、AudioManager API 详细设计

### 类定义 `Global/AudioManager.gd`

```
extends Node

# —— 播放接口 ——
func play_sfx(name: String, target: Node = null) -> void
func play_bgm(name: String) -> void
func stop_bgm(fade: float = 0.0) -> void

# —— 音量控制 ——
func set_master_volume(v: float) -> void   # v: 0.0 ~ 1.0
func set_bgm_volume(v: float) -> void
func set_sfx_volume(v: float) -> void

func get_master_volume() -> float
func get_bgm_volume() -> float
func get_sfx_volume() -> float

# —— 预加载 ——
func preload_sfx(names: Array[String]) -> void
func preload_bgm(names: Array[String]) -> void

# —— 内部 ——
func _get_sfx_player(pooled: bool = true) -> AudioStreamPlayer2D
func _return_player(player: AudioStreamPlayer2D) -> void
```

### 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `name` | String | 音效标识符，对应文件名（不含扩展名） |
| `target` | Node | 可选，若传入则创建 `AudioStreamPlayer2D` 跟随该节点（空间定位） |
| `fade` | float | BGM 淡出秒数 |
| `v` | float | 0.0（静音）~ 1.0（最大） |

### 音量持久化

音量值通过 `GlobalGameData` 存储，key 定义：

```
GlobalGameData.audio_volume_master  # float, default 0.8
GlobalGameData.audio_volume_bgm     # float, default 0.6
GlobalGameData.audio_volume_sfx     # float, default 0.8
```

在 `GlobalGameData.load_defaults_if_empty()` 中初始化，在 `SettingsScene` 中修改。

---

## 三、音频总线配置

### 总线结构（在 Godot 编辑器的 Audio 选项卡中配置）

```
Master (volume: 0 dB)
├── BGM (volume: 0 dB)
└── SFX (volume: 0 dB)
```

AudioManager 通过 `AudioServer.set_bus_volume_db()` 控制各路音量，音量换算公式：

```gdscript
var db = linear_to_db(v)  # v ∈ [0.0, 1.0]
AudioServer.set_bus_volume_db(bus_index, db)
```

### 总线索引常量

```
const BUS_MASTER: int = 0
const BUS_BGM: int    = 1
const BUS_SFX: int    = 2
```

---

## 四、音效素材清单与命名规范

### 命名规范

- 全小写 snake_case
- 使用 `.ogg` 格式（Godot 原生支持，压缩率高）
- 短音效控制在 1~3 秒，BGM 不限

### 分类清单

#### BGM（Assets/Audio/BGM/）

| 文件名 | 用途 | 播放时机 |
|--------|------|----------|
| `battle.ogg` | 战斗背景音乐 | 进入战斗场景时播放，持续循环 |

#### SFX - 战斗反馈（Assets/Audio/SFX/）

| 文件名 | 用途 | 优先级 | 触发生命周期 |
|--------|------|--------|-------------|
| `move.ogg` | 角色移动到位 | 低 | `BaseCharacter.move_toward_target()` 到达目标时 |
| `attack.ogg` | 攻击命中 | 高 | `BaseCharacter._play_attack_animation()` 中 |
| `skill.ogg` | 释放技能 | 高 | `BaseCharacter.use_active_skill()` 或 `_active_skill_post_exec()` |
| `card_play.ogg` | 使用卡牌 | 中 | `_execute_play_card()` 中 |
| `heal.ogg` | 治疗触发 | 中 | `BaseCharacter.take_damage()` 当 damage < 0 时 |
| `shield.ogg` | 护盾生效 | 中 | `CardEffect._execute_shield()` 中 |
| `death.ogg` | 角色阵亡 | 高 | `BaseCharacter.take_damage()` 当 hp <= 0 时 |
| `victory.ogg` | 战斗胜利 | 高 | `show_battle_result()` 中 |
| `defeat.ogg` | 战斗失败 | 高 | `show_battle_result()` 中 |
| `move_click.ogg` | 点击移动按钮 | 低 | `_on_move_pressed()` 中 |
| `attack_click.ogg` | 点击攻击按钮 | 低 | `_on_attack_pressed()` 中 |
| `turn_start.ogg` | 回合开始提示 | 中 | `_sync_turn_phase()` 中 |

#### SFX - UI 交互（Assets/Audio/SFX/）

| 文件名 | 用途 | 触发位置 |
|--------|------|----------|
| `click.ogg` | 按钮点击 | `ButtonTheme._up()` 中 |
| `hover.ogg` | 按钮悬停 | `ButtonTheme._enter()` 中 |
| `page_flip.ogg` | 菜单/界面切换 | 各菜单 `change_scene_to_file()` 前 |
| `deck_select.ogg` | 卡组选择操作 | 卡组构筑界面 |
| `error.ogg` | 操作错误提示 | `show_toast()` 中 |

---

## 五、集成点详细对照

### 5.1 UI 层 — ButtonTheme（全局按钮音效）

`Global/ButtonTheme.gd` 中新增：

```
_enter()  → AudioManager.play_sfx("hover")
_up()     → AudioManager.play_sfx("click")
```

注意：_down 不播放音效，仅在 _up 时播放 click，避免误触反馈。

### 5.2 UI 层 — 菜单切换

各菜单场景切换前播放 `page_flip`：

| 文件 | 位置 | 添加 |
|------|------|------|
| `Menus/MainMenu.gd` | `_on_team_pressed` / `_on_deck_pressed` 等 | `AudioManager.play_sfx("page_flip")` |
| `Menus/SettingsScene.gd` | `_on_save_pressed` / `_on_back_pressed` | `AudioManager.play_sfx("page_flip")` |
| `Menus/TeamFormation.gd` | 返回按钮 | `AudioManager.play_sfx("page_flip")` |
| `Menus/DeckBuilder.gd` | 返回按钮 | `AudioManager.play_sfx("page_flip")` |
| `UI/BattleResult.gd` | `_on_return_pressed` | `AudioManager.play_sfx("page_flip")` |

### 5.3 战斗层 — BaseCharacter

`Characters/BaseCharacter.gd` 中集成：

| 方法 | 插入音效 | 说明 |
|------|---------|------|
| `move_toward_target()` 到达后 (line 728 附近) | `play_sfx("move", self)` | 到达目标格时播放，2D 定位 |
| `_play_attack_animation()` (line 506~541) | `play_sfx("attack", self)` | 攻击触发瞬间，2D 定位 |
| `take_damage()` 当 damage < 0 (line 576~584) | `play_sfx("heal", self)` | 治疗时 |
| `take_damage()` 护盾吸收 (line 601~607) | `play_sfx("shield", self)` | 护盾触发时 |
| `take_damage()` 当 hp <= 0 (line 616~624) | `play_sfx("death", self)` | 阵亡时，2D 定位 |

### 5.4 战斗层 — main.gd（回合/卡牌/技能）

`Scenes/main.gd` 中集成：

| 方法 | 插入音效 | 说明 |
|------|---------|------|
| `_on_move_pressed()` (line 166) | `play_sfx("move_click")` | 移动按钮点击 |
| `_on_attack_pressed()` (line 183) | `play_sfx("attack_click")` | 攻击按钮点击 |
| `_execute_play_card()` (line 559) | `play_sfx("card_play")` | 卡牌使用确认时 |
| `_active_skill_post_exec()` (line 629) | `play_sfx("skill")` | 技能释放后 |
| `_sync_turn_phase()` 回合变更 (line 822) | `play_sfx("turn_start")` | 每次新回合阶段开始时 |
| `show_battle_result()` (line 766) | `play_sfx("victory" 或 "defeat")` | 战斗结算，对应胜负 |
| `show_toast()` 警告类 | `play_sfx("error")` | 操作被拒绝时（能量不足/超出范围等） |

### 5.5 战斗层 — CardEffect（卡牌效果音效）

`Cards/CardEffect.gd` 中在已有 VFX 调用旁追加 SFX：

| 已有 VFX 调用 | 追加音效 | 说明 |
|--------------|---------|------|
| `_execute_heal()` 中 `_play_vfx_preset("heal")` | `play_sfx("heal", target)` | 治疗效果 |
| `_execute_shield()` 中 `_play_vfx_preset("shield")` | `play_sfx("shield", target)` | 护盾效果 |
| `_execute_aoe_damage()` 中 `_play_vfx_preset("explosion")` | `play_sfx("skill", target)` | 范围伤害 |
| `_execute_teleport()` 中 `_play_vfx_preset("hit")` | `play_sfx("skill", target)` | 传送附带伤害 |

### 5.6 战斗层 — SkillEffect（技能音效）

`Skills/SkillEffect.gd` 中追加：

| 函数 | 添加音效 | 说明 |
|------|---------|------|
| `_bronya_active()` — 护盾 | `play_sfx("shield", target)` | 护卫指令 |
| `_firefly_active()` — 烈焰冲锋 | `play_sfx("skill", target)` | 主动技能 |
| `_elaina_active()` — 星尘爆裂 | `play_sfx("skill", target)` | AOE 技能 |
| `_silverwolf_active()` — 系统入侵 | `play_sfx("skill", target)` | 减益技能 |

### 5.7 BGM（背景音乐）

| 集成位置 | 操作 | 说明 |
|---------|------|------|
| `main.gd._ready()` | `AudioManager.play_bgm("battle")` | 战斗场景加载时自动播放 |
| `show_battle_result()` | `AudioManager.stop_bgm(0.5)` | 结算时淡出 BGM |
| 返回主菜单时 | `AudioManager.stop_bgm()` | 由页面切换或主菜单重新播放菜单 BGM |

---

## 六、AudioManager 内部实现要点

### 6.1 资源加载

- 在 `_ready()` 中使用 `preload()` 加载所有已知音效
- 音效文件映射表：

```gdscript
const SFX_MAP: Dictionary = {
    "click":       preload("res://Assets/Audio/SFX/click.ogg"),
    "hover":       preload("res://Assets/Audio/SFX/hover.ogg"),
    # ... 所有音效
}

const BGM_MAP: Dictionary = {
    "battle":      preload("res://Assets/Audio/BGM/battle.ogg"),
}
```

### 6.2 播放器池

- 预创建 4 个 `AudioStreamPlayer2D` 作为 SFX 播放池（循环使用）
- `play_sfx(name)` 时从池中取一个空闲播放器
- 若全部繁忙，创建新播放器并在播放结束后自动回收
- BGM 使用专有的 1 个 `AudioStreamPlayer`（`$BGMPLayer`）

### 6.3 空间定位

- 当 `play_sfx(name, target)` 的 target 不为 null 时，使用 `AudioStreamPlayer2D` 并调用 `reparent(target)` 或更新 `global_position` 跟随目标
- 当 target 为 null 或 target 不在场景树中时，作为全局 2D 音效播放（使用默认位置）

### 6.4 节流保护

- 高频音效（如连续攻击）做防抖：相同音效名 50ms 内不重复播放
- 使用 `_last_play_time: Dictionary` 记录每个音效的最后播放时间

---

## 七、SettingsScene 音量设置

`Menus/SettingsScene.tscn` 中新增三个 `HSlider`：

```
VBoxContainer
├── [已有控件]
├── MasterLabel + MasterSlider (范围 0~100, 默认 80)
├── BGMLabel   + BGMSlider   (范围 0~100, 默认 60)
└── SFXLabel   + SFXSlider   (范围 0~100, 默认 80)
```

- 滑块 `value_changed` 信号连接 `AudioManager.set_*_volume(v/100.0)`
- 初始化时读取 `GlobalGameData.audio_volume_*`
- 保存时写入 `GlobalGameData.audio_volume_*`

---

## 八、实施步骤与分工

### Phase 1：基础设施（估计 1h）

| 步骤 | 文件 | 内容 |
|------|------|------|
| 1.1 | `project.godot` | 创建 BGM / SFX 两条音频总线 |
| 1.2 | `Global/AudioManager.gd` | 实现完整 AudioManager（播放、音量、节流、池化） |
| 1.3 | `project.godot` | 注册 AudioManager 为 autoload |
| 1.4 | `GlobalGameData.gd` | 新增音量持久化字段 + `load_defaults_if_empty()` 初始化 |

### Phase 2：音效素材（估计 1h）

| 步骤 | 内容 |
|------|------|
| 2.1 | 从免费音效库收集/裁剪所有 SFX（参考第四节清单） |
| 2.2 | 准备 BGM（battle.ogg） |
| 2.3 | 放入 `Assets/Audio/SFX/` 和 `Assets/Audio/BGM/` |
| 2.4 | 在 AudioManager 中注册所有资源路径 |

### Phase 3：UI 音效集成（估计 30min）

| 步骤 | 文件 | 内容 |
|------|------|------|
| 3.1 | `Global/ButtonTheme.gd` | 添加 hover / click 音效 |
| 3.2 | `Menus/MainMenu.gd` | 添加 page_flip |
| 3.3 | `Menus/SettingsScene.gd` | 添加 page_flip + 音量滑块 |

### Phase 4：战斗音效集成（估计 1.5h）

| 步骤 | 文件 | 内容 |
|------|------|------|
| 4.1 | `Characters/BaseCharacter.gd` | move / attack / heal / shield / death |
| 4.2 | `Scenes/main.gd` | card_play / skill / turn_start / victory/defeat / error |
| 4.3 | `Cards/CardEffect.gd` | 卡牌效果音效追加 |
| 4.4 | `Skills/SkillEffect.gd` | 技能音效追加 |

### Phase 5：BGM（估计 30min）

| 步骤 | 文件 | 内容 |
|------|------|------|
| 5.1 | `Scenes/main.gd._ready()` | 播放 battle BGM |
| 5.2 | `Scenes/main.gd.show_battle_result()` | 淡出 BGM |

### Phase 6：测试调优（估计 1h）

| 步骤 | 内容 |
|------|------|
| 6.1 | 逐项验证 22 个集成点是否正确触发 |
| 6.2 | 音量平衡（BGM 与 SFX 的比例） |
| 6.3 | 节流效果验证（连点按钮不会音效重叠） |
| 6.4 | AI 模式与多人模式下的音效一致性 |

---

## 九、集成点总表

| # | 音效 | 文件名 | 集成位置 | 定位方式 |
|---|------|--------|---------|---------|
| 1 | click | `ButtonTheme.gd:_up()` | UI 通用 | 全局 |
| 2 | hover | `ButtonTheme.gd:_enter()` | UI 通用 | 全局 |
| 3 | page_flip | 各菜单 `change_scene_to_file()` | UI 菜单 | 全局 |
| 4 | move | `BaseCharacter.gd:move_toward_target()` | 战斗 | 2D 定位 |
| 5 | attack | `BaseCharacter.gd:_play_attack_animation()` | 战斗 | 2D 定位 |
| 6 | heal | `BaseCharacter.gd:take_damage()` (damage < 0) | 战斗 | 2D 定位 |
| 7 | shield | `BaseCharacter.gd:take_damage()` (absorb) | 战斗 | 2D 定位 |
| 8 | death | `BaseCharacter.gd:take_damage()` (hp <= 0) | 战斗 | 2D 定位 |
| 9 | skill | `main.gd:_active_skill_post_exec()` | 战斗 | 全局 |
| 10 | card_play | `main.gd:_execute_play_card()` | 战斗 | 全局 |
| 11 | move_click | `main.gd:_on_move_pressed()` | 战斗 UI | 全局 |
| 12 | attack_click | `main.gd:_on_attack_pressed()` | 战斗 UI | 全局 |
| 13 | turn_start | `main.gd:_sync_turn_phase()` | 战斗 | 全局 |
| 14 | victory | `main.gd:show_battle_result()` (赢) | 战斗 | 全局 |
| 15 | defeat | `main.gd:show_battle_result()` (输) | 战斗 | 全局 |
| 16 | error | `main.gd:show_toast()` 警告 | 战斗 UI | 全局 |
| 17 | battle BGM | `main.gd:_ready()` | 战斗 | 全局 |

---

## 十、异常与边界处理

| 场景 | 行为 |
|------|------|
| 音效文件缺失 | `AudioManager.play_sfx()` 静默跳过，输出 warning |
| AudioManager 尚未初始化 | 各调用处判空（`if AudioManager:`） |
| 多人在线同步 | 音效在本地播放，无需 RPC 同步（播放时机已由 RPC 驱动） |
| AI 模式 | 音效播放逻辑与多人模式一致（AI 操作仍触发本地音效） |
| 场景切换 | Autoload 的 AudioManager 不受场景切换影响，BGM 可跨场景持续 |
| 移动端性能 | 播放器池上限 8 个，超出时复用最早播放器 |

---

## 十一、引用文档

- `docs/10-improvement-plan.md` — 改进规划（原始需求）
- `docs/06-data-format-reference.md` — GlobalGameData 数据格式
- `project.godot` — Autoload 注册 + 音频总线
