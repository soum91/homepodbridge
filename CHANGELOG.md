# Changelog

## 0.1.0 - 2026-11-07

- Confirmed the uploaded iOS 16.1.1 HomePod Setup executable is ARM64e Mach-O with bundle ID `com.apple.HDSViewService`, bundle version `24`.
- Identified the `HomePodSetupInteractor` unknown-device branch at image-relative address `0x82318` from the binary and the matching `device 11 is not known` log.
- Added an experimental 4-byte in-memory patch of that branch with strict bundle, OS, build, and surrounding-instruction checks.
- Restricted tweak injection to `HDSViewService` and provided Sileo-uninstall rollback instructions.
- Added a macOS GitHub Actions build with an ARM64e target, rootless package scheme, and downloadable `.deb` artifact.
- Added exact-binary SHA-256 and instruction-sequence verification script.
- Added reproducible flat Sileo APT metadata generation and a GitHub Actions publish step that keeps `/docs` current with successful builds.

**Status:** Source and static patch verified; a rootless ARM64e `.deb` has been compiled in GitHub Actions. The tweak has not been tested on the actual iPhone/HomePod combination yet.
