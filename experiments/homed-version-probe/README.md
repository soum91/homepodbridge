# HomePodBridge homed capability bridge (optional)

**Experimental 0.1.6, separate from stable HomePodBridge 0.1.4. This is a reversible diagnostic step, not a confirmed pairing fix.**

The captured HomePod mini 2 setup was rejected by `homed` after receiving a real HomeKit response:
`Our pairing capabilities: 0x3, minimum software version satisfied: NO`,
`HMErrorDomain Code=48`. The disassembly of the matching iPhone14,3 iOS 16.1.1 (20B101) cache identifies
`-[HMDDeviceSetupClientSession processSessionData:fromBundle:outAccessoryUUID:error:]`.

The previous opt-in 0.1.5 probe changed **only** the local `isAtLeastVersion:` call result to `true`. A
real-device test then logged **`minimum software version satisfied: YES`**, but failed the separate capability
gate with `Our pairing capabilities: 0x3` and `HMErrorDomain Code=48`. That is evidence the first probe worked,
but the iPhone is missing at least one capability reported as required by the newer HomePod.

Version 0.1.6 retains the verified, exact-instruction minimum-version patch. It additionally hooks the runtime
`-[HMDUnassociatedAppleMediaAccessory canPairGivenCapabilities:]` selector in `homed`, calls Apple's original
implementation first, and logs its return value and the required mask if the accessor exists with integer ABI.
**Only** when the receiver is an Apple media accessory (including subclasses), the iPhone-offered mask is exactly
`0x3`, and Apple's result is false, the experimental hook returns true. All other calls keep Apple's result.
This tests whether the capability gate is the next blocker; it does **not** install missing HomeKit code or
pretend the newer HomePod protocol exists in iOS 16.

## Why it is isolated

- The installed HomePodBridge 0.1.4 patch to `HDSViewService` remains unchanged.
- This probe is a separate rootless package with its own filter targeting the `homed` process.
- It checks the exact iOS 16.1.1 (20B101) build, the `homed` process name, the loaded framework path,
  and a 16-byte ARM64e instruction signature before changing a single in-memory instruction.
- It installs the capability hook only after the version patch succeeds, and only in the opt-in homed package.
- It patches whichever of the modern or legacy HomeKit framework images are present and match exactly.
- It never writes to the sealed system volume. Uninstalling the package and restarting `homed` restores original code.

## Explicit caveats

- This is a **capability-gate experiment, not a confirmed compatibility fix**. A more recent HomePod may rely on
  actual functions or protocols unavailable in iOS 16. Successful pairing is not guaranteed.
- While installed and loaded, it changes the version comparison for **all new HomeKit pairing attempts handled by
  these methods**. Its new capability override applies to any new Apple-media pairing where the local mask is
  exactly `0x3`, not exclusively HomePod mini 2. Avoid adding other accessories during testing.
- Injecting into the HomeKit daemon can temporarily disrupt Home control or crash/restart `homed`. Preserve
  the previously working 0.1.4 package and uninstall this probe if Home becomes unstable.
- Do not install a package until its GitHub Actions build has succeeded. No successful device test has occurred.

## Device test after installing from the experimental Sileo package

1. Keep HomePodBridge 0.1.4 installed as the UI-gate bypass.
2. Update the **separate** `com.soum91.homepodbridge.homedprobe` package to version **0.1.6**.
3. Ensure the already-running `homed` process restarts so it loads the new tweak. Do not change system files.
4. Monitor syslog for `HomePodBridge homed-probe` and confirm both `Minimum-version predicate patched` **and**
   `Apple-media capability hook installed=1` before attempting setup. If either is absent, don't infer a gate result.
5. During pairing, capture `capability gate:` lines to see the actual receiver class, offered mask, required mask,
   original answer and whether the override applied. If pairing still fails, capture the new `homed` errors and
   distinguish a still-present Code=48 from a later protocol failure.
6. Do not treat a dismissed error or UI success as completed pairing. Verify the HomePod appears in Home and
   responds to a real command.

No on-disk Apple framework modifications, update, jailbreak removal, or factory reset is required by this probe.
