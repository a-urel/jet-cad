#!/usr/bin/env bash
# Host embedding API spec, invariant 1 (P-1): a released host still
# compiles against the commit under test. Puts the host probe's
# lib/main.dart as release <tag> had it into the probe that
# tool/ci/host_probe.sh resolved at this commit, analyses it, and puts this
# commit's main.dart back, whatever the verdict.
#
#   tool/ci/old_host_probe.sh <tag>
#
# Run after tool/ci/host_probe.sh, which leaves the probe's pubspec.yaml
# and lock at the commit under test. The tag must be in the clone: CI's
# checkout fetches the whole history and its tags.
set -euo pipefail
tag=$1
ci=$(cd "$(dirname "$0")" && pwd)
probe=$ci/host_probe
main=$probe/lib/main.dart
if [ ! -f "$probe/pubspec.lock" ]; then
  echo "old host probe: no resolved probe; run tool/ci/host_probe.sh first" >&2
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
