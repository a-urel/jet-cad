### Task 8: The harness — arm D, the trigger phases, the band exit, and the allocation probe

**Files:**
- Modify: `apps/dev_harness_2d/pubspec.yaml`
- Create: `apps/dev_harness_2d/lib/allocation_probe.dart`
- Modify: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `.vscode/launch.json`
- Test: `apps/dev_harness_2d/test/gpu_widget_arm_test.dart`

**Interfaces:**
- Consumes: `DraftCanvas(backend: RenderBackend.residentGpu)`,
  `DraftCanvasState.resident`, `ResidentRebuilder`'s counters,
  `GpuDrawBackend.frames`/`patchesRendered`, `FrameTimingLog`, `pumpFrame`,
  `gpuReport`, `gpuStats`.
- Produces: `GpuSpikeArm.widget`, `parseBackend`, `fireDocumentTrigger`,
  `AllocationProbe`, `kAllocFixed`, `kAllocPerPatch`, the GSPIKE lines Task 10
  reads.

- [ ] **Step 1: `vm_service`, and `BACKEND=residentGpu`**

`apps/dev_harness_2d/pubspec.yaml`, under `dependencies:`:

```yaml
  vm_service: ^15.2.0
```

then `flutter pub get` **and `git checkout -- '**/analysis_options.yaml'`**
before anything is staged.

`main.dart`: replace the `kBackend` switch with

```dart
/// `BACKEND=canvas|vertices|residentGpu`, or unset for the platform default.
/// A function so a test can check the parse without a `--dart-define`.
RenderBackend? parseBackend(String value) => switch (value) {
      '' => null,
      'canvas' => RenderBackend.canvas,
      'vertices' => RenderBackend.vertices,
      'residentGpu' => RenderBackend.residentGpu,
      final other => throw StateError(
          'BACKEND must be canvas, vertices, residentGpu or unset; got "$other"'),
    };

final RenderBackend? kBackend =
    parseBackend(const String.fromEnvironment('BACKEND', defaultValue: ''));
```

keeping the doc comment above it.

- [ ] **Step 2: Write the failing harness tests**

`apps/dev_harness_2d/test/gpu_widget_arm_test.dart`:

```dart
import 'dart:async';

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
```

- [ ] **Step 3: Run to verify they fail**

Run: `cd apps/dev_harness_2d && flutter test --concurrency=1 test/gpu_widget_arm_test.dart`
Expected: FAIL — `GpuSpikeArm.widget`, `fireDocumentTrigger`, `kAllocPerPatch` undefined.

- [ ] **Step 4: The probe**

`apps/dev_harness_2d/lib/allocation_probe.dart`:

```dart
// The frame-path allocation instrument the spec's invariant 1 calls a "new
// mechanism" (Ruling F8). `flutter test` cannot host one --
// `flutter_tester` launches with `--disable-vm-service` (STATUS, Plan 3g) --
// but a `flutter run --profile` process serves the VM service for DevTools,
// and this connects to its own isolate the way
// `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart` does under
// `dart test`, with `Service.getInfo()` first because the server is already
// up here.
import 'dart:developer' as dev;
import 'dart:isolate' as iso;

import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart' as vms_io;

/// Library URIs whose classes the report counts: this project's own frame
/// path, the two `dart:` libraries its per-frame objects live in, and the
/// GPU shim's per-pass objects, reported beside ours.
const List<String> kProbedLibraryPrefixes = <String>[
  'package:jet_cad_2d_flutter/',
  'dart:ui',
  'dart:typed_data',
  'package:flutter_gpu/',
  'package:flutter_scene/',
];

class AllocationProbe {
  AllocationProbe._(this._service, this._isolateId);
  final vms.VmService _service;
  final String _isolateId;

  /// Connects to this process's VM service. Throws with the reason when the
  /// service is not serving; the caller reports UNEVALUABLE, never a number.
  static Future<AllocationProbe> connect() async {
    var info = await dev.Service.getInfo();
    if (info.serverUri == null) {
      info = await dev.Service.controlWebServer(enable: true);
    }
    final http = info.serverUri;
    if (http == null) {
      throw StateError('the VM service is not serving (Service.getInfo and '
          'controlWebServer gave no URI) -- is this a --profile run?');
    }
    final ws = http.replace(
        scheme: 'ws', path: http.path.endsWith('/') ? '${http.path}ws' : '${http.path}/ws');
    final service = await vms_io.vmServiceConnectUri(ws.toString());
    final isolateId = dev.Service.getIsolateId(iso.Isolate.current);
    if (isolateId == null) {
      await service.dispose();
      throw StateError('Service.getIsolateId(Isolate.current) is null');
    }
    // The first RPC proves the connection; a refused one throws here, not
    // in the middle of a measurement.
    await service.getAllocationProfile(isolateId);
    return AllocationProbe._(service, isolateId);
  }

  /// Two RPCs, not one -- the meter's own finding: `gc: true` and `reset:
  /// true` on one call left the accumulators non-zero.
  Future<void> reset() async {
    await _service.getAllocationProfile(_isolateId, gc: true);
    await _service.getAllocationProfile(_isolateId, reset: true);
  }

  /// `instancesAccumulated` since [reset], per class, for the probed
  /// libraries. Keys are `<library uri> <class name>`.
  Future<Map<String, int>> read() async {
    final profile = await _service.getAllocationProfile(_isolateId);
    final out = <String, int>{};
    for (final m in profile.members ?? const <vms.ClassHeapStats>[]) {
      final cls = m.classRef;
      if (cls == null) continue;
      final lib = cls.library?.uri ?? '';
      if (!kProbedLibraryPrefixes.any(lib.startsWith)) continue;
      final n = m.instancesAccumulated ?? 0;
      if (n == 0) continue;
      out['$lib ${cls.name}'] = n;
    }
    return out;
  }

  Future<void> dispose() => _service.dispose();
}
```

- [ ] **Step 5: Arm D, the triggers, the band exit, the probe phase**

In `apps/dev_harness_2d/lib/gpu_arm.dart`:

**The enum** gains a fourth value after `gpu`:

```dart
  /// `DraftCanvas(backend: RenderBackend.residentGpu)`: the same backend as
  /// arm C, reached through the widget path Plan F wired -- collected over
  /// the extents at the live scale, rebuilt on the five triggers. Arm C
  /// stays as the control (Ruling F9); a widget-path regression shows as a
  /// C-to-D gap, not as a mystery.
  widget;
```

with `GpuSpikeArm.widget => 'D residentGpu (DraftCanvas)'` in `label`.

**The budget constants**, top level:

```dart
/// Criterion 5's gate (Ruling F8): per-frame allocations on arm D's pan
/// phase, `<= kAllocFixed + kAllocPerPatch * P`. The per-patch set the spec's
/// exception enumerates -- `PatchImage`, three `Rect`s, the `asImage()`
/// handle, plus the GPU shim's own `Viewport`, `Vector4`, two `BufferView`s,
/// a command buffer and a render pass -- is under twelve; the fixed set --
/// `composeTransforms` twice, the main image and its two `Rect`s, the main
/// pass's shim objects -- is under twenty. Both doubled: a per-INSTANCE
/// allocation is ~110,000 per frame on the measured corpus and no slack
/// here can hide it.
const int kAllocFixed = 40;
const int kAllocPerPatch = 24;
```

**`GpuSpikeState`** gains:

```dart
  /// Arm D's canvas, so the rig can read its rebuilder.
  final GlobalKey<DraftCanvasState> widgetKey = GlobalKey<DraftCanvasState>();

  /// Non-null while the rig is exercising the `devicePixelRatio` trigger:
  /// arm D's `MediaQuery` reports this ratio instead of the window's.
  final ValueNotifier<double?> dprOverride = ValueNotifier<double?>(null);

  ResidentRebuilder? get widgetRebuilder => widgetKey.currentState?.resident;

  /// The `GpuDrawBackend` an arm draws through, or null: arm C's is
  /// [backend]; arm D's is its rebuilder's, once landed; A and B have none.
  GpuDrawBackend? backendOf(GpuSpikeArm a) => switch (a) {
        GpuSpikeArm.gpu => backend,
        GpuSpikeArm.widget => widgetRebuilder?.backend as GpuDrawBackend?,
        _ => null,
      };
```

`dispose()` adds `dprOverride.dispose();`. The `Stack` gains, after arm C's
`Positioned.fill`:

```dart
                    Offstage(
                      offstage: a != GpuSpikeArm.widget,
                      child: ValueListenableBuilder<double?>(
                        valueListenable: dprOverride,
                        builder: (context, dpr, _) {
                          final data = MediaQuery.of(context);
                          return MediaQuery(
                            data: dpr == null
                                ? data
                                : data.copyWith(devicePixelRatio: dpr),
                            child: DraftCanvas(
                              key: widgetKey,
                              document: widget.document,
                              index: index,
                              camera: camera,
                              lineweightScale: widget.lineweightScale,
                              drawText: widget.drawText,
                              backend: RenderBackend.residentGpu,
                              tiles: false,
                            ),
                          );
                        },
                      ),
                    ),
```

An `Offstage` canvas is laid out and never painted, so arm D's first
`noteFrame` -- and its first rebuild -- happens when the rig switches to it.

**`fireDocumentTrigger`**, top level, GPU-free and tested:

```dart
/// Fires one of the document-side triggers by name. `probe` is the handle
/// the `CommandApplied` line is added under (and undone, and redone); the
/// caller allocates it once from `doc.handleSeed`.
void fireDocumentTrigger(DraftDocument doc, String name, {required Handle probe}) {
  switch (name) {
    case 'CommandApplied':
      final cx = kDefaultOriginX + kFloorWidth / 2;
      final cy = kOriginY + kFloorHeight / 2;
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: probe,
          owner: doc.rootHandle,
          kind: EntityKind.line,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: 100,
          transparency: 0,
          flags: 0,
        ),
        payload: GeometryPayload(
            coords: Float64List.fromList(
                [cx - 8000, cy - 5000, cx + 8000, cy + 5000]),
            scalars: Float64List(0)),
      ));
    case 'CommandUndone':
      doc.commands.undo();
    case 'CommandRedone':
      doc.commands.redo();
    case 'DocumentLoaded':
      doc.commands.notifyLoaded();
    case 'DocumentPurged':
      doc.purge();
    case 'tables':
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;
      final next = zero.color is IndexedColor && (zero.color as IndexedColor).aci == 1 ? 2 : 1;
      doc.tables.layers.remove(zero.handle);
      doc.tables.layers.add(LayerRecord(
          handle: zero.handle,
          name: zero.name,
          color: IndexedColor(next),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: zero.visible,
          locked: zero.locked));
    default:
      throw ArgumentError.value(name, 'name', 'not a document trigger');
  }
}
```

(`kDefaultOriginX`, `kOriginY`, `kFloorWidth`, `kFloorHeight` are the
constants `_addPatchedLabels` in `main.dart` already reads; import
`main.dart` if `gpu_arm.dart` does not already, and `dart:typed_data`.)

**`runGpuSpike`** changes:

`setArm` gains, before its `painted=0` check:

```dart
    if (a == GpuSpikeArm.widget) {
      // Arm D rebuilds on its first painted frame; nothing it draws before
      // the landing is the resident backend. Wait for it, bounded, and refuse
      // to measure a canvas that fell back.
      var frames = 0;
      while ((state.widgetRebuilder?.landed ?? 0) == 0 && frames < 300) {
        await pumpFrame();
        frames++;
      }
      final r = state.widgetRebuilder;
      if (r == null || r.landed == 0) {
        throw StateError('GSPIKE ${a.label}: no rebuild landed in $frames '
            'frames -- the widget path is not wired, or the upload hangs.');
      }
      if (r.uploadFailed) {
        throw StateError('GSPIKE ${a.label}: the upload failed and the canvas '
            'fell back to vertices; every number it would post is arm A\'s.');
      }
      gpuReport('GSPIKE ${a.label}: first rebuild landed after $frames '
          'frame(s) -- walk ${(r.lastWalkMicros / 1000).toStringAsFixed(1)} '
          'classify ${(r.lastClassifyMicros / 1000).toStringAsFixed(1)} '
          'upload ${(r.lastUploadMicros / 1000).toStringAsFixed(1)} '
          'total ${(r.lastTotalMicros / 1000).toStringAsFixed(1)} ms (COLD: '
          'the first GPU call of the process pays pipeline creation)');
    }
```

and its `painted=0` check reads `state.backendOf(a)?.frames ?? 0` before and
after, for both `gpu` and `widget`. `phase()` reads `state.backendOf(a)` where
it read `state.backend`. The arms loop already iterates `GpuSpikeArm.values`,
so D's `hold`/`pan`/`zoom` come for free; the per-repeat report loop's `if
(rep.arm == GpuSpikeArm.gpu)` becomes `if (rep.arm == GpuSpikeArm.gpu ||
rep.arm == GpuSpikeArm.widget)`, and `GpuSpikeArm.values.length * 3` already
counts four arms.

**The trigger phase**, run once per repeat after the arms loop, on arm D:

```dart
  /// The trigger names, in the order the spec's table lists them, the dpr
  /// pair and the band pair last. `probe` is allocated once per run.
  const triggers = <String>[
    'CommandApplied', 'CommandUndone', 'CommandRedone',
    'DocumentLoaded', 'DocumentPurged', 'tables',
    'devicePixelRatio', 'devicePixelRatio back',
    'band out', 'band back',
  ];
  final probe = state.widget.document.handleSeed.next();
  final baseDpr = MediaQuery.devicePixelRatioOf(state.context);

  Future<void> rebuildPhase(int repeat) async {
    await setArm(GpuSpikeArm.widget);
    state.camera.value = baseCamera;
    await pumpFrame();
    final r = state.widgetRebuilder!;
    for (final name in triggers) {
      final before = r.landed;
      switch (name) {
        case 'devicePixelRatio':
          state.dprOverride.value = baseDpr + 1;
        case 'devicePixelRatio back':
          state.dprOverride.value = null;
        case 'band out':
          state.camera.zoomAt(centre, 2.5);
        case 'band back':
          state.camera.zoomAt(centre, 1 / 2.5);
        default:
          fireDocumentTrigger(state.widget.document, name, probe: probe);
      }
      var frames = 0;
      while (r.landed == before && frames < 300) {
        await pumpFrame();
        frames++;
      }
      if (r.landed == before) {
        throw StateError('GSPIKE D rebuild | $name | no rebuild landed in '
            '$frames frames');
      }
      final c = r.collection!;
      gpuReport('GSPIKE D rebuild | r${repeat + 1} | $name | '
          'trigger=${r.lastTrigger!.name} '
          'walk ${(r.lastWalkMicros / 1000).toStringAsFixed(2)} '
          'classify ${(r.lastClassifyMicros / 1000).toStringAsFixed(2)} '
          'upload ${(r.lastUploadMicros / 1000).toStringAsFixed(2)} '
          'total ${(r.lastTotalMicros / 1000).toStringAsFixed(2)} ms | '
          'landed after $frames frame(s) | instances=${c.instanceCount} '
          'patches=${c.patches.length} '
          'buffer=${(c.byteLength / (1024 * 1024)).toStringAsFixed(2)} MB');
    }
  }
```

called as `await rebuildPhase(r);` at the end of each repeat's loop body
(after the report lines). **`band out` at 2.5×** collects at 2.5× the fit
scale, so its `instances` and `buffer` line is the first measurement of
criterion 6 at a rebuilt scale; `band back` returns to the base camera and
the collection follows.

**The band-exit phase**, once, after the repeats:

```dart
  await setArm(GpuSpikeArm.widget);
  {
    final r = state.widgetRebuilder!;
    state.camera.value = baseCamera;
    await pumpFrame();
    await pumpFrame();
    r.bandStaleFrames = 0;
    final landedBefore = r.landed;
    // 40 steps of 1.02 leave [0.5, 2.0] at step 36 (1.02^36 = 2.04); the
    // frames from that step to the landing are criterion 9's stale interval.
    final rep = await phase(GpuSpikeArm.widget, 'bandexit',
        (i) => state.camera.zoomAt(centre, 1.02));
    gpuReport('GSPIKE D | bandexit | build  ${gpuStats(rep.build)}');
    gpuReport('GSPIKE D | bandexit | raster ${gpuStats(rep.raster)}');
    gpuReport('GSPIKE D | bandexit | rebuilds landed=${r.landed - landedBefore} '
        'staleFrames=${r.bandStaleFrames} lastTrigger=${r.lastTrigger?.name} '
        '(criterion 9: the stale interval after a mid-gesture band exit, '
        'reported without a threshold)');
  }
```

This needs `frames` to be at least 40 for the phase; `phase()` pumps the
run's `frames`, so the band-exit phase calls `phase` with a local override:
give `phase` an optional `int? frameCount` parameter used in place of
`frames` when non-null, and pass `frameCount: 40` here.

**The allocation phase**, once, last:

```dart
  await setArm(GpuSpikeArm.widget);
  {
    state.camera.value = baseCamera;
    await pumpFrame();
    AllocationProbe? probe;
    try {
      probe = await AllocationProbe.connect();
    } catch (error) {
      gpuReport('GSPIKE alloc: UNEVALUABLE -- the VM service refused: $error');
    }
    if (probe != null) {
      const allocFrames = 30;
      await probe.reset();
      for (var i = 0; i < allocFrames; i++) {
        state.camera.panBy(const Offset(4, 0));
        await pumpFrame();
      }
      final counts = await probe.read();
      final b = state.backendOf(GpuSpikeArm.widget)!;
      final patches = b.patchesRendered;
      var total = 0;
      for (final n in counts.values) {
        total += n;
      }
      final perFrame = total / allocFrames;
      final budget = kAllocFixed + kAllocPerPatch * patches;
      final top = counts.entries.toList()
        ..sort((x, y) => y.value.compareTo(x.value));
      for (final e in top.take(15)) {
        gpuReport('GSPIKE alloc | ${(e.value / allocFrames).toStringAsFixed(1)}'
            '/frame | ${e.key}');
      }
      gpuReport('GSPIKE alloc: perFrame=${perFrame.toStringAsFixed(1)} '
          'patches=$patches budget=$budget '
          '(kAllocFixed=$kAllocFixed + kAllocPerPatch=$kAllocPerPatch x P) '
          '-> ${perFrame <= budget ? "PASS" : "MISS"} | frames=$allocFrames '
          'classes=${counts.length} total=$total');
      await probe.dispose();
    }
  }
```

**Every `GSPIKE done` line stays last.**

- [ ] **Step 6: `launch.json`**

Two entries after the `DRAW_TEXT=false` one:

```jsonc
        {
            // Plan F: four arms (D is DraftCanvas on residentGpu), the ten
            // trigger rebuilds per repeat, the band-exit phase and the
            // allocation probe. The same corpus as the criterion-11 run.
            "name": "2d: GPU spike -- Plan F (arm D, triggers, band exit, probe)",
            "cwd": "apps/dev_harness_2d",
            "program": "lib/main.dart",
            "request": "launch",
            "type": "dart",
            "deviceId": "macos",
            "flutterMode": "profile",
            "toolArgs": [
                "--dart-define=RUN_GPU_SPIKE=true",
                "--dart-define=ENTITIES=10000",
                "--dart-define=SPIKE_DEFS=20",
                "--dart-define=SPIKE_INSTANCES=150",
                "--dart-define=SPIKE_FRAMES=30",
                "--dart-define=SPIKE_REPEATS=3",
                "--dart-define=SPIKE_FILLS=true",
                "--dart-define=SPIKE_TEXT=true"
            ]
        },
        {
            // The main view on the resident backend, for the eye: pan and
            // zoom by hand, watch the rebuild land past 2x, pan far off the
            // fitted view and look for an empty edge.
            "name": "2d: main view -- BACKEND=residentGpu",
            "cwd": "apps/dev_harness_2d",
            "program": "lib/main.dart",
            "request": "launch",
            "type": "dart",
            "deviceId": "macos",
            "flutterMode": "profile",
            "toolArgs": [
                "--dart-define=BACKEND=residentGpu",
                "--dart-define=ENTITIES=10000"
            ]
        },
```

- [ ] **Step 7: Run the harness tests; expect PASS. Then the three gates**

```sh
cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
git status --short   # analysis_options.yaml must not appear; pubspec.lock changes ARE committed
```

- [ ] **Step 8: Commit**

```sh
git add apps/dev_harness_2d/pubspec.yaml pubspec.lock apps/dev_harness_2d/lib/allocation_probe.dart apps/dev_harness_2d/lib/gpu_arm.dart apps/dev_harness_2d/lib/main.dart apps/dev_harness_2d/test/gpu_widget_arm_test.dart .vscode/launch.json
git commit -m "feat(harness): arm D on DraftCanvas, the ten trigger rebuilds, the band exit, and a VM-service allocation probe"
```

(`pubspec.lock` at the workspace root is the one `flutter pub get` rewrites;
if it is git-ignored in this repository, skip it.)

---
