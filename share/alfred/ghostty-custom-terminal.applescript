-- Ghostty Alfred custom terminal script
-- Requires Ghostty 1.3.0+ AppleScript support.
--
-- Quick Terminal mode:
-- Ghostty's AppleScript can toggle the Quick Terminal, but the Quick
-- Terminal is not reliably exposed as front window/terminal for direct
-- "input text" targeting. Therefore this script shows the Quick Terminal,
-- then pastes the Alfred command into the currently focused UI surface and presses Return.
--
-- This dotfiles repo configures:
-- keybind = global:super+backslash=toggle_quick_terminal

property use_quick_terminal : true
property quick_terminal_action : "toggle_quick_terminal"
property quick_terminal_settle_delay : 0.20
property restore_clipboard_after_paste : true

-- Fallback behavior when use_quick_terminal is false
property open_in_new_window : false
property open_in_new_tab : true
property ghostty_opens_quietly : false

on new_window()
  tell application "Ghostty"
    set win to new window
    activate window win
  end tell
end new_window

on new_tab()
  tell application "Ghostty"
    set t to new tab in front window
    select tab t
    focus focused terminal of t
  end tell
end new_tab

on call_forward()
  tell application "Ghostty" to activate
end call_forward

on is_running()
  application "Ghostty" is running
end is_running

on has_windows()
  if not is_running() then return false

  tell application "Ghostty"
    if (count of windows) is 0 then return false

    try
      set term to focused terminal of selected tab of front window
    on error
      return false
    end try
  end tell

  return true
end has_windows

on wait_for_window()
  repeat 500 times
    if has_windows() then return true
    delay 0.01
  end repeat

  return false
end wait_for_window

on trigger_quick_terminal_hotkey()
  -- Physical backslash key with Command. Matches:
  -- keybind = global:super+backslash=toggle_quick_terminal
  tell application "System Events"
    key code 42 using command down
  end tell
end trigger_quick_terminal_hotkey

on show_quick_terminal()
  if not is_running() then
    call_forward()
    delay 0.30
  end if

  if has_windows() then
    -- Prefer the native Ghostty action when a terminal target exists.
    tell application "Ghostty"
      set term to focused terminal of selected tab of front window
      perform action quick_terminal_action on term
    end tell
  else
    -- If no AppleScript-visible terminal exists, fall back to the configured
    -- global keybind.
    trigger_quick_terminal_hotkey()
  end if

  delay quick_terminal_settle_delay
end show_quick_terminal

on paste_text_to_focused_surface(custom_text)
  set old_clipboard to missing value

  if restore_clipboard_after_paste then
    try
      set old_clipboard to the clipboard
    end try
  end if

  set the clipboard to custom_text
  delay 0.05

  tell application "System Events"
    keystroke "v" using command down
    delay 0.05
    key code 36 -- Return
  end tell

  delay 0.20

  if restore_clipboard_after_paste and old_clipboard is not missing value then
    set the clipboard to old_clipboard
  end if
end paste_text_to_focused_surface

on send_text(custom_text)
  tell application "Ghostty"
    set term to focused terminal of selected tab of front window
    input text (custom_text & linefeed) to term
  end tell
end send_text

on alfred_script(query)
  if use_quick_terminal then
    show_quick_terminal()
    paste_text_to_focused_surface(query)
    return
  end if

  if has_windows() then
    if open_in_new_window then
      new_window()
    else if open_in_new_tab then
      new_tab()
    else
      -- Reuse current tab
    end if
  else
    if is_running() or ghostty_opens_quietly then
      new_window()
    else
      call_forward()
    end if
  end if

  if wait_for_window() then
    send_text(query)
    call_forward()
  end if
end alfred_script
