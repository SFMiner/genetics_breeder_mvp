extends PanelContainer
class_name ClutchPanel
## ClutchPanel - Shows a hatched clutch of 20 against the Punnett square's expected counts
##
## Educational Purpose: Compare expected vs observed counts, read a plain-language verdict
## about chance, then keep one hatchling. Built entirely in code from containers.

signal keep_requested(genotype: Dictionary)

const CLUTCH_SIZE: int = 20
const CHIPS_PER_ROW: int = 10
const MIN_BUTTON: Vector2 = Vector2(48, 48)
const PANEL_BG: Color = Color(0.10, 0.16, 0.24, 0.96)
const COLOR_TEXT: Color = Color(1, 1, 1, 1)
const BAR_BG: Color = Color(0.0, 0.0, 0.0, 0.35)
const CLASS_COLORS: Array[Color] = [
	Color(1.0, 0.60, 0.25, 1.0),
	Color(1.0, 0.85, 0.30, 1.0),
	Color(0.55, 0.75, 1.0, 1.0),
	Color(0.70, 0.90, 0.70, 1.0)
]
const VERDICT_FITS: String = "Close to what the Punnett square predicts. The small differences are just chance."
const VERDICT_OFF: String = "That's further from the prediction than chance usually makes. It happens about 1 time in 20. Try hatching again!"
const KEPT_TEXT: String = "Kept! Hatch again or pick new parents."
const PICK_TEXT: String = "Click one baby to keep it."


## Simple horizontal bar: draws a dark track and a colored fill of value/max_value.
class CountBar extends Control:
	var value: float = 0.0
	var max_value: float = 1.0
	var fill_color: Color = Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(120, 14)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BAR_BG)
		var ratio: float = clampf(value / maxf(max_value, 0.0001), 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), fill_color)


var _body: VBoxContainer = null
var _hint_label: Label = null
var _chips: Array[Button] = []


func _ready() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	visible = false


# === PUBLIC API ===

func reset() -> void:
	## Clear the clutch and hide the panel
	_chips.clear()
	if _body != null:
		remove_child(_body)
		_body.queue_free()
		_body = null
	_hint_label = null
	visible = false


func show_clutch(clutch: Array[Dictionary], exact: Dictionary) -> void:
	## Display a freshly hatched clutch against the exact (Punnett) ratios
	reset()
	var trait_ids: Array[String] = []
	for trait_id: String in GeneticsState.get_trait_ids():
		trait_ids.append(trait_id)
	var classes: Array[String] = PredictionLogic.phenotype_classes(GeneticsState.traits, trait_ids)

	# Observed counts keyed by class string
	var observed: Dictionary = {}
	var kid_classes: Array[String] = []
	for geno: Dictionary in clutch:
		var pheno: Dictionary = GeneticsState.calculate_phenotype(geno)
		var kind: String = PredictionLogic.class_of(pheno, trait_ids)
		kid_classes.append(kind)
		observed[kind] = int(observed.get(kind, 0)) + 1
	var fit: Dictionary = GenomeStats.chi_square(observed, exact)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	add_child(_body)
	_body.add_child(_make_label("Your hatched eggs", 20))

	# Header + one row per class: kind, expected (ratio x 20), observed, and a bar for each
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 1)
	_body.add_child(grid)
	var total: float = float(clutch.size())
	for i: int in range(classes.size()):
		var kind: String = classes[i]
		var color: Color = CLASS_COLORS[i % CLASS_COLORS.size()]
		var expected: float = float(exact.get(kind, 0.0)) * total
		var got: int = int(observed.get(kind, 0))
		var name_label: Label = _make_label(kind, 16)
		name_label.custom_minimum_size = Vector2(130, 0)
		name_label.add_theme_color_override("font_color", color)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(name_label)
		var count_box: VBoxContainer = VBoxContainer.new()
		count_box.add_theme_constant_override("separation", 0)
		count_box.custom_minimum_size = Vector2(96, 0)
		count_box.add_child(_make_label("Expected %.1f" % expected, 14))
		count_box.add_child(_make_label("Got %d" % got, 14))
		grid.add_child(count_box)
		var bar_box: VBoxContainer = VBoxContainer.new()
		bar_box.add_theme_constant_override("separation", 4)
		bar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar_box.add_child(_make_bar(expected, total, color.darkened(0.25)))
		bar_box.add_child(_make_bar(float(got), total, color))
		grid.add_child(bar_box)

	var verdict: Label = _make_label(VERDICT_FITS if bool(fit["fits"]) else VERDICT_OFF, 15)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.custom_minimum_size = Vector2(300, 0)
	_body.add_child(verdict)

	_hint_label = _make_label(PICK_TEXT, 15)
	_body.add_child(_hint_label)

	# 20 hatchling chips, colored by phenotype and labelled with the genotype
	var chip_grid: GridContainer = GridContainer.new()
	chip_grid.columns = CHIPS_PER_ROW
	chip_grid.add_theme_constant_override("h_separation", 3)
	chip_grid.add_theme_constant_override("v_separation", 3)
	_body.add_child(chip_grid)
	for i: int in range(clutch.size()):
		var kind_idx: int = maxi(classes.find(kid_classes[i]), 0)
		var chip: Button = Button.new()
		chip.text = _genotype_text(clutch[i], trait_ids)
		chip.custom_minimum_size = MIN_BUTTON
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.tooltip_text = kid_classes[i]
		chip.add_theme_font_size_override("font_size", 14)
		_style_chip(chip, CLASS_COLORS[kind_idx % CLASS_COLORS.size()])
		chip.pressed.connect(_on_chip_pressed.bind(clutch[i]))
		chip_grid.add_child(chip)
		_chips.append(chip)
	visible = true


func chips() -> Array[Button]:
	return _chips


func chip_count() -> int:
	return _chips.size()


func click_chip(index: int) -> void:
	## Keep the chip at index from code (used by tests / the screenshot gate)
	if index >= 0 and index < _chips.size():
		_chips[index].pressed.emit()


# === HELPERS ===

func _genotype_text(geno: Dictionary, trait_ids: Array[String]) -> String:
	## "Ff Ww": one pair per trait, separated by a space
	var parts: Array[String] = []
	for trait_id: String in trait_ids:
		var pair: Array = geno.get(trait_id, [])
		if pair.size() == 2:
			parts.append("%s%s" % [pair[0], pair[1]])
	return " ".join(parts)


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label


func _make_bar(value: float, max_value: float, color: Color) -> CountBar:
	var bar: CountBar = CountBar.new()
	bar.value = value
	bar.max_value = max_value
	bar.fill_color = color
	return bar


func _style_chip(chip: Button, color: Color) -> void:
	var states: Dictionary = {
		"normal": color,
		"hover": color.lightened(0.25),
		"pressed": color.darkened(0.2),
		"disabled": color.darkened(0.55)
	}
	for state: String in states.keys():
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = states[state]
		box.set_corner_radius_all(6)
		chip.add_theme_stylebox_override(state, box)
	var dark: Color = Color(0.08, 0.08, 0.10, 1.0)
	chip.add_theme_color_override("font_color", dark)
	chip.add_theme_color_override("font_hover_color", dark)
	chip.add_theme_color_override("font_pressed_color", dark)
	chip.add_theme_color_override("font_disabled_color", Color(0.2, 0.2, 0.22, 1.0))


func _on_chip_pressed(genotype: Dictionary) -> void:
	for chip: Button in _chips:
		chip.disabled = true
	if _hint_label != null:
		_hint_label.text = KEPT_TEXT
	keep_requested.emit(genotype)
