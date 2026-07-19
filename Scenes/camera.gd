extends Camera2D

var scaleNum: float = 0.4
var _zoom_target: float = 0.4
var _zoom_anchor: Vector2 = Vector2.ZERO
var isDrag: bool = false
var startMousePosition: Vector2 = Vector2.ZERO
var startCameraPosition: Vector2 = Vector2.ZERO
var _shake_tween: Tween = null
var _base_offset: Vector2 = Vector2.ZERO

func _ready():
	zoom = Vector2(scaleNum, scaleNum)
	_zoom_target = scaleNum
	_base_offset = offset
	make_current()

func shake(intensity: float = 5.0, duration: float = 0.15):
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var elapsed = 0.0
	while elapsed < duration:
		offset = _base_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		elapsed += 0.025
		_shake_tween.tween_interval(0.025)
	_shake_tween.tween_property(self, "offset", _base_offset, 0.05)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and _zoom_target > 0.4:
			_zoom_anchor = get_global_mouse_position()
			_zoom_target -= 0.05
			scaleNum = _zoom_target
			startMousePosition = Vector2.ZERO
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and _zoom_target < 1.0:
			_zoom_anchor = get_global_mouse_position()
			_zoom_target += 0.05
			scaleNum = _zoom_target
			startMousePosition = Vector2.ZERO
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				isDrag = true
				startMousePosition = event.position
				startCameraPosition = position
			else:
				isDrag = false
				startMousePosition = Vector2.ZERO
	if isDrag and startMousePosition != Vector2.ZERO:
		var offset_drag = startMousePosition - event.position
		position = startCameraPosition + offset_drag * scaleNum ** 0.5

func _process(delta):
	var prev_zoom = zoom
	zoom = lerp(zoom, Vector2(_zoom_target, _zoom_target), 8 * delta)
	if _zoom_anchor != Vector2.ZERO and prev_zoom != zoom:
		position += _zoom_anchor - get_global_mouse_position()
