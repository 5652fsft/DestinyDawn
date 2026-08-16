extends Camera2D

var scale_num: float = 0.4
var is_drag: bool = false
var start_mouse_position: Vector2 = Vector2.ZERO
var start_camera_position: Vector2 = Vector2.ZERO
var _shake_tween: Tween = null
var _base_offset: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO

func _ready():
	zoom = Vector2(scale_num, scale_num)
	offset = start_camera_position
	_base_offset = start_camera_position
	_target_position = start_camera_position
	make_current()
	add_to_group("touch_camera")

# === 触摸双指手势接口（由 TouchInputBridge 调用，桌面端不受影响） ===

# 双指平移：screen_delta 为屏幕位移（viewport 坐标），换算到世界位移
func touch_pan(screen_delta: Vector2):
	position -= screen_delta * scale_num ** 0.5
	_target_position = position

# 双指捏合缩放：factor 为距离变化倍数，center 为双指中心（viewport 坐标，聚焦点）
func touch_zoom(factor: float, center: Vector2 = Vector2.ZERO):
	if factor <= 0.0:
		return
	_zoom_at(center, clampf(scale_num * factor, 0.4, 1.0))

# 聚焦缩放：缩放前后保持 screen_pos 处的世界点位于同一屏幕位置
func _zoom_at(screen_pos: Vector2, new_scale: float):
	var vp_size := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	var viewport_center: Vector2 = vp_size * 0.5
	var anchor: Vector2 = position + (screen_pos - viewport_center) / maxf(zoom.x, 0.01)
	scale_num = new_scale
	_target_position = anchor - (screen_pos - viewport_center) / maxf(scale_num, 0.01)

func shake(intensity: float = 5.0, duration: float = 0.15):
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps = int(duration / 0.025)
	for i in steps:
		_shake_tween.tween_callback(func():
			offset = _base_offset + Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
		)
		_shake_tween.tween_interval(0.025)
	_shake_tween.tween_property(self, "offset", _base_offset, 0.05)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var ctrl = get_viewport().gui_get_hovered_control()
			while ctrl:
				if ctrl is ScrollContainer or ctrl is RichTextLabel:
					return
				ctrl = ctrl.get_parent()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and scale_num > 0.4:
			_zoom_at(event.position, scale_num - 0.05)
			start_mouse_position = Vector2.ZERO
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and scale_num < 1.0:
			_zoom_at(event.position, scale_num + 0.05)
			start_mouse_position = Vector2.ZERO
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				is_drag = true
				start_mouse_position = event.position
				start_camera_position = position
				_target_position = position
				var ai = get_node_or_null("../AIController")
				if ai and ai.has_method("stop_camera_tween"):
					ai.stop_camera_tween()
			else:
				is_drag = false
				start_mouse_position = Vector2.ZERO
	if is_drag and start_mouse_position != Vector2.ZERO:
		var offset_drag = start_mouse_position - event.position
		position = start_camera_position + offset_drag * scale_num ** 0.5
		_target_position = position

func _process(delta):
	zoom = lerp(zoom, Vector2(scale_num, scale_num), 8 * delta)
	position = lerp(position, _target_position, 8 * delta)
