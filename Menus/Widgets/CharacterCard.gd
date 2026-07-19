extends Panel

const FONT = preload("res://Assets/Fonts/SourceHanSerifCN-Heavy-4.otf")

var char_id: String = ""
var is_in_team: bool = false

signal selected(char_id: String)

func setup(id: String, data: Dictionary):
	char_id = id
	$NameLabel.text = data.name
	$HPLabel.text = "HP: %d" % data.hp
	$MoveLabel.text = "移动: %d" % data.move
	$ATKLabel.text = "攻击: %d" % data.atk
	$SkillLabel.text = "技�? %s" % data.skill
	for c in get_children():
		if c is Label:
			c.add_theme_font_override("font", FONT)
	# 加载角色图片
	var tex = load("res://Assets/Sprites/Characters/%s_Blue.png" % id)
	if tex and $Sprite:
		$Sprite.texture = tex

func set_team_status(in_team: bool):
	is_in_team = in_team
	$SelectButton.text = "已�? if in_team else "+加入"
	$SelectButton.disabled = in_team

func _on_select_pressed():
	if not is_in_team:
		selected.emit(char_id)
