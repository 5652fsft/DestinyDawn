extends Node

# 当前玩家是否为主机（单人模式/AI 默认为 true）
var is_host = false
var is_ai_mode: bool = false

enum TurnPhase {
	NONE,
	START_ROUND,
	PLAYER_TURN,         # 先手方回合（移动+攻击合并）
	ENEMY_TURN,          # 后手方回合（移动+攻击合并）
	GAME_OVER
}

# 当前回合阶段
var current_turn_phase: int = TurnPhase.NONE
# 本回合是否已抽牌
var turn_has_been_drawn: bool = false
var is_host_turn: bool = true
# 当前局双方角色列表
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

# 主菜单配置
var selected_team: Array[String] = []    # 编队：角色ID列表
var selected_deck: Array[String] = []    # 卡组：卡牌ID列表
var player_name: String = ""
var opponent_name: String = "对手"
var server_ip: String = "127.0.0.1"
var server_port: int = 1145
var pending_client_id: int = -1
var client_peer_id: int = 2

# 音效系统音量（0.0 ~ 1.0）
var audio_volume_master: float = 0.8
var audio_volume_bgm: float = 0.3
var audio_volume_sfx: float = 0.8

# 菜单背景（默认伊蕾娜，由 SaveManager 持久化）
var menu_background: String = "elaina"

# 自动更新设置（由 SaveManager 持久化）
var auto_update: bool = true
var proxy_mode: String = "ghproxy"  # direct / ghproxy / ghddlc / ghfast / zwy / ghproxy_mirror / custom，默认 gh-proxy.com 镜像加速
var proxy_prefix: String = ""
var update_proxy_host: String = ""  # HTTP 代理（如本地 Clash 127.0.0.1），可空
var update_proxy_port: int = 0

func load_defaults_if_empty():
	if selected_team.is_empty():
		selected_team = DEFAULT_TEAM.duplicate()
	if selected_deck.is_empty():
		selected_deck = DEFAULT_DECK.duplicate()

# 首次进入默认昵称：常见人名随机（可在设置中修改，改后本局生效）
const RANDOM_NICKNAMES: Array[String] = [
	"迈克尔", "科比", "乔治", "詹姆斯", "托马斯", "威廉", "罗伯特",
	"约瑟夫", "大卫", "理查德", "安德鲁", "丹尼尔", "克里斯", "奥利弗",
	"杰克", "亨利", "塞缪尔", "亚当", "本杰明", "埃里克",
]

func _ready():
	if player_name.is_empty():
		player_name = random_nickname()

# 从常见人名池随机取一个昵称（AI 对手取名 / 玩家默认名共用）
func random_nickname() -> String:
	return RANDOM_NICKNAMES[randi() % RANDOM_NICKNAMES.size()]

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
	battle_stats = DEFAULT_BATTLE_STATS.duplicate()

# 对战双方队伍（RPC 同步用）
var host_team: Array[String] = []
var client_team: Array[String] = []
var ai_deck: Array[String] = []

# 战斗统计默认值
const DEFAULT_BATTLE_STATS: Dictionary = {
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

# 战斗统计（每局重置）
var battle_stats: Dictionary = DEFAULT_BATTLE_STATS.duplicate()

# 角色出生点（通过 map_to_local 从格子坐标转换）
var host_birth_point = [
	Vector2(-252, -478),  # cell (-5, 0)
	Vector2(-315, -147),  # cell (-4, 2)
	Vector2(-252, 184),   # cell (-2, 3)
]
var client_birth_point = [
	Vector2(1134, -478),  # cell (6, -11)
	Vector2(1197, -147),  # cell (8, -10)
	Vector2(1134, 184),   # cell (9, -8)
]

func get_char_label(c, ai_suffix: bool = false) -> String:
	if not c:
		return "?"
	var is_player_side = c.name.begins_with("Host") == is_host
	var enemy = "AI/" if ai_suffix else (opponent_name + "/")
	return ((player_name + "/") if is_player_side else enemy) + c.character_name
