// The room as the kit's type (spec 3a C3.5): today's RoomType, its label
// grip, and the Selection panel's Room section (jet_cad_floor_plan's
// selection_panel.dart:1373-1386) as property specs: the name, trimmed and
// never empty, and the area as drawn, a TextDisplay over the object (spec
// 3a C1.1). The colour row's room half (colors/color_picker.dart:17-57) is
// the type's colour target. The Room tool is [roomPlanTool].
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../ids.dart';
import '../live.dart';
import 'room.dart';
import 'room_grips.dart';
import 'room_inputs.dart';
import 'room_tool.dart';

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
);

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
  icon: Icons.meeting_room_outlined,
  letter: 'M',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (s) =>
      RoomTool(roomInputsOf(s), words: s.words, live: liveTypesOf(s)),
);
