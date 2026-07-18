extends Panel

@export var player_side: String = "Host"

@onready var player_name_label: Label = $VBoxContainer/PlayerName
@onready var faction_indicator: ColorRect = $VBoxContainer/FactionRow/FactionDot
@onready var energy_label: Label = $VBoxContainer/FactionRow/EnergyLabel
@onready var turn_highlight: ColorRect = $TurnHighlight

func _ready():
	var is_host_side = player_side == "Host"
	var name_text = "玩家1 (Host)" if is_host_side else "玩家2 (Client)"
	var color = Color(0.3, 0.5, 1.0, 0.8) if is_host_side else Color(1.0, 0.3, 0.3, 0.8)
	
	player_name_label.text = name_text
	faction_indicator.color = color

func refresh(is_my_turn: bool, energy: int = -1):
	turn_highlight.visible = is_my_turn
	if energy >= 0:
		energy_label.text = "能量: %d" % energy
