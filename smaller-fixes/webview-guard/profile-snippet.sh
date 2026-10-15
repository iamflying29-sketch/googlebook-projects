# WebView Guard: show a one-line reminder in new interactive shells while a WebView update is waiting.
if [ -n "$PS1" ] && [ -s "$HOME/.local/state/webview-guard/banner.txt" ]; then
  cat "$HOME/.local/state/webview-guard/banner.txt"
fi
