// The plan's canvas (spec 2a P2, "The widgets"): the rulers, the camera
// gestures, the interaction layer, the page chrome, the drawing, the
// selection and grip overlay and the text entry, over one PlanController,
// which is all it takes.
//
// Ported from jet_cad_floor_plan: the paper, the ink and the resolver from
// planner_shell.dart (:281-382), the canvas colour (:367-368), the
// fit-on-start latch from host/floor_plan_view.dart (:507, :595-602), and
// the view itself (PlanCanvasView, planner_view.dart). New: the one-canvas
// rule, the controller's document swap, the locale push, the snapping
// option and the lock hint (spec P4, "Where PlanLocked is caught").
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../controller/plan_controller.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';
import '../theme/plan_theme.dart' show PlanTheme, planPaperPaletteFor;
import '../tools/generic_tools.dart' show PlanToolIds;
import 'plan_canvas_view.dart';

/// How long the canvas shows the lock hint before it clears it.
const Duration kLockHintDuration = Duration(seconds: 2);

/// Draws [controller]'s plan and routes the pointer and the keys to its
/// active tool.
///
/// - The plan is fitted to the drawing area on its first frame, and again
///   on the first frame of each plan `load`, `newPlan` or `import` swaps in.
/// - A controller is shown in one PlanCanvas at a time: a second one
///   asserts in debug, after the frame. When the last canvas showing it
///   goes, any shape in progress is cancelled and plan.select armed, after
///   that frame; the controller's tools stay usable with no canvas.
/// - [rulers] and [grid] are the drafting aids; [snapping] lets object snap
///   act (the user's F3 setting is kept either way); [autofocus] lets the
///   canvas take the focus when it is mounted.
class PlanCanvas extends StatefulWidget {
  const PlanCanvas({
    super.key,
    required this.controller,
    this.rulers = true,
    this.grid = true,
    this.snapping = true,
    this.autofocus = true,
  });

  final PlanController controller;
  final bool rulers;
  final bool grid;
  final bool snapping;
  final bool autofocus;

  @override
  State<PlanCanvas> createState() => _PlanCanvasState();
}

/// The canvases one controller is shown in, and whether the check after
/// the frame is already scheduled: one check per controller and frame, so
/// two canvases of one controller report once.
final class _Shown {
  final Set<Object> canvases = <Object>{};
  bool checkScheduled = false;
}

/// Each controller's [_Shown], for the one-canvas rule (debug only).
final Expando<_Shown> _canvasesOf = Expando<_Shown>('PlanCanvas');

/// How many canvases show each controller now (every build mode): a
/// canvas that goes leaves its controller's tool alone while another
/// shows it.
final Expando<int> _mountedOf = Expando<int>('PlanCanvas.mounted');

/// [c] is shown by no canvas any more (RV6, today's tool withdrawal,
/// floor_plan_controller.dart:731-737): any shape in progress is cancelled
/// and plan.select armed. After the frame, as today's `toolChanged`: the
/// canvas goes while the tree is locked, where a host's listener of
/// `activeTool` may not rebuild. Nothing when a canvas shows [c] again by
/// then, or [c] is disposed.
void _withdrawTool(PlanController c) {
  SchedulerBinding.instance
    ..addPostFrameCallback((_) {
      if (c.isDisposed || (_mountedOf[c] ?? 0) > 0) return;
      final tools = c.toolController;
      if (c.activeTool.value == PlanToolIds.select) {
        // A drag or a band of the select tool is its shape in progress.
        tools.active.cancel(tools.context);
      } else {
        c.selectTool(PlanToolIds.select);
      }
    })
    ..ensureVisualUpdate();
}

class _PlanCanvasState extends State<PlanCanvas> {
  PlanController get _c => widget.controller;

  /// The document the resolver, the page listener and the fit latch belong
  /// to; [_bind] moves them to the controller's current one.
  DraftDocument? _document;
  PageNotifier? _page;

  /// ACI 7's foreground follows the paper (planner_shell.dart:281-299):
  /// replaced only when its key ([_foreground], [_darkCanvas]) changes, as
  /// DraftCanvas rebuilds its painter whenever it is handed a different
  /// resolver.
  late StyleResolver _resolver;
  int _foreground = -1;
  bool _darkCanvas = false;

  /// The theme's surface (or the theme's `canvasBackground`) and
  /// brightness; set in [didChangeDependencies].
  late int _surfaceArgb;
  late Brightness _brightness;
  PlanTheme? _theme;

  final GesturePolicy _policy = GesturePolicy.forPlatform();

  /// floor_plan_view.dart:507, :595-602: the fit-on-start latch, taken once
  /// per document.
  DraftDocument? _fitFor;
  bool _fit = false;
  bool _fitIsRequest = false;

  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _enter(_c);
    _c.addListener(_onController);
    _c.lockHint.addListener(_onHint);
    // A hint set before this canvas heard it (a refusal with no canvas
    // mounted, or one in the 2 s before this canvas replaced another)
    // clears too.
    _onHint();
    _c.snappingAllowed = widget.snapping;
    _bind();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _theme = PlanTheme.of(context);
    _surfaceArgb = _canvasColour(theme.colorScheme).toARGB32();
    _brightness = theme.brightness;
    // A build follows, so no setState: only a key change builds a new
    // resolver (planner_shell.dart:371-382).
    if (_nextResolver() case final next?) _resolver = next;
    PlanLocaleScope.push(context, _c);
  }

  @override
  void didUpdateWidget(PlanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller;
    if (!identical(old, _c)) {
      _leave(old);
      old.removeListener(_onController);
      old.lockHint.removeListener(_onHint);
      _hintTimer?.cancel();
      _enter(_c);
      _c.addListener(_onController);
      _c.lockHint.addListener(_onHint);
      // The new controller's hint may be showing already.
      _onHint();
      _rebind();
      PlanLocaleScope.push(context, _c);
    }
    _c.snappingAllowed = widget.snapping;
  }

  @override
  void dispose() {
    _leave(_c);
    // RV6: the controller's tool does not stay part-way with no canvas.
    _withdrawTool(_c);
    _c.removeListener(_onController);
    _c.lockHint.removeListener(_onHint);
    _page?.removeListener(_onPage);
    _hintTimer?.cancel();
    super.dispose();
  }

  /// Spec 2a P2: a controller is shown in one PlanCanvas at a time. Checked
  /// after the frame, when a replaced canvas has been disposed (a keyed
  /// swap inflates the new canvas before it deactivates the old one).
  void _enter(PlanController c) {
    _mountedOf[c] = (_mountedOf[c] ?? 0) + 1;
    assert(() {
      final shown = _canvasesOf[c] ??= _Shown();
      shown.canvases.add(this);
      if (shown.checkScheduled) return true;
      shown.checkScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        shown.checkScheduled = false;
        final count = shown.canvases.length;
        if (count > 1) {
          throw FlutterError(
              'A PlanController is shown in one PlanCanvas at a time '
              '(spec 2a P2): this controller is in $count. Dispose '
              'the first canvas before showing the controller in another.');
        }
      });
      return true;
    }());
  }

  void _leave(PlanController c) {
    final left = (_mountedOf[c] ?? 1) - 1;
    _mountedOf[c] = left == 0 ? null : left;
    assert(() {
      _canvasesOf[c]?.canvases.remove(this);
      return true;
    }());
  }

  /// Binds the page listener to the controller's current document.
  void _bind() {
    _document = _c.document;
    _page = _c.page..addListener(_onPage);
  }

  /// A new document (load, newPlan, import) or a new controller: the page
  /// listener moves, and the resolver is made again for the new document.
  void _rebind() {
    _page?.removeListener(_onPage);
    _bind();
    _foreground = -1;
    _resolver = _nextResolver()!;
  }

  /// The controller notified: a document swap rebuilds the canvas; any
  /// other notification (permissions, the locale) is not the canvas's.
  void _onController() {
    if (identical(_c.document, _document)) return;
    setState(_rebind);
  }

  /// planner_shell.dart:344-363, less the table fills (2b): a page change
  /// that moves the resolver's key rebuilds with a new resolver.
  void _onPage() {
    final next = _nextResolver();
    if (next == null) return;
    setState(() => _resolver = next);
  }

  /// planner_shell.dart:328-331: the paper the drafting and the overlays
  /// lie on.
  int _paperArgb() => displayPaperFor(
      page: _c.page.value?.background,
      surface: _surfaceArgb,
      brightness: _brightness);

  /// planner_shell.dart:334-343: a new resolver when the key moved, else
  /// null; records the new key.
  StyleResolver? _nextResolver() {
    final paper = _paperArgb();
    final foreground = foregroundFor(paper);
    final dark =
        darkCanvasFor(page: _c.page.value?.background, brightness: _brightness);
    if (foreground == _foreground && dark == _darkCanvas) return null;
    _foreground = foreground;
    _darkCanvas = dark;
    return canvasResolverFor(_c.document, paper: paper, dark: dark);
  }

  /// planner_shell.dart:367-368: the theme's `canvasBackground`, else its
  /// surface.
  Color _canvasColour(ColorScheme scheme) =>
      _theme?.canvasBackground ?? scheme.surface;

  /// floor_plan_view.dart:595-602.
  bool _fitOnStartFor(DraftDocument document) {
    if (!identical(_fitFor, document)) {
      _fitFor = document;
      _fitIsRequest = !_c.owesFirstFit;
      _fit = _c.takeFitOnStart();
    }
    return _fit;
  }

  /// Spec P4: the hint clears [kLockHintDuration] after it was set, or
  /// after this canvas bound a controller whose hint was already set. A
  /// refusal while the hint shows writes true over true, which notifies
  /// nothing, so it does not restart the window (that needs an event from
  /// the controller, not a ValueNotifier).
  void _onHint() {
    _hintTimer?.cancel();
    if (!_c.lockHint.value) return;
    final c = _c;
    _hintTimer = Timer(kLockHintDuration, () {
      if (mounted && identical(c, _c)) c.lockHint.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = _c;
    final document = c.document;
    // A parent rebuild may arrive before the controller's notification.
    if (!identical(document, _document)) _rebind();
    final paper = _paperArgb();
    return ColoredBox(
      color: _canvasColour(scheme),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlanCanvasView(
            // A new document is a new view: its own first fit, its own
            // listeners (today's PlannerShell keyed by ObjectKey(document)).
            key: ObjectKey(document),
            controller: c,
            document: document,
            index: c.index,
            resolver: _resolver,
            camera: c.camera,
            page: c.page,
            policy: _policy,
            selection: c.selection,
            tools: c.toolController,
            outlines: c.outlines,
            chrome: ChromePalette.of(theme.brightness),
            paper: planPaperPaletteFor(paper, _theme),
            selectionStrokePixels:
                _theme?.selectionWidth ?? kSelectionStrokePixels,
            sheetArgb: _darkCanvas ? paper : null,
            grips: c.grips,
            textTool: c.textTool,
            fitRequests: c.fitRequests,
            fitOnStart: _fitOnStartFor(document),
            startFitIsRequest: _fitIsRequest,
            onFitted: c.fitted,
            framing: c.framingFor,
            cameraEpoch: () => c.cameraEpoch,
            onCanvasPlaced: c.canvasPlaced,
            rulers: widget.rulers,
            grid: widget.grid,
            autofocus: widget.autofocus,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: c.lockHint,
            builder: (context, shown, _) => shown
                ? Align(
                    alignment: const Alignment(0, 0.9),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const Key('plan-lock-hint'),
                        decoration: BoxDecoration(
                            color: scheme.inverseSurface,
                            borderRadius: BorderRadius.circular(4)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text(PlanStrings.of(context).lockedHint,
                              style: TextStyle(color: scheme.onInverseSurface)),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
