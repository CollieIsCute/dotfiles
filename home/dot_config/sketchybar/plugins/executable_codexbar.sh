#!/bin/sh

case "${SENDER:-}" in
    mouse.entered)
        sketchybar --set codexbar popup.drawing=on
        exit 0
        ;;
    mouse.exited)
        sketchybar --set codexbar popup.drawing=off
        exit 0
        ;;
    mouse.clicked)
        case "${BUTTON:-left}" in
            left)
                sketchybar --set codexbar popup.drawing=off
                exec "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/native-menu.sh"
                ;;
            right) ;;
            *) exit 0 ;;
        esac
        ;;
    forced|routine|system_woke) ;;
    *) exit 0 ;;
esac

# Keep only rendered labels in SketchyBar, not account JSON or credentials.
# macOS lockf prevents overlapping refreshes and releases on process exit.
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar"
mkdir -p "$cache_dir" || exit 1
exec 9>"$cache_dir/codexbar.lock"
/usr/bin/lockf -s -t 0 9 || exit 0

sketchybar --set codexbar.status label="CodexBar · 更新中…"
# Both providers keep their own configured source: Codex OAuth, Claude CLI.
if ! data=$(codexbar usage --provider both --format json --json-only --no-credits 2>/dev/null); then
    sketchybar --set codexbar.status label="CodexBar · 更新失敗，資料未更新"
    exit 1
fi

if ! rows=$(printf '%s\n' "$data" | /usr/bin/jq -er '
    now as $now
    | [(if type == "array" then .[] elif .providers then .providers[] else . end)
     | select(.provider == "codex" or .provider == "claude")]
    | if (map(.provider) | sort) == ["claude", "codex"]
         and all(.error == null and (.usage | type) == "object")
      then .[] else error("Incomplete provider response") end
    | (if .provider == "codex" then "Codex · OAuth" else "Claude · CLI" end) as $provider
    | .usage as $usage
    | $provider,
      (if .stale == true then "注意：來源回報為快取資料" else empty end),
      ([{title: ({"300": "5 小時", "10080": "每週"}[($usage.primary.windowMinutes | tostring)] // "主要額度"), window: $usage.primary},
        {title: "每週", window: $usage.secondary},
        {title: "其他額度", window: $usage.tertiary},
        ($usage.extraRateWindows[]? | {title: .title, window: (.window // .)}),
        ($usage.windows[]? | {title: (.title // .name), window: (.window // .)})]
       | map(select((.window.usedPercent | type) == "number"))
       | if length == 0 then "目前沒有回報額度區間"
         else .[]
           | ((.title // "額度") | tostring | gsub("[\r\n\t]"; " ")) as $title
           | ([100, ([0, (100 - .window.usedPercent)] | max)] | min | round) as $remaining
           | (try (.window.resetsAt | fromdateiso8601) catch null) as $reset
           | "\($title) · 剩餘 \($remaining)%",
             (if $reset == null then empty
              elif $reset <= $now then "↳ 重置時間已到，等待來源更新"
              else (($reset - $now) / 60 | ceil) as $minutes
                | (if $minutes >= 1440 then
                     "\(($minutes / 1440) | floor) 天 \((($minutes % 1440) / 60) | floor) 小時 \($minutes % 60) 分"
                   elif $minutes >= 60 then
                     "\(($minutes / 60) | floor) 小時 \($minutes % 60) 分"
                   else "\($minutes) 分" end) as $duration
                | "↳ 約 \($duration)後重置"
              end)
         end)
'); then
    sketchybar --set codexbar.status label="CodexBar · 回應不完整，資料未更新"
    exit 1
fi

# One IPC batch replaces the tooltip rows without flashing an empty popup.
set -- --remove '/codexbar\.usage\..*/' \
    --set codexbar.status "label=CodexBar · 讀取 $(date +%H:%M:%S)"
index=0
while IFS= read -r row; do
    index=$((index + 1))
    set -- "$@" --add item "codexbar.usage.$index" popup.codexbar \
        --set "codexbar.usage.$index" width=330 icon.drawing=off \
        "label=$row" label.max_chars=40 label.padding_left=12 label.padding_right=12
done <<EOF
$rows
EOF
sketchybar "$@"
