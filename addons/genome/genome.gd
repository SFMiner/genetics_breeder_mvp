class_name Genome
extends RefCounted
## Static Mendelian genetics primitives: meiosis, crosses, phenotype, Punnett, mutation.
##
## Genotype = Dictionary of locus_id (String) -> Array of exactly 2 allele tokens (String).
## Gamete  = Dictionary of locus_id (String) -> allele token (String).
## `rng` is duck-typed: any Object with randf() -> float and randi_range(from, to) -> int.

# === INTERNAL HELPERS ===

static func _plain_pair(canon: Array[String]) -> Array:
	var out: Array = []
	for token: String in canon:
		out.append(token)
	return out


## The genotype's pair for a locus (canonical order); default_pair() if missing or malformed.
static func _pair_of(locus: GenomeLocus, genotype: Dictionary) -> Array:
	var raw: Variant = genotype.get(locus.id, null)
	if raw is Array:
		var pair: Array = raw
		if pair.size() == 2:
			return _plain_pair(locus.canonical_pair(pair))
	return _plain_pair(locus.default_pair())


static func _locus(lib: GenomeLibrary, id: String) -> GenomeLocus:
	if not lib.loci.has(id):
		return null
	var locus: GenomeLocus = lib.loci[id]
	return locus


static func _known_ids(lib: GenomeLibrary, locus_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if locus_ids.is_empty():
		return lib.locus_ids()
	for id: String in locus_ids:
		if lib.loci.has(id):
			out.append(id)
		else:
			push_warning("Genome: unknown locus '%s' ignored" % id)
	return out


static func _mutate_allele(locus: GenomeLocus, allele: String, rng: Object, rate: float) -> String:
	var roll: float = rng.randf()
	if roll >= rate:
		return allele
	var others: Array[String] = []
	for candidate: String in locus.alleles:
		if candidate != allele:
			others.append(candidate)
	if others.is_empty():
		return allele
	var idx: int = rng.randi_range(0, others.size() - 1)
	return others[idx]


static func _gamete_for(lib: GenomeLibrary, genotype: Dictionary, rng: Object, mutation_rate: float, ids: Array[String]) -> Dictionary:
	var gamete: Dictionary = {}
	for id: String in ids:
		var locus: GenomeLocus = _locus(lib, id)
		if locus == null:
			continue
		var pair: Array = _pair_of(locus, genotype)
		var idx: int = rng.randi_range(0, 1)
		var allele: String = str(pair[idx])
		if mutation_rate > 0.0:
			allele = _mutate_allele(locus, allele, rng, mutation_rate)
		gamete[id] = allele
	return gamete


# === MEIOSIS / FERTILIZATION ===

## Meiosis: per locus, one allele chosen 50/50 (independent assortment, no linkage in v0.1).
## With mutation_rate > 0 each chosen allele mutates with that probability to a different
## allele of the same locus (uniform). Missing loci use default_pair().
static func make_gamete(lib: GenomeLibrary, genotype: Dictionary, rng: Object, mutation_rate: float = 0.0) -> Dictionary:
	return _gamete_for(lib, genotype, rng, mutation_rate, lib.locus_ids())


## Fuses two gametes into a canonical genotype. A locus missing from one gamete uses the
## locus's recessive default allele for that side.
static func fertilize(lib: GenomeLibrary, gamete_a: Dictionary, gamete_b: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: String in lib.locus_ids():
		if not gamete_a.has(id) and not gamete_b.has(id):
			continue
		var locus: GenomeLocus = _locus(lib, id)
		var fallback: Array[String] = locus.default_pair()
		var fb: String = ""
		if not fallback.is_empty():
			fb = fallback[0]
		var a: String = str(gamete_a.get(id, fb))
		var b: String = str(gamete_b.get(id, fb))
		var pair: Array = [a, b]
		out[id] = _plain_pair(locus.canonical_pair(pair))
	return out


## fertilize(make_gamete(a), make_gamete(b)). Empty locus_ids means the union of loci present in
## either parent (that exist in the library). Does NOT filter lethals; see is_viable().
static func cross(lib: GenomeLibrary, parent_a: Dictionary, parent_b: Dictionary, rng: Object, mutation_rate: float = 0.0, locus_ids: Array[String] = []) -> Dictionary:
	var ids: Array[String] = []
	if locus_ids.is_empty():
		for id: String in lib.locus_ids():
			if parent_a.has(id) or parent_b.has(id):
				ids.append(id)
	else:
		ids = _known_ids(lib, locus_ids)
	var ga: Dictionary = _gamete_for(lib, parent_a, rng, mutation_rate, ids)
	var gb: Dictionary = _gamete_for(lib, parent_b, rng, mutation_rate, ids)
	return fertilize(lib, ga, gb)


## Asexual reproduction: copies the genotype with per-allele mutation. Unknown loci pass through.
static func clone_with_mutation(lib: GenomeLibrary, genotype: Dictionary, rng: Object, mutation_rate: float) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in genotype.keys():
		var id: String = str(k)
		var locus: GenomeLocus = _locus(lib, id)
		var raw: Variant = genotype[k]
		if locus == null or not (raw is Array):
			out[id] = raw
			continue
		var pair: Array = _pair_of(locus, genotype)
		var result: Array = []
		for token: Variant in pair:
			var allele: String = str(token)
			if mutation_rate > 0.0:
				allele = _mutate_allele(locus, allele, rng, mutation_rate)
			result.append(allele)
		out[id] = _plain_pair(locus.canonical_pair(result))
	return out


# === RANDOM GENOTYPES ===

static func _draw_allele(locus: GenomeLocus, rng: Object, weights: Variant) -> String:
	if locus.alleles.is_empty():
		return ""
	if weights is Dictionary:
		var w: Dictionary = weights
		var total: float = 0.0
		for allele: String in locus.alleles:
			total += maxf(0.0, float(w.get(allele, 0.0)))
		if total > 0.0:
			var roll: float = rng.randf() * total
			var acc: float = 0.0
			for allele: String in locus.alleles:
				acc += maxf(0.0, float(w.get(allele, 0.0)))
				if roll < acc:
					return allele
			return locus.alleles[locus.alleles.size() - 1]
	var idx: int = rng.randi_range(0, locus.alleles.size() - 1)
	return locus.alleles[idx]


## Each allele drawn independently. allele_weights: locus_id -> {allele: weight}; default uniform.
static func random_genotype(lib: GenomeLibrary, rng: Object, locus_ids: Array[String] = [], allele_weights: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	for id: String in _known_ids(lib, locus_ids):
		var locus: GenomeLocus = _locus(lib, id)
		var weights: Variant = allele_weights.get(id, null)
		var a: String = _draw_allele(locus, rng, weights)
		var b: String = _draw_allele(locus, rng, weights)
		var pair: Array = [a, b]
		out[id] = _plain_pair(locus.canonical_pair(pair))
	return out


# === QUERIES ===

## False if any locus of the genotype is in a lethal state.
static func is_viable(lib: GenomeLibrary, genotype: Dictionary) -> bool:
	for k: Variant in genotype.keys():
		var locus: GenomeLocus = _locus(lib, str(k))
		if locus == null:
			continue
		var raw: Variant = genotype[k]
		if raw is Array:
			var pair: Array = raw
			if pair.size() == 2 and locus.is_lethal(pair):
				return false
	return true


## locus_id -> phenotype Dictionary for every known locus in the genotype.
static func phenotype(lib: GenomeLibrary, genotype: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in genotype.keys():
		var locus: GenomeLocus = _locus(lib, str(k))
		if locus == null:
			continue
		out[locus.id] = locus.phenotype_of(_pair_of(locus, genotype))
	return out


## Order-insensitive per-locus equality. Known loci missing on one side compare as default_pair();
## unknown loci compare by raw value.
static func genotypes_equal(lib: GenomeLibrary, a: Dictionary, b: Dictionary) -> bool:
	var ids: Array = []
	for k: Variant in a.keys():
		if not ids.has(k):
			ids.append(k)
	for k: Variant in b.keys():
		if not ids.has(k):
			ids.append(k)
	for k: Variant in ids:
		var locus: GenomeLocus = _locus(lib, str(k))
		if locus == null:
			if a.get(k, null) != b.get(k, null):
				return false
			continue
		if locus.genotype_key(_pair_of(locus, a)) != locus.genotype_key(_pair_of(locus, b)):
			return false
	return true


## Space-separated genotype keys, e.g. "Ff Ww". Empty locus_ids means the genotype's own loci.
static func display_genotype(lib: GenomeLibrary, genotype: Dictionary, locus_ids: Array[String] = []) -> String:
	var ids: Array[String] = []
	if locus_ids.is_empty():
		for k: Variant in genotype.keys():
			ids.append(str(k))
	else:
		ids = locus_ids
	var parts: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var locus: GenomeLocus = _locus(lib, id)
		if locus == null:
			continue
		parts.append(locus.genotype_key(_pair_of(locus, genotype)))
	return " ".join(parts)


## Space-separated phenotype keys (same joining as punnett()'s phenotype_key), e.g. "F w".
static func phenotype_key(lib: GenomeLibrary, genotype: Dictionary, locus_ids: Array[String] = []) -> String:
	var ids: Array[String] = []
	if locus_ids.is_empty():
		for k: Variant in genotype.keys():
			ids.append(str(k))
	else:
		ids = locus_ids
	var parts: PackedStringArray = PackedStringArray()
	for id: String in ids:
		var locus: GenomeLocus = _locus(lib, id)
		if locus == null:
			continue
		parts.append(locus.phenotype_key(_pair_of(locus, genotype)))
	return " ".join(parts)


# === EXACT PROBABILITIES ===

## All distinct gamete combinations with exact probabilities:
## [{"alleles": {locus: allele}, "probability": float}]. Homozygous loci contribute one allele (p=1).
static func gametes(lib: GenomeLibrary, genotype: Dictionary, locus_ids: Array[String]) -> Array[Dictionary]:
	var combos: Array[Dictionary] = []
	combos.append({"alleles": {}, "probability": 1.0})
	for id: String in _known_ids(lib, locus_ids):
		var locus: GenomeLocus = _locus(lib, id)
		var pair: Array = _pair_of(locus, genotype)
		var options: Array[String] = []
		options.append(str(pair[0]))
		if str(pair[1]) != str(pair[0]):
			options.append(str(pair[1]))
		var p_each: float = 1.0 / float(options.size())
		var next: Array[Dictionary] = []
		for combo: Dictionary in combos:
			for allele: String in options:
				var alleles_src: Dictionary = combo["alleles"]
				var merged: Dictionary = alleles_src.duplicate()
				merged[id] = allele
				var prob: float = float(combo["probability"]) * p_each
				next.append({"alleles": merged, "probability": prob})
		combos = next
	return combos


static func _outcome_less(x: Dictionary, y: Dictionary) -> bool:
	var px: float = x["probability"]
	var py: float = y["probability"]
	if absf(px - py) > 1e-12:
		return px > py
	var kx: String = x["genotype_key"]
	var ky: String = y["genotype_key"]
	return kx < ky


## Exact cross for 1..N loci. See docs/DESIGN.md for the full return shape.
static func punnett(lib: GenomeLibrary, parent_a: Dictionary, parent_b: Dictionary, locus_ids: Array[String]) -> Dictionary:
	var ids: Array[String] = _known_ids(lib, locus_ids)
	var rows: Array[Dictionary] = gametes(lib, parent_a, ids)
	var cols: Array[Dictionary] = gametes(lib, parent_b, ids)
	var cells: Array[Array] = []
	var by_key: Dictionary = {}
	for row: Dictionary in rows:
		var cell_row: Array = []
		for col: Dictionary in cols:
			var row_alleles: Dictionary = row["alleles"]
			var col_alleles: Dictionary = col["alleles"]
			var child: Dictionary = fertilize(lib, row_alleles, col_alleles)
			cell_row.append(child)
			var prob: float = float(row["probability"]) * float(col["probability"])
			var gkey: String = display_genotype(lib, child, ids)
			if by_key.has(gkey):
				var existing: Dictionary = by_key[gkey]
				existing["probability"] = float(existing["probability"]) + prob
			else:
				by_key[gkey] = {
					"genotype": child,
					"genotype_key": gkey,
					"phenotype_key": phenotype_key(lib, child, ids),
					"phenotype": phenotype(lib, child),
					"probability": prob,
					"viable": is_viable(lib, child),
				}
		cells.append(cell_row)
	var outcomes: Array[Dictionary] = []
	for k: Variant in by_key.keys():
		var outcome: Dictionary = by_key[k]
		outcomes.append(outcome)
	outcomes.sort_custom(_outcome_less)

	var lethal_fraction: float = 0.0
	var viable_totals: Dictionary = {}
	var viable_sum: float = 0.0
	for outcome: Dictionary in outcomes:
		var p: float = outcome["probability"]
		if bool(outcome["viable"]):
			var pk: String = outcome["phenotype_key"]
			viable_totals[pk] = float(viable_totals.get(pk, 0.0)) + p
			viable_sum += p
		else:
			lethal_fraction += p
	var ratios: Dictionary = {}
	if viable_sum > 0.0:
		for pk: Variant in viable_totals.keys():
			ratios[pk] = float(viable_totals[pk]) / viable_sum
	return {
		"rows": rows,
		"cols": cols,
		"cells": cells,
		"outcomes": outcomes,
		"phenotype_ratios": ratios,
		"lethal_fraction": lethal_fraction,
	}
