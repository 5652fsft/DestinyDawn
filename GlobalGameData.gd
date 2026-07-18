extends Node

var is_host = false

enum TurnPhase {
	NONE,
	START_ROUND,        # 抽先手
	PLAYER_MOVE,        # 先手移动
	PLAYER_ATTACK,      # 先手攻击
	ENEMY_MOVE,         # 后手移动
	ENEMY_ATTACK,       # 后手攻击
	GAME_OVER
}

var current_turn_phase: int = TurnPhase.NONE
var turn_has_been_drawn:bool = false
var is_host_turn: bool = true  # true = Host 先手，false = Client 先手
var host_characters: Array = []
var client_characters: Array = []

# 角色行动状态（每回合重置）
var character_move_used: Dictionary = {}  # key: character.name, value: bool
var character_move_used_num: int = 0
var character_attack_used: Dictionary = {}
var character_attack_used_num: int = 0

# 角色出生点
var host_birth_point = [
	Vector2(0, 0),
	Vector2(200, 100),
	Vector2(0, 200)
]
var client_birth_point = [
	Vector2(600, 0),
	Vector2(400, 100),
	Vector2(600, 200)
]
