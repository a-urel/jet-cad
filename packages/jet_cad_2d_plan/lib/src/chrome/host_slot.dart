// A host slot (spec "The scope"): the host's own widgets there may be
// Material ones (a TextField, an InkWell), which need a Material ancestor
// whatever chrome the library draws around them. Infrastructure, not look.
import 'package:flutter/material.dart';

/// A transparent [Material] around [child], so a host's Material widgets
/// work in a slot of the library's chrome.
class PlanHostSlot extends StatelessWidget {
  const PlanHostSlot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}
