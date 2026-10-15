// The fixture placement the label tests use (2b Task 3): today's fixture
// placement (jet_cad_floor_plan/test/tables/table_fixture.dart:72-78). The
// placer's form is the contract's placementTransform (3a Task 1).
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// `translate(at) · R(theta) · (mirror x) · translate(-base)`.
Transform2 placementAt(double x, double y, double theta,
        {bool mirrored = false, double baseX = 900, double baseY = 700}) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
        .multiply(Transform2.translation(-baseX, -baseY));
