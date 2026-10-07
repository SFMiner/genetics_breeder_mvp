extends SceneTree
## Headless tests for the predict-then-breed loop (PredictionLogic + GeneticsState clutch API).
## Run: ../Godot_v4.5-stable_win64.exe --headless --path . --script tests/test_prediction.gd

# Autoloads are not global identifiers in --script mode; bound to the live node in _init().
var GeneticsState: Node = null

var _passed: int = 0
var _failed: int = 0
var _signal_ids: Array[int] = []


func _init() -> void:
	await get_root().ready
	GeneticsState = root.get_node("/root/GeneticsState")

	_test_phenotype_classes()
	_test_fraction_options_and_labels()
	_test_exact_ratios()
	_test_grade()
	_test_breed_clutch()
	_test_add_offspring()
	_test_breed_still_works()
	_test_score_resets()

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
	GeneticsState.set_level(level)
	GeneticsState.reset()


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _ids(level: int) -> Array[String]:
	var ids: Array[String] = []
	for trait_id: String in GeneticsState.get_trait_ids():
		ids.append(trait_id)
	return ids


func _on_breeding_complete(offspring_id: int) -> void:
	_signal_ids.append(offspring_id)


# === PHENOTYPE CLASSES ===

func _test_phenotype_classes() -> void:
	_fresh(1)
	var ids1: Array[String] = _ids(1)
	var classes1: Array[String] = PredictionLogic.phenotype_classes(GeneticsState.traits, ids1)
	_check("L1 has 2 classes", classes1.size() == 2)
	_check("L1 classes in stable order", classes1 == ["fire", "no fire"])

	_fresh(2)
	var ids2: Array[String] = _ids(2)
	var classes2: Array[String] = PredictionLogic.phenotype_classes(GeneticsState.traits, ids2)
	_check("L2 has 4 classes", classes2.size() == 4)
	_check("L2 classes in stable order", classes2 == ["fire, no flight", "fire, flight", "no fire, no flight", "no fire, flight"])

	# Keys must match get_dihybrid_probabilities (every class can occur from FfWw x FfWw)
	var dihet: int = GeneticsState.add_dragon({"fire": ["F", "f"], "wings": ["W", "w"]})
	var sq: Array = GeneticsState.build_dihybrid_square(dihet, dihet, "fire", "wings")
	var probs: Dictionary = GeneticsState.get_dihybrid_probabilities(sq, "fire", "wings")
	var keys_match: bool = probs.size() == classes2.size()
	for c: String in classes2:
		keys_match = keys_match and probs.has(c)
	_check("L2 classes match get_dihybrid_probabilities keys", keys_match)

	var class_of: String = PredictionLogic.class_of({"fire": "no fire", "wings": "flight"}, ids2)
	_check("class_of joins like the dihybrid key", class_of == "no fire, flight")


# === FRACTIONS ===

func _test_fraction_options_and_labels() -> void:
	_check("L1 options", PredictionLogic.fraction_options(1) == [0, 4, 8, 12, 16])
	_check("L2 options", PredictionLogic.fraction_options(2) == [0, 1, 2, 3, 4, 6, 8, 9, 12, 16])
	_check("label 0", PredictionLogic.fraction_label(0) == "0")
	_check("label all", PredictionLogic.fraction_label(16) == "all")
	_check("label 1/16", PredictionLogic.fraction_label(1) == "1/16")
	_check("label 2 reduces to 1/8", PredictionLogic.fraction_label(2) == "1/8")
	_check("label 3/16", PredictionLogic.fraction_label(3) == "3/16")
	_check("label 4 reduces to 1/4", PredictionLogic.fraction_label(4) == "1/4")
	_check("label 6 reduces to 3/8", PredictionLogic.fraction_label(6) == "3/8")
	_check("label 8 reduces to 1/2", PredictionLogic.fraction_label(8) == "1/2")
	_check("label 9/16", PredictionLogic.fraction_label(9) == "9/16")
	_check("label 12 reduces to 3/4", PredictionLogic.fraction_label(12) == "3/4")
	var all_labels_ok: bool = true
	for n: int in PredictionLogic.fraction_options(2):
		all_labels_ok = all_labels_ok and not PredictionLogic.fraction_label(n).is_empty()
	_check("every L2 option has a label", all_labels_ok)


# === EXACT RATIOS ===

func _ratios(geno_a: Dictionary, geno_b: Dictionary, level: int) -> Dictionary:
	_fresh(level)
	return PredictionLogic.exact_ratios(GeneticsState.library, geno_a, geno_b, _ids(level))


func _ratios_match(got: Dictionary, expected: Dictionary) -> bool:
	if got.size() != expected.size():
		return false
	for k: String in expected.keys():
		if not got.has(k) or not _approx(float(got[k]), float(expected[k])):
			return false
	return true


func _test_exact_ratios() -> void:
	var het: Dictionary = {"fire": ["F", "f"]}
	var r1: Dictionary = _ratios(het, het, 1)
	_check("Ff x Ff = 3/4, 1/4", _ratios_match(r1, {"fire": 0.75, "no fire": 0.25}))

	var r2: Dictionary = _ratios({"fire": ["F", "F"]}, {"fire": ["f", "f"]}, 1)
	_check("FF x ff = all fire", _ratios_match(r2, {"fire": 1.0}))

	var dihet: Dictionary = {"fire": ["F", "f"], "wings": ["W", "w"]}
	var r3: Dictionary = _ratios(dihet, dihet, 2)
	_check("FfWw x FfWw = 9:3:3:1", _ratios_match(r3, {
		"fire, no flight": 9.0 / 16.0,
		"fire, flight": 3.0 / 16.0,
		"no fire, no flight": 3.0 / 16.0,
		"no fire, flight": 1.0 / 16.0
	}))

	var r4: Dictionary = _ratios(dihet, {"fire": ["f", "f"], "wings": ["w", "w"]}, 2)
	_check("FfWw x ffww = 1/4 each", _ratios_match(r4, {
		"fire, no flight": 0.25,
		"fire, flight": 0.25,
		"no fire, no flight": 0.25,
		"no fire, flight": 0.25
	}))

	var r5: Dictionary = _ratios(dihet, {"fire": ["F", "f"], "wings": ["w", "w"]}, 2)
	_check("FfWw x Ffww = 3/8, 3/8, 1/8, 1/8", _ratios_match(r5, {
		"fire, no flight": 3.0 / 8.0,
		"fire, flight": 3.0 / 8.0,
		"no fire, no flight": 1.0 / 8.0,
		"no fire, flight": 1.0 / 8.0
	}))


# === GRADE ===

func _test_grade() -> void:
	var exact: Dictionary = {"fire": 0.75, "no fire": 0.25}

	var good: Dictionary = PredictionLogic.grade({"fire": 12, "no fire": 4}, exact)
	_check("grade all right", bool(good["all_right"]))
	var good_rows: Dictionary = good["rows"]
	_check("grade row detail", good_rows["fire"] == {"predicted": 12, "correct": 12, "right": true})

	var bad: Dictionary = PredictionLogic.grade({"fire": 8, "no fire": 8}, exact)
	var bad_rows: Dictionary = bad["rows"]
	_check("grade one wrong -> not all right", not bool(bad["all_right"]))
	_check("grade wrong rows flagged", not bool(bad_rows["fire"]["right"]) and not bool(bad_rows["no fire"]["right"]))
	_check("grade reports the correct numerator", int(bad_rows["fire"]["correct"]) == 12)

	var one_wrong: Dictionary = PredictionLogic.grade({"fire": 12, "no fire": 4, "extra": 0}, exact)
	_check("class missing from exact counts as 0 (right when predicted 0)", bool(one_wrong["all_right"]))
	var missing_wrong: Dictionary = PredictionLogic.grade({"fire": 12, "no fire": 0, "extra": 4}, exact)
	var mw_rows: Dictionary = missing_wrong["rows"]
	_check("class missing from exact is wrong when predicted > 0", not bool(mw_rows["extra"]["right"]) and int(mw_rows["extra"]["correct"]) == 0)

	var only_fire: Dictionary = PredictionLogic.grade({"fire": 16, "no fire": 0}, {"fire": 1.0})
	_check("missing 'no fire' key = 0 -> all right", bool(only_fire["all_right"]))


# === CLUTCH API ===

func _test_breed_clutch() -> void:
	_fresh(2)
	var a: int = GeneticsState.add_dragon({"fire": ["F", "f"], "wings": ["W", "w"]})
	var b: int = GeneticsState.add_dragon({"fire": ["F", "f"], "wings": ["W", "w"]})
	var before: int = GeneticsState.dragon_collection.size()
	GeneticsState.set_seed(77)
	var clutch_one: Array[Dictionary] = GeneticsState.breed_clutch(a, b, 20)
	_check("clutch has 20 genotypes", clutch_one.size() == 20)
	_check("clutch does not change the collection", GeneticsState.dragon_collection.size() == before)
	var shaped: bool = true
	for geno: Dictionary in clutch_one:
		shaped = shaped and geno.has("fire") and geno.has("wings")
	_check("clutch genotypes carry every trait", shaped)
	GeneticsState.set_seed(77)
	var clutch_two: Array[Dictionary] = GeneticsState.breed_clutch(a, b, 20)
	_check("same seed gives the same clutch", clutch_one == clutch_two)
	GeneticsState.set_seed(78)
	var clutch_three: Array[Dictionary] = GeneticsState.breed_clutch(a, b, 20)
	_check("different seed gives a different clutch", clutch_one != clutch_three)
	var invalid: Array[Dictionary] = GeneticsState.breed_clutch(a, 9999, 20)
	_check("invalid parent gives an empty clutch", invalid.is_empty())


func _test_add_offspring() -> void:
	_fresh(1)
	var a: int = 0
	var b: int = 1
	_signal_ids.clear()
	GeneticsState.breeding_complete.connect(_on_breeding_complete)
	var before: int = GeneticsState.dragon_collection.size()
	var kid_id: int = GeneticsState.add_offspring({"fire": ["f", "F"]}, a, b)
	GeneticsState.breeding_complete.disconnect(_on_breeding_complete)
	_check("add_offspring adds exactly one dragon", GeneticsState.dragon_collection.size() == before + 1)
	_check("add_offspring returns the new id", kid_id >= 0 and not GeneticsState.get_dragon(kid_id).is_empty())
	_check("add_offspring emits breeding_complete once with that id", _signal_ids == [kid_id])
	var kid: Dictionary = GeneticsState.get_dragon(kid_id)
	_check("add_offspring sets the parents", kid.get("parents", []) == [a, b])
	_check("add_offspring normalizes the genotype", kid["genotype"] == {"fire": ["F", "f"]})
	_check("add_offspring is generation 1", int(kid["generation"]) == 1)
	var count_after: int = GeneticsState.dragon_collection.size()
	var bad_id: int = GeneticsState.add_offspring({"fire": ["F", "f"]}, a, 9999)
	_check("add_offspring with invalid parent returns -1 and adds nothing", bad_id == -1 and GeneticsState.dragon_collection.size() == count_after)


func _test_breed_still_works() -> void:
	_fresh(1)
	GeneticsState.set_seed(5)
	var kid_id: int = GeneticsState.breed(0, 1)
	var kid: Dictionary = GeneticsState.get_dragon(kid_id)
	_check("breed() still returns a dragon", kid_id >= 0 and not kid.is_empty())
	_check("breed() records parents", kid.get("parents", []) == [0, 1])
	_check("breed() FF x ff gives Ff", kid["genotype"] == {"fire": ["F", "f"]})


func _test_score_resets() -> void:
	_fresh(1)
	GeneticsState.record_prediction(true)
	GeneticsState.record_prediction(false)
	_check("score counts predictions", GeneticsState.predictions_made == 2 and GeneticsState.predictions_right == 1)
	GeneticsState.reset()
	_check("reset clears the score", GeneticsState.predictions_made == 0 and GeneticsState.predictions_right == 0)
