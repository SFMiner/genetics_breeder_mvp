class_name GenomeStats
extends RefCounted
## Goodness-of-fit helpers for predict-then-observe teaching UIs.

# === CONSTANTS ===

## Chi-square critical values at alpha = 0.05 for df 1..10.
const CRITICAL_05: Array[float] = [
	3.841, 5.991, 7.815, 9.488, 11.070, 12.592, 14.067, 15.507, 16.919, 18.307,
]
## z for the 95th percentile of the standard normal (Wilson-Hilferty approximation).
const Z_95: float = 1.6448536

# === CHI-SQUARE ===

## Critical value at alpha = 0.05: table for df 1..10, Wilson-Hilferty above. df < 1 -> 0.
static func critical_value_05(df: int) -> float:
	if df < 1:
		return 0.0
	if df <= CRITICAL_05.size():
		return CRITICAL_05[df - 1]
	var k: float = float(df)
	var h: float = 2.0 / (9.0 * k)
	var base: float = 1.0 - h + Z_95 * sqrt(h)
	return k * base * base * base


## observed: key -> int counts. expected_ratios: key -> float (normalized internally).
## Returns {"chi2", "df", "critical_05", "fits"}. Expected 0 with observed > 0 gives
## fits = false and chi2 = INF.
static func chi_square(observed: Dictionary, expected_ratios: Dictionary) -> Dictionary:
	var keys: Array = []
	for k: Variant in expected_ratios.keys():
		keys.append(k)
	for k: Variant in observed.keys():
		if not keys.has(k):
			keys.append(k)
	var total_obs: float = 0.0
	for k: Variant in observed.keys():
		total_obs += float(observed[k])
	var total_ratio: float = 0.0
	for k: Variant in expected_ratios.keys():
		total_ratio += maxf(0.0, float(expected_ratios[k]))

	var chi2: float = 0.0
	var categories: int = 0
	var impossible: bool = false
	for k: Variant in keys:
		var ratio: float = 0.0
		if total_ratio > 0.0:
			ratio = maxf(0.0, float(expected_ratios.get(k, 0.0))) / total_ratio
		var obs: float = float(observed.get(k, 0))
		if ratio <= 0.0:
			if obs > 0.0:
				impossible = true
			continue
		categories += 1
		var expected: float = ratio * total_obs
		if expected > 0.0:
			chi2 += (obs - expected) * (obs - expected) / expected
	var df: int = maxi(categories - 1, 0)
	var critical: float = critical_value_05(df)
	if impossible:
		return {"chi2": INF, "df": df, "critical_05": critical, "fits": false}
	return {"chi2": chi2, "df": df, "critical_05": critical, "fits": chi2 <= critical}


# === OBSERVED COUNTS ===

## Observed phenotype counts keyed like Genome.punnett()["phenotype_ratios"]. Counts every
## genotype passed in; filter with Genome.is_viable() first if lethals should be excluded.
static func count_phenotypes(lib: GenomeLibrary, genotypes: Array, locus_ids: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for g: Variant in genotypes:
		if not (g is Dictionary):
			continue
		var genotype: Dictionary = g
		var key: String = Genome.phenotype_key(lib, genotype, locus_ids)
		counts[key] = int(counts.get(key, 0)) + 1
	return counts
