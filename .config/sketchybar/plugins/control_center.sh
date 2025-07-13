#!/bin/bash

osascript <<EOF
tell application "System Events"
    key code 103 using {command down, control down, shift down}
end tell
EOF