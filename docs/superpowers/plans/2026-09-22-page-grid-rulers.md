# Page, grid and rulers (sub-project 04) — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/floor_planner` shows the plan on an A4 sheet at 1:50 with an
adaptive metric grid, rulers zeroed at the sheet corner, page breaks on
demand, a page panel whose every edit is one undo step, and a zoom readout —
with a `PageComponent` in the engine that round-trips typed through the
codec, a snap rule for 03, and a `DocChange` that says what kind of edit it
carries so a page edit costs the spatial index nothing.

**Architecture:** the engine gains `PageComponent` (data on the root
handle, app-registered), the pure paper arithmetic (`page_geometry.dart`,
`grid_scale.dart`), a `capability` on the three command `DocChange`s that
`SpatialIndex` and `TileCache` use to skip components-only edits (D13), and a
`registerComponents` hook on `DraftDocumentCodec.decode`/`decodeString`. The
render layer gains `PageNotifier` (seeded, listens to `document.changes`),
`PageChromePainter` (sheet, grid over `visibleWorld ∩ sheet`, breaks; its
own `RepaintBoundary` under `DraftCanvas`), `RulerPainter` and `RulerFrame`
(two bars co-extensive with the child, a corner, a pointer notifier), and
`fitToPage`. The app registers and places the page in `startupPlan`, fits
the camera to it inside the frame's child slot, adds `PagePanel` to the
right slot and `zoom-text` to the top bar.

**Tech Stack:** Dart, Flutter **3.47.2** (the installed SDK, under a cask
directory named `3.27.3`), `flutter_test`, `vector_math`, `jet_cad_2d`,
`jet_cad_2d_flutter`. No new dependency anywhere.

**Spec:** [docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md](../specs/2026-09-22-page-grid-rulers-design.md),
**revision 2**. Read it whole before Task 1: D1–D13, the invariants, the
twenty-two mutants and the sixteen exit criteria. The review that produced
revision 2 is
[docs/superpowers/notes/2026-09-22-page-grid-rulers-spec-review-r1.md](../notes/2026-09-22-page-grid-rulers-spec-review-r1.md);
its B1 (a root component edit rebuilds the index) is the reason Task 2
exists, and B3 (iterate the intersection, not the sheet) is the one a
developer is most likely to undo by reflex in Task 6.

**Roadmap input:** [roadmap/04-page-grid-rulers.md](../../../roadmap/04-page-grid-rulers.md).

**Branch:** `plan-04/page-grid-rulers`, cut from local `main` at `52dd8ae`
or later, in its own worktree. **`origin/main` is stale** (memory:
`jet-cad-plan-status`): create the worktree by hand from local `main` —
`git worktree add .claude/worktrees/plan-04-page-grid-rulers -b
plan-04/page-grid-rulers main` — and enter it with `EnterWorktree path=…`.
The ledger lives at `.superpowers/sdd/2026-09-22-page-grid-rulers/` while the
plan is in flight and is archived to `docs/superpowers/ledgers/` as the
branch's last commit before the merge.

---

## Rulings made here rather than left to an implementer

- **Ruling 04-1 — `startupPlan` ends with `doc.commands.clearHistory()`.**
  The spec's D12 says the page is attached "through `SetComponentCommand`, so
  it is on the undo stack like the rest of the plan". Left there, the first
  cmd+Z a user presses at startup would delete the page (and the second the
  last-drawn furniture line) — the plan is built through the log for the
  index's sake, not for undo. A loaded document has no history
  (`notifyLoaded` clears it); a startup document should not either. This
  also makes `undoDepth` usable in the shell tests, which Plan 02 could not
  because the 500-command startup filled the 200-entry stack. Spec D12 is
  amended at execution with this sentence. The existing shell tests
  (`cmd+Z undoes a Delete`, `ctrl+Z after deleting two walls`) still hold:
  they count live entities, not depth.
- **Ruling 04-2 — the shell owns `PageNotifier`, not the view.** Spec D10
  says "constructed by the view". The panel (right slot) and the zoom text
  (top bar) live outside `PlannerView`, so the notifier is a shell field
  constructed after `_document` and passed to the view, the panel and the
  zoom builder — the same shape as `SelectionController`.
- **Ruling 04-3 — minor lines that coincide with a major are not drawn
  twice.** `_lines` skips minor indices that are multiples of
  `major / minor`; the "minor count" every test asserts is the count of
  minor-only lines. The differential check counts majors only.
- **Ruling 04-4 — `RulerPainter` derives the visible range from its own
  size.** The bar is co-extensive with the child on its axis (D11), so
  `camera.visibleWorld(size)` with the bar's size gives the right range on
  that axis and an irrelevant one on the other; the camera is axis-aligned
  (non-goal), so nothing leaks between axes.
- **Ruling 04-5 — the `CompoundCommand` test comment is the only edit to
  `compound_command_test.dart`.** D13 gives the summary capability a
  consumer; the comment saying "nothing in the repo dispatches on it" is
  now false and Task 2 rewrites that one comment.
- **Ruling 04-6 — `PagePanel` is a `StatefulWidget` for one reason: the
  scale `TextField` needs a controller synced from the notifier.** Every
  other control is stateless over `ValueListenableBuilder`.

## Global Constraints

Copied from `CLAUDE.md` and the spec; this plan's additions marked.

- **The frame path allocates nothing per entity in steady state, and O(1)
  per flush.** `query_allocation_test.dart` and `paint_allocation_test.dart`
  stay green unedited. **This plan adds:** the chrome painters are outside
  the vertices sink path; their per-frame work is O(lines) with lines
  bounded (Invariant 2), and the grid's point list is a `sublistView` of a
  buffer grown once.
- **Draw order is ascending handle value.** Nothing here writes geometry.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.** `PageComponent ==` and preset recognition are exact; pixel
  thresholds are plain comparisons.
- **Screen coordinates only into `dart:ui`** from the chrome painters (spec
  Invariant 5). No rebase, no absolute world coordinate.
- **Never commit a rewrite of `analysis_options.yaml`.** `git status
  --short` before every commit; `git checkout --` any
  `analysis_options.yaml` that `pub get` rewrote (yaml only — never a
  `.dart`).
- **Never synthesize test output.** Run the command, paste what it printed,
  including the exit code.
- **Before firing a mutation, back the file up with `cp`, and restore from
  that copy.** Never `git checkout --` a file to revert a mutation.
- **Prefix every test command with `CI=true`.**
- **Commit trailer, exactly:** `Co-Authored-By: Claude Fable 5.1
  <noreply@anthropic.com>`. Check with `git log -1 --format=%B | grep -c
  "Fable 5.1"` → `1`.
- Code, comments and commit messages in English.
- **`apps/dev_harness_2d` is untouched.** 82 tests at the branch point.
- **`DraftCanvas`, `DraftPainter`, `CameraGestureDetector`,
  `InteractionLayer`, `SelectionOverlayPainter` are untouched.** `TileCache`
  changes by exactly the D13 skip.
- **Every fixture is off the identity.** The standard fixture (spec,
  Testing): page origin (7350, −1230), A4 landscape, 1:50, metres; camera
  `cameraAt(0.137, const Offset(-611.5, 412.25))`. Never scale 1.0, never a
  page at (0, 0), never a square sheet.
- **Every task ends green.** The gate commands (spec, criterion 15):

  ```sh
  cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --release && flutter build web --release
  ```

  Tasks 1–4 run the `jet_cad_2d` line. Tasks 5–8 run the
  `jet_cad_2d_flutter` line (its `flutter test` exits 1 on the five
  pre-existing `text_ladder_golden_test.dart` failures and on nothing else —
  paste the summary line and check the failing names are those five). Task
  2 also runs the `jet_cad_2d_flutter` line (the tile cache). Tasks 9–10 add
  the `floor_planner` line. Tasks 11 and 12 run all four.

## File structure

| file | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/document/page_component.dart` | **create** — `PageComponent`, `PageOrientation`, `DisplayUnit`, `SheetSize`, `register` |
| `packages/jet_cad_2d/lib/src/document/page_geometry.dart` | **create** — `sheetWorldRect`, `zoomOf`, `pageWorldOf`, `worldOfPage` |
| `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart` | **create** — `GridScale`, `pick`, ladders, `formatLength`, `snapToGrid` |
| `packages/jet_cad_2d/lib/src/document/doc_change.dart` | **modify** — `capability` |
| `packages/jet_cad_2d/lib/src/document/undo.dart` | **modify** — fills `capability` |
| `packages/jet_cad_2d/lib/src/index/spatial_index.dart` | **modify** — the skip |
| `packages/jet_cad_2d/lib/src/codec/json_codec.dart` | **modify** — `registerComponents` |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | **modify** — three exports |
| `packages/jet_cad_2d/test/document/page_component_test.dart` | **create** |
| `packages/jet_cad_2d/test/document/page_geometry_test.dart` | **create** |
| `packages/jet_cad_2d/test/geometry/grid_scale_test.dart` | **create** |
| `packages/jet_cad_2d/test/index/component_edit_skip_test.dart` | **create** |
| `packages/jet_cad_2d/test/codec/page_component_roundtrip_test.dart` | **create** |
| `packages/jet_cad_2d/test/document/compound_command_test.dart` | **modify** — one comment (Ruling 04-5) |
| `packages/jet_cad_2d_flutter/lib/src/chrome_style.dart` | **create** — constants and colours |
| `packages/jet_cad_2d_flutter/lib/src/page_fit.dart` | **create** — `fitToPage` |
| `packages/jet_cad_2d_flutter/lib/src/page_notifier.dart` | **create** |
| `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart` | **create** |
| `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart` | **create** — `RulerAxis`, `RulerPainter`, `RulerCornerPainter` |
| `packages/jet_cad_2d_flutter/lib/src/ruler_frame.dart` | **create** |
| `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` | **modify** — the skip |
| `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` | **modify** — six exports |
| `packages/jet_cad_2d_flutter/test/support/page_fixture.dart` | **create** — the standard page, camera, `SpyCanvas` helpers |
| `packages/jet_cad_2d_flutter/test/page_fit_test.dart`, `page_notifier_test.dart`, `page_chrome_painter_test.dart`, `ruler_painter_test.dart`, `ruler_frame_test.dart` | **create** |
| `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` | **modify** — one test for the skip |
| `apps/floor_planner/lib/startup_plan.dart` | **modify** — register, units, place, clear history |
| `apps/floor_planner/lib/planner_view.dart` | **modify** — the tree, fit to page |
| `apps/floor_planner/lib/page_panel.dart` | **create** |
| `apps/floor_planner/lib/main.dart` | **modify** — notifier, panel, zoom text, initial fit |
| `apps/floor_planner/test/page_panel_test.dart` | **create** |
| `apps/floor_planner/test/planner_shell_test.dart`, `startup_plan_test.dart` | **modify** |
| `docs/superpowers/notes/plan-04-mutation-log.md` | **create** |
| `docs/superpowers/notes/2026-09-22-plan-04-results.md` | **create** |
| `roadmap/00-README.md`, `roadmap/04-page-grid-rulers.md`, `STATUS.md`, the spec | **modify** — plan and execution recorded |

Paths under `lib/` and `test/` in Tasks 1–4 are relative to
`packages/jet_cad_2d/`; in Tasks 5–8 to `packages/jet_cad_2d_flutter/`; in
Tasks 9–10 to `apps/floor_planner/`.

---

### Task 1: The branch point, and `PageComponent`

**Files:**
- Create: `lib/src/document/page_component.dart`
- Modify: `lib/jet_cad_2d.dart` (export)
- Test: `test/document/page_component_test.dart`

**Interfaces:**
- Produces: `PageComponent`, `PageOrientation`, `DisplayUnit` (+
  `mmPerUnit`, `symbol`, `isImperial`), `SheetSize` (+ `presets`),
  `PageComponent.register`, `effectiveWidthMm/HeightMm`, `preset`,
  `copyWith`, `fromJson`, `componentTypeId`.

- [ ] **Step 1: Branch point.** In the worktree: `git log --oneline -1`
  (≥ `52dd8ae`), `flutter pub get`, then the four gate lines once, pasting
  the four summary lines into the ledger: engine 830, render layer 771 +
  1 skip + the five goldens, harness 82, app 13. `git checkout --` the three
  `analysis_options.yaml` files.

- [ ] **Step 2: Write the failing tests.**

```dart
// test/document/page_component_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  // Never a square sheet (M-04e), never the defaults where a default would
  // hide the assertion.
  final letterPortrait = PageComponent(
    widthMm: 215.9, heightMm: 279.4, orientation: PageOrientation.portrait,
    scaleDenominator: 48, originX: 7350, originY: -1230,
    displayUnit: DisplayUnit.feetInches, background: 0xFFFAF6EC,
    gridVisible: false, gridStepMm: 152.4, snapToGrid: false, pageBreaks: true);

  test('effective size follows orientation on a non-square sheet', () {
    // M-04e.
    expect(letterPortrait.effectiveWidthMm, 215.9);
    expect(letterPortrait.effectiveHeightMm, 279.4);
    final landscape = letterPortrait.copyWith(orientation: PageOrientation.landscape);
    expect(landscape.effectiveWidthMm, 279.4);
    expect(landscape.effectiveHeightMm, 215.9);
  });

  test('presets are recognised by exact dimensions, anything else is custom', () {
    expect(letterPortrait.preset, SheetSize.letter);
    expect(PageComponent().preset, SheetSize.a4);
    expect(letterPortrait.copyWith(widthMm: 215.9, heightMm: 279.5).preset, isNull);
  });

  test('toJson keys are alphabetical and fromJson round-trips by value', () {
    final json = letterPortrait.toJson();
    expect(json.keys.toList(), [
      'background', 'displayUnit', 'gridStepMm', 'gridVisible', 'heightMm',
      'orientation', 'originX', 'originY', 'pageBreaks', 'scaleDenominator',
      'snapToGrid', 'widthMm',
    ]);
    final back = PageComponent.fromJson(json);
    expect(back, letterPortrait);
    expect(back.hashCode, letterPortrait.hashCode);
    expect(back.gridStepMm, 152.4);
  });

  test('optional keys take their defaults, required keys throw', () {
    final json = letterPortrait.toJson()
      ..remove('gridStepMm')
      ..remove('gridVisible')
      ..remove('snapToGrid')
      ..remove('pageBreaks')
      ..remove('background');
    final back = PageComponent.fromJson(json);
    expect(back.gridStepMm, isNull);
    expect(back.gridVisible, isTrue);
    expect(back.snapToGrid, isTrue);
    expect(back.pageBreaks, isFalse);
    expect(back.background, 0xFFFFFFFF);
    expect(() => PageComponent.fromJson(json..remove('originX')),
        throwsA(isA<FormatException>()));
  });

  test('copyWith can clear gridStepMm and leaves the rest alone', () {
    final cleared = letterPortrait.copyWith(gridStepMm: null);
    expect(cleared.gridStepMm, isNull);
    expect(cleared.copyWith(displayUnit: DisplayUnit.meters).scaleDenominator, 48);
    expect(letterPortrait.copyWith(), letterPortrait);
  });

  test('validation refuses non-finite and non-positive values', () {
    expect(() => PageComponent(widthMm: 0), throwsArgumentError);
    expect(() => PageComponent(heightMm: double.nan), throwsArgumentError);
    expect(() => PageComponent(scaleDenominator: -50), throwsArgumentError);
    expect(() => PageComponent(gridStepMm: 0), throwsArgumentError);
    expect(() => PageComponent(originX: double.infinity), throwsArgumentError);
  });

  test('register makes the type known to a registry, once', () {
    final registry = ComponentRegistry()..registerBuiltIns();
    PageComponent.register(registry);
    registry.attach(const Handle(16), letterPortrait);
    expect(registry.get<PageComponent>(const Handle(16)), letterPortrait);
    expect(registry.isInternal(PageComponent.componentTypeId), isFalse);
  });

  test('DisplayUnit conversions are exact', () {
    expect(DisplayUnit.millimeters.mmPerUnit, 1);
    expect(DisplayUnit.centimeters.mmPerUnit, 10);
    expect(DisplayUnit.meters.mmPerUnit, 1000);
    expect(DisplayUnit.inches.mmPerUnit, 25.4);
    expect(DisplayUnit.feetInches.mmPerUnit, 304.8);
    expect(DisplayUnit.feetInches.isImperial, isTrue);
    expect(DisplayUnit.centimeters.isImperial, isFalse);
    expect(DisplayUnit.meters.symbol, 'm');
    expect(DisplayUnit.feetInches.symbol, 'ft');
  });
}
```

- [ ] **Step 3: Run it to fail.** `CI=true dart test
  test/document/page_component_test.dart` → compile error, `PageComponent`
  undefined.

- [ ] **Step 4: Implement.**

```dart
// lib/src/document/page_component.dart
import 'component.dart';

/// Which way the sheet is turned; [PageComponent.widthMm] and [heightMm]
/// are always the portrait dimensions.
enum PageOrientation { portrait, landscape }

/// The unit a person reads (spec D1). The model is millimetres regardless.
enum DisplayUnit { millimeters, centimeters, meters, inches, feetInches }

extension DisplayUnitConversion on DisplayUnit {
  /// Exact, spec D1's table.
  double get mmPerUnit => switch (this) {
        DisplayUnit.millimeters => 1.0,
        DisplayUnit.centimeters => 10.0,
        DisplayUnit.meters => 1000.0,
        DisplayUnit.inches => 25.4,
        DisplayUnit.feetInches => 304.8,
      };

  String get symbol => switch (this) {
        DisplayUnit.millimeters => 'mm',
        DisplayUnit.centimeters => 'cm',
        DisplayUnit.meters => 'm',
        DisplayUnit.inches => 'in',
        DisplayUnit.feetInches => 'ft',
      };

  bool get isImperial =>
      this == DisplayUnit.inches || this == DisplayUnit.feetInches;
}

/// A sheet's portrait dimensions in paper millimetres.
class SheetSize {
  const SheetSize(this.widthMm, this.heightMm);

  static const SheetSize a4 = SheetSize(210, 297);
  static const SheetSize a3 = SheetSize(297, 420);
  static const SheetSize letter = SheetSize(215.9, 279.4);
  static const SheetSize tabloid = SheetSize(279.4, 431.8);
  static const List<SheetSize> presets = [a4, a3, letter, tabloid];

  final double widthMm;
  final double heightMm;

  String get name => switch (this) {
        a4 => 'A4',
        a3 => 'A3',
        letter => 'Letter',
        tabloid => 'Tabloid',
        _ => 'Custom',
      };

  @override
  bool operator ==(Object other) =>
      other is SheetSize && other.widthMm == widthMm && other.heightMm == heightMm;

  @override
  int get hashCode => Object.hash(widthMm, heightMm);
}

/// Sentinel for [PageComponent.copyWith]'s nullable field.
const Object _keep = Object();

/// The page (spec D3): sheet, orientation, drawing scale, the sheet's world
/// origin, display unit, paper colour, grid and snap settings. Attached to
/// the root handle by the application; not an engine built-in.
///
/// Immutable and value-equal, like every [Component]; `toJson` keys are
/// alphabetical, so the order is fixed by construction.
class PageComponent implements Component {
  static const String componentTypeId = 'jetcad.page';

  /// Registers the type. **Once per registry**: `register` replaces the
  /// store for the type, so a second call drops a live page.
  static void register(ComponentRegistry registry) =>
      registry.register<PageComponent>(componentTypeId, fromJson);

  final double widthMm;
  final double heightMm;
  final PageOrientation orientation;
  final double scaleDenominator;
  final double originX;
  final double originY;
  final DisplayUnit displayUnit;
  final int background;
  final bool gridVisible;
  final double? gridStepMm;
  final bool snapToGrid;
  final bool pageBreaks;

  PageComponent({
    this.widthMm = 210,
    this.heightMm = 297,
    this.orientation = PageOrientation.landscape,
    this.scaleDenominator = 50,
    this.originX = 0,
    this.originY = 0,
    this.displayUnit = DisplayUnit.meters,
    this.background = 0xFFFFFFFF,
    this.gridVisible = true,
    this.gridStepMm,
    this.snapToGrid = true,
    this.pageBreaks = false,
  }) {
    _requirePositive(widthMm, 'widthMm');
    _requirePositive(heightMm, 'heightMm');
    _requirePositive(scaleDenominator, 'scaleDenominator');
    final step = gridStepMm;
    if (step != null) _requirePositive(step, 'gridStepMm');
    _requireFinite(originX, 'originX');
    _requireFinite(originY, 'originY');
  }

  static void _requirePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'must be finite and positive');
    }
  }

  static void _requireFinite(double value, String name) {
    if (!value.isFinite) throw ArgumentError.value(value, name, 'must be finite');
  }

  double get effectiveWidthMm =>
      orientation == PageOrientation.portrait ? widthMm : heightMm;
  double get effectiveHeightMm =>
      orientation == PageOrientation.portrait ? heightMm : widthMm;

  /// The preset whose dimensions match exactly, or null for a custom sheet.
  SheetSize? get preset {
    for (final p in SheetSize.presets) {
      if (p.widthMm == widthMm && p.heightMm == heightMm) return p;
    }
    return null;
  }

  PageComponent copyWith({
    double? widthMm,
    double? heightMm,
    PageOrientation? orientation,
    double? scaleDenominator,
    double? originX,
    double? originY,
    DisplayUnit? displayUnit,
    int? background,
    bool? gridVisible,
    Object? gridStepMm = _keep,
    bool? snapToGrid,
    bool? pageBreaks,
  }) =>
      PageComponent(
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        orientation: orientation ?? this.orientation,
        scaleDenominator: scaleDenominator ?? this.scaleDenominator,
        originX: originX ?? this.originX,
        originY: originY ?? this.originY,
        displayUnit: displayUnit ?? this.displayUnit,
        background: background ?? this.background,
        gridVisible: gridVisible ?? this.gridVisible,
        gridStepMm: identical(gridStepMm, _keep)
            ? this.gridStepMm
            : gridStepMm as double?,
        snapToGrid: snapToGrid ?? this.snapToGrid,
        pageBreaks: pageBreaks ?? this.pageBreaks,
      );

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'background': background,
        'displayUnit': displayUnit.name,
        'gridStepMm': gridStepMm,
        'gridVisible': gridVisible,
        'heightMm': heightMm,
        'orientation': orientation.name,
        'originX': originX,
        'originY': originY,
        'pageBreaks': pageBreaks,
        'scaleDenominator': scaleDenominator,
        'snapToGrid': snapToGrid,
        'widthMm': widthMm,
      };

  static PageComponent fromJson(Map<String, Object?> json) => PageComponent(
        widthMm: _requiredDouble(json, 'widthMm'),
        heightMm: _requiredDouble(json, 'heightMm'),
        orientation: PageOrientation.values
            .byName(_required(json, 'orientation') as String),
        scaleDenominator: _requiredDouble(json, 'scaleDenominator'),
        originX: _requiredDouble(json, 'originX'),
        originY: _requiredDouble(json, 'originY'),
        displayUnit:
            DisplayUnit.values.byName(_required(json, 'displayUnit') as String),
        background: (json['background'] as int?) ?? 0xFFFFFFFF,
        gridVisible: (json['gridVisible'] as bool?) ?? true,
        gridStepMm: (json['gridStepMm'] as num?)?.toDouble(),
        snapToGrid: (json['snapToGrid'] as bool?) ?? true,
        pageBreaks: (json['pageBreaks'] as bool?) ?? false,
      );

  static Object _required(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) throw FormatException('PageComponent: missing "$key"');
    return value;
  }

  static double _requiredDouble(Map<String, Object?> json, String key) =>
      (_required(json, key) as num).toDouble();

  @override
  bool operator ==(Object other) =>
      other is PageComponent &&
      other.widthMm == widthMm &&
      other.heightMm == heightMm &&
      other.orientation == orientation &&
      other.scaleDenominator == scaleDenominator &&
      other.originX == originX &&
      other.originY == originY &&
      other.displayUnit == displayUnit &&
      other.background == background &&
      other.gridVisible == gridVisible &&
      other.gridStepMm == gridStepMm &&
      other.snapToGrid == snapToGrid &&
      other.pageBreaks == pageBreaks;

  @override
  int get hashCode => Object.hash(widthMm, heightMm, orientation,
      scaleDenominator, originX, originY, displayUnit, background,
      gridVisible, gridStepMm, snapToGrid, pageBreaks);

  @override
  String toString() =>
      'PageComponent(${preset?.name ?? 'custom'} ${orientation.name} '
      '1:$scaleDenominator at ($originX, $originY), ${displayUnit.name})';
}
```

Add `export 'src/document/page_component.dart';` to `lib/jet_cad_2d.dart`
in alphabetical position (after `origin_component.dart`).

- [ ] **Step 5: Run to pass**, then the `jet_cad_2d` gate line.
- [ ] **Step 6: Commit** — `feat(engine): PageComponent`.

---

### Task 2: `DocChange.capability`, and the skip in the index and the tile cache

**Files:**
- Modify: `lib/src/document/doc_change.dart`, `lib/src/document/undo.dart`,
  `lib/src/index/spatial_index.dart` (`_onChange`),
  `test/document/compound_command_test.dart` (one comment),
  `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (`applyChange`),
  `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`
- Test: `test/index/component_edit_skip_test.dart`

**Interfaces:**
- Produces: `CommandApplied/Undone/Redone.capability` (default
  `Capability.geometry`).

- [ ] **Step 1: Write the failing tests.**

```dart
// test/index/component_edit_skip_test.dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle, owner: doc.rootHandle, kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype, linetypeScale: 1.0,
      geomIndex: 0, color: const ByLayerColor(), lineweight: kByLayer,
      transparency: kByLayer, flags: 0),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

void main() {
  test('a components-only edit on the root reconciles nothing', () {
    // M-04r (the skip removed) and M-04s (the dispatcher always says
    // geometry): both make rebuildCount grow here.
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    addLine(doc, [990, 500, 1010, 500]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;
    final page = PageComponent(originX: 7350, originY: -1230);

    doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(gridVisible: false)));
    doc.commands.undo();
    doc.commands.redo();

    expect(index.rebuildCount, before);
    expect(doc.components.get<PageComponent>(doc.rootHandle),
        page.copyWith(gridVisible: false));
  });

  test('the change carries the capability of the command that made it', () {
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    final seen = <Capability>[];
    doc.commands.onAfterMutate = (change) {
      if (change case CommandApplied(:final capability) ||
          CommandUndone(:final capability) ||
          CommandRedone(:final capability)) {
        seen.add(capability);
      }
    };
    doc.commands.execute(
        SetComponentCommand<PageComponent>(doc.rootHandle, PageComponent()));
    addLine(doc, [1, 2, 3, 4]);
    doc.commands.undo();
    doc.commands.undo();
    doc.commands.redo();
    expect(seen, [
      Capability.components, Capability.geometry,
      Capability.geometry, Capability.components, Capability.components,
    ]);
  });

  test('a compound with one geometry member still reconciles', () {
    // The summary capability: components-only skips, mixed does not.
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    final line = addLine(doc, [990, 500, 1010, 500]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;
    doc.commands.execute(CompoundCommand([
      SetComponentCommand<PageComponent>(doc.rootHandle, PageComponent()),
      RemoveEntityCommand(line),
    ], label: 'mixed'));
    expect(index.rebuildCount, greaterThan(before));
  });

  test('the default capability is geometry, so old construction sites keep '
      'their meaning', () {
    const change = CommandApplied(label: 'x', touched: {Handle(7)});
    expect(change.capability, Capability.geometry);
  });
}
```

And in `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`, one
test beside the existing `applyChange` tests, using its rig:

```dart
  test('a components-only change drops no tile', () {
    // D13 for the tile cache: the same skip as the index (M-04r's twin).
    final rig = ...;  // the file's existing rig builder with a baked viewport
    final before = rig.cache.liveTileCount;
    rig.cache.applyChange(
        const CommandApplied(label: 'page', touched: {Handle(16)},
            capability: Capability.components),
        rig.doc);
    expect(rig.cache.liveTileCount, before);
    expect(rig.cache.invalidationCount, 0);
  });
```

(Handle 16 is the root in an empty document — check `rig.doc.rootHandle`
and use that instead of the literal.)

- [ ] **Step 2: Run to fail** (compile error: no `capability`).

- [ ] **Step 3: Implement.** In `doc_change.dart`, add
  `import 'command.dart';` and to each of the three classes:

```dart
final class CommandApplied extends DocChange {
  final String label;
  @override
  final Set<Handle> touched;

  /// What kind of edit this was — the command's [DraftCommand.capability],
  /// a [CompoundCommand]'s summary. [Capability.components] means no
  /// geometry and no structure moved: the spatial index and the tile cache
  /// skip it (spec D13). Defaults to [Capability.geometry] so a change built
  /// without it keeps the meaning every consumer gave it before.
  final Capability capability;

  const CommandApplied(
      {required this.label,
      required this.touched,
      this.capability = Capability.geometry});
}
```

Same for `CommandUndone` and `CommandRedone`. In `undo.dart`:
`CommandApplied(label: command.label, touched: result.touched, capability:
command.capability)`; in `undo()` and `redo()`, `capability:
inverse.capability`. In `spatial_index.dart` `_onChange`:

```dart
      case CommandApplied(:final touched, :final capability):
      case CommandUndone(:final touched, :final capability):
      case CommandRedone(:final touched, :final capability):
        // Spec D13. A components-only edit — a page setting on the root,
        // say — names a handle the structural rule would otherwise treat
        // as a node change and rebuild everything for. Components are data
        // this index never reads.
        if (capability == Capability.components) return;
        _reconcile(touched);
```

In `tile_cache.dart` `applyChange`, inside the three-case command arm,
**before** the `touched.isEmpty` check (the hoisted `_dropCarryOver()`
above the switch stays as it is):

```dart
        // Spec D13: a components-only edit moved no pixels.
        if (capability == Capability.components) return;
```

with `:final capability` added to the three patterns. In
`compound_command_test.dart`, replace the comment above the
`compound.capability` assertion with: `// "Highest-ranked" is the
declaration order of enum Capability; the spatial index and the tile cache
read it to skip components-only compounds (spec 04 D13).`

- [ ] **Step 4: Run to pass**: both new tests, then the full `jet_cad_2d`
  and `jet_cad_2d_flutter` gate lines.
- [ ] **Step 5: Commit** — `feat(engine): DocChange carries the command's
  capability; index and tiles skip component edits`.

---

### Task 3: The codec hook, and the two round-trip tests

**Files:**
- Modify: `lib/src/codec/json_codec.dart`
- Test: `test/codec/page_component_roundtrip_test.dart`

- [ ] **Step 1: Write the failing tests.**

```dart
// test/codec/page_component_roundtrip_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

DraftDocument withPage() {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(SetComponentCommand<PageComponent>(
    doc.rootHandle,
    PageComponent(
        widthMm: 215.9, heightMm: 279.4, orientation: PageOrientation.portrait,
        scaleDenominator: 48, originX: 7350, originY: -1230,
        displayUnit: DisplayUnit.feetInches, background: 0xFFFAF6EC,
        gridStepMm: 152.4, pageBreaks: true),
  ));
  return doc;
}

void main() {
  test('the page round-trips typed when the load registers it, and the '
      'bytes are stable', () {
    // M-04d: registering after loadJson makes the typed value null.
    final doc = withPage();
    final original = doc.components.get<PageComponent>(doc.rootHandle)!;
    final first = DraftDocumentCodec.encodeToString(doc);

    final back = DraftDocumentCodec.decodeString(first,
        registerComponents: PageComponent.register);

    expect(back.components.get<PageComponent>(back.rootHandle), original);
    expect(back.components.unknownOf(back.rootHandle), isEmpty);
    expect(DraftDocumentCodec.encodeToString(back), first);
  });

  test('without registration the bytes survive but the type does not — '
      'which is why the typed assertion above exists', () {
    final doc = withPage();
    final first = DraftDocumentCodec.encodeToString(doc);

    final back = DraftDocumentCodec.decodeString(first);

    expect(() => back.components.get<PageComponent>(back.rootHandle),
        anyOf(returnsNormally, throwsA(anything)));
    final unknown = back.components.unknownOf(back.rootHandle);
    expect(unknown, hasLength(1));
    expect(unknown.single['typeId'], PageComponent.componentTypeId);
    expect(DraftDocumentCodec.encodeToString(back), first);
  });

  test('decode (the map form) takes the same hook', () {
    final doc = withPage();
    final json = DraftDocumentCodec.encode(doc);
    final back = DraftDocumentCodec.decode(json,
        registerComponents: PageComponent.register);
    expect(back.components.get<PageComponent>(back.rootHandle),
        doc.components.get<PageComponent>(doc.rootHandle));
  });
}
```

(In test 2, `get<PageComponent>` on a registry that never registered the
type returns null through `_stores[T]?[handle]`; replace the `anyOf` with
`expect(back.components.get<PageComponent>(back.rootHandle), isNull)` once
you have confirmed that by running it — the `anyOf` is only there so the
first run cannot fail for the wrong reason.)

- [ ] **Step 2: Run to fail** (no named parameter `registerComponents`).

- [ ] **Step 3: Implement.** In `decode`, add the parameter and call it
  right after `DraftDocument.empty(...)`:

```dart
    void Function(ComponentRegistry registry)? registerComponents,
  }) {
    ...
    final doc = DraftDocument.empty(
      measurer: measurer, permissions: permissions, undoLimit: undoLimit);
    // Before the components load, so an application type comes back typed
    // rather than as preserve-unknown bytes (spec 04 D9). After it would be
    // M-04d: the payload lands in `_unknown` and `get<T>` is null.
    registerComponents?.call(doc.components);
```

Add the same parameter to `decodeString` and forward it.

- [ ] **Step 4: Run to pass**, then the `jet_cad_2d` gate line.
- [ ] **Step 5: Commit** — `feat(codec): registerComponents hook on decode
  and decodeString`.

---

### Task 4: `page_geometry.dart` and `grid_scale.dart`

**Files:**
- Create: `lib/src/document/page_geometry.dart`,
  `lib/src/geometry/grid_scale.dart`
- Modify: `lib/jet_cad_2d.dart` (two exports)
- Test: `test/document/page_geometry_test.dart`,
  `test/geometry/grid_scale_test.dart`

**Interfaces:**
- Produces: `sheetWorldRect`, `zoomOf`, `pageWorldOf`, `worldOfPage`;
  `kMajorMinPixels`, `kMinorMinPixels`, `GridScale` (`majorMm`, `minorMm`,
  `unit`, `divisor`), `GridScale.pick`, `GridScale.ladderFor`,
  `formatLength`, `snapToGrid`.

- [ ] **Step 1: Write the failing tests.**

```dart
// test/document/page_geometry_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  final page = PageComponent(
      originX: 7350, originY: -1230, scaleDenominator: 50);  // A4 landscape

  test('the sheet rect is origin plus effective size times D', () {
    // M-04j (D ignored) and M-04e (orientation swapped).
    final rect = sheetWorldRect(page);
    expect(rect.minX, 7350);
    expect(rect.minY, -1230);
    expect(rect.maxX, 7350 + 297 * 50);
    expect(rect.maxY, -1230 + 210 * 50);
    final portrait = sheetWorldRect(page.copyWith(orientation: PageOrientation.portrait));
    expect(portrait.maxX, 7350 + 210 * 50);
  });

  test('100 % is pixelsPerPaperMm / D', () {
    // M-04n.
    const ppm = 96.0 / 25.4;
    expect(zoomOf(ppm / 50, page, ppm), closeTo(1.0, 1e-12));
    expect(zoomOf(ppm / 100, page, ppm), closeTo(0.5, 1e-12));
    expect(zoomOf(0.137, page.copyWith(scaleDenominator: 48), ppm),
        closeTo(0.137 * 48 / ppm, 1e-12));
  });

  test('page space is world minus origin, and back', () {
    final p = pageWorldOf(Vector2(8000, -230), page);
    expect(p.x, 650);
    expect(p.y, 1000);
    expect(worldOfPage(p, page).x, 8000);
    expect(worldOfPage(p, page).y, -230);
  });
}
```

**Ruling 04-7 (recorded in the ledger; spec D7 amended at execution):** with `kMajorMinPixels = 64` and divisors 4 and 5, a ladder step's minor spacing is always at least 12.8 px, so the 8 px minor threshold can never fire from the shipped ladders on their own. The threshold and the null branch stay (the spec names them, 03 may pass finer floors, a future divisor of 10 would need them) and `pick` takes `minorMinPixels` (default `kMinorMinPixels`) so the branch is testable: M-04g fires on that test and on the painter's `minor != null` branch (Task 6).

```dart
// test/geometry/grid_scale_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('pick', () {
    test('metric: the smallest ladder step at or above 64 px', () {
      // At 0.137 px/mm: 100 mm → 13.7 px, 200 → 27.4, 500 → 68.5. Major is
      // 500 mm; minor 100 mm → 13.7 px ≥ 8, drawn. M-04c (continuous) would
      // answer 64 / 0.137 = 467.15 mm.
      final s = GridScale.pick(DisplayUnit.meters, 0.137)!;
      expect(s.majorMm, 500);
      expect(s.minorMm, 100);
      expect(s.divisor, 5);
    });

    test('a mantissa-2 major divides by 4', () {
      // At 0.35 px/mm: 100 → 35 px, 200 → 70 px. Major 200, minor 50 → 17.5 px.
      final s = GridScale.pick(DisplayUnit.centimeters, 0.35)!;
      expect(s.majorMm, 200);
      expect(s.minorMm, 50);
      expect(s.divisor, 4);
    });

    test('minor is null under the minor threshold', () {
      // M-04g's engine half, with the threshold passed explicitly because
      // the shipped 64/8 pair cannot reach the branch on its own (Ruling 04-7).
      final s = GridScale.pick(DisplayUnit.meters, 0.137, minorMinPixels: 20)!;
      expect(s.majorMm, 500);
      expect(s.minorMm, isNull);
    });

    test('imperial ladder in inches and feet', () {
      // At 0.137 px/mm: 6" = 152.4 mm → 20.9 px; 1' = 304.8 → 41.8; 2' →
      // 83.5 px. Major 2', minor 6" (divisor 4) → 20.9 px.
      final s = GridScale.pick(DisplayUnit.feetInches, 0.137)!;
      expect(s.majorMm, closeTo(609.6, 1e-9));
      expect(s.minorMm, closeTo(152.4, 1e-9));
    });

    test('null past the top of the ladder, and for a bad scale', () {
      expect(GridScale.pick(DisplayUnit.meters, 1e-9), isNull);
      expect(GridScale.pick(DisplayUnit.meters, 0), isNull);
      expect(GridScale.pick(DisplayUnit.meters, double.nan), isNull);
    });

    test('a floor is exact when it fits and the ladder climbs from it', () {
      // M-04q. At 0.3 px/mm the metric ladder says 500 (150 px) … no: 200
      // → 60 px < 64, 500 → 150 px. Floor 250 → 75 px: exact.
      final s = GridScale.pick(DisplayUnit.meters, 0.3, floorMm: 250)!;
      expect(s.majorMm, 250);
      // At 0.1 px/mm: 250 → 25 px, 500 → 50, 1250 → 125. Climbs to 1250.
      expect(GridScale.pick(DisplayUnit.meters, 0.1, floorMm: 250)!.majorMm, 1250);
    });

    test('the ladders are ascending and the metric one is 1-2-5', () {
      final metric = GridScale.ladderFor(DisplayUnit.meters);
      for (var i = 1; i < metric.length; i++) {
        expect(metric[i], greaterThan(metric[i - 1]));
      }
      expect(metric.first, closeTo(0.1, 1e-12));
      expect(metric.last, 5e7);
      expect(metric.sublist(3, 6), [1, 2, 5]);
      final imperial = GridScale.ladderFor(DisplayUnit.inches);
      expect(imperial.first, closeTo(25.4 / 16, 1e-12));
      expect(imperial.contains(304.8), isTrue);
    });
  });

  group('formatLength', () {
    test('per unit', () {
      // M-04i.
      expect(formatLength(1500, DisplayUnit.millimeters), '1500 mm');
      expect(formatLength(1500, DisplayUnit.centimeters), '150 cm');
      expect(formatLength(1500, DisplayUnit.meters), '1.5 m');
      expect(formatLength(311.15, DisplayUnit.inches), '12.25 in');
      expect(formatLength(1066.8, DisplayUnit.feetInches), '3\'-6"');
      expect(formatLength(1079.5, DisplayUnit.feetInches), '3\'-6 1/2"');
      expect(formatLength(152.4, DisplayUnit.feetInches), '0\'-6"');
      expect(formatLength(-2000, DisplayUnit.meters), '-2 m');
      expect(formatLength(0, DisplayUnit.meters), '0 m');
      expect(formatLength(0, DisplayUnit.feetInches), '0\'-0"');
    });
  });

  group('snapToGrid', () {
    final page = PageComponent(originX: 7350, originY: -1230);

    test('nearest, anchored at the sheet origin, negative side too', () {
      // M-04h (truncate) and M-04f (world anchor).
      final p = snapToGrid(Vector2(7350 + 0.7 * 500, -1230 - 0.7 * 500), 500, page);
      expect(p.x, 7350 + 500);
      expect(p.y, -1230 - 500);
      final q = snapToGrid(Vector2(7350 + 0.3 * 500, -1230 + 0.3 * 500), 500, page);
      expect(q.x, 7350);
      expect(q.y, -1230);
    });

    test('an adaptive step lands on the drawn lattice', () {
      // Invariant 3's engine half: the step comes from pick.
      final s = GridScale.pick(DisplayUnit.meters, 0.137)!;
      final p = snapToGrid(Vector2(8000, -230), s.minorMm ?? s.majorMm, page);
      expect((p.x - page.originX) % (s.minorMm ?? s.majorMm), 0);
    });

    test('refuses a non-positive step', () {
      expect(() => snapToGrid(Vector2.zero(), 0, page), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run both to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/src/document/page_geometry.dart
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../geometry/aabb2.dart';
import 'page_component.dart';

/// The sheet in world millimetres: origin plus the effective size at 1:D.
Aabb2 sheetWorldRect(PageComponent page) => Aabb2.raw(
      page.originX,
      page.originY,
      page.originX + page.effectiveWidthMm * page.scaleDenominator,
      page.originY + page.effectiveHeightMm * page.scaleDenominator,
    );

/// 1.0 is 100 %: the sheet at physical size on a 96-dpi screen (spec D4).
double zoomOf(double pxPerWorldMm, PageComponent page, double pixelsPerPaperMm) =>
    pxPerWorldMm * page.scaleDenominator / pixelsPerPaperMm;

/// World minus the sheet origin — what the rulers read (spec D5).
Vector2 pageWorldOf(Vector2 world, PageComponent page) =>
    Vector2(world.x - page.originX, world.y - page.originY);

Vector2 worldOfPage(Vector2 pageMm, PageComponent page) =>
    Vector2(pageMm.x + page.originX, pageMm.y + page.originY);
```

```dart
// lib/src/geometry/grid_scale.dart
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../document/page_component.dart';

/// A major line needs at least this many screen pixels between it and the
/// next (spec D7).
const double kMajorMinPixels = 64.0;

/// A minor line needs at least this many.
const double kMinorMinPixels = 8.0;

/// One step ladder decision, shared by the grid, the rulers and the
/// adaptive snap so they cannot disagree (spec D7).
class GridScale {
  const GridScale({required this.majorMm, required this.minorMm, required this.unit});

  final double majorMm;

  /// Null when minors would be closer than the minor threshold.
  final double? minorMm;
  final DisplayUnit unit;

  /// Minor lines per major, or 1 when there are no minors.
  int get divisor => minorMm == null ? 1 : (majorMm / minorMm!).round();

  static const List<double> _mantissas = [1, 2, 5];

  /// Ascending steps in world millimetres.
  static List<double> ladderFor(DisplayUnit unit, {double? floorMm}) {
    if (floorMm != null) {
      return [
        for (var k = 0; k <= 7; k++)
          for (final m in _mantissas) floorMm * m * math.pow(10.0, k),
      ];
    }
    if (unit.isImperial) {
      return [
        for (final inches in const [1 / 16, 1 / 8, 1 / 4, 1 / 2, 1, 2, 6])
          inches * 25.4,
        for (final feet in const [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 5000])
          feet * 304.8,
      ];
    }
    return [
      for (var k = -1; k <= 7; k++)
        for (final m in _mantissas) m * math.pow(10.0, k),
    ];
  }

  /// The smallest ladder step whose screen spacing is at least
  /// [kMajorMinPixels], with its minor; null when no step reaches it (extreme
  /// zoom-out) or the scale is not a positive finite number.
  static GridScale? pick(
    DisplayUnit unit,
    double pxPerWorldMm, {
    double? floorMm,
    double minorMinPixels = kMinorMinPixels,
  }) {
    if (!pxPerWorldMm.isFinite || pxPerWorldMm <= 0) return null;
    for (final step in ladderFor(unit, floorMm: floorMm)) {
      if (step * pxPerWorldMm >= kMajorMinPixels) {
        final divisor = _divisorFor(step, unit, floorMm);
        final minor = step / divisor;
        return GridScale(
          majorMm: step,
          minorMm: minor * pxPerWorldMm >= minorMinPixels ? minor : null,
          unit: unit,
        );
      }
    }
    return null;
  }

  /// 4 for a mantissa-2 metric step and for every imperial step, else 5.
  static int _divisorFor(double step, DisplayUnit unit, double? floorMm) {
    if (unit.isImperial && floorMm == null) return 4;
    final ratio = floorMm == null ? step : step / floorMm;
    final exponent = (math.log(ratio) / math.ln10).floor();
    final mantissa = (ratio / math.pow(10.0, exponent)).round();
    return mantissa == 2 ? 4 : 5;
  }
}

/// A length in the display unit, spec D7's table.
String formatLength(double mm, DisplayUnit unit) => switch (unit) {
      DisplayUnit.millimeters => '${_trim(mm, 3)} mm',
      DisplayUnit.centimeters => '${_trim(mm / 10, 3)} cm',
      DisplayUnit.meters => '${_trim(mm / 1000, 3)} m',
      DisplayUnit.inches => '${_trim(mm / 25.4, 4)} in',
      DisplayUnit.feetInches => _feetInches(mm),
    };

String _trim(double value, int decimals) {
  var s = value.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

String _feetInches(double mm) {
  final sign = mm < 0 ? '-' : '';
  final sixteenths = (mm.abs() / 25.4 * 16).round();
  final feet = sixteenths ~/ 192;
  final rest = sixteenths % 192;
  final inches = rest ~/ 16;
  var numerator = rest % 16;
  var denominator = 16;
  while (numerator != 0 && numerator.isEven) {
    numerator ~/= 2;
    denominator ~/= 2;
  }
  final fraction = numerator == 0 ? '' : ' $numerator/$denominator';
  return "$sign$feet'-$inches$fraction\"";
}

/// Nearest lattice point of [stepMm] anchored at the sheet origin (spec
/// D6). Works everywhere in the world; returns a fresh vector.
Vector2 snapToGrid(Vector2 world, double stepMm, PageComponent page) {
  if (!stepMm.isFinite || stepMm <= 0) {
    throw ArgumentError.value(stepMm, 'stepMm', 'must be finite and positive');
  }
  return Vector2(
    page.originX + ((world.x - page.originX) / stepMm).roundToDouble() * stepMm,
    page.originY + ((world.y - page.originY) / stepMm).roundToDouble() * stepMm,
  );
}
```

Exports: `src/document/page_geometry.dart`, `src/geometry/grid_scale.dart`.

- [ ] **Step 4: Run to pass.** Then the `jet_cad_2d` gate line. If
  `formatLength(311.15, inches)` gives `12.2500…` trimmed wrong, the fault
  is in `_trim` — fix it, not the expectation.
- [ ] **Step 5: Commit** — `feat(engine): page geometry, the grid ladder,
  formatLength, snapToGrid`.

---

### Task 5: `chrome_style.dart`, `page_fit.dart`, `PageNotifier`, the fixture

**Files:**
- Create: `lib/src/chrome_style.dart`, `lib/src/page_fit.dart`,
  `lib/src/page_notifier.dart`, `test/support/page_fixture.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (three exports now, six by Task 8)
- Test: `test/page_fit_test.dart`, `test/page_notifier_test.dart`

- [ ] **Step 1: The fixture.**

```dart
// test/support/page_fixture.dart
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The spec's standard fixture: an off-origin A4 landscape at 1:50 in
/// metres, partly visible under a zoomed, panned camera.
PageComponent standardPage() =>
    PageComponent(originX: 7350, originY: -1230);

CameraController standardCamera() => CameraController(ViewportTransform(
    worldToScreenMatrix:
        const Transform2(0.137, 0, 0, -0.137, -611.5, 412.25)));

const Size kChromeSize = Size(800, 600);

DraftDocument documentWithPage([PageComponent? page]) {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, page ?? standardPage()));
  return doc;
}
```

- [ ] **Step 2: Write the failing tests.**

```dart
// test/page_fit_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';

void main() {
  test('fitToPage fits the sheet rect, not the extents', () {
    // M-04k's render half.
    final page = standardPage();
    final fitted = fitToPage(page, kChromeSize);
    final expected = ViewportTransform.fit(sheetWorldRect(page), kChromeSize);
    expect(fitted.scale, closeTo(expected.scale, 1e-12));
    final centre = sheetWorldRect(page).center;
    final s = fitted.worldToScreen(centre);
    expect(s.x, closeTo(400, 1e-6));
    expect(s.y, closeTo(300, 1e-6));
    expect(fitted.worldToScreen(Vector2(page.originX, page.originY)).y,
        greaterThan(300), reason: 'y flips: the bottom-left is below centre');
  });
}
```

```dart
// test/page_notifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/page_fixture.dart';

void main() {
  test('seeds from the document before any event', () {
    // M-04u.
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    expect(n.value, standardPage());
  });

  test('follows apply, undo and redo through the stream', () async {
    // M-04l (undo ignored).
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    final seen = <PageComponent?>[];
    n.addListener(() => seen.add(n.value));
    final edited = standardPage().copyWith(pageBreaks: true);

    doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle, edited));
    await Future<void>.delayed(Duration.zero);
    doc.commands.undo();
    await Future<void>.delayed(Duration.zero);
    doc.commands.redo();
    await Future<void>.delayed(Duration.zero);

    expect(seen, [edited, standardPage(), edited]);
  });

  test('an unrelated edit and an equal value do not notify', () async {
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    var notified = 0;
    n.addListener(() => notified++);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage()));  // equal value
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: doc.handleSeed.next(), parent: doc.rootHandle,
        transform: Transform2.translation(5, 5), children: const [])));
    await Future<void>.delayed(Duration.zero);
    expect(notified, 0);
  });

  test('a load re-reads, and dispose stops listening', () async {
    final doc = documentWithPage();
    final n = PageNotifier(doc);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage().copyWith(gridVisible: false)));
    await Future<void>.delayed(Duration.zero);
    doc.commands.notifyLoaded();
    await Future<void>.delayed(Duration.zero);
    expect(n.value!.gridVisible, isFalse);
    n.dispose();
    expect(() => doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, standardPage())), returnsNormally);
  });
}
```

- [ ] **Step 3: Run to fail.**

- [ ] **Step 4: Implement.**

```dart
// lib/src/chrome_style.dart
import 'dart:ui' show Color;

/// Thickness of each ruler bar and the corner box, logical pixels.
const double kRulerThickness = 24.0;
const double kMajorTickPixels = 12.0;
const double kMinorTickPixels = 6.0;

/// Below this on-screen sheet size the page-break tiling is not drawn: the
/// bound at extreme zoom-out (spec D8).
const double kBreaksMinSheetPixels = 16.0;

const Color kSheetEdgeColor = Color(0xFF9E9E9E);
const Color kMajorGridColor = Color(0x33000000);
const Color kMinorGridColor = Color(0x14000000);
const Color kPageBreakColor = Color(0xFF3366CC);
const Color kRulerBackground = Color(0xFFF2F2F2);
const Color kRulerInk = Color(0xFF444444);
const Color kRulerPointer = Color(0xFFE53935);
const double kRulerLabelSize = 10.0;
```

```dart
// lib/src/page_fit.dart
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'viewport_transform.dart';

/// The camera that shows the whole sheet with `fit`'s 5 % margin (spec D4).
ViewportTransform fitToPage(PageComponent page, Size viewport) =>
    ViewportTransform.fit(sheetWorldRect(page), viewport);
```

```dart
// lib/src/page_notifier.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// The document's page as a listenable (spec D10): seeded in the
/// constructor, re-read on any change that touches the root, on a load and
/// on a purge. `ValueNotifier` skips the notification when the value is
/// `==`, so an unrelated root edit costs its listeners nothing.
class PageNotifier extends ValueNotifier<PageComponent?> {
  PageNotifier(this.document)
      : super(document.components.get<PageComponent>(document.rootHandle)) {
    _subscription = document.changes.listen(_onChange);
  }

  final DraftDocument document;
  late final StreamSubscription<DocChange> _subscription;

  void _onChange(DocChange change) {
    final root = document.rootHandle;
    final refresh = switch (change) {
      CommandApplied(:final touched) ||
      CommandUndone(:final touched) ||
      CommandRedone(:final touched) =>
        touched.contains(root),
      DocumentLoaded() || DocumentPurged() => true,
    };
    if (refresh) value = document.components.get<PageComponent>(root);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
```

Exports: `src/chrome_style.dart`, `src/page_fit.dart`,
`src/page_notifier.dart`.

- [ ] **Step 5: Run to pass**, then the `jet_cad_2d_flutter` gate line.
- [ ] **Step 6: Commit** — `feat(render): chrome style, fitToPage,
  PageNotifier`.

---

### Task 6: `PageChromePainter`

**Files:**
- Create: `lib/src/page_chrome_painter.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`
- Test: `test/page_chrome_painter_test.dart`

**Interfaces:**
- Consumes: `GridScale.pick`, `sheetWorldRect`, `PageNotifier`,
  `CameraController`, `chrome_style.dart`.
- Produces: `PageChromePainter({camera, page, repaint, onPaintForTest})`,
  `debugLastMajorCount`, `debugLastMinorCount`, `debugLastBreakCount`
  (test-only counters, reset per paint).

- [ ] **Step 1: Write the failing tests.**

```dart
// test/page_chrome_painter_test.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';
import 'support/spy_canvas.dart';

/// The metric ladder, written out so the oracle shares nothing with
/// `GridScale.pick` (spec, Differential check).
const List<double> kLadderTable = [
  0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000,
  10000, 20000, 50000, 100000, 200000, 500000, 1000000, 2000000, 5000000,
  10000000, 20000000, 50000000,
];

double? oracleMajor(double pxPerMm) {
  for (final step in kLadderTable) {
    if (step * pxPerMm >= 64) return step;
  }
  return null;
}

/// Major-line screen x positions, brute force: every lattice x inside the
/// visible-and-sheet range.
List<double> oracleMajorXs(ViewportTransform cam, PageComponent page, Size size) {
  final step = oracleMajor(cam.scale);
  if (step == null) return const [];
  final sheet = sheetWorldRect(page);
  final visible = cam.visibleWorld(size);
  final minX = math.max(sheet.minX, visible.minX);
  final maxX = math.min(sheet.maxX, visible.maxX);
  if (minX > maxX) return const [];
  final out = <double>[];
  for (var i = ((minX - page.originX) / step).ceil();
      i <= ((maxX - page.originX) / step).floor();
      i++) {
    out.add(cam.worldToScreen(Vector2(page.originX + i * step, 0)).x);
  }
  return out;
}

(PageChromePainter, ValueNotifier<PageComponent?>, CameraController) rig(
    {PageComponent? page, CameraController? camera}) {
  final n = ValueNotifier<PageComponent?>(page ?? standardPage());
  final cam = camera ?? standardCamera();
  return (PageChromePainter(camera: cam, page: n), n, cam);
}

/// Vertical lines' x from a recorded `drawRawPoints` list: every pair
/// (x0, y0, x1, y1) with x0 == x1.
List<double> verticalXs(Float32List points) => [
      for (var i = 0; i + 3 < points.length; i += 4)
        if (points[i] == points[i + 2]) points[i].toDouble(),
    ];

void main() {
  test('draws the sheet in its colour under everything', () {
    final (painter, _, _) = rig(page: standardPage().copyWith(background: 0xFFFAF6EC));
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final rects = canvas.named('drawRect').toList();
    expect(rects.first.color, const Color(0xFFFAF6EC));
    expect(canvas.calls.first.name, 'drawRect');
  });

  test('major lines sit where the oracle says, anchored at the sheet corner', () {
    // M-04f and M-04c on one camera; the seeded sweep below is the check.
    final (painter, _, cam) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final raw = canvas.named('drawRawPoints').toList();
    expect(raw, hasLength(2), reason: 'minors then majors');
    final majors = verticalXs(raw.last.args[1] as Float32List);
    final expected = oracleMajorXs(cam.value, standardPage(), kChromeSize);
    expect(majors.length, expected.length);
    for (var i = 0; i < majors.length; i++) {
      expect(majors[i], closeTo(expected[i], 1e-3));
    }
  });

  test('differential: fifty seeded cameras agree with the literal-ladder oracle', () {
    final random = math.Random(0x5EED0004);
    for (var trial = 0; trial < 50; trial++) {
      final scale = math.pow(10.0, -3 + random.nextDouble() * 5).toDouble();  // [1e-3, 1e2]
      final tx = -5000 + random.nextDouble() * 10000;
      final ty = -5000 + random.nextDouble() * 10000;
      final cam = CameraController(ViewportTransform(
          worldToScreenMatrix: Transform2(scale, 0, 0, -scale, tx, ty)));
      final (painter, _, _) = rig(camera: cam);
      final canvas = SpyCanvas();
      painter.paint(canvas, kChromeSize);
      final raw = canvas.named('drawRawPoints').toList();
      final majors = raw.isEmpty ? const <double>[] : verticalXs(raw.last.args[1] as Float32List);
      final expected = oracleMajorXs(cam.value, standardPage(), kChromeSize);
      expect(majors.length, expected.length, reason: 'trial $trial, scale $scale');
      for (var i = 0; i < majors.length; i++) {
        expect(majors[i], closeTo(expected[i], 1e-3), reason: 'trial $trial');
      }
    }
  });

  test('the point list is exactly four numbers per line', () {
    // M-04v.
    final (painter, _, _) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    for (final call in canvas.named('drawRawPoints')) {
      final points = call.args[1] as Float32List;
      expect(points.length % 4, 0);
      expect(points.length ~/ 4, anyOf(painter.debugLastMajorCount, painter.debugLastMinorCount));
    }
  });

  test('minors that coincide with a major are not drawn twice', () {
    // Ruling 04-3. Every minor x must differ from every major x.
    final (painter, _, _) = rig();
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    final raw = canvas.named('drawRawPoints').toList();
    final minors = verticalXs(raw.first.args[1] as Float32List);
    final majors = verticalXs(raw.last.args[1] as Float32List);
    for (final m in minors) {
      for (final j in majors) {
        expect((m - j).abs(), greaterThan(1e-3));
      }
    }
    expect(minors, isNotEmpty);
  });

  test('bounded at kMinScale, kMaxScale, and the intersection is the range', () {
    // Invariant 2, M-04t. At 0.001 px/mm the sheet is 14.85 px wide and
    // pick is null: nothing. At 100 px/mm the sheet is 1.485e6 px wide;
    // over the 800 px viewport the bound is 800/64 + 2 = 14 majors and
    // 800/8 + 2 = 102 minors per axis.
    for (final scale in [0.001, 100.0]) {
      final cam = CameraController(ViewportTransform(
          worldToScreenMatrix: Transform2(scale, 0, 0, -scale,
              -7350 * scale + 100, 1230 * scale + 500)));
      final (painter, _, _) = rig(camera: cam);
      painter.paint(SpyCanvas(), kChromeSize);
      expect(painter.debugLastMajorCount, lessThanOrEqualTo(2 * (800 / 64 + 2)));
      expect(painter.debugLastMinorCount, lessThanOrEqualTo(2 * (800 / 8 + 2)));
    }
  });

  test('page breaks tile outward and vanish under a 16 px sheet', () {
    // M-04m. Standard camera: sheet 14 850 mm → 2034 px wide; the visible
    // world spans 800 / 0.137 = 5839 mm, so at most two vertical break
    // lines and two horizontal ones intersect it.
    final (painter, _, _) = rig(page: standardPage().copyWith(pageBreaks: true));
    painter.paint(SpyCanvas(), kChromeSize);
    expect(painter.debugLastBreakCount, inInclusiveRange(1, 4));
    final tiny = CameraController(ViewportTransform(
        worldToScreenMatrix: const Transform2(0.001, 0, 0, -0.001, 400, 300)));
    final (small, _, _) = rig(page: standardPage().copyWith(pageBreaks: true), camera: tiny);
    small.paint(SpyCanvas(), kChromeSize);
    expect(small.debugLastBreakCount, 0);
  });

  test('a chrome toggle through the log adds no entity and rebuilds no index', () {
    // Invariant 1 / criterion 7, end to end: the painter is a listener,
    // not a writer.
    final doc = documentWithPage();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final n = PageNotifier(doc);
    addTearDown(n.dispose);
    final painter = PageChromePainter(camera: standardCamera(), page: n);
    final entities = doc.entities.liveCount;
    final rebuilds = index.rebuildCount;
    for (final flag in [true, false, true]) {
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, standardPage().copyWith(gridVisible: flag, pageBreaks: !flag)));
      painter.paint(SpyCanvas(), kChromeSize);
    }
    doc.commands.undo();
    doc.commands.redo();
    expect(doc.entities.liveCount, entities);
    expect(index.rebuildCount, rebuilds);
  });

  test('null page and zero size paint nothing', () {
    final (painter, n, _) = rig();
    n.value = null;
    final canvas = SpyCanvas();
    painter.paint(canvas, kChromeSize);
    expect(canvas.calls, isEmpty);
    n.value = standardPage();
    painter.paint(canvas, Size.zero);
    expect(canvas.calls, isEmpty);
  });
}
```

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/src/page_chrome_painter.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'chrome_style.dart';
import 'viewport_transform.dart';

/// The sheet, the grid and the page breaks, under `DraftCanvas` in its own
/// `RepaintBoundary` (spec D8). Everything it hands `dart:ui` is a screen
/// coordinate; the grid is enumerated over `visibleWorld ∩ sheet`, never
/// over the sheet, which is what bounds the line count at every zoom.
class PageChromePainter extends CustomPainter {
  PageChromePainter({
    required this.camera,
    required this.page,
    super.repaint,
    this.onPaintForTest,
  });

  final CameraController camera;
  final ValueListenable<PageComponent?> page;
  final void Function()? onPaintForTest;

  /// Test-only, reset per paint.
  int debugLastMajorCount = 0;
  int debugLastMinorCount = 0;
  int debugLastBreakCount = 0;

  /// Grown once to the bound, reused; `sublistView`s of it reach the canvas.
  Float32List _buffer = Float32List(0);

  final Paint _sheetFill = Paint();
  final Paint _sheetEdge = Paint()
    ..color = kSheetEdgeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  final Paint _minor = Paint()
    ..color = kMinorGridColor
    ..strokeWidth = 1.0;
  final Paint _major = Paint()
    ..color = kMajorGridColor
    ..strokeWidth = 1.0;
  final Paint _breaks = Paint()
    ..color = kPageBreakColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    debugLastMajorCount = 0;
    debugLastMinorCount = 0;
    debugLastBreakCount = 0;
    final p = page.value;
    if (p == null || size.isEmpty) return;
    final cam = camera.value;
    final sheet = sheetWorldRect(p);
    final topLeft = cam.worldToScreen(Vector2(sheet.minX, sheet.maxY));
    final bottomRight = cam.worldToScreen(Vector2(sheet.maxX, sheet.minY));
    final sheetScreen =
        Rect.fromLTRB(topLeft.x, topLeft.y, bottomRight.x, bottomRight.y);

    _sheetFill.color = Color(p.background);
    canvas.drawRect(sheetScreen, _sheetFill);
    canvas.drawRect(sheetScreen, _sheetEdge);
    if (p.gridVisible) _paintGrid(canvas, size, cam, p, sheet, sheetScreen);
    if (p.pageBreaks) _paintBreaks(canvas, size, cam, p, sheet);
  }

  void _paintGrid(Canvas canvas, Size size, ViewportTransform cam,
      PageComponent p, Aabb2 sheet, Rect sheetScreen) {
    final scale =
        GridScale.pick(p.displayUnit, cam.scale, floorMm: p.gridStepMm);
    if (scale == null) return;
    final visible = cam.visibleWorld(size);
    // The iteration range. The clip below only trims the half-pixel at the
    // sheet's edge; at kMaxScale the sheet is 1.5e6 px wide and iterating
    // it would be fifteen thousand lines per axis (spec review B3).
    final minX = math.max(visible.minX, sheet.minX);
    final maxX = math.min(visible.maxX, sheet.maxX);
    final minY = math.max(visible.minY, sheet.minY);
    final maxY = math.min(visible.maxY, sheet.maxY);
    if (minX > maxX || minY > maxY) return;

    canvas.save();
    canvas.clipRect(sheetScreen);
    final minor = scale.minorMm;
    if (minor != null) {
      debugLastMinorCount = _lines(canvas, cam, p, minor, minX, minY, maxX,
          maxY, _minor, skipEvery: scale.divisor);
    }
    debugLastMajorCount =
        _lines(canvas, cam, p, scale.majorMm, minX, minY, maxX, maxY, _major);
    canvas.restore();
  }

  /// Vertical then horizontal lattice lines of [stepMm] anchored at the
  /// sheet origin inside the range; returns how many were drawn. A minor
  /// index that is a multiple of [skipEvery] coincides with a major and is
  /// left to the major pass (Ruling 04-3).
  int _lines(Canvas canvas, ViewportTransform cam, PageComponent p,
      double stepMm, double minX, double minY, double maxX, double maxY,
      Paint paint, {int skipEvery = 0}) {
    final i0 = ((minX - p.originX) / stepMm).ceil();
    final i1 = ((maxX - p.originX) / stepMm).floor();
    final j0 = ((minY - p.originY) / stepMm).ceil();
    final j1 = ((maxY - p.originY) / stepMm).floor();
    final columns = math.max(0, i1 - i0 + 1);
    final rows = math.max(0, j1 - j0 + 1);
    final needed = (columns + rows) * 4;
    if (_buffer.length < needed) _buffer = Float32List(needed);
    final top = cam.worldToScreen(Vector2(minX, maxY));
    final bottom = cam.worldToScreen(Vector2(maxX, minY));
    var n = 0;
    for (var i = i0; i <= i1; i++) {
      if (skipEvery > 0 && i % skipEvery == 0) continue;
      final x = cam.worldToScreen(Vector2(p.originX + i * stepMm, minY)).x;
      _buffer[n++] = x;
      _buffer[n++] = top.y;
      _buffer[n++] = x;
      _buffer[n++] = bottom.y;
    }
    for (var j = j0; j <= j1; j++) {
      if (skipEvery > 0 && j % skipEvery == 0) continue;
      final y = cam.worldToScreen(Vector2(minX, p.originY + j * stepMm)).y;
      _buffer[n++] = top.x;
      _buffer[n++] = y;
      _buffer[n++] = bottom.x;
      _buffer[n++] = y;
    }
    if (n == 0) return 0;
    canvas.drawRawPoints(
        PointMode.lines, Float32List.sublistView(_buffer, 0, n), paint);
    return n ~/ 4;
  }

  void _paintBreaks(Canvas canvas, Size size, ViewportTransform cam,
      PageComponent p, Aabb2 sheet) {
    final w = sheet.maxX - sheet.minX;
    final h = sheet.maxY - sheet.minY;
    if (w * cam.scale < kBreaksMinSheetPixels ||
        h * cam.scale < kBreaksMinSheetPixels) {
      return;
    }
    final visible = cam.visibleWorld(size);
    final path = Path();
    var count = 0;
    for (var i = ((visible.minX - p.originX) / w).ceil();
        i <= ((visible.maxX - p.originX) / w).floor();
        i++) {
      final x = cam.worldToScreen(Vector2(p.originX + i * w, 0)).x;
      _dash(path, Offset(x, 0), Offset(x, size.height));
      count++;
    }
    for (var j = ((visible.minY - p.originY) / h).ceil();
        j <= ((visible.maxY - p.originY) / h).floor();
        j++) {
      final y = cam.worldToScreen(Vector2(0, p.originY + j * h)).y;
      _dash(path, Offset(0, y), Offset(size.width, y));
      count++;
    }
    debugLastBreakCount = count;
    if (count > 0) canvas.drawPath(path, _breaks);
  }

  /// 6 px on, 4 px off, along a screen segment.
  static void _dash(Path path, Offset a, Offset b) {
    final length = (b - a).distance;
    if (length == 0) return;
    final dir = (b - a) / length;
    for (var t = 0.0; t < length; t += 10) {
      final s = a + dir * t;
      final e = a + dir * math.min(t + 6, length);
      path.moveTo(s.dx, s.dy);
      path.lineTo(e.dx, e.dy);
    }
  }

  @override
  bool shouldRepaint(PageChromePainter old) => false;
}
```

Export `src/page_chrome_painter.dart`.

- [ ] **Step 4: Run to pass.** The "sheet in its colour" test reads
  `RecordedCall.color`; `SpyCanvas` snapshots the paint's colour at call
  time, so the field `Paint` is fine. Then the gate line.
- [ ] **Step 5: Commit** — `feat(render): PageChromePainter — sheet, grid
  over the visible intersection, page breaks`.

---

### Task 7: `RulerPainter` and `RulerCornerPainter`

**Files:**
- Create: `lib/src/ruler_painter.dart`
- Modify: `lib/jet_cad_2d_flutter.dart`
- Test: `test/ruler_painter_test.dart`

**Interfaces:**
- Produces: `RulerAxis {horizontal, vertical}`, `RulerPainter({axis,
  camera, page, pointer, repaint})`, `RulerCornerPainter({page, repaint})`,
  `debugLastTicks` (a `List<(double screen, bool major, String? label)>`,
  test-only).

- [ ] **Step 1: Write the failing tests.**

```dart
// test/ruler_painter_test.dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';
import 'support/spy_canvas.dart';

void main() {
  const barH = Size(800, kRulerThickness);
  const barV = Size(kRulerThickness, 600);

  RulerPainter make(RulerAxis axis, {CameraController? camera, Offset? pointer}) =>
      RulerPainter(
        axis: axis,
        camera: camera ?? standardCamera(),
        page: ValueNotifier<PageComponent?>(standardPage()),
        pointer: ValueNotifier<Offset?>(pointer),
      );

  test('major ticks sit at worldToScreen of the lattice, labelled in metres', () {
    // M-04a (translation dropped), M-04b (scale dropped), M-04i (unit).
    // At 0.137 px/mm the major is 500 mm (Task 4). Page x = k·500 is world
    // x = 7350 + k·500; screen x = 0.137·world − 611.5.
    final painter = make(RulerAxis.horizontal);
    painter.paint(SpyCanvas(), barH);
    final majors = painter.debugLastTicks.where((t) => t.$2).toList();
    expect(majors, isNotEmpty);
    for (final tick in majors) {
      final pageX = (tick.$1 + 611.5) / 0.137 - 7350;
      expect(pageX / 500, closeTo(pageX / 500 == 0 ? 0 : (pageX / 500).roundToDouble(), 1e-6));
      expect(tick.$3, formatLength(pageX.roundToDouble(), DisplayUnit.meters));
    }
    final spacing = majors[1].$1 - majors[0].$1;
    expect(spacing, closeTo(500 * 0.137, 1e-6));
    expect(majors.first.$1, isNot(closeTo(0, 1)), reason: 'not at the bar edge by chance');
  });

  test('the left ruler reads upward', () {
    // M-04p: page y increases as screen y decreases.
    final painter = make(RulerAxis.vertical);
    painter.paint(SpyCanvas(), barV);
    final majors = painter.debugLastTicks.where((t) => t.$2).toList();
    expect(majors.length, greaterThan(1));
    final values = [for (final t in majors) double.parse(t.$3!.split(' ').first)];
    for (var i = 1; i < majors.length; i++) {
      expect(majors[i].$1, greaterThan(majors[i - 1].$1), reason: 'ticks ordered down the bar');
      expect(values[i], lessThan(values[i - 1]), reason: 'labels decrease downward');
    }
  });

  test('minor ticks are shorter and unlabelled', () {
    final painter = make(RulerAxis.horizontal);
    final canvas = SpyCanvas();
    painter.paint(canvas, barH);
    final minors = painter.debugLastTicks.where((t) => !t.$2);
    expect(minors, isNotEmpty);
    for (final t in minors) {
      expect(t.$3, isNull);
    }
    final lines = canvas.named('drawLine').toList();
    expect(lines.length, greaterThanOrEqualTo(painter.debugLastTicks.length));
  });

  test('the pointer marker is drawn at the pointer, and not without one', () {
    final painter = make(RulerAxis.horizontal, pointer: const Offset(123.4, 50));
    final canvas = SpyCanvas();
    painter.paint(canvas, barH);
    final marker = canvas.named('drawLine').where((c) => c.color == kRulerPointer).toList();
    expect(marker, hasLength(1));
    expect((marker.single.args[0] as Offset).dx, 123.4);
    final none = SpyCanvas();
    make(RulerAxis.horizontal).paint(none, barH);
    expect(none.named('drawLine').where((c) => c.color == kRulerPointer), isEmpty);
  });

  test('past the ladder top, only the bar and the pointer', () {
    final tiny = CameraController(ViewportTransform(
        worldToScreenMatrix: const Transform2(1e-9, 0, 0, -1e-9, 400, 300)));
    final painter = make(RulerAxis.horizontal, camera: tiny);
    painter.paint(SpyCanvas(), barH);
    expect(painter.debugLastTicks, isEmpty);
  });

  test('the corner shows the unit symbol', () {
    final n = ValueNotifier<PageComponent?>(standardPage().copyWith(displayUnit: DisplayUnit.feetInches));
    final painter = RulerCornerPainter(page: n);
    expect(painter.debugLastSymbol(), isNull);
    painter.paint(SpyCanvas(), const Size(kRulerThickness, kRulerThickness));
    expect(painter.debugLastSymbol(), 'ft');
  });
}
```

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/src/ruler_painter.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'camera_controller.dart';
import 'chrome_style.dart';

enum RulerAxis { horizontal, vertical }

/// One ruler bar (spec D11): ticks from the shared ladder, zero at the
/// sheet corner, labels in the display unit, a pointer marker. The bar is
/// co-extensive with the drawing area on its axis, so `size` on that axis
/// is the child's, and every tick is placed through `camera.worldToScreen`.
class RulerPainter extends CustomPainter {
  RulerPainter({
    required this.axis,
    required this.camera,
    required this.page,
    required this.pointer,
    super.repaint,
  });

  final RulerAxis axis;
  final CameraController camera;
  final ValueListenable<PageComponent?> page;
  final ValueListenable<Offset?> pointer;

  /// Test-only: (screen coordinate along the axis, isMajor, label).
  List<(double, bool, String?)> debugLastTicks = const [];

  final Paint _background = Paint()..color = kRulerBackground;
  final Paint _ink = Paint()
    ..color = kRulerInk
    ..strokeWidth = 1.0;
  final Paint _marker = Paint()
    ..color = kRulerPointer
    ..strokeWidth = 1.0;
  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr);

  bool get _horizontal => axis == RulerAxis.horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    final ticks = <(double, bool, String?)>[];
    canvas.drawRect(Offset.zero & size, _background);
    if (_horizontal) {
      canvas.drawLine(Offset(0, size.height - 0.5),
          Offset(size.width, size.height - 0.5), _ink);
    } else {
      canvas.drawLine(Offset(size.width - 0.5, 0),
          Offset(size.width - 0.5, size.height), _ink);
    }
    final p = page.value;
    final cam = camera.value;
    if (p != null && !size.isEmpty) {
      final scale =
          GridScale.pick(p.displayUnit, cam.scale, floorMm: p.gridStepMm);
      if (scale != null) {
        final step = scale.minorMm ?? scale.majorMm;
        final divisor = scale.divisor;
        // Ruling 04-4: the bar's own size gives the right range on its axis.
        final visible = cam.visibleWorld(size);
        final origin = _horizontal ? p.originX : p.originY;
        final lo = _horizontal ? visible.minX : visible.minY;
        final hi = _horizontal ? visible.maxX : visible.maxY;
        for (var i = ((lo - origin) / step).ceil();
            i <= ((hi - origin) / step).floor();
            i++) {
          final world = origin + i * step;
          final isMajor = i % divisor == 0;
          final screen = _horizontal
              ? cam.worldToScreen(Vector2(world, 0)).x
              : cam.worldToScreen(Vector2(0, world)).y;
          final label =
              isMajor ? formatLength(i * step, p.displayUnit) : null;
          ticks.add((screen, isMajor, label));
          _tick(canvas, size, screen, isMajor, label);
        }
      }
    }
    final pointerAt = pointer.value;
    if (pointerAt != null) {
      final s = _horizontal ? pointerAt.dx : pointerAt.dy;
      if (_horizontal) {
        canvas.drawLine(Offset(s, 0), Offset(s, size.height), _marker);
      } else {
        canvas.drawLine(Offset(0, s), Offset(size.width, s), _marker);
      }
    }
    debugLastTicks = ticks;
  }

  void _tick(Canvas canvas, Size size, double screen, bool isMajor, String? label) {
    final length = isMajor ? kMajorTickPixels : kMinorTickPixels;
    if (_horizontal) {
      canvas.drawLine(
          Offset(screen, size.height), Offset(screen, size.height - length), _ink);
      if (label != null) _label(canvas, label, Offset(screen + 2, 1), 0);
    } else {
      canvas.drawLine(
          Offset(size.width, screen), Offset(size.width - length, screen), _ink);
      if (label != null) _label(canvas, label, Offset(1, screen - 2), -math.pi / 2);
    }
  }

  void _label(Canvas canvas, String text, Offset at, double angle) {
    _text.text = TextSpan(
        text: text,
        style: const TextStyle(color: kRulerInk, fontSize: kRulerLabelSize));
    _text.layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    _text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RulerPainter old) => false;
}

/// The 24 × 24 box where the bars meet: the unit's symbol.
class RulerCornerPainter extends CustomPainter {
  RulerCornerPainter({required this.page, super.repaint});

  final ValueListenable<PageComponent?> page;
  final Paint _background = Paint()..color = kRulerBackground;
  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr);
  String? _lastSymbol;

  /// Test-only.
  String? debugLastSymbol() => _lastSymbol;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _background);
    final symbol = page.value?.displayUnit.symbol;
    _lastSymbol = symbol;
    if (symbol == null) return;
    _text.text = TextSpan(
        text: symbol,
        style: const TextStyle(color: kRulerInk, fontSize: kRulerLabelSize));
    _text.layout();
    _text.paint(canvas,
        Offset((size.width - _text.width) / 2, (size.height - _text.height) / 2));
  }

  @override
  bool shouldRepaint(RulerCornerPainter old) => false;
}
```

Export `src/ruler_painter.dart`.

- [ ] **Step 4: Run to pass.** `TextPainter.layout` in a plain `test`
  needs the Flutter binding: use `TestWidgetsFlutterBinding.ensureInitialized()`
  at the top of `main` in the test. Then the gate line.
- [ ] **Step 5: Commit** — `feat(render): RulerPainter and the corner`.

---

### Task 8: `RulerFrame`, and the exports

**Files:**
- Create: `lib/src/ruler_frame.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (last export)
- Test: `test/ruler_frame_test.dart`

- [ ] **Step 1: Write the failing tests.**

```dart
// test/ruler_frame_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';

void main() {
  Future<(RulerFrameState, int Function())> pump(WidgetTester tester,
      {CameraController? camera}) async {
    var childHovers = 0;
    final page = ValueNotifier<PageComponent?>(standardPage());
    final key = GlobalKey<RulerFrameState>();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 424,
          height: 324,
          child: RulerFrame(
            key: key,
            camera: camera ?? standardCamera(),
            page: page,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerHover: (_) => childHovers++,
              child: const SizedBox.expand(key: Key('child')),
            ),
          ),
        ),
      ),
    ));
    return (key.currentState!, () => childHovers);
  }

  testWidgets('the bars are co-extensive with the child and the corner is 24 x 24',
      (tester) async {
    await pump(tester);
    final child = tester.getRect(find.byKey(const Key('child')));
    expect(child.size, const Size(400, 300));
    final top = tester.getRect(find.byKey(const Key('ruler-top')));
    final left = tester.getRect(find.byKey(const Key('ruler-left')));
    final corner = tester.getRect(find.byKey(const Key('ruler-corner')));
    expect(top.left, child.left);
    expect(top.width, child.width);
    expect(top.height, kRulerThickness);
    expect(left.top, child.top);
    expect(left.height, child.height);
    expect(left.width, kRulerThickness);
    expect(corner.size, const Size(kRulerThickness, kRulerThickness));
  });

  testWidgets('hover feeds the pointer in child coordinates; exit clears it; '
      'the child still hears it', (tester) async {
    final (state, hovers) = await pump(tester);
    final child = tester.getRect(find.byKey(const Key('child')));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: child.topLeft + const Offset(50, 40));
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(child.topLeft + const Offset(51, 41));
    await tester.pump();
    expect(state.pointer.value, const Offset(51, 41));
    expect(hovers(), greaterThan(0));
    await gesture.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(state.pointer.value, isNull);
  });

  testWidgets('a major tick in the top bar sits at its world point\'s x in the child',
      (tester) async {
    // S10: the frame-level check the painter test cannot make.
    final (state, _) = await pump(tester);
    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('ruler-top')))
        .painter as RulerPainter;
    final major = painter.debugLastTicks.firstWhere((t) => t.$2);
    final pageX = (major.$1 + 611.5) / 0.137 - 7350;
    final world = Vector2(7350 + pageX.roundToDouble(), 0);
    final inChild = state.widget.camera.value.worldToScreen(world).x;
    expect(major.$1, closeTo(inChild, 1e-6));
  });
}
```

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/src/ruler_frame.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'camera_controller.dart';
import 'chrome_style.dart';
import 'ruler_painter.dart';

/// Two ruler bars and a corner around a drawing area (spec D11). Each bar
/// is exactly co-extensive with the child on its own axis. A translucent
/// `Listener` over the child feeds [RulerFrameState.pointer]; the child's
/// own listeners still receive every event.
class RulerFrame extends StatefulWidget {
  const RulerFrame({
    super.key,
    required this.camera,
    required this.page,
    required this.child,
  });

  final CameraController camera;
  final ValueListenable<PageComponent?> page;
  final Widget child;

  @override
  State<RulerFrame> createState() => RulerFrameState();
}

class RulerFrameState extends State<RulerFrame> {
  /// The pointer's position in the child's coordinates, or null.
  final ValueNotifier<Offset?> pointer = ValueNotifier<Offset?>(null);
  late final Listenable _repaint =
      Listenable.merge([widget.camera, widget.page, pointer]);
  late final Listenable _cornerRepaint = widget.page;

  @override
  void dispose() {
    pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SizedBox(
            height: kRulerThickness,
            child: Row(
              children: [
                SizedBox(
                  width: kRulerThickness,
                  height: kRulerThickness,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('ruler-corner'),
                      painter: RulerCornerPainter(
                          page: widget.page, repaint: _cornerRepaint),
                    ),
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('ruler-top'),
                      painter: RulerPainter(
                        axis: RulerAxis.horizontal,
                        camera: widget.camera,
                        page: widget.page,
                        pointer: pointer,
                        repaint: _repaint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: kRulerThickness,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('ruler-left'),
                      painter: RulerPainter(
                        axis: RulerAxis.vertical,
                        camera: widget.camera,
                        page: widget.page,
                        pointer: pointer,
                        repaint: _repaint,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MouseRegion(
                    onExit: (_) => pointer.value = null,
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerHover: (e) => pointer.value = e.localPosition,
                      onPointerMove: (e) => pointer.value = e.localPosition,
                      onPointerCancel: (_) => pointer.value = null,
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
```

Export `src/ruler_frame.dart`. The barrel now carries six new exports:
`chrome_style`, `page_fit`, `page_notifier`, `page_chrome_painter`,
`ruler_painter`, `ruler_frame`.

- [ ] **Step 4: Run to pass.** If the hover test's `moveTo` outside the
  frame does not fire `onExit` under the test binding, move to
  `child.topLeft - const Offset(30, 30)` (still inside the surface, outside
  the child) — the `MouseRegion` exit is what matters, not the surface
  edge. Then the gate line.
- [ ] **Step 5: Commit** — `feat(render): RulerFrame with a pointer
  notifier; exports`.

---

### Task 9: The app — register, place, fit to page, the tree, the zoom text

**Files:**
- Modify: `lib/startup_plan.dart`, `lib/planner_view.dart`, `lib/main.dart`
- Test: `test/startup_plan_test.dart`, `test/planner_shell_test.dart`

- [ ] **Step 1: Write the failing tests.** In `startup_plan_test.dart`:

```dart
  test('the startup plan carries an A4 landscape page at 1:50 centred on the '
      'plan, in millimetres, with no history', () {
    final doc = startupPlan(FlutterTextMeasurer());
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    expect(page.preset, SheetSize.a4);
    expect(page.orientation, PageOrientation.landscape);
    expect(page.scaleDenominator, 50);
    expect(page.displayUnit, DisplayUnit.meters);
    final rect = sheetWorldRect(page);
    final extents = doc.extents;
    expect(rect.center.x, closeTo(extents.center.x, 1e-9));
    expect(rect.center.y, closeTo(extents.center.y, 1e-9));
    expect(rect.minX, lessThan(kPlanOriginX));
    expect(rect.maxX, greaterThan(kPlanOriginX + kPlanWidth));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.commands.canUndo, isFalse, reason: 'Ruling 04-1');
  });
```

In `planner_shell_test.dart`, replace the fit test's expectation and add:

```dart
  testWidgets('the camera is fitted to the page at the drawing area\'s size',
      (tester) async {
    // M-04k. The drawing area is the RulerFrame's child, not the view.
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(DraftCanvas));
    final page = view.document.components.get<PageComponent>(view.document.rootHandle)!;
    final expected = fitToPage(page, size);
    expect(view.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(view.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
    final extentsFit = ViewportTransform.fit(view.document.extents, size);
    expect(view.camera.value.scale, isNot(closeTo(extentsFit.scale, 1e-9)));
  });

  testWidgets('the page chrome and the rulers are in the tree, under the canvas',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    expect(find.byType(RulerFrame), findsOneWidget);
    final chrome = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PageChromePainter);
    expect(chrome, findsOneWidget);
    expect(tester.getSize(chrome), tester.getSize(find.byType(DraftCanvas)));
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    expect(view.document.entities.liveCount, greaterThanOrEqualTo(500));
  });

  testWidgets('the zoom text reads the scale and the fitted zoom', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final page = view.document.components.get<PageComponent>(view.document.rootHandle)!;
    final zoom = zoomOf(view.camera.value.scale, page, kLogicalPixelsPerMm);
    final text = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(text, '1:50 · ${(zoom * 100).round()}%');
    view.camera.zoomAt(const Offset(100, 100), 2.0);
    await tester.pump();
    final after = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(after, '1:50 · ${(zoom * 2 * 100).round()}%');
  });
```

Update the existing `the camera is fitted to the real viewport on first
layout` test: its expected transform becomes `fitToPage(page, size)`.

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.** `startup_plan.dart`, at the end of
  `startupPlan` before `return doc;`:

```dart
  // Spec 04 D12 and Ruling 04-1: the page is document data, attached
  // through the log like everything else, and then the history is cleared
  // so a fresh document has none — as a loaded one has none.
  PageComponent.register(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  doc.commands.execute(
      SetComponentCommand<PageComponent>(doc.rootHandle, startupPage(doc.extents)));
  doc.commands.clearHistory();
  return doc;
```

and a top-level function:

```dart
/// A4 landscape at 1:50 in metres, centred on [extents] (spec D4).
PageComponent startupPage(Aabb2 extents) {
  final page = PageComponent();
  final w = page.effectiveWidthMm * page.scaleDenominator;
  final h = page.effectiveHeightMm * page.scaleDenominator;
  return page.copyWith(
      originX: extents.center.x - w / 2, originY: extents.center.y - h / 2);
}
```

`main.dart`: after `_document`, `late final PageNotifier _page =
PageNotifier(_document);`; the initial camera becomes
`fitToPage(_document.components.get<PageComponent>(_document.rootHandle)!,
const Size(1440, 900))`; dispose `_page` after `_selection`; pass `page:
_page` to `PlannerView`; in the top bar, after the status text, a second
`ListenableBuilder(listenable: Listenable.merge([_camera, _page]), builder:
(_, __) => Text(_zoomLine(), key: const Key('zoom-text')))` with:

```dart
  String _zoomLine() {
    final page = _page.value;
    if (page == null) return '';
    final zoom = zoomOf(_camera.value.scale, page, kLogicalPixelsPerMm);
    return '1:${_trimNumber(page.scaleDenominator)} · ${(zoom * 100).round()}%';
  }

  static String _trimNumber(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
```

`planner_view.dart`: a `page` constructor parameter (`PageNotifier`), and
the build becomes:

```dart
  @override
  Widget build(BuildContext context) => RulerFrame(
        camera: widget.camera,
        page: widget.page,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!_fitted &&
                constraints.biggest.width > 0 &&
                constraints.biggest.height > 0) {
              _fitted = true;
              final page = widget.page.value;
              // Spec D4/D11: the page when there is one, at the drawing
              // area's size — inside the frame, so the bars are excluded.
              widget.camera.value = page != null
                  ? fitToPage(page, constraints.biggest)
                  : ViewportTransform.fit(widget.document.extents, constraints.biggest);
            }
            return CameraGestureDetector(
              camera: widget.camera,
              policy: widget.policy,
              child: InteractionLayer(
                tools: widget.tools,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: PageChromePainter(
                            camera: widget.camera,
                            page: widget.page,
                            repaint: _chromeRepaint,
                          ),
                        ),
                      ),
                    ),
                    DraftCanvas(
                      document: widget.document,
                      index: widget.index,
                      camera: widget.camera,
                      tiles: false,
                    ),
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: SelectionOverlayPainter(
                            selection: widget.selection,
                            tools: widget.tools,
                            camera: widget.camera,
                            outlines: _outlines,
                            repaint: _repaint,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
```

with `late final Listenable _chromeRepaint = Listenable.merge([widget.camera,
widget.page]);`. The `Stack`'s size comes from `DraftCanvas`, its one
non-positioned child, exactly as before.

- [ ] **Step 4: Run to pass**: both app test files, then the full
  `floor_planner` line including both builds.
- [ ] **Step 5: Commit** — `feat(app): the page under the plan — startup
  page, fit to page, rulers and chrome in the tree, zoom text`.

---

### Task 10: `PagePanel`

**Files:**
- Create: `lib/page_panel.dart`
- Modify: `lib/main.dart` (the right slot)
- Test: `test/page_panel_test.dart`

- [ ] **Step 1: Write the failing tests.**

```dart
// test/page_panel_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:floor_planner/page_panel.dart';

void main() {
  (DraftDocument, PageNotifier) docWithPage() {
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, PageComponent(originX: 7350, originY: -1230)));
    doc.commands.clearHistory();
    return (doc, PageNotifier(doc));
  }

  Future<void> pump(WidgetTester tester, DraftDocument doc, PageNotifier page) =>
      tester.pumpWidget(MaterialApp(
          home: Scaffold(body: SizedBox(width: 280, child: PagePanel(document: doc, page: page)))));

  PageComponent pageOf(DraftDocument doc) =>
      doc.components.get<PageComponent>(doc.rootHandle)!;

  testWidgets('each toggle is exactly one command, and undo reverts the control',
      (tester) async {
    // M-04o.
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);
    for (final (key, read) in [
      ('page-grid', (PageComponent p) => p.gridVisible),
      ('page-snap', (PageComponent p) => p.snapToGrid),
      ('page-breaks', (PageComponent p) => p.pageBreaks),
    ]) {
      final before = read(pageOf(doc));
      final depth = doc.commands.undoDepth;
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(read(pageOf(doc)), !before, reason: key);
      expect(doc.commands.undoDepth, depth + 1, reason: key);
      doc.commands.undo();
      await tester.pump();
      expect(read(pageOf(doc)), before);
      expect(tester.widget<CheckboxListTile>(find.byKey(Key(key))).value, before);
    }
  });

  testWidgets('preset, orientation, unit and swatch each issue one command',
      (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);

    await tester.tap(find.byKey(const Key('page-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letter').last);
    await tester.pumpAndSettle();
    expect(pageOf(doc).preset, SheetSize.letter);
    expect(doc.commands.undoDepth, 1);

    await tester.tap(find.byKey(const Key('page-orientation-portrait')));
    await tester.pump();
    expect(pageOf(doc).orientation, PageOrientation.portrait);
    expect(doc.commands.undoDepth, 2);

    await tester.tap(find.byKey(const Key('page-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ft-in').last);
    await tester.pumpAndSettle();
    expect(pageOf(doc).displayUnit, DisplayUnit.feetInches);
    expect(doc.commands.undoDepth, 3);

    await tester.tap(find.byKey(const Key('page-swatch-3')));
    await tester.pump();
    expect(pageOf(doc).background, 0xFF1F3A5F);
    expect(doc.commands.undoDepth, 4);
  });

  testWidgets('the scale field commits on submit, refuses junk', (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    await pump(tester, doc, page);
    await tester.enterText(find.byKey(const Key('page-scale')), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(pageOf(doc).scaleDenominator, 100);
    expect(doc.commands.undoDepth, 1);
    await tester.enterText(find.byKey(const Key('page-scale')), '-3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(pageOf(doc).scaleDenominator, 100);
    expect(doc.commands.undoDepth, 1);
  });

  testWidgets('a custom size shows Custom', (tester) async {
    final (doc, page) = docWithPage();
    addTearDown(page.dispose);
    doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle,
        PageComponent(widthMm: 200, heightMm: 300)));
    await tester.pump();
    await pump(tester, doc, page);
    expect(find.text('Custom'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/page_panel.dart
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// The smallest panel that lets a human change the page (spec D12). Every
/// control executes one `SetComponentCommand`; the panel rebuilds from the
/// notifier, so undo moves the controls back. 12 replaces this.
class PagePanel extends StatefulWidget {
  const PagePanel({super.key, required this.document, required this.page});

  final DraftDocument document;
  final PageNotifier page;

  @override
  State<PagePanel> createState() => _PagePanelState();
}

class _PagePanelState extends State<PagePanel> {
  final TextEditingController _scale = TextEditingController();

  static const List<(String, int)> _swatches = [
    ('White', 0xFFFFFFFF),
    ('Ivory', 0xFFFAF6EC),
    ('Grey', 0xFFEDEDED),
    ('Blueprint', 0xFF1F3A5F),
  ];

  @override
  void initState() {
    super.initState();
    _syncScale();
    widget.page.addListener(_syncScale);
  }

  @override
  void dispose() {
    widget.page.removeListener(_syncScale);
    _scale.dispose();
    super.dispose();
  }

  void _syncScale() {
    final page = widget.page.value;
    if (page == null) return;
    final text = _number(page.scaleDenominator);
    if (_scale.text != text) _scale.text = text;
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  void _set(PageComponent next) => widget.document.commands.execute(
      SetComponentCommand<PageComponent>(widget.document.rootHandle, next));

  void _submitScale(PageComponent page, String text) {
    final value = double.tryParse(text.trim());
    if (value == null || !value.isFinite || value <= 0) {
      _syncScale();
      return;
    }
    if (value != page.scaleDenominator) _set(page.copyWith(scaleDenominator: value));
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<PageComponent?>(
        valueListenable: widget.page,
        builder: (context, page, _) {
          if (page == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text('Page', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<SheetSize?>(
                key: const Key('page-preset'),
                isExpanded: true,
                value: page.preset,
                items: [
                  for (final s in SheetSize.presets)
                    DropdownMenuItem(value: s, child: Text(s.name)),
                  if (page.preset == null)
                    const DropdownMenuItem<SheetSize?>(
                        value: null, enabled: false, child: Text('Custom')),
                ],
                onChanged: (s) {
                  if (s != null) _set(page.copyWith(widthMm: s.widthMm, heightMm: s.heightMm));
                },
              ),
              const SizedBox(height: 8),
              SegmentedButton<PageOrientation>(
                segments: const [
                  ButtonSegment(
                      value: PageOrientation.portrait,
                      label: Text('Portrait', key: Key('page-orientation-portrait'))),
                  ButtonSegment(
                      value: PageOrientation.landscape,
                      label: Text('Landscape', key: Key('page-orientation-landscape'))),
                ],
                selected: {page.orientation},
                onSelectionChanged: (s) => _set(page.copyWith(orientation: s.single)),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('page-scale'),
                controller: _scale,
                decoration: const InputDecoration(prefixText: '1:', labelText: 'Scale'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (text) => _submitScale(page, text),
              ),
              const SizedBox(height: 8),
              DropdownButton<DisplayUnit>(
                key: const Key('page-unit'),
                isExpanded: true,
                value: page.displayUnit,
                items: const [
                  DropdownMenuItem(value: DisplayUnit.millimeters, child: Text('mm')),
                  DropdownMenuItem(value: DisplayUnit.centimeters, child: Text('cm')),
                  DropdownMenuItem(value: DisplayUnit.meters, child: Text('m')),
                  DropdownMenuItem(value: DisplayUnit.inches, child: Text('in')),
                  DropdownMenuItem(value: DisplayUnit.feetInches, child: Text('ft-in')),
                ],
                onChanged: (u) {
                  if (u != null) _set(page.copyWith(displayUnit: u));
                },
              ),
              CheckboxListTile(
                key: const Key('page-grid'),
                title: const Text('Grid'),
                value: page.gridVisible,
                onChanged: (v) => _set(page.copyWith(gridVisible: v)),
              ),
              CheckboxListTile(
                key: const Key('page-snap'),
                title: const Text('Snap to grid'),
                value: page.snapToGrid,
                onChanged: (v) => _set(page.copyWith(snapToGrid: v)),
              ),
              CheckboxListTile(
                key: const Key('page-breaks'),
                title: const Text('Page breaks'),
                value: page.pageBreaks,
                onChanged: (v) => _set(page.copyWith(pageBreaks: v)),
              ),
              const SizedBox(height: 8),
              const Text('Paper'),
              Row(
                children: [
                  for (var i = 0; i < _swatches.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        key: Key('page-swatch-$i'),
                        onTap: () => _set(page.copyWith(background: _swatches[i].$2)),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(_swatches[i].$2),
                            border: Border.all(
                                color: page.background == _swatches[i].$2
                                    ? Colors.blue
                                    : Colors.black26,
                                width: page.background == _swatches[i].$2 ? 2 : 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      );
}
```

In `main.dart`, the `chrome-right` container gets `child:
PagePanel(document: _document, page: _page)`.

- [ ] **Step 4: Run to pass**, then the full `floor_planner` line with
  both builds. The `SegmentedButton` label keys: if `find.byKey` cannot tap
  the label, put the key on the `ButtonSegment`'s `icon` instead, or tap
  `find.text('Portrait')`; keep the assertion.
- [ ] **Step 5: Commit** — `feat(app): PagePanel — one command per
  control`.

---

### Task 11: Mutation testing, the two allocation gates, the greps

**Files:**
- Create: `docs/superpowers/notes/plan-04-mutation-log.md`

For each of the twenty-two mutants M-04a…v in the spec's table: `cp` the
file aside, apply the mutation by hand (one edit), run **only the named test
file**, paste the failing test's name and the summary line, restore with
`cp`, `diff` to confirm. Log format per mutant:

```
### M-04a — drop the camera translation from ruler tick placement
file: packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart, `cam.worldToScreen(Vector2(world, 0)).x` → `world * cam.scale`
test: CI=true flutter test test/ruler_painter_test.dart
result: FIRED — `major ticks sit where the oracle says` [E]; 1 failed
restored: diff clean
```

M-04g fires on `grid_scale_test`'s `minorMinPixels` test and on the
painter's `minor != null` branch (mutate `if (minor != null)` to `if (true)`
with `minor ?? scale.majorMm / scale.divisor` — the painter test's
coincidence check goes red). Record Ruling 04-7 beside it.

Then:

```sh
cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
cd ../jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart   # empty
git diff --stat main..HEAD -- packages/jet_cad_2d_flutter/lib/src/tile_cache.dart   # one hunk, the skip
grep -rn "dart:ui" packages/jet_cad_2d/lib/src/document/page_component.dart packages/jet_cad_2d/lib/src/document/page_geometry.dart packages/jet_cad_2d/lib/src/geometry/grid_scale.dart   # nothing
```

Paste all outputs into the log's tail. Commit the log.

---

### Task 12: Gates, the results note, the spec amendments, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-22-plan-04-results.md`
- Modify: the spec (amendments at execution: Rulings 04-1, 04-2, 04-7 as
  "Amended at execution (Plan 04)" sentences at D12, D10 and D7),
  `roadmap/04-page-grid-rulers.md` (status line), `roadmap/00-README.md`
  (status row), `STATUS.md` (a Plan 04 section, the header, the Resume
  paragraph)

- [ ] **Step 1: The gate commands, all four lines**, outputs pasted into
  the results note with exit codes; the five golden failures named.
- [ ] **Step 2: The results note**: one row per exit criterion 1–16 with its
  witness; criterion 16 (the human's look, macOS + Chrome + Firefox) marked
  **OWED — not looked at; the human looks after this branch is presented**,
  with the seven items itemised per platform; the `header.units` non-goal
  stated in as many words; the adaptive-snap-follows-zoom sentence from D6;
  the differential's seed and trial count.
- [ ] **Step 3: STATUS and roadmap** as 02 did (`STATUS.md`'s Plan 02
  section is the template).
- [ ] **Step 4: Commit**, archive the ledger as the branch's last commit,
  then hand to `superpowers:finishing-a-development-branch`.

---

## Exit gate

The spec's sixteen criteria, each with the task that witnesses it:

| # | witness |
|---|---|
| 1 | Task 3 test 1 |
| 2 | Task 3 test 2 |
| 3 | Task 2 test 1 (undo/redo by value); Task 10 test 1 |
| 4 | Task 7 test 1 |
| 5 | Task 4 `pick` tests; Task 6 coincidence test |
| 6 | Task 6 bounded and breaks tests |
| 7 | Task 2 test 1; Task 6 chrome-toggle test |
| 8 | Task 11 |
| 9 | Task 4 snap tests |
| 10 | Task 4 format test; Task 7 upward test |
| 11 | Task 4 zoom test; Task 9 fit test |
| 12 | Task 6 differential |
| 13 | Task 10 |
| 14 | Task 11's log, twenty-two entries |
| 15 | Task 12 |
| 16 | OWED to the human, Task 12's note |

## Self-review

- **Spec coverage:** D1 → Tasks 1, 4, 9; D2 → Task 6 breaks; D3 → Task 1;
  D4 → Tasks 4, 5, 9; D5 → Tasks 4, 7; D6 → Task 4; D7 → Task 4 (with
  Ruling 04-7's `minorMinPixels`); D8 → Task 6; D9 → Task 3; D10 → Task 5;
  D11 → Tasks 7, 8; D12 → Tasks 9, 10; D13 → Task 2. Every mutant in the
  spec's table has a task and a test above; M-04g's placement is the one
  Ruling 04-7 moves.
- **Placeholder scan:** nothing says TBD; Ruling 04-7 in Task 4 records
  the one place where the spec's own thresholds made a named mutant
  unreachable and how the plan makes it reachable.
- **Type consistency:** `GridScale.pick` returns `GridScale?` everywhere
  (Tasks 4, 6, 7); `divisor` is defined in Task 4 and used in 6 and 7;
  `PageNotifier` is a `ValueListenable<PageComponent?>` wherever a painter
  takes `page`; `fitToPage(page, Size)` in Tasks 5 and 9; `zoomOf(double,
  page, double)` in Tasks 4 and 9; the `capability` parameter name is the
  same in Tasks 2 and 3's `CommandApplied` literal.
