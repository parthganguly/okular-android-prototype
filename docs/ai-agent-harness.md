# Parthicle Reader AI-agent harness

This harness gives AI agents narrow, evidence-producing workflows for the risky seams of the Parthicle Reader Android prototype. It does not replace the build system, runtime tests, code review, or release approval.

## What is included

| Surface | Purpose |
| --- | --- |
| `AGENTS.md` | Repository-wide policy, architecture map, and hard gates |
| `CLAUDE.md` | Claude Code routing and hook behavior |
| `.claude/agents/` | Build, bridge, licensing, and release specialists |
| `.claude/skills/` | Repeatable release, diagnosis, bridge, license, APK, and context-pack workflows |
| `.claude/hooks/` | Pre-tool blocks for dangerous shell commands, unapproved license edits, and checksum-free releases |
| `scripts/verify-*.ps1` | Deterministic checks that can run without app source edits |
| `justfile` | Short local entry points |
| `repomix.parthicle.json` | Focused Java/C++/QML context packing with secret/build exclusions |

## Guardrail model

The hooks run before Claude Code tools:

- `block-dangerous-commands.sh` rejects `rm -rf`, forced pushes, `gh release delete`, `curl | bash`, and `Invoke-WebRequest | iex` forms.
- `block-license-removal.sh` rejects writes under protected license/attribution paths unless the user explicitly approved the exact change and the one-shot environment flag is set.
- `block-release-without-sha.sh` rejects `gh release create` unless the command visibly carries a `.sha256` asset or SHA-256 evidence.

Hooks are guardrails, not a shell parser or a security boundary. Humans still review commands, diffs, release notes, and external effects. Do not weaken, split, alias, or encode a command to evade a hook.

## Verification contracts

`verify-bridge.ps1` statically compares C++ JNI method names/descriptors with Java declarations, checks Java native methods have C++ exports, checks QML calls exist on the `Q_INVOKABLE` surface, and confirms basic TTS main-thread/shutdown markers. It does not compile or run the app.

`verify-license.ps1` checks required Okular/KDE attribution and GPL/LGPL files, protected deletions, and SPDX removals in the current diff. It is an engineering check, not legal advice.

`verify-apk.ps1` checks ZIP readability, the requested ABI, packaged `libc++_shared.so`, SHA-256, and optionally signature/application identity. If `apksigner` or `apkanalyzer` is absent, the script says that check was not performed.

## Typical flows

For a bridge change:

1. Invoke `/parthicle-bridge-change`.
2. Trace QML -> C++ -> JNI descriptor -> Java -> Android API and back.
3. Run `just verify-bridge` and compile affected targets.
4. Ask `parthicle-bridge-reviewer` for a read-only diff review.
5. Test on a device before making TTS or URI runtime claims.

For a debug prototype release:

1. Invoke `/parthicle-apk-verify` on the exact APK.
2. Invoke `/parthicle-license-check`.
3. Invoke `/parthicle-release`; follow `docs/release-checklist.md`.
4. Upload both the APK and checksum as a GitHub pre-release after explicit approval.

For a handoff, invoke `/parthicle-context-pack`. Review the generated XML and its security findings before sharing it. Repomix output is intentionally untracked.

## Optional tools to install later

The harness degrades honestly when optional tools are missing.

- **Repomix**: packs only the focused bridge/build/release context selected by `repomix.parthicle.json`.
- **Semgrep**: adds structural checks around JNI, activity lifecycle, and unsafe Android patterns. Pin rules before making it a gate.
- **ccache**: speeds repeated C/C++ builds after cache paths are kept inside the Linux/Craft environment.
- **reuse-tool**: performs the full REUSE/SPDX lint beyond the repository's narrow license script.
- **apkanalyzer**: reads package ID, manifest, files, and DEX metadata from an APK.
- **apksigner**: verifies APK signatures and prints signer certificate digests.
- **Pi + Gondolin**: provides a constrained agent runtime/sandbox for adversarial tool experiments; evaluate separately before granting repository credentials.
- **Qodo / PR-Agent**: can add pull-request summaries and automated review, but should remain advisory for JNI, licensing, and release gates.
- **Archon**: can retain architecture and build knowledge across sessions; store decisions and evidence, never secrets or signing material.

Install tools from their official distribution channels, pin versions in CI, and record which optional checks actually ran. The comments in `justfile` show the intended local integration points.

## Maintenance

When the bridge changes, run the bridge script against both the old and new contract and update it only for intentional APIs. When release policy changes, update the release skill, checklist, agent, and hook together. Keep skills short and procedural; put durable background here or in the focused build notes.
