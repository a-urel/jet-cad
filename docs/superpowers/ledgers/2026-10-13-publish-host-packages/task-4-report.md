# Task 4 report: CI publishable matrix (D5)

## Step 2 checks

YAML check (ruby):
```
["packages/jet_cad_2d", "packages/jet_cad_2d_flutter", "packages/jet_cad_floor_plan"]
```
yaml exit 0. `flutter pub get` exit 0; `git status` showed only `.github/workflows/ci.yml` modified.

Committed-tree checks:

| Package | cmp LICENSE | dry-run exit | output |
|---|---|---|---|
| packages/jet_cad_2d | exit 0 | 0 | "Package has 0 warnings." |
| packages/jet_cad_2d_flutter | exit 0 | 0 | "Package has 0 warnings." |
| packages/jet_cad_floor_plan | exit 0 | 0 | "Package has 0 warnings." |

(First pass of the dry runs did not capture the exit code because the shell is zsh; they were re-run with explicit exit capture. Logs in /private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/6ce8ebc6-b967-46f2-b5f8-a6f183f64d69/scratchpad.)

## M-CI1

- Backed up to `/private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/6ce8ebc6-b967-46f2-b5f8-a6f183f64d69/scratchpad/LICENSE.bak`, appended one byte (`x`) to `packages/jet_cad_2d_flutter/LICENSE`.
- `cmp LICENSE packages/jet_cad_2d_flutter/LICENSE`: "cmp: EOF on LICENSE", exit 1.
- Dry run: exit 65. Output: "* 1 checked-in file is modified in git." and lists "LICENSE" under "Modified files:"; final line "Package has 1 warning."
- Restored with `cp` from the backup; `cmp` against the backup exit 0; `cmp` against the root LICENSE exit 0.
- `git status` after restore: only `.github/workflows/ci.yml` modified.

## Commit

c9eed8a7 ci: dry-run and licence checks for the three published packages (D5)

## Concerns

None. The brief's YAML was applied verbatim; no other job touched.
