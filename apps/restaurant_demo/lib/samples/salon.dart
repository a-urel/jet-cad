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
// 1-3, 4-5, the booths 6-7, the stools 8-11.

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
  p.place('restaurant.table.rect.four', 5000, 7600);
  p.place('restaurant.table.rect.four', 7500, 7600);
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

/// The Salon's sheet: A3 landscape at 1:50, centred on the world origin as
/// the default A4 sheet is, so [kSheetMin] still measures the placements
/// (the default sheet's lower-left corner) and the room lies inside it.
void _sheet(DraftDocument doc) {
  final page = PageComponent(widthMm: 297, heightMm: 420);
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
        _ => throw ArgumentError.value(c),
      },
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
}
