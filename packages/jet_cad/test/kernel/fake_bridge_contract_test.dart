import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

import 'bridge_contract.dart';

void main() {
  group('FakeKernelBridge honors the bridge contract', () {
    runKernelBridgeContract(FakeKernelBridge.new);
  });
}
