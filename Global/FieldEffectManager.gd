extends Node2D

var smoke_overlays: Array[Node] = []

func _ready():
	GlobalGameData.smoke_cells.clear()

# RPC — 放置烟雾（同步到所有客户端）
@rpc("authority", "call_local", "reliable")
func rpc_place_smoke(center_cell: Vector2i, radius: int, duration: int):
	var main = get_tree().current_scene if get_tree() else null
	var gl = main.get_node_or_null("Map/Ground") if main else null
	if not gl:
		return
	var cells = HexUtils.get_cells_in_radius(center_cell, radius, gl)
	for cell in cells:
		GlobalGameData.smoke_cells[cell] = duration
	_update_visuals(gl)

# 放置烟雾（联机走 RPC，单机直接执行）
func place_smoke(center_cell: Vector2i, radius: int, duration: int, grid_layer: TileMapLayer):
	var main = get_tree().current_scene if get_tree() else null
	if main and main.multiplayer.has_multiplayer_peer():
		rpc("rpc_place_smoke", center_cell, radius, duration)
	else:
		var cells = HexUtils.get_cells_in_radius(center_cell, radius, grid_layer)
		for cell in cells:
			GlobalGameData.smoke_cells[cell] = duration
		_update_visuals(grid_layer)

@rpc("authority", "call_local", "reliable")
func rpc_sync_smoke_cells(smoke_data: Dictionary):
	GlobalGameData.smoke_cells = smoke_data
	var main = get_tree().current_scene if get_tree() else null
	var gl = main.get_node_or_null("Map/Ground") if main else null
	if gl:
		_update_visuals(gl)

func is_in_smoke(cell: Vector2i) -> bool:
	return GlobalGameData.smoke_cells.has(cell)

# 烟雾回合递减，过期自动清除
func tick_smoke():
	for cell in GlobalGameData.smoke_cells.keys():
		GlobalGameData.smoke_cells[cell] -= 1
		if GlobalGameData.smoke_cells[cell] <= 0:
			GlobalGameData.smoke_cells.erase(cell)
	var main = get_tree().current_scene if get_tree() else null
	var gl = main.get_node_or_null("Map/Ground") if main else null
	if gl:
		_update_visuals(gl)

func clear_smoke():
	GlobalGameData.smoke_cells.clear()
	_clear_visuals()

func on_move_complete(character: Node, cell: Vector2i):
	if not is_in_smoke(cell):
		return
	GlobalGameData.character_move_used[character.name] = false
	print("[FieldEffect] %s 停留在烟雾中，本次移动不消耗次数" % GlobalGameData.get_char_label(character))

func _update_visuals(grid_layer: TileMapLayer):
	_clear_visuals()
	if not grid_layer:
		return
	for cell in GlobalGameData.smoke_cells.keys():
		var hex = _make_smoke_hex(cell, grid_layer)
		smoke_overlays.append(hex)
		grid_layer.add_child(hex)

func _clear_visuals():
	for h in smoke_overlays:
		if is_instance_valid(h):
			h.queue_free()
	smoke_overlays.clear()

func _make_smoke_hex(cell: Vector2i, grid_layer: TileMapLayer) -> Polygon2D:
	var hex = Polygon2D.new()
	var pts: PackedVector2Array = []
	for k in range(6):
		var a = deg_to_rad(60 * k - 30)
		pts.append(Vector2(cos(a) * HexUtils.HEX_RADIUS, sin(a) * HexUtils.HEX_RADIUS))
	hex.polygon = pts
	hex.color = Color(0.3, 0.3, 0.35, 0.55)
	hex.z_index = 50
	hex.position = grid_layer.map_to_local(cell)
	return hex