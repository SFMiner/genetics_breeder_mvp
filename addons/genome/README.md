# Genome addon (v0.1.0)

Vendored copy of the canonical Genome Engine. Do not edit here; change the source repo and re-sync.

## Quick start
```gdscript
var lib: GenomeLibrary = GenomeLibrary.from_json_file("res://data/loci.json")  # {"loci": [...]} or rancher {"traits": [...]}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
rng.seed = 42

var mom: Dictionary = {"fire": ["F", "f"], "wings": ["W", "w"]}
var dad: Dictionary = {"fire": ["F", "f"], "wings": ["w", "w"]}

var kid: Dictionary = Genome.cross(lib, mom, dad, rng)          # {"fire": ["F","f"], ...}
var traits: Dictionary = Genome.phenotype(lib, kid)             # locus -> {"name", "key", ...}

var loci: Array[String] = ["fire", "wings"]
var sq: Dictionary = Genome.punnett(lib, mom, dad, loci)        # exact probabilities
var fit: Dictionary = GenomeStats.chi_square(
		GenomeStats.count_phenotypes(lib, [kid], loci), sq["phenotype_ratios"])
```
Genotype shape: `{locus_id: [allele, allele]}` (Strings; tokens may be multi-character).
`rng` is any Object with `randf()` and `randi_range(from, to)`. Pass `Array[String]` (typed) for `locus_ids`.

## API
- `GenomeLocus`: fields `id, display_name, alleles, dominance (COMPLETE|INCOMPLETE|CODOMINANT), dominance_rank, phenotypes, lethal_genotypes, metadata`; `canonical_pair, genotype_key, expressed_allele, phenotype_key, phenotype_of, is_lethal, default_pair, is_valid_pair, split_key, normalize_key, to_dict, from_dict`.
- `GenomeLibrary`: `loci, add_locus, get_locus, has_locus, locus_ids, normalize, validate, to_dict, from_dict, from_json_file`.
- `Genome` (static): `make_gamete, fertilize, cross, clone_with_mutation, random_genotype, is_viable, phenotype, genotypes_equal, gametes, punnett, display_genotype, phenotype_key`.
- `GenomeStats` (static): `chi_square, critical_value_05, count_phenotypes`.

Full spec: `docs/DESIGN.md` in the source repo.
