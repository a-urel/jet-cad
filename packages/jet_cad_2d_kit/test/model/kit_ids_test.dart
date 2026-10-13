// Spec K2: the identifier patterns. Each list holds the edge a plausible
// mutation of the pattern lets through.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('I1 a kit id is a lower-case letter, then letters and digits', () {
    for (final id in ['restaurant', 'a', 'kit2', 'architecture']) {
      expect(isKitId(id), isTrue, reason: id);
    }
    // M-I1: `^[a-z0-9][a-z0-9]*$` lets '2kit' through.
    for (final id in [
      '',
      '2kit',
      'Restaurant',
      'my-kit',
      'my_kit',
      'a.b',
      'kit ',
      'kit\n',
    ]) {
      expect(isKitId(id), isFalse, reason: id);
    }
  });

  test('I2 a kind is lower-case letters and digits joined by single hyphens',
      () {
    for (final kind in ['wall-face', 'table', 'seat', 'bed-double', 'a1-2b']) {
      expect(isKind(kind), isTrue, reason: kind);
    }
    // M-I2: `^[a-z0-9-]+$` lets 'wall--face', '-wall' and 'wall-' through.
    for (final kind in [
      '',
      'Wall-face',
      'wall--face',
      '-wall',
      'wall-',
      'wall face',
      'wall_face',
      'wall.face',
      'wall-face\n',
    ]) {
      expect(isKind(kind), isFalse, reason: kind);
    }
  });

  test('I3 a key is a kit id, then two or more segments', () {
    for (final key in [
      'restaurant.table.rect',
      'restaurant.table.rect.four',
      'sample.table.high-top',
      'sample.a1.b-2.c',
    ]) {
      expect(isSymbolKey(key), isTrue, reason: key);
    }
    for (final key in [
      'restaurant.table', // M-I3a: `{1,}` in place of `{2,}`
      'restaurant',
      'Restaurant.table.rect',
      'my-kit.table.rect', // M-I3b: the kit-id check on the first segment dropped
      '2kit.table.rect', // M-I3b too
      'restaurant..table.rect',
      'restaurant.table.rect.',
      'restaurant.table rect.x',
      'restaurant.Table.rect',
      'restaurant.table.rect\n',
    ]) {
      expect(isSymbolKey(key), isFalse, reason: key);
    }
  });

  test('I4 kitOfKey is the first dot-separated segment', () {
    expect(kitOfKey('restaurant.table.rect'), 'restaurant');
    expect(kitOfKey('architecture.wall'), 'architecture');
    expect(kitOfKey('wall'), 'wall');
  });
}
