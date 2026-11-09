# Claude instructions

Follow [AGENTS.md](AGENTS.md) and preserve all existing project-specific policies. Every published release must document actual changes since the previous applicable release, with commit links and a compare diff. Do not invent functionality or use generic release notes. For rebuild-only releases, specify verified packaging, signing, or toolchain differences. Preserve existing CHANGELOG.md history. Keep .github/workflows/release-changelog.yml enabled, including release, workflow_run, and scheduled reconciliation; investigate failed factual checks rather than suppressing them.


## Diagnostic/reporting rule for Claude

Before implementing or changing any diagnostics or logs, follow the **Universal diagnostic copy and export contract** in `AGENTS.md`: verified Copy with visible feedback, native Share, native plain-text Files export, and complete selectable report. Avoid claiming these work until a signed-device paste and export check is complete.


## Universal diagnostic export contract

Every diagnostic/log report requires Copy with clipboard read-back verification where supported and visible success/failure, native Share, native Save as `.txt` with Files picker (`fileExporter` or `UIDocumentPickerViewController` on iOS), and selectable full text fallback. No silent clipboard-only buttons. Include app/version, device/OS, actionable return codes and redact secrets. Test cross-app paste, Share, Save on a signed device; otherwise mark unverified. Preserve existing policies.
