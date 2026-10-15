// Spec 3a C1.6, C1.2: a word id and its arguments (KitText), put into
// words when read; a template's placeholders filled (fillText) and listed
// (placeholdersOf). Pure Dart, like the rest of the model.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart' as authoring
    show KitText, fillText, numberedNameIndex, placeholdersOf;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test(
      'KW-fill every placeholder that has an argument is filled, each time '
      'it appears; one without is left as written; an unused argument is '
      'ignored (M-KW-missing, M-KW-first)', () {
    expect(fillText('Already a room: {name}', {'name': 'Oda 3'}),
        'Already a room: Oda 3');
    expect(
        fillText('{wall} {end} ({side}), {wall}',
            {'wall': '7A', 'end': 'start', 'side': 'left face', 'n': 4}),
        '7A start (left face), 7A');
    // M-KW-missing: a missing argument filled as ''.
    expect(
        fillText('Bedroom {n} of {count}', {'n': 2}), 'Bedroom 2 of {count}');
    // A non-String argument is printed with its toString.
    expect(fillText('{degrees}°', {'degrees': 12.5}), '12.5°');
    // Braces that are no placeholder.
    expect(fillText('{ name } {} {2} {name', {'name': 'x'}),
        '{ name } {} {2} {name');
    expect(fillText('Yatak odası {n}', const {'n': 1}), 'Yatak odası 1');
    expect(fillText('No placeholder', {'name': 'x'}), 'No placeholder');
  });

  test('KW-placeholders the set of names a template holds', () {
    // M-KW-placeholders: placeholdersOf answers an empty set.
    expect(placeholdersOf('{wall} {end} ({side}), {wall}'),
        {'wall', 'end', 'side'});
    expect(placeholdersOf('{ name } {} {2}'), isEmpty);
    expect(placeholdersOf('Raum {n}'), {'n'});
  });

  test(
      'KW-text KitText equals by its id and its arguments, whatever their '
      'order; any other id or value differs (M-KW-eq)', () {
    final a = KitText('text:test.busy', {'name': 'Slab 1', 'n': 2});
    final b = KitText('text:test.busy', {'n': 2, 'name': 'Slab 1'});
    // M-KW-eq: `==` comparing the maps by identity.
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(KitText('text:test.busy', {'name': 'Slab 2', 'n': 2})));
    expect(a, isNot(KitText('text:test.free', {'name': 'Slab 1', 'n': 2})));
    expect(a, isNot(const KitText('text:test.busy', {'name': 'Slab 1'})));
    expect(const KitText('text:test.idle').args, isEmpty);
  });

  test(
      'KW-barrels the authoring library exports KitText, fillText, '
      'placeholdersOf and numberedNameIndex (pure Dart)', () {
    // A premise of the export list, exempt from the mutation rule beyond
    // M-KW-export: without it this file does not compile.
    expect(identical(authoring.fillText, fillText), isTrue);
    expect(identical(authoring.placeholdersOf, placeholdersOf), isTrue);
    expect(identical(authoring.numberedNameIndex, numberedNameIndex), isTrue);
    expect(const authoring.KitText('text:a.b'), const KitText('text:a.b'));
  });
}
