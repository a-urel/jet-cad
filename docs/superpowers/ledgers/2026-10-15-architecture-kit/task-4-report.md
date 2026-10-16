# Task 4 report: Tool notices (spec 3a C1.2)

Status: DONE_WITH_CONCERNS (one concern about test coverage; the code is complete and the gates are green)

Commit: `e5a9abb9 feat(plan): tool notices on the status line (spec 3a C1.2)` (on `1eef1a22`)

## What was implemented

- **Contract** (`jet_cad_2d_kit/lib/src/kit/plan_tool.dart`): `abstract interface class ToolNotice { ValueListenable<KitText?> get notice; }`. It sits after `PlanToolSettings` and before `PlanTool`. The imports gain `package:flutter/foundation.dart show ValueListenable` and `../model/kit_text.dart`. The barrel already exports `plan_tool.dart`.
- **Guard** (`jet_cad_2d_plan/lib/src/kits/guard.dart`):
  - `GuardedTool.notice` reads the inner tool's `notice` once and keeps one `_GuardedNotice` wrapper for the tool's life.
  - A throwing getter goes through `_getterFailed` (one diagnostic after the frame), and the tool then has no notice.
  - The wrapper reads `value`, `addListener` and `removeListener` under the guard. After a throw it answers null and adds no listener.
- **Controller** (`plan_controller.dart`):
  - New fields `_toolNotice` (a `ValueNotifier<KitText?>`) and `_noticeSource`.
  - `toolNotice` and `textOf` were added. `textOf` reads the host's words first via `_names[kitOfKey(...)]`, falls back to `_hostWords` alone, then to the id, and fills placeholders with `fillText`.
  - `_rebindNotice()` and `_copyNotice()` were added. `_onTools` and the end of `_open` call `_rebindNotice()`.
  - `dispose` removes the listener on `_noticeSource` before taking the tools listener off, and disposes `_toolNotice` after `_activeTool`.
- **Editor** (`plan_editor.dart`):
  - The status relay now merges `selection, toolController, activeTool, toolNotice, locale`.
  - `_statusLine` composes the label, then ` — n selected`, then ` — textOf(notice)`, and puts the notice into words each time it builds.
- **Test support**:
  - New `test/support/notice_kit.dart`: kit `note`, tool `note.mark`, letter N, with en and tr words.
  - `throwing_kit.dart`:
    - `boomHooks` gains `notice` and `noticeValue`.
    - `BoomTool implements ToolNotice`, with a `said` notifier and a `BoomNotice` wrapper whose `value` checks `noticeValue`.
    - `dispose` now disposes `said`.
    - The kit gains the word `text:boom.alert`.
- **Tests**:
  - `jet_cad_2d_kit/test/kit/tool_notice_test.dart` (TN-iface).
  - `test/kits/guarded_notice_test.dart` (TN-forward, TN-guard, TN-guard-value).
  - `test/controller/tool_notice_controller_test.dart` (TN-controller, TN-textOf, TN-boundary).
  - `test/editor/editor_notice_test.dart` (TN-status, TN-relocale).
- **Spec lines**:
  - A P2 bullet in the plan-library spec's `## Amendments`.
  - A "Tool notices" bullet in the kit-contract spec's "Amendments from sub-project 3a".

`KitNames.word` falls back to English (`kit_names.dart`: `words[locale]?[id] ?? words[english]?[id]`), so the German case of TN-textOf holds.

## TDD evidence

Precondition (Step 1): `cd packages/jet_cad_2d_plan && flutter test test/kits/guarded_tool_test.dart test/editor/plan_editor_test.dart` printed `00:04 +26: All tests passed!`

RED. I ran the following after Steps 2–4, with the contract and test kits in place and no plan-library code yet:

`cd packages/jet_cad_2d_plan && flutter test test/kits/guarded_notice_test.dart test/controller/tool_notice_controller_test.dart test/editor/editor_notice_test.dart` exited with code 1. The compile errors, deduplicated:

```
   9 test/controller/tool_notice_controller_test.dart: Error: The getter 'toolNotice' isn't defined for the type 'PlanController'.
   6 test/controller/tool_notice_controller_test.dart: Error: The method 'textOf' isn't defined for the type 'PlanController'.
   7 test/kits/guarded_notice_test.dart: Error: The getter 'notice' isn't defined for the type 'GuardedTool'.
```

The editor test uses no new API, so it compiled and failed on its behaviour:

```
Expected: 'Mark — Already marked: Mark 1'
  Actual: 'Mark'
...
00:01 +0 -4: Some tests failed.
```

This was the expected result: the API did not exist yet, and the status line had no notice.

GREEN. I ran the following after Steps 5–7:

`dart format . && flutter analyze && flutter test <the three files>` printed:

```
Formatted 293 files (0 changed) in 0.73 seconds.
No issues found! (ran in 3.8s)
00:01 +8: All tests passed!
```

## Gates

- `packages/jet_cad_2d_kit`:
  - `flutter test` printed `00:06 +393: All tests passed!`
  - `flutter analyze` printed `No issues found! (ran in 3.3s)`
  - The format check printed `Formatted 87 files (0 changed)` and exited 0.
- `packages/jet_cad_2d_plan`:
  - `flutter test --enable-vmservice` printed `02:02 +1513: All tests passed!` and exited 0. This run includes the paint-allocation invariant.
  - `flutter analyze` printed `No issues found! (ran in 3.5s)`
  - The format check printed `Formatted 293 files (0 changed)` and exited 0.
- `dart run tool/ci/check_kit_deps.dart` printed `kit dependencies: 1 package(s) checked, none names the plan library or another kit` and exited 0.
- The non-ASCII greps match the Turkish words and the em dash as literal characters. A Python codepoint check found U+0130, U+015F and U+2014 in `editor_notice_test.dart`, and U+2014 in `plan_editor.dart`.
- `git status --short` is empty after the commit.

## Mutations

I applied each mutation to the committed code, ran the named test, saw it fail, then ran `git checkout -- <file>` and confirmed `git diff --quiet -- <file>` exited 0 every time.

- **M-TN-export**: renaming the declaration to `ToolNotices` broke compilation:
  `test/kit/tool_notice_test.dart:11:46: Error: Type 'ToolNotice' not found.`
- **M-TN-forward**: making the `notice` body `return null;` failed TN-forward (`Null check operator used on a null value`) and TN-controller:
  ```
  Expected: KitText:<KitText(text:note.busy, {name: Mark 1})>
    Actual: <null>
  ```
  TN-guard, TN-guard-value and TN-boundary also failed.
- **M-TN-guard-getter**: removing the try/catch in `notice` failed TN-guard (`BoomFailure(notice)`). TN-boundary also failed, with `The following BoomFailure was thrown while dispatching notifications for ToolController: BoomFailure(notice)`.
- **M-TN-guard-value**: making `value` `=> _inner.value;` failed TN-guard-value with `BoomFailure(noticeValue)`.
- **M-TN-then-null**: deleting `if (_failed) return null;` failed TN-guard-value:
  ```
  Expected: null
    Actual: KitText:<KitText(text:boom.alert, {n: 1})>
  ```
- **M-TN-active**: deleting `_rebindNotice();` from `_onTools` failed TN-controller at `tool_notice_controller_test.dart 34:5`:
  ```
  Expected: KitText:<KitText(text:note.busy, {name: Mark 1})>
    Actual: <null>
  ```
  TN-boundary also failed: `Expected: ['boom.tool']  Actual: []`.
- **M-TN-copy**: deleting `next?.addListener(_copyNotice);` failed TN-controller at `34:5`:
  ```
  Expected: KitText:<KitText(text:note.busy, {name: Mark 1})>
    Actual: <null>
  ```
- **M-TN-textOf-host**: switching to `kits.kitOf(...)?.names ?? _hostWords` failed TN-textOf at `62:5`:
  ```
  Expected: 'İşaretli: Mark 1'
    Actual: 'Zaten işaretli: Mark 1'
  ```
- **M-TN-textOf-locale**: hard-coding `'en'` failed TN-textOf at `62:5`:
  ```
  Expected: 'İşaretli: Mark 1'
    Actual: 'Already marked: Mark 1'
  ```
- **M-TN-order**: putting the notice before the selection failed TN-status:
  ```
  Expected: 'Mark — 2 selected — Already marked: Mark 1'
    Actual: 'Mark — Already marked: Mark 1 — 2 selected'
  ```
- **M-TN-relocale**: caching the text in a `_noticeText ??=` field failed TN-relocale:
  ```
  Expected: 'İşaret — Zaten işaretli: Mark 1'
    Actual: 'İşaret — Already marked: Mark 1'
  ```

`git diff --quiet` passed for the whole tree at the end.

## Files changed

- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit/lib/src/kit/plan_tool.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit/test/kit/tool_notice_test.dart` (new)
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/lib/src/kits/guard.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/test/support/notice_kit.dart` (new)
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/test/support/throwing_kit.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/test/kits/guarded_notice_test.dart` (new)
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/test/controller/tool_notice_controller_test.dart` (new)
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_plan/test/editor/editor_notice_test.dart` (new)
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/docs/superpowers/specs/2026-10-13-kit-contract-design.md`

## Deviations

None from the brief's code or tests.

- `dart format` rewrapped two expressions in `tool_notice_controller_test.dart`, as the brief's Step 7 `dart format .` expects. The `KitNames({...})` literal and the `['boom.tool']` list changed only in layout, not in meaning.
- The `_GuardedNotice` doc and `_Silent`'s doc line ("A kit tool that has no notice.") were added as the brief describes `_Silent`.

## Concerns

1. **Removing a stale notice listener is not pinned by any test.**
   - The code removes the controller's `_copyNotice` listener in three places:
     - when the tool changes (`_rebindNotice`);
     - when the session is replaced, through `_replace` arming `plan.select` on the old session while `_onTools` still listens (`ToolController.activate` notifies synchronously, `jet_cad_2d_flutter/lib/src/tool.dart:169-180`);
     - in `dispose`, before the kit products are disposed.
   - As a probe, not a named mutation, I deleted `_noticeSource?.removeListener(_copyNotice);` from `_rebindNotice`. All 8 TN tests still passed (`00:01 +8: All tests passed!`).
   - The reason: a stale listener only copies the current source's value, so nothing changes at the value level.
   - A pin would need a listener-count probe on `NoteTool.said`, for example a `ValueNotifier` subclass that exposes `hasListeners`. I did not add one because the brief fixes `notice_kit.dart` verbatim. The controller may want it in a later task or a fix round.
2. TN-boundary also turns red under M-TN-forward and M-TN-active, besides the tests the brief names. That is extra mutation strength, not a problem.

---

# Fix report 1: pinning the notice listener's removal (controller ruling)

Commit: `1672344b test(plan): pin the tool notice listener's removal (spec 3a C1.2)`, on top of `e5a9abb9`. Only `packages/jet_cad_2d_plan/test/controller/tool_notice_controller_test.dart` changed, and `notice_kit.dart` is untouched.

## What was added

- **A test-local kit `tell`** (`_tellKit(made)`, tool `tell.mark`, letter T, English only), declared in the controller test file.
  - Each document's tool is a `_Teller` over a new `_Counted`, a `ValueNotifier<KitText?>` that exposes `listened => hasListeners`.
  - The test owns the notifiers: they are collected in `made` and disposed in teardown. So a notifier outlives its tool and its document, and its listener count can be read after a swap or a dispose.
  - The file's imports gain `flutter/foundation.dart`, `flutter/material.dart` (replacing `widgets.dart show Locale`) and `jet_cad_2d_flutter`.
- **TN-unbind (M-TN-unbind-switch)**:
  - The test arms `tell.mark` and checks that the controller listens.
  - It then arms `note.mark`, a second tool with a notice, so the switch goes between two speaking tools.
  - It sets the old tool's value, then asserts three things in order: `toolNotice` is still null, the `heard` count on `toolNotice` is unchanged, and only then `tell.listened` is false.
  - It re-arms `tell.mark`, then calls `newPlan()` and checks that the old plan's notifier is no longer listened to and that the new plan's tool is not listened to.
- **TN-unbind-dispose (M-TN-unbind-dispose)**: the test arms `tell.mark` with a notice set, calls `c.dispose()`, and checks `tell.listened` is false.

## Is the stale listener observable without the count? (Evidence)

- **Tool switch.**
  - The stale listener changes neither the value nor the notifications.
  - Under M-TN-unbind-switch, the value assertion (line 118) and the `heard` assertion (line 119) both passed. The test went red only at the listener-count line, 121.
  - The reason: `_copyNotice` copies `_noticeSource?.value`, the current tool's value, and `ValueNotifier` does not notify when the value is unchanged.
  - The count is the only witness.
- **Dispose.**
  - After `dispose`, `_noticeSource` is null. A stale listener would write `null` into the disposed `_toolNotice`, and only if the value actually changed.
  - The count is the clean witness, and it turns red.
- **Document swap.**
  - The swap has no removal line of its own. It unbinds through two routes:
    - (a) `_replace` arms `plan.select` on the old session while `_onTools` still listens.
    - (b) the `_rebindNotice()` at the end of `_open`.
  - Each route alone is enough to unbind. Removing one route is not observable, by design, and both runs below are green.
  - Removing both routes is observable, at the value level and by the count.

## Mutations

Each was applied to the committed code and reverted with `git checkout -- lib/src/controller/plan_controller.dart`; `git diff --quiet` exited 0 after each.

- **M-TN-unbind-switch**: delete `_noticeSource?.removeListener(_copyNotice);` from `_rebindNotice`. RED:
  ```
  00:00 +3 -1: TN-unbind ... (M-TN-unbind-switch) [E]
    Expected: false
      Actual: <true>
    test/controller/tool_notice_controller_test.dart 121:5  main.<fn>
  ```
- **M-TN-unbind-dispose**: delete `_noticeSource?.removeListener(_copyNotice);` from `dispose`, keeping `_noticeSource = null;`. RED:
  ```
  00:00 +4 -1: TN-unbind-dispose ... (M-TN-unbind-dispose) [E]
    Expected: false
      Actual: <true>
    test/controller/tool_notice_controller_test.dart 149:5  main.<fn>
  ```
- **Swap route (a) alone**: in `_replace`, move `old.tools.removeListener(_onTools);` before `old.tools.activate(...)`. Green, `00:00 +5: All tests passed!`. Route (b) unbinds instead.
- **Swap route (b) alone**: delete `_rebindNotice();` at the end of `_open`. Green across the three TN files, `00:01 +10: All tests passed!`. Route (a) unbinds instead.
- **M-TN-unbind-swap**, routes (a) and (b) together. RED:
  ```
  TN-controller ... [E]
    Expected: null
      Actual: KitText:<KitText(text:note.busy, {name: Mark 3})>
    test/controller/tool_notice_controller_test.dart 48:5  main.<fn>
  TN-unbind ... (M-TN-unbind-switch) [E]
    Expected: null
      Actual: KitText:<KitText(text:note.busy, {name: Tell 2})>
    test/controller/tool_notice_controller_test.dart 126:5  main.<fn>
  ```

## Plan gate after the fix

- `flutter test --enable-vmservice` printed `02:06 +1515: All tests passed!` and exited 0.
- `flutter analyze` printed `No issues found! (ran in 4.1s)`.
- `dart format --output=none --set-exit-if-changed .` printed `Formatted 293 files (0 changed)` and exited 0.
- `git status --short` is clean after the commit and after every revert.

## Deviations and concerns

- **Deviation:** the pin's kit and tool are local to the test file, not in `notice_kit.dart`, which stays as the brief gave it.
- **Concern (minor):** the swap path's two unbinding routes are redundant, so neither alone can be pinned. Only their removal together is pinned, as M-TN-unbind-swap. `_open`'s `_rebindNotice()` is the brief's (Step 6.3) and is kept.
