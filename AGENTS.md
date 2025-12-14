# Repository Guidelines

## Project Structure & Module Organization
- Core gameplay lives in `scenes/main/BreederRoom.tscn` with its controller in `scripts/main/BreederRoom.gd`.
- Reusable organisms are under `scenes/organisms` with matching logic in `scripts/dragons` (e.g., `Dragon.tscn` + `Dragon.gd`).
- UI panels and popups reside in `scenes/ui` with controllers in `scripts/ui` (BreedingPanel, PunnettSquare, SelectionPopup).
- Shared state and genetics logic live in the autoload singleton `scripts/autoload/GeneticsState.gd` (registered in `project.godot`).
- Export presets sit in `export_presets.cfg`; keep them in sync if you add platforms.

## Build, Run, and Development Commands
- Open the project in the Godot editor: `godot4 --editor --path .`
- Play the game from CLI using the configured main scene: `godot4 --path .`
- Run headless for quick smoke runs (no rendering): `godot4 --headless --path . --quit-after 1` (useful for validating autoload initialization).
- When adding autoloads or changing the main scene, update `project.godot` and re-run to verify the editor picks them up.

## Coding Style & Naming Conventions
- Language: GDScript 2.0 with typed variables and signals; keep functions short and focused.
- Indentation uses tabs in existing files; match surrounding style. Keep lines concise and readable.
- Classes and scenes use PascalCase (`Dragon`, `BreederRoom`); node paths mirror scene hierarchy; signals and functions use snake_case.
- Constants are SCREAMING_SNAKE_CASE; prefer `@onready` for node references and `@export` for editable fields.
- Use brief doc comments with `##` to describe intent above functions or blocks that need context.

## Testing Guidelines
- No automated test suite is present; perform manual verification:
  - Run the main scene and breed dragons with different parent combinations; confirm Punnett square updates and offspring phenotypes match allele expectations.
  - Check reset flow: clicking Reset should clear nodes, selections, and respawn starters from `GeneticsState`.
  - Verify new UI elements behave in both fire/no-fire cases and resize appropriately at 1280x720 and smaller viewports.
- If you add logic-heavy code, consider a headless run plus in-editor breakpoints to validate allele calculations.

## Commit & Pull Request Guidelines
- Git repo is initialized; keep `main` clean. Stage intentionally (`git status`, `git add <paths>`) and use concise, imperative commits (`Add Punnett probability labels`, `Fix selection highlight reset`).
- In PRs, include: summary of changes, gameplay impact, reproduction steps, and screenshots/GIFs for UI updates.
- Mention modified scenes/scripts explicitly (e.g., `scenes/ui/PunnettSquare.tscn`, `scripts/autoload/GeneticsState.gd`) so reviewers can focus their checks.
- Keep diffs minimal: prefer updating existing scenes/scripts rather than duplicating nodes; remove unused debug prints before submission.
