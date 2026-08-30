# Final whole-branch review fixes — Plan A (GPU seam and strokes)

Branch `plan-a/gpu-seam-and-strokes`, starting commit `51f146f`. Five Important
findings from the whole-branch review, fixed before merge proposal.

## I1 — `resident_geometry.dart:168` returned `null` instead of throwing

**Verified before changing:** `create` (lines 144-159) wraps its entire call
to `_upload` in a `try`/`catch` that reports through `FlutterError.reportError`
and returns `null`. The offending `if (vertex == null || fragment == null)
return null;` sits inside `_upload`, called from inside that `try` block, so
throwing there is fully covered by the existing catch — no restructuring
needed.

Also verified the review's narrowing claim: `build_shaders.sh` (actually
`tool/build_shaders.sh:57`) declares the bundle JSON with entry points
`CadStrokeVertex` and `CadStrokeFragment`, matching the lookup keys at
`resident_geometry.dart:166-167` exactly. A missing/renamed entry point in
that JSON is what reaches this branch; a bad asset *path* already throws
inside `loadShaderLibraryAsync` per the class's own doc.

**Change:** replaced the silent `return null;` with a `StateError` naming
which entry point(s) are missing and pointing at `tool/build_shaders.sh`'s
`--shader-bundle` JSON, and extended the `_upload` doc's parenthetical list of
real-bug cases to mention it. No behavior change for the "no GPU" and
"asset-path" cases — both still surface as `null` via existing paths.

No new automated test: the class's own doc (lines 28-37) establishes that
`_upload`'s load path is untestable from inside this package (no consuming
app to apply the `packages/` asset prefix in `flutter test`), and
`debugSetGpuFactory` only fakes `gpuAvailable()`/`gpuContext`, not
`loadShaderLibraryAsync`, so there is no seam to drive a fake missing-entry
library through in this package's test suite.

## I2 — `residentGpu` silently painted through `CanvasDrawSink` on a GPU-capable platform

**Verified the bug directly:** `draft_canvas.dart` (`_attach`, was lines
269-275) set `vertices` only when `resolvedBackend == RenderBackend.vertices`;
with a GPU present, `resolveBackend` legitimately returns `residentGpu` and
`vertices` stayed `null`. `_DraftCustomPainter.paint`'s `batching == null`
branch then painted through `sink`, the `CanvasDrawSink` that
`render_backend.dart` itself calls "No longer any platform's default." The
finding was correct, not a misdiagnosis.

**Checked `render_backend_test.dart` before deciding, per the ruling's
instruction:**
- `'an explicit backend is honoured, not clamped'` loops over every
  `RenderBackend` value including `residentGpu`, without forcing
  `gpuAvailable()` either way, and only asserts `state.resolvedBackend ==
  resolveBackend(backend)` — it never inspects `state.vertices`. In a plain
  `flutter test` host environment `gpu.gpuContext.defaultColorFormat` throws
  (no Impeller), so `gpuAvailable()` is false there regardless, which is
  exactly why this test could not have caught I2 and would not have fired an
  `assert(resolvedBackend != residentGpu)` either.
- `'an explicit residentGpu request resolves to vertices when unavailable'`
  forces `gpuAvailable()` false explicitly, so it never touches the
  GPU-present branch at all.
- Conclusion: an assert guarding against `residentGpu` reaching the widget
  would not fire in today's suite, but would be a live landmine on any
  environment where `gpuAvailable()` genuinely returns true (a real device,
  or a future CI runner with Impeller) — exactly the review's warning.

**Fix applied, per the ruling:** `_attach` now builds the `VerticesDrawSink`
for both `RenderBackend.vertices` and `RenderBackend.residentGpu`, and leaves
`resolveBackend` untouched — `resolvedBackend` still faithfully reports
`residentGpu` on a GPU-capable platform, only the *painting* path changes. No
assert added. Updated three doc comments to match: `RenderBackend.residentGpu`
now states the widget-wiring gap is Plan F's work and that `DraftCanvas`
renders it as `vertices` until then; `DraftCanvasState.vertices` and
`_DraftCustomPainter.vertices`'s doc comments were both "non-null only when
... `RenderBackend.vertices`" and are now corrected to include `residentGpu`.

**Golden-test skips checked:** all four (`dash_ladder`, `fill_ladder`,
`text_lod_ladder`, `text_ladder`) skip `residentGpu` with the identical
comment: "it resolves to vertices in a test environment where GPU is
unavailable... Running it would pass the same vertices golden as the explicit
vertices iteration, a redundant pass." This is still accurate after the fix —
in fact more robustly so: it no longer depends on the accident that CI has no
GPU, since `DraftCanvas` now always paints `residentGpu` through the same
`VerticesDrawSink` regardless of platform capability. No comment changes
needed there.

**Re-ran to confirm nothing regressed:** `render_backend_test.dart` (6/6
green, all six original assertions unchanged) and all four golden ladder
suites (green, `residentGpu` still skipped).

## I3 — instance record layout expressed three times with no shared constant

**Verified:** `instance_record.dart`'s `writeStroke` used bare index
arithmetic (`o+1`, `o+2`, ...), `resident_geometry.dart`'s
`kStrokeVertexLayout` restated the same order as byte literals `4, 12, 20,
24`, and `cad_stroke.vert` restates it again by attribute name. The old
`resident_geometry_test.dart` (lines 79-85) asserted `kStrokeVertexLayout`'s
offsets against a hardcoded `Map`, independent of `writeStroke` — a genuine
restatement, not a derivation.

**Fix chosen: named offset constants (first option), plus a genuine
round-trip regression test as belt-and-suspenders.**

Why constants: this codebase's own precedent for `kFloatsPerInstance` /
`kStrokeVertexLayout` is "derive, don't restate," and the plan's own
file-structure table (`plan:87`) assigns "field offsets, stride, kind
constants" to `instance_record.dart` specifically — the constants approach is
what the plan actually asked for, the Task 8 sample code just didn't follow
it. Added `StrokeFieldOffset` (an `abstract final class` of float-index
constants: `kind=0, x0=1, y0=2, x1=3, y1=4, halfWidth=5, r=6, g=7, b=8, a=9`)
to `instance_record.dart`; `writeStroke` now indexes through it, and
`resident_geometry.dart`'s `kStrokeVertexLayout` derives every
`offsetInBytes` as `StrokeFieldOffset.<field> * 4` instead of a bare literal.
A reorder in one now moves the other automatically — there is one Dart-side
source left. `cad_stroke.vert`'s copy is GLSL and cannot read a Dart
constant; that remains an irreducible third copy, documented explicitly in
`StrokeFieldOffset`'s doc comment (only a device run or hand-verification
against `impellerc`'s reflection catches that one drifting).

I additionally replaced the risk that "constants tied together" could still
both be edited in a way that keeps them mutually consistent but wrong (e.g.
someone hardcodes a literal offset in `writeStroke` instead of using the
constant, diverging from the layout) by adding a genuine round-trip test:
`resident_geometry_test.dart`'s new
`'writeStroke and the vertex layout agree on where every field lands'` test
writes one record with **ten distinct values** through `writeStroke`, then
reads every field back through `kStrokeVertexLayout`'s own `offsetInBytes`
via `ByteData`, never touching `StrokeFieldOffset` directly on the read side.
This is exactly the second option the finding offered, added as a
cross-check rather than instead of the constants fix.

**Mutation fired and confirmed red, then reverted via `cp` (never `git
checkout --`):**

Backed up: `cp lib/src/gpu/instance_record.dart /tmp/instance_record.dart.bak`

Mutation: swapped `writeStroke`'s `x0`/`y0` writes —
```dart
into[o + StrokeFieldOffset.y0] = x0;   // was StrokeFieldOffset.x0
into[o + StrokeFieldOffset.x0] = y0;   // was StrokeFieldOffset.y0
```

`flutter test test/gpu/resident_geometry_test.dart` output (real, not
synthesized):
```
00:00 +6 -1: kStrokeVertexLayout writeStroke and the vertex layout agree on where every field lands -- a derivation, not a restatement [E]
  Expected: <11.0>
    Actual: <22.0>
  x0
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/resident_geometry_test.dart 123:7          main.<fn>.<fn>
00:00 +6 -1: Some tests failed.
```
Confirmed red (1 failure, exactly the mutated field). Reverted:
`cp /tmp/instance_record.dart.bak lib/src/gpu/instance_record.dart`, then
`diff` against the backup confirmed byte-identical, and the suite was rerun
green (7/7).

## I4 — false "private implementation detail" justification

**Verified:** `VerticesDrawSink.kMinStrokeDevicePixels`
(`vertices_draw_sink.dart:527`) has no leading underscore, no `@internal`, no
`@visibleForTesting` — it is public. `collector_differential_test.dart:204`
reads it live (`VerticesDrawSink.kMinStrokeDevicePixels / _devicePixelRatio`)
as the reference side of the differential comparison, and its own comment at
lines 197-200 already explains why: so the alarm stays real if either
constant changes independently. The review's finding was correct.

**Fix:** rewrote `GeometryCollector.kMinStrokeDevicePixels`'s doc comment.
The real reason for the duplicate copy is not visibility — it is that
`GeometryCollector` and `VerticesDrawSink` are two **independent**
implementations of the same `DrawSink` contract, and
`collector_differential_test.dart` cross-checks them precisely because they
arrive at their numbers separately. Sharing the constant would make that
comparison partly circular (both sides reading one value instead of two that
happen to agree). The doc now says this, states the constant is public, and
still names the differential test and the live-read line as the alarm
mechanism.

## I5 — `data` getter's per-access copy, undocumented

**Verified:** `Float32List get data => _buffer.sublist(...)` allocates a new
list on every call (`sublist` copies, not a view). `geometry_collector.dart`
is barrel-exported (`jet_cad_2d_flutter.dart:27`), so it's public API.
`collector_differential_test.dart` (lines 130-135) already captures a single
snapshot with a comment explaining why, confirming the cost is real and
already known operationally, just not documented on the getter. Checked the
one place `.data` is actually read today —
`apps/dev_harness_2d/lib/main.dart:1388`,
`ResidentGeometry.create(collector.data, collector.instanceCount)` — called
once per rebuild, not per frame, consistent with the doc I wrote.

**Fix:** added a doc comment on the getter stating it copies, giving the
concrete cost at the plan's measured 10,000-entity scale (10,000 × 10 floats
× 4 bytes ≈ 400 KB per call, computed from `kFloatsPerInstance` and the scale
`resident_geometry.dart`'s class doc already cites), and instructing callers
to read it once per rebuild and hoist it out of any per-frame path — Plan F's
`paint()` call site named explicitly — against the "frame path allocates
nothing per entity in steady state" non-negotiable.

## Gate output (real, both packages)

`packages/jet_cad_2d_flutter`:
```
$ flutter test
...
00:10 +438 ~1: .../tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:10 +439 ~1: All tests passed!
exit=0
```
439 passed (438 pre-existing + 1 new: the I3 round-trip test), 1 pre-existing
skip — matches the branch's known-good count plus exactly the one test added.

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.5s)
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 85 files (0 changed) in 0.16 seconds.
exit=0
```

`apps/dev_harness_2d`:
```
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.3s)
exit=0

$ dart format --output=none --set-exit-if-changed .
Formatted 16 files (0 changed) in 0.25 seconds.
exit=0
```

`git status` before committing showed no `analysis_options.yaml` rewrite (not
touched, nothing to check out) and no unexpected files beyond stray untracked
`.DS_Store`s, which were left alone and not staged.

## I6 — `geometry_collector.dart:54-55` arithmetic off by ~6x

**The defect:** doc comment on the `data` getter warned that the getter copies
the whole buffer on every access and must be hoisted out of any per-frame path.
Its arithmetic was wrong by roughly 6x, which undercut the deterrence it
exists for. The comment said:

```
/// (`resident_geometry.dart`'s doc) that is roughly 400 KB copied per call
/// (10,000 instances × [kFloatsPerInstance] floats × 4 bytes).
```

The problem: substituted **entities** for **instances**. The collector emits one
instance per **segment**, not per entity, and the plan's measurement ties
10,000 entities to 59,875 segments.

**Arithmetic re-derived:**
- Measurement document `docs/superpowers/notes/2026-08-29-gpu-arm-10k-measurement.md:32`
  records for 10,000-entity corpus: `segments=59875, buffer=2.06 MB`
- That 2.06 MB figure was produced by the **spike** using **9** floats per
  instance; verify: `59875 × 9 × 4 = 2,155,500` bytes ≈ 2.05 MB ✓
- The package's record is **10** floats (`kFloatsPerInstance` from
  `instance_record.dart:12`), so correct figure is `59875 × 10 × 4 = 2,395,000`
  bytes ≈ 2.3 MB
- This is corroborated by the test assertion at
  `resident_geometry_test.dart:23`: `ResidentGeometry.byteLengthFor(59875)`
  asserted to equal `2395000` ✓

**Fix:** rewrote lines 54-55 to:
```
/// (59,875 segments; `resident_geometry_test.dart:23`) that is roughly 2.3 MB
/// copied per call (59,875 × [kFloatsPerInstance] × 4 bytes).
```

This:
- Says "segments", not instances, and makes clear the count is segments (59,875)
  rather than entities (10,000)
- Quotes the correct figure (2.3 MB) that follows from `59875 × 10 × 4`
- Cites `resident_geometry_test.dart:23` where the reader can verify the
  59,875 assertion independently

**Gate output and exit codes:**

`packages/jet_cad_2d_flutter`:
```
$ flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
00:06 +439 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.4s)
Formatted 85 files (0 changed) in 0.14 seconds.
exit=0
```

`apps/dev_harness_2d`:
```
$ flutter analyze && dart format --output=none --set-exit-if-changed .
Analyzing dev_harness_2d...
No issues found! (ran in 1.2s)
Formatted 16 files (0 changed) in 0.13 seconds.
exit=0
```

**Verification no code changed:** `git status` showed no modified files outside
`geometry_collector.dart`, no `analysis_options.yaml` touched (would have been
rewritten by `flutter pub get` otherwise), and no unexpected files beyond
untracked `.DS_Store`s which were not staged.

## Where I judged the reviewer right vs. where I only verified

All six findings were confirmed correct on independent inspection — none
disputed. The one genuinely open call was I2's *shape*: the review's own
ruling (route `residentGpu` to `vertices` inside `DraftCanvas`, no assert)
was verified rather than taken on faith, by checking that an assert would
indeed have been a live landmine against `render_backend_test.dart`'s
GPU-present branch of `'an explicit backend is honoured, not clamped'` on any
environment where `gpuAvailable()` is genuinely true — confirming the ruling
was the safer shape, not just a stated preference.
