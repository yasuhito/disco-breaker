#!/usr/bin/env bash
set -euo pipefail

godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tools/headless_driver.gd
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
