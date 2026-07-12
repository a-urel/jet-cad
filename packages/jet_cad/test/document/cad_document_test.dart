import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/document/doc_change.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/document/operation.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  late CadDocument doc;

  setUp(() async {
    doc = await CadDocument.create(FakeKernelBridge());
  });

  tearDown(() => doc.dispose());

  test('makeBox registers body and subshape entities and commits an op',
      () async {
    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);

    final body = await doc.makeBox(const Vec3(10, 10, 10));
    await Future<void>.delayed(Duration.zero);

    expect(doc.entities, hasLength(1 + 6 + 12 + 8));
    expect(doc.entities[body]!.kind, EntityKind.body);
    expect(doc.entities[body]!.name, 'Box 1');
    expect(doc.operations, hasLength(1));
    expect(doc.operations.single, isA<MakeBoxOp>());
    expect(doc.head, 1);

    expect(events, hasLength(2));
    expect(events[0], isA<EntitiesAdded>());
    expect(events[1], isA<OperationCommitted>());
    await sub.cancel();
  });

  test('booleanCombine consumes inputs and applies the remap', () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    final entitiesBefore = doc.entities.length;

    final c = await doc.booleanCombine(a, b, BoolOp.cut);

    expect(doc.entities.containsKey(a), isFalse);
    expect(doc.entities.containsKey(b), isFalse);
    expect(doc.entities[c]!.kind, EntityKind.body);
    // two full boxes (27 each) removed, one new box (27) added
    expect(doc.entities.length, entitiesBefore - 27);
    expect(doc.head, 3);
  });

  test('fillet keeps the body and swaps edge entities for face entities',
      () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    final edge = doc.entities.values
        .firstWhere((e) => e.kind == EntityKind.edge)
        .id as EdgeId;

    final newFaces = await doc.fillet([edge], 0.2);

    expect(doc.entities.containsKey(edge), isFalse);
    expect(doc.entities[newFaces.single]!.kind, EntityKind.face);
    expect(doc.entities[newFaces.single]!.parent, body);
    expect(doc.entities.containsKey(body), isTrue);
  });

  test(
      'fillet result ids (faces, and all op outputs) resolve to real '
      'entities', () async {
    await doc.makeBox(const Vec3(1, 1, 1));
    final edge = doc.entities.values
        .firstWhere((e) => e.kind == EntityKind.edge)
        .id as EdgeId;

    final newFaces = await doc.fillet([edge], 0.2);

    for (final f in newFaces) {
      expect(doc.entities.containsKey(f), isTrue,
          reason: 'every returned face id must be a real entity');
    }
    final op = doc.operations.last as FilletOp;
    // The kernel's fillet introduces new edges/vertices too (see
    // FakeKernelBridge.fillet), not just faces — outputs must carry all of
    // them or a bare `body + faces` count here would let a regression that
    // silently drops edges/vertices from outputs go unnoticed.
    expect(op.outputs.length, greaterThan(1 + newFaces.length),
        reason: 'op.outputs must include the new edges/vertices, not just '
            'body + faces');
    for (final id in op.outputs) {
      expect(doc.entities.containsKey(id), isTrue,
          reason: 'every op output id (incl. new edges/vertices) must be a '
              'real entity');
    }
  });

  test('fillet with no edges throws ArgumentError and mutates nothing',
      () async {
    await doc.makeBox(const Vec3(1, 1, 1));
    await expectLater(doc.fillet(const [], 0.2), throwsArgumentError);
    expect(doc.operations, hasLength(1));
    expect(doc.head, 1);
  });

  test('unknown input id throws ArgumentError and mutates nothing', () async {
    await expectLater(
      doc.extrude(const FaceId('nope'), 5),
      throwsArgumentError,
    );
    expect(doc.operations, isEmpty);
    expect(doc.entities, isEmpty);
  });

  test('wrong-kind entity id throws ArgumentError', () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    // body.value names a real entity, but of kind body, not edge.
    await expectLater(
      doc.fillet([EdgeId(body.value)], 0.2),
      throwsArgumentError,
    );
  });

  test('fillet edges from two different bodies throws ArgumentError', () async {
    final bodyA = await doc.makeBox(const Vec3(1, 1, 1));
    final edgeA = doc.entities.values
        .firstWhere((e) => e.kind == EntityKind.edge && e.parent == bodyA)
        .id as EdgeId;
    final bodyB = await doc.makeBox(const Vec3(2, 2, 2));
    final edgeB = doc.entities.values
        .firstWhere((e) => e.kind == EntityKind.edge && e.parent == bodyB)
        .id as EdgeId;

    await expectLater(
      doc.fillet([edgeA, edgeB], 0.2),
      throwsArgumentError,
    );
  });

  test('booleanCombine rejects identical operands', () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    await expectLater(
      doc.booleanCombine(a, a, BoolOp.fuse),
      throwsArgumentError,
    );
  });

  test('booleanCombine emits removed, added, then committed in order',
      () async {
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));

    final events = <DocChange>[];
    final sub = doc.changes.listen(events.add);

    await doc.booleanCombine(a, b, BoolOp.fuse);
    await Future<void>.delayed(Duration.zero);

    final last3 = events.sublist(events.length - 3);
    expect(last3[0], isA<EntitiesRemoved>());
    expect(last3[1], isA<EntitiesAdded>());
    expect(last3[2], isA<OperationCommitted>());
    await sub.cancel();
  });

  test('kernel failure surfaces as KernelException and mutates nothing',
      () async {
    await expectLater(
      doc.makeBox(const Vec3(-1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    expect(doc.operations, isEmpty);
    expect(doc.entities, isEmpty);
    expect(doc.head, 0);
  });

  test('exportStep round-trips through the bridge', () async {
    final body = await doc.makeBox(const Vec3(1, 1, 1));
    final bytes = await doc.exportStep([body]);
    expect(bytes, isNotEmpty);
  });

  test('exportStep with unknown body throws ArgumentError, not sync', () async {
    await expectLater(
      doc.exportStep([const BodyId('nope')]),
      throwsArgumentError,
    );
  });
}
