// Plan files for the integration tests (3a Task 26; Tasks 27 and 28 use
// them): a plan is built in a scratch controller's document, the plan
// library's own registration, page and system, then saved; a test opens
// the text with its own controller. The architecture fixtures are today's
// (jet_cad_floor_plan/test/support/wall_fixture.dart, wall_shell.dart,
// room_fixture.dart, dimension_fixture.dart): the wall fixture is Task 12's
// wall_fixture.dart, the room plan model Task 18's room_plans.dart, the
// dimension and object builders Tasks 21-22's dimension_plans.dart and the
// wall's world ends Task 15's opening_support.dart, re-exported, never
// copied (R-P14); the rest is re-stated over the kit's public parameters
// (spec C6: public libraries only).
import 'dart:ui' show Locale;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../dimension/dimension_plans.dart' show buildPlanIn;
import 'room_plans.dart';

export '../dimension/dimension_plans.dart'
    show
        addDimension,
        addOpening,
        addSeparator,
        dimLines,
        dimText,
        dimTextHandle,
        fixedAt;
export 'editor_rig.dart' show kitCatalog;
export 'opening_support.dart' show worldEndsOf;
export 'room_plans.dart'
    show
        W,
        S,
        O,
        Placement,
        origin,
        corpus,
        corpusGroups,
        km1000,
        km1000Axis,
        km1000Groups,
        placements,
        groupFor,
        sampleWalls,
        sampleOpenings,
        sampleSeparator,
        sampleColumn,
        sampleSeeds,
        twoRoomWalls,
        boxWalls,
        recordOf,
        worldPoints,
        addRoom,
        labelsOf,
        textOf,
        worldTintOf,
        pageOf,
        anchorOf,
        deleteObject,
        labelStrings,
        kindsOf;
export 'wall_fixture.dart'
    show
        ox,
        oy,
        far,
        plan,
        nextUp,
        polar,
        groupAt,
        oracleMeet,
        nearestIn,
        insideRing,
        addWallLocal,
        addWall,
        kids,
        kindOf,
        payloadOf,
        pointsOf,
        sharedNear,
        isRectNear,
        enc,
        canon,
        worldOutline,
        walls,
        xy,
        faceOf,
        facesOf,
        expectMitre,
        expectSquare,
        driftOf;

/// A plan file: a scratch controller over [kits] (made by [first], C1.9,
/// when given), [build] run on its document, then saved. Handles [build]
/// allocates survive the save: a controller that opens the text has them.
String planWith(void Function(DraftDocument d) build,
    {List<PlanKit>? kits, PlanBuild? first}) {
  final c = PlanController(kits: kits ?? [architectureKit], build: first);
  try {
    build(c.document);
    return c.save();
  } finally {
    c.dispose();
  }
}

/// The kit's words in English, as the scratch controller's are (C1.9).
final KitWords englishWords =
    KitNamesWords(architectureKit.names, () => const Locale('en'));

/// The sample flat's outer corner and size (startup_plan.dart:53-56;
/// buildSampleFlat keeps them, not exported).
const double kPlanOriginX = 12000.0, kPlanOriginY = 8000.0;
const double kPlanWidth = 14000.0, kPlanHeight = 9000.0;

/// C5: a T. The through wall C (0, 0) -> (6000, 0), 200; the stem S from
/// (2500, 0) north, 100 centred (dimension_fixture.dart:99-101).
const List<W> c5Walls = [W(0, 0, 6000, 0, 200), W(2500, 0, 2500, 3000, 100)];

/// The handles [buildPlan] added, in the order given, and its placement.
final class Plan {
  Plan(this.place, this.walls, this.seps, this.openings);
  final Placement place;
  final List<Handle> walls, seps, openings;

  Vector2 at(double x, double y) => place.at(x, y);
}

/// Today's `buildPlan` (room_fixture.dart:118-162) into [doc], which has
/// the plan's system (a [planWith] document): its creation of a document,
/// its system and its DASHED record are the plan library's here (C1.3).
/// The objects are dimension_plans.dart's `buildPlanIn`'s.
Plan buildPlan(DraftDocument doc, List<W> walls,
    {List<S> seps = const [],
    List<W> wallsAfter = const [],
    List<O> openings = const [],
    Placement place = origin}) {
  final b = buildPlanIn(doc, walls,
      seps: seps, wallsAfter: wallsAfter, openings: openings, place: place);
  return Plan(place, b.walls, b.seps, b.openings);
}

/// Attaches [page] to [doc]'s root, one command through the dispatcher, as
/// the Page panel does; registers `PageComponent` first when [doc] has not
/// (room_fixture.dart:551-558).
void attachPage(DraftDocument doc, PageComponent page) {
  if (!doc.components.isRegistered<PageComponent>()) {
    PageComponent.register(doc.components);
  }
  doc.commands
      .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
}

/// [room]'s name to [name], one command, its other parameters kept
/// (room_fixture.dart:694-697).
DraftCommand renameRoom(DraftDocument doc, Handle room, String name) =>
    SetComponentCommand<RoomParams>(
        room, doc.components.get<RoomParams>(room)!.copyWith(name: name));

/// Today's touch_tools_test `samplePlan()`: D23's nine walls and the
/// column, the separator and the fifteen openings at the origin (no
/// rooms, no page change).
String d23PlanJson() =>
    planWith((d) => buildPlan(d, [...sampleWalls(), sampleColumn],
        seps: const [sampleSeparator], openings: sampleOpenings));
