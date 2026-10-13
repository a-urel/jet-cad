# Changelog

## 0.7.1

The first release on pub.dev. The code is the engine of jet-cad 0.7.0
(git tag `v0.7.0`) unchanged; what changed is how it is packaged:

- The package carries its own LICENSE (Apache 2.0), a README written for
  pub.dev and a runnable example (`example/jet_cad_2d_example.dart`).
- The SDK constraint is `^3.6.0` (was `^3.5.0`): the floor pub workspaces
  document for their members.
- The repository URL points at `https://github.com/a-urel/jet-cad`.
- Doc comments that named a member out of scope now resolve in the API
  reference.

From this release on, `jet_cad_2d` has its own version on pub.dev and its own
git tags (`jet_cad_2d-v0.7.1`). Before it, the engine was released with the
other jet-cad packages under one version; that history is in the repository's
[CHANGELOG.md](https://github.com/a-urel/jet-cad/blob/main/CHANGELOG.md).
