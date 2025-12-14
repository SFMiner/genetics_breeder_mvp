extends Node2D
class_name Dragon
## Dragon - Visual representation of a dragon in the breeding game
##
## Displays the dragon as a colored rectangle (placeholder) with genotype label.
## Fire-breathers are orange, non-fire-breathers are blue-gray.

signal clicked(dragon_id: int)

## The ID of this dragon in GeneticsState
@export var dragon_id: int = -1

## Visual components
@onready var genotype_label: Label = $GenotypeLabel
@onready var name_label: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea
@onready var selection_highlight: ColorRect = $SelectionHighlight

var sprite: ColorRect


## Colors for phenotypes
const COLOR_FIRE_BREATHER := Color(1.0, 0.4, 0.1)      # Orange
const COLOR_NO_FIRE := Color(0.4, 0.5, 0.7)            # Blue-gray
const COLOR_SELECTED := Color(1.0, 1.0, 0.0, 0.4)     # Yellow highlight
const COLOR_PARENT_A := Color(1.0, 0.2, 0.2, 0.5)     # Red tint for Parent A
const COLOR_PARENT_B := Color(0.2, 0.2, 1.0, 0.5)     # Blue tint for Parent B

## Selection state
var is_selected_as_parent_a: bool = false
var is_selected_as_parent_b: bool = false


func _ready() -> void:
	# Connect click detection
	sprite = $Sprite
	print(sprite)
	click_area.input_event.connect(_on_click_area_input_event)
	
	# Initial setup if dragon_id is set
	if dragon_id >= 0:
		refresh_display()


func setup(id: int) -> void:
	## Initialize this dragon with data from GeneticsState
	dragon_id = id
	refresh_display()
	sprite = $Sprite

func refresh_display() -> void:
	## Update visuals based on dragon data
	if dragon_id < 0:
		return
	
	var dragon_data: Dictionary = GeneticsState.get_dragon(dragon_id)
	if dragon_data.is_empty():
		return
	
	# Set color based on phenotype
	var is_fire: bool = GeneticsState.is_fire_breather(dragon_id)
	if sprite:
		sprite.color = COLOR_FIRE_BREATHER if is_fire else COLOR_NO_FIRE
	
	# Set genotype label
	var genotype_str: String = GeneticsState.get_genotype_string(dragon_id, "fire")
	if genotype_label:
		genotype_label.text = genotype_str
	
	# Set name label
	if name_label:
		name_label.text = dragon_data.get("name", "Dragon")
	
	# Update selection highlight
	_update_selection_highlight()


func _update_selection_highlight() -> void:
	## Show appropriate highlight based on selection state
	if is_selected_as_parent_a:
		selection_highlight.visible = true
		selection_highlight.color = COLOR_PARENT_A
	elif is_selected_as_parent_b:
		selection_highlight.visible = true
		selection_highlight.color = COLOR_PARENT_B
	else:
		selection_highlight.visible = false


func set_as_parent_a(is_parent: bool) -> void:
	## Mark this dragon as Parent A
	is_selected_as_parent_a = is_parent
	if is_parent:
		is_selected_as_parent_b = false
	_update_selection_highlight()


func set_as_parent_b(is_parent: bool) -> void:
	## Mark this dragon as Parent B
	is_selected_as_parent_b = is_parent
	if is_parent:
		is_selected_as_parent_a = false
	_update_selection_highlight()


func clear_selection() -> void:
	## Remove any parent selection
	is_selected_as_parent_a = false
	is_selected_as_parent_b = false
	_update_selection_highlight()


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	## Handle click on this dragon
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(dragon_id)
