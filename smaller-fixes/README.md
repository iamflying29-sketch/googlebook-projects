# Smaller Fixes

These are one-off diagnoses and fixes on my Lenovo Googlebook 15, written up for reference. They are smaller
than the main projects, but each one started as a real problem that I traced to its cause.

| Write-up | Summary |
|---|---|
| [What the Linux Terminal's "Keep Awake" setting really does](terminal-keep-awake.md) | Keep Awake is not a screen setting. It holds a partial wake lock that keeps the Linux virtual machine running after you leave the Terminal or the screen turns off, and it switches itself back to Off when its timer runs out. The screen turns off because of the normal GooglebookOS screen timeout. Nothing needed to be fixed. |
| [WebView Guard: WebView updates no longer close the Terminal](webview-guard/README.md) | When the Play Store updates Android System WebView, Android closes every app that uses it, and the Linux Terminal draws its window with WebView, so the whole Linux virtual machine stopped. Nothing on the Googlebook can hold that update back, so the Terminal now uses WebView Beta, whose updates I control. A small watcher on the Googlebook made the switch while the Terminal was closed and tells me when it is safe to update. Includes the scripts. |
| [Terminal session protection with tmux](tmux-session-protection/README.md) | The Terminal app's connection to the Linux virtual machine sometimes drops while the app is in the background, and the terminal server then kills the shell and every program in it. Running every interactive shell inside tmux keeps those programs alive, and a new window re-attaches the session. Includes the tmux configuration and the `~/.profile` block. |
| [Home Depot app phone mode](homedepot-phone-mode/README.md) | The Home Depot app refused to run on my Googlebook and showed "The Home Depot app is no longer supported for tablet devices." The app treats any window 600 dp or wider as a tablet, and because Android 16 and later ignore its portrait-only setting on large screens, GooglebookOS opened it in a wide landscape window. The fix keeps the app in a tall, phone-sized window. A one-time script performs real mouse drags so that GooglebookOS remembers a 448 dp wide window for the app, a small watcher snaps any window that grows too wide back to phone size within about a second, and a keeper in the Linux Terminal keeps the watcher running after reboots. The same approach works for other phone-only apps. Includes the scripts. Since October 30, 2026 the watcher also moves a Home Depot window that has become a fullscreen task, for example after a launch from the lock screen, back onto the desk, so the app never gets stuck in its tablet mode. |

General setup steps for the Linux Terminal and adb are in the
[Getting Started guide](https://github.com/iamflying29-sketch/googlebook-projects/blob/main/GETTING-STARTED.md).

These write-ups are part of [Googlebook Projects](https://github.com/iamflying29-sketch/googlebook-projects),
released under the MIT License. Copyright (c) 2026 Thomas Liviakis. This is an independent, unofficial project. It
is not affiliated with, endorsed by, or sponsored by Google, Lenovo or any other company named here. All product
names belong to their owners.
