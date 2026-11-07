# Changelog

## 0.1.0 - 2026-11-07

- Confirmed the uploaded iOS 16.1.1 HomePod Setup executable is ARM64e Mach-O with bundle ID `com.apple.HDSViewService`, bundle version `24`.
- Identified the `HomePodSetupInteractor` unknown-device branch at image-relative address `0x82318` from the binary and the matching `device 11 is not known` log.
- Added an experimental 4-byte in-memory patch of that branch with strict bundle, OS, build, and surrounding-instruction checks.
- Restricted tweak injection to `HDSViewService` and provided Sileo-uninstall rollback instructions.
- Added a macOS GitHub Actions build with an ARM64e target, rootless package scheme, and downloadable `.deb` artifact.
- Added exact-binary SHA-256 and instruction-sequence verification script.
- Added reproducible flat Sileo APT metadata generation and a GitHub Actions publish step that keeps `/docs` current with successful builds.
- Fixed Sileo source refresh failure: include the mandatory `Components: main` field in `Release` metadata. Sileo's repository parser rejects a release without it.
- Published a separate 0.1.0 Sileo APT mirror under `https://soum91.github.io/timbre/homepodbridge/`, using Timbre's existing active GitHub Pages site; the Pages deployment succeeded. Automatic updates to this mirror are not yet configured.
- Created a standalone HomePodBridge `gh-pages` branch with the package and index at the site root; added build workflow publication to the branch. GitHub Pages activated automatically and the first deployment completed successfully.
- Diagnosed the Sileo Pages 404 as a case-sensitive route mismatch: GitHub Pages serves `/HomePodBridge/Release` (HTTP 200) but not the lowercase `/homepodbridge/Release` (HTTP 404). Verified the correctly capitalized Release, Packages.gz, and .deb all return HTTP 200. Corrected the instructions to emphasize the exact mixed-case URL; no repository rename is required.

**Status:** Source and static patch verified; a rootless ARM64e `.deb` has been compiled in GitHub Actions. The tweak has not been tested on the actual iPhone/HomePod combination yet.
