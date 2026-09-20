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
    | if type == "array" then map(select(.provider == "codex" or .provider == "claude"))
      else error("Invalid provider response") end
    | if length == 0 then ["note", "尚未啟用 Codex／Claude"] else .[]
    | (if .provider == "codex" then "Codex" else "Claude" end) as $provider
    | .usage as $usage
    | (["header", $provider],
      (if .error != null or ($usage | type) != "object" then
         ["note", "未登入或讀取失敗，請點擊圖示查看"]
       else
      (if .stale == true then ["note", "注意：來源回報為快取資料"] else empty end),
      ([{title: ({"300": "5 小時", "10080": "每週"}[($usage.primary.windowMinutes | tostring)] // "主要額度"), window: $usage.primary},
        {title: "每週", window: $usage.secondary},
        {title: "其他額度", window: $usage.tertiary},
        $usage.extraRateWindows[]?]
       | map(select((.window.usedPercent | type) == "number"))
       | if length == 0 then ["note", "目前沒有回報額度區間"]
         else .[]
           | ((.title // "額度") | tostring | gsub("[\r\n\t]"; " ")) as $title
           | ([100, ([0, (100 - .window.usedPercent)] | max)] | min | round) as $remaining
           | (try (.window.resetsAt | fromdateiso8601) catch null) as $reset
           | ["quota", "\($title) · 剩餘 \($remaining)%",
             (if $reset == null then ""
              elif $reset <= $now then "↳ 重置時間已到，等待來源更新"
              else (($reset - $now) / 60 | ceil) as $minutes
                | (if $minutes >= 1440 then
                     "\(($minutes / 1440) | floor) 天 \((($minutes % 1440) / 60) | floor) 小時 \($minutes % 60) 分"
                   elif $minutes >= 60 then
                     "\(($minutes / 60) | floor) 小時 \($minutes % 60) 分"
                   else "\($minutes) 分" end) as $duration
                | "↳ 約 \($duration)後重置"
              end)]
         end) end)) end
    | join("\t")
'); then
    sketchybar --set codexbar.status label="CodexBar · 回應不完整，資料未更新"
    exit 1
fi

CONFIG_DIR=${CONFIG_DIR:-"$HOME/.config/sketchybar"}
ON_SURFACE=0xfff2f0f4
PRIMARY=0xffd0bcff
test -r "$CONFIG_DIR/colors.sh" && . "$CONFIG_DIR/colors.sh"

# One native item holds both lines, so its border encloses the whole quota.
# https://felixkratz.github.io/SketchyBar/config/items#background-properties
# One IPC batch replaces the tooltip without flashing an empty popup.
set -- --remove '/codexbar\.usage\..*/' \
    --set codexbar.status "label=CodexBar · 讀取 $(date +%H:%M:%S)"
index=0
while IFS="$(printf '\t')" read -r kind title reset; do
    index=$((index + 1))
    set -- "$@" --add item "codexbar.usage.$index" popup.codexbar \
        --set "codexbar.usage.$index" width=314 padding_left=10 padding_right=10 \
        icon.drawing=off "label=$title" label.max_chars=40 \
        label.padding_left=10 label.padding_right=10
    case "$kind" in
        header)
            set -- "$@" label.color="$PRIMARY" label.font.style=Bold
            ;;
        quota)
            set -- "$@" icon.drawing=on "icon=$title" \
                icon.font="JetBrainsMono Nerd Font:Regular:13.0" \
                icon.width=0 icon.padding_left=10 icon.padding_right=0 icon.max_chars=40 \
                label="$reset" label.font.size=12 label.color="0xcc${ON_SURFACE#????}" \
                background.drawing=on background.color="0x08${ON_SURFACE#????}" \
                background.border_width=1 background.border_color="0x55${ON_SURFACE#????}" \
                background.corner_radius=6 background.height=52 \
                icon.y_offset=11 label.y_offset=-11
            if test -z "$reset"; then
                set -- "$@" icon.y_offset=0 label.drawing=off background.height=32
            fi
            ;;
    esac
done <<EOF
$rows
EOF
sketchybar "$@"
