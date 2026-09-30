import 'package:floor_planner/new_document.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/live_objects.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  PageComponent? pageOf(DraftDocument d) =>
      d.components.get<PageComponent>(d.rootHandle);

  test(
      'ND1 the new document is empty, has no history, is in millimetres, '
      'holds DASHED at handle 6, and its page is the fixed literal '
      '(spec 12a D4, T-11)', () {
    final doc = newDocument(measurer);

    expect(doc.entities.liveCount, 0);
    expect(doc.commands.undoDepth, 0);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
    // The header's own default is unitless; the set-up changes it.
    expect(DraftDocument.empty(measurer: measurer).header.units,
        isNot(DrawingUnits.millimeters));
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype],
        kDashedLinetypeRecord);
    expect(doc.tables.linetypes.byName('DASHED')!.handle,
        ReservedHandles.dashedLinetype);

    // The literal, written out here, not read from `defaultPage`.
    expect(pageOf(doc), PageComponent(originX: -7425, originY: -5250));
    // And what the literal means: the A4 landscape sheet at 1:50, 14,850 x
    // 10,500 world mm, centred on the world origin.
    final sheet = sheetWorldRect(pageOf(doc)!);
    expect([sheet.minX, sheet.minY, sheet.maxX, sheet.maxY],
        [-7425.0, -5250.0, 7425.0, 5250.0]);
  });

  test(
      'ND2 the set-up alone registers both, sets millimetres and DASHED, and '
      'adds no page, entity or history (spec 12a D4)', () {
    final doc = prepareDocument(measurer);

    expect(doc.components.isRegistered<PageComponent>(), isTrue);
    expect(doc.components.isRegistered<WallParams>(), isTrue);
    expect(pageOf(doc), isNull);
    expect(doc.entities.liveCount, 0);
    expect(doc.commands.undoDepth, 0);
    expect(doc.header.units, DrawingUnits.millimeters);
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype],
        kDashedLinetypeRecord);
  });

  test(
      'ND3 the new document encodes, and decodes with registerAppComponents '
      'to the same page, units, DASHED and bytes (spec 12a D4, D8)', () {
    final doc = newDocument(measurer);
    final saved = DraftDocumentCodec.encodeToString(doc);

    final loaded = DraftDocumentCodec.decodeString(saved,
        measurer: measurer, registerComponents: registerAppComponents);

    expect(pageOf(loaded), PageComponent(originX: -7425, originY: -5250));
    expect(pageOf(loaded), pageOf(doc));
    expect(loaded.components.unknownOf(loaded.rootHandle), isEmpty);
    expect(loaded.header.units, DrawingUnits.millimeters);
    expect(loaded.tables.linetypes[ReservedHandles.dashedLinetype],
        kDashedLinetypeRecord);
    expect(DraftDocumentCodec.encodeToString(loaded), saved);
  });

  group('ND4 the sample\'s bytes, decoded (spec 12a D8, S-1)', () {
    late DraftDocument sample;
    late String bytes;
    late List<Handle> sampleWalls;
    setUp(() {
      sample = startupPlan(measurer);
      bytes = DraftDocumentCodec.encodeToString(sample);
      sampleWalls = liveObjectsOf<WallParams>(sample);
      // The sample's page is centred on the flat's extents, off the world
      // origin: not the new document's page.
      expect(pageOf(sample), isNotNull);
      expect(
          pageOf(sample), isNot(PageComponent(originX: -7425, originY: -5250)));
      expect(sampleWalls, hasLength(10));
    });

    test('with registerAppComponents: a live page and live walls', () {
      final loaded = DraftDocumentCodec.decodeString(bytes,
          measurer: measurer, registerComponents: registerAppComponents);
      expect(pageOf(loaded), pageOf(sample));
      expect(liveObjectsOf<WallParams>(loaded), sampleWalls);
    });

    test('with the page\'s registration alone: no live wall', () {
      final loaded = DraftDocumentCodec.decodeString(bytes,
          measurer: measurer, registerComponents: PageComponent.register);
      expect(pageOf(loaded), pageOf(sample));
      expect(liveObjectsOf<WallParams>(loaded), isEmpty);
      expect(loaded.components.unknownOf(sampleWalls.first), isNotEmpty);
    });

    test('with the catalog\'s registration alone: no live page', () {
      final loaded = DraftDocumentCodec.decodeString(bytes,
          measurer: measurer,
          registerComponents: parametricCatalog.registerComponents);
      expect(liveObjectsOf<WallParams>(loaded), sampleWalls);
      expect(loaded.components.isRegistered<PageComponent>(), isFalse);
      expect(pageOf(loaded), isNull);
      expect(loaded.components.unknownOf(loaded.rootHandle), isNotEmpty);
    });
  });
}
