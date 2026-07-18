class_name BuffData extends Resource

enum BuffType {
	ATTACK_BUFF,
	ATTACK_DEBUFF,
	DEFENSE_BUFF,
	MOVE_DEBUFF,
	DAMAGE_OVER_TIME,
	HEAL_OVER_TIME,
	MARK,
}

enum Category {
	MAGIC,
	PHYSICAL,
	SPECIAL,
}

@export var id: String
@export var name: String
@export var type: BuffType
@export var category: Category
@export var is_harmful: bool
@export var max_stacks: int = 1
@export var has_tick: bool = false  # DOT/HOT
