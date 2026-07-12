---
name: parthicle-full-review
description: Run a read-first, evidence-labeled, head-to-toe review of Parthicle Reader covering project history, architecture, runtime truth, Apple-inspired Android UX, accessibility, security, licensing, roadmap, issue hygiene, and the Claude Code harness. Use when the user asks what the project is, what has been done, what is missing, whether it is user-friendly, or what the long-term direction should be.
disable-model-invocation: true
model: inherit
effort: max
argument-hint: "[optional focus or artifact path]"
---

# Review Parthicle Reader from head to toe

Read and execute:

`docs/reviews/fable-head-to-toe-project-review-prompt.md`

Additional focus supplied by the user:

`$ARGUMENTS`

Before beginning:

1. Confirm the repository root, branch, commit, and worktree state.
2. Remain read-only with respect to app source and GitHub state.
3. Use evidence labels exactly as defined in the detailed prompt.
4. Use specialized read-only subagents for high-volume architecture, design, Android-quality, issue-history, or research exploration when that preserves the main context.
5. Do not create skills, agents, hooks, issues, releases, or source patches during the audit; propose them in `docs/ai/parthicle-harness-v2-plan.md`.
6. Use the strongest currently selected model. The user should select Fable before invoking this skill.

Required outputs are the five documents listed in the detailed prompt. If runtime testing is unavailable, produce an explicit manual test matrix and mark runtime claims unverified.
