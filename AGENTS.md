# HomePodBridge development conventions

- Target: Dopamine rootless, iPhone 13 Pro Max, iOS 16.1.1, ARM64e system process `com.apple.HDSViewService`.
- Never modify Apple's original HDSViewService executable on disk. Inject a tweak and use a reversible memory patch only.
- Never require an iOS update, jailbreak reset, erasure, or modification of users' credentials.
- Verify the entire expected instruction signature before any patch, and do nothing on mismatched executables.
- Every new release must describe *real* verified code changes in CHANGELOG.md. No generic changelog entries.
- Version the `control` file with `major.minor.patch`, and increment on release. Expose the exact installed version through Sileo package metadata and the patch log.
- Build on macOS using ARM64e and THEOS_PACKAGE_SCHEME=rootless. Upload `.deb` as a GitHub Actions artifact.
- A successful compile is not evidence of working HomePod pairing. Report UI tests and further protocol failures accurately.


## Universal diagnostic copy and export contract

Applies to Codex, Claude and all future diagnostic/debug/log reporting UI:

- Never ship a silent clipboard-only Copy button. After writing a report to the platform clipboard, immediately verify the full written text where APIs permit and display success or actionable failure. Do not present success on an unverified write.
- Every report must also offer an independent native Share action and Save as plain `.txt` file. On iOS, use the system share sheet and native Files picker (`fileExporter` or `UIDocumentPickerViewController`), not a custom file-path prompt. Allow selection of the complete report.
- Export the full diagnostics, including actual installed app/build, OS/device, and actionable failure/return codes. Redact credentials, access tokens, passwords and other secrets. Do not upload reports without consent.
- Test on a signed real device: Copy, paste into another app, Share and Save to Files, including error paths. If physical verification is unavailable, say so explicitly; a passing build is not evidence of clipboard success.
- Prefer one reusable diagnostic export component per application. Ensure future releases and newly created repositories retain this rule in both AGENTS.md and CLAUDE.md.
