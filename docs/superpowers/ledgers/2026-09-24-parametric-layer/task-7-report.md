# Task 7 report: the Box tool, key B, and the parametric system in the shell

## Implementation

- **`apps/floor_planner/lib/parametric/box_tool.dart` (new).** `BoxTool
  extends RectangleTool`, `name => 'Box'`. `accept` places the first corner
  like `RectangleTool`, then on the second click (skipping a degenerate
  rectangle via `isDegenerateRectangle`, imported from
  `rectangle_tool.dart`) commits a `CompoundCommand` of
  `AddNodeCommand(GroupNode(...))` at the lower-left corner (a pure
  translation, world-axis aligned) plus `SetComponentCommand<BoxParams>`,
  through `commit(ctx, build, needs: {structure, components, geometry})`.
  Implemented verbatim from the brief's Step 3 listing; it compiled and
  passed without changes. `points`, `clearShape` and `commit` are public
  (unprefixed) members of `PlacementTool`, so they are visible to a
  subclass in another package regardless of the `@protected`-style
  convention; `RectangleTool` and `isDegenerateRectangle` are exported from
  `jet_cad_2d_flutter.dart` via `export 'src/draw/rectangle_tool.dart'`. No
  export needed widening.
- **`apps/floor_planner/lib/main.dart`:**
  - imports `parametric/box.dart` and `parametric/box_tool.dart` (sorted
    between `page_panel.dart` and `planner_view.dart`);
  - fields `late final ParametricSystem _parametric;` and
    `final BoxTool _box = BoxTool();`;
  - new `initState` calling `super.initState()` then
    `_parametric = installBoxes(_document);` as the first read of
    `_document` (a `late final` field), so its own lazy initializer —
    `widget.document ?? startupPlan(_measurer)` — runs there, before any
    other lazy field (`_page`, `_index`, …) touches it;
  - `dispose` now calls `_parametric.dispose();` immediately before
    `_index.dispose();`;
  - a `PaletteEntry(keyName: 'tool-box', label: 'Box', shortcut: 'B',
    logicalKey: LogicalKeyboardKey.keyB, tool: _box, drawing: true)` added
    right after the Rectangle entry, so B sits next to R in the palette and
    in the generated shortcut bindings.
- **`apps/floor_planner/lib/shortcut_guard.dart`:** added
  `LogicalKeyboardKey.keyB` to `kShellLetterKeys`, right after `keyR`.
- **`apps/floor_planner/test/support/box_rig.dart` (new).** `pumpDraw`,
  `globalOf`, `status`, `press`, `bytes` copied verbatim from
  `planner_draw_test.dart` (never imported). Added:
  - `boxDoc(FlutterTextMeasurer m)`: the 1:20 page at `(7000, 3000)`,
    `snapToGrid: false`, no entities, `clearHistory()` — `drawDoc` less its
    seed line;
  - `boxKids(DraftDocument, Handle)`: `doc.leavesByOwner()[box]`'s slots,
    mapped to handles — the survey's own "children of a live object" view
    (spec 06 D3), never `GroupNode.children`, which the parametric
    mechanism does not populate for a generated leaf;
  - `boxes(DraftDocument)`: `doc.components.withComponent<BoxParams>()`,
    already ascending (`ComponentStore.handles` sorts).
- **`apps/floor_planner/test/planner_box_test.dart` (new).** BX1–BX6, from
  the brief, with two additions: `_worldOf`/`_childMidpoint`/
  `_strictlyInside` helpers, and BX4's midpoint loop (below).
- **`apps/floor_planner/test/startup_plan_test.dart`:** added SP5 exactly
  as specified, `startupPlan(measurer)` matching the file's own `setUp`
  variable name (no adaptation needed — the brief's placeholder argument
  already matched).

## Deviations from the brief

1. **BX4's geometry matched the brief's stated counts on the first run —
   no hand re-derivation was needed.** Both boxes came back with 4
   children each, as the brief predicted, so the comment in the test
   states the geometric reasoning (which two edges each box loses a
   segment from) rather than a hand override.
2. **BX4's midpoint check, which the brief asked for but did not spell
   out, is implemented as:** for every generated child of box A, its
   world-space segment midpoint (from the local line payload, mapped
   through `doc.tree.accumulatedTransform(box)`, which for this tool is a
   pure translation) must not sit strictly inside box B's own
   `(origin, origin + (width, height))` rectangle, and symmetrically for
   B's children against A. This is a genuine mutation-catcher: it fails if
   `BoxType.generate`'s clip direction or the interval math is flipped
   even in a case where the *count* of surviving pieces happens to still
   be 4 (see Self-review below).
3. **BX5's meta+Z reached the shell in the widget-test binding** —
   `tester.sendKeyDownEvent(LogicalKeyboardKey.meta)` /
   `press(tester, LogicalKeyboardKey.keyZ)` /
   `tester.sendKeyUpEvent(LogicalKeyboardKey.meta)` triggered the shell's
   `SingleActivator(keyZ, meta: true)` binding correctly, so the brief's
   named fallback (`doc.commands.undo()`) was not needed.
4. **No existing test's palette-entry or shortcut-letter *count* needed
   updating.** `A1`/`A2` each iterate a hand-written literal list of
   `(key, name)` pairs that does not include Box, and neither test counts
   the palette's total length or asserts `kShellLetterKeys.length`; `A9`
   does not touch counts either. All three still pass unmodified.
5. **`initState` did not exist before this task** (no prior task had
   needed one); it was added fresh rather than "extended", matching the
   brief's "add or extend" wording.

## RED / GREEN

**RED**, captured honestly by temporarily emptying the committed
`box_tool.dart` (backed up via `git show HEAD:...`, restored the same way
afterward; `git diff --stat` was empty and `git status --short` clean
immediately after restoring — the working tree was returned to exactly
the committed state):

```
$ CI=true flutter test test/planner_box_test.dart
...
lib/main.dart:73:9: Error: Type 'BoxTool' not found.
  final BoxTool _box = BoxTool();
        ^^^^^^^
lib/main.dart:73:9: Error: 'BoxTool' isn't a type.
lib/main.dart:73:24: Error: Method not found: 'BoxTool'.
00:00 +0 -1: loading .../planner_box_test.dart [E]
  Failed to load "...planner_box_test.dart": Compilation failed ...
00:00 +0 -1: Some tests failed.
```

**GREEN**, on the implemented tree, all 6 new tests plus SP5:

```
$ CI=true flutter test test/planner_box_test.dart test/startup_plan_test.dart
...
00:01 +11: .../planner_box_test.dart: BX2 two clicks: one box, four lines, one undo step
00:01 +12: .../planner_box_test.dart: BX3 Fill does not apply to a box
00:01 +13: .../planner_box_test.dart: BX4 two overlapping boxes read as one outline
00:01 +14: .../planner_box_test.dart: BX5 click a box, Delete: gone with its component; cmd+Z brings both back (Review Focus 2)
00:01 +15: .../planner_box_test.dart: BX6 typing B in the page panel field does not switch tools
00:01 +16: All tests passed!
```

Full app suite, same tree:

```
$ CI=true flutter test
...
00:04 +59: All tests passed!
```

59 = the branch-point 52 (STATUS.md's "app 46" is the last recorded
gate-line count from before Plan 06's engine/render tasks; the app test
count carried into this branch was 52 after task 6's BT1) + 6 (BX1–BX6) +
1 (SP5).

## Gate summary

```
$ CI=true flutter test          # exit 0, "All tests passed!" (59 tests)
$ flutter analyze                # exit 0, "No issues found!"
$ dart format --output=none --set-exit-if-changed .   # exit 0 (17 files, 0 changed)
$ flutter build macos --release  # exit 0, "✓ Built build/macos/Build/Products/Release/floor_planner.app (51.4MB)"
$ flutter build web --release    # exit 0, "✓ Built build/web"
```

`git status --short` before the commit showed no `analysis_options.yaml`.
`dart format` was run on every touched file before the gate; it reformatted
one line wrap in `planner_box_test.dart` (no logic change).

## Files

- `apps/floor_planner/lib/parametric/box_tool.dart` (new)
- `apps/floor_planner/lib/main.dart` (modified)
- `apps/floor_planner/lib/shortcut_guard.dart` (modified)
- `apps/floor_planner/test/support/box_rig.dart` (new)
- `apps/floor_planner/test/planner_box_test.dart` (new)
- `apps/floor_planner/test/startup_plan_test.dart` (modified, SP5 added)

Commit: `dcced6a` — "feat(floor_planner): the Box tool on B, and the
parametric system in the shell (spec 06 D13)".

## Self-review: what each test would catch

- **BX1** kills a missing/mis-wired palette entry or shortcut binding: if
  `tool-box`'s key were something other than `LogicalKeyboardKey.keyB`, or
  `_box` were never added to `_entries`, both the key press and the
  palette tap would leave the status line unchanged.
- **BX2** kills: (a) a `BoxTool.accept` that never builds the
  `CompoundCommand` (no `BoxParams`, no children); (b) a width/height swap
  or an `abs()` dropped (the two corners here are not symmetric — width
  120 ≠ height 70 — so a swap is caught); (c) the two commands wrapped as
  two separate `execute` calls instead of one `CompoundCommand` (would
  make `undoDepth == 2`, and a single `undo()` would leave a dangling
  component or dangling entities — the `boxes(doc)` and `liveSlots` checks
  after undo catch either half surviving alone).
- **BX3** kills a `commit` that reused `commitShape`'s fillable path (a
  region entity instead of four lines) — asserts every live entity is
  `EntityKind.line`, which a fill/region would violate.
- **BX4** kills: (a) `BoxType.generate`'s neighbour clip sign flipped (a
  child would then keep the *inside* segment instead of dropping it — the
  midpoint-outside check fails even where the piece *count* still happens
  to read 4, which a bare `hasLength(4)` would miss — Ruling 06-9's
  concern about a fixture sharing a bug with the code under test is why
  this loop was added rather than trusting the count alone); (b) a broken
  `neighbours()` search (reach overlap) that fails to pair the two boxes
  at all — both boxes would then keep their full, un-clipped 4-edge
  outline, indistinguishable from isolated boxes by count but not by the
  fact that `drift()` on a *rebuilt* `ParametricSystem` finds no further
  work only when the clean file already reflects the neighbour's cut;
  (c) `M-06g`'s local `BoxType`, where a wrong `toWorld`/`toLocal` would
  put the generated segments in the wrong place — the midpoint check
  against a rotated... — this tool never rotates a box, so this
  particular fixture cannot exercise a rotation mutant in `BoxType`; that
  gap is inherent to the tool's own D13 contract (world-axis aligned) and
  is not this task's to close.
- **BX5** kills: (a) the clean-up ruling (06-3) not firing on a group
  delete — `doc.components.get<BoxParams>(first)` would stay non-null
  after the delete; (b) a delete that also silently touches the surviving
  neighbour's geometry — `boxKids(doc, boxes(doc).single)` pins its child
  count at exactly 4, i.e., that the survivor regenerated back to an
  unclipped rectangle now that its former neighbour is gone; (c) undo
  losing the parametric replay path (`ParametricReplay`) — both the
  component and the second box's presence are checked after cmd+Z.
- **BX6** kills a `ShellShortcutGuard` that forgot `keyB` in
  `kShellLetterKeys` — status would flip to `'Box'` while a page-panel
  field has focus.
- **SP5** kills Ruling 06-13's regression directly: if
  `ComponentRegistry.register` were called unconditionally by a second
  `ParametricSystem`, `startupPlan`'s existing components (whichever ones
  happen to share a registered type by then) would be wiped, and this
  test's `diagnostics()`/`drift()` calls would surface it; more directly,
  it pins that the shipped sample plan carries zero `BoxParams` handles,
  so a future task that starts seeding boxes into `startupPlan` cannot do
  so silently.

## Concerns

- **BX4 cannot exercise a rotation mutant in `BoxType`** (Ruling 06-8's
  "M-06g (app)" and "M-06o", said to live in `BoxType` and be "killed by
  the app's rotated-pair tests"): the Box tool commits only translations,
  never a rotation, so no app-level fixture built through this tool's UI
  can rotate a box. If Ruling 06-8 expects the *app's* test suite (as
  opposed to the engine's) to kill those two mutants, that test does not
  yet exist anywhere in the app tree as of this task; it would need a
  fixture that plants a rotated `GroupNode` directly (bypassing the tool),
  which is out of this task's brief. Flagging this now rather than
  silently declaring the ruling satisfied.
- **`ParametricSystem(doc, boxCatalog)` is constructed fresh inside BX4**
  (per the brief's own listing) rather than reusing the shell's installed
  `_parametric`. This is intentional and matches Ruling 06-13's contract
  (a second system over a populated document is safe, registration skips
  what is already registered), and SP5 exercises exactly this path too,
  but it does mean BX4 does not directly verify that the *shell's own*
  installed system's `drift()` is empty after the same edit — only that a
  second, independent system agrees. Given SP5 and the shipped test
  history around Ruling 06-13, this is very unlikely to hide a defect,
  but it is a gap between "the demo is consistent" and "the shell's own
  live system says so".
- The gate's build-line output was captured directly from this run (see
  Gate summary); nothing was synthesized.
