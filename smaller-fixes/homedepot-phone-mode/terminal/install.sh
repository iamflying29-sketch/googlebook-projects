#!/bin/bash
# Installs hd-keeper into the Googlebook's Linux Terminal (Debian VM).
#   bash terminal/install.sh
# Pair this Terminal's adb with Android first (README, step 1). If adb is
# connected while this runs, Android's address and model are saved to
# /etc/default/hd-keeper so the keeper can find it again later.
set -e
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")

command -v adb > /dev/null || sudo apt-get install -y adb
command -v nc > /dev/null || sudo apt-get install -y netcat-openbsd

sudo install -Dm755 "$here/hd-keeper" /usr/local/bin/hd-keeper
sudo install -Dm644 "$repo/android/hd-phone.sh" /usr/local/share/hd-keeper/hd-phone.sh
sed "s/^User=.*/User=$USER/; s|^Environment=HOME=.*|Environment=HOME=$HOME|" "$here/hd-keeper.service" \
  | sudo tee /etc/systemd/system/hd-keeper.service > /dev/null
sudo install -d -o "$USER" /var/lib/hd-keeper

d=$(adb devices | awk 'NR > 1 && $2 == "device" && $1 ~ /:/ {print $1; exit}')
if [ -n "$d" ]; then
  model=$(adb -s "$d" shell getprop ro.product.model | tr -d '\r')
  printf 'HD_HOST=%s\nHD_MODEL="%s"\n' "${d%:*}" "$model" | sudo tee /etc/default/hd-keeper > /dev/null
  echo "Managing: $model at ${d%:*}"
else
  echo "Note: adb is not connected to Android right now; using defaults (see /etc/default/hd-keeper)."
fi

sudo systemctl daemon-reload
sudo systemctl enable --now hd-keeper
sudo systemctl restart hd-keeper
echo "hd-keeper installed. Status: systemctl status hd-keeper   Log: journalctl -u hd-keeper"
[ -f /var/lib/hd-keeper/adbhome/.android/adbkey ] || echo "Next: pair the keeper's own key with  hd-keeper pair CODE IP:PAIRPORT  (README, step 3)."
