extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var fallback: TextureRect = $Fallback

var _is_initializing: bool = true

func _ready():
	add_to_group("menu_bg")
	# Ensure non-zero size (layout may not be ready in exported builds)
	var vp_size = get_viewport_rect().size
	video_player.size = vp_size
	fallback.size = vp_size
	
	# 只在初始化时应用背景，避免重复加载
	apply_background(BackgroundManager.get_current_bg_path())
	_is_initializing = false

func _on_background_changed(id: String):
	# 如果正在初始化，避免重复调用
	if _is_initializing:
		return
	apply_background(BackgroundManager.get_current_bg_path())

func apply_background(path: String):
	if path.is_empty():
		video_player.hide()
		fallback.show()
		return
	
	# 检查是否已经有视频流且是同一个背景
	if video_player.stream and video_player.stream.resource_path == path:
		# 已经是同一个背景，直接显示即可，继续播放当前位置
		video_player.show()
		fallback.hide()
		return
	
	# 新背景，需要加载
	video_player.show()
	fallback.hide()
	var stream = _load_stream(path)
	if stream:
		video_player.stream = stream
		video_player.play()
	else:
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
