extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var fallback: TextureRect = $Fallback

var _current_background_path: String = ""
var _is_ready: bool = false

func _ready():
	# 不在这里加载背景，等待显式调用
	_is_ready = true

func setup_background(path: String):
	print("[SingletonMenuBackground] setup_background called with: ", path)
	if not _is_ready:
		await ready
	
	if path.is_empty():
		print("[SingletonMenuBackground] Setting empty background")
		video_player.hide()
		fallback.show()
		_current_background_path = ""
		return
	
	# 如果已经是同一个背景，直接显示即可
	if _current_background_path == path:
		print("[SingletonMenuBackground] Same background, just showing")
		video_player.show()
		fallback.hide()
		return
	
	print("[SingletonMenuBackground] Loading new background: ", path)
	# 新背景，需要加载
	_current_background_path = path
	video_player.show()
	fallback.hide()
	var stream = _load_stream(path)
	if stream:
		video_player.stream = stream
		video_player.play()
		print("[SingletonMenuBackground] Background loaded and playing")
	else:
		print("[SingletonMenuBackground] Failed to load background")
		video_player.hide()
		fallback.show()

static func _load_stream(path: String) -> VideoStreamTheora:
	if not FileAccess.file_exists(path):
		return null
	# Try load() first (works for res:// in PCK and absolute paths)
	var s = load(path)
	if s:
		return s
	# Fallback: create VideoStreamTheora and set file
	var stream = VideoStreamTheora.new()
	stream.file = path
	return stream

func _on_video_finished():
	video_player.play()

# 获取当前背景路径
func get_current_background_path() -> String:
	return _current_background_path