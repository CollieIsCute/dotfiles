#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

shell_args=(-w)
fish_args=(-w)
lua_args=(--config-path stylua.toml)
yaml_args=(-conf .yamlfmt)
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

files=(git ls-files -z)
if [[ -n ${FORMAT_BASE:-} ]]; then
  files=(git diff --name-only --diff-filter=ACMR -z "${FORMAT_BASE}...HEAD")
fi

while IFS= read -r -d '' file; do
  case "$file" in
  *.tmpl | *.tera | */.chezmoitemplates/* | */modify_* | */remove_*) continue ;;
  .github/workflows/*)
    if [[ ${CI:-} == true ]]; then
      yamlfmt -conf .yamlfmt -lint "$file"
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
done < <("${files[@]}" -- '*.sh' '*.fish' '*.lua' '*.yaml' '*.yml' \
  home/dot_clang-format .yamlfmt \
  home/dot_config/sketchybar/executable_sketchybarrc home/dot_local/bin/executable_openwhispr)
