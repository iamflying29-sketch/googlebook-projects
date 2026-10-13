# Smaller Fixes

These are one-off diagnoses and fixes on my Lenovo Googlebook 15, written up for reference. They are smaller
than the main projects, but each one started as a real problem that I traced to its cause.

| Write-up | Summary |
|---|---|
| [What the Linux Terminal's "Keep Awake" setting really does](terminal-keep-awake.md) | Keep Awake is not a screen setting. It holds a partial wake lock that keeps the Linux virtual machine running after you leave the Terminal or the screen turns off, and it switches itself back to Off when its timer runs out. The screen turns off because of the normal GooglebookOS screen timeout. Nothing needed to be fixed. |
| [Terminal session protection with tmux](tmux-session-protection/README.md) | The Terminal app's connection to the Linux virtual machine sometimes drops while the app is in the background, and the terminal server then kills the shell and every program in it. Running every interactive shell inside tmux keeps those programs alive, and a new window re-attaches the session. Includes the tmux configuration and the `~/.profile` block. |

General setup steps for the Linux Terminal and adb are in the
[Getting Started guide](https://github.com/iamflying29-sketch/googlebook-projects/blob/main/GETTING-STARTED.md).

These write-ups are part of [Googlebook Projects](https://github.com/iamflying29-sketch/googlebook-projects),
released under the MIT License. Copyright (c) 2026 Thomas Liviakis. This is an independent, unofficial project. It
is not affiliated with, endorsed by, or sponsored by Google, Lenovo or any other company named here. All product
names belong to their owners.
