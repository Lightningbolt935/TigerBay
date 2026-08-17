import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // ── TODO: Init Stripe when API key is ready ────────────────────────────────
  // Uncomment the block below and add flutter_stripe back to pubspec.yaml
  // once a real Stripe publishable key (pk_test_... / pk_live_...) is in .env:
  //
  // if (!kIsWeb) {
  //   final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  //   if (stripeKey.startsWith('pk_')) {
  //     Stripe.publishableKey = stripeKey;
  //     await Stripe.instance.applySettings();
  //   }
  // }

  runApp(
    const ProviderScope(
      child: TigerBayApp(),
    ),
  );
}
