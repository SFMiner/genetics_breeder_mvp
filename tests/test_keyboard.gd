extends SceneTree
## Keyboard use and the sims-site keyboard exit: Tab walks the controls in order, Tab past the last and Shift+Tab
## before the first leave the game, Escape closes the dragon menu / quiz first and then leaves, and the whole
## predict -> check -> hatch -> keep loop can be done without a mouse.
## Run: ../Godot_v4.5-stable_win64.exe --headless --path . --script tests/test_keyboard.gd

# Autoloads are not global identifiers in --script mode; bound to the live node in _run().
var GeneticsState: Node = null

var _passed: int = 0
var _failed: int = 0
var _main: Node = null


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


# Dragon / KeyboardNav are not named here: their scripts need the autoload, which is not bound when this one compiles
func _is_tile(c: Control) -> bool:
	return c != null and "role_label" in c


func _focus() -> Control:
	return get_root().gui_get_focus_owner()


func _run() -> void:
	await get_root().ready
	GeneticsState = get_root().get_node("/root/GeneticsState")
	GeneticsState.set_seed(7)
	_main = (load("res://scenes/main/BreederRoom.tscn") as PackedScene).instantiate()
	get_root().add_child(_main)
	for i: int in range(5):
		await process_frame
	var nav: Node = _main.keyboard
	_check(nav != null, "KeyboardNav is set up")
	if nav == null:
		_finish()
		return

	# --- Tab order at the start: level, dragon tiles (one stop), Reset (no parents yet, so nothing else) ---
	var stops: Array[Control] = []
	var before: int = nav.leave_count
	for i: int in range(12):
		await _key(KEY_TAB)
		var f: Control = _focus()
		if f == null:
			break
		stops.append(f)
	_check(stops.size() == 3, "Tab reaches 3 stops at the start (got %d)" % stops.size())
	_check(nav.leave_count == before + 1, "Tab past the last control leaves the game")
	_check(_focus() == null, "focus is released after leaving")
	if stops.size() == 3:
		_check(stops[0] == _main.level_select, "first stop is the level picker")
		_check(_is_tile(stops[1]), "second stop is a dragon tile")
		_check(stops[2] == _main.reset_button, "last stop is Reset Lab")

	# Shift+Tab from nothing focused starts at the last stop; before the first it leaves
	before = nav.leave_count
	var back: int = 0
	for i: int in range(12):
		await _key(KEY_TAB, true)
		if _focus() == null:
			break
		back += 1
	_check(back == 3, "Shift+Tab walks the same stops backwards (got %d)" % back)
	_check(nav.leave_count == before + 1, "Shift+Tab before the first control leaves the game")

	# Shift+Tab on the last stop moves back instead of leaving (exact-match check)
	_main.reset_button.grab_focus()
	before = nav.leave_count
	await _key(KEY_TAB, true)
	_check(nav.leave_count == before and _is_tile(_focus()), "Shift+Tab on the last stop moves back")

	# Escape with nothing open leaves
	before = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(nav.leave_count == before + 1, "Escape leaves the game")

	# --- Enter on a dragon tile opens its menu; Escape closes it first and focus returns to the tile ---
	var tiles: Array[Control] = []
	for child: Node in _main.dragon_grid.get_children():
		tiles.append(child as Control)
	_check(tiles.size() == 2, "two starter dragons (got %d)" % tiles.size())
	tiles[0].grab_focus()
	await _key(KEY_ENTER)
	_check(_main.selection_popup.visible, "Enter on a tile opens the dragon menu")
	_check(_focus() == _main.selection_popup.parent_a_button, "menu focus starts on Set as Parent A")
	before = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(not _main.selection_popup.visible and nav.leave_count == before, "Escape closes the menu without leaving")
	_check(_focus() == tiles[0], "focus returns to the tile")

	# Tab inside the menu stays inside it
	await _key(KEY_ENTER)
	await _key(KEY_TAB)
	_check(_focus() == _main.selection_popup.parent_b_button, "Tab in the menu goes to Set as Parent B")
	await _key(KEY_ESCAPE)

	# --- Choose both parents with the keyboard ---
	tiles[0].grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)  # Set as Parent A
	_check(GeneticsState.selected_parent_a_id == tiles[0].dragon_id, "Enter chooses Parent A")
	_check(tiles[0].role_label.text == "Parent A", "the tile says Parent A in text")
	_check(_focus() == tiles[0], "focus is back on the tile after choosing")
	tiles[1].grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_TAB)
	await _key(KEY_SPACE)  # Set as Parent B
	_check(GeneticsState.selected_parent_b_id == tiles[1].dragon_id, "Space chooses Parent B")

	# --- Prediction rows: one Tab stop per row, arrows move inside it, Space picks ---
	var rows: Array = _main.prediction_panel.row_groups()
	_check(rows.size() == 2, "Level 1 prediction has 2 rows (got %d)" % rows.size())
	_check(_main.prediction_panel.visible, "the prediction panel is showing")
	if rows.size() != 2:
		_finish()
		return
	tiles[1].grab_focus()
	await _key(KEY_TAB)
	var first_row: Array = rows[0]
	var second_row: Array = rows[1]
	_check(first_row.has(_focus()), "Tab from the tiles lands on the first prediction row")
	await _key(KEY_RIGHT)
	_check(_focus() == first_row[1], "Right arrow moves along the row")
	await _key(KEY_SPACE)
	_check(first_row[1].button_pressed, "Space picks a fraction")
	await _key(KEY_TAB)
	_check(second_row.has(_focus()), "Tab goes to the next row")
	var options: Array[int] = PredictionLogic.fraction_options(1)
	var need: int = 16 - int(options[1])
	var idx: int = options.find(need)
	_check(idx >= 0, "the matching fraction exists")
	second_row[idx].grab_focus()
	await _key(KEY_ENTER)
	_check(_main.prediction_panel.total_16ths() == 16, "the rows add up to the whole")
	await _key(KEY_TAB)
	_check(_focus() == _main.prediction_panel.check_button(), "next stop is Check my prediction")
	_check(_main.breeding_panel.breed_button.disabled, "Hatch is still locked before the check")
	await _key(KEY_ENTER)
	_check(_main.prediction_panel.is_checked(), "Enter checks the prediction")
	_check(_focus() == _main.breeding_panel.breed_button, "focus moves on to Hatch after the check")
	_check(not _main.breeding_panel.breed_button.disabled, "Hatch unlocks after the check")

	# --- Hatch, then keep a hatchling, all by keyboard ---
	await _key(KEY_ENTER)
	_check(_main.clutch_panel.chip_count() == 20, "Enter hatches 20 eggs")
	_check(_focus() == _main.clutch_panel.chips()[0], "focus lands on the first hatchling")
	await _key(KEY_RIGHT)
	_check(_focus() == _main.clutch_panel.chips()[1], "Right arrow moves along the hatchlings")
	var count_before: int = GeneticsState.dragon_collection.size()
	await _key(KEY_ENTER)
	_check(GeneticsState.dragon_collection.size() == count_before + 1, "Enter keeps the hatchling")

	# --- Quiz square: opens by keyboard, is modal, Escape closes it without leaving ---
	_main.quiz_button.grab_focus()
	await _key(KEY_ENTER)
	_check(_main.quiz_punnett_square.visible, "Enter on the quiz button opens the quiz")
	_check(_focus() is LineEdit, "focus starts in the first quiz cell")
	var quiz_stops: Array = nav.stops()
	_check(quiz_stops.size() == 4 * 2 + 2, "quiz Tab stops: 4 cells x 2 fields + Submit + Close (got %d)" % quiz_stops.size())
	before = nav.leave_count
	await _key(KEY_ESCAPE)
	_check(not _main.quiz_punnett_square.visible and nav.leave_count == before, "Escape closes the quiz without leaving")
	await _key(KEY_ESCAPE)
	_check(nav.leave_count == before + 1, "a second Escape leaves")

	# Every stop has a visible focus outline
	var all: Array = nav.stops()
	nav.style_focus(all)
	for group: Array in all:
		for c: Control in group:
			if not _is_tile(c):
				_check(c.has_theme_stylebox_override("focus"), "%s has the focus outline" % c.name)
	_finish()


func _finish() -> void:
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.shift_pressed = shift
		e.pressed = pressed
		get_root().push_input(e)
	await process_frame
	await process_frame
