extends Node

var player_decks: Dictionary = {}   # player_id -> Array[String] (card IDs, draw pile)
var player_hands: Dictionary = {}   # player_id -> Array[String] (card IDs)
var player_discards: Dictionary = {} # player_id -> Array[String] (card IDs)
var hand_limit: int = 5
var initial_draw: int = 3
var draw_per_turn: int = 1

func init_player(player_id: int, deck_card_ids: Array[String]):
	print("[Deck] 初始化玩家 pid=", player_id, " 卡牌=", deck_card_ids)
	var shuffled: Array[String] = deck_card_ids.duplicate()
	shuffled.shuffle()
	player_decks[player_id] = shuffled
	player_hands[player_id] = [] as Array[String]
	player_discards[player_id] = [] as Array[String]
	print("[Deck] 初始化完成，牌库大小=", player_decks.get(player_id, []).size())

@rpc("authority", "call_local", "reliable")
func draw_cards(player_id: int, count: int) -> Array[String]:
	var drawn: Array[String] = []
	print("[Deck] 抽牌 pid=", player_id, " 数量=", count, " 有牌库=", player_decks.has(player_id), " 有手牌=", player_hands.has(player_id))
	if not player_decks.has(player_id) or not player_hands.has(player_id):
		print("[Deck] 抽牌失败：玩家未初始化")
		return drawn
	var deck: Array[String] = []
	deck.assign(player_decks[player_id])
	var hand: Array[String] = []
	hand.assign(player_hands[player_id])

	for _i in range(count):
		if deck.is_empty():
			_recycle_discard(player_id)
			deck.assign(player_decks.get(player_id, [] as Array[String]))
		if deck.is_empty():
			break
		if hand.size() >= hand_limit:
			break

		var card_id: String = deck.pop_front()
		hand.append(card_id)
		drawn.append(card_id)

	player_decks[player_id] = deck
	player_hands[player_id] = hand

	return drawn

@rpc("authority", "call_local", "reliable")
func play_card(player_id: int, card_id: String) -> bool:
	if not player_hands.has(player_id) or not player_decks.has(player_id):
		return false
	var hand: Array[String] = []
	hand.assign(player_hands[player_id])
	if card_id not in hand:
		return false
	hand.erase(card_id)
	player_hands[player_id] = hand
	var deck: Array[String] = []
	deck.assign(player_decks[player_id])
	deck.append(card_id)
	player_decks[player_id] = deck
	return true

func get_hand(player_id: int) -> Array[String]:
	if not player_hands.has(player_id):
		return [] as Array[String]
	var result: Array[String] = []
	result.assign(player_hands[player_id])
	return result

func get_deck_count(player_id: int) -> int:
	if not player_decks.has(player_id):
		return 0
	return player_decks[player_id].size()

func get_discard_count(player_id: int) -> int:
	if not player_discards.has(player_id):
		return 0
	return player_discards[player_id].size()

func _recycle_discard(player_id: int):
	if not player_decks.has(player_id) or not player_discards.has(player_id):
		return
	var deck = player_decks[player_id]
	var discard = player_discards[player_id]
	if discard.is_empty():
		return
	deck.append_array(discard)
	discard.clear()
	deck.shuffle()

func init_initial_draw(player_id: int):
	draw_cards(player_id, initial_draw)

# 抽取指定类型的增益效果牌（BUFF/HEAL/SHIELD），受手牌上限约束，牌堆不足时回收弃牌堆
@rpc("authority", "call_local", "reliable")
func draw_beneficial_cards(player_id: int, count: int) -> Array[String]:
	var drawn: Array[String] = []
	if not player_decks.has(player_id) or not player_hands.has(player_id):
		return drawn
	var deck: Array[String] = []
	deck.assign(player_decks[player_id])
	var hand: Array[String] = []
	hand.assign(player_hands[player_id])

	for _i in range(count):
		if hand.size() >= hand_limit:
			break
		var idx = _find_beneficial_index(deck)
		if idx < 0:
			_recycle_discard(player_id)
			deck.clear()
			deck.assign(player_decks.get(player_id, [] as Array[String]))
			idx = _find_beneficial_index(deck)
		if idx < 0:
			break
		var card_id: String = deck[idx]
		deck.remove_at(idx)
		hand.append(card_id)
		drawn.append(card_id)

	player_decks[player_id] = deck
	player_hands[player_id] = hand
	return drawn

static func is_beneficial_card(card_id: String) -> bool:
	var card = CardDatabase.get_card(card_id)
	if not card:
		return false
	return card.card_type == CardData.CardType.BUFF \
		or card.card_type == CardData.CardType.HEAL \
		or card.card_type == CardData.CardType.SHIELD

func _find_beneficial_index(deck: Array[String]) -> int:
	for i in range(deck.size()):
		if is_beneficial_card(deck[i]):
			return i
	return -1
