# 创建 UI / 场景 / 按钮 — 规范

## 主题系统

颜色和样式常量集中在 `UI/CardTheme.gd`（卡牌常量）和 `Global/ButtonTheme.gd`（按钮主题），其他 UI 文件引用这些常量。

### 字体

统一使用 `res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf`。引用方式：

```gdscript
var font = load("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")
label.add_theme_font_override("font", font)
```

字号参考：主标题 28–32，卡牌名 24，描述 18，小标签 16，数值 22。

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

### 卡牌 UI

`UI/CardUI.gd` 实现卡牌显示，宽高比 ~3:4，能量徽章左上角，悬停放大 + 阴影增强，不可用时半透明。

### HandPanel

`UI/HandPanel.gd` 管理手牌，使用 `HFlowContainer` 自动换行排列 `CardUI` 实例。
