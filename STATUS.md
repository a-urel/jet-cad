# jet-cad — project status

**Last updated:** 2026-08-18
**Verified against:** `main` @ `a7008a6`, `plan-3c` worktree @ `c381e24` + uncommitted Task 9 work.
Every count below was produced by running the suite, not by reading a report.

---

## TL;DR — where you left off

Plan 3c (**text**) is 9 tasks into 15, running on the `plan-3c` worktree.
Tasks 0–8 are committed and reviewed. **Task 9 is half-done and uncommitted, and
the widget suite is currently RED for one mechanical reason.**

| Suite | State |
|---|---|
| `packages/jet_cad_2d` — engine | **716 tests, all pass** |
| `packages/jet_cad_2d_flutter` — widgets | **RED** — `test/draw_sink_test.dart` fails to compile |

**The exact break:** Task 9 added a required `measurer` parameter to
`CanvasDrawSink`. Four test files were updated; one was missed.

```
test/draw_sink_test.dart:183:28: Error: Required named parameter 'measurer' must be provided.
      sink = CanvasDrawSink(canvas: canvas, pixelsPerPaperMm: 4.0);
```

Fix that one call site to get back to green, then finish Task 9 (see
[Resume here](#resume-here)).

---

## What this project is

A CAD workspace holding **two independent product lines that share a name and
nothing else**.

### `jet_cad_2d` — the live line (pure Dart 2D CAD)

A pure-Dart 2D CAD engine and document model. **No OCCT, no FFI, no native
build, no Flutter dependency** — it runs anywhere Dart runs. Rendering and
widgets live in the separate `jet_cad_2d_flutter` package so the engine stays
free of `dart:ui`. This is where all current work happens.

### `jet_cad` — the dormant line (OCCT 3D)

A Flutter CAD package backed by Open CASCADE Technology over FFI, with a macOS
viewport. Plans 1 and 2 for it shipped; **Plan 3 (the interactive OCCT viewport)
was written as a kickoff but never executed** — the project pivoted to the
pure-Dart 2D line instead. Last commit touching it: `139a677`, 2026-07-13.
Nothing here is being worked on. Do not assume its docs describe current
direction.

---

## Repo layout

```
packages/
  jet_cad/              # DORMANT — OCCT 3D over FFI, macOS viewport
  jet_cad_2d/           # ACTIVE — pure-Dart 2D engine (45 lib files)
  jet_cad_2d_flutter/   # ACTIVE — Flutter render layer (8 lib files)
apps/
  dev_harness/          # DORMANT — manual harness for the jet_cad viewport
  dev_harness_2d/       # ACTIVE — measurement harness; exists so R2/R4a/R4b
                        #   run on a real device in profile mode
docs/superpowers/
  specs/                # design specs — BINDING AUTHORITY
  plans/                # implementation plans — what the implementer follows
  notes/                # measurement + mutation results of record
.superpowers/sdd/       # git-ignored per-task ledger, briefs, reports
```

`jet_cad_2d` is Dart-only (`meta`, `vector_math`; dev: `test`, `vm_service`).
`jet_cad_2d_flutter` depends on Flutter + `jet_cad_2d` by path. Both are
`resolution: workspace` members of the root pubspec.

---

## Branch and worktree map

| Location | Branch | State |
|---|---|---|
| `/Users/ahmeturel/Projects/oss/jet-cad` | `main` | clean, `a7008a6`, Plans 1/2/3a/3b merged |
| `.claude/worktrees/plan-3c` | `plan-3c` | 13 commits ahead, **8 files uncommitted** |

`main` is ahead of `origin/main`. **Nothing has been pushed.** Do not push
unless explicitly asked.

---

## Completed work

### Plan 1 — the 2D core (merged)

Identity and handles, the scene tree, columnar geometry and entity stores,
components, commands with undo, style tables and resolution, the packed R-tree
spatial index with a dirty overlay, snapping, and a deterministic versioned JSON
document format.

### Plan 2 — the backlog (merged)

Query performance and the zero-allocation invariant on the pick and snap paths.
Its `query_allocation_test.dart` harness is now a standing gate that every later
plan must not break.

> **Known carried failure:** `dart run benchmark/query_throughput.dart` has one
> failing row, `snap at dirty threshold`, carried forward from Plan 2. It is
> expected. Do not treat it as a new regression.

### Plan 3a — the render foundation (merged)

The first working render path: camera, coordinate rebasing, the `DrawSink`
paint seam, `DraftPainter`, the reference walk, and the differential oracle that
checks the painter against an independent implementation.

### Plan 3b — batching and dashes (merged)

**Batching was measured and refuted, not shipped.** The spike found the most
call-collapsed mode was **2.7× slower to rasterise** than one
`save`/`transform`/`restore` triple per leaf, and the plan's own pre-declared
stop clause fired. What shipped instead:

- The cull floor and the style memo were **deleted** — both were measured losses.
- Every line-like leaf is carried into screen space unconditionally, replacing
  the old anisotropy-gated bypass.
- An engine-side **dasher**: screen space for polylines, arc-window-aware for
  circles and arcs, with a human-reviewed collapse floor (`kDashCollapsePx`).

The profiling task also answered the standing question about an unexplained
179 ms: it is **leaf-count-bound GPU vertex work**, not fragment fill and not
draw-call dispatch. That finding is what makes a picture cache (Plan 3e)
worth building.

> **Every `flutter drive` number in the 3b results note is contaminated:**
> macOS Low Power Mode was on system-wide for the whole session and could not be
> turned off. CPU-only paths are unaffected; build and raster columns at 500k
> entities are elevated 4–12×. **Any future `flutter drive` note must state
> whether Low Power Mode was on.**

---

## In flight: Plan 3c — text

- **Spec (binding):** [docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md](docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md)
- **Plan:** [docs/superpowers/plans/2026-08-17-jet-cad-2d-plan-3c-text.md](docs/superpowers/plans/2026-08-17-jet-cad-2d-plan-3c-text.md)
- **Ledger (the only progress record — read it):** `.claude/worktrees/plan-3c/.superpowers/sdd/2026-08-17-jet-cad-2d-plan-3c-text/progress.md`

**Goal:** store, measure, hit-test and draw single-line text so the product's
real payload — table numbers and room labels — renders, and measure what it
costs.

**The central design idea:** every paragraph is laid out **once at a nominal em
size** (`kNominalTextPixels = 100.0`) and every text attribute — height,
rotation, width factor, oblique angle, justification — becomes a **transform**.
So the paragraph cache key carries no height, angle or width factor. It is
`(string, textStyle handle, ResolvedStyle.argb)` — argb is in the key because
`ui.Paragraph` bakes its colour and `drawParagraph` takes no `Paint`.

`kCapHeightRatio = 0.7`: DXF height is cap height, so the matrix scale is
`effectiveHeight / metrics.capHeight`.

**Out of scope for 3c:** MTEXT, DXF 72=3/72=5 layout, text LOD, fills, picture cache.

### Task board

| # | Task | State |
|---|---|---|
| 0 | Text columns on the store and the record | ✅ complete, review clean |
| 1 | Codec, schema 3 → 4, defensive scalar read | ✅ complete, review clean |
| 2 | `TextMetrics`, measurer seam, metric model | ✅ complete (Ruling 8 carried to T6, paid) |
| 3 | `text_geometry.dart` — one resolution point | ✅ complete, fix round 1/5 |
| 4 | `entityBounds` and all four call sites | ✅ complete, fix round 1/5 |
| 5 | `SetEntityTextCommand` | ✅ complete (landed with T4 per Ruling 11) |
| 6 | Text picks as `HitKind.fill` | ✅ complete, approved |
| 7 | The corpus grows two text sources | ✅ complete, fix round 1/5 |
| 8 | The sink learns one text op | ✅ complete, approved |
| 9 | `FlutterTextMeasurer` + paragraph cache | 🔴 **IN FLIGHT — uncommitted, suite red** |
| 10 | The painter draws text | ⬜ not started |
| 11 | Goldens — attribute ladder and mirror | ⬜ not started |
| 12 | Rigs, counters, the number the gate depends on | ⬜ not started |
| 13 | Mutation testing | ⬜ not started |
| 14 | Exit gate and the results note | ⬜ not started |

Test count grew 667 → 716 engine across Tasks 0–8.

---

## Resume here

### 1. Unbreak the suite (one line)

`packages/jet_cad_2d_flutter/test/draw_sink_test.dart:183` still constructs
`CanvasDrawSink` without the now-required `measurer`. Every other call site was
updated. Fix it, then `flutter test` should go green again.

### 2. Finish Task 9

Uncommitted work already on disk in the worktree:

```
?? packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart   (208 lines, new)
 M packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart        (+27/-4)
 M packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart            (+15/-1)
 M packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart          (export)
 M  4 test files updated for the new required parameter
```

Task 9's brief exists at `.superpowers/sdd/2026-08-17-jet-cad-2d-plan-3c-text/task-9-brief.md`;
**there is no task-9-report.md**, which is how you can tell the task never closed.

Still owed by Task 9 (from the plan, §1253):

- `packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart` — **does not exist yet**
- `FlutterTextMeasurer` must expose `paragraphFor(...)`, `layoutCount`,
  `evictionCount`, `liveParagraphCount`, `clear()`, and `const int kParagraphCacheLimit = 512`
- Three tests the plan names explicitly:
  - the same string in two colours is **two** cache entries, not one
  - a repeat `measure()` lays out nothing **and returns an identical object**
    (a fresh object per call breaks `query_allocation_test`)
  - eviction **disposes** the paragraph
- ⚠️ `Paragraph.debugDisposed` must be confirmed against this Flutter version
  before the eviction test relies on it (ledger, per-task scan).

### 3. Then Tasks 10–14

Task 10 (painter draws text) → 11 (goldens) → 12 (rigs and counters) → 13
(mutation log) → 14 (exit gate + results note, then
`superpowers:finishing-a-development-branch`).

---

## Rulings that still bind the remaining tasks

The ledger carries 20 numbered rulings. These are the ones that constrain work
you have not done yet:

**Ruling 4 — the cache limit is not a tuning knob.** `kParagraphCacheLimit` is
owned by Task 9 and may be raised **once**, in Task 12, and only with the
measured distinct-visible-key count recorded beside it. Lowering
`attributedInstanceFraction` is equally acceptable. **Relaxing the
zero-new-layouts gate row is not.** Otherwise the gate passes because the corpus
was thinned rather than because the cache works.

**Ruling 20 — Task 10 owes a measurement.** The spec wanted a second reusable
`Float64List(16)` in `CanvasDrawSink` to compose `residual ∘ local` without a
per-text-entity allocation. The plan dropped it and pushes an already-composed
transform through the existing `beginResidual`, on the grounds that
`draft_painter.dart:401-403` already does a per-leaf `.multiply()` for circles
and arcs. **Task 10 must measure per-text-leaf allocation on the paint path and
record the number.** If it exceeds the per-leaf norm circles and arcs already
establish, Task 10 reintroduces the spec's second buffer.

**Ruling 10 — `boxOfLeaf` returns null after an edit, correctly.** Dirtying a
leaf removes it from the packed R-tree and parks it in the overlay. Any test
reading a box after an edit must use the codebase idiom:
`index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot)`.

**Ruling 12 — never `tables.textStyles[...]!`.** `JsonCodec._loadTables` clears
the seeded defaults and `TableSection.remove` is public, so a document missing
handle 5 crashes on plain `doc.extents`. Use
`DraftDocument.textStyleOf(Handle)`, which falls back to a `const
TextStyleRecord`.

**Ruling 17 — the corpus must hold exactly 20 distinct labels.**
`expect(labels.length, 20)`, not `lessThanOrEqualTo(20)`. The distribution is
the exact property Task 12's distinct-key measurement is taken against; a
degenerate assertion collapsing it to one label would silently void the gate.

---

## Plan 3c exit gate (Task 14)

### Checks

| Check | Command |
|---|---|
| engine suite | `cd packages/jet_cad_2d && dart test` |
| engine analyze/format | `dart analyze && dart format --output=none --set-exit-if-changed .` |
| widget suite | `cd packages/jet_cad_2d_flutter && flutter test` |
| goldens | `flutter test --tags golden` — all pass, **no existing PNG regenerated** |
| widget analyze/format | `flutter analyze && dart format --output=none --set-exit-if-changed .` |
| harness analyze | `cd apps/dev_harness_2d && flutter analyze` |
| allocation harness | `dart test test/invariants/query_allocation_test.dart` — zero allocation **with text in the corpus** |
| query throughput | `dart run benchmark/query_throughput.dart` — `snap at dirty threshold` is the known carried failure |
| rigs | `flutter test --tags rig --run-skipped`, then `flutter drive --profile -d macos` |

### Failable criteria

| Criterion | Threshold |
|---|---|
| repeat frame at the working-set camera | **zero** new paragraph layouts |
| evictions per repeat frame, working-set camera | **zero** |
| peak live paragraphs | ≤ the declared limit |
| `skippedTextCount` on `textRigCorpus` | **0** |
| differential and non-vacuity, text on | pass |
| reference-query differential, text picking | pass |
| overlay-equals-rebuild for an edited text | pass |
| mutation log | every mutant killed or argued equivalent |

**If a failable row misses: record it and stop.** Plan 3b's Task 4 stop clause
is the precedent — a row that fires is a result. Write the number, say what it
implies for 3d and 3e, and stop rather than tuning until it complies.

The results note must state **whether macOS Low Power Mode was on**.

---

## Roadmap after 3c

### Plan 3d — fills

**It inherits no mechanism from 3b.** The 3b design's "flush contract" — a fill
flushing open draw buckets — has nothing to attach to, because batching was
reverted. 3d gets the ordinary one-call-per-primitive `CanvasDrawSink`.

**The open problem:** draw order is ascending handle value, so a region's fill
must carry a **lower** handle than its boundary or it paints over its own
outline. But handles are monotonic by creation and the natural authoring order
is *draw the boundary, then hatch it* — which produces exactly the failing case.
3d must choose and state one of:

- give the fill an explicit draw-order key the painter honours ahead of handle order, or
- require the region command to create boundary and fill in one transaction with the ordering reserved.

### Plan 3e — the definition/tile picture cache

The prize is real: the dominant cost is leaf-count-bound GPU vertex work, and
dashing makes that story **stronger** — one dashed polyline becomes dozens of
drawn spans per leaf without moving the painter's op count.

Four traps recorded in
[docs/superpowers/notes/2026-08-17-carry-forward-additions.md](docs/superpowers/notes/2026-08-17-carry-forward-additions.md):

1. **`documentRevision` does not exist yet** and nothing says what bumps it. If
   an ordinary entity edit bumps it, every definition picture is discarded every
   command — the exact pathology the two-channel split exists to avoid, and the
   planned gate row would not catch it.
2. **Tile invalidation has a hole for edits inside a definition.** A touched
   handle owned by a definition appears in no tile's handle list and its new box
   is in definition-local space. Tiles must record which definitions they baked
   and map touched handles through placements.
3. **A cached picture is no longer scale-invariant now that dashes exist.** Dash
   phase and the collapse floor are both functions of screen-space scale, so
   zoom far enough and baked-dashed entities need to render solid. That is a new
   invalidation axis with no name yet.
4. **`InstanceNode` carries only 2 of `StyleContext`'s 6 fields.**
   `linetype`, `linetypeScale`, `lineweight`, `transparency` are missing, and
   DXF's INSERT carries all four. `StyleContext` is the picture cache key, so
   this model decision belongs **before** the cache, not after.

**Do not design 3e against a fixed op-count ceiling.** The web whole-drawing
abort is reproducible but its trigger is unknown — a memory- or
session-dependent CanvasKit failure explains it with no code at fault. What 3e
is owed first is a back-to-back, same-session re-run.

---

## Commands

```sh
# engine (pure Dart)
cd packages/jet_cad_2d
dart test
dart test test/invariants/query_allocation_test.dart
dart run benchmark/query_throughput.dart
dart analyze && dart format --output=none --set-exit-if-changed .

# render layer (Flutter)
cd packages/jet_cad_2d_flutter
flutter test
flutter test --tags golden
flutter test --tags rig --run-skipped
flutter analyze && dart format --output=none --set-exit-if-changed .

# real-device frame timings
cd apps/dev_harness_2d
flutter drive --profile -d macos
```

---

## Traps

- **`flutter pub get` rewrites three `analysis_options.yaml` files** in this
  workspace. They must **never** be committed. Check `git status` after any pub
  operation.
- **The degenerate fixture is the dominant defect class here.** Plan 3c alone
  shipped it three times: fixtures all at the identity transform, all at the
  origin, all with default attributes, all one distinct string. Every one was
  caught by mutation testing, none by reading. A test that cannot be made red by
  a named mutation is not evidence.
- **`query_allocation_test` is a standing gate, not a Plan 2 artifact.** A
  `measure()` that allocates on a cache *hit* breaks it. This already bit once:
  Task 2's record-tuple memo allocated 41.5 objects per pick-path call, found in
  Task 6.
- **Reviewers verify claims independently.** Synthesized test output invalidates
  a task.
- **The `plan-3c` ledger is the only progress record** for that plan — TodoWrite
  was unavailable in the session that ran it. Keep appending to it.

---

## Housekeeping done 2026-08-18

Removed as dead weight:

- `.superpowers/sdd/` scratch for **finished** plans — Plan 1-core, Plan 3b, and
  the loose Plan 2 reports and `review-*.diff` files (~2.7 MB, git-ignored,
  **not recoverable**). Their conclusions live in `docs/superpowers/notes/`.
  The **`plan-3c` ledger was deliberately kept** — it is live state.
- Speckit scaffolding: `.specify/` and the nine `.claude/skills/speckit-*/`
  skills. Unreferenced anywhere in the project; the repo uses the superpowers
  SDD workflow instead. Tracked by git, so recoverable via
  `git checkout a7008a6 -- .specify .claude/skills`.
- `.superpowers/plan-3-kickoff-prompt.md` — the kickoff for the abandoned OCCT
  Plan 3 viewport, superseded by the 2D line.
- `CLAUDE.md` rewritten from its speckit stub into real project instructions.

**Known cost:** six links in three tracked docs
(`2026-08-11-plan-3b-results.md`, `2026-08-10-plan-3a-ledger.md`,
`2026-07-12-03-interactive-viewport.md`) point into the deleted
`.superpowers/sdd/` reports and are now dead. The notes' own prose is
self-contained; only the citations broke.
