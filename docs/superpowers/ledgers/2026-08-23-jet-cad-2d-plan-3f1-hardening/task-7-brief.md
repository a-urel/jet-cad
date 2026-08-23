## Task 7: `AllocationMeter` moves, and the probe decides whether it works

**Files:**
- Move: `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart` → `packages/jet_cad_2d/lib/src/testing/allocation_meter.dart`
- Modify: `packages/jet_cad_2d/lib/testing.dart`
- Modify: `packages/jet_cad_2d/pubspec.yaml`
- Modify: `packages/jet_cad_2d/test/invariants/query_allocation_test.dart:97`, `packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart:19`, `packages/jet_cad_2d/test/index/packed_rtree_test.dart:7`
- Create: `packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks. This task is independent of Sections 1 and 2 and could run first.
- Produces: `package:jet_cad_2d/testing.dart` exports `AllocationMeter`.

**The order is forced.** Dart cannot import another package's `test/`
directory, so the probe cannot run until the meter has moved. Move, re-point,
prove the engine suite still green, *then* probe — so a red probe is
unambiguously about `flutter test` and not about the move.

**The stop clause is pre-committed and binding.** If `connect()` returns null,
or the positive control reads below 90%, then **revert the file move, the three
import re-points, and the `pubspec.yaml` promotion of `vm_service` from
`dev_dependencies` to `dependencies`**, record the finding with its transcript,
and drop Section 3. Sections 1 and 2 do not depend on the meter. Do not
negotiate with a red probe; do not weaken the threshold to make it pass.

- [ ] **Step 1: Move the file, unchanged**

```sh
cd packages/jet_cad_2d
git mv test/invariants/vm_allocation_meter.dart lib/src/testing/allocation_meter.dart
```

The contents travel verbatim, including the long header on the three failure
modes it designs around. While the file is open, its header says "Two separate
failure modes found and designed around" and then enumerates three; correct the
count.

- [ ] **Step 2: Export it and promote the dependency**

In `lib/testing.dart`, add below the existing export:

```dart
export 'src/testing/allocation_meter.dart';
```

In `pubspec.yaml`, move `vm_service: ^15.2.0` from `dev_dependencies` into
`dependencies`. **State the cost in the task report rather than glossing it:** a
Dart dependency resolves at package level, not library level, so every consumer
of `jet_cad_2d` now resolves `vm_service` even though `jet_cad_2d.dart` does
not export `testing.dart`. Tree shaking removes the unused code from a built
application; what is paid is dependency-tree weight.

- [ ] **Step 3: Re-point the three call sites**

Replace the relative import in each with the package import:

```dart
import 'package:jet_cad_2d/testing.dart';
```

- `test/invariants/query_allocation_test.dart:97` (was `import 'vm_allocation_meter.dart';`)
- `test/invariants/text_paint_allocation_test.dart:19` (was `import 'vm_allocation_meter.dart';`)
- `test/index/packed_rtree_test.dart:7` (was `import '../invariants/vm_allocation_meter.dart';`)

If a file already imports `package:jet_cad_2d/jet_cad_2d.dart` and now has two
package imports, that is fine — `testing.dart` is deliberately not exported
from the main library.

- [ ] **Step 4: Prove the move changed nothing**

```sh
cd packages/jet_cad_2d && CI=true dart pub get
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Expected: the whole engine suite green, including the allocation tests that use
the meter. **This gate exists so a red probe in Step 6 cannot be blamed on the
move.** If anything here is red, fix it before going near the probe.

- [ ] **Step 5: Write the probe**

Create `packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart`:

```dart
// Does the VM allocation profiler work under `flutter test`?
//
// `AllocationMeter` relies on `dart:developer`'s
// `Service.controlWebServer(enable: true)` to start the VM service at runtime,
// from inside the isolate under test, with no launch flag. That was verified
// under plain `dart test` when the meter was written. It has never been
// verified under `flutter test`, whose tests run inside the `flutter_tester`
// engine binary — and Plan 3f recorded the Flutter side's allocation question
// as unmeasurable on exactly that assumption.
//
// Connecting is not the bar. A meter that connects and reports zero is worse
// than no meter, because it reports green. So this asks two questions.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/testing.dart';

/// Allocated only by this file, so nothing else on the heap can be attributed
/// to it. The meter's own guidance is to watch classes the path under test does
/// not build in bulk; here the path under test *is* the allocation.
class ProbeWitness {
  ProbeWitness(this.serial);
  final int serial;
}

const int kProbeAllocations = 100000;

void main() {
  test('the allocation profiler connects and counts under flutter test',
      () async {
    final meter = await AllocationMeter.connect();
    if (meter == null) {
      fail('AllocationMeter.connect() returned null under flutter test. '
          'The stop clause fires: revert the file move, the three import '
          're-points, and the vm_service promotion in '
          'packages/jet_cad_2d/pubspec.yaml, record this transcript, and drop '
          'Section 3 of the plan.');
    }

    await meter.reset();

    // The allocations must ESCAPE. An allocation the JIT can prove dead may
    // never happen, and a healthy meter would then read zero and be blamed
    // for it. Retaining every instance in a list the compiler cannot see
    // through is what makes this a positive control rather than a coin flip.
    final retained = <ProbeWitness>[];
    for (var i = 0; i < kProbeAllocations; i++) {
      retained.add(ProbeWitness(i));
    }
    expect(retained.length, kProbeAllocations);

    // At most one call per reset -- see the meter's failure mode 3.
    final counts = await meter.accumulatedInstances({'ProbeWitness'});
    final seen = counts['ProbeWitness'] ?? 0;

    expect(seen, greaterThanOrEqualTo((kProbeAllocations * 0.9).round()),
        reason: 'the meter connected but under-counted a known allocation: '
            'saw $seen of $kProbeAllocations. The stop clause fires.');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
```

- [ ] **Step 6: Run the probe and read the result honestly**

```sh
cd packages/jet_cad_2d_flutter && CI=true dart pub get
CI=true flutter test test/invariants/allocation_meter_probe_test.dart
```

Paste the **verbatim** output into the task report, green or red. This is the
one result in the plan whose value does not depend on which way it goes.

- [ ] **Step 7a: If GREEN — commit and report**

```bash
git add packages/jet_cad_2d/lib/src/testing/allocation_meter.dart \
        packages/jet_cad_2d/lib/testing.dart \
        packages/jet_cad_2d/pubspec.yaml \
        packages/jet_cad_2d/test/invariants/query_allocation_test.dart \
        packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart \
        packages/jet_cad_2d/test/index/packed_rtree_test.dart \
        packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart
git commit -m "test: the allocation meter is reachable from the Flutter package

Dart cannot import another package's test/ directory, so
jet_cad_2d_flutter had no allocation instrument except
VerticesDrawSink.debugCapacityVertices -- which Plan 3e proved blind to a
lazily populated cache, exactly the shape of Plan 3g's picture cache.

Moves the meter to lib/src/testing/ behind the existing lib/testing.dart,
whose own doc comment already argues this case for generate_document.dart.
vm_service is promoted from a dev dependency to a real one: dependency
resolution is package-level, so every consumer now resolves it.

The probe asks two questions, because a meter that connects and reports
zero is worse than none: it connects, and it counts an escaping known
allocation to within 10%."
```

Report explicitly that Plan 3g may now write its own trap-5 gate against its
own cache, on an instrument proven to count. **Do not write that gate here** —
there is no lazy cache-miss path in this repository to instrument; the fill
path is explicitly eager and says so at `draft_painter.dart:686-690`.

- [ ] **Step 7b: If RED — revert in full and report**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git checkout -- packages/jet_cad_2d/pubspec.yaml
git mv packages/jet_cad_2d/lib/src/testing/allocation_meter.dart \
       packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart
```

Then restore the three relative imports, remove the `testing.dart` export line,
delete the probe file, and re-run both suites to confirm the tree is back where
it started. (`git checkout` on `pubspec.yaml` is reverting a whole file to its
committed state, not reverting a mutation — the mutation rule does not apply.)

Record in the task report, and later in the results note: the verbatim probe
output, the exact `flutter test` invocation, and the conclusion that Plan 3g's
central risk must be gated by a command-time assertion rather than a frame-path
allocation gate — which is what actually proved fills eager in Plan 3e, after
the allocation gate stayed green through the mutation that should have broken
it.

---

