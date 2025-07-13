#!/bin/bash

osascript <<EOF
tell application "System Events"
    key code 111 using {command down, control down, shift down}
end tell
EOF