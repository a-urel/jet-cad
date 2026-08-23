import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

// ---------------------------------------------------------------------------
// Fixture helpers.
//
// Four distinct sources for every property under test — the instance, the
// substituted layer's record, layer 0's record, and `StyleContext.documentRoot`
// — so a resolution that reads the wrong one of the four lands on a number no
// assertion here expects. A fixture where two of the four agree cannot tell a
// correct resolver from the mutant that reads the other one.
// ---------------------------------------------------------------------------

Handle addLayer(
  DraftDocument doc,
  Handle handle,
  String name, {
  required int lineweight,
  required int transparency,
  required Handle linetype,
}) {
  // `DraftDocument.empty()` seeds layer 0 via `DocumentTables.standard()`, so
  // overriding it (as the BYLAYER-substitution fixture does, to give layer 0
  // and the substituted layer distinct values) collides on both handle and
  // name unless the existing record is removed first -- the same pattern
  // `test/index/query_filter_test.dart:381` uses to replace a layer record.
  // Only layer 0 is pre-seeded (`tables.dart:509`), and only it needs
  // replacing. An unguarded remove would silently overwrite a genuine
  // accidental duplicate instead of failing on it.
  if (handle == ReservedHandles.layerZero) doc.tables.layers.remove(handle);
  doc.tables.layers.add(LayerRecord(
    handle: handle,
    name: name,
    color: const IndexedColor(5),
    linetype: linetype,
    lineweight: lineweight,
    transparency: transparency,
    visible: true,
    locked: false,
  ));
  return handle;
}

Handle addDefinition(DraftDocument doc, Handle handle, String name) {
  doc.tree.addDefinition(Definition(
      handle: handle,
      name: name,
      basePoint: Vector2.zero(),
      children: const []));
  return handle;
}

/// A line that defers every property to whatever places it.
Handle addByBlockLine(
  DraftDocument doc,
  Handle owner,
  Handle handle, {
  double linetypeScale = 2.0,
}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: linetypeScale,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Handle addInstance(
  DraftDocument doc,
  Handle handle,
  Handle definition, {
  Handle? parent,
  Handle layer = ReservedHandles.layerZero,
  int lineweight = kByBlock,
  int transparency = kByBlock,
  Handle linetype = ReservedHandles.byBlockLinetype,
  double linetypeScale = 1.0,
}) {
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: handle,
    parent: parent ?? doc.rootHandle,
    // Never the identity: an identity transform commutes and hides ordering,
    // which is the defect four fixtures missed in Plan 2.
    transform: Transform2.translation(31, 17),
    definition: definition,
    layer: layer,
    lineweight: lineweight,
    transparency: transparency,
    linetype: linetype,
    linetypeScale: linetypeScale,
  )));
  return handle;
}

/// Resolves [child] as if drawn through [instance], directly rather than by
/// walking. The claim under test is what `contextFor` computes, not how a
/// traversal reaches it; the traversal is covered by the differential and
/// golden suites in the Flutter package.
ResolvedStyle resolveThrough(
    DraftDocument doc, List<Handle> instances, Handle child) {
  final resolver = DocumentStyleResolver(doc);
  var ctx = StyleContext.documentRoot;
  for (final i in instances) {
    ctx = resolver.contextFor(i, ctx);
  }
  return resolver.styleFor(doc.entities.slotOf(child)!, ctx);
}

void main() {
  // `StyleContext.documentRoot` is lineweight 25, transparency 0, linetype
  // `continuousLinetype`. Every expected value below differs from all three.

  test('an INSERT imposes its concrete lineweight on a BYBLOCK child', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, const Handle(200), 'BOLT');
    final child = addByBlockLine(doc, def, const Handle(201));
    addInstance(doc, const Handle(300), def, lineweight: 211);

    expect(resolveThrough(doc, [const Handle(300)], child).lineweightHundredths,
        211);
  });

  test('an INSERT imposes its concrete transparency on a BYBLOCK child', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, const Handle(200), 'BOLT');
    final child = addByBlockLine(doc, def, const Handle(201));
    addInstance(doc, const Handle(300), def, transparency: 137);

    // Transparency reaches the drawing as the alpha byte: 255 - 137 = 118.
    // Asserted through `argb` rather than through a transparency getter
    // because `ResolvedStyle` has no separate transparency field, and the
    // byte is what a painter actually consumes.
    expect(resolveThrough(doc, [const Handle(300)], child).argb >> 24, 118);
  });

  test('an INSERT imposes its concrete linetype on a BYBLOCK child', () {
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, const Handle(200), 'BOLT');
    final child = addByBlockLine(doc, def, const Handle(201));
    addInstance(doc, const Handle(300), def, linetype: const Handle(42));

    expect(resolveThrough(doc, [const Handle(300)], child).linetype,
        const Handle(42));
  });

  group('BYLAYER on an INSTANCE reads the substituted layer, not node.layer',
      () {
    /// Layer 0 and layer `L` carry different values for every property, and
    /// the instance sits on layer 0 so substitution has to happen for the
    /// right one to be read. A mutant reading `node.layer` gets layer 0's
    /// numbers; the correct resolver gets `L`'s.
    DraftDocument fixture() {
      final doc = DraftDocument.empty();
      addLayer(doc, ReservedHandles.layerZero, '0',
          lineweight: 13, transparency: 9, linetype: const Handle(70));
      addLayer(doc, const Handle(100), 'STRUCT',
          lineweight: 191, transparency: 88, linetype: const Handle(71));
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      addByBlockLine(doc, def, const Handle(201));
      // The container instance `300` places, and the parent every `310`
      // variant nests under below: harmless to leave undefined for
      // `resolveThrough` (which calls the resolver directly and never
      // walks), but a real definition is what makes this a document a
      // traversal could actually load and paint.
      addDefinition(doc, const Handle(210), 'PLATE');
      // The outer placement puts layer STRUCT into the context; the inner
      // instance is on layer 0, so it inherits STRUCT and must read STRUCT's
      // record for its own BYLAYER properties.
      addInstance(doc, const Handle(300), const Handle(210),
          layer: const Handle(100));
      return doc;
    }

    test('lineweight', () {
      final doc = fixture();
      addInstance(doc, const Handle(310), const Handle(200),
          parent: const Handle(210), lineweight: kByLayer);
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)],
                  const Handle(201))
              .lineweightHundredths,
          191);
    });

    test('transparency', () {
      final doc = fixture();
      addInstance(doc, const Handle(310), const Handle(200),
          parent: const Handle(210), transparency: kByLayer);
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)],
                      const Handle(201))
                  .argb >>
              24,
          255 - 88);
    });

    test('linetype', () {
      final doc = fixture();
      addInstance(doc, const Handle(310), const Handle(200),
          parent: const Handle(210), linetype: ReservedHandles.byLayerLinetype);
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)],
                  const Handle(201))
              .linetype,
          const Handle(71));
    });
  });

  group('kLineweightDefault never reaches a ResolvedStyle', () {
    // `-3` is a third sentinel in this encoding, not a width. A three-arm
    // switch sends it down "otherwise" and into StyleContext.lineweight,
    // whose doc comment declares that field concrete -- and the entity-side
    // guard cannot rescue it, because that guard maps a -3 entity lineweight
    // to ctx.lineweight, which here would itself be -3.
    test('carried directly by the INSERT', () {
      final doc = DraftDocument.empty();
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      final child = addByBlockLine(doc, def, const Handle(201));
      addInstance(doc, const Handle(300), def, lineweight: kLineweightDefault);

      // documentRoot's 25 -- the inherited value, which is what "default"
      // means here.
      expect(
          resolveThrough(doc, [const Handle(300)], child).lineweightHundredths,
          25);
    });

    test('reached through the INSERT\'s BYLAYER lookup', () {
      final doc = DraftDocument.empty();
      addLayer(doc, const Handle(100), 'DEFAULTED',
          lineweight: kLineweightDefault,
          transparency: 0,
          linetype: ReservedHandles.continuousLinetype);
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      final child = addByBlockLine(doc, def, const Handle(201));
      addInstance(doc, const Handle(300), def,
          layer: const Handle(100), lineweight: kByLayer);

      expect(
          resolveThrough(doc, [const Handle(300)], child).lineweightHundredths,
          25);
    });
  });

  group('linetypeScale multiplies down the tree', () {
    test('entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0', () {
      final doc = DraftDocument.empty();
      final inner = addDefinition(doc, const Handle(200), 'BOLT');
      final outer = addDefinition(doc, const Handle(210), 'PLATE');
      final child =
          addByBlockLine(doc, inner, const Handle(201), linetypeScale: 2.0);
      addInstance(doc, const Handle(300), outer, linetypeScale: 8.0);
      addInstance(doc, const Handle(310), inner,
          parent: const Handle(210), linetypeScale: 4.0);

      // Exact. Every factor is a power of two, so the product is
      // representable and `Tolerance` would only hide a wrong answer.
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)], child)
              .linetypeScale,
          64.0);
    });

    test('an INSERT at 1.0 leaves its child alone', () {
      // The default's no-op property, asserted rather than assumed: this is
      // what makes every pre-3f.1 document resolve unchanged. The entity's own
      // scale is still 2.0, never 1.0 -- the identity on both sides would
      // prove nothing.
      final doc = DraftDocument.empty();
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      final child =
          addByBlockLine(doc, def, const Handle(201), linetypeScale: 2.0);
      addInstance(doc, const Handle(300), def);

      expect(
          resolveThrough(doc, [const Handle(300)], child).linetypeScale, 2.0);
    });
  });
}
