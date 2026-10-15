# WebView Guard: WebView updates no longer close the Linux Terminal

## The problem

On 15 October 2026, my Linux Terminal closed by itself in the middle of my work, and the Linux virtual machine
stopped with it. Nothing in the virtual machine had gone wrong: its logs simply ended, with no out-of-memory kill and
no kernel error.

The Googlebook's own record of why the Terminal app ended told the real story. I read it over adb with
`dumpsys activity exit-info com.android.virtualization.terminal`. The reason was "PACKAGE UPDATED", with the
description "stop com.google.android.webview due to killDueToPackageUpdate", and
`dumpsys package com.google.android.webview` showed that the Play Store had updated Android System WebView in the
same second.

## Why it happens

- The Terminal app draws its window with WebView, so WebView's code runs inside the Terminal's own process, and the
  Linux virtual machine lives in that process too.
- Android cannot replace code that a running app has loaded. When the WebView package an app loaded is updated,
  Android ends every app that loaded it. For most apps that is harmless, but for the Terminal it stops Linux.
- The Play Store only avoids updating an app while that app itself is in use. WebView is never "in use" as an app,
  and a Googlebook on the charger with its screen off meets every condition the Play Store has for updating.
- I looked for a way to hold the update back. The Play Store does not offer its per-app "Enable auto update" switch
  for Android System WebView on the Googlebook, because WebView is a built-in system part. Over adb, the shell cannot
  block installs, change WebView's installer, or claim its updates, and Android has no setting that delays the
  shutdown of apps that use WebView.

## The fix

Android lets the WebView that apps use come from a different package. Android System WebView Beta is one of the
packages the Googlebook accepts, and unlike the built-in WebView, the Play Store lets me switch off its automatic
updates. So:

1. The Terminal, and every other app, uses WebView Beta. Updates to the regular Android System WebView no longer touch
   any running app, so the Play Store can keep updating everything automatically.
2. WebView Beta only updates when I tap Update, and WebView Guard tells me when that is safe.

WebView Guard has two small parts:

- **`webview-guard`** runs in the Linux virtual machine every 30 minutes and when the virtual machine starts. It
  checks which WebView apps use, compares it with the newest version Google has published, and starts the watcher
  on the Googlebook when there is something to do. New terminal windows show a one-line reminder while an update is
  waiting.
- **`watch.sh`** runs on the Googlebook as the adb shell user, detached from adb, so it keeps running after the
  Terminal closes. It waits until the Terminal's Linux virtual machine has stopped, then either switches apps to
  WebView Beta with Android's own command (`cmd webviewupdate set-webview-implementation`), because switching closes
  apps that use WebView too, or posts the notification "Safe to update WebView now". If the Terminal opens again
  first, the notification changes to say so. Android does not let the shell attach a tap action to a notification,
  so its text says what to do.

## Setting it up

1. Install "Android System WebView Beta" from the Play Store. Its page is not always shown in search, but
   `adb shell am start -a android.intent.action.VIEW -d market://details?id=com.google.android.webview.beta` opens
   it. Installing it does not change which WebView apps use, so it is safe while the Terminal is open.
2. On its Play Store page, open the three-dot menu and uncheck "Enable auto update".
3. The Play Store installs it only for the signed-in user, and Android only switches to a WebView installed for
   every user, so run `adb shell pm install-existing --user 0 com.google.android.webview.beta`.
4. Copy this folder to `~/projects/webview-guard` in the Linux VM, then install the timer and the reminder:
   ```bash
   cp ~/projects/webview-guard/webview-guard.service ~/projects/webview-guard/webview-guard.timer ~/.config/systemd/user/
   systemctl --user daemon-reload && systemctl --user enable --now webview-guard.timer
   sudo install -m 644 ~/projects/webview-guard/profile-snippet.sh /etc/profile.d/webview-guard.sh
   ~/projects/webview-guard/webview-guard check
   ```
   `webview-guard` finds the Googlebook through the Wireless debugging address my other helpers publish in
   `/mnt/shared/Documents`, so adb must be paired once.
5. Close the Terminal. Within about ten seconds, the Googlebook shows "The Terminal now uses WebView Beta". Then the
   Play Store's automatic app updates can be on again.

`webview-guard` alone shows the state, `webview-guard check` does the work, and `webview-guard test` posts a test
notification.

## A desktop shortcut for updating WebView Beta

`update-shortcut/` is a tiny app, "Update WebView Beta", with its source and build script (`build.sh` builds and signs
it with the Android SDK). A ready-made APK is attached to the
[Update WebView Beta 1.0 release](https://github.com/iamflying29-sketch/googlebook-projects/releases/tag/webview-guard-shortcut-1.0),
with its SHA-256 checksum; install it with `adb install UpdateWebViewBeta.apk`. Clicking its icon shows a short reminder to close the
Terminal first and then opens WebView Beta's page in the Play Store, where I tap Update. Its third button, "Add to
desktop", asks the launcher to put the shortcut on the desktop. It has no permissions.

Installing WebView Beta also brought a "WebView DevTools" icon to my desktop. That is a tool for web developers that
Google builds into every pre-release WebView, and it is not needed. Removing its icon from the desktop is fine, but
uninstalling it would remove WebView Beta itself, because it is part of the same package.

## How I tested it

- With the Terminal open, I installed WebView Beta and added it for the device's other user. Android kept using the
  regular WebView, and the Linux virtual machine kept running without a hiccup.
- I dropped the virtual machine's adb connection on purpose, and the watcher kept running on the Googlebook.
- Then I closed the Terminal. The watcher switched apps to WebView Beta about a minute before I reopened the
  Terminal, and Android confirmed the switch (`dumpsys webviewupdate` shows WebView Beta as the current package).
- In the reopened Terminal, `dumpsys activity processes com.android.virtualization.terminal` lists exactly one
  package dependency: `com.google.android.webview.beta`. The regular WebView can update now without closing it.

## Two things I learned on the way

- `pm list packages NAME` also lists every package whose name starts with NAME, so asking for WebView's version
  returned WebView Beta's too. The first watcher took that for an update and posted a false "up to date" message.
  Both scripts now only read the exact package's line.
- A notification posted by the shell goes to user 0 unless it names a user, and on the Googlebook my apps run as
  user 10. The watcher posts to the current user (`am get-current-user`).

## Safety

- The watcher only reads two things (whether the Terminal's virtual machine runs, and a package's version), posts its
  own notification, and makes the one switch to WebView Beta. It stops after seven days, and every adb and network
  call on the Linux side has a time limit.
- It recognizes the virtual machine by its `crosvm_debian` process, owned by the Terminal app, so a closed Terminal
  that Android keeps cached in the background counts as closed.

## Limits

- WebView Beta is a pre-release version of WebView, usually about a week ahead of the regular one.
- If I tap "Update all" in the Play Store while the Terminal is open, WebView Beta would update and close the
  Terminal. The reminder in new terminal windows is there for that.
- If WebView Beta is uninstalled, Android goes back to the regular WebView, and the problem returns.
- To undo it, choose Android System WebView again under Developer options, WebView implementation (while the
  Terminal is closed), and create `~/.local/state/webview-guard/keep-stable` so the watcher does not switch back.

This write-up is part of [Googlebook Projects](https://github.com/iamflying29-sketch/googlebook-projects), released
under the MIT License. Copyright (c) 2026 Thomas Liviakis. This is an independent, unofficial project. It is not
affiliated with, endorsed by, or sponsored by Google, Lenovo or any other company named here.
