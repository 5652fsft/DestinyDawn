extends Resource
class_name VideoCatalog

# This file exists only to force Godot's export system to include video files.
# Without explicit references, load("res://...ogv") returns null in exported builds.

const VIDEOS = {
	"bronya_seele": preload("res://Assets/Video/BronyaAndSeele1.ogv"),
	"elaina": preload("res://Assets/Video/Elaina1.ogv"),
}

static func get_stream(path: String) -> VideoStreamTheora:
	var fname = path.get_file()
	for id in VIDEOS:
		if VIDEOS[id].resource_path.get_file() == fname:
			return VIDEOS[id]
	return null
