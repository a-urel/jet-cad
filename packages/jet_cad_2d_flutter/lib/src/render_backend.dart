import 'package:flutter/foundation.dart' show kIsWeb;

/// Which sink `DraftCanvas` draws through.
///
/// An enum and not a `bool` because a third backend is foreseeable —
/// `flutter_gpu` ships in the SDK — and because a `bool` named for one of the
/// two options reads wrong the moment there is a third.
enum RenderBackend {
  /// `CanvasDrawSink`: one `drawPath` per primitive. The web renderer, and the
  /// fallback everywhere.
  canvas,

  /// `VerticesDrawSink`: the frame's strokes as one ordered `drawVertices`.
  vertices,
}

/// The backend a platform gets when the caller does not say.
///
/// **The only place this decision is made.** Two call sites that each decided
/// would eventually disagree, and the disagreement would show as a drawing
/// that changes when a widget is rebuilt somewhere unrelated.
///
/// Web gets the canvas backend because Impeller is not on the web — the engine
/// FAQ records interfacing the web engine with Impeller as a non-goal — and
/// CanvasKit's `drawVertices` is unmeasured. Phase C measures it; until then
/// the platform that has no Impeller gets the path that never needed one.
RenderBackend defaultRenderBackend() =>
    kIsWeb ? RenderBackend.canvas : RenderBackend.vertices;
