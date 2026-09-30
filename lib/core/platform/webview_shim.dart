/// Platform-conditional WebView facade.
///
/// `package:webview_flutter` only implements Android / iOS / macOS, so a
/// direct import makes any web build dead-on-arrival at runtime. This barrel
/// file re-exports the real plugin on `dart:io` platforms and a no-op stub on
/// the web, so shared screens can keep using the familiar `WebViewController` /
/// `WebViewWidget` API without any `kIsWeb` branching at the call site.
library;

export 'webview_shim_web.dart' if (dart.library.io) 'webview_shim_io.dart';
