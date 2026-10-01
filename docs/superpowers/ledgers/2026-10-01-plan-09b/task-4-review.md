# Task 4 review (independent) — 1951d01
Status: in progress
- Diff 359a70a..1951d01: 3 files, all packages/jet_cad_2d_flutter (export, src/symbol_gallery.dart, test/symbol_gallery_test.dart).
- material.dart: first lib import in the package (git grep at 359a70a: none). pubspec/README/specs carry no rule against it; spec D4 (binding) itself names Material + InkWell + Tooltip in the render layer. Accepted.
- Render gate (real): `00:49 +997 ~1 -7`, the 7 = text_ladder 1-5 + text_lod_ladder 1-2 (canvas) only; analyze `No issues found!`; format `Formatted 182 files (0 changed)` fmt=0. App `03:12 +819: All tests passed!`.
- M-09b12 (:106 KeyedSubtree): RED focus test only (Expected false Actual true = canRequestFocus). M-09b23 (:354): RED 8+ tests. highlight (:140): RED. disabled taps (:243): RED (Actual ['chair@1','table@1']). collapse (:123): RED x2. restored diff=0 each
- M-09b12 probe: a temp copy of the test without the canRequestFocus block (scratch file test/zz_rb4_traversal_probe_test.dart, deleted after) still goes RED under the mutant at `traversal step 0` (Expected no matching candidates, Found 1) and passes on the pristine source (+1). So the traversal check is an independent guard; the tap assertion alone is not (as the implementer says).
- HUNT imageFor on every update (:330 `true ||`): SURVIVED `+10: All tests passed!`. restored diff=0 -> finding 1
- HUNT clone after an await gap (:348 `async { await null;`): SURVIVED +10. restored diff=0 -> finding 2
- hunt header count +1 (:118): RED x2. grid 3 columns (:129): RED (Expected <8.0> Actual <161.3>). restored diff=0 each
- hunt tooltip shows id (:230): RED. label two lines (:265): RED (Expected <1> Actual <2>). replace keeps old clone (:369): RED. restored diff=0 each
- Final git status --short: empty (probe file removed).

## Verdict: Needs fixes (test-only)
1. MAJOR test/symbol_gallery_test.dart (code :327-337): "request per key change, not per build" is unguarded; `if (true || ...)` survives. Every gallery rebuild (selectedId, enabled) would re-request, re-clone and setState every cell. Fix: after settle, pump with a new selectedId and enabled:false, assert `h.thumbnails.requests` length unchanged.
2. MINOR test (code :348-360): cloning synchronously in the completion callback (Task 3's contract) is unguarded; an `async { await null;` gap survives. Fix: SymbolThumbnails(maxEntries: 1) with two cells, so the first cell's entry is evicted while pending; assert both cells show a non-null, undisposed image.
3. NOTE: an empty GalleryCategory renders a header with count 0 (the app's search omits empty groups, D3), fine.
Judgments: M-09b12 is guarded twice (canRequestFocus and traversal, probe above); material.dart import accepted (D4 mandates Material/InkWell/Tooltip; no rule against it); the cache-hit/eviction clone race (report open issue 2) is acceptable as a known limit: an LRU hit is most recent, so 64 misses would have to land in the same microtask window; the StateError is caught and the cell is blank, not broken.

## Re-review (4b) — 8a44a5c (parent 637a429)
- Diff: only packages/jet_cad_2d_flutter/test/symbol_gallery_test.dart (+58 -2; Harness/RecordingThumbnails take maxEntries, two new tests).
- Render gate (real): `00:51 +1001 ~1 -7`, all 7 [E] are text_ladder / text_lod_ladder (standing); analyze `No issues found!`; format `Formatted 182 files (0 changed)` fmt=0.
- Mutants (scratchpad/rb4b, restored diff=0 each):
  - imageFor on every update (:330 `true ||`): RED "a rebuild with the same key requests no thumbnail again" (`Expected: an object with length of <4>`, Actual: [ ...])
  - clone after an await gap (:348 `async { await null;`): RED "a cell whose entry is evicted while pending still shows a clone" (`Expected: not null Actual: <null>`)
- Eviction test is real: maxEntries 1, two cells in one build; right after the pump (no runAsync yet, so nothing has completed) it asserts 2 requests and cache length 1, i.e. the first entry was evicted while pending; then the evicted original is debugDisposed true, both cells' images non-null and undisposed, left's image isCloneOf the evicted one, no re-request.
- git status --short: empty.
### Verdict (4b): Approved
