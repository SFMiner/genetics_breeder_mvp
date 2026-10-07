extends RefCounted
class_name PredictionLogic
## PredictionLogic - Pure, static helpers for the predict-then-breed loop
##
## Educational Purpose: Students commit to a prediction (in 16ths) from the Punnett
## square before seeing the answer. These helpers list the phenotype classes, build
## the fraction choices, compute the exact ratios and grade a prediction.
## No scene or autoload access, so everything here is testable headless.

const DENOMINATOR: int = 16
const LEVEL_1_OPTIONS: Array[int] = [0, 4, 8, 12, 16]
const LEVEL_2_OPTIONS: Array[int] = [0, 1, 2, 3, 4, 6, 8, 9, 12, 16]
const CLASS_SEPARATOR: String = ", "


# === PHENOTYPE CLASSES ===

static func phenotype_classes(traits: Dictionary, trait_ids: Array[String]) -> Array[String]:
	## Every phenotype combination, dominant phenotype first, in the same format as the
	## dihybrid keys ("fire, no flight"). First trait varies slowest.
	var classes: Array[String] = []
	classes.append("")
	for trait_id: String in trait_ids:
		var trait_def: Dictionary = traits.get(trait_id, {})
		if trait_def.is_empty():
			continue
		var names: Array[String] = []
		names.append(str(trait_def["dominant_phenotype"]))
		names.append(str(trait_def["recessive_phenotype"]))
		var next: Array[String] = []
		for prefix: String in classes:
			for pheno_name: String in names:
				var joined: String = pheno_name if prefix.is_empty() else prefix + CLASS_SEPARATOR + pheno_name
				next.append(joined)
		classes = next
	if classes.size() == 1 and classes[0].is_empty():
		classes.clear()
	return classes


static func class_of(phenotype: Dictionary, trait_ids: Array[String]) -> String:
	## Class string for one dragon's phenotype dictionary ({trait_id: phenotype name})
	var parts: Array[String] = []
	for trait_id: String in trait_ids:
		parts.append(str(phenotype.get(trait_id, "")))
	return CLASS_SEPARATOR.join(parts)


# === FRACTIONS ===

static func fraction_options(level: int) -> Array[int]:
	## Numerators over 16 offered as buttons for the level
	var options: Array[int] = []
	var source: Array[int] = LEVEL_1_OPTIONS if level <= 1 else LEVEL_2_OPTIONS
	for n: int in source:
		options.append(n)
	return options


static func fraction_label(numerator_16ths: int) -> String:
	## Reduced fraction text: "0", "1/4", "3/4", "all"
	if numerator_16ths <= 0:
		return "0"
	if numerator_16ths >= DENOMINATOR:
		return "all"
	var divisor: int = _gcd(numerator_16ths, DENOMINATOR)
	@warning_ignore("integer_division")
	var top: int = numerator_16ths / divisor
	@warning_ignore("integer_division")
	var bottom: int = DENOMINATOR / divisor
	return "%d/%d" % [top, bottom]


static func _gcd(a: int, b: int) -> int:
	var x: int = absi(a)
	var y: int = absi(b)
	while y != 0:
		var t: int = y
		y = x % y
		x = t
	return maxi(x, 1)


# === EXACT RATIOS AND GRADING ===

static func exact_ratios(lib: GenomeLibrary, parent_a_geno: Dictionary, parent_b_geno: Dictionary, trait_ids: Array[String]) -> Dictionary:
	## class string -> exact probability, from Genome.punnett (missing class = 0)
	var punnett: Dictionary = Genome.punnett(lib, parent_a_geno, parent_b_geno, trait_ids)
	var ratios: Dictionary = punnett["phenotype_ratios"]
	var out: Dictionary = {}
	for key: String in ratios.keys():
		var tokens: PackedStringArray = key.split(" ")
		var parts: Array[String] = []
		for i: int in range(trait_ids.size()):
			var locus: GenomeLocus = lib.get_locus(trait_ids[i])
			var token: String = tokens[i] if i < tokens.size() else ""
			var data: Dictionary = locus.phenotypes.get(token, {})
			parts.append(str(data.get("name", token)))
		var class_name_str: String = CLASS_SEPARATOR.join(parts)
		out[class_name_str] = float(out.get(class_name_str, 0.0)) + float(ratios[key])
	return out


static func grade(prediction_16ths: Dictionary, exact: Dictionary) -> Dictionary:
	## { "rows": {class: {"predicted": int, "correct": int, "right": bool}}, "all_right": bool }
	var rows: Dictionary = {}
	var all_right: bool = true
	var keys: Array = prediction_16ths.keys()
	for k: Variant in exact.keys():
		if not keys.has(k):
			keys.append(k)
	for k: Variant in keys:
		var predicted: int = int(prediction_16ths.get(k, 0))
		var correct: int = roundi(float(exact.get(k, 0.0)) * float(DENOMINATOR))
		var right: bool = predicted == correct
		rows[k] = {"predicted": predicted, "correct": correct, "right": right}
		all_right = all_right and right
	return {"rows": rows, "all_right": all_right}
