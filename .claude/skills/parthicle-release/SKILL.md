---
name: parthicle-release
description: Prepare or publish a Parthicle Reader debug APK prototype as a GitHub pre-release. Use for release checklists, version/tag preparation, SHA-256 generation, release notes, artifact upload, or GitHub pre-release verification.
---

# Release a debug prototype

Read `AGENTS.md` and `docs/release-checklist.md`. Use this fixed sequence; stop at the first failed gate.

1. Confirm the user-approved version/tag and that the artifact is explicitly a debug prototype.
2. Require a clean worktree. Capture `git rev-parse HEAD`, branch, and remote.
3. Locate one exact APK. Do not select by vague newest-file heuristics when multiple candidates exist.
4. Run:

   ```powershell
   pwsh -NoProfile -File scripts/verify-license.ps1
   pwsh -NoProfile -File scripts/verify-bridge.ps1
   pwsh -NoProfile -File scripts/verify-apk.ps1 -ApkPath <apk> -WriteChecksum
   ```

5. Record the uppercase SHA-256 and verify the companion `<apk>.sha256` contains the same digest and filename.
6. Draft notes containing: `Debug prototype`, full commit SHA, SHA-256, package/application ID if known, ABI, signing result, device/runtime evidence actually obtained, and known limitations.
7. Show the exact tag, APK, checksum, notes, and proposed command. Obtain user approval before creating the external release.
8. Create only a pre-release and upload both assets:

   ```sh
   gh release create <tag> <apk> <apk>.sha256 --prerelease --title "Parthicle Reader <tag> (debug prototype)" --notes-file <notes>
   ```

9. Read the release back with `gh release view` and confirm `isPrerelease`, tag, assets, URL, and target commit.

Never publish from a dirty tree, omit the checksum, upload a keystore, use `--latest`, claim production readiness, or delete/replace an existing release silently.
