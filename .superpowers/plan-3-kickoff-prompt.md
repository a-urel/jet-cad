Write and execute Plan 3 (viewport) for jet-cad.

## Where things stand

- Repo: /Users/ahmeturel/Projects/oss/jet-cad — Flutter CAD package `packages/jet_cad`, OCCT-backed.
- Architecture spec (frozen v1.0, binding): docs/superpowers/specs/2026-07-12-jet-cad-architecture-design.md
- Plan 1 (pure-Dart document model) and Plan 2 (native OCCT session + FFI bridge) are both merged to main (head b17dbdf). 81 Dart tests (FFI tests auto-skip without the native lib) + 18 native GoogleTests, analyze/format clean. Local main is ahead of origin — do not push unless I say so.
- Prior plans (use as the format/quality bar — complete code per step, TDD, exact commands): docs/superpowers/plans/2026-07-12-01-scaffold-and-document-model.md and 2026-07-12-02-native-occt-ffi-bridge.md
- Execution history + carry-overs ledger: .superpowers/sdd/progress.md (git-ignored, read it)
- Native dev build: `packages/jet_cad/tool/build_native.sh` (OCCT 7.9.3 via Homebrew, CMake 4.4, macOS arm64). Native code lives in packages/jet_cad/src/native/ (5-symbol C ABI, generic JSON command dispatch via jc_execute).

## Task

1. Use superpowers:writing-plans to write Plan 3 to docs/superpowers/plans/ — scope: the interactive viewport. Propose the plan-level task split for my approval first (AskUserQuestion), write the full plan, self-review, commit, then offer execution options.
2. On my approval, execute with superpowers:subagent-driven-development on a feature branch off main (fresh subagent per task, per-task reviewer, final whole-branch review on the most capable model, fix loops until approved). Continue the ledger. Real transcripts only — synthesized test output is a firing offense; reviewers verify claims independently.

## Locked decisions (spec + prior review rounds — do not relitigate)

- macOS first. OCCT's own AIS/V3d renderer, offscreen, composited via Flutter external texture: CGL/OpenGL offscreen FBO on an IOSurface → CVPixelBuffer → FlutterTexture (Metal side). Context creation isolated in one platform module (ANGLE swap-in must stay cheap). Windows/Linux/mobile/web deferred.
- Native side needs new OCCT toolkits (TKOpenGl, TKV3d, TKService) and real Flutter plugin registration on macOS (macos/Classes podspec path was fixed in Plan 1; actual texture plumbing is new work). The riskiest plumbing (IOSurface/GL/FlutterTexture spike) should be an early task, not a late one.
- `JetCadViewport` widget + `ViewportController`. SelectionChanged is a ViewportController stream event, NOT a DocChange; selection never enters the document or undo (spec rule).
- KernelBridge grows viewer/pick/selection methods (interface is explicitly not frozen — additive change; update FakeKernelBridge AND the shared contract suite in test/kernel/bridge_contract.dart for every new method). RenderTarget is a sealed class — add a TextureTarget alongside HeadlessTarget.
- Damage-driven redraw only (render on command completion / camera change / selection change — never per-vsync). Resize + devicePixelRatio reallocate the texture, debounced.
- Package stays headless-first: viewport + controller only. No toolbars/panels/UI opinions — demo app is Plan 4. A minimal throwaway dev-harness app for manual on-screen verification is acceptable if needed; keep it out of the package's public surface.

## Carry-overs to fold into Plan 3 (from Plan 2's final review — in the ledger)

- Per-command Isolate.run + dlopen is too slow for a render loop: move FfiKernelBridge to one long-lived worker isolate per bridge (or justify why viewer commands take a different path).
- Tighten bridge contract: fillet result edges/vertices non-empty; idempotent disposeSession should join the in-flight dispose future.
- 1:N fillet split-face test fixture if selection work creates richer fixtures anyway.

## Known OCCT 7.9.3 gotchas (learned in Plan 2, don't rediscover)

- gp_Trsf::SetValues silently orthogonalizes non-rigid matrices (no throw) — raw-matrix checks are the pattern.
- STEP toolkits are TKDESTEP on 7.8+ (CMake branch already handles it).
- BRepTools ASCII round-trip preserves TopExp enumeration order (positional id zip relies on this).
- gtest needs DISCOVERY_TIMEOUT 60 (cold dyld cost across ~24 OCCT dylibs).

## Definition of Done (every task)

flutter analyze clean; full flutter test green in BOTH states (native lib present / absent — guarded tests skip via markTestSkipped); dart format lib test no diff; tool/build_native.sh exit 0 with all ctest green for native tasks; no TODOs; conventional commits ending with the Co-Authored-By trailer the repo's git log shows.
