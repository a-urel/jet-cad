/// A command threw, and undoing what it had already applied threw too, so
/// the target is partially mutated and nothing was recorded in history
/// (spec 2a E3).
///
/// Thrown by `CompoundCommand.apply` and by a `ParametricEdit` (when undoing
/// the triggering edit fails, when the reference cascade's rollback fails,
/// and when the regeneration's rollback fails), in place of the plain
/// [StateError] they threw before. The message is unchanged. It is still a
/// [StateError], so every caller that catches one catches it as before. A
/// caller that must react to an unknown document state tests for this type
/// instead of matching the message: it rebuilds what it derived from the
/// document and stops trusting its history.
final class PartialMutationError extends StateError {
  PartialMutationError(super.message);
}
