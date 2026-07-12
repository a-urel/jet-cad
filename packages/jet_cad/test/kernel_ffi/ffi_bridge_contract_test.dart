import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

import '../kernel/bridge_contract.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {});
    return;
  }
  group('FfiKernelBridge honors the bridge contract', () {
    runKernelBridgeContract(() => FfiKernelBridge(libPath));
  });
}
