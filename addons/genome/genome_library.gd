class_name GenomeLibrary
extends Resource
## A set of GenomeLocus definitions, loadable from / savable to JSON.

# === FIELDS ===

## id -> GenomeLocus (insertion order preserved).
var loci: Dictionary = {}
var version: String = "1.0"

# === LOCI ===

func add_locus(locus: GenomeLocus) -> void:
	loci[locus.id] = locus


## Returns the locus, or null (with a warning) when the id is unknown.
func get_locus(id: String) -> GenomeLocus:
	if not loci.has(id):
		push_warning("GenomeLibrary: unknown locus '%s'" % id)
		return null
	var locus: GenomeLocus = loci[id]
	return locus


func has_locus(id: String) -> bool:
	return loci.has(id)


## Locus ids in insertion order.
func locus_ids() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in loci.keys():
		out.append(str(k))
	return out


# === LOADING / SAVING ===

## Accepts {"traits": [...]} (dragon-rancher) or {"loci": [...]} (native).
static func from_dict(d: Dictionary) -> GenomeLibrary:
	var lib: GenomeLibrary = GenomeLibrary.new()
	lib.version = str(d.get("version", "1.0"))
	var entries: Variant = d.get("loci", d.get("traits", []))
	if entries is Array:
		var list: Array = entries
		for entry: Variant in list:
			if entry is Dictionary:
				var entry_dict: Dictionary = entry
				lib.add_locus(GenomeLocus.from_dict(entry_dict))
	return lib


## Loads a library from a JSON file. On failure pushes an error and returns an empty library.
static func from_json_file(path: String) -> GenomeLibrary:
	if not FileAccess.file_exists(path):
		push_error("GenomeLibrary: file not found: %s" % path)
		return GenomeLibrary.new()
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("GenomeLibrary: could not parse JSON object from %s" % path)
		return GenomeLibrary.new()
	var parsed_dict: Dictionary = parsed
	return from_dict(parsed_dict)


func to_dict() -> Dictionary:
	var list: Array = []
	for k: Variant in loci.keys():
		var locus: GenomeLocus = loci[k]
		list.append(locus.to_dict())
	return {"version": version, "loci": list}


# === GENOTYPE HELPERS ===

## Canonicalizes every known locus; unknown loci pass through unchanged.
func normalize(genotype: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in genotype.keys():
		var id: String = str(k)
		var value: Variant = genotype[k]
		if loci.has(id) and value is Array:
			var pair: Array = value
			if pair.size() == 2:
				var locus: GenomeLocus = loci[id]
				var canon: Array[String] = locus.canonical_pair(pair)
				var plain: Array = []
				for token: String in canon:
					plain.append(token)
				out[id] = plain
				continue
		out[id] = value
	return out


## Human-readable problems with a genotype (empty array = ok).
func validate(genotype: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for k: Variant in genotype.keys():
		var id: String = str(k)
		if not loci.has(id):
			problems.append("unknown locus '%s'" % id)
			continue
		var value: Variant = genotype[k]
		if not (value is Array):
			problems.append("locus '%s': genotype must be an Array of 2 alleles" % id)
			continue
		var pair: Array = value
		if pair.size() != 2:
			problems.append("locus '%s': expected 2 alleles, got %d" % [id, pair.size()])
			continue
		var locus: GenomeLocus = loci[id]
		for token: Variant in pair:
			if not (token is String) or not locus.alleles.has(token):
				problems.append("locus '%s': '%s' is not a valid allele" % [id, str(token)])
	return problems
