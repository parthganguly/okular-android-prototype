# Parthicle Reader debug APK pre-release checklist

Use this checklist only for prototype debug APKs. Every box needs current evidence; do not copy values from an older release.

## Approval and source

- [ ] User approved the version, tag, release notes, exact APK, and publication.
- [ ] Release is labeled **Debug prototype** and GitHub **pre-release**.
- [ ] Worktree is clean; branch and full commit SHA are recorded.
- [ ] Remote and target commit are correct.
- [ ] Build command, container/image, Qt/KF, SDK/NDK, ABI, and Java versions are recorded.

## Repository gates

- [ ] `scripts/verify-license.ps1` passes; Okular/KDE attribution and GPL/LGPL files remain.
- [ ] `scripts/verify-bridge.ps1` passes for any Java/C++/QML/TTS changes.
- [ ] No keystore, credentials, environment files, device data, or Repomix pack is staged.
- [ ] New third-party code/assets have provenance and license evidence.

## Exact APK

- [ ] Artifact path and byte size are recorded.
- [ ] `scripts/verify-apk.ps1 -ApkPath <apk> -WriteChecksum` passes.
- [ ] Required ABI and `lib/<abi>/libc++_shared.so` are present.
- [ ] `apksigner` result is recorded, or explicitly `not checked` if unavailable.
- [ ] `apkanalyzer` application ID is recorded, or explicitly `not checked` if unavailable.
- [ ] SHA-256 is copied from the exact upload artifact.
- [ ] `<apk>.sha256` contains the same digest and filename.

## Runtime evidence

- [ ] Install result is recorded. A signing mismatch with an installed package is reported as such, not called a build failure.
- [ ] Launch and document-open results are recorded for the tested device/API level.
- [ ] If TTS changed: engine discovery, speak, stop/restart, rate, voice, rotation/background/close, and engine-unavailable behavior are recorded.
- [ ] Untested runtime behaviors are listed as untested.

## Release notes and publication

- [ ] Notes include full commit SHA, SHA-256, ABI, package ID, debug signing status, device evidence, and known limitations.
- [ ] Notes retain Okular/KDE attribution and do not imply KDE e.V. endorsement.
- [ ] Command uses `gh release create ... --prerelease` and uploads both APK and `.sha256`.
- [ ] No `--latest`, stable-release wording, silent overwrite, release deletion, or force push is used.
- [ ] `gh release view` confirms tag, target, pre-release state, both assets, and public URL.

## Handoff record

```text
Tag:
Commit SHA:
APK path:
APK bytes:
SHA-256:
Checksum path:
ABI:
Application ID:
Signer verification:
Device/API tested:
Known limitations:
Pre-release URL:
```
