# Task 9 report
Status: DONE. Commit: 4f96b02a "docs: the host guide — any object, sections, inspectors, phones and tablets".
Files: docs/host-guide.md (6.10, 6.11, 6.12, 14, ToC), tool/ci/host_probe/lib/main.dart (8 new declarations; 7 new guide dart blocks... 34 blocks total all in probe). CHANGELOGs already complete; untouched.
Gates (real): check_guide: "all 34 code blocks are in the host probe"; host_probe.sh: analyze "No issues found", web build "Built build/web"; tool/ci dart test: "+114: All tests passed!"; probe format exit 0.
Mutation: guide hint 'Record' -> 'Pick' in the recordPicker block without the probe: check_guide exit 1 ("not in the host probe: dart: /// A combo over the POS's records..."); reverted, git diff --quiet ok.
Concerns: the guide's header still says 0.8.0 (not bumped). The wall-chain note is worded neutrally since the "how to finish a chain on a phone" question is open for the human.
