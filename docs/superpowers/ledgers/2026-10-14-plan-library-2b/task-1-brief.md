### Task 1: Engine E5, the output, the hook and matching (spec S1 "The output", "The definition", "The survey", "Matching", "Version")

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/parametric/parametric_system.dart`, `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`, `packages/jet_cad_2d/CHANGELOG.md`
- Modify: `packages/jet_cad_2d_plan/lib/src/kits/guard.dart` (controller ruling R-1: the forwarder, so the plan library compiles)
- Modify: `packages/jet_cad_2d/test/parametric/cascade_test.dart` (CS11's drift premise, one line; controller ruling R-4)
- Create (test support): `packages/jet_cad_2d/test/parametric/support/row_clients.dart`
- Test: `packages/jet_cad_2d/test/parametric/instances_test.dart`

(Paths below are under `packages/jet_cad_2d/` unless they start at the repository root.)

**Interfaces:**
- Consumes (existing engine code; read before editing; line numbers at `7f6add5d`):
  - `ParametricType` (`parametric_system.dart:26-174`), `generate` at `:38`, `dissolves` at `:91`.
  - `Generated` (`:223-336`), `GeneratedGeometryError` (`:340-348`), `DanglingReferenceError` (`:374-386`).
  - `ParametricSystem.drift` (`:660-673`) and `probe` (`:761-819`): both reach the planner through `_plan`, so they call `instances` with no change of their own.
  - `_Registration` (`:938-1004`), `generate` forwarder at `:994`.
  - `_Survey` (`regeneration.dart:70-220`) and `_survey` (`:226-304`): `children` and `owned` built from the live slots at `:256-267`.
  - `_recordOf` (`:457-466`), `_samePayload` (`:468-480`), `_plan` (`:567-662`), `_refused` (`:678-693`, unchanged here), `_subtreeRemoval` (`:855-912`, unchanged here), `_run` (`:965-1098`).
  - Commands (all exist): `AddNodeCommand` (`document/commands.dart:390`), `RemoveNodeCommand` (`:461`), `TransformNodeCommand` (`:286`), `SetInstanceDefinitionCommand` (`:326`), `SetInstanceLayerCommand.restore` (`document/layer_commands.dart:523`), `AddEntityCommand` (`commands.dart:36`), `RemoveEntityCommand` (`:125`), `SetEntityTextCommand` (`:236`, it writes the tag too), `SetEntityGeometryCommand` (`:676`).
  - `InstanceNode.==` (`document/node.dart:287-303`): exact, `Transform2.equals(…, Tolerance(linear: 0, angular: 0))` for the transform.
  - Today's table label record (`packages/jet_cad_floor_plan/lib/src/tables/table_label.dart:110-130`): the ATTRIB shape copied here (layer 0, BYBLOCK colour, lineweight, transparency and linetype, flags 0, the standard text style).
  - `GuardedType` (`packages/jet_cad_2d_plan/lib/src/kits/guard.dart:42`, `implements ParametricType<T>`), its `generate` wrapper at `:76-84`.
- Produces (exported from `package:jet_cad_2d/jet_cad_2d.dart` through the existing `export 'src/parametric/parametric_system.dart';`, `lib/jet_cad_2d.dart:62`):

```dart
final class GeneratedAttrib {
  GeneratedAttrib(this.tag, this.text, this.payload, {this.textAttrs = 0}); // ArgumentError: empty tag
  final String tag;
  final String text;
  final GeometryPayload payload;   // the instance's local (definition) space
  final int textAttrs;
}
final class GeneratedInstance {
  GeneratedInstance(this.definition, this.transform,
      {List<GeneratedAttrib> attributes = const []});  // ArgumentError: two attributes, one tag
  final Handle definition;
  final Transform2 transform;      // the object's group's local space
  final List<GeneratedAttrib> attributes;  // unmodifiable
}
final class GeneratedDefinitionError implements Exception {
  const GeneratedDefinitionError(this.object, this.definition);
  final Handle object;
  final Handle definition;
}
// on ParametricType<T>, beside generate:
List<GeneratedInstance> instances(ParametricView view, Handle self) => const [];
```

  - `GuardedType.instances` (plan library, ruling R-1): a throw becomes `KitHookFailure(kitId, typeId, 'instances', error)`. Task 4 adds its tests (PB-guard) and nothing else to `guard.dart`.
- What the consumers (Task 2, Tasks 4-6) can rely on:
  - `_Survey.instances`: each live object to its generated instances, the `InstanceNode` children of its group whose `parent` is the object, ascending by handle, each the `InstanceNode` value at survey time (nodes are immutable: a reference). `_Survey.generated`: each such instance handle to that node value (its object is `node.parent`). `_Survey.leaves`: each generated instance to every entity it owns, ascending. `children` stays entity-only. `owned` gains each generated instance's **ATTRIBs** (kind `attrib` only), mapped to the object.
  - The planner calls `instances` after `generate`, with the same view, for every object of the closure that does not dissolve. An unchanged output plans nothing.
  - Every instance command the plan holds (an added seat's `AddNodeCommand`, its ATTRIBs' `AddEntityCommand`s, a match's `TransformNodeCommand`, `SetEntityGeometryCommand`, `SetEntityTextCommand`, a removal) runs through `_run`'s one-by-one loop, which adds its `touched` to the edit's (`regeneration.dart:1064`, `:1084`, unchanged here): an edit's `CommandResult.touched` names every seat and label a regeneration adds, changes or removes. Task 7's label system reads it (UL-seat); E5-noop pins the other side (an unchanged row touches only the row).
  - `GeneratedDefinitionError` is thrown from `_plan`, inside `_run`'s `try`: the edit is undone and the error rethrown; `probe` returns it; `drift()` throws it. The plan library's `_isRefusal` (`jet_cad_2d_plan/lib/src/kits/locks.dart:304`) must **not** list it (spec S1 "The definition"); nothing in this task touches it.
  - Task 1 does **not** change `_refused` or `_subtreeRemoval`. After Task 1 a move of a generated seat still passes and a dissolve leaves its ATTRIBs behind; Task 2 closes both. No test of this task depends on a node edit being refused (an ATTRIB edit is refused already here: `owned` covers it through today's entity branch).

Plan decisions:
- **Order inside one object's plan.** Entities first (regions, plain children, surplus entity removals: today's code untouched), then instances. So a new row's reserved handles run: its LINE, seat 1, seat 1's label, seat 2, … (draw order = output order, each label just above its seat). Within a matched instance the order is definition, transform, layer, then its ATTRIBs.
- **ATTRIB matching.** Per matched instance, its existing ATTRIBs (from `_Survey.leaves`, ascending) are bucketed by tag: the first of a tag (its lowest handle) is matched, later ones are surplus. Each output attribute takes the matched one of its tag: `SetEntityGeometryCommand` on a payload difference, then `SetEntityTextCommand(h, text, <its own stored tag>)` on a text difference (the TEXT call's `''` at `regeneration.dart:638` would blank the tag). An output tag with no match is added. Surplus ones and those of a tag no output names are removed, ascending. A matched ATTRIB's record is otherwise never rewritten: no layer stamp, no style stamp (spec S1, 12b D2 and PC-3a exclusions); `textAttrs` is fixed at creation, as `Generated`'s.
- **A surplus instance** is removed with every entity it owns (fills first, then the rest, ascending), then its node. A non-ATTRIB entity a loaded file put on a matched instance is left alone.
- **An InstanceNode child of an object's group is that object's generated instance** (spec S1 "The survey"). A type that keeps the default `instances` therefore removes such a node on its next regeneration. No workspace code places an instance inside an object (the placers at `jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart:162` and `jet_cad_floor_plan/lib/src/symbols/symbol_placer.dart:203` place at the root), but one existing engine test does: CS11 (controller ruling R-4). The CHANGELOG says so.
- **The definition check** runs over all of an object's outputs before any of its instance commands is planned, and throws on the first output whose `definition` is not `t.tree.definition(…)` (a dead handle and a live node alike).

- [ ] **Step 1: Write the test clients.** Create `test/parametric/support/row_clients.dart`:

```dart
// Test-only parametric types for spec 2b S1 (E5: a type generates symbol
// instances with their ATTRIBs), written for E5 and sharing no type with
// clients.dart (Ruling 06-9). E5-default borrows clients.dart's
// CaptionType: a type that keeps the default `instances`.
//
// Fixture: two seat definitions off their origins, and two rows off the
// world origin: row 1 turned and straight; row 2 turned the other way,
// mirrored and curved. Nothing stands at the identity.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'clients.dart' show Caption, CaptionType;

/// The tag of every seat's label.
const String kSeatTag = 'UNIT';

/// Every seat label's `textAttrs`: centred on its anchor both ways.
final int kSeatLabelAttrs =
    packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.middle);

/// [RowType]'s `generate` and `instances` calls, by object.
final Map<Handle, int> rowGenerateCalls = {};
final Map<Handle, int> rowInstanceCalls = {};

void resetRowCalls() {
  rowGenerateCalls.clear();
  rowInstanceCalls.clear();
}

/// A row of [count] seats of the definition [seat], labelled
/// `<prefix>1` … `<prefix><count>`.
final class Row implements Component {
  const Row(this.seat, this.count,
      {this.prefix = 'A',
      this.spacing = 650.5,
      this.bend = 0,
      this.labelHeight = 150.25,
      this.extraTag,
      this.note = '',
      this.dissolve = false});

  static const String id = 'test.row';

  final Handle seat;
  final int count;
  final String prefix;
  final double spacing;

  /// The turn from one seat to the next, radians: 0 is a straight row.
  final double bend;
  final double labelHeight;

  /// A second ATTRIB on every seat, tagged so, its text the prefix; none
  /// when null.
  final String? extraTag;

  /// Read by no hook: an edit of it regenerates the row and changes nothing.
  final String note;

  /// Read by `dissolves` only (Task 2's E5G-dissolve).
  final bool dissolve;

  /// [extraTag] is kept as it is: a test that drops it builds a [Row].
  Row copyWith(
          {Handle? seat,
          int? count,
          String? prefix,
          double? labelHeight,
          String? note,
          bool? dissolve}) =>
      Row(seat ?? this.seat, count ?? this.count,
          prefix: prefix ?? this.prefix,
          spacing: spacing,
          bend: bend,
          labelHeight: labelHeight ?? this.labelHeight,
          extraTag: extraTag,
          note: note ?? this.note,
          dissolve: dissolve ?? this.dissolve);

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {
        'seat': seat.toJson(),
        'count': count,
        'prefix': prefix,
        'spacing': spacing,
        'bend': bend,
        'labelHeight': labelHeight,
        'extraTag': extraTag,
        'note': note,
        'dissolve': dissolve,
      };

  static Row fromJson(Map<String, Object?> j) =>
      Row(Handle.fromJson(j['seat']), j['count']! as int,
          prefix: j['prefix']! as String,
          spacing: (j['spacing']! as num).toDouble(),
          bend: (j['bend']! as num).toDouble(),
          labelHeight: (j['labelHeight']! as num).toDouble(),
          extraTag: j['extraTag'] as String?,
          note: j['note']! as String,
          dissolve: j['dissolve']! as bool);

  @override
  bool operator ==(Object other) =>
      other is Row &&
      other.seat == seat &&
      other.count == count &&
      other.prefix == prefix &&
      other.spacing == spacing &&
      other.bend == bend &&
      other.labelHeight == labelHeight &&
      other.extraTag == extraTag &&
      other.note == note &&
      other.dissolve == dissolve;

  @override
  int get hashCode => Object.hash(seat, count, prefix, spacing, bend,
      labelHeight, extraTag, note, dissolve);
}

/// Seat [i]'s placement (0-based) in its row's group, local space: along +x
/// by the spacing, on a parabola when bent, each seat turned [Row.bend] more
/// than the last.
Transform2 seatAt(Row r, int i) => Transform2.translation(
        r.spacing * i, 0.5 * r.bend * r.spacing * i * i)
    .multiply(Transform2.rotation(r.bend * i));

/// Every seat label's payload, in the seat's local (definition) space.
GeometryPayload seatLabel(Row r) =>
    textPayload(Vector2(12.5, -40.25), r.labelHeight);

/// The extra ATTRIB's payload, in the seat's local space.
GeometryPayload seatExtra(Row r) => textPayload(Vector2(-60.75, 90.5), 80.5);

final class RowType extends ParametricType<Row> {
  const RowType();

  @override
  Capability get editCapability => Capability.geometry;

  /// Every seat's ±300 square, in world.
  @override
  Aabb2 reach(Row params, Transform2 toWorld) {
    if (params.count == 0) return Aabb2.empty();
    return Aabb2.fromPoints([
      for (var i = 0; i < params.count; i++)
        for (final (dx, dy) in const [
          (-300.0, -300.0),
          (300.0, -300.0),
          (300.0, 300.0),
          (-300.0, 300.0)
        ])
          toWorld.multiply(seatAt(params, i)).transformPoint(Vector2(dx, dy)),
    ]);
  }

  /// One LINE from the first seat to the last, so the row has an entity
  /// child beside its instances.
  @override
  List<Generated> generate(ParametricView view, Handle self) {
    rowGenerateCalls[self] = (rowGenerateCalls[self] ?? 0) + 1;
    final r = view.paramsOf<Row>(self)!;
    if (r.count < 2) return const [];
    final first = seatAt(r, 0).transformPoint(Vector2(0, 0));
    final last = seatAt(r, r.count - 1).transformPoint(Vector2(0, 0));
    return [Generated(EntityKind.line, linePayload(first, last))];
  }

  @override
  List<GeneratedInstance> instances(ParametricView view, Handle self) {
    rowInstanceCalls[self] = (rowInstanceCalls[self] ?? 0) + 1;
    final r = view.paramsOf<Row>(self)!;
    return [
      for (var i = 0; i < r.count; i++)
        GeneratedInstance(r.seat, seatAt(r, i), attributes: [
          GeneratedAttrib(kSeatTag, '${r.prefix}${i + 1}', seatLabel(r),
              textAttrs: kSeatLabelAttrs),
          if (r.extraTag case final tag?)
            GeneratedAttrib(tag, r.prefix, seatExtra(r)),
        ]),
    ];
  }

  @override
  bool dissolves(ParametricView view, Handle self) =>
      view.paramsOf<Row>(self)!.dissolve;
}

/// Per-seat host data: a component on a generated instance, which no hook
/// reads (spec 2b S2's per-unit data, here in the engine).
final class SeatNote implements Component {
  const SeatNote(this.text);
  static const String id = 'test.seat_note';
  final String text;
  @override
  String get typeId => id;
  @override
  Map<String, Object?> toJson() => {'text': text};
  static SeatNote fromJson(Map<String, Object?> j) =>
      SeatNote(j['text']! as String);
  @override
  bool operator ==(Object other) => other is SeatNote && other.text == text;
  @override
  int get hashCode => text.hashCode;
}

final ParametricCatalog rowCatalog = ParametricCatalog()
  ..register<Row>(Row.id, Row.fromJson, const RowType())
  ..register<Caption>(Caption.id, Caption.fromJson, const CaptionType());

/// The catalog's components and [SeatNote]: pass to a decode.
void registerRowComponents(ComponentRegistry registry) {
  rowCatalog.registerComponents(registry);
  if (!registry.isRegistered<SeatNote>()) {
    registry.register<SeatNote>(SeatNote.id, SeatNote.fromJson);
  }
}

/// A round seat (a circle and a back LINE) and a square stool.
const Handle hSeat = Handle(500);
const Handle hStool = Handle(600);
const Handle hRow1 = Handle(1000);
const Handle hRow2 = Handle(2000);

/// Row 1: turned, off the origin.
final Transform2 atRow1 = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));

/// Row 2: turned the other way and mirrored, off the origin.
final Transform2 atRow2 = Transform2.translation(-4200.5, 9100.25)
    .multiply(Transform2.rotation(-0.7))
    .multiply(Transform2.scale(1, -1));

/// Straight, 12 seats.
const Row row1 = Row(hSeat, 12, prefix: 'A');

/// Curved, 5 seats.
const Row row2 = Row(hSeat, 5, prefix: 'B', spacing: 700.25, bend: 0.125);

void _define(DraftDocument doc, Handle h, String name, Vector2 base,
    List<(EntityKind, GeometryPayload)> leaves) {
  doc.commands.execute(AddDefinitionCommand(
      Definition(handle: h, name: name, basePoint: base, children: const [])));
  for (final (kind, payload) in leaves) {
    doc.commands.execute(AddEntityCommand(
        record: draftRecord(doc.handleSeed.next(), h, kind,
            layer: ReservedHandles.layerZero),
        payload: payload));
  }
}

/// An empty document with a system over [rowCatalog], [SeatNote]
/// registered, and the two definitions.
DraftDocument rowDoc() {
  final doc = DraftDocument.empty();
  registerRowComponents(doc.components);
  ParametricSystem(doc, rowCatalog).install();
  _define(doc, hSeat, 'seat', Vector2(10.5, -20.25), [
    (EntityKind.circle, circlePayload(Vector2(0, 0), 220)),
    (EntityKind.line, linePayload(Vector2(-200, 260.5), Vector2(200, 260.5))),
  ]);
  _define(doc, hStool, 'stool', Vector2(-5.25, 7.5), [
    (
      EntityKind.polyline,
      polylinePayload([
        Vector2(-180, -180),
        Vector2(180, -180),
        Vector2(180, 180),
        Vector2(-180, 180),
      ], closed: true)
    ),
  ]);
  return doc;
}

/// Creates the object [h] at [at] with [params], and its `ObjectLayer` in
/// the same compound when [layer] is given, as a tool does.
void place<T extends Component>(
    DraftDocument doc, Handle h, Transform2 at, T params,
    {Handle? layer}) {
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: at, children: const [])),
    SetComponentCommand<T>(h, params),
    if (layer != null) SetComponentCommand<ObjectLayer>(h, ObjectLayer(layer)),
  ], label: 'Add object'));
}

/// [rowDoc] with [row1] at [atRow1] and [row2] at [atRow2].
DraftDocument hall() {
  final doc = rowDoc();
  place(doc, hRow1, atRow1, row1);
  place(doc, hRow2, atRow2, row2);
  return doc;
}

/// A new visible, unlocked layer.
Handle addLayer(DraftDocument doc, String name, int aci) {
  final handle = doc.handleSeed.next();
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  doc.tables.layers.add(LayerRecord(
    handle: handle,
    name: name,
    color: IndexedColor(aci),
    linetype: zero.linetype,
    lineweight: zero.lineweight,
    transparency: zero.transparency,
    visible: true,
    locked: false,
  ));
  return handle;
}

/// [row]'s generated seats, ascending by handle.
List<InstanceNode> seats(DraftDocument doc, Handle row) => [
      for (final c in (doc.tree[row]! as GroupNode).children)
        if (doc.tree[c] case final InstanceNode n) n,
    ]..sort((a, b) => a.handle.value.compareTo(b.handle.value));

/// The entities [owner] owns, ascending.
List<Handle> leavesOf(DraftDocument doc, Handle owner) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == owner) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [row]'s seats' labels, one per seat, in seat order.
List<Handle> labelsOf(DraftDocument doc, Handle row) => [
      for (final s in seats(doc, row)) leavesOf(doc, s.handle).single,
    ];

EntityRecord recordOf(DraftDocument doc, Handle h) =>
    doc.entities.read(doc.entities.slotOf(h)!);

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

String enc(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

/// Entities sorted by handle: slot order is history, not state (spec D11).
String canon(DraftDocument doc) {
  final j = DraftDocumentCodec.encode(doc);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

List<Handle> drift(DraftDocument doc) =>
    ParametricSystem(doc, rowCatalog).drift();

/// Decodes [s] and installs a system over [rowCatalog].
DraftDocument reloadRows(String s) {
  final doc = DraftDocumentCodec.decode(jsonDecode(s) as Map<String, Object?>,
      registerComponents: registerRowComponents);
  ParametricSystem(doc, rowCatalog).install();
  return doc;
}

/// [doc] saved, [edit]ed as a file can be (decoded with no system: nothing
/// regenerates and nothing is guarded), saved again and loaded with a
/// system.
DraftDocument loadedWith(
    DraftDocument doc, void Function(DraftDocument raw) edit) {
  final raw = DraftDocumentCodec.decode(
      jsonDecode(enc(doc)) as Map<String, Object?>,
      registerComponents: registerRowComponents);
  edit(raw);
  return reloadRows(enc(raw));
}

/// The `CommandApplied` changes [edit] causes.
Future<List<CommandApplied>> applying(
    DraftDocument doc, void Function() edit) async {
  await pumpEventQueue();
  final applied = <CommandApplied>[];
  final sub = doc.changes.listen((c) {
    if (c is CommandApplied) applied.add(c);
  });
  edit();
  await pumpEventQueue();
  await sub.cancel();
  return applied;
}
```

- [ ] **Step 2: Write the failing tests.** Create `test/parametric/instances_test.dart`. Each test names its mutations (Step 13).

```dart
// Spec 2b S1 (E5): a parametric type generates symbol instances with their
// ATTRIBs beside its entities. The planner matches the i-th output to the
// i-th existing instance ascending by handle and ATTRIBs by tag, plans
// nothing for an unchanged output, and refuses an output naming no live
// definition before any command. Fixture: support/row_clients.dart.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart' show Caption;
import 'support/row_clients.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

void main() {
  setUp(resetRowCalls);

  test(
      'E5-args GeneratedAttrib refuses an empty tag, GeneratedInstance two '
      'attributes of one tag, and its list is its own (M-E5-args-tag, '
      'M-E5-args-dup, M-E5-args-copy)', () {
    final p = seatLabel(row1);
    expect(() => GeneratedAttrib('', 'A1', p), throwsArgumentError);
    final a = GeneratedAttrib(kSeatTag, 'A1', p, textAttrs: kSeatLabelAttrs);
    expect((a.tag, a.text, a.textAttrs), (kSeatTag, 'A1', kSeatLabelAttrs));
    final b = GeneratedAttrib(kSeatTag, 'A2', p);
    expect(
        () => GeneratedInstance(hSeat, seatAt(row1, 3), attributes: [a, b]),
        throwsArgumentError);
    final given = [a];
    final g = GeneratedInstance(hSeat, seatAt(row1, 3), attributes: given);
    given.add(GeneratedAttrib('ROW', 'A', p));
    expect(g.attributes, [a]);
    expect(() => g.attributes.add(b), throwsUnsupportedError);
    expect(GeneratedInstance(hStool, seatAt(row2, 2)).attributes, isEmpty);
  });

  test(
      'E5-shrink a row shrunk from 12 seats to 10 keeps seats 1-10 under '
      'their handles, untouched, with their components; seats 11-12 go with '
      'their labels; undo brings them back with theirs (M-E5-match, '
      'M-E5-surplus-leaves, M-E5-label-shape, M-E5-call)', () {
    final doc = hall();
    final before = seats(doc, hRow1);
    expect(before, hasLength(12));
    final labels = labelsOf(doc, hRow1);

    // Created: each seat a child of the row's group with InstanceNode's
    // default style, on the object's layer (layer 0: no ObjectLayer), and
    // one label of today's table label's shape.
    for (var i = 0; i < 12; i++) {
      final s = before[i];
      final why = 'seat ${i + 1}';
      expect(s.parent, hRow1, reason: why);
      expect(s.definition, hSeat, reason: why);
      expect(s.transform.equals(seatAt(row1, i), exact), isTrue, reason: why);
      expect(s.layer, ReservedHandles.layerZero, reason: why);
      expect(s.color, const ByBlockColor(), reason: why);
      expect(s.lineweight, kByBlock, reason: why);
      expect(s.transparency, kByBlock, reason: why);
      expect(s.linetype, ReservedHandles.byBlockLinetype, reason: why);
      expect(s.linetypeScale, 1.0, reason: why);
      expect(s.visible, isTrue, reason: why);
      final r = recordOf(doc, labels[i]);
      expect(r.owner, s.handle, reason: why);
      expect(r.kind, EntityKind.attrib, reason: why);
      expect(r.tag, kSeatTag, reason: why);
      expect(r.text, 'A${i + 1}', reason: why);
      expect(r.layer, ReservedHandles.layerZero, reason: why);
      expect(r.color, const ByBlockColor(), reason: why);
      expect(r.linetype, ReservedHandles.byBlockLinetype, reason: why);
      expect(r.lineweight, kByBlock, reason: why);
      expect(r.transparency, kByBlock, reason: why);
      expect(r.flags, 0, reason: why);
      expect(r.textStyle, ReservedHandles.standardTextStyle, reason: why);
      expect(r.textAttrs, kSeatLabelAttrs, reason: why);
      expect(payloadOf(doc, labels[i]).coords, seatLabel(row1).coords);
      expect(payloadOf(doc, labels[i]).scalars, seatLabel(row1).scalars);
    }
    // Premise: seat 12 sits off the origin in world, on row 1's turned
    // frame.
    final world = doc.tree
        .accumulatedTransform(before[11].handle)
        .transformPoint(Vector2(0, 0));
    final want =
        atRow1.multiply(seatAt(row1, 11)).transformPoint(Vector2(0, 0));
    expect(world.x, closeTo(want.x, 1e-9));
    expect(world.y, closeTo(want.y, 1e-9));
    expect(world.length, greaterThan(1000));
    expect(atRow1.transformDirection(Vector2(1, 0)).y,
        isNot(closeTo(0, 1e-3)));

    // Per-seat data: a component on each seat, which no hook reads.
    doc.commands.execute(CompoundCommand([
      for (var i = 0; i < 12; i++)
        SetComponentCommand<SeatNote>(
            before[i].handle, SeatNote('n${i + 1}')),
    ], label: 'Notes'));
    final noted = canon(doc);
    final depth = doc.commands.undoDepth;
    final row2Seats = [for (final s in seats(doc, hRow2)) s.handle];

    doc.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(count: 10)));
    final after = seats(doc, hRow1);
    expect([for (final s in after) s.handle],
        [for (final s in before.take(10)) s.handle]);
    for (var i = 0; i < 10; i++) {
      final why = 'seat ${i + 1}';
      expect(identical(doc.tree[before[i].handle], before[i]), isTrue,
          reason: '$why: no command planned on it');
      expect(doc.components.get<SeatNote>(before[i].handle),
          SeatNote('n${i + 1}'),
          reason: why);
      expect(leavesOf(doc, before[i].handle), [labels[i]], reason: why);
      expect(recordOf(doc, labels[i]).text, 'A${i + 1}', reason: why);
    }
    for (final i in [10, 11]) {
      expect(doc.tree[before[i].handle], isNull);
      expect(doc.entities.slotOf(labels[i]), isNull,
          reason: 'seat ${i + 1}\'s label goes with it');
      expect(doc.components.get<SeatNote>(before[i].handle), isNull);
    }
    expect(doc.commands.undoDepth, depth + 1);
    expect([for (final s in seats(doc, hRow2)) s.handle], row2Seats);
    expect(drift(doc), isEmpty);
    final shrunk = canon(doc);

    doc.commands.undo();
    expect(canon(doc), noted);
    expect([for (final s in seats(doc, hRow1)) s.handle],
        [for (final s in before) s.handle]);
    for (final i in [10, 11]) {
      expect(doc.components.get<SeatNote>(before[i].handle),
          SeatNote('n${i + 1}'));
      expect(leavesOf(doc, before[i].handle), [labels[i]]);
    }
    expect(drift(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), shrunk);
  });

  test(
      'E5-noop an edit that leaves a curved row\'s output as it is plans '
      'nothing: no node touched, the summary components, the index not '
      'rebuilt (M-E5-eq-def, M-E5-eq-transform, M-E5-eq-layer, '
      'M-E5-eq-payload, M-E5-eq-text)', () async {
    final doc = hall();
    final index = SpatialIndex(doc);
    index.forEachInRect(Aabb2(Vector2(-20000, -20000), Vector2(30000, 30000)),
        const QueryFilter.all(), (_) {});
    final rebuilds = index.rebuildCount;
    final nodes = <Handle, Node?>{};
    for (final row in [hRow1, hRow2]) {
      nodes[row] = doc.tree[row];
      for (final s in seats(doc, row)) {
        nodes[s.handle] = s;
      }
    }
    resetRowCalls();
    final applied = await applying(
        doc,
        () => doc.commands.execute(
            SetComponentCommand<Row>(hRow2, row2.copyWith(note: 'aisle'))));
    expect(rowInstanceCalls, {hRow2: 1}, reason: 'the row regenerated');
    expect(rowGenerateCalls, {hRow2: 1});
    expect(applied.single.touched, {hRow2});
    expect(applied.single.capability, Capability.components);
    expect(index.rebuildCount, rebuilds);
    for (final MapEntry(key: h, value: n) in nodes.entries) {
      expect(identical(doc.tree[h], n), isTrue, reason: h.toHex());
    }
    expect(drift(doc), isEmpty);
    index.dispose();
  });

  test(
      'E5-tag labels are matched by tag: two regenerations rewrite each '
      'seat\'s one label in place and keep its tag; a new payload is '
      'rewritten in place; a new tag is added, a missing one removed; a '
      'caller\'s edit of a label is refused (M-E5-tag-own, M-E5-tag-missing, '
      'M-E5-tag-add, M-E5-owned)', () {
    final doc = hall();
    final labels = labelsOf(doc, hRow2);
    final ss = [for (final s in seats(doc, hRow2)) s.handle];
    expect(ss, hasLength(5));

    void expectLabels(String prefix, double height) {
      for (var k = 0; k < ss.length; k++) {
        final why = 'seat ${k + 1}';
        expect(leavesOf(doc, ss[k]).first, labels[k], reason: why);
        final r = recordOf(doc, labels[k]);
        expect(r.tag, kSeatTag, reason: why);
        expect(r.text, '$prefix${k + 1}', reason: why);
        expect(r.textAttrs, kSeatLabelAttrs, reason: why);
        expect(payloadOf(doc, labels[k]).scalars[0], height, reason: why);
      }
    }

    for (final prefix in ['C', 'D']) {
      doc.commands.execute(
          SetComponentCommand<Row>(hRow2, row2.copyWith(prefix: prefix)));
      for (var k = 0; k < ss.length; k++) {
        expect(leavesOf(doc, ss[k]), [labels[k]],
            reason: 'one label on seat ${k + 1}, the same one');
      }
      expectLabels(prefix, row2.labelHeight);
      expect(drift(doc), isEmpty);
    }

    doc.commands.execute(SetComponentCommand<Row>(
        hRow2, row2.copyWith(prefix: 'D', labelHeight: 175.5)));
    for (var k = 0; k < ss.length; k++) {
      expect(leavesOf(doc, ss[k]), [labels[k]]);
    }
    expectLabels('D', 175.5);

    const extra = Row(hSeat, 5,
        prefix: 'D',
        spacing: 700.25,
        bend: 0.125,
        labelHeight: 175.5,
        extraTag: 'ROW');
    doc.commands.execute(SetComponentCommand<Row>(hRow2, extra));
    final extras = <Handle>[];
    for (var k = 0; k < ss.length; k++) {
      final [label, added] = leavesOf(doc, ss[k]);
      expect(label, labels[k]);
      final r = recordOf(doc, added);
      expect(r.kind, EntityKind.attrib);
      expect(r.tag, 'ROW');
      expect(r.text, 'D');
      expect(r.layer, ReservedHandles.layerZero);
      expect(r.textAttrs, 0);
      extras.add(added);
    }
    expectLabels('D', 175.5);
    expect(drift(doc), isEmpty);

    doc.commands.execute(SetComponentCommand<Row>(
        hRow2, row2.copyWith(prefix: 'D', labelHeight: 175.5)));
    for (var k = 0; k < ss.length; k++) {
      expect(leavesOf(doc, ss[k]), [labels[k]]);
      expect(doc.entities.slotOf(extras[k]), isNull);
    }
    expect(drift(doc), isEmpty);

    // A caller's edit of a label: 06 D6's entity branch, which now covers
    // a generated instance's ATTRIBs (`owned`).
    final bytes = enc(doc);
    final depth = doc.commands.undoDepth;
    expect(
        () => doc.commands
            .execute(SetEntityTextCommand(labels[2], 'Z9', kSeatTag)),
        throwsA(isA<GeneratedGeometryError>()
            .having((e) => e.handle, 'handle', labels[2])));
    expect(enc(doc), bytes);
    expect(doc.commands.undoDepth, depth);
  });

  test(
      'E5-dup-tag a loaded seat carrying two labels of one tag: the lowest '
      'handle is matched, the other removed, in one undo step (M-E5-lowest)',
      () {
    final built = hall();
    final third = seats(built, hRow1)[2].handle;
    final original = leavesOf(built, third).single;
    late Handle extra;
    final doc = loadedWith(built, (raw) {
      extra = raw.handleSeed.next();
      raw.commands.execute(AddEntityCommand(
          record: recordOf(raw, original).copyWith(handle: extra, text: 'zz'),
          payload: payloadOf(raw, original)));
    });
    expect(leavesOf(doc, third), [original, extra]);
    expect(recordOf(doc, extra).tag, kSeatTag);
    expect(drift(doc), [hRow1], reason: 'its plan would remove the surplus');
    final loaded = canon(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(prefix: 'E')));
    expect(leavesOf(doc, third), [original]);
    expect(recordOf(doc, original).text, 'E3');
    expect(doc.entities.slotOf(extra), isNull);
    expect(doc.commands.undoDepth, depth + 1);
    expect(drift(doc), isEmpty);
    doc.commands.undo();
    expect(canon(doc), loaded);
  });

  test(
      'E5-def an output naming no live definition: the edit is refused '
      'before any command; probe returns the error, drift throws it '
      '(M-E5-def)', () {
    final doc = hall();
    const ghost = Handle(4242);
    final bytes = enc(doc);
    final depth = doc.commands.undoDepth;
    final state = doc.commands.stateId;
    // A dead handle, and a live node that is not a definition.
    for (final bad in [ghost, hRow2]) {
      expect(
          () => doc.commands.execute(
              SetComponentCommand<Row>(hRow1, row1.copyWith(seat: bad))),
          throwsA(isA<GeneratedDefinitionError>()
              .having((e) => e.object, 'object', hRow1)
              .having((e) => e.definition, 'definition', bad)),
          reason: bad.toHex());
      expect(enc(doc), bytes);
      expect(doc.commands.undoDepth, depth);
      expect(doc.commands.stateId, state);
    }

    // A loaded file whose row names a dead definition.
    final loaded = loadedWith(
        doc,
        (raw) => raw.commands.execute(
            SetComponentCommand<Row>(hRow1, row1.copyWith(seat: ghost))));
    final saved = enc(loaded);
    final system = ParametricSystem(loaded, rowCatalog);
    expect(
        system.probe(hRow1),
        isA<GeneratedDefinitionError>()
            .having((e) => e.object, 'object', hRow1)
            .having((e) => e.definition, 'definition', ghost));
    expect(system.probe(hRow2), isNull);
    expect(() => system.drift(), throwsA(isA<GeneratedDefinitionError>()));
    expect(enc(loaded), saved);
  });

  test(
      'E5-default a type that keeps the default instances regenerates as '
      'before beside rows: its group gains no node, its TEXT is rewritten in '
      'place (M-E5-default)', () {
    final doc = hall();
    const hCaption = Handle(3000);
    place(doc, hCaption, atRow1.multiply(Transform2.translation(-900.5, 1200.25)),
        const Caption('Stage', 40.5, -12.25));
    expect((doc.tree[hCaption]! as GroupNode).children, isEmpty);
    final [text] = leavesOf(doc, hCaption);
    expect(recordOf(doc, text).text, 'Stage');
    doc.commands.execute(SetComponentCommand<Caption>(
        hCaption, const Caption('Screen', 40.5, -12.25)));
    expect((doc.tree[hCaption]! as GroupNode).children, isEmpty);
    expect(leavesOf(doc, hCaption), [text]);
    expect(recordOf(doc, text).text, 'Screen');
    expect(drift(doc), isEmpty);
  });

  test(
      'E5-order generated handles run in output order, each label just above '
      'its seat; a regrown seat takes handles above every other; existing '
      'seats are matched ascending by handle whatever order the group lists '
      'them in (M-E5-sort)', () {
    final doc = hall();
    final line = leavesOf(doc, hRow1).single;
    final ss = seats(doc, hRow1);
    expect((doc.tree[hRow1]! as GroupNode).children,
        [for (final s in ss) s.handle]);
    var last = line.value;
    for (final s in ss) {
      expect(s.handle.value, greaterThan(last));
      expect(leavesOf(doc, s.handle).single.value, s.handle.value + 1);
      last = s.handle.value + 1;
    }

    doc.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(count: 10)));
    final top = doc.handleSeed.current.value;
    doc.commands.execute(SetComponentCommand<Row>(hRow1, row1));
    final grown = seats(doc, hRow1);
    expect([for (final s in grown.take(10)) s.handle],
        [for (final s in ss.take(10)) s.handle]);
    expect([for (final s in grown.skip(10)) s.handle.value],
        [top + 1, top + 3]);
    expect(leavesOf(doc, grown[10].handle).single.value, top + 2);
    expect(leavesOf(doc, grown[11].handle).single.value, top + 4);
    expect(recordOf(doc, leavesOf(doc, grown[11].handle).single).text, 'A12');

    // A loaded file whose group lists the seats in reverse.
    final loaded = loadedWith(doc, (raw) {
      final group = raw.tree[hRow1]! as GroupNode;
      raw.tree.replaceNode(
          group.copyWith(children: group.children.reversed.toList()));
    });
    final asc = seats(loaded, hRow1);
    expect((loaded.tree[hRow1]! as GroupNode).children,
        [for (final s in asc.reversed) s.handle]);
    loaded.commands.execute(
        SetComponentCommand<Row>(hRow1, row1.copyWith(prefix: 'F')));
    for (var k = 0; k < asc.length; k++) {
      expect(identical(loaded.tree[asc[k].handle], asc[k]), isTrue,
          reason: 'seat ${k + 1} not moved');
      expect(recordOf(loaded, leavesOf(loaded, asc[k].handle).single).text,
          'F${k + 1}');
    }
  });

  test(
      'E5-layer a generated seat is on its object\'s layer and follows it in '
      'one undo step; its label stays on layer 0, BYBLOCK (M-E5-layer-add, '
      'M-E5-layer-match, M-E5-label-layer)', () {
    final doc = rowDoc();
    final stalls = addLayer(doc, 'Stalls', 3);
    final balcony = addLayer(doc, 'Balcony', 5);
    place(doc, hRow2, atRow2, row2, layer: stalls);
    final ss = seats(doc, hRow2);
    final labels = labelsOf(doc, hRow2);
    final line = leavesOf(doc, hRow2).single;
    // Premise: row 2 is mirrored in world.
    final m = doc.tree.accumulatedTransform(hRow2);
    expect(m.a * m.d - m.b * m.c, lessThan(0));

    void expectOn(Handle layer) {
      expect(doc.entities.layerAt(doc.entities.slotOf(line)!), layer,
          reason: 'the LINE child (12b D2)');
      for (var k = 0; k < ss.length; k++) {
        final why = 'seat ${k + 1}';
        expect((doc.tree[ss[k].handle]! as InstanceNode).layer, layer,
            reason: why);
        final r = recordOf(doc, labels[k]);
        expect(r.layer, ReservedHandles.layerZero, reason: why);
        expect(r.color, const ByBlockColor(), reason: why);
        expect(r.transparency, kByBlock, reason: why);
      }
    }

    expectOn(stalls);
    final placed = canon(doc);
    final depth = doc.commands.undoDepth;
    doc.commands.execute(
        SetComponentCommand<ObjectLayer>(hRow2, ObjectLayer(balcony)));
    expect([for (final s in seats(doc, hRow2)) s.handle],
        [for (final s in ss) s.handle]);
    expectOn(balcony);
    expect(doc.commands.undoDepth, depth + 1);
    final moved = canon(doc);
    doc.commands.undo();
    expect(canon(doc), placed);
    expectOn(stalls);
    doc.commands.redo();
    expect(canon(doc), moved);
    expect(drift(doc), isEmpty);
  });
}
```

- [ ] **Step 3: Run the tests and see them fail.** Run: `cd packages/jet_cad_2d && dart test test/parametric/instances_test.dart`. Expected: compilation fails; the errors name the undefined `GeneratedInstance`, `GeneratedAttrib` and `GeneratedDefinitionError`, and `RowType.instances` overriding no inherited member. Quote the first error line.

- [ ] **Step 4: The output, the error and the hook.** In `lib/src/parametric/parametric_system.dart`:

  (a) In `ParametricType`, after `generate` (`:36-38`), add:

```dart
  /// The symbol instances this object generates (spec 2b S1, E5), each
  /// with its ATTRIBs, beside [generate]'s entities: in the group's local
  /// space, from its own parameters and its neighbours' only, as [generate]
  /// reads. Each becomes an `InstanceNode` child of the object's group, on
  /// the object's layer, with `InstanceNode`'s default style fixed when it
  /// is added; each [GeneratedAttrib] an ATTRIB the instance owns, on layer
  /// 0, BYBLOCK, left out of the layer and style stamps.
  ///
  /// The i-th output meets the i-th existing instance, ascending by handle:
  /// a matched instance keeps its handle and every component on it, and
  /// its ATTRIBs are matched by tag. An unchanged output plans nothing. An
  /// output naming a handle that is not a live definition throws
  /// [GeneratedDefinitionError] from the plan, before any command.
  ///
  /// Called after [generate], with the same view, for every object an edit
  /// regenerates and that does not dissolve, and by `drift()` and `probe`.
  /// Must not mutate. Default: none. Every `InstanceNode` child of an
  /// object's group is that object's generated instance, so a type that
  /// keeps the default removes one on its next regeneration.
  List<GeneratedInstance> instances(ParametricView view, Handle self) =>
      const [];
```

  (b) After `class Generated` (ends `:336`), add:

```dart
/// One ATTRIB of a [GeneratedInstance] (spec 2b S1): its [tag] (the key it
/// is matched by), its [text] and its [payload], a text payload in the
/// instance's local (definition) space, as an ATTRIB's coordinates are.
/// [textAttrs] (`packTextAttrs`) is written on add only, like
/// [Generated.textAttrs]; the text and the payload are rewritten on a match
/// when they differ.
final class GeneratedAttrib {
  /// Throws `ArgumentError` for an empty [tag]: the planner matches by tag.
  GeneratedAttrib(this.tag, this.text, this.payload, {this.textAttrs = 0}) {
    if (tag.isEmpty) {
      throw ArgumentError.value(
          tag, 'tag', 'a generated ATTRIB needs a tag (spec 2b S1)');
    }
  }

  final String tag;
  final String text;
  final GeometryPayload payload;
  final int textAttrs;
}

/// One symbol instance a parametric type generates (spec 2b S1): an
/// instance of the live definition [definition], placed by [transform] in
/// the object's group's local space, with [attributes] as its ATTRIBs.
final class GeneratedInstance {
  /// Throws `ArgumentError` for two [attributes] with one tag. Keeps an
  /// unmodifiable copy of [attributes].
  GeneratedInstance(this.definition, this.transform,
      {List<GeneratedAttrib> attributes = const []})
      : attributes = List.unmodifiable(attributes) {
    final tags = <String>{};
    for (final a in this.attributes) {
      if (!tags.add(a.tag)) {
        throw ArgumentError.value(a.tag, 'attributes',
            'two generated ATTRIBs carry one tag (spec 2b S1)');
      }
    }
  }

  final Handle definition;
  final Transform2 transform;
  final List<GeneratedAttrib> attributes;
}
```

  (c) After `class DanglingReferenceError` (ends `:386`), add:

```dart
/// A generated instance naming a handle that is not a live definition
/// (spec 2b S1, "The definition"). Thrown by the planner while planning,
/// before any command: an edit is undone and nothing enters the history,
/// `probe` returns it and `drift()` throws it. A host's failure boundary
/// freezes the object (spec 2a E2); it is deliberately not a refusal.
final class GeneratedDefinitionError implements Exception {
  const GeneratedDefinitionError(this.object, this.definition);

  /// The object whose `instances` named it.
  final Handle object;

  /// The handle named, which is not a live definition.
  final Handle definition;

  @override
  String toString() => 'GeneratedDefinitionError: ${object.toHex()} '
      'generated an instance of ${definition.toHex()}, which is not a live '
      'definition';
}
```

  (d) In `_Registration`, after `generate` (`:994`), add:

```dart
  List<GeneratedInstance> instancesOf(ParametricView v, Handle h) =>
      type.instances(v, h);
```

- [ ] **Step 5: The survey.** In `lib/src/parametric/regeneration.dart`:

  (a) `_Survey`: append three constructor parameters after `this.stray` (`this.instances, this.generated, this.leaves`), replace the doc comments of `children` and `owned`, and add the three fields after `stray`:

```dart
  /// Each object's children, ascending: its entities only. Its generated
  /// instances are in [instances] (spec 2b S1).
  final Map<Handle, List<Handle>> children;

  /// Every child of a live object, and every ATTRIB of one of its generated
  /// instances (spec 2b S1), to its object: the set G of spec D4. So 06 D6's
  /// entity branch covers a generated ATTRIB, and an edit of one seeds its
  /// object.
  final Map<Handle, Handle> owned;
```

```dart
  /// Spec 2b S1: each live object's generated instances, the
  /// `InstanceNode` children of its group, ascending by handle, each its
  /// node value at this moment (nodes are immutable: a reference, not a
  /// copy). Absent when it has none. A nested group's instances are not
  /// generated.
  final Map<Handle, List<InstanceNode>> instances;

  /// Each generated instance of [instances], by handle, to its node value;
  /// its object is the node's `parent`.
  final Map<Handle, InstanceNode> generated;

  /// Each generated instance's own entities (its ATTRIBs, and whatever a
  /// loaded file put on it), ascending; absent when none.
  final Map<Handle, List<Handle>> leaves;
```

  (b) In `_survey`, replace the block from `final children = <Handle, List<Handle>>{};` through the `for (final list in children.values) { list.sort(_byValue); }` loop (`:256-267`) with:

```dart
  // Spec 2b S1: each object's generated instances, from its group's own
  // list, ascending by handle whatever order the list is in.
  final instances = <Handle, List<InstanceNode>>{};
  final generated = <Handle, InstanceNode>{};
  for (final h in order) {
    for (final c in (t.tree[h]! as GroupNode).children) {
      final node = t.tree[c];
      if (node is InstanceNode &&
          node.parent == h &&
          !generated.containsKey(c)) {
        (instances[h] ??= []).add(node);
        generated[c] = node;
      }
    }
  }
  for (final list in instances.values) {
    list.sort((a, b) => _byValue(a.handle, b.handle));
  }
  final children = <Handle, List<Handle>>{};
  final owned = <Handle, Handle>{};
  final leaves = <Handle, List<Handle>>{};
  for (final slot in t.entities.liveSlots) {
    final owner = t.entities.ownerAt(slot);
    if (objects.containsKey(owner)) {
      final h = t.entities.handleAt(slot);
      (children[owner] ??= []).add(h);
      owned[h] = owner;
      continue;
    }
    final node = generated[owner];
    if (node == null) continue;
    final h = t.entities.handleAt(slot);
    (leaves[owner] ??= []).add(h);
    if (t.entities.kindAt(slot) == EntityKind.attrib) owned[h] = node.parent;
  }
  for (final list in children.values) {
    list.sort(_byValue);
  }
  for (final list in leaves.values) {
    list.sort(_byValue);
  }
```

  (c) In `_survey`'s `return _Survey(…)`, append `instances, generated, leaves` after `stray`.

- [ ] **Step 6: Matching.** Still in `regeneration.dart`:

  (a) In `_plan`, at the end of the per-object loop body, right after the surplus loop `for (final c in surplus) { out.add(RemoveEntityCommand(c)); }` (`:657-659`), add:

```dart
    // Spec 2b S1 "Matching": the object's generated instances, after its
    // entities, from the same view.
    reserved = _planInstances(
        t, s, h, registration.instancesOf(view, h), layer, reserved, out);
```

  and append to `_plan`'s doc comment (before the dissolve paragraph):

```dart
/// Then its generated instances (spec 2b S1, [_planInstances]): matched by
/// position, ascending by handle, their ATTRIBs by tag, every command
/// planned only on an exact-`==` difference of the stored value.
///
```

  (b) After `_plan`, add:

```dart
/// Stored transforms compare exactly (12b R-15): `Transform2` has no `==`,
/// and `InstanceNode.==` compares with this tolerance.
const Tolerance _exact = Tolerance(linear: 0, angular: 0);

/// The record of an ATTRIB the plan adds onto [instance] (spec 2b S1): the
/// shape of today's table label, on layer 0 with BYBLOCK style, so it
/// follows its instance; the layer and style stamps never touch it.
EntityRecord _attribRecord(Handle handle, Handle instance, GeneratedAttrib a) =>
    EntityRecord(
      handle: handle,
      owner: instance,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
      text: a.text,
      tag: a.tag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: a.textAttrs,
    );

/// Spec 2b S1 "Matching": plans [object]'s generated instances against
/// [outputs] into [out], and returns the last handle reserved.
///
/// First, every output must name a live definition, or this throws
/// [GeneratedDefinitionError] (nothing has applied yet). Then the i-th
/// output meets the i-th existing instance, ascending by handle: a new
/// definition is a `SetInstanceDefinitionCommand`, a new transform a
/// `TransformNodeCommand` (exact, [_exact]), a node off [layer] (the
/// object's) a `SetInstanceLayerCommand.restore`; then its ATTRIBs
/// ([_planAttributes]). An unmatched output is added under reserved
/// handles, the node then its ATTRIBs, the node with `InstanceNode`'s
/// default style. A surplus instance is removed ([_instanceRemoval]).
int _planInstances(CommandTarget t, _Survey s, Handle object,
    List<GeneratedInstance> outputs, Handle layer, int reserved,
    List<DraftCommand> out) {
  for (final g in outputs) {
    if (t.tree.definition(g.definition) == null) {
      throw GeneratedDefinitionError(object, g.definition);
    }
  }
  final existing = s.instances[object] ?? const <InstanceNode>[];
  for (var i = 0; i < outputs.length; i++) {
    final g = outputs[i];
    if (i < existing.length) {
      final node = existing[i];
      final c = node.handle;
      if (node.definition != g.definition) {
        out.add(SetInstanceDefinitionCommand(c, g.definition));
      }
      if (!node.transform.equals(g.transform, _exact)) {
        out.add(TransformNodeCommand(c, g.transform));
      }
      if (node.layer != layer) {
        out.add(SetInstanceLayerCommand.restore(c, layer));
      }
      reserved = _planAttributes(t, s, c, g.attributes, reserved, out);
    } else {
      final c = Handle.checked(++reserved);
      out.add(AddNodeCommand(InstanceNode(
          handle: c,
          parent: object,
          transform: g.transform,
          definition: g.definition,
          layer: layer)));
      for (final a in g.attributes) {
        out.add(AddEntityCommand(
            record: _attribRecord(Handle.checked(++reserved), c, a),
            payload: a.payload));
      }
    }
  }
  for (final node in existing.skip(outputs.length)) {
    out.addAll(_instanceRemoval(t, s, node.handle));
  }
  return reserved;
}

/// A matched instance's ATTRIBs against [attributes] (spec 2b S1): bucketed
/// by tag, ascending, so the lowest handle of a tag is matched and the
/// rest are surplus (a loaded file). A matched one gets
/// `SetEntityGeometryCommand` for a new payload and `SetEntityTextCommand`
/// for a new text, **passing its own tag** (the TEXT call's `''` would
/// blank it, and the next regeneration would match nothing). An unmatched
/// tag is added; a surplus one, or one of a tag no output names, is
/// removed. Returns the last handle reserved.
int _planAttributes(CommandTarget t, _Survey s, Handle instance,
    List<GeneratedAttrib> attributes, int reserved, List<DraftCommand> out) {
  final byTag = <String, Handle>{};
  final surplus = <Handle>[];
  for (final c in s.leaves[instance] ?? const <Handle>[]) {
    final slot = t.entities.slotOf(c)!;
    if (t.entities.kindAt(slot) != EntityKind.attrib) continue;
    final tag = t.entities.tagAt(slot);
    if (byTag.containsKey(tag)) {
      surplus.add(c);
    } else {
      byTag[tag] = c;
    }
  }
  for (final a in attributes) {
    final c = byTag.remove(a.tag);
    if (c == null) {
      out.add(AddEntityCommand(
          record: _attribRecord(Handle.checked(++reserved), instance, a),
          payload: a.payload));
      continue;
    }
    final slot = t.entities.slotOf(c)!;
    if (!_samePayload(
        t.geometry.peek(t.entities.geomIndexAt(slot)), a.payload)) {
      out.add(SetEntityGeometryCommand(c, a.payload));
    }
    if (t.entities.textAt(slot) != a.text) {
      out.add(SetEntityTextCommand(c, a.text, t.entities.tagAt(slot)));
    }
  }
  for (final c in [...surplus, ...byTag.values]..sort(_byValue)) {
    out.add(RemoveEntityCommand(c));
  }
  return reserved;
}

/// A surplus generated instance's removal: every entity it owns, fills
/// first (a boundary's removal would take its fill), then its node.
List<DraftCommand> _instanceRemoval(
    CommandTarget t, _Survey s, Handle instance) {
  final leaves = s.leaves[instance] ?? const <Handle>[];
  bool isFill(Handle c) =>
      t.entities.kindAt(t.entities.slotOf(c)!) == EntityKind.fill;
  return [
    for (final c in leaves)
      if (isFill(c)) RemoveEntityCommand(c),
    for (final c in leaves)
      if (!isFill(c)) RemoveEntityCommand(c),
    RemoveNodeCommand(instance),
  ];
}
```

  Every name used here is already imported by `parametric_system.dart` (`Tolerance`, `EntityRecord`, `ReservedHandles`, `ByBlockColor`, `kByBlock`, the commands, `SetInstanceLayerCommand`, `InstanceNode`).

- [ ] **Step 7: The plan library's forwarder (ruling R-1).** In `packages/jet_cad_2d_plan/lib/src/kits/guard.dart`, add to `GuardedType` right after `generate` (`:76-84`):

```dart
  @override
  List<GeneratedInstance> instances(ParametricView view, Handle self) {
    try {
      return inner.instances(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('instances', e, s);
    }
  }
```

  Without it `GuardedType<T> implements ParametricType<T>` (`:42`) misses a concrete member and the plan library does not compile. Its tests (a throwing `instances` → `KitHookFailure` naming `instances`, the object frozen) are Task 4's PB-guard.

- [ ] **Step 8: CS11's premise (controller ruling R-4).** In `test/parametric/cascade_test.dart`, CS11 (`:623-672`) adds an `InstanceNode` directly under P1. Under S1 it is P1's generated instance, and Pin keeps the default `instances`, so P1's plan would remove it: `drift` names P1. Replace line `:656`, `    expect(drift(doc), isEmpty);`, with:

```dart
    // Spec 2b S1: an InstanceNode child of P1's group is P1's generated
    // instance; Pin generates none, so P1's plan would remove it.
    expect(drift(doc), [hP1]);
```

  Nothing else in CS11 changes in this task. Record it in the ledger as ruling R-4: an existing engine test's premise changed by the spec, not a weakened assertion.

- [ ] **Step 9: The CHANGELOG.** In `CHANGELOG.md`, under `## Unreleased`, add after the last bullet (the `NonLiveWriteError` one) and before `## 0.7.2`:

```markdown
- `ParametricType.instances(view, self)` (default: none) lets a type
  generate symbol instances beside its entities. Each
  `GeneratedInstance(definition, transform, attributes: […])` becomes an
  `InstanceNode` child of the object's group, on the object's layer, and
  each `GeneratedAttrib(tag, text, payload)` an ATTRIB the instance owns,
  on layer 0, BYBLOCK. The planner matches instances by position and
  ATTRIBs by tag, so a regeneration keeps a seat's handle and everything
  on it, and an unchanged output plans nothing. An output naming no live
  definition throws `GeneratedDefinitionError` while planning: the edit is
  refused, `probe` returns it and `drift()` throws it. Every
  `InstanceNode` child of an object's group is now that object's
  generated instance: a type that generates none removes it on its next
  regeneration.
```

- [ ] **Step 10: Run the new tests.** Run: `cd packages/jet_cad_2d && dart test test/parametric/instances_test.dart`. Expected: `All tests passed!` (9 tests).

- [ ] **Step 11: The gates.** Run, one at a time:
  - `cd packages/jet_cad_2d && dart format .`
  - `cd packages/jet_cad_2d && dart test test/parametric`. Expected: `All tests passed!`. This is E5-default's second half: every existing parametric test passes with types that keep the default `instances` (CS11 with Step 8's line).
  - `cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart`. Expected: `All tests passed!`.
  - `cd packages/jet_cad_2d && dart test test/testing/generate_document_test.dart` (the standing hash tests). Expected: the only failures are the two `packages/jet_cad_2d` lines of `tool/ci/standing_failures.txt`, by name; quote the summary line.
  - `cd packages/jet_cad_2d && dart test`. Expected: the only failures are those same two.
  - `cd packages/jet_cad_2d && dart analyze`. Expected: `No issues found!`.
  - `cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .`. Expected: exit 0.
  - `cd packages/jet_cad_2d_plan && dart format .`, then `flutter analyze` (`No issues found!`), `flutter test` (`All tests passed!`; quote the count line), `dart format --output=none --set-exit-if-changed .` (exit 0).

- [ ] **Step 12: The dependents, unchanged.** Run, one at a time: `cd packages/jet_cad_floor_plan && flutter test`, `cd packages/jet_cad_2d_flutter && flutter test`, `cd packages/jet_cad_2d_kit && flutter test`. Expected for each: the result of clean `main`; the only failures are the lines `tool/ci/standing_failures.txt` lists for that package. A new failure is a finding: stop and report it (do not edit a dependent). Then `git status --short`: only this task's files; leave any rewritten `analysis_options.yaml` unstaged.

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d/lib/src/parametric/parametric_system.dart packages/jet_cad_2d/lib/src/parametric/regeneration.dart packages/jet_cad_2d/CHANGELOG.md packages/jet_cad_2d/test/parametric/support/row_clients.dart packages/jet_cad_2d/test/parametric/instances_test.dart packages/jet_cad_2d/test/parametric/cascade_test.dart packages/jet_cad_2d_plan/lib/src/kits/guard.dart
git commit -m "$(cat <<'EOF'
feat(engine): E5, a parametric type generates instances (2b S1)

ParametricType.instances returns GeneratedInstances beside generate.
Each becomes an InstanceNode child of the object's group, on its layer,
and each GeneratedAttrib an ATTRIB the instance owns, on layer 0,
BYBLOCK. The planner matches instances by position and ATTRIBs by tag,
plans nothing for an unchanged output, and throws
GeneratedDefinitionError for an output naming no live definition.
GuardedType forwards the new hook, so the plan library compiles.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: Mutation check.** On the committed files only. For each mutation:
  1. apply the edit;
  2. run `cd packages/jet_cad_2d && dart test test/parametric/instances_test.dart --name '<id>'`;
  3. see it red and quote the failing expectation line;
  4. `git checkout -- <file>`;
  5. `git diff --quiet -- <file>`, which must exit 0.

  In `lib/src/parametric/parametric_system.dart`:
  - M-E5-args-tag: delete the `if (tag.isEmpty) { throw … }` statement of `GeneratedAttrib` → `E5-args` red.
  - M-E5-args-dup: delete the `if (!tags.add(a.tag)) { throw … }` statement of `GeneratedInstance` → `E5-args` red.
  - M-E5-args-copy: `: attributes = List.unmodifiable(attributes)` → `: attributes = attributes` → `E5-args` red.
  - M-E5-default: the default `instances` body `=> const [];` → `=> throw UnimplementedError('instances');` → `E5-default` red (also every row-free parametric test; quote `E5-default`).

  In `lib/src/parametric/regeneration.dart`:
  - M-E5-call: in `_plan`, `registration.instancesOf(view, h)` → `const <GeneratedInstance>[]` → `E5-shrink` red.
  - M-E5-match: in `_planInstances`, `final existing = s.instances[object] ?? const <InstanceNode>[];` → `final existing = const <InstanceNode>[];` → `E5-shrink` red (22 seats).
  - M-E5-surplus-leaves: in `_instanceRemoval`, delete the two `for (final c in leaves) …` elements → `E5-shrink` red (seat 11's label left).
  - M-E5-label-shape: in `_attribRecord`, `color: const ByBlockColor(),` → `color: const ByLayerColor(),` → `E5-shrink` red.
  - M-E5-eq-def: `if (node.definition != g.definition) {` → `if (true) {` → `E5-noop` red.
  - M-E5-eq-transform: `if (!node.transform.equals(g.transform, _exact)) {` → `if (true) {` → `E5-noop` red.
  - M-E5-eq-layer: `if (node.layer != layer) {` → `if (true) {` → `E5-noop` red.
  - M-E5-eq-payload: in `_planAttributes`, `if (!_samePayload(` … `)) {` → `if (true) {` (keep the call out: replace the whole condition) → `E5-noop` red.
  - M-E5-eq-text: `if (t.entities.textAt(slot) != a.text) {` → `if (true) {` → `E5-noop` red.
  - M-E5-tag-own: `SetEntityTextCommand(c, a.text, t.entities.tagAt(slot))` → `SetEntityTextCommand(c, a.text, '')` → `E5-tag` red.
  - M-E5-tag-missing: `for (final c in [...surplus, ...byTag.values]..sort(_byValue)) {` → `for (final c in surplus..sort(_byValue)) {` → `E5-tag` red (the `ROW` labels stay).
  - M-E5-tag-add: replace the `if (c == null) { out.add(…); continue; }` block with `if (c == null) continue;` → `E5-tag` red.
  - M-E5-owned: in `_survey`, delete `if (t.entities.kindAt(slot) == EntityKind.attrib) owned[h] = node.parent;` → `E5-tag` red (the caller's label edit passes).
  - M-E5-lowest: replace the `if (byTag.containsKey(tag)) { surplus.add(c); } else { byTag[tag] = c; }` statement with `if (byTag[tag] case final lower?) surplus.add(lower); byTag[tag] = c;` → `E5-dup-tag` red.
  - M-E5-def: delete the `for (final g in outputs) { if (t.tree.definition(g.definition) == null) { throw … } }` loop → `E5-def` red.
  - M-E5-sort: in `_survey`, delete `for (final list in instances.values) { list.sort(…); }` → `E5-order` red.
  - M-E5-layer-add: in `_planInstances`' add branch, `layer: layer)));` → `layer: ReservedHandles.layerZero)));` → `E5-layer` red.
  - M-E5-layer-match: delete the `if (node.layer != layer) { out.add(SetInstanceLayerCommand.restore(c, layer)); }` statement → `E5-layer` red.
  - M-E5-label-layer (an addition): in `_planAttributes`, after the `SetEntityTextCommand` `if` statement, add `out.add(SetEntityLayerCommand.restore(c, objectLayer(t, t.tree[instance]!.parent)));` → `E5-layer` red (the labels move to Balcony).

  `E5-args`' field read-back line and the premise lines of `E5-shrink`, `E5-order` and `E5-layer` are fixture sanity, exempt. Then run `cd packages/jet_cad_2d && dart test test/parametric` once more: `All tests passed!`.

#### Interface problem

Resolved by R-1 (the `GuardedType.instances` forwarder lands here, Step 7) and R-4 (CS11: `drift` names P1 here, Step 8; Task 2 brings the three adds in as a loaded file would).

**Note, not an interface change.** S1 makes every `InstanceNode` child of an object's group a generated instance. A type that keeps the default removes such a node on its next regeneration. Nothing in the workspace places one there except CS11 (`grep` of `InstanceNode(` across `packages/*/lib` and the dependents' tests; the placers put instances at the root). The CHANGELOG bullet says so.

---

