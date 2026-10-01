import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The export fixture of spec 13's Testing section (plan 13, P-3).
///
/// One builder for every export test, so no test can quietly fall back on a
/// degenerate document. **Nothing here sits at the origin, no transform is
/// the identity, and no style equals its default**:
///
/// - the page is A4 landscape at 1:[scaleDenominator] (50 unless a test asks
///   for another scale), its lower-left corner at world (3000, -1500), its
///   background dark grey `0xFF303030` (so the screen's foreground is white
///   and an export that keeps it draws white on white);
/// - [instance] is rotated 30 degrees and scaled (1.5, -0.75) -- mirrored, so
///   a lost sign shows -- with colour (red) and lineweight (0.70 mm)
///   overrides over BYBLOCK leaves, and its definition's `basePoint` is not
///   the origin;
/// - every root leaf names its own colour and lineweight;
/// - the "separator" is a childless group with one dashed polyline, the shape
///   spec F-8 gives a real `SeparatorParams` group (the render package does
///   not know `SeparatorParams`; the app tests use a real one).
///
/// `export_fixture_test.dart` beside this file pins every one of these
/// properties, so the fixture cannot rot into a degenerate one.
final class ExportFixture {
  ExportFixture._(this.document, this.page);

  final DraftDocument document;
  final PageComponent page;

  /// The definition [instance] places; `basePoint` (120, 45).
  late final Handle definition;

  /// Root instance of [definition]: translation (7000, 5600), rotation 30
  /// degrees, scale (1.5, -0.75); colour red, lineweight 70.
  late final Handle instance;

  /// A line and a polyline of [definition], both BYBLOCK.
  late final Handle instanceLine, instancePolyline;

  /// A point entity of [definition], BYBLOCK: drawn as a 0.70 mm square.
  late final Handle pointInInstance;

  /// The separator-like group (F-8): childless, one dashed polyline.
  late final Handle separatorGroup, separatorLine;

  /// A group with a line of its own ([outerGroupLine]), an instance of its
  /// own ([outerGroupInstance], of [outerDefinition]) and [nestedGroup].
  late final Handle outerGroup, outerGroupLine;
  late final Handle outerDefinition, outerGroupInstance, outerInstanceLeaf;

  /// A group inside [outerGroup], with one line, [nestedLine].
  late final Handle nestedGroup, nestedLine;

  /// Root leaves.
  late final Handle line, closedPolyline, dashed, arc, circle;

  /// The translucent fill (alpha 0x80) and its closed boundary polyline.
  late final Handle fill, fillBoundary;

  /// "Yatak Odası", 250 mm high (5 mm on paper at 1:50).
  late final Handle labelBig;

  /// "WC", 25 mm high: 0.5 mm on paper at 1:50, a cap height of 1.42 pt,
  /// below the default level-of-detail cull of 3. Under [labelWcStyle], not
  /// the Standard style.
  late final Handle labelWc;

  /// The text style record "WC" is drawn under ("Label", family `Arial`): a
  /// second record, so no fixture text relies on the Standard default.
  late final Handle labelWcStyle;

  /// An ACI 7 line: the foreground colour, white on the dark screen page.
  late final Handle aci7Line;

  /// A line wholly outside the sheet at every scale: left of its origin.
  late final Handle outsideLine;
}

/// The page's lower-left corner in world millimetres.
const double kExportOriginX = 3000;
const double kExportOriginY = -1500;

/// The screen page's dark background.
const int kExportBackground = 0xFF303030;

/// The DASHED linetype's values, copied from the app's
/// `kDashedLinetypeRecord` (`apps/floor_planner/lib/parametric/
/// separator.dart`): the render package does not import the app.
const LinetypeRecord kExportDashedLinetype = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'DASHED',
  description: 'Dashed __ __ __',
  pattern: DashPattern(dashes: [200, -100], totalLength: 300),
);

/// The instance's transform: translation, rotation 30 degrees, scale
/// (1.5, -0.75), composed in that order.
final Transform2 kExportInstanceTransform = Transform2.translation(7000, 5600)
    .multiply(Transform2.rotation(math.pi / 6))
    .multiply(Transform2.scale(1.5, -0.75));

/// The instance's overrides.
const int kExportInstanceRgb = 0xFF0000;
const int kExportInstanceLineweight = 70;

/// The arc's sweep: -110 degrees.
const double kExportArcSweep = -110 * math.pi / 180;

/// The fill's transparency: alpha `255 - 127 = 0x80`.
const int kExportFillTransparency = 127;

ExportFixture exportFixture({
  double scaleDenominator = 50,
  TextMeasurer measurer = const InsertionPointMeasurer(),
}) {
  final doc = DraftDocument.empty(measurer: measurer);
  final page = PageComponent(
    orientation: PageOrientation.landscape,
    scaleDenominator: scaleDenominator,
    originX: kExportOriginX,
    originY: kExportOriginY,
    background: kExportBackground,
  );
  PageComponent.register(doc.components);
  doc.commands.execute(
    SetComponentCommand<PageComponent>(doc.rootHandle, page),
  );
  if (!doc.tables.linetypes.contains(kExportDashedLinetype.handle)) {
    doc.tables.linetypes.add(kExportDashedLinetype);
  }

  final f = ExportFixture._(doc, page);
  final root = doc.rootHandle;

  // Root leaves, each with its own colour and lineweight.
  f.line = _leaf(
    doc,
    root,
    EntityKind.line,
    [4000, 500, 9000, 2500],
    color: const TrueColor(0x1565C0),
    lineweight: 35,
  );
  f.closedPolyline = _leaf(
    doc,
    root,
    EntityKind.polyline,
    [
      10000, 1000, 13000, 1200, 12500, 3500, 10200, 3000, //
      10000, 1000, // the closing pair
    ],
    color: const TrueColor(0x2E7D32),
    lineweight: 50,
  );
  f.dashed = _leaf(
    doc,
    root,
    EntityKind.polyline,
    [4000, 7500, 9000, 7500, 9000, 8500],
    color: const TrueColor(0x6A1B9A),
    lineweight: 25,
    linetype: ReservedHandles.dashedLinetype,
  );
  f.arc = _leaf(
    doc,
    root,
    EntityKind.arc,
    [14500, 6000],
    scalars: [1200, 0.4, kExportArcSweep],
    color: const TrueColor(0xEF6C00),
    lineweight: 18,
  );
  f.circle = _leaf(
    doc,
    root,
    EntityKind.circle,
    [6000, 4600],
    scalars: [800],
    color: const TrueColor(0x00838F),
    lineweight: 13,
  );
  _addFill(doc, root, f);
  f.labelBig = _text(doc, root, 'Yatak Odası', 4500, 3500, 250);
  f.labelWcStyle = doc.handleSeed.next();
  doc.tables.textStyles.add(TextStyleRecord(
    handle: f.labelWcStyle,
    name: 'Label',
    fontFamily: 'Arial',
  ));
  f.labelWc = _text(doc, root, 'WC', 10500, 4500, 25, style: f.labelWcStyle);
  f.aci7Line = _leaf(
    doc,
    root,
    EntityKind.line,
    [3600, 300, 16800, 400],
    color: const IndexedColor(7),
    lineweight: 35,
  );
  f.outsideLine = _leaf(
    doc,
    root,
    EntityKind.line,
    // Left of the sheet's left edge (x 3000), which no scale moves: the
    // sheet grows right and up from its origin, so a line placed beyond its
    // right or top edge at 1:50 can fall inside it at 1:100.
    [-6000, 2500, -3500, 3700],
    color: const TrueColor(0x795548),
    lineweight: 35,
  );

  // The instance and its definition (basePoint off the origin).
  f.definition = _definition(doc, 'export-symbol', Vector2(120, 45));
  f.instanceLine = _leaf(
    doc,
    f.definition,
    EntityKind.line,
    [200, 100, 1000, 400],
    color: const ByBlockColor(),
    lineweight: kByBlock,
  );
  f.instancePolyline = _leaf(
    doc,
    f.definition,
    EntityKind.polyline,
    [200, 100, 600, 700, 1000, 400],
    color: const ByBlockColor(),
    lineweight: kByBlock,
  );
  f.pointInInstance = _leaf(
    doc,
    f.definition,
    EntityKind.point,
    [500, 300],
    color: const ByBlockColor(),
    lineweight: kByBlock,
  );
  f.instance = _instance(
    doc,
    root,
    f.definition,
    kExportInstanceTransform,
    color: const TrueColor(kExportInstanceRgb),
    lineweight: kExportInstanceLineweight,
  );

  // The separator-like group (F-8).
  f.separatorGroup = _group(
    doc,
    root,
    Transform2.translation(9200, 5200).multiply(Transform2.rotation(0.1)),
  );
  f.separatorLine = _leaf(
    doc,
    f.separatorGroup,
    EntityKind.polyline,
    [100, 150, 2600, 150],
    color: const ByLayerColor(),
    lineweight: 35,
    linetype: ReservedHandles.dashedLinetype,
  );

  // The outer group: a line, an instance and a nested group of its own.
  f.outerGroup = _group(
    doc,
    root,
    Transform2.translation(14600, 1300).multiply(Transform2.rotation(-0.35)),
  );
  f.outerGroupLine = _leaf(
    doc,
    f.outerGroup,
    EntityKind.line,
    [100, 100, 900, 600],
    color: const TrueColor(0x283593),
    lineweight: 50,
  );
  f.outerDefinition = _definition(doc, 'export-outer-symbol', Vector2(30, -20));
  f.outerInstanceLeaf = _leaf(
    doc,
    f.outerDefinition,
    EntityKind.line,
    [50, 40, 650, 340],
    color: const ByBlockColor(),
    lineweight: kByBlock,
  );
  f.outerGroupInstance = _instance(
    doc,
    f.outerGroup,
    f.outerDefinition,
    Transform2.translation(
      1200,
      200,
    ).multiply(Transform2.rotation(0.5)).multiply(Transform2.scale(0.8, 1.2)),
    color: const TrueColor(0x00695C),
    lineweight: 40,
  );
  f.nestedGroup = _group(
    doc,
    f.outerGroup,
    Transform2.translation(300, 900).multiply(Transform2.rotation(0.2)),
  );
  f.nestedLine = _leaf(
    doc,
    f.nestedGroup,
    EntityKind.line,
    [50, 50, 700, 250],
    color: const TrueColor(0xAD1457),
    lineweight: 30,
  );

  return f;
}

Handle _leaf(
  DraftDocument doc,
  Handle owner,
  EntityKind kind,
  List<double> coords, {
  List<double> scalars = const [],
  required DraftColor color,
  required int lineweight,
  Handle linetype = ReservedHandles.continuousLinetype,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: owner,
        kind: kind,
        layer: ReservedHandles.layerZero,
        linetype: linetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: color,
        lineweight: lineweight,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars),
      ),
    ),
  );
  return handle;
}

Handle _text(
  DraftDocument doc,
  Handle owner,
  String text,
  double x,
  double y,
  double height, {
  Handle style = ReservedHandles.standardTextStyle,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(
    AddEntityCommand(
      record: EntityRecord(
        handle: handle,
        owner: owner,
        kind: EntityKind.text,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const TrueColor(0x37474F),
        lineweight: 25,
        transparency: 0,
        flags: 0,
        text: text,
        textStyle: style,
        textAttrs: packTextAttrs(),
      ),
      payload: textPayload(Vector2(x, y), height),
    ),
  );
  return handle;
}

void _addFill(DraftDocument doc, Handle owner, ExportFixture f) {
  f.fill = doc.handleSeed.next();
  f.fillBoundary = doc.handleSeed.next();
  doc.commands.execute(
    AddRegionCommand(
      fill: EntityRecord(
        handle: f.fill,
        owner: owner,
        kind: EntityKind.fill,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const TrueColor(0x1E88E5),
        lineweight: 25,
        transparency: kExportFillTransparency,
        flags: 0,
      ),
      boundary: EntityRecord(
        handle: f.fillBoundary,
        owner: owner,
        kind: EntityKind.polyline,
        layer: ReservedHandles.layerZero,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const TrueColor(0x0D47A1),
        lineweight: 35,
        transparency: 0,
        flags: 0,
      ),
      boundaryPayload: polylinePayload([
        Vector2(11000, 6500),
        Vector2(13500, 6800),
        Vector2(13000, 8300),
        Vector2(11200, 8000),
      ], closed: true),
    ),
  );
}

Handle _definition(DraftDocument doc, String name, Vector2 basePoint) {
  final handle = doc.handleSeed.next();
  doc.tree.addDefinition(
    Definition(
      handle: handle,
      name: name,
      basePoint: basePoint,
      children: const [],
    ),
  );
  return handle;
}

Handle _instance(
  DraftDocument doc,
  Handle parent,
  Handle definition,
  Transform2 transform, {
  required DraftColor color,
  required int lineweight,
}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(
    AddNodeCommand(
      InstanceNode(
        handle: handle,
        parent: parent,
        transform: transform,
        definition: definition,
        layer: ReservedHandles.layerZero,
        color: color,
        lineweight: lineweight,
      ),
    ),
  );
  return handle;
}

Handle _group(DraftDocument doc, Handle parent, Transform2 transform) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(
    AddNodeCommand(
      GroupNode(
        handle: handle,
        parent: parent,
        transform: transform,
        children: const [],
      ),
    ),
  );
  return handle;
}
