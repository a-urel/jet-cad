## Task 5: `SetEntityGeometryCommand`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/commands.dart`
- Modify: `packages/jet_cad_2d/test/document/region_command_test.dart`

**Interfaces:**
- Produces: `SetEntityGeometryCommand(Handle handle, GeometryPayload payload)`.

**Why it exists.** `GeometryStore.replace` has no production caller, because there is no geometry-edit command: editing points today means remove + add, which issues a **new handle**. A fill that names its boundary by handle loses its referent the instant that happens. Associativity is not an extra — it is unreachable without this command.

**Three things it must do beyond the write:**
1. **Refuse `EntityKind.fill`.** A fill's payload is a *reference*, not geometry. `SetEntityTextCommand` is the precedent for the refusal, right down to the message shape.
2. **Re-triangulate.** `replace` keeps the `geomIndex`, so the cache key does not change and a stale entry would never be noticed.
3. **Put every dependent fill in `touched`.** `SpatialIndex` re-derives boxes only for touched handles. A fill's box is *derived* from its boundary, so editing the boundary alone leaves the fill indexed against geometry that no longer exists — pick and cull both answer against the old outline.

- [ ] **Step 1: Write the failing tests**

Append to `region_command_test.dart`:

```dart
  test('editing a boundary re-triangulates and touches its fills', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final before = doc.fills.trianglesFor(cmd.boundary.handle)!;

    // An L, not a translation: a moved square re-triangulates to the same
    // index list and cannot tell a working invalidation from a missing one.
    final result = doc.commands.execute(SetEntityGeometryCommand(
      cmd.boundary.handle,
      GeometryPayload(
          coords: Float64List.fromList(
              [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
          scalars: Float64List(0)),
    ));
    final after = doc.fills.trianglesFor(cmd.boundary.handle)!;
    expect(after.length, 12, reason: 'six vertices reduce to four triangles');
    expect(after.length, isNot(before.length));
    expect(result.touched, contains(cmd.fill.handle),
        reason: 'the fill\'s indexed box is derived from this boundary; if the '
            'fill is not touched, SpatialIndex never re-derives it');
  });

  test('the handle and the geomIndex survive the edit', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final slot = doc.entities.slotOf(cmd.boundary.handle)!;
    final geomBefore = doc.entities.geomIndexAt(slot);
    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList([0, 0, 5, 0, 5, 5, 0, 5, 0, 0]),
            scalars: Float64List(0))));
    expect(doc.entities.slotOf(cmd.boundary.handle), slot);
    expect(doc.entities.geomIndexAt(slot), geomBefore,
        reason: 'identity preserved is the whole reason this command exists');
  });

  test('it refuses a fill, because a fill\'s payload is a reference', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(
            cmd.fill.handle,
            GeometryPayload(
                coords: Float64List(0),
                scalars: Float64List.fromList([999.0])))),
        throwsStateError);
  });

  test('undo restores the previous geometry and its triangulation', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList(
                [0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20, 0, 0]),
            scalars: Float64List(0))));
    doc.commands.undo();
    expect(doc.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: FAIL — `SetEntityGeometryCommand` is not defined.

- [ ] **Step 3: Implement**

```dart
/// Replaces one entity's geometry, preserving its handle and its `geomIndex`.
///
/// The command `GeometryStore.replace` was waiting for. Without it, editing
/// points means remove + add, which issues a new handle -- and a fill that
/// names its boundary by handle loses its referent the moment that happens.
///
/// Rejects [EntityKind.fill]: a fill's payload is a *reference*, not geometry,
/// and letting this command rewrite it would repoint a fill at another
/// boundary with no validation, no cache move and no `touched` story.
/// Re-association is a different operation and is out of this plan's scope.
class SetEntityGeometryCommand extends DraftCommand {
  SetEntityGeometryCommand(this.handle, this.payload);

  final Handle handle;
  final GeometryPayload payload;

  @override
  Capability get capability => Capability.geometry;

  @override
  String get label => 'Edit geometry';

  @override
  CommandResult apply(CommandTarget target) {
    final slot = target.entities.slotOf(handle);
    if (slot == null) {
      throw StateError('no entity with handle ${handle.toHex()}');
    }
    final record = target.entities.read(slot);
    if (record.kind == EntityKind.fill) {
      throw StateError(
          '${handle.toHex()} is a fill: its payload names a boundary and is '
          'not geometry this command may rewrite');
    }
    // `read`, not `peek`: the inverse keeps this payload, and `peek` returns
    // the store's own buffer, which a later edit would rewrite underneath the
    // undo stack.
    final previous = target.geometry.read(record.geomIndex);
    target.geometry.replace(record.geomIndex, payload);

    // The fill's box is derived from this boundary, and `SpatialIndex`
    // re-derives only what a command touches. Leaving the fills out here
    // leaves them indexed against geometry that no longer exists.
    final dependents = target.fills.fillsOf(handle);
    if (dependents.isNotEmpty) {
      final triangles = triangulationFor(record.kind, payload);
      // `replace` keeps the geomIndex, so the key does not change and a stale
      // entry would never be noticed. Replace it, or drop it when the edit
      // made the boundary unfillable -- the painter then counts a skip.
      if (triangles == null || triangles.isEmpty) {
        target.fills.dropTriangles(handle);
      } else {
        target.fills.putTriangles(handle, triangles);
      }
    }
    target.invalidateDerived();
    return CommandResult(
      inverse: SetEntityGeometryCommand(handle, previous),
      touched: {handle, ...dependents},
    );
  }
}
```

`FillIndex` gains one method, beside `dropBoundary`:

```dart
  /// Drops a boundary's triangulation but keeps the links naming it. Used when
  /// an edit makes a live boundary unfillable: the fills still exist and still
  /// point here; they simply have nothing to draw, which the painter counts.
  void dropTriangles(Handle boundary) {
    _triangles.remove(boundary);
  }
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/document/region_command_test.dart`
Expected: PASS, ten tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/commands.dart
cp "$F" /tmp/t5.dart
trap 'cp /tmp/t5.dart "$F"' EXIT
run() { dart test test/document/region_command_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T5a: drop the dependent fills from `touched`
perl -0pi -e 's/      touched: \{handle, \.\.\.dependents\},/      touched: {handle},/' "$F"; run; cp /tmp/t5.dart "$F"
# T5b: do not re-triangulate after the edit
perl -0pi -e 's/        target\.fills\.putTriangles\(handle, triangles\);//' "$F"; run; cp /tmp/t5.dart "$F"
# T5c: accept a fill
perl -0pi -e 's/    if \(record\.kind == EntityKind\.fill\) \{/    if (false) {/' "$F"; run; cp /tmp/t5.dart "$F"
# T5d: keep the inverse's payload by `peek`, sharing the store's buffer
perl -0pi -e 's/    final previous = target\.geometry\.read\(record\.geomIndex\);/    final previous = target.geometry.peek(record.geomIndex);/' "$F"; run; cp /tmp/t5.dart "$F"
```

T5a–T5c must print `KILLED`. **T5d may survive** — if it does, add a test that
edits the same boundary twice and then undoes twice, which is the only shape
that catches a shared buffer. Do not leave it unaccounted for either way.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/commands.dart \
        packages/jet_cad_2d/lib/src/document/fill_index.dart \
        packages/jet_cad_2d/test/document/region_command_test.dart
git commit -m "feat: SetEntityGeometryCommand, and the touched set fills depend on"
```

---

