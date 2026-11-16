# Home Depot App Phone Mode on the Googlebook

I made the Home Depot Android app (`com.thehomedepot`) usable on my Googlebook by keeping it in a phone-sized
window.

I tested this on my Lenovo Googlebook 15 (x86-64, GooglebookOS based on Android 17, a 2880 by 1800 display at
240 dpi) with Home Depot app 8.2.4.

## The problem

On my Googlebook, the app opened and then showed this message:

> **Continue shopping online.** The Home Depot app is no longer supported for tablet devices.

The app checks the size of its own window, and it treats any window that is **600 dp or wider** as a tablet. Two
things combine to trigger it:

1. The app's manifest asks for portrait orientation, but Android 16 and later ignore that on large screens for
   apps that target SDK 36. This is the compatibility change `UNIVERSAL_RESIZABLE_BY_DEFAULT`.
2. Because of that, GooglebookOS's desktop windowing opens the app in its default landscape window, which covers
   72% of the screen, about 1382 by 864 dp. To the app, that window is a tablet.

In a window narrower than 600 dp, the app works and shows its normal phone layout.

## How I solved it

The fix has two parts, plus a starter that makes it survive restarts.

| Part | What it does |
|---|---|
| **Remembered window size** (`tools/set-phone-window.sh`, run once) | GooglebookOS's desktop windowing remembers each app's last window size, but only when a person drags or resizes the window. It stores the size as `rememberedBoundsRatioByPackageName` in WMShell and saves it to disk, so it survives reboots. `am task resize` does not count, so the script performs real mouse drags with `input mouse motionevent` to make the window tall, centered and 448 dp wide. From then on, the app opens phone-sized. |
| **Watcher** (`android/hd-phone.sh`) | A small shell loop that runs on GooglebookOS as the adb shell user. If any Home Depot window becomes 600 dp or wider, for example after maximizing, dragging it wider or a launch at the default size, it snaps the window back to phone size within about a second. Then it drags the window's left edge with a real mouse drag, so GooglebookOS saves the phone size again. While the app is open, it also checks the saved size every 30 seconds and drags again if needed, and after 3 failed drags in a row it waits 10 minutes. The app then lays itself out as a phone again. Since October 30, 2026 it also handles a Home Depot task that has left the desktop altogether and become a fullscreen task, which happens when the app is brought to the front while no desktop window is showing, for example from the lock screen. A fullscreen task is always a tablet to the app, and `am task resize` cannot change that, so the watcher asks the desktop shell for the active desk, falls back to the desk list when the shell reports none, checks that the id is a number from the system's own list, and only then moves the task back onto the desk with `moveTaskToDesk`, the same move as the window menu's own entry. It only does this for a visible task, at most once a minute, and on any doubt it writes a line to its log and does nothing. While the app is not running, the watcher only does a cheap `pidof` check. |
| **Starter** (my [Home Depot Helper](https://github.com/iamflying29-sketch/googlebook-homedepot-helper) app) | The Home Depot Helper app carries a copy of the watcher. About 10 seconds after every restart, and then every 15 minutes, it connects to Wireless debugging on the Googlebook itself with its own pairing key, installs the watcher if the copy there differs, and starts it when it is not running or has stopped responding (its heartbeat is more than 2 minutes old), stopping a frozen watcher first. No Linux Terminal is needed. |

Until November 16, 2026 a keeper in the Linux Terminal (`terminal/hd-keeper`) started the watcher. The Terminal
only starts when you open it, so after a restart the watcher stayed off, and the Home Depot app showed its tablet
error, until I opened the Terminal. I retired that keeper and moved the job into the Home Depot Helper app. Its files
are still in `terminal/` for reference, and you do not need them.

Maximizing the app gives a full-height phone window, not a full-screen phone layout, because a full-width window is
always a tablet to the app.

When the watcher fixes a window, its drag moves the mouse pointer for about a second. That is the only way to make
GooglebookOS save the size.

## Setup

Run all of these commands in the Googlebook's **Linux Terminal** app. General setup for the Linux Terminal and adb is
in the [Getting Started guide](https://github.com/iamflying29-sketch/googlebook-projects/blob/main/GETTING-STARTED.md).

1. **Get the files.**
   ```bash
   git clone https://github.com/iamflying29-sketch/googlebook-projects.git
   cd googlebook-projects/smaller-fixes/homedepot-phone-mode
   ```

2. **Install the Home Depot Helper app** and give it its own pairing key, as its
   [README](https://github.com/iamflying29-sketch/googlebook-homedepot-helper#installation) describes in
   Installation, steps 1 to 6. It installs and starts the watcher by itself, and the status window shows the last
   watcher check.

3. **Set the remembered phone window (once).** Close the Home Depot app if it is open, then run:
   ```bash
   bash tools/set-phone-window.sh
   ```

4. **Optional:** `bash android/compat-overrides.sh apply` applies the per-app compatibility overrides that were in
   place during my testing. The comments in the script explain them. Do **not** enable `FORCE_NON_RESIZE_APP`,
   because it makes GooglebookOS ignore and clear the remembered window size.

## After a reboot

GooglebookOS always turns Wireless debugging off at boot. As soon as it is on again, the Home Depot Helper starts the
watcher by itself; on my Googlebook, my [Sleep Guard](https://github.com/iamflying29-sketch/googlebook-sleep-guard)
switches Wireless debugging back on after every restart. You do not need to open the Linux Terminal. The remembered
window size does not depend on any of this, so the app keeps opening phone-sized.

## Checking on it

Open the Home Depot Helper app: its status window shows the last watcher check, and **Check the phone-size watcher
now** runs one at once. Over adb:

```bash
adb shell cat /data/local/tmp/hd-phone.log     # resizes and rescues done by the watcher
adb shell cat /data/local/tmp/hd-phone.beat    # the watcher's heartbeat, a time in seconds
adb shell 'dumpsys activity service SystemUIService WMShell' | grep 'com.thehomedepot ->'
```

## Uninstalling

```bash
adb uninstall --user <USER_ID> local.hdhelper     # the Home Depot Helper app, if you no longer want it
adb shell 'kill $(cat /data/local/tmp/hd-phone.pid)'   # stops the watcher
bash terminal/uninstall.sh                 # only if you installed my earlier Terminal keeper
bash android/compat-overrides.sh reset     # if you applied the overrides
adb shell 'dumpsys activity service SystemUIService WMShell desktopmode clearRememberedBounds com.thehomedepot'
```

## Other apps

The watcher and the window script read `HD_PACKAGE` (the app's package name) and `HD_PHONE_DP` (the window width in
dp) from the environment, so the same approach works for other phone-only apps.

## Files

| File | What it is |
|---|---|
| `android/hd-phone.sh` | The watcher. It runs on GooglebookOS as the adb shell user. |
| `android/compat-overrides.sh` | Optional per-app compatibility overrides (`apply` or `reset`). |
| `terminal/hd-keeper` | My earlier keeper loop for the Linux Terminal, retired on November 16, 2026 (see above). |
| `terminal/hd-keeper.service` | The systemd unit for that retired keeper. |
| `terminal/install.sh` | Installs the retired keeper. Not needed any more. |
| `terminal/uninstall.sh` | Removes the retired keeper and stops the watcher. |
| `tools/set-phone-window.sh` | One-time setup that sets the remembered phone-sized window. |
| `README.md` | This document. |

This write-up is part of [Googlebook Projects](https://github.com/iamflying29-sketch/googlebook-projects), released
under the MIT License. Copyright (c) 2026 Thomas Liviakis. This is an independent, unofficial project. It is not
affiliated with, endorsed by, or sponsored by Google, Lenovo, The Home Depot or any other company named here. All
product names belong to their owners.
