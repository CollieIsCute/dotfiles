#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

while IFS= read -r -d '' file; do
  case "$file" in
  *.tmpl | *.tera | */.chezmoitemplates/* | */modify_* | */remove_*) continue ;;
  .github/workflows/*) yamlfmt -conf .yamlfmt -lint "$file" ;;
  *.sh | */executable_sketchybarrc | */executable_openwhispr) shfmt -w "$file" ;;
  *.fish) fish_indent -w "$file" ;;
  *.lua) stylua --config-path stylua.toml "$file" ;;
  *) yamlfmt -conf .yamlfmt "$file" ;;
  esac
done < <(git ls-files -z -- '*.sh' '*.fish' '*.lua' '*.yaml' '*.yml' \
  home/dot_clang-format .yamlfmt \
  home/dot_config/sketchybar/executable_sketchybarrc home/dot_local/bin/executable_openwhispr)
