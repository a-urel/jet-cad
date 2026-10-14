// The plan manifest (spec 2a P4, umbrella A8): on a plan's root, the
// format and `{kit id: version}` for each kit the plan uses. Read as it
// was saved, written at each save, checked against the loaded kits.
import 'dart:collection';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart';

import '../kits/kit_set.dart';
import 'semver.dart';

/// The plan format this library writes and reads.
const int kPlanFormat = 1;

/// A plan's manifest: its format and its kits' versions.
@immutable
final class PlanManifest {
  const PlanManifest({this.format = kPlanFormat, this.kits = const {}});

  final int format;

  /// Kit id → the version that last saved the plan.
  final Map<String, String> kits;

  @override
  bool operator ==(Object other) {
    if (other is! PlanManifest ||
        other.format != format ||
        other.kits.length != kits.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in kits.entries) {
      if (other.kits[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      format,
      Object.hashAllUnordered(
          [for (final e in kits.entries) Object.hash(e.key, e.value)]));

  @override
  String toString() => 'PlanManifest($format, $kits)';
}

/// [d]'s root manifest as read, or null when it has none (a new plan).
PlanManifest? manifestOf(DraftDocument d) {
  if (!d.components.isRegistered<ManifestComponent>()) return null;
  final m = d.components.get<ManifestComponent>(d.rootHandle);
  return m == null ? null : PlanManifest(format: m.format, kits: m.kits);
}

/// The kits [d] uses, sorted (spec P4): see [usedKitsIn].
Set<String> usedKits(DraftDocument d) => usedKitsIn(d.components.toJson());

/// The kits an encoded `components` map uses: the `<kit>` of each type id
/// `<kit>.<...>` whose `<kit>` is a kit id other than a reserved one
/// (`jetcad`, `plan`: [reservedKitIds]), and the kit of each
/// `jetcad.symbol` payload's `key`. Raw components count by their type id.
Set<String> usedKitsIn(Map<String, Object?> components) {
  final used = SplayTreeSet<String>();
  void add(String id) {
    final dot = id.indexOf('.');
    if (dot <= 0) return;
    final kit = id.substring(0, dot);
    if (!reservedKitIds.contains(kit) && isKitId(kit)) used.add(kit);
  }

  for (final MapEntry(key: typeId, value: byHandle) in components.entries) {
    add(typeId);
    if (typeId == SymbolComponent.componentTypeId &&
        byHandle is Map<String, Object?>) {
      for (final payload in byHandle.values) {
        if (payload is Map<String, Object?> && payload['key'] is String) {
          add(payload['key']! as String);
        }
      }
    }
  }
  return used;
}

/// The manifest a save writes (spec P4): for each kit used or read, a
/// loaded kit's version when it is used, and a kit that is not loaded
/// with its entry as read.
PlanManifest manifestToWrite(
    PlanManifest? read, Set<String> used, KitSet loaded) {
  final kits = SplayTreeMap<String, String>();
  for (final id in {...used, ...?read?.kits.keys}) {
    final kit = loaded.kitOf(id);
    if (kit != null) {
      if (used.contains(id)) kits[id] = kit.version;
    } else if (read?.kits[id] case final version?) {
      kits[id] = version;
    }
  }
  return PlanManifest(kits: Map.unmodifiable(kits));
}

/// What a load finds (spec P4): the kits the plan names or uses that are
/// not loaded, and one diagnostic for each such kit (`kitMissing`) and for
/// each loaded kit whose saved version is newer (`kitNewer`).
@immutable
final class ManifestCheck {
  const ManifestCheck(this.missing, this.diagnostics);

  final Set<String> missing;
  final List<KitDiagnostic> diagnostics;
}

/// [manifest] and the [used] kits checked against the [loaded] ones (spec
/// P4), kit by kit in id order: see [ManifestCheck]. A version that does
/// not parse is not compared.
ManifestCheck checkManifest(
    PlanManifest manifest, Set<String> used, KitSet loaded) {
  final missing = SplayTreeSet<String>();
  final diagnostics = <KitDiagnostic>[];
  for (final id in SplayTreeSet<String>.of({...manifest.kits.keys, ...used})) {
    final saved = manifest.kits[id];
    final kit = loaded.kitOf(id);
    if (kit == null) {
      missing.add(id);
      diagnostics.add(KitDiagnostic(
          kitId: id,
          code: KitDiagnosticCode.kitMissing,
          message: 'the plan uses the kit "$id"'
              '${saved == null ? '' : ' $saved'}, which is not loaded'));
      continue;
    }
    if (saved != null && isNewerVersion(saved, kit.version) == true) {
      diagnostics.add(KitDiagnostic(
          kitId: id,
          code: KitDiagnosticCode.kitNewer,
          message: 'the plan was saved by "$id" $saved, newer than the '
              'loaded ${kit.version}'));
    }
  }
  return ManifestCheck(
      Set.unmodifiable(missing), List.unmodifiable(diagnostics));
}
