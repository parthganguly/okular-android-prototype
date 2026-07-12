# Parthicle Reader — long-horizon product roadmap

Date: 2026-07-12 · Source: head-to-toe review (Fable 5). Horizons are sequenced by dependency, not calendar promises; durations are rough envelopes for a single part-time developer with AI-agent support [opinion]. Every item lists the user problem, evidence, dependencies, risk, success metric, and rejection criterion.

Evidence classes: [runtime] 2026-07-05 device QA · [artifact] APK inspection · [build] script runs · [static] source · [history] git/GitHub · [inference] · [opinion].

---

## Horizon A — Release integrity and reliability (now → ~4 weeks)

Goal: the next artifact a stranger downloads is exactly what it says it is, and the P0 fixes are proven on a device.

| # | Item | User problem | Evidence | Depends on | Risk | Success metric | Reject/stop if |
| --- | --- | --- | --- | --- | --- | --- | --- |
| A1 | Ship v0.3.1 correctly: bump manifest to versionName 0.3.1 / versionCode 11, rebuild, re-verify, device smoke test, publish pre-release with SHA-256 | Users can't tell fixed builds from broken ones; current v0.3.1 APK self-identifies as 0.3.0 | [artifact] aapt2 badging; issue #21 [history] | Build container; device access | Low | Installed app shows 0.3.1/11; smoke matrix passes on device | — |
| A2 | Device-verify the four QA fixes (freeze, hot ACTION_VIEW, delete→library, recents/fake-progress) | The fixes exist only as plausible diffs | [static] PR #20 diff; [runtime] bugs from QA report | A1 build | Medium — hot ACTION_VIEW fix may be incomplete (singleTask + QML routing has many paths [inference]) | Each QA bug reproduced-fixed on the same device model | Any fix fails → reopen issue, hold release |
| A3 | Correct README/format claims to match shipped generators (EPUB, DjVu currently absent; TIFF via kimgio unverified) | Broken first-experience trust when an advertised format fails to open | [artifact] no epub/djvu generator .so in APK | none | None | README lists only device-verified formats; in-app graceful failure copy | — |
| A4 | Fix `verify-apk.ps1` tool discovery + add identity gate (harness S1/S2) | Release process can't catch identity mismatch automatically | [build] this review; issues #3, #21 | none | None | Script fails on a deliberately mislabeled APK | — |
| A5 | Issue cleanup: close duplicates #12–#17/#19 against their twins, converge on one open set | Contributor confusion; stale P0 labels | [history] duplicate titles #4–10 vs #11–19 | none | None | Zero duplicate open issues | — |
| A6 | Reproducible-build notes: pin container image, Qt/KF/SDK/NDK versions in one doc tied to the release tag | No second person can produce the same APK | [static] build notes exist but unpinned | none | Low | A clean rebuild by-the-doc yields a working APK | — |

**Not in A:** any new feature, package rename, signing change (all deferred deliberately).

## Horizon B — Core reader credibility (~1–3 months)

Goal: a person can adopt Parthicle as their daily reader without hitting a "prototype moment" in the first week. This horizon is the MX-Player claim's minimum bar.

| # | Item | User problem | Evidence | Depends on | Risk | Success metric | Reject/stop if |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B1 | Session restore + real reading progress: persist last document/page; reopen on launch; real progress on recent cards; restore across process death | Losing your place is the #1 reader betrayal; app currently loses the open document on backgrounding | [runtime] QA test 23; [static] no restore code in OpenFileActivity | Recents identity (B2) | Medium (Okular docdata vs own store decision) | Kill app mid-document → relaunch lands on same page | — |
| B2 | Document identity normalization: canonical path/URI key for recents, progress, bookmarks | Duplicate recents entries; progress can't attach to a stable key | [runtime] QA bug 4; [static] exact-URI comparison | none | Low | Same file via any URI form = one recents entry | — |
| B3 | Reliable Open-with everywhere (cold, hot, from every major file manager) + default-reader viability | Silent failure when app alive in background made "Open with" untrustworthy | [runtime] QA bug 2; PR #20 fix unverified | A2 | Medium | 10/10 hot+cold VIEW intents open correctly across 3 file managers | — |
| B4 | Library: sort (name/date/size), friendly location subtitles, stale-entry cleanup, IME-composition search fix | Finding files is the core job; hardcoded alphabetical + raw path subtitles undercut it | [runtime] QA; [static] Collections.sort in OpenFileActivity | none | Low | Sort choices persist; search filters during composition | — |
| B5 | Error/loading/empty states pass: every screen has designed empty, loading, and failure copy | Blank or ambiguous states read as crashes | [runtime] QA observations; [static] QML | none | Low | State inventory reviewed screen-by-screen | — |
| B6 | Accessibility baseline: TalkBack labels on all controls, 48dp audit, font-scale pass, contrast fixes | Glyph-only buttons are unusable with TalkBack | [runtime] QA; [static] QML Accessible.name gaps | none | Low | TalkBack walkthrough of library+reader+TTS completes; principle P6 gate adopted | — |
| B7 | Multi-page navigation polish: thumbnails strip, go-to-page, bookmarks verified on device | Navigation untested beyond single-page fixtures | [runtime] QA rows 12–13 untested | device fixtures | Low | Matrix rows pass on a 200-page PDF | — |
| B8 | Device/form-factor matrix: at least one small phone, one large phone, one tablet/foldable profile through the smoke matrix | Single-device evidence (SM-M356B) is all that exists | [runtime] QA scope | emulator or borrowed devices | Medium | Matrix results recorded per release | — |
| B9 | EPUB decision: ship the Okular epub generator (with its dependency) or remove the claim everywhere | EPUB is table stakes for "reading files"; currently claimed and absent | [artifact] | Craft packaging work | Medium (libepub packaging on Android) | An .epub fixture opens on device, or claim removed | Packaging cost explodes → remove claim, revisit in C |

## Horizon C — Product differentiation (~3–9 months)

Goal: the features that make Parthicle *chosen*, not just tolerated.

| # | Item | User problem | Evidence | Depends on | Risk | Success metric | Reject/stop if |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C1 | Continuous TTS: page auto-advance, pause/resume, foreground service + MediaSession notification, screen-off playback | Listen is a demo without continuity; Android 16 mutes backgrounded audio without a service | [runtime] QA bug/AudioHardening log; [research] Android FGS/MediaSession docs | B1 (position model), A2 (TTS stability) | High (service lifecycle + Qt activity interplay) | A chapter plays screen-off to completion with lock-screen controls | Service architecture destabilizes reader → ship pause/auto-advance in-app first |
| C2 | Optional OCR for scanned pages (on-device, likely ML Kit or Tesseract as a dynamic/optional module) | Scanned PDFs are the most common "no text" disappointment | [runtime] warning path; user promise "OCR later" [history] | C1 (TTS is the consumer), B1 | High | A scanned page becomes listenable text on-device | Model size/quality unacceptable → keep honest warning |
| C3 | Annotations/highlights (Okular's annotation model, mobile UI) | Active readers need to mark up; Okular core already supports it | [static] core capability | B1/B2 identity+persistence | Medium | Highlight survives close/reopen and export | UI complexity balloons → notes-only first |
| C4 | Format test coverage: fixture corpus + per-release generator matrix (CBZ/CBR, FB2, mobi, XPS, DjVu-if-shipped) | Claims must stay honest as formats expand (P3/P7) | [artifact] gap found in this review | A3 fixtures | Low | Release notes carry a generated format matrix | — |
| C5 | Incremental library indexing (persistent index + MediaStore/FileObserver delta scan) — adopt only on measured need | Full rescans may not scale to large storage | [inference]; no measured data yet | B4 | Medium | Cold-start library on 10k-file storage < 2s | Measurements show full scan is fine → reject (avoid premature DB) |
| C6 | Privacy hardening: drop INTERNET permission (or document why), publish a one-paragraph privacy statement | Trust is the local-first product's currency | [artifact] permission present, unused [static] | verify nothing needs it (Qt internals check) | Low | APK carries no INTERNET permission or a documented reason | Qt stack breaks without it → document instead |
| C7 | Signed beta channel: proper keystore, versioned pre-releases, small tester group with a feedback path | Debug signing caps distribution and trust | [artifact] debug cert | A-series discipline | Low | 10+ external testers on a signed build | — |

## Horizon D — Production and scale (~9–24 months)

| # | Item | User problem / goal | Depends on | Risk | Success metric | Reject/stop if |
| --- | --- | --- | --- | --- | --- | --- |
| D1 | Package rename to `com.greatparthicle.reader` (or final identity) as one tested migration: manifest, Java packages, deployment metadata, prefs migration, upgrade testing | Cannot ship broadly as `org.kde.okular.kirigami` (also an endorsement-implication problem) | B-series stability; C7 keystore | High (breaks upgrades; must be before wide distribution, after feature stability) | Upgrade from old package documented; fresh install path clean | — |
| D2 | Distribution decision: F-Droid + GitHub first; Play Store only with a storage-permission strategy | `MANAGE_EXTERNAL_STORAGE` is Play-hostile for a reader; SAF-based scoped access likely required for Play | D1; storage rework | High | Listed on chosen channel with compliant permissions | Play policy cost too high → commit to F-Droid/sideload lane explicitly |
| D3 | Scoped-storage strategy: SAF tree access + MediaStore as default; all-files as power-user opt-in where lawful | Play compliance + user trust | D2 direction | High (library scan redesign) | Library works with zero broad-storage permission | — |
| D4 | Crash reporting with consent + in-app "report a problem" | Field defects invisible today | C7 beta | Low | Actionable crash reports from beta | — |
| D5 | CI/reproducible builds: containerized Craft build in CI, artifact provenance | One-machine bus factor | A6 pinning | High | CI produces installable APK from clean checkout | — |
| D6 | Localization pass (UI strings; KDE translation infrastructure already ships .mo assets) | Non-English readers | B5 string inventory | Medium | 2–3 languages complete | — |
| D7 | Tablet/foldable experience: two-page spread, adaptive library | Large-screen reading | B8 matrix | Medium | Tablet matrix passes | — |
| D8 | Upstream strategy: offer Android-generic fixes (edge rendering, URI handling, TTS bridge patterns) to okular-mobile | Reduce fork drift; give back | stable diffs | Low | One accepted upstream MR | — |

## Anti-roadmap — explicitly not building yet

| Idea | Why not now | Principle | Revisit when |
| --- | --- | --- | --- |
| Play Store submission | MANAGE_EXTERNAL_STORAGE, debug signing, upstream package id — three independent blockers [artifact] | P3 | D1–D3 done |
| Cloud sync / accounts / cross-device positions | Contradicts local-first promise before local experience is solid | P2 | Post-D, if ever, opt-in E2EE only |
| AI summarization / chat-with-PDF | Requires off-device processing or large local models; trend-driven, not job-driven | P2/P4 | On-device NPU inference matures |
| Bundled voice models / vendor TTS SDKs | System-TTS vendor neutrality is the right architecture [runtime: works] | P8 | Never, absent evidence |
| Native-Android PDF rewrite (drop Okular) | Destroys the format moat; violates AGENTS.md; no concrete limitation justifies it | P8 | A concrete, measured Okular limitation appears |
| New visual theme / rebrand pass | Fit-and-finish debt is in behavior (states, restore, a11y), not palette | P1/P3 | After B |
| Analytics SDKs | Privacy promise; beta feedback + opt-in crash reports suffice | P2 | Never as third-party; first-party opt-in in D4 |
| Feature-count parity with MX Player (network streams, codecs-style plugins) | The analogy is about coverage-without-configuration, not feature lists | P7 | — |
| OCR before continuous TTS | Inverts value: OCR's main consumer is narration | P4 | C1 shipped |
| Database-backed index today | No measured scan-time evidence yet; premature | P4 | C5 measurements demand it |

## Sequencing logic (why this order)

1. **Integrity before features** (A): every later claim inherits credibility from release discipline; the standing v0.3.1 identity defect poisons all other evidence [artifact].
2. **Retention before differentiation** (B before C): session restore, open-with, and search are why a user *keeps* the app; TTS continuity and OCR are why they *recommend* it. Retention failures make differentiation unmeasurable.
3. **Identity/distribution last-but-planned** (D1 before D2/D3): the rename is a breaking migration — do it exactly once, after the product stops changing shape weekly but before any wide distribution.
4. **Uncertainty is stated, not scheduled:** C1 (service+Qt interplay) and D3 (scoped-storage redesign) carry the highest technical risk; each gets a spike/experiment before commitment rather than a calendar date.
