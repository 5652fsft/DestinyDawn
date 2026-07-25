# 创建 UI — 规范

## 主题系统

颜色和样式常量集中在 `UI/CardTheme.gd`（卡牌）和 `Global/ButtonTheme.gd`（按钮），其他 UI 文件引用这些常量。

### 字体

统一使用 `res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf`。引用方式：

```gdscript
var font = load("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
label.add_theme_font_override("font", font)
```

字体大小：主标题 28–32，卡牌名 24，描述 18，小标签 16，数值 22。

### 按钮

所有按钮使用 `ButtonTheme` 单例的 `apply_menu()` / `apply_small()` 方法：

```gdscript
ButtonTheme.apply_menu($MyButton)
ButtonTheme.set_font($MyButton, 22)     # 可选重设字号
```

按钮样式已预设在 `Global/ButtonTheme.gd` 中。

### 面板 / 卡片

使用 `StyleBoxFlat` 在 `_ready()` 中创建，不在 `.tscn` 中引用 `.theme` 资源：

```gdscript
var bg = StyleBoxFlat.new()
bg.bg_color = Color(0.08, 0.08, 0.12, 0.8)
bg.corner_radius_top_left = 12
add_theme_stylebox_override("panel", bg)
```

### 卡牌 UI

卡牌 UI 在 `UI/CardUI.gd` 中实现，参考现有卡牌布局：

- 卡牌宽高比 ~3:4
- 能量消耗圆形徽章在左上角
- 名称在顶部，描述在中间
- 悬停时放大 + 阴影增强
- 不可用时半透明（`modulate.a = 0.6`）

### HandPanel

手牌在 `UI/HandPanel.gd` 管理，使用 `HFlowContainer` 自动换行排列 `CardUI` 实例。
