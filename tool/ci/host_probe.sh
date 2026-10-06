#!/usr/bin/env bash
# Spec 14d P6: builds the host probe against the repository at a commit,
# by git, from outside the workspace -- as a POS would depend on it.
#
#   tool/ci/host_probe.sh <git url> <commit sha>
#
# CI passes file://$GITHUB_WORKSPACE and `git rev-parse HEAD`, so no token
# is needed for a private repository. Writes only inside the probe.
set -euo pipefail
url=$1
ref=$2
probe=$(cd "$(dirname "$0")/host_probe" && pwd)
sed -e "s#@URL@#$url#g" -e "s#@REF@#$ref#g" \
  "$probe/pubspec.yaml.in" > "$probe/pubspec.yaml"
cd "$probe"
flutter pub get
flutter analyze
flutter build web
