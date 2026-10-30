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

The fix has two parts, plus a keeper that makes it survive reboots.

| Part | What it does |
|---|---|
| **Remembered window size** (`tools/set-phone-window.sh`, run once) | GooglebookOS's desktop windowing remembers each app's last window size, but only when a person drags or resizes the window. It stores the size as `rememberedBoundsRatioByPackageName` in WMShell and saves it to disk, so it survives reboots. `am task resize` does not count, so the script performs real mouse drags with `input mouse motionevent` to make the window tall, centered and 448 dp wide. From then on, the app opens phone-sized. |
| **Watcher** (`android/hd-phone.sh`) | A small shell loop that runs on GooglebookOS as the adb shell user. If any Home Depot window becomes 600 dp or wider, for example after maximizing, dragging it wider or a launch at the default size, it snaps the window back to phone size within about a second. Then it drags the window's left edge with a real mouse drag, so GooglebookOS saves the phone size again. While the app is open, it also checks the saved size every 30 seconds and drags again if needed, and after 3 failed drags in a row it waits 10 minutes. The app then lays itself out as a phone again. Since October 30, 2026 it also handles a Home Depot task that has left the desktop altogether and become a fullscreen task, which happens when the app is brought to the front while no desktop window is showing, for example from the lock screen. A fullscreen task is always a tablet to the app, and `am task resize` cannot change that, so the watcher asks the desktop shell for the active desk, falls back to the desk list when the shell reports none, checks that the id is a number from the system's own list, and only then moves the task back onto the desk with `moveTaskToDesk`, the same move as the window menu's own entry. It only does this for a visible task, at most once a minute, and on any doubt it writes a line to its log and does nothing. While the app is not running, the watcher only does a cheap `pidof` check. |
| **Keeper** (`terminal/hd-keeper`, a systemd service) | Runs in the Googlebook's own **Linux Terminal** (the Debian virtual machine). It uses the Terminal's own adb pairing with GooglebookOS, so it needs no other computer. Every 30 seconds, it checks that the watcher is running, and it restarts the watcher after a reboot, after a crash, or when the script has been updated. If the Wireless debugging port has changed, it finds the new port by scanning. |

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

2. **Pair the Terminal's adb with GooglebookOS (once).**
   Open **Settings > System > Developer options > Wireless debugging**, turn it on, and tap
   **Pair device with pairing code**. Then run these commands in the Terminal:
   ```bash
   sudo apt-get install -y adb      # if not installed yet
   adb pair <ip>:<pairing-port> <6-digit-code>
   adb connect <ip>:<port>          # port shown on the Wireless debugging screen
   adb devices                      # should list the device as "device"
   ```
   `<ip>` is the Googlebook's Wi-Fi IP address, as shown on that screen.

3. **Install the keeper.** It installs and starts the watcher too.
   ```bash
   bash terminal/install.sh
   ```

4. **Set the remembered phone window (once).** Close the Home Depot app if it is open, then run:
   ```bash
   bash tools/set-phone-window.sh
   ```

5. **Optional:** `bash android/compat-overrides.sh apply` applies the per-app compatibility overrides that were in
   place during my testing. The comments in the script explain them. Do **not** enable `FORCE_NON_RESIZE_APP`,
   because it makes GooglebookOS ignore and clear the remembered window size.

## After a reboot

GooglebookOS always turns Wireless debugging off at boot, and the Linux Terminal's virtual machine only starts when
the Terminal app is opened. So after a reboot:

1. Turn **Wireless debugging** back on.
2. Open the **Terminal** app once.

The keeper reconnects and restarts the watcher within about 2 minutes. The remembered window size does not depend on
either step, so the app keeps opening phone-sized.

## Checking on it

```bash
systemctl status hd-keeper
journalctl -u hd-keeper -n 50
adb shell cat /data/local/tmp/hd-phone.log     # resizes done by the watcher
adb shell 'dumpsys activity service SystemUIService WMShell' | grep 'com.thehomedepot ->'
```

## Uninstalling

```bash
bash terminal/uninstall.sh                 # keeper and watcher
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
| `terminal/hd-keeper` | The keeper loop. It runs in the Linux Terminal. |
| `terminal/hd-keeper.service` | The systemd unit for the keeper. |
| `terminal/install.sh` | Installs or updates the keeper. |
| `terminal/uninstall.sh` | Removes the keeper and the watcher. |
| `tools/set-phone-window.sh` | One-time setup that sets the remembered phone-sized window. |
| `README.md` | This document. |

This write-up is part of [Googlebook Projects](https://github.com/iamflying29-sketch/googlebook-projects), released
under the MIT License. Copyright (c) 2026 Thomas Liviakis. This is an independent, unofficial project. It is not
affiliated with, endorsed by, or sponsored by Google, Lenovo, The Home Depot or any other company named here. All
product names belong to their owners.
