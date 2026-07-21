extends Node

# 单例背景管理器
static var instance: BackgroundSingleton = null

@onready var _background_instance: Node = null

func _ready():
	print("[BackgroundSingleton] _ready called, current instance: ", instance)
	if instance == null:
		instance = self
		print("[BackgroundSingleton] Setting instance to: ", self)
		# 创建背景实例
		_create_background_instance()
	else:
		print("[BackgroundSingleton] Instance already exists, queueing free")
		queue_free()

# 创建背景实例
func _create_background_instance():
	print("[BackgroundSingleton] Creating background instance")
	var bg_scene = preload("res://Global/SingletonMenuBackground.tscn")
	_background_instance = bg_scene.instantiate()
	_background_instance.add_to_group("singleton_bg")
	# 确保在最底层，添加到场景树根节点
	get_tree().root.call_deferred("add_child", _background_instance)
	# 设置z_index为最低
	_background_instance.call_deferred("set", "z_index", -1000)
	print("[BackgroundSingleton] Background instance created: ", _background_instance)
	print("[BackgroundSingleton] Background parent: ", _background_instance.get_parent())

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
	return "VideoPlayer: visible=" + str(video_player.visible) + " playing=" + str(video_player.playing) + " size=" + str(video_player.size) + " Fallback: visible=" + str(fallback.visible)

# 确保背景实例正确创建
func _ensure_background():
	if not _background_instance:
		_create_background_instance()