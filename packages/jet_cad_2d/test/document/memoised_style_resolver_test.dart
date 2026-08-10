import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Counts what reaches the resolver underneath, so a memo can be shown to be
/// answering rather than merely agreeing.
class CountingResolver implements StyleResolver {
  CountingResolver(this.inner);
  final StyleResolver inner;
  int styleCalls = 0;
  int contextCalls = 0;

  @override
  StyleContext contextFor(Handle instance, StyleContext inherited) {
    contextCalls++;
    return inner.contextFor(instance, inherited);
  }

  @override
  ResolvedStyle styleFor(int slot, StyleContext ctx) {
    styleCalls++;
    return inner.styleFor(slot, ctx);
  }
}

Handle addLine(DraftDocument doc, Handle owner, Handle layer,
    {DraftColor color = const ByLayerColor()}) {
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
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList([0, 0, 1, 1]), scalars: Float64List(0)),
  ));
  return handle;
}

Handle addLayer(DraftDocument doc, String name, int aci) {
  final handle = doc.handleSeed.next();
  doc.tables.layers.add(LayerRecord(
    handle: handle,
    name: name,
    color: IndexedColor(aci),
    linetype: ReservedHandles.continuousLinetype,
    lineweight: 25,
    transparency: 0,
  ));
  return handle;
}

void main() {
  test('agrees with the resolver it wraps, on every entity', () {
    // The memo is only worth measuring if it is the same answer faster. Two
    // layers and a ByBlock entity, so more than one resolution path runs.
    final doc = DraftDocument.empty();
    final other = addLayer(doc, 'other', 3);
    const definition = Handle(700);
    doc.tree.addDefinition(Definition(
        handle: definition,
        name: 'd',
        basePoint: Vector2.zero(),
        children: const []));
    addLine(doc, definition, ReservedHandles.layerZero,
        color: const ByBlockColor());
    addLine(doc, doc.rootHandle, other);
    addLine(doc, doc.rootHandle, ReservedHandles.layerZero,
        color: const IndexedColor(5));

    final plain = DocumentStyleResolver(doc);
    final memo = MemoisedStyleResolver(plain);
    const contexts = [
      StyleContext.documentRoot,
      StyleContext(
        color: 5,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        lineweight: 50,
        transparency: 0,
        layer: ReservedHandles.layerZero,
      ),
    ];

    for (final ctx in contexts) {
      for (final slot in doc.entities.liveSlots) {
        expect(memo.styleFor(slot, ctx), plain.styleFor(slot, ctx));
      }
    }
  });

  test('a repeat is answered without reaching the resolver', () {
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, ReservedHandles.layerZero);
    final counting = CountingResolver(DocumentStyleResolver(doc));
    final memo = MemoisedStyleResolver(counting);
    final slot = doc.entities.liveSlots.first;

    memo.styleFor(slot, StyleContext.documentRoot);
    memo.styleFor(slot, StyleContext.documentRoot);
    memo.styleFor(slot, StyleContext.documentRoot);

    expect(counting.styleCalls, 1);
  });

  test('the context is part of the key, not just the slot', () {
    // The whole point of the resolver is that one entity has different paint
    // under different instances. A memo keyed on the slot alone would give the
    // second instance the first one's colour, and every structural test in the
    // suite would still pass.
    final doc = DraftDocument.empty();
    const definition = Handle(700);
    doc.tree.addDefinition(Definition(
        handle: definition,
        name: 'd',
        basePoint: Vector2.zero(),
        children: const []));
    addLine(doc, definition, ReservedHandles.layerZero,
        color: const ByBlockColor());
    final slot = doc.entities.liveSlots.first;
    final memo = MemoisedStyleResolver(DocumentStyleResolver(doc));

    StyleContext ctxWithColor(int color) => StyleContext(
          color: color,
          linetype: ReservedHandles.continuousLinetype,
          linetypeScale: 1.0,
          lineweight: 50,
          transparency: 0,
          layer: ReservedHandles.layerZero,
        );

    final red = memo.styleFor(slot, ctxWithColor(1));
    final green = memo.styleFor(slot, ctxWithColor(3));
    expect(red.argb, isNot(green.argb));
  });

  test('two contexts that resolve alike share one entry', () {
    // Value equality on the key, not identity. Two containers can hand down
    // equal contexts, and a memo keyed by identity would miss on every one of
    // them while still being correct — which is the failure that shows up as
    // "the memo bought nothing" rather than as a wrong picture.
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, ReservedHandles.layerZero);
    final counting = CountingResolver(DocumentStyleResolver(doc));
    final memo = MemoisedStyleResolver(counting);
    final slot = doc.entities.liveSlots.first;

    StyleContext fresh() => StyleContext(
          color: 7,
          linetype: ReservedHandles.continuousLinetype,
          linetypeScale: 1.0,
          lineweight: 50,
          transparency: 0,
          layer: ReservedHandles.layerZero,
        );

    memo.styleFor(slot, fresh());
    memo.styleFor(slot, fresh());

    expect(counting.styleCalls, 1);
  });

  test('contextFor is memoised too, and keyed on the inherited context', () {
    final doc = DraftDocument.empty();
    const definition = Handle(700);
    doc.tree.addDefinition(Definition(
        handle: definition,
        name: 'd',
        basePoint: Vector2.zero(),
        children: const []));
    const instance = Handle(701);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.translation(1, 2),
      definition: definition,
      layer: ReservedHandles.layerZero,
      color: const ByBlockColor(),
    )));

    final counting = CountingResolver(DocumentStyleResolver(doc));
    final memo = MemoisedStyleResolver(counting);
    StyleContext inherited(int color) => StyleContext(
          color: color,
          linetype: ReservedHandles.continuousLinetype,
          linetypeScale: 1.0,
          lineweight: 50,
          transparency: 0,
          layer: ReservedHandles.layerZero,
        );

    memo.contextFor(instance, inherited(1));
    memo.contextFor(instance, inherited(1));
    expect(counting.contextCalls, 1);

    expect(memo.contextFor(instance, inherited(3)).color, 3,
        reason: 'a ByBlock instance takes the colour handed down to it');
    expect(counting.contextCalls, 2);
  });

  test('clear drops everything', () {
    // The documented hazard has one escape: a caller that knows a layer record
    // or an instance colour changed must be able to say so.
    final doc = DraftDocument.empty();
    addLine(doc, doc.rootHandle, ReservedHandles.layerZero);
    final counting = CountingResolver(DocumentStyleResolver(doc));
    final memo = MemoisedStyleResolver(counting);
    final slot = doc.entities.liveSlots.first;

    memo.styleFor(slot, StyleContext.documentRoot);
    memo.clear();
    memo.styleFor(slot, StyleContext.documentRoot);

    expect(counting.styleCalls, 2);
  });
}
