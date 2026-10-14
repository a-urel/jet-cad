// Kit versions in a plan's manifest (spec 2a P4 "Versions", contract R6):
// semantic versions 2.0.0, compared by precedence. A version that does not
// parse is not compared, and never refuses a load.
import 'dart:math' as math;

import 'package:meta/meta.dart';

final RegExp _semver = RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)'
    r'(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?'
    r'(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$');

final RegExp _numeric = RegExp(r'^\d+$');

@immutable
final class SemVer implements Comparable<SemVer> {
  const SemVer._(this.major, this.minor, this.patch, this.pre);

  final int major, minor, patch;

  /// The pre-release identifiers; empty for a release. Build metadata is
  /// not kept: it takes no part in precedence.
  final List<String> pre;

  /// [text] as a semantic version, or null when it is not one (or a part
  /// overflows an int).
  static SemVer? tryParse(String text) {
    final m = _semver.firstMatch(text);
    if (m == null) return null;
    final major = int.tryParse(m[1]!);
    final minor = int.tryParse(m[2]!);
    final patch = int.tryParse(m[3]!);
    if (major == null || minor == null || patch == null) return null;
    final pre = m[4];
    return SemVer._(major, minor, patch,
        pre == null ? const [] : List.unmodifiable(pre.split('.')));
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (pre.isEmpty || other.pre.isEmpty) {
      // A release ranks above its pre-releases.
      return (other.pre.isEmpty ? 0 : 1) - (pre.isEmpty ? 0 : 1);
    }
    for (var i = 0; i < math.min(pre.length, other.pre.length); i++) {
      final c = _compareIdentifier(pre[i], other.pre[i]);
      if (c != 0) return c;
    }
    return pre.length.compareTo(other.pre.length);
  }

  /// Numeric identifiers numerically (no leading zero: the longer is the
  /// larger, so no int can overflow), below alphanumeric ones, which
  /// compare in ASCII order.
  static int _compareIdentifier(String a, String b) {
    final an = _numeric.hasMatch(a), bn = _numeric.hasMatch(b);
    if (an && bn) {
      return a.length != b.length
          ? a.length.compareTo(b.length)
          : a.compareTo(b);
    }
    if (an != bn) return an ? -1 : 1;
    return a.compareTo(b);
  }

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, Object.hashAll(pre));
}

/// Whether [plan] is newer than [loaded] by precedence; null when either
/// does not parse.
bool? isNewerVersion(String plan, String loaded) {
  final a = SemVer.tryParse(plan), b = SemVer.tryParse(loaded);
  if (a == null || b == null) return null;
  return a.compareTo(b) > 0;
}
