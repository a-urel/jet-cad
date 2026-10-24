// The service mode's tool (2b spec S4 "The service tool", "A drag"):
// today's TableSelectTool (jet_cad_floor_plan/lib/src/service/
// table_select_tool.dart; spec 14c S3, S4, S8, R-1, R-5 to R-7, rubber-band
// RB-2 to RB-5, table-groups G4) over units, placed and generated. A tap
// selects a unit, a long press adds or removes one, a drag moves the
// selected placed units (a seat stays), a floor drag pans or bands, and a
// unit in a group acts with its whole group. It writes the copy's engine
// selection with SelectionKey.root(unit), for a seat too. A locked unit
// (isLockedUnit) is tapped and grouped, never selected or dragged.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data' show Float64List;
import 'dart:ui' show Canvas, Offset, Rect, Size;

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/gestures.dart'
    show
        kDoubleTapSlop,
        kDoubleTapTimeout,
        kLongPressTimeout,
        kPrimaryButton,
        kTouchSlop;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../guides/guide_painter.dart';
import '../guides/guide_references.dart';
import '../guides/guide_settings.dart';
import '../guides/guide_solver.dart';
import '../units/unit_index.dart' show UnitInfo;
import 'service_state.dart' show GroupUnit, UnitGroup, UnitGroupLookup;
import 'unit_picker.dart' show PickCandidate, UnitPicker;

/// What a long press on a unit does in service (today's FloorPlanLongPress).
enum PlanLongPress {
  /// Adds the unit to the selection or removes it (a group whole).
  toggleSelection,

  /// Reports the unit to `onUnitContextMenu`, as a secondary click does.
  contextMenu,
}

/// What a drag on the floor does in service (today's FloorPlanFloorDrag).
enum PlanFloorDrag {
  /// The camera pans; Shift, Ctrl or Cmd with a mouse or stylus bands.
  pan,

  /// A band selects: left to right the units wholly inside, right to left
  /// those it touches. The camera pans with two fingers, a trackpad's
  /// scroll or the middle button.
  band,
}

/// What the tool and the service bar tell their host, read at each call
/// (R-5). [onMergeRequested] and [onSplitRequested] are the service bar's.
typedef ServiceCallbacks = ({
  void Function(String label)? onUnitTap,
  void Function()? onLayoutChanged,
  void Function(String groupId, String label)? onGroupTap,
  void Function(Set<String> labels)? onMergeRequested,
  void Function(String groupId)? onSplitRequested,
});

/// No callback.
const ServiceCallbacks kNoServiceCallbacks = (
  onUnitTap: null,
  onLayoutChanged: null,
  onGroupTap: null,
  onMergeRequested: null,
  onSplitRequested: null,
);

/// The view's options for the tool, read at each press;
/// [onUnitContextMenu] takes a global position. Moves are the permission
/// `serviceMove` (spec S4), read through the tool's `moves`.
typedef ServiceOptions = ({
  PlanLongPress longPress,
  void Function(String label, Offset globalPosition)? onUnitContextMenu,
  PlanFloorDrag floorDrag,
});

/// Today's behaviour: a long press toggles, no menu, a floor drag pans.
const ServiceOptions kDefaultServiceOptions = (
  longPress: PlanLongPress.toggleSelection,
  onUnitContextMenu: null,
  floorDrag: PlanFloorDrag.pan,
);

/// The view events, read at each call (R-5). [M] is what a drag reports as
/// moved: the live instances at the tool, the controller's fresh details at
/// the view (Task 16).
typedef ServiceEvents<M> = ({
  void Function(List<M> moved)? onUnitsMoved,
  void Function(String label)? onUnitDoubleTap,
  void Function(Offset world)? onFloorTap,
  void Function(String? label)? onUnitHover,
});

/// No view event. Its fields are `Null`, so it is a [ServiceEvents] whatever
/// its type argument.
const kNoServiceEvents = (
  onUnitsMoved: null,
  onUnitDoubleTap: null,
  onFloorTap: null,
  onUnitHover: null,
);

ServiceCallbacks _noCallbacks() => kNoServiceCallbacks;
ServiceOptions _defaultOptions() => kDefaultServiceOptions;
ServiceEvents<Handle> _noEvents() => kNoServiceEvents;
Offset _sameOffset(Offset local) => local;
bool _always() => true;

/// What a service session's tool reads from the view that shows the
/// session, at each call (2b; today's ServiceView closures,
/// service_view.dart:133-142). The view sets one on `ServiceSession.host`
/// while its canvas is mounted; [none] is today's behaviour with no view.
final class ServiceHost {
  const ServiceHost({
    this.callbacks = _noCallbacks,
    this.options = _defaultOptions,
    this.userCamera = _always,
    this.toGlobal = _sameOffset,
    this.events = _noEvents,
    this.idleKeys = _always,
  });

  /// No view: no callback, today's options, a free camera, the local
  /// offset, the keys bound.
  static const ServiceHost none = ServiceHost();

  final ServiceCallbacks Function() callbacks;
  final ServiceOptions Function() options;

  /// Whether a drag on the floor pans (host embedding API spec G-3).
  final bool Function() userCamera;

  /// The layer's local point as a global one, for a context menu.
  final Offset Function(Offset local) toGlobal;

  /// Read at each button-less move: a view hands back a record it keeps.
  final ServiceEvents<Handle> Function() events;

  /// Whether the tool's idle Escape acts (spec C-7, S-16).
  final bool Function() idleKeys;
}

/// A context gesture's selection (spec 14d S6): an unselected, unlocked
/// unit becomes the selection alone -- or, a member of a group, its
/// [group]'s selectable members -- a selected one keeps the selection, a
/// locked one changes nothing. Returns the unit's label, which the host is
/// told when it is not null.
String? contextSelect(UnitInfo hit, SelectionController selection,
    {Set<SelectionKey>? group}) {
  if (!hit.locked) {
    final key = SelectionKey.root(hit.instance);
    if (!selection.keys.contains(key)) selection.replace(group ?? [key]);
  }
  return hit.text;
}

enum _Gesture { none, pressed, dragging, panning, banding, spent }

/// The service mode's tool (S3). One per service session; disposed with it.
class ServiceTool extends Tool {
  ServiceTool(
      {required this.picker,
      required this.groups,
      required this.callbacks,
      this.options = _defaultOptions,
      this.moves = _always,
      this.userCamera = _always,
      this.toGlobal = _sameOffset,
      this.events = _noEvents,
      this.idleKeys = _always,
      this.guides,
      this.guideSettings,
      this.guideStroke});

  final UnitPicker picker;

  /// The host's unit groups, as `PlanController.unitGroups` holds them:
  /// validated, ids trimmed.
  final ValueListenable<Map<String, UnitGroup>> groups;

  final ServiceCallbacks Function() callbacks;

  /// The view's options (spec 14d S5-S7), read at each press.
  final ServiceOptions Function() options;

  /// Whether a drag on a unit moves it (spec S4: `PlanPermissions
  /// .serviceMove`, today's view option `serviceMoves`), read at each press:
  /// false makes it a pan, as on the floor.
  final bool Function() moves;

  /// The layer's local point as a global one, for a context menu (S7).
  final Offset Function(Offset local) toGlobal;

  /// Whether a drag on the floor pans (host embedding API spec G-3), read
  /// at each press: false (a view with `userCamera: false`) spends it.
  final bool Function() userCamera;

  /// The view events (spec E-1 to E-4), read at each call (R-5). A hover
  /// reads it at each button-less move, so the view hands in a record it
  /// keeps, not one built per call.
  final ServiceEvents<Handle> Function() events;

  /// Whether the tool's idle key acts (host embedding API spec C-7, S-16),
  /// read at each key: false leaves Escape, which clears the selection
  /// while no gesture runs, to the host.
  final bool Function() idleKeys;

  /// The service copy's guide references, or null: no guides (alignment
  /// guides spec, "Modes").
  final GuideReferenceCache? guides;

  /// The guide switch, or null: no guides. Listened to only while an
  /// eligible drag lives with the guides on at its start.
  final PlanGuideSettings? guideSettings;

  /// The guide stroke in screen pixels, read at paint.
  final double Function()? guideStroke;

  /// [userCamera] as the press read it.
  bool _pans = true;

  /// [moves] as the press read it.
  bool _moves = true;

  /// The press's raw down time (spec E-2).
  Duration _pressTime = Duration.zero;

  /// The last tap that reported `onUnitTap` with no modifier (spec E-2):
  /// its instance, its down's time and screen point; null when the next
  /// tap cannot complete a double tap.
  ({Handle instance, Duration time, Offset screen})? _lastTap;

  /// The label last reported to `onUnitHover` (spec E-4).
  String? _hovered;

  ServiceOptions _options = kDefaultServiceOptions;

  _Gesture _gesture = _Gesture.none;
  int _pointer = -1;
  Offset _pressScreen = Offset.zero;
  Offset _lastScreen = Offset.zero;
  final Vector2 _pressWorld = Vector2.zero();
  UnitInfo? _hit;
  bool _toggle = false;
  Timer? _timer;

  /// The drag's translation, in world units.
  double _dx = 0, _dy = 0;

  /// A finger's press that reached a unit by the reach only (14t R-11):
  /// under PlanFloorDrag.band its drag is a band (rubber-band R-4).
  bool _reachOnly = false;

  /// The live band's mode (RB-3), from the press to the pointer's latest.
  BandMode _bandMode = BandMode.window;

  final SelectionBandPainter _bandPainter = SelectionBandPainter();

  /// The units a drag moves: the selection when it began, with every
  /// group it touches (G4).
  List<Handle> _moving = const [];

  // The guides of the live drag (alignment guides spec, "The delta: Move").
  // All of it is set at the drag's start and cleared by [_reset]; a drag
  // that began with guides off or with nothing to align never listens, so
  // it is today's, byte for byte.
  final GuideSolution _solution = GuideSolution();
  final GuidePainter _guidePainter = GuidePainter();
  final Float64List _box = Float64List(4);
  Set<Handle> _movingSet = const {};
  ToolContext? _dragCtx;
  bool _eligible = false;
  bool _touch = false;
  bool _alt = false;

  /// The last guide solution, the one [paintOverlay] draws (tests read it).
  @visibleForTesting
  GuideSolution get debugSolution => _solution;

  /// The picker's candidates by instance (Z0: the units the picker can
  /// hit, a locked one listed), rebuilt when the picker's list is a new one
  /// (it is rebuilt only when the unit index is); never per pointer event.
  Map<Handle, UnitInfo> _byHandle = const {};
  List<PickCandidate>? _byHandleFor;

  /// The groups resolved against the picker's candidates, and each visible
  /// member's group by handle (G4). Rebuilt when the candidates list or the
  /// groups map is replaced, so a `setUnitGroups` alone refreshes it.
  UnitGroupLookup? _lookup;
  Map<Handle, String> _groupByHandle = const {};
  List<PickCandidate>? _lookupCandidates;
  Map<String, UnitGroup>? _lookupGroups;

  @override
  String get name => 'Units';

  /// A down only classifies a press and `cancel` executes nothing, so a
  /// finger reaches this tool after the hold-back (spec 14t R-1).
  @override
  TouchPress get touchPress => TouchPress.press;

  @override
  ToolPhase get phase => switch (_gesture) {
        _Gesture.none => ToolPhase.idle,
        _Gesture.pressed || _Gesture.spent => ToolPhase.pressed,
        _Gesture.dragging ||
        _Gesture.panning ||
        _Gesture.banding =>
          ToolPhase.dragging,
      };

  /// The outlines follow the drag (F-2).
  @override
  Transform2? get selectionPreviewTransform =>
      _gesture == _Gesture.dragging ? Transform2.translation(_dx, _dy) : null;

  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {
    if (e.buttons & kPrimaryButton == 0 || _gesture != _Gesture.none) return;
    _pointer = e.pointer;
    _pressTime = e.timeStamp;
    _pressScreen = e.screen;
    _lastScreen = e.screen;
    _pressWorld.setFrom(e.world);
    // A finger that misses every top reaches the nearest within 24 px
    // (spec 14t R-11); a mouse picks by containment only.
    _hit = picker.pick(e.world, reach: e.isTouch ? e.reachRadiusWorld : 0);
    // A finger's hit found by the reach alone (RB-2): one more pick, a
    // finger's down only.
    _reachOnly = e.isTouch && _hit != null && picker.pick(e.world) == null;
    _toggle = e.shift || e.control || e.meta;
    _options = options();
    _pans = userCamera();
    _moves = moves();
    _gesture = _Gesture.pressed;
    _dx = _dy = 0;
    final hit = _hit;
    // Under a context menu a locked unit is reported too (S7, amending
    // 14c R-1 for this mode only).
    if (hit != null &&
        (!hit.locked || _options.longPress == PlanLongPress.contextMenu)) {
      // A finger's down arrives kTouchHoldBack after it touched, so the
      // long press still falls 500 ms from contact (spec 14t T5, R-9f).
      _timer = Timer(
          e.isTouch ? kLongPressTimeout - kTouchHoldBack : kLongPressTimeout,
          () => _longPress(ctx));
    }
    notifyListeners();
  }

  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {
    // A hover (no button) is not a gesture (R-6); a mouse's or a stylus's
    // is reported (spec E-4), a finger's never.
    if (e.buttons == 0 && !e.isTouch) _hover(e);
    if (e.pointer != _pointer || e.buttons & kPrimaryButton == 0) return;
    switch (_gesture) {
      case _Gesture.none || _Gesture.spent:
        return;
      case _Gesture.pressed:
        if ((e.screen - _pressScreen).distance <= kTouchSlop) return;
        _timer?.cancel();
        _timer = null;
        // A drag, a pan or a spent drag is no tap (spec E-2).
        _lastTap = null;
        if (_startsBand(e)) {
          _gesture = _Gesture.banding;
          _lastScreen = e.screen;
          _bandMode = bandModeFor(_pressScreen, e.screen);
          notifyListeners();
          return;
        }
        final hit = _hit;
        if (hit == null || !_moves) {
          // Empty floor pans; so does any unit when moves are off (S5).
          // Unless the host locked the camera (spec G-3): then the drag is
          // spent, as on a locked unit.
          if (!_pans) {
            _gesture = _Gesture.spent;
            notifyListeners();
            return;
          }
          _gesture = _Gesture.panning;
        } else if (hit.locked) {
          // A locked unit is tapped only (R-1): no move, no pan.
          _gesture = _Gesture.spent;
          notifyListeners();
          return;
        } else if (!_startDrag(hit, ctx)) {
          // Nothing placed to move (seats only, or a drag from a seat), or
          // a group with a locked or generated visible member (G4): spent.
          _gesture = _Gesture.spent;
          notifyListeners();
          return;
        }
        _drag(e, ctx);
      case _Gesture.dragging || _Gesture.panning:
        _drag(e, ctx);
      case _Gesture.banding:
        _lastScreen = e.screen;
        _bandMode = bandModeFor(_pressScreen, e.screen);
        notifyListeners();
    }
  }

  /// Whether this drag is a band (rubber-band RB-2): from the floor -- or,
  /// under `band`, a finger's reach-only press -- when the host chose
  /// `band`, or under `pan` with a modifier at the press and no finger.
  bool _startsBand(ToolPointerEvent e) {
    final band = _options.floorDrag == PlanFloorDrag.band;
    if (_hit != null && !(band && _reachOnly)) return false;
    return band || (_toggle && !e.isTouch);
  }

  /// The drag's start (S4, G4; 2b S4 "A drag"): an unselected unit, or its
  /// whole group, replaces the selection; what moves is every selected
  /// placed unit, each group having a member among them taken whole. A
  /// selected seat stays where it is. False, with the selection untouched,
  /// when such a group has a locked or a generated visible member, or when
  /// no placed unit would move: the drag is then spent.
  bool _startDrag(UnitInfo hit, ToolContext ctx) {
    final key = SelectionKey.root(hit.instance);
    // With no group every unit stands alone, as before groups (G7).
    final lookup = _groupLookup();
    final groupOf = lookup == null ? const <Handle, String>{} : _groupByHandle;
    final hitGroup = groupOf[hit.instance];
    final replace = !ctx.selection.keys.contains(key);
    final selected = !replace
        ? ctx.selection.keys
        : hitGroup == null
            ? {key}
            : _memberKeys(lookup!, hitGroup);
    final index = picker.units.current;
    final roots = [
      for (final k in selected)
        if (k.chain.isEmpty && !(index[k.target]?.generated ?? false)) k.target
    ];
    final involved = <String>{
      for (final h in roots)
        if (groupOf[h] case final id?) id
    };
    if (roots.isEmpty ||
        involved.any((id) =>
            lookup!.hasLockedVisibleMember(id) ||
            lookup.hasGeneratedVisibleMember(id))) {
      return false;
    }
    if (replace) ctx.selection.replace(selected);
    _moving = _sorted({
      ...roots,
      for (final id in involved)
        for (final t in lookup!.selectableMembers(id)) t.handle,
    });
    _gesture = _Gesture.dragging;
    _beginGuides(ctx);
    return true;
  }

  /// The guides of a drag that has just begun: eligible when the moving
  /// units have a box (the cache leaves out seats and hidden units, so a
  /// group of hidden members has none), and listened to only when the
  /// setting is on. May allocate: drag start only.
  void _beginGuides(ToolContext ctx) {
    _solution.reset();
    _eligible = false;
    _alt = false;
    final references = guides, settings = guideSettings;
    if (references == null || settings == null || !settings.on) return;
    if (!references.unionOf(_moving, _box)) return;
    _eligible = true;
    _movingSet = Set<Handle>.of(_moving);
    _dragCtx = ctx;
    ctx.camera.addListener(_onGuideCamera);
    settings.addListener(_onGuideSettings);
  }

  /// Takes the listeners off; the drag's end, by any road.
  void _endGuides() {
    final ctx = _dragCtx;
    if (ctx != null) {
      ctx.camera.removeListener(_onGuideCamera);
      guideSettings?.removeListener(_onGuideSettings);
    }
    _dragCtx = null;
    _eligible = false;
    _alt = false;
    _movingSet = const {};
    _solution.reset();
  }

  /// The translation for the pointer at world (`wx`, `wy`): the raw delta,
  /// plus the guide's offset on each axis it captures (spec "The delta").
  /// Guides off, Alt held or no box: the raw delta, today's.
  void _aim(ToolContext ctx, double wx, double wy) {
    final rawX = wx - _pressWorld.x, rawY = wy - _pressWorld.y;
    _dx = rawX;
    _dy = rawY;
    final references = guides, settings = guideSettings;
    if (!_eligible || references == null || settings == null) return;
    if (!settings.on || _alt) {
      _solution.reset();
      return;
    }
    final aperture =
        (_touch ? kGuideTouchAperturePixels : kGuideAperturePixels) /
            ctx.camera.value.scale;
    solveGuides(references.current,
        minX: _box[0] + rawX,
        minY: _box[1] + rawY,
        maxX: _box[2] + rawX,
        maxY: _box[3] + rawY,
        aperture: aperture,
        freeX: true,
        freeY: true,
        fallbackDx: 0,
        fallbackDy: 0,
        moving: _movingSet,
        out: _solution);
    if (_solution.capturedX) _dx = rawX + _solution.dx;
    if (_solution.capturedY) _dy = rawY + _solution.dy;
  }

  /// [_aim] on its own, for the guide allocation test's isolated window: the
  /// guide code with no pointer plumbing around it.
  @visibleForTesting
  void debugAim(ToolContext ctx, double wx, double wy) => _aim(ctx, wx, wy);

  /// Aims again at the pointer's last screen point under the current
  /// camera and tells the listeners.
  void _reaim() {
    final ctx = _dragCtx;
    if (ctx == null) return;
    // The screen point back to the world by the camera's own coefficients:
    // `screenToWorld` would build a `Vector2` for its argument and one for
    // its result on every camera change (spec Constraints: guides add no
    // allocation per event).
    final m = ctx.camera.value.worldToScreenMatrix;
    final det = m.a * m.d - m.b * m.c;
    final sx = _lastScreen.dx - m.e, sy = _lastScreen.dy - m.f;
    _aim(ctx, (m.d * sx - m.c * sy) / det, (m.a * sy - m.b * sx) / det);
    notifyListeners();
  }

  void _onGuideCamera() => _reaim();

  void _onGuideSettings() => _reaim();

  static List<Handle> _sorted(Iterable<Handle> handles) =>
      handles.toList()..sort((a, b) => a.value.compareTo(b.value));

  void _drag(ToolPointerEvent e, ToolContext ctx) {
    if (_gesture == _Gesture.panning) {
      ctx.camera.panBy(e.screen - _lastScreen);
    } else {
      _touch = e.isTouch;
      _alt = e.alt;
      _aim(ctx, e.world.x, e.world.y);
    }
    _lastScreen = e.screen;
    notifyListeners();
  }

  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {
    if (e.pointer != _pointer) return;
    switch (_gesture) {
      case _Gesture.pressed:
        _tap(ctx);
      case _Gesture.dragging:
        _move(ctx);
      case _Gesture.banding:
        _band(e, ctx);
      case _Gesture.none || _Gesture.panning || _Gesture.spent:
        break;
    }
    _reset();
    notifyListeners();
  }

  /// The band's end (RB-3, RB-4): both screen corners under the camera at
  /// the up, the instances the band passes kept to the picker's
  /// candidates, groups taken by the mode's rule; one `replace`.
  void _band(ToolPointerEvent e, ToolContext ctx) {
    final a = ctx.camera.value
        .screenToWorld(Vector2(_pressScreen.dx, _pressScreen.dy));
    final b = e.world;
    final world = Aabb2.raw(math.min(a.x, b.x), math.min(a.y, b.y),
        math.max(a.x, b.x), math.max(a.y, b.y));
    final keys = _bandKeys(world, bandModeFor(_pressScreen, e.screen), ctx);
    if (_toggle) {
      if (keys.isEmpty) return;
      ctx.selection.replace({...ctx.selection.keys, ...keys});
    } else {
      ctx.selection.replace(keys);
    }
  }

  /// The band's keys (RB-3), ascending by handle: a seat's a root key too
  /// (2b S4). `snapping`, not `picking`: a locked layer's unit reaches the
  /// window's group rule (review V-1); a locked unit is never a key.
  List<SelectionKey> _bandKeys(Aabb2 world, BandMode mode, ToolContext ctx) {
    final byHandle = _units();
    final passing = <Handle>{};
    ctx.index.forEachInstanceInBand(world, mode, const QueryFilter.snapping(),
        (h) {
      if (byHandle.containsKey(h)) passing.add(h);
    });
    final lookup = _groupLookup();
    final keys = <Handle>{};
    final groups = <String>{};
    for (final h in passing) {
      final id = lookup == null ? null : _groupByHandle[h];
      if (id != null) {
        groups.add(id);
      } else if (!byHandle[h]!.locked) {
        keys.add(h);
      }
    }
    for (final id in groups) {
      final members = lookup!.visibleMembers(id);
      final take = switch (mode) {
        BandMode.crossing =>
          members.any((t) => !t.locked && passing.contains(t.handle)),
        BandMode.window => members.every((t) => passing.contains(t.handle)),
      };
      if (take) {
        for (final t in lookup.selectableMembers(id)) {
          keys.add(t.handle);
        }
      }
    }
    return [for (final h in _sorted(keys)) SelectionKey.root(h)];
  }

  /// The pointer's unit under a hover (spec E-4): picked with no reach,
  /// only while the host listens; reported only when its label differs
  /// from the last reported, null over the floor or an unlabelled unit.
  void _hover(ToolPointerEvent e) {
    final report = events().onUnitHover;
    if (report == null) return;
    final label = picker.pick(e.world)?.text;
    if (label == _hovered) return;
    _hovered = label;
    report(label);
  }

  /// A tap (S3): a unit alone, or toggled with Shift or Ctrl/Cmd; empty
  /// floor clears, unless a modifier is held (R-6). A member of a group
  /// stands for the whole group (G4): it replaces the selection, or with a
  /// modifier is added or removed whole. A locked unit selects nothing;
  /// its tap is reported, a member's with its group.
  ///
  /// Then the view events (spec E-2, E-3): a miss reports the floor at the
  /// down's world point, modifier or not (S-4); a labelled unit's tap with
  /// no modifier on the same instance as the last such tap, its down at
  /// most [kDoubleTapTimeout] after that one's and at most [kDoubleTapSlop]
  /// screen pixels from it, is a double tap, reported after its own tap;
  /// the chain then starts anew. Nothing is delayed (Q-H2).
  void _tap(ToolContext ctx) {
    final hit = _hit;
    if (hit == null) {
      if (!_toggle) ctx.selection.clear();
      _lastTap = null;
      events().onFloorTap?.call(Offset(_pressWorld.x, _pressWorld.y));
      return;
    }
    final lookup = _groupLookup();
    final group = lookup == null ? null : _groupByHandle[hit.instance];
    if (!hit.locked) {
      final key = SelectionKey.root(hit.instance);
      if (group != null) {
        ctx.selection.replace(_toggle
            ? _addOrRemoveGroup(lookup!, group, key, ctx.selection.keys)
            : _memberKeys(lookup!, group));
      } else if (_toggle) {
        ctx.selection.toggle([key]);
      } else {
        ctx.selection.replace([key]);
      }
    }
    final label = hit.text;
    if (label == null) {
      _lastTap = null;
      return;
    }
    final doubleTap = !_toggle && _completesDoubleTap(hit.instance);
    _lastTap = _toggle || doubleTap
        ? null
        : (instance: hit.instance, time: _pressTime, screen: _pressScreen);
    callbacks().onUnitTap?.call(label);
    if (group != null) callbacks().onGroupTap?.call(group, label);
    if (doubleTap) events().onUnitDoubleTap?.call(label);
  }

  /// Whether this press's down, on [instance], follows the kept tap's
  /// closely enough (spec E-2): inclusive bounds, between the two downs.
  bool _completesDoubleTap(Handle instance) {
    final last = _lastTap;
    if (last == null || last.instance != instance) return false;
    final gap = _pressTime - last.time;
    return gap >= Duration.zero &&
        gap <= kDoubleTapTimeout &&
        (_pressScreen - last.screen).distance <= kDoubleTapSlop;
  }

  /// The selectable members' keys of the group [hit] belongs to, or null:
  /// what a context gesture selects for a member, as a tap would (G4).
  Set<SelectionKey>? groupKeysOf(UnitInfo hit) {
    final lookup = _groupLookup();
    final group = lookup == null ? null : _groupByHandle[hit.instance];
    return group == null ? null : _memberKeys(lookup!, group);
  }

  /// The group's selectable members' keys, ascending by handle (G4).
  static Set<SelectionKey> _memberKeys(UnitGroupLookup lookup, String id) => {
        for (final t in lookup.selectableMembers(id))
          SelectionKey.root(t.handle)
      };

  /// [selection] with group [id] removed whole when [tapped] is in it,
  /// else added whole: one set for one `replace`, never a per-key `toggle`,
  /// which would flip a half-selected group the other way (F-5).
  static Set<SelectionKey> _addOrRemoveGroup(UnitGroupLookup lookup, String id,
      SelectionKey tapped, Set<SelectionKey> selection) {
    if (selection.contains(tapped)) {
      final members = {
        for (final t in lookup.visibleMembers(id)) SelectionKey.root(t.handle)
      };
      return {
        for (final k in selection)
          if (!members.contains(k)) k
      };
    }
    return {...selection, ..._memberKeys(lookup, id)};
  }

  /// The picker's candidates by instance (see [_byHandle]).
  Map<Handle, UnitInfo> _units() {
    final candidates = picker.candidates;
    if (!identical(_byHandleFor, candidates)) {
      _byHandle = {for (final c in candidates) c.unit.instance: c.unit};
      _byHandleFor = candidates;
    }
    return _byHandle;
  }

  /// The group lookup over the picker's current candidates, or null while
  /// the host has no group (then every gesture is as before groups).
  UnitGroupLookup? _groupLookup() {
    final map = groups.value;
    if (map.isEmpty) return null;
    final candidates = picker.candidates;
    if (_lookup == null ||
        !identical(_lookupCandidates, candidates) ||
        !identical(_lookupGroups, map)) {
      // The picker lists visible units only; a locked one is listed.
      final lookup = UnitGroupLookup(map, [
        for (final c in candidates)
          GroupUnit(
              handle: c.unit.instance,
              label: c.unit.text,
              visible: true,
              locked: c.unit.locked,
              generated: c.unit.generated),
      ]);
      _lookup = lookup;
      _groupByHandle = {
        for (final id in map.keys)
          for (final t in lookup.visibleMembers(id)) t.handle: id,
      };
      _lookupCandidates = candidates;
      _lookupGroups = map;
    }
    return _lookup;
  }

  /// The drag's one step (D16): each moved unit translated, as it is now,
  /// and only if it is still live (R-6). Nothing for a zero translation.
  void _move(ToolContext ctx) {
    if (_dx == 0 && _dy == 0) return;
    final t = Transform2.translation(_dx, _dy);
    final commands = <DraftCommand>[
      for (final h in _moving)
        if (ctx.document.tree[h] case final InstanceNode node)
          TransformNodeCommand(h, t.multiply(node.transform)),
    ];
    if (commands.isEmpty) return;
    ctx.execute(CompoundCommand(commands, label: 'Move'));
    callbacks().onLayoutChanged?.call();
    // Spec E-1: the live instances moved, ascending, once per drag.
    final moved = events().onUnitsMoved;
    if (moved == null) return;
    moved(List.unmodifiable([
      for (final h in _moving)
        if (ctx.document.tree[h] is InstanceNode) h
    ]));
  }

  /// A long press (decision 9): the unit toggled, a member's group added
  /// or removed whole as by a modifier tap (G4) -- or, under
  /// [PlanLongPress.contextMenu], reported as a context menu at the
  /// press (spec 14d S7), a member selecting its group as a tap does; the
  /// gesture is spent, so moves and the up do nothing, and no tap is
  /// reported (R-6).
  void _longPress(ToolContext ctx) {
    _timer = null;
    final hit = _hit;
    if (_gesture != _Gesture.pressed || hit == null) return;
    // A long press is no tap (spec E-2).
    _lastTap = null;
    if (_options.longPress == PlanLongPress.contextMenu) {
      final label = contextSelect(hit, ctx.selection, group: groupKeysOf(hit));
      if (label != null) {
        _options.onUnitContextMenu?.call(label, toGlobal(_pressScreen));
      }
    } else {
      if (hit.locked) return;
      final key = SelectionKey.root(hit.instance);
      final lookup = _groupLookup();
      final group = lookup == null ? null : _groupByHandle[hit.instance];
      if (group == null) {
        ctx.selection.toggle([key]);
      } else {
        ctx.selection.replace(
            _addOrRemoveGroup(lookup!, group, key, ctx.selection.keys));
      }
    }
    _gesture = _Gesture.spent;
    notifyListeners();
  }

  /// The pointer left the canvas (spec E-4): the host hears null when the
  /// last label it heard was not.
  @override
  void onPointerExit(ToolContext ctx) {
    if (_hovered == null) return;
    _hovered = null;
    events().onUnitHover?.call(null);
  }

  /// A secondary click at [world] that the view's listener let through
  /// (spec 14d S6; today's `ServiceView._onSecondaryUp`, service_view.dart:
  /// 212-227): with no `onUnitContextMenu` nothing, not even a pick; else
  /// the unit there takes [contextSelect]'s selection and, labelled, is
  /// reported at [globalPosition].
  void secondaryClick(
      Vector2 world, Offset globalPosition, SelectionController selection) {
    final report = options().onUnitContextMenu;
    if (report == null) return;
    final hit = picker.pick(world);
    if (hit == null) return;
    final label = contextSelect(hit, selection, group: groupKeysOf(hit));
    if (label != null) report(label, globalPosition);
  }

  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) {
    // Alt suspends the guides at once (C-16), and brings them back on its
    // release; only a live guided drag listens. Any other gesture falls
    // through, so a band still takes Alt (RB-5).
    final altKey = event.logicalKey == LogicalKeyboardKey.altLeft ||
        event.logicalKey == LogicalKeyboardKey.altRight;
    if (altKey && _gesture == _Gesture.dragging) {
      if (event is! KeyRepeatEvent && _dragCtx != null) {
        final down = event is KeyDownEvent;
        if (down != _alt) {
          _alt = down;
          _reaim();
        }
      }
      return KeyEventResult.ignored;
    }
    // A band takes every key (RB-5): Escape ends it, whatever idleKeys
    // says; no other shortcut lands in its middle.
    if (_gesture == _Gesture.banding) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _reset();
        notifyListeners();
      }
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _gesture == _Gesture.none &&
        idleKeys()) {
      ctx.selection.clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// A pointer cancel, a mode switch, a new copy: the drag is dropped and
  /// nothing is executed (R-5).
  @override
  void cancel(ToolContext ctx) {
    // A cancelled press is no tap (spec E-2).
    _lastTap = null;
    if (_gesture == _Gesture.none && _timer == null) return;
    _reset();
    notifyListeners();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _gesture = _Gesture.none;
    _pointer = -1;
    _hit = null;
    _moving = const [];
    _dx = _dy = 0;
    _reachOnly = false;
    _endGuides();
  }

  /// The live band, from the press's screen point to the pointer's latest
  /// (RB-6); nothing otherwise.
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {
    if (_gesture == _Gesture.dragging) {
      if (_solution.lineCount != 0 || _solution.markCount != 0) {
        _guidePainter.paint(canvas, camera.worldToScreenMatrix, _solution,
            color: paper.guideColor, strokePixels: guideStroke?.call() ?? 1.0);
      }
      return;
    }
    if (_gesture != _Gesture.banding) return;
    _bandPainter.paint(
        canvas, Rect.fromPoints(_pressScreen, _lastScreen), _bandMode, paper);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    // Not through [_reset]: the listeners come off, the rest dies with it.
    _endGuides();
    super.dispose();
  }
}
