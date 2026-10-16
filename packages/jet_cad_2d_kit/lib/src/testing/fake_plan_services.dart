// Spec 3a C1.11: a PlanServices for a kit's tests, over a given document,
// with the plan library's rules where a kit can see them (settingsOf's
// refusals, shared's one per type and its disposal order).
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show CameraController, ViewportTransform;

import '../kit/attachment.dart';
import '../kit/plan_services.dart';
import '../kit/symbols_state.dart';
import '../model/kit_names.dart';

/// A [PlanServices] over [document] for a kit's tests (spec 3a C1.11):
/// - [index]: a `SpatialIndex` over [document], made here;
/// - [camera]: world to screen at `scale` pixels per unit (positive and
///   finite), y up, the world origin at the screen's;
/// - [objectSnap]: as given, for the fake's life;
/// - [attachments]: the registry given, else one with no kind;
/// - [words]: `names` at `locale`, numbers with `decimalSeparator`;
/// - [settingsOf]: `settings[toolId]`, the map given read at each call
///   (never copied), so a test changes a tool's settings between events;
///   a tool without settings there, or settings that are not an `S`, is
///   an [ArgumentError], as the plan's;
/// - [shared]: one per `T`, the first call's; a `T` asked for while it is
///   made is a [StateError]; the [Disposable] ones are disposed by
///   [dispose], last made first;
/// - [symbolDefinition]: null (no library); [symbolsState]: ready;
/// - [liveTypeIdOf]: `catalog`'s `typeIdOf`, null for a handle in `frozen`
///   and without a catalog.
///
/// [dispose] releases the index, the camera, the state and the shared
/// objects; [document] is the caller's.
final class FakePlanServices implements PlanServices {
  FakePlanServices({
    required this.document,
    ParametricCatalog? catalog,
    Set<Handle> frozen = const {},
    double scale = 1,
    this.objectSnap = true,
    KitNames names = KitNames.empty,
    Locale locale = const Locale('en'),
    String decimalSeparator = '.',
    Map<String, Object> settings = const {},
    AttachmentRegistry? attachments,
  })  : _catalog = catalog,
        _frozen = frozen,
        _settings = settings,
        attachments = attachments ?? const _NoAttachments(),
        index = SpatialIndex(document),
        camera = CameraController(ViewportTransform(
            worldToScreenMatrix: Transform2(scale, 0, 0, -scale, 0, 0))),
        words = KitNamesWords(names, () => locale,
            decimalSeparator: () => decimalSeparator);

  final ParametricCatalog? _catalog;
  final Set<Handle> _frozen;
  final Map<String, Object> _settings;

  @override
  final DraftDocument document;

  @override
  final SpatialIndex index;

  @override
  final CameraController camera;

  @override
  final bool objectSnap;

  @override
  final AttachmentRegistry attachments;

  @override
  final KitWords words;

  final ValueNotifier<SymbolsState> _symbolsState =
      ValueNotifier(SymbolsState.ready);
  final Map<Type, Object> _shared = {};
  final List<Object> _made = [];
  final Set<Type> _making = {};
  bool _disposed = false;

  @override
  S settingsOf<S extends Object>(String toolId) {
    final value = _settings[toolId];
    if (value == null) {
      throw ArgumentError.value(toolId, 'toolId', 'has no settings here');
    }
    if (value is! S) {
      throw ArgumentError.value(
          toolId, 'toolId', 'has settings of ${value.runtimeType}, not $S');
    }
    return value;
  }

  @override
  T shared<T extends Object>(T Function(PlanServices) create) {
    if (_disposed) throw StateError('shared<$T> after dispose');
    final found = _shared[T];
    if (found != null) return found as T;
    if (!_making.add(T)) {
      throw StateError('shared<$T> asked for itself while being made');
    }
    try {
      final made = create(this);
      _shared[T] = made;
      _made.add(made);
      return made;
    } finally {
      _making.remove(T);
    }
  }

  @override
  SymbolDefinitionRef? symbolDefinition(String key) => null;

  @override
  ValueListenable<SymbolsState> get symbolsState => _symbolsState;

  @override
  String? liveTypeIdOf(Handle handle) =>
      _frozen.contains(handle) ? null : _catalog?.typeIdOf(document, handle);

  /// Disposes the shared [Disposable]s, last made first, then the index,
  /// the camera and the state. Once only.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final value in _made.reversed) {
      if (value is Disposable) value.dispose();
    }
    _made.clear();
    _shared.clear();
    index.dispose();
    camera.dispose();
    _symbolsState.dispose();
  }
}

/// No kind, no attachment.
final class _NoAttachments implements AttachmentRegistry {
  const _NoAttachments();

  @override
  Set<String> get kinds => const {};

  @override
  Attachment? attach(List<String> kinds, AttachmentQuery query) => null;
}
