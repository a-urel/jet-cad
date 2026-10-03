// Shared by the spec 14a tests: a servable table symbol and a planter,
// their library entries, and a plan to place them in. Base points and
// placements are off the origin (the degenerate-fixture rule).
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/symbols.dart';

/// A 1200 x 800 top with two 450 x 450 chairs below and above it; the base
/// point is the top's centre, (900, 700).
FurnitureSymbol tableSymbol({String key = 'test.table', int seats = 2}) =>
    FurnitureSymbol(
      key: key,
      name: 'Test table',
      category: 'Tests',
      tags: const ['table', 'test'],
      seats: seats,
      baseX: 900,
      baseY: 700,
      shapes: const [
        PolylineShape([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
            closed: true),
        PolylineShape([(675, -50), (1125, -50), (1125, 400), (675, 400)],
            closed: true),
        PolylineShape([(675, 1000), (1125, 1000), (1125, 1450), (675, 1450)],
            closed: true),
      ],
    );

/// A Ø 380 stool, its seat first; base point at its centre.
const FurnitureSymbol stoolSymbol = FurnitureSymbol(
  key: 'test.stool',
  name: 'Test stool',
  category: 'Tests',
  tags: ['stool', 'test'],
  seats: 1,
  baseX: 400,
  baseY: 300,
  shapes: [CircleShape(400, 300, 190), CircleShape(400, 300, 150)],
);

/// Not servable.
const FurnitureSymbol planterSymbol = FurnitureSymbol(
  key: 'test.planter',
  name: 'Test planter',
  category: 'Tests',
  tags: ['planter', 'test'],
  baseX: 250,
  baseY: 250,
  shapes: [CircleShape(250, 250, 250)],
);

SymbolLibrary libraryOf(List<FurnitureSymbol> catalog) =>
    SymbolLibrary.decode(Uint8List.fromList(utf8.encode(
        DraftDocumentCodec.encodeToString(buildSymbolLibrary(catalog)))));

SymbolEntry entryOf(FurnitureSymbol s) => libraryOf([s]).entries.single;

/// An empty plan with the app's components, in millimetres.
DraftDocument plan() {
  final doc = DraftDocument.empty();
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

const double kDeg37 = 37 * math.pi / 180;

/// `translate(at) · R(theta) · (mirror x) · translate(-base)`.
Transform2 placementAt(double x, double y, double theta,
        {bool mirrored = false, double baseX = 900, double baseY = 700}) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
        .multiply(Transform2.translation(-baseX, -baseY));
