# eventkitcli

Read, create, and edit Apple Calendar events through [EventKit](https://developer.apple.com/documentation/eventkit).

## Install

```sh
brew install leoshimo/tap/eventkitcli
# Later:
brew upgrade leoshimo/tap/eventkitcli

eventkitcli setup
```

The Homebrew package supports macOS 13+ on Apple Silicon and Intel. Grant full Calendar access when prompted by `setup`. If denied, enable access for the responsible app (for example Terminal) in System Settings → Privacy & Security → Calendars, then retry. Other commands fail with an actionable error rather than requesting access or returning a misleading empty result.

If you previously installed with Mint, check `which -a eventkitcli`: a Mint binary earlier in PATH can shadow Homebrew. Invoke `$(brew --prefix)/bin/eventkitcli` explicitly or remove the old Mint installation when ready.

## Discover events and calendars

```sh
# The existing human-readable format remains the default.
eventkitcli events -s 'today at 0h' -e 'tomorrow at 0h'

# JSON array, sorted by start date. Calendar filtering is optional.
eventkitcli events get -s 2026-09-16 -e 2026-09-23 --json
eventkitcli cal --json
eventkitcli cal --default --format id
```

Event JSON includes `id`, `title`, `start_date`, `end_date`, `is_all_day`, `calendar_id`, `calendar_title`, `is_recurring`, and `is_detached`. Repeating occurrences also include `occurrence` (their **current start**, used for editing) and `original_occurrence_date`. Optional `time_zone` is the event's time zone identifier. Optional fields are omitted when absent. Dates are ISO 8601 UTC timestamps with milliseconds; `YYYY-MM-DD` input and natural-language dates use your local time zone. All-day dates represent local calendar days, so their UTC timestamp need not be midnight.

Use the exact `id` from discovery, never a title or an array position. It is EventKit's persistent local event identifier, not a portable cross-device ID. Calendar moves, synchronization, and recurrence edits can change it. Create and edit return the saved record; keep its current ID and refresh discovery if a saved selector stops matching. `--json` works before or after the subcommand and is equivalent to `--format json`. JSON uses snake_case fields. Writes return one object; discovery returns an array, including `[]` for no matches. `--format id` prints only IDs. Commands send failures to stderr with a nonzero exit status.

## Create and edit

```sh
eventkitcli events create --title 'Planning' \
  --start-date 'tomorrow at 9am' --end-date 'tomorrow at 10am' --json

# Replace EVENT_ID and CALENDAR_ID with values from discovery.
eventkitcli events edit EVENT_ID --title 'Weekly planning' --json
eventkitcli events edit EVENT_ID \
  --start-date '2026-09-17T09:00:00-07:00' \
  --end-date '2026-09-17T10:30:00-07:00' --json
eventkitcli events edit EVENT_ID --calendar CALENDAR_ID --json

# One all-day event on September 18; the end date is exclusive.
eventkitcli events edit EVENT_ID --all-day \
  --start-date 2026-09-18 --end-date 2026-09-19 --json

# Switch back to a timed event.
eventkitcli events edit EVENT_ID --timed \
  --start-date '2026-09-18T09:00:00-07:00' \
  --end-date '2026-09-18T10:00:00-07:00' --json
```

Only supplied fields change. Editing just the start does **not** move the end or preserve duration automatically. End must be after start. All-day boundaries use calendar midnights and an exclusive end; a one-day event requires the following day as its end. Switching between timed and all-day requires both dates. Titles cannot be blank, and read-only calendars cannot be modified. Notes, location, alarms, attendees, and recurrence rules are outside the editing command's scope and are left alone. Edits to existing invitations may cause the calendar provider to notify attendees.

### Repeating events

```sh
# Copy BOTH id and occurrence from the selected JSON record.
eventkitcli events edit EVENT_ID \
  --occurrence '2026-09-18T16:00:00.000Z' --title 'This meeting only' --json
```

Repeating events (including detached exceptions) require `--occurrence`. It must be the exact `occurrence` value from fresh JSON discovery, not a natural-language date or the original occurrence date of a moved exception. The command resolves the exact ID/current-start pair and saves with `EKSpan.thisEvent`. A missing or ambiguous match fails without saving. If an occurrence moves, refresh discovery before editing it again.

**Whole-series and this-and-future edits are not supported.** An ID alone never silently edits the first occurrence of a series. There is no delete command.

## Development and releases

```sh
swift test --force-resolved-versions
swift run eventkitcli --help
swift run eventkitcli events edit --help
./scripts/package.sh v0.1.0
./scripts/formula.sh 0.1.0 > dist/eventkitcli.rb
```

Use Xcode 15+ / Swift 5.9+ on macOS. Dependencies are pinned in both the manifest and lockfile. Packaging builds arm64 and x86_64, checks both slices, embeds Calendar permission descriptions, signs ad hoc, and produces a tarball and SHA-256 file. Release workflow runs the tests, builds the archive and formula, and publishes them for a matching `v*` tag. Copy the **released** formula (whose checksum matches the CI-built asset) to `leoshimo/homebrew-tap`, then run `brew install` and `brew test`.

The build is repeatable from a tagged source and pinned dependencies; byte-for-byte reproducibility across different Xcode versions is not claimed. The archive includes third-party license notices. Live integration tests are opt-in: `scripts/test-live.sh` creates uniquely marked disposable events in writable calendars, modifies only those events, then removes them and verifies cleanup. A cross-calendar move is exercised when two writable calendars are available. It requires existing Calendar access; unit tests and formula tests do not touch calendar data.
