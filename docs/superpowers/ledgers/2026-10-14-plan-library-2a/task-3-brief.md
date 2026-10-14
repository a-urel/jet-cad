### Task 3: Contract — property specs, `PropertyField`, `PlanGate`, `ColourTarget` (spec P3)

**Files:**
- Create: `packages/jet_cad_2d_kit/lib/src/kit/properties.dart`, `lib/src/kit/colour.dart`
- Modify: `packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart` (two exports), `test/invariants/purity_test.dart` (P9), `CHANGELOG.md` (one bullet)
- Test: `packages/jet_cad_2d_kit/test/kit/properties_test.dart`, `test/support/code_fixtures.dart` (shared with Tasks 4 and 5's tests)

(All paths below are under `packages/jet_cad_2d_kit/` unless they start at the repository root.)

**Interfaces:**
- Consumes: `Component` (`package:jet_cad_2d/jet_cad_2d.dart`, `lib/src/document/component.dart:16-19`), in the test fixtures only; `walkImports` (`test/support/import_walker.dart`) and its allow-list (`:11-21`: `dart:async|collection|convert|core|math|typed_data`, `jet_cad_2d`, `meta`, `vector_math`).
- Produces (exported from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` only, never from `authoring.dart`):
  - `enum PlanGate { move, rotate, mirror, reshape, delete, changeLayer, recolor, editLayers, editPage }`.
  - `enum ValueUnit { length, area, angle, none }`.
  - `sealed class PropertySpec<T>`: `String get id`, `bool Function(T)? get enabled`, `PlanGate? get gate`, and `PropertyField bind(Object? value, {required String wordId, void Function(T next)? onCommit})`.
  - Its eight `final` kinds, each `({required String id, ..., bool Function(T)? enabled, PlanGate? gate})`:
    - `LengthProperty<T>({read: double Function(T), write: T Function(T, double), double? min, double? max})`;
    - `AngleProperty<T>({read, write})` (radians);
    - `NumberProperty<T>({read, write, double? min, double? max, int decimals = 0})`;
    - `ChoiceProperty<T, V>({required List<V> values, read: V Function(T), write: T Function(T, V)})` with `static String segmentOf(Object? value)`;
    - `ToggleProperty<T>({read: bool Function(T), write: T Function(T, bool)})`;
    - `TextProperty<T>({read: String Function(T), write: T Function(T, String), int? maxLength})`;
    - `ValueDisplay<T>({read: double Function(T), required ValueUnit unit})`;
    - `ActionProperty<T>({required T Function(T) apply})`.
  - `abstract interface class PropertyField { PropertySpec<Object?> get spec; String get wordId; bool get enabled; Object? get value; Object? Function(Object? input)? get commit; }` — exactly the Shared interface; its implementation `_BoundField<T>` is private.
  - `final class ColourTarget<T> { const ColourTarget({required String? Function(T) read, required T Function(T, String?) write}); }`.

Plan decision: **the binding entry point is `PropertySpec.bind`, an instance method each kind overrides.** The Shared interfaces name no way to make a `PropertyField`; Task 4's `PlanType.fieldsOf` and `PlanToolSettings.fieldsOf` need one. It must be virtual: inside a kind's own `bind`, `this` has its real `T`, so reading `read`, `write` and `enabled` passes the VM's covariance check. A top-level `bindProperty<T>(PropertySpec<T>, T)` called with a spec held as `PropertySpec<Component>` infers `T = Component` and throws a `TypeError` on the first `read` (checked under Dart 3.13.5 before writing this task). `bind` takes the owner as `Object?` and refuses a wrong one with `ArgumentError` (name `value`), never a `TypeError`.
Plan decision: **lengths are millimetres, angles radians, both ways.** `PropertyField.value` and `commit`'s input for an `AngleProperty` are radians; the panel (Task 17) shows and parses degrees and converts at its edge. No conversion happens in the contract.
Plan decision: **`commit` refuses with `ArgumentError`, named by the spec id,** for an input of the wrong type, not finite, outside `[min, max]` (inclusive; a null bound is open), not one of a choice's values (`==`, a stored-value comparison), or longer than `maxLength` code points. A **disabled** field (its `enabled` false for the bound owner) still reads, and its `commit` throws `StateError`: a disabled field is not an argument problem.
Plan decision: **a `NumberProperty` rounds to `decimals` on commit, then range-checks** (`double.parse(v.toStringAsFixed(decimals))`), so what is stored is what the panel shows. `decimals` is 0 to 10.
Plan decision: **`onCommit` sees the changed owner once, and only after the change succeeded.** Task 4's tool settings pass their `store` there; a type's fields pass none (`PlanType.commitField` builds the command).
Plan decision: a choice value's word segment is `ChoiceProperty.segmentOf(v)`: an enum's `name`, else `'$v'`. Two values with the same segment, an empty segment, or no value at all are refused when the spec is made (name `values`). The spec copies `values` unmodifiable.
Plan decision: **`properties.dart` and `colour.dart` import no Flutter** (P9 in the purity test): nothing in them draws, so a pure-Dart consumer could use them. They live under `lib/src/kit/` and are exported from the Flutter barrel only, as the scope says.

- [ ] **Step 1: The fixtures.** Create `test/support/code_fixtures.dart`:

```dart
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
```

- [ ] **Step 2: Write the failing tests.** Create `test/kit/properties_test.dart`:

```dart
// Spec 2a P3: the property specs, their constructor refusals and their
// erased binding, PropertyField. Every kind is bound to a slab whose values
// are away from their defaults; the covariance case holds specs of two
// owner types in one list, under the VM's runtime checks.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Component;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/code_fixtures.dart';

const Slab slab = Slab();

Matcher refusedOn(String name) =>
    throwsA(isA<ArgumentError>().having((e) => e.name, 'name', name));

/// [spec] (of [slabSpecs], by id) bound to [owner].
PropertyField field(String id,
    {Slab owner = slab, void Function(Slab)? onCommit}) {
  final spec = slabSpecs().firstWhere((s) => s.id == id);
  return spec.bind(owner, wordId: 'property:test.slab.$id', onCommit: onCommit);
}

void main() {
  group('constructor refusals', () {
    test('PS1 an id off the pattern is refused by every kind', () {
      final makers = <String, PropertySpec<Slab> Function(String id)>{
        'length': (id) => LengthProperty<Slab>(
            id: id, read: (s) => s.width, write: (s, _) => s),
        'angle': (id) => AngleProperty<Slab>(
            id: id, read: (s) => s.turn, write: (s, _) => s),
        'number': (id) => NumberProperty<Slab>(
            id: id, read: (s) => s.grade, write: (s, _) => s),
        'choice': (id) => ChoiceProperty<Slab, Finish>(
            id: id,
            values: Finish.values,
            read: (s) => s.finish,
            write: (s, _) => s),
        'toggle': (id) => ToggleProperty<Slab>(
            id: id, read: (s) => s.raised, write: (s, _) => s),
        'text': (id) => TextProperty<Slab>(
            id: id, read: (s) => s.label, write: (s, _) => s),
        'display': (id) => ValueDisplay<Slab>(
            id: id, read: (s) => s.depth, unit: ValueUnit.length),
        'action': (id) => ActionProperty<Slab>(id: id, apply: (s) => s),
      };
      for (final MapEntry(key: kind, value: make) in makers.entries) {
        for (final ok in ['width', 'a', 'seat-count', 'w2']) {
          expect(make(ok).id, ok, reason: '$kind $ok');
        }
        // M-PS1: drop the id check from the base constructor.
        for (final bad in [
          '',
          'Width',
          '2width',
          '-width',
          'wid th',
          'width.x',
          'width_x',
          'width\n',
        ]) {
          expect(() => make(bad), refusedOn('id'), reason: '$kind "$bad"');
        }
      }
    });

    test('PS2 bounds: min above max, a bound not finite', () {
      LengthProperty<Slab> length(double? min, double? max) =>
          LengthProperty<Slab>(
              id: 'width',
              read: (s) => s.width,
              write: (s, _) => s,
              min: min,
              max: max);
      NumberProperty<Slab> number(double? min, double? max) =>
          NumberProperty<Slab>(
              id: 'grade',
              read: (s) => s.grade,
              write: (s, _) => s,
              min: min,
              max: max);
      // M-PS2a: drop the min > max check.
      expect(() => length(500.5, 300.25), refusedOn('min'));
      expect(() => number(9.5, 0.5), refusedOn('min'));
      // M-PS2b: drop the finiteness checks.
      expect(() => length(double.negativeInfinity, 300), refusedOn('min'));
      expect(() => number(0.5, double.nan), refusedOn('max'));
      expect(length(300.25, 300.25).max, 300.25);
      expect(length(null, null).min, isNull);
    });

    test('PS3 decimals 0 to 10', () {
      NumberProperty<Slab> number(int decimals) => NumberProperty<Slab>(
          id: 'grade',
          read: (s) => s.grade,
          write: (s, _) => s,
          decimals: decimals);
      // M-PS3: drop the decimals check.
      expect(() => number(-1), refusedOn('decimals'));
      expect(() => number(11), refusedOn('decimals'));
      expect(number(0).decimals, 0);
      expect(number(10).decimals, 10);
    });

    test('PS4 a choice of no value, or of a word segment twice', () {
      ChoiceProperty<Slab, Object?> choice(List<Object?> values) =>
          ChoiceProperty<Slab, Object?>(
              id: 'finish',
              values: values,
              read: (s) => s.finish,
              write: (s, _) => s);
      // M-PS4a: drop the empty check.
      expect(() => choice(const []), refusedOn('values'));
      // M-PS4b: drop the repeated-segment check. 'oiled' the string and
      // Finish.oiled share a segment.
      expect(() => choice(const ['oiled', Finish.oiled]), refusedOn('values'));
      expect(() => choice(const ['a', '']), refusedOn('values'));
      final values = <Object?>[Finish.raw, 'square'];
      final c = choice(values);
      values.add('round');
      expect(c.values, [Finish.raw, 'square']);
      expect(() => c.values.add('x'), throwsUnsupportedError);
      expect(ChoiceProperty.segmentOf(Finish.waxed), 'waxed');
      expect(ChoiceProperty.segmentOf(3), '3');
    });

    test('PS5 a text of maxLength below 1', () {
      // M-PS5: drop the check.
      expect(
          () => TextProperty<Slab>(
              id: 'label',
              read: (s) => s.label,
              write: (s, _) => s,
              maxLength: 0),
          refusedOn('maxLength'));
    });
  });

  group('the bound field', () {
    test('PS6 a length: value, word, commit inside the bounds, inclusive', () {
      final f = field('width');
      expect(f.value, 1250.5);
      expect(f.wordId, 'property:test.slab.width');
      expect(f.enabled, isTrue);
      expect(f.spec.id, 'width');
      expect(f.spec, isA<LengthProperty<Slab>>());
      expect(f.commit!(2400.75), slab.copyWith(width: 2400.75));
      // The bounds themselves are allowed.
      expect(f.commit!(300), slab.copyWith(width: 300));
      expect(f.commit!(4800), slab.copyWith(width: 4800));
      // M-PS6a: drop the range check. M-PS6b: `v <= min` (exclusive).
      expect(() => f.commit!(299.5), refusedOn('width'));
      expect(() => f.commit!(4800.5), refusedOn('width'));
      // M-PS6c: drop the finiteness check (a NaN passes both comparisons).
      expect(() => f.commit!(double.nan), refusedOn('width'));
      expect(() => f.commit!('2400'), refusedOn('width'));
      expect(() => f.commit!(null), refusedOn('width'));
    });

    test('PS7 an angle is radians in and out', () {
      final f = field('turn');
      expect(f.value, 0.35);
      expect(f.spec.gate, PlanGate.rotate);
      // M-PS7: convert the input from degrees (v * pi / 180).
      expect(f.commit!(1.25), slab.copyWith(turn: 1.25));
      expect(f.commit!(-0.5), slab.copyWith(turn: -0.5));
      expect(() => f.commit!(double.infinity), refusedOn('turn'));
    });

    test('PS8 a number is rounded to its decimals, then range-checked', () {
      final f = field('grade');
      expect(f.value, 2.5);
      // M-PS8a: drop the rounding.
      expect(f.commit!(3.14159), slab.copyWith(grade: 3.1));
      expect(f.commit!(7), slab.copyWith(grade: 7.0));
      // 9.04 rounds to 9.0, inside; 0.44 rounds to 0.4, outside.
      // M-PS8b: range-check before rounding (9.04 is refused).
      expect(f.commit!(9.04), slab.copyWith(grade: 9.0));
      expect(() => f.commit!(0.44), refusedOn('grade'));
    });

    test('PS9 a choice takes one of its values, by ==', () {
      final f = field('finish');
      expect(f.value, Finish.waxed);
      expect(f.commit!(Finish.raw), slab.copyWith(finish: Finish.raw));
      // M-PS9: drop the membership check (a String reaches `write`).
      expect(() => f.commit!('raw'), refusedOn('finish'));
      expect(() => f.commit!(null), refusedOn('finish'));
      final shape = postSpecs()[1].bind(const Post(), wordId: 'w');
      expect(shape.commit!('square'), const Post(shape: 'square'));
      expect(() => shape.commit!('oval'), refusedOn('shape'));
    });

    test('PS10 a toggle takes a bool', () {
      final f = field('raised');
      expect(f.value, isTrue);
      expect(f.commit!(false), slab.copyWith(raised: false));
      // M-PS10: drop the type check (a TypeError from the cast instead).
      expect(() => f.commit!(1), refusedOn('raised'));
    });

    test('PS11 a text takes a String of at most maxLength code points', () {
      final f = field('label');
      expect(f.value, 'Bar top');
      expect(f.commit!('Köşe tezgâh'), slab.copyWith(label: 'Köşe tezgâh'));
      expect(f.commit!('123456789012'), slab.copyWith(label: '123456789012'));
      // M-PS11: drop the length check.
      expect(() => f.commit!('1234567890123'), refusedOn('label'));
      expect(() => f.commit!(12), refusedOn('label'));
    });

    test('PS12 a display shows its value and has no commit', () {
      final f = field('area');
      expect(f.value, 1250.5 * 640.25);
      expect((f.spec as ValueDisplay<Object?>).unit, ValueUnit.area);
      // M-PS12: give a display a commit.
      expect(f.commit, isNull);
    });

    test('PS13 an action has no value; its commit applies', () {
      final f = field('flip');
      expect(f.value, isNull);
      // M-PS13: return the owner unchanged.
      expect(f.commit!(null), slab.copyWith(flipped: true));
      expect(f.commit!('ignored'), slab.copyWith(flipped: true));
    });

    test('PS14 a disabled field reads but refuses to commit', () {
      final lowered = slab.copyWith(raised: false);
      final f = field('grade', owner: lowered);
      expect(f.enabled, isFalse);
      expect(f.value, 2.5);
      // M-PS14: drop the enabled check from commit.
      expect(() => f.commit!(3), throwsStateError);
      expect(field('grade').enabled, isTrue);
    });

    test('PS15 onCommit sees the changed owner once, and only on success', () {
      final seen = <Slab>[];
      final f = field('width', onCommit: seen.add);
      expect(() => f.commit!(10), refusedOn('width'));
      // M-PS15a: call onCommit before the change is checked.
      expect(seen, isEmpty);
      f.commit!(2400.75);
      // M-PS15b: drop the onCommit call.
      expect(seen, [slab.copyWith(width: 2400.75)]);
      final disabled = field('grade',
          owner: slab.copyWith(raised: false), onCommit: seen.add);
      expect(() => disabled.commit!(3), throwsStateError);
      expect(seen, hasLength(1));
    });

    test('PS16 binding a value of another type is an ArgumentError', () {
      final spec = slabSpecs().first;
      // M-PS16: `value as T` in place of the type test (a TypeError).
      expect(() => spec.bind(const Post(), wordId: 'w'), refusedOn('value'));
      expect(() => spec.bind(null, wordId: 'w'), refusedOn('value'));
    });
  });

  test('PS17 two owner types in one list, used only through PropertyField', () {
    // Review Focus 3. The list's static type erases each spec's owner.
    final List<PropertySpec<Component>> specs = [
      ...slabSpecs(),
      ...postSpecs(),
    ];
    const post = Post(shape: 'square', swatch: 'ochre');
    Component ownerOf(PropertySpec<Component> s) =>
        s is PropertySpec<Slab> ? slab : post;
    // Premise: the trap is real. Reading `enabled` through the erased list
    // fails the VM's covariance check.
    expect(() => specs[2].enabled, throwsA(isA<TypeError>()));
    // M-PS17: in LengthProperty.bind, read through an erased view
    // (`final LengthProperty<Object?> self = this;` and `self.read(owner)`).
    final fields = [
      for (final s in specs) s.bind(ownerOf(s), wordId: 'property:x.${s.id}'),
    ];
    expect([
      for (final f in fields) f.value
    ], [
      1250.5,
      0.35,
      2.5,
      Finish.waxed,
      true,
      'Bar top',
      1250.5 * 640.25,
      null,
      180.75,
      'square',
    ]);
    expect([for (final f in fields) f.enabled],
        [true, true, true, true, true, true, true, true, false, true]);
    expect(fields[0].commit!(600), slab.copyWith(width: 600));
    expect(fields[9].commit!('round'),
        const Post(shape: 'round', swatch: 'ochre'));
    expect(() => fields[8].commit!(200), throwsStateError);
  });

  test('PS18 a colour target holds its two hooks; PlanGate lists the flags',
      () {
    // A premise of the declarations, exempt from the mutation rule.
    const target = ColourTarget<Slab>(read: _swatch, write: _recolour);
    expect(target.read(slab), 'teal');
    expect(target.write(slab, 'ochre').swatch, 'ochre');
    expect(target.write(slab, null).swatch, isNull);
    expect(PlanGate.values.map((g) => g.name), [
      'move',
      'rotate',
      'mirror',
      'reshape',
      'delete',
      'changeLayer',
      'recolor',
      'editLayers',
      'editPage',
    ]);
  });
}

String? _swatch(Slab s) => s.swatch;

Slab _recolour(Slab s, String? swatch) =>
    s.copyWith(swatch: swatch, clearSwatch: swatch == null);
```

In `test/invariants/purity_test.dart`, add P9 after P1:

```diff
--- a/packages/jet_cad_2d_kit/test/invariants/purity_test.dart
+++ b/packages/jet_cad_2d_kit/test/invariants/purity_test.dart
@@ -33,6 +33,15 @@ void main() {
     }
   });
 
+  test('P9 the property specs and the colour target reach no Flutter', () {
+    // Spec 2a P3: nothing in them draws, so they stay pure. M-P9: import
+    // package:flutter/foundation.dart in colour.dart.
+    const files = ['lib/src/kit/properties.dart', 'lib/src/kit/colour.dart'];
+    final walk = walkImports('.', 'jet_cad_2d_kit', files);
+    expect(walk.violations, isEmpty);
+    expect(walk.visited, containsAll(files));
+  });
+
   test('P2 a Flutter import two hops away is found', () {
     final root = tree({
       'lib/authoring.dart': "export 'src/model/a.dart';\n",
```

- [ ] **Step 3: Run them to see them fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/kit/properties_test.dart test/invariants/purity_test.dart`. Expected: `properties_test.dart` fails to compile (the error names an undefined `LengthProperty`, `PropertySpec` or `PlanGate`); P9 fails because the two files do not exist yet. Quote the first error line of each.

- [ ] **Step 4: The specs.** Create `lib/src/kit/properties.dart`:

```dart
// Property specs (spec 2a P3, umbrella A4): the fields a kit's type or a
// tool's settings show in the plan library's property panel, as data. Each
// spec reads one value of its owner `T` and writes a changed copy.
//
// Free of Flutter: nothing here draws. The panel (the plan library) turns a
// spec into a widget through the erased PropertyField.

/// A PlanPermissions flag a field needs (spec 2a P2, P3). A field whose gate
/// is off is shown read-only.
enum PlanGate {
  move,
  rotate,
  mirror,
  reshape,
  delete,
  changeLayer,
  recolor,
  editLayers,
  editPage,
}

/// How a [ValueDisplay] prints its number: a length in mm, an area in mm²,
/// an angle in radians, or a plain number.
enum ValueUnit { length, area, angle, none }

final RegExp _specId = RegExp(r'^[a-z][a-z0-9-]*$');

/// One field of an owner `T`: a type's component or a tool's settings.
///
/// Its word is `property:<owner id>.<id>` (a choice's values:
/// `property:<owner id>.<id>.<value>`).
///
/// **Covariance.** The plan library holds specs of many `T`s at once. A
/// member whose type takes a `T` ([enabled], a kind's `read` and `write`)
/// throws a `TypeError` when it is read through a supertype such as
/// `PropertySpec<Object?>`. Only [id], [gate], a kind's bounds and [bind]
/// are safe there; [bind] is how the plan library uses a spec.
sealed class PropertySpec<T> {
  PropertySpec._(this.id, this.enabled, this.gate) {
    if (!_specId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id',
          'must be a lower-case letter, then lower-case letters, digits and hyphens');
    }
  }

  /// Unique within its owner's specs.
  final String id;

  /// False greys the field out and its commit throws [StateError]. Null:
  /// always enabled.
  final bool Function(T)? enabled;

  /// The permission the field needs, or null for none.
  final PlanGate? gate;

  /// This spec bound to [value], an owner `T`, under [wordId]: the erased
  /// form the plan library uses (spec 2a P1, erased operations). A kit never
  /// calls it.
  ///
  /// The field's `commit` returns the changed owner and, when it is not
  /// null, passes it to [onCommit] first. Throws [ArgumentError] when
  /// [value] is not a `T`.
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit});
}

/// A length in millimetres, within [min] and [max] (inclusive; null:
/// unbounded).
final class LengthProperty<T> extends PropertySpec<T> {
  LengthProperty({
    required String id,
    required this.read,
    required this.write,
    this.min,
    this.max,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate) {
    _checkBounds(min, max);
  }

  final double Function(T) read;
  final T Function(T, double) write;
  final double? min;
  final double? max;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(
        this,
        owner,
        wordId,
        read(owner),
        (input) => write(owner, _inRange(_finite(input, id), min, max, id)),
        onCommit);
  }
}

/// An angle, stored in radians. The field's value and its commit's input
/// are radians; the panel shows and parses degrees (spec 2a Task 17).
final class AngleProperty<T> extends PropertySpec<T> {
  AngleProperty({
    required String id,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final double Function(T) read;
  final T Function(T, double) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner),
        (input) => write(owner, _finite(input, id)), onCommit);
  }
}

/// A plain number within [min] and [max], rounded on commit to [decimals]
/// places (0 to 10), so what is stored is what the panel shows.
final class NumberProperty<T> extends PropertySpec<T> {
  NumberProperty({
    required String id,
    required this.read,
    required this.write,
    this.min,
    this.max,
    this.decimals = 0,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate) {
    _checkBounds(min, max);
    if (decimals < 0 || decimals > 10) {
      throw ArgumentError.value(decimals, 'decimals', 'must be 0 to 10');
    }
  }

  final double Function(T) read;
  final T Function(T, double) write;
  final double? min;
  final double? max;
  final int decimals;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      final rounded =
          double.parse(_finite(input, id).toStringAsFixed(decimals));
      return write(owner, _inRange(rounded, min, max, id));
    }, onCommit);
  }
}

/// One of [values], compared with `==`. A value's word segment is
/// [segmentOf] it: an enum's name, else its `toString`.
final class ChoiceProperty<T, V> extends PropertySpec<T> {
  ChoiceProperty({
    required String id,
    required List<V> values,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    PlanGate? gate,
  })  : values = List.unmodifiable(values),
        super._(id, enabled, gate) {
    if (this.values.isEmpty) {
      throw ArgumentError.value(values, 'values', 'must not be empty');
    }
    final seen = <String>{};
    for (final v in this.values) {
      final segment = segmentOf(v);
      if (segment.isEmpty || !seen.add(segment)) {
        throw ArgumentError.value(
            v, 'values', 'gives the word segment "$segment" twice or empty');
      }
    }
  }

  /// The word segment of [value]: an enum's name, else `'$value'`.
  static String segmentOf(Object? value) =>
      value is Enum ? value.name : '$value';

  final List<V> values;
  final V Function(T) read;
  final T Function(T, V) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! V || !values.contains(input)) {
        throw ArgumentError.value(input, id, 'is not one of $values');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A yes or no.
final class ToggleProperty<T> extends PropertySpec<T> {
  ToggleProperty({
    required String id,
    required this.read,
    required this.write,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final bool Function(T) read;
  final T Function(T, bool) write;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! bool) {
        throw ArgumentError.value(input, id, 'is not a bool');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A text of at most [maxLength] code points (null: any length).
final class TextProperty<T> extends PropertySpec<T> {
  TextProperty({
    required String id,
    required this.read,
    required this.write,
    this.maxLength,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate) {
    final m = maxLength;
    if (m != null && m < 1) {
      throw ArgumentError.value(m, 'maxLength', 'must be at least 1');
    }
  }

  final String Function(T) read;
  final T Function(T, String) write;
  final int? maxLength;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), (input) {
      if (input is! String) {
        throw ArgumentError.value(input, id, 'is not a String');
      }
      final m = maxLength;
      if (m != null && input.runes.length > m) {
        throw ArgumentError.value(input, id, 'is longer than $m');
      }
      return write(owner, input);
    }, onCommit);
  }
}

/// A read-only number: a room's area, a dimension's value. Its field's
/// commit is null.
final class ValueDisplay<T> extends PropertySpec<T> {
  ValueDisplay({
    required String id,
    required this.read,
    required this.unit,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final double Function(T) read;
  final ValueUnit unit;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(this, owner, wordId, read(owner), null, onCommit);
  }
}

/// A button: a door's Flip hinge. Its field's value is null and its commit
/// ignores its input and returns [apply] of the owner.
final class ActionProperty<T> extends PropertySpec<T> {
  ActionProperty({
    required String id,
    required this.apply,
    bool Function(T)? enabled,
    PlanGate? gate,
  }) : super._(id, enabled, gate);

  final T Function(T) apply;

  @override
  PropertyField bind(Object? value,
      {required String wordId, void Function(T next)? onCommit}) {
    final owner = _owner<T>(value);
    return _BoundField<T>(
        this, owner, wordId, null, (_) => apply(owner), onCommit);
  }
}

/// A spec bound to one owner value: one object's component or one tool's
/// settings (spec 2a P3). Erased: the plan library holds fields of many
/// owner types in one list and never sees a `T`.
abstract interface class PropertyField {
  /// For [PropertySpec.id], [PropertySpec.gate], the kind (a type test) and
  /// a kind's bounds or values only: see [PropertySpec]'s covariance note.
  PropertySpec<Object?> get spec;

  /// `property:<owner id>.<spec id>`.
  String get wordId;

  /// The spec's `enabled` of the bound owner; true when it has none.
  bool get enabled;

  /// The bound owner's value: a `double` for a length (mm), an angle
  /// (radians), a number and a display; the value for a choice; a `bool`;
  /// a `String`; null for an action.
  Object? get value;

  /// Null for a [ValueDisplay]. Otherwise: the owner changed by [input]
  /// (an action ignores it). Throws [ArgumentError] for an input of the
  /// wrong type, not finite, out of range, not among a choice's values or
  /// too long, and [StateError] while the field is not [enabled].
  Object? Function(Object? input)? get commit;
}

final class _BoundField<T> implements PropertyField {
  factory _BoundField(
      PropertySpec<T> spec,
      T owner,
      String wordId,
      Object? value,
      T Function(Object? input)? change,
      void Function(T next)? onCommit) {
    final enabled = spec.enabled?.call(owner) ?? true;
    return _BoundField._(
        spec,
        wordId,
        value,
        enabled,
        change == null
            ? null
            : (input) {
                if (!enabled) throw StateError('$wordId is not enabled');
                final next = change(input);
                onCommit?.call(next);
                return next;
              });
  }

  _BoundField._(this.spec, this.wordId, this.value, this.enabled, this.commit);

  @override
  final PropertySpec<T> spec;

  @override
  final String wordId;

  @override
  final Object? value;

  @override
  final bool enabled;

  @override
  final Object? Function(Object? input)? commit;
}

T _owner<T>(Object? value) {
  if (value is T) return value;
  throw ArgumentError.value(value, 'value', 'is not a $T');
}

double _finite(Object? input, String id) {
  if (input is num && input.isFinite) return input.toDouble();
  throw ArgumentError.value(input, id, 'is not a finite number');
}

double _inRange(double v, double? min, double? max, String id) {
  if ((min != null && v < min) || (max != null && v > max)) {
    throw ArgumentError.value(
        v, id, 'is outside [${min ?? '-∞'}, ${max ?? '∞'}]');
  }
  return v;
}

void _checkBounds(double? min, double? max) {
  if (min != null && !min.isFinite) {
    throw ArgumentError.value(min, 'min', 'is not finite');
  }
  if (max != null && !max.isFinite) {
    throw ArgumentError.value(max, 'max', 'is not finite');
  }
  if (min != null && max != null && min > max) {
    throw ArgumentError.value(min, 'min', 'is above max ($max)');
  }
}
```

- [ ] **Step 5: The colour target and the exports.** Create `lib/src/kit/colour.dart`:

```dart
// Colour targets (spec 2a P3, umbrella A3): how a type's component carries
// its colour, so the panel's colour row recolours a multiple selection of
// any kits' objects in one command.
//
// Free of Flutter: a swatch is a name from the plan's palette, not a Color.
import 'package:meta/meta.dart';

/// A type's colour: [read] gives its swatch (null: no colour of its own),
/// [write] a copy carrying another (null clears it). The plan library uses
/// it only through `PlanType.colourOf` and `PlanType.recolour`.
@immutable
final class ColourTarget<T> {
  const ColourTarget({required this.read, required this.write});

  final String? Function(T) read;
  final T Function(T, String?) write;
}
```

In `lib/jet_cad_2d_kit.dart`, the export list becomes:

```dart
export 'src/kit/bundled_library.dart';
export 'src/kit/colour.dart';
export 'src/kit/plan_kit.dart';
export 'src/kit/properties.dart';
export 'src/kit/symbol_library_source.dart';
export 'src/model/model.dart';
```

`lib/authoring.dart` does not change.

- [ ] **Step 6: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/kit/properties_test.dart test/invariants`. Expected: `All tests passed!`.

- [ ] **Step 7: The CHANGELOG.** Append to the `## 0.1.0` list of `CHANGELOG.md` (the package is unpublished; it stays 0.1.0):

```markdown
- Property specs (`LengthProperty`, `AngleProperty`, `NumberProperty`,
  `ChoiceProperty`, `ToggleProperty`, `TextProperty`, `ValueDisplay`,
  `ActionProperty`), their erased binding `PropertyField`, `PlanGate`,
  `ValueUnit` and `ColourTarget`.
```

- [ ] **Step 8: The gate.** Run, one at a time: `cd packages/jet_cad_2d_kit && dart format .`, then `flutter test`, `flutter analyze`, `dart format --output=none --set-exit-if-changed .`. All exit 0; `flutter test` ends `All tests passed!` (quote its count line). Then `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/kit/properties.dart packages/jet_cad_2d_kit/lib/src/kit/colour.dart packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/test/support/code_fixtures.dart packages/jet_cad_2d_kit/test/kit/properties_test.dart packages/jet_cad_2d_kit/test/invariants/purity_test.dart packages/jet_cad_2d_kit/CHANGELOG.md
git commit -m "$(cat <<'EOF'
feat(kit): property specs, PropertyField, PlanGate and ColourTarget (2a P3)

Eight sealed spec kinds read one value of their owner and write a changed
copy. Each binds itself to an owner as an erased PropertyField, so the
plan library can hold fields of many owner types in one list without a
covariance error; commit refuses out-of-range input with ArgumentError and
a disabled field with StateError. Lengths are mm and angles radians. The
specs and the colour target import no Flutter.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check.** On the committed files only. For each mutation: apply the edit, run the named test from `packages/jet_cad_2d_kit`, see it red and quote its failing line, then `git checkout -- <file>` and `git diff --quiet -- <file>` (exit 0). Every one below was seen red against this code before the task was written. PS18 is a premise of the declarations and PS17's first expectation a premise of the VM; both are exempt.

- **M-PS1** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (!_specId.hasMatch(id)) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS1 an id'`: red.

- **M-PS2a** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (min != null && max != null && min > max) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS2'`: red.

- **M-PS2b** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (min != null && !min.isFinite) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS2'`: red.

- **M-PS3** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (decimals < 0 || decimals > 10) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS3'`: red.

- **M-PS4a** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (this.values.isEmpty) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS4'`: red.

- **M-PS4b** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (segment.isEmpty || !seen.add(segment)) {
  ```

  with

  ```dart
  if (segment.isEmpty) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS4'`: red.

- **M-PS5** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (m != null && m < 1) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS5'`: red.

- **M-PS6a** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if ((min != null && v < min) || (max != null && v > max)) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS6'`: red.

- **M-PS6b** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if ((min != null && v < min) ||
  ```

  with

  ```dart
  if ((min != null && v <= min) ||
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS6'`: red.

- **M-PS6c** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (input is num && input.isFinite) return input.toDouble();
  ```

  with

  ```dart
  if (input is num) return input.toDouble();
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS6'`: red.

- **M-PS7** (`lib/src/kit/properties.dart`). Replace

  ```dart
  (input) => write(owner, _finite(input, id)), onCommit);
  ```

  with

  ```dart
  (input) => write(owner, _finite(input, id) * 3.141592653589793 / 180), onCommit);
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS7'`: red.

- **M-PS8a** (`lib/src/kit/properties.dart`). Replace

  ```dart
  double.parse(_finite(input, id).toStringAsFixed(decimals));
  ```

  with

  ```dart
  _finite(input, id);
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS8'`: red.

- **M-PS8b** (`lib/src/kit/properties.dart`). Replace

  ```dart
        final rounded =
            double.parse(_finite(input, id).toStringAsFixed(decimals));
        return write(owner, _inRange(rounded, min, max, id));
  ```

  with

  ```dart
        final rounded = double.parse(
            _inRange(_finite(input, id), min, max, id).toStringAsFixed(decimals));
        return write(owner, rounded);
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS8'`: red.

- **M-PS9** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (input is! V || !values.contains(input)) {
          throw ArgumentError.value(input, id, 'is not one of $values');
        }
        return write(owner, input);
  ```

  with

  ```dart
  return write(owner, input as V);
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS9'`: red.

- **M-PS10** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (input is! bool) {
          throw ArgumentError.value(input, id, 'is not a bool');
        }
        return write(owner, input);
  ```

  with

  ```dart
  return write(owner, input as bool);
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS10'`: red.

- **M-PS11** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (m != null && input.runes.length > m) {
  ```

  with

  ```dart
  if (false) {
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS11'`: red.

- **M-PS12** (`lib/src/kit/properties.dart`). Replace

  ```dart
  read(owner), null, onCommit);
  ```

  with

  ```dart
  read(owner), (_) => owner, onCommit);
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS12'`: red.

- **M-PS13** (`lib/src/kit/properties.dart`). Replace

  ```dart
  (_) => apply(owner)
  ```

  with

  ```dart
  (_) => owner
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS13'`: red.

- **M-PS14** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (!enabled) throw StateError('$wordId is not enabled');
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS14'`: red.

- **M-PS15a** (`lib/src/kit/properties.dart`). Replace

  ```dart
                  final next = change(input);
                  onCommit?.call(next);
  ```

  with

  ```dart
                  onCommit?.call(owner);
                  final next = change(input);
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS15'`: red.

- **M-PS15b** (`lib/src/kit/properties.dart`). Replace

  ```dart
  onCommit?.call(next);
  ```

  with

  ```dart
  // (nothing: the text is deleted)
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS15'`: red.

- **M-PS16** (`lib/src/kit/properties.dart`). Replace

  ```dart
  if (value is T) return value;
    throw ArgumentError.value(value, 'value', 'is not a $T');
  ```

  with

  ```dart
  return value as T;
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS16'`: red.

- **M-PS17** (`lib/src/kit/properties.dart`). Replace

  ```dart
          wordId,
          read(owner),
          (input) => write(owner, _inRange(
  ```

  with

  ```dart
          wordId,
          (this as LengthProperty<Object?>).read(owner),
          (input) => write(owner, _inRange(
  ```

  Run `flutter test test/kit/properties_test.dart --plain-name 'PS17'`: red.

- **M-P9** (`lib/src/kit/colour.dart`). Replace

  ```dart
  import 'package:meta/meta.dart';
  ```

  with

  ```dart
  import 'package:meta/meta.dart';
  import 'package:flutter/foundation.dart';
  ```

  Run `flutter test test/invariants/purity_test.dart --plain-name 'P9'`: red.

---

