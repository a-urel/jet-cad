#!/usr/bin/env bash
# Host embedding API spec, invariant 1 (P-1): a released host still
# compiles against the commit under test. Puts the host probe's
# lib/main.dart as release <tag> had it into the old probe that
# tool/ci/old_host_probe_resolve.sh resolved at this commit (the old probe
# depends on jet_cad_floor_plan; sub-project 4b removes it with this
# script), analyses it, and puts this commit's old main.dart back, whatever
# the verdict. The tag's file is its tool/ci/host_probe/lib/main.dart: the
# probe had that path before 4a moved it.
#
#   tool/ci/old_host_probe.sh <tag>
#
# Run after tool/ci/old_host_probe_resolve.sh, which leaves the old probe's
# pubspec.yaml and lock at the commit under test. The tag must be in the
# clone: CI's checkout fetches the whole history and its tags.
set -euo pipefail
tag=$1
ci=$(cd "$(dirname "$0")" && pwd)
probe=$ci/old_host_probe
main=$probe/lib/main.dart
if [ ! -f "$probe/pubspec.lock" ]; then
  echo "old host probe: no resolved probe; run tool/ci/old_host_probe_resolve.sh first" >&2
  exit 2
fi
kept=$(mktemp)
cp "$main" "$kept"
trap 'cp "$kept" "$main"; rm -f "$kept"' EXIT
git -C "$ci" show "$tag:tool/ci/host_probe/lib/main.dart" > "$main"
cd "$probe"
flutter analyze
echo "old host probe: $tag's main.dart analyses against" \
  "$(git -C "$ci" rev-parse HEAD)"
