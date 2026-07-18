extends Node2D

var parent_character: CharacterBody2D
var faction_color: Color = Color.WHITE

@onready var hp_bar: ColorRect = $HPBar
@onready var hp_fill: ColorRect = $HPBar/HPFill
@onready var hp_label: Label = $HPLabel
@onready var shield_icon: ColorRect = $ShieldIcon
@onready var shield_label: Label = $ShieldLabel
@onready var faction_ring: ColorRect = $FactionRing

func _ready():
	parent_character = get_parent() as CharacterBody2D
	if not parent_character:
		queue_free()
		return
	_update_faction()
	refresh()

func _update_faction():
	var is_host = parent_character.name.begins_with("Host")
	faction_color = Color(0.3, 0.5, 1.0, 0.25) if is_host else Color(1.0, 0.3, 0.3, 0.25)
	if faction_ring:
		faction_ring.color = faction_color

func refresh():
	if not parent_character or not is_inside_tree():
		return
	_update_hp()
	_update_shield()
	_update_faction()

func _update_hp():
	var hp = parent_character.hp if "hp" in parent_character else 0
	var max_hp = parent_character.max_hp if "max_hp" in parent_character else 100
	var ratio = float(hp) / float(max_hp) if max_hp > 0 else 0
	var fill_width = clamp(ratio, 0, 1) * 86.0
	hp_fill.size.x = fill_width
	hp_fill.position.x = 1
	hp_label.text = "%d/%d" % [hp, max_hp]
	if ratio > 0.6:
		hp_fill.color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.3:
		hp_fill.color = Color(0.8, 0.8, 0.1)
	else:
		hp_fill.color = Color(0.8, 0.2, 0.1)

func _update_shield():
	var s = parent_character.shield if "shield" in parent_character else 0
	var has_shield = s > 0
	shield_icon.visible = has_shield
	shield_label.visible = has_shield
	if has_shield:
		shield_label.text = str(s)
