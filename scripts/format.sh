#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

shell_args=(-w)
fish_args=(-w)
lua_args=(--config-path home/dot_config/stylua/stylua.toml)
yaml_args=(-conf home/dot_config/yamlfmt/dot_yamlfmt)
case "${1:-}" in
'') ;;
--check)
  shell_args=(-d)
  fish_args=(--check)
  lua_args+=(--check)
  yaml_args+=(-lint)
  ;;
*)
  echo "Usage: bash scripts/format.sh [--check]" >&2
  exit 2
  ;;
esac

while IFS= read -r -d '' file; do
  case "$file" in
  *.tmpl | *.tera | */.chezmoitemplates/* | */modify_* | */remove_*) continue ;;
  .github/workflows/*)
    if [[ ${CI:-} == true ]]; then
      yamlfmt -conf home/dot_config/yamlfmt/dot_yamlfmt -lint "$file"
      continue
    fi
    ;;
  esac
  case "$file" in
  *.sh | */executable_sketchybarrc | */executable_openwhispr) shfmt "${shell_args[@]}" "$file" ;;
  *.fish) fish_indent "${fish_args[@]}" "$file" ;;
  *.lua) stylua "${lua_args[@]}" "$file" ;;
  *) yamlfmt "${yaml_args[@]}" "$file" ;;
  esac
done < <(git ls-files -z -- '*.sh' '*.fish' '*.lua' '*.yaml' '*.yml' \
  home/dot_clang-format home/dot_config/yamlfmt/dot_yamlfmt \
  home/dot_config/sketchybar/executable_sketchybarrc home/dot_local/bin/executable_openwhispr)
