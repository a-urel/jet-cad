import 'package:jet_cad_ci/screenshots.dart';
import 'package:test/test.dart';

const _pkg = 'jet_cad_2d_flutter';
const _ignore = '/test/\n/build/\n/shaders/\n';

/// The package's directory at its release tag; a README URL is this plus
/// the screenshot's path.
const _url = 'https://raw.githubusercontent.com/a-urel/jet-cad/'
    'jet_cad_2d_flutter-v0.7.2/packages/jet_cad_2d_flutter';

String pubspec(List<(String, String)> shots, {String version = '0.7.2'}) => [
      'name: $_pkg',
      'version: $version',
      'screenshots:',
      for (final (d, p) in shots) ...["  - description: '$d'", '    path: $p'],
    ].join('\n');

String readme(Iterable<String> paths, {String base = _url}) =>
    paths.map((p) => '![$p]($base/$p)').join('\n\n');

const _good = [
  ('The canvas with rulers, light.', 'doc/screenshots/a.png'),
  ('The canvas on the dark canvas.', 'doc/screenshots/b.png'),
];

List<String> run({
  List<(String, String)> shots = _good,
  String? md,
  String ignore = _ignore,
  int? Function(String)? sizeOf,
  String version = '0.7.2',
}) =>
    screenshotProblems(
      package: _pkg,
      pubspec: pubspec(shots, version: version),
      readme: md ?? readme(shots.map((s) => s.$2)),
      pubignore: ignore,
      sizeOf: sizeOf ?? (_) => 200 * 1024,
    );

void main() {
  test('SS1 a good set has no problem', () => expect(run(), isEmpty));

  test('SS2 an eleventh entry', () {
    final eleven = [
      for (var i = 0; i < 11; i++) ('Screenshot number $i.', 'doc/s/$i.png')
    ];
    expect(run(shots: eleven), contains(startsWith('11 screenshots')));
  });

  test('SS3 a 9- and a 161-character description', () {
    expect(run(shots: [('123456789', 'doc/s/a.png')]),
        contains(contains('description')));
    expect(run(shots: [('x' * 161, 'doc/s/a.png')]),
        contains(contains('description')));
    expect(run(shots: [('x' * 160, 'doc/s/a.png')]), isEmpty);
    expect(run(shots: [('1234567890', 'doc/s/a.png')]), isEmpty);
  });

  test('SS4 a missing file', () {
    expect(run(sizeOf: (p) => p.endsWith('b.png') ? null : 1),
        contains(contains('missing')));
  });

  test('SS5 a file over 1 MB, a total over 4 MB', () {
    expect(run(sizeOf: (_) => 1024 * 1024 + 1), contains(contains('1 MB')));
    final five = [
      for (var i = 0; i < 5; i++) ('Screenshot number $i.', 'doc/s/$i.png')
    ];
    expect(run(shots: five, sizeOf: (_) => 900 * 1024),
        contains(contains('4 MB')));
  });

  test('SS6 a path the archive leaves out', () {
    expect(run(shots: [('A test screenshot.', 'test/a.png')]),
        contains(contains('.pubignore')));
    expect(run(shots: [('A hidden screenshot.', '.github/a.png')]),
        contains(contains('dot')));
  });

  test('SS7 a path not normalised, or of another type', () {
    expect(run(shots: [('A dotted screenshot.', './doc/a.png')]),
        contains(contains('normalised')));
    expect(run(shots: [('An SVG screenshot.', 'doc/a.svg')]),
        contains(contains('type')));
  });

  test('SS8 a duplicate path', () {
    expect(run(shots: [_good[0], _good[0]]), contains(contains('twice')));
  });

  test('SS9 a README image on main', () {
    final main = _url.replaceFirst('jet_cad_2d_flutter-v0.7.2', 'main');
    expect(run(md: readme(_good.map((s) => s.$2), base: main)),
        contains(contains('tag')));
  });

  test("SS10 a README image on the previous version's tag", () {
    final old = _url.replaceFirst('-v0.7.2', '-v0.7.1');
    expect(run(md: readme(_good.map((s) => s.$2), base: old)),
        contains(contains('tag')));
  });

  test('SS11 a relative README image, an unlisted one, a listed one unshown',
      () {
    expect(
        run(
            md: '![a](doc/screenshots/a.png)\n'
                '${readme(['doc/screenshots/b.png'])}'),
        contains(contains('absolute')));
    expect(
        run(md: readme([..._good.map((s) => s.$2), 'doc/screenshots/c.png'])),
        contains(contains('not listed')));
    expect(run(md: readme(['doc/screenshots/a.png'])),
        contains(contains('not in the README')));
  });

  test("SS12 the engine's README has no image", () {
    expect(imagelessProblems('# jet_cad_2d\n\nText.\n'), isEmpty);
    expect(imagelessProblems('![x](https://example.com/x.png)'), isNotEmpty);
    expect(imagelessProblems('<img src="x.png">'), isNotEmpty);
  });

  test('SS13 a .pubignore pattern the reader does not know', () {
    expect(run(ignore: '*.png\n'), contains(contains('pattern')));
  });
}
