// One document and everything the plan library builds over it (spec 2a
// P1 lifetimes, P2 "Documents and views"): made when the controller opens
// a document, let go when it opens the next. Ported from PlannerShell's
// construction (planner_shell.dart:277-280, :428-437, :625-671, :1050-1057)
// and disposal (:1114-1170), and FloorPlanController's _Plan
// (floor_plan_controller.dart:67-99).
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/guard.dart';
import '../kits/kit_set.dart';
import '../kits/locks.dart';
import 'grip_dispatch.dart';
import 'services.dart';
import 'shared_cache.dart';

/// The plan library's own select tool (spec P1 reserved ids).
const String planSelectToolId = 'plan.select';

final class DocumentSession {
  DocumentSession(
      {required this.document,
      required this.measurer,
      required ParametricCatalog catalog,
      required CameraController camera,
      required SnapSettings snap,
      required bool Function(String kitId) kitLoaded,
      required ValueListenable<Set<Handle>> locked,
      required DiagnosticsLog log,
      required Tool Function(String kitId, String toolId, Tool tool) guard})
      : _log = log,
        _guard = guard,
        page = PageNotifier(document),
        index = SpatialIndex(document),
        dispatch = GripDispatch(catalog) {
    locks = LockSet.scan(document, kitLoaded);
    // planner_shell.dart:625-671, the order load-bearing: the selection
    // prunes a dead key before the outline cache walks it; the gates
    // listen to the selection before the outline and grip caches do; the
    // grip cache rebuilds after the outlines.
    selection = SelectionController(document);
    lockGates = LockGates(selection: selection, locked: locked);
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines,
        objects: LockedGrips(locks,
            GuardedGrips(dispatch, typeIdOf: catalog.typeIdOf, log: log)),
        gates: lockGates);
    toolContext = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    select = SelectTool(gates: lockGates);
    // Every tool in the map is guarded (spec P4), the plan's own under the
    // kit id `plan`; the tool controller knows the guarded one.
    final guardedSelect = guard('plan', planSelectToolId, select);
    _entries.add((id: planSelectToolId, tool: guardedSelect, kit: false));
    tools = ToolController(initial: guardedSelect, context: toolContext);
    // :1050-1057: the document arrives built; the system installs last,
    // and the lock expander stacks after it.
    parametric = ParametricSystem(document, catalog, isFrozen: frozen.contains)
      ..install();
    lockExpander = LockExpander(document, locks)..install();
  }

  final DraftDocument document;
  final FlutterTextMeasurer measurer;
  final DiagnosticsLog _log;
  final Tool Function(String kitId, String toolId, Tool tool) _guard;

  /// The failure boundary of this document (spec P4; set once by the
  /// controller's `_open`). It holds no resource: it goes with its session.
  late final FailureBoundary boundary;

  /// E2's frozen objects: the boundary fills it (Task 11).
  final Set<Handle> frozen = {};

  final PageNotifier page;
  final SpatialIndex index;
  final GripDispatch dispatch;
  late final SelectionController selection;
  late final OutlineCache outlines;
  late final GripCache grips;
  late final ToolContext toolContext;

  /// The plan's select tool, unguarded (its `deleteSelection`); the map and
  /// the tool controller hold it guarded.
  late final SelectTool select;
  late final ToolController tools;
  late final ParametricSystem parametric;

  /// The document's lock set, expander and select gates (spec P4).
  late final LockSet locks;
  late final LockExpander lockExpander;
  late final LockGates lockGates;
  final SharedCache shared = SharedCache();

  /// The registry until Task 14 runs the providers' factories.
  AttachmentRegistry attachments = const NoAttachments();

  /// The tools by id: select, then each kit's in load order (Task 12 adds
  /// the generic tools after select).
  final List<({String id, Tool tool, bool kit})> _entries = [];
  final List<({String kitId, String typeId, Object provider})> _providers = [];

  /// The document's change subscription, for the history flags.
  StreamSubscription<DocChange>? history;

  /// Registers a tool that is not a kit's (Task 12's generic tools).
  void addTool(String id, Tool tool) =>
      _entries.add((id: id, tool: _guard('plan', id, tool), kit: false));

  /// Runs every kit's factories over this document, once (spec P1
  /// lifetimes): its tools, then its types' grip providers. A factory that
  /// throws is reported and leaves its product out (spec P4): a tool's id
  /// joins [disabled]; a type has no grips.
  void runKitFactories(
      KitSet kits, Map<String, PlanServices> services, Set<String> disabled) {
    for (final kit in kits.kits) {
      final s = services[kit.id]!;
      for (final tool in kit.tools) {
        final made = guardFactory(kit.id, tool.id, () => tool.create(s), _log);
        if (made == null) {
          disabled.add(tool.id);
          continue;
        }
        _entries
            .add((id: tool.id, tool: _guard(kit.id, tool.id, made), kit: true));
      }
      for (final type in kit.types) {
        final provider = guardFactory(
            kitOfKey(type.id), type.id, () => type.gripsFor(s), _log);
        if (provider == null) continue;
        dispatch.add(type.id, provider);
        _providers.add(
            (kitId: kitOfKey(type.id), typeId: type.id, provider: provider));
      }
    }
  }

  Tool? toolById(String id) {
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].id == id) return _entries[i].tool;
    }
    return null;
  }

  /// [tool]'s id; select's for a tool this session does not hold.
  String idOf(Tool tool) {
    for (var i = 0; i < _entries.length; i++) {
      if (identical(_entries[i].tool, tool)) return _entries[i].id;
    }
    return planSelectToolId;
  }

  /// Spec P1 lifetimes, 2: the kit tools, the grip (and, Task 14,
  /// attachment) providers and the shared cache disposed, in that order.
  /// The active tool must be select already.
  void disposeKitProducts() {
    for (final e in _entries) {
      if (e.kit) e.tool.dispose();
    }
    _entries.removeWhere((e) => e.kit);
    dispatch.close();
    for (final p in _providers) {
      final provider = p.provider;
      if (provider is Disposable) {
        _disposeGuarded(p.kitId, p.typeId, provider);
      }
    }
    _providers.clear();
    shared.dispose(
        onError: (kitId, error) => _disposeFailed(kitId, null, error));
  }

  /// [value]'s `dispose`, a kit's: what it throws is reported, so a swap
  /// completes (spec P4).
  void _disposeGuarded(String kitId, String subject, Disposable value) {
    try {
      value.dispose();
    } catch (error) {
      _disposeFailed(kitId, subject, error);
    }
  }

  void _disposeFailed(String kitId, String? subject, Object error) =>
      _log.add(KitDiagnostic(
          kitId: kitId,
          subject: subject,
          code: KitDiagnosticCode.hookFailed,
          message: 'dispose: $error',
          error: error));

  /// Stops listening to the document.
  void detach() {
    final h = history;
    history = null;
    if (h != null) unawaited(h.cancel());
  }

  /// Everything else, after the frame that unmounts its views
  /// (planner_shell.dart:1114-1170): the tool controller before the tools,
  /// the grip cache before the outlines and the selection, the system and
  /// the index before the document.
  void dispose() {
    tools.dispose();
    for (final e in _entries) {
      e.tool.dispose();
    }
    _entries.clear();
    grips.dispose();
    outlines.dispose();
    selection.dispose();
    page.dispose();
    lockGates.dispose();
    lockExpander.dispose();
    parametric.dispose();
    index.dispose();
    unawaited(document.dispose());
    measurer.clear();
  }
}
