package local.webviewupdate;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.ShortcutInfo;
import android.content.pm.ShortcutManager;
import android.graphics.drawable.Icon;
import android.net.Uri;
import android.os.Bundle;

/**
 * Shows a reminder to close the Linux Terminal first (updating WebView Beta closes it), then opens WebView Beta's
 * page in the Play Store. Started with the extra "pin", it asks the launcher to put a shortcut on the desktop.
 */
public class MainActivity extends Activity {
    private static final String PACKAGE = "com.google.android.webview.beta";

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        if (getIntent().getBooleanExtra("pin", false)) {
            pinToDesktop();
            finish();
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle(R.string.title)
                .setMessage(R.string.message)
                .setPositiveButton(R.string.open, (d, w) -> openPlayStore())
                .setNegativeButton(R.string.cancel, null)
                .setNeutralButton(R.string.pin, (d, w) -> pinToDesktop())
                .setOnDismissListener(d -> finish())
                .show();
    }

    private void openPlayStore() {
        Intent play = new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + PACKAGE))
                .setPackage("com.android.vending").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(play);
        } catch (ActivityNotFoundException e) {
            startActivity(new Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://play.google.com/store/apps/details?id=" + PACKAGE)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
    }

    private void pinToDesktop() {
        ShortcutManager sm = getSystemService(ShortcutManager.class);
        if (sm == null || !sm.isRequestPinShortcutSupported()) {
            return;
        }
        Intent open = new Intent(Intent.ACTION_MAIN).setClass(this, MainActivity.class);
        ShortcutInfo shortcut = new ShortcutInfo.Builder(this, "update-webview-beta")
                .setShortLabel(getString(R.string.app_name))
                .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
                .setIntent(open)
                .build();
        sm.requestPinShortcut(shortcut, null);
    }
}
