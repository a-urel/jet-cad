### Task 6: Docs, gates and results

**Files:**
- Modify: `docs/host-guide.md` (line 22's restaurant demo sentence if it
  names Material; §10 around line 1282: the POS look is now the canvas
  `PlanTheme`, the app is zinc `ShadApp`)
- Create: `docs/superpowers/notes/2026-10-24-demos-shadcn-results.md`
- Modify: `STATUS.md` (In-flight)
- Create: `docs/superpowers/ledgers/2026-10-24-demos-shadcn/` (the
  workspace's ledger, briefs, reports, `rulings.md`)

- [ ] **Step 1: Gates** (real last lines into the results note):
  `flutter test`/`analyze`/format in both demos; `cd
  packages/jet_cad_2d_plan && flutter test`; `cd
  packages/jet_cad_2d_integration && flutter test`; `cd tool/screenshots
  && flutter test`; `cd tool/ci && dart test`; `dart run
  tool/ci/check_guide.dart`; `dart run tool/ci/check_screenshots.dart`.
- [ ] **Step 2: Real runs:** `flutter build macos --debug` in both demos;
  `flutter test integration_test -d macos` in both.
- [ ] **Step 3: Look:** launch both demos on macOS, light and dark,
  screenshot each at desktop width; put them in the results note's
  evidence, say what was and was not looked at.
- [ ] **Step 4: Docs, results, STATUS, ledger archive; commit**
  `docs: results of the example apps in shadcn`.
## Global Constraints

- Never commit `analysis_options.yaml` (`git status --short` before every
  commit); never synthesize output; English code, comments, commits;
  trailer `Co-Authored-By: <model> <noreply@anthropic.com>`.
- Never merge, push, tag or publish.
- **No change under `packages/`** (spec N1). A library defect found on the
  way: stop the task, report it; never a demo-side workaround.
- **Keys:** every `Key` in the demos' `lib/` keeps its value and lands on
  the widget a user acts on (spec D6).
- **Strings:** every visible word stays where it comes from today
  (`DemoStrings`, `AppStrings`, `PlanStrings`); no shadcn component that
  shows its own English words (no `ShadSelect.withSearch`, no date picker).
- **No `Icons.`** in a demo's `lib/` once its task is done: `LucideIcons`.
- **Rulings:** a test changes only under a ruling in
  `.superpowers/sdd/2026-10-24-demos-shadcn/rulings.md`: file:line,
  old → new, how the new finder checks the same thing on the same key.
  Never drop an assertion; never widen a tolerance.
- **Self-review per task** (the human's rule: no reviewer subagents): the
  controller reads the diff, runs the task's named mutation itself and
  re-runs the gates.
- **A task ends green** in the demo it touched: `flutter test`,
  `flutter analyze`, `dart format --output=none --set-exit-if-changed .`.

## Review Focus

1. **The system flips light/dark at runtime:** `ShadApp`'s derived
   Material theme flips with it, so the canvas background and the paper
   follow, as they did under `MaterialApp`. → Task 1 test `RD2`, Task 4
   test `AD2`.
2. **The language switch at runtime** (EN → DE → TR): the top pane's tabs,
   the sheet's switches and the dialogs show the new words with no stale
   English. → Task 2 test `RT4`.
3. **Phone width (375 px):** the top pane's controls scroll, the sheet
   opens from the side button and fits, nothing overflows. → Task 2 test
   `RT2`.
4. **Large text (`TextScaler.linear(2.0)`)** at 375 and 1300 px: the top
   pane and the side panel do not overflow. → Task 2 test `RT3`.
5. **Keyboard only in the architecture demo's dialogs:** Save has the focus,
   Enter saves, Escape cancels, the name prompt's Enter submits. → Task 4
   test `AD4`.

---
