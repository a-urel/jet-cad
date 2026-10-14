// A kit's code side (docs/kits.md section 10): a parametric type, its
// property specs, its colour target and its descriptor. Analysed with the
// package; test/kit/example_code_test.dart runs it.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

enum SignFace { chalk, board }

/// A cafe's menu board: its width in millimetres, its face and its colour.
final class CafeSign implements Component {
  const CafeSign({required this.width, required this.face, this.swatch});

  static const String id = 'cafe.sign';

  final double width;
  final SignFace face;
  final String? swatch;

  CafeSign copyWith({double? width, SignFace? face}) => CafeSign(
      width: width ?? this.width, face: face ?? this.face, swatch: swatch);

  CafeSign withSwatch(String? swatch) =>
      CafeSign(width: width, face: face, swatch: swatch);

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() =>
      {'face': face.name, 'swatch': swatch, 'width': width};

  static CafeSign fromJson(Map<String, Object?> json) => CafeSign(
        width: (json['width']! as num).toDouble(),
        face: SignFace.values.byName(json['face']! as String),
        swatch: json['swatch'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is CafeSign &&
      other.width == width &&
      other.face == face &&
      other.swatch == swatch;

  @override
  int get hashCode => Object.hash(width, face, swatch);
}

/// The sign's geometry: a closed outline, its width by 80 mm, centred on
/// its group's origin.
final class CafeSignType extends ParametricType<CafeSign> {
  const CafeSignType();

  static List<Vector2> outline(CafeSign sign) => [
        Vector2(-sign.width / 2, -40),
        Vector2(sign.width / 2, -40),
        Vector2(sign.width / 2, 40),
        Vector2(-sign.width / 2, 40),
      ];

  @override
  Capability get editCapability => Capability.geometry;

  @override
  Aabb2 reach(CafeSign params, Transform2 toWorld) => Aabb2.fromPoints(
      [for (final p in outline(params)) toWorld.transformPoint(p)]);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    final sign = view.paramsOf<CafeSign>(self)!;
    return [
      Generated(
          EntityKind.polyline, polylinePayload(outline(sign), closed: true)),
    ];
  }
}

final List<PropertySpec<CafeSign>> signProperties = [
  LengthProperty<CafeSign>(
    id: 'width',
    read: (s) => s.width,
    write: (s, v) => s.copyWith(width: v),
    min: 300,
    max: 2400,
  ),
  ChoiceProperty<CafeSign, SignFace>(
    id: 'face',
    values: SignFace.values,
    read: (s) => s.face,
    write: (s, v) => s.copyWith(face: v),
  ),
  ValueDisplay<CafeSign>(
    id: 'area',
    read: (s) => s.width * 80,
    unit: ValueUnit.area,
  ),
];

final ColourTarget<CafeSign> signColour = ColourTarget<CafeSign>(
  read: (s) => s.swatch,
  write: (s, swatch) => s.withSwatch(swatch),
);

final PlanKit cafeCodeKit = PlanKit(
  id: 'cafe',
  version: '0.1.0',
  types: [
    PlanType<CafeSign>(
      id: CafeSign.id,
      fromJson: CafeSign.fromJson,
      parametric: const CafeSignType(),
      properties: signProperties,
      colour: signColour,
    ),
  ],
  names: cafeCodeNames,
);

const KitNames cafeCodeNames = KitNames({
  'en': {
    'type:cafe.sign': 'Menu board',
    'property:cafe.sign.width': 'Width',
    'property:cafe.sign.face': 'Face',
    'property:cafe.sign.face.chalk': 'Chalk',
    'property:cafe.sign.face.board': 'Board',
    'property:cafe.sign.area': 'Area',
  },
  'tr': {
    'type:cafe.sign': 'Menü panosu',
    'property:cafe.sign.width': 'Genişlik',
    'property:cafe.sign.face': 'Yüzey',
    'property:cafe.sign.face.chalk': 'Tebeşir',
    'property:cafe.sign.face.board': 'Pano',
    'property:cafe.sign.area': 'Alan',
  },
});
