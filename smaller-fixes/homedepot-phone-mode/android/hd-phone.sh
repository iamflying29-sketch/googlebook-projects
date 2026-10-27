#!/system/bin/sh
# hd-phone.sh - runs on Android as the adb shell user (uid 2000).
#
# Keeps an app in a phone-sized desktop window. The Home Depot app refuses to
# run ("no longer supported for tablet devices") when its window is 600dp or
# wider, so whenever one of its freeform windows grows that big (maximize,
# drag-resize, a launch at the default tablet size) it is resized back to a
# tall, centered phone window. The app re-lays itself out as a phone.
#
# Android desktop windowing only saves ("remembers") an app's window size when
# the user drags it; `am task resize` does not count. So after every fix the
# watcher also performs a real mouse drag of the window's left edge, and while
# the app is open it checks the saved size every 30s and re-drags if it is
# not phone-sized. New launches then open phone-sized directly.
#
# Started (and restarted if missing or outdated) by terminal/hd-keeper.
# Overridable through the environment:
#   HD_PACKAGE   app to keep phone-sized         (default com.thehomedepot)
#   HD_PHONE_DP  phone window width in dp        (default 448)
#   HD_LIMIT_DP  resize when narrowest side >=   (default 600)

P=${HD_PACKAGE:-com.thehomedepot}
PHONE_DP=${HD_PHONE_DP:-448}
LIMIT_DP=${HD_LIMIT_DP:-600}
DIR=/data/local/tmp
LOG=$DIR/hd-phone.log

echo $$ > $DIR/hd-phone.pid

# Display size and density (honors `wm size` / `wm density` overrides).
size=$(wm size | tail -1 | sed 's/.*: //')
W=${size%x*}; H=${size#*x}
DPI=$(wm density | tail -1 | sed 's/.*: //')

# Target bounds: centered, nearly full height (clear of the status bar and taskbar).
pw=$((PHONE_DP * DPI / 160))
L=$(((W - pw) / 2)); R=$((L + pw))
T=$((H * 3 / 100));  B=$((H - H * 5 / 100))
limit=$((LIMIT_DP * DPI / 160))
mid=$(((T + B) / 2))

# Snap task $1 to phone size, then drag its left edge so Android saves it.
fix() {
  am task resize $1 $((L - 40)) $T $R $B
  sleep 1
  input mouse motionevent DOWN $((L - 42)) $mid
  input mouse motionevent MOVE $((L - 20)) $mid
  input mouse motionevent MOVE $L $mid
  input mouse motionevent UP $L $mid
}

# Width in px of the saved window size, or nothing if none is saved.
saved_width() {
  dumpsys activity service SystemUIService WMShell 2>/dev/null |
    awk -v p="$P" -v w=$W '$1 == p && $2 == "->" {
      r = $0; gsub(/.*RectF\(|\).*| /, "", r); split(r, a, ",")
      printf "%d", (a[3] - a[1]) * w; exit }'
}

# Keep the log short.
[ -f $LOG ] && [ $(wc -l < $LOG) -gt 500 ] && tail -100 $LOG > $LOG.tmp && mv $LOG.tmp $LOG
echo "$(date) start: $P -> $L,$T,$R,$B (display ${W}x${H} @${DPI}dpi, limit ${limit}px)" >> $LOG

next_check=0; fails=0
while true; do
  # Cheap check first; only dump window state while the app is running.
  if pidof $P > /dev/null 2>&1; then
    # "<taskId> <left> <top> <right> <bottom>" per freeform task of $P.
    tasks=$(dumpsys activity activities 2>/dev/null | awk -v p="$P" '
      $0 ~ "\\* Task\\{.* A=[0-9]+:" p " .*mode=freeform" {
        t = $0; sub(/.* #/, "", t); sub(/ .*/, "", t); want = 1; next }
      want && /mBounds=Rect/ {
        b = $0; gsub(/.*Rect\(|\).*/, "", b); gsub(/[ ,-]+/, " ", b)
        print t, b; want = 0 }')
    echo "$tasks" | while read id l t r b; do
      [ -n "$b" ] || continue
      w=$((r - l)); h=$((b - t)); m=$w; [ $h -lt $m ] && m=$h
      if [ $m -ge $limit ]; then
        fix $id
        echo "$(date) resized task $id from $l,$t,$r,$b" >> $LOG
      fi
    done

    # Every 30s: make sure the saved size is phone-sized too. After 3 failed
    # drags in a row (e.g. another window covers the edge), wait 10 minutes.
    now=$(date +%s)
    id=${tasks%% *}
    if [ -n "$id" ] && [ $now -ge $next_check ]; then
      sw=$(saved_width)
      if [ -z "$sw" ] || [ $sw -ge $limit ]; then
        fix $id; sleep 1
        sw2=$(saved_width)
        if [ -n "$sw2" ] && [ $sw2 -lt $limit ]; then fails=0; else fails=$((fails + 1)); fi
        echo "$(date) saved size was ${sw:-none}px wide; re-dragged task $id, now ${sw2:-none}px" >> $LOG
      else
        fails=0
      fi
      if [ $fails -ge 3 ]; then next_check=$((now + 600)); else next_check=$((now + 30)); fi
    fi
    sleep 1
  else
    sleep 2
  fi
done
