#!/bin/bash

# Expects the first positional argument to be a workspace ID
workspace_app_icons() {
  if [[ -z "$1" ]]; then
    echo "No workspace ID provided"
    return
  fi  
  local workspace_id="$1"

  local aerospace_apps=$(aerospace list-windows --workspace $workspace_id --format "%{app-name}")

  if [[ -z "$aerospace_apps" ]]; then
    echo ""
    return
  fi

  # Generate icon strip using batched approach (eliminates subprocess overhead)
  local app_array=()
  while read -r app; do
    [[ -n "$app" ]] && app_array+=("$app")
  done <<< "$aerospace_apps"
  
  if [[ ${#app_array[@]} -gt 0 ]]; then
    echo "$($CONFIG_DIR/icon_map_in_batch.sh "${app_array[@]}")"
  else
    echo ""
  fi
  return
}

source $CONFIG_DIR/icons.sh

# Load the color variables
source $CONFIG_DIR/colors.sh

# Get the system monitor ID of the specified workspace.
# Expects the workspace ID as the first argument
# Returns the monitor ID of the workspace
# returns nothing (empty string) if the workspace has no windows.
get_workspace_monitor_id() {
  local workspace_id="$1"
  # aerospace command that returns all windows in the workspace, formatted as only the system monitor ID
  # each workspace is 1 character long, so truncate the output to only the first character
  local aerospace_result=$(aerospace list-windows --workspace $workspace_id --format "%{monitor-appkit-nsscreen-screens-id}")
  local monitor_id=${aerospace_result:0:1}
  echo $monitor_id
}

# Generate sketchybar arguments for a workspace item (no execution)
# Expects the workspace id as the first argument
# Optional second argument: item to position before (if not provided, no positioning)
# Returns the arguments as a space-separated string
generate_workspace_args() {
    local sid=$1
    local position_before=$2

    # if $1 was empty, return empty
    if [ -z "$sid" ]; then
        return
    fi

    # Only render spaces in the top bar if they contain windows
    local drawing="off"
    # this will return the monitor ID of the workspace, or an empty string if the workspace has no windows
    local monitor_id=$(get_workspace_monitor_id $sid)
    # -n means "nonzero" length string - ie the space has at least 1 window
    if [[ -n $monitor_id ]]; then
      drawing="on"
    fi

    # Build sketchybar command array
    local label_content
    label_content="$(workspace_app_icons "$sid")"
    local sketchybar_args=(
        --add item workspace."$sid" left
        --set workspace."$sid"
        drawing="$drawing"
        display="$monitor_id"
        background.color="0x00000000"
        background.corner_radius=4
        background.padding_left=0
        background.padding_right=0
        icon.background.drawing=off
        icon.padding_left=4
        icon.padding_right=6
        icon.color="$TEXT_DEFAULT"
        icon="$(sf_symbol_for "$sid")"
        icon.highlight_color="$TEXT_DEFAULT"
        icon.font.style="Bold"
        icon.font.size=14
        label.highlight_color="$TEXT_DEFAULT"
        label.color="$TEXT_DEFAULT"
        label.padding_left=0
        label.padding_right=10
        label.y_offset=0
        label.font="sketchybar-app-font-bg:Regular:16.0"
        label="$label_content"
        click_script="aerospace workspace $sid"
        script="$CONFIG_DIR/plugins/aerospace.sh $sid"
    )

    # Add positioning if specified
    if [[ -n "$position_before" ]]; then
        sketchybar_args+=(--move workspace."$sid" before "$position_before")
    fi

    # Return arguments as newline-separated string
    printf '%s\n' "${sketchybar_args[@]}"
}

# create a workspace item.
# Expects the workspace id as the first argument
# Optional second argument: item to position before (if not provided, no positioning)
create_workspace() {
    local sid=$1
    local position_before=$2

    # if $1 was empty, log an error in /tmp/sketchybar.log
    if [ -z "$sid" ]; then
        echo "Error: create_workspace() expects a workspace id as the first argument" >> /tmp/sketchybar.log
        return
    fi

    # Generate and execute args
    local args=($(generate_workspace_args "$sid" "$position_before"))
    sketchybar "${args[@]}"
}
sort_alphanumeric() {
  # Read input from positional argument
  local input=($(echo "$1" | tr ' ' '\n'))

  # Process input: remove duplicates and sort
  printf "%s\n" "${input[@]}" | sort -u
}
# Extract unique workspace IDs from aerospace workspace data
# Parameters:
#   $1 - workspace_data: multi-line string in format "workspace_id|app_name"
# Returns:
#   Space-separated string of unique workspace IDs
extract_unique_workspaces() {
  local workspace_data="$1"
  local workspaces=()

  while IFS='|' read -r workspace_id app_name; do
    if [[ -n "$workspace_id" ]]; then
      workspaces+=("$workspace_id")
    fi
  done <<< "$workspace_data"

  # 중복 제거 및 정렬: 숫자 우선, 알파벳 나중
  local sorted_unique=$(printf "%s\n" "${workspaces[@]}" \
    | sort -u \
    | sort -t '' -k1,1)

  # 다시 공백 구분 문자열로 변환
  local result=""
  while read -r id; do
    result+=" $id"
  done <<< "$sorted_unique"

  echo "$result"
}

# Ensure focused workspace is included in workspace list (handles empty workspaces)
# Parameters:
#   $1 - workspace_list: space-separated string of workspace IDs
#   $2 - focused_workspace: the currently focused workspace ID
# Returns:
#   Updated space-separated string of workspace IDs including focused workspace
include_focused_workspace() {
  local workspace_list="$1"
  local focused_workspace="$2"

  # Add focused workspace if it has no windows (empty workspace)
  if [[ "$workspace_list" != *" $focused_workspace "* ]]; then
    workspace_list+=" $focused_workspace "
  fi

  echo "$workspace_list"
}

# Legacy function for compatibility with existing code
list_active_workspaces() {
  local window_workspaces=$(aerospace list-windows --monitor all --format %{workspace})
  window_workspaces="$window_workspaces"$'\n'"$(aerospace list-workspaces --focused)"
  sort_alphanumeric "$window_workspaces"
}

# Create sketchybar items for all active aerospace workspaces (batched)
create_aerospace_workspaces() {
  # Get all data efficiently
  local all_workspace_data=$(aerospace list-windows --monitor all --format "%{workspace}|%{app-name}")
  local focused_workspace=$(aerospace list-workspaces --focused)

  # Process the data to find active workspaces
  local active_workspaces=$(extract_unique_workspaces "$all_workspace_data")
  active_workspaces=$(include_focused_workspace "$active_workspaces" "$focused_workspace")

  # Build all workspace creation arguments
  local all_args=()
  for workspace_id in $active_workspaces; do
    if [[ -n "$workspace_id" ]]; then
      # Read newline-separated args properly (preserves spaces)
      while IFS= read -r arg; do
        all_args+=("$arg")
      done <<< "$(generate_workspace_args "$workspace_id")"
    fi
  done

  # Create all workspaces in single sketchybar call
  if [[ ${#all_args[@]} -gt 0 ]]; then
    sketchybar "${all_args[@]}"
  fi

  # Set focused workspace styling (separate call needed for timing)
  if [[ -n "$focused_workspace" ]]; then
    set_workspace_focused "$focused_workspace"
  fi
}


# function to handle the aerospace_workspace_change event
# This function only needs to be invoked once per event instance
# The event will have set two environment variables:
# - FOCUSED_WORKSPACE: The ID of the workspace that is becoming focused
# - PREV_WORKSPACE: The ID of the workspace that was previously focused
handle_workspace_change() {

  # Get all workspace data in single call
  local all_data=$(aerospace list-windows --monitor all --format "%{workspace}|%{app-name}")

  local focused_apps=""
  local prev_apps=""
  local prev_empty="true"

  while IFS='|' read -r ws app; do
    if [[ "$ws" == "$FOCUSED_WORKSPACE" && -n "$app" ]]; then
      focused_apps+="$app"$'\n'
    elif [[ "$ws" == "$PREV_WORKSPACE" && -n "$app" ]]; then
      prev_apps+="$app"$'\n'
      prev_empty="false"
    fi
  done <<< "$all_data"

  # Build workspace updates
  local focused_updates=""
  local prev_updates=""

  # Build focused workspace updates
  if [[ -n "$FOCUSED_WORKSPACE" ]]; then
    if ! sketchybar_item_exists "workspace.$FOCUSED_WORKSPACE"; then
      create_and_position_workspace "$FOCUSED_WORKSPACE"
    fi

    # Generate icon strip for focused workspace using batched approach
    local focused_icons=""
    if [[ -n "$focused_apps" ]]; then
      local focused_app_array


      IFS=$'\n' read -r -d '' -a focused_app_array <<< "$focused_apps"$'\0'
      focused_icons="$($CONFIG_DIR/icon_map_in_batch.sh "${focused_app_array[@]}")"

      echo "focused_apps: $focused_apps"
      echo "focused_app_array: $focused_app_array"
      echo "focused_icons: $focused_icons"
    else
      focused_icons=""
    fi

    focused_updates="--set workspace.$FOCUSED_WORKSPACE drawing=on icon.highlight=on label.highlight=on background.color=$(set_alpha $BLACK 60) label=\"$focused_icons\""
  fi

  # Build previous workspace updates
  if [[ -n "$PREV_WORKSPACE" ]]; then
    local prev_icons=""
    if [[ "$prev_empty" == "true" ]]; then
      prev_icons=" —"
      prev_updates="--set workspace.$PREV_WORKSPACE icon.highlight=off label.highlight=off background.color=0x00000000 drawing=off label=\"$prev_icons\""
    else
      local prev_app_array
      IFS=$'\n' read -r -d '' -a prev_app_array <<< "$prev_apps"$'\0'
      prev_icons="$($CONFIG_DIR/icon_map_in_batch.sh "${prev_app_array[@]}")"
      prev_updates="--set workspace.$PREV_WORKSPACE icon.highlight=off label.highlight=off background.color=0x00000000  label=\"$prev_icons\""
    fi
  fi

  # Execute batched command
  if [[ -n "$focused_updates" && -n "$prev_updates" ]]; then
    eval "sketchybar $focused_updates $prev_updates"
  elif [[ -n "$focused_updates" ]]; then
    eval "sketchybar $focused_updates"
  elif [[ -n "$prev_updates" ]]; then
    eval "sketchybar $prev_updates"
  fi
}

# Use this to detect if an item needs to be created
sketchybar_item_exists() {
  local item_name="$1"

  # Check if the item exists in SketchyBar's list of items
  if sketchybar --query "$item_name" &>/dev/null; then
    return 0  # Item exists
  else
    return 1  # Item does not exist
  fi
}

# Gets all existing workspace items from sketchybar efficiently
get_existing_workspace_items() {
  sketchybar --query bar | jq -r '.items[]?' | grep '^workspace\.' | sed 's/^workspace\.//'
}

# Creates a workspace and positions it correctly in the bar
# Use this when creating workspaces dynamically (not during initial setup)
create_and_position_workspace() {
  local workspace_id="$1"
  local existing_workspaces=$(get_existing_workspace_items)

  # Find the correct position
  local position_target="workspace_separator"
  for ws in $existing_workspaces; do
    if [[ "$ws" > "$workspace_id" ]]; then
      position_target="workspace.$ws"
      break
    fi
  done

  # Create workspace with positioning in single call
  create_workspace "$workspace_id" "$position_target"
}

# Moves a workspace item to the correct position relative to other workspace items
# This should be used whenever a new workspace item is created after initialization
# to ensure that the workspace items are sorted in the correct order
position_workspace_item() {
  local new_workspace="$1"

  # First, move the new workspace before workspace_separator to ensure correct section
  sketchybar --move "workspace.$new_workspace" before workspace_separator

  # Then find the correct position among other workspace items
  local all_workspaces=$(aerospace list-windows --monitor all --format "%{workspace}" | sort -u)
  local previous_workspace=""

  # Find the workspace that should come immediately before this one
  for ws in $all_workspaces; do
    if [[ "$ws" < "$new_workspace" ]] && sketchybar --query "workspace.$ws" &>/dev/null; then
      previous_workspace="$ws"
    elif [[ "$ws" > "$new_workspace" ]] && sketchybar --query "workspace.$ws" &>/dev/null; then
      # Found the first workspace after our new one, so position before it
      sketchybar --move "workspace.$new_workspace" before "workspace.$ws"
      return
    fi
  done

  # If we found a previous workspace, position after it
  if [[ -n "$previous_workspace" ]]; then
    sketchybar --move "workspace.$new_workspace" after "workspace.$previous_workspace"
  fi
}


# Expects the workspace id as the first argument
set_workspace_focused() {
  if ! sketchybar_item_exists "workspace.$1"; then
    create_and_position_workspace $1
  fi
  # show the focused workspace no matter what
  sketchybar --set workspace."$1" drawing=on \
                        icon.highlight=on \
                        label.highlight=on \
                        background.color="$(set_alpha $BLACK 60)"
}

# Expects the workspace id as the first argument
set_workspace_unfocused() {
  # First, set it to unfocused colors (very fast)
  sketchybar --set workspace."$1" \
                         background.color="$ITEM_BG_COLOR" \
                         label.color=0xFF$MUTED \
                         icon.background.color="0xFF$SUBTLE" \
                         background.border_color="0xFF$SUBTLE"

  #Afterwards, hide it if it has no windows (slower perf)
  # -z means "empty" - ie the workspace has no windows
  if [[ -z "$(aerospace list-windows --workspace $1)" ]]; then
    sketchybar --set workspace."$1" drawing=off
  fi

}

