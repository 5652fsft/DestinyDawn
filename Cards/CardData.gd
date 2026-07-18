class_name CardData
extends Resource

enum CardType { ATTACK, HEAL, BUFF, DEBUFF, DISPLACE, SHIELD, TACTICAL }
enum TargetType { NONE, SELF, ALLY_SINGLE, ENEMY_SINGLE, ALLY_ALL, ENEMY_ALL, CELL, ALL_CHARACTERS }
enum EffectType { DAMAGE, HEAL, BUFF_ATTACK, BUFF_DEFENSE, DEBUFF_ATTACK, DEBUFF_MOVE, SHIELD, TELEPORT, SWAP, EXTRA_MOVE, DRAW_CARD, CLEANSE }

@export var id: String = ""
@export var card_name: String = ""
@export var card_type: CardType = CardType.ATTACK
@export var cost: int = 1
@export var target_type: TargetType = TargetType.ENEMY_SINGLE
@export var description: String = ""
@export var effect_type: EffectType = EffectType.DAMAGE
@export var effect_value: int = 0
@export var effect_duration: int = 1
@export var icon_path: String = ""
