import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

Handle addLine(DraftDocument doc, List<double> coords) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
        handle: handle,
        owner: doc.rootHandle,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.byLayerLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: kByLayer,
        transparency: kByLayer,
        flags: 0),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
  return handle;
}

void main() {
  test('a components-only edit on the root reconciles nothing', () {
    // M-04r (the skip removed) and M-04s (the dispatcher always says
    // geometry): both make rebuildCount grow here.
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    addLine(doc, [990, 500, 1010, 500]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;
    final page = PageComponent(originX: 7350, originY: -1230);

    doc.commands
        .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle, page.copyWith(gridVisible: false)));
    doc.commands.undo();
    doc.commands.redo();

    expect(index.rebuildCount, before);
    expect(doc.components.get<PageComponent>(doc.rootHandle),
        page.copyWith(gridVisible: false));
  });

  test('the change carries the capability of the command that made it', () {
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    final seen = <Capability>[];
    doc.commands.onAfterMutate = (change) {
      if (change
          case CommandApplied(:final capability) ||
              CommandUndone(:final capability) ||
              CommandRedone(:final capability)) {
        seen.add(capability);
      }
    };
    doc.commands.execute(
        SetComponentCommand<PageComponent>(doc.rootHandle, PageComponent()));
    addLine(doc, [1, 2, 3, 4]);
    doc.commands.undo();
    doc.commands.undo();
    doc.commands.redo();
    expect(seen, [
      Capability.components,
      Capability.geometry,
      Capability.geometry,
      Capability.components,
      Capability.components,
    ]);
  });

  test('a compound with one geometry member still reconciles', () {
    // The summary capability: components-only skips, mixed does not.
    final doc = DraftDocument.empty();
    PageComponent.register(doc.components);
    final line = addLine(doc, [990, 500, 1010, 500]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final before = index.rebuildCount;
    doc.commands.execute(CompoundCommand([
      SetComponentCommand<PageComponent>(doc.rootHandle, PageComponent()),
      RemoveEntityCommand(line),
    ], label: 'mixed'));
    expect(index.rebuildCount, greaterThan(before));
  });

  test(
      'the default capability is geometry, so old construction sites keep '
      'their meaning', () {
    const change = CommandApplied(label: 'x', touched: {Handle(7)});
    expect(change.capability, Capability.geometry);
  });
}
