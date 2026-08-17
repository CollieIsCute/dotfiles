#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
modifier="$repo_root/home/dot_config/codexbar/modify_private_config.json"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

rg -qx '      - codexbar-cli-bin' "$repo_root/home/.chezmoidata/packages.yaml"
[[ ! -e "$repo_root/home/.chezmoiscripts/run_after_4-update-codexbar.sh.tmpl" ]]
! rg -q 'codexbarPath' "$repo_root/home/dot_config/noctalia/config.toml"

fixture='{"version":1,"providers":[{"id":"codex","enabled":false,"source":"cli","apiKey":"keep-me"},{"id":"openrouter","enabled":true,"source":"api","custom":"keep"}],"customRoot":"keep"}'
render() {
  chezmoi --persistent-state "$tmp_dir/state.boltdb" --cache "$tmp_dir/cache" \
    execute-template --with-stdin --file "$modifier"
}

result="$(printf '%s' "$fixture" | render)"
assertions='{{- $config := fromJson .chezmoi.stdin -}}
{{- $codex := index $config.providers 0 -}}
{{- $other := index $config.providers 1 -}}
{{- $claude := index $config.providers 2 -}}
{{- if or (ne $config.customRoot "keep") (ne $codex.id "codex") (not $codex.enabled) (ne $codex.source "oauth") (ne $codex.apiKey "keep-me") (ne $other.id "openrouter") (ne $other.custom "keep") (ne $claude.id "claude") (not $claude.enabled) (ne $claude.source "oauth") -}}
{{- fail "CodexBar config modifier changed the wrong fields" -}}
{{- end -}}'
printf '%s' "$result" | chezmoi execute-template --with-stdin "$assertions" >/dev/null
[[ "$(printf '%s' "$result" | render)" == "$result" ]]
