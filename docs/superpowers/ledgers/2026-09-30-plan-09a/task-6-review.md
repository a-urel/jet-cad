# Task 6 review (ba812dd + 22bc83d) - independent

Verdict: Approved (one info-level observation, no blocking/major/minor defect).

Gates (mine): app `04:05 +776: All tests passed!`, analyze No issues, format 0 changed; engine `00:19 +1121 -2` (standing); render `00:47 +974 ~1 -7` (standing). `git diff a5e38a0 22bc83d --stat`: four files, all under apps/floor_planner/test (select_rig.dart, symbol_end_to_end_test.dart, symbol_library_test.dart, symbol_placer_test.dart): no lib/, render or engine change. The e2e file run three times: `+2: All tests passed!` each time; the only async step is `Future.delayed(Duration.zero)` (yield to the change stream), deterministic rather than timing-dependent. The rig imports only flutter gestures/widgets, jet_cad_2d, jet_cad_2d_flutter (public exports), vector_math. git status at the end: only packages/jet_cad/analysis_options.yaml.

Independent arithmetic (bed.double, base (800,1000), at (12345,-6789), q=1, mirrored): local -> (lx-800, ly-1000) = (qx,qy); mirror -> (-qx, qy); rotate 90 ccw (x,y)->(-y,x) -> (-qy, -qx); add at. Line endpoint (0,1300): qx=-800, qy=300 -> (12345-300, -6789+800) = (12045,-5989), the test's literal. Pillow vertex (100,1680): qx=-700, qy=680 -> (11665,-6089), the test's literal; unmirrored it would be y = -7489 (asserted). The test computes expectations with its own `world()` from hand formulas, not Transform2/placementTransform. Extents (11345,-7589)-(13345,-5989) follow from the outer rectangle under the same formula.

Discrimination: the control (default style) draws argb 0xFFFFFFFF / weight 25 against the instance 0xFF33AA77 / 70: both differ from every default. Pillow 1's edge midpoint (11665,-6414) would be pillow 2's unmirrored (asserted via `expectPoint(worldUnmirrored(425,1680), world(1175,1680))`), so pick pins the mirror; snap onto pillow 1's vertex pins rotation and offset. The painter block asserts `ops.length == 4` and per-vertex positions plus style, so a silent painter cannot pass.

Observation (info): the e2e fixture fixes q=1 mirrored; q=2/3 and unmirrored are covered only by the placer unit tests (P1-P4), not end to end. Acceptable.

Mutant matrix (real output; all restored, diff exit 0, git status clean)
End-to-end file only:
- M-09c drop rotation: first red `leaf 0 vertex 0: got [13145.0,-7789.0], want [13345.0,-5989.0]`; Select test also red (`Expected <20> Actual <19>`)
- M-09c drop mirror: `leaf 0 vertex 0: got [11545.0,-7789.0], want [13345.0,-5989.0]`; Select test red
- M-09a basePoint ignored: `got [12345.0,-6789.0]`; Select test red (`PressClass.empty` not selectedBody)
- identity placementTransform: `got [0.0,0.0]`; Select test red
- M-09d colour: `Expected <4281576055> Actual <4294967295>`
- M-09d lineweight: `Expected <70> Actual <25>`
Part B:
- sweep `== 0`: R27b, R27c, R27d red
- sweep `.abs() <` (strict): R27d red
- sweep without `.abs()`: R27e red (`leaf 1074 of 1068 has a zero sweep`)
- payload `coords[0] += 1` in place: P19 red (`coords [122.0,...]` vs `[120.0,...]`, only P19)
- payload `scalars[0] += 1` in place: P19 red (`scalars [252.0,...]` vs `[250.0,...]`)
Note: my first mutant batch used a script with a backup-name slip; the three mutants of that run were restored by `cp` from the original backup and git status confirmed `lib/` clean before continuing.
