## Global Constraints

- CLAUDE.md non-negotiables: no per-entity allocation on the frame path
  (`query_allocation_test.dart`, `paint_allocation_test.dart` green); never
  commit `analysis_options.yaml` (`git status --short` before every
  commit); never synthesize output; English code, comments, commits;
  trailer `Co-Authored-By: <model> <noreply@anthropic.com>`.
- Never merge, push, tag or publish. `dart pub publish --dry-run` only.
- **Do not touch** the canvas (`lib/src/canvas/**`), `tools/move_resolver.dart`,
  the snap, the service drag (`service/service_tool.dart`), or
  `jet_cad_2d_flutter`. The alignment-guides branch owns them.
- **No public signature change** in `jet_cad_2d_plan`; no `Shad*` or
  `LucideIcons` type reachable from its barrel (Task 1's check).
- **Keys:** every existing `Key` keeps its value and its meaning. A key that
  sat on a Material widget sits on the chrome part that replaced it.
- **Words:** every visible word from `PlanStrings` or a kit's `PlanWords`;
  no `ShadInput` without the library's `contextMenuBuilder`; no
  `keyboardToolbarBuilder`; no `ShadSelect.withSearch`; no date/time picker.
- **Canvas-owned reads stay Material** (spec "Canvas-owned reads"):
  `PlanLayerPanel._foreground`, the service view's canvas background /
  paper / brightness reads, every `PlanTheme` read.
- **Rulings:** a test changes only under a ruling in
  `.superpowers/sdd/2026-10-23-plan-shadcn-chrome/rulings.md`: mapping,
  every test touched (file:line), how the new finder checks the same
  thing, anchored to the same key. Never drop an assertion.
- **Self-review per task** (the human's rule: no reviewer subagents): the
  controller reads the diff, runs the task's named mutation itself and
  re-runs the gates.
- **A task ends green:** in every package it touched, its tests, analyze
  and `dart format --output=none --set-exit-if-changed .`; plus
  `packages/jet_cad_2d_integration` (`flutter test`) for any plan-library
  change; plus `cd tool/ci && dart test`.
- Versions are not bumped; CHANGELOG lines go under `## Unreleased`.

## Review Focus

1. **The host flips light/dark while a select or menu is open** (monepro's
   theme toggle): the open overlay and the chrome take the new theme, no
   exception. → Task 2 test `SC6`, Task 3 test `CP9`.
2. **A Material 2 host** (`useMaterial3: false`, or a hand-built
   `ColorScheme` with default container tokens): the derived theme has
   readable foreground on every surface. → Task 2 test `SC7`.
3. **Keyboard only:** Tab reaches every bar and panel control, Enter/Space
   activates an icon button, a menu opens from the keyboard and Escape
   closes it with the focus back on its trigger. → Task 3 tests `CP6`, `CP7`.
4. **Large text** (`TextScaler.linear(1.5)` and `2.0`): the editor bar and
   the panels at 375, 800 and 1280 px do not overflow. → Task 5 test `ED6`.
5. **Phone width:** a select or menu opened inside a phone drawer (375 px)
   lays out fully on screen. → Task 6 test `PP7`.

