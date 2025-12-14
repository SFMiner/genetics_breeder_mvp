extends Control
class_name PunnettSquareUI
## PunnettSquareUI - Displays a 2x2 Punnett square for single-trait inheritance
##
## Educational Purpose: Shows students all possible offspring combinations
## and their probabilities, connecting parental alleles to offspring genotypes.

@onready var title_label: Label = $TitleLabel
@onready var parent_a_label: Label = $ParentALabel
@onready var parent_b_label: Label = $ParentBLabel
@onready var grid_container: GridContainer = $GridContainer
@onready var probability_label: Label = $ProbabilityLabel
@onready var trait_selector: OptionButton = $TraitSelector

## Cell references (populated on ready)
var cells: Array[Label] = []

var current_trait_id: String = ""
var last_parent_a_id: int = -1
var last_parent_b_id: int = -1

## Colors for genotype display
const COLOR_HOMOZYGOUS_DOM := Color(1.0, 0.5, 0.2)    # FF - bright orange
const COLOR_HETEROZYGOUS := Color(0.9, 0.6, 0.4)      # Ff - lighter orange
const COLOR_HOMOZYGOUS_REC := Color(0.4, 0.5, 0.7)    # ff - blue-gray


func _ready() -> void:
	# Get cell references from grid
	for child in grid_container.get_children():
		if child is Label:
			cells.append(child)
	
	trait_selector.item_selected.connect(_on_trait_selected)
	refresh_trait_options(true)
	
	# Start hidden until parents selected
	visible = false


func display_cross(parent_a_id: int, parent_b_id: int) -> void:
	## Show the Punnett square for a cross between two dragons
	last_parent_a_id = parent_a_id
	last_parent_b_id = parent_b_id
	
	if parent_a_id < 0 or parent_b_id < 0:
		visible = false
		return
	
	var parent_a: Dictionary = GeneticsState.get_dragon(parent_a_id)
	var parent_b: Dictionary = GeneticsState.get_dragon(parent_b_id)
	
	if parent_a.is_empty() or parent_b.is_empty():
		visible = false
		return
	
	var trait_id := _get_active_trait_id()
	if trait_id.is_empty():
		visible = false
		return
	
	# Get alleles for the active trait
	var alleles_a: Array = parent_a["genotype"].get(trait_id, [])
	var alleles_b: Array = parent_b["genotype"].get(trait_id, [])
	
	if alleles_a.size() < 2 or alleles_b.size() < 2:
		visible = false
		return
	
	# Update parent labels (alleles across top and down side)
	parent_a_label.text = "      %s       %s" % [alleles_a[0], alleles_a[1]]
	parent_b_label.text = "%s\n\n%s" % [alleles_b[0], alleles_b[1]]
	
	# Build and display the Punnett square
	var punnett: Array = GeneticsState.build_punnett_square(parent_a_id, parent_b_id, trait_id)
	
	if punnett.is_empty():
		visible = false
		return
	
	# Fill in the 4 cells
	var cell_index := 0
	for row in punnett:
		for genotype_array in row:
			if cell_index < cells.size():
				var genotype_str: String = genotype_array[0] + genotype_array[1]
				cells[cell_index].text = genotype_str
				cells[cell_index].add_theme_color_override("font_color", _get_genotype_color(genotype_str))
			cell_index += 1
	
	# Calculate and display probabilities
	var probs: Dictionary = GeneticsState.get_punnett_probabilities(punnett, trait_id)
	_display_probabilities(probs)
	
	# Update title
	title_label.text = "Punnett Square: %s" % GeneticsState.get_trait_display_name(trait_id)
	
	visible = true


func _get_genotype_color(genotype: String) -> Color:
	## Return color based on genotype
	match genotype:
		"FF", "WW":
			return COLOR_HOMOZYGOUS_DOM
		"Ff", "fF", "Ww", "wW":
			return COLOR_HETEROZYGOUS
		"ff", "ww":
			return COLOR_HOMOZYGOUS_REC
		_:
			return Color.WHITE


func _display_probabilities(probs: Dictionary) -> void:
	## Show phenotype probabilities as text
	var text := "Predicted Offspring:\n"
	
	for phenotype in probs.keys():
		var percent: int = int(probs[phenotype] * 100)
		text += "%s: %d%%\n" % [phenotype.capitalize(), percent]
	
	probability_label.text = text


func hide_square() -> void:
	## Hide the Punnett square
	visible = false


func refresh_trait_options(reset_trait: bool = false) -> void:
	if reset_trait:
		current_trait_id = ""
	trait_selector.clear()
	var trait_ids: Array = GeneticsState.get_trait_ids()
	for trait_id in trait_ids:
		trait_selector.add_item(GeneticsState.get_trait_display_name(trait_id))
		var idx := trait_selector.get_item_count() - 1
		trait_selector.set_item_metadata(idx, trait_id)
	
	if current_trait_id.is_empty() and trait_ids.size() > 0:
		current_trait_id = trait_ids[0]
	
	# Select current trait in the dropdown
	for i in range(trait_selector.get_item_count()):
		if trait_selector.get_item_metadata(i) == current_trait_id:
			trait_selector.select(i)
			break


func _on_trait_selected(index: int) -> void:
	var meta = trait_selector.get_item_metadata(index)
	if meta is String:
		current_trait_id = meta
	if last_parent_a_id >= 0 and last_parent_b_id >= 0:
		display_cross(last_parent_a_id, last_parent_b_id)


func _get_active_trait_id() -> String:
	if current_trait_id.is_empty():
		var ids := GeneticsState.get_trait_ids()
		if ids.size() > 0:
			current_trait_id = ids[0]
	return current_trait_id
