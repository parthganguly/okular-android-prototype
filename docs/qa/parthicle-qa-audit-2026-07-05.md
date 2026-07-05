# Parthicle Reader QA Audit

Date: 2026-07-05
Auditor: Claude (Fable 5) via Claude Code, per `docs/qa/fable-parthicle-audit-prompt.md`
Build audited: `artifacts/parthicle-reader-v0.3.0-debug.apk` (versionCode 10, versionName 0.3.0)
Device: Samsung SM-M356B (Galaxy M35 5G), Android 16, real hardware via adb (serial RZCY22FGP1Z)

Evidence classes are kept separate throughout: **[static]** = code/docs reading, **[build]** = harness scripts, **[apk]** = APK inspection, **[device]** = observed on the connected phone.

---

## Executive verdict

**Does it broadly do what it says? Yes.** The headline claims — local library scan grouped by folder, search, category tabs, opening PDFs/TXT, and an Android-system-TTS Listen panel with Play/Stop, speed chips, and voice list — were all observed working on a real device. PDF text extraction feeds TTS correctly and image-only PDFs produce the promised "no extractable text / OCR later" warning.

**What is verified vs assumed?** Verified on device: launch, scan, search, refresh, recents with real PDF thumbnails, TXT/PDF/Markdown opening, reader toolbar, overflow menu, TTS Play/Stop/speed with Google TTS, no-text messaging, delete-with-confirmation, back navigation, rotation during TTS. Assumed (static only): EPUB/comics/DjVu/XPS/TIFF support, folder-picker (SAF) flow, bookmark persistence, multi-page navigation UI, large-file behavior.

**Is it marketable as a prototype? Yes, with honesty about rough edges.** The current GitHub pre-release wording (debug-signed, prototype, KDE disclaimer, SHA-256) is accurate and appropriately modest. But this audit found one hard UI freeze, a broken "open with" path while the app is running, and a delete flow that strands the user on the deleted document — those should be fixed or disclosed before pushing it to a wider audience.

**Is it ready for Play Store / private beta? No (Play Store), almost (private beta).** Blockers: `MANAGE_EXTERNAL_STORAGE` will not pass Play policy for a document reader without a strong justification; debug signing; package id still `org.kde.okular.kirigami`; no session restore; the confirmed bugs below. A small private beta (side-loaded APK) is reasonable after the v0.3.1 fixes.

---

## Claim matrix

| Claim | Evidence source | Test performed | Status |
|---|---|---|---|
| Local-first Android document reader | README L3 | Full flows ran with no network dependency observed [device] | **Verified** (but manifest requests `INTERNET` [apk] — wording vs permissions mismatch worth cleaning up) |
| "MX Player for reading files" positioning | README L3 | Comparative feature audit (Phase 4) | **Partially verified** — library UX imitates MX Player, but lacks sort, resume, and reliable open-with |
| Opens PDFs | README L5 | Opened text PDF and image-only PDF; both rendered [device] | **Verified** |
| Opens TXT | README L5 | Opened `ParthicleQA-note.txt`, rendered correctly [device] | **Verified** |
| Opens Markdown | README L5; v0.3.0 release notes "Markdown opening: passed" | Opened `ParthicleQA-doc.md` [device] | **Partially verified / misleading** — file opens but renders as raw text (`#` and `-` literally visible); no Markdown formatting in this build |
| Opens EPUBs, comics, DjVu, XPS, TIFF, images | README L5 | MIME/extension lists in `OpenFileActivity.java:705-751` and Okular generators exist [static]; no test assets opened | **Not verified** (static support present; runtime untested) |
| Library scan / browse grouped by folder | README screenshots; WelcomeView | Fresh launch scanned shared storage, folders listed with counts, Refresh rescan worked, "Scanning local storage..." progress message shown [device] | **Verified** |
| Library search | Screenshot alt text "searchable" | Search "ParthicleQA" found all 5 pushed files incl. subtitle paths [device] | **Verified with defect** — list does not filter while IME composition is active (underlined text); filtering only applied on committed text |
| Category tabs Local/Documents/Books/Pictures | WelcomeView | Tabs render and are tappable [device]; classification logic read [static] | **Partially verified** (tab switching not exhaustively exercised) |
| Recents ("Local History") | WelcomeView | Opened files appeared with real PDF thumbnails (PdfRenderer) [device] | **Verified with defects** — duplicate entries for the same file (different URI forms); fake fixed 44% progress bar |
| Package remains `org.kde.okular.kirigami` (caveat) | README L27-29 | `aapt2 dump badging` [apk]; `pm list packages` [device] | **Verified** |
| TTS uses Android TextToSpeech, no bundled voices | README L17-21 | Google TTS spoke the page; `dumpsys audio` showed `com.google.android.tts` playback [device] | **Verified** |
| Installed engine selection | README L21 | Engine picker hidden (only one usable engine); logcat: Samsung TTS rejects the app (`check_allowed_package ... not allowed [-4]`) [device] | **Partially verified** — matches the release-note caveat; engine-switch UI untestable on this device |
| Voice selection | README L21 | Voice combo listed en-US voices; switching voices not exercised [device] | **Partially verified** |
| Speech speed control | README L21 | 1.5x chip selected, playback restarted [device] | **Verified with suspected defect** — rate appeared to reset to 1.0x after switching documents |
| Reads current-page extractable text | README L21 | "Reading page 1" on TXT and on text PDF; audio confirmed [device] | **Verified** |
| Image-only/scanned pages lack text; OCR later | README L21 | Play on image-only PDF produced exact warning "This page has no extractable text. Scanned PDFs need OCR later." [device] | **Verified** — but the panel says "Ready to read..." *before* Play, which is misleading (doc-level `supportsSearching` is true for all poppler PDFs) |
| Ethical Okular/KDE attribution, licenses retained | README L23-25, ATTRIBUTION.md | `verify-license.ps1` PASS; SPDX headers intact in all audited files; disclaimer present in README, ATTRIBUTION.md, and release notes [static][build] | **Verified** |
| Debug prototype, pre-release, SHA-256 published | v0.3.0 release notes | Computed SHA-256 `C71DFA2D...292B2E` matches release notes exactly; apksigner confirms Android Debug cert [apk] | **Verified** |

---

## Tests run

### Phase 2 — static harness checks [build]

`powershell.exe -NoProfile -File scripts/verify-bridge.ps1` (note: the prompt's `-ExecutionPolicy Bypass` flag was blocked by a repo permission hook; the CLAUDE.md baseline form was used instead):

```
JNI calls checked: 22
Java static methods indexed: 25
QML URIHandler calls checked: 11
TTS main-thread and shutdown markers: present
Bridge static verification: PASS (device/runtime behavior not tested)
```

`powershell.exe -NoProfile -File scripts/verify-license.ps1`:

```
License files: 12 tracked entries
Attribution: Okular/KDE/GPL terms present
Protected deletions: none
SPDX removals in current diff: none
Optional reuse-tool: not installed; full REUSE audit not run
```

`powershell.exe -NoProfile -File scripts/verify-apk.ps1 -ApkPath ..\artifacts\parthicle-reader-v0.3.0-debug.apk -WriteChecksum`:

```
APK: ...\artifacts\parthicle-reader-v0.3.0-debug.apk
Bytes: 87997754
ABI: arm64-v8a
NDK runtime: lib/arm64-v8a/libc++_shared.so
SHA-256: C71DFA2D2B208B2D8DAD76867EE85DE7A9B839DFBB107E87BFC2AABF57292B2E
Signature: not checked (apksigner unavailable)
Application ID: not checked (apkanalyzer unavailable)
Checksum file: ...\parthicle-reader-v0.3.0-debug.apk.sha256
```

**Tool gap:** the script reported apksigner/apkanalyzer unavailable, but `apksigner.bat` exists at `C:\ansdk\build-tools\36.0.0\` — the script's tool discovery misses this SDK layout. Run manually [apk]:

- `apksigner verify --print-certs`: **verifies**, signer `CN=Android Debug` (SHA-256 digest `50596bae...`), plus benign unprotected-META-INF warnings.
- `aapt2 dump badging`: package `org.kde.okular.kirigami`, versionCode 10, versionName 0.3.0, minSdk 21, targetSdk 35, label "Parthicle Reader". Permissions: `MANAGE_EXTERNAL_STORAGE`, `READ/WRITE_EXTERNAL_STORAGE`, `INTERNET`, `POST_NOTIFICATIONS`.
- `reuse` tool: **not installed** — full REUSE audit not run (reported, not skipped silently).

## Runtime test results [device]

Device: Samsung Galaxy M35 5G (SM-M356B), Android 16, 1080x2340. Installed build was byte-for-byte the audited artifact version (versionCode 10, installed 2026-07-04). A reinstall was deliberately skipped to avoid wiping the user's app data; "fresh install" was therefore **not** re-tested. Disposable test files were pushed to `/sdcard/Download/ParthicleQA/` and removed after the audit (the app's Recents may briefly show stale entries for them).

| # | Test path | Result |
|---|---|---|
| 1 | Fresh install / launch | Cold **launch** verified (~8s to library). Fresh *install* skipped to protect user data. |
| 2 | Storage permission flow | All-files access already granted on this device; the pre-grant UI (Allow / Folder buttons, MX-Player-style copy) exists in code and screenshots but the flow was **not** re-run. |
| 3 | Library scan | **Pass.** Folders with counts; cached overview then background rescan; "Scanning local storage for readable files..." shown. |
| 4 | Folder/manual picker (SAF) | **Not tested** (device already in all-files mode). |
| 5 | Recent files | **Partial.** Works, real PDF thumbnails render. Bugs: duplicate entries for the same file; fake 44% progress bar; stale entries after external deletion. |
| 6 | Search | **Pass with defect.** Case-insensitive, matches name+path. Does not filter while IME composition is active. Search text persists after opening/closing a document. |
| 7 | Category tabs | Render correctly; light exercise only. |
| 8 | Markdown/TXT open | TXT **pass**. Markdown opens but shows **raw markup** (no formatting). |
| 9 | PDF with extractable text | **Pass** — renders, TTS reads it ("Reading page 1", Google TTS audio confirmed via dumpsys). |
| 10 | Image-only PDF | **Pass** — renders; Play produces the OCR warning banner. |
| 11 | Toolbar show/hide | **Pass** — tap toggles chrome; auto-hide ~3.6s. Toolbar overlaps the top of the page content while visible. |
| 12 | Page navigation | **Not meaningfully tested** — all QA docs were single-page ("1 / 1" indicator correct; thumbnail strip requires pageCount > 1). |
| 13 | Bookmark button | **Not tested** on device (present in toolbar/menu). |
| 14 | Share | **Not tested** to completion (chooser not launched to avoid leaving external UI open). |
| 15 | Delete (disposable file) | **Confirmed bug.** Dialog is good ("Delete File? ... cannot be undone", Cancel/Yes). File verifiably removed from storage, but the app **stays in the reader showing the deleted document** instead of returning to the library. |
| 16 | Back/return-to-library | **Pass** — both the system Back key and the toolbar "Library" button return to the library. |
| 17 | TTS Listen panel appears | **Pass** (second session). **First session: hard UI freeze** the moment Listen was tapped — see Bugs. |
| 18 | TTS Play/Stop with Google TTS | **Pass.** Play → "Reading page 1" → audio; Stop → "Ready". |
| 19 | TTS engine list | Engine picker hidden (single usable engine). Logcat: **Samsung TTS rejects the app** — `SamsungTTS: org.kde.okular.kirigami is not allowed [-4]`, repeated every ~400ms while the panel is open (the QML refresh timer polls JNI 2.5x/second). |
| 20 | TTS voice list | Voices listed ("English (United States) - en-US-language" etc.). Switching not exercised. |
| 21 | TTS speed control | **Pass** — chips select, playback uses them. Suspected bug: rate reverted to 1.0x after a document switch. |
| 22 | No-text page behavior | **Pass** — correct warning; but panel status claims "Ready to read..." beforehand, and the warning appears at the top of the screen partially behind the toolbar, far from the panel. |
| 23 | Rotate / resume / background during TTS | Rotation: **pass** — playback continues, panel survives; but the Voice dropdown **overflows the panel** in landscape, and the library layout appeared transiently stretched afterwards. Background (Home) during TTS: speech stops (Android 16 also logs `AudioHardening background playback would be muted`), and on relaunch **the open document is gone** — no session restore. |
| 24 | Large file | **Not tested** (no large PDF staged). |

Additional device finding: **VIEW intents while the app is running do not open the document.** Reproduced twice (once with a document open, once right after returning to library): the intent is delivered, `onNewIntent` runs, but the UI never switches documents. Cold-start VIEW intents work. Practical impact: "Open with Parthicle Reader" from a file manager silently does nothing whenever the app is alive in the background.

---

## Top 10 missing common-sense features

Severity: **[Must]** fix before serious public marketing · **[Should]** fix before Play Store/private beta · **[Nice]** later.

1. **[Must] Session restore / resume reading.** Backgrounding the app loses the open document; there is no "continue where you left off," which is the single most expected behavior in a reader (MX Player resumes position). Persist last document URI + page in `SharedPreferences`/Okular docdata and reopen on launch. Files: `OpenFileActivity.java`, `mobile/app/package/contents/ui/main.qml`, `documentitem.cpp`.
2. **[Must] Reliable "Open with" handling while running.** See confirmed bug; without it the app can't be anyone's default reader. Files: `OpenFileActivity.java` (`onNewIntent`/`handleViewIntent`), `mobile/app/android.cpp`, main QML `openRequested` handling.
3. **[Should] Sort options (name/date/size/type) + "recently added" ordering.** Everything is hardcoded alphabetical (`Collections.sort(..., compareToIgnoreCase)`). Files: `OpenFileActivity.java` (buildAllFiles/FolderPicker JSON), `WelcomeView.qml` header row.
4. **[Should] TTS pause/resume and page auto-advance.** Stop-only playback and one-page-at-a-time reading make Listen a demo, not a feature. Auto-advance to the next page when utterances finish; add pause. Files: `ParthicleTtsController.java` (completion callback), `MainView.qml`, bridge methods.
5. **[Should] Background TTS with a media notification.** Android 16 actively mutes backgrounded playback (`AudioHardening` observed); continuing playback requires a foreground service + MediaSession. Until then, document the limitation in the panel. Files: new Java service, manifest.
6. **[Should] First-run onboarding & permission rationale.** The app jumps straight to an all-files-access request; one explanatory screen ("scans your files on-device, nothing leaves your phone") would raise grant rates and soften the scary `MANAGE_EXTERNAL_STORAGE` prompt. Files: `WelcomeView.qml`.
7. **[Should] Delete follow-through and undo.** Fix the stuck-on-deleted-document bug; then consider snackbar-undo (trash/deferred delete) instead of irreversible delete. Files: `MainView.qml` (`deleteDocumentDialog`), `OpenFileActivity.java`.
8. **[Should] Accessibility pass.** Text-only toolbar buttons ("Crop", "Scroll", "⋮", "‹") need `Accessible.name`/TalkBack labels; verify 48dp touch targets and contrast of muted-on-cream text; test font scaling. Files: `MainView.qml`, `WelcomeView.qml`.
9. **[Should] Crash/feedback channel.** Debug prototype has no crash reporting and no in-app "report a problem" link; the freeze found in this audit would be invisible in the field. Minimal: a GitHub Issues link in an About panel. Files: QML about/settings surface (new).
10. **[Nice] Real reading-progress on recent cards.** Replace the hardcoded 44% bar with stored per-document progress (page/pageCount). Files: `WelcomeView.qml:519-527`, `OpenFileActivity.java` (persist last page in recents JSON).

## Top 10 common-sense design flaws

1. **[Must] Toolbar covers page content.** The floating toolbar overlays the top of the document (observed hiding the first lines of the TXT/PDF); in a reader, chrome should push or dim content, not obscure the first paragraph. Files: `MainView.qml` (readerToolbar anchoring / DocumentView top inset).
2. **[Must] Misleading "Ready to read" on no-text documents.** The Listen panel promises readiness, then Play fails with a warning rendered at the top of the screen, behind the toolbar, away from the panel. Put the page-level text check (or last warning) inside the panel status box. Files: `MainView.qml` (`friendlyTtsStatus`, `onPageTextReady`), `documentitem.cpp` (page-level text availability). 
3. **[Must] Fake progress bars on recent cards** (fixed `width: parent.width * 0.44`). Users will assume it's their reading position. Remove or make real. Files: `WelcomeView.qml:519-527`.
4. **[Should] Compact toolbar hides the document title and key actions.** On a normal phone in portrait everything collapses: no filename, Bookmark/Crop/Share/Delete gone, an unlabeled "⋮" as the only route. At minimum show the elided title. Files: `MainView.qml` (compactControls thresholds).
5. **[Should] Listen panel layout shifts under the user's finger.** The status box grows/shrinks ("Ready..." vs "Reading page 1"), moving Play/Stop between taps (observed causing missed taps). Fix the status area height. Files: `MainView.qml` (ttsPanel status Rectangle).
6. **[Should] Landscape TTS panel overflow.** Voice dropdown renders past the panel's rounded bottom edge and is clipped by the screen. Make the panel content scrollable / recompute max height in landscape. Files: `MainView.qml` (ttsPanel width/height/y).
7. **[Should] Library rows carry no location or metadata context.** In search results and category views, the subtitle is the raw path prefix truncated (`/storage/emulated/0/Download/...`), folders show generic identical icons, and a folder literally named "0" tops the list. Show friendly relative paths ("Download › ParthicleQA"), better folder icons, and consider grouping storage-root noise. Files: `OpenFileActivity.java` (subtitle), `WelcomeView.qml`.
8. **[Should] Terminology drift.** "Local History" vs "Recently opened"; "Mark/Saved" in the toolbar vs "Bookmark" in the menu; "Doc" badge for TXT/PDF/MD alike; "Listen" hidden behind an unlabeled overflow. Pick one vocabulary and make Listen a first-class toolbar action (it's the release's headline feature). Files: `MainView.qml`, `WelcomeView.qml`.
9. **[Should] System-bar and immersive inconsistencies.** First TXT open showed the nav bar and a huge black letterbox; later opens were fully immersive; the library uses light content on a cream background while the reader letterboxes on near-black — the transition flashes. Files: `OpenFileActivity.java` (`applyReaderMode`, `prepareFullscreenWindowForQt`), `MainView.qml` background.
10. **[Nice] Delete sits directly under Share in the overflow menu** with identical styling; destructive actions deserve separation or a red tint (the confirm dialog does mitigate this). Files: `MainView.qml` (moreActionsPanel).

---

## Bugs or suspected bugs

### Confirmed on device

1. **Hard UI freeze opening the Listen panel (first session).** Tapping Listen froze the entire QML UI: identical frames (MD5-equal screenshots) for 40+ seconds, no input response, activity still `mResumed=true`, no crash/ANR dialog; required `am force-stop`. Not reproduced in the second session. Prime suspect: a blocking synchronized TTS/JNI call on the Qt GUI thread (`refreshTtsData()` → `ttsStateJson`/`ttsEnginesJson`/`ttsVoicesJson` are `synchronized` and make binder calls, e.g. `getEngines()`, inside the lock) interacting with Samsung TTS's access rejection. The 400ms `ttsRefreshTimer` amplifies exposure. Files: `ParthicleTtsController.java`, `MainView.qml:852-858`.
2. **VIEW intent ignored while the app is running.** Two reproductions; cold start works. "Open with Parthicle" from another app silently fails when the app is backgrounded-but-alive. Files: `OpenFileActivity.java` (`onNewIntent` → `handleViewIntent`), QML `openRequested` handling.
3. **Delete leaves the user on the deleted document.** File confirmed removed from storage and dialog closed, but the reader kept displaying the (now-deleted) content; no return to library. Files: `MainView.qml` (`deleteDocumentDialog.onAccepted` → `deleteCurrentDocument()` return path), `OpenFileActivity.java`.
4. **Recents duplicates.** The same file appears twice in Local History when opened via different URI forms (e.g. `file:///sdcard/...` vs `file:///storage/emulated/0/...`); dedup compares exact URI strings. Files: `OpenFileActivity.java` (`recordRecentDocument`).
5. **No session restore after backgrounding.** Home during reading + relaunch lands on the library; document, page, and TTS session lost.
6. **Markdown renders as raw text** despite release notes claiming "Markdown opening: passed" — it opens, but headings/bullets show literally (Markdown generator absent/not engaged in this APK).
7. **Search does not filter during IME composition**; filtering applies only to committed text, and search text persists stale across open/close.
8. **Samsung TTS rejection logspam / single-engine reality on Samsung devices.** `SamsungTTS ... not allowed [-4]` repeats ~2.5x/sec while the panel is open. Fall out: engine picker never shows on the very devices the caveat targets.

### Suspected (observed once / not fully isolated)

9. **Speech rate resets to 1.0x after switching documents** (1.5x was selected and used, then the next document's panel showed 1.0x).
10. **Transient stretched library layout after rotation/resume** (header/search/history spaced across the whole screen during rescan, self-healed).
11. **First-open system-bar inconsistency** (nav bar visible on one open, immersive on the next, same file type).
12. **Fake 44% progress bar** listed here too because users will report it as a bug: `WelcomeView.qml:525`.

---

## v0.3.1 recommendation (small cleanup release only)

1. Fix delete → return-to-library (and drop stale recents thumbnails for deleted files).
2. Fix `onNewIntent`/document-switch so VIEW/SEND intents open while the app runs.
3. Move TTS JNI reads off the blocking path: never hold the controller lock across binder calls (`getEngines`, `getVoices`), cache engine/voice JSON, and slow the 400ms poll (or switch to event-driven updates). This is the freeze mitigation.
4. Show page-level no-text status inside the Listen panel; keep panel height stable.
5. Dedup recents by canonical path; remove the fake progress bar.
6. Fix landscape panel overflow.
7. Correct the release-notes claim about Markdown (or ship the Markdown generator if it was meant to be in).
8. Add TalkBack labels to icon/glyph-only buttons.
9. Update `scripts/verify-apk.ps1` tool discovery to find `apksigner`/`aapt2` under `C:\ansdk\build-tools\<ver>\`.

No new features, no package rename, no signing change in this release.

## v0.4.0 recommendation (next real milestone)

**Theme: "a reader you can live in."**

1. **Session restore + reading progress**: reopen last document at last page; real progress on recent cards; per-document position store.
2. **Continuous TTS**: page auto-advance, pause/resume, foreground service + MediaSession notification so playback survives screen-off/backgrounding (this is also the fix for Android 16's background-mute).
3. **Library usability**: sort options, friendly folder subtitles/breadcrumbs, image-file opening polish.
4. **Identity groundwork**: begin the tested `com.greatparthicle.reader` package migration and a proper release keystore — as its own carefully tested change, per the README caveat.

## Do-not-do list (tempting but premature)

- **Play Store submission** — blocked by `MANAGE_EXTERNAL_STORAGE` policy, debug signing, and the `org.kde.okular.kirigami` package id. Fix v0.3.1/v0.4.0 items first.
- **OCR for scanned PDFs** — the current messaging ("OCR later") is honest; shipping OCR before TTS is continuous would invert priorities.
- **Bundling voice models / vendor TTS SDKs** — vendor-neutral system TTS is the right architecture; keep it.
- **Rewriting the reader as a native-Android PDF path** — explicitly against AGENTS.md scope; the Okular document model is the product's moat.
- **Cloud sync, accounts, or analytics** — contradicts the local-first promise before the local experience is solid (and `INTERNET` permission should arguably be removed, not exercised).
- **Broad marketing pushes** — until the freeze, intent-open, and delete bugs are gone; first impressions with a frozen reader are unrecoverable.

---

## Appendix: audit hygiene

- No app source was modified. No release was created or modified. Nothing was merged.
- Artifacts written: `artifacts/parthicle-reader-v0.3.0-debug.apk.sha256` (checksum sidecar, per verify script) and this report.
- Device changes: QA test files pushed to `/sdcard/Download/ParthicleQA/` and deleted afterwards; one QA file was deleted through the app's own Delete button as the destructive-action test (by design, disposable); rotation settings were saved and restored; the app was force-stopped twice (once to clear the freeze, once at cleanup). The app's Recents may show stale entries for the removed QA files until the next cleanup of its thumbnail cache.
- Missing tools reported, not assumed: `reuse` (not installed), script-level apksigner/apkanalyzer discovery (gap; run manually), root-level `/data/anr` traces (not readable on a non-rooted retail device, so the freeze stack is behavioral evidence only).
