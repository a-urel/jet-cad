// Spec 08 D2, D3: references between parametric objects, and a closure
// that follows them. Every Post sits in a rotated group off the origin;
// every Pin's own group has a different rotated, translated transform.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/clients.dart';
import 'support/fixture.dart';

const Handle hP = Handle(3000);

/// P's own group: rotated and translated, unlike A's.
final Transform2 pinAt =
    Transform2.translation(8400, 1900).multiply(Transform2.rotation(-1.05));

/// B over A's bottom-right corner: A's bottom edge keeps [0, ~1639] only.
final Transform2 atCorner = onA(1700, -300, 0.2);

const Post postA = Post(2000, 1000);

List<double> seg(Vector2 a, Vector2 b) => [a.x, a.y, b.x, b.y];

/// A's tick for [offset], in world.
List<double> worldTick(Transform2 at, double offset) => seg(
    at.transformPoint(Vector2(offset, 0)),
    at.transformPoint(Vector2(offset, -Post.tick)));

bool hasSegment(List<List<double>> segments, List<double> want) =>
    segments.any((s) => [
          for (var k = 0; k < 4; k++) (s[k] - want[k]).abs(),
        ].every((d) => d < 1e-6));

double lengthOf(List<double> s) =>
    math.sqrt((s[2] - s[0]) * (s[2] - s[0]) + (s[3] - s[1]) * (s[3] - s[1]));

List<Handle> drift(DraftDocument doc) => ParametricSystem(doc, catalog).drift();

/// Every `test.referrers` entry, by the handle it is about.
Map<Handle, List<Handle>> reported(DraftDocument doc, ParametricCatalog c) => {
      for (final d in ParametricSystem(doc, c).diagnostics())
        if (d.code == 'test.referrers') d.handles.first: d.handles.sublist(1),
    };

/// [group]'s children and their stored coordinates, by handle.
Map<Handle, List<double>> stored(DraftDocument doc, Handle group) => {
      for (final k in kids(doc, group))
        k: doc.geometry
            .read(doc.entities.geomIndexAt(doc.entities.slotOf(k)!))
            .coords
            .toList(),
    };

/// A, B over its corner, and P on A: the two-hop shape.
DraftDocument twoHop() {
  final doc = paramDoc();
  doc.commands.execute(create(doc, hA, atA, postA));
  doc.commands.execute(create(doc, hB, atCorner, const ClipRect(400, 900)));
  doc.commands.execute(create(doc, hP, pinAt, const Pin(hA, 450)));
  return doc;
}

void main() {
  setUp(() {
    generateCalls.clear();
    Post.watch = [];
    Post.seen.clear();
  });

  test(
      'RF1 the survey\'s maps: referrers ascending and unmodifiable; a '
      'reference to a plain group, a root LINE, itself or nothing relates '
      'nothing', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    final pins = [const Handle(5300), const Handle(5100), const Handle(5200)];
    for (final (i, h) in pins.indexed) {
      doc.commands.execute(create(
          doc,
          h,
          Transform2.translation(9000.0 + 400 * i, 1200.0 - 300 * i)
              .multiply(Transform2.rotation(0.4 + 0.5 * i)),
          Pin(hA, 300.0 + 500 * i)));
    }
    // A Tag, registered after Pin: a survey that walked the objects type by
    // type, rather than by handle, would list it after every Pin. It
    // declares A twice: the survey lists it once.
    const tag = Handle(5150);
    doc.commands.execute(create(
        doc,
        tag,
        Transform2.translation(8100, 2600).multiply(Transform2.rotation(-2.2)),
        const Tag(hA)));
    expect(const TagType().references(const Tag(hA)), [hA, hA]);
    const ascending = [Handle(5100), tag, Handle(5200), Handle(5300)];
    expect(reported(doc, catalog)[hA], ascending);
    expect(Post.seen[hA], ascending);
    expect(() => Post.seen[hA]!.add(hA), throwsUnsupportedError);

    // Four more Pins, created on A and then pointed elsewhere by loading
    // an edited encoding: an edit may not create them (spec 08 D5).
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: parked,
        children: const [])));
    final line = addDrafted(doc, EntityKind.line,
        linePayload(Vector2(7200.5, 2100.25), Vector2(7300.75, 2210.5)));
    doc.commands.execute(line);
    final leaf = line.record.handle;
    final bad = [for (var i = 0; i < 4; i++) doc.handleSeed.next()];
    for (final (i, h) in bad.indexed) {
      doc.commands.execute(create(
          doc,
          h,
          Transform2.translation(6000.0 - 500 * i, 5000.0 + 200 * i)
              .multiply(Transform2.rotation(-0.3 - 0.4 * i)),
          Pin(hA, 900.0 + 100 * i)));
    }
    final missing = Handle(doc.handleSeed.current.value + 1000);
    final targets = [group, leaf, bad[2], missing];
    final j = jsonDecode(enc(doc)) as Map<String, Object?>;
    final pinJson = ((j['components']! as Map)[Pin.id]! as Map);
    for (final (i, h) in bad.indexed) {
      (pinJson['${h.value}']! as Map)['host'] = targets[i].value;
    }
    final loaded = reload(jsonEncode(j));
    for (final (i, h) in bad.indexed) {
      expect(loaded.components.get<Pin>(h)!.host, targets[i]);
    }
    expect(loaded.tree[group], isA<GroupNode>());
    expect(loaded.entities.slotOf(leaf), isNotNull);

    Post.watch = [group, leaf, ...bad, missing];
    final got = reported(loaded, catalog);
    expect(got[hA], ascending);
    for (final h in Post.watch) {
      expect(got[h], isEmpty, reason: h.toHex());
      expect(() => Post.seen[h]!.add(hA), throwsUnsupportedError,
          reason: h.toHex());
    }
    expect(() => Post.seen[hA]!.add(hA), throwsUnsupportedError);
  });

  test(
      'RF2 editing a Pin regenerates its Post in the same undo step: the '
      'tick moves; undo and redo are exact', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(doc, hP, pinAt, const Pin(hA, 700)));
    expect(drift(doc), isEmpty);
    expect(hasSegment(worldSegments(doc, hA), worldTick(atA, 700)), isTrue);
    final before = canon(doc);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(SetComponentCommand<Pin>(hP, const Pin(hA, 1330)));
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    final segments = worldSegments(doc, hA);
    expect(hasSegment(segments, worldTick(atA, 1330)), isTrue);
    expect(hasSegment(segments, worldTick(atA, 700)), isFalse);
    final after = canon(doc);

    doc.commands.undo();
    expect(canon(doc), before);
    doc.commands.redo();
    expect(canon(doc), after);
  });

  test(
      'RF3 moving a Post 60 m away regenerates its Pin: the line moves by '
      'exactly the move vector, in one undo step', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(doc, hP, pinAt, const Pin(hA, 700)));
    final was = worldSegments(doc, hP);
    // Unclipped: A has no neighbour, so P copies A's whole bottom edge.
    expect(was, hasLength(1));
    expect(
        hasSegment(
            was,
            seg(atA.transformPoint(Vector2(0, 0)),
                atA.transformPoint(Vector2(2000, 0)))),
        isTrue);
    final move = Vector2(60000, -8000);
    final away = Transform2.translation(move.x, move.y).multiply(atA);
    final r0 = rectReach(postA, atA), r1 = rectReach(postA, away);
    expect(r0.maxX < r1.minX || r1.maxX < r0.minX, isTrue,
        reason: 'the reaches before and after are disjoint');
    final depth = doc.commands.undoDepth;

    doc.commands.execute(TransformNodeCommand(hA, away));
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    final now = worldSegments(doc, hP);
    expect(now, hasLength(1));
    for (var k = 0; k < 4; k++) {
      expect(now[0][k] - was[0][k], closeTo(k.isEven ? move.x : move.y, 1e-6),
          reason: 'coord $k');
    }
  });

  test(
      'RF4 the two-hop shape: B, a neighbour of Post A, moves away; A\'s '
      'Pin regenerates and its copy of A\'s clipped edge grows', () {
    final doc = twoHop();
    final clipped = worldSegments(doc, hP);
    expect(clipped, hasLength(1));
    expect(lengthOf(clipped[0]), lessThan(1700));
    expect(lengthOf(clipped[0]), greaterThan(1500));

    doc.commands.execute(TransformNodeCommand(hB, parked));
    expect(drift(doc), isEmpty);
    final whole = worldSegments(doc, hP);
    expect(whole, hasLength(1));
    expect(
        hasSegment(
            whole,
            seg(atA.transformPoint(Vector2(0, 0)),
                atA.transformPoint(Vector2(2000, 0)))),
        isTrue);
    expect(lengthOf(whole[0]), closeTo(2000, 1e-6));
  });

  test(
      'RF5 editing a Pin regenerates its Post but not the Post\'s '
      'neighbour: B is not generated, its children are unchanged', () {
    final doc = twoHop();
    // Not degenerate: B clips A, so A reads B.
    expect(lengthOf(worldSegments(doc, hP)[0]), lessThan(1700));
    final bBefore = stored(doc, hB);
    generateCalls.clear();

    doc.commands.execute(SetComponentCommand<Pin>(hP, const Pin(hA, 1250)));
    // Read before drift(), which generates every object.
    expect(generateCalls[hB], isNull);
    expect(generateCalls[hA], 1);
    expect(generateCalls[hP], 1);
    expect(stored(doc, hB), bBefore);
    expect(drift(doc), isEmpty);
    expect(hasSegment(worldSegments(doc, hA), worldTick(atA, 1250)), isTrue);
  });

  test(
      'RF6 deleting a Pin regenerates its Post in the same edit: the Pin\'s '
      'tick goes, the other Pin\'s stays', () {
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(doc, hP, pinAt, const Pin(hA, 700)));
    doc.commands.execute(create(
        doc,
        const Handle(3100),
        pinAt.multiply(Transform2.translation(-900, 350)),
        const Pin(hA, 1500)));
    expect(hasSegment(worldSegments(doc, hA), worldTick(atA, 700)), isTrue);
    final depth = doc.commands.undoDepth;

    doc.commands.execute(CompoundCommand([
      for (final k in kids(doc, hP)) RemoveEntityCommand(k),
      RemoveNodeCommand(hP),
    ], label: 'Delete'));
    expect(drift(doc), isEmpty);
    expect(doc.commands.undoDepth, depth + 1);
    final a = worldSegments(doc, hA);
    expect(hasSegment(a, worldTick(atA, 700)), isFalse);
    expect(hasSegment(a, worldTick(atA, 1500)), isTrue);
  });

  test(
      'RF7 re-pointing a Pin from Post A to Post C regenerates both in the '
      'same edit: the tick leaves A and appears on C', () {
    const hC = Handle(4000);
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(doc, hC, parked, const Post(1600, 800)));
    doc.commands.execute(create(doc, hP, pinAt, const Pin(hA, 700)));
    expect(hasSegment(worldSegments(doc, hA), worldTick(atA, 700)), isTrue);
    expect(hasSegment(worldSegments(doc, hC), worldTick(parked, 700)), isFalse);

    doc.commands.execute(SetComponentCommand<Pin>(hP, const Pin(hC, 700)));
    expect(drift(doc), isEmpty);
    expect(hasSegment(worldSegments(doc, hA), worldTick(atA, 700)), isFalse);
    expect(hasSegment(worldSegments(doc, hC), worldTick(parked, 700)), isTrue);
    // P now copies C's bottom edge.
    expect(
        hasSegment(
            worldSegments(doc, hP),
            seg(parked.transformPoint(Vector2(0, 0)),
                parked.transformPoint(Vector2(1600, 0)))),
        isTrue);
  });

  test(
      'RF8 a loaded Pin names a plain group; the group then becomes a Post, '
      'and the Pin regenerates in the same edit as the Post\'s referrer', () {
    // P hangs off Pin P0, which reads no referrers, so nothing else stores
    // anything of P's.
    const hP0 = Handle(2500);
    final doc = paramDoc();
    doc.commands.execute(create(doc, hA, atA, postA));
    doc.commands.execute(create(
        doc,
        hP0,
        Transform2.translation(5200, 800).multiply(Transform2.rotation(1.9)),
        const Pin(hA, 300)));
    doc.commands.execute(create(doc, hP, pinAt, const Pin(hP0, 700)));
    final group = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(GroupNode(
        handle: group,
        parent: doc.rootHandle,
        transform: parked,
        children: const [])));
    final j = jsonDecode(enc(doc)) as Map<String, Object?>;
    ((j['components']! as Map)[Pin.id]! as Map)['${hP.value}'] =
        Pin(group, 700).toJson();
    final loaded = reload(jsonEncode(j));
    expect(loaded.components.get<Pin>(hP), Pin(group, 700));
    // P still stores its line to P0; regenerated, it would draw nothing.
    expect(drift(loaded), [hP]);

    loaded.commands
        .execute(SetComponentCommand<Post>(group, const Post(1600, 800)));
    expect(drift(loaded), isEmpty);
    final p = worldSegments(loaded, hP);
    expect(p, hasLength(1));
    expect(
        hasSegment(
            p,
            seg(parked.transformPoint(Vector2(0, 0)),
                parked.transformPoint(Vector2(1600, 0)))),
        isTrue);
    expect(hasSegment(worldSegments(loaded, group), worldTick(parked, 700)),
        isTrue);
  });
}
