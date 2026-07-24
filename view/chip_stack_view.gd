class_name ChipStackView
extends Control

## Chip visual using the real chip art (asset/other_pics/jetons.png): a
## 600x200 sheet, 6 columns (Sec/Min/H/D/M/Y, matching TimeUnits.Unit's
## column order exactly) x 2 rows (row 0 = single chip, row 1 = a stack).
## Shows whichever denomination TimeUnits.best_unit_for() picks for the
## given amount, so a small early-game bet shows small chips (seconds) and
## a late-game or big pot shows the big denomination (years) - same "best
## fit" logic already used for every other amount in the UI.

const CHIP_SHEET := preload("res://asset/other_pics/jetons.png")
const CHIP_CELL_SIZE := 100.0
const DISPLAY_SIZE := 32.0

var chip_icon: TextureRect
var amount_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(DISPLAY_SIZE + 8, DISPLAY_SIZE + 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	chip_icon = TextureRect.new()
	chip_icon.custom_minimum_size = Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
	chip_icon.position = Vector2(4, 0)
	chip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chip_icon.stretch_mode = TextureRect.STRETCH_SCALE
	chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip_icon)

	amount_label = Label.new()
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.position = Vector2(0, DISPLAY_SIZE + 2)
	amount_label.custom_minimum_size = Vector2(DISPLAY_SIZE + 8, 16)
	amount_label.add_theme_font_size_override("font_size", 11)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(amount_label)

	set_amount(0)


## `stacked` picks row 1 (a stack of chips) vs row 0 (a single chip) - used
## by TableView's flying-chip animations to show a single coin in motion
## rather than a whole stack flying across the table.
static func chip_texture(unit: TimeUnits.Unit, stacked: bool = false) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = CHIP_SHEET
	var row := 1 if stacked else 0
	atlas.region = Rect2(int(unit) * CHIP_CELL_SIZE, row * CHIP_CELL_SIZE, CHIP_CELL_SIZE, CHIP_CELL_SIZE)
	return atlas


func set_amount(years: float) -> void:
	if years <= 0:
		visible = false
		return
	visible = true
	chip_icon.texture = chip_texture(TimeUnits.best_unit_for(years), true)
	amount_label.text = TimeUnits.format_amount_best_unit(years)
