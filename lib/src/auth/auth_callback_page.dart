import 'dart:convert';

/// Includes a close button that attempts to close the current tab/window.
String buildAuthCallbackHtml({
  required String title,
  required String message,
  bool isSuccess = true,
  String buttonLabel = 'Close',
}) {
  final safeTitle = const HtmlEscape(HtmlEscapeMode.element).convert(title);
  final safeMessage = const HtmlEscape(HtmlEscapeMode.element).convert(message);
  final statusColor = isSuccess ? '#166534' : '#b91c1c';
  final statusBg = isSuccess ? '#dcfce7' : '#fee2e2';

  return '''<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>$safeTitle</title>
    <style>
      body {
        margin: 0;
        font-family: Arial, sans-serif;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background: #f8fafc;
      }
      .box {
        width: min(92vw, 460px);
        background: #fff;
        border: 1px solid #e5e7eb;
        border-radius: 12px;
        padding: 20px;
        text-align: center;
      }
      .status {
        display: inline-block;
        font-size: 12px;
        font-weight: 700;
        color: $statusColor;
        background: $statusBg;
        border-radius: 999px;
        padding: 4px 10px;
        margin-bottom: 10px;
      }
      h1 {
        margin: 0 0 10px;
        font-size: 22px;
      }
      p {
        margin: 0 0 16px;
        color: #334155;
      }
      .btn {
        display: inline-block;
        border: 0;
        border-radius: 8px;
        background: #111827;
        color: #fff;
        padding: 10px 14px;
        text-decoration: none;
        cursor: pointer;
      }
      .hint {
        margin-top: 10px;
        font-size: 12px;
        color: #64748b;
      }
      .hint.hidden {
        display: none;
      }
    </style>
  </head>
  <body>
    <main class="box">
      <span class="status">${isSuccess ? 'Success' : 'Error'}</span>
      <h1>$safeTitle</h1>
      <p>$safeMessage</p>
      <a class="btn" href="#" onclick="closeAuthWindow(event)">$buttonLabel</a>
      <div id="manualCloseHint" class="hint hidden">Browser blocked auto-close. Please close this tab manually.</div>
    </main>
    <script>
      function closeAuthWindow(event) {
        if (event) event.preventDefault();
        var wasVisible = document.visibilityState;

        try { window.close(); } catch (_) {}
        try { self.close(); } catch (_) {}

        setTimeout(function () {
          // If still visible, close was blocked by browser policy.
          if (wasVisible === 'visible' && document.visibilityState === 'visible') {
            var hint = document.getElementById('manualCloseHint');
            if (hint) hint.classList.remove('hidden');
          }
        }, 120);
      }
    </script>
  </body>
</html>
''';
}
