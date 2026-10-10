// Slice 4 final review F-1, F-2 and F-3: the chrome a host changes at run
// time, through `FloorPlanView` on the editor fixture under
// `editorCamera()`.
//
// - F-1: a capabilities change that adds or removes the side columns on
//   both sides at once keeps the canvas's element, so the camera (the
//   user's zoom and pan, a host's `centerOn`) is kept and no first fit
//   runs again. Mutant: the canvas `Expanded` unkeyed.
// - F-2: with a bar hidden, in both modes, a host that swaps the view's
//   controller and disposes the old one in the same step meets no
//   assertion: no lazily made relay or flag is first made in `dispose`.
//   Mutants: the shell's status relay and the service view's page flag
//   made at their first use again, with `dispose` making them.
// - F-3: chrome changing in the mode shown (the left column, the editor's
//   bar, the rulers, the service bar at a 60 px theme height) keeps every
//   world point at its global position from the
//   first frame: the camera's forward transform, the painted pixels and a
//   host overlay; `canvasRect` and `worldToGlobal` agree after the frame,
//   and a host listening to the camera outside the view hears it then.
//   The theme's bar height is not chrome kept in place: changed, the
//   plan moves with the canvas (Slice 3's S-10, `theme_service_test`).
//   Mutant: no pan.
//
// Screen points come from the camera's forward transform from the canvas's
// origin, never from the code under test.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, kRulerThickness;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_fixture.dart';
import 'editor_tools_test.dart' as t;

typedef Caps = FloorPlanEditorCapabilities;

/// No side column: no tool but Select, no Symbols tab, no panel.
final Caps kNoColumns = Caps.readOnly
    .copyWith(selectionPanel: false, layerPanel: false, pagePanel: false);

/// The left column alone.
final Caps kLeftOnly = Caps.full
    .copyWith(selectionPanel: false, layerPanel: false, pagePanel: false);

/// The view's chrome as a host rebuilds it.
final class ChromeHost {
  ChromeHost(FloorPlanController c, Caps caps, FloorPlanServiceBar service,
      FloorPlanEditorBar editor, FloorPlanTheme? theme)
      : controller = ValueNotifier(c),
        caps = ValueNotifier(caps),
        service = ValueNotifier(service),
        editor = ValueNotifier(editor),
        theme = ValueNotifier(theme);

  final ValueNotifier<FloorPlanController> controller;
  final ValueNotifier<Caps> caps;
  final ValueNotifier<FloorPlanServiceBar> service;
  final ValueNotifier<FloorPlanEditorBar> editor;
  final ValueNotifier<FloorPlanTheme?> theme;

  /// The camera values a host widget outside the view was built with.
  final List<FloorPlanCamera> heard = [];

  FloorPlanController get c => controller.value;

  void dispose() {
    controller.dispose();
    caps.dispose();
    service.dispose();
    editor.dispose();
    theme.dispose();
  }
}

final GlobalKey shotKey = GlobalKey();

/// The editor fixture in [mode] under a view whose chrome a [ChromeHost]
/// rebuilds, with a host overlay on every table in both modes and a host
/// widget beside the view that rebuilds on the camera.
Future<ChromeHost> mountChrome(WidgetTester tester,
    {FloorPlanMode mode = FloorPlanMode.design,
    Caps caps = Caps.full,
    FloorPlanServiceBar service = const FloorPlanServiceBar(),
    FloorPlanEditorBar editor = const FloorPlanEditorBar(),
    FloorPlanTheme? theme,
    FloorPlanController? controller}) async {
  final c = controller ?? FloorPlanController(json: editorPlanJson());
  if (controller == null) addTearDown(c.dispose);
  c.setMode(mode);
  final h = ChromeHost(c, caps, service, editor, theme);
  addTearDown(h.dispose);
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ListenableBuilder(
              listenable: Listenable.merge(
                  [h.controller, h.caps, h.service, h.editor, h.theme]),
              builder: (_, __) => Column(children: [
                    // A host widget outside the view that rebuilds on the
                    // camera: notified while the view builds, it would
                    // assert.
                    ValueListenableBuilder<FloorPlanCamera>(
                        valueListenable: h.c.camera,
                        builder: (_, camera, __) {
                          h.heard.add(camera);
                          return const SizedBox(height: 10);
                        }),
                    Expanded(
                        child: RepaintBoundary(
                            key: shotKey,
                            child: FloorPlanView(
                                controller: h.c,
                                editorCapabilities: h.caps.value,
                                serviceBar: h.service.value,
                                editorBar: h.editor.value,
                                theme: h.theme.value,
                                tableOverlayModes: const {
                                  FloorPlanMode.design,
                                  FloorPlanMode.selection
                                },
                                tableOverlayBuilder: (_, table) => SizedBox(
                                    key: Key(
                                        'overlay-${table.detail.table.number}'),
                                    width: 12,
                                    height: 12)))),
                  ])))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = editorCamera();
  await tester.pump();
  return h;
}

/// The shown canvas's top left, global.
Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// World [w] on the screen, by the camera's forward transform from the
/// shown canvas's origin.
Offset globalOf(WidgetTester tester, FloorPlanController c, Vector2 w) {
  final p = canvasOf(c.cameraController.value, w.x, w.y);
  return canvasOrigin(tester) + Offset(p.x, p.y);
}

void expectAt(Offset got, Offset want, String reason) {
  expect(got.dx, closeTo(want.dx, 1e-6), reason: '$reason (x)');
  expect(got.dy, closeTo(want.dy, 1e-6), reason: '$reason (y)');
}

/// The view's pixels, and the shot's width and global origin.
Future<(ByteData, int, Offset)> shoot(WidgetTester tester) async {
  final boundary =
      shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final origin = boundary.localToGlobal(Offset.zero);
  final (bytes, width) = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (raw!, width);
  }))!;
  return (bytes, width, origin);
}

/// The pixels of the global square of side 2 × [r] about [at].
List<int> pixelsAt((ByteData, int, Offset) shot, Offset at, int r) {
  final (bytes, width, origin) = shot;
  final x0 = (at.dx - origin.dx).round(), y0 = (at.dy - origin.dy).round();
  return [
    for (var y = y0 - r; y < y0 + r; y++)
      for (var x = x0 - r; x < x0 + r; x++)
        bytes.getUint32((y * width + x) * 4),
  ];
}

/// The largest difference of one channel between two runs of pixels. A
/// layer drawn at another offset in its parent may round an edge's
/// coverage one level apart; a plan moved by even a pixel differs by far
/// more.
int largestDifference(List<int> a, List<int> b) {
  var most = 0;
  for (var i = 0; i < a.length; i++) {
    for (var shift = 0; shift < 32; shift += 8) {
      final d = ((a[i] >> shift) & 0xff) - ((b[i] >> shift) & 0xff);
      if (d.abs() > most) most = d.abs();
    }
  }
  return most;
}

/// Table [n]'s overlay centre, global.
Offset overlayAt(WidgetTester tester, String n) =>
    tester.getCenter(find.byKey(Key('overlay-$n')));

void main() {
  group('F-1 the canvas kept across a change of both side columns', () {
    for (final (name, from, to) in [
      ('both columns -> none', Caps.full, kNoColumns),
      ('none -> both columns', kNoColumns, Caps.full),
      ('left only -> right only', kLeftOnly, Caps.readOnly),
      ('right only -> left only', Caps.readOnly, kLeftOnly),
    ]) {
      testWidgets(
          '$name: the same PlannerView state, the scale kept, a table '
          'where it was (the user\'s pan and a host\'s centerOn), no first '
          'fit', (tester) async {
        final h = await mountChrome(tester, caps: from);
        final c = h.c;
        final w = t.centreOf(c, '1');
        // A host's centerOn, then the user's pan.
        c.centerOn(Offset(w.x, w.y), scale: 0.5);
        await tester.pump();
        await tester.pump();
        c.cameraController.panBy(const Offset(-37, 23));
        await tester.pump();
        final state = tester.state(find.byType(PlannerView));
        final scale = c.cameraController.value.scale;
        final at = globalOf(tester, c, w);
        h.caps.value = to;
        await tester.pump();
        await tester.pump();
        expect(identical(tester.state(find.byType(PlannerView)), state), isTrue,
            reason: 'the canvas kept its element');
        expect(c.cameraController.value.scale, scale, reason: 'no fit');
        expectAt(globalOf(tester, c, w), at, 'the table kept its place');
        // The page fit is due no more: a later frame changes nothing.
        final m = c.cameraController.value;
        await tester.pump(const Duration(milliseconds: 100));
        expect(identical(c.cameraController.value, m), isTrue);
      });
    }
  });

  group('F-2 a controller swapped and disposed in one step, a bar hidden', () {
    for (final mode in FloorPlanMode.values) {
      for (final (name, service, editor, caps) in [
        (
          'the service bar hidden',
          const FloorPlanServiceBar(visible: false),
          const FloorPlanEditorBar(),
          Caps.full
        ),
        (
          'the editor bar hidden',
          const FloorPlanServiceBar(),
          const FloorPlanEditorBar(visible: false),
          Caps.full
        ),
        (
          'both bars hidden, no column, read only',
          const FloorPlanServiceBar(visible: false),
          const FloorPlanEditorBar(visible: false),
          kNoColumns
        ),
      ]) {
        testWidgets('${mode.name}, $name: no assertion', (tester) async {
          // Disposed by the test, as the host does.
          final a = FloorPlanController(json: editorPlanJson());
          final h = await mountChrome(tester,
              mode: mode,
              service: service,
              editor: editor,
              caps: caps,
              controller: a);
          final b = FloorPlanController(json: editorPlanJson())..setMode(mode);
          addTearDown(b.dispose);
          h.controller.value = b;
          a.dispose();
          await tester.pump();
          expect(tester.takeException(), isNull);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(InteractionLayer), findsOneWidget,
              reason: 'premise: the new plan shown');
        });
      }
    }
  });

  group('F-3 chrome changed in the mode shown keeps the plan in place', () {
    /// Changes the chrome by [change] and checks, at the first frame, that
    /// table 1 is where it was by the camera, by its overlay and in the
    /// pixels around it; after the frame, that `canvasRect` and
    /// `worldToGlobal` agree; at the next, that the host's widget beside
    /// the view was built with the camera. Returns the canvas's move.
    Future<Offset> expectKept(WidgetTester tester, ChromeHost h,
        void Function() change, String reason) async {
      final c = h.c;
      final w = t.centreOf(c, '1');
      final at = globalOf(tester, c, w);
      final overlay = overlayAt(tester, '1');
      final canvas = canvasOrigin(tester);
      final before = await shoot(tester);
      change();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: reason);
      final moved = canvasOrigin(tester) - canvas;
      expect(moved, isNot(Offset.zero), reason: '$reason: premise');
      expectAt(globalOf(tester, c, w), at, '$reason: frame 1, the camera');
      expectAt(overlayAt(tester, '1'), overlay, '$reason: frame 1, overlay');
      final after = await shoot(tester);
      expect(
          largestDifference(pixelsAt(after, at, 30), pixelsAt(before, at, 30)),
          lessThanOrEqualTo(2),
          reason: '$reason: frame 1, the pixels');
      // After the frame: the rect, worldToGlobal and the host's listener.
      expect(c.canvasRect.value!.topLeft, canvasOrigin(tester),
          reason: '$reason: canvasRect');
      expectAt(
          c.worldToGlobal(Offset(w.x, w.y))!, at, '$reason: worldToGlobal');
      await tester.pump();
      expect(identical(h.heard.last, c.camera.value), isTrue,
          reason: '$reason: the host heard the pan');
      expectAt(globalOf(tester, c, w), at, '$reason: settled');
      expectAt(overlayAt(tester, '1'), overlay, '$reason: overlay settled');
      return moved;
    }

    testWidgets(
        'design: the left column hidden (full -> readOnly) and shown again',
        (tester) async {
      final h = await mountChrome(tester);
      expect(
          await expectKept(
              tester, h, () => h.caps.value = Caps.readOnly, 'hidden'),
          const Offset(-240, 0));
      expect(
          await expectKept(tester, h, () => h.caps.value = Caps.full, 'shown'),
          const Offset(240, 0));
    });

    testWidgets(
        'design: the editor bar hidden and shown, then the rulers off and '
        'on', (tester) async {
      final h = await mountChrome(tester);
      expect(
          await expectKept(
              tester,
              h,
              () => h.editor.value = const FloorPlanEditorBar(visible: false),
              'bar hidden'),
          const Offset(0, -44));
      expect(
          await expectKept(tester, h,
              () => h.editor.value = const FloorPlanEditorBar(), 'bar shown'),
          const Offset(0, 44));
      expect(
          await expectKept(tester, h,
              () => h.caps.value = Caps.full.copyWith(rulers: false), 'off'),
          const Offset(-kRulerThickness, -kRulerThickness));
      expect(await expectKept(tester, h, () => h.caps.value = Caps.full, 'on'),
          const Offset(kRulerThickness, kRulerThickness));
    });

    testWidgets(
        'selection: a 60 px service bar hidden and shown; a change of the '
        "theme's bar height, 60 -> 44, still moves the plan with the canvas "
        "(Slice 3's S-10)", (tester) async {
      final h = await mountChrome(tester,
          mode: FloorPlanMode.selection,
          theme: const FloorPlanTheme(serviceBarHeight: 60));
      expect(
          await expectKept(
              tester,
              h,
              () => h.service.value = const FloorPlanServiceBar(visible: false),
              'hidden'),
          const Offset(0, -60));
      expect(
          await expectKept(tester, h,
              () => h.service.value = const FloorPlanServiceBar(), 'shown'),
          const Offset(0, 60));
      final c = h.c;
      final w = t.centreOf(c, '1');
      final at = globalOf(tester, c, w);
      final m = c.cameraController.value;
      h.theme.value = const FloorPlanTheme(serviceBarHeight: 44);
      await tester.pump();
      await tester.pump();
      expect(identical(c.cameraController.value, m), isTrue,
          reason: 'no pan for the theme');
      expectAt(globalOf(tester, c, w), at - const Offset(0, 16),
          'the plan moved with the canvas');
      // Hidden at 44 now: the pan is the bar's height today.
      expect(
          await expectKept(
              tester,
              h,
              () => h.service.value = const FloorPlanServiceBar(visible: false),
              'hidden at 44'),
          const Offset(0, -44));
    });

    testWidgets(
        'a mode switch after a change in place still keeps the plan: '
        'design, the left column hidden, then selection and back',
        (tester) async {
      final h = await mountChrome(tester);
      await expectKept(tester, h, () => h.caps.value = Caps.readOnly, 'hidden');
      final c = h.c;
      final w = t.centreOf(c, '1');
      final at = globalOf(tester, c, w);
      for (final mode in [FloorPlanMode.selection, FloorPlanMode.design]) {
        c.setMode(mode);
        await tester.pump();
        expectAt(globalOf(tester, c, w), at, '$mode: frame 1');
        await tester.pump();
        expectAt(globalOf(tester, c, w), at, '$mode: settled');
      }
    });

    testWidgets(
        'a change right after a mode switch the host made without '
        'rebuilding its view: the selection mode, its bar hidden',
        (tester) async {
      final h = await mountChrome(tester);
      h.c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      expect(
          await expectKept(
              tester,
              h,
              () => h.service.value = const FloorPlanServiceBar(visible: false),
              'hidden'),
          const Offset(0, -44));
    });

    for (final mode in FloorPlanMode.values) {
      testWidgets(
          '${mode.name}: a host rebuild with the default chrome moves '
          'nothing (the camera the identical value)', (tester) async {
        final h = await mountChrome(tester, mode: mode);
        final m = h.c.cameraController.value;
        h.caps.value = Caps.full.copyWith();
        h.service.value =
            const FloorPlanServiceBar(actions: FloorPlanServiceAction.values);
        h.editor.value =
            const FloorPlanEditorBar(actions: FloorPlanEditorAction.values);
        await tester.pump();
        await tester.pump();
        expect(identical(h.c.cameraController.value, m), isTrue);
      });
    }

    testWidgets(
        'a controller swapped back with other chrome in one step: its camera '
        "is its own, not panned by the chrome the other's plan was laid out "
        'in', (tester) async {
      final a = FloorPlanController(json: editorPlanJson());
      addTearDown(a.dispose);
      final h = await mountChrome(tester);
      final b = h.c;
      final m = b.cameraController.value.worldToScreenMatrix;
      h.controller.value = a;
      await tester.pump();
      await tester.pump();
      h.controller.value = b;
      h.caps.value = Caps.readOnly;
      await tester.pump();
      await tester.pump();
      final n = b.cameraController.value.worldToScreenMatrix;
      expect((n.a, n.e, n.f), (m.a, m.e, m.f));
    });

    testWidgets(
        "the camera's notification held for after the frame is dropped when "
        'the controller is disposed first', (tester) async {
      final c = FloorPlanController(json: editorPlanJson());
      var heard = 0;
      c.camera.addListener(() => heard++);
      final m = c.cameraController.value.worldToScreenMatrix;
      c.chromeMoved(const Offset(240, 44), Offset.zero);
      final n = c.cameraController.value.worldToScreenMatrix;
      expect((n.e - m.e, n.f - m.f), (240, 44), reason: 'panned at once');
      expect(heard, 0, reason: 'heard after the frame');
      c.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(heard, 0);
    });

    testWidgets("the camera's held notification arrives after the frame",
        (tester) async {
      final c = FloorPlanController(json: editorPlanJson());
      addTearDown(c.dispose);
      var heard = 0;
      c.camera.addListener(() => heard++);
      c.chromeMoved(const Offset(0, 60), Offset.zero);
      c.chromeMoved(const Offset(0, 0), const Offset(0, 60));
      expect(heard, 0);
      await tester.pump();
      expect(heard, 1, reason: 'one notification for the frame');
    });
  });
}
