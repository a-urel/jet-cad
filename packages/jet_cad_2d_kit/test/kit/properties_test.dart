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
      // M-PS4c (final review): drop the separator check. A segment holding
      // "." or ":" makes the word id `property:<owner>.<spec>.<value>`
      // ambiguous.
      expect(() => choice(const ['oak', 'oak.dark']), refusedOn('values'));
      expect(() => choice(const ['oak', 'tr:meşe']), refusedOn('values'));
      expect(() => choice(const [0.5, 2]), refusedOn('values'));
      expect(
          choice(const ['oak', 'oak-dark', 2]).values, ['oak', 'oak-dark', 2]);
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
      'relabel',
    ]);
  });
}

String? _swatch(Slab s) => s.swatch;

Slab _recolour(Slab s, String? swatch) =>
    s.copyWith(swatch: swatch, clearSwatch: swatch == null);
