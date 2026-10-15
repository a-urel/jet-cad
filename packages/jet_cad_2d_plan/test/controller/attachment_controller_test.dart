// Spec P1 "Lifetimes", P3 "Attachment", P4 diagnostics (Task 14), through
// the controller: the providers run once per document and go with it; a
// throwing factory or provider is a diagnostic; an attachTo kind no
// provider offers is a diagnostic; plan.symbol is armed by the gallery's
// symbol and attaches through a kit's provider; plan.select's move
// resolver asks the same registry.
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show KeyDownEvent, LogicalKeyboardKey, PhysicalKeyboardKey;
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/tools/plan_symbol_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/attach_fixtures.dart';
import '../support/symbol_fixtures.dart';
import '../support/tool_events.dart';

Uint8List shelfBytes() => encodeLibrary(Catalog(kit: 'demo', symbols: [
      box('demo.shelf.wall', 'Wall shelf', 'Storage', ['shelf'],
          attachTo: ['test-edge'], base: (950, 410)),
      box('demo.lamp.corner', 'Corner lamp', 'Lighting', ['lamp'],
          attachTo: ['room-corner'], base: (402.75, 233.5)),
    ]));

List<(String, String?, KitDiagnosticCode)> problemsOf(PlanController c) => [
      for (final d in c.diagnostics.value) (d.kitId, d.subject, d.code),
    ];

KeyDownEvent keyDown(
        LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
        physicalKey: physical, logicalKey: logical, timeStamp: Duration.zero);

/// The sign of [t]'s linear part's determinant: negative when mirrored.
double det(Transform2 t) => t.a * t.d - t.b * t.c;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'AT-14 the providers run once per document: a new plan makes new '
      'ones, disposes the old, and the services see the current registry',
      () async {
    final made = <DisposableProvider>[];
    PlanServices? seen;
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', attachments: [
        (services) {
          seen = services;
          final p = DisposableProvider('test-edge', (_) => null);
          made.add(p);
          return p;
        },
      ]),
    ]);
    addTearDown(c.dispose);
    expect(made, hasLength(1));
    expect(seen!.attachments.kinds, {'test-edge'});
    c.newPlan();
    // M-AT14: the per-document registry not disposed on a swap.
    expect(made, hasLength(2));
    expect(made.first.disposals, 1);
    expect(made.last.disposals, 0);
    expect(seen!.attachments.kinds, {'test-edge'});
  });

  test('AT-15 a throwing factory is a hookFailed; the plan still opens',
      () async {
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', attachments: [
        (_) => throw StateError('no faces'),
      ]),
    ]);
    addTearDown(c.dispose);
    expect(problemsOf(c),
        contains(('demo', 'attachments', KitDiagnosticCode.hookFailed)));
  });

  test(
      'AT-16 an attachTo kind no provider offers is one '
      'attachmentKindUnoffered per kit and kind; an offered one is none',
      () async {
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', symbols: [
        SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
      ], attachments: [
        (_) => RecordingProvider('test-edge', (_) => null)
      ]),
    ]);
    addTearDown(c.dispose);
    await settle();
    // M-AT16: `_reportUnofferedKinds` not called after the load.
    expect(
        problemsOf(c)
            .where((p) => p.$3 == KitDiagnosticCode.attachmentKindUnoffered),
        [('demo', 'room-corner', KitDiagnosticCode.attachmentKindUnoffered)]);
    c.newPlan();
    expect(
        problemsOf(c)
            .where((p) => p.$3 == KitDiagnosticCode.attachmentKindUnoffered),
        hasLength(1),
        reason: 'once per kit, subject and code');
  });

  test(
      "PN-open (D-45) a new plan's providers are checked against the loaded "
      'symbols when it opens: a kind they no longer offer is reported',
      () async {
    var documents = 0;
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', symbols: [
        SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
      ], attachments: [
        (_) => RecordingProvider(
            ++documents == 1 ? 'test-edge' : 'room-corner', (_) => null),
      ]),
    ]);
    addTearDown(c.dispose);
    await settle();
    List<(String, String?, KitDiagnosticCode)> unoffered() => [
          for (final p in problemsOf(c))
            if (p.$3 == KitDiagnosticCode.attachmentKindUnoffered) p,
        ];
    expect(unoffered(),
        [('demo', 'room-corner', KitDiagnosticCode.attachmentKindUnoffered)],
        reason: 'premise: the first document offers test-edge');
    c.newPlan();
    expect(documents, 2, reason: 'premise: the providers ran again');
    // M-PN-open: `_open` without its `_reportUnofferedKinds()`.
    expect(
        unoffered(),
        contains(
            ('demo', 'test-edge', KitDiagnosticCode.attachmentKindUnoffered)));
  });

  test(
      'AT-17 plan.symbol: refused with nothing armed (T4-b); armed, it '
      'places through the kit\'s provider; under rotate: false R is not the '
      'tool\'s', () async {
    final turned = Transform2.translation(4600.5, -1200.25)
        .multiply(Transform2.rotation(0.7));
    final edge = RecordingProvider(
        'test-edge', (_) => attachment(turned, Vector2(4610.5, -1190.25), 'e'));
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', symbols: [
        SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
      ], attachments: [
        (_) => edge
      ]),
    ]);
    addTearDown(c.dispose);
    useTestCamera(c);
    await settle();
    // M-AT17a: the "nothing armed" refusal dropped.
    expect(c.selectTool('plan.symbol'), isFalse);
    expect(c.activeTool.value, 'plan.select');
    final shelf = c.symbolById('demo.shelf.wall@1')!;
    expect(c.armSymbol(shelf), isTrue);
    expect(c.activeTool.value, 'plan.symbol');
    tapAt(c, Vector2(4500.25, -1300.75));
    final placed = c.document.tree.nodes.whereType<InstanceNode>().single;
    expect([placed.transform.a, placed.transform.e], [turned.a, turned.e]);
    expect(edge.queries.last.exclude, isEmpty);

    c.permissions = PlanPermissions.full.copyWith(rotate: false);
    expect(c.activeTool.value, 'plan.symbol', reason: 'still allowed');
    final r = c.toolController.active.onKey(
        keyDown(LogicalKeyboardKey.keyR, PhysicalKeyboardKey.keyR),
        c.toolController.context);
    // M-AT17b: canRotate wired as `() => true`.
    expect(r, KeyEventResult.ignored);
    c.permissions = PlanPermissions.full.copyWith(tools: {'plan.select'});
    expect(c.activeTool.value, 'plan.select');
    expect(c.armSymbol(shelf), isFalse, reason: 'plan.symbol not permitted');
  });

  test(
      'AT-18 plan.select\'s body drag of an attaching symbol asks the same '
      'registry, the instance excluded, and commits its answer', () async {
    Attachment? answer;
    final edge = RecordingProvider('test-edge', (_) => answer);
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', symbols: [
        SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
      ], attachments: [
        (_) => edge
      ]),
    ]);
    addTearDown(c.dispose);
    useTestCamera(c);
    await settle();
    c.armSymbol(c.symbolById('demo.shelf.wall@1')!);
    tapAt(c, Vector2(4500.25, -1300.75));
    final node = c.document.tree.nodes.whereType<InstanceNode>().single;
    c.selectTool('plan.select');
    c.selection.replace([SelectionKey.root(node.handle)]);
    final target = Transform2.translation(5200.5, -900.25)
        .multiply(Transform2.rotation(-0.35));
    answer = attachment(target, Vector2(5210.5, -890.25), 'f');
    edge.queries.clear();
    final inside =
        node.transform.transformPoint(Vector2(950, 585)); // on its middle line
    dragFrom(c, inside, inside + Vector2(600, 300));
    // M-AT18: buildGenericTools given no move resolver.
    expect(edge.queries, isNotEmpty);
    expect(edge.queries.last.exclude, {node.handle});
    final moved = c.document.tree[node.handle]! as InstanceNode;
    expect([moved.transform.a, moved.transform.b, moved.transform.e],
        [target.a, target.b, target.e]);
  });

  test(
      'AT-19 plan.symbol\'s M respects PlanPermissions.mirror: refused, M '
      'is not the tool\'s, a stored mirror is dropped from the ghost at '
      'once and from the placement', () async {
    final c = PlanController(kits: [
      PlanKit(id: 'demo', version: '1.0.0', symbols: [
        SymbolLibrarySource(label: 'demo', read: () async => shelfBytes()),
      ]),
    ]);
    addTearDown(c.dispose);
    useTestCamera(c);
    await settle();
    expect(c.armSymbol(c.symbolById('demo.shelf.wall@1')!), isTrue);
    final tool = c.toolFor('plan.symbol')! as PlanSymbolTool;
    final at = Vector2(4500.25, -1300.75);
    final tools = c.toolController;
    tools.active.onPointerMove(eventAt(c, at), tools.context);
    final m = keyDown(LogicalKeyboardKey.keyM, PhysicalKeyboardKey.keyM);
    expect(tools.active.onKey(m, tools.context), KeyEventResult.handled);
    expect(det(tool.ghostPlacement!), lessThan(0), reason: 'premise: mirrored');

    c.permissions = PlanPermissions.full.copyWith(mirror: false);
    expect(c.activeTool.value, 'plan.symbol', reason: 'still allowed');
    // M-AT19b: the setter's gatesChanged not called on a mirror change.
    expect(det(tool.ghostPlacement!), greaterThan(0),
        reason: 'the ghost drops the stored mirror at once');
    // M-AT19a: canMirror wired as `() => true`.
    expect(tools.active.onKey(m, tools.context), KeyEventResult.ignored);
    expect(tool.mirrored, isTrue, reason: 'the stored mirror is kept');
    tapAt(c, at);
    final placed = c.document.tree.nodes.whereType<InstanceNode>().single;
    expect(det(placed.transform), greaterThan(0), reason: 'placed unmirrored');

    c.permissions = PlanPermissions.full;
    expect(det(tool.ghostPlacement!), lessThan(0),
        reason: 'the stored mirror returns with the flag');
  });
}
