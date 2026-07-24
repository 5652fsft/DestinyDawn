extends Node

var is_host = false
var is_ai_mode: bool = false

enum TurnPhase {
	NONE,
	START_ROUND,
	PLAYER_TURN,         # 先手方回合（移动+攻击合并）
	ENEMY_TURN,          # 后手方回合（移动+攻击合并）
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

# 烟雾系统：格子坐标 → 剩余回合数
var smoke_cells: Dictionary = {}
# 凯瑞根死亡标记
var karrigan_death_flag: bool = false
# 本回合出牌计数
var cards_played_this_turn: int = 0

const DEFAULT_TEAM: Array[String] = ["bronya", "seele", "elaina"]
const DEFAULT_DECK: Array[String] = [
	"card_fireball", "card_ice_shard", "card_heal", "card_small_heal",
	"card_shield", "card_strength", "card_weakness", "card_regen",
]

# Phase 6 — 主菜单配置
var selected_team: Array[String] = []    # 编队：角色ID列表
var selected_deck: Array[String] = []    # 卡组：卡牌ID列表
var player_name: String = "玩家"
var opponent_name: String = "对手"
var server_ip: String = "127.0.0.1"
var server_port: int = 1145
var pending_client_id: int = -1
var client_peer_id: int = 2

# 音效系统音量（0.0 ~ 1.0）
var audio_volume_master: float = 0.8
var audio_volume_bgm: float = 0.3
var audio_volume_sfx: float = 0.8

func load_defaults_if_empty():
	if selected_team.is_empty():
		selected_team = DEFAULT_TEAM.duplicate()
	if selected_deck.is_empty():
		selected_deck = DEFAULT_DECK.duplicate()

func reset_battle_state():
	current_turn_phase = TurnPhase.NONE
	turn_has_been_drawn = false
	is_host_turn = true
	host_characters.clear()
	client_characters.clear()
	character_move_used.clear()
	character_move_used_num = 0
	character_attack_used.clear()
	character_attack_used_num = 0
	smoke_cells.clear()
	karrigan_death_flag = false
	cards_played_this_turn = 0
	host_team.clear()
	client_team.clear()
	ai_deck.clear()
	battle_stats = {
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

# Phase 6 — 对战双方队伍（RPC 同步用）
var host_team: Array[String] = []
var client_team: Array[String] = []
var ai_deck: Array[String] = []

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

func get_char_label(c) -> String:
	if not c:
		return "?"
	var is_player_side = c.name.begins_with("Host") == is_host
	return ("玩家/" if is_player_side else "对手/") + c.character_name
