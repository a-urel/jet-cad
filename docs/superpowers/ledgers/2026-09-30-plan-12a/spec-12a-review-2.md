# Review 2: spec 12a, the document lifecycle (revision 2)

**Spec:** `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md` at `c54ca55`
(branch `spec-12a/document-lifecycle`). The first review is `spec-12a-review.md` (S-1 to S-28).
**Reviewer:** independent and read-only. Nothing in the worktree was committed or edited except this file.
**Scope:** whether revision 2 really resolves S-1 to S-28, and what new problems it introduces.
The human's nine decisions are binding and were not reviewed.

**Probes.** They ran against a scratch copy of the worktree:
- the copy is `…/scratchpad/s12r2-/repo`, with `flutter pub get --offline` run in the copy only;
- the widget probes are `apps/floor_planner/test/zz_review_probe_test.dart` in that copy;
- the D3 model is `…/scratchpad/s12r2-/d3/model.dart`.

The outputs quoted below are copied verbatim from those runs.

## Verdict: **Ready with amendments**

**D3 is exactly right.** I modelled the transitions (`recordExecute`, begin, commit and abort for undo and redo, eviction, `clear`) and ran D3's six engine tests against the baseline and four mutants. Results:
- baseline: `all green`;
- M-12a-5: `RED T1 redo returns, …`;
- M-12a-6 (both readings): `RED T3 eviction`;
- M-12a-14: `RED T4 then undo`;
- the redo variant of M-12a-14: `RED T5 then redo`.

`commitRedo` rightly does not clear redo, and it needs no eviction check. `undo + redo ≤ limit` always holds:
- `recordExecute` evicts and clears redo;
- an undo moves one entry from the undo stack to the redo stack, and a redo moves one back.

**D4's fixed page is sound.** `PageComponent()` defaults are A4 landscape at 1:50 in metres, with white paper and the grid visible and snapping. The sheet is `sheetWorldRect = origin + effective size × D` (`page_geometry.dart:7-12`). So `(-w/2, -h/2) = (-7425, -5250)` centres the sheet on the world origin, and `fitToPage` fits it.

**D6's "a disabled binding still consumes" is right as far as the shell reaches.** `CallbackShortcuts` returns `handled` whenever an activator accepts, whatever the callback does (`shortcuts.dart:1212-1232`).

**D2's settle is right in order, but has three problems:**
- The keyboard path works: the shell owns `_text` and the `ToolContext`, and the overlay calls the tool through the same `tools.context`.
- A **toolbar click cancels the text entry before the flow runs** (T-1).
- The `Future.delayed(Duration.zero)` turn **never fires under `tester.pump()`** (T-4).

**Two new majors:**
- T-1: the toolbar click path loses the text entry.
- T-2: the Undo and Redo buttons bypass the mid-shape guard of 05 D3 and Ruling 07-1. The toolbar and the shortcuts then disagree, which breaks the spec's own invariant.

Every finding has a local fix inside the nine decisions, and none reopens a decision. Once the amendments are applied, a spot check is enough. A third full review is not needed.

## S-1 to S-28

| # | Resolved | Note |
|---|---|---|
| S-1 | yes | `registerAppComponents` (D8, D4). The page-after-Open test, M-12a-7 and M-12a-7b. The "still draw, not live" wording is fixed. The catalog's registration is idempotent (`parametric_system.dart:761`), so the shell's `ParametricSystem` over a decoded document is safe. |
| S-2 | yes | D5 takes the id in the same block as the encode, with a held-write test and M-12a-13. |
| S-3 | yes | The origin, the units, `execute` then `clearHistory`, the shared helper and the round trip from New are all there. One factual slip is folded into T-9. |
| S-4 | **partly** | The keyboard path commits through `finish`. A toolbar click cancels first (T-1). |
| S-5 | yes | The order is right. The chosen await has a test trap (T-4). |
| S-6 | yes | Whole transitions. The model confirms both failure tests and M-12a-14. |
| S-7 | **partly** | The guard gains the three chords, which is right. But "those stay the field's own undo and redo" is false (T-5). The test also needs a non-empty redo stack and all three chords (T-6). |
| S-8 | **partly** | Pinned in the busy state. But the fixture can make the mutant equivalent: a pending tool swallows the key (T-6), and the redo leg needs `canRedo`. |
| S-9 | yes | The first bytes are checked against an independent `encodeToString`. |
| S-10 | yes | The seam is in D1, and `planner_shell_test` migrates (12 pumps of `FloorPlannerApp`, confirmed). |
| S-11 | yes | The old document is disposed post-frame, the snap settings are no longer disposed, and the hygiene test with F3 is there. That F3 test also shows focus reaching the new shell. |
| S-12 | yes | `catch (e)`. The fixtures `[]` (a cast `TypeError` at `json_codec.dart:161`) and `{"schemaVersion":1}` (`json!` at `:171`) both throw. M-12a-16 is there. |
| S-13 | **partly** | Dirty with history, as asked. But the preamble's "rotated groups off the origin" is false (T-10), and "a real tool" needs the chain ended (T-6). |
| S-14 | yes | D11, D14 and the exit gate record the quirk. A Swift detail is in T-13. |
| S-15 | yes | `package:web` download with a revoke, and no `cross_file`. |
| S-16 | yes | |
| S-17 | yes | Busy returns cancel. The order of the checks needs fixing (T-7). |
| S-18 | yes | The tests go through `handleRequestAppExit`, and M-12a-2 includes "save, then exit". |
| S-19 | yes | |
| S-20 | yes | The test, M-12a-18, and the citation (spec 10 D3, `rooms-design.md:356-361`). |
| S-21 | yes | Busy is reset in a `finally`, "then Cmd+S writes", and the web picker limit is recorded. Nested flows are open (T-8). |
| S-22 | yes | |
| S-23 | yes | |
| S-24 | yes | |
| S-25 | yes | References checked: `main.dart:398-399`, `selection_panel.dart:440-446`, `focus_manager.dart:1943-1947`, `app.dart:1823`, `keyboard_binding.dart:596-599`, `wall_tool.dart:221`, `startup_plan_test.dart:735-738`. |
| S-26 | **partly** | Both modifiers are bound and disabled keys are consumed, but only while the shell is in the focus chain. Dialogs are not (T-3). |
| S-27 | **partly** | The limits, `Flexible` and "web tab only" are all there. The "scale of 0" example is wrong (T-9). |
| S-28 | yes | |

## New findings

### T-1 (major): a toolbar click cancels an open text entry before the flow can commit it; R-5 holds only for the keyboard

**Evidence**
- The overlay's `TextField` has no `onTapOutside` (`text_entry_overlay.dart:105-119`). EditableText's default tap-outside action calls `focusNode.unfocus()`:
  - on macOS, Windows and Linux for every pointer kind;
  - on Android and iOS for a mouse (`editable_text.dart:6876-6906`).
- `ExcludeFocus` does not stop that: tap regions are independent of focus.
- The focus loss runs `_onFocus`, which calls `cancelText` (`text_entry_overlay.dart:72-78`). This happens on pointer *down*, before the button's `onPressed`, so D2's settle finds nothing pending.
- Probe P1 put an `ExcludeFocus(IconButton)` above a real `PlannerShell`, opened the text entry, typed `Hall`, and tapped the button. `pendingAtPress` was recorded inside `onPressed`:
  ```
  P1 TargetPlatform.android PointerDeviceKind.touch: presses=1 pendingAtPress=true
  P1 TargetPlatform.android PointerDeviceKind.mouse: presses=1 pendingAtPress=false
  P1 TargetPlatform.macOS PointerDeviceKind.touch: presses=1 pendingAtPress=false
  P1 TargetPlatform.macOS PointerDeviceKind.mouse: presses=1 pendingAtPress=false
  ```
- `flutter test` defaults to Android with touch taps, the one combination where the entry survives. So a toolbar test written in the house style cannot see the defect.
- Consequence on the product platforms, macOS and web on a Mac:
  - Save from the button saves without the typed text.
  - New or Open from the button on an otherwise clean document shows no dialog, and the text is gone.
  - R-5's rationale ("the person typed it and asked to save") holds for Cmd+S only.

**Fix**
- Wrap the toolbar in a `TextFieldTapRegion`. A toolbar press is then not "outside" any text field, and D2's settle handles the text entry and the Selection panel fields in one place for both paths. D7 should state this.
- Note the side effect: a click on Undo or Redo then no longer hands a panel field back first. D6 should rule whether Undo and Redo settle too, or are disabled while a field has focus. T-2 bears on this.
- Test, with `debugDefaultTargetPlatformOverride = TargetPlatform.macOS` and `kind: PointerDeviceKind.mouse`: a text entry with typed text, then a tap on `toolbar-save`. The saved bytes contain the text entity, and the document is clean after.
- Mutant: the toolbar is outside the tap region → that test goes red.

### T-2 (major): the Undo and Redo buttons land an undo on a half-placed shape; the toolbar and the shortcuts then disagree

**Evidence**
- 05 D3, 03 D5 and Ruling 07-1 say that undo never lands mid-shape. The mechanism is the tool swallowing every key-down while it is pending (`placement_tool.dart:199-204`; the Wall tool's doc at `wall_tool.dart:61-62`).
- Probe P4: a real shell, a wall chain with one wall down, then Cmd+Z:
  ```
  P4 depth before=1 after cmd+Z=1 handled=true
  P4 after Escape then cmd+Z: depth=0
  ```
- The spec's Undo button is enabled on "not busy and `canUndo`" (D6). A click is a pointer event outside the canvas, so no tool sees it. Mid-chain, the button undoes and the key does not.
- That contradicts:
  - the ruling above;
  - the spec's invariant "the toolbar and the shortcuts cannot disagree" (Architecture, Invariants).
- The Wall tool then carries on with `_walls` counting a wall that is gone (`wall_tool.dart:77, 104, 150`).
- The same holds for Redo, and for New, Open and Save: their chords are swallowed mid-shape too, while their buttons work.

**Fix**
- Undo's and Redo's `enabled` adds "and the active tool is not pending" (`!tools.active.isPending`, with `ToolController` as the listenable). Button and key then agree, and 05 D3 holds.
- For the file commands, rule one of two options:
  - the buttons also require an idle tool;
  - or D14 records that the file chords are inert mid-shape (the tool consumes them, which on web also blocks Save Page) while the buttons work.

  The second needs no render-layer change.
- Test: a wall chain with one wall down → the Undo button is disabled, and a tap leaves `undoDepth`. After Escape, it is enabled.
- Mutant: `enabled` ignores `isPending` → red.

### T-3 (minor): a disabled binding consumes the key only while the shell is in the focus chain; every app dialog is outside it

**Evidence**
- The shell's `CallbackShortcuts` is inside the home route (`main.dart:396`). D10's dialog, the error dialog and the web Save As name dialog (D9) are separate routes.
- Probe P5: a `CallbackShortcuts` in `home:`, then Cmd+S before and during a `showDialog` with a focused `TextField`:
  ```
  P5 no dialog: handled=true; dialog up: handled=false; saves=1
  ```
- On web, unhandled means no `preventDefault()` (`keyboard_binding.dart:596-599`), so the browser opens Save Page. This happens:
  - during a web Save As, whose name dialog is up;
  - during the replace dialog;
  - with focus left on the route scope, after the text entry's plain `unfocus()` (T-1's path).
- The exit gate's "Cmd/Ctrl+S never opens the browser's Save Page, even during a pending save" therefore fails for Save As on web.

**Fix**
- Bind the file chords once more above the Navigator, e.g. a `CallbackShortcuts` in `MaterialApp.builder` that calls the same table's `run`. Disabled or busy commands are no-ops, as now.
- That builder sits below `DefaultTextEditingShortcuts` (`app.dart:1818-1823`), and the file chords are not text-editing chords, so fields lose nothing.
- The alternative is to narrow the exit gate's claim and record the limit in D14.

### T-4 (minor): `await Future<void>.delayed(Duration.zero)` never fires under `tester.pump()`; this can make mutants equivalent. Settle synchronously instead

**Evidence**
- `AutomatedTestWidgetsFlutterBinding.pump` elapses the fake clock only when a duration is given (`flutter_test/lib/src/binding.dart:2253-2255`).
- Probe P2: a `CallbackShortcuts` callback starts `() async { await Future.delayed(Duration.zero); reached = true; }()`:
  ```
  P2 after sendKeyEvent, before pump: reached=false
  P2 called=true; after pump(): reached=false
  P2 after a second pump(): reached=false
  P2 after pump(Duration.zero): reached=true
  ```
  Left unpumped, the test fails with "A Timer is still pending even after the widget tree was disposed".
- The repo's key helper is `press()`, which is `sendKeyEvent` then `pump()` (`planner_draw_test.dart:62-66`). Every flow started that way stalls at the settle.
- Tests that assert *nothing happened* then pass for the wrong reason:
  - M-12a-12 ("a second Cmd+S makes no second write"): with busy missing, the second flow stalls before `write`, and the test stays green.
- It also blocks any test that `await`s `tester.binding.handleRequestAppExit()` directly.

**Fix**
- Settle synchronously. After `handBack()` and the text tool's `finish`, call `FocusManager.instance.applyFocusChangesIfNeeded()`. This is public API, meant for "making sure no focus changes are pending before executing an action", and `MenuAnchor` uses it for exactly that (`menu_anchor.dart:1312`).
- Probe P3:
  ```
  P3 listener before apply=false, after apply=true
  ```
- The flows then need no await before reading the id, and tests keep the house `pump()`.
- Reword M-12a-11 as "settles without applying the focus change".
- If the timer is kept instead, the Testing section must require `pump(Duration.zero)` or `pumpAndSettle` after every flow trigger, and M-12a-12's test must use it for the second Cmd+S.

### T-5 (minor): D6's "in a focused field those stay the field's own undo and redo" is false

**Evidence**
- The guard maps the chords to `DoNothingAndStopPropagationTextIntent`. EditableText answers `DoNothingAction(consumesKey: false)`, that is `skipRemainingHandlers`. The key never reaches `DefaultTextEditingShortcuts` at the app root, so `UndoTextIntent` and `RedoTextIntent` never fire.
- Probe P6 (macOS): a field holding `abc` then `abcd`, then Cmd+Z:
  ```
  P6 guarded=false: after cmd+Z text="abc" handled=true
  P6 guarded=true: after cmd+Z text="abcd" handled=false
  ```
- So in a guarded field the chord does whatever the platform does with an unhandled key. On web, that is the DOM input's native undo, out of step with the framework's history.
- This is how Cmd+Z has behaved since spec 05. Revision 2 extends the claim to the redo chords.

**Fix**
- Reword D6: "in a focused field they never reach the document". Only the guard's part is guaranteed.
- Optionally, map them in the guard to `UndoTextIntent` and `RedoTextIntent`, which gives fields a real undo and redo. With no field focused, no action is found and the key still bubbles.

### T-6 (minor): three "no call" tests can pass under their mutants

**1. A pending tool eats the key (P4).**
- S-8's busy test (M-12a-9), M-12a-12's second Cmd+S and every test that presses a chord after "an edit through a real tool" must end the chain first (Escape, or Select active and idle).
- If they do not, the Wall tool returns `handled` and the chord never reaches the shell.

**2. The redo legs need a redo stack.**
- With `canRedo == false`, a Redo that ignores `enabled` calls `redo()`, which returns at once (`undo.dart:166`). The call cannot be seen.
- Affected: the busy test's Cmd+Shift+Z, and the text-field test (M-12a-15).
- For M-12a-15 there is a second reason. Without the guard, the shell's *disabled* Redo still consumes the chord, so `undoDepth` and `canRedo` are unchanged either way.
- Fixture: two edits, then one undo. That gives dirty, `undoDepth > 0` and `canRedo`.

**3. M-12a-15 is "the guard lacks *a* redo chord".** The test presses Cmd+Shift+Z only, so dropping Ctrl+Shift+Z or Ctrl+Y survives. Press all three.

### T-7 (minor): D11 checks "clean" before settling and before "busy"

**Evidence**
- D11 lists "Clean: exit. Busy: cancel. Dirty: settle, then the D10 dialog."
- In that order, a clean document with a typed but unsubmitted Selection panel value, or an open text entry, exits and loses it. D10 settles *before* its dirty check.
- If "clean" is evaluated before "busy", a re-save of a clean document whose `write` is in flight exits mid-write. D14 records that `writeAsBytes` truncates in place, so that leaves a damaged file.

**Fix**
- State the order: busy → cancel; else settle; then clean → exit; else the dialog.
- Test: a clean document with a Selection panel value typed and not submitted, then an exit request → the dialog appears.

### T-8 (minor): nested flows and the busy flag

**Evidence**
- D10's and D11's "Save" run Save inside a flow that is already busy. The spec does not say how.
- If the nested Save goes through the command's guarded `run`, it is a no-op while busy.
- If it is a flow of its own, its `finally` clears busy while the outer flow continues (for example, Open's picker is then up), and every command is re-enabled mid-flow.
- Separately, an edit made while that nested write is pending (D5 keeps the canvas live) is then replaced or quit without a prompt.

**Fix**
- D6: busy belongs to the outermost flow. Save and Save As are plain steps that return success; the command wrappers own busy.
- D10 and D11: after a nested Save succeeds, proceed only if the document is still clean; otherwise ask again.
- Test: dirty → New → Save, with the write held → Cmd+O, Cmd+S and the buttons do nothing. Complete the write → the document is replaced.

### T-9 (minor): two factual errors about `PageComponent`

**Evidence**
- D8 and D14 say "a decodable but out-of-range page (a scale of 0, say) has no check in `PageComponent.fromJson`". But `fromJson` calls the constructor (`page_component.dart:202-216`), and the constructor rejects:
  - non-positive or non-finite sizes and scale;
  - non-finite origins (`page_component.dart:109-116`).
- A scale of 0 therefore throws `ArgumentError` inside the decode (`component.dart:194`). D8's `catch (e)` shows the error dialog, and nothing is swapped.
- D4's "the codec cannot encode (`jsonEncode` throws on NaN)" has the same slip. `startupPage` on an empty document already throws at `copyWith`, through that same constructor check.

**Fix**
- D8/D14: say the page's own fields are range-checked on load (and a bad page fails the Open cleanly). Name what is actually unchecked: a positive but absurd scale or size, and parametric parameters.
- A `{"… scaleDenominator": 0}` fixture could join the Open-failure tests for free.

### T-10 (minor): the Testing preamble's "rotated groups off the origin" is false

**Evidence**
- Every sample object sits in a root-level group at `Transform2.identity()` (`startup_plan.dart:305-371`).
- The tools add objects the same way.
- No listed fixture is rotated, so the round trips never carry a non-identity group transform.

**Fix**
- Either drop "rotated", or make the New round trip rotate one wall's group through the Select tool's rotation grip before Save As. The second is the better fixture for the exit criterion.

### T-11 (minor): pin D4's page as a literal

**Evidence**
- "`PageNotifier.value` is the fixed default", if computed through the same helper, cannot see a formula slip. Two examples:
  - the portrait `widthMm` used for `effectiveWidthMm`, giving origin `(-5250, -7425)`;
  - `PageComponent()` left at `(0, 0)`.

**Fix**
- The spec states the value: `PageComponent(originX: -7425, originY: -5250)`, all other fields at their defaults.
- The launch test compares against that literal.
- Name the mutant: origin from the portrait size → red.

### T-12 (minor): the web `saveLocation` needs a navigator

**Evidence**
- D9's web `saveLocation(String suggestedName)` "asks for a name in an app dialog", but the interface carries no `BuildContext` or navigator.

**Fix**
- The web implementation takes a `Future<String?> Function(String suggested)` name prompt that the host supplies. The fake bypasses it.
- An empty name is a cancel.

### T-13 (nit): smaller points

- **Swift.** `windowShouldClose(_:)` on an `NSWindow` subclass is found by AppKit's `respondsToSelector:`. `MainFlutterWindow` does not adopt `NSWindowDelegate`, so Swift exposes the method to Objective-C only when it is marked `@objc`. Say `@objc func windowShouldClose(_ sender: NSWindow) -> Bool` in D11. (Reasoned from Swift's `@objc` inference, not run here. The human's macOS look covers it.)
- **Dirty after a save.** D5 recomputes `dirty` on each change, but a save emits none. Say that writing `savedState` recomputes it too.
- **Tab title.** `WidgetsApp` wraps everything in its own `Title('Floor planner')` (`app.dart:1810`). A rebuild of the app, e.g. on a platform brightness change, resets the tab title until the host's inner `Title` rebuilds. Use `MaterialApp.onGenerateTitle`, fed from the host's state, or rebuild the inner `Title` on that signal.
- **Long names.** The document name in the top bar also needs `Flexible` with an ellipsis. A long file name overflows today's fixed 44 px row as the status line would.
- **Page scale after a save.** After a Save with an unsubmitted page scale, the settle hands focus back but does not re-sync the field as `_onScaleTapOutside` does (`page_panel.dart:88-90`). The panel then shows a scale the saved file does not have. Call `_syncScale`, or record it.
