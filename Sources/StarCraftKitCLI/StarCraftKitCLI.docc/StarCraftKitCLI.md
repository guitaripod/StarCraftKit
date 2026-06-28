# ``StarCraftKitCLI``

A command-line interface for accessing StarCraft II esports data.

## Overview

`StarCraftKitCLI` provides a set of commands to interact with StarCraft II esports
data from your terminal. Track live matches, explore players, browse tournaments and
series, search across entities, export data, and open match streams — all from the
command line. The tool is built on top of ``StarCraftKit`` and the PandaScore API.

The executable command is `starcraft`.

## Installation

### Using Swift Package Manager

```bash
git clone https://github.com/guitaripod/StarCraftKit.git
cd StarCraftKit
swift build -c release
sudo cp .build/release/starcraft-cli /usr/local/bin/starcraft
```

Or run it directly from the package without installing:

```bash
swift run starcraft <command>
```

## Configuration

Set your PandaScore API token:

```bash
export PANDA_TOKEN="your-api-token"
```

Or add it to your shell configuration file (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
echo 'export PANDA_TOKEN="your-api-token"' >> ~/.zshrc
```

## Quick Start

```bash
# Currently running matches
starcraft live

# Today's matches
starcraft today

# Search for a player (or team/tournament)
starcraft search Serral
starcraft search Dragon --type team

# Upcoming matches
starcraft upcoming

# Find when a player plays next
starcraft player-schedule Serral
```

## Commands

### Live Tracking
- `live` — currently running matches
- `today` — today's match schedule
- `upcoming` — future matches

### Players
- `players` — list players
- `player-schedule` — a specific player's upcoming matches
- `player-matches` — a player's match history

### Tournaments, Series & Leagues
- `tournaments` — browse tournaments
- `tournament-matches` — a tournament's matches
- `series` — tournament series
- `leagues` — leagues

### Matches & Teams
- `matches` — list matches
- `teams` — list teams

### Search, Export & Streams
- `search` — universal search across players, teams, and tournaments (`--type`)
- `export` — export data
- `stream` — list and open the Twitch/YouTube streams attached to live matches

### Utilities
- `cache` — cache statistics and management (e.g. `cache stats`)
- `test` — exercise the API endpoints
- `debug` — diagnostics

> The `stream` command simply opens the Twitch/YouTube URLs that PandaScore embeds in
> match data. There is no live WebSocket streaming.

Use `--help` with any command to see all of its options:

```bash
starcraft --help
starcraft live --help
```

## Topics

### Subcommands
- ``LiveCommand``
- ``TodayCommand``
- ``UpcomingCommand``
- ``PlayersCommand``
- ``PlayerScheduleCommand``
- ``SearchCommand``
