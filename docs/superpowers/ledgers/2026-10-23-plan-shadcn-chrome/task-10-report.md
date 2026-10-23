# Task 10 report
Red (before impl): EX1 light/dark, EX2 failed (AlertDialog under a bare MaterialApp has no ShadTheme); EX3/EX4/EX5 passed pre-change (guards).
Mutation M-EX (showShadDialog(context: context, ...)): 5 red (EX1 x2, EX2, EX4, EX5).
Gates: plan 1843 pass, analyze clean, format 0 changed; integration 240 pass; restaurant_demo 114; architecture_demo 176; tool/ci 122; api boundary clean.
Rulings: R-allow (ShadDialog, ShadDialogRoute), R-SegmentedButton (export_dialog_test X-9).
Choices: ShadDialogRoute with PlanShadScope(data: resolved) page; PlanStrings captured at call site and passed to the dialog; scope's opaque MouseRegion swallows barrier taps so a full-page GestureDetector pops on outside tap; barrier colour is the route default (a literal fails theme_colours_test). No PlanTheme read by the dialog.
Icon pairs: none.
