class_name GenomeLocus
extends Resource
## One gene (locus): its alleles, dominance behaviour and phenotype table.
##
## A genotype at this locus is an Array of exactly 2 allele tokens (Strings). Tokens may be
## multi-character ("D1", "Ho"); genotypes are never parsed character by character.

# === ENUMS ===

## COMPLETE covers simple dominance and multi-allele hierarchies (rank order).
## INCOMPLETE and CODOMINANT resolve identically (the heterozygote is its own phenotype);
## the distinction is kept for teaching labels.
enum Dominance { COMPLETE, INCOMPLETE, CODOMINANT }

# === FIELDS ===

@export var id: String = ""
@export var display_name: String = ""
## All allele tokens for this locus.
@export var alleles: Array[String] = []
@export var dominance: Dominance = Dominance.COMPLETE
## Most dominant first. Defaults to `alleles` order when empty.
@export var dominance_rank: Array[String] = []
## key -> Dictionary of phenotype data (should include "name"). Keys are canonical genotype
## strings ("Ff", "D1D2") or, for COMPLETE, the expressed allele ("F").
@export var phenotypes: Dictionary = {}
## Canonical genotype strings that are non-viable.
@export var lethal_genotypes: Array[String] = []
## Passthrough for game-specific fields (unlock_level, sprite_suffix, ...).
@export var metadata: Dictionary = {}

var _warned_keys: Dictionary = {}

const _NATIVE_KEYS: Array[String] = [
	"id", "key", "display_name", "name", "alleles", "dominance", "dominance_type",
	"dominance_rank", "phenotypes", "lethal_genotypes", "metadata",
]

# === RANKING ===

## Full ordering used for canonicalization: dominance_rank first, then any remaining alleles.
func _ranking() -> Array[String]:
	var out: Array[String] = []
	for token: String in dominance_rank:
		if not out.has(token):
			out.append(token)
	for token: String in alleles:
		if not out.has(token):
			out.append(token)
	return out


func _rank_index(token: String, ranking: Array[String]) -> int:
	var idx: int = ranking.find(token)
	if idx < 0:
		return ranking.size()
	return idx


func _before(x: String, y: String, ranking: Array[String]) -> bool:
	var ix: int = _rank_index(x, ranking)
	var iy: int = _rank_index(y, ranking)
	if ix != iy:
		return ix < iy
	return x < y


# === PAIR HELPERS ===

## Orders a pair by dominance rank (unknown tokens after known, then alphabetical).
## ["f","F"] -> ["F","f"].
func canonical_pair(pair: Array) -> Array[String]:
	var out: Array[String] = []
	if pair.size() != 2:
		push_error("GenomeLocus '%s': a genotype pair needs exactly 2 alleles, got %d" % [id, pair.size()])
		return out
	var a: String = str(pair[0])
	var b: String = str(pair[1])
	var ranking: Array[String] = _ranking()
	if _before(b, a, ranking):
		out.append(b)
		out.append(a)
	else:
		out.append(a)
		out.append(b)
	return out


## Concatenated canonical pair: "Ff", "D1D3".
func genotype_key(pair: Array) -> String:
	var p: Array[String] = canonical_pair(pair)
	if p.size() != 2:
		return ""
	var first: String = p[0]
	var second: String = p[1]
	return first + second


## Highest-ranked allele of the pair.
func expressed_allele(pair: Array) -> String:
	var p: Array[String] = canonical_pair(pair)
	if p.size() != 2:
		return ""
	return p[0]


## The key used to group phenotypes: COMPLETE -> expressed allele, otherwise genotype key.
func phenotype_key(pair: Array) -> String:
	if dominance == Dominance.COMPLETE:
		return expressed_allele(pair)
	return genotype_key(pair)


func _is_known_token(token: String) -> bool:
	return alleles.has(token) or dominance_rank.has(token)


## Splits a concatenated genotype string ("HHo") into its 2 tokens using this locus's
## allele names. Returns an empty array when it cannot be split.
func split_key(key: String) -> Array[String]:
	var out: Array[String] = []
	for i: int in range(1, key.length()):
		var left: String = key.substr(0, i)
		var right: String = key.substr(i)
		if _is_known_token(left) and _is_known_token(right):
			out.append(left)
			out.append(right)
			return out
	return out


## Normalizes a genotype string in any allele order to the canonical key ("fF" -> "Ff").
## Strings that are not genotype pairs (e.g. an expressed-allele key "F") are returned as-is.
func normalize_key(key: String) -> String:
	var parts: Array[String] = split_key(key)
	if parts.size() == 2:
		return genotype_key(parts)
	return key


func _find_entry(gkey: String) -> Variant:
	if phenotypes.has(gkey):
		return phenotypes[gkey]
	for k: Variant in phenotypes.keys():
		if k is String:
			var ks: String = k
			if normalize_key(ks) == gkey:
				return phenotypes[ks]
	return null


## Resolves the phenotype for a genotype pair. Order: exact genotype key, then expressed allele
## (COMPLETE only), then a fallback {"name": phenotype_key} with a one-time warning.
## The result is a deep copy with "key" set to phenotype_key().
func phenotype_of(pair: Array) -> Dictionary:
	var gkey: String = genotype_key(pair)
	var pkey: String = phenotype_key(pair)
	var entry: Variant = _find_entry(gkey)
	if entry == null and dominance == Dominance.COMPLETE:
		var allele_key: String = expressed_allele(pair)
		if phenotypes.has(allele_key):
			entry = phenotypes[allele_key]
	var result: Dictionary = {}
	if entry is Dictionary:
		var entry_dict: Dictionary = entry
		result = entry_dict.duplicate(true)
	else:
		if not _warned_keys.has(pkey):
			_warned_keys[pkey] = true
			push_warning("GenomeLocus '%s': no phenotype defined for '%s'; using fallback" % [id, pkey])
		result = {"name": pkey}
	result["key"] = pkey
	return result


func is_lethal(pair: Array) -> bool:
	if lethal_genotypes.is_empty():
		return false
	var gkey: String = genotype_key(pair)
	for entry: String in lethal_genotypes:
		if entry == gkey or normalize_key(entry) == gkey:
			return true
	return false


## Homozygous for the lowest-ranked allele (the recessive default).
func default_pair() -> Array[String]:
	var out: Array[String] = []
	var ranking: Array[String] = _ranking()
	if ranking.is_empty():
		return out
	var lowest: String = ranking[ranking.size() - 1]
	out.append(lowest)
	out.append(lowest)
	return out


## True when the pair has 2 entries and both are alleles of this locus.
func is_valid_pair(pair: Array) -> bool:
	if pair.size() != 2:
		return false
	for token: Variant in pair:
		if not (token is String) or not alleles.has(token):
			return false
	return true


# === SERIALIZATION ===

static func _dominance_name(value: Dominance) -> String:
	match value:
		Dominance.INCOMPLETE:
			return "incomplete"
		Dominance.CODOMINANT:
			return "codominant"
	return "complete"


static func _parse_dominance(raw: Variant) -> Dominance:
	if raw is int or raw is float:
		var n: int = int(raw)
		if n == int(Dominance.INCOMPLETE):
			return Dominance.INCOMPLETE
		if n == int(Dominance.CODOMINANT):
			return Dominance.CODOMINANT
		return Dominance.COMPLETE
	var s: String = str(raw).to_lower()
	if s == "incomplete":
		return Dominance.INCOMPLETE
	if s == "codominant":
		return Dominance.CODOMINANT
	return Dominance.COMPLETE


static func _to_string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw is Array:
		var src: Array = raw
		for item: Variant in src:
			out.append(str(item))
	return out


static func _plain(src: Array) -> Array:
	var out: Array = []
	for item: Variant in src:
		out.append(item)
	return out


## Emits the native schema (id / display_name / dominance ...).
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"alleles": _plain(alleles),
		"dominance": _dominance_name(dominance),
		"dominance_rank": _plain(dominance_rank),
		"phenotypes": phenotypes.duplicate(true),
		"lethal_genotypes": _plain(lethal_genotypes),
		"metadata": metadata.duplicate(true),
	}


## Accepts the native schema and dragon-rancher's trait_defs.json entry schema unchanged
## (key -> id, name -> display_name, dominance_type simple/hierarchy -> COMPLETE ...).
## Unknown fields land in `metadata`; phenotype keys are normalized to canonical genotype keys.
static func from_dict(d: Dictionary) -> GenomeLocus:
	var loc: GenomeLocus = GenomeLocus.new()
	loc.id = str(d.get("id", d.get("key", "")))
	loc.display_name = str(d.get("display_name", d.get("name", loc.id)))
	loc.alleles = _to_string_array(d.get("alleles", []))
	loc.dominance_rank = _to_string_array(d.get("dominance_rank", []))
	loc.lethal_genotypes = []
	var raw_dom: Variant = d.get("dominance", d.get("dominance_type", "complete"))
	loc.dominance = _parse_dominance(raw_dom)

	var raw_pheno: Variant = d.get("phenotypes", {})
	if raw_pheno is Dictionary:
		var src: Dictionary = raw_pheno
		var normalized: Dictionary = {}
		# Pass 1: keys already canonical (or not genotype pairs) always win.
		for k: Variant in src.keys():
			var ks: String = str(k)
			if loc.normalize_key(ks) == ks:
				normalized[ks] = _deep_copy(src[k])
		# Pass 2: non-canonical order keys fill gaps only.
		for k: Variant in src.keys():
			var ks: String = str(k)
			var nk: String = loc.normalize_key(ks)
			if nk != ks and not normalized.has(nk):
				normalized[nk] = _deep_copy(src[k])
		loc.phenotypes = normalized

	var raw_lethal: Variant = d.get("lethal_genotypes", [])
	for entry: String in _to_string_array(raw_lethal):
		loc.lethal_genotypes.append(loc.normalize_key(entry))

	var meta: Dictionary = {}
	var raw_meta: Variant = d.get("metadata", {})
	if raw_meta is Dictionary:
		var meta_src: Dictionary = raw_meta
		meta = meta_src.duplicate(true)
	for k: Variant in d.keys():
		var ks: String = str(k)
		if not _NATIVE_KEYS.has(ks):
			meta[ks] = _deep_copy(d[k])
	loc.metadata = meta
	return loc


static func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var dict_value: Dictionary = value
		return dict_value.duplicate(true)
	if value is Array:
		var arr_value: Array = value
		return arr_value.duplicate(true)
	return value
