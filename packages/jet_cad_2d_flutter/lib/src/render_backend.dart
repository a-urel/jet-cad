import 'gpu/gpu_facade.dart' show gpuAvailable;

/// Which sink `DraftCanvas` draws through.
///
/// An enum and not a `bool` because a third backend is foreseeable —
/// `flutter_gpu` ships in the SDK — and because a `bool` named for one of the
/// two options reads wrong the moment there is a third.
enum RenderBackend {
  /// `CanvasDrawSink`: one `drawPath` per primitive. No longer any
  /// platform's default — see [defaultRenderBackend] — but kept as the
  /// fallback an explicit `backend:` argument can still choose.
  canvas,

  /// `VerticesDrawSink`: the frame's strokes as one ordered `drawVertices`.
  /// The default on every platform, web included.
  vertices,

  /// The GPU-resident backend: the document's geometry uploaded once, the
  /// camera a uniform, one instanced draw call per frame.
  ///
  /// **Never a default and never automatic.** It is chosen explicitly, and
  /// [resolveBackend] routes it back to [vertices] on a platform without
  /// Flutter GPU rather than throwing per frame.
  ///
  /// **Wiring a GPU-resident sink into `DraftCanvas` is Plan F's work.**
  /// [resolveBackend] answers only the platform-capability question above;
  /// it does not decide what the widget paints through. Until Plan F,
  /// `DraftCanvas` renders this value — including on a platform where
  /// [resolveBackend] leaves it as `residentGpu` because a GPU is actually
  /// present — the same way it renders [vertices]: there is no GPU-resident
  /// sink yet, and painting through `CanvasDrawSink` instead would be a
  /// regression to the backend this enum's doc already calls "no longer any
  /// platform's default".
  residentGpu,
}

/// The backend a platform gets when the caller does not say.
///
/// **The only place this decision is made.** Two call sites that each decided
/// would eventually disagree, and the disagreement would show as a drawing
/// that changes when a widget is rebuilt somewhere unrelated.
///
/// Unconditional since Plan 3d Phase C measured the web. The desktop rows
/// (Task 12, macOS profile, median of 3, build p50 / raster p50) showed no
/// crossover — 10,000: canvas 12.35 / 44.32 ms, vertices 5.71 / 6.68 ms;
/// 50,000: canvas 15.36 / 66.94 ms, vertices 7.07 / 8.53 ms; 500,000: canvas
/// 44.29 / 508.00 ms, vertices 17.44 / 21.64 ms. The web rows (Task 13,
/// CanvasKit via Chrome 151.0.7922.170, `flutter run -d chrome --profile`,
/// median of 3) held the same shape: 10,000 entities — canvas 117.80 /
/// 79.30 ms, vertices 6.80 / 1.40 ms (17.3x / 56.6x build/raster); 50,000 —
/// canvas 155.70 / 107.90 ms, vertices 8.90 / 1.80 ms (17.5x / 59.9x).
///
/// **Read the two tables as two separate confirmations, not one table
/// doubled.** They are not the same drawing — different viewport (web fits
/// 1200x723 @2, desktop whatever the driven window was), different leaf
/// counts (web 10k is 2111 screen-space leaves against desktop's 1664) — so
/// there is no sound per-platform multiplier between them. Within a
/// platform, `build` (Dart-side widget-to-displaylist cost, the same
/// Flutter framework code on both) is the trustworthy comparison and it is
/// what this default actually rests on: the 17.3x-17.5x web build ratio.
/// `raster` is not commensurable across platforms — CanvasKit's
/// `FrameTiming.rasterDuration` most likely ends at command submission
/// rather than completion, which is the only way web vertices can raster in
/// 1.40ms against desktop's 6.68ms while drawing 34% more geometry — so the
/// 56x-60x raster figures are not the number this decision leans on, even
/// though they point the same direction. CanvasKit's `drawVertices` was the
/// open question this default was written against; the within-platform
/// build ratio answers it.
RenderBackend defaultRenderBackend() => RenderBackend.vertices;

/// The backend that will actually run, given what the caller asked for.
///
/// **The fallback is here and nowhere else.** Two call sites that each decided
/// would eventually disagree — the reason [defaultRenderBackend] gives for
/// itself, applied to the same problem one layer up.
RenderBackend resolveBackend(RenderBackend requested) {
  if (requested != RenderBackend.residentGpu) return requested;
  return gpuAvailable() ? RenderBackend.residentGpu : RenderBackend.vertices;
}
