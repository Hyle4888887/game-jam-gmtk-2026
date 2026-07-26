extends Node

# Headless check for the pause/rules-panel wiring:
#   - RulesPanelView starts hidden, open()/close() toggle it and emit closed
#   - GameView._toggle_pause() actually pauses the tree and shows/hides the
#     panel in lockstep, and toggling back cleanly restores both
# Doesn't test PacedActionSource's SceneTreeTimer pause-awareness directly -
# that relies on Godot's documented create_timer(time, process_always=false)
# contract rather than custom logic. Run via:
#   godot --headless --path . res://sim/test_pause.tscn

var failures := 0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok - %s" % label)
	else:
		failures += 1
		print("  FAIL - %s" % label)


func _ready() -> void:
	var panel: RulesPanelView = load("res://view/rules_panel_view.tscn").instantiate()
	add_child(panel)
	_check(not panel.visible, "RulesPanelView starts hidden (no auto-show)")

	panel.open()
	_check(panel.visible, "open() shows the panel")

	panel._layout()
	var vp := panel.get_viewport_rect().size
	# Mirrors _layout()'s own clamped formula rather than a raw "fraction of
	# vp" check - headless's dummy window is a 64x64 square, and with the
	# project's canvas_items/expand stretch config that distorts the visible
	# rect to a non-16:9 shape (1152x1152, not the real 1152x648 design
	# aspect), so a loose vp.y*0.7 bound doesn't hold under the height
	# clamp's real max (760) on every environment. A real monitor's landscape
	# aspect never hits this edge case.
	var expected_panel_size := Vector2(clampf(vp.x * 0.7, 480, 900), clampf(vp.y * 0.8, 420, 760))
	_check(panel._panel.size.is_equal_approx(expected_panel_size) and expected_panel_size.x > 400 and expected_panel_size.y > 300, "panel sizes as a real fraction of the viewport, not a tiny fixed box")
	_check(panel._dim.color.a >= 0.8, "dim overlay is strongly opaque, not barely-there")

	var rules_text := panel._build_rules_text()
	for quest: Quest in Quest.default_pool():
		_check(rules_text.find(quest.display_name) != -1, "rules text mentions the '%s' anti-quest" % quest.display_name)

	# GDScript lambdas capture outer locals by value snapshot, not by
	# reference - a plain bool assigned inside the closure wouldn't be
	# visible out here, so use a 1-element Array as a mutable box instead.
	var closed_fired := [false]
	panel.closed.connect(func(): closed_fired[0] = true)
	panel.close()
	_check(not panel.visible, "close() hides the panel")
	_check(closed_fired[0], "close() emits the closed signal")

	var gv: GameView = load("res://view/game_view.tscn").instantiate()
	gv.ai_turn_delay_seconds = 0.0
	add_child(gv)

	_check(not get_tree().paused, "tree is not paused when the game starts")

	gv._toggle_pause()
	_check(get_tree().paused, "_toggle_pause() pauses the tree")
	_check(gv.rules_panel.visible, "pausing opens the rules panel as a pause menu")

	gv._toggle_pause()
	_check(not get_tree().paused, "_toggle_pause() again unpauses")
	_check(not gv.rules_panel.visible, "unpausing closes the rules panel")

	# Unpausing via the panel's own close button (not just ESC again) must
	# also actually unpause - this is the rules_panel.closed -> GameManager
	# unpause wiring in GameView, not just the reverse _toggle_pause() path.
	gv._toggle_pause()
	_check(get_tree().paused, "paused again to test closing via the panel's own button")
	gv.rules_panel.close_button.pressed.emit()
	_check(not get_tree().paused, "clicking the panel's own close button while paused also unpauses")

	# Always leave the tree unpaused when this test exits, regardless of
	# outcome, so a failure here can't wedge the whole test run.
	get_tree().paused = false

	if failures > 0:
		print("FAILED: %d assertion(s) failed" % failures)
		get_tree().quit(1)
	else:
		print("PASSED: pause/rules-panel wiring behaves correctly")
		get_tree().quit(0)
