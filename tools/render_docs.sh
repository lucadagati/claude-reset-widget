#!/bin/bash
# Re-generates docs/menu.png and docs/menubar.png from the real widget code with fictional data.
set -e
cd "$(dirname "$0")/.."
T=$(mktemp -d)
sed '/^let app = NSApplication.shared/,$d' main.swift > "$T/main.swift"
cat tools/harness.swift >> "$T/main.swift"
swiftc "$T/main.swift" -o "$T/render"
mkdir -p docs && "$T/render" docs
