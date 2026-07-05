# Android KDE/Craft Docker notes

These notes target the Parthicle Reader Qt 6/Kirigami Android packaging path. Paths vary by Craft image and Qt/NDK version; collect them from the failing container rather than copying old values blindly.

## Keep the layers distinct

| Layer | Typical contents | Diagnostic question |
| --- | --- | --- |
| Windows host | source checkout, Docker client, Android device | Is a host path being projected case-insensitively? |
| Docker image | SDK command-line tools and build packages | Is the requested platform installed here? |
| CraftRoot volume | Qt, KDE Frameworks, ECM, KIO headers | Did a cached package extract correctly on Linux? |
| Build tree | CMake state and generated deployment JSON | What exact platform, NDK, ABI, and `stdcpp-path` were generated? |
| APK | ABI libraries, manifest, resources, signature | Was the expected runtime actually packaged? |

Run checks in the layer that owns the path. Seeing `android-36` on Windows does not prove the container has `android-35`.

## android-35 / android-36 mismatch

`androiddeployqt` follows generated project/deployment metadata. If it requests `platforms/android-35`, installing only `android-36` does not satisfy it.

Inside the build container:

```sh
grep -R 'android-3[56]' <build-directory>
sdkmanager --list_installed
sdkmanager 'platforms;android-35'
```

Use the image's real `sdkmanager` path and explicit `--sdk_root` if its environment is not initialized. Re-run the packaging step. Do not change `compileSdk` or app source until the generated request and supported Qt/Craft configuration are understood.

## `libc++_shared.so` and `stdcpp-path`

Qt's generated `*-deployment-*.json` tells `androiddeployqt` where the NDK C++ runtime lives. Inspect it directly:

```sh
find <build-directory> -name '*-deployment-*.json' -print
grep -n 'stdcpp-path\|target-architecture' <deployment-json>
find "$ANDROID_NDK_ROOT" -path '*/aarch64-linux-android/libc++_shared.so' -print
```

For arm64, the resolved path must use the NDK sysroot's `aarch64-linux-android` runtime. A value containing a duplicated root, `/lib//home/...`, a missing ABI suffix, or a path from the host is generated-metadata damage. Repair/regenerate packaging metadata at that layer; do not edit Java/C++/QML.

After packaging, run:

```powershell
pwsh -NoProfile -File scripts/verify-apk.ps1 -ApkPath <apk>
```

This proves `lib/arm64-v8a/libc++_shared.so` is in that APK, not that every native dependency loads on-device.

## KIO case-sensitive headers

KIO can expose both uppercase forwarding headers and lowercase implementation paths. A copy through a case-insensitive Windows filesystem can merge them. Check in the Linux CraftRoot:

```sh
test -f /path/to/CraftRoot/include/KF6/KIOCore/KIO/Global
test -f /path/to/CraftRoot/include/KF6/KIOCore/kio/global.h
find /path/to/CraftRoot/include/KF6/KIOCore -maxdepth 2 -iname 'global*' -print
```

If one case variant is absent, restore/re-extract the KIO package cache inside the case-sensitive Linux volume. Do not create an improvised header or change include spelling in Okular to mask a damaged SDK.

## Useful evidence bundle

Capture:

- commit and dirty status;
- Docker image ID and mounted volumes;
- Qt, KF, ECM, SDK, NDK, Java, CMake, and Ninja versions;
- ABI and generated deployment JSON;
- first causal build error (not only the final Gradle failure);
- installed Android platforms;
- resolved `libc++_shared.so` and KIO header paths;
- final APK path and SHA-256.

`ccache` can be installed later to accelerate correct builds. Put its cache in a stable Linux/Docker volume and include compiler identity in cache debugging; never use cache success to hide an unreproducible clean build.
