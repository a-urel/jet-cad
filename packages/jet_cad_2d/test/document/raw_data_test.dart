import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('stores an opaque blob per handle per source', () {
    // The engine never inspects the payload; only the adapter that wrote it
    // knows its shape. That is what keeps this from being a DXF concept in the
    // core document.
    final raw = RawDataStore()
      ..set(const Handle(10), SourceKind.dxf, {
        '70': 1,
        'unknown': [1, 2]
      });
    expect((raw.get(const Handle(10), SourceKind.dxf)! as Map)['70'], 1);
    expect(raw.get(const Handle(10), SourceKind.ifc), isNull);
  });

  test('keeps sources independent for the same handle', () {
    final raw = RawDataStore()
      ..set(const Handle(10), SourceKind.dxf, {'a': 1})
      ..set(const Handle(10), SourceKind.ifc, {'b': 2});
    expect(raw.allFor(const Handle(10)).keys,
        containsAll([SourceKind.dxf, SourceKind.ifc]));
  });

  test('round-trips unchanged, including nested structures', () {
    final source = RawDataStore()
      ..set(const Handle(300), SourceKind.dxf, {
        'nested': {
          'deep': [1, 'two', 3.0]
        },
      })
      ..set(const Handle(10), SourceKind.dxf, {'x': 1});
    final json = source.toJson();
    final loaded = RawDataStore()..loadJson(json);
    expect(loaded.toJson(), json);
    expect(
      ((loaded.get(const Handle(300), SourceKind.dxf)! as Map)['nested']
          as Map)['deep'],
      [1, 'two', 3.0],
    );
  });

  test('serialises handles in numeric order for determinism', () {
    final raw = RawDataStore()
      ..set(const Handle(300), SourceKind.dxf, {'x': 1})
      ..set(const Handle(10), SourceKind.dxf, {'x': 2})
      ..set(const Handle(200), SourceKind.dxf, {'x': 3});
    expect(raw.toJson().keys.toList(), ['10', '200', '300']);
  });

  test('remove clears every source for a handle', () {
    final raw = RawDataStore()
      ..set(const Handle(10), SourceKind.dxf, {'a': 1})
      ..remove(const Handle(10));
    expect(raw.allFor(const Handle(10)), isEmpty);
    expect(raw.isEmpty, isTrue);
  });

  test(
      'allFor returns a read-only view, so a caller cannot corrupt the '
      'store without going through set/remove', () {
    final raw = RawDataStore()..set(const Handle(1), SourceKind.dxf, {'a': 1});
    final view = raw.allFor(const Handle(1));
    expect(() => view[SourceKind.ifc] = 'x', throwsUnsupportedError);
  });
}
