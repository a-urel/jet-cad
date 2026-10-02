// Spec 12b D8: on every DocChange the selection drops a key, and the hover,
// whose target's effective layer is hidden or locked — a root entity's own
// (a drafted region's is its boundary's), an ATTRIB's instance's when it is
// on layer 0, an instance's own, a parametric object's `objectLayer` — and
// keeps one whose layer is neither.
//
// The parametric object is the fixture's root group carrying an
// `ObjectLayer`: the selection reads the engine's `objectLayer` on a group
// key, and the render package registers no parametric type, so no
// regeneration runs here (the stamp is the engine's, pinned by
// `object_layer_test.dart`).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';

import '../support/layer_fixture.dart';

SelectionKey key(Handle h) => SelectionKey.root(h);

/// Runs [command] and lets the selection hear its `DocChange`.
Future<void> run(LayerFixture f, DraftCommand command) async {
  f.doc.commands.execute(command);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late LayerFixture f;
  late SelectionController selection;
  late int notified;

  setUp(() {
    f = LayerFixture();
    selection = SelectionController(f.doc);
    addTearDown(selection.dispose);
    notified = 0;
    selection.addListener(() => notified++);
  });

  /// One key per kind of target, every one on A or substituted to A.
  Set<SelectionKey> onA() => {
        key(f.rootA),
        key(f.instance),
        key(f.attrib),
        key(f.object),
        key(f.regionFill),
      };

  test('hiding A drops every key on A, and keeps the one on layer 0', () async {
    selection.replace({...onA(), key(f.rootZero)});
    notified = 0;
    await run(f, SetLayerCommand(f.withState(f.a, visible: false)));
    expect(selection.keys, {key(f.rootZero)});
    expect(notified, 1);
  });

  test('locking A drops every key on A, and keeps the one on layer 0',
      () async {
    selection.replace({...onA(), key(f.rootZero)});
    await run(f, SetLayerCommand(f.withState(f.a, locked: true)));
    expect(selection.keys, {key(f.rootZero)});
  });

  test(
      'a change that leaves A visible and unlocked keeps every key, and '
      'notifies nothing', () async {
    selection.replace({...onA(), key(f.rootZero)});
    notified = 0;
    // A recolour of A, a show of C and a move of a line no key names: none
    // touches what is selected.
    await run(f,
        SetLayerCommand(f.layer(f.a).copyWith(color: const IndexedColor(6))));
    await run(f, SetLayerCommand(f.withState(f.c, visible: true)));
    await run(f, SetEntityLayerCommand(f.lineZero, f.c));
    expect(selection.keys, {...onA(), key(f.rootZero)});
    expect(notified, 0);
  });

  test(
      'hiding layer 0 drops the root entity on it, and keeps the instance on '
      'A, its ATTRIB on layer 0 (by its instance) and the object on A',
      () async {
    selection.replace({...onA(), key(f.rootZero)});
    // Layer 0 is the effective current layer, which cannot be hidden.
    await run(f, SetCurrentLayerCommand(f.b));
    await run(
        f,
        SetLayerCommand(
            f.withState(ReservedHandles.layerZero, visible: false)));
    expect(selection.keys, onA());
  });

  test(
      'moving an instance to the hidden layer drops it and its ATTRIB; undo '
      'brings neither back (the selection is not undone)', () async {
    selection.replace({key(f.instance), key(f.attrib), key(f.rootA)});
    await run(f, SetInstanceLayerCommand(f.instance, f.c));
    expect(selection.keys, {key(f.rootA)});
    f.doc.commands.undo();
    await Future<void>.delayed(Duration.zero);
    expect(selection.keys, {key(f.rootA)});
  });

  test('moving the object to the locked layer drops its group key', () async {
    selection.replace({key(f.object), key(f.rootA)});
    await run(f, SetComponentCommand<ObjectLayer>(f.object, ObjectLayer(f.b)));
    expect(selection.keys, {key(f.rootA)});
  });

  test(
      'a region picked on its fill follows its boundary\'s layer: the '
      'boundary on the locked layer drops it', () async {
    selection.replace({key(f.regionFill), key(f.rootA)});
    await run(f, SetEntityLayerCommand(f.regionBoundary, f.b));
    expect(f.doc.entities.layerAt(f.doc.entities.slotOf(f.regionFill)!), f.a);
    expect(selection.keys, {key(f.rootA)});
  });

  test(
      'a region picked on its fill follows its boundary\'s layer: the fill '
      'alone on the hidden layer keeps it', () async {
    selection.replace({key(f.regionFill), key(f.rootA)});
    await run(f, SetEntityLayerCommand(f.regionFill, f.c));
    expect(selection.keys, {key(f.regionFill), key(f.rootA)});
  });

  test(
      'the hover is dropped when its layer is hidden, and kept when another '
      'layer is', () async {
    selection.setHover(key(f.rootZero));
    await run(f, SetLayerCommand(f.withState(f.a, visible: false)));
    expect(selection.hover, key(f.rootZero));

    selection.setHover(key(f.instance));
    await run(f, SetLayerCommand(f.withState(f.a, visible: true)));
    expect(selection.hover, key(f.instance));
    notified = 0;
    await run(f, SetLayerCommand(f.withState(f.a, locked: true)));
    expect(selection.hover, isNull);
    expect(notified, 1);
  });

  test('a key on a layer the table does not have is kept', () async {
    const ghost = Handle(0x6A6A);
    selection.replace({key(f.rootA)});
    await run(f, SetEntityLayerCommand.restore(f.rootA, ghost));
    expect(selection.keys, {key(f.rootA)});
  });
}
