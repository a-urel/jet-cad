## Task 4: `AddRegionCommand`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
- Create: `packages/jet_cad_2d/test/document/region_command_test.dart`

**Interfaces:**
- Consumes: `FillIndex` (Task 3), `triangulateSimplePolygon` (Task 2), `boundaryHandleOf` (Task 1).
- Produces:
```dart
class AddRegionCommand extends DraftCommand {
  AddRegionCommand({required this.fill, required this.boundary,
      required this.boundaryPayload});
  final EntityRecord fill;         // handle strictly lower
  final EntityRecord boundary;
  final GeometryPayload boundaryPayload;

  static AddRegionCommand allocate({
    required HandleSeed seed,
    required Handle owner,
    required EntityKind boundaryKind,
    required GeometryPayload boundaryPayload,
    required Handle layer,
    required DraftColor fillColor,
    required DraftColor boundaryColor,
    int fillTransparency = 0,
    int boundaryLineweight = kLineweightDefault,
  });
}
class RemoveRegionCommand extends DraftCommand { ... }  // the inverse

/// Also produced here, and consumed by Tasks 5, 7 and 8.
///
/// null  = not a fillable boundary at all -> refused at command time
/// empty = a circle (fanned per frame, never cached), OR a fillable shape the
///         clipper could not reduce -> the painter skips it and counts it
Int32List? triangulationFor(EntityKind kind, GeometryPayload payload);
```

**The one rule this command exists for.** It allocates `fill` **before**
`boundary`, so the fill's handle is strictly lower and ascending handle order
draws it underneath. `apply` re-checks that invariant and throws if it does not
hold, so a hand-built command cannot invert it silently.

**One `apply`, not two composed.** The fill is written first and at that instant
its boundary does not exist. Composing two `AddEntityCommand`s would fire
`invalidateDerived()` between them and let an observer see a fill with a
dangling reference. This command writes both, then invalidates once.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d/test/document/region_command_test.dart`:

```dart
import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

GeometryPayload squareLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
    scalars: Float64List(0));

AddRegionCommand region(DraftDocument doc) => AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: squareLoop(),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );

void main() {
  test('the fill gets the lower handle, so it draws underneath', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    expect(cmd.fill.handle.value, lessThan(cmd.boundary.handle.value),
        reason: 'draw order is ascending handle value; a fill above its own '
            'boundary paints over its outline');
    doc.commands.execute(cmd);
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
  });

  test('apply refuses an inverted pair rather than drawing it wrong', () {
    final doc = DraftDocument.empty();
    final good = region(doc);
    final inverted = AddRegionCommand(
      fill: good.fill.copyWith(handle: Handle(good.boundary.handle.value + 1)),
      boundary: good.boundary,
      boundaryPayload: good.boundaryPayload,
    );
    expect(() => doc.commands.execute(inverted), throwsStateError);
  });

  test('the fill names its boundary and the index links them', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final slot = doc.entities.slotOf(cmd.fill.handle)!;
    final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
    expect(payload.coords, isEmpty, reason: 'a fill stores no geometry');
    expect(boundaryHandleOf(payload), cmd.boundary.handle);
    expect(doc.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
  });

  test('the triangulation is materialised by the command, not by a draw', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6),
        reason: 'a square is two triangles; the frame path reads and never '
            'computes');
  });

  test('an unfillable boundary is refused before anything is written', () {
    final doc = DraftDocument.empty();
    final open = GeometryPayload(
        coords: Float64List.fromList([0, 0, 10, 0, 10, 10]), // not closed
        scalars: Float64List(0));
    expect(
        () => doc.commands.execute(AddRegionCommand.allocate(
              seed: doc.handleSeed,
              owner: doc.rootHandle,
              boundaryKind: EntityKind.polyline,
              boundaryPayload: open,
              layer: ReservedHandles.layerZero,
              fillColor: const TrueColor(0x3366CC),
              boundaryColor: const TrueColor(0x000000),
            )),
        throwsStateError);
    expect(doc.entities.liveSlots, isEmpty,
        reason: 'apply must either complete fully or leave the target '
            'unmutated');
  });

  test('undo removes both halves and redo restores the same handles', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.undo();
    expect(doc.entities.liveSlots, isEmpty);
    expect(doc.fills.entryCount, 0);
    expect(doc.fills.linkCount, 0);
    doc.commands.redo();
    expect(doc.entities.slotOf(cmd.fill.handle), isNotNull);
    expect(doc.entities.slotOf(cmd.boundary.handle), isNotNull);
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: FAIL — `AddRegionCommand` is not defined.

- [ ] **Step 3: Implement**

Append to `commands.dart`:

```dart
/// Creates a boundary and the fill beneath it, as one mutation.
///
/// **The pair's handles are the whole point.** Draw order is ascending handle
/// value, and the natural authoring order -- draw the outline, then hatch it --
/// produces exactly the failing case. [allocate] takes the fill's handle first,
/// so it is strictly lower, and [apply] re-checks that rather than trusting it:
/// a hand-built command must not be able to invert the order silently.
///
/// **One `apply`, not two composed commands.** The fill is written first and at
/// that instant the boundary it names does not exist. Two `AddEntityCommand`s
/// would fire `invalidateDerived()` between them and let the index observe a
/// fill with a dangling reference.
class AddRegionCommand extends DraftCommand {
  AddRegionCommand({
    required this.fill,
    required this.boundary,
    required this.boundaryPayload,
  });

  final EntityRecord fill;
  final EntityRecord boundary;
  final GeometryPayload boundaryPayload;

  /// Allocates the pair, **fill first**.
  static AddRegionCommand allocate({
    required HandleSeed seed,
    required Handle owner,
    required EntityKind boundaryKind,
    required GeometryPayload boundaryPayload,
    required Handle layer,
    required DraftColor fillColor,
    required DraftColor boundaryColor,
    int fillTransparency = 0,
    int boundaryLineweight = kLineweightDefault,
  }) {
    final fillHandle = seed.next();
    final boundaryHandle = seed.next();
    return AddRegionCommand(
      fill: EntityRecord(
        handle: fillHandle,
        owner: owner,
        kind: EntityKind.fill,
        layer: layer,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: fillColor,
        lineweight: kLineweightDefault,
        transparency: fillTransparency,
        flags: 0,
      ),
      boundary: EntityRecord(
        handle: boundaryHandle,
        owner: owner,
        kind: boundaryKind,
        layer: layer,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: boundaryColor,
        lineweight: boundaryLineweight,
        transparency: 0,
        flags: 0,
      ),
      boundaryPayload: boundaryPayload,
    );
  }

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Add region';

  @override
  CommandResult apply(CommandTarget target) {
    if (fill.handle.value >= boundary.handle.value) {
      throw StateError(
          'a region\'s fill must carry the lower handle: got fill '
          '${fill.handle.toHex()} against boundary ${boundary.handle.toHex()}');
    }
    if (fill.owner != boundary.owner) {
      throw StateError('a region\'s two halves must share one owner');
    }
    // Everything that can refuse, refuses before anything is written --
    // `apply` must either complete fully or leave the target unmutated.
    final triangles = triangulationFor(boundary.kind, boundaryPayload);
    if (triangles == null) {
      throw StateError('${boundary.handle.toHex()} is not a fillable boundary');
    }
    if (target.entities.containsHandle(fill.handle) ||
        target.entities.containsHandle(boundary.handle)) {
      throw DuplicateHandleError(fill.handle);
    }

    final fillGeom = target.geometry.add(GeometryPayload(
      coords: Float64List(0),
      scalars: Float64List.fromList([boundary.handle.value.toDouble()]),
    ));
    target.entities.add(fill.copyWith(geomIndex: fillGeom));
    final boundaryGeom = target.geometry.add(boundaryPayload);
    target.entities.add(boundary.copyWith(geomIndex: boundaryGeom));
    target.handleSeed.raiseTo(boundary.handle);

    target.fills.link(fill.handle, boundary.handle);
    if (triangles.isNotEmpty) {
      target.fills.putTriangles(boundary.handle, triangles);
    }
    target.invalidateDerived();

    return CommandResult(
      inverse: RemoveRegionCommand(
          fill: fill, boundary: boundary, boundaryPayload: boundaryPayload),
      touched: {fill.handle, boundary.handle},
    );
  }
}

/// The triangulation for a fillable boundary, or null when it is not one.
///
/// An **empty** result is different from null: null means "this is not a
/// boundary at all" and is refused at command time; empty means "a fillable
/// shape that could not be reduced", which the painter skips and counts.
/// A circle returns an empty list and is fanned per frame instead -- its
/// triangulation is scale-dependent and must never be cached.
Int32List? triangulationFor(EntityKind kind, GeometryPayload payload) {
  if (kind == EntityKind.circle) {
    return payload.scalars.isNotEmpty && payload.scalars[0] > 0
        ? Int32List(0)
        : null;
  }
  if (kind != EntityKind.polyline) return null;
  final count = payload.pointCount;
  // Closedness is a stored-value question, so the comparison is exact. This is
  // the same test `SpatialIndex` already applies before answering
  // `HitKind.fill` for a closed polyline's interior.
  if (count < 3) return null;
  if (payload.coords[0] != payload.coords[(count - 1) * 2] ||
      payload.coords[1] != payload.coords[(count - 1) * 2 + 1]) {
    return null;
  }
  return triangulateSimplePolygon(payload.coords, count);
}

/// Removes a region as one mutation. [AddRegionCommand]'s inverse.
///
/// Removal order is boundary first, then fill: the reverse of creation, so no
/// observer ever sees a live fill whose boundary has gone.
class RemoveRegionCommand extends DraftCommand {
  RemoveRegionCommand({
    required this.fill,
    required this.boundary,
    required this.boundaryPayload,
  });

  final EntityRecord fill;
  final EntityRecord boundary;
  final GeometryPayload boundaryPayload;

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Remove region';

  @override
  CommandResult apply(CommandTarget target) {
    final boundarySlot = target.entities.slotOf(boundary.handle);
    final fillSlot = target.entities.slotOf(fill.handle);
    if (boundarySlot == null || fillSlot == null) {
      throw StateError('region ${boundary.handle.toHex()} is not intact');
    }
    target.geometry.remove(target.entities.geomIndexAt(boundarySlot));
    target.entities.remove(boundarySlot);
    target.geometry.remove(target.entities.geomIndexAt(fillSlot));
    target.entities.remove(fillSlot);
    target.fills.dropBoundary(boundary.handle);
    target.invalidateDerived();
    return CommandResult(
      inverse: AddRegionCommand(
          fill: fill, boundary: boundary, boundaryPayload: boundaryPayload),
      touched: {fill.handle, boundary.handle},
    );
  }
}
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: PASS, six tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/commands.dart
cp "$F" /tmp/t4.dart
trap 'cp /tmp/t4.dart "$F"' EXIT
run() { dart test test/document/region_command_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T4a: allocate the boundary first, so the fill paints over its outline
perl -0pi -e 's/    final fillHandle = seed\.next\(\);\n    final boundaryHandle = seed\.next\(\);/    final boundaryHandle = seed.next();\n    final fillHandle = seed.next();/' "$F"; run; cp /tmp/t4.dart "$F"
# T4b: drop the ordering re-check, so a hand-built command inverts silently
perl -0pi -e 's/    if \(fill\.handle\.value >= boundary\.handle\.value\) \{/    if (false) {/' "$F"; run; cp /tmp/t4.dart "$F"
# T4c: triangulate lazily -- do not populate at command time
perl -0pi -e 's/      target\.fills\.putTriangles\(boundary\.handle, triangles\);//' "$F"; run; cp /tmp/t4.dart "$F"
# T4d: accept a nearly-closed loop
perl -0pi -e 's/  if \(payload\.coords\[0\] != payload\.coords\[\(count - 1\) \* 2\] \|\|\n      payload\.coords\[1\] != payload\.coords\[\(count - 1\) \* 2 \+ 1\]\) \{\n    return null;\n  \}//' "$F"; run; cp /tmp/t4.dart "$F"
```

All four must print `KILLED`. **T4d needs the open-boundary fixture**; if it
survives, no test is exercising an unclosed loop and the task is not done.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/commands.dart \
        packages/jet_cad_2d/test/document/region_command_test.dart
git commit -m "feat: AddRegionCommand reserves the pair's draw order"
```

---

