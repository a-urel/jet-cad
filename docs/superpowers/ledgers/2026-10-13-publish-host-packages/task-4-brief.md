### Task 4: CI `publishable` over three packages (D5)

**Files:**
- Modify: `.github/workflows/ci.yml` (the `publishable` job)

- [ ] **Step 1: Rewrite the job as a matrix**

Replace the `publishable` job with:

```yaml
  publishable:
    name: ${{ matrix.package }}, publishable to pub.dev
    runs-on: ubuntu-latest
    timeout-minutes: 15
    strategy:
      fail-fast: false
      matrix:
        package:
          - packages/jet_cad_2d
          - packages/jet_cad_2d_flutter
          - packages/jet_cad_floor_plan
    steps:
      - uses: actions/checkout@v5
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true
      - name: Resolve the workspace
        run: flutter pub get
      # Decision 2 of the publishing spec: each published package carries
      # the root's Apache 2.0 licence, byte for byte.
      - name: The licence is the root's
        run: cmp LICENSE ${{ matrix.package }}/LICENSE
      # A dry run uploads nothing; it exits 65 on any warning (a version
      # bump without its CHANGELOG entry, a modified checked-in file), not
      # only on an error. A dependent's dry run does not need its
      # dependency on pub.dev (spec F-2).
      - name: Publish dry run
        working-directory: ${{ matrix.package }}
        run: dart pub publish --dry-run
```

- [ ] **Step 2: Check the YAML and each step locally**

Run: `ruby -ryaml -e 'y = YAML.load_file(".github/workflows/ci.yml"); p y["jobs"]["publishable"]["strategy"]["matrix"]["package"]'` — Expected: the three paths.

For each of the three packages, run `cmp LICENSE <package>/LICENSE` and `dart pub -C <package> publish --dry-run` on the committed tree — Expected: no output from `cmp`; "Package has 0 warnings.", exit 0.

Mutant **M-CI1**: append a byte to `packages/jet_cad_2d_flutter/LICENSE` (copy first); `cmp` must exit 1 and the dry run must report the modified file with exit 65. Restore, `cmp`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: dry-run and licence checks for the three published packages (D5)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

