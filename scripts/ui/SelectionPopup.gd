extends Control
class_name SelectionPopup
## SelectionPopup - Popup menu for selecting a dragon as Parent A or B
##
## Appears when a dragon is clicked, allowing the student to assign
## that dragon to a parent slot for breeding.

signal parent_a_selected(dragon_id: int)
signal parent_b_selected(dragon_id: int)
signal popup_closed()

@onready var panel: Panel = $Panel
@onready var dragon_name_label: Label = $Panel/DragonNameLabel
@onready var genotype_label: Label = $Panel/GenotypeLabel
@onready var phenotype_label: Label = $Panel/PhenotypeLabel
@onready var parent_a_button: Button = $Panel/ParentAButton
@onready var parent_b_button: Button = $Panel/ParentBButton
@onready var close_button: Button = $Panel/CloseButton

var current_dragon_id: int = -1


func _ready() -> void:
	parent_a_button.pressed.connect(_on_parent_a_pressed)
	parent_b_button.pressed.connect(_on_parent_b_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Start hidden
	visible = false


func show_for_dragon(dragon_id: int, screen_position: Vector2) -> void:
	## Show the popup for a specific dragon at the given position
	
	current_dragon_id = dragon_id
	
	var dragon: Dictionary = GeneticsState.get_dragon(dragon_id)
	if dragon.is_empty():
		return
	
	# Update labels
	dragon_name_label.text = dragon.get("name", "Dragon")
	genotype_label.text = "Genotype: " + GeneticsState.get_genotype_string(dragon_id)
	
	var is_fire: bool = GeneticsState.is_fire_breather(dragon_id)
	phenotype_label.text = "Phenotype: " + ("🔥 Fire-Breather" if is_fire else "❄️ No Fire")
	
	# Position popup near the dragon but on screen
	position = _clamp_to_screen(screen_position)
	
	visible = true


func _clamp_to_screen(pos: Vector2) -> Vector2:
	## Keep popup within screen bounds
	var viewport_size: Vector2 = get_viewport_rect().size
	var popup_size: Vector2 = panel.size
	
	pos.x = clamp(pos.x, 0, viewport_size.x - popup_size.x)
	pos.y = clamp(pos.y, 0, viewport_size.y - popup_size.y)
	
	return pos


func _on_parent_a_pressed() -> void:
	parent_a_selected.emit(current_dragon_id)
	_close()


func _on_parent_b_pressed() -> void:
	parent_b_selected.emit(current_dragon_id)
	_close()


func _on_close_pressed() -> void:
	_close()


func _close() -> void:
	visible = false
	current_dragon_id = -1
	popup_closed.emit()


func _input(event: InputEvent) -> void:
	## Close popup if clicking outside it
	if visible and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = panel.get_local_mouse_position()
			var panel_rect := Rect2(Vector2.ZERO, panel.size)
			if not panel_rect.has_point(local_pos):
				_close()
