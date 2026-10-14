// One document and everything the plan library builds over it (spec 2a
// P1 lifetimes, P2 "Documents and views"): made when the controller opens
// a document, let go when it opens the next. Ported from PlannerShell's
// construction (planner_shell.dart:277-280, :428-437, :625-671, :1050-1057)
// and disposal (:1114-1170), and FloorPlanController's _Plan
// (floor_plan_controller.dart:67-99).
import 'dart:async';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/kit_set.dart';
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
      required SnapSettings snap})
      : page = PageNotifier(document),
        index = SpatialIndex(document),
        dispatch = GripDispatch(catalog) {
    // planner_shell.dart:625-671, the order load-bearing: the selection
    // prunes a dead key before the outline cache walks it; the grip cache
    // rebuilds after the outlines.
    selection = SelectionController(document);
    outlines = OutlineCache(document, selection);
    grips = GripCache(document, selection, outlines, objects: dispatch);
    toolContext = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page,
        snap: snap,
        grips: grips);
    tools = ToolController(initial: select, context: toolContext);
    _entries.add((id: planSelectToolId, tool: select, kit: false));
    // :1050-1057: the document arrives built; the system installs last.
    parametric = ParametricSystem(document, catalog, isFrozen: frozen.contains)
      ..install();
  }

  final DraftDocument document;
  final FlutterTextMeasurer measurer;

  /// E2's frozen objects (Task 11 fills it).
  final Set<Handle> frozen = {};

  final PageNotifier page;
  final SpatialIndex index;
  final GripDispatch dispatch;
  late final SelectionController selection;
  late final OutlineCache outlines;
  late final GripCache grips;
  late final ToolContext toolContext;
  final SelectTool select = SelectTool();
  late final ToolController tools;
  late final ParametricSystem parametric;
  final SharedCache shared = SharedCache();

  /// The registry until Task 14 runs the providers' factories.
  AttachmentRegistry attachments = const NoAttachments();

  /// The tools by id: select, then each kit's in load order (Task 12 adds
  /// the generic tools after select).
  final List<({String id, Tool tool, bool kit})> _entries = [];
  final List<Object> _providers = [];

  /// The document's change subscription, for the history flags.
  StreamSubscription<DocChange>? history;

  /// Registers a tool that is not a kit's (Task 12's generic tools).
  void addTool(String id, Tool tool) =>
      _entries.add((id: id, tool: tool, kit: false));

  /// Runs every kit's factories over this document, once (spec P1
  /// lifetimes): its tools, then its types' grip providers.
  void runKitFactories(KitSet kits, Map<String, PlanServices> services) {
    for (final kit in kits.kits) {
      final s = services[kit.id]!;
      for (final tool in kit.tools) {
        _entries.add((id: tool.id, tool: tool.create(s), kit: true));
      }
      for (final type in kit.types) {
        final provider = type.gripsFor(s);
        if (provider == null) continue;
        dispatch.add(type.id, provider);
        _providers.add(provider);
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
      if (p is Disposable) p.dispose();
    }
    _providers.clear();
    shared.dispose();
  }

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
    parametric.dispose();
    index.dispose();
    unawaited(document.dispose());
    measurer.clear();
  }
}
