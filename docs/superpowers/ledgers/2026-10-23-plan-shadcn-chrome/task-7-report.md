# Task 7 report
Status: DONE_WITH_CONCERNS (one behaviour test red: architecture_demo DC9, see Concerns).

Tests: new test/panels/layer_page_chrome_test.dart (LP1-LP6 + swatch keyboard). Red before implementation: LP1, LP2 (x2), LP3, LP4, LP6 failed (compile-level type mismatches / missing parts); LP5 and the swatch-keyboard test were green on the old tree by design (they pin kept behaviour).
Mutations: M-LP1 (groupId: Object() in text_field.dart) -> LP1 red: "Expected: '75' Actual: '20'". M-LP5 (_foreground reads ShadTheme) -> LP5 red: Expected black Color(1,0,0,0) Actual white (1,1,1,1). Both reverted.
Gates: plan flutter test All tests passed (+1714 ~7); plan analyze No issues; format 0 changed; integration All tests passed (+240); restaurant_demo All tests passed (+112); tool/ci dart test All tests passed (+122); check_api_boundary clean; architecture_demo: all green except DC9.
Icon pairs: radio_button_checked/unchecked -> circleDot/circle; visibility/_off -> eye/eyeOff; lock/lock_open -> lock/lockOpen; add -> plus; delete_outline -> trash2; expand_less/more -> chevronUp/chevronDown; block -> ban; arrow_drop_down -> chevronDown (menu trigger trailing).
Choices: swatch/hover row are new chrome parts (pick.dart), focusable, Enter/Space, hover/selected/ring from the shadcn scope; layer row surface is a sibling focus stop under the content so keys in the rename field never reach it. Custom paper size = placeholder. Scale prefix "1:" via new PlanTextField.prefix. Page swatch border: primary / input (= Material outline).
Concerns: architecture_demo test/document_commands_test.dart DC9 ("with the page panel's sheet dropdown open, every file chord is handled and runs nothing") is red: the old DropdownButton was a modal route that swallowed Cmd+S/O/N; the ShadSelect popover is not modal so the chords act (a write lands). Not a type change, so not touched. Needs a decision: make PlanSelect's open popover consume chords, or rule the test.

## Fix round 1
DC9 (spec G5, binding): an open PlanSelect / PlanMenuButton keeps the keyboard as a modal route did.
- New chrome/modal_keys.dart: `PlanModalKeys`, a non-focusable `Focus` wrapped around the ShadSelect / ShadContextMenu; while the popover is open its `onKeyEvent` returns handled for every key except arrows, Home/End, Enter, Space, Escape, Tab and the modifier keys. The popover content is an OverlayPortal, so its focus ancestors are the widgets around the select (checked: it sees the events before an outer CallbackShortcuts). A HardwareKeyboard handler was tried first and rejected: its result does not stop the focus dispatch. The menu's Escape handler is unchanged (Escape is in the allowed set).
- Tests CP12, CP13 in test/chrome/parts_test.dart (counted outer Shortcuts: Cmd+S, Ctrl+Z, letter L; premise closed = 3 reach, open = 0, arrows+Enter pick, closed again = 3).
- Mutation (handler never consumes): CP12, CP13 and DC9 red; restored.
- DC9 green unchanged. Gates: plan +1716 ~7 green, analyze clean, format clean; integration +240; restaurant_demo +112; architecture_demo +176 three full runs in a row, all green (EX8 did not recur); tool/ci +122; API boundary clean.
