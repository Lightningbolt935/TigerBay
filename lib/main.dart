import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:tigerbay_app/core/config/env_config.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Error Boundary & Diagnostic Screen ──────────────────────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[TigerBay Global Error] ${details.exceptionAsString()}');
    debugPrint('[TigerBay Stack] ${details.stack}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0F0F13),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something unexpected occurred',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  try {
                    rootNavigatorKey.currentState?.pop();
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF141418),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'Go Back',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // ── Load Environment Configuration (Safe for CI/Docker/Azure/Local) ────────
  await EnvConfig.initialize();

  // ── Mobile-only system chrome settings ─────────────────────────────────────
  // SystemChrome APIs are not supported on web and will throw if called.
  if (!kIsWeb) {
    // Lock to portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Transparent status bar (light icons for dark luxury background)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android: light icons
      statusBarBrightness: Brightness.dark, // iOS: light icons
    ));
  }

  // ── Init Supabase (works on all platforms: Web, Android, iOS, Windows) ─────
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // ── Init Stripe ────────────────────────────────────────────────────────────
  // Previously this was web-skipped, which left the browser with no Stripe
  // backend at all. It is safe now because the `flutter_stripe_web` dependency
  // registers WebStripe, which assigns StripePlatform.instance before the
  // MethodChannelStripeFactory fallback in stripe_platform_interface is ever
  // evaluated. That fallback reads Platform.isIOS/Platform.isAndroid and throws
  // UnsupportedError in the browser.
  final stripeKey = EnvConfig.stripePublishableKey;
  if (stripeKey.startsWith('pk_')) {
    Stripe.publishableKey = stripeKey;
    if (!kIsWeb) {
      // merchantIdentifier and urlScheme are native-only concepts; the web
      // backend reads the current page URL instead.
      Stripe.merchantIdentifier = 'merchant.io.tigerbay.app';
      Stripe.urlScheme = EnvConfig.appScheme;
      Stripe.setReturnUrlSchemeOnAndroid = true;
    }

    // Deliberately not awaited. On web, initialise() injects
    // https://js.stripe.com/v3 and waits for it, so blocking here would tie
    // Flutter's first frame to a third-party CDN and leave the user staring at
    // the boot splash if that request is slow or blocked. flutter_stripe
    // defers settings internally — every Stripe call routes through
    // _awaitForSettings(), which applies and awaits the settings itself — so
    // the payment flow still waits for Stripe to be ready.
    unawaited(
      Stripe.instance.applySettings().catchError((Object e) {
        debugPrint('[TigerBay] Stripe initialisation failed: $e');
      }),
    );
  }

  runApp(
    const ProviderScope(
      child: TigerBayApp(),
    ),
  );
}
