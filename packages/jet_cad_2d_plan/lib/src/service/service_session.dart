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

import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, VoidCallback;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:meta/meta.dart' show internal;

import '../kits/guard.dart';
import '../kits/locks.dart';
import '../units/unit_index.dart';
import '../units/unit_label_system.dart';
import 'service_state.dart' show UnitGroup;
import 'service_tool.dart';
import 'unit_picker.dart' show UnitPicker;

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
  /// session with what its boundary found. [groups] are the controller's
  /// unit groups and [moves] its `serviceMove`, both read by the service
  /// tool at each call; without them: no group, moves allowed (a session a
  /// test builds).
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
    ValueListenable<Map<String, UnitGroup>>? groups,
    bool Function()? moves,
    Set<Handle> Function(DraftDocument document, Handle object)? referencesOf,
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
        damage: (error) => damage(this, error),
        referencesOf: referencesOf);
    // As the design's (plan_controller.dart's `_open`): a hook failure is
    // probed, frozen and retried once.
    lockExpander
      ..onHookFailure = boundary.recover
      ..onPartialMutation = boundary.partialMutation
      ..onRefusedEdit = boundary.recoverRefused
      ..onRetryFailed = boundary.retryFailed;
    // Last but the tool, as the design's (session.dart): it listens to
    // [locked], so no later step can throw and leak the listener.
    units = UnitIndexCache(document,
        catalog: catalog, locks: locks, locked: locked);
    // The picker reads [units], so the tool comes after it; neither
    // constructor, nor the tool controller's, can throw.
    picker = UnitPicker(document, units);
    tool = ServiceTool(
        picker: picker,
        groups: groups ?? _noGroups,
        callbacks: () => host.callbacks(),
        options: () => host.options(),
        moves: moves ?? _always,
        userCamera: () => host.userCamera(),
        toGlobal: (local) => host.toGlobal(local),
        events: () => host.events(),
        idleKeys: () => host.idleKeys());
    tools = ToolController(initial: tool, context: toolContext);
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

  /// The service tool (2b S4), the tool controller's one tool.
  late final ServiceTool tool;

  /// The copy's picker: a locked unit and a seat are picked (spec S2, S4).
  @internal
  late final UnitPicker picker;

  /// What the tool reads from the view that shows this session, at each
  /// call: the view sets it while its canvas is mounted and puts
  /// [ServiceHost.none] back when it goes (Task 16).
  @internal
  ServiceHost host = ServiceHost.none;

  static final ValueNotifier<Map<String, UnitGroup>> _noGroups =
      ValueNotifier(const <String, UnitGroup>{});
  static bool _always() => true;

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
