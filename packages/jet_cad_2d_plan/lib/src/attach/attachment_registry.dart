// Spec P3 "Attachment" (Task 14): the registry over the kits' providers,
// one per document (spec P1 "Lifetimes": a kit's factories run once per
// document). plan.symbol and plan.select's move resolver use it, and
// nothing else.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../kits/guard.dart' show guardAttachment;

/// The providers of one document, by kind, in the order they were added
/// (kit load order).
///
/// [attach] asks every provider of each kind in its `kinds` and returns
/// the answer whose marker is nearest the query's pointer (the earlier on
/// a tie). A query's `keep` reaches only the provider that made it. A
/// provider that throws is taken as no attachment and reported; so is a
/// factory that throws, which adds no provider.
final class PlanAttachmentRegistry implements AttachmentRegistry {
  PlanAttachmentRegistry(
      {required void Function(KitDiagnostic diagnostic) report})
      : _report = report;

  final void Function(KitDiagnostic diagnostic) _report;
  final Map<String, List<_Provider>> _byKind = <String, List<_Provider>>{};
  final Expando<_Provider> _origin = Expando<_Provider>('attachment origin');

  /// Runs [factory] over [services] and adds its provider.
  void add(String kitId, AttachmentProvider Function(PlanServices) factory,
      PlanServices services) {
    final AttachmentProvider provider;
    final String kind;
    try {
      provider = factory(services);
      kind = provider.kind;
    } catch (e) {
      _report(KitDiagnostic(
          kitId: kitId,
          subject: 'attachments',
          code: KitDiagnosticCode.hookFailed,
          message: 'an attachment provider factory of "$kitId" threw: $e',
          error: e));
      return;
    }
    (_byKind[kind] ??= <_Provider>[]).add(_Provider(kitId, provider));
  }

  @override
  Set<String> get kinds => Set.unmodifiable(_byKind.keys);

  @override
  Attachment? attach(List<String> kinds, AttachmentQuery query) {
    final keep = query.keep;
    final keeper = keep == null ? null : _origin[keep];
    AttachmentQuery? bare;
    Attachment? best;
    var bestDistance = double.infinity;
    for (final kind in kinds) {
      final providers = _byKind[kind];
      if (providers == null) continue;
      for (final p in providers) {
        final q = keep == null || identical(p, keeper)
            ? query
            : (bare ??= _withoutKeep(query));
        final a = _ask(p, q);
        if (a == null) continue;
        _origin[a] = p;
        final d = a.marker.distanceToSquared(query.pointer);
        if (d < bestDistance) {
          best = a;
          bestDistance = d;
        }
      }
    }
    return best;
  }

  /// [p]'s answer through Task 11's guard: a throw is no attachment and
  /// one hookFailed (subject: the provider's kind).
  Attachment? _ask(_Provider p, AttachmentQuery q) =>
      guardAttachment(p.kitId, p.provider, q, _report);

  static AttachmentQuery _withoutKeep(AttachmentQuery q) => AttachmentQuery(
        footprint: q.footprint,
        current: q.current,
        pointer: q.pointer,
        capture: q.capture,
        edgeCapture: q.edgeCapture,
        mirrored: q.mirrored,
        mayRotate: q.mayRotate,
        exclude: q.exclude,
      );

  /// Disposes every provider that is [Disposable] and empties the
  /// registry (the document is going). A provider's dispose that throws is
  /// reported (subject: its kind), and the others are still disposed.
  void dispose() {
    for (final entry in _byKind.entries) {
      for (final p in entry.value) {
        // Disposable is no AttachmentProvider: a pattern, not a promotion.
        if (p.provider case final Disposable disposable) {
          try {
            disposable.dispose();
          } catch (e) {
            _report(KitDiagnostic(
                kitId: p.kitId,
                subject: entry.key,
                code: KitDiagnosticCode.hookFailed,
                message: 'dispose: $e',
                error: e));
          }
        }
      }
    }
    _byKind.clear();
  }
}

final class _Provider {
  const _Provider(this.kitId, this.provider);

  final String kitId;
  final AttachmentProvider provider;
}
