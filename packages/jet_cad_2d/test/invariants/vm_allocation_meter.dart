// A thin wrapper around the Dart VM's own allocation profiler, shared by
// every allocation-measuring test in this suite (`query_allocation_test.dart`
// and the un-skipped tree test in `test/index/packed_rtree_test.dart`).
//
// **Mechanism, chosen deliberately over the alternatives:**
//
// - `ProcessInfo.currentRss` deltas (`dart:io`) were tried first, since the
//   task brief suggested them as a fallback and they need no dependency at
//   all. Measured directly: a synthetic loop that allocates nothing showed a
//   *larger* RSS delta than one that allocates a `Vector2` on every one of
//   five million iterations (753 KB vs 82 KB, in one run). RSS is a
//   whole-process, page-granular metric driven by the OS and the GC's own
//   scavenge/decommit behaviour, not by how many bytes the mutator actually
//   asked for -- it cannot resolve a per-call budget measured in tens of
//   bytes. Rejected.
// - `dart:developer`'s `Service` plus `package:vm_service`'s
//   `getAllocationProfile`, the same mechanism a prior review used by hand
//   (see the Task 17 brief) to find `Vector2` and `Function` at roughly
//   0.0023 instances per pick. This is what [AllocationMeter] wraps.
//
// **Getting it to run under plain `dart test`, no flags:** `getInfo()` off
// the box reports no service URI unless the process was started with
// `--enable-vm-service` or `--observe`, which would make this gate the kind
// nobody runs by hand. `dart:developer`'s `Service.controlWebServer(enable:
// true)` starts the service *at runtime*, from inside the very isolate under
// test, with no such flag -- confirmed by inspecting `serverUri` before and
// after the call under an ordinary `dart test test/invariants/...` run. That
// is the trick this file relies on.
//
// **Two failure modes found and designed around while building this:**
//
// 1. `getAllocationProfile(reset: true)` does not retroactively zero a
//    class's *already-promoted, still-live* instances -- a document built
//    entirely before `reset` can still report thousands of "accumulated"
//    instances of its own record types afterward, with zero further calls in
//    between. `gc: true` on the surrounding calls fixes it in isolation, but
//    was measured to occasionally hang this specific harness for the full
//    30-second test timeout when issued back-to-back on this isolate -- a
//    hang is worse than a flaky number, so `gc` is not used here at all.
//    The workaround is `_watchedClasses`: every class this file (or its
//    caller) asks about is one the query methods under test do not build in
//    bulk anywhere else (a `SpatialIndex`'s own document, entity, and
//    geometry storage never touch `Vector2` or `Transform2`), so the
//    stale-promotion artefact never has anything to trigger on.
// 2. Summing `accumulatedSize`/`instancesAccumulated` across *every* class
//    the profile reports -- the shape of the task brief's own sample
//    assertion -- was measured to carry 20-70 MB of noise from a single
//    reset-then-read round trip with *no* work done in between at all
//    (`_List`, `_OneByteString`, `_Map`, `_Double`, `Code`/`Instructions`
//    from ongoing JIT tiering, `Context`/`_Closure` from the async
//    machinery ferrying the RPC itself). That noise floor is four to five
//    orders of magnitude past the tens-of-bytes budget this suite cares
//    about, so a whole-heap sum cannot resolve it at any iteration count
//    this suite can afford to run. The fix is the same one as above: name a
//    small set of classes the code path is not expected to touch, and sum
//    only those.
// 3. **`getAllocationProfile` without `reset` is not a repeatable snapshot
//    read.** Calling it a second time, with no work done in between, was
//    measured to report near-zero for every class -- as if the *first* call
//    had silently re-based the "since reset" baseline to itself. Confirmed
//    directly with an order-swap: whichever of two back-to-back reads runs
//    first sees the true accumulated count; whichever runs second reads
//    near-zero, regardless of which named classes either one asks about.
//    This was the actual cause of what first looked like several different,
//    increasingly strange escape-analysis failures while calibrating a
//    depth-bound budget for `pickInto`/`snapInto` in the task-17 report's
//    round-2 section -- every mutation *had* materialized correctly (and
//    was confirmed to, via a debug read of the mutated value itself), but
//    the *second* of two `accumulatedInstances` calls made against the same
//    `reset` epoch was reading a baseline the first call had already reset
//    out from under it. [accumulatedInstances] enforces this at runtime
//    (see its own doc comment) rather than leaving it as a trap the next
//    caller has to already know about.
//
// **What a clean reading here proves, and what it does not:** a near-zero
// count for a named class means the JIT, for *this* run, on *this* machine,
// did not observe that class being instantiated on the timed path -- it is
// evidence the code is allocation-free in the configuration actually tested,
// not a proof that hold under AOT or that no allocation of some *other,
// unwatched* class occurred. See each call site's own comment for which
// classes it watches and why those are the ones that would move if the
// method under test regressed.
library;

import 'dart:developer' as dev;
import 'dart:isolate' as iso;

import 'package:vm_service/vm_service.dart' as vm_service;
import 'package:vm_service/vm_service_io.dart' as vm_service_io;

/// A live connection to this isolate's own VM allocation profiler.
///
/// [connect] returns `null`, rather than throwing, when the service cannot
/// be started or reached -- a sandboxed CI runner that blocks the loopback
/// socket a `dart:developer` web server needs is a real environment, and a
/// test built on this class is expected to skip itself with a stated reason
/// in that case rather than report a false pass. See `query_allocation_test
/// .dart` and `packed_rtree_test.dart` for that skip path.
class AllocationMeter {
  AllocationMeter._(this._service, this._isolateId);

  final vm_service.VmService _service;
  final String _isolateId;

  /// Guards against the trap documented in this file's failure mode 3:
  /// a second [accumulatedInstances] call against the same [reset] epoch
  /// silently reads near-zero rather than the true count. Set by
  /// [accumulatedInstances], cleared by [reset].
  bool _consumedSinceReset = false;

  static Future<AllocationMeter?> connect() async {
    try {
      final info = await dev.Service.controlWebServer(enable: true);
      final serverUri = info.serverUri;
      if (serverUri == null) return null;
      // vm_service_io wants a ws:// URI; controlWebServer hands back the
      // http:// one the DevTools link is built from.
      final wsUri = Uri(
        scheme: 'ws',
        host: serverUri.host,
        port: serverUri.port,
        path: '${serverUri.path}ws',
      ).toString();
      final service = await vm_service_io.vmServiceConnectUri(wsUri);
      // `Isolate.current`, not `getVM().isolates.first`: this isolate is not
      // guaranteed to be the only or the first one the service lists, and
      // asking for *this* isolate's own id directly is exact where picking
      // "the first one" would only usually be right.
      final isolateId = dev.Service.getIsolateId(iso.Isolate.current);
      if (isolateId == null) {
        await service.dispose();
        return null;
      }
      // Round-trip once before handing this back: a socket that connects
      // but whose first real RPC hangs or errors is exactly the case a
      // caller needs to fall back on, not discover mid-measurement.
      await service.getAllocationProfile(isolateId);
      return AllocationMeter._(service, isolateId);
    } catch (_) {
      return null;
    }
  }

  /// Settles the heap (one full GC, no reset) and then zeroes the
  /// accumulator. Everything a watched class allocates from this point until
  /// [accumulatedInstances] is called next counts.
  ///
  /// The settle step matters more than it looks: `getAllocationProfile(reset:
  /// true)` alone does not retroactively zero a class's already-live
  /// instances (see failure mode 1 in this file's doc comment) -- and that
  /// is not scoped to the current test. Every test in a file shares one
  /// isolate, so an object left behind by an *earlier* test can still be
  /// attributed to "since reset" here, whenever the VM's own bookkeeping
  /// next gets around to scanning it. Measured directly while building
  /// this: a second test in the same file reading a clean `Vector2` class it
  /// never touches at ~10 instances per call, entirely explained by the
  /// *previous* test's now-garbage `Vector2`s, and settling immediately
  /// before every reset -- not once at file start -- was what made both
  /// tests read near zero independently.
  ///
  /// Two separate RPCs, not one `getAllocationProfile(reset: true, gc:
  /// true)` call: back-to-back `gc: true` calls on this isolate were
  /// measured, while prototyping this file, to occasionally hang for the
  /// full 30-second test timeout against a heavier fixture. A single settle
  /// call immediately followed by a single, separate reset call was not
  /// observed to hang in the same testing (including against the
  /// heaviest fixtures this suite uses) and is what this method does; do not
  /// add a second settle call in front of it "for extra safety" -- that is
  /// closer to the shape that hung.
  Future<void> reset() async {
    await _service.getAllocationProfile(_isolateId, gc: true);
    await _service.getAllocationProfile(_isolateId, reset: true);
    _consumedSinceReset = false;
  }

  /// Instances accumulated since the last [reset], per name in
  /// [classNames].
  ///
  /// Summed across every class on the heap sharing that name, rather than
  /// picking one: `Aabb2` is defined both by this package and, unused but
  /// still loaded, by `package:vector_math` (hidden from every import in
  /// this codebase, but not unloaded from the VM's own class table). Both
  /// are expected to sit at zero on every path this file measures, so
  /// summing them is harmless when the reading is clean and conservative
  /// (counts, rather than hides, a hit) when it is not.
  ///
  /// **Call this at most once per [reset].** A second call against the
  /// same epoch was measured to read near-zero for every class rather than
  /// the true accumulated count -- see this file's doc comment, failure
  /// mode 3. Enforced here rather than left as a trap: a caller that needs
  /// several classes' worth of budgets after one measured loop must request
  /// the union of every class it cares about in a single call, then apply
  /// different thresholds to the entries of the one returned map -- see
  /// `query_allocation_test.dart`'s `pickInto`/`snapInto` tests for the
  /// pattern.
  Future<Map<String, int>> accumulatedInstances(
    Set<String> classNames,
  ) async {
    if (_consumedSinceReset) {
      throw StateError(
        'AllocationMeter.accumulatedInstances() was already called once '
        'since the last reset() -- a second call in the same epoch reads '
        'near-zero instead of the true accumulated count (see this file\'s '
        'doc comment, failure mode 3), so this would silently produce a '
        'false pass rather than a real measurement. Request every class '
        'this measurement needs in one call instead.',
      );
    }
    _consumedSinceReset = true;
    final profile = await _service.getAllocationProfile(_isolateId);
    final out = <String, int>{for (final name in classNames) name: 0};
    for (final member
        in profile.members ?? const <vm_service.ClassHeapStats>[]) {
      final name = member.classRef?.name;
      if (name == null || !classNames.contains(name)) continue;
      out[name] = (out[name] ?? 0) + (member.instancesAccumulated ?? 0);
    }
    return out;
  }

  Future<void> dispose() => _service.dispose();
}

/// The reason string every allocation test in this suite skips with when
/// [AllocationMeter.connect] returns `null`. One shared string, so a run
/// that cannot reach the VM service reports the same, greppable line from
/// every test it skips rather than a slightly different one per call site.
const String vmServiceUnavailableReason =
    'the VM allocation profiler could not be started or reached from this '
    'process (Service.controlWebServer failed, or its first RPC did not '
    'round-trip) -- this environment likely blocks the loopback socket '
    'dart:developer opens for it. Run under an environment that allows a '
    'local socket; no CLI flag works around this, since the harness starts '
    'the service itself at runtime rather than requiring --enable-vm-service.';
