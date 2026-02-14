# Changelog

## [2.0.0] - 2026-02-14

### Changed — Complete Architecture Rewrite

Guild Historian v2 is a ground-up rewrite. The addon no longer tracks events locally via snapshot diffing. Instead, it reads directly from WoW's server-side APIs (guild achievements, guild news feed, guild roster, and guild event log) every time it loads. This means the addon works identically on any machine from the moment it's installed — no warm-up period, no data loss on reinstall.

### Added

- **Guild Dashboard** — New card-based home screen (replaces Statistics panel)
  - **Guild Pulse** — Total members, online count, achievement points, and completion %
  - **On This Day** — Guild achievements earned on this calendar date in previous years
  - **Recent Activity** — Live feed from guild news (boss kills, loot, achievements)
  - **Top Achievers** — Members with the most achievement points
  - **Activity Snapshot** — Summary of recent activity by type
  - **Class Composition** — Online max-level members grouped by class
  - **Achievement Progress** — Category-by-category progress bars
- **Achievement Timeline** — Full chronological history of guild achievements with real completion dates going back to guild creation
- **Guild News Feed** — Recent boss kills, loot, and achievements merged into a searchable timeline
- **Roster Activity** — Recent joins, leaves, promotions, and demotions from the guild event log
- **DataModules architecture** — AchievementScanner, NewsReader, RosterReader, EventLogReader
- **Dashboard-first navigation** — Window opens to Dashboard tab by default
- **Configurable dashboard cards** — Show/hide individual cards in Settings

### Removed

- **Local event tracking** — No more snapshot diffing, write queues, or data pruning
- **Database.lua** — Replaced by DataModules (API-driven, no local storage of events)
- **Modules/** directory — GuildRoster, BossKills, Achievements, LootTracker, MilestoneDetector, OnThisDay, Notes modules all removed
- **Detail Panel** — Click-to-expand event details removed (replaced by dashboard cards)
- **Export Frame** — Text export feature removed
- **Statistics Panel** — Replaced by Dashboard cards
- **Player Notes** — Freeform note feature removed
- **Purge command** — No longer needed (no local event data to purge)
- **Search command** — Replaced by filter bar in Timeline tab
- **Loot quality threshold** — No longer configurable (reads all news)
- **Max event limit** — No longer needed (reads from API, not local storage)

### Changed

- **TOC version** bumped to 2.0.0
- **Slash commands** simplified to `/gh toggle`, `/gh config`, `/gh debug`
- **Locale files** cleaned up: removed old v1 keys, kept valid translations
- **Test suite** expanded to 106 tests covering utils, data modules, and validation

## [1.0.0] - 2026-02-12

### Added

- **Timeline UI** — Browsable, filterable event timeline with date grouping and virtualized scrolling
- **Boss Kill Tracking** — Records encounter completions with difficulty, group size, and roster snapshots
- **First Kill Detection** — Identifies and highlights first-time boss kills per encounter/difficulty
- **Roster Monitoring** — Tracks members joining, leaving, rank changes, and max level achievements via snapshot diffing
- **Achievement Logging** — Records personal and guild achievements with point values
- **Loot Tracking** — Logs notable loot drops received by guild members, filterable by quality threshold
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
