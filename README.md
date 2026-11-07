# HomePod Bridge (experimental)

An initial *test* tweak for Soumen's iPhone 13 Pro Max on iOS 16.1.1 with Dopamine rootless and ElleKit. It tries to let a newer HomePod mini 2 (device type 11) move past the HomePod Setup screen requiring a newer iOS version.

## What the reverse engineering established

- `HDSViewService.app/HDSViewService` is the actual 962 KB ARM64e setup executable.
- Its `HomePodSetupInteractor` checks the device type, accepts 0 or 5, and otherwise enters the "device ... is not known" update path. The captured iOS syslog reported `device 11`.
- The rejection is the `b.ne` instruction at image-relative offset `0x82318`. On the exact file supplied by the user, its 4 bytes are `61 00 00 54`.
- Replacing that conditional branch with an ARM64 NOP (`1f 20 03 d5`) allows execution to fall through to the existing success return. The tweak changes code in **HDSViewService memory only**, not the executable stored on disk.

**This is not yet tested on a device.** Subsequent pairing stages may have other iOS version or feature requirements. Installation has risks typical of experimental jailbreak tweaks, including process crashes. Use only on the matching iOS build and remove the package if the setup UI behaves unexpectedly.

## Build and test

1. To build through GitHub, put this folder's **contents** at the root of a GitHub repository. GitHub Actions will run `.github/workflows/build.yml` on pushes to `main`, using a macOS 15 runner and the modern ARM64e ABI. Download the `HomePodBridge-rootless-deb` workflow artifact when the build succeeds. Alternatively, on a Mac with Theos and the iOS 16.5 SDK run `make package FINALPACKAGE=1`.
2. Install the generated `.deb` on the *iPhone 13 Pro Max running 16.1.1* using Sileo. This is not for the iPhone 17.
3. Fully close the HomePod Setup view, then start a fresh pairing attempt so `HDSViewService` relaunches with the injected tweak.
4. Collect log lines containing `HomePodBridge` and `HomePodSetupInteractor` (and ideally the next setup steps).
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

Once connected over USB, run the existing working `pymobiledevice3 syslog live` command, filtering for `HDSViewService`; look for `[HomePodBridge] Patched unknown-device update gate` or its error messages. Avoid Frida attach for this experiment: in the earlier tests it failed for Calculator as well as the setup process, making it an unreliable indicator.

## Source integrity

Original extracted Mach-O SHA-256: `0ef19ac608379b89fc0eb93f190c5b4253ede0b88f44bf72e8f7ee0206e5eb91`

The uploaded Apple binary and app assets are **not included** in this source package.

## Sileo APT source

Each successful GitHub Actions build publishes a flat APT repository in `docs/`, including the built `.deb`, `Packages`, `Packages.gz`, and `Release`. The GitHub Pages source is:

`https://soum91.github.io/HomePodBridge/`

To enable the source for the first time, the repo owner must visit **Settings → Pages**, select **Deploy from a branch**, choose **main** and **/docs**, then save. GitHub Pages may take a few minutes to deploy. The Sileo source is usable only once the `Release` URL responds successfully.

The repository is currently unsigned. If Sileo rejects it for authentication or signature policy, use the directly downloaded `.deb` until a stable signing key and signed `Release` are configured.
