# 创建 UI / 场景 / 按钮 — 规范

## 主题系统

### 颜色常量 (`UI/CardTheme.gd`)

所有卡牌相关 UI 共享的样式常量：

```gdscript
const CARD_BG = Color(0.12, 0.12, 0.2, 1.0)
const CARD_BORDER_RADIUS = 8
const COST_BG = Color(0.2, 0.3, 0.5, 0.9)
const COST_RADIUS = 14
const HOVER_SCALE = 1.35
const HOVER_MODULATE = Color(1, 1, 0.85)
const HOVER_SHADOW_SIZE = 16
const HOVER_SHADOW_COLOR = Color(0, 0, 0, 0.5)
const HOVER_SHADOW_OFFSET = Vector2(4, 4)
const HOVER_TWEEN_SEC = 0.12
const DECK_HOVER_SCALE = 1.08
const DECK_BASE_SCALE = 0.95
const DISABLED_ALPHA = 0.6
```

引用方式：`const CardTheme = preload("res://UI/CardTheme.gd")`

### 字体

统一使用 `res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf`：

```gdscript
const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
# 对 Label:
label.add_theme_font_override("font", FONT)
label.add_theme_font_size_override("font_size", <size>)
# 对 Button:
button.add_theme_font_override("font", FONT)
# 在 tscn 中:
theme_override_fonts/font = ExtResource("...")
theme_override_font_sizes/font_size = <size>
```

### 面板背景条 (StyleBoxFlat 模式)

```gdscript
var bg = StyleBoxFlat.new()
bg.bg_color = Color(0.12, 0.12, 0.2, 0.8)    # 毛玻璃底色 + alpha
bg.corner_radius_top_left = 8
bg.corner_radius_top_right = 8
bg.corner_radius_bottom_left = 8
bg.corner_radius_bottom_right = 8
bg.border_color = Color(1, 1, 1, 0.08)        # 玻璃边缘高光
bg.border_width_top = 1
bg.border_width_right = 1
bg.border_width_bottom = 1
bg.border_width_left = 1
node.add_theme_stylebox_override("panel", bg)
```

---

## 按钮规范

### 主菜单按钮动效（参考 `Menus/MainMenu.gd`）

所有可交互按钮应统一使用以下模式：

```gdscript
func _setup_button(btn: Button):
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(_on_btn_enter.bind(btn))
	btn.mouse_exited.connect(_on_btn_exit.bind(btn))
	btn.button_down.connect(_on_btn_down.bind(btn))
	btn.button_up.connect(_on_btn_up.bind(btn))

func _on_btn_enter(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

func _on_btn_exit(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1, 1), 0.1)

func _on_btn_down(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.05)

func _on_btn_up(btn):
	var t = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.05)
```

### 按钮样式

字体引用 `ExtResource("2")` (SourceHanSerifCN)，字号 14~22，文本直接写入 tscn。

---

## 卡牌 UI 模式

### Battle Card (`UI/CardUI.tscn/.gd`) — 战斗中手牌

1. `extends Panel`
2. `_ready()` 中连接 `mouse_entered`/`mouse_exited`，设置 `pivot_offset`
3. 悬停：scale → 1.35, modulate → 黄色高亮
4. 点击：通过 `_gui_input` 捕获
5. 背景：`CardTheme.CARD_BG` + 圆角

### Deck Card (`Menus/Widgets/DeckCardUI.tscn/.gd`) — 构筑界面

1. `extends Panel`
2. 同上 hover/click 模式，但 scale → 1.08（`DECK_HOVER_SCALE`）
3. `set_in_deck_mode(bool)` 控制亮/灰状态
4. `signal clicked(cid: String)`

### Character Card (`Menus/Widgets/CharacterCard.tscn/.gd`) — 编队界面

1. `extends Panel`
2. 具有正面/背面翻转功能（点击右上角"i"按钮）
3. 正面：立绘 + 名称 + 属性 + 技能名 + 天赋名
4. 背面：ScrollContainer + 详细属性 + 技能/天赋描述
5. `signal clicked(cid: String)` — 点击卡片 toggle 入队/离队
6. `set_team_status(bool)` — 控制亮/灰

---

## 场景布局规范

### 菜单场景（MainMenu / TeamFormation / DeckBuilder）

```
Control (全屏, anchors_preset=15)
├ BgSprite (TextureRect)
│   full screen, z_index=-1, texture=menubg.jpg, expand_mode=1
├ Title / Labels (绝对定位)
├ Content (GridContainer / VBoxContainer / ScrollContainer)
└ 底部按钮 (BackButton / SaveButton)
```

- 所有子节点使用**绝对定位** (`layout_mode = 0`)
- 背景图 `menubg.jpg` 全屏铺满

### 创建新场景的步骤

1. 确定场景类型：`Control`（全屏菜单）/ `Node2D`（游戏内）/ `Panel`（UI 组件）
2. 添加背景（如需要）
3. 添加内容节点
4. 添加脚本，连接信号
5. 在需要跳转的地方使用 `get_tree().change_scene_to_file("res://path/to/scene.tscn")`

---

## 编队界面角色卡片与槽位规范

- 左侧 `ScrollContainer > GridContainer` 展示所有角色卡片（3 列）
- 右侧 `VBoxContainer` 动态生成 3 个队伍槽位
- 点击左侧卡片 toggle 入队/离队
- 点击右侧槽位移除角色
- 已入队卡片变灰（`DISABLED_ALPHA`），未入队高亮

---

## 命名规范

| 中文 | 代码/UI 中统一使用 |
|---|---|
| 生命值 | `生命值: %d` |
| 攻击力 | `攻击力: %d` |
| 移动 | `移动: %d` |
| 射程 | `射程: %d` |
| 主动技能 | 直接显示技能名（无前缀） |
| 被动/天赋 | `天赋·技能名` |
| 卡牌类型 | 攻击 / 治疗 / 增益 / 减益 / 位移 / 护盾 / 战术 |
