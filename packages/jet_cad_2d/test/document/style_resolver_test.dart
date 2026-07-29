import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, Handle owner,
    {required Handle layer,
    required DraftColor color,
    int lineweight = kByLayer}) {
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
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

void main() {
  test('ByLayer resolves against the entity layer, not the context layer', () {
    final doc = DraftDocument.empty();
    const red = Handle(100);
    doc.tables.layers.add(const LayerRecord(
      handle: red,
      name: 'red',
      color: IndexedColor(1),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 0,
      visible: true,
      locked: false,
    ));
    final h =
        addLine(doc, doc.rootHandle, layer: red, color: const ByLayerColor());
    final slot = doc.entities.slotOf(h)!;

    final resolver = DocumentStyleResolver(doc);
    final style = resolver.styleFor(slot, StyleContext.documentRoot);

    expect(style.argb, 0xFF000000 | aciToRgb(1));
    expect(style.lineweightHundredths, 50);
  });

  test('ByBlock resolves against the context, and layer-0 inherits it', () {
    // A definition's contents authored ByBlock on layer 0 are the whole point
    // of the block model: 500 instances share one geometry and each renders in
    // its own colour. If this resolves against the layer table instead, every
    // instance renders identically and the picture cache in 3b would be keyed
    // on a context that changes nothing.
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'sym',
        basePoint: Vector2.zero(),
        children: const []));
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
    expect(style.argb, 0xFF000000 | aciToRgb(3));
  });

  test('two levels of nesting compose contexts outward-in', () {
    // The inner instance is authored ByBlock, so it must take the OUTER
    // instance's concrete colour, not fall back to a default. A fixture with
    // one nesting level cannot tell the two apart.
    final doc = DraftDocument.empty();
    const inner = Handle(300), outer = Handle(301);
    doc.tree.addDefinition(Definition(
        handle: inner,
        name: 'inner',
        basePoint: Vector2.zero(),
        children: const []));
    doc.tree.addDefinition(Definition(
        handle: outer,
        name: 'outer',
        basePoint: Vector2.zero(),
        children: const []));
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
      color: const ByBlockColor(),
    )));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: outerNode,
      parent: doc.rootHandle,
      transform: Transform2.translation(3, 4),
      definition: outer,
      layer: ReservedHandles.layerZero,
      color: const IndexedColor(5),
    )));

    final resolver = DocumentStyleResolver(doc);
    final ctxOuter = resolver.contextFor(outerNode, StyleContext.documentRoot);
    final ctxInner = resolver.contextFor(innerNode, ctxOuter);

    expect(resolver.styleFor(slot, ctxInner).argb, 0xFF000000 | aciToRgb(5));
  });

  test('transparency becomes the alpha channel', () {
    final doc = DraftDocument.empty();
    final h = addLine(doc, doc.rootHandle,
        layer: ReservedHandles.layerZero, color: const IndexedColor(2));
    final slot = doc.entities.slotOf(h)!;
    // 0 is opaque in DXF: alpha = 255 - transparency.
    final ctx = StyleContext.documentRoot.copyWith(transparency: 64);
    expect(DocumentStyleResolver(doc).styleFor(slot, ctx).argb >> 24, 255 - 64);
  });
}
