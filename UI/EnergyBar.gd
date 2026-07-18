extends HBoxContainer

@onready var energy_label: Label = $EnergyLabel
@onready var max_label: Label = $MaxLabel

func update_display(current: int, max_val: int):
	energy_label.text = "能量: %d" % current
	max_label.text = "/ %d" % max_val
