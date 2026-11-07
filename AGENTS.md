# HomePodBridge development conventions

- Target: Dopamine rootless, iPhone 13 Pro Max, iOS 16.1.1, ARM64e system process `com.apple.HDSViewService`.
- Never modify Apple's original HDSViewService executable on disk. Inject a tweak and use a reversible memory patch only.
- Never require an iOS update, jailbreak reset, erasure, or modification of users' credentials.
- Verify the entire expected instruction signature before any patch, and do nothing on mismatched executables.
- Every new release must describe *real* verified code changes in CHANGELOG.md. No generic changelog entries.
- Version the `control` file with `major.minor.patch`, and increment on release. Expose the exact installed version through Sileo package metadata and the patch log.
- Build on macOS using ARM64e and THEOS_PACKAGE_SCHEME=rootless. Upload `.deb` as a GitHub Actions artifact.
- A successful compile is not evidence of working HomePod pairing. Report UI tests and further protocol failures accurately.
