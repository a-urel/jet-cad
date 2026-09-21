import 'dart:ui_web' as ui_web;

/// **The only `dart:ui_web` import in this package.**
///
/// The engine's wheel heuristic gives up on Firefox by asking
/// `ui_web.browser.browserEngine == BrowserEngine.firefox`
/// (`engine/src/flutter/lib/web_ui/lib/src/engine/pointer_binding.dart:689`).
/// Asking the same object the same question is what keeps the policy and
/// the heuristic from disagreeing about which browser they are in; a
/// user-agent string parsed here could.
bool isFirefoxBrowser() => ui_web.browser.isFirefox;
