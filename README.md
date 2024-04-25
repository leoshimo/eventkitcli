# eventkitcli - CLI to Apple's EventKit Framework

`eventkitcli` is a CLI interface to interacting with Apple's [EventKit Framework](https://developer.apple.com/documentation/eventkit).

## Usage

```shell
# Initial setup for permissions
$ eventkitlcli setup

# Fetching Events
$ eventkitcli events -s "today @ 0h" -e "today @ 24h"

# Creating Events
$ eventkitcli events create --title "Hello World" \
    --start-date "now" \
    --end-date "in one hour"
$ eventkitcli events create --title "My Event" \
    --start-date "1/1/2024" \
    --end-date "1/2/2024"
$ eventkitcli events create --title "My Event" \
    --start-date "1/1/2024 8AM" \
    --end-date "in one hour"
$ eventkitcli events create --title "My Event" \
    --start-date "today at 9am" \
    --end-date "today at 11am"
```

## Installation

1. Install [mint](https://github.com/yonaskolb/Mint)
2. Add `~/.mint/bin` to shell `PATH`
3. Run `mint install --force leoshimo/eventkitcli@main` (initial installation and upgrades)

## Development

```shell
$ swift run eventkitcli setup
$ swift run eventkitcli add-event ...
```
