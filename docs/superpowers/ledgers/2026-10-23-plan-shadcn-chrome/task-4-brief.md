### Task 4: The leak collectors see the parts

**Files:**
- Modify: `packages/jet_cad_2d_plan/test/editor/editor_words_test.dart` (`visibleTexts`)
- Modify: `packages/jet_cad_2d_integration/test/l10n/leak_test.dart` (its collector), `test/l10n/panel_words_test.dart` if it collects
- Test: the same files

**Interfaces:**
- Consumes: `PlanWordsCarrier` (Task 3) through `package:jet_cad_2d_plan/src/chrome/words_carrier.dart` (tests may import `src`; check the integration package already does elsewhere, else add a `@visibleForTesting` re-export in an existing test-support barrel).

- [ ] **Step 1:** Extend each collector: today's `Text` and `Tooltip.message`, **plus** `visibleWords` of every widget that `is PlanWordsCarrier`. Every assertion and allowlist stays as it is.
- [ ] **Step 2:** Leak mutations (test-only fixtures, not lib): a
  `PlanIconButton(label: 'Raw')` mounted in the editor's bar `trailing`
  slot in a Turkish run → LK1 red; a `PlanMenuButton` entry `'Raw'` → red;
  a `PlanTextField(errorText: 'Raw')` → red. Keep them as tests
  `LK1x tooltip`, `LK1x menu entry`, `LK1x field error` (expect the leak
  to be reported).
- [ ] **Step 3:** Record ruling R-LK ("collectors extended, no assertion changed").
- [ ] **Step 4: Gates; commit** `test(plan): the leak collectors read the chrome parts`.

