// Spec K7: the geometry snapshot, its canonical text, its file, and the
// merge the generator runs (M, the spec's own: let updateSnapshot overwrite
// an existing entry; N7 goes red).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

const CatalogSymbol every = CatalogSymbol(
  key: 'sample.x.y',
  version: 3,
  name: 'X',
  category: 'C',
  unit: CatalogUnit(
      kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
  base: (120.5, -40),
  shapes: [
    CatalogLine((10, 20), (30, 40)),
    CatalogPolyline([(1, 2), (3, 4), (5, 6)], closed: true),
    CatalogCircle((7, 8), 9),
    CatalogArc((1, 1), 2, 0.5, -1.25),
  ],
);

CatalogSymbol dot(String key, {(double, double) base = (300, 200)}) =>
    CatalogSymbol(
      key: key,
      name: key,
      category: 'C',
      base: base,
      shapes: [CatalogCircle(base, 150)],
    );

void main() {
  test('N1 the canonical entry: base, shapes, unit, keys sorted', () {
    // M-N1a: leave out "closed". M-N1b: leave out the unit.
    expect(geometrySnapshot(const Catalog(kit: 'sample', symbols: [every])), {
      'sample.x.y@3': '{"base":[120.5,-40.0],"shapes":['
          '{"from":[10.0,20.0],"kind":"line","to":[30.0,40.0]},'
          '{"closed":true,"kind":"polyline","points":[[1.0,2.0],[3.0,4.0],[5.0,6.0]]},'
          '{"center":[7.0,8.0],"kind":"circle","radius":9.0},'
          '{"center":[1.0,1.0],"kind":"arc","radius":2.0,"start":0.5,"sweep":-1.25}'
          '],"unit":{"capacity":1,"kind":"seat","labelling":"assigned"}}',
    });
  });

  test('N2 -0.0 is written 0.0; a symbol with no unit writes null', () {
    final s = geometrySnapshot(
        Catalog(kit: 'sample', symbols: [dot('sample.a.b', base: (-0.0, 5))]));
    // M-N2: write numbers as they are; "-0.0" appears.
    expect(
        s['sample.a.b@1'],
        '{"base":[0.0,5.0],"shapes":[{"center":[0.0,5.0],"kind":"circle",'
        '"radius":150.0}],"unit":null}');
  });

  test('N3 entries are sorted by key@version, whatever the catalog order', () {
    final s = geometrySnapshot(Catalog(
        kit: 'sample', symbols: [dot('sample.z.b'), dot('sample.a.b')]));
    expect(s.keys.toList(), ['sample.a.b@1', 'sample.z.b@1']);
  });

  test('N4 the file: one entry per line, sorted, and it reads back', () {
    final s = geometrySnapshot(Catalog(
        kit: 'sample', symbols: [dot('sample.z.b'), dot('sample.a.b')]));
    final text = encodeSnapshot(s);
    expect(
        text,
        '{\n'
        '  "sample.a.b@1": ${s['sample.a.b@1']},\n'
        '  "sample.z.b@1": ${s['sample.z.b@1']}\n'
        '}\n');
    expect(parseSnapshot(text), s);
    expect(encodeSnapshot(const {}), '{}\n');
    expect(parseSnapshot('{}\n'), isEmpty);
  });

  test('N5 parsing compares canonical texts, not the file layout', () {
    expect(
        parseSnapshot('{ "a.b.c@1" : { "base" : [ 1.0, 2.0 ], "shapes" : [],'
            ' "unit" : null } }'),
        {'a.b.c@1': '{"base":[1.0,2.0],"shapes":[],"unit":null}'});
  });

  test('N6 what is not a snapshot is a FormatException', () {
    expect(() => parseSnapshot('not json'), throwsFormatException);
    expect(() => parseSnapshot('[1]'), throwsFormatException);
    expect(() => parseSnapshot('{"a.b.c@1": 3}'), throwsFormatException);
  });

  test('N7 updateSnapshot adds new entries and never rewrites one', () {
    final merged = updateSnapshot(
      {'a.b.c@1': 'committed', 'c.d.e@1': 'retired'},
      {'a.b.c@1': 'changed', 'b.c.d@1': 'new'},
    );
    // M-N7 (the spec's own): `{...committed, ...current}` lets the changed
    // geometry overwrite the committed entry.
    expect(merged, {
      'a.b.c@1': 'committed',
      'b.c.d@1': 'new',
      'c.d.e@1': 'retired',
    });
    expect(merged.keys.toList(), ['a.b.c@1', 'b.c.d@1', 'c.d.e@1']);
  });
}
