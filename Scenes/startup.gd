# startup.gd
extends Control

func _on_create_button_down():
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(1145) != OK:
		print("[Error] 服务器启动失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = true
	
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")

func _on_join_button_down():
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client("127.0.0.1", 1145) != OK:
		print("[Error] 连接失败")
		return
	multiplayer.multiplayer_peer = peer
	GlobalGameData.is_host = false
	
	get_tree().change_scene_to_file("res://Scenes/scene.tscn")
