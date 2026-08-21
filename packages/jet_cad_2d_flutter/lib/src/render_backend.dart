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
/// median of 3) went further, not merely holding: 10,000 entities — canvas
/// 117.80 / 79.30 ms, vertices 6.80 / 1.40 ms (17.3x / 56.6x); 50,000 —
/// canvas 155.70 / 107.90 ms, vertices 8.90 / 1.80 ms (17.5x / 59.9x).
/// CanvasKit's `drawVertices` was the open question this default was
/// written against; it is answered now, and by a wider margin than the
/// desktop numbers that motivated the design.
RenderBackend defaultRenderBackend() => RenderBackend.vertices;
