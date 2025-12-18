extends Node
## GeneticsState - Singleton managing dragon collection and genetics calculations
##
## Educational Purpose: This singleton handles all Mendelian inheritance logic,
## allowing students to breed dragons and observe how alleles pass from parents
## to offspring following predictable patterns.

signal dragon_added(dragon_id: int)
signal dragon_renamed(dragon_id: int, new_name: String)
signal breeding_complete(offspring_id: int)
signal collection_reset()

## Dragon collection - all dragons currently in the game
var dragon_collection: Array[Dictionary] = []

## Next available ID for new dragons
var _next_dragon_id: int = 0

## Currently selected parents for breeding
var selected_parent_a_id: int = -1
var selected_parent_b_id: int = -1

## Trait library by level
const TRAIT_LIBRARY := {
	1: {
		"fire": {
			"name": "Fire-Breathing",
			"dominant_allele": "F",
			"recessive_allele": "f",
			"dominant_phenotype": "fire",
			"recessive_phenotype": "no fire"
		}
	},
	2: {
		"fire": {
			"name": "Fire-Breathing",
			"dominant_allele": "F",
			"recessive_allele": "f",
			"dominant_phenotype": "fire",
			"recessive_phenotype": "no fire"
		},
		"wings": {
			"name": "Wings",
			"dominant_allele": "W",
			"recessive_allele": "w",
			"dominant_phenotype": "no flight",
			"recessive_phenotype": "flight"
		}
	}
}

## Active trait set and level
var traits: Dictionary = {}
var current_level: int = 1


func _ready() -> void:
	_set_traits_for_level(current_level)
	_spawn_starter_dragons()


func _spawn_starter_dragons() -> void:
	## Spawn the P generation for the active level
	if current_level == 1:
		add_dragon({"fire": ["F", "F"]}, "Blaze")    # Homozygous dominant
		add_dragon({"fire": ["f", "f"]}, "Frost")    # Homozygous recessive
	else:
		# Level 2: include wings trait as well
		add_dragon({"fire": ["F", "F"], "wings": ["W", "W"]}, "Blaze")
		add_dragon({"fire": ["f", "f"], "wings": ["w", "w"]}, "Frost")


func add_dragon(genotype: Dictionary, dragon_name: String = "") -> int:
	## Add a new dragon to the collection
	## Returns the dragon's ID
	
	var dragon_id := _next_dragon_id
	_next_dragon_id += 1
	
	# Normalize allele order and ensure all traits are present
	var normalized_genotype := _ensure_all_traits(_normalize_genotype(genotype))
	
	# Calculate phenotype from genotype
	var phenotype := calculate_phenotype(normalized_genotype)
	
	# Generate name if not provided
	if dragon_name.is_empty():
		dragon_name = "Dragon %d" % dragon_id
	
	var dragon := {
		"id": dragon_id,
		"name": dragon_name,
		"genotype": normalized_genotype,
		"phenotype": phenotype,
		"generation": _determine_generation(dragon_id)
	}
	
	dragon_collection.append(dragon)
	dragon_added.emit(dragon_id)
	
	return dragon_id


func rename_dragon(dragon_id: int, new_name: String) -> void:
	## Rename a dragon by ID; no-op if not found or name empty
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		return
	
	for i in range(dragon_collection.size()):
		if dragon_collection[i]["id"] == dragon_id:
			dragon_collection[i]["name"] = trimmed
			dragon_renamed.emit(dragon_id, trimmed)
			return


func get_dragon(dragon_id: int) -> Dictionary:
	## Retrieve a dragon by its ID
	## Returns empty dictionary if not found
	
	for dragon in dragon_collection:
		if dragon["id"] == dragon_id:
			return dragon
	return {}


func calculate_phenotype(genotype: Dictionary) -> Dictionary:
	## Determine visible traits from genetic code
	## For complete dominance: one dominant allele = dominant phenotype
	
	var phenotype := {}
	
	for trait_id in genotype.keys():
		var alleles: Array = genotype[trait_id]
		var trait_def: Dictionary = traits.get(trait_id, {})
		
		if trait_def.is_empty():
			continue
		
		var dominant: String = trait_def["dominant_allele"]
		
		if dominant in alleles:
			phenotype[trait_id] = trait_def["dominant_phenotype"]
		else:
			phenotype[trait_id] = trait_def["recessive_phenotype"]
	
	return phenotype


func breed(parent_a_id: int, parent_b_id: int) -> int:
	## Breed two dragons and create offspring
	## Returns the offspring's ID, or -1 if breeding fails
	
	var parent_a := get_dragon(parent_a_id)
	var parent_b := get_dragon(parent_b_id)
	
	if parent_a.is_empty() or parent_b.is_empty():
		push_error("Cannot breed: invalid parent ID")
		return -1
	
	# Calculate offspring genotype
	var offspring_genotype := _calculate_offspring_genotype(
		parent_a["genotype"],
		parent_b["genotype"]
	)
	
	var offspring_id := add_dragon(offspring_genotype)
	
	breeding_complete.emit(offspring_id)
	
	return offspring_id


func _calculate_offspring_genotype(genotype_a: Dictionary, genotype_b: Dictionary) -> Dictionary:
	## Mendelian inheritance: randomly select one allele from each parent per trait
	
	var offspring_genotype := {}
	
	for trait_id in traits.keys():
		var alleles_a: Array = genotype_a.get(trait_id, [])
		var alleles_b: Array = genotype_b.get(trait_id, [])
		
		if alleles_a.size() < 2 or alleles_b.size() < 2:
			continue
		
		var from_a: String = alleles_a[randi() % 2]
		var from_b: String = alleles_b[randi() % 2]
		
		offspring_genotype[trait_id] = _normalize_allele_pair(from_a, from_b)
	
	return _ensure_all_traits(offspring_genotype)


func build_punnett_square(parent_a_id: int, parent_b_id: int, trait_id: String) -> Array:
	## Build a 2x2 Punnett square for a single trait
	
	var parent_a := get_dragon(parent_a_id)
	var parent_b := get_dragon(parent_b_id)
	
	if parent_a.is_empty() or parent_b.is_empty():
		return []
	
	var alleles_a: Array = parent_a["genotype"].get(trait_id, [])
	var alleles_b: Array = parent_b["genotype"].get(trait_id, [])
	
	if alleles_a.is_empty() or alleles_b.is_empty():
		return []
	
	var square := []
	for b_allele in alleles_b:
		var row := []
		for a_allele in alleles_a:
			var combined := _normalize_allele_pair(a_allele, b_allele)
			row.append(combined)
		square.append(row)
	return square


func build_gametes(genotype: Dictionary, trait_a: String, trait_b: String) -> Array:
	## Return the 4 gamete combinations for two traits (independent assortment)
	var alleles_a: Array = genotype.get(trait_a, [])
	var alleles_b: Array = genotype.get(trait_b, [])
	if alleles_a.size() < 2 or alleles_b.size() < 2:
		return []
	
	return [
		{trait_a: [alleles_a[0]], trait_b: [alleles_b[0]]},
		{trait_a: [alleles_a[0]], trait_b: [alleles_b[1]]},
		{trait_a: [alleles_a[1]], trait_b: [alleles_b[0]]},
		{trait_a: [alleles_a[1]], trait_b: [alleles_b[1]]}
	]


func build_dihybrid_square(parent_a_id: int, parent_b_id: int, trait_a: String, trait_b: String) -> Array:
	## Build a 4x4 Punnett square for two traits
	var parent_a := get_dragon(parent_a_id)
	var parent_b := get_dragon(parent_b_id)
	if parent_a.is_empty() or parent_b.is_empty():
		return []
	
	var gametes_a := build_gametes(parent_a["genotype"], trait_a, trait_b)
	var gametes_b := build_gametes(parent_b["genotype"], trait_a, trait_b)
	if gametes_a.size() < 4 or gametes_b.size() < 4:
		return []
	
	var square := []
	for g_b in gametes_b:
		var row := []
		for g_a in gametes_a:
			var geno := {}
			geno[trait_a] = _normalize_allele_pair(g_a[trait_a][0], g_b[trait_a][0])
			geno[trait_b] = _normalize_allele_pair(g_a[trait_b][0], g_b[trait_b][0])
			row.append(geno)
		square.append(row)
	return square


func get_punnett_probabilities(punnett_square: Array, trait_id: String) -> Dictionary:
	## Calculate phenotype probabilities from a Punnett square
	var trait_def: Dictionary = traits.get(trait_id, {})
	if trait_def.is_empty() or punnett_square.is_empty():
		return {}
	
	var total_cells := 0
	var phenotype_counts := {}
	
	for row in punnett_square:
		for cell in row:
			total_cells += 1
			var genotype := {trait_id: cell}
			var phenotype := calculate_phenotype(genotype)
			var phenotype_value: String = phenotype.get(trait_id, "unknown")
			
			if phenotype_value not in phenotype_counts:
				phenotype_counts[phenotype_value] = 0
			phenotype_counts[phenotype_value] += 1
	
	var probabilities := {}
	for pheno in phenotype_counts.keys():
		probabilities[pheno] = float(phenotype_counts[pheno]) / float(total_cells)
	
	return probabilities


func get_dihybrid_probabilities(punnett_square: Array, trait_a: String, trait_b: String) -> Dictionary:
	## Phenotype probabilities for two traits combined
	if punnett_square.is_empty():
		return {}
	
	var total := 0
	var counts := {}
	for row in punnett_square:
		for cell in row:
			total += 1
			var phenotype := calculate_phenotype(cell)
			var fire_pheno: String = phenotype.get(trait_a, "unknown")
			var wings_pheno: String = phenotype.get(trait_b, "unknown")
			var key := "%s, %s" % [fire_pheno, wings_pheno]
			if key not in counts:
				counts[key] = 0
			counts[key] += 1
	
	var probs := {}
	for k in counts.keys():
		probs[k] = float(counts[k]) / float(total)
	return probs


func _normalize_genotype(genotype: Dictionary) -> Dictionary:
	var normalized := {}
	for trait_id in genotype.keys():
		var alleles: Array = genotype[trait_id]
		if alleles.size() >= 2:
			normalized[trait_id] = _normalize_allele_pair(alleles[0], alleles[1])
	return normalized


func _normalize_allele_pair(allele1: String, allele2: String) -> Array:
	if allele1 == allele1.to_upper() and allele2 == allele2.to_lower():
		return [allele1, allele2]
	elif allele2 == allele2.to_upper() and allele1 == allele1.to_lower():
		return [allele2, allele1]
	else:
		return [allele1, allele2]


func _determine_generation(dragon_id: int) -> int:
	if dragon_id < 2:
		return 0
	else:
		return 1


func select_parent_a(dragon_id: int) -> void:
	selected_parent_a_id = dragon_id


func select_parent_b(dragon_id: int) -> void:
	selected_parent_b_id = dragon_id


func clear_selection() -> void:
	selected_parent_a_id = -1
	selected_parent_b_id = -1


func can_breed() -> bool:
	return (
		selected_parent_a_id >= 0 and
		selected_parent_b_id >= 0 and
		selected_parent_a_id != selected_parent_b_id
	)


func reset() -> void:
	dragon_collection.clear()
	_next_dragon_id = 0
	clear_selection()
	_spawn_starter_dragons()
	collection_reset.emit()


func get_genotype_string(dragon_id: int, trait_id: String = "fire") -> String:
	var dragon := get_dragon(dragon_id)
	if dragon.is_empty():
		return ""
	
	var alleles: Array = dragon["genotype"].get(trait_id, [])
	if alleles.is_empty():
		return ""
	
	return alleles[0] + alleles[1]


func is_fire_breather(dragon_id: int) -> bool:
	var dragon := get_dragon(dragon_id)
	if dragon.is_empty():
		return false
	var genotype: Dictionary = dragon.get("genotype", {})
	var trait_def: Dictionary = traits.get("fire", {})
	if not trait_def.is_empty():
		var alleles: Array = genotype.get("fire", [])
		return trait_def.get("dominant_allele", "F") in alleles
	return dragon.get("phenotype", {}).get("fire", "") == "fire"


func get_trait_ids() -> Array:
	var ids := traits.keys()
	ids.sort()
	return ids


func get_trait_display_name(trait_id: String) -> String:
	return traits.get(trait_id, {}).get("name", trait_id)


func get_genotype_summary(dragon_id: int) -> String:
	var dragon := get_dragon(dragon_id)
	if dragon.is_empty():
		return ""
	
	var parts: Array[String] = []
	for trait_id in get_trait_ids():
		var genotype: Array = dragon["genotype"].get(trait_id, [])
		if genotype.size() == 2:
			parts.append("%s: %s%s" % [trait_id.capitalize(), genotype[0], genotype[1]])
	return "\n".join(parts)


func get_phenotype_summary(dragon_id: int) -> String:
	var dragon := get_dragon(dragon_id)
	if dragon.is_empty():
		return ""
	
	var parts: Array[String] = []
	for trait_id in get_trait_ids():
		var pheno: String = dragon["phenotype"].get(trait_id, "")
		if not pheno.is_empty():
			parts.append("%s" % pheno)
	return "\n".join(parts)


func set_level(level: int) -> void:
	var clamped = clamp(level, 1, TRAIT_LIBRARY.size())
	if clamped == current_level:
		return
	current_level = clamped
	_set_traits_for_level(current_level)
	reset()


func _set_traits_for_level(level: int) -> void:
	traits = TRAIT_LIBRARY.get(level, TRAIT_LIBRARY[1]).duplicate(true)


func _ensure_all_traits(genotype: Dictionary) -> Dictionary:
	for trait_id in traits.keys():
		if not genotype.has(trait_id):
			var recessive: String = traits[trait_id]["recessive_allele"]
			genotype[trait_id] = [recessive, recessive]
	return genotype
