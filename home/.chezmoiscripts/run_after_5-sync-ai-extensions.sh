#!/usr/bin/env bash

export GIT_TERMINAL_PROMPT=0

within() {
  perl -e 'alarm shift; exec @ARGV' 30 "$@"
}

if command -v codex >/dev/null 2>&1; then
  grep -Fq '[marketplaces.ponytail]' "$HOME/.codex/config.toml" 2>/dev/null ||
    within codex plugin marketplace add DietrichGebert/ponytail --json || :
  grep -Fq '[plugins."ponytail@ponytail"]' "$HOME/.codex/config.toml" 2>/dev/null ||
    within codex plugin add ponytail@ponytail --json || :
fi

checkout="$HOME/.local/share/chezmoi-ai/sources/addyosmani-agent-skills"
mkdir -p "$(dirname "$checkout")" || exit
if [[ -d "$checkout/.git" ]]; then
  within git -C "$checkout" pull --ff-only --quiet || :
else
  within git clone --depth=1 --quiet https://github.com/addyosmani/agent-skills.git "$checkout" || :
fi

for source in "$checkout/skills" "$HOME/.local/share/ai-skills"; do
  [[ -d "$source" ]] || continue
  for destination in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.config/opencode/skills"; do
    mkdir -p "$destination" || exit
    cp -a "$source/." "$destination/" || exit
  done
done
