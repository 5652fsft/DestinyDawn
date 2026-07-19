extends Node

var player_decks: Dictionary = {}   # player_id -> Array[String] (card IDs, draw pile)
var player_hands: Dictionary = {}   # player_id -> Array[String] (card IDs)
var player_discards: Dictionary = {} # player_id -> Array[String] (card IDs)
var hand_limit: int = 5
var initial_draw: int = 3
var draw_per_turn: int = 1

func init_player(player_id: int, deck_card_ids: Array[String]):
	var shuffled: Array[String] = deck_card_ids.duplicate()
	shuffled.shuffle()
	player_decks[player_id] = shuffled
	player_hands[player_id] = [] as Array[String]
	player_discards[player_id] = [] as Array[String]
	print("[Deck] init_player p%d: deck=%d cards" % [player_id, shuffled.size()])

@rpc("authority", "call_local", "reliable")
func draw_cards(player_id: int, count: int) -> Array[String]:
	var drawn: Array[String] = []
	if not player_decks.has(player_id) or not player_hands.has(player_id):
		print("[Deck] draw_cards FAIL: no deck/hand for player %d" % player_id)
		return drawn
	var deck: Array[String] = []
	deck.assign(player_decks[player_id])
	var hand: Array[String] = []
	hand.assign(player_hands[player_id])
	print("[Deck] draw_cards p%d: deck=%d hand=%d drawing=%d" % [player_id, deck.size(), hand.size(), count])

	for _i in range(count):
		if deck.is_empty():
			_recycle_discard(player_id)
			deck.assign(player_decks.get(player_id, [] as Array[String]))
		if deck.is_empty():
			print("[Deck] draw_cards p%d: deck empty after recycle" % player_id)
			break
		if hand.size() >= hand_limit:
			print("[Deck] draw_cards p%d: hand full (%d)" % [player_id, hand_limit])
			break

		var card_id: String = deck.pop_front()
		hand.append(card_id)
		drawn.append(card_id)

	player_decks[player_id] = deck
	player_hands[player_id] = hand
	print("[Deck] draw_cards p%d done: drawn=%d deck=%d hand=%d" % [player_id, drawn.size(), deck.size(), hand.size()])
	return drawn

@rpc("authority", "call_local", "reliable")
func play_card(player_id: int, card_id: String) -> bool:
	if not player_hands.has(player_id) or not player_decks.has(player_id):
		print("[Deck] play_card FAIL: no hand/deck for p%d" % player_id)
		return false
	var hand: Array[String] = []
	hand.assign(player_hands[player_id])
	if card_id not in hand:
		print("[Deck] play_card FAIL: card %s not in hand for p%d (hand=%s)" % [card_id, player_id, str(hand)])
		return false
	hand.erase(card_id)
	player_hands[player_id] = hand
	var deck: Array[String] = []
	deck.assign(player_decks[player_id])
	deck.append(card_id)
	player_decks[player_id] = deck
	print("[Deck] play_card p%d: %s → deck:%d hand:%d" % [player_id, card_id, deck.size(), hand.size()])
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
