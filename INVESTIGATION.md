# HomePod mini 2 setup investigation (2026-11-07)

## Verified evidence

- Device: `AudioAccessory11,1`, reported as type 11 by iOS 16.1.1. The HomePod reports software version `27.0` in the previously captured pre-authorization response.
- The uploaded iOS 16.1.1 `HDSViewService` executable has SHA-256 `0ef19ac608379b89fc0eb93f190c5b4253ede0b88f44bf72e8f7ee0206e5eb91`.
- Earlier logs from before 0.1.4 show a successful `B238Setup` start acknowledgment and a `PreAuth response` from the HomePod, **even though** the old UI then reports the unknown-device update gate. BLE discovery and pre-authorization therefore functioned before the gate was bypassed.
- Version 0.1.4 repaired incorrect dyld image selection. The actual phone visibly advanced to **Setting Up**; the subsequent screenshot shows `kHomeKitSyncTimeoutErr (HomeKitSetupWaitDeviceSetup)` and `NSOSStatusErrorDomain` code `-71163`.
- The 17:02 setup timeout was observed separately from the 16:31 `systemhook.dylib` signature mismatch on 0.1.3. Do not treat the old mismatch as a 0.1.4 failure.
- Static strings in the iOS 16.1.1 setup executable already include `errorHomeKitSyncTimeout` and `HomeKitSetupStart`; the timeout is not necessarily itself a new iOS 27-only error type.

## What remains unknown

The timeout identifies **where** the client stopped waiting; it does not identify **why** the HomePod failed to complete device configuration. Possibilities include a Wi-Fi/HomeKit service issue, a newer protocol request, a capability that iOS 16.1.1 omits, or a peer-side error. None is yet proven.

`HDSViewService` imports the private `HomeDeviceSetup` framework, while the timeout log originates in `CoreUtils` through that setup path. The uploaded `HDSViewService.app` binary does not contain all the implementation needed to resolve that cause by static disassembly alone.

## Next experiment (no OS or firmware update)

1. Keep the 0.1.4 package installed. No new in-memory patch is justified by the timeout alone.
2. On Windows, run `scripts/capture-homepod.ps1` **before** beginning a fresh setup attempt with the phone close to the HomePod.
3. Retain HDSViewService/CoreUtils progress messages from the beginning of the attempt, not only the final error. The helper writes to the current directory to avoid redirected Desktop paths.
4. Run `python scripts/summarize-homepod-log.py FILE.txt` locally for a sanitized phase summary. Review the source log before sharing because setup logs can include identifiers and account metadata.
5. Correlate the last successful `B238Setup`, Wi-Fi handoff and `HomeKitSetup` messages against the `HomeKitSetupWaitDeviceSetup` timeout. Only then choose a guarded tweak change.

**Safety:** Do not suppress setup errors, forge a success acknowledgment, modify the system executable, reset the HomePod, or update the iPhone merely to make the UI finish. A completed setup must correspond to a genuinely configured HomePod.
