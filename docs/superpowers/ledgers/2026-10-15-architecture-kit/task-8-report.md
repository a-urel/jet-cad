# Task 8 report

Commit dbaf4bd4 `fix(plan): the pins 2a parked for sub-project 3 (spec 3a C1.12, D-44, D-45)`.

## Implementation
- plan_shortcuts.dart: per-controller mount-ordered `Expando<List<_PlanShortcutsState>>`; last mounted speaks (`_join`/`_leave`/`_applyIdleKeys`) exactly as the brief.
- Tests added: PN-remount, PN-kind, PN-dispose, MV-2 comments, PN-MV-nested/node/live, PN-open, SE8 (new unit_copy_test.dart). Brief code used verbatim; all sync, no settleHistory needed.

## TDD evidence
- RED (D-44): before the fix, `flutter test test/shortcuts/plan_shortcuts_test.dart --plain-name PN-remount` -> `Expected: false  Actual: <true>` at the post-keys(2) expect. After fix: shortcuts dir `All tests passed!` (+17).
- Pins of existing behaviour: RED = mutations below.

## Gates (jet_cad_2d_plan)
- `flutter test --enable-vmservice`: `+1548: All tests passed!`
- `flutter analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: exit 0 (299 files, 0 changed)
- git status: only this task's 6 files. Kit package untouched (no check_kit_deps needed).

## Mutations (committed code; each reverted, `git diff --quiet` exit 0)
- M-PN-1 (dispose gives keys back): PN-remount `Expected: false  Actual: <true>`
- M-PN-2 (_leave reopens): PN-remount `Expected: false  Actual: <true>`
- M-PN-kind: `Which: threw StateError:<Bad state: no kind>` (PN-kind)
- M-PN-dispose: `Expected: return normally ... threw StateError:<Bad state: the wall-face provider broke on dispose>`
- M-PN-ortho: MV-2 `Expected: empty  Actual: [Instance of 'AttachmentQuery']`
- M-PN-nested: `Expected: null  Actual: ({marker: [99010.25,-69020.5], transform: ...})`
- M-PN-node: PN-MV-node `Expected: null  Actual: <Instance of 'Attachment'>`
- M-PN-live: `Expected: [150.0, 210.0, 2050.5, 1180.25]  Actual: [150.0, 210.0, 1750.0, 960.0]`
- M-PN-open (the `_open` call, first of two callers): `Expected: contains (demo, test-edge, attachmentKindUnoffered)`
- M-PN-SE8: `Expected: UnitComponent(table, 3, numbered)  Actual: <null>`

## Deviations
- M-PN-kind as written (`kind = provider.kind;` moved after the catch) does not compile (`final String kind` assigned after use / definite assignment). Ran the equivalent: dropped the `final String kind;` declaration and put `final kind = provider.kind;` after the catch block.
- M-PN-open: the file has two `_reportUnofferedKinds()` calls (the other after symbol load); mutated the one in `_open` (after `probeLoaded()`).

## Concerns
None.
