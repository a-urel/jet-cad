// A kit's words with parameters (spec 3a C1.6): a `text:<kit>.<id>` word is
// a template whose `{name}` placeholders are filled when it is read, so a
// tool's notice (C1.2) is a word id and its arguments, put into words in
// the language of the moment.
//
// Pure Dart: no Flutter, no dart:io.
import 'package:meta/meta.dart';

/// A placeholder: `{`, a letter, then letters and digits, `}`.
final RegExp _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}');

/// A word id and its arguments, put into words when read
/// (`KitWords.text`). Equal by its id and its arguments' values, whatever
/// their order.
@immutable
final class KitText {
  const KitText(this.id, [this.args = const {}]);

  /// `text:<kit>.<id>`.
  final String id;

  /// The values of the word's placeholders, by name.
  final Map<String, Object> args;

  @override
  bool operator ==(Object other) {
    if (other is! KitText || other.id != id) return false;
    final theirs = other.args;
    if (theirs.length != args.length) return false;
    for (final MapEntry(:key, :value) in args.entries) {
      if (!theirs.containsKey(key) || theirs[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      id,
      Object.hashAllUnordered(
          [for (final e in args.entries) Object.hash(e.key, e.value)]));

  @override
  String toString() => 'KitText($id, $args)';
}

/// [template] with each placeholder `{name}` that [args] has replaced by
/// `'${args[name]}'`; a placeholder without an argument is left as
/// written, an argument the template does not name is ignored.
String fillText(String template, Map<String, Object> args) =>
    template.replaceAllMapped(_placeholder, (m) {
      final value = args[m[1]!];
      return value == null ? m[0]! : '$value';
    });

/// The names of [template]'s placeholders.
Set<String> placeholdersOf(String template) =>
    {for (final m in _placeholder.allMatches(template)) m[1]!};
