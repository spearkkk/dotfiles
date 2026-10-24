# tmux Alt Pane Navigation Design

## Intent

Keep two distinct unprefixed tmux shortcuts:

- `Alt+h/j/k/l` selects the adjacent pane without changing the layout.
- `Alt+Shift+h/j/k/l` moves the current pane's position with the Tilish-aware
  `tmux-move-pane` helper.

The plain Alt bindings were removed while Tilish integration was introduced,
which made the expected focus-navigation shortcut unavailable.

## Goals

- Restore unprefixed `Alt+h/j/k/l` pane focus navigation.
- Preserve the existing `Alt+Shift+h/j/k/l` pane-reordering bindings.
- Add a regression assertion for the two shortcut families.

## Non-goals

- Do not change Tilish layout behavior or the pane movement helper.
- Do not alter prefix-based `h/j/k/l` navigation.

## Approaches

1. Bind plain Alt keys to `select-pane` and retain Shift+Alt bindings for the
   movement helper. Chosen: this exactly separates navigation from reordering.
2. Bind both key families to the movement helper. Rejected: it removes
   focus-only navigation.
3. Use a separate plugin for focus navigation. Rejected: tmux's built-in
   `select-pane` is sufficient and has no additional lifecycle interaction.

## Implementation

Add four root-table bindings in `home/.tmux.conf`:

```tmux
bind-key -n M-h select-pane -L
bind-key -n M-j select-pane -D
bind-key -n M-k select-pane -U
bind-key -n M-l select-pane -R
```

Extend the tmux movement test (or add a focused configuration assertion) to
require both the plain Alt focus bindings and the existing Shift+Alt movement
bindings. The regression test should fail if either key family is removed or
assigned to the other behavior.

## Verification

Run the focused tmux test and inspect the loaded key table in an isolated tmux
server. After sourcing the configuration in the user's live server, verify:

1. `Alt+h/j/k/l` changes the active pane only.
2. `Alt+Shift+h/j/k/l` swaps the current pane with its directional neighbor.
