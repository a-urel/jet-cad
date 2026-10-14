// The test kits are sound (spec 2a "Tests"): the test kit's words are
// English and Turkish only, every id it uses has its English word, and the
// throwing kit throws for the hooks it is told to and no others; the
// harness builds a plan document whose system generates every kit's objects.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';
import '../support/throwing_kit.dart';

void main() {
  test('TK1 the test kit validates; its words are en and tr, no de', () {
    final kit = testKit();
    expect(kit.validate(), isEmpty);
    expect(kit.names.words.keys.toSet(), {'en', 'tr'});
    final english = kit.names.words['en']!;
    for (final spec in slabProperties()) {
      expect(english, contains('property:test.slab.${spec.id}'));
    }
    expect(english.keys.toSet(), kit.names.words['tr']!.keys.toSet());
  });

  test('TK2 the disc kit, the conflict kit and the throwing kit validate', () {
    expect(discKit().validate(), isEmpty);
    expect(conflictKit().validate(), isEmpty);
    expect(ThrowingKit().kit.validate(), isEmpty);
  });

  test('TK3 the throwing kit throws for its failing hooks only', () {
    expect(() => ThrowingKit(failing: ['nope']), throwsArgumentError);
    final kit = ThrowingKit(failing: ['reach']);
    expect(() => kit.check('reach'),
        throwsA(isA<BoomFailure>().having((f) => f.hook, 'hook', 'reach')));
    kit.check('generate');
    kit.failAll();
    expect(kit.failing, boomHooks);
    for (final hook in boomHooks) {
      expect(() => kit.check(hook), throwsA(isA<BoomFailure>()), reason: hook);
    }
  });

  test('TK4 a slab off the origin, turned: its corners and its JSON', () {
    final s =
        SlabComponent(width: 1800, height: 900, angle: 0.4, swatch: 'red');
    final c = slabCorners(s);
    // (900, -450) turned by 0.4 rad, by hand.
    expect(c[1].x, closeTo(900 * 0.9210609940 + 450 * 0.3894183423, 1e-6));
    expect(c[1].y, closeTo(900 * 0.3894183423 - 450 * 0.9210609940, 1e-6));
    expect(SlabComponent.fromJson(s.toJson()), s);
    expect(s.toJson().keys.toList(), [
      'angle',
      'finish',
      'flipped',
      'height',
      'label',
      'labelled',
      'swatch',
      'thickness',
      'width',
    ]);
    expect(discOutline(DiscComponent(radius: 650)).first, Vector2(650, 0));
  });

  test('TK5 the harness: a plan document whose system draws every kit', () {
    final boom = ThrowingKit();
    final kits = [testKit(), discKit(), boom.kit];
    final d = planDocument(kits, separator: DecimalSeparator.comma);
    final page = d.components.get<PageComponent>(d.rootHandle)!;
    expect((page.originX, page.originY), (-7425.0, -5250.0));
    expect(page.decimalSeparator, DecimalSeparator.comma);
    expect(d.header.units, DrawingUnits.millimeters);
    expect(d.commands.canUndo, isFalse);
    installSystem(d, kits);
    final slab = addObject<SlabComponent>(
        d, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2500, -1300));
    final disc = addObject<DiscComponent>(d, DiscComponent(radius: 650),
        at: Vector2(-900, 700));
    final block = addObject<BlockComponent>(d, const BlockComponent(size: 400),
        at: Vector2(100, 200));
    // The outline is generated in the group's space: the turned corners.
    final coords = coordsOf(d, leavesOf(d, slab).single);
    final corners =
        slabCorners(SlabComponent(width: 1800, height: 900, angle: 0.4));
    expect(coords[2], closeTo(corners[1].x, 1e-9));
    expect(coords[3], closeTo(corners[1].y, 1e-9));
    expect(leavesOf(d, disc), hasLength(1));
    expect(leavesOf(d, block), hasLength(1));
    final line = addLine(d, Vector2(-310, 45), Vector2(820, -130));
    expect(coordsOf(d, line), [-310, 45, 820, -130]);
  });
}
