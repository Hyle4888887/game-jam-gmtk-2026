class_name Deck
extends RefCounted

var cards: Array[Card] = []


func _init() -> void:
	build()


func build() -> void:
	cards.clear()
	for suit in range(4):
		for rank in range(2, 15):
			cards.append(Card.new(suit, rank))


## Fisher-Yates shuffle via the seeded RNGService so runs are reproducible.
func shuffle(rng_service) -> void:
	rng_service.shuffle(cards)


func draw() -> Card:
	return cards.pop_back()


func burn() -> Card:
	return cards.pop_back()


func remaining() -> int:
	return cards.size()
