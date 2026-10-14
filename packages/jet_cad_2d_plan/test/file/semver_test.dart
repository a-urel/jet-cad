// Spec 2a P4 "Versions (R6)": kit versions are semantic versions compared
// by precedence; one that does not parse is not compared.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/file/semver.dart';

void main() {
  test('PF-7 precedence, semver 2.0.0 section 11; build metadata ignored', () {
    const ordered = [
      '0.9.9',
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0',
      '1.0.1',
      '1.2.0',
      '1.10.0',
      '2.0.0',
    ];
    for (var i = 0; i < ordered.length; i++) {
      for (var j = 0; j < ordered.length; j++) {
        final a = SemVer.tryParse(ordered[i])!,
            b = SemVer.tryParse(ordered[j])!;
        // M-PF-7a: pre-release identifiers compared as text ('11' < '2').
        // M-PF-7b: a pre-release ranked above its release.
        // M-PF-7c: minor compared as text ('10' < '2').
        expect(a.compareTo(b).sign, i.compareTo(j).sign,
            reason: '${ordered[i]} vs ${ordered[j]}');
      }
    }
    expect(
        SemVer.tryParse('1.2.3+build.7')!.compareTo(SemVer.tryParse('1.2.3')!),
        0);
  });

  test('PF-7u what does not parse is null, and is never compared', () {
    for (final text in [
      '',
      '1',
      '1.2',
      '1.2.x',
      '01.2.3',
      '1.2.3-',
      'v1.2.3',
      '1.2.3-01',
      '99999999999999999999.0.0'
    ]) {
      // M-PF-7u: tryParse on the major.minor.patch prefix only.
      expect(SemVer.tryParse(text), isNull, reason: text);
    }
    expect(isNewerVersion('1.x', '1.0.0'), isNull);
    expect(isNewerVersion('2.0.0', 'dev'), isNull);
    expect(isNewerVersion('1.2.1', '1.2.0'), isTrue);
    expect(isNewerVersion('1.2.0', '1.2.0'), isFalse);
    expect(isNewerVersion('1.2.0', '1.2.0-rc.1'), isTrue);
  });
}
