# HomePod Bridge (experimental)

An experimental tweak for Soumen's iPhone 13 Pro Max on iOS 16.1.1 with Dopamine rootless and ElleKit. Version 0.1.4 fixes the ElleKit Mach-O image-selection bug and has been observed advancing HomePod mini 2 (device type 11) past the update-required screen to **Setting Up**. Complete pairing is **not** working yet. The full setup log reveals that `homed` rejects a real HomeKit setup response with `HMErrorDomain Code=48`: `Our pairing capabilities: 0x3, minimum software version satisfied: NO` and `Cannot pair as current device doesn't have all required capabilities.` The later `kHomeKitSyncTimeoutErr (-71163)` is downstream of this rejection.

## What the reverse engineering established

- `HDSViewService.app/HDSViewService` is the actual 962 KB ARM64e setup executable.
- Its `HomePodSetupInteractor` checks the device type, accepts 0 or 5, and otherwise enters the "device ... is not known" update path. The captured iOS syslog reported `device 11`.
- The rejection is the `b.ne` instruction at image-relative offset `0x82318`. On the exact file supplied by the user, its 4 bytes are `61 00 00 54`.
- Replacing that conditional branch with an ARM64 NOP (`1f 20 03 d5`) allows execution to fall through to the existing success return. The tweak changes code in **HDSViewService memory only**, not the executable stored on disk.

**Observed on the actual devices:** version 0.1.0 bypassed the upgrade screen but immediately produced `Setup Failed (-6732)`. Version 0.1.1 regressed to the update-required screen. Version 0.1.2 removed the diagnostic hooks; version 0.1.3 proved the active Mach-O image was incorrectly assumed to be index zero. Version 0.1.4 selects the actual `HDSViewService` executable and reached **Setting Up**, followed by a HomeKit device-setup synchronization timeout. **Pairing is still not verified.** The next proven gate is inside the `homed` daemon, not the HDSViewService update check. A matching iOS 16.1.1 `homed` executable is required before developing a signature-checked, fail-closed compatibility patch. See `INVESTIGATION.md` for the precise event trace. Installation carries normal experimental jailbreak tweak risks, including process crashes. Use only on the matching iOS build and remove the package if the setup UI behaves unexpectedly.

## Build and test

1. To build through GitHub, put this folder's **contents** at the root of a GitHub repository. GitHub Actions will run `.github/workflows/build.yml` on pushes to `main`, using a macOS 15 runner and the modern ARM64e ABI. Download the `HomePodBridge-rootless-deb` workflow artifact when the build succeeds. Alternatively, on a Mac with Theos and the iOS 16.5 SDK run `make package FINALPACKAGE=1`.
2. Install the generated `.deb` on the *iPhone 13 Pro Max running 16.1.1* using Sileo. This is not for the iPhone 17.
3. Fully close the HomePod Setup view, then start a fresh pairing attempt so `HDSViewService` relaunches with the injected tweak.
4. Verify that `HomePodBridge 0.1.4` initializes and logs `Patched unknown-device update gate`. Collect the full setup stage trace if a later HomeKit error occurs. The experimental `ErrorTrace` and `ErrorStack` hooks from 0.1.1 remain removed.
5. To revert, **uninstall HomePod Bridge from Sileo**, then relaunch setup. The original Apple executable was never changed on disk.

Do not modify, overwrite, or replace Apple's system app. Do not update iOS, disable the jailbreak, or erase the HomePod in order to run this test.

## Safeguards

The tweak checks:

- The actual bundle identifier is `com.apple.HDSViewService`.
- Bundle version is `24`.
- The OS reports iOS 16.1.x.
- Twenty bytes around the branch precisely match those in the extracted executable.

If any check fails, the tweak skips patching and logs the reason.

## Debug logging on Windows

Once connected over USB, run `scripts/capture-homepod.ps1` from Windows PowerShell and start the setup attempt. It writes a timestamped text file to the **current directory**, not a possibly redirected Desktop folder. Run `python scripts/summarize-homepod-log.py PATH_TO_CAPTURE` for a privacy-conscious phase summary. Keep the unfiltered trace locally if the error is only reported from another daemon, and do not share unredacted account or pairing values. Avoid Frida attach for this experiment: in the earlier tests it failed for Calculator as well as the setup process, making it an unreliable indicator. See `INVESTIGATION.md` for the known HomeKit timeout and the current offline evidence.

## Source integrity

Original extracted Mach-O SHA-256: `0ef19ac608379b89fc0eb93f190c5b4253ede0b88f44bf72e8f7ee0206e5eb91`

The uploaded Apple binary and app assets are **not included** in this source package.

## Sileo APT source

**Dedicated HomePodBridge Sileo source:**

`https://soum91.github.io/homepodbridge/`

The `gh-pages` branch contains the latest successfully built package and matching APT metadata. The repository has now been renamed to all lowercase. The URL path is **case-sensitive**: `/homepodbridge/Release` returns HTTP 200, whereas the former `/HomePodBridge/Release` returns HTTP 404. Remove the old Sileo source and add the lowercase URL above. The build workflow keeps this branch updated with every successful build. This site is separate from Timbre.

HomePodBridge builds additionally publish the package and index in `docs/` on `main`. The raw GitHub alternative is:

`https://raw.githubusercontent.com/soum91/homepodbridge/main/docs/`

Use the dedicated GitHub Pages URL for installation and automatic updates. A temporary mirror was originally placed on Timbre's Pages site during troubleshooting, but HomePodBridge no longer relies on it.

The repository is currently unsigned. If Sileo rejects it for authentication or signature policy, use the directly downloaded `.deb` until a stable signing key and signed `Release` are configured.
