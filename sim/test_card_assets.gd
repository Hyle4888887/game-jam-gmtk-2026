extends SceneTree

# Headless check that Card.texture_path()/has_face_art() correctly reflect
# the current (2026-07-26) state of the pulled art pack: every suit/rank now
# has real face art except "2 of Heart", whose source file is misspelled
# "2Hearth.png" instead of "2Heart.png" (see asset/Cards/Heart/) - once
# that's renamed/replaced, update this test's last assertion too. This is a
# data check, not GameManager-dependent, so plain --script mode is fine here.
# Run via:
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
	_check(ace_heart.has_face_art(), "AceHeart has face art")
	_check(ace_heart.texture_path() == "res://asset/Cards/Heart/AceHeart.png", "AceHeart texture_path resolves to the real file")

	var two_heart := Card.new(Card.Suit.HEART, 2)
	_check(not two_heart.has_face_art(), "2 of Heart currently has no face art (source file is misspelled 2Hearth.png)")

	var ten_diamond := Card.new(Card.Suit.DIAMOND, 10)
	_check(ten_diamond.has_face_art(), "10Diamond has face art (.jpg extension)")

	var ace_diamond := Card.new(Card.Suit.DIAMOND, 14)
	_check(ace_diamond.has_face_art(), "AceDiamond has face art")

	var any_spade := Card.new(Card.Suit.SPADE, 5)
	_check(any_spade.has_face_art(), "Spade suit now has face art")

	var any_clover := Card.new(Card.Suit.CLOVER, 5)
	_check(any_clover.has_face_art(), "Clover suit now has face art")

	_check(ResourceLoader.exists(Card.DEFAULT_BACK_TEXTURE), "DEFAULT_BACK_TEXTURE points at a real file")

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		quit(1)
	else:
		print("PASSED: Card texture mapping matches current art pack state")
		quit(0)
