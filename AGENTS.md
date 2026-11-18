# Dopamine-Rose workspace

## Build and verification

This is the complete RootHide repository, not an Apelin tweak. The root Makefile builds BaseBin, Packages, then Application. Application/Makefile uses Xcode's `xcodebuild` with the Dopamine scheme and a generic iOS destination, then signs and packages IPA/TIPA archives. The full build requires the repository's macOS build dependencies; see `.github/workflows/rose-roothide.yml`. Do not treat a device-side Clang syntax check as a full build.

This workspace has no Apelin external package script. Do not invent a replacement .deb or rewrite the jailbreak build just to make Apelin's build button work.

- `.github/ui-tests/run.sh` requires macOS, Xcode and an installed iPhone Simulator runtime. It stages seven byte-identical production Objective-C files using `prepare.py`, then exercises four themes with 68 screenshot cases. The fixtures replace business actions, so passing the harness does not verify jailbreak operations.
- `.github/scripts/verify_themes.py <archive.ipa-or-tipa>` validates an actual archive's four-theme resources, identity, RootHide payload, Mach-O signature commands and deployment targets. Synthetic fixtures only test the validator itself.
- Python syntax can be checked with `ast.parse`, Bash syntax with `bash -n`, and whitespace with `git diff --check` without Xcode.
- On a device with a prepared Clang/iPhoneOS SDK, `prepare.py` can stage sources into a temporary directory inside the workspace. Run `clang -arch arm64 -fsyntax-only -fobjc-arc -fblocks -I<staged-src> <staged-src>/*.m` for a limited syntax check. This does not link or run the app.

## Theme boundaries

The supported keys, in order, are `origami`, `glaze`, `nocturne`, `dusty-rose`. The default and unknown-key fallback is `glaze`, implemented in `DOThemeManager`. Shared UIKit blur, cards and native navigation remain part of all four themes. BaseBin's Swift tools and jailbreak IOSurface dependencies are unrelated to the removed fifth UI renderer and must not be removed as theme residue.

Keep application identity, RootHide payload and jailbreak implementation outside theme-only edits. Report full-build, simulator and physical-device checks separately; never infer runtime success from static checks. Building, installing, publishing and triggering remote workflows are separate actions.
