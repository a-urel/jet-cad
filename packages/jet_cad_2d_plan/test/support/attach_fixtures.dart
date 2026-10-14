// Attachment providers for tests (Task 14): scripted answers, recorded
// queries, a provider that throws and one that is Disposable. The
// geometry of a real provider (a wall face) is a kit's (sub-project 3);
// here only the plan library's plumbing is under test.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
// Disposable is the kit's (jet_cad_2d_kit, Task 4; controller ruling
// R-d), imported above.
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// An attachment: [transform], its [marker], and a [token].
Attachment attachment(Transform2 transform, Vector2 marker, Object token) =>
    Attachment(transform: transform, marker: marker, token: token);

/// Answers with [answer] and records every query.
final class RecordingProvider implements AttachmentProvider {
  RecordingProvider(this.kind, this.answer);

  @override
  final String kind;

  Attachment? Function(AttachmentQuery query) answer;
  final List<AttachmentQuery> queries = [];

  @override
  Attachment? attach(AttachmentQuery query) {
    queries.add(query);
    return answer(query);
  }
}

/// Throws on every query.
final class ThrowingProvider implements AttachmentProvider {
  ThrowingProvider(this.kind);

  @override
  final String kind;
  int calls = 0;

  @override
  Attachment? attach(AttachmentQuery query) {
    calls++;
    throw StateError('the $kind provider broke');
  }
}

/// A provider with a dispose (the kit's Disposable, Task 4).
final class DisposableProvider extends RecordingProvider implements Disposable {
  DisposableProvider(super.kind, super.answer);

  int disposals = 0;

  @override
  void dispose() => disposals++;
}

/// A query near the fixtures' world (off the origin, a turned current).
AttachmentQuery queryAt(Vector2 pointer,
        {Attachment? keep,
        bool mayRotate = true,
        bool mirrored = false,
        Set<Handle> exclude = const {}}) =>
    AttachmentQuery(
      footprint: const Aabb2.raw(150, 210, 1750, 960),
      current: Transform2.translation(pointer.x, pointer.y)
          .multiply(Transform2.rotation(0.4)),
      pointer: pointer,
      capture: 160,
      edgeCapture: 100,
      mirrored: mirrored,
      mayRotate: mayRotate,
      exclude: exclude,
      keep: keep,
    );
