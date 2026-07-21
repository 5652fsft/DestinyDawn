# 改进规划（Phase 10）

## 一、动态背景

### 目标
主菜单、编队界面、卡组构筑、设置界面共用一个动态背景（视频循环播放），替代当前的静态图片。

### 实现方案

**技术选型**：`VideoStreamPlayer` 节点循环播放 mp4 视频，全屏叠加在菜单最底层。

**文件结构**：
```
Assets/
└── Video/
    ├── BronyaAndSeele1.mp4   # 背景视频 A
    └── Elaina1.mp4           # 背景视频 B
Scenes/
└── MenuBackground.tscn       # 动态背景场景
Global/
├── BackgroundManager.gd      # 背景管理器（autoload），管理当前选中背景与视频状态
└── BackgroundManager.gd.uid
```

**BackgroundManager.gd 职责**：
- `current_bg: String` — 当前选中的背景标识（`"bronya_seele"` / `"elaina"` / `"static"`）
- `set_background(id: String)` — 切换背景，保存设置到文件
- `get_bg_path(id: String) -> String` — 根据标识返回视频资源路径
- `get_available_backgrounds() -> Array[Dictionary]` — 返回可选列表（含名称、预览缩略图）
- `load_saved_setting()` / `save_setting()` — 持久化配置（写入文件或 GlobalGameData）

**VideoStreamPlayer 配置**：
- `autoplay = true`
- `expand = true`（拉伸铺满全屏）
- `mouse_filter = MOUSE_FILTER_IGNORE`（不拦截鼠标事件）
- 循环播放：连接 `finished` 信号 → 调用 `play()` 重新开始

**设置可选项**：
- 多个动态背景可选（Bronya&Seele / Elaina）
- 保留静态背景作为回退选项（`"static"`）
- 在设置界面添加下拉选择器

**集成方式**：
在各菜单场景（MainMenu / TeamFormation / DeckBuilder / SettingsScene）中添加 MenuBackground 实例，铺满全屏置于最底层。同时移除原有的静态背景图片节点（`BgSprite`）。

**BackgroundManager 使用方式**：
```gdscript
# 获取当前背景路径
var bg_mgr = BackgroundManager
var path = bg_mgr.get_current_bg_path()
$VideoPlayer.stream = load(path)
$VideoPlayer.play()

# 切换背景
BackgroundManager.set_background("elaina")

# 监听设置变更（在设置界面）
var options = BackgroundManager.get_available_backgrounds()
# 返回: [{"id":"bronya_seele","name":"布洛妮娅 & 希儿","path":"res://Assets/Video/BronyaAndSeele1.mp4"},
#         {"id":"elaina","name":"伊蕾娜","path":"res://Assets/Video/Elaina1.mp4"},
#         {"id":"static","name":"静态背景","path":""}]
```

---

## 二、UI 改进

### 2.1 卡牌系统

| 改进项 | 现状 | 目标 |
|--------|------|------|
| 费用不足灰化 | 无，能量不足时仍可拖拽但释放失败 | 手牌中费用 > 当前能量的卡牌灰化 + 禁用拖拽，鼠标悬停显示消耗提示 |
| 卡面重设计 | 纯文字卡片，仅有名称/描述/费用 | 重新排版：增加卡牌稀有度边框/底色，元素图标（火/冰/毒/盾），效果数值加粗/着色，费用醒目展示（已有点，需要美化） |

**卡面重设计详细方案**：

```
┌─────────────┐
│  ⚡ 1       │  ← 费用（左上角圆形，颜色随类型变化）
│             │
│  火球术     │  ← 卡名（居中，大字，带阴影）
│             │
│  造成 20    │  ← 描述区（小字，效果数值标红/加粗）
│  点伤害     │
│             │
│  ATTACK     │  ← 类型标签（右下角，颜色区分：红=攻击，绿=治疗，蓝=Buff等）
└─────────────┘
```

**卡面颜色方案**：

| 卡牌类型 | 边框/底色 | 费用颜色 | 标签文字 |
|----------|-----------|----------|----------|
| ATTACK   | 暗红 (#8B0000) | 红   | ATTACK |
| HEAL     | 深绿 (#006400) | 绿   | HEAL   |
| BUFF     | 蓝紫 (#4B0082) | 蓝   | BUFF   |
| DEBUFF   | 暗紫 (#800080) | 紫   | DEBUFF |
| SHIELD   | 钢蓝 (#4682B4) | 蓝   | SHIELD |
| TACTICAL | 金 (#B8860B)   | 金   | TACTICAL |
| DISPLACE | 橙 (#FF8C00)   | 橙   | DISPLACE |

**实现方式**：
- 修改 `CardUI.gd` 中的 `setup(data)` 方法，根据 `card_data.card_type` 设置不同颜色主题
- 使用 `StyleBoxFlat` 动态设置卡牌面板的 `bg_color` 和 `border_color`
- 添加 `CardType` 标签显示
- 添加图标系统（可选）：为每种效果类型预设 Emoji/图标字符

### 2.2 角色信息面板（CharacterInfoPanel）

**目标**：增强信息可读性和视觉层次。

**需要补充的字段**：

| 字段 | 说明 |
|------|------|
| 角色等级 | 预留（当前未实装等级系统，显示"Lv.1"） |
| 元素/类型标签 | 根据角色设定显示标签（如：近战/远程/法师/坦克） |
| 当前状态 | 醒目标示（已行动/待行动/无法行动） |
| Buff 数量统计 | "增益 ×3  减益 ×1" 的概览行 |
| 主动技能冷却 | 在技能面板上方显示冷却回合数 |

**面板布局重排**（从上到下）：

```
┌─────────────────────┐
│  伊蕾娜    Lv.1     │  ← 名称 + 等级
│  法师 · 远程        │  ← 类型标签
│  ═══════════════    │
│  ❤ 60/60  ⚔ 20     │  ← 生命 + 攻击力（并排）
│  ➤ 5格   〉 3格     │  ← 移动范围 + 攻击范围
│  🛡 0               │  ← 护盾（有值时显示）
│  ═══════════════    │
│  [效果]             │  ← 效果标题
│  增益 ×2 减益 ×0    │  ← Buff 统计行
│  [魔力充盈] +15%    │  ← 各 Buff 明细
│  [力量强化] +8      │
└─────────────────────┘
```

**Buff 标签样式**（`_buff_desc` 返回值增加颜色标记）：

| Buff 类型 | 文本颜色 | 示例 |
|-----------|---------|------|
| ATTACK_BUFF | 绿色 | `[color=green][魔力充盈] +15%（2回合）[/color]` |
| ATTACK_DEBUFF | 红色 | `[color=red][虚弱] -8（2回合）[/color]` |
| DEFENSE_BUFF | 蓝色 | `[color=blue][防御] -20%伤害（2回合）[/color]` |
| DAMAGE_OVER_TIME | 暗红 | `[color=darkred][中毒] 每回合-5（3回合）[/color]` |
| HEAL_OVER_TIME | 绿色 | `[color=green][再生] 每回合+5（3回合）[/color]` |
| MARK | 紫色 | `[color=purple][标记] +50%伤害（2回合）[/color]` |
| MOVE_DEBUFF | 橙色 | `[color=orange][迟缓] -2移动（1回合）[/color]` |
| TAUNT | 金色 | `[color=gold][嘲讽] 强制攻击（1回合）[/color]` |

**实现方式**：
- `CharacterInfoPanel._buff_desc()` 改用 RichTextLabel 支持 BBCode
- 或每个 Buff 标签用 `Label.add_theme_color_override("font_color", color)` 单独着色
- 在 `refresh()` 中添加统计行（计算 buffs 中 is_harmful 的数量）
- 在 `show_for()` 中添加 `current_character` 的类型标签（可从 CharacterData 扩展）

### 2.3 主界面 UI 美化

**主菜单**：
- 背景切换为动态视频（见第一章）
- 按钮间距、悬停效果微调（已有 HOVER_SCALE，可增加阴影过渡）
- 标题"Destiny Dawn"增加发光效果或描边
- 版本号显示（右下角小字）

**编队界面**：
- 角色卡片增加稀有度边框
- 拖拽交换角色时增加动画反馈
- 当前队伍总属性概览（总HP/平均攻击力/移动力）

**卡组构筑界面**：
- 卡牌列表按费用/类型分组折叠
- 已选卡牌数量显示（如 12/20）
- 搜索/过滤框

**设置界面**：
- 背景选择下拉框（复用动态背景列表）
- 各选项增加简短说明文本

### 2.4 全局 UI

| 改进项 | 详细方案 | 实现位置 |
|--------|----------|----------|
| 回合过渡动画 | 阶段切换时半屏遮罩从右向左移入 + "你的回合"/"敌方回合"大字（变速缓动），停留 1s 后从左向右移出 | `main.gd` 的 `_sync_turn_phase` 或 `TurnIndicator.gd` |
| 战斗结果界面 | 胜利/失败弹窗：半透明全屏遮罩 + 居中卡片（带圆角阴影），显示战斗统计（伤害/治疗/击杀/回合数），"返回主菜单"/"再来一局"按钮（美化样式） | `BattleResult.tscn` 重新排版 |

**回合过渡动画实现方案**：

```gdscript
# 在 TurnIndicator.gd 或 main.gd 中
func show_turn_announcement(text: String, color: Color):
    var overlay = ColorRect.new()
    overlay.color = Color.BLACK
    overlay.modulate.a = 0.0
    overlay.size = get_viewport_rect().size
    add_child(overlay)
    
    var label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 48)
    label.add_theme_color_override("font_color", color)
    # 初始位置在屏幕右侧外
    label.position = Vector2(get_viewport_rect().size.x, get_viewport_rect().size.y * 0.4)
    add_child(label)
    
    # 移入动画：缓出（先快后慢）
    var tween = create_tween().set_parallel(true)
    tween.tween_property(overlay, "modulate:a", 0.5, 0.3)
    tween.tween_property(label, "position:x", get_viewport_rect().size.x * 0.5 - label.size.x * 0.5, 0.5)\
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    
    await get_tree().create_timer(1.0).timeout
    
    # 移出动画：缓入（先慢后快）
    tween = create_tween().set_parallel(true)
    tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
    tween.tween_property(label, "position:x", -label.size.x, 0.4)\
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    
    await tween.finished
    overlay.queue_free()
    label.queue_free()
```

---

## 三、特效改进

### 3.1 VFX 预设补充

当前 `_play_vfx_preset` 支持的预设：

| 预设 | 效果 | 使用场景 |
|------|------|----------|
| `buff` | 绿色上升粒子 | 增益效果 |
| `debuff` | 红色下降粒子 | 减益效果 |
| `heal` | 绿色十字/光晕 | 治疗类效果 |
| `explosion` | 爆炸粒子 | AOE 伤害 |
| `skill` | 技能特效 | 角色主动技能 |

需要补充：

| 新增预设 | 实现方案 | 使用场景 |
|----------|----------|----------|
| `shield` | 蓝色护盾光晕：Sprite2D 缩放 + 淡出，或环形粒子 | 护盾类卡牌/技能（`_execute_shield`） |
| `death` | 消散粒子：角色原地分解为向上飘散的碎片 | 角色阵亡时（`hp <= 0` → `_play_vfx_preset("death")`） |
| `teleport` | 闪烁：角色变半透明 → 位移 → 恢复，带拖尾粒子 | 位移类卡牌（shadowstep, teleport） |
| `critical` | 冲击波：圆形扩散环 + 屏幕震动 | 高伤害/暴击时（伤害 > 20 或特定技能） |

**VFX 预设实现方式**：

每个预设对应一个场景（`tscn`）或通过代码动态创建粒子/动画：

```gdscript
# VFXManager.gd 或 BuffManager.gd 中预加载场景
const VFX_SCENES = {
    "explosion": preload("res://Effects/Explosion.tscn"),
    "shield": preload("res://Effects/ShieldEffect.tscn"),
    "death": preload("res://Effects/DeathEffect.tscn"),
    "teleport": preload("res://Effects/TeleportEffect.tscn"),
    "critical": preload("res://Effects/CriticalEffect.tscn"),
}

func play_vfx(name: String, target: Node):
    var scene = VFX_SCENES.get(name)
    if not scene:
        return
    var instance = scene.instantiate()
    target.add_child(instance)
    # 自动播放后清除
```

**地图范围效果**：

对地图释放的卡牌/技能，需要在地图上显示对应效果：
- AOE 范围预览：高亮目标地格 + 周围受影响区域（使用 `highlight_layer.set_cell()`）
- 范围命中动画：在受影响的每个地格播放爆炸/命中粒子
- 指定地格技能：点击地格后在该位置播放特效

实现位置：`CardEffect.gd` 和 `SkillEffect.gd` 中，在执行效果前调用高亮函数，执行后清除高亮并播放命中特效。

### 3.2 屏幕震动

**CameraShake 组件**：

```gdscript
# Effects/CameraShake.gd
extends Camera2D

var shake_strength: float = 0.0
var shake_decay: float = 5.0

func apply_shake(strength: float):
    shake_strength = strength

func _process(delta):
    if shake_strength > 0:
        offset = Vector2(
            randf_range(-shake_strength, shake_strength),
            randf_range(-shake_strength, shake_strength)
        )
        shake_strength = max(0, shake_strength - shake_decay * delta)
    else:
        offset = Vector2.ZERO
```

**触发逻辑**（在 `BaseCharacter.take_damage()` 中）：

```gdscript
func take_damage(damage: int):
    ...
    # 伤害 > 20 时触发屏幕震动
    if damage > 20 and main and main.has_method("_apply_shake"):
        main._apply_shake(min(damage * 0.1, 5.0))
    ...
```

**集成方式**：
- 场景的 Camera2D 添加 CameraShake 脚本
- 或在 `main.gd` 中添加 `_apply_shake(strength)` 方法，遍历场景中所有 Camera2D

### 3.3 浮动数字改进

当前 `FloatingNumber.tscn` 仅有简单数字位移。

**改进方案**：

```gdscript
# FloatingNumber.gd
extends Node2D

enum NumberType { DAMAGE, HEAL, CRITICAL, BUFF, DEBUFF }

func show(value: int, type: NumberType):
    var label = $Label
    match type:
        NumberType.DAMAGE:
            label.text = "-%d" % value
            label.modulate = Color.RED
        NumberType.HEAL:
            label.text = "+%d" % value
            label.modulate = Color.GREEN
        NumberType.CRITICAL:
            label.text = "-%d!" % value
            label.modulate = Color.YELLOW
            label.add_theme_font_size_override("font_size", 28)  # 加粗放大
    # 向上飘出 + 缩放 + 淡出
    var tween = create_tween().set_parallel(true)
    tween.tween_property(self, "position:y", position.y - 40, 0.8).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
    await tween.finished
    queue_free()
```

---

## 四、交互改进

### 4.1 操作优化

| 改进项 | 详细方案 | 实现位置 |
|--------|----------|----------|
| 右键取消视觉反馈 | 当前右键取消无反馈。改为取消时短暂闪烁目标/地图边缘，或 toast"已取消" | `main.gd` 的 `_unhandled_input` 中右键取消分支 |
| 空格结束回合 | 我的回合时按空格键直接结束回合（等同于点击结束回合按钮），非回合阶段忽略 | `main.gd._input` 中新增 KEY_SPACE 处理 |
| ESC 取消选中 | 按 ESC 取消当前角色选中，关闭信息面板，回到无选中状态 | `main.gd._input` 中新增 KEY_ESCAPE 处理（调用 `unselect_character(null, true)`） |
| 点击空白取消选中 | 点击地图空白区域（无角色、无 UI 的地方）取消当前角色选中 | `BaseCharacter.handle_move()` 中，当点空白且未处于移动/攻击模式时调用 `main.unselect_character(null, true)` |
| 自动镜头居中 | 选中角色时镜头平滑移动到角色附近（`Camera2D.position` 插值到角色位置） | `main.gd.select_character()` 中新增镜头移动 tween |

### 4.2 目标选择优化

| 改进项 | 详细方案 |
|--------|----------|
| 拖拽时目标高亮 | 当卡牌拖拽到有效目标上方时，目标角色闪烁高亮（边框光晕或脉冲缩放）；无效目标时显示红框提示 |
| 高亮实现 | 拖拽过程中，`CardUI._process` 中调用 `main._try_select_target` 的低配版：只检测目标不执行，返回检测结果给 CardUI 或直接在高亮层显示。更好的方式：在 `main.gd` 中设置 `_drag_hovered_target`，在 `_process` 中更新，触发目标角色显示高亮圈 |

**拖拽高亮流程图**：

```
CardUI._process (每帧)
  → 检测鼠标位置下是否有角色
  → 如果有：
    → 判断是否为有效目标（卡牌 target_type 匹配）
    → 如果是有效目标：目标显示绿色高亮圈
    → 如果是无效目标：目标显示红色闪烁
  → 如果没有：清除高亮
```

### 4.3 拖拽优化

| 改进项 | 详细方案 |
|--------|----------|
| 无效释放弹回 | 卡牌拖拽到无效区域释放时，不是原地消失，而是沿拖拽路径反向飞回原位 + 缩放弹入动画（弹簧效果），然后正常消失 |

**弹回动画实现**：

```gdscript
# CardUI.gd 中，当 on_card_dropped 返回 false 时
func _drop_card():
    ...
    if main.on_card_dropped(card_data):
        # 有效释放：之前的消散动画
        ...
        queue_free()
        return
    # 无效释放：弹回动画
    if _ghost:
        var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(_ghost, "position", Vector2(0, 0), 0.3)  # 飞回原位
        tween.tween_property(_ghost, "scale", Vector2(1.0, 1.0), 0.3)
        tween.chain().tween_property(_ghost, "modulate:a", 0.0, 0.15)
        tween.finished.connect(func():
            _ghost.queue_free()
            _ghost = null
        )
    # 不 queue_free，留在原位（但由 _sync_hand 刷新手牌后会自然消失）
```

---

## 五、实施顺序

| Phase | 内容 | 估算 |
|-------|------|------|
| 1 | 创建 MenuBackground 场景 + BackgroundManager autoload + 复制视频文件 + 集成到各菜单 | 1h |
| 2 | 费用不足灰化 + 卡面重设计（颜色方案 + 排版） | 2h |
| 3 | 角色信息面板增强（类型标签、Buff 着色、统计行） | 2h |
| 4 | VFX 预设补充（shield/death/teleport/critical） | 2h |
| 5 | 屏幕震动 + 浮动数字改进 | 1h |
| 6 | 回合过渡动画 + 战斗结果界面美化 | 2h |
| 7 | 交互改进（右键反馈 / 空格结束 / ESC取消 / 镜头居中 / 目标高亮 / 弹回动画） | 3h |
| 8 | 主菜单 + 编队 + 卡组 + 设置界面美化 | 2h |

---

## 六、依赖项

- 动态背景素材：`C:\Users\10932\Documents\5652\DestinyDawn\bg` 中的 mp4 文件（Godot 4.3+ 原生支持 mp4 播放，低版本需转换为 .ogv）
- VFX 粒子效果使用 Godot 内置粒子系统，无需外部资源
- 屏幕震动使用 Camera2D 位置偏移
- 字体已存在：`Assets/Fonts/SourceHanSerifCN-Heavy-4.otf`
