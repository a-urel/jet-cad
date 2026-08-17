import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:test/test.dart';

/// FNV-1a over the document's full serialisation.
///
/// Not a hash for security — a change detector. The codec writes every table
/// record, every node transform and every coordinate, so two documents with
/// the same fingerprint are the same document.
int fingerprint(DraftDocument doc) {
  final s = DraftDocumentCodec.encodeToString(doc);
  var h = 0xcbf29ce484222325;
  for (var i = 0; i < s.length; i++) {
    h = ((h ^ s.codeUnitAt(i)) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return h;
}

void main() {
  test('generateDocument is deterministic across calls', () {
    // The generator seeds math.Random(0xC0FFEE). Two documents built with the
    // same arguments must agree entity for entity, or Plan 2's numbers and
    // Plan 3a's are not measured on the same drawing and cannot be compared.
    final a = generateDocument(2000, definitionCount: 20);
    final b = generateDocument(2000, definitionCount: 20);

    expect(a.entities.liveSlots.length, b.entities.liveSlots.length);
    for (final slot in a.entities.liveSlots) {
      expect(a.entities.handleAt(slot), b.entities.handleAt(slot));
      expect(a.entities.kindAt(slot), b.entities.kindAt(slot));
      expect(a.geometry.peek(a.entities.geomIndexAt(slot)).coords,
          b.geometry.peek(b.entities.geomIndexAt(slot)).coords);
    }
    expect(a.extents.minX, b.extents.minX);
    expect(a.extents.maxX, b.extents.maxX);
  });

  test('the default document is the one Plan 2 measured, byte for byte', () {
    // These two numbers were taken from this file's serialisation *before* the
    // corpus extensions were written, and they are the whole guard on them.
    // Every extension draws from its own `Random` and allocates no handle
    // while it is off, so a default that leaks — one extra `nextDouble()`, one
    // extra node — shifts every subsequent value in the document and moves
    // these. Plan 2's gate note is only reproducible while they hold.
    //
    // Deliberately not the structural assertions the plan sketches (one layer,
    // every colour ByLayer, every node an instance under the root). Those pass
    // on a document whose coordinates have all moved.
    //
    // Re-baselined in Plan 3c Task 1: the four text keys changed the
    // serialisation.
    expect(fingerprint(generateDocument(2000, definitionCount: 20)),
        -4223683079839955300);
    expect(fingerprint(generateDocument(20000, definitionCount: 20)),
        -1538364231202837705);
  });

  test('defaults reproduce the Plan 2 corpus structurally too', () {
    // The fingerprint says "unchanged" but not "unchanged in what way". This
    // names the properties the extensions must each leave alone, so a failure
    // says which one moved.
    final doc = generateDocument(2000, definitionCount: 20);
    expect(doc.tables.layers.records, hasLength(1));
    expect(doc.tables.linetypes.records, hasLength(3));
    for (final slot in doc.entities.liveSlots) {
      expect(doc.entities.colorAt(slot), kByLayer);
      expect(doc.entities.layerAt(slot), ReservedHandles.layerZero);
      expect(doc.entities.linetypeAt(slot), ReservedHandles.byLayerLinetype);
    }
    for (final node
        in doc.tree.nodes.where((n) => n.handle != doc.rootHandle)) {
      expect(node, isA<InstanceNode>());
      expect(node.parent, doc.rootHandle);
    }
  });

  test('nestingDepth places instances inside definitions', () {
    final doc = generateDocument(5000, definitionCount: 20, nestingDepth: 2);
    expect(
        doc.tree.nodes.where(
            (n) => n.handle != doc.rootHandle && n.parent != doc.rootHandle),
        isNotEmpty);
  });

  test('nesting terminates: no definition reaches itself', () {
    // A cycle is not a slow document, it is a stack overflow on the frame
    // path. The generator must place only strictly *later* definitions inside
    // earlier ones, and this is the check that says so rather than the
    // comment.
    final doc = generateDocument(5000, definitionCount: 20, nestingDepth: 3);
    final placedInside = <Handle, Set<Handle>>{};
    for (final node in doc.tree.nodes) {
      if (node is! InstanceNode || node.parent == doc.rootHandle) continue;
      (placedInside[node.parent] ??= <Handle>{}).add(node.definition);
    }
    expect(placedInside, isNotEmpty, reason: 'nothing was nested');

    for (final definition in placedInside.keys) {
      final seen = <Handle>{};
      final stack = <Handle>[definition];
      while (stack.isNotEmpty) {
        final at = stack.removeLast();
        for (final child in placedInside[at] ?? const <Handle>{}) {
          expect(child, isNot(definition), reason: 'definition cycle');
          if (seen.add(child)) stack.add(child);
        }
      }
    }
  });

  test('mirroredFraction produces negative-determinant instances', () {
    final doc =
        generateDocument(5000, definitionCount: 20, mirroredFraction: 0.25);
    final placed =
        doc.tree.nodes.where((n) => n.handle != doc.rootHandle).toList();
    final mirrored = placed.where((n) => n.transform.determinant < 0);
    expect(mirrored.length / placed.length, closeTo(0.25, 0.05));
  });

  test('nonUniformFraction produces anisotropic instances', () {
    // The bypass in `DraftPainter` only runs past a ratio of 2, so a corpus of
    // gently squashed instances would measure the fast path and report it as
    // coverage of the slow one.
    final doc =
        generateDocument(5000, definitionCount: 20, nonUniformFraction: 0.2);
    final placed =
        doc.tree.nodes.where((n) => n.handle != doc.rootHandle).toList();
    final anisotropic =
        placed.where((n) => n.transform.anisotropyRatio > 2.0).toList();
    expect(anisotropic.length / placed.length, closeTo(0.2, 0.05));
  });

  test('groupCount puts leaves under group nodes', () {
    // A group folds its transform into the leaves of the container above it,
    // which is a different code path in both the index and the painter from a
    // leaf owned by the root.
    final doc = generateDocument(5000, definitionCount: 20, groupCount: 12);
    // The root is itself a GroupNode, so it has to come out of the count.
    final groups = doc.tree.nodes
        .whereType<GroupNode>()
        .where((g) => g.handle != doc.rootHandle)
        .toList();
    expect(groups, hasLength(12));

    final owners = {
      for (final slot in doc.entities.liveSlots) doc.entities.ownerAt(slot)
    };
    expect(groups.where((g) => owners.contains(g.handle)), isNotEmpty);
  });

  test('byBlockFraction and layerCount create more than one resolution path',
      () {
    // Without this the memo-versus-unmemoised delta measures a single path and
    // means nothing.
    final doc = generateDocument(5000,
        definitionCount: 20, layerCount: 8, byBlockFraction: 0.3);
    final encodings = {
      for (final slot in doc.entities.liveSlots) doc.entities.colorAt(slot)
    };
    expect(encodings.length, greaterThan(1));
    expect(doc.tables.layers.records, hasLength(8));

    final layers = {
      for (final slot in doc.entities.liveSlots) doc.entities.layerAt(slot)
    };
    expect(layers.length, greaterThan(1),
        reason: 'adding layer records that nothing is drawn on measures the '
            'table, not the resolution path');
  });

  test('byBlock entities live where ByBlock means something', () {
    // ByBlock on a root-level entity has no instance to resolve against and
    // falls back to the context, so it exercises no extra path. The fraction
    // is of definition-owned entities for that reason.
    final doc =
        generateDocument(5000, definitionCount: 20, byBlockFraction: 0.3);
    final definitions = {for (final d in doc.tree.definitions) d.handle};
    for (final slot in doc.entities.liveSlots) {
      if (doc.entities.colorAt(slot) != kByBlock) continue;
      expect(definitions, contains(doc.entities.ownerAt(slot)));
    }
  });

  test('dashedFraction is reported and non-zero when asked for', () {
    final doc =
        generateDocument(5000, definitionCount: 20, dashedFraction: 0.4);
    final dashed = doc.entities.liveSlots.where(
        (s) => doc.entities.linetypeAt(s) != ReservedHandles.byLayerLinetype);
    expect(dashed.length / doc.entities.liveSlots.length, closeTo(0.4, 0.05));
    expect(doc.tables.linetypes.records.map((r) => r.name), contains('Dashed'));
  });

  test('every extension stays deterministic', () {
    // The extensions draw from their own `Random`; a seed taken from the
    // clock, or a `Set` iterated in hash order, would make two runs of the
    // same rig incomparable.
    Map<String, Object?> build() => DraftDocumentCodec.encode(generateDocument(
          3000,
          definitionCount: 20,
          nestingDepth: 2,
          mirroredFraction: 0.25,
          nonUniformFraction: 0.2,
          groupCount: 8,
          layerCount: 8,
          byBlockFraction: 0.3,
          dashedFraction: 0.4,
        ));
    expect(build().toString(), build().toString());
  });
}
