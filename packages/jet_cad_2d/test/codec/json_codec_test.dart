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
    // Child nodes only. The entity below states that this definition holds it
    // through EntityRecord.owner, which is the authoritative side.
    children: const [],
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
  // A component type this build has never heard of — preserve-unknown layer
  // 2. Nested so a shallow copy could not fake byte-identical round-tripping.
  doc.components.attachUnknown(instance, {
    'typeId': 'acme.plumbing',
    'diameter': 32,
    'nested': {'a': 1},
  });
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

  test('refuses a schema version below the first one that ever existed', () {
    // A file declaring 0 or a negative version is not one this package wrote.
    // Parsing it as v1 would fail — if at all — much deeper in, with a
    // FormatException naming some field rather than the version.
    for (final version in [0, -1]) {
      final json = DraftDocumentCodec.encode(DraftDocument.empty())
        ..['schemaVersion'] = version;
      expect(() => DraftDocumentCodec.decode(json),
          throwsA(isA<SchemaVersionError>()),
          reason: 'schemaVersion $version');
    }
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

  test("an instance's colour survives save and load", () {
    final doc = DraftDocument.empty();
    const def = Handle(600);
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'sym',
        basePoint: Vector2.zero(),
        children: const []));
    const instance = Handle(601);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: def,
      layer: ReservedHandles.layerZero,
      color: const IndexedColor(3),
    )));

    final loaded = DraftDocumentCodec.decode(DraftDocumentCodec.encode(doc));
    final node = loaded.tree[instance]! as InstanceNode;
    expect(node.color, const IndexedColor(3));
  });

  test('an instance with no stored colour loads as ByBlockColor', () {
    // Simulates a file written before InstanceNode carried a colour field:
    // strip the key a current encode would have written, rather than
    // hand-authoring a whole schemaVersion-2 file, so the fixture stays
    // anchored to what this build actually produces.
    final doc = DraftDocument.empty();
    const def = Handle(602);
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'sym',
        basePoint: Vector2.zero(),
        children: const []));
    const instance = Handle(603);
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: instance,
      parent: doc.rootHandle,
      transform: Transform2.identity(),
      definition: def,
      layer: ReservedHandles.layerZero,
      color: const IndexedColor(3),
    )));

    final json = DraftDocumentCodec.encode(doc);
    final nodes = (json['nodes']! as List).cast<Map<String, Object?>>();
    final nodeJson = nodes.singleWhere((n) => n['handle'] == instance.toJson());
    expect(nodeJson.remove('color'), isNotNull,
        reason: 'sanity: a current encode really does write the key');

    final loaded = DraftDocumentCodec.decode(json);
    final node = loaded.tree[instance]! as InstanceNode;
    expect(node.color, const ByBlockColor());
  });

  test('geometry is stored inline, so slots are never persisted', () {
    final json = DraftDocumentCodec.encode(sampleDocument());
    final entity = (json['entities']! as List).single as Map;
    expect(entity.keys.toList(), ['record', 'geometry']);
    // A persisted slot would make the file depend on allocation history.
    expect((entity['record']! as Map).containsKey('geomIndex'), isFalse,
        reason: 'a slot is not durable state and must never reach the file');
    final loaded = DraftDocumentCodec.decode(json);
    final slot = loaded.entities.liveSlots.single;
    expect(loaded.geometry.read(loaded.entities.geomIndexAt(slot)).pointAt(1),
        Vector2(1, 1));
  });

  test('a stored geomIndex in an older file is discarded, not honoured', () {
    // Files written before the field was dropped still carry it. Honouring it
    // would bind the record to a slot in the *saving* store's numbering
    // instead of the *loading* store's.
    //
    // A one-entity document cannot tell "discarded" from "honoured" apart:
    // with a single slot, allocation order and the stored value agree either
    // way. Three entities with stored indices that could not be the
    // allocation-order slots — 7, 9, 3 in the file, against the 0, 1, 2 the
    // loader actually assigns — make the two behaviours diverge, and each
    // entity carries its own distinguishing geometry so a wrong pairing shows
    // up as the wrong point, not just a wrong number.
    final doc = DraftDocument.empty();
    final handles = [for (var i = 0; i < 3; i++) doc.handleSeed.next()];
    for (var i = 0; i < handles.length; i++) {
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: handles[i],
          owner: doc.rootHandle,
          kind: EntityKind.line,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: kByLayer,
          transparency: kByLayer,
          flags: 0,
        ),
        payload: GeometryPayload(
          coords: Float64List.fromList([i * 10.0, 0, i * 10.0 + 1, 1]),
          scalars: Float64List(0),
        ),
      ));
    }

    final json = DraftDocumentCodec.encode(doc);
    final entities = (json['entities']! as List).cast<Map<String, Object?>>();
    const storedIndices = [7, 9, 3];
    for (var i = 0; i < entities.length; i++) {
      (entities[i]['record']! as Map<String, Object?>)['geomIndex'] =
          storedIndices[i];
    }

    final loaded = DraftDocumentCodec.decode(json);
    expect(loaded.entities.liveSlots.toList(), [0, 1, 2],
        reason: 'slots follow allocation order, not the stored indices');
    for (var i = 0; i < handles.length; i++) {
      final slot = loaded.entities.slotOf(handles[i])!;
      expect(slot, i,
          reason: 'entity $i lands in the slot allocation order gives it, '
              'not stored index ${storedIndices[i]}');
      expect(
        loaded.geometry.read(loaded.entities.geomIndexAt(slot)).pointAt(1),
        Vector2(i * 10.0 + 1, 1),
        reason: 'entity $i must resolve to its own payload',
      );
    }
  });

  test('serialization is idempotent, which is the determinism guarantee', () {
    // save(load(save(d))) == save(d). The naive save(load(x)) == x form only
    // holds when x was already produced canonically.
    //
    // The document must have a *hole* in its entity slots for this to test
    // anything: with a dense store, whatever a save wrote about slots would
    // agree with what the dense reallocation on load produced, and a codec
    // that persisted allocation history would pass anyway. Three adds and a
    // delete of the first leaves live slots {1, 2}, which reload as {0, 1}.
    final doc = sampleDocument();
    final extra = [for (var i = 0; i < 3; i++) doc.handleSeed.next()];
    for (var i = 0; i < extra.length; i++) {
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: extra[i],
          owner: doc.rootHandle,
          kind: EntityKind.line,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: kByLayer,
          transparency: kByLayer,
          flags: 0,
        ),
        payload: GeometryPayload(
          coords: Float64List.fromList([i * 10.0, 0, i * 10.0 + 1, 1]),
          scalars: Float64List(0),
        ),
      ));
    }
    doc.commands.execute(RemoveEntityCommand(extra[0]));
    expect(doc.entities.liveSlots.toList(), [0, 2, 3],
        reason: 'sanity: the fixture really does have a hole in it');

    final once = DraftDocumentCodec.encodeToString(doc);
    final reloaded = DraftDocumentCodec.decodeString(once);
    expect(reloaded.entities.liveSlots.toList(), [0, 1, 2],
        reason: 'sanity: reloading really does renumber the survivors');

    final twice = DraftDocumentCodec.encodeToString(reloaded);
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

  test('an unknown component payload round-trips byte-identical', () {
    final json = DraftDocumentCodec.encode(sampleDocument());
    final components = (json['components']! as Map).cast<String, Object?>();
    final byHandle =
        (components['acme.plumbing']! as Map).cast<String, Object?>();
    final payload = byHandle.values.single as Map;
    // The typeId is the map key one layer up; embedding it in the payload
    // too would break byte-identity on a second round-trip.
    expect(payload.containsKey('typeId'), isFalse);
    expect(payload['diameter'], 32);
    expect((payload['nested']! as Map)['a'], 1);

    final loaded = DraftDocumentCodec.decode(json);
    final instance = loaded.tree.nodes.whereType<InstanceNode>().single.handle;
    final preserved = loaded.components.unknownOf(instance);
    expect(preserved, hasLength(1));
    expect(preserved.single['typeId'], 'acme.plumbing');
    expect(preserved.single['diameter'], 32);
    expect((preserved.single['nested']! as Map)['a'], 1);

    // Byte-identical on a second encode, not just structurally similar.
    expect(DraftDocumentCodec.encode(loaded)['components'], json['components']);
  });

  test(
      'decode raises the handle seed above every handle actually read, not '
      'just the declared seed', () {
    final source = sampleDocument();
    // The document's own seed already equals the highest handle anywhere in
    // it: every handle here was minted by sequential doc.handleSeed.next()
    // calls, so this is the actual maximum, not a hardcoded stand-in for it.
    final maxHandleInDocument = source.handleSeed.current.value;
    final json = DraftDocumentCodec.encode(source);
    // Simulate a hand-edited or truncated file whose declared seed
    // undercounts what the file actually contains.
    json['handleSeed'] = 1;

    final loaded = DraftDocumentCodec.decode(json);
    expect(loaded.handleSeed.next().value, greaterThan(maxHandleInDocument));
  });

  test(
      'decode repairs a definition cycle and reports it only when a '
      'diagnostics list is passed', () {
    // Two definitions built by hand rather than through commands: the live
    // API rejects a cycle on the way in, so the only way to exercise import's
    // recovery path is to construct the file directly, the way a corrupted or
    // hand-edited document would arrive.
    final json = DraftDocumentCodec.encode(DraftDocument.empty());
    const defA = Handle(500);
    const defB = Handle(501);
    const nodeA = Handle(502);
    const nodeB = Handle(503);

    json['definitions'] = [
      Definition(
        handle: defA,
        name: 'A',
        basePoint: Vector2.zero(),
        children: const [nodeA],
      ).toJson(),
      Definition(
        handle: defB,
        name: 'B',
        basePoint: Vector2.zero(),
        children: const [nodeB],
      ).toJson(),
    ];
    json['nodes'] = [
      ...(json['nodes']! as List),
      InstanceNode(
        handle: nodeA,
        parent: defA,
        transform: Transform2.identity(),
        definition: defB,
        layer: ReservedHandles.layerZero,
      ).toJson(),
      InstanceNode(
        handle: nodeB,
        parent: defB,
        transform: Transform2.identity(),
        definition: defA,
        layer: ReservedHandles.layerZero,
      ).toJson(),
    ];

    final diagnostics = <Diagnostic>[];
    final loaded = DraftDocumentCodec.decode(json, diagnostics: diagnostics);

    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.code, 'tree.cycle_dropped');
    // Names the back edge that closed the cycle: the dropped instance, the
    // definition its container names, and the definition it pointed at.
    expect(diagnostics.single.handles, [nodeB, defB, defA]);
    // The cycle is broken, not merely detected: defB no longer instances
    // anything, so walking from either definition now terminates.
    expect(loaded.tree.definition(defB)!.children, isEmpty);

    // The repair itself happens whether or not the caller asks to be told.
    final loadedWithoutDiagnostics = DraftDocumentCodec.decode(json);
    expect(loadedWithoutDiagnostics.tree.definition(defB)!.children, isEmpty);
  });

  test('a document with a region round-trips byte-identically', () {
    final doc = DraftDocument.empty();
    final cmd = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );
    doc.commands.execute(cmd);
    final first = jsonEncode(DraftDocumentCodec.encode(doc));
    final reloaded =
        DraftDocumentCodec.decode(jsonDecode(first) as Map<String, Object?>);
    expect(jsonEncode(DraftDocumentCodec.encode(reloaded)), first);
  });

  test('load leaves the fill index populated, not empty', () {
    // The frame path reads and never computes. A load that left this empty
    // would ear-clip on the first paint of every visible fill.
    final doc = DraftDocument.empty();
    final cmd = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );
    doc.commands.execute(cmd);
    final reloaded = DraftDocumentCodec.decode(
        jsonDecode(jsonEncode(DraftDocumentCodec.encode(doc)))
            as Map<String, Object?>);
    expect(reloaded.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
    expect(reloaded.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test('the schema version is 6, and a v7 document is refused by version', () {
    expect(kSchemaVersion, 6);
    // `isA<SchemaVersionError>()`, not `throwsA(anything)`: a bare
    // `{'schemaVersion': N}` map fails on the missing `'header'` key too, so
    // the loose matcher passed whenever N was the *current* version rather
    // than a future one. The point of this test is that the refusal comes from
    // the version guard.
    expect(() => DraftDocumentCodec.decode({'schemaVersion': 7}),
        throwsA(isA<SchemaVersionError>()));
  });
}
