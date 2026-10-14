// The service copy and everything over it (spec 2b S3 "Mode and copy"):
// the design's text decoded under runtime permissions, its parametric
// system over the guarded catalog and the design's frozen set, its unit
// label system, its lock expander over the design's lock set, its own
// failure boundary, its index, page, selection, outlines, unit index and
// tool controller. Today's service copy and its systems
// (jet_cad_floor_plan's floor_plan_controller.dart:1305-1319,
// host/service_view.dart:124-130, :242-245), built like 2a's
// DocumentSession (controller/session.dart:29-89).
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, VoidCallback;
import 'package:flutter/material.dart' show Canvas, KeyEventResult, Size;
import 'package:flutter/services.dart' show KeyEvent;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../kits/guard.dart';
import '../kits/locks.dart';
import '../units/unit_index.dart';
import '../units/unit_label_system.dart';

/// The controller's two modes (spec S3).
enum PlanMode {
  /// The editor over the plan the host loads and saves.
  design,

  /// A copy of the design under runtime permissions: units are tapped,
  /// selected, given statuses, grouped and moved; nothing done here
  /// reaches the design.
  service,
}

/// [design]'s text decoded as a service copy (today's `_copyOf`): under
/// `DraftPermissions.runtime` (transforms and components only), with
/// [register]'s components, a component the design keeps raw (E4) kept
/// raw. The handles are the design's.
DraftDocument serviceCopyOf(DraftDocument design,
        {required void Function(ComponentRegistry registry) register,
        required TextMeasurer measurer}) =>
    DraftDocumentCodec.decodeString(DraftDocumentCodec.encodeToString(design),
        measurer: measurer,
        permissions: DraftPermissions.runtime,
        diagnostics: <Diagnostic>[],
        keepUnreadableComponents: true,
        registerComponents: register);

/// The service copy and its systems and views (spec S3). Made when service
/// is entered (and by a load, a new plan, a reset or a restore in
/// service), disposed after the frame that unmounts its view.
final class ServiceSession {
  /// [locks] and [frozen] are the design session's own (the handles are
  /// the same in both documents); [lock] and [damage] receive this
  /// session with what its boundary found. The copy's one tool is an idle
  /// placeholder until Task 14's `ServiceTool`.
  ServiceSession({
    required this.document,
    required this.measurer,
    required ParametricCatalog catalog,
    required CameraController camera,
    required LockSet locks,
    required Set<Handle> frozen,
    required ValueListenable<Set<Handle>> locked,
    required DiagnosticsLog log,
    required void Function(ServiceSession session, Set<Handle> objects) lock,
    required void Function(ServiceSession session, PartialMutationError error)
        damage,
  })  : page = PageNotifier(document),
        index = SpatialIndex(document) {
    // The selection before the outlines (it prunes a dead key first), as
    // the design's (session.dart:49-56).
    selection = SelectionController(document);
    outlines = OutlineCache(document, selection);
    toolContext = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page);
    tool = _IdleTool();
    tools = ToolController(initial: tool, context: toolContext);
    // The design's stack (Task 7): parametric, unit labels, lock.
    parametric = ParametricSystem(document, catalog, isFrozen: frozen.contains)
      ..install();
    labels = UnitLabelSystem(document)..install();
    lockExpander = LockExpander(document, locks)..install();
    boundary = FailureBoundary(
        document: document,
        catalog: catalog,
        system: parametric,
        frozen: frozen,
        log: log,
        lock: (objects) => lock(this, objects),
        damage: (error) => damage(this, error));
    // As the design's (plan_controller.dart's `_open`): a hook failure is
    // probed, frozen and retried once.
    lockExpander
      ..onHookFailure = boundary.recover
      ..onPartialMutation = boundary.partialMutation
      ..onRefusedEdit = boundary.recoverRefused
      ..onRetryFailed = boundary.retryFailed;
    // Last, as the design's (session.dart): it listens to [locked], so no
    // later step can throw and leak the listener.
    units = UnitIndexCache(document,
        catalog: catalog, locks: locks, locked: locked);
  }

  /// The copy.
  final DraftDocument document;
  final FlutterTextMeasurer measurer;
  final PageNotifier page;
  final SpatialIndex index;
  late final SelectionController selection;
  late final OutlineCache outlines;

  /// The copy's units: what everything in service reads.
  late final UnitIndexCache units;
  late final ToolContext toolContext;

  /// The copy's one tool, which [tools] holds.
  late final Tool tool;
  late final ToolController tools;
  late final ParametricSystem parametric;
  late final UnitLabelSystem labels;
  late final LockExpander lockExpander;
  late final FailureBoundary boundary;

  /// The controller's subscription to the copy's changes, and its
  /// selection listener; [detach] drops both.
  StreamSubscription<DocChange>? history;
  VoidCallback? onSelection;

  bool get canUndo => document.commands.canUndo;
  bool get canRedo => document.commands.canRedo;

  /// Stops the controller listening, at once.
  void detach() {
    final h = history;
    history = null;
    if (h != null) unawaited(h.cancel());
    final l = onSelection;
    onSelection = null;
    if (l != null) selection.removeListener(l);
  }

  /// Everything, after the frame that unmounts the view: the tool
  /// controller before the tool, the outlines before the selection, the
  /// systems last in first out, the index before the document.
  void dispose() {
    tools.dispose();
    tool.dispose();
    outlines.dispose();
    selection.dispose();
    page.dispose();
    units.dispose();
    lockExpander.dispose();
    labels.dispose();
    parametric.dispose();
    index.dispose();
    unawaited(document.dispose());
    measurer.clear();
  }
}

/// The copy's tool until Task 14's service tool: it reacts to nothing.
final class _IdleTool extends Tool {
  @override
  String get name => 'plan.service';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}
