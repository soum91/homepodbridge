# Changelog

## 0.1.2 - 2026-11-07

- Reverted the `NSError` method hooks, limited error tracing, and Logos `%ctor` initialization added in 0.1.1 after the real iPhone 13 Pro Max test again showed the **Software Update** screen.
- Restored the exact 0.1.0 device-recognition patch logic and original C constructor entry point. Changed only the version label in its initialization log.
- Retained signature, iOS, build, and bundle checks. This is a rollback of a regression, **not** a claimed fix for the remaining `Setup Failed (-6732)` error.

## 0.1.1 - 2026-11-07

- Recorded the first real device test of 0.1.0: the update-required screen was bypassed, but the HomePod mini 2 immediately returned `Setup Failed (-6732)`. Pairing is **not** working yet.
- Added narrowly scoped `NSError` instrumentation in `HDSViewService` to record failure domain, code, user-info **key names only**, and a short symbolic call stack for `-6732`.
- Restricted the new diagnostics to the exact iOS 16.1.x / `HDSViewService` build 24 / original instruction signature, and enabled them only if the in-memory device-recognition patch succeeds.
- Capped logging to 32 relevant error events per process, omitting all private error values, Apple IDs, and pairing credentials.
- Retained the original reversible 4-byte in-memory patch. Neither iOS nor HomePod firmware is updated by this release.

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
- Diagnosed the initial Sileo Pages 404 as a case-sensitive route mismatch: before the repository rename, GitHub Pages served `/HomePodBridge/Release` (HTTP 200) but not lowercase `/homepodbridge/Release` (HTTP 404). Documented the case-sensitive address then in use.
- Following the repository owner's rename to lowercase, confirmed the routing reversed: `/homepodbridge/Release` now returns HTTP 200, while the obsolete mixed-case path returns HTTP 404. Updated all source URLs to lowercase. Confirmed package index, compressed index, and Debian payload are accessible and package-index SHA-256 checksums match the release metadata.

**Status:** Source and static patch verified; a rootless ARM64e `.deb` has been compiled in GitHub Actions. The tweak has not been tested on the actual iPhone/HomePod combination yet.
