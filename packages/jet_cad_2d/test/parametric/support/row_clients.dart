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
          double? spacing,
          double? bend,
          double? labelHeight,
          String? note,
          bool? dissolve}) =>
      Row(seat ?? this.seat, count ?? this.count,
          prefix: prefix ?? this.prefix,
          spacing: spacing ?? this.spacing,
          bend: bend ?? this.bend,
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
Transform2 seatAt(Row r, int i) =>
    Transform2.translation(r.spacing * i, 0.5 * r.bend * r.spacing * i * i)
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
