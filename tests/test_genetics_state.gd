extends SceneTree
## Headless tests for the GeneticsState autoload.
## Run: ../Godot_v4.5-stable_win64.exe --headless --path . --script tests/test_genetics_state.gd

# Autoloads are not global identifiers in --script mode; bound to the live node in _init().
var GeneticsState: Node = null

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	await get_root().ready
	GeneticsState = root.get_node("/root/GeneticsState")

	_run_shape_tests()
	_run_random_tests()

	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


# === HELPERS ===

func _check(test_name: String, condition: bool) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s" % test_name)


func _fresh(level: int) -> void:
	## Switch to a level and restore a clean collection (set_level is a no-op on the same level)
	GeneticsState.set_level(level)
	GeneticsState.reset()


func _add(genotype: Dictionary) -> int:
	var id: int = GeneticsState.add_dragon(genotype)
	return id


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


# === SHAPE / DETERMINISTIC TESTS ===

func _run_shape_tests() -> void:
	_test_phenotype_level_1()
	_test_phenotype_level_2()
	_test_punnett_shape()
	_test_punnett_probabilities()
	_test_dihybrid_square_and_probabilities()
	_test_gametes()


func _test_phenotype_level_1() -> void:
	_fresh(1)
	var expected: Dictionary = {"FF": "fire", "Ff": "fire", "ff": "no fire"}
	for key: String in expected.keys():
		var geno: Dictionary = {"fire": [key[0], key[1]]}
		var pheno: Dictionary = GeneticsState.calculate_phenotype(geno)
		_check("L1 phenotype %s" % key, pheno.get("fire", "") == expected[key])
	# allele order must not matter
	var swapped: Dictionary = GeneticsState.calculate_phenotype({"fire": ["f", "F"]})
	_check("L1 phenotype fF", swapped.get("fire", "") == "fire")
	# unknown trait is skipped
	var unknown: Dictionary = GeneticsState.calculate_phenotype({"scales": ["S", "S"]})
	_check("unknown trait skipped", unknown.is_empty())


func _test_phenotype_level_2() -> void:
	_fresh(2)
	var fire_expected: Dictionary = {"FF": "fire", "Ff": "fire", "ff": "no fire"}
	for key: String in fire_expected.keys():
		var pheno: Dictionary = GeneticsState.calculate_phenotype({"fire": [key[0], key[1]]})
		_check("L2 fire %s" % key, pheno.get("fire", "") == fire_expected[key])
	# wings is intentionally inverted: W (dominant) = "no flight"
	var wings_expected: Dictionary = {"WW": "no flight", "Ww": "no flight", "ww": "flight"}
	for key: String in wings_expected.keys():
		var pheno: Dictionary = GeneticsState.calculate_phenotype({"wings": [key[0], key[1]]})
		_check("L2 wings %s" % key, pheno.get("wings", "") == wings_expected[key])
	var both: Dictionary = GeneticsState.calculate_phenotype({"fire": ["F", "f"], "wings": ["w", "w"]})
	_check("L2 combined phenotype", both == {"fire": "fire", "wings": "flight"})
	# dragons store their phenotype
	var id: int = _add({"fire": ["f", "F"], "wings": ["w", "W"]})
	var dragon: Dictionary = GeneticsState.get_dragon(id)
	_check("add_dragon canonical genotype", dragon["genotype"] == {"fire": ["F", "f"], "wings": ["W", "w"]})
	_check("add_dragon phenotype", dragon["phenotype"] == {"fire": "fire", "wings": "no flight"})


func _test_punnett_shape() -> void:
	_fresh(1)
	var het: int = _add({"fire": ["F", "f"]})
	var rec: int = _add({"fire": ["f", "f"]})
	var dom: int = _add({"fire": ["F", "F"]})

	var sq: Array = GeneticsState.build_punnett_square(het, rec, "fire")
	_check("Ff x ff: 2 rows", sq.size() == 2)
	var shape_ok: bool = sq.size() == 2
	for row: Array in sq:
		shape_ok = shape_ok and row.size() == 2
		for cell: Array in row:
			shape_ok = shape_ok and cell.size() == 2
	_check("Ff x ff: 2x2 of 2-allele arrays", shape_ok)
	# rows follow parent B's alleles, columns parent A's alleles: [[Ff, ff], [Ff, ff]]
	_check("Ff x ff: cells", sq == [[["F", "f"], ["f", "f"]], [["F", "f"], ["f", "f"]]])

	var sq2: Array = GeneticsState.build_punnett_square(dom, rec, "fire")
	_check("FF x ff: full 2x2, all Ff", sq2 == [[["F", "f"], ["F", "f"]], [["F", "f"], ["F", "f"]]])

	var sq3: Array = GeneticsState.build_punnett_square(het, het, "fire")
	_check("Ff x Ff: cells", sq3 == [[["F", "F"], ["F", "f"]], [["F", "f"], ["f", "f"]]])

	_check("invalid parent gives empty", GeneticsState.build_punnett_square(999, het, "fire").is_empty())
	_check("missing trait gives empty", GeneticsState.build_punnett_square(het, het, "wings").is_empty())


func _test_punnett_probabilities() -> void:
	_fresh(1)
	var het: int = _add({"fire": ["F", "f"]})
	var rec: int = _add({"fire": ["f", "f"]})
	var dom: int = _add({"fire": ["F", "F"]})

	var probs: Dictionary = GeneticsState.get_punnett_probabilities(GeneticsState.build_punnett_square(het, het, "fire"), "fire")
	_check("Ff x Ff keys", probs.size() == 2 and probs.has("fire") and probs.has("no fire"))
	_check("Ff x Ff fire = 0.75", _approx(probs.get("fire", -1.0), 0.75))
	_check("Ff x Ff no fire = 0.25", _approx(probs.get("no fire", -1.0), 0.25))

	var probs2: Dictionary = GeneticsState.get_punnett_probabilities(GeneticsState.build_punnett_square(het, rec, "fire"), "fire")
	_check("Ff x ff 50/50", _approx(probs2.get("fire", -1.0), 0.5) and _approx(probs2.get("no fire", -1.0), 0.5))

	var probs3: Dictionary = GeneticsState.get_punnett_probabilities(GeneticsState.build_punnett_square(dom, rec, "fire"), "fire")
	_check("FF x ff all fire", probs3.size() == 1 and _approx(probs3.get("fire", -1.0), 1.0))

	var probs4: Dictionary = GeneticsState.get_punnett_probabilities(GeneticsState.build_punnett_square(rec, rec, "fire"), "fire")
	_check("ff x ff all no fire", probs4.size() == 1 and _approx(probs4.get("no fire", -1.0), 1.0))

	_check("empty square gives empty probs", GeneticsState.get_punnett_probabilities([], "fire").is_empty())
	_check("unknown trait gives empty probs", GeneticsState.get_punnett_probabilities([[["F", "f"]]], "scales").is_empty())


func _test_dihybrid_square_and_probabilities() -> void:
	_fresh(2)
	var dihet: int = _add({"fire": ["F", "f"], "wings": ["W", "w"]})
	var sq: Array = GeneticsState.build_dihybrid_square(dihet, dihet, "fire", "wings")
	var shape_ok: bool = sq.size() == 4
	for row: Array in sq:
		shape_ok = shape_ok and row.size() == 4
		for cell: Dictionary in row:
			var fire_pair: Array = cell.get("fire", [])
			var wings_pair: Array = cell.get("wings", [])
			shape_ok = shape_ok and fire_pair.size() == 2 and wings_pair.size() == 2
	_check("FfWw x FfWw: 4x4 cells of {fire, wings} pairs", shape_ok)
	_check("dihybrid first cell FFWW", sq[0][0] == {"fire": ["F", "F"], "wings": ["W", "W"]})
	_check("dihybrid last cell ffww", sq[3][3] == {"fire": ["f", "f"], "wings": ["w", "w"]})
	_check("dihybrid cell [0][1] FFWw", sq[0][1] == {"fire": ["F", "F"], "wings": ["W", "w"]})

	var probs: Dictionary = GeneticsState.get_dihybrid_probabilities(sq, "fire", "wings")
	_check("dihybrid 4 phenotype keys", probs.size() == 4)
	_check("dihybrid fire, no flight = 9/16", _approx(probs.get("fire, no flight", -1.0), 9.0 / 16.0))
	_check("dihybrid fire, flight = 3/16", _approx(probs.get("fire, flight", -1.0), 3.0 / 16.0))
	_check("dihybrid no fire, no flight = 3/16", _approx(probs.get("no fire, no flight", -1.0), 3.0 / 16.0))
	_check("dihybrid no fire, flight = 1/16", _approx(probs.get("no fire, flight", -1.0), 1.0 / 16.0))

	# homozygous parents still give the full 4x4 grid
	var pure_a: int = _add({"fire": ["F", "F"], "wings": ["W", "W"]})
	var pure_b: int = _add({"fire": ["f", "f"], "wings": ["w", "w"]})
	var sq2: Array = GeneticsState.build_dihybrid_square(pure_a, pure_b, "fire", "wings")
	var full: bool = sq2.size() == 4
	for row: Array in sq2:
		full = full and row.size() == 4
	_check("FFWW x ffww: full 4x4", full)
	var probs2: Dictionary = GeneticsState.get_dihybrid_probabilities(sq2, "fire", "wings")
	_check("FFWW x ffww: all fire, no flight", probs2.size() == 1 and _approx(probs2.get("fire, no flight", -1.0), 1.0))
	_check("dihybrid empty square gives empty probs", GeneticsState.get_dihybrid_probabilities([], "fire", "wings").is_empty())


func _test_gametes() -> void:
	_fresh(2)
	var geno: Dictionary = {"fire": ["F", "f"], "wings": ["W", "w"]}
	var gametes: Array = GeneticsState.build_gametes(geno, "fire", "wings")
	_check("4 gametes", gametes.size() == 4)
	_check("gamete order", gametes == [
		{"fire": ["F"], "wings": ["W"]},
		{"fire": ["F"], "wings": ["w"]},
		{"fire": ["f"], "wings": ["W"]},
		{"fire": ["f"], "wings": ["w"]}
	])
	_check("gametes need both traits", GeneticsState.build_gametes({"fire": ["F", "f"]}, "fire", "wings").is_empty())


# === RANDOMNESS-DEPENDENT TESTS ===

func _run_random_tests() -> void:
	_test_breed_valid_and_canonical()
	_test_monohybrid_ratio()
	_test_dihybrid_ratio()
	_test_seed_repeatability()
	_test_probabilities_match_engine()
	_test_isolation()


func _test_breed_valid_and_canonical() -> void:
	_fresh(2)
	GeneticsState.set_seed(7)
	var a: int = _add({"fire": ["F", "f"], "wings": ["W", "w"]})
	var b: int = _add({"fire": ["f", "F"], "wings": ["w", "W"]})
	var valid: bool = true
	var canonical: bool = true
	var allowed_fire: Array = [["F", "F"], ["F", "f"], ["f", "f"]]
	var allowed_wings: Array = [["W", "W"], ["W", "w"], ["w", "w"]]
	for i: int in range(200):
		var kid_id: int = GeneticsState.breed(a, b)
		var kid: Dictionary = GeneticsState.get_dragon(kid_id)
		var geno: Dictionary = kid["genotype"]
		valid = valid and kid_id >= 0 and geno["fire"] in allowed_fire and geno["wings"] in allowed_wings
		canonical = canonical and (geno["fire"][0] != "f" or geno["fire"][1] == "f")
		canonical = canonical and (geno["wings"][0] != "w" or geno["wings"][1] == "w")
		valid = valid and kid["phenotype"] == GeneticsState.calculate_phenotype(geno)
	_check("breed gives valid genotypes", valid)
	_check("breed gives canonical order (dominant first)", canonical)
	_check("breed with invalid parent returns -1", GeneticsState.breed(a, 9999) == -1)


func _test_monohybrid_ratio() -> void:
	_fresh(1)
	GeneticsState.set_seed(12345)
	var het: int = _add({"fire": ["F", "f"]})
	var kids: Array = []
	for i: int in range(2000):
		var kid_id: int = GeneticsState.breed(het, het)
		var geno: Dictionary = GeneticsState.get_dragon(kid_id)["genotype"]
		kids.append(geno)
	var loci: Array[String] = ["fire"]
	var lib: GenomeLibrary = GeneticsState.library
	var observed: Dictionary = GenomeStats.count_phenotypes(lib, kids, loci)
	var expected: Dictionary = {"F": 3.0, "f": 1.0}
	var fit: Dictionary = GenomeStats.chi_square(observed, expected)
	_check("Ff x Ff over 2000 fits 3:1 (chi2 %.2f)" % float(fit["chi2"]), bool(fit["fits"]))
	_check("Ff x Ff produced both phenotypes", observed.size() == 2)


func _test_dihybrid_ratio() -> void:
	_fresh(2)
	GeneticsState.set_seed(2024)
	var dihet: int = _add({"fire": ["F", "f"], "wings": ["W", "w"]})
	var kids: Array = []
	for i: int in range(3200):
		var kid_id: int = GeneticsState.breed(dihet, dihet)
		kids.append(GeneticsState.get_dragon(kid_id)["genotype"])
	var loci: Array[String] = ["fire", "wings"]
	var lib: GenomeLibrary = GeneticsState.library
	var observed: Dictionary = GenomeStats.count_phenotypes(lib, kids, loci)
	var expected: Dictionary = {"F W": 9.0, "F w": 3.0, "f W": 3.0, "f w": 1.0}
	var fit: Dictionary = GenomeStats.chi_square(observed, expected)
	_check("FfWw x FfWw over 3200 fits 9:3:3:1 (chi2 %.2f)" % float(fit["chi2"]), bool(fit["fits"]))


func _test_seed_repeatability() -> void:
	_fresh(2)
	var a: int = _add({"fire": ["F", "f"], "wings": ["W", "w"]})
	var b: int = _add({"fire": ["F", "f"], "wings": ["W", "w"]})
	var run_one: Array = []
	var run_two: Array = []
	GeneticsState.set_seed(99)
	for i: int in range(50):
		run_one.append(GeneticsState.get_dragon(GeneticsState.breed(a, b))["genotype"])
	GeneticsState.set_seed(99)
	for i: int in range(50):
		run_two.append(GeneticsState.get_dragon(GeneticsState.breed(a, b))["genotype"])
	_check("same seed gives same offspring sequence", run_one == run_two)
	GeneticsState.set_seed(100)
	var run_three: Array = []
	for i: int in range(50):
		run_three.append(GeneticsState.get_dragon(GeneticsState.breed(a, b))["genotype"])
	_check("different seed gives different sequence", run_one != run_three)


func _test_probabilities_match_engine() -> void:
	## The UI probabilities must equal the engine's exact Punnett ratios for every cross
	_fresh(2)
	var lib: GenomeLibrary = GeneticsState.library
	var fire_alleles: Array = [["F", "F"], ["F", "f"], ["f", "f"]]
	var wings_alleles: Array = [["W", "W"], ["W", "w"], ["w", "w"]]
	var mismatches: int = 0
	var loci: Array[String] = ["fire", "wings"]
	for fa: Array in fire_alleles:
		for fb: Array in fire_alleles:
			for wa: Array in wings_alleles:
				for wb: Array in wings_alleles:
					var geno_a: Dictionary = {"fire": fa, "wings": wa}
					var geno_b: Dictionary = {"fire": fb, "wings": wb}
					var id_a: int = _add(geno_a)
					var id_b: int = _add(geno_b)
					var sq: Array = GeneticsState.build_dihybrid_square(id_a, id_b, "fire", "wings")
					var probs: Dictionary = GeneticsState.get_dihybrid_probabilities(sq, "fire", "wings")
					var engine: Dictionary = Genome.punnett(lib, geno_a, geno_b, loci)
					var ratios: Dictionary = engine["phenotype_ratios"]
					var names: Dictionary = {"F": "fire", "f": "no fire", "W": "no flight", "w": "flight"}
					var mapped: Dictionary = {}
					for key: String in ratios.keys():
						var parts: PackedStringArray = key.split(" ")
						mapped["%s, %s" % [names[parts[0]], names[parts[1]]]] = ratios[key]
					if mapped.size() != probs.size():
						mismatches += 1
						continue
					for key: String in mapped.keys():
						if not _approx(float(mapped[key]), float(probs.get(key, -1.0))):
							mismatches += 1
	_check("dihybrid probabilities match Genome.punnett for all 81 crosses", mismatches == 0)


func _test_isolation() -> void:
	_fresh(1)
	_add({"fire": ["F", "f"]})
	GeneticsState.reset()
	_check("reset restores the two starters", GeneticsState.dragon_collection.size() == 2)
	_check("reset restarts ids at 0", GeneticsState.dragon_collection[0]["id"] == 0)
	GeneticsState.set_level(2)
	_check("level 2 library has both loci", GeneticsState.library.has_locus("fire") and GeneticsState.library.has_locus("wings"))
	GeneticsState.set_level(1)
	_check("level 1 library drops wings", not GeneticsState.library.has_locus("wings"))
