# Fable prompt: Parthicle Reader head-to-toe review

Use this prompt in Claude Code with **Fable selected** and the highest practical effort level. The first pass is an audit and strategy exercise, not an implementation sprint.

```text
You are conducting a head-to-toe review of Parthicle Reader as a combined:

- software archaeologist,
- Android/Qt/KDE systems architect,
- product manager,
- usability and accessibility researcher,
- Apple-inspired interaction-design critic,
- open-source/licensing reviewer,
- QA lead,
- and Claude Code harness architect.

Your job is not to praise the project. Your job is to reconstruct what actually exists, test the claims, find what is weak or missing, explain what is currently being done, and propose a defensible long-horizon direction.

Repository:
parthganguly/okular-android-prototype

Product:
Parthicle Reader — a local-first Android document reader based on Okular/KDE, intended to become an “MX Player for reading files.”

Known stack:
- Okular document model and generators
- KDE Frameworks / Kirigami
- Qt 6 / QML / C++
- Android Java activity and services
- Java ↔ JNI/C++ ↔ QML bridge
- Android TextToSpeech
- Docker/KDE Craft Android build environment
- GitHub prototype releases
- GPL/LGPL/SPDX attribution obligations

## Non-negotiable operating rules

1. Start read-only.
2. Do not modify app source code.
3. Do not create, merge, close, or publish anything.
4. Do not change GitHub issues or releases.
5. You may write only review documents under `docs/reviews/`, `docs/strategy/`, `docs/design/`, `docs/architecture/`, or `docs/ai/`.
6. Do not claim runtime behavior unless you directly observed it on a named APK and device/emulator.
7. Do not claim a feature is supported merely because an extension or generator exists upstream.
8. Never treat a screenshot, static code path, successful compile, APK signature, and successful device workflow as equivalent evidence.
9. Protect user files. Any delete test must use a disposable file created specifically for QA.
10. Preserve licensing and attribution. This review must not recommend hiding the Okular/KDE foundation.
11. Use a separate worktree or clean branch if you need to write the review documents.
12. Stop and report if repository state is dirty or ambiguous.

## Evidence discipline

Label every important finding with one of these evidence classes:

- **[runtime]** directly reproduced on a named device/emulator and exact APK
- **[artifact]** inspected in the built APK/AAB or release asset
- **[build]** observed in a real build/test command
- **[static]** derived from source/configuration inspection
- **[history]** derived from Git history, PRs, releases, issues, or commit messages
- **[research]** supported by external primary/official or peer-reviewed evidence
- **[inference]** reasoned conclusion that has not yet been directly tested
- **[opinion]** product/design judgment, clearly marked as such

Use this evidence hierarchy when confidence conflicts:

1. reproducible runtime observation,
2. deterministic test/build evidence,
3. artifact inspection,
4. source inspection,
5. official platform documentation,
6. peer-reviewed or systematic research,
7. established usability heuristics,
8. subjective design opinion.

Never present Apple guidance, Nielsen-style heuristics, or visual taste as laboratory proof. Label principles and heuristics honestly.

For each major recommendation include:

- evidence class,
- confidence: high / medium / low,
- user impact,
- engineering impact,
- likely files or systems touched,
- validation method,
- and what would falsify the recommendation.

## Required source hierarchy

Prefer current primary sources and cite them in the report:

### Apple design principles
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Apple UI Design Dos and Don’ts: https://developer.apple.com/design/tips/
- Relevant Apple Developer design/WWDC material when directly applicable

Use Apple as a **design philosophy**, not as a visual skin. Extract principles such as:

- clarity,
- content-first hierarchy,
- restraint,
- consistency,
- direct manipulation,
- immediate and legible feedback,
- progressive disclosure,
- forgiving actions,
- coherent motion,
- typography and spacing discipline,
- and obsessive fit-and-finish.

Do not blindly copy iOS components into Android. Parthicle must still obey Android navigation, lifecycle, permissions, accessibility, and interaction conventions.

### Android quality and accessibility
- Android core app quality: https://developer.android.com/docs/quality-guidelines/core-app-quality
- Android accessibility: https://developer.android.com/guide/topics/ui/accessibility/apps
- Relevant Android storage, lifecycle, intent, TTS, and adaptive-layout documentation

### Accessibility standards
- WCAG 2.2: https://www.w3.org/TR/WCAG22/

Use WCAG as a useful cross-platform reference, not as a claim that a native Android app formally conforms without an appropriate audit.

### Claude Code harness
- Skills: https://code.claude.com/docs/en/skills
- Subagents: https://code.claude.com/docs/en/sub-agents
- Hooks: https://code.claude.com/docs/en/hooks
- Memory / CLAUDE.md: https://code.claude.com/docs/en/memory
- MCP: https://code.claude.com/docs/en/mcp

### Upstream project sources
- Okular/KDE upstream docs and source
- Kirigami and Qt documentation
- Existing repository attribution and licensing files

### Research
Use peer-reviewed studies, systematic reviews, standards, or controlled experiments when available. Avoid unsupported blog claims. If only expert heuristics exist, say so.

## Phase 0 — Establish the exact review baseline

Record:

- review date,
- branch,
- full commit SHA,
- clean/dirty state,
- latest GitHub tag and release,
- latest built APK path and embedded versionName/versionCode,
- package ID,
- device/emulator model and Android version if connected,
- available build/test tools,
- unavailable optional tools,
- and whether GitHub issue/release state is accessible.

Inspect the current release blocker and do not confuse a filename with embedded Android version identity.

## Phase 1 — Reconstruct the project from beginning to now

Read and correlate:

- `README.md`
- `ATTRIBUTION.md`
- `AGENTS.md`
- `CLAUDE.md`
- `docs/ai-agent-harness.md`
- `docs/release-checklist.md`
- `docs/build/android-kde-docker-notes.md`
- all files under `docs/qa/`
- all existing Claude skills, subagents, and hooks
- release tags and release notes
- Git log and important commits
- merged PRs
- open and closed issues
- duplicate or superseded issues

Produce a factual project timeline showing:

- what was inherited from Okular,
- what Parthicle changed,
- what was merely rebranded,
- what was genuinely added,
- what was runtime-verified,
- what was only statically verified,
- and what remains unfinished.

Explicitly separate:

1. upstream Okular/KDE capability,
2. Parthicle Android integration,
3. Parthicle product/UI work,
4. build/release infrastructure,
5. AI-agent harness work,
6. claims that are still aspirational.

## Phase 2 — Build a current architecture map

Trace and document:

- user workflow: launch → permission → library scan → search/browse → open → read → navigate → TTS → share/delete → return
- QML screen/component structure
- Java ↔ JNI/C++ ↔ QML bridge contracts
- Android activity lifecycle and intent handling
- document open/reload/close/delete flow
- library scanning and recents identity model
- document generator/format path
- TTS initialization, discovery, voice selection, chunking, progress, stop/shutdown, and fallback
- storage permission and filesystem access model
- build pipeline from source to APK
- packaging metadata and known Android SDK/NDK/KIO hazards
- release pipeline and evidence gates
- licensing and attribution surfaces

Create at least:

1. a component diagram,
2. a runtime sequence diagram for opening a document,
3. a runtime sequence diagram for TTS,
4. a build/release pipeline diagram,
5. a table of architectural boundaries and ownership.

Use Mermaid in Markdown where useful.

For each boundary assess:

- coupling,
- lifecycle risk,
- error propagation,
- thread affinity,
- testability,
- observability,
- and likely failure modes.

## Phase 3 — Claim-versus-reality audit

Extract every user-facing claim from README, release notes, screenshots, issue descriptions, and app copy.

Create a matrix:

| Claim | Source | Actual evidence | Status | Confidence | Required next test |

Statuses:

- verified,
- partially verified,
- misleading,
- unverified,
- false,
- obsolete.

Audit at least:

- “local-first”
- “MX Player for reading files”
- supported formats
- searchable local library
- recent files
- Open with / ACTION_VIEW
- share and delete
- bookmarks and navigation
- current-page TTS
- engine and voice selection
- offline behavior
- scanned/image-only limitations
- Markdown behavior
- package identity
- prototype release identity
- accessibility claims, if any
- privacy claims, if any

Challenge the “MX Player” comparison. Define the minimum capabilities required before that phrase is credible.

## Phase 4 — Test the product from head to toe

First run the existing harness:

- `scripts/verify-bridge.ps1`
- `scripts/verify-license.ps1`
- `scripts/verify-apk.ps1` on the exact artifact if present
- `git diff --check`

Use Windows PowerShell 5.1-safe commands on this machine unless a Linux/Docker command is explicitly required.

If Claude Code supports `/run`, `/verify`, and `/run-skill-generator`, assess whether a project-specific run recipe should be generated for Parthicle’s nonstandard Docker/Craft/ADB workflow. Do not create it during the audit unless explicitly approved.

If a device is connected, run a safe device audit against the exact APK. Cover:

### Installation and identity
- fresh install
- upgrade/install-over behavior
- launcher label/icon
- embedded versionName/versionCode
- package ID
- debug signing warning

### First run and permissions
- permission explanation
- denial path
- retry path
- manual folder picker
- all-files access implications
- empty storage
- slow/large storage

### Library
- scan progress
- empty/loading/error states
- category tabs
- search and IME composition
- sort/filter expectations
- folders and breadcrumbs
- recents deduplication
- stale/deleted items
- thumbnail behavior
- very long filenames
- RTL/non-Latin filenames if feasible

### Reader
- PDF with extractable text
- TXT
- Markdown
- image-only/scanned PDF
- image
- EPUB/comic/DjVu/XPS/TIFF only if a safe fixture and generator are actually available
- cold and hot ACTION_VIEW
- reader controls discoverability
- page navigation
- bookmarks
- rotation
- background/resume
- process death/session restore
- dark/light mode
- large file and malformed file handling

### TTS
- panel open/close
- default engine
- inaccessible/private engine
- Google fallback
- voice selection
- speed control
- Play/Stop
- no-text page
- page change while speaking
- orientation change
- background/lock behavior
- interruption by another audio app
- cleanup on app close

### Destructive actions
- delete only a disposable QA file
- confirmation clarity
- cancellation
- success feedback
- return-to-library behavior
- stale recents cleanup

### Accessibility
- TalkBack labels/order
- touch targets
- font scaling
- contrast
- color independence
- focus visibility
- orientation parity
- one-handed reachability
- reduced-motion considerations

Capture:

- commands,
- exact outputs,
- screenshots,
- logcat excerpts,
- timings where useful,
- and failed/unavailable tests.

Do not turn missing evidence into a pass.

## Phase 5 — Product and jobs-to-be-done review

Identify the most important user jobs. At minimum test these hypotheses:

1. “Open almost any reading file without thinking about format.”
2. “Find a local document quickly.”
3. “Resume where I stopped.”
4. “Read comfortably with minimal interface chrome.”
5. “Listen to a document without configuring a cloud service.”
6. “Trust that files remain private and actions are predictable.”

For each job, document:

- target user,
- current workflow,
- friction,
- failure points,
- missing state/feedback,
- competing alternatives,
- and what success would measurably look like.

Do not invent market demand. Separate observed user value from product aspiration.

## Phase 6 — Apple-inspired design audit, adapted correctly for Android

Review screenshots, QML, and runtime behavior.

Use Apple’s philosophy as an evaluative lens, not a theme pack. Judge whether the product exhibits:

### Clarity
- Is the primary action obvious?
- Are labels plain and specific?
- Are states visible rather than hidden?
- Are icons understandable without memorization?
- Is error copy actionable?

### Deference to content
- Does the document remain visually dominant?
- Does chrome disappear at the right time without becoming undiscoverable?
- Are decoration and gradients subordinate to reading?

### Hierarchy
- Does visual weight match task importance?
- Is the first-run path obvious?
- Are primary, secondary, and destructive actions distinct?

### Consistency
- Are library, reader, TTS, dialogs, and system bars one coherent product?
- Do identical controls behave identically?
- Does the app respect Android back, intent, permission, and lifecycle expectations?

### Direct manipulation and feedback
- Does every tap have immediate visible response?
- Are loading, scanning, speaking, deleting, and opening states observable?
- Can users reverse or safely cancel risky actions?

### Restraint and progressive disclosure
- Are advanced controls hidden until needed without becoming impossible to find?
- Is the reader toolbar too dense?
- Is the TTS panel exposing engine internals before users need them?

### Fit and finish
- spacing rhythm
- alignment
- typography
- truncation
- touch targets
- contrast
- icon consistency
- motion
- landscape behavior
- system-bar integration
- empty/loading/error states

Important Android adaptation:

- use at least 48dp effective touch targets for custom Android controls,
- preserve standard Android back/gesture behavior,
- preserve state across backgrounding and rotation,
- support adaptive layouts,
- and avoid copying iOS navigation patterns that conflict with Android conventions.

Produce a design scorecard, but avoid false precision. Use qualitative grades with evidence instead of arbitrary decimal scores.

For every design flaw provide:

- screenshot/runtime evidence,
- violated principle,
- user consequence,
- minimal correction,
- ideal correction,
- and acceptance test.

## Phase 7 — Accessibility and inclusive-design review

Audit against relevant Android guidance, Apple accessibility principles, and WCAG concepts.

At minimum assess:

- semantic labels and roles,
- TalkBack order,
- target size,
- contrast,
- font scaling,
- orientation,
- non-color cues,
- focus order,
- motion sensitivity,
- error identification,
- clear destructive confirmations,
- audio/TTS controls,
- multilingual filenames and UI strings.

Distinguish:

- verified accessibility behavior,
- static likely behavior,
- and untested requirements.

Produce an accessibility test matrix and prioritized backlog.

## Phase 8 — Technical architecture and quality review

Assess:

- whether Qt/Kirigami remains the right shell
- whether the Java/C++/QML boundary is maintainable
- whether any bridge is doing too much
- whether Android lifecycle and intent behavior are robust
- whether library scanning will scale
- whether a database-backed incremental index is justified
- whether document identity/recents need normalization
- whether session restore and real reading progress have a coherent model
- whether TTS should remain page-scoped or evolve into document narration
- whether OCR belongs in-process, as an Android service, or as an optional module
- whether package rename should happen before wider testing
- whether MANAGE_EXTERNAL_STORAGE is acceptable for the intended distribution path
- whether debug-signing and release discipline are adequate
- whether build reproduction is realistic for another developer
- whether CI is possible with current dependencies
- whether a rewrite is justified

Do not recommend a rewrite merely because another stack is fashionable. Any rewrite proposal must include:

- concrete current limitation,
- migration cost,
- compatibility risk,
- licensing implications,
- feature parity risk,
- and a staged alternative.

## Phase 9 — Security, privacy, and licensing review

Assess:

- filesystem permissions
- external intents
- URI/file handling
- exported activity surface
- delete behavior
- TTS vendor interaction
- network permission and actual network use
- secrets and keystores
- artifact signing
- prompt-injection exposure in agent tooling
- untrusted MCP/server risk
- GitHub/release permissions
- SPDX and attribution correctness
- whether screenshots, docs, and app copy overclaim ownership

State clearly what is engineering guidance versus legal advice.

## Phase 10 — Claude Code harness review

Inspect:

- `AGENTS.md`
- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/agents/**`
- `.claude/skills/**`
- `.claude/hooks/**`
- `scripts/verify-*.ps1`
- `justfile`
- `repomix.parthicle.json`
- any `.mcp.json`
- GitHub issue/PR workflow

Evaluate whether the harness uses the correct mechanism for each need:

- enduring facts → `CLAUDE.md` / imported `AGENTS.md`
- multi-step procedure → skill
- high-volume specialized investigation → subagent
- enforced denial/gate → hook or permission rule
- external system access → trusted MCP
- repeatable deterministic evidence → script/test

Explicitly check whether `CLAUDE.md` truly imports `AGENTS.md` using `@AGENTS.md`; merely saying “follow AGENTS.md” is weaker than an actual import.

Assess the existing skills for:

- triggering description quality,
- scope,
- permitted tools,
- model invocation control,
- forked context suitability,
- dynamic context injection,
- Windows PowerShell compatibility,
- evidence output,
- and accidental overlap.

Assess whether Parthicle should add or revise these skills:

1. `/parthicle-full-review`
2. `/parthicle-design-audit`
3. `/parthicle-accessibility-audit`
4. `/parthicle-runtime-regression`
5. `/parthicle-product-roadmap`
6. `/parthicle-architecture-map`
7. `/parthicle-issue-hygiene`
8. `/parthicle-release-identity`
9. a generated `/run-parthicle-reader` recipe using `/run-skill-generator`
10. a focused `/verify-parthicle-reader` workflow

Assess whether these subagents are justified:

- `parthicle-product-design-reviewer`
- `parthicle-android-quality-reviewer`
- `parthicle-architecture-reviewer`
- `parthicle-evidence-auditor`
- `parthicle-issue-curator`

Do not create agents merely to increase agent count. Every proposed agent must have:

- a non-overlapping responsibility,
- a reason to isolate context,
- explicit tools,
- explicit denied tools,
- expected input,
- expected output,
- and invocation criteria.

Review hooks and propose only targeted additions, such as:

- warn or block direct app-source edits on `main`
- block release creation if embedded version identity and tag disagree
- block unsupported “verified” claims without an evidence marker
- run lightweight focused checks after bridge/QML/manifest edits
- never trigger a full Android build after every edit

MCP policy:

- prefer the trusted GitHub connector when it removes copy/paste work,
- keep active MCP surface minimal,
- do not recommend random community MCP servers,
- document prompt-injection and credential risk,
- use read-only scopes where possible.

Worktree policy:

- review, implementation, and release preparation should not share a dirty working tree,
- high-risk agents should use isolated worktrees,
- no agent should silently merge or publish.

Produce a Harness v2 proposal with exact recommended paths and complete draft frontmatter/content for every proposed skill or agent. Do not install or commit them during this audit.

## Phase 11 — Project-management and issue hygiene

Audit open/closed issues for:

- duplicates,
- obsolete reports,
- fixed-but-open issues,
- acceptance criteria quality,
- missing priorities,
- missing release milestones,
- and mismatch between issue state and main branch.

Create a proposed issue map:

- close as completed,
- close as duplicate,
- keep open,
- split,
- merge,
- defer.

Do not actually change issues without approval.

## Phase 12 — Long-horizon product strategy

Create a roadmap in horizons rather than a feature dump.

### Horizon A — Release integrity and reliability: now to 4 weeks
Focus on:

- correct v0.3.1 identity
- exact artifact smoke test
- unresolved P0/P1 regressions
- issue cleanup
- reproducible build notes
- release evidence

### Horizon B — Core reader credibility: 1 to 3 months
Evaluate:

- stable Open with
- session restore
- real reading progress
- recents normalization
- search/sort/filter
- bookmarks/navigation
- robust error/loading/empty states
- accessibility baseline
- device/form-factor matrix

### Horizon C — Product differentiation: 3 to 9 months
Evaluate:

- TTS page auto-advance and reliable narration
- optional OCR for scanned pages
- annotations and highlights
- richer format test coverage
- incremental indexing
- privacy and offline guarantees
- signed beta distribution

### Horizon D — Production and scale: 9 to 24 months
Evaluate:

- package rename and migration
- Play Store or alternative distribution readiness
- scoped-storage strategy
- production signing and update path
- crash reporting with privacy controls
- CI/reproducible builds
- localization
- tablet/foldable experience
- contribution/upstream strategy
- whether selected changes should be upstreamed to Okular/KDE

For every roadmap item provide:

- user problem,
- evidence,
- dependency,
- engineering risk,
- success metric,
- rejection criterion,
- and what should be delayed or explicitly not built.

Avoid calendar certainty when effort is unknown. Use sequencing and dependency reasoning instead of pretending to know exact dates.

## Phase 13 — North-star product principles

Propose 5–8 durable principles for Parthicle Reader. They must be specific enough to reject bad features.

Candidate themes to evaluate:

- content before chrome
- open locally, work offline
- predictable file behavior
- broad format support with honest claims
- one obvious path for common actions
- advanced controls on demand
- no fabricated state or progress
- accessibility as a quality gate
- preserve upstream strength instead of rewriting it
- evidence before release claims

Create an “anti-roadmap”: attractive ideas that should not be built yet and why.

## Required deliverables

Write these files only:

1. `docs/reviews/parthicle-head-to-toe-review-YYYY-MM-DD.md`
2. `docs/architecture/parthicle-current-state.md`
3. `docs/design/parthicle-design-principles.md`
4. `docs/strategy/parthicle-long-horizon-roadmap.md`
5. `docs/ai/parthicle-harness-v2-plan.md`

The main review must include:

- executive verdict
- what has been done
- what is currently being done
- what the app genuinely does today
- what it only appears to do
- architecture assessment
- claim matrix
- test matrix
- product/job analysis
- Apple-inspired design audit
- Android-quality audit
- accessibility audit
- security/privacy/licensing audit
- build/release audit
- AI-agent harness audit
- issue hygiene map
- immediate priorities
- long-horizon roadmap
- anti-roadmap
- source bibliography
- uncertainty register

Use tables where they improve comparison, not everywhere.

## Final executive questions

Answer these directly:

1. What exactly is Parthicle Reader today?
2. What important work has actually been completed?
3. What is currently underway or blocked?
4. Does the product broadly do what it says?
5. Which claims remain weak or misleading?
6. What are the five biggest user-facing problems?
7. What are the five biggest architectural risks?
8. Is the current visual design coherent and user-friendly?
9. Does it embody Apple’s design philosophy without becoming an inappropriate iOS imitation?
10. Is it a credible Android prototype, private beta, public beta, or production app?
11. What should be done next?
12. What should explicitly not be done next?
13. What should the project become over the next 1–2 years?
14. Which Claude Code skills, subagents, hooks, scripts, and MCP connections would materially improve development?
15. What evidence would change your conclusions?

Be direct. Do not flatter the owner. Do not punish the project for being a prototype, but do not excuse defects merely because it is one.
```

## Short invocation

After this file is present in the repository, the audit can be started in Claude Code with:

```text
Read docs/reviews/fable-head-to-toe-project-review-prompt.md and execute it exactly. Start read-only, use Fable at high effort, and do not modify app source or GitHub state.
```
