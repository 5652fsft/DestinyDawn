class_name BaseSkill
extends Resource

enum SkillTarget { NONE, SELF, ALLY_SINGLE, ENEMY_SINGLE }

@export var skill_name: String = ""
@export var description: String = ""
@export var cooldown: int = 0
@export var target_type: SkillTarget = SkillTarget.NONE
@export var is_passive: bool = false
