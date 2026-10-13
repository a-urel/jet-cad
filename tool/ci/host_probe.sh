#!/usr/bin/env bash
# Spec 14d P6: builds the host probe against the repository at a commit,
# from outside the workspace -- as a POS would depend on it. The probe
# resolves the planner from pub.dev, and its dependency overrides take the
# four repository packages from git at the commit; the restaurant symbols
# are copied into the probe, as a host does (publishing spec D6, D9).
#
#   tool/ci/host_probe.sh <git url> <commit sha>
#
# CI passes file://$GITHUB_WORKSPACE and `git rev-parse HEAD`, so no token
# is needed for a private repository. Writes only inside the probe. The
# sha must be the full one: check_host_lock.dart --ref compares it exactly
# with each package's resolved-ref in the lock.
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
rm -rf "$probe/build" "$probe/.dart_tool" "$probe/pubspec.lock" \
  "$probe/assets/restaurant.jetlib" "$probe/lib/restaurant_names.dart"
sed -e "s#@URL@#$url#g" -e "s#@REF@#$ref#g" \
  "$probe/pubspec.yaml.in" > "$probe/pubspec.yaml"
cd "$probe"
flutter pub get
dart run "$ci/check_host_lock.dart" "$probe/pubspec.lock" --ref "$ref"
# Publishing spec D9: the probe carries the restaurant library as a host
# does, copied verbatim from the package pub resolved at this commit (the
# names file imports the planner's public symbol_sources.dart).
symbols=$(dart run "$ci/package_root.dart" "$probe" jet_cad_restaurant_symbols)
mkdir -p "$probe/assets"
cp "$symbols/assets/restaurant.jetlib" "$probe/assets/restaurant.jetlib"
cp "$symbols/lib/src/names.dart" "$probe/lib/restaurant_names.dart"
flutter analyze
flutter build web
fail=0
# The lock check above is the main guard; these three catch what reached
# the build anyway. hooks_runner is Flutter's own folder name, so a rename
# would let its check pass silently.
if [ -e .dart_tool/hooks_runner ]; then
  echo "host probe: a build hook ran (.dart_tool/hooks_runner exists)" >&2
  fail=1
fi
if [ -e build/web/assets/packages/flutter_scene ]; then
  echo "host probe: the web build ships flutter_scene's assets" >&2
  fail=1
fi
# Inside an `if`, `set -e` does not apply: a missing main.dart.js would
# make grep exit 2 and read as "not found" (Task 2 review R-2).
if [ ! -f build/web/main.dart.js ]; then
  echo "host probe: the web build has no main.dart.js" >&2
  fail=1
elif grep -q 'cad.shaderbundle' build/web/main.dart.js; then
  echo "host probe: main.dart.js loads cad.shaderbundle" >&2
  fail=1
fi
if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "host probe: no GPU renderer, no build hook; build/web is" \
  "$(du -sh build/web | cut -f1)"
