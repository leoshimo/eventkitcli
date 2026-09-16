#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export MACOSX_DEPLOYMENT_TARGET=13.0
swift build -c release --arch arm64 --arch x86_64 --force-resolved-versions
binary="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/eventkitcli"
version="$("$binary" --version)"
if [[ $# -gt 0 && "$1" != "v$version" ]]; then
  echo "Tag $1 does not match executable version $version" >&2
  exit 1
fi
stage="dist/eventkitcli-$version"
mkdir -p "$stage/bin" "$stage/licenses"
install -m 755 "$binary" "$stage/bin/eventkitcli"
codesign --force --sign - --identifier com.leoshimo.eventkitcli "$stage/bin/eventkitcli"
install -m 644 README.md "$stage/README.md"
install -m 644 .build/checkouts/swift-argument-parser/LICENSE.txt "$stage/licenses/swift-argument-parser.txt"
install -m 644 .build/checkouts/SwiftyChrono/LICENSE "$stage/licenses/SwiftyChrono.txt"
lipo "$stage/bin/eventkitcli" -verify_arch arm64 x86_64
codesign --verify --strict "$stage/bin/eventkitcli"
archive="eventkitcli-$version-macos-universal.tar.gz"
COPYFILE_DISABLE=1 tar -czf "dist/$archive" -C dist "eventkitcli-$version"
(cd dist && shasum -a 256 "$archive" > "$archive.sha256")
echo "Packaged dist/$archive"
