class_name KeyboardNav
extends Node
## Keyboard use and the keyboard exit for the sims site (SPEC section 6).
## The Tab order lives in stops() below. A "stop" is a group of controls that count as ONE Tab stop
## (dragon tiles, the fraction buttons of one row, the 20 hatchlings): Tab enters the group and the
## arrow keys move inside it. Tab past the last stop or Shift+Tab before the first leaves the game.
## Escape closes the open box first (dragon menu, quiz square) and leaves only when none is open.

const FOCUS_COLOR: Color = Color(1.0, 0.85, 0.2)

## Times the keyboard left the game; read by tests/test_keyboard.gd.
var leave_count: int = 0
## True after a key press, false after a mouse click (the room only moves focus around for keyboard users).
var keys_in_use: bool = false

var _room: Node = null
var _ring: StyleBoxFlat
var _ring_toggle: StyleBoxFlat


func _init() -> void:
	_ring = _make_ring(FOCUS_COLOR)
	_ring_toggle = _make_ring(Color(1, 1, 1))


func setup(room: Node) -> void:
	_room = room


func _make_ring(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(3)
	box.set_corner_radius_all(4)
	box.set_expand_margin_all(2.0)
	return box


# === TAB ORDER ===

func stops() -> Array:
	## Array of Array[Control], in Tab order, for whatever is on screen right now.
	var groups: Array = []
	var popup: SelectionPopup = _room.selection_popup
	var quiz: QuizPunnettSquareUI = _room.quiz_punnett_square
	if popup.visible:
		# The dragon menu is modal: only its own controls
		groups.append([popup.parent_a_button])
		groups.append([popup.parent_b_button])
		groups.append([popup.rename_button])
		groups.append([popup.rename_line_edit])
		groups.append([popup.rename_save_button])
		groups.append([popup.close_button])
	elif quiz.visible:
		for cell: Dictionary in quiz.cells:
			groups.append([cell["geno"]])
			groups.append([cell["pheno"]])
		groups.append([quiz.submit_button])
		groups.append([quiz.close_button])
	else:
		groups.append([_room.level_select])
		var tiles: Array = []
		for child: Node in _room.dragon_grid.get_children():
			if child is Dragon and not child.is_queued_for_deletion():
				tiles.append(child)
		groups.append(tiles)
		for row: Array in _room.prediction_panel.row_groups():
			groups.append(row)
		groups.append([_room.prediction_panel.check_button()])
		groups.append([_room.breeding_panel.breed_button])
		groups.append(_room.clutch_panel.chips())
		groups.append([_room.quiz_button])
		groups.append([_room.reset_button])
	var usable: Array = []
	for group: Array in groups:
		var members: Array = []
		for c: Variant in group:
			var control: Control = c as Control
			if control != null and _usable(control):
				members.append(control)
		if not members.is_empty():
			usable.append(members)
	return usable


func _usable(c: Control) -> bool:
	if not is_instance_valid(c) or not c.is_visible_in_tree() or c.focus_mode == Control.FOCUS_NONE:
		return false
	var button: BaseButton = c as BaseButton
	return button == null or not button.disabled


func primary(group: Array) -> Control:
	## The control Tab lands on: the one with focus, else a picked toggle, else the first
	for c: Control in group:
		if c.has_focus():
			return c
	for c: Control in group:
		var button: BaseButton = c as BaseButton
		if button != null and button.toggle_mode and button.button_pressed:
			return c
	return group[0]


func _stop_index(all: Array, focus: Control) -> int:
	if focus == null:
		return -1
	for i: int in range(all.size()):
		var group: Array = all[i]
		if group.has(focus):
			return i
	return -1


func style_focus(all: Array) -> void:
	## Visible focus outline on every control in the order (buttons and fields; tiles draw their own)
	for group: Array in all:
		for c: Control in group:
			if c is Dragon:
				continue
			var button: BaseButton = c as BaseButton
			var toggle: bool = button != null and button.toggle_mode
			c.add_theme_stylebox_override("focus", _ring_toggle if toggle else _ring)


# === INPUT ===

func _input(event: InputEvent) -> void:
	# In _input, not _unhandled_input: the GUI takes Tab for its own focus movement before that.
	# An open OptionButton list is its own popup window, so its Escape closes it and never gets here.
	if _room == null:
		return
	if event is InputEventMouseButton and event.pressed:
		keys_in_use = false
		return
	if not (event is InputEventKey and event.pressed):
		return
	keys_in_use = true
	var focus: Control = get_viewport().gui_get_focus_owner()
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _room.selection_popup.visible:
			_room.selection_popup.close()
		elif _room.quiz_punnett_square.visible:
			_room.quiz_punnett_square.close()
			if _room.quiz_button.is_visible_in_tree():
				_room.quiz_button.grab_focus()
		else:
			leave_game()
		return
	# Exact match (third argument): without it ui_focus_next also matches Shift+Tab
	var forward: bool = event.is_action_pressed("ui_focus_next", true, true)
	var backward: bool = event.is_action_pressed("ui_focus_prev", true, true)
	if not (forward or backward):
		return
	var all: Array = stops()
	if all.is_empty():
		return
	style_focus(all)
	get_viewport().set_input_as_handled()
	var index: int = _stop_index(all, focus)
	if index < 0:
		var start: int = 0 if forward else all.size() - 1
		primary(all[start]).grab_focus()
		return
	var target: int = index + (1 if forward else -1)
	if target < 0 or target >= all.size():
		leave_game()
		return
	primary(all[target]).grab_focus()


## Drops focus and asks the sims site's play page to take the keyboard back. On its own page there is no parent.
func leave_game() -> void:
	get_viewport().gui_release_focus()
	leave_count += 1
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
				"if (window.parent !== window) window.parent.postMessage({type: 'sims:leave-game'}, location.origin)")
