# Fable Parthicle Reader QA Audit Prompt

Use this prompt in Claude Code with the strongest available Claude/Fable reasoning model. This audit is read-heavy first, then test-heavy. Do not modify app source unless explicitly asked after the report.

```text
You are acting as the Parthicle Reader QA architect and product-debug reviewer.

Repository context:
Parthicle Reader is a local-first Android document reader based on Okular/KDE. It claims to be the "MX Player for reading files." It has prototype releases:
- v0.1.0-prototype: first usable Android prototype
- v0.2.0-prototype: Parthicle Reader rebrand
- v0.3.0-prototype: Android system Text-to-Speech MVP

Important project files:
- AGENTS.md
- CLAUDE.md
- docs/ai-agent-harness.md
- docs/release-checklist.md
- docs/build/android-kde-docker-notes.md
- README.md
- ATTRIBUTION.md
- mobile/app/ui/MainView.qml
- mobile/app/ui/WelcomeView.qml
- mobile/android/src/OpenFileActivity.java
- mobile/android/src/ParthicleTtsController.java
- mobile/app/android.cpp
- mobile/app/android.h
- mobile/components/documentitem.cpp
- mobile/components/documentitem.h

Goal:
Run a hard-nosed QA audit. Determine whether the app does what the README/release notes say, what obvious common-sense features are missing, and what common-sense design flaws remain.

Hard rules:
- Do not change app source code.
- Do not create a release.
- Do not merge anything.
- Do not make unsupported runtime claims.
- Separate static evidence, build evidence, APK inspection evidence, and device runtime evidence.
- If a tool is missing, say it is missing instead of pretending the check passed.

Phase 1 — Claim inventory
Read README.md, ATTRIBUTION.md, release notes if available, and docs. Extract every user-facing claim, including:
- local-first Android document reader
- opens PDFs, EPUBs, comics, images, Markdown, TXT, DjVu, XPS, TIFF, and supported formats
- library scan/search/browse behavior
- current Android package-name caveat
- TTS MVP claims: Android TextToSpeech, installed engines, voice selection, speed control, current-page extractable text, scanned/image-only limitation
- ethical Okular/KDE attribution

Produce a claim matrix:
| Claim | Evidence source | Test needed | Status: verified / partially verified / not verified / false / unclear |

Phase 2 — Static harness checks
Run from repo root:
- powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-bridge.ps1
- powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-license.ps1
If an APK path is available:
- powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-apk.ps1 -ApkPath <exact APK path> -WriteChecksum

Report exact output. Do not summarize as pass unless the scripts say pass.

Phase 3 — Build/runtime reality check
If the existing v0.3.0 APK artifact exists, do not rebuild first. Inspect it and install it on a connected Android device/emulator if available.

Test paths:
1. Fresh install / launch
2. Storage permission flow
3. Library scan
4. Folder/manual picker flow
5. Recent files behavior
6. Search behavior
7. Category tabs: Local, Documents, Books, Images
8. Open at least one Markdown/TXT file
9. Open one PDF with extractable text
10. Open one image-only/scanned PDF if available
11. Reader toolbar show/hide behavior
12. Page navigation
13. Bookmark button behavior
14. Share current document
15. Delete current document — do not actually delete user data; use a disposable test file
16. Back/return-to-library behavior
17. TTS Listen panel appears
18. TTS Play/Stop with Google TTS
19. TTS engine list behavior
20. TTS voice list behavior
21. TTS speed control
22. No-text-page behavior
23. Rotate screen / resume app / background app during TTS
24. Large file behavior if a large PDF is available

If no device/emulator is available, produce an explicit manual test plan instead of claiming runtime verification.

Phase 4 — Common-sense feature gap audit
Pretend you are an Android user comparing this to MX Player/VLC-style local file apps and common readers. Identify missing basics by severity.

Classify into:
- Must fix before serious public marketing
- Should fix before Play Store/private beta
- Nice later

Consider:
- first-run onboarding
- permission explanation
- sort by name/date/size/type
- file thumbnails and loading states
- empty states
- recent files reliability
- favorites/bookmarks discoverability
- search scope clarity
- current folder breadcrumb
- refresh/rescan behavior
- file delete confirmation and undo
- open-with/share-in Android intents
- progress indicator during scan
- no-text/scanned-PDF messaging
- OCR roadmap clarity
- TTS pause/resume vs stop-only
- TTS page auto-advance
- TTS notification/background playback expectations
- Android package name still org.kde.okular.kirigami
- debug signing / install-over caveat
- app icon/launcher identity
- crash/reporting channel
- accessibility: TalkBack labels, touch targets, contrast, font scaling
- offline/local-first privacy wording

Phase 5 — Common-sense design flaw audit
Review screenshots, QML, and runtime if available. Find design issues that a normal user would notice.

Look for:
- toolbar density
- hidden controls discoverability
- inconsistent terminology
- visual mismatch between library and reader
- too many buttons in reader chrome
- confusing TTS settings layout
- poor error copy
- permission copy that feels scary
- KDE/Okular leftovers visible to user
- package/app identity mismatch
- dark/light system bar mismatch
- insufficient loading feedback
- destructive actions too easy
- long filenames/truncation
- one-handed use problems

Phase 6 — Output
Create a report only. Do not edit app source.

Report format:

# Parthicle Reader QA Audit

## Executive verdict
- Does it broadly do what it says?
- What is verified vs assumed?
- Is it marketable as a prototype?
- Is it ready for Play Store/private beta?

## Claim matrix

## Tests run
Include commands and exact results.

## Runtime test results
Include device/emulator details if tested.

## Top 10 missing common-sense features
For each: severity, why it matters, suggested implementation, likely files touched.

## Top 10 common-sense design flaws
For each: severity, why it matters, suggested implementation, likely files touched.

## Bugs or suspected bugs
Separate confirmed bugs from suspected bugs.

## v0.3.1 recommendation
Small cleanup release plan only. No giant new features.

## v0.4.0 recommendation
Next real feature milestone.

## Do-not-do list
Things that would be tempting but premature.
```
