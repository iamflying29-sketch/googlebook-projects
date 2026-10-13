# What the Linux Terminal's "Keep Awake" Setting Really Does

The Linux Terminal app on the Googlebook has a setting called Keep Awake. I thought it was broken, because my
screen still went to sleep while the Terminal was open in front of me. Reading the app's code showed that the
setting works as designed. It was simply never meant to keep the screen on. This write-up explains what Keep
Awake does, what actually turns the screen off, and what you can do instead.

## The problem

My Googlebook's screen turned off after a few minutes even while the Linux Terminal was the active window and
Keep Awake was set. I checked the system while the Terminal was focused:

| Check | Result |
|---|---|
| Is the Terminal the focused window? | Yes |
| Does the Terminal window ask to keep the screen on? | No (no `KEEP_SCREEN_ON` flag on its window) |
| Is anything holding the device awake? | No (zero wake locks) |
| GooglebookOS screen timeout | 5 minutes (300000 ms) |
| The Linux display's own blank timer | Already off (`idle-time=0` in `~/.config/weston.ini`) |

## What I found in the app's code

I decompiled the Terminal app that shipped with my GooglebookOS build (`CL3B.260622.271.R1`). Its Keep Awake
logic lives in the app's background service. This is what it does:

1. **It holds a partial wake lock, not a screen lock.** The service creates a wake lock of type
   `PARTIAL_WAKE_LOCK` with the tag `TerminalApp:KeepAwake`. A partial wake lock keeps the processor, and with it
   the Linux virtual machine, running while the screen is off. It never keeps the screen on.
2. **It only takes the lock when you leave the Terminal.** The service tracks whether the app is in the
   foreground. It releases the lock whenever the Terminal comes to the front, and takes it only when the Terminal
   leaves the foreground. The screen turning off while the Terminal is open counts as leaving the foreground too,
   so Keep Awake also covers the screen timing out.
3. **It is a one-shot timer.** The choices are Off, 1 minute, 5 minutes, 10 minutes, 30 minutes, 1 hour, 2 hours,
   6 hours and 1 day. When the chosen time runs out, the app switches the setting back to Off by itself. You have
   to set it again before the next long job.
4. **Nothing in the app keeps the screen on.** I found no keep-screen-on flag or call anywhere in its code.

So Keep Awake means "keep my Linux programs running after I switch away or the screen turns off". It does not
mean "keep my screen on".

## What turns the screen off

The screen turns off because of the normal GooglebookOS screen timeout, which was 5 minutes on my Googlebook. A
screen that is on keeps the whole computer running, so the Terminal does not need Keep Awake while it is in
front of you, which is why the app releases the lock then.

What happens when the screen times out depends on the setting:

- **Keep Awake set to Off:** when the screen turns off, the Googlebook can go into deep sleep, and the Linux
  virtual machine pauses. Anything running in it, such as a download, a build or Waydroid, stops until you wake
  the computer, and then continues where it left off.
- **Keep Awake set to a time:** the screen still goes dark, but the virtual machine keeps running for the time you
  picked. When that time runs out, the setting goes back to Off.

## What you can do

- **To keep the screen on longer,** change the Screen timeout option in the Googlebook's Display settings. This
  applies to every app, not just the Terminal.
- **To keep the screen on while charging,** turn on **Stay awake** in Developer options. It only helps while the
  Googlebook is charging.
- **To keep Linux programs running with the screen off,** set Keep Awake to a time that covers your job, and set
  it again next time, because it switches itself back to Off.

## Closing the lid is different

Later, while building my [Sleep Guard](https://github.com/iamflying29-sketch/googlebook-sleep-guard) project, I
found that GooglebookOS's power service force-disables every wake lock while the lid is closed. That includes the
Terminal's Keep Awake lock. So Keep Awake cannot keep the virtual machine running while the lid is closed, no
matter which time you choose.

## Conclusion

The setting works as designed, and nothing needed to be fixed. It keeps the Linux virtual machine running in the
background for a limited time, and the screen timeout is a separate GooglebookOS setting.

If your long jobs are killed while the Terminal is in the background, even though the virtual machine keeps
running, that is a different problem. See
[Terminal session protection with tmux](tmux-session-protection/README.md).

This write-up is part of [Googlebook Projects](https://github.com/iamflying29-sketch/googlebook-projects), released
under the MIT License. Copyright (c) 2026 Thomas Liviakis. This is an independent, unofficial project. It is not
affiliated with, endorsed by, or sponsored by Google, Lenovo or any other company named here. All product names
belong to their owners.
