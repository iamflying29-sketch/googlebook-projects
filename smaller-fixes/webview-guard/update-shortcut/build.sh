#!/bin/bash
# Builds and signs UpdateWebViewBeta.apk with the Android SDK in ~/tools/android-sdk.
set -euo pipefail

cd "$(dirname "$0")"
SDK=${ANDROID_SDK:-$HOME/tools/android-sdk}   # where the Android SDK is installed
BT=$SDK/build-tools/37.0.0
JAR=$SDK/platforms/android-36.1/android.jar
KS=keystore.jks
KS_PASS=${KS_PASS:-change-me}   # the password for your own keystore (it is created on the first build)
VERSION_NAME=1.0
VERSION_CODE=$(( $(date +%s) / 60 ))   # epoch minutes: always increases, never a downgrade

# A fresh build directory each time (nothing is ever deleted).
B=build/$(date +%Y%m%d-%H%M%S)
mkdir -p "$B/classes" "$B/gen"

"$BT/aapt2" compile --dir res -o $B/res.zip
"$BT/aapt2" link -o $B/unsigned.apk -I "$JAR" --manifest AndroidManifest.xml \
    --min-sdk-version 33 --target-sdk-version 36 --version-code $VERSION_CODE --version-name $VERSION_NAME \
    --java $B/gen $B/res.zip

javac -Xlint:all -Xlint:-options -source 11 -target 11 -cp "$JAR" -d $B/classes \
    $B/gen/local/webviewupdate/R.java src/local/webviewupdate/*.java
"$BT/d8" --min-api 33 --lib "$JAR" --output $B $(find $B/classes -name '*.class')

python3 -I -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1], "a").write(sys.argv[2], "classes.dex")' \
    $B/unsigned.apk $B/classes.dex
"$BT/zipalign" -p -f 4 $B/unsigned.apk $B/aligned.apk

if [ ! -f "$KS" ]; then
    keytool -genkeypair -keystore "$KS" -storepass "$KS_PASS" -keypass "$KS_PASS" -alias webviewupdate \
        -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Update WebView Beta (local build)"
fi
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$KS_PASS" --out UpdateWebViewBeta.apk $B/aligned.apk
"$BT/apksigner" verify UpdateWebViewBeta.apk
echo "Built $(pwd)/UpdateWebViewBeta.apk (version $VERSION_NAME, code $VERSION_CODE)"
