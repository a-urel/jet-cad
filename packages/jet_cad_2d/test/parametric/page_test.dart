// The page (spec 10 D14): a parametric view reads the root's page, and a
// page change regenerates, in the same edit, every live object of each type
// whose page key changed.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

import 'support/clients.dart';
import 'support/fixture.dart';

// Four objects on A's rotated frame, off the origin, each far from the
// others: none is another's neighbour, so a seed pulls nothing else in.
const Handle hG = Handle(1000); // a Gauge
const Handle hD = Handle(2000); // a Dial
const Handle hC = Handle(3000); // a ClipRect
const Handle hG2 = Handle(4000); // a second Gauge
final Transform2 atG = onA(1200.5, -300.25, 0.4);
final Transform2 atD = onA(-2500.75, 800.5, -0.3);
final Transform2 atC = onA(4000.25, 2500.5, 0.15);
final Transform2 atG2 = onA(-1500.5, -2200.25, 1.1);
const Gauge gauge = Gauge(125.5, -40.25);
const Dial dial = Dial(-60.75, 30.5);
const ClipRect clip = ClipRect(600.5, 400.25);
const Gauge gauge2 = Gauge(-35.25, 80.75);

/// The page as the app's panel writes it: one command on the root.
DraftCommand setPage(DraftDocument doc, PageComponent? page) =>
    SetComponentCommand<PageComponent>(doc.rootHandle, page);

/// The select tool's delete cascade for one group.
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g)) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

/// The length of [group]'s one LINE, from its world coordinates.
double lineLength(DraftDocument doc, Handle group) {
  final [s] = worldSegments(doc, group);
  return math.sqrt(math.pow(s[2] - s[0], 2) + math.pow(s[3] - s[1], 2));
}

int calls(Handle h) => generateCalls[h] ?? 0;

List<Handle> drift(DraftDocument doc) => ParametricSystem(doc, catalog).drift();

/// A document with `PageComponent` registered (the app registers it before
/// anything else), the parametric system installed.
DraftDocument pageDoc() {
  final doc = paramDoc();
  PageComponent.register(doc.components);
  return doc;
}

/// Decodes with the page and the catalog's factories, installs a system.
DraftDocument reloadWithPage(String s) {
  final doc = DraftDocumentCodec.decode(jsonDecode(s) as Map<String, Object?>,
      registerComponents: (r) {
    PageComponent.register(r);
    catalog.registerComponents(r);
  });
  ParametricSystem(doc, catalog).install();
  return doc;
}

/// Every command inside [c], compounds and replays opened.
Iterable<DraftCommand> flatten(DraftCommand c) sync* {
  yield c;
  if (c is CompoundCommand) {
    for (final k in c.children) {
      yield* flatten(k);
    }
  } else if (c is ParametricReplay) {
    yield* flatten(c.replay);
  }
}

/// The capability of each `CommandApplied` that [run] causes.
Future<List<Capability>> appliedCapabilities(
    DraftDocument doc, void Function() run) async {
  await pumpEventQueue();
  final out = <Capability>[];
  final sub = doc.changes.listen((c) {
    if (c is CommandApplied) out.add(c.capability);
  });
  run();
  await pumpEventQueue();
  await sub.cancel();
  return out;
}

void main() {
  setUp(generateCalls.clear);

  test(
      'PG1 a page change seeds exactly the types whose key changed, in '
      'one undo step; a page-only edit regenerates; a seeded object with a '
      'dead reference does not refuse it', () async {
    // Premises on the keys: the default page is 1:50 in metres, and the
    // unit indices the Dial's lengths are written from.
    expect(PageComponent().scaleDenominator, 50);
    expect(PageComponent().displayUnit, DisplayUnit.meters);
    expect(DisplayUnit.meters.index, 2);
    expect(DisplayUnit.feetInches.index, 4);

    final doc = pageDoc();
    final m50 = PageComponent(background: 0xFFF4F1EA);
    doc.commands.execute(setPage(doc, m50));
    doc.commands.execute(create(doc, hG, atG, gauge));
    doc.commands.execute(create(doc, hD, atD, dial));
    doc.commands.execute(create(doc, hC, atC, clip));
    // Premises: nothing is anyone's neighbour; the Gauge sits off the
    // origin on a turned frame.
    final reaches = [
      const GaugeType().reach(gauge, atG),
      const DialType().reach(dial, atD),
      const RectType<ClipRect>(Capability.geometry).reach(clip, atC),
      const GaugeType().reach(gauge2, atG2),
    ];
    for (var i = 0; i < reaches.length; i++) {
      for (var j = i + 1; j < reaches.length; j++) {
        expect(reaches[i].expandedBy(100).intersects(reaches[j]), isFalse,
            reason: '$i and $j');
      }
    }
    final start = worldSegments(doc, hG).single;
    expect(math.sqrt(start[0] * start[0] + start[1] * start[1]),
        greaterThan(1000));
    expect((start[3] - start[1]).abs(), greaterThan(1),
        reason: 'the LINE is not axis-aligned in world');
    // Created at 1:50 m: 10 x 50 = 500 and 100 x (2 + 1) = 300.
    expect(lineLength(doc, hG), closeTo(500, 1e-6));
    expect(lineLength(doc, hD), closeTo(300, 1e-6));
    expect(drift(doc), isEmpty);

    // 1:50 m -> 1:100 m, the page alone: the edit touches the root, which
    // is not an object, so only the page seeds regenerate the Gauge.
    final at50 = canon(doc);
    final depth = doc.commands.undoDepth;
    final g0 = calls(hG), d0 = calls(hD), c0 = calls(hC);
    final m100 = m50.copyWith(scaleDenominator: 100);
    final caps = await appliedCapabilities(
        doc, () => doc.commands.execute(setPage(doc, m100)));
    expect(doc.components.get<PageComponent>(doc.rootHandle), m100);
    expect(lineLength(doc, hG), closeTo(1000, 1e-6), reason: '10 x 100');
    expect(calls(hG), g0 + 1);
    expect(calls(hD), d0, reason: 'the unit did not change');
    expect(calls(hC), c0, reason: 'a ClipRect reads no page');
    expect(lineLength(doc, hD), closeTo(300, 1e-6));
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect(caps, [Capability.geometry],
        reason: 'the plan changed geometry: the index must hear it');
    expect(drift(doc), isEmpty);
    final at100 = canon(doc);

    doc.commands.undo();
    expect(canon(doc), at50);
    expect(lineLength(doc, hG), closeTo(500, 1e-6));
    expect(drift(doc), isEmpty);
    doc.commands.redo();
    expect(canon(doc), at100);
    expect(lineLength(doc, hG), closeTo(1000, 1e-6));
    expect(drift(doc), isEmpty);

    // 1:100 m -> 1:100 ft-in: the Dial regenerates, 100 x (4 + 1) = 500;
    // the Gauge does not.
    final g1 = calls(hG), d1 = calls(hD), c1 = calls(hC);
    doc.commands.execute(
        setPage(doc, m100.copyWith(displayUnit: DisplayUnit.feetInches)));
    expect(calls(hD), d1 + 1);
    expect(lineLength(doc, hD), closeTo(500, 1e-6));
    expect(calls(hG), g1);
    expect(calls(hC), c1);
    expect(lineLength(doc, hG), closeTo(1000, 1e-6));
    expect(doc.commands.undoDepth, depth + 2);
    expect(drift(doc), isEmpty);

    // A page read at creation: a Gauge created on the 1:100 page draws
    // 1,000 from the start.
    doc.commands.execute(create(doc, hG2, atG2, gauge2));
    expect(lineLength(doc, hG2), closeTo(1000, 1e-6));
    expect(drift(doc), isEmpty);

    // A compound that changes the page and deletes one Gauge: the live
    // Gauge regenerates, the deleted one is not regenerated, and its
    // component is detached once (06 D8). Planned on a copy through the
    // expander, so the edit's inverse can be read.
    final copy = reloadWithPage(enc(doc));
    final m25 = copy.components
        .get<PageComponent>(copy.rootHandle)!
        .copyWith(scaleDenominator: 25);
    generateCalls.clear();
    final edit = copy.commands.expander!(CompoundCommand(
        [setPage(copy, m25), deleteObject(copy, hG2)],
        label: 'Page and delete')) as ParametricEdit;
    final result = edit.apply(copy);
    expect(copy.tree[hG2], isNull);
    expect(copy.components.get<Gauge>(hG2), isNull);
    expect(calls(hG2), 0, reason: 'a deleted object is not regenerated');
    expect(calls(hG), 1);
    expect(lineLength(copy, hG), closeTo(250, 1e-6), reason: '10 x 25');
    final restores = [
      for (final c in flatten(result.inverse))
        if (c is SetComponentCommand<Gauge> && c.handle == hG2) c.value,
    ];
    expect(restores, [gauge2], reason: 'detached once');
    // The same compound through the dispatcher: one undo step, exact undo.
    final beforeCompound = canon(doc, sortNodes: true);
    final depth3 = doc.commands.undoDepth;
    doc.commands.execute(CompoundCommand(
        [setPage(doc, m25), deleteObject(doc, hG2)],
        label: 'Page and delete'));
    expect(doc.components.get<Gauge>(hG2), isNull);
    expect(lineLength(doc, hG), closeTo(250, 1e-6));
    expect(doc.commands.undoDepth, depth3 + 1);
    expect(drift(doc), isEmpty);
    doc.commands.undo();
    expect(canon(doc, sortNodes: true), beforeCompound);
    expect(doc.components.get<Gauge>(hG2), gauge2);
    expect(drift(doc), isEmpty);

    // A page attached where none was: a Gauge created before it
    // regenerates only if the new scale is not 50.
    final bare = pageDoc();
    bare.commands.execute(create(bare, hG, atG, gauge));
    expect(bare.components.get<PageComponent>(bare.rootHandle), isNull);
    expect(lineLength(bare, hG), closeTo(500, 1e-6), reason: 'no page: 50');
    final b0 = calls(hG);
    bare.commands.execute(setPage(bare, PageComponent(gridStepMm: 250.5)));
    expect(calls(hG), b0, reason: 'attached at 1:50: the key is unchanged');
    bare.commands.execute(setPage(bare, null));
    expect(calls(hG), b0, reason: 'detached from 1:50: the key is unchanged');
    bare.commands.execute(setPage(bare, PageComponent(scaleDenominator: 20.5)));
    expect(calls(hG), b0 + 1);
    expect(lineLength(bare, hG), closeTo(205, 1e-6), reason: '10 x 20.5');
    expect(drift(bare), isEmpty);

    // Ruling 10-4: a loaded Gauge whose host names a missing handle. A page
    // change regenerates it and is not refused: it was seeded by the page,
    // not edited.
    final missing = Handle(doc.handleSeed.current.value + 1000);
    final edited = jsonDecode(enc(doc)) as Map<String, Object?>;
    ((edited['components']! as Map)[Gauge.id]! as Map)['${hG.value}'] =
        Gauge(gauge.x, gauge.y, host: missing).toJson();
    final loaded = reloadWithPage(jsonEncode(edited));
    expect(
        loaded.components.get<Gauge>(hG), Gauge(125.5, -40.25, host: missing));
    final page = loaded.components.get<PageComponent>(loaded.rootHandle)!;
    expect(page.scaleDenominator, 100);
    List<Diagnostic> dangling() => [
          for (final d in ParametricSystem(loaded, catalog).diagnostics())
            if (d.code == 'parametric.dangling') d,
        ];
    expect(dangling().single.handles, [hG, missing]);
    // Premise: an edit of the Gauge itself is refused, so the reference is
    // live and only the page seeds' place spares the page change.
    expect(
        () => loaded.commands.execute(SetComponentCommand<Gauge>(
            hG, Gauge(130.5, -40.25, host: missing))),
        throwsA(isA<DanglingReferenceError>()));
    final loadedDepth = loaded.commands.undoDepth;
    final l0 = calls(hG);
    loaded.commands
        .execute(setPage(loaded, page.copyWith(scaleDenominator: 12.5)));
    expect(calls(hG), l0 + 1);
    expect(lineLength(loaded, hG), closeTo(125, 1e-6), reason: '10 x 12.5');
    expect(loaded.commands.undoDepth, loadedDepth + 1);
    expect(dangling().single.handles, [hG, missing]);

    // With `PageComponent` not registered, `view.page` is null: a Gauge
    // draws 10 x 50 = 500, a Dial 100 x (2 + 1) = 300.
    final unregistered = paramDoc();
    expect(unregistered.components.isRegistered<PageComponent>(), isFalse);
    unregistered.commands.execute(create(unregistered, hG, atG, gauge));
    unregistered.commands.execute(create(unregistered, hD, atD, dial));
    expect(lineLength(unregistered, hG), closeTo(500, 1e-6));
    expect(lineLength(unregistered, hD), closeTo(300, 1e-6));
    expect(drift(unregistered), isEmpty);
  });

  test(
      'PG2 a paper-colour change and a grid change call no generate of '
      'a page-key client', () async {
    final doc = pageDoc();
    final page = PageComponent(scaleDenominator: 100);
    doc.commands.execute(setPage(doc, page));
    doc.commands.execute(create(doc, hG, atG, gauge));
    doc.commands.execute(create(doc, hD, atD, dial));
    expect(lineLength(doc, hG), closeTo(1000, 1e-6));
    expect(lineLength(doc, hD), closeTo(300, 1e-6));
    final g0 = calls(hG), d0 = calls(hD);
    final depth = doc.commands.undoDepth;

    // Blueprint paper: one command, the page changed, no generate.
    final blue = page.copyWith(background: 0xFF1E3A5F);
    final caps = await appliedCapabilities(
        doc, () => doc.commands.execute(setPage(doc, blue)));
    expect(doc.components.get<PageComponent>(doc.rootHandle), blue);
    expect(calls(hG), g0);
    expect(calls(hD), d0);
    expect(doc.commands.undoDepth, depth + 1);
    expect(caps, [Capability.components], reason: 'nothing regenerated');

    // A grid step: one command, the page changed, no generate.
    final grid = blue.copyWith(gridStepMm: 250.5);
    doc.commands.execute(setPage(doc, grid));
    expect(doc.components.get<PageComponent>(doc.rootHandle), grid);
    expect(calls(hG), g0);
    expect(calls(hD), d0);
    expect(doc.commands.undoDepth, depth + 2);
    expect(lineLength(doc, hG), closeTo(1000, 1e-6));
    expect(lineLength(doc, hD), closeTo(300, 1e-6));
    expect(drift(doc), isEmpty);
  });
}
