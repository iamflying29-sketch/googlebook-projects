#!/bin/bash
# set-phone-window.sh - one-time setup, run anywhere adb is connected to Android
# (e.g. the Googlebook's Linux Terminal).
#
# Android desktop windowing remembers each app's window size, but only when
# the user drags or resizes the window ("rememberedBoundsRatioByPackageName"
# in `dumpsys activity service SystemUIService WMShell`). `am task resize`
# does not count. This script opens the app and performs real mouse drags
# with `input mouse motionevent` to shrink the window to a tall, centered phone
# shape. After that, every launch opens phone-sized.
#
#   bash tools/set-phone-window.sh [adb-serial]
# Environment: HD_PACKAGE (default com.thehomedepot), HD_PHONE_DP (default 448)
set -e
P=${HD_PACKAGE:-com.thehomedepot}
PHONE_DP=${HD_PHONE_DP:-448}
S=${1:-$(adb devices | awk 'NR > 1 && $2 == "device" {print $1; exit}')}
[ -n "$S" ] || { echo "adb is not connected to Android" >&2; exit 1; }
ash() { adb -s "$S" shell "$@" | tr -d '\r'; }

bounds() {  # prints "left top right bottom" of the app's freeform window
  ash dumpsys activity activities | awk -v p="$P" '
    $0 ~ "\\* Task\\{.* A=[0-9]+:" p " .*mode=freeform" {want = 1; next}
    want && /mBounds=Rect/ { b = $0; gsub(/.*Rect\(|\).*/, "", b); gsub(/[ ,-]+/, " ", b); print b; exit }'
}
drag() {    # x1 y1 x2 y2: press, move in steps, release
  local i
  ash input mouse motionevent DOWN $1 $2
  for i in 1 2 3 4 5 6; do
    ash input mouse motionevent MOVE $(( $1 + ($3 - $1) * i / 6 )) $(( $2 + ($4 - $2) * i / 6 ))
  done
  ash input mouse motionevent UP $3 $4
  sleep 2
}

size=$(ash wm size | tail -1 | sed 's/.*: //'); W=${size%x*}; H=${size#*x}
DPI=$(ash wm density | tail -1 | sed 's/.*: //')
pw=$((PHONE_DP * DPI / 160))
L=$(((W - pw) / 2)); T=$((H * 3 / 100)); B=$((H - H * 5 / 100))
caption=$((20 * DPI / 160))   # a point inside the window's title bar

# Start from a fresh, resizable window. (FORCE_NON_RESIZE_APP would block this.)
ash am force-stop --user current $P
ash monkey -p $P -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
sleep 6
read l t r b < <(bounds) || true
[ -n "$b" ] || { echo "no freeform window for $P found" >&2; exit 1; }
echo "window: $l,$t,$r,$b"

# Android saves the size only when a drag actually changes it. The watcher may
# already have shrunk the window, so first drag a little wider, then to size.
drag $((l - 2)) $(((t + b) / 2)) $((r - pw - 40)) $(((t + b) / 2))   # left edge -> a bit wider
read l t r b < <(bounds) || true
drag $((l - 2)) $(((t + b) / 2)) $((r - pw)) $(((t + b) / 2))        # left edge -> phone width
read l t r b < <(bounds) || true
drag $(((l + r) / 2)) $((b + 2)) $(((l + r) / 2)) $B             # bottom edge down
read l t r b < <(bounds) || true
drag $(((l + r) / 2)) $((t - 2)) $(((l + r) / 2)) $T             # top edge up
read l t r b < <(bounds) || true
drag $(((l + r) / 2)) $((t + caption)) $((L + pw / 2)) $((t + caption))   # title bar -> center
read l t r b < <(bounds) || true
echo "window now: $l,$t,$r,$b  ($(( (r - l) * 160 / DPI ))dp x $(( (b - t) * 160 / DPI ))dp)"
# The saved entry is a RectF of display ratios; check its width is phone-sized.
rem=$(ash dumpsys activity service SystemUIService WMShell | grep -m1 "$P ->" | grep -oE 'RectF\([^)]*\)')
echo "saved: ${rem:-none}"
remw=$(echo "$rem" | tr -d 'RectF() ' | awk -F, -v w=$W 'NF == 4 {printf "%d", ($3 - $1) * w}')
if [ -n "$remw" ] && [ "$remw" -lt $((600 * DPI / 160)) ]; then
  echo "Remembered (${remw}px wide). New launches of $P open phone-sized."
else
  echo "Warning: the saved size is not phone-sized; drag the window edge narrower once by hand." >&2
  exit 1
fi
