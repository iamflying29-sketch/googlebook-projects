#!/bin/bash
# compat-overrides.sh - optional. Applies (or resets) the per-app compat-change
# overrides that were in place when this fix was tested. They persist across
# reboots and app updates. On their own they did not change the launch size;
# the remembered window size and the watcher do the real work.
#
#   bash android/compat-overrides.sh apply|reset [adb-serial]
#
# UNIVERSAL_RESIZABLE_BY_DEFAULT (357141415) is what makes Android 16+ ignore
# an app's portrait-only manifest on large screens (targetSdk >= 36).
# Do NOT enable FORCE_NON_RESIZE_APP: it makes maximize keep the phone layout,
# but it also makes Android ignore and clear the remembered window size.
P=${HD_PACKAGE:-com.thehomedepot}
S=${2:-$(adb devices | awk 'NR > 1 && $2 == "device" {print $1; exit}')}
a() { adb -s "$S" shell am compat "$@"; }
case "$1" in
  apply)
    a disable UNIVERSAL_RESIZABLE_BY_DEFAULT $P
    a enable OVERRIDE_RESPECT_REQUESTED_ORIENTATION $P
    a enable OVERRIDE_MIN_ASPECT_RATIO $P
    a enable OVERRIDE_MIN_ASPECT_RATIO_LARGE $P ;;
  reset)
    for c in UNIVERSAL_RESIZABLE_BY_DEFAULT OVERRIDE_RESPECT_REQUESTED_ORIENTATION \
             OVERRIDE_MIN_ASPECT_RATIO OVERRIDE_MIN_ASPECT_RATIO_LARGE FORCE_NON_RESIZE_APP; do
      a reset $c $P
    done ;;
  *) echo "usage: $0 apply|reset [adb-serial]" >&2; exit 1 ;;
esac
