// The frame-path allocation instrument the spec's invariant 1 calls a "new
// mechanism" (Ruling F8). `flutter test` cannot host one --
// `flutter_tester` launches with `--disable-vm-service` (STATUS, Plan 3g) --
// but a `flutter run --profile` process serves the VM service for DevTools,
// and this connects to its own isolate the way
// `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart` does under
// `dart test`, with `Service.getInfo()` first because the server is already
// up here.
import 'dart:developer' as dev;
import 'dart:isolate' as iso;

import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart' as vms_io;

/// Library URIs whose classes the report counts: this project's own frame
/// path, the two `dart:` libraries its per-frame objects live in, and the
/// GPU shim's per-pass objects, reported beside ours.
const List<String> kProbedLibraryPrefixes = <String>[
  'package:jet_cad_2d_flutter/',
  'dart:ui',
  'dart:typed_data',
  'package:flutter_gpu/',
  'package:flutter_scene/',
];

class AllocationProbe {
  AllocationProbe._(this._service, this._isolateId);
  final vms.VmService _service;
  final String _isolateId;

  /// Connects to this process's VM service. Throws with the reason when the
  /// service is not serving; the caller reports UNEVALUABLE, never a number.
  static Future<AllocationProbe> connect() async {
    var info = await dev.Service.getInfo();
    if (info.serverUri == null) {
      info = await dev.Service.controlWebServer(enable: true);
    }
    final http = info.serverUri;
    if (http == null) {
      throw StateError('the VM service is not serving (Service.getInfo and '
          'controlWebServer gave no URI) -- is this a --profile run?');
    }
    final ws = http.replace(
        scheme: 'ws',
        path: http.path.endsWith('/') ? '${http.path}ws' : '${http.path}/ws');
    final service = await vms_io.vmServiceConnectUri(ws.toString());
    final isolateId = dev.Service.getIsolateId(iso.Isolate.current);
    if (isolateId == null) {
      await service.dispose();
      throw StateError('Service.getIsolateId(Isolate.current) is null');
    }
    // The first RPC proves the connection; a refused one throws here, not
    // in the middle of a measurement.
    await service.getAllocationProfile(isolateId);
    return AllocationProbe._(service, isolateId);
  }

  /// Two RPCs, not one -- the meter's own finding: `gc: true` and `reset:
  /// true` on one call left the accumulators non-zero.
  Future<void> reset() async {
    await _service.getAllocationProfile(_isolateId, gc: true);
    await _service.getAllocationProfile(_isolateId, reset: true);
  }

  /// `instancesAccumulated` since [reset], per class, for the probed
  /// libraries. Keys are `<library uri> <class name>`.
  ///
  /// **Call this at most once per [reset].** The meter this file follows
  /// measured a second read against the same epoch reading near-zero for
  /// every class rather than the true accumulated count (failure mode 3 in
  /// `vm_allocation_meter.dart`), because the first read re-bases the
  /// baseline to itself.
  Future<Map<String, int>> read() async {
    final profile = await _service.getAllocationProfile(_isolateId);
    final out = <String, int>{};
    for (final m in profile.members ?? const <vms.ClassHeapStats>[]) {
      final cls = m.classRef;
      if (cls == null) continue;
      final lib = cls.library?.uri ?? '';
      if (!kProbedLibraryPrefixes.any(lib.startsWith)) continue;
      final n = m.instancesAccumulated ?? 0;
      if (n == 0) continue;
      out['$lib ${cls.name}'] = n;
    }
    return out;
  }

  Future<void> dispose() => _service.dispose();
}
