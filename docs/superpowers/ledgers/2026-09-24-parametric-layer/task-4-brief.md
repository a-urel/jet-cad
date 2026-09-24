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

