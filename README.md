# eventkitcli - CLI to Apple's EventKit Framework

`eventkitcli` is a CLI interface to interacting with Apple's [EventKit Framework](https://developer.apple.com/documentation/eventkit).

## Usage

```shell
# Initial setup for permissions
$ eventkitlcli setup

# Adding Events:
$ eventkitcli add-event --title "Hello World" \
    --start-date "now" \
    --end-date "in one hour"
$ eventkitcli add-event --title "My Event" \
    --start-date "now" \
    --end-date "in one hour"
$ eventkitcli add-event --title "My Event" \
    --start-date "1/1/2024" \
    --end-date "1/2/2024"
$ eventkitcli add-event --title "My Event" \
    --start-date "1/1/2024 8AM" \
    --end-date "in one hour"
$ eventkitcli add-event --title "My Event" \
    --start-date "today at 9am" \
    --end-date "today at 11am"
```

## Installation

1. Install [mint](https://github.com/yonaskolb/Mint)
2. Add `~/.mint/bin` to shell `PATH`
3. Run `mint install leoshimo/eventkitcli@main`
