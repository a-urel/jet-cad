# Task 6 review (d7f81056..6ab88e8b)

Spec: compliant. Quality: Approved.

Strengths: code matches the brief and K5 (const PlanKit, defaults, bundledLibrary resolves rootBundle at read time, offset/length honoured). The tests use off-origin views (S2) and name mutations.

Deviations judged:
- Dropped `dart:typed_data` import in sources_test.dart: legitimate; flutter/services.dart exports Uint8List and the analyzer flagged it (pre-flight F1 was wrong). Accepted.
- M-K6 on the `if (!foreign && namespace != 'symbol' && !english.containsKey(wordId))` condition (no `else if` exists): equivalent mutation, K6 red. Accepted.

Findings (all Minor):
1. plan_kit.dart:~52 `!rest.contains('.')` is redundant for 'tool:wall' (kitOfKey returns 'wall' != id); a word 'tool:sample' (no dot, rest == id) would pass the foreign check without it. K4 only uses 'tool:wall', so dropping the `contains('.')` term survives. Add 'tool:sample' to K4's id list.
2. missingEnglish is reported once per non-English locale holding the word (a tr and a de word without English give two problems). Untested, not specified; acceptable.
3. K4 expects exactly one problem, so a foreign tool word is not also reported missingEnglish (gated by !foreign): untested ordering, fine.
