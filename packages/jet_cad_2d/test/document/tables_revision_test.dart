// Table mutations reach nobody today. `DocChange` is emitted only by
// `undo.dart` when a command is applied, undone or redone, and
// `TableSection.add`, `remove` and `clear` go through no command at all
// (`tables.dart:51-68`). Plan 3g's tile cache must invalidate on a layer
// colour change, so the tables grow a revision and a `Listenable`.
//
// All three mutators, because `clear` is the one an earlier draft of the spec
// missed and a load path that clears would otherwise leave every tile stale.

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

LayerRecord layer(int handle, String name) => LayerRecord(
      handle: Handle(handle),
      name: name,
      // Not the default: the anti-degenerate habit applies to fixtures in this
      // repository generally, and a record that differs only by handle proves
      // less than one that differs in a field a resolver reads.
      color: const IndexedColor(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 40,
    );

void main() {
  test('every table mutator bumps the revision and notifies', () {
    final tables = DocumentTables.standard();
    var notifications = 0;
    void listener() => notifications++;
    tables.changes.addListener(listener);
    addTearDown(() => tables.changes.removeListener(listener));

    final start = tables.mutationRevision;

    tables.layers.add(layer(900, 'WALLS'));
    expect(tables.mutationRevision, start + 1, reason: 'add');
    expect(notifications, 1);

    tables.layers.remove(const Handle(900));
    expect(tables.mutationRevision, start + 2, reason: 'remove');
    expect(notifications, 2);

    tables.linetypes.clear();
    expect(tables.mutationRevision, start + 3, reason: 'clear');
    expect(notifications, 3);
  });

  test('a rejected add bumps nothing', () {
    final tables = DocumentTables.standard();
    tables.layers.add(layer(901, 'GRID'));
    final after = tables.mutationRevision;

    expect(() => tables.layers.add(layer(901, 'OTHER')),
        throwsA(isA<DuplicateHandleError>()));
    expect(tables.mutationRevision, after,
        reason: 'a throw is not a mutation; bumping here would invalidate '
            'every tile for an edit the document refused');
  });

  test('a remove of an absent handle bumps nothing', () {
    final tables = DocumentTables.standard();
    final after = tables.mutationRevision;
    tables.layers.remove(const Handle(9999));
    expect(tables.mutationRevision, after);
  });

  test('every section is wired, not just layers', () {
    final tables = DocumentTables.standard();
    var revision = tables.mutationRevision;
    // Six sections; a per-section wiring mistake would leave one silent, and
    // a test that checked `layers` alone would not see it.
    tables.layers.add(layer(910, 'A'));
    expect(tables.mutationRevision, ++revision);
    tables.linetypes.add(const LinetypeRecord(
        handle: Handle(911),
        name: 'DASHED2',
        description: 'A test-only dash pattern',
        pattern: DashPattern(dashes: [4.0, -2.0], totalLength: 6.0)));
    expect(tables.mutationRevision, ++revision);
    tables.textStyles.add(const TextStyleRecord(
        handle: Handle(912),
        name: 'TITLE',
        fontFamily: 'Roboto',
        widthFactor: 1.2));
    expect(tables.mutationRevision, ++revision);
    tables.patterns.add(const PatternRecord(
      handle: Handle(913),
      name: 'NET',
      // PatternRecord.lines is required with no default, so this is the
      // fixture rather than a departure from one -- non-trivial so the
      // record is not indistinguishable from an empty pattern.
      lines: [
        PatternLine(
          angle: 45.0,
          baseX: 0.0,
          baseY: 0.0,
          deltaX: 0.0,
          deltaY: 3.0,
          dashes: [2.0, -1.0],
        ),
      ],
    ));
    expect(tables.mutationRevision, ++revision);
    tables.dimStyles.add(const DimStyleRecord(
      handle: Handle(914),
      name: 'D1',
      // Not the default empty map: a resolver reading a dimension style
      // reads fields out of `opaque`, not out of the record's presence alone.
      opaque: {'DIMASZ': 2.5},
    ));
    expect(tables.mutationRevision, ++revision);
    tables.appIds.add(const AppIdRecord(handle: Handle(915), name: 'ACAD2'));
    expect(tables.mutationRevision, ++revision);
  });
}
