### Task 1: The dash seam on `DrawSink`

**Files:**
- Modify: `lib/src/draw_sink.dart`
- Modify: `lib/src/canvas_draw_sink.dart`
- Modify: `lib/src/vertices_draw_sink.dart`
- Modify: `lib/src/gpu/geometry_collector.dart` (declaration only — behaviour is Task 5)
- Modify: `test/support/text_key_sink.dart`
- Test: `test/draw_sink_test.dart` (create if absent)

**Interfaces:**
- Produces: `DrawSink.shadesDashes`, `DrawSink.beginDash(DashPattern, double)`,
  `DrawSink.endDash()`, `BeginDashOp`, `EndDashOp`, and
  `RecordingDrawSink({bool shadesDashes = false})`.
- Consumes: `DashPattern` from `package:jet_cad_2d` — already exported, already
  imported by `draw_sink.dart` through the barrel.

**The one design decision, so the implementer does not have to make it.**
`beginDash` takes **two** arguments, not three. `patternToLocal` converts
pattern units to the space the coordinates in the bracketed ops are in — which
is the residual's local space, by `DrawSink`'s own contract at the top of the
file. Everything else the collector needs it derives from the residual it
already holds. The two values are exactly the two the painter already computes
at its two dash sites, so nothing new is calculated anywhere:

- polylines: `_dashScale(style, toScreen)` — the points are already in screen
  space and the residual is a bare translation.
- circles and arcs: `style.linetypeScale * document.header.globalLinetypeScale`
  — the coordinates are in the leaf's own space and the residual carries the
  scale.

- [ ] **Step 1: Write the failing test**

Create `test/draw_sink_test.dart` (or append, if it exists):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  const pattern = DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);

  test('a recording sink defaults to not shading dashes, and says so by '
      'refusing the bracket rather than by ignoring it', () {
    final sink = RecordingDrawSink();
    expect(sink.shadesDashes, isFalse);
    expect(() => sink.beginDash(pattern, 2.5), throwsUnsupportedError);
    expect(() => sink.endDash(), throwsUnsupportedError);
  });

  test('a shading recording sink records the bracket with its scale', () {
    final sink = RecordingDrawSink(shadesDashes: true);
    expect(sink.shadesDashes, isTrue);
    sink.beginDash(pattern, 2.5);
    sink.endDash();
    expect(sink.ops, <DrawOp>[
      const BeginDashOp(pattern, 2.5),
      const EndDashOp(),
    ]);
  });

  test('the bracket ops compare by value, scale included', () {
    // The scale is part of `==` because the oracle asks whether two walks
    // dashed at the same rate, not merely whether both dashed.
    expect(const BeginDashOp(pattern, 2.5) == const BeginDashOp(pattern, 2.5),
        isTrue);
    expect(const BeginDashOp(pattern, 2.5) == const BeginDashOp(pattern, 2.6),
        isFalse);
  });

  test('every non-shading sink in this package refuses the bracket', () {
    final sinks = <DrawSink>[NullDrawSink(), RecordingDrawSink()];
    for (final sink in sinks) {
      expect(sink.shadesDashes, isFalse, reason: '$sink');
      expect(() => sink.beginDash(pattern, 1.0), throwsUnsupportedError,
          reason: '$sink');
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart
```
Expected: compile failure — `shadesDashes`, `beginDash`, `BeginDashOp` are
not defined.

- [ ] **Step 3: Add the three members to the interface**

In `lib/src/draw_sink.dart`, inside `abstract class DrawSink`, after
`endResidual()`:

```dart
  /// Whether this sink evaluates dash patterns itself.
  ///
  /// **False means "hand me the spans"; true means "hand me the geometry and
  /// the pattern".** `DraftPainter` reads this and takes one of two routes: a
  /// false sink is given the cut spans it has always been given, through
  /// ordinary [polyline] and [arc] calls; a true sink is given the *undashed*
  /// primitive, bracketed by [beginDash] and [endDash].
  ///
  /// **The information a span carries is strictly less than the pattern that
  /// produced it.** A two-point span has no cycle, no phase and no element
  /// index, so a sink that wants to decide dash coverage per fragment — at
  /// the live camera, rather than at whatever camera cut the spans — cannot
  /// recover what it needs from the span stream. That is the whole reason
  /// this getter exists rather than a sink simply doing something different
  /// with what it is given.
  bool get shadesDashes;

  /// Opens a dashed bracket. Every geometry op until [endDash] is dashed with
  /// [pattern].
  ///
  /// [patternToLocal] converts pattern units to the units the bracketed ops'
  /// coordinates are in — which is the residual's local space, by this
  /// interface's own contract above. It is `linetypeScale ×
  /// globalLinetypeScale` folded with whatever the caller has already applied
  /// to the coordinates: for a polyline the painter has already carried the
  /// points into screen space, so the factor includes the screen scale; for a
  /// curve the coordinates stay in the leaf's own space and it does not.
  ///
  /// **Only called on a sink whose [shadesDashes] is true.** Every other sink
  /// in this package throws here, deliberately: a wiring mistake that routed
  /// undashed geometry to a span-consuming sink would otherwise draw a solid
  /// line where the document says dashed, which is a picture nobody would
  /// question. A throw is loud; a solid line is not.
  void beginDash(DashPattern pattern, double patternToLocal);

  /// Closes the bracket opened by [beginDash].
  void endDash();
```

Add the ops beside the other `DrawOp` subclasses:

```dart
@immutable
final class BeginDashOp extends DrawOp {
  const BeginDashOp(this.pattern, this.patternToLocal);

  final DashPattern pattern;

  /// Part of `==` on purpose: two walks that dashed the same pattern at
  /// different rates drew different pictures, and an oracle that compared
  /// only the pattern would call them equal.
  final double patternToLocal;

  @override
  bool operator ==(Object other) =>
      other is BeginDashOp &&
      other.pattern == pattern &&
      other.patternToLocal == patternToLocal;

  @override
  int get hashCode => Object.hash(pattern, patternToLocal);

  @override
  String toString() => 'BeginDashOp($pattern, $patternToLocal)';
}

@immutable
final class EndDashOp extends DrawOp {
  const EndDashOp();

  @override
  bool operator ==(Object other) => other is EndDashOp;

  @override
  int get hashCode => (EndDashOp).hashCode;

  @override
  String toString() => 'EndDashOp()';
}
```

- [ ] **Step 4: Implement in all six sinks**

`RecordingDrawSink` — it gains a constructor it did not have. Existing
`RecordingDrawSink()` call sites keep compiling:

```dart
class RecordingDrawSink implements DrawSink {
  RecordingDrawSink({this.shadesDashes = false});

  /// **Defaults to false so this class stays the oracle it already is.**
  /// `draft_painter_test.dart` asserts span counts against a recording sink
  /// over a dashed fixture; flipping the default would change what those
  /// tests are looking at without changing a line of them.
  @override
  final bool shadesDashes;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) => shadesDashes
      ? _ops.add(BeginDashOp(pattern, patternToLocal))
      : throw UnsupportedError(
          'this RecordingDrawSink does not shade dashes; '
          'construct it with shadesDashes: true to record the bracket');

  @override
  void endDash() => shadesDashes
      ? _ops.add(const EndDashOp())
      : throw UnsupportedError(
          'this RecordingDrawSink does not shade dashes');
```

`NullDrawSink`, `CanvasDrawSink`, `VerticesDrawSink`, `TextKeySink` — all four
take the same shape:

```dart
  @override
  bool get shadesDashes => false;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) =>
      throw UnsupportedError(
          '<ClassName> consumes dash spans, not dash patterns; '
          'DraftPainter must not open a dash bracket on a sink whose '
          'shadesDashes is false');

  @override
  void endDash() => throw UnsupportedError('<ClassName> does not shade dashes');
```

`GeometryCollector` — **declaration only in this task.** `shadesDashes => true`,
and `beginDash`/`endDash` bodies that do nothing yet with a `// Task 5` comment.
It must compile and it must not change what the collector emits.

- [ ] **Step 5: Run the test and the suite**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart && flutter test
```
Expected: the new file passes; the rest of the suite is unchanged. The
collector now answers `true` to a question nobody asks yet.

- [ ] **Step 6: Gate and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze
cd ../.. && git status --short   # analysis_options.yaml must not be staged
git add packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test
git commit -m "feat(sink): a dash bracket, for a sink that shades rather than consumes spans"
```

---

