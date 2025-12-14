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

## Cell references (populated on ready)
var cells: Array[Label] = []

## Colors for genotype display
const COLOR_HOMOZYGOUS_DOM := Color(1.0, 0.5, 0.2)    # FF - bright orange
const COLOR_HETEROZYGOUS := Color(0.9, 0.6, 0.4)      # Ff - lighter orange
const COLOR_HOMOZYGOUS_REC := Color(0.4, 0.5, 0.7)    # ff - blue-gray


func _ready() -> void:
	# Get cell references from grid
	for child in grid_container.get_children():
		if child is Label:
			cells.append(child)
	
	# Start hidden until parents selected
	visible = false


func display_cross(parent_a_id: int, parent_b_id: int) -> void:
	## Show the Punnett square for a cross between two dragons
	
	if parent_a_id < 0 or parent_b_id < 0:
		visible = false
		return
	
	var parent_a: Dictionary = GeneticsState.get_dragon(parent_a_id)
	var parent_b: Dictionary = GeneticsState.get_dragon(parent_b_id)
	
	if parent_a.is_empty() or parent_b.is_empty():
		visible = false
		return
	
	# Get alleles for fire trait
	var alleles_a: Array = parent_a["genotype"].get("fire", [])
	var alleles_b: Array = parent_b["genotype"].get("fire", [])
	
	if alleles_a.size() < 2 or alleles_b.size() < 2:
		visible = false
		return
	
	# Update parent labels (alleles across top and down side)
	parent_a_label.text = "      %s       %s" % [alleles_a[0], alleles_a[1]]
	parent_b_label.text = "%s\n\n%s" % [alleles_b[0], alleles_b[1]]
	
	# Build and display the Punnett square
	var punnett: Array = GeneticsState.build_punnett_square(parent_a_id, parent_b_id, "fire")
	
	if punnett.is_empty():
		visible = false
		return
	
	# Fill in the 4 cells
	# Grid is: [0][1]
	#          [2][3]
	# Punnett is: [[top-left, top-right], [bottom-left, bottom-right]]
	
	var cell_index := 0
	for row in punnett:
		for genotype_array in row:
			if cell_index < cells.size():
				var genotype_str: String = genotype_array[0] + genotype_array[1]
				cells[cell_index].text = genotype_str
				cells[cell_index].add_theme_color_override("font_color", _get_genotype_color(genotype_str))
			cell_index += 1
	
	# Calculate and display probabilities
	var probs: Dictionary = GeneticsState.get_punnett_probabilities(punnett, "fire")
	_display_probabilities(probs)
	
	# Update title
	title_label.text = "Punnett Square: Fire Trait"
	
	visible = true


func _get_genotype_color(genotype: String) -> Color:
	## Return color based on genotype
	match genotype:
		"FF":
			return COLOR_HOMOZYGOUS_DOM
		"Ff", "fF":
			return COLOR_HETEROZYGOUS
		"ff":
			return COLOR_HOMOZYGOUS_REC
		_:
			return Color.WHITE


func _display_probabilities(probs: Dictionary) -> void:
	## Show phenotype probabilities as text
	var text := "Predicted Offspring:\n"
	
	for phenotype in probs.keys():
		var percent: int = int(probs[phenotype] * 100)
		var icon: String = "🔥" if phenotype == "fire-breather" else "❄️"
		text += "%s %s: %d%%\n" % [icon, phenotype.capitalize(), percent]
	
	probability_label.text = text


func hide_square() -> void:
	## Hide the Punnett square
	visible = false
