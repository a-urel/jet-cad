# Spec 04 (page, grid, rulers) — review of revision 1

**Date:** 2026-09-22. **Spec:** `docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md`
at `15d2fe0`. **Reviewers:** Codex CLI (`gpt-5.5`, read-only sandbox),
an Opus subagent (read-only), and Copilot CLI — which hit its usage limit
after reading the spec and produced no finding. Two independent reviews,
not three. Every finding below was re-verified against the tree at
`4895fc8` before its ruling; rulings are what revision 2 applies.

## Blocking

| # | finding | who | verified | ruling |
|---|---|---|---|---|
| B1 | A `SetComponentCommand` on the root handle reports `touched: {root}`; the root is a tree node; `SpatialIndex._reconcile` sets `structural` for any touched tree node and calls `rebuildAll()`. So every page edit is a full R-tree rebuild and Invariant 1 / exit criterion 7 ("zero index rebuilds") is false as written. | both | `commands.dart:424`, `tree.dart:60-62`, `spatial_index.dart:2646-2674`; moreover a handle that resolves to *nothing* also reaches `rebuildAll()` through `_reconcileEntity`'s `last == null` branch, so moving the component off the root would not help | **Engine change, new D13:** `CommandApplied`/`Undone`/`Redone` gain `final Capability capability` (named, default `Capability.geometry` so every existing `const` construction site compiles). `SpatialIndex._onChange` and `TileCache`'s change handler return before reconciling when `capability == Capability.components`: components are data the index never reads. A `CompoundCommand`'s summary capability is exactly right here — components-only compounds skip, mixed ones reconcile. Mutant M-04r: remove the skip; `rebuildCount` grows on a page edit. Invariant 1 restated as holding *because of* D13. |
| B2 | The differential check's oracle calls the same `GridScale.pick` as the painter, so M-04c cannot make it go red. | both | property of the specced test | The test carries the ladder as a **literal table** and derives the expected step from it with its own 64 px rule; the oracle shares nothing with `pick`. |
| B3 | "Clipped to the sheet rect" never states the iteration range; at the app's `kMaxScale = 100` px/mm an A4 sheet is 1.485e6 px wide, so iterating the sheet at a 1 mm major is ~14 850 lines per axis against a bound of viewport/64 + 2. | Opus | `startup_plan.dart:23`, `main.dart:42` | The iteration range is `visibleWorld ∩ sheetWorldRect`; the canvas clip is belt-and-braces. Stated in D8 with the kMaxScale example. |

## Should-fix

| # | finding | who | ruling |
|---|---|---|---|
| S1 | D7's "take the top step" fallback is labelled zoom-in but is zoom-out, and is unbounded (top step at sub-pixel spacing). | Opus | No majors at all when the top step is under 64 px; wording fixed. |
| S2 | M-04c's "line count at scale 1e−9" cannot go red: the sheet is 1.5e−5 px wide and both branches draw zero lines. | Opus | The bounded-count tests at 1e−9 and 1e6 stay as Invariant 2's witnesses (expected: zero and bounded respectively); M-04c is killed by `grid_scale_test` and the differential check only. |
| S3 | Snap step follows the zoom and `gridStepMm` is only a ladder floor, so "250 mm" does not snap at 250 mm and the same drag snaps differently at two zooms. | Opus | `snapToGrid` uses `gridStepMm` **exactly** when non-null; otherwise the zoom-adaptive step, stated as such. `pick` keeps the floor semantics for drawing. |
| S4 | "A snapped point lies on a drawn line" is false outside the sheet, where 03 will drag. | Opus | Invariant 3 and its test qualified to points inside the sheet; snap works everywhere, anchored at the sheet corner, and outside the sheet there is simply no line to coincide with. |
| S5 | A `Float32List` "sized to the bound" hands `drawRawPoints` a partly filled buffer; `PointMode.lines` draws the tail through (0, 0). | Opus | The list handed to `dart:ui` is exactly `count · 4` long: `Float32List.sublistView` of a reused buffer. Test asserts the recorded list's length. |
| S6 | 50 random cameras, no seed. | Opus | Seed `0x5EED0004`, named in the spec. |
| S7 | Seventeen mutants named, no exit criterion requiring them killed or declared equivalent. | Opus | Criterion added: `docs/superpowers/notes/plan-04-mutation-log.md`, every named mutant fired, killed or declared equivalent with a reason. |
| S8 | Criterion 14 drops 02's baseline exception (five `text_ladder_golden_test.dart` failures) and the `CI=true` prefix. | Opus | Restated verbatim from 02's criterion 12. |
| S9 | `RulerFrame` sits outside `CameraGestureDetector`, but the `LayoutBuilder` that fits the camera reads the outer size; fit and rulers would disagree with the drawn area. | both | The `LayoutBuilder` moves inside `RulerFrame`'s child slot; fit and both rulers use the child's size; the shell test compares against `DraftCanvas`'s size, as Plan 01's does. |
| S10 | Whether the top bar spans the full width or starts after the corner box is unstated; the wrong choice offsets every tick by 24 px and the isolated painter test cannot see it. | Opus | Each bar is co-extensive with the child on its own axis; the corner box occupies the remaining 24 × 24; a frame-level widget test ties a major tick's screen x to the same world point's x in the child. |
| S11 | The engine-side reason for `PageComponent` is undercut by putting the pure arithmetic in the Flutter package. | Opus | `sheetWorldRect`, `zoomOf(double scale, …)`, `pageWorldOf`, `GridScale`, `formatLength`, `snapToGrid` move to the engine (`document/page_geometry.dart`, `geometry/grid_scale.dart`); only `fitToPage` (needs `Size` and `ViewportTransform`), the painters and the widget stay in Flutter. |
| S12 | `PageNotifier` never seeds its initial value; the startup page is invisible until the first change. `OutlineCache` seeds in its constructor. | Codex | Seeds from `components.get<PageComponent>(root)` in the constructor; a test reads the value before any event. |
| S13 | The panel cannot edit `originX/Y`, custom dims or `gridStepMm`, yet the exit gate says "every field". | Codex | Narrowed: the 04 panel owns preset, orientation, scale, unit, the three toggles and the paper colour. Origin, custom dimensions and `gridStepMm` are data the engine tests exercise and 12's panel exposes. Criterion 13 restated. |
| S14 | The codec class is `DraftDocumentCodec`, and `decodeString` forwards to `decode` without the hook. | Codex | Both named; `registerComponents` on both. |
| S15 | M-04d as a mutation of the test's own call proves nothing about the hook. | Codex | M-04d is a **production** mutant: call `registerComponents` *after* `components.loadJson`. The typed round-trip test goes red. |

## Nits, all applied

Line citations corrected (`register` 67, `registerBuiltIns` 80, `toJson`
130, `loadJson` 171, preserve-unknown 181-186, `pixelsPerPaperMm` 117); the
top chrome slot is not empty (it holds `status-text`); the label-cache
reason replaced by the bounded count; `PageComponent.register` is
register-once (a second call replaces the store and drops the live page);
`DocumentPurged` named correctly; `scaleDenominator` is a double and the
panel accepts any positive number; the intro no longer says the rulers
"honour" `header.units`.

## What the two reviewers disagreed on

Nothing of substance. Codex's M-04d and codec-name findings and Opus's
grid-range and buffer-length findings were each unique to one reviewer,
which is the argument for running both.
