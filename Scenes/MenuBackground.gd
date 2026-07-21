extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var fallback: TextureRect = $Fallback

func _ready():
	add_to_group("menu_bg")
	# Ensure non-zero size (layout may not be ready in exported builds)
	var vp_size = get_viewport_rect().size
	video_player.size = vp_size
	fallback.size = vp_size
	apply_background(BackgroundManager.get_current_bg_path())

func _on_background_changed(id: String):
	apply_background(BackgroundManager.get_current_bg_path())

func apply_background(path: String):
	print("[MenuBG] apply_background path=", path)
	if path.is_empty():
		video_player.hide()
		fallback.show()
		return
	video_player.show()
	fallback.hide()
	var stream = _load_stream(path)
	if stream:
		video_player.stream = stream
		video_player.play()
		print("[MenuBG] stream=", str(stream), " is_playing=", video_player.is_playing(), " visible=", video_player.visible, " size=", video_player.size)
	else:
		print("[MenuBG] FAILED to load stream")
		video_player.hide()
		fallback.show()

static func _load_stream(path: String) -> VideoStreamTheora:
	if not FileAccess.file_exists(path):
		print("[MenuBG] file NOT found: ", path)
		return null
	print("[MenuBG] file exists: ", path)
	# Try load() first (works for res:// in PCK and absolute paths)
	var s = load(path)
	if s:
		print("[MenuBG] load() OK")
		return s
	# Fallback: create VideoStreamTheora and set file
	print("[MenuBG] load() returned null, trying VideoStreamTheora.new()")
	var stream = VideoStreamTheora.new()
	stream.file = path
	return stream

func _on_video_finished():
	video_player.play()
