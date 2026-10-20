# Task 6 report: NEEDS_CONTEXT (not committed)

Status: implemented and working-tree only; stopped before the gates, mutations and commit because the spec's default breakpoints turn 5 existing tests red at the default/narrow test surfaces.

## What exists (uncommitted, in the worktree)
- lib/src/editor/editor_layout.dart: PlanEditorLayout, PlanLayoutBreakpoints (tablet 600, desktop 1000; `<` comparisons), PlanDrawerHost (Stack(fit: expand) overlay; both drawers kept mounted offstage via Visibility(maintainState); scrim barrier closes on tap; Escape via HardwareKeyboard handler while a drawer is open, because the select tool consumes Escape before any ancestor Focus/Shortcuts, so PlanShortcuts was not usable; left 280, right 300, capped at 85%).
- plan_editor.dart: `breakpoints`, `layout` params; `_editor` is a dispatcher (forced desktop returns `_docked`, the old tree, unchanged; else LayoutBuilder on the editor's own width); `_docked` = old `_editor`; right column extracted to `_rightColumn` (same widgets/keys); `_compact` for phone/tablet; `_topBar` gains first/last/phone params. Layout change closes the drawer (selection untouched).
- Phone bar: left button (menu) first, right button (tune) last; hidden on phone: status text and the snap/zoom read-outs; the file/edit toolbar scrolls horizontally. Damaged icon kept.
- Tablet: `chrome-tool-strip` (56 wide) from PlanToolPalette(compact: true) (icon buttons, same `tool-<id>` keys, fill icon), `chrome-symbols-button` at its foot only when the gallery is offered; opens gallery as left drawer. Right button as phone.
- Strings openToolsPanel/openPropertiesPanel (en/de/tr) + test/support/recording_plan_strings.dart regenerated (needed for the new abstract members). Barrel exports + barrel_test deliberate. CHANGELOG line.
- test/editor/editor_layout_test.dart: EL1-EL7 (+EL2b, EL3b, EL4b): all pass (`flutter test` on that file: "All tests passed!", 11 tests incl. EL1..EL7 variants).
- Fixed on the way: theme_colours_test (no literal colour: scrim uses scheme.scrim), Stack children keyed positions (barrier slot placeholder, otherwise drawers remount and lose scroll state).

## Blocking: existing tests that fail with the spec's breakpoints (unedited)
Full run of packages/jet_cad_2d_plan after the change: exactly these 5 existing tests fail (all else green, analyze clean, format clean):
1. test/editor/editor_view_test.dart "the three chrome slots are laid out": pumps MaterialApp(PlanEditor) at the default 800x600 -> tablet -> no `chrome-left`.
2. test/editor/editor_theme_test.dart "PlanTheme through the barrel alone...": default 800x600 -> tablet, expects `chrome-left`.
3-5. test/editor/editor_words_test.dart OV-H-unit-en / -de / -tr "at 656 x 700 ... the right panel never overflows": sets 656x700 explicitly (tablet), expects the docked 280 right panel.

## Proposal (controller to rule)
- A: `PlanEditor.layout` default stays width-driven, but these 5 tests need a pin: they are not editable, so no.
- B (my recommendation): keep spec breakpoints; make the DEFAULT `breakpoints` const PlanLayoutBreakpoints(tablet: 600, desktop: 1000) as spec, but treat the three tests as the rule's casualties and let the human approve editing them to pass `layout: PlanEditorLayout.desktop` (3 files, a one-argument change each, no assertion weakened).
- C: lower the default desktop breakpoint to 656 (smallest docked width existing tests use) -- changes spec D4; the 800x600 default surface then stays desktop. This keeps all 5 unedited but a 656-wide dock leaves a 136 px canvas, which defeats D4's purpose.
- No tests were edited; no commits made.

## Not done yet (pending the ruling)
Gates last lines, mutation run (`<` -> `<=` at 1000 with EL5's 1000-wide case; drop Visibility maintainState -> EL4b; Escape handler removed -> EL4; Stack without fit expand -> EL4 premise; clear drawer on layout change removed -> EL6), commit `feat(plan): PlanEditor on phones and tablets`.

---
# Update after rulings: DONE (commit 8dba22f8)

Rulings applied: (1) `layout: PlanEditorLayout.desktop` added, with the one-line comment, to editor_view_test ("the three chrome slots"), editor_theme_test (barrel PlanEditor) and editor_words_test (the OV-H and OV-H-unit en/de/tr builds; OV-H was passing only trivially at tablet, so it is pinned too; the 704-656 sweep is untouched). Rationale: "desktop unchanged" binds desktop widths; these tests pin the desktop chrome at sub-desktop surfaces. No assertion touched; only an import added in two of them. CHANGELOG notes the behaviour change. (2) Escape handler skips when primary focus is in an EditableText; EL4c added.

Gates (packages/jet_cad_2d_plan): `flutter test --enable-vmservice` -> "+1617: All tests passed!"; `flutter analyze` -> "No issues found!"; `dart format ... .` -> "0 changed"; check_kit_deps green.

Mutations (on committed code, reverted by git checkout, git diff --quiet clean):
- M1 `<` -> `<=` at both breakpoints: EL5 red.
- M2 Visibility maintainState: false: EL4b red.
- M3 Escape handler no longer closes: EL4 and EL4c red.
- M4 no drawer reset on layout change: EL6 red.
- M5 EditableText guard removed: EL4c red.
