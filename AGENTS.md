# Parthicle Reader agent guide

## Scope

Parthicle Reader is an Android prototype built on Okular, KDE Frameworks, Qt 6, and Kirigami. Preserve the existing Okular document model and upstream licensing. Do not replace the reader with a thin Android-only PDF path.

Before changing code, read `CLAUDE.md` and the relevant skill in `.claude/skills/`. For harness maintenance, also read `docs/ai-agent-harness.md`.

## Repository map

- `mobile/app/`: Kirigami/QML application and C++ Android bridge.
- `mobile/android/src/`: Java activity, Android services, and `TextToSpeech` controller.
- `mobile/components/`: Okular document integration, including Android URI handling.
- `core/`, `part/`, `generators/`: upstream Okular behavior; treat edits here as high risk.
- `LICENSES/`, `COPYING*`, `ATTRIBUTION.md`: protected licensing and attribution surface.
- `scripts/`: deterministic harness checks; these are not app runtime code.

## Non-negotiable gates

1. Keep Java, JNI/C++, and QML bridge names, signatures, types, null/error behavior, and lifecycle semantics aligned.
2. Keep Android `TextToSpeech` initialization and engine calls on the Android main thread; stop and shut it down with the activity lifecycle.
3. Preserve SPDX headers, Okular/KDE attribution, GPL/LGPL texts, and upstream notices. Never remove or weaken licensing to simplify a prototype release.
4. Publish debug APKs only as clearly labeled GitHub pre-releases. Never describe a debug build as production-ready.
5. Calculate SHA-256 from the exact APK being uploaded, write a companion `.sha256` file, and include the digest in release notes.
6. Run `scripts/verify-bridge.ps1`, `scripts/verify-license.ps1`, and `scripts/verify-apk.ps1` as applicable. Report unavailable optional tools instead of pretending their checks ran.

## Build diagnosis order

Diagnose packaging before changing app source:

1. Confirm the requested Android platform exists inside the build container. Qt/Craft metadata may request `android-35` even when `android-36` is installed.
2. Inspect generated `*-deployment-*.json`. A malformed `stdcpp-path` or wrong ABI suffix can hide the NDK `libc++_shared.so` even when the library exists.
3. Check KIO headers inside the case-sensitive Linux CraftRoot. Both `KIO/Global` and `kio/global.h` may be required; a Windows volume copy can collapse their paths.
4. Only after packaging metadata, SDK, NDK, and cached headers are sound should source changes be considered.

## Working rules

- Make the smallest change that preserves the Okular flow.
- Never commit generated APKs, keystores, tokens, Craft roots, or Repomix output.
- Show the exact command, first relevant error, and affected path when a check fails.
- Keep claims proportional: a static bridge check is not a device test; a signed APK is not proof that TTS works at runtime.
- End release work with the commit SHA, APK path, SHA-256, signature result, and pre-release URL.
