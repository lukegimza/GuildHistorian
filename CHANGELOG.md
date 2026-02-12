# Changelog

## [1.0.0] - 2026-02-12

### Added

- **Timeline UI** — Browsable, filterable event timeline with date grouping and virtualized scrolling
- **Boss Kill Tracking** — Records encounter completions with difficulty, group size, and roster snapshots
- **First Kill Detection** — Identifies and highlights first-time boss kills per encounter/difficulty
- **Roster Monitoring** — Tracks member joins, leaves, rank changes, and max level achievements via snapshot diffing
- **Achievement Logging** — Records personal and guild achievements with point values
- **Loot Tracking** — Logs notable loot received by guild members, filterable by quality threshold
- **Milestone Detection** — Celebrates guild milestones: member count thresholds, kill counts, and member anniversaries
- **"On This Day" Popup** — Login notification showing events from this day in previous years
- **Player Notes** — Add freeform notes to the guild timeline or to specific events
- **Export** — Export full guild history as plain text for external use
- **Statistics Panel** — Overview of total events, first kills, member tracking, activity leaders, and event type breakdown
- **Settings Panel** — In-game configuration for tracking, display, and data management options
- **Minimap Button** — LibDataBroker minimap icon with left-click toggle and right-click settings
- **Filter Bar** — Filter timeline by event type, text search, date range presets
- **Detail Panel** — Click any event for full details including roster, notes, and metadata
- **Slash Commands** — `/gh toggle`, `/gh note`, `/gh search`, `/gh stats`, `/gh export`, `/gh config`, `/gh purge`, `/gh debug`
- **Localization** — English (complete), German, French, Spanish, Brazilian Portuguese (partial)
- **Deduplication** — djb2 hash-based dedup prevents duplicate event recording
- **Write Queue** — Batched 5-second flush cycle reduces save overhead during burst activity
- **Data Pruning** — Automatic pruning to configurable max event limit
- **Purge Command** — Safely delete all data for the current guild with confirmation
