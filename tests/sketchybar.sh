#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config="$repo/home/dot_config/sketchybar"

grep -Fq 'tap "FelixKratz/formulae", trusted: { formula: "sketchybar" }' "$repo/home/dot_config/brew/Brewfile"
grep -Fq 'brew "FelixKratz/formulae/sketchybar"' "$repo/home/dot_config/brew/Brewfile"
grep -Fq 'cask "codexbar"' "$repo/home/dot_config/brew/Brewfile"
grep -Fq '.config/sketchybar/**' "$repo/home/.chezmoiignore"
grep -Fq 'sleep 3; sketchybar --reload || sketchybar' "$repo/home/dot_config/aerospace/aerospace.toml"
grep -Fq 'FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE' "$repo/home/dot_config/aerospace/aerospace.toml"
grep -Fq '[templates.sketchybar]' "$repo/home/dot_config/matugen/config.toml.tmpl"
grep -Fq '# sketchybar:' "$repo/home/.chezmoiscripts/run_onchange_after_6-apply-theme.sh.tmpl"

for file in \
    "$config/executable_sketchybarrc" \
    "$config/plugins/executable_clock.sh" \
    "$config/plugins/executable_volume.sh" \
    "$config/plugins/executable_workspace.sh"; do
    test -x "$file"
    sh -n "$file"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin"

cat >"$tmp/bin/sketchybar" <<'EOF'
#!/bin/sh
if test "${1-} ${2-}" = "--query default_menu_items"; then
    printf '%s\n' "$MOCK_MENU_ITEMS"
else
    printf '%s\n' "$*" >>"$MOCK_SKETCHYBAR_LOG"
fi
EOF

cat >"$tmp/bin/osascript" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$MOCK_OSASCRIPT_LOG"
case "$*" in
    *'output volume of'*) printf '%s\n' "${MOCK_VOLUME:-50}" ;;
    *'output muted of'*) printf '%s\n' "${MOCK_MUTED:-false}" ;;
esac
EOF

chmod +x "$tmp/bin/sketchybar" "$tmp/bin/osascript"

if command -v matugen >/dev/null 2>&1; then
    cat >"$tmp/matugen.toml" <<EOF
[config]

[templates.sketchybar]
input_path = "$config/colors.sh.tera"
output_path = "$tmp/colors.sh"
EOF
    matugen color hex '#6750a4' -m light -c "$tmp/matugen.toml" >/dev/null
    grep -Eq '^CAPSULE=0x4d[0-9a-fA-F]{6}$' "$tmp/colors.sh"
    grep -Eq '^ON_SURFACE=0xff[0-9a-fA-F]{6}$' "$tmp/colors.sh"
    grep -Eq '^PRIMARY=0xff[0-9a-fA-F]{6}$' "$tmp/colors.sh"
    grep -Eq '^ON_PRIMARY=0xff[0-9a-fA-F]{6}$' "$tmp/colors.sh"
fi

export PATH="$tmp/bin:$PATH"
export MOCK_SKETCHYBAR_LOG="$tmp/sketchybar.log"
export MOCK_OSASCRIPT_LOG="$tmp/osascript.log"
export MOCK_MENU_ITEMS='[
  "Karabiner-Console-User-Server,(1)",
  "控制中心,WiFi(2)",
  "控制中心,Network_speed(3)",
  "控制中心,Sensors_mini(4)",
  "控制中心,RAM_tachometer(5)",
  "控制中心,codexbar-merged(6)",
  "控制中心,Item-0(7)",
  "KeePassXC,(8)"
]'

: >"$MOCK_SKETCHYBAR_LOG"
CONFIG_DIR="$config" sh "$config/executable_sketchybarrc"
grep -Fq -- '--add alias 控制中心,codexbar-merged(6) left' "$MOCK_SKETCHYBAR_LOG"
grep -Fq -- '--add alias 控制中心,Sensors_mini(4) right' "$MOCK_SKETCHYBAR_LOG"
grep -Fq -- '--add alias 控制中心,RAM_tachometer(5) right' "$MOCK_SKETCHYBAR_LOG"
grep -Fq -- '--add alias 控制中心,Network_speed(3) right' "$MOCK_SKETCHYBAR_LOG"
grep -Fq -- '--add alias KeePassXC,(8) left' "$MOCK_SKETCHYBAR_LOG"
grep -Fq -- '--set codexbar padding_left=5 padding_right=5' "$MOCK_SKETCHYBAR_LOG"
grep -Fq -- '--set workspaces padding_left=5 padding_right=5' "$MOCK_SKETCHYBAR_LOG"
grep -Fq -- '--set stats.net.group padding_left=5 padding_right=5' "$MOCK_SKETCHYBAR_LOG"
if grep -Eq -- '--add alias (控制中心,(WiFi|Item-0)|Karabiner-Console-User-Server)' "$MOCK_SKETCHYBAR_LOG"; then
    echo 'System menu items must not be duplicated in tray aliases' >&2
    exit 1
fi

: >"$MOCK_SKETCHYBAR_LOG"
CONFIG_DIR="$config" NAME=space.3 FOCUSED_WORKSPACE=3 sh "$config/plugins/executable_workspace.sh"
grep -Fq 'background.drawing=on' "$MOCK_SKETCHYBAR_LOG"
grep -Fq 'icon.color=0xff381e72' "$MOCK_SKETCHYBAR_LOG"

: >"$MOCK_SKETCHYBAR_LOG"
CONFIG_DIR="$config" NAME=space.3 FOCUSED_WORKSPACE=4 sh "$config/plugins/executable_workspace.sh"
grep -Fq 'background.drawing=off' "$MOCK_SKETCHYBAR_LOG"
grep -Fq 'icon.color=0xfff2f0f4' "$MOCK_SKETCHYBAR_LOG"

: >"$MOCK_OSASCRIPT_LOG"
NAME=volume SENDER=mouse.scrolled SCROLL_DELTA=1 MOCK_VOLUME=98 \
    sh "$config/plugins/executable_volume.sh"
grep -Fq 'set volume output volume 100' "$MOCK_OSASCRIPT_LOG"

: >"$MOCK_OSASCRIPT_LOG"
NAME=volume SENDER=mouse.scrolled SCROLL_DELTA=-1 MOCK_VOLUME=2 \
    sh "$config/plugins/executable_volume.sh"
grep -Fq 'set volume output volume 0' "$MOCK_OSASCRIPT_LOG"

: >"$MOCK_OSASCRIPT_LOG"
NAME=volume SENDER=mouse.clicked sh "$config/plugins/executable_volume.sh"
grep -Fq 'set volume output muted not (output muted of (get volume settings))' "$MOCK_OSASCRIPT_LOG"

echo 'SketchyBar checks passed.'
