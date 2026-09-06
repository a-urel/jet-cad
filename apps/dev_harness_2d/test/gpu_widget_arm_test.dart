import 'package:dev_harness_2d/gpu_arm.dart';
import 'package:dev_harness_2d/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  test('BACKEND parses residentGpu, and still refuses a typo', () {
    expect(parseBackend('residentGpu'), RenderBackend.residentGpu);
    expect(parseBackend('vertices'), RenderBackend.vertices);
    expect(parseBackend(''), isNull);
    expect(() => parseBackend('gpu'), throwsStateError);
  });

  test('four arms, four distinct labels, and D names the widget', () {
    expect(GpuSpikeArm.values, hasLength(4));
    expect(GpuSpikeArm.values.map((a) => a.label).toSet(), hasLength(4));
    expect(GpuSpikeArm.widget.label, contains('DraftCanvas'));
    expect(GpuSpikeArm.gpu.label, isNot(contains('DraftCanvas')));
  });

  test('fireDocumentTrigger emits the DocChange its name says', () async {
    final doc = spikeDocument(entityCount: 500, text: false);
    final probe = doc.handleSeed.next();
    final seen = <DocChange>[];
    final sub = doc.changes.listen(seen.add);
    addTearDown(sub.cancel);
    Future<Type> fire(String name) async {
      seen.clear();
      fireDocumentTrigger(doc, name, probe: probe);
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1), reason: name);
      return seen.single.runtimeType;
    }

    expect(await fire('CommandApplied'), CommandApplied);
    expect(await fire('CommandUndone'), CommandUndone);
    expect(await fire('CommandRedone'), CommandRedone);
    expect(await fire('DocumentLoaded'), DocumentLoaded);
    expect(await fire('DocumentPurged'), DocumentPurged);
    final before = doc.tables.mutationRevision;
    // `fire` clears at its start, not at its end, so the last one's
    // `DocumentPurged` is still in `seen` -- cleared here, or the
    // no-DocChange assertion below would only ever be reading that.
    seen.clear();
    fireDocumentTrigger(doc, 'tables', probe: probe);
    await Future<void>.delayed(Duration.zero);
    expect(doc.tables.mutationRevision, greaterThan(before));
    expect(seen, isEmpty, reason: 'a table edit emits no DocChange (spec)');
    expect(() => fireDocumentTrigger(doc, 'nonsense', probe: probe),
        throwsArgumentError);
  });

  test('the allocation budget is the enumerated exception set, generously', () {
    // A per-instance allocation on the measured corpus (~110,000 instances)
    // exceeds any P the corpus can have by orders of magnitude; the two
    // constants only have to be above the per-patch and fixed sets Plan E's
    // results note and the GPU shim's own per-pass objects add up to.
    expect(kAllocPerPatch, inInclusiveRange(12, 32));
    expect(kAllocFixed, inInclusiveRange(16, 64));
  });
}
