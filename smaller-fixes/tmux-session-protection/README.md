# Terminal Session Protection with tmux

Long jobs in the Googlebook's Linux Terminal were sometimes killed in the middle of their work, even though the
Terminal app and its virtual machine kept running. This fix runs every interactive Terminal shell inside tmux, so
programs survive when the Terminal app's connection to the virtual machine drops, and a new Terminal window picks
up exactly where you left off.

## What it does

My long-running jobs in the Linux Terminal now survive a dropped connection. Every new Terminal window
automatically opens a tmux session, or re-attaches the session that a dropped connection left behind. The status
bar at the bottom reads "protected session", so I can see at a glance that the protection is active.

## The problem

Long jobs in the Linux Terminal were dying in the middle of their work. The Googlebook's logs showed why. About
two minutes after the Terminal app went into the background, its connection to the Linux virtual machine sometimes
dropped. The log line was:

```
AndroidToVmBridge: Client disconnected
```

The terminal server inside the virtual machine, `ttyd`, then sent SIGHUP (signal 1) to the login shell, which
ended the shell and every program running in it. The Terminal app and the virtual machine themselves kept
running, so nothing looked wrong until I came back to a fresh prompt. It did not happen every time: other long
stretches in the background were fine.

## How I solved it

1. **I installed tmux** (version 3.5a in the Linux Terminal's Debian 13). tmux runs programs in a session that
   belongs to a separate tmux server process, not to the Terminal window. When the window's shell is killed, the
   session and its programs keep running, detached.
2. **I made every new Terminal window use tmux automatically.** The Linux Terminal starts each window as a login
   shell (`ttyd` runs `/bin/bash -l`), which reads `~/.profile`. A short block at the end of `~/.profile` checks
   for a tmux session that nobody is attached to, which is what a dropped connection leaves behind. If it finds
   one, it re-attaches it. Otherwise it starts a new session.
3. **I kept it out of the way of everything else.** The block runs only for interactive shells whose input and
   output are a terminal, and only when you are not already inside tmux. Command shells that programs start in the
   background are not affected. Setting `NO_AUTO_TMUX=1` skips the feature.
4. **I added a small tmux configuration** with no delay after the Esc key, mouse support, a 50,000 line scrollback
   history, true color, clipboard support, and the "protected session" status bar.

In testing, I sent SIGHUP to a window's shell, the same signal `ttyd` sends after a disconnect. The program
running in tmux stayed alive, and the next Terminal window re-attached the same session.

## Requirements

- The Linux Terminal on the Googlebook. I set this up on GooglebookOS build `CL3B.260622.271.R1` with the Linux
  Terminal's Debian 13 (trixie) system.
- The `tmux` package. I use tmux 3.5a.
- Bash as your login shell, which is the default in the Linux Terminal, and no `~/.bash_profile` or
  `~/.bash_login` file, because Bash skips `~/.profile` when either of them exists.

## Installation

1. Install tmux:

   ```
   sudo apt install tmux
   ```

2. Download the files. They are in the `smaller-fixes/tmux-session-protection` folder of the
   [googlebook-projects](https://github.com/iamflying29-sketch/googlebook-projects) repository:

   ```
   cd ~
   git clone https://github.com/iamflying29-sketch/googlebook-projects.git
   cd googlebook-projects/smaller-fixes/tmux-session-protection
   ```

3. Back up your current files first:

   ```
   cp ~/.profile ~/.profile.bak-before-tmux
   [ -f ~/.tmux.conf ] && cp ~/.tmux.conf ~/.tmux.conf.bak
   ```

4. Install the tmux configuration and add the block to the end of `~/.profile`:

   ```
   cp tmux.conf ~/.tmux.conf
   cat profile-snippet.sh >> ~/.profile
   ```

5. Open a new Linux Terminal window. You should see the status bar with "protected session" at the bottom.

If you already use your own `~/.tmux.conf`, you do not have to replace it. The auto-attach block in `~/.profile`
works with any tmux configuration.

## Using it

- **Selecting text:** mouse mode is on, so the mouse wheel scrolls back through the history. To select text for
  copying, hold **Shift** while you drag.
- **After a dropped connection:** open a new Terminal window. It re-attaches the session that was left behind,
  with every program still running exactly where you left it.
- **Several windows:** if every existing session is already attached, a new window starts a new session.
- **Skipping tmux for one shell:** start it with `NO_AUTO_TMUX=1`, for example `NO_AUTO_TMUX=1 bash -l`.
- **Leaving tmux:** if you detach (Ctrl+B, then D) or exit tmux, the window falls back to the plain login shell.
- **Checking sessions:** `tmux ls` lists them and shows which ones are attached.

A quick way to check the re-attach behavior: detach in one window with Ctrl+B, then D, and open a new Terminal
window. The new window should re-attach the detached session.

## Updating, and what happens after app or GooglebookOS updates

The fix lives entirely in two files in your Linux home folder, so app and GooglebookOS updates do not touch it
unless they reset the Linux Terminal. If the Linux Terminal is reset or reinstalled, repeat the installation.
tmux itself is updated with the normal Debian updates (`sudo apt update` and `sudo apt upgrade`).

## Uninstalling

Put back your old `~/.profile`, or delete the block that starts with `# Keep Terminal sessions alive` at the end
of it. Then remove or restore `~/.tmux.conf`:

```
cp ~/.profile.bak-before-tmux ~/.profile
rm ~/.tmux.conf
```

If you had your own `~/.tmux.conf` before, restore it from `~/.tmux.conf.bak` instead. New Terminal windows then
open a plain shell again.

## Limitations

- tmux cannot help if the whole virtual machine stops, for example after a restart of the Googlebook or when an
  update closes the Terminal app. Programs in the virtual machine end in that case.
- Because mouse mode is on, plain dragging does not select text. Hold Shift while you drag.
- The fix protects programs from a dropped connection. It does not stop the connection from dropping.

## Files

| File | Purpose |
|---|---|
| `tmux.conf` | The tmux configuration. Copy it to `~/.tmux.conf`. |
| `profile-snippet.sh` | The auto-attach block. Append it to the end of `~/.profile`. |
| `README.md` | This document. |

This write-up is part of [Googlebook Projects](https://github.com/iamflying29-sketch/googlebook-projects), released
under the MIT License. Copyright (c) 2026 Thomas Liviakis. This is an independent, unofficial project. It is not
affiliated with, endorsed by, or sponsored by Google, Lenovo or any other company named here. All product names
belong to their owners.
