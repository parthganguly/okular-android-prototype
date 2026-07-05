---
name: parthicle-build-diagnose
description: Diagnose Parthicle Reader Qt 6, Kirigami, KDE Craft, Docker, androiddeployqt, Android SDK/NDK, KIO header, or libc++_shared.so build and packaging failures. Use when an Android build fails or a generated APK is missing.
---

# Diagnose Android/KDE builds

Read `docs/build/android-kde-docker-notes.md`. Preserve the first causal error and distinguish Windows host, Docker image, Linux CraftRoot volume, source tree, build tree, and generated packaging metadata.

1. Capture the exact failing command, complete first error block, current commit, container/image identity, Qt/KF versions, ABI, `ANDROID_SDK_ROOT`, `ANDROID_NDK_ROOT`, and deployment JSON path.
2. Check requested and installed platforms inside the same environment:

   ```sh
   grep -R 'android-3[56]' <build-or-deployment-metadata>
   sdkmanager --list_installed
   ```

   Install the platform actually requested (commonly `platforms;android-35`) instead of rewriting source merely because `android-36` is present.
3. Inspect `stdcpp-path` in generated `*-deployment-*.json`. Resolve it and verify the ABI-specific NDK sysroot contains `libc++_shared.so`. Treat duplicated prefixes, empty path components, and a wrong target triple as packaging metadata faults.
4. Check Linux case-sensitive paths separately:

   ```sh
   test -f <CraftRoot>/include/KF6/KIOCore/KIO/Global
   test -f <CraftRoot>/include/KF6/KIOCore/kio/global.h
   ```

   Restore the affected Craft cache/archive inside the Linux volume if a Windows sync collapsed the names.
5. Re-run only the smallest failing packaging step. Then run a clean package build before declaring the issue fixed.

Do not edit app source during diagnosis. Report hypothesis, confirming evidence, repair layer, verification, and remaining uncertainty. Mention `ccache` as an optional speedup only after correctness is restored.
