extends PanelContainer
class_name PredictionPanel
## PredictionPanel - Students pick a fraction for every phenotype class BEFORE breeding
##
## Educational Purpose: Commit to a prediction from the Punnett square, then check it.
## Built entirely in code from containers (no positioned .tscn layout).
## Flow: setup(a, b) -> student picks fractions -> "Check my prediction" -> prediction_checked.

signal prediction_checked(all_right: bool)

const MIN_BUTTON: Vector2 = Vector2(48, 48)
const WIDTH_LEVEL_1: float = 340.0
const WIDTH_LEVEL_2: float = 556.0
const WIDTH_COMPACT: float = 290.0
const PANEL_BG: Color = Color(0.10, 0.16, 0.24, 0.96)
const BUTTON_NORMAL: Color = Color(0.22, 0.30, 0.42, 1.0)
const CHECK_NORMAL: Color = Color(0.15, 0.55, 0.30, 1.0)
const BUTTON_HOVER: Color = Color(0.30, 0.40, 0.55, 1.0)
const BUTTON_PICKED: Color = Color(1.0, 0.80, 0.25, 1.0)
const BUTTON_PICKED_TEXT: Color = Color(0.10, 0.10, 0.10, 1.0)
const COLOR_RIGHT: Color = Color(0.45, 1.0, 0.55, 1.0)
const COLOR_WRONG: Color = Color(1.0, 0.55, 0.50, 1.0)
const COLOR_TEXT: Color = Color(1, 1, 1, 1)
const MSG_HINT: String = "Pick one number for each kind. The total must be all."
const MSG_RIGHT: String = "You got it! Great predicting!"
const MSG_WRONG: String = "Look at the square: count the boxes for each kind."

## Parents for the cross currently being predicted
var parent_a_id: int = -1
var parent_b_id: int = -1

## class string -> {"value": int (16ths, 0 if none picked), "buttons": Array[Button], "label": Label, "result": Label}
var _rows: Dictionary = {}
var _classes: Array[String] = []
var _exact: Dictionary = {}
var _checked: bool = false

var _body: VBoxContainer = null
var _total_label: Label = null
var _score_label: Label = null
var _check_button: Button = null
var _message_label: Label = null
var _compact: bool = false


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

func setup(a_id: int, b_id: int) -> void:
	## Build the prediction rows for this cross and the current level, then show the panel
	parent_a_id = a_id
	parent_b_id = b_id
	_checked = false
	_compact = false
	var trait_ids: Array[String] = _trait_ids()
	_classes = PredictionLogic.phenotype_classes(GeneticsState.traits, trait_ids)
	var geno_a: Dictionary = GeneticsState.get_dragon(a_id).get("genotype", {})
	var geno_b: Dictionary = GeneticsState.get_dragon(b_id).get("genotype", {})
	_exact = PredictionLogic.exact_ratios(GeneticsState.library, geno_a, geno_b, trait_ids)
	_rebuild()
	set_compact(false)
	visible = true


func reset() -> void:
	## Forget the prediction and hide the panel (used when a parent changes)
	parent_a_id = -1
	parent_b_id = -1
	_checked = false
	_rows.clear()
	_classes.clear()
	_exact.clear()
	_clear_body()
	visible = false


func desired_width() -> float:
	## Width that fits every fraction button for the level (or the compact summary)
	if _compact:
		return WIDTH_COMPACT
	return WIDTH_LEVEL_1 if GeneticsState.current_level <= 1 else WIDTH_LEVEL_2


func set_compact(compact: bool) -> void:
	## Compact = just the per-kind results (frees room for the clutch panel after hatching)
	_compact = compact
	for key: String in _rows.keys():
		var row: Dictionary = _rows[key]
		var line: Control = row["line"]
		line.visible = not compact
	if _total_label != null:
		_total_label.visible = not compact
		_check_button.visible = not compact
	custom_minimum_size = Vector2(desired_width(), 0)
	size = Vector2(desired_width(), 0)


func is_checked() -> bool:
	return _checked


func exact_ratios() -> Dictionary:
	## Exact class -> probability for the current cross
	return _exact


func total_16ths() -> int:
	## Sum of the picked numerators (over 16)
	var total: int = 0
	for key: String in _rows.keys():
		var row: Dictionary = _rows[key]
		total += int(row["value"])
	return total


# === BUILD ===

func _trait_ids() -> Array[String]:
	var ids: Array[String] = []
	for trait_id: String in GeneticsState.get_trait_ids():
		ids.append(trait_id)
	return ids


func _clear_body() -> void:
	if _body != null:
		remove_child(_body)
		_body.queue_free()
		_body = null


func _rebuild() -> void:
	_clear_body()
	_rows.clear()
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	add_child(_body)

	# Flow container: the score drops under the title when the panel is narrow (compact)
	var header: HFlowContainer = HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 16)
	header.add_theme_constant_override("v_separation", 0)
	_body.add_child(header)
	header.add_child(_make_label("Predict the babies", 20))
	_score_label = _make_label("", 15)
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_score_label)

	var options: Array[int] = PredictionLogic.fraction_options(GeneticsState.current_level)
	for kind: String in _classes:
		_add_row(kind, options)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_body.add_child(footer)
	_total_label = _make_label("", 20)
	_total_label.custom_minimum_size = Vector2(120, 0)
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_total_label)
	_check_button = Button.new()
	_check_button.text = "Check my prediction"
	_check_button.custom_minimum_size = Vector2(190, 48)
	_check_button.add_theme_font_size_override("font_size", 17)
	_check_button.add_theme_stylebox_override("normal", _box(CHECK_NORMAL))
	_check_button.add_theme_stylebox_override("hover", _box(CHECK_NORMAL.lightened(0.2)))
	_check_button.add_theme_stylebox_override("pressed", _box(CHECK_NORMAL.darkened(0.2)))
	_check_button.add_theme_stylebox_override("disabled", _box(Color(0.18, 0.22, 0.28, 1.0)))
	_check_button.add_theme_color_override("font_color", COLOR_TEXT)
	_check_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	_check_button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	_check_button.add_theme_color_override("font_disabled_color", Color(0.65, 0.68, 0.72, 1.0))
	_check_button.pressed.connect(_on_check_pressed)
	footer.add_child(_check_button)

	_message_label = _make_label(MSG_HINT, 14)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(150, 0)
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_message_label)
	_refresh()


func _add_row(kind: String, options: Array[int]) -> void:
	var holder: VBoxContainer = VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)
	_body.add_child(holder)

	var top: HBoxContainer = HBoxContainer.new()
	holder.add_child(top)
	var name_label: Label = _make_label(kind, 17)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var result_label: Label = _make_label("", 16)
	top.add_child(result_label)

	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	holder.add_child(line)
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: Array[Button] = []
	for n: int in options:
		var btn: Button = Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.text = PredictionLogic.fraction_label(n)
		btn.custom_minimum_size = MIN_BUTTON
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 17)
		_style_toggle(btn)
		btn.pressed.connect(_on_fraction_pressed.bind(kind, n))
		line.add_child(btn)
		buttons.append(btn)
	_rows[kind] = {"value": 0, "buttons": buttons, "label": name_label, "result": result_label, "line": line}


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	return label


func _style_toggle(btn: Button) -> void:
	var normal: StyleBoxFlat = _box(BUTTON_NORMAL)
	var hover: StyleBoxFlat = _box(BUTTON_HOVER)
	var picked: StyleBoxFlat = _box(BUTTON_PICKED)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", picked)
	btn.add_theme_stylebox_override("hover_pressed", picked)
	btn.add_theme_stylebox_override("disabled", _box(Color(0.18, 0.22, 0.28, 1.0)))
	btn.add_theme_color_override("font_pressed_color", BUTTON_PICKED_TEXT)
	btn.add_theme_color_override("font_hover_pressed_color", BUTTON_PICKED_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color(0.65, 0.68, 0.72, 1.0))


func _box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	return box


# === EVENTS ===

func _on_fraction_pressed(kind: String, numerator: int) -> void:
	if _checked:
		return
	var row: Dictionary = _rows[kind]
	row["value"] = numerator
	_refresh()


func _refresh() -> void:
	## Update the running total, the Check button and the score line
	var total: int = total_16ths()
	# Level 1 options are all quarters, so show the total in quarters there
	var per_unit: int = 4 if GeneticsState.current_level <= 1 else 1
	var denominator: int = PredictionLogic.DENOMINATOR / per_unit
	_total_label.text = "Total: %d/%d" % [total / per_unit, denominator]
	_total_label.add_theme_color_override("font_color", COLOR_RIGHT if total == PredictionLogic.DENOMINATOR else COLOR_TEXT)
	_check_button.disabled = _checked or total != PredictionLogic.DENOMINATOR
	_score_label.text = _score_text()


func _score_text() -> String:
	if GeneticsState.predictions_made <= 0:
		return ""
	return "Predictions right: %d of %d" % [GeneticsState.predictions_right, GeneticsState.predictions_made]


func _on_check_pressed() -> void:
	if _checked or total_16ths() != PredictionLogic.DENOMINATOR:
		return
	_checked = true
	var picks: Dictionary = {}
	for kind: String in _rows.keys():
		var row: Dictionary = _rows[kind]
		picks[kind] = int(row["value"])
	var graded: Dictionary = PredictionLogic.grade(picks, _exact)
	var graded_rows: Dictionary = graded["rows"]
	for kind: String in _rows.keys():
		var row: Dictionary = _rows[kind]
		var result: Dictionary = graded_rows.get(kind, {"correct": 0, "right": int(row["value"]) == 0})
		var result_label: Label = row["result"]
		var correct_text: String = PredictionLogic.fraction_label(int(result["correct"]))
		if bool(result["right"]):
			result_label.text = "✓ %s" % correct_text
			result_label.add_theme_color_override("font_color", COLOR_RIGHT)
		else:
			result_label.text = "✗ it is %s" % correct_text
			result_label.add_theme_color_override("font_color", COLOR_WRONG)
		var buttons: Array = row["buttons"]
		for btn: Button in buttons:
			btn.disabled = true
	var all_right: bool = bool(graded["all_right"])
	GeneticsState.record_prediction(all_right)
	_message_label.text = MSG_RIGHT if all_right else MSG_WRONG
	_message_label.add_theme_color_override("font_color", COLOR_RIGHT if all_right else COLOR_TEXT)
	_refresh()
	prediction_checked.emit(all_right)


# === DEBUG / TEST HELPERS ===

func pick(kind: String, numerator_16ths: int) -> void:
	## Choose a fraction for a row from code (used by the DG_SHOT screenshot gate)
	if not _rows.has(kind):
		return
	var row: Dictionary = _rows[kind]
	var options: Array[int] = PredictionLogic.fraction_options(GeneticsState.current_level)
	var idx: int = options.find(numerator_16ths)
	if idx < 0:
		return
	var buttons: Array = row["buttons"]
	var btn: Button = buttons[idx]
	btn.button_pressed = true
	_on_fraction_pressed(kind, numerator_16ths)


func check() -> void:
	_on_check_pressed()
