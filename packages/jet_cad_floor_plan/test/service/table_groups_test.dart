// Table-groups spec G1, G2, G3 (the lead order), G4 (the lookup) and G5
// (the Merge and Split rules), with no plan: `TableGroup`, the validation,
// and the lookup over table facts. Ids and numbers are deliberately not
// sorted (`G7` holds 12, 3 and 7), handles are given out of order, and the
// facts carry a file duplicate, a locked member and a hidden one.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/service/table_groups.dart';

TableGroup g(Set<String> members, [String? label]) =>
    TableGroup(members: members, label: label);

GroupTable t(int handle, String? number,
        {bool visible = true, bool locked = false}) =>
    GroupTable(
        handle: Handle(handle),
        number: number,
        visible: visible,
        locked: locked);

/// Handles out of order: 0x51 carries 12, 0x2A carries 3, 0x77 carries 7,
/// 0x13 carries 20, 0x64 and 0x1F both carry 5 (a file duplicate), 0x88
/// carries 8 on a locked layer, 0x90 carries 9 on a hidden layer, 0x99
/// carries 10 on a layer both hidden and locked, 0x40 has no number.
final List<GroupTable> facts = [
  t(0x77, '7'),
  t(0x51, '12'),
  t(0x88, '8', locked: true),
  t(0x2A, '3'),
  t(0x13, '20'),
  t(0x64, '5'),
  t(0x90, '9', visible: false),
  t(0x1F, '5'),
  t(0x99, '10', visible: false, locked: true),
  t(0x40, null),
];

List<int> handles(Iterable<GroupTable> list) =>
    [for (final x in list) x.handle.value];

Matcher argumentError(List<String> parts) => throwsA(isA<ArgumentError>()
    .having((e) => e.toString(), 'message', stringContainsInOrder(parts)));

void main() {
  group('TableGroup (G1, G2)', () {
    test(
        'TG-U1 members are trimmed, a blank one dropped, and the set is '
        'unmodifiable (M-TG-2, M-C1-14)', () {
      final group = g({' 12 ', '3', '  ', '', '7\t'});
      expect(group.members, {'12', '3', '7'});
      expect(() => group.members.add('9'), throwsUnsupportedError);
    });

    test(
        'TG-U2 the label is trimmed, a blank one is none, and it is cut to '
        '24 characters, counted as grapheme clusters (M-C1-1, M-C1-2)', () {
      expect(g({'1'}, '  Window bay  ').label, 'Window bay');
      expect(g({'1'}, '   ').label, isNull);
      expect(g({'1'}, '').label, isNull);
      expect(g({'1'}).label, isNull);
      expect(TableGroup.maxLabel, 24);
      final long = '${'a' * 20}bcdefgh';
      expect(g({'1'}, '  $long ').label, '${'a' * 20}bcde');
      // Each family emoji is one character of several code units.
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
      final label = g({'1'}, family * 30).label!;
      expect(label, family * 24);
    });

    test(
        'TG-U3 equality is by value: the members as a set, the label '
        '(M-C1-3)', () {
      expect(g({'12', '3', '7'}, 'Bay'), g({'7', ' 3', '12'}, 'Bay '));
      expect(g({'12', '3', '7'}).hashCode, g({'7', '3', '12'}).hashCode);
      expect(g({'12', '3', '7'}), isNot(g({'12', '3'})));
      expect(g({'12', '3', '7'}), isNot(g({'12', '3', '7'}, 'Bay')));
    });
  });

  group('validateTableGroups (G2)', () {
    test(
        'TG-U4 ids are trimmed, in the given order, and the map is '
        'unmodifiable (M-TG-2, M-C1-13)', () {
      final out = validateTableGroups({
        ' G7 ': g({'12', '3', '7'}),
        'G2': g({'20'}),
      });
      expect(out.keys, ['G7', 'G2']);
      expect(out['G7'], g({'12', '3', '7'}));
      expect(() => out['G9'] = g({'1'}), throwsUnsupportedError);
    });

    test(
        'TG-U5 a number in two groups throws, naming it and both ids, '
        'trimmed numbers included (M-TG-1)', () {
      expect(
          () => validateTableGroups({
                'G7': g({'12', '5'}),
                'G2': g({'20', ' 5 '}),
              }),
          argumentError(['"5"', '"G7"', '"G2"']));
    });

    test(
        'TG-U6 a blank id, two ids the same after trimming, and a group '
        'with no member after trimming throw (G2)', () {
      expect(
          () => validateTableGroups({
                '': g({'1'})
              }),
          argumentError(['blank']));
      expect(
          () => validateTableGroups({
                '   ': g({'1'})
              }),
          argumentError(['blank']));
      expect(
          () => validateTableGroups({
                'G1': g({'1'}),
                ' G1 ': g({'2'}),
              }),
          argumentError(['"G1"']));
      expect(
          () => validateTableGroups({
                'G1': g({' ', ''})
              }),
          argumentError(['"G1"', 'no member']));
      expect(validateTableGroups(const {}), isEmpty);
    });
  });

  group('TableGroupLookup (G2, G4)', () {
    final lookup = TableGroupLookup(
        validateTableGroups({
          'G7': g({'12', '3', '7'}),
          'G5': g({'5', '8', '10', '99'}),
          'G9': g({'9'}),
        }),
        facts);

    test(
        'TG-U7 a number resolves to its group, trimmed; an unknown member '
        'number is kept (G2, M-C1-12)', () {
      expect(lookup.groupOf('12'), 'G7');
      expect(lookup.groupOf(' 3 '), 'G7');
      expect(lookup.groupOf('99'), 'G5');
      expect(lookup.groupOf('20'), isNull);
      expect(lookup.groupOf('missing'), isNull);
    });

    test(
        'TG-U8 visible members ascending by handle: a duplicate gives both, '
        'a locked one counts, a hidden one does not (M-C1-4, M-C1-5)', () {
      expect(handles(lookup.visibleMembers('G7')), [0x2A, 0x51, 0x77]);
      expect(handles(lookup.visibleMembers('G5')), [0x1F, 0x64, 0x88]);
      expect(lookup.visibleMembers('G9'), isEmpty);
      expect(lookup.visibleMembers('nope'), isEmpty);
    });

    test(
        'TG-U9 selectable members drop the locked one; a locked member '
        'counts as locked only on a visible layer (M-C1-6, M-C1-7)', () {
      expect(handles(lookup.selectableMembers('G7')), [0x2A, 0x51, 0x77]);
      expect(handles(lookup.selectableMembers('G5')), [0x1F, 0x64]);
      expect(lookup.hasLockedVisibleMember('G5'), isTrue);
      expect(lookup.hasLockedVisibleMember('G7'), isFalse);
      // 10 is locked but hidden: it does not count.
      final hiddenLocked = TableGroupLookup(
          validateTableGroups({
            'G1': g({'3', '10'})
          }),
          facts);
      expect(hiddenLocked.hasLockedVisibleMember('G1'), isFalse);
      expect(handles(hiddenLocked.selectableMembers('G1')), [0x2A]);
    });
  });

  group('the Merge rule (G5)', () {
    final groups = validateTableGroups({
      'G7': g({'12', '3', '7'}),
      'G2': g({'20', '8'}),
    });

    test(
        'TG-U10 disabled for one table, two unnumbered tables, two tables '
        'sharing one number, one whole group and part of one (M-TG-16)', () {
      expect(mergeQualifies({'5'}, groups), isFalse,
          reason: 'one table, or both tables carrying 5');
      expect(mergeQualifies(const {}, groups), isFalse,
          reason: 'unnumbered tables report no number');
      expect(mergeQualifies({'12', '3', '7'}, groups), isFalse,
          reason: 'exactly one group');
      expect(mergeQualifies({'3', '7'}, groups), isFalse);
      expect(mergeQualifies({'5', ' ', ''}, groups), isFalse);
    });

    test(
        'TG-U11 enabled for two numbered tables, a group and a table, two '
        'groups (M-TG-16)', () {
      expect(mergeQualifies({'5', '30'}, groups), isTrue);
      expect(mergeQualifies({'5', '30'}, const {}), isTrue);
      expect(mergeQualifies({'12', '3', '7', '5'}, groups), isTrue);
      expect(mergeQualifies({'3', '20'}, groups), isTrue);
      // A group id equal to an ungrouped number (a POS naming groups "1",
      // "2"): group 1 and table 1 are still two units (review 1).
      expect(
          mergeQualifies(
              {'3', '7', '1'},
              validateTableGroups({
                '1': g({'3', '7'})
              })),
          isTrue);
    });
  });

  group('the Split rule (G5)', () {
    final lookup = TableGroupLookup(
        validateTableGroups({
          'G7': g({'12', '3', '7', '8'}),
          'G9': g({'9', '20'}),
        }),
        facts);
    String? split(Set<String> numbers, {bool unnumbered = false}) =>
        lookup.splitGroup(numbers, unnumberedSelected: unnumbered);

    test(
        'TG-U12 exactly one group\'s selectable members qualify, a group '
        'with a locked member and one with a single visible member '
        'included (M-TG-17)', () {
      expect(split({'7', '12', '3'}), 'G7',
          reason: 'its locked 8 is never selected');
      expect(split({' 20 '}), 'G9', reason: 'its 9 is hidden');
    });

    test(
        'TG-U13 a group plus a table, part of a group, a group plus an '
        'unnumbered table, nothing, and tables in no group do not '
        '(M-TG-17)', () {
      expect(split({'7', '12', '3', '5'}), isNull);
      expect(split({'5', '7', '12', '3'}), isNull);
      expect(split({'7', '12'}), isNull);
      expect(split({'7', '12', '3'}, unnumbered: true), isNull);
      expect(split(const {}), isNull);
      expect(split({'5'}), isNull);
      expect(split({'7', '12', '3', '8'}), isNull,
          reason: 'a locked member is never selectable');
    });
  });

  group('the lead order (G3)', () {
    List<String> sorted(List<String> numbers) =>
        [...numbers]..sort(tableNumberOrder(numbers));

    test(
        'TG-U14 all digits sort numerically by (length after leading '
        'zeros, then string), never int.parse; otherwise by string '
        '(M-C1-8, M-C1-9, M-C1-10)', () {
      expect(sorted(['12', '3', '7']), ['3', '7', '12']);
      expect(sorted(['10', '007', '9']), ['007', '9', '10']);
      expect(sorted(['7', '07', '6']), ['6', '07', '7']);
      const big = '123456789012345678901234567890';
      expect(sorted([big, '99', '0']), ['0', '99', big]);
      expect(sorted(['12', '3', '5A']), ['12', '3', '5A']);
      expect(sorted(['12', '3', '-7']), ['-7', '12', '3']);
    });

    test(
        'TG-U15 inLeadOrder: by number, a duplicate to the lowest handle, '
        'an unnumbered table dropped (M-C1-11)', () {
      final order = inLeadOrder([
        t(0x77, '7'),
        t(0x64, '5'),
        t(0x51, '12'),
        t(0x40, null),
        t(0x1F, '5'),
      ]);
      expect(handles(order), [0x1F, 0x64, 0x77, 0x51]);
      expect(handles(inLeadOrder([t(0x64, '5'), t(0x1F, '5')])), [0x1F, 0x64]);
    });
  });
}
