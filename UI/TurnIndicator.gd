extends Control

@onready var turn_label = $MarginContainer/VBoxContainer/TurnLabel
@onready var end_turn_button = $MarginContainer/VBoxContainer/EndTurnButton
@onready var transition = $TurnTransition
@onready var transition_mask = $TurnTransition/Mask
@onready var transition_label = $TurnTransition/TransitionLabel
@onready var main: Node = get_tree().current_scene

var _last_phase: int = -1

func _ready():
	hide()
	ButtonTheme.apply_menu(end_turn_button)
	ButtonTheme.set_font(end_turn_button, 20)
	end_turn_button.text = "结束回合"
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
	var round = GlobalGameData.battle_stats.get("turns_taken", 0)

	# 检测回合切换，播放过渡动画
	if phase != _last_phase and phase != GlobalGameData.TurnPhase.NONE and phase != GlobalGameData.TurnPhase.START_ROUND and phase != GlobalGameData.TurnPhase.GAME_OVER:
		_play_turn_transition()
	_last_phase = phase

	if phase == GlobalGameData.TurnPhase.GAME_OVER:
		turn_label.text = "游戏结束！"
		show()
		end_turn_button.hide()
	elif _is_my_turn():
		turn_label.text = "第 %d 回合 - 你的回合" % round
		show()
		end_turn_button.show()
		end_turn_button.disabled = false
	elif phase == GlobalGameData.TurnPhase.NONE or phase == GlobalGameData.TurnPhase.START_ROUND:
		hide()
	else:
		turn_label.text = "第 %d 回合 - 对方回合" % round
		show()
		end_turn_button.show()
		end_turn_button.disabled = true

func _play_turn_transition():
	var is_my = _is_my_turn()
	transition_label.text = "你的回合" if is_my else "敌方回合"

	# 过渡期间锁定棋盘输入（遮罩之外还需代码级锁：角色点击为每帧轮询物理查询）
	main.is_input_locked = true

	# 过渡期间隐藏手牌，结束后恢复
	var hand_panel = main.get_node_or_null("UI/HandPanel")
	var had_hand = hand_panel and hand_panel.visible and not ("_hand_hidden" in main and main._hand_hidden)
	if had_hand:
		hand_panel.hide()

	# 初始位置：屏幕右侧外
	transition_mask.position.x = 1280
	transition_label.modulate.a = 0.0
	transition.show()

	# 动画
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC)
	# 遮罩从右移入
	tw.tween_property(transition_mask, "position:x", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	# 文字淡入
	tw.parallel().tween_property(transition_label, "modulate:a", 1.0, 0.2).set_delay(0.1)
	# 停留
	tw.tween_interval(0.8)
	# 遮罩向左移出
	tw.tween_property(transition_mask, "position:x", -1280.0, 0.35).set_ease(Tween.EASE_IN)
	# 文字淡出
	tw.parallel().tween_property(transition_label, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		transition.hide()
		transition_mask.position.x = 1280
		# 仅当投降菜单未打开时解锁（ESC 可在过渡期间打开菜单）
		if not (main._surrender_dialog and main._surrender_dialog.visible):
			main.is_input_locked = false
		# 恢复手牌（仅当用户未主动用 F 隐藏）
		if hand_panel and had_hand and not ("_hand_hidden" in main and main._hand_hidden):
			hand_panel.show()
	)

func _on_EndTurnButton_pressed():
	main.unselect_character(null, true)
	if _is_my_turn():
		print("[Info] 结束当前回合")
		if main.multiplayer.has_multiplayer_peer():
			main.rpc("advance_turn_phase")
		else:
			main.advance_turn_phase()
	else:
		print("[Info] 不是你的回合")
