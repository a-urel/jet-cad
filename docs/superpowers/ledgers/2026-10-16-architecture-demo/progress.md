# SDD ledger — plan: docs/superpowers/plans/2026-10-16-architecture-demo.md

Spec: docs/superpowers/specs/2026-10-16-architecture-demo-design.md (approved 2026-10-16). Plan approved 2026-10-16 ("onaylıyorum").
Branch feat/architecture-demo, worktree .claude/worktrees/architecture-demo, from main a156c5a2.
Reviewers: Sonnet only (human, 2026-10-16: no Opus reviews). Implementers: Sonnet by default.

## Pre-flight scan

| Pair / task | Shared file or interface | Finding |
|---|---|---|
| T1 → T2, T6 | `kFileChords` (T2 chord layer), `showPlanExportDialog` (T6 wrapper) | consistent: T1 produces both, exported names match |
| T2 → T3 | `ArchitectureDemoApp` seams (`files`, `exitGuard` added later) | T2 states T3-T4 add them; T3 adds `exitGuard`/`files`? T3 only creates the file layer; the seams are wired in T4 step 3. Ruled below |
| T3 → T4 | `AppStrings` (cancel word), fakes in `app_fakes.dart` | consistent |
| T4 → T5 | `document_host.dart`, rig | T5 extends T4's host; consistent |
| T4 → T6 | `document_host.dart` build (`printer`, `onExport`) | T4 passes `printer: widget.printer`; T6 replaces with `BusyPagePrinter`; consistent |
| T4 → T7 | rig `pumpApp` | consistent |
| T7 → integration package | new file `layer_picker_types_test.dart` | outside the app; allowed by spec (audit row) |
| T1 | own text | test + export + gates; consistent |
| T2 | own text | AS1 mutation `kits: []` — PlanController may refuse an empty kit set (validateKitSet); implementer picks another mutation if so |
| T3 | own text | consistent |
| T4 | own text | `_mayDiscard` sync-dirty question left to the implementer with a read; consistent |
| T5 | own text | consistent |
| T6 | own text | consistent |
| T7 | own text | LG red-on-today → stop rule; consistent |
| T8 | own text | smoke step is the controller's; consistent |

Ruling: T2-T4 seams — `ArchitectureDemoApp` gets `files`, `createFiles`, `exitGuard` in Task 4 step 3 (with the session and host); Task 3 creates the layer and fakes only — the plan's Interfaces line "Tasks 3-4 add the other two" reads as Task 4 — cost if wrong: none (one constructor).
Ruling: T2 AS1 mutation — if `PlanController(kits: [])` throws, use "no `symbols:` loader" or another mutation that removes the Symbols tab — the plan's mutation is illustrative — cost: none.

## Tasks
Ruling: Tasks 1 and 2 dispatched as one batch to one Sonnet implementer and reviewed as one unit — Task 1 is a two-name export with no judgment, and the human asked to save cost — cost if wrong: one review covers two commits.
Task 1: complete — 42e3fa4c (exports showPlanExportDialog, kFileChords; barrel ED-9 pinned).
Task 2: complete — a66b3807, 22611489, 296dd27d (controller's fix of review Minor 1: pubspec comment). Sonnet review: Approved/Approved, 0C 0I 3M. Deviations accepted: jet_cad_2d_plan ^0.8.0; app owns PlanSymbolLoader (controller never disposes a given loader); no font family; AS-dispose rewritten (reparent + unmount).
Parked: M2 `symbols: null` survives every test — carried to Task 7 (symbol tests must pin the furniture palette through the app). M3 N1 scope (lib/test/pubspec only) — accepted, spec B6 says exactly that.
Task 3: complete — 15cf9ba5. Sonnet review: PASS/PASS, 0C 0I 3M. Copied layer byte-identical; app_strings differs by header + pageFlowFailed. Moved to Task 4 (need the wired app): AW1, AW2, AW4, DS3 — carried in Task 4's dispatch with full assertions (review Minor). AW-locale added (word level).
Task 4: implemented — d4fa1f34, c5671088, f311b08e, 00dc9c44 (+90 ~4). Concerns ruled:
Ruling: the 4 skips (ST2, ST3, ST8, ST4-focus) are a library parity gap (old shell's settle finished the text entry and handed panel focus back; the new settlePendingInput does not) — Task 4b fixes it in jet_cad_2d_plan per decision 10 and unskips — cost if wrong: a library change to the 2a settle.
Ruling: DC12 at 900 px weakens the old 800 px assertion — Task 4b narrows the name widget to fit 800 px — cost: a shorter name before the ellipsis.
Ruling: Undo/Redo/canvas edits stay live during a held write (RN1-open-undo) — accepted under decision 5: the save point is the encoded state, so dirty stays right — cost: the old "everything held" behaviour is gone.
Ruling: identity guard on markSaved/named after a write kept (RN3 needs it) — the plan said none needed; the test proves otherwise — cost: none.
Ruling: DO6-open-scale split, DC5-open-sample, the app's dev deps (jet_cad_2d, jet_cad_2d_flutter, jet_cad_2d_kit, vector_math) accepted.
Ruling: DC12c's old range (704→656 px) is impossible under the library bar's fixed 616 px + the name — split: DC12c-open pins the new floor (776 px), the premise note stays — cost: a narrow window overflows below 776 px.
Task 4b: implemented — 1233a6ca (plan: settle finishes text entry, page panel hands focus back), 1b00fdaa (app: name maxWidth 160, DC12 at 800 px, skips removed). plan 1554, integration 227, app 94.
Task 4/4b review (Sonnet): spec PASS, quality PASS WITH FINDINGS — 0C 2I 4M.
Ruling: I2 (openFlow asks before the picker; an edit during the picker is lost on load) — not fixed: the old app asked before the picker on purpose (spec 12a D10, as macOS apps do), busy holds the file callbacks, and the picker is modal on macOS — cost if wrong: a web user who edits while the picker is open loses that edit.
Fix round 1 (resumed the 4b implementer): I1 (settle unregister/re-register tests), M1 (ST4 merged back), M2 (ST1 note), M3 (busy set after dispose), M4 (SET-1 moved).
Fix round 1: d4141133, e1111e50 — re-review: all addressed (I1, M1-M4); plan 1556, integration 227, app 94.
Task 4: complete (with 4b). Carried to Task 5: after a teardown mid-flow, `_mayDiscard`'s continuation may call `newPlan`/`load` on the disposed controller (re-review, unrun, low).
Task 5: complete — 7d1bcba0, 9ad321d6 (app +107). Sonnet review PASS/PASS WITH FINDINGS, 0C 0I 2M. Exit settles via a discarded controller.save() (no public settle). Teardown carry-over: no error, pinned by RP-teardown.
Parked for the final fix wave: T5-M1 the discarded save() appends a duplicate diagnostic on a damaged plan; T5-M2 no test for the throwing-save exit path.
Task 6: implemented — e9d7c93a, 1b133ff4 (app +140).
Ruling: busy wrappers refuse while busy (dialog returns null, printer returns) instead of nesting — a nested wrapper would start an export/print during a held write, since the library's buttons do not grey — cost: Export/Print pressed during a write do nothing silently.
Ruling: the dialog-close → onExport gap (library renders with its guard held, app not busy) stays open, pinned by N6-gap and documented; a library signal is a follow-up — matches the spec's Risks — cost: a Save in that gap writes its file and the export writes too.
Ruling: name widget 144 px, DC12c floor 800 px (the Export button joined the bar) — cost: shorter names before the ellipsis.
Task 6 review (Sonnet): PASS / PASS WITH FINDINGS, 0C 1I 3M (EX12 lost 'handled'; PR1/EX1 content weakened; EF12 bytes). Fix round 1: resumed the Task 6 implementer to restore them.
Fix round 1: e0e19eda — re-review: all addressed. Task 6: complete (app +140).
Task 7: implemented — 486e19be, 40ec1062 (app 171, plan 1558, integration 228). No LG red on today's library: no fix task.
Ruling: the carried `symbols:` mutation is equivalent (the controller makes its own loader over the same kit sources) — the final fix wave drops the app's own loader field (simpler, nothing to pin) — cost: none.
Task 7 review (Sonnet): PASS/PASS, 0C 0I 5M. LG4 not a parity defect (old symbol_panel also ExcludeFocus, ruling 05-6).
Task 7: complete.
Parked for the final fix wave (weakenings, must be restored): T7-M1 WE3 position along B; T7-M2 palette cell image as a clone of c.thumbnails; T7-M3 SS7 no ghost after New; T7-M4 SS14-open anchored id match, SS13-open old document disposed. Plus: drop the app's own PlanSymbolLoader field; T5-M1, T5-M2.
Task 8: steps 1, 2, 4 complete — 40dab63c (audit closed 194/194; gates green; dry-run 0 warnings). Smoke: app launched on macOS via flutter run (VM service up, no error in log); computer-use access for the app was DENIED by the human — interactive smoke not done; asking the human.
Ruling (human chose, 2026-10-16: 'Otomatik test yaz'): the smoke run becomes an integration_test on macOS driving the real app (sample, draw a wall, save to a temp dir, new, open, screenshot via RepaintBoundary to PNG) — in the final fix wave.
Final review (Sonnet): ready to merge after fixes, 0C 1I 5M. Fix wave brief: fix-wave-brief.md (A1-A6, B1-B4, C1-C2, D1-D3).
Fix wave: 4fa37742..826f08c1 (14 commits) — re-review (Sonnet): Approved. App 176, plan 1558, integration 228; macOS smoke integration test +1 passed; builds OK. Open minor: A5's damaged-plan guard has no red test (no public way to damage a plan through the kit).
Look finding (smoke PNG): the Page panel's "Landscape" button wraps to "Landscap/e" at 1440 px — plan library, for the human.
Archive: ledger copied to docs/superpowers/ledgers/2026-10-16-architecture-demo/ with README row; STATUS updated.
