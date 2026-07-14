#!/usr/bin/env bash
set -u

PONYTAIL_PACKAGE='@dietrichgebert/ponytail'
PONYTAIL_PLUGIN='ponytail@ponytail'
PONYTAIL_REPO='DietrichGebert/ponytail'
CLAUDE_PROVIDER_PACKAGE='@khalilgharbaoui/opencode-claude-code-plugin'
SKILLS_REPO='https://github.com/addyosmani/agent-skills.git'

info() {
  printf 'AI extensions: %s\n' "$*"
}

json_version() {
  [[ "$1" =~ \"version\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && printf '%s\n' "${BASH_REMATCH[1]}"
}

npm_latest() {
  local json
  json="$(curl --connect-timeout 3 --max-time 10 -fsSL "$1")" || return
  json_version "$json"
}

with_timeout() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  elif command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
  else
    "$@"
  fi
}

move_exact() {
  if command -v perl >/dev/null 2>&1; then
    perl -e 'rename $ARGV[0], $ARGV[1] or exit 1' "$1" "$2"
  else
    mv -T -- "$1" "$2"
  fi
}

update_claude() {
  local version="$1" marketplaces plugins
  info "Updating Claude Code $PONYTAIL_PLUGIN to $version"
  marketplaces="$(with_timeout 30 claude plugin marketplace list --json)" || return
  if [[ "${marketplaces//[[:space:]]/}" != *"\"name\":\"ponytail\""* ]]; then
    with_timeout 120 claude plugin marketplace add "$PONYTAIL_REPO" --scope user || return
  else
    with_timeout 120 claude plugin marketplace update ponytail || return
  fi
  plugins="$(with_timeout 30 claude plugin list --json)" || return
  if [[ "${plugins//[[:space:]]/}" == *"\"id\":\"$PONYTAIL_PLUGIN\""* ]]; then
    with_timeout 120 claude plugin update "$PONYTAIL_PLUGIN" --scope user
  else
    with_timeout 120 claude plugin install "$PONYTAIL_PLUGIN" --scope user
  fi
}

update_codex() {
  local version="$1" marketplaces
  info "Updating Codex $PONYTAIL_PLUGIN to $version"
  marketplaces="$(with_timeout 30 codex plugin marketplace list --json)" || return
  if [[ "${marketplaces//[[:space:]]/}" != *"\"name\":\"ponytail\""* ]]; then
    with_timeout 120 codex plugin marketplace add "$PONYTAIL_REPO" --json || return
  else
    with_timeout 120 codex plugin marketplace upgrade ponytail --json || return
  fi
  with_timeout 120 codex plugin add "$PONYTAIL_PLUGIN" --json
}

update_opencode() (
  local package="$1" version="$2"
  local cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/opencode/packages"
  local cache="$cache_root/${package}@latest"
  local manifest="$cache/node_modules/$package/package.json"
  local backup="${cache}.previous"
  local discard="${cache}.discard.$$"
  local lock="${cache}.sync-lock.$$" marker=".sync-ai-$$" contender contender_pid staging='' staged_cache staged_manifest
  [[ -r "$manifest" && "$(json_version "$(<"$manifest")")" == "$version" ]] && return
  info "Updating OpenCode $package to $version"

  mkdir -p "$(dirname "$cache")" || return
  mkdir "$lock" 2>/dev/null || return
  trap 'rm -rf -- "$lock"' EXIT
  for contender in "${cache}.sync-lock."*; do
    [[ "$contender" == "$lock" || ! -d "$contender" ]] && continue
    contender_pid="${contender##*.}"
    if [[ "$contender_pid" =~ ^[0-9]+$ ]] && kill -0 "$contender_pid" 2>/dev/null; then
      return
    fi
    rm -rf -- "$contender" || return
  done
  trap '[[ -e "$cache" || ! -e "$backup" ]] || move_exact "$backup" "$cache" || :; [[ -z "$staging" ]] || rm -rf -- "$staging"; rm -rf -- "$discard" "$lock"' EXIT

  [[ -e "$cache" || ! -e "$backup" ]] || move_exact "$backup" "$cache" || return
  staging="$(mktemp -d "$cache_root/.sync-ai.XXXXXX")" || return

  XDG_CACHE_HOME="$staging" XDG_CONFIG_HOME="$staging/config" \
    with_timeout 120 opencode plugin "$package" --global --pure || return
  staged_cache="$staging/opencode/packages/${package}@latest"
  staged_manifest="$staged_cache/node_modules/$package/package.json"
  [[ -r "$staged_manifest" && "$(json_version "$(<"$staged_manifest")")" == "$version" ]] || return
  : >"$staged_cache/$marker" || return

  rm -rf -- "$discard" || return
  if [[ -e "$backup" ]]; then
    [[ ! -e "$cache" ]] || move_exact "$cache" "$discard" || return
  else
    [[ ! -e "$cache" ]] || move_exact "$cache" "$backup" || return
  fi
  if move_exact "$staged_cache" "$cache" && [[ -e "$cache/$marker" ]] &&
    [[ -r "$manifest" && "$(json_version "$(<"$manifest")")" == "$version" ]]; then
    rm -f -- "$cache/$marker"
    rm -rf -- "$backup" "$discard"
    return
  fi
  return 1
)

sync_skills() {
  local remote="$1" checkout="$HOME/.local/share/chezmoi-ai/sources/addyosmani-agent-skills"
  mkdir -p "$(dirname "$checkout")" || return
  if [[ ! -d "$checkout/.git" ]]; then
    info 'Cloning addyosmani-agent-skills'
    with_timeout 30 git clone --depth=1 "$SKILLS_REPO" "$checkout" || return
  elif [[ -n "$remote" && "$(git -C "$checkout" rev-parse HEAD)" != "$remote" ]]; then
    if [[ -n "$(git -C "$checkout" status --porcelain)" ]]; then
      info 'Keeping locally modified addyosmani-agent-skills'
    else
      info 'Updating addyosmani-agent-skills'
      with_timeout 30 git -C "$checkout" pull --ff-only "$SKILLS_REPO" main || return
      [[ "$(git -C "$checkout" rev-parse HEAD)" == "$remote" ]] || return
    fi
  fi

  local destination skill source
  for source in "$checkout/skills" "$HOME/.local/share/ai-skills"; do
    [[ -d "$source" ]] || continue
    for destination in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.config/opencode/skills"; do
      mkdir -p "$destination" || return
      for skill in "$source"/*; do
        [[ ! -d "$skill" ]] || cp -a "$skill" "$destination/" || return
      done
    done
  done
}

main() {
  local tmp ponytail_version provider_version skills_revision
  tmp="$(mktemp -d)" || return
  trap "rm -rf -- '$tmp'" EXIT
  npm_latest 'https://registry.npmjs.org/@dietrichgebert%2fponytail/latest' >"$tmp/ponytail" &
  local ponytail_pid=$!
  npm_latest 'https://registry.npmjs.org/@khalilgharbaoui%2fopencode-claude-code-plugin/latest' >"$tmp/provider" &
  local provider_pid=$!
  with_timeout 10 git ls-remote --exit-code "$SKILLS_REPO" refs/heads/main 2>/dev/null | cut -f1 >"$tmp/skills" &
  local skills_pid=$!
  wait "$ponytail_pid" || :
  wait "$provider_pid" || :
  wait "$skills_pid" || :

  ponytail_version="$(<"$tmp/ponytail")"
  provider_version="$(<"$tmp/provider")"
  skills_revision="$(<"$tmp/skills")"

  if [[ -n "$ponytail_version" ]]; then
    local claude_cache="$HOME/.claude/plugins/cache/ponytail/ponytail/$ponytail_version"
    if command -v claude >/dev/null 2>&1 && { [[ ! -d "$claude_cache" ]] || ! grep -Fq "\"installPath\": \"$claude_cache\"" "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; }; then
      update_claude "$ponytail_version" || info 'Claude Code update failed; keeping the installed version'
    fi
    if command -v codex >/dev/null 2>&1 && { [[ ! -d "$HOME/.codex/plugins/cache/ponytail/ponytail/$ponytail_version" ]] || ! grep -Fq "[plugins.\"$PONYTAIL_PLUGIN\"]" "$HOME/.codex/config.toml" 2>/dev/null; }; then
      update_codex "$ponytail_version" || info 'Codex update failed; keeping the installed version'
    fi
    if command -v opencode >/dev/null 2>&1; then
      update_opencode "$PONYTAIL_PACKAGE" "$ponytail_version" || info 'OpenCode Ponytail update failed'
    fi
  else
    info 'Could not check the Ponytail version; keeping the installed version'
  fi

  if command -v opencode >/dev/null 2>&1 && [[ -n "$provider_version" ]]; then
    update_opencode "$CLAUDE_PROVIDER_PACKAGE" "$provider_version" || info 'OpenCode plugin update failed; keeping the installed version'
  fi
  sync_skills "$skills_revision" || info 'Skill synchronization failed; keeping the existing skills'
}

[[ "${BASH_SOURCE[0]}" != "$0" ]] || main "$@"
