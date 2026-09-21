import 'package:flutter/material.dart';

// Scaffold placeholder. Task 8 replaces this file with the real shell; it
// exists only so the generated project builds under the workspace's
// `sdk: ^3.5.0` floor, which the generator's own dot-shorthand syntax
// does not.
void main() => runApp(const FloorPlannerApp());

class FloorPlannerApp extends StatelessWidget {
  const FloorPlannerApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'Floor planner',
        home: Scaffold(body: Center(child: Text('floor_planner'))),
      );
}
