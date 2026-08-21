### Task 2: Dispose the submitted `Vertices`

`Vertices` extends `NativeFieldWrapperClass1` and carries a real `dispose()`
over the native symbol `Vertices::dispose`. `flush()` builds one per flush and
drops it. At 19 flushes a frame and 60 frames a second that is about 1,140
undisposed native-backed objects a second, each holding the frame's position
and colour buffers, reclaimed only when a finalizer runs.

**The open question is settled by test, not by reading:** may a `Vertices` be
disposed immediately after the `drawVertices` that submitted it, or does the
recorded output still refer to it? Step 1 asks a `PictureRecorder`; step 7 asks
a real device, because a recorder may retain what a rasterisation does not.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`

**Interfaces:**
- Consumes: `VerticesDrawSink.flush()` from the spike.
- Produces: `bool VerticesDrawSink.lastFlushDisposed` — whether the last
  submitted `Vertices` was disposed, so a test can assert it without holding
  the object.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`,
inside `main()`:

```dart
  test('the submitted Vertices is disposed, and the picture still records', () {
    // `Vertices` is native-backed: `dispose()` frees the position and colour
    // buffers the engine holds, and dropping the object instead leaves them to
    // a finalizer. At 19 flushes a frame that is about 1,140 a second.
    //
    // MUTATION: drop the dispose call and `lastFlushDisposed` reads false.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)..beginResidual(Transform2.identity());
    for (var i = 0; i < 5; i++) {
      sink.polyline(_seg(0, i * 1.0, 10, i * 1.0), 2, _style(), closed: false);
    }
    sink.endResidual();
    sink.flush();

    expect(sink.lastFlushDisposed, isTrue);
    // The recording must survive the dispose. If `drawVertices` had kept a
    // live reference rather than copying, this throws.
    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    expect(picture, isNotNull);
  });

  test('a flush with nothing batched disposes nothing', () {
    // MUTATION: dispose unconditionally and this throws on a null.
    final recorder = PictureRecorder();
    final sink = _sink(canvas: Canvas(recorder));
    sink.flush();
    expect(sink.flushCallCount, 0);
    expect(sink.lastFlushDisposed, isFalse);
    recorder.endRecording().dispose();
  });
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Expected: `The getter 'lastFlushDisposed' isn't defined for the type
'VerticesDrawSink'`.

- [ ] **Step 3: Implement**

In `vertices_draw_sink.dart`, add the field beside the other flush counters:

```dart
  bool _lastFlushDisposed = false;
```

and the accessor beside `lastFlushVertexCount`:

```dart
  /// Whether the last [flush] disposed the `Vertices` it submitted.
  ///
  /// Exposed rather than the object itself, because the object is gone by the
  /// time anything could read it — which is the point.
  bool get lastFlushDisposed => _lastFlushDisposed;
```

In `flush()`, set it false on entry beside `_flushCalls = 0;`, then replace the
submission with:

```dart
    final vertices = Vertices.raw(
      VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(vertices, BlendMode.dst, _paint);
    // `drawVertices` has taken what it needs by the time it returns; holding
    // the object past that point holds native buffers the engine has already
    // copied. Verified against a `PictureRecorder` here and on a device in
    // Plan 3d Task 2 step 7.
    vertices.dispose();
    _lastFlushDisposed = true;
```

(The `_paint` field arrives in Task 3; until then leave the inline
`Paint()..color = const Color(0xFFFFFFFF)` exactly as the spike has it.)

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Expected: 26 tests pass.

**If the recording throws instead**, the answer to the open question is "no".
Do not force it. Change the implementation to hold the previous flush's
`Vertices` in a field and dispose it at the *start* of the next flush, keep
`lastFlushDisposed` meaning "the previous one was disposed", adjust the two
tests to match, and record the finding in the task's commit message. One frame
of native memory outstanding is the cost; 1,140 a second is not.

- [ ] **Step 5: Run both suites green**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart
git commit -m "fix: dispose the Vertices each flush submits

`Vertices` is native-backed and carries a real `dispose()` over
`Vertices::dispose`. The spike built one per flush and dropped it: about 1,140
undisposed objects a second at 60 fps, each holding that frame's position and
colour buffers until a finalizer ran.

Whether it may be disposed at submission was an open question in the design and
is now answered by test rather than by reading."
```

- [ ] **Step 7: Verify on a device, not only in a recorder**

A `PictureRecorder` may retain what a real rasterisation does not, so the
recorder test is necessary and not sufficient.

```sh
cd apps/dev_harness_2d
flutter run --profile -d macos --dart-define=TEXT=true --dart-define=ENTITIES=10000
```

Pan and zoom for about thirty seconds. Expected: the drawing renders, no crash,
no blank frames. Then quit, and **revert the CocoaPods rewrite**:

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
git status --porcelain   # must be clean
```

Record what you saw in the task's report. A crash or a blank frame here means
the recorder answered a different question from the rasteriser, and the "hold
one frame" fallback in step 4 applies.

---

