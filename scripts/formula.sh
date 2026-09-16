#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?Usage: scripts/formula.sh VERSION}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
archive="eventkitcli-$version-macos-universal.tar.gz"
sha="$(shasum -a 256 "dist/$archive" | cut -d ' ' -f 1)"
cat <<FORMULA
class Eventkitcli < Formula
  desc "Read, create, and edit Apple Calendar events"
  homepage "https://github.com/leoshimo/eventkitcli"
  url "https://github.com/leoshimo/eventkitcli/releases/download/v$version/$archive"
  sha256 "$sha"
  depends_on macos: :ventura

  def install
    bin.install "bin/eventkitcli"
    doc.install "README.md"
    pkgshare.install "licenses"
  end

  def caveats
    <<~EOS
      Run eventkitcli setup to grant Calendar access before reading or editing events.
    EOS
  end

  test do
    assert_equal "$version", shell_output("#{bin}/eventkitcli --version").strip
    assert_match "Edit selected fields", shell_output("#{bin}/eventkitcli events edit --help")
    assert_match "Specify at least one field", shell_output("#{bin}/eventkitcli events edit nonexistent 2>&1", 64)
  end
end
FORMULA
