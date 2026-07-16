#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo/home/.chezmoiscripts/run_after_5-sync-ai-extensions.sh"

[[ "$(json_version '{"version":"0.9.2"}')" == "0.9.2" ]]

(
  npm_latest() { return 1; }
  with_timeout() { return 1; }
  sync_skills() { return 1; }
  main >/dev/null
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_CACHE_HOME="$tmp/cache"
manifest="$XDG_CACHE_HOME/opencode/packages/example/plugin@latest/node_modules/example/plugin/package.json"
mkdir -p "$(dirname "$manifest")"
printf '%s\n' '{"version":"1.0.0"}' >"$manifest"
mkdir -p "$tmp/bin"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$tmp/bin/opencode"
chmod +x "$tmp/bin/opencode"
PATH="$tmp/bin:$PATH"
! update_opencode example/plugin 2.0.0 >/dev/null
[[ "$(json_version "$(<"$manifest")")" == "1.0.0" ]]

printf '%s\n' \
  '#!/bin/sh' \
  'package="$2"' \
  'manifest="$XDG_CACHE_HOME/opencode/packages/${package}@latest/node_modules/$package/package.json"' \
  'mkdir -p "$(dirname "$manifest")"' \
  'printf '\''%s\n'\'' '\''{"version":"2.0.0"}'\'' >"$manifest"' \
  >"$tmp/bin/opencode"
update_opencode example/plugin 2.0.0 >/dev/null
[[ "$(json_version "$(<"$manifest")")" == "2.0.0" ]]

cache="$XDG_CACHE_HOME/opencode/packages/example/plugin@latest"
mv "$cache" "${cache}.previous"
printf '%s\n' '#!/bin/sh' 'exit 1' >"$tmp/bin/opencode"
! update_opencode example/plugin 3.0.0 >/dev/null
[[ "$(json_version "$(<"$manifest")")" == "2.0.0" ]]
