extends Node

const LOG_PATH: String = "user://logs/ai.log"

static func log(msg: String, category: String = "AI"):
	var timestamp = Time.get_time_string_from_system()
	var line = "[%s][%s] %s" % [timestamp, category, msg]
	print(line)
	_ensure_log_dir()
	_append_to_file(line)

static func _ensure_log_dir():
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("logs"):
		dir.make_dir("logs")

static func _append_to_file(line: String):
	var file = FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)
	if not file:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		return
	file.seek_end()
	file.store_line(line)
	file.close()

static func clear():
	_ensure_log_dir()
	var file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_line("")
		file.close()
	print("[AILogger] 日志文件已清空: %s" % LOG_PATH)

static func get_log_path() -> String:
	return ProjectSettings.globalize_path(LOG_PATH)
