# Task 9b report: bar toggles and strings

Status: DONE_WITH_CONCERNS. Commit d515b90b `feat(plan): alignment guide toggles in both bars`.

## Built
- Enums: `PlanEditorAction { export, print, undo, redo, guides, snap, zoom }`, `PlanServiceAction { undo, redo, guides, merge, split, export, print }`, docs updated.
- Editor: `_BarCommand.selected` (ValueListenable<bool>?), `_Toolbar` renders via `ListenableBuilder(Listenable.merge([enabled, selected]))` with `IconButton.isSelected`. `_guidesFlag = _Flag(c.alignmentGuides, () => userOn)` made in `_bind`, disposed in `_unbind` (rebinds on controller swap). `_guidesCommands` (id `guides`, `Icons.straighten`) appended after `_editCommands` at both call sites, outside the undo gate, only with `alignmentGuides`. `_toolbarFor` maps `guides`; readouts switch is now explicit (no `_ =>`).
- Service: `_button(..., {selected})`, `service-guides` in group 0, null when `!alignmentGuides` (new `_ServiceCanvas.alignmentGuides` field). Selected flag is lazily made (`_guidesFlag ??=`) so a dispose after the controller's dispose does not call `addListener` on a disposed `PlanGuideSettings` (found by editor_modes F-2/F-3 failing; fixed).
- Strings `alignmentGuides` in strings.dart, en/de/tr verbatim, recording_plan_strings.dart.

## TDD evidence
Honest note: I wrote the implementation before the new test file, so I did not watch it fail first. Red evidence is the mutations below plus the full-suite failures after the enum change (27 failures before test updates).

## Mutations (test/guides/guide_bar_test.dart), each reverted afterwards
Command: `flutter test --enable-vmservice test/guides/guide_bar_test.dart`
- M1 guides command inside the undo gate (`widget.alignmentGuides && permissions.undo`): `+1 -1: editor bar the default bar shows toolbar-guides (permissions.undo: false) ...  [E]`
- M2 editor `selected` read once (`ValueNotifier(userOn)`): `+0 -2: editor bar the default bar shows toolbar-guides (permissions.undo: false) ... [E]` (both undo variants red)
- M3 service group switch puts guides in group 1: `Expected: <0>  Actual: <8.0>` at `service bar the default bar shows service-guides right after service-redo and in the same group ... [E]`
- M4 service `selected` read once: `Expected: false  Actual: <true>` at the same service test.
After reverting: guide_bar_test +8 all passing.

## Pinned tests updated (same commit)
- editor_bar_test: values list; kEditorEdges/kEditorKeys (+`toolbar-guides` 184/144, status 240/200).
- service_bar_test: values list; kServiceEdges/kServiceKeys (+`service-guides` 108, later buttons +48).
- plan_editor_test ED-4, editor_options_test O23: the toggle stays when all permissions are refused (spec: outside undo gate), so they assert it and measure from it.
- unit_groups_toolbar_test TB7: Print is 8 px after the toggle, which abuts Redo.
- apps/architecture_demo/test/document_commands_test.dart DC12/DC12c: floor 800 -> 840 px (the 40 px toggle overflowed the tight 800 px bar by 10 px / 1 px). Test-only change; no demo app code touched.

## Gates (real last lines)
- plan `flutter test --enable-vmservice`: `+1747: All tests passed!` (was +1739; 8 new)
- plan `flutter analyze`: `No issues found!`; `dart format --output=none --set-exit-if-changed .`: `Formatted 338 files (0 changed)`
- restaurant_demo: `+112: All tests passed!`, analyze `No issues found!`
- architecture_demo: `+176: All tests passed!`, analyze `No issues found!`, format `Formatted 44 files (0 changed)`
- `git status --short` before commit showed no analysis_options.yaml.

## Concerns
1. Architecture demo's 800 px desktop floor is now 840 px; Task 11 / the human may prefer shrinking the demo's host widgets instead of raising the floor.
2. `serviceController()` defaults guides to user-off, so existing service tests see a not-selected toggle; new tests use `guides: true`.
3. The restaurant demo had no failing tests, so no change there.
4. TDD order as noted above.

## Fix round 1
- Reverted the 840 px test change. The toggle stays uniform with Undo/Redo (40 px, no compact styling; a 30 px compact try did not fit anyway).
- Measured: the demo bar has zero slack at 800 px, so the title yields the toggle's 40 px: `_DocumentTitle` maxWidth 144 -> 104 in apps/architecture_demo/lib/document_host.dart (comment updated).
- DC12/DC12c are back at their original 800 px text. One change beyond comments: DC12 line 846 asserted `width == 144, reason: 'bounded at 144'`; it now pins 104. It pins the bound the ruling changes. Comments naming 144 px updated.
- Gates: architecture_demo +176 pass, analyze clean, format clean; restaurant_demo +112 pass, analyze clean, format clean; plan +1747 pass, analyze clean, format clean.
