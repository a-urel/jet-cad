# `/spec-review` skill: report

**Date:** 2026-11-16. **Branch:** `claude/spec-review-skill-91e41b` (worktree
`.claude/worktrees/spec-review-skill-91e41b`, cut from local `main` at `892aad2d`).
**State:** nothing committed, nothing pushed; the owner decides on the commit.

## The four answers

- **Where reviewable docs live:** specs in `docs/superpowers/specs/`, plans in
  `docs/superpowers/plans/`, notes in `docs/superpowers/notes/`, archived ledgers in
  `docs/superpowers/ledgers/` (from `AGENTS.md`, "Workflow"). New, tracked: review archives in
  `docs/superpowers/reviews/<YYYY-MM-DD>-<slug>/`, the slug being the path under
  `docs/superpowers/` (or `docs/`) with `/` as `-`, e.g. `specs-2026-10-24-dxf-writer-design`.
  The script accepts any `.md` file in the repository outside that archive directory.
- **Orientation files for a reviewer:** `AGENTS.md` (`CLAUDE.md` is a prefix of it), the head
  of `STATUS.md`, `roadmap/00-README.md`; then whatever the document cites.
- **Protected branch:** `main`. GitHub reports `main` as not protected by branch rules
  (`gh api repos/a-urel/jet-cad/branches/main` → `"protected": false`, no rulesets), but the
  repository's own rules make it protected in practice: work only in a worktree, the human
  merges. The skill refuses on `main` and on a detached HEAD.
- **CLIs installed:** all three — `codex` (codex-cli 0.167.1), `copilot` (GitHub Copilot CLI
  1.0.105), `claude` (Claude Code 2.1.311), all under `/opt/homebrew/bin`. Codex was kept out
  of every review until the owner allowed it for `/spec-review` on 2026-11-16 (relayed by the
  master); the fourth and fifth real runs use it (see "Final real runs" below).

## Files

| file | what |
|---|---|
| `scripts/ai_review.sh` | the runner: render, three CLIs in parallel, classify, retry, archive, snapshot |
| `scripts/ai_review/prompt.md` | the reviewer prompt template, repository-neutral (`{{DOC_PATH}}`, `{{PROJECT}}`, `{{ORIENTATION}}`, `{{DOC_LAYOUT}}`) |
| `scripts/ai_review/selftest.sh` | the self-test, one command, no network, no real CLI |
| `.claude/skills/spec-review/SKILL.md` | the judgement: branch check, run, merge, re-verify, disposition, fold back, report |
| `AGENTS.md` | new section "Outside review of a document": the skill, the script, the archive, the self-test |
| `docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design/` | the archive of the first real run (`prompt.md`, `findings-claude.md`, `summary.txt`) |
| `docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r2/` | the archive of the second real run, after review round 1 |
| `docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r3/` | the archive of the third real run, after review round 2 |
| `docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r4/` | the fourth real run, all three providers: Codex refused the pinned model |
| `docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r5/` | the fifth real run, all three providers: Codex and Claude `ok` |
| `docs/superpowers/reviews/2026-11-17-specs-2026-10-24-dxf-writer-design/` | the run after review round 3, `--only codex,claude`: both `ok` |
| `docs/superpowers/notes/2026-11-16-spec-review-skill-report.md` | this report |

`.gitignore` needed no change (`git check-ignore` passes none of the new paths). Nothing under
`packages/` or `apps/`, no `analysis_options.yaml`.

## How it was built

Tests first: `selftest.sh` was written before the script and ran red (`13 passed, 112 failed`,
the script absent), then green once the script existed. The real run then showed a Copilot
stderr line the script did not know (below); a test for it went in first (`126 passed,
2 failed`), then the fix.

**Mutation check of the self-test** (each mutation applied to `scripts/ai_review.sh`, the
self-test run, the file restored and compared with `cmp`):

| mutation | self-test |
|---|---|
| M1 no two-half retry | 121 passed, 4 failed |
| M2 answer files named `<provider>.md` | 116 passed, 9 failed |
| M3 providers run one after another | 124 passed, 1 failed |
| M4 Copilot may run shell commands | 124 passed, 1 failed |
| M5 no `-r<N>` suffix on a same-day rerun | 122 passed, 3 failed |
| M6 worktree warning never raised | 122 passed, 3 failed |
| M7 no `timeout` status | 123 passed, 2 failed |
| M8 no duplicate drop when merging halves | 122 passed, 3 failed |
| M9 exit 0 always | 123 passed, 2 failed |
| M10 an existing `--out` is written into | 123 passed, 2 failed |
| M11 auth failures reported as `failed:provider` | 121 passed, 4 failed |
| M12 Claude's `--tools` gains `Bash` | first 125 passed, 0 failed (survived: the check matched `--allowedTools`' value); after tightening the check to the value right after each flag, 125 passed, 1 failed |

**Hermetic flags, checked against each CLI's `--help` today** (not from memory; the Copilot and
Claude lines are as of review round 1, below):

- **Copilot:** `-p <prompt> --model $AI_REVIEW_COPILOT_MODEL (default gpt-6.1-sol) --mode plan -s
  --no-ask-user --available-tools view,grep,glob --no-custom-instructions --disable-builtin-mcps
  --disable-client-telemetry --no-auto-update --sync-session=off --disallow-temp-dir
  --deny-tool=write --deny-tool=shell --deny-tool=url`. No `--trust-folder`; the script refuses
  to call Copilot when a `trustedFolders` entry in `$COPILOT_HOME` (default `~/.copilot`)
  `config.json` or `settings.json` covers the repository. Memory is off in prompt mode by
  default. The tool names `view`, `grep`, `glob` are not in `--help`; I read them from the
  Copilot package installed under `~/.copilot/pkg` (1.0.92). Copilot could not run here (account
  policy), so a real run with them is still owed.
- **Claude:** `-p --model $AI_REVIEW_CLAUDE_MODEL (default fable) --safe-mode --restricted
  --setting-sources= --strict-mcp-config --no-session-persistence --disable-slash-commands
  --tools Read,Grep,Glob --allowedTools Read,Grep,Glob --permission-mode dontAsk
  --max-budget-usd 5`, prompt on stdin. The `-r2` real run used exactly this line.
- **Codex** (as of the reference additions; see "Final real runs" for what the real CLI made of
  it): `exec -m $AI_REVIEW_CODEX_MODEL (default gpt-6.1-sol; gpt-5.5 until the fourth real run) -s read-only --ephemeral
  --ignore-user-config --ignore-rules --skip-git-repo-check -c web_search="disabled"
  -c project_doc_max_bytes=0 --disable apps --disable hooks --disable plugins --disable memories
  -o <answer-file>`. The two `-c` keys were validated locally without a model call:
  `codex -c web_search='"bogus"' features list` fails with `failed to load bootstrap
  configuration`, `codex -c web_search='"disabled"' -c project_doc_max_bytes=0 features list`
  loads. The self-test drives this command line through a PATH shim; the real Codex never ran
  a review.

Every call runs from the repository root under a timeout (default 600 s per call) that kills
the CLI's whole process group and exits 142; INT, TERM and HUP are forwarded to that group too.

## Self-test, real last lines (final, after review round 3)

```
$ scripts/ai_review/selftest.sh
...
PASS r3-3: ... and is counted as ignored

ai_review selftest: 455 passed, 0 failed
```
(exit code 0, under macOS /bin/bash 3.2.57 and under bash 5.3.20 via `AI_REVIEW_TEST_BASH`.) Before round 1 it read `128 passed, 0 failed`; after round 1, `198 passed, 0 failed`; after round 2, `277 passed, 0 failed`; after the reference additions and cross-reviews, `401 passed, 0 failed`. Both runs, the default (the script under `/bin/bash` 3.2.57) and `AI_REVIEW_TEST_BASH=/opt/homebrew/bin/bash` (bash 5.3.20), end the same way. It covers ok, a clean lone
VERDICT, truncated, the two-half retry (duplicate, failing halves), timeout with process-group
kill, interruption by INT/TERM/HUP, not-installed, auth, a Copilot policy denial, quota, model,
all-failed, usage errors, same-day `-r2`/`-r3`, an existing `--out`, parallelism, the
repository root as working directory, the worktree warning, and the three real command lines
through PATH shims with `PATH` cut to the shims plus `/usr/bin:/bin:/usr/sbin:/sbin` (so no real
CLI is reachable, and the script runs under macOS `/bin/bash` 3.2 there).

## The real run

`scripts/ai_review.sh docs/superpowers/specs/2026-10-24-dxf-writer-design.md --only copilot,claude`
(the DXF writer spec: approved, not planned). Exit code 0, about five minutes. `summary.txt`,
verbatim:

```
document: docs/superpowers/specs/2026-10-24-dxf-writer-design.md
date: 2026-11-16
archive: docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design
models: codex=gpt-5.5 copilot=gpt-6.1-sol claude=fable
timeout-per-call: 600s
copilot  failed:provider        0 findings  -
claude   ok                     11 findings  VERDICT: revise — the H2 byte-equality test, the root group and the handle space need decisions before a plan can be cut.
findings: 11 total
hint: copilot: the CLI exited with an error; its stderr is in the run directory printed below
```

**Copilot:** its stderr was `Error: Access denied by policy settings (Request ID: …)` with a
pointer to github.com/settings/copilot. The same error comes back from a bare
`copilot -p "Reply with the single word: pong" -s --no-ask-user` run from an empty scratch
directory, with `--model gpt-6.1-sol` and with `--model auto`: the account's Copilot CLI
access is off, not a review flag. The script now classifies that line as `skipped:auth` with a
hint naming the settings page. **The first archive's `summary.txt` still records
`copilot failed:provider`** (and a `models:` line naming codex, which did not run, and a hint
pointing at a run directory it never names): it was written by the script before these fixes,
and archives are never edited.

**Second real run, after review round 1** (same command; lands in `-r2`, the first archive
untouched). Exit code 0, 226 s. `summary.txt`, verbatim:

```
document: docs/superpowers/specs/2026-10-24-dxf-writer-design.md
date: 2026-11-16
archive: docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r2
models: copilot=gpt-6.1-sol claude=fable
timeout-per-call: 600s
copilot  skipped:auth           0 findings  -
claude   ok                     11 findings  VERDICT: revise — two binding contradictions (group export rule, H2 byte-equality gate) must be resolved before a plan is written.
findings: 11 total
hint: copilot: not signed in, or Copilot CLI access is off for the account; run 'copilot' and use /login, or check the policies at https://github.com/settings/copilot, then rerun with --only copilot
```
No `warning:` line: the wider snapshot (git-ignored files, git config and hooks, archive
contents) saw nothing change, and no answer names a path outside the repository. Its 11
findings are not merged into the table below, which stays the first run's.

## Merged findings of the first run (shown here only; the spec is unchanged)

One provider answered, so no two rows merged. Every row was re-verified against the
repository before acceptance, as the skill requires; F11 is a fact about DXF, not the
repository, and was checked against DXF's version history as I know it.

| # | sources | severity | finding | disposition | would apply in |
|---|---|---|---|---|---|
| 1 | claude:major | major | H2's byte-for-byte test cannot hold: `$EXTMIN/$EXTMAX` are "the document's computed extents" (`DraftDocument.extents`, over every entity) while `PlanPageFlows.omittedOf` returns group handles and leaves the geometry in the copy | accepted (verified: `extents` getter in `draft_document.dart`, `omittedOf` in `page_flows.dart`, "Version and header") | Version and header; The plan library |
| 2 | claude:major | major | The root is a component-carrying group (`ManifestComponent`, `PageComponent` on `rootHandle`), so the GROUP rule would make it a DXF GROUP and leaves the document XRECORD's owner undefined | accepted (verified: `manifest.dart`, `plan_page_panel.dart`) | Containers and transforms; Semantics |
| 3 | claude:major | major | Pointers in JETCAD JSON and DXF codes 330/340 are not said to be in written-handle space, while `OriginComponent.id` is a free string | accepted (verified: `origin_component.dart`, `final String id`) | Handles |
| 4 | claude:major | major | Transparency maps only 0–255; `kByLayer`/`kByBlock` (stored in an `Int16List`, `InstanceNode`'s default is `kByBlock`) have no mapping | accepted (verified: `entity_store.dart` `_transparency`, `InstanceNode` doc in `node.dart`) | Entity style columns |
| 5 | claude:minor | minor | "Groups never as anonymous blocks" contradicts `GroupNode`'s doc comment ("Exports as an anonymous block rather than a DXF GROUP") without saying it supersedes it | accepted (verified: `GroupNode` doc comment, `node.dart`) | Containers and transforms |
| 6 | claude:minor | minor | An exploded (sheared) instance's ATTRIBs, nested instances and BLOCK emission are undefined | accepted (verified: `InstanceNode` doc on owned ATTRIBs) | Containers and transforms |
| 7 | claude:minor | minor | A TTF style is written "by font file name", but `TextStyleRecord` has no file name for TTF | accepted (verified: `fontFamily`, `isShx`, `shxFileName` in `tables.dart`) | Tables |
| 8 | claude:minor | minor | No version bump named for `jet_cad_2d_plan` (now 1.0.2), and the new request member must be optional to be non-breaking | accepted (verified: `pubspec.yaml`, `PlanExportRequest` constructor in `registries.dart`) | The plan library |
| 9 | claude:minor | minor | "A leaf under an invisible node is written invisible" is ambiguous for an `InstanceNode` (INSERT code 60 vs. shared definition leaves, GROUP membership) | accepted (verified: `InstanceNode.visible`; "Hidden nodes" bullet) | Entity style columns |
| 10 | claude:minor | minor | "A new built-in exporter joins the test's list" relies on a hand-written list; the test should enumerate the default exporters | accepted (verified: "H2 enforced by test" bullet, `checkRegistry` in `page_flows.dart`) | Verification |
| 11 | claude:hunch | hunch | AC1027 is not "the oldest version that is UTF-8 throughout": UTF-8 arrived with R2007 (AC1021), true colour and transparency with R2004 | accepted (external fact, from DXF version history; no repository source) | Version and header |

By severity: blocker 0, major 4, minor 6, hunch 1.

## Review round 1

An independent review of the uncommitted work raised 3 HIGH, 7 MEDIUM and 13 LOW findings. I
checked each against the code before fixing it and found none wrong. Method: every new
self-test case went in first; the whole extended self-test was run against the unchanged
script (`135 passed, 58 failed`, every failure traced to one of the findings below, plus
knock-on failures in the "ok" block: the accepted `c.dex` run had claimed the base archive
name); then the script was fixed (`193 passed, 0 failed`); then each fix was mutated back.
Two mutations survived that first pass (H3b, M7b); for each I added the test that was missing
and showed the mutation red. Final after round 1: `196 passed, 0 failed`; after the late HIGH below: `198 passed, 0 failed`.

| finding | test added | fix | mutation → self-test |
|---|---|---|---|
| H1 a lone VERDICT trims to empty and ends `truncated` | `clean:` a fake that answers only `VERDICT: ready — …` must be `ok`, 0 findings, exit 0, not retried | the trim starts at the first `F<n> [` **or** `VERDICT:` line | trim starts only at `F<n>` → 190 passed, 3 failed |
| H2 `--only` checked with a regex, name reaches `eval` | `usage:` `--only c.dex` and `--only 'c[$(touch …)o]dex'` exit 2, the marker file never appears | `case "$p" in codex\|copilot\|claude)`; `hook_for` is a three-arm `case`; no `eval` left | check accepts `c*` → 182 passed, 11 failed |
| H3 no trap for INT/TERM/HUP; orphaned provider, half archive | `interrupt (INT/TERM/HUP):` the script, started in its own process group, gets the signal on the group; it must exit 130/143/129 within 10 s, the provider and its child must be gone, no archive left. `interrupt (timer):` the script SIGKILLed, then TERM to the group: the provider must still die | the per-call timer registers its provider's process group in the run directory and forwards INT/TERM/HUP to it; the script traps the three, kills every registered group and its jobs, removes the archive it claimed, exits 128+n | (a) no script traps → 189 passed, 4 failed; (b) timer does not forward → first 193 passed, 0 failed (survived: the script's trap killed the groups); after adding `interrupt (timer)` → 194 passed, 2 failed |
| M1 a failed half still gives `ok` | `retry:` half A failing and half B failing each exit 1 as `failed:provider`; the merged VERDICT must be half B's, half A's must be gone | both halves must exit 0, else the failing call's status; the VERDICT comes from half B only | (a) failing half ignored → 190 passed, 3 failed; (b) VERDICT from either half → 191 passed, 2 failed |
| M2 `[ -e ]` then `mkdir -p` lets two runs share an archive | `race:` six concurrent runs on one document must leave six archives, each with its own `summary.txt` | the archive is claimed with a plain `mkdir`, looping to `-rN` on failure; `--out` fails when its `mkdir` fails | check-then-`mkdir -p` → 191 passed, 2 failed (one archive for six runs) |
| M3 auth/quota text on stdout becomes `failed:provider` | `auth:`/`quota:` the message on stdout with exit 1; `cli:` the codex shim prints `401 Unauthorized` to its event log | classification searches stderr, the raw answers of all calls and codex's event log | not mutated (not in the requested set) |
| M4 snapshot misses ignored files, git hooks and config, archive extras | `worktree:` a change to a git-ignored file, a new `.git/hooks/pre-commit`, a `git config --local` change, a stray file inside the archive, a content change to an existing untracked file | the snapshot walks every file under the repository (nested repositories and worktrees skipped) with sub-second mtime and size, plus the git config, `config.worktree`, `hooks/` and `info/` of the git dir and common dir; the archive is checked by name, and `prompt.md` against the rendered copy | not mutated |
| M5 Copilot: user MCP servers, saved trust, sync | `cli:` `--available-tools view,grep,glob`, `--sync-session=off`, `--disallow-temp-dir`; `copilot-trust:` a `trustedFolders` entry for the repository or its parent (in a fake `COPILOT_HOME`) refuses the call (`failed:provider`, hint names `trustedFolders`, copilot never called); an unrelated entry does not | the three flags (all in `copilot --help`); `--available-tools` filters every tool the model sees, MCP tools included; the trust check reads `$COPILOT_HOME/config.json` and `settings.json` (this machine's have no `trustedFolders` today). This also closes my earlier open point on session state as far as the CLI allows: account sync is off; local session files are still written | not mutated |
| M6 file tools not confined to the repository | `cli:` claude gets `--restricted`; `untrusted:` an answer naming `/etc/hosts` gives `warning: findings-codex.md names paths outside the repository`, an absolute path inside the repository does not. **Corrected in round 3:** treating that as correct was wrong. Such a path carried the home directory and the user name into a tracked archive unflagged. Paths inside the repository are now rewritten relative (R3-2) | Claude `--restricted` (file tools confined to the working directory, per `claude --help`); Codex has no read-confinement flag in `codex exec --help` (only `--add-dir` to widen), so the script flags outside paths and the skill gained a step that checks the archive for outside content, tokens or account names before anything is committed | not mutated |
| M7 timeout test passes with the group kill removed | `timeout:` the fake ignores TERM and spawns a child; both must be dead afterwards, and a 2 s timeout must return within 10 s | (test only; the group kill was already there) | (a) kill the pid, not the group → 192 passed, 1 failed; (b) kill nothing → first 193 passed, 0 failed (survived: the fake's 60 s sleep ended on its own); after adding the elapsed-time check → 193 passed, 3 failed |

**LOW findings**

| finding | done |
|---|---|
| "ignores SIGALRM" case tests its own fake; wall-clock branch unreachable | both deleted; the timer now kills with TERM then KILL, and the timeout case uses a fake that ignores TERM |
| shim never checks the prompt reaches a CLI, `dontAsk`, `--max-budget-usd`, `-m` | added: copilot's `-p` value, claude's stdin, codex's last argument, claude `--permission-mode dontAsk` and `--max-budget-usd 5`, codex `-m gpt-5.5`, every flag value checked as the argument right after its flag |
| no case for a content change to an existing untracked file | added (`scratch.txt`) |
| run the script under `/bin/bash`; not-installed with hooks unset and PATH without the CLIs | done: every case runs `/bin/bash "$SCRIPT"`; new case with no hook and `PATH=/usr/bin:/bin:/usr/sbin:/sbin` gives three `skipped:not-installed`, exit 1 |
| `--timeout` checked per line with grep | `case` pattern; a two-line value is exit 2 (tested) |
| the two halves are stateless, "remaining findings" refers to nothing | both retry prompts now quote the cut-off first answer between marker lines, as data; the dedupe key is the section plus the claim, both lower-cased with punctuation collapsed (tested: the retry prompt carries the first answer) |
| a fatal error after the archive exists leaves it without `summary.txt` | the prompt is rendered into the run directory before the archive is claimed, and any later setup error removes the claimed archive (no test: no remaining fatal path after the claim can be triggered from outside) |
| VERDICT unbounded and unfiltered in `summary.txt` | control bytes stripped, capped at 200 bytes on a UTF-8 boundary with ` [cut]` (tested); `SKILL.md` says VERDICT lines and anything quoted in `summary.txt` are untrusted |
| `failed:provider` hint names a run directory the summary never shows; `archive:` not a path outside the repo | the hint now says stderr is not archived (it may hold account details) and stays in the run directory printed on the terminal; kept out of the tracked summary on purpose. Outside the repository the `archive:` line gives the absolute path |
| `--only ""` runs all three | exit 2 (tested) |
| symlinked document | refused, exit 2 (tested) |
| `SKILL.md`: fifteen minutes vs worst case; branch guard; own words | "five to fifteen minutes, up to about half an hour when a provider is retried in halves"; "`main` or any other branch the repository protects (here, only `main`)"; folded findings and the table's `finding` cell must be restated in the skill's own words, never pasted |
| the first archive records `copilot failed:provider` | stated under "The real run" above |

Also fixed while there: the `models:` line names only the providers that ran (tested).

**Late HIGH: git-ignored documents.** This repository does have git-ignored document
directories: `git check-ignore -v` names `.superpowers/` (`.gitignore`, the in-flight SDD
ledgers, briefs and reports) and `.claude/worktrees/` (nested worktrees) for any `.md` beneath
them; `docs/superpowers/specs/` and `docs/superpowers/notes/` are not ignored. Test first: the
fixture's `.gitignore` gained `.superpowers/`, and two `usage:` cases review
`.superpowers/sdd/p/brief.md` and `ignored/notes.md`; both must exit 2 with no archive written.
Against the unchanged script: `195 passed, 3 failed` (both ran and archived). Fix: the script
refuses any document `git check-ignore` reports as ignored, before anything is rendered or
claimed. Then `198 passed, 0 failed`; with the check disabled (mutation) `195 passed, 3 failed`.

**About the stray `pkill -f 'sleep 47'`:** none of my fakes or runs used `sleep 47` (they use
`sleep 60`, `sleep 2`, `sleep 1`), so that pattern could not match them, and no run of mine
ended early or gave odd numbers. The self-test was rerun after it anyway (the 198 above).

## Review round 2

A second independent review: all ten round-1 fixes held; it raised 1 HIGH and 7 MEDIUM new or
remaining findings, plus LOW items. I checked each against the code and found none wrong.
Method as in round 1: all new cases first, run against the unchanged script
(`223 passed, 49 failed`, every failure traced to a finding below), then the new script
(`272 passed, 0 failed`), then mutations in isolated copies of `scripts/`, three at a time.
Three things needed a second pass, each recorded below: two tests that could not fail (R2-4,
R2-7) and one old check whose proxy no longer held. Final: `277 passed, 0 failed` under
`/bin/bash` 3.2.57 and under bash 5.3.20.

One old check changed meaning, not strength: "clean: a lone VERDICT is not retried" used the
absence of `findings-<p>.raw.md` as its proxy, and R2-1 now writes `raw.md` whenever the trim
drops text. It now counts the fake's calls (must be 1).

| finding | test added | fix | mutation → self-test |
|---|---|---|---|
| R2-1 decorated headers or VERDICT-first answers are `ok` with 0 findings; findings lost | `r2-1:` `**F1 [major] Intent**`, `### F2 [MINOR] Decisions  `, `- claim:`, `**VERDICT:**` must give `ok`, 2 findings, canonical lines in the archive, dropped prose in `raw.md`; VERDICT-first must give `truncated` with both findings archived; prose plus `VERDICT: revise` must give `truncated`, 0 findings | answers are normalized first (optional `#`, `*`, `_`, `>`, `-` and spaces around `F<n> [`, `VERDICT:` and the field names; severity lower-cased); a finding after the last VERDICT keeps the whole rest and makes the provider `truncated`; `ok` with 0 findings needs a `ready` verdict; whenever the trim drops a non-blank line, the whole answer is archived as `findings-<p>.raw.md` | (a) no normalization → 269 passed, 4 failed; (b) findings after the VERDICT ignored → 271 passed, 2 failed; (c) `ok` with 0 findings and revise → 272 passed, 1 failed |
| R2-2 the first VERDICT wins; a quoted one cuts the answer | `r2-2:` a finding quoting `VERDICT: ready — …`, the real last line `VERDICT: reject — …`: `ok`, 2 findings, verdict `reject` | the trim runs through the **last** VERDICT line and the verdict is taken from it; in the retry merge only half B's last VERDICT counts and other VERDICT lines stay in their finding | (a) trim ends at the first VERDICT → 272 passed, 1 failed; (b) verdict from the first VERDICT → 272 passed, 1 failed |
| R2-3 other runs' archives warn; ignored names in the tracked summary; uncapped; misleading wording | `r2-3:` none of the six concurrent runs' summaries warns; 60 new files give a summary of at most 40 lines in all, with `and N more` (the cap itself is `CHANGES_MAX=20` entries plus that line); the warning reads `(by a reviewer or anything else)`; `worktree:` a changed git-ignored file is only counted in `summary.txt` and named on the terminal. **Corrected in round 3:** "only counted" was false for names git quotes (non-ASCII, `"`, `\`, tab). Those were classed as tracked and named; fixed in R3-3 | the whole reviews directory is left out of the walk and out of `git status`; at most 20 entries plus `... and N more`; git-ignored paths (`git check-ignore --stdin`) are counted in `summary.txt` and listed on the terminal only; `SKILL.md` says the change may come from a reviewer or anything else in the checkout and has to be explained before the run is trusted | (a) reviews directory walked again → 270 passed, 3 failed; (b) ignored paths named in the summary → 270 passed, 3 failed |
| R2-4 snapshot misses commits, branch switches, same-shape rewrites, chmod, empty directories, nested repositories | `r2-4:` an empty commit (`git HEAD` entry), `checkout -b planted` (`git branch refs/heads/planted` entry), a same-size rewrite of the untracked `scratch.txt` with its mtime put back, `chmod +x scratch.txt`, `mkdir emptydir`, `git init ignored/nested`: each must be flagged | the snapshot adds `HEAD`, the current branch, every ref (`for-each-ref`), `git status --porcelain -uall` (reviews directory filtered), and per path its type and mode, and for files sub-second mtime, **ctime** and size; directories and symlinks are entries; a nested repository is one entry by its top directory (changes inside an existing one are not tracked, as other worktrees under `.claude/worktrees/` change on their own) | (a) no HEAD, branch or refs → 271 passed, 2 failed; (b) no mode or ctime → 272 passed, 1 failed; (c) no directory entries → first 273 passed, 0 failed (survived: the check `emptydir` matched the archive path `o-emptydir` in the `archive:` line; every R2-4 check is now anchored on its warning entry) → 276 passed, 1 failed; (d) nested repositories skipped silently → 271 passed, 2 failed. The chmod and rewrite cases first used tracked files, which `git status` also catches; they moved to an untracked file so mode and ctime are what is tested |
| R2-5 the caller's environment reaches the CLIs (`COPILOT_ALLOW_ALL=true` would trust the folder) | `env:` the shim run sets `COPILOT_ALLOW_ALL=true`, `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` and `AI_REVIEW_PLANTED`; each shim records its environment: none of the three may arrive at any CLI, `HOME`, `PATH` (and Copilot's `COPILOT_HOME`) must | every provider, real or fake, runs as `/usr/bin/env -i <allow-list> <cli> …`. Common list: `HOME USER LOGNAME PATH SHELL TERM LANG TMPDIR TZ`, the proxy variables, `SSL_CERT_FILE SSL_CERT_DIR NODE_EXTRA_CA_CERTS`; Codex adds `CODEX_HOME OPENAI_API_KEY OPENAI_BASE_URL`; Copilot `COPILOT_HOME GH_TOKEN GITHUB_TOKEN COPILOT_GITHUB_TOKEN GH_HOST XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME`; Claude `ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CONFIG_DIR`. The real Claude still authenticated under it (third real run, below) | environment not scrubbed → 264 passed, 9 failed |
| R2-6 error words in answers or the event log decide the status | `r2-6:` a crashed call whose finding says "Unauthorized", another whose finding says "usage limit": both `failed:provider`; "Not logged in" on stdout with exit 0: `skipped:auth` after one call; `cli:` repository text with "Unauthorized" early in Codex's event log, then 40 events and a crash: `failed:provider` | stderr is searched with every pattern; stdout only when the answers hold no finding or VERDICT line; Codex's event log only in its last 20 lines; an exit-0 answer with no finding or VERDICT is checked for auth/quota/model text before any retry | (a) stdout searched even with findings → 271 passed, 2 failed; (b) whole event log searched → 272 passed, 1 failed; (c) exit-0 stdout not checked → 271 passed, 2 failed |
| R2-7 traps installed after the run directory and the archive exist | `r2-7:` thirty runs, each in its own process group, TERMed 0–100 ms after start: no archive, no run directory left. Then deterministic: a `mkdir` shim that creates the archive and lingers, and a `mktemp` shim that creates the run directory and lingers; TERM to the group while they linger: nothing left | the three signals are trapped as the script's first act, recorded while setup runs and acted on as soon as the archive is claimed; the handler tolerates empty variables and removes only what this run created; the `mktemp` and archive `mkdir` run with the signals ignored (a group signal cannot kill them between creating the directory and the script recording it) | (a) traps installed late → 272 passed, 1 failed (7 run directories left); (b) setup steps not shielded → first 273 passed, 0 failed (survived: the thirty-run burst never hit that window); after adding the lingering-`mkdir` case → 276 passed, 1 failed |
| R2-8 any file name in the pgid directory becomes a kill target | `r2-8:` a copy of the script whose `kill` is a shell function that only records its arguments (never real `kill`); the fake plants `0 1 7 abc 99999999 ../x` in the pgid directory; TERM to the copy's pid alone: none of the planted names may appear as a target, the real provider group must | a name is a target only if it is all digits, at least two of them, no leading zero, and `ps -o pgid= -p <n>` reports exactly `<n>`; the same check guards the final sweep | every name a target → 272 passed, 5 failed |

**LOW items**

| item | done |
|---|---|
| a SIGKILLed timer leaves the provider and a stale pgid file | after the final `wait` the script kills every remaining valid group and clears the pgid directory; tested (the fake SIGKILLs its timer, sleeps on; it must die, and the run must not wait for it). Mutation "no final sweep" → 272 passed, 1 failed |
| a provider child that starts its own process group survives | said in the header comment |
| run directories never removed (one self-test run left 46) | `$RUN` is removed when every provider is `ok`, in `die2` and on a signal; kept, with its path printed, otherwise. The self-test exports `TMPDIR` inside its own temp directory. Tested (all-ok run, interrupted run). Mutation "run directory kept after a signal" → 271 passed, 2 failed |
| Codex feature check passes `--enable hooks` | each feature name must be preceded by `--disable` |
| signals only to the group | `low:` TERM to the script's pid alone (real `kill`): exit 143, provider and child dead, no archive, no run directory; the R2-8 recorder case also signals the pid alone |
| surviving round-1 mutations | leftover group after a normal exit: tested (the fake leaves `sleep 60 &` behind; it must die); review archive as a document: tested (exit 2; mutation → 272 passed, 1 failed); no `cd "$ROOT"` on Claude's real path: the shims now record their working directory (mutation → 272 passed, 1 failed); Codex's `< /dev/null` dropped: **equivalent mutant**, 277 passed, 0 failed: providers run inside a background job, and a non-interactive bash gives a background job `/dev/null` as stdin already. The redirect stays, and the shims now check that neither Copilot nor Codex reads the caller's stdin and that Claude's stdin is the prompt |
| retry merge keeps `[MAJOR]` or trailing-space duplicates | headers are normalized before merging; tested |
| stray-file check skips names starting with `..` | the archive is listed with `ls -A`; tested with `..planted` |
| "429 Too Many Requests", "HTTP 401", "hit your limit" | added on stderr only: `HTTP 401` (followed by a non-digit or the end) → `skipped:auth`; `429 Too Many Requests`, `HTTP 429`, `hit your limit` → `skipped:quota`; tested |
| what `--help` cannot settle | stated under "What I could not do" below |

I deleted the run directories my own runs left in `$TMPDIR`: 830 `ai_review.*` directories,
828 of them identified as mine by this repository's prompt text in their `prompt.md`, and 2
empty ones created during my round-1 test window. After the final runs none is left.

**Third real run, after review round 2** (`--only copilot,claude`, lands in `-r3`; `-r1` and
`-r2` untouched). Exit code 0, 292 s. `summary.txt`, verbatim:

```
document: docs/superpowers/specs/2026-10-24-dxf-writer-design.md
date: 2026-11-16
archive: docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r3
models: copilot=gpt-6.1-sol claude=fable
timeout-per-call: 600s
copilot  skipped:auth           0 findings  -
claude   ok                     12 findings  VERDICT: revise — group records, H2 byte-equality, transparency sentinels and origin-id handles need decisions before planning.
findings: 12 total
hint: copilot: not signed in, or Copilot CLI access is off for the account; run 'copilot' and use /login, or check the policies at https://github.com/settings/copilot, then rerun with --only copilot
```
Claude ran under the scrubbed environment and authenticated. Copilot's stderr was again
`Error: Access denied by policy settings`. No `warning:` line. The archive has a
`findings-claude.raw.md`: Claude opened with one line of prose ("Verification done; writing the
findings now."), which the trim dropped and the raw file keeps. Its 12 findings are not merged
into the table above.


## Reference additions (one implementation for the four repositories) and the cross-reviews

The owner decided that the four repositories share one implementation and that this one is the
reference. Two cross-reviews of the other repositories' scripts added cases. Method, test first
throughout:

1. The self-test was rewritten to read the config block out of the script and build every
   fixture from it. Against the round-2 script it stopped at once: `selftest: no usable config
   block`.
2. Stage b: only the config block and the neutral template went in. Against that,
   `346 passed, 43 failed`. Every failure traced to one of the items below, plus knock-on
   failures in the "ok" block (stage b still ran on the protected branch and took the base
   archive name).
3. The full reference script: `390 passed, 0 failed`.
4. The real Codex run showed one more fix (model pin and pattern); its tests went in first
   (`389 passed, 4 failed`), then `393 passed, 0 failed`.
5. Six-way parallel mutation runs exposed a real race, which deterministic tests then
   reproduced (`397 passed, 3 failed`). Fixed: `400 passed, 0 failed`.
6. One stderr test was strengthened after its mutation survived. Final: `401 passed, 0 failed`
   under `/bin/bash` 3.2.57 and under bash 5.3.20.

Several cross-review cases already passed on my script. They stay in the self-test and are
marked "already passed" below.

**Reference items**

| item | test | change |
|---|---|---|
| 1. one config block; repository-neutral template; fixture from the config | the self-test sources the block (`AI_REVIEW_PROJECT`, `REVIEWS_REL`, `IGNORED_REVIEWS_REL`, `PROTECTED_BRANCHES`, `ORIENTATION`, `DOC_LAYOUT`, `SLUG_STRIP`) and builds the fixture, its orientation files and its branches from it; `porting:` the template carries `{{DOC_PATH}}`, `{{PROJECT}}`, `{{ORIENTATION}}`, `{{DOC_LAYOUT}}` and not the project name; nothing below the block repeats a config value; the rendered prompt names every orientation file, the project and the layout; `usage:` the first protected branch and a detached HEAD exit 2; one script copy per ignored-document policy | the block at the top of `scripts/ai_review.sh`; the header is neutral too; the script itself refuses a protected branch and a detached HEAD |
| 2. ignored documents, second policy | `policy archive:` (a copy with the ignored reviews directory set) the ignored document is reviewed into the ignored directory, nothing visible to git appears, no tracked archive names it, a concurrent tracked run's summary never names it; `--out` refused when tracked, through `..`, through a symlink, through a differently-cased spelling (ran here, case-insensitive APFS), in another repository; accepted outside any repository and in an ignored directory; a symlink to the ignored document refused; an ignored reviews directory that git does not ignore refused. `policy refuse:` the same document exits 2 with the setting empty (this repository's setting) | the archive goes to `IGNORED_REVIEWS_REL`; `--out` is decided by git (`rev-parse --show-toplevel`, then `check-ignore`) from the deepest existing directory, each existing component resolved physically, `..` in the to-be-created part cancelled as `mkdir -p` would; the archive is created exactly at the checked path; both reviews directories are left out of the snapshot. `SKILL.md`: such an archive is never committed and the fold-back goes into the ignored document only |
| 3. env-file preflight | `env-file:` a FIFO named `.env` (the run would hang if the script opened it) gives `codex skipped:unconfined`, a hint naming the file and the flag, codex never called, claude and copilot still run; `--allow-unconfined` lets codex run; `.env.example/.sample/.template` do not count, `.env.local` does; an env file in the main checkout of a linked worktree counts and the hint says so | names only (`-e`), in the root and, for a linked worktree, in the main checkout (from `--git-common-dir`); new status `skipped:unconfined` for providers listed in `UNCONFINED_PROVIDERS` (codex); `--allow-unconfined`; a `warning: env file(s) present` line; header, summary hint and `SKILL.md` name the status |
| 4. provenance | `provenance:` `document-blob:` equals `git hash-object`, `commit:` equals `git rev-parse HEAD` | two summary lines; `SKILL.md` puts both in the fold-back header line |
| 5. archived stderr | `stderr:` a fake's stderr with a `ghp_` token, a request id, a home path and an `sk-ant-` key: the error line is in the summary, none of the four strings anywhere in the archive; an ok provider's stderr never in the summary; a repeated line once; an echoed error-shaped line outside the last 20 lines and an echoed line inside them that only contains "error" are not kept | for a non-ok provider, up to three of the last 20 stderr lines that *start* as errors, deduplicated, paths, request ids, token-shaped and long hex strings masked, control bytes stripped, 200 bytes each; nothing else of stderr leaves the run directory |
| 6. `SKILL.md` | — | background start and completion notice (foreground capped at ten minutes, worst case about thirty); stop on the test-hook warning (the script now writes `warning: test hook AI_REVIEW_BIN_<P> is set`, tested both ways); report env-file and worktree warnings before folding; ask before reverting anything; stop a run with TERM |
| 7. portability | `portable:` `/bin/bash -n` on both files is a case; the whole self-test runs under `/bin/bash` 3.2 and once more under bash 5.3 | no `case` inside `$( … )`, no bash 4 syntax; the header says so |

**Rows from the cross-review**

| case | test | result |
|---|---|---|
| A1 signal to the pid alone in the launch window and between retry calls | `sweep:` 42 trials (TERM and INT, 0 to 1.0 s in 0.05 s steps) over the launch window and 20 around the retry boundary; every provider pid and child pid recorded, all must be dead 1.5 s after the script exits. Plus `window:` a copy whose timer waits 2 s between fork and group registration; TERM to the pid must still kill the provider | the sweeps **already passed** on the round-2 script (my launch window is a few milliseconds); the window case is new and passes because each provider job traps the signal and forwards it to its timer, and the timer installs its handlers before it forks. Mutations "jobs do not forward" and "handler does not kill its jobs" both survived the sweeps and are red on the window case |
| A2 a signal after `summary.txt` keeps the archive | `late signal:` a copy that sleeps right after writing the summary; TERM then must leave the archive | `DONE=1` on the same line that writes `summary.txt`; the handler keeps the archive after it |
| A3 the pgid path is not in the provider's environment | `env:` no variable naming the run directory or `pgids` reaches any shimmed CLI | **already passed** (`env -i`); the timer also deletes `AI_REVIEW_PGIDS` from its own environment |
| A4 `--out` for an ignored document decided by git, not strings | the `policy archive:` `--out` cases above (case variant, `..`, symlink, other repository) | see item 2 |
| A5 a symlink to an ignored document | `policy archive:` refused | **already passed** (symlinks are refused altogether) |
| A6 the first answer's findings survive a failed half or a smaller merge | `retry:` half B fails: `findings-claude.md` keeps the first answer's F2, status `failed:provider`, 2 findings; halves with fewer findings: F2 kept | the merge takes the first answer, then the halves, deduplicated; any non-skipped status archives what the answer held |
| A7 environment scrub through the real command lines | `env:` the shim run plants `GH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL OPENAI_API_KEY OPENAI_BASE_URL COPILOT_PROVIDER_BASE_URL COPILOT_CUSTOM_INSTRUCTIONS_DIRS COPILOT_ALLOW_ALL CODEX_HOME HTTPS_PROXY AWS_SECRET_ACCESS_KEY AI_REVIEW_PLANTED`; each shim records its environment | none arrives anywhere except a provider's **own** credential variables, which stay because a login can live there: `OPENAI_API_KEY` and `CODEX_HOME` reach codex only, `GH_TOKEN` copilot only, `ANTHROPIC_API_KEY` claude only (asserted both ways). Dropped since round 2: `OPENAI_BASE_URL` and every proxy variable |
| A8 `--only` and `--timeout` checked as strings first | `usage:` `--timeout $'5\n+calls[$(touch …)]'` exits 2 and runs nothing; a seven-digit timeout exits 2; `--only $'codex\nclaude'` exits 2 | timeout: digits only, no leading zero, at most six; `--only`: `[a-z,]` only, before splitting (the newline case **already passed** through the per-name `case`) |
| A9 screening for content quoted from ignored paths | — | `SKILL.md` step 3: screen a tracked archive for anything from `.env` files, ignored specs or `.git/config`, since `--restricted` confines Claude to a directory that contains them |
| A10 snapshot blind spots | `snapshot:` `.git/info/exclude`, `.git/info/attributes`, a new tag, a hook's mode change, a file in a `core.hooksPath` directory outside the repository, `config.worktree` of a linked worktree | `info/` and refs were **already** watched; added the `core.hooksPath` target |
| A11 Codex project config and feature names | `cli:` each feature name is preceded by `--disable` | `codex features list` (a local listing) has `apps`, `hooks`, `plugins` and `memories`. Neither this repository nor its main checkout has a `.codex/` directory, so whether `--ignore-user-config` also skips a project-level `.codex/config.toml` is untested here. No throwaway Copilot home is used, so no login record is copied anywhere |
| A12 comments that claim more than the code | — | the header now says what the flags guarantee and what not: no write tools, reads confined for Claude and Copilot but not Codex, ignored files inside the repository readable by all, each CLI still reading its own login and home |
| B1 header and verdict forms | `forms:` `**F1** [major]`, `- F2`, `1. F3`, `**F4** [blocker]` followed by a plain `F5`, `**VERDICT:** revise` give `ok`, 5 findings; `> VERDICT: ready` inside a finding and a closing `VERDICT: readyness …` are not verdicts (the retry runs); a verdict followed by another finding is `truncated` | normalization accepts `- `, `1. `, `#`, `*`, `_` before the header and markers around `F<n>`; a verdict line counts only if its word is exactly `ready`, `revise` or `reject`, never with a `>` prefix; trim, "has a verdict" and the merge use the same strict rule |
| B2 SIGINT ignored in a background shell | `int-ignored:` started with SIGINT ignored: INT does not stop it (the documented limit), TERM does (exit 143, provider dead) | the header states the limit; `SKILL.md` says to stop a run with TERM |
| B3 a control character in the document path | `usage:` a file named `a<newline>b.md` exits 2 | document and `--out` paths with a control character are refused |
| B4 `--out` in another repository's tracked tree | see item 2 | decided against the repository that contains `--out` |
| B5 a run directory inside the repository | `snapshot:` `TMPDIR` inside the fixture: no worktree warning | the run directory is left out of the walk and of `git status` |
| B6 `git status` without the index lock | `snapshot:` a stat-dirty fixture: `.git/index` mtime unchanged by a run | `GIT_OPTIONAL_LOCKS=0` on every snapshot git call |
| B7 `info/attributes`, `config.worktree` | see A10 | **already** watched |
| B8 per-provider `failed:model` hint | `model:` the codex hint names `AI_REVIEW_CODEX_MODEL` | **already passed** |
| B9 `mktemp -d` with a template; the `< /dev/null` mutant | — | the self-test **already** used `mktemp -d "${TMPDIR:-/tmp}/ai_review_selftest.XXXXXX"`; the stdin assertions stay but claim nothing about that mutant, which is equivalent (round 2) |
| B10 cases the other self-test missed | handler no longer kills its jobs (window case), INT trap dropped (H3a below), stderr lines in the summary (`stderr:`), an interrupt during the retry (retry sweep) | all present, each with a red mutation below |

**Found by the mutation runs themselves** (not on any list):
- **A group signal could kill a command substitution that held a path.** `RUN="$(cd "$RUN" && pwd -P)"` and the same for `OUT` then left the variable empty, and the directory could no longer be cleaned. Seen as the 30-run burst leaving one directory under six-way load. The `race:` cases now delay exactly that resolution in a copy and TERM the group: one run directory and one archive were left before the fix (`397 passed, 3 failed`). Fixed by never assigning a path straight from a command substitution.
- **Codex echoes the files it reads on stderr** (seen in the real run). The error-line filter now takes only lines that start as errors, from the last 20 lines.

**Mutations**: 61 runs in isolated copies of `scripts/`, the round-1 and round-2 sets adapted to
the current code plus one or more per new item. Three runs were stopped half-way when I raised
the parallelism and were rerun. "first run" marks a mutation that survived until the test named
in the last column was added or strengthened.

| mutation | self-test | first failing check |
|---|---|---|
| H1 trim starts only at a finding | 387 passed, 3 failed | clean: a lone VERDICT line exits 0 |
| H2 provider checks accept c* (charset check removed too) | 378 passed, 12 failed | usage: a regex provider name (c.dex) is exit 2 |
| H3a no signal traps once armed | 379 passed, 11 failed | interrupt (INT): the script exits 128+signal |
| H3b timer does not forward signals | 388 passed, 2 failed | interrupt (timer): the provider dies when only the timer gets TERM |
| M1 failing half ignored | 386 passed, 4 failed | retry: half B failing is failed:provider, not ok |
| M2 check-then-mkdir -p claim | 388 passed, 2 failed | race: six concurrent runs claim six archives |
| M7 timeout kills the pid, not the group | 388 passed, 2 failed | timeout: the provider's child is killed |
| R2-1a no normalisation | 383 passed, 7 failed | r2-1: decorated headers are findings (ok, 2 findings) |
| R2-1b findings after the VERDICT ignored | 390 passed, 0 failed | — |
| R2-1c ok with 0 findings and revise | 389 passed, 1 failed | r2-1: 0 findings with a revise VERDICT is truncated, never ok |
| R2-2a trim ends at the first verdict | 389 passed, 1 failed | r2-2: the verdict is the last VERDICT line, both findings kept |
| R2-2b verdict from the first verdict line | 389 passed, 1 failed | r2-2: the verdict is the last VERDICT line, both findings kept |
| R2-3a reviews directory walked | 387 passed, 3 failed | ok: no warning when the reviewers wrote nothing |
| R2-3b ignored paths named in summary.txt | 387 passed, 3 failed | worktree: a change to a git-ignored file is counted in summary.txt |
| R2-4a no HEAD, branch or refs | 387 passed, 3 failed | r2-4: a new commit is flagged |
| R2-4b no mode or ctime | 388 passed, 2 failed | r2-4: a chmod of an untracked file is flagged |
| R2-4c no directory entries | 389 passed, 1 failed | r2-4: a new empty directory is flagged |
| R2-4d nested repositories skipped silently | 388 passed, 2 failed | r2-4: a new nested repository is counted |
| R2-5 environment not scrubbed | 358 passed, 32 failed | env: codex does not receive GH_TOKEN |
| R2-6a stdout searched even with findings | 388 passed, 2 failed | r2-6: 'Unauthorized' inside a finding of a crashed call is failed:provider |
| R2-6b whole codex event log | 389 passed, 1 failed | cli: repository text early in codex's event log does not make a crash skipped:auth |
| R2-6c exit-0 stdout not checked | 388 passed, 2 failed | r2-6: 'Not logged in' on stdout with exit 0 is skipped:auth |
| R2-7a early traps removed | 389 passed, 4 failed | r2-7: thirty runs TERMed early leave no run directory |
| R2-7b setup steps not shielded | 392 passed, 1 failed | r2-7: TERM while mkdir lingers leaves no archive |
| R2-8 every pgid file a kill target | 388 passed, 5 failed | r2-8: a planted pgid file '0' is never a kill target: -TERM -- -0/-TERM -- -1/-TERM -- -7/-TERM |
| LOW no final sweep | 392 passed, 1 failed | low: a provider whose timer was SIGKILLed is swept after the run |
| LOW run directory kept after a signal | 390 passed, 3 failed | r2-7: thirty runs TERMed early leave no run directory |
| N1 orientation not rendered from the config | 391 passed, 2 failed | prompt: orientation names STATUS.md |
| N2a ignored document --out never checked | 386 passed, 7 failed | policy archive: a tracked --out is refused (o-tracked) |
| N2b ignored document --out compared as a string | 388 passed, 5 failed | policy archive: a tracked --out is refused (o-dots) |
| N2c ignored document archived in the tracked directory | 389 passed, 4 failed | r2-7: thirty runs TERMed early leave no archive |
| N3a env files never acted on | 387 passed, 6 failed | env-file: codex is skipped:unconfined |
| N3b main checkout not checked | 391 passed, 2 failed | env-file: an env file in the main checkout of a linked worktree counts |
| N3c example files counted | 391 passed, 2 failed | r2-7: thirty runs TERMed early leave no run directory |
| N4 no blob id in the summary | 392 passed, 1 failed | provenance: summary records the document's blob id |
| N5a stderr lines not masked | 390 passed, 3 failed | stderr: 'ghp_PLANTED' never reaches the archive |
| N5b every stderr line archived | 398 passed, 2 failed (first run: 392 passed, 1 failed) | stderr: 'harmless chatter' never reaches the archive |
| N5c an ok provider's stderr archived | 392 passed, 1 failed | stderr: an ok provider's stderr never reaches the summary |
| N6 no test-hook warning | 257 passed, 136 failed | ok: three good providers exit 0 |
| N7 a bash-4-only parse in the script | 129 passed, 237 failed | ok: three good providers exit 0 |
| C1a provider jobs do not forward signals | 399 passed, 1 failed (first run: 393 passed, 0 failed) | window: a provider whose timer has not registered its group yet still dies on TERM to the pid:  |
| C1b handler does not kill its job subshells | 399 passed, 1 failed (first run: 393 passed, 0 failed) | window: a provider whose timer has not registered its group yet still dies on TERM to the pid:  |
| C2 a signal after the summary removes the archive | 392 passed, 1 failed | late signal: a TERM after summary.txt is written keeps the archive |
| C6a the merge drops the first answer | 391 passed, 2 failed | low: duplicates differing in severity case and trailing spaces are merged |
| C6b a failed provider's findings not archived | 391 passed, 2 failed | retry: a failed half keeps the first answer's findings in findings-<p>.md |
| C7 proxies passed on | 387 passed, 6 failed | env: codex does not receive OPENAI_BASE_URL |
| C8 no length cap on --timeout | 382 passed, 11 failed | usage: a --timeout longer than six digits is exit 2 |
| C10a core.hooksPath not watched | 392 passed, 1 failed | snapshot: the core.hooksPath target is watched |
| C10b git info files not watched | 391 passed, 2 failed | snapshot: .git/info/exclude is watched |
| D1a a quoted '> VERDICT' is a verdict | 392 passed, 1 failed | forms: a quoted '> VERDICT:' and 'VERDICT: readyness' are not verdicts |
| D1b any word after VERDICT: counts | 391 passed, 2 failed | forms: a quoted '> VERDICT:' and 'VERDICT: readyness' are not verdicts |
| D3 control characters in the document path accepted | 391 passed, 2 failed | usage: a control character in the document path is exit 2 |
| D5 the run directory is part of the snapshot | 392 passed, 1 failed | snapshot: the run's own directory inside the repository is not a change |
| D6 git status takes the index lock | 392 passed, 1 failed | snapshot: git status never rewrites the index |
| D8 codex model hint names the copilot variable | 392 passed, 1 failed | model: the codex hint names AI_REVIEW_CODEX_MODEL |
| M8 codex 'model is not supported' not a model failure | 392 passed, 1 failed | model: codex's 'model is not supported' is failed:model |
| M9 repeated error lines not deduplicated | 392 passed, 1 failed | stderr: a repeated error line is archived once |
| M10 error lines not anchored | 400 passed, 1 failed (first run: 400 passed, 0 failed) | stderr: an echoed line inside the tail that only contains 'error' is not kept |
| M11 the whole stderr searched, not its tail | 400 passed, 1 failed (first run: 400 passed, 0 failed) | stderr: an error-shaped echoed line outside the tail is not kept |
| M12 run directory path assigned from a command substitution | 399 passed, 1 failed | race (RUN): no run directory left |
| M13 archive path assigned from a command substitution | 399 passed, 1 failed | race (OUT): TERM while resolving the OUT path leaves no archive |

The one surviving mutation, **R2-1b** ("findings after the verdict ignored"), is equivalent. When
a finding follows the last verdict, the kept part ends in that finding, so the strict last-line
verdict check fails and the status is `truncated` either way. The explicit `lost` branch stays as
a second guard.

## Final real runs: Codex meets the real CLI

The owner allowed Codex for `/spec-review` in this repository on 2026-11-16 (relayed by the
master). Neither this worktree nor the main checkout has an env file, so the preflight let Codex
run; `--allow-unconfined` was not used.

**Fourth run**: `scripts/ai_review.sh docs/superpowers/specs/2026-10-24-dxf-writer-design.md`
(no `--only`), lands in `-r4`, exit 0, 234 s. `summary.txt`, verbatim:

```
document: docs/superpowers/specs/2026-10-24-dxf-writer-design.md
document-blob: d2eca50b22c867dfa3284cb64f22dd64487b2463
commit: 892aad2d72e72ced720642f6ce7b26fa3c99b7c5
date: 2026-11-16
archive: docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r4
models: codex=gpt-5.5 copilot=gpt-6.1-sol claude=fable
timeout-per-call: 600s
codex    failed:provider        0 findings  -
copilot  skipped:auth           0 findings  -
claude   ok                     10 findings  VERDICT: revise — root-as-GROUP and the omit-vs-delete byte test are contradictions; the rest are gaps a plan would hit.
findings: 10 total
hint: codex: the CLI exited with an error; its error lines (masked) follow; the rest of its stderr is not archived
error: codex: ERROR: The 'gpt-5.5' model is not supported when using Codex with a ChatGPT account.
error: codex: ERROR: The 'gpt-5.5' model is not supported when using Codex with a ChatGPT account.
hint: copilot: not signed in, or Copilot CLI access is off for the account; run 'copilot' and use /login, or check the policies at https://github.com/settings/copilot, then rerun with --only copilot
error: copilot: Error: Access denied by policy settings (request-id <masked>)
```

What it showed:
- Codex accepted the whole command line. Its stderr header reads `model: gpt-5.5`, `provider:
  openai`, `approval: never`, `sandbox: read-only`, and it got as far as the model call, then
  printed a fallback-metadata warning and the error above. No line complained about a flag, a
  `-c` key or a feature name.
- Only the pinned model was refused, so `gpt-5.5` (a guess from earlier use) is wrong for this
  login. The local models cache (`~/.codex/models_cache.json`, fetched today by the CLI itself)
  lists `gpt-6.1-sol` first. The default pin is now `gpt-6.1-sol`, still overridable with
  `AI_REVIEW_CODEX_MODEL`.
- The message should have been `failed:model`, and the line appeared twice. Both are fixed,
  test first (the `model:` and `stderr:` cases).
- This archive keeps what it recorded.

**Fifth, final run**: the same command, lands in `-r5`, exit 0, 294 s. `summary.txt`, verbatim:

```
document: docs/superpowers/specs/2026-10-24-dxf-writer-design.md
document-blob: d2eca50b22c867dfa3284cb64f22dd64487b2463
commit: 892aad2d72e72ced720642f6ce7b26fa3c99b7c5
date: 2026-11-16
archive: docs/superpowers/reviews/2026-11-16-specs-2026-10-24-dxf-writer-design-r5
models: codex=gpt-6.1-sol copilot=gpt-6.1-sol claude=fable
timeout-per-call: 600s
codex    ok                     6 findings  VERDICT: revise — Manifest preparation, reversible semantics, exploded identities and export verification need explicit decisions.
copilot  skipped:auth           0 findings  -
claude   ok                     9 findings  VERDICT: revise — H2 byte-equality test and the group-as-GROUP reversal need resolving before a plan is written.
findings: 15 total
hint: copilot: not signed in, or Copilot CLI access is off for the account; run 'copilot' and use /login, or check the policies at https://github.com/settings/copilot, then rerun with --only copilot
error: copilot: Error: Access denied by policy settings (request-id <masked>)
```

Codex's exact argv in the fifth run (the environment is what `env -i` passes; `CODEX_HOME` and
`OPENAI_API_KEY` were not set, so they were not passed; the prompt is the rendered `prompt.md`
of the archive):

```
/usr/bin/env -i HOME=<home> USER=<user> LOGNAME=<user> PATH=<path> SHELL=<shell> TERM=<term> LANG=<lang> TMPDIR=<tmpdir> \
  codex exec -m gpt-6.1-sol -s read-only --ephemeral --ignore-user-config --ignore-rules --skip-git-repo-check \
  -c 'web_search="disabled"' -c project_doc_max_bytes=0 \
  --disable apps --disable hooks --disable plugins --disable memories \
  -o <run directory>/codex.out "<prompt>"
```

**Copilot in the final run:** status `skipped:auth`, with the CLI's own error line as the script
archived it, masked: `error: copilot: Error: Access denied by policy settings (request-id
<masked>)`. The owner suspended the Copilot CLI check on 2026-11-16 until the subscription is
renewed, so this skip is expected and not a failure of the run. Copilot stays in the script, the
config, the self-test fakes and `SKILL.md` as designed. It was not retried and the policy was not
worked around.

Whether each piece was accepted:
- The four `--disable` names are in `codex features list` and drew no complaint.
- `-c web_search="disabled"` was validated locally before (an invalid value fails to load the
  configuration).
- `project_doc_max_bytes=0` drew no complaint.
- The header confirmed `sandbox: read-only` and `approval: never`.
- Status `ok`.

Screening as `SKILL.md` step 3 asks: no `warning:` line; `findings-codex.md` and
`findings-claude.md` contain no absolute path outside the repository, no home path, no `.env`,
no `.git/config`, no token or address. The 15 findings are not merged into the first run's table
and the spec is unchanged.

## Review round 3

A third independent review raised 1 HIGH, 5 MEDIUM, 2 LOW-MEDIUM, 2 LOW findings and 4 false
claims in this report. I checked each finding against the code before fixing it and found none
wrong. Method as before:
- All new cases went in first. Against the unchanged script: `403 passed, 50 failed`, every
  failure on a round-3 item. Four of those were existing checks whose expected text changed
  (stderr class lines, env-file names moved to the terminal, the inverted inside-path case).
- The fix: `453 passed, 0 failed`.
- One mutation survived (R3-3b, below). The fail-closed case it pointed to went in test first
  (`453 passed, 2 failed`), then the fix.
- Final: `455 passed, 0 failed` under the default `/bin/bash` 3.2.57 and under
  `AI_REVIEW_TEST_BASH=/opt/homebrew/bin/bash` (bash 5.3.20).

| finding | test added | fix | mutation → self-test |
|---|---|---|---|
| R3-1 findings lost on a later auth or quota failure | `r3-1:` a retry half failing with quota, and with auth, after a first answer with F1 and F2 [blocker]: `skipped:quota`/`skipped:auth`, 2 findings, the blocker archived; a first call with the same findings, then a quota or auth error on stderr and exit 1: same | the post-call `skipped:*` early return is gone. Every status reached after a call archives and counts the findings it holds; only the skips decided before any call (not installed, unconfined, trusted folder) have none. The script comment and `SKILL.md` step 4 are now true | post-call skips return before archiving → 445 passed, 8 failed |
| R3-2 absolute repository paths archived verbatim; narrow outside check | `r3-2:` `$R/AGENTS.md` in an answer and `$R/STATUS.md` in its dropped preamble come out repository-relative in `findings-codex.md` and `.raw.md`, with no warning; the main checkout's root is rewritten too (run from a linked worktree); `file:///Users/…`, `/mnt/…`, `/srv/…`, `/nix/…`, `/workspace/…` and `C:\Users\…` warn. The round-1 case "an absolute path inside the repository is not flagged" is inverted into "is rewritten relative" | `relativize` rewrites every spelling of the roots (physical, as git printed it, without macOS's `/private` prefix, the main checkout's) in the trimmed answer before it is counted and archived, and in the raw file; then any absolute path left, also after `file://`, and any Windows drive path warns | (a) not relativized → 446 passed, 7 failed; (b) only the old top directories → 448 passed, 5 failed; (c) main checkout root not rewritten → 452 passed, 1 failed |
| R3-3 ignored names git quotes were named in summary.txt | `r3-3:` four ignored files (`müşteri-gizli.txt`, a tab, a `"`, a `\` in the name) rewritten during the run: none of their names (nor `m\303`) in `summary.txt`, `4 git-ignored path(s)` counted; with `git check-ignore` failing (a copy that exits 128) a changed ignored name stays off and is counted as ignored | `git -c core.quotePath=false check-ignore --stdin -z`, matched NUL-separated; fails closed: a path with a control character, a quote or a backslash counts as ignored, and so does every path when `check-ignore` exits with anything but 0 or 1 | (a) NUL paths fed without `-z` → 447 passed, 6 failed; (b) the character rule removed → 453 passed, 0 failed (**survived**, equivalent while `-z` matching is exact; kept as a second guard); (c) a failing `check-ignore` does not fail closed → 453 passed, 2 failed |
| R3-4 a quoted document line forged the verdict | `r3-4:` `**Verdict:** ready for release` after a finding without a fix line is `truncated`, 1 finding; `VERDICT: Ready …` is not a verdict; a correct `VERDICT: ready` after an incomplete last finding is `truncated`, 2 findings | the verdict keyword is case-sensitive: an upper-case `VERDICT:` (the round-2 decorations still tolerated) followed by exactly `ready`, `revise` or `reject` in lower case; `ok` also requires the last finding block to have its claim, evidence and fix lines | (a) case-insensitive again → 452 passed, 1 failed; (b) completeness not checked → 452 passed, 1 failed |
| R3-5 SIGKILL to the script's group leaves providers running | `r3-5:` the first output line names a pid file holding the script's pid; `kill -KILL -- -<group>` with a provider sleeping: the provider is dead within 5 s | (a) the script writes `$RUN/pid` and prints `ai_review: pid N (pid file …); stop it with kill -TERM "$(cat …)", never with SIGKILL` first. (b) Each timer forks a watchdog into a process group of its own, outside the script's group, which a group SIGKILL cannot reach. It polls every 0.5 s: when the script's pid is gone it kills the provider group (TERM, KILL after 2 s); when the provider group is gone it exits. (c) `SKILL.md`: stop only with `kill -TERM "$(cat <pid file>)"`, never with the task-stop tool; an archive directory without `summary.txt` is a leftover of a killed run, reported and removed only on the user's yes | (a) no watchdog → 452 passed, 1 failed; (b) no pid line → 452 passed, 1 failed |
| R3-6 config not checked against the repository | `r3-6:` a copy with `REVIEWS_REL` under an ignored directory exits 2; an `IGNORED_REVIEWS_REL` that git does not ignore exits 2 for a tracked document too; a missing orientation file only warns on the terminal (`orientation file not found: …`), exit 0 | three checks at start-up; "Porting" now covers the two repositories that ignore `docs/superpowers/` | (a) ignored `REVIEWS_REL` accepted → 452 passed, 1 failed; (b) tracked `IGNORED_REVIEWS_REL` accepted → 451 passed, 2 failed; (c) no orientation warning → 452 passed, 1 failed |
| R3-7 env files only at the root; names in the tracked summary; Claude and Copilot could read the root `.env` | `r3-7:` `sub/deep/.env` and `.envrc` give `skipped:unconfined`; `summary.txt` holds only `warning: env files: 1, names on the terminal`, no name; the name is on the terminal; Claude's real command line carries `--disallowedTools 'Read(**/.env),Read(**/.env.*),Read(**/.envrc)'` (checked through the shim). Round-2 env-file checks now look for the names on the terminal | candidates at any depth from `git ls-files -z` (tracked, untracked and ignored) plus the root itself (a FIFO is not listed by git), in the repository and the main checkout, including `.envrc`; never opened; the hint and warning give a count. **Claude** is denied reading env files by its permission rules. I checked by hand, outside the test suite, in a scratch repository with a dummy `.env`: with the rule, Claude answered `DENIED`; without it, it printed the dummy line. **Copilot** has no way to deny reads by path (`copilot help permissions` lists only shell, write, MCP and URL kinds), so it can read env files inside the repository; `SKILL.md` says so. **Codex** stays skipped (owner-approved rule unchanged) | (a) root only → 450 passed, 3 failed; (b) `.envrc` ignored → 452 passed, 1 failed; (c) names in the summary → 452 passed, 1 failed; (d) Claude not denied → 452 passed, 1 failed |
| R3-8 masked error lines still leaked addresses, org names, Windows and `/mnt` paths | `r3-8:` a stderr line with an e-mail address, an account, an org, `C:\Users\…` and `/mnt/data/…`: none of them in the summary, which says `error: claude: class=provider code=-` | `summary.txt` gets only the error class (`auth`, `quota`, `model`, `timeout`, `provider`) and an HTTP-style code found in the provider's last error lines; the masked lines go to the terminal only | masked lines archived again → 445 passed, 8 failed |
| R3-9 a set but empty test hook ran the real CLI | `r3-9:` `AI_REVIEW_BIN_CODEX=''` exits 2 | `${VAR+set}` with an empty value is a usage error, for all three hooks | empty hook accepted → 452 passed, 1 failed |
| R3-10 only the camel-case trust key | `r3-10:` a `"trusted_folders"` entry for the repository refuses Copilot (never called) | both spellings are matched. The 1.0.x trust store could not be read reliably. The decision is made in Copilot's native module (`folderTrustIsTrusted`, called from `cli-main.js` of the installed 1.0.92 package). The only trust tables I found, `project_host_trust` and `project_host_trusted_configs` in `~/.copilot/data.db` (read-only, schema and row counts only: both empty here), key on project ids, not folder paths. So a trust saved only in that store is not seen by the script | camel case only → 451 passed, 2 failed |

**Scope cut.** The master cut round 3's scope (no more mutations; R3-5 and R3-7 reduced to their
cheap parts; R3-10 deferred). That cut arrived after the whole round, mutations included, was
already done and reported. Nothing was removed. The R3-5 watchdog and the R3-7 Claude deny rules
stay as built and tested. The only open item of the cut is R3-10, the Copilot 1.0.x native trust
store, which is a known gap as stated in its row.

**The four false claims**, corrected where they stand:
- **R2-3, "git-ignored paths are only counted in `summary.txt`":** false for names git quotes. It is now true (R3-3), and the round-2 row says so.
- **R2-3, "at most 40 summary lines":** that was the test's bound on the whole summary. The cap in the code is `CHANGES_MAX=20` entries plus `... and N more`; the row now says both.
- **The script comment and `SKILL.md` step 4 on a non-ok provider's findings:** were false for `skipped:quota`/`skipped:auth`. True since R3-1.
- **The round-1 M6 row's "an absolute path inside the repository does not warn":** presented a leak as correct. The row now carries the correction (R3-2).

**Real run after round 3** (`--only codex,claude`; Copilot stays suspended):
`scripts/ai_review.sh docs/superpowers/specs/2026-10-24-dxf-writer-design.md --only codex,claude`.
Exit 0, 252 s. The date had turned, so it is the first archive of 2026-11-17 (no `-rN`). The
last fix (fail-closed on a failing `check-ignore`) came after this run and only affects how
changed ignored paths are classed. Output, verbatim (the pid line is the new first line):

```
ai_review: pid 89344 (pid file /private/var/folders/cy/hzy04mbx3lggs3z69x7_1c4m0000gn/T/ai_review.n0G8Cw/pid); stop it with kill -TERM "$(cat /private/var/folders/cy/hzy04mbx3lggs3z69x7_1c4m0000gn/T/ai_review.n0G8Cw/pid)", never with SIGKILL
document: docs/superpowers/specs/2026-10-24-dxf-writer-design.md
document-blob: d2eca50b22c867dfa3284cb64f22dd64487b2463
commit: 892aad2d72e72ced720642f6ce7b26fa3c99b7c5
date: 2026-11-17
archive: docs/superpowers/reviews/2026-11-17-specs-2026-10-24-dxf-writer-design
models: codex=gpt-6.1-sol claude=fable
timeout-per-call: 600s
codex    ok                     10 findings  VERDICT: revise — Tree restoration, exploded instances, omission, manifests, and attribute ordering need explicit decisions before implementation.
claude   ok                     9 findings  VERDICT: revise — two unresolved conflicts with the architecture spec and the tree record; the rest are small decisions.
findings: 19 total
```
Claude ran with the new `--disallowedTools` env-file rules and accepted them. Screening found no
outside path, home path, `.env`, `.git/config`, token or address in either findings file. The
run directory was removed (both providers ok).

## Porting

To use this in another repository:

- **Copy unchanged:** `scripts/ai_review.sh`, `scripts/ai_review/prompt.md`,
  `scripts/ai_review/selftest.sh`, `.claude/skills/spec-review/SKILL.md`.
- **Edit only** the block between `# >>> ai_review config` and `# <<< ai_review config` in
  `scripts/ai_review.sh`:
  - `AI_REVIEW_PROJECT`: one line naming the project;
  - `REVIEWS_REL`: the tracked archive directory;
  - `IGNORED_REVIEWS_REL`: a git-ignored archive directory for git-ignored documents, or empty
    to refuse them. It must be ignored by the repository's `.gitignore`, and `REVIEWS_REL` must
    not be: the script refuses to start otherwise (R3-6);
  - `PROTECTED_BRANCHES`;
  - `ORIENTATION`: `path:description|path:description|…`, in reading order;
  - `DOC_LAYOUT`: one sentence on where specs, plans and notes live;
  - `SLUG_STRIP`: path prefixes dropped from the archive slug.
- **Then:** run `scripts/ai_review/selftest.sh`, and once more with
  `AI_REVIEW_TEST_BASH=<a current bash>`. It builds its fixture from the block, so it needs no
  other change. Track the reviews directory.
- **`AGENTS.md`**, the per-repository paragraph (here under "Outside review of a document"):

  > `/spec-review <doc>` (`.claude/skills/spec-review/SKILL.md`) runs an independent, read-only
  > review of a spec, plan or doc page by up to three CLIs (Codex, Copilot, Claude) through
  > `scripts/ai_review.sh`, then merges, re-verifies and folds the findings back into the
  > document. Each run is archived, never overwritten, in `<REVIEWS_REL>/<date>-<slug>/`;
  > git-ignored documents are <refused | archived in `<IGNORED_REVIEWS_REL>/` and never
  > committed>. The repository-specific settings are the config block at the top of the script.
  > The script's self-test needs no network and no real CLI: `scripts/ai_review/selftest.sh`.

- **jet-office and jet-print** ignore `docs/superpowers/` (their `.gitignore`), where their specs
  and plans live. Their block should read `REVIEWS_REL="docs/reviews"` (tracked) and
  `IGNORED_REVIEWS_REL="docs/superpowers/reviews"` (ignored). Their specs are then reviewed into
  the ignored directory and never committed; a tracked document's review goes to `docs/reviews/`.
  A copied block with `REVIEWS_REL="docs/superpowers/reviews"` stops with exit 2 there, rather than
  filing "tracked" archives in an ignored directory.
- **Orientation files** are checked at start-up; a missing one only warns on the terminal.
- **`SKILL.md` names a few things by this repository's example:** the `main` branch and the
  `git worktree add` line in step 1. Each sits next to "the config block" or "here" and reads
  correctly elsewhere, but a repository with a different branching rule may want to change that
  one example line.

## Checks, real last lines

- `scripts/ai_review/selftest.sh` (default: the script runs under macOS `/bin/bash` 3.2.57) →
  ```
  PASS r3-3: ... and is counted as ignored

  ai_review selftest: 455 passed, 0 failed
  ```
  exit 0.
- `AI_REVIEW_TEST_BASH=/opt/homebrew/bin/bash scripts/ai_review/selftest.sh` (bash 5.3.20) →
  the same two last lines, `ai_review selftest: 455 passed, 0 failed`, exit 0.
- `cd tool/ci && dart test` (after round 3) →
  ```
  00:54 +121: test/api_boundary_test.dart: AB6 the real jet_cad_2d_plan barrel is clean
  01:06 +122: All tests passed!
  ```
  No failures, so nothing to compare with `tool/ci/standing_failures.txt` (package suites only).
- `shellcheck -S warning scripts/ai_review.sh scripts/ai_review/selftest.sh` → no output, exit 0.
- `/bin/bash -n` on both scripts → ok (also a self-test case).
- `dart format`: not run; no Dart file changed.
- **Package gates not run** (`dart test`/`flutter test`, analyze, format in `packages/jet_cad_2d`,
  `jet_cad_2d_flutter`, `jet_cad_2d_gpu`): this work touches no package.
- Temp directories: I removed the run directories my own runs left (the fourth run's, kept
  because a provider was not ok, after reading its stderr; and one empty `ai_review_selftest.*`
  left by a mutation run I stopped). None of mine is left in `$TMPDIR`. `$TMPDIR/ai_review/` is
  not mine and was left alone.

## `git status --short`

```
 M AGENTS.md
?? .claude/
?? docs/superpowers/notes/2026-11-16-spec-review-skill-report.md
?? docs/superpowers/reviews/
?? scripts/
```
(`.claude/` holds only `skills/spec-review/SKILL.md` as untracked; `settings.local.json` is
ignored. `docs/superpowers/reviews/` holds six archives of the DXF writer spec: five of
2026-11-16, `-r2` to `-r5` beside the untouched first, and one of 2026-11-17.)

## Points for the owner, what I could not do

- **New status `skipped:unconfined` and `--allow-unconfined`: approved by the owner on
  2026-11-16**, as built and as `SKILL.md` describes them. A provider whose file reads are not
  confined to the repository (Codex) is skipped while an env file exists in the root or the
  main checkout. `--allow-unconfined` runs it anyway and is passed only when the user asks for
  it after seeing the env file names, never by the skill on its own.
- **Proxies are no longer passed** to any provider (cross-review A7). Behind a proxy every
  provider will fail to connect until `HTTPS_PROXY` (and friends) go back on the allow-list.
- **Copilot cannot be denied reading env files** inside the repository (no path-scoped deny in
  its CLI), and a folder trust saved only in its 1.0.x native store is not seen by the script
  (R3-10). Both are moot while the check is suspended, and both are stated in `SKILL.md` or here.
- **Copilot is unverified end to end.** The account's Copilot CLI access is denied by policy
  (github.com/settings/copilot); the owner suspended the Copilot check until the subscription is
  renewed (2026-11-16). So `--available-tools view,grep,glob` (tool names read from
  the Copilot package, not from `--help`), `--sync-session=off`, `--disallow-temp-dir`, signing
  in under the scrubbed environment and whether it still writes local session files are checked
  only by `--help` and the shim.
- **Codex** works with the line above. Untested: whether `--ignore-user-config` also skips a
  project-level `.codex/config.toml` (none exists here). Codex reads are not confined; the
  preflight, the outside-path warning and the skill's screening stand in.
- **The refs listing can warn about other sessions' commits** in a checkout where other
  worktrees commit during a run; the warning says "by a reviewer or anything else".
- **Follow-ups, not built (out of scope):** a cloud-session path that uses GitHub Copilot's PR
  review; a CI check that fails a spec PR without a review archive.
