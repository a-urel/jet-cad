import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../document/cad_document.dart';
import '../document/entity.dart';
import '../kernel/kernel_types.dart';
import 'texture_binding.dart';

/// Emitted on [ViewportController.selectionChanges] whenever the selection
/// set changes. Selection is view state: it never appears in the document's
/// change stream, operation list, or undo history.
class SelectionChanged {
  final Set<EntityId> selection;
  const SelectionChanged(this.selection);
}

/// Drives one viewport for one [CadDocument]: texture lifecycle, camera,
/// pick/selection, and damage-driven rendering.
///
/// Damage model: a frame is drawn only on document changes, camera changes,
/// selection changes, or resize — never per-vsync. [textureId] flips from
/// null once the platform texture is registered ([notifyListeners]).
class ViewportController extends ChangeNotifier {
  ViewportController({
    required this.document,
    TextureBinding binding = const TextureBinding(),
  }) : _binding = binding {
    _docSubscription = document.changes.listen((_) => requestRender());
  }

  static const Duration _resizeDebounce = Duration(milliseconds: 100);

  final CadDocument document;
  final TextureBinding _binding;

  final StreamController<SelectionChanged> _selectionController =
      StreamController.broadcast();
  StreamSubscription<void>? _docSubscription;

  int? _textureId;
  Set<EntityId> _selection = const {};
  Size? _appliedLogicalSize;
  double _dpr = 1.0;
  Size? _pendingLogicalSize;
  double _pendingDpr = 1.0;
  Timer? _resizeTimer;
  bool _attaching = false;
  bool _rendering = false;
  bool _renderQueued = false;
  bool _disposed = false;

  int? get textureId => _textureId;
  Set<EntityId> get selection => Set.unmodifiable(_selection);
  Stream<SelectionChanged> get selectionChanges => _selectionController.stream;

  /// Called by the widget on every layout. First call attaches (register +
  /// fit + render); later size/dpr changes debounce into a reallocation.
  void handleLayout(Size logicalSize, double devicePixelRatio) {
    if (_disposed || logicalSize.isEmpty) return;
    if (_textureId == null) {
      if (_attaching) return;
      _attaching = true;
      unawaited(_attach(logicalSize, devicePixelRatio));
      return;
    }
    if (logicalSize == _appliedLogicalSize && devicePixelRatio == _dpr) {
      return;
    }
    _pendingLogicalSize = logicalSize;
    _pendingDpr = devicePixelRatio;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(_resizeDebounce, () => unawaited(_applyResize()));
  }

  Future<void> _attach(Size logicalSize, double devicePixelRatio) async {
    try {
      _dpr = devicePixelRatio;
      _appliedLogicalSize = logicalSize;
      final surfaceId = await document.bridge.resizeViewport(
        document.session,
        (logicalSize.width * devicePixelRatio).round(),
        (logicalSize.height * devicePixelRatio).round(),
        devicePixelRatio,
      );
      final textureId = await _binding.registerTexture(surfaceId);
      if (_disposed) {
        await _binding.unregisterTexture(textureId);
        return;
      }
      _textureId = textureId;
      await document.bridge.fitAll(document.session);
      await requestRender();
      notifyListeners();
    } finally {
      _attaching = false;
    }
  }

  Future<void> _applyResize() async {
    final logicalSize = _pendingLogicalSize;
    final textureId = _textureId;
    if (_disposed || logicalSize == null || textureId == null) return;
    _appliedLogicalSize = logicalSize;
    _dpr = _pendingDpr;
    final surfaceId = await document.bridge.resizeViewport(
      document.session,
      (logicalSize.width * _dpr).round(),
      (logicalSize.height * _dpr).round(),
      _dpr,
    );
    if (_disposed) return;
    await _binding.updateSurface(textureId, surfaceId);
    await requestRender();
  }

  /// Renders one frame and signals the compositor. Coalescing: calls that
  /// arrive while a render is in flight fold into a single trailing render.
  Future<void> requestRender() async {
    if (_disposed || _textureId == null) return;
    if (_rendering) {
      _renderQueued = true;
      return;
    }
    _rendering = true;
    try {
      do {
        _renderQueued = false;
        await document.bridge.renderFrame(document.session);
        final textureId = _textureId;
        if (textureId != null) {
          await _binding.frameReady(textureId);
        }
      } while (_renderQueued && !_disposed);
    } finally {
      _rendering = false;
    }
  }

  Offset _physical(Offset logical) => logical * _dpr;

  Future<void> orbitStart(Offset logicalPos) async {
    if (_disposed) return;
    final p = _physical(logicalPos);
    await document.bridge.orbitStart(document.session, p.dx, p.dy);
  }

  Future<void> orbitTo(Offset logicalPos) async {
    if (_disposed) return;
    final p = _physical(logicalPos);
    await document.bridge.orbit(document.session, p.dx, p.dy);
    await requestRender();
  }

  Future<void> panBy(Offset logicalDelta) async {
    if (_disposed) return;
    final d = _physical(logicalDelta);
    await document.bridge.pan(document.session, d.dx, d.dy);
    await requestRender();
  }

  Future<void> zoomBy(double factor) async {
    if (_disposed) return;
    await document.bridge.zoom(document.session, factor);
    await requestRender();
  }

  Future<void> fitAll() async {
    if (_disposed) return;
    await document.bridge.fitAll(document.session);
    await requestRender();
  }

  /// Picks at [logicalPos]; a hit selects that entity, a miss clears the
  /// selection. Emits [SelectionChanged] on every call (CAD idiom: clicking
  /// empty space deselects, and listeners want to know).
  Future<void> selectAt(Offset logicalPos,
      {PickFilter filter = PickFilter.body}) async {
    if (_disposed) return;
    final p = _physical(logicalPos);
    final hit =
        await document.bridge.pick(document.session, p.dx, p.dy, filter);
    await setSelection({if (hit != null) hit.entity});
  }

  /// Replaces the selection and highlights it. Selection never touches the
  /// document: no DocChange, no undo entry.
  Future<void> setSelection(Set<EntityId> ids) async {
    if (_disposed) return;
    _selection = Set.of(ids);
    await document.bridge.setSelection(document.session, _selection.toList());
    await requestRender();
    _selectionController.add(SelectionChanged(selection));
  }

  /// Releases viewport resources. The document is NOT disposed — the caller
  /// owns it. Idempotent.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    _docSubscription?.cancel();
    _docSubscription = null;
    final textureId = _textureId;
    _textureId = null;
    if (textureId != null) {
      // Best-effort platform cleanup; failures have nowhere to go.
      unawaited(
          _binding.unregisterTexture(textureId).catchError((Object _) {}));
    }
    _selectionController.close();
    super.dispose();
  }
}
