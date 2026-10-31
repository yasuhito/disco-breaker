#!/usr/bin/env bash
set -euo pipefail

# npm's browser-test assets are not Godot resources (some vendor fonts also
# crash the importer). Keep repeat validation safe after running npm ci.
if [[ -d node_modules ]]; then
  touch node_modules/.gdignore
fi

godot --headless --path . --import
godot --headless --path . --check-only --script res://src/tutorial_view.gd
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/title_flow.gd
godot --headless --path . --script res://tools/headless_driver.gd
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
