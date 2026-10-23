# SDD ledger — plan: docs/superpowers/plans/2026-10-24-demos-shadcn.md

Spec: docs/superpowers/specs/2026-10-24-demos-shadcn-design.md (rev 2, approved 2026-10-24).
Branch claude/shadcn-ui-75d8dc, start 870661fa. No reviewer subagents (human's rule): controller self-reviews.

## Preflight scan

| Tasks | Shared | Producer → consumer | Found |
|---|---|---|---|
| 1-2 | restaurant lib/main.dart | T1 app widget, _theme, _viewTheme → T2 _scaffoldFor | disjoint regions; T2 starts from T1's tree |
| 1-2 | test/look_test.dart | T1 look assertions, line 82 → T2 byTooltip 409-419 | disjoint |
| 1-2/3 | demoShadTheme | T1 produces → T2, T3 read ShadTheme.of | consistent |
| 2-3 | zones_test.dart:87 (zone toggle lives in side_panel.dart) | T3 owns widget | T2 brief says leave to T3: consistent |
| 2-3 | host_chrome_test.dart | T2 none expected → T3 lines 207/257/323 | ok |
| 1-4 → 5 | demos' lib | T5 guards expect empty allow-list | ok if 1-4 complete |
| 6 | docs | after all | ok |
| T1 self | RD1-3 vs Step 3 | tests match code | ok |
| T2 self | RT1-4 vs Step 3 | ok; sheet width via ShadSheet constraints (API to check) | implementer checks |
| T3 self | retarget-first then implement | ok |
| T4 self | AD1-4 vs Step 3 | ok |
| T5 self | list vs library KM | ok |
| T6 self | gates | ok |

Ruling: none needed at preflight.

## Tasks
Task 1: dispatched (BASE 870661fa, sonnet)
Task 1: controller mutation: materialThemeBuilder always the Standard branch → RD3 red; restored. Gates rerun: +117 all passed, analyze clean, format 0.
Ruling: the rig preloads shadcn de/tr words (deferred imports) in runAsync and pumps 1 ms after a language switch (settleLocale/switchLanguage) — shadcn 0.57.3 loads non-English words on a timer — costs: a runtime first-use frame in the old language, to check in Task 6's real run.
Task 1: minor (deferred): settle() with the 1 ms tick made export_area_test find two export dialogs; settle left unchanged, cause not investigated.
Task 1: complete (commits 870661fa..0306d426, self-review clean)
Task 2: dispatched (BASE 0306d426, sonnet)
Task 2: controller mutation: side button onPressed no-op → layouts RS1 ×4 + RT2 red; restored. Gates rerun: +122, analyze clean.
Ruling: docked controls scroll horizontally (reverse) beside the title instead of a fixed row — at 1300 px they overflowed by 54 px — costs: at desktop the left controls may sit off-screen at large text; wrapping is the alternative.
Ruling: ShadTabs scrollable: true with flex-0 tabs, keys on the tab labels' Text — non-scrollable ShadTabs take infinite width in a Row — costs: none seen.
Ruling: the keyed ShadSheet fills the route; RT2 and layouts_test measure DemoSidePanel (320) — costs: the key does not sit on the visible box.
Task 2: minor (deferred): the sheet shows shadcn's default close X and border.
Task 2: carry to Task 3: remove _panel()'s transparent Material once side_panel.dart is shadcn.
Task 2: complete (commits 0306d426..3952571b, self-review clean)
Task 3: dispatched (BASE 3952571b, sonnet)
Task 3: implementer DONE at ee679b88 (124 passed). Controller finding: find-table taps in host_chrome_test:454/466 miss (an overlay covers the field) → focus premise vacuous. Fix round 1/5 dispatched to the same implementer.
Task 3: fix round 1/5 (1 addressed, 0 open — the overlay was ShadInput's selection toolbar from a second touch tap; taps now mouse-kind from an unfocused start, "would not hit" count 0; commits ee679b88..7c5ad90d)
Task 3: controller mutation: export dialog never marks the current choice → DH4 red; restored. Gates rerun: +124, 0 "would not hit", analyze clean.
Ruling: ShadSwitch wrapped in Align (it expands full width, a tap at its centre misses), ShadButton labels Flexible in the side panel, pickRecord ensureVisible (ShadSelect's chevron covers edge options) — costs: none seen.
Ruling: the table menu is a ShadContextMenu in a root OverlayEntry under a dismissing barrier (shadcn has no showMenu) — costs: no route, so no back-button dismissal on Android.
Task 3: minor (deferred): own bar buttons and export choices do not wrap long labels.
Task 3: complete (commits 3952571b..7c5ad90d, self-review clean)
Task 4: dispatched (BASE 7c5ad90d, sonnet)
Task 4: implementer DONE at 5b20328d (+180, analyze clean, would-not-hit 0).
Task 4: controller mutation: error dialog OK no-op → AD3, DC9, EX2, DO6 red (suite ran >10 min on the hangs); restored. Analyze clean.
Ruling: ShadTooltip around the document title needs a ShadGestureDetector child (a bare Text never reads the hover strategy) — costs: none seen.
Ruling: test fixtures in document_save_test DS6 and document_open_test move from MaterialApp to ShadApp (showShadDialog needs a ShadTheme) — costs: none.
Task 4: complete (commits 7c5ad90d..5b20328d, self-review clean)
Task 5: dispatched (BASE 5b20328d, sonnet)
Task 5: implementer DONE at bcfc89aa. Controller mutation: 'Theme.of' appended to badges.dart → DKM1 stays green (Theme.of/ThemeData( missing from the list); bare material import in architecture main → DKM1 red. Fix round 1/5 dispatched.
Task 5: fix round 1/5 (1 addressed, 0 open — DKM1 regex matched only name( ; now tear-offs too; commits bcfc89aa..4a129cb2)
Task 5: controller mutations: Theme.of tear-off in restaurant badges → DKM1 red; Card() in architecture document_host → DKM1 red; restored.
Ruling: one material.dart import allowed per demo, `show ThemeMode` in lib/main.dart (ShadApp.themeMode takes Material's enum) — costs: none.
Task 5: complete (commits 5b20328d..4a129cb2, self-review clean)
Task 6: dispatched (BASE 4a129cb2, sonnet); Step 3 (the look) done by the controller.
Task 6: BLOCKED at 4a129cb2: restaurant integration POS1 fails (own-bar ShadSwitch tap misses on macOS). All other gates green (see task-6-report.md). host-guide edit uncommitted. Task 3: fix round 2/5 dispatched to its implementer.
Task 3: fix round 2/5 (1 addressed, 0 open — reveal() left the entry in the cache extent below the viewport in the taller macOS window → ensureVisible; plus an 8 px dead zone between switch track and label in _toggle closed; commit a6913fc0; restaurant +126, integration +1)
Ruling: the switch's label gap is made hit-testable with an opaque MouseRegion (click cursor) instead of a transparent colour — theme_colours_test forbids colour literals — costs: none seen.
Task 6: unblocked, resumed to finish docs.
Task 6: complete (commit 1d1786f1; Looked-at section pending the controller).
Look (controller): real apps launched; screen access for them denied by the human, so the controller rendered both demos with the bundle's real fonts in a scratch widget test (not committed), 1300 light/dark and 400 light. Architecture: fine. Restaurant: bare Texts in the side panel (tables, groups, sections, log) have no DefaultTextStyle under plain ShadApp → wrong font; phone shows two identical slidersHorizontal icons (demo's side button + library's panel button).
Task 3: fix round 3/5 dispatched (DefaultTextStyle via ShadApp builder in both demos; side button icon panelRight).
Task 3: fix round 3/5 (2 addressed, 0 open — DefaultTextStyle from ShadApp.builder in both demos plus DemoSidePanel's own wrap; panelRight icon; commit f3758596; restaurant +127, architecture +183)
Ruling: DemoSidePanel wraps itself in the theme's text style too — the ShadSheet route sets a muted DefaultTextStyle — costs: none.
Look: second render clean. Controller re-run at f3758596: restaurant +127, integration +1; architecture +183, integration +1.
All tasks complete. No final reviewer subagent (the human's rule); the controller self-reviewed every task.
