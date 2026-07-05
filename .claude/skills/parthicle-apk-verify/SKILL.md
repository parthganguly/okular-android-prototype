---
name: parthicle-apk-verify
description: Verify a Parthicle Reader Android APK's identity, ZIP integrity, ABI contents, libc++_shared.so, signature, SHA-256, and checksum sidecar. Use before install, handoff, or GitHub pre-release upload.
---

# Verify an APK

Select the exact artifact explicitly, then run:

```powershell
pwsh -NoProfile -File scripts/verify-apk.ps1 -ApkPath <apk> -WriteChecksum
```

Optionally pass `-ExpectedSha256 <digest>` to bind verification to a previously published value and `-RequireAbi <abi>` when the target differs from `arm64-v8a`.

Require:

- APK exists, has ZIP magic, and can be opened as an archive;
- required ABI directory exists;
- `lib/<abi>/libc++_shared.so` is packaged;
- SHA-256 matches any expected value and the sidecar is created from the same file;
- `apksigner verify --print-certs` succeeds when Android build-tools are installed;
- `apkanalyzer` identity/manifest output is captured when available.

Install `apksigner` and `apkanalyzer` later via Android SDK Build Tools / Command-line Tools for stronger inspection. Without them, report signature and manifest identity as `not checked`; do not infer them from the filename. Keep debug signing and pre-release status explicit.
