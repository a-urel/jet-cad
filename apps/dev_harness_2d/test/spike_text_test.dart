import 'package:dev_harness_2d/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const int _kEntities = 2000;

int _textCount(DraftDocument doc) {
  var n = 0;
  for (final slot in doc.entities.liveSlots) {
    final k = doc.entities.kindAt(slot);
    if (k == EntityKind.text || k == EntityKind.attrib) n++;
  }
  return n;
}

/// Whether [doc] carries one of [_addPatchedLabels]'s own labels -- the
/// `'ROOM $n'` text `generateDocument`'s plain floor texts never produce
/// (they carry the empty string; see `_addFloorText`) and its vocabulary
/// labels never produce either (`_kLabelVocabulary` in
/// `generate_document.dart` has no `'ROOM'` entry).
bool _hasPatchedLabel(DraftDocument doc) {
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) != EntityKind.text) continue;
    if (doc.entities.textAt(slot).startsWith('ROOM ')) return true;
  }
  return false;
}

void main() {
  test('SPIKE_TEXT is inert at its default', () {
    // Not a literal `0`: `generateDocument`'s root-level content carries a
    // small baseline of plain, contentless floor texts unconditionally --
    // `textCount = math.min(300, rootEntityCount ~/ 100)` was the whole
    // formula before `labelFraction` ever existed, and turning `labelFraction`
    // off (which `text: false`/the default both do) "reduces to the original
    // formula exactly" (that function's own doc comment) rather than to zero.
    // Measured directly: `spikeDocument(entityCount: 2000)` carries 16 such
    // texts regardless of `SPIKE_TEXT`, `kSpikeDefs` and `kSpikeInstances`
    // being what they are. What "inert at its default" actually means here,
    // and what `spike_fill_scale_test.dart`'s own default-vs-explicit pattern
    // already tests for `SPIKE_FILL_SCALE`, is that asking for the default
    // two different ways gives the same document, and that neither carries
    // any of [_addPatchedLabels]'s own labels or the vocabulary/attribute
    // extensions `withText` gates.
    final byDefault = spikeDocument(entityCount: _kEntities);
    final explicitFalse = spikeDocument(entityCount: _kEntities, text: false);
    expect(_textCount(byDefault), _textCount(explicitFalse));
    expect(_hasPatchedLabel(byDefault), isFalse);
    expect(_hasPatchedLabel(explicitFalse), isFalse);
  });

  test('with text on, the corpus carries labels, and some are patched', () {
    final doc = spikeDocument(entityCount: _kEntities, text: true);
    expect(_textCount(doc), greaterThan(0));
    // Collect at the fitted camera and classify, exactly as the arm does:
    // the deliberate patched labels must be patches, or criterion 11 has
    // nothing to measure.
    final index = SpatialIndex(doc);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final collector = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        devicePixelRatio: 1.0,
        measurer: harnessMeasurer,
        textStyleOf: doc.textStyleOf);
    final camera = ViewportTransform.fit(doc.extents, kMeasurementViewport);
    painter.paint(collector, camera, kMeasurementViewport);
    final patches = classifyTextPatches(
        collector.data, collector.instanceCount, collector.texts,
        devicePixelRatio: 1.0);
    expect(collector.skippedOps, 0, reason: 'text is drawn now');
    expect(patches.length, greaterThanOrEqualTo(kPatchedLabelCount),
        reason: 'every deliberate patched label is a patch');
    index.dispose();
  });
}
