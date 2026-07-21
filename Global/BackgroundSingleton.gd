extends Node

# 单例背景管理器
static var instance: BackgroundSingleton = null

@onready var _background_instance: Node = null

func _ready():
	if instance == null:
		instance = self
		# 创建背景实例
		_create_background_instance()
	else:
		queue_free()

# 创建背景实例
func _create_background_instance():
	var bg_scene = preload("res://Global/SingletonMenuBackground.tscn")
	_background_instance = bg_scene.instantiate()
	_background_instance.add_to_group("singleton_bg")
	get_tree().root.add_child(_background_instance)
	_background_instance.z_index = -100  # 确保在最底层

# 设置背景
func set_background(path: String):
	# 确保实例存在
	if instance != self:
		return
	
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