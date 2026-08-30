# Task 2 Report: The Instance Record

## What was implemented

Created two new files for the GPU instance record wire format:

### 1. `packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart`
- Defined `const int kFloatsPerInstance = 10` - the size of one instance record
- Defined `const double kKindStroke = 0` - the kind tag for stroke records
- Implemented `void writeStroke(Float32List into, int index, {...})` function

The function writes a stroke record at a given index, packing 10 floats:
- `[kind, x0, y0, x1, y1, halfWidth, r, g, b, a]`
- Colour is extracted from argb (0xAARRGGBB) as four separate normalized floats (0-1 range)

### 2. `packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart`
- Single test: `writes a stroke at an offset without touching its neighbours`
- Guards against degenerate fixtures by filling the buffer with -1 initially
- Verifies exact layout matches the specification
- Verifies colour extraction from argb values (0x80402010 -> a=0x80, r=0x40, g=0x20, b=0x10)

## TDD Evidence

### Step 1: RED - Write and run the failing test

Command:
```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```

Expected failure (from brief):
- "Error: Error when reading 'lib/src/gpu/instance_record.dart': No such file or directory"
- "Method not found: 'writeStroke'"
- Multiple "Undefined name" errors for kFloatsPerInstance and kKindStroke

Actual output (relevant excerpt):
```
test/gpu/instance_record_test.dart:4:8: Error: Error when reading 'lib/src/gpu/instance_record.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';
       ^
test/gpu/instance_record_test.dart:8:32: Error: Undefined name 'kFloatsPerInstance'.
test/gpu/instance_record_test.dart:14:5: Error: Method not found: 'writeStroke'.
    writeStroke(buffer, 1,
    ^^^^^^^^^^^
...
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart [E]
```

Failures were as expected.

### Step 2: GREEN - Implement and run the passing test

Command:
```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```

Actual output:
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart
00:00 +0: writes a stroke at an offset without touching its neighbours
00:00 +1: All tests passed!
```

Test passes after implementation.

## Verification

### Full test suite
```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter && flutter test
```
Result: **417 tests passed** (including the new test)

### Static analysis
```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter && flutter analyze
```
Result: **No issues found!**

### Code formatting
```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
```
Result: **Formatted 77 files (0 changed)** - all formatting correct after initial format pass

## Commit

```
90c04f4 feat(gpu): the instance record, ten floats and none of them packed
```

Files:
- `packages/jet_cad_2d_flutter/lib/src/gpu/instance_record.dart` (45 lines)
- `packages/jet_cad_2d_flutter/test/gpu/instance_record_test.dart` (32 lines)

## Self-Review Findings

✅ **Completeness**: All required interfaces implemented exactly as specified
- `const int kFloatsPerInstance = 10;`
- `const double kKindStroke = 0;`
- `void writeStroke(Float32List into, int index, {required double x0, required double y0, required double x1, required double y1, required double halfWidth, required int argb})`

✅ **Layout**: Record layout matches specification exactly
- Slot 0: kind (kKindStroke = 0)
- Slots 1-4: x0, y0, x1, y1
- Slot 5: halfWidth
- Slots 6-9: r, g, b, a (normalized floats from argb)

✅ **Testing**: Test follows TDD cycle
- Guards against degenerate fixtures with -1 pre-fill
- Verifies offset isolation (neighbours untouched)
- Tests exact colour extraction math

✅ **Documentation**: Doc comments follow house style
- Explain *why* (web shader constraints, buffer pooling strategy)
- Cite evidence (`flutter_scene`'s web loader, `vertices_draw_sink.dart:41-57`)

✅ **Code quality**: No issues
- No analysis warnings
- Proper formatting
- Clear variable names (o for offset, standard practice in this codebase)
- Bitwise operations use standard idiom from brief

✅ **No scope creep**: Only what was specified
- No extra functions
- No premature optimization
- No placeholder for future kinds

## Issues or Concerns

None. Implementation is clean, tests are green, and ready for Task 3.
