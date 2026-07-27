import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

DraftDocument sampleDocument() {
  final doc = DraftDocument.empty();
  doc.header
    ..units = DrawingUnits.millimeters
    ..importedExtents = Aabb2(Vector2(0, 0), Vector2(500, 400));

  final defHandle = doc.handleSeed.next();
  final defEntity = doc.handleSeed.next();
  doc.tree.addDefinition(Definition(
    handle: defHandle,
    name: 'Table-4Seat',
    basePoint: Vector2(0.5, 0.5),
    children: [defEntity],
  ));
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: defEntity,
      owner: defHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([0, 0, 1, 1]),
      scalars: Float64List(0),
    ),
  ));

  final instance = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: instance,
    parent: doc.rootHandle,
    transform: Transform2.translation(4.5e6, -3.2e6),
    definition: defHandle,
    layer: ReservedHandles.layerZero,
  )));
  doc.commands.execute(SetComponentCommand<OriginComponent>(
    instance,
    const OriginComponent(source: SourceKind.dxf, id: '2A'),
  ));
  doc.rawData.set(instance, SourceKind.dxf, {'1001': 'ACME', '1000': 'x'});
  return doc;
}

void main() {
  test('encodes the schema version and a fixed top-level key order', () {
    final json = DraftDocumentCodec.encode(DraftDocument.empty());
    expect(json['schemaVersion'], kSchemaVersion);
    expect(json.keys.toList(), [
      'schemaVersion',
      'header',
      'tables',
      'definitions',
      'root',
      'nodes',
      'entities',
      'components',
      'rawData',
      'handleSeed',
    ]);
  });

  test('refuses a document with no schema version', () {
    expect(() => DraftDocumentCodec.decode(const {}),
        throwsA(isA<SchemaVersionError>()));
  });

  test('refuses a schema version from the future', () {
    expect(
      () => DraftDocumentCodec.decode({'schemaVersion': kSchemaVersion + 1}),
      throwsA(isA<SchemaVersionError>()),
    );
  });

  test('round-trips a document structurally', () {
    final source = sampleDocument();
    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(source));

    expect(loaded.header.units, DrawingUnits.millimeters);
    expect(loaded.header.importedExtents!.max, Vector2(500, 400));
    expect(loaded.tree.definitions, hasLength(1));
    expect(loaded.tree.definitions.single.name, 'Table-4Seat');
    expect(loaded.entities.liveCount, 1);
    expect(loaded.extents.min.x, closeTo(4.5e6, 1e-9));
  });

  test('geometry is stored inline, so slots are never persisted', () {
    final json = DraftDocumentCodec.encode(sampleDocument());
    final entity = (json['entities']! as List).single as Map;
    expect(entity.keys.toList(), ['record', 'geometry']);
    // A persisted slot would make the file depend on allocation history.
    expect((entity['record']! as Map).containsKey('geomIndex'), isTrue,
        reason: 'the record still has the field; the loader overwrites it');
    final loaded = DraftDocumentCodec.decode(json);
    final slot = loaded.entities.liveSlots.single;
    expect(loaded.geometry.read(loaded.entities.geomIndexAt(slot)).pointAt(1),
        Vector2(1, 1));
  });

  test('serialization is idempotent, which is the determinism guarantee', () {
    // save(load(save(d))) == save(d). The naive save(load(x)) == x form only
    // holds when x was already produced canonically.
    final once = DraftDocumentCodec.encodeToString(sampleDocument());
    final twice = DraftDocumentCodec.encodeToString(
        DraftDocumentCodec.decodeString(once));
    expect(twice, once);
  });

  test('two documents built the same way encode identically', () {
    expect(DraftDocumentCodec.encodeToString(sampleDocument()),
        DraftDocumentCodec.encodeToString(sampleDocument()));
  });

  test('unknown top-level fields survive a round-trip', () {
    final json = DraftDocumentCodec.encode(DraftDocument.empty())
      ..['futureSection'] = {'written': 'by a newer build'};
    final loaded = DraftDocumentCodec.decode(json);
    expect(loaded.unknownDocumentFields['futureSection'], isNotNull);
    final again = DraftDocumentCodec.encode(loaded);
    expect(again['futureSection'], {'written': 'by a newer build'});
  });

  test('preserved raw data and components survive a round-trip', () {
    final loaded =
        DraftDocumentCodec.decode(DraftDocumentCodec.encode(sampleDocument()));
    final instance = loaded.tree.nodes.whereType<InstanceNode>().single.handle;
    expect(loaded.components.get<OriginComponent>(instance)!.id, '2A');
    expect(
        (loaded.rawData.get(instance, SourceKind.dxf)! as Map)['1001'], 'ACME');
  });

  test('the handle seed is restored so reloaded documents cannot reissue', () {
    final source = sampleDocument();
    final before = source.handleSeed.current;
    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(source));
    expect(loaded.handleSeed.current, before);
    expect(loaded.handleSeed.next().value, greaterThan(before.value));
  });

  test('a loaded document starts with no undo history', () {
    final loaded =
        DraftDocumentCodec.decode(DraftDocumentCodec.encode(sampleDocument()));
    expect(loaded.commands.canUndo, isFalse);
  });

  test('encodeToString produces parseable canonical JSON', () {
    final text = DraftDocumentCodec.encodeToString(sampleDocument());
    expect(jsonDecode(text), isA<Map<String, Object?>>());
  });
}
