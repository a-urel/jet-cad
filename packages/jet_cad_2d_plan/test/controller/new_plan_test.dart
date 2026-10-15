// D-28's generic half (spec 3a C1.3, Appendix A): jet_cad_floor_plan's
// test/new_document_test.dart ND1, ND3 and two ND4 cases, ported over the
// plan library's newPlanDocument and the test kit's registration (the
// controller's), assertions unchanged. Not here: ND1's and ND3's DASHED
// lines and ND4's "with registerAppComponents: a live page and live
// walls", which need the architecture kit (Task 17); ND2, whose premise (a
// set-up adding no page, new_document.dart:18-24) the plan library does not
// have (new_plan.dart:23-33). The sample is two slabs off the origin,
// turned, on a 1:100 page whose origin is not the new plan's.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show FlutterTextMeasurer;
import 'package:jet_cad_2d_plan/src/controller/new_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  final catalog = catalogOf([testKit()]);
  void register(ComponentRegistry r) => registerPlanComponents(r, catalog);

  PageComponent? pageOf(DraftDocument d) =>
      d.components.get<PageComponent>(d.rootHandle);

  test(
      'ND1 the new document is empty, has no history, is in millimetres, '
      'and its page is the fixed literal (spec 12a D4, T-11)', () {
    final doc = newPlanDocument(measurer, register: register);

    expect(doc.entities.liveCount, 0);
    expect(doc.commands.undoDepth, 0);
    expect(doc.commands.canUndo, isFalse);
    expect(doc.commands.canRedo, isFalse);
    // The header's own default is unitless; the set-up changes it.
    expect(DraftDocument.empty(measurer: measurer).header.units,
        isNot(DrawingUnits.millimeters));
    expect(doc.header.units, DrawingUnits.millimeters);

    // The literal, written out here, not read from `defaultPlanPage`.
    expect(pageOf(doc), PageComponent(originX: -7425, originY: -5250));
    // And what the literal means: the A4 landscape sheet at 1:50, 14,850 x
    // 10,500 world mm, centred on the world origin.
    final sheet = sheetWorldRect(pageOf(doc)!);
    expect([sheet.minX, sheet.minY, sheet.maxX, sheet.maxY],
        [-7425.0, -5250.0, 7425.0, 5250.0]);
  });

  test(
      "ND3 the new document encodes, and decodes with the plan's "
      'registration to the same page, units and bytes (spec 12a D4, D8)', () {
    final doc = newPlanDocument(measurer, register: register);
    final saved = DraftDocumentCodec.encodeToString(doc);

    final loaded = DraftDocumentCodec.decodeString(saved,
        measurer: measurer, registerComponents: register);

    expect(pageOf(loaded), PageComponent(originX: -7425, originY: -5250));
    expect(pageOf(loaded), pageOf(doc));
    expect(loaded.components.unknownOf(loaded.rootHandle), isEmpty);
    expect(loaded.header.units, DrawingUnits.millimeters);
    expect(DraftDocumentCodec.encodeToString(loaded), saved);
  });

  group("ND4 the sample's bytes, decoded (spec 12a D8, S-1)", () {
    late DraftDocument sample;
    late String bytes;
    late List<Handle> sampleSlabs;
    setUp(() {
      sample = planDocument([testKit()], measurer: measurer);
      sample.commands.execute(SetComponentCommand<PageComponent>(
          sample.rootHandle,
          PageComponent(
              originX: -3100.5, originY: 820.25, scaleDenominator: 100)));
      installSystem(sample, [testKit()]);
      addObject<SlabComponent>(
          sample, SlabComponent(width: 1800, height: 900, angle: 0.4),
          at: Vector2(-2600, 1400));
      addObject<SlabComponent>(
          sample, SlabComponent(width: 1200, height: 700, angle: -1.1),
          at: Vector2(2300, 1400));
      bytes = DraftDocumentCodec.encodeToString(sample);
      sampleSlabs = catalog.objectsOf<SlabComponent>(sample);
      // The sample's page is off the world origin: not the new document's
      // page.
      expect(pageOf(sample), isNotNull);
      expect(
          pageOf(sample), isNot(PageComponent(originX: -7425, originY: -5250)));
      expect(sampleSlabs, hasLength(2));
    });

    test("with the page's registration alone: no live slab", () {
      final loaded = DraftDocumentCodec.decodeString(bytes,
          measurer: measurer, registerComponents: PageComponent.register);
      expect(pageOf(loaded), pageOf(sample));
      expect(catalog.objectsOf<SlabComponent>(loaded), isEmpty);
      expect(loaded.components.unknownOf(sampleSlabs.first), isNotEmpty);
    });

    test("with the catalog's registration alone: no live page", () {
      final loaded = DraftDocumentCodec.decodeString(bytes,
          measurer: measurer, registerComponents: catalog.registerComponents);
      expect(catalog.objectsOf<SlabComponent>(loaded), sampleSlabs);
      expect(loaded.components.isRegistered<PageComponent>(), isFalse);
      expect(pageOf(loaded), isNull);
      expect(loaded.components.unknownOf(loaded.rootHandle), isNotEmpty);
    });
  });
}
