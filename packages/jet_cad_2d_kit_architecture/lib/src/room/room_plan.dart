// The room as the kit's type (spec 3a C3.5): today's RoomType, its label
// grip, and the Selection panel's Room section (jet_cad_floor_plan's
// selection_panel.dart:1373-1386) as property specs: the name, trimmed and
// never empty, and the area as drawn, a TextDisplay over the object (spec
// 3a C1.1). The colour row's room half (colors/color_picker.dart:17-57) is
// the type's colour target. The Room tool is [roomPlanTool].
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart';
import '../separator/separator.dart';
import '../wall/wall.dart';
import 'room.dart';
import 'room_grips.dart';
import 'room_inputs.dart';
import 'room_tool.dart';
import 'room_trace.dart';

/// The room type (spec 3a C3.5).
///
/// - **Name**: a [TextProperty] committed trimmed; a name empty once
///   trimmed is refused (today's R-24: a nameless room could not be told
///   apart), gated by `reshape` (an object's own field, today's S-10).
/// - **Area**: [roomAreaText], read-only.
/// - **Colour**: the room's palette name (plan colours spec PC-3).
/// - **Grips**: the label grip; a drop within the snap aperture of the
///   pole, at the camera's scale whatever F3 says, returns the label to
///   automatic (Ruling 10-17). A room is not moved or turned (R-22).
final PlanType<RoomParams> roomPlanType = PlanType<RoomParams>(
  id: ArchitectureTypes.room,
  fromJson: RoomParams.fromJson,
  parametric: const RoomType(),
  grips: (s) =>
      RoomGrips(aperture: () => kSnapAperturePixels / s.camera.value.scale),
  properties: [
    TextProperty<RoomParams>(
      id: 'name',
      read: (p) => p.name,
      write: (p, v) {
        final name = v.trim();
        if (name.isEmpty) {
          throw ArgumentError.value(v, 'name', 'is empty once trimmed');
        }
        return p.copyWith(name: name);
      },
      gate: PlanGate.reshape,
    ),
    TextDisplay<RoomParams>(id: 'area', read: (p, o) => roomAreaText(o)),
  ],
  colour: ColourTarget<RoomParams>(
    read: (p) => p.color,
    write: (p, swatch) => p.copyWith(color: swatch),
  ),
  area: (p, o) => _roomArea(o, p),
  name: (p) => p.name,
);

/// The traces taken per document and state, and the one [RoomInputs] they
/// are taken among.
final class _AreaCache {
  _AreaCache(DraftDocument document)
      : inputs = RoomInputs(document, _liveByComponent(document));

  final RoomInputs inputs;
  int state = -1;
  final Map<Handle, List<Vector2>?> rings = {};
}

final Expando<_AreaCache> _areaCache = Expando('roomArea');

/// How many room traces [roomPlanType]'s area has taken (not its memo).
/// Never reset by the library.
@visibleForTesting
int debugRoomAreaTraces = 0;

/// The live rule of a document that has no plan services at hand: a wall is
/// the live object carrying a [WallParams], a separator one carrying a
/// [SeparatorParams]. A plan's frozen objects (session state, not document
/// state) are not known here, so a frozen wall still bounds the area.
LiveTypeOf _liveByComponent(DraftDocument document) => (h) {
      if (document.components.get<WallParams>(h) != null) {
        return ArchitectureTypes.wall;
      }
      if (document.components.get<SeparatorParams>(h) != null) {
        return ArchitectureTypes.separator;
      }
      return null;
    };

/// The room's face as the plan's area: [Traced.ring] (the outer contour, in
/// world millimetres, anticlockwise) of the trace around the room's world
/// seed, among the document's walls and separators; null when the seed
/// stands in a wall or the face is unbounded. Taken from the document
/// (the same trace [RoomType.generate] takes, among the same contributors)
/// and memoised per room and document state (`commands.stateId`), as
/// [roomAreaText] is; it is not on the frame path.
List<Vector2>? _roomArea(PlanObject object, RoomParams params) {
  final doc = object.document;
  final cache = _areaCache[doc] ??= _AreaCache(doc);
  final state = doc.commands.stateId;
  if (cache.state != state) {
    cache.state = state;
    cache.rings.clear();
    cache.inputs.invalidate();
  }
  final room = object.handle;
  if (cache.rings.containsKey(room)) return cache.rings[room];
  debugRoomAreaTraces++;
  final result =
      traceRoomAmong(object.world.transformPoint(params.seed), cache.inputs);
  return cache.rings[room] = result is Traced ? result.ring : null;
}

/// How many times [roomAreaText] read the document (not its memo). Never
/// reset by the library.
@visibleForTesting
int debugRoomAreaReads = 0;

/// The last Area line read per document: the room, the document's state
/// and the string.
final Expando<({Handle room, int state, String text})> _areaMemo =
    Expando('roomAreaText');

/// The Area line of [object], a room (spec 10 D21, R-25; today's `_areaOf`,
/// selection_panel.dart:826-844): its area label's stored string, exactly
/// as drawn, or '—' when it has none (a file's room with no children,
/// today's panel line). The labels are the room's TEXT children, the name
/// then the area in handle order (D9, D18), so the area is the second, in
/// handle order, never in slot order.
///
/// Reads the document once per room shown and per document state
/// (`commands.stateId`): today's panel dropped its memo on every command
/// change, and the state moves on exactly those.
///
/// The limit of that key: only a command moves `stateId`, and
/// `notifyLoaded`/`notifyPurged` keep it. So when the plan rebuilds the
/// document under the same state (spec 2a E3: a rollback threw and the
/// plan is regenerated through `notifyLoaded`), a label the rebuild
/// rewrote can be shown stale here until the next command moves the
/// state. It is a display string only, never stored or read back, and the
/// path is rare (a failed rollback), so the memo keeps the plain key.
String roomAreaText(PlanObject object) {
  final doc = object.document;
  final room = object.handle;
  final state = doc.commands.stateId;
  final memo = _areaMemo[doc];
  if (memo != null && memo.room == room && memo.state == state) {
    return memo.text;
  }
  debugRoomAreaReads++;
  final entities = doc.entities;
  final labels = <(Handle, int)>[
    for (final slot in entities.liveSlots)
      if (entities.ownerAt(slot) == room &&
          entities.kindAt(slot) == EntityKind.text)
        (entities.handleAt(slot), slot),
  ]..sort((a, b) => a.$1.value.compareTo(b.$1.value));
  final text = labels.length < 2 ? '—' : entities.textAt(labels[1].$2);
  _areaMemo[doc] = (room: room, state: state, text: text);
  return text;
}

/// The Room tool (spec 3a C3.5): M. One click inside a face commits one
/// room, named with the next free numbered name, in one undo step
/// (structure, components and geometry: today's commit); its notice is
/// "already a room" (spec 3a C1.2). Its inputs are the kit's shared
/// RoomInputs, its live rule the plan's.
final PlanTool roomPlanTool = PlanTool(
  id: ArchitectureTools.room,
  icon: LucideIcons.house,
  letter: 'M',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (s) =>
      RoomTool(roomInputsOf(s), words: s.words, live: liveTypesOf(s)),
);
