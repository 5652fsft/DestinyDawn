extends Camera2D

var scaleNum: float = 1
var isDrag: bool = false
var startMousePosition: Vector2 = Vector2.ZERO
var startCameraPosition: Vector2 = Vector2.ZERO
var _shake_tween: Tween = null
var _base_offset: Vector2 = Vector2.ZERO

func _ready():
	zoom = Vector2(scaleNum, scaleNum)
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
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and scaleNum > 0.5:
			scaleNum -= 0.1
			startMousePosition = Vector2.ZERO
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and scaleNum < 1.8:
			scaleNum += 0.1
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
	zoom = lerp(zoom, Vector2(scaleNum, scaleNum), 8 * delta)
