---
name: reviewers
description: Use when reviewing AI-generated code, specs, architecture, implementation plans, documents, or reviewer feedback before accepting, merging, applying, or acting on it.
---

# Reviewers

## Overview

Review AI-generated work as independent verification, not consensus-building. Confidence, claimed tests, and other reviewers' approvals are inputs to check, not evidence.

## Harness Contract

The review policy lives here, but external reviewer CLIs may not load this skill.
Therefore ai-review.fish must embed the essential review contract in every
generated request: review kind, focus, role constraints, output shape, worktree,
branch, HEAD, and evidence expectations.

Use --kind when the target is not an obvious code diff. Use --focus when the user
asks for a specific review angle. Treat --kind auto as a hint and verify the
generated request classified the target reasonably.

## Required Orchestration

The default path is external review orchestration through `ai-review.fish`.

| Situation | Required action |
|---|---|
| User asks this agent to review AI-generated work | Run `ai-review --all --worktree PATH --kind auto` with the narrowest safe scope before giving a verdict |
| A previous ai-review group is still running | Run `ai-review collect [GROUP_OR_RUN_ID]` and wait for results |
| Prompt is already an `# AI Review Request` from ai-review | Do not recurse; act as that assigned reviewer |
| Not inside tmux | Run `ai-review --headless --all --worktree PATH --kind auto` |
| `ai-review` is unavailable | Report that orchestration cannot run; do not do a solo final review unless the user explicitly overrides |

## Worktree Selection

Reviewer panes must start in the real repository/worktree being reviewed, not a temp copy or whatever directory the tmux origin pane happens to be in.

1. Identify the intended target worktree before starting review.
2. Pass it explicitly with `--worktree /absolute/path` unless the origin pane is already known to be in that exact worktree.
3. Prefer absolute paths. From fish in the target repo, `ai-review --all --worktree (pwd)` is acceptable.
4. After starting, verify `ai-review list` or each request's `Worktree:` line shows the intended path.
5. If the worktree shows `/tmp`, `/private/tmp`, or an unrelated repo, stop that run and restart with the correct `--worktree`.

From non-fish shells, use fish without overriding XDG or zoxide paths:

```sh
fish -lc 'ai-review --all --worktree /path/to/repo --kind auto'
fish -lc 'ai-review --headless --all --worktree /path/to/repo --kind auto --no-wait'
fish -lc 'ai-review --all --worktree /path/to/repo --staged-only --kind code'
fish -lc 'ai-review --deep --worktree /path/to/repo --staged-only --kind code'
fish -lc 'ai-review --all --worktree /path/to/repo --path path/to/file --path path/to/other --kind auto'
fish -lc 'ai-review --all --worktree /path/to/repo --kind architecture --focus "dependency direction and failure modes"'
fish -lc 'ai-review collect'
fish -lc 'ai-review list --worktree /path/to/repo'
fish -lc 'ai-review clean'
```

`ai-review` does not paste the aggregate prompt by default. Use `--paste` only when the origin pane is an AI prompt that should receive the aggregate prompt.

Review artifacts are written under `/tmp/ai-review`. Use the group manifest, `reviews.md`, `summary-prompt.md`, and per-run `request.md`, `result.md`, `stdout.txt`, and `stderr.txt` files when diagnosing reviewer behavior.

Do not blindly trust `--kind auto`; verify the generated request before relying on the review.

Pass `--worktree` explicitly whenever the origin pane might not already be in the target repository; otherwise reviewer panes inherit the origin pane's current directory. Do not set `XDG_DATA_HOME` or `_ZO_DATA_DIR` just to run `ai-review`; that hides environment problems and can make reviewer panes inherit the wrong runtime state. If sandbox restrictions prevent fish, zoxide, tmux, or Codex from writing normal state, run `ai-review` from an unsandboxed tmux shell instead of redirecting state to temporary XDG paths. `ai-review` creates tmux panes for each configured reviewer, captures their outputs, and returns an aggregate prompt. The final answer should synthesize those reviewer results using this skill's contract.

## Headless Mode

Use `--headless` when the caller is not inside tmux or when an agent needs file-based review orchestration without visible panes. Headless mode still writes the same `/tmp/ai-review` group artifacts and supports `collect`, but progress is tracked by reviewer process IDs instead of tmux panes.

Prefer `--no-wait` for agent-driven headless runs, then call `ai-review collect GROUP_ID` after reviewers finish or when the user asks for status.

## Review Depth

Use the default `--all` path for normal review. Use `--deep` only when the user asks for a deeper or more expensive pass, the change is high-risk, or default reviewers disagree. Deep review is still limited to supported Claude/Codex reviewers and must not add unsupported agents.

## State Hygiene

Use `ai-review list --worktree PATH` when old runs make status hard to read. Use `ai-review clean` to remove terminal run directories after results have been collected or are no longer needed. Do not clean while reviewers are still running unless the user intentionally wants to discard old terminal artifacts only.

## Review Scope

Avoid reviewing unrelated dirty worktree changes. Choose the narrowest scope that still covers the user request.

- Use `--staged-only` when the intended review target is the staged patch.
- Use repeatable `--path PATH` when only specific files or directories should be reviewed.
- Use full worktree scope only when the whole dirty worktree is intentionally in scope.
- Verify each request's `Diff Scope:` and `Path Scope:` metadata before trusting reviewer output.

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
| Docs | Reader context, durable explanation, stale ticket dependency, unsafe or ambiguous guidance |
| Reviewer synthesis | Evidence quality, conflicting claims, duplicate findings, hallucinated files/lines, actionable items |

If the target is mixed, review the highest-risk layer first: architecture/spec before plan, plan before code details, blocking correctness before style.

## Output Contract

Every review must use this shape:

```markdown
## Review Target
[Code / Spec / Architecture / Plan / Docs / Review Synthesis / Mixed]

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

Anchors are file:line for code, section/requirement/heading or quoted claim for specs/docs, decision or boundary for architecture, step number for plans, reviewer name plus claim for synthesis.

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
