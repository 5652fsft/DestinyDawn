extends Control

func _ready():
	GlobalGameData.load_defaults_if_empty()
	var buttons = [$VBoxContainer/TeamButton, $VBoxContainer/DeckButton, $VBoxContainer/HostButton, $VBoxContainer/JoinButton, $VBoxContainer/AIBattleButton, $VBoxContainer/GuideButton, $VBoxContainer/SettingsButton, $VBoxContainer/QuitButton]
	for btn in buttons:
		ButtonTheme.apply_menu(btn)
		ButtonTheme.set_font(btn, 20)
	_update_status()

func _update_status():
	$VBoxContainer/TeamButton.text = "编队管理"
	$VBoxContainer/DeckButton.text = "卡组构筑"

func _on_team_pressed():
	get_tree().change_scene_to_file("res://Menus/TeamFormation.tscn")

func _on_deck_pressed():
	get_tree().change_scene_to_file("res://Menus/DeckBuilder.tscn")

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(1145) != OK:
		print("[Error] 服务器启动失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = true
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_join_pressed():
	var ip = GlobalGameData.server_ip
	if ip.is_empty():
		ip = "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, 1145) != OK:
		print("[Error] 连接失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = false
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://Menus/SettingsScene.tscn")

func _on_ai_battle_pressed():
	GlobalGameData.load_defaults_if_empty()
	GlobalGameData.is_host = true
	GlobalGameData.is_ai_mode = true
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_guide_pressed():
	var text = ""
	var file = FileAccess.open("res://README.md", FileAccess.READ)
	if file:
		text = file.get_as_text()
		file.close()
	else:
		text = "游戏指南文件未找到。\n请访问 GitHub 仓库查看最新指南：\nhttps://github.com/5652fsft/DestinyDawn"
	# 简单 Markdown → BBCode 转换
	text = _md_to_bbcode(text)
	$GuideDialog/GuideText.bbcode_enabled = true
	$GuideDialog/GuideText.text = text
	$GuideDialog.popup_centered()

# 简单的 Markdown → BBCode 转换（覆盖常用元素）
func _md_to_bbcode(t: String) -> String:
	var lines = t.split("\n")
	for i in range(lines.size()):
		var line = lines[i]
		# 标题行
		if line.begins_with("##"):
			line = line.trim_prefix("#").trim_prefix("#").trim_prefix(" ").trim_prefix("#").trim_prefix(" ")
			line = "[b][u]%s[/u][/b]" % line
		# 加粗段落
		elif line.begins_with("**") and line.ends_with("**"):
			line = "[b]%s[/b]" % line.trim_prefix("**").trim_suffix("**")
		# 列表项
		elif line.begins_with("- "):
			line = "  •  %s" % line.trim_prefix("- ")
		# 表格行
		elif line.begins_with("|"):
			line = line.replace("|", "  ")
		# 分隔线
		elif line.begins_with("---"):
			line = "─" * 30
		# 行内 **text** 转 [b]text[/b]
		var bold_start = line.find("**")
		if bold_start >= 0:
			var bold_end = line.find("**", bold_start + 2)
			if bold_end >= 0:
				line = line.left(bold_start) + "[b]" + line.substr(bold_start + 2, bold_end - bold_start - 2) + "[/b]" + line.substr(bold_end + 2)
		lines[i] = line
	return "\n".join(lines)

func _on_quit_pressed():
	get_tree().quit()
