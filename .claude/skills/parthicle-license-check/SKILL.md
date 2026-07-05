---
name: parthicle-license-check
description: Review Parthicle Reader licensing, attribution, SPDX headers, Okular/KDE GPL obligations, dependency notices, or release wording. Use before distribution and whenever protected license or attribution files may change.
---

# Check licensing and attribution

Treat `LICENSES/`, `COPYING*`, `LICENSE*`, `ATTRIBUTION.md`, `REUSE.toml`, and `.reuse/` as protected. Obtain explicit user approval before editing them.

1. Run `scripts/verify-license.ps1` and inspect the actual git diff.
2. Confirm no license/attribution file is deleted or renamed away.
3. Confirm modified source retains valid `SPDX-FileCopyrightText` and `SPDX-License-Identifier` lines where the file already used them.
4. Trace new copied code, fonts, icons, screenshots, libraries, Maven artifacts, and bundled binaries to their source and license.
5. Keep upstream Okular/KDE notices and GPL/LGPL license texts. Do not imply KDE e.V. endorsement or relicense upstream code.
6. For distributions, ensure attribution and corresponding source obligations have an explicit delivery plan.
7. If `reuse` is installed, run `reuse lint` and report its output separately from the deterministic repository check.

Classify results as blocker, needs provenance, or advisory. State that this is an engineering compliance review, not legal advice. Never turn missing provenance into a guessed license.
