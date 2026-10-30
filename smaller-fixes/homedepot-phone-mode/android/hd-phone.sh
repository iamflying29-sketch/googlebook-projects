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

# A Home Depot task that is a FULLSCREEN task instead of a desktop window is a tablet to the
# app, and `am task resize` cannot change that. Move it back onto the active desk, which is
# what the window's own menu does; the loop above then resizes it like any wide window.
# Every id comes from the system itself and is checked before use; on any doubt, do nothing.
WMS="dumpsys activity service SystemUIService WMShell desktopmode"
desk_answer() {   # prints the one number (or list) the desktopmode command answered with
  $WMS "$@" 2>/dev/null | sed -n 's/^ *\(-\{0,1\}[0-9][0-9,]*\) *$/\1/p' | head -1
}
rescue() {        # $1 = task id of a fullscreen task of $P
  # While a fullscreen task is on top the system reports no active desk (-1), so fall back
  # to the desk list, but only when it names exactly one desk.
  ids=$(desk_answer getDeskIds 0)
  desk=$(desk_answer getActiveDeskId 0)
  case "$desk" in ''|-1|*[!0-9]*) desk=$ids;; esac
  case "$desk" in ''|*[!0-9]*)
    echo "$(date) fullscreen task $1: no single desk to move it to (active '$desk', list '$ids'), not moving it" >> $LOG; return 1;; esac
  case ",$ids," in *",$desk,"*) ;; *)
    echo "$(date) fullscreen task $1: desk $desk is not in the desk list '$ids', not moving it" >> $LOG; return 1;; esac
  $WMS moveTaskToDesk $1 $desk > /dev/null 2>&1
  echo "$(date) moved fullscreen task $1 back onto desk $desk" >> $LOG
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

next_check=0; fails=0; last_rescued=; last_rescue_time=0
while true; do
  # Cheap check first; only dump window state while the app is running.
  if pidof $P > /dev/null 2>&1; then
    # "<taskId> <left> <top> <right> <bottom>" per freeform task of $P.
    dump=$(dumpsys activity activities 2>/dev/null)
    tasks=$(echo "$dump" | awk -v p="$P" '
      $0 ~ "\\* Task\\{.* A=[0-9]+:" p " .*mode=freeform" {
        t = $0; sub(/.* #/, "", t); sub(/ .*/, "", t); want = 1; next }
      want && /mBounds=Rect/ {
        b = $0; gsub(/.*Rect\(|\).*/, "", b); gsub(/[ ,-]+/, " ", b)
        print t, b; want = 0 }')
    # Visible fullscreen tasks of $P (not desktop windows): move them back onto the desk,
    # at most once a minute per task, so a failing move can never loop. A hidden one is left
    # alone until it is shown, so no window ever pops up on its own.
    full=$(echo "$dump" | awk -v p="$P" '
      $0 ~ "\\* Task\\{.* A=[0-9]+:" p " .*visible=true.*mode=fullscreen" {
        t = $0; sub(/.* #/, "", t); sub(/ .*/, "", t); print t }')
    for id in $full; do
      case "$id" in ''|*[!0-9]*) continue;; esac
      now=$(date +%s)
      if [ "$id" != "$last_rescued" ] || [ $((now - last_rescue_time)) -ge 60 ]; then
        last_rescued=$id; last_rescue_time=$now
        rescue $id
      fi
    done

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
