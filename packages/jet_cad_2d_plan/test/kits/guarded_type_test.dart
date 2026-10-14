// Spec P4 "The failure boundary": every ParametricType hook is called
// through a guarding adapter that rethrows what the hook throws as
// KitHookFailure(kitId, typeId, hook, error); the engine rolls the edit
// back and rethrows it unchanged. One test per hook, each on the engine
// alone (a ParametricSystem over the box and ring kits' guarded types), so
// the attribution is the adapter's. The named mutant of each is that
// hook's guard removed (the delegate called bare): the raw HookBoom then
// escapes instead.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/src/kits/guard.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_kit.dart';

/// A document with a page and a system over the guarded square and disc.
({DraftDocument doc, ParametricSystem system, ParametricCatalog catalog})
    harness(Switches sw) {
  final d = DraftDocument.empty();
  PageComponent.register(d.components);
  d.commands.execute(SetComponentCommand<PageComponent>(
      d.rootHandle, PageComponent(scaleDenominator: 50)));
  final catalog = ParametricCatalog()
    ..register<SquareParams>(SquareParams.id, SquareParams.fromJson,
        GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw)))
    ..register<DiscParams>(DiscParams.id, DiscParams.fromJson,
        GuardedType<DiscParams>('ring', DiscParams.id, DiscType(sw)));
  final system = ParametricSystem(d, catalog)..install();
  return (doc: d, system: system, catalog: catalog);
}

Matcher failed(String kitId, String typeId, String hook) =>
    isA<KitHookFailure>()
        .having((f) => f.kitId, 'kitId', kitId)
        .having((f) => f.typeId, 'typeId', typeId)
        .having((f) => f.hook, 'hook', hook)
        .having((f) => f.error, 'error',
            isA<HookBoom>().having((b) => b.hook, 'hook', hook));

/// Runs [edit] on [d]: it must throw [matcher], leave the document as it
/// was and record nothing.
void expectRefused(DraftDocument d, void Function() edit, Matcher matcher) {
  final before = canon(d);
  final depth = d.commands.undoDepth;
  final state = d.commands.stateId;
  expect(edit, throwsA(matcher));
  expect(canon(d), before, reason: 'rolled back');
  expect(d.commands.undoDepth, depth);
  expect(d.commands.stateId, state);
}

/// A root-level line's add command, its handle already taken.
DraftCommand lineCommand(DraftDocument d) => addDrafted(d, EntityKind.line,
    linePayload(Vector2(-500.5, 900.25), Vector2(300.75, 1200.5)),
    layer: ReservedHandles.layerZero);

DraftCommand resize(Handle h, SquareParams p, double side) =>
    SetComponentCommand<SquareParams>(h, p.copyWith(side: side));

void main() {
  const poisoned = SquareParams(side: 1200, poisoned: true);

  test('F-G1 reach', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    sw.failing.add('reach');
    // M-F-G1: GuardedType.reach → `inner.reach(params, toWorld)` bare.
    // The line's handle is taken from the seed before the snapshot: the
    // refusal must leave the document as it was then.
    final line = lineCommand(h.doc);
    expectRefused(h.doc, () => h.doc.commands.execute(line),
        failed('box', SquareParams.id, 'reach'));
  });

  test('F-G2 references', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    sw.failing.add('references');
    // M-F-G2: GuardedType.references bare.
    final line = lineCommand(h.doc);
    expectRefused(h.doc, () => h.doc.commands.execute(line),
        failed('box', SquareParams.id, 'references'));
  });

  test('F-G3 generate', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    sw.failing.add('generate');
    // M-F-G3: GuardedType.generate bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, poisoned, 900)),
        failed('box', SquareParams.id, 'generate'));
  });

  test('F-G4 dissolves', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    sw.failing.add('dissolves');
    // M-F-G4: GuardedType.dissolves bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, poisoned, 900)),
        failed('box', SquareParams.id, 'dissolves'));
  });

  test('F-G5 diagnose', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    sw.failing.add('diagnose');
    // M-F-G5: GuardedType.diagnose bare.
    expect(() => h.system.diagnostics(),
        throwsA(failed('box', SquareParams.id, 'diagnose')));
  });

  test('F-G6 editCapability', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, const SquareParams(side: 1200));
    sw.failing.add('editCapability');
    // M-F-G6: GuardedType.editCapability bare.
    expectRefused(
        h.doc,
        () => h.doc.commands
            .execute(resize(s, const SquareParams(side: 1200), 900)),
        failed('box', SquareParams.id, 'editCapability'));
  });

  test('F-G7 referencePolicy', () {
    final sw = Switches();
    final h = harness(sw);
    final disc =
        addObject(h.doc, nearSquare(2000, 0, 0), const DiscParams(radius: 400));
    final p = SquareParams(side: 1200, partner: disc);
    final s = addObject(h.doc, atSquare, p);
    sw.failing.add('referencePolicy');
    // M-F-G7: GuardedType.referencePolicy bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, p, 900)),
        failed('box', SquareParams.id, 'referencePolicy'));
  });

  test('F-G8 pageKey', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, const SquareParams(side: 1200));
    final root = h.doc.rootHandle;
    final page = h.doc.components.get<PageComponent>(root)!;
    sw.failing.add('pageKey');
    // M-F-G8: GuardedType.pageKey bare.
    expectRefused(
        h.doc,
        () => h.doc.commands.execute(SetComponentCommand<PageComponent>(
            root, page.copyWith(scaleDenominator: 75))),
        failed('box', SquareParams.id, 'pageKey'));
  });

  test(
      'F-G9 placeBox, asked by another kit\'s generate: the failure names '
      'the square, not the disc that asked', () {
    final sw = Switches();
    final h = harness(sw);
    addObject(h.doc, atSquare, poisoned);
    final disc = addObject(
        h.doc, nearSquare(300, 200, 0), const DiscParams(radius: 700));
    sw.failing.add('placeBox');
    // M-F-G9a: GuardedType.placeBox bare. M-F-G9b: the
    // `on KitHookFailure { rethrow; }` clause removed from
    // GuardedType.generate: the disc's guard rewraps the square's failure
    // as ring.disc's `generate`.
    expectRefused(
        h.doc,
        () => h.doc.commands.execute(SetComponentCommand<DiscParams>(
            disc, const DiscParams(radius: 850))),
        failed('box', SquareParams.id, 'placeBox'));
  });

  test('F-G10 placeInput', () {
    final sw = Switches();
    final h = harness(sw);
    final s = addObject(h.doc, atSquare, poisoned);
    addObject(h.doc, nearSquare(300, 200, 0), const DiscParams(radius: 700));
    sw.failing.add('placeInput');
    // M-F-G10: GuardedType.placeInput bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, poisoned, 900)),
        failed('box', SquareParams.id, 'placeInput'));
  });

  test('F-G11 readBox', () {
    final sw = Switches();
    final h = harness(sw);
    const p = SquareParams(side: 1200);
    final s = addObject(h.doc, atSquare, p);
    addObject(h.doc, nearSquare(300, 200, 0),
        const DiscParams(radius: 700, poisoned: true));
    sw.failing.add('readBox');
    // M-F-G11: GuardedType.readBox bare.
    expectRefused(h.doc, () => h.doc.commands.execute(resize(s, p, 900)),
        failed('ring', DiscParams.id, 'readBox'));
  });

  test('F-G12 contributesPlace, read by register', () {
    final sw = Switches()..failing.add('contributesPlace');
    // M-F-G12: GuardedType.contributesPlace bare.
    expect(
        () => ParametricCatalog().register<SquareParams>(
            SquareParams.id,
            SquareParams.fromJson,
            GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw))),
        throwsA(failed('box', SquareParams.id, 'contributesPlace')));
  });

  test('F-G13 readsPlaces, read by register', () {
    final sw = Switches()..failing.add('readsPlaces');
    // M-F-G13: GuardedType.readsPlaces bare.
    expect(
        () => ParametricCatalog().register<SquareParams>(
            SquareParams.id,
            SquareParams.fromJson,
            GuardedType<SquareParams>('box', SquareParams.id, SquareType(sw))),
        throwsA(failed('box', SquareParams.id, 'readsPlaces')));
  });

  test(
      'F-G14 the plan\'s TypeGuard through PlanType.registerInto keeps T and '
      'the kit\'s id; a healthy edit is unchanged by the guard', () {
    final sw = Switches();
    final d = DraftDocument.empty();
    final catalog = ParametricCatalog();
    boxKit(sw).types.single.registerInto(catalog, guard: const PlanTypeGuard());
    ParametricSystem(d, catalog).install();
    final s = addObject(d, atSquare, poisoned);
    expect(catalog.names<SquareParams>(d, s), isTrue,
        reason: 'registered as SquareParams, not Component');
    expect(kids(d, s), hasLength(4));
    sw.failing.add('reach');
    // M-F-G14: PlanTypeGuard.wrap returning `type` unwrapped.
    expect(() => addLine(d, Vector2(-500.5, 900.25), Vector2(300.75, 1200.5)),
        throwsA(failed('box', SquareParams.id, 'reach')));
  });
}
