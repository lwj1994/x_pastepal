#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build --target XPastepalCore
build_directory=$(swift build --show-bin-path)
probe_directory=$(mktemp -d /tmp/xpastepal-click-probe.XXXXXXXX)
trap 'rm -rf "$probe_directory"' EXIT
swiftc -target "$(uname -m)-apple-macosx14.0" -I "$build_directory/Modules" \
  Sources/XPastepal/ClipCard.swift \
  Sources/XPastepal/ClipClickActions.swift \
  Sources/XPastepal/ClipImageThumbnail.swift \
  Sources/XPastepal/SourceAppIconView.swift \
  Sources/XPastepal/LibrarySupportingViews.swift \
  "$build_directory"/XPastepalCore.build/*.swift.o \
  scripts/fixtures/main.swift -o "$probe_directory/probe"
"$probe_directory/probe"
"$probe_directory/probe" --list
