#!/bin/bash

### START-OF-ICON-MAP
function __icon_map() {
  case "$1" in
    "Ableton Live" | "Live")
      icon_result=":ableton_live:"
      ;;
    "Activity Monitor")
      icon_result=":activity_monitor:"
      ;;
    "Acrobat Reader")
      icon_result=":adobe_acrobat_reader_dc:"
      ;;
    "Affinity Designer 2")
      icon_result=":affinity_designer:"
      ;;
    "Affinity Photo 2")
      icon_result=":affinity_photo:"
      ;;
    "Affinity Publisher 2")
      icon_result=":affinity_publisher:"
      ;;
    "Alacritty")
      icon_result=":alacritty:"
      ;;
    "Amazon Music")
      icon_result=":amazon_music:"
      ;;
    "Amazon Q")
      icon_result=":amazonq:"
      ;;
    "AnyDesk")
      icon_result=":anydesk:"
      ;;
    "AppCleaner")
      icon_result=":app_cleaner:"
      ;;
    "App Store")
      icon_result=":app_store:"
      ;;
    "Arc")
      icon_result=":arc:"
      ;;
    "Fusion" | "Fusion Service Utility")
      icon_result=":autodesk_fusion:"
      ;;
    "Bitwig Studio")
      icon_result=":bitwing_studio:"
      ;;
    "Blender")
      icon_result=":blender:"
      ;;
    "Books")
      icon_result=":books:"
      ;;
    "Brave Browser")
      icon_result=":brave_browser:"
      ;;
    "Calculator")
      icon_result=":calculator:"
      ;;
    "Calendar")
      icon_result=":calendar:"
      ;;
    "ChatGPT")
      icon_result=":chatgpt:"
      ;;
    "Google Chrome")
      icon_result=":chrome:"
      ;;
    "Claude")
      icon_result=":claude:"
      ;;
    "Clock")
      icon_result=":clock:"
      ;;
    "CotEditor")
      icon_result=":coteditor:"
      ;;
    "Cursor")
      icon_result=":cursor:"
      ;;
    "DataSpell")
      icon_result=":dataspell:"
      ;;
    "default")
      icon_result=":default:"
      ;;
    "DEVONthink" | "DEVONthink 3")
      icon_result=":devonthink:"
      ;;
    "Discord")
      icon_result=":discord:"
      ;;
    "Docker Desktop")
      icon_result=":docker:"
      ;;
    "Drafts")
      icon_result=":drafts:"
      ;;
    "Easy CSV Editor")
      icon_result=":easy_csv_editor:"
      ;;
    "FaceTime")
      icon_result=":facetime:"
      ;;
    "Figma")
      icon_result=":figma:"
      ;;
    "Filen Drive")
      icon_result=":filen_drive:"
      ;;
    "Finder")
      icon_result=":finder_thick:"
      ;;
    "Firefox Developer Edition")
      icon_result=":firefox:"
      ;;
    "Font Book")
      icon_result=":font_book:"
      ;;
    "Ghostty")
      icon_result=":ghostty2:"
      ;;
    "GitHub Desktop")
      icon_result=":github_desktop:"
      ;;
    "Goodnotes")
      icon_result=":goodnotes:"
      ;;
    "Google Docs")
      icon_result=":google_docs:"
      ;;
    "Google Drive")
      icon_result=":google_drive:"
      ;;
    "Goggle Sheets")
      icon_result=":google_sheets:"
      ;;
    "Google Sheets")
      icon_result=":google_slides:"
      ;;
    "Hammerspoon")
      icon_result=":hammerspoon:"
      ;;
    "Hoppscotch")
      icon_result=":hoppscotch:"
      ;;
    "Inkscape")
      icon_result=":inkscape:"
      ;;
    "iTerm2")
      icon_result=":iterm:"
      ;;
    "Karabiner-Elements")
      icon_result=":karabiner_elements:"
      ;;
    "Karabiner-EventViewer")
      icon_result=":karabiner_eventviewer:"
      ;;
    "Keynote")
      icon_result=":keynote:"
      ;;
    "KiCad")
      icon_result=":kicad:"
      ;;
    "Kindle")
      icon_result=":kindle:"
      ;;
    "kitty")
      icon_result=":kitty:"
      ;;
    "LaTeXiT")
      icon_result=":latexit:"
      ;;
    "LINE")
      icon_result=":line:"
      ;;
    "LTspice")
      icon_result=":ltspice:"
      ;;
    "Mail")
      icon_result=":mail:"
      ;;
    "Maps")
      icon_result=":maps:"
      ;;
    "Messages")
      icon_result=":messages:"
      ;;
    "Microsoft Excel")
      icon_result=":microsoft_excel:"
      ;;
    "Microsoft OneNote")
      icon_result=":microsoft_onenote:"
      ;;
    "Microsoft Outlook")
      icon_result=":microsoft_outlook:"
      ;;
    "Microsoft PowerPoint")
      icon_result=":microsoft_powerpoint:"
      ;;
    "Microsoft Remote Desktop")
      icon_result=":microsoft_remotedesktop:"
      ;;
    "Microsoft Teams classic")
      icon_result=":microsoft_teams:"
      ;;
    "Microsoft To Do")
      icon_result=":microsoft_todo:"
      ;;
    "Microsoft Word")
      icon_result=":microsoft_word:"
      ;;
    "Music")
      icon_result=":music:"
      ;;
    "Neovide" | "Neovim")
      icon_result=":neovide:"
      ;;
    "Notes")
      icon_result=":notes:"
      ;;
    "Notion")
      icon_result=":notion:"
      ;;
    "Notion Calendar")
      icon_result=":notion_calendar:"
      ;;
    "Numbers")
      icon_result=":numbers:"
      ;;
    "Obsidian")
      icon_result=":obsidian:"
      ;;
    "OneDrive")
      icon_result=":onedrive:"
      ;;
    "paw")
      icon_result=":paw:"
      ;;
    "Photos")
      icon_result=":photos:"
      ;;
    "Pixelmator" | "Pixelmator Pro")
      icon_result=":pixelmator:"
      ;;
    "Podcasts")
      icon_result=":podcasts:"
      ;;
    "Preview")
      icon_result=":preview_2:"
      ;;
    "PrusaSlicer")
      icon_result=":prusa_slicer:"
      ;;
    "PyCharm")
      icon_result=":pycharm:"
      ;;
    "pyhton")
      icon_result=":python:"
      ;;
    "python3.5" | "python3.6" | "python3.7" | "python3.8" | \
    "python3.9" | "python3.10" | "python3.11" | "python3.12" | "python3.13")
      icon_result=":python:"
      ;;
    "qBittorrent")
      icon_result=":qbittorrent:"
      ;;
    "QMK Toolbox")
      icon_result=":qmk:"
      ;;
    "REAPER")
      icon_result=":reaper:"
      ;;
    "Safari")
      icon_result=":safari:"
      ;;
    "Sequel Ace")
      icon_result=":sequel_ace:"
      ;;
    "Skim")
      icon_result=":skim:"
      ;;
    "Slack")
      icon_result=":slack:"
      ;;
    "Spark")
      icon_result=":spark:"
      ;;
    "Spotify")
      icon_result=":spotify:"
      ;;
    "System Settings")
      icon_result=":system_settings_simple_big:"
      ;;
    "Tailescale")
      icon_result=":tailscale:"
      ;;
    "TeamViewer")
      icon_result=":teamviewer:"
      ;;
    "Terminal")
      icon_result=":terminal:"
      ;;
    "TeXShop")
      icon_result=":texshop:"
      ;;
    "TickTick")
      icon_result=":ticktick:"
      ;;
    "Todoist")
      icon_result=":todoist:"
      ;;
    "UpNote")
      icon_result=":upnote:"
      ;;
    "VESTA")
      icon_result=":vesta:"
      ;;
    "Vivaldi")
      icon_result=":vivaldi:"
      ;;
    "Code")
      icon_result=":vscode:"
      ;;
    "Warp")
      icon_result=":warp:"
      ;;
    "WezTerm")
      icon_result=":wezterm:"
      ;;
    "XQuartz")
      icon_result=":xquartz:"
      ;;
    "Zed")
      icon_result=":zed:"
      ;;
    "Zen Browser")
      icon_result=":zen_browser:"
      ;;
    "zoom" | "zoom.us")
      icon_result=":zoom:"
      ;;
    *)
      icon_result=":default:"
      ;;
  esac
}
### END-OF-ICON-MAP
# Process all arguments in batch (eliminates subprocess overhead)
for app_name in "$@"; do
    __icon_map "$app_name"
    echo -n " $icon_result"
done
