// The export fixture: a plan on the default page with, around the sheet's
// centre (not the origin), two marks turned 0.4 and -1.1 rad and a line,
// saved by a controller of the given kits; and the same plan without its
// page.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'mark_kit.dart';

String exportPlanJson({List<PlanKit>? kits, bool page = true}) {
  final scratch = PlanController(kits: kits ?? [markKit()]);
  final doc = scratch.document;
  final root = doc.rootHandle;
  final sheet = sheetWorldRect(doc.components.get<PageComponent>(root)!);
  final cx = (sheet.minX + sheet.maxX) / 2, cy = (sheet.minY + sheet.maxY) / 2;
  Transform2 put(double dx, double dy, double turn) =>
      Transform2.translation(cx + dx, cy + dy)
          .multiply(Transform2.rotation(turn));
  addMark(doc, ReservedHandles.layerZero,
      at: put(-2600.5, 900.25, 0.4), size: 700.5);
  addMark(doc, ReservedHandles.layerZero,
      at: put(2100.25, -700.5, -1.1), size: 520.25);
  doc.commands.execute(addDrafted(
      doc,
      EntityKind.line,
      linePayload(Vector2(cx - 3900.5, cy - 2100.25),
          Vector2(cx + 3300.75, cy + 1800.5)),
      layer: ReservedHandles.layerZero));
  if (!page) {
    doc.commands.execute(SetComponentCommand<PageComponent>(root, null));
  }
  final json = scratch.save();
  scratch.dispose();
  return json;
}
