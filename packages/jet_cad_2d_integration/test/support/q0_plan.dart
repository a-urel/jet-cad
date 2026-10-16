// The decimal separator's fixture (jet_cad_floor_plan/test/
// decimal_separator_test.dart:37-80) as a plan file (3a Task 27): a box of
// four 200 mm walls at the corpus far origin turned 23 degrees, a cm page at
// 1:20, its origin off zero, grid snap off, the separator point; a room
// `Kitchen` (12.37 m²) and an aligned dimension in a turned group (345.7).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

import 'plans.dart';

/// A box of four 200 mm centred walls, centrelines (0, 0)-(4,050, 3,413):
/// inner faces x 100..3,950, y 100..3,313, 3,850 × 3,213 = 12,370,050 mm²,
/// 12.37005 m² (0.00495 from the tie 12.375).
const List<W> q0Walls = [
  W(0, 0, 4050, 0, 200),
  W(4050, 0, 4050, 3413, 200),
  W(4050, 3413, 0, 3413, 200),
  W(0, 3413, 0, 0, 200),
];

/// The fixture's page: cm at 1:20, its origin off zero, grid snap off (so a
/// tool click resolves to its raw point), the separator `point`.
final PageComponent q0Page = PageComponent(
    originX: -4180.5,
    originY: 2645.25,
    scaleDenominator: 20,
    displayUnit: DisplayUnit.centimeters,
    snapToGrid: false);

/// The fixture's plan file, its room and its dimension: [q0Walls] at the
/// corpus far origin turned 23° ([corpus]), [q0Page], a room `Kitchen`
/// seeded at plan (1,500.25, 1,700.75), and an aligned dimension in a root
/// group of its own at plan (600.5, 4,400.25) turned a further 0.4 rad,
/// from local (−120.5, 40.25) to (3,336.8, 40.25): 3,457.3 mm, 3,457
/// tenths of a cm (0.2 from the half), 345.7.
({String json, Handle room, Handle dim}) q0PlanJson() {
  late Handle room, dim;
  final json = planWith((d) {
    final plan = buildPlan(d, q0Walls, place: corpus);
    attachPage(d, q0Page);
    room = addRoom(d, plan.at(1500.25, 1700.75), 'Kitchen');
    dim = addDimension(
        d, const FixedEnd(-120.5, 40.25), const FixedEnd(3336.8, 40.25),
        offset: 300.25,
        at: corpus.m
            .multiply(Transform2.translation(600.5, 4400.25))
            .multiply(Transform2.rotation(0.4)));
  });
  return (json: json, room: room, dim: dim);
}

/// [doc]'s page with separator [s], one command, as the Page panel's `_set`
/// makes it (today's `separatorTo`).
DraftCommand separatorTo(DraftDocument doc, DecimalSeparator s) =>
    SetComponentCommand<PageComponent>(
        doc.rootHandle, pageOf(doc).copyWith(decimalSeparator: s));
