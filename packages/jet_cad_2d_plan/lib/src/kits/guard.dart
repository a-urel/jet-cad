// Spec P4 "The failure boundary" (umbrella A9): every kit hook is called at
// the contract's boundary. A kit's ParametricType is wrapped in
// [GuardedType], which rethrows what a hook throws as [KitHookFailure];
// its tools in [GuardedTool]; its grips, attachment providers, factories
// and sections in guarded calls. [FailureBoundary] is the controller's
// flow after a failed edit: probe the type's objects (E2), freeze and lock
// the failing ones, retry once; and the load's check. [DiagnosticsLog]
// keeps one diagnostic per kit, subject and code.
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../controller/diagnostics_log.dart';
import 'locks.dart' show PlanLocked;

export '../controller/diagnostics_log.dart' show DiagnosticsLog;

/// A kit's [ParametricType] hook threw [error]: [hook] of [typeId], in
/// [kitId]. The engine rolls the edit back and rethrows it unchanged.
final class KitHookFailure implements Exception {
  const KitHookFailure(this.kitId, this.typeId, this.hook, this.error);

  final String kitId;
  final String typeId;
  final String hook;
  final Object error;

  @override
  String toString() => 'KitHookFailure: $typeId.$hook threw $error';
}

/// [inner] with every member called at the boundary: what it throws is
/// rethrown as a [KitHookFailure] naming [kitId], [typeId] and the member
/// (a [KitHookFailure] from a nested call, another type's hook asked
/// through the view, keeps its own attribution). `implements`, not
/// `extends`: a member the engine adds later is a compile error here, never
/// a silently unguarded default. One `try` around one call per member: no
/// allocation in the happy path.
final class GuardedType<T extends Component> implements ParametricType<T> {
  const GuardedType(this.kitId, this.typeId, this.inner);

  final String kitId;
  final String typeId;
  final ParametricType<T> inner;

  Never _fail(String hook, Object error, StackTrace stack) =>
      Error.throwWithStackTrace(
          KitHookFailure(kitId, typeId, hook, error), stack);

  @override
  Capability get editCapability {
    try {
      return inner.editCapability;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('editCapability', e, s);
    }
  }

  @override
  Aabb2 reach(T params, Transform2 toWorld) {
    try {
      return inner.reach(params, toWorld);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('reach', e, s);
    }
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    try {
      return inner.generate(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('generate', e, s);
    }
  }

  @override
  List<GeneratedInstance> instances(ParametricView view, Handle self) {
    try {
      return inner.instances(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('instances', e, s);
    }
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) {
    try {
      return inner.diagnose(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('diagnose', e, s);
    }
  }

  @override
  Iterable<Handle> references(T params) {
    try {
      return inner.references(params);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('references', e, s);
    }
  }

  @override
  ReferencePolicy get referencePolicy {
    try {
      return inner.referencePolicy;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('referencePolicy', e, s);
    }
  }

  @override
  Object? pageKey(PageComponent? page) {
    try {
      return inner.pageKey(page);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('pageKey', e, s);
    }
  }

  @override
  bool dissolves(ParametricView view, Handle self) {
    try {
      return inner.dissolves(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('dissolves', e, s);
    }
  }

  @override
  bool get contributesPlace {
    try {
      return inner.contributesPlace;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('contributesPlace', e, s);
    }
  }

  @override
  Aabb2? placeBox(ParametricView view, Handle self) {
    try {
      return inner.placeBox(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('placeBox', e, s);
    }
  }

  @override
  Object placeInput(ParametricView view, Handle self) {
    try {
      return inner.placeInput(view, self);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('placeInput', e, s);
    }
  }

  @override
  bool get readsPlaces {
    try {
      return inner.readsPlaces;
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('readsPlaces', e, s);
    }
  }

  @override
  Aabb2 readBox(T params, Transform2 toWorld, Aabb2 stored) {
    try {
      return inner.readBox(params, toWorld, stored);
    } on KitHookFailure {
      rethrow;
    } catch (e, s) {
      _fail('readBox', e, s);
    }
  }
}

/// The plan library's [TypeGuard]: `PlanType.registerInto(catalog, guard:)`
/// wraps the kit's type in a [GuardedType] of the same `T`.
final class PlanTypeGuard implements TypeGuard {
  const PlanTypeGuard();

  @override
  ParametricType<T> wrap<T extends Component>(
          String kitId, String typeId, ParametricType<T> type) =>
      GuardedType<T>(kitId, typeId, type);
}

/// [create]'s product, or null when it throws: the failure is reported as
/// [subject]'s (a tool id, a type id), and the caller disables what the
/// factory would have made (spec table: "a tool's factory: the tool is
/// disabled").
T? guardFactory<T extends Object?>(
    String kitId, String subject, T Function() create, DiagnosticsLog log) {
  try {
    return create();
  } catch (error) {
    log.add(KitDiagnostic(
        kitId: kitId,
        subject: subject,
        code: KitDiagnosticCode.hookFailed,
        message: 'factory: $error',
        error: error));
    return null;
  }
}

/// Every armed tool, generic or a kit's, behind the boundary (spec P4).
///
/// - [PlanLocked] and `DanglingReferenceError` (E2's refusal of a frozen
///   object's `cascade` referrer) are refusals: the hint is set and the
///   inner's gesture cancelled; no diagnostic.
/// - A [KitHookFailure] is its kit's: a diagnostic, the inner cancelled,
///   [onFailed] (the controller arms `plan.select`).
/// - Anything else a kit tool throws is a diagnostic of [toolId], the
///   inner cancelled, [onFailed]; a generic tool's (kit id `plan`) is
///   rethrown unchanged, as today (`select_tool.dart:546-550`).
/// - A paint that throws is skipped, reported after the frame, and the tool
///   is given to [onFailed] after the frame; it paints nothing until it is
///   cancelled.
///
/// Owns [inner]: [dispose] disposes it (a kit's that throws is reported).
final class GuardedTool extends Tool {
  GuardedTool({
    required this.inner,
    required this.kitId,
    required this.toolId,
    required this.log,
    required this.lockHint,
    required this.onFailed,
  }) {
    inner.addListener(_forward);
  }

  final Tool inner;
  final String kitId;
  final String toolId;
  final DiagnosticsLog log;
  final ValueNotifier<bool> lockHint;
  final VoidCallback onFailed;

  bool _broken = false;

  bool get _isKit => kitId != 'plan';

  void _forward() => notifyListeners();

  KitDiagnostic _diagnostic(Object error) => KitDiagnostic(
      kitId: kitId,
      subject: toolId,
      code: KitDiagnosticCode.hookFailed,
      message: '$error',
      error: error);

  /// A getter's failure: a generic tool's is rethrown; a kit's is reported
  /// after the frame (a getter may be read in a build or a paint).
  void _getterFailed(Object error, StackTrace stack) {
    if (!_isKit) Error.throwWithStackTrace(error, stack);
    log.addAfterFrame(_diagnostic(error));
  }

  void _cancelInner(ToolContext ctx) {
    try {
      inner.cancel(ctx);
    } catch (error, stack) {
      if (!_isKit) Error.throwWithStackTrace(error, stack);
      log.add(_diagnostic(error));
    }
  }

  void _failed(Object error, StackTrace stack, ToolContext ctx) {
    if (error is PlanLocked || error is DanglingReferenceError) {
      lockHint.value = true;
      _cancelInner(ctx);
      return;
    }
    if (error is KitHookFailure) {
      log.add(KitDiagnostic(
          kitId: error.kitId,
          subject: error.typeId,
          code: KitDiagnosticCode.hookFailed,
          message: '${error.hook}: ${error.error}',
          error: error.error));
    } else if (_isKit) {
      log.add(_diagnostic(error));
    } else {
      Error.throwWithStackTrace(error, stack);
    }
    _cancelInner(ctx);
    onFailed();
  }

  void _paintFailed(Object error, StackTrace stack) {
    if (!_isKit) Error.throwWithStackTrace(error, stack);
    _broken = true;
    log.addAfterFrame(_diagnostic(error));
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => onFailed())
      ..ensureVisualUpdate();
  }

  @override
  String get name {
    try {
      return inner.name;
    } catch (e, s) {
      _getterFailed(e, s);
      return toolId;
    }
  }

  @override
  ToolPhase get phase {
    try {
      return inner.phase;
    } catch (e, s) {
      _getterFailed(e, s);
      return ToolPhase.idle;
    }
  }

  @override
  TouchPress get touchPress {
    try {
      return inner.touchPress;
    } catch (e, s) {
      _getterFailed(e, s);
      return TouchPress.lift;
    }
  }

  @override
  bool get isMidShape {
    try {
      return inner.isMidShape;
    } catch (e, s) {
      _getterFailed(e, s);
      return false;
    }
  }

  @override
  MouseCursor get cursor {
    try {
      return inner.cursor;
    } catch (e, s) {
      _getterFailed(e, s);
      return MouseCursor.defer;
    }
  }

  @override
  Transform2? get selectionPreviewTransform {
    try {
      return inner.selectionPreviewTransform;
    } catch (e, s) {
      _getterFailed(e, s);
      return null;
    }
  }

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    try {
      inner.onPointerDown(e, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    try {
      inner.onPointerMove(e, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    try {
      inner.onPointerUp(e, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  void onPointerExit(ToolContext ctx) {
    try {
      inner.onPointerExit(ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
    }
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    try {
      return inner.onKey(event, ctx);
    } catch (error, stack) {
      _failed(error, stack, ctx);
      return KeyEventResult.ignored;
    }
  }

  @override
  void cancel(ToolContext ctx) {
    _broken = false;
    _cancelInner(ctx);
  }

  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {
    if (_broken) return;
    try {
      inner.paintOverlay(canvas, camera, viewport, paper);
    } catch (error, stack) {
      _paintFailed(error, stack);
    }
  }

  @override
  void paintWorldOverlay(
      Canvas canvas, Vector2 origin, double scale, PaperPalette paper) {
    if (_broken) return;
    try {
      inner.paintWorldOverlay(canvas, origin, scale, paper);
    } catch (error, stack) {
      _paintFailed(error, stack);
    }
  }

  /// Disposes [inner]; a kit tool's dispose that throws is reported, so a
  /// document swap completes (spec P4); a generic tool's is rethrown.
  @override
  void dispose() {
    inner.removeListener(_forward);
    try {
      inner.dispose();
    } catch (error, stack) {
      if (!_isKit) Error.throwWithStackTrace(error, stack);
      log.add(_diagnostic(error));
    }
    super.dispose();
  }
}

/// The grip provider behind the boundary: a call that throws is reported
/// (once per type, through [typeIdOf]) and that object has no grips, no
/// drag and does not move until the document is replaced (a drag in flight
/// is refused: its `drag` answers null).
final class GuardedGrips implements ObjectGripProvider {
  GuardedGrips(this._inner,
      {required String? Function(DraftDocument, Handle) typeIdOf,
      required DiagnosticsLog log})
      : _typeIdOf = typeIdOf,
        _log = log;

  final ObjectGripProvider _inner;
  final String? Function(DraftDocument, Handle) _typeIdOf;
  final DiagnosticsLog _log;
  final Set<Handle> _failed = {};

  void _fail(DraftDocument d, Handle group, String member, Object error) {
    _failed.add(group);
    String typeId;
    try {
      typeId = _typeIdOf(d, group) ?? 'plan';
    } catch (_) {
      typeId = 'plan';
    }
    _log.add(KitDiagnostic(
        kitId: kitOfKey(typeId),
        subject: typeId,
        code: KitDiagnosticCode.hookFailed,
        message: 'grips.$member: $error',
        error: error));
  }

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    if (_failed.contains(group)) return const [];
    try {
      return _inner.gripsOf(d, group);
    } catch (error) {
      _fail(d, group, 'gripsOf', error);
      return const [];
    }
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_failed.contains(group)) return null;
    try {
      return _inner.drag(d, group, grip, world);
    } catch (error) {
      _fail(d, group, 'drag', error);
      return null;
    }
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_failed.contains(group)) return const [];
    try {
      return _inner.preview(d, group, grip, world);
    } catch (error) {
      _fail(d, group, 'preview', error);
      return const [];
    }
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    if (_failed.contains(group)) return false;
    try {
      return _inner.movable(d, group);
    } catch (error) {
      _fail(d, group, 'movable', error);
      return false;
    }
  }
}

/// [provider]'s answer to [query], or null when it throws (spec table: an
/// attachment provider's failure is taken as no attachment), reported
/// under [kitId] and the provider's kind.
Attachment? guardAttachment(String kitId, AttachmentProvider provider,
    AttachmentQuery query, void Function(KitDiagnostic) report) {
  try {
    return provider.attach(query);
  } catch (error) {
    String kind;
    try {
      kind = provider.kind;
    } catch (_) {
      kind = 'attachment';
    }
    report(KitDiagnostic(
        kitId: kitId,
        subject: kind,
        code: KitDiagnosticCode.hookFailed,
        message: 'attach: $error',
        error: error));
    return null;
  }
}

/// The controller's flow after a kit's hook failed (spec P4), for one
/// document.
final class FailureBoundary {
  FailureBoundary({
    required this.document,
    required this.catalog,
    required this.system,
    required this.frozen,
    required this.log,
    required this.lock,
    required this.damage,
  });

  final DraftDocument document;
  final ParametricCatalog catalog;
  final ParametricSystem system;

  /// The set the system's `isFrozen` reads.
  final Set<Handle> frozen;
  final DiagnosticsLog log;

  /// The controller's `lockBroken`: locks and clears the history.
  final void Function(Set<Handle> objects) lock;

  /// The controller's damage handler (E3).
  final void Function(PartialMutationError error) damage;

  void _report(KitHookFailure f) => log.add(KitDiagnostic(
      kitId: f.kitId,
      subject: f.typeId,
      code: KitDiagnosticCode.hookFailed,
      message: '${f.hook}: ${f.error}',
      error: f.error));

  void _freeze(Set<Handle> objects) {
    frozen.addAll(objects);
    lock(objects);
  }

  /// [failure] reported; that type's objects probed, and the failing ones
  /// frozen and locked. True when one was: the edit is worth one retry.
  bool recover(KitHookFailure failure) {
    _report(failure);
    final broken = probeType(failure.typeId);
    if (broken.isEmpty) return false;
    _freeze(broken);
    return true;
  }

  /// The live, unfrozen root-level objects of [typeId] whose probe (E2)
  /// fails, ascending by the tree's order.
  Set<Handle> probeType(String typeId) {
    final broken = <Handle>{};
    final root = document.rootHandle;
    for (final node in document.tree.nodes) {
      if (node is! GroupNode || node.parent != root) continue;
      final h = node.handle;
      if (frozen.contains(h) || catalog.typeIdOf(document, h) != typeId) {
        continue;
      }
      if (system.probe(h) != null) broken.add(h);
    }
    return broken;
  }

  /// An edit failed on an error no kit hook threw (the planner refusing
  /// what a `generate` returned; final review, finding I2): every live kit
  /// object is probed, one by one, and the failing ones frozen and locked,
  /// each with its type's diagnostic. True when one was: the edit is worth
  /// one retry. False when none fails: the edit itself is refused.
  bool recoverRefused(Object error) {
    final broken = _probeAll();
    if (broken.isEmpty) return false;
    _freeze(broken);
    return true;
  }

  /// The retry after [recoverRefused] (or [recover]) failed again on an
  /// error no kit hook threw: the edit is refused, with one diagnostic.
  void retryFailed(Object error) => log.add(KitDiagnostic(
      kitId: 'plan',
      code: KitDiagnosticCode.hookFailed,
      message: 'an edit failed again after the objects that broke it were '
          'locked: $error',
      error: error));

  /// After a load: one dry run of the whole plan. While it throws, the
  /// objects to blame are frozen and locked, with their diagnostics, and it
  /// runs again: on a kit's hook failure, that type's failing objects; when
  /// those are none, or on an error no hook threw (the planner refusing
  /// what a `generate` returned, an engine invariant), every live kit
  /// object is probed, one by one (fix round 1). When no object's probe
  /// fails, the error is reported to [FlutterError.reportError] and the
  /// load goes on. Each round freezes at least one object or ends, so it
  /// ends.
  void probeLoaded() {
    while (true) {
      try {
        system.drift();
        return;
      } catch (error, stack) {
        var broken = const <Handle>{};
        if (error is KitHookFailure) {
          _report(error);
          broken = probeType(error.typeId);
        }
        if (broken.isEmpty) broken = _probeAll();
        if (broken.isEmpty) {
          FlutterError.reportError(FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'jet_cad_2d_plan',
              context: ErrorDescription("during the load's dry run of the "
                  'plan (no object\'s probe failed)')));
          return;
        }
        _freeze(broken);
      }
    }
  }

  /// Every live, unfrozen root-level kit object whose probe (E2) fails,
  /// each reported as its type's: the per-object check of a load whose dry
  /// run failed on no single type, and of an edit that failed on no hook.
  Set<Handle> _probeAll() {
    final broken = <Handle>{};
    final root = document.rootHandle;
    for (final node in document.tree.nodes) {
      if (node is! GroupNode || node.parent != root) continue;
      final h = node.handle;
      if (frozen.contains(h)) continue;
      final typeId = catalog.typeIdOf(document, h);
      if (typeId == null) continue;
      final error = system.probe(h);
      if (error == null) continue;
      broken.add(h);
      if (error is KitHookFailure) {
        _report(error);
      } else {
        log.add(KitDiagnostic(
            kitId: kitOfKey(typeId),
            subject: typeId,
            code: KitDiagnosticCode.hookFailed,
            message: '$error',
            error: error));
      }
    }
    return broken;
  }

  /// E4: each `component.unreadable` diagnostic of the load is reported as
  /// its kit's `componentUnreadable`, and its handles frozen and locked.
  void reportUnreadable(List<Diagnostic> loadDiagnostics) {
    final unreadable = <Handle>{};
    final registered = catalog.typeIds.toSet();
    for (final d in loadDiagnostics) {
      if (d.code != 'component.unreadable') continue;
      for (final h in d.handles) {
        final typeId = _typeOf(h, d.message, registered);
        log.add(KitDiagnostic(
            kitId: kitOfKey(typeId),
            subject: typeId,
            code: KitDiagnosticCode.componentUnreadable,
            message: d.message));
        unreadable.add(h);
      }
    }
    if (unreadable.isNotEmpty) _freeze(unreadable);
  }

  /// The registered type whose payload [h] kept raw, else the message's
  /// `<typeId>:` prefix (E4's message shape).
  String _typeOf(Handle h, String message, Set<String> registered) {
    for (final payload in document.components.unknownOf(h)) {
      final typeId = payload['typeId'];
      if (typeId is String && registered.contains(typeId)) return typeId;
    }
    final colon = message.indexOf(':');
    return colon > 0 ? message.substring(0, colon) : message;
  }

  /// E3: a rollback threw. Reported, then the controller rebuilds through
  /// `notifyLoaded` and marks the plan damaged.
  void partialMutation(PartialMutationError error) {
    log.add(KitDiagnostic(
        kitId: 'plan',
        code: KitDiagnosticCode.rollbackFailed,
        message: error.message,
        error: error));
    damage(error);
  }
}
