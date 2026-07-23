extends Node

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

# 主菜单按钮样式（悬停/点击缩放动画，无背景色变化）
static func apply_menu(btn: Button):
	btn.resized.connect(_pivot_center.bind(btn))
	btn.mouse_entered.connect(_enter.bind(btn))
	btn.mouse_exited.connect(_exit.bind(btn))
	btn.button_down.connect(_down.bind(btn))
	btn.button_up.connect(_up.bind(btn))
	# 立即尝试设置轴心（若尺寸已确定）
	if btn.size.x > 0 and btn.size.y > 0:
		btn.pivot_offset = btn.size * 0.5

# 战斗内按钮样式（保留默认 Button padding，通过 modulate 实现禁用效果）
static func apply_battle(btn: Button):
	apply_menu(btn)

static func apply_glass_blue(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.4, 0.52, 0.45)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.5, 0.55, 0.65, 0.4)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	var hover = style.duplicate()
	hover.bg_color = Color(0.38, 0.46, 0.58, 0.55)
	var pressed = style.duplicate()
	pressed.bg_color = Color(0.28, 0.36, 0.48, 0.55)
	pressed.border_color = Color(0.6, 0.65, 0.8, 0.5)
	for state in ["normal", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

static func apply_glass_edit(le: LineEdit):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.32, 0.4, 0.52, 0.45)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.5, 0.55, 0.65, 0.4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	le.add_theme_stylebox_override("normal", style)
	le.add_theme_stylebox_override("focus", style)
	le.add_theme_stylebox_override("read_only", style)

static func set_font(btn: Button, size: int = 18):
	if not btn.has_theme_font_override("font"):
		btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", size)

# === 内部回调 ===

static func _pivot_center(btn):
	if btn.size.x > 0 and btn.size.y > 0:
		btn.pivot_offset = btn.size * 0.5

static func _enter(btn):
	if btn.disabled:
		return
	var t = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)

static func _exit(btn):
	if btn.disabled:
		return
	var t = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1, 1), 0.1)

static func _down(btn):
	if btn.disabled:
		return
	var t = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(0.97, 0.97), 0.05)

static func _up(btn):
	if btn.disabled:
		return
	var am = Engine.get_singleton("AudioManager")
	if am: am.play_sfx("click")
	var t = btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.05)
