extends Node

func _init():
	print("[AudioManager] _init() called, name=" + name)

const SFX_DIR = "res://Assets/Audio/SFX/"
const BGM_DIR = "res://Assets/Audio/BGM/"
var _bus_master: int
var _bus_bgm: int
var _bus_sfx: int

var bgm_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer2D] = []
const POOL_SIZE: int = 6
const THROTTLE_MS: int = 50

var _sfx_cache: Dictionary = {}
var _bgm_cache: Dictionary = {}
var _last_play_time: Dictionary = {}

const BGM_TRACKS: Array[String] = ["battle1", "battle2", "battle3", "battle4", "battle5", "battle6"]
var _bgm_order: Array[int] = []
var _bgm_index: int = -1

func _ready():
	print("[AudioManager] _ready() called")
	_bus_master = AudioServer.get_bus_index("Master")
	_bus_bgm = max(AudioServer.get_bus_index("BGM"), 0)
	_bus_sfx = max(AudioServer.get_bus_index("SFX"), 0)
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPLayer"
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	bgm_player.finished.connect(_on_bgm_finished)
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer2D.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		sfx_pool.append(p)
	load_all_audio()

func load_all_audio():
	var sfx_list = [
		"click", "move", "attack", "heal",
		"shield", "death", "card_play", "turn_start", "victory", "defeat",
		"deck_select",
		"attack_sword", "attack_digital", "attack_magic", "attack_gun",
	]
	for name in sfx_list:
		_load_sfx(name)
	for name in BGM_TRACKS:
		_load_bgm(name)

func _load_sfx(name: String):
	var path = SFX_DIR + name + ".ogg"
	if ResourceLoader.exists(path):
		_sfx_cache[name] = ResourceLoader.load(path)
	else:
		_sfx_cache[name] = null
		push_warning("[AudioManager] SFX not found: " + path)

func _load_bgm(name: String):
	var path = BGM_DIR + name + ".mp3"
	if ResourceLoader.exists(path):
		_bgm_cache[name] = ResourceLoader.load(path)
	else:
		_bgm_cache[name] = null
		push_warning("[AudioManager] BGM not found: " + path)

func play_sfx(name: String, target: Node = null):
	if not _sfx_cache.has(name) or _sfx_cache[name] == null:
		return
	if _is_throttled(name):
		return
	_last_play_time[name] = Time.get_ticks_msec()
	var player = _get_idle_player()
	if not player:
		return
	player.stream = _sfx_cache[name]
	if target and is_instance_valid(target):
		player.global_position = target.global_position
	player.pitch_scale = 1.0 + randf_range(-0.03, 0.03)
	player.play()

func play_bgm(name: String):
	if not _bgm_cache.has(name) or _bgm_cache[name] == null:
		return
	_shuffle_and_play(name)

func play_bgm_random():
	if _bgm_cache.is_empty():
		return
	_bgm_order = range(BGM_TRACKS.size())
	_bgm_order.shuffle()
	_bgm_index = -1
	_play_next_bgm()

func _play_next_bgm():
	_bgm_index += 1
	if _bgm_index >= _bgm_order.size():
		_bgm_order.shuffle()
		_bgm_index = 0
	var track = BGM_TRACKS[_bgm_order[_bgm_index]]
	if not _bgm_cache.has(track) or _bgm_cache[track] == null:
		_play_next_bgm()
		return
	bgm_player.stream = _bgm_cache[track]
	bgm_player.play()

func _on_bgm_finished():
	_play_next_bgm()

func _shuffle_and_play(first: String):
	var idx = BGM_TRACKS.find(first)
	if idx == -1:
		idx = 0
	_bgm_order = range(BGM_TRACKS.size())
	_bgm_order.shuffle()
	_bgm_order.erase(idx)
	_bgm_order.insert(0, idx)
	_bgm_index = -1
	_play_next_bgm()

func stop_bgm(fade: float = 0.0):
	if fade > 0.0:
		var tween = create_tween()
		tween.tween_method(_fade_bgm_volume, bgm_player.volume_db, -80.0, fade)
		await tween.finished
	bgm_player.stop()
	bgm_player.volume_db = 0.0

func _fade_bgm_volume(v: float):
	bgm_player.volume_db = v

func _is_throttled(name: String) -> bool:
	if _last_play_time.has(name):
		var elapsed = Time.get_ticks_msec() - _last_play_time[name]
		if elapsed < THROTTLE_MS:
			return true
	return false

func _get_idle_player() -> AudioStreamPlayer2D:
	for p in sfx_pool:
		if not p.playing:
			return p
	return null

func set_master_volume(v: float):
	AudioServer.set_bus_volume_db(_bus_master, linear_to_db(v))
	GlobalGameData.audio_volume_master = v

func set_bgm_volume(v: float):
	AudioServer.set_bus_volume_db(_bus_bgm, linear_to_db(v))
	GlobalGameData.audio_volume_bgm = v

func set_sfx_volume(v: float):
	AudioServer.set_bus_volume_db(_bus_sfx, linear_to_db(v))
	GlobalGameData.audio_volume_sfx = v

func get_master_volume() -> float:
	return GlobalGameData.audio_volume_master

func get_bgm_volume() -> float:
	return GlobalGameData.audio_volume_bgm

func get_sfx_volume() -> float:
	return GlobalGameData.audio_volume_sfx

func _apply_saved_volumes():
	set_master_volume(GlobalGameData.audio_volume_master)
	set_bgm_volume(GlobalGameData.audio_volume_bgm)
	set_sfx_volume(GlobalGameData.audio_volume_sfx)
