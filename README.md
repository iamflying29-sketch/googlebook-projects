# Googlebook Projects

Open-source fixes and apps for the Lenovo Googlebook 15, by Thomas Liviakis.

The Googlebook is a brand new class of device: an x86-64 laptop running GooglebookOS, a desktop build of Android 17
that can also run Chrome web apps. Almost no one is building for it yet. Every project here started as a real
problem on my own Lenovo Googlebook 15. I traced each one through the system's own code and logs to its root cause,
then built and tested a fix that keeps itself running, survives app and GooglebookOS updates where it can, and is
published here as open source so that others can read it, use it, edit it and fork it.

> These projects were built and tested on one device: a Lenovo Googlebook 15 (x86-64 Intel) running GooglebookOS
> build CL3B.260622.271.R1. Other Googlebooks, including the ARM models with Snapdragon processors, and later builds
> may behave differently. You are welcome to adapt the code for them.

## How these repositories fit together

Googlebook Projects is a family of repositories. This one is the hub. Each project lives in its own repository,
and each of those repositories is linked into this hub as a Git **submodule** under the `projects/` folder. On
GitHub, clicking a project folder takes you straight to that project's repository. Every repository in the family
also carries the `googlebook` topic.

To download everything at once:

```bash
git clone --recurse-submodules https://github.com/iamflying29-sketch/googlebook-projects.git
```

Before you set up any project, read the **[Getting started guide](GETTING-STARTED.md)**. It shows how to turn on the
Linux Terminal, install adb, connect to GooglebookOS over Wireless debugging, find your Android user ID, and install
the Android SDK build tools.

**Turn on "Disable adb authorization timeout" in Developer options and leave it on.** Otherwise Android forgets every
Wireless debugging pairing that has not connected for 7 days, without a word: on 2026-10-17 the pairings of Sleep
Guard and Shadow Trackpad Fix vanished that way and both stopped working. The guide shows where the switch is.

## Projects

| Project | The problem | What I built |
|---|---|---|
| [Sleep Guard](https://github.com/iamflying29-sketch/googlebook-sleep-guard) | The Googlebook lost all power during lid-closed deep sleep when the charger was unplugged, and it booted from scratch when the lid was opened. | An on-device helper, an app and a Linux Terminal command that hold the laptop awake for a fraction of a second on every lid-closed wake, so the hardware can finish handling a charger change before deep sleep resumes. |
| [Shadow Trackpad Fix](https://github.com/iamflying29-sketch/googlebook-shadow-trackpad-fix) | In the Shadow PC app, slow two-finger scrolling did nothing, and pinch, flick and multi-finger swipes did not work at all. | An input helper with its own gesture engine, a companion app that keeps it running, a doctor that re-checks everything after updates, and Trackpad Probe, the diagnostic app that proved the root cause. |
| [Buds LE Link](https://github.com/iamflying29-sketch/googlebook-buds-le-link) | Galaxy Wearable crashed with the Galaxy Buds4, and once that was fixed, the Buds plugin showed "disconnected" over LE Audio and needed a manual Connect every time. | The fix for the plugin crash, plus a small background app that reconnects the plugin's control link automatically, checks it every 15 minutes, and puts the plugin back in ARM mode after a restart. |
| [Gmail Web App Notification Issue](https://github.com/iamflying29-sketch/googlebook-gmail-web-app-notifications) | The Gmail web app could not notify while it was closed, and its alerts vanished from the Notification Center after about 7 seconds. | Real, lasting Gmail notifications with Reply, Delete and Mark as read, built from Gmail Go as the push engine, Notification Keeper, an accessibility helper and a background service in the Linux Terminal. |
| [Notification Keeper](https://github.com/iamflying29-sketch/googlebook-notification-keeper) | Web apps withdraw their own notifications a few seconds after posting them, so nothing is left in the Notification Center. | An open-source Android app that keeps a copy of every withdrawn web app notification. It was designed for Gmail first, and its goal is to preserve notifications for every Chrome web app on GooglebookOS. |
| [Battery Widget](https://github.com/iamflying29-sketch/googlebook-battery-widget) | Google's Batteries widget never showed connected Bluetooth earbuds. | A permission fix for the widget's app, made permanent, with a one-command repair script. |
| [Waydroid](https://github.com/iamflying29-sketch/googlebook-waydroid) | Waydroid in the Linux Terminal never finished booting Android. | The networking fix and the other changes that make Waydroid boot and run Google Play inside the Linux Terminal, with launcher buttons. |
| [Continue On](https://github.com/iamflying29-sketch/googlebook-continue-on) | Google's Continue On feature requires an Android 17 phone, so my Android 15 tablet and Android 16 phone were left out. | A working stand-in that mirrors and controls those devices on the Googlebook with an open-source scrcpy client. |
| [Forge IDE](https://github.com/iamflying29-sketch/googlebook-forge-ide) | Using my local Llama 3.1 model meant typing into a terminal, prompts took minutes to process on the CPU, and the Linux VM cannot use the Intel graphics. | A Cursor-style AI coding IDE with an agent that edits files and runs commands, chat tabs, visible thinking, inline review of every change, code intelligence (including Kotlin, Java and Rust), Android builds with virtual Android devices from Android 11 to Android 17, including Google's apps and Google's own Wear OS 6, Google TV 16, Pixel-style Android 16, Android Automotive 15 and desktop Android 14 builds (phones, foldables, tablets, watches, TVs, cars and desktops, without an emulator), the makers' own Android under ARM emulation (Samsung One UI 8 and Nothing OS 4 boot to their setup wizards, and OnePlus, OPPO, Xiaomi, Honor, vivo, Realme and Pixel images are prepared the same way), device personas of 28 real Galaxy, Pixel, OnePlus, Motorola, Lenovo, Xiaomi, Fire TV and Shield devices, Compose previews of phone, watch and TV screens without a device, real devices from Google's and Samsung's device labs, a debugger for Python, C, C++, Rust, Kotlin, Java, JavaScript, TypeScript and Android apps, notebooks in Python, Kotlin and Bash, a codebase index that searches by meaning, voice input, a live view of Llama and the vision model working together, emulator images that check their own sources for updates and upgrades daily and install them with one click, a native Kotlin app with an editor that works like Cursor's, and a GPU engine that runs Llama or Qwen3.5 4B on the Intel graphics from the Android side of the laptop and, with Qwen3.5, looks at screenshots itself. |
| [Home Depot Helper](https://github.com/iamflying29-sketch/googlebook-homedepot-helper) | A tap on a Home Depot order notification from my Notification Keeper could only open the Home Depot app, not the order the email was about, and a sign-in verification code had to be read and typed by hand. | A small Kotlin app that reads the notification's subject and preview and opens the exact order or the purchase history inside the Home Depot app through the app's own links, and for a verification code copies it and types it into the app's code field with its own accessibility service. |

## Smaller fixes

One-off diagnoses and fixes are written up in **[smaller-fixes/](smaller-fixes/)**, including what the Linux
Terminal's "Keep Awake" setting really does, how I protect long-running Terminal sessions with tmux, and how I stopped
WebView updates from closing the Terminal.

## Design principles

- **Never block GooglebookOS.** Helpers that read system service output read it while it is being written, with a
  deadline, and they put a time limit on every command. Long-running helpers have watchdogs that release anything
  they hold if they ever stall.
- **Fail safe.** When a helper sees a GooglebookOS build or an app version it has not verified, it stands down,
  falls back or warns you instead of guessing.
- **No root and no system changes.** Everything uses the permissions that adb's shell user already has.
- **Honest limits.** Every README says what was tested, what was not, and what can still go wrong.

## Security and privacy

- No signing keys, adb keys, passwords, browser sign-ins or personal data are part of these repositories. Every build
  script creates its own keystore the first time you run it, so your builds are signed with your own key.
- Third-party apps, such as Gmail Go and Samsung's Galaxy Wearable plugin, are never included. Where a project needs
  one, its README explains where to get it the legal way.

## Website

The source of the Googlebook Projects website is in the [docs/](docs/) folder.

## Credits

I built and documented these projects with the help of Claude Code, Anthropic's AI coding assistant.

## Disclaimer and license

This is an independent, unofficial project. It is not affiliated with, endorsed by, or sponsored by Google, Lenovo
or any other company named here. All product names belong to their owners. Released under the MIT License.
Copyright (c) 2026 Thomas Liviakis.
