import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/document/codec.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  test('encode/load round-trips ops, entities, and head', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    await doc.booleanCombine(a, b, BoolOp.fuse);
    await doc.undo(); // head = 2 of 3

    final json =
        jsonDecode(jsonEncode(await doc.save())) as Map<String, Object?>;
    expect(json['schemaVersion'], 1);
    expect(json['kernelVersion'], 'fake-1.0');
    expect(json['occtVersion'], 'none');

    final restored = await CadDocument.load(json, FakeKernelBridge());
    expect(restored.head, doc.head);
    expect(restored.operations.length, doc.operations.length);
    expect(restored.entities, doc.entities);
    expect(restored.canUndo, isFalse,
        reason: 'pre-load ops are not undoable in v1');
    await doc.dispose();
    await restored.dispose();
  });

  test('load continues numbering ops', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    await doc.makeBox(const Vec3(1, 1, 1));
    final json = await doc.save();

    final restored = await CadDocument.load(json, FakeKernelBridge());
    await restored.makeBox(const Vec3(2, 2, 2));
    final ids = [for (final op in restored.operations) op.id.value];
    expect(ids.toSet().length, ids.length, reason: 'op ids stay unique');
    await doc.dispose();
    await restored.dispose();
  });

  test('unknown schema version throws FormatException', () async {
    await expectLater(
      CadDocument.load({'schemaVersion': 99}, FakeKernelBridge()),
      throwsFormatException,
    );
  });

  test('redo after load throws StateError instead of crashing', () async {
    // UndoRecords are in-memory only and don't survive persistence. A
    // document loaded with head < ops.length looks redoable, but replaying
    // that operation has no snapshot to restore from.
    final doc = await CadDocument.create(FakeKernelBridge());
    await doc.makeBox(const Vec3(1, 1, 1));
    await doc.makeBox(const Vec3(2, 2, 2));
    await doc.undo(); // head = 1 of 2
    final json =
        jsonDecode(jsonEncode(await doc.save())) as Map<String, Object?>;

    final restored = await CadDocument.load(json, FakeKernelBridge());
    expect(restored.canRedo, isFalse);
    await expectLater(restored.redo(), throwsStateError);

    await doc.dispose();
    await restored.dispose();
  });

  test('load rejects malformed documents with FormatException', () async {
    await expectLater(
      CadDocument.load(
        {'schemaVersion': 1, 'head': 5, 'ops': [], 'entities': []},
        FakeKernelBridge(),
      ),
      throwsFormatException,
    );
  });

  test('load rejects a document missing ops with FormatException', () async {
    await expectLater(
      CadDocument.load(
        {'schemaVersion': 1, 'head': 0, 'entities': []},
        FakeKernelBridge(),
      ),
      throwsFormatException,
    );
  });

  test('save() embeds geometry; load restores the kernel session', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final json = await doc.save();
    expect(json['geometry'], isNotNull);

    final restored = await CadDocument.load(json, FakeKernelBridge());
    // Kernel state restored: exportStep works for the stored body id.
    expect(await restored.exportStep([a]), isNotEmpty);
    await doc.dispose();
    await restored.dispose();
  });

  test('load without geometry but with ops throws StateError', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    await doc.makeBox(const Vec3(1, 1, 1));
    final json = CadDocumentCodec.encode(doc); // no geometry
    await expectLater(
      CadDocument.load(json, FakeKernelBridge()),
      throwsStateError,
    );
    await doc.dispose();
  });

  test('corrupt op entry is a FormatException with index context', () async {
    await expectLater(
      CadDocument.load({
        'schemaVersion': 1,
        'kernelVersion': 'x',
        'occtVersion': 'x',
        'head': 0,
        'ops': [42],
        'entities': <Object?>[],
      }, FakeKernelBridge()),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', contains('index 0'))),
    );
  });

  test('failed load disposes the created session (no leak)', () async {
    final bridge = FakeKernelBridge();
    await expectLater(
      CadDocument.load({
        'schemaVersion': 1,
        'kernelVersion': 'x',
        'occtVersion': 'x',
        'head': 0,
        'ops': [42],
        'entities': <Object?>[],
      }, bridge),
      throwsFormatException,
    );
    expect(bridge.liveSessionCount, 0);
  });
}
