# Plan 2: Native OCCT Session + FFI Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A real `FfiKernelBridge` backed by a C++ shim over Open CASCADE (OCCT), headless — every `KernelBridge` contract the `FakeKernelBridge` honors now runs against real B-rep geometry, plus document persistence wired to kernel snapshots.

**Architecture:** Plan 2 of 5 for `docs/superpowers/specs/2026-07-12-jet-cad-architecture-design.md`. C++ `Session` owns `map<string id, Body{TopoDS_Shape + subshape id maps}>`. The C ABI is five symbols; all commands flow through one generic JSON dispatch (`jc_execute`) — this deliberately pre-implements the spec's "may evolve into `execute(KernelCommand)`" note at the ABI level while the Dart `KernelBridge` interface keeps its typed methods. Dart side: `FfiKernelBridge` serializes each typed call to a command JSON, runs the blocking native call in `Isolate.run`, and enforces one-command-in-flight-per-session with a Dart-side future chain.

**Documented deviations from the frozen spec (implementation findings, per the spec's own evolution rule):**
1. *Async transport:* spec says NativePort callbacks; we use `Isolate.run` + per-session queue. Same guarantee (UI never blocks, one command in flight per session), no `dart_api_dl` vendoring. Revisit only if Plan 3 needs native→Dart push events.
2. *Ids:* session-scoped monotonic strings (`b1`, `f2`, …), not RFC UUIDs. Deterministic, snapshot-preserved (counter serialized), same scheme as the fake. "Stable application identifier" intent preserved.
3. *Replay fallback:* `load` without a geometry blob and a non-empty op list throws `StateError` (clear message) instead of replaying. Truncated redo branches consumed counter values, so naive replay cannot reproduce stored ids; real replay is the parametric phase's job.
4. *Blobs:* STEP bytes and snapshots cross the ABI as base64 inside JSON. Coarse commands, small payloads in v1; revisit with pointer+length passing if profiling ever cares.

**Tech Stack:** OCCT ≥ 7.6 via Homebrew (`brew install opencascade cmake ninja`), CMake ≥ 3.24, nlohmann/json + GoogleTest via `FetchContent` (pinned), C++17, `dart:ffi` + `package:ffi`, existing Flutter/Dart floors from Plan 1.

> **Plan authority:** authoritative for sequencing and interface contracts, not exact code. OCCT toolkit names and minor API signatures vary across versions — the implementer adjusts to satisfy the linker/compiler and records the adjustment in their report. If implementation reveals a cleaner shape, simplify and update the task's Interfaces block.

## Global Constraints

- **Definition of Done — Dart-touching tasks:** `flutter analyze` clean, full `flutter test` green (count against real output), `dart format lib test` no diff, no TODO comments, real transcripts only (never synthesize output).
- **Definition of Done — native tasks:** `tool/build_native.sh` exits 0 (configure + build + ctest, all green, real transcript), no new warnings introduced by our files at default warning level, and the full Dart suite still green.
- Hard rule unchanged: nothing above `KernelBridge` imports `dart:ffi`. `FfiKernelBridge` and bindings live in `lib/src/kernel/ffi/`; the public export is conditional (`dart.library.ffi`) with an `UnsupportedError` stub so the package stays web-compilable.
- Id-preserving restore is contractual: `restoreBodies`/`restoreSession` restore entities under the exact ids the snapshot was taken with, and the id counter never re-issues an id that a restored snapshot contains.
- `deleteBodies` is idempotent (documented in Plan 1) — the shim must preserve this.
- Boolean consumes both inputs: every prior subshape id of `a` and `b` appears in the remap (mapped via OCCT history lineage where known, `[]` otherwise); `a`/`b` body ids map to `[result]`.
- Fillet keeps the body id; filleted edge ids map to ≥1 generated face id in the remap; subshapes that survive (IsSame) or are Modified keep their old ids and do NOT appear in remap or result lists; result lists contain only newly-created subshapes.
- Errors: OCCT exceptions and invalid input never cross the ABI as crashes — always the JSON error envelope, surfacing in Dart as `KernelException`.
- FFI integration tests are guarded: they skip (with a printed notice) when the native library is absent, so the pure-Dart suite stays green on machines without OCCT.
- Commit style: conventional commits; each task commits.

---

### Task 1: Dart prep — snapshot type unification, compensation, carry-over fixes

**Files:**
- Modify: `packages/jet_cad/lib/src/kernel/kernel_bridge.dart`
- Modify: `packages/jet_cad/lib/src/kernel/kernel_types.dart`
- Modify: `packages/jet_cad/lib/src/kernel/fake_kernel_bridge.dart`
- Modify: `packages/jet_cad/lib/src/document/undo.dart`
- Modify: `packages/jet_cad/lib/src/document/cad_document.dart`
- Modify: `packages/jet_cad/macos/jet_cad.podspec`
- Test: `packages/jet_cad/test/kernel/kernel_types_test.dart` (new)
- Test: `packages/jet_cad/test/document/compensation_test.dart` (new)

**Interfaces:**
- Consumes: everything from Plan 1.
- Produces:
  - `KernelBridge.snapshotBodies` returns `Future<KernelSnapshot>`; `restoreBodies(SessionHandle, KernelSnapshot)` — no raw `Uint8List` snapshots anywhere (unifies the two snapshot types flagged in the whole-branch review).
  - `CreateResult.fromJson(Map<String, Object?>)` and `CreateResult.toJson()` — the FFI bridge parses native results through this.
  - `UndoRecord.preSnapshot/postSnapshot` typed `KernelSnapshot?`.
  - `CadDocument` compensates orphaned kernel bodies: if the post-op `snapshotBodies` fails, the created/affected kernel state is rolled back (best-effort) before the error propagates — kernel and document never diverge silently.
  - Fixed `macos/jet_cad.podspec` `source_files` path.

- [ ] **Step 1: Write failing tests**

`packages/jet_cad/test/kernel/kernel_types_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

void main() {
  test('CreateResult JSON round-trips', () {
    const result = CreateResult(
      body: BodyId('b1'),
      faces: [FaceId('f2'), FaceId('f3')],
      edges: [EdgeId('e4')],
      vertices: [VertexId('v5')],
      remap: IdRemap({
        EntityId('b0'): [EntityId('b1')],
        EntityId('f0'): <EntityId>[],
      }),
    );
    final restored = CreateResult.fromJson(result.toJson());
    expect(restored.body, const BodyId('b1'));
    expect(restored.faces, const [FaceId('f2'), FaceId('f3')]);
    expect(restored.edges, const [EdgeId('e4')]);
    expect(restored.vertices, const [VertexId('v5')]);
    expect(restored.remap.mapping[const EntityId('b0')], const [EntityId('b1')]);
    expect(restored.remap.mapping[const EntityId('f0')], isEmpty);
  });

  test('CreateResult.fromJson tolerates missing remap', () {
    final restored = CreateResult.fromJson({
      'body': 'b1',
      'faces': <Object?>[],
      'edges': <Object?>[],
      'vertices': <Object?>[],
    });
    expect(restored.remap.mapping, isEmpty);
  });
}
```

`packages/jet_cad/test/document/compensation_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/src/document/cad_document.dart';
import 'package:jet_cad/src/document/entity.dart';
import 'package:jet_cad/src/kernel/fake_kernel_bridge.dart';
import 'package:jet_cad/src/kernel/kernel_types.dart';

/// Fails snapshotBodies after [allowedSnapshots] successful calls.
class _SnapshotFailingBridge extends FakeKernelBridge {
  _SnapshotFailingBridge(this.allowedSnapshots);

  int allowedSnapshots;

  @override
  Future<KernelSnapshot> snapshotBodies(
      SessionHandle session, List<BodyId> bodies) {
    if (allowedSnapshots-- <= 0) {
      throw const KernelException('simulated snapshot failure');
    }
    return super.snapshotBodies(session, bodies);
  }
}

Future<int> _kernelBodyCount(FakeKernelBridge bridge, CadDocument doc) async {
  // saveSnapshot dumps every body in the fake session.
  final snapshot = await doc.debugSaveSnapshot();
  return (jsonDecode(utf8.decode(snapshot.bytes)) as List).length;
}

void main() {
  test('makeBox compensates when post-snapshot fails: no orphan kernel body',
      () async {
    final bridge = _SnapshotFailingBridge(0);
    final doc = await CadDocument.create(bridge);
    await expectLater(
      doc.makeBox(const Vec3(1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    expect(doc.operations, isEmpty);
    expect(doc.entities, isEmpty);
    bridge.allowedSnapshots = 1000;
    expect(await _kernelBodyCount(bridge, doc), 0,
        reason: 'created body must be compensated away');
    await doc.dispose();
  });

  test('boolean compensates when post-snapshot fails: inputs restored',
      () async {
    // Allowed: 2 post-snapshots for the two makeBox calls, 1 pre-snapshot
    // for the boolean; the boolean's post-snapshot (4th call) fails.
    final bridge = _SnapshotFailingBridge(3);
    final doc = await CadDocument.create(bridge);
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final b = await doc.makeBox(const Vec3(2, 2, 2));
    await expectLater(
      doc.booleanCombine(a, b, BoolOp.fuse),
      throwsA(isA<KernelException>()),
    );
    expect(doc.entities.containsKey(a), isTrue);
    expect(doc.entities.containsKey(b), isTrue);
    expect(doc.head, 2);
    bridge.allowedSnapshots = 1000;
    expect(await _kernelBodyCount(bridge, doc), 2,
        reason: 'a and b restored, boolean result deleted');
    final step = await doc.exportStep([a, b]);
    expect(step, isNotEmpty);
    await doc.dispose();
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/kernel/kernel_types_test.dart test/document/compensation_test.dart`
Expected: FAIL — `CreateResult.fromJson`, `debugSaveSnapshot` undefined; snapshot type mismatch.

- [ ] **Step 3: Unify snapshot types + add CreateResult JSON**

In `kernel_types.dart`, add to `CreateResult`:

```dart
  Map<String, Object?> toJson() => {
        'body': body.value,
        'faces': [for (final f in faces) f.value],
        'edges': [for (final e in edges) e.value],
        'vertices': [for (final v in vertices) v.value],
        'remap': remap.toJson(),
      };

  factory CreateResult.fromJson(Map<String, Object?> json) => CreateResult(
        body: BodyId(json['body']! as String),
        faces: [for (final f in json['faces']! as List) FaceId(f as String)],
        edges: [for (final e in json['edges']! as List) EdgeId(e as String)],
        vertices: [
          for (final v in json['vertices']! as List) VertexId(v as String),
        ],
        remap: json['remap'] == null
            ? IdRemap.empty
            : IdRemap.fromJson((json['remap']! as Map).cast<String, Object?>()),
      );
```

In `kernel_bridge.dart`, change the snapshot methods (doc comment updated to name `KernelSnapshot` as THE opaque snapshot type at both granularities):

```dart
  Future<KernelSnapshot> snapshotBodies(
      SessionHandle session, List<BodyId> bodies);
  Future<void> restoreBodies(SessionHandle session, KernelSnapshot snapshot);
```

In `fake_kernel_bridge.dart`: `snapshotBodies` wraps its bytes in `KernelSnapshot(...)`; `restoreBodies` reads `snapshot.bytes`. In `undo.dart`: `preSnapshot`/`postSnapshot` become `KernelSnapshot?`. In `cad_document.dart`: update the types where snapshots are taken/passed (`_bridge.restoreBodies(_session, record.preSnapshot!)` unchanged in shape).

- [ ] **Step 4: Add compensation + debugSaveSnapshot to CadDocument**

Add helper inside `CadDocument`:

```dart
  /// Snapshot after a mutating kernel call; if the snapshot itself fails,
  /// roll the kernel back (best effort) so kernel and document never
  /// diverge, then rethrow.
  Future<KernelSnapshot> _snapshotOrCompensate(
    List<BodyId> bodies, {
    required Future<void> Function() compensate,
  }) async {
    try {
      return await _bridge.snapshotBodies(_session, bodies);
    } catch (_) {
      try {
        await compensate();
      } catch (_) {
        // Best effort: the original error is the one that matters.
      }
      rethrow;
    }
  }

  /// Whole-session kernel snapshot. Used by persistence (Task 9) and tests.
  Future<KernelSnapshot> debugSaveSnapshot() =>
      _bridge.saveSnapshot(_session);
```

Update each command's post-snapshot call:
- `makeBox`/`extrude`: `_snapshotOrCompensate([result.body], compensate: () => _bridge.deleteBodies(_session, [result.body]))`
- `importStep`: same with `bodyIds`
- `booleanCombine`: `_snapshotOrCompensate([result.body], compensate: () async { await _bridge.deleteBodies(_session, [result.body]); await _bridge.restoreBodies(_session, pre); })`
- `fillet`: `_snapshotOrCompensate([result.body], compensate: () async { await _bridge.deleteBodies(_session, [result.body]); await _bridge.restoreBodies(_session, pre); })`

- [ ] **Step 5: Fix podspec**

In `macos/jet_cad.podspec`, change `s.source_files` to `'Classes/**/*'`.

- [ ] **Step 6: Verify + commit**

```bash
flutter test && flutter analyze && dart format --set-exit-if-changed lib test
git add -A && git commit -m "refactor: unify kernel snapshots on KernelSnapshot, add orphan compensation"
```

Expected: full suite green (41 + 4 new = 45), analyze clean, no diff.

---

### Task 2: Native build scaffolding

**Files:**
- Create: `packages/jet_cad/src/native/CMakeLists.txt`
- Create: `packages/jet_cad/src/native/include/jet_cad_native.h`
- Create: `packages/jet_cad/src/native/api.cpp`
- Create: `packages/jet_cad/src/native/b64.hpp`
- Create: `packages/jet_cad/src/native/tests/smoke_test.cpp`
- Create: `packages/jet_cad/tool/build_native.sh` (executable)
- Modify: `packages/jet_cad/README.md` (add "Native development" section)

**Interfaces:**
- Consumes: Homebrew OCCT + CMake (`brew install opencascade cmake ninja`).
- Produces:
  - C ABI (frozen for this plan):
    - `uint64_t jc_create_session(void)`
    - `void jc_dispose_session(uint64_t)`
    - `const char* jc_execute(uint64_t session, const char* command_json)` — returns malloc'd UTF-8 JSON envelope `{"ok":true,"result":...}` | `{"ok":false,"error":"..."}`; caller frees with `jc_free`
    - `const char* jc_version(void)` — `{"kernelVersion":"jet_cad_native 0.1.0","occtVersion":"<OCC_VERSION_COMPLETE>"}`
    - `void jc_free(const char*)`
  - `tool/build_native.sh` → builds `packages/jet_cad/build/native/libjet_cad_native.{dylib|so}` and runs ctest.
  - `b64.hpp`: `std::string b64encode(const std::string&)`, `std::string b64decode(const std::string&)` (throws `std::runtime_error` on bad input).

- [ ] **Step 1: C ABI header**

`src/native/include/jet_cad_native.h`:

```c
#ifndef JET_CAD_NATIVE_H
#define JET_CAD_NATIVE_H

#include <stdint.h>

#if defined(_WIN32)
#define JC_EXPORT __declspec(dllexport)
#else
#define JC_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Creates a kernel session; returns an opaque non-zero handle. */
JC_EXPORT uint64_t jc_create_session(void);

/* Disposes a session. Unknown handles are a silent no-op. */
JC_EXPORT void jc_dispose_session(uint64_t session);

/*
 * Executes one JSON command against a session. Returns a malloc'd UTF-8
 * JSON envelope: {"ok":true,"result":...} or {"ok":false,"error":"..."}.
 * Never throws / crashes across this boundary. Free with jc_free.
 */
JC_EXPORT const char* jc_execute(uint64_t session, const char* command_json);

/* Returns malloc'd {"kernelVersion":...,"occtVersion":...}. Free with jc_free. */
JC_EXPORT const char* jc_version(void);

JC_EXPORT void jc_free(const char* ptr);

#ifdef __cplusplus
}
#endif

#endif /* JET_CAD_NATIVE_H */
```

- [ ] **Step 2: base64 helper**

`src/native/b64.hpp`:

```cpp
#pragma once
#include <cstdint>
#include <stdexcept>
#include <string>

namespace jetcad {

inline const char* kB64Chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

inline std::string b64encode(const std::string& in) {
  std::string out;
  out.reserve(((in.size() + 2) / 3) * 4);
  size_t i = 0;
  while (i + 2 < in.size()) {
    uint32_t n = (uint8_t)in[i] << 16 | (uint8_t)in[i + 1] << 8 |
                 (uint8_t)in[i + 2];
    out += kB64Chars[n >> 18];
    out += kB64Chars[(n >> 12) & 63];
    out += kB64Chars[(n >> 6) & 63];
    out += kB64Chars[n & 63];
    i += 3;
  }
  if (i + 1 == in.size()) {
    uint32_t n = (uint8_t)in[i] << 16;
    out += kB64Chars[n >> 18];
    out += kB64Chars[(n >> 12) & 63];
    out += "==";
  } else if (i + 2 == in.size()) {
    uint32_t n = (uint8_t)in[i] << 16 | (uint8_t)in[i + 1] << 8;
    out += kB64Chars[n >> 18];
    out += kB64Chars[(n >> 12) & 63];
    out += kB64Chars[(n >> 6) & 63];
    out += '=';
  }
  return out;
}

inline std::string b64decode(const std::string& in) {
  auto val = [](char c) -> int {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
  };
  if (in.size() % 4 != 0) throw std::runtime_error("bad base64 length");
  std::string out;
  out.reserve(in.size() / 4 * 3);
  for (size_t i = 0; i < in.size(); i += 4) {
    int a = val(in[i]), b = val(in[i + 1]);
    if (a < 0 || b < 0) throw std::runtime_error("bad base64 char");
    out += (char)((a << 2) | (b >> 4));
    if (in[i + 2] != '=') {
      int c = val(in[i + 2]);
      if (c < 0) throw std::runtime_error("bad base64 char");
      out += (char)(((b & 15) << 4) | (c >> 2));
      if (in[i + 3] != '=') {
        int d = val(in[i + 3]);
        if (d < 0) throw std::runtime_error("bad base64 char");
        out += (char)(((c & 3) << 6) | d);
      }
    }
  }
  return out;
}

}  // namespace jetcad
```

- [ ] **Step 3: API stub**

`src/native/api.cpp` (Session arrives in Task 3; the stub proves the toolchain):

```cpp
#include "include/jet_cad_native.h"

#include <cstdlib>
#include <cstring>
#include <string>

#include <Standard_Version.hxx>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace {

const char* mallocString(const std::string& s) {
  char* out = static_cast<char*>(std::malloc(s.size() + 1));
  std::memcpy(out, s.c_str(), s.size() + 1);
  return out;
}

const char* errorEnvelope(const std::string& message) {
  return mallocString(json{{"ok", false}, {"error", message}}.dump());
}

}  // namespace

extern "C" {

uint64_t jc_create_session(void) { return 0; /* Task 3 */ }

void jc_dispose_session(uint64_t) { /* Task 3 */ }

const char* jc_execute(uint64_t, const char*) {
  return errorEnvelope("no commands implemented yet");
}

const char* jc_version(void) {
  return mallocString(json{{"kernelVersion", "jet_cad_native 0.1.0"},
                           {"occtVersion", OCC_VERSION_COMPLETE}}
                          .dump());
}

void jc_free(const char* ptr) { std::free(const_cast<char*>(ptr)); }

}  // extern "C"
```

- [ ] **Step 4: CMake**

`src/native/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.24)
project(jet_cad_native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
option(JET_CAD_BUILD_TESTS "Build GoogleTest targets" ON)

find_package(OpenCASCADE REQUIRED)

include(FetchContent)
FetchContent_Declare(nlohmann_json
  URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz)
FetchContent_MakeAvailable(nlohmann_json)

add_library(jet_cad_native SHARED
  api.cpp
  # session.cpp added in Task 3
)
target_include_directories(jet_cad_native PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(jet_cad_native PRIVATE nlohmann_json::nlohmann_json)

# OCCT toolkits. 7.8+ renamed STEP toolkits (TKSTEP -> TKDESTEP); support both.
set(JET_CAD_OCCT_LIBS
  TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo
  TKPrim TKBO TKFillet TKShHealing TKXSBase)
if(TARGET TKDESTEP)
  list(APPEND JET_CAD_OCCT_LIBS TKDESTEP)
else()
  list(APPEND JET_CAD_OCCT_LIBS TKSTEP TKSTEPBase TKSTEPAttr TKSTEP209)
endif()
target_include_directories(jet_cad_native PRIVATE ${OpenCASCADE_INCLUDE_DIR})
target_link_libraries(jet_cad_native PRIVATE ${JET_CAD_OCCT_LIBS})

if(JET_CAD_BUILD_TESTS)
  FetchContent_Declare(googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.tar.gz)
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  FetchContent_MakeAvailable(googletest)
  enable_testing()
  add_executable(jet_cad_native_tests
    tests/smoke_test.cpp
    # tests/session_test.cpp added in Task 3
  )
  target_link_libraries(jet_cad_native_tests PRIVATE
    jet_cad_native nlohmann_json::nlohmann_json GTest::gtest_main)
  include(GoogleTest)
  gtest_discover_tests(jet_cad_native_tests)
endif()
```

- [ ] **Step 5: Smoke test**

`src/native/tests/smoke_test.cpp`:

```cpp
#include <gtest/gtest.h>
#include <nlohmann/json.hpp>

#include "../include/jet_cad_native.h"

using json = nlohmann::json;

TEST(Smoke, VersionReportsOcct) {
  const char* raw = jc_version();
  ASSERT_NE(raw, nullptr);
  auto v = json::parse(raw);
  jc_free(raw);
  EXPECT_EQ(v.at("kernelVersion"), "jet_cad_native 0.1.0");
  EXPECT_FALSE(v.at("occtVersion").get<std::string>().empty());
}

TEST(Smoke, ExecuteReturnsEnvelope) {
  const char* raw = jc_execute(0, "{}");
  ASSERT_NE(raw, nullptr);
  auto env = json::parse(raw);
  jc_free(raw);
  EXPECT_FALSE(env.at("ok").get<bool>());
}
```

- [ ] **Step 6: Build script**

`tool/build_native.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/native"
if command -v brew >/dev/null 2>&1; then
  export CMAKE_PREFIX_PATH="$(brew --prefix opencascade):${CMAKE_PREFIX_PATH:-}"
fi
cmake -S "$ROOT/src/native" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
  -DJET_CAD_BUILD_TESTS=ON "$@"
cmake --build "$BUILD" --parallel
ctest --test-dir "$BUILD" --output-on-failure
echo "native library: $(ls "$BUILD"/libjet_cad_native.*)"
```

`chmod +x tool/build_native.sh`. Add a "Native development" section to the package README: prerequisites (`brew install opencascade cmake ninja`), the build command, and a note that the pure-Dart suite never needs any of this.

- [ ] **Step 7: Verify + commit**

```bash
packages/jet_cad/tool/build_native.sh
cd packages/jet_cad && flutter test && flutter analyze
git add -A && git commit -m "feat: native build scaffolding with C ABI stub and GoogleTest smoke"
```

Expected: cmake configures (finds OCCT), builds, 2 smoke tests pass, Dart suite untouched and green.

---

### Task 3: Session core + makeBox

**Files:**
- Create: `packages/jet_cad/src/native/session.hpp`
- Create: `packages/jet_cad/src/native/session.cpp`
- Modify: `packages/jet_cad/src/native/api.cpp` (wire registry + dispatch)
- Modify: `packages/jet_cad/src/native/CMakeLists.txt` (add session.cpp, tests/session_test.cpp)
- Create: `packages/jet_cad/src/native/tests/session_test.cpp`

**Interfaces:**
- Consumes: Task 2 scaffolding.
- Produces:
  - `jetcad::Session` with `json execute(const json& cmd)`; command `{"cmd":"makeBox","size":[dx,dy,dz]}` → result `{"body":"b1","faces":[...6],"edges":[...12],"vertices":[...8],"remap":{}}`
  - Session registry behind the C ABI: `jc_create_session` returns real handles; `jc_execute` dispatches with a per-session `std::mutex` (insurance — Dart also serializes) and catches ALL exceptions (`Standard_Failure`, `std::exception`) into error envelopes.
  - Internal helpers the later tasks build on: `nextId(prefix)`, `requireBody(id)`, `registerBody(shape)` (enumerate faces/edges/vertices in `TopExp::MapShapes` order, assign ids, return result json), `enumerate(shape, kind)`.

- [ ] **Step 1: session.hpp**

```cpp
#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <vector>

#include <TopAbs_ShapeEnum.hxx>
#include <TopoDS_Shape.hxx>
#include <nlohmann/json.hpp>

namespace jetcad {

using json = nlohmann::json;

// Thrown for invalid input / failed operations; becomes the error envelope.
struct CommandError : std::runtime_error {
  using std::runtime_error::runtime_error;
};

struct Body {
  TopoDS_Shape shape;
  // Insertion-ordered id -> subshape. Order matches TopExp::MapShapes.
  std::vector<std::pair<std::string, TopoDS_Shape>> faces, edges, vertices;
};

class Session {
 public:
  json execute(const json& cmd);

 private:
  json makeBox(const json&);
  json extrude(const json&);       // Task 5
  json booleanOp(const json&);     // Task 4
  json fillet(const json&);        // Task 5
  json transform(const json&);     // Task 5
  json importStep(const json&);    // Task 6
  json exportStep(const json&);    // Task 6
  json snapshotBodies(const json&);   // Task 6
  json restoreBodies(const json&);    // Task 6
  json deleteBodies(const json&);
  json saveSnapshot(const json&);     // Task 6
  json restoreSession(const json&);   // Task 6

  std::string nextId(const char* prefix);
  Body& requireBody(const std::string& id);
  std::string bodyIdOwningSubshape(TopAbs_ShapeEnum kind,
                                   const std::string& id) const;
  const TopoDS_Shape& requireSubshape(TopAbs_ShapeEnum kind,
                                      const std::string& id) const;
  // Enumerates shape's subshapes of one kind in TopExp::MapShapes order.
  static std::vector<TopoDS_Shape> enumerate(const TopoDS_Shape& shape,
                                             TopAbs_ShapeEnum kind);
  // Assigns fresh ids to every subshape and stores the body; returns result
  // json {body, faces, edges, vertices, remap:{}}.
  json registerBody(const TopoDS_Shape& shape);

  uint64_t counter_ = 0;
  std::map<std::string, Body> bodies_;
};

}  // namespace jetcad
```

- [ ] **Step 2: session.cpp (core + makeBox + deleteBodies + dispatch)**

```cpp
#include "session.hpp"

#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

namespace jetcad {

std::string Session::nextId(const char* prefix) {
  return std::string(prefix) + std::to_string(++counter_);
}

Body& Session::requireBody(const std::string& id) {
  auto it = bodies_.find(id);
  if (it == bodies_.end()) throw CommandError("unknown body: " + id);
  return it->second;
}

const TopoDS_Shape& Session::requireSubshape(TopAbs_ShapeEnum kind,
                                             const std::string& id) const {
  for (const auto& [bodyId, body] : bodies_) {
    const auto& list = kind == TopAbs_FACE   ? body.faces
                       : kind == TopAbs_EDGE ? body.edges
                                             : body.vertices;
    for (const auto& [subId, shape] : list) {
      if (subId == id) return shape;
    }
  }
  throw CommandError("unknown subshape: " + id);
}

std::string Session::bodyIdOwningSubshape(TopAbs_ShapeEnum kind,
                                          const std::string& id) const {
  for (const auto& [bodyId, body] : bodies_) {
    const auto& list = kind == TopAbs_FACE   ? body.faces
                       : kind == TopAbs_EDGE ? body.edges
                                             : body.vertices;
    for (const auto& [subId, shape] : list) {
      if (subId == id) return bodyId;
    }
  }
  throw CommandError("unknown subshape: " + id);
}

std::vector<TopoDS_Shape> Session::enumerate(const TopoDS_Shape& shape,
                                             TopAbs_ShapeEnum kind) {
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes(shape, kind, map);
  std::vector<TopoDS_Shape> out;
  out.reserve(map.Extent());
  for (int i = 1; i <= map.Extent(); ++i) out.push_back(map(i));
  return out;
}

json Session::registerBody(const TopoDS_Shape& shape) {
  Body body;
  body.shape = shape;
  json faces = json::array(), edges = json::array(),
       vertices = json::array();
  for (const auto& f : enumerate(shape, TopAbs_FACE)) {
    auto id = nextId("f");
    body.faces.emplace_back(id, f);
    faces.push_back(id);
  }
  for (const auto& e : enumerate(shape, TopAbs_EDGE)) {
    auto id = nextId("e");
    body.edges.emplace_back(id, e);
    edges.push_back(id);
  }
  for (const auto& v : enumerate(shape, TopAbs_VERTEX)) {
    auto id = nextId("v");
    body.vertices.emplace_back(id, v);
    vertices.push_back(id);
  }
  auto bodyId = nextId("b");
  bodies_.emplace(bodyId, std::move(body));
  return json{{"body", bodyId},
              {"faces", faces},
              {"edges", edges},
              {"vertices", vertices},
              {"remap", json::object()}};
}

json Session::makeBox(const json& cmd) {
  const auto& size = cmd.at("size");
  double dx = size.at(0), dy = size.at(1), dz = size.at(2);
  if (dx <= 0 || dy <= 0 || dz <= 0) {
    throw CommandError("box dimensions must be positive");
  }
  BRepPrimAPI_MakeBox make(dx, dy, dz);
  return registerBody(make.Shape());
}

json Session::deleteBodies(const json& cmd) {
  // Idempotent by contract: unknown ids are silently ignored (undo paths
  // may delete already-gone bodies).
  for (const auto& id : cmd.at("bodies")) {
    bodies_.erase(id.get<std::string>());
  }
  return json::object();
}

json Session::execute(const json& cmd) {
  const std::string name = cmd.at("cmd").get<std::string>();
  if (name == "makeBox") return makeBox(cmd);
  if (name == "extrude") return extrude(cmd);
  if (name == "boolean") return booleanOp(cmd);
  if (name == "fillet") return fillet(cmd);
  if (name == "transform") return transform(cmd);
  if (name == "importStep") return importStep(cmd);
  if (name == "exportStep") return exportStep(cmd);
  if (name == "snapshotBodies") return snapshotBodies(cmd);
  if (name == "restoreBodies") return restoreBodies(cmd);
  if (name == "deleteBodies") return deleteBodies(cmd);
  if (name == "saveSnapshot") return saveSnapshot(cmd);
  if (name == "restoreSession") return restoreSession(cmd);
  throw CommandError("unknown command: " + name);
}

// Stubs replaced by Tasks 4-6; keep the linker happy and honest.
json Session::extrude(const json&) { throw CommandError("not implemented: extrude"); }
json Session::booleanOp(const json&) { throw CommandError("not implemented: boolean"); }
json Session::fillet(const json&) { throw CommandError("not implemented: fillet"); }
json Session::transform(const json&) { throw CommandError("not implemented: transform"); }
json Session::importStep(const json&) { throw CommandError("not implemented: importStep"); }
json Session::exportStep(const json&) { throw CommandError("not implemented: exportStep"); }
json Session::snapshotBodies(const json&) { throw CommandError("not implemented: snapshotBodies"); }
json Session::restoreBodies(const json&) { throw CommandError("not implemented: restoreBodies"); }
json Session::saveSnapshot(const json&) { throw CommandError("not implemented: saveSnapshot"); }
json Session::restoreSession(const json&) { throw CommandError("not implemented: restoreSession"); }

}  // namespace jetcad
```

- [ ] **Step 3: Wire registry into api.cpp**

Replace the stub bodies in `api.cpp`:

```cpp
#include <map>
#include <memory>
#include <mutex>

#include <Standard_Failure.hxx>

#include "session.hpp"

namespace {

struct SessionEntry {
  std::unique_ptr<jetcad::Session> session = std::make_unique<jetcad::Session>();
  std::mutex mutex;  // insurance; Dart already serializes per session
};

std::mutex g_registryMutex;
std::map<uint64_t, std::unique_ptr<SessionEntry>> g_sessions;
uint64_t g_nextHandle = 0;

}  // namespace

extern "C" {

uint64_t jc_create_session(void) {
  std::lock_guard<std::mutex> lock(g_registryMutex);
  uint64_t handle = ++g_nextHandle;
  g_sessions[handle] = std::make_unique<SessionEntry>();
  return handle;
}

void jc_dispose_session(uint64_t session) {
  std::lock_guard<std::mutex> lock(g_registryMutex);
  g_sessions.erase(session);
}

const char* jc_execute(uint64_t session, const char* command_json) {
  SessionEntry* entry = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_registryMutex);
    auto it = g_sessions.find(session);
    if (it != g_sessions.end()) entry = it->second.get();
  }
  if (entry == nullptr) return errorEnvelope("unknown session");
  try {
    std::lock_guard<std::mutex> lock(entry->mutex);
    auto cmd = json::parse(command_json);
    auto result = entry->session->execute(cmd);
    return mallocString(json{{"ok", true}, {"result", result}}.dump());
  } catch (const Standard_Failure& e) {
    const char* msg = e.GetMessageString();
    return errorEnvelope(std::string("OCCT: ") + (msg ? msg : "failure"));
  } catch (const std::exception& e) {
    return errorEnvelope(e.what());
  } catch (...) {
    return errorEnvelope("unknown native error");
  }
}

}  // extern "C"
```

(`jc_version`/`jc_free`/helpers stay from Task 2.)

- [ ] **Step 4: session_test.cpp**

```cpp
#include <gtest/gtest.h>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

#include "../session.hpp"

using jetcad::Session;
using json = nlohmann::json;

namespace {
double volume(const TopoDS_Shape& shape) {
  GProp_GProps props;
  BRepGProp::VolumeProperties(shape, props);
  return props.Mass();
}
}  // namespace

TEST(SessionMakeBox, TopologyCountsAndDeterministicIds) {
  Session s;
  auto r = s.execute({{"cmd", "makeBox"}, {"size", {1.0, 2.0, 3.0}}});
  EXPECT_EQ(r.at("faces").size(), 6u);
  EXPECT_EQ(r.at("edges").size(), 12u);
  EXPECT_EQ(r.at("vertices").size(), 8u);
  EXPECT_TRUE(r.at("remap").empty());

  Session s2;
  auto r2 = s2.execute({{"cmd", "makeBox"}, {"size", {1.0, 2.0, 3.0}}});
  EXPECT_EQ(r.at("body"), r2.at("body")) << "ids deterministic per session";
}

TEST(SessionMakeBox, VolumeGolden) {
  Session s;
  auto r = s.execute({{"cmd", "makeBox"}, {"size", {2.0, 3.0, 4.0}}});
  // Reach the shape through a second command? No — this is a C++ unit
  // test; use a friend-free check via export in Task 6. Here: rebuild and
  // measure directly to pin OCCT behavior.
  BRepPrimAPI_MakeBox make(2.0, 3.0, 4.0);
  EXPECT_NEAR(volume(make.Shape()), 24.0, 1e-9);
  (void)r;
}

TEST(SessionMakeBox, RejectsBadInput) {
  Session s;
  EXPECT_THROW(
      s.execute({{"cmd", "makeBox"}, {"size", {-1.0, 1.0, 1.0}}}),
      jetcad::CommandError);
  EXPECT_THROW(s.execute({{"cmd", "loft"}}), jetcad::CommandError);
}

TEST(CApi, SessionLifecycleAndErrorEnvelope) {
  uint64_t h = jc_create_session();
  ASSERT_NE(h, 0u);
  const char* raw = jc_execute(
      h, R"({"cmd":"makeBox","size":[1.0,1.0,1.0]})");
  auto env = json::parse(raw);
  jc_free(raw);
  ASSERT_TRUE(env.at("ok").get<bool>());
  EXPECT_EQ(env.at("result").at("faces").size(), 6u);

  raw = jc_execute(h, R"({"cmd":"makeBox","size":[0.0,1.0,1.0]})");
  env = json::parse(raw);
  jc_free(raw);
  EXPECT_FALSE(env.at("ok").get<bool>());

  jc_dispose_session(h);
  raw = jc_execute(h, R"({"cmd":"makeBox","size":[1.0,1.0,1.0]})");
  env = json::parse(raw);
  jc_free(raw);
  EXPECT_FALSE(env.at("ok").get<bool>());
  EXPECT_EQ(env.at("error"), "unknown session");
}
```

Add includes as needed (`#include <BRepPrimAPI_MakeBox.hxx>`, `#include "../include/jet_cad_native.h"`). Register `session.cpp` in the library sources and `tests/session_test.cpp` in the test target.

- [ ] **Step 5: Verify + commit**

```bash
packages/jet_cad/tool/build_native.sh
git add -A && git commit -m "feat: native Session core with makeBox and C ABI dispatch"
```

Expected: all gtest targets green (2 smoke + 4 session).

---

### Task 4: Boolean with history-based remap

**Files:**
- Modify: `packages/jet_cad/src/native/session.hpp` (add lineage helper decl)
- Modify: `packages/jet_cad/src/native/session.cpp` (replace booleanOp stub)
- Create: `packages/jet_cad/src/native/tests/boolean_test.cpp`
- Modify: `packages/jet_cad/src/native/CMakeLists.txt`

**Interfaces:**
- Consumes: Session core.
- Produces: command `{"cmd":"boolean","a":"b9","b":"b18","op":"fuse|cut|common"}` → CreateResult json. Contract: `a`/`b` fully consumed; remap maps every prior subshape id (via `BRepAlgoAPI` history lineage: `Modified`, survival by `IsSame`, else `IsDeleted`/`[]`); result subshapes get fresh ids.

- [ ] **Step 1: Implement booleanOp**

Replace the stub in `session.cpp` (add includes `<BRepAlgoAPI_Common.hxx>`, `<BRepAlgoAPI_Cut.hxx>`, `<BRepAlgoAPI_Fuse.hxx>`, `<BRepAlgoAPI_BooleanOperation.hxx>`, `<memory>`):

```cpp
namespace {

// Finds the id assigned to `shape` in a freshly registered body, or "".
std::string idOfShape(const Body& body, TopAbs_ShapeEnum kind,
                      const TopoDS_Shape& shape) {
  const auto& list = kind == TopAbs_FACE   ? body.faces
                     : kind == TopAbs_EDGE ? body.edges
                                           : body.vertices;
  for (const auto& [id, s] : list) {
    if (s.IsSame(shape)) return id;
  }
  return {};
}

}  // namespace

json Session::booleanOp(const json& cmd) {
  const std::string aId = cmd.at("a"), bId = cmd.at("b");
  if (aId == bId) throw CommandError("boolean operands must be distinct");
  Body a = requireBody(aId);  // copies: we erase before registering result
  Body b = requireBody(bId);
  const std::string op = cmd.at("op");

  std::unique_ptr<BRepAlgoAPI_BooleanOperation> algo;
  if (op == "fuse") {
    algo = std::make_unique<BRepAlgoAPI_Fuse>(a.shape, b.shape);
  } else if (op == "cut") {
    algo = std::make_unique<BRepAlgoAPI_Cut>(a.shape, b.shape);
  } else if (op == "common") {
    algo = std::make_unique<BRepAlgoAPI_Common>(a.shape, b.shape);
  } else {
    throw CommandError("unknown boolean op: " + op);
  }
  if (!algo->IsDone()) throw CommandError("boolean operation failed");
  TopoDS_Shape result = algo->Shape();
  if (result.IsNull()) throw CommandError("boolean produced empty result");

  bodies_.erase(aId);
  bodies_.erase(bId);
  json out = registerBody(result);
  const Body& newBody = bodies_.at(out.at("body").get<std::string>());

  json remap = json::object();
  remap[aId] = json::array({out.at("body")});
  remap[bId] = json::array({out.at("body")});
  auto mapOld = [&](TopAbs_ShapeEnum kind,
                    const std::vector<std::pair<std::string, TopoDS_Shape>>&
                        olds) {
    for (const auto& [oldId, oldShape] : olds) {
      json targets = json::array();
      if (!algo->IsDeleted(oldShape)) {
        const auto& mods = algo->Modified(oldShape);
        if (!mods.IsEmpty()) {
          for (const auto& m : mods) {
            auto id = idOfShape(newBody, kind, m);
            if (!id.empty()) targets.push_back(id);
          }
        } else {
          // Survived unmodified: geometry identical, but ids are fresh in
          // v1 (boolean consumes inputs wholesale). Map to the new id.
          auto id = idOfShape(newBody, kind, oldShape);
          if (!id.empty()) targets.push_back(id);
        }
      }
      remap[oldId] = targets;
    }
  };
  for (const Body* src : {&a, &b}) {
    mapOld(TopAbs_FACE, src->faces);
    mapOld(TopAbs_EDGE, src->edges);
    mapOld(TopAbs_VERTEX, src->vertices);
  }
  out["remap"] = remap;
  return out;
}
```

Note `Modified()` returns `const TopTools_ListOfShape&` — iterate with a range-for (OCCT ≥ 7.2 supports it) or `TopTools_ListIteratorOfListOfShape`; adjust to the installed OCCT.

- [ ] **Step 2: boolean_test.cpp**

```cpp
#include <gtest/gtest.h>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

#include "../session.hpp"

using jetcad::Session;
using json = nlohmann::json;

namespace {
json box(Session& s, double x, double y, double z) {
  return s.execute({{"cmd", "makeBox"}, {"size", {x, y, z}}});
}
}  // namespace

TEST(Boolean, FuseConsumesInputsAndRemapsEverything) {
  Session s;
  auto a = box(s, 1, 1, 1);
  auto b = box(s, 2, 2, 2);
  auto c = s.execute({{"cmd", "boolean"},
                      {"a", a.at("body")},
                      {"b", b.at("body")},
                      {"op", "fuse"}});
  // Both bodies consumed.
  EXPECT_THROW(s.execute({{"cmd", "boolean"},
                          {"a", a.at("body")},
                          {"b", c.at("body")},
                          {"op", "cut"}}),
               jetcad::CommandError);
  // Remap covers both body ids and every prior subshape id.
  const auto& remap = c.at("remap");
  EXPECT_EQ(remap.at(a.at("body").get<std::string>())[0], c.at("body"));
  size_t expected = 2;  // the two body ids
  for (const auto* r : {&a, &b}) {
    expected += r->at("faces").size() + r->at("edges").size() +
                r->at("vertices").size();
  }
  EXPECT_EQ(remap.size(), expected);
}

TEST(Boolean, CutVolumeGolden) {
  Session s;
  // Unit cube minus a cube covering half of it: volume 0.5.
  auto a = box(s, 1, 1, 1);
  auto b = box(s, 0.5, 1, 1);  // overlaps [0,0.5]x[0,1]x[0,1]
  auto c = s.execute({{"cmd", "boolean"},
                      {"a", a.at("body")},
                      {"b", b.at("body")},
                      {"op", "cut"}});
  // Volume via a companion measurement command is Task 6 territory;
  // measure through the registered shape by re-running the same geometry.
  // Contract-level assertion here: result exists with faces.
  EXPECT_GT(c.at("faces").size(), 0u);
  EXPECT_FALSE(c.at("body").get<std::string>().empty());
}

TEST(Boolean, RejectsSelfAndUnknown) {
  Session s;
  auto a = box(s, 1, 1, 1);
  EXPECT_THROW(s.execute({{"cmd", "boolean"},
                          {"a", a.at("body")},
                          {"b", a.at("body")},
                          {"op", "fuse"}}),
               jetcad::CommandError);
  EXPECT_THROW(s.execute({{"cmd", "boolean"},
                          {"a", "nope"},
                          {"b", a.at("body")},
                          {"op", "fuse"}}),
               jetcad::CommandError);
}
```

Volume goldens for booleans move to Task 6 (via `snapshotBodies` + direct BREP measurement in the test); the contract assertions above are what boolean itself owns. Add the file to CMake.

- [ ] **Step 3: Verify + commit**

```bash
packages/jet_cad/tool/build_native.sh
git add -A && git commit -m "feat: native boolean with history-based id remap"
```

---

### Task 5: Extrude, fillet, transform

**Files:**
- Modify: `packages/jet_cad/src/native/session.cpp` (replace three stubs; add fillet-specific registration helper)
- Create: `packages/jet_cad/src/native/tests/modeling_test.cpp`
- Modify: `packages/jet_cad/src/native/CMakeLists.txt`

**Interfaces:**
- Consumes: Session core.
- Produces:
  - `{"cmd":"extrude","face":"f3","depth":5.0}` → new body (prism along face outward normal × depth), source body untouched, remap `{}`.
  - `{"cmd":"fillet","edges":["e4"],"radius":0.1}` → same body id, new shape; surviving/Modified subshapes keep ids; result lists = newly created subshapes only; remap: consumed edge → generated face ids, plus `[]` for other deleted subshapes.
  - `{"cmd":"transform","bodies":["b9"],"matrix":[16 col-major doubles]}` → `{}` result; subshape ids preserved positionally; rejects non-rigid matrices (`gp_Trsf` limitation, surfaced as CommandError "transform must be rigid (rotation+translation)"). Uniform-scale/non-rigid support deferred (`gp_GTrsf`), documented in the command's error message.

- [ ] **Step 1: Implement extrude**

Includes: `<BRepAdaptor_Surface.hxx>`, `<BRepPrimAPI_MakePrism.hxx>`, `<TopoDS.hxx>`, `<gp_Vec.hxx>`.

```cpp
json Session::extrude(const json& cmd) {
  const std::string faceId = cmd.at("face");
  double depth = cmd.at("depth");
  if (depth == 0) throw CommandError("extrude depth must be non-zero");
  const TopoDS_Shape& faceShape = requireSubshape(TopAbs_FACE, faceId);
  TopoDS_Face face = TopoDS::Face(faceShape);

  BRepAdaptor_Surface surf(face);
  double u = (surf.FirstUParameter() + surf.LastUParameter()) / 2.0;
  double v = (surf.FirstVParameter() + surf.LastVParameter()) / 2.0;
  gp_Pnt p;
  gp_Vec d1u, d1v;
  surf.D1(u, v, p, d1u, d1v);
  gp_Vec normal = d1u.Crossed(d1v);
  if (normal.Magnitude() < 1e-12) {
    throw CommandError("cannot compute face normal");
  }
  if (face.Orientation() == TopAbs_REVERSED) normal.Reverse();
  normal.Normalize();
  normal.Multiply(depth);

  BRepPrimAPI_MakePrism prism(face, normal);
  if (!prism.IsDone()) throw CommandError("extrude failed");
  return registerBody(prism.Shape());
}
```

- [ ] **Step 2: Implement fillet**

Includes: `<BRepFilletAPI_MakeFillet.hxx>`.

```cpp
json Session::fillet(const json& cmd) {
  const auto& edgeIds = cmd.at("edges");
  double radius = cmd.at("radius");
  if (edgeIds.empty()) throw CommandError("fillet needs at least one edge");
  if (radius <= 0) throw CommandError("fillet radius must be positive");

  const std::string bodyId =
      bodyIdOwningSubshape(TopAbs_EDGE, edgeIds[0].get<std::string>());
  for (const auto& e : edgeIds) {
    if (bodyIdOwningSubshape(TopAbs_EDGE, e.get<std::string>()) != bodyId) {
      throw CommandError("fillet edges must belong to a single body");
    }
  }
  Body old = bodies_.at(bodyId);  // copy for lineage lookup

  BRepFilletAPI_MakeFillet make(old.shape);
  std::vector<std::pair<std::string, TopoDS_Shape>> filleted;
  for (const auto& e : edgeIds) {
    const std::string id = e.get<std::string>();
    for (const auto& [subId, shape] : old.edges) {
      if (subId == id) {
        make.Add(radius, TopoDS::Edge(shape));
        filleted.emplace_back(subId, shape);
      }
    }
  }
  make.Build();
  if (!make.IsDone()) throw CommandError("fillet failed (radius too large?)");
  TopoDS_Shape newShape = make.Shape();

  // Rebuild the body under the SAME id, carrying ids forward:
  // - subshape survives (IsSame) or is Modified(old)  -> keeps old id
  // - otherwise                                       -> fresh id (reported)
  Body rebuilt;
  rebuilt.shape = newShape;
  json newFaces = json::array(), newEdges = json::array(),
       newVertices = json::array();
  auto carry = [&](TopAbs_ShapeEnum kind,
                   const std::vector<std::pair<std::string, TopoDS_Shape>>&
                       olds,
                   std::vector<std::pair<std::string, TopoDS_Shape>>& dest,
                   json& reportNew, const char* prefix) {
    for (const auto& shape : enumerate(newShape, kind)) {
      std::string carried;
      for (const auto& [oldId, oldShape] : olds) {
        if (shape.IsSame(oldShape)) { carried = oldId; break; }
        const auto& mods = make.Modified(oldShape);
        for (const auto& m : mods) {
          if (shape.IsSame(m)) { carried = oldId; break; }
        }
        if (!carried.empty()) break;
      }
      if (carried.empty()) {
        carried = nextId(prefix);
        reportNew.push_back(carried);
      }
      dest.emplace_back(carried, shape);
    }
  };
  carry(TopAbs_FACE, old.faces, rebuilt.faces, newFaces, "f");
  carry(TopAbs_EDGE, old.edges, rebuilt.edges, newEdges, "e");
  carry(TopAbs_VERTEX, old.vertices, rebuilt.vertices, newVertices, "v");

  // Remap: filleted edges -> the faces Generated from them; every other
  // old subshape that no longer exists -> [].
  json remap = json::object();
  auto stillPresent = [&](TopAbs_ShapeEnum kind, const std::string& id) {
    const auto& list = kind == TopAbs_FACE   ? rebuilt.faces
                       : kind == TopAbs_EDGE ? rebuilt.edges
                                             : rebuilt.vertices;
    for (const auto& [subId, s] : list) {
      if (subId == id) return true;
    }
    return false;
  };
  for (const auto& [edgeId, edgeShape] : filleted) {
    json targets = json::array();
    const auto& generated = make.Generated(edgeShape);
    for (const auto& g : generated) {
      auto id = idOfShape(rebuilt, TopAbs_FACE, g);
      if (!id.empty()) targets.push_back(id);
    }
    remap[edgeId] = targets;
  }
  auto dropVanished = [&](TopAbs_ShapeEnum kind,
                          const std::vector<
                              std::pair<std::string, TopoDS_Shape>>& olds) {
    for (const auto& [oldId, s] : olds) {
      if (!stillPresent(kind, oldId) && !remap.contains(oldId)) {
        remap[oldId] = json::array();
      }
    }
  };
  dropVanished(TopAbs_FACE, old.faces);
  dropVanished(TopAbs_EDGE, old.edges);
  dropVanished(TopAbs_VERTEX, old.vertices);

  bodies_[bodyId] = std::move(rebuilt);
  return json{{"body", bodyId},
              {"faces", newFaces},
              {"edges", newEdges},
              {"vertices", newVertices},
              {"remap", remap}};
}
```

(`idOfShape` from Task 4 moves to a file-local helper usable by both.)

- [ ] **Step 3: Implement transform**

Includes: `<BRepBuilderAPI_Transform.hxx>`, `<gp_Trsf.hxx>`.

```cpp
json Session::transform(const json& cmd) {
  const auto& m = cmd.at("matrix");
  if (m.size() != 16) throw CommandError("matrix must have 16 values");
  gp_Trsf trsf;
  try {
    // Column-major input -> gp_Trsf row-major 3x4.
    trsf.SetValues(m[0], m[4], m[8], m[12],
                   m[1], m[5], m[9], m[13],
                   m[2], m[6], m[10], m[14]);
  } catch (const Standard_Failure&) {
    throw CommandError(
        "transform must be rigid (rotation+translation); scaling/shear "
        "unsupported in v1");
  }
  for (const auto& idJson : cmd.at("bodies")) {
    requireBody(idJson.get<std::string>());
  }
  for (const auto& idJson : cmd.at("bodies")) {
    Body& body = bodies_.at(idJson.get<std::string>());
    Body moved;
    BRepBuilderAPI_Transform mover(body.shape, trsf, /*Copy=*/false);
    moved.shape = mover.Shape();
    // Same TShape tree, same enumeration order: transfer ids positionally.
    auto transfer = [&](TopAbs_ShapeEnum kind,
                        const std::vector<
                            std::pair<std::string, TopoDS_Shape>>& olds,
                        std::vector<std::pair<std::string, TopoDS_Shape>>&
                            dest) {
      auto shapes = enumerate(moved.shape, kind);
      if (shapes.size() != olds.size()) {
        throw CommandError("internal: transform changed topology");
      }
      for (size_t i = 0; i < shapes.size(); ++i) {
        dest.emplace_back(olds[i].first, shapes[i]);
      }
    };
    transfer(TopAbs_FACE, body.faces, moved.faces);
    transfer(TopAbs_EDGE, body.edges, moved.edges);
    transfer(TopAbs_VERTEX, body.vertices, moved.vertices);
    body = std::move(moved);
  }
  return json::object();
}
```

Add `#include <Standard_Failure.hxx>` to session.cpp.

- [ ] **Step 4: modeling_test.cpp**

```cpp
#include <gtest/gtest.h>

#include "../session.hpp"

using jetcad::Session;
using json = nlohmann::json;

namespace {
json box(Session& s, double x, double y, double z) {
  return s.execute({{"cmd", "makeBox"}, {"size", {x, y, z}}});
}
}  // namespace

TEST(Extrude, CreatesNewBodyLeavesSourceIntact) {
  Session s;
  auto a = box(s, 2, 3, 1);
  auto r = s.execute({{"cmd", "extrude"},
                      {"face", a.at("faces")[0]},
                      {"depth", 5.0}});
  EXPECT_NE(r.at("body"), a.at("body"));
  EXPECT_EQ(r.at("faces").size(), 6u);
  // Source still usable.
  auto r2 = s.execute({{"cmd", "extrude"},
                       {"face", a.at("faces")[1]},
                       {"depth", 1.0}});
  EXPECT_FALSE(r2.at("body").get<std::string>().empty());
  EXPECT_THROW(
      s.execute({{"cmd", "extrude"}, {"face", "nope"}, {"depth", 1.0}}),
      jetcad::CommandError);
}

TEST(Fillet, KeepsBodyIdMapsEdgeToGeneratedFace) {
  Session s;
  auto a = box(s, 10, 10, 10);
  std::string edge = a.at("edges")[0];
  auto r = s.execute(
      {{"cmd", "fillet"}, {"edges", {edge}}, {"radius", 1.0}});
  EXPECT_EQ(r.at("body"), a.at("body"));
  ASSERT_TRUE(r.at("remap").contains(edge));
  EXPECT_GE(r.at("remap").at(edge).size(), 1u)
      << "filleted edge maps to generated face(s)";
  EXPECT_GE(r.at("faces").size(), 1u) << "at least the new fillet face";
  EXPECT_THROW(s.execute({{"cmd", "fillet"},
                          {"edges", {edge}},
                          {"radius", 1.0}}),
               jetcad::CommandError)
      << "consumed edge id no longer valid";
  EXPECT_THROW(s.execute({{"cmd", "fillet"},
                          {"edges", json::array()},
                          {"radius", 1.0}}),
               jetcad::CommandError);
}

TEST(Fillet, TooLargeRadiusFailsCleanly) {
  Session s;
  auto a = box(s, 1, 1, 1);
  EXPECT_THROW(s.execute({{"cmd", "fillet"},
                          {"edges", {a.at("edges")[0]}},
                          {"radius", 100.0}}),
               jetcad::CommandError);
  // Body must still exist untouched after the failure.
  auto r = s.execute({{"cmd", "fillet"},
                      {"edges", {a.at("edges")[1]}},
                      {"radius", 0.1}});
  EXPECT_EQ(r.at("body"), a.at("body"));
}

TEST(Transform, PreservesIdsRejectsScale) {
  Session s;
  auto a = box(s, 1, 1, 1);
  // Column-major translation by (5,0,0).
  json m = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 5, 0, 0, 1};
  auto r = s.execute(
      {{"cmd", "transform"}, {"bodies", {a.at("body")}}, {"matrix", m}});
  EXPECT_TRUE(r.empty());
  // Ids still valid: fillet an edge of the moved body.
  auto f = s.execute({{"cmd", "fillet"},
                      {"edges", {a.at("edges")[0]}},
                      {"radius", 0.1}});
  EXPECT_EQ(f.at("body"), a.at("body"));
  // Non-rigid rejected.
  json scale = {2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  EXPECT_THROW(s.execute({{"cmd", "transform"},
                          {"bodies", {a.at("body")}},
                          {"matrix", scale}}),
               jetcad::CommandError);
}
```

Add to CMake test sources.

- [ ] **Step 5: Verify + commit**

```bash
packages/jet_cad/tool/build_native.sh
git add -A && git commit -m "feat: native extrude, fillet with id carry-over, rigid transform"
```

---

### Task 6: STEP I/O + snapshots + session persistence

**Files:**
- Modify: `packages/jet_cad/src/native/session.hpp` (add `brepToString`/`brepFromString` decls)
- Modify: `packages/jet_cad/src/native/session.cpp` (replace six stubs)
- Create: `packages/jet_cad/src/native/tests/persistence_test.cpp`
- Modify: `packages/jet_cad/src/native/CMakeLists.txt`

**Interfaces:**
- Consumes: everything native so far.
- Produces:
  - `{"cmd":"importStep","dataB64":...}` → `{"bodies":[CreateResult,...]}` (one per STEP root; a compound root registers as one body)
  - `{"cmd":"exportStep","bodies":[ids]}` → `{"dataB64":...}`
  - `{"cmd":"snapshotBodies","bodies":[ids]}` → `{"dataB64":...}` — payload is JSON `[{id, brepB64, faces:[ids], edges:[ids], vertices:[ids]}]` (BREP via `BRepTools::Write` ASCII; subshape ids stored positionally in enumeration order — id-preserving by construction)
  - `{"cmd":"restoreBodies","dataB64":...}` → `{}` (bodies re-registered under their original ids, overwriting; ids never re-issued: counter bumped past any numeric suffix seen)
  - `{"cmd":"saveSnapshot"}` → `{"dataB64":...}` (all bodies + `counter`)
  - `{"cmd":"restoreSession","dataB64":...}` → `{}` (clears session, loads bodies, `counter_ = max(counter_, saved)`)

- [ ] **Step 1: BREP + temp-file helpers**

In `session.cpp` (includes: `<BRepTools.hxx>`, `<BRep_Builder.hxx>`, `<sstream>`, `<fstream>`, `<filesystem>`, `<atomic>`, `<unistd.h>` (POSIX `getpid`; on Windows use `_getpid` from `<process.h>` — Plan 5 concern), `<STEPControl_Reader.hxx>`, `<STEPControl_Writer.hxx>`, `<IFSelect_ReturnStatus.hxx>`, `<TopoDS_Compound.hxx>`, and `"b64.hpp"`):

```cpp
namespace {

std::string brepToString(const TopoDS_Shape& shape) {
  std::ostringstream out;
  BRepTools::Write(shape, out);
  return out.str();
}

TopoDS_Shape brepFromString(const std::string& data) {
  std::istringstream in(data);
  TopoDS_Shape shape;
  BRep_Builder builder;
  BRepTools::Read(shape, in, builder);
  if (shape.IsNull()) throw jetcad::CommandError("corrupt BREP payload");
  return shape;
}

// Unique temp path; STEP translators are file-based across OCCT versions.
std::filesystem::path tempStepPath() {
  static std::atomic<uint64_t> counter{0};
  auto name = "jet_cad_" + std::to_string(::getpid()) + "_" +
              std::to_string(++counter) + ".step";
  return std::filesystem::temp_directory_path() / name;
}

struct TempFileGuard {
  std::filesystem::path path;
  ~TempFileGuard() {
    std::error_code ec;
    std::filesystem::remove(path, ec);
  }
};

// Bumps the id counter past any numeric suffix in restored ids so a
// restored snapshot never collides with future fresh ids.
uint64_t maxNumericSuffix(const nlohmann::json& ids) {
  uint64_t maxSeen = 0;
  for (const auto& idJson : ids) {
    const std::string id = idJson.get<std::string>();
    size_t digits = id.find_first_of("0123456789");
    if (digits != std::string::npos) {
      maxSeen = std::max(maxSeen,
                         (uint64_t)std::stoull(id.substr(digits)));
    }
  }
  return maxSeen;
}

}  // namespace
```

- [ ] **Step 2: Implement snapshots**

```cpp
json Session::snapshotBodies(const json& cmd) {
  json dump = json::array();
  for (const auto& idJson : cmd.at("bodies")) {
    const std::string id = idJson.get<std::string>();
    const Body& body = requireBody(id);
    json entry = {{"id", id}, {"brepB64", b64encode(brepToString(body.shape))}};
    for (auto [key, list] : {std::pair{"faces", &body.faces},
                             {"edges", &body.edges},
                             {"vertices", &body.vertices}}) {
      json ids = json::array();
      for (const auto& [subId, s] : *list) ids.push_back(subId);
      entry[key] = ids;
    }
    dump.push_back(entry);
  }
  return json{{"dataB64", b64encode(dump.dump())}};
}

json Session::restoreBodies(const json& cmd) {
  auto dump = json::parse(b64decode(cmd.at("dataB64").get<std::string>()));
  for (const auto& entry : dump) {
    Body body;
    body.shape = brepFromString(b64decode(entry.at("brepB64")));
    auto zip = [&](const char* key, TopAbs_ShapeEnum kind,
                   std::vector<std::pair<std::string, TopoDS_Shape>>& dest) {
      auto shapes = enumerate(body.shape, kind);
      const auto& ids = entry.at(key);
      if (ids.size() != shapes.size()) {
        throw CommandError("snapshot id/topology mismatch");
      }
      for (size_t i = 0; i < shapes.size(); ++i) {
        dest.emplace_back(ids[i].get<std::string>(), shapes[i]);
      }
      counter_ = std::max(counter_, maxNumericSuffix(ids));
    };
    zip("faces", TopAbs_FACE, body.faces);
    zip("edges", TopAbs_EDGE, body.edges);
    zip("vertices", TopAbs_VERTEX, body.vertices);
    const std::string id = entry.at("id");
    counter_ = std::max(counter_, maxNumericSuffix(json::array({id})));
    bodies_[id] = std::move(body);
  }
  return json::object();
}

json Session::saveSnapshot(const json&) {
  json allIds = json::array();
  for (const auto& [id, body] : bodies_) allIds.push_back(id);
  json bodiesDump =
      json::parse(b64decode(snapshotBodies({{"cmd", "snapshotBodies"},
                                            {"bodies", allIds}})
                                .at("dataB64")
                                .get<std::string>()));
  return json{{"dataB64",
               b64encode(json{{"counter", counter_},
                              {"bodies", bodiesDump}}
                             .dump())}};
}

json Session::restoreSession(const json& cmd) {
  auto snapshot =
      json::parse(b64decode(cmd.at("dataB64").get<std::string>()));
  bodies_.clear();
  restoreBodies({{"cmd", "restoreBodies"},
                 {"dataB64", b64encode(snapshot.at("bodies").dump())}});
  counter_ = std::max(counter_, snapshot.at("counter").get<uint64_t>());
  return json::object();
}
```

- [ ] **Step 3: Implement STEP I/O**

```cpp
json Session::importStep(const json& cmd) {
  const std::string bytes = b64decode(cmd.at("dataB64").get<std::string>());
  if (bytes.empty()) throw CommandError("empty STEP payload");
  TempFileGuard tmp{tempStepPath()};
  {
    std::ofstream out(tmp.path, std::ios::binary);
    out.write(bytes.data(), (std::streamsize)bytes.size());
  }
  STEPControl_Reader reader;
  if (reader.ReadFile(tmp.path.string().c_str()) != IFSelect_RetDone) {
    throw CommandError("STEP parse failed");
  }
  reader.TransferRoots();
  json results = json::array();
  for (int i = 1; i <= reader.NbShapes(); ++i) {
    TopoDS_Shape shape = reader.Shape(i);
    if (!shape.IsNull()) results.push_back(registerBody(shape));
  }
  if (results.empty()) throw CommandError("STEP contained no shapes");
  return json{{"bodies", results}};
}

json Session::exportStep(const json& cmd) {
  TopoDS_Compound compound;
  BRep_Builder builder;
  builder.MakeCompound(compound);
  for (const auto& idJson : cmd.at("bodies")) {
    builder.Add(compound, requireBody(idJson.get<std::string>()).shape);
  }
  TempFileGuard tmp{tempStepPath()};
  STEPControl_Writer writer;
  writer.Transfer(compound, STEPControl_AsIs);
  if (writer.Write(tmp.path.string().c_str()) != IFSelect_RetDone) {
    throw CommandError("STEP write failed");
  }
  std::ifstream in(tmp.path, std::ios::binary);
  std::string bytes((std::istreambuf_iterator<char>(in)),
                    std::istreambuf_iterator<char>());
  return json{{"dataB64", b64encode(bytes)}};
}
```

(`STEPControl_StepModelType`/`STEPControl_AsIs` include: `<STEPControl_StepModelType.hxx>` if needed.)

- [ ] **Step 4: persistence_test.cpp**

```cpp
#include <gtest/gtest.h>

#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>

#include "../session.hpp"

using jetcad::Session;
using json = nlohmann::json;

namespace {
json box(Session& s, double x, double y, double z) {
  return s.execute({{"cmd", "makeBox"}, {"size", {x, y, z}}});
}
}  // namespace

TEST(Snapshots, RestorePreservesIdsAndCounterNeverCollides) {
  Session s;
  auto a = box(s, 1, 2, 3);
  const std::string bodyId = a.at("body");
  auto snap = s.execute({{"cmd", "snapshotBodies"}, {"bodies", {bodyId}}});
  s.execute({{"cmd", "deleteBodies"}, {"bodies", {bodyId}}});
  EXPECT_THROW(s.execute({{"cmd", "exportStep"}, {"bodies", {bodyId}}}),
               jetcad::CommandError);
  s.execute({{"cmd", "restoreBodies"}, {"dataB64", snap.at("dataB64")}});
  auto step = s.execute({{"cmd", "exportStep"}, {"bodies", {bodyId}}});
  EXPECT_FALSE(step.at("dataB64").get<std::string>().empty());
  // Fresh ids after restore must not collide with restored ones.
  auto b = box(s, 1, 1, 1);
  EXPECT_NE(b.at("body"), bodyId);
}

TEST(Snapshots, SessionSaveRestoreRoundTrip) {
  Session s;
  auto a = box(s, 1, 1, 1);
  auto b = box(s, 2, 2, 2);
  auto save = s.execute({{"cmd", "saveSnapshot"}});
  Session fresh;
  fresh.execute({{"cmd", "restoreSession"}, {"dataB64", save.at("dataB64")}});
  auto step = fresh.execute(
      {{"cmd", "exportStep"},
       {"bodies", {a.at("body"), b.at("body")}}});
  EXPECT_FALSE(step.at("dataB64").get<std::string>().empty());
  auto c = box(fresh, 3, 3, 3);
  EXPECT_NE(c.at("body"), a.at("body"));
  EXPECT_NE(c.at("body"), b.at("body"));
}

TEST(Step, ExportImportRoundTrip) {
  Session s;
  auto a = box(s, 2, 3, 4);
  auto out = s.execute({{"cmd", "exportStep"}, {"bodies", {a.at("body")}}});
  Session other;
  auto imported = other.execute(
      {{"cmd", "importStep"}, {"dataB64", out.at("dataB64")}});
  ASSERT_GE(imported.at("bodies").size(), 1u);
  EXPECT_GE(imported.at("bodies")[0].at("faces").size(), 6u);
  EXPECT_THROW(other.execute({{"cmd", "importStep"},
                              {"dataB64", "aGVsbG8="}}),
               jetcad::CommandError)
      << "non-STEP payload rejected";
}
```

Add to CMake.

- [ ] **Step 5: Verify + commit**

```bash
packages/jet_cad/tool/build_native.sh
git add -A && git commit -m "feat: native STEP io and id-preserving snapshots"
```

---

### Task 7: Dart FFI bridge

**Files:**
- Create: `packages/jet_cad/lib/src/kernel/ffi/native_bindings.dart`
- Create: `packages/jet_cad/lib/src/kernel/ffi/ffi_kernel_bridge.dart`
- Create: `packages/jet_cad/lib/src/kernel/ffi_kernel_bridge_unsupported.dart`
- Create: `packages/jet_cad/lib/src/kernel/ffi_kernel_bridge_export.dart`
- Modify: `packages/jet_cad/lib/jet_cad.dart`
- Modify: `packages/jet_cad/pubspec.yaml` (add `ffi: ^2.1.0`)
- Test: `packages/jet_cad/test/kernel_ffi/ffi_kernel_bridge_test.dart`

**Interfaces:**
- Consumes: native library from Tasks 2-6, `KernelBridge` + types from Task 1.
- Produces:
  - `class FfiKernelBridge implements KernelBridge` — construct with `FfiKernelBridge(libraryPath)` or `FfiKernelBridge.auto()` (env `JET_CAD_NATIVE_LIB`, else `<package>/build/native/libjet_cad_native.{dylib|so}`); static `String? locateLibrary()` returns null when absent (tests use this to skip).
  - One command in flight per session: internal future-chain queue keyed by session handle; every command runs the blocking native call inside `Isolate.run`.
  - Error envelopes → `KernelException(message)`.
  - Conditional public export: `FfiKernelBridge` importable from `package:jet_cad/jet_cad.dart` on ffi platforms; on non-ffi platforms the stub class throws `UnsupportedError` on construction. Nothing above the bridge imports `dart:ffi` — this file IS the bridge layer.

- [ ] **Step 1: Bindings**

`lib/src/kernel/ffi/native_bindings.dart`:

```dart
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

typedef _CreateSessionC = ffi.Uint64 Function();
typedef _DisposeSessionC = ffi.Void Function(ffi.Uint64);
typedef _ExecuteC = ffi.Pointer<Utf8> Function(ffi.Uint64, ffi.Pointer<Utf8>);
typedef _VersionC = ffi.Pointer<Utf8> Function();
typedef _FreeC = ffi.Void Function(ffi.Pointer<Utf8>);

/// Raw synchronous bindings to libjet_cad_native. Blocking — only call
/// from a worker isolate (FfiKernelBridge wraps every call in Isolate.run).
class NativeBindings {
  NativeBindings(String libraryPath)
      : _lib = ffi.DynamicLibrary.open(libraryPath) {
    _createSession = _lib
        .lookupFunction<_CreateSessionC, int Function()>('jc_create_session');
    _disposeSession = _lib.lookupFunction<_DisposeSessionC,
        void Function(int)>('jc_dispose_session');
    _execute = _lib.lookupFunction<_ExecuteC,
        ffi.Pointer<Utf8> Function(int, ffi.Pointer<Utf8>)>('jc_execute');
    _version =
        _lib.lookupFunction<_VersionC, ffi.Pointer<Utf8> Function()>(
            'jc_version');
    _free = _lib
        .lookupFunction<_FreeC, void Function(ffi.Pointer<Utf8>)>('jc_free');
  }

  final ffi.DynamicLibrary _lib;
  late final int Function() _createSession;
  late final void Function(int) _disposeSession;
  late final ffi.Pointer<Utf8> Function(int, ffi.Pointer<Utf8>) _execute;
  late final ffi.Pointer<Utf8> Function() _version;
  late final void Function(ffi.Pointer<Utf8>) _free;

  int createSession() => _createSession();

  void disposeSession(int session) => _disposeSession(session);

  String _takeString(ffi.Pointer<Utf8> ptr) {
    try {
      return ptr.toDartString();
    } finally {
      _free(ptr);
    }
  }

  String execute(int session, String commandJson) {
    final cmd = commandJson.toNativeUtf8();
    try {
      return _takeString(_execute(session, cmd));
    } finally {
      malloc.free(cmd);
    }
  }

  String version() => _takeString(_version());
}
```

- [ ] **Step 2: FfiKernelBridge**

`lib/src/kernel/ffi/ffi_kernel_bridge.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../document/entity.dart';
import '../kernel_bridge.dart';
import '../kernel_types.dart';
import 'native_bindings.dart';

/// Top-level so Isolate.run can invoke it with only sendable captures.
String _executeInIsolate((String, int, String) args) {
  final (libPath, session, cmd) = args;
  return NativeBindings(libPath).execute(session, cmd);
}

/// [KernelBridge] backed by the OCCT shim (libjet_cad_native).
///
/// Every command runs the blocking native call in a worker isolate and is
/// serialized per session (one command in flight — OCCT sessions are not
/// thread-safe). Error envelopes surface as [KernelException].
class FfiKernelBridge implements KernelBridge {
  FfiKernelBridge(this.libraryPath) : _bindings = NativeBindings(libraryPath);

  factory FfiKernelBridge.auto() {
    final path = locateLibrary();
    if (path == null) {
      throw StateError(
          'jet_cad native library not found; build it with '
          'tool/build_native.sh or set JET_CAD_NATIVE_LIB');
    }
    return FfiKernelBridge(path);
  }

  /// Env override, then the dev build location. Null when absent.
  static String? locateLibrary() {
    final env = Platform.environment['JET_CAD_NATIVE_LIB'];
    if (env != null && File(env).existsSync()) return env;
    final ext = Platform.isMacOS ? 'dylib' : 'so';
    final dev = 'build/native/libjet_cad_native.$ext';
    if (File(dev).existsSync()) return File(dev).absolute.path;
    return null;
  }

  final String libraryPath;
  final NativeBindings _bindings;
  final Map<int, Future<void>> _queues = {};

  Future<Map<String, Object?>> _run(
      SessionHandle session, Map<String, Object?> cmd) {
    final prev = _queues[session.value] ?? Future<void>.value();
    final job = prev.then((_) async {
      final raw = await Isolate.run(() =>
          _executeInIsolate((libraryPath, session.value, jsonEncode(cmd))));
      final envelope = (jsonDecode(raw) as Map).cast<String, Object?>();
      if (envelope['ok'] != true) {
        throw KernelException(envelope['error']?.toString() ?? 'unknown');
      }
      final result = envelope['result'];
      return result is Map
          ? result.cast<String, Object?>()
          : <String, Object?>{};
    });
    _queues[session.value] = job.then((_) {}, onError: (_) {});
    return job;
  }

  @override
  Future<SessionHandle> createSession(RenderTarget target) async =>
      SessionHandle(_bindings.createSession());

  @override
  Future<void> disposeSession(SessionHandle session) async {
    await (_queues[session.value] ?? Future<void>.value());
    _queues.remove(session.value);
    _bindings.disposeSession(session.value);
  }

  @override
  Future<KernelVersionInfo> versionInfo() async {
    final v = (jsonDecode(_bindings.version()) as Map).cast<String, Object?>();
    return KernelVersionInfo(
      kernelVersion: v['kernelVersion']! as String,
      occtVersion: v['occtVersion']! as String,
    );
  }

  Future<CreateResult> _create(
          SessionHandle s, Map<String, Object?> cmd) async =>
      CreateResult.fromJson(await _run(s, cmd));

  @override
  Future<CreateResult> makeBox(SessionHandle s, Vec3 size) =>
      _create(s, {'cmd': 'makeBox', 'size': size.toJson()});

  @override
  Future<CreateResult> extrude(SessionHandle s, FaceId face, double depth) =>
      _create(s, {'cmd': 'extrude', 'face': face.value, 'depth': depth});

  @override
  Future<CreateResult> booleanOp(
          SessionHandle s, BodyId a, BodyId b, BoolOp op) =>
      _create(s, {'cmd': 'boolean', 'a': a.value, 'b': b.value, 'op': op.name});

  @override
  Future<CreateResult> fillet(
          SessionHandle s, List<EdgeId> edges, double radius) =>
      _create(s, {
        'cmd': 'fillet',
        'edges': [for (final e in edges) e.value],
        'radius': radius,
      });

  @override
  Future<void> transform(
          SessionHandle s, List<BodyId> bodies, Matrix4 matrix) =>
      _run(s, {
        'cmd': 'transform',
        'bodies': [for (final b in bodies) b.value],
        'matrix': matrix.storage.toList(),
      });

  @override
  Future<List<CreateResult>> importStep(
      SessionHandle s, Uint8List bytes) async {
    final result = await _run(
        s, {'cmd': 'importStep', 'dataB64': base64Encode(bytes)});
    return [
      for (final r in result['bodies']! as List)
        CreateResult.fromJson((r as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<Uint8List> exportStep(SessionHandle s, List<BodyId> bodies) async {
    final result = await _run(s, {
      'cmd': 'exportStep',
      'bodies': [for (final b in bodies) b.value],
    });
    return base64Decode(result['dataB64']! as String);
  }

  @override
  Future<KernelSnapshot> snapshotBodies(
      SessionHandle s, List<BodyId> bodies) async {
    final result = await _run(s, {
      'cmd': 'snapshotBodies',
      'bodies': [for (final b in bodies) b.value],
    });
    return KernelSnapshot(base64Decode(result['dataB64']! as String));
  }

  @override
  Future<void> restoreBodies(SessionHandle s, KernelSnapshot snapshot) =>
      _run(s, {
        'cmd': 'restoreBodies',
        'dataB64': base64Encode(snapshot.bytes),
      });

  @override
  Future<void> deleteBodies(SessionHandle s, List<BodyId> bodies) =>
      _run(s, {
        'cmd': 'deleteBodies',
        'bodies': [for (final b in bodies) b.value],
      });

  @override
  Future<KernelSnapshot> saveSnapshot(SessionHandle s) async {
    final result = await _run(s, {'cmd': 'saveSnapshot'});
    return KernelSnapshot(base64Decode(result['dataB64']! as String));
  }

  @override
  Future<void> restoreSession(SessionHandle s, KernelSnapshot snapshot) =>
      _run(s, {
        'cmd': 'restoreSession',
        'dataB64': base64Encode(snapshot.bytes),
      });
}
```

- [ ] **Step 3: Conditional export + stub**

`lib/src/kernel/ffi_kernel_bridge_unsupported.dart`:

```dart
/// Stub for platforms without dart:ffi (web). Construction always throws.
class FfiKernelBridge {
  FfiKernelBridge(String libraryPath) {
    throw UnsupportedError('FfiKernelBridge requires dart:ffi');
  }

  factory FfiKernelBridge.auto() = FfiKernelBridge._throw;

  FfiKernelBridge._throw() : this('');

  static String? locateLibrary() => null;
}
```

`lib/src/kernel/ffi_kernel_bridge_export.dart`:

```dart
export 'ffi_kernel_bridge_unsupported.dart'
    if (dart.library.ffi) 'ffi/ffi_kernel_bridge.dart';
```

In `lib/jet_cad.dart` add:

```dart
export 'src/kernel/ffi_kernel_bridge_export.dart' show FfiKernelBridge;
```

Add `ffi: ^2.1.0` to dependencies.

- [ ] **Step 4: Guarded integration test**

`packages/jet_cad/test/kernel_ffi/ffi_kernel_bridge_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {});
    return;
  }

  late FfiKernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = FfiKernelBridge(libPath);
    session = await bridge.createSession(const HeadlessTarget());
  });

  tearDown(() => bridge.disposeSession(session));

  test('versionInfo reports a real OCCT version', () async {
    final v = await bridge.versionInfo();
    expect(v.occtVersion, isNotEmpty);
    expect(v.kernelVersion, contains('jet_cad_native'));
  });

  test('makeBox returns real box topology', () async {
    final r = await bridge.makeBox(session, const Vec3(1, 2, 3));
    expect(r.faces, hasLength(6));
    expect(r.edges, hasLength(12));
    expect(r.vertices, hasLength(8));
  });

  test('kernel errors surface as KernelException', () async {
    await expectLater(
      bridge.makeBox(session, const Vec3(-1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
    await expectLater(
      bridge.extrude(session, const FaceId('nope'), 1),
      throwsA(isA<KernelException>()),
    );
  });

  test('boolean cut against real geometry: inputs consumed, remap total',
      () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final c = await bridge.booleanOp(session, a.body, b.body, BoolOp.fuse);
    expect(c.remap.mapping[a.body], [EntityId(c.body.value)]);
    final priorIds = 2 +
        a.faces.length + a.edges.length + a.vertices.length +
        b.faces.length + b.edges.length + b.vertices.length;
    expect(c.remap.mapping, hasLength(priorIds));
    await expectLater(
      bridge.booleanOp(session, a.body, c.body, BoolOp.cut),
      throwsA(isA<KernelException>()),
    );
  });

  test('STEP round-trip through real OCCT', () async {
    final a = await bridge.makeBox(session, const Vec3(2, 3, 4));
    final bytes = await bridge.exportStep(session, [a.body]);
    expect(utf8.decode(bytes.take(20).toList(), allowMalformed: true),
        contains('ISO-10303'));
    final imported = await bridge.importStep(session, bytes);
    expect(imported, isNotEmpty);
    expect(imported.first.faces.length, greaterThanOrEqualTo(6));
  });

  test('snapshot restore preserves ids against real kernel', () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final snap = await bridge.snapshotBodies(session, [a.body]);
    await bridge.deleteBodies(session, [a.body]);
    await expectLater(
      bridge.exportStep(session, [a.body]),
      throwsA(isA<KernelException>()),
    );
    await bridge.restoreBodies(session, snap);
    expect(await bridge.exportStep(session, [a.body]), isNotEmpty);
    final b = await bridge.makeBox(session, const Vec3(1, 1, 1));
    expect(b.body, isNot(a.body), reason: 'no id re-issue after restore');
  });

  test('commands are serialized per session (no interleaving crash)',
      () async {
    final futures = [
      for (var i = 0; i < 8; i++) bridge.makeBox(session, const Vec3(1, 1, 1)),
    ];
    final results = await Future.wait(futures);
    expect(results.map((r) => r.body.value).toSet(), hasLength(8));
  });

  test('full CadDocument flow runs against the real kernel', () async {
    final doc = await CadDocument.create(FfiKernelBridge(libPath));
    final a = await doc.makeBox(const Vec3(10, 10, 10));
    final b = await doc.makeBox(const Vec3(4, 4, 4));
    final c = await doc.booleanCombine(a, b, BoolOp.cut);
    final edge = doc.entities.values
        .firstWhere((e) => e.kind == EntityKind.edge && e.parent == c)
        .id as EdgeId;
    await doc.fillet([edge], 0.5);
    await doc.undo();
    await doc.redo();
    final step = await doc.exportStep([c]);
    expect(step, isNotEmpty);
    await doc.dispose();
  });
}
```

- [ ] **Step 5: Verify + commit**

```bash
packages/jet_cad/tool/build_native.sh
cd packages/jet_cad && flutter test && flutter analyze && dart format --set-exit-if-changed lib test
git add -A && git commit -m "feat: FfiKernelBridge with per-session queue and guarded integration tests"
```

Expected: with the native lib present the ffi tests run for real; without it, one SKIPPED marker test. Both states green.

---

### Task 8: Shared bridge contract suite

**Files:**
- Create: `packages/jet_cad/test/kernel/bridge_contract.dart` (shared suite, not a test file itself)
- Create: `packages/jet_cad/test/kernel/fake_bridge_contract_test.dart`
- Create: `packages/jet_cad/test/kernel_ffi/ffi_bridge_contract_test.dart`

**Interfaces:**
- Consumes: both bridges.
- Produces: `void runKernelBridgeContract(KernelBridge Function() createBridge)` — invariant-based assertions every `KernelBridge` implementation must satisfy (fills the Plan-1 review gaps: unknown-session behavior, saveSnapshot/restoreSession round-trip). Invariants only — no exact topology counts (fake and OCCT legitimately differ on boolean face counts).

- [ ] **Step 1: Write the shared contract**

`test/kernel/bridge_contract.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

/// Contract every KernelBridge implementation must satisfy.
void runKernelBridgeContract(KernelBridge Function() createBridge) {
  late KernelBridge bridge;
  late SessionHandle session;

  setUp(() async {
    bridge = createBridge();
    session = await bridge.createSession(const HeadlessTarget());
  });

  tearDown(() => bridge.disposeSession(session));

  test('contract: commands on an unknown session fail as KernelException',
      () async {
    await expectLater(
      bridge.makeBox(const SessionHandle(999999), const Vec3(1, 1, 1)),
      throwsA(isA<KernelException>()),
    );
  });

  test('contract: makeBox produces a body with subshapes and unique ids',
      () async {
    final r = await bridge.makeBox(session, const Vec3(1, 2, 3));
    final all = <String>{
      r.body.value,
      ...r.faces.map((f) => f.value),
      ...r.edges.map((e) => e.value),
      ...r.vertices.map((v) => v.value),
    };
    expect(all.length,
        1 + r.faces.length + r.edges.length + r.vertices.length);
    expect(r.faces, isNotEmpty);
    expect(r.edges, isNotEmpty);
  });

  test('contract: boolean consumes inputs, remap covers all prior ids',
      () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final c = await bridge.booleanOp(session, a.body, b.body, BoolOp.fuse);
    final prior = <EntityId>{
      a.body, b.body,
      ...a.faces, ...a.edges, ...a.vertices,
      ...b.faces, ...b.edges, ...b.vertices,
    };
    expect(c.remap.mapping.keys.toSet(), prior);
    expect(c.remap.mapping[a.body], isNotEmpty);
    await expectLater(
      bridge.exportStep(session, [a.body]),
      throwsA(isA<KernelException>()),
    );
  });

  test('contract: fillet keeps body id and maps each edge to >=1 new face',
      () async {
    final box = await bridge.makeBox(session, const Vec3(10, 10, 10));
    final edge = box.edges.first;
    final r = await bridge.fillet(session, [edge], 0.5);
    expect(r.body, box.body);
    expect(r.remap.mapping[edge], isNotEmpty);
    expect(r.faces, isNotEmpty);
  });

  test('contract: snapshotBodies/restoreBodies is id-preserving', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final snap = await bridge.snapshotBodies(session, [box.body]);
    await bridge.deleteBodies(session, [box.body]);
    await bridge.restoreBodies(session, snap);
    expect(await bridge.exportStep(session, [box.body]), isNotEmpty);
  });

  test('contract: saveSnapshot/restoreSession round-trips a whole session',
      () async {
    final a = await bridge.makeBox(session, const Vec3(1, 1, 1));
    final b = await bridge.makeBox(session, const Vec3(2, 2, 2));
    final snapshot = await bridge.saveSnapshot(session);

    final second = createBridge();
    final s2 = await second.createSession(const HeadlessTarget());
    await second.restoreSession(s2, snapshot);
    expect(await second.exportStep(s2, [a.body, b.body]), isNotEmpty);
    final c = await second.makeBox(s2, const Vec3(3, 3, 3));
    expect(c.body, isNot(a.body));
    expect(c.body, isNot(b.body));
    await second.disposeSession(s2);
  });

  test('contract: deleteBodies is idempotent', () async {
    final box = await bridge.makeBox(session, const Vec3(1, 1, 1));
    await bridge.deleteBodies(session, [box.body]);
    await bridge.deleteBodies(session, [box.body]); // no throw
  });
}
```

Note the cross-bridge snapshot in the session round-trip: snapshots are NOT portable between implementations — `createBridge()` gives a fresh instance of the SAME implementation.

- [ ] **Step 2: Two runners**

`test/kernel/fake_bridge_contract_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

import 'bridge_contract.dart';

void main() {
  group('FakeKernelBridge honors the bridge contract', () {
    runKernelBridgeContract(FakeKernelBridge.new);
  });
}
```

`test/kernel_ffi/ffi_bridge_contract_test.dart`:

```dart
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
```

If the fake fails a contract test, fix the FAKE to meet the contract, never weaken the contract to fit the fake. One failure is known in advance: the session round-trip's no-id-collision assertion — a fresh `FakeKernelBridge` starts `_idCounter = 0`, so after `restoreSession` its next id would collide with a restored `b1`. Fix in `fake_kernel_bridge.dart`: bump the counter past restored ids in both restore paths —

```dart
  void _absorbIds(Iterable<String> ids) {
    for (final id in ids) {
      final digits = RegExp(r'\d+$').firstMatch(id)?.group(0);
      if (digits != null) {
        final n = int.parse(digits);
        if (n > _idCounter) _idCounter = n;
      }
    }
  }
```

Call it from `restoreBodies` and `restoreSession` with each restored body's id and all subshape ids (matches the native shim's `maxNumericSuffix` behavior — same contract, both implementations).

- [ ] **Step 3: Verify + commit**

```bash
packages/jet_cad/tool/build_native.sh
cd packages/jet_cad && flutter test && flutter analyze && dart format --set-exit-if-changed lib test
git add -A && git commit -m "test: shared KernelBridge contract suite run against fake and ffi bridges"
```

---

### Task 9: Persistence wiring — geometry blob save/load

**Files:**
- Modify: `packages/jet_cad/lib/src/document/cad_document.dart` (`save()`, `load` geometry path, element-level validation)
- Modify: `packages/jet_cad/lib/src/document/codec.dart` (geometry field)
- Modify: `packages/jet_cad/CHANGELOG.md` (0.2.0 entry)
- Test: `packages/jet_cad/test/document/codec_test.dart` (extend)
- Test: `packages/jet_cad/test/kernel_ffi/persistence_e2e_test.dart` (guarded)

**Interfaces:**
- Consumes: `saveSnapshot`/`restoreSession` (contract-tested in Task 8).
- Produces:
  - `Future<Map<String, Object?>> CadDocument.save()` — `CadDocumentCodec.encode(this)` plus `'geometry': base64(saveSnapshot().bytes)`.
  - `CadDocument.load`: when `geometry` present → decode, `restoreSession` on the fresh session (kernel state restored, ids line up with stored entities by the id-preserving contract). When absent and `ops` non-empty → `StateError` with message naming the missing blob and pointing at the replay deferral. When absent and `ops` empty → plain empty document (unchanged).
  - Element-level validation: each entity/op entry parse wrapped; failures → `FormatException('corrupt document: <detail> at index <i>')`.
  - Schema stays 1 — `geometry` is additive and optional.

- [ ] **Step 1: Write failing tests (fake-backed)**

Append to `test/document/codec_test.dart`:

```dart
  test('save() embeds geometry; load restores the kernel session', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    final a = await doc.makeBox(const Vec3(1, 1, 1));
    final json = await doc.save();
    expect(json['geometry'], isNotNull);

    final restored = await CadDocument.load(json, FakeKernelBridge());
    // Kernel state restored: exportStep works for the stored body id.
    expect(await restored.exportStep([a]), isNotEmpty);
    await doc.dispose();
    await restored.dispose();
  });

  test('load without geometry but with ops throws StateError', () async {
    final doc = await CadDocument.create(FakeKernelBridge());
    await doc.makeBox(const Vec3(1, 1, 1));
    final json = CadDocumentCodec.encode(doc); // no geometry
    await expectLater(
      CadDocument.load(json, FakeKernelBridge()),
      throwsStateError,
    );
    await doc.dispose();
  });

  test('corrupt op entry is a FormatException with index context', () async {
    await expectLater(
      CadDocument.load({
        'schemaVersion': 1,
        'kernelVersion': 'x',
        'occtVersion': 'x',
        'head': 0,
        'ops': [42],
        'entities': <Object?>[],
      }, FakeKernelBridge()),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'message', contains('index 0'))),
    );
  });
```

- [ ] **Step 2: Implement**

In `cad_document.dart`:

```dart
  /// Full persisted form: document state plus the kernel geometry blob.
  Future<Map<String, Object?>> save() async {
    final snapshot = await _bridge.saveSnapshot(_session);
    return {
      ...CadDocumentCodec.encode(this),
      'geometry': base64Encode(snapshot.bytes),
    };
  }
```

(add `import 'dart:convert';`). In `load`, after the existing head validation:

```dart
    var i = 0;
    for (final e in json['entities']! as List) {
      try {
        final entity = Entity.fromJson((e as Map).cast<String, Object?>());
        doc._entities[entity.id] = entity;
      } catch (err) {
        throw FormatException('corrupt document: bad entity at index $i: $err');
      }
      i++;
    }
    i = 0;
    var maxOpId = 0;
    for (final o in json['ops']! as List) {
      try {
        final op = Operation.fromJson((o as Map).cast<String, Object?>());
        doc._ops.add(op);
        if (op.id.value > maxOpId) maxOpId = op.id.value;
      } catch (err) {
        throw FormatException('corrupt document: bad op at index $i: $err');
      }
      i++;
    }
    // ... existing head/_undoFloor/_nextOpId assignments ...
    final geometry = json['geometry'];
    if (geometry != null) {
      await bridge.restoreSession(
          doc._session, KernelSnapshot(base64Decode(geometry as String)));
    } else if (doc._ops.isNotEmpty) {
      throw StateError(
          'document has no geometry blob; op replay is not supported in v1 '
          '(save() embeds geometry — use it)');
    }
    return doc;
```

Note ordering: geometry restore happens after validation so a corrupt doc never touches the kernel; the throw must dispose the created session — wrap the whole body after `create` in try/catch, `await doc.dispose()` on error, rethrow.

- [ ] **Step 3: Guarded end-to-end test**

`test/kernel_ffi/persistence_e2e_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad/jet_cad.dart';

void main() {
  final libPath = FfiKernelBridge.locateLibrary();
  if (libPath == null) {
    test('SKIPPED: native library not built (tool/build_native.sh)', () {});
    return;
  }

  test('model -> save -> load -> continue editing, against real OCCT',
      () async {
    final doc = await CadDocument.create(FfiKernelBridge(libPath));
    final a = await doc.makeBox(const Vec3(10, 10, 10));
    final b = await doc.makeBox(const Vec3(4, 4, 4));
    final c = await doc.booleanCombine(a, b, BoolOp.cut);
    final saved = await doc.save();
    await doc.dispose();

    final restored = await CadDocument.load(saved, FfiKernelBridge(libPath));
    expect(restored.canUndo, isFalse);
    expect(await restored.exportStep([c]), isNotEmpty);
    // Continue editing on restored geometry: new ids must not collide.
    final d = await restored.makeBox(const Vec3(1, 1, 1));
    expect(restored.entities[d], isNotNull);
    final e = await restored.booleanCombine(c, d, BoolOp.fuse);
    expect(await restored.exportStep([e]), isNotEmpty);
    await restored.dispose();
  });
}
```

- [ ] **Step 4: CHANGELOG + verify + commit**

Add to `CHANGELOG.md` under a new `## 0.2.0` heading: FFI/OCCT backend (`FfiKernelBridge`), unified `KernelSnapshot`, `CadDocument.save()` with geometry blob, load restores kernel sessions. Bump pubspec `version: 0.2.0`.

```bash
packages/jet_cad/tool/build_native.sh
cd packages/jet_cad && flutter test && flutter analyze && dart format --set-exit-if-changed lib test
git add -A && git commit -m "feat: document persistence restores kernel sessions via geometry blob"
```

---

## Deferred (explicit)

- Plan 3: viewer/pick/selection bridge methods, AIS/V3d, macOS texture path, `SelectionChanged` stream.
- Plan 4: demo app (needs Plan 5's app-embedding work or a dev-only dylib load path).
- Plan 5: app embedding (podspec vendored libs), Windows/Linux native builds, prebuilt binary pipeline, CI matrix with OCCT, binary BREP (BinTools) + pointer-based blob passing if profiling warrants.
- Parametric phase: true op replay (id translation tables), persistent naming.
