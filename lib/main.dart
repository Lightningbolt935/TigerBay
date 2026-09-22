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

    // Transparent status bar (dark icons for white/light background)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android: dark icons
      statusBarBrightness: Brightness.light, // iOS: dark icons
    ));
  }

  // ── Init Supabase (works on all platforms: Web, Android, iOS, Windows) ─────
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );

  // ── Init Stripe ────────────────────────────────────────────────────────────
  final stripeKey = EnvConfig.stripePublishableKey;
  if (stripeKey.startsWith('pk_')) {
    Stripe.publishableKey = stripeKey;
    Stripe.merchantIdentifier = 'merchant.io.tigerbay.app';
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
