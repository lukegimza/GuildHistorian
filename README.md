# Guild Historian

A World of Warcraft addon that passively records your guild's milestones and presents them in a browsable in-game timeline. Every boss kill, roster change, achievement, and loot drop is captured automatically so your guild's story is never lost.

## Features

- **Boss Kill Tracking** — Records boss kills with difficulty, group composition, and first-kill detection
- **Roster Monitoring** — Tracks members joining, leaving, rank changes, and max level achievements
- **Achievement Logging** — Captures guild and personal achievements
- **Loot Tracking** — Records notable loot drops received by guild members
- **Milestone Detection** — Celebrates guild milestones like member count thresholds, boss kill counts, and member anniversaries
- **"On This Day" Popup** — Shows you what happened on this day in your guild's history
- **Player Notes** — Add personal notes to your guild's timeline
- **Export** — Export your guild history as plain text for external use
- **Statistics** — View your guild's history at a glance with event breakdowns, most active members, and more

## Installation

1. Download the latest release
2. Extract the `GuildHistorian` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Restart WoW or type `/reload` if the game is running

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/gh` or `/gh toggle` | Toggle the main timeline window |
| `/gh note <text>` | Add a note to your guild's history |
| `/gh search <text>` | Search events by keyword |
| `/gh stats` | Show quick statistics in chat |
| `/gh export` | Open the export window |
| `/gh config` | Open the settings panel |
| `/gh debug` | Toggle debug mode |
| `/gh purge` | Purge all data for the current guild |

### Minimap Button

- **Left-click** — Toggle the timeline window
- **Right-click** — Open settings

### Timeline Window

The main window has three tabs:

1. **Timeline** — Browse all recorded events with filters for event type, date range, and text search
2. **Statistics** — View aggregate stats: total events, first kills, member tracking, and activity breakdown
3. **Settings** — Configure tracking options, display preferences, and data limits

## Configuration

All settings are accessible via `/gh config` or the Settings tab:

- **Tracking toggles** for boss kills, roster changes, achievements, and loot
- **Minimum loot quality** threshold (Uncommon through Legendary)
- **Minimap icon** visibility
- **"On This Day" popup** toggle
- **Maximum events** stored (1,000 to 10,000)

## Localization

Guild Historian includes translations for:
- English (complete)
- German (partial)
- French (partial)
- Spanish (partial)
- Brazilian Portuguese (partial)

Contributions for additional translations are welcome!

## Requirements

- World of Warcraft Retail
- Must be in a guild to track events

## Libraries

Guild Historian bundles the following libraries:
- [Ace3](https://www.wowace.com/projects/ace3) (AceAddon, AceDB, AceEvent, AceConsole, AceTimer)
- [LibStub](https://www.wowace.com/projects/libstub)
- [CallbackHandler](https://www.wowace.com/projects/callbackhandler)
- [LibDataBroker](https://www.wowace.com/projects/libdatabroker-1-1)
- [LibDBIcon](https://www.wowace.com/projects/libdbicon-1-0)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Author

**GIMZWARE**
