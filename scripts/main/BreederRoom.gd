extends Node2D
## BreederRoom - Main game scene for Dragon Genetics
##
## Manages the breeding lab: displays dragons, handles selection,
## coordinates UI components, and spawns offspring.

@onready var dragon_grid: GridContainer = %DragonGrid
@onready var breeding_panel: BreedingPanel = $CanvasLayer/BreedingPanel
@onready var punnett_square: PunnettSquareUI = %PunnettSquare as PunnettSquareUI
@onready var quiz_punnett_square: QuizPunnettSquareUI = %QuizSquare as QuizPunnettSquareUI
@onready var selection_popup: SelectionPopup = $CanvasLayer/SelectionPopup
@onready var reset_button: Button = $CanvasLayer/ResetButton
@onready var level_select: OptionButton = $CanvasLayer/LevelSelect
@onready var title_label: Label = $CanvasLayer/TitleLabel
@onready var generation_label: Label = $CanvasLayer/GenerationLabel
@onready var breed_player : AudioStreamPlayer = $BreedPlayer
@onready var rename_player : AudioStreamPlayer = $RenamePlayer
@onready var fire_emoji : Sprite2D = $CanvasLayer/GenerationLabel/FireEmoji
@onready var smoke_emoji : Sprite2D = $CanvasLayer/GenerationLabel/SmokeEmoji
## Preload the Dragon scene
var dragon_scene: PackedScene = preload("res://scenes/organisms/Dragon.tscn")

## Track dragon node instances by ID
var dragon_nodes: Dictionary = {}
var smoke_emoji_pos : Vector2
var fire_emoji_pos : Vector2
## Grid layout
const DRAGONS_PER_ROW : int = 6

const EMOJI_SHIFT : Vector2 = Vector2(10,0)

# === PREDICT-THEN-BREED ===
const CLUTCH_SIZE: int = 20
## Left-hand column under the dragon tiles; both panels share it (one stage at a time)
const PREDICT_POSITION: Vector2 = Vector2(8, 262)
## The clutch panel fills the space between the compact prediction panel and the right column
const CLUTCH_TOP: float = 262.0
const CLUTCH_RIGHT: float = 912.0
const PANEL_GAP: float = 8.0
## The quiz square covers the Punnett square, so it opens from this button instead of automatically
const QUIZ_BUTTON_POSITION: Vector2 = Vector2(700, 664)
const QUIZ_BUTTON_SIZE: Vector2 = Vector2(200, 48)

var prediction_panel: PredictionPanel = null
var clutch_panel: ClutchPanel = null
var quiz_button: Button = null


func _ready() -> void:
	# Debug gate: DG_LEVEL=2 starts on Level 2 (set before anything spawns)
	if OS.get_environment("DG_LEVEL") == "2":
		GeneticsState.set_level(2)

	# Connect GeneticsState signals
	GeneticsState.dragon_added.connect(_on_dragon_added)
	GeneticsState.dragon_renamed.connect(_on_dragon_renamed)
	GeneticsState.breeding_complete.connect(_on_breeding_complete)
	GeneticsState.collection_reset.connect(_on_collection_reset)
	
	smoke_emoji_pos = smoke_emoji.position
	fire_emoji_pos = fire_emoji.position

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
	_ensure_quiz_square()
	_build_prediction_panels()

	# Spawn initial dragons from GeneticsState
	_spawn_all_dragons()

	# Update generation display
	_update_generation_label()

	# Debug gate: DG_SHOT=<png path> runs the loop automatically and saves a screenshot
	var shot_path: String = OS.get_environment("DG_SHOT")
	if not shot_path.is_empty():
		_run_screenshot_gate(shot_path)


func _build_prediction_panels() -> void:
	## Create the PredictionPanel and ClutchPanel in code (containers only, no .tscn layout)
	var layer: CanvasLayer = $CanvasLayer
	prediction_panel = PredictionPanel.new()
	prediction_panel.position = PREDICT_POSITION
	prediction_panel.prediction_checked.connect(_on_prediction_checked)
	layer.add_child(prediction_panel)

	clutch_panel = ClutchPanel.new()
	clutch_panel.keep_requested.connect(_on_keep_requested)
	layer.add_child(clutch_panel)
	
	quiz_button = Button.new()
	quiz_button.text = "Quiz me on the square"
	quiz_button.position = QUIZ_BUTTON_POSITION
	quiz_button.custom_minimum_size = QUIZ_BUTTON_SIZE
	quiz_button.size = QUIZ_BUTTON_SIZE
	quiz_button.add_theme_font_size_override("font_size", 16)
	quiz_button.visible = false
	quiz_button.pressed.connect(_on_quiz_button_pressed)
	layer.add_child(quiz_button)

	if punnett_square:
		punnett_square.set_summary_hidden(true)


func _on_quiz_button_pressed() -> void:
	if GeneticsState.can_breed() and quiz_punnett_square:
		quiz_punnett_square.display_quiz(
			GeneticsState.selected_parent_a_id,
			GeneticsState.selected_parent_b_id
		)


func _show_clutch(clutch: Array[Dictionary]) -> void:
	## Compact the prediction panel, then fit the clutch panel into the space beside it
	prediction_panel.set_compact(true)
	var left: float = PREDICT_POSITION.x + prediction_panel.desired_width() + PANEL_GAP
	var width: float = CLUTCH_RIGHT - left
	clutch_panel.position = Vector2(left, CLUTCH_TOP)
	clutch_panel.custom_minimum_size = Vector2(width, 0)
	clutch_panel.size = Vector2(width, 0)
	clutch_panel.show_clutch(clutch, prediction_panel.exact_ratios())


func _reset_prediction_loop() -> void:
	## Back to step 2: no prediction, summary hidden, Hatch locked
	if prediction_panel:
		prediction_panel.reset()
	if clutch_panel:
		clutch_panel.reset()
	if quiz_button:
		quiz_button.visible = false
	breeding_panel.set_prediction_checked(false)
	if punnett_square:
		punnett_square.set_summary_hidden(true)


func _begin_prediction() -> void:
	## Called after a parent changes: restart the loop for the new pair (if it is a valid pair)
	var a_id: int = GeneticsState.selected_parent_a_id
	var b_id: int = GeneticsState.selected_parent_b_id
	if GeneticsState.can_breed():
		if prediction_panel.visible and prediction_panel.parent_a_id == a_id and prediction_panel.parent_b_id == b_id:
			return
		_reset_prediction_loop()
		prediction_panel.setup(a_id, b_id)
		quiz_button.visible = true
	else:
		_reset_prediction_loop()


func _on_prediction_checked(_all_right: bool) -> void:
	## Step 3: reveal the Punnett summary and unlock Hatch
	if punnett_square:
		punnett_square.set_summary_hidden(false)
	breeding_panel.set_prediction_checked(true)


func _on_keep_requested(genotype: Dictionary) -> void:
	## Step 5: keep one hatchling (the other 19 are discarded)
	var offspring_id: int = GeneticsState.add_offspring(
		genotype,
		GeneticsState.selected_parent_a_id,
		GeneticsState.selected_parent_b_id
	)
	if offspring_id >= 0:
		breed_player.play()
		_update_generation_label()


func _run_screenshot_gate(path: String) -> void:
	## Debug: select the starters (or DG_HET=1 heterozygous parents), predict, check, hatch, screenshot, quit.
	## DG_STAGE=pre stops after the prediction is entered but before it is checked.
	GeneticsState.set_seed(42)
	await get_tree().process_frame
	await get_tree().process_frame
	var a_id: int = 0
	var b_id: int = 1
	if OS.get_environment("DG_HET") == "1":
		var het: Dictionary = {"fire": ["F", "f"], "wings": ["W", "w"]}
		a_id = GeneticsState.add_dragon(het, "Ember")
		b_id = GeneticsState.add_dragon(het, "Spark")
		await get_tree().process_frame
	_on_parent_a_selected(a_id)
	_on_parent_b_selected(b_id)
	await get_tree().process_frame
	var sample: Array[int] = []
	if GeneticsState.current_level == 1:
		sample.append_array([12, 4])
	else:
		sample.append_array([9, 3, 3, 1])
	var trait_ids: Array[String] = []
	for trait_id: String in GeneticsState.get_trait_ids():
		trait_ids.append(trait_id)
	var classes: Array[String] = PredictionLogic.phenotype_classes(GeneticsState.traits, trait_ids)
	for i: int in range(classes.size()):
		prediction_panel.pick(classes[i], sample[i])
	await get_tree().process_frame
	if OS.get_environment("DG_STAGE") != "pre":
		prediction_panel.check()
		await get_tree().process_frame
		_on_breed_requested()
	for i: int in range(3):
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	var err: int = image.save_png(path)
	print("DG_SHOT saved %s (err %d)" % [path, err])
	get_tree().quit()


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
	_ensure_quiz_square()
	if GeneticsState.selected_parent_a_id >= 0 and GeneticsState.selected_parent_b_id >= 0:
		if punnett_square:
			punnett_square.display_cross(
				GeneticsState.selected_parent_a_id,
				GeneticsState.selected_parent_b_id
			)
		if quiz_punnett_square:
			quiz_punnett_square.visible = false
	else:
		if punnett_square:
			punnett_square.hide_square()
		if quiz_punnett_square:
			quiz_punnett_square.visible = false
	_begin_prediction()


func _on_breed_requested() -> void:
	## Step 4: hatch a clutch of 20 (nothing is added to the collection until one is kept)
	if not GeneticsState.can_breed() or not prediction_panel.is_checked():
		return
	
	var a_id: int = GeneticsState.selected_parent_a_id
	var b_id: int = GeneticsState.selected_parent_b_id
	var clutch: Array[Dictionary] = GeneticsState.breed_clutch(a_id, b_id, CLUTCH_SIZE)
	if clutch.is_empty():
		return
	breed_player.play()
	_show_clutch(clutch)


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
	_reset_prediction_loop()
	if punnett_square:
		punnett_square.hide_square()
	if quiz_punnett_square:
		quiz_punnett_square.visible = false
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
		if GeneticsState.is_fire_breather(dragon.get("id", -1)):
			fire_count += 1
		else:
			no_fire_count += 1
	if total > 9: 
		fire_emoji.position = fire_emoji_pos + EMOJI_SHIFT 
		if fire_count > 9:
			smoke_emoji.position = smoke_emoji_pos + EMOJI_SHIFT + EMOJI_SHIFT 
		else:
			smoke_emoji.position = smoke_emoji_pos + EMOJI_SHIFT
	else:
		fire_emoji.position = fire_emoji_pos 
		smoke_emoji.position = smoke_emoji_pos

	generation_label.text = "Dragons: %d |       Fire: %d |        No Fire: %d" % [total, fire_count, no_fire_count]


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
	_reset_prediction_loop()
	if punnett_square:
		punnett_square.hide_square()
	if quiz_punnett_square:
		quiz_punnett_square.visible = false
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


func _ensure_quiz_square() -> void:
	if quiz_punnett_square == null:
		var node := get_node_or_null("CanvasLayer/QuizSquare")
		if node:
			quiz_punnett_square = node
		else:
			push_warning("QuizPunnettSquare node not found; check scene tree path.")
