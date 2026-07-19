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

# Phase 6 — 主菜单配置
var selected_team: Array[String] = []    # 编队：角色ID列表
var selected_deck: Array[String] = []    # 卡组：卡牌ID列表
var player_name: String = "玩家"

# Phase 6 — 对战双方队伍（RPC 同步用）
var host_team: Array[String] = []
var client_team: Array[String] = []

# Phase 6 — 战斗统计
var battle_stats: Dictionary = {
	host_damage_dealt = 0,
	host_healing_done = 0,
	host_cards_played = 0,
	host_kills = 0,
	client_damage_dealt = 0,
	client_healing_done = 0,
	client_cards_played = 0,
	client_kills = 0,
	turns_taken = 0,
}

# 角色出生点
var host_birth_point = [
	Vector2(-252, -37),   # cell (-3, 2)
	Vector2(-252, 404),   # cell (-1, 4)
	Vector2(252, 404),    # cell (3, 0)
]
var client_birth_point = [
	Vector2(756, -698),   # cell (2, -9)
	Vector2(1260, -698),  # cell (6, -13)
	Vector2(1260, -257),  # cell (8, -11)
]
