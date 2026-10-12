// Rubber-band spec RB-6, Task 1: the shared band painter and its direction
// rule. M-BP1/M-BP2 (the rule), M-RB18 (the stroke by mode), M-BP3 (no state
// between calls).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/canvas_palette.dart';
import 'package:jet_cad_2d_flutter/src/selection_band.dart';
import 'package:jet_cad_2d_flutter/src/selection_style.dart';

import 'support/spy_canvas.dart';

const Rect _rect = Rect.fromLTRB(312.5, 41.25, 518.75, 97.5);

int _argb(RecordedCall c) => c.color!.toARGB32();

int _fillOf(int stroke) => (stroke & 0xFFFFFF) | (kBandFillAlpha << 24);

void main() {
  test('BP1: left to right is a window, right to left a crossing', () {
    expect(bandModeFor(const Offset(310, 40), const Offset(520, 90)),
        BandMode.window);
    expect(bandModeFor(const Offset(520, 90), const Offset(310, 40)),
        BandMode.crossing);
    // Equal x is a window (>=), whatever y does.
    expect(bandModeFor(const Offset(310, 40), const Offset(310, 90)),
        BandMode.window);
    expect(bandModeFor(const Offset(310, 90), const Offset(310, 40)),
        BandMode.window);
    // A hair to the left is a crossing even when the drag is mostly vertical.
    expect(bandModeFor(const Offset(310, 90), const Offset(309.5, 40)),
        BandMode.crossing);
    // Only x decides: a drag up and to the right is still a window.
    expect(bandModeFor(const Offset(310, 90), const Offset(520, 40)),
        BandMode.window);
  });

  test(
      'BP2: a window is a fill and a solid 1 px outline; a crossing a fill '
      'and dashes', () {
    final painter = SelectionBandPainter();

    final window = SpyCanvas();
    painter.paint(window, _rect, BandMode.window, PaperPalette.light);
    final rects = window.named('drawRect').toList();
    expect(window.calls, hasLength(2));
    expect(rects, hasLength(2));
    expect(rects[0].args.first, _rect);
    expect(rects[1].args.first, _rect);
    expect(_argb(rects[0]), _fillOf(0xFF1E6FE8));
    expect(rects[1].paintingStyle, PaintingStyle.stroke);
    expect(_argb(rects[1]), 0xFF1E6FE8);
    expect(rects[1].strokeWidth, 1.0);

    final crossing = SpyCanvas();
    painter.paint(crossing, _rect, BandMode.crossing, PaperPalette.light);
    expect(crossing.calls, hasLength(2));
    final fill = crossing.named('drawRect').single;
    expect(fill.args.first, _rect);
    expect(_argb(fill), _fillOf(0xFF2E9E5B));
    final dashes = crossing.named('drawPath').single;
    expect(dashes.paintingStyle, PaintingStyle.stroke);
    expect(_argb(dashes), 0xFF2E9E5B);
    expect(dashes.strokeWidth, 1.0);

    final path = dashes.args.first! as Path;
    final bounds = path.getBounds();
    expect(bounds.left, closeTo(_rect.left, 1e-9));
    expect(bounds.top, closeTo(_rect.top, 1e-9));
    expect(bounds.right, closeTo(_rect.right, 1e-9));
    expect(bounds.bottom, closeTo(_rect.bottom, 1e-9));
    // The first dash starts at the top-left corner and runs 6 px right.
    final first = path.computeMetrics().first;
    expect(first.length, closeTo(6.0, 1e-9));
    final from = first.getTangentForOffset(0)!.position;
    final to = first.getTangentForOffset(first.length)!.position;
    expect(from.dx, closeTo(_rect.left, 1e-9));
    expect(from.dy, closeTo(_rect.top, 1e-9));
    expect(to.dx, closeTo(_rect.left + 6, 1e-9));
    expect(to.dy, closeTo(_rect.top, 1e-9));
  });

  test('BP3: no state leaks between calls of one painter', () {
    final painter = SelectionBandPainter();
    final a = SpyCanvas(), b = SpyCanvas(), c = SpyCanvas();
    painter.paint(a, _rect, BandMode.window, PaperPalette.light);
    painter.paint(b, _rect, BandMode.crossing, PaperPalette.light);
    painter.paint(c, _rect, BandMode.window, PaperPalette.light);
    expect(c.calls, hasLength(a.calls.length));
    for (var i = 0; i < a.calls.length; i++) {
      expect(c.calls[i].name, a.calls[i].name, reason: 'call $i');
      expect(c.calls[i].color, a.calls[i].color, reason: 'call $i colour');
      expect(c.calls[i].paintingStyle, a.calls[i].paintingStyle,
          reason: 'call $i style');
      expect(c.calls[i].strokeWidth, a.calls[i].strokeWidth,
          reason: 'call $i width');
    }
    // The crossing in between was the crossing's: its dashes, its colour.
    expect(b.named('drawPath'), hasLength(1));
    expect(_argb(b.named('drawPath').single), 0xFF2E9E5B);
    // A second crossing draws the same dashes, not the first's plus its own.
    final d = SpyCanvas();
    painter.paint(d, _rect, BandMode.crossing, PaperPalette.light);
    int contours(SpyCanvas s) =>
        (s.named('drawPath').single.args.first! as Path)
            .computeMetrics()
            .length;
    expect(contours(d), contours(b));
  });
}
