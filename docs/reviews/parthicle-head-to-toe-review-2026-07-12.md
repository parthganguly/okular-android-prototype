# Parthicle Reader — head-to-toe project review

Date: 2026-07-12 · Reviewer: Claude (Fable 5) via Claude Code, executing `docs/reviews/fable-head-to-toe-project-review-prompt.md` and `/parthicle-full-review`, with the `parthicle-architecture-reviewer` and `parthicle-product-design-reviewer` subagents.

## Phase 0 — Review baseline

| Item | Value |
| --- | --- |
| Review date | 2026-07-12 |
| Branch | `review/head-to-toe-2026-07-12` (created from `github/harness/fable-full-project-review`, content-identical to GitHub `main` at `a5f11dbf5e3c350104b10b53d74dee7342b051f0` — verified by empty `git diff --stat`) |
| Local `main` at start | `89c003ae70a5ebbbc422cda4938dad37d0abb201`, clean (had not pulled PR #22) |
| Worktree state | Clean [build: `git status --porcelain` empty]; `git diff --check` clean |
| Latest tag / release | `v0.3.0-prototype` — GitHub pre-release, assets: APK + screenshot (note: **no `.sha256` sidecar asset was uploaded**; digest is in the notes only) [history] |
| Latest built APK | `..\artifacts\parthicle-reader-v0.3.1-debug.apk`, 87,365,346 bytes, SHA-256 `3FCB986A74CD3AE41D19F5195B1CA74BCCC432CDEA7B46375A1DD98F9E6CF795` [build] |
| Embedded identity of that APK | **versionName 0.3.0, versionCode 10** — mismatched with its filename; package `org.kde.okular.kirigami`, label "Parthicle Reader", minSdk 21, targetSdk 35, arm64-v8a, debug-signed (`CN=Android Debug`, apksigner verifies) [artifact] |
| Repo manifest | still `versionName="0.3.0" versionCode="10"` — release blocker issue #21 open [static] |
| Device/emulator | **None connected** (`adb devices` empty). No runtime testing was possible in this review; the only runtime evidence is `docs/qa/parthicle-qa-audit-2026-07-05.md` (v0.3.0 APK on Samsung SM-M356B, Android 16) |
| Tools available | powershell.exe 5.1, git, gh (authenticated), docker client, java, aapt2/apksigner at `C:\ansdk\build-tools\36.0.0\` |
| Tools unavailable | `pwsh` (PowerShell 7), adb device, build container (not running), `reuse`, apkanalyzer |
| GitHub state | Accessible read-only: 4 merged PRs, 19 issues (11 open) |

**Evidence classes used throughout:** [runtime] (2026-07-05 QA device audit only) · [artifact] · [build] · [static] · [history] · [research] · [inference] · [opinion].

---

## Executive verdict

**Parthicle Reader is a genuinely working, honestly documented, single-device-verified Android prototype whose product core (library scan → open PDF/TXT → listen to a page) has been proven on real hardware — and whose four most serious runtime bugs have plausible fixes merged but zero device verification, sitting behind a release that cannot ship because the artifact lies about its own version.**

The project's greatest strengths are unusual for a prototype: evidence discipline (a QA culture that distinguishes device truth from static hope), release hygiene (SHA-256, pre-release labeling, KDE disclaimers), and a well-matched AI-agent harness. Its greatest weaknesses are: the app **cannot resume where you stopped** (the single most expected reader behavior); its format claims exceed the shipped artifact (EPUB and DjVu generators are **absent from the APK** despite the README [artifact]); accessibility is effectively unaddressed (zero `Accessible.*` properties in the QML tree [static]); and everything merged since 2026-07-06 is unverified on any device.

It is a **credible early prototype approaching private-beta readiness** — not a public beta, not production. The distance to "private beta" is short and concrete: ship v0.3.1 with correct identity, device-verify the four QA fixes, and correct the format claims.

---

## Phase 1 — What has been done (project reconstruction)

### Timeline [history]

| Period | Work | Evidence |
| --- | --- | --- |
| ≤2026-04 | Upstream KDE Okular master (full history, ~26 years incl. KPDF era) | git log |
| ~2026-04/05 | `2be2bc257` "Prototype Android reader workflow" — the Parthicle fork point; then ~17 commits of Android reader iteration: library home UI, toolbar, recents/search/thumbnails, safe-area/back-navigation, edge-rendering fixes | first-parent log |
| 2026-05-22 | v0.1.0-prototype release ("Okular Android Prototype") | releases |
| 2026-05-22/23 | `b1877fbe7` "Rebrand Android prototype as Parthicle Reader"; v0.2.0-prototype | releases, log |
| 2026-07-04 | PR #1 "Add Android system TTS MVP" → v0.3.0-prototype pre-release | PR list, release |
| 2026-07-05 | PR #2 AI agent harness (AGENTS.md, CLAUDE.md, skills, agents, hooks, verify scripts); Fable QA audit prompt + **on-device QA audit** (the [runtime] source of record) | log, docs/qa/ |
| 2026-07-06 | PR #20 "Fix v0.3.1 runtime QA issues" (`6003384e6`): singleTask + queued openUri + openRequestedUri (hot ACTION_VIEW); delete → returnToLibrary + UI-thread toasts; TTS discovery decoupled from locks onto an executor with cached JSON (freeze mitigation); fake 44% progress bar removed; README Markdown claim corrected | PR #20 diff [static] |
| 2026-07-11 | v0.3.1 APK built — but from a tree whose manifest still says 0.3.0/10 → issue #21 release blocker | [artifact], issue #21 |
| 2026-07-12 | PR #22 full-review harness (prompt, `/parthicle-full-review` skill, two reviewer agents) merged to `main`; this review | PR #22, this document |

### Separation of what exists

1. **Upstream Okular/KDE capability (inherited):** the entire document model, rendering, generators, bookmarks/TOC/thumbnails plumbing, `mobile/components/` scaffolding, translations, licensing infrastructure. This is the overwhelming majority of code by volume.
2. **Parthicle Android integration (genuinely added):** `OpenFileActivity` library scanner/recents/intents/insets/share/delete (~1,800 lines), `ParthicleTtsController` (~700 lines), JNI bridge extensions (23 invokables), `documentitem` text-for-page TTS plumbing, edge-rendering and back-navigation fixes to `DocumentView.qml`.
3. **Parthicle product/UI work (genuinely added):** `WelcomeView.qml` library/home (870 lines), `MainView.qml` reader chrome + Listen panel (1,049 lines), branding/icon.
4. **Rebranded only:** app label/icon, README header; package ID, Java package (`org.kde.something`), and QML module names remain upstream [static][artifact].
5. **Build/release infrastructure:** hand-built Docker/Craft container (not in repo), verify scripts, release checklist, hooks — real but not reproducible by a second person [static].
6. **AI harness work:** AGENTS/CLAUDE routing, 6 skills, 6 agents, 3 hooks, repomix config, justfile — assessed in the harness audit below and in `docs/ai/parthicle-harness-v2-plan.md`.
7. **Runtime-verified (v0.3.0 only):** launch/scan/search/recents/thumbnails; PDF+TXT open; Markdown-as-raw-text; toolbar chrome; TTS Play/Stop/speed via Google TTS; no-text warning; delete confirmation; back navigation; rotation-during-TTS survival [runtime].
8. **Statically verified only:** all PR #20 fixes; SAF folder picker; bookmarks persistence; multi-page navigation UI; EPUB/comic/DjVu/XPS/TIFF opening (and see the claim matrix — two of those generators aren't in the APK at all).
9. **Unfinished/aspirational:** session restore, reading progress, sort, TTS continuity (pause/auto-advance/background), OCR, package rename, signed distribution, accessibility, CI.

### What is currently being done / blocked

- **Blocked:** v0.3.1 release — blocked on manifest identity bump + rebuild + device smoke test (issue #21). No device is currently connected; the exact v0.3.1 artifact was never device-tested [history][build].
- **Open engineering:** issues #3 (verify-apk tool discovery), #7 (recents dedup — real, unfixed [static]), #13/#14/#16 duplicates of already-merged fixes pending device verification, #18/#19 TTS-panel/search P2s (unfixed [static]).
- **Just landed:** the full-review harness (PR #22) — this document is its first execution.

---

## Phase 3 — Claim-versus-reality matrix

| Claim | Source | Actual evidence | Status | Confidence | Required next test |
| --- | --- | --- | --- | --- | --- |
| "Local-first" | README:3 | No network dependency observed [runtime]; but manifest requests `INTERNET` (unused [static]) and artifact adds `POST_NOTIFICATIONS` [artifact] | **Partially verified** — behavior yes, permission surface contradicts wording | High | Remove/justify INTERNET; explain merged POST_NOTIFICATIONS |
| "MX Player for reading files" | README:3 | Library UX imitates the pattern [runtime]; resume, reliable open-with, sort, background listening — all absent or unverified | **Aspirational / partially misleading** | High | Define the minimum bar (see below) and gate the phrase on it |
| Opens PDFs | README:5 | Text + image-only PDFs rendered on device [runtime] | **Verified** (v0.3.0) | High | Re-verify on v0.3.1 artifact |
| Opens TXT | README:5 | [runtime] | **Verified** | High | — |
| Markdown opens as readable raw text; rich rendering not active | README:5 (post-PR-20 wording) | Raw-text behavior confirmed [runtime]; no markdown generator in APK [artifact] | **Verified** (wording now honest; v0.3.0 release notes' "Markdown opening: passed" remains misleading in the historical record [history]) | High | Ship Discount-based generator or keep wording |
| Opens EPUBs | README:5 | **No epub generator library in v0.3.1 APK** [artifact: no `okularGenerator_epub` in `lib/arm64-v8a/`, only translation .mo files] | **False for shipped artifacts** | High | Package the generator + device-open a fixture, or remove claim |
| Opens DjVu | README:5 | **No djvu generator in APK** [artifact] | **False for shipped artifacts** | High | Same |
| Opens comics / XPS / TIFF / images | README:5 | comicbook, xps, kimgio, fb, mobi, dvi, fax, txt, poppler generators present [artifact]; none of these formats device-opened | **Unverified** (statically plausible) | Medium | Fixture-per-format device matrix |
| Searchable local library | screenshots/alt text | Search worked on device with an IME-composition defect [runtime]; defect unfixed [static] | **Verified with defect** | High | Retest after fix |
| Recent files | UI | Works with duplicates + stale entries [runtime]; dedup unfixed [static]; fake progress bar removed [static] | **Partially verified** | High | Dedup fix + device retest |
| "Open with" / ACTION_VIEW | intent filters | Cold works; hot silently failed [runtime]; three-part fix merged [static] | **Partially verified / fix unverified** | Medium | Hot+cold matrix on device |
| Share and delete | UI | Delete confirmed but stranded user on deleted doc [runtime]; fix merged [static]; share never completed on device; share path retains off-thread Toast bug [static] | **Partially verified** | Medium | Device retest both |
| Bookmarks & navigation | toolbar/menu | Untested on device (single-page fixtures) [runtime gap] | **Unverified** | — | Multi-page fixture test |
| Current-page TTS | README TTS section | Google TTS spoke page text; Play/Stop/speed verified [runtime]; one hard freeze on first session [runtime]; mitigation merged [static] | **Verified with serious defect; fix unverified** | Medium | 30-min soak, 2 sessions, Samsung device |
| Engine & voice selection | README | Engine picker hidden on single-engine device; Samsung TTS rejects app; voices listed, switching unexercised [runtime] | **Partially verified** | Medium | Multi-engine device test |
| Offline behavior | implied | All flows offline [runtime] | **Verified** (behaviorally) | Medium-high | Airplane-mode full pass |
| Scanned/image-only limitation + "OCR later" | README | Exact warning observed [runtime]; but panel claimed "Ready to read" first [runtime], status logic unfixed [static] | **Verified claim, misleading in-app state** | High | Panel-status fix + retest |
| Package remains `org.kde.okular.kirigami` (documented caveat) | README | [artifact][runtime] | **Verified** | High | — |
| Debug prototype, pre-release, SHA-256 published | release notes | Digest matches artifact [build vs release notes]; **however no `.sha256` asset uploaded to the release** and current v0.3.1 artifact identity is wrong [artifact] | **Verified for v0.3.0 with gaps; blocked for v0.3.1** | High | Fix identity; upload sidecar per checklist |
| Attribution/licensing retained | README/ATTRIBUTION | verify-license PASS [build]; SPDX intact; disclaimers present | **Verified** | High | Optional full `reuse lint` |
| Accessibility claims | — | None made | **N/A** (and none would survive: zero Accessible.* [static]) | — | TalkBack pass before any claim |
| Privacy claims | — | None made in-app; "local-first" carries implication | **Gap** — no privacy statement exists | — | One-paragraph in-app note |

**The "MX Player" bar.** For the comparison to be credible, minimum: (1) session restore + resume; (2) reliable default-app open-with, hot and cold; (3) recency sort; (4) background/screen-off listening with media controls; (5) format claims that match the artifact. Today 0 of 5 hold [runtime+artifact+static]. The phrase should be treated as an internal north star, not user-facing copy, until at least 1–3 hold. [opinion]

---

## Phase 4 — Test matrix (what this review could and could not run)

### Executed [build]

| Check | Result |
| --- | --- |
| `scripts/verify-bridge.ps1` | PASS — 22 JNI calls, 25 Java statics, 11 QML calls checked, TTS markers present ("device/runtime behavior not tested" honestly printed). Known gap: QML coverage is MainView-only [static] |
| `scripts/verify-license.ps1` | PASS — 12 license files, attribution present, no protected deletions, no SPDX removals |
| `scripts/verify-apk.ps1` on v0.3.1 APK | Structure PASS (ZIP, arm64-v8a, libc++_shared.so, SHA-256 `3FCB98…F795`); apksigner/apkanalyzer reported unavailable — **false negative**, tools exist at `C:\ansdk\build-tools\36.0.0` (issue #3 confirmed) |
| `apksigner verify --print-certs` (manual) | Verifies; `CN=Android Debug`, cert SHA-256 `50596bae…`; benign META-INF warnings |
| `aapt2 dump badging` (manual) | package `org.kde.okular.kirigami`, **versionCode 10 / versionName 0.3.0**, label "Parthicle Reader", minSdk 21 / targetSdk 35, permissions MANAGE_EXTERNAL_STORAGE, READ/WRITE_EXTERNAL_STORAGE, INTERNET, POST_NOTIFICATIONS |
| APK payload inspection | Generators present: poppler, txt, comicbook, xps, fb, mobi, dvi, fax, kimgio; **absent: epub, djvu, markdown, spectre, tiff-specific** (TIFF may route via qtiff/kimgio [inference]); 30+ image-format plugins present |
| `git diff --check` | Clean |

### Not executable in this review (no device, no container)

Fresh install/upgrade, first-run permission flows, library/reader/TTS runtime matrix, destructive-action retest, TalkBack/font-scale/contrast on device, process-death restore, hot ACTION_VIEW verification — i.e., **every row of the Phase 4 device matrix**. These are inherited from the 2026-07-05 QA audit for v0.3.0 and are **stale for current `main`**. A manual test matrix for the next device session is embedded in the QA report's 24 rows plus the harness-v2 `/parthicle-runtime-regression` skill (see `docs/ai/parthicle-harness-v2-plan.md` §2.3). Missing evidence is reported as missing, not as a pass.

---

## Phase 5 — Product and jobs-to-be-done review

Full analysis in the product/design deep-dive (§Phase 6 below summarizes design; the six job hypotheses were evaluated by the design subagent). Summary verdicts:

| Job | Verdict | Anchor evidence |
| --- | --- | --- |
| 1. Open almost any file without thinking about format | **Partially real.** PDF/TXT proven; hot open-with was broken (fix unverified); EPUB/DjVu claimed but not shipped | [runtime][artifact] |
| 2. Find a local document quickly | **Mostly real** with friction: no sort, raw-path subtitles, IME search defect | [runtime][static] |
| 3. Resume where I stopped | **Fails entirely** — no session restore, no reading position, recents duplicates; the largest gap vs every competitor (ReadEra, Librera, Moon+, MX Player itself) | [runtime][static] |
| 4. Read comfortably with minimal chrome | **Real at the core** (immersive + auto-hide worked) but chrome overlays first lines of content; compact toolbar hides title and headline actions | [runtime][artifact][static] |
| 5. Listen without configuring a cloud service | **Real as a demo** — vendor-neutral system TTS is genuinely differentiating; not yet a feature (no pause, no auto-advance, no background, freeze history) | [runtime] |
| 6. Trust privacy and predictability | **Half-earned:** offline behavior + honest release notes vs unused INTERNET permission, broadest storage grant, no privacy note, v0.3.0's two predictability breakers (fixes unverified) | [runtime][artifact][static] |

Observed value today = local library + PDF/TXT reading + one-page TTS. Everything else is aspiration; no market data exists in the repo and none was invented.

---

## Phase 6 — Apple-inspired design audit (Android-first)

The design subagent's scorecard (qualitative, evidence-anchored; full findings with minimal/ideal corrections and acceptance tests are in its report, incorporated here):

| Principle | Grade | Anchor |
| --- | --- | --- |
| Clarity | **Weak** | Glyph-only ‹ ⋮ ×; "Mark/Saved" vs "Bookmark"; "Nav"; MX-Player analogy inside a permission prompt; TTS "Ready to read" on unreadable pages [runtime][static] |
| Deference to content | **Weak-to-adequate** | Immersive reading right [runtime]; toolbar obscures first lines of the page [runtime + artifact: parthicle-reader-controls.png] |
| Hierarchy | **Adequate (library) / weak (first-run, reader)** | First-run primary action is a small ToolButton with 2-line elided rationale; Listen buried behind unlabeled overflow [static] |
| Consistency | **Weak** | Two design languages (custom cream library vs stock Kirigami drawer); terminology drift; hardcoded light library + dark reader ignores system dark mode [static] |
| Feedback / direct manipulation | **Adequate with failures** | Pinch/swipe/tap direct [runtime]; no pressed states on tabs/cards; scan state is text-only, no spinner [static]; v0.3.0 freeze + silent intent failure [runtime] |
| Restraint / progressive disclosure | **Adequate** | TTS engine/voice disclosure is exemplary [static]; but restraint hits the wrong targets — hides the document title and Listen, shows raw `/storage/emulated/0` paths [static][opinion] |
| Forgiveness | **Weak** | Irreversible delete, no undo; no session restore means accidental backgrounding destroys context [runtime][static] |
| Motion | **Weak** | Only page flips animate (250 ms); chrome/menus/panels pop instantly [static] |
| Typography/spacing | **Weak-to-adequate** | ~12 font sizes (9–26px) with arbitrary multipliers; 7 corner-radius idioms; sub-pixel spacing fractions; badge text at 9–10px [static] |
| Fit-and-finish | **Adequate for a prototype** | Careful insets, elision, honest progress hairline; dead code, fake "›" affordance, identical Allow/Folder icons [static] |

**Top design corrections (ordered by user impact):**
1. Inset or dim content under the toolbar — chrome must never cover the first paragraph (acceptance: page-1 first line legible with chrome visible).
2. Always show the elided document title; promote **Listen** to a first-class labeled toolbar action.
3. Fix TTS panel truthfulness: page-level no-text status inside the panel, fixed status-box height, scrollable panel content in landscape.
4. One vocabulary (Bookmark/Recent/Listen); real icons + labels for back/overflow; "Delete" (red) instead of "Yes".
5. Friendly location subtitles ("Download › Parthicle"); pressed states on tabs/cards; scan spinner.
6. Honor system dark mode with a curated dark library palette; keep the reader canvas.
7. 150–200 ms motion on chrome/panel/menu transitions.

**Apple-vs-Android conflicts resolved Android-first:** keep the floating auto-hide chrome (fix the overlay); make the TTS popup a bottom sheet (solves landscape too); register the back-callback only while a document is open and verify predictive back on Android 14+; system back must remain the source of truth (it currently works [runtime]).

---

## Phase 7 — Accessibility audit

**Headline: zero `Accessible.*` properties exist anywhere in the `mobile/` QML tree [static, grep-verified].** MouseArea-driven controls (category tabs, library rows, recent cards, page thumbnails, tap-to-toggle-chrome surface) present **no semantics to TalkBack at all** [inference, high confidence]; glyph-only buttons (⋮ ‹ ×) would announce as literal glyphs or nothing.

| Dimension | Status |
| --- | --- |
| TalkBack labels/order | Statically likely failing; untested (Qt a11y bridge quality unknown on this app) |
| Touch targets | Toolbar buttons 48–54dp **pass**; TTS speed chips ~34dp **fail**; category tabs ~40dp **fail**; page thumbnails ~45dp marginal [static, extracted constants] |
| Contrast (computed from source colors) | Muted text ≈4.9:1 pass; "Book" badge ≈3.6:1 **fail AA**; "Image" badge ≈4.3:1 marginal fail; white-on-photo recents titles unguaranteed [static] |
| Font scaling | At risk: hard px floors + fixed container heights (86/138/188/78/40/34) won't grow with text [static]; untested |
| Orientation | Landscape TTS overflow observed [runtime]; panel still unscrollable [static] |
| Non-color cues | Mostly good (bold+color tabs, text badges, icon+label bookmark) [static] |
| Destructive confirmation | Clear wording [runtime]; weak verbs (Yes/Cancel) [static] |
| Motion sensitivity | Little animation (benefit); fixed 3.6s auto-hide can't be extended [static] |
| RTL/multilingual | UTF-8-safe, ElideMiddle; RTL untested |

**Prioritized backlog:** P0 — `Accessible.role/name/onPressAction` on every interactive element + one real TalkBack validation pass; P0 — chips/tabs to ≥48dp effective targets. P1 — badge contrast, 1.3×/2.0× font-scale audit, scrollable TTS panel. P2 — destructive verb+tint, focus indicators, predictive back, RTL spot-check. Adopting principle P6 (accessibility as release gate — `docs/design/parthicle-design-principles.md`) makes this class of defect release-blocking.

No formal WCAG conformance is claimed or deniable without a device audit; the computed values above are engineering signals, not an audit result.

---

## Phase 2 & 8 — Architecture assessment

Full detail (component/sequence diagrams, boundary/risk table, 16 verdicts, corrections, uncertainty register) in `docs/architecture/parthicle-current-state.md`. Condensed verdicts:

- **Keep Qt/Kirigami + Okular** — the generator breadth is the moat; every verified failure was Parthicle-authored glue, not substrate. **Rewrite rejected** under the prompt's anti-rewrite rules. [opinion, high]
- **The bridge is maintainable but decaying:** three stringly-typed contracts (JNI descriptors, library JSON, TTS JSON), `URIHandler` god-interface (23 invokables), verify-bridge QML coverage gap (checks MainView only). [static, high]
- **`OpenFileActivity` is a god object (1,821 lines, ≥7 responsibilities).** Concrete residual defect from its size: share path still Toasts off-thread — thrown-and-swallowed at the JNI boundary, i.e. silent share feedback [static]. Decompose into LibraryRepository/RecentsStore/ThumbnailCache without bridge changes.
- **PR #20's fixes are the right mechanisms** (singleTask, queued openUri, close-then-open routing, executor-based TTS discovery, cached JSON) — **plausibility high, runtime confidence zero.** [static/inference]
- **Scaling cliff in library scanning:** full storage walk per resume; whole-library JSON through JNI; multi-MB SharedPreferences. Fine today; MediaStore query is the next step, DB only when progress/sort demand it.
- **Identity/recents need normalization now** (URI-string identity duplicates recents [runtime], unfixed [static]) — prerequisite for the missing session-restore model, which the code actively fights (`Main.qml:107` resets `currentPage=0`, defeating Okular's own docdata resume).
- **TTS: page-scoped → narration in three steps:** push channel (kills 400ms poll + Samsung logspam), auto-advance, foreground service + MediaSession (Android 16 mutes background audio [runtime]).
- **Thread-affinity policy drift:** PR #20 moved TTS discovery binder calls off the main thread — AGENTS.md gate #2 still says all engine calls belong on it. Reconcile the policy text before an agent "fixes" the code backwards. [static]
- **Build reproducibility: not realistic today** (no Dockerfile/pins in-repo). CI staged: verify-scripts CI now; nightly containerized build later; emulator smoke last.

**Five biggest architectural risks:** (1) unverified-fix debt — everything after 2026-07-06 is device-untested; (2) OpenFileActivity god object breeding thread-affinity bugs; (3) no session/identity model under recents, progress, bookmarks; (4) single hand-built build container = bus factor 1; (5) release identity not mechanically tied to artifacts (already burned once).

---

## Phase 9 — Security, privacy, licensing

*Engineering guidance, not legal advice.*

- **Permissions [artifact][static]:** `MANAGE_EXTERNAL_STORAGE` — acceptable for side-loaded prototype, Play-policy blocker later; `INTERNET` — requested, no usage found in app code [static grep]; remove or justify; `POST_NOTIFICATIONS` in artifact but not source manifest — manifest-merge injection [inference], explain before privacy claims.
- **Intent surface [static]:** one exported activity with broad VIEW/SEND MIME filters — appropriate for a reader; content-URI handling goes through fd resolution (`fd:///N?okularMimeType=…`), no path traversal found in review; `file://` share uses a StrictMode bypass — replace with FileProvider (code comment already admits it).
- **Delete behavior:** real filesystem deletion with confirmation [runtime]; no undo; recents entry removed [static].
- **Secrets/signing:** no keystores/tokens in repo [static]; debug cert only [artifact]; hooks block release deletion/force-push [static].
- **Agent-tooling exposure:** no MCP servers configured (good); hooks are guardrails not boundaries (documented honestly); prompt-injection surface = issue/release text read by agents — treat as data (noted in harness v2 plan).
- **Licensing [build][static]:** verify-license PASS; SPDX headers intact; GPL/LGPL texts retained; README/ATTRIBUTION/release notes carry the independence disclaimer. **One overclaim risk:** the shipped package ID `org.kde.okular.kirigami` itself implies KDE association to anyone inspecting the device — a rename argument beyond branding [opinion]. Screenshots and app copy do not overclaim ownership; the format list overclaims capability (see claim matrix).

---

## Build/release audit

- v0.3.0 release: honest wording, digest-in-notes matches artifact [build vs history]; **missing the `.sha256` sidecar asset** the checklist requires (assets: APK + screenshot only) [history].
- v0.3.1: **blocked and must stay blocked** — artifact embeds 0.3.0/10 [artifact]; manifest unbumped [static]; no device test of the exact artifact (issue #21 accurately states all of this — the project's own release discipline caught the problem; the harness now needs to make it mechanical).
- verify-apk tool-discovery bug (issue #3) confirmed live [build].
- Reproducibility: A6/D5 roadmap items; nothing in-repo builds the container.

---

## Phase 10 — AI-agent harness audit

Full inventory, gap analysis (G1–G7), and complete v2 proposal with draft skill/hook/agent content: `docs/ai/parthicle-harness-v2-plan.md`. Highlights:

- **v1 is genuinely good:** correct mechanism-to-need mapping (`@AGENTS.md` real import verified; procedures as skills; gates as hooks; deterministic evidence as scripts); hooks work; scripts pass and degrade honestly [build][static].
- **Confirmed gaps:** verify-apk discovery (G1); no mechanical artifact-identity↔tag gate (G2 — the live v0.3.1 failure); no runtime-regression skill (G7 — the 24-row device matrix lives only in a dated QA report); duplicate-issue hygiene absent (G4); verify-bridge QML coverage gap.
- **v2 in one line:** fix the two script gaps, add `/parthicle-runtime-regression` and `/parthicle-issue-hygiene`, add the release-identity gate + main-branch-edit warning hooks, amend the two reviewer agents with the runtime-evidence boundary, keep MCP at zero, stage CI from the static scripts up. Proposed-and-rejected: design/accessibility/roadmap as separate skills (overlap), evidence-auditor and issue-curator agents (wrong mechanism), a `/run-parthicle-reader` recipe (cannot run here — negative value until an emulator loop exists).

---

## Phase 11 — Issue hygiene map

19 issues total; the #4–#10 series was re-filed as #11–#19 (near-verbatim duplicates) [history]. Proposed map — **no issue was changed by this review**:

| Issue | Proposal | Rationale |
| --- | --- | --- |
| #3 verify-apk toolchain | **Keep open** | Confirmed live this review [build] |
| #4 (P0 TTS freeze, closed), #5 (P0 hot VIEW, closed), #6 (P1 delete return, closed), #8 (P1 fake progress, closed), #9 (P2 Markdown wording, closed) | **Keep closed, annotate** "fixed-on-main, device-verification pending (issue #21 smoke list)" | Closed on merge; fixes unverified [static] |
| #7 recents dedup (open) | **Keep open** — genuinely unfixed [static] | |
| #11, #12, #13, #14, #16, #17 | **Close as duplicates** of #19/#4/#5/#6/#8/#9 respectively — but first transfer any unique detail | One-to-one duplicate titles [history] |
| #15 dedup duplicate of #7 | **Close as duplicate of #7** | |
| #18 landscape TTS overflow, #19 IME search | **Keep open** (one each after dedup) — both unfixed [static] | |
| #21 release blocker | **Keep open, pinned** — the accurate gate for everything | |
| Missing | **File after approval:** share-path off-thread Toast; verify-bridge QML coverage; accessibility P0 (labels + 48dp); EPUB/DjVu claim-vs-artifact; `.sha256` asset absent from v0.3.0 release | Found by this review |

Also: duplicates #11–#19 carry no priority labels and no milestones; adopting the `/parthicle-issue-hygiene` skill (harness v2) prevents recurrence.

---

## Immediate priorities (next 4 weeks — Horizon A)

1. **Ship v0.3.1 correctly** (manifest 0.3.1/11 → rebuild → verify → device smoke → pre-release with `.sha256` asset). Everything else queues behind this.
2. **Device-verify the four QA fixes** on the Samsung device; reopen any that fail.
3. **Correct format claims** (EPUB/DjVu out of README or into the APK).
4. **Fix verify-apk discovery + add identity gate** (issues #3/#21 class, harness S1/S2).
5. **Issue dedup pass** (map above, after approval).
6. **Two-line fixes while there:** share-path `showToast`; verify-bridge QML list.

## Long-horizon roadmap and anti-roadmap

See `docs/strategy/parthicle-long-horizon-roadmap.md` for the full horizon plan (A: release integrity → B: core reader credibility [session restore, identity normalization, open-with reliability, sort, error states, accessibility baseline, EPUB decision] → C: differentiation [continuous TTS, OCR, annotations, format matrix, privacy hardening, signed beta] → D: production [package rename, distribution/scoped storage, CI, localization, tablets, upstreaming]) with per-item evidence, dependencies, success metrics, and rejection criteria — plus the anti-roadmap (no Play submission, no cloud/accounts/analytics, no AI summarization, no bundled voices, no native rewrite, no OCR before narration, no DB before measurement).

North-star principles: `docs/design/parthicle-design-principles.md` (P1 document-is-the-interface … P8 preserve-the-Okular-foundation).

---

## Final executive questions

1. **What exactly is Parthicle Reader today?** A debug-signed, single-ABI Android prototype: Okular's document engine wrapped in a custom Kirigami library/reader UI with a working page-level system-TTS panel — verified on exactly one device for v0.3.0, with four major fixes merged but unverified, and a release blocked on artifact identity. [runtime][artifact][static]
2. **What important work has actually been completed?** The Android reader workflow (library scan/search/recents/thumbnails, immersive reader, back navigation, edge rendering); the TTS MVP; the QA audit culture and its 24-row device matrix; the AI harness (skills/agents/hooks/scripts); three honest pre-releases. [runtime][history][build]
3. **What is currently underway or blocked?** v0.3.1 blocked on identity+device-smoke (issue #21); recents dedup, IME search, TTS-panel truthfulness/landscape still open; the full-review harness just landed (this is its first run). [history][static]
4. **Does the product broadly do what it says?** For its core loop, yes — proven on device. Its format list and MX-Player framing exceed the artifact. [runtime][artifact]
5. **Which claims remain weak or misleading?** EPUB/DjVu (false for shipped APKs); "MX Player for reading files" (0/5 minimum bar); "local-first" vs INTERNET permission; historical "Markdown opening: passed"; every post-2026-07-06 "fixed" (unverified). [artifact][static][history]
6. **Five biggest user-facing problems?** (1) No resume/session restore; (2) chrome covering page content + buried title/Listen; (3) unverified reliability of open-with/delete/TTS-freeze fixes; (4) accessibility (TalkBack effectively unsupported, sub-48dp targets); (5) library friction (no sort, raw paths, search defect, duplicate recents). [runtime][static]
7. **Five biggest architectural risks?** Unverified-fix debt; OpenFileActivity god object; missing identity/session model; irreproducible build (bus factor 1); manual release-identity coupling. [static][artifact]
8. **Is the visual design coherent and user-friendly?** Partially coherent (one palette, consistent library idiom) with real craft in insets/elision, but two design languages, ~12 font sizes, terminology drift, and weak feedback/motion. Friendly at the surface, unfriendly in states (loading/error/empty are text-only; failures often silent). [static][runtime][opinion]
9. **Does it embody Apple's philosophy without iOS imitation?** It has the instincts (deference, progressive disclosure in TTS, restraint) but misapplies them — hiding the title and headline feature while showing filesystem paths, and letting chrome cover content. No inappropriate iOS visual imitation; the ‹ chevron and Yes/Cancel dialogs are the closest misses. Android conventions (back, insets) are respected where tested. [runtime][static][opinion]
10. **Credibility level: prototype, private beta, public beta, production?** **Credible prototype; not yet private beta.** Private beta needs: v0.3.1 identity fixed, device-verified P0 fixes, honest format list. Public beta needs Horizon B (resume, reliability, accessibility baseline, signed builds). Production needs Horizon D. [synthesis]
11. **What should be done next?** The six immediate priorities above, in order — nothing else jumps the queue. [opinion]
12. **What should explicitly not be done next?** Play submission, package rename before beta users exist, OCR before continuous TTS, cloud/AI features, DB index before measurement, visual rebrand before behavioral debt, any new feature before v0.3.1 ships correctly. [opinion, anti-roadmap]
13. **What should it become over 1–2 years?** The trustworthy local-first reader for Android: resume-everywhere, honest broad format support, best-in-class offline narration (system TTS + optional OCR), scoped-storage-clean, F-Droid-distributed with reproducible builds — an app whose differentiators are privacy, honesty, and the Okular engine, not feature count. [opinion, roadmap]
14. **Which Claude Code investments would materially help?** In order: `/parthicle-runtime-regression`; the release-identity gate (script+hook); verify-apk discovery fix; `/parthicle-issue-hygiene`; verify-bridge QML coverage; reviewer-agent evidence-boundary amendments; static-scripts CI. Full drafts in the harness v2 plan. [static/build-grounded]
15. **What evidence would change these conclusions?** A device session: if the four PR #20 fixes verify cleanly, "unverified-fix debt" collapses and private beta is ~one release away; if the freeze recurs, the TTS architecture needs the push-channel redesign sooner. An APK from a fixed manifest proving generator packaging (EPUB present would flip that claim row). A 10k-file scan measurement (would confirm or retire the scaling-cliff risk). A TalkBack pass (would harden or soften the P0 accessibility finding). [falsifiability]

---

## Source bibliography

**Repository/primary:** README.md · ATTRIBUTION.md · AGENTS.md · CLAUDE.md · docs/ai-agent-harness.md · docs/release-checklist.md · docs/build/android-kde-docker-notes.md · docs/qa/fable-parthicle-audit-prompt.md · docs/qa/parthicle-qa-audit-2026-07-05.md (runtime evidence of record) · mobile/** source · scripts/verify-*.ps1 · .claude/** · git log/tags · GitHub PRs #1, #2, #20, #22; issues #3–#21; releases v0.1.0/v0.2.0/v0.3.0-prototype · artifacts/parthicle-reader-v0.3.1-debug.apk (aapt2/apksigner/ZIP inspection).
**External principle sources [research-informed, not laboratory proof]:** Apple Human Interface Guidelines (developer.apple.com/design/human-interface-guidelines) · Apple UI Design Dos and Don'ts (developer.apple.com/design/tips) · Android Core App Quality (developer.android.com/docs/quality-guidelines/core-app-quality) · Android accessibility (developer.android.com/guide/topics/ui/accessibility/apps) · WCAG 2.2 (w3.org/TR/WCAG22) — used for contrast formulas and target-size heuristics · Android TextToSpeech/foreground-service/MediaSession/scoped-storage documentation (developer.android.com) · Claude Code docs (code.claude.com/docs: skills, sub-agents, hooks, memory, MCP). Play-policy statements about MANAGE_EXTERNAL_STORAGE are cited as widely documented policy [research], not re-verified against today's policy text.

## Uncertainty register (consolidated)

1. **All post-PR-#20 runtime behavior** — the review's largest caveat; every "fix" is [static]/[inference].
2. **v0.3.1 APK code provenance** vs commit 6003384e6 (identity says 0.3.0).
3. **TalkBack reality** through the Qt-Android accessibility bridge (P0 finding is inferred).
4. **Font-scale/dark-mode/RTL/tablet rendering** — never run.
5. **EPUB/comics/XPS/TIFF/DVI opening** — generator presence ≠ opening (Markdown proved that).
6. **SAF folder-picker flow, share completion, bookmark persistence, multi-page navigation** — untested.
7. **Okular docdata persistence on Android** (session-restore plan assumes it).
8. **Freeze root cause** — behavioral evidence only, never stack-confirmed.
9. **Library scale limits** — no measurement beyond a small QA fixture set.
10. **POST_NOTIFICATIONS origin**; **predictive-back behavior**; **password-retry on fd URIs**; **KDE-style Craft CI feasibility** — all unconfirmed.
11. **gu (gridUnit) calibration** — dp arithmetic in the accessibility findings assumes gu ≈ 18–22; pass/fail conclusions survive the range due to hard px floors.

*This review modified no app source, no GitHub state, and no releases. Files written: the five deliverables under `docs/reviews|architecture|design|strategy|ai/`, on the review branch only.*
