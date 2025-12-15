extends Node2D
## BreederRoom - Main game scene for Dragon Genetics
##
## Manages the breeding lab: displays dragons, handles selection,
## coordinates UI components, and spawns offspring.

@onready var dragon_grid: GridContainer = %DragonGrid
@onready var breeding_panel: BreedingPanel = $CanvasLayer/BreedingPanel
@onready var punnett_square: PunnettSquareUI = %PunnettSquare
@onready var selection_popup: SelectionPopup = $CanvasLayer/SelectionPopup
@onready var reset_button: Button = $CanvasLayer/ResetButton
@onready var level_select: OptionButton = $CanvasLayer/LevelSelect
@onready var title_label: Label = $CanvasLayer/TitleLabel
@onready var generation_label: Label = $CanvasLayer/GenerationLabel
@onready var breed_player : AudioStreamPlayer = $BreedPlayer
@onready var rename_player : AudioStreamPlayer = $RenamePlayer


## Preload the Dragon scene
var dragon_scene: PackedScene = preload("res://scenes/organisms/Dragon.tscn")

## Track dragon node instances by ID
var dragon_nodes: Dictionary = {}

## Grid layout
const DRAGONS_PER_ROW : int = 6


func _ready() -> void:
	# Connect GeneticsState signals
	GeneticsState.dragon_added.connect(_on_dragon_added)
	GeneticsState.dragon_renamed.connect(_on_dragon_renamed)
	GeneticsState.breeding_complete.connect(_on_breeding_complete)
	GeneticsState.collection_reset.connect(_on_collection_reset)

	# Configure grid
	dragon_grid.columns = DRAGONS_PER_ROW
	# Connect UI signals
	breeding_panel.breed_requested.connect(_on_breed_requested)
	selection_popup.parent_a_selected.connect(_on_parent_a_selected)
	selection_popup.parent_b_selected.connect(_on_parent_b_selected)
	reset_button.pressed.connect(_on_reset_pressed)
	level_select.item_selected.connect(_on_level_selected)
	_populate_level_select()
	_ensure_punnett_square()
	_ensure_punnett_square()
	
	# Spawn initial dragons from GeneticsState
	_spawn_all_dragons()
	
	# Update generation display
	_update_generation_label()


func _spawn_all_dragons() -> void:
	## Create Dragon nodes for all dragons in GeneticsState
	for dragon_data in GeneticsState.dragon_collection:
		_spawn_dragon_node(dragon_data["id"])


func _spawn_dragon_node(dragon_id: int) -> void:
	## Create a Dragon node for the given ID
	
	var dragon_instance: Dragon = dragon_scene.instantiate()
	dragon_grid.add_child(dragon_instance)
	
	# Defer setup until after the node is fully inside the tree so @onready vars exist
	dragon_instance.call_deferred("setup", dragon_id)
	
	# Connect click signal after setup
	dragon_instance.clicked.connect(_on_dragon_clicked)
	dragon_nodes[dragon_id] = dragon_instance


func _on_dragon_added(dragon_id: int) -> void:
	## Handle new dragon being added to GeneticsState
	if not dragon_nodes.has(dragon_id):
		_spawn_dragon_node(dragon_id)


func _on_dragon_clicked(dragon_id: int) -> void:
	## Show selection popup when a dragon is clicked
	var dragon_node: Dragon = dragon_nodes.get(dragon_id)
	if dragon_node:
		var popup_pos: Vector2 = dragon_node.global_position + Vector2(50, -50)
		selection_popup.show_for_dragon(dragon_id, popup_pos)


func _on_parent_a_selected(dragon_id: int) -> void:
	## Set dragon as Parent A
	
	# Clear previous Parent A highlight
	if GeneticsState.selected_parent_a_id >= 0:
		var old_node: Dragon = dragon_nodes.get(GeneticsState.selected_parent_a_id)
		if old_node:
			old_node.set_as_parent_a(false)
	
	# Set new Parent A
	GeneticsState.select_parent_a(dragon_id)
	breeding_panel.set_parent_a(dragon_id)
	
	# Highlight the selected dragon
	var dragon_node: Dragon = dragon_nodes.get(dragon_id)
	if dragon_node:
		dragon_node.set_as_parent_a(true)
	
	
	# Update Punnett square
	_update_punnett_square()


func _on_parent_b_selected(dragon_id: int) -> void:
	## Set dragon as Parent B
	
	# Clear previous Parent B highlight
	if GeneticsState.selected_parent_b_id >= 0:
		var old_node: Dragon = dragon_nodes.get(GeneticsState.selected_parent_b_id)
		if old_node:
			old_node.set_as_parent_b(false)
	
	# Set new Parent B
	GeneticsState.select_parent_b(dragon_id)
	breeding_panel.set_parent_b(dragon_id)
	
	# Highlight the selected dragon
	var dragon_node: Dragon = dragon_nodes.get(dragon_id)
	if dragon_node:
		dragon_node.set_as_parent_b(true)
	
	# Update Punnett square
	_update_punnett_square()


func _on_dragon_renamed(dragon_id: int, _new_name: String) -> void:
	## Refresh the dragon tile when its name changes
	var dragon_node: Dragon = dragon_nodes.get(dragon_id)
	if dragon_node:
		dragon_node.refresh_display()
	rename_player.play()


func _update_punnett_square() -> void:
	## Update the Punnett square display based on selected parents
	_ensure_punnett_square()
	if GeneticsState.selected_parent_a_id >= 0 and GeneticsState.selected_parent_b_id >= 0:
		if punnett_square:
			punnett_square.display_cross(
				GeneticsState.selected_parent_a_id,
				GeneticsState.selected_parent_b_id
			)
	else:
		if punnett_square:
			punnett_square.hide_square()


func _on_breed_requested() -> void:
	## Handle breed button press
	if not GeneticsState.can_breed():
		return
	
	# Perform breeding
	var offspring_id: int = GeneticsState.breed(
		GeneticsState.selected_parent_a_id,
		GeneticsState.selected_parent_b_id
	)
	breed_player.play()
	if offspring_id >= 0:
		_update_generation_label()


func _on_breeding_complete(offspring_id: int) -> void:
	## Handle new offspring created
	# Flash or highlight the new dragon
	var dragon_node: Dragon = dragon_nodes.get(offspring_id)
	if dragon_node:
		# Simple flash effect using modulate
		_flash_dragon(dragon_node)


func _flash_dragon(dragon_node: Dragon) -> void:
	## Brief flash animation to highlight new offspring
	var original_modulate: Color = dragon_node.modulate
	dragon_node.modulate = Color(2, 2, 2, 1)  # Bright white flash
	
	await get_tree().create_timer(0.2).timeout
	dragon_node.modulate = original_modulate


func _on_reset_pressed() -> void:
	## Reset the game to initial state
	_clear_dragons()
	
	# Clear UI state
	breeding_panel.clear_parents()
	if punnett_square:
		punnett_square.hide_square()
	selection_popup.visible = false
	
	# Reset GeneticsState (this will re-spawn starters)
	GeneticsState.reset()


func _on_collection_reset() -> void:
	## Handle GeneticsState reset
	# New dragons are emitted via dragon_added during reset; avoid double-spawning.
	_update_generation_label()
	if punnett_square:
		punnett_square.refresh_trait_options(true)


func _update_generation_label() -> void:
	## Update the generation counter display
	var total: int = GeneticsState.dragon_collection.size()
	var fire_count: int = 0
	var no_fire_count: int = 0
	
	for dragon in GeneticsState.dragon_collection:
		if dragon["phenotype"].get("fire") == "fire-breather":
			fire_count += 1
		else:
			no_fire_count += 1
	
	generation_label.text = "Dragons: %d | ?? Fire: %d | ?? No Fire: %d" % [total, fire_count, no_fire_count]


func _populate_level_select() -> void:
	level_select.clear()
	level_select.add_item("Level 1: Fire (monohybrid)", 1)
	level_select.add_item("Level 2: Fire + Wings", 2)
	var idx := level_select.get_item_index(GeneticsState.current_level)
	if idx >= 0:
		level_select.select(idx)


func _on_level_selected(index: int) -> void:
	var level_id := level_select.get_item_id(index)
	if level_id == GeneticsState.current_level:
		return
	_clear_dragons()
	breeding_panel.clear_parents()
	if punnett_square:
		punnett_square.hide_square()
	selection_popup.visible = false
	GeneticsState.set_level(level_id)
	if punnett_square:
		punnett_square.refresh_trait_options(true)
	_update_generation_label()


func _clear_dragons() -> void:
	for dragon_node in dragon_nodes.values():
		dragon_node.queue_free()
	dragon_nodes.clear()


func _ensure_punnett_square() -> void:
	if punnett_square == null:
		var node := get_node_or_null("CanvasLayer/PunnettSquare")
		if node:
			punnett_square = node
		else:
			push_warning("PunnettSquare node not found; check scene tree path.")
