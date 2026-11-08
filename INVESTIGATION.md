# HomePod mini 2 setup investigation (2026-11-07)

## Confirmed second gate: HomeKit daemon compatibility check

The full UTF-16 syslog captured for the 21:29 setup attempt proves that the 0.1.4 HDSViewService update-gate bypass reaches the actual HomeKit daemon protocol exchange:

- 21:29:53.125: HDSViewService opens an `HMDeviceSetupSession`.
- 21:29:53.162: HDSViewService sends `HMDeviceSetupRequestMessage` (1397 bytes).
- 21:29:53.623: HDSViewService receives `HMDeviceSetupResponseMessage` (2564 bytes), passes it to `homed`.
- 21:29:53.628: `homed` receives `HMDUnassociatedAppleMediaAccessory` and reports accessory HomeKit version `14.0` (this is not the HomePodOS version).
- 21:29:53.628: `homed` logs **`Our pairing capabilities: 0x3, minimum software version satisfied: NO`**, followed by **`Cannot pair as current device doesn't have all required capabilities.`**
- 21:29:53.628: `homed` rejects session exchange with `HMErrorDomain Code=48`. HDSViewService receives the same error.
- 21:34:55: after 300 seconds, HDSViewService reports `kHomeKitSyncTimeoutErr` / `NSOSStatusErrorDomain Code=-71163` at `HomeKitSetupWaitDeviceSetup`.

**Conclusion:** The timeout is downstream of a proven `homed` compatibility rejection. Device discovery, pre-authorization, setup user interface, and actual HomeKit data exchange all progressed. This does NOT imply provisioning completed. We need to identify how `homed` computes the minimum software predicate, the current pairing-capability bitmask, and the required capability mask. Blindly forcing a success return may leave the accessory unconfigured.

## Existing HDSViewService patch

- Device `AudioAccessory11,1` identifies as type 11; it reported HomePodOS 27.0 in an earlier preauthorization response.
- The matching iOS 16.1.1 `HDSViewService` binary SHA-256 is `0ef19ac608379b89fc0eb93f190c5b4253ede0b88f44bf72e8f7ee0206e5eb91`.
- On that exact binary, replacing the conditional branch at image offset `0x82318` with an ARM64 NOP bypasses the unknown-device update screen.
- Version 0.1.4 locates the true `MH_EXECUTE` image despite ElleKit/systemhook image ordering; it must remain unchanged as our known working baseline.

## Required evidence before a homed patch

Obtain the **matching iOS 16.1.1 `homed` executable** from the jailbroken iPhone, or a matching extracted IPSW/firmware filesystem, for offline ARM64e disassembly. Do not use a daemon from a different iOS build. On the phone, first check (read-only):

```sh
ls -l /usr/libexec/homed
file /usr/libexec/homed
shasum -a 256 /usr/libexec/homed
```

If the path differs, locate the daemon through launchd service configuration or `find /usr /System/Library -name homed -type f 2>/dev/null` without editing the system volume. Transfer a **copy** of the file through the user's usual SSH/SFTP channel. Preserve the original. Some Apple executables are stored with an encrypted or stripped on-disk image; if the copied file is not disassemblable, obtain the exact-build decrypted image through a diagnostic dump or a matching firmware image instead.

Analyze the strings and cross-references for `Our pairing capabilities`, `minimum software version satisfied`, and `Cannot pair as current device`; identify the concrete branch and inputs. Only then design a signature-checked, fail-closed, in-memory tweak for `homed`, isolated from the working HDSViewService patch. Check the actual required features, not merely the numeric software gate, and verify that the HomePod completes pairing and is controllable. Never suppress `HMErrorDomain Code=48` or fabricate a completion notification.

## Safety and privacy

This log contains private HomeKit, device and account identifiers. Keep the full log private; share only the redacted lines above. No need for a new device log yet. Do not update iOS, reset the HomePod, modify an on-disk Apple executable, or abandon the jailbreak. This project remains experimental and complete pairing is **not** yet demonstrated.

## homed executable received (2026-11-07)

The 88 KB file copied from `/System/Library/PrivateFrameworks/HomeKitDaemon.framework/Support/homed` was received in a ZIP and verified as a 89,728-byte ARM64e Mach-O executable (PAC arm64e). SHA-256: `6c786e224e03a19a07ec68918b2c2c461f2ec6264ae05d26755c6b0d8ac69645`. It contains an `HMDMainDriver` reference and softlink paths to `/System/Library/PrivateFrameworks/HomeKitDaemon.framework/HomeKitDaemon` and `/System/Library/PrivateFrameworks/HomeKitDaemonLegacy.framework/HomeKitDaemonLegacy`. None of the three capability-rejection log strings appears in this executable. This is consistent with an entrypoint that delegates the pairing implementation to private frameworks; the actual check cannot safely be patched from this executable alone.

**Next read-only collection:** Locate and copy the two matching iOS 16.1.1 framework Mach-O images (or extract the exact-build dylibs from the arm64e dyld shared cache if they are not separate files). The user should first run `ls -lh` on both framework paths. Do not derive patch bytes or offsets from another iOS release.

## Exact-build dyld cache extracted in GitHub Actions (2026-11-07)

The automatic `extract-homekit.yml` job succeeded in recovering the arm64e dyld shared cache from the original iPhone14,3 iOS 16.1.1 (20B101) IPSW hosted on Apple's CDN. Its text-only diagnostic artifact identified exact string locations in both frameworks:

| Diagnostic string | HomeKitDaemon | HomeKitDaemonLegacy |
| --- | --- | --- |
| `Our pairing capabilities: 0x%lx, minimum software version satisfied: %@` | `0x1fe48a45c` | `0x1c4bb5821` |
| `Cannot pair as current device doesn't have all required capabilities.` | `0x1fe48a4ae` | `0x1c4bb5873` |
| `Received accessory HomeKit version: %@` | `0x1fe48a42b` | `0x1c4bb57f0` |

Extracted image sizes/hashes: `HomeKitDaemon` (27 MB; SHA-256 `d1c968d81ff3a5202d0a0c119be7a525d3e98d4541669aeced8f0ae57b42c46b`); `HomeKitDaemonLegacy` (24 MB; SHA-256 `68f9ff3981ea4b86e0f33d9e0189e663fb5bd9462fa384d022c0e3f4865d7320`).

Both images contain the rejection text, so the active code path still needs to be established. The workflow now collects cross-references to these exact strings. This is **not yet** a proof of a safe bypass or functional support for the newer HomePod.

## Pairing function identified by string cross-references

The next GitHub Actions artifact resolved both capability/rejection strings to the same Objective-C method in each framework:

`-[HMDDeviceSetupClientSession processSessionData:fromBundle:outAccessoryUUID:error:]`

- `HomeKitDaemon`: function start `0x1fdb90c58`. Capability-log reference `0x1fdb915bc` (+2404); rejection-log reference `0x1fdb91704` (+2732).
- `HomeKitDaemonLegacy`: function start `0x1c433ce18`. Capability-log reference `0x1c433d6a8` (+2192); rejection-log reference `0x1c433d908` (+2800).

The workflow was updated to capture focused ARM64e disassembly around both sets of references. This identifies where the logged rejection occurs but not yet how the capability mask or minimum OS version predicate are computed. Do not patch a branch without verifying those data dependencies and validating real HomePod provisioning.
