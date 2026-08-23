# Task 7 report: `AllocationMeter` moves, and the probe decides whether it works

**Result: RED. Reverted in full per the pre-committed stop clause. Section 3 is dropped.**

## What was done, in order

### Step 1 — move the file, unchanged

```sh
cd packages/jet_cad_2d
git mv test/invariants/vm_allocation_meter.dart lib/src/testing/allocation_meter.dart
```

Contents traveled verbatim except the one required correction: the header said
"Two separate failure modes found and designed around" while enumerating
three. Corrected to "Three failure modes found and designed around while
building this". (This edit, and the move, were undone in the Step 7b revert
below.)

### Step 2 — export it and promote the dependency

`lib/testing.dart` gained:

```dart
export 'src/testing/allocation_meter.dart';
```

`pubspec.yaml` moved `vm_service: ^15.2.0` from `dev_dependencies` into
`dependencies`.

**Cost, stated plainly:** a Dart dependency resolves at package level, not
library level. Promoting `vm_service` means every consumer of `jet_cad_2d`
now resolves `vm_service` in its dependency graph, even though
`jet_cad_2d.dart` (the main library) does not export `testing.dart` and never
touches it. Tree shaking removes the unused code from a built application;
what is paid is dependency-tree weight, not runtime weight. (This edit was
reverted below.)

### Step 3 — re-point the three call sites

Replaced the relative import with `import 'package:jet_cad_2d/testing.dart';`
in:
- `test/invariants/query_allocation_test.dart` (was `import 'vm_allocation_meter.dart';`)
- `test/invariants/text_paint_allocation_test.dart` (was `import 'vm_allocation_meter.dart';`)
- `test/index/packed_rtree_test.dart` (was `import '../invariants/vm_allocation_meter.dart';`)

Also normalized import ordering (merged the new package import into the
existing sorted package-import block rather than leaving a separate group),
and updated stale in-comment filename references
(`vm_allocation_meter.dart` → `allocation_meter.dart` / the new path) and one
stale "two failure modes" comment mirror in `query_allocation_test.dart`'s
header, to keep the surrounding documentation accurate. (All reverted below.)

### Step 4 — prove the move changed nothing (gate, before touching Flutter)

```sh
cd packages/jet_cad_2d && CI=true dart pub get
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Verbatim tail of `dart test` output:

```
00:02 +775: test/index/packed_rtree_test.dart: search allocates nothing after the first call
...
00:02 +779: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
...
00:03 +792: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +793: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +793: All tests passed!
```

`dart analyze`:
```
Analyzing jet_cad_2d...
No issues found!
```

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 112 files (0 changed) in 0.20 seconds.
```

**Gate green.** 793 tests passed, including every allocation test using the
relocated meter through its new import path. This establishes that a red
result in Step 6 is about `flutter test`, not about the move.

### Step 5 — write the probe

Created `packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart`
exactly as specified in the task brief (verbatim from the brief's Step 5
code block — `ProbeWitness`, `kProbeAllocations = 100000`, `connect()` /
`reset()` / `accumulatedInstances({'ProbeWitness'})`, 90% threshold, 60s
timeout).

### Step 6 — run the probe

Exact invocation:

```sh
cd packages/jet_cad_2d_flutter && CI=true dart pub get
CI=true flutter test test/invariants/allocation_meter_probe_test.dart
```

**Verbatim output:**

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart
00:00 +0: the allocation profiler connects and counts under flutter test
00:00 +0 -1: the allocation profiler connects and counts under flutter test [E]
  AllocationMeter.connect() returned null under flutter test. The stop clause fires: revert the file move, the three import re-points, and the vm_service promotion in packages/jet_cad_2d/pubspec.yaml, record this transcript, and drop Section 3 of the plan.
  package:matcher                                        fail
  test/invariants/allocation_meter_probe_test.dart 32:7  main.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart: the allocation profiler connects and counts under flutter test
```

**RED.** `AllocationMeter.connect()` returned `null` under `flutter test`.
The probe never got as far as the positive control (the 100,000-instance
`ProbeWitness` retention loop and the 90% threshold check were never
reached, because `connect()` itself failed first). This means
`dart:developer`'s `Service.controlWebServer(enable: true)` — the mechanism
the meter relies on to start the VM service at runtime from inside the
isolate under test, with no launch flag — does not produce a reachable
service URI (or the isolate id / first RPC round-trip failed) inside the
`flutter_tester` engine binary that backs `flutter test`, under the
sandboxed conditions of this run. `connect()`'s own `catch (_) { return
null; }` swallows the specific underlying reason, by design (see the
meter's own doc comment on why it prefers a stated skip to a thrown
exception) — so this transcript is the full extent of what is knowable
from this run: the mechanism proven under plain `dart test` does not carry
over to `flutter test`.

### Step 7b — revert in full (the stop clause fired)

Per the brief:

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad
git checkout -- packages/jet_cad_2d/pubspec.yaml
```

Then, rather than `git mv` the modified file back (which would have carried
forward the in-place "three failure modes" text edit), the safer path to a
byte-exact revert was used: `git reset` to unstage the rename, followed by
`git checkout --` on every touched tracked file (`lib/testing.dart`,
`pubspec.yaml`, `test/index/packed_rtree_test.dart`,
`test/invariants/query_allocation_test.dart`,
`test/invariants/text_paint_allocation_test.dart`,
`test/invariants/vm_allocation_meter.dart` — the last of these restores the
file at its original path from the index/HEAD), then removing the two
now-untracked files at the new locations
(`packages/jet_cad_2d/lib/src/testing/allocation_meter.dart` and the probe
file `packages/jet_cad_2d_flutter/test/invariants/allocation_meter_probe_test.dart`).
This reverts every one of: the file move, the header's failure-mode-count
correction, the three import re-points (including the incidental comment and
import-ordering touch-ups made alongside them), the `testing.dart` export
line, and the `pubspec.yaml` dependency promotion — restoring the tree to
exactly its pre-task committed state (`git diff --stat` against HEAD is
empty; `git status` reports "nothing to commit, working tree clean"). The
probe file was deleted.

### Re-verification after revert

Engine suite:
```sh
cd packages/jet_cad_2d && CI=true dart test
```
Tail:
```
00:03 +792: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +793: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +793: All tests passed!
```
`dart analyze`: `No issues found!`
`dart format --output=none --set-exit-if-changed .`: `Formatted 112 files (0 changed) in 0.20 seconds.`

Flutter suite:
```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test
```
Tail:
```
00:04 +304: All tests passed!
```
(304 tests passed, 1 skipped — consistent with the pre-existing suite; no
change in shape from before the task started.)
`flutter analyze`: `No issues found! (ran in 1.1s)`
`dart format --output=none --set-exit-if-changed .`: `Formatted 54 files (0 changed) in 0.10 seconds.`

`git status`: clean. `git diff --stat`: empty. No untracked files. No
`analysis_options.yaml` modification appeared at any point in either
package's `pub get` runs in this task.

## What Plan 3g now knows that it did not know before

The mechanism `AllocationMeter` relies on — `dart:developer`'s
`Service.controlWebServer(enable: true)` starting the VM service at runtime,
from inside the isolate under test, with no launch flag — works under plain
`dart test` (proven previously, and re-proven here by the green Step 4 gate)
but **does not work under `flutter test`**, whose tests run inside the
`flutter_tester` engine binary. This was previously an unverified assumption
(Plan 3f recorded the Flutter-side allocation question as unmeasurable on
exactly this assumption); it is now a measured fact, with a transcript.

Consequently: **Plan 3g's central risk — a lazily-populated picture cache
that could be blind to a cache-miss regression, the same shape Plan 3e
already found `VerticesDrawSink.debugCapacityVertices` blind to — cannot be
gated by a frame-path VM-allocation-profiler assertion inside
`jet_cad_2d_flutter`'s test suite, because the profiler cannot be reached
from that test tree at all.** The gate Plan 3g needs must be a **command-time
assertion** instead (an explicit invariant checked in code — e.g. an
assertion on the cache's own fill/hit bookkeeping, or a counter the cache
exposes and a test reads directly — rather than an out-of-band allocation
count). This is the same lesson Plan 3e already learned from the *other*
direction: the frame-path allocation gate on `VerticesDrawSink` stayed green
through the exact mutation that should have broken it, and it was a
command-time assertion (not an allocation reading) that actually proved the
cache-fill path eager. This task independently confirms, from the
instrumentation side rather than the mutation-testing side, that the
allocation-profiler approach is not available as a tool in
`jet_cad_2d_flutter` at all — so Plan 3g does not need to spend time
attempting it and rediscovering this.

No lazy cache-miss path exists yet in this repository to instrument in any
case — the fill path is explicitly eager (`draft_painter.dart:686-690`) — so
this task does not (and should not) write that gate. It answers the
narrower, prior question: which instrument is available for whichever gate
Plan 3g does write, and the answer is: not this one, inside
`jet_cad_2d_flutter`.

## Commit

None. The task ends with a full revert, not a commit — the working tree is
identical to the state at task start (`git diff --stat` against HEAD is
empty).

## Why the probe was red

A follow-up diagnostic was requested to name the cause behind the red probe,
since `AllocationMeter.connect()`'s `catch (_) { return null; }` swallows the
real reason by design. A throwaway file,
`packages/jet_cad_2d_flutter/test/invariants/service_probe_scratch_test.dart`,
called `dev.Service.controlWebServer(enable: true)` directly, with no
try/catch, and printed the result. It needed no pubspec change: `vm_service`
is a dev dependency of the workspace member `jet_cad_2d`, and this pub
workspace (`resolution: workspace`) resolves one shared `package_config.json`
across all members, so the import resolved and compiled from
`jet_cad_2d_flutter` without being declared in that package's own
`pubspec.yaml` (the analyzer surfaced only an Information-level
`depend_on_referenced_packages` hint, not a resolution failure — confirmed
empirically by running the test, not just by reading the lint).

Command:
```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/service_probe_scratch_test.dart
```

Verbatim output:
```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.1 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/service_probe_scratch_test.dart
00:00 +0: diagnose controlWebServer under flutter test
ServiceProtocolInfo: Dart VM Service Protocol v4.21
serverUri: null
isolateId: isolates/5126513748590131 (null means the meter treats this as a failure path too)
DIAGNOSIS: serverUri is null -- the web server itself did not start / did not report a URI.
00:00 +1: All tests passed!
```

**The key line:** `serverUri: null`.

**What the diagnostic actually measured, and nothing more.** Two facts:
`controlWebServer` returned a non-null `ServiceProtocolInfo` whose
`serverUri` field was `null`, and `getIsolateId` resolved a real isolate id.
The print statement in the scratch file itself posed the honest question this
leaves open: *the web server did not start, or it started but did not report
a URI* — the transcript does not distinguish those two cases. The non-null
isolate id does not help decide between them either: `getIsolateId` is an
in-process lookup against the current isolate's own identity; it does not
touch the HTTP layer `controlWebServer` is responsible for, so its succeeding
is not evidence about whether that HTTP layer came up.

**Original conclusion in this section (superseded — recorded here rather
than deleted).** The first version of this section went further than the
above and stated: *"the VM service web server does not start inside
`flutter_tester` at all ... This reads as a platform fact about the
`flutter_tester` engine binary ... Nothing in this transcript suggests a flag
or an alternate URI would help."* That was an overreach the evidence did not
support: nothing in the two measured facts rules in or out *why* `serverUri`
was null, and "platform fact, no flag would help" is precisely the claim the
transcript cannot decide. It was corrected on review, below.

**The corrected cause, confirmed directly rather than taken on anyone's
word.** `flutter test` launches the `flutter_tester` engine binary with
`--disable-vm-service` on its command line. Verified by running an existing,
unrelated test file and capturing the live process:

```sh
cd packages/jet_cad_2d_flutter
CI=true flutter test test/draw_sink_test.dart > /tmp/flutter_test_probe.log 2>&1 &
# polled `ps aux | grep -i flutter_tester` every 0.2s while it ran
```

Verbatim captured process line:
```
ahmeturel        31580  11.7  0.3 435627904 109472   ??  RN   12:44PM   0:00.10 /opt/homebrew/Caskroom/flutter/3.27.3/flutter/bin/cache/artifacts/engine/darwin-x64/flutter_tester --disable-vm-service --enable-checked-mode --verify-entry-points --enable-software-rendering --skia-deterministic-rendering --enable-dart-profiling --non-interactive --use-test-fonts --disable-asset-fonts --packages=/Users/ahmeturel/Projects/oss/jet-cad/.dart_tool/package_config.json --flutter-assets-dir=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/build/unit_test_assets /var/folders/cy/hzy04mbx3lggs3z69x7_1c4m0000gn/T/flutter_tools.sSl8sQ/flutter_test_listener.c4mxaJ/listener.dart.dill
```

`--disable-vm-service` is present. That is the cause: the server never starts
because it is switched off at process launch, before any in-isolate call
(`controlWebServer` included) runs. This is a flag effect, not a capability
`flutter_tester` lacks — the earlier "platform fact" framing is withdrawn.

**Which future Plan 3g is in, corrected.** Not cleanly either of the two
named in the request. The flag-driven cause makes the *second* future's
premise ("a connection problem; a flag or different URI might reach it")
directionally plausible and unexplored — `flutter test --start-paused`, or
any invocation that does not pass `--disable-vm-service`, is a route nobody
has tried and this task did not rule out. But the practical verdict for Plan
3g is unchanged: `--disable-vm-service` is passed by the `flutter_tester`
process `flutter test` itself launches, not by anything in this repository's
control on a per-test basis. Even if some invocation avoided the flag, it
would not be one an ordinary `flutter test` run (or CI's `flutter test`)
exercises, so it could not serve as an always-on gate the way
`query_allocation_test.dart`'s meter serves the engine suite. Plan 3g's
cache-miss risk still needs a command-time assertion rather than a
frame-path allocation gate — that verdict does not change — but it now rests
on "the flag `flutter test` passes closes this off," not on "the mechanism
is impossible under this runner," and the difference matters if a future
plan ever controls its own `flutter_tester` invocation directly.

The scratch diagnostic file and the `/tmp/flutter_test_probe.log` capture
file were both deleted immediately after use. Tree re-verified clean:
`git status --short` empty, `git diff --stat b1e9ec1..HEAD` empty,
`git log --oneline -1` still `b1e9ec1`.
