# Task 5 review: exportPagePdf (spec D4; T-4, T-5, T-6, T-8, T-9 for the PDF)

**Scope**
- Reviewer: independent.
- Commits: `d3063ab` (4b), `c134c14`, `72827ed`, range `94653f6..72827ed`. Reviewed in the detached worktree `.claude/worktrees/plan-13-review` at `72827ed`.
- Nothing was committed or staged. At the end, `git status --short` shows only `packages/jet_cad/analysis_options.yaml` (pub get).
- Mutant runner: `scratchpad/r5/mut.py`. It copies the file to `scratchpad/r5/<id>.bak` and makes exact replacements, aborting unless each matches once. It runs the named test file in the foreground, copies the file back and diffs it. Every run printed `RESTORED diff=0`. Logs are in `scratchpad/r5/<id>.log`.
- I wrote one temporary test, `test/zz_review_t5_test.dart`. It was moved to `scratchpad/r5/` before the gate run and is not in the tree.

## 1. 4b closes task-4-review findings 1-5

| Finding | Closed? | Evidence (re-fired) |
|---|---|---|
| 1: measurer typed as `TextMeasurer`; export passes `document.textMeasurer` | Yes | OWN-fresh (two edits: import, then `FlutterTextMeasurer().measure(...)`) is RED: `Expected: … of <605> Actual: <1100.0000144000003>` and `of <70> Actual: <200.00000394>`. Summary `00:00 +16 -2: Some tests failed.` |
| 2: style record | Yes | OWN-style (`textStyleOf(ReservedHandles.standardTextStyle)`) is RED: `of <70> Actual: <110.00000062999999>`, `00:00 +17 -1`. The fixture's "WC" is now under "Label"/Arial, pinned in `export_fixture_test.dart`. |
| 3: `/FontFile2` must be a stream | Yes | OWN-rd-ff (`descriptor?[key] != null`) is RED: `Expected: ['/CIDFontType2', null] Actual: ['/CIDFontType2', '/FontFile2']`, `00:00 +25 -1`. |
| 4: utf16 strict | Yes | The bfchar, bfrange and bfrange-array cases throw. The surrogate pair reads as U+1F600. The package's astral `/ToUnicode` defect is recorded in the report for the results note. |
| 5: CID guard | Yes | The guard sits before `_pushTransform`/`_fillState`, and the test asserts nothing is left behind. OWN-cid (`if (false)`) is RED: `Actual: <Closure: () => void>`, `00:00 +17 -1`. |

The implementer added a `simpleTrueTypeFonts` parameter to `_render` (`pdf_draw_sink_text_test.dart:472`), but no caller passes it. The CID test builds its own `PdfDocument`. This is dead (finding 4).

## 2. `exportPagePdf` against D4 as amended by R-13-14 (`lib/src/export/page_export.dart`)

| D4 point | Verdict |
|---|---|
| `pageCamera(page, 72/25.4)` | Yes (`:36`). |
| Page format = camera size | Yes (`:40`): `PdfPageFormat(camera.size.width, camera.size.height)`. The page camera's size is already the oriented size. |
| `SpatialIndex` disposed in `finally`, also on a throw | Yes (`:42-63`). This was checked empirically: an export with garbage font bytes throws `IndexError`, and both dispatcher hooks are null afterwards. |
| Resolver foreground `0x000000` | Yes (`:57`). |
| `DraftPainter(minTextCapPixels: 0.0, omitOwners:)` | Yes (`:54-60`). |
| `PdfDrawSink` gets `document.textMeasurer` and `document.textStyleOf` | Yes (`:51-52`). |
| `write(PdfStream)`, not `save()` | Yes (`:64-66`). No isolate. |
| No `VerticesDrawSink`, `TileCache` or `DraftCanvas` | Yes. Grep of the file finds none. |
| Exported from the library | Yes (`jet_cad_2d_flutter.dart`). |

**Async gaps.** The index lives only across synchronous code. It is disposed before the one `await` (`pdf.write`), so no edit can interleave while it exists.

**The measurer's caches.** Calling `measure` fills or evicts the measurer's own cache. That is not document state: the codec and `stateId` are unchanged (T-9). At worst it costs the screen some cache hits.

**"Does not mutate the document": it does, through the dispatcher's hooks (finding 1, high).**
- `SpatialIndex(document)` *assigns* `document.commands.onAfterMutate = _onChange` and `onBeforeMutate = _guardMutation` (`packages/jet_cad_2d/lib/src/index/spatial_index.dart:167,173`).
  - These are single slots, not listener lists (`undo.dart:133,142`).
- `dispose()` nulls them when they are its own (`:3066-3076`).
- The app's shell holds a long-lived `SpatialIndex(_document)` over the live document (`apps/floor_planner/lib/main.dart:243`).
- So an export of the live document (Task 9) silently unhooks the screen's index for good. Every later edit, undo or redo leaves the screen's culling, picking and snapping stale.
- The thumbnail recipe the spec copied (F-6) is safe only because its document is private.
- Real lines from my temporary test (fixture document, a "screen" index built first, one export, then one line added by command):
  ```
  REVIEW before export: hooks set true true; count 0
  REVIEW after export: onAfterMutate==screen's false, null true; onBeforeMutate null true
  REVIEW after an edit: screen index sees 0, a fresh index sees 1
  ```
- T-9 checks only the codec and `stateId`, so it cannot see this.

## 3. Tests (`test/export/export_pdf_test.dart`, 20 tests)

**Route.**
- Every T-4, T-5, T-6, T-8 and T-9 test calls `exportPagePdf(compress: false)` and reads the result back through `PdfContent`.
- The measurer pins and the `compress: true` smoke test also go through it.

**Independence.**
- `toPage` (`:36-39`) computes `((x - 3000)/den·u, (y + 1500)/den·u)` from the fixture's constants. It does not go through `pageCamera`.
- The instance's image uses the fixture's `kExportInstanceTransform`, which is a fixture constant and not the export's code.
- The instance-position test went red under M-13d, so it is not tautological.

**Fixture.**
- The origin is (3000, -1500), at 1:50 and 1:100.
- The instance is rotated 30° and mirrored (1.5, -0.75), with red and 0.70 mm overrides.
- The page is dark (`0xFF303030`, asserted in T-6), and "WC" is under a non-standard style.
- The lineweight-0 line is added by command per scale group. I accept that (report item 4).

**Weak spots.**
- Every export test uses one page format, A4 landscape. A format hard-coded to `PdfPageFormat.a4.landscape` survives (REV-a4 below), and so would any format bug that happens to be right for A4 landscape. See finding 2.
- The T-6 loop over the instance's strokes (`:165-167`) would pass if it were empty. It is protected only by T-5's `hasLength(2)` in the same group. Acceptable.

## 4. Mutants

E = `lib/src/export/page_export.dart`, ET = `test/export/export_pdf_test.dart`. Each was fired against ET unless noted.

| id | mutation | result (real lines) |
|---|---|---|
| M-13b | E: `pixelsPerPaperMm: 1.0` | RED: T-4, 0.70 mm and 0.35 mm, at 1:50 and 1:100 (`of <0.99212…> Actual: <0.35>`). `00:00 +16 -4: Some tests failed.` |
| M-13c (normalised) | E: `camera.pixelsPerPaperMm * (50 / page.scaleDenominator)` | RED **at 1:100 only**, both widths (`Actual: <0.99213>`, `Actual: <0.49606>`). `00:00 +18 -2` |
| M-13c (raw) | E: `camera.pixelsPerPaperMm * camera.camera.scale` | RED at both scales (`Actual: <0.02812>`). `00:00 +16 -4` |
| M-13d | E: import `page_fit.dart`; `paint(sink, fitToPage(page, camera.size), camera.size)` | RED ×7: T-5 position (`Actual: []`), T-5 baseline origin, T-4 instance width at both scales, T-6 ACI 7, T-6 red, T-8 positive. `00:00 +13 -7` |
| M-13n | E: `DocumentStyleResolver(document)` | RED: `Expected: [0, 0, 0] Actual: [1.0, 1.0, 1.0]`. `00:00 +19 -1` |
| M-13o | sink `_alpha`: `const opacity = 1.0;` | RED: `of <0.5019607843137255> Actual: <1.0>`. `00:00 +19 -1` |
| M-13p | E: `minTextCapPixels: 0.0` line removed | RED ×5: `Actual: ['Yatak Odası']`; plus the baseline origin, both measurer pins and the compress smoke test. `00:00 +15 -5` |
| M-13x | E: `SetComponentCommand<PageComponent>(rootHandle, page)` executed before the index | RED: `Expected: <23> Actual: <24>`. `00:00 +19 -1` |
| REV-omit (mine) | E: `omitOwners:` not forwarded | RED: T-8 omitted (`Actual: [`). `00:00 +19 -1` |
| REV-swap (mine) | E: `PdfPageFormat(height, width)` (portrait for landscape) | RED ×9. `00:00 +11 -9` |
| REV-px (mine) | E: the format in 96-dpi px, not pt (`× 96/72`) | RED ×9. `00:00 +11 -9` |
| REV-viewport (mine) | E: `paint(…, camera.size / 2)` (culling viewport halved) | RED ×10 (`Actual: ['Yatak Odası']` among them). `00:00 +10 -10` |
| REV-a4 (mine) | E: `pageFormat: PdfPageFormat.a4.landscape` | **survives**, `00:00 +20: All tests passed!`. Finding 2. |
| REV-dispose / OWN-ex-dispose | E: `// index.dispose();` | **survives** on ET: `00:00 +20: All tests passed!`. It is **observable**, though. With the same mutant, my temporary test printed `hooks null after: false false` (no prior index) and `REVIEW throw: IndexError; hooks null after: false false`, against `true true` unmutated. See finding 1. |

**"Index not disposed" is pinnable without a debug counter.** `document.commands.onAfterMutate` and `onBeforeMutate` are public. A non-disposed index leaves them pointing at a dead index, which keeps reconciling on every edit (a leak plus per-edit cost). I recommend pinning it, not accepting it, together with finding 1's fix.
- Once finding 1's restore is in, a missing `dispose()` stops being visible through the hooks: the restore overwrites them.
- What remains is only the retained `ContainerIndex` maps of an unreachable object, which the GC reclaims.
- At that point, accepting the mutant as equivalent "by experiment" is fair.

## 5. Gates and scope

- Render, `CI=true flutter test` at `72827ed`: `01:04 +1124 ~1 -7: Some tests failed.`
  - The 7 deduplicated `[E]` failures are text ladder rungs 1-5 and text lod ladder rungs 1-2 (RenderBackend.canvas), the standing set.
  - No `[E]` comes from either allocation invariant file.
- `CI=true flutter analyze`: `No issues found! (ran in 2.1s)`.
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 198 files (0 changed)`, `format_exit=0`.
- Scope:
  - `git diff --stat 94653f6..72827ed -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants` prints nothing.
  - `--name-only` lists only the nine render-package files named in the report.

## Verdict: **Needs fixes**

The function matches D4/R-13-14 point by point. The tests are routed correctly and are non-degenerate, and every named mutant is red. But the export rewrites the live document's dispatcher hooks. That breaks the app's screen index after the first export, and T-9 cannot see it. The fix is small and local to `page_export.dart` plus one test group, and it must land before Task 9 wires the export into the shell.

## Findings

1. **High: the export unhooks the screen's `SpatialIndex` from the live document.**
   - Where: `lib/src/export/page_export.dart:42,61-63`; the mechanism is `spatial_index.dart:167,173,3066-3076`.
   - Problem: `SpatialIndex(document)` overwrites the dispatcher's single `onAfterMutate`/`onBeforeMutate` slots, and `dispose()` nulls them. The shell's index (`main.dart:243`) then never hears another edit (demonstrated: `screen index sees 0, a fresh index sees 1`). This also breaks D4's "writes nothing to it" and spec I-3.
   - Fix:
     - Capture `final afterMutate = document.commands.onAfterMutate, beforeMutate = document.commands.onBeforeMutate;` before `SpatialIndex(document)`.
     - In `finally`, *after* `index.dispose()`, restore both.
     - Add a comment that this is sound only because no `await` lies between the construction and the `finally`.
   - Test, through `exportPagePdf`, in a T-9 group:
     - Build a "screen" `SpatialIndex(f.document)` first.
     - Assert both hooks are `==` before and after a normal export *and* after a throwing export (bad `fontBytes`).
     - Then add a line by command and assert the screen index's `forEachInRect` sees it.
     - Add a no-prior-index case asserting the hooks are null after.
   - Mutants: drop the restore (red); restore before `dispose()` (red in the no-prior-index case only if dispose then nulls; check by experiment); `dispose()` removed (red before the restore exists, then record it as equivalent).
   - Spec amendment at Task 11: D4/I-3 should say "the dispatcher's hooks are unchanged".
   - Task 9's T-10 should also edit after an export in the pumped shell.
2. **Low: the page format is only ever A4 landscape.**
   - Where: `test/export/export_pdf_test.dart:66-72`.
   - Problem: REV-a4 (`PdfPageFormat.a4.landscape`) survives.
   - Fix: one export of the fixture with the page set to another paper or orientation (e.g. A3 portrait, by `SetComponentCommand<PageComponent>` in the fixture's setup, not inside the export). Assert MediaBox `[0 0 297u 420u]` and one known point (e.g. the ACI 7 line's start) at its independently computed position.
3. **Low: "index not disposed" is recorded as unobservable, but it is observable.**
   - Where: task-5-report item 6 and mutant OWN-ex-dispose.
   - Problem: the public dispatcher hooks show it (§4).
   - Fix: covered by finding 1's tests. Afterwards, re-record OWN-ex-dispose by experiment.
4. **Info: a dead test parameter.**
   - Where: `test/export/pdf_draw_sink_text_test.dart:472-475`.
   - Problem: `_render`'s `simpleTrueTypeFonts` parameter is never passed.
   - Fix: remove it, or use it in the CID test instead of the hand-built document.

---

## Re-review (5b)

**Scope**
- Commit: `8fe438b` on `72827ed`, reviewed in the detached worktree at `8fe438b`.
- Nothing was committed or staged. `git status --short` shows only `packages/jet_cad/analysis_options.yaml`.
- Mutants were run with the same runner (`scratchpad/r5/mut.py`): a `cp` backup, exact replacements, the test file run in the foreground, a `cp` back. Every run printed `RESTORED diff=0`.

### Finding 1: closed, soundly

**The code.** `_withExportIndex` (`page_export.dart`):
- It captures `onAfterMutate` and `onBeforeMutate` before the index is built.
- It builds the index inside the outer `try`, so a throw from `SpatialIndex(document)`/`rebuildAll()` is also covered.
- It runs `body` and disposes the index in an inner `finally`.
- It restores both hooks in an outer `finally`, after `dispose()`.
- `body` is `void Function(SpatialIndex)`, synchronous by type, and `pdf.write` (the one `await`) stays outside it. Between the capture and the restore:
  - no edit can run;
  - the screen index cannot be disposed or replaced;
  - nothing the restore writes can be stale.
- The ordering also covers the no-prior-index case: it restores `null`.

**No detached-index option exists.** `SpatialIndex` has one constructor, `SpatialIndex(this.document)` (`spatial_index.dart:161`). It always calls `rebuildAll()` and assigns both hooks; there is no flag and no named constructor (`grep "SpatialIndex\.\w*("` finds none).

**No other registrations.**
- Grep over `packages/jet_cad_2d/lib/src/index/` for `.listen(`, `addListener`, `subscribe`, `.changes` and other `document.x =` assignments finds only the two hook assignments (`:167,173`) and their conditional nulling in `dispose()` (`:3066-3076`).
- `rebuildAll()` and `ContainerIndex.build` only read the document: `tree`, `entities`, `geometry`, `textStyleOf` and `textMeasurer` (metrics, a cache).
- `dispose()` clears only the index's own maps.
- So the restore covers every shared slot the index touches.

**Tests** (`export_pdf_test.dart`, group "T-9: the dispatcher's mutation hooks are left as found"):
- **Screen-index test.** A screen index is built first.
  - Both hooks are `==` after a normal export and after a throwing export (64 bytes of `7` as the font).
  - The screen index's `forEachInRect` over an empty probe counts 0, then 1 after a line is added by command.
- **No-index test.** The hooks are null before, after a normal export and after a throwing export.

**Mutants** (each fired against `export_pdf_test.dart`):

| id | mutation | result (real lines) |
|---|---|---|
| B2-norestore | outer `finally`'s restore deleted | RED: `Expected: <Closure: (DocChange) => void from Function '_onChange@649435428':.> Actual: <null>`, reason `normal export`. `00:00 +22 -1: Some tests failed.` |
| B2-normalonly | no outer `try/finally`; restore after the inner `try/finally`, on a normal return only | RED: the same `Actual: <null>`, reason `throwing export`. `00:00 +22 -1: Some tests failed.` |
| B2-nodispose | `// index.dispose();` | survives, `00:00 +23: All tests passed!` |
| B2-restorefirst | restore also inside the inner `finally`, before `dispose()` | survives, `00:00 +23: All tests passed!` |

**The two survivors are equivalent, by experiment and by reading.**
- **B2-nodispose.**
  - The restore overwrites the dead index's hooks, and the index registers nothing else (above), so nothing outside the local frame refers to it.
  - What is left is its own maps, which the GC collects. Nothing observable differs.
  - Both T-9 tests pass under it, including the edit the screen index must hear.
- **B2-restorefirst.**
  - After the early restore, `dispose()` sees hooks that are not its own (the screen's, or null) and leaves them.
  - The outer `finally` then writes the same values again.
  - Both cases pass.

I accept both as equivalent.

### Finding 2: closed

- The new test sets the page to A3 portrait at 1:100 by `SetComponentCommand` in the test, off the origin (3000, −1500), and asserts both.
  - The MediaBox is `[0 0 297u 420u]`.
  - The ACI 7 line's single black stroke is at `((3600−3000)/100·u, (300+1500)/100·u)`, computed independently of `pageCamera`, and its colour is `[0, 0, 0]`.
  - Because H differs from A4's, the page set-up's `H` is now exercised too.
- B2-a4 (`PdfPageFormat.a4.landscape`) is RED: `Expected: a numeric value within <0.000005> of <1190.5511811023623> Actual: <595.27559>`. `00:00 +22 -1: Some tests failed.`
- The `_residualOf` comment change is correct: it keeps A4's H, but `_pointBound` and `_widthBound` use only the linear part, which H does not touch.

### Finding 3: closed

The report now records "index not disposed" as observable before 5b and as equivalent after it. That matches B2-nodispose above.

### Finding 4: closed

`_render`'s unused `simpleTrueTypeFonts` parameter is removed. The CID test keeps its own `PdfDocument(simpleTrueTypeFonts: true)`.

### Gates and scope at `8fe438b`

- Render, `CI=true flutter test`: `00:52 +1127 ~1 -7: Some tests failed.`
  - That is 1124 + 3.
  - The 7 deduplicated `[E]` failures are text ladder rungs 1-5 and text lod ladder rungs 1-2 (RenderBackend.canvas), the standing set. No other test failed.
- `CI=true flutter analyze`: `No issues found! (ran in 1.5s)`.
- `dart format --output=none --set-exit-if-changed .`: `format_exit=0`, `Formatted 198 files (0 changed)`.
- `git diff --name-only 72827ed..8fe438b` lists `page_export.dart`, `export_pdf_test.dart` and `pdf_draw_sink_text_test.dart` only.
- `git diff --stat 94653f6..8fe438b -- packages/jet_cad_2d apps packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/invariants` is empty.

### Verdict (5b): **Approved**

Findings 1-4 are closed. The fix is minimal and correct by construction (synchronous body, restore after dispose, in an outer `finally`), and the named mutants are red. The two survivors are equivalent, shown by experiment.

Carry-overs (no action in Task 5):
- (a) Task 6's `exportPagePng` must paint inside `_withExportIndex`, with `toImage` outside the body, as the implementer notes.
- (b) Task 9's T-10 should edit after an export in the pumped shell.
- (c) Task 11 should amend spec D4 and I-3 to name the dispatcher's hooks.
