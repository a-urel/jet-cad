// `SPIKE_FILL_SCALE` -- the knob that makes Plan D's fills large enough for a
// human to judge.
//
// **Why a knob rather than a bigger corpus.** At the measurement corpus's own
// room size a fill lands on screen at 0.7 to 2.7 logical pixels (a 60,000 x
// 40,000 unit floor fitted into a 1400 x 900 window is 0.0225 px/unit, and a
// room is 30-120 units wide), so Plan D's five window checks cannot be made
// against it at all. Growing the rooms permanently would put a different
// drawing under every number already recorded in
// `docs/superpowers/notes/2026-09-01-plan-d-results.md`; a scale that is
// inert at its default keeps the measured corpus and the viewable one the
// same drawing at two sizes.
//
// The two tests below are the two halves of that claim: the default changes
// nothing, and the scale changes size and nothing else.

import 'package:dev_harness_2d/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// Small enough to keep the test quick, large enough that
/// `_addFillRegions`'s `max(200, entityCount ~/ 100)` gives its floor of 200
/// rooms -- so the lists compared below are never empty.
const int _kEntities = 2000;

/// One room's width and height, read back out of its boundary polygon.
class _Room {
  const _Room(this.width, this.height);
  final double width;
  final double height;
}

/// Every filled room in [doc], in handle order.
///
/// Reads the **boundary** of each `EntityKind.fill`, which is where
/// `_addFillRegions` puts the rectangle: the fill record itself carries no
/// geometry of its own, only the boundary's handle. The rectangle is written
/// as five points with the first repeated at the end, so the width is the
/// span between points 0 and 1 and the height the span between points 1 and
/// 2 -- and reading it back this way, rather than trusting the generator's
/// own local variables, is what makes this a measurement of the document
/// rather than a restatement of the code that built it.
List<_Room> _rooms(DraftDocument doc) {
  final rooms = <_Room>[];
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) != EntityKind.fill) continue;
    final payload = doc.geometry.peek(doc.entities.geomIndexAt(slot));
    final boundarySlot = doc.entities.slotOf(boundaryHandleOf(payload));
    if (boundarySlot == null) continue;
    final coords =
        doc.geometry.peek(doc.entities.geomIndexAt(boundarySlot)).coords;
    rooms.add(_Room(coords[2] - coords[0], coords[5] - coords[3]));
  }
  return rooms;
}

void main() {
  test('the default scale leaves the measured corpus exactly as it was', () {
    // Exact `==`, not a tolerance: these are stored values, and the claim is
    // that passing the default explicitly and not passing it at all produce
    // the same bytes. A default that had drifted off 1.0 shows up here as a
    // whole-list mismatch rather than as a number nobody reads.
    final byDefault =
        _rooms(spikeDocument(entityCount: _kEntities, fillsEnabled: true));
    final explicitOne = _rooms(spikeDocument(
        entityCount: _kEntities, fillsEnabled: true, fillScale: 1.0));

    expect(byDefault, isNotEmpty,
        reason: 'a corpus with no filled rooms would make both tests in this '
            'file vacuous');
    expect(byDefault.length, explicitOne.length);
    for (var i = 0; i < byDefault.length; i++) {
      expect(byDefault[i].width, explicitOne[i].width, reason: 'room $i');
      expect(byDefault[i].height, explicitOne[i].height, reason: 'room $i');
    }
  });

  test('the scale multiplies room size, and only size', () {
    const scale = 20.0;
    final small = _rooms(spikeDocument(
        entityCount: _kEntities, fillsEnabled: true, fillScale: 1.0));
    final large = _rooms(spikeDocument(
        entityCount: _kEntities, fillsEnabled: true, fillScale: scale));

    // The room COUNT is not a function of the scale. A scale wired into
    // `roomCount` instead of into `w`/`h` would draw a different corpus, not
    // the same corpus larger.
    expect(large.length, small.length,
        reason: 'the scale changes how big a room is, never how many there '
            'are');

    // Both dimensions, separately: a scale applied to `w` alone leaves every
    // room a stretched sliver and passes a width-only assertion.
    for (var i = 0; i < small.length; i++) {
      expect(large[i].width, closeTo(small[i].width * scale, 1e-6),
          reason: 'room $i width');
      expect(large[i].height, closeTo(small[i].height * scale, 1e-6),
          reason: 'room $i height');
    }

    // Non-degenerate, so the loop above is not comparing zeros to zeros --
    // this file's own guard against the failure mode `CLAUDE.md` names.
    expect(small.first.width, greaterThan(0));
    expect(small.first.height, greaterThan(0));
  });
}
