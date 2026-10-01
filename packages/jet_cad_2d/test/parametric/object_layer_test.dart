// Spec 12b D2: a parametric object's layer is its group's `ObjectLayer`,
// stamped by the regeneration onto every child, added or matched (the one
// column 06 D11 / 10 D13 now rewrite on a match), and detached with the
// object by 06 D8's cleanup and 10 D15's dissolve.
//
// Fixture (plan P-6): layers A (ACI 1), B (ACI 5, locked) and C (ACI 3,
// hidden) beside a visible layer 0; every object sits in a turned group off
// the origin (the parametric catalog's `atA`, `atB`, `parked`).
import 'dart:convert';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/clients.dart';
import 'support/fixture.dart';

const Handle hT = Handle(3000); // a Caption
const Handle hF = Handle(4000); // a Fuse
const Handle hP = Handle(5000); // a Pin

const RegionRect regions = RegionRect(900.5, 600.25, 2);
const Caption caption = Caption('Kitchen', 120.5, 80.25);
const Fuse fuse = Fuse(150.5, -80.25, 900.5, 600.75);

class _Scene {
  _Scene() : doc = paramDoc() {
    a = _addLayer('A', 1);
    b = _addLayer('B', 5, locked: true);
    c = _addLayer('C', 3, visible: false);
  }

  /// [doc] (a reload of [of]'s document) read with [of]'s layers.
  _Scene.over(this.doc, _Scene of) {
    a = of.a;
    b = of.b;
    c = of.c;
  }

  final DraftDocument doc;
  late final Handle a;
  late final Handle b;
  late final Handle c;

  Handle _addLayer(String name, int aci,
      {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers.add(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    ));
    return handle;
  }

  /// Creates [h] with [params], and with `ObjectLayer(layer)` in the same
  /// compound when [layer] is given (as a tool does).
  void add<T extends Component>(Handle h, Transform2 at, T params,
      {Handle? layer}) {
    final created = create(doc, h, at, params) as CompoundCommand;
    doc.commands.execute(CompoundCommand([
      ...created.children,
      if (layer != null)
        SetComponentCommand<ObjectLayer>(h, ObjectLayer(layer)),
    ], label: 'Add object'));
  }

  /// D2's move of an object: one `SetComponentCommand<ObjectLayer>`.
  void move(Handle h, Handle? layer) =>
      doc.commands.execute(SetComponentCommand<ObjectLayer>(
          h, layer == null ? null : ObjectLayer(layer)));

  Handle layerOf(Handle child) =>
      doc.entities.layerAt(doc.entities.slotOf(child)!);

  EntityKind kindOf(Handle child) =>
      doc.entities.kindAt(doc.entities.slotOf(child)!);

  /// Asserts [group] has children and that every one is on [layer].
  void expectOn(Handle group, Handle layer) {
    final children = kids(doc, group);
    expect(children, isNotEmpty, reason: 'children of ${group.toHex()}');
    for (final k in children) {
      expect(layerOf(k), layer,
          reason: '${kindOf(k).name} ${k.toHex()} of ${group.toHex()}');
    }
  }

  /// [group]'s fills, ascending.
  List<Handle> fills(Handle group) => [
        for (final k in kids(doc, group))
          if (kindOf(k) == EntityKind.fill) k,
      ];

  /// The boundary [fill] names.
  Handle boundaryOf(Handle fill) => Handle(doc.geometry
      .read(doc.entities.geomIndexAt(doc.entities.slotOf(fill)!))
      .scalars[0]
      .toInt());

  /// Asserts every region of [group] has its fill and its boundary on
  /// [layer], each on its own, and that there are [count] regions.
  void expectRegionsOn(Handle group, Handle layer, int count) {
    final f = fills(group);
    expect(f, hasLength(count));
    for (final fill in f) {
      expect(layerOf(fill), layer, reason: 'fill ${fill.toHex()}');
      final boundary = boundaryOf(fill);
      expect(layerOf(boundary), layer, reason: 'boundary ${boundary.toHex()}');
    }
  }
}

/// [doc]'s state for an undo comparison: [canon] without the handle seed,
/// which only rises (an undone add leaves it where the add put it).
String state(DraftDocument doc, {bool sortNodes = false}) {
  final j = jsonDecode(canon(doc, sortNodes: sortNodes)) as Map<String, Object?>
    ..remove('handleSeed');
  return jsonEncode(j);
}

/// The select tool's delete of one object: its children, then its node.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// Every command inside [c], compounds and replays opened.
Iterable<DraftCommand> flatten(DraftCommand c) sync* {
  yield c;
  if (c is CompoundCommand) {
    for (final k in c.children) {
      yield* flatten(k);
    }
  } else if (c is ParametricReplay) {
    yield* flatten(c.replay);
  }
}

/// [doc]'s copy, [command] expanded and applied on it outside the
/// dispatcher: the edit (its capability, read after apply) and the inverse
/// the history would record, the top undo entry's `ParametricReplay`.
(ParametricEdit, ParametricReplay) planOnCopy(
    DraftDocument doc, DraftCommand Function(DraftDocument copy) command) {
  final copy = reload(enc(doc));
  final edit = copy.commands.expander!(command(copy)) as ParametricEdit;
  final inverse = edit.apply(copy).inverse as ParametricReplay;
  return (edit, inverse);
}

/// The capability of each `CommandApplied` that [run] causes.
Future<List<Capability>> appliedCapabilities(
    DraftDocument doc, void Function() run) async {
  await pumpEventQueue();
  final out = <Capability>[];
  final sub = doc.changes.listen((c) {
    if (c is CommandApplied) out.add(c.capability);
  });
  run();
  await pumpEventQueue();
  await sub.cancel();
  return out;
}

List<Diagnostic> missingLayerWarnings(DraftDocument doc) => [
      for (final d in doc.validate())
        if (d.code == ValidationCodes.objectLayerMissing) d,
    ];

void main() {
  test(
      'OL1 added children: an object created with its ObjectLayer has every '
      'child on that layer, a region\'s fill and boundary and a TEXT included',
      () {
    final s = _Scene();
    s.add(hA, atA, const ClipRect(2000, 1000), layer: s.a);
    s.add(hB, parked, regions, layer: s.b);
    s.add(hT, onA(4000.5, -2500.25, 0.4), caption, layer: s.c);
    s.expectOn(hA, s.a);
    s.expectOn(hB, s.b);
    s.expectRegionsOn(hB, s.b, 2);
    s.expectOn(hT, s.c);
    expect(s.kindOf(kids(s.doc, hT).single), EntityKind.text);
  });

  test(
      'OL2 move then edit: the move restamps every matched child, and an '
      'edit that adds children and matches others keeps them all on the '
      'object\'s layer; undo and redo of each', () {
    final s = _Scene();
    s.add(hA, atA, const ClipRect(2000, 1000));
    s.add(hB, atB, const ClipRect(400, 900));
    s.doc.commands.clearHistory();
    s.expectOn(hA, ReservedHandles.layerZero);
    final before = state(s.doc);
    final children = kids(s.doc, hA);

    s.move(hA, s.a);
    // Every child is matched (the payloads did not change): same handles.
    expect(kids(s.doc, hA), children);
    s.expectOn(hA, s.a);
    s.expectOn(hB, ReservedHandles.layerZero);
    final moved = state(s.doc);

    // Narrow A so B no longer pierces its top edge: A's top edge stops
    // splitting, so one child goes and the rest are matched.
    s.doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2000, 600.5)));
    expect(kids(s.doc, hA), hasLength(4));
    s.expectOn(hA, s.a);
    // Widen it back past B: an added piece and matched edges.
    s.doc.commands.execute(
        SetComponentCommand<ClipRect>(hA, const ClipRect(2100.25, 1000)));
    expect(kids(s.doc, hA), hasLength(5));
    s.expectOn(hA, s.a);
    final edited = state(s.doc);

    s.doc.commands.undo();
    s.doc.commands.undo();
    expect(state(s.doc), moved);
    s.doc.commands.undo();
    expect(state(s.doc), before);
    expect(s.doc.components.get<ObjectLayer>(hA), isNull);
    s.expectOn(hA, ReservedHandles.layerZero);
    s.doc.commands.redo();
    expect(state(s.doc), moved);
    s.doc.commands.redo();
    s.doc.commands.redo();
    expect(state(s.doc), edited);
  });

  test(
      'OL3 regions: a move restamps a matched region\'s fill and its '
      'boundary each, an added region lands on the layer, and a second '
      'move restamps both again; undo and redo', () {
    final s = _Scene();
    s.add(hB, parked, regions);
    s.doc.commands.clearHistory();
    final before = state(s.doc);
    s.expectRegionsOn(hB, ReservedHandles.layerZero, 2);

    s.move(hB, s.a);
    s.expectRegionsOn(hB, s.a, 2);
    s.expectOn(hB, s.a);

    s.doc.commands.execute(SetComponentCommand<RegionRect>(
        hB, const RegionRect(900.5, 600.25, 3)));
    s.expectRegionsOn(hB, s.a, 3);
    s.expectOn(hB, s.a);

    s.move(hB, s.b);
    s.expectRegionsOn(hB, s.b, 3);
    s.expectOn(hB, s.b);
    final last = state(s.doc);

    s.doc.commands.undo();
    s.expectRegionsOn(hB, s.a, 3);
    s.doc.commands.undo();
    s.doc.commands.undo();
    expect(state(s.doc), before);
    s.doc.commands.redo();
    s.doc.commands.redo();
    s.doc.commands.redo();
    expect(state(s.doc), last);
  });

  test(
      'OL3b a region whose fill and boundary disagree (a file\'s state) is '
      'restamped record by record: after a save and load, a regenerating '
      'edit moves only the boundaries onto the object\'s layer', () {
    final s = _Scene();
    s.add(hB, parked, regions, layer: s.a);
    s.expectRegionsOn(hB, s.a, 2);
    // A file's state: every boundary on layer 0, every fill on A.
    for (final fill in s.fills(hB)) {
      final slot = s.doc.entities.slotOf(s.boundaryOf(fill))!;
      s.doc.entities.replace(slot,
          s.doc.entities.read(slot).copyWith(layer: ReservedHandles.layerZero));
    }
    final loaded = reload(enc(s.doc));
    final l = _Scene.over(loaded, s);
    for (final fill in l.fills(hB)) {
      expect(l.layerOf(fill), s.a);
      expect(l.layerOf(l.boundaryOf(fill)), ReservedHandles.layerZero);
    }
    loaded.commands.execute(SetComponentCommand<RegionRect>(
        hB, const RegionRect(950.5, 600.25, 2)));
    l.expectRegionsOn(hB, s.a, 2);
    l.expectOn(hB, s.a);
  });

  test(
      'OL4 a TEXT child: the move restamps it, a string edit keeps it on the '
      'layer; undo and redo', () {
    final s = _Scene();
    s.add(hT, onA(400.5, -250.25, 0.4), caption);
    s.doc.commands.clearHistory();
    final text = kids(s.doc, hT).single;
    expect(s.kindOf(text), EntityKind.text);
    s.move(hT, s.c);
    expect(kids(s.doc, hT), [text]);
    expect(s.layerOf(text), s.c);
    s.doc.commands.execute(SetComponentCommand<Caption>(
        hT, const Caption('Pantry', 120.5, 80.25)));
    expect(kids(s.doc, hT), [text]);
    expect(s.doc.entities.textAt(s.doc.entities.slotOf(text)!), 'Pantry');
    expect(s.layerOf(text), s.c);
    s.doc.commands.undo();
    s.doc.commands.undo();
    expect(s.layerOf(text), ReservedHandles.layerZero);
    s.doc.commands.redo();
    expect(s.layerOf(text), s.c);
  });

  test(
      'OL5 a neighbour edit: editing B regenerates A, whose added and '
      'matched children stay on A\'s layer, and B\'s on B\'s; undo and redo',
      () {
    final s = _Scene();
    s.add(hA, atA, const ClipRect(2000, 1000));
    s.add(hB, atB, const ClipRect(400, 900), layer: s.b);
    s.move(hA, s.a);
    s.doc.commands.clearHistory();
    final before = state(s.doc);
    expect(kids(s.doc, hA), hasLength(5));

    // B moved off A's top edge onto its right edge: A's top edge is whole
    // again (removed piece) and its right edge splits (added piece).
    s.doc.commands.execute(TransformNodeCommand(hB, onA(1800, 300, 0.3)));
    s.expectOn(hA, s.a);
    s.expectOn(hB, s.b);
    final after = state(s.doc);
    expect(after, isNot(before));
    s.doc.commands.undo();
    expect(state(s.doc), before);
    s.doc.commands.redo();
    expect(state(s.doc), after);
  });

  test(
      'OL6 no ObjectLayer means layer 0: a new object without one, and a '
      'moved object whose component is detached, regenerate on layer 0', () {
    final s = _Scene();
    s.add(hA, atA, const ClipRect(2000, 1000));
    s.expectOn(hA, ReservedHandles.layerZero);
    s.add(hB, parked, regions, layer: s.a);
    s.expectRegionsOn(hB, s.a, 2);
    s.move(hB, null);
    expect(s.doc.components.get<ObjectLayer>(hB), isNull);
    s.expectOn(hB, ReservedHandles.layerZero);
    s.expectRegionsOn(hB, ReservedHandles.layerZero, 2);
  });

  test(
      'OL7 an ObjectLayer naming a missing layer is kept as stored, '
      'regenerates on layer 0 and is diagnosed', () {
    final s = _Scene();
    const ghost = Handle(0x6A6A);
    s.add(hA, atA, const ClipRect(2000, 1000), layer: ghost);
    s.expectOn(hA, ReservedHandles.layerZero);
    expect(s.doc.components.get<ObjectLayer>(hA), const ObjectLayer(ghost));

    // An object on A whose layer the table loses (as a file can): the next
    // regeneration moves its matched children to layer 0.
    s.add(hB, parked, regions, layer: s.a);
    s.expectOn(hB, s.a);
    s.doc.tables.layers.remove(s.a);
    s.doc.commands.execute(SetComponentCommand<RegionRect>(
        hB, const RegionRect(900.5, 600.25, 3)));
    s.expectOn(hB, ReservedHandles.layerZero);
    s.expectRegionsOn(hB, ReservedHandles.layerZero, 3);
    expect(s.doc.components.get<ObjectLayer>(hB), ObjectLayer(s.a));
    expect(
        [for (final d in missingLayerWarnings(s.doc)) d.handles],
        unorderedEquals([
          [hA, ghost],
          [hB, s.a]
        ]));
    expect(missingLayerWarnings(s.doc).map((d) => d.severity),
        everyElement(DiagnosticSeverity.warning));
  });

  /// Three objects, each on a layer other than 0, and nothing to move.
  _Scene unmoved() {
    final s = _Scene();
    s.add(hA, atA, const SoftRect(2000, 1000), layer: s.a);
    s.add(hB, parked, regions, layer: s.b);
    s.add(hT, onA(4000.5, -2500.25, 0.4), caption, layer: s.c);
    return s;
  }

  test(
      'OL8a an edit that leaves layers alone plans no layer command (S-10): '
      'the replay of a geometry edit of each child kind holds none', () {
    final s = unmoved();
    // The plan rewrites payloads (and a string), and moves no layer.
    for (final edit in <DraftCommand>[
      SetComponentCommand<SoftRect>(hA, const SoftRect(2200.5, 1000)),
      SetComponentCommand<RegionRect>(hB, const RegionRect(950.25, 600.25, 2)),
      SetComponentCommand<Caption>(hT, const Caption('Hall', 130.5, 80.25)),
    ]) {
      final (_, replay) = planOnCopy(s.doc, (_) => edit);
      final commands = flatten(replay).toList();
      expect(commands.whereType<SetEntityGeometryCommand>(), isNotEmpty,
          reason: edit.toString());
      expect(commands.whereType<SetEntityLayerCommand>(), isEmpty,
          reason: edit.toString());
    }
  });

  test(
      'OL8b a components edit whose regeneration output is unchanged reports '
      'components (S-10); a real move reports geometry', () async {
    final s = unmoved();
    final (edit, _) = planOnCopy(s.doc,
        (_) => SetComponentCommand<SoftRect>(hA, const SoftRect(2000, 1000)));
    expect(edit.capability, Capability.components);
    expect(
        await appliedCapabilities(
            s.doc,
            () => s.doc.commands.execute(
                SetComponentCommand<SoftRect>(hA, const SoftRect(2000, 1000)))),
        [Capability.components]);
    expect(
        await appliedCapabilities(
            s.doc,
            () => s.doc.commands.execute(
                SetComponentCommand<ObjectLayer>(hB, ObjectLayer(s.b)))),
        [Capability.components]);
    // A real move reports geometry (D1: a layer move changes pixels).
    expect(await appliedCapabilities(s.doc, () => s.move(hB, s.a)),
        [Capability.geometry]);
  });

  test(
      'OL9 detach on delete (S-1): deleting the last object on A detaches '
      'its ObjectLayer, so deleting A leaves no warning; undo restores the '
      'component and the layer', () {
    final s = _Scene();
    s.add(hA, atA, const ClipRect(2000, 1000), layer: s.a);
    s.add(hB, parked, regions, layer: s.b);
    s.doc.commands.clearHistory();
    final before = state(s.doc, sortNodes: true);

    s.doc.commands.execute(deleteObject(s.doc, hA));
    expect(s.doc.tree[hA], isNull);
    expect(s.doc.components.get<ObjectLayer>(hA), isNull);
    expect(s.doc.components.get<ObjectLayer>(hB), ObjectLayer(s.b));
    s.doc.commands.execute(RemoveLayerCommand(s.a));
    expect(s.doc.tables.layers.contains(s.a), isFalse);
    expect(missingLayerWarnings(s.doc), isEmpty);

    s.doc.commands.undo();
    s.doc.commands.undo();
    expect(s.doc.components.get<ObjectLayer>(hA), ObjectLayer(s.a));
    s.expectOn(hA, s.a);
    expect(state(s.doc, sortNodes: true), before);
    s.doc.commands.redo();
    expect(s.doc.components.get<ObjectLayer>(hA), isNull);
  });

  test(
      'OL9b detach on cascade loss: a Pin on A whose host Post is deleted '
      'loses its ObjectLayer with it; undo restores it, redo detaches it', () {
    final s = _Scene();
    s.add(hA, atA, const Post(2000, 1000), layer: s.b);
    s.add(hP, onA(1400.5, 2200.25, 1.1), const Pin(hA, 450), layer: s.a);
    s.expectOn(hP, s.a);
    s.doc.commands.clearHistory();
    final before = state(s.doc, sortNodes: true);

    s.doc.commands.execute(deleteObject(s.doc, hA));
    expect(s.doc.tree[hP], isNull, reason: 'the cascade removed the pin');
    expect(s.doc.components.get<Pin>(hP), isNull);
    expect(s.doc.components.get<ObjectLayer>(hP), isNull);
    expect(s.doc.components.get<ObjectLayer>(hA), isNull);
    final after = state(s.doc, sortNodes: true);

    s.doc.commands.undo();
    expect(s.doc.components.get<ObjectLayer>(hP), ObjectLayer(s.a));
    s.expectOn(hP, s.a);
    expect(state(s.doc, sortNodes: true), before);
    s.doc.commands.redo();
    expect(s.doc.components.get<ObjectLayer>(hP), isNull);
    expect(state(s.doc, sortNodes: true), after);
  });

  test(
      'OL10 detach on dissolve: a dissolving object loses its ObjectLayer in '
      'the edit; undo restores it', () {
    final s = _Scene();
    s.add(hF, onA(-3000.5, 2000.25, -0.2), fuse, layer: s.a);
    s.doc.commands.clearHistory();
    s.expectRegionsOn(hF, s.a, 1);
    s.expectOn(hF, s.a);
    final before = state(s.doc, sortNodes: true);

    s.doc.commands.execute(SetComponentCommand<Fuse>(
        hF, const Fuse(150.5, -80.25, 900.5, 600.75, burnt: true)));
    expect(s.doc.tree[hF], isNull);
    expect(s.doc.components.get<Fuse>(hF), isNull);
    expect(s.doc.components.get<ObjectLayer>(hF), isNull);
    s.doc.commands.execute(RemoveLayerCommand(s.a));
    expect(missingLayerWarnings(s.doc), isEmpty);

    s.doc.commands.undo();
    s.doc.commands.undo();
    expect(s.doc.components.get<ObjectLayer>(hF), ObjectLayer(s.a));
    expect(state(s.doc, sortNodes: true), before);
  });

  test('OL11 the stamp survives a save and load: the moved layer is stored',
      () {
    final s = _Scene();
    s.add(hB, parked, regions);
    s.move(hB, s.a);
    final loaded = reload(enc(s.doc));
    expect(loaded.components.get<ObjectLayer>(hB), ObjectLayer(s.a));
    for (final k in kids(loaded, hB)) {
      expect(loaded.entities.layerAt(loaded.entities.slotOf(k)!), s.a);
    }
  });
}
