// Reading a component's JSON (spec K2): a missing or mistyped field is a
// FormatException naming it, never a TypeError from an `as` cast.
//
// Pure Dart: no Flutter, no dart:io. Not exported.

/// [json]'s value at [key], which must be present and a [T] (a nullable [T]
/// admits null). [type] names the component in the message.
T field<T>(Map<String, Object?> json, String key, String type) {
  if (!json.containsKey(key)) {
    throw FormatException('$type: missing "$key"');
  }
  final value = json[key];
  if (value is! T) {
    throw FormatException('$type: "$key" is not a $T: $value');
  }
  return value;
}

/// [json]'s value at [key], or [absent] when [json] has no [key]: a field
/// added after a format was first written, so that what was saved before it
/// still reads (contract R2). A present value must be a [T].
T optionalField<T>(
        Map<String, Object?> json, String key, String type, T absent) =>
    json.containsKey(key) ? field<T>(json, key, type) : absent;

/// [json]'s list of strings at [key].
List<String> stringList(Map<String, Object?> json, String key, String type) {
  final list = field<List<Object?>>(json, key, type);
  return [
    for (final item in list)
      item is String
          ? item
          : throw FormatException('$type: "$key" holds $item, not a string'),
  ];
}
