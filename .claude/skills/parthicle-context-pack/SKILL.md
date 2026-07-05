---
name: parthicle-context-pack
description: Create a small, security-checked Parthicle Reader context bundle for another AI agent or reviewer. Use when packing repository context, preparing a handoff, or reducing Java/C++/QML bridge context with Repomix.
---

# Pack focused repository context

Use `repomix.parthicle.json`; do not widen to the full Okular tree by default.

1. Review `git status` and the config include/ignore rules.
2. Exclude APKs, keystores, environment files, build trees, Craft roots, credentials, device data, and generated output.
3. Install Repomix later if needed (`npm install -g repomix`), then run:

   ```sh
   repomix --config repomix.parthicle.json
   ```

4. Read Repomix security findings and stop if any secret-like content is detected.
5. Inspect `repomix-parthicle.xml` before sharing. Record source commit, dirty status, config path, output SHA-256, and omitted runtime evidence.
6. Delete or leave the generated pack untracked after handoff; never commit it.

For adversarial or sandboxed agent experiments, Pi + Gondolin may be installed later. Archon may be added later for durable project knowledge, but neither is required for a deterministic context pack.
