import '../core/handle.dart';
import 'resolved_style.dart';
import 'style_context.dart';
import 'style_resolver.dart';

/// A [StyleResolver] that remembers what it was told.
///
/// **A rig instrument, not shipping infrastructure.** The cache is valid only
/// while no layer record and no instance colour changes: nothing in today's
/// command set can change either, which is the same standing `FilterEvaluator`
/// documents for its own caches. [clear] is the only escape, and a caller that
/// knows better must call it. Plan 3b either gives this an invalidation hook or
/// does not ship it.
///
/// It exists so the memo's value is a measured number rather than an
/// assumption. [DocumentStyleResolver] is unmemoised on purpose: measure the
/// unmemoised cost first, and do not take on invalidation debt before anything
/// needs it.
class MemoisedStyleResolver implements StyleResolver {
  MemoisedStyleResolver(this.inner);

  final StyleResolver inner;

  /// Keyed by value, not by identity.
  ///
  /// Two containers can hand down equal contexts, and an identity key would
  /// miss on every one of them while staying correct — a memo that bought
  /// nothing, which is a measurement that reads as a conclusion. Dart records
  /// give the structural equality [StyleContext] itself does not have.
  ///
  /// Every field of the context is in the key, including ones today's
  /// [DocumentStyleResolver.styleFor] does not read. Keying on the fields it
  /// happens to read couples this to a private detail: the day resolution
  /// starts reading one more, the memo would answer stale rather than miss.
  final Map<(int, int, Handle, double, int, int, Handle), ResolvedStyle>
      _styles = {};

  final Map<(Handle, int, Handle, double, int, int, Handle), StyleContext>
      _contexts = {};

  int get entryCount => _styles.length + _contexts.length;

  void clear() {
    _styles.clear();
    _contexts.clear();
  }

  @override
  ResolvedStyle styleFor(int slot, StyleContext ctx) => _styles.putIfAbsent(
        (
          slot,
          ctx.color,
          ctx.linetype,
          ctx.linetypeScale,
          ctx.lineweight,
          ctx.transparency,
          ctx.layer
        ),
        () => inner.styleFor(slot, ctx),
      );

  @override
  StyleContext contextFor(Handle instance, StyleContext inherited) =>
      _contexts.putIfAbsent(
        (
          instance,
          inherited.color,
          inherited.linetype,
          inherited.linetypeScale,
          inherited.lineweight,
          inherited.transparency,
          inherited.layer
        ),
        () => inner.contextFor(instance, inherited),
      );
}
