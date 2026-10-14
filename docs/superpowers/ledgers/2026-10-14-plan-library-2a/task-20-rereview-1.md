# Task 20 re-review, fix round 1

1. Pass-through tests (toolPalette incl. gallery-alone, symbolFilter, shortcuts, autofocus, onPageFlowError) - ADDRESSED. plan_editor_test.dart group "the options a host passes through": ED-P1, ED-P2, ED-F, ED-S, ED-A1 (positive control), ED-A2, ED-E; each has a named mutation comment and a red output in the report. ED-S uses a host CallbackShortcuts with reached==1, so it is not degenerate. ED-E asserts once, StateError, ready again.
2. Canvas handed another controller withdraws the old tool (ED-6b) - ADDRESSED. plan_canvas.dart didUpdateWidget adds _withdrawTool(old) after _leave(old). ED-6b asserts activeTool == 'plan.select'. The report admits the isMidShape expect does not go red under the mutation (another path cancels the shape), so only the activeTool line carries the mutation; that is honest and sufficient.
3. ED-L swap half distinguishable - ADDRESSED. The second plan has its own layer D and a mark on it; after load the picker must show 'D', enabled; M-ED-L3 red recorded.
4. Mechanical expect comparison - ADDRESSED. The report lists 334 source / 285 port / 235 identical expects, every differing test with a reason, and flags the NEW rows. I judged the NEW rows: PF6 (selection-mode exports are 2b's), NS1 layoutFired (2b's serviceLayoutChanges), status-text pick premises (selection set directly; this removes premise expects, not what the remaining text assertion checks), and the two theme tests (M-H30 swaps groupFrameColor for canvasBackground; I read both tests side by side and the merge-per-field and view-wins checks are the same, only the field differs; "through the barrel" is generic-four only). None weakens a remaining assertion. Not independently re-run: the script itself (expects.py) is in the scratchpad, so counts are claims; the spot-check of M-H30 matched the report.

New breakage in the fix diff: none Critical/Important. exportRunnable now equals exportersFor(...).isNotEmpty (editor_page_flows.dart); ED-X1/X2 re-mutation reds recorded.
Out-of-scope: Minor 3 (unnamed mutations in ported files) left to the controller, as the report says.

Verdict: all findings addressed, no new Critical/Important breakage.
