# Guild Historian

A real-time guild dashboard and achievement browser for World of Warcraft. See your guild's pulse, recent activity, and full achievement history at a glance — from the moment you install it.

## Features

- **Guild Dashboard** — A card-based home screen showing your guild's vital signs
  - **Guild Pulse** — Total members, online count, achievement points, and completion progress
  - **On This Day** — Guild achievements earned on this calendar date in previous years
  - **Recent Activity** — Live feed of boss kills, loot drops, and achievements from the guild news
  - **Top Achievers** — Your guild's highest achievement point earners
  - **Activity Snapshot** — Quick summary of recent activity by type
  - **Class Composition** — Online max-level members grouped by class
  - **Achievement Progress** — Category-by-category progress bars for guild achievements
- **Achievement Timeline** — Full chronological history of guild achievements going back to guild creation
- **Guild News Feed** — Recent boss kills, loot, and achievements merged into a searchable timeline
- **Roster Activity** — Recent joins, leaves, promotions, and demotions
- **"On This Day" Popup** — Login notification showing what your guild accomplished on this date in past years
- **Filters & Search** — Filter timeline by type, date range, or keyword

## How It Works

Guild Historian reads directly from WoW's server-side data. No local event tracking is needed — the addon works identically on any install, any machine, from the moment it loads.

- **Guild achievements** provide a complete historical record with real completion dates
- **Guild news feed** provides recent weeks of boss kills, loot, and achievements
- **Guild roster** provides current member data and achievement points
- **Guild event log** provides recent roster changes (joins, leaves, promotions)

## Installation

1. Download the latest release
2. Extract the `GuildHistorian` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Restart WoW or type `/reload` if the game is running

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/gh` or `/gh toggle` | Toggle the main window |
| `/gh config` | Open the settings panel |
| `/gh debug` | Toggle debug mode |

### Minimap Button

- **Left-click** — Toggle the main window
- **Right-click** — Open settings

### Main Window

The window has three tabs:

1. **Dashboard** — Card-based overview of your guild's current state
2. **Timeline** — Chronological list of achievements, news, and roster changes with filters
3. **Settings** — Toggle minimap icon, On This Day popup, and individual dashboard cards

## Configuration

All settings are accessible via `/gh config` or the Settings tab:

- **Display:** Minimap icon visibility, On This Day popup toggle
- **Dashboard Cards:** Show/hide individual cards (Guild Pulse, On This Day, Recent Activity, Top Achievers, Activity Snapshot, Class Composition, Achievement Progress)

## Localization

Guild Historian includes translations for:
- English (complete)
- German (partial)
- French (partial)
- Spanish (partial)
- Brazilian Portuguese (partial)

## Requirements

- World of Warcraft Retail (The War Within)
- Must be in a guild

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
