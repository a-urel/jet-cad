# The parametric layer (sub-project 06) — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a parametric object is a root-level `GroupNode` whose handle
carries a registered parametric `Component`. Every edit that changes its
parameters, its placement, its existence or its neighbourhood regenerates
the affected objects' child entities **inside the same undo step**. The app
gets a demo: a **Box** tool (key **B**) and a **Selection** panel section
that edits one box's width and height. Overlapping boxes show one merged
outline.

**Architecture:**
- **The engine** gains:
  - one slot on `CommandDispatcher`, `expander`, called in `execute` only;
  - `lib/src/parametric/`:
    - a `ParametricCatalog` of types;
    - a `ParametricSystem` that takes the slot and wraps each command in a
      single-use `ParametricEdit`;
    - a two-phase, parameters-only planner.

  Undo and redo replay a concrete `ParametricReplay` and never regenerate.
- **The render layer** gains one optional parameter on
  `PlacementTool.commit`.
- **The app** gains:
  - `BoxParams` and `BoxType`;
  - a `BoxTool`;
  - a `SelectionPanel`;
  - the install in the shell.

**Tech Stack:**
- Dart, and Flutter 3.47.2;
- `package:test`, `flutter_test` and `vector_math`;
- `jet_cad_2d` and `jet_cad_2d_flutter`.

No new dependency.

**Spec:** [docs/superpowers/specs/2026-09-24-parametric-layer-design.md](../specs/2026-09-24-parametric-layer-design.md),
**revision 2**. Read it whole before Task 1: the evidence of record, D1–D13,
the invariants, the testing rules, the mutant table and the fourteen exit
criteria.

**Its evidence:**
- [the spike findings](../notes/2026-09-24-parametric-spike-findings.md);
- [the r1 review](../notes/2026-09-24-parametric-layer-spec-review-r1.md).

The spike's throwaway code is on branch `spike/06-parametric`
(`packages/jet_cad_2d/test/spike06/`). **Read it, never merge it.**

**Roadmap input:** [roadmap/06-parametric-layer.md](../../../roadmap/06-parametric-layer.md).

**Branch:** `plan-06/parametric-layer`, cut from local `main` at the commit
that lands this plan.
- **This session's worktree hook refuses writes outside the session's own
  worktree**, so the branch is cut *inside* the session worktree:
  `git switch -c plan-06/parametric-layer main`.
- `origin/main` is stale. Never branch from it, and never push.
- **While the plan is in flight**, the ledger lives at
  `.superpowers/sdd/2026-09-24-parametric-layer/`.
- **As the branch's last commit before the merge**, the ledger is archived
  to `docs/superpowers/ledgers/2026-09-24-parametric-layer/`.

---

## Rulings made here rather than left to an implementer

Each ruling says what the plan does, why, and what it costs if wrong.
Those marked **(spec amended)** are written into the spec in Task 11 as
"Amended at execution (Plan 06)" paragraphs.

- **Ruling 06-1 — types live in a `ParametricCatalog` (spec amended, D3
  and D10).**
  - **The problem.** Revision 2 put `registerComponents` on
    `ParametricSystem`, whose constructor takes a document. But
    `DraftDocumentCodec.decode` *creates* the document, and it needs the
    factories *before* it loads components (`json_codec.dart:115`). A
    per-document system cannot exist yet at that point.
  - **The fix.** A document-free `ParametricCatalog` holds the types.
    - `catalog.register<T>(typeId, factory, type)` adds one.
    - `catalog.registerComponents` is what `decode` receives.
    - `ParametricSystem(document, catalog)` registers the catalog's
      components into that document and reads its types.
  - **Cost if wrong:** one indirection.
- **Ruling 06-2 — one library, two files.** `parametric_system.dart`
  declares `part 'regeneration.dart';`. The planner uses the private
  registration type, and a `part` keeps it private without widening the
  API. **Cost:** none.
- **Ruling 06-3 — the clean-up detaches only components of objects that
  were live before the edit (spec amended, D4 step 4).**
  - **Why.** Revision 2 says "every parametric component whose group node
    no longer exists". Taken literally, that would also detach a
    *misplaced* component on a leaf handle (D5) on every edit. A leaf
    handle has no tree node either.
  - **Cost if wrong:** a misplaced component survives a delete. It is
    already reported by `diagnostics()`.
- **Ruling 06-4 — a touched handle that *was* an object is a seed too.**
  An explicit `SetComponentCommand<T>(h, null)` turns a box back into a
  plain group. Its old neighbours must regrow, so `before.objects` handles
  seed as well as `after.objects` handles. **Cost:** none.
- **Ruling 06-5 — M-06b is "every sort removed" (spec amended, the mutant
  table).**
  - **Why.** The survey sorts the live objects, because it merges several
    types, and the closure sorts again. So the spec's "both" (planner and
    store) is three sorts here.
  - **The mutants.**
    - M-06b removes the survey's sort, the closure's sort and
      `ComponentStore.handles`' sort.
    - M-06b′ removes the closure's sort alone.
  - **Cost:** none.
- **Ruling 06-6 — M-06p's observable is child-handle stability, not raw
  bytes (spec amended).**
  - **Why.** A remove followed by an add reuses the freed slot, since the
    free list is LIFO (`slot_allocator.dart:52`). So the raw bytes can
    match while the child's handle changes.
  - **The kill.** P2 asserts that a width edit keeps every child handle.
  - **Cost:** none.
- **Ruling 06-7 — M-06f is fired as `ParametricSystem.install()`
  regenerating everything (spec amended).**
  - The stale-file test N9 turns red. The spike's probe answer, that
    regeneration on load is a no-op on a clean file, stands.
  - **Cost:** none.
- **Ruling 06-8 — where the transform mutants live.**
  - **M-06g (engine)** makes the system's `worldOf` return the identity.
    It is killed by the engine's relational tests.
  - **M-06g (app)** and **M-06o** live in `BoxType`, which is client code.
    They are killed by the app's rotated-pair tests.
  - **Cost:** none.
- **Ruling 06-9 — the test clients duplicate `BoxType`'s clipping on
  purpose.**
  - **Why.** The engine tests cannot import the app, and the fixture must
    not share a bug with the code it checks.
  - **Cost:** about sixty lines, twice.
- **Ruling 06-10 — new mutant M-06u:** `commit` ignores its `needs`
  argument. It is killed by `CN1` (Task 5).
- **Ruling 06-11 — `ParametricEdit`'s constructor is private.** Only the
  expander creates one, so "single-use" cannot be broken from outside. A
  test obtains one by calling `document.commands.expander!(command)`.
- **Ruling 06-13 — registration never re-registers (spec amended, D1).**
  - **The trap.** `ComponentRegistry.register<T>` *replaces* `T`'s store
    (`component.dart:74`), which wipes every component of that type. A
    second `ParametricSystem` over a loaded document would do exactly that.
    `drift()` checks and the app's SP5 build one.
  - **The fix.** The engine gains `bool ComponentRegistry.isRegistered<T>()`,
    a second small addition outside `parametric/`. The catalog registers a
    type only when it is not registered yet.
  - **Pinned by P10** and mutant **M-06v**.
  - **Cost:** one method.
- **Ruling 06-12 — the shell installs in `initState` and disposes in
  `dispose`.** A test that pumps `PlannerShell(document: doc)` installs on
  its own document. A second `install()` on one document throws, which is
  spec D2.

## Global Constraints

These are copied from `CLAUDE.md` and the spec.

- **Pure-Dart engine.** Nothing under `packages/jet_cad_2d` imports Flutter
  or `dart:ui`.
- **`unused_import` and `unused_element` are errors in
  `jet_cad_2d_flutter`** and in the app.
- **The frame path allocates nothing new.** `query_allocation_test.dart`
  and `paint_allocation_test.dart` stay green and **unedited**.
  Regeneration runs on edits only.
- **Draw order is ascending handle value.** A child keeps its handle across
  regeneration.
- **Geometric decisions use `Tolerance`; stored-value comparisons are exact
  `==`.**
  - The decisions: the inside test, the minimum piece length, and the reach
    overlap.
  - The stored values: the planner's payload comparison, and component
    equality.
- **World is root space.** Never read or write the root's transform.
- **Never commit `analysis_options.yaml`.** Run `git status --short` before
  every commit.
- **Never `git checkout --` a `.dart` file.** Back it up with `cp`, restore
  from that copy, and `diff` to prove the restore.
- **Never synthesize test output.** Paste what ran, with the summary line
  and the exit code.
- **Prefix every test command with `CI=true`.**
- **Code, comments and commit messages in English.**
- **Every commit ends with the trailer, exactly:** `Co-Authored-By: Claude
  Opus 5.5 <noreply@anthropic.com>`.
- **Format before the gate:** `dart format <files you touched>`.
- **Every fixture is off the identity.**
  - Engine objects sit at `atA = translation(7010, 3020) · rotation(π/6)`
    and relative to it. They are never at the origin, never at 0° or 90°,
    and never at scale 1 except where the group transform is rigid by
    design.
  - **Every relational fixture is rotated** (spec, Testing).
  - Relational tests assert the clip counts, **A 5 and B 3**, so a fixture
    that stops overlapping goes red.
- **Every task ends green.** The gate lines:

  ```sh
  cd packages/jet_cad_2d         && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter && CI=true flutter test ; flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/floor_planner          && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --release && flutter build web --release
  ```

  - **The standing exception:** the render layer exits 1 on the five
    `text_ladder_golden_test.dart` failures and on nothing else.
  - **Which lines each task runs:**
    - Tasks 1–4: the engine line, plus the render line, because the engine
      barrel grows.
    - Task 5: the render line.
    - Tasks 6–8: the app line as well.
    - Tasks 10–11: all four.
  - **Branch-point counts** at `6adf03d`: engine **911**; render layer
    **923** + 1 skip + the five goldens; harness **82**; app **46**.

## Review Focus

Five inputs the spec implies but names in no exit criterion. They are the
ones most likely to bite a person using this. Each has a test in the task
that owns the code.

1. **Rotating a box with the rotation grip while it overlaps a neighbour.**
   The rotate commits `Compound([TransformNodeCommand])`, labelled
   `Rotate`. Expected: one undo step, the neighbour re-clipped, `drift()`
   empty. Test: Task 3, `N13`.
2. **Selecting a box with a click and pressing Delete in the app.**
   Expected: the box and its component are gone, the neighbour regrows, and
   cmd+Z brings both back. Test: Task 7, `BX5`.
3. **A width edit that swallows a box whole inside its neighbour.**
   Expected: 0 children, and back to 4 on the next edit, with **new**
   handles. Test: Task 3, `N14`.
4. **cmd+Z after a panel edit.** Expected: the field shows the old width
   again. Test: Task 8, `SP6`.
5. **Two boxes sharing an edge exactly.** They are not neighbours, and both
   keep 4 lines. Test: Task 6, `BT4`.

---

## File structure

| file | responsibility |
|---|---|
| `packages/jet_cad_2d/lib/src/document/undo.dart` | **modify**: the `expander` slot (D2) |
| `packages/jet_cad_2d/lib/src/document/component.dart` | **modify**: `ComponentRegistry.isRegistered<T>()` (Ruling 06-13) |
| `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart` | **create**: `ParametricType`, `Generated`, `GeneratedGeometryError`, `ParametricView`, `ParametricCatalog`, `ParametricSystem`, `ParametricEdit`, `ParametricReplay` |
| `packages/jet_cad_2d/lib/src/parametric/regeneration.dart` | **create** (`part of`): the survey, the closure, the planner |
| `packages/jet_cad_2d/lib/jet_cad_2d.dart` | **modify**: one export |
| `packages/jet_cad_2d/test/document/expander_test.dart` | **create**: X1–X4 |
| `packages/jet_cad_2d/test/parametric/support/clients.dart` | **create**: the test types `ClipRect`, `SoftRect`, `Trip`, `Hinge` and their `ParametricType`s |
| `packages/jet_cad_2d/test/parametric/support/fixture.dart` | **create**: placements, `paramDoc`, `create`, `pair`, `kids`, `worldSegments`, `enc`, `canon`, `reload` |
| `packages/jet_cad_2d/test/parametric/regeneration_test.dart` | **create**: P1–P10 |
| `packages/jet_cad_2d/test/parametric/neighbourhood_test.dart` | **create**: N1–N14 |
| `packages/jet_cad_2d/test/parametric/guards_test.dart` | **create**: G1–G9 |
| `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart` | **modify**: `commit(…, {needs})` |
| `packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart` | **create**: CN1–CN2 |
| `apps/floor_planner/lib/parametric/box.dart` | **create**: `BoxParams`, `BoxType`, `boxCatalog`, `installBoxes` |
| `apps/floor_planner/lib/parametric/box_tool.dart` | **create**: `BoxTool` |
| `apps/floor_planner/lib/selection_panel.dart` | **create**: `SelectionPanel` |
| `apps/floor_planner/lib/main.dart` | **modify**: install, the Box tool, and the panel |
| `apps/floor_planner/lib/shortcut_guard.dart` | **modify**: add B |
| `apps/floor_planner/test/support/box_rig.dart` | **create**: the shell rig for box tests |
| `apps/floor_planner/test/box_test.dart` | **create**: BT1–BT6 |
| `apps/floor_planner/test/planner_box_test.dart` | **create**: BX1–BX6 |
| `apps/floor_planner/test/selection_panel_test.dart` | **create**: SP1–SP7 |
| `apps/floor_planner/test/startup_plan_test.dart` | **modify**: SP5 |
| `docs/superpowers/notes/plan-06-mutation-log.md` | **create** (Task 9) |
| `docs/superpowers/notes/2026-09-24-plan-06-results.md` | **create** (Task 11) |
| the spec, `roadmap/06-parametric-layer.md`, `roadmap/00-README.md`, `STATUS.md` | **modify** (Task 11) |

---

### Task 1: The dispatcher's `expander` slot

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/undo.dart` (`execute`, and
  a new field next to `onBeforeMutate`)
- Test: `packages/jet_cad_2d/test/document/expander_test.dart`

**Interfaces:**
- Produces: `DraftCommand Function(DraftCommand command)?
  CommandDispatcher.expander`. It is called once per `execute`, after
  `_checkNotDisposed` and before `_require`, and never in `undo` or
  `redo`.

- [ ] **Step 1: Write the failing tests.**

```dart
// packages/jet_cad_2d/test/document/expander_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Wraps a command: its own label, a declared capability set, and an
/// inverse that is also a `_Tagged`, so the test can see what history holds.
class _Tagged extends DraftCommand {
  _Tagged(this.inner, this.needs);
  final DraftCommand inner;
  final Set<Capability> needs;
  static int applies = 0;

  @override
  Capability get capability => Capability.structure;
  @override
  Set<Capability> get capabilities => needs;
  @override
  String get label => 'tagged ${inner.label}';
  @override
  CommandResult apply(CommandTarget target) {
    applies++;
    final r = inner.apply(target);
    return CommandResult(inverse: _Tagged(r.inverse, needs), touched: r.touched);
  }
}

AddEntityCommand line(DraftDocument doc) => addDrafted(doc, EntityKind.line,
    linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));

void main() {
  test('X1 execute runs the expanded command and reports it', () async {
    final doc = DraftDocument.empty();
    doc.commands.expander = (c) => _Tagged(c, {Capability.geometry});
    final seen = <DocChange>[];
    final sub = doc.commands.changes.listen(seen.add);
    doc.commands.execute(line(doc));
    await Future<void>.delayed(Duration.zero);
    final applied = seen.single as CommandApplied;
    expect(applied.label, 'tagged Add line');
    expect(applied.capability, Capability.structure);
    await sub.cancel();
  });

  test('X2 undo and redo never call the expander', () {
    final doc = DraftDocument.empty();
    var calls = 0;
    doc.commands.expander = (c) {
      calls++;
      return c;
    };
    doc.commands.execute(line(doc));
    doc.commands.undo();
    doc.commands.redo();
    doc.commands.undo();
    expect(calls, 1);
  });

  test('X3 permissions are checked on the expanded command', () {
    final doc = DraftDocument.empty();
    doc.commands.expander = (c) => _Tagged(c, {Capability.structure});
    doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: true, structure: false);
    // Built first: the handle is taken when the command is built.
    final add = line(doc);
    final before = DraftDocumentCodec.encodeToString(doc);
    _Tagged.applies = 0;
    expect(() => doc.commands.execute(add),
        throwsA(isA<PermissionDeniedError>()));
    expect(_Tagged.applies, 0);
    expect(doc.commands.undoDepth, 0);
    expect(DraftDocumentCodec.encodeToString(doc), before);
  });

  test('X4 history holds the expanded command\'s inverse', () {
    final doc = DraftDocument.empty();
    doc.commands.expander = (c) => c is _Tagged ? c : _Tagged(c, c.capabilities);
    doc.commands.execute(line(doc));
    _Tagged.applies = 0;
    doc.commands.undo();
    expect(_Tagged.applies, 1, reason: 'the inverse is a _Tagged');
  });
}
```

- [ ] **Step 2: Run the tests; they fail.**
  - Run: `cd packages/jet_cad_2d && CI=true dart test test/document/expander_test.dart`
  - Expected: a compile error, because `expander` does not exist.

- [ ] **Step 3: Implement.** In `undo.dart`, add after `onBeforeMutate`:

```dart
  /// Spec 06 D2: wraps every command [execute] runs — never [undo] or
  /// [redo], which replay concrete inverses. The parametric system takes
  /// this slot to fold a regeneration into the same undo step.
  ///
  /// Contract: a pure wrapper. It may return [command] unchanged, and it
  /// must not mutate anything itself. One slot, one owner: whoever takes it
  /// releases it only if it is still their own tear-off.
  DraftCommand Function(DraftCommand command)? expander;
```

Replace `execute`'s body from `_require(command);` onwards with:

```dart
    final effective = expander?.call(command) ?? command;
    _require(effective);
    // The inverse is pushed only after apply returns, so a command that
    // throws leaves no history behind: history matches what actually
    // mutated the target, never what merely attempted to.
    final result = effective.apply(target);
    _history.push(result.inverse);
    final change = CommandApplied(
        label: effective.label,
        touched: result.touched,
        capability: effective.capability);
    _changes.add(change);
    onAfterMutate?.call(change);
```

- [ ] **Step 4: Run the tests; they pass. Then run the engine line and the
  render line.**
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/document/undo.dart packages/jet_cad_2d/test/document/expander_test.dart
git commit -m "$(cat <<'EOF'
feat(engine): CommandDispatcher.expander, called in execute only (spec 06 D2)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: The parametric system and planner

**Files:**
- Create: `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`
- Create: `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/component.dart`: add
  `bool isRegistered<T extends Component>() => _stores.containsKey(T);` to
  `ComponentRegistry`, next to `register` (Ruling 06-13)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart`: add
  `export 'src/parametric/parametric_system.dart';` in alphabetical order
- Create: `packages/jet_cad_2d/test/parametric/support/clients.dart`
- Create: `packages/jet_cad_2d/test/parametric/support/fixture.dart`
- Test: `packages/jet_cad_2d/test/parametric/regeneration_test.dart`

**Interfaces:**
- Consumes: `CommandDispatcher.expander` (Task 1).
- Produces, used by Tasks 3, 4 and 6–8:
  - `abstract class ParametricType<T extends Component>`:
    - `Capability get editCapability`;
    - `Aabb2 reach(T params, Transform2 toWorld)`;
    - `List<Generated> generate(ParametricView view, Handle self)`.
  - `final class Generated(EntityKind kind, GeometryPayload payload)`,
    which throws `ArgumentError` for `fill`.
  - `class GeneratedGeometryError implements Exception { final Handle
    handle; }`.
  - `final class ParametricView`, with:
    - `U? paramsOf<U extends Component>(Handle)`;
    - `Transform2 toWorld(Handle)`;
    - `List<Handle> neighbours(Handle)`.
  - `class ParametricCatalog`, with:
    - `void register<T extends Component>(String typeId,
      ComponentFactory<T> factory, ParametricType<T> type)`;
    - `void registerComponents(ComponentRegistry registry)`.
  - `class ParametricSystem`, with:
    - the constructor `ParametricSystem(DraftDocument document,
      ParametricCatalog catalog)`;
    - `void install()` and `void dispose()`;
    - `List<Handle> drift()`;
    - `List<Diagnostic> diagnostics()`.
  - `final class ParametricEdit extends DraftCommand`, created only by the
    expander.
  - `final class ParametricReplay extends DraftCommand`.

- [ ] **Step 1: Write the test clients.**

```dart
// packages/jet_cad_2d/test/parametric/support/clients.dart
// Test-only parametric types. RectType duplicates the app's BoxType on
// purpose (Ruling 06-9): a fixture must not share a bug with the code it
// checks.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

abstract class RectParams implements Component {
  double get width;
  double get height;
}

final class ClipRect implements RectParams {
  const ClipRect(this.width, this.height);
  static const String id = 'test.clipRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static ClipRect fromJson(Map<String, Object?> j) => ClipRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is ClipRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

/// Same shape, but its parameter edits need only `components` (spec D7).
final class SoftRect implements RectParams {
  const SoftRect(this.width, this.height);
  static const String id = 'test.softRect';
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static SoftRect fromJson(Map<String, Object?> j) => SoftRect(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is SoftRect && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

enum TripMode { off, throwing, reentrant }

/// A rectangle whose generation can be made to throw, or to call back into
/// the dispatcher (G6–G8).
final class Trip implements RectParams {
  const Trip(this.width, this.height);
  static const String id = 'test.trip';
  static TripMode mode = TripMode.off;
  static DraftDocument? document;
  @override
  final double width;
  @override
  final double height;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};
  static Trip fromJson(Map<String, Object?> j) => Trip(
      (j['width']! as num).toDouble(), (j['height']! as num).toDouble());
  @override
  bool operator ==(Object o) =>
      o is Trip && o.width == width && o.height == height;
  @override
  int get hashCode => Object.hash(width, height);
}

RectParams? rectOf(ParametricView v, Handle h) =>
    v.paramsOf<ClipRect>(h) ?? v.paramsOf<SoftRect>(h) ?? v.paramsOf<Trip>(h);

List<Vector2> corners(RectParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// The open parameter interval of a->b strictly inside the convex quad [q],
/// or null. "Strictly": a segment lying on q's edge is outside.
(double, double)? insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
  const tol = Tolerance.standard;
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    area += u.x * v.y - v.x * u.y;
  }
  final s = area > 0 ? 1.0 : -1.0;
  final d = b - a;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    final e = v - u;
    final len = e.length;
    final f0 = s * (e.x * (a.y - u.y) - e.y * (a.x - u.x)) / len;
    final fd = s * (e.x * d.y - e.y * d.x) / len;
    if (fd.abs() <= tol.linear) {
      if (f0 <= tol.linear) return null;
      continue;
    }
    final t = (tol.linear - f0) / fd;
    if (fd > 0) {
      lo = math.max(lo, t);
    } else {
      hi = math.min(hi, t);
    }
  }
  return (hi - lo) * d.length > Tolerance.standard.linear ? (lo, hi) : null;
}

/// The rectangle [0,w]x[0,h] in local space, minus every neighbour's
/// interior: four edges in order, each split into ascending pieces.
List<Generated> clippedRect(ParametricView view, Handle self) {
  final p = rectOf(view, self)!;
  final toLocal = view.toWorld(self).invert();
  final quads = [
    for (final n in view.neighbours(self))
      if (rectOf(view, n) case final q?)
        [
          for (final c in corners(q))
            toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
        ],
  ];
  final c = corners(p);
  final out = <Generated>[];
  for (var i = 0; i < 4; i++) {
    final a = c[i], b = c[(i + 1) % 4];
    final len = (b - a).length;
    var keep = <(double, double)>[(0, 1)];
    for (final q in quads) {
      final inside = insideInterval(a, b, q);
      if (inside == null) continue;
      keep = [
        for (final (lo, hi) in keep) ...[
          if ((math.min(hi, inside.$1) - lo) * len > Tolerance.standard.linear)
            (lo, math.min(hi, inside.$1)),
          if ((hi - math.max(lo, inside.$2)) * len > Tolerance.standard.linear)
            (math.max(lo, inside.$2), hi),
        ],
      ];
    }
    for (final (lo, hi) in keep) {
      out.add(Generated(
          EntityKind.line, linePayload(a + (b - a) * lo, a + (b - a) * hi)));
    }
  }
  return out;
}

Aabb2 rectReach(RectParams p, Transform2 toWorld) =>
    Aabb2.fromPoints([for (final c in corners(p)) toWorld.transformPoint(c)]);

final class RectType<T extends RectParams> extends ParametricType<T> {
  const RectType(this.editCapability);
  @override
  final Capability editCapability;
  @override
  Aabb2 reach(T params, Transform2 toWorld) => rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) =>
      clippedRect(view, self);
}

final class TripType extends ParametricType<Trip> {
  const TripType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Trip params, Transform2 toWorld) => rectReach(params, toWorld);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    switch (Trip.mode) {
      case TripMode.off:
        break;
      case TripMode.throwing:
        throw StateError('tripwire');
      case TripMode.reentrant:
        Trip.document!.commands.execute(
            SetComponentCommand<Trip>(self, const Trip(10, 10)));
    }
    return clippedRect(view, self);
  }
}

/// Generates one LINE and one ARC, in an order its parameter flips (M-06m).
final class Hinge implements Component {
  const Hinge(this.flip);
  static const String id = 'test.hinge';
  final bool flip;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'flip': flip};
  static Hinge fromJson(Map<String, Object?> j) => Hinge(j['flip']! as bool);
  @override
  bool operator ==(Object o) => o is Hinge && o.flip == flip;
  @override
  int get hashCode => flip.hashCode;
}

final class HingeType extends ParametricType<Hinge> {
  const HingeType();
  @override
  Capability get editCapability => Capability.geometry;
  @override
  Aabb2 reach(Hinge params, Transform2 toWorld) => Aabb2.fromPoints([
        toWorld.transformPoint(Vector2(0, 0)),
        toWorld.transformPoint(Vector2(100, 100)),
      ]);
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final line = Generated(
        EntityKind.line, linePayload(Vector2(0, 0), Vector2(100, 0)));
    final arc =
        Generated(EntityKind.arc, arcPayload(Vector2(50, 50), 40, 0.3, 1.2));
    return view.paramsOf<Hinge>(self)!.flip ? [arc, line] : [line, arc];
  }
}

ParametricCatalog testCatalog() => ParametricCatalog()
  ..register<ClipRect>(
      ClipRect.id, ClipRect.fromJson, const RectType<ClipRect>(Capability.geometry))
  ..register<SoftRect>(SoftRect.id, SoftRect.fromJson,
      const RectType<SoftRect>(Capability.components))
  ..register<Trip>(Trip.id, Trip.fromJson, const TripType())
  ..register<Hinge>(Hinge.id, Hinge.fromJson, const HingeType());
```

- [ ] **Step 2: Write the fixture.**

```dart
// packages/jet_cad_2d/test/parametric/support/fixture.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'clients.dart';

/// A's placement, and everything relational is placed relative to it, so
/// the whole scene is rotated and off the origin.
final Transform2 atA =
    Transform2.translation(7010, 3020).multiply(Transform2.rotation(math.pi / 6));
Transform2 onA(double x, double y, double turn) => atA
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

/// B pierces A's long top edge from inside: A's top edge splits in two (A
/// has 5 children), B's bottom edge is swallowed (B has 3).
final Transform2 atB = onA(800, 700, 0.3);

/// Far from everything, still rotated.
final Transform2 parked =
    Transform2.translation(19000, 11000).multiply(Transform2.rotation(-0.7));

const Handle hA = Handle(1000);
const Handle hB = Handle(2000);

final ParametricCatalog catalog = testCatalog();

DraftDocument paramDoc() {
  final doc = DraftDocument.empty();
  ParametricSystem(doc, catalog).install();
  return doc;
}

DraftCommand create<T extends Component>(
        DraftDocument doc, Handle h, Transform2 at, T params) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: at, children: const [])),
      SetComponentCommand<T>(h, params),
    ], label: 'Add object');

void pair(DraftDocument doc, {bool bFirst = false}) {
  final a = create(doc, hA, atA, const ClipRect(2000, 1000));
  final b = create(doc, hB, atB, const ClipRect(400, 900));
  for (final c in bFirst ? [b, a] : [a, b]) {
    doc.commands.execute(c);
  }
}

/// [group]'s children, ascending.
List<Handle> kids(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Each LINE child of [group], in world coordinates.
List<List<double>> worldSegments(DraftDocument doc, Handle group) {
  final m = doc.tree.accumulatedTransform(group);
  return [
    for (final k in kids(doc, group))
      () {
        final g = doc.geometry
            .read(doc.entities.geomIndexAt(doc.entities.slotOf(k)!))
            .coords;
        final a = m.transformPoint(Vector2(g[0], g[1]));
        final b = m.transformPoint(Vector2(g[2], g[3]));
        return [a.x, a.y, b.x, b.y];
      }(),
  ];
}

String enc(DraftDocument d) => DraftDocumentCodec.encodeToString(d);

/// Entities sorted by handle: slot order is history, not state (spec D11).
String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

/// Decodes with the catalog's factories and installs a system.
DraftDocument reload(String s) {
  final doc = DraftDocumentCodec.decode(jsonDecode(s) as Map<String, Object?>,
      registerComponents: catalog.registerComponents);
  ParametricSystem(doc, catalog).install();
  return doc;
}
```

- [ ] **Step 3: Write the failing tests P1–P9.**

```dart
// packages/jet_cad_2d/test/parametric/regeneration_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

void expectWorld(DraftDocument doc, Handle g, Transform2 at, double w, double h) {
  final c = [Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
      .map(at.transformPoint)
      .toList();
  final got = worldSegments(doc, g);
  expect(got, hasLength(4));
  for (var i = 0; i < 4; i++) {
    final want = [c[i].x, c[i].y, c[(i + 1) % 4].x, c[(i + 1) % 4].y];
    for (var k = 0; k < 4; k++) {
      expect(got[i][k], closeTo(want[k], 1e-9), reason: 'edge $i coord $k');
    }
  }
}

void main() {
  test('P1 the first object in an empty document generates (M-06q)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    expectWorld(doc, hA, parked, 2000, 1000);
    for (final k in kids(doc, hA)) {
      expect(doc.entities.kindAt(doc.entities.slotOf(k)!), EntityKind.line);
    }
  });

  test('P2 a width edit regenerates in place, keeping every child handle '
      '(M-06p)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, parked, const ClipRect(2000, 1000)));
    final before = kids(doc, hA);
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(3100, 450)));
    expect(kids(doc, hA), before);
    expectWorld(doc, hA, parked, 3100, 450);
  });

  test('P3 edit plus regeneration is one undo step; undo and redo restore '
      'both, with the same handles (M-06c)', () {
    final doc = paramDoc();
    pair(doc);
    expect(kids(doc, hA), hasLength(5));
    expect(kids(doc, hB), hasLength(3));
    final before = canon(doc);
    final depth = doc.commands.undoDepth;
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)));
    expect(doc.commands.undoDepth, depth + 1);
    final after = canon(doc);
    final handlesAfter = [...kids(doc, hA), ...kids(doc, hB)];
    expect(after, isNot(before));
    doc.commands.undo();
    expect(canon(doc), before);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    doc.commands.redo();
    expect(canon(doc), after);
    expect([...kids(doc, hA), ...kids(doc, hB)], handlesAfter);
  });

  test('P4 the summary says geometry, so the index sees new children '
      '(M-06h)', () {
    final doc = paramDoc();
    final index = SpatialIndex(doc);
    // A at width 500 does not reach B; at 2000 it does, and both re-clip.
    doc.commands.execute(create(doc, hA, atA, const ClipRect(500, 1000)));
    doc.commands.execute(create(doc, hB, atB, const ClipRect(400, 900)));
    expect(kids(doc, hA), hasLength(4));
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2000, 1000)));
    expect(kids(doc, hA), hasLength(5));
    for (final g in [hA, hB]) {
      for (final s in worldSegments(doc, g)) {
        final mid = Vector2((s[0] + s[2]) / 2, (s[1] + s[3]) / 2);
        final found = <Handle>{};
        index.forEachInRect(
            Aabb2(mid - Vector2(0.5, 0.5), mid + Vector2(0.5, 0.5)),
            const QueryFilter.all(),
            (slot) => found.add(doc.entities.handleAt(slot)));
        expect(found.intersection(kids(doc, g).toSet()), isNotEmpty,
            reason: 'a child of ${g.toHex()} at $mid');
      }
    }
    index.dispose();
  });

  test('P5 children are matched by kind, then ordinal (M-06m)', () {
    final doc = paramDoc();
    const h = Handle(3000);
    doc.commands.execute(create(doc, h, parked, const Hinge(false)));
    final before = kids(doc, h);
    doc.commands.execute(SetComponentCommand<Hinge>(h, const Hinge(true)));
    expect(kids(doc, h), before);
    for (final k in kids(doc, h)) {
      final slot = doc.entities.slotOf(k)!;
      final p = doc.geometry.read(doc.entities.geomIndexAt(slot));
      switch (doc.entities.kindAt(slot)) {
        case EntityKind.line:
          expect((p.coords.length, p.scalars.length), (4, 0));
        case EntityKind.arc:
          expect(p.scalars.length, 3);
        default:
          fail('unexpected kind');
      }
    }
  });

  test('P6 fast path: no parametric object, no parametric command, the '
      'command is returned as is', () {
    final doc = paramDoc();
    final add = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));
    expect(identical(doc.commands.expander!(add), add), isTrue);
    final box = create(doc, hA, parked, const ClipRect(10, 10));
    expect(doc.commands.expander!(box), isA<ParametricEdit>());
  });

  test('P7 a fill cannot be generated', () {
    expect(
        () => Generated(EntityKind.fill, linePayload(Vector2(1, 2), Vector2(3, 4))),
        throwsArgumentError);
  });

  test('P8 one system per document; dispose releases only its own slot', () {
    final doc = DraftDocument.empty();
    final s = ParametricSystem(doc, catalog)..install();
    expect(() => ParametricSystem(doc, catalog).install(), throwsStateError);
    s.dispose();
    expect(doc.commands.expander, isNull);
    final t = ParametricSystem(doc, catalog)..install();
    s.dispose();
    expect(doc.commands.expander, isNotNull, reason: 's no longer owns it');
    t.dispose();
  });

  test('P9 a ParametricEdit applies once (spec D9)', () {
    final doc = paramDoc();
    final edit = doc.commands.expander!(
        create(doc, hA, parked, const ClipRect(10, 10)));
    edit.apply(doc);
    expect(() => edit.apply(doc), throwsStateError);
  });

  test('P10 a second system over a populated document keeps its '
      'components (Ruling 06-13, M-06v)', () {
    final doc = paramDoc();
    pair(doc);
    final before = enc(doc);
    final second = ParametricSystem(doc, catalog);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    expect(second.drift(), isEmpty);
    expect(enc(doc), before);
  });
}
```

- [ ] **Step 4: Run the tests; they fail.**
  - Run: `cd packages/jet_cad_2d && CI=true dart test test/parametric`
  - Expected: compile errors, because nothing in `parametric/` exists.

- [ ] **Step 5: Implement `parametric_system.dart`.**

```dart
// packages/jet_cad_2d/lib/src/parametric/parametric_system.dart
import '../core/diagnostic.dart';
import '../core/handle.dart';
import '../core/tolerance.dart';
import '../document/command.dart';
import '../document/commands.dart';
import '../document/component.dart';
import '../document/draft_document.dart';
import '../document/drafting.dart';
import '../document/node.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';

part 'regeneration.dart';

/// What one parametric type contributes (spec 06 D3). Behaviour lives here,
/// outside the document, which stays data only.
abstract class ParametricType<T extends Component> {
  const ParametricType();

  /// The capability a change of `T`'s value needs (spec D7).
  Capability get editCapability;

  /// The world region this object's generation depends on and affects,
  /// from parameters and the group's accumulated transform only.
  Aabb2 reach(T params, Transform2 toWorld);

  /// This object's entities, in the group's local space, from its own
  /// parameters and its neighbours' — never from generated geometry.
  List<Generated> generate(ParametricView view, Handle self);
}

/// One generated entity (spec D3). Never a fill: `SetEntityGeometryCommand`
/// rejects a fill's payload, and regions are out of scope.
final class Generated {
  Generated(this.kind, this.payload) {
    if (kind == EntityKind.fill) {
      throw ArgumentError.value(
          kind, 'kind', 'a fill cannot be generated (spec 06 D3)');
    }
  }

  final EntityKind kind;
  final GeometryPayload payload;
}

/// A direct edit of a generated entity (spec D6). Propagates like
/// `PermissionDeniedError`; the UI never offers the edit.
class GeneratedGeometryError implements Exception {
  const GeneratedGeometryError(this.handle);

  final Handle handle;

  @override
  String toString() => 'GeneratedGeometryError: ${handle.toHex()} is '
      'generated by a parametric object and cannot be edited directly';
}

/// Read-only access for [ParametricType.generate].
final class ParametricView {
  ParametricView._(this._target, this._neighbours);

  final CommandTarget _target;
  final Map<Handle, List<Handle>> _neighbours;

  U? paramsOf<U extends Component>(Handle h) => _target.components.get<U>(h);

  /// The accumulated transform: group-local to world.
  Transform2 toWorld(Handle h) => _worldOf(_target, h);

  /// Ascending handles of the objects whose reach overlaps [h]'s.
  List<Handle> neighbours(Handle h) => _neighbours[h] ?? const [];
}

/// The parametric types an application knows, independent of any document
/// (Ruling 06-1): `DraftDocumentCodec.decode` needs the factories before
/// the document exists.
class ParametricCatalog {
  final List<_Registration<Component>> _types = [];

  void register<T extends Component>(String typeId,
      ComponentFactory<T> factory, ParametricType<T> type) {
    _types.add(_Registration<T>(typeId, factory, type));
  }

  /// Pass as `DraftDocumentCodec.decode(…, registerComponents: …)`.
  void registerComponents(ComponentRegistry registry) {
    for (final t in _types) {
      t.registerInto(registry);
    }
  }
}

/// Regenerates parametric objects inside the edit that changes them (spec
/// 06 D1, D2, D4). One per document; takes the dispatcher's expander slot.
class ParametricSystem {
  ParametricSystem(this.document, this.catalog) {
    catalog.registerComponents(document.components);
  }

  final DraftDocument document;
  final ParametricCatalog catalog;

  bool _applying = false;

  List<_Registration<Component>> get _types => catalog._types;

  void install() {
    if (document.commands.expander != null) {
      throw StateError('the dispatcher already has an expander (spec 06 D2)');
    }
    document.commands.expander = _expand;
  }

  /// Releases the slot only if it is still this system's own tear-off.
  void dispose() {
    if (document.commands.expander == _expand) {
      document.commands.expander = null;
    }
  }

  /// Handles whose regeneration would change anything (spec D10). A dry
  /// run: reserves no handle, mutates nothing.
  List<Handle> drift() {
    final s = _survey(document, _types);
    final view = ParametricView._(document, s.neighbours);
    return [
      for (final h in s.objects.keys)
        if (_plan(document, [h], s, view).isNotEmpty) h,
    ];
  }

  /// One diagnostic per parametric component on a holder that is not a
  /// root-level group: it is not regenerated (spec D5).
  List<Diagnostic> diagnostics() => [
        for (final t in _types)
          for (final h in t.handles(document))
            if (!_isObject(document, _types, h))
              Diagnostic(
                severity: DiagnosticSeverity.warning,
                code: 'parametric.misplaced',
                message: '${t.typeId} on ${h.toHex()}, which is not a '
                    'root-level group, is not regenerated',
                handles: [h],
              ),
      ];

  DraftCommand _expand(DraftCommand command) {
    if (_applying) {
      throw StateError('execute() inside a parametric regeneration '
          '(spec 06 D2): generate() must not mutate');
    }
    if (!_types.any((t) => t.handles(document).isNotEmpty) &&
        !_setsParametric(command)) {
      return command;
    }
    return ParametricEdit._(this, command);
  }

  bool _setsParametric(DraftCommand c) => c is CompoundCommand
      ? c.children.any(_setsParametric)
      : _types.any((t) => t.owns(c));

  Set<Capability> _editCapabilitiesOf(DraftCommand c) => c is CompoundCommand
      ? {for (final child in c.children) ..._editCapabilitiesOf(child)}
      : {
          for (final t in _types)
            if (t.owns(c)) t.type.editCapability,
        };
}

/// An edit and its regeneration, as one command (spec D4). Created only by
/// the expander, once per `execute`, and applied once (spec D9).
final class ParametricEdit extends DraftCommand {
  ParametricEdit._(this._system, this.inner);

  final ParametricSystem _system;
  final DraftCommand inner;
  bool _applied = false;
  bool _geometryChanged = false;

  @override
  String get label => inner.label;

  /// The triggering edit's authority plus each parametric type's
  /// `editCapability`; the regeneration adds none of its own (spec D7).
  @override
  Set<Capability> get capabilities =>
      {...inner.capabilities, ..._system._editCapabilitiesOf(inner)};

  /// Read by the dispatcher after [apply]: `geometry` whenever the plan
  /// changed geometry, so the index does not skip it (spec D9).
  @override
  Capability get capability =>
      _geometryChanged && inner.capability.index < Capability.geometry.index
          ? Capability.geometry
          : inner.capability;

  @override
  CommandResult apply(CommandTarget target) {
    if (_applied) {
      throw StateError('a ParametricEdit applies once (spec 06 D9)');
    }
    _applied = true;
    _system._applying = true;
    try {
      return _run(this, target);
    } finally {
      _system._applying = false;
    }
  }
}

/// The concrete inverse of a [ParametricEdit]: undo and redo replay it and
/// never regenerate. Its own inverse is again a `ParametricReplay` with the
/// same [capabilities], so redo is authorised exactly as undo (spec D7).
final class ParametricReplay extends DraftCommand {
  ParametricReplay(this.replay, Set<Capability> capabilities)
      : capabilities = Set.unmodifiable(capabilities);

  final CompoundCommand replay;

  @override
  final Set<Capability> capabilities;

  @override
  Capability get capability => replay.capability;

  @override
  String get label => replay.label;

  @override
  CommandResult apply(CommandTarget target) {
    final r = replay.apply(target);
    return CommandResult(
      inverse: ParametricReplay(r.inverse as CompoundCommand, capabilities),
      touched: r.touched,
    );
  }
}

/// One registered type, with `T` captured so the untyped system can call it.
final class _Registration<T extends Component> {
  _Registration(this.typeId, this.factory, this.type);

  final String typeId;
  final ComponentFactory<T> factory;
  final ParametricType<T> type;

  /// Ruling 06-13: `register` replaces the store, wiping every component
  /// of `T`, so a type already registered is left alone.
  void registerInto(ComponentRegistry r) {
    if (!r.isRegistered<T>()) r.register<T>(typeId, factory);
  }
  bool has(CommandTarget t, Handle h) => t.components.get<T>(h) != null;
  Iterable<Handle> handles(CommandTarget t) => t.components.withComponent<T>();
  bool owns(DraftCommand c) => c is SetComponentCommand<T>;
  DraftCommand detach(Handle h) => SetComponentCommand<T>(h, null);
  Aabb2 reachOf(CommandTarget t, Handle h) =>
      type.reach(t.components.get<T>(h) as T, _worldOf(t, h));
  List<Generated> generate(ParametricView v, Handle h) => type.generate(v, h);
}
```

- [ ] **Step 6: Implement `regeneration.dart`.**

```dart
// packages/jet_cad_2d/lib/src/parametric/regeneration.dart
part of 'parametric_system.dart';

int _byValue(Handle a, Handle b) => a.value.compareTo(b.value);

/// Group-local to world for a parametric object. Mutant M-06g returns the
/// identity here.
Transform2 _worldOf(CommandTarget t, Handle h) =>
    t.tree.accumulatedTransform(h);

/// A root-level group carrying a registered parametric component (spec D5).
bool _isObject(
    CommandTarget t, List<_Registration<Component>> types, Handle h) {
  final node = t.tree[h];
  return node is GroupNode &&
      node.parent == t.tree.root &&
      types.any((r) => r.has(t, h));
}

/// Everything the planner reads about the parametric objects at one moment.
final class _Survey {
  _Survey(this.objects, this.neighbours, this.children, this.owned);

  /// Live objects, ascending, with their registration.
  final Map<Handle, _Registration<Component>> objects;

  /// Each object's neighbours, ascending (spec D3).
  final Map<Handle, List<Handle>> neighbours;

  /// Each object's children, ascending.
  final Map<Handle, List<Handle>> children;

  /// Every child of a live object, to its owner: the set G of spec D4.
  final Map<Handle, Handle> owned;
}

_Survey _survey(CommandTarget t, List<_Registration<Component>> types) {
  final found = <Handle, _Registration<Component>>{};
  for (final r in types) {
    for (final h in r.handles(t)) {
      if (_isObject(t, types, h)) found[h] = r;
    }
  }
  final order = found.keys.toList()..sort(_byValue);
  final objects = {for (final h in order) h: found[h]!};
  final reach = {for (final h in order) h: objects[h]!.reachOf(t, h)};
  const tol = Tolerance.standard;
  bool overlap(Aabb2 a, Aabb2 b) =>
      a.minX < b.maxX - tol.linear &&
      b.minX < a.maxX - tol.linear &&
      a.minY < b.maxY - tol.linear &&
      b.minY < a.maxY - tol.linear;
  final neighbours = {
    for (final a in order)
      a: [
        for (final b in order)
          if (b != a && overlap(reach[a]!, reach[b]!)) b,
      ],
  };
  final children = <Handle, List<Handle>>{};
  final owned = <Handle, Handle>{};
  for (final slot in t.entities.liveSlots) {
    final owner = t.entities.ownerAt(slot);
    if (!objects.containsKey(owner)) continue;
    final h = t.entities.handleAt(slot);
    (children[owner] ??= []).add(h);
    owned[h] = owner;
  }
  for (final list in children.values) {
    list.sort(_byValue);
  }
  return _Survey(objects, neighbours, children, owned);
}

/// Seeds plus their neighbours before and after, as a sorted list of live
/// objects (spec D4 step 6). One hop: generation reads parameters only.
List<Handle> _closure(Set<Handle> seeds, _Survey before, _Survey after) => {
      ...seeds,
      for (final s in seeds) ...?before.neighbours[s],
      for (final s in seeds) ...?after.neighbours[s],
    }.where(after.objects.containsKey).toList()
      ..sort(_byValue);

bool _samePayload(GeometryPayload a, GeometryPayload b) {
  if (a.coords.length != b.coords.length ||
      a.scalars.length != b.scalars.length) {
    return false;
  }
  for (var i = 0; i < a.coords.length; i++) {
    if (a.coords[i] != b.coords[i]) return false;
  }
  for (var i = 0; i < a.scalars.length; i++) {
    if (a.scalars[i] != b.scalars[i]) return false;
  }
  return true;
}

/// Plans, and does not apply, the commands that bring [closure] up to date
/// (spec D4 step 7). New children get **reserved** handles above the seed,
/// which is not advanced: `AddEntityCommand.apply` raises it when the add
/// lands.
List<DraftCommand> _plan(CommandTarget t, List<Handle> closure, _Survey s,
    ParametricView view) {
  var reserved = t.handleSeed.current.value;
  final out = <DraftCommand>[];
  for (final h in closure) {
    final generated = s.objects[h]!.generate(view, h);
    final byKind = <EntityKind, List<Handle>>{};
    for (final c in s.children[h] ?? const <Handle>[]) {
      (byKind[t.entities.kindAt(t.entities.slotOf(c)!)] ??= []).add(c);
    }
    final used = <EntityKind, int>{};
    for (final g in generated) {
      final i = used[g.kind] ?? 0;
      used[g.kind] = i + 1;
      final existing = byKind[g.kind];
      if (existing != null && i < existing.length) {
        final slot = t.entities.slotOf(existing[i])!;
        if (!_samePayload(
            t.geometry.peek(t.entities.geomIndexAt(slot)), g.payload)) {
          out.add(SetEntityGeometryCommand(existing[i], g.payload));
        }
      } else {
        out.add(AddEntityCommand(
            record: draftRecord(Handle.checked(++reserved), h, g.kind),
            payload: g.payload));
      }
    }
    final surplus = [
      for (final e in byKind.entries) ...e.value.skip(used[e.key] ?? 0),
    ]..sort(_byValue);
    for (final c in surplus) {
      out.add(RemoveEntityCommand(c));
    }
  }
  return out;
}

/// The first touched handle that edits a generated entity, removes one
/// while its group lives, or adds one into a live object (spec D6).
Handle? _refused(CommandTarget t, List<_Registration<Component>> types,
    _Survey before, Set<Handle> touched) {
  for (final h in touched.toList()..sort(_byValue)) {
    final owner = before.owned[h];
    if (owner != null) {
      if (_isObject(t, types, owner)) return h;
      continue;
    }
    final slot = t.entities.slotOf(h);
    if (slot != null && _isObject(t, types, t.entities.ownerAt(slot))) {
      return h;
    }
  }
  return null;
}

/// Undoes [r] after a failure; if that fails too, the target is in an
/// unknown state and the caller must know it.
void _undoInner(CommandTarget t, String label, CommandResult r, Object cause) {
  try {
    r.inverse.apply(t);
  } catch (rollbackError) {
    throw StateError('"$label": $cause, and undoing the edit then threw '
        '($rollbackError); the target is partially mutated and nothing was '
        'recorded in history');
  }
}

/// Spec D4 steps 1–9.
CommandResult _run(ParametricEdit edit, CommandTarget t) {
  final types = edit._system._types;
  final before = _survey(t, types);
  final r = edit.inner.apply(t);

  final refused = _refused(t, types, before, r.touched);
  if (refused != null) {
    _undoInner(t, edit.label, r, GeneratedGeometryError(refused));
    throw GeneratedGeometryError(refused);
  }

  final after = _survey(t, types);
  // Ruling 06-3: only objects that were live before the edit.
  final lost = [
    for (final h in before.objects.keys)
      if (!after.objects.containsKey(h) && t.tree[h] == null) h,
  ];
  final cleanup = [for (final h in lost) before.objects[h]!.detach(h)];
  final seeds = <Handle>{
    for (final h in r.touched) ...[
      // Ruling 06-4: a handle that was an object seeds too.
      if (after.objects.containsKey(h) || before.objects.containsKey(h)) h,
      if (before.owned[h] case final owner?) owner,
    ],
    ...lost,
  };
  if (seeds.isEmpty && cleanup.isEmpty) return r;

  final List<DraftCommand> plan;
  try {
    plan = _plan(t, _closure(seeds, before, after), after,
        ParametricView._(t, after.neighbours));
  } catch (error) {
    _undoInner(t, edit.label, r, error);
    rethrow;
  }
  edit._geometryChanged = plan.isNotEmpty;

  final inverses = <DraftCommand>[];
  final touched = <Handle>{...r.touched};
  for (final c in [...cleanup, ...plan]) {
    final CommandResult applied;
    try {
      applied = c.apply(t);
    } catch (error) {
      try {
        for (final i in inverses.reversed) {
          i.apply(t);
        }
      } catch (rollbackError) {
        throw StateError('"${edit.label}": regeneration threw ($error) and '
            'its rollback threw ($rollbackError); the target is partially '
            'mutated and nothing was recorded in history');
      }
      _undoInner(t, edit.label, r, error);
      rethrow;
    }
    inverses.add(applied.inverse);
    touched.addAll(applied.touched);
  }

  return CommandResult(
    inverse: ParametricReplay(
      CompoundCommand([
        if (inverses.isNotEmpty)
          CompoundCommand(inverses.reversed.toList(), label: 'Regenerate'),
        r.inverse,
      ], label: edit.label),
      edit.capabilities,
    ),
    touched: touched,
  );
}
```

If `dart analyze` flags an unused import in the part's host (for example
`draft_document.dart` or `node.dart`), keep only what is referenced.
`GroupNode` comes from `node.dart`. `DraftDocument` is used by
`ParametricSystem.document`.

- [ ] **Step 7: Run P1–P10; they pass.** Paste the output. Then run the
  engine line and the render line.
- [ ] **Step 8: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/parametric packages/jet_cad_2d/lib/jet_cad_2d.dart packages/jet_cad_2d/test/parametric
git commit -m "$(cat <<'EOF'
feat(engine): the parametric system and planner (spec 06 D1-D9)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Neighbourhood, determinism, load and drift

**Files:**
- Test: `packages/jet_cad_2d/test/parametric/neighbourhood_test.dart`

**Interfaces:**
- Consumes: everything Task 2 produced, plus `support/`.
- Produces: no code. If a test here fails against Task 2's code, fix the
  code, not the test. Record the fix in the ledger as a ruling.

- [ ] **Step 1: Write N1–N14.**

```dart
// packages/jet_cad_2d/test/parametric/neighbourhood_test.dart
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

/// drift() on a document that already has a system installed: build a
/// second, uninstalled system over it, which only reads.
List<Handle> driftOf(DraftDocument doc) =>
    ParametricSystem(doc, catalog).drift();

void main() {
  test('N1 the pair clips each other: A 5, B 3, and no drift', () {
    final doc = paramDoc();
    pair(doc);
    expect(kids(doc, hA), hasLength(5));
    expect(kids(doc, hB), hasLength(3));
    expect(driftOf(doc), isEmpty);
  });

  test('N2 an edit of A changes B too (M-06d)', () {
    final doc = paramDoc();
    pair(doc);
    final b = worldSegments(doc, hB);
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)));
    expect(worldSegments(doc, hB), isNot(b));
    expect(driftOf(doc), isEmpty);
  });

  test('N3 moving A away restores B: old neighbours are dirty (M-06l)', () {
    final doc = paramDoc();
    pair(doc);
    doc.commands.execute(TransformNodeCommand(hA, parked));
    expect(kids(doc, hB), hasLength(4));
    expect(kids(doc, hA), hasLength(4));
    expect(driftOf(doc), isEmpty);
  });

  test('N4 both transforms matter: B clipped in world by A, both rotated '
      '(M-06g engine)', () {
    final doc = paramDoc();
    pair(doc);
    // Every B child lies outside A's open interior, in world.
    final toA = atA.invert();
    for (final s in worldSegments(doc, hB)) {
      final mid = toA.transformPoint(Vector2((s[0] + s[2]) / 2, (s[1] + s[3]) / 2));
      final inside = mid.x > 1e-6 && mid.x < 2000 - 1e-6 && mid.y > 1e-6 &&
          mid.y < 1000 - 1e-6;
      expect(inside, isFalse, reason: 'B piece midpoint in A-local: $mid');
    }
  });

  test('N5 the same edit on a document and its reload gives the same bytes '
      '(M-06b)', () {
    const n1 = Handle(1000), n2 = Handle(2000), s = Handle(3000);
    final x = paramDoc();
    x.commands.execute(create(x, n2, onA(0, 1500, 0), const ClipRect(2000, 1000)));
    x.commands.execute(create(x, n1, atA, const ClipRect(2000, 1000)));
    x.commands.execute(create(x, s, parked, const ClipRect(200, 900)));
    final y = reload(enc(x)); // store order [n1, n2, s]; x holds [n2, n1, s]
    for (final d in [x, y]) {
      d.commands.execute(TransformNodeCommand(s, onA(900, 800, 0)));
    }
    expect(kids(x, n1), hasLength(5));
    expect(kids(x, n2), hasLength(5));
    expect(enc(y), enc(x));
  });

  test('N6 two seeds in one command: either child order, same bytes '
      '(M-06b\')', () {
    String run(bool bFirst) {
      final d = paramDoc();
      d.commands.execute(create(d, hA, parked, const ClipRect(2000, 1000)));
      d.commands.execute(create(d, hB,
          Transform2.translation(-9000, -4000).multiply(Transform2.rotation(0.9)),
          const ClipRect(400, 900)));
      final moves = [
        TransformNodeCommand(hA, atA),
        TransformNodeCommand(hB, atB),
      ];
      d.commands.execute(CompoundCommand(
          bFirst ? moves.reversed.toList() : moves,
          label: 'Move'));
      expect(kids(d, hA), hasLength(5));
      return enc(d);
    }
    expect(run(true), run(false));
  });

  test('N7 per-object world geometry does not depend on creation order', () {
    final x = paramDoc();
    pair(x);
    final y = paramDoc();
    pair(y, bFirst: true);
    expect(worldSegments(y, hA), worldSegments(x, hA));
    expect(worldSegments(y, hB), worldSegments(x, hB));
  });

  test('N8 load then save is byte-identical, typed', () {
    final doc = paramDoc();
    pair(doc);
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400)));
    final s = enc(doc);
    final back = reload(s);
    expect(back.components.get<ClipRect>(hA), const ClipRect(2600, 1400));
    expect(enc(back), s);
  });

  test('N9 stale geometry on file is trusted on load and reported by drift '
      '(M-06f, Ruling 06-7)', () {
    final doc = paramDoc();
    pair(doc);
    final json = jsonDecode(enc(doc)) as Map<String, Object?>;
    final victim = kids(doc, hB).first.value;
    for (final e in json['entities']! as List) {
      final m = e as Map<String, Object?>;
      if ((m['record']! as Map)['handle'] == victim) {
        ((m['geometry']! as Map)['coords']! as List)[0] = 12.5;
      }
    }
    final stale = jsonEncode(json);
    final back = reload(stale);
    expect(enc(back), stale);
    expect(back.commands.undoDepth, 0);
    expect(driftOf(back), [hB]);
  });

  test('N10 undo restores stale geometry exactly: undo never regenerates '
      '(M-06n)', () {
    final doc = paramDoc();
    pair(doc);
    final json = jsonDecode(enc(doc)) as Map<String, Object?>;
    final victim = kids(doc, hB).first.value;
    for (final e in json['entities']! as List) {
      final m = e as Map<String, Object?>;
      if ((m['record']! as Map)['handle'] == victim) {
        ((m['geometry']! as Map)['coords']! as List)[0] = 12.5;
      }
    }
    final back = reload(jsonEncode(json));
    final stale = canon(back);
    back.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2000, 1001)));
    expect(driftOf(back), isEmpty, reason: 'the edit re-generated B');
    back.commands.undo();
    expect(canon(back), stale);
  });

  test('N11 a misplaced component is reported and never regenerated', () {
    final doc = paramDoc();
    final line = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7010.5, 3020.25), Vector2(7133.1, 3071.9)));
    doc.commands.execute(line);
    final h = line.record.handle;
    doc.commands.execute(SetComponentCommand<ClipRect>(h, const ClipRect(5, 5)));
    final d = ParametricSystem(doc, catalog).diagnostics();
    expect(d.single.code, 'parametric.misplaced');
    expect(d.single.handles, [h]);
    expect(kids(doc, h), isEmpty);
  });

  test('N12 an edit inside a query walk fails before anything mutates', () {
    final doc = paramDoc();
    final index = SpatialIndex(doc);
    pair(doc);
    final before = enc(doc);
    Object? error;
    index.forEachInRect(Aabb2(Vector2(-1e6, -1e6), Vector2(1e6, 1e6)),
        const QueryFilter.all(), (slot) {
      try {
        doc.commands.execute(
            SetComponentCommand<ClipRect>(hA, const ClipRect(100, 100)));
      } catch (e) {
        error ??= e;
      }
    });
    expect(error, isA<QueryReentrancyError>());
    expect(enc(doc), before);
    index.dispose();
  });

  test('N13 rotating A while it overlaps B is one step and re-clips B '
      '(Review Focus 1)', () {
    final doc = paramDoc();
    pair(doc);
    final depth = doc.commands.undoDepth;
    final b = worldSegments(doc, hB);
    final pivot = atA.transformPoint(Vector2(1000, 500));
    final turn = Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(0.25))
        .multiply(Transform2.translation(-pivot.x, -pivot.y));
    doc.commands.execute(CompoundCommand(
        [TransformNodeCommand(hA, turn.multiply(atA))],
        label: 'Rotate'));
    expect(doc.commands.undoDepth, depth + 1);
    expect(worldSegments(doc, hB), isNot(b));
    expect(driftOf(doc), isEmpty);
  });

  test('N14 swallowed whole, then back, with new handles '
      '(Review Focus 3)', () {
    final doc = paramDoc();
    pair(doc);
    final old = kids(doc, hB);
    // B shrinks to 50 x 50 at (800,700) in A-local: wholly inside A.
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hB, const ClipRect(50, 50)));
    expect(kids(doc, hB), isEmpty);
    doc.commands.execute(
        SetComponentCommand<ClipRect>(hB, const ClipRect(400, 900)));
    expect(kids(doc, hB), hasLength(3));
    expect(kids(doc, hB).toSet().intersection(old.toSet()), isEmpty);
    expect(driftOf(doc), isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests.** Every one must pass against Task 2's code.
  - Run: `cd packages/jet_cad_2d && CI=true dart test test/parametric/neighbourhood_test.dart`
  - If one fails, the defect is in Task 2's code or in this task's
    fixture. Find which, fix it, and log a ruling. **Never weaken an
    assertion.**
- [ ] **Step 3: The engine line and the render line.**
- [ ] **Step 4: Commit.**

```bash
git add packages/jet_cad_2d/test/parametric/neighbourhood_test.dart
git commit -m "$(cat <<'EOF'
test(engine): parametric neighbourhood, determinism, load and drift (spec 06 D4, D10, D11)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Guards: refusal, delete, permissions, failures, re-entry

**Files:**
- Test: `packages/jet_cad_2d/test/parametric/guards_test.dart`

**Interfaces:**
- Consumes: Task 2 and `support/`, including `Trip.mode` and
  `Trip.document`.
- Produces: no code. If a test here fails against Task 2's code, fix the
  code, not the test. Record the fix in the ledger as a ruling.

- [ ] **Step 1: Write G1–G9.**

```dart
// packages/jet_cad_2d/test/parametric/guards_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

/// The select tool's delete cascade for one group (select_tool.dart:654-682).
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

const DraftPermissions runtime = DraftPermissions.runtime;

void main() {
  tearDown(() {
    Trip.mode = TripMode.off;
    Trip.document = null;
  });

  test('G1 a direct edit of a generated line is refused, and nothing '
      'changes (M-06j)', () {
    final doc = paramDoc();
    pair(doc);
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    final k = kids(doc, hA).first;
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(
            k, linePayload(Vector2(1, 2), Vector2(3, 4)))),
        throwsA(isA<GeneratedGeometryError>()
            .having((e) => e.handle, 'handle', k)));
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, depth);
  });

  test('G2 adding an entity into a parametric group is refused', () {
    final doc = paramDoc();
    pair(doc);
    final depth = doc.commands.undoDepth;
    final add = AddEntityCommand(
        record: draftRecord(doc.handleSeed.next(), hA, EntityKind.line),
        payload: linePayload(Vector2(1, 2), Vector2(3, 4)));
    expect(() => doc.commands.execute(add),
        throwsA(isA<GeneratedGeometryError>()));
    expect(kids(doc, hA), hasLength(5));
    expect(doc.commands.undoDepth, depth);
  });

  test('G3 delete detaches the component, the neighbour regrows, undo '
      'brings all back (M-06k)', () {
    final doc = paramDoc();
    pair(doc);
    final before = canon(doc);
    doc.commands.execute(deleteObject(doc, hA));
    expect(doc.components.get<ClipRect>(hA), isNull);
    expect(doc.tree[hA], isNull);
    expect(kids(doc, hB), hasLength(4));
    expect(ParametricSystem(doc, catalog).drift(), isEmpty);
    doc.commands.undo();
    expect(canon(doc), before);
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
  });

  test('G4 runtime: a geometry-type edit is refused; a components-type '
      'edit, its undo and its redo all succeed (M-06i)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const ClipRect(2000, 1000)));
    doc.commands.execute(create(doc, hB, atB, const SoftRect(400, 900)));
    expect(kids(doc, hB), hasLength(3));
    doc.commands.permissions = runtime;
    expect(
        () => doc.commands.execute(
            SetComponentCommand<ClipRect>(hA, const ClipRect(2600, 1400))),
        throwsA(isA<PermissionDeniedError>()));
    final before = canon(doc);
    doc.commands.execute(
        SetComponentCommand<SoftRect>(hB, const SoftRect(300, 1500)));
    final after = canon(doc);
    expect(after, isNot(before));
    doc.commands.undo();
    expect(canon(doc), before);
    doc.commands.redo();
    expect(canon(doc), after);
  });

  test('G5 runtime: a move regenerates the neighbour; a delete is refused',
      () {
    final doc = paramDoc();
    pair(doc);
    doc.commands.permissions = runtime;
    doc.commands.execute(TransformNodeCommand(hA, parked));
    expect(kids(doc, hB), hasLength(4));
    doc.commands.undo();
    expect(kids(doc, hB), hasLength(3));
    expect(() => doc.commands.execute(deleteObject(doc, hA)),
        throwsA(isA<PermissionDeniedError>()));
  });

  test('G6 a throwing generate during a delete leaves everything as it '
      'was, component included (M-06r)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const ClipRect(2000, 1000)));
    doc.commands.execute(create(doc, hB, atB, const Trip(400, 900)));
    final before = enc(doc);
    Trip.mode = TripMode.throwing;
    expect(() => doc.commands.execute(deleteObject(doc, hA)),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', 'tripwire')));
    expect(doc.components.get<ClipRect>(hA), const ClipRect(2000, 1000));
    expect(enc(doc), before);
  });

  test('G7 a failed plan reserves no handle: handleSeed unchanged (M-06t)',
      () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, const ClipRect(2000, 1000)));
    doc.commands.execute(create(doc, hB, parked, const Trip(400, 900)));
    final before = enc(doc);
    Trip.mode = TripMode.throwing;
    // A (lower handle) is planned first and would gain a child; then B's
    // generate throws.
    expect(() => doc.commands.execute(TransformNodeCommand(hB, atB)),
        throwsStateError);
    expect(enc(doc), before, reason: 'handleSeed is in the bytes');
  });

  test('G8 generate calling execute fails loudly; history unchanged '
      '(M-06s)', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hB, parked, const Trip(400, 900)));
    final before = enc(doc);
    final depth = doc.commands.undoDepth;
    Trip.document = doc;
    Trip.mode = TripMode.reentrant;
    expect(
        () => doc.commands.execute(
            SetComponentCommand<Trip>(hB, const Trip(500, 900))),
        throwsStateError);
    expect(doc.commands.undoDepth, depth);
    expect(enc(doc), before);
  });

  test('G9 un-parametric: detaching the component regrows old neighbours '
      '(Ruling 06-4)', () {
    final doc = paramDoc();
    pair(doc);
    doc.commands.execute(SetComponentCommand<ClipRect>(hA, null));
    expect(kids(doc, hB), hasLength(4));
    expect(kids(doc, hA), hasLength(5), reason: 'A is plain lines now');
  });
}
```

- [ ] **Step 2: Run the tests.** Every one must pass. Handle a failure as
  in Task 3.
- [ ] **Step 3: The engine line and the render line.**
- [ ] **Step 4: Commit.**

```bash
git add packages/jet_cad_2d/test/parametric/guards_test.dart
git commit -m "$(cat <<'EOF'
test(engine): parametric guards -- refusal, delete, runtime, failures, re-entry (spec 06 D6-D8)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `PlacementTool.commit` checks a capability set

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:217-225`
- Test: `packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart`

**Interfaces:**
- Produces: `bool commit(ToolContext ctx, DraftCommand Function() build,
  {Set<Capability> needs = const {Capability.geometry}})`. The
  permissions are checked for every member before `build` runs.

- [ ] **Step 1: Write CN1–CN2.** Use the existing draw fixture
  (`test/support/draw_fixture.dart`) to get a `ToolContext`. Read it first
  and use its rig builder's real name. The test subclass:

```dart
// packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/draw_fixture.dart';

class _Probe extends RectangleTool {
  int builds = 0;
  bool run(ToolContext ctx, Set<Capability> needs) => commit(ctx, () {
        builds++;
        return CompoundCommand(const [], label: 'never');
      }, needs: needs);
}

void main() {
  testWidgets('CN1 a denied member of needs stops the build (M-06u)',
      (tester) async {
    final rig = await drawRig(tester); // the fixture's rig; adapt the name
    rig.doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: true, structure: false);
    final probe = _Probe();
    expect(probe.run(rig.ctx, {Capability.structure, Capability.geometry}),
        isFalse);
    expect(probe.builds, 0);
  });

  testWidgets('CN2 the default is geometry alone, as in 05', (tester) async {
    final rig = await drawRig(tester);
    rig.doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: false, structure: true);
    final probe = _Probe();
    expect(probe.run(rig.ctx, const {Capability.geometry}), isFalse);
    expect(probe.builds, 0);
  });
}
```

The `CompoundCommand(const [], …)` throws if it is ever built. Neither
test may reach it; a build shows up as that `ArgumentError`. Adapt `rig.doc`
and `rig.ctx` to the fixture's real field names.

- [ ] **Step 2: Run the tests; CN1 fails to compile** (`needs` does not
  exist).
- [ ] **Step 3: Implement.**

```dart
  /// Ruling 05-3: the permission check runs before [build], so a denied
  /// shape allocates no handle. [needs] is every capability the built
  /// command will need (spec 06 D13, Ruling 06-10); 05's shapes need
  /// geometry alone. Returns whether the command ran.
  bool commit(ToolContext ctx, DraftCommand Function() build,
      {Set<Capability> needs = const {Capability.geometry}}) {
    final permissions = ctx.document.commands.permissions;
    if (!needs.every(permissions.allows)) return false;
    ctx.execute(build());
    return true;
  }
```

- [ ] **Step 4: Run the render line.**
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart
git commit -m "$(cat <<'EOF'
feat(render): PlacementTool.commit checks a capability set (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `BoxParams` and `BoxType`

**Files:**
- Create: `apps/floor_planner/lib/parametric/box.dart`
- Test: `apps/floor_planner/test/box_test.dart`

**Interfaces:**
- Consumes: `ParametricType`, `ParametricCatalog`, `ParametricSystem`,
  `Generated` and `ParametricView` (Task 2).
- Produces, used by Tasks 7 and 8:
  - `final class BoxParams implements Component`, with:
    - `const BoxParams(double width, double height)`;
    - `static const String componentTypeId = 'floor_planner.box'`;
    - `BoxParams copyWith({double? width, double? height})`;
    - `static BoxParams fromJson(Map<String, Object?>)`.
  - `final class BoxType extends ParametricType<BoxParams>`, with
    `editCapability == Capability.geometry`.
  - `final ParametricCatalog boxCatalog`.
  - `ParametricSystem installBoxes(DraftDocument doc)`.

- [ ] **Step 1: Write BT1–BT6.**

```dart
// apps/floor_planner/test/box_test.dart
import 'dart:math' as math;

import 'package:floor_planner/parametric/box.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final Transform2 atA =
    Transform2.translation(7010, 3020).multiply(Transform2.rotation(math.pi / 6));
Transform2 onA(double x, double y, double turn) => atA
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

DraftCommand box(DraftDocument doc, Handle h, Transform2 at, double w, double hh) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: at, children: const [])),
      SetComponentCommand<BoxParams>(h, BoxParams(w, hh)),
    ], label: 'Add box');

List<Handle> kids(DraftDocument doc, Handle g) => [
      for (final s in doc.entities.liveSlots)
        if (doc.entities.ownerAt(s) == g) doc.entities.handleAt(s),
    ];

void main() {
  const a = Handle(1000), b = Handle(2000);

  test('BT1 BoxParams: value equality, key order, round trip', () {
    const p = BoxParams(1200, 800);
    expect(p.toJson().keys.toList(), ['width', 'height']);
    expect(BoxParams.fromJson(p.toJson()), p);
    expect(p.copyWith(height: 5), const BoxParams(1200, 5));
    expect(p.typeId, 'floor_planner.box');
  });

  test('BT2 an isolated box is four lines at its corners', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 1200, 800));
    expect(kids(doc, a), hasLength(4));
  });

  test('BT3 a rotated overlapping pair clips each other: A 5, B 3 '
      '(M-06g app, M-06o)', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 2000, 1000));
    doc.commands.execute(box(doc, b, onA(800, 700, 0.3), 400, 900));
    expect(kids(doc, a), hasLength(5));
    expect(kids(doc, b), hasLength(3));
    expect(ParametricSystem(doc, boxCatalog).drift(), isEmpty);
  });

  test('BT4 two boxes sharing an edge exactly are not neighbours '
      '(Review Focus 5)', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 1000, 1000));
    doc.commands.execute(box(doc, b, onA(1000, 0, 0), 1000, 1000));
    expect(kids(doc, a), hasLength(4));
    expect(kids(doc, b), hasLength(4));
  });

  test('BT5 editCapability is geometry', () {
    expect(const BoxType().editCapability, Capability.geometry);
  });

  test('BT6 a box reaches exactly its transformed corners', () {
    final r = const BoxType().reach(const BoxParams(2000, 1000), atA);
    final c = [Vector2(0, 0), Vector2(2000, 0), Vector2(2000, 1000), Vector2(0, 1000)]
        .map(atA.transformPoint);
    expect(r.minX, c.map((v) => v.x).reduce(math.min));
    expect(r.maxY, c.map((v) => v.y).reduce(math.max));
  });
}
```

- [ ] **Step 2: Run; it fails to compile.**
- [ ] **Step 3: Implement `box.dart`.** `BoxType.generate` is the test
  client's `clippedRect` restricted to `BoxParams` neighbours. Copy
  `insideInterval` verbatim, as `_insideInterval` (Ruling 06-9).

```dart
// apps/floor_planner/lib/parametric/box.dart
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The demo parametric object's parameters (spec 06 D13), in mm.
final class BoxParams implements Component {
  const BoxParams(this.width, this.height);

  static const String componentTypeId = 'floor_planner.box';

  final double width;
  final double height;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'width': width, 'height': height};

  static BoxParams fromJson(Map<String, Object?> json) => BoxParams(
      (json['width']! as num).toDouble(), (json['height']! as num).toDouble());

  BoxParams copyWith({double? width, double? height}) =>
      BoxParams(width ?? this.width, height ?? this.height);

  @override
  bool operator ==(Object other) =>
      other is BoxParams && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

List<Vector2> _corners(BoxParams p) => [
      Vector2(0, 0),
      Vector2(p.width, 0),
      Vector2(p.width, p.height),
      Vector2(0, p.height),
    ];

/// A rectangle whose outline loses what lies strictly inside any
/// overlapping box: overlapping boxes read as one outline, the wall
/// clean-up preview (spec 06 D13).
final class BoxType extends ParametricType<BoxParams> {
  const BoxType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(BoxParams params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final c in _corners(params)) toWorld.transformPoint(c)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final p = view.paramsOf<BoxParams>(self)!;
    // M-06o fires here: toWorld(self) without .invert().
    final toLocal = view.toWorld(self).invert();
    final quads = [
      for (final n in view.neighbours(self))
        if (view.paramsOf<BoxParams>(n) case final q?)
          [
            for (final c in _corners(q))
              toLocal.transformPoint(view.toWorld(n).transformPoint(c)),
          ],
    ];
    final c = _corners(p);
    const tol = Tolerance.standard;
    final out = <Generated>[];
    for (var i = 0; i < 4; i++) {
      final a = c[i], b = c[(i + 1) % 4];
      final len = (b - a).length;
      var keep = <(double, double)>[(0, 1)];
      for (final q in quads) {
        final inside = _insideInterval(a, b, q);
        if (inside == null) continue;
        keep = [
          for (final (lo, hi) in keep) ...[
            if ((math.min(hi, inside.$1) - lo) * len > tol.linear)
              (lo, math.min(hi, inside.$1)),
            if ((hi - math.max(lo, inside.$2)) * len > tol.linear)
              (math.max(lo, inside.$2), hi),
          ],
        ];
      }
      for (final (lo, hi) in keep) {
        out.add(Generated(
            EntityKind.line, linePayload(a + (b - a) * lo, a + (b - a) * hi)));
      }
    }
    return out;
  }
}

/// The open parameter interval of a->b strictly inside the convex quad [q].
(double, double)? _insideInterval(Vector2 a, Vector2 b, List<Vector2> q) {
  const tol = Tolerance.standard;
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    area += u.x * v.y - v.x * u.y;
  }
  final s = area > 0 ? 1.0 : -1.0;
  final d = b - a;
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 4; i++) {
    final u = q[i], v = q[(i + 1) % 4];
    final e = v - u;
    final len = e.length;
    final f0 = s * (e.x * (a.y - u.y) - e.y * (a.x - u.x)) / len;
    final fd = s * (e.x * d.y - e.y * d.x) / len;
    if (fd.abs() <= tol.linear) {
      if (f0 <= tol.linear) return null;
      continue;
    }
    final t = (tol.linear - f0) / fd;
    if (fd > 0) {
      lo = math.max(lo, t);
    } else {
      hi = math.min(hi, t);
    }
  }
  return (hi - lo) * d.length > tol.linear ? (lo, hi) : null;
}

/// The floor planner's parametric types.
final ParametricCatalog boxCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType());

/// Builds and installs the document's parametric system.
ParametricSystem installBoxes(DraftDocument doc) =>
    ParametricSystem(doc, boxCatalog)..install();
```

- [ ] **Step 4: Run BT1–BT6; they pass. Then run the app line.**
- [ ] **Step 5: Commit.**

```bash
git add apps/floor_planner/lib/parametric/box.dart apps/floor_planner/test/box_test.dart
git commit -m "$(cat <<'EOF'
feat(floor_planner): BoxParams and BoxType, the parametric demo (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: The Box tool, the key B, and the install in the shell

**Files:**
- Create: `apps/floor_planner/lib/parametric/box_tool.dart`
- Modify: `apps/floor_planner/lib/main.dart`:
  - `initState` and `dispose`;
  - a `_box` field;
  - a `PaletteEntry` after Rectangle.
- Modify: `apps/floor_planner/lib/shortcut_guard.dart`: add
  `LogicalKeyboardKey.keyB` to `kShellLetterKeys`.
- Create: `apps/floor_planner/test/support/box_rig.dart`
- Test: `apps/floor_planner/test/planner_box_test.dart`
- Modify: `apps/floor_planner/test/startup_plan_test.dart`: add SP5.

**Interfaces:**
- Consumes: `installBoxes` and `BoxParams` (Task 6), and
  `commit(…, needs:)` (Task 5).
- Produces: `class BoxTool extends RectangleTool`, whose `name` is
  `'Box'`. The shell field is `_parametric`.

- [ ] **Step 1: Write the rig and BX1–BX6.**
  - **`box_rig.dart`:**
    - copy `pumpDraw`, `globalOf`, `status`, `press` and `bytes` from
      `test/planner_draw_test.dart`. **Copy, never import a test file**;
    - add `boxDoc(FlutterTextMeasurer m)`: a 1:20 page at `(7000, 3000)`,
      `snapToGrid: false`, and **no** entities, with `clearHistory()`;
    - add `boxKids(DraftDocument, Handle)`;
    - add `boxes(DraftDocument)`, the handles carrying `BoxParams`,
      ascending.
  - **The tests:**

```dart
// apps/floor_planner/test/planner_box_test.dart
import 'package:floor_planner/parametric/box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/box_rig.dart';

void main() {
  testWidgets('BX1 B and the palette entry activate the Box tool',
      (tester) async {
    await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester.tap(find.byKey(const Key('tool-box')));
    await tester.pump();
    expect(status(tester), 'Box');
  });

  testWidgets('BX2 two clicks: one box, four lines, one undo step',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.pump();
    final b = boxes(doc).single;
    expect(doc.components.get<BoxParams>(b)!.width, closeTo(120, 1e-6));
    expect(doc.components.get<BoxParams>(b)!.height, closeTo(70, 1e-6));
    expect(boxKids(doc, b), hasLength(4));
    expect(doc.commands.undoDepth, 1);
    doc.commands.undo();
    await tester.pump();
    expect(boxes(doc), isEmpty);
    expect(doc.entities.liveSlots, isEmpty);
  });

  testWidgets('BX3 Fill does not apply to a box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await press(tester, LogicalKeyboardKey.keyF);
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.pump();
    for (final s in view.document.entities.liveSlots) {
      expect(view.document.entities.kindAt(s), EntityKind.line);
    }
  });

  testWidgets('BX4 two overlapping boxes read as one outline',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.tapAt(globalOf(tester, view, 7100, 3060));
    await tester.tapAt(globalOf(tester, view, 7190, 3120));
    await tester.pump();
    final bs = boxes(doc);
    expect(bs, hasLength(2));
    // Each outline loses two part-edges inside the other: two edges cut.
    expect(boxKids(doc, bs[0]), hasLength(4));
    expect(boxKids(doc, bs[1]), hasLength(4));
    expect(ParametricSystem(doc, boxCatalog).drift(), isEmpty);
    // Every child midpoint lies outside the other box's interior.
  });

  testWidgets('BX5 click a box, Delete: gone with its component; cmd+Z '
      'brings both back (Review Focus 2)', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final doc = view.document;
    await press(tester, LogicalKeyboardKey.keyB);
    await tester.tapAt(globalOf(tester, view, 7010, 3020));
    await tester.tapAt(globalOf(tester, view, 7130, 3090));
    await tester.tapAt(globalOf(tester, view, 7100, 3060));
    await tester.tapAt(globalOf(tester, view, 7190, 3120));
    await press(tester, LogicalKeyboardKey.keyV);
    final first = boxes(doc).first;
    // The first box's bottom edge, away from the second box.
    await tester.tapAt(globalOf(tester, view, 7040, 3020));
    await tester.pump();
    await press(tester, LogicalKeyboardKey.delete);
    expect(doc.tree[first], isNull);
    expect(doc.components.get<BoxParams>(first), isNull);
    expect(boxKids(doc, boxes(doc).single), hasLength(4));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await press(tester, LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    expect(doc.components.get<BoxParams>(first), isNotNull);
    expect(boxes(doc), hasLength(2));
  });

  testWidgets('BX6 typing B in the page panel field does not switch tools',
      (tester) async {
    await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    final field = find.descendant(
        of: find.byKey(const Key('chrome-right')),
        matching: find.byType(EditableText));
    await tester.tap(field.first);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });
}
```

  - **BX4's geometry.** `(7010,3020)-(7130,3090)` and
    `(7100,3060)-(7190,3120)` overlap in one corner, so each box loses one
    corner region and two of its edges are shortened. That is 4 children
    each, and different world segments from an isolated box.
    - Add the midpoint check the comment names: each child's world midpoint
      is not strictly inside the other box's world rectangle.
    - If the exact counts differ from what the geometry gives, **derive
      them by hand, write the derivation in the test's comment, and assert
      that.**
  - **BX5's click point.** `(7040, 3020)` lies on the first box's bottom
    edge, outside the second box. A click there selects the group by
    `resolveHit`.
  - **Undo in BX5.** The shell binds cmd+Z. If key simulation of meta+Z
    does not reach the shell in the test binding, call
    `doc.commands.undo()` instead and note it in the report.

  SP5 goes in `startup_plan_test.dart`:

```dart
  test('SP5 the sample plan holds no parametric object (spec 06 D13)', () {
    final doc = startupPlan(FlutterTextMeasurer());
    final system = ParametricSystem(doc, boxCatalog);
    expect(system.drift(), isEmpty);
    expect(system.diagnostics(), isEmpty);
    expect(doc.components.withComponent<BoxParams>(), isEmpty);
  });
```

  Adapt `startupPlan`'s argument to the file's existing calls.

- [ ] **Step 2: Run; they fail** (no `BoxTool`, and no `tool-box` entry).
- [ ] **Step 3: Implement `box_tool.dart`.**

```dart
// apps/floor_planner/lib/parametric/box_tool.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'box.dart';

/// Spec 06 D13: two opposite corners, world-axis aligned, committed as a
/// parametric box — a group at the lower-left corner carrying [BoxParams].
/// The expander generates its lines. Fill does not apply.
class BoxTool extends RectangleTool {
  BoxTool();

  @override
  String get name => 'Box';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c1 = points.first;
    if (isDegenerateRectangle(c1, point)) return;
    commit(ctx, () {
      final doc = ctx.document;
      final h = doc.handleSeed.next();
      final minX = c1.x < point.x ? c1.x : point.x;
      final minY = c1.y < point.y ? c1.y : point.y;
      return CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: Transform2.translation(minX, minY),
            children: const [])),
        SetComponentCommand<BoxParams>(
            h, BoxParams((point.x - c1.x).abs(), (point.y - c1.y).abs())),
      ], label: 'Add box');
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    clearShape();
  }
}
```

  If `points`, `clearShape` or `commit` are not visible to a subclass
  outside the package, check `placement_tool.dart`'s annotations
  (`@protected` members are visible to subclasses). Check the package's
  exports too: `RectangleTool` and `isDegenerateRectangle` must be
  exported.

- [ ] **Step 4: Wire the shell.** In `main.dart`:
  1. Add the imports `parametric/box.dart` and `parametric/box_tool.dart`.
  2. Add the fields `late final ParametricSystem _parametric;` and
     `final BoxTool _box = BoxTool();`.
  3. Add or extend `initState` so it runs, **before anything else that
     reads the document**:

     ```dart
     @override
     void initState() {
       super.initState();
       // Spec 06 D13, Ruling 06-12: startupPlan builds its document with no
       // parametric object, so installing after it is safe.
       _parametric = installBoxes(_document);
     }
     ```

  4. In `dispose`, add `_parametric.dispose();` just before
     `_index.dispose();`.
  5. After the Rectangle entry, add
     `PaletteEntry(keyName: 'tool-box', label: 'Box', shortcut: 'B',
     logicalKey: LogicalKeyboardKey.keyB, tool: _box, drawing: true)`.
  6. In `shortcut_guard.dart`, add `LogicalKeyboardKey.keyB` after `keyR`.

  Existing tests that enumerate every palette entry or `kShellLetterKeys`
  (A1, A2 and A9 in `planner_draw_test.dart`) keep passing. If one counts
  entries, update the count and say so in the report.

- [ ] **Step 5: Run the app line.** Paste the output.
- [ ] **Step 6: Commit.**

```bash
git add apps/floor_planner/lib apps/floor_planner/test
git commit -m "$(cat <<'EOF'
feat(floor_planner): the Box tool on B, and the parametric system in the shell (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: The Selection panel section

**Files:**
- Create: `apps/floor_planner/lib/selection_panel.dart`
- Modify: `apps/floor_planner/lib/main.dart`. The right panel becomes a
  `Column`:
  - `SelectionPanel` first, sized to its content;
  - then `Expanded(PagePanel)`;
  - both inside the one `ShellShortcutGuard`.
- Test: `apps/floor_planner/test/selection_panel_test.dart`

**Interfaces:**
- Consumes: `BoxParams` and `BoxType` (Task 6), `SelectionController`, and
  the rig (Task 7).
- Produces: `SelectionPanel({required DraftDocument document, required
  SelectionController selection})`, with the keys `selection-panel`,
  `box-width` and `box-height`.

- [ ] **Step 1: Write SP1–SP7.** They reuse `box_rig.dart`. Draw two boxes
  as in BX4, then select with `view.selection.replace([...])`: the
  `PlannerView`'s selection controller, via `SelectionKey.root(h)`. Read
  `planner_view.dart` for the field's name.

```dart
// apps/floor_planner/test/selection_panel_test.dart
import 'package:floor_planner/parametric/box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/box_rig.dart';

Finder get width => find.byKey(const Key('box-width'));
Finder get height => find.byKey(const Key('box-height'));

void main() {
  testWidgets('SP1 shown for exactly one selected box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view); // in box_rig.dart: BX4's four clicks
    final bs = boxes(view.document);
    expect(width, findsNothing);
    view.selection.replace([SelectionKey.root(bs.first)]);
    await tester.pump();
    expect(width, findsOneWidget);
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SP2 hidden for none, two, and a non-box', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final bs = boxes(view.document);
    view.selection.replace([for (final b in bs) SelectionKey.root(b)]);
    await tester.pump();
    expect(width, findsNothing);
    final line = addDrafted(view.document, EntityKind.line,
        linePayload(Vector2(7300, 3300), Vector2(7400, 3350)));
    view.document.commands.execute(line);
    view.selection.replace([SelectionKey.root(line.record.handle)]);
    await tester.pump();
    expect(width, findsNothing);
  });

  testWidgets('SP3 Enter commits one step and regenerates', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(view.document.components.get<BoxParams>(b)!.width, 150);
    expect(view.document.commands.undoDepth, depth + 1);
    expect(ParametricSystem(view.document, boxCatalog).drift(), isEmpty);
  });

  testWidgets('SP4 an invalid value reverts and commits nothing',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    final depth = view.document.commands.undoDepth;
    for (final bad in ['0', '-3', 'abc']) {
      await tester.enterText(height, bad);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<TextField>(height).controller!.text, '70');
    }
    expect(view.document.commands.undoDepth, depth);
  });

  testWidgets('SP5 under runtime the fields are read-only', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    view.document.commands.permissions = DraftPermissions.runtime;
    view.selection.replace([SelectionKey.root(boxes(view.document).first)]);
    await tester.pump();
    expect(tester.widget<TextField>(width).readOnly, isTrue);
  });

  testWidgets('SP6 undo after a panel edit shows the old width '
      '(Review Focus 4)', (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    final b = boxes(view.document).first;
    view.selection.replace([SelectionKey.root(b)]);
    await tester.pump();
    await tester.enterText(width, '150');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    view.document.commands.undo();
    await tester.pump();
    expect(tester.widget<TextField>(width).controller!.text, '120');
  });

  testWidgets('SP7 typing B in the width field does not switch tools',
      (tester) async {
    final view = await pumpDraw(tester, boxDoc(FlutterTextMeasurer()));
    await drawTwoBoxes(tester, view);
    await press(tester, LogicalKeyboardKey.keyV);
    view.selection.replace([SelectionKey.root(boxes(view.document).first)]);
    await tester.pump();
    await tester.tap(width);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), isNot('Box'));
  });
}
```

  Add `drawTwoBoxes(tester, view)` to `box_rig.dart`: B, then BX4's four
  clicks, then `pump`. Add the `vector_math` import to this test for
  `Vector2`.

- [ ] **Step 2: Run; they fail.**
- [ ] **Step 3: Implement `selection_panel.dart`.**

```dart
// apps/floor_planner/lib/selection_panel.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'parametric/box.dart';

/// Spec 06 D13: one selected box's width and height. Each commit is one
/// `SetComponentCommand<BoxParams>`, which the parametric system turns into
/// one undo step with its regeneration. 12 builds the real inspector.
class SelectionPanel extends StatefulWidget {
  const SelectionPanel(
      {super.key, required this.document, required this.selection});

  final DraftDocument document;
  final SelectionController selection;

  @override
  State<SelectionPanel> createState() => _SelectionPanelState();
}

class _SelectionPanelState extends State<SelectionPanel> {
  final TextEditingController _width = TextEditingController();
  final TextEditingController _height = TextEditingController();
  late final StreamSubscription<DocChange> _changes;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_sync);
    _changes = widget.document.commands.changes.listen((_) => _sync());
    _load();
  }

  @override
  void dispose() {
    widget.selection.removeListener(_sync);
    _changes.cancel();
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  /// The one selected box, or null.
  Handle? get _box {
    final keys = widget.selection.keys;
    if (keys.length != 1) return null;
    final h = keys.single.target;
    final node = widget.document.tree[h];
    if (node is! GroupNode || node.parent != widget.document.rootHandle) {
      return null;
    }
    return widget.document.components.get<BoxParams>(h) == null ? null : h;
  }

  static String _number(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Copies the model into the fields; no rebuild.
  void _load() {
    final h = _box;
    if (h == null) return;
    final p = widget.document.components.get<BoxParams>(h)!;
    final w = _number(p.width), hh = _number(p.height);
    if (_width.text != w) _width.text = w;
    if (_height.text != hh) _height.text = hh;
  }

  /// A selection or document change: reload and rebuild.
  void _sync() {
    _load();
    if (mounted) setState(() {});
  }

  void _submit(Handle h, String text, {required bool isWidth}) {
    final value = double.tryParse(text.trim());
    final p = widget.document.components.get<BoxParams>(h)!;
    if (value == null || !value.isFinite || value <= 0) {
      _sync();
      return;
    }
    final next = isWidth ? p.copyWith(width: value) : p.copyWith(height: value);
    if (next == p) return;
    widget.document.commands.execute(SetComponentCommand<BoxParams>(h, next));
  }

  @override
  Widget build(BuildContext context) {
    final h = _box;
    if (h == null) return const SizedBox.shrink();
    final editable = widget.document.commands.permissions
        .allows(const BoxType().editCapability);
    Widget field(String label, TextEditingController c, bool isWidth) =>
        TextField(
          key: Key(isWidth ? 'box-width' : 'box-height'),
          controller: c,
          readOnly: !editable,
          decoration: InputDecoration(labelText: label, suffixText: 'mm'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (t) => _submit(h, t, isWidth: isWidth),
          onTapOutside: (_) => _submit(h, c.text, isWidth: isWidth),
        );
    return Material(
      key: const Key('selection-panel'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Box', style: Theme.of(context).textTheme.titleSmall),
            field('Width', _width, true),
            field('Height', _height, false),
          ],
        ),
      ),
    );
  }
}
```

  Focus-out uses `onTapOutside`, which runs on a tap elsewhere. If SP4 or
  SP7 show that `onTapOutside` commits during a test's tap on the field
  itself, keep `onSubmitted` only, and record Ruling 06-14 ("Enter
  commits; focus-out reverts to the model value"). The spec's D13 then
  gets amended in Task 11.

- [ ] **Step 4: Wire the panel.** In `main.dart`, the `chrome-right`
  child becomes:

```dart
                    child: ShellShortcutGuard(
                      child: Column(
                        children: [
                          SelectionPanel(
                              document: _document, selection: _selection),
                          Expanded(
                            child: PagePanel(document: _document, page: _page),
                          ),
                        ],
                      ),
                    ),
```

- [ ] **Step 5: Run the app line.**
- [ ] **Step 6: Commit.**

```bash
git add apps/floor_planner/lib apps/floor_planner/test
git commit -m "$(cat <<'EOF'
feat(floor_planner): the Selection panel edits one box's width and height (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-06-mutation-log.md`

For each mutant:
1. `cp` the file to
   `.superpowers/sdd/2026-09-24-parametric-layer/mutation-backups/<basename>.<id>`.
2. Apply the one edit.
3. Run **the named test file** with `CI=true`, and paste the failing names
   and the summary line.
4. Restore with `cp`.
5. `diff <backup> <file>`, and paste the empty output.

**Never `git checkout --` a `.dart` file.** Paths below are relative to
the repo root. `ps.dart` is
`packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`, and
`regen.dart` is `.../parametric/regeneration.dart`.

| ID | file | edit | test file |
|---|---|---|---|
| M-06a | `packages/jet_cad_2d/lib/src/document/commands.dart`, `CompoundCommand.apply` | `inverses.reversed.toList()` → `inverses.toList()` | `packages/jet_cad_2d/test/document/compound_command_test.dart` (covered there; spec) |
| M-06b | `regen.dart` `_survey` and `_closure`, and `document/component.dart` `ComponentStore.handles` | drop all three sorts: the survey's `..sort(_byValue)`, the closure's `..sort(_byValue)`, and the store's `..sort` (Ruling 06-5) | `test/parametric/neighbourhood_test.dart` (N5) |
| M-06b′ | `regen.dart`, `_closure` | drop `..sort(_byValue)` | `neighbourhood_test.dart` (N6) |
| M-06c | `regen.dart`, `_run` | drop the `if (inverses.isNotEmpty) CompoundCommand(…)` element from the replay | `test/parametric/regeneration_test.dart` (P3) |
| M-06d | `regen.dart`, `_closure` | return `seeds.where(after.objects.containsKey).toList()..sort(_byValue)` | `neighbourhood_test.dart` (N2, N3) |
| M-06e | — | N/A by construction (spec D4 step 6); record it | — |
| M-06f | `ps.dart`, `install` | after taking the slot, execute `regenerateAll`: a `CompoundCommand` of `_plan` over every object, if non-empty (Ruling 06-7) | `neighbourhood_test.dart` (N9) |
| M-06g | `regen.dart`, `_worldOf` | return `Transform2.identity()` | `neighbourhood_test.dart` (N1, N4), `regeneration_test.dart` (P3) |
| M-06g (app) | `apps/floor_planner/lib/parametric/box.dart`, `reach` | `toWorld.transformPoint(c)` → `c` | `apps/floor_planner/test/box_test.dart` (BT3) |
| M-06h | `ps.dart`, `ParametricEdit.capability` | return `inner.capability` | `regeneration_test.dart` (P4) |
| M-06i | `ps.dart`, `ParametricReplay.apply` | return `r` (a bare compound inverse) | `test/parametric/guards_test.dart` (G4) |
| M-06j | `regen.dart`, `_run` | delete the `_refused` block | `guards_test.dart` (G1, G2) |
| M-06k | `regen.dart`, `_run` | `final cleanup = <DraftCommand>[];` | `guards_test.dart` (G3) |
| M-06l | `regen.dart`, `_closure` | delete the `before.neighbours` line | `neighbourhood_test.dart` (N3) |
| M-06m | `regen.dart`, `_plan` | match by overall ordinal: one list of all children, ignoring kind | `regeneration_test.dart` (P5) |
| M-06n | `packages/jet_cad_2d/lib/src/document/undo.dart`, `undo` | `final inverse = _history.takeUndo();` → `final inverse = expander?.call(_history.takeUndo()) ?? …` (keep it compiling) | `test/document/expander_test.dart` (X2), `neighbourhood_test.dart` (N10) |
| M-06o | `box.dart`, `generate` | `view.toWorld(self).invert()` → `view.toWorld(self)` | `box_test.dart` (BT3) |
| M-06p | `regen.dart`, `_plan` | a changed payload becomes `RemoveEntityCommand(existing[i])` plus an `AddEntityCommand` with a reserved handle | `regeneration_test.dart` (P2) (Ruling 06-6) |
| M-06q | `ps.dart`, `_expand` | drop `&& !_setsParametric(command)` | `regeneration_test.dart` (P1) |
| M-06r | `regen.dart`, `_run` | apply `cleanup` right after computing it, and leave it out of the loop (revision 1's shape) | `guards_test.dart` (G6) |
| M-06s | `ps.dart`, `_expand` | delete the `_applying` check | `guards_test.dart` (G8) |
| M-06t | `regen.dart`, `_plan` | `Handle.checked(++reserved)` → `t.handleSeed.next()` | `guards_test.dart` (G7) |
| M-06u | `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`, `commit` | check `Capability.geometry` only | `packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart` (CN1) |
| M-06v | `ps.dart`, `_Registration.registerInto` | drop the `isRegistered` check | `regeneration_test.dart` (P10) |

- [ ] **Step 1: Fire each mutant.** Append each result to the log as it
  lands, formatted as in `plan-05-mutation-log.md`:
  - the heading `### M-06x — <title>`;
  - then `file:`, `edit:` and `test:`;
  - then `result: KILLED -- <names>; <summary>`.

  **A survivor** gets a fixture change in the owning test, a re-fire logged
  as `M-06x′`, and a ruling. The spec permits no designed survivor except
  M-06e (N/A) and M-06a (covered by the engine's own test).
- [ ] **Step 2: Tally.** Write "N fired: K killed, S survived, M-06e N/A".
- [ ] **Step 3:** `git status --short` lists only the log.
- [ ] **Step 4: Commit.**

```bash
git add docs/superpowers/notes/plan-06-mutation-log.md
git commit -m "$(cat <<'EOF'
docs: Plan 06 mutation log -- M-06a..v

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Invariants and greps

**Files:**
- Modify: `docs/superpowers/notes/plan-06-mutation-log.md` (append)

- [ ] **Step 1: Run each check and paste its output.**

```sh
git diff main -- packages/jet_cad_2d/test/invariants packages/jet_cad_2d_flutter/test/invariants | wc -l   # 0
grep -rn "package:flutter\|dart:ui" packages/jet_cad_2d/lib | wc -l   # 0
# document/ never imports parametric/ (spec D1); component.dart gains isRegistered only
git diff main -- packages/jet_cad_2d/lib/src/document/component.dart | grep '^+' | grep -v '^+++'
grep -rn "parametric" packages/jet_cad_2d/lib/src/document | wc -l   # 0
# The render layer changed only placement_tool.dart (spec, Files)
git diff --stat main -- packages/jet_cad_2d_flutter/lib   # one file
# No handleSeed.next() in the planner (spec D4 step 7)
grep -n "handleSeed.next" packages/jet_cad_2d/lib/src/parametric   # no hits
```

- [ ] **Step 2: Run all four gate lines** and paste each summary. Name the
  five golden failures.
- [ ] **Step 3: Commit** with the message `docs: Plan 06 invariants and
  greps` and the trailer.

---

### Task 11: Gates, the results note, the spec amendments, STATUS, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-24-plan-06-results.md`
- Modify: the spec, `roadmap/06-parametric-layer.md`,
  `roadmap/00-README.md`, `STATUS.md`

- [ ] **Step 1: Paste the four gate lines**, with exit codes and counts.
  The expected counts:
  - engine: 911 + 4 (X) + 10 (P) + 14 (N) + 9 (G) = **948**;
  - render layer: 923 + 2 (CN) = **925**, plus 1 skip and the five goldens;
  - harness: **82**;
  - app: 46 + 6 (BT) + 6 (BX) + 7 (SP) + 1 (SP5) = **66**;
  - both builds `✓ Built`.

  **Report what ran**, and explain any difference.
- [ ] **Step 2: The results note.** Include:
  - one row per exit criterion 1–14, each with its witness;
  - the mutation tally;
  - Rulings 06-1…06-13, and any added during execution;
  - the Review Focus items and their tests;
  - the debt, from spec D12 and the open questions:
    - the draw order of added children;
    - the O(n²) neighbour search;
    - the per-axis AABB reach;
  - **criterion 14 marked OWED.** The human looks after this branch is
    presented: on macOS, in Chrome and in Firefox from `build/web`. Each
    platform's list:
    1. B draws a box.
    2. A second box overlapping the first: one merged outline.
    3. Select a box. Width and Height appear; set the width, press Enter,
       and the outline follows. cmd+Z undoes it in one step.
    4. Move and rotate a box over another. The outlines re-merge, and one
       undo restores.
    5. Delete a box. The other regrows, and cmd+Z brings it back.
    6. Typing B or V in the fields does not switch tools.
- [ ] **Step 3: Spec amendments.** Add "Amended at execution (Plan 06)"
  paragraphs:
  - D3 and D10: Ruling 06-1, the catalog;
  - D4 step 4: Ruling 06-3, and 06-4;
  - the mutant table: Rulings 06-5, 06-6, 06-7, 06-8 and 06-10;
  - D1: Ruling 06-13 (`isRegistered`);
  - D13: Ruling 06-14, if it was made.
- [ ] **Step 4: STATUS and the roadmap.** Follow Plan 05's shape:
  - the header;
  - a Plan 06 section;
  - the Resume paragraph;
  - `roadmap/06-parametric-layer.md`'s status line;
  - `roadmap/00-README.md`'s row.
- [ ] **Step 5: Commit, then archive the ledger** as the branch's last
  commit.

```bash
git add docs/superpowers/notes/2026-09-24-plan-06-results.md docs/superpowers/specs/2026-09-24-parametric-layer-design.md roadmap/06-parametric-layer.md roadmap/00-README.md STATUS.md
git commit -m "$(cat <<'EOF'
docs: Plan 06 results, spec amendments, STATUS and roadmap

Exit gate 13 of 14; criterion 14 (the human's look) is OWED.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
mkdir -p docs/superpowers/ledgers/2026-09-24-parametric-layer
cp -R .superpowers/sdd/2026-09-24-parametric-layer/. docs/superpowers/ledgers/2026-09-24-parametric-layer/
git add docs/superpowers/ledgers/2026-09-24-parametric-layer
git commit -m "$(cat <<'EOF'
docs: archive the Plan 06 ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Hand over to `superpowers:finishing-a-development-branch`. **The merge is
the human's decision.**

---

## Exit gate

| # | criterion | witness |
|---|---|---|
| 1 | the four gate lines, the five goldens only, both builds | Task 11 Step 1 |
| 2 | a parameter change regenerates, a neighbour's too | P2, N2, SP3 |
| 3 | one undo step; undo and redo restore both, same handles | P3, BX2 |
| 4 | load → save byte-identical, typed | N8 |
| 5 | same state plus same edit gives the same bytes | N5, N6 |
| 6 | a mutual dependency terminates, with no iteration | N1, N2, M-06e N/A |
| 7 | no `QueryReentrancyError` from regeneration | P4, N12 |
| 8 | the allocation invariants unchanged | Task 10 |
| 9 | draw order: unchanged objects keep their child handles | P2, P3 |
| 10 | a direct edit of a generated child is refused | G1, G2 |
| 11 | delete detaches the component; undo restores it | G3, BX5 |
| 12 | runtime inheritance, undo and redo included | G4, G5, SP5 |
| 13 | every mutant killed, or recorded as N/A or covered | the mutation log |
| 14 | the human's look | OWED (Task 11) |

## Self-review

**Spec coverage.**

| spec item | covered by |
|---|---|
| D1 | Task 2; the Task 10 grep; P10 (Ruling 06-13) |
| D2 | Task 1, `_expand` (Task 2); X1–X4, P6, P8, G8 |
| D3 | Task 2; P7; the catalog (Ruling 06-1) |
| D4 | Task 2 `_run`, `_plan`, `_closure`; P1–P5, N1–N14, G6, G7 |
| D5 | `_isObject`, `diagnostics()`; N11 |
| D6 | `_refused`; G1, G2 |
| D7 | `ParametricEdit.capabilities`, `ParametricReplay`; G4, G5 |
| D8 | the cleanup; G3, BX5 |
| D9 | `capability`, single use; P4, P9 |
| D10 | `drift()`, the catalog; N8, N9, N10 |
| D11 | N5, N6, N7, P3 |
| D12 | P2, P3; the results note's debt |
| D13 | Tasks 5–8 |
| Invariants | Task 10; P4, N12 |

**Placeholder scan.** No TBD. Some steps name a fallback where the plan's
reading of Flutter or of an existing fixture could be wrong:
- CN1 and CN2 adapt to the draw fixture's rig names;
- BX4's counts are derived by hand if the geometry disagrees;
- BX5 falls back to `undo()` if meta+Z does not reach the shell;
- SP's `onTapOutside` has a fallback ruling.

Each says what to paste and what to do instead.

**Type and name consistency.** These names are used identically across
tasks:
- `ParametricCatalog`, `register`, `registerComponents`;
- `ParametricSystem(doc, catalog)`, `install`, `dispose`, `drift`,
  `diagnostics`;
- `ParametricEdit`, `ParametricReplay`, `Generated`,
  `GeneratedGeometryError`, `ParametricView.paramsOf`, `toWorld`,
  `neighbours`;
- `BoxParams.componentTypeId`, `BoxType`, `boxCatalog`, `installBoxes`,
  `BoxTool`, `SelectionPanel`;
- the keys `tool-box`, `box-width`, `box-height`, `selection-panel`.
