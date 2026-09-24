### Task 5: `PlacementTool.commit` checks a capability set

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:217-225`
- Test: `packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart`

**Interfaces:**
- Produces: `bool commit(ToolContext ctx, DraftCommand Function() build,
  {Set<Capability> needs = const {Capability.geometry}})`. The
  permissions are checked for every member before `build` runs.

- [ ] **Step 1: Write CN1–CN2.** Use the existing draw fixture
  (`test/support/draw_fixture.dart`) to get a `ToolContext`. Read it first
  and use its rig builder's real name. The test subclass:

```dart
// packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/draw_fixture.dart';

class _Probe extends RectangleTool {
  int builds = 0;
  bool run(ToolContext ctx, Set<Capability> needs) => commit(ctx, () {
        builds++;
        return CompoundCommand(const [], label: 'never');
      }, needs: needs);
}

void main() {
  testWidgets('CN1 a denied member of needs stops the build (M-06u)',
      (tester) async {
    final rig = await drawRig(tester); // the fixture's rig; adapt the name
    rig.doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: true, structure: false);
    final probe = _Probe();
    expect(probe.run(rig.ctx, {Capability.structure, Capability.geometry}),
        isFalse);
    expect(probe.builds, 0);
  });

  testWidgets('CN2 the default is geometry alone, as in 05', (tester) async {
    final rig = await drawRig(tester);
    rig.doc.commands.permissions = const DraftPermissions(
        transform: true, components: true, geometry: false, structure: true);
    final probe = _Probe();
    expect(probe.run(rig.ctx, const {Capability.geometry}), isFalse);
    expect(probe.builds, 0);
  });
}
```

The `CompoundCommand(const [], …)` throws if it is ever built. Neither
test may reach it; a build shows up as that `ArgumentError`. Adapt `rig.doc`
and `rig.ctx` to the fixture's real field names.

- [ ] **Step 2: Run the tests; CN1 fails to compile** (`needs` does not
  exist).
- [ ] **Step 3: Implement.**

```dart
  /// Ruling 05-3: the permission check runs before [build], so a denied
  /// shape allocates no handle. [needs] is every capability the built
  /// command will need (spec 06 D13, Ruling 06-10); 05's shapes need
  /// geometry alone. Returns whether the command ran.
  bool commit(ToolContext ctx, DraftCommand Function() build,
      {Set<Capability> needs = const {Capability.geometry}}) {
    final permissions = ctx.document.commands.permissions;
    if (!needs.every(permissions.allows)) return false;
    ctx.execute(build());
    return true;
  }
```

- [ ] **Step 4: Run the render line.**
- [ ] **Step 5: Commit.**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart packages/jet_cad_2d_flutter/test/draw/commit_needs_test.dart
git commit -m "$(cat <<'EOF'
feat(render): PlacementTool.commit checks a capability set (spec 06 D13)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

