// Spec 3a C1.6: numbered names in the contract, over patterns that name no
// plan type. A room tool passes one pattern per locale of its words; the
// plan's layer panel one per built-in language and the current one.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

String room(int n) => 'Room $n';
String raum(int n) => 'Raum $n';
String oda(int n) => 'Oda $n';

void main() {
  test(
      'KW-numbered the n of a name made by any of the patterns, compared by '
      'the fold (M-KW-first-pattern, M-KW-fold)', () {
    final patterns = [room, raum, oda];
    expect(numberedNameIndex('Room 4', patterns), 4);
    // M-KW-first-pattern: only the first pattern compared.
    expect(numberedNameIndex('Oda 12', patterns), 12);
    expect(numberedNameIndex('Raum 3', patterns), 3);
    // Folded: the fold given meets a case difference, on both sides.
    // M-KW-fold: the fold applied to the name only.
    expect(
        numberedNameIndex('ODA 7', patterns, fold: (s) => s.toLowerCase()), 7);
    expect(numberedNameIndex('ODA 7', patterns), isNull);
  });

  test('KW-numbered-shape a name of another shape takes no n', () {
    for (final name in ['Room 0', 'Room 2 ', 'Room', 'Raum 2a', 'Hall 3', '']) {
      expect(numberedNameIndex(name, [room, raum, oda]), isNull, reason: name);
    }
    expect(numberedNameIndex('Room 3', const []), isNull);
  });
}
