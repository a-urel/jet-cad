// Fixtures for the contract's code side (spec 2a P3): two component types of
// a kit "test", so a list can hold specs of two different owner types, and
// the specs of every property kind. Not degenerate: every value is away from
// its default and from zero, the turn is not a multiple of a right angle.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart';

enum Finish { oiled, waxed, raw }

/// A slab: one field per property kind.
@immutable
final class Slab implements Component {
  const Slab({
    this.width = 1250.5,
    this.depth = 640.25,
    this.turn = 0.35,
    this.grade = 2.5,
    this.finish = Finish.waxed,
    this.raised = true,
    this.label = 'Bar top',
    this.flipped = false,
    this.swatch = 'teal',
  });

  static const String id = 'test.slab';

  final double width;
  final double depth;
  final double turn;
  final double grade;
  final Finish finish;
  final bool raised;
  final String label;
  final bool flipped;
  final String? swatch;

  Slab copyWith({
    double? width,
    double? turn,
    double? grade,
    Finish? finish,
    bool? raised,
    String? label,
    bool? flipped,
    String? swatch,
    bool clearSwatch = false,
  }) =>
      Slab(
        width: width ?? this.width,
        depth: depth,
        turn: turn ?? this.turn,
        grade: grade ?? this.grade,
        finish: finish ?? this.finish,
        raised: raised ?? this.raised,
        label: label ?? this.label,
        flipped: flipped ?? this.flipped,
        swatch: clearSwatch ? null : swatch ?? this.swatch,
      );

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() => {
        'depth': depth,
        'finish': finish.name,
        'flipped': flipped,
        'grade': grade,
        'label': label,
        'raised': raised,
        'swatch': swatch,
        'turn': turn,
        'width': width,
      };

  static Slab fromJson(Map<String, Object?> j) => Slab(
        width: (j['width']! as num).toDouble(),
        depth: (j['depth']! as num).toDouble(),
        turn: (j['turn']! as num).toDouble(),
        grade: (j['grade']! as num).toDouble(),
        finish: Finish.values.byName(j['finish']! as String),
        raised: j['raised']! as bool,
        label: j['label']! as String,
        flipped: j['flipped']! as bool,
        swatch: j['swatch'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Slab &&
      other.width == width &&
      other.depth == depth &&
      other.turn == turn &&
      other.grade == grade &&
      other.finish == finish &&
      other.raised == raised &&
      other.label == label &&
      other.flipped == flipped &&
      other.swatch == swatch;

  @override
  int get hashCode => Object.hash(
      width, depth, turn, grade, finish, raised, label, flipped, swatch);

  @override
  String toString() => 'Slab($width x $depth, $label, $swatch)';
}

/// A post: a second owner type. Its `width` shares the slab's spec id on
/// purpose, so a field can be offered to the wrong type.
@immutable
final class Post implements Component {
  const Post({this.width = 180.75, this.shape = 'round', this.swatch});

  static const String id = 'test.post';

  final double width;
  final String shape;
  final String? swatch;

  @override
  String get typeId => id;

  @override
  Map<String, Object?> toJson() =>
      {'shape': shape, 'swatch': swatch, 'width': width};

  static Post fromJson(Map<String, Object?> j) => Post(
        width: (j['width']! as num).toDouble(),
        shape: j['shape']! as String,
        swatch: j['swatch'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Post &&
      other.width == width &&
      other.shape == shape &&
      other.swatch == swatch;

  @override
  int get hashCode => Object.hash(width, shape, swatch);

  @override
  String toString() => 'Post($width, $shape, $swatch)';
}

/// The slab's specs: all eight kinds, in panel order. `turn` needs the
/// rotate gate; `grade` is enabled only while the slab is raised.
List<PropertySpec<Slab>> slabSpecs() => [
      LengthProperty<Slab>(
        id: 'width',
        read: (s) => s.width,
        write: (s, v) => s.copyWith(width: v),
        min: 300,
        max: 4800,
      ),
      AngleProperty<Slab>(
        id: 'turn',
        read: (s) => s.turn,
        write: (s, v) => s.copyWith(turn: v),
        gate: PlanGate.rotate,
      ),
      NumberProperty<Slab>(
        id: 'grade',
        read: (s) => s.grade,
        write: (s, v) => s.copyWith(grade: v),
        min: 0.5,
        max: 9,
        decimals: 1,
        enabled: (s) => s.raised,
      ),
      ChoiceProperty<Slab, Finish>(
        id: 'finish',
        values: Finish.values,
        read: (s) => s.finish,
        write: (s, v) => s.copyWith(finish: v),
      ),
      ToggleProperty<Slab>(
        id: 'raised',
        read: (s) => s.raised,
        write: (s, v) => s.copyWith(raised: v),
      ),
      TextProperty<Slab>(
        id: 'label',
        read: (s) => s.label,
        write: (s, v) => s.copyWith(label: v),
        maxLength: 12,
      ),
      ValueDisplay<Slab>(
        id: 'area',
        read: (s) => s.width * s.depth,
        unit: ValueUnit.area,
      ),
      ActionProperty<Slab>(
        id: 'flip',
        apply: (s) => s.copyWith(flipped: !s.flipped),
      ),
    ];

/// The post's specs.
List<PropertySpec<Post>> postSpecs() => [
      LengthProperty<Post>(
        id: 'width',
        read: (p) => p.width,
        write: (p, v) => Post(width: v, shape: p.shape, swatch: p.swatch),
        min: 50,
        enabled: (p) => p.shape == 'round',
      ),
      ChoiceProperty<Post, String>(
        id: 'shape',
        values: const ['round', 'square'],
        read: (p) => p.shape,
        write: (p, v) => Post(width: p.width, shape: v, swatch: p.swatch),
      ),
    ];
