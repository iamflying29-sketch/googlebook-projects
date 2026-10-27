#!/bin/bash
# Removes hd-keeper from the Linux Terminal and stops the watcher on Android.
#   bash terminal/uninstall.sh
sudo systemctl disable --now hd-keeper 2> /dev/null
sudo rm -f /usr/local/bin/hd-keeper /etc/systemd/system/hd-keeper.service /etc/default/hd-keeper
sudo rm -rf /usr/local/share/hd-keeper /var/lib/hd-keeper
sudo systemctl daemon-reload

for d in $(adb devices | awk 'NR > 1 && $2 == "device" {print $1}'); do
  adb -s "$d" shell 'p=$(cat /data/local/tmp/hd-phone.pid 2>/dev/null)
    [ -n "$p" ] && grep -q hd-phone /proc/$p/cmdline 2>/dev/null && kill $p
    rm -f /data/local/tmp/hd-phone.sh /data/local/tmp/hd-phone.pid /data/local/tmp/hd-phone.log'
done
echo "hd-keeper removed."
