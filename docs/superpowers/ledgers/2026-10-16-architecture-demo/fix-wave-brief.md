# 3b final fix wave — brief

The whole-branch review (Sonnet, `final-review.md`) found the branch ready to merge after fixes: 0 Critical, 1 Important, 5 Minor. This wave is the plan's one fix dispatch. It closes those, the Minors parked during the tasks, and replaces the manual smoke run with an automated one (the human's choice). Rules: `dispatch-notes.md` in full. Every behaviour change and every restored or new assertion names a mutation that turns it red; run, revert with `git checkout --`, show `git diff --quiet`.

## A. Code

- **A1 (Important I1).** `apps/architecture_demo/lib/busy_wrappers.dart`: `busyExportDialog`'s and `BusyPagePrinter.print`'s `finally` clears `busy` with no disposed guard. Pass the wrappers a way to know the session is disposed (the session itself, or a `bool Function() isDisposed`) and skip the clear once disposed, as `_flow` does. Test in `test/export/busy_test.dart`: hold the printer, unmount the app (`pumpWidget(SizedBox())`), complete the job: no error. Mutation: remove the guard.
- **A2 (Minor M1).** `document_host.dart` `openFlow`: `if (!mounted) return;` after the picker's await, before `load`. Give `FakeDocumentFiles` a hold hook for `open()` (in `test/support/app_fakes.dart`) and add a held-picker teardown test. Mutation: remove the check (the test must catch it: assert no `load` reached the disposed controller, e.g. by a spy or by the error surfacing; make the assertion real).
- **A3 (Minor M2).** `exportFlow`: a `mounted` check after the awaited panel and after the write (before anything else); a held-write teardown test. Mutation: remove it.
- **A4 (parked).** Drop the app's own `PlanSymbolLoader` field in `lib/main.dart` (the controller makes and disposes its own over the same kit sources; Task 7 proved the mutation equivalent). Every test stays green.
- **A5 (parked T5-M1).** The exit's settle by a discarded `controller.save()` appends a duplicate `damagedUnsavable` diagnostic on a damaged plan. Avoid it: settle another way if one exists publicly (re-check: PlanEditor settles before its callbacks; is there a public route now, after Task 4b?), else only call `save()` when not damaged if that is readable publicly, else document the duplicate in a comment and pin its count. Say which.
- **A6 (parked T5-M2).** A test of the exit path when the settle's `save()` throws: the exit still proceeds per the old order (dirty asks). Mutation: let the throw escape.

## B. Restored assertions (parked T7, weakenings)

- **B1 (T7-M1).** `test/symbols/symbol_section_end_to_end_test.dart` WE3: also assert the back-centre's along-wall position on wall B equals the drop point's projection (within the page grid step). Mutation: offset the placed position along the wall in a scratch edit of the move path (or of the test's drop point after the fact) so only the new assertion reds.
- **B2 (T7-M2).** `symbol_palette_end_to_end_test.dart`: the cell image must be the cache's: render/look up the same key in `c.thumbnails` and compare (`isCloneOf` or equal image bytes). If the key is not reachable publicly, say so and keep the current check with a `// Decided:` note.
- **B3 (T7-M3).** `symbol_shell_test.dart` SS7 intent: after New, the canvas shows no placement ghost (find the ghost's paint or the tool's overlay state through public means).
- **B4 (T7-M4).** SS14-open: anchored id match (`architecture.sofa…` pattern, e.g. `matches(RegExp(r'^architecture\.sofa'))` or `contains('.sofa')`) for every element; SS13-open: the old document is disposed after New (`before.commands.isDisposed` if reachable; else `// Decided:` why not).

## C. Test hygiene (Minor M3-M5)

- **C1.** One `titledDirty` and one `canvasFocused` in `test/support/app_rig.dart` (parameterised as needed); delete the copies in `document_exit_test.dart`, `document_replace_test.dart`, `document_save_test.dart`, `document_settle_test.dart`, `symbols/symbol_palette_end_to_end_test.dart`. Shared `far` constants too if identical. No assertion changes.
- **C2.** A header on `test/support/app_fakes.dart` (what was ported, what is new); fix `export_rig.dart`'s header wording.

## D. The smoke run, automated (the human's choice)

- **D1.** `apps/architecture_demo/integration_test/smoke_test.dart` (dev dependency `integration_test: sdk: flutter`): `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`; pump the real `ArchitectureDemoApp` with a files object backed by a temp directory (real disk writes; the io implementation's panels cannot be driven, so a small `DocumentFiles` over `Directory.systemTemp.createTempSync()` in the test file) and the real printer untouched. Steps: tap `toolbar-open-sample`; assert walls/rooms/furniture live; draw one wall with the wall tool by pointer events; Save As `smoke.jetplan` (the temp files object answers the location); New; Open `smoke.jetplan`; assert the reopened plan's `controller.save()` equals the written file's text and holds the drawn wall; capture the editor through a `RepaintBoundary` (`toImage` → PNG) and write it to `docs/superpowers/notes/2026-10-16-architecture-demo-smoke.png` (path from the app dir: `../../docs/...`).
- **D2.** Run it: `cd apps/architecture_demo && flutter test integration_test/smoke_test.dart -d macos`. Transcribe the last lines. If the macOS run cannot start for an environment reason, report the exact output; do not fake a pass.
- **D3.** Commit the PNG (it is a result of record).

## E. After the wave

- Re-run and transcribe: app test/analyze/format; `jet_cad_2d_plan` (`--enable-vmservice`) and `jet_cad_2d_integration` (`--enable-vmservice`) test/analyze/format; the smoke integration test; `flutter build macos` and `flutter build web`.
- In `docs/superpowers/notes/2026-10-16-architecture-demo-results.md`: replace the "## Smoke run" pending line with the automated run (command, last lines, the PNG link, and one line: the human declined interactive control, chose the automated test); append "## Final fix wave" (items closed, gates, commits). Change no earlier figure.
- Commits by kind: `fix(demo): …`, `test(demo): …`, `docs: …`.

Report: `.superpowers/sdd/2026-10-16-architecture-demo/fix-wave-report.md`.
