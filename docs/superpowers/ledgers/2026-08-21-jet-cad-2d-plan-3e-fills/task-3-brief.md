## Task 3: `FillIndex` — the cache and the reverse map

**Files:**
- Create: `packages/jet_cad_2d/lib/src/document/fill_index.dart`
- Create: `packages/jet_cad_2d/test/document/fill_index_test.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/command.dart` (`CommandTarget` gains `FillIndex get fills`)
- Modify: `packages/jet_cad_2d/lib/src/document/draft_document.dart` (owns one, exposes it)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (export)

**Interfaces:**
- Consumes: `triangulateSimplePolygon` (Task 2), `boundaryHandleOf` (Task 1).
- Produces:
```dart
class FillIndex {
  Int32List? trianglesFor(Handle boundary);
  void putTriangles(Handle boundary, Int32List triangles);
  void link(Handle fill, Handle boundary);
  void unlink(Handle fill);
  List<Handle> fillsOf(Handle boundary);   // ascending handle order
  void dropTriangles(Handle boundary);     // triangles only; links stay (Task 5)
  void dropBoundary(Handle boundary);      // triangles + every link naming it
  void clear();
  int get entryCount;                      // triangulations held
  int get linkCount;                       // fill -> boundary links held
}
```

**Why one object.** The cache and the reverse map are written by the same three commands, invalidated at the same moments, and rebuilt together on load. Two objects would be two chances to update one and forget the other — the shape of the defect this plan is most exposed to.

**Why the key is a `Handle`.** `purge()` renumbers every `geomIndex` wholesale (`draft_document.dart`), so a `geomIndex`-keyed cache is not stale after a purge but **permuted**. Handles survive purge, are never reissued, and undo restores them. A missed invalidation is then a leak, not a wrong drawing.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d/test/document/fill_index_test.dart`:

```dart
import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('triangles round-trip by boundary handle', () {
    final ix = FillIndex();
    expect(ix.trianglesFor(const Handle(20)), isNull);
    ix.putTriangles(const Handle(20), Int32List.fromList([0, 1, 2]));
    expect(ix.trianglesFor(const Handle(20)), [0, 1, 2]);
    expect(ix.entryCount, 1);
  });

  test('a hit returns the stored list itself, not a copy', () {
    // The frame path reads this per fill per frame. A defensive copy here
    // would allocate per entity and break the global constraint.
    final ix = FillIndex();
    final stored = Int32List.fromList([0, 1, 2]);
    ix.putTriangles(const Handle(20), stored);
    expect(identical(ix.trianglesFor(const Handle(20)), stored), isTrue);
  });

  test('fillsOf returns every fill naming a boundary, in handle order', () {
    final ix = FillIndex();
    ix.link(const Handle(31), const Handle(40));
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(22), const Handle(41));
    expect(ix.fillsOf(const Handle(40)), [const Handle(19), const Handle(31)]);
    expect(ix.fillsOf(const Handle(41)), [const Handle(22)]);
    expect(ix.fillsOf(const Handle(99)), isEmpty);
  });

  test('dropBoundary removes the triangles and every link naming it', () {
    final ix = FillIndex();
    ix.putTriangles(const Handle(40), Int32List.fromList([0, 1, 2]));
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(31), const Handle(40));
    ix.dropBoundary(const Handle(40));
    expect(ix.trianglesFor(const Handle(40)), isNull);
    expect(ix.fillsOf(const Handle(40)), isEmpty);
    expect(ix.entryCount, 0);
    expect(ix.linkCount, 0,
        reason: 'a link left behind after its boundary died is the leak the '
            'handle key was chosen to make harmless -- but it is still a leak');
  });

  test('unlink removes one fill and leaves its siblings', () {
    final ix = FillIndex();
    ix.link(const Handle(19), const Handle(40));
    ix.link(const Handle(31), const Handle(40));
    ix.unlink(const Handle(19));
    expect(ix.fillsOf(const Handle(40)), [const Handle(31)]);
  });

  test('the index survives a purge because handles do', () {
    // The purge test that a geomIndex-keyed cache cannot pass. Two entities,
    // one removed, then purge -- which renumbers every geomIndex and leaves
    // every handle alone.
    final doc = DraftDocument.empty();
    final a = doc.handleSeed.next();
    final b = doc.handleSeed.next();
    for (final h in [a, b]) {
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: h,
          owner: doc.rootHandle,
          kind: EntityKind.polyline,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.continuousLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const TrueColor(0x000000),
          lineweight: 30,
          transparency: 0,
          flags: 0,
        ),
        payload: GeometryPayload(
            coords: Float64List.fromList(
                h == a ? [0, 0, 1, 0, 1, 1, 0, 0] : [5, 5, 6, 5, 6, 6, 5, 5]),
            scalars: Float64List(0)),
      ));
    }
    doc.fills.putTriangles(b, Int32List.fromList([0, 1, 2]));
    doc.commands.execute(RemoveEntityCommand(a));
    doc.purge();
    expect(doc.fills.trianglesFor(b), [0, 1, 2],
        reason: 'purge renumbers every geomIndex and touches no handle, so a '
            'handle-keyed entry is still attached to the same entity');
  });
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/fill_index_test.dart`
Expected: FAIL — `FillIndex` is not defined.

- [ ] **Step 3: Implement**

`packages/jet_cad_2d/lib/src/document/fill_index.dart`:

```dart
import 'dart:typed_data';

import '../core/handle.dart';

/// Derived state for fills: one triangulation per boundary, and the reverse
/// map from a boundary to the fills that name it.
///
/// **Keyed by `Handle`, never by `geomIndex`.** `DraftDocument.purge()`
/// renumbers every `geomIndex` from a remap table, so a slot-keyed cache does
/// not go stale across a purge -- it goes *permuted*, every surviving entry
/// attached to the wrong entity at once. Handles are never reissued
/// (`HandleSeed.next` only increments) and `RemoveEntityCommand`'s inverse
/// restores the same handle, so a stale entry here can only ever be an entry
/// nobody reads. The failure mode is a leak, not a lie.
///
/// **Never populated on the frame path.** Commands and the codec fill it; the
/// painter only reads. [trianglesFor] returns the stored list itself rather
/// than a copy, because the alternative allocates once per fill per frame.
///
/// Both halves live in one object because the same three commands write both
/// and the same moments invalidate both.
class FillIndex {
  final Map<Handle, Int32List> _triangles = {};
  final Map<Handle, Handle> _boundaryOfFill = {};

  Int32List? trianglesFor(Handle boundary) => _triangles[boundary];

  void putTriangles(Handle boundary, Int32List triangles) {
    _triangles[boundary] = triangles;
  }

  void link(Handle fill, Handle boundary) {
    _boundaryOfFill[fill] = boundary;
  }

  void unlink(Handle fill) {
    _boundaryOfFill.remove(fill);
  }

  /// Every fill naming [boundary], in ascending handle order.
  ///
  /// Ordered because callers put these into a command's `touched` set and into
  /// removal cascades, and this project's determinism rests on stable orders.
  List<Handle> fillsOf(Handle boundary) {
    final out = <Handle>[
      for (final e in _boundaryOfFill.entries)
        if (e.value == boundary) e.key,
    ];
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  void dropBoundary(Handle boundary) {
    _triangles.remove(boundary);
    _boundaryOfFill.removeWhere((_, b) => b == boundary);
  }

  void clear() {
    _triangles.clear();
    _boundaryOfFill.clear();
  }

  int get entryCount => _triangles.length;
  int get linkCount => _boundaryOfFill.length;
}
```

In `command.dart`, add to `CommandTarget`:

```dart
  /// The fill cache and the boundary->fills map. A command that changes a
  /// boundary's geometry or removes one must keep this current; see
  /// `SetEntityGeometryCommand` and `RemoveEntityCommand`.
  FillIndex get fills;
```

In `draft_document.dart`, add the field, the getter, and — deliberately — **no
call in `purge()`**:

```dart
  final FillIndex fills = FillIndex();
```

with a comment at `purge()`:

```dart
    // `fills` is deliberately untouched. It is keyed by handle, and purge
    // renumbers slots, not handles. Adding an invalidation here would be
    // correct-looking and wrong: it would throw away work nothing invalidated.
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/document/fill_index_test.dart`
Expected: PASS, six tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/document/fill_index.dart
cp "$F" /tmp/t3.dart
trap 'cp /tmp/t3.dart "$F"' EXIT
run() { dart test test/document/fill_index_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T3a: return a defensive copy -- allocates per fill per frame
perl -0pi -e 's/  Int32List\? trianglesFor\(Handle boundary\) => _triangles\[boundary\];/  Int32List? trianglesFor(Handle boundary) { final t = _triangles[boundary]; return t == null ? null : Int32List.fromList(t); }/' "$F"; run; cp /tmp/t3.dart "$F"
# T3b: dropBoundary forgets the links
perl -0pi -e 's/    _boundaryOfFill\.removeWhere\(\(_, b\) => b == boundary\);//' "$F"; run; cp /tmp/t3.dart "$F"
# T3c: fillsOf returns insertion order
perl -0pi -e 's/    out\.sort\(\(a, b\) => a\.value\.compareTo\(b\.value\)\);//' "$F"; run; cp /tmp/t3.dart "$F"
```

All three must print `KILLED`.

Also run the **keying** mutant, which is the one the purge test exists for. It
cannot be expressed as a one-line edit of this file; do it by hand: change
`trianglesFor`/`putTriangles`/`dropBoundary` to take an `int geomIndex`, and
have the purge test key by `doc.entities.read(doc.entities.slotOf(b)!).geomIndex`.
The purge test must go red. Record the transcript in the commit message.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/fill_index.dart \
        packages/jet_cad_2d/lib/src/document/command.dart \
        packages/jet_cad_2d/lib/src/document/draft_document.dart \
        packages/jet_cad_2d/lib/jet_cad_2d.dart \
        packages/jet_cad_2d/test/document/fill_index_test.dart
git commit -m "feat: FillIndex, keyed by handle so purge cannot permute it"
```

---

