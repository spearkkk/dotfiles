---
name: reviewers
description: Use when reviewing AI-generated code, specs, architecture, implementation plans, documents, or reviewer feedback before accepting, merging, applying, or acting on it.
---

# Reviewers

## Overview

Review AI-generated work as independent verification, not consensus-building. Confidence, claimed tests, and other reviewers' approvals are inputs to check, not evidence.

## Required Orchestration

The default path is external review orchestration through `ai-review.fish`.

| Situation | Required action |
|---|---|
| User asks this agent to review AI-generated work | Run `ai-review --all --worktree PATH` before giving a verdict |
| A previous ai-review group is still running | Run `ai-review collect [GROUP_OR_RUN_ID]` and wait for results |
| Prompt is already an `# AI Review Request` from ai-review | Do not recurse; act as that assigned reviewer |
| Not inside tmux or `ai-review` is unavailable | Report that orchestration cannot run; do not do a solo final review unless the user explicitly overrides |

## Worktree Selection

Reviewer panes must start in the real repository/worktree being reviewed, not a temp copy or whatever directory the tmux origin pane happens to be in.

1. Identify the intended target worktree before starting review.
2. Pass it explicitly with `--worktree /absolute/path` unless the origin pane is already known to be in that exact worktree.
3. Prefer absolute paths. From fish in the target repo, `ai-review --all --worktree (pwd)` is acceptable.
4. After starting, verify `ai-review list` or each request's `Worktree:` line shows the intended path.
5. If the worktree shows `/tmp`, `/private/tmp`, or an unrelated repo, stop that run and restart with the correct `--worktree`.

From non-fish shells, use fish without overriding XDG or zoxide paths:

```sh
fish -lc 'ai-review --all --worktree /path/to/repo'
fish -lc 'ai-review collect'
```

Pass `--worktree` explicitly whenever the origin pane might not already be in the target repository; otherwise reviewer panes inherit the origin pane's current directory. Do not set `XDG_DATA_HOME` or `_ZO_DATA_DIR` just to run `ai-review`; that hides environment problems and can make reviewer panes inherit the wrong runtime state. If sandbox restrictions prevent fish, zoxide, tmux, or Codex from writing normal state, run `ai-review` from an unsandboxed tmux shell instead of redirecting state to temporary XDG paths. `ai-review` creates tmux panes for each configured reviewer, captures their outputs, and returns an aggregate prompt. The final answer should synthesize those reviewer results using this skill's contract.

## When to Use

Use for AI agent review, code review, spec review, architecture review, implementation plan review, PR review, design review, or reviewer-result synthesis.

Do not use for writing the artifact itself; use it when deciding whether to trust, accept, revise, merge, or act on an AI-produced artifact.

## Quick Reference: Review Target

First classify the artifact, then emphasize the matching risks.

| Target | Review focus |
|---|---|
| Code diff | Requirements fit, behavior changes, regressions, errors, missing tests, security, compatibility |
| Spec | Problem clarity, scope, acceptance criteria, ambiguity, missing edge cases, contradictions |
| Architecture | Boundaries, dependency direction, data flow, coupling, failure modes, operability, migration path |
| Plan | Sequence, testability, hidden dependencies, rollback, risk, whether steps prove completion |
| Reviewer synthesis | Evidence quality, conflicting claims, duplicate findings, hallucinated files/lines, actionable items |

If the target is mixed, review the highest-risk layer first: architecture/spec before plan, plan before code details, blocking correctness before style.

## Output Contract

Every review must use this shape:

```markdown
## Review Target
[Code / Spec / Architecture / Plan / Review Synthesis / Mixed]

## Verdict
[Accept / Request changes / Block / Insufficient evidence]

## Main Risks
- ...

## Findings
- [severity] [anchor] Finding, evidence, impact

## Evidence Gaps
- ...

## Recommended Next Actions
- ...
```

Anchors are file:line for code, section/requirement/decision for specs and architecture, step number for plans, reviewer name plus claim for synthesis.

## Review Rules

- Treat "tests pass", "manually tested", "senior agent approved", and "reviewers agree" as unverified until evidence is shown.
- Prefer `Insufficient evidence` over forced approval when source material is missing.
- Separate blocking defects from non-blocking improvements.
- Do not hide uncertainty: name the missing file, command output, requirement, or decision.
- Do not rewrite the artifact unless asked; review it.

## Rationalizations

| Excuse | Reality |
|---|---|
| "Another AI already approved it" | Other AI output is a claim source, not proof. Verify evidence. |
| "The team is in a hurry" | Time pressure raises review risk; it does not lower the bar for blockers. |
| "It looks broadly coherent" | Coherent specs can still be unimplementable, ambiguous, or contradictory. |
| "Only one architecture issue stood out" | Review boundaries, data flow, failure modes, and operations before narrowing. |
| "The author says tests pass" | Test claims need command/output or must be listed as an evidence gap. |

## Red Flags

Stop and apply the contract when you see: LGTM pressure, approve-only requests, "don't ask for context", large diff fatigue, reviewer consensus, senior-agent authority, claimed tests without output, or architecture dismissed as "theoretical."

## Common Mistakes

- Approving coherent prose without checking whether it is implementable.
- Reviewing architecture like code and missing dependency direction or failure modes.
- Treating reviewer consensus as correctness.
- Listing concerns without a verdict or next action.

## Example

A spec says "offline mode should never lose work, sync later, handle conflicts automatically, no backend changes." Verdict should not be plain approval. Review Target: Spec. Verdict: Request changes or Insufficient evidence. Findings should call out undefined conflict policy, storage limits, cross-device behavior, retry/idempotency, and acceptance tests. Evidence Gaps should ask for sync contract and conflict examples.
