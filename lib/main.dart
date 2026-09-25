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
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // ── Init Stripe ────────────────────────────────────────────────────────────
  final stripeKey = EnvConfig.stripePublishableKey;
  if (stripeKey.startsWith('pk_')) {
    Stripe.publishableKey = stripeKey;
    Stripe.merchantIdentifier = 'merchant.io.tigerbay.app';
    Stripe.urlScheme = EnvConfig.appScheme;
    Stripe.setReturnUrlSchemeOnAndroid = true;
    if (!kIsWeb) {
      await Stripe.instance.applySettings();
    }
  }

  runApp(
    const ProviderScope(
      child: TigerBayApp(),
    ),
  );
}
