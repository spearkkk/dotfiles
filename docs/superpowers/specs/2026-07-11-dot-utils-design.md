# Dot Utils Design

## Goal

Create a small personal utility command system for interactive fish usage and Alfred workflow integration. The first version should focus on timestamp handling, case conversion, and random identifiers or variable-like strings.

## Chosen Approach

Use a hybrid command layout:

- `.local/bin/u` is the stable executable entrypoint for fish, shell scripts, and Alfred.
- `.local/share/dot-utils/u.lua` is the Lua CLI dispatcher.
- `.local/share/dot-utils/lib/` contains reusable Lua modules.
- Fish integration can add short aliases or completions later without becoming the implementation backend.

This keeps `.local/bin` clean, makes Alfred integration predictable, and lets the Lua code grow without crowding executable files.

## Command Shape

The main command is `u`, with grouped subcommands:

```text
u ts now
u ts ms
u case camel "hello world"
u case snake "hello world"
u rand hex 8
u rand var
```

Commands print only the result to stdout by default so they are easy to pipe, copy, or return from Alfred.

## Initial Utility Groups

### `ts`

Timestamp utilities:

- `u ts now`: Unix timestamp in seconds.
- `u ts ms`: Unix timestamp in milliseconds.
- `u ts iso`: local ISO-like timestamp.
- `u ts date`: local date in `YYYY-MM-DD`.

### `case`

Case conversion utilities:

- `u case snake <text>`
- `u case kebab <text>`
- `u case camel <text>`
- `u case pascal <text>`
- `u case upper <text>`
- `u case lower <text>`

The command accepts all remaining arguments as input text joined with spaces.

### `rand`

Random value utilities:

- `u rand hex [bytes]`: lowercase hex string, default 8 bytes.
- `u rand id [length]`: URL-safe alphanumeric id, default 12 chars.
- `u rand var [style]`: variable-like name. Default style is `camel`; supported styles are `camel`, `snake`, and `kebab`.

Use macOS-friendly system randomness where possible. If the implementation uses external tools, keep dependencies to tools already present or already bootstrapped in this dotfiles repo.

## Error Handling

- Unknown groups or subcommands exit with status `2`.
- Runtime failures exit with status `1`.
- `u help`, `u --help`, and invalid usage print concise usage text.
- Successful commands print no labels, colors, or extra decoration.

## Alfred Integration

Alfred workflows should call `.local/bin/u` directly. Because the command writes plain stdout, Alfred can use the result as script output or copy it to the clipboard without parsing.

## Testing

Add a lightweight test script or documented verification command that exercises:

- Help output.
- Each timestamp command returns a non-empty value.
- Case conversions for a representative input.
- Random commands return expected character classes and lengths.
- Invalid commands return status `2`.

## Out of Scope For First Version

- URL, base64, JSON, color, network, or localhost helpers.
- Interactive prompts.
- Alfred workflow file generation.
- Fish completions beyond a simple alias or function if it is trivial.
