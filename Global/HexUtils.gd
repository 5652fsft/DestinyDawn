class_name HexUtils
extends Node

# 六边形邻居方向（奇数列偏移）
const HEX_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]

# 六边形高亮多边形半径
const HEX_RADIUS: float = 68.0
# 六边形格子中心间距
const HEX_SPACING: float = 130.0

# BFS 范围搜索，返回 {cell: 距离}，只算步数不计算地形消耗
static func get_cells_in_range(grid_layer: TileMapLayer, start_cell: Vector2i, max_range: int) -> Dictionary:
	var cells: Dictionary = {}
	var visited: Dictionary = {start_cell: 0}
	var queue = [start_cell]
	while queue.size() > 0:
		var cell = queue.pop_front()
		var cost = visited[cell]
		cells[cell] = cost
		if cost >= max_range:
			continue
		for d in HEX_DIRS:
			var next_cell = cell + d
			if not visited.has(next_cell) and grid_layer.get_cell_source_id(next_cell) != -1:
				visited[next_cell] = cost + 1
				queue.append(next_cell)
	return cells

# 圆形半径搜索，返回半径内所有有效格子（Array）
static func get_cells_in_radius(center: Vector2i, radius: int, grid_layer: TileMapLayer) -> Array:
	var result = [center]
	var visited: Dictionary = {center: 0}
	var queue = [center]
	while queue.size() > 0:
		var cell = queue.pop_front()
		var cost = visited[cell]
		if cost >= radius:
			continue
		for d in HEX_DIRS:
			var next_cell = cell + d
			if not visited.has(next_cell) and grid_layer.get_cell_source_id(next_cell) != -1:
				visited[next_cell] = cost + 1
				result.append(next_cell)
				queue.append(next_cell)
	return result

# AI 寻路：从 target 开始 BFS 寻找最近可用空格
static func find_nearest_free_cell(
	grid_layer: TileMapLayer, start: Vector2i, max_range: int,
	is_occupied: Callable, get_cost: Callable
) -> Vector2i:
	var visited: Dictionary = {start: 0}
	var queue = [start]
	while queue.size() > 0:
		var cur = queue.pop_front()
		var cost = visited[cur]
		if not is_occupied.call(cur):
			if get_cost.call(cur) > 0:
				return cur
		if cost >= max_range:
			continue
		for d in HEX_DIRS:
			var n = cur + d
			if visited.has(n):
				continue
			visited[n] = cost + 1
			queue.append(n)
	return Vector2i(-1, -1)

# 加权可达范围搜索（地形消耗 + 占用判定），返回 {cell: 最小消耗}
static func get_reachable_cells(
	grid_layer: TileMapLayer, start_cell: Vector2i, max_points: int,
	is_occupied: Callable, get_cost: Callable
) -> Dictionary:
	var result: Dictionary = { start_cell: 0 }
	var closed: Dictionary = {}
	var open_list = [{ "cell": start_cell, "cost": 0 }]
	while open_list.size() > 0:
		var current = open_list.pop_front()
		var cell: Vector2i = current.cell
		var total_cost: int = current.cost
		if closed.has(cell):
			continue
		closed[cell] = true
		for d in HEX_DIRS:
			var next_cell: Vector2i = cell + d
			if closed.has(next_cell):
				continue
			if is_occupied.call(next_cell):
				closed[next_cell] = true
				continue
			var cost = get_cost.call(next_cell)
			if cost <= 0:
				closed[next_cell] = true
				continue
			var new_cost = total_cost + cost
			if new_cost <= max_points:
				if not result.has(next_cell) or new_cost < result[next_cell]:
					result[next_cell] = new_cost
					_insert_sorted(open_list, { "cell": next_cell, "cost": new_cost })
	return result

# 开销优先插入（二分查找）
static func _insert_sorted(arr: Array, item: Dictionary) -> void:
	var lo = 0
	var hi = arr.size()
	while lo < hi:
		var mid = (lo + hi) / 2
		if arr[mid].cost < item.cost:
			lo = mid + 1
		else:
			hi = mid
	arr.insert(lo, item)
