extends Node
# 本地持久化：用户设置、编队、卡组等（user://settings.cfg）
# 内存字段统一挂在 GlobalGameData，本类只负责 读/写 磁盘。

const SAVE_PATH = "user://settings.cfg"

# 节名 -> (配置文件键 -> GlobalGameData 字段名)
const FIELD_MAP: Dictionary = {
	"general": {
		"player_name": "player_name",
		"server_port": "server_port",
	},
	"audio": {
		"audio_volume_master": "audio_volume_master",
		"audio_volume_bgm": "audio_volume_bgm",
		"audio_volume_sfx": "audio_volume_sfx",
	},
	"ui": {
		"menu_background": "menu_background",
	},
	"game": {
		"selected_team": "selected_team",
		"selected_deck": "selected_deck",
	},
	"update": {
		"auto_update": "auto_update",
		"proxy_mode": "proxy_mode",
		"proxy_prefix": "proxy_prefix",
		"update_proxy_host": "update_proxy_host",
		"update_proxy_port": "update_proxy_port",
	},
}

func _ready():
	load_all()

# 从磁盘加载全部配置到 GlobalGameData（文件不存在或损坏时静默跳过，保留默认值）
func load_all():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for section in FIELD_MAP:
		var fields: Dictionary = FIELD_MAP[section]
		for key in fields:
			if cfg.has_section_key(section, key):
				GlobalGameData.set(fields[key], cfg.get_value(section, key))

# 将 GlobalGameData 当前值全部写入磁盘
func save_all() -> bool:
	var cfg = ConfigFile.new()
	for section in FIELD_MAP:
		var fields: Dictionary = FIELD_MAP[section]
		for key in fields:
			cfg.set_value(section, key, GlobalGameData.get(fields[key]))
	var err = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("[Save] 保存失败: %s" % SAVE_PATH)
		return false
	return true

# 调试用：打印当前保存文件实际路径
func get_save_path() -> String:
	return ProjectSettings.globalize_path(SAVE_PATH)
