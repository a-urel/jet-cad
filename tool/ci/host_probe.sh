#!/usr/bin/env bash
# Spec 14d P6: builds the host probe against the repository at a commit,
# by git, from outside the workspace -- as a POS would depend on it.
#
#   tool/ci/host_probe.sh <git url> <commit sha>
#
# CI passes file://$GITHUB_WORKSPACE and `git rev-parse HEAD`, so no token
# is needed for a private repository. Writes only inside the probe.
#
# GPU split spec S8: the host's graph holds no GPU renderer and runs no
# build hook. The probe starts clean, because stale output survives a
# build; its lock is checked after `pub get`, and its web build after the
# build.
set -euo pipefail
url=$1
ref=$2
ci=$(cd "$(dirname "$0")" && pwd)
probe=$ci/host_probe
rm -rf "$probe/build" "$probe/.dart_tool" "$probe/pubspec.lock"
sed -e "s#@URL@#$url#g" -e "s#@REF@#$ref#g" \
  "$probe/pubspec.yaml.in" > "$probe/pubspec.yaml"
cd "$probe"
flutter pub get
dart run "$ci/check_host_lock.dart" "$probe/pubspec.lock"
flutter analyze
flutter build web
fail=0
if [ -e .dart_tool/hooks_runner ]; then
  echo "host probe: a build hook ran (.dart_tool/hooks_runner exists)" >&2
  fail=1
fi
if [ -e build/web/assets/packages/flutter_scene ]; then
  echo "host probe: the web build ships flutter_scene's assets" >&2
  fail=1
fi
if grep -q 'cad.shaderbundle' build/web/main.dart.js; then
  echo "host probe: main.dart.js loads cad.shaderbundle" >&2
  fail=1
fi
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "host probe: no GPU renderer, no build hook; build/web is" \
  "$(du -sh build/web | cut -f1)"
