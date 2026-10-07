# CLAUDE.md

This file is the single copy of the project conventions; AGENTS.md only points here.

# Repository Guidelines

## Project Structure & Module Organization
- Main flow lives in `scenes/main/BreederRoom.tscn` with controller `scripts/main/BreederRoom.gd`; it instantiates both the result Punnett square and the quiz square.
- Organisms: `scenes/organisms/Dragon.tscn` with logic in `scripts/dragons/Dragon.gd` (assigns textures from `assets/sprites`, e.g., `dragon_ad_fr_wd.png`).
- UI: `scenes/ui` contains `BreedingPanel.tscn`, `SelectionPopup.tscn`, `PunnettSquare.tscn` (results) and `QuizPunnettSquare.tscn` (player input). Matching scripts live in `scripts/ui/`.
- Shared genetics rules and level data (Level 1: fire only; Level 2: fire + wings) live in the autoload singleton `scripts/autoload/GeneticsState.gd` (registered in `project.godot`).
- Export presets are in `export_presets.cfg`; keep platform entries in sync when adding builds.

## Build, Test, and Development Commands
- Open the project: `godot4 --editor --path .`
- Run the game with the configured main scene: `godot4 --path .`
- Quick smoke without rendering: `godot4 --headless --path . --quit-after 1` (catches autoload/scene load errors).
- After adding autoloads or changing the main scene, re-run once to ensure `project.godot` picks up changes.

## Coding Style & Naming Conventions
- Use GDScript 2 with typed variables and signals; prefer `@onready` for scene references and `@export` for editor tuning.
- Match existing indentation (tabs) and Godot naming: PascalCase for scenes/classes, snake_case for functions/signals/vars, SCREAMING_SNAKE_CASE for constants.
- UI nodes referenced via `%` must keep their unique names; keep quiz/result square cell counts at 2 columns (monohybrid) or 4 (dihybrid).
- Sprite assets follow `dragon_a{allele}_f{allele}_w{allele}.png`; add new traits with consistent prefixes.

## Testing Guidelines
- Headless tests (two suites: `test_genetics_state.gd`, `test_prediction.gd`): `GODOT=../Godot_v4.5-stable_win64.exe bash tests/run_all_tests.sh`. Run an editor scan first (`--headless --path . --editor --quit-after 250`) after adding a `class_name` script so it is registered.
- Screenshot gate (needs rendering, so do NOT pass `--headless`): `DG_SHOT=C:/path/out.png ../Godot_v4.5-stable_win64.exe --path .` auto-picks the two starters, enters a sample prediction, checks it, hatches a clutch, saves the viewport and quits. `DG_LEVEL=2` starts on Level 2, `DG_STAGE=pre` stops before the check, `DG_HET=1` uses two heterozygous parents. Look at the PNG for overlap/clipping at 1280x720.
- Predict-then-breed spec: `docs/PREDICT_THEN_BREED.md`. Its logic is in `scripts/rules/prediction_logic.gd`; `PredictionPanel` and `ClutchPanel` are built in code (`scripts/ui/`) and added by `BreederRoom`. The quiz square no longer opens by itself (it covered the Punnett square); the "Quiz me on the square" button opens it.
- Manual checks (secondary): run the main scene, click dragons and parent slots, and verify selection highlights.
- For Level 1 and 2, confirm Punnett square values, quiz inputs, and result highlighting; ensure gridlines and labels align.
- Use Reset Lab to confirm collections clear and starter dragons respawn; ensure quiz/result squares refresh accordingly.
- If you touch genetics math, test breeding across all allele combos and watch for off-screen layout issues at 1280x720.
- Layout caveat: the prediction/clutch panels sit under the first row of dragon tiles (y 262+), so a collection of 7+ dragons (second tile row) runs underneath them.

## Genome Engine
- `addons/genome/` is a vendored copy of `../genome-engine` (https://github.com/SFMiner/genome-engine). Never edit it here: change the engine, then run `bash tools/sync_genome.sh ../dragon_genetics` from `genome-engine`.
- `GeneticsState` builds a `GenomeLibrary` from `TRAIT_LIBRARY` and delegates crossing and phenotype lookup to it; use `set_seed(n)` for repeatable breeding.
- Headless tests: `../Godot_v4.5-stable_win64.exe --headless --path . --script tests/test_genetics_state.gd` (or `GODOT=<binary> bash tests/run_all_tests.sh`).
- `.gitattributes` forces LF so the addon's sync hash stays stable; keep it.

## Commit & Pull Request Guidelines
- Git is initialized; keep commits small and imperative (`Fix quiz square layout`, `Add wings trait sprites`). Run `git status` to avoid accidental `.godot/editor` noise unless intentionally updating editor state.
- In PRs, summarize gameplay impact, list modified scenes/scripts, add repro steps, and attach screenshots/GIFs for UI changes.
- Prefer editing existing scenes/scripts over duplicating nodes; remove temporary debug prints before submitting.
