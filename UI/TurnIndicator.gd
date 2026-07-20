extends Control

@onready var turn_label = $MarginContainer/VBoxContainer/TurnLabel
@onready var end_turn_button = $MarginContainer/VBoxContainer/EndTurnButton
@onready var main: Node2D = get_tree().current_scene

func _ready():
	hide()
	ButtonTheme.apply_menu(end_turn_button)
	ButtonTheme.set_font(end_turn_button, 20)
	end_turn_button.text = "结束阶段"
	end_turn_button.pressed.connect(_on_EndTurnButton_pressed)

func _is_my_turn() -> bool:
	var phase = GlobalGameData.current_turn_phase
	match phase:
		GlobalGameData.TurnPhase.PLAYER_TURN:
			return GlobalGameData.is_host_turn == GlobalGameData.is_host
		GlobalGameData.TurnPhase.ENEMY_TURN:
			return GlobalGameData.is_host_turn != GlobalGameData.is_host
	return false

func update_turn_display():
	var phase = GlobalGameData.current_turn_phase
	if phase == GlobalGameData.TurnPhase.GAME_OVER:
		turn_label.text = "游戏结束！"
		show()
		end_turn_button.hide()
	elif _is_my_turn():
		turn_label.text = "你的回合"
		show()
		end_turn_button.show()
		end_turn_button.disabled = false
	elif phase == GlobalGameData.TurnPhase.NONE or phase == GlobalGameData.TurnPhase.START_ROUND:
		hide()
	else:
		turn_label.text = "对方回合"
		show()
		end_turn_button.show()
		end_turn_button.disabled = true

func _on_EndTurnButton_pressed():
	main.unselect_character(null, true)
	if _is_my_turn():
		print("[Info] 结束当前阶段，进入下一阶段")
		main.rpc("advance_turn_phase")
	else:
		print("[Info] 不是你的回合")
