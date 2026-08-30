# GPU backend, Plan A — the seam and the strokes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A third `RenderBackend` that draws a document's **stroked polylines**
from GPU-resident geometry in one instanced draw call, with the camera as a
uniform, and falls back to `VerticesDrawSink` where Flutter GPU is unavailable.

**Architecture:** A collector implementing the existing `DrawSink` walks the
document **once per rebuild**, not per frame, and writes one instance record per
stroke segment into a single `Float32List` in walk order. That buffer is
uploaded once. Each frame writes a 20-float uniform block and issues **one**
instanced draw; ordering is preserved because the buffer is submitted in walk
order and there is exactly one call. Every GPU import in the package is
confined to one facade file.

**Tech Stack:** Dart, Flutter 3.47.1, `flutter_scene` 0.23.0 (for its internal
`flutter_gpu` shim only), `impellerc` for the shader bundle, `flutter_test`.

**Spec:** [docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 4). Read it before Task 1; this plan argues from it.

**Evidence:** [the spike](../notes/2026-08-29-flutter-gpu-backend-spike.md),
[the 10,000-entity measurement](../notes/2026-08-29-gpu-arm-10k-measurement.md),
[the settle-flicker probe](../notes/2026-08-29-settle-flicker-probe.md).

**Reference implementation:** the throwaway spike arm at
`apps/dev_harness_2d/lib/gpu_arm.dart` on this branch already does the core of
Tasks 4-7 and is known to run on macOS and in Chrome. Read it; do not copy its
shortcuts (it bakes no joins, no caps, no dashes, and skips fills and text).

---

## Where Plan A sits

The spec is one subsystem but too large for one plan. Seven plans, each
producing working software:

| plan | delivers |
|---|---|
| **A (this one)** | the facade, the enum, the collector and buffer for **stroked polylines**, one draw call, the ordering and differential gates, the fallback |
| B | joins, caps, `point()`, and the `_coveredArgb` hairline alpha |
| C | dashes in the shader |
| D | fills |
| E | the text split — *N* text ops, *N+1* draw calls |
| F | the rebuild triggers and the watermark |
| G | web: CanvasKit and Skwasm |

**Plan A's exit is not the spec's exit gate.** It satisfies spec criteria 3, 4
and 10, and establishes the instruments criteria 1 and 5 need. Criteria 6-9, 11,
12 and 13 belong to later plans.

## Global Constraints

Copied verbatim from `CLAUDE.md` and the spec. Every task's requirements
implicitly include this section.

- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.**
- **Draw order is emission order** — *not* "ascending handle value". A
  definition's contents are emitted contiguously at the instance's handle
  position in definition-local handles (`draft_painter.dart:397-412`,
  `:449-467`), so global emission order is **not** a sorted list of handle
  values. **Never sort the buffer.**
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of
  them in this workspace. Check `git status` before every commit and
  `git checkout --` them.
- **Never synthesize test output.** Run the command, paste what it printed.
- Code, comments and commit messages in English.
- **`packages/jet_cad_2d` is untouched by this plan.** Everything lives in
  `packages/jet_cad_2d_flutter`.
- Shaders are authored so `impellerc` can emit an **OpenGL ES 100** stage: the
  web loader reads `entry.openglEs` and runs `transpileGlslEs100To300` over it.
  **No bitwise operators and no integer attributes** — ES 100 has neither. Colour
  is four floats, and the kind tag is a float compared with `<`, not an int.
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```

## File structure

| file | responsibility |
|---|---|
| `lib/src/gpu/gpu_facade.dart` | **the only file in the package that imports a GPU package.** Re-exports `flutter_scene`'s shim, and owns the injectable factory the fallback test needs |
| `lib/src/gpu/instance_record.dart` | the record layout: field offsets, stride, kind constants, and the writer |
| `lib/src/gpu/geometry_collector.dart` | `DrawSink` implementation; walk-order emission into a `Float32List` |
| `lib/src/gpu/resident_geometry.dart` | owns the device buffers, the upload, and the render-target texture |
| `lib/src/gpu/gpu_draw_backend.dart` | the frame path: uniform write, one draw call, `asImage`, composite |
| `lib/src/render_backend.dart` | **modify** — a third enum value |
| `shaders/cad_stroke.vert`, `shaders/cad_stroke.frag` | the shader pair |
| `tool/build_shaders.sh` | the `impellerc` invocation, checked in so the bundle is reproducible |
| `assets/shaders/cad.shaderbundle` | generated, committed |

---

### Task 1: The facade, and a fallback that is testable

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_facade.dart`
- Modify: `packages/jet_cad_2d_flutter/pubspec.yaml`
- Test: `packages/jet_cad_2d_flutter/test/gpu/gpu_facade_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `bool gpuAvailable()`, `void debugSetGpuFactory(GpuContextFactory? f)`,
  `typedef GpuContextFactory = gpu.GpuContext Function()`, and the re-export
  `export 'package:flutter_scene/src/gpu/gpu.dart';`

Spec criterion 10 requires the fallback to be tested "through an injectable
facade factory that fails on demand" — hardware or plist failure is not a
deterministic fixture. That injection point is the reason this task exists
before any drawing.

- [ ] **Step 1: Add the dependency**

In `packages/jet_cad_2d_flutter/pubspec.yaml`, under `dependencies:`:

```yaml
  # **For its internal `flutter_gpu` shim only, not its scene graph.**
  # `flutter_scene/lib/src/gpu/gpu.dart` re-exports `package:flutter_gpu`
  # verbatim on native and falls back to a WebGL2 backend on web; bare
  # `flutter_gpu` imports `dart:ffi` and cannot compile for the web at all.
  # The import is off contract and pre-1.0, which is why exactly one file in
  # this package is allowed to make it.
  flutter_scene: ^0.23.0
```

Run `flutter pub get`, then `git checkout -- ../jet_cad/analysis_options.yaml`
and any other rewritten `analysis_options.yaml`.

- [ ] **Step 2: Write the failing test**

`test/gpu/gpu_facade_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';

void main() {
  tearDown(() => debugSetGpuFactory(null));

  test('reports the platform context when no factory is injected', () {
    // On the test host Flutter GPU is not enabled, so this is false. The
    // assertion that matters is that it *answers* rather than throwing.
    expect(() => gpuAvailable(), returnsNormally);
  });

  test('a factory that throws makes the backend unavailable, once', () {
    var calls = 0;
    debugSetGpuFactory(() {
      calls++;
      throw StateError('no gpu');
    });
    expect(gpuAvailable(), isFalse);
    expect(gpuAvailable(), isFalse);
    expect(calls, 1,
        reason: 'the probe is cached: a platform without Flutter GPU must not '
            'pay a throwing call per frame');
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/gpu/gpu_facade_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'jet_cad_2d_flutter' ... gpu_facade.dart` or `Method not found: 'gpuAvailable'`.

- [ ] **Step 4: Write the facade**

`lib/src/gpu/gpu_facade.dart`:

```dart
/// The only file in this package that imports a GPU package.
///
/// **Why the import is off contract, and why it is confined here.**
/// `package:flutter_gpu` imports `dart:ffi` and `dart:nativewrappers` at
/// library level, so it cannot compile for the web. `flutter_scene` carries an
/// internal shim that re-exports it verbatim on native and falls back to its
/// own WebGL2 backend on web, selected by conditional export. That shim lives
/// under `lib/src/`, in a pre-1.0 package whose minor releases carry breaking
/// changes. Confining it to one file is what makes replacing it — with our own
/// conditional export over our own backend — an edit to this file rather than a
/// rewrite.
///
/// **Trigger for taking it in-house:** the first `flutter_scene` minor release
/// that breaks this file, or the first API the shim does not expose.
library;

// ignore: implementation_imports
import 'package:flutter_scene/src/gpu/gpu.dart' as gpu;

// ignore: implementation_imports
export 'package:flutter_scene/src/gpu/gpu.dart';

/// Builds a GPU context, or throws if the platform has none.
typedef GpuContextFactory = gpu.GpuContext Function();

GpuContextFactory? _override;
bool? _available;

/// **Test seam.** Replaces the platform probe; `null` restores it and clears
/// the cached answer.
///
/// Spec criterion 10 requires the fallback to be exercised deterministically,
/// and neither a missing `Info.plist` key nor absent hardware is a fixture a
/// suite can arrange.
void debugSetGpuFactory(GpuContextFactory? factory) {
  _override = factory;
  _available = null;
}

/// Whether this platform can serve the resident backend.
///
/// **Cached, and the cache is the point.** A platform without Flutter GPU must
/// answer once and then cost nothing; probing per frame would put a throwing
/// call on the frame path of exactly the devices that can least afford it.
bool gpuAvailable() {
  final cached = _available;
  if (cached != null) return cached;
  try {
    final factory = _override;
    if (factory != null) {
      factory();
    } else {
      // Touching the context is the probe: the getter throws on a platform
      // where Flutter GPU was not enabled.
      gpu.gpuContext.defaultColorFormat;
    }
    return _available = true;
  } catch (_) {
    return _available = false;
  }
}
```

- [ ] **Step 5: Run the test**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/gpu/gpu_facade_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 6: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../.. && git status --short   # confirm no analysis_options.yaml is staged
git add packages/jet_cad_2d_flutter/lib/src/gpu/gpu_facade.dart \
        packages/jet_cad_2d_flutter/test/gpu/gpu_facade_test.dart \
        packages/jet_cad_2d_flutter/pubspec.yaml
git commit -m "feat(gpu): the facade, and a GPU probe a test can fail on demand"
```

---

### Task 2: The instance record

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart`
- Test: `packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `const int kFloatsPerInstance = 10;`,
  `const double kKindStroke = 0;`,
  `void writeStroke(Float32List into, int index, {required double x0, required double y0, required double x1, required double y1, required double halfWidth, required int argb})`

**Why ten floats and not a packed record.** The shader bundle must carry an
OpenGL ES 100 stage for the web loader, and ES 100 has no bitwise operators and
no integer vertex attributes — so a packed `uint32` colour cannot be unpacked in
the shader. Four floats it is. Later plans add kinds; the layout leaves the kind
in slot 0 so a `kind < 0.5` branch reads the same in every stage.

- [ ] **Step 1: Write the failing test**

`test/gpu/instance_record_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

void main() {
  test('writes a stroke at an offset without touching its neighbours', () {
    final buffer = Float32List(kFloatsPerInstance * 3);
    // Fill so an unwritten field is visible rather than coincidentally zero:
    // a record written into an all-zero buffer passes even if it writes
    // nothing, which is the degenerate fixture this guards.
    buffer.fillRange(0, buffer.length, -1);

    writeStroke(buffer, 1,
        x0: 3, y0: 4, x1: 5, y1: 6, halfWidth: 0.75, argb: 0x80402010);

    expect(buffer.sublist(0, kFloatsPerInstance),
        everyElement(-1.0), reason: 'record 0 must be untouched');
    expect(buffer.sublist(kFloatsPerInstance * 2),
        everyElement(-1.0), reason: 'record 2 must be untouched');

    final r = buffer.sublist(kFloatsPerInstance, kFloatsPerInstance * 2);
    expect(r[0], kKindStroke);
    expect(r.sublist(1, 5), [3.0, 4.0, 5.0, 6.0]);
    expect(r[5], 0.75);
    // 0x80402010 -> a=0x80, r=0x40, g=0x20, b=0x10
    expect(r[6], closeTo(0x40 / 255, 1e-6));
    expect(r[7], closeTo(0x20 / 255, 1e-6));
    expect(r[8], closeTo(0x10 / 255, 1e-6));
    expect(r[9], closeTo(0x80 / 255, 1e-6));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/gpu/instance_record_test.dart`
Expected: FAIL — `Method not found: 'writeStroke'`.

- [ ] **Step 3: Write the record**

`lib/src/gpu/instance_record.dart`:

```dart
import 'dart:typed_data';

/// Floats per instance record.
///
/// `[kind, x0, y0, x1, y1, halfWidth, r, g, b, a]`.
///
/// **Ten floats, and none of them packed, because of the web.** The shader
/// bundle must carry an OpenGL ES 100 stage — `flutter_scene`'s web loader
/// reads `entry.openglEs` and transpiles it to ES 300 — and ES 100 has neither
/// bitwise operators nor integer vertex attributes, so a `uint32` colour could
/// not be unpacked in the shader. 40 bytes per record against the spike's 36.
const int kFloatsPerInstance = 10;

/// The kind tag, in slot 0 of every record.
///
/// **One buffer and one draw call carry every kind**, because separate
/// pipelines are separate draw calls and three draw calls submit as "all
/// strokes, then all joins, then all fills" — not walk order.
/// `vertices_draw_sink.dart:41-57` records that defect being shipped and
/// reverted once already, partitioned by colour rather than by kind.
const double kKindStroke = 0;

/// Writes the stroke record at [index]. [argb] is `0xAARRGGBB`.
void writeStroke(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o] = kKindStroke;
  into[o + 1] = x0;
  into[o + 2] = y0;
  into[o + 3] = x1;
  into[o + 4] = y1;
  into[o + 5] = halfWidth;
  into[o + 6] = ((argb >> 16) & 0xFF) / 255.0;
  into[o + 7] = ((argb >> 8) & 0xFF) / 255.0;
  into[o + 8] = (argb & 0xFF) / 255.0;
  into[o + 9] = ((argb >> 24) & 0xFF) / 255.0;
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/gpu/instance_record_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart \
        packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart
git commit -m "feat(gpu): the instance record, ten floats and none of them packed"
```

---

### Task 3: The collector, and the mutation that proves it applies the residual

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`
- Test: `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `kFloatsPerInstance`, `writeStroke`, `kKindStroke` (Task 2).
- Produces: `class GeometryCollector implements DrawSink` with
  `GeometryCollector({required double pixelsPerPaperMm, required double devicePixelRatio, double lineweightScale = 1.0})`,
  `Float32List get data`, `int get instanceCount`, `int get skippedOps`.

**The named mutation this task exists to kill:** *drop the residual transform
and emit the raw points.* The widget spike's smoke run hit exactly that and put
all 399,000 primitives outside the viewport
(`2026-08-29-widget-per-entity-spike.md`). The fixture below is off-origin and
non-uniformly scaled, so the mutation cannot pass.

- [ ] **Step 1: Write the failing test**

`test/gpu/geometry_collector_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

const _style = ResolvedStyle(
    argb: 0xFF203040,
    lineweightHundredths: 50,
    linetype: Handle.none,
    linetypeScale: 1);

void main() {
  test('applies the residual, and a non-uniform one', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: 4, devicePixelRatio: 2, lineweightScale: 1);

    // **Deliberately not the identity, not at the origin, and not uniform.**
    // a=2, d=3 with a translation: a collector that drops the residual writes
    // (1,1)->(2,2); one that applies it writes (12,13)->(14,16).
    c.beginResidual(Transform2(2, 0, 0, 3, 10, 10));
    final pts = Float64List.fromList([1, 1, 2, 2]);
    c.polyline(pts, 2, _style, closed: false);
    c.endResidual();

    expect(c.instanceCount, 1);
    final r = c.data.sublist(0, kFloatsPerInstance);
    expect(r[0], kKindStroke);
    expect(r.sublist(1, 5), [12.0, 13.0, 14.0, 16.0]);
  });

  test('emits one instance per segment, in walk order', () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([0, 0, 1, 0, 1, 1]), 3, _style,
        closed: false);
    c.endResidual();

    expect(c.instanceCount, 2);
    expect(c.data.sublist(1, 5), [0.0, 0.0, 1.0, 0.0]);
    expect(c.data.sublist(kFloatsPerInstance + 1, kFloatsPerInstance + 5),
        [1.0, 0.0, 1.0, 1.0]);
  });

  test('drops a zero-length segment rather than handing the shader a NaN', () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.polyline(Float64List.fromList([5, 5, 5, 5]), 2, _style, closed: false);
    c.endResidual();
    expect(c.instanceCount, 0);
  });

  test('counts the ops Plan A does not draw instead of dropping them silently',
      () {
    final c = GeometryCollector(pixelsPerPaperMm: 4, devicePixelRatio: 2);
    c.beginResidual(Transform2.identity());
    c.circle(0, 0, 5, _style);
    c.text('x', Handle.none, _style);
    c.endResidual();
    expect(c.instanceCount, 0);
    expect(c.skippedOps, 2);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/gpu/geometry_collector_test.dart`
Expected: FAIL — `Method not found: 'GeometryCollector'`.

- [ ] **Step 3: Write the collector**

`lib/src/gpu/geometry_collector.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'instance_record.dart';

/// Collects a document's stroked segments into one buffer, in walk order.
///
/// **This is a `DrawSink`, and that is deliberate.** `RecordingDrawSink`
/// equality is this project's primary correctness mechanism; a backend that
/// invented its own traversal would give it up. What changes is not the
/// interface but *when* it runs — on a rebuild, not on a frame.
///
/// **Walk order is the draw order and nothing may reorder it.** The buffer is
/// submitted in the order written, in one draw call, and that is the whole
/// reason this design needs no depth buffer. Sorting it — by handle, by colour,
/// by anything — reintroduces the defect `vertices_draw_sink.dart:41-57`
/// records.
class GeometryCollector implements DrawSink {
  GeometryCollector({
    required this.pixelsPerPaperMm,
    required this.devicePixelRatio,
    this.lineweightScale = 1.0,
  });

  final double pixelsPerPaperMm;
  final double devicePixelRatio;
  final double lineweightScale;

  /// **A minimum stroke width in device pixels.** Copied from
  /// `VerticesDrawSink.kMinStrokeDevicePixels` rather than shared, because that
  /// one is a private implementation detail of a sink this class does not use.
  /// If the two ever disagree the differential test in Task 8 goes red, which
  /// is the intended alarm.
  static const double kMinStrokeDevicePixels = 1.0;

  final List<double> _out = <double>[];
  int _instances = 0;
  int _skipped = 0;
  Transform2 _residual = Transform2.identity();

  Float32List get data => Float32List.fromList(_out);
  int get instanceCount => _instances;

  /// Ops this plan does not draw yet — arcs, circles, fills, text, points.
  /// Counted rather than ignored so a corpus that needs Plan B through E is
  /// visible as a number instead of as a missing picture.
  int get skippedOps => _skipped;

  double _halfWidthFor(int lineweightHundredths) {
    final logical =
        lineweightHundredths / 100.0 * pixelsPerPaperMm * lineweightScale;
    final floor = kMinStrokeDevicePixels / devicePixelRatio;
    final w = logical.isFinite && logical > floor ? logical : floor;
    return w / 2;
  }

  void _emit(double x0, double y0, double x1, double y1, double half, int argb) {
    // Exactly the sink's own test: `_emitSegment` bails on zero length
    // (`vertices_draw_sink.dart:503-507`). A degenerate segment has no
    // direction and the shader would divide by zero building its normal.
    if (x0 == x1 && y0 == y1) return;
    final at = _instances * kFloatsPerInstance;
    _out.length = at + kFloatsPerInstance;
    final view = Float32List(kFloatsPerInstance);
    writeStroke(view, 0,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
    for (var i = 0; i < kFloatsPerInstance; i++) {
      _out[at + i] = view[i];
    }
    _instances++;
  }

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
  }

  @override
  void endResidual() {}

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final t = _residual;
    var px = t.a * points[0] + t.c * points[1] + t.e;
    var py = t.b * points[0] + t.d * points[1] + t.f;
    final firstX = px, firstY = py;
    for (var i = 1; i < count; i++) {
      final qx = t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e;
      final qy = t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f;
      _emit(px, py, qx, qy, half, style.argb);
      px = qx;
      py = qy;
    }
    if (closed) _emit(px, py, firstX, firstY, half, style.argb);
  }

  @override
  void point(double x, double y, ResolvedStyle style) => _skipped++;

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _skipped++;

  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
          ResolvedStyle style) =>
      _skipped++;

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) =>
      _skipped++;

  @override
  void text(String text, Handle style, ResolvedStyle resolved) => _skipped++;
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/gpu/geometry_collector_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Fire the mutation by hand and confirm it goes red**

Temporarily change `_emit`'s call in `polyline` to use the raw points —
`_emit(points[0], points[1], points[2], points[3], half, style.argb)` — and run
the suite. Expected: the residual test FAILS. **Revert the mutation**, re-run,
confirm green, and record both outcomes in the task report.

- [ ] **Step 6: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart \
        packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): the collector, and a fixture a dropped residual cannot pass"
```

---

### Task 4: The shaders and a reproducible bundle

**Files:**
- Create: `packages/jet_cad_2d_flutter/shaders/cad_stroke.vert`
- Create: `packages/jet_cad_2d_flutter/shaders/cad_stroke.frag`
- Create: `packages/jet_cad_2d_flutter/tool/build_shaders.sh`
- Create (generated, committed): `packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle`
- Modify: `packages/jet_cad_2d_flutter/pubspec.yaml`

**Interfaces:**
- Consumes: the record layout from Task 2 — attribute names must match exactly.
- Produces: shader names `CadStrokeVertex` and `CadStrokeFragment`, uniform
  block `FrameInfo { mat4 mvp; vec2 half_viewport; }`, vertex inputs `corner`
  (per vertex) and `kind, p0, p1, half_width, color` (per instance).

**The half-width is applied after projection and that is the point.** The
lineweight is paper-space 1/100 mm and explicitly *"not a world quantity"*
(`resolved_style.dart:18`), so it is invariant under zoom. A quad expanded at
collection time thickens with the camera; expanded in the shader it does not.

- [ ] **Step 1: Write the vertex shader**

`shaders/cad_stroke.vert`:

```glsl
// Expands one world-space segment per instance into a screen-space quad.
//
// **Authored for OpenGL ES 100.** `impellerc` emits the `openglEs` stage the
// web loader reads and transpiles to ES 300, and ES 100 has no bitwise
// operators and no integer attributes -- hence a float kind tag and a vec4
// colour rather than a packed uint32.

uniform FrameInfo {
  mat4 mvp;            // collection space -> normalized device coordinates
  vec2 half_viewport;  // device pixels / 2
} frame_info;

// Per vertex: two triangles of a unit quad, six corners.
// x picks the endpoint (0 = p0, 1 = p1), y picks the side (-1 or +1).
in vec2 corner;

// Per instance.
in float kind;
in vec2 p0;
in vec2 p1;
in float half_width;  // device pixels
in vec4 color;

out vec4 v_color;

void main() {
  vec4 clip0 = frame_info.mvp * vec4(p0, 0.0, 1.0);
  vec4 clip1 = frame_info.mvp * vec4(p1, 0.0, 1.0);

  vec2 px0 = clip0.xy * frame_info.half_viewport;
  vec2 px1 = clip1.xy * frame_info.half_viewport;

  vec2 delta = px1 - px0;
  float length_px = length(delta);
  // The collector drops zero-length segments, so this guard is defensive
  // rather than reachable -- and it stays, because a NaN here is a whole
  // frame of nothing.
  vec2 direction = length_px > 0.0 ? delta / length_px : vec2(1.0, 0.0);
  vec2 normal = vec2(-direction.y, direction.x);

  vec2 px = mix(px0, px1, corner.x) + normal * half_width * corner.y;

  gl_Position = vec4(px / frame_info.half_viewport, 0.0, 1.0);
  v_color = color;
}
```

- [ ] **Step 2: Write the fragment shader**

`shaders/cad_stroke.frag`:

```glsl
// Plan A draws hard-edged strokes. Antialiasing is Plan B's, and the pixel
// differential in Task 8 is stated against a hard-edged reference for exactly
// that reason.

in vec4 v_color;
out vec4 frag_color;

void main() {
  frag_color = v_color;
}
```

- [ ] **Step 3: Write the build script**

`tool/build_shaders.sh`:

```sh
#!/bin/sh
# Compiles the shader bundle. Checked in so the committed bundle is
# reproducible rather than a binary somebody once produced.
#
# `impellerc` ships in the engine artifacts and is not on PATH.
# `--runtime-stage-gles` is the stage `flutter_scene`'s web loader reads
# (`entry.openglEs`, then `transpileGlslEs100To300`); the metal and vulkan
# stages serve native.
set -e
FLUTTER_ROOT="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
IMPELLERC="$FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/impellerc"
cd "$(dirname "$0")/.."
"$IMPELLERC" \
  --runtime-stage-metal --runtime-stage-vulkan --runtime-stage-gles \
  --shader-bundle='{"CadStrokeVertex":{"type":"vertex","file":"shaders/cad_stroke.vert"},"CadStrokeFragment":{"type":"fragment","file":"shaders/cad_stroke.frag"}}' \
  --sl=assets/shaders/cad.shaderbundle
echo "wrote assets/shaders/cad.shaderbundle"
```

- [ ] **Step 4: Build the bundle and verify the ES stage is in it**

```sh
chmod +x packages/jet_cad_2d_flutter/tool/build_shaders.sh
packages/jet_cad_2d_flutter/tool/build_shaders.sh
strings -a packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle | grep -c "attribute "
```

Expected: the script prints the path, and the `grep -c` is **greater than
zero** — `attribute` is ES 100 syntax and its presence is the evidence the web
loader's input is there. Paste both outputs into the task report.

- [ ] **Step 5: Declare the asset**

In `packages/jet_cad_2d_flutter/pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/shaders/cad.shaderbundle
```

- [ ] **Step 6: Commit**

```sh
git add packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/tool \
        packages/jet_cad_2d_flutter/assets packages/jet_cad_2d_flutter/pubspec.yaml
git commit -m "feat(gpu): the stroke shaders, and a build script that makes the bundle reproducible"
```

---

### Task 5: Resident geometry — upload once

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart`
- Test: `packages/jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart`

**Interfaces:**
- Consumes: `gpu_facade.dart`, `kFloatsPerInstance` (Task 2).
- Produces: `class ResidentGeometry` with
  `static Future<ResidentGeometry?> create(Float32List instances, int instanceCount)`,
  `int get instanceCount`, `int get byteLength`, `void dispose()`, and
  the package-private fields the backend binds.

The unit-quad corner buffer is six vertices — two triangles — because a triangle
strip cannot mix kinds, and Plans B through D add kinds to this same buffer.

- [ ] **Step 1: Write the failing test**

`test/gpu/resident_geometry_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';
import 'package:jet_cad_2d_flutter/src/gpu/resident_geometry.dart';

void main() {
  tearDown(() => debugSetGpuFactory(null));

  test('returns null rather than throwing where there is no GPU', () async {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    final g = await ResidentGeometry.create(
        Float32List(kFloatsPerInstance), 1);
    expect(g, isNull,
        reason: 'the caller falls back; it must not have to catch');
  });

  test('reports the byte length the instance count implies', () {
    expect(ResidentGeometry.byteLengthFor(59875),
        59875 * kFloatsPerInstance * 4);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/gpu/resident_geometry_test.dart`
Expected: FAIL — `Method not found: 'ResidentGeometry'`.

- [ ] **Step 3: Write it**

`lib/src/gpu/resident_geometry.dart`:

```dart
import 'dart:typed_data';

import 'gpu_facade.dart' as gpu;
import 'instance_record.dart';

/// The document's geometry, uploaded once and read every frame.
///
/// **Uploaded once is the whole claim.** The spike measured a 14.7 ms
/// collection walk at 10,000 entities against a 0.61 ms frame; this class is
/// where the walk stops being per-frame.
class ResidentGeometry {
  ResidentGeometry._(this.instanceCount, this._corners, this._instances,
      this._pipeline, this._vertexShader, this._uniforms);

  static const String _bundlePath = 'assets/shaders/cad.shaderbundle';

  /// Bytes a buffer of [instances] records occupies.
  static int byteLengthFor(int instances) =>
      instances * kFloatsPerInstance * 4;

  /// Uploads [instances], or returns null if this platform has no GPU.
  static Future<ResidentGeometry?> create(
      Float32List instances, int instanceCount) async {
    if (!gpu.gpuAvailable()) return null;
    // **The async loader, not `fromAsset`.** `ShaderLibrary.fromAsset` is
    // synchronous and throws on web, where asset loading is not.
    final library = await gpu.loadShaderLibraryAsync(_bundlePath);
    final vertex = library?['CadStrokeVertex'];
    final fragment = library?['CadStrokeFragment'];
    if (vertex == null || fragment == null) return null;

    // Two triangles of a unit quad: (endpoint, side).
    final corners = Float32List.fromList(<double>[
      0, -1, 0, 1, 1, -1, //
      1, -1, 0, 1, 1, 1, //
    ]);

    final context = gpu.gpuContext;
    final layout = gpu.VertexLayout(buffers: <gpu.VertexBuffer>[
      const gpu.VertexBuffer(strideInBytes: 8, attributes: [
        gpu.VertexAttribute(name: 'corner', format: gpu.VertexFormat.float32x2),
      ]),
      const gpu.VertexBuffer(
        strideInBytes: kFloatsPerInstance * 4,
        stepMode: gpu.VertexStepMode.instance,
        attributes: [
          gpu.VertexAttribute(name: 'kind', format: gpu.VertexFormat.float32),
          gpu.VertexAttribute(
              name: 'p0',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: 4),
          gpu.VertexAttribute(
              name: 'p1',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: 12),
          gpu.VertexAttribute(
              name: 'half_width',
              format: gpu.VertexFormat.float32,
              offsetInBytes: 20),
          gpu.VertexAttribute(
              name: 'color',
              format: gpu.VertexFormat.float32x4,
              offsetInBytes: 24),
        ],
      ),
    ]);

    return ResidentGeometry._(
      instanceCount,
      context.createDeviceBufferWithCopy(ByteData.sublistView(corners)),
      context.createDeviceBufferWithCopy(ByteData.sublistView(
          instances, 0, instanceCount * kFloatsPerInstance)),
      context.createRenderPipeline(vertex, fragment, vertexLayout: layout),
      vertex,
      context.createHostBuffer(),
    );
  }

  final int instanceCount;
  final gpu.DeviceBuffer _corners;
  final gpu.DeviceBuffer _instances;
  final gpu.RenderPipeline _pipeline;
  final gpu.Shader _vertexShader;
  final gpu.HostBuffer _uniforms;

  int get byteLength => byteLengthFor(instanceCount);

  gpu.DeviceBuffer get corners => _corners;
  gpu.DeviceBuffer get instances => _instances;
  gpu.RenderPipeline get pipeline => _pipeline;
  gpu.Shader get vertexShader => _vertexShader;
  gpu.HostBuffer get uniforms => _uniforms;

  void dispose() {}
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/gpu/resident_geometry_test.dart`
Expected: PASS, 2 tests. (The null path is what the suite can reach; the upload
path needs a device and is exercised by Task 7's harness run.)

- [ ] **Step 5: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/resident_geometry.dart \
        packages/jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart
git commit -m "feat(gpu): resident geometry, uploaded once"
```

---

### Task 6: The frame path — one uniform write, one draw call

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart`
- Test: `packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart`

**Interfaces:**
- Consumes: `ResidentGeometry` (Task 5), `ViewportTransform`.
- Produces: `class GpuDrawBackend` with
  `GpuDrawBackend(ResidentGeometry geometry, ViewportTransform collectionCamera)`,
  `ui.Image? render(ViewportTransform camera, Size viewport, double dpr)`,
  `int get frames`, and the pure function
  `ByteData buildFrameInfo(Transform2 collectionToScreen, int widthPx, int heightPx)`
  which Task 6's test covers without a GPU.

**The matrix is the only per-frame CPU work, and the test is on the matrix.**
`render` needs a device; `buildFrameInfo` does not, and it is where a sign error
would live.

- [ ] **Step 1: Write the failing test**

`test/gpu/frame_info_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_draw_backend.dart';

void main() {
  test('maps screen space to NDC with y flipped', () {
    // 200x100 device pixels, identity collection-to-screen.
    final data = buildFrameInfo(Transform2.identity(), 200, 100);
    double at(int i) => data.getFloat32(i * 4, Endian.host);

    // Column-major mat4. Screen (0,0) -> NDC (-1, +1); screen (200,100) ->
    // NDC (+1, -1). A sign error on the y row is the defect this catches, and
    // an identity fixture at the origin would not.
    expect(at(0), closeTo(2 / 200, 1e-9)); // x scale
    expect(at(5), closeTo(-2 / 100, 1e-9)); // y scale, negated
    expect(at(12), closeTo(-1, 1e-9)); // x translate
    expect(at(13), closeTo(1, 1e-9)); // y translate
    expect(at(16), closeTo(100, 1e-9)); // half viewport x
    expect(at(17), closeTo(50, 1e-9)); // half viewport y
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/gpu/frame_info_test.dart`
Expected: FAIL — `Method not found: 'buildFrameInfo'`.

- [ ] **Step 3: Write the backend**

`lib/src/gpu/gpu_draw_backend.dart` — the full file, including `render`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../viewport_transform.dart';
import 'gpu_facade.dart' as gpu;
import 'resident_geometry.dart';

/// The uniform block: `mat4 mvp` then `vec2 half_viewport`, std140, 80 bytes.
///
/// [collectionToScreen] takes a point in the buffer's space — the collection
/// camera's screen space — to the live camera's screen space. This function
/// finishes the job: screen to normalized device coordinates, y flipped.
ByteData buildFrameInfo(
    Transform2 collectionToScreen, int widthPx, int heightPx) {
  final sx = 2.0 / widthPx;
  final sy = -2.0 / heightPx;
  final data = ByteData(80);
  void f(int i, double v) => data.setFloat32(i * 4, v, Endian.host);
  f(0, collectionToScreen.a * sx);
  f(1, collectionToScreen.b * sy);
  f(2, 0);
  f(3, 0);
  f(4, collectionToScreen.c * sx);
  f(5, collectionToScreen.d * sy);
  f(6, 0);
  f(7, 0);
  f(8, 0);
  f(9, 0);
  f(10, 1);
  f(11, 0);
  f(12, collectionToScreen.e * sx - 1);
  f(13, collectionToScreen.f * sy + 1);
  f(14, 0);
  f(15, 1);
  f(16, widthPx / 2);
  f(17, heightPx / 2);
  f(18, 0);
  f(19, 0);
  return data;
}

/// `outer ∘ inner`.
Transform2 composeTransforms(Transform2 outer, Transform2 inner) => Transform2(
      outer.a * inner.a + outer.c * inner.b,
      outer.b * inner.a + outer.d * inner.b,
      outer.a * inner.c + outer.c * inner.d,
      outer.b * inner.c + outer.d * inner.d,
      outer.a * inner.e + outer.c * inner.f + outer.e,
      outer.b * inner.e + outer.d * inner.f + outer.f,
    );

/// Draws [geometry] once per frame with the camera as a uniform.
class GpuDrawBackend {
  GpuDrawBackend(this.geometry, this.collectionCamera)
      : _collectionInverse = collectionCamera.worldToScreenMatrix.invert();

  final ResidentGeometry geometry;
  final ViewportTransform collectionCamera;
  final Transform2 _collectionInverse;

  gpu.Texture? _target;
  int _w = 0;
  int _h = 0;

  /// Frames submitted. A backend in the paint path that never increments this
  /// is drawing nothing, and a timing figure taken from it is the cost of an
  /// empty screen.
  int frames = 0;

  ui.Image? render(ViewportTransform camera, Size viewport, double dpr) {
    final widthPx = (viewport.width * dpr).round();
    final heightPx = (viewport.height * dpr).round();
    if (widthPx <= 0 || heightPx <= 0 || geometry.instanceCount == 0) {
      return null;
    }
    if (_target == null || _w != widthPx || _h != heightPx) {
      // **`createTexture`, not `createImageSurface`.** The web backend has no
      // `createImageSurface` at all, and on macOS Metal its optional format
      // argument resolves to `PixelFormat.unknown` and throws.
      _target = gpu.gpuContext.createTexture(
          gpu.StorageMode.devicePrivate, widthPx, heightPx);
      _w = widthPx;
      _h = heightPx;
    }
    final target = _target!;

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final pass = commandBuffer.createRenderPass(gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
          texture: target, clearValue: vm.Vector4(1, 1, 1, 1)),
    ));

    pass.bindPipeline(geometry.pipeline);
    pass.setPrimitiveType(gpu.PrimitiveType.triangle);
    pass.setColorBlendEnable(true);
    pass.bindVertexBuffer(
        gpu.BufferView(geometry.corners,
            offsetInBytes: 0, lengthInBytes: geometry.corners.sizeInBytes),
        slot: 0);
    pass.bindVertexBuffer(
        gpu.BufferView(geometry.instances,
            offsetInBytes: 0, lengthInBytes: geometry.instances.sizeInBytes),
        slot: 1);
    pass.bindUniform(
      geometry.vertexShader.getUniformSlot('FrameInfo'),
      geometry.uniforms.emplace(buildFrameInfo(
          composeTransforms(camera.worldToScreenMatrix, _collectionInverse),
          widthPx,
          heightPx)),
    );
    // **One call. Six vertices, one instance per record, in buffer order.**
    pass.draw(6, instanceCount: geometry.instanceCount);

    commandBuffer.submit();
    frames++;
    // Synchronous on both backends: the web shim's `Texture.asImage` states it
    // "matches flutter_gpu's synchronous `asImage`".
    return target.asImage();
  }

  void dispose() => geometry.dispose();
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/gpu/frame_info_test.dart`
Expected: PASS.

- [ ] **Step 5: Fire the mutation and confirm it goes red**

Change `f(5, ...)` to use `+2.0 / heightPx` instead of `sy`. Run the test.
Expected: FAIL on the y-scale expectation. **Revert**, re-run, confirm green,
and record both outcomes.

- [ ] **Step 6: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart \
        packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart
git commit -m "feat(gpu): the frame path -- one uniform write, one draw call"
```

---

### Task 7: The third backend, and the fallback

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/render_backend.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`
- Test: `packages/jet_cad_2d_flutter/test/gpu/backend_selection_test.dart`

**Interfaces:**
- Consumes: `gpuAvailable()` (Task 1).
- Produces: `RenderBackend.residentGpu`, and
  `RenderBackend resolveBackend(RenderBackend requested)`.

- [ ] **Step 1: Write the failing test**

`test/gpu/backend_selection_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/gpu_facade.dart';

void main() {
  tearDown(() => debugSetGpuFactory(null));

  test('residentGpu falls back to vertices where there is no GPU', () {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    expect(resolveBackend(RenderBackend.residentGpu), RenderBackend.vertices);
  });

  test('the default is unchanged by this plan', () {
    expect(defaultRenderBackend(), RenderBackend.vertices);
  });

  test('an explicit vertices request is never rerouted', () {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    expect(resolveBackend(RenderBackend.vertices), RenderBackend.vertices);
    expect(resolveBackend(RenderBackend.canvas), RenderBackend.canvas);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/gpu/backend_selection_test.dart`
Expected: FAIL — `Getter not found: 'residentGpu'`.

- [ ] **Step 3: Add the enum value and the resolver**

In `lib/src/render_backend.dart`, add to the enum after `vertices`:

```dart
  /// The GPU-resident backend: the document's geometry uploaded once, the
  /// camera a uniform, one instanced draw call per frame.
  ///
  /// **Never a default and never automatic.** It is chosen explicitly, and
  /// [resolveBackend] routes it back to [vertices] on a platform without
  /// Flutter GPU rather than throwing per frame.
  residentGpu,
```

and append to the same file:

```dart
/// The backend that will actually run, given what the caller asked for.
///
/// **The fallback is here and nowhere else.** Two call sites that each decided
/// would eventually disagree — the reason [defaultRenderBackend] gives for
/// itself, applied to the same problem one layer up.
RenderBackend resolveBackend(RenderBackend requested) {
  if (requested != RenderBackend.residentGpu) return requested;
  return gpuAvailable() ? RenderBackend.residentGpu : RenderBackend.vertices;
}
```

with `import 'gpu/gpu_facade.dart' show gpuAvailable;` at the top.

Export the new symbols from `lib/jet_cad_2d_flutter.dart` if `render_backend.dart`
is already exported there — it is; no change is needed beyond confirming it.

- [ ] **Step 4: Run the test**

Run: `flutter test test/gpu/backend_selection_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/render_backend.dart \
        packages/jet_cad_2d_flutter/test/gpu/backend_selection_test.dart
git commit -m "feat(gpu): a third backend, and a fallback with one decision point"
```

---

### Task 8: The differential gate — the resident arm against `VerticesDrawSink`

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart`

**Interfaces:**
- Consumes: `GeometryCollector` (Task 3), the existing
  `test/support/fixtures.dart` and `RecordingDrawSink`.

**This is Plan A's most important task and it does not need a GPU.** It compares
the collector's emission against the *reference sink's own* segment stream, so a
divergence in half-width, in walk order, or in the residual is caught in the
widget suite rather than on a device.

- [ ] **Step 1: Write the test**

`test/gpu/collector_differential_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

void main() {
  test('emits every polyline segment the painter walks, in the same order',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    // **Off-origin, mirrored and non-uniform, by construction.** A fixture at
    // the identity transform is the failure mode `CLAUDE.md` names, and it
    // would let a collector that drops the residual pass this test.
    final doc = mirroredNonUniformFixture(measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        drawText: false);
    final camera = ViewportTransform.fit(doc.extents, const Size(400, 300));

    // The reference: what the painter emits, recorded.
    final recording = RecordingDrawSink();
    painter.paint(recording, camera, const Size(400, 300));

    // The arm: what the collector writes.
    final collector = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2);
    painter.paint(collector, camera, const Size(400, 300));

    // Rebuild the expected segment list from the recording, applying the
    // residual exactly as the collector must.
    final expected = <List<double>>[];
    Transform2 residual = Transform2.identity();
    for (final op in recording.ops) {
      if (op is BeginResidualOp) residual = op.residual;
      if (op is PolylineOp) {
        final t = residual;
        var px = t.a * op.points[0] + t.c * op.points[1] + t.e;
        var py = t.b * op.points[0] + t.d * op.points[1] + t.f;
        for (var i = 1; i < op.count; i++) {
          final qx = t.a * op.points[i * 2] + t.c * op.points[i * 2 + 1] + t.e;
          final qy = t.b * op.points[i * 2] + t.d * op.points[i * 2 + 1] + t.f;
          if (px != qx || py != qy) expected.add([px, py, qx, qy]);
          px = qx;
          py = qy;
        }
      }
    }

    expect(expected, isNotEmpty,
        reason: 'a fixture with no polylines would make this test vacuous');
    expect(collector.instanceCount, expected.length);
    for (var i = 0; i < expected.length; i++) {
      final o = i * kFloatsPerInstance;
      expect([collector.data[o + 1], collector.data[o + 2],
              collector.data[o + 3], collector.data[o + 4]],
          expected[i],
          reason: 'instance $i must be the walk\'s $i-th segment');
    }
  });
}
```

- [ ] **Step 2: Add the fixture the test names**

If `mirroredNonUniformFixture` does not exist in `test/support/fixtures.dart`,
add it there — a root group containing a polyline leaf, plus one instance of a
definition placed with a **mirrored, non-uniform** transform
(`Transform2(-1.7, 0, 0, 2.3, 140, -60)`), so both the mirrored and the
non-uniform arms are exercised. Read the neighbouring fixtures in that file and
match their construction style.

- [ ] **Step 3: Run it**

Run: `flutter test test/gpu/collector_differential_test.dart`
Expected: PASS. If the counts differ, the collector — not the test — is wrong.

- [ ] **Step 4: Fire two mutations and confirm both go red**

1. Sort `collector.data` by x before comparing (simulating a buffer sort):
   expect FAIL on the order assertion.
2. In `GeometryCollector.polyline`, skip the `closed` segment:
   expect FAIL on the count, **if** the fixture has a closed polyline; if it
   does not, say so in the report and note that Plan B's `circle()` arm is
   where that mutation becomes killable.

**Revert both**, re-run, confirm green, record all four outcomes.

- [ ] **Step 5: Commit**

```sh
git add packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart \
        packages/jet_cad_2d_flutter/test/support/fixtures.dart
git commit -m "test(gpu): the collector against the painter's own walk, on a fixture the identity cannot pass"
```

---

### Task 9: The harness arm, and a run on a device

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Delete: `apps/dev_harness_2d/lib/gpu_arm.dart`, `apps/dev_harness_2d/lib/gpu_arm_rig.dart`

**Interfaces:**
- Consumes: everything above.

The spike's throwaway arm is replaced by the real backend. Deleting it in the
same commit is what keeps one implementation rather than two.

- [ ] **Step 1: Point the harness's GPU arm at the package**

In `apps/dev_harness_2d`, replace the `RUN_GPU_SPIKE` app's use of the spike's
`SegmentCollector`/`GpuLineRenderer` with `GeometryCollector`,
`ResidentGeometry.create` and `GpuDrawBackend` from
`package:jet_cad_2d_flutter`. Keep the three-arm rig and its interleaving; only
the arm's internals change.

- [ ] **Step 2: Run it on macOS in profile mode**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile \
  --dart-define=RUN_GPU_SPIKE=true --dart-define=ENTITIES=10000 \
  --dart-define=SPIKE_DEFS=20 --dart-define=SPIKE_INSTANCES=150 \
  --dart-define=SPIKE_FRAMES=30 --dart-define=SPIKE_REPEATS=3
```

**Bring the window to the front before the run starts.** An occluded macOS
window produces no frames and the rig hangs silently — recorded in the spike
note, and it costs a run every time it is forgotten.

Expected: a `GSPIKE collect+upload` line naming an instance count and a buffer
size, then nine phase reports. **Paste the output into the task report
verbatim.** Compare the arm C zoom figures against the measurement note's
0.61 build / 0.63 raster; a large divergence is a finding, not a nuisance.

- [ ] **Step 3: Delete the spike arm**

```sh
git rm apps/dev_harness_2d/lib/gpu_arm.dart apps/dev_harness_2d/lib/gpu_arm_rig.dart
```

Fix the imports in `main.dart` and re-run the analyzer.

- [ ] **Step 4: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze
cd ../../apps/dev_harness_2d && flutter analyze
cd ../.. && git status --short   # no analysis_options.yaml
git add apps/dev_harness_2d
git commit -m "feat(harness): the GPU arm runs the package backend, and the spike arm goes"
```

---

## Self-review

**Spec coverage.** Plan A implements: the facade and its in-house trigger; the
one-buffer/one-kind-tag/one-draw-call correction; shader-side quad expansion;
`createTexture` over `createImageSurface`; `loadShaderLibraryAsync` over
`fromAsset`; the ES 100 stage; the fallback through an injectable factory
(criterion 10); emission order preserved and never sorted (criteria 3 and 4, in
the form Plan A can reach).

**Deliberately not in Plan A**, each with its plan: joins, caps, `point()`,
`_coveredArgb` (B); dashes (C); fills (D); text (E); the rebuild triggers,
`devicePixelRatio` and the watermark (F); web (G). The collector counts every
op it does not draw, so a corpus needing a later plan shows as a number rather
than a missing picture.

**Placeholders:** none. Every code step carries the code.

**Type consistency:** `kFloatsPerInstance`, `writeStroke`, `kKindStroke`,
`GeometryCollector`, `ResidentGeometry.create`, `buildFrameInfo`,
`composeTransforms`, `resolveBackend`, `gpuAvailable`, `debugSetGpuFactory` are
each defined once and used with the same signature everywhere after.

**One gap named rather than hidden:** Task 8's second mutation depends on the
fixture containing a closed polyline. The step says so and says where the
mutation becomes killable if it does not.
