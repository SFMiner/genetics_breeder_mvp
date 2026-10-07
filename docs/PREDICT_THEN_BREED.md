# Predict-then-Breed Loop — Spec

Goal: students commit to a prediction from the Punnett square *before* they see the answer or
breed, then test it against a clutch of offspring. Audience: middle-school special-ed students
(K–5 reading levels), so short plain words, big targets, no typing.

## Flow (Levels 1 and 2)
1. **Choose parents** (existing SelectionPopup → BreedingPanel slots). Changing either parent
   resets the loop to step 2.
2. **Predict.** The Punnett grid is visible (students reason from it), but the result square's
   "Predicted Offspring: …%" summary is **hidden** until the prediction is locked. The
   PredictionPanel lists **every phenotype class for the level**, not just those possible in this
   cross (listing only the possible ones would give away the answer):
   - Level 1: `fire`, `no fire`
   - Level 2: every combination of the fire and wings phenotypes (4 rows), labelled like the
     existing dihybrid keys (`"fire, no flight"`).
   Each row has a fraction button group (toggle buttons in one ButtonGroup, one choice per row):
   - Level 1: `0`, `1/4`, `1/2`, `3/4`, `all`
   - Level 2: `0`, `1/16`, `1/8`, `3/16`, `1/4`, `3/8`, `1/2`, `9/16`, `3/4`, `all`
   A running total shows ("Total: 12/16"). **Check my prediction** enables only when the total
   is exactly 1 (compare as integer numerators over 16 to avoid float error).
3. **Check.** Compare each row with the exact ratio from `Genome.punnett(...)["phenotype_ratios"]`
   (missing key = 0). Each row shows ✓ or ✗ and the correct fraction. The PunnettSquare summary is
   revealed. The session score updates ("Predictions right: 3 of 4"). A fully correct prediction
   gets an encouraging line; otherwise show "Look at the square: count the boxes for each kind."
4. **Hatch a clutch.** The Breed button is disabled before the check (tooltip "Make a prediction
   first") and becomes **Hatch 20 eggs**. It calls `GeneticsState.breed_clutch(a_id, b_id, 20)`
   (does **not** add to the collection). The ClutchPanel shows:
   - one row per phenotype class: Punnett-expected count (ratio × 20, one decimal place), observed
     count, and a simple horizontal bar for each
   - a plain-language verdict from `GenomeStats.chi_square(observed, phenotype_ratios)`:
     - fits → "Close to what the Punnett square predicts. The small differences are just chance."
     - doesn't fit → "That's further from the prediction than chance usually makes. It happens
       about 1 time in 20. Try hatching again!"
   - 20 small hatchling chips (colored by phenotype, labelled with genotype like `Ff Ww`).
5. **Keep one.** Clicking a chip calls `GeneticsState.add_offspring(genotype, a_id, b_id)`, which
   adds that dragon to the collection the way `breed()` does (same id, generation, signal
   `breeding_complete` and the tile flash). The other 19 are discarded. After keeping one, the
   student can **Hatch 20 eggs** again (same prediction) or change parents.

## Code
- `scripts/rules/prediction_logic.gd` — `class_name PredictionLogic`, static and pure (testable):
  - `phenotype_classes(traits: Dictionary, trait_ids: Array[String]) -> Array[String]` — all
    combinations, in a stable order matching the dihybrid key format.
  - `fraction_options(level: int) -> Array[int]` — numerators over 16.
  - `exact_ratios(lib, parent_a_geno, parent_b_geno, trait_ids) -> Dictionary` — `class ->
    float` using `Genome.punnett`, keys converted to the phenotype-name class strings.
  - `grade(prediction_16ths: Dictionary, exact: Dictionary) -> Dictionary` — `{ "rows": {class:
    {"predicted": int, "correct": int, "right": bool}}, "all_right": bool }`; `correct` =
    `roundi(ratio * 16)`.
  - `fraction_label(numerator_16ths: int) -> String` — reduced (`"3/4"`, `"all"`, `"0"`).
- `GeneticsState`: add `breed_clutch(a_id: int, b_id: int, n: int) -> Array[Dictionary]`
  (genotypes via `Genome.cross` with the existing seeded `rng`) and `add_offspring(genotype:
  Dictionary, a_id: int, b_id: int) -> int`. `breed()` should become
  `add_offspring(Genome.cross(...))` so there is a single path.
- UI: **build PredictionPanel and ClutchPanel in code** (`scripts/ui/prediction_panel.gd`,
  `scripts/ui/clutch_panel.gd`, Control subclasses), added by BreederRoom at runtime. Don't
  hand-author new positioned `.tscn` layouts. Use containers (VBox/HBox/Grid), min button size
  about 48 px, and the existing theme/fonts. Expose `reset()`.
- BreederRoom wires the steps: on parent change → panels reset, summary hidden, Breed disabled.
- Session score lives in GeneticsState (`predictions_made`, `predictions_right`), resets with
  `reset()`.

## Tests (`tests/test_prediction.gd`)
- `phenotype_classes`: 2 for L1, 4 for L2, stable order, keys match `get_dihybrid_probabilities`.
- `fraction_options` and `fraction_label` (reduction, `"all"`, `"0"`).
- `exact_ratios` for Ff×Ff (3/4, 1/4), FF×ff (all), FfWw×FfWw (9/16, 3/16, 3/16, 1/16), FfWw×ffww
  (1/4 each), FfWw×Ffww (3/8, 3/8, 1/8, 1/8).
- `grade`: all right, one wrong, and a class missing from the exact ratios (= 0).
- `breed_clutch`: returns n genotypes, does not change the collection, same seed ⇒ same clutch.
- `add_offspring`: adds exactly one dragon, emits `breeding_complete`, and sets the parents.
- `breed()` still works (existing suite stays green).
