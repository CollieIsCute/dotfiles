#!/bin/sh

# Keep only rendered labels in SketchyBar, not account JSON or credentials.
# macOS lockf prevents overlapping refreshes and releases on process exit.
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
mkdir -p "$cache_dir" || exit 1
exec 9>"$cache_dir/codexbar.lock"
/usr/bin/lockf -s -t 0 9 || exit 0

sketchybar --set codexbar.status label="CodexBar · 更新中…"
# The CLI still returns healthy providers when another provider fails (nonzero exit).
data=$(codexbar usage --format json --json-only --no-credits 2>/dev/null) || :

if ! rows=$(printf '%s\n' "$data" | /usr/bin/jq -er '
    now as $now
    | def countdown($reset):
        (([$reset - $now, 0] | max) / 60 | ceil) as $minutes
        | if $minutes >= 1440 then
            "\(($minutes / 1440) | floor)d\((($minutes % 1440) / 60) | floor)h"
          else "\(($minutes / 60) | floor)h\($minutes % 60)m" end;
    if type == "array" then map(select(.provider == "codex" or .provider == "claude"))
      else error("Invalid provider response") end
    | if length == 0 then ["note", "尚未啟用 Codex／Claude"] else .[]
    | .provider as $id
    | (if $id == "codex" then "Codex" else "Claude" end) as $provider
    | .usage as $usage
    | (.error == null and ($usage | type) == "object") as $ok
    | (if $ok then
        [{title: ({"300": "5 小時", "10080": "每週"}[($usage.primary.windowMinutes | tostring)] // "主要額度"), window: $usage.primary},
         {title: "每週", window: $usage.secondary},
         {title: "其他額度", window: $usage.tertiary},
         $usage.extraRateWindows[]?]
        | map(select((.window.usedPercent | type) == "number"))
        | map({title: ((.title // "額度") | tostring | gsub("[\r\n\t]"; " ")),
               remaining: ([100, ([0, (100 - .window.usedPercent)] | max)] | min | round),
               reset: (try (.window.resetsAt | fromdateiso8601) catch null)})
       else [] end) as $quotas
    | (if ($quotas | length) == 0 then "--"
       else $quotas[0] as $quota
       | (if $quota.reset == null then ""
          else " \(countdown($quota.reset))"
          end) as $deadline
       | "\($quota.remaining)%\($deadline)"
       end) as $meter
    | (["meter", $id, $meter],
      ["header", $provider],
      (if $ok | not then ["note", "未登入或讀取失敗，請點擊圖示查看"]
       else
      (if .stale == true then ["note", "注意：來源回報為快取資料"] else empty end),
      (if ($quotas | length) == 0 then ["note", "目前沒有回報額度區間"]
       else $quotas[]
         | ["quota", "\(.title) · 剩餘 \(.remaining)%\(if .reset == null then ""
             elif .reset <= $now then " · 等待重置資料更新"
             else " · \(countdown(.reset)) 後重置" end)"]
       end) end)) end
    | join("\t")
'); then
  sketchybar --set codexbar.status label="CodexBar · 回應不完整，資料未更新"
  exit 1
fi

CONFIG_DIR=${CONFIG_DIR:-"$HOME/.config/sketchybar"}
PRIMARY=0xffd0bcff
test -r "$CONFIG_DIR/colors.sh" && . "$CONFIG_DIR/colors.sh"

# One IPC batch replaces the tooltip without flashing an empty popup.
# Providers missing from this response stay hidden rather than keeping stale numbers.
set -- --remove '/codexbar\.usage\..*/' --set '/^meter\./' drawing=off \
  --set codexbar.status "label=CodexBar · 讀取 $(date +%H:%M:%S)"
index=0
# meter rows carry the provider id and its bar label; the rest build the popup.
while IFS="$(printf '\t')" read -r kind title reset; do
  if test "$kind" = meter; then
    set -- "$@" --set "meter.$title" drawing=on "label=$reset"
    continue
  fi
  index=$((index + 1))
  set -- "$@" --add item "codexbar.usage.$index" popup.codexbar \
    --set "codexbar.usage.$index" width=314 padding_left=10 padding_right=10 \
    icon.drawing=off "label=$title" label.max_chars=40 \
    label.padding_left=10 label.padding_right=10
  test "$kind" = header && set -- "$@" label.color="$PRIMARY" label.font.style=Bold
done <<EOF
$rows
EOF
sketchybar "$@"
