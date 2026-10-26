# Global Rules

- Primary OS is macOS.
- Interactive shell is `fish`.
- Runtime and tool versions are managed with `mise`.
- Prefer macOS-compatible commands and `fish`-compatible snippets unless the project requires otherwise.
- If a runtime is missing, consider `mise` before suggesting manual installation.

## Artifact Review

When you create a user-reviewable artifact, verify that it exists and run
`openit <absolute-path-or-url>`. Open only finalized review artifacts, not
intermediate files or every edited source file.

## Durable Context

Tickets track work; docs explain it. Do not require readers to open a ticket to
understand a doc, spec, plan, runbook, or PR.
