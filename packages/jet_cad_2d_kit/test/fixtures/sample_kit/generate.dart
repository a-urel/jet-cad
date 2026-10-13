// The sample kit's generator, as a kit's own runs (spec K7): writes the
// library and adds the snapshot entries of new key@Ns, never rewriting an
// existing one.
//
//   cd packages/jet_cad_2d_kit && dart run test/fixtures/sample_kit/generate.dart
import 'dart:io';

import 'package:jet_cad_2d_kit/authoring.dart';

import 'sample_kit.dart';

void main() {
  final dir = File.fromUri(Platform.script).parent.path;
  File('$dir/sample.jetlib').writeAsBytesSync(encodeLibrary(sampleCatalog));
  final snapshot = File('$dir/sample_snapshot.json');
  final committed = snapshot.existsSync()
      ? parseSnapshot(snapshot.readAsStringSync())
      : <String, String>{};
  snapshot.writeAsStringSync(encodeSnapshot(
      updateSnapshot(committed, geometrySnapshot(sampleCatalog))));
  stdout.writeln('sample kit: ${sampleCatalog.symbols.length} symbols written');
}
