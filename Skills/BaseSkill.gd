class_name BaseSkill
extends Resource

enum SkillTarget { NONE, SELF, ALLY_SINGLE, ENEMY_SINGLE, CELL }

@export var skill_name: String = ""
@export var description: String = ""
@export var cooldown: int = 0  # 最大冷却
var current_cooldown: int = 0  # 当前冷却（0=可释放）
@export var target_type: SkillTarget = SkillTarget.NONE
@export var skill_range: int = 0  # 0 = 无限制, >0 = 最大格数
@export var is_passive: bool = false
