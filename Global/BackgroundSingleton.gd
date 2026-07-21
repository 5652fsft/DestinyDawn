extends Node

# 单例背景管理器
static var instance: BackgroundSingleton = null

@onready var _background_instance: Node = null
var _in_battle: bool = false
var _last_background_path: String = ""

# 设置背景
func set_background(path: String):
	# 确保实例存在
	if instance != self:
		return
	
	print("[BackgroundSingleton] Setting background: ", path)
	print("[BackgroundSingleton] Background instance exists: ", _background_instance != null)
	if _background_instance:
		_background_instance.setup_background(path)
	else:
		print("[BackgroundSingleton] ERROR: No background instance found")
		# 尝试重新创建
		_create_background_instance()
		if _background_instance:
			_background_instance.setup_background(path)

# 进入战斗模式
func enter_battle():
	_in_battle = true
	_last_background_path = get_current_background_path()
	if _background_instance:
		_background_instance.hide_background()

# 退出战斗模式
func exit_battle():
	_in_battle = false
	if _background_instance:
		_background_instance.setup_background(_last_background_path)

# 隐藏背景（战斗专用）
func hide_background():
	if _background_instance:
		_background_instance.hide_background()

# 获取当前背景路径
func get_current_background_path() -> String:
	if _background_instance and _background_instance.has_method("get_current_background_path"):
		return _background_instance._current_background_path
	return ""

# 静态接口
static func setup(path: String):
	if instance:
		instance.set_background(path)

# 获取单例
static func get_singleton() -> BackgroundSingleton:
	return instance

# 获取背景实例状态
func get_background_status() -> String:
	if not _background_instance:
		return "No background instance"
	var video_player = _background_instance.get_node_or_null("VideoPlayer")
	var fallback = _background_instance.get_node_or_null("Fallback")
	if not video_player:
		return "No VideoPlayer"
	if not fallback:
		return "No Fallback"
	return "VideoPlayer: visible=" + str(video_player.visible) + " is_playing=" + str(video_player.is_playing()) + " size=" + str(video_player.size) + " Fallback: visible=" + str(fallback.visible)

# 确保背景实例正确创建
func _ensure_background():
	if not _background_instance:
		_create_background_instance()