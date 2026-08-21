### Task 8: The flush observer

The rasterizer needs the triangles Impeller was given. `flush()` builds the
`Vertices`, submits it, disposes it and rewinds the buffer in one call, so a
test that runs after it finds nothing and one that runs before it has not
exercised the code under test.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`

**Interfaces:**
- Produces: `typedef FlushObserver = void Function(Float32List positions, Int32List colors);`
  and `VerticesDrawSink.observer`, consumed by Tasks 9 and 10.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`:

```dart
  test('the observer sees exactly what was submitted, before the rewind', () {
    // The rasterizer's seam. Reading the buffer after a flush finds it
    // rewound; reading it before finds work the flush has not yet done.
    //
    // MUTATION: hand the observer the whole buffer rather than the submitted
    // view and the length reads the capacity, 4096, instead of 12.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    late Float32List seenPositions;
    late Int32List seenColors;
    var calls = 0;

    final sink = _sink(canvas: canvas)
      ..observer = (positions, colors) {
        calls++;
        seenPositions = Float32List.fromList(positions);
        seenColors = Int32List.fromList(colors);
      }
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 0), 2, _style(argb: 0xFF112233), closed: false)
      ..endResidual();
    sink.flush();

    expect(calls, 1);
    expect(seenPositions.length, 12);
    expect(seenColors.length, 6);
    expect(seenColors[0].toUnsigned(32), 0xFF112233);
    // And the buffer really was rewound afterwards.
    expect(sink.debugPositions(), isEmpty);
    recorder.endRecording().dispose();
  });

  test('a flush with nothing batched does not call the observer', () {
    // MUTATION: call it unconditionally and a frame that drew nothing
    // rasterises an empty buffer over the previous one.
    var calls = 0;
    final recorder = PictureRecorder();
    _sink(canvas: Canvas(recorder))
      ..observer = ((_, __) => calls++)
      ..flush();
    expect(calls, 0);
    recorder.endRecording().dispose();
  });

  test('the observer fires once per flush, text included', () {
    // MUTATION: observe only the final flush and a fixture with text loses
    // every triangle drawn before the first text op.
    var calls = 0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)
      ..observer = ((_, __) => calls++)
      ..beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false);
    sink.text('x', ReservedHandles.standardTextStyle, _style());
    sink.polyline(_seg(0, 5, 10, 5), 2, _style(), closed: false);
    sink.endResidual();
    sink.flush();
    expect(calls, 2);
    recorder.endRecording().dispose();
  });
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Expected: `The setter 'observer' isn't defined for the type 'VerticesDrawSink'`.

- [ ] **Step 3: Implement**

In `vertices_draw_sink.dart`, above the class:

```dart
/// Handed the position and colour views a [VerticesDrawSink.flush] submitted,
/// before it rewinds the buffer.
///
/// The views are live over the sink's own storage and are valid only for the
/// duration of the call; an observer that keeps one must copy it.
typedef FlushObserver = void Function(Float32List positions, Int32List colors);
```

In the class, beside `canvas`:

```dart
  /// Watches every flush, or null.
  ///
  /// **Test seam, null in production.** `flush` submits, disposes and rewinds
  /// in one call, so there is no moment outside it at which the triangles
  /// Impeller was given can be read. The rasterizer in
  /// `test/support/triangle_rasterizer.dart` is the only caller.
  FlushObserver? observer;
```

and in `flush()`, immediately after `_lastFlushVertices = colors.length;`:

```dart
    observer?.call(positions, colors);
```

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

- [ ] **Step 5: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat: a flush observer, so a test can see what Impeller was given

flush() submits, disposes and rewinds in one call. Reading the buffer after it
finds nothing; reading it before finds work the flush has not done. The
observer is handed the submitted views at the one moment they mean something,
and is null in production."
```

---

