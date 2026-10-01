# Task 4 report — render: the symbol gallery (spec D4, R-1)

Commit: 1951d01 `feat(render): the symbol gallery` (parent 359a70a). Not pushed.

Files:
- packages/jet_cad_2d_flutter/lib/src/symbol_gallery.dart (new): `GallerySymbol{id, label, thumbnailKey, thumbnailDocument}`, `GalleryCategory{name, symbols}`, `kGalleryThumbnailAspect = 4/3`, `SymbolGallery({categories, selectedId, enabled, onSelect, thumbnails, foreground, cellColor})`.
- packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart: `export 'src/symbol_gallery.dart';`.
- packages/jet_cad_2d_flutter/test/symbol_gallery_test.dart (new, 10 tests).

## Gates
Render, full suite (log scratchpad/b4/render.log): `00:55 +997 ~1 -7: Some tests failed.` = 987 + 10 new, 1 skip, 7 failures = the standing ones only (listed every `[E]`: text ladder rungs 1-5, text lod ladder rungs 1-2, RenderBackend.canvas).
`flutter analyze`: `No issues found! (ran in 1.4s)`; `dart format --output=none --set-exit-if-changed .`: `Formatted 182 files (0 changed)`, fmt=0.
App (re-run because the barrel export grew): `02:45 +819: All tests passed!`, `No issues found! (ran in 2.7s)`, `Formatted 145 files (0 changed)`, fmt=0. App source unchanged.
Engine: untouched by the diff, not re-run. `git diff --stat 359a70a HEAD`: 3 files, all in packages/jet_cad_2d_flutter (invariant tests untouched). analysis_options.yaml not staged (explicit paths).

## Design
- `ExcludeFocus` › `Material(transparent)` › `CustomScrollView`: per category a `SliverToBoxAdapter` header (`symbol-group-<name>`: chevron, name, count; InkWell tap toggles the collapsed set in state) and, unless collapsed, a 2-column `SliverGrid` of cells (`symbol-cell-<id>`).
- Cell: `Semantics(selected, enabled, button)` › `Tooltip(full label)` › `Opacity(enabled ? 1 : 0.38)` › `Material(color, shape)` › `InkWell(onTap: enabled ? ... : null)` › thumbnail + one-line ellipsis label.
- **Highlight, observable without a golden (decision):** the cell's `Semantics(selected: true)` (read via `getSemanticsData().flagsCollection.isSelected`) AND the cell `Material`'s colour `primaryContainer` (else `cellColor`) with a `primary` 2 px border. Both come from one `selected` value computed at the grid builder.
- Thumbnail: a private stateful widget given `(symbol, logicalSize, dpr, foreground, thumbnails)`; logical size from a `LayoutBuilder`, the largest 4:3 box floored to whole logical pixels (stable cache key); DPR from `MediaQuery.devicePixelRatioOf`. It requests in initState and again in didUpdateWidget when the thumbnails object, key, size, DPR or foreground change; it clones in the future's completion callback (per Task 3's contract), drops completions of superseded requests, disposes the previous clone on replacement and its clone on dispose. Errors: empty `RawImage`, label stays, nothing thrown.
- Headers still collapse while `enabled == false`.

## Tests (10)
fixtures not degenerate (basePoint off origin, mirrored rotated instance far from origin); headers + two-column grid + count + ellipsis + tooltip; collapse/expand; tap -> onSelect(id) with `key@version` ids; disabled ignores taps, greyed, headers still collapse; highlight follows selectedId only (incl. same key at two versions); no focus (tap keeps the outside node's primary focus, the cell's InkWell node has `canRequestFocus == false` and refuses `requestFocus`, `nextFocus` traversal never lands in the gallery); a cell shows a clone, unmounting disposes the clone, the cache image stays undisposed and `toByteData` works; an image change disposes the previous clone; a throwing builder shows label + empty image + no exception. Image waits under `tester.runAsync` (thumbnails subclass records futures), then a pump.

## Mutants
cp to scratchpad/b4/backup.dart, one sed, `CI=true flutter test test/symbol_gallery_test.dart` in the foreground, cp back, `restored diff=0` every time. Lines at 1951d01, lib/src/symbol_gallery.dart.

| Id | Line | Mutation | Red test(s) | Real output |
|---|---|---|---|---|
| M-09b12 | :106 | `ExcludeFocus(` -> `KeyedSubtree(` | a cell and a header never take focus | `Expected: false` / `Actual: <true>` (`canRequestFocus`), `+9 -1` |
| M-09b23 | :354 | `clone = image.clone()` -> `clone = image` | own clone test (`Expected: false` / `Actual: <true>`, identity), plus 8 others fail at teardown on the double dispose (`Failed assertion ... Image.dispose` from `SymbolThumbnails.dispose`) | `+1 -9` |
| highlight ignores selectedId | :140 | `selectedId == symbol.id` -> `selectedId != null` | only the cell whose id is selectedId is highlighted | `Expected: false` / `Actual: <true>`, `+9 -1` |
| disabled tap calls onSelect | :243 | `onTap: () => onSelect(symbol.id)` | disabled cells ... ignore taps | `Expected: empty` / `Actual: ['chair@1', 'table@1']` |
| collapse (chosen) | :123 | `if (!_collapsed.contains(...))` -> `if (true)` | collapse test, disabled test | `Expected: no matching candidates` / `Actual: _KeyWidgetFinder:<Found 1 widget with key [<'symbol-cell-chair@1'>]`, `+8 -2` |
| extra: replace keeps old clone | :369 | `_image?.dispose()` -> `_image` | an image change disposes its previous clone | `Expected: true` / `Actual: <false>` |
| extra: dispose keeps clone | :375 | `_image?.dispose()` -> `_image` | own clone test ("the cell disposed its clone") | `Expected: true` / `Actual: <false>` |

## Open issues / notes
- Plan text "a focused FocusNode elsewhere keeps focus after a tap" alone does not catch M-09b12: InkWell never requests focus on tap, so with ExcludeFocus removed the outside node keeps focus anyway. The test adds `canRequestFocus`/`requestFocus` and traversal checks; the canRequestFocus assertion is what goes red. Reviewers should not rely on the tap assertion for M-09b12.
- Task 3 cache contract gap: a cache *hit* on an already completed future delivers the `then` callback a microtask later; if that entry is evicted in between (another request in the same synchronous build with a tiny `maxEntries`), the image is already disposed and `clone()` throws StateError. The cell catches that StateError and shows an empty cell (no retry). With 64 entries and 27 symbols it does not arise; not tested.
- Package lib now imports `package:flutter/material.dart` for the first time (Material, InkWell, Tooltip, Icons), as spec D4 asks. Tooltip needs an Overlay ancestor (MaterialApp in the app and tests).
- Thumbnail size is derived from layout (about 101x75 logical in a 240 px panel), not a constant; the app (Task 8) need pass nothing for it.

## Task 4b (review findings 1, 2; test-only)

Commit: 8a44a5c `test(render): the gallery requests once per key and clones on completion (4b)` (parent 637a429). Only packages/jet_cad_2d_flutter/test/symbol_gallery_test.dart changed (`RecordingThumbnails` and `Harness` take `maxEntries`; two tests added). No lib change.

Tests added:
- "a rebuild with the same key requests no thumbnail again": after the images settle (4 requests), pump with `selectedId: 'sofa@1'`, then also `enabled: false`; the request count stays 4, every cell shows an undisposed image.
- "a cell whose entry is evicted while pending still shows a clone": `maxEntries: 1`, two cells in one build (2 requests, cache length 1, the first evicted while pending); after settling, the evicted original is `debugDisposed`, both cells show a non-null, undisposed image, the left one a clone of the evicted original, and nothing was re-requested.

Gate: render `01:01 +1001 ~1 -7: Some tests failed.` = 999 (after 3b) + 2 new, 1 skip, 7 standing (text ladder rungs 1-5, text lod ladder rungs 1-2, every `[E]` listed); `No issues found! (ran in 1.9s)`; `Formatted 182 files (0 changed)`, fmt=0. App and engine untouched (test-only render change), not re-run.

Mutants (lib/src/symbol_gallery.dart at 8a44a5c; cp backup in scratchpad/b4b, `restored diff=0` each):

| Mutation | Line | Red test | Real output |
|---|---|---|---|
| imageFor on every widget update (`if (true \|\| ...`) | :330 | a rebuild with the same key requests no thumbnail again | `Expected: an object with length of <4>` / `Actual: [`, `+11 -1` |
| clone taken after an await gap (`then((image) async { await null; ...`) | :348 | a cell whose entry is evicted while pending still shows a clone | `Expected: not null` / `Actual: <null>`, `+11 -1` |
