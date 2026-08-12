# 创建 UI / 场景 / 按钮 — 规范

## 主题系统

颜色和样式常量集中在 `UI/CardTheme.gd`（卡牌常量）和 `Global/ButtonTheme.gd`（按钮主题），其他 UI 文件引用这些常量。

### 字体

统一使用 `res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf`。引用方式：

```gdscript
var font = load("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
label.add_theme_font_override("font", font)
```

字号参考：主标题 28–32，卡牌名 15，描述 9，小标签 16，数值 22。实际以 `ButtonTheme.set_font()` 调用为准。

### 按钮

所有按钮使用 `ButtonTheme` 单例的 `apply_menu()` / `apply_battle()` 方法设置外观，按钮预设样式在 `Global/ButtonTheme.gd` 中定义。

### 面板 / 卡片

使用 `StyleBoxFlat` 在 `_ready()` 中创建，不在 `.tscn` 引用 `.theme` 资源：

```gdscript
var bg = StyleBoxFlat.new()
bg.bg_color = Color(0.08, 0.08, 0.12, 0.8)
bg.corner_radius_top_left = 12
add_theme_stylebox_override("panel", bg)
```

## 卡牌 UI（CardUIBase 体系）

### 架构

- `UI/CardUIBase.gd`（class_name，extends Panel）：**所有卡牌样式公共基类**，负责撞色背景、双底纹、外边框、费用圆、类型标签、分割线、卡图加载（含 placeholder）、hover 动画、灰化、选中态。
- `UI/CardUI.gd`（extends CardUIBase）：战斗手牌卡（140×200），持有 `CardData`，拖拽释放交互。
- `Menus/Widgets/DeckCardUI.gd`（extends CardUIBase）：卡组构筑卡（125×183），点击选卡交互。

**子类差异全部通过虚方法覆写**：`_card_type()` / `_card_size()` / `_split_y()` / `_hover_scale()` / `_z_index_hover()` / `_z_index_normal()` / `_selected_z()`。新增卡牌类型 UI 时优先继承基类，不要复制样式代码。

> **节点时序约束**：基类用 `@onready` 引用节点，`setup()` 必须在节点 `add_child` 入树**之后**调用（否则引用为 null）。`HandPanel`（先 add_child 后 setup）与 `DeckBuilder`（已按此修复）均为正确示例。

### 撞色背景

- 由 `Global/CardArtGenerator.gd` 程序化生成（`make_card_bg`），按类型缓存。
- 上半：类型色（`TYPE_GRAD_TOP`）→ 深灰（`GRAD_BOTTOM_DARK`）垂直渐变；下半：统一高级灰白（`BOTTOM_COLOR`）；`SPLIT_Y`（战斗卡 100 / 构筑卡 `DECK_SPLIT_Y` 84）处**硬分割**。
- Panel 的 stylebox 为 `StyleBoxTexture`（纹理含四角圆角），**不是** `StyleBoxFlat`。

### 节点绘制顺序约束

`BorderOverlay`（外边框）在 tscn 中**必须声明在节点列表最末**（Godot 同父节点按声明顺序绘制，后者在上）。否则全宽分割线 `NameDivider` 会盖断边框左右竖线，选中高亮框会被分割线切断。

### 分割线与底纹

- `NameDivider`：卡名上方 2px 类型色横线（与边框同源 `TYPE_BORDER`，不透明，左右顶格），区分深浅色区。
- `CardPattern`（卡面区 10,34→130,101）：白色低透明六边形网格，位于 `CardImage` 之下——**卡面图为透明背景 PNG 时网格透出**。
- `CardPatternBottom`（白底区）：深色网格（`PATTERN_DARK_COLOR`）。

### 文字

- 卡名：左对齐、深色（白底区可读），15px（构筑卡 12px）。
- 描述：9px（构筑卡 8px），`line_spacing = 2`，autowrap。

### 灰化

透明度恒为 1，仅降明度：`DISABLED_MODULATE = Color(0.6, 0.6, 0.65, 1)`。战斗卡 `set_affordable()` / 构筑卡 `set_in_deck_mode()` 均走 `set_disabled_visual()`。

### 选中态（青色高亮框）

`set_selected(true)`：外边框变青色（`SELECT_BORDER_COLOR`，3px），**无晕影**；`set_selected(false)` 完全恢复。规则：

- 高亮样式用 `_normal_border_style.duplicate()` 生成——**禁止直接修改正常样式对象**，否则取消选中后无法恢复（曾因此出现高亮残留 bug）。
- 选中时 `z_index` 提升至 `_selected_z()`（构筑卡 15 / 角色卡 15），hover 退出后保持，避免被相邻卡/分割线遮挡。
- 构筑界面：卡池中"已加入卡组"的卡显示高亮；出战卡组区不显示。
- 编队角色卡（`CharacterCard.gd`）同规则：`set_team_status()` → `_apply_selected_style()`，翻转背面后恢复选中样式。

### hover 动画

悬停放大 + 微调色：`HOVER_SCALE = 1.2`（战斗卡）/ `DECK_HOVER_SCALE = 1.04`（构筑卡、角色卡）。**滚动列表（ScrollContainer 必然裁切内容）内卡片悬停放大时**：

- 相邻遮挡：hover/选中时提升 z（20/15）解决。
- 容器边缘裁切：网格外包一层 `MarginContainer`（四边 10px 缓冲）吸收放大溢出量。

### 手牌 HandPanel

`UI/HandPanel.gd` 管理手牌，扇形布局排列 `CardUI` 实例，入场/调整位置带 0.3s tween。

## 战斗输入与取消操作

- **左键选取**：点击角色选中/取消，点击敌人可查看。
- **移动模式**：点击可达格子移动；点同按钮（"移动" ↔ "取消移动"）取消。
- **攻击模式**：点击敌人执行攻击；点击友方提示"目标选择无效"并退出攻击模式（保留选中）；点击自身/空白提示并取消选中；点同按钮（"普通攻击" ↔ "取消攻击"）取消。
- **技能瞄准**：点"使用技能"进入瞄准，点"取消使用技能"按钮退出；右键不提供取消。
- **取消操作统一由按钮承担，不再支持右键取消**。
