### Task 1: Dependencies and the API boundary check

**Files:**
- Modify: `packages/jet_cad_2d_plan/pubspec.yaml` (add `shadcn_ui: ^0.57.1`,
  `lucide_icons_flutter: ^3.1.25`; `environment.sdk: ^3.11.0`)
- Modify: `apps/dev_harness/pubspec.yaml` (`shadcn_ui: ^0.57.1`,
  `sdk: ^3.11.0`, `flutter: ">=3.41.0"`), and its `lib/` if 0.56/0.57
  broke anything
- Create: `tool/ci/lib/api_boundary.dart`, `tool/ci/check_api_boundary.dart`
- Test: `tool/ci/test/api_boundary_test.dart`
- Modify: `.github/workflows/ci.yml` (run `dart run tool/ci/check_api_boundary.dart` beside `check_guide.dart`)

**Interfaces:**
- Produces: `List<String> apiBoundaryProblems(LibraryElement barrel, {Set<String> forbiddenPackages = const {'shadcn_ui', 'lucide_icons_flutter'}})`
  — one problem per exported element whose public member type, parameter,
  return type, type argument, bound or supertype (transitively through
  exported types only) is declared in a forbidden package; the problem
  names the element, the member and the type. Resolved the way
  `tool/ci/lib/guide.dart` resolves (read it first).

- [ ] **Step 1: Resolve the workspace.** `flutter pub get` at the root; it
  must resolve `shadcn_ui 0.57.1` with no override. If `intl` or another
  transitive pin conflicts, report it to the controller; do not override.
- [ ] **Step 2: Write failing tests** in `api_boundary_test.dart`:
  `AB1 a clean barrel has no problems` (a fixture package in a temp dir
  exporting a class with `Widget`/`IconData` members → `[]`);
  `AB2 a Shad-typed public field is a problem` (fixture with
  `final ShadThemeData theme;` → one problem naming the field);
  `AB3 a Shad supertype is a problem`; `AB4 a Shad type argument in a
  return type is a problem` (`List<ShadOption> f()`); `AB5 a private member
  is not`; `AB6 the real jet_cad_2d_plan barrel is clean`.
- [ ] **Step 3: Run** `cd tool/ci && dart test test/api_boundary_test.dart` → AB1–AB5 FAIL (no function).
- [ ] **Step 4: Implement** `apiBoundaryProblems` and the CLI (exit 1 with the problems listed).
- [ ] **Step 5: Run** the test → PASS; `dart run tool/ci/check_api_boundary.dart` → prints no problem, exit 0.
- [ ] **Step 6: Mutation** M-AB: add `final ShadThemeData? shad = null;` to
  `PlanEditor` → the CLI and AB6 go red; revert.
- [ ] **Step 7: dev_harness green:** `cd apps/dev_harness && flutter analyze && flutter test`.
- [ ] **Step 8: All gates** (Global Constraints) and `dart run tool/ci/check_host_lock.dart` on the probe as CI does; commit
  `build(plan): shadcn_ui ^0.57.1 and the API boundary check`.

