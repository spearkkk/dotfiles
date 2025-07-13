#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/utils/aerospace.sh"

# Define plugin and item directories (needed for sourcing item configs)
PLUGIN_DIR="$CONFIG_DIR/plugins"
ITEM_DIR="$CONFIG_DIR/items"

# Generate arguments for all left-side items (workspaces + front_app + separator)
generate_left_side_args() {
    local all_args=()
    
    # Add aerospace events first
    all_args+=(--add event aerospace_workspace_change)

    # This custom event (triggered in ~/.config/aerospace/aerospace.toml) fires when a window is moved
    # from one space to another.
    # It will include two variables:
    # - TARGET_WORKSPACE: The ID of the workspace the window was moved to
    # - FOCUSED_WORKSPACE: The ID of the workspace that is currently focused (where the window is moving from)
    all_args+=(--add event change-window-workspace)
    

    # This custom event (triggered in ~/.config/aerospace/aerospace.toml) fires when
    # a workspace is moved to a different monitor.
    # It will include two variables:
    # - TARGET_MONITOR: The system ID of the monitor the workspace was moved to (NOT aerospace ID)
    # - TARGET_WORKSPACE: The ID of the workspace that is being moved
    all_args+=( --add event change-workspace-monitor)
    
    # Generate workspace arguments
    local all_workspace_data=$(aerospace list-windows --monitor all --format "%{workspace}|%{app-name}")
    local focused_workspace=$(aerospace list-workspaces --focused)
    local active_workspaces=$(extract_unique_workspaces "$all_workspace_data")
    active_workspaces=$(include_focused_workspace "$active_workspaces" "$focused_workspace")
    
    for workspace_id in $active_workspaces; do
        if [[ -n "$workspace_id" ]]; then
            while IFS= read -r arg; do
                all_args+=("$arg")
            done <<< "$(generate_workspace_args "$workspace_id")"
        fi
    done
    
    # Add workspace separator
    all_args+=(
        --add item workspace_separator q
        --set workspace_separator
        icon="􀤑"
        icon.font.size=10
        icon.color="$RED"
        icon.padding_left=2
        icon.padding_right=4
        label.drawing=off
        background.drawing=off
        script="$CONFIG_DIR/plugins/aerospace_windows.sh"
        display="active"
        --subscribe workspace_separator space_windows_change
        --subscribe workspace_separator front_app_switched
        --subscribe workspace_separator aerospace_workspace_change
        --subscribe workspace_separator change-window-workspace
        --subscribe workspace_separator change-workspace-monitor
    )
    all_args+=(
        --add bracket _aerospace '/workspace\..*/' workspace_separator \
        --set _aerospace drawing=on \
              background.drawing=on \
              background.corner_radius=4 \
              background.border_width=0 \
              background.color="$(set_alpha $BACKGROUND_DARKEST 60)" \
              background.y_offset=0
    )
    
    # Add front_app using new pattern
    source "$CONFIG_DIR/items/_front_app.sh"
    all_args+=("${FRONT_APP[@]}")

    printf '%s\n' "${all_args[@]}"
}

# Generate arguments for all right-side items
generate_right_side_args() {
    local all_args=()
    
    # All right-side items using new pattern
#    source "$CONFIG_DIR/items/calendar.sh"
#    all_args+=("${bar_item_calendar[@]}")
#
#    source "$CONFIG_DIR/items/volume.sh"
#    all_args+=("${bar_item_volume[@]}")

    
#    source "$CONFIG_DIR/items/cpu.sh"
#    all_args+=("${bar_item_cpu[@]}")
    
#    source "$CONFIG_DIR/items/memory.sh"
#    all_args+=("${bar_item_memory[@]}")
    
#    source "$CONFIG_DIR/items/wifi.sh"
#    all_args+=("${bar_item_wifi[@]}")
    
    printf '%s\n' "${all_args[@]}"
}

# Execute left or right side based on argument
case "$1" in
    "left")
        args=()
        while IFS= read -r arg; do
            args+=("$arg")
        done <<< "$(generate_left_side_args)"
        sketchybar "${args[@]}"
        ;;
    "right")
        args=()
        while IFS= read -r arg; do
            args+=("$arg")
        done <<< "$(generate_right_side_args)"
        sketchybar "${args[@]}"
        ;;
    *)
        echo "Usage: $0 {left|right}"
        exit 1
        ;;
esac
