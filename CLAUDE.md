# Claude Code instructions for Parthicle Reader

Follow `AGENTS.md` as the repository policy. This file adds Claude Code routing and hook behavior.

## Route work to the narrow tool

- Android/KDE/Craft failure: use `/parthicle-build-diagnose` or the `parthicle-build-doctor` agent.
- Java/C++/QML or TTS boundary change: use `/parthicle-bridge-change` and request the `parthicle-bridge-reviewer` agent before claiming completion.
- Attribution, SPDX, or dependency license work: use `/parthicle-license-check` or the `parthicle-license-cop` agent.
- APK inspection: use `/parthicle-apk-verify`.
- Debug prototype publication: use `/parthicle-release` and the `parthicle-release-manager` agent.
- Small, shareable repository context: use `/parthicle-context-pack`.

## Hook overrides

Hooks in `.claude/hooks/` block dangerous commands and release-policy violations. Do not bypass them for convenience.

- License-file writes require the user to explicitly approve the exact edit, then set `PARTHICLE_LICENSE_EDIT_CONFIRMED=1` for that one Claude Code invocation.
- A release command must name a `.sha256` asset or include `SHA-256`/`sha256` evidence. Prefer the release skill over an override.

If a hook blocks a command, explain the block and propose a safe command. Never split or obfuscate a forbidden operation to evade matching.

## Verification baseline

Run from the repository root:

```powershell
pwsh -NoProfile -File scripts/verify-bridge.ps1
pwsh -NoProfile -File scripts/verify-license.ps1
pwsh -NoProfile -File scripts/verify-apk.ps1 -ApkPath <path> -WriteChecksum
```

Use `powershell.exe` instead of `pwsh` on Windows PowerShell-only hosts.
