// lib/supabase_config.dart
// Centralises Supabase URL / anon key access.
// Values are loaded from .env via flutter_dotenv.

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static String get url {
    final v = dotenv.env['SUPABASE_URL'];
    assert(v != null && v.isNotEmpty,
        'SUPABASE_URL is missing from .env');
    return v!;
  }

  static String get anonKey {
    final v = dotenv.env['SUPABASE_ANON_KEY'];
    assert(v != null && v.isNotEmpty,
        'SUPABASE_ANON_KEY is missing from .env');
    return v!;
  }

  static String get stripePublishableKey {
    final v = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    assert(v != null && v.isNotEmpty,
        'STRIPE_PUBLISHABLE_KEY is missing from .env');
    return v!;
  }
}
