# Parthicle Reader design principles

Date: 2026-07-12 · Source: head-to-toe review (Fable 5). These are proposed north-star principles. They use Apple's design philosophy — clarity, deference to content, restraint, feedback, forgiveness, fit-and-finish — as a **quality standard**, while remaining a native Android product that follows Android navigation, lifecycle, storage, accessibility, and back-gesture conventions. They are deliberately specific enough to reject features.

Evidence basis: the 2026-07-05 on-device QA audit [runtime], QML/Java source [static], and design judgment [opinion]. Apple HIG and Android quality guidelines are principle sources [research], not laboratory proof.

---

## P1. The document is the interface

The page owns the screen. Chrome exists to serve the current reading act and then gets out of the way — but never at the cost of discoverability or of covering content.

- Reader chrome auto-hides; a single tap brings it back. (Already true [runtime].)
- Chrome must never obscure content while visible — the v0.3.0 toolbar overlapping the first lines of a page [runtime] violates this. Chrome pushes, insets, or dims; it does not sit on the text.
- No decoration that competes with the page: gradients, cards, and accents belong to the library, not the reading surface.

*Rejects:* persistent banners in the reader; a toolbar row of rarely-used icons; branding on the reading surface.

## P2. Open locally, work offline, stay private

Parthicle's promise is MX-Player-like: point it at the files already on the phone and it just works — no account, no cloud, no upload.

- Every feature must function with the network off.
- No telemetry or crash reporting without explicit, revocable consent; local logs first.
- Permissions are explained in the moment of need, in plain words ("scans your files on this phone; nothing leaves it").
- The `INTERNET` permission must either gain a user-visible justification or be removed [static: currently unused by app code].

*Rejects:* cloud sync as a headline feature; login walls; third-party analytics SDKs; "AI summarization" that ships text off-device.

## P3. Honest state, honest claims

The UI never fabricates state, and product copy never claims more than the artifact does.

- No placeholder progress bars (the hardcoded 44% bar was a violation [runtime]; removed on main [static]).
- Status text must reflect reality: "Ready to read" on a page with no extractable text is a lie [runtime]; the check belongs before the promise.
- README/release formats list = generators actually in the APK. v0.3.x claims EPUB/DjVu while shipping neither generator [artifact] — that fails this principle.
- Errors say what happened and what to do next, near where the user is looking.

*Rejects:* skeleton screens that fake progress; "supported formats" lists copied from upstream; release notes claiming untested behavior.

## P4. One obvious path; power on demand

Every common job — find, open, resume, listen, delete — has exactly one visible, self-explanatory path. Advanced controls exist behind one consistent disclosure point, never more than one level deep.

- Primary actions are labeled and visible; the headline feature (Listen) must not hide behind an unlabeled overflow glyph [runtime].
- Progressive disclosure, not amputation: the compact toolbar that drops the document title and all named actions behind "⋮" [runtime] hides too much.
- Identical controls behave identically everywhere; one vocabulary ("Recent", "Bookmark", "Listen" — not "Local History"/"Mark"/"Saved" drift [runtime]).

*Rejects:* settings screens with engine internals users never asked about; two entry points to the same action; icon-only destructive buttons.

## P5. Forgiving by construction

Users must be able to act quickly without fear.

- Destructive actions: clear confirmation naming the object, then visible success, then a safe landing place. (Delete stranding the user on the deleted document [runtime] violated the landing rule; fixed on main [static], unverified on device.)
- Prefer undo over confirmation where feasible (snackbar undo for delete is the target state).
- Back always does the expected Android thing — leaves chrome, then leaves the document, then leaves the app; never a dead end.
- State survives rotation, backgrounding, and process death. A reader that loses your place is broken; session restore is a core requirement, not a feature.

*Rejects:* irreversible bulk operations; custom back behavior; "are you sure?" as a substitute for reversibility.

## P6. Accessibility is a release gate, not a backlog label

If it cannot be used with TalkBack, large fonts, and one hand, it is not done.

- Every interactive element has an accessible name and ≥48dp effective target.
- Text respects system font scaling; contrast meets WCAG-AA-equivalent ratios as an engineering target (formal conformance claims require an audit).
- No information carried by color alone; focus order matches visual order.
- The audit found icon/glyph-only controls without labels [runtime]; that class of defect blocks release once this principle is adopted.

*Rejects:* shipping a screen whose TalkBack pass was never run; dp-precise designs that break at 1.3× font scale.

## P7. Broad format support, honestly earned

The MX-Player analogy is about *coverage with zero configuration* — but only formats that open on a real device get claimed.

- Format support is proven per-release by opening a fixture file of that type on-device; the claim list is generated from that matrix, not from upstream capability.
- Formats without a shipped generator are labeled "planned", with graceful failure copy in-app.
- Prefer deepening reliability of the big five (PDF, images, TXT/MD, CBZ/CBR, EPUB-when-shipped) over adding exotic formats.

*Rejects:* advertising every Okular generator; silently rendering Markdown as raw text while release notes say "Markdown opening: passed" [history].

## P8. Preserve the Okular foundation; change it upstream-compatibly

The Okular document model is the moat — the reason format breadth is achievable by a one-person project. Attribution is a feature, not a liability.

- No thin Android-only PDF rewrite (AGENTS.md gate; affirmed by this review).
- Keep `core/`, `part/`, `generators/` diffs minimal and upstreamable; UI innovation happens in `mobile/`.
- Okular/KDE attribution stays visible in README, ATTRIBUTION.md, and release notes; the fork never implies KDE endorsement.

*Rejects:* forking core rendering for a quick feature; hiding the fork's origin for branding reasons; license simplification "for a prototype".

---

## Using these principles

A feature proposal must state which principle it serves and must not violate any other. When two conflict (e.g., P7 breadth vs P3 honesty), honesty and reliability win over breadth and novelty. The anti-roadmap in `docs/strategy/parthicle-long-horizon-roadmap.md` applies these rejections to currently tempting ideas.
