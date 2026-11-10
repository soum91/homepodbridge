# Changelog

## 0.1.8 homed probe / 0.1.5 UI tweak - 2026-11-10

- Privacy-only packaging update: replace the owner’s legal-name attribution with `soum91` in source package controls, published Sileo metadata, and available historical `.deb` files.
- Rebuild both current packages under incremented versions so installed package metadata can be refreshed through Sileo. No tweak logic, HomeKit compatibility, or pairing behavior has changed; device verification remains pending.

## 0.1.7 (optional homed capability-hook scheduling diagnostic) - 2026-11-09

- Moved experimental `homed` capability-hook installation from the daemon's main dispatch queue to a utility queue. The setup callback may not drain the main queue promptly, preventing a reliable indication that the hook actually installed.
- Added up to 12 bounded attempts over approximately three seconds if HomeKit's Objective-C class or selector has not been registered yet; never hook unrelated classes.
- Emit explicit unified-log milestones for library injection, exact-build minimum-version patch verification, capability-hook installation status, and capability-predicate evaluations. The Apple pairing bypass and its restrictions are unchanged from 0.1.6.
- This is a diagnostic and scheduling change only. Physical-device activation and successful HomePod pairing are not yet verified.
- Source baseline: https://github.com/soum91/homepodbridge/commit/1966b939b41715ce14462ef038ff2dc5d84b482c . Current comparison: https://github.com/soum91/homepodbridge/compare/1966b939b41715ce14462ef038ff2dc5d84b482c...main .

## 0.1.6 (optional homed capability bridge) - 2026-11-08

- Confirmed from a real iPhone 13 Pro Max `homed` log that the separate 0.1.5 minimum-version probe succeeds: `minimum software version satisfied: YES`. The HomePod pairing attempt nevertheless fails Apple's independent capability requirement with an offered mask of `0x3` and `HMErrorDomain Code=48`.
- Added an opt-in, process-scoped hook of `HMDUnassociatedAppleMediaAccessory canPairGivenCapabilities:`. It invokes Apple's original method, records the receiver class and optional integer required-mask result, and overrides a false answer **only** for Apple-media receivers whose offered mask equals the observed `0x3`.
- Install the hook only after the signature-verified iOS 16.1.1 (20B101) in-memory minimum-version patch succeeds. Preserve the unchanged 0.1.4 `HDSViewService` UI-gate bypass and make no on-disk Apple system file changes.
- This release tests the next capability gate; the complete HomePod mini 2 protocol is **not yet verified compatible** with iOS 16.1.1, and a real-device setup test is still required.

## 0.1.4 - 2026-11-07

- Identified the real cause of the signature mismatch from the iPhone 13 Pro Max diagnostic capture: `_dyld_get_image_header(0)` returned `/usr/lib/systemhook.dylib`, not the `HDSViewService` executable, so the previous releases examined the wrong instructions.
- Locate the loaded Mach-O explicitly by requiring `MH_EXECUTE` and the `HDSViewService` executable basename, rather than assuming image index zero is the executable.
- Retain all bundle/version/iOS checks and the complete 20-byte expected signature check before applying the existing 4-byte in-memory branch patch. Refuse to patch if no matching executable or signature is found.
- Log the selected executable path to aid verification. HomePod pairing still requires a real device test; this change fixes the image selection bug, not the entire unverified pairing protocol.

## 0.1.3 - 2026-11-07

- Confirmed from a real iPhone 13 Pro Max syslog capture that ElleKit loads `HomePodBridge 0.1.2` inside `HDSViewService`, but the signature guard refuses the patch because live memory differs from the original executable file.
- Added read-only diagnostics on signature mismatch: log the loaded main executable path and the exact 20 live instruction bytes alongside the 20 expected bytes.
- Retained the existing bundle/build/iOS checks and fail-closed behavior. This release deliberately does not change any patch offset or bypass the signature guard; HomePod pairing is not yet fixed.

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
