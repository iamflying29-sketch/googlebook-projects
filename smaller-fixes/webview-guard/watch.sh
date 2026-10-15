#!/system/bin/sh
# WebView Guard watcher. It runs on the Googlebook as the adb shell user and is started by webview-guard in the
# Linux VM.
#
# Android closes every app that uses WebView when the WebView package it loaded is updated or replaced. The Terminal
# app draws its window with WebView, so that closes the Terminal and stops the whole Linux VM. This script waits until
# the Terminal's Linux VM has stopped and then does one of two things:
#   switch PACKAGE           make PACKAGE (WebView Beta) the WebView that apps use, with Android's own command,
#                            because switching closes every app that uses WebView too; then notify and exit.
#   update PACKAGE CODE NEW  post a notification that it is safe to update PACKAGE now; if the Terminal opens again
#                            first, the notification says to wait. It exits when the package's version changes.
# It stops after seven days. Besides the switch, it only reads (whether the VM runs, and a package's version) and
# changes nothing on the Googlebook except its own notification.
DIR=/data/local/tmp/webview-guard
TERMINAL=com.android.virtualization.terminal
MODE="$1"
PKG="$2"
OLD_CODE="$3"      # the package's version code when the watcher started
NEW_NAME="$4"      # the version Google has released
echo $$ > "$DIR/pid"
echo "$MODE $PKG: watching since $(date '+%Y-%m-%d %H:%M:%S') ${NEW_NAME:+for $NEW_NAME}" > "$DIR/state"
end=$(( $(date +%s) + 604800 ))
state=""
n=0

code() {   # "pm list packages NAME" also lists packages whose names start with NAME, so only the exact line counts
  pm list packages --show-versioncode "$PKG" 2>/dev/null | while read -r line; do
    case "$line" in "package:$PKG versionCode:"*) echo "${line##*versionCode:}" ;; esac
  done
}

vm_running() {   # the Linux VM (crosvm_debian, or any crosvm owned by the Terminal app); the danger is the VM, not a cached app
  pidof crosvm_debian >/dev/null 2>&1 && return 0
  t=$(pidof "$TERMINAL") || return 1
  owner=$(stat -c %U "/proc/${t%% *}" 2>/dev/null)
  for p in $(pidof crosvm); do
    [ "$(stat -c %U "/proc/$p" 2>/dev/null)" = "$owner" ] && return 0
  done
  return 1
}

notify() {   # title and text (Android does not let the shell attach a tap action, so the text says what to do)
  cmd notification post -u "$(am get-current-user)" -S bigtext -t "$1" webview-guard "$2" >/dev/null 2>&1
}

current_provider() {
  dumpsys webviewupdate 2>/dev/null | sed -n 's/.*Current WebView package (name, version): (\([^,]*\),.*/\1/p'
}

while [ "$(date +%s)" -lt "$end" ]; do
  n=$((n + 1))
  if [ "$MODE" = switch ]; then
    if ! vm_running && ! vm_running; then   # checked twice, so a VM that is just starting is not missed
      sleep 3
      if ! vm_running; then
        cmd webviewupdate set-webview-implementation "$PKG" >/dev/null 2>&1
        sleep 2
        if [ "$(current_provider)" = "$PKG" ]; then
          notify "The Terminal now uses WebView Beta" "Updates to the regular Android System WebView can no longer close the Terminal. You can turn the Play Store's automatic app updates back on. WebView Beta itself only updates when you tap Update, and WebView Guard tells you when that is safe."
          echo "switched to $PKG at $(date '+%Y-%m-%d %H:%M:%S')" > "$DIR/state"
        else
          notify "WebView Guard could not switch to WebView Beta" "Android kept $(current_provider). Nothing else changed. Open the Terminal and run webview-guard to see why."
          echo "switch to $PKG failed at $(date '+%Y-%m-%d %H:%M:%S'); provider $(current_provider)" > "$DIR/state"
        fi
        exit 0
      fi
    fi
  else
    if [ $((n % 12)) -eq 1 ]; then   # about once a minute
      now=$(code)
      if [ -n "$now" ] && [ "$now" != "$OLD_CODE" ]; then
        notify "WebView is up to date" "You can open the Terminal again."
        echo "$PKG updated at $(date '+%Y-%m-%d %H:%M:%S')" > "$DIR/state"
        exit 0
      fi
    fi
    if vm_running; then
      if [ "$state" = closed ]; then
        notify "Wait with the WebView update" "The Terminal is open again. Updating WebView now would close it and stop Linux, so update it after you close the Terminal."
      fi
      state=open
    else
      if [ "$state" != closed ]; then
        notify "Safe to update WebView now" "The Terminal is closed, so updating WebView ($NEW_NAME) will not stop Linux. In the Play Store, tap your profile picture, then Manage apps and device, and tap Update all. Then open the Terminal again."
      fi
      state=closed
    fi
  fi
  sleep 5
done
echo "stopped after seven days at $(date '+%Y-%m-%d %H:%M:%S')" > "$DIR/state"
