// Mounting the service view for the ported and new tests: a controller
// over a fixture plan with the test kit, switched to service, the view at
// 1440 x 900 (today's surface), the first fit let land, then the test's
// camera put in place, as today's mounts did (bars_test.dart:56-74,
// view_events_test.dart:35-60).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/view/plan_service_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'service_fixture.dart' show serviceFixture;
import 'service_fixtures.dart';
import 'test_kit.dart' show unitKit;

Finder byKey(String k) => find.byKey(Key(k));

/// A controller over [json] (the embedding plan by default) with [kits]
/// (the fixture kit by default: the fixture plans are plan files over
/// `fxKit()`), disposed at tear-down.
PlanController serviceController({String? json, List<PlanKit>? kits}) {
  final c = PlanController(
      kits: kits ?? [fxKit()], json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  return c;
}

/// A controller over Task 5's service fixture (`serviceFixture().json`: a
/// turned, mirrored table labelled 12; row A, six seats, turned; row B,
/// five seats, curved), with the test kit's units.
PlanController rowsController() =>
    serviceController(json: serviceFixture().json, kits: [unitKit()]);

/// [view] mounted for [c] in service at 1440 x 900; then [camera]
/// ([embeddingCamera] by default).
Future<void> pumpService(
    WidgetTester tester, PlanController c, PlanServiceView view,
    {ViewportTransform? camera}) async {
  c.setMode(PlanMode.service);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: view)));
  await tester.pump();
  await tester.pump();
  c.camera.value = camera ?? embeddingCamera();
  await tester.pump();
}

/// World [w] on the screen: the canvas's top left plus the camera's image.
Offset globalOfWorld(WidgetTester tester, PlanController c, Vector2 w) {
  final s = c.camera.value.worldToScreen(w);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// The world centre of the unit labelled [label] in the active document,
/// from its detail (the box's centre, Task 9).
Vector2 unitCentre(PlanController c, String label) {
  final d = c.unitDetails.firstWhere((d) => d.unit.label == label);
  return Vector2(d.center!.dx, d.center!.dy);
}
