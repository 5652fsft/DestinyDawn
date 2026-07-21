extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var fallback: TextureRect = $Fallback

func _ready():
	add_to_group("menu_bg")
	apply_background(BackgroundManager.get_current_bg_path())

func _on_background_changed(id: String):
	apply_background(BackgroundManager.get_current_bg_path())

func apply_background(path: String):
	if path.is_empty():
		video_player.hide()
		fallback.show()
		return
	video_player.show()
	fallback.hide()
	var stream = load(path)
	if stream:
		video_player.stream = stream
		video_player.play()
	else:
		push_warning("MenuBackground: failed to load ", path)
		video_player.hide()
		fallback.show()

func _on_video_finished():
	video_player.play()
