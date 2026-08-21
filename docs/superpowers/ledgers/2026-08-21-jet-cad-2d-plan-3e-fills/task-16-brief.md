## Task 16: The rig grows fills

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/lib/measurement_rig.dart`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`

**Interfaces:**
- Produces: `--dart-define=FILLS=true|false`, `fillCount` and `skippedFills` on the invariants line.

**A `String.fromEnvironment`, and it stays one.** Plan 3c lost a full device run to `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as false while printing entirely plausible numbers. Follow `kBackend`'s shape: a string, with an unrecognised value throwing at startup.

- [ ] **Step 1: Extend the corpus**

Fills go in behind the define, on the same corpus, so on/off is one flag apart
on one drawing — exactly as text does. A fraction of the corpus's closed
polylines gain a region partner; the fraction is a named constant beside
`kDashedFraction`.

- [ ] **Step 2: Print the counters**

`printInvariants` gains two fields, so a backend pair is still a comparison of
two renderers and not of two drawings:

```dart
void printInvariants(DraftPainter painter, CanvasDrawSink sink) {
  print('  screenSpaceLeafCount=${painter.screenSpaceLeafCount} '
      'dashSpans=${painter.dashSpanCount} '
      'collapsed=${painter.collapsedDashCount} '
      'canvasCalls=${sink.canvasCallCount}');
  print('  fills=${painter.fillCount} '
      'skippedFills=${painter.skippedFillCount}');
}
```

- [ ] **Step 3: Extend the allocation gate**

`paint_allocation_test.dart` runs its two-flush comparison on a corpus
**containing fills**. The steady-state requirement is unchanged: **zero
allocations per fill**. A cache hit returns the stored `Int32List` by
reference, so a hit allocates nothing; a *miss* on the frame path would show up
here immediately, which is a second gate on "populated eagerly, never lazily".

- [ ] **Step 4: Measure, on the device**

```sh
cd apps/dev_harness_2d
# check first, and record it: pmset -g | grep lowpowermode
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=RIG=pan --dart-define=ENTITIES=10000 \
  --dart-define=BACKEND=vertices --dart-define=FILLS=true
```

Six runs: `{10000, 50000} × {canvas, vertices}` with `FILLS=true`, plus
`{10000} × {canvas, vertices}` with `FILLS=false` for the delta.

**After every `flutter drive`:** `git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`.

- [ ] **Step 5: Measure the load cost**

The one row eager materialisation owes:

```dart
test('load-time triangulation cost, recorded', () {
  final json = jsonEncode(JsonCodec.save(fillHeavyCorpus()));
  final sw = Stopwatch()..start();
  JsonCodec.load(jsonDecode(json) as Map<String, Object?>);
  // ignore: avoid_print
  print('LOAD fills=$n elapsed=${sw.elapsedMilliseconds}ms');
});
```

No threshold — but no plan may skip the row.

- [ ] **Step 6: Commit**

```bash
git status --porcelain   # project.pbxproj must NOT appear
git add apps/dev_harness_2d packages/jet_cad_2d_flutter/test/invariants
git commit -m "test: the rig corpus grows fills, behind a define"
```

---

