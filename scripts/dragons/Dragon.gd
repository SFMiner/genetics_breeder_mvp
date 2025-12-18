extends Control
class_name Dragon
## Dragon - Visual representation of a dragon in the breeding game
##
## Displays the dragon as a colored rectangle (placeholder) with genotype label.
## Fire-breathers are orange, non-fire-breathers are blue-gray.

signal clicked(dragon_id: int)

## The ID of this dragon in GeneticsState
@export var dragon_id: int = -1

## Visual components
@onready var sprite: Sprite2D = $Sprite
@onready var genotype_label: Label = $GenotypeLabel
@onready var name_label: Label = $NameLabel
@onready var click_area: Area2D = $ClickArea
@onready var selection_highlight: ColorRect = $SelectionHighlight
@onready var aud: AudioStreamPlayer = $AudioStreamPlayer

## Colors for phenotypes (kept for highlights)
const COLOR_FIRE_BREATHER := Color(1.0, 0.4, 0.1)      # Orange
const COLOR_NO_FIRE := Color(0.4, 0.5, 0.7)            # Blue-gray
const COLOR_SELECTED := Color(1.0, 1.0, 0.0, 0.4)     # Yellow highlight
const COLOR_PARENT_A := Color(0.875, 0.0, 0.969, 0.973)     # Red tint for Parent A
const COLOR_PARENT_B := Color(0.2, 1.0, 1.0, 1.0)     # Blue tint for Parent B

## Selection state
var is_selected_as_parent_a: bool = false
var is_selected_as_parent_b: bool = false

const BASE_WIDTH := 140.0
const BASE_HEIGHT := 160.0
const PAD := 10.0
const HIGHLIGHT_PAD := 6.0
const LABEL_TOP := 6.0
const SPRITE_TOP := 30.0
const SPRITE_BOTTOM := 110.0
const GENO_TOP := 115.0
const GENO_BOTTOM := 135.0

func _ready() -> void:
	# Let the Area2D handle input; the Control root should not consume it
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Ensure click signal is connected (scene also wires it, but keep it explicit)
	if click_area and not click_area.input_event.is_connected(_on_click_area_input_event):
		click_area.input_pickable = true
		click_area.input_event.connect(_on_click_area_input_event)
	
	# Initial setup if dragon_id is set
	if dragon_id >= 0:
		refresh_display()

func setup(id: int) -> void:
	## Initialize this dragon with data from GeneticsState
	# If setup is called via call_deferred, @onready vars will already be valid.
	# In case it's ever called earlier, re-cache the nodes defensively.
	if not sprite:
		sprite = $Sprite
	if not genotype_label:
		genotype_label = $GenotypeLabel
	if not name_label:
		name_label = $NameLabel
	if not selection_highlight:
		selection_highlight = $SelectionHighlight
	
	dragon_id = id
	refresh_display()


func refresh_display() -> void:
	## Update visuals based on dragon data
	if dragon_id < 0:
		return
	
	var dragon_data: Dictionary = GeneticsState.get_dragon(dragon_id)
	if dragon_data.is_empty():
		return
	
	# Set sprite based on genotype
	sprite.texture = _get_dragon_texture(dragon_data)
	
	# Set genotype label (all traits summary)
	var genotype_str: String = GeneticsState.get_genotype_summary(dragon_id)
	genotype_label.text = genotype_str
	
	# Set name label
	name_label.text = dragon_data.get("name", "Dragon")

	# Resize layout to fit longest label
	var needed_width: float = max(
		BASE_WIDTH,
		genotype_label.get_combined_minimum_size().x + 2.0 * PAD,
		name_label.get_combined_minimum_size().x + 2.0 * PAD
	)
	_layout_nodes(needed_width)
	
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
	aud.play()

	_update_selection_highlight()


func set_as_parent_b(is_parent: bool) -> void:
	## Mark this dragon as Parent B
	is_selected_as_parent_b = is_parent
	if is_parent:
		is_selected_as_parent_a = false
	aud.play()

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


func _layout_nodes(width: float) -> void:
	## Center child nodes within the given width so grid cells expand cleanly
	custom_minimum_size = Vector2(width, BASE_HEIGHT)
	size = custom_minimum_size
	var center_x := width / 2.0
	
	# Highlight box
	selection_highlight.offset_left = HIGHLIGHT_PAD
	selection_highlight.offset_right = width - HIGHLIGHT_PAD
	selection_highlight.offset_top = HIGHLIGHT_PAD
	selection_highlight.offset_bottom = BASE_HEIGHT - 26.0
	
	# Sprite block (centered)
	sprite.position = Vector2(width / 2.0, (SPRITE_TOP + SPRITE_BOTTOM) / 2.0)
	sprite.scale = Vector2(width / BASE_WIDTH * 0.35, width / BASE_WIDTH * 0.35)
	
	# Labels
	name_label.offset_left = PAD
	name_label.offset_right = width - PAD
	name_label.offset_top = LABEL_TOP
	name_label.offset_bottom = LABEL_TOP + 20.0
	
	genotype_label.offset_left = PAD
	genotype_label.offset_right = width - PAD
	genotype_label.offset_top = GENO_TOP
	genotype_label.offset_bottom = GENO_BOTTOM
	
	# Click area and collision shape
	click_area.position = Vector2(center_x, BASE_HEIGHT / 2.0)
	var shape: CollisionShape2D = click_area.get_node("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D:
		var rect_shape := shape.shape as RectangleShape2D
		rect_shape.size = Vector2(width, BASE_HEIGHT)


func _get_dragon_texture(dragon_data: Dictionary) -> Texture2D:
	## Build a sprite filename based on genotype: fire (a=dominant F, r=recessive f), wings (d=dominant W, r=recessive w)
	var genotype: Dictionary = dragon_data.get("genotype", {})
	var fire: Array = genotype.get("fire", [])
	var wings: Array = genotype.get("wings", [])
	
	var fire_code := "r"
	if fire.size() == 2 and (fire[0] == "F" or fire[1] == "F"):
		fire_code = "d"
	
	var wings_code := "r"
	if wings.size() == 2 and (wings[0] == "W" or wings[1] == "W"):
		wings_code = "d"
	
	# If wings trait is absent (level 1), fall back to recessive wings art
	if wings.is_empty():
		wings_code = "r"
	
	var filename := "res://assets/sprites/dragon_a%s_f%s_w%s.png" % [
		fire_code,
		fire_code,
		wings_code
	]
	
	var tex := load(filename)
	if tex is Texture2D:
		return tex
	return null
