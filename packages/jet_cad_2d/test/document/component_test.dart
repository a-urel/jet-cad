import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// A domain component defined by the *test*, not by the engine — the engine
/// deliberately defines no domain types.
class SeatingComponent implements Component {
  final int number;
  final int capacity;

  const SeatingComponent({required this.number, required this.capacity});

  @override
  String get typeId => 'test.seating';

  @override
  Map<String, Object?> toJson() => {'number': number, 'capacity': capacity};

  static SeatingComponent fromJson(Map<String, Object?> json) =>
      SeatingComponent(
        number: json['number']! as int,
        capacity: json['capacity']! as int,
      );

  @override
  bool operator ==(Object other) =>
      other is SeatingComponent &&
      other.number == number &&
      other.capacity == capacity;

  @override
  int get hashCode => Object.hash(number, capacity);
}

ComponentRegistry registryWithSeating() => ComponentRegistry()
  ..register<SeatingComponent>('test.seating', SeatingComponent.fromJson);

void main() {
  test('attaches, reads back, and detaches', () {
    final registry = registryWithSeating();
    registry.attach(
        const Handle(10), const SeatingComponent(number: 4, capacity: 6));
    expect(registry.get<SeatingComponent>(const Handle(10)),
        const SeatingComponent(number: 4, capacity: 6));
    registry.detach<SeatingComponent>(const Handle(10));
    expect(registry.get<SeatingComponent>(const Handle(10)), isNull);
  });

  test('attaching an unregistered type throws instead of silently dropping',
      () {
    expect(
      () => ComponentRegistry().attach(
          const Handle(10), const SeatingComponent(number: 1, capacity: 2)),
      throwsA(isA<UnregisteredComponentError>()),
    );
  });

  test('withComponent returns ascending handles and only carriers', () {
    // The runtime's core query. Ascending because query results must be stably
    // ordered; sized by component count, not entity count.
    final registry = registryWithSeating();
    for (final h in [30, 10, 20]) {
      registry.attach(Handle(h), SeatingComponent(number: h, capacity: 4));
    }
    expect(
        [for (final h in registry.withComponent<SeatingComponent>()) h.value],
        [10, 20, 30]);
  });

  test('attaches to nodes and entities alike — one handle space', () {
    final registry = registryWithSeating();
    registry.attach(
        const Handle(10), const SeatingComponent(number: 1, capacity: 2));
    registry.attach(
        const Handle(9999), const SeatingComponent(number: 2, capacity: 2));
    expect(registry.withComponent<SeatingComponent>(), hasLength(2));
  });

  test('an unknown typeId is preserved verbatim through a round-trip', () {
    // No layer discards data it does not understand. A plugin's component type
    // must survive an app build that has never heard of it.
    final source = ComponentRegistry()
      ..attachUnknown(const Handle(10), {
        'typeId': 'acme.plumbing',
        'diameter': 32,
        'nested': {'a': 1},
      });
    final json = source.toJson();

    final loaded = ComponentRegistry()..loadJson(json);
    final preserved = loaded.unknownOf(const Handle(10));
    expect(preserved, hasLength(1));
    expect(preserved.single['typeId'], 'acme.plumbing');
    expect(preserved.single['diameter'], 32);
    expect((preserved.single['nested']! as Map)['a'], 1);
    expect(loaded.toJson(), json);
  });

  test('a registered component round-trips through json', () {
    final source = registryWithSeating()
      ..attach(
          const Handle(10), const SeatingComponent(number: 4, capacity: 6));
    final loaded = registryWithSeating()..loadJson(source.toJson());
    expect(loaded.get<SeatingComponent>(const Handle(10)),
        const SeatingComponent(number: 4, capacity: 6));
  });

  test('a registered type read by a registry that lacks it is still preserved',
      () {
    final source = registryWithSeating()
      ..attach(
          const Handle(10), const SeatingComponent(number: 4, capacity: 6));
    final json = source.toJson();

    final ignorant = ComponentRegistry()..loadJson(json);
    expect(ignorant.unknownOf(const Handle(10)), hasLength(1));
    expect(ignorant.toJson(), json, reason: 'preserved byte-for-byte');
  });

  test('toJson orders type ids and handles deterministically', () {
    final registry = registryWithSeating();
    for (final h in [300, 100, 200]) {
      registry.attach(Handle(h), SeatingComponent(number: h, capacity: 1));
    }
    registry.attachUnknown(const Handle(50), {'typeId': 'aaa.first'});
    final json = registry.toJson();
    expect(json.keys.toList(), ['aaa.first', 'test.seating']);
    expect((json['test.seating']! as Map).keys.toList(), ['100', '200', '300']);
  });

  group('OriginComponent', () {
    test('records the source format and original identifier', () {
      final registry = ComponentRegistry()..registerBuiltIns();
      registry.attach(const Handle(10),
          const OriginComponent(source: SourceKind.dxf, id: '2A'));
      expect(registry.get<OriginComponent>(const Handle(10))!.id, '2A');
    });

    test('is internal, so it is never written as foreign extended data', () {
      final registry = ComponentRegistry()..registerBuiltIns();
      expect(registry.isInternal(OriginComponent.componentTypeId), isTrue);
      expect(registry.isInternal('test.seating'), isFalse);
    });

    test('round-trips through the document format', () {
      final source = ComponentRegistry()..registerBuiltIns();
      source.attach(const Handle(10),
          const OriginComponent(source: SourceKind.ifc, id: '3xY7\$0abcd'));
      final loaded = ComponentRegistry()..registerBuiltIns();
      loaded.loadJson(source.toJson());
      final origin = loaded.get<OriginComponent>(const Handle(10))!;
      expect(origin.source, SourceKind.ifc);
      expect(origin.id, '3xY7\$0abcd');
    });
  });
}
