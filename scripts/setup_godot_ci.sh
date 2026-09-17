#!/usr/bin/env bash
# Installs the exact pinned Godot 4.7.2 editor and export templates used by
# scripts/check.sh, verifying each download against a pinned SHA-256 so CI
# always builds with the same engine as local development.
set -euo pipefail

godot_version="4.7.2-stable"
editor_zip="Godot_v4.7.2-stable_linux.x86_64.zip"
editor_sha256="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
templates_tpz="Godot_v4.7.2-stable_export_templates.tpz"
templates_sha256="f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
release_url="https://github.com/godotengine/godot/releases/download/${godot_version}"

install_root="${GODOT_INSTALL_ROOT:-$HOME/.local/share/godot-ci}"
templates_dir="$HOME/.local/share/godot/export_templates/${godot_version}"

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(sha256sum "$file" | cut -d' ' -f1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "checksum mismatch for $file: expected $expected, got $actual" >&2
    exit 1
  fi
}

if [[ ! -x "$install_root/godot" ]]; then
  mkdir -p "$install_root"
  curl --fail --silent --location --output "$install_root/$editor_zip" "$release_url/$editor_zip"
  verify_sha256 "$install_root/$editor_zip" "$editor_sha256"
  unzip -q -o "$install_root/$editor_zip" -d "$install_root"
  mv "$install_root/Godot_v4.7.2-stable_linux.x86_64" "$install_root/godot"
  chmod +x "$install_root/godot"
  rm "$install_root/$editor_zip"
fi

if [[ ! -f "$templates_dir/web_release.zip" ]]; then
  mkdir -p "$templates_dir"
  workdir="$(mktemp -d)"
  curl --fail --silent --location --output "$workdir/$templates_tpz" "$release_url/$templates_tpz"
  verify_sha256 "$workdir/$templates_tpz" "$templates_sha256"
  unzip -q -o "$workdir/$templates_tpz" -d "$workdir"
  cp -r "$workdir/templates/." "$templates_dir/"
  rm -rf "$workdir"
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$install_root" >>"$GITHUB_PATH"
fi
