extends Node

# 触摸输入桥（Android 专用，Autoload）
# 职责：
#  1. 单指触摸 → 鼠标事件由引擎内置转换（emulate_mouse_from_touch=true）完成，
#     覆盖主界面与弹出子窗口（PopupMenu），桥不再重复注入点击/移动
#  2. 双指手势：捏合缩放 + 双指平移视角（调 camera.gd 的 touch_* 接口）
#  3. ScrollContainer 触摸拖动滚动（引擎不处理，需桥实现）
#  4. 提供刘海屏安全区计算（get_content_safe_insets）
# 守卫：仅在 android 平台激活；桌面端完全旁路，不影响现有体验。

var _active: bool = false
var _touches: Dictionary = {}      # 触点 index -> 最近位置（viewport 坐标）
var _primary_index: int = -1       # 当前担任"鼠标"的主触点
var _two_finger: bool = false
var _last_center: Vector2 = Vector2.ZERO
var _last_dist: float = 0.0

# 滚动状态（ScrollContainer 触摸拖动滚动，仅安卓）
var _scroll_container: ScrollContainer = null  # 当前拖动中的滚动容器
var _scrolling: bool = false                    # 已超过死区进入滚动
const _SCROLL_DEADZONE := 8.0                   # 拖动滚动死区（viewport 像素）

# 供其他脚本查询的触摸状态（悬停兜底预留）
static var touch_active: bool = false
static var last_touch_pos: Vector2 = Vector2.ZERO

func _ready():
	_active = OS.has_feature("android")
	if not _active:
		set_process_input(false)
		return
	# 单指触摸→鼠标由引擎内置转换（覆盖 PopupMenu 等子窗口）；
	# 桥仅补充引擎不做的双指手势与 ScrollContainer 拖动滚动
	Input.emulate_mouse_from_touch = true

func _input(event: InputEvent):
	if not _active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			last_touch_pos = event.position
			if _touches.size() == 1:
				_primary_index = event.index
				touch_active = true
				_try_begin_scroll(event.position)
			else:
				_two_finger = true
				_cancel_scroll()
				_start_two_finger()
		else:
			_touches.erase(event.index)
			if _two_finger:
				_two_finger = false
				if _touches.is_empty():
					_primary_index = -1
					touch_active = false
				else:
					_primary_index = _touches.keys()[0]
			elif event.index == _primary_index:
				_primary_index = -1
				touch_active = false
				if _scrolling:
					_end_scroll()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		var prev: Vector2 = _touches[event.index]
		_touches[event.index] = event.position
		last_touch_pos = event.position
		if _two_finger:
			_update_two_finger()
		elif event.index == _primary_index:
			if _scroll_container != null:
				var delta: Vector2 = event.position - prev
				if not _scrolling and delta.length() > _SCROLL_DEADZONE:
					_scrolling = true
					# 超过死区进入滚动：取消引擎已按下的鼠标点击，避免误触内容控件
					_send_button(MOUSE_BUTTON_LEFT, false, event.position)
				if _scrolling:
					_apply_scroll(delta)

# === 双指手势 ===

func _start_two_finger():
	var ps: Array = _touches.values()
	if ps.size() < 2:
		return
	_last_center = (ps[0] + ps[1]) * 0.5
	_last_dist = ps[0].distance_to(ps[1])

func _update_two_finger():
	var ps: Array = _touches.values()
	if ps.size() < 2:
		return
	var center = (ps[0] + ps[1]) * 0.5
	var dist = ps[0].distance_to(ps[1])
	if _last_dist > 0.0:
		get_tree().call_group("touch_camera", "touch_pan", center - _last_center)
		get_tree().call_group("touch_camera", "touch_zoom", dist / _last_dist, center)
	_last_center = center
	_last_dist = dist

# === 事件转换（仅滚动取消点击使用） ===

# viewport 坐标（触摸事件在 _input() 中已由 Godot 转换为此坐标系）→ window 坐标
# Input.parse_input_event 期望 window/屏幕坐标（注入后 Viewport 会再转回 viewport 给 GUI），
# 官方做法：get_viewport().get_screen_transform() * viewport_pos（get_screen_transform 不含相机变换）。
func _to_window(vp_pos: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return vp_pos
	return vp.get_screen_transform() * vp_pos

func _send_button(button: int, pressed: bool, pos: Vector2):
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	var win_pos := _to_window(pos)
	ev.position = win_pos
	ev.global_position = win_pos
	Input.parse_input_event(ev)

# === 滚动（ScrollContainer 触摸拖动） ===

# 按下时：若悬停控件（或其祖先）是 ScrollContainer，标记为该容器，准备拖动滚动
func _try_begin_scroll(pos: Vector2):
	_scroll_container = null
	_scrolling = false
	var vp := get_viewport()
	if vp == null:
		return
	var ctrl: Control = vp.gui_get_hovered_control()
	while ctrl != null:
		if ctrl is ScrollContainer:
			_scroll_container = ctrl
			return
		ctrl = ctrl.get_parent_control()

# 应用拖动滚动（自然滚动方向：手指上滑查看下方内容 -> scroll_vertical 增加）
func _apply_scroll(delta: Vector2):
	var sc := _scroll_container
	if sc == null:
		return
	if sc.scroll_vertical > 0 or sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_vertical = sc.scroll_vertical - int(delta.y)
	if sc.scroll_horizontal > 0 or sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_horizontal = sc.scroll_horizontal - int(delta.x)

# 结束滚动（手指抬起或双指介入）：清理状态，鼠标释放由引擎 emulation 负责
func _end_scroll():
	_scrolling = false
	_scroll_container = null

func _cancel_scroll():
	_scrolling = false
	_scroll_container = null

# === 安全区 ===

# 返回内容区域内被系统安全区（刘海/挖孔）覆盖的边距（x=left, y=top, z=right, w=bottom），单位：viewport 坐标
func get_content_safe_insets() -> Vector4:
	if not _active:
		return Vector4.ZERO
	var win := get_window()
	if win == null:
		return Vector4.ZERO
	var ws := win.size
	if ws.x <= 0 or ws.y <= 0:
		return Vector4.ZERO
	var vp_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	# canvas_items 拉伸：内容等比缩放并居中，四周可能有黑边
	var scale := minf(ws.x / vp_size.x, ws.y / vp_size.y)
	var content_rect := Rect2((Vector2(ws) - vp_size * scale) * 0.5, vp_size * scale)
	var safe := DisplayServer.get_display_safe_area()
	# 返回内容区被系统安全区（刘海/挖孔）覆盖的边距；黑边不影响（safe 通常=整个窗口）
	var left := maxf(0.0, safe.position.x - content_rect.position.x) / scale
	var top := maxf(0.0, safe.position.y - content_rect.position.y) / scale
	var right := maxf(0.0, content_rect.end.x - safe.end.x) / scale
	var bottom := maxf(0.0, content_rect.end.y - safe.end.y) / scale
	return Vector4(left, top, right, bottom)
