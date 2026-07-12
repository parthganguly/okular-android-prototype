# Parthicle Reader — Claude Code harness v2 plan

Date: 2026-07-12 · Author: Claude (Fable 5) head-to-toe review · Status: proposal only — nothing in this plan has been installed or committed as active harness configuration.

Evidence classes used: **[static]** source/config inspection, **[build]** observed command runs, **[history]** git/GitHub history, **[runtime]** the 2026-07-05 device QA report, **[inference]** reasoned but untested, **[opinion]** judgment.

---

## 1. What the harness is today (v1 audit)

### 1.1 Inventory [static][build]

| Surface | State | Assessment |
| --- | --- | --- |
| `AGENTS.md` | Policy, repo map, six hard gates, build-diagnosis order | Strong. Concise, enforceable, correct altitude for enduring facts. |
| `CLAUDE.md` | Imports policy via a literal `@AGENTS.md` first line, then routing + hook doc | Correct mechanism — the import is real, not a "please follow" reference. Verified first line is `@AGENTS.md`. |
| `.claude/settings.json` | 3 PreToolUse hooks on Bash; license hook also on Edit/Write/MultiEdit/NotebookEdit | Wired correctly; see §1.3 for gaps. |
| `.claude/skills/` (6) | apk-verify, bridge-change, build-diagnose, context-pack, license-check, release | Good trigger descriptions, procedural, PowerShell-5.1-aware. `parthicle-release` is the best of the set (fixed sequence, stop-at-first-failure, explicit "never" list). |
| `.claude/agents/` (4 on `main`, 6 on the review-harness branch) | build-doctor, bridge-reviewer, license-cop, release-manager (+ product-design-reviewer, architecture-reviewer on `harness/fable-full-project-review`) | Clear non-overlapping charters, explicit tools. The two reviewer agents used by this review worked as designed. |
| `.claude/hooks/` (3) | block-dangerous-commands, block-license-removal, block-release-without-sha | Working POSIX sh; Python-based parsing with degradation when Python is absent. |
| `scripts/verify-*.ps1` | bridge PASS, license PASS [build] | Deterministic and honest about what they do not test. |
| `justfile` | verify/verify-apk/pack-context/semgrep/reuse recipes | Useful; optional tools degrade honestly. |
| `repomix.parthicle.json` | Focused include set; excludes secrets, APKs, keystores, Craft roots | Correct. |
| `.mcp.json` | none | Correct for current needs — no MCP surface, no injection risk from third-party servers. |

### 1.2 What v1 got right [opinion, informed by build/history evidence]

1. **Mechanism/need matching is mostly correct.** Enduring facts live in `AGENTS.md` (imported, not paraphrased), procedures in skills, gates in hooks, deterministic evidence in scripts. This is the textbook decomposition.
2. **Evidence discipline is embedded in the culture**, not just documents: release notes carry SHA-256; QA reports label evidence classes; scripts print "not checked (tool unavailable)" instead of passing silently.
3. **Hooks are proportionate.** They block catastrophes (force push, release deletion, license removal, checksum-free release) without trying to be a security boundary, and the docs say so explicitly.

### 1.3 Confirmed v1 gaps

| # | Gap | Evidence | Severity |
| --- | --- | --- | --- |
| G1 | `verify-apk.ps1` tool discovery misses `apksigner`/`aapt2` under `C:\ansdk\build-tools\36.0.0\` — script printed "Signature: not checked (apksigner unavailable)" while `apksigner.bat` verified the same APK seconds later when invoked directly | [build] this review, and issue #3 [history] | High — the release checklist depends on it |
| G2 | No check ties **embedded APK identity** (versionName/versionCode) to the release tag. Exactly this failure occurred: `parthicle-reader-v0.3.1-debug.apk` embeds 0.3.0/code 10 (issue #21) | [artifact][history] | High |
| G3 | Release-blocker state lives only in a GitHub issue; nothing in the harness stops a release skill run from picking the stale artifact | [static] | Medium |
| G4 | Duplicate GitHub issues (#11–#19 duplicate #4–#10 topics one-for-one) — the harness has no issue-hygiene procedure | [history] | Medium |
| G5 | The full-review prompt/skill/agents merged to `main` via PR #22 but the local `main` had not pulled them; the invoked files were missing at review start | [history] this session | Low (process) |
| G6 | Hooks depend on `python3`/`python` on PATH inside Git Bash; the grep fallback for the dangerous-command hook is weaker (e.g. misses `-fr` spelling) | [static] `.claude/hooks/block-dangerous-commands.sh:52` | Low |
| G7 | No runtime-regression checklist exists as a skill; the excellent 24-row device matrix lives only inside a dated QA report | [static] | Medium |

---

## 2. Harness v2 — proposed changes

Principle: **add nothing that does not close an observed failure.** Every proposal below cites the gap it closes. Items are ordered by value.

### 2.1 Script fixes (no new surface)

**S1. Fix `verify-apk.ps1` tool discovery (closes G1).** Search order: `ANDROID_HOME`/`ANDROID_SDK_ROOT` env vars → `C:\ansdk\build-tools\*\` (newest version first) → PATH. Print which path was used. Also emit embedded `versionName`/`versionCode`/package via `aapt2 dump badging` when available.

**S2. Add identity gate to `verify-apk.ps1` (closes G2):** new optional parameters `-ExpectedVersionName` and `-ExpectedPackage`; non-zero exit on mismatch. The release skill then passes the tag-derived version. This turns issue #21's failure mode into a deterministic FAIL.

### 2.2 Hook additions (targeted, per the review prompt's constraints)

**H1. Release identity hook (closes G2/G3).** Extend `block-release-without-sha.sh` (or add `block-release-identity-mismatch.sh`): when the command is `gh release create <tag> …`, require the environment marker `PARTHICLE_RELEASE_IDENTITY_VERIFIED=1`, which only the release skill instructs setting after `verify-apk.ps1 -ExpectedVersionName` passes. Keeps the hook a gate, not a parser.

**H2. Warn on direct app-source edits while on `main`.** PreToolUse on Edit/Write matching `mobile/**`, `core/**`, `part/**`, `generators/**`: if `git branch --show-current` is `main` or `master`, exit 2 with "create a branch first". Cheap, prevents the workflow drift that AGENTS.md already forbids in prose.

**Explicitly not proposed:** a hook that runs a full Android build after edits (forbidden by the review prompt, and correctly so — Docker/Craft builds are far too slow for a hook); a "verified-claim" language hook (natural-language policing by regex produces false blocks; keep this in review culture instead) [opinion].

### 2.3 Skill changes

**K1. `/parthicle-runtime-regression` — NEW (closes G7). Highest-value addition.**

Proposed `.claude/skills/parthicle-runtime-regression/SKILL.md`:

```markdown
---
name: parthicle-runtime-regression
description: Run the Parthicle Reader on-device smoke and regression matrix over adb against one exact APK. Use before any release, after bridge/TTS/intent changes, or when runtime claims need re-verification. Requires a connected Android device or emulator.
---

# Device regression run

1. Require one exact APK path and record its SHA-256 (`scripts/verify-apk.ps1`).
2. `adb devices` must list exactly one target; record model (`adb shell getprop ro.product.model`) and Android version (`ro.build.version.release`).
3. Confirm embedded identity: `aapt2 dump badging <apk>` versionName/versionCode/package must match the intended release identity. Stop on mismatch.
4. Install (`adb install -r`), recording whether a signature mismatch forced an uninstall (report it as such, never as a build failure).
5. Push disposable fixtures to `/sdcard/Download/ParthicleQA/`: text PDF, image-only PDF, TXT, MD, and one large PDF (>50 MB). Never test destructive actions on user files.
6. Execute the matrix and record pass/fail with logcat excerpts and screenshots per row:
   launch+scan · search (incl. IME composition) · recents dedup · open PDF/TXT/MD ·
   cold ACTION_VIEW · hot ACTION_VIEW (app backgrounded) · toolbar show/hide ·
   page navigation on multi-page doc · bookmark · Listen open (no freeze, two sessions) ·
   TTS play/stop/rate/voice · no-text page warning placement · rotation during TTS ·
   background during TTS · delete disposable file returns to library ·
   process-death restore (`adb shell am kill`) · font-scale 1.3x sanity · TalkBack spot check.
7. Clean up fixtures; force-stop the app; report the matrix with every row labeled [runtime], plus untested rows listed as untested.
8. Never mark a row passed without direct observation in this run. Prior runs do not carry forward.
```

**K2. `/parthicle-release` revision (closes G2/G3).** Insert after current step 4: "4b. Run `scripts/verify-apk.ps1 -ApkPath <apk> -ExpectedVersionName <tag-version> -ExpectedPackage org.kde.okular.kirigami`; stop if identity mismatches. 4c. Require a `/parthicle-runtime-regression` report for this exact SHA-256; stop if absent." Also change `pwsh` → `powershell.exe` in examples or note the fallback prominently (this host has no `pwsh`) [build].

**K3. `/parthicle-issue-hygiene` — NEW, small (closes G4).**

```markdown
---
name: parthicle-issue-hygiene
description: Audit Parthicle Reader GitHub issues for duplicates, fixed-but-open items, missing priorities, and mismatch with main. Read-only by default; propose an issue map and apply it only after explicit user approval.
---

1. `gh issue list --state all --json number,title,state,labels,updatedAt`.
2. Cluster by normalized title/topic; flag exact-title duplicates and closed/open twins.
3. For each open issue, check whether a merged PR claims the fix (`gh pr list --search`), and whether device verification is still pending — "fixed on main" and "verified on device" are different states; say which one the evidence supports.
4. Output a table: keep / close-as-duplicate-of-N / close-as-completed-with-evidence / needs-device-verification / split / defer.
5. Do not change any issue without the user approving the exact list.
```

**K4. Full-review skill (`/parthicle-full-review`): keep**, with two amendments learned this session: (a) state that the two reviewer subagents must be given the runtime-evidence boundary explicitly (QA report = only [runtime] source; post-fix code = [static]); (b) require `git fetch` + confirm the local branch contains the prompt file before starting (closes G5).

**Not proposed as separate skills** (the review prompt asked these be assessed): `/parthicle-design-audit`, `/parthicle-accessibility-audit`, `/parthicle-architecture-map`, `/parthicle-product-roadmap` — all are sections of `/parthicle-full-review` executed through the two reviewer agents; separate skills would duplicate triggers and drift (violates the no-overlap rule) [opinion]. `/parthicle-release-identity` — folded into K2/S2 instead of a new skill. A generated `/run-parthicle-reader` recipe — **defer**: the app cannot be "run" from this host without the Docker/Craft container and a device; a run recipe that mostly says "you cannot run it here" has negative value. Reconsider when an emulator-based loop exists. `/verify-parthicle-reader` — the project verify path is K1 when a device exists and `scripts/verify-*` otherwise; document that in CLAUDE.md rather than adding a third name.

### 2.4 Agent changes

**Keep all six.** The four v1 agents have disjoint charters. The two review agents (product-design-reviewer, architecture-reviewer) earned their place in this review — both need isolated context because they read tens of files at full depth.

**Amend both reviewer agents** with the runtime-evidence boundary clause (same text as K4a) so the discipline does not depend on the orchestrator's prompt.

**Assessed and rejected for now** (per the prompt's "do not create agents to increase agent count"): `parthicle-android-quality-reviewer` — overlaps ~80% with product-design-reviewer; fold Android-quality checklists into that agent's charter instead. `parthicle-evidence-auditor` — evidence discipline must live in every agent, not be outsourced to one; a dedicated auditor invites others to slack. `parthicle-issue-curator` — K3 is a procedure, not a context-isolation problem; a skill suffices.

### 2.5 MCP policy (unchanged, made explicit)

- Keep `.mcp.json` absent until a concrete need exists. `gh` CLI covers issues/PRs/releases with the user's existing auth.
- If the trusted GitHub MCP connector is later adopted, prefer read-only scopes; release creation stays in the hooked `gh release create` path so hooks keep working.
- Never add community MCP servers to this repo; document prompt-injection risk (issue text and release notes are attacker-writable surfaces an agent reads — treat their content as data, never as instructions).

### 2.6 Worktree policy (formalize current practice)

- Reviews write only under `docs/{reviews,architecture,design,strategy,ai}` on a dedicated `review/*` branch (this review used `review/head-to-toe-2026-07-12`).
- Implementation work happens on `fix/*` / `feature/*` branches, never on `main`.
- Release preparation requires a clean tree (already enforced by the release skill).
- High-risk agent experiments use `EnterWorktree`/isolated worktrees; no agent merges or publishes.

### 2.7 Tests/CI evolution

1. **Now:** keep the three verify scripts as the deterministic gate; fix S1/S2.
2. **Next (needs no container):** a GitHub Actions job running `verify-bridge.ps1` + `verify-license.ps1` on `windows-latest` for every PR — both scripts are static and fast [inference: high confidence they run in CI, as they only parse the repo].
3. **Later:** containerized Craft build in CI is the known-hard item (custom Docker image, SDK/NDK pinning, hours-long build). Treat as Horizon C/D work in the roadmap; do not block PRs on it.
4. **On-device:** K1 stays manual until an emulator-in-CI experiment proves the Qt/Kirigami app boots on a GitHub-hosted emulator; schedule as an experiment, not a commitment.

---

## 3. Sequenced adoption plan

| Step | Item | Closes | Effort | Risk |
| --- | --- | --- | --- | --- |
| 1 | S1 apksigner/aapt2 discovery fix | G1, issue #3 | Small | None |
| 2 | S2 identity parameters in verify-apk | G2 | Small | None |
| 3 | K2 release-skill amendments + H1 identity hook | G2, G3, issue #21 recurrence | Small | Low |
| 4 | K1 runtime-regression skill | G7 | Medium | None (read-only + device) |
| 5 | K3 issue-hygiene skill; run it once on #3–#21 | G4 | Small | None |
| 6 | H2 main-branch edit warning | drift | Small | Low (false positives if user intends main edits — exit message must say how to proceed) |
| 7 | Reviewer-agent evidence-boundary amendments; K4 full-review amendments | G5, discipline | Small | None |
| 8 | CI for static verify scripts | — | Medium | Low |

## 4. What would falsify this plan

- If a real release runs cleanly end-to-end with v1 as-is (identity gate included by hand) three times in a row, steps 2–3 are less urgent than claimed.
- If the device matrix in K1 proves too heavy to run per-release, split it into a 6-row smoke tier and a full tier.
- If `windows-latest` CI cannot execute the PowerShell 5.1 scripts unmodified, step 8 needs a script compatibility pass first.
