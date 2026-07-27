# jet_cad_2d

A pure-Dart 2D CAD engine and document model: identity, scene tree, columnar
geometry and entity stores, components, commands with undo, and a deterministic
document format.

**This package is independent of `jet_cad`.** Despite the shared name it does
not depend on it, does not link Open CASCADE, and shares no code with it. It has
no Flutter dependency and runs anywhere Dart runs.

Rendering and widgets live in `jet_cad_2d_flutter`. DXF and IFC support live in
separate adapter packages and use only this package's public API.

Status: pre-release. See
`docs/superpowers/specs/2026-07-27-jet-cad-2d-architecture-design.md`.
