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
