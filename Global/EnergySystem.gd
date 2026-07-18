extends Node

var player_energy: Dictionary = {}  # player_id -> energy
var max_energy: int = 10
var energy_per_turn: int = 2

func _ready():
	pass

func init_players(player_ids: Array[int]):
	for pid in player_ids:
		player_energy[pid] = 3

@rpc("authority", "call_local", "reliable")
func set_energy(player_id: int, value: int):
	player_energy[player_id] = clamp(value, 0, max_energy)

func get_energy(player_id: int) -> int:
	return player_energy.get(player_id, 0)

func can_afford(player_id: int, cost: int) -> bool:
	return player_energy.get(player_id, 0) >= cost

@rpc("authority", "call_local", "reliable")
func spend_energy(player_id: int, cost: int) -> bool:
	if not can_afford(player_id, cost):
		return false
	player_energy[player_id] -= cost
	return true

@rpc("authority", "call_local", "reliable")
func restore_energy(player_id: int):
	player_energy[player_id] = min(max_energy, player_energy[player_id] + energy_per_turn)
