extends Node
## GeneticsState - Singleton managing dragon collection and genetics calculations
##
## Educational Purpose: This singleton handles all Mendelian inheritance logic,
## allowing students to breed dragons and observe how alleles pass from parents
## to offspring following predictable patterns.

signal dragon_added(dragon_id: int)
signal breeding_complete(offspring_id: int)
signal collection_reset()

## Dragon collection - all dragons currently in the game
var dragon_collection: Array[Dictionary] = []

## Next available ID for new dragons
var _next_dragon_id: int = 0

## Currently selected parents for breeding
var selected_parent_a_id: int = -1
var selected_parent_b_id: int = -1

## Trait definitions for Level 1 (Fire-breathing only)
## F = Fire-breathing (dominant), f = no fire (recessive)
const TRAITS := {
	"fire": {
		"name": "Fire-Breathing",
		"dominant_allele": "F",
		"recessive_allele": "f",
		"dominant_phenotype": "fire-breather",
		"recessive_phenotype": "no fire"
	}
}


func _ready() -> void:
	# Initialize with starter dragons when game begins
	_spawn_starter_dragons()


func _spawn_starter_dragons() -> void:
	## Spawn the P generation: one FF (pure fire) and one ff (pure no-fire)
	## This models Mendel's original pea plant crosses
	add_dragon({"fire": ["F", "F"]}, "Blaze")    # Homozygous dominant
	add_dragon({"fire": ["f", "f"]}, "Frost")    # Homozygous recessive


func add_dragon(genotype: Dictionary, dragon_name: String = "") -> int:
	## Add a new dragon to the collection
	## Returns the dragon's ID
	
	var dragon_id := _next_dragon_id
	_next_dragon_id += 1
	
	# Normalize allele order (capital letters first)
	var normalized_genotype := _normalize_genotype(genotype)
	
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
		var trait_def: Dictionary = TRAITS.get(trait_id, {})
		
		if trait_def.is_empty():
			continue
		
		# Complete dominance: presence of dominant allele determines phenotype
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
	
	# Create the offspring
	var offspring_id := add_dragon(offspring_genotype)
	
	breeding_complete.emit(offspring_id)
	
	return offspring_id


func _calculate_offspring_genotype(genotype_a: Dictionary, genotype_b: Dictionary) -> Dictionary:
	## Mendelian inheritance: randomly select one allele from each parent per trait
	
	var offspring_genotype := {}
	
	for trait_id in genotype_a.keys():
		var alleles_a: Array = genotype_a[trait_id]
		var alleles_b: Array = genotype_b[trait_id]
		
		# Randomly pick one allele from each parent
		var from_a: String = alleles_a[randi() % 2]
		var from_b: String = alleles_b[randi() % 2]
		
		offspring_genotype[trait_id] = [from_a, from_b]
	
	return offspring_genotype


func build_punnett_square(parent_a_id: int, parent_b_id: int, trait_id: String) -> Array:
	## Build a 2x2 Punnett square for a single trait
	## Returns array of arrays: [[top-left, top-right], [bottom-left, bottom-right]]
	
	var parent_a := get_dragon(parent_a_id)
	var parent_b := get_dragon(parent_b_id)
	
	if parent_a.is_empty() or parent_b.is_empty():
		return []
	
	var alleles_a: Array = parent_a["genotype"].get(trait_id, [])
	var alleles_b: Array = parent_b["genotype"].get(trait_id, [])
	
	if alleles_a.is_empty() or alleles_b.is_empty():
		return []
	
	# Build 2x2 grid
	# Parent A's alleles go across the top
	# Parent B's alleles go down the left side
	var square := []
	
	for b_allele in alleles_b:
		var row := []
		for a_allele in alleles_a:
			# Combine alleles, normalized (capital first)
			var combined := _normalize_allele_pair(a_allele, b_allele)
			row.append(combined)
		square.append(row)
	
	return square


func get_punnett_probabilities(punnett_square: Array, trait_id: String) -> Dictionary:
	## Calculate phenotype probabilities from a Punnett square
	## Returns: {"fire-breather": 0.75, "no fire": 0.25} for example
	
	var trait_def: Dictionary = TRAITS.get(trait_id, {})
	if trait_def.is_empty() or punnett_square.is_empty():
		return {}
	
	var total_cells := 0
	var phenotype_counts := {}
	
	for row in punnett_square:
		for cell in row:
			total_cells += 1
			
			# Determine phenotype for this genotype
			var genotype := {trait_id: cell}
			var phenotype := calculate_phenotype(genotype)
			var phenotype_value: String = phenotype.get(trait_id, "unknown")
			
			if phenotype_value not in phenotype_counts:
				phenotype_counts[phenotype_value] = 0
			phenotype_counts[phenotype_value] += 1
	
	# Convert to probabilities
	var probabilities := {}
	for pheno in phenotype_counts.keys():
		probabilities[pheno] = float(phenotype_counts[pheno]) / float(total_cells)
	
	return probabilities


func _normalize_genotype(genotype: Dictionary) -> Dictionary:
	## Ensure alleles are in standard order (capital letters first)
	
	var normalized := {}
	
	for trait_id in genotype.keys():
		var alleles: Array = genotype[trait_id]
		normalized[trait_id] = _normalize_allele_pair(alleles[0], alleles[1])
	
	return normalized


func _normalize_allele_pair(allele1: String, allele2: String) -> Array:
	## Put capital letter first: ["f", "F"] becomes ["F", "f"]
	
	if allele1 == allele1.to_upper() and allele2 == allele2.to_lower():
		return [allele1, allele2]
	elif allele2 == allele2.to_upper() and allele1 == allele1.to_lower():
		return [allele2, allele1]
	else:
		# Both same case, return as-is
		return [allele1, allele2]


func _determine_generation(dragon_id: int) -> int:
	## Simple generation tracking: starters are gen 0
	if dragon_id < 2:
		return 0  # P generation
	else:
		return 1  # For MVP, all bred dragons are "F1" (simplified)


func select_parent_a(dragon_id: int) -> void:
	## Set a dragon as Parent A for breeding
	selected_parent_a_id = dragon_id


func select_parent_b(dragon_id: int) -> void:
	## Set a dragon as Parent B for breeding
	selected_parent_b_id = dragon_id


func clear_selection() -> void:
	## Clear both parent selections
	selected_parent_a_id = -1
	selected_parent_b_id = -1


func can_breed() -> bool:
	## Check if breeding is possible (both parents selected and different)
	return (
		selected_parent_a_id >= 0 and
		selected_parent_b_id >= 0 and
		selected_parent_a_id != selected_parent_b_id
	)


func reset() -> void:
	## Reset to initial state (for new class period)
	dragon_collection.clear()
	_next_dragon_id = 0
	clear_selection()
	_spawn_starter_dragons()
	collection_reset.emit()


func get_genotype_string(dragon_id: int, trait_id: String = "fire") -> String:
	## Get human-readable genotype string like "Ff" or "FF"
	var dragon := get_dragon(dragon_id)
	if dragon.is_empty():
		return ""
	
	var alleles: Array = dragon["genotype"].get(trait_id, [])
	if alleles.is_empty():
		return ""
	
	return alleles[0] + alleles[1]


func is_fire_breather(dragon_id: int) -> bool:
	## Quick check if dragon breathes fire
	var dragon := get_dragon(dragon_id)
	if dragon.is_empty():
		return false
	
	return dragon["phenotype"].get("fire", "") == "fire-breather"
