extends Node

# 单例背景管理器
static var instance: BackgroundSingleton = null

@onready var _background_instance: Node = null
var _in_battle: bool = false
var _last_background_path: String = ""

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
	# 确保在最底层，添加到场景树根节点
	get_tree().root.call_deferred("add_child", _background_instance)
	# 设置z_index为最低
	_background_instance.call_deferred("set", "z_index", -1000)

# 设置背景
func set_background(path: String):
	# 确保实例存在
	if instance != self:
		return
	
	if _background_instance:
		_background_instance.setup_background(path)
	else:
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

# 确保背景实例正确创建
func _ensure_background():
	if not _background_instance:
		_create_background_instance()
