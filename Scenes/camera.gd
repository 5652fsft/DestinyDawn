extends Camera2D

var scaleNum : float = 1
var isDrag = false
var startMousePosition = Vector2.ZERO
var startCameraPosition = Vector2.ZERO


func _ready() -> void:
	self.zoom = Vector2(scaleNum, scaleNum)
	make_current()

func _input(event: InputEvent) -> void:
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
				startCameraPosition = self.position
			else:
				isDrag = false
				startMousePosition = Vector2.ZERO
	if isDrag and startMousePosition != Vector2.ZERO:
		var offset = startMousePosition - event.position
		self.position = startCameraPosition + offset * scaleNum ** 0.5
			

func _process(delta: float) -> void:
	self.zoom = lerp(self.zoom, Vector2(scaleNum, scaleNum), 8 * delta)
