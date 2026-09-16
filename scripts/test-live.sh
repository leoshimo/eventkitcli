#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Explicitly opt in. Only uniquely marked events created by this test are modified or removed.
swift build --force-resolved-versions
export EVENTKITCLI_BINARY="${EVENTKITCLI_BINARY:-$(swift build --show-bin-path)/eventkitcli}"
export EVENTKITCLI_LIVE_TESTS=1
swift test --force-resolved-versions --filter LiveEventTests
