extends Control
class_name PunnettSquareUI
## PunnettSquareUI - Displays Punnett squares for mono- and dihybrid inheritance
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

var current_trait_id: String = ""
var last_parent_a_id: int = -1
var last_parent_b_id: int = -1
const DIHYBRID_CELL_COUNT := 16
const MONOHYBRID_CELL_COUNT := 4

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
	
	var traits := GeneticsState.get_trait_ids()
	if traits.size() >= 2 and GeneticsState.current_level > 1:
		_display_dihybrid(parent_a_id, parent_b_id, traits[0], traits[1])
	else:
		_display_monohybrid(parent_a_id, parent_b_id, _get_active_trait_id())


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
	var trait_ids: Array = GeneticsState.get_trait_ids()
	if current_trait_id.is_empty() and trait_ids.size() > 0:
		current_trait_id = trait_ids[0]


func _on_trait_selected(index: int) -> void:
	pass


func _get_active_trait_id() -> String:
	if current_trait_id.is_empty():
		var ids := GeneticsState.get_trait_ids()
		if ids.size() > 0:
			current_trait_id = ids[0]
	return current_trait_id


func _display_monohybrid(parent_a_id: int, parent_b_id: int, trait_id: String) -> void:
	if trait_id.is_empty():
		visible = false
		return
	
	var parent_a: Dictionary = GeneticsState.get_dragon(parent_a_id)
	var parent_b: Dictionary = GeneticsState.get_dragon(parent_b_id)
	var alleles_a: Array = parent_a["genotype"].get(trait_id, [])
	var alleles_b: Array = parent_b["genotype"].get(trait_id, [])
	
	if alleles_a.size() < 2 or alleles_b.size() < 2:
		visible = false
		return
	
	grid_container.columns = 2
	_clear_cells()
	
	parent_a_label.text = "     %s             %s" % [alleles_a[0], alleles_a[1]]
	parent_b_label.text = "%s\n\n%s" % [alleles_b[0], alleles_b[1]]
	
	var punnett: Array = GeneticsState.build_punnett_square(parent_a_id, parent_b_id, trait_id)
	if punnett.is_empty():
		visible = false
		return
	
	var cell_index := 0
	for row in punnett:
		for genotype_array in row:
			if cell_index < MONOHYBRID_CELL_COUNT and cell_index < cells.size():
				var genotype_str: String = genotype_array[0] + genotype_array[1]
				cells[cell_index].text = "\n" + genotype_str
				cells[cell_index].add_theme_color_override("font_color", _get_genotype_color(genotype_str))
			cell_index += 1
	
	var probs: Dictionary = GeneticsState.get_punnett_probabilities(punnett, trait_id)
	_display_probabilities(probs)
	title_label.text = "Punnett Square: %s" % GeneticsState.get_trait_display_name(trait_id)
	visible = true
	_hide_unused_cells(MONOHYBRID_CELL_COUNT)


func _display_dihybrid(parent_a_id: int, parent_b_id: int, trait_a: String, trait_b: String) -> void:
	grid_container.columns = 4
	_clear_cells()
	
	var parent_a: Dictionary = GeneticsState.get_dragon(parent_a_id)
	var parent_b: Dictionary = GeneticsState.get_dragon(parent_b_id)
	var gametes_a := GeneticsState.build_gametes(parent_a["genotype"], trait_a, trait_b)
	var gametes_b := GeneticsState.build_gametes(parent_b["genotype"], trait_a, trait_b)
	
	if gametes_a.size() < 4 or gametes_b.size() < 4:
		visible = false
		return
	
	parent_a_label.text = "  %s    |    %s    |    %s    |    %s" % [
		_gamete_string(gametes_a[0], [trait_a, trait_b]),
		_gamete_string(gametes_a[1], [trait_a, trait_b]),
		_gamete_string(gametes_a[2], [trait_a, trait_b]),
		_gamete_string(gametes_a[3], [trait_a, trait_b])
	]
	parent_b_label.text = "%s\n\n%s\n\n%s\n\n%s" % [
		_gamete_string(gametes_b[0], [trait_a, trait_b]),
		_gamete_string(gametes_b[1], [trait_a, trait_b]),
		_gamete_string(gametes_b[2], [trait_a, trait_b]),
		_gamete_string(gametes_b[3], [trait_a, trait_b])
	]
	
	var punnett := GeneticsState.build_dihybrid_square(parent_a_id, parent_b_id, trait_a, trait_b)
	if punnett.is_empty():
		visible = false
		return
	
	var cell_index := 0
	for row in punnett:
		for geno_dict in row:
			if cell_index < DIHYBRID_CELL_COUNT and cell_index < cells.size():
				var a_pair: Array = geno_dict.get(trait_a, [])
				var b_pair: Array = geno_dict.get(trait_b, [])
				var txt := ""
				if a_pair.size() == 2:
					txt += "%s%s" % [a_pair[0], a_pair[1]]
				if b_pair.size() == 2:
					if not txt.is_empty():
						txt += "\n"
					txt += "%s%s" % [b_pair[0], b_pair[1]]
				cells[cell_index].text = txt
				cells[cell_index].add_theme_color_override("font_color", Color.WHITE)
			cell_index += 1
	
	var probs2 := GeneticsState.get_dihybrid_probabilities(punnett, trait_a, trait_b)
	_display_probabilities(probs2)
	title_label.text = "Punnett Square: %s + %s" % [
		GeneticsState.get_trait_display_name(trait_a),
		GeneticsState.get_trait_display_name(trait_b)
	]
	visible = true
	_hide_unused_cells(DIHYBRID_CELL_COUNT)

func _gamete_string(gamete: Dictionary, order: Array = []) -> String:
	var parts: Array[String] = []
	if order.is_empty():
		for key in gamete.keys():
			var alleles: Array = gamete[key]
			if alleles.size() >= 1:
				parts.append("%s" % alleles[0])
	else:
		for key in order:
			var alleles: Array = gamete.get(key, [])
			if alleles.size() >= 1:
				parts.append("%s" % alleles[0])
	return "".join(parts)


func _clear_cells() -> void:
	for i in range(cells.size()):
		cells[i].text = ""
		cells[i].add_theme_color_override("font_color", Color.WHITE)


func _hide_unused_cells(active_count: int) -> void:
	for i in range(cells.size()):
		cells[i].visible = i < active_count
