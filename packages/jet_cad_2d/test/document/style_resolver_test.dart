import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, Handle owner,
    {required Handle layer,
    required DraftColor color,
    int lineweight = kByLayer,
    int transparency = kByLayer}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: layer,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: color,
      lineweight: lineweight,
      transparency: transparency,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

/// A layer that is not layer 0, so substitution has somewhere to land.
Handle addLayer(DraftDocument doc, Handle handle, String name,
    {required DraftColor color, int lineweight = 50, int transparency = 0}) {
  doc.tables.layers.add(LayerRecord(
    handle: handle,
    name: name,
    color: color,
    linetype: ReservedHandles.continuousLinetype,
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

void main() {
  // Expected colours are written as literals throughout. Asserting against
  // `aciToRgb(n)` would be a tautology: the same function under test on both
  // sides passes whatever it returns.

  test('ByLayer resolves against the entity layer, not the context layer', () {
    final doc = DraftDocument.empty();
    final red =
        addLayer(doc, const Handle(100), 'red', color: const IndexedColor(1));
    final h =
        addLine(doc, doc.rootHandle, layer: red, color: const ByLayerColor());
    final slot = doc.entities.slotOf(h)!;

    final resolver = DocumentStyleResolver(doc);
    final style = resolver.styleFor(slot, StyleContext.documentRoot);

    expect(style.argb, 0xFFFF0000, reason: 'ACI 1 is red');
    expect(style.lineweightHundredths, 50);
  });

  test('ByBlock resolves against the context, and layer-0 inherits it', () {
    // A definition's contents authored ByBlock on layer 0 are the whole point
    // of the block model: 500 instances share one geometry and each renders in
    // its own colour. If this resolves against the layer table instead, every
    // instance renders identically and the picture cache in 3b would be keyed
    // on a context that changes nothing.
    final doc = DraftDocument.empty();
    final def = addDefinition(doc, const Handle(200), 'sym');
    final h = addLine(doc, def,
        layer: ReservedHandles.layerZero, color: const ByBlockColor());
    final slot = doc.entities.slotOf(h)!;

    const instance = Handle(201);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.translation(5, 7),
      definition: def,
      layer: ReservedHandles.layerZero,
      color: const IndexedColor(3),
    )));

    final resolver = DocumentStyleResolver(doc);
    final ctx = resolver.contextFor(instance, StyleContext.documentRoot);
    expect(ctx.color, encodeColor(const IndexedColor(3)));

    final style = resolver.styleFor(slot, ctx);
    expect(style.argb, 0xFF00FF00, reason: 'ACI 3 is green');
  });

  group('two levels of nesting', () {
    // Both cases share one fixture: the same inner definition placed twice in
    // the same outer definition, once ByBlock and once with a concrete colour.
    // One case alone cannot discriminate — a `contextFor` that ignored the
    // inner node entirely and returned `inherited` would pass the ByBlock case,
    // and one that ignored the outer context would pass the concrete case.
    late DraftDocument doc;
    late int slot;
    late StyleContext ctxOuter;
    late DocumentStyleResolver resolver;
    const innerByBlock = Handle(302), outerNode = Handle(303);
    const innerConcrete = Handle(304);

    setUp(() {
      doc = DraftDocument.empty();
      final inner = addDefinition(doc, const Handle(300), 'inner');
      final outer = addDefinition(doc, const Handle(301), 'outer');
      final h = addLine(doc, inner,
          layer: ReservedHandles.layerZero, color: const ByBlockColor());
      slot = doc.entities.slotOf(h)!;

      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: innerByBlock,
        parent: outer,
        transform: Transform2.translation(1, 2),
        definition: inner,
        layer: ReservedHandles.layerZero,
        color: const ByBlockColor(),
      )));
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: innerConcrete,
        parent: outer,
        transform: Transform2.translation(8, 9),
        definition: inner,
        layer: ReservedHandles.layerZero,
        color: const IndexedColor(6),
      )));
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: outerNode,
        parent: doc.rootHandle,
        transform: Transform2.translation(3, 4),
        definition: outer,
        layer: ReservedHandles.layerZero,
        color: const IndexedColor(5),
      )));

      resolver = DocumentStyleResolver(doc);
      ctxOuter = resolver.contextFor(outerNode, StyleContext.documentRoot);
    });

    test('a ByBlock inner instance passes the outer colour through', () {
      final ctxInner = resolver.contextFor(innerByBlock, ctxOuter);
      expect(resolver.styleFor(slot, ctxInner).argb, 0xFF0000FF,
          reason: 'ACI 5, the outer instance colour, is blue');
    });

    test('a concrete inner instance overrides the outer colour', () {
      final ctxInner = resolver.contextFor(innerConcrete, ctxOuter);
      expect(resolver.styleFor(slot, ctxInner).argb, 0xFFFF00FF,
          reason: 'ACI 6, the inner instance colour, is magenta');
    });
  });

  group('the layer-0 rule is substitution, not deferral', () {
    // Layer 0 is a real DXF layer with a real table record. An entity on it is
    // drawn on the layer of the instance that places it; when nothing places it
    // on another layer, layer 0's own record governs. Deferring to the context
    // instead would make layer 0's record unreachable and would silently give
    // BYLAYER the meaning of BYBLOCK.

    test('an entity on layer 0 is drawn on the placing instance\'s layer', () {
      final doc = DraftDocument.empty();
      final red = addLayer(doc, const Handle(100), 'red',
          color: const IndexedColor(1), lineweight: 50);
      final def = addDefinition(doc, const Handle(200), 'sym');
      final h = addLine(doc, def,
          layer: ReservedHandles.layerZero, color: const ByLayerColor());
      final slot = doc.entities.slotOf(h)!;

      const instance = Handle(201);
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(5, 7),
        definition: def,
        layer: red,
        // Deliberately not ACI 1: if the entity resolved against the context
        // rather than against layer `red`, it would come out green.
        color: const IndexedColor(3),
      )));

      final resolver = DocumentStyleResolver(doc);
      final ctx = resolver.contextFor(instance, StyleContext.documentRoot);
      final style = resolver.styleFor(slot, ctx);

      expect(style.argb, 0xFFFF0000,
          reason: "layer red's ACI 1, not the ACI 3 context");
      expect(style.lineweightHundredths, 50, reason: "layer red's lineweight");
    });

    test('layer 0 keeps its own colour when no instance substitutes it', () {
      final doc = DraftDocument.empty();
      final def = addDefinition(doc, const Handle(200), 'sym');
      final h = addLine(doc, def,
          layer: ReservedHandles.layerZero, color: const ByLayerColor());
      final slot = doc.entities.slotOf(h)!;

      const instance = Handle(201);
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: instance,
        parent: doc.rootHandle,
        transform: Transform2.translation(5, 7),
        definition: def,
        layer: ReservedHandles.layerZero,
        color: const IndexedColor(3),
      )));

      final resolver = DocumentStyleResolver(doc);
      final ctx = resolver.contextFor(instance, StyleContext.documentRoot);

      expect(resolver.styleFor(slot, ctx).argb, 0xFFFFFFFF,
          reason: "layer 0's own ACI 7 is white; the ACI 3 context is what "
              'BYBLOCK would have taken');
    });

    test(
        'a nested instance on layer 0 resolves ByLayer against the '
        'substituted layer', () {
      // The instance is on layer 0 and its own colour is BYLAYER, so the layer
      // it is placed through governs — the same substitution `styleFor` applies
      // to an entity. Reading layer 0's record here instead would have the one
      // node report two different effective layers: layer 0 for its own colour,
      // and the substituted layer for everything it places.
      final doc = DraftDocument.empty();
      final red = addLayer(doc, const Handle(100), 'red',
          color: const IndexedColor(1), lineweight: 50);
      final inner = addDefinition(doc, const Handle(300), 'inner');
      final outer = addDefinition(doc, const Handle(301), 'outer');
      final h = addLine(doc, inner,
          layer: ReservedHandles.layerZero, color: const ByBlockColor());
      final slot = doc.entities.slotOf(h)!;

      const innerNode = Handle(302), outerNode = Handle(303);
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: innerNode,
        parent: outer,
        transform: Transform2.translation(1, 2),
        definition: inner,
        layer: ReservedHandles.layerZero,
        color: const ByLayerColor(),
      )));
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: outerNode,
        parent: doc.rootHandle,
        transform: Transform2.translation(3, 4),
        definition: outer,
        layer: red,
        color: const IndexedColor(3),
      )));

      final resolver = DocumentStyleResolver(doc);
      final ctxOuter =
          resolver.contextFor(outerNode, StyleContext.documentRoot);
      final ctxInner = resolver.contextFor(innerNode, ctxOuter);

      expect(ctxInner.layer, red);
      expect(ctxInner.color, encodeColor(const IndexedColor(1)),
          reason: "layer red's own colour, not layer 0's ACI 7");
      expect(resolver.styleFor(slot, ctxInner).argb, 0xFFFF0000);
    });

    test('ByLayer transparency comes from the layer record, not the context',
        () {
      final doc = DraftDocument.empty();
      final h = addLine(doc, doc.rootHandle,
          layer: ReservedHandles.layerZero, color: const IndexedColor(2));
      final slot = doc.entities.slotOf(h)!;

      final ctx = StyleContext.documentRoot.copyWith(transparency: 64);
      final style = DocumentStyleResolver(doc).styleFor(slot, ctx);

      expect(style.argb >> 24, 255,
          reason: "layer 0's transparency is 0, so the entity stays opaque");
    });

    test("layer 0's default-lineweight sentinel never leaks into the style",
        () {
      // Layer 0 ships with `kLineweightDefault`, a sentinel, not a width. Now
      // that its record is read rather than skipped, the sentinel must still
      // resolve through the context.
      final doc = DraftDocument.empty();
      final h = addLine(doc, doc.rootHandle,
          layer: ReservedHandles.layerZero, color: const IndexedColor(2));
      final slot = doc.entities.slotOf(h)!;

      final style =
          DocumentStyleResolver(doc).styleFor(slot, StyleContext.documentRoot);

      expect(style.lineweightHundredths, StyleContext.documentRoot.lineweight);
      expect(style.lineweightHundredths, isNot(kLineweightDefault));
    });
  });

  group('transparency', () {
    test("an entity's own transparency becomes the alpha channel", () {
      final doc = DraftDocument.empty();
      final h = addLine(doc, doc.rootHandle,
          layer: ReservedHandles.layerZero,
          color: const IndexedColor(2),
          transparency: 64);
      final slot = doc.entities.slotOf(h)!;

      final style =
          DocumentStyleResolver(doc).styleFor(slot, StyleContext.documentRoot);

      // 0 is opaque in DXF: alpha = 255 - transparency.
      expect(style.argb >> 24, 191);
      expect(style.argb & 0xFFFFFF, 0xFFFF00, reason: 'ACI 2 is yellow');
    });

    test('ByBlock transparency takes the context', () {
      final doc = DraftDocument.empty();
      final h = addLine(doc, doc.rootHandle,
          layer: ReservedHandles.layerZero,
          color: const IndexedColor(2),
          transparency: kByBlock);
      final slot = doc.entities.slotOf(h)!;

      final ctx = StyleContext.documentRoot.copyWith(transparency: 64);
      expect(DocumentStyleResolver(doc).styleFor(slot, ctx).argb >> 24, 191);
    });

    test('a layer record with transparency reaches the alpha channel', () {
      final doc = DraftDocument.empty();
      final hazy = addLayer(doc, const Handle(100), 'hazy',
          color: const IndexedColor(2), transparency: 90);
      final h = addLine(doc, doc.rootHandle,
          layer: hazy, color: const IndexedColor(2));
      final slot = doc.entities.slotOf(h)!;

      final style =
          DocumentStyleResolver(doc).styleFor(slot, StyleContext.documentRoot);

      expect(style.argb >> 24, 165);
    });
  });

  group('aciToRgb', () {
    test('the nine fixed colours are exact', () {
      expect(aciToRgb(1), 0xFF0000, reason: 'red');
      expect(aciToRgb(2), 0xFFFF00, reason: 'yellow');
      expect(aciToRgb(3), 0x00FF00, reason: 'green');
      expect(aciToRgb(4), 0x00FFFF, reason: 'cyan');
      expect(aciToRgb(5), 0x0000FF, reason: 'blue');
      expect(aciToRgb(6), 0xFF00FF, reason: 'magenta');
      expect(aciToRgb(7), 0xFFFFFF, reason: 'white');
      expect(aciToRgb(8), 0x808080, reason: 'dark grey');
      expect(aciToRgb(9), 0xC0C0C0, reason: 'light grey');
    });

    test('250..255 is the grey ramp', () {
      expect(aciToRgb(250), 0x333333);
      expect(aciToRgb(255), 0xDDDDDD);
      for (var aci = 250; aci <= 255; aci++) {
        final rgb = aciToRgb(aci);
        expect(rgb & 0xFF, (rgb >> 8) & 0xFF, reason: 'grey: r == g == b');
        expect(rgb & 0xFF, (rgb >> 16) & 0xFF, reason: 'grey: r == g == b');
      }
    });

    test('the 240-colour cube stays inside 24 bits and is total', () {
      for (var aci = 10; aci <= 249; aci++) {
        final rgb = aciToRgb(aci);
        expect(rgb, greaterThanOrEqualTo(0));
        expect(rgb, lessThanOrEqualTo(0xFFFFFF));
      }
    });
  });
}
