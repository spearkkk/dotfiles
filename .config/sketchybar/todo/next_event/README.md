# Next Event Item

## Goal

Add a SketchyBar item that shows the next upcoming calendar event for today.

- Show only the next event in the bar.
- Change border color as the event gets closer.
- On click, show all events scheduled for today.
- Work Mac: show both company Google Calendar and macOS Calendar events.
- Personal Mac: show macOS Calendar events only.

## Recommended Data Source

Use macOS Calendar as the single source of truth.

```text
Google Calendar account -> macOS Calendar
Personal Calendar -> macOS Calendar
SketchyBar -> icalBuddy -> macOS Calendar database
```

This keeps the SketchyBar code the same across work and personal machines. If the company Google account is added to Calendar.app, both company and personal events can be read through the same path.

## Required Tool

Install `ical-buddy`:

```sh
brew install ical-buddy
```

`icalBuddy` reads events and tasks from the macOS Calendar database. It is available through Homebrew as `ical-buddy`.

## Alternative

If company Google Calendar cannot be added to macOS Calendar, use `gcalcli` as a second source.

```text
icalBuddy -> macOS Calendar events
gcalcli -> Google Calendar events
daemon -> merge/sort events
```

This is more complex because it requires Google OAuth/API setup and result merging.

## Proposed Files

```text
.config/sketchybar/helpers/calendar_daemon.sh
.config/sketchybar/items/next_event.lua
/tmp/sketchybar_next_event.json
/tmp/sketchybar_next_event.tsv
```

## Architecture

Do not query calendars directly from Lua callbacks.

Use the same pattern as `media`:

```text
calendar_daemon.sh
-> run icalBuddy periodically
-> parse today's events
-> compute next upcoming event
-> write cache atomically
-> sketchybar --trigger calendar_change

next_event.lua
-> read cache only
-> render next event
-> show today's events in popup on click
```

This avoids blocking SketchyBar's Lua event loop.

## Cache Format

JSON for debugging:

```json
{
  "ok": true,
  "updated_at": 1783425000,
  "next": {
    "title": "Sync",
    "start_epoch": 1783428600,
    "end_epoch": 1783430400,
    "calendar": "Work"
  },
  "events": [
    {
      "title": "Standup",
      "start_epoch": 1783418400,
      "end_epoch": 1783419300,
      "calendar": "Work"
    }
  ]
}
```

TSV for cheap Lua reads:

```text
updated_at<TAB>ok<TAB>next_start<TAB>next_end<TAB>next_title<TAB>events_serialized
```

## Bar Display

Example:

```text
􀉉 14:00 Sync
```

Hide the item when there are no remaining events today.

## Border Color Rules

Use time until next event:

```text
> 60 min: dim/base04
<= 60 min: blue/base0d
<= 15 min: yellow/base0a
<= 5 min or ongoing: red/base08
```

## Popup

Click behavior:

```text
10:00 Standup
14:00 Sync
16:30 1:1
```

The popup should list all remaining events today, sorted by start time.

## Refresh Policy

Daemon interval:

```text
Normal: 5 min
Within 60 min of next event: 1 min
Within 15 min of next event: 30 sec
```

Lua item:

```text
calendar_change -> reread cache
routine -> update border urgency from cached timestamps
```

## Open Questions

- Should all-day events be shown or ignored?
- Should ongoing events be shown as current event, or should the item skip to the next future event?
- Should declined/canceled events be filtered?
- Should private events show the title or just "Busy"?
- Should work and personal calendars use different icons/colors?

## References

- `icalBuddy`: https://github.com/ali-rantakari/icalBuddy
- Homebrew formula: https://formulae.brew.sh/formula/ical-buddy
- `gcalcli`: https://github.com/insanum/gcalcli
