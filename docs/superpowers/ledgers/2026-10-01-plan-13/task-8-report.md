# Task 8 report — App: FileKind (spec D8, M-13ac)

Commit: f181afc `feat(app): file kinds for export` (on f625d80). Not pushed.

## Files
- apps/floor_planner/lib/document_files.dart: `enum FileKind { jetplan, pdf, png }` with `extension`, `label`, `mimeType` fields and a `typeGroup` getter (`XTypeGroup(label:, extensions: [extension])`); `fileNameFor(String? typed, FileKind kind)`; `jetplanFileName` kept, delegating to `fileNameFor(typed, FileKind.jetplan)`; pure helper `saveTypeGroupsFor(FileKind kind)` (the io rule, factored out so it is VM-testable); interface `saveLocation(name, {kind = FileKind.jetplan})`, `write(location, name, bytes, {kind = FileKind.jetplan})`. `kJetplanTypeGroup` kept (the open panels use it).
- lib/document_files_io.dart: save panel uses `saveTypeGroupsFor(kind)`; path returned unchanged for every kind (the existing io rule: the panel appends the extension, the sandbox grant forbids appending); write ignores kind.
- lib/document_files_web.dart: `fileNameFor(await askName(...), kind)`; blob type `kind.mimeType` (jetplan keeps `application/json`, what the web write used before).
- lib/document_files_stub.dart: unchanged (it only has a throwing `createDocumentFiles`, no class to change).
- test/support/fake_document_files.dart: `FakeWrite` gains `kind`; new `saveLocationKinds` list parallel to `saveLocationCalls` (kept `List<String>` so existing tests that compare it stay unchanged).
- test/document_files_kind_test.dart (new, 6 tests FK1-FK6).

## Decisions
- Case sensitivity: kept case-sensitive, as `jetplanFileName` always was (`endsWith`): `plan.PDF` + pdf -> `plan.PDF.pdf`. Tested in FK1.
- Labels: 'Jet plan' (unchanged), 'PDF document', 'PNG image'.
- The io side never appended an extension (plan said "if the io side does that"); the per-kind io rule is therefore just the type group, factored into `saveTypeGroupsFor`.

## Gates (real tails)
App `CI=true flutter test`: `03:49 +901: All tests passed!` (895 + 6 new)
`CI=true flutter analyze`: `No issues found! (ran in 2.1s)`
`dart format --output=none --set-exit-if-changed .`: `Formatted 156 files (0 changed)`, exit 0
`CI=true flutter build web --release`: `✓ Built build/web`
Engine and render packages: not touched (diff touches only apps/floor_planner); not re-run. Allocation invariant tests unedited. analysis_options.yaml not staged.

## Mutants (each: cp backup, sed one line, run test/document_files_kind_test.dart, cp back, diff exit 0 -> `restored=0`)
| id | file:line | mutation | red test | output |
|---|---|---|---|---|
| M-13ac | lib/document_files.dart:103 | `'.${kind.extension}'` -> `'.${FileKind.jetplan.extension}'` | FK1 | `Expected: 'plan.pdf'  Actual: 'plan.jetplan'` |
| M-8mime | lib/document_files.dart:36 | pdf mimeType `application/pdf` -> `application/json` | FK4 | `Expected: 'application/pdf'  Actual: 'application/json'` |
| M-8io | lib/document_files.dart:61 | `[kind.typeGroup]` -> `[FileKind.jetplan.typeGroup]` | FK5 | `Expected: 'PDF document'  Actual: 'Jet plan'` |
| M-8fake | test/support/fake_document_files.dart:119 | `kind: kind` -> `kind: FileKind.jetplan` | FK6 | `Expected: [FileKind.png, FileKind.jetplan, FileKind.pdf]` ... red |
All four red; all restored (`restored=0`).

## Spec/plan notes
- Plan/spec say the web `saveLocation` "appends .jetplan today": true; the io side never appends (it returns the panel's path unchanged), so "the io side's extension rule per kind" reduces to the type group.
- The web file's use of `kind.mimeType` and `fileNameFor` is not reachable from VM tests (reviewed by reading + web build only); a mutant there (e.g. hard-coded 'application/json') would survive all tests. Same for the io file calling `saveTypeGroupsFor(kind)` vs a constant. Known limit, as for plan 12a's platform files.
- `kind` on `write` is unused by io (bytes written as-is); it exists for the web MIME type and the fake.
