class_name RulesPanelView
extends Control

## Static rules/help overlay. Before this, the game had NO in-game
## explanation of bet-to-lose, the 2 daily executions, or the win condition
## anywhere. Shown two ways (see GameView): hovering the small "?" button
## peeks it transiently, and pressing ESC pins it open as a real pause menu
## (freezes gameplay - see GameView._toggle_pause). Starts hidden; never
## auto-shown, since blocking the whole screen at launch was itself a
## complaint. process_mode is ALWAYS so its own close button stays clickable
## even while the tree is paused.

const INTRO_TEXT := "You are a lifer betting your sentence in a game of Texas Hold'em.

GOAL: get your sentence down to 0 years before day 7 ends, without being executed.

BET-TO-LOSE: chips are years of your sentence. Win a hand and your own bet is ERASED from your sentence. Lose (or fold) and a quarter of your bet gets ADDED instead. Winning big pots is the only way your time actually goes down - playing it safe just lets it creep up.

CHIP UNITS: the number on a chip is shown in a different unit each day (seconds, minutes, hours... up to years by day 7) purely for flavor - your actual sentence is always tracked in years underneath, shown with a live seconds-equivalent next to it."

const OUTRO_TEXT := "Survive all 7 days AND reach 0 years to walk free."

signal closed

var close_button: Button
var _dim: ColorRect
var _panel: Panel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.85)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.z_index = 100
	add_child(_dim)

	_panel = Panel.new()
	_panel.z_index = 101
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.98)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.55, 0.25)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(outer_vbox)

	var title := Label.new()
	title.text = "PRISON POKER - HOW IT WORKS"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = _build_rules_text()
	scroll.add_child(body)

	close_button = Button.new()
	close_button.text = "GOT IT"
	close_button.custom_minimum_size = Vector2(160, 46)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	outer_vbox.add_child(close_button)

	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")

	visible = false


func _layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0 or vp.y <= 0:
		vp = Vector2(1152, 648)
	var panel_size := Vector2(clampf(vp.x * 0.7, 480, 900), clampf(vp.y * 0.8, 420, 760))
	_panel.size = panel_size
	_panel.position = (vp - panel_size) / 2.0


func _build_rules_text() -> String:
	var lines: Array[String] = [INTRO_TEXT, ""]
	lines.append("EXECUTIONS: at the end of every day, 2 of the 7 prisoners are executed:")
	lines.append("  - Whoever has the MOST years left, always.")
	lines.append("  - Whoever matches that day's random anti-quest (shown at the top of the screen). The full pool of possible anti-quests:")
	for quest: Quest in Quest.default_pool():
		lines.append("      * %s - %s" % [quest.display_name, quest.description])
	lines.append("")
	lines.append(OUTRO_TEXT)
	return "\n".join(lines)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()
