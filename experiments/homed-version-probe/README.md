# HomePodBridge homed version probe (optional)

**Experimental 0.1.5-probe1, separate from stable HomePodBridge 0.1.4. Not published to the Sileo feed.**

The captured HomePod mini 2 setup was rejected by `homed` after receiving a real HomeKit response:
`Our pairing capabilities: 0x3, minimum software version satisfied: NO`,
`HMErrorDomain Code=48`. The disassembly of the matching iPhone14,3 iOS 16.1.1 (20B101) cache identifies
`-[HMDDeviceSetupClientSession processSessionData:fromBundle:outAccessoryUUID:error:]`.

This probe replaces **only** the local `isAtLeastVersion:` call result in that specific method with `true`.
It leaves the independent `canPairGivenCapabilities:` result untouched and preserves the final AND/branch,
so a genuinely missing pairing capability can still reject setup.

## Why it is isolated

- The installed HomePodBridge 0.1.4 patch to `HDSViewService` remains unchanged.
- This probe is a separate rootless package with its own filter targeting the `homed` process.
- It checks the exact iOS 16.1.1 (20B101) build, the `homed` process name, the loaded framework path,
  and a 16-byte ARM64e instruction signature before changing a single in-memory instruction.
- It patches whichever of the modern or legacy HomeKit framework images are present and match exactly.
- It never writes to the sealed system volume. Uninstalling the package and restarting `homed` restores original code.

## Explicit caveats

- This is a **version-check experiment, not a confirmed compatibility fix**. A more recent HomePod may rely on
  actual functions or protocols unavailable in iOS 16. Successful pairing is not guaranteed.
- While installed and loaded, it changes the version comparison for **all new HomeKit pairing attempts handled by
  these methods**, not exclusively HomePod mini 2. Avoid adding any other HomeKit accessories during testing.
- Injecting into the HomeKit daemon can temporarily disrupt Home control or crash/restart `homed`. Preserve
  the previously working 0.1.4 package and uninstall this probe if Home becomes unstable.
- Do not install a package until its GitHub Actions build has succeeded. No successful device test has occurred.

## Observation after a future opt-in install

1. Keep HomePodBridge 0.1.4 installed as the UI-gate bypass.
2. Install only the **separate** `HomePodBridge-homed-probe-deb` artifact if accepting the diagnostic risk.
3. Ensure the already-running `homed` process restarts so it loads the new tweak. Do not change system files.
4. Monitor syslog for `HomePodBridge homed-probe` and verify `Version-only comparison patched` before attempting setup.
5. If the HomePod still fails with `HMErrorDomain Code=48`, capture the new `Our pairing capabilities` line:
   the minimum-version predicate should be passed but `canPairGivenCapabilities:` may still reject.
6. Do not treat a dismissed error or UI success as completed pairing. Verify the HomePod appears in Home and
   responds to a real command.

No on-disk Apple framework modifications, update, jailbreak removal, or factory reset is required by this probe.
