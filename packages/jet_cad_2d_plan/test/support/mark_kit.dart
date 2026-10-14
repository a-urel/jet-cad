// A one-type kit for the panel and export tests: `mark.cross`, a cross of
// two lines of half-size `size` about the group's local origin. Its type
// is real (it registers, generates and regenerates through the parametric
// system), so a mark is a live parametric object for the catalog (E1).
// `exported: false` gives the same type for the export omission tests.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final class MarkCross implements Component {
  const MarkCross(this.size);

  static const String componentTypeId = 'mark.cross';

  /// Half the cross's width, in mm.
  final double size;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {'size': size};

  static MarkCross fromJson(Map<String, Object?> json) =>
      MarkCross((json['size']! as num).toDouble());

  @override
  bool operator ==(Object other) => other is MarkCross && other.size == size;

  @override
  int get hashCode => size.hashCode;
}

final class MarkCrossType extends ParametricType<MarkCross> {
  const MarkCrossType();

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(MarkCross params, Transform2 toWorld) {
    final s = params.size;
    return Aabb2.fromPoints([
      for (final c in [
        Vector2(-s, -s),
        Vector2(s, -s),
        Vector2(s, s),
        Vector2(-s, s),
      ])
        toWorld.transformPoint(c),
    ]);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final s = view.paramsOf<MarkCross>(self)!.size;
    return [
      Generated(EntityKind.line, linePayload(Vector2(-s, -s), Vector2(s, s))),
      Generated(EntityKind.line, linePayload(Vector2(-s, s), Vector2(s, -s))),
    ];
  }
}

/// The kit `mark` (version 1.0.0) with its one type; [exported] false
/// leaves marks out of every export (spec P5, "omitted types").
PlanKit markKit({bool exported = true}) => PlanKit(
      id: 'mark',
      version: '1.0.0',
      types: [
        PlanType<MarkCross>(
          id: MarkCross.componentTypeId,
          fromJson: MarkCross.fromJson,
          parametric: const MarkCrossType(),
          exported: exported,
        ),
      ],
      names: const KitNames({
        'en': {'type:mark.cross': 'Cross'},
      }),
    );

/// Adds a mark of half-size [size] at [at] on [layer] to [doc], as a tool
/// adds an object: one compound of its group, its component and its
/// `ObjectLayer`. Returns the group's handle.
Handle addMark(DraftDocument doc, Handle layer,
    {required Transform2 at, double size = 450.5}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: at, children: const [])),
    SetComponentCommand<MarkCross>(h, MarkCross(size)),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(layer)),
  ], label: 'Add mark'));
  return h;
}
