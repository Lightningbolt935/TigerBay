import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tigerbay_app/core/config/env_config.dart';
import 'package:tigerbay_app/core/config/stripe_config.dart';
import 'firebase_options.dart';
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

  // ── Load Environment Configuration ───────────────────────────────────────
  await EnvConfig.initialize();

  // ── Mobile-only system chrome settings ───────────────────────────────────
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  // ── Init Firebase ────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[TigerBay] Firebase initialization failed: $e');
  }

  // ── Init Supabase ────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );

  // ── Init Stripe ──────────────────────────────────────────────────────────
  try {
    final stripeKey = EnvConfig.stripePublishableKey.isNotEmpty
        ? EnvConfig.stripePublishableKey
        : StripeConfig.publishableKey;

    if (stripeKey.startsWith('pk_')) {
      Stripe.publishableKey = stripeKey;
      StripeConfig.updatePublishableKey(stripeKey);

      if (EnvConfig.appScheme.isNotEmpty) {
        Stripe.urlScheme = EnvConfig.appScheme;
      }
      Stripe.setReturnUrlSchemeOnAndroid = true;

      // Note: merchantIdentifier is omitted until Apple Pay credentials
      // are provisioned in Xcode to prevent iOS Simulator presentation blocks.
      if (!kIsWeb) {
        await Stripe.instance.applySettings();
        debugPrint('[TigerBay] ✅ Stripe initialized (${stripeKey.substring(0, 10)}...)');
      }
    } else {
      debugPrint('[TigerBay] ⚠️ Stripe key missing or does not start with pk_: "$stripeKey"');
    }
  } catch (e) {
    debugPrint('[TigerBay] ❌ Stripe initialization error in main: $e');
  }

  runApp(
    const ProviderScope(
      child: TigerBayApp(),
    ),
  );
}