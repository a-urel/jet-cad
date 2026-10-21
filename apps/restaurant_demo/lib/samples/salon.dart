// The Salon sample: four-seat tables, round six-seat tables, two booths, a
// bar with four stools and a host stand, as a `PlanBuild`, in a room of
// four walls. The old plan (assets/plans/salon.json, dropped with the old
// packages) held the thirteen placements and no wall; the positions are the
// old ones, in mm from the sheet's lower-left corner, and the room is new:
// built first, 1200 mm clear of the furniture's box (x 1765..13900, y
// 1075..9150). That room is wider than the default A4 sheet at 1:50
// (14850 x 10500 mm), so the build sets an A3 sheet at 1:50 (21000 x 14850
// mm) over the same centre: the scale, the walls and every placement stay
// as they are, and only the paper grows. Numbered in build order: tables
// 1-3, 4-5, the booths 6-7, the stools 8-11. Three rooms divide the floor
// (spec D14): the Salon, the VIP corner in the north-east (the booths 6 and
// 7) and the Garden outside the south wall (tables 2 and 3, which stand there
// rather than in the room; the round tables would not fit the sheet).

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitWords;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

import 'place_tables.dart';

/// The room's wall centrelines, mm from the sheet's lower-left corner.
const double kRoomLeft = 400, kRoomRight = 15250;
const double kRoomBottom = -250, kRoomTop = 10500;

/// The exterior wall thickness, as the sample flat's.
const double kRoomWall = 250;

/// Builds the Salon into [document] (a `PlanBuild`).
void buildSalon(DraftDocument document, KitWords words) {
  _sheet(document);
  _room(document);
  final p = TablePlacer(document);
  p.place('restaurant.table.rect.four', 2500, 7600);
  p.place('restaurant.table.rect.four', 4000, kGardenTableY);
  p.place('restaurant.table.rect.four', 10500, kGardenTableY);
  p.place('restaurant.table.round.six', 2700, 4300);
  p.place('restaurant.table.round.six', 5700, 4300);
  p.place('restaurant.booth.four', 11000, 8300);
  p.place('restaurant.booth.four', 11000, 5600);
  p.place('restaurant.bar.stool', 7700, 2650);
  p.place('restaurant.bar.stool', 8500, 2650);
  p.place('restaurant.bar.stool', 9300, 2650);
  p.place('restaurant.bar.stool', 10100, 2650);
  p.place('restaurant.bar.counter', 8900, 1800);
  p.place('restaurant.host.stand', 13600, 1300);
}

/// The VIP corner: bounded by the north and east walls, a separator from
/// the north wall down at [kVipWest] and one from there to the east wall at
/// [kVipSouth]. It holds the booths 6 and 7 (x 11000, y 8300 and 5600).
const double kVipWest = 9800, kVipSouth = 4300;

/// The Garden, outside the south wall: bounded by it and a separator at
/// [kGardenSouth] (the room's wall stands at [kRoomBottom]) and one at each
/// side wall's line. The sheet is A3 centred on the origin, whose lowest
/// edge is 1925 mm under the room's south wall centre line.
const double kGardenSouth = -2100;

/// The y of the Garden's tables (2 and 3), midway between the south wall's
/// outer face and [kGardenSouth].
const double kGardenTableY = -1250;

/// The Salon's sheet: A3 landscape at 1:50, centred on the world origin as
/// the default A4 sheet is, so [kSheetMin] still measures the placements
/// (the default sheet's lower-left corner) and the room lies inside it.
void _sheet(DraftDocument doc) {
  // The plan's own page, resized: its decimal separator (the language's, not
  // the build's to decide) and every other field stay.
  final page = doc.components
      .get<PageComponent>(doc.rootHandle)!
      .copyWith(widthMm: 297, heightMm: 420);
  final w = page.effectiveWidthMm * page.scaleDenominator;
  final h = page.effectiveHeightMm * page.scaleDenominator;
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, page.copyWith(originX: -w / 2, originY: -h / 2)));
}

/// Four walls anticlockwise from the south-west corner, an entrance door in
/// the south (long) wall and two windows in the north one. Each wall and
/// opening is its own root-level group at the identity, as the tools add
/// them.
void _room(DraftDocument doc) {
  Handle group(Component c, String label) {
    final h = doc.handleSeed.next();
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      switch (c) {
        final WallParams w => SetComponentCommand<WallParams>(h, w),
        final OpeningParams o => SetComponentCommand<OpeningParams>(h, o),
        final SeparatorParams s => SetComponentCommand<SeparatorParams>(h, s),
        final RoomParams r => SetComponentCommand<RoomParams>(h, r),
        _ => throw ArgumentError.value(c),
      },
      // A separator and a room are objects of the drawing layer, as the
      // tools add them.
      if (c is SeparatorParams || c is RoomParams)
        SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc))),
    ], label: label));
    return h;
  }

  final x0 = kSheetMin.x + kRoomLeft, x1 = kSheetMin.x + kRoomRight;
  final y0 = kSheetMin.y + kRoomBottom, y1 = kSheetMin.y + kRoomTop;
  Handle wall(double sx, double sy, double ex, double ey) => group(
      WallParams(sx, sy, ex, ey, kRoomWall, Justification.centre), 'Add wall');
  final south = wall(x0, y0, x1, y0);
  wall(x1, y0, x1, y1);
  final north = wall(x1, y1, x0, y1);
  wall(x0, y1, x0, y0);
  group(OpeningParams(south, 6900, 1100, OpeningKind.door), 'Add door');
  // The north wall runs east to west: positions are from its east end.
  group(OpeningParams(north, 3500, 1800, OpeningKind.window), 'Add window');
  group(OpeningParams(north, 9500, 1800, OpeningKind.window), 'Add window');
  _sections(group, x0, x1, y0, y1);
}

/// The Salon (the whole floor but the two below, seeded west of the VIP
/// corner), the VIP corner and the Garden, as rooms the tools would make.
void _sections(Handle Function(Component, String) group, double x0, double x1,
    double y0, double y1) {
  Handle sep(double sx, double sy, double ex, double ey) =>
      group(SeparatorParams(sx, sy, ex, ey), 'Add separator');
  final vx = kSheetMin.x + kVipWest, vy = kSheetMin.y + kVipSouth;
  sep(vx, y1, vx, vy);
  sep(vx, vy, x1, vy);
  final gy = kSheetMin.y + kGardenSouth;
  sep(x0, gy, x1, gy);
  sep(x1, y0, x1, gy);
  sep(x0, y0, x0, gy);
  group(
      RoomParams(kSheetMin.x + 5000, kSheetMin.y + 6000, 'Salon'), 'Add room');
  group(RoomParams(kSheetMin.x + 12500, kSheetMin.y + 7000, 'VIP'), 'Add room');
  group(
      RoomParams(kSheetMin.x + 7000, kSheetMin.y - 1100, 'Garden'), 'Add room');
}
