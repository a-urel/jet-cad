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

  test('unknown input id throws ArgumentError and mutates nothing', () async {
    await expectLater(
      doc.extrude(const FaceId('nope'), 5),
      throwsArgumentError,
    );
    expect(doc.operations, isEmpty);
    expect(doc.entities, isEmpty);
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
}
