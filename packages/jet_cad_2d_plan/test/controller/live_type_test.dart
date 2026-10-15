// Spec 3a C1.5 (Task 6), Review Focus 5's contract half: a kit's services
// answer liveTypeIdOf: a live object's type id, and null for a frozen
// object (E2), whose id the catalog's typeIdOf still answers, for a
// missing kit's object, and for anything that is no object. Squares and a
// disc off the origin, turned.
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';

/// The box kit's square, and a tool whose factory hands [see] the kit's
/// services (a factory runs once per document; the services are the kit's
/// for the controller's life).
PlanKit seeingKit(Switches sw, void Function(PlanServices services) see) =>
    PlanKit(
      id: 'box',
      version: '1.4.0',
      types: [
        PlanType<SquareParams>(
            id: SquareParams.id,
            fromJson: SquareParams.fromJson,
            parametric: SquareType(sw)),
      ],
      tools: [
        PlanTool(
            id: 'box.stamp',
            icon: Icons.crop_square,
            create: (services) {
              see(services);
              return StampTool();
            }),
      ],
      names: const KitNames({
        'en': {'type:box.square': 'Square', 'tool:box.stamp': 'Stamp'},
      }),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'LS-frozen liveTypeIdOf: a live square\'s id; null for a frozen square '
      "(the catalog's typeIdOf still answers it), a missing kit's disc, a "
      'line, the root and a handle that names nothing', () {
    final sw = Switches();
    // A plan holding a disc of the ring kit, opened below without it.
    final withRing = PlanController(kits: [seeingKit(sw, (_) {}), ringKit(sw)]);
    addTearDown(withRing.dispose);
    final disc = addObject(withRing.document, nearSquare(-2500.5, 1800.25, 0.7),
        const DiscParams(radius: 400));
    final json = withRing.save();

    PlanServices? seen;
    final c =
        PlanController(kits: [seeingKit(sw, (s) => seen = s)], json: json);
    addTearDown(c.dispose);
    final s = seen!;
    final d = c.document;
    expect(c.locked.value, {disc}, reason: "premise: the missing kit's disc");
    final broken =
        addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
    final healthy = addObject(
        d, nearSquare(4000, -500, 0.25), const SquareParams(side: 500));
    final line = addLine(d, Vector2(6100.5, 2950.25), Vector2(7400.75, 3600.5));
    expect(s.liveTypeIdOf(broken), SquareParams.id,
        reason: 'premise: live until its code fails');
    sw.failing.add('reach');
    expect(c.execute(TransformNodeCommand(broken, nearSquare(100.5, 50.25, 0))),
        isFalse);
    expect(c.frozen, {broken}, reason: 'premise: frozen');
    // M-LS-1: `KitServices.liveTypeIdOf` without its frozen test.
    expect(s.liveTypeIdOf(broken), isNull);
    expect(c.typeOf(broken)?.id, SquareParams.id,
        reason: "the catalog's typeIdOf still answers a frozen object");
    expect(s.liveTypeIdOf(healthy), SquareParams.id);
    expect(s.liveTypeIdOf(disc), isNull);
    expect(s.liveTypeIdOf(line), isNull);
    expect(s.liveTypeIdOf(d.rootHandle), isNull);
    expect(s.liveTypeIdOf(const Handle(0x7FFF1)), isNull);
  });
}
