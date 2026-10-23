# Rulings — example apps in shadcn

Each: file:line, old → new, why the same thing is still checked.


## Task 1 (restaurant demo root)

- test/look_test.dart:~223 (DL1/DL2) "Standard: standardSeen.shad isNull" -> isNotNull and
  its colorScheme == demoShadTheme(b).colorScheme. Premise (no ShadTheme under
  Standard) no longer exists under a ShadApp root (spec D2); the same finder
  (ShadTheme.maybeOf at the PlanEditor element) now pins that the app's zinc is
  above the view under Standard too.
- test/look_test.dart (DL1/DL2) standardSurface/standardBar: "derived from the
  seed scheme's surface" -> asserted equal to zinc.background (premise) and the
  bar pixel is still read at barBackground() and compared to the same colour.
  The pixel checks on the same bar and surround are unchanged; only the
  expected colour's source changed (the seed no longer exists).
- test/look_test.dart (DL1/DL2) "expect(zinc.background, isNot(standardBar)) DL-S1
  premise: the looks' bars differ" -> expect(standardBar == zinc.background):
  the two looks' bars no longer differ; the toggle's bar difference is now the
  height (44 vs 52, still asserted) and the POS bar pixel stays asserted
  against zinc.background.
- test/look_test.dart: posShadTheme -> demoShadTheme (rename), test name and
  header comment reworded; no assertion removed.
- test/invariants/theme_colours_test.dart kAllowedLiterals: entry
  ('lib/main.dart', 'Colors.teal') removed; the seed is gone from lib/main.dart
  and the test itself requires a stale entry to be dropped (its own assertion
  'stale' empty). The scan, the mutants and the other entries are unchanged.
- test/support/demo_rig.dart: pumpDemo's second frame is pump(1 ms) and a
  runAsync preload of the de/tr shadcn words; new settleLocale/switchLanguage
  (pump, pump(1 ms)). shadcn_ui loads non-English words via deferred imports,
  so under ShadApp a bare two-frame pump shows nothing yet; no assertion
  touched. settle() itself is unchanged (a 1 ms tick there broke
  export_area_test's stacked dialogs).
- test/{badges,layout,events,statuses,service_modes,zones}_test.dart: each
  language-button tap + two bare pumps or settle()/press() -> switchLanguage()
  (same tap on the same key, same two frames, the second with a 1 ms tick).
  Every expect after it is unchanged.

## Task 2 (restaurant top pane, sheet, controls)

- test/layouts_test.dart:59 `tester.getSize(byKey('side-panel-drawer')).width <= size.width`
  -> `tester.getSize(find.byType(DemoSidePanel)).width <= size.width`. The
  keyed `ShadSheet` fills the route (its dialog is the overlay), so its own
  size is the window's and the old check would be vacuous; the panel inside it
  is the visible 320 px sheet. Same bound, same open sheet. The 320 itself is
  asserted exactly in top_pane_test RT2 (new).
- test/look_test.dart:83 `shoot`: boundary found as the RepaintBoundary above
  `find.byType(Scaffold)` -> above `find.byType(DemoHome)`. The Scaffold is
  gone; the first boundary above it was the route's, and the unchanged
  `expect(boundary.size, kWindow)` premise still pins it.
- test/look_test.dart DL3 (:~412-424) `find.byTooltip('Look'|'Aussehen'|'Görünüm')
  findsOneWidget` -> hover the `look-toggle` with a mouse, pump past the
  tooltip wait, `find.text(word) findsOneWidget`, then move away. Added
  assertions only: before the hover the word is `findsNothing` (premise), and
  after each switch the previous language's word is `findsNothing`. Same key,
  same three words.
- test/zones_test.dart:87 untouched (the zone toggle is in side_panel.dart,
  Task 3).
- No layout number followed from the AppBar's height: the bar-height checks in
  DL1/DL2 are the service bar's (44/52), unchanged.

## Task 3 (restaurant side panel and host widgets)

- test/layout_test.dart:98,105,252 `tester.widget<FilledButton>(byKey('save')).onPressed`
  -> `tester.widget<ShadButton>(...)`. Same key (now on the ShadButton), same
  null / non-null `onPressed` of the Save button, same dirty states.
- test/host_chrome_test.dart:208,324 `TextButton` -> `ShadButton` (`.onPressed`
  null / non-null of the own bar's buttons, same keys, same states).
- test/host_chrome_test.dart:258 `find.byIcon(Icons.check)` ->
  `find.byIcon(LucideIcons.check)`, still `descendant(of: byKey(key))`: the
  current choice of the export dialog carries the check, no other one does.
- test/zones_test.dart:87 `SegmentedButton<String>.selected == {'B'}` ->
  `ShadTabs<String>.value == 'B'` (the toggle's single selected zone).
- test/zones_test.dart:88 `SwitchListTile.value` -> `ShadSwitch.value` (same key
  `fade-others`, still isTrue).
- test/statuses_test.dart:113 `PopupMenuItem<String>.enabled` ->
  `ShadContextMenuItem.enabled` on `menu-select`, still isFalse for a locked
  table. Mutation (always enabled) turns D20 red.
- test/support/demo_rig.dart:286 `pickedId`: `DropdownButton.value ?? ''` ->
  the select's own `ShadSelectState.controller.value.single` (the id the
  select holds and shows; '' for none). A `ShadSelect` takes `initialValue`
  only at build, so the live value is the controller's.
- test/support/demo_rig.dart:277 `pickRecord`: added
  `tester.ensureVisible(option)` + settle before the tap on the entry. The
  select's popover scrolls to the shown record and its scroll-up chevron then
  covers the first entries (the 13-record list), so a tap on `pos-id-none`
  hit the chevron. The same entry, the same key, the same tap; the user
  scrolls the list the same way. No assertion touched.
- Added (assertions only, no existing one touched): statuses_test D20b (a
  dismissed table menu: tap outside swallowed, Escape closes, a choice still
  acts), linking_test LK2b (the combo shows an unknown id as it is and still
  offers the records). Mutations: no barrier -> D20b red; unknown id dropped
  from the select -> LK2b red.

## Task 3 fix round 1

- test/host_chrome_test.dart (DH-plan-keys loop, ~:456-466 and the tap after the
  loop) `tester.tap(byKey('find-table'))` -> `tester.tap(..., kind:
  PointerDeviceKind.mouse)`; before the loop's tap, added
  `FocusManager.instance.primaryFocus?.unfocus()` + `expect(searchFocused, isFalse)`.
  Cause: the second default (touch) tap on an already-focused ShadInput opens
  the field's own text-selection toolbar (a ShadContextMenu: Paste / Select
  All) at the field, so the tap after the loop landed on the toolbar, and the
  `searchFocused` premise passed only from focus left over. Now the click is a
  mouse click (no toolbar; what the neighbouring toggle taps already are) and
  the premise starts unfocused, so the click is what focuses it. All the
  original expects are unchanged; two added.

## Task 4

All in apps/architecture_demo/test. No assertion dropped, no tolerance widened.

- support/app_rig.dart `pumpApp` (~:95): added a `runAsync` preload of
  `GlobalShadLocalizations` for de and tr before `pumpWidget`, and a
  `pump(kLocaleTick)` (1 ms) after the first pump. shadcn 0.57.3 loads those
  words through deferred imports on a timer; without it the app under a German
  or Turkish system locale resolved English (document_separator FS1-FS3,
  app_words AW1/AW2, document_title N5 failed with 'en' for 'de'/'tr'). The
  same checks run on the same keys. Added `shadTooltipOf` (the words in the
  `ShadTooltip` builder around a finder) and `tooltipShows` (mouse hover, wait,
  `find.text(word)`, move away) helpers; `app_root_test` AD1 and DC11 use the
  hover, the tooltip tests below use the builder (a `ShadTooltip` is not found
  by `find.byTooltip`, and its words exist only while shown).
- document_title_test.dart:17 `switchTo` and document_separator_test.dart:38
  `switchSystemTo`: second pump is now `pump(kLocaleTick)`; `switchTo` adds a
  third plain pump. The locale change reaches the shadcn words on the tick
  frame, so the host rebuilds there and tells the app on the next frame (the
  title). Every assertion after it is unchanged (N5 still reads title and bar
  right after the switch, in a fixed pump sequence).
- app_words_test.dart:36 `tooltipOf`: `w is IconButton` -> `w is ShadIconButton`,
  `w.tooltip!` -> `shadTooltipOf(tester, ...)` (the words of the wrapping
  `ShadTooltip`); AW1 still expects 'Örneği aç' on `toolbar-open-sample`.
- app_words_test.dart AW4 (~:128): the test pumps the app itself, so it got the
  same preload and `pump(kLocaleTick)` after the first and after the
  Turkish-locale pump; the 'PDF-Dokument' / 'Jet-Plan' / 'PNG görüntüsü'
  expectations are unchanged.
- document_commands_test.dart:86 `on`: `w is IconButton` -> `w is ShadIconButton`
  (`onPressed != null`, same key). :93 `tooltipOfButton`: `w.tooltip` ->
  `shadTooltipOf(tester, button(id))`; DC1/DC1b expectations (incl. Open sample
  has no chord) unchanged.
- document_commands_test.dart DC11 (:802,:808,:816,:821): `find.byTooltip
  ('Edited')` findsNothing/findsOneWidget -> `tooltipShows(tester,
  byKey('document-name'), 'Edited')` isFalse/isTrue: hover the title with a
  mouse, wait past the tooltip, `find.text('Edited')`, move away. Same four
  states (clean, dirty, saved, undone past the save).
- document_replace_test.dart:43 `enabled`: `w is IconButton` -> `w is
  ShadIconButton` (`onPressed != null`, same key).
- document_save_test.dart:214 DS6 fixture: `MaterialApp(home: Builder)` ->
  `ShadApp(home: Builder)` (`showShadDialog` needs a `ShadTheme`; the prompt is
  shown over it exactly as before). :227 `TextField.controller!.text` ->
  `ShadInput.controller!.text` on `name-prompt-field`, 'Untitled.jetplan'.
- document_open_test.dart:371 fixture: `MaterialApp(delegates, locales, home:
  DocumentHost)` -> `ShadApp(...)`: the host's Open sample button and dialogs
  are shadcn now and need a `ShadTheme`. Nothing asserted changes.
- app_shell_test.dart:31 CH-consume fixture: `showDialog` / `AlertDialog` /
  `TextField(dialog-field)` -> `showShadDialog` / `ShadDialog` / `ShadInput
  (dialog-field)`. The test still taps the field, sends the file chord and
  expects it handled above the route with the dialog still up.
- Comment-only: support/app_rig.dart `titleOf` doc, document_separator_test and
  document_title_test headers ("MaterialApp" -> "ShadApp").
- Added test/app_root_test.dart AD1-AD4 (new file). Mutations: save dialog
  `barrierDismissible: true` -> AD4 red; Save without `autofocus` -> AD4 red;
  title tooltip without the `ShadGestureDetector` -> DC11 red.
- Library-adjacent finding (host side, not under packages/): a `ShadTooltip`
  around a bare `Text` never opens (it opens through the hover strategy its
  child reads, and only buttons read it). `_DocumentTitle` wraps the text in
  `ShadGestureDetector` inside the tooltip.

## Task 3 fix round 2

- test/support/demo_rig.dart `reveal`: after `scrollUntilVisible`, added
  `tester.ensureVisible(byKey(key))` + pump. `scrollUntilVisible` stops as soon
  as the lazy list has *built* the entry, which can be in the list's cache
  extent below the viewport; the 1600 px macOS window put `own-bar` at y 688,
  outside the panel's viewport, and the tap hit the list's blank area. Same
  key, same tap; no assertion touched.
