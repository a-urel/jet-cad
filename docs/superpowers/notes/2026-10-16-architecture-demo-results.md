# The architecture demo (sub-project 3b): results of record

Branch `feat/architecture-demo`, cut from `main` at `a156c5a2`. Head at the
gates: `40ec1062` (the commit that adds this note sits on top of it); 23
commits over `main`. Plan:
`docs/superpowers/plans/2026-10-16-architecture-demo.md`. Spec:
`docs/superpowers/specs/2026-10-16-architecture-demo-design.md`. Audit and its
closure: `docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md`
("Closed (3b)"). Transcripts copied from the terminal on 2026-10-16, last
lines only, all from this run (Task 8, on the head above).

The whole-branch review and its fix wave are the controller's and are not
recorded here yet.

## Gates (this run)

| Package | test | analyze | format |
|---|---|---|---|
| `apps/architecture_demo` | `00:32 +171: All tests passed!` | `No issues found! (ran in 3.8s)` | `Formatted 43 files (0 changed)`, exit 0 |
| `packages/jet_cad_2d_plan` (`--enable-vmservice`) | `02:00 +1558: All tests passed!` | `No issues found! (ran in 4.0s)` | `Formatted 301 files (0 changed)` |
| `packages/jet_cad_2d_integration` (`--enable-vmservice`) | `00:56 +228: All tests passed!` | `No issues found! (ran in 3.2s)` | `Formatted 80 files (0 changed)` |

Builds, in `apps/architecture_demo`:
- `flutter build macos`: `✓ Built build/macos/Build/Products/Release/architecture_demo.app (48.8MB)`
- `flutter build web`: `✓ Built build/web`

Untouched packages: `git diff --stat main -- packages/jet_cad packages/jet_cad_2d
packages/jet_cad_2d_flutter packages/jet_cad_2d_gpu packages/jet_cad_floor_plan
packages/jet_cad_restaurant_symbols apps/floor_planner` printed nothing.

`cd packages/jet_cad_2d_plan && dart pub publish --dry-run` (dry run only,
never published): `Package has 0 warnings.`

`git status --short` was clean after the builds.

## Smoke run

The human declined interactive control and chose an automated test instead.
`apps/architecture_demo/integration_test/smoke_test.dart` runs the real
`ArchitectureDemoApp` on the macOS binary, with the real printer and a files
object over a temporary directory (real disk writes): Open sample (10 walls,
7 rooms, 15 openings, 5 dimensions, 8 furniture fills), one wall drawn by
pointer events, Save As `smoke.jetplan`, New, Open `smoke.jetplan`; the
reopened plan's `save()` equals the file's text and holds the drawn wall
(11 walls). The editor was captured through a `RepaintBoundary`:
[the screenshot](2026-10-16-architecture-demo-smoke.png) (the sandbox keeps
the app inside its container, so the PNG was copied out by hand).

```
cd apps/architecture_demo && flutter test integration_test/smoke_test.dart -d macos
00:00 +0: smoke: Open sample, draw a wall, Save As, New, Open: the reopened plan is the written file; the editor is captured
SMOKE_PNG .../dev.jetcad.architectureDemo/Data/tmp/2026-10-16-architecture-demo-smoke.png 248646 bytes
00:03 +1: (tearDownAll)
00:03 +1: All tests passed!
```

## Audit totals

The audit's 194 in-scope rows all have an outcome (the audit's "Closed (3b)"
section, built by script from the ported test names and cross-checked against
the Task 1-7 reports): ported 89, split 26, covered 73 (each with a
`checked: file:line` citation), dropped 6, no row open.

## Library changes made (decision 10 and Task 1)

All in `packages/jet_cad_2d_plan` (0.8.0, unpublished changes), each with a
named mutation in its task report:
- Task 1, `42e3fa4c`: the barrel exports `showPlanExportDialog` and
  `kFileChords` (ED-9 pins the exact name set; CHANGELOG line).
- Task 4b, `1233a6ca`, `e1111e50`: `settlePendingInput` finishes an open text
  entry (`TextEntryOverlay` registers a settle) and the page panel hands focus
  back to the canvas; found by four ported cases that the old shell passed
  (ST2, ST3, ST8, ST4's focus assertion). Tests: `canvas/text_entry_settle_test.dart`,
  `panels/page_scale_field_test.dart`.
- Task 7: two new library tests, no behaviour change: `export/page_printer_test.dart`
  (PP-1, the `printing` channel call: PR8) and X-9b in
  `export/export_dialog_test.dart` (Escape cancels). One new integration test,
  `layers/layer_picker_types_test.dart` (the six architecture types alone
  enable the picker).
- The library gaps LG1-LG6 (`library_gaps_test.dart` in the app) were green on
  today's library; none needed a fix.

## Rulings (progress.md)

- T2-T4 seams: `files`, `createFiles`, `exitGuard` arrive in Task 4 with the
  session and host; Task 3 only creates the layer and fakes.
- T2 AS1 mutation: the plan's `kits: []` was illustrative; another mutation
  that removes the Symbols tab is used if the controller refuses it.
- Tasks 1 and 2 dispatched and reviewed as one unit (cost saving).
- The four settle skips (ST2, ST3, ST8, ST4-focus) were a library parity gap;
  Task 4b fixed it in `jet_cad_2d_plan` and unskipped them.
- DC12 at 900 px weakened the old 800 px assertion; Task 4b narrowed the name
  widget (maxWidth 160) to fit 800 px.
- RN1-open-undo: Undo, Redo and canvas edits stay live during a held write;
  accepted (decision 5), the save point is the encoded state so dirty stays right.
- The identity guard on `markSaved` after a write is kept (RN3 needs it).
- DO6-open-scale, DC5-open-sample, DC12c-open split and the app's dev
  dependencies (`jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`,
  `vector_math`) accepted.
- DC12c's old range (704 to 656 px) is impossible under the library bar's
  fixed width: DC12c pins the new floor (800 px after the Export button), the
  premise noted.
- I2 not fixed: `openFlow` asks before the picker, as the old app did on
  purpose; an edit made while the picker is open is lost on load. Cost: a web
  user who edits while the picker is open loses that edit.
- Exit settles by a discarded `controller.save()` (no public settle), then a
  microtask yield, then dirty. Teardown mid-flow: no error, pinned by RP-teardown.
- Busy wrappers refuse while busy (the export dialog answers null, the printer
  returns) instead of nesting. Cost: Export or Print pressed during a write
  does nothing, silently.
- The dialog-close to `onExport` gap stays open, pinned by N6-gap (see
  follow-ups).
- Name widget 144 px, DC12c floor 800 px after the Export button joined the bar.
- The carried `symbols:` mutation is equivalent (the controller makes its own
  loader over the same kit sources); the final fix wave drops the app's own
  loader field.
- LG4 is not a parity defect (the old symbol panel was also `ExcludeFocus`, ruling 05-6).
- Reviewers: Sonnet only (the human, 2026-10-16: no Opus reviews).

## Follow-ups

- **The export gap's library signal.** Between the export dialog closing and
  `onExport` (the bytes being made; a 300 dpi PNG takes about a second) the
  app is not busy and the library has no hook (`pageFlows.ready` is
  `@internal`). A New or Open in that gap runs, and a Save writes its file
  and the export writes too. N6-gap pins it. A public signal from the library
  (a flow-in-flight notifier or a ready hook) would close it.
- **`PlanObject.liveTypeIdOf`** is carried to sub-project 4 (the demo does not
  need it; spec "Out of scope").
- `apps/floor_planner` and the old packages stay until sub-project 4 removes them.
- Parked minors, **closed in the final fix wave** (below; listed as they were parked):
  - T5-M1: the discarded `save()` on exit appends a duplicate diagnostic on a damaged plan.
  - T5-M2: no test for the throwing-save exit path.
  - T7-M1: WE3's position along the second wall (B) is weakened.
  - T7-M2: the palette cell image check is a clone of `c.thumbnails`.
  - T7-M3: SS7 has no check that no ghost remains after New.
  - T7-M4: SS14-open's anchored id match; SS13-open's old document disposed.
  - Drop the app's own `PlanSymbolLoader` field (equivalent mutant above).

## Final fix wave

Closed: the whole-branch review's I1 (teardown guards in `busyExportDialog`
and `BusyPagePrinter`), M1 (`openFlow` stops after a picker that answers on
a dead host), M2 (`exportFlow` the same after the save panel), M3-M5 (one
`titledDirty` and one `canvasFocused` in `app_rig.dart`; headers on
`app_fakes.dart` and `export_rig.dart`); the parked T5-M1 (the exit's settle
`save()` is skipped on a `damaged` plan), T5-M2 (the throwing-save exit path
pinned), T7-M1..M4 (WE3's position along B, the palette cell as a clone of
the controller cache's image, SS7's no-ghost check, SS14-open's anchored
match, SS13-open's disposed document), and the app's own `PlanSymbolLoader`
field (dropped). The smoke run is automated (above). Not closed: the
`damagedUnsavable` duplicate on a damaged plan has no red test (no public
way to damage a plan through the architecture kit); the dialog wrapper's
`isDisposed` wiring in the host is unreachable by a test (the dialog route
dies with the navigator).

Gates after the wave: app `flutter test` 176 passed, analyze clean, format 0
changed; `jet_cad_2d_plan` (`--enable-vmservice`) 1558 passed; `jet_cad_2d_integration`
(`--enable-vmservice`) 228 passed, both clean on analyze and format; the smoke
test passed; `flutter build macos` and `flutter build web` built. Commits:
`4fa37742`, `8295cc76`, `cafa8ff3`, `518e2757`, `492c3719`, `fac57b29`,
`0ce785fb`, `b6831537`, `17a472b8`, `90f1576b`, `6b695558`, `7277dd24`.
