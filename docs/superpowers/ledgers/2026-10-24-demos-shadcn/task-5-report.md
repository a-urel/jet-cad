# Task 5 report
Files: apps/{restaurant,architecture}_demo/test/invariants/kept_material_test.dart (DKM1, DKM2).
Scan: lib/**.dart, comments and single-line strings stripped; construct list = the library's (plus DropdownMenuItem, PopupMenuDivider).
Construct allow-list: empty. Import allow-list: lib/main.dart `show ThemeMode` (restaurant and architecture): ShadApp.themeMode takes Material's enum. DKM1 also fails on a bare/hide material.dart import and on a stale import entry.
Restaurant lib: demo_theme.dart's material import replaced by widgets.dart; main.dart's by `show ThemeMode` + widgets.dart.
Mutations (each run, restored): IconButton in restaurant side_panel.dart -> DKM1 red; Icons.add in architecture document_host.dart -> DKM2 red; stale Scaffold entry -> DKM1 red; bare material.dart import -> DKM1 red.
Gates: restaurant 126 tests passed, analyze clean, format 0 changed; architecture 182 passed, analyze clean, format 0 changed.

## Fix round 1
Finding: `Theme.of;` (a tear-off, no `(`) slipped past DKM1. The regex now also matches a name's `.of` tear-off and a `show...` function tear-off (`(?<=\.of|\bshow[A-Za-z]+)(?!\w)`); `\b` keeps PlanTheme.of, ShadTheme.of, ShadThemeData( out.
Probes appended to restaurant lib/badges.dart (each restored): DKM1 red for Theme.of; Theme.of(..); ThemeData(); showDialog; showDialog(); showMenu(); SnackBar; InkWell; Divider; Card; Switch; Checkbox; Material; SwitchListTile; PopupMenuButton; DropdownButton; Tooltip; TextField; AlertDialog; SimpleDialog; Drawer; AppBar; Scaffold; MaterialApp; SegmentedButton; TextButton. Green for PlanTheme.of, ShadTheme.of, ShadThemeData(), ShadButton().
Gates (real last lines): restaurant "+126: All tests passed!", analyze "No issues found!", format 0 changed; architecture "+182: All tests passed!", analyze "No issues found!", format 0 changed.
