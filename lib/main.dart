import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Load env variables ─────────────────────────────────────────────────────
  await dotenv.load(fileName: '.env');

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

  // ── Init Supabase (works on all platforms) ─────────────────────────────────
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
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
