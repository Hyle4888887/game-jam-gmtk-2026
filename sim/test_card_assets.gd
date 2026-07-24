extends SceneTree

# Headless check that Card.texture_path()/has_face_art() correctly reflect
# the current (incomplete, 2026-07-24) state of the pulled art pack: Spade
# and Clover have no face art at all, Diamond is missing its Ace, and Heart
# is missing its Ace and 2. This is a data check, not GameManager-dependent,
# so plain --script mode is fine here. Run via:
#   godot --headless --path . --script res://sim/test_card_assets.gd

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _initialize() -> void:
	var king_heart := Card.new(Card.Suit.HEART, 13)
	_check(king_heart.has_face_art(), "KHeart has face art")
	_check(king_heart.texture_path() == "res://asset/Cards/Heart/KHeart.png", "KHeart texture_path resolves to the real file")

	var ace_heart := Card.new(Card.Suit.HEART, 14)
	_check(not ace_heart.has_face_art(), "AceHeart currently has no face art (deleted, not yet replaced)")
	_check(ace_heart.texture_path() == "", "AceHeart texture_path falls back to empty string")

	var two_heart := Card.new(Card.Suit.HEART, 2)
	_check(not two_heart.has_face_art(), "2 of Heart currently has no face art")

	var ten_diamond := Card.new(Card.Suit.DIAMOND, 10)
	_check(ten_diamond.has_face_art(), "10Diamond has face art (.jpg extension)")

	var ace_diamond := Card.new(Card.Suit.DIAMOND, 14)
	_check(not ace_diamond.has_face_art(), "AceDiamond currently has no face art")

	var any_spade := Card.new(Card.Suit.SPADE, 5)
	_check(not any_spade.has_face_art(), "Spade suit currently has zero face art")

	var any_clover := Card.new(Card.Suit.CLOVER, 5)
	_check(not any_clover.has_face_art(), "Clover suit currently has zero face art")

	_check(ResourceLoader.exists(Card.DEFAULT_BACK_TEXTURE), "DEFAULT_BACK_TEXTURE points at a real file")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		quit(1)
	else:
		print("PASSED: Card texture mapping matches current art pack state")
		quit(0)
