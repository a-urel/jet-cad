### Task 6: `apps/floor_planner` — the scaffold, the workspace, the window

**Files:**
- Create: `apps/floor_planner/` (via `flutter create`)
- Modify: `pubspec.yaml` (root; `workspace:`)
- Modify: `apps/floor_planner/pubspec.yaml`
- Modify: `apps/floor_planner/macos/Runner/Base.lproj/MainMenu.xib`
- Modify: `.vscode/launch.json`

**Interfaces:**
- Produces: a workspace member that builds for macOS and web with the
  generated counter app still in `lib/main.dart` (Task 8 replaces it).
  Tasks 7–8 depend on the pubspec's dependencies.

- [ ] **Step 1: Create**

```sh
cd apps && flutter create --org dev.jetcad --project-name floor_planner --platforms macos,web floor_planner
cd floor_planner && rm -f README.md test/widget_test.dart && ls
```

- [ ] **Step 2: The pubspec**

Replace `apps/floor_planner/pubspec.yaml` with:

```yaml
name: floor_planner
description: >-
  The floor planner product application. Hosts a DraftCanvas behind a
  CameraGestureDetector, with empty chrome slots that later sub-projects
  fill. Not an instrument: the measurement harness is apps/dev_harness_2d.
publish_to: none
version: 0.0.1
resolution: workspace

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  jet_cad_2d:
    path: ../../packages/jet_cad_2d
  jet_cad_2d_flutter:
    path: ../../packages/jet_cad_2d_flutter
  vector_math: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

If `flutter create` pinned a different `flutter_lints` major, keep the
generated one. Add to the root `pubspec.yaml`'s `workspace:` list, after
`- apps/dev_harness_2d`:

```yaml
  - apps/floor_planner
```

Then `cd /path/to/worktree && flutter pub get`, and
`git status --short` — restore any rewritten `analysis_options.yaml` under
`packages/` or `apps/dev_harness_2d` with `git checkout --`. The app's own
generated `analysis_options.yaml` stays as generated (Ruling 01-1).

- [ ] **Step 3: The window (spec D7)**

In `apps/floor_planner/macos/Runner/Base.lproj/MainMenu.xib` there is one
line `<rect key="contentRect" x="335" y="390" width="800" height="600"/>`.
Change it to:

```xml
            <rect key="contentRect" x="335" y="390" width="1440" height="900"/>
```

`MainFlutterWindow.swift` is **not** edited; it reads this frame from the
nib. `isRestorable` is left at its default. Confirm with
`git diff --stat -- apps/floor_planner/macos` that the xib is the only
change under `macos/` besides generation.

- [ ] **Step 4: Build both targets as generated**

```sh
cd apps/floor_planner && flutter build macos --debug 2>&1 | tail -3 && flutter build web 2>&1 | tail -3
```

Expected: both `✓ Built`. **This is the first web build of
`jet_cad_2d_flutter` in this repository's history** (spec D6) — the counter
app does not yet import it, so the real test is Task 8's; if *this* build
fails, the failure is the scaffold's, not the package's.

- [ ] **Step 5: The launch entry**

In `.vscode/launch.json`, append to `configurations` (after the last
existing entry):

```json
        {
            // The product application, sub-project 01. Not an instrument:
            // nothing here is measured, and F5 should keep landing on the
            // harness entries above it.
            "name": "floor_planner: macOS",
            "cwd": "apps/floor_planner",
            "program": "lib/main.dart",
            "request": "launch",
            "type": "dart",
            "deviceId": "macos"
        }
```

- [ ] **Step 6: Commit**

```sh
git status --short
git add pubspec.yaml apps/floor_planner .vscode/launch.json
git commit -m "build(floor_planner): scaffold the product app as a workspace member, 1440x900 window"
```

The generated `apps/floor_planner/analysis_options.yaml` is in this commit
and in no later one (Ruling 01-1).

---

