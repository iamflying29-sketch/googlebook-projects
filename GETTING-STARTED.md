# Getting started

Every project in Googlebook Projects is set up from the Googlebook's own **Linux Terminal**, and it talks to
GooglebookOS through **adb over Wireless debugging**. This guide covers the setup that all of the projects share.
Each project's README then gives its own steps.

I built and tested everything on a Lenovo Googlebook 15 (x86-64 Intel) running GooglebookOS, a desktop build of
Android 17 (build CL3B.260622.271.R1). The Linux Terminal on that build runs Debian 13 (trixie) for x86-64.

## 1. Turn on Developer options

1. Open **Settings** and find **Build number** in the About section. If you cannot find it, search Settings for
   "Build number".
2. Tap **Build number** seven times, and enter your password or PIN if GooglebookOS asks for it.
3. **Developer options** now appears under **Settings > System > Developer options**.

## 2. Turn on the Linux Terminal

1. In **Developer options**, turn on the Linux development environment. If your build puts it somewhere else,
   search Settings for "Linux".
2. Open the **Terminal** app and let it download and set up Debian. This takes a few minutes the first time.

## 3. Install adb and the basic tools in the Linux Terminal

```bash
sudo apt update
sudo apt install adb python3 openjdk-21-jdk-headless unzip
```

`adb` is Debian's package of the Android Debug Bridge. The JDK is only needed for projects that you build from
source.

## 4. Connect to GooglebookOS over Wireless debugging

The Linux Terminal runs in a virtual machine, so it reaches GooglebookOS over your Wi-Fi network, the same way a
separate computer would. Automatic discovery does not work from inside the virtual machine, so you always type the
address yourself.

1. Make sure your Googlebook is connected to Wi-Fi.
2. Open **Settings > System > Developer options > Wireless debugging** and turn it on.
3. Tap **Pair device with pairing code**. Keep that dialog open. It shows an IP address and port and a six-digit
   code.
4. In the Linux Terminal, pair with the address, port and code from the dialog:

   ```bash
   adb pair 192.0.2.10:37000 123456
   ```

   Replace `192.0.2.10:37000` and `123456` with the values on your screen. (192.0.2.10 is a reserved example
   address, not a real one.)
5. Close the dialog. The main **Wireless debugging** screen shows a different port under **IP address & Port**.
   Connect to that one:

   ```bash
   adb connect 192.0.2.10:41000
   adb devices
   ```

   `adb devices` should list your Googlebook with the word `device` after it.

You only pair once. The connection port changes when Wireless debugging restarts, for example after a reboot or
after the Wi-Fi drops, so you may need to run `adb connect` again with the new port shown on the Wireless debugging
screen. Some projects, such as Sleep Guard and Shadow Trackpad Fix, handle reconnecting by themselves.

**Never scan your network or a range of ports to find the address.** Read it from the Wireless debugging screen.

## 5. Find your Android user ID

GooglebookOS runs your account as an Android user that is not always user 0. On my Googlebook it is user 10. Several
projects need this number, so check yours:

```bash
adb shell am get-current-user
```

Wherever a project's instructions say `<USER_ID>`, use the number this command prints.

## 6. Install the Android SDK build tools (only for building apps from source)

The Android apps in these projects are built with plain SDK tools (aapt2, javac, d8, zipalign and apksigner), with
no Gradle and no Android Studio. Their build scripts expect the SDK in `~/tools/android-sdk`.

1. Download the **Command line tools only** package for Linux from
   <https://developer.android.com/studio#command-tools>.
2. Unpack it so that `sdkmanager` ends up at `~/tools/android-sdk/cmdline-tools/latest/bin/sdkmanager`:

   ```bash
   mkdir -p ~/tools/android-sdk/cmdline-tools
   cd ~/tools/android-sdk/cmdline-tools
   unzip ~/Downloads/commandlinetools-linux-*_latest.zip
   mv cmdline-tools latest
   ```

   Adjust the path to the zip file if you saved it somewhere else.
3. Install the build tools and the platform that the build scripts use, and accept the licenses when asked:

   ```bash
   ~/tools/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root="$HOME/tools/android-sdk" \
       "build-tools;35.0.0" "platforms;android-35"
   ```

Each build script creates its own signing keystore the first time you run it, so your builds are signed with your
own key. Keystores and keys are never part of these repositories.

## 7. Next steps

Pick a project from the [Googlebook Projects overview](README.md) and follow its README. Every README lists its exact
requirements, installation steps, commands, and how to remove it again.

## Safety notes

- Everything here uses the permissions that adb's shell user already has. Nothing needs root, and nothing modifies
  GooglebookOS itself.
- Wireless debugging gives a paired computer a lot of control over your device. Only pair computers you own, and you
  can revoke pairings at any time under **Wireless debugging > Paired devices**.
- These projects were built and tested on one device and one GooglebookOS build. Other Googlebooks or later builds
  may behave differently, and several projects check for that and stand down instead of guessing.
