# Task 2 review fixes (controller)

Review: task-2-review.md, Approved with fixes (R-1..R-5). All five applied.

- R-1: SC14 reads host_probe.sh's commands (comments aside) and asserts
  `set -euo pipefail` and the order pub get < lock check < analyze < build.
- R-2: a missing build/web/main.dart.js fails the probe (grep inside `if`
  is outside `set -e`); a comment says the lock check is the main guard
  and hooks_runner is Flutter's own folder name.
- R-3: the parser refuses a flow map on the `packages:` line (other than
  `{}`, a trailing comment allowed) and a key indented less than the
  first; HL8, HL7 extended.
- R-4: look-alike `my_scene` in the green fixture (43 keys now).
- R-5: the probe's usage says the sha must be the full one.

Mutants (each restored, `cmp` confirmed):

| Mutant | Result |
|---|---|
| M1 the check line deleted from host_probe.sh | red: SC14 |
| M2 the check moved after `flutter analyze` | red: SC14 |
| M3 a flow map accepted | red: HL8 |
| M4 a shallow key skipped as a field | red: HL8 |
| M5 a key matched by its end (`endsWith`) | red: HL1, HL3 x5, HL5, HL6 |
| M6 the `{}` branch dropped | red: HL7 |

R-2 by hand: the probe's post-build block sourced under `set -euo pipefail`
in a scratch dir: no main.dart.js -> exit 1 with "has no main.dart.js";
a clean main.dart.js -> exit 0; one naming cad.shaderbundle -> exit 1.

Gates (tool/ci): `+50: All tests passed!`; analyze `No issues found!`;
format `Formatted 11 files (0 changed)`; `bash -n` ok.
