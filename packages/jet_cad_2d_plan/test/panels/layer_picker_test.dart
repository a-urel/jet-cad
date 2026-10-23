// Ported from apps/floor_planner/test/layers/layer_picker_test.dart;
// assertions unchanged. The picker takes a PlanController (2a spec P2) and
// asks the catalog whether a group is a live object (E1); the walls and
// the door are the mark kit's marks. Not ported: "in the app" (the
// property panel's layout, Task 17, and the Wall and Door tools,
// sub-project 3) and "a move the document refuses" (Task 11's
// probe-and-freeze flow; the picker's catch is LP-7).
//
// Spec 12b D12, D11: the Selection section's layer picker. It shows for a
// non-empty selection whenever no tool's settings show, including where no
// type section does (a line); it shows the common layer or "Mixed"; one
// choice is one command, one undo step, whatever the selection holds — a
// drafted region moves every record of it, an ATTRIB moves its instance, a
// parametric object moves by its `ObjectLayer`; members already on the
// target are skipped; a plain group disables it; read-only disables it and
// the runtime preset does not.
//
// P-6's layers: `A` (ACI 1), `B` (ACI 5, locked), `C` (ACI 3, hidden), and a
// visible `D` (ACI 2) added here as a target that keeps the selection. Walls
// sit in rotated groups at the corpus far origin; the line, the region and
// the symbol are away from the origin; the symbol is turned.
import 'dart:async' show StreamSubscription;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/src/chrome/menu_button.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/l10n/strings_en.dart';
import 'package:jet_cad_2d_plan/src/panels/layer_picker.dart';

import '../support/layer_plan.dart';
import '../support/mark_kit.dart';

/// The English the picker's words are checked against.
const _en = PlanStringsEn();

Finder byKey(String k) => find.byKey(Key(k));

/// Adds the visible layer `D` (ACI 2) to [doc]; its handle.
Handle addLayerD(DraftDocument doc) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final d = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: d,
      name: 'D',
      color: const IndexedColor(2),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency)));
  return d;
}

/// The fixture: P-6's layers with a mark on `A` (the source's first wall)
/// and a mark on `B` (its door), plus a line, a drafted region with a
/// second fill and a symbol with an ATTRIB, all on `A`, a second mark on
/// `A` (the source's second wall), and a visible layer `D`. Built on the
/// scratch document `layerPlan` saves and opens again: a save and a load
/// keep handles.
final class PickerDoc {
  factory PickerDoc() {
    late final Handle d, line;
    late final ({Handle fill, Handle boundary, Handle secondFill}) region;
    late final ({Handle definition, Handle instance, Handle attrib}) symbol;
    final fx = layerPlan(
        objects: true,
        more: (doc, a, b, c) {
          d = addLayerD(doc);
          line = addLineOn(doc, a, 1250.5, 3400.25, 4100.75, 3650.5);
          region = addRegionOn(doc, a, 7300.5, 2100.25, 350);
          symbol = addSymbolOn(doc, a, 2600.5, 1800.75);
          return [addMark(doc, a, at: placed(8800.25, -950.5, 1.1))];
        });
    return PickerDoc._(fx, d, line, region, symbol);
  }

  PickerDoc._(this.l, this.d, this.line, this.region, this.symbol);

  final LayerPlan l;
  final Handle d;
  final Handle line;
  final ({Handle fill, Handle boundary, Handle secondFill}) region;
  final ({Handle definition, Handle instance, Handle attrib}) symbol;

  DraftDocument get doc => l.doc;
  PlanController get controller => l.controller;
  Handle get wall => l.marks[0];
  Handle get door => l.marks[1];
}

/// Whether [h] is a live object of a loaded kit's type (E1): the source's
/// `isParametricObject`.
bool isParametricObject(PlanController c, Handle h) =>
    c.catalog.typeIdOf(c.document, h) != null;

/// The picker alone, shown while the selection is not empty and rebuilt on
/// every selection and document change, as `PlanPropertyPanel` mounts it
/// (copied from layer_page_controller_test.dart).
class PickerHost extends StatefulWidget {
  const PickerHost(this.controller, {super.key});

  final PlanController controller;

  @override
  State<PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<PickerHost> {
  late final StreamSubscription<DocChange> _changes;

  @override
  void initState() {
    super.initState();
    widget.controller.selection.addListener(_refresh);
    _changes =
        widget.controller.document.commands.changes.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _changes.cancel();
    widget.controller.selection.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.controller.selection.isEmpty
      ? const SizedBox.shrink()
      : LayerPicker(controller: widget.controller);
}

/// [c]'s layer picker in a 280-wide right column, over [c]'s selection.
Future<SelectionController> pumpPanel(
    WidgetTester tester, PlanController c) async {
  // A fresh picker host each time.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 280,
          height: 800,
          child: Column(children: [
            PickerHost(c),
          ]),
        ),
      ),
    ),
  ));
  await tester.pump();
  return c.selection;
}

/// Lets the change stream deliver and the panel rebuild.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> select(
    WidgetTester tester, SelectionController selection, List<Handle> hs) async {
  selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

/// Opens the picker's menu and chooses [layer].
Future<void> choose(WidgetTester tester, Handle layer) async {
  await tester.tap(byKey('layer-picker'));
  await tester.pumpAndSettle();
  await tester.tap(byKey('layer-picker-item-${layer.toHex()}'));
  await tester.pumpAndSettle();
}

String valueOf(WidgetTester tester) =>
    tester.widget<Text>(byKey('layer-picker-value')).data!;

bool pickerEnabled(WidgetTester tester) =>
    tester.widget<PlanMenuButton<Handle>>(byKey('layer-picker')).enabled;

String pickerTooltip(WidgetTester tester) =>
    tester.widget<PlanMenuButton<Handle>>(byKey('layer-picker')).label;

/// Every entity record the parametric object [group] owns (its generated
/// children), with their layers.
List<Handle> childLayers(DraftDocument doc, Handle group) {
  final out = <Handle>[];
  final store = doc.entities;
  for (final slot in store.liveSlots) {
    if (store.ownerAt(slot) == group) out.add(store.layerAt(slot));
  }
  return out;
}

void main() {
  testWidgets(
      'shown for a line-only selection, where no type section shows; not for '
      'an empty one; choosing layer 0 is one command and one undo step',
      (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final selection = await pumpPanel(tester, p.controller);
    expect(byKey('layer-picker'), findsNothing, reason: 'nothing selected');

    await select(tester, selection, [p.line]);
    expect(byKey('layer-picker'), findsOneWidget);
    expect(valueOf(tester), 'A');
    expect(pickerEnabled(tester), isTrue);
    await choose(tester, ReservedHandles.layerZero);
    expect(doc.commands.undoDepth, 1);
    expect(layerOf(doc, p.line), ReservedHandles.layerZero);
    expect(valueOf(tester), '0');
    doc.commands.undo();
    await settle(tester);
    expect(layerOf(doc, p.line), p.l.a);
    expect(valueOf(tester), 'A');
  });

  testWidgets(
      'a mixed selection (a line, a region picked on its fill, a symbol, a '
      'wall) moves in one undo step; every record of the region moves; one '
      'undo restores all (M-LP-5, M-LP-17)', (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final a = p.l.a;
    final selection = await pumpPanel(tester, p.controller);
    await select(
        tester, selection, [p.line, p.region.fill, p.symbol.instance, p.wall]);
    expect(valueOf(tester), 'A');
    expect(childLayers(doc, p.wall), isNotEmpty, reason: 'premise');
    expect(childLayers(doc, p.wall).toSet(), {a}, reason: 'premise');
    final bytes = DraftDocumentCodec.encodeToString(doc);

    await choose(tester, p.d);
    expect(doc.commands.undoDepth, 1, reason: 'one undo step');
    for (final h in [
      p.line,
      p.region.fill,
      p.region.boundary,
      p.region.secondFill,
    ]) {
      expect(layerOf(doc, h), p.d, reason: h.toHex());
    }
    expect((doc.tree[p.symbol.instance]! as InstanceNode).layer, p.d);
    expect(layerOf(doc, p.symbol.attrib), ReservedHandles.layerZero,
        reason: 'the ATTRIB follows its instance by substitution');
    expect(objectLayerOf(doc, p.wall), p.d);
    expect(childLayers(doc, p.wall).toSet(), {p.d},
        reason: 'the regeneration stamps the moved wall\'s children');
    // Nothing else moved.
    expect(objectLayerOf(doc, p.l.marks[2]), a);
    expect(objectLayerOf(doc, p.door), p.l.b);
    expect(valueOf(tester), 'D');
    expect(selection.keys, hasLength(4), reason: 'D is visible and unlocked');

    doc.commands.undo();
    await settle(tester);
    expect(DraftDocumentCodec.encodeToString(doc), bytes,
        reason: 'one undo restores everything');
    expect(valueOf(tester), 'A');
  });

  testWidgets('a region picked on its boundary moves every fill of it',
      (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final selection = await pumpPanel(tester, p.controller);
    await select(tester, selection, [p.region.boundary]);
    await choose(tester, p.d);
    expect(doc.commands.undoDepth, 1);
    for (final h in [p.region.boundary, p.region.fill, p.region.secondFill]) {
      expect(layerOf(doc, h), p.d, reason: h.toHex());
    }
  });

  testWidgets(
      'the label: "Mixed" for mixed layers; an ATTRIB shows its instance\'s '
      'layer; a fill shows its boundary\'s; an object its ObjectLayer',
      (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final selection = await pumpPanel(tester, p.controller);
    await select(tester, selection, [p.line, p.door]);
    expect(valueOf(tester), _en.mixed);
    await select(tester, selection, [p.door]);
    expect(valueOf(tester), 'B');
    await select(tester, selection, [p.symbol.attrib]);
    expect(layerOf(doc, p.symbol.attrib), ReservedHandles.layerZero,
        reason: 'premise');
    expect(valueOf(tester), 'A');
    // A file can split a region; its layer is its boundary's.
    doc.commands.execute(SetEntityLayerCommand.restore(p.region.fill, p.d));
    await select(tester, selection, [p.region.fill]);
    expect(valueOf(tester), 'A');
    await select(tester, selection, [p.region.fill, p.line]);
    expect(valueOf(tester), 'A');
  });

  testWidgets(
      'a selection already on the target dispatches nothing; an ATTRIB and '
      'its instance are one member', (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final selection = await pumpPanel(tester, p.controller);
    await select(
        tester, selection, [p.line, p.region.fill, p.symbol.attrib, p.wall]);
    final state = doc.commands.stateId;
    await choose(tester, p.l.a);
    expect(doc.commands.undoDepth, 0);
    expect(doc.commands.stateId, state);
    expect(
        layerMoveCommand(doc, selection.keys, p.l.a,
            isObject: (h) => isParametricObject(p.controller, h)),
        isNull);

    // The ATTRIB and its instance collapse into one move of the instance.
    final both = layerMoveCommand(
        doc,
        [
          SelectionKey.root(p.symbol.attrib),
          SelectionKey.root(p.symbol.instance)
        ],
        p.d,
        isObject: (h) => isParametricObject(p.controller, h));
    expect(both, isA<SetInstanceLayerCommand>());
    expect((both! as SetInstanceLayerCommand).node, p.symbol.instance);
    // Skipped per member: only the line is off D here.
    doc.commands.execute(SetInstanceLayerCommand(p.symbol.instance, p.d));
    final one = layerMoveCommand(doc,
        [SelectionKey.root(p.symbol.attrib), SelectionKey.root(p.line)], p.d,
        isObject: (h) => isParametricObject(p.controller, h));
    expect(one, isA<SetEntityLayerCommand>());
    expect((one! as SetEntityLayerCommand).entity, p.line);
  });

  testWidgets(
      'moving to a hidden layer is allowed and empties the selection; to a '
      'locked one too', (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final selection = await pumpPanel(tester, p.controller);
    await select(tester, selection, [p.line, p.wall]);
    await choose(tester, p.l.c);
    expect(doc.commands.undoDepth, 1);
    expect(layerOf(doc, p.line), p.l.c);
    expect(objectLayerOf(doc, p.wall), p.l.c);
    expect(selection.keys, isEmpty, reason: 'C is hidden (D8)');
    expect(byKey('layer-picker'), findsNothing);

    await select(tester, selection, [p.symbol.instance]);
    await choose(tester, p.l.b);
    expect((doc.tree[p.symbol.instance]! as InstanceNode).layer, p.l.b);
    expect(selection.keys, isEmpty, reason: 'B is locked (D8)');
  });

  testWidgets(
      'read-only disables it with the reason and nothing is dispatched; the '
      'runtime preset (components) moves (D11)', (tester) async {
    for (final permissions in [
      DraftPermissions.readOnly,
      DraftPermissions.runtime,
    ]) {
      final p = PickerDoc();
      final doc = p.doc;
      doc.commands.permissions = permissions;
      final selection = await pumpPanel(tester, p.controller);
      await select(tester, selection, [p.line, p.wall]);
      final bytes = DraftDocumentCodec.encodeToString(doc);
      if (permissions == DraftPermissions.readOnly) {
        expect(pickerEnabled(tester), isFalse);
        expect(pickerTooltip(tester), _en.readOnlyDocument);
        await tester.tap(byKey('layer-picker'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(byKey('layer-picker-item-${p.d.toHex()}'), findsNothing,
            reason: 'no menu');
        expect(tester.takeException(), isNull);
        expect(doc.commands.undoDepth, 0);
        expect(DraftDocumentCodec.encodeToString(doc), bytes);
      } else {
        expect(permissions.allows(Capability.structure), isFalse,
            reason: 'premise: runtime cannot edit layers');
        expect(pickerEnabled(tester), isTrue);
        await choose(tester, p.d);
        expect(tester.takeException(), isNull);
        expect(doc.commands.undoDepth, 1);
        expect(layerOf(doc, p.line), p.d);
        expect(objectLayerOf(doc, p.wall), p.d);
      }
    }
  });

  testWidgets(
      'a plain (non-parametric) group disables it with the reason, even one '
      'carrying an ObjectLayer', (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final plain = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: plain,
        parent: doc.rootHandle,
        transform: Transform2.translation(910.5, -420.25)
            .multiply(Transform2.rotation(0.6)),
        children: const [])));
    doc.commands
        .execute(SetComponentCommand<ObjectLayer>(plain, ObjectLayer(p.l.a)));
    doc.commands.clearHistory();
    final selection = await pumpPanel(tester, p.controller);
    await select(tester, selection, [p.line, plain]);
    expect(pickerEnabled(tester), isFalse);
    expect(pickerTooltip(tester), _en.plainGroupNoLayer);
    await select(tester, selection, [p.line]);
    expect(pickerEnabled(tester), isTrue);
    expect(pickerTooltip(tester), isNot(_en.plainGroupNoLayer));
  });

  testWidgets(
      'every registered parametric type (the mark kit\'s one type, on four '
      'layers) alone: the picker is enabled and shows the object\'s '
      'layer (Task 10 review finding 1, R-own-5)', (tester) async {
    late final Handle d;
    final l = layerPlan(
        objects: true,
        more: (doc, a, b, c) {
          d = addLayerD(doc);
          return [
            addMark(doc, d, at: placed(-6400.5, 9100.25, 0.7)),
            addMark(doc, ReservedHandles.layerZero,
                at: placed(-9800.25, -7300.5, -0.3)),
          ];
        });
    final doc = l.doc;
    final markD = l.marks[2], mark0 = l.marks[3];
    final cases = <(String, Handle, String)>[
      ('mark on D', markD, 'D'),
      ('mark on A', l.marks[0], 'A'),
      ('mark on B', l.marks[1], 'B'),
      ('mark on 0', mark0, '0'),
    ];
    final selection = await pumpPanel(tester, l.controller);
    for (final (type, h, name) in cases) {
      expect(isParametricObject(l.controller, h), isTrue, reason: type);
      await select(tester, selection, [h]);
      expect(pickerEnabled(tester), isTrue, reason: type);
      expect(pickerTooltip(tester), isNot(_en.plainGroupNoLayer), reason: type);
      expect(valueOf(tester), name, reason: type);
    }
    // And one of them moves: the mark on 0, from layer 0 to D.
    await select(tester, selection, [mark0]);
    await choose(tester, d);
    expect(doc.commands.undoDepth, 1);
    expect(objectLayerOf(doc, mark0), d);
    expect(childLayers(doc, mark0), isNotEmpty, reason: 'premise');
    expect(childLayers(doc, mark0).toSet(), {d});
  });

  testWidgets(
      'the picker needs components, not transform: custom permission sets '
      'that differ only there (Task 10 review finding 2, R-own-2)',
      (tester) async {
    const noComponents = DraftPermissions(
        transform: true, components: false, geometry: true, structure: true);
    const onlyComponents = DraftPermissions(
        transform: false, components: true, geometry: false, structure: false);

    var p = PickerDoc();
    var doc = p.doc;
    doc.commands.permissions = noComponents;
    var selection = await pumpPanel(tester, p.controller);
    await select(tester, selection, [p.line, p.wall]);
    expect(pickerEnabled(tester), isFalse);
    expect(pickerTooltip(tester), _en.readOnlyDocument);

    p = PickerDoc();
    doc = p.doc;
    doc.commands.permissions = onlyComponents;
    selection = await pumpPanel(tester, p.controller);
    await select(tester, selection, [p.line, p.wall]);
    expect(pickerEnabled(tester), isTrue);
    await choose(tester, p.d);
    expect(tester.takeException(), isNull);
    expect(doc.commands.undoDepth, 1);
    expect(layerOf(doc, p.line), p.d);
    expect(objectLayerOf(doc, p.wall), p.d);
    expect(childLayers(doc, p.wall).toSet(), {p.d});
  });

  testWidgets(
      'the no-op rule compares the stored ObjectLayer: a dangling one moved '
      'to layer 0 is rewritten; an absent one moved to layer 0 is a no-op '
      '(Task 10 review finding 3, R-own-3)', (tester) async {
    final p = PickerDoc();
    final doc = p.doc;
    final zero = ReservedHandles.layerZero;
    // A layer handle that names no layer (a file can hold one).
    final gone = doc.handleSeed.next();
    expect(doc.tables.layers[gone], isNull, reason: 'premise');
    final dangling = p.wall, absent = p.l.marks[2];
    doc.commands
        .execute(SetComponentCommand<ObjectLayer>(dangling, ObjectLayer(gone)));
    doc.commands.execute(SetComponentCommand<ObjectLayer>(absent, null));
    doc.commands.clearHistory();
    expect(objectLayer(doc, dangling), zero, reason: 'premise: shown on 0');
    expect(objectLayerOf(doc, dangling), gone, reason: 'premise: stored');
    expect(objectLayerOf(doc, absent), isNull, reason: 'premise');
    expect(childLayers(doc, dangling).toSet(), {zero}, reason: 'premise');
    expect(childLayers(doc, absent).toSet(), {zero}, reason: 'premise');

    bool isObject(Handle h) => isParametricObject(p.controller, h);
    final repair = layerMoveCommand(doc, [SelectionKey.root(dangling)], zero,
        isObject: isObject);
    expect(repair, isA<SetComponentCommand<ObjectLayer>>());
    expect(
        layerMoveCommand(doc, [SelectionKey.root(absent)], zero,
            isObject: isObject),
        isNull);

    final selection = await pumpPanel(tester, p.controller);
    await select(tester, selection, [absent]);
    expect(valueOf(tester), '0');
    await choose(tester, zero);
    expect(doc.commands.undoDepth, 0, reason: 'absent is already layer 0');
    expect(objectLayerOf(doc, absent), isNull);

    await select(tester, selection, [dangling]);
    expect(valueOf(tester), '0');
    await choose(tester, zero);
    expect(doc.commands.undoDepth, 1, reason: 'the stored value is repaired');
    expect(objectLayerOf(doc, dangling), zero);
  });
}
