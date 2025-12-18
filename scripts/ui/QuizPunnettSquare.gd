extends Control
class_name QuizPunnettSquareUI
## QuizPunnettSquareUI - Input-based Punnett quiz for mono- and dihybrid crosses.

@onready var title_label: Label = $TitleLabel
@onready var parent_a_label: Label = $ParentALabel
@onready var parent_b_label: Label = $ParentBLabel
@onready var grid_container: GridContainer = $GridContainer
@onready var submit_button: Button = $SubmitButton
@onready var close_button: Button = $CloseButton
@onready var result_label: Label = $ResultLabel

const DIHYBRID_CELL_COUNT := 16
const MONOHYBRID_CELL_COUNT := 4

const COLOR_NEUTRAL := Color(0.2, 0.2, 0.25, 0.7)
const COLOR_CORRECT := Color(0.2, 0.6, 0.2, 0.7)
const COLOR_INCORRECT := Color(0.6, 0.2, 0.2, 0.7)

@export var mono_position_x: float = 918.0
@export var mono_width: float = 350.0
@export var dihybrid_position_x: float = 500.0
@export var dihybrid_width: float = 760.0

var cells: Array[Dictionary] = [] # {panel, style, geno, pheno, expected_geno, expected_pheno, expected_label}
var last_parent_a_id: int = -1
var last_parent_b_id: int = -1

func _ready() -> void:
	_build_cells()
	submit_button.pressed.connect(_on_submit_pressed)
	close_button.pressed.connect(_on_close_pressed)
	visible = false


func display_quiz(parent_a_id: int, parent_b_id: int) -> void:
	_ensure_refs()
	last_parent_a_id = parent_a_id
	last_parent_b_id = parent_b_id
	_clear_cells_visuals()
	result_label.text = "Enter your guesses and submit."
	
	if parent_a_id < 0 or parent_b_id < 0:
		_hide_all_cells()
		return
	
	var parent_a := GeneticsState.get_dragon(parent_a_id)
	var parent_b := GeneticsState.get_dragon(parent_b_id)
	if parent_a.is_empty() or parent_b.is_empty():
		_hide_all_cells()
		return
	
	var traits := GeneticsState.get_trait_ids()
	if traits.size() >= 2 and GeneticsState.current_level > 1:
		position.x = dihybrid_position_x
		size.x = dihybrid_width
		_setup_dihybrid(parent_a, parent_b, traits[0], traits[1])
	else:
		position.x = mono_position_x
		size.x = mono_width
		_setup_monohybrid(parent_a, parent_b, _get_active_trait())
	visible = true


func _build_cells() -> void:
	grid_container.columns = 4
	for i in range(DIHYBRID_CELL_COUNT):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(70, 70)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_NEUTRAL
		panel.add_theme_stylebox_override("panel", style)
		
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.theme = panel.theme
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var geno := LineEdit.new()
		geno.placeholder_text = "Genotype"
		geno.max_length = 8
		geno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var pheno := OptionButton.new()
		pheno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var expected_label := Label.new()
		expected_label.text = ""
		expected_label.add_theme_font_size_override("font_size", 11)
		expected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		vbox.add_child(geno)
		vbox.add_child(pheno)
		vbox.add_child(expected_label)
		panel.add_child(vbox)
		grid_container.add_child(panel)
		
		cells.append({
			"panel": panel,
			"style": style,
			"geno": geno,
			"pheno": pheno,
			"expected_geno": "",
			"expected_pheno": "",
			"expected_label": expected_label
		})


func _setup_monohybrid(parent_a: Dictionary, parent_b: Dictionary, trait_id: String) -> void:
	if trait_id.is_empty():
		_hide_all_cells()
		return
	
	var alleles_a: Array = parent_a["genotype"].get(trait_id, [])
	var alleles_b: Array = parent_b["genotype"].get(trait_id, [])
	if alleles_a.size() < 2 or alleles_b.size() < 2:
		_hide_all_cells()
		return
	
	parent_a_label.text = "              %s                    %s" % [alleles_a[0], alleles_a[1]]
	parent_b_label.text = "%s\n\n\n%s" % [alleles_b[0], alleles_b[1]]
	title_label.text = "Quiz Square: %s" % GeneticsState.get_trait_display_name(trait_id)
	
	var punnett := GeneticsState.build_punnett_square(parent_a["id"], parent_b["id"], trait_id)
	if punnett.is_empty():
		_hide_all_cells()
		return
	
	var pheno_options := _phenotype_options()
	grid_container.columns = 2
	_show_cells(MONOHYBRID_CELL_COUNT, 2)
	var idx := 0
	for row in punnett:
		for geno_arr in row:
			if idx >= MONOHYBRID_CELL_COUNT:
				break
			var geno_str = geno_arr[0] + geno_arr[1]
			var geno_dict = {trait_id: geno_arr}
			var pheno_dict : Dictionary = GeneticsState.calculate_phenotype(geno_dict)
			var pheno_str : String = _phenotype_string(pheno_dict)
			_assign_cell(idx, geno_str, pheno_str, pheno_options)
			idx += 1


func _setup_dihybrid(parent_a: Dictionary, parent_b: Dictionary, trait_a: String, trait_b: String) -> void:
	parent_a_label.text = ""
	parent_b_label.text = ""
	title_label.text = "Quiz Square: %s + %s" % [
		GeneticsState.get_trait_display_name(trait_a),
		GeneticsState.get_trait_display_name(trait_b)
	]
	
	var gametes_a := GeneticsState.build_gametes(parent_a["genotype"], trait_a, trait_b)
	var gametes_b := GeneticsState.build_gametes(parent_b["genotype"], trait_a, trait_b)
	if gametes_a.size() < 4 or gametes_b.size() < 4:
		_hide_all_cells()
		return
	
	parent_a_label.text = "%s                |                %s                |                %s                |                %s" % [
		_gamete_string(gametes_a[0], [trait_a, trait_b]),
		_gamete_string(gametes_a[1], [trait_a, trait_b]),
		_gamete_string(gametes_a[2], [trait_a, trait_b]),
		_gamete_string(gametes_a[3], [trait_a, trait_b])
	]
	parent_b_label.text = "%s\n\n\n%s\n\n\n%s\n\n\n%s" % [
		_gamete_string(gametes_b[0], [trait_a, trait_b]),
		_gamete_string(gametes_b[1], [trait_a, trait_b]),
		_gamete_string(gametes_b[2], [trait_a, trait_b]),
		_gamete_string(gametes_b[3], [trait_a, trait_b])
	]
	
	var punnett := GeneticsState.build_dihybrid_square(parent_a["id"], parent_b["id"], trait_a, trait_b)
	if punnett.is_empty():
		_hide_all_cells()
		return
	
	var pheno_options := _phenotype_options()
	grid_container.columns = 4
	_show_cells(DIHYBRID_CELL_COUNT, 4)
	var idx := 0
	for row in punnett:
		for geno_dict in row:
			if idx >= DIHYBRID_CELL_COUNT:
				break
			var geno_str := _combined_genotype_string(geno_dict, [trait_a, trait_b])
			var pheno_dict := GeneticsState.calculate_phenotype(geno_dict)
			var pheno_str := _phenotype_string(pheno_dict)
			_assign_cell(idx, geno_str, pheno_str, pheno_options)
			idx += 1


func _assign_cell(index: int, expected_geno: String, expected_pheno: String, pheno_options: Array) -> void:
	if index < 0 or index >= cells.size():
		return
	var cell: Dictionary = cells[index]
	var panel: PanelContainer = cell["panel"]
	var geno: LineEdit = cell["geno"]
	var pheno: OptionButton = cell["pheno"]
	var expected_label: Label = cell["expected_label"]
	
	panel.show()
	geno.text = ""
	geno.placeholder_text = "Genotype"
	pheno.clear()
	for opt in pheno_options:
		pheno.add_item(opt)
	pheno.selected = -1
	expected_label.text = ""
	cell["expected_geno"] = expected_geno
	cell["expected_pheno"] = expected_pheno
	_set_cell_color(cell, COLOR_NEUTRAL)


func _phenotype_options() -> Array:
	var traits := GeneticsState.get_trait_ids()
	var combos: Array[String] = [""]
	for trait_id in traits:
		var trait_def: Dictionary = GeneticsState.traits.get(trait_id, {})
		var dom = trait_def.get("dominant_phenotype", "")
		var rec = trait_def.get("recessive_phenotype", "")
		var next: Array[String] = []
		for base in combos:
			if not dom.is_empty():
				next.append(_combine_pheno(base, dom))
			if not rec.is_empty():
				next.append(_combine_pheno(base, rec))
		combos = next
	return combos


func _phenotype_string(pheno: Dictionary) -> String:
	var parts: Array[String] = []
	for trait_id in GeneticsState.get_trait_ids():
		var p = pheno.get(trait_id, "")
		if not p.is_empty():
			parts.append(p)
	return ", ".join(parts)


func _combined_genotype_string(geno: Dictionary, order: Array) -> String:
	var parts: Array[String] = []
	for trait_id in order:
		var pair: Array = geno.get(trait_id, [])
		if pair.size() == 2:
			parts.append("%s%s" % [pair[0], pair[1]])
	return "|".join(parts)


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


func _clear_cells_visuals() -> void:
	for i in range(cells.size()):
		var cell: Dictionary = cells[i]
		_set_cell_color(cell, COLOR_NEUTRAL)
		cell["expected_label"].text = ""


func _hide_all_cells() -> void:
	for i in range(cells.size()):
		var cell = cells[i]
		cell["panel"].hide()
	visible = false


func _show_cells(count: int, columns: int) -> void:
	grid_container.columns = columns
	for i in range(cells.size()):
		if i < count:
			cells[i]["panel"].show()
		else:
			cells[i]["panel"].hide()


func _set_cell_color(cell: Dictionary, color: Color) -> void:
	var style: StyleBoxFlat = cell.get("style") as StyleBoxFlat
	if style:
		style.bg_color = color


func _on_submit_pressed() -> void:
	var score := 0
	var total := 0
	for cell in cells:
		if not cell["panel"].visible:
			continue
		total += 1
		var expected_geno: String = cell["expected_geno"]
		var expected_pheno: String = cell["expected_pheno"]
		var geno_input: String = _normalize_geno_input(cell["geno"].text, expected_geno)
		var pheno_input: String = _normalize_pheno_input(cell["pheno"])
		
		var geno_ok := _normalize_geno_input(expected_geno, expected_geno) == geno_input
		var pheno_ok := _normalize_pheno_input(expected_pheno) == pheno_input
		var correct := geno_ok and pheno_ok
		if correct:
			_set_cell_color(cell, COLOR_CORRECT)
		else:
			_set_cell_color(cell, COLOR_INCORRECT)
		cell["expected_label"].text = "Ans: %s | %s" % [expected_geno, expected_pheno]
		if correct:
			score += 1
	
	result_label.text = "Score: %d / %d" % [score, total]


func _on_close_pressed() -> void:
	visible = false
	_clear_cells_visuals()


func _normalize_geno_input(text: String, expected_pattern: String = "") -> String:
	var cleaned := text.strip_edges().replace(" ", "").replace("\n", "")
	cleaned = cleaned.replace("|", "").replace("/", "").replace("-", "")
	if cleaned.is_empty():
		return ""
	
	var trait_count := 1
	if not expected_pattern.is_empty():
		var segments := expected_pattern.split("|", false)
		if segments.size() > 1:
			trait_count = segments.size()
	
	var alleles_per_trait := 2
	var expected_len : int = trait_count * alleles_per_trait
	var usable_len : int = min(cleaned.length(), expected_len)
	if usable_len % alleles_per_trait != 0:
		usable_len -= usable_len % alleles_per_trait
	if usable_len <= 0:
		return ""
	
	var parts: Array[String] = []
	for i in range(0, usable_len, alleles_per_trait):
		var allele_a := cleaned.substr(i, 1)
		var allele_b := cleaned.substr(i + 1, 1)
		parts.append(_normalize_allele_pair_string(allele_a, allele_b))
	return "|".join(parts)


func _normalize_allele_pair_string(allele_a: String, allele_b: String) -> String:
	var a_upper := allele_a == allele_a.to_upper()
	var b_upper := allele_b == allele_b.to_upper()
	
	if a_upper and not b_upper:
		return allele_a + allele_b
	elif b_upper and not a_upper:
		return allele_b + allele_a
	return allele_a + allele_b


func _normalize_pheno_input(input) -> String:
	if input is OptionButton:
		var ob := input as OptionButton
		var selected_text := ""
		if ob.selected >= 0:
			selected_text = ob.get_item_text(ob.selected)
		return _normalize_pheno_input(selected_text)
	elif input is String:
		return input.strip_edges().to_lower()
	return ""


func _get_active_trait() -> String:
	var ids := GeneticsState.get_trait_ids()
	if ids.size() > 0:
		return ids[0]
	return ""


func _combine_pheno(base: String, addition: String) -> String:
	if base.strip_edges() == "":
		return addition
	return "%s, %s" % [base, addition]


func _ensure_refs() -> void:
	if not title_label:
		title_label = $TitleLabel
	if not parent_a_label:
		parent_a_label = $ParentALabel
	if not parent_b_label:
		parent_b_label = $ParentBLabel
	if not grid_container:
		grid_container = $GridContainer
	if not submit_button:
		submit_button = $SubmitButton
	if not close_button:
		close_button = $CloseButton
	if not result_label:
		result_label = $ResultLabel
