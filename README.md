# genetics_breeder_mvp

## Feature checklist
- [x] Level 1 (fire) and Level 2 (fire + wings) breeding with Mendelian inheritance
- [x] Monohybrid (2x2) and dihybrid (4x4) Punnett squares with phenotype probabilities
- [x] Quiz Punnett square (player fills in genotypes and phenotypes)
- [x] Genome Engine integration: `GeneticsState` delegates crossing and phenotype lookup to the vendored `addons/genome` (seedable RNG via `set_seed`)
- [x] Headless test suite: `tests/test_genetics_state.gd` (run with `tests/run_all_tests.sh`)
- [x] Predict-then-breed loop (spec: `docs/PREDICT_THEN_BREED.md`): fraction prediction per phenotype, check, hatch 20 eggs, keep one
- [x] Prediction panel and clutch panel built in code (`scripts/ui/prediction_panel.gd`, `clutch_panel.gd`), pure logic in `scripts/rules/prediction_logic.gd`
- [x] Headless tests for the prediction loop: `tests/test_prediction.gd`
- [x] `DG_SHOT` screenshot gate for layout checks (see CLAUDE.md)
- [x] Keyboard: Tab order, visible focus outline, arrow keys inside groups, Escape closes a box then leaves (`scripts/ui/KeyboardNav.gd`, `tests/test_keyboard.gd`)
- [x] Whole predict-then-breed loop playable without a mouse
- [x] No emoji/symbols in text (web fonts); right/wrong and Parent A/B shown in words, not colour alone
- [x] Web export for sims.mr-miner.com (2D + GUI template, single-threaded, unused assets excluded)
- [x] Sims-site keyboard exit (`sims:leave-game`)
- [ ] Play-test the loop with students (wording, pacing, 7+ dragon collections under the panels)
